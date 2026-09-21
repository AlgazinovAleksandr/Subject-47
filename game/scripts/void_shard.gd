extends StaticBody3D

# The stone shard that fits the child room's cradle — the first half of the far wing's chain
# (shard -> cradle -> the Hall of Frames -> the Sanctum's stone plate over the twist note).
#
# ⭐ IT MOVED TO THE ARCHIVE (2026-09-20 pass 3). It used to lie in the hollow on the underside
# of the Morgue slab, seven seconds from the cradle it opens: the 15:00 log has the shard taken
# at 410 s and the cradle completed at 417 s. The playtester: *"having the missing block just
# before that room is too simple — shall we make it somewhere at the beginning of the level and
# not so easy to find? So that if you miss it you will have to walk all the way to the level
# entry."* It now sits in the legs-up basin of the inverted table in the Archive, a dead end off
# the Ward that none of that day's three runs entered.
#
# ⭐ AND IT IS VISIBLE FROM THE START, WEDGED FAST (2026-09-20 pass 5, Issue 243). Pass 3 made it
# INVISIBLE and collider-less until the table re-posed itself behind the player's back, and two
# captures of the 23:33 run say what that reads as: *"this shard did not appear immediately… we
# should fix that"*. It was working exactly as built — 4.4 s, 11 s and 5.6 s after the table was
# first seen, always on a look-away — and an object that does not exist until you turn round is,
# to a player, a bug. So: the shard is there from frame 0, jammed into the upturned table's
# underside between a leg and the stretcher, and it REFUSES (*"It is wedged fast."*). The
# table's off-screen rearrangement shakes it loose into the basin with a `shard_clatter`, and
# from there it is taken exactly as before.
# ⚠️ THE OFF-SCREEN RULE IS UNTOUCHED, and that is the whole point: what changes when you are
# not looking is still the change. What is new is that the player can SEE the thing that has to
# change, so the look-away is a payoff instead of a spawn.
#
# ⚠️ Layer 2, so the player walks THROUGH it. The table's own collider was cut back to its top
# slab for this (`void_fragments.inverted_table`): with the old floor-to-1.05 m block the E-ray
# stopped on the table and the basin was a place you could see into and never reach — the exact
# fault the Morgue slab's three-collider fix was for.
# ⚠️ `wedge()` / `free_into_basin()` are IDEMPOTENT and the level derives them from the
# rearranger's own `spent` flag, so the off-screen beat, a snapshot restore and a test that sets
# the state by hand all land in the same world. The freed state is derived, never stored.
# ⚠️ `free_into_basin(false)` is the SILENT form, used by a restore: a snapshot must never
# replay a one-shot (the Ward frame's rule).
# ⚠️ ZERO PANIC. The cost is the walk back: from the Archive to the cradle is ~185 m past two
# stalkers, and the loop is two-way once its note is read, so missing it can never softlock.

const FRAGMENTS := preload("res://scripts/void_fragments.gd")

signal taken

var level: Node = null

var _gone := false
var _freed := false
var _basin := Vector3.ZERO       # where it lands once it comes loose (world)
var _wedged_pos := Vector3.ZERO  # where it is jammed until then (world)
var _wedged_rot := Vector3.ZERO
var _shape: CollisionShape3D
var _clatter: AudioStreamPlayer3D


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.36, 0.30, 0.36)
	_shape.shape = box
	add_child(_shape)
	# Three chips, not one cube: silhouette carries a prop (Issue 35).
	var pale := FRAGMENTS._mat(FRAGMENTS.TINT_PALE)
	var stone := FRAGMENTS._mat(FRAGMENTS.TINT)
	var core := FRAGMENTS._box(self, Vector3(0.20, 0.17, 0.12), Vector3.ZERO, pale, "ShardCore")
	core.rotation = Vector3(0.35, 0.4, -0.25)
	var chip := FRAGMENTS._box(self, Vector3(0.09, 0.13, 0.07), Vector3(0.09, -0.05, 0.05), stone, "ShardChip")
	chip.rotation = Vector3(-0.2, 0.9, 0.5)
	var flake := FRAGMENTS._box(self, Vector3(0.07, 0.06, 0.11), Vector3(-0.08, 0.06, -0.04), pale, "ShardFlake")
	flake.rotation = Vector3(0.6, -0.3, 0.2)


# ⚠️ Called by the level AFTER add_child, like `void_loop_note.conceal()` and for the same
# reason: `_ready()` runs before the mesh and the collider exist, so nothing set in `_ready()`
# can describe them. `wedged` is the pose the player finds it in; `basin` is where the table
# drops it when it re-poses itself.
func set_poses(wedged: Vector3, wedged_rot: Vector3, basin: Vector3) -> void:
	_wedged_pos = wedged
	_wedged_rot = wedged_rot
	_basin = basin


func wedge() -> void:
	if _gone:
		return
	_freed = false
	global_position = _wedged_pos
	rotation = _wedged_rot


# The rearrangement IS the release. `announce` is false for a restore — a snapshot must never
# replay a one-shot beat.
func free_into_basin(announce: bool = true) -> void:
	if _gone:
		return
	var was_freed := _freed
	_freed = true
	global_position = _basin
	rotation = Vector3.ZERO
	if was_freed or not announce:
		return
	if _clatter == null:
		var s := GameState.load_audio("shard_clatter")
		if s:
			_clatter = AudioStreamPlayer3D.new()
			_clatter.name = "ShardClatter"
			_clatter.stream = s
			# shard_clatter measures -22.5 dBFS RMS — 5.9 dB quieter than the `paper_drop` that
			# used to mark this beat, which sat at -9.0 dB / unit 3.0. Same perceived level for
			# the same job: -3.0 dB at unit 3.0. It is the ONLY tell that something behind you
			# came loose, so it is set from the file, not from a plausible number.
			_clatter.volume_db = -3.0
			_clatter.unit_size = 3.0
			_clatter.bus = AudioBuses.AMBIENCE
			add_child(_clatter)
	if _clatter:
		_clatter.play()
	_dbg("VOID shard FREED into the basin at %v" % global_position)


func is_freed() -> bool:
	return _freed


# check_reachable's gate hook: the sweep asks the level to put itself into the state a player
# reaches rather than deleting a collider behind its back (the LabLocker rule).
func move_aside_instantly() -> void:
	free_into_basin(false)


# ⚠️ TRUE EVEN WHILE WEDGED, like every other gated interactable in this level: `false` hides
# the prompt entirely, and a shard you can see and get no word about is the pass-3 complaint
# again in a different shape. The refusal is the information.
func can_interact() -> bool:
	return not _gone


func prompt_text() -> String:
	return "E — Take the shard." if _freed else "It is wedged fast."


func interact() -> void:
	if _gone:
		return
	if not _freed:
		_dbg("VOID shard refused — wedged")
		return
	_gone = true
	if level != null:
		level.call("take_shard")
	_dbg("VOID shard taken from the Archive table")
	taken.emit()
	queue_free()
