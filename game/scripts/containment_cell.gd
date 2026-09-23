extends Node3D
class_name ContainmentCell

# ⭐ OBJECT 12'S TANK — concept A, "the glass tank" (K-CELL, 2026-09-23, the user's choice over
# a barred cell and a restraint frame: backlogs/captures/breach-2026-09-23-cell-concepts/).
#
# ONE BUILD, TWO LEVELS. KONTUR stands it OCCUPIED in the Passage: the facility's title creature
# behind 60 mm glass, chained by the neck, turning its head to follow you. THE BREACH stands it
# BREACHED: the same tank with the front burst outward and nobody in it. The two can never drift
# apart because they are the same script. Set `state` BEFORE `add_child()`; `_ready()` builds
# from it once.
#
#   var cell := ContainmentCell.new()
#   cell.state = ContainmentCell.STATE_BREACHED    # default STATE_OCCUPIED
#   cell.drain = true                               # the stained floor drain in front
#   parent.add_child(cell)
#
# THE LOCAL FRAME IS CONVENTIONAL: FRONT = −z (the glass that bursts, the placard, the drain, the
# direction of the charge), BACK = +z (the steel wall with the gouges, meant to stand against a
# room wall), glass on −z and ±x. The footprint is square (2 × 2 m), so turning it changes nothing
# a player can bump into. KONTUR turns it PI/2 so the front faces the walking line.
#
# ⚠️ IT HAS NO RULES AT ALL, in either state — the `watcher.gd` contract, verbatim: no
# `ScaryObject`, no gaze panic, no kill radius, no `Screamer`, no trigger volume, no fail state,
# no `interact()`, and it adds ZERO panic. The occupant has no collider; the tank has one.
#
# ⚠️ IT MUST NEVER BECOME A PURSUER. `SCARY.md` §8.4 is "one chase level in twelve" and that
# level is 6. The breached state is a set, not a door: nothing comes out of it.
#
# ⚠️ IT USES `hollow_crown.glb` (via `CreatureAnim`) AND `creature_object12.gd`'s PALETTE — HUE
# SHARED, LEVEL SCALED (Issue 147). `SPECIMEN_ALBEDO` / `SPECIMEN_EMISSION_COLOR` are that script's
# colours verbatim; `SPECIMEN_DIM` / `SPECIMEN_EMISSION` / `SPECIMEN_SPECULAR` are this level's,
# because the Breach meets the creature across a lit facility and KONTUR meets it at 1.5 m under a
# torch. The shipped Breach material rendered 1.8–2.8× brighter than what was behind it here.
#
# ⚠️ AND DARKENING ALONE CANNOT WORK. The occupant goes invisible (contrast 0.006–0.09) before it
# goes dark, because `watcher.gd`'s premise is "a dark shape OCCLUDING A LIT SURFACE". So the three
# faces the player looks THROUGH the tank at are lit: the steel back wall carries its own emission
# (the caged lamp's pool of light, painted into `cell_back_wall.png`), and each side carries a
# one-sided backlit liner just inside its glass. Emission illuminates nothing in this project (no
# GI, no glow), so this raises the BACKGROUND without touching the figure — which is the point.
#
# ⚠️ THE CAGED LAMP IS EMISSION ONLY. `check_darkness.gd` asserts nothing burns in KONTUR's Soviet
# half (z < 51), the user's D2 call; a real light in this tank would be the first. The light it
# "throws" is the back wall's baked pool.

const GLB_PATH := CreatureAnim.GLB_PATH
const IDLE_RATE := 0.15

# ---- the two states ------------------------------------------------------------------------
const STATE_OCCUPIED := "occupied"
const STATE_BREACHED := "breached"

## "occupied" (KONTUR, the default) or "breached" (the Breach). Read once, in `_ready()`.
@export_enum("occupied", "breached") var state: String = STATE_OCCUPIED
## The stained floor drain in front of the tank.
@export var drain: bool = true


func is_breached() -> bool:
	return state == STATE_BREACHED


# ---- dimensions (local; front = −z) -------------------------------------------------------
const SIZE := Vector2(2.0, 2.0)   # footprint, x by z
const HEIGHT := 2.6
const PLINTH_H := 0.16
const CAP_H := 0.14
const POST := 0.14
const GLASS_T := 0.06            # the placard says 60 mm, so the glass is 60 mm
const GLASS_C := 0.965           # distance of each pane's centre plane from the tank centre
const GLASS_IN := GLASS_C - GLASS_T / 2.0      # 0.935, the pane's inner face
const GLASS_OUT := GLASS_C + GLASS_T / 2.0     # 0.995, the pane's outer face
const GLASS_HALF := 0.84         # half-width of a pane (the posts' inner faces are at 0.86)
const GLASS_Y0 := PLINTH_H + 0.02
const GLASS_Y1 := HEIGHT - 0.02
# The riveted clamp band on the OUTSIDE of each pane: the heavy frame in the concept. It laps
# 4 cm over the glass edge, so the visible glass is ±0.80 wide and 0.36..2.40 high.
const BAND_IN := 0.80
const BAND_OUT := 1.032
const BAND_W0 := 1.002           # band's inner plane; 7 mm clear of the glass
const BAND_T := 0.03
const SILL_TOP := 0.36
const HEADER_BOT := 2.40
const RIVET_PITCH := 0.09
# Decals on the INSIDE of the glass, 2.5 cm off it (the brief's ≥ 2 cm, and clear of the side
# liners 3 cm further in).
const DECAL_W := GLASS_IN - 0.025
const LINER_W := 0.88            # the side liners' distance from the centre

# Backlit surfaces (see the header). Dark albedo, because emission is most of a surface's colour
# here and a pale albedo under a lit panel blows out (Issue 21).
const LINER_ALBEDO := Color(0.05, 0.055, 0.052)
const LINER_EMISSION := Color(0.60, 0.66, 0.64)
# ⚠️ BOTH ARE `EMISSION_OP_MULTIPLY` over their own art, so the energy scales a TEXTURE, not a flat
# colour — which is why they sit near 1.0 where the old flat liners sat at 0.16–0.18. The first
# build left the back wall on Godot's default ADD, which is (emission colour + texture) × energy:
# it rendered as a flat 0.69 slab with the gouges washed out (Issue 81's exact shape, bisected).
# No texel is above 0.67 sRGB, so ≤ 1.0 here cannot clamp (Issue 21).
const LINER_ENERGY := 1.0        # the one-sided side liners, over cell_side_wall.png
const BACK_WALL_ENERGY := 1.0    # the gouged back wall, over cell_back_wall.png
const BULB_ENERGY := 0.8         # under 1.0, or it clamps to flat white (Issue 21)

const TEX_BACK := "res://assets/textures/level_5_kontur/cell_back_wall.png"
const TEX_SIDE := "res://assets/textures/level_5_kontur/cell_side_wall.png"
const TEX_SMEAR := "res://assets/textures/level_5_kontur/cell_blood_smear.png"
const TEX_DRAGS := "res://assets/textures/level_5_kontur/cell_claw_drags.png"
const TEX_STAIN := "res://assets/textures/level_5_kontur/cell_floor_stain.png"
const TEX_CRACK := "res://assets/textures/level_5_kontur/cell_glass_crack.png"
const TEX_PLACARD := "res://assets/textures/level_5_kontur/cell_placard.png"
const TEX_IRON := "res://assets/textures/shared/rusted_iron.png"

# Yaw only, and slowly. A head that snaps is a creature with a rule; a head that takes a second to
# come round is a thing that noticed you.
const TRACK_RATE := 0.9           # radians per second
const TRACK_RANGE := 26.0

# Derived from the file's MEASURED level: `object12_cell.wav` is −10.87 dBFS RMS
# (tools/make_sfx_kontur_extra.py prints it). At −18 it sits ~11 dB under KONTUR's breath loop.
const HUM_DB := -18.0
const HUM_UNIT := 7.0

# ---- the restraint ------------------------------------------------------------------------
# ⚠️ THE COLLAR RIDES THE `neck` BONE, AND ITS ORIENTATION DOES NOT. Measured over a full
# `unsteady` cycle the neck wanders x −0.16..0.15 and z −0.00..0.26 around the occupant's origin,
# so a collar fixed in space would visibly pass through the creature. It follows the bone's
# POSITION every frame; its lugs stay on the tank's ±x, because a loose ring hung on two chains
# does not turn when the head inside it turns — and a collar that turned with the head would swing
# its chains through the skull the moment the creature tracked a player to the side.
const COLLAR_R := 0.125
const COLLAR_ALONG := 0.35        # the ring sits this far from `neck` toward `Head`
const COLLAR_LEAN := 0.5          # how much of the neck's lean the ring takes (0 = level)
const CHAIN_ANCHOR_X := 0.30
const CHAIN_ANCHOR_Y := HEIGHT - 0.015
# The chains PAY OUT through ceiling fairleads rather than stretching: links sit at a fixed pitch
# from the lug to the fairlead and the count changes, so the breathing sway and the lunge move
# them without a single link ever deforming.
const LINK_PITCH := 0.05
const LINK_POOL := 32
# The breached collar hangs lower (the winch has let it down) and turns on its chains.
const BREACH_COLLAR_POS := Vector3(0.04, 1.52, 0.16)
const BREACH_SWING := 3.4         # seconds per swing
# Hung steeply: level, a torn ring seen from the front is a flat bar (first render). Tipped, the
# open "C" and the sheared lock read from every side.
const BREACH_COLLAR_TILT := Vector3(0.62, 0.35, -0.38)

# ---- the charge (kontur.gd BS1) -----------------------------------------------------------
# Driven from `_process`, not a Tween, so the collar — which reads the neck bone in `_process` —
# can never lag the body by a frame. Same shape the Tween had: expo-out, hold, sine back.
# ⚠️ IT HITS THE GLASS NOW, AND THE GLASS ANSWERS AT THE MOMENT OF IMPACT. With a front pane back
# in the way, two things about the old beat broke, both measured in the first renders:
#   * the old fixed 0.62 m lunge stopped the frontmost bone at −0.674, 26 cm short of the pane;
#   * the white flash, fired at t = 0 at 1.2, made the pane between the player and the creature an
#     opaque grey sheet (frame mean 0.25) for exactly the 0.16–0.34 s the body was at the glass.
# So the lunge is sized from the occupant's real bone reach to stop the frontmost bone
# LUNGE_FRONT_MARGIN inside the pane (fingers reach ~8 cm past the hand bone), never past it, and
# the flash, the crack and the thud all land when the body arrives.
# ⚠️ AND IT LUNGES AT THE PLAYER, into whichever pane is between them. The old lunge was a fixed
# local −z, which was the face an AnteEast arrival meets while the booth stood unturned; with the
# tank turned PI/2, −z is WEST, and a player who came through AnteEast (the black door's side on a
# coin flip) would have watched it lunge sideways past them. The crack lands on the pane it hit.
# The head STOPS TRACKING for the lunge: turning while lunging changed the pose after the lunge was
# sized and put a hand 6 cm through the glass (measured with tracking deliberately broken).
const LUNGE_FALLBACK := 0.62            # when there is no skeleton to measure
const LUNGE_MAX := 0.85
const LUNGE_FRONT_MARGIN := 0.12      # ~8 cm of finger past the hand bone, + the sway during the lunge
const LUNGE_OUT := 0.16
const LUNGE_HOLD := 0.18
const LUNGE_BACK := 0.6
# A POP, NOT A SHEET, AND ONLY ON THE STRUCK PANE. The pane is a double-sided 60 mm box, so its
# emission lands twice; one shared material flashed all three panes; and a 0.28 s fade still had
# the pane grey while the body was pressed to it (render at 0.32 s, AnteEast approach).
const IMPACT_FLASH := 0.22
const IMPACT_FADE := 0.12
const CRACK_SIZE := 0.95
const REACH_BONES := ["LeftHand", "RightHand", "LeftForeArm", "RightForeArm", "Head", "head_end",
	"headfront"]

var _anim: CreatureAnim = null
var _occupant: Node3D = null
var _occupant_rest := Vector3.ZERO
var _occupant_material: StandardMaterial3D = null
var _player: Node3D = null
var _yaw: float = 0.0
var _lunge_t: float = -1.0
var _lunge_dir := Vector3(0, 0, -1)     # tank-local, horizontal
var _lunge_dist: float = LUNGE_FALLBACK
var _lunge_face := "front"
var _lunge_wall: float = 0.0
var _impacted := false
var _neck_idx := -1
var _head_idx := -1

# The blackout beat (kontur.gd BS1): the tank's own light dies with the room's.
var _liners: Array = []                 # [[MeshInstance3D, original_emission_energy], ...]
var _bulb_mat: StandardMaterial3D = null
var _placard_mat: StandardMaterial3D = null
var _pane_mats: Dictionary = {}           # face -> the pane's own glass material
var _cracks: Dictionary = {}              # face -> MeshInstance3D, hidden until that pane is hit
var _charged: bool = false
var _decal_n := 0

var _collar: Node3D = null
var _collar_half_r: Node3D = null
var _chains: Array = []                 # [{ "mm": MultiMesh, "lug": Node3D, "anchor": Vector3 }]
var _t := 0.0

var _steel: StandardMaterial3D
var _trim: StandardMaterial3D
var _band: StandardMaterial3D


# ---- the specimen's palette -----------------------------------------------------------------
# `creature_object12.gd:_apply_retint()`'s colours, verbatim. Do not re-pick them.
const SPECIMEN_ALBEDO := Color(0.35, 0.4, 0.32)
const SPECIMEN_EMISSION_COLOR := Color(0.4, 0.05, 0.05)
# The Breach's loose creature runs 1.0 / 0.12 / 0.2; these differ deliberately (Issue 147). If the
# user ever wants identical numbers, that is the one edit.
const SPECIMEN_DIM := 0.45             # albedo scale
const SPECIMEN_EMISSION := 0.16        # emission energy
const SPECIMEN_SPECULAR := 0.0


func _specimen_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(SPECIMEN_ALBEDO.r * SPECIMEN_DIM,
		SPECIMEN_ALBEDO.g * SPECIMEN_DIM, SPECIMEN_ALBEDO.b * SPECIMEN_DIM)
	m.roughness = 0.9
	# ⚠️ A dielectric's specular is NOT scaled by albedo — the chest hotspot survives any darkening.
	m.metallic_specular = SPECIMEN_SPECULAR
	m.emission_enabled = true
	m.emission = SPECIMEN_EMISSION_COLOR
	m.emission_energy_multiplier = SPECIMEN_EMISSION   # under 1.0 — Issue 21
	return m


# Test surface. `check_kontur_entities.gd` asserts every renderable in the occupant carries this one
# material. Null in the breached state, which has no occupant.
func occupant_material() -> StandardMaterial3D:
	return _occupant_material


func _ready() -> void:
	if state != STATE_OCCUPIED and state != STATE_BREACHED:
		push_warning("ContainmentCell: unknown state '%s', building occupied" % state)
		state = STATE_OCCUPIED
	_steel = _iron_mat(Color(0.30, 0.31, 0.29), 0.35, 0.62)
	_trim = _iron_mat(Color(0.20, 0.21, 0.20), 0.3, 0.7)
	_band = _iron_mat(Color(0.26, 0.27, 0.25), 0.4, 0.55)
	_build_shell()
	_build_restraint()
	_build_fixtures()
	_build_grime()
	if is_breached():
		_build_breach()
	else:
		_build_occupant()
		_build_audio()
	if drain:
		_build_drain()
	_build_collider()


# ------------------------------------------------------------------------------------ the tank

# Face frames: `n` points OUT of the face, `t` is the viewer's right when standing outside it, and
# `yaw` turns a QuadMesh (which faces +z) to face out with its texture unmirrored.
const FACES := {
	"front": { "n": Vector3(0, 0, -1), "t": Vector3(-1, 0, 0), "yaw": PI },
	"right": { "n": Vector3(1, 0, 0), "t": Vector3(0, 0, -1), "yaw": PI / 2.0 },
	"left": { "n": Vector3(-1, 0, 0), "t": Vector3(0, 0, 1), "yaw": -PI / 2.0 },
}


func _fpos(face: String, u: float, v: float, w: float) -> Vector3:
	var f: Dictionary = FACES[face]
	return (f["t"] as Vector3) * u + Vector3(0, v, 0) + (f["n"] as Vector3) * w


func _fbox(face: String, n: String, u: float, v: float, w: float,
		su: float, sv: float, sw: float, mat: Material) -> MeshInstance3D:
	var size := Vector3(su, sv, sw) if face == "front" else Vector3(sw, sv, su)
	return _box(n, size, _fpos(face, u, v, w), mat)


func _build_shell() -> void:
	var hx: float = SIZE.x / 2.0
	var hz: float = SIZE.y / 2.0
	_box("Plinth", Vector3(SIZE.x + 0.14, PLINTH_H, SIZE.y + 0.14), Vector3(0, PLINTH_H / 2.0, 0), _trim)
	_box("Cap", Vector3(SIZE.x + 0.14, CAP_H, SIZE.y + 0.14), Vector3(0, HEIGHT + CAP_H / 2.0, 0), _trim)
	var post_h: float = HEIGHT - PLINTH_H
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box("Post", Vector3(POST, post_h, POST),
				Vector3(sx * (hx - POST / 2.0), PLINTH_H + post_h / 2.0, sz * (hz - POST / 2.0)), _steel)

	# ⚠️ Never a mirror (Issue 148, and see `_glass_mat()`): at roughness 0.08 the torch put a pinpoint
	# glare on the glass that landed ON THE OCCUPANT'S CHEST and was twice mistaken for a highlight
	# on the creature.
	var faces: Array = ["left", "right"] if is_breached() else ["front", "left", "right"]
	for face in faces:
		# One material PER PANE, so the charge's impact pop lands on the pane it hit and no other.
		_pane_mats[face] = _glass_mat(0.20)
		# ⚠️ Each pane is 2 cm clear of every post, the plinth and the cap. Two visible surfaces in
		# one plane is this project's most common bug class, and with a transparent one the fight
		# is invisible in a still and obvious in motion.
		_fbox(face, "Pane" + String(face).capitalize(), 0.0, (GLASS_Y0 + GLASS_Y1) / 2.0, GLASS_C,
			GLASS_HALF * 2.0, GLASS_Y1 - GLASS_Y0, GLASS_T, _pane_mats[face])
	for face in ["front", "left", "right"]:
		_build_band(face)

	# ⚠️ THE BACK IS STEEL, NOT GLASS. It stands against a room wall (0.15 m from KONTUR's Passage
	# wall), so nobody can get behind it, and it is worth far more as the lit surface the occupant
	# is a shadow against. The plate reaches 1 cm into the posts so its ends are never seen.
	_box("BackPlate", Vector3(2.0 * (hx - POST) + 0.02, HEIGHT - PLINTH_H, 0.04),
		Vector3(0, PLINTH_H + (HEIGHT - PLINTH_H) / 2.0, 0.96), _steel)
	# The gouged, lamp-lit steel face, 3 cm proud of the plate. Artwork on a QuadMesh, never a box
	# face (Issue 24); sized to the texture's aspect (1.66 × 2.30) by the generator.
	var back := _art_quad("BackWall", TEX_BACK, Vector2(1.66, 2.30),
		Vector3(0, PLINTH_H + 0.04 + 1.15, 0.96 - 0.02 - 0.03), Vector3(0, PI, 0))
	var bm := back.material_override as StandardMaterial3D
	bm.albedo_color = Color(0.35, 0.36, 0.34)
	bm.roughness = 0.6
	bm.metallic_specular = 0.2
	bm.emission_enabled = true
	bm.emission = Color(1, 1, 1)
	bm.emission_texture = bm.albedo_texture
	bm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	bm.emission_energy_multiplier = BACK_WALL_ENERGY
	_capture_liner(back)      # FIRST in `_liners`: check_kontur_blackout reads entry 0
	# ⚠️ THE SIDE LINERS ARE ONE-SIDED (CULL_BACK), AND BOTH OBVIOUS BUILDS FAILED (Issue 147). A
	# frosted backlit pane lays its emission over everything behind it — contrast 1–3 %, and the
	# whole frame's mean went 0.05 → 0.25. A panel facing INTO the tank is drawn from the far side
	# and culled entirely from its own, so from the south you see the creature against the north
	# liner and from the north against the south one.
	_capture_liner(_backlit_panel("LinerRight", Vector2(1.60, 2.30),
		Vector3(LINER_W, 1.35, 0), -PI / 2.0))
	_capture_liner(_backlit_panel("LinerLeft", Vector2(1.60, 2.30),
		Vector3(-LINER_W, 1.35, 0), PI / 2.0))

	_build_placard()


# The heavy riveted frame on the outside of one face: two full-height stiles that also wrap the
# corner post, a header and a sill, and one row of rivets down the middle of each.
func _build_band(face: String) -> void:
	var w: float = BAND_W0 + BAND_T / 2.0
	var h0: float = PLINTH_H
	var h1: float = HEIGHT
	var rivets: Array = []
	var mid_u: float = (BAND_IN + BAND_OUT) / 2.0
	if face == "front":
		# The front stiles run out to BAND_OUT and cover the corner; the side stiles stop at the
		# front stile's inner plane, so the two only ever meet back to back.
		for s in [-1.0, 1.0]:
			_fbox(face, "BandStile", s * mid_u, (h0 + h1) / 2.0, w, BAND_OUT - BAND_IN, h1 - h0, BAND_T, _band)
			rivets.append([face, s * mid_u, h0 + 0.10, s * mid_u, h1 - 0.10])
	else:
		# Side stiles: the front one from the front band's inner plane back to BAND_IN, the rear
		# one flush with the posts' back face.
		# For "right" t = −z, so the FRONT (−z) is at +u; for "left" t = +z, the front is at −u.
		var front_sign: float = 1.0 if face == "right" else -1.0
		var fa: float = front_sign * BAND_W0
		var fb: float = front_sign * BAND_IN
		var ra: float = -front_sign * BAND_IN
		var rb: float = -front_sign * (SIZE.y / 2.0)
		_fbox(face, "BandStile", (fa + fb) / 2.0, (h0 + h1) / 2.0, w, absf(fa - fb), h1 - h0, BAND_T, _band)
		_fbox(face, "BandStile", (ra + rb) / 2.0, (h0 + h1) / 2.0, w, absf(ra - rb), h1 - h0, BAND_T, _band)
		rivets.append([face, (fa + fb) / 2.0, h0 + 0.10, (fa + fb) / 2.0, h1 - 0.10])
		rivets.append([face, (ra + rb) / 2.0, h0 + 0.10, (ra + rb) / 2.0, h1 - 0.10])
	_fbox(face, "BandHeader", 0.0, (HEADER_BOT + h1) / 2.0, w, BAND_IN * 2.0, h1 - HEADER_BOT, BAND_T, _band)
	_fbox(face, "BandSill", 0.0, (h0 + SILL_TOP) / 2.0, w, BAND_IN * 2.0, SILL_TOP - h0, BAND_T, _band)
	rivets.append([face, -BAND_IN + 0.08, (HEADER_BOT + h1) / 2.0, BAND_IN - 0.08, (HEADER_BOT + h1) / 2.0])
	rivets.append([face, -BAND_IN + 0.08, (h0 + SILL_TOP) / 2.0, BAND_IN - 0.08, (h0 + SILL_TOP) / 2.0])
	_add_rivets(rivets, BAND_W0 + BAND_T)


# One MultiMesh of rivet heads per face — ~100 heads, one draw call. Half of each squashed sphere
# is buried in the band, so what shows is a dome.
func _add_rivets(rows: Array, w: float) -> void:
	var xforms: Array = []
	var face := ""
	for r in rows:
		face = r[0]
		var a := Vector2(r[1], r[2])
		var b := Vector2(r[3], r[4])
		var n: int = int(floor(a.distance_to(b) / RIVET_PITCH)) + 1
		for i in range(n):
			var p: Vector2 = a.lerp(b, float(i) / float(max(1, n - 1)))
			var pos := _fpos(face, p.x, p.y, w)
			var nrm: Vector3 = FACES[face]["n"]
			# squashed sphere: local Y is the short axis, turned to point out of the face
			var basis := Basis(Quaternion(Vector3.UP, nrm))
			xforms.append(Transform3D(basis, pos))
	var sm := SphereMesh.new()
	sm.radius = 0.013
	sm.height = 0.014
	sm.radial_segments = 10
	sm.rings = 5
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Rivets_" + face
	mmi.multimesh = mm
	var rm := _iron_mat(Color(0.42, 0.42, 0.39), 0.55, 0.45)
	mmi.material_override = rm
	add_child(mmi)


func _build_placard() -> void:
	# A riveted enamel plate bolted to the front header, overhanging the top of the glass. Pillow
	# art (tools/make_kontur_cell_art.py), Russian + English, on a QuadMesh sized to its aspect.
	var holder := Node3D.new()
	holder.name = "Placard"
	add_child(holder)
	var y := 2.42
	var z := -(BAND_W0 + BAND_T)          # the band's outer face
	holder.position = Vector3(0, y, z)
	var plate := MeshInstance3D.new()
	plate.name = "PlacardPlate"
	var pb := BoxMesh.new()
	pb.size = Vector3(0.64, 0.25, 0.012)
	plate.mesh = pb
	plate.material_override = _trim
	plate.position = Vector3(0, 0, -0.006)
	holder.add_child(plate)
	var art := _art_quad("PlacardArt", TEX_PLACARD, Vector2(0.60, 0.225),
		Vector3(0, 0, -0.018), Vector3(0, PI, 0), holder)
	_placard_mat = art.material_override as StandardMaterial3D
	_placard_mat.roughness = 0.8
	# ⚠️ EMISSION_OP_MULTIPLY, low — the redacted signs' recipe (Issue 81): readable under the torch,
	# never a pale rectangle floating in a black room. Label3D is unshaded by default and the old
	# placard WAS that rectangle.
	_placard_mat.emission_enabled = true
	_placard_mat.emission_texture = _placard_mat.albedo_texture
	_placard_mat.emission = Color(1, 1, 1)
	_placard_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_placard_mat.emission_energy_multiplier = 0.25
	if is_breached():
		# One bolt sheared: the plate hangs askew. Same plane, so it never meets the band face.
		holder.rotation.z = 0.13
		holder.position += Vector3(0.02, -0.025, 0)


# ------------------------------------------------------------------------------ the restraint

func _build_restraint() -> void:
	_collar = Node3D.new()
	_collar.name = "Collar"
	add_child(_collar)
	var collar_mat := _iron_mat(Color(0.46, 0.46, 0.43), 0.65, 0.35)   # worn bright where it rubbed
	var lug_l := Node3D.new()
	var lug_r := Node3D.new()
	# Hinge at the back (+z), lock at the front (−z); the RIGHT half pivots on the hinge.
	var half_l := Node3D.new()
	half_l.name = "HalfL"
	_collar.add_child(half_l)
	_collar_half_r = Node3D.new()
	_collar_half_r.name = "HalfR"
	_collar_half_r.position = Vector3(0, 0, COLLAR_R)
	_collar.add_child(_collar_half_r)
	var segs := 14
	for i in range(segs):
		var a: float = (float(i) + 0.5) * TAU / float(segs)
		var parent: Node3D = _collar_half_r if sin(a) > 0.0 else half_l
		var off := Vector3.ZERO if parent == half_l else Vector3(0, 0, -COLLAR_R)
		_box("CollarBand", Vector3(2.0 * COLLAR_R * sin(PI / float(segs)) + 0.004, 0.062, 0.016),
			Vector3(sin(a) * (COLLAR_R + 0.008), 0, cos(a) * (COLLAR_R + 0.008)) + off, collar_mat,
			Vector3(0, a, 0), parent)
	for s in [-1.0, 1.0]:
		var parent2: Node3D = _collar_half_r if s > 0.0 else half_l
		var off2 := Vector3.ZERO if parent2 == half_l else Vector3(0, 0, -COLLAR_R)
		_box("CollarLug", Vector3(0.03, 0.05, 0.04), Vector3(s * (COLLAR_R + 0.025), 0, 0) + off2,
			collar_mat, Vector3.ZERO, parent2)
		_cyl("CollarEye", 0.014, 0.012, Vector3(s * (COLLAR_R + 0.048), 0.0, 0) + off2, collar_mat,
			Vector3(0, 0, PI / 2.0), parent2)
		var lug: Node3D = lug_r if s > 0.0 else lug_l
		lug.name = "LugR" if s > 0.0 else "LugL"
		lug.position = Vector3(s * (COLLAR_R + 0.05), 0.0, 0) + off2
		parent2.add_child(lug)
		# each half carries half of the lock at the front
		_box("CollarLock", Vector3(0.036, 0.074, 0.036), Vector3(s * 0.02, 0, -(COLLAR_R + 0.02)) + off2,
			collar_mat, Vector3.ZERO, parent2)
	_cyl("CollarHinge", 0.013, 0.078, Vector3(0, 0, COLLAR_R + 0.012), collar_mat, Vector3.ZERO, half_l)

	var link := TorusMesh.new()
	link.inner_radius = 0.011
	link.outer_radius = 0.021
	link.rings = 10
	link.ring_segments = 6
	var chain_mat := _iron_mat(Color(0.30, 0.30, 0.28), 0.6, 0.45)
	for s in [-1.0, 1.0]:
		var anchor := Vector3(s * CHAIN_ANCHOR_X, CHAIN_ANCHOR_Y, 0.12)
		# The fairlead the chain pays out through, bolted to the cap's underside (5 mm into the
		# cap, so its top face is never coplanar with the cap's).
		_box("Fairlead", Vector3(0.08, 0.05, 0.08), Vector3(anchor.x, HEIGHT - 0.02, anchor.z), _trim)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = link
		mm.instance_count = LINK_POOL
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "ChainR" if s > 0.0 else "ChainL"
		mmi.multimesh = mm
		mmi.material_override = chain_mat
		add_child(mmi)
		_chains.append({ "mm": mm, "lug": lug_r if s > 0.0 else lug_l, "anchor": anchor })

	if is_breached():
		# TORN OPEN: the right half hangs off the hinge, the lock sheared between the two.
		_collar_half_r.rotation.y = -1.25
		half_l.rotation.y = 0.22
	_place_collar_fallback()


# Before the skeleton is readable, and whenever it is not, the collar sits where the neck is at rest.
func _place_collar_fallback() -> void:
	if is_breached():
		_collar.position = BREACH_COLLAR_POS
		_collar.rotation = BREACH_COLLAR_TILT
	else:
		_collar.position = Vector3(0, 1.84, 0.12)
	_update_chains()


func _tick_collar(delta: float) -> void:
	_t += delta
	if is_breached():
		# It turns and sways slightly on its chains — the only thing in the tank that moves.
		var w: float = TAU / BREACH_SWING
		_collar.position = BREACH_COLLAR_POS + Vector3(0.03 * sin(w * _t), 0.0,
			0.018 * sin(0.77 * w * _t + 1.0))
		_collar.rotation = BREACH_COLLAR_TILT + Vector3(0.03 * sin(w * _t + 0.6),
			0.25 * sin(0.31 * w * _t), 0.06 * sin(w * _t + 0.4))
	elif _anim and _neck_idx >= 0 and _head_idx >= 0:
		var skel := _anim.skeleton()
		var sx := skel.global_transform
		var neck := to_local(sx * skel.get_bone_global_pose(_neck_idx).origin)
		var head := to_local(sx * skel.get_bone_global_pose(_head_idx).origin)
		var up := (head - neck).normalized()
		if up.length() < 0.5:
			up = Vector3.UP
		up = up.lerp(Vector3.UP, 1.0 - COLLAR_LEAN).normalized()
		var fwd := Vector3(0, 0, 1)
		fwd = (fwd - up * fwd.dot(up)).normalized()
		var x := up.cross(fwd)
		_collar.transform = Transform3D(Basis(x, up, fwd), neck + (head - neck) * COLLAR_ALONG)
	_update_chains()


func _update_chains() -> void:
	for c in _chains:
		var mm: MultiMesh = c["mm"]
		var lug: Node3D = c["lug"]
		if not lug.is_inside_tree():
			continue
		var a: Vector3 = to_local(lug.global_position)
		var b: Vector3 = c["anchor"]
		var d := b - a
		var dist := d.length()
		if dist < 0.01:
			mm.visible_instance_count = 0
			continue
		var u := d / dist
		var side := u.cross(Vector3(0, 0, 1))
		if side.length() < 0.1:
			side = u.cross(Vector3(1, 0, 0))
		var v := side.normalized()
		var w := u.cross(v)
		var n: int = mini(LINK_POOL, int(ceil(dist / LINK_PITCH)) + 1)
		for i in range(n):
			# The ring's hole axis alternates between v and w, so each link threads the last.
			var basis := Basis(u * 1.55, w, -v) if i % 2 == 0 else Basis(u * 1.55, v, w)
			mm.set_instance_transform(i, Transform3D(basis, a + u * (LINK_PITCH * (float(i) + 0.3))))
		mm.visible_instance_count = n


# --------------------------------------------------------------------------- fixtures and grime

func _build_fixtures() -> void:
	# ---- the caged lamp, under the ceiling near the back wall: the source of the back wall's
	# painted pool of light. Emission only (see the header).
	var lp := Vector3(0, HEIGHT, 0.60)
	var enamel := _mat(Color(0.10, 0.14, 0.11), 0.3, 0.5)
	var wire := _iron_mat(Color(0.24, 0.24, 0.22), 0.6, 0.5)
	_box("LampMount", Vector3(0.16, 0.025, 0.16), lp + Vector3(0, -0.005, 0), _trim)
	_cyl("LampStem", 0.012, 0.06, lp + Vector3(0, -0.045, 0), wire)
	var shade := MeshInstance3D.new()
	shade.name = "LampShade"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.10
	cm.height = 0.07
	cm.radial_segments = 16
	shade.mesh = cm
	shade.material_override = enamel
	shade.position = lp + Vector3(0, -0.11, 0)
	add_child(shade)
	var bulb := MeshInstance3D.new()
	bulb.name = "LampBulb"
	var sp := SphereMesh.new()
	sp.radius = 0.042
	sp.height = 0.084
	bulb.mesh = sp
	_bulb_mat = _mat(Color(0.20, 0.19, 0.17), 0.0, 0.3)
	_bulb_mat.emission_enabled = true
	_bulb_mat.emission = Color(1.0, 0.92, 0.78)
	_bulb_mat.emission_energy_multiplier = BULB_ENERGY
	bulb.material_override = _bulb_mat
	bulb.position = lp + Vector3(0, -0.175, 0)
	add_child(bulb)
	# the cage: two rings and six ribs
	_torus("LampCage", 0.095, 0.104, lp + Vector3(0, -0.145, 0), wire)
	_torus("LampCage", 0.052, 0.060, lp + Vector3(0, -0.235, 0), wire)
	for i in range(6):
		var a: float = float(i) * TAU / 6.0
		var p0 := lp + Vector3(sin(a) * 0.1, -0.145, cos(a) * 0.1)
		var p1 := lp + Vector3(sin(a) * 0.056, -0.235, cos(a) * 0.056)
		_rod("LampRib", p0, p1, 0.004, wire)

	# ---- the sedative lines, snapped. A manifold in each back corner of the ceiling, and rubber
	# lines hanging from it — torn out of whatever they fed. One carries blood.
	var rubber := _mat(Color(0.20, 0.13, 0.06), 0.0, 0.55)
	var bloodline := _mat(Color(0.20, 0.03, 0.02), 0.0, 0.35)
	var cannula := _mat(Color(0.46, 0.44, 0.38), 0.0, 0.4)
	for s in [-1.0, 1.0]:
		var m := Vector3(s * 0.58, HEIGHT, 0.64)
		_box("LineManifold", Vector3(0.18, 0.05, 0.09), m + Vector3(0, -0.02, 0), _trim)
		for k in range(3 if s < 0.0 else 2):
			var x0 := m + Vector3(s * (-0.06 + 0.06 * k), -0.045, 0.0)
			_cyl("LinePort", 0.011, 0.03, x0 + Vector3(0, -0.005, 0), cannula)
			var pts: Array = []
			if s < 0.0 and k == 0:
				pts = [x0, x0 + Vector3(0.02, -0.55, -0.03)]
			elif s < 0.0 and k == 1:
				pts = [x0, x0 + Vector3(-0.03, -0.62, -0.05), x0 + Vector3(0.05, -0.98, -0.12)]
			elif s < 0.0:
				# the long one: down to the floor and a coil dragged across it
				pts = [x0, x0 + Vector3(0.0, -1.2, -0.06), Vector3(x0.x + 0.05, PLINTH_H + 0.01, 0.40),
					Vector3(x0.x + 0.30, PLINTH_H + 0.01, 0.18)]
			elif k == 0:
				pts = [x0, x0 + Vector3(-0.02, -0.72, -0.04)]
			else:
				pts = [x0, x0 + Vector3(0.03, -0.40, 0.0), x0 + Vector3(-0.04, -0.66, -0.08)]
			var mat: StandardMaterial3D = bloodline if (s > 0.0 and k == 1) else rubber
			_tube(pts, 0.0065, mat)
			# the snapped end: a torn hub, and on the blood line a dark bead that never falls
			var end: Vector3 = pts[pts.size() - 1]
			var prev: Vector3 = pts[pts.size() - 2]
			if end.y > PLINTH_H + 0.05:
				_rod("LineHub", end, end + (end - prev).normalized() * 0.035, 0.0048, cannula)
			if mat == bloodline:
				_sphere("LineDrip", 0.008, end + Vector3(0, -0.045, 0), bloodline)


# Blood and claw drags on the INSIDE of the glass, dried; a stain on the tank floor. All on
# QuadMeshes 2.5 cm off the glass (the decals are double-sided so they read from outside through
# it) and sized from their own textures' aspect (check_art_aspect.gd).
func _build_grime() -> void:
	var faces: Array = ["left", "right"] if is_breached() else ["front", "left", "right"]
	for face in faces:
		match face:
			"front":
				# ⚠️ Nothing across the occupant's own column (x ±0.35) from the front: the head and
				# shoulders must stay readable against the lit back wall.
				_glass_decal(face, TEX_SMEAR, 0.72, Vector2(-0.56, 1.98), 0.0)
				_glass_decal(face, TEX_DRAGS, 0.74, Vector2(0.56, 1.30), 0.05)
				_glass_decal(face, TEX_SMEAR, 0.42, Vector2(0.44, 0.62), 0.3)
			"right":
				_glass_decal(face, TEX_SMEAR, 0.70, Vector2(0.55, 0.92), 0.2)
				_glass_decal(face, TEX_DRAGS, 0.62, Vector2(-0.62, 1.55), -0.04)
			"left":
				_glass_decal(face, TEX_DRAGS, 0.66, Vector2(0.60, 1.62), 0.06)
				_glass_decal(face, TEX_SMEAR, 0.46, Vector2(-0.58, 0.70), -0.35)
	_floor_decal("TankStain", TEX_STAIN, 0.85, Vector3(0.05, PLINTH_H + 0.02, 0.20), 0.7)
	if not is_breached():
		# The impact crack the charge leaves on whichever pane it hits, hidden until then. OUTSIDE the
		# glass (2.2 cm off its outer face), so it is the frontmost layer: crack, glass, blood,
		# creature. `_impact()` slides it along the pane to where the body arrived.
		for face in ["front", "left", "right"]:
			var ck := _glass_decal(face, TEX_CRACK, CRACK_SIZE, Vector2(0.0, 1.84), 0.0,
				GLASS_OUT + 0.022, 2)
			ck.name = "ImpactCrack_" + face
			var cm := ck.material_override as StandardMaterial3D
			cm.albedo_color = Color(0.78, 0.82, 0.80)
			cm.roughness = 0.4          # fracture faces glint; the blood behind them does not
			ck.visible = false
			_cracks[face] = ck


func _glass_decal(face: String, tex: String, height: float, uv: Vector2, roll: float,
		w: float = DECAL_W, priority: int = -1) -> MeshInstance3D:
	var t: Texture2D = load(tex) if ResourceLoader.exists(tex) else null
	var aspect: float = (float(t.get_width()) / float(t.get_height())) if t else 1.0
	# ⚠️ A UNIQUE name each: six siblings called "GlassDecal" come out as "@MeshInstance3D@NN" for
	# all but the first (Issue 17), which is how the first run of check_containment_cell counted 2.
	_decal_n += 1
	var mi := _art_quad("GlassDecal_%s_%d" % [face, _decal_n], tex, Vector2(height * aspect, height),
		_fpos(face, uv.x, uv.y, w), Vector3(0, FACES[face]["yaw"], roll))
	var m := mi.material_override as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# DRIED, so matte: at roughness 0.5 with the default lobe the torch put a pale-pink sheen over the
	# whole smear and it read as wet paint.
	m.roughness = 0.88
	m.metallic_specular = 0.15
	# Drawn BEFORE the glass (whose priority is 0), so the pane tints the blood behind it rather
	# than the sort flipping frame to frame as the camera moves.
	m.render_priority = priority
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _floor_decal(n: String, tex: String, width: float, pos: Vector3, yaw: float) -> MeshInstance3D:
	var t: Texture2D = load(tex) if ResourceLoader.exists(tex) else null
	var aspect: float = (float(t.get_width()) / float(t.get_height())) if t else 1.0
	var holder := Node3D.new()
	holder.name = n
	holder.position = pos
	holder.rotation.y = yaw
	add_child(holder)
	var mi := _art_quad(n + "Art", tex, Vector2(width, width / aspect), Vector3.ZERO,
		Vector3(-PI / 2.0, 0, 0), holder)
	var m := mi.material_override as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.7
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ------------------------------------------------------------------------------ the breached state

# The front has burst OUTWARD: no front pane, teeth of 60 mm glass still in the frame, the rest in
# pieces across the floor in front, the collar torn open and swinging, and a drag of blood across
# the tank floor to the sill. Deterministic (its own seeded RNG), so every load is the same wreck.
func _build_breach() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212
	# ⚠️ GLOSSIER AND LIGHTER THAN THE PANES. The first render used the pane glass (dark, 0.2
	# alpha, the Issue-148 soft lobe) and every piece read as a flat dark triangle painted on the
	# floor. Broken glass is read by its glints. There is no occupant in this state, so Issue 148's
	# glare-on-the-chest concern does not apply here.
	var shard_mat := _glass_mat(0.30)
	shard_mat.albedo_color = Color(0.55, 0.66, 0.63, 0.30)
	shard_mat.roughness = 0.06
	shard_mat.metallic_specular = 0.7
	var prism := PrismMesh.new()
	prism.size = Vector3(1, 1, 1)

	# ---- the teeth left in the frame, pointing into the hole from each edge
	var teeth: Array = []
	var edges := [
		# [u0, u1, v, point_dir(2D), count, min_len, max_len]
		[-0.72, 0.72, SILL_TOP - 0.05, Vector2(0, 1), 6, 0.10, 0.44],
		[-0.72, 0.72, HEADER_BOT + 0.05, Vector2(0, -1), 5, 0.06, 0.30],
		[0.40, 2.20, -(BAND_IN - 0.05), Vector2(1, 0), 4, 0.06, 0.26],
		[0.40, 2.20, BAND_IN - 0.05, Vector2(-1, 0), 4, 0.06, 0.26],
	]
	for e in edges:
		var cnt: int = e[4]
		for i in range(cnt):
			var along: float = lerpf(e[0], e[1], (float(i) + rng.randf_range(0.2, 0.8)) / float(cnt))
			var base_w: float = rng.randf_range(0.10, 0.30)
			var length: float = rng.randf_range(e[5], e[6]) + 0.05
			var dir2: Vector2 = e[3]
			var u: float
			var v: float
			if absf(dir2.y) > 0.5:
				u = along
				v = e[2] + dir2.y * length / 2.0
			else:
				u = e[2] + dir2.x * length / 2.0
				v = along
			# A prism's apex is its local +Y. In the front face's frame the viewer's right is −x, so the
			# apex must point along (−dir.x, dir.y); a roll θ about z sends +Y to (−sin θ, cos θ).
			var roll: float = atan2(dir2.x, dir2.y) + rng.randf_range(-0.22, 0.22)
			var pos := _fpos("front", u, v, GLASS_C + rng.randf_range(-0.003, 0.003))
			var b := Basis(Vector3(0, 0, 1), roll) * Basis(Vector3.UP, rng.randf_range(-0.07, 0.07))
			# ⚠️ LOCAL scale (`b * from_scale`), not `Basis.scaled()`, which scales the PARENT axes.
			b = b * Basis.from_scale(Vector3(base_w, length, GLASS_T))
			teeth.append(Transform3D(b, pos))
	_multimesh("FrontRemnant", prism, teeth, shard_mat)

	# ---- the rest of the pane, across the floor in front (and a few on the tank floor's lip)
	var bits: Array = []
	for i in range(96):
		var d: float = 0.08 + 2.1 * pow(rng.randf(), 1.7)        # metres out from the plinth
		var spread: float = 0.55 + 0.45 * d
		var x: float = rng.randf_range(-1.0, 1.0) * spread
		var size: float = lerpf(0.26, 0.05, clampf(d / 2.2, 0.0, 1.0)) * rng.randf_range(0.5, 1.2)
		if i % 3 == 0:
			size *= 0.35          # grit: a third of the pieces are chips
		var thick: float = GLASS_T if size > 0.12 else rng.randf_range(0.012, 0.03)
		# never closer to the plinth than the piece's own size, or it pokes into the plinth
		var z: float = -(SIZE.y / 2.0 + 0.07) - maxf(d, size * 0.8)
		var y: float = thick / 2.0 + 0.002
		if drain and absf(x) < 0.30 and absf(z + 1.55) < 0.22:
			y += DRAIN_TOP                                      # lying on the grate
		var b2 := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) \
			* Basis(Vector3(1, 0, 0), -PI / 2.0 + rng.randf_range(-0.05, 0.05))
		b2 = b2 * Basis.from_scale(Vector3(size, size * rng.randf_range(0.6, 1.5), thick))
		bits.append(Transform3D(b2, Vector3(x, y, z)))
	for i in range(6):
		var x2: float = rng.randf_range(-0.7, 0.7)
		var s2: float = rng.randf_range(0.05, 0.12)
		var b3 := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis(Vector3(1, 0, 0), -PI / 2.0)
		bits.append(Transform3D(b3 * Basis.from_scale(Vector3(s2, s2, 0.02)),
			Vector3(x2, PLINTH_H + 0.012, -(SIZE.y / 2.0) + rng.randf_range(0.02, 0.14))))
	_multimesh("FloorShards", prism, bits, shard_mat)

	# ---- it went out over the sill: a drag across the tank floor toward the front
	_floor_decal("SillDrag", TEX_DRAGS, 0.5, Vector3(-0.05, PLINTH_H + 0.02, -0.50), PI)


func _multimesh(n: String, mesh: Mesh, xforms: Array, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = n
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mmi


# Test surface: how many glass pieces the breach left, as [teeth in the frame, pieces on the floor].
func breach_shard_counts() -> Vector2i:
	var a := get_node_or_null("FrontRemnant") as MultiMeshInstance3D
	var b := get_node_or_null("FloorShards") as MultiMeshInstance3D
	return Vector2i(a.multimesh.instance_count if a else 0, b.multimesh.instance_count if b else 0)


# ------------------------------------------------------------------------------------- the drain

# A cast grate over a black pit in a soaked stain, just in front of the tank: the thing a facility
# builds under a tank it has to hose out. Built from parts — frame, bars, pit — never a picture of a
# drain on a quad. No collider: it is flush enough to walk over.
# Heights, bottom to top, each layer ≥ 4 mm clear of the next so nothing is ever coplanar:
# stain 0.030 · pit 0.034 · cross bar 0.038..0.052 · bars 0.040..0.054 · frame 0.001..0.056.
# ⚠️ Both flat layers sit ≥ 0.03 above the floor: check_wall_overlap's 2 cm skin includes its own
# boundary, so 0.02 is reported (KONTUR's FLOOR_MARK_Y lesson).
const DRAIN_TOP := 0.056

func _build_drain() -> void:
	var c := Vector3(0, 0, -1.55)
	_floor_decal("DrainStain", TEX_STAIN, 1.30, c + Vector3(0.06, 0.030, -0.12), 0.35)
	var iron := _iron_mat(Color(0.16, 0.16, 0.15), 0.5, 0.6)
	var ow := 0.60
	var od := 0.44
	var fw := 0.035
	var fh := DRAIN_TOP - 0.001
	for s in [-1.0, 1.0]:
		_box("DrainFrame", Vector3(ow, fh, fw), c + Vector3(0, 0.001 + fh / 2.0, s * (od - fw) / 2.0), iron)
		_box("DrainFrame", Vector3(fw, fh, od - 2.0 * fw), c + Vector3(s * (ow - fw) / 2.0, 0.001 + fh / 2.0, 0), iron)
	for i in range(9):
		var x: float = -0.24 + i * 0.06
		_box("DrainBar", Vector3(0.012, 0.014, od - 2.0 * fw), c + Vector3(x, 0.040 + 0.007, 0), iron)
	_box("DrainCross", Vector3(ow - 2.0 * fw, 0.014, 0.014), c + Vector3(0, 0.038 + 0.007, 0), iron)
	var pit := MeshInstance3D.new()
	pit.name = "DrainPit"
	var q := QuadMesh.new()
	q.size = Vector2(ow - 2.0 * fw, od - 2.0 * fw)
	pit.mesh = q
	pit.material_override = _mat(Color(0.006, 0.006, 0.006), 0.0, 1.0)
	pit.position = c + Vector3(0, 0.036, 0)
	pit.rotation.x = -PI / 2.0
	add_child(pit)


# ----------------------------------------------------------------------------------- the collider

# ⚠️ OCCUPIED: ONE box for the whole tank, exactly as before. The occupant has none at all — a
# collider around the creature would be a thing the player could bump into through glass, and the
# first step toward it having a rule.
# ⚠️ BREACHED: the frame and back only. The front is open, so a player can step in — which needs
# the tank floor and a ramp over the 0.16 m sill, because a capsule cannot climb a vertical step
# that tall (the contact normal on its rounded foot is ~53°, past `floor_max_angle`).
func _build_collider() -> void:
	var body := StaticBody3D.new()
	body.name = "CellBody"
	add_child(body)
	var w := SIZE.x + 0.14
	var d := SIZE.y + 0.14
	if not is_breached():
		_col(body, Vector3(w, HEIGHT, d), Vector3(0, HEIGHT / 2.0, 0))
		return
	var slab := 0.2
	_col(body, Vector3(w, HEIGHT + CAP_H, slab), Vector3(0, (HEIGHT + CAP_H) / 2.0, d / 2.0 - slab / 2.0))
	for s in [-1.0, 1.0]:
		_col(body, Vector3(slab, HEIGHT + CAP_H, d), Vector3(s * (w / 2.0 - slab / 2.0), (HEIGHT + CAP_H) / 2.0, 0))
	_col(body, Vector3(w - 2.0 * slab, PLINTH_H, d - slab), Vector3(0, PLINTH_H / 2.0, -slab / 2.0))
	# the ramp: from the floor 0.42 m out to the sill's top edge
	var run := 0.42
	var ang := atan2(PLINTH_H, run)
	var ramp := CollisionShape3D.new()
	var rs := BoxShape3D.new()
	var len := sqrt(run * run + PLINTH_H * PLINTH_H)
	rs.size = Vector3(w - 2.0 * slab, 0.04, len)
	ramp.shape = rs
	# top surface passes through (z = −d/2 − run, y 0) and (z = −d/2, y PLINTH_H)
	var mid := Vector3(0, PLINTH_H / 2.0, -d / 2.0 - run / 2.0)
	# A rotation of −ang about x sends the box's long axis (+z) to (0, sin, cos), rising toward the
	# tank, and its top face's normal (+y) to (0, cos, −sin), facing the approach.
	var nrm := Vector3(0, cos(ang), -sin(ang))
	ramp.position = mid - nrm * 0.02
	ramp.rotation.x = -ang
	body.add_child(ramp)


func _col(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	body.add_child(col)


# ------------------------------------------------------------------------------------ the occupant

func _build_occupant() -> void:
	_occupant = Node3D.new()
	_occupant.name = "Object12"
	_occupant.position = Vector3(0, PLINTH_H, 0.12)
	_occupant_rest = _occupant.position
	add_child(_occupant)

	var visual: Node3D
	_anim = CreatureAnim.build(_occupant)
	if _anim:
		visual = _anim.visual_root()
		# ⚠️ `unsteady` (3.0 s), NEVER `shamble`: measured over a full cycle `shamble` wanders
		# 0.515 m laterally and `unsteady` 0.197 m, and this tank is 2 m across. IDLE_RATE 0.15
		# gives a ~20 s period — breathing, shifting weight, not pacing.
		_anim.play(CreatureAnim.CLIP_UNSTEADY, IDLE_RATE)
		var skel := _anim.skeleton()
		if skel:
			_neck_idx = skel.find_bone("neck")
			_head_idx = skel.find_bone("Head")
		if _neck_idx < 0 or _head_idx < 0:
			push_warning("ContainmentCell: no neck/Head bone — the collar stays at its rest height")
	else:
		# Fallback silhouette, so a missing GLB leaves a shape rather than an empty tank.
		visual = Node3D.new()
		var torso := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.16
		cap.height = 2.1
		torso.mesh = cap
		torso.position.y = 1.15
		visual.add_child(torso)
		var head := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.16
		sph.height = 0.32
		head.mesh = sph
		head.position.y = 2.32
		visual.add_child(head)
		_occupant.add_child(visual)

	# It DUPLICATES the model's own material, so the skin survives and SPECIMEN_ALBEDO multiplies it.
	var applied := 0
	if _anim:
		_occupant_material = _anim.apply_tint(
			SPECIMEN_ALBEDO, SPECIMEN_DIM, SPECIMEN_SPECULAR,
			SPECIMEN_EMISSION_COLOR, SPECIMEN_EMISSION)
		applied = _anim.mesh_instances().size()
	else:
		_occupant_material = _specimen_mat()
		for mi in _mesh_instances(visual):
			mi.material_override = _occupant_material
			applied += 1
	# ⚠️ A GLB WITH ONE MESH TODAY IS NOT A CONTRACT; check_kontur_entities asserts every renderable.
	if applied == 0:
		push_warning("ContainmentCell: no MeshInstance3D to retint — occupant will render raw")


# The blackout beat: when the black door blows the room's lights (kontur.gd:_begin_cell_blackout),
# the tank's own light goes too — back wall, side liners, the bulb, the placard — so the occupant is
# lit ONLY by the player's torch. Restored at the Kitchen. No panic, no rule — a lighting state.
func _capture_liner(mi: MeshInstance3D) -> MeshInstance3D:
	if is_instance_valid(mi) and mi.material_override:
		_liners.append([mi, mi.material_override.emission_energy_multiplier])
	return mi


func set_dark(on: bool) -> void:
	for entry in _liners:
		var mi: MeshInstance3D = entry[0]
		if is_instance_valid(mi) and mi.material_override:
			mi.material_override.emission_energy_multiplier = 0.0 if on else float(entry[1])
	if _bulb_mat:
		_bulb_mat.emission_energy_multiplier = 0.0 if on else BULB_ENERGY
	if _placard_mat:
		_placard_mat.emission_energy_multiplier = 0.0 if on else 0.25


# ⚠️ ZERO PANIC, CANNOT KILL, NO RULE (the user's call, Q3, 2026-09-09). Object 12 surges at the
# glass once as the player passes in the dark: a loud snarl at the front, a camera jolt, a lunge
# that carries it INTO the pane between it and the player and snaps both chains after it — and on impact a pop on
# that pane, a thud, and the pane left CRACKED where it hit (K-CELL), still there when you come back.
# kontur.gd gates it on the blackout being live, which is only ever true after gate 1, so the
# headless entities test never fires it.
# ⚠️ apparition_snarl is a creature lunge, deliberately NOT a fatal screamer file — reusing a death
# sting for a survivable beat teaches the player the death sound is free (INTRO.md's objection).
# ⚠️ A NO-OP IN THE BREACHED STATE: there is nothing in the tank to charge.
func charge(player: Node3D) -> void:
	if _charged or is_breached() or _occupant == null:
		return
	_charged = true
	var target := to_local(player.global_position) if player else Vector3(0, 0, -3)
	var plan := lunge_plan(target)
	_lunge_dir = plan["dir"]
	_lunge_dist = plan["dist"]
	_lunge_face = plan["face"]
	_lunge_wall = plan["wall"]
	var snarl := GameState.load_audio("apparition_snarl")
	if snarl:
		var sp := AudioStreamPlayer3D.new()
		sp.stream = snarl
		sp.volume_db = 3.0
		sp.max_db = 6.0
		sp.unit_size = 8.0
		add_child(sp)
		sp.position = _occupant_rest + _lunge_dir * _lunge_wall + Vector3(0, 1.24, 0)
		sp.finished.connect(sp.queue_free)
		sp.play()
	if player and player.has_method("jolt_camera"):
		player.jolt_camera(0.16, 0.45)
	_lunge_t = 0.0
	_impacted = false


# The charge's plan toward a tank-local point. Test surface as well as the lunge's own sizing:
#   dir    horizontal unit vector from the occupant toward the point
#   face   the first surface that line meets: "front" / "left" / "right" glass, or "back" steel
#   wall   the distance along `dir` from the occupant's origin to that surface's inner face
#   reach  how far the occupant's reach bones already extend along `dir` (NAN without a skeleton)
#   dist   how far it travels: reach + dist = wall − LUNGE_FRONT_MARGIN, capped at LUNGE_MAX
func lunge_plan(target: Vector3) -> Dictionary:
	var o := _occupant_rest
	var d := Vector3(target.x - o.x, 0.0, target.z - o.z)
	d = d.normalized() if d.length() > 0.05 else Vector3(0, 0, -1)
	var wall := INF
	var face := "front"
	var back_in := 0.96 - 0.02 - 0.03                 # the back wall's art face
	var cands := [
		["front", d.z < -0.001, (-GLASS_IN - o.z) / d.z if absf(d.z) > 0.001 else INF],
		["right", d.x > 0.001, (GLASS_IN - o.x) / d.x if absf(d.x) > 0.001 else INF],
		["left", d.x < -0.001, (-GLASS_IN - o.x) / d.x if absf(d.x) > 0.001 else INF],
		["back", d.z > 0.001, (back_in - o.z) / d.z if absf(d.z) > 0.001 else INF],
	]
	for c in cands:
		if c[1] and float(c[2]) < wall:
			wall = float(c[2])
			face = c[0]
	var reach := reach_along(d)
	var dist := LUNGE_FALLBACK if is_nan(reach) \
		else clampf(wall - LUNGE_FRONT_MARGIN - reach, 0.0, LUNGE_MAX)
	return { "dir": d, "face": face, "wall": wall, "reach": reach, "dist": dist }


# How far the occupant's reach bones extend along tank-local horizontal `dir`, measured from where
# the occupant stands right now. NAN without a skeleton.
func reach_along(dir: Vector3) -> float:
	if _anim == null or _anim.skeleton() == null or _occupant == null:
		return NAN
	var skel := _anim.skeleton()
	var o := _occupant.position
	var best := -INF
	for nm in REACH_BONES:
		var i := skel.find_bone(nm)
		if i >= 0:
			var b := to_local(skel.global_transform * skel.get_bone_global_pose(i).origin) - o
			best = maxf(best, b.x * dir.x + b.z * dir.z)
	return NAN if best == -INF else best


# The body arrives at the pane: a short white pop on the glass, the crack, and a thud at the front.
func _impact() -> void:
	_impacted = true
	var gm: StandardMaterial3D = _pane_mats.get(_lunge_face)
	if gm:
		gm.emission_enabled = true
		gm.emission = Color(0.9, 0.95, 1.0)
		var f := create_tween()
		f.tween_property(gm, "emission_energy_multiplier", IMPACT_FLASH, 0.03)
		f.tween_property(gm, "emission_energy_multiplier", 0.0, IMPACT_FADE)
	var hit := _occupant_rest + _lunge_dir * _lunge_wall
	if _cracks.has(_lunge_face):
		# Slide the crack along its pane to where the body arrived, kept inside the visible glass.
		var ck: MeshInstance3D = _cracks[_lunge_face]
		var u: float = hit.dot(FACES[_lunge_face]["t"])
		var lim: float = BAND_IN - CRACK_SIZE / 2.0 - 0.02
		ck.position = _fpos(_lunge_face, clampf(u, -lim, lim), 1.84, GLASS_OUT + 0.022)
		ck.visible = true
	var thud := GameState.load_audio("impact_thud")     # −17.3 dBFS RMS; the Corridor's false door
	if thud:
		var tp := AudioStreamPlayer3D.new()
		tp.stream = thud
		tp.volume_db = 2.0
		tp.max_db = 6.0
		tp.unit_size = 6.0
		add_child(tp)
		tp.position = hit + Vector3(0, 1.64, 0)
		tp.finished.connect(tp.queue_free)
		tp.play()


# Test surface: the pane the charge cracked ("front" / "left" / "right"), or "" if none.
func cracked_face() -> String:
	for f in _cracks:
		if is_instance_valid(_cracks[f]) and (_cracks[f] as MeshInstance3D).visible:
			return f
	return ""


func is_cracked() -> bool:
	return cracked_face() != ""


func _lunge_amount() -> float:
	var t := _lunge_t
	if t < LUNGE_OUT:
		return 1.0 - pow(2.0, -10.0 * t / LUNGE_OUT)          # TRANS_EXPO, EASE_OUT
	t -= LUNGE_OUT
	if t < LUNGE_HOLD:
		return 1.0
	t -= LUNGE_HOLD
	if t < LUNGE_BACK:
		return 0.5 + 0.5 * cos(PI * t / LUNGE_BACK)            # TRANS_SINE, EASE_IN_OUT, back to 0
	return -1.0


func _build_audio() -> void:
	var stream := GameState.load_audio("object12_cell")
	if stream == null:
		return
	var pl := AudioStreamPlayer3D.new()
	pl.name = "CellHum"
	pl.stream = stream
	pl.volume_db = HUM_DB
	pl.unit_size = HUM_UNIT
	pl.max_db = 0.0
	pl.position = Vector3(0, 1.2, 0)
	add_child(pl)
	# Every .wav.import here is loop_mode=0, so loops are restarted in code.
	pl.finished.connect(pl.play)
	pl.play()


# ---------------------------------------------------------------------------------- tracking

# ⚠️ NEVER `../Player`. That assumed the tank's parent was the level, which stops being true the
# moment a level nests it (the Breach's `ContainmentApproach`). The player joins the "player" group
# in `player.gd:_ready()`; the current scene's `Player` is the fallback.
func _find_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var tree := get_tree()
	if tree == null:
		return null
	var p := tree.get_first_node_in_group("player") as Node3D
	if p == null and tree.current_scene:
		p = tree.current_scene.get_node_or_null("Player") as Node3D
	_player = p
	return p


func _process(delta: float) -> void:
	if _occupant:
		if _lunge_t >= 0.0:
			_lunge_t += delta
			var k := _lunge_amount()
			if k < 0.0:
				_lunge_t = -1.0
				k = 0.0
			_occupant.position = _occupant_rest + _lunge_dir * (_lunge_dist * k)
			if not _impacted and _lunge_t >= LUNGE_OUT * 0.85:
				_impact()
		var p := _find_player()
		if p and _lunge_t < 0.0:      # it commits to the lunge: no turning mid-charge
			# ⚠️ In the TANK'S frame. KONTUR turns the tank PI/2; a world-space bearing would have
			# the occupant stare 90° away from the player.
			var to := to_local(p.global_position)
			if Vector2(to.x, to.z).length() <= TRACK_RANGE:
				var want := atan2(to.x, to.z)
				_yaw = _step_angle(_yaw, want, TRACK_RATE * delta)
				_occupant.rotation.y = _yaw
	if _collar:
		_tick_collar(delta)


static func _step_angle(from: float, to: float, max_step: float) -> float:
	var d := wrapf(to - from, -PI, PI)
	return from + clampf(d, -max_step, max_step)


# ------------------------------------------------------------------------------------- helpers

func _mat(albedo: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = rough
	return m


# Rusted-iron grain, triplanar, tinted dark: surface texture, never a picture of anything.
func _iron_mat(tint: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := _mat(tint, metallic, rough)
	if ResourceLoader.exists(TEX_IRON):
		m.albedo_texture = load(TEX_IRON)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(1.6, -1.6, 1.6)
	return m


func _liner_mat(energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = LINER_ALBEDO
	m.roughness = 0.85
	m.metallic_specular = 0.0
	m.emission_enabled = true
	m.emission = LINER_EMISSION
	m.emission_energy_multiplier = energy
	return m


# ⚠️ CULL_BACK is doing the work, not the colour. A `QuadMesh` faces +z; `y_rot` turns it inward.
# It wears the plain lamp-lit steel (cell_side_wall.png, cut to this quad's aspect) rather than a
# flat colour: a flat emissive panel seen at a grazing angle from the front read as a pale light
# box, not the inside of a steel tank.
func _backlit_panel(n: String, size: Vector2, pos: Vector3, y_rot: float) -> MeshInstance3D:
	var mi := _art_quad(n, TEX_SIDE, size, pos, Vector3(0, y_rot, 0))
	var m := mi.material_override as StandardMaterial3D
	if m.albedo_texture == null:
		mi.material_override = _liner_mat(0.18)      # the old flat liner, if the art is missing
		m = mi.material_override
	else:
		m.albedo_color = Color(0.35, 0.36, 0.34)
		m.roughness = 0.6
		m.metallic_specular = 0.15
		m.emission_enabled = true
		m.emission = Color(1, 1, 1)
		m.emission_texture = m.albedo_texture
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_energy_multiplier = LINER_ENERGY
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return mi


func _glass_mat(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# ⚠️ DARK, and no emission (charge() flashes it briefly). A lit pane hides what is behind it,
	# which is the whole prop.
	m.albedo_color = Color(0.10, 0.13, 0.12, alpha)
	# ⚠️ 0.32 / 0.08, not Issue 148's 0.22 / 0.25. That fix was measured against a 1.2-energy torch;
	# the torch has been 1.6 since 2026-09-03, and the first render of this tank put a white disc of
	# glare dead on the occupant's chest again (the torch sits at the eye, so its reflection in a
	# pane faced head-on is ALWAYS at screen centre, which is where the creature is).
	m.roughness = 0.32
	m.metallic = 0.0
	m.metallic_specular = 0.08
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _art_quad(n: String, tex: String, size: Vector2, pos: Vector3, rot: Vector3,
		parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(tex):
		m.albedo_texture = load(tex)
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	(parent if parent else self).add_child(mi)
	return mi


func _box(n: String, size: Vector3, pos: Vector3, mat: Material,
		rot: Vector3 = Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	(parent if parent else self).add_child(mi)
	return mi


func _cyl(n: String, r: float, h: float, pos: Vector3, mat: Material,
		rot: Vector3 = Vector3.ZERO, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	(parent if parent else self).add_child(mi)
	return mi


func _torus(n: String, inner: float, outer: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 20
	tm.ring_segments = 6
	mi.mesh = tm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _sphere(n: String, r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


# A thin cylinder from `a` to `b`.
func _rod(n: String, a: Vector3, b: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var d := b - a
	var mi := _cyl(n, r, d.length(), (a + b) / 2.0, mat)
	var y := d.normalized()
	var x := y.cross(Vector3(0, 0, 1))
	if x.length() < 0.1:
		x = y.cross(Vector3(1, 0, 0))
	x = x.normalized()
	# ⚠️ Right-handed (z = x × y). A negated z mirrors the mesh and flips its winding, so back-face
	# culling would draw the inside of every rod.
	mi.basis = Basis(x, y, x.cross(y)).orthonormalized()
	return mi


# A tube through `pts`, one cylinder per span and a ball at each joint so it bends rather than kinks.
func _tube(pts: Array, r: float, mat: Material) -> void:
	for i in range(pts.size() - 1):
		_rod("Line", pts[i], pts[i + 1], r, mat)
		if i > 0:
			_sphere("LineJoint", r, pts[i], mat)


func _mesh_instances(node: Node) -> Array:
	var out: Array = []
	if node == null:
		return out
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_mesh_instances(c))
	return out
