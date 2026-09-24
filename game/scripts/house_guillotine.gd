extends StaticBody3D
class_name HouseGuillotine

# THE GUILLOTINE ON THE PORCH (2026-09-24, the Porch pass — the user's design: *"in this porch
# you will have a guillotine, and … behind the falling painting you will have a watermelon"*).
#
# Three presses, three states, and NO FAIL STATE — it can never hurt you (the user rejected the
# "put your own head in" version outright; see `backlogs/02-house-porch.md` §6):
#
#   EMPTY  --E with the watermelon-->  LOADED   (the fruit is set in the lunette, where a head goes)
#   LOADED --E-->                      CUT      (the rope is pulled, the blade drops, the fruit bursts
#                                                in two, and the BOLT CUTTERS that were inside it lie
#                                                in the basket)
#   CUT    --E-->                      DONE     (you take the cutters)
#
# E while EMPTY without the fruit does nothing here except `empty_tried` — the LEVEL repeats the
# red thought (*SHALL I PUT SOMETHING THERE?*), throttled. Prop emits, level decides: the
# `house_fridge.gd` / `cellar_gate.gd` split.
#
# ⚠️ BUILT FROM PARTS (Issue 35 — "silhouette carries a prop here, art does not"): two uprights
# on runners with rear braces, a crossbar, a two-board lunette with the neck gap between them, a
# weighted oblique blade riding in front of the lunette, a bascule bench behind, a rope over a
# pulley to a toggle, and a wicker basket in front. A guillotine that is one box is a box.
#
# ⚠️ The blade travels IN FRONT of the lunette boards (z +0.06, the boards end at +0.035), which
# is how the real machine's grooves work and why it can drop through the gap without a mesh ever
# passing through wood.
#
# Local frame: +Z is the FRONT (the basket side, where the player stands), uprights at ±X.

signal empty_tried
signal loaded
signal cut
signal cutters_taken

enum State { EMPTY, LOADED, CUT, DONE }

const WOOD_TEX := "res://assets/textures/level_2_house/house_wood_stairs.png"
const FRAME_HALF := 0.30          # uprights at x = ±FRAME_HALF
const LUNETTE_Y := 0.70           # the neck gap's centre — where the fruit sits
const BLADE_UP_Y := 1.95          # the blade assembly's origin, raised
const BLADE_DOWN_Y := 0.94        # …and dropped: the oblique edge's low corner on the lower board
const BLADE_Z := 0.06
const PULL_TIME := 0.35
const DROP_TIME := 0.16
const BASKET_Z := 0.46
const BASKET_FLOOR := 0.02
const BENCH_TOP := 0.55
const CUTTERS_SCALE := 0.55       # bolt_cutters.gd at 0.55 = 0.31 m, shorter than the fruit

var state: int = State.EMPTY
# Set by the level (`level_2.gd:_refresh_carried()`'s sibling) — the prop never reads GameState.
var melon_in_hand: bool = false

var _busy: bool = false
var _blade: Node3D = null
var _fruit: Node3D = null
var _toggle: Node3D = null
var _rope: Node3D = null            # the rope's ANCHOR at the pulley; scaled to stretch it
var _halves: Array[Node3D] = []
var _cutters: Node3D = null
var _wood: StandardMaterial3D = null


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_build()


func state_name() -> String:
	return ["EMPTY", "LOADED", "CUT", "DONE"][state]


func has_cutters() -> bool:
	return _cutters != null and is_instance_valid(_cutters)


func cutters_node() -> Node3D:
	return _cutters if has_cutters() else null


# ------------------------------------------------------------------ the interaction

func can_interact() -> bool:
	if _busy:
		return false
	return state != State.DONE


func prompt_text() -> String:
	match state:
		State.EMPTY:
			return "E — Set the watermelon in the lunette." if melon_in_hand \
				else "E — The lunette is empty."
		State.LOADED:
			return "E — Pull the rope."
		State.CUT:
			return "E — Take the bolt cutters."
	return ""


func interact() -> void:
	if not can_interact():
		return
	match state:
		State.EMPTY:
			if melon_in_hand:
				_load(true)
				loaded.emit()
			else:
				empty_tried.emit()
		State.LOADED:
			_pull()
		State.CUT:
			# The cutters take themselves (their own `interact()` is what the ray finds when it
			# reaches into the basket); this is the path for a ray that stopped on the frame.
			if has_cutters():
				_cutters.call("interact")


# The restore path — force the STATE, never replay the EVENT (MovedProp's rule). No sound, no
# tween, no signal.
func restore(melon_state: String, cutters_already_taken: bool) -> void:
	match melon_state:
		"placed":
			_load(false)
		"cut":
			_fruit.visible = false
			_blade.position.y = BLADE_DOWN_Y
			_lay_halves(false)
			if cutters_already_taken:
				state = State.DONE
			else:
				_spawn_cutters()
				state = State.CUT


# ------------------------------------------------------------------ the beats

func _load(animate: bool) -> void:
	state = State.LOADED
	_fruit.visible = true
	if not animate:
		_fruit.position = Vector3(0, LUNETTE_Y, 0)
		return
	_fruit.position = Vector3(0, LUNETTE_Y + 0.22, 0.12)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_fruit, "position", Vector3(0, LUNETTE_Y, 0), 0.25)


func _pull() -> void:
	_busy = true
	_play("guillotine_rope", _toggle.position, -2.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# The toggle is hauled down and the rope stretches with it.
	tw.tween_property(_toggle, "position:y", _toggle.position.y - 0.28, PULL_TIME)
	tw.parallel().tween_property(_rope, "scale:y", 1.2, PULL_TIME)
	tw.tween_callback(func() -> void:
		_play("guillotine_drop", Vector3(0, BLADE_UP_Y, BLADE_Z), 2.0))
	tw.tween_property(_blade, "position:y", BLADE_DOWN_Y, DROP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_on_blade_down)
	tw.tween_property(_toggle, "position:y", _toggle.position.y, 0.4)
	tw.parallel().tween_property(_rope, "scale:y", 1.0, 0.4)


func _on_blade_down() -> void:
	_play("melon_burst", Vector3(0, LUNETTE_Y, 0), 2.0)
	_fruit.visible = false
	_lay_halves(true)
	_spawn_cutters()
	state = State.CUT
	_busy = false
	cut.emit()


# The two halves, FLESH UP: one tumbles forward into the basket, one falls back onto the bench.
# The origin of a half is the centre of its cut face, so resting = surface + LENGTH / 2.
func _lay_halves(animate: bool) -> void:
	for h in _halves:
		if is_instance_valid(h):
			h.queue_free()
	_halves.clear()
	var rest := [
		[Vector3(-0.08, BASKET_FLOOR + HouseWatermelon.LENGTH / 2.0, BASKET_Z - 0.02), Vector3(0.12, 0.5, -0.08)],
		[Vector3(0.02, BENCH_TOP + HouseWatermelon.LENGTH / 2.0, -0.32), Vector3(-0.10, -0.7, 0.06)],
	]
	for i in range(rest.size()):
		var r: Array = rest[i]
		var half := HouseWatermelon.build_half()
		# ⚠️ Distinct names: a second sibling called "MelonHalf" is silently renamed @Node3D@NN
		# by Godot (Issue 17's family), and the test counting halves by name found one.
		half.name = "MelonHalf%d" % i
		add_child(half)
		_moonlit(half)
		_halves.append(half)
		var at: Vector3 = r[0]
		var rot: Vector3 = r[1]
		if not animate:
			half.position = at
			half.rotation = rot
			continue
		half.position = Vector3(0, LUNETTE_Y, 0)
		half.rotation = Vector3.ZERO
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(half, "position", at, 0.32) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(half, "rotation", rot, 0.32)


func _spawn_cutters() -> void:
	if has_cutters():
		return
	var c := BoltCutters.new()
	c.name = "BoltCutters"
	c.size_scale = CUTTERS_SCALE
	c.position = Vector3(0.10, BASKET_FLOOR + 0.004, BASKET_Z + 0.02)
	c.rotation.y = deg_to_rad(58.0)
	add_child(c)
	_moonlit(c)
	c.picked_up.connect(_on_cutters_picked)
	_cutters = c


func _on_cutters_picked() -> void:
	_cutters = null
	state = State.DONE
	cutters_taken.emit()


# ------------------------------------------------------------------ the build

func _build() -> void:
	_wood = StandardMaterial3D.new()
	_wood.roughness = 0.9
	if ResourceLoader.exists(WOOD_TEX):
		_wood.albedo_texture = load(WOOD_TEX)
		_wood.uv1_triplanar = true
		_wood.uv1_scale = Vector3(1.2, -1.2, 1.2)
		_wood.albedo_color = Color(0.55, 0.50, 0.46)
	else:
		_wood.albedo_color = Color(0.22, 0.15, 0.10)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.10, 0.09, 0.08)
	dark.metallic = 0.6
	dark.roughness = 0.6
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.46, 0.48, 0.52)
	steel.metallic = 0.85
	steel.roughness = 0.3
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.42, 0.36, 0.26)
	rope_mat.roughness = 1.0
	var wicker := StandardMaterial3D.new()
	wicker.albedo_color = Color(0.32, 0.23, 0.12)
	wicker.roughness = 1.0

	# Runners, cross beams, uprights, crossbar.
	for sx in [-1.0, 1.0]:
		_part("Runner", Vector3(0.08, 0.08, 1.30), Vector3(sx * FRAME_HALF, 0.04, -0.40), _wood)
		_part("Upright", Vector3(0.08, 2.30, 0.10), Vector3(sx * FRAME_HALF, 1.23, 0.0), _wood)
		# Rear brace, bottom-back to top-front (1.22 up, 0.80 forward -> 33.3 deg about X).
		var brace := _part("Brace", Vector3(0.06, 1.46, 0.06), Vector3(sx * FRAME_HALF, 0.69, -0.45), _wood)
		brace.rotation.x = deg_to_rad(33.3)
	_part("CrossBeamFront", Vector3(0.68, 0.08, 0.08), Vector3(0, 0.04, 0.21), _wood)
	_part("CrossBeamBack", Vector3(0.68, 0.08, 0.08), Vector3(0, 0.04, -1.01), _wood)
	_part("Crossbar", Vector3(0.78, 0.12, 0.16), Vector3(0, 2.44, 0.0), _wood)

	# The lunette: two boards with the neck gap between them, closed at the sides.
	_part("LunetteLow", Vector3(0.52, 0.14, 0.07), Vector3(0, 0.56, 0.0), _wood)
	_part("LunetteHigh", Vector3(0.52, 0.14, 0.07), Vector3(0, 0.84, 0.0), _wood)
	for sx in [-1.0, 1.0]:
		_part("LunetteCheek", Vector3(0.07, 0.14, 0.07), Vector3(sx * 0.225, LUNETTE_Y, 0.0), _wood)

	# The bascule bench behind it, on two pairs of legs.
	_part("Bench", Vector3(0.30, 0.05, 0.95), Vector3(0, BENCH_TOP - 0.025, -0.55), _wood)
	for lz in [-0.95, -0.20]:
		for lx in [-0.10, 0.10]:
			_part("BenchLeg", Vector3(0.05, BENCH_TOP - 0.05, 0.05),
				Vector3(lx, (BENCH_TOP - 0.05) / 2.0, lz), _wood)

	# The blade assembly: an iron weight and an OBLIQUE steel blade under it.
	_blade = Node3D.new()
	_blade.name = "Blade"
	_blade.position = Vector3(0, BLADE_UP_Y, BLADE_Z)
	add_child(_blade)
	_part("Weight", Vector3(0.50, 0.16, 0.05), Vector3(0, 0.08, 0), dark, _blade)
	var edge := _part("Edge", Vector3(0.46, 0.26, 0.012), Vector3(0, -0.13, 0), steel, _blade)
	edge.rotation.z = deg_to_rad(12.0)

	# The rope: over a pulley at the crossbar's end, down the outside of the right upright to a
	# cleat, with a wooden toggle on its free end.
	var pulley := MeshInstance3D.new()
	pulley.name = "Pulley"
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05
	pm.bottom_radius = 0.05
	pm.height = 0.03
	pulley.mesh = pm
	pulley.set_surface_override_material(0, dark)
	pulley.position = Vector3(FRAME_HALF + 0.08, 2.44, 0.0)
	pulley.rotation.x = PI / 2.0
	add_child(pulley)
	var rope_mesh := MeshInstance3D.new()
	rope_mesh.name = "Rope"
	var rm := CylinderMesh.new()
	rm.top_radius = 0.009
	rm.bottom_radius = 0.009
	rm.height = 1.36
	rope_mesh.mesh = rm
	rope_mesh.set_surface_override_material(0, rope_mat)
	# Hung from an ANCHOR at its top, so stretching the anchor (`scale.y`) lengthens the rope
	# downward instead of about its own middle.
	_rope = Node3D.new()
	_rope.name = "RopeAnchor"
	_rope.position = Vector3(FRAME_HALF + 0.13, 2.42, 0.0)
	add_child(_rope)
	rope_mesh.position = Vector3(0, -0.68, 0)
	_rope.add_child(rope_mesh)
	_part("Cleat", Vector3(0.05, 0.10, 0.05), Vector3(FRAME_HALF + 0.065, 1.12, 0.0), dark)
	_toggle = Node3D.new()
	_toggle.name = "Toggle"
	_toggle.position = Vector3(FRAME_HALF + 0.13, 1.03, 0.0)
	add_child(_toggle)
	_part("ToggleGrip", Vector3(0.03, 0.14, 0.03), Vector3(0, 0, 0), _wood, _toggle)

	# The basket, open-topped, in front of the lunette.
	var basket := Node3D.new()
	basket.name = "Basket"
	basket.position = Vector3(0, 0, BASKET_Z)
	add_child(basket)
	_part("BasketFloor", Vector3(0.44, BASKET_FLOOR, 0.32), Vector3(0, BASKET_FLOOR / 2.0, 0), wicker, basket)
	for sz in [-1.0, 1.0]:
		_part("BasketWall", Vector3(0.44, 0.26, 0.02), Vector3(0, 0.13, sz * 0.15), wicker, basket)
	for sx in [-1.0, 1.0]:
		_part("BasketWall", Vector3(0.02, 0.26, 0.28), Vector3(sx * 0.21, 0.13, 0), wicker, basket)

	# The fruit's slot in the lunette. Long axis THROUGH the neck gap (local Z), where a head goes.
	_fruit = HouseWatermelon.build_whole()
	_fruit.name = "LoadedMelon"
	_fruit.rotation.x = PI / 2.0
	_fruit.position = Vector3(0, LUNETTE_Y, 0)
	_fruit.visible = false
	add_child(_fruit)

	# Colliders — the frame and the bench as one solid, the uprights to full height, the basket.
	_shape(Vector3(0.72, 1.0, 1.30), Vector3(0, 0.5, -0.40))
	_shape(Vector3(0.80, 2.52, 0.16), Vector3(0, 1.26, 0.0))
	_shape(Vector3(0.46, 0.28, 0.34), Vector3(0, 0.14, BASKET_Z))

	_moonlit(self)


func _part(part_name: String, size: Vector3, pos: Vector3, mat: Material,
		parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


func _shape(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	add_child(cs)


# Render layer 2 is the MOON's cull mask (`house_outdoors.gd:MOON_LAYER`) — the porch props are
# lit by it; nothing inside the house is on it.
static func _moonlit(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers |= 2
	for c in n.get_children():
		_moonlit(c)


func _play(base: String, local_pos: Vector3, db: float) -> void:
	var s := GameState.load_audio(base)
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = db
	p.unit_size = 6.0
	p.max_db = 6.0
	p.position = local_pos
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
