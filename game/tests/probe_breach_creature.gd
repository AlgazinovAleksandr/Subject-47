extends SceneTree

# THE BREACH (level_6_breach.tscn) — Object 12 in CHASE, photographed head-on and side-on.
# Run WITHOUT --headless.
#
#   /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/probe_breach_creature.gd
#
# CHASE closes distance UNCONDITIONALLY, so unlike the Void's stalker this one can be
# photographed running straight at the player camera — which is the only view that can settle
# "does it face the right way when moving".

const OUT := "user://breach_shots"
const S_CHASE := 2      # CreatureObject12.State.CHASE

var _t := 0.0
var _stage := 0
var _sub := 0
var _lvl: Node
var _player: CharacterBody3D
var _cam: Camera3D
var _dir_cam: Camera3D
var _c: Node
var _body: StaticBody3D
var _log: Array[String] = []
var _shots: Array[String] = []
var _toe: Array = []
var _ft: Array[float] = []
var _luma_with: Image = null
var _atrium := Vector3.ZERO


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	change_scene_to_file("res://scenes/level_6_breach.tscn")


func _say(s: String) -> void:
	_log.append(s)
	print("  " + s)


func _shot(n: String) -> void:
	var p := "%s/%s.png" % [OUT, n]
	root.get_texture().get_image().save_png(p)
	_shots.append(ProjectSettings.globalize_path(p))
	print("   [shot] " + n)


func _find_node_class(n: Node, cls: String, out: Array) -> void:
	if n.get_class() == cls:
		out.append(n)
	for c in n.get_children():
		_find_node_class(c, cls, out)


func _find_script(n: Node, s: String, out: Array) -> void:
	var sc: Variant = n.get_script()
	if sc and String(sc.resource_path).ends_with(s):
		out.append(n)
	for c in n.get_children():
		_find_script(c, s, out)


func _skel() -> Skeleton3D:
	var o: Array = []
	_find_node_class(_c, "Skeleton3D", o)
	return o[0] if o.size() > 0 else null


func _look(from: Vector3, at: Vector3) -> void:
	_player.global_position = from
	_player.velocity = Vector3.ZERO
	var d := at - from
	_player.rotation.y = atan2(-d.x, -d.z)
	_cam.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.5, 1.5)


func _chase() -> void:
	_c.call("activate")
	_c.call("_enter", S_CHASE)


# ⚠️ HARNESS ONLY, and it is not a difficulty change to the game: `contact_dist` 1.0 kills the
# player on arrival, which fires `Screamer.trigger()`, which RELOADS THE SCENE — the first run
# of this probe photographed five identical frames of the screamer panel and then hung on a
# freed creature. Shrunk here so the chase can be watched to the end.
func _defuse() -> void:
	_c.set("contact_dist", 0.02)


func _sample_toes() -> void:
	var sk := _skel()
	if sk == null:
		return
	var lt := sk.find_bone("LeftToeBase")
	var rt := sk.find_bone("RightToeBase")
	if lt < 0 or rt < 0:
		return
	var xf := sk.global_transform
	_toe.append({"body": _body.global_position,
		"l": xf * sk.get_bone_global_pose(lt).origin,
		"r": xf * sk.get_bone_global_pose(rt).origin})


func _slide(tag: String) -> void:
	if _toe.size() < 8:
		_say("FOOT SLIDE %s: only %d samples" % [tag, _toe.size()])
		return
	var bt := 0.0
	var pt := 0.0
	var n := 0
	for i in range(1, _toe.size()):
		var a: Dictionary = _toe[i - 1]
		var b: Dictionary = _toe[i]
		var av: Vector3 = a["body"]
		var bv: Vector3 = b["body"]
		var bd := Vector2(bv.x - av.x, bv.z - av.z).length()
		if bd < 1e-6:
			continue
		var al: Vector3 = a["l"]
		var bl: Vector3 = b["l"]
		var ar: Vector3 = a["r"]
		var br: Vector3 = b["r"]
		pt += minf(Vector2(bl.x - al.x, bl.z - al.z).length(),
			Vector2(br.x - ar.x, br.z - ar.z).length())
		bt += bd
		n += 1
	if bt <= 0.0:
		_say("FOOT SLIDE %s: body never moved" % tag)
		return
	_say("FOOT SLIDE %-22s planted/body = %.3f  (0 = planted, 1 = full skate)  frames=%d body=%.2f m"
		% [tag, pt / bt, n, bt])


func _process(delta: float) -> bool:
	_t += delta
	if _t < 0.03:
		return false
	if _stage > 0 and (not is_instance_valid(_c) or not is_instance_valid(_body)):
		_say("!! creature was FREED — the scene reloaded (a screamer fired). Aborting at stage %d." % _stage)
		for l in _log:
			print(l)
		quit(1)
		return true

	if _stage == 0:
		if _t < 2.5:
			return false
		_lvl = current_scene
		_player = get_first_node_in_group("player") as CharacterBody3D
		_cam = _player.get_node_or_null("Camera3D")
		_player.set("ai_active", true)
		_player.set("ai_move_dir", Vector2.ZERO)
		var out: Array = []
		_find_script(_lvl, "creature_object12.gd", out)
		if out.is_empty():
			_say("NO CreatureObject12 FOUND")
			quit(1)
			return true
		_c = out[0]
		_body = _c.get("_body")
		_say("creature at %s  chase_speed=%s patrol_speed=%s contact_dist=%s"
			% [_body.global_position, _c.get("chase_speed"), _c.get("patrol_speed"),
				_c.get("contact_dist")])
		var b: Node = _lvl.get("_builder")
		_atrium = b.call("room_center", "Atrium") if b else Vector3(0, 0, 22)
		_say("Atrium centre %s" % _atrium)
		_defuse()
		_dir_cam = Camera3D.new()
		_dir_cam.fov = 75.0
		_lvl.add_child(_dir_cam)
		_stage = 1
		_t = 0.0
		return false

	# ---- 1: it runs straight at the PLAYER camera ----
	if _stage == 1:
		if _sub == 0:
			_look(_atrium + Vector3(0, 0.1, -4.0), _atrium + Vector3(0, 1.0, 6.0))
			_body.global_position = _atrium + Vector3(0, 0, 6.0)
			_chase()
			_toe.clear()
			_sub = 1
			_t = 0.0
			return false
		_sample_toes()
		if _t < 0.55:
			return false
		var d := _body.global_position.distance_to(_player.global_position)
		if _sub <= 4:
			_shot("11_chase_at_player_%d" % _sub)
			_say("chase->player %d: creature %s  dist %.2f m  yaw %.1f deg  state=%s"
				% [_sub, _body.global_position, d, rad_to_deg(_body.rotation.y),
					_c.get("_state")])
		_sub += 1
		_t = 0.0
		if _sub > 4:
			_slide("chase (run, 2.2 s)")
			_stage = 2
			_sub = 0
		return false

	# ---- 2: side-on, director cam, while chasing ----
	if _stage == 2:
		if _sub == 0:
			_dir_cam.current = true
			_look(_atrium + Vector3(0, 0.1, -6.0), _atrium + Vector3(0, 1.0, 8.0))
			_body.global_position = _atrium + Vector3(0, 0, 7.0)
			_chase()
			_toe.clear()
			_sub = 1
			_t = 0.0
			return false
		_sample_toes()
		if _t < 0.35:
			return false
		var p := _body.global_position
		_dir_cam.global_position = Vector3(p.x + 4.0, 1.5, p.z)
		_dir_cam.look_at(p + Vector3(0, 1.0, 0), Vector3.UP)
		if _sub <= 5:
			_shot("12_chase_side_%d" % _sub)
			_say("chase side %d: z=%.3f yaw=%.1f deg" % [_sub, p.z, rad_to_deg(_body.rotation.y)])
		_sub += 1
		_t = 0.0
		if _sub > 5:
			_slide("chase side (1.8 s)")
			_stage = 3
			_sub = 0
		return false

	# ---- 3: PATROL gait, side-on ----
	if _stage == 3:
		if _sub == 0:
			_c.call("activate")
			_c.call("_enter", 0)   # PATROL
			_body.global_position = _atrium + Vector3(0, 0, 6.0)
			_look(_atrium + Vector3(0, 0.1, -14.0), _atrium + Vector3(0, 1.0, -20.0))
			_toe.clear()
			_sub = 1
			_t = 0.0
			return false
		_sample_toes()
		if _t < 0.6:
			return false
		var p := _body.global_position
		_dir_cam.global_position = Vector3(p.x + 3.6, 1.5, p.z)
		_dir_cam.look_at(p + Vector3(0, 1.0, 0), Vector3.UP)
		if _sub <= 2:
			_shot("13_patrol_side_%d" % _sub)
			_say("patrol %d: pos=%s yaw=%.1f deg state=%s" % [_sub, p,
				rad_to_deg(_body.rotation.y), _c.get("_state")])
		_sub += 1
		_t = 0.0
		if _sub > 2:
			_slide("patrol (walk)")
			_stage = 4
			_sub = 0
		return false

	# ---- 4: legibility in this level's own lighting, masked (shadows OFF for the mask) ----
	if _stage == 4:
		var dists := [3.0, 8.0, 15.0]
		var i: int = _sub / 3
		if i >= dists.size():
			_set_shadow(true)
			_stage = 5
			_sub = 0
			_t = 0.0
			return false
		var d: float = dists[i]
		var ph: int = _sub % 3
		if ph == 0:
			_dir_cam.current = false
			_cam.current = true
			_c.call("_enter", 0)
			_set_shadow(false)
			_body.global_position = _atrium + Vector3(0, 0, d - 6.0)
			_look(_atrium + Vector3(0, 0.1, -6.0), _atrium + Vector3(0, 1.0, d - 6.0))
			_set_vis(true)
			_sub += 1
			_t = 0.0
			return false
		if ph == 1:
			_shot("14_legibility_%02dm" % int(d))
			_luma_with = root.get_texture().get_image()
			_set_vis(false)
			_sub += 1
			_t = 0.0
			return false
		_mask("breach %2d m" % int(d), _luma_with, root.get_texture().get_image())
		_set_vis(true)
		_sub += 1
		_t = 0.0
		return false

	# ---- 5: frame time with one creature ----
	if _stage == 5:
		if _sub == 0:
			_body.global_position = _atrium + Vector3(0, 0, 2.0)
			_look(_atrium + Vector3(0, 0.1, -4.0), _atrium + Vector3(0, 1.0, 2.0))
			_c.call("_enter", S_CHASE)
			_ft.clear()
			_sub = 1
			_t = 0.0
			return false
		_ft.append(delta)
		if _t < 2.5:
			return false
		_perf("1 creature (Breach, CHASE)")
		_stage = 6
		_sub = 0
		_t = 0.0
		return false

	if _stage == 6:
		if _sub == 0:
			_body.global_position = Vector3(0, -80, 0)
			_ft.clear()
			_sub = 1
			_t = 0.0
			return false
		_ft.append(delta)
		if _t < 2.5:
			return false
		_perf("0 creatures (Breach baseline)")
		print("\n===== BREACH SUMMARY =====")
		for l in _log:
			print(l)
		print("\nshots:")
		for s in _shots:
			print("  " + s)
		quit(0)
		return true
	return false


func _perf(tag: String) -> void:
	var tot := 0.0
	for f in _ft:
		tot += f
	var avg := tot / maxf(1, _ft.size())
	_say("FRAME TIME %-30s avg %6.2f ms (%5.0f fps) n=%d" % [tag, avg * 1000.0, 1.0 / avg,
		_ft.size()])


func _set_vis(v: bool) -> void:
	var o: Array = []
	_find_node_class(_c, "MeshInstance3D", o)
	for m in o:
		(m as MeshInstance3D).visible = v


func _set_shadow(on: bool) -> void:
	var o: Array = []
	_find_node_class(_c, "MeshInstance3D", o)
	for m in o:
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _mask(tag: String, a: Image, b: Image) -> void:
	if a == null or b == null:
		return
	var cre := 0.0
	var bg := 0.0
	var n := 0
	var pk := 0.0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var la := a.get_pixel(x, y).get_luminance()
			var lb := b.get_pixel(x, y).get_luminance()
			if absf(la - lb) < 0.004:
				continue
			cre += la
			bg += lb
			pk = maxf(pk, la)
			n += 1
	if n < 20:
		_say("%s: mask too small (%d)" % [tag, n])
		return
	var cm: float = cre / n
	var bm: float = bg / n
	_say("%s  px=%d  creature lum %.4f (peak %.4f)  background behind it %.4f  ratio %.2f %s"
		% [tag, n, cm, pk, bm, cm / maxf(0.0001, bm),
			"DARKER than background" if cm < bm else "brighter than background"])
