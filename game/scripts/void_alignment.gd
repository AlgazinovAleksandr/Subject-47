extends StaticBody3D

# ⭐ THREE MEMORIES IN THREE CORNERS, GATED PROMPT (2026-09-20, pass 2).
#
# What this was (pass 1): three IDENTICAL broken doorways over the pit — the island, the far
# north tile and the far south tile — each with a keystone reachable by the ordinary 3 m ray
# from wherever you happened to be standing. The 13:10 playtest logged **20 wrong presses in
# four minutes**, 1 of 3 solved, and at least one press from (-5.4, 47.6): the tile NEXT to
# the north viewpoint, 1.9 m from its feet against a 0.65 m alignment radius. A wrong-TILE
# press and a wrong-ANGLE press were indistinguishable, so the player could not learn
# anything from failing, and the far wing was never reached.
#
# What it is now, on the user's ruling:
#   * THREE DIFFERENT SHAPES, so "which memory is this" is answerable by looking:
#       DOOR   from the island (-3.6, 45.5), looking west   (the pass-1 set, unchanged)
#       BED    from the spine's first tile (1.4, 45.5), looking north-east over the pit
#       WINDOW from the south branch's middle tile (-3.6, 42.8), looking south-east
#   * A CANVAS BUILDER. A shape is a silhouette of 2D rects in the view plane at depth F;
#     each rect is given its OWN depth d and placed at `eye + f*d + canvas*(d/F)`, sized
#     `(w, h)*(d/F)`. The projection from the eye is the silhouette; from anywhere else the
#     pieces scatter. The seam list is every pair of adjacent-rect corner points that must
#     coincide in projection — the same canvas point rendered at two depths.
#   * A GATED PROMPT. `can_interact()` is true only within GATE_RADIUS of that view's FEET.
#     The prompt therefore says WHERE TO STAND and never whether you are aligned — the
#     §8.2 readout the 2026-09-19 ruling removed stays removed. There is no state tell.
#
# ⭐ PASS 3, 2026-09-20: THE KEYSTONES ARE NOT HERE WHEN YOU ARRIVE. Each viewpoint carries
# an empty stone SOCKET; the thing that fills it is hidden in the level's early rooms — a tar
# DOOR HANDLE in PocketA, a bone BED SLAT inside the Ward's folded frame, a verdigris WINDOW
# LATCH inside the flat doorframe in Hall2. Seating one turns the socket into that view's
# keystone, in the anchor's own silhouette; `interact_view()` then runs unchanged, wrong press
# cost and all. The wrong object is refused by name and costs nothing. The three shapes were
# held in 8.7 s at the 15:00 playtest because the three buttons were already standing there.
# ⚠️ The anchors live in the LEVEL's inventory (`level_3.gd`), not in
# `GameState.carried_item`: the shard and an anchor can be carried at once and that property
# is now a composed HUD line, not a key.
#
# ⚠️ THE TOLERANCES ARE MEASURED, NOT GUESSED. `tests/check_void_alignment.gd` sweeps a 0.3 m
# grid over each view's tile at eye 1.65 ± 0.15 m, facing the shape ± 15°, and requires ≥ 70 %
# of the grid to align — the user's target, because a human on a 1.6 m tile has to be able to
# hit it. It also requires the ADJACENT tiles' centres to align from nowhere and to be unable
# to interact at all. Do not narrow `radius` / `seam` without re-running it.
#
# ⚠️ A wrong press costs `WRONG_PRESS_PANIC`, THE USER'S NUMBER (2026-09-20 grill): 6 panic.
# Not a re-tune candidate.
# ⚠️ Nothing else here adds panic, and standing at a viewpoint is charged by no zone: the tile
# hall has no DarkZone, there is no standstill term in the Void and D is watch-only while the
# player is on the tiles. Issue 18 — never tax the posture the puzzle requires.
signal completed

const FRAGMENTS := preload("res://scripts/void_fragments.gd")
const KEYSTONE_SCRIPT := preload("res://scripts/void_keystone.gd")

const EYE_H := 1.65
const KEYSTONE := Vector3(-4.7, 1.45, 45.5)      # = view 0's keystone; this node sits on it
const WRONG_PRESS_PANIC := 6.0

# ⚠️ THE PLACE TELL. The prompt appears inside this radius of a view's feet and nowhere else,
# which is what makes a refused press readable as "wrong angle" rather than "wrong tile".
# 1.5 m covers the whole of a 1.6 m tile (corner 1.13 m) and the whole 2.0 x 2.2 island
# (corner 1.48 m), and excludes every adjacent tile centre (nearest is 1.6 m).
const GATE_RADIUS := 1.5

# ── the three canvases ─────────────────────────────────────────────────────────────────
# A view is: an eye point (`feet` + EYE_H), a look direction `f` (the lateral `l` is derived
# as (f.z, 0, -f.x)), a canvas depth `F`, a canvas offset `off` (u, v) applied to every rect
# AND every seam, and a list of rects in canvas coordinates:
#   u  lateral, +ve along l      v  vertical, relative to the eye
#   w  canvas width   h  canvas height   d  this piece's own depth   t  thickness along f
# A seam is [canvas point, depth A, depth B] — one point of the silhouette rendered at two
# depths. From the eye the two are the same pixel; the angle between them measures the error.
#
# `key` is the keystone's offset from `eye + f*1.1`: (lateral along l, vertical). ⚠️ MEASURED
# FROM THE PICTURE, not chosen. At 1.1 m the keystone subtends ±9.3°, and at (0, -0.2) — the
# same place for all three — it sat ON TOP of the BED's foot leg and the WINDOW's sill in the
# screenshots: the one object the player must look at to press E was hiding the shape they
# have to judge. It now stands beside each silhouette (the DOOR keeps the centre, because
# there it hangs inside its own opening, which is where it reads best).
#
# ⚠️ Every piece of every shape stays ≥ 0.25 m inside the abyss walls (x -8.9..2.8,
# z 40.6..50.4) and clear of the causeway's tiles in y. Measured, not assumed — moving a
# depth moves the piece along f AND scales its lateral offset.
const VIEWS := [
	{
		"nm": "Door", "feet": Vector3(-3.6, 0, 45.5), "f": Vector3(-1, 0, 0),
		"F": 3.7, "off": Vector2(0.0, 0.0), "tint": Color(0.42, 0.36, 0.50),
		# ⭐ The object this socket takes, and where it is: PocketA, beside the trap note.
		"anchor": "handle", "family": "violet",
		"rects": [
			{"nm": "Post0",  "u": -0.80, "v": -0.20, "w": 0.17, "h": 2.50, "d": 2.1, "t": 0.18},
			{"nm": "Post1",  "u":  0.80, "v": -0.20, "w": 0.17, "h": 2.50, "d": 2.4, "t": 0.18},
			{"nm": "Lintel", "u":  0.00, "v":  1.05, "w": 1.77, "h": 0.17, "d": 3.7, "t": 0.20},
		],
		"seams": [[Vector2(-0.80, 1.05), 2.1, 3.7], [Vector2(0.80, 1.05), 2.4, 3.7]],
		"axis": 0, "converged": -8.68,
		# ⚠️ MEASURED (probe_void_view_region, 2026-09-20). The island is 2.0 x 2.2 — the
		# biggest stand in the puzzle — and its posts sit at 2.1/2.4 against a 3.7 m lintel,
		# which is the steepest depth ratio of the three shapes. Worst seam error over the
		# 0.3 m grid is 0.305 rad; the coverage curve is 0.16 -> 73 %, 0.20 -> 86 %,
		# 0.25 -> 96 %. 0.20 is the tightest value with margin over the user's 70 % floor.
		# ⚠️ The adjacent tiles read 0.106 / 0.140 rad — INSIDE this limit — so it is `radius`
		# and the 1.5 m prompt gate, not the seam test, that keeps them out. Perspective
		# alignment is near-invariant along the view axis; a radius is the honest bound.
		"radius": 1.30, "seam": 0.20, "height": 0.55, "face": 0.55,
		"key": Vector2(0.0, -0.20),     # inside the doorway: pieces span -14..+14 deg
		"marks": [Vector3(-4.4, 0.14, 44.65), Vector3(-4.4, 0.14, 46.35)],
	},
	{
		"nm": "Bed", "feet": Vector3(1.4, 0, 45.5), "f": Vector3(0.2402, 0, 0.9707),
		"F": 3.0, "off": Vector2(-0.50, 0.0), "tint": Color(0.50, 0.47, 0.42),
		"anchor": "slat", "family": "bone",     # inside the Ward's E-armed folded frame
		# ⚠️ A BED HAS TO READ AS A BED. The first cut gave the headboard the width of a post
		# (0.27) and the frame the depth of a rail (0.18), and the screenshot from the tile
		# read as a bench: silhouette carries a prop, Issue 35. The headboard is now a BOARD
		# and the frame a mattress-deep mass; the left edge and the depths are unchanged, so
		# the seams and the measured region are unchanged with them.
		"rects": [
			{"nm": "Headboard", "u": -0.675, "v":  0.02, "w": 0.55, "h": 0.84, "d": 3.0, "t": 0.14},
			{"nm": "Frame",     "u": -0.100, "v": -0.50, "w": 1.70, "h": 0.30, "d": 2.2, "t": 0.22},
			{"nm": "LegHead",   "u": -0.810, "v": -0.99, "w": 0.14, "h": 0.68, "d": 1.7, "t": 0.13},
			{"nm": "LegFoot",   "u":  0.680, "v": -0.99, "w": 0.14, "h": 0.68, "d": 2.6, "t": 0.13},
		],
		"seams": [
			[Vector2(-0.95, -0.35), 3.0, 2.2],   # headboard foot <-> frame head end
			[Vector2(-0.88, -0.65), 1.7, 2.2],   # head-end leg top <-> frame underside
			[Vector2( 0.75, -0.65), 2.6, 2.2],   # foot leg top <-> frame foot end
		],
		"axis": 1, "converged": -5.20,
		# Measured: worst seam error over the 1.6 m tile's grid 0.118 rad; 0.12 -> 92 %.
		"radius": 1.00, "seam": 0.12, "height": 0.55, "face": 0.55,
		"key": Vector2(0.38, -0.20),    # +19.1 deg; the bed spans -28.6..+6.1 deg
		"marks": [Vector3(1.945, 0.14, 45.829), Vector3(1.071, 0.14, 46.045)],
	},
	{
		"nm": "Window", "feet": Vector3(-3.6, 0, 42.8), "f": Vector3(0.6, 0, -0.8),
		"F": 2.2, "off": Vector2(-0.42, 0.18), "tint": Color(0.30, 0.40, 0.35),
		"anchor": "latch", "family": "verdigris",   # inside Hall2's flat doorframe
		"rects": [
			{"nm": "Head",  "u":  0.00, "v":  0.62, "w": 1.10, "h": 0.16, "d": 2.2, "t": 0.14},
			{"nm": "Sill",  "u":  0.00, "v": -0.72, "w": 1.10, "h": 0.16, "d": 1.6, "t": 0.14},
			{"nm": "Jamb0", "u": -0.47, "v": -0.05, "w": 0.16, "h": 1.50, "d": 1.7, "t": 0.13},
			{"nm": "Jamb1", "u":  0.47, "v": -0.05, "w": 0.16, "h": 1.50, "d": 2.0, "t": 0.13},
			{"nm": "Cross", "u":  0.00, "v": -0.05, "w": 0.78, "h": 0.13, "d": 1.9, "t": 0.12},
		],
		"seams": [
			[Vector2(-0.55,  0.70), 1.7, 2.2],   # left jamb head <-> head bar, left end
			[Vector2( 0.55,  0.70), 2.0, 2.2],   # right jamb head <-> head bar, right end
			[Vector2(-0.55, -0.80), 1.7, 1.6],   # left jamb foot <-> sill, left end
			[Vector2( 0.55, -0.80), 2.0, 1.6],   # right jamb foot <-> sill, right end
			[Vector2(-0.39, -0.05), 1.9, 1.7],   # cross bar left end <-> left jamb inner face
			[Vector2( 0.39, -0.05), 1.9, 2.0],   # cross bar right end <-> right jamb inner face
		],
		"axis": 1, "converged": -5.20,
		# Measured: worst seam error over the 1.6 m tile's grid 0.099 rad; 0.12 -> 96 %.
		"radius": 1.00, "seam": 0.12, "height": 0.55, "face": 0.55,
		"key": Vector2(0.40, -0.20),    # +20.0 deg; the window spans -26.1..+5.7 deg
		"marks": [Vector3(-3.69, 0.14, 42.17), Vector3(-2.97, 0.14, 42.71)],
	},
]

var solved := false
var reveal_spent := false
var _views: Array = []               # per view: pieces / homes / convs / seams / eye / aim
var _view_solved: Array[bool] = [false, false, false]
# ⭐ PASS 3. The body that carries each view's socket (view 0 is this node), and whether its
# anchor has been seated in it. A view cannot be held until its socket is filled.
var _socket_nodes: Array[Node3D] = [null, null, null]   # the interactable body per view
var _socket_mounts: Array[Node3D] = [null, null, null]  # …and the YAWED node its art hangs on
var _socket_filled: Array[bool] = [false, false, false]
var _level: Node = null
var _gate_logged: Array[bool] = [false, false, false]
var _echo: Array[Node3D] = []
var _gate: StaticBody3D
var _gate_shape: CollisionShape3D
var _gate_parts: Array[Node3D] = []
var _player: CharacterBody3D
var _echo_light: OmniLight3D
var _sound: AudioStreamPlayer3D
var _knock: AudioStreamPlayer3D
var _sequence: Tween
var _view_tweens: Array = [null, null, null]


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


func _ready() -> void:
	# ⚠️ VIEW 0'S KEYSTONE IS THIS NODE, so its `key` row has to agree with `KEYSTONE`.
	# Asserted rather than derived, because `position` is read by every `_world_box` below.
	position = KEYSTONE
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.28, 0.48, 0.48)
	shape.shape = box
	add_child(shape)
	var stone := FRAGMENTS._mat(Color(0.42, 0.36, 0.50))
	for v in range(VIEWS.size()):
		_build_view(v)
	_build_seal(stone)
	_build_echo(stone)
	_build_inscription()
	_knock = AudioStreamPlayer3D.new()
	_knock.name = "KeystoneKnock"
	_knock.stream = GameState.load_audio("wall_knock_stone")
	_knock.volume_db = -6.0
	_knock.unit_size = 4.0
	_knock.bus = AudioBuses.AMBIENCE
	add_child(_knock)
	_player = get_parent().get_node_or_null("Player") as CharacterBody3D
	_level = get_parent()


func _world_box(nm: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	return FRAGMENTS._box(self, size, at - position, material, nm)


# ── the canvas builder ─────────────────────────────────────────────────────────────────
# `l` is derived, never authored: a box with rotation.y = atan2(f.x, f.z) has basis.z == f and
# basis.x == (f.z, 0, -f.x), so a BoxMesh of size (w*r, h*r, t) in that frame is exactly the
# canvas rect at depth d. ⚠️ Do NOT go back to composing an axis-aligned size vector out of
# abs(f) and abs(l) — that only works for the DOOR, whose f happens to be a world axis.
static func lateral_of(f: Vector3) -> Vector3:
	return Vector3(f.z, 0.0, -f.x)


# The world point of a canvas point (u, v) rendered at depth `d`.
static func canvas_point(eye: Vector3, f: Vector3, F: float, off: Vector2,
		u: float, v: float, d: float) -> Vector3:
	var l := lateral_of(f)
	var r: float = d / F
	return eye + f * d + l * ((u + off.x) * r) + Vector3(0, (v + off.y) * r, 0)


func _build_view(v: int) -> void:
	var spec: Dictionary = VIEWS[v]
	var f: Vector3 = (spec["f"] as Vector3).normalized()
	var F: float = spec["F"]
	var off: Vector2 = spec["off"]
	var eye: Vector3 = (spec["feet"] as Vector3) + Vector3(0, EYE_H, 0)
	var yaw: float = atan2(f.x, f.z)
	var stone := FRAGMENTS._mat(spec["tint"])
	var pieces: Array[Node3D] = []
	for rect in (spec["rects"] as Array):
		var d: float = rect["d"]
		var r: float = d / F
		var centre := canvas_point(eye, f, F, off, rect["u"], rect["v"], d)
		var size := Vector3(float(rect["w"]) * r, float(rect["h"]) * r, float(rect["t"]))
		var piece := _world_box("%s_%s" % [spec["nm"], rect["nm"]], size, centre, stone)
		piece.rotation.y = yaw
		pieces.append(piece)
	# Seams, resolved to world point PAIRS once at build time.
	var seams: Array[Vector3] = []
	for s in (spec["seams"] as Array):
		var cp: Vector2 = s[0]
		seams.append(canvas_point(eye, f, F, off, cp.x, cp.y, float(s[1])))
		seams.append(canvas_point(eye, f, F, off, cp.x, cp.y, float(s[2])))
	# Home / converged transforms, stored rather than recomputed: restore_state must never
	# depend on a hardcoded coordinate list again.
	var axis: int = spec["axis"]
	var homes: Array[Vector3] = []
	var convs: Array[Vector3] = []
	for piece in pieces:
		homes.append(piece.position)
		var target: Vector3 = piece.position
		target[axis] = float(spec["converged"]) - position[axis]
		convs.append(target)
	# Dark framing on the tile itself, so the place you have to stand is findable in the dark.
	var dark := FRAGMENTS._mat(Color(0.14, 0.11, 0.19))
	for at in (spec["marks"] as Array):
		var mark := _world_box("ViewEdge_%s" % spec["nm"], Vector3(0.14, 0.28, 0.14), at, dark)
		mark.rotation.y = yaw
	# View 0's socket is this node. The other two get their own bodies on layer 2.
	if v > 0:
		var ks := StaticBody3D.new()
		ks.name = "Keystone" + String(spec["nm"])
		ks.set_script(KEYSTONE_SCRIPT)
		# set(), not `ks.puzzle =` — the variable is statically typed StaticBody3D and the
		# script's own members are not visible to the compiler through it.
		ks.set("puzzle", self)
		ks.set("view", v)
		var key: Vector2 = spec["key"]
		ks.position = eye + f * 1.1 + lateral_of(f) * key.x + Vector3(0, key.y, 0) - position
		ks.rotation.y = yaw
		add_child(ks)
		_socket_nodes[v] = ks
		_socket_mounts[v] = ks
	else:
		# ⚠️ THIS NODE MUST NOT BE ROTATED. `_world_box()` converts a world point to a local
		# one by subtracting `position` and nothing else, so every piece, seal plate and echo
		# post in the level assumes an identity basis here. View 0's socket therefore hangs on
		# a child mount that carries the yaw, and the body stays square to the world.
		var mount := Node3D.new()
		mount.name = "SocketMount"
		mount.rotation.y = yaw
		add_child(mount)
		_socket_nodes[0] = self
		_socket_mounts[0] = mount
	FRAGMENTS.anchor_socket(_socket_mounts[v], spec["tint"], "Socket")
	# The canvas centre at depth F: what "looking at the shape" means from an off-centre cell.
	var aim := canvas_point(eye, f, F, off, 0.0, 0.0, F)
	_views.append({"pieces": pieces, "homes": homes, "convs": convs, "seams": seams,
		"eye": eye, "f": f, "aim": aim})


func _build_seal(stone: Material) -> void:
	_gate = StaticBody3D.new()
	_gate.name = "MorgueSeal"
	_gate.position = Vector3(-8.90, 1.26, 45.5) - position
	_gate.collision_layer = 1
	_gate.collision_mask = 0
	add_child(_gate)
	_gate_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.20, 2.52, 1.75)
	_gate_shape.shape = box
	_gate.add_child(_gate_shape)
	# Broken horizontal plates leave visible seams but form a solid seal.
	for i in range(3):
		var plate := FRAGMENTS._box(_gate, Vector3(0.22, 0.79, 1.72),
			Vector3(0, (i - 1) * 0.84, 0), stone, "SealPlate%d" % i)
		plate.rotation.x = (i - 1) * 0.018
		_gate_parts.append(plate)


func _build_echo(stone: Material) -> void:
	# A second, much larger doorway stands in the abyss beyond the platform edge.
	# It has no collision: the crossing and the camera never move during the reveal.
	for side in [-1.0, 1.0]:
		var post := _world_box("BelowPost", Vector3(0.55, 4.0, 0.45),
			Vector3(-7.0 + side * 0.4, -4.0, 45.5 + side * 2.1), stone)
		post.rotation.x = side * 0.4
		_echo.append(post)
	var lintel := _world_box("BelowLintel", Vector3(0.55, 0.48, 4.65), Vector3(-7.4, -1.4, 45.5), stone)
	lintel.rotation.x = -0.25
	_echo.append(lintel)
	_echo_light = OmniLight3D.new()
	_echo_light.name = "BelowLight"
	_echo_light.position = Vector3(-5.5, -2.0, 45.5) - position
	_echo_light.light_color = Color(0.67, 0.48, 0.9)
	_echo_light.light_energy = 0.0
	_echo_light.omni_range = 7.0
	add_child(_echo_light)
	_sound = AudioStreamPlayer3D.new()
	_sound.name = "StoneReply"
	_sound.position = Vector3(-7.0, -3.0, 45.5) - position
	_sound.stream = GameState.load_audio("wall_knock_stone")
	_sound.volume_db = -4.0
	_sound.unit_size = 8.0
	_sound.bus = AudioBuses.AMBIENCE
	add_child(_sound)


func _build_inscription() -> void:
	var inscription := Label3D.new()
	inscription.name = "AlignmentInscription"
	# ⚠️ TEACHES, never REPORTS. It names how many places there are to stand, because the seal
	# opening on the third solve is otherwise unguessable; it says nothing about whether the
	# shape is currently held, which is the readout the 2026-09-20 ruling removed.
	# ⭐ PASS 3 names the three objects, because the sockets are empty when you arrive and an
	# empty socket with no idea what fills it is a dead end rather than a quest. It still says
	# nothing about WHERE they are and nothing about whether a shape is currently held.
	inscription.text = "STAND WHERE THE BROKEN THINGS\nREMEMBER ONE DOOR, ONE BED, ONE WINDOW.\nTHE HANDLE, THE SLAT AND THE LATCH ARE ELSEWHERE.\nTHERE ARE THREE PLACES TO STAND."
	inscription.font_size = 30
	inscription.pixel_size = 0.003
	inscription.modulate = Color(0.66, 0.58, 0.74)
	inscription.outline_size = 0
	inscription.no_depth_test = false
	inscription.position = Vector3(-4.95, 0.44, 45.5) - position
	inscription.rotation.y = PI / 2.0
	add_child(inscription)


# ── the test / prop surface ─────────────────────────────────────────────────────
func view_solved(v: int) -> bool:
	return v >= 0 and v < _view_solved.size() and _view_solved[v]


func views_solved() -> Array:
	return _view_solved.duplicate()


func solved_count() -> int:
	var n := 0
	for s in _view_solved:
		if s:
			n += 1
	return n


func view_count() -> int:
	return VIEWS.size()


func view_feet(v: int) -> Vector3:
	return VIEWS[v]["feet"] as Vector3


func view_aim(v: int) -> Vector3:
	return (_views[v] as Dictionary)["aim"] as Vector3


# ⭐ THE PLACE TELL (2026-09-20 pass 2). True only while the player is standing on this view's
# tile. `can_interact()` is what `player.gd:_is_interactable()` asks before it will show a
# prompt at all, so the prompt IS the "you are in the right place" tell and nothing else in
# the level says it. It deliberately says nothing about alignment.
func gate_open(v: int) -> bool:
	if v < 0 or v >= VIEWS.size() or not is_instance_valid(_player):
		return false
	var feet: Vector3 = VIEWS[v]["feet"]
	var p: Vector3 = _player.global_position
	var near: bool = Vector2(p.x - feet.x, p.z - feet.z).length() <= GATE_RADIUS
	if near and not _gate_logged[v]:
		_gate_logged[v] = true
		_dbg("VOID keystone prompt revealed: %s (within %.1f m of its feet)"
			% [VIEWS[v]["nm"], GATE_RADIUS])
	return near


# `view := 0` keeps every bare `is_aligned()` call working.
func is_aligned(view: int = 0) -> bool:
	if not is_instance_valid(_player) or view >= _views.size():
		return false
	var camera := _player.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return false
	return aligned_from(view, camera.global_position, -camera.global_basis.z)


# The alignment test, taken apart so a probe can sweep it without moving the player.
# ⚠️ ANGULAR, so it is exactly what the eye sees: each seam is one silhouette point rendered
# at two depths, and the check is the angle between the two rays from THIS eye.
func aligned_from(view: int, eye: Vector3, forward: Vector3) -> bool:
	if view < 0 or view >= _views.size():
		return false
	var data: Dictionary = _views[view]
	var spec: Dictionary = VIEWS[view]
	var home: Vector3 = data["eye"]
	if Vector2(eye.x - home.x, eye.z - home.z).length() > float(spec["radius"]):
		return false
	if absf(eye.y - home.y) > float(spec["height"]):
		return false
	var to_shape: Vector3 = (data["aim"] as Vector3) - eye
	if to_shape.length() < 0.05 or forward.normalized().dot(to_shape.normalized()) < float(spec["face"]):
		return false
	var seams: Array = data["seams"]
	var limit: float = spec["seam"]
	var i := 0
	while i < seams.size():
		var a: Vector3 = (seams[i] - eye)
		var b: Vector3 = (seams[i + 1] - eye)
		if a.length() < 0.01 or b.length() < 0.01:
			return false
		if a.normalized().angle_to(b.normalized()) > limit:
			return false
		i += 2
	return true


# The worst seam error in radians from this eye — a measurement, never shown to the player.
func seam_error(view: int, eye: Vector3) -> float:
	if view < 0 or view >= _views.size():
		return INF
	var seams: Array = (_views[view] as Dictionary)["seams"]
	var worst := 0.0
	var i := 0
	while i < seams.size():
		var a: Vector3 = seams[i] - eye
		var b: Vector3 = seams[i + 1] - eye
		if a.length() > 0.01 and b.length() > 0.01:
			worst = maxf(worst, a.normalized().angle_to(b.normalized()))
		i += 2
	return worst


func can_interact() -> bool:
	return not _view_solved[0] and gate_open(0)


func prompt_text() -> String:
	return socket_prompt(0)


func interact() -> void:
	socket_interact(0)


# ── the sockets (2026-09-20 pass 3) ────────────────────────────────────────────────────
#
# ⚠️ THE PROMPT STATES A CONDITION; IT NEVER PROMISES AN ACTION THAT CANNOT HAPPEN. Issue 226
# was a prompt that offered E where E could not succeed. "The socket is empty." is the cradle's
# form — "Something is missing from it." — and E from there does nothing and costs nothing.
# The invitation only appears when the object in your hands is the one this socket takes.
func socket_filled(v: int) -> bool:
	return v >= 0 and v < _socket_filled.size() and _socket_filled[v]


func _carried() -> String:
	if _level == null or not _level.has_method("carried_anchor"):
		return ""
	return String(_level.call("carried_anchor"))


func socket_prompt(v: int) -> String:
	if v < 0 or v >= VIEWS.size():
		return ""
	if _socket_filled[v]:
		return "E — Hold the shape."
	if _carried() == String(VIEWS[v]["anchor"]):
		return "E — Set %s in the socket." % _level.call("carried_label")
	return "The socket is empty."


func socket_interact(v: int) -> void:
	if v < 0 or v >= VIEWS.size() or _view_solved[v]:
		return
	if _socket_filled[v]:
		interact_view(v)
		return
	var want := String(VIEWS[v]["anchor"])
	var held := _carried()
	if held == want:
		place_anchor(v, false)
		return
	if held != "":
		# ⚠️ NO COST. A wrong object is a wrong guess about MEANING, and the level already
		# charges 6 panic for a wrong guess about PLACE. Two prices for two kinds of mistake
		# would make the quest the same tax as the puzzle.
		ScreenText.toast(get_tree(), "It does not belong to this one.", Color(0.72, 0.68, 0.80), 1.6, 30)
		_dbg("VOID socket %s refused %s (it takes the %s)" % [VIEWS[v]["nm"], held, want])
		return
	_dbg("VOID socket %s is empty (E with nothing in hand)" % VIEWS[v]["nm"])


# Seat the anchor: the socket becomes this view's keystone, in the anchor's own silhouette and
# its own family's colour, inside the socket's jaws in the VIEW's tint. `silent` is the
# snapshot-restore path — no sound, no inventory change, no log.
func place_anchor(v: int, silent: bool) -> void:
	if _socket_filled[v]:
		return
	_socket_filled[v] = true
	var spec: Dictionary = VIEWS[v]
	var mount: Node3D = _socket_mounts[v]
	if mount and mount.get_node_or_null("Anchor" + String(spec["anchor"]).capitalize()) == null:
		var art := FRAGMENTS.anchor_mesh(mount, spec["anchor"], spec["family"])
		art.position = Vector3(0, 0.03, 0.03)
	if silent:
		return
	if _level and _level.has_method("consume_anchor"):
		_level.call("consume_anchor", String(spec["anchor"]))
	_knock_at(v)
	_dbg("VOID socket %s filled with the %s" % [spec["nm"], spec["anchor"]])


func sockets_filled() -> Array:
	return _socket_filled.duplicate()


func restore_sockets(placed: Array) -> void:
	for v in range(_socket_filled.size()):
		if v < placed.size() and bool(placed[v]):
			place_anchor(v, true)


func interact_view(v: int) -> void:
	if v < 0 or v >= _views.size() or _view_solved[v]:
		return
	# An empty socket has no keystone to hold, and no wrong-press cost either.
	if not _socket_filled[v]:
		return
	if not is_aligned(v):
		if is_instance_valid(_player) and _player.has_method("add_panic"):
			_player.add_panic(WRONG_PRESS_PANIC)
		_knock_at(v)
		_dbg("VOID keystone %s pressed unaligned (+%.0f panic)" % [VIEWS[v]["nm"], WRONG_PRESS_PANIC])
		return
	_view_solved[v] = true
	_converge(v, false)
	_dbg("VOID keystone %d/3 solved (%s)" % [solved_count(), VIEWS[v]["nm"]])
	if solved_count() >= VIEWS.size():
		_open_seal()


func _knock_at(v: int) -> void:
	if _knock == null or _knock.stream == null:
		return
	var at: Vector3 = (VIEWS[v]["feet"] as Vector3) + (VIEWS[v]["f"] as Vector3).normalized() * 1.1 \
		+ Vector3(0, 1.45, 0)
	_knock.global_position = at
	_knock.play()


func _converge(v: int, instant: bool) -> void:
	var data: Dictionary = _views[v]
	var pieces: Array = data["pieces"]
	var convs: Array = data["convs"]
	if _view_tweens[v]:
		(_view_tweens[v] as Tween).kill()
		_view_tweens[v] = null
	if instant:
		for i in range(pieces.size()):
			(pieces[i] as Node3D).position = convs[i]
		return
	var t := create_tween()
	t.set_parallel(true)
	for i in range(pieces.size()):
		t.tween_property(pieces[i], "position", convs[i], 1.1).set_trans(Tween.TRANS_SINE)
	_view_tweens[v] = t


func _open_seal() -> void:
	solved = true
	reveal_spent = true
	_gate_shape.set_deferred("disabled", true)
	_dbg("VOID morgue seal opened — all three shapes held")
	completed.emit()
	_sequence = create_tween()
	_sequence.set_parallel(true)
	for i in range(_gate_parts.size()):
		_sequence.tween_property(_gate_parts[i], "position:z", -1.6 if i % 2 == 0 else 1.6, 1.1)
	_sequence.chain().tween_interval(0.55)
	_sequence.chain().tween_property(_echo_light, "light_energy", 0.5, 0.35)
	for part in _echo:
		_sequence.parallel().tween_property(part, "rotation", Vector3.ZERO, 1.5).set_trans(Tween.TRANS_SINE)
	_sequence.chain().tween_interval(0.7)
	_sequence.chain().tween_callback(_stone_reply)


func _stone_reply() -> void:
	if _sound.stream:
		_sound.play()


# `views` is the per-viewpoint array `level_3.save_progress()` stores. An old snapshot with
# only `was_solved` still restores correctly: a solved puzzle means all three were held.
func restore_state(was_solved: bool, was_revealed: bool, views: Array = []) -> void:
	if _sequence:
		_sequence.kill()
		_sequence = null
	solved = was_solved
	reveal_spent = was_revealed or solved
	for v in range(_view_solved.size()):
		var done: bool = was_solved
		if v < views.size():
			done = bool(views[v]) or was_solved
		_view_solved[v] = done
		# A held shape implies a seated anchor — an old snapshot that predates the sockets
		# restores a solved view with its keystone present, never an empty socket.
		if done:
			place_anchor(v, true)
		if _view_tweens[v]:
			(_view_tweens[v] as Tween).kill()
			_view_tweens[v] = null
		var data: Dictionary = _views[v]
		var pieces: Array = data["pieces"]
		var source: Array = data["convs"] if done else data["homes"]
		for i in range(pieces.size()):
			(pieces[i] as Node3D).position = source[i]
	solved = solved_count() >= VIEWS.size()
	_gate_shape.set_deferred("disabled", solved)
	for i in range(_gate_parts.size()):
		_gate_parts[i].position.z = (-1.6 if i % 2 == 0 else 1.6) if solved else 0.0
	_echo_light.light_energy = 0.5 if reveal_spent else 0.0
	for i in range(_echo.size()):
		_echo[i].rotation.x = 0.0 if reveal_spent else [-0.4, 0.4, -0.25][i]
	_sound.stop()
