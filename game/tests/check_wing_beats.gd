extends SceneTree

# L1.3-1.6 (2026-09-13): the doubled wing's beats.
#   * the presence follows the trail while the player walks, stops when they stop, never inside
#     2.5 m, a contact costs +12 and drops it back >= 5 m, and it sleeps when the wing lights
#   * the laugh fires once, from a wing room the player has not visited, and only once
#   * the screamer fires once, >= 8 m from the breaker, with a figure in the world, +15, gone
#     within ~1.2 s, and never a Screamer black panel
#   * NOOK_SCARE_DELAY is 20 and the wing lights AFTER the figure beat (source order)
#
#   Godot --headless --path game --script res://tests/check_wing_beats.gd

const Scenes = preload("res://tests/lib/scenes.gd")

var _fails := 0
var _checks := 0
var _t := 0.0
var _phase := 0
var _lvl: Node = null
var _p: CharacterBody3D = null
var _h: Node3D = null
var _h_after_walk := Vector3.ZERO
var _panic0 := 0.0
var _saw_black := false
var _fig_seen := false
var _glow_checked := false
var _nearest := 999.0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _initialize() -> void:
	Scenes.pin_rng(5)
	change_scene_to_file("res://scenes/level_1.tscn")


func _put(pos: Vector3, vel: Vector3 = Vector3.ZERO) -> void:
	_p.global_position = pos
	_p.velocity = vel


func _process(delta: float) -> bool:
	if current_scene == null:
		return false
	_t += delta
	var scr := root.get_node_or_null("Screamer")
	if scr and scr.get("_black_panel") != null and (scr.get("_black_panel") as CanvasItem).visible:
		_saw_black = true
	match _phase:
		0:
			if _t < 1.0:
				return false
			_lvl = current_scene
			_p = _lvl.get_node("Player")
			_p.set_physics_process(false)   # the test drives position and velocity by hand
			_ok("NOOK_SCARE_DELAY is 20 s (L1.6)", is_equal_approx(float(_lvl.get("NOOK_SCARE_DELAY")), 20.0))
			var src := FileAccess.get_file_as_string("res://scripts/level_1.gd")
			var fn := src.find("func _nook_cleanup(")
			var body := src.substr(fn, src.find("\nfunc ", fn + 10) - fn) if fn >= 0 else ""
			_ok("the wing lights AFTER the figure is freed (_nook_cleanup order)",
				body.find("_nook_figure.queue_free()") >= 0 and body.find("_nook_figure.queue_free()") < body.find("_light_the_wing()"))
			_ok("the wing is 28 rooms (21 + two loops + four deeper dead ends, 2026-09-13)", (_lvl.get("WING_ROOMS") as Array).size() == 28)
			# Into the Junction: the presence wakes.
			_put(Vector3(-21.0, 0.1, 12.5), Vector3.ZERO)
			_lvl.call("_tick_wing_beats", delta)
			_h = _lvl.get_node_or_null("WingPresence")
			_ok("entering Junction wakes the presence", _h != null and bool(_h.call("is_awake")))
			if _h == null:
				return _done()
			_ok("it starts back at the wing entrance, > 6 m away", _h.global_position.distance_to(_p.global_position) > 6.0,
				"%.1f m" % _h.global_position.distance_to(_p.global_position))
			_h.set("_cool", 0.0)
			_t = 0.0
			_phase = 1
		1:
			# Walk south into SouthSpur: 4 m/s for 1.5 s. The presence should ADVANCE.
			var before := _h.global_position
			_put(_p.global_position + Vector3(0, 0, -4.0 * delta), Vector3(0, 0, -4.0))
			_h.call("_process", delta)
			if _t > 1.5:
				_h_after_walk = _h.global_position
				_ok("it advances along the trail while the player walks",
					_h.global_position.distance_to(Vector3(-12.6, 0, 12.5)) > 1.5,
					"moved %.2f m from the entrance" % _h.global_position.distance_to(Vector3(-12.6, 0, 12.5)))
				_ok("…and is still well outside 2.5 m", _h.global_position.distance_to(_p.global_position) > 2.5)
				_ok("…and the drag loop is playing", (_h.get_node("Drag") as AudioStreamPlayer3D).playing)
				_t = 0.0
				_phase = 2
		2:
			# Stop: it stops.
			_put(_p.global_position, Vector3.ZERO)
			_h.call("_process", delta)
			if _t > 1.0:
				_ok("it STOPS when the player stops", _h.global_position.distance_to(_h_after_walk) < 0.05,
					"drift %.3f m" % _h.global_position.distance_to(_h_after_walk))
				_ok("…and the drag loop stops", not (_h.get_node("Drag") as AudioStreamPlayer3D).playing)
				_panic0 = _p.get_panic_ratio()
				_t = 0.0
				_phase = 3
		3:
			# Walk BACK toward it (out of a dead end): contact, +12, it drops back.
			var to := _h.global_position - _p.global_position
			to.y = 0.0
			_put(_p.global_position + to.normalized() * 4.0 * delta, to.normalized() * 4.0)
			_h.call("_process", delta)
			if int(_h.get("contacts")) >= 1 or _t > 6.0:
				_ok("walking back into it makes CONTACT", int(_h.get("contacts")) >= 1)
				_ok("…worth +12 panic", _p.get_panic_ratio() - _panic0 >= 12.0 / 50.0 - 0.01,
					"%.2f -> %.2f" % [_panic0, _p.get_panic_ratio()])
				_ok("…and it dropped back >= 5 m", _h.global_position.distance_to(_p.global_position) >= 5.0,
					"%.1f m" % _h.global_position.distance_to(_p.global_position))
				# The laugh.
				_lvl.set("_wing_visited", {"DarkCorridor": true, "Junction": true, "SouthSpur": true})
				_lvl.call("_fire_wing_laugh")
				var laugh := _lvl.get_node_or_null("WingLaugh") as AudioStreamPlayer3D
				_ok("the laugh plays from a wing room", laugh != null and laugh.playing)
				if laugh:
					var room := String(_lvl.call("_room_name_at", laugh.global_position))
					_ok("…one the player has NOT visited", room != "" and not (room in ["DarkCorridor", "Junction", "SouthSpur"]), room)
				_lvl.call("_fire_wing_laugh")
				_ok("…and only once", _lvl.get_tree().get_nodes_in_group("x").size() == 0 and _count_named(_lvl, "WingLaugh") <= 1)
				# The screamer, from SouthHall, torch off, far from the breaker.
				_put(Vector3(-26.0, 0.1, 7.7), Vector3.ZERO)
				_p.call("ai_look_at", Vector3(-30.0, 1.6, 7.7))
				_p.set("_panic", 0.0)
				_panic0 = _p.get_panic_ratio()
				_lvl.call("_fire_wing_screamer")
				var fig := _lvl.get_node_or_null("WingScreamer") as Node3D
				_ok("the screamer is a figure IN THE WORLD", fig != null)
				_ok("…>= 8 m from the breaker", _p.global_position.distance_to(Vector3(-59.85, 1.1, 16.5)) >= 8.0)
				_t = 0.0
				_phase = 4
		4:
			var fig := _lvl.get_node_or_null("WingScreamer") as Node3D
			if fig:
				_fig_seen = true
				var cam := _p.get_node("Camera3D") as Node3D
				_nearest = minf(_nearest, Vector2(fig.global_position.x - cam.global_position.x, fig.global_position.z - cam.global_position.z).length())
			# 2026-09-14 (Issue 208): the beat is now turn (0.45) + lunge (0.25) + hold (1.4) + a
			# flee of ~1.6 s — it must be SEEN, so it lives ~3.7 s and glows.
			if _t > 1.4 and fig and not _glow_checked:
				_glow_checked = true
				var q := fig.get_node_or_null("Figure") as MeshInstance3D
				var m := q.get_surface_override_material(0) as StandardMaterial3D if q else null
				_ok("it GLOWS (emission on, the torch is locked off in the wing)", m != null and m.emission_enabled and m.emission_energy_multiplier >= 1.0)
				_ok("...and carries a light", fig.get_node_or_null("LungerLight") != null)
				_ok("...and the camera is PINNED to it (input frozen, facing it)", bool(_p.call("is_input_frozen"))
					and (-(_p.get_node("Camera3D") as Node3D).global_transform.basis.z).dot((fig.global_position - _p.global_position).normalized()) > 0.8)
			if _t > 4.5:
				_ok("it lunged to arm's length (<= 1.0 m)", _fig_seen and _nearest <= 1.0, "%.2f m" % _nearest)
				_ok("…cost +15", _p.get_panic_ratio() - _panic0 >= 15.0 / 50.0 - 0.01, "%.2f" % _p.get_panic_ratio())
				_ok("…and is gone within ~4.5 s (held, then fled)", _lvl.get_node_or_null("WingScreamer") == null)
				_ok("…with NO fullscreen flash at any point", not _saw_black)
				_ok("…and control came back", not bool(_p.call("is_input_frozen")))
				_lvl.call("_fire_wing_screamer")
				_ok("…and only once", _lvl.get_node_or_null("WingScreamer") == null)
				# Lights: the presence sleeps.
				_lvl.call("_light_the_wing", true)
				_ok("the presence sleeps when the wing lights", not bool(_h.call("is_awake")) and not _h.visible)
				return _done()
	return false


func _count_named(n: Node, nm: String) -> int:
	var c := 0
	for ch in n.get_children():
		if ch.name.begins_with(nm):
			c += 1
	return c


func _done() -> bool:
	print("  %d checks, %d failed" % [_checks, _fails])
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
	return true
