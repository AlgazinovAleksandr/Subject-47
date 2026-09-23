extends RefCounted

# Existing focused combat tests start at the hunt. check_breach_approach walks
# the entire shipping approach and proves the physical trigger separately.
static func enter(level: Node) -> void:
	level.get("_approach").call("seal_immediate")
	level.call("_on_approach_committed")
	var player: Node3D = level.get_node("Player")
	player.position = Vector3(0, 0.1, -2)
	player.rotation = Vector3(0, PI, 0)
