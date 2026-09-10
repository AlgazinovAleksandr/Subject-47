extends SceneTree

# WHAT DOES A DORMANT OBJECT 12 LOOK LIKE — and which held frame should it be?
#
#   ⚠️ RUN WITHOUT --headless. It needs a render target.
#   /Applications/Godot.app/Contents/MacOS/Godot --path game \
#       --script res://tests/screenshot_dormant_creature.gd
#
# Writes to /tmp/dormant_shots/.
#
# ⚠️ THIS EXISTS TO CHOOSE A CONSTANT, NOT TO ASSERT ONE. `creature_object12.gd:DORMANT_POSE_AT`
# is a seek offset into the `walk` cycle, and the only honest way to pick it is to look: frame 0
# of a walk is a full stride with one leg thrown forward, which reads as a creature caught
# mid-step rather than one standing. Somewhere near the passing phase the legs come together.
# `check_creature_anim.gd` asserts that the pose is HELD and is not the bind pose; which frame it
# is remains a judgement, and this is where the judgement is made.
#
# ⚠️ THE FRAMING IS THE PLAYER'S OWN, and that is the whole point. The creature stands at (0,0,14)
# and the player spawns at (0, 0.1, -2) facing +Z — 16.0 m, heading 0.0 deg, straight down the
# spine. A pose chosen in a close-up is a pose chosen at a distance nobody ever sees it from, so
# the sweep shoots the spawn view first and only then walks in for the detail.
#
# ⚠️ IT MOVES THE PLAYER, NEVER THE CREATURE. `level_6_breach.gd:270-275` warns that the world
# transform lives on the inner `StaticBody3D`, so setting the outer node's `position` moves
# nothing — `screenshot_level6.gd` does exactly that and has been photographing the creature at
# z=14 while believing it moved it.

const OUT := "/tmp/dormant_shots/"
const SCENE := "res://scenes/level_6_breach.tscn"
const SETTLE := 3.0
# The candidates. `walk` runs 1.033 s at Godot's 30 fps resample, so these are 0 %, 12 %, 25 %,
# 37 %, 50 % and 75 % through the cycle, plus the two calmer clips for comparison.
const POSES := [
	["walk", 0.00], ["walk", 0.13], ["walk", 0.26], ["walk", 0.39],
	["walk", 0.52], ["walk", 0.78],
	["unsteady", 0.40], ["unsteady", 1.50], ["shamble", 2.70],
]
# Where the camera stands for each pass.
const VIEWS := [
	["spawn", Vector3(0, 0.1, -2.0)],     # the player's own first frame, 16 m out
	["near", Vector3(0, 0.1, 10.0)],      # 4 m, to actually see the silhouette
]

var _t := 0.0
var _armed := false
var _i := 0
var _v := 0
var _level: Node = null
var _creature: Node = null
var _player: CharacterBody3D = null


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	seed(7)
	change_scene_to_file(SCENE)


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _find_creature() -> Node:
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		var s = x.get_script()
		if s and String(s.resource_path).ends_with("creature_object12.gd"):
			return x
	return null


func _process(delta: float) -> bool:
	_t += delta
	if _t < SETTLE or current_scene == null:
		return false
	if _level == null:
		_level = current_scene
		_creature = _find_creature()
		_player = _level.get_node_or_null("Player") as CharacterBody3D
		if _creature == null or _player == null:
			print("could not find creature/player")
			quit(1)
			return true
		var cp: Vector3 = _creature.call("get_creature_position")
		print("creature at %s, player spawn %s -> %.2f m"
			% [str(cp), str(_player.global_position), cp.distance_to(_player.global_position)])

	if _v >= VIEWS.size():
		print("\nwrote %d shots to %s" % [POSES.size() * VIEWS.size(), OUT])
		quit(0)
		return true

	# ⚠️ SET THE STATE THIS FRAME, CAPTURE ON THE NEXT. The frame has already been submitted by
	# the time `_process` runs, so a same-frame capture photographs the PREVIOUS pose —
	# `screenshot_dark_levels.gd` carries the same warning after producing "torch off" images
	# with the torch plainly on in them.
	if not _armed:
		var view: Array = VIEWS[_v]
		_player.global_position = view[1]
		_player.rotation.y = PI       # player forward is -Z, so PI faces +Z, down the spine
		_player.force_update_transform()
		var pose: Array = POSES[_i]
		var anim = _creature.get("_anim")
		if anim != null:
			anim.call("hold_pose", pose[0], pose[1])
		_armed = true
		return false

	var view2: Array = VIEWS[_v]
	var pose2: Array = POSES[_i]
	var img := get_root().get_texture().get_image()
	var name := "%s_%s_%03d.png" % [view2[0], pose2[0], int(float(pose2[1]) * 100.0)]
	img.save_png(OUT + name)
	print("  %s" % name)
	_armed = false
	_i += 1
	if _i >= POSES.size():
		_i = 0
		_v += 1
	return false
