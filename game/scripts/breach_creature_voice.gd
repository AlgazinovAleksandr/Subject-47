extends Node

# Presentation only. Never writes an AI target, player panic, or the hidden flag.
const CLIPS := {
	"chase": "res://assets/audio/level_backrooms/crate_jumpscare.ogg",
	"batter": "breach_voice_batter",
	"search": "breach_voice_search",
}
const CHASE_BACKGROUND := "breach_voice_chase_background"
const CHASE_MUSIC_DB := -8.0
const VOICE_DB := {"chase": -6.0, "batter": -4.0, "search": -5.0}
var _creature: Node
var _player: CharacterBody3D
var _doors: Array = []
var _voice: AudioStreamPlayer3D
var _music: AudioStreamPlayer
var _streams: Dictionary = {}
var _mode := ""
var _cooldown := 0.0
var _last_position := Vector3.ZERO
var _plays := {"chase": 0, "batter": 0, "search": 0}


func configure(creature: Node, player: CharacterBody3D, doors: Array) -> void:
	_creature = creature
	_player = player
	_doors = doors
	_voice = AudioStreamPlayer3D.new()
	_voice.name = "Object12Voice"
	_voice.unit_size = 9.0
	_voice.max_distance = 45.0
	_voice.max_db = -2.0
	_voice.volume_db = -3.0
	_voice.bus = "Master"
	add_child(_voice)
	for kind in CLIPS:
		_streams[kind] = load(CLIPS[kind]) if CLIPS[kind].begins_with("res://") else GameState.load_audio(CLIPS[kind])
	_music = AudioStreamPlayer.new()
	_music.name = "ChaseBackground"
	_music.volume_db = CHASE_MUSIC_DB
	# Listener-centred stereo score plus the creature's independent positional voice.
	var bed := GameState.load_audio(CHASE_BACKGROUND) as AudioStreamWAV
	if bed:
		bed = bed.duplicate() as AudioStreamWAV
		bed.loop_mode = AudioStreamWAV.LOOP_FORWARD
		bed.loop_begin = 0
		bed.loop_end = roundi(bed.get_length() * bed.mix_rate)
	_music.stream = bed
	add_child(_music)
	for door in _doors:
		door.batter_started.connect(_batter_started)
		door.batter_silenced.connect(_silenced)
	_last_position = _creature.get_creature_position()


func _batter_started() -> void:
	# Door impacts and the voice begin together; never wait for the chase cry to finish.
	_mode = "batter"
	_cooldown = 0.0
	_voice.stop()
	_music.stop()


func _silenced() -> void:
	_voice.stop()
	_music.stop()
	_mode = "silence"
	_cooldown = 0.0


func _wanted_mode() -> String:
	if not is_instance_valid(_creature) or not is_instance_valid(_player):
		return ""
	if Screamer.is_lunging() or Screamer.get("_is_triggering") or is_instance_valid(get_parent().get("_kill_sequence")):
		return ""
	if not _creature.get("_active") or _creature.get("_purge_frozen"):
		return ""
	if _creature.get_state() == 4: # staggered: the existing wound sting owns this moment
		return ""
	var battering := false
	for door in _doors:
		if is_instance_valid(door) and door.get("_battering"):
			if door.get("_silenced"):
				return "silence"
			battering = true
	if battering:
		return "batter"
	if _player.is_hidden():
		return "search"
	if _creature.get_state() == 2:
		return "chase"
	return ""


func _process(delta: float) -> void:
	if not is_instance_valid(_voice):
		return
	var mode := _wanted_mode()
	if mode == "chase":
		if not _music.playing:
			_music.play()
	else:
		_music.stop()
	if mode == "" or mode == "silence":
		_voice.stop()
		_mode = mode
		_cooldown = 0.0
		return
	var pos: Vector3 = _creature.get_creature_position()
	_voice.global_position = pos + Vector3(0, 1.4, 0)
	if pos.distance_to(_last_position) > 5.0:
		# A teleport must not pan a sustained howl across the player's head.
		_voice.stop()
		_cooldown = randf_range(1.0, 2.0)
	_last_position = pos
	if mode != _mode:
		_voice.stop()
		_cooldown = 0.0 if mode != "search" else randf_range(0.8, 1.5)
		_mode = mode
	_cooldown = maxf(0.0, _cooldown - delta)
	if _voice.playing or _cooldown > 0.0:
		return
	var stream: AudioStream = _streams.get(mode)
	if stream == null:
		return
	_voice.stream = stream
	# Keep the pursuit cry directional but audible while running away. The score
	# does not attenuate, so normal world falloff buried the voice at 18–30 metres.
	# max_distance adds its own fade even with ATTENUATION_DISABLED.
	_voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED if mode == "chase" else AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	_voice.max_distance = 0.0 if mode == "chase" else 45.0
	_voice.attenuation_filter_db = 0.0 if mode == "chase" else -24.0
	_voice.pitch_scale = randf_range(0.94, 1.05)
	_voice.volume_db = VOICE_DB[mode]
	_voice.play()
	_plays[mode] += 1
	match mode:
		"chase": _cooldown = stream.get_length() / _voice.pitch_scale + randf_range(3.0, 5.0)
		"batter": _cooldown = stream.get_length() / _voice.pitch_scale + 0.3
		"search": _cooldown = stream.get_length() / _voice.pitch_scale + randf_range(5.0, 8.0)
	var log_node := get_node_or_null("/root/DebugLog")
	if log_node:
		log_node.note("OBJECT 12 VOICE %s at %v" % [mode, pos])
