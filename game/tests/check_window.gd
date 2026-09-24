extends SceneTree

# THE HOUSE'S LIVING-ROOM WINDOW EXISTS, FACES INTO THE ROOM, AND IS A REAL OPENING.
#
#   Godot --headless --path game --script res://tests/check_window.gd
#
# ⭐ MOVED 2026-09-24 (the Porch pass). The window used to be a painted `forest.png` quad behind
# glass on the living room's NORTH wall (-5, 1.6, 8.75), which backed onto the Bedroom 0.5 m away.
# It is now a floor-length opening in the WEST wall (x = -8.5, centred z = 6) — `house_window.gd`
# — with a real porch and yard behind it, and it bursts after the forest scare.
#
# ⚠️ IT ASSERTED NOTHING UNTIL 2026-08-17 (workstream H2): it printed transforms and exited 0
# without ever calling `quit()` with a verdict. It asserts, with physics queries:
#   * the window is built at all (sample size first), and its glass faces INTO the room (+X);
#   * the opening is REAL: a ray from inside at chest height stops on the PANE's collider, not on
#     a wall — and a ray at 2.6 m stops on the lintel (the opening is 2.3 m, not full height);
#   * after `break_pane()` the same chest-height ray leaves the house and reaches the yard;
#   * CONTROL: one glass quad turned round is rejected by the facing test.

const CENTRE := Vector3(-8.5, 1.2, 6.0)
const RADIUS := 1.6
const MIN_GLASS := 2

var _t := 0.0
var _checks := 0
var _fails: Array[String] = []
var _stage := "measure"
var _control: MeshInstance3D = null


func _initialize() -> void:
	change_scene_to_file("res://scenes/level_2_1.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var space := current_scene.get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var p := current_scene.get_node_or_null("Player") as CollisionObject3D
	if p:
		q.exclude = [p.get_rid()]
	return space.intersect_ray(q)


func _process(delta: float) -> bool:
	_t += delta
	if _stage == "measure":
		if _t < 1.4:
			return false
		_measure()
		_stage = "broken"
		_t = 0.0
		return false
	if _stage == "broken":
		if _t < 0.3:
			return false
		var hit := _ray(Vector3(-7.4, 1.2, 6.0), Vector3(-30.0, 1.2, 6.0))
		var hx: float = (hit["position"] as Vector3).x if not hit.is_empty() else -99.0
		_ok("after the burst the same ray leaves the house and reaches the yard", hx < -12.0,
			"first hit at x = %.2f (%s)" % [hx, str(hit.get("collider", "nothing"))])
		_control_check()
		print("")
		print("%d checks, %d failed" % [_checks, _fails.size()])
		if _fails.is_empty():
			print("WINDOW PASS")
			quit(0)
		else:
			for f in _fails:
				print("  FAIL: " + f)
			print("WINDOW FAIL")
			quit(1)
		return true
	return false


func _all(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _measure() -> void:
	print("--- the House living-room window (west wall) ---")
	var win := current_scene.get_node_or_null("HouseWindow") as Node3D
	_ok("the window node is built", win != null)
	if win == null:
		return
	var glass: Array = []
	for n in _all(win, []):
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is QuadMesh \
				and (n as MeshInstance3D).global_position.distance_to(CENTRE) < RADIUS:
			glass.append(n)
	# ⚠️ Sample size first: "0 window parts checked ... PASS" is the failure this file spent
	# its whole life in.
	_ok("the glass is built", glass.size() >= MIN_GLASS, "%d glass quad(s)" % glass.size())
	var into := 0
	for g in glass:
		var f: Vector3 = (g as MeshInstance3D).global_transform.basis.z.normalized()
		if f.x > 0.5:
			into += 1
	_ok("the glass faces INTO the living room (+x)", into >= MIN_GLASS,
		"%d of %d quads face +x" % [into, glass.size()])
	var pane: Object = win.call("pane_body")
	_ok("the pane has a collider", pane != null)
	var hit := _ray(Vector3(-7.4, 1.2, 6.0), Vector3(-30.0, 1.2, 6.0))
	_ok("a chest-height ray from the room stops on the PANE, not on a wall",
		not hit.is_empty() and hit["collider"] == pane,
		"hit %s" % str(hit.get("collider", "nothing")))
	var high := _ray(Vector3(-7.4, 2.6, 6.0), Vector3(-30.0, 2.6, 6.0))
	var high_name := String((high["collider"] as Node).name) if not high.is_empty() else "nothing"
	_ok("…and at 2.6 m the opening is closed by the lintel (the window is 2.3 m tall)",
		high_name == "WindowLintel", "hit %s" % high_name)
	# ⚠️ THE CONTROL, derived from the scene: turn one glass quad around and require the same
	# facing test to reject it. Recorded NOW, because the burst frees the sash the glass is in.
	if not glass.is_empty():
		_control = glass[0]
		_control.rotate_y(PI)
		_control_facing_x = _control.global_transform.basis.z.normalized().x
	win.call("break_pane", false)
	_ok("break_pane() reports the window broken", bool(win.call("is_broken")))


var _control_facing_x := INF


func _control_check() -> void:
	_ok("control: a glass quad existed to turn around", _control_facing_x != INF)
	if _control_facing_x != INF:
		_ok("CONTROL: a glass quad turned to face the yard is REJECTED", _control_facing_x <= 0.5,
			"facing x = %.2f after a 180 turn" % _control_facing_x)
