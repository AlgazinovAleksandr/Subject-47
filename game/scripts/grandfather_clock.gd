extends Node
class_name GrandfatherClock

# The Corridor's grandfather clock at d = 48 m — a CASE, not a picture of one (2026-09-10, the
# user's replay: *"Shall we make that clock 3d?"*).
#
# It was a 2 x 3 m flat wall panel carrying `clock.png` — a photograph of a clock on wallpaper,
# hung as a picture of a wall on a wall (Issue 35's exact shape). It is now built from parts:
# plinth, a trunk with a glazed door and a PENDULUM SWINGING behind the glass, a hood carrying a
# drawn dial behind a brass bezel, a pediment with two finials. Dark walnut veneer via a triplanar
# material; brass flat-tinted; the dial on a `QuadMesh` sized to its own square art (Issue 24 —
# never on a BoxMesh face).
#
# ⚠️⚠️ DELIBERATE — `scare_intensity` STAYS 1.0 (20 panic/s while looked at). The 2026-09-10
# playtest died to this exact object 14 s into the level: the chime at d 46 spiked +10 and 1.5 s
# of looking at the clock added the rest. The user was shown that arithmetic and the two softer
# options (0.5, or cursed only after the chime) and chose to keep it. A clock worth looking at
# is one people look at; that is the point. Do not re-tune it without asking.
#
# The chain is the project's gaze convention, unchanged: `ScaryObject (this node, no transform)
# -> StaticBody3D (carries the world transform) -> parts + one collider`. `player.gd:
# _find_scary_object()` walks UP from the collider it hit, so the ScaryObject must be an
# ANCESTOR of the body, never a child of it.
#
# Local axes of the body: +z is the FRONT (the same convention as the corridor's panels, whose
# QuadMesh normals face the room), so the caller yaws it with `atan2(inward.x, inward.z)`.
# The floor is local y = 0.

const DEPTH := 0.38
const WIDTH := 0.64
const HEIGHT := 2.16
const PLINTH := Vector3(0.64, 0.14, 0.38)
const TRUNK_W := 0.50
const TRUNK_H := 1.30
const TRUNK_D := 0.30
const HOOD := Vector3(0.60, 0.56, 0.34)
const PEDIMENT := Vector3(0.66, 0.10, 0.38)
const DIAL := 0.36
const GLASS := Vector2(0.40, 1.08)
const PENDULUM_ROD := 0.86
const BOB_R := 0.075
# The swing: ±6 deg, 1.0 s each way — a 2.0 s period, one tick per half-swing.
const SWING_DEG := 6.0
const SWING_HALF_PERIOD := 1.0
const TICK_DB := -14.0
const TICK_UNIT := 4.0

var _body: StaticBody3D = null
var _pivot: Node3D = null
var _dial: MeshInstance3D = null


static func build(parent: Node, xform: Transform3D, intensity: float,
		face_tex: String, wood_tex: String) -> GrandfatherClock:
	var clock := GrandfatherClock.new()
	clock.name = "GrandfatherClock"
	parent.add_child(clock)
	clock._build(xform, intensity, face_tex, wood_tex)
	return clock


func body() -> StaticBody3D:
	return _body


func pendulum() -> Node3D:
	return _pivot


func dial() -> MeshInstance3D:
	return _dial


func _build(xform: Transform3D, intensity: float, face_tex: String, wood_tex: String) -> void:
	var scary := ScaryObject.new()
	scary.name = "ClockGaze"
	scary.scare_intensity = intensity
	add_child(scary)

	_body = StaticBody3D.new()
	_body.name = "ClockBody"
	_body.transform = xform
	scary.add_child(_body)

	var wood := _wood_material(wood_tex)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.55, 0.42, 0.18)
	brass.metallic = 0.8
	brass.roughness = 0.35
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.04, 0.035, 0.03)
	dark.roughness = 0.95
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.03, 0.03, 0.04, 0.55)
	glass.roughness = 0.12
	glass.metallic = 0.1
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED

	# ---- plinth
	_box("Plinth", PLINTH, Vector3(0, PLINTH.y / 2.0, 0), wood)
	var trunk_y0 := PLINTH.y
	var trunk_cy := trunk_y0 + TRUNK_H / 2.0

	# ---- trunk: a hollow box — back, two sides, a floor and a lintel — so the pendulum has a
	# cavity to swing in and the glass has something dark behind it.
	_box("TrunkBack", Vector3(TRUNK_W, TRUNK_H, 0.02), Vector3(0, trunk_cy, -TRUNK_D / 2.0 + 0.01), wood)
	_box("TrunkSideL", Vector3(0.02, TRUNK_H, TRUNK_D), Vector3(-TRUNK_W / 2.0 + 0.01, trunk_cy, 0), wood)
	_box("TrunkSideR", Vector3(0.02, TRUNK_H, TRUNK_D), Vector3(TRUNK_W / 2.0 - 0.01, trunk_cy, 0), wood)
	_box("TrunkFloor", Vector3(TRUNK_W, 0.02, TRUNK_D), Vector3(0, trunk_y0 + 0.01, 0), dark)
	_box("CavityBack", Vector3(TRUNK_W - 0.04, TRUNK_H - 0.04, 0.004),
		Vector3(0, trunk_cy, -TRUNK_D / 2.0 + 0.024), dark)
	# The glazed door: four rails of wood around a pane of glass, standing on the front face.
	var front_z := TRUNK_D / 2.0
	var rail := 0.05
	_box("DoorRailL", Vector3(rail, TRUNK_H, 0.03), Vector3(-TRUNK_W / 2.0 + rail / 2.0, trunk_cy, front_z), wood)
	_box("DoorRailR", Vector3(rail, TRUNK_H, 0.03), Vector3(TRUNK_W / 2.0 - rail / 2.0, trunk_cy, front_z), wood)
	_box("DoorRailT", Vector3(TRUNK_W, 0.08, 0.03), Vector3(0, trunk_y0 + TRUNK_H - 0.04, front_z), wood)
	_box("DoorRailB", Vector3(TRUNK_W, 0.10, 0.03), Vector3(0, trunk_y0 + 0.05, front_z), wood)
	var pane := MeshInstance3D.new()
	pane.name = "DoorGlass"
	var pm := QuadMesh.new()
	pm.size = GLASS
	pane.mesh = pm
	pane.material_override = glass
	pane.position = Vector3(0, trunk_cy, front_z - 0.005)
	_body.add_child(pane)

	# ---- the pendulum, hung from the top of the cavity, swinging on a looping tween.
	_pivot = Node3D.new()
	_pivot.name = "PendulumPivot"
	_pivot.position = Vector3(0, trunk_y0 + TRUNK_H - 0.10, -0.02)
	_body.add_child(_pivot)
	var rod := MeshInstance3D.new()
	rod.name = "PendulumRod"
	var rm := BoxMesh.new()
	rm.size = Vector3(0.012, PENDULUM_ROD, 0.008)
	rod.mesh = rm
	rod.material_override = brass
	rod.position = Vector3(0, -PENDULUM_ROD / 2.0, 0)
	_pivot.add_child(rod)
	var bob := MeshInstance3D.new()
	bob.name = "PendulumBob"
	var bm := CylinderMesh.new()
	bm.top_radius = BOB_R
	bm.bottom_radius = BOB_R
	bm.height = 0.018
	bob.mesh = bm
	bob.material_override = brass
	bob.rotation.x = PI / 2.0     # a disc facing the glass
	bob.position = Vector3(0, -PENDULUM_ROD + 0.02, 0)
	_pivot.add_child(bob)
	_pivot.rotation.z = deg_to_rad(SWING_DEG)
	var sway := create_tween().set_loops()
	sway.tween_property(_pivot, "rotation:z", deg_to_rad(-SWING_DEG), SWING_HALF_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(_pivot, "rotation:z", deg_to_rad(SWING_DEG), SWING_HALF_PERIOD) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# ---- hood, dial, bezel
	var hood_y0 := trunk_y0 + TRUNK_H
	var hood_cy := hood_y0 + HOOD.y / 2.0
	_box("Hood", HOOD, Vector3(0, hood_cy, 0), wood)
	var hood_front := HOOD.z / 2.0
	_dial = MeshInstance3D.new()
	_dial.name = "Dial"
	var dm := QuadMesh.new()
	dm.size = Vector2(DIAL, DIAL)
	_dial.mesh = dm
	var dial_mat := StandardMaterial3D.new()
	dial_mat.roughness = 0.85
	if ResourceLoader.exists(face_tex):
		dial_mat.albedo_texture = load(face_tex)
	else:
		dial_mat.albedo_color = Color(0.72, 0.66, 0.52)
	_dial.material_override = dial_mat
	_dial.position = Vector3(0, hood_cy, hood_front + 0.004)
	_body.add_child(_dial)
	var bezel := MeshInstance3D.new()
	bezel.name = "Bezel"
	var tm := TorusMesh.new()
	tm.inner_radius = DIAL / 2.0
	tm.outer_radius = DIAL / 2.0 + 0.022
	tm.rings = 48
	tm.ring_segments = 12
	bezel.mesh = tm
	bezel.material_override = brass
	bezel.rotation.x = PI / 2.0     # torus lies in xy, its hole facing the room
	bezel.position = Vector3(0, hood_cy, hood_front + 0.006)
	_body.add_child(bezel)
	# Hood door rails, so the dial sits inside a frame like the pendulum does.
	_box("HoodRailL", Vector3(0.05, HOOD.y, 0.03), Vector3(-HOOD.x / 2.0 + 0.025, hood_cy, hood_front), wood)
	_box("HoodRailR", Vector3(0.05, HOOD.y, 0.03), Vector3(HOOD.x / 2.0 - 0.025, hood_cy, hood_front), wood)

	# ---- pediment and finials
	var ped_cy := hood_y0 + HOOD.y + PEDIMENT.y / 2.0
	_box("Pediment", PEDIMENT, Vector3(0, ped_cy, 0), wood)
	for sx in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		fin.name = "Finial_%s" % ("L" if sx < 0 else "R")
		var fm := CylinderMesh.new()
		fm.top_radius = 0.008
		fm.bottom_radius = 0.022
		fm.height = 0.12
		fin.mesh = fm
		fin.material_override = brass
		fin.position = Vector3(sx * (PEDIMENT.x / 2.0 - 0.07), ped_cy + PEDIMENT.y / 2.0 + 0.06, 0)
		_body.add_child(fin)

	# ---- one collider for the gaze ray and the walk (it stands 0.38 m into a 3 m hall)
	var col := CollisionShape3D.new()
	col.name = "ClockCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, DEPTH)
	col.shape = shape
	col.position = Vector3(0, HEIGHT / 2.0, 0)
	_body.add_child(col)

	# ---- the tick: a positional loop at the bob, room tone under the score.
	var s := GameState.load_audio("clock_tick")
	if s:
		var tick := AudioStreamPlayer3D.new()
		tick.name = "ClockTick"
		tick.stream = s
		tick.volume_db = TICK_DB
		tick.max_db = 0.0
		tick.unit_size = TICK_UNIT
		tick.position = Vector3(0, trunk_y0 + 0.3, 0)
		_body.add_child(tick)
		tick.finished.connect(tick.play)
		tick.play()


func _box(part_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	_body.add_child(mi)
	return mi


# Dark walnut, triplanar so every box face carries grain without per-face UVs. Negative V,
# the project-wide rule for triplanar wood and wallpaper (Issue 19).
func _wood_material(tex_path: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.55
	mat.metallic = 0.0
	if ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(2.4, -2.4, 2.4)
		mat.albedo_color = Color(0.9, 0.85, 0.8)
	else:
		mat.albedo_color = Color(0.16, 0.10, 0.06)
	return mat
