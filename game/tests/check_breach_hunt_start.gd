extends SceneTree

# ⭐ 2026-09-23 (the user's call: "I do not like that the creature is just standing here at the moment
# the true level begins … appear at the random place in the level"). Object 12 is ABSENT through the
# arrival grace (invisible, collider off), then appears UNSEEN: a random hunt room, far from the
# player, out of their sight, never EastVault (the flashlight) or ExitVault (the purge chamber), and
# unannounced. Ten seeded starts from varied player positions and facings, through the level's own
# `_tick_familiarization`. The grace length is shortened for speed only; the timing itself is guarded
# by check_breach_flashlight (20 s / 8 s on the live clock).
const SCENE := "res://scenes/level_6_breach.tscn"
const RUNS := 10
const STARTS := [
	[Vector3(0, 0.1, -2), 0.0],         # Entry, looking up the spine
	[Vector3(0, 0.1, 14), 0.0],         # Junction1, looking north
	[Vector3(0, 0.1, 22), PI / 2.0],    # Atrium, looking west
	[Vector3(7, 0.1, 25), PI],          # WardA, looking south
	[Vector3(-7, 0.1, 22), -PI / 2.0],  # WestHall, looking east
]
var _fails := 0
var _checks := 0
var _started := 0
var _positions: Array = []


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started > 180000:
		print("FAIL hunt-start test timed out")
		quit(1)
	return false


func _ok(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", label])


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run() -> void:
	for i in RUNS:
		seed(9001 + i)
		change_scene_to_file(SCENE)
		await create_timer(1.6).timeout
		var level := current_scene
		preload("res://tests/lib/breach_hunt_fixture.gd").enter(level)
		var player: CharacterBody3D = level.get_node("Player")
		var start: Array = STARTS[i % STARTS.size()]
		player.global_position = start[0]
		player.rotation = Vector3(0, start[1], 0)
		var creature: Node = level.get("_creature")
		var col: CollisionShape3D = creature.get("_body_collider")
		await physics_frame
		await physics_frame
		_ok("run %d: absent during the grace (hidden, no collider, inactive)" % i,
			not creature.get("_body").visible and col.disabled and not creature.get("_active"))
		var before: Vector3 = creature.call("get_creature_position")
		level.set("_familiarization_time", 0.4)
		level.set("_familiarization_t", 0.0)
		var waited := 0.0
		while not creature.get("_active") and waited < 3.0:
			await process_frame
			waited += get_root().get_process_delta_time()
		creature.set_process(false)
		var at: Vector3 = creature.call("get_creature_position")
		var builder: Node = level.get("_builder")
		var east: Vector3 = builder.call("room_center", "EastVault")
		var vault: Vector3 = builder.call("room_center", "ExitVault")
		_ok("run %d: activated" % i, creature.get("_active"))
		_ok("run %d: present again (visible + solid)" % i, creature.get("_body").visible and not col.disabled)
		_ok("run %d: moved away from its dormant spawn" % i, _flat(at, before) > 0.5)
		_ok("run %d: far from the player (%.1f m)" % [i, _flat(at, player.global_position)], _flat(at, player.global_position) >= 8.0)
		_ok("run %d: not in EastVault or ExitVault" % i, _flat(at, east) > 0.6 and _flat(at, vault) > 0.6)
		_ok("run %d: out of the player's sight where it appeared" % i, not creature.call("_visible_to_player", at))
		_ok("run %d: unannounced (no AWAKE objective)" % i,
			not ("AWAKE" in String(root.get_node("GameState").get("current_objective"))))
		_positions.append(Vector2(snappedf(at.x, 0.1), snappedf(at.z, 0.1)))
		# Negative control, once: an impossible minimum distance must find nothing and move nothing.
		if i == 0:
			var here: Vector3 = creature.call("get_creature_position")
			_ok("control: an impossible min_dist returns false", not creature.call("spawn_unseen", 10000.0, []))
			_ok("control: ...and leaves the body where it was", _flat(creature.call("get_creature_position"), here) < 0.01)
	var distinct := {}
	for p in _positions:
		distinct[p] = true
	_ok("spawns vary across runs (%d distinct rooms in %d)" % [distinct.size(), RUNS], distinct.size() >= 3)
	_ok("sample count is meaningful", _checks >= RUNS * 7)
	print("BREACH HUNT START: %d checks, %d failed" % [_checks, _fails])
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit(1 if _fails else 0)
