extends SceneTree

# DOES A FROZEN PLAYER STOP SPRINTING?
#
#   Godot --headless --path game --script res://tests/check_frozen_sprint.gd
#
# ⚠️ FOUND BY PLAYING, NOT BY READING (2026-09-07). An independent agent sprinted into a Breach
# hiding spot and died in 6.1 seconds standing perfectly still: panic climbed 13.20 → 49.20 at
# exactly +6.00/s = `SPRINT_PANIC_RATE`, with `velocity` (0.00, 0.00) the whole time.
#
# `_apply_movement()` returns early on `_input_frozen` ABOVE the line that recomputes
# `_is_sprinting`, so the flag LATCHES at whatever it was on the last unfrozen frame. Every
# consumer keeps reading it:
#   player.gd:521            +6 panic/s, and it SUPPRESSES DECAY, so there is no way down
#   apparition.gd:456        `_is_fleeing()` — a HOLD apparition KILLS YOU for this
#   creature_smiler.gd:92    sprinting → fatal rush
#   level_6_breach.gd:327    broadcasts your position to the creature you are hiding from
#   dungeon.gd:1404          sprint-deafness ducks the tells you are listening for
# The two fatal ones are why this is a `check_` and not a backlog line: hiding is the Breach's
# own counter-play, and freezing is how the game delivers half its set pieces.
#
# ⚠️ `_is_moving` LATCHES THE SAME WAY, and CLAUDE.md:1519 claims the opposite in as many words —
# *"Footstep audio is silenced for free by the existing `_is_moving`-gated chain"*. It is not:
# `_handle_footsteps()` needs only `_is_moving and is_on_floor()`, both true for a hidden player
# who WALKED to the locker, which is all of them. A player hiding from a creature that hunts by
# noise was broadcasting footsteps.
#
# ⚠️ THE CONTROL IS THE POINT. "Panic did not climb" is trivially true of a build where sprinting
# is broken, of a player who never sprinted, and of a level that failed to load. Phase C sprints
# WITHOUT freezing and requires panic to climb and the flag to be true.

const LEVEL := "res://scenes/level_6_breach.tscn"
const SAMPLE := 1.5          # seconds of held state per phase
const SPRINT_RATE := 6.0     # player.gd:SPRINT_PANIC_RATE
const STILL_SAMPLE := 6.5    # past STANDSTILL_GRACE 4.0 with room for the tax to show
const SEED_PANIC := 30.0     # high enough that a full 22.75 decay cannot clamp at zero
const TAX_SPLIT := 19.0      # between the taxed (~15.25) and untaxed (~22.75) drops

var _fails := 0
var _checks := 0
var _t := 0.0
var _wall := 0.0
var _phase := -1
var _level: Node = null
var _player: CharacterBody3D = null
var _panic0 := 0.0
var _spot: Node = null


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _initialize() -> void:
	Engine.time_scale = 3.0
	seed(31)
	change_scene_to_file(LEVEL)


func _panic() -> float:
	return float(_player.get("_panic"))


# Drive one real sprinting frame so the flag is genuinely set by the shipping path — never by
# poking `_is_sprinting`, which would test the assignment instead of the behaviour.
func _sprint_for_real() -> void:
	_player.ai_active = true
	_player.ai_sprint = true
	_player.ai_move_dir = Vector2(0, -1)


func _stop_ai() -> void:
	_player.ai_sprint = false
	_player.ai_move_dir = Vector2.ZERO


func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 120.0:
		print("TIMEOUT in phase %d" % _phase)
		return _report()
	_t += delta
	if current_scene == null:
		return false

	if _level == null:
		if _t < 2.0:
			return false
		_level = current_scene
		_player = _level.get_node_or_null("Player") as CharacterBody3D
		if _player == null:
			print("no player")
			return _report()
		# Keep the creature out of this entirely — it is not what is under test, and a chase
		# would add panic terms that mask the one being measured.
		_level.set("_creature_awake", false)
		var creature = _level.get("_creature")
		if creature != null and is_instance_valid(creature):
			creature.set("_active", false)
		for n in _level.find_children("*", "Node", true, false):
			if n is HidingSpot:
				_spot = n
				break
		if _spot == null:
			print("no hiding spot found")
			return _report()
		print("== FROZEN SPRINT ==  spot=%s" % _spot.name)
		_phase = 0
		_t = 0.0
		return false

	# ---- Phase 0: sprint for real, then hide through the REAL interact ray -----------------
	if _phase == 0:
		# ⚠️ TELEPORT ONCE, THEN LET IT LAND. `_is_sprinting` requires `is_on_floor()`, and a body
		# re-placed every frame is never on the floor — the first version of this test moved the
		# player each tick and its own control caught it: "the player really is sprinting" FAILED,
		# which made the three assertions after it vacuous.
		if _t < 0.10:
			_player.global_position = _spot.call("hide_anchor") + Vector3(0, 0.1, 0)
			return false
		if _t < 0.60:
			_sprint_for_real()
			return false
		_ok("CONTROL — the player really is sprinting before the freeze",
			bool(_player.call("is_sprinting")), "if this is false the phase proves nothing")
		_spot.call("interact")
		_stop_ai()
		_ok("the player is hidden", bool(_player.call("is_hidden")))
		_panic0 = _panic()
		_phase = 1
		_t = 0.0
		return false

	if _phase == 1:
		if _t < SAMPLE:
			return false
		var gained: float = _panic() - _panic0
		var expected: float = SPRINT_RATE * SAMPLE
		_ok("HIDDEN: the sprint flag is cleared", not bool(_player.call("is_sprinting")),
			"latched true = +6 panic/s standing still, and fatal to an apparition or a Smiler")
		_ok("HIDDEN: panic does not climb at the sprint rate",
			gained < expected * 0.5,
			"gained %.2f in %.1f s; a latched sprint gives %.2f" % [gained, SAMPLE, expected])
		_ok("HIDDEN: the moving flag is cleared (footsteps)",
			not bool(_player.get("_is_moving")),
			"latched true keeps footsteps playing while you hide from something that hears")
		_player.call("exit_hiding")
		_phase = 2
		_t = 0.0
		return false

	# ---- Phase 2: the beartrap pin, same shape, a different early return -------------------
	if _phase == 2:
		if _t < 0.35:
			_sprint_for_real()
			return false
		_player.call("begin_qte")
		_stop_ai()
		_panic0 = _panic()
		_phase = 3
		_t = 0.0
		return false

	if _phase == 3:
		if _t < SAMPLE:
			return false
		var gained2: float = _panic() - _panic0
		_ok("QTE PIN: the sprint flag is cleared", not bool(_player.call("is_sprinting")),
			"the beartrap already charges 15 + 40; a latched sprint adds 6/s on top")
		_ok("QTE PIN: panic does not climb at the sprint rate",
			gained2 < SPRINT_RATE * SAMPLE * 0.5,
			"gained %.2f in %.1f s" % [gained2, SAMPLE])
		_player.call("end_qte")
		_phase = 4
		_t = 0.0
		return false

	# ---- Phase 4: THE CONTROL — sprinting while NOT frozen must still cost ------------------
	if _phase == 4:
		_player.set("_panic", 0.0)
		_panic0 = 0.0
		_sprint_for_real()
		_phase = 5
		_t = 0.0
		return false

	if _phase == 5:
		if _t < SAMPLE:
			_sprint_for_real()
			return false
		var gained3: float = _panic() - _panic0
		_ok("CONTROL — an UNFROZEN sprint still sets the flag",
			bool(_player.call("is_sprinting")),
			"if this fails the three assertions above are vacuous")
		_ok("CONTROL — an UNFROZEN sprint still costs panic",
			gained3 > SPRINT_RATE * SAMPLE * 0.4,
			"gained %.2f in %.1f s, expected ~%.2f" % [gained3, SAMPLE, SPRINT_RATE * SAMPLE])
		_stop_ai()
		# ⚠️⚠️ SEED PANIC, AND MEASURE THE DECAY DIFFERENTIAL — NEVER THE ABSOLUTE GAIN. The first
		# version of these three assertions started from panic 0 and asserted "gained < 1.0", and
		# they passed **on the broken build too**: `PANIC_DECAY_RATE` 3.5/s exceeds
		# `STANDSTILL_PANIC_RATE` 3.0/s, so a taxed player standing still still nets −0.5/s,
		# clamps at zero, and reads a comfortable 0.00 either way. Its own control caught it.
		# From a seeded 30, over `STILL_SAMPLE` with `STANDSTILL_GRACE` 4.0 of it free:
		#     untaxed  drop ≈ 3.5 × 6.5                     = 22.75
		#     taxed    drop ≈ 22.75 − 3.0 × (6.5 − 4.0)     = 15.25
		# so the two are 7.5 apart and `TAX_SPLIT` sits between them.
		_player.call("enable_standstill_panic")
		_player.call("freeze_input")
		_player.set("_panic", SEED_PANIC)
		_phase = 6
		_t = 0.0
		return false

	if _phase == 6:
		if _t < STILL_SAMPLE:
			return false
		var drop_frozen: float = SEED_PANIC - _panic()
		_ok("FROZEN: standing still is NOT taxed — you cannot move",
			drop_frozen > TAX_SPLIT,
			"panic fell %.2f over %.1f s; untaxed ~22.75, taxed ~15.25" % [drop_frozen, STILL_SAMPLE])
		_player.call("unfreeze_input")
		_player.call("begin_qte")
		_player.set("_panic", SEED_PANIC)
		_phase = 7
		_t = 0.0
		return false

	if _phase == 7:
		if _t < STILL_SAMPLE:
			return false
		var drop_qte: float = SEED_PANIC - _panic()
		_ok("QTE PIN: standing still is NOT taxed either",
			drop_qte > TAX_SPLIT,
			"panic fell %.2f over %.1f s" % [drop_qte, STILL_SAMPLE])
		_player.call("end_qte")
		_player.set("_panic", SEED_PANIC)
		_phase = 8
		_t = 0.0
		return false

	# ---- THE CONTROL: free to move, standing still, the tax MUST bite -----------------------
	if _phase == 8:
		if _t < STILL_SAMPLE:
			_player.ai_move_dir = Vector2.ZERO
			return false
		var drop_free: float = SEED_PANIC - _panic()
		_ok("CONTROL — an UNFROZEN player standing still IS taxed",
			drop_free < TAX_SPLIT,
			"panic fell %.2f over %.1f s; if this matches the frozen figure the three above prove nothing"
				% [drop_free, STILL_SAMPLE])
		return _report()

	return false


func _report() -> bool:
	print("== %d checks, %d failed ==" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return true
