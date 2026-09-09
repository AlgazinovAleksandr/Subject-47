extends StaticBody3D
class_name RotaryPhone

# A grimy 1970s rotary phone on the carpet. It rings (rotary_ring) from across the
# maze; answer it (E) and distorted overlapping voices pour out (phone_whisper) as
# a read-to-die trap beat — panic climbs while the call is "open," like a trap note.
# Builds its own primitive mesh so backrooms.gd only has to place it.

const RING_INTERVAL := 7.0       # silence between ring bursts
const ANSWER_PANIC_RATE := 11.0  # read-to-die rate fed by NoteUI while the call is up

# These used to default to 0 dB, which made the ring the loudest recurring sound in
# the level despite reading as "distant". Pulled down under the score.
const RING_VOLUME_DB := -6.0
const WHISPER_VOLUME_DB := -3.0

const WHISPER_TEXT := """...hello? hello is someone—
...don't follow the arrows they want you to—
...it's been three days. three. days.
...the hum the hum the hum the—
...if you can hear this you already took a wrong—
...HANG UP. HANG UP. HANG U—"""

signal answered
signal smashed

# KONTUR reuses this phone as its "ignore" gate, where picking up is itself the whole
# failure — stacking a read-to-die note on top of a forfeited run would be punishing
# the same mistake twice. Backrooms leaves this true and keeps the trap note.
@export var open_note: bool = true

# KONTUR's Gate 6 redesign: once the player is carrying a hammer, E no longer answers
# the phone — it smashes it. Defaults false so Backrooms' phone (the only other
# caller) is completely unaffected.
@export var smashable: bool = false

# The phone body's colour. KONTUR Gate 6 has three phones — yellow / blue / green — and the colour
# is which verb the player owes it (told on a note in Records). Default is the near-black 1970s
# handset, so the Backrooms phones and the Perëkozhnik's COLOURLESS decoy are unaffected — and the
# colourless one among three coloured ones is half the mimic tell.
@export var tint: Color = Color(0.05, 0.05, 0.06)

# When true the phone does NOT ring on its own timer; a controller (kontur.gd's phone cycle) calls
# set_ringing() so exactly one of the three rings at a time. Backrooms leaves this false (self-rings).
@export var externally_driven: bool = false

# Which ring to load, and how loud.
#
# The Backrooms mixes its ring UNDER that level's score so it reads as "distant" — it
# now uses the same recorded `phone_ringing` clip (the procedural `rotary_ring` playtested
# as inaudible three times) but at -8 dB on the level's own bed bus. KONTUR needs the
# opposite: Gate 6 is "ignore the phone", so the ring has to be an unmistakable, sustained
# temptation heard for a whole room's length, at full level on Master.
# Backrooms Zone 2 (the Sprawl) reuses this phone ALREADY OFF THE HOOK: it never rings, and
# instead leaks `phone_whisper` continuously at low level from an alcove. Something else
# answered it. Defaults true so zone 1's and KONTUR's phones are completely unaffected.
#
# ⚠️ Pair it with `open_note = false`. A silent phone that still opened a read-to-die note on
# E would be a trap with no tell at all, which is §8.11 (never punish a scare the player could
# not have seen coming).
@export var rings: bool = true

@export var ring_audio: String = "rotary_ring"
@export var ring_volume_db: float = RING_VOLUME_DB
# Larger unit_size = audible from further away before distance attenuation bites.
@export var ring_unit_size: float = 6.0

# Which bus the ring rides. Defaults to Master so KONTUR's Gate 6 phone — a temptation
# that must be heard through everything — is unaffected. The Backrooms puts it on its own
# "Backrooms" bed bus instead, so the ring sits inside the level mix it is supposed to be
# under, and ducks with the bed when a SilenceZone or a HoldBreath dip fires. A recurring
# level sound on Master survives every silence effect in the game, which is exactly what
# a phone ringing 3 m from the spawn point should not do.
@export var ring_bus: String = "Master"

var _answered: bool = false
var _smashed: bool = false
var _resolved: bool = false      # KONTUR: the gate has accepted this phone (green answered, or smashed)
var _should_ring: bool = false   # externally_driven: the controller wants this one ringing now
var _ring_timer: float = 2.0
var _ring_player: AudioStreamPlayer3D
var _whisper_player: AudioStreamPlayer3D
var _smash_player: AudioStreamPlayer3D


func _ready() -> void:
	_build_mesh()
	_ring_player = AudioStreamPlayer3D.new()
	var ring := GameState.load_audio(ring_audio)
	if ring == null and ring_audio != "rotary_ring":
		ring = GameState.load_audio("rotary_ring")   # fall back rather than go silent
	if ring:
		_ring_player.stream = ring
	_ring_player.unit_size = ring_unit_size
	_ring_player.volume_db = ring_volume_db
	# ⚠️ ENSURE, don't test-and-skip. Props are spawned before the level starts its
	# ambience, so the level's bed bus does not exist yet when this runs — a
	# `get_bus_index() != -1` guard here silently left the ring on Master, which is the
	# exact bug this export was added to fix. AudioBuses.ensure() is idempotent and gets
	# the nesting (under Ambience, never Master) right on its own.
	if ring_bus != "Master":
		AudioBuses.ensure(ring_bus)
	_ring_player.bus = ring_bus
	add_child(_ring_player)

	_whisper_player = AudioStreamPlayer3D.new()
	var wh := GameState.load_audio("phone_whisper")
	if wh:
		_whisper_player.stream = wh
	_whisper_player.unit_size = 4.0
	_whisper_player.volume_db = WHISPER_VOLUME_DB
	add_child(_whisper_player)

	_smash_player = AudioStreamPlayer3D.new()
	var smash := GameState.load_audio("phone_smash")
	if smash:
		_smash_player.stream = smash
	_smash_player.unit_size = 8.0
	add_child(_smash_player)


func _build_mesh() -> void:
	build_visual(self, tint)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.32, 0.3, 0.36)
	col.shape = shape
	col.position.y = 0.15
	add_child(col)


# ⚠️ STATIC, and WITHOUT the collider (2026-08-18). KONTUR's Perëkozhnik can wear a phone
# as a disguise (`mimic_shell.gd`), and a mimic has to be built from the SAME geometry as
# the thing it imitates — two builders drift, and "which of these two is not ringing" only
# works if the two are otherwise identical. Additive: nothing else calls it.
static func build_visual(parent: Node3D, body_tint: Color = Color(0.05, 0.05, 0.06)) -> void:
	var black := StandardMaterial3D.new()
	black.albedo_color = body_tint
	black.roughness = 0.4
	black.metallic = 0.1

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.28, 0.12, 0.34)
	base.mesh = base_mesh
	base.set_surface_override_material(0, black)
	base.position.y = 0.06
	parent.add_child(base)

	# dial face
	var dial := MeshInstance3D.new()
	var dial_mesh := CylinderMesh.new()
	dial_mesh.top_radius = 0.1
	dial_mesh.bottom_radius = 0.1
	dial_mesh.height = 0.02
	dial.mesh = dial_mesh
	dial.set_surface_override_material(0, black)
	dial.position = Vector3(0, 0.13, 0.06)
	parent.add_child(dial)

	# handset resting on top
	var handset := MeshInstance3D.new()
	var hs_mesh := BoxMesh.new()
	hs_mesh.size = Vector3(0.3, 0.06, 0.08)
	handset.mesh = hs_mesh
	handset.set_surface_override_material(0, black)
	handset.position = Vector3(0, 0.15, -0.12)
	parent.add_child(handset)


func _process(delta: float) -> void:
	if _answered or _smashed or _resolved:
		return
	if externally_driven:
		# The controller owns the cadence; we only keep the burst alive while it wants us ringing
		# (every .wav.import here is loop_mode=0, so a finished burst must be replayed).
		if _should_ring and _ring_player.stream and not _ring_player.playing:
			_ring_player.play()
		return
	if not rings:
		# Off the hook: a continuous, quiet leak instead of a ring. Self-restarted, because
		# every .wav.import in this project is loop_mode=0.
		if _whisper_player.stream and not _whisper_player.playing:
			_whisper_player.play()
		return
	# ⚠️ The timer counts SILENCE, not wall time (2026-08-15). It used to be re-armed the
	# moment it expired, while the play() call was skipped if the clip was still running —
	# so with a ring LONGER than RING_INTERVAL the burst ended and the next one started
	# almost immediately. The Backrooms' 10 s `phone_ringing` on a 7 s timer rang ~10 s in
	# every 14: not a phone ringing across the maze, a phone ringing continuously. Only
	# start the countdown once the burst has actually finished.
	if _ring_player.playing:
		return
	_ring_timer -= delta
	if _ring_timer <= 0.0:
		_ring_timer = RING_INTERVAL
		if _ring_player.stream:
			_ring_player.play()


func interact() -> void:
	if _answered or _smashed or _resolved:
		return
	if open_note:
		# Backrooms read-to-die: answering LOCKS the call open and bleeds panic. Hang up to live.
		_answered = true
		_ring_player.stop()
		if _whisper_player.stream:
			_whisper_player.play()
		answered.emit()
		NoteUI.show_note(WHISPER_TEXT, ANSWER_PANIC_RATE)
	else:
		# KONTUR: E ANSWERS. The level decides the outcome (fatal / hallucination / hint) and
		# whether this resolves the phone — answering does NOT lock it, so a phone the player must
		# still SMASH stays smashable. The ring stops on pickup; the controller re-rings it if it
		# is still unresolved.
		_ring_player.stop()
		_should_ring = false
		answered.emit()


# Space / push_effort — SMASH (KONTUR Gate 6). E answers, Space smashes; the two verbs on one aim
# are the whole choice. Needs the hammer (`smashable`). A no-op for the Backrooms phones, which are
# never smashable, so their only verb stays E.
func secondary_interact() -> void:
	if _answered or _smashed or _resolved:
		return
	if smashable:
		_smash()


# The controller (kontur.gd) turns exactly one unresolved phone on at a time.
func set_ringing(on: bool) -> void:
	if _resolved or _smashed or _answered:
		return
	_should_ring = on
	if on:
		if _ring_player.stream and not _ring_player.playing:
			_ring_player.play()
	else:
		_ring_player.stop()


func is_resolved() -> bool:
	return _resolved or _smashed


func _smash() -> void:
	_smashed = true
	_should_ring = false
	_ring_player.stop()
	if _smash_player.stream:
		_smash_player.play()
	smashed.emit()
	# A quick, permanent visual tell that this phone is done ringing.
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", deg_to_rad(28.0), 0.15)
	tw.parallel().tween_property(self, "position:y", position.y - 0.06, 0.15)


# The RESTORE path (kontur.gd resume) and the green-answered accept. Silent — no sound, no signal,
# no re-trigger — the world is catching up with a ledger that already says this phone is done.
# `smashed_look` tilts the handset (a phone the player smashed); an ANSWERED green phone stays
# upright. Additive: the Backrooms' phones never call it.
func mark_resolved(smashed_look: bool = true) -> void:
	if _resolved or _smashed:
		return
	_resolved = true
	_should_ring = false
	if _ring_player:
		_ring_player.stop()
	if smashed_look:
		_smashed = true
		rotation.z = deg_to_rad(28.0)
		position.y -= 0.06


# Back-compat alias for the old single-phone resume path.
func mark_smashed() -> void:
	mark_resolved(true)
