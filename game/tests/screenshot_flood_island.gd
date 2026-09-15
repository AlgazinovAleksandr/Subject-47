extends SceneTree
# R5/R6 (2026-09-16): photograph the Flood's pool island and the altar as the relics wake.
# Run WITHOUT --headless. Self-terminating. /tmp/flood_island/
const OUT := "/tmp/flood_island/"
var _lvl: Node
var _zone: Node
var _player: CharacterBody3D
var _plate: Node3D
var _f := 0
var _total := 0
var _t := 0.0
var _stage := 0
var _shots := {}
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	seed(7)
	change_scene_to_file("res://scenes/backrooms.tscn")
func _shoot(n: String) -> void:
	if _shots.has(n):
		return
	_shots[n] = true
	root.get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
	print("shot: ", n)
func _process(delta: float) -> bool:
	_total += 1
	_t += delta
	if _total > 2400:
		print("RESULT: FAIL (timeout at stage %d)" % _stage)
		quit(1)
		return true
	if current_scene == null:
		return false
	_f += 1
	match _stage:
		0:
			if _f < 30:
				return false
			_lvl = current_scene
			_player = _lvl.get_node("Player")
			_player.set("ai_active", true)
			_lvl.call("_enter_zone", 3)
			_zone = _lvl.get_node("ZoneFlood")
			_plate = _zone.get_node("FloodPlate")
			_stage = 1
			_f = 0
			return false
		1:
			if _f < 20:
				return false
			var origin: Vector3 = _zone.get("_origin")
			var deck: Node3D = _zone.get_node("DryPlatform")
			# from the Descent doorway, looking at the pool
			_player.global_position = origin + Vector3(0, 0.1, 11.8)
			_player.velocity = Vector3.ZERO
			_player.call("force_update_transform")
			_player.call("ai_look_at", deck.global_position + Vector3(0, 0.6, 0))
			_stage = 2
			_f = 0
			return false
		2:
			if _f == 25:
				_shoot("1_pool_from_doorway")
				var deck: Node3D = _zone.get_node("DryPlatform")
				_player.global_position = deck.global_position + Vector3(-2.6, 0.1, 2.8) - Vector3(0, 0.22, 0) + Vector3(0, 0.22, 0)
				_player.velocity = Vector3.ZERO
				_player.call("force_update_transform")
				_player.call("ai_look_at", deck.global_position + Vector3(0.8, 0.7, -0.5))
			if _f == 50:
				_shoot("2_pool_ladder_side")
				# the altar: seat all six, then watch the wake
				_plate.call("seat_kinds", ["candle", "book", "skull", "bell", "key", "doll"])
				var top_y: float = float(_plate.get("TOP_Y")) + 0.1
				var stand: Vector3 = _plate.to_global(Vector3(0, 0, -1.15))
				_player.global_position = Vector3(stand.x, (_zone.get("_origin") as Vector3).y + 0.1, stand.z)
				_player.velocity = Vector3.ZERO
				_player.call("force_update_transform")
				_player.call("ai_look_at", _plate.to_global(Vector3(0, top_y, 0.05)))
				_t = 0.0
				_stage = 3
			return false
		3:
			if _t > 1.2:
				_shoot("3_altar_candle_lit")
			if _t > 2.0:
				_shoot("4_altar_bell")
			if _t > 3.2:
				_shoot("5_altar_doll_up")
			if _t > 3.6:
				_shoot("6_altar_lamp_gutter")
			if _t > 5.2:
				_shoot("7_altar_after")
				print("RESULT: PASS")
				quit(0)
				return true
	return false
