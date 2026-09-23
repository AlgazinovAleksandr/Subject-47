extends Node3D

# ⭐ THE RECURRING ROOM (2026-09-22 pass 6) — the level's second sub-challenge, behind the secret
# door the cradle opens. It was THE HALL OF FRAMES (pass 4) and it kept the same five frames, the
# same answer and the same settle; what changed is the VERB and what a step does to the room.
#
# Five upright doorframes, each holding a small diorama of a thing you have already met, in that
# room's own albedo family (`void_fragments.PALETTE`, the level's memory system):
#
#     shards  Threshold  violet      frame  Ward     bone       table  Archive  rust
#     chairs  LoopIn     verdigris   stair  Hall1    tar
#
# **Walk through them in the order you first met them** — Threshold → Hall1 → Ward → Archive →
# LoopIn. Every step is a hard cut to black with a slam, and you come back standing in the Morgue
# doorway facing the five doors:
#
#   RIGHT — the room is back, one stage STRANGER, and the tone goes up an interval.
#   WRONG — on the fade-in a figure is standing 0.6 m in front of your face for exactly one
#           frame; the room is back at stage 0 and the five doors have been reshuffled.
#
# ⚠️ THE 1.2 s STAND-STILL DWELL IS RETIRED, AND IT WAS A BUG IN THE SHAPE OF A RULE. The 23:47
# playtester made ONE wrong step at 780.8 s, stood in the room for another 105 seconds, and then
# quit with capture #5: *"The mechanics of this secret room is weird — I cannot walk in the doors,
# I think it should be a bug."* They were right. The frames have no colliders, so walking through
# one takes 0.15 s and did nothing; the only way to make anything happen was to stand still inside
# a doorway for 1.2 s, which is not a thing a doorway asks of anybody. A stand-still rule in a
# walk-through space reads as a wall.
#
# ⚠️ THE PAIRWISE OFF-SCREEN RE-SCRAMBLE IS RETIRED WITH IT (Issue 241). It existed because no
# bearing in a 6 x 6 room with five frames in it is free, so "re-arrange while unwatched" was
# unsatisfiable and had to be weakened to "exchange two frames you cannot see, four times". The
# cut to black satisfies the original rule outright: for 0.3 s the player can see NOTHING, so the
# whole permutation moves at once and the level's rule — nothing ever changes while you are
# looking at it — holds in its strongest form. `check_void.gd` controls exactly that: the order
# differs afterwards and no frame changed in any frame where the screen was lit.
#
# ⚠️ ZERO PANIC, NO FAIL STATE, INFINITELY RETRYABLE — the user's ruling, and the reason this is
# legal at all: worst-case brute force is 15 crossings, a floor and not a wall. Nothing in this
# file calls `add_panic()`, and the room carries no `DarkZone` and is outside `DreadFarWing`.
# ⚠️ NO READOUT (SCARY.md §8.2). The stage is FELT, never counted — the lamp, the hum, the
# doubled dioramas, the walls, the lean. Five rungs, not a number on a screen.
# ⚠️ EVERY FIGURE HERE IS A PHOTOGRAPH (P3): no collider, no `ScaryObject`, no AI, no rule.
# `check_void_frames.gd` walks their subtrees every run and asserts exactly that — a sixth
# creature would break SCARY.md §8.3's one-chase-level-in-twelve budget.
# ⚠️ EVERY FRAME IS WALK-THROUGH. `void_fragments.flat_doorframe()` builds meshes only, with no
# collider at all, and the dioramas' own bodies have their shapes disabled and their layer
# zeroed here. Five solid frames in a 6 x 6 room is a room you cannot cross — and since the step
# IS walking through one, a collider would make the puzzle impossible rather than merely hard.

const FRAGMENTS := preload("res://scripts/void_fragments.gd")
const _VOID_VISUAL := preload("res://scripts/void_creature_visual.gd")

# ── the answer: the order the five things are met walking the level from the spawn ──
#
# ⚠️ CORRECTED 2026-09-23 (pass 8). This read `shards, frame, table, chairs, stair` from pass 4
# to pass 7, and it was simply WRONG about the level it describes. The 23:10 playtester
# photographed the room and wrote: *"You see the stairs after the lamps, and here the right
# order is that the stairs are last. If it is indeed a mistake, please check and correct."* It
# was a mistake. `CeilingStair_Hall1` stands at (1.0, 0, 7.0) — in Hall1, the SECOND room on the
# only path out of the Threshold — and the answer had it fifth. A puzzle whose rule is "the
# order you met them" and whose answer is not that order is a puzzle that can only be brute
# forced, which is what the ladder was measuring.
#
# The path, read off `level_3.gd:ROOMS` (which is itself in walk order):
#
#   Threshold (z 1.4, the hung shards) -> Hall1 (z 7, the stair into the ceiling)
#   -> Ward (z 14.5, the folded frame) -> Archive (z 22, the inverted table — a dead end, and
#   the shard in its basin is what makes it mandatory) -> LoopIn (z 16.9, the fused chairs,
#   the mouth of the loop corridor).
#
# ⚠️ IT IS NOT A z-SORT, and a guard that sorted by z would be green on a wrong answer: LoopIn's
# chairs stand at z 16.9, NORTH of the Archive's table at z 22. The Archive is a dead end you
# walk into and back out of before the loop, so the order is the level's ROOM order, not a
# coordinate. `check_void.gd:_answer_order()` asserts exactly that — each diorama's source prop
# is located by position inside `ROOMS`, and `ANSWER` must be that list sorted by ROOMS index.
const ANSWER := ["shards", "stair", "frame", "table", "chairs"]

# `y` and `scale` are MEASURED against the 0.92 x 2.10 m opening each diorama has to read
# inside — a prop scaled by eye either pokes out of the front of the frame or disappears into
# the backdrop 0.95 m behind it.
const DIORAMAS := {
	"shards": {"room": "Threshold", "family": "violet",    "scale": 0.55, "y": 0.42},
	"frame":  {"room": "Ward",      "family": "bone",      "scale": 0.45, "y": 0.55},
	"table":  {"room": "Archive",   "family": "rust",      "scale": 0.50, "y": 0.75},
	"chairs": {"room": "LoopIn",    "family": "verdigris", "scale": 0.45, "y": 0.85},
	"stair":  {"room": "Hall1",     "family": "tar",       "scale": 0.24, "y": 0.60},
}

# ⚠️ TWO COLUMNS, NOT A RING, AND ALL FIVE FACE THE ENTRANCE (2026-09-22). A frame's FRONT is
# its local -z; the step is a crossing from the front, so a frame whose back is turned to the
# door you arrive by is a frame you have to walk round and come back through. Pass 4's east
# column faced -x for a different reason — its drop-out point had to land inside the room, and
# that constraint is gone now that every step puts you at the entrance. Both columns therefore
# face +x, toward (-21.9, 47.5), and every diorama is legible from the stance you arrive in.
# ⚠️ The east column moved x -22.3 -> -23.4 with the flip: facing +x at -22.3 left 1.2 m between
# the frame plane and the east wall face to stand in and see it from. At -23.4 there is 2.3 m.
# ⚠️ The doorway lane (z 46.6..48.4) is still kept clear between the columns: a frame across the
# only doorway is a sealed room, and `check_void_frames` asserts it.
const SLOTS := [
	{"at": Vector3(-25.7, 0.0, 45.4), "yaw": -1.4708},   # -PI/2 + 0.10, faces +x
	{"at": Vector3(-25.7, 0.0, 47.0), "yaw": -1.6508},   # -PI/2 - 0.08
	{"at": Vector3(-25.7, 0.0, 48.6), "yaw": -1.5108},   # -PI/2 + 0.06
	{"at": Vector3(-23.4, 0.0, 44.9), "yaw": -1.6408},   # -PI/2 - 0.07
	{"at": Vector3(-23.4, 0.0, 49.1), "yaw": -1.4508},   # -PI/2 + 0.12
]

# `flat_doorframe()` lies in its own XZ plane; Rx(-PI/2) stands it on end with local +z up, and
# the whole thing then spans y -1.17..+1.17 about its origin. FRAME_LIFT puts the threshold bar
# on the floor: opening y 0.12..2.22, width 0.92 between the jambs' inner faces.
const FRAME_LIFT := 1.17
const DIORAMA_Z := 0.48         # behind the frame plane (local +z is BEHIND; -z is the front)
const BACKDROP_Z := 0.95
const DROP_OUT := 1.0           # metres in front of a frame, for the harnesses' approach stance

# ── the crossing ────────────────────────────────────────────────────────────────
# A step is the player's capsule crossing the frame PLANE (local z = 0) from the FRONT, inside
# the opening. No dwell, no timer, no posture.
#
# ⚠️ A LATCH, NOT A SIGN FLIP, and that is measured rather than careful. The first build tested
# `prev < 0 and now >= 0` on the player's local z, and a player teleported to stand DEAD CENTRE
# in a doorway stepped through it without moving: at local z = 0 the body's own settling jitter
# crosses zero, and "standing still does not step" — the one thing this mechanic replaced a dwell
# to guarantee — was false on its first test. A hysteresis band cannot be satisfied by jitter:
# the slot ARMS only when the player is at least ARM_Z in FRONT of the plane and inside the
# opening, and fires only when they are at least ARM_Z BEHIND it and still inside. Walking round
# the side disarms it (LATERAL_ESCAPE), so a frame cannot be stepped by going around it.
# ⚠️ It is also what makes a teleport safe: nothing is armed until a sample lands in front of a
# frame, so being put down somewhere else in the room can never register a crossing.
# ⚠️ 0.55 m of half-width against a 0.46 m half-opening: a capsule that clips the jamb still
# went through the doorway, and refusing it would reproduce the complaint this replaced.
const CROSS_HALF_W := 0.55
const CROSS_MAX_Y := 2.4        # so a crossing is a crossing of THIS frame, not of its plane
const ARM_Z := 0.25             # how far clear of the plane counts as genuinely in front/behind
const LATERAL_ESCAPE := 0.95    # …and how far to the side counts as having walked round it
# ⚠️ THERE IS NO ARRIVAL COOLDOWN, and its removal is a fix rather than a simplification. Pass
# 4's dwell needed one so the frame you were dropped in front of could not instantly re-fire;
# the latch makes it unnecessary (the teleport disarms every threshold, so nothing can fire
# until the player has walked in front of something again) and makes it HARMFUL: a 0.35 s window
# that disarms every frame swallows the crossing of anyone who reaches a door inside it, and a
# sprinting player covers the 1.5 m to the nearest one in 0.23 s. Measured in the harness first,
# where an instant teleport to the next door lost every second leg.
const CUT_TIME := 0.3           # the black, with `loop_slam` over it
# The Morgue doorway, 0.9 m inside the room, facing -x at the five doors.
const ENTRANCE := Vector3(-21.9, 0.1, 47.5)
const ENTRANCE_YAW := PI / 2.0  # player forward is -basis.z; this points it at -x

# ── the five-stage ladder ───────────────────────────────────────────────────────
# ⚠️ EVERY RUNG IS REVERSIBLE, because a wrong step drops the room back to stage 0 and the
# player has to be able to tell that it did. `apply_stage(0)` restores the lamp, the hum, the
# duplicates, the tilt, the whispers, the wall material and the lean.
#
# ⭐ FRONT-LOADED 2026-09-22 (pass 7, Issue 256). The 02:13 playtester took NINE wrong doors,
# every one of them at stage 0–2, and wrote: *"The visual effects are really good but they start
# appearing after I get something like the third door correct — shall we add more visuals in
# total and start adding them earlier?"* The reason was arithmetic, not taste. This level never
# takes the torch away, so the player walks in carrying `player.gd`'s default 1.6-energy, 18 m,
# shadow-casting flashlight; Godot's omni falloff is `(1 - (d/range)^4)^2 / d`, so on the far
# column of doors (4.31 m from the entrance eye) the TORCH delivers 0.370 and the room's
# shadowless lamp delivers 0.075 at 0.25 and 0.036 at 0.12.
#
#   Stage 1's entire effect used to be that lamp falling 0.25 -> 0.12: 0.039 out of a budget of
#   0.445, an 8.7 % change, delivered across 0.3 s of pure black to a dark-adapting eye.
#
# The lamp is NOT A CHANNEL in this room. It only owns the ceiling and the two side walls — the
# surfaces the torch is never pointed at. So: **every rung now carries something full-screen or
# silhouette-scale INSIDE THE TORCH CONE**, which means albedo (delivered at full strength), the
# camera itself (free of light entirely), or geometry that moves into the frame.
# ⚠️ STILL NO READOUT (SCARY.md §8.2) and still ZERO PANIC. A monotone channel in five notches is
# a counter, so the camera roll is the WORLD's tilt (0.02 -> 0.06, five tiny notches nobody can
# read as a gauge) and the ceiling takes TWO notches, not five. Nothing here calls `add_panic()`.
const LAMP_BASE := 0.25         # stage 0–2 — the room as the secret door opens on it
const LAMP_DIM := 0.12          # stage 3+ — it drops on the rung that gives it a ceiling to sit on
const LAMP_RATE := 1.2
const LAMP_SWING := 0.32        # stage 5, metres of travel on x
const LAMP_SWING_PERIOD := 3.0
const DIORAMA_ROLL := 0.18      # stage 2+
# ⭐ THE ECHO STEPS SIDEWAYS (pass 7, menu item 3). It used to stand 0.35 m BEHIND its diorama at
# 0.8 scale, on the same local x and the same y — apparent size ratio 0.8 * d/(d+0.35) = 0.74 at
# 4.3 m, i.e. a concentric silhouette entirely INSIDE the front copy, lying against a backdrop of
# albedo 0.02. It was invisible by construction. At full scale, 0.28 m to the side and 0.10 m
# back, the two silhouettes peel apart by 3.7 deg = 54 px at 4.3 m against the now-pale backdrop.
const ECHO_BACK := 0.10         # stage 2+ — the second copy, a hair behind the first
const ECHO_SIDE := 0.28         # …and stepped sideways, which is the whole rung
const ECHO_SCALE := 1.0
const LEAN := 0.10              # stage 5 — the doors and the dioramas roll one way
const WHISPERS_STAGE3 := 2
const WHISPERS_STAGE5 := 5
const CORRUPT_TEX := "res://assets/textures/level_4_void/wall_void_corrupt.png"

# ⭐ ITEM 1 — THE BACKDROPS TURN PALE. Five 1.40 x 2.20 m panels, 20 x 30 deg each from the
# entrance, go from luminance 0.007 to 0.20 (a 27x jump) and every memory in the room becomes a
# black cut-out on a lit panel. ⚠️ ALBEDO ONLY — `emission_enabled` stays false everywhere in
# this file. SCARY.md §8.8's own prescribed answer to "make it stand out in the dark" is
# silhouette, and this project has no glow, no fog and no tonemapping, so an emissive panel would
# clamp to a flat white rectangle (Issue 21).
const BACKDROP_DARK := Color(0.02, 0.018, 0.026)
const BACKDROP_PALE := Color(0.55, 0.53, 0.48)

# ⭐ ITEM 2 — THE ROOM IS NOT LEVEL. A HELD camera roll, not a shake: five doorframes and two
# wall corners all tip the same way against a room full of true verticals. It costs no light at
# all, which is why it is the one channel with five legible rungs.
# ⚠️ WRITTEN ON THE CAMERA NODE by this level, never in `player.gd`: `_rotate_camera()` writes
# only `camera.rotation.x`, so z is free. ⚠️ AND RE-APPLIED ON EVERY ARRIVAL, because
# `player.gd:jolt_camera()` tweens `camera.rotation:z` back to 0.0 and both of this level's
# one-shot figures jolt. The settle zeroes it.
const ROLL := [0.0, 0.02, 0.02, 0.04, 0.04, 0.06]

# ⭐ ITEM 4 — THE CEILING COMES DOWN, AND BRINGS THE LAMP WITH IT. ⚠️ A NEW SLAB IN EMPTY SPACE,
# never a move of `FrameHall_Ceiling` (SCARY.md P11's non-negotiable: add a node, never resize a
# room in place). 5.6 x 5.6 inside a 6 x 6 room leaves 0.10 m to every wall box's inner face, so
# `check_wall_overlap` has nothing to overlap. Two notches — five discrete heights would be a
# countable progress channel, which is §8.2. The ceiling is the ONE surface the room lamp owns
# (0.24 directly above it against 0.036 on the dioramas), so bringing it down is also what
# finally makes the lamp's own drop something you can watch happen.
const SLAB_SIZE := Vector3(5.6, 0.10, 5.6)
const SLAB_Y := [3.0, 3.0, 3.0, 2.7, 2.7, 2.2]

# ⭐ ITEM 6 — THE DIORAMAS OUTGROW THEIR FRAMES. The memory in each doorway grows until it is
# jammed in the opening. ⚠️ GROWING, never distorting: the dioramas ARE the answer, so a rung
# that made one unidentifiable would be a rung that broke the puzzle. A bigger memory is an
# easier memory to read.
const GROW := [1.0, 1.0, 1.0, 1.0, 1.25, 1.5]

# ⭐ ITEM 10 — THE ROOM CHANGES COLOUR, two notches (stages 2 and 4), energy untouched. It is
# ~8 % of the light on the doors and most of the light on the ceiling and the two side walls,
# i.e. exactly the surfaces item 4 is bringing into the frame. It stays after the settle.
const LAMP_TINT := [Color(0.72, 0.58, 1.00), Color(0.72, 0.58, 1.00),
	Color(0.66, 0.47, 1.00), Color(0.66, 0.47, 1.00),
	Color(0.57, 0.33, 1.00), Color(0.57, 0.33, 1.00)]

# ⭐ ITEM 7/8 — THE SIXTH DOOR AND THE WATCHER IN IT, stage 4, ONCE. One extra door is an
# anomaly; a door per rung is an anomaly COUNTER, which is Issue 34's failure in world-space
# clothing. It pays off the Threshold note read five rooms earlier — *"Count the doors. The
# number will not stay the same."*
# ⚠️ IT IS A VISUAL AGAINST THE FAR WALL, NEVER AN OPENING. The wall box spans x -27.1..-26.9;
# the shell's own geometry runs x -26.85..-26.75, i.e. 0.05 m clear of the wall's inner face and
# wholly inside the room. Nothing is cut, nothing is plugged, and `check_shell_sealed` never sees
# a hole. It is also NOT appended to `_units`, so `_tick_thresholds()` can never arm on it.
# ⚠️ THE WATCHER IS A PHOTOGRAPH (SCARY.md P3): no collider, no `ScaryObject`, no AI, no rule, no
# panic, and it never moves. `check_void_frames.gd` walks its subtree every run.
const SIXTH_AT := Vector3(-26.85, 0.0, 47.0)
const SIXTH_YAW := -PI / 2.0    # front (local -z) points +x, at the entrance
# ⚠️ -0.45, NOT -0.18. MEASURED: `VoidCreatureVisual` is a lean-forward mid-stride REACH with
# 1.28 m arms, so its own bounding box runs ~0.79 m deep about its origin. At -0.18 the figure's
# BACK sat at x -26.971 — 0.071 m inside the far wall's box, which is a mesh buried in a wall.
# At -0.45 the whole thing is inside the room with 0.10 m to spare, and at 4.95 m from the
# entrance a 0.45 m stand-off is 0.06 deg of parallax: it still reads as standing in the door.
const SIXTH_FIGURE_Z := -0.45

# ⭐ ITEM 9 — A MEMORY STANDS IN THE ROOM AT 1:1, stage 5: the diorama of the LAST right door's
# room, out of its frame, between you and the doors. Geometry only, no collider, freed at the
# settle. ⚠️ `ceiling_y` 2.05 rather than the room's 3.3: at stage 5 the false ceiling is at
# 2.2 and a flight that climbed past it would put a 6 cm tread 7 mm under a 5.6 m slab, which is
# this project's most common bug class in miniature. The flight now ENDS at the ceiling that came
# down. ⚠️ Placed so the player's own 0.4 m capsule at the entrance is 0.47 m clear of it, and
# the east column's shells 0.25 m clear on the other side.
const MEMORY_ID := "stair"
# ⚠️ MEASURED, twice. `ceiling_stair()`'s treads span 3.10 m and its broken stringers push the
# real footprint to 3.40 m, against a 5.80 m room with the entrance stance at z 47.5 — so a
# 1:1 flight CANNOT be both north of the z = 44.1 wall face and south of the entrance line.
# The first placement (-22.7, 45.8) put a stringer corner at z 44.0999, i.e. 0.1 mm inside the
# wall box: this project's most common bug class, found by the guard rather than by eye. This
# one clears the wall by 0.15 m, the east column's shells by 0.10 m, and the player's own 0.4 m
# capsule at the entrance by 0.17 m — and it crosses z 47.5 only 0.5 m west of where they stand.
const MEMORY_AT := Vector3(-22.85, 0.0, 45.95)
const MEMORY_CEIL := 2.05

# ⭐ ITEM 11 — ONE WHISPER BEHIND YOUR HEAD, stage 1. The room's only unwatched bearing is the
# one at your back and the arrival stance guarantees it. In the Morgue doorway, 0.9 m behind the
# entrance eye. ⚠️ GAIN FROM THE ARITHMETIC, not from a plausible number: the five frame whispers
# run -24.0 dB / unit 4.0 at 2.2-4.3 m, i.e. about -22 dB effective at the ear. At 0.9 m with
# unit 1.0 the distance gain is +0.9 dB, so -23.0 dB lands at -22.1 — the same whisper, from
# behind. It also falls away fast (-32.5 dB at 3 m), which is right: it marks the one bearing
# the room never lets you keep, and only from the stance it is about.
const BACK_WHISPER_AT := Vector3(-21.0, 1.45, 47.5)
const BACK_WHISPER_DB := -23.0
const BACK_WHISPER_UNIT := 1.0

const SETTLE_TIME := 1.5
const HUSH := 1.0
const HUSH_DB := -60.0
# One interval per stage. `frame_tone` is one sample; `pitch_scale` is what rises.
const TONE_PITCH := [1.0, 1.125, 1.25, 1.5, 2.0]
const SETTLE_X := -24.0
const SETTLE_Z := [45.2, 46.15, 47.1, 48.05, 49.0]
const ARMS_LENGTH := 0.6        # the wrong step's figure, in front of the camera
const ARMS_EYE_DROP := 0.40     # so the 2.05 m mask lands on the 1.65 m eye line

signal solved

var level: Node3D = null
var note: Node = null

var _order: Array = []          # slot index -> diorama id
var _units: Array = []          # slot index -> Node3D
var _stages: Array = []         # slot index -> the diorama root (or null once settled)
var _echoes: Array = []         # slot index -> the stage-2 duplicate behind it (or null)
var _whispers: Array = []       # slot index -> AudioStreamPlayer3D (or null)
var _armed: Array = []          # slot index -> the player has been ARM_Z in front of this one
var _progress := 0              # = the stage. 0..5
var _wrong := 0
var _solved := false
var _seed := 0
var _stepping := false
var _crossings := 0
var _cuts := 0
# ⚠️ A MEMBER, NOT A LAMBDA CAPTURE. GDScript lambdas capture by VALUE, so a `var` assigned
# inside the Callable that runs under the black would never be seen by the coroutine that
# resumes after it — the stage-3 blink would simply never fire and nothing would say so.
var _arrived_three := false
var _rng := RandomNumberGenerator.new()
var _lamp: OmniLight3D = null
var _lamp_target := LAMP_BASE
var _lamp_home := Vector3.ZERO
var _swinging := false
var _swing_t := 0.0
var _hush_for := 0.0
var _watcher: Node3D = null      # the wrong step's figure, at arm's length
var _watcher_ttl := 0
var _watcher_frames := 0
var _door_figure: Node3D = null  # stage 3's figure, standing in a non-answer doorway
var _door_ttl := 0
var _door_frames := 0
var _hum: AudioStreamPlayer3D = null
var _walls: Array = []           # the room's own CSG wall boxes
var _wall_mats: Array = []       # …and the material each one was built with
var _corrupt_mat: Material = null
var _walls_corrupt := false
# ⭐ pass 7. The floor is found by the SAME geometric rule as the walls and kept beside them:
# it is the biggest torch-lit surface in the room and the exact inverse of the walls stage 4
# was spending itself on (which are ~85 % occluded by the frames from the entrance).
var _floor: CSGBox3D = null
var _floor_mat: Material = null
var _corrupt_floor_mat: Material = null
var _floor_corrupt := false
var _backdrops: Array = []       # slot index -> the backdrop quad's StandardMaterial3D
var _slab: MeshInstance3D = null # the false ceiling
var _lamp_base_y := 0.0
var _sixth: Node3D = null        # the sixth doorway, flush in the far wall
var _sixth_figure: Node3D = null # …and the thing standing in it
var _memory: Node3D = null       # the last memory, out of its frame at 1:1
var _whisper_back: AudioStreamPlayer3D = null
var _tone: AudioStreamPlayer3D = null
var _slam: AudioStreamPlayer3D = null
var _drop: AudioStreamPlayer3D = null
var _settle_sfx: AudioStreamPlayer3D = null


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


# ── build ───────────────────────────────────────────────────────────────────────
func build(owner_level: Node3D, lamp: OmniLight3D, seed_value: int) -> void:
	level = owner_level
	_lamp = lamp
	if _lamp:
		_lamp_home = _lamp.position
		_lamp_base_y = _lamp.position.y
	_seed = seed_value
	_build_audio()
	for i in range(SLOTS.size()):
		var unit := Node3D.new()
		unit.name = "Frame%d" % i
		unit.position = SLOTS[i]["at"]
		unit.rotation.y = float(SLOTS[i]["yaw"])
		add_child(unit)
		var shell: Node3D = FRAGMENTS.flat_doorframe(unit, Vector3(0, FRAME_LIFT, 0), 0.0,
			"Shell", "violet")
		shell.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
		# ⚠️ The flat frame's own black quad is the thing a diorama has to be SEEN through, so
		# it goes; a bigger backdrop stands 0.95 m behind instead. Freed, not hidden: a hidden
		# opaque quad in the opening is a diorama nobody can photograph.
		var black := shell.get_node_or_null("FlatDoorwayBlack")
		if black:
			shell.remove_child(black)
			black.queue_free()
		_backdrop(unit)
		_units.append(unit)
		_stages.append(null)
		_echoes.append(null)
		_armed.append(false)
		_whispers.append(_emitter("Whisper%d" % i, "stalker_whisper", -24.0, 4.0, true))
	for i in range(_whispers.size()):
		var w: AudioStreamPlayer3D = _whispers[i]
		if w:
			w.position = (_units[i] as Node3D).position + Vector3(0, 1.2, 0)
	_find_room_walls()
	_build_slab()
	_build_sixth_door()
	_build_memory()
	apply_scramble(_seed)
	apply_stage(0)
	if _lamp:
		_lamp.light_energy = LAMP_BASE


# ⭐ ITEM 4's slab. Built once, in empty space under the real ceiling, and only ever MOVED on y.
# ⚠️ NOT a CSGBox3D: this is scenery, not a room surface, and a CSG box here would join the
# `check_wall_overlap` CSG pass and the level's own collision. A `MeshInstance3D` with no body
# is what "a ceiling that is not the ceiling" should be — you can see it and it does not exist.
func _build_slab() -> void:
	_slab = MeshInstance3D.new()
	_slab.name = "FalseCeiling"
	var bm := BoxMesh.new()
	bm.size = SLAB_SIZE
	_slab.mesh = bm
	# The room's own ceiling material, so the thing that comes down is the ceiling and not a
	# new object. Its albedo is dark, which is what lets the lamp read ON it.
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.04, 0.07)
	m.roughness = 0.95
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.28, 0.28, 0.28)
	if ResourceLoader.exists("res://assets/textures/level_4_void/wall_void.png"):
		var t: Texture2D = load("res://assets/textures/level_4_void/wall_void.png")
		if t:
			m.albedo_texture = t
	_slab.set_surface_override_material(0, m)
	_slab.position = Vector3(-24.0, float(SLAB_Y[0]), 47.0)
	add_child(_slab)


func _build_sixth_door() -> void:
	_sixth = Node3D.new()
	_sixth.name = "SixthDoor"
	_sixth.position = SIXTH_AT
	_sixth.rotation.y = SIXTH_YAW
	add_child(_sixth)
	var shell: Node3D = FRAGMENTS.flat_doorframe(_sixth, Vector3(0, FRAME_LIFT, 0), 0.0,
		"Shell", "violet")
	shell.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	# ⚠️ THE BLACK QUAD STAYS HERE, unlike the five answer frames. Those had theirs removed
	# because a diorama has to be SEEN through the opening; this one has no diorama and the
	# black IS the effect — a door with nothing behind it, 0.085 m clear of the wall face.
	_sixth_figure = _VOID_VISUAL.new() as Node3D
	_sixth_figure.name = "SixthDoorWatcher"
	_sixth.add_child(_sixth_figure)
	_sixth_figure.position = Vector3(0, 0, SIXTH_FIGURE_Z)
	_sixth_figure.rotation.y = PI        # +Z is its forward; the viewer stands at local -z
	_strip_collision(_sixth_figure)
	_sixth.visible = false


func _build_memory() -> void:
	_memory = Node3D.new()
	_memory.name = "MemoryAtFullSize"
	add_child(_memory)
	var built: Node = FRAGMENTS.ceiling_stair(_memory, MEMORY_AT, 0.0, MEMORY_CEIL,
		"Memory_" + MEMORY_ID, String(DIORAMAS[MEMORY_ID]["family"]))
	# ⚠️ REMOVED, NOT DISABLED. `_strip_collision()` is right for a diorama inside a frame — it
	# zeroes the layer and disables the shape, which is enough to make it invisible to every
	# query. This one is a 3.4 m prop standing in the middle of the floor at eye height and the
	# claim about it is "geometry only", so the shapes go out of the tree entirely: a disabled
	# shape is one property away from being a 3.4 m wall in the room the puzzle is solved in.
	_strip_collision(built)
	_remove_shapes(built)
	_memory.visible = false


func _backdrop(unit: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Backdrop"
	var qm := QuadMesh.new()
	# ⚠️ 2.20 tall centred at y 1.20, i.e. y 0.10..2.30. A 2.50 tall quad dips below y 0 and
	# lands INSIDE the floor slab, which check_wall_overlap's flat-prop pass reports (and is
	# right to: a quad buried in a slab is the coincident-surface bug in its other direction).
	qm.size = Vector2(1.40, 2.20)
	mi.mesh = qm
	var black := StandardMaterial3D.new()
	black.albedo_color = BACKDROP_DARK
	black.roughness = 1.0
	mi.set_surface_override_material(0, black)
	mi.position = Vector3(0, 1.20, BACKDROP_Z)
	mi.rotation.y = PI          # a QuadMesh faces +z; the viewer is at local -z
	unit.add_child(mi)
	# ⭐ ITEM 1: the material is KEPT, so `apply_stage()` can write `albedo_color` on it. The
	# quads themselves are freed by `_drop_stage()` at the settle, which is why this array is
	# only ever read through `is_instance_valid()`.
	_backdrops.append(black)


func _build_audio() -> void:
	# ⚠️ Gains from the FILES' measured RMS, never from plausible numbers:
	#   frame_tone   -10.89 dBFS -> -7.5 dB / unit 4.0, heard as the room comes back
	#   loop_slam    -17.74      -> -6.0 dB / unit 3.0. The corridor's copy runs -3.0 / unit 14
	#                because it is heard from 15-30 m; in a 6 m room that is a different sound.
	#   frame_drop   -16.17      -> -10.5 / unit 4.0: it plays at zero distance from the player
	#                who has just been put back down at the entrance.
	#   frame_settle -13.01      -> -5.5 / unit 6.0, and it has to fill the room once.
	#   room_hum      -6.55      -> -26.0 / unit 5.0. It is the LOUDEST file this room owns and
	#                the only one that never stops, so it gets by far the quietest gain: a bed
	#                under a 6 m room, not an event (measured 4.000 s, peak -1.01 dBFS).
	#   stalker_whisper -19.2    -> -24.0 / unit 4.0, under creature_stalker's own -38..-8 stare
	#                window: these are doors murmuring, not a creature looking at you.
	_tone = _emitter("FrameTone", "frame_tone", -7.5, 4.0)
	_slam = _emitter("FrameSlam", "loop_slam", -6.0, 3.0)
	_drop = _emitter("FrameDrop", "frame_drop", -10.5, 4.0)
	_settle_sfx = _emitter("FrameSettle", "frame_settle", -5.5, 6.0)
	if _settle_sfx:
		_settle_sfx.position = Vector3(SETTLE_X, 1.4, 47.0)
	_hum = _emitter("RoomHum", "room_hum", -26.0, 5.0, true)
	if _hum:
		_hum.position = Vector3(-24.0, 2.4, 47.0)
	# ⭐ ITEM 11 (pass 7): the same whisper, in the doorway at the back of your head. See
	# BACK_WHISPER_DB for the arithmetic that makes it the same loudness as the frames' five.
	_whisper_back = _emitter("WhisperBack", "stalker_whisper", BACK_WHISPER_DB,
		BACK_WHISPER_UNIT, true)
	if _whisper_back:
		_whisper_back.position = BACK_WHISPER_AT


# ⚠️ `loop` re-triggers from `finished`, never from the .import: every `.wav.import` in this
# project is `loop_mode=0` (the scrape's idiom, `creature_stalker.gd:_tick_whisper`). Setting it
# in code is also what stops a re-import from silently regressing it (ambient_void's lesson).
func _emitter(nm: String, base: String, db: float, unit: float,
		loop: bool = false) -> AudioStreamPlayer3D:
	var s := GameState.load_audio(base)
	if s == null:
		return null
	var pl := AudioStreamPlayer3D.new()
	pl.name = nm
	pl.stream = s
	pl.volume_db = db
	pl.unit_size = unit
	pl.bus = AudioBuses.AMBIENCE
	add_child(pl)
	if loop:
		pl.finished.connect(pl.play)
	return pl


# ⚠️ FOUND BY GEOMETRY, NOT BY NAME, and that is measured rather than cautious: `RoomBuilder`
# calls EVERY wall box "Wall", and Godot 4 does not suffix a duplicate name — it replaces it
# with the class-based auto name (Issue 237). A name filter finds exactly one wall in the level.
# The honest key is the geometry: a wall box is ROOM_H tall (floors and ceilings are T = 0.2),
# and this room's own walls are the ones whose whole extent lies inside its rect.
# ⚠️ THE x = -21 PLANE IS DELIBERATELY EXCLUDED. It is the MORGUE's wall — the Morgue reaches
# z 42.5..52.5 there and builds first, so that box is 10 m of somebody else's room and
# corrupting it would change a wall the player sees from the Morgue. Three boxes: x -27,
# z 44 and z 50. `check_void` asserts the count, so a later footprint edit cannot silently
# drop the stage-4 rung to one wall.
# ⭐ AND THE FLOOR, pass 7 (menu item 5), found by the SAME geometric rule — a slab is
# `RoomBuilder.T` thick and sits BELOW y 0, a wall is ROOM_H tall. `"%s_Floor"` happens to be a
# unique node name here, but naming is what Issue 237 is about and geometry is the honest key.
# ⚠️ It is the biggest single torch-lit surface in the room: the torch (30 deg half-angle from
# eye 1.65) first strikes the floor at 2.86 m and lights everything from there to the far wall
# at 0.31-0.37, unoccluded, filling the bottom third of the frame — the exact inverse of the
# three walls, which are 85 % hidden behind the frames from the only stance this room has.
func _find_room_walls() -> void:
	_walls = []
	_wall_mats = []
	_floor = null
	_floor_mat = null
	if level == null:
		return
	var rooms := level.get_node_or_null("Rooms")
	if rooms == null:
		return
	var rect := Rect2(Vector2(-27.0, 44.0), Vector2(6.0, 6.0)).grow(0.15)
	for c in rooms.get_children():
		if not (c is CSGBox3D):
			continue
		var b := c as CSGBox3D
		var lo := Vector2(b.position.x - b.size.x * 0.5, b.position.z - b.size.z * 0.5)
		var hi := Vector2(b.position.x + b.size.x * 0.5, b.position.z + b.size.z * 0.5)
		if not (rect.has_point(lo) and rect.has_point(hi)):
			continue
		if absf(b.size.y - 3.3) < 0.01:
			_walls.append(b)
			_wall_mats.append(b.material)
		elif b.size.y < 0.4 and b.position.y < 0.0:
			_floor = b
			_floor_mat = b.material


func _corrupt_material() -> Material:
	if _corrupt_mat != null:
		return _corrupt_mat
	_corrupt_mat = _corrupt_from(_wall_mats[0] if not _wall_mats.is_empty() else null)
	return _corrupt_mat


# ⚠️ A DUPLICATE, and the ORIGINAL IS KEPT. Every rung has to be reversible, because a wrong
# step drops the room to stage 0 and the player must be able to tell that it did; writing the
# corrupt texture onto the shared wall/floor material instance would corrupt the whole level.
func _corrupt_from(src: Material) -> Material:
	var m: StandardMaterial3D
	if src is StandardMaterial3D:
		m = (src as StandardMaterial3D).duplicate()
	else:
		m = StandardMaterial3D.new()
		m.roughness = 0.9
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.28, -0.28, 0.28)
	if ResourceLoader.exists(CORRUPT_TEX):
		var t: Texture2D = load(CORRUPT_TEX)
		if t:
			m.albedo_texture = t
	return m


func _corrupt_floor_material() -> Material:
	if _corrupt_floor_mat != null:
		return _corrupt_floor_mat
	_corrupt_floor_mat = _corrupt_from(_floor_mat)
	return _corrupt_floor_mat


# ── the scramble ────────────────────────────────────────────────────────────────
#
# Deterministic from `seed_value`, so a snapshot restore, a reshuffle and a seeded harness run
# all land in the same room. The permutation is SAVED as well as the seed, because the level's
# attempt counter (which seeds the first one) moves under a restart and the arrangement a player
# walked back out of must be the arrangement they walk back into.
func apply_scramble(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ids: Array = ANSWER.duplicate()
	var tries := 0
	while true:
		for i in range(ids.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: Variant = ids[i]
			ids[i] = ids[j]
			ids[j] = tmp
		tries += 1
		# A reshuffle that changes nothing is not a reshuffle; it reads as a dead trigger.
		if _order.is_empty() or ids != _order or tries >= 8:
			break
	_set_order(ids)


func _set_order(ids: Array) -> void:
	_order = ids.duplicate()
	for i in range(_units.size()):
		_rebuild_diorama(i)


func _rebuild_diorama(i: int) -> void:
	for arr in [_stages, _echoes]:
		if arr[i] != null and is_instance_valid(arr[i]):
			_units[i].remove_child(arr[i])
			arr[i].queue_free()
		arr[i] = null
	var id := String(_order[i])
	_stages[i] = _build_diorama(_units[i], id, 1.0, 0.0, DIORAMA_Z, "Diorama_")
	# ⭐ STAGE 2: a second copy of the same memory at FULL SIZE, stepped 0.28 m SIDEWAYS and only
	# 0.10 m back, so the frame reads as a double exposure rather than as perspective. It used to
	# stand directly behind at 0.8 scale, where it was geometrically inside the front copy's own
	# silhouette (0.74x apparent size on the same axis) and could never have been seen.
	_echoes[i] = _build_diorama(_units[i], id, ECHO_SCALE, ECHO_SIDE, DIORAMA_Z + ECHO_BACK,
		"Echo_")
	_echoes[i].visible = _progress >= 2
	_stages[i].rotation.z = DIORAMA_ROLL if _progress >= 2 else 0.0
	_echoes[i].rotation.z = -DIORAMA_ROLL if _progress >= 2 else 0.0
	# ⚠️ AFTER the rebuild, always: a scramble re-creates both copies at scale 1.0 and the room
	# may already be at stage 4 or 5, where they are 1.25x or 1.5x. A rung that a reshuffle
	# quietly undoes is a rung the player watches disappear.
	_apply_diorama_scale(i)


func _build_diorama(unit: Node3D, id: String, scale_mult: float, x: float, z: float,
		prefix: String) -> Node3D:
	var spec: Dictionary = DIORAMAS[id]
	var stage := Node3D.new()
	stage.name = prefix + id
	# ⚠️ The SAME height, not a scaled one: a smaller copy at the same eye level reads as the
	# same object further back, which is the illusion. Scaled down it reads as a child's toy.
	stage.position = Vector3(x, float(spec["y"]), z)
	stage.scale = Vector3.ONE * float(spec["scale"]) * scale_mult
	unit.add_child(stage)
	var fam := String(spec["family"])
	var built: Node = null
	match id:
		"shards":
			built = FRAGMENTS.hung_shards(stage, Vector3.ZERO, "MemShards", 5, 47, 3.3, fam)
		"frame":
			built = FRAGMENTS.folded_frame(stage, Vector3.ZERO, 0.35, "MemFrame", fam)
		"table":
			built = FRAGMENTS.inverted_table(stage, Vector3.ZERO, 0.30, "MemTable", null, fam)
		"chairs":
			built = FRAGMENTS.fused_chairs(stage, Vector3.ZERO, 0.0, "MemChairs", fam)
		_:
			built = FRAGMENTS.ceiling_stair(stage, Vector3.ZERO, 0.0, 3.3, "MemStair", fam)
	_strip_collision(built)
	return stage


# ⚠️ A DIORAMA IS A PICTURE, NOT FURNITURE. Four of the five builders return a layer-1
# StaticBody3D with a real collision box; at 0.45 scale inside a frame the player has to WALK
# THROUGH, those are five invisible kerbs in a 6 x 6 room and the puzzle becomes unsolvable.
# Layer AND shapes, because a shape left enabled on a layer-0 body still answers
# `intersect_shape` queries from anything that asks by mask.
func _strip_collision(n: Node) -> void:
	if n is CollisionObject3D:
		(n as CollisionObject3D).collision_layer = 0
		(n as CollisionObject3D).collision_mask = 0
	if n is CollisionShape3D:
		(n as CollisionShape3D).disabled = true
	for c in n.get_children():
		_strip_collision(c)


func _remove_shapes(n: Node) -> void:
	for c in n.get_children():
		_remove_shapes(c)
	if n is CollisionShape3D:
		n.get_parent().remove_child(n)
		n.queue_free()


# ── the ladder ──────────────────────────────────────────────────────────────────
#
# ⚠️ ZERO PANIC ON EVERY RUNG. Nothing here calls `add_panic()`; the room is outside
# `DreadFarWing` and both `DarkZone`s (Issue 18 — never tax the posture a puzzle requires, and
# this one asks you to walk about a dark room reading small sculptures).
# `arriving` is true only for a step the player just took, and gates the two beats that are
# EVENTS rather than states: the eyelid blink and the figure in a doorway. A snapshot restore
# passes false, so walking back into the level re-applies the world without replaying anything
# (the Ward frame's rule).
func apply_stage(n: int, arriving: bool = false) -> void:
	_progress = clampi(n, 0, ANSWER.size())
	var s := _progress
	# ⭐ THE LAMP DROP MOVED TO STAGE 3 (pass 7). At stage 1 it was 8.7 % of the light on the
	# thing the player is facing, spent inside a 0.3 s cut to black. At stage 3 it arrives with a
	# ceiling 2.7 m above the eye — the one surface the lamp owns — so the drop is finally
	# something that can be watched happening.
	_lamp_target = LAMP_BASE if s < 3 else LAMP_DIM
	_swinging = s >= 5
	_lamp_home.y = _lamp_base_y + (float(SLAB_Y[s]) - float(SLAB_Y[0]))
	if _lamp and is_instance_valid(_lamp):
		if not _swinging:
			_lamp.position = _lamp_home
		else:
			_lamp.position.y = _lamp_home.y
		_lamp.light_color = LAMP_TINT[s]
	if _slab and is_instance_valid(_slab):
		_slab.position.y = float(SLAB_Y[s])
	if _hum:
		if s >= 1 and not _hum.playing:
			_hum.play()
		elif s < 1 and _hum.playing:
			_hum.stop()
	for m in _backdrops:
		if m is StandardMaterial3D:
			(m as StandardMaterial3D).albedo_color = BACKDROP_DARK if s < 1 else BACKDROP_PALE
	if _whisper_back:
		if s >= 1 and not _whisper_back.playing:
			_whisper_back.play()
		elif s < 1 and _whisper_back.playing:
			_whisper_back.stop()
	for i in range(_units.size()):
		if _echoes[i] != null and is_instance_valid(_echoes[i]):
			_echoes[i].visible = s >= 2
			_echoes[i].rotation.z = -DIORAMA_ROLL if s >= 2 else 0.0
		if _stages[i] != null and is_instance_valid(_stages[i]):
			_stages[i].rotation.z = DIORAMA_ROLL if s >= 2 else 0.0
		(_units[i] as Node3D).rotation.z = LEAN if s >= 5 else 0.0
		_apply_diorama_scale(i)
	var want_whispers: int = 0
	if s >= 5:
		want_whispers = WHISPERS_STAGE5
	elif s >= 3:
		want_whispers = WHISPERS_STAGE3
	for i in range(_whispers.size()):
		var w: AudioStreamPlayer3D = _whispers[i]
		if w == null:
			continue
		if i < want_whispers and not w.playing:
			w.play()
		elif i >= want_whispers and w.playing:
			w.stop()
	_set_walls_corrupt(s >= 4)
	_set_floor_corrupt(s >= 2)
	if _sixth and is_instance_valid(_sixth):
		_sixth.visible = s >= 4
	if _memory and is_instance_valid(_memory):
		_memory.visible = s >= 5
	_apply_roll()
	_dbg("VOID room stage %d" % s)


# ⚠️ WRITTEN ON EVERY STAGE CHANGE, WHICH IS EVERY ARRIVAL. Both branches of `_inside_black()`
# call `apply_stage()` in the same breath as `_teleport_to_entrance()`, so the roll is re-applied
# each time the player is put back down — which it has to be, because `player.gd:jolt_camera()`
# tweens `camera.rotation:z` back to 0.0 and this level jolts twice.
# ⚠️ THE LEVEL WRITES THE CAMERA NODE; `player.gd` is not touched. `_rotate_camera()` writes only
# `camera.rotation.x` (through `_pitch`), so z is nobody else's.
# ⚠️ THROUGH THE LEVEL, NOT STRAIGHT ONTO THE CAMERA. `level_3.gd:_tick_shake()` is the other
# writer of `camera.rotation.z` — it fires a 0.4 s sine every 20-60 s anywhere outside the tile
# hall — and a roll written here directly was simply erased by the next shake and left at the
# shake's last sample afterwards. `set_camera_roll()` makes the level the one owner: the shake
# now displaces this value instead of replacing it.
func _apply_roll() -> void:
	var v: float = float(ROLL[clampi(_progress, 0, ROLL.size() - 1)])
	if level != null and is_instance_valid(level) and level.has_method("set_camera_roll"):
		level.call("set_camera_roll", v)
		return
	var cam := _camera()
	if cam:
		cam.rotation.z = v


# ⚠️ INDEXED, NOT `arr == _stages`. GDScript's `==` on two Arrays is an ELEMENT-WISE compare,
# not an identity test, so `for arr in [_stages, _echoes]` + `arr == _stages` would have given
# the echo the front copy's multiplier on any frame where the two arrays happened to be equal.
func _apply_diorama_scale(i: int) -> void:
	if i >= _order.size():
		return
	var id := String(_order[i])
	if not DIORAMAS.has(id):
		return
	var base: float = float((DIORAMAS[id] as Dictionary)["scale"])
	var g: float = float(GROW[clampi(_progress, 0, GROW.size() - 1)])
	if _stages[i] != null and is_instance_valid(_stages[i]):
		(_stages[i] as Node3D).scale = Vector3.ONE * base * g
	if _echoes[i] != null and is_instance_valid(_echoes[i]):
		(_echoes[i] as Node3D).scale = Vector3.ONE * base * ECHO_SCALE * g


func _set_walls_corrupt(on: bool) -> void:
	if on == _walls_corrupt:
		return
	_walls_corrupt = on
	for i in range(_walls.size()):
		var b: CSGBox3D = _walls[i]
		if not is_instance_valid(b):
			continue
		b.material = _corrupt_material() if on else _wall_mats[i]


func _set_floor_corrupt(on: bool) -> void:
	if on == _floor_corrupt or _floor == null or not is_instance_valid(_floor):
		return
	_floor_corrupt = on
	_floor.material = _corrupt_floor_material() if on else _floor_mat


# ⭐ STAGE 3's ARRIVAL: the eyelid blink, and a figure standing in a doorway that is NOT the one
# the answer wants next — so the one door you must not take is the one with something in it.
# ⚠️ `StareDirector.blink_now()` is called, never re-implemented: one owner per effect, and the
# director carries the `_busy` flag that stops two blinks fighting over the same lids.
func _stage_three_arrival(with_blink: bool = true) -> void:
	var p := _player()
	if p == null:
		return
	var director := level.get_node_or_null("StareDirector") if level else null
	if with_blink and director and director.has_method("blink_now"):
		director.call("blink_now", p)
	var want := String(ANSWER[mini(_progress, ANSWER.size() - 1)])
	var slot := -1
	for i in range(_order.size()):
		if String(_order[i]) != want:
			slot = i
			break
	if slot < 0:
		return
	_clear_door_figure()
	_door_figure = _VOID_VISUAL.new() as Node3D
	_door_figure.name = "DoorwayFigure"
	(_units[slot] as Node3D).add_child(_door_figure)
	_door_figure.position = Vector3(0, 0, 0.10)
	_door_figure.rotation.y = PI          # +Z is its forward; the viewer stands at local -z
	_door_figure.visible = true
	_door_ttl = 1
	_dbg("VOID room stage 3 — a figure stood in the %s doorway for one frame"
		% String(_order[slot]))


func _clear_door_figure() -> void:
	if _door_figure and is_instance_valid(_door_figure):
		_door_figure.get_parent().remove_child(_door_figure)
		_door_figure.queue_free()
	_door_figure = null


# ── per frame ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# ⚠️ COUNTED BEFORE IT IS HIDDEN, and that is what makes "exactly one frame" measurable
	# rather than asserted. A figure is placed mid-`_process` of frame N (so frame N RENDERS
	# it), is seen here at the top of frame N+1, and is hidden on that same line. A harness that
	# polled `visible` could sample either side of the hide and prove nothing.
	if is_instance_valid(_watcher) and _watcher.visible:
		_watcher_frames += 1
	if _watcher_ttl > 0:
		_watcher_ttl -= 1
		if _watcher_ttl == 0 and is_instance_valid(_watcher):
			_watcher.visible = false
	if is_instance_valid(_door_figure) and _door_figure.visible:
		_door_frames += 1
	if _door_ttl > 0:
		_door_ttl -= 1
		if _door_ttl == 0 and is_instance_valid(_door_figure):
			_door_figure.visible = false
	_tick_lamp(delta)
	_tick_hush(delta)
	if _solved:
		return
	_tick_thresholds()


func _player() -> CharacterBody3D:
	if level == null:
		return null
	return level.get_node_or_null("Player") as CharacterBody3D


func _camera() -> Camera3D:
	var p := _player()
	return p.get_node_or_null("Camera3D") as Camera3D if p else null


# THE STEP. A crossing of a frame's plane, from its front, inside its opening.
#
# ⚠️ IT IS A SIGN CHANGE, NOT AN OVERLAP. An Area3D would fire on entering the volume, which is
# what the old dwell sat inside and what made "standing still" a state at all; a sign change on
# the local z of the player's own body is the geometric definition of walking THROUGH something,
# and it cannot be satisfied by standing anywhere. `check_void` proves both halves: a walk at
# speed steps, and 2 s parked dead centre inside the opening does not.
func _tick_thresholds() -> void:
	if _stepping:
		return
	var p := _player()
	if p == null:
		return
	var at: Vector3 = p.global_position
	var hit := -1
	for i in range(_units.size()):
		var u := _units[i] as Node3D
		var local: Vector3 = u.to_local(at)
		if absf(local.x) > LATERAL_ESCAPE or absf(local.y) > CROSS_MAX_Y:
			_armed[i] = false
			continue
		# ⚠️ ARMING IS WIDER THAN FIRING, and that is measured, not generous. The first build
		# required `|local.x| <= CROSS_HALF_W` to ARM as well as to fire, and a DIAGONAL approach
		# — which is every approach from the entrance to a frame that is not straight ahead —
		# then had an arming window 2.4 cm long: the path only comes inside the opening's width
		# a hair before it is already level with the plane. At `Engine.time_scale = 6.0` the bot
		# moves 6.7 cm per physics tick, so the window fell BETWEEN two samples and a frame
		# walked cleanly through registered nothing (measured: 901 ticks parked 0.8 m behind it).
		# Arming anywhere in front of the plane inside LATERAL_ESCAPE, and firing only inside the
		# opening, gives a 1.5 m arming stretch and the same firing rule.
		var inside: bool = absf(local.x) <= CROSS_HALF_W
		if local.z <= -ARM_Z:
			_armed[i] = true
		elif local.z >= ARM_Z:
			if bool(_armed[i]) and inside and hit < 0:
				hit = i
			_armed[i] = false
	if hit >= 0:
		_crossings += 1
		_step(hit)


func _reset_prev() -> void:
	for i in range(_armed.size()):
		_armed[i] = false


func _step(slot: int) -> void:
	var id := String(_order[slot])
	var right: bool = id == String(ANSWER[_progress])
	_stepping = true
	_reset_prev()
	if _slam:
		_slam.global_position = (_units[slot] as Node3D).global_position + Vector3(0, 1.2, 0)
		_slam.play()
	_cuts += 1
	_dbg("VOID room cut")
	_run_step(slot, right)


# ⚠️ THE MUTATION HAPPENS INSIDE THE BLACK, and the level owns the black because the panel is a
# CanvasLayer and this node is a Node3D full of geometry. `cut_to_black(seconds, while_black)`
# shows the panel, calls the Callable, holds, and hides it — so the ONLY thing between the
# player and the new room is 0.3 s of nothing. The Callable is a lambda rather than a method
# reference so the slot and the verdict travel with it: `Object.call()` on a renamed method
# fails NOTHING (Issue 245), and a captured lambda cannot go stale that way.
func _run_step(slot: int, right: bool) -> void:
	_arrived_three = false
	var work := func() -> void:
		_arrived_three = _inside_black(slot, right)
	var lv: Variant = level
	if lv != null and is_instance_valid(level) and level.has_method("cut_to_black"):
		await lv.cut_to_black(CUT_TIME, work)
	else:
		work.call()
	if not is_instance_valid(self):
		return
	_stepping = false
	_reset_prev()
	if _drop:
		_drop.global_position = ENTRANCE + Vector3(0, 1.0, 0)
		_drop.play()
	# ⚠️ ON THE FADE-IN, NOT INSIDE THE BLACK. Both of these are things you SEE for one rendered
	# frame; placed while the panel is up they would be one frame of a black screen.
	if not right:
		_figure_at_arms_length()
	elif _arrived_three:
		_arrived_three = false
		_stage_three_arrival()


# Returns true if this step arrived at stage 3 (whose beats are shown after the black).
func _inside_black(slot: int, right: bool) -> bool:
	if right:
		_progress += 1
		_dbg("VOID room step right (%d)" % _progress)
		if _tone:
			_tone.global_position = ENTRANCE + Vector3(0, 1.4, 0)
			_tone.pitch_scale = float(TONE_PITCH[mini(_progress - 1, TONE_PITCH.size() - 1)])
			_tone.play()
		_hush_for = HUSH
		_teleport_to_entrance()
		# ⚠️ THE FIFTH RUNG IS APPLIED AND *THEN* SETTLED, in that order. The room reaches its
		# worst state — leaning, every whisper on, the lamp swinging — and the settle's 1.5 s
		# tween is what takes the lean back out of it while the frames line up. Settling first
		# would mean rung 5 never existed: the ladder has five rungs and there are five right
		# doors, so the last one has to be both.
		apply_stage(_progress)
		if _progress >= ANSWER.size():
			_settle()
			return false
		return _progress == 3
	_wrong += 1
	_progress = 0
	_dbg("VOID room step wrong — reset (%d wrong so far, it wanted %s)"
		% [_wrong, ANSWER[0]])
	# ⚠️ THE WHOLE PERMUTATION, not a pair (Issue 241 retired). Nothing is visible, so the
	# level's rule is satisfied in its strongest form and the five doors can simply move.
	_rng.seed = _seed + 977 * _wrong
	apply_scramble(_rng.randi())
	apply_stage(0)
	_teleport_to_entrance()
	return false


# ⚠️ HEADING RESET AND VELOCITY ZEROED — the opposite of the loop seam's rule, and deliberately:
# the seam is a place you keep walking through, this is a place you arrive at. You come back
# standing in the Morgue doorway looking at the five doors, which is what makes "the same room,
# stranger" legible at all.
func _teleport_to_entrance() -> void:
	var p := _player()
	if p == null:
		return
	p.velocity = Vector3.ZERO
	p.global_position = ENTRANCE
	p.rotation.y = ENTRANCE_YAW
	p.force_update_transform()
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.rotation.x = 0.0
		# ⭐ ITEM 2 (pass 7): the room is not level, and the roll is re-applied HERE — on every
		# arrival — because `player.gd:jolt_camera()` tweens z back to 0.0 behind our back.
		_apply_roll()
		cam.force_update_transform()


# ⭐ THE WRONG DOOR'S ANSWER: a figure standing 0.6 m in front of the camera for exactly ONE
# rendered frame as the room comes back. `void_stare_director.gd`'s blink watcher and
# `void_cradle_figure.gd`'s lunge, at their shared distance. No collider, no `ScaryObject`, no
# rule, no panic, no sound of its own — the slam over the cut is the sound.
func _figure_at_arms_length() -> void:
	var p := _player()
	var cam := _camera()
	if p == null or cam == null:
		return
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return
	fwd = fwd.normalized()
	if _watcher == null or not is_instance_valid(_watcher):
		_watcher = _VOID_VISUAL.new() as Node3D
		_watcher.name = "FrameWatcher"
		add_child(_watcher)
	var at: Vector3 = p.global_position + fwd * ARMS_LENGTH
	at.y = p.global_position.y - ARMS_EYE_DROP
	_watcher.global_position = at
	_watcher.rotation.y = atan2(-fwd.x, -fwd.z)   # facing the player
	_watcher.visible = true
	_watcher_ttl = 1
	_dbg("VOID room figure stood %.1f m in front of the camera for one frame (wrong %d)"
		% [ARMS_LENGTH, _wrong])


func _slot_of(id: String) -> int:
	for i in range(_order.size()):
		if String(_order[i]) == id:
			return i
	return -1


# ── lamp and whisper ────────────────────────────────────────────────────────────
func _tick_lamp(delta: float) -> void:
	if _lamp == null or not is_instance_valid(_lamp):
		return
	_lamp.light_energy = move_toward(_lamp.light_energy, _lamp_target, delta * LAMP_RATE)
	if not _swinging:
		return
	_swing_t += delta
	_lamp.position.x = _lamp_home.x + LAMP_SWING * sin(_swing_t * TAU / LAMP_SWING_PERIOD)


# ⚠️ THE HUSH IS APPLIED TO THE EMITTERS, NOT TO A BUS AND NOT TO THE DIRECTOR.
# `creature_stalker.gd` builds its whisper with no `bus`, so it lands on Master and a
# `HoldBreath` dip of Ambience does not touch it; and `void_stare_director.gd` is not this
# pass's file. Setting (never subtracting) the level every idle frame is idempotent, and the
# stalker's own `_tick_whisper()` writes the true value back within one physics frame of the
# hush ending — so this reverts itself even if the hall is freed mid-hush.
func _tick_hush(delta: float) -> void:
	if _hush_for <= 0.0:
		return
	_hush_for -= delta
	if level == null or not level.has_method("get_stalkers"):
		return
	for s in (level.call("get_stalkers") as Dictionary).values():
		if not is_instance_valid(s):
			continue
		var body = s.get("_body")
		if body == null or not is_instance_valid(body):
			continue
		var w := (body as Node3D).get_node_or_null("StalkerWhisper") as AudioStreamPlayer3D
		if w:
			w.volume_db = HUSH_DB
	var south := level.get_node_or_null("LoopWhisperSouth") as AudioStreamPlayer3D
	if south:
		south.volume_db = HUSH_DB


# ── the finish ──────────────────────────────────────────────────────────────────
func _settle() -> void:
	if _solved:
		return
	_solved = true
	_dbg("VOID frames SETTLED — the five line up and the corridor opens")
	if _settle_sfx:
		_settle_sfx.play()
	_clear_door_figure()
	var tw := create_tween()
	tw.set_parallel(true)
	for i in range(_units.size()):
		var u := _units[i] as Node3D
		for arr in [_stages, _echoes]:
			if arr[i] != null and is_instance_valid(arr[i]):
				# The memories collapse as the frames agree: 0.5 s of shrink under a 1.5 s
				# settle, then gone — a frame with a diorama still in it is a corridor you
				# cannot walk.
				tw.tween_property(arr[i], "scale", Vector3.ONE * 0.001, 0.5)
		var bd := u.get_node_or_null("Backdrop")
		if bd:
			tw.tween_property(bd, "scale", Vector3(0.001, 0.001, 0.001), 0.5)
		tw.tween_property(u, "position", Vector3(SETTLE_X, 0.0, float(SETTLE_Z[i])), SETTLE_TIME) \
			.set_trans(Tween.TRANS_SINE)
		tw.tween_property(u, "rotation:y", 0.0, SETTLE_TIME).set_trans(Tween.TRANS_SINE)
		tw.tween_property(u, "rotation:z", 0.0, SETTLE_TIME).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(_on_settled)


# ⚠️ THE ROOM STAYS CORRUPTED. Only the lamp and the frames are relieved — the walls, the hum
# and the whispers are what the player spent five right doors getting to, and taking them back
# would make the last step read as an undo.
func _on_settled() -> void:
	for i in range(_units.size()):
		_drop_stage(i)
	_settle_state()
	if note and is_instance_valid(note):
		note.call("reveal")
	solved.emit()


# ⭐ WHAT THE SETTLE TAKES BACK AND WHAT IT KEEPS (pass 7). Pass 6's ruling stands — the room
# stays corrupted, or the last door reads as an undo — so the floor and the walls keep their
# corrupt texture and the lamp keeps its colour, with only its ENERGY resolving to 1.0. What
# goes is everything whose staying would read as a mistake rather than as an aftermath:
#   * the camera roll — a held Dutch angle would follow the player back through the Sanctum;
#   * the false ceiling — the frames settle into a corridor at x -24 and the hidden note hangs
#     at y 1.3 on the z = 50 wall, and a 2.2 m slab over that corridor is not a scare;
#   * the sixth door and its watcher — a motionless figure over the page is a different beat;
#   * the memory at 1:1 — it stands exactly where the frames settle to.
func _settle_state() -> void:
	_lamp_target = 1.0
	_swinging = false
	_lamp_home.y = _lamp_base_y
	if _lamp and is_instance_valid(_lamp):
		_lamp.position = _lamp_home
		# ⚠️ THE COLOUR STAYS, the energy resolves. Set here rather than left to whatever
		# `apply_stage()` wrote last, because `settle_instantly()` is the RESTORE path and never
		# walked the ladder at all — a player who walks back into a solved room must find the
		# room they left, not the room as it was built.
		_lamp.light_color = LAMP_TINT[LAMP_TINT.size() - 1]
	if level != null and is_instance_valid(level) and level.has_method("set_camera_roll"):
		level.call("set_camera_roll", 0.0)
	else:
		var cam := _camera()
		if cam:
			cam.rotation.z = 0.0
	if _slab and is_instance_valid(_slab):
		remove_child(_slab)
		_slab.queue_free()
	_slab = null
	if _sixth and is_instance_valid(_sixth):
		remove_child(_sixth)
		_sixth.queue_free()
	_sixth = null
	_sixth_figure = null
	if _memory and is_instance_valid(_memory):
		remove_child(_memory)
		_memory.queue_free()
	_memory = null


func _drop_stage(i: int) -> void:
	for arr in [_stages, _echoes]:
		if arr[i] != null and is_instance_valid(arr[i]):
			_units[i].remove_child(arr[i])
			arr[i].queue_free()
		arr[i] = null
	var bd := (_units[i] as Node3D).get_node_or_null("Backdrop")
	if bd:
		_units[i].remove_child(bd)
		bd.queue_free()


# The restore path: the same world, with no tween, no sound and no replayed beat (the Ward
# frame's rule — a snapshot must never re-fire a one-shot).
func settle_instantly() -> void:
	_solved = true
	_progress = ANSWER.size()
	for i in range(_units.size()):
		var u := _units[i] as Node3D
		u.position = Vector3(SETTLE_X, 0.0, float(SETTLE_Z[i]))
		u.rotation.y = 0.0
		u.rotation.z = 0.0
		_drop_stage(i)
	_settle_state()
	if _lamp and is_instance_valid(_lamp):
		_lamp.light_energy = _lamp_target
	if note and is_instance_valid(note):
		note.call("reveal")


# ── progress ────────────────────────────────────────────────────────────────────
#
# ⚠️ `stage` IS `progress`, stored under both names on purpose: the level's snapshot calls it
# `frame_stage` because that is what it means to the WORLD (how strange the room is), and this
# file calls it progress because that is what it means to the puzzle. One value, never two.
func save_state() -> Dictionary:
	return {"order": _order.duplicate(), "progress": _progress, "stage": _progress,
		"wrong": _wrong, "solved": _solved, "seed": _seed}


func restore_state(d: Dictionary) -> void:
	if d.is_empty():
		return
	_seed = int(d.get("seed", _seed))
	var order: Array = d.get("order", [])
	if order.size() == ANSWER.size():
		_set_order(order)
	_wrong = int(d.get("wrong", 0))
	if bool(d.get("solved", false)):
		_progress = ANSWER.size()
		settle_instantly()
		return
	# ⚠️ `arriving` is FALSE: the stage is re-applied as a STATE. A restore that blinked the
	# player and stood a figure in a doorway would be a snapshot replaying a one-shot.
	apply_stage(clampi(int(d.get("stage", d.get("progress", 0))), 0, ANSWER.size()))
	if _lamp:
		_lamp.light_energy = _lamp_target
	_reset_prev()


# ⚠️ SCREENSHOT / TEST HOOKS, the pattern `void_exit_door.gd:snap_assembled()` set: a one-frame
# beat is a RACE with a capture and the capture always loses. These drive the SAME placement the
# beat drives — nothing is faked — and then hold the figure visible instead of hiding it.
func snap_arms_length_figure() -> void:
	_figure_at_arms_length()
	_watcher_ttl = 100000


# ⚠️ NO BLINK for the capture: `blink_now()` drops two eyelids over the whole screen for half a
# second, and the first run of this shot photographed them instead of the figure.
func snap_doorway_figure() -> void:
	_progress = maxi(_progress, 3)
	_stage_three_arrival(false)
	_door_ttl = 100000


func hide_snap_figures() -> void:
	if is_instance_valid(_watcher):
		_watcher.visible = false
	_watcher_ttl = 0
	_clear_door_figure()
	_door_ttl = 0


# ── test surface ────────────────────────────────────────────────────────────────
func answer_order() -> Array:
	return ANSWER.duplicate()


func frame_ids() -> Array:
	return _order.duplicate()


func slot_of(id: String) -> int:
	return _slot_of(id)


func progress() -> int:
	return _progress


func stage() -> int:
	return _progress


func wrong_count() -> int:
	return _wrong


func is_solved() -> bool:
	return _solved


func is_stepping() -> bool:
	return _stepping


func crossings() -> int:
	return _crossings


func cuts() -> int:
	return _cuts


func watcher() -> Node3D:
	return _watcher if is_instance_valid(_watcher) else null


func watcher_visible() -> bool:
	return is_instance_valid(_watcher) and _watcher.visible


func watcher_frames() -> int:
	return _watcher_frames


func door_figure() -> Node3D:
	return _door_figure if is_instance_valid(_door_figure) else null


func door_figure_frames() -> int:
	return _door_frames


func unit(i: int) -> Node3D:
	return _units[i] as Node3D if i >= 0 and i < _units.size() else null


func echo(i: int) -> Node3D:
	return _echoes[i] as Node3D if i >= 0 and i < _echoes.size() else null


func entrance_point() -> Vector3:
	return ENTRANCE


# A stance 1.0 m out from the frame's FRONT face, on the floor — where a harness starts a leg.
func front_point(i: int) -> Vector3:
	var u := unit(i)
	if u == null:
		return Vector3.ZERO
	var front := -u.global_transform.basis.z
	front.y = 0.0
	return u.global_position + front.normalized() * DROP_OUT + Vector3(0, 0.1, 0)


# …and the matching stance 1.0 m out of its BACK, so a harness can walk the whole crossing.
func back_point(i: int) -> Vector3:
	var u := unit(i)
	if u == null:
		return Vector3.ZERO
	var back := u.global_transform.basis.z
	back.y = 0.0
	return u.global_position + back.normalized() * DROP_OUT + Vector3(0, 0.1, 0)


func dwell_point(i: int) -> Vector3:
	var u := unit(i)
	return u.global_position + Vector3(0, 0.1, 0) if u else Vector3.ZERO


func lamp_energy() -> float:
	return _lamp.light_energy if is_instance_valid(_lamp) else -1.0


func lamp_offset() -> float:
	return (_lamp.position.x - _lamp_home.x) if is_instance_valid(_lamp) else 0.0


func hum_playing() -> bool:
	return _hum != null and _hum.playing


func whispers_playing() -> int:
	var n := 0
	for w in _whispers:
		if w != null and (w as AudioStreamPlayer3D).playing:
			n += 1
	return n


func walls_corrupt() -> bool:
	return _walls_corrupt


func wall_boxes() -> Array:
	return _walls.duplicate()


func wall_texture_name() -> String:
	if _walls.is_empty() or not is_instance_valid(_walls[0]):
		return ""
	var m = (_walls[0] as CSGBox3D).material
	if m is StandardMaterial3D and (m as StandardMaterial3D).albedo_texture:
		return String((m as StandardMaterial3D).albedo_texture.resource_path).get_file()
	return ""


func lean() -> float:
	return (_units[0] as Node3D).rotation.z if not _units.is_empty() else 0.0


# ── the pass-7 ladder's test surface ────────────────────────────────────────────
func backdrop_albedo(i: int) -> Color:
	if i < 0 or i >= _backdrops.size() or not (_backdrops[i] is StandardMaterial3D):
		return Color.MAGENTA
	return (_backdrops[i] as StandardMaterial3D).albedo_color


# ⚠️ THE LEVEL'S BASE, not the camera node's instantaneous z. The ambient shake displaces the
# camera by up to 0.008 rad for 0.4 s at a time, so a guard reading the node would be measuring
# whether a 20-60 s timer happened to fire on the sampled tick.
func camera_roll() -> float:
	if level != null and is_instance_valid(level) and level.has_method("camera_roll_base"):
		return float(level.call("camera_roll_base"))
	var cam := _camera()
	return cam.rotation.z if cam else -99.0


# …and the camera node itself, for a guard that wants to prove the base really reached it.
func camera_roll_live() -> float:
	var cam := _camera()
	return cam.rotation.z if cam else -99.0


func grow_applied() -> float:
	return float(GROW[clampi(_progress, 0, GROW.size() - 1)])


func roll_for(s: int) -> float:
	return float(ROLL[clampi(s, 0, ROLL.size() - 1)])


# The echo's offset in its own frame's local space — the number item 3 is entirely about.
func echo_offset(i: int) -> Vector3:
	var e := echo(i)
	return e.position if e else Vector3.ZERO


func floor_box() -> CSGBox3D:
	return _floor if is_instance_valid(_floor) else null


func floor_texture_name() -> String:
	if _floor == null or not is_instance_valid(_floor):
		return ""
	var m = _floor.material
	if m is StandardMaterial3D and (m as StandardMaterial3D).albedo_texture:
		return String((m as StandardMaterial3D).albedo_texture.resource_path).get_file()
	return ""


func floor_corrupt() -> bool:
	return _floor_corrupt


func slab() -> MeshInstance3D:
	return _slab if is_instance_valid(_slab) else null


func slab_y() -> float:
	return _slab.position.y if is_instance_valid(_slab) else -99.0


func lamp_y() -> float:
	return _lamp.position.y if is_instance_valid(_lamp) else -99.0


func lamp_color() -> Color:
	return _lamp.light_color if is_instance_valid(_lamp) else Color.MAGENTA


func sixth_door() -> Node3D:
	return _sixth if is_instance_valid(_sixth) else null


func sixth_door_visible() -> bool:
	return is_instance_valid(_sixth) and _sixth.visible


func sixth_watcher() -> Node3D:
	return _sixth_figure if is_instance_valid(_sixth_figure) else null


func memory() -> Node3D:
	return _memory if is_instance_valid(_memory) else null


func memory_visible() -> bool:
	return is_instance_valid(_memory) and _memory.visible


func diorama_scale(i: int) -> float:
	var st := _stages[i] as Node3D if i >= 0 and i < _stages.size() else null
	if st == null or not is_instance_valid(st) or i >= _order.size():
		return -1.0
	var id := String(_order[i])
	if not DIORAMAS.has(id):
		return -1.0
	return st.scale.x / maxf(0.0001, float((DIORAMAS[id] as Dictionary)["scale"]))


func back_whisper_playing() -> bool:
	return _whisper_back != null and _whisper_back.playing
