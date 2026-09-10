extends SceneTree

# Photograph THE FLOOD's six ritual pieces (2026-09-10) — each one lying in the object it was
# hauled out of, and then all six set on the altar. **Run WITHOUT --headless.**
#
#   Godot --path game --script res://tests/screenshot_flood_pieces.gd -- --out=<dir>
#
# The headless guards say a candle, a book, a skull, a bell, a key and a doll exist and are
# built from parts; only a picture can say whether they READ as those things under a torch in
# a near-black room, which is the whole of the user's complaint about the grey shards.
# Frames are captured into memory and written at the end (a 5 MP save stalls the frame it
# runs in).

var OUT := "/tmp/flood_pieces/"

var _t := 0.0
var _stage := 0
var _pending: Array = []
var _scene: Node
var _player: Node3D
var _zone: Node
var _items: Array = []
var _idx := 0
var _plate: Node3D
# ⚠️ A pose set in the frame of the capture is NOT what the capture shows — the camera's
# transform reaches the renderer a frame later. Every close-up poses, waits one frame, shoots.
var _posed := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--out="):
			OUT = String(a).trim_prefix("--out=").trim_suffix("/") + "/"
	seed(7)
	change_scene_to_file("res://scenes/backrooms.tscn")


func _all(n: Node, acc: Array) -> Array:
	for c in n.get_children():
		acc.append(c)
		_all(c, acc)
	return acc


func _shoot(name: String) -> void:
	_pending.append([name, get_root().get_viewport().get_texture().get_image()])


func _flush() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for p in _pending:
		(p[1] as Image).save_png(OUT + String(p[0]) + ".png")
	print("wrote %d frames to %s" % [_pending.size(), OUT])


func _world_aabb(n: Node3D) -> AABB:
	var out := AABB(n.global_position, Vector3.ZERO)
	var first := true
	for c in _all(n, []):
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			var local := mi.get_aabb()
			var t := mi.global_transform
			for i in range(8):
				var corner: Vector3 = local.position + Vector3(local.size.x * float(i & 1),
					local.size.y * float((i >> 1) & 1), local.size.z * float((i >> 2) & 1))
				var w: Vector3 = t * corner
				if first:
					out = AABB(w, Vector3.ZERO)
					first = false
				else:
					out = out.expand(w)
	return out


# Stand `dist` from a prop's open side (toward its room centre), eye on its centre.
func _stand_at(prop: Node3D, dist: float, aim_y_off: float = 0.0) -> void:
	var aabb := _world_aabb(prop)
	var aim: Vector3 = aabb.get_center() + Vector3(0, aim_y_off, 0)
	var origin: Vector3 = _zone.get("_origin")
	var toward: Vector3 = Vector3.ZERO
	# The Flood's rooms are read off the zone's own table.
	for r in _zone.get("ROOMS"):
		var p: Vector2 = r["pos"]
		var s: Vector2 = r["size"]
		var c := origin + Vector3(p.x, 0, p.y)
		var local := prop.global_position - c
		if absf(local.x) <= s.x / 2.0 and absf(local.z) <= s.y / 2.0:
			toward = c - prop.global_position
			toward.y = 0.0
			break
	if toward.length() < 0.2:
		toward = Vector3(0, 0, 1)
	toward = toward.normalized()
	var radius: float = maxf(aabb.size.x, aabb.size.z) * 0.5
	var stand: Vector3 = aim + toward * (dist + radius)
	_player.global_position = Vector3(stand.x, origin.y + 0.1, stand.z)
	_player.velocity = Vector3.ZERO
	_player.call("force_update_transform")
	_player.call("ai_look_at", aim)


func _process(delta: float) -> bool:
	_t += delta
	if current_scene == null:
		return false
	if _scene == null and _t < 3.0:
		return false
	match _stage:
		0:
			_scene = current_scene
			_player = _scene.get_node_or_null("Player") as Node3D
			_zone = _scene.get_node_or_null("ZoneFlood")
			if _player == null or _zone == null:
				print("FAIL: no player/zone")
				quit(1)
				return true
			_scene.call("_enter_zone", 3)
			for n in _all(_zone, []):
				var s: Script = n.get_script()
				var g := String(s.get_global_name()) if s != null else ""
				if g == "Apparition" or g == "Beartrap" or String(n.name).ends_with("Event"):
					n.queue_free()
			_player.call("set_smiler_active", true)
			_player.set("ai_active", true)
			for n in _player.get_children():
				if n is CanvasLayer:
					n.visible = false
			var item_script: GDScript = load("res://scripts/sunken_item.gd")
			for n in _all(_zone, []):
				if n.get_script() == item_script:
					_items.append(n)
			_plate = _zone.get_node_or_null("FloodPlate") as Node3D
			print("%d items, plate %s" % [_items.size(), _plate != null])
			_t = 0.0
			_stage = 1
			return false
		1:
			# Per item: haul it open (through the shipping ray), wait, take a frame, and lift
			# the piece so the altar can be filled at the end.
			if _idx >= _items.size():
				_t = 0.0
				_stage = 3
				return false
			var it: Node3D = _items[_idx]
			_stand_at(it, 1.0, 0.15)
			if not bool(it.get("is_searched")):
				it.call("interact")
			_t = 0.0
			_stage = 2
			return false
		2:
			if _t < 1.3:
				return false
			var it: Node3D = _items[_idx]
			var frag := it.get_node_or_null("Fragment") as Node3D
			if frag and not _posed:
				var a := _world_aabb(frag)
				var origin: Vector3 = _zone.get("_origin")
				var c := a.get_center()
				# Close: 0.75 m from the piece, from the object's own FRONT (its local -z —
				# a wheelchair's seat is only visible past the backrest from the footplate side).
				# ⚠️ The VISUAL's basis, not the item's: a wheelchair turns 0.9 rad when "opened".
				var vis := it.get_node_or_null("Visual") as Node3D
				var toward := -(vis if vis else it).global_transform.basis.z
				toward.y = 0.0
				toward = toward.normalized()
				var stand := c + toward * 0.75
				_player.global_position = Vector3(stand.x, origin.y + 0.1, stand.z)
				_player.call("force_update_transform")
				_player.call("ai_look_at", c)
				_posed = true
				return false
			_posed = false
			_shoot("piece_%d_%s" % [_idx, String(it.call("piece_kind"))])
			# Lift it, dismissing the page that arrives.
			it.call("interact")
			var ui := root.get_node_or_null("/root/NoteUI")
			if ui != null and bool(ui.get("is_open")):
				ui.call("_close")
			_idx += 1
			_stage = 1
			return false
		3:
			if _t < 0.3:
				return false
			var ui := root.get_node_or_null("/root/NoteUI")
			if ui != null and bool(ui.get("is_open")):
				ui.call("_close")
			_stand_at(_plate, 1.0, 0.4)
			_shoot("altar_empty")
			_zone.call("_on_plate_used")
			_t = 0.0
			_stage = 4
			return false
		4:
			if _t < 2.4:
				return false
			if not _posed:
				var origin: Vector3 = _zone.get("_origin")
				# In the plate's OWN frame: the board is on local +z, so stand on -z, 1.1 m
				# out, looking down at the slots.
				var top_y: float = float(_plate.get("TOP_Y")) + 0.1
				var stand: Vector3 = _plate.to_global(Vector3(0, 0, -1.15))
				_player.global_position = Vector3(stand.x, origin.y + 0.1, stand.z)
				_player.call("force_update_transform")
				_player.call("ai_look_at", _plate.to_global(Vector3(0, top_y, 0.05)))
				_posed = true
				return false
			_shoot("altar_set")
			_flush()
			print("held %d set %s" % [int(_zone.call("pieces_held")), str(_zone.call("set_kinds"))])
			quit(0)
			return true
	return false
