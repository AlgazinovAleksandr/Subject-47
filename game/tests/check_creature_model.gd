extends SceneTree

# The ASSET contract for the creature models. No level, no creature script — just the GLBs.
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
# ⭐ TABLE-DRIVEN SINCE 2026-09-12: THE NIGHTMARE's hunter is a second model (`parasite.glb`, a
# 69-bone Mixamo rig with two clips, built by tools/fbx_to_glb.py + merge_creature_glb.py
# --profile parasite). Every row below states its own rig, clips, facing bones and height; the
# hollow_crown row is the previous file's literals, untouched.
#
# WHAT IT ASSERTS, PER MODEL
#   1. the GLB resolves at all (the forgotten --import)
#   2. the rig is intact — one skeleton, one mesh, the named bones
#   3. the clips, with the expected durations
#   4. NO CLIP TRANSLATES THE ROOT — the `run_fast_10` class of bug, which would slide the mesh
#      2.25 m off its own collider every cycle
#   5. it is not in bind pose — the animations actually move bones
#   6. it is NOT SELF-LIT and NOT METAL — the two traps baked into a source material
#   7. it faces the axis the creature scripts already assume
#   8. it is the height the .import's root_scale claims
#   9. the polygon budget is on the record

const MODELS := [
	{
		"name": "hollow_crown",
		"glb": "res://assets/models/hollow_crown.glb",
		# clip -> duration in seconds, from tools/merge_creature_glb.py's own printout.
		"clips": {"walk": 1.067, "shamble": 5.533, "unsteady": 3.000,
			"run": 0.667, "sprint": 0.500, "charge": 0.833},
		"bones": 24,
		"named": ["Hips", "Head", "LeftArm", "headfront", "head_end"],
		"hips": "Hips", "arm": "LeftArm",
		"front": ["headfront", "head_end"],   # front bone z > back bone z  =>  faces +Z
		# The merge tool reports the bind mesh at 1.6400 m and the .import applies root_scale 1.2012.
		"target_h": 1.97,
	},
	{
		"name": "parasite",
		"glb": "res://assets/models/parasite.glb",
		"clips": {"walk": 1.467, "run": 0.667},
		"bones": 69,
		# ⚠️ Godot sanitises `mixamorig:Hips` to `mixamorig_Hips`; _bone() tries both spellings.
		"named": ["mixamorig_Hips", "mixamorig_Head", "mixamorig_LeftArm",
			"mixamorig_LeftFoot", "mixamorig_LeftToe_End"],
		"hips": "mixamorig_Hips", "arm": "mixamorig_LeftArm",
		"front": ["mixamorig_LeftToe_End", "mixamorig_LeftFoot"],   # toes ahead of the heel
		"target_h": 2.01,   # ships at its natural size, root_scale 1.0
	},
]
# ⚠️ Godot resamples to `animation/fps=30` on import, so a tolerance of one frame is required;
# anything tighter fails for a reason that has nothing to do with the asset being wrong.
const FRAME := 1.0 / 30.0
const H_TOL := 0.10

# ⚠️ A LOOSER BOUND THAN IT LOOKS. `shamble` and `unsteady` are deliberately drunken — the
# measured mid-clip Hips excursion is up to 43 cm laterally before scaling — so this cannot be
# tight. What it is really catching is a clip that WALKS AWAY, i.e. `charge`'s 2.279 m. The
# end-to-end bound below is the strict half.
#
# ⚠️⚠️ MEASURE IN WORLD SPACE. `Skeleton3D.get_bone_global_pose()` returns SKELETON space, and
# both rigs' bones are in CENTIMETRES under an Armature scaled 0.01 — so the first version of
# this test read "shamble drifts 51.497 m" and failed six clips on a perfectly good asset. The
# conversion is `skel.global_transform * pose.origin`, and it is the same trap for the height
# check: for a SKINNED mesh the MeshInstance3D's own transform is not what renders it, the
# skeleton is, so `mi.global_transform * mesh.get_aabb()` reported a 2 cm creature.
const MAX_MID_DRIFT := 0.75
const MAX_END_DRIFT := 0.02
const MIN_CHECKS := 60   # the sample-size floor: two models' worth of assertions

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


func _bone(skel: Skeleton3D, name: String) -> int:
	var i := skel.find_bone(name)
	if i < 0:
		i = skel.find_bone(name.replace("_", ":"))
	return i


func _process(_delta: float) -> bool:
	for M in MODELS:
		_check_model(M)
	_ok("sample size: at least %d checks ran" % MIN_CHECKS, _checks >= MIN_CHECKS, "%d" % _checks)
	print("== %d checks, %d failed ==" % [_checks, _fails.size()])
	for f in _fails:
		print("   FAILED: " + f)
	quit(1 if _fails.size() > 0 else 0)
	return true


func _check_model(M: Dictionary) -> void:
	var tag: String = M["name"]
	var GLB: String = M["glb"]
	var CLIPS: Dictionary = M["clips"]
	print("== CREATURE MODEL [%s] ==" % tag)

	# ------------------------------------------------------------------ 1. it resolves
	_ok("[%s] the merged GLB exists (did you run --import?)" % tag, ResourceLoader.exists(GLB), GLB)
	if not ResourceLoader.exists(GLB):
		return
	var packed: PackedScene = load(GLB)
	_ok("[%s] it loads as a PackedScene" % tag, packed != null)
	if packed == null:
		return
	var inst: Node3D = packed.instantiate()
	root.add_child(inst)

	# ------------------------------------------------------------------ 2. the rig
	var skels: Array = []
	var meshes: Array = []
	var players: Array = []
	_find(inst, "Skeleton3D", skels)
	_find(inst, "MeshInstance3D", meshes)
	_find(inst, "AnimationPlayer", players)
	_ok("[%s] exactly one Skeleton3D" % tag, skels.size() == 1, "%d found" % skels.size())
	_ok("[%s] exactly one MeshInstance3D" % tag, meshes.size() == 1, "%d found" % meshes.size())
	_ok("[%s] exactly one AnimationPlayer" % tag, players.size() == 1, "%d found" % players.size())
	if skels.is_empty() or meshes.is_empty() or players.is_empty():
		inst.queue_free()
		return
	var skel: Skeleton3D = skels[0]
	var mi: MeshInstance3D = meshes[0]
	var ap: AnimationPlayer = players[0]

	_ok("[%s] %d bones" % [tag, M["bones"]], skel.get_bone_count() == int(M["bones"]),
		"%d" % skel.get_bone_count())
	var hips := _bone(skel, M["hips"])
	var larm := _bone(skel, M["arm"])
	for nm in M["named"]:
		_ok("[%s] bone '%s' resolves" % [tag, nm], _bone(skel, nm) >= 0)
	if hips < 0 or larm < 0:
		inst.queue_free()
		return

	# ------------------------------------------------------------------ 3. the clips
	var have := ap.get_animation_list()
	var names: Array[String] = []
	for a in have:
		names.append(String(a).get_file())
	_ok("[%s] %d clips present" % [tag, CLIPS.size()], have.size() == CLIPS.size(),
		"got %s" % str(names))
	var lib := ""
	for a in have:
		if String(a).contains("/"):
			lib = String(a).get_slice("/", 0) + "/"
			break
	for clip in CLIPS.keys():
		var full: String = lib + String(clip)
		var anim: Animation = ap.get_animation(full)
		_ok("[%s] clip '%s' exists" % [tag, clip], anim != null)
		if anim:
			var want: float = CLIPS[clip]
			_ok("[%s] clip '%s' is %.3fs" % [tag, clip, want],
				absf(anim.length - want) <= FRAME * 1.5, "got %.3f" % anim.length)

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

		_ok("[%s] '%s' never walks away from its own collider" % [tag, clip],
			worst_mid <= MAX_MID_DRIFT,
			"worst mid-clip root drift %.3f m (limit %.2f)" % [worst_mid, MAX_MID_DRIFT])
		_ok("[%s] '%s' ends where it started" % [tag, clip], end_d <= MAX_END_DRIFT,
			"end-to-end root drift %.4f m (limit %.2f)" % [end_d, MAX_END_DRIFT])
		if max_arm_swing > 5.0:
			moved_bones += 1
		_ok("[%s] '%s' actually animates a limb" % [tag, clip], max_arm_swing > 5.0,
			"arm swings %.1f deg from rest" % max_arm_swing)
	ap.stop()
	_ok("[%s] every clip moves the skeleton (not a bind-pose model)" % tag,
		moved_bones == CLIPS.size(), "%d of %d" % [moved_bones, CLIPS.size()])

	# ------------------------------------------------------------------ 6. not lit, not metal
	var mesh: Mesh = mi.mesh
	_ok("[%s] the mesh has a surface" % tag, mesh != null and mesh.get_surface_count() >= 1)
	for s in range(mesh.get_surface_count()):
		var m := mesh.surface_get_material(s) as StandardMaterial3D
		_ok("[%s] surface %d has a StandardMaterial3D" % [tag, s], m != null)
		if m == null:
			continue
		# ⚠️ THE TWO TRAPS. The hollow_crown source had no `metallicFactor` at all (glTF's default
		# is 1.0 — a 100 % metal creature is a black mirror at 0.02 ambient) and its albedo map
		# was ALSO wired as an emissive texture at full strength; the Parasite's Blender export
		# arrived at metallic 0.5. In a game built on "you only see what the torch finds", a
		# self-lit or mirror creature is the single thing that cannot ship.
		_ok("[%s] surface %d is not metal" % [tag, s], m.metallic <= 0.01, "metallic %.3f" % m.metallic)
		_ok("[%s] surface %d is not self-lit" % [tag, s], not m.emission_enabled,
			"emission_enabled %s" % str(m.emission_enabled))
		_ok("[%s] surface %d KEPT its texture" % [tag, s], m.albedo_texture != null,
			"a retint that drops this is the bug the swap exists to fix")

	# ------------------------------------------------------------------ 7. facing
	# The creature scripts all compute yaw as atan2(dir.x, dir.z) and forward as
	# (sin(y), 0, cos(y)), i.e. they treat +Z as forward. The rig must agree, or every creature
	# in the game runs backwards (corridor.gd shipped exactly that once — Issue 102).
	ap.stop()
	skel.reset_bone_poses()
	var fb := _bone(skel, M["front"][0])
	var bb := _bone(skel, M["front"][1])
	if fb >= 0 and bb >= 0:
		var zf: float = (skel.global_transform * skel.get_bone_global_pose(fb).origin).z
		var zb: float = (skel.global_transform * skel.get_bone_global_pose(bb).origin).z
		_ok("[%s] the rig faces +Z, like every creature script assumes" % tag, zf > zb,
			"%s z %.3f vs %s z %.3f" % [M["front"][0], zf, M["front"][1], zb])

	# ------------------------------------------------------------------ 8. height
	# ⚠️ From the BONES in world space, not from the mesh AABB. A skinned mesh is posed by its
	# skeleton, so the MeshInstance3D's transform says nothing about how big it renders — the
	# first version of this check multiplied the (already correct) 1.970 m mesh AABB by the
	# MeshInstance3D's 0.020 scale and reported a 2 cm monster.
	var lowest := 1e9
	var highest := -1e9
	for b in range(skel.get_bone_count()):
		var wp: Vector3 = skel.global_transform * skel.get_bone_global_pose(b).origin
		lowest = minf(lowest, wp.y)
		highest = maxf(highest, wp.y)
	var bone_span := highest - lowest
	var target_h: float = M["target_h"]
	# Bone span is crown-of-skull-joint to toe-joint, i.e. a little under the silhouette; the
	# mesh AABB is the silhouette. Assert on the mesh, report both.
	var mesh_h: float = mesh.get_aabb().size.y
	_ok("[%s] the mesh is about %.2f m tall (root_scale applied)" % [tag, target_h],
		absf(mesh_h - target_h) <= H_TOL,
		"mesh AABB %.3f m, bone span %.3f m" % [mesh_h, bone_span])
	_ok("[%s] the skeleton is posed at the same scale as the mesh" % tag,
		bone_span > target_h * 0.6 and bone_span < target_h * 1.1,
		"bone span %.3f m — if this is ~100x the mesh, the cm/metre unit split is unresolved"
			% bone_span)

	# ------------------------------------------------------------------ 9. budget, on the record
	var tris_total := 0
	var verts_total := 0
	for s in range(mesh.get_surface_count()):
		var arrays: Array = mesh.surface_get_arrays(s)
		verts_total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var idx = arrays[Mesh.ARRAY_INDEX]
		tris_total += (idx.size() / 3) if idx != null else 0
	print("  INFO  [%s] budget: %d verts, %d tris  (x4 on screen = %d tris)"
		% [tag, verts_total, tris_total, tris_total * 4])
	_ok("[%s] under the stated 120k-triangle budget" % tag, tris_total <= 120000,
		"%d tris" % tris_total)

	inst.queue_free()
