extends SceneTree

# 200-seed stress test of DungeonGen (THE NIGHTMARE's procedural layout).
#
# Pure data, no scene. This exists for the reason check_maze_gen.gd exists: the
# generator's output is only ever seen through a level the player walks around in,
# so a scene smoke test exercises ONE seed and asserts nothing about the other
# 4 billion. A procedural generator that CAN emit a broken dungeon eventually WILL.
#
# What it asserts (DUNGEON_NIGHTMARES.md §B14):
#   - every room is reachable from the spawn (BFS over the doorway graph)
#   - chamber count is in range
#   - no two rooms overlap (RoomBuilder's hard constraint, Issue 23)
#   - every doorway lies on a genuinely SHARED edge between two rooms
#   - the seven sconces are in seven DISTINCT chambers
#   - the bed is far enough from the spawn to be a walk
#   - at least one CYCLE exists (a spanning tree makes a chaser unbeatable)
#   - no sconce and no frame sits on a wall that carries a doorway
#   - (2026-09-12) every chamber has a KIND, exactly one larder / well / chapel, the larder is
#     a sconce chamber, the sconces satisfy the spacing rule, and there are NO beartraps and
#     NO sealed alcove any more (the Hollow One is cut; the traps were a death path)
#
# ⚠️ It also asserts its own SAMPLE SIZE. check_apparition_clearance.gd reported a
# cheerful "0 spawns checked ... PASS" when the script under test failed to compile;
# a green run on zero samples is the most dangerous result a test can give.
#
# Usage: Godot --headless --path game --script res://tests/check_dungeon_gen.gd

const RUNS := 200

var _fails := 0
var _checked := 0
var _gen_script: GDScript = null

# Aggregates, printed so a human can see the shape of what shipped rather than just
# a green light.
var _rooms_min := 99999
var _rooms_max := -1
var _rooms_total := 0
var _cycles_total := 0
var _bed_dist_min := 99999
var _sealed_overrides := 0
var _sconce_short := 0
var _relaxed_total := 0
var _gap_min := 99
var _kind_counts: Dictionary = {}


func _fail(msg: String) -> void:
	print("  FAIL %s" % msg)
	_fails += 1


func _initialize() -> void:
	# Loaded at runtime rather than named as a class_name: naming a game class in a
	# SceneTree test forces it to compile before the autoloads exist.
	_gen_script = load("res://scripts/dungeon_gen.gd")


func _process(_delta: float) -> bool:
	if _gen_script == null:
		print("  FAIL could not load res://scripts/dungeon_gen.gd")
		_report()
		return true

	for i in range(RUNS):
		var g = _gen_script.new()
		if g == null:
			_fail("DungeonGen.new() returned null at run %d — did it fail to compile?" % i)
			break
		# Derived, not random: a failure is reproducible from its seed alone.
		g.generate(i * 7919 + 13, i * 104729 + 7)
		_check_one(i, g)

	_report()
	return true


func _check_one(seed_i: int, g) -> void:
	# D1 (2026-09-13): eight candle caches, in eight different chambers.
	var caches: Array = g.candle_rooms
	if caches.size() != int(g.CANDLE_CACHES) or caches.size() < 8:
		_fail("seed %d: %d candle caches (want CANDLE_CACHES = %d, >= 8)" % [seed_i, caches.size(), int(g.CANDLE_CACHES)])
	var uniq := {}
	for c in caches:
		uniq[c] = true
	if uniq.size() != caches.size():
		_fail("seed %d: candle caches share a room" % seed_i)
	_checked += 1
	var rooms: Array = g.rooms
	var doors: Array = g.doorways

	if rooms.size() < 8:
		_fail("seed=%d only %d rooms" % [seed_i, rooms.size()])
		return
	_rooms_min = mini(_rooms_min, rooms.size())
	_rooms_max = maxi(_rooms_max, rooms.size())
	_rooms_total += rooms.size()

	# --- chamber count ---------------------------------------------------------
	var chambers: Array = g.chamber_names
	if chambers.size() < 9 or chambers.size() > 16:
		_fail("seed=%d chamber count %d outside 9..16" % [seed_i, chambers.size()])

	# --- no two rooms overlap --------------------------------------------------
	# Rooms in a ROOMS table must ABUT, never OVERLAP, or their floor and ceiling
	# slabs coincide and z-fight (Issue 23). The lattice should make this impossible
	# by construction; assert it anyway, because "impossible by construction" is
	# what everyone said about the Lab's Observation room too.
	for a in range(rooms.size()):
		for b in range(a + 1, rooms.size()):
			var ra: Dictionary = rooms[a]
			var rb: Dictionary = rooms[b]
			var ax0: float = ra["pos"].x - ra["size"].x * 0.5
			var ax1: float = ra["pos"].x + ra["size"].x * 0.5
			var az0: float = ra["pos"].y - ra["size"].y * 0.5
			var az1: float = ra["pos"].y + ra["size"].y * 0.5
			var bx0: float = rb["pos"].x - rb["size"].x * 0.5
			var bx1: float = rb["pos"].x + rb["size"].x * 0.5
			var bz0: float = rb["pos"].y - rb["size"].y * 0.5
			var bz1: float = rb["pos"].y + rb["size"].y * 0.5
			var ox: float = minf(ax1, bx1) - maxf(ax0, bx0)
			var oz: float = minf(az1, bz1) - maxf(az0, bz0)
			if ox > 0.01 and oz > 0.01:
				_fail("seed=%d rooms %s and %s OVERLAP by %.2f x %.2f" % [
					seed_i, ra["name"], rb["name"], ox, oz])
				return

	# --- reachability ----------------------------------------------------------
	# Every room must be reachable from the spawn. (The sealed teaching alcove that used to be
	# the one exception is gone with the Hollow One.)
	var reachable: Array = g.reachable_rooms()
	for r in rooms:
		var nm: String = r["name"]
		if nm == "Alcove":
			_fail("seed=%d a sealed 'Alcove' room still exists — the Hollow One was cut" % seed_i)
		if not reachable.has(nm):
			_fail("seed=%d room %s is UNREACHABLE from spawn %s" % [seed_i, nm, g.spawn_room])
			return

	# --- cycles ----------------------------------------------------------------
	# ⚠️ The single most important structural assertion here. A spanning tree is a
	# perfect maze; in a perfect maze a corridor-following pursuer is unbeatable,
	# because every corridor is a dead end with extra steps. maze_chase_ui.gd's BFS
	# monster taught this project that lesson at a cost of 12 instant deaths in 40.
	if g.extra_edge_count < 1:
		_fail("seed=%d NO CYCLES — the layout is a perfect maze" % seed_i)
	_cycles_total += g.extra_edge_count

	# --- doorways lie on genuinely shared edges --------------------------------
	for d in doors:
		if not _doorway_is_shared(g, d):
			_fail("seed=%d doorway at %s dir=%s is not on a shared room edge" % [
				seed_i, d["pos"], d["dir"]])
			break

	# --- seven sconces in seven distinct chambers ------------------------------
	# ⚠️ Exactly seven, every seed, no tolerance. Lighting 7/7 is what reveals the
	# bed, so a dungeon that placed 6 is one the player can explore forever and
	# never finish. This is the single assertion in this file that is about the
	# level being WINNABLE rather than about it being well-formed.
	var spots: Array = g.sconce_spots
	if spots.size() != 7:
		_fail("seed=%d placed %d sconces, not 7 — the level is UNWINNABLE" % [
			seed_i, spots.size()])
		_sconce_short += 1
	var seen: Dictionary = {}
	for s in spots:
		var nm2: String = s["room"]
		if seen.has(nm2):
			_fail("seed=%d two sconces in the same chamber %s" % [seed_i, nm2])
		seen[nm2] = true
		if not chambers.has(nm2):
			_fail("seed=%d sconce in %s which is not a chamber" % [seed_i, nm2])

	# --- no sconce or frame on a wall carrying a doorway -----------------------
	# wall_point() returns the wall CENTRE, which is exactly where a doorway sits.
	# A collider there silently seals the room — a documented recurrence (the
	# Records warning sign sealed a breaker room in the Lab).
	for s in spots:
		if not g.free_sides(s["room"]).has(s["side"]):
			_fail("seed=%d SCONCE in %s is on side %s which carries a doorway" % [
				seed_i, s["room"], s["side"]])
			break
	for f in g.frame_spots:
		if not g.free_sides(f["room"]).has(f["side"]):
			_fail("seed=%d FRAME in %s is on side %s which carries a doorway" % [
				seed_i, f["room"], f["side"]])
			break

	# --- the bed is a walk away ------------------------------------------------
	var bed_d: int = g.room_distance(g.spawn_room, g.bed_room)
	if bed_d < 3:
		_fail("seed=%d bed is only %d rooms from spawn" % [seed_i, bed_d])
	_bed_dist_min = mini(_bed_dist_min, bed_d)

	# --- entity exclusion zones (§B10, as amended 2026-09-12) --------------------
	# The spawn and bed chambers hold no resident statue. Sconce chambers MAY now: a Crypt's
	# statue rises when its sconce is lit, and the statues no longer kill (creature_stalker.gd
	# `lethal = false`), so the old "no entity in a lit chamber" ban is deliberately gone.
	if g.still_one_rooms.has(g.spawn_room):
		_fail("seed=%d a Still One is in the SPAWN chamber" % seed_i)
	if g.still_one_rooms.has(g.bed_room):
		_fail("seed=%d a Still One is in the BED chamber" % seed_i)
	for nm3 in g.still_one_rooms:
		var k: String = g.kind_of(nm3)
		if k != "cells" and k != "crypt":
			_fail("seed=%d a Still One in %s, a '%s' (only cells/crypt host them)" % [seed_i, nm3, k])
			break

	# --- no beartraps, no alcove (both cut 2026-09-12) -------------------------
	# An absence assertion needs its subject to still be expressible, or it is vacuous: the
	# generator has no `beartrap_rooms` any more, so assert on the property's ABSENCE too.
	if g.get("beartrap_rooms") != null:
		_fail("seed=%d the generator still exposes beartrap_rooms" % seed_i)
	if g.get("teach_room") != null:
		_fail("seed=%d the generator still exposes teach_room (the Hollow One's alcove)" % seed_i)

	# --- room kinds ------------------------------------------------------------
	var kinds: Dictionary = g.room_kinds
	var counts: Dictionary = {}
	for nm4 in chambers:
		var k2: String = kinds.get(nm4, "")
		if k2 == "" or not g.ROOM_KINDS.has(k2):
			_fail("seed=%d chamber %s has no valid kind ('%s')" % [seed_i, nm4, k2])
			break
		counts[k2] = int(counts.get(k2, 0)) + 1
		_kind_counts[k2] = int(_kind_counts.get(k2, 0)) + 1
	if int(counts.get("larder", 0)) != 1:
		_fail("seed=%d %d larders, want exactly 1" % [seed_i, int(counts.get("larder", 0))])
	if int(counts.get("well", 0)) != 1:
		_fail("seed=%d %d wells, want exactly 1" % [seed_i, int(counts.get("well", 0))])
	# --- four-door chambers hold nothing on a wall (2026-09-12, seed 606) ------
	# Every builder but the cistern's hugs a doorway-free "back" wall; a chamber with a doorway
	# in every wall has none, and the fallback stood a lectern in a doorway. Such chambers are
	# re-dealt to "cistern" and counted, so the rate is printed rather than assumed.
	for nm5 in chambers:
		# Sconce chambers become bench-less galleries (frames hang on walls); the rest, cisterns.
		if nm5 == g.bed_room:
			continue   # always a crypt; the builder drops its sarcophagi instead
		if g.prop_sides(nm5).is_empty() and not ["cistern", "gallery"].has(kinds.get(nm5, "")):
			_fail("seed=%d %s has no prop-safe wall but is a '%s'" % [seed_i, nm5, kinds.get(nm5, "")])
			break
	_sealed_overrides += int(g.sealed_kind_overrides)
	if int(counts.get("chapel", 0)) != 1:
		_fail("seed=%d %d chapels, want exactly 1" % [seed_i, int(counts.get("chapel", 0))])
	if kinds.get(g.spawn_room, "") != "scriptorium":
		_fail("seed=%d the spawn chamber is a '%s', not the zero-panic scriptorium" % [
			seed_i, kinds.get(g.spawn_room, "")])
	if kinds.get(g.bed_room, "") != "crypt":
		_fail("seed=%d the bed chamber is a '%s', not a crypt" % [seed_i, kinds.get(g.bed_room, "")])
	if g.lair_room == "" or not seen.has(g.lair_room):
		_fail("seed=%d the larder %s is not a sconce chamber" % [seed_i, g.lair_room])
	elif g.lair_room == g.spawn_room:
		_fail("seed=%d the larder is the spawn chamber" % seed_i)
	# Cells only where the niche fits (>= 2x3 cells).
	for nm5 in chambers:
		if kinds.get(nm5, "") == "cells":
			var rr: Rect2i = g.room_rect(nm5)
			if mini(rr.size.x, rr.size.y) < 2 or rr.size.x * rr.size.y < 6:
				_fail("seed=%d cells in %s which is only %dx%d cells" % [seed_i, nm5, rr.size.x, rr.size.y])
				break

	# --- sconce spacing ---------------------------------------------------------
	# Pairwise room-graph distance >= the gap the generator reports it used; the number of
	# seeds that had to relax below SCONCE_MIN_GAP is printed and asserted at the end.
	_relaxed_total += g.sconce_relaxed
	_gap_min = mini(_gap_min, g.sconce_gap_used)
	for a2 in range(spots.size()):
		for b2 in range(a2 + 1, spots.size()):
			var dd: int = g.room_distance(spots[a2]["room"], spots[b2]["room"])
			if dd < g.sconce_gap_used:
				_fail("seed=%d sconces %s and %s are %d rooms apart, under the used gap %d" % [
					seed_i, spots[a2]["room"], spots[b2]["room"], dd, g.sconce_gap_used])
				break


# A doorway is legitimate only if two DIFFERENT rooms actually meet on that plane
# and both span the doorway's position. A doorway on an unshared edge is a hole
# into the void — Issue 5's whole family.
func _doorway_is_shared(g, d: Dictionary) -> bool:
	var p: Vector2 = d["pos"]
	var on_low := 0
	var on_high := 0
	for r in g.rooms:
		var x0: float = r["pos"].x - r["size"].x * 0.5
		var x1: float = r["pos"].x + r["size"].x * 0.5
		var z0: float = r["pos"].y - r["size"].y * 0.5
		var z1: float = r["pos"].y + r["size"].y * 0.5
		if d["dir"] == "x":
			if p.y <= z0 + 0.01 or p.y >= z1 - 0.01:
				continue
			if absf(p.x - x1) < 0.01:
				on_low += 1     # this room ends at the plane
			elif absf(p.x - x0) < 0.01:
				on_high += 1    # this room starts at the plane
		else:
			if p.x <= x0 + 0.01 or p.x >= x1 - 0.01:
				continue
			if absf(p.y - z1) < 0.01:
				on_low += 1
			elif absf(p.y - z0) < 0.01:
				on_high += 1
	return on_low >= 1 and on_high >= 1


func _doorway_touches_room_unused(g, d: Dictionary, room_name: String) -> bool:
	for r in g.rooms:
		if r["name"] != room_name:
			continue
		var p: Vector2 = d["pos"]
		var x0: float = r["pos"].x - r["size"].x * 0.5
		var x1: float = r["pos"].x + r["size"].x * 0.5
		var z0: float = r["pos"].y - r["size"].y * 0.5
		var z1: float = r["pos"].y + r["size"].y * 0.5
		if d["dir"] == "x":
			return (absf(p.x - x0) < 0.01 or absf(p.x - x1) < 0.01) \
				and p.y > z0 - 0.01 and p.y < z1 + 0.01
		return (absf(p.y - z0) < 0.01 or absf(p.y - z1) < 0.01) \
			and p.x > x0 - 0.01 and p.x < x1 + 0.01
	return false


func _report() -> void:
	# ⚠️ Sample-size assertion. Without it, a DungeonGen that fails to compile makes
	# every .new() return null, every check short-circuit, and this test print a
	# tidy PASS having asserted precisely nothing.
	if _checked < RUNS:
		_fail("only %d/%d seeds were generated — did dungeon_gen.gd fail to load?" % [
			_checked, RUNS])

	print("DUNGEON-GEN seeds=%d" % _checked)
	if _checked > 0:
		print("  rooms per dungeon: min %d  mean %.1f  max %d" % [
			_rooms_min, float(_rooms_total) / _checked, _rooms_max])
		print("  extra (cycle) edges: mean %.1f" % [float(_cycles_total) / _checked])
		print("  shortest spawn->bed distance seen: %d rooms" % _bed_dist_min)
		print("  seeds with fewer than 7 sconces: %d" % _sconce_short)
		print("  sconce spacing: min gap used %d, relaxations %d across %d seeds" % [
			_gap_min, _relaxed_total, _checked])
		print("  kinds dealt over all seeds: %s" % str(_kind_counts))
		print("  chambers with no prop-safe wall re-dealt (cistern / bench-less gallery): %d over %d seeds" % [_sealed_overrides, _checked])
	# ⚠️ The spacing rule must hold on MOST dungeons, or it is decoration. Measured on the
	# 24x24 / 16-chamber lattice and asserted as a fraction, not zero: a seed that draws few
	# chambers may legitimately need the relaxation.
	if _checked > 0 and _relaxed_total > _checked / 10:
		_fail("sconce spacing relaxed on %d of %d seeds (limit 10%%)" % [_relaxed_total, _checked])
	print("  %d checks, %d failed" % [_checked, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
