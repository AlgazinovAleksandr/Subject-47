extends Node

# ⭐ THE STARE DIRECTOR (2026-09-20, the Void only). The user's call after capture #2: a creature
# that never moves while watched, and a stare that is PAID FOR — "not only panic rises, but maybe
# some hallucinations, maybe some weird sounds, some whispers". The whisper lives on the stalker
# (`CreatureStalker.whisper`); this node owns the hallucinations.
#
# It is SCARY.md P8 — the diegetic sanity-effect suite — driven by continuous stare time instead
# of the panic ratio, plus a P3 Watcher flash. Every effect is self-reverting, none touches
# `_panic`, none can kill: a scare with a number can be optimised against and one without cannot.
# ApparitionDirector's fairness gates apply verbatim (paused tree, open note, frozen input), and
# the blink is never fired while the player stands on the tiles — a black screen over a fatal pit
# would be §8.11, the unavoidable coin-flip death.
#
# Ladder: at STARE_FIRST seconds of continuous stare at ONE stalker, then every STARE_EVERY after,
# ONE effect fires, cycling blink → panic-bar lie → scrawl → lamp dim. A look-away resets the ladder
# for that stalker (`stare_time()` resets to 0 the frame you stop looking).

const STARE_FIRST := 6.0
const STARE_EVERY := 6.0
const LID_CLOSE := 0.12
const LID_HOLD := 0.25
const LID_OPEN := 0.20
const LIE_RATIO := 0.98
const LIE_SECONDS := 0.8
const LAMP_DIM := 0.2
const LAMP_DIM_SECONDS := 1.0
const LAMP_SEARCH := 12.0
const WATCHER_AHEAD := 1.2
# ⚠️ No "YOU BLINKED." — the blink is its own animation now (2026-09-20 capture #9: the line read as a bug).
const SCRAWLS := ["STOP LOOKING.", "IT IS NOT LOOKING BACK.", "COUNT THE PIECES.", "IT REMEMBERS YOUR FACE."]
const EFFECTS := ["blink", "lie", "scrawl", "lamp"]

const _VOID_VISUAL := preload("res://scripts/void_creature_visual.gd")

var _level: Node3D
var _thresholds: Dictionary = {}   # stalker id -> stare seconds at which the next effect fires
var _cycle: int = 0
var _scrawl_index: int = 0
var _busy: bool = false
var _blink_layer: CanvasLayer
var _lid_top: Panel
var _lid_bottom: Panel
var _blink_audio: AudioStreamPlayer
var _watcher: Node3D
var _fired: int = 0
var _last_effect: String = ""


func _ready() -> void:
	_level = get_parent() as Node3D
	_blink_layer = CanvasLayer.new()
	_blink_layer.name = "BlinkLayer"
	_blink_layer.layer = 60
	_blink_layer.visible = false
	# ⭐ EYELIDS (2026-09-20 evening): two black panels, curved on the edge where they meet, that close
	# from the top and bottom of the frame. They start with zero height (anchor_bottom 0 / anchor_top 1).
	_lid_top = _make_lid("LidTop", true)
	_lid_bottom = _make_lid("LidBottom", false)
	_blink_layer.add_child(_lid_top)
	_blink_layer.add_child(_lid_bottom)
	add_child(_blink_layer)
	_blink_audio = AudioStreamPlayer.new()
	_blink_audio.name = "BlinkAudio"
	_blink_audio.stream = GameState.load_audio("blink")
	_blink_audio.volume_db = -2.0
	add_child(_blink_audio)


func _process(_delta: float) -> void:
	if _busy or _level == null or not _level.has_method("get_stalkers"):
		return
	var p := _level.get_node_or_null("Player") as CharacterBody3D
	if p == null:
		return
	# ApparitionDirector's gates: a paused tree means a note, a lock or a screamer owns the screen.
	if get_tree().paused or NoteUI.is_open or p.is_input_frozen():
		return
	var stalkers: Dictionary = _level.call("get_stalkers")
	for id in stalkers:
		# ⚠️ Untyped on purpose: a typed `var s: Node =` THROWS on a freed instance (the geometry walk
		# frees every stalker at setup), and the check below never runs. Issue 224's third lesson.
		var s = stalkers[id]
		if not is_instance_valid(s) or not s.has_method("stare_time"):
			continue
		var t: float = s.call("stare_time")
		if t <= 0.0:
			_thresholds.erase(id)   # a look-away resets the ladder for this one
			continue
		var threshold: float = _thresholds.get(id, STARE_FIRST)
		if t >= threshold:
			_thresholds[id] = threshold + STARE_EVERY
			_fire(p, s, id, t)
			return


func _fire(p: CharacterBody3D, stalker: Node, id: String, stare: float) -> void:
	var effect: String = EFFECTS[_cycle % EFFECTS.size()]
	_cycle += 1
	# Never a black screen over the pit: on the tiles the blink becomes a scrawl.
	if effect == "blink" and _on_tiles(p):
		effect = "scrawl"
	_fired += 1
	_last_effect = effect
	_dbg("HALLUCINATION %s (stalker %s, stare %.1f s)" % [effect, id, stare])
	match effect:
		"blink":
			_blink(p, stalker)
		"lie":
			var hud: Node = p.call("get_panic_hud")
			if hud and hud.has_method("lie"):
				hud.call("lie", LIE_RATIO, LIE_SECONDS)
		"scrawl":
			ScreenText.scrawl(get_tree(), SCRAWLS[_scrawl_index % SCRAWLS.size()], 2.5)
			_scrawl_index += 1
		"lamp":
			_dim_nearest_lamp(p)


func _make_lid(nm: String, top: bool) -> Panel:
	var lid := Panel.new()
	lid.name = nm
	lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 1)
	var r := 420
	if top:
		sb.corner_radius_bottom_left = r
		sb.corner_radius_bottom_right = r
	else:
		sb.corner_radius_top_left = r
		sb.corner_radius_top_right = r
	lid.add_theme_stylebox_override("panel", sb)
	lid.anchor_left = 0.0
	lid.anchor_right = 1.0
	lid.anchor_top = 0.0 if top else 1.0
	lid.anchor_bottom = 0.0 if top else 1.0
	lid.offset_left = -60.0    # wider than the frame so the curve's corners never show
	lid.offset_right = 60.0
	return lid


# The blink: the lids close (LID_CLOSE), hold (LID_HOLD) and open (LID_OPEN) with a wet sound, and
# for exactly ONE frame as they part a second fractured figure stands at arm's length. It is a
# photograph — no collider, no ScaryObject, no rule (SCARY.md P3). The stalkers keep their own rule
# throughout: the camera never moved, so a watched one stays frozen through the blink.
func _blink(p: CharacterBody3D, stalker: Node) -> void:
	_busy = true
	_blink_layer.visible = true
	if _blink_audio.stream:
		_blink_audio.play()
	var closing := create_tween().set_parallel(true)
	closing.tween_property(_lid_top, "anchor_bottom", 0.5, LID_CLOSE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	closing.tween_property(_lid_bottom, "anchor_top", 0.5, LID_CLOSE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await closing.finished
	await get_tree().create_timer(LID_HOLD, false).timeout
	if not is_instance_valid(p) or not is_instance_valid(self):
		_busy = false
		return
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	if cam and is_instance_valid(stalker):
		var fwd := -cam.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length() > 0.01:
			fwd = fwd.normalized()
			if _watcher == null or not is_instance_valid(_watcher):
				_watcher = _VOID_VISUAL.new() as Node3D
				_watcher.name = "StareWatcher"
				_level.add_child(_watcher)
			var at: Vector3 = p.global_position + fwd * WATCHER_AHEAD
			at.y = p.global_position.y
			_watcher.global_position = at
			_watcher.rotation.y = atan2(-fwd.x, -fwd.z)
			_watcher.visible = true
	var opening := create_tween().set_parallel(true)
	opening.tween_property(_lid_top, "anchor_bottom", 0.0, LID_OPEN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	opening.tween_property(_lid_bottom, "anchor_top", 1.0, LID_OPEN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().process_frame
	if is_instance_valid(_watcher):
		_watcher.visible = false
	await opening.finished
	_blink_layer.visible = false
	_busy = false


func _dim_nearest_lamp(p: CharacterBody3D) -> void:
	var best: OmniLight3D = null
	var best_d := LAMP_SEARCH
	for child in _level.get_children():
		if child is OmniLight3D and child.light_energy > 0.0:
			var d: float = (child as OmniLight3D).global_position.distance_to(p.global_position)
			if d < best_d:
				best_d = d
				best = child
	if best == null:
		return
	var full: float = best.light_energy
	var tw := create_tween()
	tw.tween_property(best, "light_energy", full * LAMP_DIM, 0.08)
	tw.tween_interval(LAMP_DIM_SECONDS)
	tw.tween_property(best, "light_energy", full, 0.35)


func _on_tiles(p: CharacterBody3D) -> bool:
	if not _level.has_method("tile_rect"):
		return false
	var r: Rect2 = _level.call("tile_rect")
	return r.has_area() and r.has_point(Vector2(p.global_position.x, p.global_position.z))


func _dbg(msg: String) -> void:
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg:
		dbg.note(msg)


# ── test surface ────────────────────────────────────────────────────────────────
func fired_count() -> int:
	return _fired


func last_effect() -> String:
	return _last_effect


func is_blinking() -> bool:
	return _blink_layer != null and _blink_layer.visible


# 0 = eyes open, 0.5 = the lids meet. For tests.
func blink_progress() -> float:
	return _lid_top.anchor_bottom if _lid_top else 0.0


func set_cycle(index: int) -> void:
	_cycle = index
