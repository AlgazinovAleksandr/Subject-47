extends SceneTree
var _t := 0.0
func _initialize() -> void:
	change_scene_to_file("res://scenes/corridor.tscn")
func _process(delta: float) -> bool:
	_t += delta
	if current_scene == null or _t < 1.5:
		return false
	var lvl := current_scene
	var pt: Dictionary = lvl.call("_path_point", 118.0)
	print("pt118 pos=%s dir=%s side=%s" % [pt["pos"], pt["dir"], pt["side"]])
	var e: Dictionary = (lvl.call("forks") as Array)[0]
	for k in ["mouthA", "mouthC", "cornerA", "cornerC", "dir", "fwd"]:
		print("  %s = %s" % [k, str(e[k])])
	for n in lvl.get_children():
		if String(n.name).begins_with("Fork0"):
			var b := n as CSGBox3D
			if b:
				print("  box %s pos=%s size=%s" % [n.name, b.position, b.size])
			else:
				print("  node %s at %s" % [n.name, (n as Node3D).position if n is Node3D else "-"])
	var space: PhysicsDirectSpaceState3D = lvl.get_node("Player").get_world_3d().direct_space_state
	var dir3: Vector3 = e["dir"]
	for probe in [["mouth+1", (e["mouthA"] as Vector3) + dir3 * 1.0], ["mouth+4", (e["mouthA"] as Vector3) + dir3 * 4.0],
			["mouth+6.5", (e["mouthA"] as Vector3) + dir3 * 6.5], ["cornerA", e["cornerA"]], ["midB", ((e["cornerA"] as Vector3) + (e["cornerC"] as Vector3)) / 2.0],
			["cornerC", e["cornerC"]], ["C mid", ((e["cornerC"] as Vector3) + (e["mouthC"] as Vector3)) / 2.0], ["mouthC+1", (e["mouthC"] as Vector3) + dir3 * 1.0]]:
		var p: Vector3 = probe[1]
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p + Vector3(0, -1.0, 0))
		var hit: Dictionary = space.intersect_ray(q)
		print("  floor under %s %s -> %s" % [probe[0], str(p.round()), (hit["collider"].name if hit else "NOTHING")])
	quit(0)
	return true
