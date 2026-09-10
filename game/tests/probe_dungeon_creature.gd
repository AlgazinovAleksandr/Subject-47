extends SceneTree

# THE NIGHTMARE (dungeon.tscn) — the darkest place the model appears. Run WITHOUT --headless.
#
#   /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/probe_dungeon_creature.gd -- --dungeon-seed 404
#
# Worry #4 at its hardest: ambient 0.045, no flashlight at all, one 4.5 m candle. A Still One is
# `creature_stalker.gd` with TINT 0.55 — the same tint measured against a torch at 1.6 energy
# and 18 m range. The candle is a different light entirely.

const OUT := "user://dungeon_shots"

var _t := 0.0
var _stage := 0
var _sub := 0
var _lvl: Node
var _player: CharacterBody3D
var _cam: Camera3D
var _cre: Array = []
var _body: StaticBody3D
var _log: Array[String] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	seed(404)
	change_scene_to_file("res://scenes/dungeon.tscn")


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
		if _t < 4.0:
			return false
		_lvl = current_scene
		_player = get_first_node_in_group("player") as CharacterBody3D
		_cam = _player.get_node_or_null("Camera3D")
		_player.set("ai_active", true)
		_player.set("ai_move_dir", Vector2.ZERO)
		_find_script(_lvl, "creature_stalker.gd", _cre)
		var mat: Array = []
		_find_script(_lvl, "creature_object12.gd", mat)
		_say("Still Ones in scene: %d ; Matron instances: %d" % [_cre.size(), mat.size()])
		if _cre.is_empty():
			_say("no Still One spawned yet (they arrive with the sconce clock) — "
				+ "spawning nothing to photograph")
			quit(0)
			return true
		var duds := 0
		for c in _cre:
			if bool(c.get("is_dud")):
				duds += 1
		_say("   of which duds: %d ; scrape_tell on: %s ; spark_reactive on: %s"
			% [duds, _cre[0].get("scrape_tell"), _cre[0].get("spark_reactive")])
		_body = _cre[0].get("_body")
		var c0: Node = _cre[0]
		c0.set("is_dud", false)      # harness: keep it upright so it can be photographed
		c0.set("_awakened", true)
		c0.set("_age", 999.0)
		c0.set("_stare_off_timer", 0.0)
		var cd: Node = _lvl.get("_candle")
		_say("candle present: %s  lit=%s" % [cd != null,
			cd.get("burning") if cd else "-"])
		if cd and not bool(cd.get("burning")):
			cd.call("toggle")
		# ⚠️ The first run of this probe photographed the ANTECHAMBER: the dungeon proper is
		# only entered by interacting with the cot, so every shot was of a brick wall with
		# "Press E" on it. Go under first.
		var cots: Array = []
		_find_script(_lvl, "dungeon_cot.gd", cots)
		_say("cots found: %d" % cots.size())
		for k in cots:
			if k.has_method("interact"):
				k.call("interact")
				break
		_stage = 5
		_t = 0.0
		return false

	# wait out the sleep transition, then re-find everything
	if _stage == 5:
		if _t < 8.0:
			return false
		_lvl = current_scene
		_player = get_first_node_in_group("player") as CharacterBody3D
		_cam = _player.get_node_or_null("Camera3D")
		_player.set("ai_active", true)
		_cre.clear()
		_find_script(_lvl, "creature_stalker.gd", _cre)
		_say("after sleeping: player at %s ; Still Ones %d ; in_dungeon=%s"
			% [_player.global_position, _cre.size(), _lvl.get("_in_dungeon")])
		if _cre.is_empty():
			_say("STILL NO Still One to photograph")
			print("\n===== DUNGEON SUMMARY =====")
			for l in _log:
				print(l)
			quit(0)
			return true
		_cre[0].set("is_dud", false)
		_cre[0].set("_awakened", true)
		_cre[0].set("_age", 999.0)
		_cre[0].set("_stare_off_timer", 0.0)
		_body = _cre[0].get("_body")
		var cd2: Node = _lvl.get("_candle")
		if cd2 and not bool(cd2.get("burning")):
			cd2.call("toggle")
		if cd2:
			_say("candle burning=%s remaining=%s" % [cd2.get("burning"), cd2.get("remaining")])
		_stage = 1
		_t = 0.0
		return false

	if _stage == 1:
		var dists := [2.0, 4.0, 7.0]
		var i: int = _sub / 2
		if i >= dists.size():
			print("\n===== DUNGEON SUMMARY =====")
			for l in _log:
				print(l)
			print("\n%s" % ProjectSettings.globalize_path(OUT))
			quit(0)
			return true
		var d: float = dists[i]
		if _sub % 2 == 0:
			# ⚠️ Place it along a heading with CLEAR FLOOR, not blindly at +Z: the first run
			# put the creature through the antechamber door and photographed a wall.
			var p := _player.global_position
			var best := Vector3.FORWARD
			var best_d := 0.0
			var ss := _player.get_world_3d().direct_space_state
			for k in 16:
				var ang: float = TAU * k / 16.0
				var dir := Vector3(sin(ang), 0, cos(ang))
				var q := PhysicsRayQueryParameters3D.create(
					p + Vector3(0, 1.0, 0), p + Vector3(0, 1.0, 0) + dir * 12.0)
				q.exclude = [_player.get_rid(), _body.get_rid()]
				var hit := ss.intersect_ray(q)
				var reach: float = 12.0 if hit.is_empty() \
					else p.distance_to(hit["position"] as Vector3)
				if reach > best_d:
					best_d = reach
					best = dir
			var at := p + best * minf(d, best_d - 0.6)
			_say("   heading %.0f deg has %.1f m of clear floor; placing at %.1f m"
				% [rad_to_deg(atan2(best.x, best.z)), best_d, minf(d, best_d - 0.6)])
			_body.global_position = Vector3(at.x, p.y - 0.1, at.z)
			_look(Vector3(p.x, 0.1, p.z), Vector3(at.x, 1.0, at.z))
			_cre[0].set("_stare_off_timer", 0.0)
			_sub += 1
			_t = 0.0
			return false
		_shot("40_dungeon_%02dm" % int(d))
		var img := root.get_texture().get_image()
		var mx := 0.0
		var tot := 0.0
		var n := 0
		for y in range(int(img.get_height() * 0.25), int(img.get_height() * 0.80), 2):
			for x in range(int(img.get_width() * 0.35), int(img.get_width() * 0.65), 2):
				var l := img.get_pixel(x, y).get_luminance()
				mx = maxf(mx, l)
				tot += l
				n += 1
		_say("%2d m  centre-band mean lum %.4f  peak %.4f" % [int(d), tot / maxf(1, n), mx])
		_sub += 1
		_t = 0.0
		return false
	return false
