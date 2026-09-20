extends StaticBody3D

# The second half of the far wing's chain: the shard found in the Archive fits the child room's
# fractured cradle. Setting it completes the cradle — the slats, rails and runners tween level
# for the only time anything in this level agrees with itself.
#
# ⭐ 2026-09-20 pass 4 — WHAT COMPLETION PAYS CHANGED, and none of it is in this file. It used to
# retract the stone plate over the Sanctum's twist note, two rooms away, where nobody could see
# it: the 18:30 playtester stood here for 62 s afterwards and wrote *"the visuals and the effects
# were too weak."* `completed` now drives `level_3.gd:_on_cradle_completed()`, which fires the
# giving scare (`void_cradle_figure.gd`), opens the secret door in the Morgue's west wall and
# arms the drawing's change. The plate is the HIDDEN NOTE'S now. This script is unchanged
# otherwise, on purpose: the signal was always the seam.
#
# ⚠️ THE SCRIPT LIVES ON THE CRADLE'S OWN LAYER-1 BODY. A nested interact volume inside a
# solid prop is never reached by `player.gd`'s ray: the ray stops on the outer collider. The
# script therefore goes on the body `void_fragments.fractured_cradle()` already builds, via
# `_body(..., script)` which sets it BEFORE `add_child` so `_ready()` actually runs.
# ⚠️ Zero panic. CreatureE stands two metres away; that is the whole cost.

const FRAGMENTS := preload("res://scripts/void_fragments.gd")
const SETTLE_TIME := 1.1

signal completed

var done := false
# ⚠️ THE LEVEL OWNS THE INVENTORY, NOT GameState (2026-09-20 pass 3). Since the player can
# carry a stone shard AND one of the three anchors at the same time, `GameState.carried_item`
# is a COMPOSED HUD line ("a stone shard · a door handle") and testing it for equality with
# "stone shard" started returning false for a player who was holding one. Ask the level.
var level: Node = null
var _tween: Tween


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


func can_interact() -> bool:
	return not done


func _has_shard() -> bool:
	return level != null and bool(level.call("has_shard"))


func prompt_text() -> String:
	if _has_shard():
		return "E — Set the shard in the cradle."
	return "Something is missing from it."


func interact() -> void:
	if done or not _has_shard():
		return
	done = true
	level.call("consume_shard")
	_dbg("VOID cradle completed")
	_settle(false)
	completed.emit()


# `instant` skips the tween — used by `_restore_progress()` when the player walks back in
# having already done it, so the level never replays a one-shot beat (the Ward frame's rule).
func _settle(instant: bool) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	var parts: Array[Node3D] = []
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var nm := String(child.name)
		# Godot suffixes duplicate names ("FloatingSlat2"), hence begins_with.
		if nm.begins_with("FloatingSlat") or nm.begins_with("DetachedRail") or nm.begins_with("Runner"):
			parts.append(child as Node3D)
	if not instant:
		_tween = create_tween()
		_tween.set_parallel(true)
	for part in parts:
		if instant:
			part.rotation = Vector3.ZERO
		else:
			_tween.tween_property(part, "rotation", Vector3.ZERO, SETTLE_TIME).set_trans(Tween.TRANS_SINE)
	_place_shard()


func _place_shard() -> void:
	if get_node_or_null("SetShard") != null:
		return
	var bed := get_node_or_null("BrokenBed") as Node3D
	var at := Vector3(-0.16, 0.94, 0.14) if bed == null else bed.position + Vector3(0, 0.09, 0)
	var shard := FRAGMENTS._box(self, Vector3(0.20, 0.15, 0.12), at,
		FRAGMENTS._mat(FRAGMENTS.TINT_PALE), "SetShard")
	shard.rotation = Vector3(0.1, 0.35, -0.08)


func restore_state(was_done: bool) -> void:
	if not was_done or done:
		return
	done = true
	_settle(true)
