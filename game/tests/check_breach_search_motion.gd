extends SceneTree

# NEVER MOTIONLESS BEFORE A TELEPORT (2026-09-24, Breach pass 5). The user: "now it is just standing in
# one place not moving", then: "Change nothing about this, the only thing I wanted is to avoid the
# situation when the object is not moving at all before teleporting."
#
#   Godot --headless --path game --script res://tests/check_breach_search_motion.gd
#
# Object 12 runs its OWN state machine throughout; the test only stages it and watches its position every
# physics frame. A TELEPORT is a jump of > 1.2 m in one frame. A STILL window is a stretch in which it has
# moved < 5 cm in total.
#   A. a HIDDEN player's roam (the player in a Records cabinet): over ~31 s, spanning at least two
#      12 s relocations — no still window of >= 1.5 s anywhere, and in particular before a teleport;
#   B. the post-hide loss (the player out of sight, not hidden): it walks to the last-known spot, keeps
#      moving through SEARCH_TIME, and is relocated near the player — no still window >= 1.5 s before it;
#   C. THE MATRON'S FLAGS (relocate_when_lost false, forget_hidden_player false) on the same creature:
#      today's search — it arrives and stands turning on the spot (a still window >= 5 s), so the change
#      is gated and the Nightmare is untouched.
const SCENE := "res://scenes/level_6_breach.tscn"
const TELEPORT_STEP := 1.2
const STILL_EPS := 0.05
var _level: Node
var _player: CharacterBody3D
var _creature: Node
var _fails := 0
var _checks := 0
var _started := 0


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _started > 300000:
		print("FAIL search-motion test timed out")
		quit(1)
	return false


func _ok(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", label])


func _stage() -> void:
	change_scene_to_file(SCENE)
	await create_timer(1.6).timeout
	_level = current_scene
	preload("res://tests/lib/breach_hunt_fixture.gd").enter(_level)
	_player = _level.get_node("Player")
	_player.set("ai_active", true)
	_creature = _level.get("_creature")
	_creature.call("set_present", true)


# Watch for `seconds`: returns {teleports, longest_still, still_before_teleport (the longest still window
# that ended at a teleport), samples, travelled}.
func _watch(seconds: float, stop_after_teleports: int = 99) -> Dictionary:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var prev: Vector3 = _creature.call("get_creature_position")
	var anchor := prev
	var still_t := 0.0
	var out := {"teleports": 0, "longest_still": 0.0, "still_before_teleport": 0.0, "samples": 0, "travelled": 0.0}
	var e := 0.0
	while e < seconds:
		await physics_frame
		e += dt
		if _level.get("_kill_sequence") != null:
			break
		var p: Vector3 = _creature.call("get_creature_position")
		var step := Vector2(p.x - prev.x, p.z - prev.z).length()
		out["samples"] += 1
		if step > TELEPORT_STEP:
			out["teleports"] += 1
			out["still_before_teleport"] = maxf(out["still_before_teleport"], still_t)
			anchor = p
			still_t = 0.0
			prev = p
			if out["teleports"] >= stop_after_teleports:
				break
			continue
		out["travelled"] += step
		if Vector2(p.x - anchor.x, p.z - anchor.z).length() < STILL_EPS:
			still_t += dt
			out["longest_still"] = maxf(out["longest_still"], still_t)
		else:
			anchor = p
			still_t = 0.0
		prev = p
	return out


func _run() -> void:
	# ---- A. a hidden player's roam
	await _stage()
	var spots: Array = _level.find_children("*", "HidingSpot", true, false)
	var records: Node = null
	for sp in spots:
		if String(sp.name).contains("Records"):
			records = sp
	if records == null and not spots.is_empty():
		records = spots[0]
	_player.global_position = (records as Node3D).global_position + Vector3(0, 0.1, 0)
	_player.call("enter_hiding", records)
	_creature.call("place_body", Vector3(0.0, 0.0, 30.0), Vector3(0.0, 0.0, 20.0))
	_creature.call("activate")
	await create_timer(0.2).timeout
	var hidden: bool = _player.call("is_hidden")
	var a: Dictionary = await _watch(31.0)
	print("  A (hidden roam): %s" % str(a))
	_ok("A: the player is hidden and the creature roams on its own (%.1f m walked, %d samples)" % [a["travelled"], a["samples"]],
		hidden and a["samples"] > 1500 and a["travelled"] > 20.0)
	_ok("A: at least two relocations in 31 s (%d teleports)" % a["teleports"], a["teleports"] >= 2)
	_ok("A: it is NEVER motionless for 1.5 s (longest still %.2f s; before a teleport %.2f s)" % [a["longest_still"], a["still_before_teleport"]],
		a["longest_still"] < 1.5)
	# ---- B. the post-hide loss: out of sight, not hidden; SEARCH to the last-known spot, then relocation
	await _stage()
	_player.global_position = Vector3(0.0, 0.1, 22.0)           # the Atrium: rooms 10–14 m off exist, 22 m from it
	_player.rotation.y = 0.0
	_creature.call("place_body", Vector3(-7.0, 0.0, 44.0), Vector3(-7.0, 0.0, 40.0))
	_creature.call("activate")
	await create_timer(0.1).timeout
	_creature.set("_last_seen_pos", Vector3(-7.0, 0.0, 41.0))
	_creature.set("_search_t", 0.0)
	_creature.call("_enter", 3)                                  # SEARCH (PATROL/INVESTIGATE/CHASE/SEARCH/…)
	var b: Dictionary = await _watch(16.0, 1)
	print("  B (post-hide loss): %s" % str(b))
	_ok("B: the search gives up and relocates it near the player (%d teleport)" % b["teleports"], b["teleports"] >= 1)
	_ok("B: it kept walking right up to the teleport (longest still %.2f s; before it %.2f s)" % [b["longest_still"], b["still_before_teleport"]],
		b["longest_still"] < 1.5 and b["still_before_teleport"] < 1.5)
	# ---- C. the Matron's flags: today's search is untouched
	await _stage()
	_creature.set("forget_hidden_player", false)
	_creature.set("relocate_when_lost", false)
	_player.global_position = Vector3(0.0, 0.1, -2.0)
	_creature.call("place_body", Vector3(-7.0, 0.0, 44.0), Vector3(-7.0, 0.0, 40.0))
	_creature.call("activate")
	await create_timer(0.1).timeout
	_creature.set("_last_seen_pos", Vector3(-7.0, 0.0, 41.0))
	_creature.set("_search_t", 0.0)
	_creature.call("_enter", 3)
	var c: Dictionary = await _watch(11.0)
	print("  C (Matron flags): %s" % str(c))
	_ok("C: with the Matron's flags it still arrives and stands scanning (longest still %.2f s >= 5 s), as before" % c["longest_still"],
		c["longest_still"] >= 5.0 and c["teleports"] == 0)
	print("BREACH SEARCH MOTION: %d checks, %d failed" % [_checks, _fails])
	current_scene.queue_free()
	await process_frame
	quit(1 if _fails else 0)
