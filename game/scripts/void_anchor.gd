extends StaticBody3D

# ⭐ A CARRIED ANCHOR (2026-09-20 pass 3): the door handle, the bed slat, the window latch.
#
# What this replaced: three identical stone diamonds that stood at their own viewpoints from
# the moment the level loaded. The 15:00 playtester solved all three shapes in 8.7 s and wrote
# *"The buttons for pressing still all look the same — shall we figure out how to hide them,
# make it more like a quest, make them different shapes and colours?"* Each viewpoint now
# carries an empty SOCKET, and the thing that fills it is hidden somewhere earlier in the
# level: the handle in PocketA beside a trap note, the slat inside the Ward's folded frame,
# the latch inside the flat doorframe in Hall2 that drops you thirty metres backwards if you
# stand in it too long.
#
# ⚠️ ONE AT A TIME, and the refusal is in the PROMPT, never in a silent no-op — the cradle's
# rule ("Something is missing from it."). `can_interact()` stays true so the prompt is shown;
# the prompt says whether E will do anything. Issue 226 is about a prompt that PROMISES an
# action that cannot succeed, which is a different thing from one that states a condition.
# ⚠️ ZERO PANIC on every path, including the refusals. No fail state: every anchor has exactly
# one socket that accepts it, so a full pair of hands can always be emptied.
# ⚠️ Layer 2 — raycast-hittable, walk-through — so an anchor lying inside a prop's footprint
# can still be taken. The prop's OWN solid collider is what the ray has to clear, which is why
# the slat lies at the folded frame's open mouth and the latch sits inside a frame with no
# collider at all.

const FRAGMENTS := preload("res://scripts/void_fragments.gd")

signal taken

var anchor_id := "handle"          # "handle" | "slat" | "latch"
var label := "a door handle"       # how the HUD's carried line names it
var family := "tar"
var pose := Vector3.ZERO           # rotation of the silhouette where it LIES in the world
var level: Node = null             # the level owns the inventory, not GameState

var _gone := false


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Generous: these are small objects lying among bigger ones, and the E-ray is 3 m of
	# a single line. 0.36 m is the shard's own volume, which a playtester found under a slab.
	box.size = Vector3(0.36, 0.36, 0.36)
	shape.shape = box
	add_child(shape)
	var art := FRAGMENTS.anchor_mesh(self, anchor_id, family)
	art.rotation = pose


func can_interact() -> bool:
	return not _gone


func prompt_text() -> String:
	if level != null and String(level.call("carried_anchor")) != "":
		return "Your hands are full."
	return "E — Take %s." % label


func interact() -> void:
	if _gone or level == null:
		return
	if String(level.call("carried_anchor")) != "":
		_dbg("VOID anchor %s refused — already carrying %s" % [anchor_id, level.call("carried_anchor")])
		return
	_gone = true
	taken.emit()
	# ⚠️ THE LEVEL FREES THE BODY, not this script. Two owners of one node's lifetime is how a
	# snapshot restore ends up with an anchor that is both carried and still lying on the floor:
	# the restore path has to be able to remove an anchor it never saw taken.
	level.call("take_anchor", anchor_id)
