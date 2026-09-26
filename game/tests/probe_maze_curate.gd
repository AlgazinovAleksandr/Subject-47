extends SceneTree

# MEASUREMENT — how `MazeChaseUI.CURATED_SEEDS` was chosen (2026-09-24 e). Not in the suite: it
# asserts nothing, and a full sweep takes minutes. Reproducible: no wall-clock, no randomize().
#
#   Godot --headless --path game --script res://tests/probe_maze_curate.gd
#   Godot --headless --path game --script res://tests/probe_maze_curate.gd -- 1000 1000 20
#                                                            first seed ^   count ^   ^ bot runs per seed
#
# The user's call (backlogs/02-house-porch.md §2 row 16): *"filter only, I pick 12"*, i.e. the
# procedure picks, nobody hand-picks. For every generator seed in the range:
#   1. build the layout exactly as `open()` does (`maze_curation.gd:fresh`, sub-seed = seed);
#   2. REJECT on the fairness filters, measured by `maze_curation.gd:analyse`:
#        (a) RACE    the hunter can reach a cell the tour cannot avoid within RACE_MARGIN_S of
#                    the player (or before);
#        (b) BEHIND  the hammer or the key is behind the hunter;
#        (c) PATROL  the patroller's free circuit walks through such a cell;
#   3. play the survivors RUNS times with the harness bot, varying ONLY the patroller's
#      sub-seed (seed*100 + k; k = 0 is the circuit the game plays) and REJECT on
#        (d) LOOP    any run where the bot stalls or times out;
#   4. keep the band — bot win rate 50-85 % — and rank by distance from its middle (67.5 %),
#      ties broken by the smaller seed. The first 12 are the shipped list.
#
# Each seed prints one `ROW` line (grep-able) and the table is re-printed ranked at the end.

const Curation := preload("res://tests/lib/maze_curation.gd")
const BAND_LO := 0.50
const BAND_HI := 0.85
const PICK := 12

var _first := 1000
var _count := 1000
var _runs := 20


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() >= 1:
		_first = int(a[0])
	if a.size() >= 2:
		_count = int(a[1])
	if a.size() >= 3:
		_runs = int(a[2])


func _median(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return float(s[s.size() / 2])


func _process(_delta: float) -> bool:
	var script: GDScript = load("res://scripts/maze_chase_ui.gd")
	var ui: Node = script.new()
	var bot = Curation.new(ui)
	var t0 := Time.get_ticks_msec()
	var rej := {"race": 0, "behind": 0, "patrol": 0, "loop": 0, "band_low": 0, "band_high": 0}
	var kept: Array = []
	# `ship` = the bot's result on k = 0, the patroller circuit the game itself plays.
	print("ROW  seed  tour  cuts  mand  margin_s  behind  patrol  wins/%d  med_win_s  stalls  ship  verdict" % _runs)
	for s in range(_first, _first + _count):
		Curation.fresh(ui, s, s)
		var f: Dictionary = Curation.analyse(ui)
		var verdict := ""
		var wins := -1
		var med := 0.0
		var stalls := 0
		var ship := "-"
		if not f["race_ok"]:
			verdict = "REJECT a-race"
			rej["race"] += 1
		elif f["behind"]:
			verdict = "REJECT b-behind"
			rej["behind"] += 1
		elif f["patrol_hit"]:
			verdict = "REJECT c-patrol"
			rej["patrol"] += 1
		else:
			wins = 0
			var times: Array = []
			for k in _runs:
				Curation.fresh(ui, s, s * 100 + k if k > 0 else s)
				var r: Dictionary = bot.play()
				if k == 0:
					ship = "W" if r["won"] else "L"
				if r["won"]:
					wins += 1
					times.append(r["t"])
				elif r["stalled"] or r["timeout"]:
					stalls += 1
			med = _median(times)
			var rate: float = float(wins) / float(_runs)
			if stalls > 0:
				verdict = "REJECT d-loop"
				rej["loop"] += 1
			elif rate < BAND_LO:
				verdict = "REJECT band-low"
				rej["band_low"] += 1
			elif rate > BAND_HI:
				verdict = "REJECT band-high"
				rej["band_high"] += 1
			else:
				verdict = "KEEP"
				kept.append({"seed": s, "tour": f["tour"], "cuts": f["cuts"],
					"margin": f["min_margin"], "wins": wins, "med": med, "rate": rate,
					"ship": ship, "mand": f["mandatory"]})
		print("ROW  %d  %d  %d  %d  %.2f  %s  %s  %s  %.1f  %d  %s  %s" % [
			s, f["tour"], f["cuts"], f["mandatory"], f["min_margin"],
			"Y" if f["behind"] else "-", "Y" if f["patrol_hit"] else "-",
			("%d" % wins) if wins >= 0 else "-", med, stalls, ship, verdict])
	var mid := (BAND_LO + BAND_HI) / 2.0
	kept.sort_custom(func(x, y):
		var dx: float = absf(float(x["rate"]) - mid)
		var dy: float = absf(float(y["rate"]) - mid)
		if not is_equal_approx(dx, dy):
			return dx < dy
		return int(x["seed"]) < int(y["seed"]))
	print("")
	print("=== %d seeds (%d..%d), %d bot runs each: rejected race %d · behind %d · patrol %d · loop %d · band-low %d · band-high %d · KEPT %d  (%.0f s)" % [
		_count, _first, _first + _count - 1, _runs, rej["race"], rej["behind"], rej["patrol"],
		rej["loop"], rej["band_low"], rej["band_high"], kept.size(),
		float(Time.get_ticks_msec() - t0) / 1000.0])
	print("RANKED  seed  tour  cuts  margin_s  wins/%d  med_win_s  ship" % _runs)
	var picked: Array = []
	for i in kept.size():
		var k: Dictionary = kept[i]
		print("%s %d  %d  %d  %.2f  %d  %.1f  %s" % ["PICK  " if i < PICK else "spare ", k["seed"], k["tour"],
			k["cuts"], k["margin"], k["wins"], k["med"], k["ship"]])
		if i < PICK:
			picked.append(int(k["seed"]))
	print("CURATED_SEEDS := %s" % [picked])
	ui.free()
	quit(0)
	return true
