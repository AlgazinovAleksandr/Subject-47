extends SceneTree

# THE RECURRING ROOM (level_3.tscn, the sixteenth room) — the maze-tester shape, applied to a
# puzzle whose arrangement is different on every load and whose verb is WALKING.
#
#   Godot --headless --path game --script res://tests/check_void_frames.gd
#   Godot --headless --path game --script res://tests/check_void_frames.gd -- --seeds 3
#
# WHAT IT ASSERTS, and why each one is here rather than in check_void.gd:
#
#   * SIX SEEDED SCRAMBLES, each SOLVED by the answer order through the real crossing. A
#     generated arrangement proved solvable once is a generated arrangement proved nothing
#     (check_maze_gen.gd's rule).
#   * EVERY STEP IS WALKED. The player is put down 1.0 m in FRONT of the frame, on the floor,
#     and walks THROUGH it under `ai_move_dir` with the real body and the real collision, to a
#     stance 1.0 m out of its back. Issue 226: a guard that teleports to the answer has not
#     tested the question — and here the question is literally "can you walk through it".
#   * A WRONG STEP NEVER STRANDS. After EVERY arrival — right or wrong — a downward physics ray
#     must find floor under the player, the FrameHall's rect must contain them, and they must be
#     at the room's own entrance. A puzzle with no fail state that can drop you inside a wall has
#     a fail state.
#   * BRUTE FORCE IS BOUNDED. On one seed the harness plays a blind but rational player: it
#     identifies a door by the MEMORY in it (never by its position — a wrong step reshuffles the
#     five), eliminates each memory it has seen refused at each place in the order, and never
#     repeats a known-wrong guess. ⚠️ 25, NOT the 15 pass 4 published: a wrong step now resets
#     the answer to the BEGINNING, so every retry at place k costs k correct crossings to get
#     back there. Worst case = sum over k of 1 + (4-k)*(k+1) = 5 + 7 + 7 + 5 + 1 = 25. The 15
#     was the bound for a wrong step that only re-scrambled and left progress alone.
#   * EVERY FIGURE IS A PHOTOGRAPH. The subtree of the wrong step's figure and of stage 3's
#     doorway figure is walked for a CollisionObject3D, a CollisionShape3D and a ScaryObject
#     ancestor; all three must be absent, every time. The one thing these must never quietly
#     become is a sixth creature (SCARY.md §8.3).
#   * THE WRONG STEP'S FIGURE LASTS EXACTLY ONE PROCESS FRAME, counted by the room itself rather
#     than polled (polling can sample either side of the hide and prove nothing).
#   * THE NOTE REFUSES WHILE AN ANCHOR IS CARRIED — with the control run first, so "it opened"
#     cannot be confused with "it always opens".
#
# ⚠️ DEADLINE AND BUDGETS, both. Issue 224: a guard with no deadline can park the whole suite in
# a stage with no match arm forever, and `run_tests.sh` then never finishes.

const SCENE := "res://scenes/level_3.tscn"
const DEADLINE_MS := 300000
const SEEDS := [101, 202, 303, 404, 505, 606]
const STEP_BUDGET := 900          # physics ticks one crossing leg may take
const SETTLE_TICKS := 14
# ⚠️ 25, and the arithmetic is in the header: a wrong door resets the answer, so the worst case
# is 5 + 7 + 7 + 5 + 1 crossings, not pass 4's 15. Measured on seed 404.
const BRUTE_LIMIT := 25

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
var _legs_walked := 0
var _arrivals_checked := 0
var _brute_crossings := 0
var _brute_known: Array = []      # answer position -> memories already refused there
var _brute_chosen: Array = []     # memories already accepted in this run
var _brute_id := ""
var _trace := false
var _trace_panic := 0.0


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
		"cross": _cross(t)
		"wait_cut": _wait_cut()
		"after_wrong": _after_wrong()
		"brute": _brute(t)
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
		_ok("the player and the recurring room both exist", false)
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
	# zero-panic assertions mean anything (Issue 240). That autoload is GLOBAL and fires one of
	# three events on a random timer in every level, two of which are `add_panic(8.0)` and
	# `add_panic(12.0)`. The first build of the pass-4 harness reported "the page costs no panic
	# — panic 0.072" and the spike turned out to be a `painting_fall` landing during the settle.
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
	print("--- the room and the five doors ---")
	_ok("FrameHall is 6 x 6 at x -27..-21, z 44..50",
		_rect.size.is_equal_approx(Vector2(6, 6)) and _rect.position.is_equal_approx(Vector2(-27, 44)),
		str(_rect))
	# Issue 18: the puzzle is solved by walking about a dark room, so nothing here may charge for
	# being in it — no DarkZone (which would tax the torch being off) and no DreadZone.
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
	var facing := 0
	var entrance: Vector3 = _hall.call("entrance_point")
	for i in range(5):
		var u: Node3D = _hall.call("unit", i)
		if not _rect.has_point(Vector2(u.global_position.x, u.global_position.z)):
			outside += 1
		for pt in [_hall.call("front_point", i), _hall.call("back_point", i)]:
			if not _rect.has_point(Vector2((pt as Vector3).x, (pt as Vector3).z)):
				outside += 1
		# ⭐ EVERY FRONT FACES THE ENTRANCE (pass 6). The step is a crossing FROM THE FRONT, so a
		# frame whose back is turned to the door you arrive by is a frame you have to walk round
		# before you can use it — and its diorama, the thing that names it, is not visible from
		# the stance the room always puts you in.
		var front := -u.global_transform.basis.z
		front.y = 0.0
		var toward := entrance - u.global_position
		toward.y = 0.0
		if front.normalized().dot(toward.normalized()) > 0.5:
			facing += 1
		for j in range(i + 1, 5):
			var v: Node3D = _hall.call("unit", j)
			if u.global_position.distance_to(v.global_position) < 1.2:
				overlaps += 1
	_ok("every frame AND both of its stances are inside the room", outside == 0, "%d outside" % outside)
	_ok("all five doors face the entrance you are always put back at", facing == 5,
		"%d of 5" % facing)
	_ok("no two frames are inside 1.2 m of each other", overlaps == 0, "%d pairs" % overlaps)
	# ⚠️ The doorway lane must be clear, or the secret room is a sealed room.
	var lane_blocked := 0
	for i in range(5):
		var u2: Node3D = _hall.call("unit", i)
		if absf(u2.global_position.z - 47.5) < 1.3 and u2.global_position.x > -23.0:
			lane_blocked += 1
	_ok("no frame stands across the doorway lane at z 47.5", lane_blocked == 0)
	_ok("the entrance is inside the room and on the Morgue doorway's line",
		_rect.has_point(Vector2(entrance.x, entrance.z)) and absf(entrance.z - 47.5) < 0.01,
		str(entrance))
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
	_hall.call("restore_state", {"order": _hall.call("frame_ids"), "progress": 0, "stage": 0,
		"wrong": 0, "solved": false, "seed": s})
	_hall.call("apply_scramble", s)
	_k = 0
	_did_wrong = false
	_brute_crossings = 0
	_brute_known = [[], [], [], [], []]
	_brute_chosen = []
	_brute_id = ""
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
		return
	# ⭐ SEED 4 PLAYS THE WORST LEGAL STRATEGY: slot 0, slot 1, slot 2 … restart on every wrong
	# one, learn nothing. The whole room has to fall inside BRUTE_LIMIT crossings.
	if _seed_i == 3:
		_begin_brute()
		return
	_begin_leg()


func _walk_in(t: int) -> void:
	_leg_ticks += t
	var target := Vector3(-22.6, 0.0, 47.5)
	_steer(target)
	if Vector2(_p.global_position.x - target.x, _p.global_position.z - target.z).length() < 0.6:
		_ok("the secret room is enterable on foot through the freed doorway",
			_rect.has_point(Vector2(_p.global_position.x, _p.global_position.z)),
			"walked to %v in %d ticks" % [_p.global_position, _leg_ticks])
		_ok("…and walking in past the doorway steps nothing",
			int(_hall.call("progress")) == 0 and int(_hall.call("wrong_count")) == 0,
			"stage %d, %d wrong" % [int(_hall.call("progress")), int(_hall.call("wrong_count"))])
		_walked_in = true
		_begin_leg()
		return
	if _leg_ticks > STEP_BUDGET:
		_ok("the secret room is enterable on foot through the freed doorway", false,
			"stalled at %v" % _p.global_position)
		_walked_in = true
		_begin_leg()


# Put the player down 1.0 m in FRONT of the frame it is about to walk through, aim them at the
# matching stance 1.0 m out of its BACK, and let them walk. ⚠️ The whole leg is under the real
# body: the crossing is a geometric fact about where the capsule has been.
var _target_slot := -1
var _target_back := Vector3.ZERO


func _begin_leg() -> void:
	var answer: Array = _hall.call("answer_order")
	var want: String = String(answer[mini(int(_hall.call("progress")), answer.size() - 1)])
	# Seed 2 makes a deliberate WRONG step first: a frame that is not the one the order wants.
	if _seed_i == 1 and not _did_wrong:
		want = String(answer[2])
	# Seed 3 flails: three wrong steps in a row.
	if _seed_i == 2 and not _did_wrong and int(_hall.call("wrong_count")) < 3:
		want = String(answer[(int(_hall.call("wrong_count")) + 1) % 5])
		if want == String(answer[int(_hall.call("progress"))]):
			want = String(answer[(int(_hall.call("progress")) + 2) % 5])
	_aim_at_slot(int(_hall.call("slot_of", want)))


func _aim_at_slot(slot: int) -> void:
	_target_slot = slot
	_target_back = _hall.call("back_point", slot)
	_place(_hall.call("front_point", slot), _target_back + Vector3(0, 1.2, 0))
	_progress_before = int(_hall.call("progress"))
	_wrong_before = int(_hall.call("wrong_count"))
	_leg_ticks = 0
	_legs_walked += 1
	_stage = "cross"


func _cross(t: int) -> void:
	_leg_ticks += t
	# ⚠️ STOP WALKING THE MOMENT THE ROOM IS MID-STEP (2026-09-23 pass 8) — an intermittent this
	# file has carried since the crossing replaced the dwell, measured at roughly 1 run in 4:
	# "seed 101: right step 5 put the player back at the room's entrance — at (-23.5, 0, 47.5),
	# entrance (-21.9, 0.1, 47.5)". The room teleports the player to the entrance INSIDE its 0.3 s
	# black, and `ai_move_dir` is a LATCHED value — it keeps driving the body on every physics
	# tick until something writes it again. This harness polls in the IDLE step with
	# `Engine.time_scale = 6.0`, so an arbitrary number of physics ticks can pass between two
	# polls, and the bot walked up to 1.6 m WEST of the entrance it had just been put at before
	# the check ran. The assertion was right and the measurement was late.
	# ⚠️ IT IS NOT A GAME BUG: a human holding W through a frame also keeps walking after the
	# arrival, which is correct. What has to hold is that the ROOM put them at the entrance, so
	# the harness stops holding W for the duration of the step and measures that.
	if bool(_hall.call("is_stepping")):
		_p.set("ai_move_dir", Vector2.ZERO)
		_p.velocity = Vector3.ZERO
		return
	_steer(_target_back)
	var progress := int(_hall.call("progress"))
	var wrong := int(_hall.call("wrong_count"))
	if wrong > _wrong_before:
		_p.set("ai_move_dir", Vector2.ZERO)
		_p.velocity = Vector3.ZERO
		_stage = "after_wrong"
		_wait = 20             # past the 0.3 s cut, so the arrival can be measured
		return
	if progress > _progress_before:
		_p.set("ai_move_dir", Vector2.ZERO)
		_p.velocity = Vector3.ZERO
		_after_arrival("right step %d" % progress)
		_k = progress
		if bool(_hall.call("is_solved")):
			_stage = "settling"
			_wait = 220          # the 1.5 s settle tween, with room to spare
			return
		_stage = "wait_cut"
		return
	if _leg_ticks > STEP_BUDGET:
		_ok("seed %d: the crossing at slot %d fired inside its budget"
			% [int(_seeds[_seed_i]), _target_slot], false,
			"%d ticks walking through it, at %v" % [_leg_ticks, _p.global_position])
		_stage = "next"


# ⚠️ AFTER EVERY ARRIVAL, RIGHT OR WRONG. "Zero fail state" is a claim about where the player
# ends up, and the only honest test of it is a physics ray, the room's own rect and the stated
# entrance.
func _after_arrival(what: String) -> void:
	_arrivals_checked += 1
	var at: Vector3 = _p.global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.6, 0), at - Vector3(0, 0.6, 0), 1)
	q.exclude = [_p.get_rid()]
	var hit: Dictionary = _level.get_world_3d().direct_space_state.intersect_ray(q)
	var inside: bool = _rect.has_point(Vector2(at.x, at.z))
	var entrance: Vector3 = _hall.call("entrance_point")
	if not inside or hit.is_empty():
		_ok("seed %d: %s left the player standing on floor inside the room"
			% [int(_seeds[_seed_i]), what], false,
			"at %v, inside=%s, floor=%s" % [at, inside, hit.get("collider", "NOTHING")])
	if Vector2(at.x - entrance.x, at.z - entrance.z).length() > 0.4:
		_ok("seed %d: %s put the player back at the room's entrance"
			% [int(_seeds[_seed_i]), what], false, "at %v, entrance %v" % [at, entrance])
	var panic := float(_p.call("get_panic_ratio"))
	if panic > 0.001:
		_ok("seed %d: %s cost no panic" % [int(_seeds[_seed_i]), what], false,
			"panic %.3f" % panic)


func _after_wrong() -> void:
	_did_wrong = true
	var s: int = int(_seeds[_seed_i])
	var wrong: int = int(_hall.call("wrong_count"))
	_after_arrival("wrong step %d" % wrong)
	_ok("seed %d: a wrong door resets the answer to the beginning" % s,
		int(_hall.call("progress")) == 0, "stage %d" % int(_hall.call("progress")))
	_ok("seed %d: …and the room is back at stage 0 with it" % s,
		absf(float(_hall.call("lamp_energy")) - 0.25) < 0.14
		and not bool(_hall.call("hum_playing"))
		and not bool(_hall.call("walls_corrupt")),
		"lamp %.2f hum %s walls %s" % [float(_hall.call("lamp_energy")),
			_hall.call("hum_playing"), _hall.call("walls_corrupt")])
	var fig: Node3D = _hall.call("watcher")
	_ok("seed %d: …and a figure stood at arm's length on the fade-in" % s, fig != null)
	if fig:
		var bad := _rule_bearing(fig)
		_ok("seed %d: …which is a PHOTOGRAPH — no collider, no ScaryObject, no rule" % s,
			bad == "", bad)
	_ok("seed %d: …for EXACTLY one process frame per wrong step" % s,
		int(_hall.call("watcher_frames")) == wrong,
		"%d frames over %d wrong steps" % [int(_hall.call("watcher_frames")), wrong])
	_k = 0
	_stage = "wait_cut"


# ── a blind but rational player, on one seed ────────────────────────────────────
#
# ⚠️ IT GUESSES BY MEMORY, NEVER BY POSITION, and that distinction is the mechanic. A wrong door
# reshuffles all five, so "try slot 0, then slot 1" is not a strategy at all — it is a random
# walk, and the first draft of this stage measured one (16 crossings and still at stage 0 on a
# room that is solvable in 5). What a player can actually do is remember that the hung SHARDS
# were refused as the first door and never offer them there again. That is what this plays.
func _begin_brute() -> void:
	print("  brute force: a blind player who eliminates by MEMORY, restarting on each wrong door")
	_brute_crossings = 0
	_brute_next()


func _brute_next() -> void:
	# ⚠️ ALPHABETICAL, NOT `answer_order()`. The first draft iterated the answer itself and
	# "solved the room in 5 crossings" — it was reading the solution off the array it was meant
	# to be blind to. A fixed order the level does not share is what a player who knows nothing
	# actually has.
	var answer: Array = _sorted(_hall.call("answer_order"))
	var place: int = int(_hall.call("progress"))
	var ruled: Array = _brute_known[place]
	var pick := ""
	for id in answer:
		var s := String(id)
		if _brute_chosen.has(s) or ruled.has(s):
			continue
		pick = s
		break
	if pick == "":
		_ok("seed %d: the blind player always has a door left to try" % int(_seeds[_seed_i]),
			false, "place %d, chosen %s, ruled out %s" % [place, str(_brute_chosen), str(ruled)])
		_stage = "next"
		return
	_brute_id = pick
	_aim_at_slot(int(_hall.call("slot_of", pick)))
	_stage = "brute"


func _brute(t: int) -> void:
	_leg_ticks += t
	# The same latched-input race as `_cross()` — see its note. The brute-force sweep makes up to
	# 25 crossings per seed, so it is the arm MOST likely to hit it.
	if bool(_hall.call("is_stepping")):
		_p.set("ai_move_dir", Vector2.ZERO)
		_p.velocity = Vector3.ZERO
		return
	_steer(_target_back)
	var progress := int(_hall.call("progress"))
	var wrong := int(_hall.call("wrong_count"))
	if progress > _progress_before or wrong > _wrong_before:
		_brute_crossings += 1
		_p.set("ai_move_dir", Vector2.ZERO)
		_p.velocity = Vector3.ZERO
		_after_arrival("brute crossing %d" % _brute_crossings)
		if wrong > _wrong_before:
			(_brute_known[_progress_before] as Array).append(_brute_id)
			_brute_chosen = []
		else:
			_brute_chosen.append(_brute_id)
		if bool(_hall.call("is_solved")):
			_ok("seed %d: a blind player solved the room in %d crossings (<= %d)"
				% [int(_seeds[_seed_i]), _brute_crossings, BRUTE_LIMIT],
				_brute_crossings <= BRUTE_LIMIT)
			_stage = "settling"
			_wait = 220
			return
		if _brute_crossings > BRUTE_LIMIT:
			_ok("seed %d: a blind player solves the room in <= %d crossings"
				% [int(_seeds[_seed_i]), BRUTE_LIMIT], false,
				"%d crossings and still at stage %d" % [_brute_crossings, progress])
			_stage = "next"
			return
		# ⚠️ The next leg is chosen in `_wait_cut`, not here, so it cannot begin while the cut
		# is still running (see the note there).
		_stage = "wait_cut"
		return
	if _leg_ticks > STEP_BUDGET:
		_ok("seed %d: the brute-force crossing at slot %d fired inside its budget"
			% [int(_seeds[_seed_i]), _target_slot], false, "%d ticks" % _leg_ticks)
		_stage = "next"


# ⚠️ THE NEXT LEG DOES NOT START UNTIL THE CUT IS OVER, and that is a HARNESS rule the first
# build got wrong in a way worth writing down. The step is detected the instant the stage
# advances — which happens INSIDE the 0.3 s black — so a harness that immediately teleports the
# player to the next frame's front stance is placing them while the coroutine is still running.
# When it resumes it disarms every threshold (correctly: it has just teleported the player to
# the entrance), and at `Engine.time_scale = 6.0` the bot has already walked 1.2 m past the next
# frame's plane by then. Measured: one crossing, then 901 ticks parked 0.8 m behind a door that
# would never fire. A real player is FROZEN for the whole cut and cannot reproduce it.
func _wait_cut() -> void:
	if bool(_hall.call("is_stepping")):
		return
	if _seed_i == 3:
		_brute_next()
		return
	_begin_leg()


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


func _settled() -> void:
	var s: int = int(_seeds[_seed_i])
	_solved_seeds += 1
	_ok("seed %d: the answer order solves it" % s, bool(_hall.call("is_solved"))
		and int(_hall.call("progress")) == 5, "stage %d" % int(_hall.call("progress")))
	var xs: Array = []
	var line := true
	for i in range(5):
		var u: Node3D = _hall.call("unit", i)
		xs.append(snappedf(u.global_position.x, 0.01))
		if absf(u.global_position.x - (-24.0)) > 0.05 or absf(u.rotation.y) > 0.02 \
				or absf(u.rotation.z) > 0.02:
			line = false
	_ok("seed %d: the five frames line up into one corridor, upright" % s, line, str(xs))
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
	# A fresh load per seed: the settle frees the dioramas and retires the thresholds, so an
	# in-place reset would measure a room this level cannot actually be in.
	_loaded = false
	_settle = 0
	_stage = ""
	_last_phys = -1
	change_scene_to_file(SCENE)


func _finish() -> void:
	_ok("every seed was solved", _solved_seeds == _seeds.size(),
		"%d of %d" % [_solved_seeds, _seeds.size()])
	_ok("every leg was really walked (sample size)", _legs_walked >= 5 * _seeds.size(),
		"%d legs walked through a frame" % _legs_walked)
	_ok("every arrival was checked for floor, containment and the entrance",
		_arrivals_checked >= 5 * _seeds.size(), "%d arrivals" % _arrivals_checked)
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
	if dir.length() < 0.15:
		_p.set("ai_move_dir", Vector2.ZERO)
		return
	var local := _p.global_basis.inverse() * dir.normalized()
	_p.set("ai_move_dir", Vector2(local.x, local.z))
	_p.set("ai_sprint", false)


func _report() -> bool:
	if _checks < 12 + 4 * _seeds.size():
		print("  FAIL only %d checks ran — did a stage abort?" % _checks)
		_fails += 1
	print("  %d checks, %d failed" % [_checks, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true
