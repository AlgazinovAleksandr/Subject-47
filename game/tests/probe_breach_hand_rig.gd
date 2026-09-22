extends SceneTree
# Throwaway: measure the hollow-crown rig for the approach's hand puppet.
func _initialize() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var rig := CreatureAnim.build(holder)
	rig.hold_pose(CreatureAnim.CLIP_WALK, 0.0)
	await process_frame
	await process_frame
	var sk := rig.skeleton()
	print("root yaw ", rig.visual_root().rotation, " scale ", rig.visual_root().scale)
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.contains("Arm") or n.contains("Hand") or n.contains("Head") or n.contains("Hips") or n.contains("Shoulder") or n.contains("Index") or n.contains("Middle"):
			print("%-28s %s" % [n, sk.to_global(sk.get_bone_global_pose(i).origin)])
	var aabb := AABB()
	for m in rig.mesh_instances():
		var a: AABB = m.global_transform * m.get_aabb()
		aabb = a if aabb.size == Vector3.ZERO else aabb.merge(a)
	print("mesh aabb ", aabb)
	quit(0)
