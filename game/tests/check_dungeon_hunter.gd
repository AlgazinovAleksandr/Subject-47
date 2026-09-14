extends SceneTree

# THE NIGHTMARE's "hard to lose" contract (2026-09-12), driven live.
#
#   Godot --headless --path game --script res://tests/check_dungeon_hunter.gd
#
# The user's verdict on the first hand playtest was "it is very simple to get killed", and the
# six-seed completion bot agreed (0 wins, 2 deaths). Every instant death was removed; the panic
# bar is the only one left. This asserts it two ways:
#   1. SOURCE: dungeon.gd and dungeon_rooms.gd contain no `Screamer.trigger(` at all.
#   2. LIVE: a Still One reaching the player fires a survivable flash + STARTLE_PANIC and topples;
#      a Weeping Frame's burn-out costs no extra panic and never triggers; the hunter's contact
#      stages the catch — +CATCH_PANIC, no trigger, the wave ends and input comes back; the chase
#      cue rises only while it is chasing WITH line of sight and falls when the wave ends.
#
# ⚠️ Wall-clock waits, not frame counts: the catch is staged on SceneTreeTimers.

const SEED := 101
const CATCH_WAIT := 0.7          # > the 0.35 s to the sting
const RELEASE_WAIT := 1.6        # > 0.35 + 0.9 s to the release
const CUE_WAIT := 0.6

var _fails := 0
var _checks := 0
var _stage := 0
var _t := 0.0
var _settle := 0
var _level: Node = null
var _p: CharacterBody3D = null
var _hunter = null
var _panic_before := 0.0
var _statue = null
var _started := false


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _panic() -> float:
	return float(_p.call("get_panic_ratio")) * 50.0


func _process(delta: float) -> bool:
	if not _started:
		_started = true
		var gs := root.get_node_or_null("GameState")
		if gs:
			gs.call("save_level_progress", 7, {"layout_seed": SEED, "content_seed": SEED * 31 + 7})
		change_scene_to_file("res://scenes/dungeon.tscn")
		return false
	_settle += 1
	if _settle < 14:
		return false
	if _level == null:
		_level = current_scene
		if _level == null or not _level.has_method("get_gen"):
			print("  FAIL dungeon.tscn did not load")
			_fails += 1
			return _report()
		_p = _level.get_node("Player")
		_hunter = _level.call("get_hunter")
		_source_check()
		var gen = _level.call("get_gen")
		_level.set("_in_dungeon", true)
		_p.global_position = gen.room_center_world(gen.spawn_room) + Vector3(0, 0.1, 0)
		_p.force_update_transform()
		var cand = _level.get("_candle")
		if cand and not bool(cand.get("burning")):
			cand.call("toggle")
		_stage = 1
		_t = 0.0
		return false

	# A death would reload the scene: that is the one thing this file exists to rule out.
	if current_scene != _level:
		_ok("the level was never reloaded by a screamer", false, "scene changed")
		return _report()

	_t += delta
	match _stage:
		1:
			_stage_statue()
		2:
			if _t >= 0.3:
				_ok("statue: the player is alive and the run continues", is_instance_valid(_p))
				# Decay (3.5/s) runs during the 0.3 s wait — no hunter is present to hold it.
				var want: float = float(_level.get("STARTLE_PANIC"))
				var got: float = _panic() - _panic_before
				_ok("statue: STARTLE_PANIC was charged (less 0.3 s of decay)",
					got >= want - 3.5 * 0.45 and got <= want + 0.6, "delta %.1f" % got)
				_ok("statue: no fatal screamer", not bool(root.get_node("Screamer").get("_is_triggering")))
				_ok("statue: it toppled for good", bool(_statue.call("has_fallen")))
				_stage_frame()
				_stage = 3
				_t = 0.0
		3:
			if _t >= 0.3:
				_stage_catch_begin()
				_stage = 4
				_t = 0.0
		4:
			if _t >= CATCH_WAIT:
				_ok("catch: the player is alive", is_instance_valid(_p))
				_ok("catch: exactly CATCH_PANIC was charged",
					absf((_panic() - _panic_before) - float(_level.get("CATCH_PANIC"))) < 0.6,
					"delta %.1f" % (_panic() - _panic_before))
				_ok("catch: no fatal screamer", not bool(root.get_node("Screamer").get("_is_triggering")))
				_ok("catch: the player is pinned during the lunge", bool(_p.call("is_input_frozen")))
				var d: float = (_hunter.call("get_creature_position") as Vector3).distance_to(_p.global_position)
				_ok("catch: its face is at arm's length", d <= 1.2, "%.2f m" % d)
				_stage = 5
			elif _t >= RELEASE_WAIT:
				pass
		5:
			if _t >= RELEASE_WAIT:
				_ok("release: the wave is over (hunter despawned)", not bool(_level.call("hunter_present")))
				_ok("release: input is back", not bool(_p.call("is_input_frozen")))
				var cue := _level.get_node_or_null("ChaseCue") as AudioStreamPlayer
				_ok("release: the chase cue is silent", cue != null and cue.volume_db <= -55.0,
					"%.1f dB" % (cue.volume_db if cue else 0.0))
				_stage_cue_begin()
				_stage = 6
				_t = 0.0
		6:
			if _t >= CUE_WAIT:
				var cue := _level.get_node_or_null("ChaseCue") as AudioStreamPlayer
				var st: int = int(_hunter.call("get_state"))
				var los: bool = bool(_hunter.call("has_line_of_sight"))
				_ok("cue: the hunter is in CHASE with line of sight", st == 2 and los,
					"state %d los %s" % [st, str(los)])
				_ok("cue: the chase cue rose", cue != null and cue.volume_db > -20.0,
					"%.1f dB" % (cue.volume_db if cue else -99.0))
				_ok("cue: it plays on the un-ducked chase bus", cue != null and str(cue.bus) == "DungeonChase")
				var v := _level.get("_hunter_voice") as AudioStreamPlayer3D
				_ok("voice: the hunter carries a positional voice on the chase bus",
					v != null and str(v.bus) == "DungeonChase")
				_ok("voice: its cadence is the user's 10-20 s",
					float(_level.get("HUNTER_CALL_MIN")) == 10.0 and float(_level.get("HUNTER_CALL_MAX")) == 20.0)
				_level.call("_despawn_matron")
				_stage = 7
				_t = 0.0
		7:
			if _t >= 1.8:
				var cue := _level.get_node_or_null("ChaseCue") as AudioStreamPlayer
				_ok("cue: it fell within 1.6 s of the wave ending", cue != null and cue.volume_db <= -55.0,
					"%.1f dB" % (cue.volume_db if cue else 0.0))
				return _report()
	return false


func _source_check() -> void:
	for path in ["res://scripts/dungeon.gd", "res://scripts/dungeon_rooms.gd"]:
		var f := FileAccess.open(path, FileAccess.READ)
		var txt: String = f.get_as_text() if f else ""
		# Code only — the header COMMENT says "no Screamer.trigger()" in as many words.
		var code := ""
		for line in txt.split("\n"):
			if not line.strip_edges().begins_with("#"):
				code += line + "\n"
		_ok("%s contains no Screamer.trigger(" % path.get_file(), txt != "" and not code.contains("Screamer.trigger("))
	# And the constants the user chose.
	_ok("CATCH_PANIC is 20", float(_level.get("CATCH_PANIC")) == 20.0)
	_ok("STARTLE_PANIC is 12", float(_level.get("STARTLE_PANIC")) == 12.0)


func _stage_statue() -> void:
	# Pick a statue, make it real, put it in contact and let it do what it does on contact.
	var statues: Array = _level.get("_still_ones")
	_ok("there are statues to test", statues.size() > 0, "%d" % statues.size())
	if statues.is_empty():
		_stage = 3
		return
	_statue = statues[0]
	_statue.set("is_dud", false)
	_ok("the statue is non-lethal", not bool(_statue.get("lethal")))
	_panic_before = _panic()
	# Contact means reaching the player: the shipping `_lunge()` is the branch that used to kill.
	_statue.call("_lunge")
	_stage = 2
	_t = 0.0


func _stage_frame() -> void:
	var frames: Array = _level.get("_frames")
	if frames.is_empty():
		_ok("there are frames to test", false)
		return
	var f = frames[0]
	_ok("the frame is non-lethal", not bool(f.get("lethal")))
	f.call("set_ignites", true)
	var before := _panic()
	f.call("_burn_out")   # the end of the 3 s wind-up that used to be Screamer.trigger()
	_ok("frame: the burn-out is not a death", not bool(root.get_node("Screamer").get("_is_triggering")))
	_ok("frame: the burn-out charges nothing extra (gaze was the price)", absf(_panic() - before) < 0.01)
	_ok("frame: it is burnt and inert", bool(f.call("is_burnt")))


func _stage_catch_begin() -> void:
	_ok("the hunter exists", _hunter != null)
	if _hunter == null:
		return
	# Put it 3 m ahead with line of sight, awake, then let contact do what contact does.
	var fwd: Vector3 = -(_p.get_node("Camera3D") as Camera3D).global_transform.basis.z
	fwd.y = 0.0
	_level.call("_spawn_matron_at", _p.global_position + fwd.normalized() * 3.0, 60.0)
	_ok("the wave started", bool(_level.call("hunter_present")))
	_panic_before = _panic()
	_hunter.call("_contact")   # the shipping branch: `caught`, never Screamer.trigger()


func _stage_cue_begin() -> void:
	# Fresh player state, hunter 4 m ahead, chasing, with line of sight.
	if bool(_p.call("is_input_frozen")):
		_p.call("unfreeze_input")
	var fwd: Vector3 = -(_p.get_node("Camera3D") as Camera3D).global_transform.basis.z
	fwd.y = 0.0
	_level.call("_spawn_matron_at", _p.global_position + fwd.normalized() * 2.2, 60.0)
	_hunter.call("force_chase")
	_hunter.call("force_block", 5.0)   # hold it there so it does not walk into a second catch


func _report() -> bool:
	if _checks < 24:
		print("  FAIL only %d checks ran" % _checks)
		_fails += 1
	print("  %d checks, %d failed" % [_checks, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true
