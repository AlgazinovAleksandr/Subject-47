extends Node3D
class_name SpurBell

# C2 (2026-09-14) built this as BELL-AND-WAIT: E rang, the mouth door slammed, footsteps came up
# the spur and stopped behind you, and looking round decided a card. The user's 2026-09-14 run
# (BACKLOG_Sep_15 C4): "the door did not close... what is this room for?" — and their redesign,
# verbatim in intent: ROOM 217 WON'T OPEN UNTIL YOU HAVE A KEY. Ring the bell and the light goes
# for several seconds; when it comes back there is a KEY beside the bell; that key opens 217,
# where the same illusion waits. The door to this nook never closes behind you.
#
# So this is a SERVICE, not a shut-in: ring → `bell_ding` → BLACKOUT_AFTER later every light
# you have dies (desk lamp, the spur torch, YOUR torch — `force_flashlight_off()`, the
# Issue-174 pair) and something walks up the spur in the dark → BLACKOUT_S later the lights
# return, the walker is gone, and the key is lying by the bell. Zero panic, no fail state, no
# door. `key_taken` is what unlocks `FalseExitDoor` (the level wires it).

signal rung
signal key_placed
signal key_taken
signal served(turned: bool)   # kept for callers of the old beat; emitted once the key is down

const BLACKOUT_AFTER := 1.2     # s after the ding before the lights die
const BLACKOUT_S := 4.5         # s of dark ("several seconds")
const APPROACH_FROM := 22.0     # m down the hall the steps start
const STOP_BEHIND := 1.0        # m behind the player's back where they stop
const STEP_DB := 2.0
const KEY_LABEL := "Room key — 217"
const TAG_TEX := "res://assets/textures/level_3_corridor/key_tag_217.png"

var _desk_pos: Vector3 = Vector3.ZERO
var _bell_pos: Vector3 = Vector3.ZERO
var _mouth: Vector3 = Vector3.ZERO
var _dir: Vector3 = Vector3.ZERO
var _lat: Vector3 = Vector3.ZERO
var _lamp: OmniLight3D = null
var _torch: Node = null
var _player: CharacterBody3D = null
var _steps: AudioStreamPlayer3D = null
var _level: Node = null
var _index: int = 0
var _t: float = -1.0
var _rung: bool = false
var _dark: bool = false
var _done: bool = false
var _key: Node = null
var _key_taken: bool = false
var _lamp_energy: float = 0.7


func setup(level: Node, index: int, desk_pos: Vector3, bell_pos: Vector3, mouth: Vector3, dir: Vector3,
		lamp: OmniLight3D, torch: Node) -> void:
	_level = level
	_index = index
	_desk_pos = desk_pos
	_bell_pos = bell_pos
	_mouth = mouth
	_dir = dir
	_lat = dir.cross(Vector3.UP).normalized()
	_lamp = lamp
	_torch = torch
	if _lamp:
		_lamp_energy = _lamp.light_energy


func is_rung() -> bool:
	return _rung


func is_dark() -> bool:
	return _dark


## True once the lights are back and the key is on the desk.
func is_done() -> bool:
	return _done


func has_key() -> bool:
	return _key_taken


## The bell prop calls this (E).
func ring() -> void:
	if _rung:
		return
	_rung = true
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	rung.emit()
	_play("bell_ding", _desk_pos + Vector3(0, 1.0, 0), 0.0)
	get_tree().create_timer(BLACKOUT_AFTER).timeout.connect(_blackout)


func _blackout() -> void:
	if _done or _dark:
		return
	_dark = true
	if is_instance_valid(_lamp):
		var tw := create_tween()
		tw.tween_property(_lamp, "light_energy", 0.0, 0.12)
	if is_instance_valid(_torch) and _torch.has_method("extinguish"):
		_torch.call("extinguish")
	if is_instance_valid(_player):
		_player.call("force_flashlight_off")
	HoldBreath.dip(get_tree(), BLACKOUT_S)
	# the service, unseen: footsteps up the spur in the dark, stopping at your back
	var s: AudioStream = GameState.load_audio("footstep")
	_steps = AudioStreamPlayer3D.new()
	_steps.name = "BellSteps"
	if s:
		_steps.stream = s
	_steps.unit_size = 10.0
	_steps.max_db = 4.0
	_steps.volume_db = STEP_DB
	_steps.bus = AudioBuses.AMBIENCE
	add_child(_steps)
	_steps.global_position = _mouth - _dir * APPROACH_FROM + Vector3(0, 0.3, 0)
	_steps.finished.connect(_steps.play)
	_steps.play()
	_t = 0.0
	get_tree().create_timer(BLACKOUT_S).timeout.connect(_lights_back)
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("BELL rung — blackout %.1f s" % BLACKOUT_S)


func _behind_point() -> Vector3:
	if _player == null:
		return _mouth
	var to_mouth: Vector3 = _mouth - _player.global_position
	to_mouth.y = 0.0
	if to_mouth.length() < 0.01:
		return _mouth
	return _player.global_position + to_mouth.normalized() * STOP_BEHIND


func _process(delta: float) -> void:
	if _t < 0.0 or _done:
		return
	_t += delta
	var r: float = clampf(_t / BLACKOUT_S, 0.0, 1.0)
	var from: Vector3 = _mouth - _dir * APPROACH_FROM
	if is_instance_valid(_steps):
		_steps.global_position = from.lerp(_behind_point(), r) + Vector3(0, 0.3, 0)
		_steps.pitch_scale = lerpf(1.0, 0.82, r)


func _lights_back() -> void:
	if _done:
		return
	_done = true
	_dark = false
	_t = -1.0
	if is_instance_valid(_steps):
		if _steps.finished.is_connected(_steps.play):
			_steps.finished.disconnect(_steps.play)
		_steps.stop()
		_steps.queue_free()
	if is_instance_valid(_lamp):
		var tw := create_tween()
		tw.tween_property(_lamp, "light_energy", _lamp_energy, 0.25)
	if is_instance_valid(_torch) and _torch.has_method("relight"):
		_torch.call("relight")
	if is_instance_valid(_player):
		_player.call("restore_flashlight")
	_spawn_key()
	_play("latch_release", _bell_pos, -2.0)
	key_placed.emit()
	served.emit(false)
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("BELL served — the 217 key is on the desk")


## The restore path (a back-door return): no blackout, the key simply lies there or is held.
func restore(rung: bool, taken: bool) -> void:
	if not rung:
		return
	_rung = true
	_done = true
	if taken:
		_key_taken = true
		return
	_spawn_key()


# A brass key with the 217 fob, lying beside the bell on the desk. `KeyItem` owns the pickup;
# the parts are the level's (a key is a silhouette first — Issue 35).
func _spawn_key() -> void:
	if _level == null or is_instance_valid(_key):
		return
	var key := KeyItem.new()
	key.name = "Spur%dKey" % _index
	key.label_text = KEY_LABEL
	_level.add_child(key)
	key.global_position = _bell_pos + _lat * -0.26
	key.rotation.y = atan2(_lat.x, _lat.z)
	key.picked_up.connect(_on_key_taken)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.62, 0.48, 0.2)
	brass.metallic = 0.85
	brass.roughness = 0.4
	var shaft := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.006
	sc.bottom_radius = 0.006
	sc.height = 0.075
	shaft.mesh = sc
	shaft.material_override = brass
	shaft.rotation.x = PI / 2.0
	shaft.position = Vector3(0, 0.008, 0.02)
	key.add_child(shaft)
	var bow := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.012
	tm.outer_radius = 0.022
	bow.mesh = tm
	bow.material_override = brass
	bow.position = Vector3(0, 0.008, -0.03)
	key.add_child(bow)
	for k in [[0.0, 0.048], [0.0, 0.056]]:
		var bit := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.006, 0.012, 0.006)
		bit.mesh = bm
		bit.material_override = brass
		bit.position = Vector3(0, 0.014, float(k[1]))
		key.add_child(bit)
	# the fob, flat on the desk, hung off the bow
	var tag := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.075, 0.047)   # 512x320 art
	tag.mesh = qm
	var tmat := StandardMaterial3D.new()
	if ResourceLoader.exists(TAG_TEX):
		var tex := load(TAG_TEX)
		tmat.albedo_texture = tex
		tmat.emission_enabled = true
		tmat.emission_texture = tex
		tmat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		tmat.emission_energy_multiplier = 0.3   # findable, not a beacon
		tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		tmat.alpha_scissor_threshold = 0.5
	else:
		tmat.albedo_color = Color(0.55, 0.42, 0.18)
	tmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tag.material_override = tmat
	tag.rotation = Vector3(-PI / 2.0, 0, 0)
	tag.position = Vector3(-0.045, 0.004, -0.07)
	key.add_child(tag)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 0.08, 0.2)
	col.shape = shape
	col.position = Vector3(0, 0.03, 0)
	key.add_child(col)
	_key = key


func _on_key_taken() -> void:
	_key_taken = true
	GameState.set_carried(KEY_LABEL)
	key_taken.emit()
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note("BELL key taken")


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
