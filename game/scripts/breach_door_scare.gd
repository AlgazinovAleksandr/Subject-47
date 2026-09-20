extends Node

# Level-owned, reversible presentation. Door timers/collision remain in SlamDoor.
# Torch cull masks compose with hiding's energy dim and F's visibility without stealing either.
const EFFECT_RADIUS := 10.0
const BLACKOUT_TAIL := 0.8
var _player: CharacterBody3D
var _lamps: Array = []
var _doors: Array = []
var _quiet: Dictionary = {}
var _lamp_visibility: Dictionary = {}
var _bed_volumes: Dictionary = {}
var _torch_mask := -1
var _leaf_positions: Dictionary = {}
var _impact_tweens: Dictionary = {}


func configure(player: CharacterBody3D, lamps: Array, doors: Array) -> void:
	_player = player
	_lamps = lamps
	_doors = doors
	for door in _doors:
		door.batter_started.connect(_started.bind(door))
		door.batter_silenced.connect(_silenced.bind(door))
		door.broken_open.connect(_ended.bind(door))
		door.batter_impact.connect(_impact.bind(door))
		for leaf in [door.get("_hinge"), door.get("_hinge_r")]:
			_leaf_positions[leaf] = leaf.position


func _impact(door: Node3D) -> void:
	_settle_leaves(door)
	var push := 1.0
	if is_instance_valid(_player):
		push = signf((_player.global_position - door.global_position).dot(door.global_basis.z))
	var force := lerpf(0.045, 0.10, 1.0 - clampf(float(door.get("_batter_t")) / 6.0, 0.0, 1.0))
	var tween := create_tween().set_parallel(true)
	_impact_tweens[door] = tween
	for leaf in [door.get("_hinge"), door.get("_hinge_r")]:
		var rest: Vector3 = _leaf_positions[leaf]
		tween.tween_property(leaf, "position", rest + Vector3(0, force * 0.18, push * force), 0.055)
	# Hold the peak long enough to read even at 30 fps before the metal springs back.
	tween.chain().tween_interval(0.05)
	tween.chain()
	for leaf in [door.get("_hinge"), door.get("_hinge_r")]:
		tween.tween_property(leaf, "position", _leaf_positions[leaf], 0.16).set_trans(Tween.TRANS_BOUNCE)


func _settle_leaves(door: Node) -> void:
	if _impact_tweens.has(door):
		var tween: Tween = _impact_tweens[door]
		if tween.is_valid():
			tween.kill()
		_impact_tweens.erase(door)
	for leaf in [door.get("_hinge"), door.get("_hinge_r")]:
		if is_instance_valid(leaf) and _leaf_positions.has(leaf):
			leaf.position = _leaf_positions[leaf]


func _near(door: Node3D) -> bool:
	return is_instance_valid(_player) and _player.global_position.distance_to(door.global_position) <= EFFECT_RADIUS


func _started(door: Node3D) -> void:
	_note("POUND", door)


func _silenced(door: Node3D) -> void:
	_settle_leaves(door)
	_quiet[door] = true
	_note("SILENCE", door)
	_process(0.0)


func _ended(door: Node3D) -> void:
	_settle_leaves(door)
	_quiet.erase(door)
	_note("BREAK / LIGHT RESTORED", door)
	_process(0.0)


func torch_is_interrupted() -> bool:
	return _torch_mask >= 0


func _process(_delta: float) -> void:
	var quiet_nearby := false
	var dark_nearby := false
	var dark_lamps: Dictionary = {}
	for door in _quiet.keys():
		if not is_instance_valid(door) or not door.get("_battering"):
			_quiet.erase(door)
			continue
		if not _near(door):
			continue
		quiet_nearby = true
		if float(door.get("_batter_t")) > BLACKOUT_TAIL:
			continue
		dark_nearby = true
		for entry in _lamps:
			var lamp: Light3D = entry[0]
			if is_instance_valid(lamp) and lamp.global_position.distance_to(door.global_position) <= EFFECT_RADIUS:
				dark_lamps[lamp] = true
	for lamp in _lamp_visibility.keys():
		if not dark_lamps.has(lamp):
			if is_instance_valid(lamp):
				lamp.visible = _lamp_visibility[lamp]
			_lamp_visibility.erase(lamp)
	for lamp in dark_lamps:
		if not _lamp_visibility.has(lamp):
			_lamp_visibility[lamp] = lamp.visible
		lamp.visible = false
	_set_torch_dark(dark_nearby)
	_set_quiet(quiet_nearby)


func _set_torch_dark(dark: bool) -> void:
	if not is_instance_valid(_player):
		return
	var torch: SpotLight3D = _player.get("flashlight")
	if not is_instance_valid(torch):
		return
	if dark and _torch_mask < 0:
		_torch_mask = torch.light_cull_mask
		torch.light_cull_mask = 0
		_note("BLACKOUT", null)
	elif not dark and _torch_mask >= 0:
		torch.light_cull_mask = _torch_mask
		_torch_mask = -1


func _set_quiet(quiet: bool) -> void:
	if quiet:
		# Only this level's continuous beds. Body sounds and the final crash keep their gain.
		for child in get_parent().get_children():
			if child is AudioStreamPlayer and not _bed_volumes.has(child):
				_bed_volumes[child] = child.volume_db
				child.volume_db -= 32.0
	else:
		for bed in _bed_volumes:
			if is_instance_valid(bed):
				bed.volume_db = _bed_volumes[bed]
		_bed_volumes.clear()


func _exit_tree() -> void:
	for door in _doors:
		if is_instance_valid(door):
			_settle_leaves(door)
	_set_torch_dark(false)
	_set_quiet(false)
	for lamp in _lamp_visibility:
		if is_instance_valid(lamp):
			lamp.visible = _lamp_visibility[lamp]
	_lamp_visibility.clear()


func _note(phase: String, door: Node) -> void:
	var log_node := get_node_or_null("/root/DebugLog")
	if log_node:
		log_node.note("BREACH DOOR %s %s" % [phase, door.name if door else ""])
