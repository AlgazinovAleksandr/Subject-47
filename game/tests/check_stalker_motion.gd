extends SceneTree

# Exercise CreatureStalker's shipping physics and visible body, including paths a
# clear eye-ray cannot validate: capsule corners, narrow doors, ledges and retreats.
# Godot --headless --path game --script res://tests/check_stalker_motion.gd

const DEADLINE_MS := 25000
const VISUAL_PATH := "res://scripts/void_creature_visual.gd"
var _started_at := 0
var _started := false
var _finished := false
var _checks := 0
var _fails: Array[String] = []
var _motion_samples := 0
var _pose_samples := 0
var _world: Node3D
var _player: CharacterBody3D
var _camera: Camera3D
var _stalker: Node3D
var _body: StaticBody3D
var _stalker_script: Script
var _caught := 0
var _toppled := 0


func _initialize() -> void:
	_started_at = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	if not _finished and Time.get_ticks_msec() - _started_at > DEADLINE_MS:
		_ok("global timeout did not expire", false)
		_finish()
		return true
	if not _started:
		_started = true
		_run.call_deferred()
	return _finished


func _ok(label: String, condition: bool, detail: String = "") -> void:
	_checks += 1
	print("  %s %s%s" % ["PASS" if condition else "FAIL", label,
		" — " + detail if detail != "" else ""])
	if not condition:
		_fails.append(label)


func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame


func _box(where: Vector3, size: Vector3, label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = where
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	_world.add_child(body)
	return body


func _place(where: Vector3) -> void:
	_body.global_position = where
	_body.rotation = Vector3.ZERO
	_body.force_update_transform()


func _move(displacement: Vector3) -> Vector3:
	_motion_samples += 1
	var before := _body.global_position
	var result: Vector3 = _stalker.call("_move_safely", displacement)
	_ok("motion reports the visible body's actual displacement", result.is_equal_approx(_body.global_position - before))
	return result


func _overlaps_at(where: Vector3) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.29
	shape.height = 1.68
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, where + Vector3(0, 0.85, 0))
	query.exclude = [_body.get_rid(), _player.get_rid()]
	return not _world.get_world_3d().direct_space_state.intersect_shape(query).is_empty()


func _floor_at(where: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(where + Vector3(0, 0.1, 0), where - Vector3(0, 0.2, 0))
	query.exclude = [_body.get_rid(), _player.get_rid()]
	return not _world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _pose() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	# Compare actual mesh transforms, never gait labels or the outer Node3D position.
	var meshes := _body.find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		var local: Transform3D = _body.global_transform.affine_inverse() * mesh.global_transform
		for column in [local.origin, local.basis.x, local.basis.y, local.basis.z]:
			out.append(column.x)
			out.append(column.y)
			out.append(column.z)
	_pose_samples += meshes.size()
	return out


func _pose_drift(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	if a.is_empty() or a.size() != b.size():
		return INF
	var worst := 0.0
	for i in range(a.size()):
		worst = maxf(worst, absf(a[i] - b[i]))
	return worst


func _run() -> void:
	_stalker_script = load("res://scripts/creature_stalker.gd") as Script
	var visual := load(VISUAL_PATH) as Script
	_ok("shipping stalker and Void mesh scripts load", _stalker_script != null and visual != null)
	if not _fails.is_empty():
		_finish()
		return
	_world = Node3D.new()
	_world.name = "StalkerPhysicsFixture"
	root.add_child(_world)
	current_scene = _world
	_box(Vector3(0, -0.1, 0), Vector3(20, 0.2, 20), "Floor")
	_box(Vector3(15, -0.1, 0), Vector3(6, 0.2, 4), "FarSideOfGap")
	_box(Vector3(0, 1.5, 2), Vector3(3, 3, 0.3), "Wall")
	_box(Vector3(3.8, 1.5, -1), Vector3(1.2, 3, 0.3), "DoorLeft")
	_box(Vector3(6.2, 1.5, -1), Vector3(1.2, 3, 0.3), "DoorRight")
	_player = CharacterBody3D.new()
	_player.name = "Player"
	_player.add_to_group("player")
	_player.position = Vector3(-5, 0, -5)
	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.position.y = 1.65
	_player.add_child(_camera)
	_world.add_child(_player)
	_stalker = _stalker_script.new() as Node3D
	_stalker.position = Vector3(-5, 0, 1)
	_stalker.set("visual_script", visual)
	_world.add_child(_stalker)
	_stalker.set_physics_process(false)
	_body = _stalker.get("_body") as StaticBody3D
	_ok("clearance APIs and the actual collider are present", _body != null
		and _stalker.has_method("_move_safely") and _stalker.has_method("relocate_safely"))
	if not _fails.is_empty():
		_finish()
		return
	await _ticks(3)

	_place(Vector3(-5, 0, -2))
	var moved := _move(Vector3(0, 0, 4))
	_ok("CONTROL: four metres of supported empty floor remain traversable", moved.distance_to(Vector3(0, 0, 4)) < 0.03)
	_ok("CONTROL: collision query detects the blocking wall", _overlaps_at(Vector3(0, 0, 2)))
	_ok("CONTROL: empty floor does not register as a body obstruction", not _overlaps_at(Vector3(-5, 0, 0)))
	_place(Vector3.ZERO)
	_move(Vector3(0, 0, 4))
	_ok("a large step stops before the wall without overlap", _body.global_position.z > 0.4
		and _body.global_position.z < 1.58 and not _overlaps_at(_body.global_position), str(_body.global_position))

	_place(Vector3(1.72, 0, 0))
	var ray := PhysicsRayQueryParameters3D.create(Vector3(1.72, 0.9, 0), Vector3(1.72, 0.9, 4))
	ray.exclude = [_body.get_rid(), _player.get_rid()]
	_ok("corner fixture has a clear centre ray", _world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty())
	_move(Vector3(0, 0, 4))
	_ok("capsule sweep still catches the wall corner", _body.global_position.z < 2.0
		and not _overlaps_at(_body.global_position))

	_place(Vector3(0, 0, 1.4))
	moved = _move(Vector3(1.0, 0, 1.0))
	_ok("diagonal approach slides along a wall without overlap", moved.x > 0.7
		and _body.global_position.z < 1.58 and not _overlaps_at(_body.global_position))

	_place(Vector3(5, 0, -3))
	moved = _move(Vector3(0, 0, 4))
	_ok("the body passes through a genuinely clear doorway", moved.z > 3.95)
	_place(Vector3(4.5, 0, -3))
	_move(Vector3(0, 0, 4))
	_ok("door jamb clearance uses body width", _body.global_position.z < -1.0
		and not _overlaps_at(_body.global_position))

	_place(Vector3(9, 0, 0))
	_ok("CONTROL: a destination beyond the gap has floor", _floor_at(Vector3(15, 0, 0)))
	_ok("CONTROL: the middle of the gap has no floor", not _floor_at(Vector3(11, 0, 0)))
	_move(Vector3(6, 0, 0))
	_ok("floor support is checked throughout a step across a gap", _body.global_position.x > 9.1
		and _body.global_position.x < 9.8 and _floor_at(_body.global_position + Vector3(0.24, 0, 0)))

	_stalker.set("leash", Rect2(-7, -3, 2, 6))
	_place(Vector3(-6, 0, 0))
	_move(Vector3(4, 0, 0))
	_ok("swept movement preserves the Nightmare leash", _body.global_position.x <= -5.0
		and _body.global_position.x > -5.05)
	_stalker.set("leash", Rect2())
	_place(Vector3.ZERO)
	_stalker.set("_player", _player)
	_stalker.set("_camera", _camera)
	_player.global_position = Vector3(0, 0, -3)
	_stalker.call("_dismiss")
	# ⭐ 2026-09-20: the dismissal used to MOVE the body in the observed frame — the one place the
	# "never moves while watched" rule was broken, and what the player saw. It is deferred now.
	_ok("dismissal in the observed frame moves NOTHING", _body.global_position.distance_to(Vector3.ZERO) < 0.001
		and bool(_stalker.call("retreat_pending")), str(_body.global_position))
	_stalker.call("_execute_retreat")
	_ok("the deferred three-metre retreat stops at the last valid wall position", _body.global_position.z > 0.4
		and _body.global_position.z < 1.58 and not _overlaps_at(_body.global_position))
	_ok("...and the pending retreat is spent", not bool(_stalker.call("retreat_pending")))
	_place(Vector3.ZERO)
	var reached := bool(_stalker.call("relocate_safely", Vector3(0, 0, 4)))
	_ok("blocked repositioning refuses its target and remains before the wall", not reached
		and _body.global_position.z < 1.58 and not _overlaps_at(_body.global_position))
	_place(Vector3(-5, 0, 0))
	_ok("clear repositioning succeeds", bool(_stalker.call("relocate_safely", Vector3(-5, 0, 3))))

	_place(Vector3(-5, 0, 1))
	_player.global_position = Vector3(-5, 0, -4)
	_camera.look_at(_body.global_position + Vector3(0, 0.9, 0))
	_stalker.set("_age", 6.0)
	_stalker.set_physics_process(true)
	await _ticks(3)
	var watched_position := _body.global_position
	var watched_pose := _pose()
	await _ticks(24)
	_ok("watching freezes the collider in real physics frames", _body.global_position.distance_to(watched_position) < 0.0001)
	_ok("watching freezes actual fractured mesh transforms", _pose_drift(watched_pose, _pose()) < 0.0001)
	_camera.look_at(Vector3(-5, 1.65, -10))
	await _ticks(24)
	_ok("CONTROL: looking away resumes movement", _body.global_position.distance_to(watched_position) > 0.3)
	_ok("CONTROL: the same visible fragments animate when advancing", _pose_drift(watched_pose, _pose()) > 0.002)

	# ⭐ THE STARE, on the real physics path (2026-09-20). Stare it into a dismissal: the body must
	# not move by a millimetre while watched — dismissal frame included — and the 3 m retreat must
	# land on the first frame the camera is elsewhere. The whisper rides the same gaze.
	_stalker.set("whisper", true)
	_camera.look_at(_body.global_position + Vector3(0, 0.9, 0))
	await _ticks(3)
	var pre_dismiss := _body.global_position
	_stalker.set("_stare_off_timer", 3.9)
	await _ticks(12)
	_ok("stare time counts continuous gaze from the real camera", float(_stalker.call("stare_time")) > 0.15)
	_ok("the dismissal on the real path is DEFERRED: nothing moved while watched",
		_body.global_position.distance_to(pre_dismiss) < 0.0001 and bool(_stalker.call("retreat_pending")),
		"moved %.4f" % _body.global_position.distance_to(pre_dismiss))
	_ok("the whisper rises with the gaze", float(_stalker.call("whisper_level")) > 0.02)
	var whisper_node: AudioStreamPlayer3D = _stalker.get("_whisper")
	_ok("...on a positional loop that is playing", whisper_node != null and whisper_node.playing)
	_camera.look_at(Vector3(-5, 1.65, -10))
	await _ticks(2)
	_ok("the retreat lands on the first unobserved frame", _body.global_position.distance_to(pre_dismiss) > 0.5
		and not bool(_stalker.call("retreat_pending")), "moved %.2f" % _body.global_position.distance_to(pre_dismiss))
	_ok("the stare resets on a look-away", float(_stalker.call("stare_time")) == 0.0)
	await _ticks(60)
	_ok("the whisper falls after a look-away", float(_stalker.call("whisper_level")) < 0.01)
	_stalker.set("whisper", false)
	_stalker.set_physics_process(false)

	# ⭐ Pass 2 (2026-09-20 evening): `stalk_speed` is an export the Void sets to 3.0; the default
	# stays STALK_SPEED so every other caller is byte-identical. Measured on the real physics path.
	var travel: Dictionary = {}
	for speed in [1.25, 3.0]:
		_stalker.set("stalk_speed", speed)
		_stalker.set("_retreat_pending", false)
		_stalker.set("_fired", false)
		_place(Vector3(-5, 0, 1))
		_player.global_position = Vector3(-5, 0, -5.5)
		_camera.look_at(Vector3(-5, 1.65, -12))   # looking away: it advances
		_stalker.set("_awakened", true)
		_stalker.set("_age", 6.0)
		var from := _body.global_position
		_stalker.set_physics_process(true)
		await _ticks(12)
		_stalker.set_physics_process(false)
		travel[speed] = _body.global_position.distance_to(from)
	_ok("the default speed is unchanged (1.25 m/s over 12 ticks = 0.25 m)", absf(float(travel[1.25]) - 0.25) < 0.05, "%.3f m" % float(travel[1.25]))
	_ok("a 3.0 m/s stalker covers 2.4x the distance per tick", absf(float(travel[3.0]) / maxf(float(travel[1.25]), 0.001) - 2.4) < 0.25,
		"%.3f m vs %.3f m" % [float(travel[3.0]), float(travel[1.25])])
	_stalker.set("stalk_speed", 1.25)
	_player.global_position = Vector3(-5, 0, -4)   # where the sections below expect the player

	# A protected island must suppress contact as well as movement and gaze.
	_place(Vector3(-5, 0, -3.3))
	_stalker.set("protected_player_rect", Rect2(-6, -5, 2, 2))
	_stalker.set("_awakened", true)
	_stalker.set_physics_process(true)
	await _ticks(5)
	_ok("protected player cannot be killed by a nearby stalker", not bool(_stalker.get("_fired"))
		and not bool(root.get_node("Screamer").get("_is_triggering")))
	var scary: Node = _body.get_parent()
	_ok("protected player has no stalker gaze pressure", float(scary.get("scare_intensity")) == 0.0)
	_stalker.set_physics_process(false)
	_stalker.set("protected_player_rect", Rect2())

	# THE NIGHTMARE keeps the imported animated model and its nonfatal outcomes.
	var nightmare := _stalker_script.new() as Node3D
	nightmare.position = Vector3(-8, 0, -4)
	nightmare.set("lethal", false)
	nightmare.set("spark_reactive", true)
	_world.add_child(nightmare)
	nightmare.set_physics_process(false)
	nightmare.connect("caught", func() -> void: _caught += 1)
	nightmare.connect("toppled", func() -> void: _toppled += 1)
	_ok("default callers retain the imported creature animation", nightmare.get("_anim") != null
		and nightmare.get("_custom_visual") == null)
	var nightmare_body := nightmare.get("_body") as StaticBody3D
	var spark_start := nightmare_body.global_position
	nightmare.call("on_spark", Vector3(-5, 0, -4))
	_ok("Nightmare spark still advances one safe metre", absf(nightmare_body.global_position.distance_to(spark_start) - 1.0) < 0.03)
	nightmare.call("on_spark", nightmare_body.global_position + Vector3(0.5, 0, 0))
	_ok("Nightmare contact still catches and topples without death", _caught == 1 and _toppled == 1
		and bool(nightmare.call("has_fallen")) and not bool(root.get_node("Screamer").get("_is_triggering")))
	var dud := _stalker_script.new() as Node3D
	dud.position = Vector3(-7, 0, -5)
	dud.set("is_dud", true)
	_world.add_child(dud)
	await _ticks(3)
	_ok("Nightmare duds still topple on approach", bool(dud.call("has_fallen")))
	dud.queue_free()
	nightmare.queue_free()

	# Contact comes from the real update, then the visible body must move BEFORE
	# Screamer blacks out the world. The old outer-node teleport left this body still.
	_place(Vector3(-5, 0, -3))
	_stalker.set("_age", 6.0)
	_stalker.set("_awakened", true)
	var lunge_start := _body.global_position
	_stalker.set_physics_process(true)
	await create_timer(0.10, true, false, true).timeout
	_ok("contact begins a real lunge", bool(_stalker.get("_fired")))
	_ok("lunge moves the rendered inner body before the cut", _body.global_position.distance_to(lunge_start) > 0.15
		and not bool(root.get_node("Screamer").get("_is_triggering")))
	await create_timer(0.16, true, false, true).timeout
	_ok("completed visible lunge reaches the fatal screamer", bool(root.get_node("Screamer").get("_is_triggering")))
	root.get_node("GameState").call("invalidate_transition")
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_ok("nonzero movement and visible mesh samples were measured", _motion_samples >= 8 and _pose_samples >= 12,
		"%d moves / %d mesh samples" % [_motion_samples, _pose_samples])
	if _checks < 35:
		_ok("at least 35 independent assertions ran", false, "only %d" % _checks)
	for failure in _fails:
		print("  FAILED: " + failure)
	print("STALKER-MOTION %s: %d checks, %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _checks, _fails.size()])
	quit(0 if _fails.is_empty() else 1)
