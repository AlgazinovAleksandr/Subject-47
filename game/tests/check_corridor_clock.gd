extends SceneTree

# THE CORRIDOR'S GRANDFATHER CLOCK IS A CASE THAT TICKS, AND IT STILL CURSES AT 1.0.
#
#   Godot --headless --path game --script res://tests/check_corridor_clock.gd
#
# 2026-09-10: the flat `clock.png` wall panel at d = 48 became `grandfather_clock.gd`, built
# from parts. This guard pins what the rebuild must keep and what it must not quietly lose:
#   1. it stands at d ~48 on the +X wall, on the floor, its back seated near the plaster;
#   2. it is PARTS — a dozen meshes, a glazed door, a dial on a QuadMesh carrying the drawn
#      face (never a BoxMesh face — Issue 24), and a pendulum whose pivot actually MOVES;
#   3. the gaze chain is intact: ScaryObject -> body -> collider, and the shipping gaze ray
#      from the centreline resolves to it at intensity 1.0 (⚠️ DELIBERATE — the user kept it
#      after seeing it kill them at 14 s; asserted so it cannot drift without a decision);
#   4. the hall beside it is still walkable (>= 2.5 m of 3.0), measured with rays and a point
#      query, never intersect_shape (Issue 40);
#   5. no quad in the level carries the retired panel art, and the chime event still exists.

const SCENE := "res://scenes/corridor.tscn"
const CLOCK_D := 48.0

var _fails := 0
var _checks := 0
var _t := 0.0
var _stage := 0
var _level: Node = null
var _player: CharacterBody3D = null
var _clock: Node = null
var _pivot_z0 := INF
var _pivot_samples: Array = []


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print("  %s  %s%s" % ["OK  " if cond else "FAIL", label, ("   " + detail) if detail != "" else ""])
	if not cond:
		_fails += 1


func _initialize() -> void:
	change_scene_to_file(SCENE)


func _find_all(n: Node, pred: Callable, out: Array) -> void:
	if pred.call(n):
		out.append(n)
	for c in n.get_children():
		_find_all(c, pred, out)


func _process(delta: float) -> bool:
	_t += delta
	if _t > 30.0:
		print("TIMEOUT")
		return _finish()
	if current_scene == null or _t < 1.5:
		return false
	match _stage:
		0:
			_level = current_scene
			_player = _level.get_node_or_null("Player") as CharacterBody3D
			_clock = _level.get_node_or_null("GrandfatherClock")
			_ok("the clock exists as a GrandfatherClock node", _clock != null)
			if _clock == null:
				return _finish()
			var body: StaticBody3D = _clock.call("body")
			_ok("...with a body carrying its world transform", body != null)
			var pt: Dictionary = _level.call("_path_point", CLOCK_D)
			var pos: Vector3 = body.global_position
			var along: float = (pos - (pt["pos"] as Vector3)).dot(pt["dir"])
			var across: float = (pos - (pt["pos"] as Vector3)).dot(pt["side"])
			_ok("it stands at d ~48 on the +X wall", absf(along) < 0.3 and across > 1.0,
				"along %.2f, across %.2f (wall face at 1.50)" % [along, across])
			_ok("...on the floor", absf(pos.y) < 0.02, "y %.3f" % pos.y)
			var depth := float(_clock.get_script().get_script_constant_map().get("DEPTH", 0.0))
			var back_gap: float = 1.5 - (across + depth / 2.0)
			_ok("...its back seated near the plaster (0.02-0.06 m)", back_gap >= 0.02 and back_gap <= 0.06,
				"gap %.3f" % back_gap)
			# Parts.
			var meshes: Array = []
			_find_all(body, func(n: Node) -> bool: return n is MeshInstance3D, meshes)
			_ok("it is built from parts (>= 12 meshes)", meshes.size() >= 12, "%d" % meshes.size())
			var dial: MeshInstance3D = _clock.call("dial")
			_ok("the dial is a QuadMesh (art never on a BoxMesh face)", dial != null and dial.mesh is QuadMesh)
			var dmat := dial.material_override as StandardMaterial3D if dial else null
			_ok("...carrying the drawn face", dmat != null and dmat.albedo_texture != null
				and dmat.albedo_texture.resource_path.get_file() == "clock_face.png")
			if dial and dial.mesh is QuadMesh and dmat and dmat.albedo_texture:
				var q := dial.mesh as QuadMesh
				var ta := float(dmat.albedo_texture.get_width()) / float(dmat.albedo_texture.get_height())
				_ok("...at the art's own aspect", absf(q.size.x / q.size.y - ta) < 0.05,
					"quad %.3f vs texture %.3f" % [q.size.x / q.size.y, ta])
			var glass: Node = body.get_node_or_null("DoorGlass")
			_ok("there is a glazed door to see the pendulum through", glass != null)
			var woody := 0
			for m in meshes:
				var mm := (m as MeshInstance3D).material_override as StandardMaterial3D
				if mm and mm.albedo_texture and mm.albedo_texture.resource_path.get_file() == "clock_walnut.png":
					woody += 1
			_ok("the case wears the walnut texture, not a flat tint", woody >= 8, "%d walnut parts" % woody)
			# Gaze chain.
			var scary: Node = body.get_parent()
			_ok("the body's parent is the ScaryObject (the gaze chain walks UP)",
				scary != null and scary.get_script() != null
				and String(scary.get_script().resource_path).ends_with("scary_object.gd"))
			_ok("⚠️ DELIBERATE — its gaze intensity is 1.0 (the user kept it, 2026-09-10)",
				scary != null and is_equal_approx(float(scary.get("scare_intensity")), 1.0),
				"%.2f" % float(scary.get("scare_intensity")) if scary else "no ScaryObject")
			# The shipping gaze ray from the centreline.
			_player.global_position = Vector3(pos.x - across, 0.1, pos.z - 0.6)
			_player.ai_active = true
			_player.ai_look_at(pos + Vector3(0, 1.4, 0))
			_stage = 1
			_t = 0.0
			return false
		1:
			if _t < 0.4:
				return false
			var target: Node = _player.ai_interact_target()
			var body: StaticBody3D = _clock.call("body")
			var found: Node = _player.call("_find_scary_object", body)
			_ok("the shipping gaze ray from the centreline resolves the clock's ScaryObject",
				found != null and is_equal_approx(float(found.get("scare_intensity")), 1.0),
				"target %s" % [target])
			# Tick + pendulum sampling.
			var tick := body.get_node_or_null("ClockTick") as AudioStreamPlayer3D
			_ok("it ticks (a positional loop at the case)", tick != null and tick.playing
				and tick.stream != null and tick.stream.resource_path.get_file().get_basename() == "clock_tick")
			_ok("...quietly — room tone, not a cue", tick != null and tick.volume_db <= -10.0 and tick.max_db <= 0.0,
				"%.1f dB, max %.1f" % [tick.volume_db if tick else 0.0, tick.max_db if tick else 0.0])
			var piv: Node3D = _clock.call("pendulum")
			_pivot_z0 = piv.rotation.z if piv else INF
			_pivot_samples.clear()
			_stage = 2
			_t = 0.0
			return false
		2:
			var piv: Node3D = _clock.call("pendulum")
			if piv:
				_pivot_samples.append(piv.rotation.z)
			# ⚠️ Frames AND time: a headless loop's frame length is not a clock (one frame here
			# measured over a second), so "1.2 s" alone can be a single sample.
			if _t < 1.2 or _pivot_samples.size() < 6:
				return false
			var lo: float = _pivot_z0
			var hi: float = _pivot_z0
			for s in _pivot_samples:
				lo = minf(lo, s)
				hi = maxf(hi, s)
			_ok("the pendulum SWINGS — its pivot moved over 1.2 s", _pivot_samples.size() >= 6 and hi - lo > deg_to_rad(4.0),
				"%.1f deg of travel over %d samples" % [rad_to_deg(hi - lo), _pivot_samples.size()])
			_ok("...and stays within ±8 deg", absf(lo) <= deg_to_rad(8.0) and absf(hi) <= deg_to_rad(8.0),
				"%.1f..%.1f deg" % [rad_to_deg(lo), rad_to_deg(hi)])
			# Walkable hall beside it.
			var body: StaticBody3D = _clock.call("body")
			var pt: Dictionary = _level.call("_path_point", CLOCK_D)
			var space := _player.get_world_3d().direct_space_state
			var free := 0.0
			var x0: Vector3 = (pt["pos"] as Vector3) - (pt["side"] as Vector3) * 1.5 + Vector3(0, 1.0, 0)
			var q := PhysicsRayQueryParameters3D.create(x0 + (pt["side"] as Vector3) * 0.01, x0 + (pt["side"] as Vector3) * 3.2)
			q.exclude = [_player.get_rid()]
			q.collision_mask = 1
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				free = x0.distance_to(hit["position"])
			_ok("the hall beside the clock keeps >= 2.5 m of its 3.0 m", free >= 2.5,
				"%.2f m free before the first collider (%s)" % [free, hit.get("collider", null)])
			var pq := PhysicsPointQueryParameters3D.new()
			pq.position = body.global_position + Vector3(0, 1.0, 0)
			pq.collision_mask = 1
			_ok("...and the case itself is SOLID (a point inside it is inside a collider)",
				not space.intersect_point(pq).is_empty())
			# The retired art and the chime.
			var stale: Array = []
			_find_all(_level, Callable(self, "_is_stale_clock_surface"), stale)
			_ok("no surface in the level carries the retired clock.png panel", stale.is_empty(),
				"%d found" % stale.size())
			var chimes: Array = []
			_find_all(_level, Callable(self, "_is_chime_event"), chimes)
			_ok("the chime event still stands at d 46", chimes.size() >= 1, "%d event volumes" % chimes.size())
			return _finish()
	return false


func _is_stale_clock_surface(n: Node) -> bool:
	if not (n is MeshInstance3D):
		return false
	var mi := n as MeshInstance3D
	var mat: Material = mi.material_override
	if mat == null and mi.mesh:
		mat = mi.get_surface_override_material(0)
	if mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_texture:
		return (mat as StandardMaterial3D).albedo_texture.resource_path.get_file() == "clock.png"
	return false


func _is_chime_event(n: Node) -> bool:
	if not (n is Area3D) or not n.has_signal("fired"):
		return false
	var p: Vector3 = (n as Node3D).global_position
	return absf(p.z - 46.0) < 0.6 and absf(p.x) < 0.5


func _finish() -> bool:
	print("%d checks, %d failed" % [_checks, _fails])
	print("CORRIDOR-CLOCK PASS" if _fails == 0 else "CORRIDOR-CLOCK FAIL")
	quit(1 if _fails > 0 else 0)
	return true
