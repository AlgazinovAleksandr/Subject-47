extends "res://scripts/note.gd"

# ⭐ THE LOOP NOTE, 2026-09-20. The corridor note is the thing that BREAKS the loop, and it
# hangs at z 23 — nine metres before the seam at z 32. Both runs of the 2026-09-20 morning
# playtest read it on the first pass (150.56 s and 259.89 s), so the loop never fired once: no
# lap, no torn page, no `AGAIN.`, no creep. The beat was unreachable by a player walking
# normally, and the page was made illegible below lap 2.
#
# ⭐ AND SINCE PASS 2 IT IS NOT THERE AT ALL UNTIL LAP 2. The 13:10 playtester walked up to a
# visible page with a prompt that refused it and wrote *"weird that I can see this note but I
# cannot pick it up… make it invisible"*. A prompt that says no is a bug to a player; an empty
# wall that later has a page on it is the corridor. `conceal()` takes the mesh and the collider
# out of the world (so the interact ray cannot even find it), `reveal()` puts them back and
# drops a page onto the floor of the ear — `paper_drop`, positional, from the note itself.
#
# ⚠️ `reveal()` and `conceal()` are IDEMPOTENT and driven purely from `level_3._loop_laps`, so
# the seam, a snapshot restore and a test that sets the lap count by hand all land in the same
# world. The revealed state is derived, never stored.
# ⚠️ `move_aside_instantly()` is an ALIAS for `reveal()` — `check_reachable.gd:_open_gates()`
# prefers the game's own restore path over deleting a collider (the LabLocker rule), and this
# note is both a gate and a probe target.
# ⚠️ ZERO PANIC. Nothing in the ladder touches the bar; the cost is time and the corridor.

var laps := 0
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
			# paper_drop measures -16.6 dBFS RMS; the note is read from ~1 m, so this is a
			# close, quiet sound and the gain is set from that, not from a round number.
			_drop.volume_db = -9.0
			_drop.unit_size = 3.0
			_drop.bus = AudioBuses.AMBIENCE
			add_child(_drop)
	if _drop:
		_drop.play()
	_dbg("VOID LoopNote appears at lap %d (paper_drop at %v)" % [laps, global_position])


func is_revealed() -> bool:
	return _revealed


# check_reachable's gate hook: the reachability sweep asks the level to put itself into the
# solved state rather than deleting colliders behind its back.
func move_aside_instantly() -> void:
	reveal()


func can_interact() -> bool:
	# ⚠️ TRUE on purpose even while concealed. A `false` here hides the prompt
	# (`player.gd:_is_interactable`), which is the right answer while the note has no collider
	# for the ray to find anyway — and once it is revealed at lap 2 the page must be readable.
	return true


func prompt_text() -> String:
	if laps <= 0:
		return "The words will not hold still."
	if laps == 1:
		return "One line has settled. The rest will not."
	return "E — Read the page."


func interact() -> void:
	if laps < 2:
		_dbg("VOID LoopNote refused — lap %d of the 2 it wants" % laps)
		return
	super()
