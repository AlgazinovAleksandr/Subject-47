extends SceneTree

# THE VOID (level_3.tscn) — the mechanics behind the three impossible spaces, and the roster.
#
#   * the loop corridor: the seam sends a +z walker back exactly one period with HEADING and
#     VELOCITY preserved (backrooms.gd's teleport zeroes velocity; seamlessness needs it kept),
#     ignores a -z walker, and stops for good once the corridor's note has been read
#   * the floating tiles: CreatureD is watch-only while the player is on them (it watches, it
#     never steps) and stalks again the moment they are off — with a live control that drops
#     the level's tile rect and requires it to step
#   * six stalkers, every one with the scrape tell and every one still lethal (D10)
#   * five safe notes + the twist + three read-to-die traps, the twist inside the Sanctum
#   * the three DarkZones, the DreadZone over the far wing, the Threshold's CalmZone
#   * save_progress() / _restore_progress() round-trip notes_read / loop_broken / loop_laps
#   * a player below FALL_Y arms the screamer on the next frame (asserted, then quit before
#     the reload)
#
# Usage: Godot --headless --path game --script res://tests/check_void.gd

const SCENE := "res://scenes/level_3.tscn"

var _fails := 0
var _checks := 0
var _started := false
var _settle := 0
var _level: Node = null
var _p: CharacterBody3D = null
var _stage := 0
var _wait := 0          # physics ticks still to wait in the current stage
var _last_phys := -1
var _d_start := Vector3.ZERO
var _tile_rect := Rect2()
var _yaw0 := 0.0
var _lap_ticks := 0
var _stalkers: Dictionary = {}


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _ticks() -> int:
	var pf := Engine.get_physics_frames()
	var t: int = 1 if _last_phys < 0 else maxi(0, pf - _last_phys)
	_last_phys = pf
	return t


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		change_scene_to_file(SCENE)
		return false
	_settle += 1
	if _settle < 14:
		return false
	if _level == null:
		_level = current_scene
		if _level == null or not _level.has_method("get_stalkers"):
			print("  FAIL level_3.tscn did not load, or level_3.gd failed to parse")
			_fails += 1
			return _report()
		_p = _level.get_node_or_null("Player") as CharacterBody3D
		if _p == null:
			_ok("player exists", false)
			return _report()
		_structural()
		_stage = 1
		return false
	if current_scene != _level and _stage < 9:
		_ok("the level did not reload mid-test", false, "stage %d" % _stage)
		return _report()
	var t := _ticks()
	if _wait > 0:
		_wait -= t
		if _stage == 4:
			_watch_lap(t)
		return false
	match _stage:
		1: _begin_watch_only()
		2: _end_watch_only()
		3: _watch_control()
		4: _begin_lap()
		5: _end_lap()
		6: _reverse()
		7: _broken()
		8: _snapshot()
		9: _fall()
		10: return _fall_result()
	return false


# ── structure ─────────────────────────────────────────────────────────────────
func _structural() -> void:
	_stalkers = _level.call("get_stalkers")
	_ok("six stalkers", _stalkers.size() == 6, str(_stalkers.keys()))
	var tells := 0
	var lethal := 0
	for s in _stalkers.values():
		if bool(s.get("scrape_tell")):
			tells += 1
		if bool(s.get("lethal")):
			lethal += 1
	_ok("every stalker carries the scrape tell", tells == _stalkers.size(), "%d of %d" % [tells, _stalkers.size()])
	_ok("every stalker is still lethal (D10: the Void keeps its teeth)", lethal == _stalkers.size(), "%d of %d" % [lethal, _stalkers.size()])

	var safe := 0
	var trap := 0
	var twist: Node3D = null
	for c in _level.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("note.gd"):
			if bool(c.get("is_trap")):
				trap += 1
			else:
				safe += 1
			if bool(c.get("is_twist_note")):
				twist = c
	_ok("five safe notes plus the twist (six non-trap)", safe == 6, "%d" % safe)
	_ok("three read-to-die trap notes", trap == 3, "%d" % trap)
	_ok("exactly one twist note", twist != null)
	if twist:
		var sr: Rect2 = _level.call("_room_rect", "Sanctum")
		_ok("the twist note hangs inside the Sanctum",
			sr.has_point(Vector2(twist.global_position.x, twist.global_position.z)),
			"%s in %s" % [twist.global_position, sr])

	var dark := 0
	var dread := 0
	var calm := 0
	for c in _level.get_children():
		if c is DarkZone:
			dark += 1
		elif c is DreadZone:
			dread += 1
		elif c is CalmZone:
			calm += 1
	_ok("three DarkZones (tile hall, morgue, child's room)", dark == 3, "%d" % dark)
	_ok("one DreadZone over the far wing", dread == 1, "%d" % dread)
	_ok("one CalmZone at the Threshold", calm == 1, "%d" % calm)

	var exit := _level.get_node_or_null("ExitDoor")
	var back := _level.get_node_or_null("BackDoor")
	_ok("ExitDoor waits on the twist note", exit != null and int(exit.get("unlock_condition")) == 3)
	_ok("BackDoor goes back", back != null and bool(back.get("goes_back")))
	_tile_rect = _level.call("tile_rect")
	_ok("the tile hall rect is published", _tile_rect.size.x > 5.0, str(_tile_rect))


# ── CreatureD watches from the far side and never steps while you are on the tiles ──
func _begin_watch_only() -> void:
	print("--- the bridge stalker ---")
	var d = _stalkers.get("D")
	# The west landing pad: inside the tile rect, with line of sight to D through the
	# Morgue doorway (the line crosses x = -9 at z ~46.1, inside the 1.8 m opening).
	_p.global_position = Vector3(-7.7, 0.1, 45.5)
	_p.force_update_transform()
	_p.call("ai_look_at", Vector3(0.0, 1.3, 45.5))   # looking east: D is not watched
	d.set("_awakened", true)
	d.set("_age", 10.0)
	_d_start = (d.get("_body") as Node3D).global_position
	_stage = 2
	_wait = 120


func _end_watch_only() -> void:
	var d = _stalkers.get("D")
	var moved: float = ((d.get("_body") as Node3D).global_position - _d_start).length()
	_ok("D is watch-only while the player stands on the tiles", bool(d.get("watch_only")))
	_ok("…and did not step in 2 s, awake, unwatched, with line of sight",
		moved < 0.05, "moved %.2f m" % moved)
	# CONTROL: with the level's tile rect emptied the flag drops and it must advance.
	_level.set("_tile_rect", Rect2())
	_stage = 3
	_wait = 90


func _watch_control() -> void:
	var d = _stalkers.get("D")
	var moved: float = ((d.get("_body") as Node3D).global_position - _d_start).length()
	_ok("CONTROL: off the tiles the flag drops", not bool(d.get("watch_only")))
	_ok("CONTROL: and D steps toward the player", moved > 0.3, "moved %.2f m in 1.5 s" % moved)
	_level.set("_tile_rect", _tile_rect)
	# The creatures are out of the picture for the rest of the run.
	for s in _stalkers.values():
		if is_instance_valid(s):
			_level.remove_child(s)
			s.queue_free()
	_stage = 4


# ── the loop seam ─────────────────────────────────────────────────────────────
func _begin_lap() -> void:
	print("--- the loop corridor ---")
	_p.global_position = Vector3(12.5, 0.1, 30.0)
	_p.force_update_transform()
	_p.set("ai_active", true)
	_p.call("ai_look_at", Vector3(12.5, 1.3, 44.0))
	_p.set("ai_move_dir", Vector2(0.0, -1.0))
	_yaw0 = _p.rotation.y
	_lap_ticks = 0
	_stage = 4
	_wait = 400


func _watch_lap(t: int) -> void:
	_lap_ticks += t
	if int(_level.call("loop_laps")) >= 1:
		_wait = 0
		_stage = 5


func _end_lap() -> void:
	var laps: int = int(_level.call("loop_laps"))
	_ok("walking +z through the seam counts a lap", laps >= 1, "%d after %d ticks" % [laps, _lap_ticks])
	_ok("…and puts the player one period back (z 15..18)",
		_p.global_position.z > 15.0 and _p.global_position.z < 18.5, "z %.2f" % _p.global_position.z)
	_ok("heading is preserved across the seam", absf(angle_difference(_yaw0, _p.rotation.y)) < 0.01,
		"yaw %.3f -> %.3f" % [_yaw0, _p.rotation.y])
	_ok("velocity is preserved across the seam (not zeroed)", _p.velocity.z > 1.0,
		"v.z %.2f" % _p.velocity.z)
	_stage = 6
	_reverse_setup()


func _reverse_setup() -> void:
	# Walk BACK through the seam: it must not fire (walking out of the loop is allowed).
	_p.global_position = Vector3(12.5, 0.1, 33.5)
	_p.force_update_transform()
	_p.call("ai_look_at", Vector3(12.5, 1.3, 15.0))
	_p.set("ai_move_dir", Vector2(0.0, -1.0))
	_wait = 150


func _reverse() -> void:
	_ok("walking -z through the seam does NOT teleport", int(_level.call("loop_laps")) == 1
		and _p.global_position.z < 31.5 and _p.global_position.z > 20.0,
		"laps %d, z %.2f" % [int(_level.call("loop_laps")), _p.global_position.z])
	# Break the loop the way the game does, then walk +z through the seam again.
	_level.call("_on_loop_note_read")
	_p.global_position = Vector3(12.5, 0.1, 30.0)
	_p.force_update_transform()
	_p.call("ai_look_at", Vector3(12.5, 1.3, 44.0))
	_p.set("ai_move_dir", Vector2(0.0, -1.0))
	_stage = 7
	_wait = 250


func _broken() -> void:
	_ok("once the note is read the seam is inert", bool(_level.call("loop_broken"))
		and int(_level.call("loop_laps")) == 1 and _p.global_position.z > 33.5,
		"laps %d, z %.2f" % [int(_level.call("loop_laps")), _p.global_position.z])
	_p.set("ai_move_dir", Vector2.ZERO)
	_p.set("ai_active", false)
	_stage = 8


# ── snapshot ─────────────────────────────────────────────────────────────────
func _snapshot() -> void:
	print("--- save / restore ---")
	_level.call("_mark_note", "NoteWard")
	_level.set("_loop_laps", 2)
	var d: Dictionary = _level.call("save_progress")
	_ok("save_progress carries notes_read / loop_broken / loop_laps",
		d.has("notes_read") and d.has("loop_broken") and d.has("loop_laps"), str(d))
	root.get_node("GameState").call("save_level_progress", 8, d)
	_level.set("_notes_read", [])
	_level.set("_loop_broken", false)
	_level.set("_loop_laps", 0)
	_level.call("_restore_progress")
	_ok("…and _restore_progress puts them back",
		(_level.get("_notes_read") as Array).has("NoteWard") and bool(_level.call("loop_broken"))
		and int(_level.call("loop_laps")) == 2,
		"notes %s broken %s laps %d" % [_level.get("_notes_read"), _level.call("loop_broken"), _level.call("loop_laps")])
	root.get_node("GameState").call("save_level_progress", 8, {})
	_stage = 9


# ── the abyss ─────────────────────────────────────────────────────────────────
func _fall() -> void:
	print("--- the abyss ---")
	_p.global_position = Vector3(-3.0, -5.0, 45.5)
	_p.force_update_transform()
	_stage = 10
	_wait = 2


func _fall_result() -> bool:
	var scr := root.get_node("Screamer")
	_ok("a player below FALL_Y arms the screamer on the next frame", bool(scr.get("_is_triggering")))
	return _report()


func _report() -> bool:
	if _checks < 20:
		print("  FAIL only %d checks ran — did a stage abort?" % _checks)
		_fails += 1
	print("  %d checks, %d failed" % [_checks, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true
