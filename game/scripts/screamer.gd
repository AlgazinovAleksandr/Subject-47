extends CanvasLayer

# Autoload singleton: Screamer
# Call Screamer.trigger() from anywhere to fire the fatal screamer (image +
# matching sound for the current level, then restart). Call flash_scare() for a
# survivable scare (fullscreen flash + sound, no restart — the caller adds panic).

var _black_panel: ColorRect
var _screamer_image: TextureRect
var _audio: AudioStreamPlayer
var _screamer_textures: Array[Texture2D] = []  # fallback pool (intro / ending)
var _is_triggering: bool = false
var _is_flashing: bool = false
var _fatal_token := -1


func _claim_fatal(reserved_token: int = -1) -> int:
	if reserved_token >= 0:
		return reserved_token if GameState.transition_is_current(reserved_token) else -1
	if _lunging and GameState.transition_is_current(_fatal_token):
		return _fatal_token
	return GameState.begin_transition("death")


func _clear_fatal(token: int) -> void:
	if _fatal_token != token:
		return
	_black_panel.visible = false
	_screamer_image.visible = true
	_audio.stop()
	_is_triggering = false
	_lunging = false
	_suppress_sting = false
	_fatal_token = -1


func _process(_delta: float) -> void:
	if _fatal_token >= 0 and not GameState.transition_is_current(_fatal_token):
		_clear_fatal(_fatal_token)

# Per-level fatal screamer: current_level -> [image path, audio base name].
# load_audio() resolves the base name across the audio subdirs (.wav/.ogg).
const LEVEL_SCREAMERS := {
	1: ["res://assets/textures/level_1_lab/screamer_lab.png", "screamer_lab"],
	2: ["res://assets/textures/level_2_house/screamer_house.png", "screamer_house"],
	3: ["res://assets/textures/level_3_corridor/screamer_hotel.png", "screamer_corridor"],
	4: ["res://assets/textures/level_backrooms/screamer_smiler.png", "all_levels_screamer"],
	5: ["res://assets/textures/level_5_kontur/screamer_kontur.png", "kontur_scream"],
	6: ["res://assets/textures/level_6_breach/level_6_jumpscare.jpg", "level_6_jumpscare"],
	# 7 = THE NIGHTMARE. ⚠️ screamer_dungeon lives in level_9_dungeon/, NOT in
	# screamers/ — that folder is DirAccess-scanned as the random fallback pool for
	# the intro and ending only (the screamer_hotel.png precedent).
	7: ["res://assets/textures/level_9_dungeon/screamer_dungeon.png", "screamer_dungeon"],
	8: ["res://assets/textures/level_4_void/screamer_void.png", "screamer_void"],
}

const FALLBACK_AUDIO := "all_levels_screamer"  # intro / ending levels with no dedicated scream

const RESTART_DELAY := 2.5
# How long the world goes quiet around a survivable scare (SCARY.md P5). Deliberately
# short: this is a held breath, not a SilenceZone. Only applies to flash_scare() — a fatal
# trigger() reloads the scene anyway, so silence before it would be silence before nothing.
const PRE_SCARE_SILENCE := 0.6


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_black_panel = ColorRect.new()
	_black_panel.color = Color.BLACK
	_black_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_black_panel)

	_screamer_image = TextureRect.new()
	_screamer_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screamer_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_black_panel.add_child(_screamer_image)

	_audio = AudioStreamPlayer.new()
	add_child(_audio)

	_black_panel.visible = false

	# Fallback pool: every .png in screamers/ (used for intro / ending only).
	var dir := DirAccess.open("res://assets/textures/screamers")
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".png"):
				var tex: Texture2D = load("res://assets/textures/screamers/" + fname)
				if tex:
					_screamer_textures.append(tex)
			fname = dir.get_next()
		dir.list_dir_end()


# Set both the screamer image and the scream audio for the current level.
# Falls back to a random screamers/ image + the shared all_levels_screamer for intro/ending.
func _apply_level_av() -> void:
	var entry: Variant = LEVEL_SCREAMERS.get(GameState.current_level)
	if entry != null and ResourceLoader.exists(entry[0]):
		_screamer_image.texture = load(entry[0])
		var stream := GameState.load_audio(entry[1])
		if stream:
			_audio.stream = stream
			return
	# Fallback path.
	if _screamer_textures.size() > 0:
		_screamer_image.texture = _screamer_textures[randi() % _screamer_textures.size()]
	var fallback := GameState.load_audio(FALLBACK_AUDIO)
	if fallback:
		_audio.stream = fallback


func set_screamer_texture(texture: Texture2D) -> void:
	_screamer_image.texture = texture


func set_screamer_audio(stream: AudioStream) -> void:
	_audio.stream = stream


# Single source of truth for playtest death logging (see debug_log.gd::record_death for
# the full story — the old panic-collapse heuristic missed every death that didn't go
# through the panic system, e.g. instant creature contact). Runs once per real trigger,
# guarded by the _is_triggering check both callers already do before calling this.
func _log_death() -> void:
	var dbg := get_node_or_null("/root/DebugLog")
	if not dbg:
		return
	var p := get_tree().get_first_node_in_group("player")
	var pos: Vector3 = p.global_position if p else Vector3.ZERO
	dbg.record_death(pos, "level %d" % GameState.current_level)


# Death has to actually STOP the player.
#
# trigger() deliberately UNPAUSES the tree — NoteUI pauses while a note is open and
# detects the unpause to drop its overlay, so pausing here instead would strand a
# trap note on screen. But that left the player fully simulating behind the black
# panel for the whole restart delay: still walking, still gazing, still feeding the
# panic bar. Playtest showed panic climbing 5% -> 78% AFTER death, because the corpse
# was still staring at the Perekozhnik.
#
# So freeze the player alone. The node is freed by the reload a moment later; this
# only has to hold for RESTART_DELAY.
func _freeze_player() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p:
		p.process_mode = Node.PROCESS_MODE_DISABLED


# ⭐ THE BLACK FLASH, and the silence in front of it (2026-09-03).
#
# ⚠️ THIS FILE DID NOT DO WHAT `CLAUDE.md` SAID IT DID. The documented sequence has always been
# "black flash -> screamer image fullscreen -> loud audio burst", and the code did none of it:
# `_screamer_image` is a CHILD of `_black_panel` (see `_ready()`), so `_black_panel.visible =
# true` put the black and the face on screen in the same frame, with `_audio.play()` on the
# very next line. There was no black beat, and — unlike `flash_scare()`, which has ducked
# `Ambience` since the day `HoldBreath` landed — the FATAL path had no silence either. The
# loudest moment in the game arrived on top of a running ambience bed, at full ambience level.
#
# It matters more than a re-mastered file does. On 2026-09-03 the sourced stings were measured
# and the honest finding was that six of the eight fatal screamers are already within ~1 dB of
# each other and of the ceiling — there is no gain left in the FILES. What there is, is
# CONTRAST, and it is free: `BLACK_HOLD` of nothing at all, on a bus that has just been pulled
# down 30 dB, is worth more perceived level than any amount of saturation.
#
# ⚠️ The hold is deliberately short. At 0.2 s it reads as the cut itself; much past 0.35 s and
# the player starts to register "the screen went black" as its own event, which gives them time
# to brace — the exact opposite of the point. It also comes OUT of `RESTART_DELAY` rather than
# being added to it, so the time from death to reload does not move.
const BLACK_HOLD := 0.2

# `with_image` false (R7, 2026-09-16, the user: "only the running animation accompanied by the
# scream, we do not need the static image following after it"): the lunge deaths cut to black
# and restart with no fullscreen picture — the figure at arm's length WAS the picture.
func trigger(image_override: String = "", with_image: bool = true, reserved_token: int = -1) -> void:
	if _is_triggering:
		return
	var token := _claim_fatal(reserved_token)
	if token < 0:
		return
	_fatal_token = token
	# K3 (2026-09-16, capture #6 again): while a lunge is in progress ANY death is the lunge —
	# the condemn bar's own `add_panic()` death raced the figure and brought the picture back.
	if _lunging:
		with_image = false
	_is_triggering = true
	_log_death()
	get_tree().paused = false
	_freeze_player()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_level_av()
	if image_override != "" and ResourceLoader.exists(image_override):
		_screamer_image.texture = load(image_override)
	await _black_then_scream(with_image)
	if not GameState.transition_is_current(token):
		_clear_fatal(token)
		return
	_suppress_sting = false
	await get_tree().create_timer(maxf(0.0, RESTART_DELAY - BLACK_HOLD)).timeout
	if not GameState.transition_is_current(token):
		_clear_fatal(token)
		return
	_clear_fatal(token)
	GameState.restart_current_level()


# Cut to black in silence, hold, then the face and the scream together.
#
# ⚠️ `HoldBreath.dip()` is fire-and-forget on purpose (awaiting it would delay the scare by the
# whole dip). It restores `Ambience` itself, and `AudioBuses.reset_all()` runs on the level
# reload that follows regardless, so a dip interrupted by the scene change cannot leak.
# ⚠️ The timer is `process_always` — `trigger()` unpauses the tree, but `trigger_to_menu()` can
# be reached from a paused NoteUI, and a paused SceneTreeTimer here would hang on black forever.
func _black_then_scream(with_image: bool = true) -> void:
	var token := _fatal_token
	_screamer_image.visible = false
	_black_panel.visible = true
	HoldBreath.dip(get_tree(), PRE_SCARE_SILENCE)
	await get_tree().create_timer(BLACK_HOLD, true, false, true).timeout
	if not GameState.transition_is_current(token) or token != _fatal_token:
		return
	_screamer_image.visible = with_image
	if _audio.stream and not _suppress_sting:
		_audio.play()


# ⭐ K2 (2026-09-14, the user's design: "in-world deaths"). A death that happens IN THE WORLD
# before the funnel: the player is pinned and turned, a figure stands `ahead` metres in front
# (validated by a ray from the eye — if the wall is nearer it stands short of the wall, never
# in it), glows so it reads in a dark room, and lunges to `reach` metres from the lens over
# `time` seconds with the LEVEL'S OWN fatal sting playing AT the figure; on arrival `trigger()`
# runs unchanged (black, image, restart), with the 2D sting suppressed because it has already
# been heard once, at arm's length. The funnel is still `trigger()` — `_is_triggering`,
# `_log_death()`, `RESTART_DELAY` and `restart_current_level()` are untouched, so every test
# that watches `_is_triggering` sees the same death; it just starts ~`time` later.
# ⚠️ `_lunging` mirrors `_is_flashing`: a second call during the wind-up is ignored, and a
# plain `trigger()` from elsewhere (the panic bar) still pre-empts — the funnel wins.
# ⚠️ The timers are `process_always` and the player is frozen by `freeze_input()`, not by
# `process_mode` (that comes in `trigger()`): the camera tween needs the player processing.
const LUNGE_GLOW := 1.4
const LUNGE_LIGHT_RANGE := 4.0
const LUNGE_LIGHT_ENERGY := 1.2
const LUNGE_TURN := 0.3
const LUNGE_MIN_AHEAD := 0.9
var _lunging: bool = false
var _suppress_sting: bool = false
var _lunger: Node3D = null


func is_lunging() -> bool:
	return _lunging


func trigger_with_lunge(tex_path: String, ahead: float = 2.2, reach: float = 0.5,
		time: float = 0.28, image_override: String = "") -> void:
	if _is_triggering or _lunging:
		return
	var token := _claim_fatal()
	if token < 0:
		return
	_fatal_token = token
	var p := get_tree().get_first_node_in_group("player") as Node3D
	var scene := get_tree().current_scene
	if p == null or scene == null:
		trigger(image_override, true, token)
		return
	_lunging = true
	get_tree().paused = false
	if p.has_method("freeze_input"):
		p.call("freeze_input")
	if "velocity" in p:
		var v: Vector3 = p.get("velocity")
		p.set("velocity", Vector3(0, v.y, 0))
	# Where it stands: straight ahead on the floor, short of any wall.
	var fwd: Vector3 = -p.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0, 0, -1)
	var d: float = ahead
	var space := p.get_world_3d().direct_space_state
	# Rays at eye AND waist height: a desk in front of you is under the eye ray, and a
	# figure standing in a desk is the picture the first render produced.
	for h in [1.6, 0.9]:
		var from: Vector3 = p.global_position + Vector3(0, h, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + fwd * (ahead + 0.6))
		q.exclude = [p.get_rid()] if p is CollisionObject3D else []
		var hit := space.intersect_ray(q)
		if hit:
			d = minf(d, clampf(from.distance_to(hit.position) - 0.45, LUNGE_MIN_AHEAD, ahead))
	var spot: Vector3 = p.global_position + fwd * d
	spot.y = p.global_position.y
	var l := DoorLunger.build(scene, spot, tex_path, 2.0)
	l.name = "DeathLunger"
	l.set_glow(LUNGE_GLOW)
	l.add_light(LUNGE_LIGHT_RANGE, LUNGE_LIGHT_ENERGY)
	_lunger = l
	# The level's own fatal sting, AT the figure.
	_apply_level_av()
	if _audio.stream:
		var sp := AudioStreamPlayer3D.new()
		sp.name = "LungeSting"
		sp.stream = _audio.stream
		sp.max_db = 6.0
		sp.unit_size = 8.0
		sp.position = Vector3(0, 1.4, 0)
		l.add_child(sp)
		sp.play()
		_suppress_sting = true
	HoldBreath.dip(get_tree(), LUNGE_TURN + time + 0.4)
	if p.has_method("turn_to_face"):
		p.call("turn_to_face", spot + Vector3(0, 1.2, 0), LUNGE_TURN)
	l.lunged.connect(func() -> void:
		if not GameState.transition_is_current(token):
			return
		_lunging = false
		trigger(image_override, false, token)   # R7: no static picture after the lunge
	)
	await get_tree().create_timer(LUNGE_TURN, true).timeout   # scales with time_scale, like the tween
	if not GameState.transition_is_current(token):
		_clear_fatal(token)
		return
	if not is_instance_valid(l):
		_lunging = false
		trigger(image_override, false, token)
		return
	var dir_to: Vector3 = (l.global_position - p.global_position)
	dir_to.y = 0.0
	dir_to = dir_to.normalized() if dir_to.length() > 0.01 else fwd
	var end: Vector3 = p.global_position + dir_to * reach
	end.y = l.global_position.y
	l.lunge_to(end, time)
	# Safety valve: if the tween never lands (a freed scene), the funnel still runs.
	await get_tree().create_timer(time + 0.6, true).timeout
	if _lunging and GameState.transition_is_current(token):
		_lunging = false
		trigger(image_override, false, token)


# image_override lets a caller force a specific fatal image regardless of the
# per-level lookup — used for the twist ending, which must always show the
# same screamer no matter which level state it fires from.
func trigger_to_menu(image_override: String = "") -> void:
	if _is_triggering:
		return
	var token := _claim_fatal()
	if token < 0:
		return
	_fatal_token = token
	_is_triggering = true
	_log_death()
	get_tree().paused = false
	_freeze_player()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_apply_level_av()
	if image_override != "" and ResourceLoader.exists(image_override):
		_screamer_image.texture = load(image_override)
	await _black_then_scream()
	if not GameState.transition_is_current(token):
		_clear_fatal(token)
		return
	await get_tree().create_timer(maxf(0.0, RESTART_DELAY - BLACK_HOLD), true, false, true).timeout
	if not GameState.transition_is_current(token):
		_clear_fatal(token)
		return
	_clear_fatal(token)
	GameState.go_to_main_menu()


# Survivable scare: flash an image fullscreen + play a sound for `hold` seconds,
# then clear. Does NOT pause or restart — the caller is responsible for any
# panic spike. Used by the forest (house) and manager (corridor) scares.
func flash_scare(image_path: String, audio_base: String, hold: float = 0.8) -> void:
	if _is_triggering or _is_flashing:
		return
	_is_flashing = true

	# SCARY.md P5 — the pre-scare silence dip. Two lines, and it improves EVERY survivable
	# scare in the game at once: the House forest window, the Corridor Manager, the three
	# turn mirrors, the Lab nook payoff, all eight KONTUR strike flashes, every Backrooms
	# wrong wall. F.E.A.R.'s entire audio thesis is that the silence before the hit is what
	# makes the hit; the longest telegraph this game had before it was 0.22 s
	# (apparition.gd:TELEGRAPH_TIME) and everything else was a hard cut.
	#
	# ⚠️ Fire-and-forget, deliberately NOT awaited. Awaiting it would delay the image and
	# the sting by the whole dip, which is the opposite of the effect — the world drops out
	# from under the scare, it does not queue ahead of it. The dip outlives this function
	# on its own node (parented to the tree root), and it ducks only "Ambience", so the
	# heartbeat on "Body" keeps going. See hold_breath.gd and audio_buses.gd.
	HoldBreath.dip(get_tree(), PRE_SCARE_SILENCE)

	if ResourceLoader.exists(image_path):
		_screamer_image.texture = load(image_path)
	var stream := GameState.load_audio(audio_base)
	if stream:
		_audio.stream = stream
		_audio.play()
	# ⚠️ Defensive: the fatal path hides `_screamer_image` for its BLACK_HOLD beat and restores
	# it afterwards. The `_is_triggering` guard above already stops the two overlapping, but a
	# survivable scare that rendered a black rectangle because a previous death left this false
	# would be silent, invisible and very hard to trace. One line.
	_screamer_image.visible = true
	_black_panel.visible = true
	await get_tree().create_timer(hold).timeout
	# A fatal trigger may have taken over mid-flash — don't yank its panel.
	if not _is_triggering:
		_black_panel.visible = false
	_is_flashing = false
