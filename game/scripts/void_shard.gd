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
# ⭐ AND IT IS TAKEABLE FROM FRAME ZERO (2026-09-22 pass 6). Pass 3 made it invisible until the
# table re-posed itself; pass 5 made it visible but WEDGED, refusing until the same look-away
# shook it loose. Capture #4 of the 23:47 run is what happened next: refused five times at
# 136-143 s, freed off-screen at 145.6 s two seconds after the player had walked out, taken at
# 160 s — *"when I entered the room for the first time — I could not take the shard. And now …
# second time — I can. Should not be that way"*. A receipt that reads as a lock is a lock.
# So the shard lies in the basin of the upturned table from `_ready()`, offering E, and the
# table's off-screen rearrangement survives as a PURE SCARE that gates nothing.
# ⚠️ `shard_clatter.wav` is GONE — it existed only to announce the release. Do not re-add a
# `GameState.load_audio("shard_clatter")`: the file and its generator entry were deleted, so
# `ResourceLoader.exists()` is false and the call would silently return null forever.
#
# ⚠️ Layer 2, so the player walks THROUGH it. The table's own collider was cut back to its top
# slab for this (`void_fragments.inverted_table`): with the old floor-to-1.05 m block the E-ray
# stopped on the table and the basin was a place you could see into and never reach — the exact
# fault the Morgue slab's three-collider fix was for.
# ⚠️ ZERO PANIC. The cost is the walk back: from the Archive to the cradle is ~185 m past two
# stalkers, and the loop is two-way once its note is read, so missing it can never softlock.

const FRAGMENTS := preload("res://scripts/void_fragments.gd")

signal taken

var level: Node = null

var _gone := false
# ⚠️ TRUE FROM CONSTRUCTION. Kept as a field rather than deleted because `is_freed()` is the API
# three guards and two walk routes address this prop by, and because "the shard is available"
# is a thing a test should be able to ask rather than assume.
var _freed := true
var _basin := Vector3.ZERO       # where it lies, in the upturned table's basin (world)
var _shape: CollisionShape3D


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
# can describe them. `basin` is where it lies, in the legs-up table's own hollow.
func set_basin(basin: Vector3) -> void:
	_basin = basin
	if not _gone:
		global_position = _basin
		rotation = Vector3.ZERO


func basin() -> Vector3:
	return _basin


func is_freed() -> bool:
	return _freed


func can_interact() -> bool:
	return not _gone


func prompt_text() -> String:
	return "E — Take the shard."


func interact() -> void:
	if _gone:
		return
	_gone = true
	if level != null:
		level.call("take_shard")
	_dbg("VOID shard taken from the Archive table")
	taken.emit()
	queue_free()
