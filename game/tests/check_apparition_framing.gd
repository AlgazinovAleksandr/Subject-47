extends SceneTree

# WHEN THE APPARITION APPEARS, IS IT ON SCREEN?
#
#   Godot --headless --path game --script res://tests/check_apparition_framing.gd
#
# ⚠️ NOTHING ASKED THIS BEFORE 2026-09-07, and the answer was routinely no. `apparition.gd` fans
# over `HEADINGS_DEG = [0, ±22, ±45, ±90, ±135, 180]` and takes the first heading with room; the
# camera's default 75 deg VERTICAL fov is ±53.75 deg horizontally at 16:9, so five of those ten
# are off-screen by construction, and `LATERAL_NUDGES` reaches ±1.6 m — a further 45 deg at the
# 1.6 m minimum distance. `check_apparition_clearance.gd` asserts the figure is not inside a wall
# and `_fits()`'s own line-of-sight ray is an OCCLUSION test, not a visibility one; its docstring
# claiming "can the player actually see it?" was simply wrong.
#
# ⚠️⚠️ IT IS A FAIRNESS PROPERTY, NOT A FRAMING ONE, which is why it is asserted rather than
# photographed. A HOLD apparition KILLS YOU FOR FLEEING and `_is_fleeing()` is *horizontal
# distance growing* — so a figure that materialises behind you turns walking forward into a flee,
# against something you have never seen, while `DREAD_RATE` charges the whole time. `SCARY.md`
# §8.11: never punish a player for a scare they could not have seen coming.
#
# ⚠️ THE SAMPLE IS DELIBERATELY HALF AND HALF, and the first version was not — it was uniformly
# hostile and produced "19 of 19 in frustum, 19 of 19 needed the turn", which is a pass that
# proves only the fallback. Each pass needs its own poses:
#   EASY    one end of a long room, level pitch, looking down its axis. The in-frame pass should
#           find a spot in front of the player and the camera should NOT be taken away from them.
#   HOSTILE pressed against a wall facing it, pitched at the floor or the ceiling. These exhaust
#           the forward headings, and they are the cases the player actually reported.
# Asserted separately, because "always on screen" is trivially true if the camera is seized every
# single time — and a scripted turn on every appearance is a cutscene, not a scare.

const LEVEL := "res://scenes/level_1.tscn"
const SAMPLES := 24
const SETTLE_PER := 0.9      # past TURN_TIME 0.45 + TURN_SETTLE 0.10, with room to spare
const CHEST := Vector3(0, 1.2, 0)

var _fails := 0
var _checks := 0
var _t := 0.0
var _wall := 0.0
var _i := -1
var _armed := false
var _level: Node = null
var _player: CharacterBody3D = null
var _cam: Camera3D = null
var _ap: Node3D = null
var _poses: Array = []
var _in_frame := 0
var _turned := 0
var _skipped := 0
var _turned_by := {}
var _placed_by := {}
# 2026-09-10 — the arrival is CLOSE and LOUD (the user's call): every placement's horizontal
# distance must sit inside the range the script names, and the shared screamer must be playing
# at the figure by the time it has resolved.
var _dist_min := INF
var _dist_max := 0.0
var _dist_bad := 0
var _sting_ok := 0
var _sting_missing := 0
# ⚠️ `load()` in `_initialize`, never the bare class name and never `preload`. Calling
# `Apparition.spawn()` from a SceneTree script fails at runtime with "Nonexistent function
# 'spawn' in base 'GDScript'" — measured — and a `preload` would compile the script before the
# autoloads register, which `check_creature_anim.gd:18` documents costing it a hang.
var AP: GDScript
var RULE_HOLD := 0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _initialize() -> void:
	AP = load("res://scripts/apparition.gd")
	RULE_HOLD = int(AP.get_script_constant_map().get("Rule", {}).get("HOLD", 0))
	Engine.time_scale = 5.0
	seed(4242)
	change_scene_to_file(LEVEL)


func _build_poses() -> void:
	var rooms: Array = _level.get_script().get_script_constant_map().get("ROOMS", [])
	var easy: Array = []
	var hostile: Array = []
	for r in rooms:
		var pos: Vector2 = r["pos"]
		var size: Vector2 = r["size"]
		var half: Vector2 = size * 0.5
		# EASY: stand near one end of the room's LONG axis and look down it, level. A room only
		# qualifies if it is long enough to hold a figure at the 2.5 m minimum spawn distance
		# with the 0.5 m wall margin either side.
		var along_x: bool = size.x >= size.y
		var run: float = (size.x if along_x else size.y)
		if run >= 7.0:
			var back := Vector2(-half.x + 1.0, 0.0) if along_x else Vector2(0.0, -half.y + 1.0)
			easy.append({
				"p": Vector3(pos.x + back.x, 0.2, pos.y + back.y),
				"yaw": atan2(back.x, back.y),   # face back along the axis, into the room
				"pitch": 0.0, "kind": "easy",
			})
		# HOSTILE: hard against each wall, facing it, at three pitches.
		for off in [Vector2(half.x - 0.6, 0.0), Vector2(-half.x + 0.6, 0.0),
				Vector2(0.0, half.y - 0.6), Vector2(0.0, -half.y + 0.6)]:
			hostile.append({
				"p": Vector3(pos.x + off.x, 0.2, pos.y + off.y),
				"yaw": atan2(-off.x, -off.y),
				"pitch": [0.0, -0.7, 0.5][randi() % 3], "kind": "hostile",
			})
	easy.shuffle()
	hostile.shuffle()
	easy.resize(mini(SAMPLES / 2, easy.size()))
	hostile.resize(mini(SAMPLES - easy.size(), hostile.size()))
	_poses = easy + hostile
	_poses.shuffle()


func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 240.0:
		print("TIMEOUT at sample %d" % _i)
		return _report()
	_t += delta
	if _t < 2.5 or current_scene == null:
		return false
	if _level == null:
		_level = current_scene
		_player = _level.get_node_or_null("Player") as CharacterBody3D
		_cam = _player.get_node_or_null("Camera3D") as Camera3D if _player else null
		if _player == null or _cam == null:
			print("no player/camera")
			return _report()
		_build_poses()
		print("== APPARITION FRAMING ==  %d hostile poses in the Lab" % _poses.size())

	if not _armed:
		_i += 1
		if _i >= _poses.size():
			return _finish()
		var pose: Dictionary = _poses[_i]
		_player.global_position = pose["p"]
		_player.rotation.y = float(pose["yaw"])
		_cam.rotation.x = float(pose["pitch"])
		_player.velocity = Vector3.ZERO
		_player.force_update_transform()
		_cam.force_update_transform()
		if is_instance_valid(_ap):
			_ap.queue_free()
		_ap = AP.call("spawn", _level, RULE_HOLD, Vector3.ZERO, true)
		_ap.appear()
		_armed = true
		_t = 0.0
		return false

	if _t < SETTLE_PER:
		return false
	_armed = false
	# `appear()` frees itself when nothing legible fits — a legitimate outcome, and NOT a
	# framing failure. Counted separately so it cannot quietly become the pass condition.
	if not is_instance_valid(_ap) or not _ap.visible:
		_skipped += 1
		return false
	var seen: bool = _cam.is_position_in_frustum(_ap.global_position + CHEST)
	if seen:
		_in_frame += 1
	# Distance: the script's own range, plus the widest lateral nudge it is allowed to add.
	var consts: Dictionary = AP.get_script_constant_map()
	var d := Vector2(_ap.global_position.x - _player.global_position.x,
		_ap.global_position.z - _player.global_position.z).length()
	_dist_min = minf(_dist_min, d)
	_dist_max = maxf(_dist_max, d)
	var nudge_max := 0.0
	for n in (consts.get("LATERAL_NUDGES", []) as Array):
		nudge_max = maxf(nudge_max, absf(float(n)))
	var lo := float(consts.get("MIN_DIST", 1.6)) - 0.05
	var hi := sqrt(pow(float(consts.get("APPEAR_DIST_MAX", 3.0)), 2.0) + nudge_max * nudge_max) + 0.05
	if d < lo or d > hi:
		_dist_bad += 1
		print("     OUT OF RANGE at pose %d: %.2f m (allowed %.2f..%.2f)" % [_i, d, lo, hi])
	# The sting: named, at the figure, the shared screamer, and actually playing.
	var sting := _ap.get_node_or_null("ArrivalSting") as AudioStreamPlayer3D
	var sting_base := ""
	if sting and sting.stream:
		sting_base = sting.stream.resource_path.get_file().get_basename()
	if sting and sting.playing and sting_base == String(consts.get("ARRIVAL_STING_DEFAULT", "")):
		_sting_ok += 1
	else:
		_sting_missing += 1
		print("     NO ARRIVAL STING at pose %d: node=%s playing=%s stream=%s"
			% [_i, str(sting != null), str(sting.playing if sting else false), sting_base])
	var kind := String(_poses[_i]["kind"])
	_placed_by[kind] = int(_placed_by.get(kind, 0)) + 1
	if bool(_ap.get("_turned")):
		_turned += 1
		_turned_by[kind] = int(_turned_by.get(kind, 0)) + 1
	if not seen:
		print("     OFF SCREEN at pose %d: player %s yaw %.0f deg, figure %s, turned=%s"
			% [_i, str(_player.global_position), rad_to_deg(_player.rotation.y),
				str(_ap.global_position), str(_ap.get("_turned"))])
	_player.unfreeze_input()
	return false


func _finish() -> bool:
	var placed: int = _poses.size() - _skipped
	_ok("enough apparitions were actually placed to mean anything", placed >= 12,
		"%d placed, %d skipped (nothing legible fitted — a legitimate outcome)"
			% [placed, _skipped])
	_ok("EVERY placed apparition ends up on screen", _in_frame == placed,
		"%d of %d in frustum; %d of them needed the scripted camera turn"
			% [_in_frame, placed, _turned])
	_ok("EVERY placed apparition is CLOSE — inside the 2026-09-10 range the script names",
		placed > 0 and _dist_bad == 0,
		"%d out of range; measured %.2f..%.2f m" % [_dist_bad, _dist_min, _dist_max])
	_ok("...and its arrival sting is the shared screamer, playing at the figure",
		placed > 0 and _sting_ok == placed,
		"%d of %d had it (%d missing)" % [_sting_ok, placed, _sting_missing])
	var e_placed: int = int(_placed_by.get("easy", 0))
	var e_turned: int = int(_turned_by.get("easy", 0))
	var h_placed: int = int(_placed_by.get("hostile", 0))
	var h_turned: int = int(_turned_by.get("hostile", 0))
	print("     easy %d placed / %d turned      hostile %d placed / %d turned"
		% [e_placed, e_turned, h_placed, h_turned])
	_ok("EASY poses are served by the in-frame pass, WITHOUT seizing the camera",
		e_placed >= 4 and e_turned * 3 <= e_placed,
		"%d of %d easy placements needed the turn — the first pass should carry these"
			% [e_turned, e_placed])
	_ok("CONTROL — the fallback IS reached by the hostile poses",
		h_placed >= 4 and h_turned > 0,
		"%d of %d hostile placements needed it. If this is 0 the second pass is untested"
			% [h_turned, h_placed])
	return _report()


func _report() -> bool:
	print("== %d checks, %d failed ==" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return true
