extends StaticBody3D

# A slab of the Sanctum's own wall, sitting 3 cm in front of the twist note. It is not a
# door and not a puzzle: it says "The stone will not move." and it means it. It retracts
# when the hidden note at the end of the Hall of Frames is read, and nothing else moves it.
#
# ⭐ 0.90 × 1.10, NOT 0.60 × 0.80 (2026-09-20 pass 5, Issue 242). At the old size it covered a
# 0.4 × 0.5 note face-on and NOT from a grazing stance along the wall: 6 cm of depth at 80° off
# normal is 34 cm of parallax, so a third of the page showed beside the slab and the interact
# ray reached the note's collider past the plate's edge — the level's win condition, read with
# the whole far-wing chain skipped. The slab now overhangs the note by 25 cm on each side and
# 30 cm top and bottom, and it is no longer the only gate: `void_twist_note.gd` refuses by name
# while this node is alive. **A blocker guards one viewing angle; a refusal guards all of them.**
# ⚠️ NOT flush with the wall in the coplanar sense — its back face is 0.13 m clear of the wall
# face at x -17.90 and 0.09 m clear of the note's paper quad. Two visible surfaces in one plane
# is this project's most common bug class; "flush" here means "covering", not "touching".
#
# ⚠️ Layers 1|2 (`collision_layer = 3`): layer 1 so it intercepts the interact ray BEFORE the
# note behind it, layer 2 so the refusal prompt appears at all. It hangs on a wall that has
# no doorway in it — never plug a room's only opening (the Records-sign lesson).
# ⚠️ `move_aside_instantly()` exists for `check_reachable.gd`, which prefers a level's own
# restore path to deleting a collider. Without it the TwistNote measures UNREACHABLE.

const FRAGMENTS := preload("res://scripts/void_fragments.gd")
const RETRACT_TIME := 0.9
const RETRACT_DROP := 0.85

# ⭐ 2026-09-20 pass 4. The plate no longer retracts on the cradle — the hidden note behind the
# secret door does. So a player who has just completed the cradle and walked back here would read
# *"The stone will not move."*, which states a condition they cannot act on and have in fact
# already half-satisfied: Issue 226's exact shape, in words instead of a prompt. The level sets
# this the moment the cradle completes, and the line becomes a POINTER.
var moved_elsewhere := false

var _tween: Tween


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


func _ready() -> void:
	collision_layer = 3
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Local z is the thin axis so the caller's yaw convention matches note.gd's exactly.
	box.size = Vector3(0.92, 1.12, 0.06)
	shape.shape = box
	add_child(shape)
	var stone := FRAGMENTS._mat(Color(0.26, 0.23, 0.31))
	FRAGMENTS._box(self, Vector3(0.90, 1.10, 0.06), Vector3.ZERO, stone, "PlateFace")
	# Two shallow ribs so it reads as a fitted slab rather than a floating rectangle.
	for y in [-0.39, 0.39]:
		FRAGMENTS._box(self, Vector3(0.94, 0.05, 0.03), Vector3(0, y, 0.035),
			FRAGMENTS._mat(FRAGMENTS.TINT_DARK), "PlateRib")


func can_interact() -> bool:
	return true


func prompt_text() -> String:
	if moved_elsewhere:
		return "Something else was opened instead."
	return "The stone will not move."


func interact() -> void:
	pass


func retract() -> void:
	if _tween:
		return
	_dbg("VOID sanctum plate retracting — the twist note is exposed")
	_tween = create_tween()
	_tween.tween_property(self, "position:y", position.y - RETRACT_DROP, RETRACT_TIME).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(queue_free)


func move_aside_instantly() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	queue_free()
