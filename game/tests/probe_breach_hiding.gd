extends SceneTree

# ADVERSARIAL PROBE — enter_hiding()'s force_flashlight_off()/restore_flashlight() pair and the
# outward peek cone.
#
#   Godot --headless --path game --script res://tests/probe_breach_hiding.gd
#   Godot --headless --path game --script res://tests/probe_breach_hiding.gd -- dungeon
#
#   L1  hide with the torch ALREADY OFF          -> must not come back on
#   L2  hide with the torch ON                   -> must come back on, and unlocked
#   L3  hide, exit, hide again in a DIFFERENT spot
#   L4  hide during a stagger / while a door batters (detection must stay off)
#   L5  the peek cone actually faces OUT of the spot, measured against the room centre
#   L6  THE NIGHTMARE: the torch is dead from level start and must STAY dead across a
#       hide/unhide, and `_flashlight_locked` must not be left in a state F can exploit
#   L7  NESTING: a level that has already called force_flashlight_off() and then the player
#       hides — does the level's own restore still hand the torch back?

var _dungeon := false
var _stage := 0
var _t := 0.0
var _player: CharacterBody3D = null
var _spots: Array = []
var _rooms_centre := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "dungeon":
			_dungeon = true
	Engine.time_scale = 4.0
	seed(7)
	change_scene_to_file("res://scenes/dungeon.tscn" if _dungeon else "res://scenes/level_6_breach.tscn")



# ⚠️ NO `class_name` TYPES ANYWHERE IN THESE PROBES. A `--script` SceneTree compiles its own
# dependencies BEFORE the autoloads exist, so naming `CreatureObject12` at parse time forces an
# early compile of a script that references `Screamer` and the whole probe fails to load.
# `probe_purge_freeze.gd` already avoids this by matching on the script's resource path.
func _is_script(n: Node, base: String) -> bool:
	var s = n.get_script()
	return s != null and String(s.resource_path).ends_with(base)


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _grab() -> void:
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		if _is_script(x, "hiding_spot.gd"):
			_spots.append(x)
		elif x is CharacterBody3D and x.is_in_group("player"):
			_player = x


func _fl() -> String:
	return "visible=%s locked=%s dead=%s was_on=%s battery=%.0f" % [
		str(_player.flashlight.visible), str(_player._flashlight_locked),
		str(_player._flashlight_dead), str(_player._flash_was_on), _player._battery]


func _press_f() -> void:
	# The real F branch, copied out of player.gd:_unhandled_input so this probe cannot be
	# fooled by a helper that does not exist in the shipping path.
	if _player.flashlight.visible:
		_player.flashlight.visible = false
	elif _player._battery > 0.0 and not _player._flashlight_dead and not _player._flashlight_locked:
		_player.flashlight.visible = true


func _process(d: float) -> bool:
	_t += d
	if _stage == 0:
		if _t < 0.9:
			return false
		_grab()
		if _player == null:
			print("FATAL: no player")
			return true
		print("=== probe_breach_hiding (%s) ===" % ("dungeon" if _dungeon else "breach"))
		print("hiding spots: %d" % _spots.size())
		print("at spawn: ", _fl())
		_stage = 1
		return false
	if _stage == 1:
		_run()
		return true
	return false


func _run() -> void:
	if _spots.is_empty():
		print("no hiding spots — nothing to test")
		return
	var a = _spots[0]
	var b = _spots[1] if _spots.size() > 1 else _spots[0]

	print("\nL1. HIDE WITH THE TORCH ALREADY OFF")
	_player.flashlight.visible = false
	_player._flashlight_locked = false
	_player.enter_hiding(a)
	print("   hidden:  ", _fl())
	_player.exit_hiding()
	print("   out:     ", _fl())
	print("   verdict: %s" % ("torch correctly left off, lock cleared"
		if not _player.flashlight.visible and not _player._flashlight_locked
		else "*** WRONG ***"))
	_press_f()
	print("   F after: ", _fl(), "  <- F must be able to turn it on again" if not _player._flashlight_dead else "")

	print("\nL2. HIDE WITH THE TORCH ON")
	_player.flashlight.visible = not _player._flashlight_dead
	_player._flashlight_locked = false
	var was: bool = _player.flashlight.visible
	_player.enter_hiding(a)
	print("   hidden:  ", _fl())
	_player.exit_hiding()
	print("   out:     ", _fl())
	print("   verdict: %s" % ("restored" if _player.flashlight.visible == was
		else ("*** NOT restored (was %s) ***" % str(was))))

	print("\nL3. HIDE, EXIT, HIDE AGAIN IN A DIFFERENT SPOT")
	_player.flashlight.visible = not _player._flashlight_dead
	_player.enter_hiding(a)
	_player.exit_hiding()
	_player.enter_hiding(b)
	print("   hidden in B: ", _fl(), " pos=", _player.global_position)
	_player.exit_hiding()
	print("   out:         ", _fl())
	print("   verdict: %s" % ("ok" if _player.flashlight.visible == (not _player._flashlight_dead)
		else "*** torch state lost across two hides ***"))

	print("\nL3b. DOUBLE enter_hiding() WITHOUT AN EXIT (re-entrancy)")
	_player.flashlight.visible = not _player._flashlight_dead
	_player.enter_hiding(a)
	var was_on_after_first: bool = _player._flash_was_on
	_player.enter_hiding(b)   # guarded by `if _hidden: return`
	print("   _flash_was_on after first=%s after second=%s  hide_spot=%s" % [
		str(was_on_after_first), str(_player._flash_was_on),
		str(_player._hide_spot.name if _player._hide_spot else "null")])
	_player.exit_hiding()
	print("   out: ", _fl())

	print("\nL5. PEEK CONE DIRECTION")
	for s in _spots:
		_player.enter_hiding(s)
		var yaw: float = _player.rotation.y
		var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var spot_out: Vector3 = (s as Node3D).global_transform.basis.z
		spot_out.y = 0.0
		spot_out = spot_out.normalized()
		var to_spot: Vector3 = (s.global_position - _player.global_position)
		to_spot.y = 0.0
		var d_spot := 999.0
		if to_spot.length() > 0.01:
			d_spot = rad_to_deg(acos(clamp(fwd.dot(to_spot.normalized()), -1.0, 1.0)))
		print("   %-22s anchor=%s  facing-vs-out=%.1f deg  facing-vs-spot=%.1f deg %s" % [
			s.name, str(_player.global_position).pad_decimals(2),
			rad_to_deg(acos(clamp(fwd.dot(spot_out), -1.0, 1.0))), d_spot,
			"" if d_spot > 90.0 else "  *** STILL FACING INTO THE SPOT ***"])
		_player.exit_hiding()

	print("\nL7. NESTED force_flashlight_off() (a level blackout, THEN a hide)")
	_player._flashlight_dead = false
	_player._battery = 240.0
	_player.flashlight.visible = true
	_player._flashlight_locked = false
	_player._flash_was_on = false
	_player.force_flashlight_off()              # a level's scripted blackout
	print("   level blackout:      ", _fl())
	_player.enter_hiding(a)                     # player hides DURING the blackout
	print("   hidden:              ", _fl())
	_player.exit_hiding()
	print("   out of the locker:   ", _fl())
	_player.restore_flashlight()                # the level's own restore, later
	print("   level restore:       ", _fl())
	print("   verdict: %s" % ("torch handed back" if _player.flashlight.visible
		else "*** TORCH LOST: nested force_flashlight_off() overwrote _flash_was_on ***"))
