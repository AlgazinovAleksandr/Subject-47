extends SceneTree

# The two levels that EARN their light back: does the payoff fire, and only when it should?
#
#   Godot --headless --path game --script res://tests/check_dark_payoffs.gd
#
#   Lab   — pitch black until all three breakers are thrown, then the whole building.
#   House — pitch black until all three SAFE notes are read, then ONE lamp beside the exit lock.
#
# ⚠️ `check_darkness.gd` proves the levels START dark. That is the easy half, and on its own it
# is satisfied by a level whose lights never come back at all — which would be unwinnable rather
# than frightening. This is the other half.
#
# ⚠️ THE HOUSE COUNTER IS THE INTERESTING ONE. `note.gd` emits `read` on EVERY open, so the naive
# `_count += 1` lights the house for a player who opens the living-room note three times and
# never goes down to the cellar for the third digit. `level_2.gd` counts node names; this drives
# that path by re-reading one note repeatedly and requires the lamp to stay dark.

var _fails: Array[String] = []
var _checks := 0
var _stage := 0
var _house_saved: Dictionary = {}
var _fade_mid := -1.0
var _fade_end := -1.0


func gs2() -> Node:
	return root.get_node_or_null("GameState")


# How many of the ten dark-wing lamps are actually burning?
func _wing_burning() -> int:
	var n := 0
	var wing: Dictionary = current_scene.get("_wing_lamp_names")
	if wing == null:
		return 0
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		if x is OmniLight3D and wing.has(x.name) and x.light_energy > 0.001:
			n += 1
	return n
var _t := 0.0
var _wall := 0.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


# Lit lamps, EXCLUDING the ones the level names as burning before the power (2026-09-10:
# `level_1.gd:PRE_POWER_LIT`, Records — the dark wing's home bearing). `check_darkness.gd`
# asserts that set exactly; this file asks whether the PAYOFF lights the rest.
func _lit_count() -> int:
	var nodes: Array = []
	_all(current_scene, nodes)
	var allowed: Dictionary = {}
	var sc := current_scene.get_script() as GDScript
	if sc:
		allowed = sc.get_script_constant_map().get("PRE_POWER_LIT", {})
	var n := 0
	for x in nodes:
		if x is OmniLight3D and (x as OmniLight3D).light_energy > 0.001 \
				and not allowed.has(String(x.name)):
			n += 1
	return n


func _lamp(nm: String) -> OmniLight3D:
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		if x is OmniLight3D and String(x.name) == nm:
			return x
	return null


func _initialize() -> void:
	change_scene_to_file("res://scenes/level_1.tscn")


func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 150.0:
		print("TIMEOUT at stage %d" % _stage)
		quit(1)
		return true
	_t += delta
	if _t < 3.0 or current_scene == null:
		return false
	_t = 0.0

	match _stage:
		0:
			print("== DARK PAYOFFS ==")
			_ok("Lab: nothing is lit before the breakers", _lit_count() == 0,
				"%d lamps burning" % _lit_count())
			_ok("Lab: _power_on is false at spawn",
				not bool(current_scene.get("_power_on")))
			# Throw all three, through the level's own signal path.
			var nodes: Array = []
			_all(current_scene, nodes)
			var breakers: Array = []
			for x in nodes:
				if x.get_script() != null \
						and String(x.get_script().resource_path).ends_with("breaker.gd"):
					breakers.append(x)
			_ok("Lab: found the three breakers", breakers.size() == 3,
				"%d found" % breakers.size())
			for b in breakers:
				# ⚠️ Through the signal, not by setting `_power_on`. The point is that the LEVEL's
				# own wiring restores the light; forcing the flag would assert nothing about it.
				b.emit_signal("flipped")
			_stage = 1
		1:
			var lit := _lit_count()
			_ok("Lab: the building comes back when the third breaker goes", lit >= 8,
				"%d lamps burning after 3/3" % lit)
			_ok("Lab: _power_on is true", bool(current_scene.get("_power_on")))
			var we := current_scene.get_node_or_null(
				"Environment/WorldEnvironment") as WorldEnvironment
			if we and we.environment:
				# The ambient is tweened over 1.2 s; by now it has arrived.
				_ok("Lab: the ambient comes back with it",
					we.environment.ambient_light_energy > 0.2,
					("ambient %.3f — lamps alone light their own pools and leave everything "
					+ "between them black, which is the search, not the reward")
						% we.environment.ambient_light_energy)
			# ⚠️ The Morgue and the ten-room wing must STILL be dark. `_restore_power()` skips
			# every lamp spawned at 0.0 (Issue 36); floodlighting them would undo the DarkZone-free
			# morgue's whole design and the navigate-by-ear wing's puzzle in one go.
			var morgue := _lamp("Lamp_Morgue")
			_ok("Lab: the Morgue stays dark after the power returns",
				morgue == null or morgue.light_energy <= 0.001,
				"Morgue lamp %.3f" % (morgue.light_energy if morgue else -1.0))
			var nook := _lamp("Lamp_BreakerNook")
			_ok("Lab: the dark wing stays dark too",
				nook == null or nook.light_energy <= 0.001,
				"BreakerNook lamp %.3f" % (nook.light_energy if nook else -1.0))
			change_scene_to_file("res://scenes/level_2_1.tscn")
			_stage = 2
		2:
			_ok("House: nothing is lit before the notes", _lit_count() == 0,
				"%d lamps burning" % _lit_count())
			var lock := _lamp("Lamp_Lock")
			_ok("House: the exit lamp exists and is dark",
				lock != null and lock.light_energy <= 0.001)

			# ⭐ THE RE-READ CONTROL. Fire ONE note's `read` three times.
			var nodes2: Array = []
			_all(current_scene, nodes2)
			var safe: Array = []
			for x in nodes2:
				if x.get_script() != null \
						and String(x.get_script().resource_path).ends_with("note.gd") \
						and not bool(x.get("is_trap")):
					safe.append(x)
			_ok("House: found the three safe notes", safe.size() == 3,
				"%d non-trap notes" % safe.size())
			if safe.size() == 3:
				for i in range(3):
					safe[0].emit_signal("read")
				_ok("House: re-reading ONE note three times does NOT light the lamp",
					not bool(current_scene.get("_lock_lamp_on")),
					("note.gd emits `read` on every open, so a counter that increments would "
					+ "light the house without the player ever going to the cellar"))
				safe[1].emit_signal("read")
				safe[2].emit_signal("read")
			# ⚠️ A SUB-STAGE 0.6 s LATER, INSIDE THE FADE. The normal cadence here is 3 s and
			# `LAMP_ON_FADE` is 2.2, so every ordinary stage boundary lands AFTER the tween has
			# settled — which is precisely why a fade that drove nothing went unnoticed. Winding
			# `_t` forward buys a reading while the ramp is still climbing.
			_t = 2.4
			_stage = 21
		21:
			var mid := _lamp("Lamp_Lock")
			_fade_mid = mid.light_energy if mid else -1.0
			_stage = 3
		3:
			var settled := _lamp("Lamp_Lock")
			_fade_end = settled.light_energy if settled else -1.0
			# ⚠️⚠️ SAMPLED *DURING* THE FADE, WHICH IS THE ONLY WAY TO SEE IT. `LAMP_ON_FADE` was
			# DEAD for the whole life of the feature — `_lock_lamp_gain` was declared, tweened and
			# documented, and `_drive_lights()`, the only writer of `light_energy`, never read it,
			# so the lamp snapped to full on the first frame (measured 0.4117 while the gain was
			# still 0.0031). Every assertion in this file sampled 3 s later, by which time a snap
			# and a fade are identical. A tween on a variable nothing reads looks exactly like a
			# working fade from the outside.
			_ok("House: the lamp is NOT at full brightness the instant it is lit",
				_fade_mid > 0.001 and _fade_mid < _fade_end * 0.85,
				("mid-fade %.4f against settled %.4f — must be visibly between 0 and full, or "
				+ "LAMP_ON_FADE is driving nothing") % [_fade_mid, _fade_end])
			_ok("House: ...and it does reach full",
				_fade_end > 0.001, "settled %.4f" % _fade_end)

			_ok("House: all three distinct notes DO light it",
				bool(current_scene.get("_lock_lamp_on")))
			var lock2 := _lamp("Lamp_Lock")
			_ok("House: and it is the lamp by the exit lock that came on",
				lock2 != null and lock2.light_energy > 0.001,
				"Lamp_Lock %.3f" % (lock2.light_energy if lock2 else -1.0))
			# ⚠️ ONLY that one. The user's call (D3) was a beacon at the end of a dark house, not
			# a power restore — the Lab already owns that beat.
			_ok("House: NOTHING else came on with it", _lit_count() == 1,
				("%d lamps burning — the payoff is one warm point at the far end of a black "
				+ "house, which is spent the moment a second lamp joins it") % _lit_count())

			# ⭐⭐ DOES THE PAYOFF SURVIVE A BACK-DOOR RETURN? Both of these levels now hand the
			# player a permanent light for solving something, and a permanent reward that a walk
			# to the next level and back silently revokes is worse than no reward — the player
			# cannot tell it from a bug. This is KONTUR's Issues 141/142 in two new places: a
			# LEDGER and the WORLD IT DESCRIBES must be restored together, and the test for it is
			# not "does the flag come back" but "having come back, is the level still in the state
			# the flag claims". Both bugs below were real and both were found by writing this.
			# ⭐ VERIFIED RED 2026-09-03, and the first version of this note over-claimed. With
			# `_light_the_wing(true)` removed from the Lab's restore, the two Lab assertions go
			# red (the wing dark, 0 of 10 lamps; the lock zone respawned). The House's objective
			# write moving back above the cellar/key chain reddens NOTHING on its own — measured,
			# 22 of 22 still green — because every branch of that chain is gated on state this
			# stage never set. Opening the cellar before the capture (below) is what makes the
			# third failure real; with it, the revert reports the objective as OBJ_CODE.
			# A resume guard that has never been watched going red is the one thing this project
			# has learned not to trust — and "watched going red" has to mean the assertion you
			# are claiming, not any assertion in the file.
			var gs := root.get_node_or_null("GameState")
			gs.set("current_level", 2)
			# ⚠️⚠️ OPEN THE CELLAR BEFORE CAPTURING, OR THIS WHOLE STAGE MEASURES NOTHING.
			# The bug is that `_restore_progress()`'s cellar/key chain OVERWRITES the objective,
			# and every branch of that chain is gated on `cellar_open` / `has_cellar_key` /
			# `_map_solved`. A snapshot taken from three `read` signals alone has all three false,
			# so no branch runs, nothing overwrites, and the assertion below passes IDENTICALLY
			# with the objective write back in its old buggy position — measured 2026-09-03,
			# 22 of 22 green on a deliberate revert. It is also the state real play produces:
			# the third safe note is IN the cellar, so a player who has read all three must have
			# opened it. `save_progress()` reads the gate's own `_opened`, so open the gate.
			var gate = current_scene.get("_cellar_gate")
			if is_instance_valid(gate):
				gate.call("open")
			_ok("House: the cellar is open, so the restore's objective chain will FIRE",
				is_instance_valid(gate) and bool(gate.get("_opened")),
				"without this the objective assertion two stages down is vacuous")
			gs.call("_capture_progress")
			_house_saved = gs.call("get_level_progress", 2)
			_ok("House: the snapshot carries the lamp",
				bool(_house_saved.get("lock_lamp", false)),
				str(_house_saved.keys()))
			gs.set("entered_from_ahead", true)
			change_scene_to_file("res://scenes/level_2_1.tscn")
			_stage = 4
		4:
			# ⚠️ The lamp is a STATE, so it must be lit on arrival — with no sting and no tween,
			# because re-firing the beat would announce a discovery made a level ago.
			var relit := _lamp("Lamp_Lock")
			_ok("House: RESUMED — the exit lamp is still burning",
				relit != null and relit.light_energy > 0.001,
				"Lamp_Lock %.3f on a restored house" % (relit.light_energy if relit else -1.0))
			# ⚠️ `GameState` stores the line in `current_objective`, not `objective_text` — read
			# the wrong name and `String(null)` throws, which aborts `_process` BEFORE the stage
			# counter and loops the test for ever printing the assertion above as a pass. That is
			# Issue 45, and it is why the timeout check sits at the TOP of this function.
			# ⚠️ The constant map is used to keep this coupled to the level's own string rather
			# than a copy. It is NOT a workaround for `Node.get()`: an earlier version of this
			# comment claimed `Node.get()` cannot see a `const`, and that is FALSE on 4.6.3 —
			# measured, `current_scene.get("OBJ_LOCK_LIT")` returns the string and
			# `check_sprawl_walls.gd` reads `SPRAWL_AMBIENT`/`BASE_AMBIENT` that way today.
			var obj := String(gs2().get("current_objective"))
			var want := String(current_scene.get_script()
				.get_script_constant_map().get("OBJ_LOCK_LIT", "<no such const>"))
			_ok("House: RESUMED — the objective is not downgraded", obj == want,
				("objective read \"%s\" — the cellar/key chain below the lamp block used to "
				+ "overwrite it, sending a player who had already read all three notes back to "
				+ "an earlier step of the quest. Verified red 2026-09-03 by moving the write "
				+ "back into the lamp block: it reports OBJ_CODE.") % obj)

			# --- and the Lab's dark wing, the other half of the same class of bug
			gs2().set("current_level", 1)
			change_scene_to_file("res://scenes/level_1.tscn")
			_stage = 5
		5:
			# Clear the wing the way the level does, then walk out and back.
			# ⚠️ MEASURED A STAGE LATER, NEVER ON THIS FRAME. `_light_the_wing()` raises the ten
			# lamps over `WING_LIGHT_FADE` 1.5 s with a Tween, and a Tween does not run until the
			# NEXT frame — reading the energies here reported 0 of 10 burning on a wing that lights
			# perfectly. That is the project's own documented vacuous-measurement shape (the door
			# clearance check that measured un-swung doors and reported a comfortable 2.81 m).
			# ⭐ CONTROL for the stage-6 assertion below. "`_nook_zone` is null on a restored Lab"
			# is trivially true of a build where the zone is never created at all — so prove a
			# FRESH Lab has one before proving the restore frees it.
			_ok("Lab: a fresh Lab HAS the flashlight-lock zone",
				current_scene.get("_nook_zone") != null,
				"if this is null the stage-6 'the lock zone is gone' assertion measures nothing")
			current_scene.set("_nook_scare_done", true)
			current_scene.call("_light_the_wing")
			_stage = 51
		51:
			var lit_before := _wing_burning()
			# ⚠️ ALL TEN, not ">0". The wing is ten rooms and the payoff is that the whole route
			# back is lit; a trimmed `WING_ROOMS` would sail through a >0 check while leaving the
			# player walking most of the maze in the dark.
			_ok("Lab: the wing lights up when the nook is cleared", lit_before == 10,
				"%d of 10 wing lamps burning 3 s after _light_the_wing()" % lit_before)
			gs2().call("_capture_progress")
			_ok("Lab: the snapshot carries the nook payoff",
				bool(gs2().call("get_level_progress", 1).get("nook_scare_done", false)))
			gs2().set("entered_from_ahead", true)
			change_scene_to_file("res://scenes/level_1.tscn")
			_stage = 6
		6:
			# ⚠️ THIS WENT RED BEFORE THE FIX. `_light_the_wing()` can only ever be called by the
			# nook breaker's `flipped`, and a restored breaker never emits it again — so the wing
			# came back DARK with its flashlight-lock zone respawned, i.e. a lightless 50 m maze
			# whose puzzle was already solved and could not be re-solved.
			_ok("Lab: RESUMED — the wing is still lit", _wing_burning() == 10,
				"%d of 10 wing lamps burning on a restored Lab" % _wing_burning())
			_ok("Lab: RESUMED — and the flashlight lock zone is gone",
				current_scene.get("_nook_zone") == null,
				"re-entering must not re-lock a torch the player has earned back")
			print("== %d checks, %d failed ==" % [_checks, _fails.size()])
			for f in _fails:
				print("   FAILED: " + f)
			quit(1 if _fails.size() > 0 else 0)
			return true
		_:
			pass
	return false
