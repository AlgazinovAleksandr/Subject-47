extends StaticBody3D

# ⭐ THE WARD BOX (2026-09-22 pass 6) — the one prop in this level that changes UNDER YOUR EYES.
#
# The 23:47 run photographed the Ward twice. Capture #1, of `FoldedFrame_Ward_L`: *"the object
# closer to the monster looks like a bed, but the one … further away … still does not remind
# anything … like a gift box"*. Capture #2, of the gurney's receipt: *"The visuals of you touching
# the bed are weak … how it logically helps getting a piece from the other room. Should it be like
# a magical button that will open the magical box having this piece?"*
#
# So: the frame is a sealed strapped box (`void_fragments.strapped_box`), the bed slat is inside
# it, and touching the gurney a metre away grinds the lid back IN PLAIN VIEW.
#
# ⚠️ THIS DELIBERATELY BREAKS SCARY.md P11 — "nothing changes while you are looking" — FOR THIS
# ONE PROP, and that is the user's ruling, not a lapse. The off-screen version of this cause was
# photographed as *"nothing happened"* in two consecutive playtests (Issue 243), and the receipt
# added in pass 5 answered the touch without ever answering the QUESTION ("what was that for?").
# The right frame five metres away keeps its off-screen answer as atmosphere, so the rule still
# governs the level; it is suspended for the one object the player is being asked to understand.
#
# ⚠️ TWO GATES, ON PURPOSE (Issue 242's ruling, applied forward). The shut lid is a real collider
# that a descending E-ray stops on — but a blocker guards ONE viewing angle, so `void_anchor.gd`
# ALSO refuses on the slat itself (*"The box is sealed."*) while `is_open()` is false. The
# physical lid is defence in depth; the refusal is the gate.
# ⚠️ ZERO PANIC on every path, no fail state. The gurney's touch is a plain E that is always
# available, so the slat — which gates the Morgue seal — can never be locked away (softlock).
# ⚠️ `move_aside_instantly()` is `check_reachable.gd`'s gate hook: the sweep asks the level to put
# itself into the state a player reaches rather than deleting a collider behind its back (the
# LabLocker rule). It is the SILENT form, like every other restore path in this level.

signal opened

# 0.8 s of lid, per the pass-6 spec. The grind leads it by GRIND_LEAD so the receipt at the
# gurney and the answer at the box read as cause and effect rather than as one doubled sample —
# they are 1.2 m apart and both play `stone_grind`.
const OPEN_TIME := 0.8
const GRIND_LEAD := 0.18
# Past vertical: the slab lifts and falls back over the far side, clear of the approach.
const OPEN_ANGLE := -2.1

var _open := false
var _tween: Tween = null
var _grind: AudioStreamPlayer3D = null


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


# ⚠️ Resolved lazily, never in `_ready()`. `void_fragments._body()` sets the script and calls
# `add_child()` in one breath, so `_ready()` runs before a single child of this node exists
# (`void_loop_note.gd`'s rule, learned the same way, and Issue 244's shape).
func _lid() -> Node3D:
	return get_node_or_null("WardBoxLid") as Node3D


func _lid_shape() -> CollisionShape3D:
	return get_node_or_null("WardBoxLidShape") as CollisionShape3D


func open(animated: bool = true) -> void:
	if _open:
		return
	_open = true
	var lid := _lid()
	# ⚠️ DEFERRED FOR THE ANIMATED PATH, IMMEDIATE FOR THE SILENT ONE, and the difference is a
	# measured bug. `set_deferred` lands at the END of the frame; `check_reachable.gd` opens its
	# gates and probes in the SAME frame, so the deferred form left the lid's collider in place
	# for the whole sweep and the bed slat inside the box measured UNREACHABLE (20 standing
	# cells in range, no ray). The silent form is a restore/gate call — never inside a physics
	# query flush — so it can write the flag directly; the E-press form keeps the deferral.
	var shape := _lid_shape()
	if shape:
		if animated:
			shape.set_deferred("disabled", true)
		else:
			shape.disabled = true
	if lid == null:
		return
	if not animated:
		lid.rotation.x = OPEN_ANGLE
		opened.emit()
		return
	if _grind == null:
		_build_grind()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(GRIND_LEAD)
	_tween.tween_callback(_play_grind)
	_tween.tween_property(lid, "rotation:x", OPEN_ANGLE, OPEN_TIME).set_trans(Tween.TRANS_SINE)
	# ⚠️ NO LOG LINE HERE. `level_3.gd:open_ward_box()` writes the pass-6 instrumentation line
	# `VOID ward box OPENED`, and a second one from this node put the same event in the playtest
	# log twice — which is how a reader counts two openings of a one-shot box.
	opened.emit()


func _play_grind() -> void:
	if _grind and is_instance_valid(_grind):
		_grind.play()


# `stone_grind` measures -10.3 dBFS RMS — the loudest file in the level and its "a thing made of
# stone moved" sound. The player is inside 3 m when this fires (they have just pressed E on the
# gurney, 1.2 m away), so it gets the near treatment: -9.5 dB at unit 3.0 clamps to the +3 dB
# max_db at that distance, i.e. about -6.5 dB effective — level with the gurney's own receipt
# (-9.0 / unit 2.0 = -6.5 at 1.5 m) and 0.18 s behind it.
func _build_grind() -> void:
	var s := GameState.load_audio("stone_grind")
	if s == null:
		return
	_grind = AudioStreamPlayer3D.new()
	_grind.name = "WardBoxGrind"
	_grind.stream = s
	_grind.volume_db = -9.5
	_grind.unit_size = 3.0
	_grind.bus = AudioBuses.AMBIENCE
	add_child(_grind)


func move_aside_instantly() -> void:
	open(false)


func is_open() -> bool:
	return _open


# ⚠️ INERT ONCE OPEN. While the box is shut it is the thing the ray finds and the thing that
# explains itself; the moment the lid is back the prompt must belong to the slat inside it, and
# `can_interact() == false` makes this node stop competing for the ray's verdict entirely
# (player.gd:_is_interactable — the LabLocker's mechanism).
func can_interact() -> bool:
	return not _open


func prompt_text() -> String:
	return "The box is sealed."


# ⚠️ A CONDITION, NOT A PROMISE (Issue 226). The prompt states what is true; E does nothing and
# costs nothing. The thing that opens it is the gurney, which is 1.2 m away and always available.
func interact() -> void:
	if not _open:
		_dbg("VOID ward box refused — sealed")


# ── test surface ────────────────────────────────────────────────────────────────
func lid_angle() -> float:
	var lid := _lid()
	return lid.rotation.x if lid else 0.0
