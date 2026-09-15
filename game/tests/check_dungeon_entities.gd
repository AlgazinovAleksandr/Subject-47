extends SceneTree

# DUNGEON_NIGHTMARES.md §B10's hard constraints, as assertions.
#
# §B10 is explicitly "the double-jeopardy audit for this level" — every item on it
# is a rule this project has already broken once somewhere else and paid for. They
# are cheap to violate by accident in a later session (one enter_dark_zone(), one
# RandomAmbient.register_player()) and expensive to notice by playing, because the
# symptom is "the level feels unfair" rather than a crash.
#
# The bans, and what each one would cost:
#   NO DarkZone      +3/s for having the light off, in a level whose whole premise
#                    is that light is scarce and sometimes WRONG. Issue 18 verbatim.
#   NO standstill    the Hollow One's solution REQUIRES standing still to listen.
#   NO DreadZone     the silence must suppress decay with ZERO additive pressure,
#                    or it re-creates the Corridor Zone-C stacking problem.
#   NO RandomAmbient its blind 4 m pops are indistinguishable from this level's real
#                    positional tells, which is the ONE skill being tested.
#   NO Apparition    a HOLD apparition kills you for fleeing, dropped into a level
#                    built around walking away from a slow pursuer.
#   NO instant death (2026-09-12) — the hunter's contact is non-lethal, every statue and
#                    frame is non-lethal, the Hollow One and the beartraps are gone. The
#                    panic bar is the only death; check_dungeon_hunter.gd drives the beats.
#
# Usage: Godot --headless --path game --script res://tests/check_dungeon_entities.gd

const SEEDS := [101, 404, 707]

var _fails := 0
var _checks := 0
var _started := false
var _settle := 0
var _level: Node = null
var _seed_i := 0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_load(SEEDS[0])
		return false
	_settle += 1
	if _settle < 14:
		return false
	if _level == null:
		_level = current_scene
		if _level == null or not _level.has_method("get_gen"):
			print("  FAIL dungeon.tscn did not load, or dungeon.gd failed to parse")
			_fails += 1
			return _report()
		_audit(SEEDS[_seed_i])
		_seed_i += 1
		_level = null
		if _seed_i < SEEDS.size():
			_load(SEEDS[_seed_i])
			return false
		return _report()
	return false


func _load(s: int) -> void:
	_settle = 0
	var gs := root.get_node_or_null("GameState")
	if gs:
		gs.call("save_level_progress", 7, {"layout_seed": s, "content_seed": s * 31 + 7})
	change_scene_to_file("res://scenes/dungeon.tscn")


func _audit(s: int) -> void:
	var gen = _level.call("get_gen")

	# ⚠️ EVERY ASSERTION IN THIS FILE IS AN ABSENCE — "no DarkZone", "no DreadZone", "no
	# ApparitionDirector" — and an absence is trivially TRUE of a level that failed to build.
	# So the first thing asserted is that there IS a level: chambers, sconces and the entity
	# roster. Without this, a dungeon.gd that threw on the first line would print eleven
	# comfortable OKs per seed (workstream H2, 2026-08-17).
	# ⚠️ `rooms` is the generator's own emitted room list; `_chambers` is private. Reading a
	# property that does not exist returns null, and `null as Array` THROWS — which aborts
	# `_audit()` before every ban in this file, and a thrown test still exits 0 (Issue 45).
	var rooms: Variant = gen.get("rooms") if gen != null else null
	var chambers: int = (rooms as Array).size() if rooms is Array else 0
	var sconce_list: Variant = _level.call("get_sconces")
	var sconces: int = (sconce_list as Array).size() if sconce_list is Array else 0
	_ok("seed %d: the dungeon actually built" % s, chambers >= 9 and sconces == 7,
		"%d rooms, %d sconces" % [chambers, sconces])

	# ⚠️ ...AND A LIVE CONTROL, because an absence check can also stop looking. Add a real
	# `DarkZone` to the scene and require the same counter to see it: if `_count_script()`
	# ever stops matching — a moved script path, a renamed file, a subclass — every ban in
	# this file goes quietly green forever.
	var planted: Node = (load("res://scripts/dark_zone.gd") as GDScript).new()
	planted.name = "DarkZoneControl"
	_level.add_child(planted)
	var seen := _count_script(_level, load("res://scripts/dark_zone.gd"))
	_ok("seed %d CONTROL: a planted DarkZone IS counted" % s, seen == 1, "%d found" % seen)
	_level.remove_child(planted)
	planted.queue_free()

	# ── The banned zones, by TYPE not by name ──────────────────────────────────
	# Counted by script identity so a renamed node cannot hide one.
	var dark := _count_script(_level, load("res://scripts/dark_zone.gd"))
	var dread := _count_script(_level, load("res://scripts/dread_zone.gd"))
	_ok("seed %d: no DarkZone anywhere" % s, dark == 0, "%d found" % dark)
	_ok("seed %d: no DreadZone anywhere" % s, dread == 0, "%d found" % dread)

	# ── The banned player opt-ins ──────────────────────────────────────────────
	var p := _level.get_node_or_null("Player") as CharacterBody3D
	if p:
		# Read the private flags directly: the alternative is inferring them from
		# behaviour, which would take 4 s of standing still per seed.
		_ok("seed %d: standstill panic never enabled" % s,
			not bool(p.get("_standstill_panic_enabled")))
		_ok("seed %d: the flashlight is dead (the candle replaces it)" % s,
			not bool(p.call("is_flashlight_on")))

	# ── RandomAmbient is not registered ────────────────────────────────────────
	# ⚠️ The single most important implementation note in the design doc. It is a
	# GLOBAL autoload that keeps whatever player was last registered, so the check
	# is "does it point at OUR player", not "is it null".
	var ra := root.get_node_or_null("RandomAmbient")
	if ra and p:
		var registered = ra.get("_player")
		_ok("seed %d: RandomAmbient is not driving this level" % s,
			registered != p,
			"registered=%s" % ("our player" if registered == p else "not us"))

	# ── No ApparitionDirector ──────────────────────────────────────────────────
	var appar := _count_script(_level, load("res://scripts/apparition_director.gd"))
	_ok("seed %d: no ApparitionDirector" % s, appar == 0, "%d found" % appar)

	# ── The cut entities are GONE, by script identity ──────────────────────────
	var hollow := _count_script(_level, load("res://scripts/creature_hollow.gd"))
	_ok("seed %d: no Hollow One in the tree (cut 2026-09-12)" % s, hollow == 0, "%d found" % hollow)
	var traps := _count_script(_level, load("res://scripts/beartrap.gd"))
	_ok("seed %d: no beartrap in the tree (cut 2026-09-12)" % s, traps == 0, "%d found" % traps)

	# The spawn chamber and the bed chamber hold no resident statue.
	var bad := 0
	if gen.still_one_rooms.has(gen.spawn_room):
		bad += 1
	if gen.still_one_rooms.has(gen.bed_room):
		bad += 1
	_ok("seed %d: no entity in the spawn / bed chambers" % s, bad == 0, "%d violations" % bad)

	# ── NOTHING KILLS (2026-09-12) ─────────────────────────────────────────────
	var stalker_script := load("res://scripts/creature_stalker.gd")
	var frame_script := load("res://scripts/weeping_frame.gd")
	var lethal_statues := 0
	var statues := 0
	var lethal_frames := 0
	var frames := 0
	for n in _all_nodes(_level):
		if n.get_script() == stalker_script:
			statues += 1
			if bool(n.get("lethal")):
				lethal_statues += 1
		elif n.get_script() == frame_script:
			frames += 1
			if bool(n.get("lethal")):
				lethal_frames += 1
	_ok("seed %d: every Still One is non-lethal" % s, statues > 0 and lethal_statues == 0,
		"%d statues, %d lethal" % [statues, lethal_statues])
	_ok("seed %d: every Weeping Frame is non-lethal" % s, frames > 0 and lethal_frames == 0,
		"%d frames, %d lethal" % [frames, lethal_frames])

	# ── The hunter: the Parasite, non-lethal, below the player's walk speed ────
	# ⚠️ THE resolution of the level's central design problem (§B1 rule 1). If this
	# ever creeps above 4.0 the correct play becomes sprinting, which costs +6/s
	# panic with decay suppressed — the exact double jeopardy the whole level was
	# designed to avoid. Worth an assertion because it is one @export away.
	var hunter := _level.get_node_or_null("TheHunter")
	_ok("seed %d: the hunter exists" % s, hunter != null)
	if hunter:
		var cs: float = float(hunter.get("chase_speed"))
		_ok("seed %d: hunter chase speed %.1f is below the 4.0 walk" % [s, cs], cs < 4.0)
		_ok("seed %d: the hunter's contact is NON-lethal" % s, not bool(hunter.get("lethal_contact")))
		_ok("seed %d: the hunter wears the Parasite model" % s, str(hunter.get("model")) == "parasite")
		var players: Array = []
		_find_class(hunter, "AnimationPlayer", players)
		_ok("seed %d: the hunter built its animated model (not the capsule fallback)" % s,
			players.size() >= 1)
	_ok("seed %d: no TheMatron node remains" % s, _level.get_node_or_null("TheMatron") == null)

	# ── The hunter wakes at THREE sconces, through the shipping path ───────────
	var scs: Array = _level.call("get_sconces")
	var cand = _level.get("_candle")
	if cand and scs.size() >= 3:
		cand.set("burning", true)
		for i in range(3):
			_level.call("_on_sconce_interact", scs[i])
		_ok("seed %d: three sconces arm the hunter's window" % s,
			bool(_level.get("_matron_active_window")))

	# ── The room archetypes were built ─────────────────────────────────────────
	var handles: Dictionary = _level.call("room_handles")
	_ok("seed %d: every chamber got its archetype props" % s,
		handles.size() == (gen.chamber_names as Array).size(),
		"%d handles for %d chambers" % [handles.size(), (gen.chamber_names as Array).size()])

	# ── The map and its key ────────────────────────────────────────────────────
	_ok("seed %d: the M map action exists" % s, InputMap.has_action("map"))
	_ok("seed %d: the map UI is in the tree" % s, _level.call("get_map") != null)
	_ok("seed %d: the folded plan is in the Antechamber" % s,
		_level.get_node_or_null("MapPickup") != null)
	var chase_bus := AudioServer.get_bus_index("DungeonChase")
	_ok("seed %d: the chase bus exists (not the ducked Dungeon bus)" % s, chase_bus != -1)
	var cue := _level.get_node_or_null("ChaseCue")
	_ok("seed %d: the chase cue is on DungeonChase" % s,
		cue != null and str(cue.get("bus")) == "DungeonChase")

	# ── The audio bus exists and the heartbeat is NOT on it ────────────────────
	# The silence only works if your own pulse survives the duck.
	var bus := AudioServer.get_bus_index("Dungeon")
	_ok("seed %d: the Dungeon bus exists" % s, bus != -1)
	if p:
		var hb = p.get("_heartbeat_player")
		if hb != null:
			_ok("seed %d: the heartbeat is NOT on the duckable bus" % s,
				str(hb.bus) != "Dungeon", "bus=%s" % hb.bus)


func _all_nodes(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_all_nodes(c))
	return out


func _find_class(node: Node, cls: String, out: Array) -> void:
	if node.get_class() == cls:
		out.append(node)
	for c in node.get_children():
		_find_class(c, cls, out)


func _count_script(node: Node, script: Resource) -> int:
	var n := 0
	if node.get_script() == script:
		n += 1
	for c in node.get_children():
		n += _count_script(c, script)
	return n


func _report() -> bool:
	# ⚠️ Sample-size assertion — a level that fails to parse must not report PASS.
	if _checks < SEEDS.size() * 18:
		print("  FAIL only %d checks ran — did dungeon.gd fail to load?" % _checks)
		_fails += 1
	print("  %d checks, %d failed" % [_checks, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true
