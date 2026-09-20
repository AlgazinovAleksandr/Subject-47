extends "res://scripts/note.gd"

# ⭐ THE HIDDEN NOTE (2026-09-20 pass 4) — the page at the end of the Hall of Frames' corridor,
# and the thing that finally moves the stone over the twist note.
#
# The chain used to be `cradle → SanctumPlate retracts → TwistNote → ExitDoor`, with the plate
# retracting two rooms away from where the player was standing. It is now
# `cradle → the secret door → the frames → THIS → the plate → TwistNote → ExitDoor`: one link
# moved, **no new unlock condition**, and `door.gd:UnlockCondition.TWIST_READ` is untouched.
# One note points (the drawer page), one moves the stone (this), one reveals (the twist).
#
# ⚠️ READABLE ONLY EMPTY-HANDED — the user's ruling, and Yume Nikki's relinquishment ending in
# one line: you have spent the whole level picking things up, and the last door opens for the
# player who is holding nothing. It adds NO gate that is not already mandatory (all three
# sockets gate the Morgue seal, the cradle gates the secret door), so it can never softlock: by
# the time anyone is standing here the condition is already true unless they are carrying
# something, and the fix for that is to walk it back and put it down.
# ⚠️ IT REFUSES BY NAME. Issue 226 — a prompt is a promise the action can succeed from HERE, so
# the refusal states the condition instead of offering E.
# ⚠️ SAFE, never a trap. A read-to-die note on the critical path is §8.11 by construction, and
# `note.gd` only archives non-trap notes, so this one is in the journal (TAB) afterwards.
# ⚠️ ZERO PANIC.
#
# ⚠️ `conceal()` / `reveal()` are `void_loop_note.gd`'s pattern and are IDEMPOTENT: the mesh and
# the collider leave the world entirely until the five frames line up, so the interact ray
# cannot even find it, and `move_aside_instantly()` is an alias for `reveal()` so
# `check_reachable.gd` probes it through the level's own restore path (the LabLocker rule)
# rather than by deleting a collider behind the level's back.

signal plate_should_retract

var level: Node = null

var _revealed := true
var _drop: AudioStreamPlayer3D = null


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


func _shapes() -> Array:
	var out: Array = []
	for c in get_children():
		if c is CollisionShape3D:
			out.append(c)
	return out


# ⚠️ Called by the level AFTER add_child: `_make_note()` adds the paper mesh and the collider as
# children of a node that is already in the tree, so `_ready()` has run before either exists and
# cannot hide them (void_loop_note.gd and void_shard.gd learned this the same way).
func conceal() -> void:
	_revealed = false
	visible = false
	for c in _shapes():
		(c as CollisionShape3D).set_deferred("disabled", true)


func reveal() -> void:
	if _revealed:
		return
	_revealed = true
	visible = true
	for c in _shapes():
		(c as CollisionShape3D).set_deferred("disabled", false)
	if _drop == null:
		var s := GameState.load_audio("paper_drop")
		if s:
			_drop = AudioStreamPlayer3D.new()
			_drop.name = "PaperDrop"
			_drop.stream = s
			# paper_drop measures -16.6 dBFS RMS and is read from ~1 m, like the loop note's
			# page: the same close, quiet treatment, set from the file and not from a number.
			_drop.volume_db = -9.0
			_drop.unit_size = 3.0
			_drop.bus = AudioBuses.AMBIENCE
			add_child(_drop)
	if _drop:
		_drop.play()
	_dbg("VOID hidden note REVEALED at the corridor's end %v" % global_position)


func is_revealed() -> bool:
	return _revealed


func move_aside_instantly() -> void:
	reveal()


# ⚠️ TRUE even while concealed, exactly as `void_loop_note.gd` does it: `can_interact()` false
# hides the prompt entirely, which is the right answer while there is no collider for the ray to
# find anyway — and once the frames settle the page has to be readable.
func can_interact() -> bool:
	return true


func _carrying() -> String:
	if level == null:
		return ""
	if bool(level.call("has_shard")):
		return "a stone shard"
	var a := String(level.call("carried_anchor"))
	return String(level.call("carried_label")) if a != "" else ""


func _put_back() -> bool:
	if level == null:
		return true
	return bool(level.call("everything_put_back"))


func prompt_text() -> String:
	var held := _carrying()
	if held != "":
		return "Your hands are not empty."
	if not _put_back():
		return "Put everything back first."
	return "E — Read the page."


func interact() -> void:
	var held := _carrying()
	if held != "":
		_dbg("VOID hidden note refused (carrying %s)" % held)
		return
	if not _put_back():
		_dbg("VOID hidden note refused (not everything is back)")
		return
	super()
	_dbg("VOID hidden note READ — plate retracting")
	plate_should_retract.emit()
