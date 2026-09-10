extends SceneTree

# THE MAP ICON MOVES AT ONE SPEED, WHATEVER YOUR PANIC IS.
#
#   Godot --headless --path game --script res://tests/check_maze_speed.gd
#
# 2026-09-10, from the user's replay of the House: *"if you failed the first attempt the next
# time you get slower. It should not be that way. I think the ideal speed is constant."* The icon's
# ease rate and speed cap used to be `lerpf`ed by the 3D player's panic ratio, and panic carries
# across attempts (a catch costs 18 of 50), so every retry WAS slower. `maze_chase_ui.gd:_drag_step()`
# now owns that arithmetic as a pure function, and this test feeds it the same cursor at panic
# 0.0 and 0.9 and requires the same travel to the last bit.
#
# ⚠️ `check_maze_chase.gd` cannot see this: its bot writes `_player_pos` at its own ESCAPE_SPEED
# and never reads the drag constants, so the win-rate harness was green on both sides of the
# coupling. A property nothing measures is a property that ships broken.

const DT := 1.0 / 60.0
const FRAMES := 30
const CURSOR := Vector2(900.0, 40.0)

var _fails := 0
var _checks := 0
var _done := false


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print("  %s  %s%s" % ["OK  " if cond else "FAIL", label, ("   " + detail) if detail != "" else ""])
	if not cond:
		_fails += 1


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var script: GDScript = load("res://scripts/maze_chase_ui.gd")
	var ui: Node = script.new()
	root.add_child(ui)

	var consts: Dictionary = script.get_script_constant_map()
	_ok("the drag physics is ONE constant pair (SPRING_K, PLAYER_SPEED)",
		consts.has("SPRING_K") and consts.has("PLAYER_SPEED"),
		"SPRING_K=%s PLAYER_SPEED=%s" % [str(consts.get("SPRING_K")), str(consts.get("PLAYER_SPEED"))])
	_ok("…and the panic-lerp pair is GONE, not merely unused",
		not consts.has("SPRING_K_PANIC") and not consts.has("PLAYER_MIN_SPEED")
			and not consts.has("SPRING_K_BASE") and not consts.has("PLAYER_MAX_SPEED"))
	var speed := float(consts.get("PLAYER_SPEED", 0.0))
	_ok("the constant sits between the old first-run (240) and retry (~156-190) speeds",
		speed > 190.0 and speed < 240.0, "PLAYER_SPEED %.0f" % speed)

	# Drive the pure step with two panic values from the same start and cursor.
	var travel: Dictionary = {}
	for ratio in [0.0, 0.9]:
		var pos := Vector2(100.0, 40.0)
		var first_step := Vector2.ZERO
		for i in range(FRAMES):
			var step: Vector2 = ui.call("_drag_step", CURSOR, pos, ratio, DT)
			if i == 0:
				first_step = step
			pos += step
		travel[ratio] = {"pos": pos, "first": first_step}
	var p0: Vector2 = travel[0.0]["pos"]
	var p9: Vector2 = travel[0.9]["pos"]
	_ok("the icon travels EXACTLY as far at panic 0.9 as at panic 0.0",
		p0.is_equal_approx(p9), "after %d frames: %s vs %s" % [FRAMES, str(p0), str(p9)])
	var f0: Vector2 = travel[0.0]["first"]
	_ok("…and the first frame is capped at PLAYER_SPEED, not at a panic-scaled speed",
		is_equal_approx(f0.length(), speed * DT), "%.3f px vs cap %.3f" % [f0.length(), speed * DT])
	_ok("the icon actually moved (the measurement is not of a stuck icon)",
		p0.distance_to(Vector2(100.0, 40.0)) > 50.0, "%.1f px" % p0.distance_to(Vector2(100.0, 40.0)))

	# CONTROL: a step that DID scale with panic would be caught — build one by hand from the
	# retired lerp and prove the equality assertion above is not vacuous.
	var k9: float = lerpf(9.0, 3.0, 0.9)
	var cap9: float = lerpf(240.0, 100.0, 0.9) * DT
	var ctrl := Vector2(100.0, 40.0)
	for i in range(FRAMES):
		var s: Vector2 = (CURSOR - ctrl) * (1.0 - exp(-k9 * DT))
		if s.length() > cap9:
			s = s.normalized() * cap9
		ctrl += s
	_ok("CONTROL — the retired panic lerp would have travelled a different distance",
		not ctrl.is_equal_approx(p0), "old lerp at 0.9: %s vs constant: %s" % [str(ctrl), str(p0)])

	ui.queue_free()
	print("%d checks, %d failed" % [_checks, _fails])
	print("MAZE-SPEED PASS" if _fails == 0 else "MAZE-SPEED FAIL")
	quit(1 if _fails > 0 else 0)
	return true
