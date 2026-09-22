extends Node3D

# ⭐ THE CRADLE BURNS (2026-09-23 pass 8). Capture #3 of the 23:10 run, standing over the
# completed cradle at the end of pass 7's beat: *"make this visual of the monster showing up as
# a jumpscare more brutal. Firstly, the jumpscare itself should be louder. Secondly, maybe add
# animation like there is fire for like 3 seconds and then this face appears from fire?"*
#
# So the second the room goes black, a fire starts in the crib. It grows for three seconds —
# the only thing in the world, and the only warm colour anywhere in this level — and then the
# face comes UP THROUGH it. `level_3.gd:_run_cradle_shadow()` owns the clock; this file owns
# the flames, their light and their crackle, and nothing else.
#
# ⚠️ ZERO PANIC, NO FAIL STATE, NO COLLIDER, NO `ScaryObject`. It is a photograph with a light
# in it, like every other beat in this level. It exists for ~5.8 s and is then freed outright —
# `check_void` asserts it is absent before the beat and absent after.
#
# ⚠️ IT IS AN EVENT, NOT A PROP, AND THAT IS WHY IT MAY BE THE ONE EMISSIVE THING HERE.
# SCARY.md §8.8 / Issue 21: this project renders with no glow, no fog and Linear tonemap at
# exposure 1.0, so a self-lit surface above 1.0 is a flat white rectangle with no detail in it.
# The quads are `SHADING_MODE_UNSHADED` + `BLEND_MODE_ADD`, which outputs ALBEDO directly and
# ignores `emission` entirely — so the ceiling is expressed where it is actually read, on
# `albedo_color`, whose components never exceed 1.0 and whose ALPHA is what the beat animates.
# `emission_energy_multiplier` is nonetheless pinned at 1.0 so that a later pass restoring
# per-pixel shading cannot silently walk this over the clamp.
#
# ⚠️ THE LIGHT HAS NO 1/d CORE, AND THAT IS THE WHOLE REASON 0.9 ENERGY IS SAFE HERE. Godot's
# omni attenuation is `(1 - (d/range)^4)^2 * d^(-omni_attenuation)`; at the default decay of 1.0
# a 0.9-energy lamp puts 1.07 of irradiance on anything 0.83 m away and 1.7 on anything half a
# metre away, and the mask this beat exists to show is a ~0.95-albedo surface that passes within
# 0.3 m of the flames as it rises. Pass 7 solved that by dropping the lamp to 0.40 energy at
# range 1.8. A FIRE IS NOT A POINT — it is a volume of burning air — so `omni_attenuation` is
# 0.0 and the falloff is the range window alone: irradiance is `energy * (1 - (d/3)^4)^2`, which
# is `<= 0.9` at EVERY distance, for the whole beat, by construction. Measured at the hold: the
# mask sits 0.62 m from the flame core, takes 0.897 of irradiance and reads at 0.85 luminance
# against pass 7's 0.73 — brighter than the beat it replaces and still 15 % clear of the clamp.
#
# ⚠️ NO PARTICLE SYSTEM. Six billboarded quads on per-quad phases cost nothing, are deterministic
# (a screenshot of frame N is the same frame N next run, which a GPU particle system is not), and
# read as fire at the one distance this is ever seen from. `silhouette carries a prop` (Issue 35)
# applies to flames too: what sells this is the ragged top edge moving, not the texture.

const FLAME_TEX := "res://assets/textures/level_4_void/void_flame.png"

# ── the shape of the fire ───────────────────────────────────────────────────────
const QUADS := 6
const BASE_W := 0.34            # a quad's width at full growth, before its own flicker
const BASE_H := 0.80            # …and its height. Tops reach ~0.2 m over the cradle's rim.
const SPREAD := 0.20            # how far the six sit from the flame axis
const TINT := Color(1.0, 0.62, 0.26)

# ── the light ───────────────────────────────────────────────────────────────────
const LIGHT_COLOR := Color(1.0, 0.55, 0.2)
const LIGHT_ENERGY := 0.9       # the ceiling of the ramp; see the header for why it cannot clamp
const LIGHT_RANGE := 3.0
const LIGHT_RAMP := 1.0         # 0 -> 0.9 over the first second
const LIGHT_FLICKER := 0.15     # …and then +/- this, on its own phase
const LIGHT_LIFT := 0.24        # the flame core, above the cradle's broken bed
# ⚠️ AND 0.30 m TOWARD THE PLAYER — Issue 258, measured again here and not assumed. The flames
# stand on the cradle's broken bed, which is 0.16 m off the cradle's own axis, and from the
# stance a player presses E from that put the light BEHIND the figure that rises out of it: the
# first render of this beat at 2.5 m is a black silhouette in front of an orange fire, with no
# face in it at all. The MASK hangs ~0.20 m forward of the figure's axis, so a light 0.30 m
# forward sits 0.10 m in front of it and 0.62 m below it — lit from underneath, out of the fire,
# which is the image pass 7 measured and the reason its lamp was offset too.
# ⚠️ The QUADS do not move: they are where the fire physically is. Only the light leans.
const LIGHT_TOWARD := 0.30

# ── the clock ───────────────────────────────────────────────────────────────────
const GROW := 3.0               # the fire is full size when the face starts to rise

# ⚠️ -4.9 dB IS ARITHMETIC. `cradle_fire.wav` measures -19.7 dBFS mean / -1.0 dBFS peak over
# 3.500 s (ffmpeg volumedetect). The level's own constant bed is `room_hum` at -6.55 dBFS / -26.0
# dB / unit 5.0, i.e. -32.55 dBFS delivered at the source; a fire two metres away in a blacked-out
# room should sit clearly over the bed without swallowing the snarl, so this is placed 8.0 dB
# above it: -24.55 dBFS delivered, which is -4.85 dB of gain, rounded to -4.9. That lands 1.3 dB
# over `drawer_pull`'s delivered -25.9 dBFS and 22.6 dB under the snarl's -2.0.
# ⚠️ AMBIENCE, not Master: this is a sound IN the room at a position, and unlike the sting
# nothing ducks the Ambience bus during this beat (`_run_cradle_shadow()` never calls
# `HoldBreath.dip()` — that was pass 5's staging).
# ⚠️ LOOPED IN CODE. Every `.wav.import` in this project is `loop_mode=0`; `finished -> play` is
# the idiom (`void_frame_hall.gd:_emitter`, `creature_stalker.gd:_tick_whisper`), and setting it
# here rather than in the .import is also what stops a re-import from regressing it silently.
const FIRE_DB := -4.9
const FIRE_UNIT := 3.0

var _t := 0.0
var _dying := false
var _fade := 0.0
var _fade_t := 0.0
var _quads: Array = []
var _phase: Array = []
var _light: OmniLight3D = null
var _audio: AudioStreamPlayer3D = null


func _dbg(msg: String) -> void:
	var d := get_node_or_null("/root/DebugLog")
	if d:
		d.note(msg)


# `base` is the world point the flames stand on — the top of the cradle's broken bed, handed in
# by the level so this file never hand-computes a position inside somebody else's prop.
func ignite(base: Vector3, toward: Vector3 = Vector3.ZERO) -> void:
	global_position = base
	var lean := Vector3(toward.x, 0.0, toward.z)
	lean = lean.normalized() * LIGHT_TOWARD if lean.length() > 0.01 else Vector3.ZERO
	var tex: Texture2D = null
	if ResourceLoader.exists(FLAME_TEX):
		tex = load(FLAME_TEX) as Texture2D
	for i in range(QUADS):
		var mi := MeshInstance3D.new()
		mi.name = "Flame%d" % i
		var qm := QuadMesh.new()
		qm.size = Vector2(BASE_W, BASE_H)
		mi.mesh = qm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		# ⚠️ `billboard_keep_scale`, or the whole animation is invisible: a billboarded quad
		# discards its own basis, scale included, unless this is set — so the flame would flicker
		# in alpha and never move. The SIZE is animated on the QuadMesh itself for the same
		# reason, and each quad therefore owns its own mesh resource.
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.albedo_texture = tex
		m.albedo_color = TINT
		m.disable_receive_shadows = true
		# Pinned at the clamp ceiling, and unread while the material is unshaded (see the header).
		m.emission_enabled = true
		m.emission = TINT
		m.emission_energy_multiplier = 1.0
		mi.set_surface_override_material(0, m)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a: float = TAU * float(i) / float(QUADS)
		mi.position = Vector3(cos(a) * SPREAD * (0.4 + 0.6 * float(i % 3) / 2.0), BASE_H * 0.5,
			sin(a) * SPREAD * (0.4 + 0.6 * float((i + 1) % 3) / 2.0))
		add_child(mi)
		_quads.append(mi)
		# Six DIFFERENT clocks: one shared sine makes six quads pulse as one lamp.
		_phase.append([a * 1.7, 3.1 + 0.9 * float(i % 4), 0.55 + 0.25 * float(i % 3)])
	_light = OmniLight3D.new()
	_light.name = "CradleLight"
	_light.light_color = LIGHT_COLOR
	_light.omni_range = LIGHT_RANGE
	_light.omni_attenuation = 0.0
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	# ⚠️ The fire node carries no rotation of its own, so its local axes ARE the world's and
	# `lean` can be applied directly. That is deliberate: a prop-local offset would have to be
	# unrotated through the cradle's yaw, which is exactly the hand-computed-position class of
	# bug this project keeps re-learning.
	_light.position = Vector3(lean.x, LIGHT_LIFT, lean.z)
	add_child(_light)
	var s := GameState.load_audio("cradle_fire")
	if s:
		_audio = AudioStreamPlayer3D.new()
		_audio.name = "CradleFireLoop"
		_audio.stream = s
		_audio.volume_db = FIRE_DB
		_audio.unit_size = FIRE_UNIT
		_audio.bus = AudioBuses.AMBIENCE
		_audio.position = Vector3(0, 0.3, 0)
		add_child(_audio)
		_audio.finished.connect(_audio.play)
		_audio.play()
	_apply(0.0)
	_dbg("VOID cradle fire LIT at %v — %d quads, omni %.1f energy over %.1f m, decay %.1f, leaning %.2f m toward the player"
		% [base, _quads.size(), LIGHT_ENERGY, LIGHT_RANGE, _light.omni_attenuation,
			lean.length()])


# The level's own clock says when; this only starts the 0.3 s fade the three things share.
func extinguish(over: float) -> void:
	if _dying:
		return
	_dying = true
	_fade = maxf(over, 0.001)
	_fade_t = 0.0
	if _audio and is_instance_valid(_audio):
		_audio.finished.disconnect(_audio.play)
	_dbg("VOID cradle fire OUT (fading over %.2f s)" % _fade)


func _process(delta: float) -> void:
	_t += delta
	if _dying:
		_fade_t += delta
	_apply(delta)


# ⚠️ ONE FUNCTION FOR THE LIVE BEAT AND FOR THE SCREENSHOT HOOK, so a capture can never
# photograph a state the beat does not reach (the `void_exit_door.gd:snap_assembled()` rule).
func _apply(_delta: float) -> void:
	var grow: float = clampf(_t / GROW, 0.0, 1.0)
	# Ease out: it catches fast and then fills the crib.
	grow = 1.0 - (1.0 - grow) * (1.0 - grow)
	var out: float = 1.0
	if _dying:
		out = clampf(1.0 - _fade_t / _fade, 0.0, 1.0)
	for i in range(_quads.size()):
		var mi: MeshInstance3D = _quads[i]
		if not is_instance_valid(mi):
			continue
		var ph: Array = _phase[i]
		var f: float = 0.5 + 0.5 * sin(_t * float(ph[1]) + float(ph[0]))
		var h: float = BASE_H * grow * (0.62 + 0.55 * f)
		var w: float = BASE_W * grow * (0.78 + 0.34 * f)
		var qm := mi.mesh as QuadMesh
		if qm:
			qm.size = Vector2(maxf(w, 0.001), maxf(h, 0.001))
		mi.position.y = h * 0.5
		var m := mi.get_surface_override_material(0) as StandardMaterial3D
		if m:
			var c := m.albedo_color
			c.a = out * grow * float(ph[2]) * (0.45 + 0.55 * f)
			m.albedo_color = c
	if _light and is_instance_valid(_light):
		var ramp: float = clampf(_t / LIGHT_RAMP, 0.0, 1.0)
		var jitter: float = LIGHT_FLICKER * sin(_t * 7.3) * 0.6 + LIGHT_FLICKER * sin(_t * 13.1) * 0.4
		var e: float = LIGHT_ENERGY * ramp + (jitter if ramp >= 1.0 else 0.0)
		_light.light_energy = clampf(e, 0.0, LIGHT_ENERGY + LIGHT_FLICKER) * out
	if _audio and is_instance_valid(_audio) and _dying:
		_audio.volume_db = FIRE_DB + linear_to_db(maxf(out, 0.0001))


# ── test / screenshot surface ───────────────────────────────────────────────────
# ⚠️ Drives the SAME `_apply()` the live beat drives, with the wait taken out. A timed beat is a
# race with a capture and the capture always loses.
func advance_to(age: float) -> void:
	_t = age
	_apply(0.0)


func age() -> float:
	return _t


func light() -> OmniLight3D:
	return _light


func light_energy() -> float:
	return _light.light_energy if _light and is_instance_valid(_light) else 0.0


func quads() -> Array:
	return _quads.duplicate()


func is_dying() -> bool:
	return _dying
