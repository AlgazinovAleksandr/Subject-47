extends "res://scripts/note.gd"

# ⭐ THE TWIST NOTE REFUSES WHILE THE STONE STANDS (2026-09-20 pass 5, Issue 242).
#
# The Void's win condition is `TWIST_READ`, and until now the only thing between the player and
# it was a physical blocker: a 0.60 × 0.80 stone plate hanging 3 cm in front of a note of about
# the same size. The 23:33 playtest read this note 13 s after the cradle with NO frame step, no
# settle and no hidden-note read in the log — the whole Hall of Frames skipped — and capture 8
# shows why: from a grazing stance along the Sanctum's west wall the page shows BESIDE the slab.
# 6 cm of depth at 80° off-normal is 34 cm of parallax, so the interact ray reaches the note's
# collider past the plate's edge.
#
# ⚠️ GATE THE TARGET, NOT THE RAY. A blocker guards one viewing angle; a refusal on the thing
# being read guards all of them. The plate is still there (it is the thing the hidden note
# moves, and the thing whose prompt points at the far wing), but it is no longer load-bearing.
# ⚠️ IT REFUSES BY NAME — Issue 226: a prompt is a promise that the action can succeed from
# HERE, so the refusal states the world's condition instead of offering E.
# ⚠️ ZERO PANIC, no new fail state, no new unlock condition: `door.gd:UnlockCondition.TWIST_READ`
# and `note.gd`'s `is_twist_note` path are untouched, and this only ever returns EARLY.
# ⚠️ THE GATE IS THE LEVEL'S PLATE REFERENCE, not a copy of it. `level_3.gd` nulls
# `_sanctum_plate` in the same breath as `retract()` / `move_aside_instantly()`, so the one
# place that knows whether the stone has moved is the one place that is asked — including from
# `_restore_progress()`, where a snapshot with `hidden_note_read` unseals instantly and a
# return from the ending with `twist_read` does the same.

var level: Node = null


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


# The stone is up iff the level still owns a plate. ⚠️ `is_instance_valid` as well as the null
# check: `retract()` queue_frees at the END of a 0.9 s tween, and a freed node compares equal to
# null in Godot 4 (Issue 223) — the level nulls its own reference, so this is belt and braces.
func plate_stands() -> bool:
	if level == null or not is_instance_valid(level):
		return false
	return bool(level.call("plate_stands"))


# ⚠️ TRUE, like every other gated note in this level. `can_interact()` false would hide the
# prompt entirely and the page would read as scenery — the loop note's lesson.
func can_interact() -> bool:
	return true


func prompt_text() -> String:
	return "The stone covers it." if plate_stands() else "E — Read the page."


func interact() -> void:
	if plate_stands():
		_dbg("VOID twist note refused — the plate stands")
		return
	super()
