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
#
# ⭐ IT CLOSES AGAIN (2026-09-23 pass 8). Capture #1 of the 23:10 run, standing at the bank:
# *"You can open those brown cells but you cannot close them. Hard to find a note here, make it
# possible to close them."* Seventeen one-way fronts turn a search into a ratchet — you cannot
# undo a look, so the bank ends the level as a wall of open holes and the one that matters is
# indistinguishable from the sixteen that did not. E on a pulled front now slides it back over
# the same 0.25 s. The page rides in with it, and re-opening finds it exactly where it was.
#
# ⚠️ AN OPEN DRAWER'S INTERACT VOLUME IS THE BOTTOM 0.20 m OF THE FRONT — THE HANDLE — AND NOT
# THE WHOLE FACE, and that is the whole reason this is safe. Issue 231: the E-ray takes the
# NEAREST hit and `player.gd` nulls a target it cannot interact with rather than looking past
# it, so a full-face volume standing 0.09 m proud of a pulled front is a wall in front of the
# page that stands 0.10 m behind it. Measured on `Drawer4_1`: open, the page's aim point is at
# world y 1.14 and the shrunk volume spans y 0.71..0.91, so every ray that reaches the page
# from any standing cell passes at least 0.25 m above the volume (steepest case, eye 1.65 m at
# 0.5 m out: 1.24 vs 0.91). The volume is also exactly where a hand goes — pass 4 already put
# the pale handle box at local y -0.15, inside this band.

const SLIDE := 0.35
const SLIDE_TIME := 0.25
# The shut volume: the whole front, 0.09 m proud of the carcass (Issue 231's fix, unchanged).
const SHUT_BOX := Vector3(0.54, 0.54, 0.16)
const SHUT_AT := Vector3(0, 0, 0.09)
# …and the open one: the handle band only, so the page behind it is never occluded.
const OPEN_BOX := Vector3(0.54, 0.20, 0.16)
const OPEN_AT := Vector3(0, -0.17, 0.09)
# ⚠️ THE SAME FILE, 6 dB DOWN — not a reversed one. `drawer_pull` is a slide with a stop at the
# end and it reads much the same run backwards; what a SHUT differs in is loudness (you push it,
# you do not haul it), and a second .wav for that is a second base name to keep globally unique
# for no audible gain. -17.4 dBFS RMS at -14.5 dB delivers -31.9 dBFS at the source against the
# pull's -25.9: the same gesture, exactly 6 dB quieter.
const SHUT_DB := -14.5

signal opened
signal closed

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
	_shape.name = "DrawerFace"
	var box := BoxShape3D.new()
	box.size = SHUT_BOX
	_shape.shape = box
	_shape.position = SHUT_AT
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
	return true


func prompt_text() -> String:
	return "E — Close the drawer." if _open else "E — Pull the drawer."


func interact() -> void:
	if _open:
		_close()
	else:
		_pull()


func _pull() -> void:
	_open = true
	_slide(_home + Vector3(0, 0, SLIDE), -8.5)
	_fit_volume()
	_dbg("VOID drawer %d_%d pulled%s" % [col, row, "  (THE PAGE)" if holds_page else ""])
	opened.emit()


# ⚠️ THE PAGE IS A CHILD OF THIS BODY, so it rides back in with no code at all — and that is
# why it is still readable after a close and a second pull: nothing is freed, hidden or moved
# relative to the drawer, only the drawer moves. `check_void` opens, closes, re-opens and reads
# it through the real ray for exactly that reason.
func _close() -> void:
	_open = false
	_slide(_home, SHUT_DB)
	_fit_volume()
	_dbg("VOID drawer %d_%d closed%s" % [col, row, "  (THE PAGE)" if holds_page else ""])
	closed.emit()


func _slide(to: Vector3, db: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", to, SLIDE_TIME).set_trans(Tween.TRANS_SINE)
	if _audio:
		_audio.volume_db = db
		_audio.play()


# Restore / harness: the same end state with no tween and no sound.
func open_instantly() -> void:
	if _open:
		return
	_open = true
	if _tween:
		_tween.kill()
		_tween = null
	position = _home + Vector3(0, 0, SLIDE)
	_fit_volume()


# …and its mirror, for the restore path: a snapshot records the set that is OPEN, so a drawer
# missing from that set has to be SHUT again, not merely left alone (see `_restore_progress()`).
func close_instantly() -> void:
	if not _open:
		return
	_open = false
	if _tween:
		_tween.kill()
		_tween = null
	position = _home
	_fit_volume()


# ⚠️ AN OPENED DRAWER MUST STOP INTERCEPTING THE RAY ACROSS THE PAGE. Its interact box stands
# 0.09 m proud of the front and the page lies 0.10 m behind it, so a FULL-FACE box on a pulled
# front means the E-ray stops on the drawer and the page inside is unreadable (Issue 231, and
# the morgue poster's shape before it). Pass 3 answered that by disabling the shape outright,
# which is also why the drawer could not be closed. Pass 8 shrinks it to the handle band
# instead — small enough to leave every ray to the page clear (measured: 0.25 m of headroom in
# the steepest case), big enough to point at from a metre out.
func _fit_volume() -> void:
	if _shape == null:
		return
	var box := _shape.shape as BoxShape3D
	if box:
		box.size = OPEN_BOX if _open else SHUT_BOX
	_shape.position = OPEN_AT if _open else SHUT_AT
	# ⚠️ WRITTEN DIRECTLY, never `set_deferred` (Issue 252): a reachability probe or an E-ray in
	# the SAME frame as the press must see the new volume, and a deferred write lands after it.
	_shape.disabled = false


# check_reachable's gate hook — the level's own restore path, never a deleted collider.
func move_aside_instantly() -> void:
	open_instantly()


func is_open() -> bool:
	return _open
