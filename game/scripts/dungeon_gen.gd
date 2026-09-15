class_name DungeonGen
extends RefCounted

# Procedural dungeon layout for THE NIGHTMARE (DUNGEON_NIGHTMARES.md §B6).
#
# PURE DATA. No scene, no nodes, no engine state — `generate()` fills the public
# arrays below and `dungeon.gd` turns them into geometry. That separation is the
# whole reason this is testable: check_dungeon_gen.gd runs 200 seeds without ever
# loading a scene. `check_maze_gen.gd` exists for exactly the same reason ("the
# minigame is only ever opened via player interaction, so a normal scene smoke test
# never exercises _generate_maze() at all") — and the trap is identical here.
#
# ── Why a LATTICE and not free rectangles ───────────────────────────────────────
# RoomBuilder imposes three hard constraints: rooms must ABUT and never OVERLAP
# (Issue 23), wall dedup is by interval per (axis, plane, height), and doorways cut
# every wall on their plane whose span they overlap. A naive random-rectangle
# generator violates all three and would reproduce Issues 19/20/23 at scale. A cell
# lattice makes abutment exact and overlap impossible by construction — and it is
# also literally what Dungeon Nightmares does (its rooms are "2x2", "2x3", "3x2").
#
# ⚠️ UNIFORM ROOM HEIGHT. §B6 step 6 asks for h=3.2 chambers and h=2.6 corridors.
# Measured (tests/probe_mixed_height.gd): RoomBuilder keys its wall dedup on
# "axis|plane|HEIGHT", so two abutting rooms of different heights BOTH emit a slab
# on their shared plane — 4 slabs where there should be 2, with coincident faces.
# No shipped level uses per-room "h" at all, so this was untested territory. We keep
# one height and let dungeon.gd hang a separate drop-ceiling over corridor rooms,
# which delivers the same "chambers feel like rooms" read with nothing coplanar.
# See ISSUES_SOLUTIONS.md Issue 41.

const CELL := 3.0          # one corridor width — DN's "hallway"
# ⭐ 24, not 18 (2026-09-12, the user's call): a clean run of the 18x18 lattice took 82 s against
# a 12-15 minute target, with sconces a room or two apart. 72 x 72 m gives the hunter room to
# hunt in and the sconce-spacing rule below something to space across.
const GRID := 24           # 24 x 24 cells, a ~72 x 72 m envelope
const ROOM_H := 3.2        # uniform; see the ⚠️ above
const CORRIDOR_CEIL_H := 2.6   # dungeon.gd's drop ceiling, not a RoomBuilder height

# ⚠️ 12, not §B6's 9. Seven sconces must ALWAYS be placeable — 7/7 is what reveals
# the bed, so a dungeon that can only fit 6 is unwinnable. With 9 chambers, minus
# the bed chamber, minus any chamber whose every wall ended up carrying a doorway,
# the pool was exactly 7 in the best case and measured short on 69 of 200 seeds.
# Slack is the fix; the extra chambers also give the Matron more places to be.
const CHAMBER_COUNT := 16   # 16 on the 24x24 lattice (was 12 on 18x18) — enough for every
                            # room KIND to appear, see _deal_kinds()
const MIN_CHAMBERS := 9     # hard floor — below this the level cannot be won
const PLACE_ATTEMPTS := 60  # then give up on this chamber — NEVER loop forever
const SCONCE_COUNT := 7
const CANDLE_CACHES := 8   # 4 -> 8 on 2026-09-13 (D1): one per two chambers
const STILL_ONE_COUNT := 6
const FRAME_COUNT := 6
const HIDING_COUNT := 2
const DOOR_WIDTH := 2.2
const MAX_STRAIGHT := 7     # cells; longer runs get a jog (§B6 step 8). 5 on the 18x18 lattice.

# ⭐ SCONCE SPACING (2026-09-12). Room-graph BFS distance (corridors count as rooms, so two
# chambers joined by one corridor are 2 apart; chambers never abut, so 2 is unconstrained).
# Seven sconces are picked greedily at >= this gap; if seven do not fit the gap is relaxed to 2
# and `sconce_relaxed` counts it, because 7/7 is what reveals the bed and is non-negotiable.
const SCONCE_MIN_GAP := 3

# ⭐ ROOM ARCHETYPES (2026-09-12, the user's structure: "variety by room, not a ladder"). Every
# chamber is dealt a KIND; `dungeon_rooms.gd` builds the props and owns the one scare each kind
# fires — when that room's sconce is lit (SCONCE_KINDS) or when the player first steps in
# (ENTRY_KINDS). This file only deals the cards; it never builds anything.
const ROOM_KINDS := ["gallery", "scriptorium", "cells", "well", "chapel", "crypt", "cistern", "larder"]
const SCONCE_KINDS := ["gallery", "chapel", "crypt", "larder", "scriptorium"]
const ENTRY_KINDS := ["cells", "well", "cistern", "scriptorium"]

const EMPTY := 0
const CHAMBER := 1
const CORRIDOR := 2

# ── Output ──────────────────────────────────────────────────────────────────────
var rooms: Array = []            # RoomBuilder room dicts, world coords
var doorways: Array = []         # RoomBuilder doorway dicts
var chamber_names: Array[String] = []
var corridor_names: Array[String] = []
var spawn_room: String = ""
var bed_room: String = ""
var sconce_spots: Array = []     # [{room, side: Vector2}]
var frame_spots: Array = []      # [{room, side: Vector2}] — the Gallery rooms' paintings
var still_one_rooms: Array[String] = []   # the Cells and Crypt rooms (never the bed)
var candle_rooms: Array[String] = []
var hiding_rooms: Array[String] = []
var matron_spawn_rooms: Array[String] = []
var room_kinds: Dictionary = {}  # chamber name -> one of ROOM_KINDS
var lair_room: String = ""       # the one "larder": the hunter's lair, a sconce chamber
var sconce_relaxed: int = 0      # how many times the spacing rule had to be loosened (0 = never)
var sealed_kind_overrides := 0   # chambers re-dealt to 'cistern' for having no prop-safe wall (prop_sides)
var sconce_gap_used: int = 0     # the gap the seven sconces actually satisfy
var slam_doorways: Array = []    # indices into `doorways` — chamber<->corridor only
var extra_edge_count: int = 0    # cycles added beyond the spanning tree

# ── Internals ───────────────────────────────────────────────────────────────────
var _grid: Array = []            # _grid[y][x] -> EMPTY/CHAMBER/CORRIDOR
var _chambers: Array = []        # [{id, x0, y0, x1, y1}] inclusive cell bounds
var _cell_room: Dictionary = {}  # "x,y" -> room name
var _room_cells: Dictionary = {} # room name -> Array[Vector2i]
var _room_rect: Dictionary = {}  # room name -> Rect2i in cells
var _adj: Dictionary = {}        # room name -> Array[String]
var _doorway_rooms: Array = []   # parallel to `doorways`: [roomA, roomB] it joins
var _carved_paths: Array = []    # the ordered cell paths the carve produced
var _rng := RandomNumberGenerator.new()
var _content_rng := RandomNumberGenerator.new()


# `layout_seed` decides the geometry, `content_seed` decides what is IN it. They are
# separate so a level can restore "5 sconces lit" against the SAME dungeon — see
# the ⚠️ on KONTUR's _dark_x: restoring progress against a re-rolled layout marks
# gates passed whose puzzles have moved.
func generate(layout_seed: int, content_seed: int) -> void:
	_rng.seed = layout_seed
	_content_rng.seed = content_seed
	_reset()

	_place_chambers()
	_connect_chambers()
	_coalesce_rooms()
	_build_adjacency()
	_emit_doorways()
	_nudge_collinear_doorways()
	_place_content()


func _reset() -> void:
	rooms = []
	doorways = []
	chamber_names = []
	corridor_names = []
	spawn_room = ""
	bed_room = ""
	sconce_spots = []
	frame_spots = []
	still_one_rooms = []
	candle_rooms = []
	hiding_rooms = []
	matron_spawn_rooms = []
	room_kinds = {}
	lair_room = ""
	sconce_relaxed = 0
	sconce_gap_used = 0
	slam_doorways = []
	extra_edge_count = 0
	_chambers = []
	_cell_room = {}
	_room_cells = {}
	_room_rect = {}
	_adj = {}
	_doorway_rooms = []
	_carved_paths = []
	_grid = []
	for y in range(GRID):
		var row: Array = []
		for x in range(GRID):
			row.append(EMPTY)
		_grid.append(row)


# ── Step 1: chambers ────────────────────────────────────────────────────────────
# Rejection sampling with a 1-cell gap. The gap is not cosmetic: it guarantees a
# corridor can always run between two chambers, and it guarantees RoomBuilder's
# no-overlap rule holds by construction.
func _place_chambers() -> void:
	for _i in range(CHAMBER_COUNT):
		if not _try_place_chamber(_rng.randi_range(2, 3), _rng.randi_range(2, 4)):
			# Give up on THIS chamber rather than looping forever (§B6 step 1) —
			# but keep going, because a later smaller draw may still fit.
			continue

	# ⚠️ Top-up pass with the smallest possible chamber.
	# MIN_CHAMBERS is a HARD floor, not a preference: seven sconces have to fit in
	# seven distinct chambers that are not the bed chamber, so a dungeon with fewer
	# than 8 usable chambers is UNWINNABLE — 7/7 is what reveals the exit. Pure
	# rejection sampling produced 7 chambers on 2 seeds in 200, i.e. roughly one
	# unwinnable dungeon per hundred restarts, which on a level that re-rolls on
	# every death is not an acceptable rate.
	var guard := 0
	while _chambers.size() < MIN_CHAMBERS and guard < 200:
		guard += 1
		_try_place_chamber(2, 2)


func _try_place_chamber(w: int, d: int) -> bool:
	for _attempt in range(PLACE_ATTEMPTS):
		# Never touch the border: the outermost ring stays empty so every chamber
		# has room for a corridor on all sides.
		var x0 := _rng.randi_range(1, GRID - w - 2)
		var y0 := _rng.randi_range(1, GRID - d - 2)
		if not _chamber_fits(x0, y0, x0 + w - 1, y0 + d - 1):
			continue
		_chambers.append({"id": _chambers.size(), "x0": x0, "y0": y0,
			"x1": x0 + w - 1, "y1": y0 + d - 1})
		for y in range(y0, y0 + d):
			for x in range(x0, x0 + w):
				_grid[y][x] = CHAMBER
		return true
	return false


func _chamber_fits(x0: int, y0: int, x1: int, y1: int) -> bool:
	# Reject if any cell within 1 of the candidate is already occupied.
	for y in range(y0 - 1, y1 + 2):
		for x in range(x0 - 1, x1 + 2):
			if x < 0 or y < 0 or x >= GRID or y >= GRID:
				continue
			if _grid[y][x] != EMPTY:
				return false
	return true


# ── Step 2+3: connect and carve ─────────────────────────────────────────────────
func _connect_chambers() -> void:
	var n := _chambers.size()
	if n < 2:
		return

	# Complete graph weighted by Manhattan distance between chamber centres.
	var edges: Array = []
	for a in range(n):
		for b in range(a + 1, n):
			edges.append([_manhattan(a, b), a, b])
	edges.sort_custom(func(p, q): return p[0] < q[0])

	# Kruskal -> minimum spanning tree (guarantees connectivity).
	var parent: Array = []
	for i in range(n):
		parent.append(i)
	var tree: Array = []
	var spare: Array = []
	for e in edges:
		if _find(parent, e[1]) != _find(parent, e[2]):
			parent[_find(parent, e[1])] = _find(parent, e[2])
			tree.append(e)
		else:
			spare.append(e)

	# ⚠️ THE EXTRA EDGES ARE NOT OPTIONAL. A spanning tree is a PERFECT MAZE, and in
	# a perfect maze every corridor is a dead end with extra steps — so a pursuer
	# that follows corridors is unbeatable. This project has already paid for that
	# lesson once: maze_chase_ui.gd's BFS monster became a 12-in-40 instant death
	# the moment it started following actual corridors. DN's dungeons are loopy for
	# precisely this reason, and it is why closing a door on Mary and walking around
	# the block works. A level with a chaser MUST have cycles.
	var extras: int = int(ceil(0.25 * n))
	for i in range(min(extras, spare.size())):
		tree.append(spare[i])
		extra_edge_count += 1

	for e in tree:
		_carve(e[1], e[2])


func _find(parent: Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


func _manhattan(a: int, b: int) -> int:
	var ca := _chamber_center(a)
	var cb := _chamber_center(b)
	return absi(ca.x - cb.x) + absi(ca.y - cb.y)


func _chamber_center(i: int) -> Vector2i:
	var c: Dictionary = _chambers[i]
	return Vector2i((c.x0 + c.x1) / 2, (c.y0 + c.y1) / 2)


# Carve an L (or Z) between two chamber centres. Cells already CHAMBER are skipped,
# so the path enters and leaves chambers cleanly. Every crossing between a chamber
# cell and a non-chamber cell is recorded as a PORTAL — that is what later becomes a
# doorway, which is why an incidental adjacency does not punch a hole in a wall.
func _carve(a: int, b: int) -> void:
	var pa := _chamber_center(a)
	var pb := _chamber_center(b)
	var path := _path_cells(pa, pb)

	for i in range(path.size()):
		var c: Vector2i = path[i]
		if _grid[c.y][c.x] == EMPTY:
			_grid[c.y][c.x] = CORRIDOR

	# Record the ordered path so _emit_doorways can find where it crosses a wall.
	_carved_paths.append(path)


# A Manhattan path with at most two elbows. If a single leg would run longer than
# MAX_STRAIGHT cells we split it into a Z, because the one trick behind DN's
# claustrophobia is that you almost never have a sightline longer than one room
# (§B6 step 8 / §B7 point 2) — and unlike fog, it costs nothing to render.
func _path_cells(from: Vector2i, to: Vector2i) -> Array:
	var out: Array = []
	var x_first := _rng.randi_range(0, 1) == 0
	var dx: int = absi(to.x - from.x)
	var dy: int = absi(to.y - from.y)

	var waypoints: Array = [from]
	if x_first:
		if dx > MAX_STRAIGHT and dy > 0:
			var midx: int = from.x + (to.x - from.x) / 2
			var midy: int = from.y + (to.y - from.y) / 2
			waypoints.append(Vector2i(midx, from.y))
			waypoints.append(Vector2i(midx, midy))
			waypoints.append(Vector2i(to.x, midy))
		else:
			waypoints.append(Vector2i(to.x, from.y))
	else:
		if dy > MAX_STRAIGHT and dx > 0:
			var midy2: int = from.y + (to.y - from.y) / 2
			var midx2: int = from.x + (to.x - from.x) / 2
			waypoints.append(Vector2i(from.x, midy2))
			waypoints.append(Vector2i(midx2, midy2))
			waypoints.append(Vector2i(midx2, to.y))
		else:
			waypoints.append(Vector2i(from.x, to.y))
	waypoints.append(to)

	var cur: Vector2i = from
	out.append(cur)
	for wp in waypoints:
		while cur.x != wp.x:
			cur.x += signi(wp.x - cur.x)
			out.append(cur)
		while cur.y != wp.y:
			cur.y += signi(wp.y - cur.y)
			out.append(cur)
	return out


# ── Step 4: coalesce corridor cells into rooms ──────────────────────────────────
# Merge each maximal STRAIGHT run into one RoomBuilder room, splitting at every turn
# and every junction. This keeps the room count sane and — more importantly — stops
# us emitting a wall plane at every 3 m cell boundary, which is the Issue-23
# coincident-wall bug waiting to happen.
func _coalesce_rooms() -> void:
	# Chambers first, so they own their cells.
	for ch in _chambers:
		var nm := "Chamber%d" % ch.id
		chamber_names.append(nm)
		var cells: Array[Vector2i] = []
		for y in range(ch.y0, ch.y1 + 1):
			for x in range(ch.x0, ch.x1 + 1):
				cells.append(Vector2i(x, y))
				_cell_room["%d,%d" % [x, y]] = nm
		_room_cells[nm] = cells
		_room_rect[nm] = Rect2i(ch.x0, ch.y0, ch.x1 - ch.x0 + 1, ch.y1 - ch.y0 + 1)

	# Then corridor runs.
	var claimed: Dictionary = {}
	var idx := 0
	for y in range(GRID):
		for x in range(GRID):
			if _grid[y][x] != CORRIDOR:
				continue
			var key := "%d,%d" % [x, y]
			if claimed.has(key):
				continue
			var kind := _corridor_kind(x, y)
			var cells: Array[Vector2i] = []
			if kind == "h":
				var x0 := x
				while x0 - 1 >= 0 and _grid[y][x0 - 1] == CORRIDOR \
						and _corridor_kind(x0 - 1, y) == "h" \
						and not claimed.has("%d,%d" % [x0 - 1, y]):
					x0 -= 1
				var x1 := x
				while x1 + 1 < GRID and _grid[y][x1 + 1] == CORRIDOR \
						and _corridor_kind(x1 + 1, y) == "h":
					x1 += 1
				for cx in range(x0, x1 + 1):
					cells.append(Vector2i(cx, y))
			elif kind == "v":
				var y0 := y
				while y0 - 1 >= 0 and _grid[y0 - 1][x] == CORRIDOR \
						and _corridor_kind(x, y0 - 1) == "v" \
						and not claimed.has("%d,%d" % [x, y0 - 1]):
					y0 -= 1
				var y1 := y
				while y1 + 1 < GRID and _grid[y1 + 1][x] == CORRIDOR \
						and _corridor_kind(x, y1 + 1) == "v":
					y1 += 1
				for cy in range(y0, y1 + 1):
					cells.append(Vector2i(x, cy))
			else:
				# A turn, a T, a cross or an isolated cell: its own 1x1 room.
				cells.append(Vector2i(x, y))

			var nm := "Hall%d" % idx
			idx += 1
			corridor_names.append(nm)
			var minx := 9999
			var miny := 9999
			var maxx := -1
			var maxy := -1
			for c in cells:
				claimed["%d,%d" % [c.x, c.y]] = true
				_cell_room["%d,%d" % [c.x, c.y]] = nm
				minx = mini(minx, c.x)
				miny = mini(miny, c.y)
				maxx = maxi(maxx, c.x)
				maxy = maxi(maxy, c.y)
			_room_cells[nm] = cells
			_room_rect[nm] = Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1)

	_emit_rooms()


# "h" = part of a horizontal run, "v" = vertical, "j" = junction/turn (own room).
func _corridor_kind(x: int, y: int) -> String:
	var e: bool = x + 1 < GRID and _grid[y][x + 1] == CORRIDOR
	var w: bool = x - 1 >= 0 and _grid[y][x - 1] == CORRIDOR
	var n: bool = y - 1 >= 0 and _grid[y - 1][x] == CORRIDOR
	var s: bool = y + 1 < GRID and _grid[y + 1][x] == CORRIDOR
	var horiz: bool = e or w
	var vert: bool = n or s
	if horiz and not vert:
		return "h"
	if vert and not horiz:
		return "v"
	return "j"


func _emit_rooms() -> void:
	rooms = []
	for nm in chamber_names + corridor_names:
		var r: Rect2i = _room_rect[nm]
		rooms.append({
			"name": nm,
			"pos": _cell_to_world(r.position, r.size),
			"size": Vector2(r.size.x * CELL, r.size.y * CELL),
			"h": ROOM_H,
		})


# Cell rect -> world centre. The lattice is centred on the origin.
func _cell_to_world(origin: Vector2i, size: Vector2i) -> Vector2:
	var cx: float = (origin.x + size.x * 0.5 - GRID * 0.5) * CELL
	var cz: float = (origin.y + size.y * 0.5 - GRID * 0.5) * CELL
	return Vector2(cx, cz)


func cell_center_world(c: Vector2i) -> Vector3:
	var p := _cell_to_world(c, Vector2i(1, 1))
	return Vector3(p.x, 0.0, p.y)


# ── Step 5: doorways ────────────────────────────────────────────────────────────
func _build_adjacency() -> void:
	_adj = {}
	for nm in _room_cells.keys():
		_adj[nm] = []


# Emit a doorway for every crossing the carved paths actually make, plus every
# corridor<->corridor adjacency (consecutive runs of one continuous hallway).
#
# ⚠️ Deliberately NOT "every adjacent pair". A corridor that merely runs alongside a
# chamber would otherwise get a doorway punched into that wall, and a chamber with a
# doorway on all four sides has nowhere left to hang a sconce — which silently seals
# the room the moment a collider lands on the doorway (§B6 step 7; the Records
# warning sign did exactly this in the Lab).
func _emit_doorways() -> void:
	var pairs: Dictionary = {}

	for path in _carved_paths:
		for i in range(path.size() - 1):
			var a: Vector2i = path[i]
			var b: Vector2i = path[i + 1]
			var ra: String = _cell_room.get("%d,%d" % [a.x, a.y], "")
			var rb: String = _cell_room.get("%d,%d" % [b.x, b.y], "")
			if ra == "" or rb == "" or ra == rb:
				continue
			pairs[_pair_key(ra, rb)] = [ra, rb, a, b]

	# Corridor<->corridor adjacency: two runs that touch are one hallway.
	for nm in corridor_names:
		for c in _room_cells[nm]:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var o: Vector2i = c + d
				if o.x < 0 or o.y < 0 or o.x >= GRID or o.y >= GRID:
					continue
				var other: String = _cell_room.get("%d,%d" % [o.x, o.y], "")
				if other == "" or other == nm or not corridor_names.has(other):
					continue
				var k := _pair_key(nm, other)
				if not pairs.has(k):
					pairs[k] = [nm, other, c, o]

	for k in pairs.keys():
		var e: Array = pairs[k]
		_add_doorway(e[0], e[1], e[2], e[3])


func _pair_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


func _add_doorway(ra: String, rb: String, ca: Vector2i, cb: Vector2i) -> void:
	var d: Vector2i = cb - ca
	var dir := "x" if d.x != 0 else "z"
	# The doorway sits on the boundary plane between the two cells.
	var wx: float
	var wz: float
	if dir == "x":
		var plane_x: float = (maxi(ca.x, cb.x) - GRID * 0.5) * CELL
		wx = plane_x
		wz = (ca.y + 0.5 - GRID * 0.5) * CELL
	else:
		var plane_z: float = (maxi(ca.y, cb.y) - GRID * 0.5) * CELL
		wz = plane_z
		wx = (ca.x + 0.5 - GRID * 0.5) * CELL

	doorways.append({"pos": Vector2(wx, wz), "width": DOOR_WIDTH, "dir": dir})
	var idx: int = doorways.size() - 1
	_doorway_rooms.append([ra, rb])

	_adj[ra].append(rb)
	_adj[rb].append(ra)

	# SlamDoors go on chamber<->corridor thresholds only — never corridor turns, and
	# never a dead end (§B4.2 / §B10).
	var a_ch: bool = chamber_names.has(ra)
	var b_ch: bool = chamber_names.has(rb)
	if a_ch != b_ch:
		slam_doorways.append(idx)


# ── Step 8: sightline pass ──────────────────────────────────────────────────────
# If a chamber has two doorways that are collinear and directly opposite, you can
# see straight through it into the next space. Nudge one off-centre by a cell.
func _nudge_collinear_doorways() -> void:
	for nm in chamber_names:
		var r: Rect2i = _room_rect[nm]
		if r.size.x < 2 and r.size.y < 2:
			continue
		var mine: Array = _doorways_touching(nm)
		for i in range(mine.size()):
			for j in range(i + 1, mine.size()):
				var a: int = mine[i]
				var b: int = mine[j]
				var da: Dictionary = doorways[a]
				var db: Dictionary = doorways[b]
				if da["dir"] != db["dir"]:
					continue
				var p1: Vector2 = da["pos"]
				var p2: Vector2 = db["pos"]
				var collinear: bool = (da["dir"] == "z" and absf(p1.x - p2.x) < 0.01) \
					or (da["dir"] == "x" and absf(p1.y - p2.y) < 0.01)
				if not collinear:
					continue
				# ⚠️ Shift ONLY within the span the two rooms actually share.
				# Clamping to the chamber's own extent (the first version of this)
				# walks the doorway off the neighbour's wall, and RoomBuilder then
				# cuts an opening into a plane with nothing behind it — a hole into
				# the void, Issue 5's whole family. Caught by check_dungeon_gen.gd's
				# "doorway is not on a shared room edge" assertion on 197/200 seeds.
				var span: Vector2 = _shared_span(b)
				if span.y - span.x < DOOR_WIDTH + 0.2:
					continue
				var lo: float = span.x + DOOR_WIDTH * 0.5
				var hi: float = span.y - DOOR_WIDTH * 0.5
				if hi - lo < 0.1:
					continue
				var shifted := p2
				if da["dir"] == "z":
					shifted.x = clampf(p2.x + CELL, lo, hi)
					if absf(shifted.x - p2.x) < 0.01:
						shifted.x = clampf(p2.x - CELL, lo, hi)
				else:
					shifted.y = clampf(p2.y + CELL, lo, hi)
					if absf(shifted.y - p2.y) < 0.01:
						shifted.y = clampf(p2.y - CELL, lo, hi)
				if shifted != p2:
					doorways[b]["pos"] = shifted


# The interval, along the wall it sits in, over which BOTH rooms joined by doorway
# `idx` actually exist. A doorway may only ever be moved inside this.
func _shared_span(idx: int) -> Vector2:
	var pair: Array = _doorway_rooms[idx]
	var ra: Rect2i = _room_rect.get(pair[0], Rect2i())
	var rb: Rect2i = _room_rect.get(pair[1], Rect2i())
	var horizontal_wall: bool = doorways[idx]["dir"] == "z"   # wall runs along X
	var a0: int
	var a1: int
	var b0: int
	var b1: int
	if horizontal_wall:
		a0 = ra.position.x
		a1 = ra.position.x + ra.size.x
		b0 = rb.position.x
		b1 = rb.position.x + rb.size.x
	else:
		a0 = ra.position.y
		a1 = ra.position.y + ra.size.y
		b0 = rb.position.y
		b1 = rb.position.y + rb.size.y
	var lo: int = maxi(a0, b0)
	var hi: int = mini(a1, b1)
	return Vector2((lo - GRID * 0.5) * CELL, (hi - GRID * 0.5) * CELL)


func _doorways_touching(room_name: String) -> Array:
	var r: Rect2i = _room_rect[room_name]
	var x0: float = (r.position.x - GRID * 0.5) * CELL
	var x1: float = (r.position.x + r.size.x - GRID * 0.5) * CELL
	var z0: float = (r.position.y - GRID * 0.5) * CELL
	var z1: float = (r.position.y + r.size.y - GRID * 0.5) * CELL
	var out: Array = []
	for i in range(doorways.size()):
		var d: Dictionary = doorways[i]
		var p: Vector2 = d["pos"]
		if d["dir"] == "x":
			if (absf(p.x - x0) < 0.01 or absf(p.x - x1) < 0.01) \
					and p.y > z0 - 0.01 and p.y < z1 + 0.01:
				out.append(i)
		else:
			if (absf(p.y - z0) < 0.01 or absf(p.y - z1) < 0.01) \
					and p.x > x0 - 0.01 and p.x < x1 + 0.01:
				out.append(i)
	return out


# Which sides of a room carry NO doorway. Sconces and Weeping Frames must go on
# one of these: wall_point() returns the wall CENTRE, which is exactly where a
# doorway sits, so a collider there silently seals the room.
func free_sides(room_name: String) -> Array:
	if not _room_rect.has(room_name):
		return []
	var r: Rect2i = _room_rect[room_name]
	var x0: float = (r.position.x - GRID * 0.5) * CELL
	var x1: float = (r.position.x + r.size.x - GRID * 0.5) * CELL
	var z0: float = (r.position.y - GRID * 0.5) * CELL
	var z1: float = (r.position.y + r.size.y - GRID * 0.5) * CELL
	var used := {"w": false, "e": false, "s": false, "n": false}
	for d in doorways:
		var p: Vector2 = d["pos"]
		if d["dir"] == "x":
			if p.y > z0 - 0.01 and p.y < z1 + 0.01:
				if absf(p.x - x0) < 0.01:
					used["w"] = true
				elif absf(p.x - x1) < 0.01:
					used["e"] = true
		else:
			if p.x > x0 - 0.01 and p.x < x1 + 0.01:
				if absf(p.y - z0) < 0.01:
					used["s"] = true
				elif absf(p.y - z1) < 0.01:
					used["n"] = true
	var out: Array = []
	if not used["w"]:
		out.append(Vector2(-1, 0))
	if not used["e"]:
		out.append(Vector2(1, 0))
	if not used["s"]:
		out.append(Vector2(0, -1))
	if not used["n"]:
		out.append(Vector2(0, 1))
	return out


# ── Step 7: content ─────────────────────────────────────────────────────────────
func _place_content() -> void:
	if chamber_names.is_empty():
		return

	var dist := _all_pairs_bfs()

	# Spawn = the chamber with the highest total distance to all others (a corner of
	# the graph, so the walk to the bed is long).
	var best_total := -1.0
	for nm in chamber_names:
		var total := 0.0
		for other in chamber_names:
			total += float(dist.get(nm, {}).get(other, 0))
		if total > best_total:
			best_total = total
			spawn_room = nm

	# Bed = the chamber furthest from spawn.
	var best_d := -1
	for nm in chamber_names:
		if nm == spawn_room:
			continue
		var d: int = int(dist.get(spawn_room, {}).get(nm, -1))
		if d > best_d:
			best_d = d
			bed_room = nm
	if bed_room == "":
		bed_room = spawn_room

	# ⚠️ §B10: the spawn chamber, the bed chamber and every lit-sconce chamber
	# contain no entity of any kind. Sconce chambers are excluded from the entity
	# pool below for the same reason.
	#
	# The spawn chamber IS eligible for a sconce — §B10 bars ENTITIES from it, not
	# fixtures, and lighting the one in the room you woke up in is a clean first
	# beat that teaches the verb before anything is hunting you. The bed chamber is
	# not: it stays dark until 7/7 reveals it.
	var sconce_pool: Array[String] = []
	for nm in chamber_names:
		if nm != bed_room and not free_sides(nm).is_empty():
			sconce_pool.append(nm)
	_shuffle(sconce_pool)
	# Put the spawn chamber first so it always gets one — the tutorial beat should
	# not be subject to the shuffle.
	if sconce_pool.has(spawn_room):
		sconce_pool.erase(spawn_room)
		sconce_pool.push_front(spawn_room)

	# ⭐ SPACING: greedy at SCONCE_MIN_GAP, relaxed one step at a time (never below 2, which is
	# unconstrained) only if seven do not fit. The spawn chamber is always first in the pool so it
	# always gets its tutorial sconce.
	var picked: Array[String] = []
	var gap: int = SCONCE_MIN_GAP
	while gap >= 2:
		picked = []
		for nm in sconce_pool:
			var ok := true
			for other in picked:
				if int(dist.get(nm, {}).get(other, 99)) < gap:
					ok = false
					break
			if ok:
				picked.append(nm)
			if picked.size() >= SCONCE_COUNT:
				break
		if picked.size() >= SCONCE_COUNT:
			break
		gap -= 1
		sconce_relaxed += 1
	sconce_gap_used = gap
	for nm in picked:
		var sides: Array = free_sides(nm)
		sconce_spots.append({"room": nm, "side": sides[_content_rng.randi() % sides.size()]})

	var sconce_rooms: Array[String] = []
	for sp in sconce_spots:
		sconce_rooms.append(sp["room"])

	# ⭐ The kinds are dealt BEFORE the entities, because the entities now follow the kinds.
	_deal_kinds(sconce_rooms)

	# Still Ones live in the Cells (behind bars, leashed) and the Crypts (rising from a
	# sarcophagus when its sconce is lit). Never the bed chamber — §B10's one rule that survived
	# the archetype pass: the finale's room holds no resident threat.
	for nm in chamber_names:
		if nm == bed_room:
			continue
		var k: String = room_kinds.get(nm, "")
		if k == "cells" or k == "crypt":
			still_one_rooms.append(nm)
	if still_one_rooms.size() > STILL_ONE_COUNT:
		still_one_rooms.resize(STILL_ONE_COUNT)

	# Weeping Frames: the Gallery rooms' paintings, on doorway-free walls the sconce is not
	# using — up to two per gallery, FRAME_COUNT overall.
	for nm in chamber_names:
		if room_kinds.get(nm, "") != "gallery":
			continue
		var taken: Variant = null
		for sp in sconce_spots:
			if sp["room"] == nm:
				taken = sp["side"]
		var choices: Array = []
		for sd in free_sides(nm):
			if taken == null or sd != taken:
				choices.append(sd)
		_shuffle(choices)
		# ⚠️ TWO PAINTINGS PER WALL, 1.1 m either side of the centre (2026-09-12). One per wall
		# left most galleries with a single frame — a 2-cell chamber has two free walls and the
		# sconce takes one — and a gallery with one picture is not a gallery. `offset` runs along
		# the wall; dungeon.gd applies it.
		for i in range(mini(2, choices.size())):
			for off in [-1.1, 1.1]:
				if frame_spots.size() >= FRAME_COUNT:
					break
				frame_spots.append({"room": nm, "side": choices[i], "offset": off})

	# Candle caches: chambers only, one candle each.
	var cache_pool: Array[String] = chamber_names.duplicate()
	cache_pool.erase(bed_room)
	_shuffle(cache_pool)
	for i in range(mini(CANDLE_CACHES, cache_pool.size())):
		candle_rooms.append(cache_pool[i])

	# Hiding: two, never in the same chamber, never in a dead end.
	var hide_pool: Array[String] = []
	for nm in chamber_names:
		if nm == spawn_room or nm == bed_room:
			continue
		if _adj.get(nm, []).size() >= 2:   # not a dead end
			hide_pool.append(nm)
	_shuffle(hide_pool)
	for i in range(mini(HIDING_COUNT, hide_pool.size())):
		hiding_rooms.append(hide_pool[i])

	# The hunter spawns in a chamber, never a corridor, and never the spawn/bed room.
	for nm in chamber_names:
		if nm != spawn_room and nm != bed_room:
			matron_spawn_rooms.append(nm)

	# ⚠️ No beartraps and no sealed alcove any more (2026-09-12): the traps were a death path in a
	# level whose only death is now the panic bar, and the alcove existed for the Hollow One,
	# which is cut. Both are asserted absent by check_dungeon_gen.gd.


# ⭐ Deal a KIND to every chamber. Pure data, content-RNG, so the same seed deals the same hand.
#
#   spawn chamber   -> scriptorium   a zero-panic first beat: writing appears on the wall
#   bed chamber     -> crypt         dressing only; NO resident statue (§B10, the finale room)
#   sconce chambers -> one LARDER (the hunter's lair, preferring >= 3 rooms from spawn), one
#                      CHAPEL, then gallery / crypt / scriptorium cycling
#   the rest        -> one WELL, then cells (only if the chamber is >= 2x3 cells) / cistern /
#                      scriptorium cycling
func _deal_kinds(sconce_rooms: Array[String]) -> void:
	room_kinds = {}
	lair_room = ""
	room_kinds[spawn_room] = "scriptorium"
	room_kinds[bed_room] = "crypt"

	var lair_pool: Array[String] = []
	var lair_far: Array[String] = []
	for nm in sconce_rooms:
		if nm == spawn_room or nm == bed_room:
			continue
		if prop_sides(nm).is_empty():
			continue   # the larder's hooks and barrels need a prop-safe wall
		lair_pool.append(nm)
		if room_distance(spawn_room, nm) >= 3:
			lair_far.append(nm)
	var pool: Array[String] = lair_far if not lair_far.is_empty() else lair_pool
	if not pool.is_empty():
		lair_room = pool[_content_rng.randi() % pool.size()]
		room_kinds[lair_room] = "larder"

	var rest: Array[String] = []
	for nm in sconce_rooms:
		if not room_kinds.has(nm):
			rest.append(nm)
	_shuffle(rest)
	var cycle := ["gallery", "crypt", "scriptorium"]
	var i := 0
	sealed_kind_overrides = 0
	for nm in rest:
		# A sconce chamber with no prop-safe wall is a GALLERY: its frames hang on the walls and
		# the builder skips the centre bench (same rule as the cistern re-deal below).
		if prop_sides(nm).is_empty():
			room_kinds[nm] = "gallery"
			sealed_kind_overrides += 1
			continue
		if i == 0:
			room_kinds[nm] = "chapel"
		else:
			room_kinds[nm] = cycle[(i - 1) % cycle.size()]
		i += 1

	var others: Array[String] = []
	for nm in chamber_names:
		if not room_kinds.has(nm):
			others.append(nm)
	_shuffle(others)
	var entry_cycle := ["cells", "cistern", "scriptorium"]
	var j := 0
	var well_dealt := false
	for nm in others:
		# ⚠️ A CHAMBER WITH A DOORWAY IN EVERY WALL GETS THE ONE KIND THAT TOUCHES NO WALL
		# (2026-09-12). Every other builder hugs a doorway-free "back" wall, and with none to
		# choose `_back_side()` fell back to north — seed 606 put a scriptorium lectern squarely
		# in Chamber12's north doorway (walk_dungeon: 1 blocked of 60). The cistern is water and
		# a grate at the centre, collider-free.
		if prop_sides(nm).is_empty():
			room_kinds[nm] = "cistern"
			sealed_kind_overrides += 1
			continue
		if not well_dealt:
			room_kinds[nm] = "well"
			well_dealt = true
			continue
		var r: Rect2i = _room_rect[nm]
		var big: bool = mini(r.size.x, r.size.y) >= 2 and r.size.x * r.size.y >= 6
		var k: String = entry_cycle[j % entry_cycle.size()]
		j += 1
		if k == "cells" and not big:
			k = "cistern"
		room_kinds[nm] = k
	# The spawn and bed chambers are dealt by name above; the same four-door rule applies. The
	# bed stands at its room's centre and the water sheet has no collider, so a flooded crypt
	# is still a bed room.
	# The spawn chamber follows the same rule. The BED chamber stays a crypt whatever its walls:
	# the bed is the room, and `DungeonRooms._build_crypt` simply builds no sarcophagi there when
	# no wall is prop-safe.
	if prop_sides(spawn_room).is_empty() and room_kinds.get(spawn_room, "") != "cistern":
		room_kinds[spawn_room] = "cistern"
		sealed_kind_overrides += 1


# ⚠️ THE WALLS A FLOOR PROP MAY HUG (2026-09-12). `free_sides()` says which walls carry no
# doorway; this also drops a wall when a doorway in a PERPENDICULAR wall lies within
# PROP_LANE of it — that doorway's inward line runs straight along the props (the bot stood
# 130 s against a sarcophagus row in seed 101's crypt and a chapel's altar+pew in seed 202).
# Props reach up to 2.4 m from their wall, plus a capsule: 3.0 m.
const PROP_LANE := 3.0

func prop_sides(room_name: String) -> Array:
	if not _room_rect.has(room_name):
		return []
	var r: Rect2i = _room_rect[room_name]
	var x0: float = (r.position.x - GRID * 0.5) * CELL
	var x1: float = (r.position.x + r.size.x - GRID * 0.5) * CELL
	var z0: float = (r.position.y - GRID * 0.5) * CELL
	var z1: float = (r.position.y + r.size.y - GRID * 0.5) * CELL
	var out: Array = []
	for sd in free_sides(room_name):
		var ok := true
		for d in doorways:
			var p: Vector2 = d["pos"]
			var on_room: bool
			if d["dir"] == "x":
				on_room = p.y > z0 - 0.01 and p.y < z1 + 0.01 \
					and (absf(p.x - x0) < 0.01 or absf(p.x - x1) < 0.01)
			else:
				on_room = p.x > x0 - 0.01 and p.x < x1 + 0.01 \
					and (absf(p.y - z0) < 0.01 or absf(p.y - z1) < 0.01)
			if not on_room:
				continue
			var dist: float
			if absf(sd.x) > 0.5:
				dist = absf(p.x - (x0 if sd.x < 0.0 else x1))
			else:
				dist = absf(p.y - (z0 if sd.y < 0.0 else z1))
			if dist > 0.01 and dist < PROP_LANE:
				ok = false
				break
		if ok:
			out.append(sd)
	return out


func kind_of(room_name: String) -> String:
	return room_kinds.get(room_name, "")


# Which room a world position is in ("" outside the lattice). The map and the entry-triggered
# scares both need it; it is the inverse of _cell_to_world over `_cell_room`.
func room_at(pos: Vector3) -> String:
	var cx: int = int(floor(pos.x / CELL + GRID * 0.5))
	var cy: int = int(floor(pos.z / CELL + GRID * 0.5))
	if cx < 0 or cy < 0 or cx >= GRID or cy >= GRID:
		return ""
	return _cell_room.get("%d,%d" % [cx, cy], "")


# ── Graph queries ───────────────────────────────────────────────────────────────
func _all_pairs_bfs() -> Dictionary:
	var out: Dictionary = {}
	for nm in chamber_names:
		out[nm] = _bfs(nm)
	return out


func _bfs(start: String) -> Dictionary:
	var dist: Dictionary = {start: 0}
	var queue: Array = [start]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for nxt in _adj.get(cur, []):
			if dist.has(nxt):
				continue
			dist[nxt] = int(dist[cur]) + 1
			queue.append(nxt)
	return dist


# Distances between every pair of ROOMS (not just chambers) — dungeon.gd uses this
# to keep the Matron's spawn at least N rooms away from the player.
func room_distance(a: String, b: String) -> int:
	var d := _bfs(a)
	return int(d.get(b, -1))


func adjacency() -> Dictionary:
	return _adj


# The room-by-room BFS route from `a` to `b`, inclusive of both. Used by
# walk_dungeon.gd to build a walkable waypoint list, and by dungeon.gd to reason
# about how far away the Matron is in ROOMS rather than in metres.
func path_between(a: String, b: String) -> Array:
	var prev: Dictionary = {a: ""}
	var queue: Array = [a]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == b:
			break
		for nxt in _adj.get(cur, []):
			if prev.has(nxt):
				continue
			prev[nxt] = cur
			queue.append(nxt)
	if not prev.has(b):
		return []
	var out: Array = []
	var node: String = b
	while node != "":
		out.push_front(node)
		node = prev[node]
	return out


# The world-space centre of the doorway joining two adjacent rooms, or Vector3.INF.
# ⚠️ A straight line between two room CENTRES does not generally pass through the
# doorway that connects them, so anything driving a body between rooms has to aim
# at the opening itself.
func doorway_between(a: String, b: String) -> Vector3:
	for i in range(_doorway_rooms.size()):
		var pair: Array = _doorway_rooms[i]
		if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
			var p: Vector2 = doorways[i]["pos"]
			return Vector3(p.x, 0.0, p.y)
	return Vector3.INF


func room_cells(room_name: String) -> Array:
	return _room_cells.get(room_name, [])


func room_rect(room_name: String) -> Rect2i:
	return _room_rect.get(room_name, Rect2i())


func room_center_world(room_name: String) -> Vector3:
	if not _room_rect.has(room_name):
		return Vector3.ZERO
	var r: Rect2i = _room_rect[room_name]
	var p := _cell_to_world(r.position, r.size)
	return Vector3(p.x, 0.0, p.y)


# Every room reachable from the spawn. The test asserts this covers every room.
func reachable_rooms() -> Array:
	return _bfs(spawn_room).keys()


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _content_rng.randi() % (i + 1)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
