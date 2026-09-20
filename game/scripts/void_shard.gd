extends StaticBody3D

# The stone shard that fits the child room's cradle — the first half of the far wing's chain
# (shard → cradle → the Sanctum's stone plate over the twist note).
#
# ⭐ IT MOVED TO THE ARCHIVE, AND IT HIDES (2026-09-20 pass 3). It used to lie in the hollow on
# the underside of the Morgue slab, seven seconds from the cradle it opens: the 15:00 log has
# the shard taken at 410 s and the cradle completed at 417 s. The playtester: *"having the
# missing block just before that room is too simple — shall we make it somewhere at the
# beginning of the level and not so easy to find? So that if you miss it you will have to walk
# all the way to the level entry."* It now sits in the legs-up basin of the inverted table in
# the Archive, a dead end off the Ward that none of the day's three runs entered — and it is
# INVISIBLE AND UNTOUCHABLE until that table rearranges itself behind your back. You cannot
# see it from the doorway; you get it by looking at the table and then looking away.
#
# ⚠️ Layer 2, so the player walks THROUGH it. The table's own collider was cut back to its top
# slab for this (`void_fragments.inverted_table`): with the old floor-to-1.05 m block the E-ray
# stopped on the table and the basin was a place you could see into and never reach — the exact
# fault the Morgue slab's three-collider fix was for.
# ⚠️ `conceal()` / `reveal()` are IDEMPOTENT and the level derives them from the rearranger's
# own `spent` flag, so the off-screen beat, a snapshot restore and a test that sets the state by
# hand all land in the same world. The revealed state is derived, never stored.
# ⚠️ ZERO PANIC. The cost is the walk back: from the Archive to the cradle is ≈ 185 m past two
# stalkers, and the loop is two-way once its note is read, so missing it can never softlock.

const FRAGMENTS := preload("res://scripts/void_fragments.gd")

signal taken

var level: Node = null

var _gone := false
var _revealed := true
var _shape: CollisionShape3D
var _drop: AudioStreamPlayer3D


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
# reason: `_ready()` runs before the mesh and the collider exist, so it cannot hide them.
func conceal() -> void:
	_revealed = false
	visible = false
	if _shape:
		_shape.set_deferred("disabled", true)


func reveal() -> void:
	if _revealed or _gone:
		return
	_revealed = true
	visible = true
	if _shape:
		_shape.set_deferred("disabled", false)
	if _drop == null:
		var s := GameState.load_audio("paper_drop")
		if s:
			_drop = AudioStreamPlayer3D.new()
			_drop.name = "ShardSettle"
			_drop.stream = s
			# paper_drop measures -16.6 dBFS RMS and this is a small thing shifting inside a
			# table you are standing beside — the same close, quiet treatment the loop note's
			# page gets. It is the ONLY tell that the rearrangement left something behind.
			_drop.volume_db = -9.0
			_drop.unit_size = 3.0
			_drop.bus = AudioBuses.AMBIENCE
			add_child(_drop)
	if _drop:
		_drop.play()
	_dbg("VOID shard REVEALED in the inverted table's basin at %v" % global_position)


func is_revealed() -> bool:
	return _revealed


# check_reachable's gate hook: the sweep asks the level to put itself into the state a player
# reaches rather than deleting a collider behind its back (the LabLocker rule).
func move_aside_instantly() -> void:
	reveal()


func can_interact() -> bool:
	return not _gone and _revealed


func prompt_text() -> String:
	return "E — Take the shard."


func interact() -> void:
	if _gone or not _revealed:
		return
	_gone = true
	if level != null:
		level.call("take_shard")
	_dbg("VOID shard taken from the Archive table")
	taken.emit()
	queue_free()
