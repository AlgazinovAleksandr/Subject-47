extends RefCounted

# THE HOUSE MAP'S FAIRNESS FILTERS AND ITS HARNESS BOT, in one place (2026-09-24 e).
#
#   const MazeCuration := preload("res://tests/lib/maze_curation.gd")
#   MazeCuration.fresh(ui, layout_seed, sub_seed)     # the layout, exactly as open() builds it
#   var f: Dictionary = MazeCuration.analyse(ui)       # filters (a)-(c), measured
#   var bot = MazeCuration.new(ui)
#   var r: Dictionary = bot.play()                     # {won, caught, by_patrol, stalled, t}
#
# Three consumers: `probe_maze_curate.gd` chooses `MazeChaseUI.CURATED_SEEDS` with it,
# `check_maze_gen.gd` asserts filters (a)-(c) on every curated seed with it, and
# `check_maze_chase.gd` replays the win-rate band with it. ⚠️ One copy, so the three cannot
# drift — the bot below used to be pasted verbatim into two files ("deliberately kept verbatim
# so the probe and the assertion measure the same player").
#
# ⚠️ NO `class_name` (see tests/lib/scenes.gd for why), and it only ever touches the UI through
# `get`/`call`, so it compiles without the game's class cache.

const DT := 1.0 / 60.0
# ⭐ THE BOT. Unchanged from `check_maze_chase.gd`'s ESCAPE pass: it walks the corridor route
# to the nearest live fragment, then to the key, stepping round a cell a monster stands in, at
# 200 px/s (95 % of the icon's `PLAYER_SPEED` 210 — a competent, not a perfect, player).
const BOT_SPEED := 200.0
const AVOID_RADIUS := 70.0
const ESCAPE_TIMEOUT := 100.0
# (d) A DEAD LOOP: the bot's corridor distance to its current goal has not reached a new low
# for this long while it is neither caught nor won. The bot only ever steps downhill, so this
# can only mean it is pinned on geometry or shuttling between two cells.
const STALL_S := 10.0

# ⭐ (a) THE RACE MARGIN. The hunter must be unable to reach a cell the tour cannot avoid until
# at least this long AFTER the player can. 1.2 s is `MazeChaseUI.SNARE_HOLD`: one snare's pin
# must not be able to turn a won race into a lost one. The player's time is taken at
# `PLAYER_SPEED` along the tour; the hunter's is `MONSTER_START_DELAY` plus its own shortest
# corridor route at `MONSTER_SPEED` — a LOWER bound on when it could be there, because it
# chases the player rather than heading for the cell, so the filter errs against the layout.
const RACE_MARGIN_S := 1.2
# (b) A waypoint is "behind the hunter" if, when the hunter wakes, it is this many cells nearer
# to the waypoint than the player still is.
const BEHIND_MARGIN_CELLS := 1
# (c) How long the patroller's free circuit is simulated for (game time after the head start).
const PATROL_SIM_S := 45.0

var ui: Node
var speed: float = BOT_SPEED
var _goal := Vector2.ZERO
var _goal_for := -1
var _fields: Dictionary = {}


func _init(u: Node, bot_speed: float = BOT_SPEED) -> void:
	ui = u
	speed = bot_speed


# The layout for `layout_seed` with the patroller's circuit on `sub_seed` — byte-for-byte what
# `MazeChaseUI._load_layout()` + `open()` build (seed → generate; the patrol RNG is reseeded by
# `_reset_positions()`). `sub_seed == layout_seed` is the circuit the game actually plays.
static func fresh(u: Node, layout_seed: int, sub_seed: int) -> void:
	u.set("patrol_seed", sub_seed)
	seed(layout_seed)
	u.call("_generate_maze")
	u.call("_reset_positions")
	# The harness gates the monsters on the head start itself (`t >= grace` in play()).
	u.set("_monster_start_timer", 0.0)


static func _k(u: Node, name: String) -> Variant:
	return (u.get_script() as Script).get(name)


# ---------------------------------------------------------------- the bot

func reset() -> void:
	_goal_for = -1
	_fields.clear()


func _field(cell: Vector2i) -> Dictionary:
	if not _fields.has(cell):
		_fields[cell] = ui.call("_bfs_distances", cell)
	return _fields[cell]


# The nearest live fragment by corridor distance, or the key once every fragment is in hand.
func goal() -> Vector2:
	var frags: Array = ui.get("_fragments")
	if frags.is_empty():
		return ui.get("_target_pos")
	if _goal_for != frags.size():
		_goal_for = frags.size()
		var pcell: Vector2i = ui.call("_cell_at", ui.get("_player_pos"))
		var field: Dictionary = _field(pcell)
		var best: Vector2 = frags[0]
		var best_d: int = 1 << 30
		for f: Vector2 in frags:
			var d: int = int(field.get(ui.call("_cell_at", f), 1 << 30))
			if d < best_d:
				best_d = d
				best = f
		_goal = best
	return _goal


# check_maze_chase.gd's corridor walk, unchanged: prefer a downhill step that is not into a
# monster; take the blocked one only if there is no alternative.
func step_toward(dt: float, target: Vector2) -> void:
	var pp: Vector2 = ui.get("_player_pos")
	var pcell: Vector2i = ui.call("_cell_at", pp)
	var tcell: Vector2i = ui.call("_cell_at", target)
	var aim := target
	if pcell != tcell:
		var field: Dictionary = _field(tcell)
		var danger: Array[Vector2] = [ui.get("_monster_pos"), ui.get("_patrol_pos")]
		var best := pcell
		var best_d: int = field.get(pcell, 1 << 30)
		var fallback := pcell
		var fallback_d: int = best_d
		for n in ui.call("_open_neighbours", pcell):
			if not field.has(n) or int(field[n]) >= best_d:
				if field.has(n) and int(field[n]) < fallback_d:
					fallback_d = int(field[n])
					fallback = n
				continue
			var centre: Vector2 = ui.call("_cell_center", n)
			var blocked := false
			for d in danger:
				if centre.distance_to(d) < AVOID_RADIUS:
					blocked = true
					break
			if blocked:
				if int(field[n]) < fallback_d:
					fallback_d = int(field[n])
					fallback = n
				continue
			best_d = int(field[n])
			best = n
		if best == pcell:
			best = fallback
		if best != pcell:
			aim = ui.call("_cell_center", best)
	var dir := (aim - pp)
	if dir.length() < 0.01:
		return
	var step: Vector2 = pp + dir.normalized() * speed * dt
	ui.set("_player_pos", ui.call("_resolve_wall_slide", pp, step, float(_k(ui, "ICON_HALF_EXTENT"))))


# One whole attempt with the full roster live, decided by the UI's own `_is_won()` and its own
# pickup / glass path (`_check_fragments()` → `_check_glass()`). Call after `fresh()`.
func play(timeout: float = ESCAPE_TIMEOUT) -> Dictionary:
	reset()
	var grace: float = float(_k(ui, "MONSTER_START_DELAY"))
	var catch_radius: float = float(_k(ui, "CATCH_RADIUS"))
	var t := 0.0
	var best_d: int = 1 << 30
	var best_goal := Vector2i(-1, -1)
	var since_best := 0.0
	var out := {"won": false, "caught": false, "by_patrol": false, "stalled": false,
		"timeout": false, "t": 0.0, "glass": false}
	while t < timeout:
		step_toward(DT, goal())
		if t >= grace:
			ui.call("_tick_monster", DT)
			ui.call("_tick_patroller", DT)
			ui.call("_check_snares", null)
		ui.call("_check_fragments")
		t += DT
		var pp: Vector2 = ui.get("_player_pos")
		var d_h: float = (ui.get("_monster_pos") as Vector2).distance_to(pp)
		var d_p: float = (ui.get("_patrol_pos") as Vector2).distance_to(pp)
		if d_h <= catch_radius or d_p <= catch_radius:
			out["caught"] = true
			out["by_patrol"] = d_p <= catch_radius and d_h > catch_radius
			break
		if bool(ui.call("_is_won")):
			out["won"] = true
			break
		# (d) progress toward the CURRENT goal, in corridor cells.
		var gcell: Vector2i = ui.call("_cell_at", goal())
		var d_goal: int = int(_field(gcell).get(ui.call("_cell_at", pp), 1 << 30))
		if gcell != best_goal:
			best_goal = gcell
			best_d = d_goal
			since_best = 0.0
		elif d_goal < best_d:
			best_d = d_goal
			since_best = 0.0
		else:
			since_best += DT
			if since_best >= STALL_S:
				out["stalled"] = true
				break
	out["t"] = t
	out["glass"] = bool(ui.get("_glass_broken"))
	if not out["won"] and not out["caught"] and not out["stalled"]:
		out["timeout"] = true
	return out


# ---------------------------------------------------------------- the fairness filters

# BFS over the maze's open edges with `blocked` cells removed.
static func _bfs_without(u: Node, from: Vector2i, blocked: Dictionary) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for n: Vector2i in u.call("_open_neighbours", cur):
			if dist.has(n) or blocked.has(n):
				continue
			dist[n] = int(dist[cur]) + 1
			queue.append(n)
	return dist


# One shortest path from `a` to `b` (exclusive of `a`, inclusive of `b`), walked back down the
# distance field. Every mandatory cell lies on EVERY path, so on this one too — it is the
# complete candidate list for the cut-vertex test.
static func _shortest_path(u: Node, a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var field: Dictionary = u.call("_bfs_distances", a)
	var path: Array[Vector2i] = []
	var walk := b
	var guard := 0
	while walk != a and guard < 10000:
		guard += 1
		path.push_front(walk)
		var here: int = int(field.get(walk, 0))
		for n: Vector2i in u.call("_open_neighbours", walk):
			if int(field.get(n, 1 << 30)) == here - 1:
				walk = n
				break
	return path


# ⭐ Measure one generated layout against filters (a)-(c). Nothing here trusts a value the
# generator recorded about itself except `_tour` (the order the player walks) — every distance,
# cut vertex and circuit is recomputed.
#
#   mandatory  — every cell the tour CANNOT avoid: for each leg (start → hammer → key), a cell
#                whose removal disconnects the leg's ends (a cut vertex for that leg), plus the
#                leg's own end. Each carries the player's arrival time along the tour.
#   (a) race   — min over mandatory cells (except the key's own cell, which the glass shuts to
#                the hunter) of hunter_arrival − player_arrival; FAIL if ≤ RACE_MARGIN_S.
#   (b) behind — the hunter's start cell is itself mandatory, or when it wakes it is nearer the
#                first waypoint than the player still is (by BEHIND_MARGIN_CELLS).
#   (c) patrol — the patroller's free circuit (the game's own `_tick_patroller`, on the layout's
#                own sub-seed, the player out of its reach) enters a mandatory cell.
static func analyse(u: Node) -> Dictionary:
	var cell_px: float = float(_k(u, "CELL_SIZE"))
	var v_player: float = float(_k(u, "PLAYER_SPEED"))
	var v_hunter: float = float(_k(u, "MONSTER_SPEED"))
	var grace: float = float(_k(u, "MONSTER_START_DELAY"))
	var start: Vector2i = u.get("_start_cell")
	var target: Vector2i = u.get("_target_cell")
	var tour: Array = (u.get("_tour") as Array).duplicate()
	if tour.is_empty():
		tour.append(target)
	var hunter_cell: Vector2i = u.call("_cell_at", u.get("_monster_start"))
	# The glass room is solid to the hunter until the player breaks it.
	var h_dist: Dictionary = _bfs_without(u, hunter_cell, {target: true})

	var mandatory: Array = []     # [{cell, cells_walked, leg}]
	var cut_count := 0
	var offset := 0
	var from := start
	var leg := 0
	for leg_end: Vector2i in tour:
		var path := _shortest_path(u, from, leg_end)
		for i in path.size():
			var c: Vector2i = path[i]
			var is_end: bool = c == leg_end
			var is_cut := false
			if not is_end:
				is_cut = not _bfs_without(u, from, {c: true}).has(leg_end)
			if is_cut:
				cut_count += 1
			if is_end or is_cut:
				mandatory.append({"cell": c, "walked": offset + i + 1, "leg": leg})
		offset += path.size()
		from = leg_end
		leg += 1

	# (a) the race
	var min_margin := INF
	var worst_cell := Vector2i(-1, -1)
	for m in mandatory:
		var c: Vector2i = m["cell"]
		if c == target:
			continue
		var t_p: float = float(m["walked"]) * cell_px / v_player
		var t_h: float = INF
		if h_dist.has(c):
			t_h = grace + float(h_dist[c]) * cell_px / v_hunter
		var margin: float = t_h - t_p
		if margin < min_margin:
			min_margin = margin
			worst_cell = c

	# (b) behind the hunter
	var behind := false
	var behind_why := ""
	for m in mandatory:
		if m["cell"] == hunter_cell:
			behind = true
			behind_why = "hunter start %s is a cell the tour cannot avoid" % [hunter_cell]
	var first: Vector2i = tour[0]
	var lead_cells: float = grace * v_player / cell_px
	var d_first: int = int((u.call("_bfs_distances", start) as Dictionary).get(first, 1 << 20))
	var player_left: float = maxf(0.0, float(d_first) - lead_cells)
	var hunter_to_first: int = int(h_dist.get(first, 1 << 20))
	if float(hunter_to_first + BEHIND_MARGIN_CELLS) < player_left:
		behind = true
		behind_why = "hunter %d cells from %s at wake-up, the player %.1f" % [
			hunter_to_first, first, player_left]

	# (c) the patroller's free circuit on the layout's OWN sub-seed
	var mand_set: Dictionary = {}
	for m in mandatory:
		if m["cell"] != target:
			mand_set[m["cell"]] = true
	var saved_player: Vector2 = u.get("_player_pos")
	var saved_patrol: Vector2 = u.get("_patrol_pos")
	var saved_seed: int = int(u.get("patrol_seed"))
	u.call("_reset_positions")
	u.set("_player_pos", Vector2(-100000.0, -100000.0))   # out of PATROL_AGGRO for the whole run
	var patrol_hit := false
	var patrol_hit_cell := Vector2i(-1, -1)
	var patrol_hit_t := 0.0
	var pt := 0.0
	var visited: Dictionary = {}
	while pt < PATROL_SIM_S:
		u.call("_tick_patroller", DT)
		pt += DT
		var pc: Vector2i = u.call("_cell_at", u.get("_patrol_pos"))
		visited[pc] = true
		if mand_set.has(pc) and not patrol_hit:
			patrol_hit = true
			patrol_hit_cell = pc
			patrol_hit_t = pt + grace
	# Put the layout back exactly as a fresh open would have it.
	u.set("patrol_seed", saved_seed)
	u.call("_reset_positions")
	u.set("_monster_start_timer", 0.0)
	u.set("_player_pos", saved_player)
	u.set("_patrol_pos", saved_patrol)

	return {
		"tour": int(u.get("_tour_length")),
		"mandatory": mandatory.size(),
		"cuts": cut_count,
		"min_margin": min_margin,
		"worst_cell": worst_cell,
		"race_ok": min_margin > RACE_MARGIN_S,
		"behind": behind,
		"behind_why": behind_why,
		"patrol_hit": patrol_hit,
		"patrol_hit_cell": patrol_hit_cell,
		"patrol_hit_t": patrol_hit_t,
		"patrol_cells": visited.size(),
		"fair": min_margin > RACE_MARGIN_S and not behind and not patrol_hit,
	}
