extends StaticBody3D
class_name HouseBladeStump

# THE GUILLOTINE'S BLADE, DRIVEN INTO A STUMP IN THE FOREST (2026-09-24 c — playtest capture #3,
# the user: *"currently it makes no sense to walk there … you need to search for something
# there"*). The porch guillotine stands without its blade (`house_guillotine.gd`); this is where
# it went. A fixed clearing (`HouseOutdoors.BLADE_CLEARING`) — ⭐⭐ since 2026-09-24 (d) in the far
# north-west corner of the forest, d = 25.5 m, behind one thick trunk (`HouseOutdoors.HIDE_TRUNK`).
#
# ⚠️ NO HINT, the user's call: no path, no sound beacon, no glint, NO EMISSION anywhere on it. It
# is lit by the moon (render layer 2, `HouseOutdoors.moonlit()`) and by the torch, like every
# other thing out there. Finding it is the forest's whole job.
#
# E pulls it free (`blade_pull`, played AT the stump) and `pulled` fires; the LEVEL carries it
# (`level_2.gd:_refresh_carried()` -> "guillotine blade"). Carrying costs nothing.
#
# ⚠️ Two bodies, deliberately:
#   * THIS body is the INTERACT volume — layer 2 / mask 0 (note.gd's convention: the E ray finds
#     it, nobody walks into it). It ENCLOSES the whole stump and the blade, so the ray meets it
#     before it can meet the solid stump — pointing anywhere at the stump gives the prompt.
#     (`player.gd:_update_interact_prompt()` does not walk up from what it hits, so a volume
#     that only wrapped the blade would leave the bark silent.) Disabled once the blade is out.
#   * `StumpBody` is the SOLID stump — layer 1, a cylinder you walk round.
#
# Built from PARTS (Issue 35): a bark cylinder (`forest_bark.png`, flared at the foot), a paler
# cut top, a dark split where the blade went in, and four roots running out into the leaf
# litter. The blade is `HouseGuillotine.build_blade()` — the very weight and edge the frame is
# missing — leaning into the cut at an angle, as if swung down into it.

signal pulled

const LAYER := 2
const TEX := "res://assets/textures/level_2_house/"
const STUMP_R := 0.40            # at the cut
const STUMP_R_FOOT := 0.46
const STUMP_H := 0.55
# The blade assembly's origin (the weight's underside) is lifted so its LOWEST point is
# BLADE_BURY under the cut face (before the lean). ⭐ 2026-09-24 (d): derived from
# `HouseGuillotine.blade_low_y()`, because the generated art is shorter than the old box edge — the
# old constant lift 0.13 would have left the art's low corner sitting ON the wood, not in it.
# ⭐ 2026-09-24 (d, verification render `23_stump_close`): 0.08 / 24° read as a PLATE LYING ON the
# cut, not a blade driven INTO it: the generated art is only ~0.28 m tall, so a 24° lean with 8 cm
# buried leaves a low, tilted sliver seen mostly from above. Near-upright and deeper reads as an axe
# in a chopping block.
const BLADE_BURY := 0.12
const BLADE_LEAN_DEG := 8.0      # about the blade's own long axis — struck at a slight angle
const BLADE_YAW_DEG := 35.0      # across the cut, not square to anything
const BLADE_ROLL_DEG := -7.0
const PULL_DB := 0.0            # the stand-in measures loudest-300 ms −12.3 dBFS

var _taken := false
var _blade: Node3D = null
var _interact_col: CollisionShape3D = null


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	_build()


func has_blade() -> bool:
	return not _taken


func blade_node() -> Node3D:
	return _blade


func can_interact() -> bool:
	return not _taken


func prompt_text() -> String:
	return "E — Pull the blade free."


func interact() -> void:
	if _taken:
		return
	_empty()
	_play_pull()
	ScreenText.toast(get_tree(), "Guillotine blade", Color(0.4, 1.0, 0.4), 2.0)
	pulled.emit()


# The restore path: the blade is already out (held or mounted). No sound, no toast, no signal.
func restore_taken() -> void:
	_empty()


func _empty() -> void:
	_taken = true
	if is_instance_valid(_blade):
		_blade.visible = false
	if _interact_col:
		_interact_col.set_deferred("disabled", true)


func _play_pull() -> void:
	var s := GameState.load_audio("blade_pull")
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.name = "BladePull"
	p.stream = s
	p.volume_db = PULL_DB
	p.max_db = PULL_DB + 4.0
	p.unit_size = 5.0
	p.position = Vector3(0, STUMP_H + 0.1, 0)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# ------------------------------------------------------------------ the build

func _build() -> void:
	# The blade FIRST: `check_reachable.gd` aims at a prop's first mesh, and the blade is the
	# thing a player aims at.
	_blade = HouseGuillotine.build_blade()
	_blade.position = Vector3(0, STUMP_H - HouseGuillotine.blade_low_y() - BLADE_BURY, 0)
	_blade.rotation = Vector3(deg_to_rad(BLADE_LEAN_DEG), deg_to_rad(BLADE_YAW_DEG), deg_to_rad(BLADE_ROLL_DEG))
	add_child(_blade)

	var bark := RoomBuilder.make_material(TEX + "forest_bark.png", Vector3(2.0, 0.25, 1.0),
		Color(0.16, 0.13, 0.10))
	if bark.albedo_texture:
		bark.albedo_color = Color(0.85, 0.82, 0.8)
	bark.uv1_triplanar = false          # the cylinder's own UVs wrap the bark (the trunks' rule)
	var cut := StandardMaterial3D.new()
	cut.albedo_color = Color(0.40, 0.31, 0.21)    # pale heartwood — paler than the bark
	cut.roughness = 1.0
	var split := StandardMaterial3D.new()
	split.albedo_color = Color(0.05, 0.035, 0.025)
	split.roughness = 1.0

	var body := MeshInstance3D.new()
	body.name = "StumpBark"
	var cm := CylinderMesh.new()
	cm.top_radius = STUMP_R
	cm.bottom_radius = STUMP_R_FOOT
	cm.height = STUMP_H
	cm.radial_segments = 14
	cm.rings = 1
	body.mesh = cm
	body.set_surface_override_material(0, bark)
	body.position = Vector3(0, STUMP_H / 2.0, 0)
	add_child(body)

	# The cut top: a disc a little inside the bark's rim and 8 mm proud of its cap — never
	# coplanar with it.
	var top := MeshInstance3D.new()
	top.name = "StumpCut"
	var tm := CylinderMesh.new()
	tm.top_radius = STUMP_R - 0.03
	tm.bottom_radius = STUMP_R - 0.03
	tm.height = 0.012
	tm.radial_segments = 14
	tm.rings = 1
	top.mesh = tm
	top.set_surface_override_material(0, cut)
	top.position = Vector3(0, STUMP_H + 0.002, 0)
	add_child(top)

	# The split the blade is in: a dark slot across the cut along the blade's yaw, 3 mm above
	# the cut face. Visible for what it is once the blade has been pulled.
	var slot := MeshInstance3D.new()
	slot.name = "StumpSplit"
	var sb := BoxMesh.new()
	sb.size = Vector3(0.52, 0.004, 0.035)
	slot.mesh = sb
	slot.set_surface_override_material(0, split)
	slot.position = Vector3(0, STUMP_H + 0.011, 0)
	slot.rotation.y = deg_to_rad(BLADE_YAW_DEG)
	add_child(slot)

	# Four roots, thick at the stump and running out and down into the litter.
	for i in range(4):
		var yaw := deg_to_rad(20.0 + 90.0 * i + (13.0 if i % 2 == 0 else -9.0))
		var d := Vector3(sin(yaw), 0.0, cos(yaw))
		var root := MeshInstance3D.new()
		root.name = "StumpRoot"
		var rcm := CylinderMesh.new()
		rcm.top_radius = 0.025               # the thin end, out in the litter
		rcm.bottom_radius = 0.11
		rcm.height = 0.72
		rcm.radial_segments = 8
		rcm.rings = 1
		root.mesh = rcm
		root.set_surface_override_material(0, bark)
		# Its axis (+Y, thin end) points out and down; its middle sits just outside the foot.
		var axis := (d * 0.62 - Vector3.UP * 0.30).normalized()
		var side := d.cross(Vector3.UP).normalized()
		var fwd := side.cross(axis).normalized()
		root.basis = Basis(side, axis, fwd)
		root.position = d * (STUMP_R_FOOT + 0.14) + Vector3(0, 0.07, 0)
		add_child(root)

	# The solid stump, layer 1: a cylinder you walk round.
	var solid := StaticBody3D.new()
	solid.name = "StumpBody"
	solid.collision_layer = 1
	solid.collision_mask = 0
	var scs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = STUMP_R_FOOT
	cyl.height = STUMP_H
	scs.shape = cyl
	scs.position = Vector3(0, STUMP_H / 2.0, 0)
	solid.add_child(scs)
	add_child(solid)

	# The interact volume (this body, layer 2): the stump and the blade inside one box.
	_interact_col = CollisionShape3D.new()
	_interact_col.name = "InteractVolume"
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, STUMP_H + 0.42, 1.0)
	_interact_col.shape = box
	_interact_col.position = Vector3(0, box.size.y / 2.0, 0)
	add_child(_interact_col)
