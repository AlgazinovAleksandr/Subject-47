extends "res://scripts/door.gd"

# ⭐ THE DOOR THAT ASSEMBLES ITSELF (2026-09-20 pass 3). The Void's exit only, set on the body
# in `level_3.gd:_make_door()`; the BackDoor keeps plain `door.gd`.
#
# The 15:00 playtester finished the level and wrote *"When we open the door leading to the intro
# room with the end — I think it would be cool to have some kind of animation."* Every doorway
# in this level is a thing that does not assemble: the perspective memories, the frame lying
# flat in Hall2, the heap of doors in Hall3, and the seven floating sub-rects of this door's own
# leaf. On the last press of the game they slide into their true places, the gaps close, the
# askew slab falls into line, and for 0.3 s the Void contains ONE whole object. Then it opens
# onto the corrupted intro.
#
# ⚠️ TOKEN FIRST, ANIMATION SECOND — and that ordering IS the fix, not a style choice (Issue
# 219). If the 1.2 s ran before `begin_transition()`, a panic death inside it would claim the
# transition, restart the level, and THEN this coroutine would wake on the restarted scene,
# take a fresh token of its own and advance a player who had just died into the ending. Taking
# the token first makes the press and the death race by exactly the same shared rule as every
# other door in the game: the first one to claim it wins, and the loser's callback is refused.
# ⚠️ `await super._open_door()` is never used — the parent opens after 0.5 s and completes the
# transition itself, so calling it would complete twice with two different tokens.
# ⚠️ ZERO PANIC, no new fail state. The slabs are `Node3D`s with no collider; nothing the
# player can stand on or be hit by moves.

const ASSEMBLE_TIME := 0.9
const HOLD_TIME := 0.3

var _assembling := false
var _assembly: Tween
var _grind: AudioStreamPlayer3D


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


func _slabs() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in get_children():
		if c is Node3D and String(c.name).begins_with("LeafSlab_"):
			out.append(c as Node3D)
	return out


func _open_door() -> void:
	if not goes_back and not advances_level:
		return
	var token := GameState.begin_transition("door")
	if token < 0:
		return
	_start_assembly()
	# One timer for the whole 1.2 s rather than `await tween.finished`: a tween belongs to this
	# node, and a node freed by a competing scene change takes its signal with it.
	await get_tree().create_timer(ASSEMBLE_TIME + HOLD_TIME).timeout
	GameState.complete_door_transition(token, goes_back)


func _start_assembly() -> void:
	if _assembling:
		return
	_assembling = true
	var slabs := _slabs()
	_dbg("VOID exit door ASSEMBLING (%d slabs, %.1f s + %.1f s hold)"
		% [slabs.size(), ASSEMBLE_TIME, HOLD_TIME])
	if _grind == null:
		var s := GameState.load_audio("stone_grind")
		if s:
			_grind = AudioStreamPlayer3D.new()
			_grind.name = "OpenAudio"
			# stone_grind measures -10.3 dBFS RMS, the loudest of this level's one-shots, so it
			# gets the quietest gain — the same pair the loop's wall plug is set from.
			_grind.volume_db = -8.0
			_grind.unit_size = 5.0
			_grind.stream = s
			_grind.bus = AudioBuses.AMBIENCE
			add_child(_grind)
	if _grind:
		_grind.play()
	if _assembly:
		_assembly.kill()
	_assembly = create_tween()
	_assembly.set_parallel(true)
	for slab in slabs:
		_assembly.tween_property(slab, "position", slab.get_meta("true_position", slab.position),
			ASSEMBLE_TIME).set_trans(Tween.TRANS_SINE)
		_assembly.tween_property(slab, "rotation", slab.get_meta("true_rotation", Vector3.ZERO),
			ASSEMBLE_TIME).set_trans(Tween.TRANS_SINE)
		_assembly.tween_property(slab, "scale", slab.get_meta("true_scale", Vector3.ONE),
			ASSEMBLE_TIME).set_trans(Tween.TRANS_SINE)


func is_assembling() -> bool:
	return _assembling


# The end state with no tween, no sound and no transition — what `screenshot_scene.gd` shoots
# and what `check_void` measures against the stored sub-rects. ⚠️ Never call this from the
# game: opening the door is the only thing that may assemble it.
func snap_assembled() -> void:
	for slab in _slabs():
		slab.position = slab.get_meta("true_position", slab.position)
		slab.rotation = slab.get_meta("true_rotation", Vector3.ZERO)
		slab.scale = slab.get_meta("true_scale", Vector3.ONE)
