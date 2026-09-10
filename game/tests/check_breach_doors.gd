extends SceneTree

# EVERY DOOR IN THE BREACH LOOKS LIKE THE SAME KIND OF DOOR.
#
#   Godot --headless --path game --script res://tests/check_breach_doors.gd
#
# ⚠️⚠️ THE GAP THIS FILLS: `check_art_aspect.gd` returns early on a mesh that is not a
# `QuadMesh`/`PlaneMesh`, and again on a null `albedo_texture`. **So a prop with no artwork at all
# is invisible to the only guard in the project that exists for artwork.** The PurgeChamber — the
# biggest door in the level and its one permanent win condition — was a flat-tinted `BoxMesh` at
# `Color(0.14, 0.14, 0.15)` for its whole life, standing beside two exit doors and eight slam-door
# leaves that all carry `breach_door.png`, and every guard reported green. The player found it by
# looking at it: *"make sure all the doors look the same."*
#
# Guards that see a MISSING thing have to enumerate what should be there, which is what this does.
#
# ⚠️ THE EMISSION RULE, and why it is not "all identical". Godot's default operator is ADD, which
# lays a flat colour wash over the whole leaf; `slam_door.gd` uses MULTIPLY, which tints the
# texture's own shape. Same PNG, two different pictures. All seven doors now use MULTIPLY at
# energy 0.08 — but the RED tint stays exclusive to the exit and back doors, because red-means-exit
# is a convention across all nine levels (`CLAUDE.md`, Door Conventions) and this is the one level
# you are being chased toward one in. "Identical" would delete the signal; "one material, red for
# exits" keeps it.

const SCENE := "res://scenes/level_6_breach.tscn"
const SETTLE := 3.0
const RED := Color(0.6, 0.09, 0.09)

var _fails := 0
var _checks := 0
var _t := 0.0
var _level: Node = null


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _initialize() -> void:
	seed(7)
	change_scene_to_file(SCENE)


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


# Every textured art surface under `root`, as its material.
func _art_materials(root: Node) -> Array:
	var out: Array = []
	var nodes: Array = []
	_all(root, nodes)
	for x in nodes:
		if not (x is MeshInstance3D):
			continue
		var mi := x as MeshInstance3D
		if not (mi.mesh is QuadMesh):
			continue
		var m := mi.get_surface_override_material(0) as StandardMaterial3D
		if m != null and m.albedo_texture != null:
			out.append(m)
	return out


func _process(delta: float) -> bool:
	_t += delta
	if _t < SETTLE or current_scene == null:
		return false
	_level = current_scene

	var nodes: Array = []
	_all(_level, nodes)
	var doors := {"exit": [], "slam": [], "purge": []}
	for x in nodes:
		var sc = x.get_script()
		if sc == null:
			continue
		var path := String(sc.resource_path)
		if path.ends_with("slam_door.gd"):
			doors["slam"].append(x)
		elif path.ends_with("purge_chamber.gd"):
			doors["purge"].append(x)
		elif path.ends_with("door.gd"):
			doors["exit"].append(x)

	print("== BREACH DOORS ==  %d exit/back, %d slam, %d purge"
		% [doors["exit"].size(), doors["slam"].size(), doors["purge"].size()])
	# 6 slam doors since the 2026-09-09 maze rework (was 4 — the map is bigger with more chokepoints).
	_ok("the level has its 2 exit/back doors, 6 slam doors and 1 purge chamber",
		doors["exit"].size() == 2 and doors["slam"].size() == 6 and doors["purge"].size() == 1)

	# ---- every door carries artwork ------------------------------------------------------
	var total := 0
	for kind in ["exit", "slam", "purge"]:
		for d in doors[kind]:
			var mats := _art_materials(d)
			total += mats.size()
			_ok("%s door %s carries artwork on a QuadMesh" % [kind, String((d as Node).name)],
				mats.size() >= 1,
				"%d textured quads — an untextured door is invisible to check_art_aspect.gd"
					% mats.size())
			for m in mats:
				var sm := m as StandardMaterial3D
				_ok("...%s: emission is MULTIPLY, not Godot's default ADD"
						% String((d as Node).name),
					sm.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY,
					"operator %d" % sm.emission_operator)
				# The red is the EXIT signal and must not spread to the others.
				var is_red: bool = sm.emission.r > 0.4 and sm.emission.g < 0.2
				_ok("...%s: the red exit tint is %s" % [String((d as Node).name),
						"present" if kind == "exit" else "absent"],
					is_red == (kind == "exit"),
					"emission %s" % str(sm.emission))
	# ⭐ CONTROL. Every assertion above is per-material, so all of them are vacuously true if the
	# sweep collected nothing. The Breach has 2 single-leaf doors (1 quad each), 6 slam doors
	# (4 quads each) and the purge chamber (2) = 28 since the 2026-09-09 maze rework.
	_ok("CONTROL — the sweep actually found the door art", total >= 18,
		"%d textured door quads" % total)

	# ---- and every opening is framed ------------------------------------------------------
	var casings := 0
	for x in nodes:
		if x is Node3D and String(x.name).begins_with("Casing_"):
			casings += 1
	var doors_table: Array = _level.get_script().get_script_constant_map().get("DOORS", [])
	var want: int = doors_table.size() - doors["slam"].size() - doors["purge"].size()
	_ok("every bare opening has an architrave", casings == want,
		"%d casings for %d unframed openings — RoomBuilder cuts these as raw holes"
			% [casings, want])
	# ⚠️ AND NOTHING THE FRAMES ADDED IS SOLID. A collider on the only doorway wall is how this
	# project seals a room by accident; `check_doorways.gd` is the level-wide guard, this is the
	# local one that names the cause.
	var solid := 0
	for x in nodes:
		if not (x is Node3D) or not String(x.name).begins_with("Casing_"):
			continue
		var kids: Array = []
		_all(x, kids)
		for k in kids:
			if k is CollisionShape3D or k is PhysicsBody3D:
				solid += 1
	_ok("...and none of them is solid", solid == 0,
		"%d collider(s)/body(s) under the new casings" % solid)

	print("== %d checks, %d failed ==" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return true
