extends StaticBody3D
class_name HouseGuillotine

# THE GUILLOTINE ON THE PORCH (2026-09-24, the Porch pass — the user's design: *"in this porch
# you will have a guillotine, and … behind the falling painting you will have a watermelon"*).
#
# ⭐ 2026-09-24 (c) — IT STARTS WITHOUT ITS BLADE (playtest capture #3, the user: *"it makes no
# sense to walk there … you need to search for something there"*). The blade is driven into a
# stump in a clearing out in the forest (`house_blade_stump.gd`); the frame stands with the weight
# and the edge missing and the rope hanging slack to the boards. The fruit and the blade go in
# **in either order**; the rope can only be pulled with both.
#
# Four states for the fruit, one flag for the blade, and NO FAIL STATE — it can never hurt you
# (the user rejected the "put your own head in" version outright; see
# `backlogs/02-house-porch.md` §6):
#
#   (any, no blade) --E with the blade-->   the blade is mounted (hauled up, the rope cleated)
#   EMPTY  --E with the watermelon-->       LOADED (the fruit is set in the lunette, where a head goes)
#   LOADED --E, blade mounted-->            CUT    (the rope is pulled, the blade drops, the fruit
#                                                   bursts in two, and the BOLT CUTTERS that were
#                                                   inside it fall ON THE DECK BOARDS in front)
#   CUT    --E-->                           DONE   (you take the cutters)
#
# E with nothing to give does nothing here except emit — the LEVEL decides what is thought
# (throttled): `blade_missing_tried` while the frame has no blade (*WHERE IS THE BLADE?*),
# `empty_tried` once it has one and the lunette is empty (*SHALL I PUT SOMETHING THERE?*). Prop
# emits, level decides: the `house_fridge.gd` / `cellar_gate.gd` split.
#
# ⚠️ BUILT FROM PARTS (Issue 35 — "silhouette carries a prop here, art does not"): two uprights
# on runners with rear braces, a crossbar, a two-board lunette with the neck gap between them, a
# weighted oblique blade riding in front of the lunette, a bascule bench behind, and a rope over
# a pulley to a toggle. A guillotine that is one box is a box.
# ⭐ 2026-09-24 (c): NO BASKET (capture #2, the user: *"remove the box, and make the bolt cutters
# appear just on the floor"*). The cutters and one half of the fruit land on the deck boards at
# FLOOR_Z, clear of the runners (which end at z 0.25).
#
# ⚠️ The blade travels IN FRONT of the lunette boards (z +0.06, the boards end at +0.035), which
# is how the real machine's grooves work and why it can drop through the gap without a mesh ever
# passing through wood.
#
# Local frame: +Z is the FRONT (the lunette side, where the player stands), uprights at ±X; y = 0
# is the deck's top face.

signal empty_tried
signal blade_missing_tried
signal blade_mounted
signal loaded
signal cut
signal cutters_taken

enum State { EMPTY, LOADED, CUT, DONE }

const WOOD_TEX := "res://assets/textures/level_2_house/house_wood_stairs.png"
const FRAME_HALF := 0.30          # uprights at x = ±FRAME_HALF
const LUNETTE_Y := 0.70           # the neck gap's centre — where the fruit sits
const BLADE_UP_Y := 1.95          # the blade assembly's origin, raised
# …and dropped: the blade's LOWEST point lands on the lower lunette board's top face. ⭐ 2026-09-24
# (d): derived (`blade_down_y()`), because the lowest point depends on the art's aspect — it was the
# constant 0.94, which is exactly this for the old box geometry (its low corner is 0.31 below the
# origin).
const LOWER_BOARD_TOP := 0.63
const BLADE_Z := 0.06
const PULL_TIME := 0.35
const DROP_TIME := 0.16
const MOUNT_TIME := 0.45          # the rope hauled taut when the blade goes on
# ⭐ 2026-09-24 (c): where the cutters and one half land — ON THE DECK, in front of the frame.
# The runners and the front cross beam end at z 0.25; the player stands ~1.2 m out.
const FLOOR_Z := 0.60
const BENCH_TOP := 0.55
const CUTTERS_SCALE := 0.55       # bolt_cutters.gd at 0.55 = 0.31 m, shorter than the fruit
# The rope: anchored under the pulley, its toggle cleated at TOGGLE_Y when a blade hangs on it,
# and lying on the boards when there is none (the rope run out to its full length — SLACK).
const ROPE_TOP := 2.42
const ROPE_LEN := 1.36
const TOGGLE_Y := 1.03
const TOGGLE_SLACK_Y := 0.02

var state: int = State.EMPTY
# Set by the level (`level_2.gd:_refresh_carried()`'s sibling) — the prop never reads GameState.
var melon_in_hand: bool = false
var blade_in_hand: bool = false

var _has_blade: bool = false
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


func has_blade() -> bool:
	return _has_blade


func blade_node() -> Node3D:
	return _blade


func has_cutters() -> bool:
	return _cutters != null and is_instance_valid(_cutters)


func cutters_node() -> Node3D:
	return _cutters if has_cutters() else null


func halves() -> Array[Node3D]:
	return _halves


# ------------------------------------------------------------------ the interaction

func can_interact() -> bool:
	if _busy:
		return false
	return state != State.DONE


func prompt_text() -> String:
	match state:
		State.EMPTY, State.LOADED:
			if not _has_blade and blade_in_hand:
				return "E — Mount the blade."
			if state == State.EMPTY and melon_in_hand:
				return "E — Set the watermelon in the lunette."
			if not _has_blade:
				return "E — There is no blade."
			return "E — The lunette is empty." if state == State.EMPTY else "E — Pull the rope."
		State.CUT:
			return "E — Take the bolt cutters."
	return ""


func interact() -> void:
	if not can_interact():
		return
	match state:
		State.EMPTY, State.LOADED:
			# The blade first when it is in hand: one press, one thing.
			if not _has_blade and blade_in_hand:
				_mount(true)
				blade_mounted.emit()
			elif state == State.EMPTY and melon_in_hand:
				_load(true)
				loaded.emit()
			elif not _has_blade:
				# ⚠️ A loaded frame with no blade REFUSES the pull — nothing drops, nothing is cut.
				blade_missing_tried.emit()
			elif state == State.EMPTY:
				empty_tried.emit()
			else:
				_pull()
		State.CUT:
			# The cutters take themselves (their own `interact()` is what the ray finds when it
			# reaches down to the boards); this is the path for a ray that stopped on the frame.
			if has_cutters():
				_cutters.call("interact")


# The restore path — force the STATE, never replay the EVENT (MovedProp's rule). No sound, no
# tween, no signal. A cut fruit implies a mounted blade (it did the cutting).
func restore(melon_state: String, cutters_already_taken: bool, blade_mounted_already: bool = false) -> void:
	if blade_mounted_already or melon_state == "cut":
		_mount(false)
	match melon_state:
		"placed":
			_load(false)
		"cut":
			_fruit.visible = false
			_blade.position.y = blade_down_y()
			_lay_halves(false)
			if cutters_already_taken:
				state = State.DONE
			else:
				_spawn_cutters()
				state = State.CUT


# ------------------------------------------------------------------ the beats

# The blade goes on and the rope is hauled up and cleated. Animated: the rope and its toggle come
# up off the boards to the cleat, with the rope-through-pulley sound (it ends in an iron catch).
func _mount(animate: bool) -> void:
	_has_blade = true
	_blade.visible = true
	_blade.position = Vector3(0, BLADE_UP_Y, BLADE_Z)
	if not animate:
		_rope_taut()
		return
	_busy = true
	_play("guillotine_rope", _toggle.position, -2.0)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_toggle, "position:y", TOGGLE_Y, MOUNT_TIME)
	tw.parallel().tween_property(_toggle, "rotation:z", 0.0, MOUNT_TIME)
	tw.parallel().tween_property(_rope, "scale:y", 1.0, MOUNT_TIME)
	tw.tween_callback(func() -> void: _busy = false)


func _rope_taut() -> void:
	_toggle.position.y = TOGGLE_Y
	_toggle.rotation.z = 0.0
	_rope.scale.y = 1.0


func _rope_slack() -> void:
	_toggle.position.y = TOGGLE_SLACK_Y
	_toggle.rotation.z = PI / 2.0          # the toggle lies on the boards
	_rope.scale.y = (ROPE_TOP - TOGGLE_SLACK_Y - 0.02) / ROPE_LEN


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
		# ⭐ 2026-09-24 (b): the user's `guillotine`.
		_play("guillotine", Vector3(0, BLADE_UP_Y, BLADE_Z), 2.0))
	tw.tween_property(_blade, "position:y", blade_down_y(), DROP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_on_blade_down)
	tw.tween_property(_toggle, "position:y", _toggle.position.y, 0.4)
	tw.parallel().tween_property(_rope, "scale:y", 1.0, 0.4)


func _on_blade_down() -> void:
	# The user's `watermelon_crack` is quiet (mean −31.6 dBFS, peak −5), hence +8.
	_play("watermelon_crack", Vector3(0, LUNETTE_Y, 0), 8.0)
	_fruit.visible = false
	_lay_halves(true)
	_spawn_cutters()
	state = State.CUT
	_busy = false
	cut.emit()


# The two halves, FLESH UP: one tumbles forward onto the deck boards, one falls back onto the
# bench. The origin of a half is the centre of its cut face, so resting = surface + LENGTH / 2.
func _lay_halves(animate: bool) -> void:
	for h in _halves:
		if is_instance_valid(h):
			h.queue_free()
	_halves.clear()
	var rest := [
		[Vector3(-0.16, HouseWatermelon.LENGTH / 2.0, FLOOR_Z + 0.02), Vector3(0.10, 0.5, -0.06)],
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
	# On the boards (y = 0 is the deck's top face; the parts sit 7 mm clear of it).
	c.position = Vector3(0.14, 0.004, FLOOR_Z + 0.04)
	c.rotation.y = deg_to_rad(58.0)
	add_child(c)
	_moonlit(c)
	c.picked_up.connect(_on_cutters_picked)
	_cutters = c


func _on_cutters_picked() -> void:
	_cutters = null
	state = State.DONE
	cutters_taken.emit()


# ------------------------------------------------------------------ the blade, as a part

# The blade assembly — an iron weight over an OBLIQUE steel edge — as one node whose origin is
# the weight's underside. STATIC so the stump in the forest (`house_blade_stump.gd`) carries
# exactly the blade this frame is missing. ⚠️ No emission, anywhere: the user's call (2026-09-24
# c) is that nothing points at the blade, and a self-lit edge in a black forest is a beacon.
#
# ⭐⭐ 2026-09-24 (d), playtest 2 capture #2 (*"the blade does not look very realistic, you have the
# image generation tool, please use it"*): the blade is ARTWORK now — `guillotine_blade.png`, an
# RGBA front view (a bolted iron bar on top, a full-width iron band, the steel below it with the
# edge LOW ON THE LEFT seen from the front, the triangle under the diagonal transparent) — on the
# `door.gd:build_visual()` pattern: the art on a QUAD on each face, never on a box face (a BoxMesh
# renders a magnified crop, Issue 24), over thin dark EDGE BOXES that give it thickness.
#   * The quads are cropped by UV to the art's opaque bounding box and sized to ITS aspect at
#     BLADE_ART_W wide (the uprights' inner faces are ±0.26). Alpha SCISSOR, not blend — a blended
#     quad sorts against the trunks and the lunette boards.
#   * The BACK quad is turned round AND mirrored in U (the coordinator's note on the art): a real
#     blade seen from behind has its low corner on the viewer's right, and an un-mirrored back face
#     would show the slant the wrong way round from the rear.
#   * The edge boxes are measured off the art's ALPHA (`blade_profile()`): horizontal strips, each
#     box only as wide as the columns opaque in EVERY row of its strip. So no box can show through
#     the cut-away triangle or the gaps between the bar's three tabs — they are hidden behind the
#     art from the front and back and seen only edge-on, as the blade's thickness.
# Falls back to the two old boxes if the file is not there.
const BLADE_TEX := "res://assets/textures/level_2_house/guillotine_blade.png"
const BLADE_ART_W := 0.50        # 1 cm clear of each upright's inner face (±0.26)
const BLADE_TOP := 0.16          # the art's top edge above the origin (the old weight's top)
const BLADE_PLATE := 0.014       # the edge boxes' thickness; the quads sit 2 mm proud of them
const BLADE_FALLBACK_LOW := -0.31   # the old boxes' lowest point (the edge's low corner)
const BLADE_STRIPS := 12

static var _blade_prof: Dictionary = {}


static func build_blade() -> Node3D:
	var b := Node3D.new()
	b.name = "Blade"
	var prof := blade_profile()
	if not bool(prof.get("ok", false)):
		var weight := _static_part("Weight", Vector3(0.50, 0.16, 0.05), Vector3(0, 0.08, 0), iron_material())
		b.add_child(weight)
		var edge := _static_part("Edge", Vector3(0.46, 0.26, 0.012), Vector3(0, -0.13, 0), steel_material())
		edge.rotation.z = deg_to_rad(12.0)
		b.add_child(edge)
		return b
	var h: float = BLADE_ART_W / float(prof["aspect"])
	# The edge boxes. Each rect is in the art's opaque bounding box, 0..1, x left->right as seen
	# from the front, y top->bottom.
	var n := 0
	for r in prof["boxes"]:
		var rr: Rect2 = r
		var size := Vector3(rr.size.x * BLADE_ART_W, rr.size.y * h, BLADE_PLATE)
		var centre := Vector3((rr.position.x + rr.size.x / 2.0 - 0.5) * BLADE_ART_W,
			BLADE_TOP - (rr.position.y + rr.size.y / 2.0) * h, 0.0)
		b.add_child(_static_part("BladeEdge%d" % n, size, centre, iron_material()))
		n += 1
	var uv: Rect2 = prof["uv"]
	for face in [["BladeArtFront", 1.0], ["BladeArtBack", -1.0]]:
		var sgn: float = face[1]
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = prof["tex"]
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.metallic = 0.35
		mat.roughness = 0.55
		if sgn > 0.0:
			mat.uv1_scale = Vector3(uv.size.x, uv.size.y, 1.0)
			mat.uv1_offset = Vector3(uv.position.x, uv.position.y, 0.0)
		else:
			# Mirrored in U: u runs from the crop's right edge to its left.
			mat.uv1_scale = Vector3(-uv.size.x, uv.size.y, 1.0)
			mat.uv1_offset = Vector3(uv.position.x + uv.size.x, uv.position.y, 0.0)
		var mi := MeshInstance3D.new()
		mi.name = String(face[0])
		var qm := QuadMesh.new()
		qm.size = Vector2(BLADE_ART_W, h)
		mi.mesh = qm
		mi.set_surface_override_material(0, mat)
		mi.position = Vector3(0, BLADE_TOP - h / 2.0, sgn * (BLADE_PLATE / 2.0 + 0.002))
		if sgn < 0.0:
			mi.rotation.y = PI
		b.add_child(mi)
	return b


# The lowest point of the blade below its origin (negative): the bottom of the art, or the old
# edge's low corner.
static func blade_low_y() -> float:
	var prof := blade_profile()
	if not bool(prof.get("ok", false)):
		return BLADE_FALLBACK_LOW
	return BLADE_TOP - BLADE_ART_W / float(prof["aspect"])


func blade_down_y() -> float:
	return LOWER_BOARD_TOP - blade_low_y()


# Measured off the texture's ALPHA, once (a static cache — the frame and the stump both ask):
#   uv     the opaque bounding box, as a fraction of the image (the quads are cropped to it)
#   aspect that box's width / height (the quads are sized to it)
#   boxes  BLADE_STRIPS horizontal strips of it, each reduced to the longest run of columns that
#          are opaque in EVERY sampled row of the strip, inset one sample; runs under 20 % of the
#          width are dropped (the tabs), equal neighbours merged
# ⚠️ Sampled on a grid (~128 columns), not per pixel: this runs at level load. `decompress()`
# first — every texture imports VRAM-compressed (Issue 203) and a compressed image has no pixels
# to read.
static func blade_profile() -> Dictionary:
	if not _blade_prof.is_empty():
		return _blade_prof
	var out := {"ok": false}
	if ResourceLoader.exists(BLADE_TEX):
		var tex := load(BLADE_TEX) as Texture2D
		var img: Image = tex.get_image() if tex else null
		if img and img.is_compressed():
			img.decompress()
		if img and img.get_width() > 8 and img.get_height() > 8:
			out = _profile_of(img, tex)
	_blade_prof = out
	return out


static func _profile_of(img: Image, tex: Texture2D) -> Dictionary:
	var w := img.get_width()
	var hh := img.get_height()
	var step := maxi(1, w / 128)
	var x0 := w
	var x1 := -1
	var y0 := hh
	var y1 := -1
	for y in range(0, hh, step):
		for x in range(0, w, step):
			if img.get_pixel(x, y).a >= 0.5:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	if x1 <= x0 or y1 <= y0:
		return {"ok": false}
	var bw := float(mini(x1 - x0 + step, w - x0))
	var bh := float(mini(y1 - y0 + step, hh - y0))
	var cols: Array[int] = []
	var x := x0
	while x <= x1:
		cols.append(x)
		x += step
	var raw: Array = []           # [a, b, ya, yb] in pixels
	for k in range(BLADE_STRIPS):
		var ya := y0 + int(bh * k / BLADE_STRIPS)
		var yb := y0 + int(bh * (k + 1) / BLADE_STRIPS) - 1
		var best_a := -1
		var best_b := -1
		var run_a := -1
		for i in range(cols.size()):
			var ok := true
			var yy := ya
			while ok:
				if img.get_pixel(cols[i], mini(yy, hh - 1)).a < 0.5:
					ok = false
				if yy >= yb:
					break
				yy = mini(yy + maxi(1, step / 4), yb)     # …always including the strip's last row
			if ok:
				if run_a < 0:
					run_a = i
				if best_a < 0 or (i - run_a) > (best_b - best_a):
					best_a = run_a
					best_b = i
			else:
				run_a = -1
		if best_a < 0 or float(cols[best_b] - cols[best_a]) < 0.2 * bw:
			continue
		# inset one sample either side: the run's ends are only known to the sampling step
		raw.append([cols[best_a] + step, cols[best_b] - step, ya, yb])
	var merged: Array = []
	for r in raw:
		if not merged.is_empty():
			var m: Array = merged[-1]
			if absi(int(m[0]) - int(r[0])) <= step and absi(int(m[1]) - int(r[1])) <= step \
					and int(m[3]) + 1 >= int(r[2]):
				m[0] = maxi(int(m[0]), int(r[0]))
				m[1] = mini(int(m[1]), int(r[1]))
				m[3] = r[3]
				continue
		merged.append(r.duplicate())
	var boxes: Array = []
	for m in merged:
		var ra := float(int(m[0]) - x0) / bw
		var rb := float(int(m[1]) - x0) / bw
		var ta := float(int(m[2]) - y0 + 1) / bh
		var tb := float(int(m[3]) - y0) / bh
		if rb > ra and tb > ta:
			boxes.append(Rect2(ra, ta, rb - ra, tb - ta))
	return {"ok": true, "tex": tex, "aspect": bw / bh, "boxes": boxes,
		"uv": Rect2(float(x0) / w, float(y0) / hh, bw / w, bh / hh), "px": Vector2i(w, hh)}


# ⭐ 2026-09-24 (c), the user's call: DULLER steel so the blade reads grey under the torch. At
# metallic 0.85 / roughness 0.3 it had nothing in the forest to reflect and rendered as a near-black
# wedge in the stump even with the torch on it (render 23_stump_close). Still no emission, and the
# moonlight picture does not change, so this is legibility at arm's length, not a hint from afar.
static func steel_material() -> StandardMaterial3D:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.46, 0.48, 0.52)
	steel.metallic = 0.5
	steel.roughness = 0.5
	return steel


static func iron_material() -> StandardMaterial3D:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.17, 0.16, 0.15)
	dark.metallic = 0.4
	dark.roughness = 0.7
	return dark


static func _static_part(part_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, mat)
	mi.position = pos
	return mi


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
	var dark := iron_material()
	var rope_mat := StandardMaterial3D.new()
	rope_mat.albedo_color = Color(0.42, 0.36, 0.26)
	rope_mat.roughness = 1.0

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

	# The blade assembly: an iron weight and an OBLIQUE steel blade under it. ⭐ 2026-09-24 (c):
	# NOT HERE YET — it is in the stump in the forest, and `_mount()` shows it.
	_blade = build_blade()
	_blade.position = Vector3(0, BLADE_UP_Y, BLADE_Z)
	_blade.visible = false
	add_child(_blade)

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
	rm.height = ROPE_LEN
	rope_mesh.mesh = rm
	rope_mesh.set_surface_override_material(0, rope_mat)
	# Hung from an ANCHOR at its top, so stretching the anchor (`scale.y`) lengthens the rope
	# downward instead of about its own middle.
	_rope = Node3D.new()
	_rope.name = "RopeAnchor"
	_rope.position = Vector3(FRAME_HALF + 0.13, ROPE_TOP, 0.0)
	add_child(_rope)
	rope_mesh.position = Vector3(0, -ROPE_LEN / 2.0, 0)
	_rope.add_child(rope_mesh)
	_part("Cleat", Vector3(0.05, 0.10, 0.05), Vector3(FRAME_HALF + 0.065, 1.12, 0.0), dark)
	_toggle = Node3D.new()
	_toggle.name = "Toggle"
	_toggle.position = Vector3(FRAME_HALF + 0.13, TOGGLE_Y, 0.0)
	add_child(_toggle)
	_part("ToggleGrip", Vector3(0.03, 0.14, 0.03), Vector3(0, 0, 0), _wood, _toggle)
	# No blade on it yet: the rope has run out and the toggle lies on the boards.
	_rope_slack()

	# The fruit's slot in the lunette. Long axis THROUGH the neck gap (local Z), where a head goes.
	_fruit = HouseWatermelon.build_whole()
	_fruit.name = "LoadedMelon"
	_fruit.rotation.x = PI / 2.0
	_fruit.position = Vector3(0, LUNETTE_Y, 0)
	_fruit.visible = false
	add_child(_fruit)

	# Colliders — the frame and the bench as one solid, the uprights to full height. (The basket's
	# third box went with the basket, 2026-09-24 c.)
	_shape(Vector3(0.72, 1.0, 1.30), Vector3(0, 0.5, -0.40))
	_shape(Vector3(0.80, 2.52, 0.16), Vector3(0, 1.26, 0.0))

	_moonlit(self)


func _part(part_name: String, size: Vector3, pos: Vector3, mat: Material,
		parent: Node = null) -> MeshInstance3D:
	var mi := _static_part(part_name, size, pos, mat)
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
	p.max_db = maxf(6.0, db + 2.0)
	p.position = local_pos
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
