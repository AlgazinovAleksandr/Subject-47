extends SceneTree

# THE VOID (level_3.tscn) — photograph the four stalkers doing the thing they are for.
# Run WITHOUT --headless.
#
#   /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/probe_void_creature.gd
#
# ⚠️ `_stare_off_timer` and `_awakened` are RESET before every stage. The first version of this
# probe let stage 1's three distance shots accumulate 4 s of gaze, which fired `_dismiss()` in
# stage 2 and shoved the creature 3 m backwards out of ENGAGE_DIST — every later stage then
# measured a DORMANT creature and reported "body never moved" as if the game were broken.

const OUT := "user://void_shots"

var _t := 0.0
var _stage := 0
var _sub := 0
var _lvl: Node
var _player: CharacterBody3D
var _cam: Camera3D
var _dir_cam: Camera3D
var _cre: Array = []
var _bodies: Array = []
var _log: Array[String] = []
var _toe_track: Array = []
var _pose_watched := ""
var _pos_watched := Vector3.ZERO
var _frame_times: Array[float] = []
var _shots: Array[String] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	change_scene_to_file("res://scenes/level_3.tscn")


func _say(s: String) -> void:
	_log.append(s)
	print("  " + s)


func _find_script(n: Node, script_name: String, out: Array) -> void:
	var sc: Variant = n.get_script()
	if sc and String(sc.resource_path).ends_with(script_name):
		out.append(n)
	for c in n.get_children():
		_find_script(c, script_name, out)


func _find_node_class(n: Node, cls: String, out: Array) -> void:
	if n.get_class() == cls:
		out.append(n)
	for c in n.get_children():
		_find_node_class(c, cls, out)


func _skel_of(c: Node) -> Skeleton3D:
	var out: Array = []
	_find_node_class(c, "Skeleton3D", out)
	return out[0] if out.size() > 0 else null


func _pose_hash(sk: Skeleton3D) -> String:
	if sk == null:
		return "-"
	var s := ""
	for i in sk.get_bone_count():
		var r := sk.get_bone_pose_rotation(i)
		s += "%.4f,%.4f,%.4f,%.4f;" % [r.x, r.y, r.z, r.w]
	return s.md5_text()


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := "%s/%s.png" % [OUT, name]
	img.save_png(p)
	_shots.append(ProjectSettings.globalize_path(p))
	print("   [shot] " + name)


func _arm(c: Node) -> void:
	# Make it hunt right now: seen before, no accumulated stare, grace elapsed.
	c.set("_awakened", true)
	c.set("_stare_off_timer", 0.0)
	c.set("_age", 999.0)


func _place(c: Node, pos: Vector3) -> void:
	var b: StaticBody3D = c.get("_body")
	b.global_position = pos


func _look(from: Vector3, at: Vector3) -> void:
	_player.global_position = from
	_player.velocity = Vector3.ZERO
	var d := at - from
	_player.rotation.y = atan2(-d.x, -d.z)
	_cam.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.5, 1.5)


func _process(delta: float) -> bool:
	_t += delta
	if _t < 0.03:
		return false

	match _stage:
		0: return _s0()
		1: return _s1()
		2: return _s2(delta)
		3: return _s3(delta)
		4: return _s4()
		5: return _s5(delta)
		6: return _s6(delta)
	return false


func _s0() -> bool:
	if _t < 2.0:
		return false
	_lvl = current_scene
	_player = get_first_node_in_group("player") as CharacterBody3D
	if _player == null:
		var pp: Array = []
		_find_node_class(_lvl, "CharacterBody3D", pp)
		_player = pp[0] if pp.size() > 0 else null
	_cam = _player.get_node_or_null("Camera3D")
	_player.set("ai_active", true)
	_player.set("ai_move_dir", Vector2.ZERO)
	_find_script(_lvl, "creature_stalker.gd", _cre)
	_say("creatures found: %d" % _cre.size())
	for c in _cre:
		var b: StaticBody3D = c.get("_body")
		_bodies.append(b)
		var sk := _skel_of(c)
		_say("  %-10s spawn=%s skeleton=%s meshes=%d"
			% [c.name, b.global_position, "yes" if sk else "NO", _count_mesh(b)])
	for i in range(1, _bodies.size()):
		_bodies[i].global_position = Vector3(0, -60, i * 6)
	_stage = 1
	_t = 0.0
	return false


# ---- stage 1: level's own lighting, 3 / 8 / 15 m, with a MASKED luminance read ----
var _luma_dists := [3.0, 8.0, 15.0]
var _luma_with: Image = null

func _s1() -> bool:
	var i: int = _sub / 3
	if i >= _luma_dists.size():
		_stage = 2
		_sub = 0
		_t = 0.0
		return false
	var d: float = _luma_dists[i]
	var phase: int = _sub % 3
	if phase == 0:
		_arm(_cre[0])
		_place(_cre[0], Vector3(0, 0, d))
		_look(Vector3(0, 0.1, 0), Vector3(0, 1.0, d))
		_set_visible(_cre[0], true)
		_sub += 1
		_t = 0.0
		return false
	if phase == 1:
		_shot("01_level_dist_%02dm" % int(d))
		_luma_with = root.get_texture().get_image()
		_set_visible(_cre[0], false)
		_sub += 1
		_t = 0.0
		return false
	_measure_masked(_luma_with, root.get_texture().get_image(), "dist %2d m" % int(d))
	_set_visible(_cre[0], true)
	_sub += 1
	_t = 0.0
	return false


# ---- stage 2: WATCHED = frozen; unwatched = advances ----
func _s2(delta: float) -> bool:
	var sk := _skel_of(_cre[0])
	match _sub:
		0:
			_arm(_cre[0])
			_place(_cre[0], Vector3(0, 0, 6.0))
			_look(Vector3(0, 0.1, 0), Vector3(0, 1.0, 6.0))
			_sub = 1
			_t = 0.0
		1:
			if _t < 1.0:
				return false
			_pose_watched = _pose_hash(sk)
			_pos_watched = _bodies[0].global_position
			_say("WATCHED: gait=%s pos=%s" % [_cre[0].get("_gait"), _pos_watched])
			_shot("02a_watched_frozen")
			_sub = 2
			_t = 0.0
		2:
			if _t < 1.5:
				return false
			var same_pose := _pose_hash(sk) == _pose_watched
			var moved: float = _bodies[0].global_position.distance_to(_pos_watched)
			_say("WATCHED +1.5 s: bone pose IDENTICAL = %s ; body moved %.4f m ; gait=%s"
				% [same_pose, moved, _cre[0].get("_gait")])
			_shot("02b_watched_still_frozen")
			_sub = 3
			_t = 0.0
		3:
			_look(Vector3(0, 0.1, 0), Vector3(0, 1.0, -6.0))
			_toe_track.clear()
			_sub = 4
			_t = 0.0
		4:
			_sample_toes()
			if _t < 3.0:
				return false
			var p: Vector3 = _bodies[0].global_position
			_say("UNWATCHED 3.0 s: pos=%s (moved %.3f m, expected %.3f at STALK_SPEED 1.25) gait=%s"
				% [p, p.distance_to(_pos_watched), 1.25 * 3.0, _cre[0].get("_gait")])
			_say("   bone pose changed while unwatched = %s" % [_pose_hash(sk) != _pose_watched])
			_report_slide("advance (unseen, 3 s)")
			_sub = 5
			_t = 0.0
		5:
			_look(Vector3(0, 0.1, 0), Vector3(0, 1.0, _bodies[0].global_position.z))
			_sub = 6
			_t = 0.0
		6:
			if _t < 0.5:
				return false
			_pose_watched = _pose_hash(sk)
			_pos_watched = _bodies[0].global_position
			_shot("02c_looked_back_refrozen")
			_sub = 7
			_t = 0.0
		7:
			if _t < 1.2:
				return false
			_say("RE-FROZEN +1.2 s: pose identical = %s ; moved %.4f m"
				% [_pose_hash(sk) == _pose_watched,
					_bodies[0].global_position.distance_to(_pos_watched)])
			_shot("02d_refrozen_after")
			_stage = 3
			_sub = 0
			_t = 0.0
	return false


# ---- stage 3: director cam SIDE-ON while it advances (facing + foot slide) ----
func _s3(delta: float) -> bool:
	if _sub == 0:
		_dir_cam = Camera3D.new()
		_dir_cam.fov = 75.0
		_lvl.add_child(_dir_cam)
		var t := SpotLight3D.new()
		t.light_energy = 2.2
		t.spot_range = 22.0
		t.spot_angle = 38.0
		t.spot_angle_attenuation = 0.3
		t.shadow_enabled = true
		_dir_cam.add_child(t)
		_dir_cam.current = true
		_arm(_cre[0])
		_place(_cre[0], Vector3(0, 0, 7.0))
		_look(Vector3(0, 0.1, 0), Vector3(0, 1.0, -6.0))
		_toe_track.clear()
		_sub = 1
		_t = 0.0
		return false
	_sample_toes()
	if _t < 0.40:
		return false
	var b: StaticBody3D = _bodies[0]
	var p := b.global_position
	_dir_cam.global_position = Vector3(p.x + 3.6, 1.5, p.z)
	_dir_cam.look_at(p + Vector3(0, 1.0, 0), Vector3.UP)
	if _sub <= 5:
		_shot("03_side_advance_%d" % _sub)
		_say("side %d: z=%.3f yaw=%.1f deg gait=%s" % [_sub, p.z, rad_to_deg(b.rotation.y),
			_cre[0].get("_gait")])
	_sub += 1
	_t = 0.0
	if _sub > 5:
		_report_slide("advance (side view, 2.4 s)")
		_stage = 4
		_sub = 0
	return false


# ---- stage 4: director cam in FRONT of it while it advances ----
func _s4() -> bool:
	if _sub == 0:
		_arm(_cre[0])
		_place(_cre[0], Vector3(0, 0, 7.0))
		_look(Vector3(0, 0.1, 0), Vector3(0, 1.0, -6.0))
		_sub = 1
		_t = 0.0
		return false
	if _t < 0.5:
		return false
	var p: Vector3 = _bodies[0].global_position
	_dir_cam.global_position = Vector3(p.x, 1.5, p.z - 3.2)
	_dir_cam.look_at(p + Vector3(0, 1.0, 0), Vector3.UP)
	if _sub <= 3:
		_shot("04_front_advance_%d" % _sub)
		_say("front %d: z=%.3f body_yaw=%.1f deg  (it walks toward -Z; yaw 180 deg = facing -Z = TOWARD this camera)"
			% [_sub, p.z, rad_to_deg(_bodies[0].rotation.y)])
	_sub += 1
	_t = 0.0
	if _sub > 3:
		_stage = 5
		_sub = 0
	return false


# ---- stage 5: four creatures, frame time ----
func _s5(delta: float) -> bool:
	if _sub == 0:
		_dir_cam.current = false
		_cam.current = true
		for i in _bodies.size():
			_bodies[i].global_position = Vector3(-2.4 + i * 1.6, 0, 6.0)
			_arm(_cre[i])
		_look(Vector3(0, 0.1, 0), Vector3(0, 1.0, 6.0))
		_sub = 1
		_t = 0.0
		_frame_times.clear()
		return false
	_frame_times.append(delta)
	if _t < 3.0:
		return false
	_shot("05_four_creatures")
	_perf("4 creatures visible (all animating)")
	_stage = 6
	_sub = 0
	_t = 0.0
	return false


# ---- stage 6: baseline ----
func _s6(delta: float) -> bool:
	if _sub == 0:
		for b in _bodies:
			b.global_position = Vector3(0, -60, 0)
		_sub = 1
		_t = 0.0
		_frame_times.clear()
		return false
	_frame_times.append(delta)
	if _t < 2.5:
		return false
	_perf("0 creatures visible (baseline)")
	print("\n===== VOID SUMMARY =====")
	for l in _log:
		print(l)
	print("\nshots:")
	for s in _shots:
		print("  " + s)
	quit(0)
	return true


func _perf(tag: String) -> void:
	var tot := 0.0
	var worst := 0.0
	var srt: Array[float] = _frame_times.duplicate()
	srt.sort()
	for f in _frame_times:
		tot += f
		worst = maxf(worst, f)
	var avg := tot / maxf(1, _frame_times.size())
	var p95: float = srt[int(srt.size() * 0.95)] if srt.size() > 1 else avg
	_say("FRAME TIME %-38s avg %6.2f ms (%5.0f fps)  p95 %6.2f ms  worst %6.2f ms  n=%d"
		% [tag, avg * 1000.0, 1.0 / avg, p95 * 1000.0, worst * 1000.0, _frame_times.size()])


func _count_mesh(n: Node) -> int:
	var out: Array = []
	_find_node_class(n, "MeshInstance3D", out)
	return out.size()


func _set_visible(c: Node, v: bool) -> void:
	var out: Array = []
	_find_node_class(c, "MeshInstance3D", out)
	for m in out:
		(m as MeshInstance3D).visible = v


func _sample_toes() -> void:
	var sk := _skel_of(_cre[0])
	if sk == null:
		return
	var lt := sk.find_bone("LeftToeBase")
	var rt := sk.find_bone("RightToeBase")
	if lt < 0 or rt < 0:
		return
	var xf := sk.global_transform
	_toe_track.append({
		"body": (_bodies[0] as StaticBody3D).global_position,
		"l": xf * sk.get_bone_global_pose(lt).origin,
		"r": xf * sk.get_bone_global_pose(rt).origin,
	})


# A planted foot must be STATIONARY IN THE WORLD during stance. This reports the world travel
# of whichever foot moved LESS each frame, over the body's own travel.
#   ~0.0-0.25 = the foot is planted and the gait is carrying the body (correct)
#   ~1.0      = both feet move with the body every frame = full ice-skating
func _report_slide(tag: String) -> void:
	if _toe_track.size() < 8:
		_say("FOOT SLIDE %s: not enough samples (%d)" % [tag, _toe_track.size()])
		return
	var body_total := 0.0
	var planted_total := 0.0
	var n := 0
	for i in range(1, _toe_track.size()):
		var a: Dictionary = _toe_track[i - 1]
		var b: Dictionary = _toe_track[i]
		var av: Vector3 = a["body"]
		var bv: Vector3 = b["body"]
		var bd := Vector2(bv.x - av.x, bv.z - av.z).length()
		if bd < 1e-6:
			continue
		var al: Vector3 = a["l"]
		var bl: Vector3 = b["l"]
		var ar: Vector3 = a["r"]
		var br: Vector3 = b["r"]
		var ld := Vector2(bl.x - al.x, bl.z - al.z).length()
		var rd := Vector2(br.x - ar.x, br.z - ar.z).length()
		planted_total += minf(ld, rd)
		body_total += bd
		n += 1
	if n == 0 or body_total <= 0.0:
		_say("FOOT SLIDE %s: body never moved (%d samples)" % [tag, _toe_track.size()])
		return
	_say("FOOT SLIDE %-28s planted/body = %.3f   (0 = planted, 1 = full skate)  frames=%d body=%.3f m"
		% [tag, planted_total / body_total, n, body_total])


# Mask = pixels that changed when the creature was hidden. Measures the creature against
# EXACTLY what is behind it, which a fixed screen band cannot.
func _measure_masked(with_img: Image, without_img: Image, tag: String) -> void:
	if with_img == null or without_img == null:
		return
	var w := with_img.get_width()
	var h := with_img.get_height()
	var cre := 0.0
	var bg := 0.0
	var n := 0
	var peak := 0.0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var a := with_img.get_pixel(x, y).get_luminance()
			var b := without_img.get_pixel(x, y).get_luminance()
			if absf(a - b) < 0.004:
				continue
			cre += a
			bg += b
			peak = maxf(peak, a)
			n += 1
	if n < 20:
		_say("%s  MASK TOO SMALL (%d px) — creature not on screen?" % [tag, n])
		return
	var cm: float = cre / n
	var bm: float = bg / n
	_say("%s  creature-px=%d  creature mean lum %.4f  peak %.4f  what is BEHIND it %.4f  ratio %.2f%s"
		% [tag, n, cm, peak, bm, cm / maxf(0.0001, bm),
			"  <- creature is DARKER than its background" if cm < bm else ""])
