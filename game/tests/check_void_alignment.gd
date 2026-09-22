extends SceneTree

# Real player E-ray, physical seal, protected stance, and saved event state.
#
# ⭐ 2026-09-20. The puzzle became THREE viewpoints and the far wing became a CHAIN, so this
# file now proves, through the shipping raycast and real physics sweeps:
#   * a wrong keystone press costs exactly WRONG_PRESS_PANIC (6) and opens nothing, with a
#     right press as the control that it adds none;
#   * one and two held shapes leave the seal a solid wall; only the third retracts it;
#   * the stone plate intercepts the twist note's ray until the cradle is completed, and E on
#     the cradle without the shard is a no-op (both controls);
#   * a return from the ending with the twist already read finds the plate gone.
#
# ⭐ 2026-09-20 PASS 2. The three shapes became a DOOR, a BED and a WINDOW in three corners and
# the prompt became place-gated, so this file also carries the MEASUREMENT that set the
# tolerances (it was a throwaway probe; a number nobody re-measures is a number that rots):
#   * the REGION SWEEP — a 0.3 m grid over each view's own tile at eye 1.65 +/- 0.15 m facing
#     the shape +/- 15 deg must align for >= REGION_FLOOR of its cells. The user's target,
#     because a human standing anywhere on a 1.6 m tile has to be able to hit it;
#   * the CONTROLS — every adjacent tile centre aligns for NO view and can interact with NO
#     keystone, and no shape aligns from another shape's tile;
#   * the GATE — a wrong press is only possible from inside the 1.5 m place gate at all;
#   * the GEOMETRY — every piece of every shape floats clear of the abyss walls and above the
#     causeway, measured from its own world AABB.
#
# ⭐ 2026-09-20 PASS 3. The keystones are no longer standing at their tiles: each viewpoint has
# an EMPTY SOCKET and the object that fills it is hidden elsewhere in the level. So this file
# also proves, through the shipping ray:
#   * a socket refuses E with NOTHING in hand and with the WRONG object in hand (two controls),
#     costs no panic either way, and accepts only its own;
#   * a seated anchor becomes that view's keystone — its own silhouette, distinct per view,
#     inside a socket in the view's own tint;
#   * `interact_view()` on an EMPTY socket can neither solve nor charge (the wrong-press cost
#     belongs to a wrong ANGLE, not to an empty hand);
#   * the three anchors survive a navigation restore: taken ones stay gone, carried ones stay
#     carried, seated ones stay seated.
const WRONG_PRESS_PANIC := 6.0
const PANIC_MAX := 50.0
const REGION_FLOOR := 0.70
const GRID_STEP := 0.30
const EYE_HEIGHTS := [1.50, 1.65, 1.80]
const YAWS := [-15.0, 0.0, 15.0]
# Per view: the tile it stands on, and the neighbouring tile centres that are its control.
const TILES := [
	{"size": Vector2(2.0, 2.2), "near": [Vector2(-1.8, 47.0), Vector2(-1.8, 44.0),
		Vector2(-5.6, 47.4), Vector2(-5.6, 43.6)], "key": ""},
	{"size": Vector2(1.6, 1.6), "near": [Vector2(-0.2, 45.5)], "key": "KeystoneBed"},
	{"size": Vector2(1.6, 1.6), "near": [Vector2(-1.8, 44.0), Vector2(-5.6, 43.6)],
		"key": "KeystoneWindow"},
]
# The abyss's inner faces (level_3.gd:_build_tile_hall) and the tiles' top.
const ABYSS := AABB(Vector3(-8.9, -8.0, 40.6), Vector3(11.7, 8.0, 9.8))
var _start := 0
var _started := false
var _done := false
var _checks := 0
var _fails := 0
var _level: Node3D
var _player: CharacterBody3D
var _puzzle: StaticBody3D
const SCENE := "res://scenes/level_3.tscn"

func _initialize() -> void:
	_start = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if not _done and Time.get_ticks_msec() - _start > 50000:
		_ok("test completed before timeout", false)
		_finish()
	if not _started:
		_started = true
		_run.call_deferred()
	return _done

func _ok(label: String, condition: bool) -> void:
	_checks += 1
	print("  %s %s" % ["OK" if condition else "FAIL", label])
	if not condition:
		_fails += 1

func _ticks(count: int) -> void:
	for i in range(count):
		await physics_frame

func _place(at: Vector3, look: Vector3) -> void:
	_player.global_position = at + Vector3(0, 0.03, 0)
	_player.velocity = Vector3.ZERO
	_player.call("ai_look_at", look)
	_player.force_update_transform()
	_player.get_node("Camera3D").force_update_transform()

func _seal_hit() -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(-8.4, 1, 45.5), Vector3(-9.5, 1, 45.5), 1)
	return _level.get_world_3d().direct_space_state.intersect_ray(q)

func _run() -> void:
	change_scene_to_file(SCENE)
	await _ticks(12)
	_level = current_scene
	_player = _level.get_node("Player")
	_puzzle = _level.get_node("AlignmentKeystone")
	_player.set("ai_active", true)
	_ok("exactly five live creatures and no entrance creature", _level.call("get_stalkers").size() == 5
		and not _level.has_node("CreatureA"))
	await create_timer(7.0).timeout
	_ok("idle entrance survives beyond the old 6.4-second kill", current_scene == _level
		and not root.get_node("Screamer").get("_is_triggering"))
	var fragment := _level.get_node("WardFragment")
	_place(Vector3(-2.6, 0, 11.5), fragment.global_position)
	await _ticks(2)
	_ok("Ward fragment is reached through the shipping ray", _player.call("ai_interact_target") == fragment)
	_player.call("ai_interact")
	await _ticks(2)
	_ok("touch arms the fragment without changing it while watched", fragment.armed and not fragment.spent)
	_player.call("ai_look_at", Vector3(-2.6, 1.3, 5))
	await _ticks(3)
	_ok("looking away rearranges the physical sculpture once", fragment.spent
		and absf(fragment.sculpture.get_node("SuspendedAssembly").rotation.z) > 0.2)

	# ── the measured region, the controls, and the geometry ───────────────────────
	_region_sweep()
	_geometry_bounds()

	# ── the sockets and their two refusals ───────────────────────────────────────
	await _socket_controls()

	# ── the wrong press. ⚠️ FOUND, not hardcoded: the island is 2.0 x 2.2 and its tolerances
	# are set from the sweep above, so "0.75 m off the eye" stopped being a wrong answer the
	# moment the region was widened for a human. The test asks the level where a wrong press
	# is still possible — inside the 1.5 m place gate, on the island, and not aligned — and
	# fails loudly if the puzzle has become unfailable.
	var wrong := _find_wrong_stance(0)
	_ok("there is somewhere on the island a press is still REFUSED (%s)" % wrong,
		wrong != Vector3.INF)
	if wrong == Vector3.INF:
		wrong = Vector3(-3.6, 0, 45.5)
	_place(wrong, _puzzle.global_position)
	_player.call("kill_flashlight")
	await _ticks(3)
	var panic_before := float(_player.call("get_panic_ratio"))
	_ok("CONTROL: unsolved seal physically blocks the passage", not _seal_hit().is_empty())
	_ok("a refused stance still reaches the keystone (the gate is PLACE, not angle)",
		_player.call("ai_interact_target") == _puzzle)
	_player.call("ai_interact")
	await _ticks(3)
	_ok("wrong perspective cannot open the seal", not _puzzle.call("view_solved", 0)
		and not _seal_hit().is_empty())
	var cost := (float(_player.call("get_panic_ratio")) - panic_before) * PANIC_MAX
	# ⚠️ 6.0 is THE USER'S NUMBER (2026-09-20). This assertion exists so a future tuning pass
	# has to change the spec to change it. Decay is 3.5/s, so three ticks cost ~0.2.
	_ok("a wrong press costs exactly WRONG_PRESS_PANIC", cost > WRONG_PRESS_PANIC - 0.6
		and cost < WRONG_PRESS_PANIC + 0.1)
	if cost <= WRONG_PRESS_PANIC - 0.6 or cost >= WRONG_PRESS_PANIC + 0.1:
		print("      measured %.3f panic" % cost)
	_ok("the stone knocks where the wrong press was", _puzzle.get("_knock") != null
		and (_puzzle.get("_knock") as AudioStreamPlayer3D).stream != null)

	# ⭐ THE PLACE GATE, through the shipping ray. From the tile NEXT DOOR — the exact mistake
	# the 13:10 playtest made twenty times — there must be no prompt and no target at all.
	await _gate_controls()

	# ── shape 1 of 3: the DOOR, from the island ──
	_place(Vector3(-3.6, 0, 45.5), _puzzle.global_position)
	await _ticks(3)
	_ok("the DOOR aligns from the stable island", _puzzle.call("is_aligned", 0))
	_ok("…and the other two shapes do NOT align from here",
		not _puzzle.call("is_aligned", 1) and not _puzzle.call("is_aligned", 2))
	_ok("aligned keystone is within ordinary interaction reach", _player.call("ai_interact_target") == _puzzle)
	_ok("fixed lighting supports a torch-off solve", not _player.call("is_flashlight_on")
		and _level.get_node("Light_TileHall").light_energy >= 0.6)
	var stance := float(_player.call("get_panic_ratio"))
	await create_timer(1.0).timeout
	_ok("holding the puzzle stance does not charge panic", float(_player.call("get_panic_ratio")) <= stance)
	var right_before := float(_player.call("get_panic_ratio"))
	_player.call("ai_interact")
	await _ticks(4)
	_ok("real E holds the island's shape", _puzzle.call("view_solved", 0))
	_ok("CONTROL: a RIGHT press adds no panic at all",
		float(_player.call("get_panic_ratio")) <= right_before)
	_ok("one shape of three leaves the seal a solid wall",
		not _puzzle.solved and not _seal_hit().is_empty())

	# ── shape 2 of 3: the BED, from the spine's first tile ──
	var bed := _puzzle.get_node("KeystoneBed")
	_level.call("take_anchor", "slat")
	_place(Vector3(1.4, 0, 45.5), bed.global_position)
	await _ticks(3)
	_ok("the bed's socket invites the slat", String(bed.call("prompt_text")).begins_with("E — Set"))
	_player.call("ai_interact")
	await _ticks(2)
	_ok("E seats the slat and the socket becomes the bed's keystone",
		bool(_puzzle.call("socket_filled", 1)) and String(_level.call("carried_anchor")) == "")
	_ok("the BED aligns from the spine's first tile", _puzzle.call("is_aligned", 1))
	_ok("…and the DOOR and WINDOW do NOT align from here",
		not _puzzle.call("is_aligned", 0) and not _puzzle.call("is_aligned", 2))
	_ok("the bed keystone is its own interactable", _player.call("ai_interact_target") == bed)
	_player.call("ai_interact")
	await _ticks(4)
	_ok("real E holds the bed", _puzzle.call("view_solved", 1))
	_ok("two shapes of three STILL leave the seal a solid wall",
		not _puzzle.solved and not _seal_hit().is_empty())

	# ── shape 3 of 3: the WINDOW, from the south branch's middle tile ──
	var window := _puzzle.get_node("KeystoneWindow")
	_level.call("take_anchor", "latch")
	_place(Vector3(-3.6, 0, 42.8), window.global_position)
	await _ticks(3)
	_player.call("ai_interact")
	await _ticks(2)
	_ok("E seats the latch in the window's socket", bool(_puzzle.call("socket_filled", 2)))
	_ok("the three seated keystones are three DIFFERENT objects", _distinct_keystones())
	_ok("the WINDOW aligns from the south branch's middle tile", _puzzle.call("is_aligned", 2))
	_ok("…and the DOOR and BED do NOT align from here",
		not _puzzle.call("is_aligned", 0) and not _puzzle.call("is_aligned", 1))
	_ok("the window keystone is its own interactable", _player.call("ai_interact_target") == window)
	_player.call("ai_interact")
	await _ticks(6)
	_ok("the third shape solves the puzzle", _puzzle.solved and _puzzle.call("solved_count") == 3)
	_ok("solving removes the real doorway obstruction", _seal_hit().is_empty())
	_ok("reveal is recorded immediately and cannot repeat", _puzzle.reveal_spent and not _puzzle.call("can_interact"))
	var footing := _player.global_position
	await create_timer(4.0).timeout
	_ok("reveal leaves the player on stable footing", _player.global_position.distance_to(footing) < 0.05)
	_ok("giant echo is lit and the stone reply exists", _puzzle.get("_echo_light").light_energy > 0.4
		and _puzzle.get("_sound").stream != null)
	# Physically walk the southern branch in both directions; the full route covers north.
	for target in [Vector3(-3.6, 0, 42.8), Vector3(-5.6, 0, 43.6), Vector3(-7, 0, 44.5),
			Vector3(-7.7, 0, 45.5), Vector3(-7, 0, 44.5), Vector3(-5.6, 0, 43.6),
			Vector3(-3.6, 0, 42.8), Vector3(-1.8, 0, 44), Vector3(-0.2, 0, 45.5), Vector3(-3.6, 0, 45.5)]:
		await _walk_to(target)

	await _chain()

	var data: Dictionary = _level.call("save_progress")
	_ok("snapshot includes both completed events", data.get("alignment_solved", false)
		and data.get("reveal_spent", false) and data.get("ward_spent", false))
	_ok("…and the far wing's chain", bool(data.get("shard_taken", false))
		and bool(data.get("cradle_done", false)))
	root.get_node("GameState").call("save_level_progress", 8, data)
	change_scene_to_file(SCENE)
	await _ticks(12)
	_level = current_scene
	_player = _level.get_node("Player")
	_puzzle = _level.get_node("AlignmentKeystone")
	_ok("navigation restore opens seal without replaying reveal", _puzzle.solved and _seal_hit().is_empty()
		and _puzzle.get("_sequence") == null)
	_ok("…and all three viewpoints come back solved",
		_puzzle.call("view_solved", 0) and _puzzle.call("view_solved", 1) and _puzzle.call("view_solved", 2))
	_ok("navigation restore retains rearranged sculpture", _level.get_node("WardFragment").spent)
	# ⭐ pass 3: the quest survives a back-door return. All three objects were seated before the
	# snapshot, so none may be lying in the level again and all three sockets must be filled —
	# otherwise walking out and back in hands the player three fresh anchors and three empty
	# sockets, with the shapes already held.
	var still_lying: Array = []
	for id in ["handle", "slat", "latch"]:
		if _level.get_node_or_null("Anchor_" + id) != null:
			still_lying.append(id)
	_ok("navigation restore leaves no taken anchor lying in the level again: %s"
		% ("none" if still_lying.is_empty() else ", ".join(still_lying)), still_lying.is_empty())
	_ok("…and all three sockets come back filled",
		(_level.get_node("AlignmentKeystone").call("sockets_filled") as Array) == [true, true, true])
	# ⭐ pass 4: the plate is the HIDDEN NOTE'S now, so what a snapshot has to carry is that the
	# page was read — `_notes_read` and the `hidden_note_read` key — not that the cradle was done.
	_ok("navigation restore keeps the twist note exposed", _level.get_node_or_null("SanctumPlate") == null)
	# ⭐ pass 5: the plate is no longer the only gate — the note refuses on its own (Issue 242).
	# A restore has to keep the two consistent: no stone, no refusal.
	var tw2 = _level.call("twist_note")
	_ok("…and the note's own gate came back OPEN with it (prompt '%s')"
		% (tw2.call("prompt_text") if tw2 != null else "-"),
		tw2 != null and not bool(_level.call("plate_stands"))
		and String(tw2.call("prompt_text")) == "E — Read the page.")
	_ok("…and the secret wall stays open across the return", bool(_level.call("secret_open")))

	# ⭐ Coming back through the ending's door with a CLEARED snapshot. This is the case the
	# early `data.is_empty()` return used to swallow: the plate came back over a note the
	# player had already read, in front of a door that was already unlocked.
	root.get_node("GameState").call("save_level_progress", 8, {})
	root.get_node("GameState").set("twist_read", true)
	root.get_node("GameState").set("entered_from_ahead", true)
	change_scene_to_file(SCENE)
	await _ticks(12)
	_level = current_scene
	_ok("a return from the ending does not re-seal the twist note",
		_level.get_node_or_null("SanctumPlate") == null)
	root.get_node("GameState").set("entered_from_ahead", false)

	root.get_node("Screamer").call("trigger")
	await create_timer(3.0).timeout
	await _ticks(8)
	_ok("death resets puzzle and optional event", not current_scene.get_node("AlignmentKeystone").solved
		and not current_scene.get_node("WardFragment").spent)
	_ok("death puts the stone plate back over the twist note",
		current_scene.get_node_or_null("SanctumPlate") != null)
	_finish()


# ⭐ THE SOCKETS (2026-09-20 pass 3), driven by the shipping ray from the island.
#
# ⚠️ BOTH REFUSALS ARE CONTROLS, and both must be free. The level already charges 6 panic for a
# wrong ANGLE; charging again for a wrong OBJECT would price one mistake twice and turn a quest
# into a tax. The empty-handed case is the one that used to be impossible: before pass 3 there
# was always a keystone standing there to press.
func _socket_controls() -> void:
	print("--- the sockets ---")
	_place(Vector3(-3.6, 0, 45.5), _puzzle.global_position)
	await _ticks(3)
	_ok("the island's socket starts EMPTY", not bool(_puzzle.call("socket_filled", 0)))
	_ok("…and says so", String(_puzzle.call("prompt_text")) == "The socket is empty.")
	_ok("…while still being reachable, so the place tell survives",
		_player.call("ai_interact_target") == _puzzle)
	var before := float(_player.call("get_panic_ratio"))
	_player.call("ai_interact")
	await _ticks(3)
	_ok("CONTROL: E with nothing in hand fills nothing and solves nothing",
		not bool(_puzzle.call("socket_filled", 0)) and not _puzzle.call("view_solved", 0))
	_ok("CONTROL: …and costs no panic",
		float(_player.call("get_panic_ratio")) <= before + 0.001)
	# The WRONG object: the bed slat, in the door's socket.
	_level.call("take_anchor", "slat")
	await _ticks(2)
	_ok("carrying an anchor shows it on the HUD's carried line",
		String(root.get_node("GameState").get("carried_item")).find("bed slat") >= 0,
		)
	_ok("…and the wrong socket does not invite it",
		String(_puzzle.call("prompt_text")) == "The socket is empty.")
	before = float(_player.call("get_panic_ratio"))
	_player.call("ai_interact")
	await _ticks(3)
	_ok("CONTROL: the wrong object is refused and stays in hand",
		not bool(_puzzle.call("socket_filled", 0)) and String(_level.call("carried_anchor")) == "slat")
	_ok("CONTROL: …and that refusal costs no panic either",
		float(_player.call("get_panic_ratio")) <= before + 0.001)
	# ⚠️ An EMPTY socket cannot be failed either: `interact_view()` is what the wrong-press cost
	# lives in, and with no keystone in the socket there is nothing to hold.
	before = float(_player.call("get_panic_ratio"))
	_puzzle.call("interact_view", 0)
	await _ticks(3)
	_ok("CONTROL: interact_view on an empty socket neither solves nor charges",
		not _puzzle.call("view_solved", 0)
		and float(_player.call("get_panic_ratio")) <= before + 0.001)
	# …and the right one.
	_level.call("consume_anchor", "slat")
	_level.call("take_anchor", "handle")
	await _ticks(2)
	_ok("the right object turns the prompt into an invitation",
		String(_puzzle.call("prompt_text")).begins_with("E — Set"))
	_player.call("ai_interact")
	await _ticks(3)
	_ok("E seats the handle and the socket becomes the door's keystone",
		bool(_puzzle.call("socket_filled", 0)) and String(_level.call("carried_anchor")) == "")
	_ok("…and the level's carried line is empty again",
		String(root.get_node("GameState").get("carried_item")) == "")
	_ok("the seated keystone wears the DOOR view's own tint", _socket_tint(0))


# The socket's stone is built from the view's `tint`, so the three sockets are three colours
# and a seated keystone keeps the colour of the memory it completes.
func _socket_tint(v: int) -> bool:
	var mount := _mount(v)
	if mount == null:
		return false
	var base := mount.get_node_or_null("Socket/SocketBase") as MeshInstance3D
	if base == null:
		return false
	var want: Color = (_puzzle.get("VIEWS") as Array)[v]["tint"]
	var mat := base.get_surface_override_material(0) as StandardMaterial3D
	return mat != null and mat.albedo_color.is_equal_approx(want)


func _mount(v: int) -> Node3D:
	if v == 0:
		return _puzzle.get_node_or_null("SocketMount") as Node3D
	return _puzzle.get_node_or_null(["", "KeystoneBed", "KeystoneWindow"][v]) as Node3D


# Three seated keystones, three different silhouettes — the whole point of pass 3. Measured as
# NODE NAMES under each mount plus the number of mesh children, not by eye.
func _distinct_keystones() -> bool:
	var seen := {}
	for v in range(3):
		var mount := _mount(v)
		if mount == null:
			return false
		var want: String = "Anchor" + String((_puzzle.get("VIEWS") as Array)[v]["anchor"]).capitalize()
		var art := mount.get_node_or_null(want) as Node3D
		if art == null or art.get_child_count() < 3:
			print("      %s has no %s under it" % [mount.name, want])
			return false
		if seen.has(want):
			return false
		seen[want] = true
	return seen.size() == 3


# ⭐ THE MEASUREMENT THAT SET THE TOLERANCES (2026-09-20 pass 2), kept as an assertion.
#
# The 13:10 playtest could not solve two of three viewpoints in four minutes. The ruling was
# that the tolerances come from a probe and are widened until a human standing ANYWHERE on the
# tile can hit it — >= 70 % of a 0.3 m grid at eye 1.65 +/- 0.15 m, facing the shape +/- 15
# degrees. This is that probe. It runs against `aligned_from()`, the same function
# `is_aligned()` calls, so it cannot drift away from the shipping behaviour.
#
# ⚠️ It asserts its own SAMPLE SIZE. "0 cells checked ... PASS" has happened in this repo.
func _region_sweep() -> void:
	print("--- the measured solvable region ---")
	var views: Array = _puzzle.get("VIEWS")
	_ok("the puzzle publishes three views", views.size() == 3 and TILES.size() == 3)
	for v in range(views.size()):
		var spec: Dictionary = views[v]
		var feet: Vector3 = spec["feet"]
		var aim: Vector3 = _puzzle.call("view_aim", v)
		var size: Vector2 = TILES[v]["size"]
		var xs := _offsets(size.x)
		var zs := _offsets(size.y)
		var cells := 0
		var hit := 0
		for dx in xs:
			for dz in zs:
				cells += 1
				var any := false
				for h in EYE_HEIGHTS:
					var eye := Vector3(feet.x + dx, h, feet.z + dz)
					var base: Vector3 = (aim - eye).normalized()
					for yaw in YAWS:
						if bool(_puzzle.call("aligned_from", v,
								eye, base.rotated(Vector3.UP, deg_to_rad(yaw)))):
							any = true
				if any:
					hit += 1
		var frac: float = float(hit) / maxf(1.0, float(cells))
		_ok("%s: at least 9 grid cells were actually sampled (%d)" % [spec["nm"], cells], cells >= 9)
		_ok("%s: %d of %d grid cells align (%.0f%%, floor %.0f%%)"
			% [spec["nm"], hit, cells, frac * 100.0, REGION_FLOOR * 100.0], frac >= REGION_FLOOR)
		# CONTROL: the tile next door aligns for nothing and can interact with nothing.
		for n in (TILES[v]["near"] as Array):
			var neye := Vector3(n.x, 1.65, n.y)
			_ok("%s: CONTROL adjacent tile (%.1f, %.1f) does NOT align" % [spec["nm"], n.x, n.y],
				not bool(_puzzle.call("aligned_from", v, neye, (aim - neye).normalized())))
	# CONTROL: no shape may align from another shape's tile.
	for v in range(views.size()):
		var bad := ""
		for w in range(views.size()):
			if v == w:
				continue
			var feet: Vector3 = (views[w] as Dictionary)["feet"]
			var eye := Vector3(feet.x, 1.65, feet.z)
			var aim: Vector3 = _puzzle.call("view_aim", v)
			if bool(_puzzle.call("aligned_from", v, eye, (aim - eye).normalized())):
				bad = String((views[w] as Dictionary)["nm"])
		_ok("%s: CONTROL solves from NO other view's tile (%s)"
			% [(views[v] as Dictionary)["nm"], bad if bad != "" else "none"], bad == "")


func _offsets(extent: float) -> Array:
	var out: Array = []
	var half: float = extent * 0.5 - 0.10
	var k: int = int(floor(half / GRID_STEP + 0.0001))
	for i in range(-k, k + 1):
		out.append(float(i) * GRID_STEP)
	return out


# Every piece of every shape hangs over the pit. This measures each one's WORLD AABB — the
# pieces are rotated boxes now, so a component-wise reading of a size vector would lie — and
# requires 0.20 m of clearance inside the abyss walls and 0.35 m of air over the causeway.
func _geometry_bounds() -> void:
	var checked := 0
	var bad: Array = []
	for v in range(3):
		for piece in ((_puzzle.get("_views") as Array)[v] as Dictionary)["pieces"]:
			var mi := piece as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			checked += 1
			var box := mi.get_aabb()
			var lo := Vector3(INF, INF, INF)
			var hi := -lo
			for c in 8:
				var wp: Vector3 = mi.global_transform * box.get_endpoint(c)
				lo = Vector3(minf(lo.x, wp.x), minf(lo.y, wp.y), minf(lo.z, wp.z))
				hi = Vector3(maxf(hi.x, wp.x), maxf(hi.y, wp.y), maxf(hi.z, wp.z))
			if lo.x < ABYSS.position.x + 0.20 or hi.x > ABYSS.position.x + ABYSS.size.x - 0.20 \
					or lo.z < ABYSS.position.z + 0.20 or hi.z > ABYSS.position.z + ABYSS.size.z - 0.20:
				bad.append("%s reaches the abyss wall (%v..%v)" % [mi.name, lo.snappedf(0.01), hi.snappedf(0.01)])
			elif lo.y < 0.35:
				bad.append("%s hangs into the causeway (y %.2f)" % [mi.name, lo.y])
	_ok("all 12 shape pieces measured (%d)" % checked, checked == 12)
	_ok("every piece floats clear of the abyss walls and the tiles: %s"
		% ("clear" if bad.is_empty() else ", ".join(bad)), bad.is_empty())


# Somewhere on this view's tile that is INSIDE the 1.5 m place gate and NOT aligned. If there
# is nowhere, the puzzle can no longer be failed from its own tile and this test says so.
func _find_wrong_stance(v: int) -> Vector3:
	var feet: Vector3 = (_puzzle.get("VIEWS") as Array)[v]["feet"]
	var aim: Vector3 = _puzzle.call("view_aim", v)
	var size: Vector2 = TILES[v]["size"]
	for dx in _offsets(size.x):
		for dz in _offsets(size.y):
			var eye := Vector3(feet.x + dx, 1.68, feet.z + dz)
			if Vector2(dx, dz).length() > 1.45:
				continue
			if not bool(_puzzle.call("aligned_from", v, eye, (aim - eye).normalized())):
				return Vector3(feet.x + dx, 0, feet.z + dz)
	return Vector3.INF


# ⭐ THE PLACE GATE, driven by the shipping raycast. From the tile next door the prompt must
# not appear and `ai_interact_target()` must not name the keystone — the 13:10 playtest could
# press the north keystone from 1.9 m away, so a wrong-TILE press and a wrong-ANGLE press were
# the same event and the player could learn nothing from either.
func _gate_controls() -> void:
	var views: Array = _puzzle.get("VIEWS")
	for v in range(views.size()):
		var key: Node3D = _puzzle
		var nm: String = TILES[v]["key"]
		if nm != "":
			key = _puzzle.get_node(nm) as Node3D
		for n in (TILES[v]["near"] as Array):
			_place(Vector3(n.x, 0, n.y), key.global_position)
			await _ticks(2)
			_ok("%s: CONTROL no prompt from the adjacent tile (%.1f, %.1f)"
				% [(views[v] as Dictionary)["nm"], n.x, n.y],
				not bool(key.call("can_interact")))
			_ok("%s: CONTROL the E-ray finds no keystone from there"
				% (views[v] as Dictionary)["nm"],
				_player.call("ai_interact_target") != key)
	# …and the POSITIVE control: standing on its own tile, the prompt is there.
	for v in range(views.size()):
		var key: Node3D = _puzzle
		var nm: String = TILES[v]["key"]
		if nm != "":
			key = _puzzle.get_node(nm) as Node3D
		var feet: Vector3 = (views[v] as Dictionary)["feet"]
		_place(feet, key.global_position)
		await _ticks(2)
		_ok("%s: the prompt IS there from its own tile" % (views[v] as Dictionary)["nm"],
			bool(key.call("can_interact")) and _player.call("ai_interact_target") == key)


# The far wing: shard -> cradle -> the plate over the twist note.
# ⚠️ The five stalkers are removed FIRST. This section teleports the player next to two of
# them to fire rays; encounter survivability on this exact route is walk_void_live's job, and
# it walks the whole chain with all five live.
func _chain() -> void:
	for s in (_level.call("get_stalkers") as Dictionary).values():
		if is_instance_valid(s):
			_level.remove_child(s)
			s.queue_free()
	await _ticks(2)
	var twist := _level.get_node("TwistNote")
	var plate := _level.get_node_or_null("SanctumPlate")
	_ok("the Sanctum's twist note starts behind a stone plate", plate != null)
	_place(Vector3(-16.0, 0, 26.1), twist.global_position)
	await _ticks(3)
	_ok("CONTROL: the plate intercepts the twist note's ray",
		_player.call("ai_interact_target") == plate)
	_player.call("ai_interact")
	await _ticks(2)
	_ok("CONTROL: and E on the plate does nothing at all",
		not bool(root.get_node("NoteUI").get("is_open")) and _level.get_node_or_null("SanctumPlate") != null)

	var cradle := _level.get_node("Cradle_ChildRoom")
	_place(Vector3(-14.0, 0, 34.9), cradle.global_position + Vector3(0, 0.9, 0))
	await _ticks(3)
	_ok("the cradle is reached on its own body, not a nested volume",
		_player.call("ai_interact_target") == cradle)
	_player.call("ai_interact")
	await _ticks(2)
	_ok("CONTROL: E on the cradle without the shard completes nothing", not cradle.done)

	# ⭐ THE SHARD IS IN THE ARCHIVE (pass 3), inside the inverted table's legs-up basin — and
	# since 2026-09-22 pass 6 it is simply TAKEABLE there from frame 0. Pass 5's wedge, which
	# refused until the table re-posed itself off-screen, read as a lock and not as a puzzle
	# (capture #4: *"should not be that way"*), so it is gone. The table still rearranges; it
	# just gates nothing any more, and this checks BOTH halves.
	var shard := _level.get_node("SlabShard")
	var table := _level.get_node("InvertedTable_Archive")
	_place(Vector3(-3.4, 0, 20.6), shard.global_position)
	await _ticks(3)
	_ok("the shard is visible and OFFERS E from frame 0 (pass 5's wedge is retired)",
		bool(shard.call("is_freed")) and shard.visible
		and String(shard.call("prompt_text")) == "E — Take the shard.")
	_ok("…and the shipping E-ray finds it", _player.call("ai_interact_target") == shard)
	_ok("looking at the table from inside the Archive arms it", bool(table.get("armed")))
	_player.call("ai_look_at", Vector3(-3.4, 1.3, 18.2))
	await _ticks(4)
	_ok("looking away still re-poses the table — a scare that now gates nothing",
		bool(table.get("spent")))
	_ok("…and the shard did not move with it",
		shard.global_position.distance_to(Vector3(-3.4, 0.42, 22.0)) < 0.05)
	_place(Vector3(-3.4, 0, 20.9), shard.global_position)
	await _ticks(3)
	_ok("the shard in the table's basin is reachable through the real ray",
		_player.call("ai_interact_target") == shard)
	_player.call("ai_interact")
	await _ticks(2)
	_ok("taking it puts the shard in the LEVEL's inventory",
		bool(_level.call("has_shard")),
		)
	_ok("…and on the HUD's carried line",
		String(root.get_node("GameState").get("carried_item")).find("stone shard") >= 0)

	_place(Vector3(-14.0, 0, 34.9), cradle.global_position + Vector3(0, 0.9, 0))
	await _ticks(3)
	_player.call("ai_interact")
	await _ticks(2)
	_ok("with the shard, E completes the cradle", cradle.done
		and not bool(_level.call("has_shard"))
		and String(root.get_node("GameState").get("carried_item")) == "")
	await create_timer(1.4).timeout
	# ⭐ 2026-09-20 pass 4 — THE CHAIN GAINED A LINK AND THIS IS WHERE IT MOVED. The cradle no
	# longer retracts the stone plate: it opens a sixteenth room behind the Morgue's west wall,
	# and the page at the end of THAT is what moves the stone. No new unlock condition was added;
	# `ExitDoor` still waits on `TWIST_READ` alone.
	_ok("completing the cradle does NOT retract the stone plate any more",
		_level.get_node_or_null("SanctumPlate") != null)
	_ok("…it opens the Morgue's west wall instead (measured with a ray, not a flag)",
		bool(_level.call("secret_open"))
		and _level.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(Vector3(-20.4, 1.0, 47.5),
				Vector3(-21.6, 1.0, 47.5), 1)).is_empty())
	_ok("…and the plate's line becomes a POINTER rather than a refusal (Issue 226)",
		String(_level.get_node("SanctumPlate").call("prompt_text"))
			== "Something else was opened instead.")

	# The page behind the frames is what does it. Driven through the note's own `interact()`,
	# with the hands already empty (three anchors seated, the shard spent) — which is the state
	# anyone standing at the corridor's end is in.
	var hidden = _level.call("hidden_note")
	hidden.call("reveal")
	_ok("the hidden page accepts E once everything is put back (prompt '%s')"
		% hidden.call("prompt_text"),
		String(hidden.call("prompt_text")) == "E — Read the page.")
	hidden.call("interact")
	root.get_node("NoteUI").call("_close")
	await create_timer(1.4).timeout
	_ok("reading it retracts the stone plate", _level.get_node_or_null("SanctumPlate") == null)
	_place(Vector3(-16.0, 0, 26.1), twist.global_position)
	await _ticks(3)
	_ok("…and the twist note is now what the ray finds", _player.call("ai_interact_target") == twist)


func _walk_to(target: Vector3) -> void:
	var arrived := false
	var lowest := 0.0
	for frame in range(400):
		var direction := target - _player.global_position
		direction.y = 0
		if direction.length() < 0.20:
			arrived = true
			break
		_player.call("ai_look_at", target + Vector3(0, 1.65, 0))
		_player.set("ai_move_dir", Vector2(0, -1))
		await physics_frame
		lowest = minf(lowest, _player.global_position.y)
	_player.set("ai_move_dir", Vector2.ZERO)
	_ok("southern branch reached %s without falling" % target, arrived and lowest > -0.1)


func _finish() -> void:
	if _done:
		return
	_done = true
	_ok("at least 70 meaningful checks ran", _checks >= 70)
	print("VOID ALIGNMENT: %d checks, %d failed" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
