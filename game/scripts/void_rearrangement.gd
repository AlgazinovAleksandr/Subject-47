extends StaticBody3D

# Off-screen geometry mutation (SCARY.md P11). Two modes, one rule: NOTHING EVER CHANGES
# WHILE THE PLAYER IS LOOKING AT IT.
#
#   * touch mode (`arm_on_sight` false, the Ward frame): E arms it AND the thing you touched
#     moves under your eyes (pass 5's receipt); a later look away changes the sculpture five
#     metres off. The node is a layer-2 interactable carrying its own visible prop — since
#     2026-09-20 pass 5 a hospital gurney hung nose-down, not an abstract shard.
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

# ⭐ 2026-09-22 pass 6. Emitted by `interact()` the moment the touch lands, BEFORE the off-screen
# answer — so a level can hang a second, deliberately ON-SCREEN consequence on the same press.
# The Ward uses it to grind the strapped box open a metre away: capture #2 of the 23:47 run asked
# for "*a magical button that will open the magical box having this piece*", and a receipt that
# only moves the thing you touched still does not say what touching it was FOR.
# ⚠️ NOT emitted by `restore_state()` — a snapshot must never replay a one-shot beat.
signal touched

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
# ⭐ 2026-09-20 pass 5. The touch prop's colour family (the Ward is bone) and the RECEIPT the
# touched object gives under the player's own eyes before the off-screen answer. Set before
# `add_child`, like every other property here — `_ready()` builds the gurney from it.
var family := "violet"
var rearranged_rotation := Vector3(0, -0.45, 0.22)
var rearranged_offset := Vector3.ZERO
var _gurney: Node3D = null
var _receipt_grind: AudioStreamPlayer3D = null
var _receipt_tween: Tween = null
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
	# them, "20 cells in range, nearest 0.80 m"). Riding the prop's own body means the guard's
	# ray finds it and classifies it INERT, which is exactly what it is.
	if arm_on_sight:
		if sculpture == null:
			sculpture = self
		_player = get_parent().get_node_or_null("Player") as CharacterBody3D
		return
	collision_layer = 2
	collision_mask = 0
	_player = get_parent().get_node_or_null("Player") as CharacterBody3D
	# ⚠️ DEFERRED, AND THAT IS A BUG FIX (2026-09-20 pass 5). `arm_on_sight` is an @export set by
	# the CALLER, and the two sight-mode props cannot set it before `_ready()` runs: they are
	# built by `void_fragments._body()`, which attaches the script and calls `add_child()` in one
	# breath, so `level_3.gd:_arm_on_sight()` only gets to set the flag on the line AFTER the
	# node is already in the tree. Every sight-mode rearranger therefore ran this touch-mode
	# branch once — the Archive's inverted table and Hall3's door heap have been carrying a
	# 0.4 x 0.5 x 0.4 interact volume and a stray pale box at their origins for their whole
	# lives. Harmless while the prop was a 0.24 m shard; catastrophic the moment it became a
	# 2 m gurney, and measurable either way: the table's extra volume swallowed the interact ray
	# that has to reach the shard in its basin (`ai_interact_target -> nothing` from four
	# stances). A deferred call lands after the caller's next line, so the flag is final.
	# ⚠️ `collision_layer = 2` stays HERE, unconditionally, because that is the shipped world:
	# both sight-mode props are layer 2 today and the walk routes and reachability sweeps were
	# measured against it. Moving them back to layer 1 makes a table and a heap of doors solid,
	# which is a level change and not this pass's.
	call_deferred("_build_touch_prop")


func _build_touch_prop() -> void:
	if arm_on_sight:
		return
	# ⚠️ THE TOUCH VOLUME IS DELIBERATELY SMALLER THAN THE PROP, and this is measured, not shy.
	# The Ward's bed slat (`Anchor_slat`) lies at (-2.52, 0.10, 13.60), 0.3 m north of this node,
	# and it is picked up from (-2.5, 0, 12.5): that ray leaves an eye at y 1.75 and is down at
	# y 0.925 by z 13.05 and y 0.55 by z 13.30. This volume starts at y 1.25 and at z 13.08, so
	# the ray passes 0.33 m under it. The first draft (y 1.05, z 12.95) swallowed the slat — the
	# ray takes the NEAREST hit, and an anchor that gates the Morgue seal is a hard softlock.
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.00, 0.60, 0.50)
	col.shape = box
	col.position = Vector3(0.0, 0.30, 0.0)
	add_child(col)
	# ⭐ THE PROP IS A GURNEY NOW (2026-09-20 pass 5), not a 0.24 m pale box: *"they still should
	# represent some objects. This one is too unclear."* Bone family, boxes only, hung nose-down.
	_gurney = FRAGMENTS.gurney(self, Vector3.ZERO, 0.0, "HangingGurney", family)
	_build_receipt_grind()


func can_interact() -> bool:
	return not arm_on_sight and not armed and not spent


func prompt_text() -> String:
	return "" if arm_on_sight else "E — Touch the hanging gurney."


# ⭐ A CAUSE SHOWS A RECEIPT (2026-09-20 pass 5, Issue 243). Two hand playtests in a row said the
# same thing about this prop — *"nothing changes"* (18:30) and *"does it do something? I did not
# notice anything"* (23:33) — and both times it had worked exactly as built: the frame five
# metres away re-posed the moment the player looked elsewhere. SCARY.md P11's rule is that
# nothing changes WHILE WATCHED; it is not a rule that a touch may go unanswered. So the thing
# you touch now moves under your hand — 0.10 m down and 6° of yaw over 0.4 s, with a grind at
# the gurney itself — and the RIGHT frame still answers off-screen, unchanged.
# ⚠️ The receipt moves the VISUAL only. The touch volume stays where it is, because a collider
# that drops 0.10 m mid-frame is a prompt that flickers.
# ⚠️ ZERO PANIC, and one-shot by construction: `can_interact()` is false from the next frame.
const RECEIPT_DROP := 0.10
const RECEIPT_YAW := 0.105          # 6°
const RECEIPT_TIME := 0.4


func interact() -> void:
	if can_interact():
		armed = true
		_play_receipt()
		_dbg("VOID ward fragment ARMED (%s)" % name)
		touched.emit()


func _build_receipt_grind() -> void:
	var s := GameState.load_audio("stone_grind")
	if s == null:
		return
	# stone_grind measures -10.3 dBFS RMS — the loudest file in the level, and the level's "a
	# thing made of stone moved" sound. This one plays at ARM'S LENGTH (the player is inside
	# 3 m or the prompt would not be up), so it gets the quiet treatment: -9.0 dB at unit 2.0 is
	# about -6.5 dB effective at 1.5 m, a shade louder than the same file's distant answer from
	# the other frame (-8.0 at unit 5.0 over 5.2 m = -8.3 dB). The receipt is the near one.
	_receipt_grind = AudioStreamPlayer3D.new()
	_receipt_grind.name = "GurneyGrind"
	_receipt_grind.stream = s
	_receipt_grind.volume_db = -9.0
	_receipt_grind.unit_size = 2.0
	_receipt_grind.bus = AudioBuses.AMBIENCE
	add_child(_receipt_grind)


func _play_receipt() -> void:
	if _gurney == null or not is_instance_valid(_gurney):
		return
	var hang := _gurney.get_node_or_null("GurneyHang") as Node3D
	if hang == null:
		return
	if _receipt_tween:
		_receipt_tween.kill()
	_receipt_tween = create_tween().set_parallel(true)
	_receipt_tween.tween_property(hang, "position:y", hang.position.y - RECEIPT_DROP,
		RECEIPT_TIME).set_trans(Tween.TRANS_SINE)
	_receipt_tween.tween_property(hang, "rotation:y", hang.rotation.y + RECEIPT_YAW,
		RECEIPT_TIME).set_trans(Tween.TRANS_SINE)
	if _receipt_grind:
		_receipt_grind.play()
	_dbg("VOID gurney RECEIPT: dropped %.2f m and yawed %.0f deg under the player's eyes"
		% [RECEIPT_DROP, rad_to_deg(RECEIPT_YAW)])


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
