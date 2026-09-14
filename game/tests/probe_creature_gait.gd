extends SceneTree

# What ground speed does each clip LOOK like it is walking at?
#
#   Godot --headless --path game --script res://tests/probe_creature_gait.gd
#
# A `probe_*`, not a `check_*`: it asserts nothing and is not in the suite. It exists so that
# `CreatureAnim.CLIP_SPEED` is a MEASUREMENT rather than a taste call, and so the measurement
# can be repeated if the asset is ever re-merged.
#
# HOW. Every clip is in-place, so there is no root translation to read a speed from. But a
# walk cycle still states its own speed: during the STANCE phase the planted foot is still
# relative to the ground, which in an in-place clip means it travels BACKWARD relative to the
# hips at exactly the speed the body would be moving forward. So: sample toe-minus-hips along
# the clip's forward axis, find the longest run of monotone backward travel, and divide the
# distance by its duration.
#
# ⚠️⚠️ IT IS WRONG FOR `unsteady`, AND THE ANCHOR IS WHY THAT IS KNOWN. This estimator finds the
# stance phase as the longest monotone backward run of toe-minus-hips, which needs a clean contact
# phase to mean anything. `unsteady` is a drunken sway: the hips lurch forward past a foot that is
# not actually planted, that stretch reads as a long clean stance, and the estimate came back
# **1.489 m/s against a true ~0.84** — a 77 % overestimate that made the Void's stalker skate
# forward at 27.6 % of its own speed. The figure in `CreatureAnim.CLIP_SPEED` is the corrected one,
# measured the other way round (residual world drift of the planted toe at three different
# `speed_scale`s, solving `feet = world - drift`, which needs no stance detection at all).
# ⚠️ Every other clip's estimate held. Keep this probe for gaits with a real contact phase, and
# cross-check any new drunken or shuffling clip against a drift measurement before believing it.
#
# ⚠️ ANCHORED, NOT ASSUMED. `charge` is the one clip whose true speed is known independently —
# it shipped with 2.279 m of baked root motion over 0.833 s = 2.849 m/s (tools/merge_creature_glb.py
# strips it and prints that figure). If the stance estimate for `charge` does not land near
# 2.849, the method is wrong and every other number it prints is wrong too. That is printed as
# a ratio at the end and is the only thing here worth trusting blindly.
#
# ⚠️ Bone poses come back in SKELETON space, which for this rig is CENTIMETRES under an
# Armature scaled 0.01. Everything is converted through `skel.global_transform` first.

# ⚠️ `-- --model parasite` measures the second model (2026-09-12). Both of its takes carried root
# motion, so BOTH clips have a true speed (`true` below); measured 2026-09-12 the stance estimate
# was 1.526 vs 1.497 on `walk` (2 %) and 3.129 vs 2.829 on the limping `run` (10 % high — the
# drunken-clip failure `unsteady` already taught). CreatureAnim.MODELS ships the true numbers.
const MODELS := {
	"hollow_crown": {
		"glb": "res://assets/models/hollow_crown.glb",
		"clips": ["walk", "shamble", "unsteady", "run", "sprint", "charge"],
		"hips": "Hips", "toes": ["LeftToeBase", "RightToeBase"],
		"anchor_clip": "charge", "anchor_true": 2.849,
	},
	"parasite": {
		"glb": "res://assets/models/parasite.glb",
		"clips": ["walk", "run"],
		"hips": "mixamorig_Hips", "toes": ["mixamorig_LeftToeBase", "mixamorig_RightToeBase"],
		# Both takes shipped with baked root motion; merge_creature_glb.py --profile parasite
		# strips it and prints these ground speeds. The stance estimate is checked against them.
		"anchor_clip": "walk", "anchor_true": 1.497,
		"true": {"walk": 1.497, "run": 2.829},
	},
}
const SAMPLES := 120
const METHOD_K := 2.849 / 2.799   # the calibration the hollow_crown anchor established


func _find(n: Node, cls: String, out: Array) -> void:
	if n.get_class() == cls:
		out.append(n)
	for c in n.get_children():
		_find(c, cls, out)


func _process(_delta: float) -> bool:
	var model := "hollow_crown"
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--model":
			model = args[i + 1]
	var M: Dictionary = MODELS[model]
	var CLIPS: Array = M["clips"]
	var packed: PackedScene = load(M["glb"])
	var inst: Node3D = packed.instantiate()
	root.add_child(inst)
	var skels: Array = []
	var players: Array = []
	_find(inst, "Skeleton3D", skels)
	_find(inst, "AnimationPlayer", players)
	var skel: Skeleton3D = skels[0]
	var ap: AnimationPlayer = players[0]
	var hips := skel.find_bone(M["hips"])
	var toes := [skel.find_bone(M["toes"][0]), skel.find_bone(M["toes"][1])]
	print("== CREATURE GAIT [%s] ==  hips=%d toes=%s" % [model, hips, str(toes)])

	var lib := ""
	for a in ap.get_animation_list():
		if String(a).contains("/"):
			lib = String(a).get_slice("/", 0) + "/"
			break

	print("  clip        dur     stance run      implied m/s")
	var est := {}
	for clip in CLIPS:
		var full: String = lib + clip
		if not ap.has_animation(full):
			continue
		var anim: Animation = ap.get_animation(full)
		ap.play(full)
		var best := 0.0
		for toe in toes:
			if toe < 0:
				continue
			# toe-minus-hips along +Z (the rig's forward, asserted by check_creature_model.gd)
			var rel: Array[float] = []
			for i in range(SAMPLES):
				ap.seek(anim.length * float(i) / float(SAMPLES - 1), true)
				var h: Vector3 = skel.global_transform * skel.get_bone_global_pose(hips).origin
				var t: Vector3 = skel.global_transform * skel.get_bone_global_pose(toe).origin
				rel.append(t.z - h.z)
			# longest monotone-decreasing run = the stance phase
			var run_start := 0
			var i2 := 1
			while i2 < rel.size():
				if rel[i2] < rel[i2 - 1]:
					var j := i2
					while j < rel.size() and rel[j] < rel[j - 1]:
						j += 1
					var dist: float = rel[run_start if false else i2 - 1] - rel[j - 1]
					var dur: float = anim.length * float(j - 1 - (i2 - 1)) / float(SAMPLES - 1)
					if dur > 0.02:
						best = maxf(best, dist / dur)
					i2 = j
				else:
					i2 += 1
		est[clip] = best
		print("  %-10s %6.3fs                  %6.3f" % [clip, anim.length, best])
	ap.stop()

	var anchor_clip: String = M["anchor_clip"]
	if anchor_clip != "":
		var anchor: float = est.get(anchor_clip, 0.0)
		print("\n  ANCHOR: '%s' true speed %.3f m/s (from its stripped root motion)"
			% [anchor_clip, M["anchor_true"]])
		print("          stance estimate %.3f m/s  ->  ratio %.3f"
			% [anchor, anchor / float(M["anchor_true"])])
		if anchor > 0.01:
			var k: float = float(M["anchor_true"]) / anchor
			print("\n  CALIBRATED (estimate x %.4f) — these are the CLIP_SPEED values:" % k)
			for clip in CLIPS:
				if est.has(clip):
					print("    %-10s %6.3f" % [clip, float(est[clip]) * k])
	else:
		print("\n  NO ANCHOR for this model. Applying the method's own"
			+ " calibration k = %.4f from the hollow_crown anchor:" % METHOD_K)
		for clip in CLIPS:
			if est.has(clip):
				print("    %-10s %6.3f" % [clip, float(est[clip]) * METHOD_K])
	if M.has("true"):
		print("\n  TRUE ground speeds (stripped root motion) vs the stance estimate:")
		for clip in CLIPS:
			if est.has(clip) and (M["true"] as Dictionary).has(clip):
				var tr: float = float(M["true"][clip])
				print("    %-10s true %6.3f   estimate %6.3f   ratio %.3f"
					% [clip, tr, float(est[clip]), float(est[clip]) / tr])
	inst.queue_free()
	quit(0)
	return true
