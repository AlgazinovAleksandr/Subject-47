extends SceneTree

# Do the three creatures actually MOVE, and does each one's gait match what it is doing?
#
#   Godot --headless --path game --script res://tests/check_creature_anim.gd
#
# `check_creature_model.gd` asserts the ASSET. This asserts the WIRING — that each creature
# script resolves the model rather than silently falling back to a capsule, that the state
# machine drives the clip, and that the retint kept the model's skin.
#
# ⚠️ THE ONE ASSERTION NOTHING ELSE IN THE PROJECT CAN MAKE: `creature_stalker.gd` is a Weeping
# Angel — it advances only while it is NOT being looked at — and until 2026-09-03 that rule was
# literally invisible, because the model was a rigid T-pose that looked identical watched and
# unwatched. Now that it walks, a creature whose legs kept cycling while you stared at it would
# contradict the only rule the Void teaches. `speed_scale == 0.0 while observed` is that rule,
# expressed as something a machine can check.

# ⚠️ `load()` INSIDE _initialize, NEVER `preload`. A preload compiles the creature scripts at
# THIS script's parse time, which is before the autoloads register — and both of them reference
# `Screamer`, so it fails with "Identifier not found: Screamer", `.new()` returns null, and the
# test loops forever calling methods on nothing. `test_creature_object12.gd:63` carries the same
# note; this file rediscovered the trap the hard way.
var STALKER: GDScript
var OBJ12: GDScript

var _fails: Array[String] = []
var _checks := 0
var _stage := 0
var _t := 0.0
var _wall := 0.0
var _stalker: Node3D
var _obj: Node3D
var _player: CharacterBody3D
var _cam: Camera3D
var _dormant_pose := PackedFloat32Array()


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _anim_of(n: Node) -> AnimationPlayer:
	var a = n.get("_anim")
	if a == null:
		return null
	return a.call("visual_root").find_child("AnimationPlayer", true, false) as AnimationPlayer


func _clip_of(n: Node) -> String:
	var a = n.get("_anim")
	return "" if a == null else String(a.call("current_clip"))


func _speed_of(n: Node) -> float:
	var ap := _anim_of(n)
	return -1.0 if ap == null else ap.speed_scale


# ⚠️ ASSERT THE SKELETON, NOT THE CLIP NAME. The sway this file used to bless was asserted by
# its LABEL — `_clip_of(_obj) == "shamble"` — which says what was asked for and nothing about
# what the bones then did. These two read the actual pose.
func _skel(n: Node) -> Skeleton3D:
	var a = n.get("_anim")
	return null if a == null else a.call("skeleton") as Skeleton3D


# Every bone's global pose, flattened. Two identical signatures mean nothing moved AT ALL.
func _pose_signature(n: Node) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var sk := _skel(n)
	if sk == null:
		return out
	for i in range(sk.get_bone_count()):
		var t: Transform3D = sk.get_bone_global_pose(i)
		out.append(t.origin.x); out.append(t.origin.y); out.append(t.origin.z)
		var q := t.basis.get_rotation_quaternion()
		out.append(q.x); out.append(q.y); out.append(q.z); out.append(q.w)
	return out


func _pose_drift(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	if a.size() != b.size() or a.is_empty():
		return -1.0
	var worst := 0.0
	for i in range(a.size()):
		worst = maxf(worst, absf(a[i] - b[i]))
	return worst


# How far the skeleton is from its REST pose. ~0 means bind pose — a T-posed statue, which is
# what `halt()` would leave on screen and is the failure mode a held pose must not become.
func _rest_distance(n: Node) -> float:
	var sk := _skel(n)
	if sk == null:
		return -1.0
	var worst := 0.0
	for i in range(sk.get_bone_count()):
		var rest_q := sk.get_bone_rest(i).basis.get_rotation_quaternion()
		var pose_q := sk.get_bone_pose_rotation(i)
		worst = maxf(worst, absf(rest_q.angle_to(pose_q)))
	return worst


func _mats(n: Node) -> Array:
	var a = n.get("_anim")
	if a == null:
		return []
	var out: Array = []
	for mi in a.call("mesh_instances"):
		if mi.material_override:
			out.append(mi.material_override)
	return out


func _initialize() -> void:
	STALKER = load("res://scripts/creature_stalker.gd")
	OBJ12 = load("res://scripts/creature_object12.gd")
	var world := Node3D.new()
	world.name = "World"
	root.add_child(world)

	# A stub player: the creature scripts find it by the "player" group, and the stalker also
	# needs a Camera3D child to decide whether it is being observed.
	_player = CharacterBody3D.new()
	_player.name = "Player"
	_player.add_to_group("player")
	world.add_child(_player)
	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	_player.add_child(_cam)
	_player.global_position = Vector3(0, 0, 0)

	_stalker = STALKER.new()
	_stalker.position = Vector3(0, 0, 4)
	world.add_child(_stalker)

	_obj = OBJ12.new()
	_obj.position = Vector3(20, 0, 20)
	world.add_child(_obj)


func _process(delta: float) -> bool:
	# ⚠️ THE TIMEOUT IS FIRST, NOT LAST. A GDScript runtime error aborts the rest of _process,
	# so a timeout check at the bottom never runs once anything throws — and the test hangs
	# until the harness kills it with no output. That is ISSUES_SOLUTIONS Issue 45, and this
	# file hit it on its first run.
	_wall += delta
	if _wall > 30.0:
		print("TIMEOUT at stage %d after %.1fs" % [_stage, _wall])
		quit(1)
		return true
	_t += delta
	if _t < 0.2:
		return false

	match _stage:
		0:
			print("== CREATURE ANIM ==")
			# ------------------------------------------------ the model actually resolved
			for pair in [["stalker", _stalker], ["object12", _obj]]:
				var n: Node = pair[1]
				_ok("%s built the animated model (not the capsule fallback)" % pair[0],
					n.get("_anim") != null,
					"a null _anim means ResourceLoader could not see the GLB — run --import")
				_ok("%s has exactly one AnimationPlayer" % pair[0], _anim_of(n) != null)
				var mats := _mats(n)
				_ok("%s retinted every mesh" % pair[0], mats.size() >= 1,
					"%d materials" % mats.size())
				for m in mats:
					# ⚠️ The regression this whole swap exists to prevent: the old retint built
					# a fresh StandardMaterial3D and threw the model's texture away.
					_ok("%s KEPT the model's skin" % pair[0],
						(m as StandardMaterial3D).albedo_texture != null)
					_ok("%s is not metal" % pair[0], (m as StandardMaterial3D).metallic <= 0.01)
					_ok("%s cannot self-light out of the dark" % pair[0],
						(m as StandardMaterial3D).emission_energy_multiplier <= 0.25,
						"energy %.3f" % (m as StandardMaterial3D).emission_energy_multiplier)
			_stage = 1
			_t = 0.0
		1:
			# ------------------------------------------------ ⭐ DORMANT OBJECT 12 STANDS STILL
			#
			# ⚠️ THIS BLOCK USED TO ASSERT THE OPPOSITE, and it is the reason the defect shipped:
			# it read `clip == "shamble"` and `speed_scale < 0.8` and called that "the standing
			# sway". Both were true of a creature swinging its hips 0.515 m and its arms 57.9 deg
			# in front of a player 16 m away — the label matched, the behaviour did not, and the
			# player filed it as a bug. An assertion about a clip NAME cannot see what the bones
			# do; the three below read the skeleton.
			_ok("dormant Object 12 holds a pose from the WALK cycle",
				_clip_of(_obj) == "walk", "clip '%s'" % _clip_of(_obj))
			_ok("...and it is HELD, not played slowly",
				_speed_of(_obj) == 0.0, "speed_scale %.2f" % _speed_of(_obj))
			# ⭐ CONTROL, and not a formality: `halt()` would satisfy both assertions above and
			# leave a T-POSED STATUE on screen. Nothing else in the project can tell them apart.
			var rest_d := _rest_distance(_obj)
			_ok("...and it is NOT the bind pose (a T-posed statue would pass everything above)",
				rest_d > 0.15, "worst bone %.3f rad from rest" % rest_d)
			_dormant_pose = _pose_signature(_obj)
			_ok("CONTROL — the skeleton was actually sampled", _dormant_pose.size() > 0,
				"%d floats over %d bones"
					% [_dormant_pose.size(), _dormant_pose.size() / 7])
			_stage = 11
			_t = 0.0
		11:
			# Two seconds of dormancy. `shamble` at 0.5x cycles in 11 s, so a sway would have
			# moved a long way by now; a held pose must not have moved at all.
			if _t < 2.0:
				return false
			var drift := _pose_drift(_dormant_pose, _pose_signature(_obj))
			_ok("after 2 s of dormancy the skeleton has not moved by so much as a millimetre",
				drift >= 0.0 and drift < 0.0005,
				"worst per-component drift %.6f" % drift)

			# ------------------------------------------------ each state picks its gait
			_obj.call("activate")
			_ok("PATROL walks", _clip_of(_obj) == "walk", "clip '%s'" % _clip_of(_obj))
			_ok("...at a believable rate",
				_speed_of(_obj) > 0.6 and _speed_of(_obj) < 1.8,
				"speed_scale %.2f for patrol_speed %.1f m/s"
					% [_speed_of(_obj), float(_obj.get("patrol_speed"))])
			_dormant_pose = _pose_signature(_obj)
			_stage = 12
			_t = 0.0
		12:
			# ⚠️ THE OTHER HALF, and the one that makes the stillness assertion mean something:
			# a creature that never moves also "has not moved after 2 s". Waking it must start
			# the bones going, out of the pose it was standing in — `CreatureAnim.play()`'s
			# same-clip branch retunes the speed without restarting, so there is no pop.
			if _t < 1.0:
				return false
			var woke := _pose_drift(_dormant_pose, _pose_signature(_obj))
			_ok("...and one second after activate() it IS moving",
				woke > 0.005, "worst per-component drift %.6f since waking" % woke)

			_obj.call("_enter", 2)   # State.CHASE
			_ok("CHASE at 5.0 m/s uses the RUN cycle",
				_clip_of(_obj) == "run", "clip '%s'" % _clip_of(_obj))
			_ok("...without looking retimed",
				_speed_of(_obj) > 0.6 and _speed_of(_obj) < 1.8,
				"speed_scale %.2f" % _speed_of(_obj))

			# ⚠️ The Matron is THIS script at chase_speed 3.4. One clip cannot serve both: on
			# `run` she lands at the 0.62 clamp floor and reads as slow motion. The split is
			# what makes the shared script legitimate rather than a compromise.
			_obj.set("chase_speed", 3.4)
			_obj.call("_enter", 0)
			_obj.call("_enter", 2)
			_ok("the Matron's 3.4 m/s CHASE picks a slower cycle instead",
				_clip_of(_obj) == "charge", "clip '%s'" % _clip_of(_obj))
			_ok("...and lands near 1.0 rather than at the clamp",
				_speed_of(_obj) > 0.9 and _speed_of(_obj) < 1.5,
				"speed_scale %.2f" % _speed_of(_obj))
			_obj.set("chase_speed", 5.0)

			_obj.call("_enter", 4)   # State.STAGGERED
			_ok("STAGGERED reels", _clip_of(_obj) == "unsteady", "clip '%s'" % _clip_of(_obj))

			_obj.call("_enter", 3)   # State.SEARCH
			_ok("SEARCH walks to the last-known position first",
				_clip_of(_obj) == "walk", "clip '%s'" % _clip_of(_obj))
			_obj.set("_search_arrived", true)
			_obj.call("_refresh_clip")
			_ok("...then scans in place on a different gait",
				_clip_of(_obj) == "unsteady", "clip '%s'" % _clip_of(_obj))

			# ------------------------------------------------ the purge corpse stops
			_obj.call("lure_into_trap")
			var ap := _anim_of(_obj)
			_ok("a purged creature STOPS (a corpse does not walk on its face)",
				ap != null and not ap.is_playing())
			_ok("...and is face down", absf(float(_obj.get("_visual_root").rotation.x)
				- deg_to_rad(-90.0)) < 0.01)
			_stage = 2
			_t = 0.0
		2:
			# ------------------------------------------------ ⭐ the Weeping-Angel rule
			# Look straight at it, from 4 m — inside ENGAGE_DIST 8.0, dead centre of the FOV.
			_cam.look_at(Vector3(0, 0.9, 4), Vector3.UP)
			_stage = 3
			_t = 0.0
		3:
			var watched_speed := _speed_of(_stalker)
			_ok("WATCHED: the stalker freezes mid-stride", watched_speed == 0.0,
				("speed_scale %.2f — legs that keep cycling while you stare contradict the "
				+ "one rule the Void teaches") % watched_speed)
			_ok("...and it is frozen, not stopped (the pose is held)",
				_anim_of(_stalker) != null and _anim_of(_stalker).is_playing(),
				"a stopped player would snap to bind pose")
			# Now look away: 180 degrees, same position.
			_cam.look_at(Vector3(0, 0.9, -4), Vector3.UP)
			_stage = 4
			_t = 0.0
		4:
			if _t < 0.5:
				return false
			var free_speed := _speed_of(_stalker)
			_ok("UNWATCHED: it moves again", free_speed > 0.0,
				"speed_scale %.2f" % free_speed)
			# ⚠️ A CONTROL. If `_speed_of` returned a constant, or the stalker never ran its
			# _process at all, stage 3 would have passed for the wrong reason. Requiring the
			# two readings to DIFFER is what makes the pair mean something.
			_ok("CONTROL: watched and unwatched read differently",
				free_speed != 0.0,
				"if these are ever equal, the freeze assertion above is vacuous")
			print("== %d checks, %d failed ==" % [_checks, _fails.size()])
			for f in _fails:
				print("   FAILED: " + f)
			quit(1 if _fails.size() > 0 else 0)
			return true
		_:
			pass
	return false
