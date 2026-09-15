extends Node3D
class_name BlindRoom

# C4 (2026-09-14): BLIND NAVIGATION — the wrong branch at corner 365 ends in this room. Step in
# and the way back drops shut, the torch dies, and the room's plan flashes ONCE for MAP_FLASH_S
# on the wall behind you (the Intro ward's light-switch glimpse). Then feel for the release
# lever: every wall you bump answers with its own knock (wood / stone / metal, so the walls can
# be told apart by ear), and the lever hums — far cue + near confirm, the Lab wing's beacon.
# Pull it (E) and the way back opens and the torch is yours again. Zero panic; FALLBACK_S opens
# it for a player who never finds the lever. Iron Lung's one-glimpse navigation.

signal sealed
signal released(reason: String)

const MAP_FLASH_S := 0.4
const MAP_FLASH_DELAY := 1.2
const KNOCK_GAP_S := 0.45
const FALLBACK_S := 60.0

var _player: CharacterBody3D = null
var _sealed: bool = false
var _released: bool = false
var _t: float = 0.0
var _knock_t: float = 0.0
var _map_shown: bool = false
var _gate: Node3D = null
var _map_quad: MeshInstance3D = null
var _map_light: OmniLight3D = null
var _lever: Node = null
var _hum_far: AudioStreamPlayer3D = null
var _hum_near: AudioStreamPlayer3D = null
var _knock_material := {}    # collider name -> "wood"|"stone"|"metal"


func setup(gate: Node3D, map_quad: MeshInstance3D, map_light: OmniLight3D, lever: Node, knock_material: Dictionary) -> void:
	_gate = gate
	_map_quad = map_quad
	_map_light = map_light
	_lever = lever
	_knock_material = knock_material
	if _map_quad:
		_map_quad.visible = false
	if _map_light:
		_map_light.visible = false
	if _gate:
		_gate.visible = false
		_set_gate_solid(false)


func is_sealed() -> bool:
	return _sealed


func is_released() -> bool:
	return _released


func map_shown() -> bool:
	return _map_shown


func seal() -> void:
	if _sealed:
		return
	_sealed = true
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _gate:
		_gate.visible = true
		_set_gate_solid(true)
	_play("door_slam", _gate.global_position if _gate else global_position, 2.0)
	# ⚠️ force_flashlight_off / restore_flashlight, NOT lock/unlock: `unlock_flashlight()` only
	# clears the lock and leaves the light OFF, so the player walked out of the blind room in
	# the dark until they pressed F (walk_corridor: "the torch is back" red; player.gd says so
	# above the pair, and hiding_spot.gd made the same mistake — Issue 174).
	if _player and _player.has_method("force_flashlight_off"):
		_player.call("force_flashlight_off")
	sealed.emit()
	get_tree().create_timer(MAP_FLASH_DELAY, false).timeout.connect(_flash_map)
	# the beacon
	_hum_far = _loop("lever_hum_far", 14.0, -6.0)
	_hum_near = _loop("lever_hum_near", 4.0, -2.0)
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("BLIND ROOM sealed")


func _flash_map() -> void:
	if _released or not is_instance_valid(_map_quad):
		return
	_map_shown = true
	_map_quad.visible = true
	if _map_light:
		_map_light.visible = true
	_play("light_pop", _map_quad.global_position, -6.0)
	get_tree().create_timer(MAP_FLASH_S, false).timeout.connect(func() -> void:
		if is_instance_valid(_map_quad):
			_map_quad.visible = false
		if is_instance_valid(_map_light):
			_map_light.visible = false)


func _process(delta: float) -> void:
	if not _sealed or _released:
		return
	_t += delta
	_knock_t -= delta
	if _player and _knock_t <= 0.0 and _player.get_slide_collision_count() > 0:
		for i in _player.get_slide_collision_count():
			var c := _player.get_slide_collision(i)
			var col := c.get_collider()
			if col == null:
				continue
			var nm := String((col as Node).name)
			if _knock_material.has(nm) and c.get_normal().y < 0.3:
				_knock_t = KNOCK_GAP_S
				_play("wall_knock_" + String(_knock_material[nm]), c.get_position(), -2.0)
				break
	if _t >= FALLBACK_S:
		release("fallback")


## The lever calls this (E).
func release(reason: String = "lever") -> void:
	if _released:
		return
	_released = true
	if _gate:
		_gate.visible = false
		_set_gate_solid(false)
	_play("latch_release", _gate.global_position if _gate else global_position, 0.0)
	for h in [_hum_far, _hum_near]:
		if is_instance_valid(h):
			if h.finished.is_connected(h.play):
				h.finished.disconnect(h.play)
			h.stop()
			h.queue_free()
	if _player and _player.has_method("restore_flashlight"):
		_player.call("restore_flashlight")
	released.emit(reason)
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("BLIND ROOM released (%s) after %.1f s" % [reason, _t])


func _set_gate_solid(on: bool) -> void:
	if _gate == null:
		return
	for c in _gate.get_children():
		if c is CSGShape3D:
			(c as CSGShape3D).use_collision = on


func _loop(base: String, unit: float, db: float) -> AudioStreamPlayer3D:
	var s: AudioStream = GameState.load_audio(base)
	if s == null or _lever == null:
		return null
	var a := AudioStreamPlayer3D.new()
	a.name = "Beacon_" + base
	a.stream = s
	a.unit_size = unit
	a.max_db = 3.0
	a.volume_db = db
	a.bus = AudioBuses.AMBIENCE
	add_child(a)
	a.global_position = (_lever as Node3D).global_position + Vector3(0, 1.0, 0)
	a.finished.connect(a.play)
	a.play()
	return a


func _play(base: String, pos: Vector3, db: float) -> void:
	var s: AudioStream = GameState.load_audio(base)
	if s == null:
		return
	var a := AudioStreamPlayer3D.new()
	a.stream = s
	a.volume_db = db
	a.unit_size = 8.0
	a.bus = AudioBuses.AMBIENCE
	add_child(a)
	a.global_position = pos
	a.finished.connect(a.queue_free)
	a.play()
