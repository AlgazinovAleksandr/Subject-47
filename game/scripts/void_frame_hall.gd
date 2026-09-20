extends Node3D

# ⭐ THE HALL OF FRAMES (2026-09-20 pass 4) — the level's second sub-challenge, behind the
# secret door the cradle opens.
#
# Five upright doorframes, each framing a small diorama of a thing you have already met, in that
# room's own albedo family (`void_fragments.PALETTE`, the level's memory system):
#
#     shards  Threshold  violet      frame  Ward     bone       table  Archive  rust
#     chairs  LoopIn     verdigris   stair  Hall1    tar
#
# **Step through them in the order you first met them** — Threshold → Ward → Archive → LoopIn →
# Hall1 — using the verb pass 3 added and NOBODY FOUND (the 18:30 log: the step-through never
# fired once in 413 s). Requiring it is the only way this level can teach it that cannot be read
# as a hint. The frames' POSITIONS are scrambled per load and re-scrambled behind your back on
# every wrong step, so the answer is the memory of the level, never the geometry of the room.
#
# ⚠️ ZERO PANIC, NO FAIL STATE, INFINITELY RETRYABLE — the user's ruling, and the reason this is
# legal at all: worst-case brute force is 15 dwells, a floor and not a wall. Nothing in this file
# calls `add_panic()`, and the room carries no `DarkZone` and is outside `DreadFarWing` (Issue 18:
# never tax the posture a puzzle requires, and this one asks you to stand still).
# ⚠️ NO READOUT (SCARY.md §8.2). The feedback is entirely spatial and diegetic — which frame you
# come out of, the lamp, the interval of the tone. The count is never shown.
# ⚠️ THE FIGURE IN A DIORAMA IS A PHOTOGRAPH (P3): no collider, no `ScaryObject`, no AI, no rule.
# `check_void_frames.gd` walks its subtree every run and asserts exactly that — a sixth creature
# would break §8.3's one-chase-level-in-twelve budget.
#
# ⚠️ EVERY FRAME IS WALK-THROUGH. `void_fragments.flat_doorframe()` builds meshes only, with no
# collider at all, and the dioramas' own bodies have their shapes disabled and their layer
# zeroed here. Five solid frames in a 6 x 6 room is a room you cannot cross.

const FRAGMENTS := preload("res://scripts/void_fragments.gd")
const _VOID_VISUAL := preload("res://scripts/void_creature_visual.gd")

# ── the answer: the order the five things are met walking the level from the spawn ──
const ANSWER := ["shards", "frame", "table", "chairs", "stair"]

# `y` and `scale` are MEASURED against the 0.92 x 2.10 m opening each diorama has to read
# inside — a prop scaled by eye either pokes out of the front of the frame or disappears into
# the backdrop 0.95 m behind it. `deep` is the prop's own local depth, the number that had to
# fit between the two.
const DIORAMAS := {
	"shards": {"room": "Threshold", "family": "violet",    "scale": 0.55, "y": 0.42},
	"frame":  {"room": "Ward",      "family": "bone",      "scale": 0.45, "y": 0.55},
	"table":  {"room": "Archive",   "family": "rust",      "scale": 0.50, "y": 0.75},
	"chairs": {"room": "LoopIn",    "family": "verdigris", "scale": 0.45, "y": 0.85},
	"stair":  {"room": "Hall1",     "family": "tar",       "scale": 0.24, "y": 0.60},
}

# ⚠️ TWO COLUMNS, NOT A RING — a west column of three and an east column of two, with the
# doorway lane (z 46.6..48.4) kept clear between them. A pentagon around the room's centre
# looked better and crowded the entrance; either way, NO layout of five frames in a 6 x 6 room
# leaves a bearing with nothing in it (measured: from the wrong step's drop point the five sit
# at -122, -41, +41, +122 and 180 degrees, so the worst-case distance to the nearest is 40.5,
# inside the camera's own 53.7-degree horizontal half-angle), which is why the re-scramble
# exchanges PAIRS of unwatched frames rather than waiting for the room to be unwatched.
# ⚠️ The east column's two frames sit at z 44.9 and 49.1 precisely to clear that lane: a frame
# across the only doorway is a sealed room.
const SLOTS := [
	{"at": Vector3(-25.7, 0.0, 45.4), "yaw": -1.4708},   # -PI/2 + 0.10, faces +x
	{"at": Vector3(-25.7, 0.0, 47.0), "yaw": -1.6508},   # -PI/2 - 0.08
	{"at": Vector3(-25.7, 0.0, 48.6), "yaw": -1.5108},   # -PI/2 + 0.06
	{"at": Vector3(-22.3, 0.0, 44.9), "yaw":  1.4808},   #  PI/2 - 0.09, faces -x
	{"at": Vector3(-22.3, 0.0, 49.1), "yaw":  1.6408},   #  PI/2 + 0.07
]

# `flat_doorframe()` lies in its own XZ plane; Rx(-PI/2) stands it on end with local +z up, and
# the whole thing then spans y -1.17..+1.17 about its origin. FRAME_LIFT puts the threshold bar
# on the floor: opening y 0.12..2.22, width 0.92 between the jambs' inner faces.
const FRAME_LIFT := 1.17
const DIORAMA_Z := 0.48         # behind the frame plane (local +z is BEHIND; -z is the front)
const BACKDROP_Z := 0.95
const DROP_OUT := 1.0           # metres in front of a frame the player is set down

const STEP_DWELL := 1.2         # the step-through's own clock, verbatim
const COOLDOWN := 0.35          # after any drop, so the destination cannot instantly re-fire
const LAMP_BASE := 0.25
const LAMP_STEP := 0.15
const LAMP_DEAD := 2.0
const LAMP_RATE := 1.2
const SETTLE_TIME := 1.5
const HUSH := 1.0
const HUSH_DB := -60.0
const RESCRAMBLE_DOT := 0.55    # ~57 degrees: a frame inside this cone counts as watched
const RESCRAMBLE_RANGE := 9.0
# One interval per stage. `frame_tone` is one sample; `pitch_scale` is what rises.
const TONE_PITCH := [1.0, 1.125, 1.25, 1.5, 2.0]
const SETTLE_X := -24.0
const SETTLE_Z := [45.2, 46.15, 47.1, 48.05, 49.0]
const BEHIND_DIST := 1.2

signal solved

var level: Node3D = null
var note: Node = null

var _order: Array = []          # slot index -> diorama id
var _units: Array = []          # slot index -> Node3D
var _stages: Array = []         # slot index -> the diorama root (or null once settled)
var _areas: Array = []          # slot index -> Area3D
var _progress := 0
var _wrong := 0
var _solved := false
var _seed := 0
var _dwell := 0.0
var _in_slot := -1
var _cooldown := 0.0
var _rescramble_pending := false
var _swaps_left := 0
var _swap_cooldown := 0.0
var _rng := RandomNumberGenerator.new()
var _lamp: OmniLight3D = null
var _lamp_target := LAMP_BASE
var _lamp_dead_for := 0.0
var _hush_for := 0.0
var _figure: Node3D = null
var _figure_slot := -1
var _watcher: Node3D = null
var _watcher_ttl := 0
var _watcher_frames := 0
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
		var area := Area3D.new()
		area.name = "Dwell%d" % i
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.86, 2.00, 0.44)
		col.shape = sh
		area.add_child(col)
		area.position = Vector3(0, 1.10, 0)
		area.collision_layer = 0
		area.collision_mask = 1
		unit.add_child(area)
		_units.append(unit)
		_areas.append(area)
		_stages.append(null)
	apply_scramble(_seed)
	_lamp_target = LAMP_BASE
	if _lamp:
		_lamp.light_energy = LAMP_BASE


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
	black.albedo_color = Color(0.02, 0.018, 0.026)
	black.roughness = 1.0
	mi.set_surface_override_material(0, black)
	mi.position = Vector3(0, 1.20, BACKDROP_Z)
	mi.rotation.y = PI          # a QuadMesh faces +z; the viewer is at local -z
	unit.add_child(mi)


func _build_audio() -> void:
	# ⚠️ Gains from the FILES' measured RMS, never from plausible numbers:
	#   frame_tone   -10.89 dBFS (0.6 dB under stone_grind, the level's loudest one-shot until
	#                this pass) -> -7.5 dB / unit 4.0, heard from the frame you just left
	#   loop_slam    -17.74      -> -6.0 dB / unit 3.0. The corridor's copy runs -3.0 / unit 14
	#                because it is heard from 15-30 m; in a 6 m room that is a different sound.
	#   frame_drop   -16.17      -> -10.5 / unit 4.0, the step-through's own measured gain: it
	#                plays at zero distance from the player who just arrived.
	#   frame_settle -13.01      -> -5.5 / unit 6.0, and it has to fill the room once.
	_tone = _emitter("FrameTone", "frame_tone", -7.5, 4.0)
	_slam = _emitter("FrameSlam", "loop_slam", -6.0, 3.0)
	_drop = _emitter("FrameDrop", "frame_drop", -10.5, 4.0)
	_settle_sfx = _emitter("FrameSettle", "frame_settle", -5.5, 6.0)
	if _settle_sfx:
		_settle_sfx.position = Vector3(SETTLE_X, 1.4, 47.0)


func _emitter(nm: String, base: String, db: float, unit: float) -> AudioStreamPlayer3D:
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
	return pl


# ── the scramble ────────────────────────────────────────────────────────────────
#
# Deterministic from `seed_value`, so a snapshot restore, a re-scramble and a seeded harness run
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
		# A re-scramble that changes nothing is not a re-scramble; it reads as a dead trigger.
		if _order.is_empty() or ids != _order or tries >= 8:
			break
	_set_order(ids)


func _set_order(ids: Array) -> void:
	_order = ids.duplicate()
	for i in range(_units.size()):
		if _stages[i] != null and is_instance_valid(_stages[i]):
			_units[i].remove_child(_stages[i])
			_stages[i].queue_free()
		_stages[i] = _build_diorama(_units[i], String(_order[i]))


func _build_diorama(unit: Node3D, id: String) -> Node3D:
	var spec: Dictionary = DIORAMAS[id]
	var stage := Node3D.new()
	stage.name = "Diorama_" + id
	stage.position = Vector3(0, float(spec["y"]), DIORAMA_Z)
	stage.scale = Vector3.ONE * float(spec["scale"])
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
# StaticBody3D with a real collision box; at 0.45 scale inside a frame the player is meant to
# stand in, those are five invisible kerbs in a 6 x 6 room. Layer AND shapes, because a shape
# left enabled on a layer-0 body still answers `intersect_shape` queries from anything that
# asks by mask, and the re-scramble's line-of-sight ray is exactly such a query.
func _strip_collision(n: Node) -> void:
	if n is CollisionObject3D:
		(n as CollisionObject3D).collision_layer = 0
		(n as CollisionObject3D).collision_mask = 0
	if n is CollisionShape3D:
		(n as CollisionShape3D).disabled = true
	for c in n.get_children():
		_strip_collision(c)


# ── per frame ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	# ⚠️ COUNTED BEFORE IT IS HIDDEN, and that is what makes "exactly one frame" measurable
	# rather than asserted. The watcher is placed mid-`_process` of frame N (so frame N RENDERS
	# it), is seen here at the top of frame N+1, and is hidden on that same line. A harness that
	# polled `visible` could sample either side of the hide and prove nothing.
	if is_instance_valid(_watcher) and _watcher.visible:
		_watcher_frames += 1
	if _watcher_ttl > 0:
		_watcher_ttl -= 1
		if _watcher_ttl == 0 and is_instance_valid(_watcher):
			_watcher.visible = false
	_tick_lamp(delta)
	_tick_hush(delta)
	if _solved:
		return
	_tick_rescramble()
	_tick_dwell(delta)


func _player() -> CharacterBody3D:
	if level == null:
		return null
	return level.get_node_or_null("Player") as CharacterBody3D


func _camera() -> Camera3D:
	var p := _player()
	return p.get_node_or_null("Camera3D") as Camera3D if p else null


func _tick_dwell(delta: float) -> void:
	var p := _player()
	if p == null:
		return
	if _cooldown > 0.0:
		_cooldown -= delta
		_dwell = 0.0
		_in_slot = -1
		return
	var inside := -1
	for i in range(_areas.size()):
		for b in (_areas[i] as Area3D).get_overlapping_bodies():
			if b == p:
				inside = i
				break
		if inside >= 0:
			break
	if inside != _in_slot:
		_in_slot = inside
		_dwell = 0.0
	if inside < 0:
		return
	_dwell += delta
	if _dwell < STEP_DWELL:
		return
	_dwell = 0.0
	_step(inside)


func _step(slot: int) -> void:
	var id := String(_order[slot])
	if id == String(ANSWER[_progress]):
		_right(slot, id)
	else:
		_wrong_step(slot, id)


func _right(slot: int, id: String) -> void:
	_progress += 1
	_dbg("VOID frame step right (%d/%d) — %s" % [_progress, ANSWER.size(), id])
	if _tone:
		_tone.global_position = (_units[slot] as Node3D).global_position + Vector3(0, 1.4, 0)
		_tone.pitch_scale = float(TONE_PITCH[mini(_progress - 1, TONE_PITCH.size() - 1)])
		_tone.play()
	_lamp_target = LAMP_BASE + LAMP_STEP * float(_progress)
	_hush_for = HUSH
	if _progress >= ANSWER.size():
		_settle()
		return
	_drop_player_at(_slot_of(String(ANSWER[_progress])))


func _wrong_step(slot: int, id: String) -> void:
	_wrong += 1
	_dbg("VOID frame step wrong (%d) — %s, it wanted %s" % [_wrong, id, ANSWER[_progress]])
	if _slam:
		_slam.global_position = (_units[slot] as Node3D).global_position + Vector3(0, 1.2, 0)
		_slam.play()
	_lamp_dead_for = LAMP_DEAD
	_rescramble_pending = true
	_swaps_left = RESCRAMBLE_SWAPS
	_swap_cooldown = 0.0
	_rng.seed = _seed + 977 * _wrong
	_place_diorama_figure()
	# ⚠️ EVERY third wrong step, not only the third: a player who is flailing keeps escalating.
	if _wrong % 3 == 0:
		_behind_you()
	_drop_player_at(slot)


# ⚠️ HEADING AND VELOCITY ARE KEPT — the loop seam's and the step-through's own rule. Nothing
# here touches `rotation`, and the drop point is DROP_OUT metres out of the frame's FRONT face,
# which is always inside the room for all five slots (check_void_frames asserts a floor under the
# player and the room rect around them after every single drop).
func _drop_player_at(slot: int) -> void:
	var p := _player()
	if p == null or slot < 0:
		return
	var unit := _units[slot] as Node3D
	var front := -unit.global_transform.basis.z
	front.y = 0.0
	if front.length() < 0.01:
		front = Vector3(1, 0, 0)
	front = front.normalized()
	var at: Vector3 = unit.global_position + front * DROP_OUT
	at.y = 0.1
	var keep := p.velocity
	p.global_position = at
	p.force_update_transform()
	p.velocity = keep
	_cooldown = COOLDOWN
	_dwell = 0.0
	_in_slot = -1
	if _drop:
		_drop.global_position = at + Vector3(0, 1.0, 0)
		_drop.play()


func _slot_of(id: String) -> int:
	for i in range(_order.size()):
		if String(_order[i]) == id:
			return i
	return -1


# ── the two figures ─────────────────────────────────────────────────────────────
#
# Both are `void_creature_visual.gd` with NOTHING attached: no stalker script, no collider, no
# ScaryObject ancestor, no panic, no rule. The same photograph the stare director stands at the
# parting of the eyelids (P3), and the same one the cradle throws at the camera.
func _place_diorama_figure() -> void:
	_clear_diorama_figure()
	var want := String(ANSWER[mini(_wrong, ANSWER.size() - 1)])
	var slot := _slot_of(want)
	if slot < 0 or _stages[slot] == null or not is_instance_valid(_stages[slot]):
		return
	_figure = _VOID_VISUAL.new() as Node3D
	_figure.name = "DioramaFigure"
	_stages[slot].add_child(_figure)
	_figure.position = Vector3(0, 0, -0.25)
	_figure.rotation.y = PI          # +Z is its forward; the viewer stands at the stage's -z
	_figure_slot = slot
	_dbg("VOID frame figure stands in the %s diorama (wrong %d)" % [want, _wrong])


func _clear_diorama_figure() -> void:
	if _figure and is_instance_valid(_figure):
		_figure.get_parent().remove_child(_figure)
		_figure.queue_free()
	_figure = null
	_figure_slot = -1


# 1.2 m behind the player for exactly one process frame — `void_stare_director.gd`'s blink
# watcher, placed the other way round. The director is not called: only its placement is copied,
# because a second caller would fight its `_busy` flag and its ladder.
func _behind_you() -> void:
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
	var at: Vector3 = p.global_position - fwd * BEHIND_DIST
	at.y = p.global_position.y
	_watcher.global_position = at
	_watcher.rotation.y = atan2(fwd.x, fwd.z)   # facing the back of the player's head
	_watcher.visible = true
	_watcher_ttl = 1
	_dbg("VOID frame figure stood %.1f m behind the player for one frame (wrong %d)"
		% [BEHIND_DIST, _wrong])


# ── the re-scramble, off-screen ─────────────────────────────────────────────────
#
# ⚠️ ONE PAIR AT A TIME, AND ONLY PAIRS THE PLAYER CANNOT SEE — and this is the second design,
# because the first one deadlocked and the geometry says it had to. The obvious rule ("apply the
# whole new order the first frame no frame is being watched") is unsatisfiable HERE: measured
# from the wrong step's own drop point, the five frames sit at bearings -122, -41, +41, +122 and
# 180 degrees, so the widest gap between neighbours is 81 degrees and the furthest any bearing
# can be from the nearest frame is 40.5 — inside a 75-degree-FOV camera's own ~54-degree
# horizontal half-angle, let alone the 57 this tests. There is NO direction in this room with
# nothing in it, so "look away from all five" never happens and the frames never move.
#
# Exchanging two unobserved frames' memories is strictly better and needs no compromise: every
# swap is atomic, `_order` is a valid permutation at every instant (so a dwell is never judged
# against a frame that is visually mid-change), and the level's own rule — NOTHING EVER CHANGES
# WHILE YOU ARE LOOKING AT IT — holds per frame instead of per room. Stand still staring at one
# and the ones behind you still trade; turn round and they have.
const RESCRAMBLE_SWAPS := 4          # enough exchanges to shuffle five
const SWAP_INTERVAL := 0.25


func _tick_rescramble() -> void:
	if not _rescramble_pending:
		return
	var delta: float = get_process_delta_time()
	_swap_cooldown -= delta
	if _swap_cooldown > 0.0:
		return
	var free: Array = []
	for i in range(_units.size()):
		if not _looking_at(i):
			free.append(i)
	if free.size() < 2:
		return
	# The figure that was standing in a diorama goes with the first exchange: it is part of the
	# same beat, and a rebuilt diorama would free it anyway.
	_clear_diorama_figure()
	var a: int = int(free[_rng.randi_range(0, free.size() - 1)])
	var b: int = a
	var guard := 0
	while b == a and guard < 16:
		b = int(free[_rng.randi_range(0, free.size() - 1)])
		guard += 1
	if b == a:
		return
	var tmp: Variant = _order[a]
	_order[a] = _order[b]
	_order[b] = tmp
	_rebuild_diorama(a)
	_rebuild_diorama(b)
	_swaps_left -= 1
	_swap_cooldown = SWAP_INTERVAL
	if _swaps_left <= 0:
		_rescramble_pending = false
		_dbg("VOID frames re-scrambled off-screen after %d wrong step(s): %s"
			% [_wrong, str(_order)])


func _rebuild_diorama(i: int) -> void:
	if _stages[i] != null and is_instance_valid(_stages[i]):
		_units[i].remove_child(_stages[i])
		_stages[i].queue_free()
	_stages[i] = _build_diorama(_units[i], String(_order[i]))


# A frame is WATCHED if its opening is inside the cone, inside range and not behind a wall.
# ⚠️ 0.55 is not a taste call: a 75-degree-FOV camera at 16:9 sees +-53.7 degrees horizontally,
# i.e. everything with a dot above 0.59. 0.55 is the first value strictly OUTSIDE the frustum,
# so a frame this calls unwatched is a frame that is genuinely off the screen.
func _looking_at(i: int) -> bool:
	var cam := _camera()
	var p := _player()
	if cam == null or p == null:
		return false
	var c: Vector3 = (_units[i] as Node3D).global_position + Vector3(0, 1.2, 0)
	var to: Vector3 = c - cam.global_position
	if to.length() > RESCRAMBLE_RANGE:
		return false
	if (-cam.global_basis.z).dot(to.normalized()) < RESCRAMBLE_DOT:
		return false
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, c)
	q.exclude = [p.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ── lamp and whisper ────────────────────────────────────────────────────────────
func _tick_lamp(delta: float) -> void:
	if _lamp == null or not is_instance_valid(_lamp):
		return
	if _lamp_dead_for > 0.0:
		_lamp_dead_for -= delta
		_lamp.light_energy = 0.0
		return
	_lamp.light_energy = move_toward(_lamp.light_energy, _lamp_target, delta * LAMP_RATE)


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
	_clear_diorama_figure()
	for a in _areas:
		(a as Area3D).set_deferred("monitoring", false)
	var tw := create_tween()
	tw.set_parallel(true)
	for i in range(_units.size()):
		var u := _units[i] as Node3D
		if _stages[i] != null and is_instance_valid(_stages[i]):
			# The memories collapse as the frames agree: 0.5 s of shrink under a 1.6 s settle,
			# then gone — a frame with a diorama still in it is a corridor you cannot walk.
			tw.tween_property(_stages[i], "scale", Vector3.ONE * 0.001, 0.5)
		var bd := u.get_node_or_null("Backdrop")
		if bd:
			tw.tween_property(bd, "scale", Vector3(0.001, 0.001, 0.001), 0.5)
		tw.tween_property(u, "position", Vector3(SETTLE_X, 0.0, float(SETTLE_Z[i])), SETTLE_TIME) \
			.set_trans(Tween.TRANS_SINE)
		tw.tween_property(u, "rotation:y", 0.0, SETTLE_TIME).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(_on_settled)


func _on_settled() -> void:
	for i in range(_units.size()):
		_drop_stage(i)
	_lamp_target = LAMP_BASE + LAMP_STEP * float(ANSWER.size())
	if note and is_instance_valid(note):
		note.call("reveal")
	solved.emit()


func _drop_stage(i: int) -> void:
	if _stages[i] != null and is_instance_valid(_stages[i]):
		_units[i].remove_child(_stages[i])
		_stages[i].queue_free()
	_stages[i] = null
	var bd := (_units[i] as Node3D).get_node_or_null("Backdrop")
	if bd:
		_units[i].remove_child(bd)
		bd.queue_free()


# The restore path: the same world, with no tween, no sound and no replayed beat (the Ward
# frame's rule — a snapshot must never re-fire a one-shot).
func settle_instantly() -> void:
	_solved = true
	_progress = ANSWER.size()
	for a in _areas:
		(a as Area3D).set_deferred("monitoring", false)
	for i in range(_units.size()):
		var u := _units[i] as Node3D
		u.position = Vector3(SETTLE_X, 0.0, float(SETTLE_Z[i]))
		u.rotation.y = 0.0
		_drop_stage(i)
	_lamp_target = LAMP_BASE + LAMP_STEP * float(ANSWER.size())
	if _lamp:
		_lamp.light_energy = _lamp_target
	if note and is_instance_valid(note):
		note.call("reveal")


# ── progress ────────────────────────────────────────────────────────────────────
func save_state() -> Dictionary:
	return {"order": _order.duplicate(), "progress": _progress, "wrong": _wrong,
		"solved": _solved, "seed": _seed}


func restore_state(d: Dictionary) -> void:
	if d.is_empty():
		return
	_seed = int(d.get("seed", _seed))
	var order: Array = d.get("order", [])
	if order.size() == ANSWER.size():
		_set_order(order)
	_progress = clampi(int(d.get("progress", 0)), 0, ANSWER.size())
	_wrong = int(d.get("wrong", 0))
	if bool(d.get("solved", false)):
		settle_instantly()
	else:
		_lamp_target = LAMP_BASE + LAMP_STEP * float(_progress)
		if _lamp:
			_lamp.light_energy = _lamp_target


# ── test surface ────────────────────────────────────────────────────────────────
func answer_order() -> Array:
	return ANSWER.duplicate()


func frame_ids() -> Array:
	return _order.duplicate()


func slot_of(id: String) -> int:
	return _slot_of(id)


func progress() -> int:
	return _progress


func wrong_count() -> int:
	return _wrong


func is_solved() -> bool:
	return _solved


func dwell_seconds() -> float:
	return _dwell


func rescramble_pending() -> bool:
	return _rescramble_pending


func looking_at(i: int) -> bool:
	return _looking_at(i)


func diorama_figure() -> Node3D:
	return _figure if is_instance_valid(_figure) else null


func diorama_figure_slot() -> int:
	return _figure_slot


func watcher() -> Node3D:
	return _watcher if is_instance_valid(_watcher) else null


func watcher_visible() -> bool:
	return is_instance_valid(_watcher) and _watcher.visible


func watcher_frames() -> int:
	return _watcher_frames


func unit(i: int) -> Node3D:
	return _units[i] as Node3D if i >= 0 and i < _units.size() else null


func front_point(i: int) -> Vector3:
	var u := unit(i)
	if u == null:
		return Vector3.ZERO
	var front := -u.global_transform.basis.z
	front.y = 0.0
	return u.global_position + front.normalized() * DROP_OUT + Vector3(0, 0.1, 0)


func dwell_point(i: int) -> Vector3:
	var u := unit(i)
	return u.global_position + Vector3(0, 0.1, 0) if u else Vector3.ZERO


func lamp_energy() -> float:
	return _lamp.light_energy if is_instance_valid(_lamp) else -1.0
