extends StaticBody3D
class_name UseProp

# A generic "press E on this" prop — the Intake Wing's straps, tap and reel-to-reel (2026-09-24).
#
# ⚠️ DELIBERATELY DUMB. The prop reports that it was used and how many times; the LEVEL owns what
# that means (a buckle sound, water, a tape, a door buzzing open). That is the prop-emits /
# level-decides split `cellar_gate.gd` and `bottle_item.gd` already use, and it is why there is no
# bespoke strap.gd / tap.gd / reel.gd — three one-line scripts would each grow their own copy of
# the same guards.
#
# Layer 2 / mask 0, `note.gd`'s convention: raycast-hittable and NOT solid. The straps sit across
# the bed the player wakes on, inside the player's own capsule; on layer 1 they would shove the
# player off the mattress (and `check_spawn_blocked.gd` would be right to say so).
#
# The level builds the visual as children of this body and gives it a CollisionShape3D; this
# script adds nothing visual of its own.

signal used(times: int)

const INTERACTABLE_LAYER := 2

@export var prompt: String = ""
@export var max_uses: int = 1          # 0 = unlimited (the tap toggles)
@export var enabled: bool = true

var times_used: int = 0


func _ready() -> void:
	collision_layer = INTERACTABLE_LAYER
	collision_mask = 0


func can_interact() -> bool:
	return enabled and (max_uses <= 0 or times_used < max_uses)


func prompt_text() -> String:
	return prompt if prompt != "" else "Press E"


func interact() -> void:
	if not can_interact():
		return
	times_used += 1
	used.emit(times_used)


# A size-and-offset convenience so the level does not repeat the three-line collider dance.
func add_box_shape(size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = offset
	add_child(col)
