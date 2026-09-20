extends Node

# Presentation only. Never writes an AI target, player panic, or the hidden flag.
const CLIPS := {
	"chase": "breach_voice_chase",
	"batter": "breach_voice_batter",
	"search": "breach_voice_search",
}
var _creature: Node
var _player: CharacterBody3D
var _doors: Array = []
var _voice: AudioStreamPlayer3D
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
	add_child(_voice)
	for kind in CLIPS:
		_streams[kind] = GameState.load_audio(CLIPS[kind])
	for door in _doors:
		door.batter_started.connect(_batter_started)
		door.batter_silenced.connect(_silenced)
	_last_position = _creature.get_creature_position()


func _batter_started() -> void:
	# Door impacts and the voice begin together; never wait for the chase cry to finish.
	_mode = "batter"
	_cooldown = 0.0
	_voice.stop()


func _silenced() -> void:
	_voice.stop()
	_mode = "silence"
	_cooldown = 0.0


func _wanted_mode() -> String:
	if not is_instance_valid(_creature) or not is_instance_valid(_player):
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
	_voice.pitch_scale = randf_range(0.94, 1.05)
	_voice.volume_db = -5.0 if mode == "search" else -3.0
	_voice.play()
	_plays[mode] += 1
	match mode:
		"chase": _cooldown = randf_range(5.0, 8.0)
		"batter": _cooldown = 2.0
		"search": _cooldown = randf_range(7.0, 11.0)
	var log_node := get_node_or_null("/root/DebugLog")
	if log_node:
		log_node.note("OBJECT 12 VOICE %s at %v" % [mode, pos])
