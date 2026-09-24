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
#   3. THE FIRST PORCH VISIT — ⭐ 2026-09-24 (c): the first step onto the deck ARMS THE PAINTING,
#      but 3 s on the deck NOT looking at the guillotine fires NO scrawl; a real look does, ONCE,
#      within ~0.5 s (measured). No tree-line ghost while the camera is on the guillotine; turned
#      west, it runs, and its world position is PROJECTED on screen and ray-checked for occlusion
#      (the fence hid the old lane). The frame starts BLADELESS and the blade is in the stump;
#      E on it says there is no blade. ⭐⭐ 2026-09-24 (d): the stump is in the FAR NORTH-WEST
#      CORNER (d 25.5) and HIDDEN: physics rays from the rail gap and from the forest's middle to
#      the blade stop on the one thick trunk (`HidingTrunk`), and a CONTROL ray with that trunk
#      excluded reaches the stump. The blade is ARTWORK on quads (never on a box face).
#   4. THE FOREST CLOCK, MEASURED — panic slope on the deck, at the tree line and deep, and the
#      time from 0 to death at the deepest reachable point; suspended while input is frozen.
#   5. THE GHOSTS — spawned on cadence out in the trees; no collider, no ScaryObject, and zero
#      panic measured on the deck while three of them run across the view.
#   6. THE PAINTING -> THE HOLE -> THE FRUIT — falls when seen; the fruit is taken via the ray;
#      ⭐ 2026-09-24 (d): NO witch appears (glimpse 2 is deleted — the house sightings are
#      `check_house_witch.gd`'s).
#   7. THE GUILLOTINE — the fruit set, the pull REFUSED without a blade; ⭐ THE REAL WALK from the
#      rail gap to the stump in the clearing and back (a grid A* round the level's own trunks,
#      driven by the real AutoPlayer), its panic cost measured from 0 (asserted survivable) and
#      from 25 (reported); the blade pulled out through the ray, carried, mounted through the
#      ray; the pull; the cutters ON THE DECK BOARDS (physics rays) taken through the ray;
#      glimpse 3 on the tree line; the carried line lists what is held.
#   8. SAVE / RESTORE — snapshots (fruit held, fruit placed, blade held, all done, plus a
#      blade-first snapshot that proves "either order") reloaded through the level's own
#      `_restore_progress()`: nothing replays, every state is forced — `blade_state` in all three
#      of its values.
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
func _scrawls(text: String = "") -> int:
	var want := text if text != "" else String(_l.get("PORCH_SCRAWL"))
	var n := 0
	for c in _all(root, []):
		if c is Label and (c as Label).text == want and (c as Label).is_visible_in_tree():
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


# ---------------------------------------------------------------- the walk to the stump
# ⭐ 2026-09-24 (c). A grid A* over the yard round the level's OWN trunks (`HouseOutdoors.trunks`,
# the seeded layout as built) and the stump, then line-of-sight smoothing — so the route follows
# whatever the seed produced, and the REAL AutoPlayer walks it with the real capsule.
const GRID := 0.5
const TRUNK_CLEAR := 1.0      # trunk r (<= 0.34) + capsule 0.4 + margin
# ⭐ 2026-09-24 (d): the thick trunk the stump hides behind (r 0.55) + capsule + margin.
const HIDE_CLEAR := HouseOutdoors.HIDE_TRUNK_R + 0.4 + 0.25

func _blocked(c: Vector2, trunks: Array, stump: Vector2) -> bool:
	if c.x > -12.3 or c.x < HouseOutdoors.YARD_X.x + 1.2 or c.y < HouseOutdoors.YARD_Z.x + 1.2 \
			or c.y > HouseOutdoors.YARD_Z.y - 1.2:
		return true
	if c.distance_to(stump) < 1.15:
		return true
	if c.distance_to(HouseOutdoors.HIDE_TRUNK) < HIDE_CLEAR:
		return true
	for t in trunks:
		if c.distance_to(t) < TRUNK_CLEAR:
			return true
	return false


func _seg_clear(a: Vector2, b: Vector2, trunks: Array, stump: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) / 0.2))
	for i in range(n + 1):
		var c := a.lerp(b, float(i) / maxf(1.0, float(n)))
		if c.distance_to(stump) < 1.1:
			return false
		if c.distance_to(HouseOutdoors.HIDE_TRUNK) < HIDE_CLEAR + 0.05:
			return false
		for t in trunks:
			if c.distance_to(t) < TRUNK_CLEAR + 0.05:
				return false
	return true


# From this cell can the player actually SEE the stump (eye height, layer 1, the stump's own solid
# counts as seeing it)? ⭐ 2026-09-24 (d): a cell 1.2–1.7 m from the stump can now be right behind
# the thick trunk, and the E ray from there would meet bark.
func _sees_stump(c: Vector2, stump: Vector2) -> bool:
	var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, 1.6, c.y), Vector3(stump.x, 0.7, stump.y))
	q.collision_mask = 1
	q.exclude = [_p.get_rid()]
	var hit := _p.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or String((hit["collider"] as Node).name) == "StumpBody"


# Waypoints (world, y = 0.1) from `from` to a free spot 1.2–1.7 m from the stump.
func _plan_to_stump(from: Vector2, stump: Vector2) -> Array:
	var trunks: Array = (_l.get_node("HouseOutdoors").get("trunks") as Array).duplicate()
	trunks.append_array(_l.get_node("HouseOutdoors").get("ring_trunks") as Array)
	var key := func(c: Vector2) -> Vector2i: return Vector2i(roundi(c.x / GRID), roundi(c.y / GRID))
	var start: Vector2i = key.call(from)
	var open: Array = [start]
	var came := {start: start}
	var g := {start: 0.0}
	var goal := Vector2i(999999, 0)
	var guard := 0
	while not open.is_empty() and guard < 40000:
		guard += 1
		var bi := 0
		var best := INF
		for i in range(open.size()):
			var f: float = float(g[open[i]]) + (Vector2(open[i]) * GRID).distance_to(stump)
			if f < best:
				best = f
				bi = i
		var cur: Vector2i = open[bi]
		open.remove_at(bi)
		var cw := Vector2(cur) * GRID
		var ds := cw.distance_to(stump)
		if ds >= 1.2 and ds <= 1.7 and _sees_stump(cw, stump):
			goal = cur
			break
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var nb := cur + Vector2i(dx, dz)
				var nw := Vector2(nb) * GRID
				if _blocked(nw, trunks, stump):
					continue
				var ng: float = float(g[cur]) + GRID * (1.4142 if dx != 0 and dz != 0 else 1.0)
				if not g.has(nb) or ng < float(g[nb]):
					g[nb] = ng
					came[nb] = cur
					if not open.has(nb):
						open.append(nb)
	if goal.x == 999999:
		return []
	var cells: Array = []
	var c: Vector2i = goal
	while c != start:
		cells.push_front(Vector2(c) * GRID)
		c = came[c]
	cells.push_front(from)
	# Smooth: from each kept point, jump to the furthest point still in the clear.
	var pts: Array = [cells[0]]
	var i := 0
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not _seg_clear(cells[i], cells[j], trunks, stump):
			j -= 1
		pts.append(cells[j])
		i = j
	var out: Array = []
	for pt in pts:
		out.append(Vector3(pt.x, 0.1, pt.y))
	return out


# Walk a route with the real AutoPlayer. Tracks panic WITHOUT letting it reach PANIC_MAX (the
# screamer would reload the scene mid-test): above 44 it is shifted down by 20 and the 20 is
# carried in `overflow`. Decay is a constant rate, so the shift is exact while the bar is > 0.
# Returns {ok, peak, end, deepest, secs}.
var _overflow := 0.0

func _walk_route(pts: Array, max_sec: float) -> Dictionary:
	var ap := AUTOPLAYER.new(_p)
	var t0 := Time.get_ticks_msec()
	var peak := _panic() + _overflow
	var deepest := 0.0
	var ok := true
	for w in pts:
		ap.reset_stuck()
		var arrived := false
		while float(Time.get_ticks_msec() - t0) / 1000.0 < max_sec:
			if ap.step_toward(w):
				arrived = true
				break
			if ap.stuck:
				break
			await physics_frame
			if _panic() > 44.0:
				_p.set("_panic", _panic() - 20.0)
				_overflow += 20.0
			peak = maxf(peak, _panic() + _overflow)
			deepest = maxf(deepest, HouseOutdoors.forest_depth(_p.global_position))
		if not arrived:
			ok = false
			print("    walk stopped short of %v at %v (stuck=%s)" % [w, _p.global_position.snappedf(0.01), ap.stuck])
			break
	ap.stop()
	ap.release()
	return {"ok": ok, "peak": peak, "end": _panic() + _overflow, "deepest": deepest,
		"secs": float(Time.get_ticks_msec() - t0) / 1000.0}


# Hold still (as a player pressing E does) while the clock keeps running; same overflow rule.
func _linger(sec: float) -> float:
	var peak := _panic() + _overflow
	var t0 := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < sec:
		await physics_frame
		if _panic() > 44.0:
			_p.set("_panic", _panic() - 20.0)
			_overflow += 20.0
		peak = maxf(peak, _panic() + _overflow)
	return peak


# Sample a running ghost every physics frame until it is gone: is its body's centre inside the
# camera's view (unproject + is_position_behind), and does a physics ray from the camera reach it
# (layer 1, the player excluded)? A figure is ~0.9 m wide, so three rays go out — to its centre and
# 0.3 m either side of it across the view — and it counts as SEEN if any one arrives: a 12 cm porch
# post crossing the centre does not hide it. It counts as HIDDEN BY THE PORCH only when all three are
# stopped and one of them by the fence or the porch's own body (screens, rail, posts, roof).
# Returns {n, on_screen, clear, seen, fence}.
func _sample_ghost(g: Node3D, h: float) -> Dictionary:
	var cam := _p.get_node("Camera3D") as Camera3D
	var vp := root.get_viewport().get_visible_rect().size
	var space := _p.get_world_3d().direct_space_state
	var out := {"n": 0, "on_screen": 0, "clear": 0, "fence": 0, "seen": 0}
	while is_instance_valid(g) and not g.is_queued_for_deletion():
		var a: float = float(g.call("alpha")) if g.has_method("alpha") else 1.0
		if a >= 0.3:
			var c := g.global_position + Vector3(0, h * 0.5, 0)
			out["n"] += 1
			var on := false
			if not cam.is_position_behind(c):
				var q2 := cam.unproject_position(c)
				on = q2.x >= 0.0 and q2.x <= vp.x and q2.y >= 0.0 and q2.y <= vp.y
			if on:
				out["on_screen"] += 1
			var side := cam.global_basis.x.normalized() * 0.3
			var any_clear := false
			var porch := false
			for pt in [c, c + side, c - side]:
				var rq := PhysicsRayQueryParameters3D.create(cam.global_position, pt)
				rq.collision_mask = 1
				rq.exclude = [_p.get_rid()]
				var hit := space.intersect_ray(rq)
				if hit.is_empty():
					any_clear = true
				elif String((hit["collider"] as Node).name) in ["YardFence", "PorchRailBody"]:
					porch = true
			if any_clear:
				out["clear"] += 1
				if on:
					out["seen"] += 1
			elif porch:
				out["fence"] += 1
		await physics_frame
	return out


func _run() -> void:
	await _load()

	# ----------------------------------------------------------------- 0. the user's sounds + note 1
	# ⭐ 2026-09-24 (b): the user's recordings must resolve to THEIR files, not to a stand-in or to
	# a same-named file in another folder (`shared/glass_break` shadowed the user's glass_break —
	# load_audio searches `shared` first — which is why it is `window_glass_break` now).
	print("--- 0. the user's sounds, the first note ---")
	for pair in [["dark_forest_soundtrack", "level_2_house/dark_forest_soundtrack.ogg"],
			["window_glass_break", "level_2_house/window_glass_break.wav"],
			["guillotine", "level_2_house/guillotine.mp3"],
			["watermelon_crack", "level_2_house/watermelon_crack.wav"],
			["ghost_sound", "level_2_house/ghost_sound.wav"],
			["witch_scream", "level_2_house/witch_scream.mp3"]]:
		var st: AudioStream = _gs.call("load_audio", String(pair[0]))
		_ok("load_audio('%s') is the user's file" % pair[0],
			st != null and st.resource_path.ends_with(String(pair[1])), st.resource_path if st else "null")
	var fn := _l.get_node_or_null("ForestNight")
	_ok("the night outside is the user's track, one non-positional player",
		fn is AudioStreamPlayer and (fn as AudioStreamPlayer).stream.resource_path.ends_with("dark_forest_soundtrack.ogg"))
	var n1 := _l.get_node_or_null("SafeNote_First") as Node3D
	_ok("the first note (digit 4) hangs on the Bedroom's north wall",
		n1 != null and bool(_l.call("_in_room", n1.global_position, "Bedroom")) and n1.global_position.z > 15.0,
		str(n1.global_position.snappedf(0.01)) if n1 else "missing")
	_ok("…and nothing is left in the Living Room by the old name", _l.get_node_or_null("SafeNote_Living") == null)

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
	var g := _l.get_node("Guillotine") as Node3D
	var gc := g.global_position + Vector3(0, float(_l.get("GUILLOTINE_LOOK_Y")), 0)
	var stump := _l.get_node_or_null("BladeStump") as Node3D
	await physics_frame
	# ⭐ 2026-09-24 (c): the painting is armed by the FIRST STEP onto the deck, not by the look.
	_ok("the first step onto the deck arms the painting", bool(_l.get("_painting_armed"))
		and not bool(_l.get("_painting_fallen")))
	var cam := _p.get_node("Camera3D") as Camera3D
	var dot0 := (-cam.global_basis.z).normalized().dot((gc - cam.global_position).normalized())
	# Stand there, as the walk left us (facing west out of the window), for 3 s — NOT looking at it.
	await _wait(3.0)
	_ok("3 s on the deck NOT looking at the guillotine fires NO scrawl (no dwell fallback)",
		not bool(_l.get("_porch_visited")) and _scrawls() == 0,
		"3-D dot to its centre %.2f (< %.2f), on deck %s" % [dot0, float(_l.get("GUILLOTINE_LOOK_DOT")),
			HouseOutdoors.on_deck(_p.global_position)])
	# The frame is bladeless; the blade is in the stump in the clearing.
	_ok("the guillotine starts WITHOUT its blade", not bool(g.call("has_blade"))
		and not (g.call("blade_node") as Node3D).visible)
	_ok("…the blade is in the stump in the FAR NORTH-WEST CORNER (d 25.5)", stump != null and bool(stump.call("has_blade"))
		and (stump.call("blade_node") as Node3D).visible
		and Vector2(stump.global_position.x, stump.global_position.z).distance_to(HouseOutdoors.BLADE_CLEARING) < 0.01
		and absf(HouseOutdoors.forest_depth(stump.global_position) - 25.5) < 0.01
		and stump.global_position.x < -36.0 and stump.global_position.z > 20.0,
		str(stump.global_position) if stump else "no stump")
	# ⭐⭐ 2026-09-24 (d): HIDDEN behind one thick trunk. Rays from the rail gap (three points across
	# it) and from the forest's middle to the blade (its centre and both ends) and to the stump's
	# top: with every OTHER trunk excluded, each must stop on `HidingTrunk`; a CONTROL ray with
	# HidingTrunk excluded too must reach the stump (layer 1 solid or layer 2 interact volume).
	if stump:
		var sp3 := _p.get_world_3d().direct_space_state
		var hide := _l.get_node("HouseOutdoors").get_node_or_null("HidingTrunk") as StaticBody3D
		var others := _l.get_node("HouseOutdoors").get_node_or_null("YardTrunks") as StaticBody3D
		_ok("the thick trunk exists (r %.2f, its own body)" % HouseOutdoors.HIDE_TRUNK_R, hide != null and others != null)
		var bl := stump.call("blade_node") as Node3D
		# ⚠️ Loaded at RUN time, never named statically: a class that references an autoload
		# (GameState) cannot compile while this SceneTree script compiles — the autoloads are not
		# registered yet — and the failed compile then breaks the level itself.
		var GUILL = load("res://scripts/house_guillotine.gd")
		var prof: Dictionary = GUILL.blade_profile()
		var bh: float = float(GUILL.BLADE_ART_W) / float(prof["aspect"]) if bool(prof.get("ok", false)) else 0.42
		var mid_y: float = float(GUILL.BLADE_TOP) - bh / 2.0
		var targets := {
			"blade centre": bl.global_transform * Vector3(0, mid_y, 0),
			"blade left end": bl.global_transform * Vector3(-0.22, mid_y, 0),
			"blade right end": bl.global_transform * Vector3(0.22, mid_y, 0),
			"stump top": stump.global_position + Vector3(0, float(stump.get("STUMP_H")), 0),
		}
		var eyes := {
			"rail gap z 5.1": Vector3(-12.0, 1.6, 5.1), "rail gap z 6.0": Vector3(-12.0, 1.6, 6.0),
			"rail gap z 6.9": Vector3(-12.0, 1.6, 6.9), "forest middle (-26, 6)": Vector3(-26.0, 1.6, 6.0),
		}
		var n_rays := 0
		var n_hidden := 0
		var n_control := 0
		var n_full_blocked := 0
		for en in eyes:
			for tn in targets:
				var e: Vector3 = eyes[en]
				var t: Vector3 = targets[tn]
				n_rays += 1
				var q1 := PhysicsRayQueryParameters3D.create(e, t)
				q1.collision_mask = 1 | 2
				q1.exclude = [_p.get_rid(), others.get_rid()]
				var h1 := sp3.intersect_ray(q1)
				if not h1.is_empty() and h1["collider"] == hide:
					n_hidden += 1
				else:
					print("    NOT hidden by the thick trunk: %s -> %s  (hit %s)" % [en, tn,
						str(h1.get("collider")) if not h1.is_empty() else "nothing"])
				var q2 := PhysicsRayQueryParameters3D.create(e, t)
				q2.collision_mask = 1 | 2
				q2.exclude = [_p.get_rid(), others.get_rid(), hide.get_rid()]
				var h2 := sp3.intersect_ray(q2)
				if not h2.is_empty() and (h2["collider"] == stump or String((h2["collider"] as Node).name) == "StumpBody"):
					n_control += 1
				# The whole scene (only the player excluded): blocked by SOMETHING.
				var q3 := PhysicsRayQueryParameters3D.create(e, t)
				q3.collision_mask = 1
				q3.exclude = [_p.get_rid()]
				if not sp3.intersect_ray(q3).is_empty():
					n_full_blocked += 1
		_note("hiding trunk: %d of %d rays (rail gap x3 + forest middle, to the blade's centre / ends and the stump top) stop on it; control (trunk excluded) reaches the stump on %d of %d; whole scene blocked %d of %d"
			% [n_hidden, n_rays, n_control, n_rays, n_full_blocked, n_rays])
		_ok("the THICK TRUNK hides the blade and the stump from the rail gap AND the forest's middle",
			n_rays == 16 and n_hidden == n_rays, "%d of %d" % [n_hidden, n_rays])
		_ok("…control: with that trunk excluded every ray REACHES the stump (the check can fail)",
			n_control == n_rays, "%d of %d" % [n_control, n_rays])
		# ⭐⭐ The blade is ARTWORK on quads, never on a box face (Issue 24).
		for owner_name in ["stump", "frame"]:
			var bn: Node3D = (stump.call("blade_node") if owner_name == "stump" else g.call("blade_node")) as Node3D
			var art_quads := 0
			var art_on_box := 0
			var emissive := 0
			var unlit := 0
			for mi in bn.find_children("*", "MeshInstance3D", true, false):
				var m := (mi as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
				var textured := m != null and m.albedo_texture != null \
					and m.albedo_texture.resource_path.ends_with("guillotine_blade.png")
				if textured and (mi as MeshInstance3D).mesh is QuadMesh:
					art_quads += 1
				if textured and (mi as MeshInstance3D).mesh is BoxMesh:
					art_on_box += 1
				if m and m.emission_enabled:
					emissive += 1
				if ((mi as MeshInstance3D).layers & 2) == 0:
					unlit += 1
			if ResourceLoader.exists(String(GUILL.BLADE_TEX)):
				_ok("the %s's blade carries guillotine_blade.png on QUADS (front + back), on no box face" % owner_name,
					art_quads >= 2 and art_on_box == 0, "%d quads, %d boxes" % [art_quads, art_on_box])
			else:
				print("    (guillotine_blade.png not present: the %s's blade is the fallback boxes)" % owner_name)
			_ok("…no emission on the %s's blade, and every part moonlit (render layer 2)" % owner_name,
				emissive == 0 and unlit == 0, "%d emissive, %d off layer 2" % [emissive, unlit])
	var trunks_near := 99.0
	for t in (_l.get_node("HouseOutdoors").get("trunks") as Array):
		trunks_near = minf(trunks_near, (t as Vector2).distance_to(HouseOutdoors.BLADE_CLEARING))
	_ok("…in a clearing: no SEEDED trunk within 3.5 m of it", trunks_near >= 3.5, "nearest trunk %.2f m" % trunks_near)
	# Physics, not flags: a ray straight down onto the stump's top meets its interact volume.
	if stump:
		var sq := PhysicsRayQueryParameters3D.create(stump.global_position + Vector3(0, 2.0, 0),
			stump.global_position + Vector3(0, 0.3, 0))
		sq.collision_mask = 2
		var sh := _p.get_world_3d().direct_space_state.intersect_ray(sq)
		_ok("…and a physics ray down onto the stump meets the blade's interact volume",
			not sh.is_empty() and sh["collider"] == stump)
	# Now LOOK at it.
	var t_look := Time.get_ticks_msec()
	_p.call("ai_look_at", gc)
	var fired_after := -1.0
	for i in range(60):
		await physics_frame
		if bool(_l.get("_porch_visited")):
			fired_after = float(Time.get_ticks_msec() - t_look) / 1000.0
			break
	_note("scrawl after the first real look at the guillotine: %.2f s (hold %.2f s)" % [fired_after,
		float(_l.get("GUILLOTINE_LOOK_HOLD"))])
	_ok("a real look at the guillotine fires the scrawl within ~0.5 s", fired_after >= 0.25 and fired_after <= 0.6,
		"%.2f s" % fired_after)
	await physics_frame
	_ok("…and the thought is on screen, ONCE", _scrawls() == 1, "%d on screen" % _scrawls())
	# ⭐ The guaranteed tree-line ghost waits for a look WEST — the camera on the guillotine is not
	# "looking at the yard" any more (it was: fwd.x -0.42 < -0.35, and the lane went behind the fence).
	await _wait(float(_l.get("PORCH_GHOST_DELAY")) + 0.8)
	_ok("no tree-line ghost while the camera is on the guillotine", int(_l.get("_ghosts_spawned")) == 0
		and _count_named("ForestGhost") == 0, "%d spawned" % int(_l.get("_ghosts_spawned")))
	_p.call("ai_look_at", Vector3(-20.0, 1.4, 6.0))
	var ghost: Node3D = null
	for i in range(20):
		await physics_frame
		for c in _l.get_children():
			if String(c.name).begins_with("ForestGhost") and not c.is_queued_for_deletion():
				ghost = c
		if ghost:
			break
	_ok("turned west, the guaranteed ghost runs along the tree line", ghost != null
		and absf(ghost.global_position.x - float(_l.get("TREE_LINE_GHOST_X"))) < 0.2,
		str(ghost.global_position.snappedf(0.1)) if ghost else "none")
	if ghost:
		var vis: Dictionary = await _sample_ghost(ghost, 1.75)
		var frac := float(vis["seen"]) / maxf(1.0, float(vis["n"]))
		_note("tree-line ghost from the deck: %d frames sampled, %d on screen, %d unoccluded, %d SEEN (%.0f %%), %d hidden by the porch/fence"
			% [vis["n"], vis["on_screen"], vis["clear"], vis["seen"], frac * 100.0, vis["fence"]])
		_ok("…a meaningful sample of its run (>= 30 frames)", int(vis["n"]) >= 30, "%d" % vis["n"])
		_ok("…never hidden by the fence or the porch's own screens", int(vis["fence"]) == 0, "%d frames" % vis["fence"])
		_ok("…on screen AND unoccluded for most of its run (>= 60 %)", frac >= 0.6, "%.0f %%" % (frac * 100.0))
	# E on the frame with no blade and nothing in hand, once the first thought has faded.
	await _wait(1.0)
	var front := g.global_position + g.global_transform.basis.z * 1.25
	_stand(Vector3(front.x, 0.1, front.z), g.global_position + Vector3(0, 0.7, 0))
	var blade_txt := String(_l.get("BLADE_SCRAWL"))
	var before := _scrawls(blade_txt)
	tgt = await _press(g.global_position + Vector3(0, 0.7, 0))
	await _wait(0.3)
	_ok("E on the BLADELESS frame thinks WHERE IS THE BLADE?", tgt == g and _scrawls(blade_txt) == before + 1,
		"target %s, scrawls %d -> %d" % [str(tgt), before, _scrawls(blade_txt)])
	_ok("…and loads nothing", String(g.call("state_name")) == "EMPTY")
	_ok("…and the prompt says so", String(g.call("prompt_text")).contains("no blade"), String(g.call("prompt_text")))
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
	# ⭐ 2026-09-24 (d): glimpse 2 is DELETED — taking the fruit brings no witch and no scream.
	var witch_figs := 0
	for i in range(30):
		await _wait(0.05)
		for c in _l.get_children():
			if c is Watcher and String(c.name).begins_with("Witch") and not c.is_queued_for_deletion():
				witch_figs += 1
	_ok("taking the fruit spawns NO witch (glimpse 2 is gone) and no scream",
		witch_figs == 0 and _l.get_node_or_null("WitchScream") == null and _p.call("is_input_frozen") != true,
		"%d witch-frames" % witch_figs)
	var snap_held: Dictionary = _l.call("save_progress")

	# ----------------------------------------------------------------- 7. the guillotine
	print("--- 7. the guillotine ---")
	_stand(Vector3(front.x, 0.1, front.z), g.global_position + Vector3(0, 0.7, 0))
	_ok("with the fruit in hand the prompt offers the lunette (no blade needed for that)",
		String(g.call("prompt_text")).contains("watermelon"), String(g.call("prompt_text")))
	tgt = await _press(g.global_position + Vector3(0, 0.7, 0))
	await _wait(0.4)
	_ok("E sets it in the lunette", String(g.call("state_name")) == "LOADED" and String(_l.get("_melon_state")) == "placed")
	_ok("…and it leaves the carried line", String(_gs.get("carried_item")) == "", "'%s'" % _gs.get("carried_item"))
	var snap_placed: Dictionary = _l.call("save_progress")
	# ⭐ LOADED WITHOUT A BLADE: the pull is refused — nothing drops, nothing is cut.
	_ok("loaded but bladeless, the prompt says there is no blade", String(g.call("prompt_text")).contains("no blade"),
		String(g.call("prompt_text")))
	var blade_before := _scrawls(blade_txt)
	tgt = await _press(g.global_position + Vector3(0, 0.7, 0))
	await _wait(1.2)
	_ok("E on the loaded, BLADELESS frame REFUSES the pull: no cut", tgt == g
		and String(g.call("state_name")) == "LOADED" and String(_l.get("_melon_state")) == "placed"
		and (g.call("halves") as Array).is_empty() and g.call("cutters_node") == null)
	_ok("…and thinks WHERE IS THE BLADE?", _scrawls(blade_txt) == blade_before + 1,
		"%d -> %d" % [blade_before, _scrawls(blade_txt)])

	# ⭐⭐ THE WALK: from the rail gap to the stump and back, the real AutoPlayer round the real
	# trunks. Twice: from 25 panic (just after the window scare — reported, not asserted) without
	# pulling, then from 0 with the pull through the shipping ray (asserted survivable).
	print("--- 7b. the walk to the stump and back ---")
	var sp := Vector2(stump.global_position.x, stump.global_position.z)
	var gap := Vector3(-12.6, 0.1, 6.0)
	var deck_back := Vector3(-10.3, 0.1, 6.0)
	var route: Array = _plan_to_stump(Vector2(gap.x, gap.z), sp)
	var route_len := 0.0
	for i in range(1, route.size()):
		route_len += (route[i] as Vector3).distance_to(route[i - 1])
	_ok("a walkable route to the stump exists round the seeded trunks", route.size() >= 2,
		"%d waypoints, %.1f m from the rail gap" % [route.size(), route_len])
	var back: Array = route.duplicate()
	back.reverse()
	back.append(deck_back)
	var trips := {}
	var heard := ""
	for start_panic in [25.0, 0.0]:
		_stand(Vector3(-11.0, 0.1, 6.0), Vector3(-20.0, 1.4, 6.0))
		await _wait(0.3)
		_overflow = 0.0
		_p.set("_panic", start_panic)
		var out: Dictionary = await _walk_route(route, 40.0)
		var at_stump := Vector2(_p.global_position.x, _p.global_position.z).distance_to(sp)
		_p.call("ai_look_at", stump.global_position + Vector3(0, 0.7, 0))
		await physics_frame
		var st_tgt: Node = _p.call("ai_interact_target")
		var pulled_here := false
		if start_panic == 0.0:
			_ok("from %.1f m, the shipping ray finds the blade in the stump" % at_stump, st_tgt == stump, str(st_tgt))
			_ok("…and the prompt says what E does", st_tgt != null and String(st_tgt.call("prompt_text")).contains("blade"))
			_p.call("ai_interact")
			pulled_here = true
			await physics_frame
			var bp := stump.get_node_or_null("BladePull") as AudioStreamPlayer3D
			heard = bp.stream.resource_path if bp and bp.stream and bp.playing else ""
		var linger: float = await _linger(0.6)     # the press, as a person makes it
		var home: Dictionary = await _walk_route(back, 40.0)
		await physics_frame
		var peak := maxf(maxf(float(out["peak"]), linger), float(home["peak"]))
		trips[start_panic] = {"ok": bool(out["ok"]) and bool(home["ok"]), "peak": peak,
			"end": float(home["end"]), "deepest": maxf(float(out["deepest"]), float(home["deepest"])),
			"secs": float(out["secs"]) + float(home["secs"]) + 0.6, "pulled": pulled_here}
		_note("round trip rail gap -> stump -> deck from %2.0f panic: peak %.1f of 50 (cost %+.1f), back on the deck at %.1f, deepest d = %.1f m, %.1f s walking, route %.1f m each way"
			% [start_panic, peak, peak - start_panic, float(home["end"]), trips[start_panic]["deepest"],
				trips[start_panic]["secs"], route_len])
		_ok("the round trip from %.0f was actually walked, out and back to the deck" % start_panic,
			bool(trips[start_panic]["ok"]) and HouseOutdoors.on_deck(_p.global_position),
			"at %v" % _p.global_position.snappedf(0.01))
		_overflow = 0.0
	_ok("from CALM (0) the round trip is survivable (peak < 50)", float(trips[0.0]["peak"]) < 50.0,
		"peak %.1f" % float(trips[0.0]["peak"]))
	_ok("…the blade came out of the stump", not bool(stump.call("has_blade"))
		and not (stump.call("blade_node") as Node3D).visible and String(_l.get("_blade_state")) == "held")
	_ok("…the pull was HEARD at the stump (blade_pull, playing there)", heard.ends_with("blade_pull.wav"), heard)
	_ok("…and the carried line lists it", String(_gs.get("carried_item")).contains("guillotine blade"),
		"'%s'" % _gs.get("carried_item"))
	if stump:
		var sq2 := PhysicsRayQueryParameters3D.create(stump.global_position + Vector3(0, 2.0, 0),
			stump.global_position + Vector3(0, 0.3, 0))
		sq2.collision_mask = 2
		_ok("…and the stump's interact volume is gone (physics ray)",
			_p.get_world_3d().direct_space_state.intersect_ray(sq2).is_empty())
	var snap_blade_held: Dictionary = _l.call("save_progress")
	_p.set("_panic", 0.0)

	# Mount it, through the ray.
	_stand(Vector3(front.x, 0.1, front.z), g.global_position + Vector3(0, 0.7, 0))
	_ok("with the blade in hand the prompt offers to mount it", String(g.call("prompt_text")).contains("Mount"),
		String(g.call("prompt_text")))
	tgt = await _press(g.global_position + Vector3(0, 0.7, 0))
	await _wait(0.8)
	var bn := g.call("blade_node") as Node3D
	_ok("E mounts the blade: it hangs in the frame", tgt == g and bool(g.call("has_blade")) and bn.visible
		and bn.global_position.y > 1.8 and String(_l.get("_blade_state")) == "mounted")
	_ok("…and it leaves the carried line", not String(_gs.get("carried_item")).contains("blade"),
		"'%s'" % _gs.get("carried_item"))
	_ok("…the prompt is the rope now", String(g.call("prompt_text")).contains("rope"), String(g.call("prompt_text")))
	_p.set("_panic", 0.0)
	tgt = await _press(g.global_position + Vector3(0, 0.7, 0))
	await _wait(1.2)
	_ok("E pulls the rope: the blade drops and the fruit is CUT", String(g.call("state_name")) == "CUT")
	var cut_panic := _panic()
	_ok("…no fail state and no panic from the machine itself", cut_panic < 0.05, "%.3f" % cut_panic)
	var halves := g.call("halves") as Array
	_ok("…two halves, flesh up", halves.size() == 2, "%d" % halves.size())
	var on_boards := 0
	for h in halves:
		if (h as Node3D).global_position.y < 0.25:
			on_boards += 1
	_ok("…one of them on the deck boards", on_boards == 1, "%d below 0.25 m" % on_boards)
	var cutters := g.call("cutters_node") as Node3D
	_ok("…and the bolt cutters lie in front of it", cutters != null)
	var space2 := _p.get_world_3d().direct_space_state
	if cutters:
		# ON THE FLOOR, by physics: straight down from above them, the first layer-2 thing is the
		# cutters, and under them (layer 1, the frame excluded) the deck — within a few cm.
		var top := cutters.global_position + Vector3(0, 1.0, 0)
		var c2 := PhysicsRayQueryParameters3D.create(top, cutters.global_position - Vector3(0, 0.5, 0))
		c2.collision_mask = 2
		var ch := space2.intersect_ray(c2)
		var d1 := PhysicsRayQueryParameters3D.create(top, cutters.global_position - Vector3(0, 0.5, 0))
		d1.collision_mask = 1
		d1.exclude = [g.get_rid(), _p.get_rid()]
		var dh := space2.intersect_ray(d1)
		var floor_y: float = (dh["position"] as Vector3).y if not dh.is_empty() else -99.0
		_ok("the cutters are ON THE DECK: a ray down meets them, and the boards right under them",
			not ch.is_empty() and ch["collider"] == cutters and absf(floor_y) < 0.02
			and cutters.global_position.y - floor_y < 0.05 and HouseOutdoors.on_deck(cutters.global_position),
			"cutters y %.3f, floor y %.3f, collider %s" % [cutters.global_position.y, floor_y,
				str(ch.get("collider")) if not ch.is_empty() else "none"])
	# No basket: nothing named one, and a ray down where it stood meets the deck, not a wicker box.
	var old_basket := g.global_transform * Vector3(0, 0.6, 0.46)
	var bq := PhysicsRayQueryParameters3D.create(old_basket, old_basket - Vector3(0, 1.0, 0))
	bq.collision_mask = 1
	bq.exclude = [_p.get_rid()]
	var bh := space2.intersect_ray(bq)
	_ok("there is NO basket: nothing named one, and a ray where it stood meets the deck",
		g.find_child("Basket*", true, false) == null and not bh.is_empty() and bh["collider"] != g
		and absf((bh["position"] as Vector3).y) < 0.02,
		str(bh.get("collider")) if not bh.is_empty() else "no hit")
	_stand(Vector3(front.x, 0.1, front.z), cutters.global_position if cutters else g.global_position)
	tgt = await _press(cutters.global_position if cutters else g.global_position)
	var tgt_name := String(tgt.name) if is_instance_valid(tgt) else "none"
	await _wait(0.3)
	_ok("the shipping ray takes the cutters off the floor", tgt == cutters and bool(_l.get("_cutters_held"))
		and String(g.call("state_name")) == "DONE", tgt_name)
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
			"witch_note", "witch_glimpses", "cutters_held", "blade_state"]:
		_ok("save_progress carries '%s'" % k, snap_done.has(k), str(snap_done.get(k)))
	_ok("…with the values this run reached",
		bool(snap_done["window_broken"]) and bool(snap_done["porch_visited"]) and bool(snap_done["painting_fallen"])
		and String(snap_done["melon_state"]) == "cut" and bool(snap_done["witch_note"])
		and (snap_done["witch_glimpses"] as Array).size() == 2
		and (snap_done["witch_glimpses"] as Array).has(1) and (snap_done["witch_glimpses"] as Array).has(3) and bool(snap_done["cutters_held"])
		and String(snap_done["blade_state"]) == "mounted")

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
	var st2 := _l.get_node("BladeStump")
	_ok("…blade_state 'stump': the blade is still in the stump, the frame bladeless",
		String(_l.get("_blade_state")) == "stump" and bool(st2.call("has_blade"))
		and not bool(g2.call("has_blade")) and not (g2.call("blade_node") as Node3D).visible)
	await _load(snap_placed)
	_ok("restore 'placed': the fruit sits in the lunette", String(_l.get_node("Guillotine").call("state_name")) == "LOADED")
	await _load(snap_blade_held)
	var g4 := _l.get_node("Guillotine")
	var st4 := _l.get_node("BladeStump") as Node3D
	var sq4 := PhysicsRayQueryParameters3D.create(st4.global_position + Vector3(0, 2.0, 0),
		st4.global_position + Vector3(0, 0.3, 0))
	sq4.collision_mask = 2
	await physics_frame
	_ok("restore blade_state 'held': the stump is EMPTY (no blade, no interact volume by ray)",
		not bool(st4.call("has_blade")) and not (st4.call("blade_node") as Node3D).visible
		and _p.get_world_3d().direct_space_state.intersect_ray(sq4).is_empty())
	_ok("…the blade is carried, silently", String(_gs.get("carried_item")).contains("guillotine blade")
		and bool(g4.get("blade_in_hand")) and st4.get_node_or_null("BladePull") == null,
		"'%s'" % _gs.get("carried_item"))
	_ok("…and the frame offers to mount it, the fruit still in the lunette",
		String(g4.call("prompt_text")).contains("Mount") and String(g4.call("state_name")) == "LOADED")
	# ⭐ EITHER ORDER: a snapshot with the blade mounted FIRST and the fruit still in the wall.
	var snap_blade_first := snap_held.duplicate(true)
	snap_blade_first["melon_state"] = "wall"
	snap_blade_first["blade_state"] = "mounted"
	await _load(snap_blade_first)
	var g5 := _l.get_node("Guillotine") as Node3D
	_ok("restore blade_state 'mounted' (blade first): it hangs in the frame, the stump is empty",
		bool(g5.call("has_blade")) and (g5.call("blade_node") as Node3D).visible
		and not bool(_l.get_node("BladeStump").call("has_blade")) and String(g5.call("state_name")) == "EMPTY")
	var f5 := g5.global_position + g5.global_transform.basis.z * 1.25
	_stand(Vector3(f5.x, 0.1, f5.z), g5.global_position + Vector3(0, 0.7, 0))
	await _wait(0.2)
	_ok("…the empty lunette, bladed, asks for something to put there", String(g5.call("prompt_text")).contains("empty"),
		String(g5.call("prompt_text")))
	var th0 := _scrawls()
	tgt = await _press(g5.global_position + Vector3(0, 0.7, 0))
	await _wait(0.3)
	_ok("…E there thinks SHALL I PUT SOMETHING THERE? (not the blade line)", tgt == g5 and _scrawls() == th0 + 1
		and _scrawls(String(_l.get("BLADE_SCRAWL"))) == 0)
	var melon5 := _l.get_node("HouseWatermelon") as Node3D
	_stand(Vector3(0.85, 0.1, 17.7), melon5.global_position)
	tgt = await _press(melon5.global_position)
	await _wait(0.2)
	_stand(Vector3(f5.x, 0.1, f5.z), g5.global_position + Vector3(0, 0.7, 0))
	tgt = await _press(g5.global_position + Vector3(0, 0.7, 0))
	await _wait(0.4)
	tgt = await _press(g5.global_position + Vector3(0, 0.7, 0))
	await _wait(1.2)
	_ok("…blade first, then the fruit, then the rope: CUT (either order works)",
		String(g5.call("state_name")) == "CUT" and g5.call("cutters_node") != null)
	await _load(snap_done)
	var g3 := _l.get_node("Guillotine")
	_ok("restore 'done': the guillotine is spent, the blade down, the cutters in hand",
		String(g3.call("state_name")) == "DONE" and not bool(g3.call("has_cutters"))
		and String(_gs.get("carried_item")) == "bolt cutters", "'%s'" % _gs.get("carried_item"))
	_ok("…blade_state 'mounted': the blade is in the frame (down), the stump empty",
		bool(g3.call("has_blade")) and (g3.call("blade_node") as Node3D).visible
		and not bool(_l.get_node("BladeStump").call("has_blade")))
	_ok("…the porch visit is remembered: no thought replays", bool(_l.get("_porch_visited")))
	_stand(Vector3(-9.6, 0.1, 5.5), Vector3(-10.35, 1.0, 7.75))
	await _wait(2.5)
	_ok("…standing on the deck again does not re-scrawl", _scrawls() == 0)
	var witches := _count_named("Witch1") + _count_named("Witch3")
	_ok("…the witch does not come back (both glimpses spent)", witches == 0, "%d figures" % witches)
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
