extends SceneTree

# THE BREACH APPROACH, PASS 3 (2026-09-23): the effort door, the dark room, the escape told, and
# every floor prop solid. Driven through the REAL player: walked with `ai_move_dir`, the handle taken
# and the wheel fitted through `ai_interact()` (the E ray, `can_interact()`, the prompt), and the
# wheel TURNED by synthesized `InputEventMouseMotion` circles pushed into the viewport, the path a
# real mouse takes. No completion signal and no approach method is called to make anything happen.
#
#   Godot --headless --path game --script res://tests/check_breach_porthole.gd
#
# What it asserts:
#   * the Plenum's old doorway to Containment is BLOCKED (physics rays at three heights), against a
#     control ray through a doorway that is open;
#   * a ray hits the collider of EVERY floor-standing prop class (P6), each ray fired from the side
#     the player can stand on;
#   * the wheel refuses without the handle; the technician refuses while the victim is still heard;
#   * taking the handle: grip → eyes OPEN (the texture swap) → whisper → released → eyes CLOSED, in
#     that order, once; the carried line shows it; the pair has the same size and differs only a little;
#   * the wheel turns under mouse circles, DRIFTS BACK when released, lets go on E and on a movement
#     key, does not turn for a straight back-and-forth rub, unwinds the other way, and opens the door
#     after three turns in 10–20 s; the door then leaves a ray-clear doorway;
#   * the dark room: panic climbs, reaches the cap within ~15–20 s, NEVER exceeds 42 — not even
#     sprinting — and drains once outside; the spark light fires in 0.06–0.12 s bursts;
#   * the cell chamber: glass crunches underfoot, the CCTV screen is a shader quad fed by the
#     placeholder clip, the cell's spot is reserved; the snapshot round-trips.
const SCENE := "res://scenes/level_6_breach.tscn"
const PANIC_MAX := 50.0
var _level: Node
var _player: CharacterBody3D
var _approach: Node
var _fails := 0
var _checks := 0
var _started := 0


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	change_scene_to_file(SCENE)
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started > 360000:
		print("FAIL porthole test timed out")
		quit(1)
	return false


func _ok(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", label])


func _bind() -> void:
	_level = current_scene
	_player = _level.get_node("Player")
	_player.set("ai_active", true)
	_approach = _level.get("_approach")


func _panic() -> float:
	return float(_player.get("_panic"))


func _secs(t: float) -> void:
	var e := 0.0
	while e < t:
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second


func _walk(target: Vector3, max_t: float = 20.0) -> bool:
	var e := 0.0
	while Vector2(_player.position.x - target.x, _player.position.z - target.z).length() > 0.3:
		_player.call("ai_look_at", Vector3(target.x, 1.7, target.z))
		_player.set("ai_move_dir", Vector2(0, -1))
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second
		if e > max_t:
			_player.set("ai_move_dir", Vector2.ZERO)
			print("  walk stuck at %s heading for %s" % [_player.position, target])
			return false
	_player.set("ai_move_dir", Vector2.ZERO)
	await physics_frame
	return true


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_ray(q)


func _hit_name(r: Dictionary) -> String:
	return String((r["collider"] as Node).name) if not r.is_empty() else ""


func _find_all(node: Node, wanted: String, out: Array) -> Array:
	for c in node.get_children():
		if String(c.name) == wanted:
			out.append(c)
		_find_all(c, wanted, out)
	return out


func _is_under(n: Node, root: Node) -> bool:
	return n == root or root.is_ancestor_of(n)


# A mouse circle, pushed through the viewport exactly as the OS delivers motion (Viewport.push_input
# reaches `_input` headless, where Input.parse_input_event does not — godot#73557).
# ⚠️ The phase `_th` carries across calls: restarting it at 0 each call is a jump in the hand's
# direction, i.e. a fake reversal the wheel is right to read as unwinding.
var _th := 0.0

func _circle(seconds: float, turns_per_s: float, radius: float, way: float = 1.0) -> void:
	var e := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	while e < seconds:
		var w := TAU * turns_per_s * way
		var mm := InputEventMouseMotion.new()
		mm.relative = Vector2(-sin(_th), cos(_th)) * radius * absf(w) * dt * way
		root.push_input(mm)
		_th += w * dt
		await physics_frame
		e += dt


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	root.push_input(ev)
	await physics_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	root.push_input(up)
	await physics_frame


func _run() -> void:
	await create_timer(1.8).timeout
	_bind()
	var consts: Dictionary = _approach.get_script().get_script_constant_map()
	# ⚠️ PINNED, not read back: 42/50 is the USER's number (2026-09-23). Reading the constant would let
	# an edit to it move the goalposts with it.
	var cap := 42.0
	_ok("the dark room's cap is the user's 42/50 (%.1f)" % float(consts["DARK_PANIC_CAP"]), is_equal_approx(float(consts["DARK_PANIC_CAP"]), cap))

	# ---------------------------------------------------------------- 1. blocked, and the control
	var blocked := 0
	for y in [0.6, 1.2, 1.8]:
		var r := _ray(Vector3(-27.8, y, -26.0), Vector3(-24.2, y, -26.0))
		var who := _hit_name(r)
		if who.contains("Collapsed") or who.contains("FallenDuct"):
			blocked += 1
		print("  old doorway ray y=%.1f -> %s" % [y, _hit_name(r)])
	_ok("the Plenum's old doorway to Containment is blocked by the collapse at 3 heights (%d/3)" % blocked, blocked == 3)
	var ctrl := _ray(Vector3(-63.6, 1.2, -26.0), Vector3(-60.4, 1.2, -26.0))
	_ok("CONTROL: the same ray through the open Damaged->Plenum doorway is clear (%s)" % _hit_name(ctrl), ctrl.is_empty())
	var shut := _ray(Vector3(-44.5, 1.0, -31.4), Vector3(-44.5, 1.0, -34.6))
	_ok("the porthole door is shut: a ray through it hits the leaf (%s)" % _hit_name(shut), "Porthole" in _hit_name(shut))

	# ---------------------------------------------------------------- 2. every floor prop is solid (P6)
	# [node name, ray height]. Rays are fired at the prop's centre from 1.6 m away on each of the four
	# sides; the prop passes if its OWN collider is the first thing hit from at least one side.
	var classes := [["PressureReceiver", 0.9], ["EmptyInspectionRack", 0.6], ["InspectionWindowSill", 0.5],
		["CabinetDoor", 1.0], ["ReturnRiser", 1.0], ["ContainmentWallDamage", 1.0], ["CellJambL", 1.0],
		["BulkheadRail", 1.0], ["CableDrop", 1.8], ["DeadTechnician", 0.3], ["RestraintChair", 0.6],
		["InstrumentTrolley", 0.5], ["VialRack", 0.9], ["SpecimenCart", 0.5], ["Bucket", 0.15],
		["BodyFaceDown", 0.12], ["BodyGuard", 0.12], ["CCTVDesk", 0.5], ["ToppledChair", 0.25],
		["FallenDuct", 1.0], ["PortholeJambL", 1.0], ["GrilleHousingLow", 0.6], ["BreachedCell", 1.0]]
	var solid_classes := 0
	for spec in classes:
		var nodes := _find_all(_approach, String(spec[0]), [])
		var hit_any := false
		for n in nodes:
			var c: Vector3 = (n as Node3D).global_position
			c.y = float(spec[1])
			for dir in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
				var r := _ray(c + dir * 1.6, c)
				if not r.is_empty() and _is_under(r["collider"], n):
					hit_any = true
					break
			if hit_any:
				break
		if hit_any:
			solid_classes += 1
		else:
			print("  NOT SOLID: %s (%d instance(s))" % [spec[0], nodes.size()])
	_ok("a ray hits the collider of every floor prop class (%d of %d)" % [solid_classes, classes.size()],
		solid_classes == classes.size())

	# ---------------------------------------------------------------- 3. into the Plenum: the victim
	_player.global_position = Vector3(-78, 0.1, -26)
	_player.velocity = Vector3.ZERO
	await _secs(0.2)
	_ok("walked into the Plenum", await _walk(Vector3(-50.0, 0.1, -26.0)))
	var names: Array = Array(_approach.call("beat_names"))
	_ok("the victim is heard behind the porthole door", names.has("victim"))
	_ok("walked to the door", await _walk(consts["DOOR_STOP"]))
	# the wheel without its handle does nothing
	_player.call("ai_look_at", Vector3(-44.5, 1.05, -32.87))
	await physics_frame
	var wheel_target: Node = _player.call("ai_interact_target")
	_ok("the wheel is in reach of the real E ray (%s)" % (wheel_target.name if wheel_target else "nothing"),
		wheel_target != null and String(wheel_target.name) == "PortholeWheelInteract")
	_player.call("ai_interact")
	await physics_frame
	_ok("without the handle the wheel neither engages nor opens", not _approach.get("wheel_engaged")
		and not _approach.get("porthole_open") and not _player.call("is_input_frozen"))
	# the technician keeps silent while the victim is still being heard
	var tech_head := Vector3(-46.55, 0.55, -32.4)
	_player.call("ai_look_at", tech_head)
	await physics_frame
	var early: Node = _player.call("ai_interact_target")
	_ok("the technician offers nothing while the victim sequence is still playing", early == null)
	var waited := 0.0
	var tech_target: Node = null
	while waited < 20.0:
		_player.call("ai_look_at", tech_head)
		await physics_frame
		waited += 1.0 / Engine.physics_ticks_per_second
		tech_target = _player.call("ai_interact_target")
		if tech_target != null:
			break
	print("  the technician answered %.2f s after the door was reached" % waited)
	_ok("once the drag has gone, the technician is in reach of the real E ray",
		tech_target != null and String(tech_target.name) == "TechnicianInteract")

	# ---------------------------------------------------------------- 4. the handle
	var mat: StandardMaterial3D = _approach.call("technician_material")
	var closed_tex: Texture2D = _approach.get("_tech_tex_closed")
	var open_tex: Texture2D = _approach.get("_tech_tex_open")
	_ok("he starts with his eyes CLOSED", mat.albedo_texture == closed_tex)
	_ok("the pair are two different textures of the SAME size (%dx%d / %dx%d)" % [closed_tex.get_width(),
		closed_tex.get_height(), open_tex.get_width(), open_tex.get_height()],
		closed_tex != open_tex and closed_tex.get_size() == open_tex.get_size())
	var a_img := closed_tex.get_image()
	var b_img := open_tex.get_image()
	if a_img.is_compressed():
		a_img.decompress()
	if b_img.is_compressed():
		b_img.decompress()
	var diff := 0
	var total := 0
	for y in range(0, a_img.get_height(), 2):
		for x in range(0, a_img.get_width(), 2):
			total += 1
			var ca := a_img.get_pixel(x, y)
			var cb := b_img.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.08:
				diff += 1
	print("  eye pair: %d of %d sampled texels differ (%.3f %%)" % [diff, total, 100.0 * diff / total])
	_ok("the pair differ, and only in a tiny region (the eyes): %.3f %% of texels" % (100.0 * diff / total),
		diff > 20 and float(diff) / total < 0.01)
	var t0 := Time.get_ticks_msec()
	_player.call("ai_interact")
	var eyes_open_at := -1.0
	var whisper_heard := false
	var released_at := -1.0
	var closed_again_at := -1.0
	var e := 0.0
	while e < 6.0:
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second
		if eyes_open_at < 0.0 and mat.albedo_texture == open_tex:
			eyes_open_at = e
		for c in _approach.get_children():
			if c is AudioStreamPlayer3D and c.playing and c.stream and String(c.stream.resource_path).contains("approach_whisper_dont_go_in"):
				whisper_heard = true
		if released_at < 0.0 and _approach.get("handle_taken"):
			released_at = e
		if released_at > 0.0 and closed_again_at < 0.0 and mat.albedo_texture == closed_tex:
			closed_again_at = e
	print("  technician: eyes open %.2f s, released %.2f s, eyes closed %.2f s" % [eyes_open_at, released_at, closed_again_at])
	_ok("the hand grips ~0.5 s, THEN the eyes open (%.2f s)" % eyes_open_at, eyes_open_at >= 0.4 and eyes_open_at <= 0.7)
	_ok("the whisper plays, close, from his head", whisper_heard)
	_ok("the grip lets go after the whisper (%.2f s) and the handle is carried" % released_at,
		released_at > eyes_open_at + 1.5 and String(root.get_node("GameState").get("carried_item")) == "A WHEEL HANDLE")
	_ok("then the eyes close for good (%.2f s)" % closed_again_at, closed_again_at > released_at)
	names = Array(_approach.call("beat_names"))
	var order := ["technician", "technician_grip", "technician_eyes_open", "technician_released", "technician_eyes_closed"]
	var idx := order.map(func(b): return names.find(b))
	_ok("the technician's steps are logged once each, in order %s" % str(idx),
		idx.all(func(i): return i >= 0) and idx[0] < idx[1] and idx[1] < idx[2]
		and idx[2] < idx[3] and idx[3] < idx[4] and order.all(func(b): return names.count(b) == 1))
	_player.call("ai_look_at", tech_head)
	await physics_frame
	_ok("it happens ONCE: afterwards he offers nothing", _player.call("ai_interact_target") == null)

	# ---------------------------------------------------------------- 5. the wheel
	_player.call("ai_look_at", Vector3(-44.5, 1.05, -32.87))
	await physics_frame
	_player.call("ai_interact")
	await physics_frame
	_ok("E on the wheel fits the handle and engages it (handle shown, player frozen, carried cleared)",
		_approach.get("handle_fitted") and _approach.get("wheel_engaged") and _player.call("is_input_frozen")
		and String(root.get_node("GameState").get("carried_item")) == "")
	var yaw_before := _player.rotation.y
	await _circle(2.5, 0.8, 70.0)
	var p1: float = _approach.get("wheel_progress")
	print("  after 2.5 s of circling: %.2f rad (%.2f turns)" % [p1, p1 / TAU])
	_ok("circling the mouse turns the wheel (%.2f rad in 2.5 s; the cap allows 4.75)" % p1, p1 > 3.0 and p1 <= 1.9 * 2.5 + 0.05)
	_ok("while turning, the mouse does not turn the camera", is_equal_approx(_player.rotation.y, yaw_before))
	await _secs(2.5)
	var p2: float = _approach.get("wheel_progress")
	_ok("released, it DRIFTS BACK (%.2f -> %.2f rad in 2.5 s)" % [p1, p2], p2 < p1 - 0.5)
	# a straight rub back and forth turns nothing
	var rub_from: float = _approach.get("wheel_progress")
	for k in 90:
		var mm := InputEventMouseMotion.new()
		mm.relative = Vector2(12.0 if (k / 6) % 2 == 0 else -12.0, 0.0)
		root.push_input(mm)
		await physics_frame
	var rub_to: float = _approach.get("wheel_progress")
	_ok("rubbing straight back and forth does not turn it (%.2f -> %.2f)" % [rub_from, rub_to], rub_to <= rub_from + 0.05)
	# the other way unwinds
	await _circle(1.0, 0.8, 70.0)
	var fwd: float = _approach.get("wheel_progress")
	await _circle(1.0, 0.8, 70.0, -1.0)
	var back: float = _approach.get("wheel_progress")
	_ok("circling the other way unwinds it (%.2f -> %.2f)" % [fwd, back], back < fwd - 0.5)
	# E lets go
	await _press("interact")
	_ok("E again lets go of the wheel (unfrozen)", not _approach.get("wheel_engaged") and not _player.call("is_input_frozen"))
	_player.call("ai_look_at", Vector3(-44.5, 1.05, -32.87))
	await physics_frame
	_player.call("ai_interact")
	await physics_frame
	_ok("E takes it again", _approach.get("wheel_engaged"))
	await _press("move_back")
	_ok("a movement key lets go too", not _approach.get("wheel_engaged") and not _player.call("is_input_frozen"))
	# now turn it all the way, from a standing start
	_player.set("ai_move_dir", Vector2.ZERO)
	await _secs(12.0)   # let it drift all the way back to shut first
	_ok("left alone it drifts back to shut (%.2f rad)" % float(_approach.get("wheel_progress")), float(_approach.get("wheel_progress")) < 0.01)
	_player.call("ai_look_at", Vector3(-44.5, 1.05, -32.87))
	await physics_frame
	_player.call("ai_interact")
	await physics_frame
	var turn_t := 0.0
	var dt := 1.0 / Engine.physics_ticks_per_second
	# ⚠️ A TRACKPAD, not a mouse: small, slow circles (20 px radius, 0.4 a second). This is the case
	# "forgiving on a trackpad" is about; the fast mouse circle is timed by check_breach_approach.
	while not _approach.get("porthole_open") and turn_t < 30.0:
		await _circle(0.25, 0.4, 20.0)
		turn_t += 0.25
	print("  WHEEL: three turns in %.2f s of small slow trackpad circles (20 px, 0.4 circles/s)" % turn_t)
	_ok("three full turns open it, in 10–20 s of trackpad circling (%.2f s)" % turn_t, _approach.get("porthole_open") and turn_t >= 10.0 and turn_t <= 20.0)
	_ok("opening lets go and unfreezes", not _approach.get("wheel_engaged") and not _player.call("is_input_frozen"))
	await _secs(4.2)
	_ok("the door heaves open (%.1f°)" % float(_approach.call("porthole_leaf_angle")), float(_approach.call("porthole_leaf_angle")) > 95.0)
	var open_ray := _ray(Vector3(-44.5, 1.0, -31.4), Vector3(-44.5, 1.0, -34.6))
	_ok("and the doorway is now clear to a physics ray (%s)" % _hit_name(open_ray), open_ray.is_empty())

	# ---------------------------------------------------------------- 6. the dark room
	var before_panic := _panic()
	_ok("panic is 0 on the Plenum side of the door (%.3f)" % before_panic, before_panic == 0.0)
	_ok("walked through the porthole door into the dark room", await _walk(Vector3(-44.5, 0.1, -36.0)))
	await _walk(Vector3(-40.0, 0.1, -36.4))
	var curve := []
	var over := 0
	var peak := 0.0
	var t_cap := -1.0
	var light: OmniLight3D = _approach.call("spark_light")
	var on_frames := 0
	var flashes: Array = []
	var run := 0
	var was_on := false
	e = 0.0
	while e < 24.0:
		await physics_frame
		e += dt
		var pn := _panic()
		peak = maxf(peak, pn)
		if pn > cap + 0.0001:
			over += 1
		if t_cap < 0.0 and pn >= cap - 0.05:
			t_cap = e
		if int(e * 60.0) % 120 == 0:
			curve.append("%.0fs:%.1f" % [e, pn])
		if light.visible:
			on_frames += 1
			run += 1
		elif was_on:
			flashes.append(run * dt)
			run = 0
		was_on = light.visible
	print("  DARK ROOM panic curve %s  peak %.4f  cap reached at %.2f s" % [str(curve), peak, t_cap])
	print("  sparks: %d flashes, durations %s" % [flashes.size(), str(flashes.slice(0, 8))])
	_ok("panic rises while inside and reaches the cap in ~15–20 s (%.2f s)" % t_cap, t_cap >= 14.0 and t_cap <= 21.0)
	_ok("panic NEVER exceeds %.0f/50 (peak %.4f, %d frames over)" % [cap, peak, over], over == 0 and peak <= cap + 0.0001)
	var ok_flashes := flashes.size() >= 4 and flashes.all(func(d): return d >= 0.049 and d <= 0.135)
	_ok("the junction box fires 0.06–0.12 s bursts (%d flashes)" % flashes.size(), ok_flashes)
	_ok("and is dark most of the time (%.1f %% of frames lit)" % (100.0 * on_frames / (24.0 * 60.0)), on_frames < 24.0 * 60.0 * 0.25)
	# sprinting at the cap still cannot kill
	var reloads_before := current_scene
	_player.set("ai_sprint", true)
	var sprint_over := 0
	e = 0.0
	while e < 3.0:
		_player.call("ai_look_at", Vector3(-44.0 if int(e) % 2 == 0 else -36.0, 1.7, -37.5))
		_player.set("ai_move_dir", Vector2(0, -1))
		await physics_frame
		e += dt
		if _panic() > cap + 0.12:
			sprint_over += 1
	_player.set("ai_sprint", false)
	_player.set("ai_move_dir", Vector2.ZERO)
	await physics_frame
	_ok("sprinting inside cannot carry panic past the cap (%d frames over by >0.12) and nobody died" % sprint_over,
		sprint_over == 0 and current_scene == reloads_before and _panic() <= cap + 0.12)

	# ---------------------------------------------------------------- 7. out, through the passage, to the chamber
	await _walk(Vector3(-40.0, 0.1, -36.5))
	_ok("walked across the dark room to its far door", await _walk(Vector3(-29.0, 0.1, -36.5)))
	var decay_rise := 0
	var last := _panic()
	for target in [Vector3(-21.0, 0.1, -36.5), Vector3(-13.8, 0.1, -34.3), Vector3(-13.5, 0.1, -30.3)]:
		var ee := 0.0
		while Vector2(_player.position.x - target.x, _player.position.z - target.z).length() > 0.3 and ee < 12.0:
			_player.call("ai_look_at", Vector3(target.x, 1.7, target.z))
			_player.set("ai_move_dir", Vector2(0, -1))
			await physics_frame
			ee += dt
			var pn := _panic()
			if not _approach.get("_in_dark") and pn > last + 0.0001:
				decay_rise += 1
			last = pn
		_player.set("ai_move_dir", Vector2.ZERO)
	print("  panic on reaching the chamber exit: %.2f" % _panic())
	_ok("outside the dark room panic only drains (%d frames rose)" % decay_rise, decay_rise == 0 and _panic() < cap - 5.0)
	names = Array(_approach.call("beat_names"))
	_ok("the chamber is entered through the passage (beats dark_room -> cell_chamber)",
		names.has("dark_room") and names.has("cell_chamber") and names.find("dark_room") < names.find("cell_chamber"))
	_ok("the burst glass crunches underfoot (%d crunches)" % int(_approach.get("glass_crunches")), int(_approach.get("glass_crunches")) >= 2)
	var screen_mat: ShaderMaterial = _approach.call("cctv_screen_material")
	var video: VideoStreamPlayer = _approach.get("_cctv_video")
	_ok("the CCTV screen is a shader quad (grain, scanlines, dropouts)", screen_mat != null and screen_mat.shader != null
		and screen_mat.shader.code.contains("scan"))
	_ok("fed by the placeholder clip at the user's fixed path", video != null and video.stream != null
		and String(video.stream.resource_path) == String(consts["CCTV_VIDEO"]))
	# ⭐ THE SHARED CELL, a second consumer of containment_cell.gd (KONTUR is the first).
	var spot: Node3D = _approach.get("_cell_spot")
	var cell: Node = _approach.call("breached_cell")
	# ⚠️ Duck-typed, never `is ContainmentCell`: naming the class compiles containment_cell.gd with THIS
	# script, before the autoloads exist under --script, and its `GameState` then fails to compile.
	var is_cell: bool = cell != null and cell.get_script() != null \
		and String(cell.get_script().resource_path).ends_with("containment_cell.gd")
	_ok("the shared ContainmentCell stands on BreachedCellSpot", spot != null and is_cell and cell.get_parent() == spot)
	if is_cell:
		var counts: Vector2i = cell.call("breach_shard_counts")
		_ok("it is BREACHED: teeth in the frame and glass on the floor (%s)" % str(counts),
			cell.call("is_breached") and counts.x > 0 and counts.y > 0)
		var back_axis := (cell as Node3D).global_basis.z.normalized()
		_ok("its front (local -z) faces -x, toward the player coming in (back axis %s)" % str(back_axis.snappedf(0.01)),
			back_axis.dot(Vector3(1, 0, 0)) > 0.99)
		# the front is OPEN: a ray from the chamber passes where the pane was and stops at the steel back
		var open := _ray(Vector3(-14.0, 1.3, -34.8), Vector3(-9.0, 1.3, -34.8))
		var hit_x: float = (open["position"] as Vector3).x if not open.is_empty() else 99.0
		_ok("the pane is gone: a ray through its front stops at the back wall (x %.2f), inside the tank" % hit_x,
			not open.is_empty() and _is_under(open["collider"], cell) and hit_x > -10.4)
		_ok("the tank carries no ScaryObject and no collider-free danger (it adds zero panic)", _no_scary(cell))
	var mine := _find_all(_approach, "BurstGlass", []).size() + _find_all(_approach, "BurstGlassSlab", []).size()
	_ok("the approach lays no glass of its own on the tank's field (%d pieces)" % mine, mine == 0)
	_ok("the placeholder plinth is gone", spot != null and spot.get_node_or_null("BreachedCellPlaceholder") == null)
	var puppet: Node = _approach.call("grille_puppet")
	_ok("the grille puppet has not been freed yet (the door tell never ran on this staged route)", puppet != null)
	if puppet:
		_ok("the grille puppet carries no collider and no ScaryObject", _no_collider_or_scary(puppet))

	# ---------------------------------------------------------------- 8. the snapshot
	var snap: Dictionary = _level.call("save_progress")
	_ok("the snapshot carries the handle and the open door (%s)" % str(snap),
		snap.get("approach_handle_taken", false) and snap.get("approach_porthole_open", false))
	var gs := root.get_node("GameState")
	gs.get("level_progress")[6] = snap
	change_scene_to_file(SCENE)
	await create_timer(1.8).timeout
	_bind()
	_ok("a return visit finds the door open and the handle gone from his hand",
		_approach.get("porthole_open") and float(_approach.call("porthole_leaf_angle")) > 95.0
		and _approach.get("handle_taken") and _approach.get("_tech_handle") == null)
	var back_ray := _ray(Vector3(-44.5, 1.0, -31.4), Vector3(-44.5, 1.0, -34.6))
	_ok("and its doorway is clear", back_ray.is_empty())
	gs.get("level_progress")[6] = {"approach_handle_taken": true, "approach_porthole_open": false}
	change_scene_to_file(SCENE)
	await create_timer(1.8).timeout
	_bind()
	_ok("a return with the handle carried: the door is shut and the handle is still carried",
		not _approach.get("porthole_open") and _approach.get("handle_taken")
		and String(gs.get("carried_item")) == "A WHEEL HANDLE")
	gs.get("level_progress").erase(6)
	gs.call("set_carried", "")
	_ok("sample count is meaningful", _checks >= 40)
	print("BREACH PORTHOLE: %d checks, %d failed" % [_checks, _fails])
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit(1 if _fails else 0)


func _no_scary(node: Node) -> bool:
	var n := node
	while n != null:
		if n is ScaryObject:
			return false
		n = n.get_parent()
	return _find_all_scary(node) == 0


func _find_all_scary(node: Node) -> int:
	var k := 0
	for c in node.get_children():
		if c is ScaryObject:
			k += 1
		k += _find_all_scary(c)
	return k


func _no_collider_or_scary(node: Node) -> bool:
	var n := node
	while n != null:
		if n is ScaryObject:
			return false
		n = n.get_parent()
	return _clean(node)


func _clean(node: Node) -> bool:
	for c in node.get_children():
		if c is CollisionShape3D or c is CollisionObject3D or c is ScaryObject:
			return false
		if not _clean(c):
			return false
	return true
