extends SceneTree

# WHICH swing angle does each door actually take, and how much lane is left when it is open?
#
#   Godot --headless --path game --script res://tests/probe_door_swing.gd
#
# A `probe_*`: it prints, it does not assert. `check_slam_door_seals.gd` already proves a CLOSED
# door seals its doorway, and the dungeon-tester proved 0.0 % of leaves hide their artwork across
# 744 leaves on 8 seeds. Neither answers the remaining question, which is about the OPEN state:
# `_pick_clear_swings()` walks a ladder of [85, 78, 72, 66, 60, 40, 22, 10] x ±, and a door that
# settles on 22° has technically "found a clear swing" while standing most of the way across its
# own doorway. That is a legibility number, not a correctness one, so it is reported rather than
# enforced — the constant is `SlamDoor.OPEN_DEG` and moving it is a design call.
#
# ⚠️ IT IS NOT A WALKABILITY NUMBER. The swinging leaves sit on `INTERACTABLE_LAYER` and never
# block movement; the only solid part is `_block_body`, whose collider is disabled unless the
# door is closed. An open door therefore leaves its doorway completely clear at ANY angle —
# `check_slam_door_seals.gd` measures the open Dungeon door at 2.22 m of a 2.20 m opening. What
# the angle decides is whether the leaf's ART stands across its own opening, and whether
# `check_interact_reach.gd`'s ray still finds it (see the ⚠️ at `slam_door.gd:238`). Quote the
# per-angle "lane" figures as leaf geometry, never as a passage the player squeezes through.

const SCENES := {
	"Breach": "res://scenes/level_6_breach.tscn",
	"Dungeon": "res://scenes/dungeon.tscn",
}

var _t := 0.0
var _stage := 0
var _keys: Array = []


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _doors() -> Array:
	var out: Array = []
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		var s = x.get_script()
		if s and String(s.resource_path).ends_with("slam_door.gd"):
			out.append(x)
	return out


func _initialize() -> void:
	_keys = SCENES.keys()
	seed(7)
	change_scene_to_file(SCENES[_keys[0]])


func _process(delta: float) -> bool:
	_t += delta
	if _t < 3.0 or current_scene == null:
		return false
	_t = 0.0
	if _stage >= _keys.size():
		quit(0)
		return true
	var label: String = _keys[_stage]
	var doors := _doors()
	var hist := {}
	var widest := 0.0
	var narrowest := 999.0
	# `_pick_clear_swings()` records its choice as an `open_deg` META on each hinge — that is the
	# same value `set_open()` reads back, so this measures what the door will actually do.
	for d in doors:
		var kids: Array = []
		_all(d, kids)
		for k in kids:
			if k is Node3D and k.has_meta("open_deg"):
				var a := int(round(absf(float(k.get_meta("open_deg")))))
				hist[a] = int(hist.get(a, 0)) + 1
	var w := 0.0
	for d in doors:
		w = float(d.get("door_width"))
		widest = maxf(widest, w)
		narrowest = minf(narrowest, w)
	# ⚠️ NO LANE MEASUREMENT HERE, DELIBERATELY. The obvious probe — open every door, then point-
	# query across the doorway — was written and DELETED: `set_open()` drives a Tween, and the
	# physics space reflects the last physics STEP, so measuring in the frame you open them reads
	# a doorway full of closed doors. It reported 0.00 m on levels that `walk_dungeon.gd` and
	# `autoplay_exit_reachable.gd` both walk end to end, which is the tell. Whether the player
	# fits is already answered by those two plus `check_interact_reach.gd`; what they cannot
	# answer, and this can, is WHICH ANGLE the ladder settles on.
	print("== %s: %d slam doors, width %.2f-%.2f m ==" % [label, doors.size(), narrowest, widest])
	if hist.is_empty():
		print("   (slam_door.gd exposes no per-leaf swing property to read — see the ⚠️ in that")
		print("    file; the ladder is applied inside _build_leaf and not recorded)")
	else:
		var keys := hist.keys()
		keys.sort()
		keys.reverse()
		for a in keys:
			print("   %3d deg : %d leaves" % [a, hist[a]])
		print("   ⚠️ OPEN_DEG is %s; anything well below it is a leaf that could not fully clear."
			% str(load("res://scripts/slam_door.gd").get_script_constant_map().get("OPEN_DEG")))
	_stage += 1
	if _stage < _keys.size():
		change_scene_to_file(SCENES[_keys[_stage]])
	return false
