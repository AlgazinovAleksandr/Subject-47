extends SceneTree

# Photograph THE NIGHTMARE's 2026-09-12 rework: one shot per room ARCHETYPE with its scare fired,
# the hunter appearing behind you (the Larder beat), the catch mid-lunge, the folded plan on the
# Antechamber rack, and the map overlay. Seed 101.
#
# ⚠️ Run WITHOUT --headless — it needs a real render target:
#   Godot --path game --script res://tests/screenshot_dungeon_rooms.gd
#
# ⚠️ Pose one frame, shoot on a later one (a pose set in the frame of the capture is not what
# the capture shows), and give each scare its animation time before the shot.

const OUT := "/tmp/dungeon_room_shots/"
const SEED := 101

var _started := false
var _settle := 0
var _level: Node = null
var _shots: Array = []      # [{name, kind|special, wait}]
var _idx := -1
var _wait := 0
var _pending := ""
var _frames: Array = []     # [[name, Image]]


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		var gs := root.get_node_or_null("GameState")
		if gs:
			gs.call("save_level_progress", 7, {"layout_seed": SEED, "content_seed": SEED * 31 + 7})
		change_scene_to_file("res://scenes/dungeon.tscn")
		return false
	_settle += 1
	if _settle < 20:
		return false
	if _level == null:
		_level = current_scene
		if _level == null or not _level.has_method("get_gen"):
			print("FAIL: dungeon did not load")
			quit(1)
			return true
		DirAccess.make_dir_recursive_absolute(OUT)
		_plan()
		_next()
		return false
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			_capture(_pending)
			_next()
	return false


func _plan() -> void:
	var gen = _level.call("get_gen")
	var done: Dictionary = {}
	for nm in gen.chamber_names:
		var k: String = gen.kind_of(nm)
		if k == "" or done.has(k):
			continue
		done[k] = nm
		_shots.append({"name": "room_%s_before" % k, "room": nm, "kind": k, "fire": false, "wait": 8})
		_shots.append({"name": "room_%s_after" % k, "room": nm, "kind": k, "fire": true, "wait": 150})
	_shots.append({"name": "ante_map_pickup", "special": "pickup", "wait": 8})
	_shots.append({"name": "hunter_lair_beat", "special": "lair", "wait": 45})
	_shots.append({"name": "hunter_catch", "special": "catch", "wait": 28})
	_shots.append({"name": "hunter_released", "special": "released", "wait": 90})
	_shots.append({"name": "map_overlay", "special": "map", "wait": 8})


func _next() -> void:
	_idx += 1
	if _idx >= _shots.size():
		for f in _frames:
			(f[1] as Image).save_png(OUT + f[0] + ".png")
			print("SAVED ", OUT + f[0] + ".png")
		quit(0)
		return
	var sh: Dictionary = _shots[_idx]
	var p := _level.get_node("Player") as CharacterBody3D
	_level.set("_in_dungeon", true)
	var cand = _level.get("_candle")
	if cand and not bool(cand.get("burning")):
		cand.call("toggle")   # the real path: lights the candle's own OmniLight
	if p.is_input_frozen():
		p.unfreeze_input()
	if sh.has("special"):
		_special(sh, p)
	else:
		_room_pose(sh, p)
	_pending = sh["name"]
	_wait = int(sh["wait"])


func _room_pose(sh: Dictionary, p: CharacterBody3D) -> void:
	var gen = _level.call("get_gen")
	var handles: Dictionary = _level.call("room_handles")
	var h: Dictionary = handles.get(sh["room"], {})
	var c: Vector3 = gen.room_center_world(sh["room"])
	var back: Vector2 = h.get("back", Vector2(0, 1))
	var bv := Vector3(back.x, 0, back.y)
	var r: Rect2i = gen.room_rect(sh["room"])
	var half: float = (r.size.x if absf(back.x) > 0.5 else r.size.y) * DungeonGen.CELL * 0.5
	var feet: Vector3 = c - bv * (half - 1.0)
	var look: Vector3 = c + bv * (half - 1.2) + Vector3(0, 1.0, 0)
	if sh["kind"] == "well" or sh["kind"] == "larder" or sh["kind"] == "crypt" or sh["kind"] == "gallery":
		look = c + Vector3(0, 1.0, 0)
	_place(p, feet, look)
	if bool(sh["fire"]):
		var lit := false
		for sc in _level.call("get_sconces"):
			if String(sc.name) == "Sconce_" + String(sh["room"]) and not sc.is_lit:
				_level.call("_on_sconce_interact", sc)
				lit = true
		if not lit:
			_level.call("_fire_room_scare", sh["room"])
		if sh["kind"] == "gallery":
			# look at the frame that fell: it is behind the pose, so turn round
			for f in _level.call("frames_in_room", sh["room"]):
				if f.has_fallen():
					_place(p, feet, (f as Node3D).global_position)


func _special(sh: Dictionary, p: CharacterBody3D) -> void:
	var ante: Vector3 = _level.get("ANTE_ORIGIN")
	match sh["special"]:
		"pickup":
			_level.set("_in_dungeon", false)
			_place(p, ante + Vector3(1.2, 0.1, -0.6), ante + Vector3(2.6 + 0.55, 0.95, -2.4))
		"lair":
			var gen = _level.call("get_gen")
			var handles: Dictionary = _level.call("room_handles")
			var lair: String = gen.lair_room
			var h: Dictionary = handles.get(lair, {})
			var c: Vector3 = gen.room_center_world(lair)
			_place(p, c + Vector3(0, 0.1, 1.8), c + Vector3(0, 1.0, -3.0))
			_level.call("lair_beat", lair, h.get("spawn_pos", c))
		"catch":
			_level.call("_on_hunter_caught")
		"released":
			pass   # 1.5 s after the catch: the hunter should be gone and input back
		"map":
			var gen = _level.call("get_gen")
			var m = _level.call("get_map")
			m.set_found(true)
			var seen: Array = []
			for nm in gen.chamber_names:
				seen.append(nm)
			for nm in gen.corridor_names:
				if seen.size() % 3 != 0:
					seen.append(nm)
			var lit: Array = []
			for sc in _level.call("get_sconces"):
				if sc.is_lit:
					lit.append(sc.global_position)
			m.refresh(seen, lit)
			m.toggle()


func _place(p: CharacterBody3D, feet: Vector3, look_at: Vector3) -> void:
	p.global_position = feet + Vector3(0, 0.1, 0)
	p.velocity = Vector3.ZERO
	var cam := p.get_node("Camera3D") as Camera3D
	var eye: Vector3 = feet + Vector3(0, 1.65, 0)
	var to: Vector3 = look_at - eye
	p.rotation.y = atan2(-to.x, -to.z)
	var flat := Vector2(to.x, to.z).length()
	cam.rotation.x = atan2(to.y, flat)
	if p.has_method("set"):
		p.set("_pitch", cam.rotation.x)


func _capture(shot_name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	_frames.append([shot_name, img])
	print("captured ", shot_name)
