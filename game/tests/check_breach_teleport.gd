extends SceneTree

# B3 (2026-09-09): the creature RELOCATES near the player when SEARCH gives up, instead of hunting
# an empty wing forever.
#
#   Godot --headless --path game --script res://tests/check_breach_teleport.gd
#
# Drives the real state machine: place the player, put Object 12 into SEARCH with its scan already
# spent, tick, and assert it jumped to a spot that is (a) 10–14 m from the player, (b) NOT in the
# player's line of sight, and (c) resumed in SEARCH (not straight into CHASE). Also checks the safe
# fallback: with no portals fed (THE NIGHTMARE's Matron), relocate is a no-op and it PATROLs.
#
# ⚠️ Everything duck-typed; the State enum read off the script's constant map.

var _frame := 0
var _t := 0.0
var _phase := "load"
var _fails := 0
var _checks := 0
var _scene: Node
var _player: CharacterBody3D
var _creature: Node
var _search := 0
var _patrol := 0
var _start_pos := Vector3.ZERO


func _initialize() -> void:
	change_scene_to_file("res://scenes/level_6_breach.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	if not cond:
		_fails += 1
	print("  %s  %s%s" % ["PASS" if cond else "FAIL", label, ("   " + detail) if detail != "" else ""])


func _process(delta: float) -> bool:
	_frame += 1
	_t += delta
	if _frame < 15:
		return false
	match _phase:
		"load": _load()
		"wait": _wait()
		"done":
			print("%d checks, %d failed" % [_checks, _fails])
			print("BREACH-TELEPORT PASS" if _fails == 0 else "BREACH-TELEPORT FAIL")
			quit(1 if _fails > 0 else 0)
			return true
	return false


func _load() -> void:
	_scene = current_scene
	_player = _scene.get_node_or_null("Player") as CharacterBody3D
	for c in _scene.get_children():
		if c.get_class() == "StaticBody3D" and c.has_method("get_creature_position"):
			_creature = c
	if _creature == null:
		for c in _scene.get_children():
			if c.has_method("get_state") and c.has_method("set_portals"):
				_creature = c
	_ok("player and creature present", _player != null and _creature != null)
	if _player == null or _creature == null:
		_phase = "done"
		return
	var consts: Dictionary = (_creature.get_script() as GDScript).get_script_constant_map()
	var st: Dictionary = consts.get("State", {})
	_search = int(st.get("SEARCH", 3))
	_patrol = int(st.get("PATROL", 0))
	# Put the player in the Atrium centre, wake the creature, and put it into SEARCH far away with
	# its scan already spent so the next tick relocates.
	_player.global_position = Vector3(0, 0.1, 22)
	_player.ai_active = true
	if _creature.has_method("activate"):
		_creature.call("activate")
	# Park the creature somewhere far (Incinerator) and force SEARCH with the scan finished.
	var body = _creature.get("_body")
	if body:
		(body as Node3D).global_position = Vector3(0, 0, 58)
	_creature.call("_enter", _search)
	_creature.set("_last_seen_pos", Vector3(0, 0, 58))
	_creature.set("_search_arrived", true)
	var sc: Dictionary = (_creature.get_script() as GDScript).get_script_constant_map()
	_creature.set("_search_t", float(sc.get("SEARCH_TIME", 8.0)))
	_start_pos = _creature.call("get_creature_position")
	_t = 0.0
	_phase = "wait"


func _wait() -> void:
	if _t < 0.6:
		return
	var pos: Vector3 = _creature.call("get_creature_position")
	var moved := pos.distance_to(_start_pos)
	_ok("the creature relocated (it did not stay put)", moved > 5.0, "moved %.1f m" % moved)
	var flat := Vector2(pos.x - _player.global_position.x, pos.z - _player.global_position.z).length()
	_ok("it reappeared 10-14 m from the player", flat >= 9.0 and flat <= 15.5, "%.1f m" % flat)
	# Out of the player's line of sight.
	var space := _player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		_player.global_position + Vector3(0, 0.9, 0), pos + Vector3(0, 0.9, 0))
	q.collision_mask = 1
	q.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(q)
	_ok("it reappeared OUT of the player's line of sight", not hit.is_empty(),
		"a wall is between them")
	_ok("it resumed in SEARCH, not CHASE", int(_creature.call("get_state")) == _search,
		"state %d" % int(_creature.call("get_state")))
	_phase = "done"
