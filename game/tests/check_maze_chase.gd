extends SceneTree

# The House map minigame's monster must be able to catch you — and you must still be
# able to win (BACKLOG #14). Since 2026-09-24 (e) "win" is measured on the TWELVE CURATED
# LAYOUTS the game actually deals (`MazeChaseUI.CURATED_SEEDS`), not on random generator output.
#   Godot --headless --path game --script res://tests/check_maze_chase.gd
#
# The original bug: it steered by a raw Euclidean beeline through a PERFECT maze, where the
# corridor route between two cells is routinely 5-15x the straight line. So it drove into
# walls, the per-axis wall-slide carried it sideways down dead ends, and once the player had
# left the starting neighbourhood it could never close again — exactly the reported "it can
# basically kill the player only at the beginning."
#
# Nothing here opens the real UI or touches a scene. It instantiates MazeChaseUI's script,
# generates real mazes, and steps the real `_tick_monster()` / `_tick_patroller()` /
# `_check_snares()` / `_check_fragments()` (→ `_check_glass()`) by hand. The bot and the
# layout builder are `tests/lib/maze_curation.gd`, the same code `probe_maze_curate.gd` chose
# the twelve with, so this file replays the selection rather than re-implementing it.
#
# Four passes:
#   CATCH   — a player who stands still AT THE START is caught.
#   BAND    — on each of the 12 curated layouts, the harness bot (20 runs, the patroller's
#             sub-seed varied exactly as the probe varied it) wins inside 45-90 %, with no
#             stall and no timeout; the aggregate sits inside the 50-85 % selection band.
#   SKIP    — a player who ignores the hammer and runs for the key must not win.
#   PURSUE  — a player who runs away and THEN stops is still hunted down. This is the
#             reported bug in one sentence.
# CATCH / SKIP / PURSUE run on the 12 curated layouts AND on 40 raw generator seeds
# (9000-9039): the pursuit AI is a property of the generator and must hold on all of it.
#
# ⚠️ CATCH and ESCAPE both passed against the old beeline AI, verified by putting it back: the
# monster spawns one cell from the player, and over 96 px a beeline and a corridor route are
# the same thing. Only PURSUE separates them (beeline: 0/40).

const Curation := preload("res://tests/lib/maze_curation.gd")
const DT := 1.0 / 60.0
const CATCH_TIMEOUT := 30.0
const HUNT_TIMEOUT := 60.0
const RUNS := 20
# ⭐ The per-layout assertion is a little wider than the 50-85 % the probe SELECTED on, so a
# harmless float change in the bot does not redden the suite, while a layout that has become
# unwinnable-ish (< 9/20) or a walkover (> 18/20) does. The run is deterministic, so on an
# unchanged build this file reproduces the probe's wins/20 exactly.
const SEED_LO := 9      # 45 %
const SEED_HI := 18     # 90 %
const AGG_LO := 0.50
const AGG_HI := 0.85
const RAW_SEEDS := 40

var _ui: Node
var _fails := 0


func _initialize() -> void:
	var script: GDScript = load("res://scripts/maze_chase_ui.gd")
	_ui = script.new()


func _fail(msg: String) -> void:
	_fails += 1
	print("  FAIL ", msg)


func _median(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return float(s[s.size() / 2])


# The curated layouts, then the raw generator seeds.
func _all_seeds(curated: Array) -> Array:
	var out: Array = curated.duplicate()
	for i in RAW_SEEDS:
		out.append(9000 + i)
	return out


func _process(_delta: float) -> bool:
	var curated: Array = (_ui.get_script() as Script).get("CURATED_SEEDS")
	var catch_radius: float = _ui.get_script().get("CATCH_RADIUS")
	var grace: float = _ui.get_script().get("MONSTER_START_DELAY")
	var bot = Curation.new(_ui)
	if curated.size() != 12:
		_fail("CURATED_SEEDS has %d entries, the user's call is 12" % curated.size())
	var seeds := _all_seeds(curated)

	# ---------------------------------------------------------------- CATCH
	print("--- %d mazes (12 curated + %d raw): does a STATIONARY player get caught? ---"
		% [seeds.size(), RAW_SEEDS])
	var catch_times: Array[float] = []
	for s in seeds:
		Curation.fresh(_ui, s, s)
		var t := 0.0
		var caught := false
		while t < CATCH_TIMEOUT:
			if t >= grace:
				_ui.call("_tick_monster", DT)
			t += DT
			if (_ui.get("_monster_pos") as Vector2).distance_to(_ui.get("_player_pos")) <= catch_radius:
				caught = true
				break
		if caught:
			catch_times.append(t)
		else:
			_fail("maze seed %d: stood still for %.0f s and was never caught" % [s, CATCH_TIMEOUT])
	print("  caught %d/%d — median %.1f s" % [catch_times.size(), seeds.size(), _median(catch_times)])

	# ---------------------------------------------------------------- BAND
	# ⚠️ THE HISTORY THIS REPLACES (kept, not deleted): on random generator seeds 9000-9039 this
	# pass reported 37/40 (one hunter, perfect maze), 26/40 (2026-08-15: braid + patroller +
	# snares, floor lowered 0.75 → 0.55 on the user's call), then 28/40 and 232/400 = 58 % at a
	# 21.7 s median (2026-08-16: the two-stage objective + the patroller band). Those numbers
	# describe what the generator deals at random, and since 2026-09-24 (e) the player is never
	# dealt a random layout — so the floor that mattered moved from "the generator on average"
	# to "each of the twelve the player can meet". The raw rate is still printed below, as a
	# reference, without an assertion.
	print("--- the 12 CURATED layouts x %d runs (patroller sub-seed varied): in band? ---" % RUNS)
	var total_wins := 0
	var total_runs := 0
	var all_times: Array = []
	for s in curated:
		var wins := 0
		var stalls := 0
		var by_patrol := 0
		var by_hunter := 0
		var times: Array = []
		for k in RUNS:
			# ⚠️ Exactly the probe's sub-seeds: k = 0 is the circuit the game plays.
			Curation.fresh(_ui, s, s * 100 + k if k > 0 else s)
			var r: Dictionary = bot.play()
			total_runs += 1
			if r["won"]:
				wins += 1
				times.append(r["t"])
				all_times.append(r["t"])
			elif r["caught"]:
				if r["by_patrol"]:
					by_patrol += 1
				else:
					by_hunter += 1
			else:
				stalls += 1
		total_wins += wins
		print("  seed %d: won %2d/%d  median win %.1f s  caught by hunter %d / patroller %d  stalls %d"
			% [s, wins, RUNS, _median(times), by_hunter, by_patrol, stalls])
		if wins < SEED_LO or wins > SEED_HI:
			_fail("curated seed %d: the bot won %d/%d, outside %d..%d — the layout has drifted "
				% [s, wins, RUNS, SEED_LO, SEED_HI] + "out of the band; re-run probe_maze_curate.gd")
		if stalls > 0:
			_fail("curated seed %d: %d run(s) stalled or timed out — a dead loop (filter d)" % [s, stalls])
	# ⚠️ Sample size, or "0 of 0" reads as a pass.
	if total_runs != curated.size() * RUNS or total_runs == 0:
		_fail("only %d band runs were scored (want %d)" % [total_runs, curated.size() * RUNS])
	var agg: float = float(total_wins) / float(maxi(total_runs, 1))
	print("  AGGREGATE %d/%d = %.1f %%, median win %.1f s   (asserted %d-%d %%)"
		% [total_wins, total_runs, agg * 100.0, _median(all_times), int(AGG_LO * 100), int(AGG_HI * 100)])
	if agg < AGG_LO or agg > AGG_HI:
		_fail("aggregate %.1f %% outside the %d-%d %% band" % [agg * 100.0, int(AGG_LO * 100), int(AGG_HI * 100)])

	# Reference only: what the raw generator would have dealt (no assertion — nothing ships it).
	var raw_wins := 0
	for i in RAW_SEEDS:
		Curation.fresh(_ui, 9000 + i, 9000 + i)
		if bot.play()["won"]:
			raw_wins += 1
	print("  (reference, not asserted) the RAW generator, seeds 9000-%d: bot won %d/%d"
		% [9000 + RAW_SEEDS - 1, raw_wins, RAW_SEEDS])

	# ---------------------------------------------------------------- SKIP
	# The only pass that can see the two-stage rule break: a bot that walks to the fragments
	# first collects them whether or not the rule exists (verified 2026-08-16 by deleting the
	# collection half of `_is_won()`: this file stayed green until this pass existed).
	print("--- %d mazes: a player who SKIPS the hammer must not win ---" % seeds.size())
	var skipped_wins := 0
	var skip_checked := 0
	for s in seeds:
		Curation.fresh(_ui, s, s)
		if (_ui.get("_fragments") as Array).is_empty():
			continue
		skip_checked += 1
		var away := Vector2(-99999.0, -99999.0)
		_ui.set("_monster_pos", away)
		_ui.set("_patrol_pos", away)
		bot.reset()
		var t := 0.0
		while t < 40.0:
			bot.step_toward(DT, _ui.get("_target_pos"))
			_ui.call("_check_fragments")
			t += DT
			if bool(_ui.call("_is_won")):
				skipped_wins += 1
				break
	if skip_checked != seeds.size():
		_fail("only %d of %d seeds had a fragment to skip" % [skip_checked, seeds.size()])
	print("  skipping players who reached the key anyway: %d/%d (want 0)" % [skipped_wins, skip_checked])
	if skipped_wins > 0:
		_fail("%d/%d runs won WITHOUT the hammer — the key is not actually sealed"
			% [skipped_wins, skip_checked])

	# ---------------------------------------------------------------- PURSUE
	print("--- %d mazes: player runs the objective, THEN stops. Hunted down? ---" % seeds.size())
	var hunted := 0
	var hunt_times: Array[float] = []
	for s in seeds:
		Curation.fresh(_ui, s, s)
		bot.reset()
		var t := 0.0
		while t < 12.0:
			bot.step_toward(DT, bot.goal())
			if t >= grace:
				_ui.call("_tick_monster", DT)
				_ui.call("_tick_patroller", DT)
				_ui.call("_check_snares", null)
			_ui.call("_check_fragments")
			t += DT
			if bool(_ui.call("_is_won")):
				break
		var start_gap: float = (_ui.get("_monster_pos") as Vector2).distance_to(_ui.get("_player_pos") as Vector2)
		var t2 := 0.0
		var got := false
		while t2 < HUNT_TIMEOUT:
			_ui.call("_tick_monster", DT)
			_ui.call("_tick_patroller", DT)
			t2 += DT
			var pp2: Vector2 = _ui.get("_player_pos")
			if (_ui.get("_monster_pos") as Vector2).distance_to(pp2) <= catch_radius \
					or (_ui.get("_patrol_pos") as Vector2).distance_to(pp2) <= catch_radius:
				got = true
				break
		if got:
			hunted += 1
			hunt_times.append(t2)
		elif curated.has(s):
			# A curated layout the hunter cannot finish is a region it cannot navigate.
			_fail("curated seed %d: stood still for %.0f s after running and was never reached "
				% [s, HUNT_TIMEOUT] + "(started %.0f px away)" % start_gap)
	print("  hunted down %d/%d (median %.1f s after the player stopped)"
		% [hunted, seeds.size(), _median(hunt_times)])
	if hunted < int(seeds.size() * 0.9):
		_fail("only %d/%d — the monster cannot reach a player who moved away. This is "
			% [hunted, seeds.size()] + "the reported bug: it only kills you at the start.")

	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	_ui.free()
	quit(0 if _fails == 0 else 1)
	return true
