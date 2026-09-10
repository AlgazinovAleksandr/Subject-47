extends SceneTree
# Do a SlamDoor's / PurgeChamber's frame uprights actually stand proud of their wall?
# ⚠️ Wait past _pick_clear_swings()'s 1.5 s deferred timer.
var _t := 0.0
func _initialize() -> void:
	change_scene_to_file("res://scenes/level_6_breach.tscn")
func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children(): _all(c, out)
func _process(d: float) -> bool:
	_t += d
	if _t < 3.0 or current_scene == null: return false
	var nodes: Array = []
	_all(current_scene, nodes)
	var space := current_scene.get_world_3d().direct_space_state
	for x in nodes:
		var nm := String(x.name)
		if not (x is MeshInstance3D): continue
		if not (nm.begins_with("Casing") or nm == "Transom" or nm.contains("Jamb")): continue
		pass
	# Sample the jamb meshes of the first slam door and the purge chamber.
	for parent_name in ["Slam_Corridor1_Junction1", "Slam_ArchiveB_WardB", "PurgeChamber"]:
		var par := current_scene.get_node_or_null(parent_name)
		if par == null: continue
		var w: float = float(par.get("door_width")) if par.get("door_width") != null else -1.0
		var jambs: Array = []
		for c in par.get_children():
			if c is MeshInstance3D and (c.mesh as BoxMesh):
				var s: Vector3 = (c.mesh as BoxMesh).size
				# a jamb is tall and thin in x
				if s.y > 1.5 and s.x < 0.2:
					jambs.append(c)
		var buried := 0
		var total := 0
		for j in jambs:
			var sz: Vector3 = (j.mesh as BoxMesh).size
			for f in [-0.5, 0.5]:
				var pt: Vector3 = j.global_transform * Vector3(0, 0, sz.z * f * 0.92)
				var q := PhysicsPointQueryParameters3D.new()
				q.position = pt
				q.collision_mask = 1
				total += 1
				if not space.intersect_point(q, 4).is_empty(): buried += 1
		print("%-28s width %.2f  jambs %d  buried face-samples %d of %d"
			% [parent_name, w, jambs.size(), buried, total])
	quit(0); return true
