extends SceneTree

# OBJECT 12'S TANK HAS TWO STATES, AND EACH IS THE OTHER'S CONTROL (K-CELL, 2026-09-23).
#
#   Godot --headless --path game --script res://tests/check_kontur_cell.gd
#
# `containment_cell.gd` builds concept A, "the glass tank", OCCUPIED in KONTUR and BREACHED for the
# Breach. The breached tank must have no occupant, no hum, no front pane and an OPEN front a body
# can walk into; the occupied one must have all of those and a closed front. Every property is
# asserted for both states, so a builder that ignored `state` fails one half whichever way it
# ignored it — which is also this file's proof that it can fail at all.
#
# ⚠️ PHYSICS, NOT OBJECT STATE, for everything a player can touch (a wall's `is_solid()` once
# returned true for the whole life of a hole in the world): the closed/open front is a RAY, the
# interior is a POINT QUERY, and "a player could step in" is a real CapsuleShape3D the size of
# `kontur.tscn`'s (r 0.4, h 1.8) driven by `move_and_slide()` from 2.5 m out.
#
# Also:
#   * `_find_player` works under a NESTED, TURNED parent — a second occupied tank under a
#     `ContainmentApproach` node, rotated 1 rad, must find the scene's Player and turn its head to
#     it in its own frame (the old `../Player` found nothing there; a world-space bearing would
#     have stared 57° off);
#   * THE CHARGE HITS THE GLASS AT THE PLAYER AND NEVER PASSES IT: the plan's sizing rule exactly
#     (reach + distance = wall − margin), the reach along the lunge within 0.25 m of the pane and
#     never closer than 0.06 m, the collar on the neck throughout, and the crack on the pane that
#     was hit — the FRONT for a player in front of KONTUR's tank, the RIGHT pane for a player at the
#     nested tank's side, and no other pane (the old lunge was a fixed local −z);
#   * every blood/claw decal on the glass is ≥ 2 cm off every pane face.

const Scenes := preload("res://tests/lib/scenes.gd")
const CELL_SCRIPT := "res://scripts/containment_cell.gd"
const BUDGET := 60.0

var _fails := 0
var _checks := 0
var _stage := 0
var _t := 0.0
var _elapsed := 0.0

var _k: Node = null
var _cell: Node3D = null          # KONTUR's own, occupied
var _nested: Node3D = null        # occupied, under a turned ContainmentApproach
var _player: Node3D = null
var _consts: Dictionary = {}
var _max_reach := -INF            # KONTUR's tank, along its lunge
var _max_reach_side := -INF       # the nested tank, along its lunge
var _plan: Dictionary = {}
var _plan_side: Dictionary = {}
var _max_collar := 0.0
var _cracked_before_impact := false

var _world: Node3D = null         # the breached half's own test room
var _open: Node3D = null          # breached
var _shut: Node3D = null          # occupied, in the same room: the control
var _body: CharacterBody3D = null
var _walk_t := 0.0


func _initialize() -> void:
	Scenes.pin_rng(7)
	change_scene_to_file("res://scenes/kontur.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _process(delta: float) -> bool:
	_elapsed += delta
	if _elapsed > BUDGET:
		_ok("the run finished inside its %.0f s budget" % BUDGET, false, "stalled at stage %d" % _stage)
		return _finish()
	_t += delta
	match _stage:
		0:
			if _t < 1.2:
				return false
			_stage_kontur_structure()
		1:
			if _t < 4.2:          # TRACK_RATE 0.9 rad/s: time to come round a full half-turn
				return false
			_stage_nested_tracking()
		2:
			_sample_charge()
			if _t < 1.1:
				return false
			_stage_charge_result()
		3:
			if _t < 0.4:          # colliders register on the next physics step
				return false
			_stage_breached_structure()
		4:
			if _walk_t < 3.0:
				return false
			_stage_walk_result()
			return _finish()
	return false


func _physics_process(delta: float) -> bool:
	if _stage == 4 and _body and is_instance_valid(_body):
		_walk_t += delta
		# Walk straight at the tank's interior from 2.5 m in front of it, as a player would.
		var to := _open.to_global(Vector3(0, 0, 0.1)) - _body.global_position
		to.y = 0.0
		var v := to.normalized() * 1.6 if to.length() > 0.05 else Vector3.ZERO
		_body.velocity = Vector3(v.x, _body.velocity.y - 9.8 * delta, v.z)
		_body.move_and_slide()
	return false


# ------------------------------------------------------------------------------ KONTUR, occupied

func _stage_kontur_structure() -> void:
	_k = current_scene
	_cell = _k.get_node_or_null("ContainmentCell") as Node3D
	_player = _k.get_node_or_null("Player") as Node3D
	_ok("KONTUR has its tank and a player", _cell != null and _player != null)
	if _cell == null or _player == null:
		_finish()
		return
	_consts = (_cell.get_script() as GDScript).get_script_constant_map()
	_ok("KONTUR's tank is OCCUPIED (the default)", String(_cell.get("state")) == "occupied"
		and not bool(_cell.call("is_breached")))
	_check_state_structure(_cell, false, "KONTUR")
	_check_front_by_ray(_cell, false, "KONTUR")
	_check_interior_point(_cell, false, "KONTUR")
	_check_decal_clearance(_cell)

	# A second occupied tank, NESTED and TURNED, with the player off to one side of it.
	var holder := Node3D.new()
	holder.name = "ContainmentApproach"
	_k.add_child(holder)
	holder.position = Vector3(1.5, 0.0, 24.5)
	holder.rotation.y = 1.0
	_nested = (load(CELL_SCRIPT) as GDScript).new()
	_nested.name = "NestedTank"
	holder.add_child(_nested)
	_player.set_physics_process(false)
	_player.global_position = Vector3(-2.5, 0.1, 22.0)
	_next(1)


func _stage_nested_tracking() -> void:
	var found: Node = _nested.get("_player")
	_ok("a NESTED tank finds the scene's Player (not ../Player)", found == _player,
		"found %s" % (found.name if found else "<null>"))
	var occ := _nested.get_node_or_null("Object12") as Node3D
	if occ:
		var to: Vector3 = _nested.to_local(_player.global_position)
		var want := atan2(to.x, to.z)
		var err := absf(wrapf(occ.rotation.y - want, -PI, PI))
		_ok("...and turns its head to the player IN ITS OWN FRAME", err < 0.15,
			"yaw %.2f vs bearing %.2f (err %.2f rad) — a world-space bearing is off by the parent's 1.0"
				% [occ.rotation.y, want, err])
	# Now the charges. KONTUR's own tank with the player in front of it...
	_player.global_position = Vector3(-0.3, 0.1, 16.0)
	_cracked_before_impact = bool(_cell.call("is_cracked"))
	_plan = _cell.call("lunge_plan", _cell.to_local(_player.global_position))
	_cell.call("charge", _player)
	_check_plan(_plan, "front", "KONTUR, player in front")
	# ...and the nested tank with the player at its local +x side: it must go for the RIGHT pane.
	_player.global_position = _nested.to_global(Vector3(3.0, 0.0, 0.12))
	_plan_side = _nested.call("lunge_plan", _nested.to_local(_player.global_position))
	_nested.call("charge", _player)
	_check_plan(_plan_side, "right", "nested, player at its side")
	_next(2)


# ⚠️ THE SIZING RULE, asserted exactly. A reach threshold alone cannot tell a sized lunge from the
# old fixed 0.62 m one: the occupant's pose at charge time varies run to run by more than the
# difference (measured: fixed −0.771, sized −0.793 on the same seed).
func _check_plan(plan: Dictionary, face: String, tag: String) -> void:
	_ok("%s: the charge goes for the %s pane" % [tag, face.to_upper()], String(plan.get("face", "")) == face,
		"planned face '%s', dir %s" % [String(plan.get("face", "")), str(plan.get("dir"))])
	var reach: float = plan.get("reach", NAN)
	var dist: float = plan.get("dist", 0.0)
	var target: float = float(plan.get("wall", 0.0)) - float(_consts["LUNGE_FRONT_MARGIN"])
	var capped: bool = absf(dist - float(_consts["LUNGE_MAX"])) < 0.001
	_ok("%s: the lunge is SIZED to stop the reach LUNGE_FRONT_MARGIN inside the pane" % tag,
		not is_nan(reach) and (absf(reach + dist - target) < 0.002 or capped),
		"reach %.3f + lunge %.3f = %.3f, target %.3f" % [reach, dist, reach + dist, target])


func _sample_charge() -> void:
	# Reach along each tank's own lunge, from the TANK's origin-side: occupant offset + bone reach.
	for pair in [[_cell, _plan, "main"], [_nested, _plan_side, "side"]]:
		var c: Node3D = pair[0]
		var pl: Dictionary = pair[1]
		if pl.is_empty():
			continue
		var d: Vector3 = pl["dir"]
		var occ := c.get_node_or_null("Object12") as Node3D
		var r: float = c.call("reach_along", d)
		if occ == null or is_nan(r):
			continue
		var off: Vector3 = occ.position - (c.get("_occupant_rest") as Vector3)
		var total: float = r + off.x * d.x + off.z * d.z
		if pair[2] == "main":
			_max_reach = maxf(_max_reach, total)
		else:
			_max_reach_side = maxf(_max_reach_side, total)
	var anim = _cell.get("_anim")
	var collar := _cell.get_node_or_null("Collar") as Node3D
	if anim and collar:
		var sk: Skeleton3D = anim.skeleton()
		var nk: Vector3 = _cell.to_local(sk.global_transform * sk.get_bone_global_pose(sk.find_bone("neck")).origin)
		_max_collar = maxf(_max_collar, Vector2(collar.position.x - nk.x, collar.position.z - nk.z).length())


func _stage_charge_result() -> void:
	_ok("before the charge the pane is intact", not _cracked_before_impact)
	for row in [[_plan, _max_reach, _cell, "front", "KONTUR"], [_plan_side, _max_reach_side, _nested, "right", "nested"]]:
		var wall: float = float((row[0] as Dictionary).get("wall", 0.0))
		var got: float = row[1]
		_ok("%s: the charge REACHES the glass (within 0.25 m of the pane)" % row[4], got >= wall - 0.25,
			"reach %.3f along the lunge, pane at %.3f" % [got, wall])
		_ok("%s: ...and never passes it (>= 0.06 m inside the pane)" % row[4], got <= wall - 0.06,
			"reach %.3f, pane at %.3f" % [got, wall])
		_ok("%s: the impact cracked the %s pane and no other" % [row[4], String(row[3]).to_upper()],
			String((row[2] as Node).call("cracked_face")) == row[3],
			"cracked '%s'" % String((row[2] as Node).call("cracked_face")))
	_ok("the collar stayed on the neck through the lunge", _max_collar < 0.08,
		"max collar-to-neck offset %.3f m" % _max_collar)
	# Leave KONTUR for the breached half's own room.
	current_scene.queue_free()
	_build_breach_room()
	_next(3)


# ---------------------------------------------------------------------------- the breached room

func _build_breach_room() -> void:
	_world = Node3D.new()
	_world.name = "BreachRoom"
	root.add_child(_world)
	var floor := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(20, 0.2, 20)
	fs.shape = fb
	fs.position = Vector3(0, -0.1, 0)
	floor.add_child(fs)
	_world.add_child(floor)
	var script := load(CELL_SCRIPT) as GDScript
	_open = script.new()
	_open.set("state", "breached")
	var holder := Node3D.new()
	holder.name = "ContainmentApproach"
	_world.add_child(holder)
	holder.add_child(_open)
	_shut = script.new()                 # occupied, 5 m away: the same checks must disagree
	_shut.position = Vector3(5, 0, 0)
	_world.add_child(_shut)


func _stage_breached_structure() -> void:
	_ok("the breached tank reports its state", bool(_open.call("is_breached")))
	_check_state_structure(_open, true, "BREACHED")
	_check_state_structure(_shut, false, "control, occupied")
	_check_front_by_ray(_open, true, "BREACHED")
	_check_front_by_ray(_shut, false, "control, occupied")
	_check_interior_point(_open, true, "BREACHED")
	_check_interior_point(_shut, false, "control, occupied")
	# The sides stay shut in both states: only the front burst.
	var space := _open.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_open.to_global(Vector3(2.5, 1.2, 0)),
		_open.to_global(Vector3(0, 1.2, 0)))
	var hit := space.intersect_ray(q)
	_ok("BREACHED: the SIDE is still closed to a ray", not hit.is_empty()
		and _open.to_local(hit["position"]).x > 0.8)
	var counts: Vector2i = _open.call("breach_shard_counts")
	_ok("BREACHED: glass teeth left in the frame", counts.x >= 12, "%d" % counts.x)
	_ok("BREACHED: pieces thrown across the floor in front", counts.y >= 40, "%d" % counts.y)
	var ctl: Vector2i = _shut.call("breach_shard_counts")
	_ok("control: an occupied tank has no shards", ctl == Vector2i.ZERO, str(ctl))
	var half := _open.get_node_or_null("Collar/HalfR") as Node3D
	_ok("BREACHED: the collar is torn open (a half hangs off the hinge)",
		half != null and absf(half.rotation.y) > 0.8, "%.2f rad" % (half.rotation.y if half else 0.0))
	var shut_half := _shut.get_node_or_null("Collar/HalfR") as Node3D
	_ok("control: the occupied collar is closed", shut_half != null and absf(shut_half.rotation.y) < 0.01)
	_open.call("charge", null)
	_ok("BREACHED: charge() is a no-op", not bool(_open.get("_charged"))
		and float(_open.get("_lunge_t")) < 0.0 and not bool(_open.call("is_cracked")))

	# Walk a real capsule in.
	_body = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	_body.add_child(cs)
	_world.add_child(_body)
	_body.global_position = _open.to_global(Vector3(0, 0.05, -2.5))
	_walk_t = 0.0
	_next(4)


func _stage_walk_result() -> void:
	var p := _open.to_local(_body.global_position)
	_ok("BREACHED: a player-sized capsule WALKS INTO the tank over the sill",
		p.z > -0.45 and absf(p.x) < 0.5, "ended at local %s" % str(p))
	_ok("...and stands on the tank floor, not in it", absf(p.y - float(_consts["PLINTH_H"])) < 0.06,
		"foot y %.3f, tank floor %.2f" % [p.y, float(_consts["PLINTH_H"])])


# ----------------------------------------------------------------------------------- shared checks

func _check_state_structure(cell: Node3D, breached: bool, tag: String) -> void:
	var occ := cell.get_node_or_null("Object12")
	var hum := cell.get_node_or_null("CellHum")
	var front := cell.get_node_or_null("PaneFront")
	var sides := cell.get_node_or_null("PaneLeft") != null and cell.get_node_or_null("PaneRight") != null
	if breached:
		_ok("%s: NO occupant" % tag, occ == null and cell.call("occupant_material") == null)
		_ok("%s: NO hum" % tag, hum == null)
		_ok("%s: NO intact front pane" % tag, front == null)
	else:
		_ok("%s: the occupant is there" % tag, occ != null and cell.call("occupant_material") != null)
		_ok("%s: the hum is there" % tag, hum != null)
		_ok("%s: the front pane is there" % tag, front != null)
	_ok("%s: both side panes are there" % tag, sides)
	_ok("%s: the collar and both chains are there" % tag, cell.get_node_or_null("Collar") != null
		and cell.get_node_or_null("ChainL") != null and cell.get_node_or_null("ChainR") != null)


# A chest-height ray from 2.5 m in front, aimed at the centre: an occupied tank stops it at the
# front face; a breached one lets it through to the back slab.
func _check_front_by_ray(cell: Node3D, breached: bool, tag: String) -> void:
	var space := cell.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cell.to_global(Vector3(0, 1.2, -2.5)),
		cell.to_global(Vector3(0, 1.2, 1.5)))
	var hit := space.intersect_ray(q)
	var z: float = cell.to_local(hit["position"]).z if not hit.is_empty() else 99.0
	if breached:
		_ok("%s: the FRONT is open to a ray (it reaches the back)" % tag, z > 0.8, "hit at local z %.2f" % z)
	else:
		_ok("%s: the front is CLOSED to a ray" % tag, z < -0.95, "hit at local z %.2f" % z)


func _check_interior_point(cell: Node3D, breached: bool, tag: String) -> void:
	var space := cell.get_world_3d().direct_space_state
	var pq := PhysicsPointQueryParameters3D.new()
	pq.position = cell.to_global(Vector3(0, 1.0, 0))
	var solid := not space.intersect_point(pq, 1).is_empty()
	if breached:
		_ok("%s: the interior is open (a point query finds nothing)" % tag, not solid)
	else:
		_ok("%s: the interior is solid (not standable)" % tag, solid)


func _check_decal_clearance(cell: Node3D) -> void:
	var gin: float = float(_consts["GLASS_IN"])
	var gout: float = float(_consts["GLASS_OUT"])
	var n := 0
	var worst := INF
	for c in cell.get_children():
		if not (c is MeshInstance3D) or not (String(c.name).begins_with("GlassDecal")
				or String(c.name).begins_with("ImpactCrack")):
			continue
		var p: Vector3 = (c as MeshInstance3D).position
		# which face: the larger of |x| and |z| is the face axis
		var d: float = maxf(absf(p.x), absf(p.z))
		worst = minf(worst, minf(absf(d - gin), absf(d - gout)))
		n += 1
	_ok("the glass carries its blood and claw decals (+ a hidden crack per pane)", n >= 10, "%d decal(s)" % n)
	_ok("every glass decal is >= 2 cm off every pane face", worst >= 0.02, "closest %.3f m" % worst)


func _next(s: int) -> void:
	_stage = s
	_t = 0.0


func _finish() -> bool:
	_ok("enough checks actually ran", _checks >= 49, "%d checks (a full pass runs 50)" % _checks)
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
	return true
