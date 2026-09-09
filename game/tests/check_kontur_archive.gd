extends SceneTree

# A5 (capture #8): the Recovery Archive's bait-vs-real hidden keycard.
#
#   Godot --headless --path game --script res://tests/check_kontur_archive.gd
#
# Drives the REAL interact path: search a DECOY lot (nudges, reveals nothing), search the KEY lot
# (reveals a takeable keycard), take it, then open the sealed transit door with it. The whole point
# of the feature is that the door gates progress and the keycard is always findable, so this proves
# both halves rather than trusting the structure check.
#
# ⚠️ Everything duck-typed; autoloads by path.

var _frame := 0
var _elapsed := 0.0
var _fails := 0
var _checks := 0
var _phase := "load"
var _t0 := 0.0
var _scene: Node
var _player: CharacterBody3D
var _lots: Array = []
var _key_lot: Node = null
var _decoy_lot: Node = null
var _gate: Node = null


func _initialize() -> void:
	change_scene_to_file("res://scenes/kontur.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	if not cond:
		_fails += 1
	print("  %s  %s%s" % ["PASS" if cond else "FAIL", label, ("   " + detail) if detail != "" else ""])


func _aim_from(aim: Vector3, dist: float, deg: float) -> void:
	var off := Vector3(sin(deg_to_rad(deg)), 0.0, cos(deg_to_rad(deg))) * dist
	_player.global_position = Vector3(aim.x + off.x, 0.1, aim.z + off.z)
	_player.ai_active = true
	_player.ai_look_at(aim)
	_player.ai_interact_target()


# Stand in the AISLE (near x=0) at the lot's z and look at its protruding interact collider (~x
# ±1.90). Standing next to the rack itself would put the player inside the rack's solid collider.
func _stand_in_aisle_for(worldx: float, z: float, target: Vector3) -> void:
	var side: float = signf(worldx)
	if side == 0.0:
		side = 1.0
	_player.global_position = Vector3(side * 0.9, 0.1, z)
	_player.ai_active = true
	_player.ai_look_at(target)
	_player.ai_interact_target()


func _aim_lot(lot: Node) -> void:
	var p: Vector3 = (lot as Node3D).global_position
	var side: float = signf(p.x)
	if side == 0.0:
		side = 1.0
	_stand_in_aisle_for(p.x, p.z, Vector3(side * 1.90, p.y + 0.16, p.z))


func _process(delta: float) -> bool:
	_frame += 1
	_elapsed += delta
	if _frame < 10:
		return false
	match _phase:
		"load": _load()
		"decoy": _decoy(delta)
		"key": _key(delta)
		"take": _take(delta)
		"gate": _gate_phase(delta)
		"done":
			print("%d checks, %d failed" % [_checks, _fails])
			print("KONTUR-ARCHIVE PASS" if _fails == 0 else "KONTUR-ARCHIVE FAIL")
			quit(1 if _fails > 0 else 0)
			return true
	return false


func _load() -> void:
	_scene = current_scene
	_player = _scene.get_node_or_null("Player") as CharacterBody3D
	_ok("player present", _player != null)
	for n in ["Lot_sheet", "Lot_lever", "Lot_box", "Lot_plate", "Lot_handset", "Lot_empty"]:
		var l := _scene.get_node_or_null(n)
		if l:
			_lots.append(l)
			if bool(l.get("has_key")):
				_key_lot = l
			elif _decoy_lot == null:
				_decoy_lot = l
	_ok("all six lots present", _lots.size() == 6)
	_ok("exactly one lot hides the keycard", _key_lot != null)
	_gate = _scene.get_node_or_null("ArchiveGate")
	_ok("the transit gate exists and is shut", _gate != null and bool(_gate.call("can_interact")))
	if not (_player and _key_lot and _decoy_lot and _gate):
		_phase = "done"
		return
	# Search a decoy first.
	_aim_lot(_decoy_lot)
	_ok("the interact ray finds the decoy lot from the aisle",
		_player.ai_interact_target() == _decoy_lot,
		"ray saw %s" % [_player.ai_interact_target()])
	_player.ai_interact()
	_t0 = _elapsed
	_phase = "decoy"


func _decoy(_d: float) -> void:
	if _elapsed - _t0 < 0.5:
		return
	_ok("a searched decoy reveals NO keycard", _scene.get_node_or_null("ArchiveKeycard") == null)
	_ok("and it goes inert (E does nothing more)", not bool(_decoy_lot.call("can_interact")))
	# Now the key lot.
	_aim_lot(_key_lot)
	_ok("the interact ray finds the key lot",
		_player.ai_interact_target() == _key_lot,
		"ray saw %s" % [_player.ai_interact_target()])
	_player.ai_interact()
	_t0 = _elapsed
	_phase = "key"


func _key(_d: float) -> void:
	if _elapsed - _t0 < 0.5:
		return
	var card := _scene.get_node_or_null("ArchiveKeycard")
	_ok("searching the key lot reveals a takeable keycard", card != null)
	if card == null:
		_phase = "done"
		return
	var cp: Vector3 = (card as Node3D).global_position
	_stand_in_aisle_for(cp.x, cp.z, cp)
	_ok("the interact ray finds the keycard, not the inert lot",
		_player.ai_interact_target() == card,
		"ray saw %s" % [_player.ai_interact_target()])
	_player.ai_interact()
	_t0 = _elapsed
	_phase = "take"


func _take(_d: float) -> void:
	if _elapsed - _t0 < 0.5:
		return
	_ok("the keycard is taken (removed from the world)",
		_scene.get_node_or_null("ArchiveKeycard") == null)
	# Approach the sealed gate at z=44 and open it.
	_aim_from(Vector3(0, 1.2, 44.0), 1.4, 8.0)
	_ok("the gate is still shut before we press E", bool(_gate.call("can_interact")))
	_player.ai_look_at(Vector3(0, 1.2, 44.0))
	_player.ai_interact()
	_t0 = _elapsed
	_phase = "gate"


func _gate_phase(_d: float) -> void:
	if _elapsed - _t0 < 1.2:
		return
	_ok("the transit gate opened with the keycard in hand", not bool(_gate.call("can_interact")))
	_phase = "done"
