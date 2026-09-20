extends StaticBody3D

# Off-screen geometry mutation (SCARY.md P11). Two modes, one rule: NOTHING EVER CHANGES
# WHILE THE PLAYER IS LOOKING AT IT.
#
#   * touch mode (`arm_on_sight` false, the Ward frame): E arms it; a later look away
#     changes the sculpture. The node is a layer-2 interactable with its own visible shard.
#   * sight mode (`arm_on_sight` true, 2026-09-20 — the Hall3 door heap and the Archive's
#     inverted table): arming is free. Looking AT the prop for one frame from inside 8 m with
#     a clear line arms it; the first look away re-poses it. No prompt, no collider, no panic.
#
# ⚠️ Zero panic in either mode, deliberately. GAME_MECHANICS_IDEAS' governing finding is
# "stop adding panic terms, start adding channels" — this is a channel.
const FRAGMENTS := preload("res://scripts/void_fragments.gd")

const SIGHT_RANGE := 8.0
const SIGHT_DOT := 0.6

# ⭐ 2026-09-20 pass 3. Emitted the moment the sculpture actually re-poses, so a level can
# hang a consequence on the beat instead of polling `spent`. The Archive's inverted table uses
# it to expose the stone shard in its basin: the rearrangement IS the reveal, which is why the
# shard cannot be found by walking past.
# ⚠️ NOT emitted by `restore_state()` — a snapshot restore must never replay a one-shot beat
# (the Ward frame's rule). The level derives the restored world from `spent` instead.
signal rearranged

@export var arm_on_sight := false

var spent := false
var armed := false
var sculpture: Node3D
# Which child of `sculpture` moves, and where to. Defaults reproduce the Ward frame exactly.
var target_child := "SuspendedAssembly"
# ⭐ 2026-09-20 pass 4 — THE DISTANCE GATE, and it is the fix for a real bug. The 18:30 log has
# `WardFragment ARMED` at 50.52 s and `rearranged off-screen` at **107.11 s**, two rooms away:
# the re-pose fired on the first look-away FROM ANYWHERE, so the player touched a thing in the
# Ward and the consequence happened 57 s later where nobody could see it ("*nothing changes*").
# With a rect set, the re-pose only fires while the player's XZ is still inside it. Empty (the
# default) keeps the old behaviour for the two sight-mode props, which are their own rooms.
var room_rect: Rect2 = Rect2()
var rearranged_rotation := Vector3(0, -0.45, 0.22)
var rearranged_offset := Vector3.ZERO
var _home_position := Vector3.ZERO
var _home_captured := false
var _player: CharacterBody3D


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


func _ready() -> void:
	# ⚠️ IN SIGHT MODE THE SCRIPT LIVES ON THE PROP'S OWN SOLID BODY, not on a separate marker.
	# A marker node would be a Node3D with `interact()` and no reachable collider, which
	# `check_reachable.gd` correctly reports as an UNREACHABLE interactable (measured: two of
	# them, "20 cells in range, nearest 0.80 m"). Riding the prop's own layer-1 body means the
	# guard's ray finds it and classifies it INERT, which is exactly what it is.
	if arm_on_sight:
		if sculpture == null:
			sculpture = self
		_player = get_parent().get_node_or_null("Player") as CharacterBody3D
		return
	collision_layer = 2
	collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.5, 0.4)
	col.shape = box
	add_child(col)
	var shard := FRAGMENTS._box(self, Vector3(0.24, 0.33, 0.22), Vector3.ZERO,
		FRAGMENTS._mat(FRAGMENTS.TINT_PALE), "TouchFragment")
	shard.rotation = Vector3(0.2, 0.3, -0.3)
	_player = get_parent().get_node_or_null("Player") as CharacterBody3D


func can_interact() -> bool:
	return not arm_on_sight and not armed and not spent


func prompt_text() -> String:
	return "" if arm_on_sight else "E — Touch the suspended fragment."


func interact() -> void:
	if can_interact():
		armed = true
		_dbg("VOID ward fragment ARMED (%s)" % name)


func _target() -> Node3D:
	if not is_instance_valid(sculpture):
		return null
	return sculpture.get_node_or_null(target_child) as Node3D


func _process(_delta: float) -> void:
	if spent or not is_instance_valid(_player) or not is_instance_valid(sculpture):
		return
	var camera := _player.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		return
	var centre := sculpture.global_position + Vector3(0, 1.3, 0)
	var to_prop := centre - camera.global_position
	var looking: bool = (-camera.global_basis.z).dot(to_prop.normalized()) > 0.1
	if not armed:
		if not arm_on_sight:
			return
		# Arm the first time it is genuinely SEEN: in front, close, and not through a wall.
		if to_prop.length() > SIGHT_RANGE or (-camera.global_basis.z).dot(to_prop.normalized()) < SIGHT_DOT:
			return
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, centre)
		query.exclude = [_player.get_rid(), get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return
		armed = true
		_dbg("VOID prop %s armed on sight" % name)
		return
	if looking:
		return
	# ⚠️ ...AND ONLY WHILE THE PLAYER IS STILL IN THE ROOM. Waiting is not the same as leaving.
	if room_rect.has_area() and not room_rect.has_point(
			Vector2(_player.global_position.x, _player.global_position.z)):
		return
	spent = true
	armed = false
	_apply_configuration()
	_dbg("VOID prop %s rearranged off-screen" % name)
	rearranged.emit()


func _apply_configuration() -> void:
	var assembly := _target()
	if assembly == null:
		return
	if not _home_captured:
		_home_position = assembly.position
		_home_captured = true
	assembly.rotation = rearranged_rotation if spent else Vector3.ZERO
	assembly.position = _home_position + (rearranged_offset if spent else Vector3.ZERO)


func restore_state(was_spent: bool, was_armed: bool) -> void:
	spent = was_spent
	armed = was_armed and not spent
	_apply_configuration()
