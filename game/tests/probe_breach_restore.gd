extends SceneTree

# ADVERSARIAL PROBE — "win, then re-enter the level via `_restore_progress()`".
#
#   Godot --headless --path game --script res://tests/probe_breach_restore.gd
#
# `_restore_progress()` is the LAST line of `_ready()` and calls `lure_into_trap()` on the freshly
# spawned creature, which sets `_active = false` AND `set_process(false)`. But `_process()` on the
# LEVEL keeps running `_tick_familiarization()`, which is gated only on `_creature_awake` — so on
# a level that has already been won it counts down and calls `activate()`, printing "IT IS AWAKE."
# over a corpse. Measured here, plus where that corpse actually is.

const SCENE := "res://scenes/level_6_breach.tscn"

var _stage := 0
var _t := 0.0
var _level: Node = null
var _creature: Node = null


func _initialize() -> void:
	Engine.time_scale = 20.0
	seed(7)
	pass   # the scene change happens in _process, after the autoloads exist — see _seed()


func _is_script(n: Node, base: String) -> bool:
	var s = n.get_script()
	return s != null and String(s.resource_path).ends_with(base)


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _grab() -> void:
	_level = current_scene
	var nodes: Array = []
	_all(current_scene, nodes)
	for x in nodes:
		if _is_script(x, "creature_object12.gd"):
			_creature = x


# ⚠️ `GameState` cannot be NAMED at parse time in a `--script` SceneTree (autoloads are not yet
# registered when this file is compiled) and is not guaranteed to be in `root` during
# `_initialize()` either. Seed it on the first frame, then load the scene.
func _seed() -> bool:
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		return false
	gs.set("entered_from_ahead", true)
	var lp: Dictionary = gs.get("level_progress")
	lp[6] = {"creature_defeated": true}
	change_scene_to_file(SCENE)
	return true


var _seeded := false

func _process(d: float) -> bool:
	if not _seeded:
		_seeded = _seed()
		if not _seeded:
			return false
		return false
	_t += d
	if _stage == 0:
		if _t < 1.0:
			return false
		_grab()
		if _creature == null:
			print("FATAL")
			return true
		print("=== probe_breach_restore (returning to a level already won) ===")
		print("  creature_defeated restored = %s" % str(_level._creature_defeated))
		print("  creature: active=%s processing=%s pos=%s visual.rot.x=%.1f deg" % [
			str(_creature._active), str(_creature.is_processing()),
			str(_creature.get_creature_position()),
			rad_to_deg(_creature._visual_root.rotation.x) if _creature._visual_root else 0.0])
		print("  (the purge happened in the Incinerator, z 55..62 — where is the body?)")
		print("  exit door locked = %s" % str(_level._exit_door.extra_lock if _level._exit_door else "?"))
		print("  familiarization: awake=%s t=%.1f of %.1f" % [
			str(_level._creature_awake), _level._familiarization_t, _level._familiarization_time])
		_stage = 1
		return false
	if _stage == 1:
		if _level._creature_awake:
			print("\n  *** _tick_familiarization FIRED ON A DEFEATED CREATURE at t=%.1f ***" % _t)
			print("      it printed \"IT IS AWAKE.\" and called activate() -> active=%s processing=%s" % [
				str(_creature._active), str(_creature.is_processing())])
			print("      (harmless only because lure_into_trap() also called set_process(false))")
			_stage = 2
			return false
		if _t > 60.0:
			print("\n  familiarization never fired in 60 s of scaled time — no defect here")
			return true
		return false
	if _stage == 2 and _t > 65.0:
		print("\n  after another %.0f s: creature moved? pos=%s  state=%d" % [
			65.0 - _t, str(_creature.get_creature_position()), _creature.get_state()])
		return true
	return false
