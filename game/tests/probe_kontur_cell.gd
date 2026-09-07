extends SceneTree

# KONTUR — the caged specimen. Run WITHOUT --headless.
#
#   /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/probe_kontur_cell.gd
#
# Worry #5: it should sway slowly inside its booth and NOT walk out of it. `unsteady` is 2.9667 s
# long and the cell plays it at IDLE_RATE, so this watches it for well over a full clip period
# and reports the occupant's maximum excursion from its start point in world space, plus the
# skeleton's own max horizontal reach, against the booth's interior.

const OUT := "user://kontur_shots"
const WATCH := 24.0

var _t := 0.0
var _stage := 0
var _sub := 0
var _lvl: Node
var _player: CharacterBody3D
var _cam: Camera3D
var _cell: Node
var _occ: Node3D
var _skel: Skeleton3D
var _start := Vector3.ZERO
var _max_off := 0.0
var _min_p := Vector3(1e9, 1e9, 1e9)
var _max_p := Vector3(-1e9, -1e9, -1e9)
var _yaws: Array[float] = []
var _log: Array[String] = []
var _shot_at := 0
var _cell_aabb: AABB


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	seed(7)
	change_scene_to_file("res://scenes/kontur.tscn")


func _say(s: String) -> void:
	_log.append(s)
	print("  " + s)


func _shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [OUT, n])
	print("   [shot] " + n)


func _find_script(n: Node, s: String, out: Array) -> void:
	var sc: Variant = n.get_script()
	if sc and String(sc.resource_path).ends_with(s):
		out.append(n)
	for c in n.get_children():
		_find_script(c, s, out)


func _find_node_class(n: Node, cls: String, out: Array) -> void:
	if n.get_class() == cls:
		out.append(n)
	for c in n.get_children():
		_find_node_class(c, cls, out)


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

	if _stage == 0:
		if _t < 3.0:
			return false
		_lvl = current_scene
		_player = get_first_node_in_group("player") as CharacterBody3D
		_cam = _player.get_node_or_null("Camera3D")
		_player.set("ai_active", true)
		_player.set("ai_move_dir", Vector2.ZERO)
		var out: Array = []
		_find_script(_lvl, "containment_cell.gd", out)
		if out.is_empty():
			_say("NO ContainmentCell FOUND IN KONTUR")
			quit(1)
			return true
		_cell = out[0]
		_occ = _cell.get("_occupant") as Node3D
		var sk: Array = []
		_find_node_class(_cell, "Skeleton3D", sk)
		_skel = sk[0] if sk.size() > 0 else null
		_start = _occ.global_position
		var solids: Array = []
		_find_node_class(_cell, "MeshInstance3D", solids)
		# booth extent = every mesh under the cell EXCEPT the occupant's own
		var first := true
		for m in solids:
			var mi: MeshInstance3D = m
			if _occ.is_ancestor_of(mi):
				continue
			var a := mi.get_aabb()
			a.position = mi.global_transform * a.position
			if first:
				_cell_aabb = a
				first = false
			else:
				_cell_aabb = _cell_aabb.merge(a)
		_say("cell at %s  occupant at %s  skeleton=%s"
			% [(_cell as Node3D).global_position, _start, "yes" if _skel else "NO"])
		_say("booth extent (all non-occupant meshes) %s" % _cell_aabb)
		_say("occupant clip=%s" % [(_cell.get("_anim") as CreatureAnim).current_clip()
			if _cell.get("_anim") else "NO ANIM"])
		# Stand in the Passage looking at the booth from the spine.
		var p: Vector3 = (_cell as Node3D).global_position
		_look(p + Vector3(-2.6, 0.1, -1.0), p + Vector3(0, 1.1, 0))
		_stage = 1
		_t = 0.0
		return false

	if _stage == 1:
		var here: Vector3 = _occ.global_position
		_max_off = maxf(_max_off, here.distance_to(_start))
		_yaws.append(_occ.rotation.y)
		if _skel:
			var xf := _skel.global_transform
			for i in _skel.get_bone_count():
				var w: Vector3 = xf * _skel.get_bone_global_pose(i).origin
				_min_p = Vector3(minf(_min_p.x, w.x), minf(_min_p.y, w.y), minf(_min_p.z, w.z))
				_max_p = Vector3(maxf(_max_p.x, w.x), maxf(_max_p.y, w.y), maxf(_max_p.z, w.z))
		var want := int(_t / 6.0)
		if want > _shot_at and want <= 4:
			_shot_at = want
			_shot("30_cell_t%02ds" % int(_t))
			_say("t=%5.1f s  occupant node %s  offset from start %.4f m  yaw %.1f deg"
				% [_t, here, here.distance_to(_start), rad_to_deg(_occ.rotation.y)])
		if _t < WATCH:
			return false
		_say("--- after %.0f s ---" % WATCH)
		_say("occupant NODE never moved more than %.4f m from its start" % _max_off)
		_say("skeleton world envelope min=%s max=%s" % [_min_p, _max_p])
		var span := _max_p - _min_p
		_say("   envelope span x=%.3f y=%.3f z=%.3f m" % [span.x, span.y, span.z])
		var inside := _cell_aabb.grow(0.02).encloses(AABB(_min_p, _max_p))
		_say("   every bone, every frame, INSIDE the booth AABB = %s" % inside)
		if not inside:
			_say("   !! bones outside booth: min %s vs booth min %s ; max %s vs booth max %s"
				% [_min_p, _cell_aabb.position, _max_p, _cell_aabb.position + _cell_aabb.size])
		var ymin := 999.0
		var ymax := -999.0
		for y in _yaws:
			ymin = minf(ymin, y)
			ymax = maxf(ymax, y)
		_say("occupant yaw range over the watch: %.1f deg (head-tracking, TRACK_RATE 0.9 rad/s)"
			% rad_to_deg(ymax - ymin))
		_stage = 2
		_t = 0.0
		return false

	# close-up, and a shot from the -Z leaf side (the arc that used to render nothing)
	if _stage == 2:
		var p: Vector3 = (_cell as Node3D).global_position
		match _sub:
			0:
				_look(p + Vector3(-1.6, 0.1, 0.0), p + Vector3(0, 1.2, 0))
				_sub = 1
				_t = 0.0
			1:
				if _t < 0.5:
					return false
				_shot("31_cell_closeup_west")
				_look(p + Vector3(0.0, 0.1, -2.2), p + Vector3(0, 1.2, 0))
				_sub = 2
				_t = 0.0
			2:
				if _t < 0.5:
					return false
				_shot("32_cell_through_port")
				_look(p + Vector3(2.2, 0.1, 1.8), p + Vector3(0, 1.2, 0))
				_sub = 3
				_t = 0.0
			3:
				if _t < 0.5:
					return false
				_shot("33_cell_far")
				print("\n===== KONTUR CELL SUMMARY =====")
				for l in _log:
					print(l)
				print("\n%s" % ProjectSettings.globalize_path(OUT))
				quit(0)
				return true
		return false
	return false
