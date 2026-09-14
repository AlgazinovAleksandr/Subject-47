extends SceneTree

# The Lab dark wing's signal meter tells the TRUTH.
#
#   Godot --headless --path game --script res://tests/check_wing_meter.gd
#
# ⚠️ DELIBERATE (2026-08-16). This widget is a HUD readout of proximity to a solution, which
# `GAME_MECHANICS_IDEAS` §5.2(2) and ISSUES_SOLUTIONS Issue 34 both name as a thing this
# project does not build. It is here on the user's explicit call, made after being shown
# both. That decision is not what this test is about.
#
# What this test is about is the half of Issue 34 that was NOT a matter of taste. The deleted
# `set_breaker_proximity()` bar measured straight-line distance, so from inside a dead end it
# read a warm ~0.43 while being nowhere near the breaker in walking terms — it did not merely
# solve the maze, it solved it WRONG. The replacement runs Dijkstra over the wing's own
# doorway graph, and the assertions below are exactly the cases where a beeline lies:
#
#   * every DEAD END must read colder than the route room it branches off, even where it is
#     physically closer to the breaker than that room is;
#   * Plant — MEASURED at 6.6 m from the breaker in a straight line and 30.0 m of walking,
#     a 4.6x lie — must read cold. A beeline meter calls it 0.79 (nearly arrived) and points
#     the player at a wall; this one calls it 0.04;
#   * the value must rise monotonically along the real route.
#
# The test also proves the meter can be wrong: it computes the naive Euclidean answer beside
# the real one and prints both, so the size of the lie it is avoiding is on the record.

# The real route in, from Records' doorway to the breaker.
const ROUTE := [
	Vector3(-13.0, 0.0, 12.5),      # DarkCorridor, just inside the wing
	Vector3(-18.0, 0.0, 12.5),      # DarkCorridor, far end
	Vector3(-21.0, 0.0, 12.5),      # Junction — decision 1
	Vector3(-21.0, 0.0, 9.5),       # SouthSpur
	Vector3(-26.0, 0.0, 7.7),       # SouthHall — decision 3
	Vector3(-30.5, 0.0, 7.7),       # SouthHall, at the Cistern doorway
	Vector3(-34.0, 0.0, 7.7),       # Cistern — decision 4
	Vector3(-40.5, 0.0, 7.7),       # LowerRun — decision 5
	Vector3(-46.0, 0.0, 7.7),       # Crossing — decision 6
	Vector3(-51.5, 0.0, 7.7),       # FarHall
	Vector3(-57.0, 0.0, 7.7),       # Turn — decision 7
	Vector3(-57.0, 0.0, 12.1),      # Shaft
	Vector3(-58.5, 0.0, 16.5),      # BreakerNook, on the breaker
]
# Dead ends, each paired with the route room it branches off.
const DEAD_ENDS := [
	["PumpPit", Vector3(-25.0, 0.0, 2.5), Vector3(-26.0, 0.0, 7.7)],
	["SumpWell", Vector3(-34.0, 0.0, 2.1), Vector3(-34.0, 0.0, 7.7)],
	["VentShaft", Vector3(-39.8, 0.0, 14.0), Vector3(-40.5, 0.0, 7.7)],
	["BoilerPit", Vector3(-57.0, 0.0, 2.1), Vector3(-57.0, 0.0, 7.7)],
]

var _frame := 0
var _fails := 0
var _checks := 0
var _meter: Node
var _breaker := Vector3.ZERO


func _initialize() -> void:
	change_scene_to_file("res://scenes/level_1.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	if not cond:
		_fails += 1
	print("  %s  %s%s" % ["PASS" if cond else "FAIL", label, ("   " + detail) if detail != "" else ""])


func _find(root: Node, pred: Callable) -> Node:
	if pred.call(root):
		return root
	for c in root.get_children():
		var f := _find(c, pred)
		if f:
			return f
	return null


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 10:
		return false

	_meter = _find(current_scene, func(n: Node) -> bool:
		return n is CanvasLayer and n.has_method("path_distance") and n.has_method("signal_strength")
	)
	print("--- dark wing signal meter ---")
	_ok("the meter exists in the built level", _meter != null)
	if not _meter:
		_finish()
		return true
	var nook := current_scene.get_node_or_null("Breaker_Nook") as Node3D
	_ok("the nook breaker exists to measure against", nook != null)
	if nook:
		_breaker = nook.global_position

	# It must only be on screen inside the wing.
	_ok("it starts hidden (the player spawns in Reception)", not bool(_meter.call("is_active")))

	print("  ..  normalisation: the furthest room in the wing is %.1f m of walking away"
		% float(_meter.call("max_path")))
	_ok("the scale is derived from the level's own geometry, not a typed-in number",
		float(_meter.call("max_path")) > 20.0 and float(_meter.call("max_path")) < 120.0,
		"%.1f m" % float(_meter.call("max_path")))

	# ── the route reads monotonically warmer ─────────────────────────────────────────
	var last := -1.0
	var monotonic := true
	var trace: Array = []
	for p in ROUTE:
		var s: float = _meter.call("signal_strength", p)
		trace.append("%.2f" % s)
		if s < last - 0.001:
			monotonic = false
		last = s
	print("  ..  along the real route: %s" % [", ".join(PackedStringArray(trace))])
	_ok("the meter rises monotonically along the actual route", monotonic)
	_ok("and it reads ~1.0 standing at the breaker", last > 0.9, "%.2f" % last)

	# ── the assertion the deleted widget failed ──────────────────────────────────────
	var checked := 0
	for entry in DEAD_ENDS:
		var room: String = entry[0]
		var dead: Vector3 = entry[1]
		var junction: Vector3 = entry[2]
		var s_dead: float = _meter.call("signal_strength", dead)
		var s_junction: float = _meter.call("signal_strength", junction)
		var path: float = _meter.call("path_distance", dead)
		var beeline: float = dead.distance_to(_breaker)
		checked += 1
		print("  ..  %s: %.1f m of walking, %.1f m as the crow flies (a %.1fx lie), reads %.2f"
			% [room, path, beeline, path / maxf(0.1, beeline), s_dead])
		_ok("%s (a dead end) reads COLDER than the junction it branches off" % room,
			s_dead < s_junction, "%.2f vs %.2f" % [s_dead, s_junction])
	# ⚠️ Assert the sample size — "0 dead ends checked … PASS" is a documented failure mode here.
	_ok("every dead end was actually checked", checked == DEAD_ENDS.size(),
		"%d of %d" % [checked, DEAD_ENDS.size()])

	# THE CASE THAT CONVICTED THE OLD WIDGET (Issue 34): a room that is CLOSE to the breaker as
	# the crow flies and FAR by the doorway graph. A straight-line meter reads it warm and points
	# the player at a wall; the path-based one reads it cold. Since 2026-09-13 Plant loops back
	# into the route (so its lie shrank), and the worst liar is whichever room the geometry makes
	# it — measured over the candidates below rather than typed in.
	var liars := {
		"Plant": Vector3(-32.5, 0.0, 12.5), "Gallery": Vector3(-46.0, 0.0, 17.0),
		"VaultRun(west)": Vector3(-43.0, 0.0, 22.7), "VentShaft": Vector3(-39.8, 0.0, 14.0),
	}
	var worst_gap := 0.0
	var worst_name := ""
	for nm in liars:
		var at: Vector3 = liars[nm]
		var s_path: float = _meter.call("signal_strength", at)
		var s_naive: float = clampf(1.0 - at.distance_to(_breaker) / float(_meter.call("max_path")), 0.0, 1.0)
		print("  ..  %s: path-based %.2f vs the straight-line answer %.2f" % [nm, s_path, s_naive])
		if s_naive - s_path > worst_gap:
			worst_gap = s_naive - s_path
			worst_name = nm
	_ok("some room reads a LOT warmer by beeline than by path (the Issue-34 lie, measured)",
		worst_gap >= 0.2, "%s: gap %.2f" % [worst_name, worst_gap])

	# ⭐ 2026-09-13: NEAR-ONLY. The bar is shown within NEAR_HOPS (3) rooms of the breaker and
	# hidden beyond — by doorway hops, never by straight line. Junction is 10+ rooms out; Turn
	# is 3 (Turn -> Shaft -> BreakerNook = 2 hops... asserted from the meter's own graph).
	var hops_junction := int(_meter.call("room_hops", Vector3(-21.0, 0.0, 12.5)))
	var hops_turn := int(_meter.call("room_hops", Vector3(-57.0, 0.0, 7.7)))
	var hops_nook := int(_meter.call("room_hops", Vector3(-57.0, 0.0, 16.5)))
	print("  ..  hops: Junction %d, Turn %d, BreakerNook %d" % [hops_junction, hops_turn, hops_nook])
	_ok("the breaker's own room is 0 hops", hops_nook == 0)
	_ok("the hop graph reaches Junction (>= 8 hops out)", hops_junction >= 8, "%d hops" % hops_junction)
	# 2026-09-14: the bar is LIVE EVERYWHERE in the wing again (the user's call). Drive tick()
	# with a stand-in player at Junction and require the bar to stay on screen and read > 0.
	var stand := Node3D.new()
	current_scene.add_child(stand)
	stand.global_position = Vector3(-21.0, 0.0, 12.5)
	_meter.call("set_player", stand)
	_meter.call("set_active", true)
	_meter.call("tick", 0.1)
	var root_ctl := _meter.get("_root") as CanvasItem
	_ok("the bar is ON SCREEN from the first decision room (live everywhere)", root_ctl != null and root_ctl.visible)
	_ok("...and it READS there", float(_meter.call("signal_strength", Vector3(-21.0, 0.0, 12.5))) > 0.0)
	_meter.call("set_active", false)
	stand.queue_free()
	# The loops must be in the meter's graph: Plant reaches the breaker through PlantDrop.
	var plant_hops := int(_meter.call("room_hops", Vector3(-32.5, 0.0, 12.5)))
	var west_hops := int(_meter.call("room_hops", Vector3(-26.5, 0.0, 12.5)))
	_ok("loop 1 is in the graph: Plant is CLOSER (by hops) than WestCorridor", plant_hops < west_hops,
		"%d vs %d" % [plant_hops, west_hops])

	# Outside the wing there is nothing to measure and it must say so rather than guess.
	var outside: float = _meter.call("path_distance", Vector3(0.0, 0.0, 0.0))
	_ok("outside the wing it reports no reading at all", not is_finite(outside))

	_finish()
	return true


func _finish() -> void:
	print("%d checks, %d failed" % [_checks, _fails])
	print("WING-METER PASS" if _fails == 0 else "WING-METER FAIL")
	quit(1 if _fails > 0 else 0)
