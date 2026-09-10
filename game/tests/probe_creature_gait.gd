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

const GLB := "res://assets/models/hollow_crown.glb"
const CLIPS := ["walk", "shamble", "unsteady", "run", "sprint", "charge"]
const SAMPLES := 120
const CHARGE_TRUE := 2.849


func _find(n: Node, cls: String, out: Array) -> void:
	if n.get_class() == cls:
		out.append(n)
	for c in n.get_children():
		_find(c, cls, out)


func _process(_delta: float) -> bool:
	var packed: PackedScene = load(GLB)
	var inst: Node3D = packed.instantiate()
	root.add_child(inst)
	var skels: Array = []
	var players: Array = []
	_find(inst, "Skeleton3D", skels)
	_find(inst, "AnimationPlayer", players)
	var skel: Skeleton3D = skels[0]
	var ap: AnimationPlayer = players[0]
	var hips := skel.find_bone("Hips")
	var toes := [skel.find_bone("LeftToeBase"), skel.find_bone("RightToeBase")]

	var lib := ""
	for a in ap.get_animation_list():
		if String(a).contains("/"):
			lib = String(a).get_slice("/", 0) + "/"
			break

	print("== CREATURE GAIT ==")
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

	var anchor: float = est.get("charge", 0.0)
	print("\n  ANCHOR: 'charge' true speed 2.849 m/s (from its stripped root motion)")
	print("          stance estimate %.3f m/s  ->  ratio %.3f" % [anchor, anchor / CHARGE_TRUE])
	if anchor > 0.01:
		var k: float = CHARGE_TRUE / anchor
		print("\n  CALIBRATED (estimate x %.4f) — these are the CLIP_SPEED values:" % k)
		for clip in CLIPS:
			if est.has(clip):
				print("    %-10s %6.3f" % [clip, float(est[clip]) * k])
	inst.queue_free()
	quit(0)
	return true
