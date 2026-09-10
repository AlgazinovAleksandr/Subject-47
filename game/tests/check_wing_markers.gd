extends SceneTree

# THE DARK WING'S DOORWAYS ARE MARKED — AND ONLY THE WING'S, AND ONLY UP CLOSE.
#
#   Godot --headless --path game --script res://tests/check_wing_markers.gd
#
# 2026-09-10 (the user's replay): *"Currently it is impossible to find [the last breaker] if you
# do not know the path already. Figure out the way to make it easier but not too easy."* The
# answer chosen: photoluminescent strips on every wing doorway, faded by distance, so the
# topology is readable junction by junction while the rooms stay black and the hum and the
# meter still own the ANSWER. This guard pins the four properties that keep it "not too easy":
#   1. every wing doorway is marked, on both faces, from the level's own tables;
#   2. NO doorway outside the wing is marked (a marked Reception is a lit map);
#   3. a strip is a mark, not a lamp: dim ceiling, dark albedo, no collider, seated on its wall;
#   4. it FADES: full inside MARK_NEAR, nothing beyond MARK_FAR — measured by moving the player.
# ⚠️ The doorway set is DERIVED here from ROOMS/DOORS/WING_ROOMS, never read from the level's
# own `_wing_doorways()`, or the two would agree by construction.

const SCENE := "res://scenes/level_1.tscn"
const NEAR_PROBE := 3.0
const FAR_PROBE := 26.0
const MAX_EMISSION := 0.3

var _fails := 0
var _checks := 0
var _t := 0.0
var _stage := 0
var _level: Node = null
var _player: CharacterBody3D = null
var _markers: Array = []
var _probe: MeshInstance3D = null
var _near_e := -1.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print("  %s  %s%s" % ["OK  " if cond else "FAIL", label, ("   " + detail) if detail != "" else ""])
	if not cond:
		_fails += 1


func _initialize() -> void:
	change_scene_to_file(SCENE)


func _consts() -> Dictionary:
	return (_level.get_script() as GDScript).get_script_constant_map()


# The wing's doorways, derived: a doorway whose centre lies on a wing room's boundary.
func _split_doorways() -> Dictionary:
	var c := _consts()
	var wing: Array = []
	var other: Array = []
	for d in (c["DOORS"] as Array):
		var p: Vector2 = d["pos"]
		var in_wing := false
		for r in (c["ROOMS"] as Array):
			if not (c["WING_ROOMS"] as Array).has(String(r["name"])):
				continue
			var rc: Vector2 = r["pos"]
			var half: Vector2 = (r["size"] as Vector2) * 0.5
			if absf(p.x - rc.x) <= half.x + 0.05 and absf(p.y - rc.y) <= half.y + 0.05:
				in_wing = true
				break
		(wing if in_wing else other).append(d)
	return {"wing": wing, "other": other}


func _near(p: Vector2, radius: float) -> int:
	var n := 0
	for m in _markers:
		var g: Vector3 = (m as Node3D).global_position
		if Vector2(g.x - p.x, g.z - p.y).length() <= radius:
			n += 1
	return n


func _wall_gap(mi: MeshInstance3D) -> Dictionary:
	# The strip's thin axis is its local z; one direction meets the wall face, the other the room.
	var space := mi.get_world_3d().direct_space_state
	var out := {"back": INF, "front": INF}
	for sgn in [-1.0, 1.0]:
		var dir: Vector3 = mi.global_transform.basis.z * sgn
		var from: Vector3 = mi.global_position
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 0.8)
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		if not (hit["collider"] is CSGShape3D):
			continue
		var d: float = from.distance_to(hit["position"]) - float((mi.mesh as BoxMesh).size.z) / 2.0
		out["back"] = minf(out["back"], d)
	return out


func _process(delta: float) -> bool:
	_t += delta
	if _t > 40.0:
		print("TIMEOUT at stage %d" % _stage)
		return _finish()
	if current_scene == null or _t < 1.5:
		return false
	match _stage:
		0:
			_level = current_scene
			_player = _level.get_node_or_null("Player") as CharacterBody3D
			_ok("player found", _player != null)
			_markers = _level.call("wing_marker_nodes")
			var split := _split_doorways()
			var wing: Array = split["wing"]
			_ok("the wing has ten doorways (derived from ROOMS/DOORS/WING_ROOMS)", wing.size() == 10,
				"%d" % wing.size())
			_ok("four strips per wing doorway (two faces, two jambs)", _markers.size() == wing.size() * 4,
				"%d strips for %d doorways" % [_markers.size(), wing.size()])
			var marked := 0
			for d in wing:
				if _near(d["pos"], 1.3) >= 4:
					marked += 1
			_ok("EVERY wing doorway carries its four strips", marked == wing.size(),
				"%d of %d" % [marked, wing.size()])
			var leaked := 0
			for d in (split["other"] as Array):
				if _near(d["pos"], 1.3) > 0:
					leaked += 1
					print("     marked non-wing doorway at %s" % str(d["pos"]))
			_ok("CONTROL — no doorway OUTSIDE the wing is marked (%d checked)" % (split["other"] as Array).size(),
				leaked == 0 and (split["other"] as Array).size() >= 8)

			# A mark, not a lamp.
			var cap := float(_consts().get("MARK_EMISSION", 9.0))
			_ok("the emission ceiling is a MARK's, not a lamp's", cap > 0.0 and cap <= MAX_EMISSION,
				"MARK_EMISSION %.2f (max %.2f)" % [cap, MAX_EMISSION])
			var colliders := 0
			var pale := 0
			var seated := 0
			var floating := 0
			for m in _markers:
				var mi := m as MeshInstance3D
				for ch in mi.get_children():
					if ch is CollisionShape3D or ch is CollisionObject3D:
						colliders += 1
				var mat := mi.material_override as StandardMaterial3D
				if mat and mat.albedo_color.get_luminance() > 0.15:
					pale += 1
				var gap := _wall_gap(mi)
				if gap["back"] >= 0.015 and gap["back"] <= 0.06:
					seated += 1
				else:
					floating += 1
					print("     strip %s: wall gap %.3f" % [mi.name, gap["back"]])
			_ok("no strip carries a collider (a collider on a doorway seals a room)", colliders == 0)
			_ok("every strip's albedo is dark — the glow is the emission, not the paint", pale == 0,
				"%d pale" % pale)
			_ok("every strip is SEATED on a wall face (0.015–0.06 m), none floats", floating == 0,
				"%d seated, %d not" % [seated, floating])

			# The fade: stand near one, then far from it.
			_probe = _markers[0] as MeshInstance3D
			var g: Vector3 = _probe.global_position
			var away: Vector3 = (_probe.global_transform.basis.z * -1.0)
			_player.global_position = Vector3(g.x, 0.1, g.z) + away * 0.0 + Vector3(0, 0, 0)
			# Stand NEAR_PROBE away along the room side of the strip, whichever side is open.
			var space := _player.get_world_3d().direct_space_state
			var best := Vector3(g.x, 0.1, g.z)
			for sgn in [-1.0, 1.0]:
				var cand: Vector3 = Vector3(g.x, 0.1, g.z) + _probe.global_transform.basis.z * sgn * NEAR_PROBE
				var q := PhysicsRayQueryParameters3D.create(Vector3(g.x, 1.0, g.z), cand + Vector3(0, 1.0, 0))
				q.collision_mask = 1
				if space.intersect_ray(q).is_empty():
					best = cand
					break
			_player.global_position = best
			_player.velocity = Vector3.ZERO
			_stage = 1
			_t = 0.0
			return false
		1:
			if _t < 0.6:
				return false
			var mat := _probe.material_override as StandardMaterial3D
			_near_e = mat.emission_energy_multiplier
			var d: float = _player.global_position.distance_to(_probe.global_position)
			_ok("standing %.1f m from a strip, it glows" % d, _near_e > 0.05 and _near_e <= MAX_EMISSION,
				"emission %.3f" % _near_e)
			# Now far away: the Reception, 20+ m from any wing strip.
			_player.global_position = Vector3(0.0, 0.1, -1.5)
			_player.velocity = Vector3.ZERO
			_stage = 2
			_t = 0.0
			return false
		2:
			if _t < 0.6:
				return false
			var mat := _probe.material_override as StandardMaterial3D
			var far_e := mat.emission_energy_multiplier
			var d: float = _player.global_position.distance_to(_probe.global_position)
			_ok("from %.0f m away the same strip has FADED OUT — no lit map of the wing" % d,
				far_e < 0.005, "emission %.4f (was %.3f up close)" % [far_e, _near_e])
			_ok("CONTROL — the fade measured a real change, not two zeros", _near_e - far_e > 0.04,
				"%.3f -> %.4f" % [_near_e, far_e])
			return _finish()
	return false


func _finish() -> bool:
	print("%d checks, %d failed" % [_checks, _fails])
	print("WING-MARKERS PASS" if _fails == 0 else "WING-MARKERS FAIL")
	quit(1 if _fails > 0 else 0)
	return true
