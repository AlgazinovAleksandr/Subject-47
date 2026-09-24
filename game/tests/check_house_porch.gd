extends SceneTree

# THE PORCH PASS (2026-09-24), END TO END — the House's new digit-2 chain, driven through the
# shipping code paths: the real E ray (`ai_interact_target()` + `ai_interact()`), the real
# `AutoPlayer` walking the real capsule, and physics queries rather than object flags.
#
#   Godot --headless --path game --script res://tests/check_house_porch.gd
#
#   1. THE WITCH'S NOTE — read through the ray; journal-archived; NOT a safe note (the lamp
#      counter never sees it). Glimpse 1: she is in the yard beyond the GLASS, zero panic.
#   2. THE WINDOW — a capsule query and a real walk both stop at the pane; the forest scare
#      fires at FOREST_SCARE_DIST; ~0.6 s after the flash CLEARS the pane is gone (a physics
#      ray passes) and the real AutoPlayer walks out through the opening onto the deck.
#   3. THE FIRST PORCH VISIT — the scrawl fires ONCE (counted on screen), the painting is armed,
#      and the guaranteed tree-line ghost runs. E on the empty lunette re-thinks the thought.
#   4. THE FOREST CLOCK, MEASURED — panic slope on the deck, at the tree line and deep, and the
#      time from 0 to death at the deepest reachable point; suspended while input is frozen.
#   5. THE GHOSTS — spawned on cadence out in the trees; no collider, no ScaryObject, and zero
#      panic measured on the deck while three of them run across the view.
#   6. THE PAINTING -> THE HOLE -> THE FRUIT — falls when seen; the fruit is taken via the ray;
#      glimpse 2 appears behind the player.
#   7. THE GUILLOTINE — EMPTY -> LOADED -> CUT -> the cutters, every step through the ray;
#      glimpse 3 on the tree line; the carried line lists what is held.
#   8. SAVE / RESTORE — three snapshots (fruit held, fruit placed, all done) reloaded through the
#      level's own `_restore_progress()`: nothing replays, every state is forced.
#   9. THE FRIDGE CHAIN — cut with the restored cutters, through the ray.
#
# ⚠️ Disarmed for determinism, and said so: the random `ApparitionDirector` (a HOLD apparition
# mid-measurement would be a real death), the level's random blackout clock (+4 panic a flicker)
# and the global `RandomAmbient` scheduler (+5/+8/+12 at random) — the last two would corrupt the
# slope measurements. Nothing else is touched.

const AUTOPLAYER := preload("res://tests/autoplay/autoplayer.gd")
const SCENE := "res://scenes/level_2_1.tscn"

var _fails: Array[String] = []
var _checks := 0
var _l: Node = null
var _p: CharacterBody3D = null
var _gs: Node = null
var _measured: Array[String] = []


func _initialize() -> void:
	_run()


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _note(line: String) -> void:
	_measured.append(line)
	print("  MEASURED " + line)


func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await physics_frame


func _load(snapshot: Dictionary = {}) -> void:
	_gs = root.get_node("GameState")
	_gs.set("level_progress", {2: snapshot} if not snapshot.is_empty() else {})
	change_scene_to_file(SCENE)
	await _wait(1.6)
	_l = current_scene
	_p = _l.get_node("Player") as CharacterBody3D
	var dir := _l.get_node_or_null("ApparitionDirector")
	if dir:
		dir.queue_free()
	_l.set("_blackout_clock", 99999.0)
	# ⚠️ And the GLOBAL random-scare scheduler (+5 / +8 / +12 at random): measured, one +12 landed
	# inside a 2 s slope window and read as "+8.00 /s" at the deepest point. Test-only.
	var ra := root.get_node_or_null("RandomAmbient")
	if ra:
		ra.set_process(false)
	_p.set("_panic", 0.0)


func _stand(pos: Vector3, look: Vector3) -> void:
	_p.set("velocity", Vector3.ZERO)
	_p.global_position = pos
	_p.call("ai_look_at", look)


func _panic() -> float:
	return float(_p.get("_panic"))


# Count the red thought on screen right now (ScreenText puts each scrawl on its own label).
func _scrawls() -> int:
	var n := 0
	for c in _all(root, []):
		if c is Label and (c as Label).text == String(_l.get("PORCH_SCRAWL")) and (c as Label).is_visible_in_tree():
			n += 1
	return n


func _all(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		_all(c, out)
	return out


func _count_named(prefix: String) -> int:
	var n := 0
	for c in _l.get_children():
		if String(c.name).begins_with(prefix) and not c.is_queued_for_deletion():
			n += 1
	return n


# Walk the real player to `to`. True if it arrived.
func _walk(to: Vector3, max_sec: float = 10.0) -> bool:
	var ap := AUTOPLAYER.new(_p)
	var t0 := Time.get_ticks_msec()
	var ok := false
	while float(Time.get_ticks_msec() - t0) / 1000.0 < max_sec:
		if ap.step_toward(to):
			ok = true
			break
		if ap.stuck:
			break
		await physics_frame
	ap.stop()
	ap.release()
	return ok


# Press E at whatever the shipping ray finds, after aiming at `look` from where we stand.
func _press(look: Vector3) -> Node:
	_p.call("ai_look_at", look)
	await physics_frame
	var tgt: Node = _p.call("ai_interact_target")
	_p.call("ai_interact")
	return tgt


# Mean panic slope over `sec` seconds from `start`.
func _slope(start: float, sec: float) -> float:
	_p.set("_panic", start)
	var t0 := Time.get_ticks_msec()
	await physics_frame
	var p0 := _panic()
	var t_a := Time.get_ticks_msec()
	await _wait(sec)
	var dt := float(Time.get_ticks_msec() - t_a) / 1000.0 * Engine.time_scale
	return (_panic() - p0) / maxf(0.001, dt)


func _run() -> void:
	await _load()

	# ----------------------------------------------------------------- 1. the witch's note
	print("--- 1. the witch's note ---")
	var wn := _l.get_node_or_null("WitchNote") as Node3D
	_ok("the witch's note is on the Entry Hall table", wn != null)
	_stand(Vector3(0.6, 0.1, -1.4), wn.global_position)
	var tgt: Node = await _press(wn.global_position)
	_ok("the shipping ray reaches it and E opens it", tgt == wn and bool(root.get_node("NoteUI").get("is_open")), str(tgt))
	root.get_node("NoteUI").call("_close")
	await _wait(0.2)
	_ok("the level knows it was read", bool(_l.get("_witch_note_read")))
	var journal: Array = _gs.get("journal")
	var archived := false
	for e in journal:
		if str(e).contains("old woman"):
			archived = true
	_ok("…and it is archived in the journal (TAB)", archived)
	_ok("it is NOT a safe note — the lamp counter never saw it",
		(_l.get("_safe_notes_read") as Array).is_empty() and int(_l.get("SAFE_NOTES_TOTAL")) == 3)

	# Glimpse 1: in the living room, facing the (intact) window.
	_p.set("_panic", 0.0)
	_stand(Vector3(-4.5, 0.1, 6.0), Vector3(-9.0, 1.4, 6.0))
	await _wait(1.2)
	var w1 := _l.get_node_or_null("Witch1") as Node3D
	_ok("glimpse 1: she stands in the yard beyond the glass", w1 != null and w1.global_position.x < -14.0,
		str(w1.global_position.snappedf(0.1)) if w1 else "no figure")
	_ok("…and she costs nothing", _panic() < 0.05, "panic %.3f" % _panic())
	if w1:
		_ok("…a Watcher: no collider under her", w1.find_children("*", "CollisionObject3D", true, false).is_empty())

	# ----------------------------------------------------------------- 2. the window
	print("--- 2. the window ---")
	var win := _l.get_node("HouseWindow")
	var pane := win.call("pane_body") as StaticBody3D
	var space := _p.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	q.exclude = [_p.get_rid()]
	q.transform = Transform3D(Basis(), Vector3(-8.5, 0.95, 6.0))
	var hits := space.intersect_shape(q, 8)
	var pane_hit := false
	for h in hits:
		if h["collider"] == pane:
			pane_hit = true
	_ok("a player-sized capsule in the opening overlaps the PANE", pane_hit, "%d overlaps" % hits.size())
	# A real walk into it, the scare held off so the walk measures the pane and nothing else.
	_l.set("_forest_fired", true)
	_stand(Vector3(-5.5, 0.1, 6.0), Vector3(-11.0, 1.4, 6.0))
	await _walk(Vector3(-11.0, 0.1, 6.0), 4.0)
	_ok("a real walk into the window STOPS at the pane", _p.global_position.x > -8.2,
		"stopped at x = %.2f" % _p.global_position.x)
	_l.set("_forest_fired", false)
	_p.set("_panic", 0.0)
	_stand(Vector3(-5.5, 0.1, 6.0), Vector3(-11.0, 1.4, 6.0))
	# Up to the glass, as the player does. (AutoPlayer arrives 0.9 m short of its target, so the
	# target sits past FOREST_SCARE_DIST's edge at x = -7.0.)
	await _walk(Vector3(-8.0, 0.1, 6.0), 4.0)
	await _wait(0.2)
	_ok("the forest scare fires at the window", bool(_l.get("_forest_fired")))
	_ok("…and it costs FOREST_SCARE_PANIC (25), unchanged", _panic() > 20.0 and _panic() < 26.0,
		"%.1f" % _panic())
	_ok("…and the face replaced her: glimpse 1 is gone", _l.get_node_or_null("Witch1") == null)
	await _wait(0.5)
	_ok("the pane is still there UNDER the flash", not bool(win.call("is_broken")))
	await _wait(1.2)
	_ok("~0.6 s after the flash clears, the pane has burst", bool(win.call("is_broken")))
	var rq := PhysicsRayQueryParameters3D.create(Vector3(-7.4, 1.2, 6.0), Vector3(-11.5, 1.2, 6.0))
	rq.exclude = [_p.get_rid()]
	_ok("…a physics ray now passes where the pane was", space.intersect_ray(rq).is_empty())
	_p.set("_panic", 0.0)
	var out_ok: bool = await _walk(Vector3(-9.6, 0.1, 6.0), 6.0)
	_ok("the REAL AutoPlayer walks out through the opening onto the deck",
		out_ok and HouseOutdoors.on_deck(_p.global_position), "at %v" % _p.global_position.snappedf(0.01))

	# ----------------------------------------------------------------- 3. the first porch visit
	print("--- 3. the first porch visit ---")
	await _wait(2.3)
	_ok("the first porch visit is registered", bool(_l.get("_porch_visited")))
	_ok("…it arms the painting", bool(_l.get("_painting_armed")) and not bool(_l.get("_painting_fallen")))
	_ok("…and the thought is on screen, ONCE", _scrawls() == 1, "%d on screen" % _scrawls())
	# Turn to the yard for the guaranteed tree-line pass.
	_p.call("ai_look_at", Vector3(-20.0, 1.4, 6.0))
	var ghost_seen := false
	for i in range(80):
		await _wait(0.1)
		if _count_named("ForestGhost") > 0:
			ghost_seen = true
			break
	_ok("the guaranteed ghost runs along the tree line", ghost_seen,
		"%d spawned" % int(_l.get("_ghosts_spawned")))
	# E on the empty lunette, once the first thought has faded.
	await _wait(3.0)
	var g := _l.get_node("Guillotine") as Node3D
	var front := g.global_position + g.global_transform.basis.z * 1.25
	_stand(Vector3(front.x, 0.1, front.z), g.global_position + Vector3(0, 0.7, 0))
	var before := _scrawls()
	tgt = await _press(g.global_position + Vector3(0, 0.7, 0))
	await _wait(0.3)
	_ok("E on the EMPTY lunette (no fruit) re-thinks the thought", tgt == g and _scrawls() == before + 1,
		"target %s, scrawls %d -> %d" % [str(tgt), before, _scrawls()])
	_ok("…and loads nothing", String(g.call("state_name")) == "EMPTY")
	_ok("…and the prompt says so", String(g.call("prompt_text")).contains("empty"))
	await _wait(3.2)
	_p.call("ai_look_at", Vector3(-8.7, 1.0, 6.0))    # back toward the house
	_stand(Vector3(-9.5, 0.1, 4.2), Vector3(-9.5, 1.0, 8.0))
	await _wait(2.3)
	_ok("walking the deck again does NOT re-fire the first-visit thought", _scrawls() == 0,
		"%d on screen" % _scrawls())

	# ----------------------------------------------------------------- 4. the forest clock
	print("--- 4. the forest clock ---")
	var look_w := func(at: Vector3) -> void: _stand(at, at + Vector3(-5.0, -1.2, 0.3))
	look_w.call(Vector3(-10.0, 0.1, 4.5))
	var s_deck: float = await _slope(20.0, 2.0)
	_note("deck (-10.0, 4.5), d = 0: %.2f /s   (decay alone is -3.5)" % s_deck)
	_ok("ZERO clock on the deck: panic decays at the player's own rate", absf(s_deck + 3.5) < 0.35)
	look_w.call(Vector3(-12.6, 0.1, 6.0))
	var s_edge: float = await _slope(20.0, 2.0)
	_note("tree line (-12.6, 6.0), d = 0.6: net %+.2f /s   (expected ~+0.06)" % s_edge)
	_ok("at the tree line the bar HOLDS (net ~0)", absf(s_edge) < 0.35)
	look_w.call(Vector3(-32.0, 0.1, 5.8))
	var s_deep: float = await _slope(20.0, 2.0)
	_note("deep (-32.0, 5.8), d = 20: net %+.2f /s   (expected +2.0)" % s_deep)
	_ok("20 m in, net +2 /s", absf(s_deep - 2.0) < 0.35)
	look_w.call(Vector3(-39.3, 0.1, 5.8))
	var s_far: float = await _slope(20.0, 2.0)
	_note("deepest reachable (-39.3, 5.8), d = 27.3: net %+.2f /s   (capped at +2.0)" % s_far)
	_ok("past FOREST_DEEP the rate is capped", absf(s_far - 2.0) < 0.35)
	# Time from 0 to death at the deepest reachable point — in REAL time. ⚠️ Not on a scaled
	# clock: the first version ran this at Engine.time_scale 4 and measured 20.8 s against a
	# 1x slope of exactly +2.00 /s, i.e. the harness measuring its own clock. Stops at 45 so the
	# screamer never fires mid-test; the last 5 are projected at the measured rate.
	_p.set("_panic", 0.0)
	var t0 := Time.get_ticks_msec()
	while _panic() < 45.0 and float(Time.get_ticks_msec() - t0) / 1000.0 < 40.0:
		await physics_frame
	var game_s := float(Time.get_ticks_msec() - t0) / 1000.0
	var reached := _panic()
	_p.set("_panic", 0.0)
	var to_death := game_s * 50.0 / maxf(1.0, reached)
	_note("0 -> %.1f panic in %.1f s at the deepest point; projected 0 -> 50 (death): %.1f s" % [reached, game_s, to_death])
	_ok("about 25 s from calm to death deep in the forest", to_death > 22.0 and to_death < 28.0)
	# Suspended while input is frozen.
	_p.call("freeze_input")
	var s_frozen: float = await _slope(20.0, 1.5)
	_p.call("unfreeze_input")
	_note("deep, input frozen: %+.2f /s   (clock suspended -> decay only, -3.5)" % s_frozen)
	_ok("the clock is SUSPENDED while input is frozen", s_frozen < -3.0)
	_p.set("_panic", 0.0)

	# ----------------------------------------------------------------- 5. the ghosts
	print("--- 5. the ghosts ---")
	_l.set("_ghost_clock", 0.0)
	look_w.call(Vector3(-16.0, 0.1, 6.0))
	var spawned0 := int(_l.get("_ghosts_spawned"))
	var times: Array[float] = []
	var tg0 := Time.get_ticks_msec()
	Engine.time_scale = 4.0
	while float(Time.get_ticks_msec() - tg0) / 1000.0 * 4.0 < 40.0:
		_p.set("_panic", 0.0)
		var before_n := int(_l.get("_ghosts_spawned"))
		await physics_frame
		if int(_l.get("_ghosts_spawned")) > before_n:
			times.append(float(Time.get_ticks_msec() - tg0) / 1000.0 * 4.0)
	Engine.time_scale = 1.0
	var gaps: Array[float] = []
	for i in range(1, times.size()):
		gaps.append(times[i] - times[i - 1])
	_note("ghosts in 40 s of forest: %d, gaps %s" % [times.size(), str(gaps.map(func(x): return snappedf(x, 0.1)))])
	var in_band := not gaps.is_empty()
	for gp in gaps:
		if gp < 5.5 or gp > 11.0:
			in_band = false
	_ok("ghosts come on a 6-10 s cadence out in the trees", times.size() >= 4 and in_band)
	# Zero panic, structurally and measured: on the deck (clock 0), three ghosts in view.
	look_w.call(Vector3(-10.5, 0.1, 6.0))
	_p.set("_panic", 0.0)
	await physics_frame
	_l.call("_spawn_ghost", 0, Vector3(-19.0, 0, 2.0), Vector3(-19.0, 0, 10.0), _p)
	_l.call("_spawn_ghost", 1, Vector3(-17.0, 0, 9.0), Vector3(-17.0, 0, 2.0), _p)
	_l.call("_spawn_ghost", 2, Vector3(-28.0, 0, 3.0), Vector3(-28.0, 0, 9.0), _p)
	await _wait(0.2)
	var structural := true
	var live := 0
	for c in _l.get_children():
		if String(c.name).begins_with("ForestGhost"):
			live += 1
			if not c.find_children("*", "CollisionObject3D", true, false).is_empty():
				structural = false
	_ok("the ghosts have no collider (the gaze and interact rays pass through)", live >= 3 and structural,
		"%d live" % live)
	await _wait(2.0)
	_ok("three ghosts running across the view add ZERO panic", _panic() < 0.01, "panic %.3f" % _panic())

	# ----------------------------------------------------------------- 6. the painting, the fruit
	print("--- 6. the painting -> the hole -> the fruit ---")
	var painting := _l.find_child("FallingPainting", true, false) as Node3D   # under its ScaryObject
	var melon := _l.get_node("HouseWatermelon") as Node3D
	_stand(Vector3(0.85, 0.1, 17.6), Vector3(0.85, 1.5, 19.0))
	_ok("before it falls the fruit is inert (no prompt)", _p.call("ai_interact_target") != melon)
	_stand(Vector3(-0.7, 0.1, 17.4), painting.global_position)
	await _wait(0.8)
	_ok("the painting falls when seen at the lock", bool(_l.get("_painting_fallen")))
	_ok("…the hole is there", (_l.get_node("PlasterHole") as Node3D).visible)
	_stand(Vector3(0.85, 0.1, 17.7), melon.global_position)
	tgt = await _press(melon.global_position)
	await _wait(0.2)
	_ok("the shipping ray takes the watermelon", tgt == melon and String(_l.get("_melon_state")) == "held")
	_ok("the HUD carries it", String(_gs.get("carried_item")) == "watermelon", "'%s'" % _gs.get("carried_item"))
	await _wait(1.5)
	var w2 := _l.get_node_or_null("Witch2") as Node3D
	_ok("glimpse 2: she is at the far end of the Hallway, BEHIND you",
		w2 != null and w2.global_position.z < 8.0 and absf(w2.global_position.x) < 1.2,
		str(w2.global_position.snappedf(0.1)) if w2 else "no figure")
	_ok("…zero panic", _panic() < 0.05, "%.3f" % _panic())
	var snap_held: Dictionary = _l.call("save_progress")

	# ----------------------------------------------------------------- 7. the guillotine
	print("--- 7. the guillotine ---")
	_stand(Vector3(front.x, 0.1, front.z), g.global_position + Vector3(0, 0.7, 0))
	_ok("with the fruit in hand the prompt offers the lunette",
		String(g.call("prompt_text")).contains("watermelon"))
	tgt = await _press(g.global_position + Vector3(0, 0.7, 0))
	await _wait(0.4)
	_ok("E sets it in the lunette", String(g.call("state_name")) == "LOADED" and String(_l.get("_melon_state")) == "placed")
	_ok("…and it leaves the carried line", String(_gs.get("carried_item")) == "", "'%s'" % _gs.get("carried_item"))
	var snap_placed: Dictionary = _l.call("save_progress")
	_p.set("_panic", 0.0)
	tgt = await _press(g.global_position + Vector3(0, 0.7, 0))
	await _wait(1.2)
	_ok("E pulls the rope: the blade drops and the fruit is CUT", String(g.call("state_name")) == "CUT")
	var cut_panic := _panic()
	_ok("…no fail state and no panic from the machine itself", cut_panic < 0.05, "%.3f" % cut_panic)
	var halves := 0
	for c in g.get_children():
		if String(c.name).begins_with("MelonHalf"):
			halves += 1
	_ok("…two halves, flesh up", halves == 2, "%d" % halves)
	var cutters := g.call("cutters_node") as Node3D
	_ok("…and the bolt cutters lie in the basket", cutters != null)
	tgt = await _press(cutters.global_position if cutters else g.global_position)
	await _wait(0.3)
	_ok("E takes the cutters", bool(_l.get("_cutters_held")) and String(g.call("state_name")) == "DONE")
	_ok("the carried line lists them", String(_gs.get("carried_item")) == "bolt cutters", "'%s'" % _gs.get("carried_item"))
	_ok("the guillotine goes inert", not bool(g.call("can_interact")))
	_p.call("ai_look_at", Vector3(-18.0, 1.2, 5.0))
	var w3: Node3D = null
	for i in range(30):
		await _wait(0.1)
		w3 = _l.get_node_or_null("Witch3") as Node3D
		if w3:
			break
	_ok("glimpse 3: she watches from the tree line", w3 != null and w3.global_position.x < -15.0,
		str(w3.global_position.snappedf(0.1)) if w3 else "no figure")
	var snap_done: Dictionary = _l.call("save_progress")
	for k in ["window_broken", "porch_visited", "painting_armed", "painting_fallen", "melon_state",
			"witch_note", "witch_glimpses", "cutters_held"]:
		_ok("save_progress carries '%s'" % k, snap_done.has(k), str(snap_done.get(k)))
	_ok("…with the values this run reached",
		bool(snap_done["window_broken"]) and bool(snap_done["porch_visited"]) and bool(snap_done["painting_fallen"])
		and String(snap_done["melon_state"]) == "cut" and bool(snap_done["witch_note"])
		and (snap_done["witch_glimpses"] as Array).size() == 3 and bool(snap_done["cutters_held"]))

	# ----------------------------------------------------------------- 8. save / restore
	print("--- 8. save / restore ---")
	await _load(snap_held)
	var g2 := _l.get_node("Guillotine")
	_ok("restore 'held': the fruit is in hand and not in the wall",
		_l.get_node_or_null("HouseWatermelon") == null and bool(g2.get("melon_in_hand"))
		and String(_gs.get("carried_item")) == "watermelon", "'%s'" % _gs.get("carried_item"))
	_ok("…the window is broken silently", bool(_l.get_node("HouseWindow").call("is_broken"))
		and _l.get_node("HouseWindow").get_node_or_null("BurstAudio") == null)
	_ok("…the painting is on the floor, the hole open",
		bool(_l.get("_painting_fallen")) and (_l.find_child("FallingPainting", true, false) as Node3D).position.y < 0.3
		and (_l.get_node("PlasterHole") as Node3D).visible)
	await _load(snap_placed)
	_ok("restore 'placed': the fruit sits in the lunette", String(_l.get_node("Guillotine").call("state_name")) == "LOADED")
	await _load(snap_done)
	var g3 := _l.get_node("Guillotine")
	_ok("restore 'done': the guillotine is spent, the blade down, the cutters in hand",
		String(g3.call("state_name")) == "DONE" and not bool(g3.call("has_cutters"))
		and String(_gs.get("carried_item")) == "bolt cutters", "'%s'" % _gs.get("carried_item"))
	_ok("…the porch visit is remembered: no thought replays", bool(_l.get("_porch_visited")))
	_stand(Vector3(-9.6, 0.1, 5.5), Vector3(-10.35, 1.0, 7.75))
	await _wait(2.5)
	_ok("…standing on the deck again does not re-scrawl", _scrawls() == 0)
	var witches := _count_named("Witch1") + _count_named("Witch2") + _count_named("Witch3")
	_ok("…the witch does not come back (all three glimpses spent)", witches == 0, "%d figures" % witches)
	_ok("…nor does the forest scare (the window is spent)", _panic() < 1.0, "panic %.2f" % _panic())

	# ----------------------------------------------------------------- 9. the fridge chain
	print("--- 9. the fridge chain ---")
	var fridge := _l.get_node("Fridge") as Node3D
	var fwd := fridge.global_transform.basis.z
	_stand(fridge.global_position + Vector3(-1.4, 0.1, 0.0), fridge.global_position + Vector3(0, 1.0, 0))
	tgt = await _press(fridge.global_position + Vector3(0, 1.0, 0))
	await _wait(0.3)
	_ok("with the restored cutters, E through the ray cuts the fridge chain",
		tgt == fridge and not bool(fridge.call("is_chained")), str(tgt))
	_ok("…and the carried line clears", String(_gs.get("carried_item")) == "", "'%s'" % _gs.get("carried_item"))

	print("")
	print("--- MEASURED ---")
	for m in _measured:
		print("  " + m)
	print("%d checks, %d failed" % [_checks, _fails.size()])
	for f in _fails:
		print("  FAIL: " + f)
	print("RESULT: " + ("PASS" if _fails.is_empty() else "FAIL (%d)" % _fails.size()))
	quit(0 if _fails.is_empty() else 1)
