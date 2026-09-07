extends SceneTree

# THE HIDING SPOTS, DRIVEN THE WAY A PLAYER DRIVES THEM.
#
#   Godot --headless --path game --script res://tests/check_hiding_spots.gd
#
# ⚠️⚠️ NOTHING IN THIS REPO TOUCHED THIS PATH BEFORE 2026-09-07. `grep enter_hiding|exit_hiding`
# over `game/tests/` returned **zero hits**. `check_interact_reach.gd` proves a HidingSpot can be
# AIMED at and never presses E on one; `test_creature_object12.gd` proves the creature honours
# `is_hidden()` using a **stub player** with a hand-set boolean, so it says nothing about how the
# flag gets set; `check_level6_breach.gd` counts six of them.
#
# The player reported it: *"when I enter the cabinets — my flashlight stops working and I cannot
# see anything."* Two separate defects, both invisible to every guard in the suite:
#
#   1. `enter_hiding()` used `lock_flashlight()` / `unlock_flashlight()` — the pair `player.gd`
#      itself documents as *"not enough for a temporary blackout: it hides the light but
#      `unlock_flashlight()` only clears the lock."* So the torch never came back, and with it the
#      LIGHT WEAPON (`_tick_light_weapon()` returns early on `not is_flashlight_on()`). Git dates
#      it as a stale caller: the hiding code predates the correct API by six days.
#   2. `_hide_yaw_center` was the yaw at the E-press — i.e. pointing AT the wall the spot is
#      mounted on — so the ±50° peek cone was centred into masonry. Measured in Corridor1, the
#      creature's only approach was ~105° off-axis.
#
# ⚠️ THE TORCH ASSERTION READS `is_flashlight_on()`, NOT `_flashlight_locked`. `check_lab_locker.gd`
# asserts the FLAG and passes happily on a torch that is still dark — that is precisely how this
# shipped. `check_house_guest.gd` asserts the light end to end, but for the *other* API.

const SCENE := "res://scenes/level_6_breach.tscn"
const SETTLE := 3.0
const CYCLES := 2          # enter/leave twice per spot: the second time is where state leaks show

var _fails := 0
var _checks := 0
var _t := 0.0
var _wall := 0.0
var _stage := 0
var _level: Node = null
var _player: CharacterBody3D = null
var _creature: Node = null
var _spots: Array = []
var _i := 0
var _cycle := 0
var _peek_limit := 0.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _initialize() -> void:
	seed(7)
	change_scene_to_file(SCENE)


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _collect() -> void:
	var nodes: Array = []
	_all(_level, nodes)
	for x in nodes:
		var sc = x.get_script()
		if sc == null:
			continue
		var path := String(sc.resource_path)
		if path.ends_with("hiding_spot.gd"):
			_spots.append(x)
		elif path.ends_with("creature_object12.gd"):
			_creature = x


func _creature_body() -> Node3D:
	if _creature == null:
		return null
	var nodes: Array = []
	_all(_creature, nodes)
	for x in nodes:
		if x is StaticBody3D:
			return x as Node3D
	return null


func _torch_on() -> bool:
	return bool(_player.call("is_flashlight_on"))


# Stand where a player would: in front of the spot, looking at it.
func _approach(spot: Node3D) -> void:
	var out_dir: Vector3 = spot.global_transform.basis.z
	out_dir.y = 0.0
	out_dir = out_dir.normalized() if out_dir.length() > 0.01 else Vector3(0, 0, 1)
	_player.global_position = spot.global_position + out_dir * 1.1 + Vector3(0, 0.1, 0)
	_player.velocity = Vector3.ZERO
	_player.call("ai_look_at", spot.global_position + Vector3(0, 1.2, 0))
	_player.force_update_transform()
	var cam := _player.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.force_update_transform()


# ⚠️ THE CONE IS ASSERTED AGAINST THE ROOM, NOT AGAINST A DOORWAY, and the first draft of this
# file got that wrong. Four of the six spots are mounted on a CORRIDOR SIDE WALL, so they face
# across the corridor while its doorways are at roughly ±75° — no ±50° cone can ever contain
# them, and demanding it would be asserting something the geometry forbids rather than something
# the fix should deliver. What hiding has to give you is a view OF THE ROOM: the creature enters
# that view as it draws level with you, which is the moment that matters. Asserting the room
# centre keeps the property honest and still fails loudly on a cone pointed into masonry.
func _room_centre_of(spot: Node3D) -> Vector3:
	var rooms: Array = _level.get_script().get_script_constant_map().get("ROOMS", [])
	var p := spot.global_position
	for r in rooms:
		var pos: Vector2 = r["pos"]
		var half: Vector2 = (r["size"] as Vector2) * 0.5
		if absf(p.x - pos.x) <= half.x + 0.6 and absf(p.z - pos.y) <= half.y + 0.6:
			return Vector3(pos.x, 0.0, pos.y)
	return Vector3(INF, 0.0, INF)


func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 180.0:
		print("TIMEOUT at stage %d, spot %d" % [_stage, _i])
		return _report()
	_t += delta
	if _t < SETTLE or current_scene == null:
		return false
	if _level == null:
		_level = current_scene
		_player = _level.get_node_or_null("Player") as CharacterBody3D
		_collect()
		# ⚠️⚠️ STOP THE FAMILIARIZATION TIMER, or this test kills its own player. The first run
		# teleported the player from spot to spot for longer than `FAMILIARIZATION_FIRST` 30 s;
		# Object 12 then activated, hunted down a stationary target and fired the screamer, which
		# RELOADS THE SCENE. `_level` became a freed object — and in Godot a freed reference
		# compares EQUAL to null, so the setup block re-entered, `_collect()` ran a second time,
		# and the test cheerfully reported "12 hiding spots found". Setting `_creature_awake`
		# short-circuits `_tick_familiarization()` without activating anything.
		_level.set("_creature_awake", true)
		# ⚠️ Resolve the creature's own player reference before calling `_detect_player()`. It is
		# normally seeded by `_ensure_player()` inside `_process`, which only runs once the
		# creature is active — and a GDScript runtime error here would abort `_process` mid-test
		# AND fail the whole suite (a `SCRIPT ERROR` is a failure even at exit 0).
		if _creature != null:
			_creature.call("_ensure_player")
		var ps: GDScript = load("res://scripts/player.gd")
		_peek_limit = float(ps.get("HIDE_PEEK_LIMIT"))
		print("== HIDING SPOTS ==  %d found, peek cone +-%.0f deg"
			% [_spots.size(), rad_to_deg(_peek_limit)])
		_ok("all six hiding spots exist", _spots.size() == 6, "%d found" % _spots.size())
		_ok("a live player and creature", _player != null and _creature != null)
		if _player == null or _spots.is_empty():
			return _report()
		_player.set("ai_active", true)
		_t = 0.0
		return false

	# ⚠️ A freed Node compares == null in GDScript, so this is how a reloaded scene announces
	# itself. Without it the test silently restarts and doubles its own sample.
	if current_scene != _level:
		_ok("the scene did not reload mid-test", false,
			"something fired Screamer.trigger() — every assertion after this point is on a "
			+ "different level instance")
		return _report()
	if _i >= _spots.size():
		return _report()
	var spot := _spots[_i] as Node3D
	var label := "%s#%d" % [String(spot.name), _i]

	match _stage:
		0:
			_approach(spot)
			_stage = 1
			_t = 0.0
		1:
			if _t < 0.3:
				return false
			# ---- ENTER, through the real interact ray
			var seen = _player.call("ai_interact_target")
			if _cycle == 0:
				_ok("%s: the shipping ray reaches it from the approach" % label,
					seen != null and _is_spot(seen, spot), "ray saw %s" % str(seen))
				_ok("%s: the torch is ON before hiding" % label, _torch_on())
			_player.call("ai_interact")
			_ok("%s: E hides the player (cycle %d)" % [label, _cycle + 1],
				bool(_player.call("is_hidden")))
			_ok("%s: ...and the torch goes out while hidden" % label, not _torch_on(),
				"deliberate — the cost of hiding; see enter_hiding()")
			# ---- the peek cone must be able to see where the creature comes from
			if _cycle == 0:
				# ⭐ THE REGRESSION GUARD FOR THE FIX ITSELF: the player must face AWAY from the
				# spot. Before 2026-09-07 they faced straight at it, because you have to look at
				# a prop to press E on it and nothing ever re-aimed them.
				var facing: Vector3 = -_player.global_transform.basis.z
				var out_dir: Vector3 = spot.global_transform.basis.z
				facing.y = 0.0
				out_dir.y = 0.0
				var align: float = facing.normalized().dot(out_dir.normalized())
				_ok("%s: the player faces OUT of the spot, not into the wall" % label,
					align > 0.9,
					"facing-vs-outward dot %.2f (was ~-1.0: staring at the box)" % align)
				# ...and the room it is standing in is inside the cone.
				var rc := _room_centre_of(spot)
				var eye := _player.global_position
				var to := Vector3(rc.x - eye.x, 0.0, rc.z - eye.z)
				var off := 999.0
				if is_finite(rc.x) and to.length() > 0.5:
					off = absf(angle_difference(float(_player.get("_hide_yaw_center")),
						atan2(-to.normalized().x, -to.normalized().z)))
				_ok("%s: the room it is hiding in is inside the peek cone" % label,
					off <= _peek_limit,
					"room centre is %.0f deg off, cone is +-%.0f"
						% [rad_to_deg(off), rad_to_deg(_peek_limit)])
			# ---- detection really is suppressed
			if _cycle == 0 and _creature != null:
				_ok("%s: the creature cannot detect a hidden player" % label,
					not bool(_creature.call("_detect_player")))
				# ⭐ CONTROL. "cannot detect" is trivially true if the creature could never have
				# detected this pose anyway — out of range, out of its cone, or behind a wall.
				# Put it nose to nose and facing the player, un-hide for one call, and require
				# the same function to say YES.
				var body := _creature_body()
				var keep := Vector3.ZERO
				var keep_p := _player.global_position
				# ⚠️ THE CONTROL STEPS THE PLAYER OUT OF THE SPOT'S OWN COLLIDER FIRST, and the
				# reason is a genuine property of the level worth knowing: `HidingSpot` is a
				# layer-1 `StaticBody3D` whose interact volume is the carcass GROWN FORWARD by
				# 0.6 m and pushed into the room, so a player standing at `hide_anchor()` is
				# INSIDE it. Any ray to them from the room crosses that box — measured, the three
				# 2.0 m LOCKERS occlude the creature's chest-to-camera ray while the shorter
				# cabinets and desk do not. So at a locker the player is partly hidden by the
				# geometry whether or not `is_hidden()` is true, and a control run from the anchor
				# would fail for reasons that have nothing to do with the flag under test.
				# What is being controlled is "`_detect_player()` CAN say yes for this pair at
				# this range and facing", so it is run one metre clear of the box.
				var face0: Vector3 = -_player.global_transform.basis.z
				face0.y = 0.0
				face0 = face0.normalized()
				_player.global_position = keep_p + face0 * 1.0
				_player.force_update_transform()
				var cam0 := _player.get_node_or_null("Camera3D") as Camera3D
				if cam0:
					cam0.force_update_transform()
				if body:
					keep = body.global_position
					# ⚠️ PLACE IT IN THE OPEN FLOOR THE PLAYER IS FACING, not at a fixed -z
					# offset. The first draft put it 1.5 m along world -z, which for five of the
					# six spots is inside the wall the spot is mounted on — `_detect_player()`'s
					# line-of-sight ray then failed and the CONTROL failed with it, reporting a
					# broken probe as a broken game. The player is looking into the room they
					# just walked out of, so that direction is guaranteed clear.
					var face: Vector3 = -_player.global_transform.basis.z
					face.y = 0.0
					face = face.normalized()
					body.global_position = _player.global_position + face * 1.5
					# The creature's own forward is (sin(y), 0, cos(y)) — face it back at us.
					body.rotation.y = atan2(-face.x, -face.z)
					body.force_update_transform()
				_player.set("_hidden", false)
				var saw := bool(_creature.call("_detect_player"))
				_player.set("_hidden", true)
				if body:
					body.global_position = keep
					body.force_update_transform()
				_player.global_position = keep_p
				_player.force_update_transform()
				_ok("%s: CONTROL — it CAN detect an unhidden player at this range" % label, saw,
					"if this fails, the assertion above measures nothing")
			_stage = 2
			_t = 0.0
		2:
			if _t < 0.3:
				return false
			# ---- LEAVE. player.gd routes E straight to the spot while hidden.
			_player.call("ai_interact")
			_ok("%s: E lets the player out again (cycle %d)" % [label, _cycle + 1],
				not bool(_player.call("is_hidden")))
			# ⭐ THE ASSERTION THIS WHOLE FILE EXISTS FOR.
			_ok("%s: THE TORCH IS HANDED BACK (cycle %d)" % [label, _cycle + 1], _torch_on(),
				"a player who hides must not step out into the dark holding a torch that "
				+ "looks broken — and without it they have no light weapon either")
			_cycle += 1
			if _cycle >= CYCLES:
				_cycle = 0
				_i += 1
			_stage = 0
			_t = 0.0
	return false


func _is_spot(n, spot: Node) -> bool:
	var x := n as Node
	while x != null:
		if x == spot:
			return true
		x = x.get_parent()
	return false


func _report() -> bool:
	if _player:
		_player.set("ai_active", false)
	print("== %d checks, %d failed ==" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return true
