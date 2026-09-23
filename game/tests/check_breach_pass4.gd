extends SceneTree

# THE BREACH APPROACH, PASS 4 (2026-09-23): the shutter face, the ceiling drop, the fused technician.
#
#   Godot --headless --path game --script res://tests/check_breach_pass4.gd
#
# Physical, through the real player (`ai_move_dir`, `ai_look_at`), with the approach's own clock and
# beat log. `check_breach_approach.gd` walks the whole route and proves the beat ORDER (with
# `ceiling_drop` in it) and the music; `check_breach_porthole.gd` takes the handle from the technician
# at his new wall through the real E ray. This file proves what those cannot see:
#
#   A. THE SHUTTER FACE — a QUIET STARE (the user's choice over a jolt), REVERSED 2026-09-24:
#      * the beat arms, but while the player looks AWAY nothing opens;
#      * the FIRST opening, when they look, shows the face: head in the niche, turned to them;
#      * every later cycle is empty, looked at or not;
#      * the puppet is the hand's contract: no collider, no ScaryObject, its own non-emissive
#        material, no shadow, its own layer, lit only by a fill culled to that layer (and the bay's
#        lamps culled FROM it), and it is freed once the shutter is down; the next cycle is empty;
#      * panic stays 0.
#   B. THE CEILING DROP — sudden, by position:
#      * it fires once, when the player crosses x -9.2 in Containment, ~2.3 m ahead of them;
#      * the hatch bursts, the body is 3D parts (no quad anywhere in it), it swings and settles;
#      * the lane stays clear to physics rays at three heights and at the player's capsule edge, all
#        through the swing, while the SAME ray at the body's line hits it (the positive control);
#      * the walk carries on to the Threshold end of Containment; walking back and forth does not
#        fire it again; panic stays 0.
#   C. THE FUSED TECHNICIAN (2026-09-24, the user's own art) — at the Plenum's far wall, ONE relief, LIFE
#      SIZE, at the wall plane, no sphere mass and no 3D limbs, a few thin tendrils lying on the wall; THE
#      WHOLE VALVE WHEEL pressed flush between his PAINTED fists (grip points checked against the art's
#      texels); lit by a caged lamp above him; the porthole door shows a bare spindle.
const SCENE := "res://scenes/level_6_breach.tscn"
var _level: Node
var _player: CharacterBody3D
var _approach: Node
var _fails := 0
var _checks := 0
var _started := 0
var _panic_seen := 0.0


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	change_scene_to_file(SCENE)
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _started > 300000:
		print("FAIL pass-4 test timed out")
		quit(1)
	return false


func _ok(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", label])


func _frame() -> void:
	await physics_frame
	_panic_seen = maxf(_panic_seen, float(_player.get("_panic")))


func _secs(t: float) -> void:
	var e := 0.0
	while e < t:
		await _frame()
		e += 1.0 / Engine.physics_ticks_per_second


func _count(beat: String) -> int:
	return Array(_approach.call("beat_names")).count(beat)


func _beat(beat: String) -> Dictionary:
	for b in _approach.get("beat_log"):
		if b["name"] == beat:
			return b
	return {}


func _find(node: Node, pred: Callable) -> Node:
	for c in node.get_children():
		if pred.call(c):
			return c
		var deep := _find(c, pred)
		if deep:
			return deep
	return null


func _all(node: Node, out: Array) -> Array:
	for c in node.get_children():
		out.append(c)
		_all(c, out)
	return out


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_ray(q)


func _under(n: Object, root: Node) -> bool:
	var x := n as Node
	while x != null:
		if x == root:
			return true
		x = x.get_parent()
	return false


func _run() -> void:
	await create_timer(1.8).timeout
	_level = current_scene
	_player = _level.get_node("Player")
	_player.set("ai_active", true)
	_approach = _level.get("_approach")
	var consts: Dictionary = _approach.get_script().get_script_constant_map()
	await _shutter(consts)
	await _drop(consts)
	_technician(consts)
	_ok("panic stayed at 0 through all of it (peak %.3f)" % _panic_seen, _panic_seen == 0.0)
	print("BREACH PASS 4: %d checks, %d failed" % [_checks, _fails])
	current_scene.queue_free()
	await process_frame
	quit(1 if _fails else 0)


# ------------------------------------------------------------------------------------ A. the face

func _look_at_niche(niche: Vector3) -> void:
	_player.call("ai_look_at", niche)


func _look_away() -> void:
	_player.call("ai_look_at", _player.global_position + Vector3(20, 1.6, 0))


# Wait (looking wherever `look` says) until the shutter's next cycle STARTS; returns false on timeout.
func _until_next_cycle(look: Callable, limit: float = 12.0) -> bool:
	var before := int(_approach.get("_shutter_cycles"))
	var e := 0.0
	while int(_approach.get("_shutter_cycles")) == before and e < limit:
		look.call()
		await _frame()
		e += 1.0 / Engine.physics_ticks_per_second
	return int(_approach.get("_shutter_cycles")) > before


# Wait for the running cycle to end; true if the face was ever visible during it.
func _through_cycle(look: Callable) -> bool:
	var seen := false
	var e := 0.0
	while bool(_approach.get("_shutter_busy")) and e < 12.0:
		look.call()
		var f: Node3D = _approach.call("face_puppet")
		if f != null and f.visible:
			seen = true
		await _frame()
		e += 1.0 / Engine.physics_ticks_per_second
	return seen


func _shutter(consts: Dictionary) -> void:
	var niche: Vector3 = _approach.get("_niche_centre")
	var window: Vector3 = consts["SHUTTER_WINDOW"]
	var face: Node3D = _approach.call("face_puppet")
	_ok("the face puppet is built, hidden, before the shutter beat", face != null and not face.visible)
	if face == null:
		return
	# --- the puppet contract, checked on the node itself
	_ok("the face puppet carries no collider", _find(face, func(c): return c is CollisionShape3D or c is CollisionObject3D) == null)
	_ok("no ScaryObject above or below the face puppet",
		_find(face, func(c): return c is ScaryObject) == null and not (face.get_parent() is ScaryObject))
	var meshes: Array = _all(face, []).filter(func(n): return n is MeshInstance3D)
	var creature: Node = _level.get("_creature")
	var creature_mat: Material = creature.get("_material")
	var layer: int = consts["FACE_LAYER"]
	var mats_ok := not meshes.is_empty()
	for m in meshes:
		var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
		if mat == null or mat == creature_mat or mat.emission_enabled or (m as MeshInstance3D).layers != layer \
				or (m as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			mats_ok = false
	_ok("every face mesh (%d) has its own non-emissive material, no shadow, and only its own layer" % meshes.size(), mats_ok)
	# ⚠️ The camera must be able to SEE that layer. The face first shipped on render layer 20, the
	# mirror-only layer the player's camera culls: every check above passed and the render was an empty
	# niche. A state check cannot see a culled layer unless it asks the camera.
	var pcam: Camera3D = _player.get_node("Camera3D")
	_ok("the player's camera renders the face's layer (cull_mask %x, layer %x)" % [pcam.cull_mask, layer],
		(pcam.cull_mask & layer) == layer)
	var lights: Array = _all(face, []).filter(func(n): return n is Light3D)
	_ok("its only light is a fill culled to its layer (%d light(s))" % lights.size(),
		lights.size() == 1 and (lights[0] as Light3D).light_cull_mask == layer)
	var leaks := 0
	for n in _all(_approach, []):
		if n is Light3D and not _under(n, face) and (n as Node3D).global_position.distance_to(niche) < 6.0 \
				and ((n as Light3D).light_cull_mask & layer) != 0:
			leaks += 1
			print("  light %s at %s reaches the face layer" % [n.name, (n as Node3D).global_position])
	_ok("no other light within 6 m of the niche reaches the face layer (%d)" % leaks, leaks == 0)
	var roll_z: float = (_approach.get("_shutter_pivot") as Node3D).global_position.z
	var head: Vector3 = face.call("head_point")
	print("  niche %s  roll z %.2f  head %s  window %s" % [niche, roll_z, head, window])
	_ok("the head stands IN the niche, behind the roll (head z %.2f > roll z %.2f) at head height (%.2f m)" % [head.z, roll_z, head.y],
		head.z > roll_z and head.y > 1.4 and head.y < 1.95)

	# --- ⭐ REVERSED 2026-09-24 (the user): the FIRST opening shows the face, and waits for the look.
	# Stand in Observation in front of bay B's window LOOKING AWAY: the beat arms, but nothing opens.
	_player.global_position = Vector3(-60.5, 0.1, -48.0)
	_player.velocity = Vector3.ZERO
	var look := _look_at_niche.bind(niche)
	var waited_away := 0.0
	while waited_away < 3.0:
		_look_away()
		await _frame()
		waited_away += 1.0 / Engine.physics_ticks_per_second
	_ok("standing in Observation arms the shutter beat, but looking AWAY opens nothing (%d cycles in 3 s)" % int(_approach.get("_shutter_cycles")),
		_count("shutter") == 1 and int(_approach.get("_shutter_cycles")) == 0 and _count("shutter_face") == 0)
	# --- turn to look: the first opening is the face's
	var started := await _until_next_cycle(look, 3.0)
	await _frame()
	await _frame()
	var cam: Camera3D = _player.get_node("Camera3D")
	var dist := cam.global_position.distance_to(niche)
	_ok("the niche is %.1f m away and being looked at (dot %.2f)" % [dist, _approach.call("_camera_dot", niche)],
		dist <= float(consts["FACE_LOOK_DIST"]) and float(_approach.call("_camera_dot", niche)) >= float(consts["FACE_LOOK_DOT"]))
	face = _approach.call("face_puppet")
	_ok("the FIRST opening shows the face (cycle %d, face cycle %d)" % [int(_approach.get("_shutter_cycles")), int(_approach.get("_face_cycle"))],
		started and int(_approach.get("_shutter_cycles")) == 1 and _count("shutter_face") == 1 and int(_approach.get("_face_cycle")) == 1
		and face != null and face.visible)
	if face != null:
		var actor: Node3D = face.get("actor")
		var fwd := actor.global_basis.z
		var to := cam.global_position - actor.global_position
		fwd.y = 0.0
		to.y = 0.0
		_ok("it is turned to the player (facing dot %.3f)" % fwd.normalized().dot(to.normalized()),
			fwd.normalized().dot(to.normalized()) > 0.97)
	# the roll is up while it is seen, and it holds still (a stare, not a lunge)
	await _secs(3.2)
	var pivot: Node3D = _approach.get("_shutter_pivot")
	face = _approach.call("face_puppet")
	var h0: Vector3 = face.call("head_point") if face else Vector3.ZERO
	await _secs(1.0)
	var h1: Vector3 = face.call("head_point") if is_instance_valid(face) else Vector3(99, 99, 99)
	_ok("with the roll up (scale %.2f) the face holds still (moved %.3f m in 1 s)" % [pivot.scale.y, h0.distance_to(h1)],
		pivot.scale.y < 0.2 and h0.distance_to(h1) < 0.01)
	await _through_cycle(look)
	await _frame()
	_ok("the shutter rolls down over it and the puppet is FREED", _count("shutter_face_gone") == 1
		and _approach.call("face_puppet") == null and not is_instance_valid(face))
	started = await _until_next_cycle(look)
	var seen4 := await _through_cycle(look)
	_ok("the next cycle is EMPTY although it is looked at (once per run)", started and not seen4 and _count("shutter_face") == 1)
	started = await _until_next_cycle(_look_away)
	var seen5 := await _through_cycle(_look_away)
	_ok("and so is every later one (cycle %d)" % int(_approach.get("_shutter_cycles")), started and not seen5 and _count("shutter_face") == 1)


# ------------------------------------------------------------------------------------ B. the drop

func _lane_clear(victim: Node) -> Array:
	# [lane blocked by the victim?, body line hit by the victim?]
	var lane_hit := false
	for spec in [[-26.0, 0.4], [-26.0, 1.0], [-26.0, 1.6], [-25.6, 1.0], [-25.6, 0.3]]:
		var r := _ray(Vector3(-11.5, spec[1], spec[0]), Vector3(-2.5, spec[1], spec[0]))
		if not r.is_empty() and _under(r["collider"], victim):
			lane_hit = true
	var rb := _ray(Vector3(-11.5, 1.2, -24.8), Vector3(-2.5, 1.2, -24.8))
	return [lane_hit, not rb.is_empty() and _under(rb["collider"], victim)]


func _drop(consts: Dictionary) -> void:
	var rig: Node3D = _approach.call("drop_rig")
	_ok("the ceiling-drop rig exists", rig != null)
	if rig == null:
		return
	var victim: Node3D = rig.get_node("CocoonedVictim")
	var hatch: Node3D = _approach.get("_drop_hatch")
	var solid: CollisionShape3D = _approach.get("_drop_solid")
	# ⭐ 3D, not flat art (the user's "it looks very 2d now" was about the technician; this one is
	# built to never draw that note)
	var parts := _all(victim, [])
	var quads := parts.filter(func(n): return n is MeshInstance3D and (n.mesh is QuadMesh or n.mesh is PlaneMesh))
	var capsules := parts.filter(func(n): return n is MeshInstance3D and n.mesh is CapsuleMesh)
	var arm := parts.filter(func(n): return String(n.name).begins_with("HangingArm") or String(n.name) == "HangingHand")
	# only the work lamp's bulb may glow (a light fitting); the body itself never does (SCARY.md §8.8)
	var emissive := parts.filter(func(n): return (n is MeshInstance3D and n.material_override is StandardMaterial3D
		and n.material_override.emission_enabled and String(n.name) != "WorkLampBulb"))
	_ok("the body is 3D parts: %d capsules, no quad or plane (%d), one bare arm out of the cocoon (%d parts), nothing on it glows (%d)" % [capsules.size(), quads.size(), arm.size(), emissive.size()],
		capsules.size() >= 12 and quads.is_empty() and arm.size() == 3 and emissive.is_empty())
	var lamp: OmniLight3D = _approach.get("_drop_lamp")
	_ok("a work lamp hangs on the LANE side of the body and casts shadows (it models the body from the front)",
		lamp != null and _under(lamp, victim) and lamp.shadow_enabled and lamp.global_position.z < rig.global_position.z - 0.3)
	_ok("before the drop: hidden, its collider off, the hatch shut", not victim.visible and solid.disabled and is_zero_approx(hatch.rotation.z))
	var pre := _lane_clear(victim)
	_ok("before the drop not even the body's own line hits it (it is not there yet)", not pre[1])
	# walk east down the lane from Containment's west end, as the route does
	_player.global_position = Vector3(-13.5, 0.1, -26.0)
	_player.velocity = Vector3.ZERO
	await _frame()
	var dropped_at := Vector3.INF
	var lane_blocked := 0
	var body_hits := 0
	var samples := 0
	var swing_peak := 0.0
	var e := 0.0
	var target := Vector3(-1.0, 0.1, -26.0)
	while _player.global_position.x < target.x - 0.3 and e < 12.0:
		_player.call("ai_look_at", Vector3(target.x, 1.7, target.z))
		_player.set("ai_move_dir", Vector2(0, -1))
		await _frame()
		e += 1.0 / Engine.physics_ticks_per_second
		if dropped_at == Vector3.INF and _count("ceiling_drop") == 1:
			dropped_at = _player.global_position
		if dropped_at != Vector3.INF:
			var lc := _lane_clear(victim)
			samples += 1
			if lc[0]:
				lane_blocked += 1
			if lc[1]:
				body_hits += 1
			swing_peak = maxf(swing_peak, absf(rig.rotation.z) + absf(rig.rotation.y))
	_player.set("ai_move_dir", Vector2.ZERO)
	var b := _beat("ceiling_drop")
	var ahead := float(_approach.get("drop_ahead"))
	print("  drop fired with the player at %s, %.2f m ahead (%.2f m away); lane samples %d, blocked %d, body line hit %d" % [
		dropped_at, ahead, float(_approach.get("drop_distance")), samples, lane_blocked, body_hits])
	_ok("it fires by position, crossing x %.1f (player at x %.2f)" % [float(consts["DROP_TRIGGER_X"]), dropped_at.x],
		dropped_at.x > float(consts["DROP_TRIGGER_X"]) and dropped_at.x < float(consts["DROP_TRIGGER_X"]) + 0.4)
	_ok("the body lands 1.5–2.5 m ahead of the player (%.2f m)" % ahead, ahead >= 1.5 and ahead <= 2.5)
	_ok("the hatch burst open (%.0f°) and the body is shown, solid" % rad_to_deg(hatch.rotation.z),
		hatch.rotation.z < deg_to_rad(-100.0) and victim.visible and not solid.disabled)
	_ok("the lane stays clear to physics rays through the swing (%d samples, %d blocked)" % [samples, lane_blocked],
		samples > 30 and lane_blocked == 0)
	_ok("POSITIVE CONTROL: the same ray along the body's line does hit it (%d of %d)" % [body_hits, samples], body_hits > 0)
	_ok("the walk carries on to the Threshold end of Containment (x %.2f)" % _player.global_position.x,
		_player.global_position.x >= target.x - 0.35)
	_ok("it swings and twists (peak %.2f rad)" % swing_peak, swing_peak > 0.3)
	# walk back past the trigger and forward again: once per run
	var back := Vector3(-11.0, 0.1, -26.0)
	e = 0.0
	while _player.global_position.x > back.x + 0.3 and e < 8.0:
		_player.call("ai_look_at", Vector3(back.x, 1.7, back.z))
		_player.set("ai_move_dir", Vector2(0, -1))
		await _frame()
		e += 1.0 / Engine.physics_ticks_per_second
	_player.set("ai_move_dir", Vector2.ZERO)
	_ok("walking back west past the body is unobstructed too (x %.2f)" % _player.global_position.x, _player.global_position.x <= back.x + 0.35)
	_player.global_position = Vector3(-8.5, 0.1, -26.0)
	await _secs(0.3)
	_ok("crossing again does not fire it again (%d)" % _count("ceiling_drop"), _count("ceiling_drop") == 1)
	await _secs(14.0)
	_ok("it settles (rotation %.3f rad after ~20 s)" % rig.rotation.length(), rig.rotation.length() < 0.06)


# ------------------------------------------------------------------------------ C. the technician

func _technician(consts: Dictionary) -> void:
	var tech: Node3D = _approach.get_node_or_null("DeadTechnician")
	_ok("the fused technician exists", tech != null)
	if tech == null:
		return
	var head: Vector3 = _approach.get("_tech_head")
	var wheel: Vector3 = (_approach.get("_wheel") as Node3D).global_position
	var apart := Vector2(head.x - wheel.x, head.z - wheel.z).length()
	_ok("he is on the Plenum's far side from the porthole door (%.1f m)" % apart, apart > 12.0)
	var stop: Vector3 = consts["TECH_STOP"]
	var eye := stop + Vector3(0, 1.6, 0)
	_ok("TECH_STOP puts his face within reach of the E ray (%.2f m)" % eye.distance_to(head), eye.distance_to(head) < 2.9)
	var parts := _all(tech, [])
	var relief := parts.filter(func(n): return n is MeshInstance3D and String(n.name) == "TechnicianBody")
	var spread := parts.filter(func(n): return n is MeshInstance3D and n.mesh is QuadMesh and String(n.name) == "GrowthSpread")
	var spheres := parts.filter(func(n): return n is MeshInstance3D and n.mesh is SphereMesh and String(n.name) != "TechLampBulb")
	var tendrils := parts.filter(func(n): return String(n.name).begins_with("GrowthTendril") and n.mesh is CapsuleMesh)
	var limbs := parts.filter(func(n): return (String(n.name).begins_with("Arm") or String(n.name).begins_with("Sleeve")
		or String(n.name).begins_with("FusedHand") or String(n.name).begins_with("LeftForearm") or String(n.name) == "Palm"))
	var wheel_node: Node3D = _approach.get("_tech_wheel")
	print("  relief quads %d  spheres %d  tendrils %d  3D limb parts %d" % [relief.size(), spheres.size(), tendrils.size(), limbs.size()])
	_ok("ONE relief and the roots decal flat on the wall behind it", relief.size() == 1 and spread.size() == 1)
	if relief.is_empty():
		return
	# ⭐ 2026-09-24: the user's art carries the swallowed body and the arms, so no 3D mass is left
	_ok("NO sphere mass (%d spheres; the 56-lump mound is gone) and NO 3D arms, sleeves or hands (%d parts)" % [spheres.size(), limbs.size()],
		spheres.is_empty() and limbs.is_empty())
	var fat := tendrils.filter(func(n): return (n.mesh as CapsuleMesh).radius > 0.025)
	var standing := tendrils.filter(func(n): return n.position.z > 0.075)
	_ok("only a few THIN tendrils (%d segments), all lying on the wall (%d thicker than 2.5 cm, %d standing off it)" % [tendrils.size(), fat.size(), standing.size()],
		tendrils.size() >= 5 and tendrils.size() <= 40 and fat.is_empty() and standing.is_empty())
	# ⭐ 2026-09-24 (the user: "a man holding a wheel looks very two D"): a real BAS-RELIEF MESH
	var rq: MeshInstance3D = relief[0]
	var arrays: Array = rq.mesh.surface_get_arrays(0) if rq.mesh else []
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays.size() > 0 else PackedVector3Array()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays.size() > 0 else PackedVector2Array()
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays.size() > 0 else PackedInt32Array()
	_ok("the relief is a displaced MESH, not a flat card (%d vertices, %d triangles)" % [verts.size(), idx.size() / 3],
		not (rq.mesh is QuadMesh) and verts.size() > 10000 and idx.size() / 3 > 10000)
	if verts.is_empty():
		return
	var aabb: AABB = rq.mesh.get_aabb()
	var rsize := Vector2(aabb.size.x, aabb.size.y)
	var tex: Texture2D = _approach.get("_tech_tex_closed")
	var tex_aspect := float(tex.get_width()) / tex.get_height()
	_ok("the mesh's aspect is its texture's (%.3f against %.3f): the art is not stretched" % [rsize.x / rsize.y, tex_aspect],
		absf(rsize.x / rsize.y - tex_aspect) < 0.01)
	var head_w := rsize.x * float(consts["TECH_ART_HEAD_FRAC"])
	_ok("he is LIFE SIZE: his head is %.2f m across, ears included (a man's is ~0.18–0.22 m)" % head_w, head_w >= 0.17 and head_w <= 0.24)
	var base := INF
	for v in verts:
		base = minf(base, v.z)
	var sp: Node3D = spread[0]
	_ok("he is grown out of the wall: the mesh's base is %.3f m off it (>= 2 cm), the roots decal behind it at %.3f m" % [base, sp.position.z],
		base >= 0.02 and base <= 0.08 and sp.position.z >= 0.02 and sp.position.z < base)
	# depth where it should be: sample the vertex heights round art UVs
	var depth_at := func(uv: Vector2, r_uv: float) -> float:
		var best := 0.0
		for k in verts.size():
			if uvs[k].distance_to(uv) <= r_uv:
				best = maxf(best, verts[k].z - base)
		return best
	var chest: float = depth_at.call(Vector2(0.5, 0.45), 0.05)
	var face: float = depth_at.call(Vector2(0.505, 0.21), 0.03)
	var fists := minf(depth_at.call(consts["TECH_ART_GRIPS_UV"][0], 0.02), depth_at.call(consts["TECH_ART_GRIPS_UV"][1], 0.02))
	var ring := 0.0
	for k in verts.size():
		var u := uvs[k]
		if u.x < 0.015 or u.x > 0.985 or u.y < 0.015 or u.y > 0.985:
			ring = maxf(ring, verts[k].z - base)
	print("  relief depth: chest %.3f m  face %.3f m  fists %.3f m  frame edge %.4f m" % [chest, face, fists, ring])
	_ok("REAL DEPTH: the chest stands %.2f m proud, the face %.2f m, the fists %.2f m (each >= 0.10 m)" % [chest, face, fists],
		chest >= 0.10 and face >= 0.10 and fists >= 0.10)
	_ok("and it falls to the wall at the edges of the art (%.4f m at the frame edge)" % ring, ring <= 0.005)
	# no spikes: a vertex standing out of its four neighbours' mean (a steep flank is fine — a torso's
	# side IS steep — a single-vertex spike or pit is not)
	var n: int = consts["TECH_MESH_N"]
	var spike := 0.0
	var steep := 0.0
	for j in range(1, n):
		for i in range(1, n):
			var c0: float = verts[j * (n + 1) + i].z
			var nb := (verts[j * (n + 1) + i - 1].z + verts[j * (n + 1) + i + 1].z + verts[(j - 1) * (n + 1) + i].z + verts[(j + 1) * (n + 1) + i].z) * 0.25
			spike = maxf(spike, absf(c0 - nb))
			steep = maxf(steep, absf(verts[j * (n + 1) + i + 1].z - c0))
	_ok("smooth, no spikes (largest vertex offset from its neighbours' mean %.1f mm; steepest flank %.0f mm per 6.8 mm)" % [spike * 1000.0, steep * 1000.0],
		spike < 0.02 and steep < 0.07)
	_ok("it casts shadows (the lamp throws his head, arms and the wheel onto him and the wall)",
		rq.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	# the grip points: from the ART's UVs, through the relief's own extents (not through the level's maths)
	var grips_uv: Array = consts["TECH_ART_GRIPS_UV"]
	var grips: Array = []
	for uv in grips_uv:
		grips.append(Vector2(rq.position.x + ((uv as Vector2).x - 0.5) * rsize.x, rq.position.y + (0.5 - (uv as Vector2).y) * rsize.y))
	# …and they must BE his painted fists: opaque, skin-toned texels there on the art
	var img: Image = (_approach.get("_tech_tex_closed") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var on_skin := 0
	for uv in grips_uv:
		var c := Color(0, 0, 0, 0)
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				c += img.get_pixel(int((uv as Vector2).x * img.get_width()) + dx, int((uv as Vector2).y * img.get_height()) + dy) / 25.0
		print("  grip uv %s: texel %s" % [uv, c])
		if c.a > 0.5 and c.r > c.b + 0.06 and c.r >= c.g - 0.02 and c.v > 0.35:
			on_skin += 1
	_ok("both grip points are on his painted fists (%d of 2 opaque, skin-toned)" % on_skin, on_skin == 2)
	# ⭐ THE WHOLE VALVE WHEEL, between the painted hands, pressed flush
	var spokes := [] if wheel_node == null else _all(wheel_node, []).filter(func(n): return String(n.name).begins_with("WheelSpoke"))
	var rim: MeshInstance3D = null if wheel_node == null else wheel_node.find_child("WheelRim", true, false) as MeshInstance3D
	_ok("he holds the whole valve wheel: a rim and %d spokes" % spokes.size(), wheel_node != null and rim != null and rim.mesh is TorusMesh and spokes.size() == 5)
	if wheel_node == null:
		return
	var wl := tech.to_local(wheel_node.global_position)
	var at_fists := wl.z - (base + fists)
	_ok("it sits at the FISTS' displaced depth, not the wall's: its plane %.3f m in front of the lower fist's surface, %.3f m off the wall, parallel to it" % [at_fists, wl.z],
		at_fists >= -0.005 and at_fists <= 0.04 and wl.z - base >= 0.09 and absf(wheel_node.rotation.x) < 0.05 and absf(wheel_node.rotation.y) < 0.05)
	var radius: float = consts["VALVE_R"]
	var on_rim := 0
	for g in grips:
		var d := absf((g as Vector2).distance_to(Vector2(wl.x, wl.y)) - radius)
		print("  painted fist at %s: %.3f m off the rim circle" % [g, d])
		if d < 0.015:
			on_rim += 1
	_ok("the wheel sits between his painted hands: its rim passes through both fists (%d of 2 within 1.5 cm)" % on_rim, on_rim == 2)
	var steel := (rim.material_override as StandardMaterial3D) if rim else null
	_ok("bare, bright steel (albedo %.2f, metallic %.2f: bright enough for the lamp to catch, not a dark mirror), not emissive" % [steel.albedo_color.v if steel else 0.0, steel.metallic if steel else 0.0],
		steel != null and steel.albedo_color.v >= 0.6 and steel.metallic >= 0.4 and steel.metallic <= 0.7 and not steel.emission_enabled)
	var lamp: SpotLight3D = tech.find_child("TechnicianLamp", true, false) as SpotLight3D
	var down := (-lamp.global_basis.z) if lamp else Vector3.ZERO
	_ok("a caged lamp above him lights him from above, shadowed (aim %.2f down; %.2f m above his face)" % [-down.y, (lamp.global_position.y - head.y) if lamp else 0.0],
		lamp != null and lamp.shadow_enabled and down.y < -0.5 and lamp.global_position.y > head.y + 0.2)
	var nmat: StandardMaterial3D = _approach.call("technician_material")
	_ok("the relief has a normal map derived from the art, so the lamp shapes it", nmat != null and nmat.normal_enabled and nmat.normal_texture != null)
	# the door: a bare spindle, and the wheel on it hidden until it is fitted
	var door_wheel: Node3D = _approach.get("_wheel")
	_ok("the porthole door shows a bare spindle; its wheel is not there until fitted",
		_approach.find_child("WheelSpindle", true, false) != null and door_wheel != null and not door_wheel.visible)
	var mat: StandardMaterial3D = _approach.call("technician_material")
	var closed: Texture2D = _approach.get("_tech_tex_closed")
	var opened: Texture2D = _approach.get("_tech_tex_open")
	_ok("the relief is the fused pair, eyes closed to start (%s)" % (closed.resource_path.get_file() if closed else "none"),
		mat != null and closed != null and opened != null and mat.albedo_texture == closed
		and closed.resource_path.ends_with("approach_fused_closed.png") and opened.resource_path.ends_with("approach_fused_open.png")
		and closed.get_size() == opened.get_size())
	var glow := parts.filter(func(n): return (n is MeshInstance3D and n.material_override is StandardMaterial3D
		and n.material_override.emission_enabled and String(n.name) != "TechLampBulb"))
	_ok("nothing on him glows but the lamp's bulb (%d)" % glow.size(), glow.is_empty())
	var r := _ray(Vector3(stop.x, 1.0, head.z), Vector3(head.x + 0.4, 1.0, head.z))
	_ok("he is solid: a ray from the room at chest height stops on his mass (%s)" % (r["collider"].name if not r.is_empty() else "nothing"),
		not r.is_empty() and _under(r["collider"], tech))
