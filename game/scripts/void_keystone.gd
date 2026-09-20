extends StaticBody3D

# One of the three perspective SOCKETS (`void_alignment.gd` owns the puzzle; the island's
# socket IS that node, these two are its children for the BED and WINDOW viewpoints).
#
# ⚠️ THE PROMPT NEVER REPORTS ALIGNMENT. It read "The fragments do not meet." / "E — Hold the
# shape." before 2026-09-20, which is SCARY.md §8.2's alignment readout and the reason the
# puzzle was solved in under two seconds.
#
# ⭐ AND SINCE 2026-09-20 pass 2 IT IS GATED BY PLACE. `can_interact()` is false unless the
# player is standing within `GATE_RADIUS` of THIS view's feet, so the prompt appearing means
# "you are on the right tile" and nothing else. The 13:10 playtest pressed a keystone 20 times
# from wherever it happened to be reachable — including from the tile NEXT DOOR — so a wrong
# press taught nothing. Now a wrong press can only ever mean "wrong angle".
#
# ⭐ AND SINCE PASS 3 IT STARTS EMPTY. *"The buttons for pressing still all look the same"* —
# they were one `Vector3(0.16, 0.30, 0.30)` box in one colour for all three views, and all
# three shapes fell in 8.7 s. The socket holds nothing until you carry its object here from
# somewhere else in the level; the object then IS the keystone, in its own silhouette and its
# own family's colour, and the look-and-hold runs from there exactly as before.
#
# ⚠️ Every branch is delegated to the puzzle (`socket_*`), so view 0 — whose body is the
# puzzle node itself — and views 1 and 2 cannot drift apart. That drift is what made the
# pass-1 keystones two implementations of one rule.

const FRAGMENTS := preload("res://scripts/void_fragments.gd")

var puzzle: Node = null
var view := 0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.36, 0.48, 0.48)
	shape.shape = box
	add_child(shape)


func can_interact() -> bool:
	if puzzle == null or bool(puzzle.call("view_solved", view)):
		return false
	return bool(puzzle.call("gate_open", view))


func prompt_text() -> String:
	return "" if puzzle == null else String(puzzle.call("socket_prompt", view))


func interact() -> void:
	if puzzle:
		puzzle.call("socket_interact", view)
