extends SceneTree

# The ASSET contract for the creature model. No level, no creature script — just the GLB.
#
#   Godot --headless --path game --script res://tests/check_creature_model.gd
#
# ⚠️ WHY THIS EXISTS AND WHY IT IS FIRST. The model this replaces (`Void_creature.glb`) shipped
# for months with **zero animations** and was rendered as a T-pose in three levels, while every
# test in the suite stayed green — because nothing anywhere asserted anything about the asset.
# The one piece of code that was supposed to fix the pose (`_pose_arms_down()`, three identical
# copies) was measured in 2026-08 to move nothing at all.
#
# ⚠️ AND THE SILENT-FALLBACK TRAP IS REAL. All three creature scripts load the GLB with
# `ResourceLoader.exists()` + `load()` and fall back to a procedural capsule when it is missing.
# Godot does not see a new asset until `--import` has run. So: forget the import, and every
# creature in the game quietly becomes a grey capsule, and every existing test still passes.
# Assertion 1 below is the guard for exactly that, and it is the reason this file runs before
# `check_creature_anim.gd`.
#
# WHAT IT ASSERTS
#   1. the GLB resolves at all (the forgotten --import)
#   2. the rig is intact — one skeleton, one mesh, the named bones
#   3. six clips with the expected durations
#   4. NO CLIP TRANSLATES THE ROOT — the `run_fast_10` class of bug, which would slide the mesh
#      2.25 m off its own collider every cycle
#   5. it is not in bind pose — the animations actually move bones
#   6. it is NOT SELF-LIT and NOT METAL — the two traps baked into the source material
#   7. it faces the axis the creature scripts already assume
#   8. it is the height the .import's root_scale claims
#   9. the polygon budget is on the record

const GLB := "res://assets/models/hollow_crown.glb"

# clip -> duration in seconds, from tools/merge_creature_glb.py's own printout.
# ⚠️ Godot resamples to `animation/fps=30` on import, so a tolerance of one frame is required;
# anything tighter fails for a reason that has nothing to do with the asset being wrong.
const CLIPS := {
	"walk": 1.067, "shamble": 5.533, "unsteady": 3.000,
	"run": 0.667, "sprint": 0.500, "charge": 0.833,
}
const FRAME := 1.0 / 30.0

# The merge tool reports the bind mesh at 1.6400 m and the .import applies root_scale 1.2012.
const TARGET_H := 1.97
const H_TOL := 0.10

# ⚠️ A LOOSER BOUND THAN IT LOOKS. `shamble` and `unsteady` are deliberately drunken — the
# measured mid-clip Hips excursion is up to 43 cm laterally before scaling — so this cannot be
# tight. What it is really catching is a clip that WALKS AWAY, i.e. `charge`'s 2.279 m. The
# end-to-end bound below is the strict half.
#
# ⚠️⚠️ MEASURE IN WORLD SPACE. `Skeleton3D.get_bone_global_pose()` returns SKELETON space, and
# this rig's bones are in CENTIMETRES under an Armature scaled 0.01 — so the first version of
# this test read "shamble drifts 51.497 m" and failed six clips on a perfectly good asset. The
# conversion is `skel.global_transform * pose.origin`, and it is the same trap for the height
# check: for a SKINNED mesh the MeshInstance3D's own transform is not what renders it, the
# skeleton is, so `mi.global_transform * mesh.get_aabb()` reported a 2 cm creature.
const MAX_MID_DRIFT := 0.75
const MAX_END_DRIFT := 0.02

var _fails: Array[String] = []
var _checks := 0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _find(n: Node, cls: String, out: Array) -> void:
	if n.get_class() == cls:
		out.append(n)
	for c in n.get_children():
		_find(c, cls, out)


func _process(_delta: float) -> bool:
	print("== CREATURE MODEL ==")

	# ------------------------------------------------------------------ 1. it resolves
	_ok("the merged GLB exists (did you run --import?)", ResourceLoader.exists(GLB), GLB)
	if not ResourceLoader.exists(GLB):
		print("== %d checks, %d failed ==" % [_checks, _fails.size()])
		quit(1)
		return true
	var packed: PackedScene = load(GLB)
	_ok("it loads as a PackedScene", packed != null)
	var inst: Node3D = packed.instantiate()
	root.add_child(inst)

	# ------------------------------------------------------------------ 2. the rig
	var skels: Array = []
	var meshes: Array = []
	var players: Array = []
	_find(inst, "Skeleton3D", skels)
	_find(inst, "MeshInstance3D", meshes)
	_find(inst, "AnimationPlayer", players)
	_ok("exactly one Skeleton3D", skels.size() == 1, "%d found" % skels.size())
	_ok("exactly one MeshInstance3D", meshes.size() == 1, "%d found" % meshes.size())
	_ok("exactly one AnimationPlayer", players.size() == 1, "%d found" % players.size())
	if skels.is_empty() or meshes.is_empty() or players.is_empty():
		print("== %d checks, %d failed ==" % [_checks, _fails.size()])
		quit(1)
		return true
	var skel: Skeleton3D = skels[0]
	var mi: MeshInstance3D = meshes[0]
	var ap: AnimationPlayer = players[0]

	_ok("24 bones", skel.get_bone_count() == 24, "%d" % skel.get_bone_count())
	var hips := skel.find_bone("Hips")
	var head := skel.find_bone("Head")
	var larm := skel.find_bone("LeftArm")
	var hfront := skel.find_bone("headfront")
	var hend := skel.find_bone("head_end")
	for pair in [["Hips", hips], ["Head", head], ["LeftArm", larm],
			["headfront", hfront], ["head_end", hend]]:
		_ok("bone '%s' resolves" % pair[0], int(pair[1]) >= 0)

	# ------------------------------------------------------------------ 3. six clips
	var have := ap.get_animation_list()
	var names: Array[String] = []
	for a in have:
		names.append(String(a).get_file())
	_ok("six clips present", have.size() == 6, "got %s" % str(names))
	var lib := ""
	for a in have:
		if String(a).contains("/"):
			lib = String(a).get_slice("/", 0) + "/"
			break
	for clip in CLIPS.keys():
		var full: String = lib + String(clip)
		var anim: Animation = ap.get_animation(full)
		_ok("clip '%s' exists" % clip, anim != null)
		if anim:
			var want: float = CLIPS[clip]
			_ok("clip '%s' is %.3fs" % [clip, want], absf(anim.length - want) <= FRAME * 1.5,
				"got %.3f" % anim.length)

	# ------------------------------------------------------------------ 4/5. motion
	# ⚠️ Sampled through the real AnimationPlayer with `seek(t, true)` and read off the
	# SKELETON's global bone pose — not off the Animation resource's keys. The keys are what the
	# merge tool already printed; what matters here is what Godot's importer + retargeting
	# actually produce, which is a different thing and is where an import setting could silently
	# reintroduce root motion.
	var moved_bones := 0
	for clip in CLIPS.keys():
		var full: String = lib + String(clip)
		if not ap.has_animation(full):
			continue
		var anim: Animation = ap.get_animation(full)
		ap.play(full)
		ap.seek(0.0, true)
		var origin0: Vector3 = skel.global_transform * skel.get_bone_global_pose(hips).origin
		var rest_arm: Quaternion = skel.get_bone_rest(larm).basis.get_rotation_quaternion()
		var worst_mid := 0.0
		var max_arm_swing := 0.0
		for i in range(1, 21):
			var t: float = anim.length * float(i) / 20.0
			ap.seek(t, true)
			var o: Vector3 = skel.global_transform * skel.get_bone_global_pose(hips).origin
			var d := Vector2(o.x - origin0.x, o.z - origin0.z).length()
			worst_mid = maxf(worst_mid, d)
			var q: Quaternion = skel.get_bone_pose_rotation(larm)
			max_arm_swing = maxf(max_arm_swing, rad_to_deg(q.angle_to(rest_arm)))
		ap.seek(anim.length, true)
		var oend: Vector3 = skel.global_transform * skel.get_bone_global_pose(hips).origin
		var end_d := Vector2(oend.x - origin0.x, oend.z - origin0.z).length()

		_ok("'%s' never walks away from its own collider" % clip, worst_mid <= MAX_MID_DRIFT,
			"worst mid-clip root drift %.3f m (limit %.2f)" % [worst_mid, MAX_MID_DRIFT])
		_ok("'%s' ends where it started" % clip, end_d <= MAX_END_DRIFT,
			"end-to-end root drift %.4f m (limit %.2f)" % [end_d, MAX_END_DRIFT])
		if max_arm_swing > 5.0:
			moved_bones += 1
		_ok("'%s' actually animates a limb" % clip, max_arm_swing > 5.0,
			"LeftArm swings %.1f deg from rest" % max_arm_swing)
	ap.stop()
	_ok("every clip moves the skeleton (not a bind-pose model)", moved_bones == CLIPS.size(),
		"%d of %d" % [moved_bones, CLIPS.size()])

	# ------------------------------------------------------------------ 6. not lit, not metal
	var mesh: Mesh = mi.mesh
	_ok("the mesh has a surface", mesh != null and mesh.get_surface_count() >= 1)
	for s in range(mesh.get_surface_count()):
		var m := mesh.surface_get_material(s) as StandardMaterial3D
		_ok("surface %d has a StandardMaterial3D" % s, m != null)
		if m == null:
			continue
		# ⚠️ THE TWO TRAPS. The source had no `metallicFactor` at all, and glTF's default is
		# 1.0 — a 100 % metal creature is a black mirror at 0.02 ambient. And its albedo map was
		# ALSO wired as an emissive texture at full strength, which in a game built on "you only
		# see what the torch finds" is the single thing that cannot ship.
		_ok("surface %d is not metal" % s, m.metallic <= 0.01, "metallic %.3f" % m.metallic)
		_ok("surface %d is not self-lit" % s, not m.emission_enabled,
			"emission_enabled %s" % str(m.emission_enabled))
		_ok("surface %d KEPT its texture" % s, m.albedo_texture != null,
			"a retint that drops this is the bug the swap exists to fix")

	# ------------------------------------------------------------------ 7. facing
	# The creature scripts all compute yaw as atan2(dir.x, dir.z) and forward as
	# (sin(y), 0, cos(y)), i.e. they treat +Z as forward. The rig must agree, or every creature
	# in the game runs backwards (corridor.gd shipped exactly that once — Issue 102).
	if hfront >= 0 and hend >= 0:
		var zf: float = (skel.global_transform * skel.get_bone_global_pose(hfront).origin).z
		var zb: float = (skel.global_transform * skel.get_bone_global_pose(hend).origin).z
		_ok("the rig faces +Z, like every creature script assumes", zf > zb,
			"headfront z %.3f vs head_end z %.3f" % [zf, zb])

	# ------------------------------------------------------------------ 8. height
	# ⚠️ From the BONES in world space, not from the mesh AABB. A skinned mesh is posed by its
	# skeleton, so the MeshInstance3D's transform says nothing about how big it renders — the
	# first version of this check multiplied the (already correct) 1.970 m mesh AABB by the
	# MeshInstance3D's 0.020 scale and reported a 2 cm monster.
	var lowest := 1e9
	var highest := -1e9
	ap.stop()
	skel.reset_bone_poses()
	for b in range(skel.get_bone_count()):
		var wp: Vector3 = skel.global_transform * skel.get_bone_global_pose(b).origin
		lowest = minf(lowest, wp.y)
		highest = maxf(highest, wp.y)
	var bone_span := highest - lowest
	# Bone span is crown-of-skull-joint to toe-joint, i.e. a little under the silhouette; the
	# mesh AABB is the silhouette. Assert on the mesh, report both.
	var mesh_h: float = mesh.get_aabb().size.y
	_ok("the mesh is about %.2f m tall (root_scale applied)" % TARGET_H,
		absf(mesh_h - TARGET_H) <= H_TOL,
		"mesh AABB %.3f m, bone span %.3f m" % [mesh_h, bone_span])
	_ok("the skeleton is posed at the same scale as the mesh",
		bone_span > TARGET_H * 0.6 and bone_span < TARGET_H * 1.1,
		"bone span %.3f m — if this is ~100x the mesh, the cm/metre unit split is unresolved"
			% bone_span)

	# ------------------------------------------------------------------ 9. budget, on the record
	var arrays: Array = mesh.surface_get_arrays(0)
	var vcount: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var icount: int = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
	print("  INFO  budget: %d verts, %d tris  (4 stalkers in the Void = %d tris on screen)"
		% [vcount, icount / 3, (icount / 3) * 4])
	_ok("under the stated 120k-triangle budget", icount / 3 <= 120000, "%d tris" % (icount / 3))

	inst.queue_free()
	print("== %d checks, %d failed ==" % [_checks, _fails.size()])
	for f in _fails:
		print("   FAILED: " + f)
	quit(1 if _fails.size() > 0 else 0)
	return true
