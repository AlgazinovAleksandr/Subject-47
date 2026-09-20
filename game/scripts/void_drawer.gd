extends StaticBody3D

# ⭐ SEARCH — one of the Morgue's seventeen drawer fronts (2026-09-20 pass 3).
#
# The 15:00 playtester finished the level in 564 s and wrote *"we need at least 1-2
# subchallenges in this level — for now the vibe is really good but it is underpacked with the
# action"*. The drawer bank was scenery. E now pulls a front out 0.35 m over 0.25 s with a
# `drawer_pull`, once. **Sixteen of the seventeen hold nothing at all** — the search is the
# challenge, and a search where every container pays is a queue, not a search.
#
# ⚠️ ZERO PANIC, no fail state, no timer. The Morgue's `DarkZone` charges only with the torch
# OFF, and searching a drawer bank does not ask you to turn it off — Issue 18, never tax the
# posture the puzzle requires.
# ⚠️ Layer 2 (raycast-hittable, walk-through) and the collider stands 0.09 m PROUD of the
# carcass's own layer-1 box: the E-ray takes the nearest hit, so a volume flush with the
# cabinet is a volume nobody can point at.
# ⚠️ The page rides INSIDE this body, so it slides out with the front. While the drawer is
# shut the page is behind the carcass and `check_reachable` classifies it CONTAINED — reached
# by opening its host, the Lab `HintPage`-in-a-drawer rule.

const SLIDE := 0.35
const SLIDE_TIME := 0.25

signal opened

var col := 0
var row := 0
var holds_page := false

var _open := false
var _home := Vector3.ZERO
var _audio: AudioStreamPlayer3D
var _tween: Tween
var _shape: CollisionShape3D


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	_home = position
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.54, 0.54, 0.16)
	_shape.shape = box
	_shape.position = Vector3(0, 0, 0.09)
	add_child(_shape)
	var s := GameState.load_audio("drawer_pull")
	if s:
		_audio = AudioStreamPlayer3D.new()
		_audio.name = "DrawerPull"
		_audio.stream = s
		# drawer_pull measures -17.4 dBFS RMS, 0.8 dB under paper_drop, and is heard from
		# arm's length like it: the same treatment, 0.5 dB hotter.
		_audio.volume_db = -8.5
		_audio.unit_size = 3.0
		_audio.bus = AudioBuses.AMBIENCE
		add_child(_audio)


func can_interact() -> bool:
	return not _open


func prompt_text() -> String:
	return "E — Pull the drawer."


func interact() -> void:
	if _open:
		return
	_open = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", _home + Vector3(0, 0, SLIDE), SLIDE_TIME) \
		.set_trans(Tween.TRANS_SINE)
	if _audio:
		_audio.play()
	_retire()
	_dbg("VOID drawer %d_%d pulled%s" % [col, row, "  (THE PAGE)" if holds_page else ""])
	opened.emit()


# Restore / harness: the same end state with no tween and no sound.
func open_instantly() -> void:
	if _open:
		return
	_open = true
	if _tween:
		_tween.kill()
		_tween = null
	position = _home + Vector3(0, 0, SLIDE)
	_retire()


# ⚠️ AN OPENED DRAWER MUST STOP INTERCEPTING THE RAY. Its interact box stands 0.09 m proud of
# the front and the page lies 0.23 m behind it, so leaving the box live means the E-ray stops
# on a drawer that refuses (`can_interact()` false) and the player gets NO prompt at all —
# `player.gd` nulls a non-interactable target, it does not look past it. The page inside would
# have been unreadable for the same reason the morgue poster was unreachable.
func _retire() -> void:
	if _shape:
		_shape.set_deferred("disabled", true)


# check_reachable's gate hook — the level's own restore path, never a deleted collider.
func move_aside_instantly() -> void:
	open_instantly()


func is_open() -> bool:
	return _open
