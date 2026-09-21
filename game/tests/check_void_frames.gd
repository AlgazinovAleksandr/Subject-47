extends SceneTree

# THE HALL OF FRAMES (level_3.tscn, the sixteenth room) — the maze-tester shape, applied to a
# puzzle whose arrangement is different on every load.
#
#   Godot --headless --path game --script res://tests/check_void_frames.gd
#   Godot --headless --path game --script res://tests/check_void_frames.gd -- --seeds 3
#
# WHAT IT ASSERTS, and why each one is here rather than in check_void.gd:
#
#   * SIX SEEDED SCRAMBLES, each SOLVED by the answer order through the real 1.2 s dwell. A
#     generated arrangement proved solvable once is a generated arrangement proved nothing
#     (check_maze_gen.gd's rule).
#   * EVERY DWELL IS ENTERED ON FOOT from a human stance — the player is put down 1.0 m in front
#     of the frame, on the floor, and WALKS the last metre under `ai_move_dir` with the real
#     body and the real collision. Issue 226: a guard that teleports to the exact answer has not
#     tested the question. Seed 1 additionally walks in from the secret doorway.
#   * A WRONG STEP NEVER STRANDS. After EVERY drop — right or wrong — a downward physics ray
#     must find floor under the player and the FrameHall's rect must contain them. A puzzle with
#     no fail state that can drop you inside a wall has a fail state.
#   * THE FIGURE IS A PHOTOGRAPH. Its whole subtree is walked for a CollisionObject3D, a
#     CollisionShape3D and a ScaryObject ancestor; all three must be absent, every time. The one
#     thing this must never quietly become is a sixth creature (SCARY.md §8.3).
#   * THE THIRD WRONG STEP'S FIGURE LASTS EXACTLY ONE PROCESS FRAME, counted by the hall itself
#     rather than polled (polling can sample either side of the hide and prove nothing).
#   * THE NOTE REFUSES WHILE AN ANCHOR IS CARRIED — with the control run first, so "it opened"
#     cannot be confused with "it always opens".
#
# ⚠️ DEADLINE AND BUDGETS, both. Issue 224: a guard with no deadline can park the whole suite in
# a stage with no match arm forever, and `run_tests.sh` then never finishes.

const SCENE := "res://scenes/level_3.tscn"
const DEADLINE_MS := 300000
const SEEDS := [101, 202, 303, 404, 505, 606]
const STEP_BUDGET := 900          # physics ticks one dwell leg may take
const SETTLE_TICKS := 14

var _seeds: Array = []
var _seed_i := 0
var _started := false
var _settle := 0
var _loaded := false
var _level: Node = null
var _p: CharacterBody3D = null
var _hall: Node = null
var _rect := Rect2()
var _stage := ""
var _k := 0                       # which answer step this seed is on
var _leg_ticks := 0
var _wait := 0
var _last_phys := -1
var _fails := 0
var _checks := 0
var _started_at := 0
var _structural_done := false
var _progress_before := 0
var _wrong_before := 0
var _did_wrong := false
var _walked_in := false
var _solved_seeds := 0
var _dwells_entered := 0
var _drops_checked := 0
var _watched_id := ""
var _entered_slot := 0
var _last_slot := 0
var _last_ids: Array = []
var _watched_violations := 0
var _watched_samples := 0
var _trace := false
var _trace_panic := 0.0
var _last_delta := 0.0


func _initialize() -> void:
	_seeds = SEEDS.duplicate()
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if String(args[i]) == "--trace":
			_trace = true
		if String(args[i]) == "--seeds" and i + 1 < args.size():
			_seeds = SEEDS.slice(0, maxi(1, int(args[i + 1])))


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _ticks() -> int:
	var pf := Engine.get_physics_frames()
	var t: int = 1 if _last_phys < 0 else maxi(0, pf - _last_phys)
	_last_phys = pf
	return t


func _process(_delta: float) -> bool:
	_last_delta = _delta
	if _started_at == 0:
		_started_at = Time.get_ticks_msec()
	elif Time.get_ticks_msec() - _started_at > DEADLINE_MS:
		_ok("the whole run finished inside the deadline", false,
			"stuck in '%s' on seed %d" % [_stage, _seeds[mini(_seed_i, _seeds.size() - 1)]])
		return _report()
	if not _started:
		_started = true
		Engine.time_scale = 6.0
		change_scene_to_file(SCENE)
		return false
	_settle += 1
	if _settle < SETTLE_TICKS:
		return false
	if not _loaded:
		if not _bootstrap():
			return _report()
		return false
	var t := _ticks()
	if _trace:
		var pr := float(_p.call("get_panic_ratio"))
		if absf(pr - _trace_panic) > 0.0001:
			print("   TRACE panic %.4f -> %.4f in '%s' at %v" % [_trace_panic, pr, _stage, _p.global_position])
			_trace_panic = pr
	if _wait > 0:
		_wait -= t
		return false
	match _stage:
		"walk_in": _walk_in(t)
		"approach": _approach(t)
		"wrong_lamp": _wrong_lamp()
		"look_away": _look_away(t)
		"settling": _settled()
		"note": _note_checks()
		"next": _next_seed()
	return false


func _bootstrap() -> bool:
	_loaded = true
	_level = current_scene
	if _level == null or not _level.has_method("frame_hall"):
		print("  FAIL level_3.tscn did not load, or level_3.gd failed to parse")
		_fails += 1
		return false
	_p = _level.get_node_or_null("Player") as CharacterBody3D
	_hall = _level.call("frame_hall")
	if _p == null or _hall == null:
		_ok("the player and the Hall of Frames both exist", false)
		return false
	# ⚠️ The five stalkers are removed. This is a geometry-and-logic harness that parks a player
	# in one room for a minute; Issue 89 is a harness that photographs its own death and keeps
	# going, and Issue 228 is a wait next to a creature being a distance. Nothing here measures
	# them — check_stalker_motion and walk_void_live do.
	var removed := 0
	for s in (_level.call("get_stalkers") as Dictionary).values():
		if is_instance_valid(s):
			_level.remove_child(s)
			s.queue_free()
			removed += 1
	_ok("five stalkers removed for the frames harness", removed == 5, "%d removed" % removed)
	# ⚠️ AND `RandomAmbient` IS UNREGISTERED, which is not tidying — it is what makes this file's
	# zero-panic assertions mean anything. That autoload is GLOBAL and fires one of three events
	# on a random timer in every level, two of which are `add_panic(8.0)` and `add_panic(12.0)`.
	# The first build of this harness reported "the page costs no panic — panic 0.072" and the
	# spike turned out to be a `painting_fall` landing during the settle: the room was innocent
	# and the measurement was not. Retuning that autoload would change every level's pressure at
	# once and is not this pass's call; silencing it FOR THE HARNESS is.
	root.get_node("RandomAmbient").call("register_player", null)
	_rect = _level.call("_room_rect", "FrameHall")
	_p.set("ai_active", true)
	# The level's own opening path, never a deleted collider (the LabLocker rule).
	_level.call("_open_secret_door")
	_ok("the secret door opens through the level's own path",
		bool(_level.call("secret_open")) and _level.call("secret_plug") == null)
	if not _structural_done:
		_structural()
	_begin_seed()
	return true


# ── structure, once ─────────────────────────────────────────────────────────────
func _structural() -> void:
	_structural_done = true
	print("--- the room and the five frames ---")
	_ok("FrameHall is 6 x 6 at x -27..-21, z 44..50",
		_rect.size.is_equal_approx(Vector2(6, 6)) and _rect.position.is_equal_approx(Vector2(-27, 44)),
		str(_rect))
	# Issue 18: the puzzle is solved by standing still, so nothing here may charge for standing.
	var inside_dread := false
	var inside_dark := false
	var centre := Vector2(-24, 47)
	for c in _level.get_children():
		if not (c is Area3D) or c.get_child_count() == 0:
			continue
		var shape := (c.get_child(0) as CollisionShape3D)
		if shape == null or not (shape.shape is BoxShape3D):
			continue
		var sz: Vector3 = (shape.shape as BoxShape3D).size
		var pos: Vector3 = (c as Area3D).position
		var r := Rect2(pos.x - sz.x * 0.5, pos.z - sz.z * 0.5, sz.x, sz.z)
		if not r.has_point(centre):
			continue
		if c is DreadZone:
			inside_dread = true
		elif c is DarkZone:
			inside_dark = true
	_ok("Issue 18: the frame room is outside DreadFarWing", not inside_dread)
	_ok("Issue 18: …and outside every DarkZone", not inside_dark)
	var ids: Array = _hall.call("frame_ids")
	var answer: Array = _hall.call("answer_order")
	var seen := {}
	for id in ids:
		seen[String(id)] = true
	_ok("five frames, five DIFFERENT memories", ids.size() == 5 and seen.size() == 5, str(ids))
	_ok("…and they are exactly the five the answer names",
		_sorted(ids) == _sorted(answer), "%s vs %s" % [_sorted(ids), _sorted(answer)])
	var overlaps := 0
	var outside := 0
	for i in range(5):
		var u: Node3D = _hall.call("unit", i)
		if not _rect.has_point(Vector2(u.global_position.x, u.global_position.z)):
			outside += 1
		var fp: Vector3 = _hall.call("front_point", i)
		if not _rect.has_point(Vector2(fp.x, fp.z)):
			outside += 1
		for j in range(i + 1, 5):
			var v: Node3D = _hall.call("unit", j)
			if u.global_position.distance_to(v.global_position) < 1.2:
				overlaps += 1
	_ok("every frame AND every drop-out point is inside the room", outside == 0, "%d outside" % outside)
	_ok("no two frames are inside 1.2 m of each other", overlaps == 0, "%d pairs" % overlaps)
	# ⚠️ The doorway lane must be clear, or the secret room is a sealed room.
	var lane_blocked := 0
	for i in range(5):
		var u: Node3D = _hall.call("unit", i)
		if absf(u.global_position.z - 47.5) < 1.3 and u.global_position.x > -23.0:
			lane_blocked += 1
	_ok("no frame stands across the doorway lane at z 47.5", lane_blocked == 0)
	var note = _level.call("hidden_note")
	_ok("the page at the corridor's end is NOT in the world yet",
		note != null and not bool(note.call("is_revealed")) and not note.visible)
	_ok("…and it is a safe, journal-kept note, never a trap",
		note != null and not bool(note.get("is_trap")))


func _sorted(a: Array) -> Array:
	var out: Array = []
	for v in a:
		out.append(String(v))
	out.sort()
	return out


# ── one seed ────────────────────────────────────────────────────────────────────
func _begin_seed() -> void:
	var s: int = int(_seeds[_seed_i])
	_hall.call("restore_state", {"order": _hall.call("frame_ids"), "progress": 0, "wrong": 0,
		"solved": false, "seed": s})
	_hall.call("apply_scramble", s)
	_k = 0
	_did_wrong = false
	_walked_in = _seed_i != 0
	print("--- seed %d: %s ---" % [s, str(_hall.call("frame_ids"))])
	_ok("seed %d: a scramble was applied and the five memories survived it" % s,
		(_hall.call("frame_ids") as Array).size() == 5)
	if _seed_i == 0:
		# Seed 1 walks in from the secret doorway, so the room is proved enterable on foot
		# before anything else is measured.
		_place(Vector3(-20.4, 0.1, 47.5), Vector3(-24.0, 1.2, 47.5))
		_stage = "walk_in"
		_leg_ticks = 0
	else:
		_begin_leg()


func _walk_in(t: int) -> void:
	_leg_ticks += t
	var target := Vector3(-23.6, 0.0, 47.5)
	_steer(target)
	if Vector2(_p.global_position.x - target.x, _p.global_position.z - target.z).length() < 0.6:
		_ok("the secret room is enterable on foot through the freed doorway",
			_rect.has_point(Vector2(_p.global_position.x, _p.global_position.z)),
			"walked to %v in %d ticks" % [_p.global_position, _leg_ticks])
		_walked_in = true
		_begin_leg()
		return
	if _leg_ticks > STEP_BUDGET:
		_ok("the secret room is enterable on foot through the freed doorway", false,
			"stalled at %v" % _p.global_position)
		_walked_in = true
		_begin_leg()


# Put the player down 1.0 m in front of the frame it is about to enter — a stance on the floor,
# the same one the game itself drops them at after a right step — then WALK the last metre.
func _begin_leg() -> void:
	var answer: Array = _hall.call("answer_order")
	var want: String = String(answer[_k])
	# Seed 2 makes a deliberate WRONG step first: a frame that is not the one the order wants.
	if _seed_i == 1 and _k == 0 and not _did_wrong:
		want = String(answer[2])
	# Seed 3 flails: three wrong steps in a row, so the behind-you figure has to fire.
	if _seed_i == 2 and not _did_wrong and _hall.call("wrong_count") < 3:
		want = String(answer[(_hall.call("wrong_count") + 1) % 5])
		if want == String(answer[_hall.call("progress")]):
			want = String(answer[(_hall.call("progress") + 2) % 5])
	var slot: int = _hall.call("slot_of", want)
	var fp: Vector3 = _hall.call("front_point", slot)
	var u: Node3D = _hall.call("unit", slot)
	_place(fp, u.global_position + Vector3(0, 1.2, 0))
	_progress_before = int(_hall.call("progress"))
	_wrong_before = int(_hall.call("wrong_count"))
	_leg_ticks = 0
	_stage = "approach"


func _approach(t: int) -> void:
	_leg_ticks += t
	var slot := _target_slot()
	_last_slot = slot
	var u: Node3D = _hall.call("unit", slot)
	_steer(u.global_position)
	if float(_hall.call("dwell_seconds")) > 0.05:
		_dwells_entered += 1
	var progress := int(_hall.call("progress"))
	var wrong := int(_hall.call("wrong_count"))
	if progress > _progress_before:
		_after_drop("right step %d" % progress)
		_k = progress
		if bool(_hall.call("is_solved")):
			_stage = "settling"
			_wait = 220          # the 1.5 s settle tween, with room to spare
			return
		_begin_leg()
		return
	if wrong > _wrong_before:
		_after_wrong()
		return
	if _leg_ticks > STEP_BUDGET:
		_ok("seed %d: the dwell at slot %d fired inside its budget" % [int(_seeds[_seed_i]), slot],
			false, "%d ticks standing in it, dwell %.2f s, at %v"
				% [_leg_ticks, float(_hall.call("dwell_seconds")), _p.global_position])
		_stage = "next"


func _target_slot() -> int:
	var answer: Array = _hall.call("answer_order")
	var want: String = String(answer[mini(_k, 4)])
	if _seed_i == 1 and _k == 0 and not _did_wrong:
		want = String(answer[2])
	if _seed_i == 2 and not _did_wrong and int(_hall.call("wrong_count")) < 3:
		want = String(answer[(int(_hall.call("wrong_count")) + 1) % 5])
		if want == String(answer[int(_hall.call("progress"))]):
			want = String(answer[(int(_hall.call("progress")) + 2) % 5])
	return int(_hall.call("slot_of", want))


# ⚠️ AFTER EVERY DROP, RIGHT OR WRONG. "Zero fail state" is a claim about where the player ends
# up, and the only honest test of it is a physics ray and the room's own rect.
func _after_drop(what: String) -> void:
	_drops_checked += 1
	var at: Vector3 = _p.global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.6, 0), at - Vector3(0, 0.6, 0), 1)
	q.exclude = [_p.get_rid()]
	var hit: Dictionary = _level.get_world_3d().direct_space_state.intersect_ray(q)
	var inside: bool = _rect.has_point(Vector2(at.x, at.z))
	if not inside or hit.is_empty():
		_ok("seed %d: %s left the player standing on floor inside the room"
			% [int(_seeds[_seed_i]), what], false,
			"at %v, inside=%s, floor=%s" % [at, inside, hit.get("collider", "NOTHING")])
	var panic := float(_p.call("get_panic_ratio"))
	if panic > 0.001:
		_ok("seed %d: %s cost no panic" % [int(_seeds[_seed_i]), what], false,
			"panic %.3f" % panic)


func _after_wrong() -> void:
	_did_wrong = true
	_entered_slot = _last_slot
	var s: int = int(_seeds[_seed_i])
	var wrong: int = int(_hall.call("wrong_count"))
	_after_drop("wrong step %d" % wrong)
	_ok("seed %d: a wrong step does NOT advance the answer" % s,
		int(_hall.call("progress")) == _progress_before,
		"progress %d" % int(_hall.call("progress")))
	_ok("seed %d: …and marks the frames to re-scramble on the next look-away" % s,
		bool(_hall.call("rescramble_pending")))
	var fig: Node3D = _hall.call("diorama_figure")
	_ok("seed %d: …and stands a figure in a diorama" % s, fig != null)
	if fig:
		var bad := _rule_bearing(fig)
		_ok("seed %d: …which is a PHOTOGRAPH — no collider, no ScaryObject, no rule" % s,
			bad == "", bad)
	if wrong % 3 == 0:
		_ok("seed %d: the third wrong step put a figure behind the player" % s,
			_hall.call("watcher") != null)
		_ok("seed %d: …for EXACTLY one process frame" % s,
			int(_hall.call("watcher_frames")) == 1,
			"%d frames" % int(_hall.call("watcher_frames")))
		var w: Node3D = _hall.call("watcher")
		if w:
			_ok("seed %d: …and it is a photograph too" % s, _rule_bearing(w) == "")
	# ⚠️ The lamp is driven by the hall's own `_tick_lamp`, which runs at the TOP of its
	# `_process` — so it is still at its old level in the frame the wrong step fires. Sampling it
	# here measured 0.25 against an expected 0.0 on the first build.
	# ⚠️ AND THE PLAYER IS STOPPED AND POINTED AT THE FRAME THEY JUST GOT THROWN OUT OF. The
	# re-scramble exchanges pairs of UNWATCHED frames, so it completes from any stance (a player
	# can see at most three of the five from anywhere in a 6 x 6 room), and leaving the camera on
	# one is what makes the next stage a real control on the level's one rule.
	# ⚠️ STOPPED is load-bearing: `_approach` leaves `ai_move_dir` pointing into the frame, the
	# frames have NO collider, and a player left walking goes straight through the opening and out
	# the back — measured, and it put the camera facing the wall with 0 of 5 frames in view and,
	# on another seed, all five in view at once, which deadlocks the pair exchange.
	_place(_hall.call("front_point", _entered_slot),
		(_hall.call("unit", _entered_slot) as Node3D).global_position + Vector3(0, 1.2, 0))
	_leg_ticks = 0
	_wait = 4
	_stage = "wrong_lamp"


func _wrong_lamp() -> void:
	var s: int = int(_seeds[_seed_i])
	_ok("seed %d: a wrong step kills the room's lamp" % s,
		float(_hall.call("lamp_energy")) <= 0.001,
		"energy %.2f" % float(_hall.call("lamp_energy")))
	# ⚠️ THE LEVEL'S CORE RULE, CONTROLLED PER FRAME: nothing ever changes while you are looking
	# at it. The re-scramble exchanges pairs of UNWATCHED frames, so "the order is unchanged while
	# the player looks" is false by design and would be the wrong control — the right one is that
	# the frame the camera is ON does not change under it. The player has been standing in front
	# of one for four ticks and it is still watched.
	var watching := 0
	for i in range(5):
		if bool(_hall.call("looking_at", i)):
			watching += 1
	_ok("seed %d: CONTROL: the player is watching at least one frame while it re-scrambles" % s,
		watching >= 1, "%d of 5 in view" % watching)
	_last_ids = (_hall.call("frame_ids") as Array).duplicate()
	_watched_violations = 0
	_watched_samples = 0
	_watched_id = ""
	_leg_ticks = 0
	_stage = "look_away"


func _rule_bearing(n: Node) -> String:
	var found: Array = []
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is CollisionObject3D:
			found.append("%s is a CollisionObject3D" % c.name)
		if c is CollisionShape3D:
			found.append("%s is a CollisionShape3D" % c.name)
		if c is ScaryObject:
			found.append("%s is a ScaryObject" % c.name)
		for k in c.get_children():
			stack.append(k)
	var a: Node = n.get_parent()
	while a != null:
		if a is ScaryObject:
			found.append("%s is a ScaryObject ANCESTOR" % a.name)
		a = a.get_parent()
	return ", ".join(found)


# ⚠️ The player is turned to face the doorway and LEFT there. The re-scramble exchanges pairs of
# frames the camera cannot see, so it completes over a second or so rather than in one frame —
# which is the mechanic, not a delay: in a room this size there is no bearing that sees none of
# them, so an all-at-once rule would never fire at all.
func _look_away(t: int) -> void:
	_leg_ticks += t
	# ⚠️ SAMPLED EVERY FRAME, over the whole re-scramble, on EVERY slot. The level's one rule is
	# that nothing changes while you are looking at it; the honest test of it is to watch each
	# frame's memory and its watched-ness together, not to check one slot once.
	var ids: Array = _hall.call("frame_ids")
	_watched_samples += 1
	for i in range(ids.size()):
		if String(ids[i]) != String(_last_ids[i]) and bool(_hall.call("looking_at", i)):
			_watched_violations += 1
			_watched_id = "slot %d went %s -> %s IN VIEW" % [i, _last_ids[i], ids[i]]
	_last_ids = ids.duplicate()
	if not bool(_hall.call("rescramble_pending")):
		_ok("seed %d: looking away re-scrambled the frames off-screen" % int(_seeds[_seed_i]),
			_hall.call("diorama_figure") == null,
			"order now %s" % str(_hall.call("frame_ids")))
		_ok("seed %d: CONTROL: no frame changed while it was in view (%d frames sampled)"
			% [int(_seeds[_seed_i]), _watched_samples],
			_watched_violations == 0 and _watched_samples >= 8, _watched_id)
		_k = int(_hall.call("progress"))
		_begin_leg()
		return
	if _leg_ticks > STEP_BUDGET:
		_ok("seed %d: the re-scramble happened once the player looked away"
			% int(_seeds[_seed_i]), false, "still pending after %d ticks" % _leg_ticks)
		_stage = "next"


func _settled() -> void:
	var s: int = int(_seeds[_seed_i])
	_solved_seeds += 1
	_ok("seed %d: the answer order solves it" % s, bool(_hall.call("is_solved"))
		and int(_hall.call("progress")) == 5, "progress %d" % int(_hall.call("progress")))
	var xs: Array = []
	var line := true
	for i in range(5):
		var u: Node3D = _hall.call("unit", i)
		xs.append(snappedf(u.global_position.x, 0.01))
		if absf(u.global_position.x - (-24.0)) > 0.05 or absf(u.rotation.y) > 0.02:
			line = false
	_ok("seed %d: the five frames line up into one corridor" % s, line, str(xs))
	var note = _level.call("hidden_note")
	_ok("seed %d: …and the page at its end is in the world" % s,
		note != null and bool(note.call("is_revealed")) and note.visible)
	if _seed_i < _seeds.size() - 1:
		_stage = "next"
		return
	_stage = "note"
	_wait = 10


# ── the note, on the last seed only ─────────────────────────────────────────────
func _note_checks() -> void:
	print("--- the page that moves the stone ---")
	var note = _level.call("hidden_note")
	var plate := _level.get_node_or_null("SanctumPlate")
	# The state a player who has actually got here is in: three anchors seated, the cradle done.
	_level.get_node("AlignmentKeystone").call("restore_sockets", [true, true, true])
	_level.set("_cradle_done", true)
	if plate:
		plate.set("moved_elsewhere", true)
		_ok("the Sanctum plate's prompt POINTS once the cradle is done, instead of refusing",
			String(plate.call("prompt_text")) == "Something else was opened instead.",
			"'%s'" % plate.call("prompt_text"))
	# CONTROL: with an anchor in hand it must refuse, by name, and open nothing.
	_level.call("take_anchor", "handle")
	_place(Vector3(-24.0, 0.1, 48.7), note.global_position)
	var t0: Node = _p.call("ai_interact_target")
	_ok("CONTROL: the ray reaches the page from the corridor's end",
		t0 == note or (t0 != null and note.is_ancestor_of(t0)),
		"ray hit %s" % (t0.name if t0 else "nothing"))
	_ok("CONTROL: with an anchor in hand the prompt refuses BY NAME",
		String(note.call("prompt_text")) == "Your hands are not empty.",
		"'%s'" % note.call("prompt_text"))
	_p.call("ai_interact")
	_ok("CONTROL: …and E opens nothing", not bool(root.get_node("NoteUI").get("is_open")))
	# ⚠️ NOT just "the plate is still there". `retract()` queue_frees at the END of a 0.9 s tween,
	# so the node survives the refusal by a second whatever happens — the control passed against
	# a deliberately broken build until it also asked whether the tween had started.
	var still := _level.get_node_or_null("SanctumPlate")
	_ok("CONTROL: …and the stone has not started moving",
		still != null and still.get("_tween") == null)
	# Hands empty: it reads, and THAT is what retracts the plate.
	_level.call("consume_anchor", "handle")
	_ok("empty-handed, the prompt offers E",
		String(note.call("prompt_text")) == "E — Read the page.",
		"'%s'" % note.call("prompt_text"))
	_p.call("ai_interact")
	var ui := root.get_node("NoteUI")
	_ok("…and E really opens it through the shipping ray", bool(ui.get("is_open")))
	ui.call("_close")
	_ok("…and reading it starts the Sanctum plate retracting",
		_level.get_node_or_null("SanctumPlate") == null
			or _level.get_node("SanctumPlate").get("_tween") != null)
	_ok("the page costs no panic", float(_p.call("get_panic_ratio")) <= 0.001,
		"panic %.3f" % float(_p.call("get_panic_ratio")))
	_stage = "next"


func _next_seed() -> void:
	_seed_i += 1
	if _seed_i >= _seeds.size():
		_finish()
		return
	# A fresh load per seed: the settle frees the dioramas and disables the dwell areas, so an
	# in-place reset would measure a room this level cannot actually be in.
	_loaded = false
	_settle = 0
	_stage = ""
	_last_phys = -1
	change_scene_to_file(SCENE)


func _finish() -> void:
	_ok("every seed was solved by the answer order", _solved_seeds == _seeds.size(),
		"%d of %d" % [_solved_seeds, _seeds.size()])
	_ok("the dwell clock really ran (sample size)", _dwells_entered >= 20 * _seeds.size(),
		"%d frames with a running clock" % _dwells_entered)
	_ok("every drop was checked for floor and containment",
		_drops_checked >= 5 * _seeds.size(), "%d drops" % _drops_checked)
	_report()


# ── helpers ─────────────────────────────────────────────────────────────────────
func _place(at: Vector3, look: Vector3) -> void:
	_p.set("ai_move_dir", Vector2.ZERO)
	_p.velocity = Vector3.ZERO
	_p.global_position = at
	_p.force_update_transform()
	_p.call("ai_look_at", look)
	var cam := _p.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.force_update_transform()


func _steer(target: Vector3) -> void:
	var dir := target - _p.global_position
	dir.y = 0.0
	if dir.length() < 0.25:
		_p.set("ai_move_dir", Vector2.ZERO)
		return
	var local := _p.global_basis.inverse() * dir.normalized()
	_p.set("ai_move_dir", Vector2(local.x, local.z))
	_p.set("ai_sprint", false)


func _report() -> bool:
	if _checks < 10 + 4 * _seeds.size():
		print("  FAIL only %d checks ran — did a stage abort?" % _checks)
		_fails += 1
	print("  %d checks, %d failed" % [_checks, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true
