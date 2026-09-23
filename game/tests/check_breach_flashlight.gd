extends SceneTree

# Shipping geometry and E-ray, physical walking, F handler and real scene reloads.
# Creature timing is live; park it only for deterministic route/interaction checks.
const SCENE := "res://scenes/level_6_breach.tscn"
const OUT := "/tmp/breach_flashlight/"
var _level: Node
var _player: CharacterBody3D
var _creature: Node
var _fails := 0
var _checks := 0
var _started := 0
var _shots := false

func _initialize() -> void:
	_started = Time.get_ticks_msec()
	_shots = OS.get_cmdline_user_args().has("--screenshots")
	seed(2147)
	change_scene_to_file(SCENE)
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started > 150000:
		print("FAIL flashlight test timed out")
		quit(1)
	return false

func _ok(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", label])

func _bind() -> void:
	_level = current_scene
	_player = _level.get_node("Player")
	_player.set("ai_active", true)
	_creature = _level.get("_creature")

func _f() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.keycode = KEY_F
	event.pressed = true
	_player.call("_unhandled_input", event)

func _shot(label: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	root.get_texture().get_image().save_png(OUT + label + ".png")

func _walk(target: Vector3) -> void:
	var start := Time.get_ticks_msec()
	while Vector2(_player.position.x - target.x, _player.position.z - target.z).length() > 0.22:
		_player.call("ai_look_at", Vector3(target.x, 1.75, target.z))
		_player.set("ai_move_dir", Vector2(0, -1))
		await physics_frame
		if Time.get_ticks_msec() - start > 7000:
			_ok("walk reaches %s (stopped at %s)" % [target, _player.position], false)
			_player.set("ai_move_dir", Vector2.ZERO)
			return
	_player.set("ai_move_dir", Vector2.ZERO)
	await physics_frame
	_ok("physical walking reaches %s" % target, true)

func _enter(spot: Node3D) -> void:
	_player.call("ai_look_at", spot.global_position + Vector3(0, 0.9, 0))
	await physics_frame
	_ok("E ray targets %s" % spot.name, _player.call("ai_interact_target") == spot)
	_player.call("ai_interact")
	await process_frame
	await process_frame

func _run() -> void:
	await create_timer(1.8).timeout
	_bind()
	preload("res://tests/lib/breach_hunt_fixture.gd").enter(_level)
	var gs := root.get_node("GameState")
	var cabinet: Node3D = _level.get("_flashlight_cabinet")
	var fixed_position := cabinet.global_position
	_ok("starts missing, locked and dark", not _level.get("_flashlight_found") and _player.get("_flashlight_locked") and not _player.call("is_flashlight_on"))
	_ok("objective explains the search", "MISSING" in String(gs.get("current_objective")))
	_f()
	_ok("F cannot summon the missing flashlight", not _player.call("is_flashlight_on"))
	# ⚠️ 2026-09-23 (the user's call): the cabinet moved to EastVault, the east dead end, so the
	# light and the purge chamber are in opposite wings. Measured from the purge door (-7, 48).
	_ok("fixed cabinet is the EastVault dead end", fixed_position.x > 10 and fixed_position.z > 21 and fixed_position.z < 27)
	_ok("cabinet is far from the purge door (%.1f m)" % Vector2(fixed_position.x + 7, fixed_position.z - 48).length(),
		Vector2(fixed_position.x + 7, fixed_position.z - 48).length() > 25.0)
	var archive_b: HidingSpot
	for child in _level.get_children():
		if child is HidingSpot and child.global_position.distance_to(Vector3(-9.78, 0, 37.5)) < 2:
			archive_b = child
	_ok("ArchiveB keeps an ORDINARY cabinet", archive_b != null and archive_b != cabinet)
	_ok("arrival grace keeps creature dormant", not _level.get("_creature_awake"))
	await _shot("01_entry_without_flashlight")
	# ⚠️ FIRST attempt: 20 s (2026-09-23). The old 8 s mark must now pass with it still dormant.
	await create_timer(8.2).timeout
	_ok("first-attempt grace outlasts the old 8 s", not _level.get("_creature_awake"))
	await create_timer(12.0).timeout
	_ok("creature wakes at the 20 s first-attempt grace, during the search", _level.get("_creature_awake") and not _level.get("_flashlight_found"))
	_creature.set_process(false)
	_creature.call("_ensure_player")
	var body: Node3D = _creature.get("_body")
	body.global_position = Vector3(0, 0, 6)
	_player.call("ai_look_at", Vector3(0, 0.9, 6))
	_creature.call("force_chase")
	_player.get("flashlight").visible = true
	await physics_frame
	var shield: float = _creature.get("_shield")
	_level.call("_tick_light_weapon", 0.5)
	_ok("unowned beam cannot damage the creature", _creature.get("_shield") == shield)
	_player.get("flashlight").visible = false
	body.global_position = Vector3(7, 0, 44.5)
	_creature.call("_enter", 0)
	# Walk via the western loop, including a real non-pickup hiding stop in Records.
	for point in [Vector3(0, 0, 7), Vector3(0, 0, 14), Vector3(-7, 0, 14)]:
		await _walk(point)
	var other: Node3D
	for child in _level.get_children():
		if child is HidingSpot and child.global_position.distance_to(Vector3(-9.78, 0, 14)) < 2:
			other = child
	_ok("Records has an ordinary cabinet", other != null)
	if other == null:
		quit(1)
		return
	await _walk(other.global_position + other.global_basis.z * 1.1)
	await _enter(other)
	_ok("other cabinet hides without collecting", _player.call("is_hidden") and not _level.get("_flashlight_found"))
	_player.call("ai_interact")
	await process_frame
	_ok("leaving other cabinet keeps torch missing", not _player.call("is_hidden") and _player.get("_flashlight_locked"))
	# Back across the spine and into the east wing: Junction1 -> Atrium -> WardA -> EastVault.
	for point in [Vector3(0, 0, 14), Vector3(0, 0, 21), Vector3(7, 0, 21), Vector3(7, 0, 24), Vector3(13, 0, 24)]:
		await _walk(point)
	var clue: Node = _level.get("_flashlight_clue")
	await _walk(cabinet.global_position + cabinet.global_basis.z * 1.1)
	_player.call("ai_look_at", cabinet.global_position + Vector3(0, 0.8, 0))
	clue.set("_time", 0.0)
	await _shot("02_cabinet_clue")
	await _enter(cabinet)
	_ok("E recovers the flashlight from the correct cabinet", _level.get("_flashlight_found") and not _player.get("_flashlight_locked"))
	_ok("pickup leaves the player hidden with light off", _player.call("is_hidden") and not _player.call("is_flashlight_on"))
	_ok("collected clue turns off", clue.get("_taken") and not clue.get("_glow").visible)
	_ok("physical prop lifts into the camera", clue.get("_torch").get_parent() == _player.get_node("Camera3D"))
	await create_timer(0.2).timeout
	await _shot("03_hidden_pickup")
	_f()
	_ok("F works after collection while hidden", _player.call("is_flashlight_on"))
	body.global_position = _player.global_position + cabinet.global_basis.z * 0.6
	_creature.call("force_chase")
	_creature.call("_check_contact")
	_ok("pickup and F cannot expose player to contact death", _level.get("_kill_sequence") == null and _player.call("is_hidden"))
	body.global_position = Vector3(7, 0, 44.5)
	_creature.call("_enter", 0)
	_player.call("ai_interact")
	await process_frame
	_ok("exit keeps the recovered flashlight usable", not _player.call("is_hidden") and _player.call("is_flashlight_on"))
	_level.call("_recover_flashlight", true)
	_ok("repeated recovery does not reset F state", _player.call("is_flashlight_on"))
	await create_timer(1.0).timeout
	await _shot("04_recovered_light")
	# The other way out of the east wing is the WardA <-> Junction2 loop: walk its physical doorway too.
	for point in [Vector3(7, 0, 24), Vector3(7, 0, 30), Vector3(0, 0, 30)]:
		await _walk(point)
	var saved: Dictionary = _level.call("save_progress")
	_ok("progress saves flashlight ownership", saved.get("flashlight_found", false))
	gs.get("level_progress")[6] = saved
	change_scene_to_file(SCENE)
	await create_timer(1.0).timeout
	_bind()
	_ok("normal return restores ownership with light off", _level.get("_flashlight_found") and not _player.get("_flashlight_locked") and not _player.call("is_flashlight_on"))
	_ok("normal return removes cabinet clue", _level.get("_flashlight_clue").get("_taken"))
	_f()
	_ok("restored torch responds to F", _player.call("is_flashlight_on"))
	gs.call("restart_current_level")
	await create_timer(1.2).timeout
	_bind()
	_ok("death restart makes the flashlight missing again", not _level.get("_flashlight_found") and _player.get("_flashlight_locked"))
	_ok("death restart keeps the exact cabinet location", _level.get("_flashlight_cabinet").global_position == fixed_position)
	# ⚠️ RETRY: 8 s (2026-09-23). The checkpoint seals the approach on load, so the grace clock has
	# been running since _ready(); align to it once, then assert on the creature's own state.
	_ok("retry resumes at the sealed checkpoint", _level.get("_approach_complete"))
	var already: float = float(_level.get("_familiarization_t"))
	await create_timer(maxf(0.0, 7.6 - already)).timeout
	_ok("retry grace still dormant just before 8 s", not _level.get("_creature_awake"))
	await create_timer(0.8).timeout
	_ok("retry grace wakes the creature at 8 s", _level.get("_creature_awake"))
	_level.get("_creature").set_process(false)
	# The creature can be sealed before recovering the optional defensive tool.
	_level.set("_creature_defeated", true)
	_level.call("_recover_flashlight", false)
	_ok("late recovery preserves the escape objective", "IS OPEN" in String(gs.get("current_objective")))
	gs.get("level_progress")[6] = {"creature_defeated": true}
	change_scene_to_file(SCENE)
	await create_timer(1.0).timeout
	_bind()
	_ok("older completed saves retain a usable torch", _level.get("_flashlight_found") and not _player.get("_flashlight_locked") and _level.get("_creature_defeated"))
	print("BREACH FLASHLIGHT: %d checks, %d failed" % [_checks, _fails])
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit(1 if _fails else 0)
