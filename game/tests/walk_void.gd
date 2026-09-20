extends SceneTree

# THE VOID (level_3.tscn) is physically completable: spawn -> five safe notes -> the loop
# corridor (which must send you back at least once and never again once its note is read)
# -> across the floating tiles -> the twist note -> the exit door, unlocked.
#
# ⚠️ Every note is read through the SHIPPING raycast (ai_interact_target / ai_interact),
# never by calling interact() on the node, and the loop is walked, never signalled: the
# seam is an Area3D that only fires for a body moving +z through it, which is precisely
# the thing a call to _on_loop_seam() would not prove. walk_backrooms.gd's lesson.
#
# The base test removes five stalkers to isolate geometry and note reachability.
# walk_void_live.gd retains them and requires all five encounters plus the real exit. Budgets count PHYSICS TICKS, not
# render frames (headless idle frames are uncapped and say nothing about distance walked).
#
# Usage: Godot --headless --path game --script res://tests/walk_void.gd

const AUTOPLAYER := preload("res://tests/autoplay/autoplayer.gd")
const SCENE := "res://scenes/level_3.tscn"
const TICKS_PER_HOP := 700       # 11.7 s of movement at 60 Hz
const TICK_CAP := 140000          # hang guard over the whole route (pass 3 doubled it)
# ⚠️ AND A WALL-CLOCK DEADLINE (2026-09-20 pass 3), because a tick cap is not one. Issue 224:
# `check_void` had no deadline and a broken control parked it in a stage with no match arm
# forever; this file had exactly the same hole, and a guard that can hang is worse than one
# that fails — run_tests.sh never finishes and nothing downstream runs.
const DEADLINE_MS := 420000
const ARRIVE := 1.2
const TILE_ARRIVE := 0.9         # = AutoPlayer.ARRIVE_DIST; a beam is 1.0 m wide

# "walk": a waypoint. "read": approach point already reached; look at the note and press E.
# "take"/"cradle": the same, for the shard and its socket. "lap": walk +z up the loop until
# `laps` teleports have happened. "check": a named assertion.
#
# ⭐ 2026-09-20 pass 3 adds "take_anchor" / "place_anchor" (the quest: three objects hidden in
# the level's early rooms, carried ONE AT A TIME to three empty sockets on the causeway),
# "step_through" (stand in Hall2's flat doorframe until it drops you in LoopIn) and "drawers"
# (pull the Morgue's seventeen fronts until one yields the page). ⚠️ The route walks them in
# HUMAN ORDER — the order the objects are met from the spawn, with the long walk back for the
# bed slat actually walked — because a bot that fetches in the convenient order proves a beat
# nobody reaches (Issue 220, the loop note that came before its own seam).
#
# ⚠️ ONE LAP PER STEP. The loop note is illegible until lap 2 since 2026-09-20, and a single
# lap step with one 700-tick budget cannot walk 30 m of corridor twice — it times out at lap 1
# and the note then refuses E, which looks like a broken note rather than a short budget.
var _steps: Array = [
	{"walk": Vector3(-2.7, 0, 0.0)},
	{"read": "NoteThreshold"},
	{"walk": Vector3(0, 0, 4.0)}, {"walk": Vector3(0, 0, 5.6)},
	# PocketA, the dead end off Hall1 that no run of the 2026-09-20 playtests entered: the tar
	# door handle lies on the floor under its trap note.
	{"walk": Vector3(-1.5, 0, 7.0)}, {"walk": Vector3(-3.2, 0, 7.2)},
	{"walk": Vector3(-4.5, 0, 7.1), "exact": true},
	{"take_anchor": "handle"},
	{"walk": Vector3(-2.6, 0, 7.0)}, {"walk": Vector3(0, 0, 7.4)},
	{"walk": Vector3(0, 0, 10.0)}, {"walk": Vector3(0, 0, 11.6)},
	{"walk": Vector3(0, 0, 16.6)},
	{"read": "NoteWard"},
	# ⭐ THE ARCHIVE. Walk in facing the inverted table (which arms it), walk back out facing
	# away (which re-poses it and exposes the shard), then come back for it. Nothing here is
	# signalled: the arming and the reveal are the prop's own `arm_on_sight` beat.
	{"walk": Vector3(-2.0, 0, 17.4)}, {"walk": Vector3(-2.6, 0, 19.2)},
	{"walk": Vector3(-3.3, 0, 20.3), "exact": true},
	{"check": "shard_hidden"},
	{"walk": Vector3(-1.4, 0, 18.8), "exact": true},
	{"check": "shard_revealed"},
	{"walk": Vector3(-3.4, 0, 20.9), "exact": true},
	{"take": "SlabShard"},
	{"walk": Vector3(-2.0, 0, 18.6)}, {"walk": Vector3(-1.2, 0, 16.8)},
	# Round the right-hand suspended frame (2.6, 14.5): a straight line from the note to the east
	# doorway at z 15.5 clips its foot end.
	{"walk": Vector3(3.4, 0, 17.35)},
	{"walk": Vector3(5.0, 0, 15.5)}, {"walk": Vector3(6.6, 0, 15.5)},
	{"walk": Vector3(11.0, 0, 15.5)}, {"walk": Vector3(12.5, 0, 15.5)},
	{"lap": Vector3(12.5, 0, 40.0), "laps": 1},
	{"check": "loop_note_illegible"},
	{"lap": Vector3(12.5, 0, 40.0), "laps": 2},
	{"walk": Vector3(12.2, 0, 23.0)},
	{"check": "plug_present"},
	{"read": "LoopNote"},
	{"check": "loop_broken"},
	{"walk": Vector3(12.5, 0, 26.0)},
	{"check": "plug_gone"},
	{"walk": Vector3(12.5, 0, 43.0)},
	{"check": "no_more_laps"},
	{"walk": Vector3(12.5, 0, 44.0)}, {"walk": Vector3(12.5, 0, 45.6)},
	{"walk": Vector3(11.0, 0, 46.7)}, {"walk": Vector3(9.4, 0, 46.7)},
	{"walk": Vector3(3.0, 0, 45.5)}, {"walk": Vector3(1.7, 0, 45.5)},
	# ⭐ THE CAUSEWAY, 2026-09-20 pass 2: three DIFFERENT memories in three corners. The route
	# is east pad -> the spine's first tile (the BED, looking north-east over the pit) -> the
	# north branch -> the island (the DOOR, looking west) -> the south branch's middle tile
	# (the WINDOW, looking south-east) -> west pad. Tile centres, as built, and every
	# viewpoint leg is `exact`: the keystone prompt is gated to 1.5 m of the tile's feet, so
	# arriving 0.9 m out is arriving somewhere the puzzle is deliberately not offered.
	# ⭐ THE QUEST, walked. The handle came from PocketA and is still in hand, so the DOOR is
	# the shape that can be held first; the latch is 8 m away in Hall2; the slat costs the long
	# walk back to the Ward, which is what the step-through exists for.
	{"walk": Vector3(-0.2, 0, 45.5), "tile": true},
	{"walk": Vector3(-1.8, 0, 47.0), "tile": true},
	{"walk": Vector3(-3.6, 0, 48.2), "tile": true},
	{"walk": Vector3(-3.6, 0, 45.5), "tile": true, "exact": true},
	{"check": "socket_refuses_empty"},
	{"place_anchor": 0},
	{"check": "solve_door"},
	# back east for the window latch, lying inside Hall2's flat doorframe
	{"walk": Vector3(-1.8, 0, 44.0), "tile": true},
	{"walk": Vector3(-0.2, 0, 45.5), "tile": true},
	{"walk": Vector3(1.4, 0, 45.5), "tile": true},
	{"walk": Vector3(3.0, 0, 45.5)}, {"walk": Vector3(5.2, 0, 45.2)},
	{"walk": Vector3(7.05, 0, 44.45), "exact": true},
	{"take_anchor": "latch"},
	{"check": "stepped_out_in_time"},
	{"walk": Vector3(5.0, 0, 45.4)}, {"walk": Vector3(3.0, 0, 45.5)},
	{"walk": Vector3(1.4, 0, 45.5), "tile": true},
	{"walk": Vector3(-0.2, 0, 45.5), "tile": true},
	{"walk": Vector3(-1.8, 0, 44.0), "tile": true},
	{"walk": Vector3(-3.6, 0, 42.8), "tile": true, "exact": true},
	{"check": "wrong_anchor_refused"},
	{"place_anchor": 2},
	{"check": "solve_window"},
	# ⭐ …and the long one: back to the Ward for the bed slat, THROUGH the flat doorframe.
	{"walk": Vector3(-1.8, 0, 44.0), "tile": true},
	{"walk": Vector3(-0.2, 0, 45.5), "tile": true},
	{"walk": Vector3(1.4, 0, 45.5), "tile": true},
	{"walk": Vector3(3.0, 0, 45.5)}, {"walk": Vector3(5.2, 0, 45.0)},
	{"walk": Vector3(7.0, 0, 44.7), "exact": true},
	{"step_through": true},
	# ⚠️ ROUND THE SUSPENDED FRAMES, both ways. FoldedFrame_Ward_R (2.6, 14.5) carries a
	# 1.25 x 1.85 x 1.65 collider and a straight line from the LoopIn doorway to the slat
	# grazes its corner — the walker wedged there and stalled three legs in a row.
	{"walk": Vector3(6.4, 0, 15.5)}, {"walk": Vector3(4.6, 0, 15.5)},
	{"walk": Vector3(3.4, 0, 17.0)}, {"walk": Vector3(0.4, 0, 17.0)},
	{"walk": Vector3(0.0, 0, 12.4)},
	{"walk": Vector3(-2.5, 0, 12.5), "exact": true},
	{"take_anchor": "slat"},
	{"walk": Vector3(0.0, 0, 12.6)}, {"walk": Vector3(0.4, 0, 17.0)},
	{"walk": Vector3(3.4, 0, 17.35)}, {"walk": Vector3(5.0, 0, 15.5)},
	# ⚠️ THROUGH the LoopIn doorway (11, 15.5) before turning north: the corridor's west wall
	# runs from x = 11, so a diagonal from inside LoopIn straight to (12.5, 20) walks into it.
	{"walk": Vector3(6.6, 0, 15.5)}, {"walk": Vector3(11.0, 0, 15.5)},
	{"walk": Vector3(12.5, 0, 15.5)}, {"walk": Vector3(12.5, 0, 20.0)},
	{"walk": Vector3(12.5, 0, 30.0)}, {"walk": Vector3(12.5, 0, 38.0)},
	{"walk": Vector3(12.5, 0, 43.0)},
	{"check": "no_more_laps"},
	{"walk": Vector3(12.5, 0, 45.6)}, {"walk": Vector3(11.0, 0, 46.7)},
	{"walk": Vector3(9.4, 0, 46.7)}, {"walk": Vector3(5.0, 0, 45.6)},
	{"walk": Vector3(3.0, 0, 45.5)}, {"walk": Vector3(1.7, 0, 45.5)},
	{"walk": Vector3(1.4, 0, 45.5), "tile": true, "exact": true},
	{"place_anchor": 1},
	{"check": "solve_bed"},
	{"walk": Vector3(-0.2, 0, 45.5), "tile": true},
	{"walk": Vector3(-1.8, 0, 44.0), "tile": true},
	{"walk": Vector3(-3.6, 0, 42.8), "tile": true},
	{"walk": Vector3(-5.6, 0, 43.6), "tile": true},
	{"walk": Vector3(-7.0, 0, 44.5), "tile": true},
	{"walk": Vector3(-7.7, 0, 45.5), "tile": true},
	{"check": "seal_open"},
	{"check": "still_on_the_tiles"},
	{"walk": Vector3(-9.0, 0, 45.5)}, {"walk": Vector3(-10.6, 0, 45.5)},
	# ⚠️ APPROACH THE SLAB FROM THE SOUTH. CreatureD stands at (-11.2, 47.0); the torn page is
	# in the hollow on the slab's underside at (-13.1, 1.84, 45.5), and a southern approach
	# keeps 2.3 m of air between the player and D for the whole beat.
	{"walk": Vector3(-11.9, 0, 44.0)}, {"walk": Vector3(-13.0, 0, 44.7), "exact": true},
	{"read": "SlabPage"},
	{"walk": Vector3(-15.0, 0, 44.6)}, {"walk": Vector3(-18.0, 0, 45.4)},
	{"walk": Vector3(-19.8, 0, 45.0)},
	{"read": "NoteMorgue"},
	# ⭐ SEARCH: pull the fronts along the north wall until one of them has the page in it.
	{"walk": Vector3(-19.0, 0, 50.6)},
	{"drawers": true},
	{"walk": Vector3(-17.0, 0, 45.0)},
	{"walk": Vector3(-14.0, 0, 42.5)}, {"walk": Vector3(-14.0, 0, 40.9)},
	{"walk": Vector3(-14.0, 0, 36.5)}, {"walk": Vector3(-14.0, 0, 34.9), "exact": true},
	{"cradle": "Cradle_ChildRoom"},
	# ⭐ 2026-09-20 pass 4. Completing the cradle no longer retracts the Sanctum plate: it opens a
	# wall three rooms away, and the page behind THAT is what moves the stone. The route walks it.
	{"check": "secret_opened"},
	{"check": "sanctum_still_sealed"},
	# north out of the child room, back through Hall3 and the Morgue, and west through the
	# doorway that did not exist when the player last stood here.
	{"walk": Vector3(-14.0, 0, 36.5)}, {"walk": Vector3(-14.0, 0, 40.9)},
	{"walk": Vector3(-14.0, 0, 42.5)}, {"walk": Vector3(-15.5, 0, 44.6)},
	{"walk": Vector3(-18.5, 0, 46.6)}, {"walk": Vector3(-20.4, 0, 47.5)},
	{"walk": Vector3(-22.6, 0, 47.5)},
	{"check": "in_frame_hall"},
	{"frames": true},
	{"walk": Vector3(-24.0, 0, 48.6), "exact": true},
	{"read": "HiddenNote"},
	# …and all the way back to the Sanctum for the twist note. ⚠️ The plate is checked AFTER the
	# first legs, not in the frame the page is read: `retract()` queue_frees at the END of a 0.9 s
	# tween, so a sweep in the next frame measures the pre-free state.
	{"walk": Vector3(-22.6, 0, 47.5)}, {"walk": Vector3(-20.4, 0, 47.5)},
	{"walk": Vector3(-17.5, 0, 45.6)}, {"walk": Vector3(-14.6, 0, 43.4)},
	{"check": "sanctum_unsealed"},
	{"walk": Vector3(-14.0, 0, 42.5)}, {"walk": Vector3(-14.0, 0, 40.9)},
	{"walk": Vector3(-14.0, 0, 36.5)}, {"walk": Vector3(-14.0, 0, 33.0)},
	{"walk": Vector3(-14.0, 0, 29.5)}, {"walk": Vector3(-14.0, 0, 27.9)},
	{"check": "exit_locked_before_twist"},
	{"stare": "F"},
	{"walk": Vector3(-16.0, 0, 26.1), "exact": true},
	{"read": "TwistNote"},
	{"check": "twist_read"},
	{"walk": Vector3(-14.0, 0, 21.2)},
	{"check": "exit_unlocked_and_found"},
]

var _stare_elapsed := 0.0
var _exiting := false
var _exit_started := 0
var _live := false
var _encounters: Dictionary = {}
var _fails := 0
var _checks := 0
var _started := false
var _settle := 0
var _level: Node = null
var _auto = null
var _step := 0
var _hop := 0
var _total := 0
var _last_phys := -1
var _retried: Dictionary = {}     # step index -> already backed up once
var _stalls := 0
var _removed := 0
var _read_pending := false      # a note is open and must be closed next frame
var _bootstrapped := false      # the one-shot setup block has run
var _lap_start_z := 0.0
var _min_y := 0.0
var _started_at := 0
var _step_before := -1
var _step_ticks := 0
var _step_yaw := 0.0
var _drawer_i := 0
var _drawers_opened := 0
var _pages_found := 0
var _frame_leg := -1
var _frame_ticks := 0
var _frame_target := -1
var _frame_settle := -1
var _frame_wrong_done := false


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails += 1


func _process(_delta: float) -> bool:
	if _started_at == 0:
		_started_at = Time.get_ticks_msec()
	elif Time.get_ticks_msec() - _started_at > DEADLINE_MS:
		_ok("the whole route finished inside the deadline", false,
			"stuck at step %d of %d" % [_step, _steps.size()])
		return _report()
	if not _started:
		_started = true
		Engine.time_scale = 6.0
		change_scene_to_file(SCENE)
		return false
	_settle += 1
	if _settle < 14:
		return false
	# ⚠️ `not _bootstrapped`, NOT `_level == null`. In Godot 4 a variable holding a FREED node
	# compares equal to null, so the instant the exit door swapped level_3 out for the ending
	# this block re-entered, found `ending.tscn` in `current_scene` and reported
	# "level_3.tscn did not load, or level_3.gd failed to parse" on a run where the exit had
	# just worked. That is the other half of walk_void_live's 24/25.
	if not _bootstrapped:
		_bootstrapped = true
		_level = current_scene
		if _level == null or not _level.has_method("get_stalkers"):
			print("  FAIL level_3.tscn did not load, or level_3.gd failed to parse")
			_fails += 1
			return _report()
		var p := _level.get_node_or_null("Player") as CharacterBody3D
		if p == null:
			_ok("player exists", false)
			return _report()
		for s in ([] if _live else (_level.call("get_stalkers") as Dictionary).values()):
			if is_instance_valid(s):
				_level.remove_child(s)
				s.queue_free()
				_removed += 1
		_ok("live threats retained" if _live else "five stalkers removed for geometry-only walk",
			_removed == 0 if _live else _removed == 5, "%d removed" % _removed)
		_auto = AUTOPLAYER.new(p)
		_min_y = p.global_position.y
		return false

	if _exiting:
		# ⚠️ `current_scene` IS NULL FOR A FRAME during change_scene_to_file's swap, and the old
		# `current_scene != _level` read it straight away: null != _level is true, so the test
		# asserted `null.scene_file_path` -> false and reported a failed exit on a run where the
		# human log shows the exit worked (walk_void_live 24/25, 2026-09-20). Wait for a scene.
		if current_scene != null and current_scene != _level:
			_ok("real E exit reached the ending", current_scene != null and current_scene.scene_file_path == "res://scenes/ending.tscn")
			return _finish()
		if Time.get_ticks_msec() - _exit_started > 5000:
			_ok("exit transition completed within five seconds", false)
			return _report()
		return false

	# The scene reloading under us means the player died (a fall or a trap note read out).
	# Same null-during-swap caveat as the exit branch above.
	if current_scene != null and current_scene != _level:
		_ok("the level did not reload mid-route (a death)", false, "at step %d" % _step)
		return _report()

	var pf := Engine.get_physics_frames()
	var ticks: int = 1 if _last_phys < 0 else maxi(0, pf - _last_phys)
	_last_phys = pf
	_total += ticks
	if _total > TICK_CAP:
		_ok("route finished inside the tick cap", false, "capped at step %d of %d" % [_step, _steps.size()])
		return _report()

	var p: CharacterBody3D = _auto.player
	_min_y = minf(_min_y, p.global_position.y)

	if _read_pending:
		var note_ui := root.get_node("NoteUI")
		_ok("a note opened through the ray", bool(note_ui.get("is_open")))
		note_ui.call("_close")
		_read_pending = false
		_step += 1
		return false

	if _step >= _steps.size():
		return _finish()
	var st: Dictionary = _steps[_step]

	if st.has("stare"):
		if not _live:
			_step += 1
			return false
		_auto.stop()
		var creature: Node = _level.call("get_stalkers")[st["stare"]]
		p.call("ai_look_at", creature.get("_body").global_position + Vector3(0, 0.9, 0))
		_stare_elapsed += ticks * Engine.time_scale / Engine.physics_ticks_per_second
		if _stare_elapsed >= 4.2:
			_step += 1
			_stare_elapsed = 0.0
		return false
	if st.has("read"):
		_read_note(st["read"])
		return false
	if st.has("take"):
		_take_shard(st["take"])
		_step += 1
		return false
	if st.has("take_anchor"):
		_take_anchor(String(st["take_anchor"]))
		_step += 1
		return false
	if st.has("place_anchor"):
		_place_anchor(int(st["place_anchor"]))
		_step += 1
		return false
	if st.has("step_through"):
		if _step_through(ticks):
			_step += 1
		return false
	if st.has("drawers"):
		if _pull_drawers():
			_step += 1
		return false
	if st.has("frames"):
		if _solve_frames(ticks):
			_step += 1
		return false
	if st.has("cradle"):
		_use_cradle(st["cradle"])
		_step += 1
		return false
	if st.has("check"):
		_check(st["check"])
		_step += 1
		return false

	var target: Vector3 = st.get("walk", st.get("lap", Vector3.ZERO))
	# ⚠️ SLOW DOWN FOR AN EXACT LEG. At Engine.time_scale 6 the player covers ~0.40 m per
	# physics tick, so a 0.15 m arrive radius is a coin flip: the walker oscillates across the
	# target forever and the leg "times out twice" while standing 0.2 m from it. player.gd
	# NORMALISES ai_move_dir (player.gd:364), so the harness cannot creep by shortening the
	# vector — the only lever is the clock.
	var exact: bool = st.get("exact", false)
	Engine.time_scale = 1.5 if exact else 6.0
	var arrive: float = 0.15 if exact else (TILE_ARRIVE if st.get("tile", false) else ARRIVE)
	if st.has("lap"):
		var want: int = int(st.get("laps", 1))
		var laps: int = int(_level.call("loop_laps"))
		if laps >= want:
			_ok("the loop corridor sent the player back (lap %d)" % want,
				true, "%d lap(s), z %.1f -> %.1f" % [laps, _lap_start_z, p.global_position.z])
			_step += 1
			_hop = 0
			_lap_start_z = 0.0
			_auto.reset_stuck()
			return false
		if _lap_start_z == 0.0:
			_lap_start_z = p.global_position.z
	else:
		var flat := Vector2(target.x - p.global_position.x, target.z - p.global_position.z)
		if flat.length() <= arrive:
			_step += 1
			_hop = 0
			_auto.reset_stuck()
			return false

	_steer(target)
	_hop += ticks
	if _hop > TICKS_PER_HOP:
		if st.has("lap"):
			_ok("the loop corridor sent the player back (lap %d)" % int(st.get("laps", 1)), false,
				"walked %d ticks up the loop, laps still %d" % [_hop, int(_level.call("loop_laps"))])
			_step += 1
			_hop = 0
			return false
		# One retry by backing to the previous waypoint (walk_dungeon.gd's rule): straight-line
		# steering can wedge on a jamb, and that is the harness, not the level.
		if not _retried.has(_step) and _step > 0 and _steps[_step - 1].has("walk"):
			_retried[_step] = true
			_step -= 1
			_hop = 0
			_auto.reset_stuck()
			return false
		_stalls += 1
		_ok("leg %d reached %s" % [_step, target], false, "timed out twice")
		_step += 1
		_hop = 0
		_auto.reset_stuck()
	return false


# ⭐ THE QUEST, through the real ray in every case (2026-09-20 pass 3).
#
# ⚠️ Never `anchor.interact()` / `socket.interact()`. The whole question is whether a player who
# has WALKED here can see the thing and get a prompt — Issue 30's lesson, and Issue 226's: a
# socket's prompt is gated to 1.5 m of its own tile, so arriving 0.9 m out is arriving somewhere
# the puzzle is deliberately not offered.
func _take_anchor(id: String) -> void:
	var p: CharacterBody3D = _auto.player
	var node := _level.get_node_or_null("Anchor_" + id) as Node3D
	if node == null:
		_ok("the %s is in the world" % id, false)
		return
	_auto.stop()
	p.velocity = Vector3.ZERO
	p.call("ai_look_at", node.global_position)
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.force_update_transform()
	var t: Node = p.call("ai_interact_target")
	_ok("the ray finds the %s from the walked approach" % id,
		t == node or (t != null and node.is_ancestor_of(t)),
		"from %v, ray hit %s" % [p.global_position, t.name if t else "nothing"])
	p.call("ai_interact")
	_ok("E takes the %s and the level carries it" % id,
		String(_level.call("carried_anchor")) == id,
		"carrying '%s', HUD '%s'" % [_level.call("carried_anchor"),
			root.get_node("GameState").get("carried_item")])


func _place_anchor(view: int) -> void:
	var p: CharacterBody3D = _auto.player
	var puzzle := _level.get_node("AlignmentKeystone") as Node3D
	var names := ["", "KeystoneBed", "KeystoneWindow"]
	var key: Node3D = puzzle if view == 0 else puzzle.get_node_or_null(names[view]) as Node3D
	var nm: String = String((puzzle.get("VIEWS") as Array)[view]["nm"])
	_auto.stop()
	p.velocity = Vector3.ZERO
	p.call("ai_look_at", key.global_position)
	p.get_node("Camera3D").force_update_transform()
	var t: Node = p.call("ai_interact_target")
	_ok("%s: the socket is reached from the walked viewpoint" % nm, t == key,
		"at %v, ray hit %s" % [p.global_position, t.name if t else "nothing"])
	_ok("%s: the socket invites the object in hand" % nm,
		String(key.call("prompt_text")).begins_with("E — Set"),
		"'%s'" % key.call("prompt_text"))
	p.call("ai_interact")
	_ok("%s: E seats the anchor and empties the hands" % nm,
		bool(puzzle.call("socket_filled", view)) and String(_level.call("carried_anchor")) == "")


# Stand in Hall2's flat doorframe until it drops you out of the one in LoopIn.
func _step_through(ticks: int) -> bool:
	var p: CharacterBody3D = _auto.player
	if _step_before < 0:
		_step_before = int(_level.call("step_drops"))
		_step_yaw = p.rotation.y
		_auto.stop()
		p.velocity = Vector3.ZERO
	_step_ticks += ticks
	if int(_level.call("step_drops")) > _step_before:
		_ok("standing in the flat doorframe drops the player through it",
			p.global_position.distance_to(Vector3(8.0, 0.1, 15.3)) < 0.5,
			"landed at %v after %d ticks" % [p.global_position, _step_ticks])
		_ok("…keeping the heading it was walking on",
			absf(angle_difference(_step_yaw, p.rotation.y)) < 0.01,
			"yaw %.3f -> %.3f" % [_step_yaw, p.rotation.y])
		_step_before = -1
		_step_ticks = 0
		_auto.reset_stuck()
		return true
	if _step_ticks > 900:
		_ok("the flat doorframe dropped the player inside its budget", false,
			"%d ticks standing in it, %d drops" % [_step_ticks, int(_level.call("step_drops"))])
		_step_before = -1
		_step_ticks = 0
		return true
	return false


# ⭐ SEARCH. Pull fronts through the real ray until the page turns up; assert that exactly one
# of the seventeen held anything, and read the page where it lies.
func _pull_drawers() -> bool:
	var p: CharacterBody3D = _auto.player
	var drawers: Array = _level.call("drawers")
	if _drawer_i >= drawers.size():
		_ok("every drawer opened through the ray", _drawers_opened == drawers.size(),
			"%d of %d" % [_drawers_opened, drawers.size()])
		_ok("exactly ONE of the %d drawers held a page" % drawers.size(), _pages_found == 1,
			"%d pages" % _pages_found)
		return true
	var d: Node3D = drawers[_drawer_i]
	_drawer_i += 1
	# ⚠️ ONE OF THE SEVENTEEN IS ALREADY OUT (pass 4), and an open drawer has nothing to offer:
	# `can_interact()` is false and `_retire()` has taken its box out of the ray's way, which is
	# Issue 231's fix. Counting it as "unreachable" would be counting the fix as the bug.
	if bool(d.call("is_open")):
		_drawers_opened += 1
		_ok("drawer %s was already pulled at load (the bank's visible moving part)" % d.name, true)
		return false
	# Stand a metre out from this front, and aim at the FRONT FACE of its interact box rather
	# than at the body's centre: the box stands 0.09 m proud of the carcass and the open drawer
	# above a bottom-row one can graze a ray aimed at the centre from a fixed stance.
	var at: Vector3 = d.global_position + d.global_transform.basis.z * 0.22
	p.global_position = Vector3(at.x, 0.1, at.z - 1.0)
	p.velocity = Vector3.ZERO
	p.force_update_transform()
	p.call("ai_look_at", at)
	p.get_node("Camera3D").force_update_transform()
	var t: Node = p.call("ai_interact_target")
	if t == d or (t != null and d.is_ancestor_of(t)):
		p.call("ai_interact")
		if bool(d.call("is_open")):
			_drawers_opened += 1
	else:
		_ok("drawer %s is reachable" % d.name, false,
			"ray hit %s" % (t.name if t else "nothing"))
	var page := d.get_node_or_null("DrawerPage") as Node3D
	if page != null:
		_pages_found += 1
		_ok("the drawer that holds the page is %s" % d.name, true)
	return false


# The shard in the Archive's inverted table, through the real ray. ⚠️ Never `shard.interact()`:
# the whole question is whether a player who has watched a table re-pose itself can SEE it.
func _take_shard(nm: String) -> void:
	var p: CharacterBody3D = _auto.player
	var shard := _level.get_node_or_null(nm) as Node3D
	if shard == null:
		_ok("the slab shard exists", false)
		return
	_auto.stop()
	p.velocity = Vector3.ZERO
	p.call("ai_look_at", shard.global_position)
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.force_update_transform()
	var t: Node = p.call("ai_interact_target")
	_ok("the interact ray finds the shard under the slab", t == shard or (t != null and shard.is_ancestor_of(t)),
		"from %s, ray hit %s" % [p.global_position, t.name if t else "nothing"])
	p.call("ai_interact")
	# ⚠️ `has_shard()`, not `carried_item == "stone shard"`. The HUD line is COMPOSED since
	# pass 3 ("a stone shard · a door handle"), so an equality test against it started
	# returning false for a player who was carrying both.
	_ok("E takes the shard and the level carries it", bool(_level.call("has_shard")),
		"HUD reads '%s'" % root.get_node("GameState").get("carried_item"))


func _use_cradle(nm: String) -> void:
	var p: CharacterBody3D = _auto.player
	var cradle := _level.get_node_or_null(nm) as Node3D
	if cradle == null:
		_ok("the cradle exists", false)
		return
	_auto.stop()
	p.velocity = Vector3.ZERO
	p.call("ai_look_at", cradle.global_position + Vector3(0, 0.9, 0))
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.force_update_transform()
	var t: Node = p.call("ai_interact_target")
	_ok("the interact ray finds the cradle body (not a nested volume)",
		t == cradle or (t != null and cradle.is_ancestor_of(t)),
		"from %s, ray hit %s" % [p.global_position, t.name if t else "nothing"])
	p.call("ai_interact")
	_ok("setting the shard completes the cradle", bool(cradle.get("done")))
	_ok("...and the shard is no longer carried", not bool(_level.call("has_shard")),
		"HUD reads '%s'" % root.get_node("GameState").get("carried_item"))


func _read_note(nm: String) -> void:
	var p: CharacterBody3D = _auto.player
	var note := _level.get_node_or_null(nm) as Node3D
	if note == null:
		_ok("note %s exists" % nm, false)
		_step += 1
		return
	_auto.stop()
	p.velocity = Vector3.ZERO
	p.call("ai_look_at", note.global_position)
	var cam := p.get_node_or_null("Camera3D") as Camera3D
	if cam:
		cam.force_update_transform()
	var t: Node = p.call("ai_interact_target")
	var hit: bool = t == note or (t != null and note.is_ancestor_of(t))
	_ok("the interact ray finds %s from the walked approach" % nm, hit,
		"from %s, ray hit %s" % [p.global_position, t.name if t else "nothing"])
	if not hit:
		_step += 1
		return
	p.call("ai_interact")
	_read_pending = true


# A horizontal physics sweep across the LoopIn <-> LoopStraight doorway. ⚠️ A ray, not
# `get_node_or_null("LoopWallPlug") != null`: a wall's is_solid() was true for the whole life
# of a wall that was a hole in the world, and object state is not geometry.
func _plug_ray() -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(10.0, 1.0, 15.5), Vector3(12.0, 1.0, 15.5), 1)
	return _level.get_world_3d().direct_space_state.intersect_ray(q)


# Press E on one keystone from the viewpoint the walk has arrived at.
func _press_keystone(node_name: String, view: int, label: String, expect_seal: bool) -> void:
	var p: CharacterBody3D = _auto.player
	_auto.stop()
	p.velocity = Vector3.ZERO
	var puzzle := _level.get_node("AlignmentKeystone") as Node3D
	var key: Node3D = puzzle if node_name == "" else puzzle.get_node_or_null(node_name) as Node3D
	if key == null:
		_ok("%s: the keystone exists" % label, false)
		return
	p.call("ai_look_at", key.global_position)
	p.get_node("Camera3D").force_update_transform()
	# ⭐ THE PLACE GATE, from a WALKED position (2026-09-20 pass 2) — not a teleport. If the
	# autoplayer's real arrival is outside the keystone's 1.5 m gate there is no prompt and no
	# target, which is precisely the failure the 13:10 playtest could not distinguish from a
	# wrong angle.
	_ok("%s: the prompt is offered where the walk actually arrived" % label,
		bool(key.call("can_interact")), "at %s" % p.global_position)
	_ok("%s: a filled socket offers the hold" % label,
		String(key.call("prompt_text")) == "E — Hold the shape.", "'%s'" % key.call("prompt_text"))
	_ok("%s: the ray reaches the keystone from the walked viewpoint" % label,
		p.call("ai_interact_target") == key, "at %s" % p.global_position)
	p.call("ai_interact")
	_ok("%s: E holds this shape" % label, bool(puzzle.call("view_solved", view)))
	var q := PhysicsRayQueryParameters3D.create(Vector3(-8.4, 1, 45.5), Vector3(-9.5, 1, 45.5), 1)
	var hit: Dictionary = _level.get_world_3d().direct_space_state.intersect_ray(q)
	if expect_seal:
		# CONTROL: one and two shapes open NOTHING. The seal is still a physical wall.
		_ok("%s: the seal is still solid (%d/3)" % [label, int(puzzle.call("solved_count"))], not hit.is_empty())
	else:
		# ⚠️ The collider is disabled with set_deferred, so the sweep is a SEPARATE step
		# ("seal_open") a leg later. Asserting it in this frame reads the pre-deferral state.
		_ok("%s: the third shape completes the puzzle" % label, bool(puzzle.get("solved")))


func _check(what: String) -> void:
	var p: CharacterBody3D = _auto.player
	match what:
		# ⚠️ THE ORDER CHANGED IN PASS 3 and the seal expectation moves with it: the handle is
		# found first (PocketA), the latch second (Hall2, 8 m from the tiles) and the slat last,
		# because it costs the walk back to the Ward. The BED is now the third shape held.
		"solve_bed":
			_press_keystone("KeystoneBed", 1, "bed / spine tile", false)
		"solve_door":
			_press_keystone("", 0, "door / island", true)
		"solve_window":
			_press_keystone("KeystoneWindow", 2, "window / south branch", true)
		"shard_hidden":
			# ⚠️ THE INVARIANT, NOT THE MOMENT. In the LIVE run the walker keeps its eyes on
			# whichever creature is nearest, so the Archive's table can arm and re-pose several
			# legs earlier than the geometry route reaches this step — and asserting "the shard
			# is hidden HERE" made walk_void_live fail on a run where everything worked. What is
			# true in both runs is that the shard is in the world exactly when the table has
			# moved; the ray control below then runs whenever it still has something to prove.
			var sh = _level.call("shard")
			var tbl := _level.get_node_or_null("InvertedTable_Archive")
			_ok("the shard is in the world exactly when the table has re-posed",
				sh != null and tbl != null and bool(sh.call("is_revealed")) == bool(tbl.get("spent")),
				"revealed %s, table spent %s" % [sh.call("is_revealed") if sh else "-",
					tbl.get("spent") if tbl else "-"])
			if tbl != null and not bool(tbl.get("spent")):
				# CONTROL: and the E-ray cannot find it either — the table is in the way.
				p.call("ai_look_at", sh.global_position)
				p.get_node("Camera3D").force_update_transform()
				var t0: Node = p.call("ai_interact_target")
				_ok("CONTROL: …and the interact ray finds no shard from the doorway side",
					t0 != sh, "ray hit %s" % (t0.name if t0 else "nothing"))
			else:
				print("  NOTE  the table had already re-posed by this leg (live steering) —"
					+ " the hidden-shard ray control runs in the geometry walk")
		"shard_revealed":
			var table := _level.get_node_or_null("InvertedTable_Archive")
			var sh2 = _level.call("shard")
			_ok("looking away re-posed the table", table != null and bool(table.get("spent")))
			_ok("…and it is the prop's own off-screen beat that did it, not a call",
				table != null and not bool(table.get("armed")))
			_ok("…and that is what put the shard in the world",
				sh2 != null and bool(sh2.call("is_revealed")) and sh2.visible)
		"socket_refuses_empty":
			# The sockets start EMPTY: three identical diamonds standing at the tiles is what
			# the 15:00 playtest solved in 8.7 s.
			var puzzle := _level.get_node("AlignmentKeystone")
			_ok("the island's socket is filled only by the object that belongs to it",
				not bool(puzzle.call("socket_filled", 0)) and not bool(puzzle.call("socket_filled", 1))
				and not bool(puzzle.call("socket_filled", 2)))
		"wrong_anchor_refused":
			# CONTROL: the LATCH is in hand and this is the WINDOW's tile, so it fits — press
			# the BED's socket instead (its own tile is 5 m away, so use the call the keystone
			# makes) and require the refusal to change nothing and cost nothing.
			var puzzle2 := _level.get_node("AlignmentKeystone")
			var before := float(p.call("get_panic_ratio"))
			puzzle2.call("socket_interact", 1)
			_ok("CONTROL: the wrong socket refuses the latch",
				not bool(puzzle2.call("socket_filled", 1))
				and String(_level.call("carried_anchor")) == "latch")
			_ok("CONTROL: …and a refusal costs no panic",
				float(p.call("get_panic_ratio")) <= before + 0.001)
		"stepped_out_in_time":
			_ok("the latch can be taken and left before the frame drops you",
				int(_level.call("step_drops")) == 0, "%d drops" % int(_level.call("step_drops")))
		"loop_note_illegible":
			var note := _level.get_node_or_null("LoopNote")
			if note == null:
				_ok("LoopNote exists", false)
				return
			_ok("at lap 1 the loop note is still illegible",
				int(note.get("laps")) == 1 and String(note.call("prompt_text")).find("E ") < 0,
				"laps %d, prompt '%s'" % [int(note.get("laps")), note.call("prompt_text")])
			# CONTROL: E on it at lap 1 must open NOTHING — the prompt is not just flavour.
			note.call("interact")
			_ok("...and E on it opens no note at lap 1",
				not bool(root.get_node("NoteUI").get("is_open")))
		"plug_present":
			var hit: Dictionary = _plug_ray()
			_ok("at lap 2 the way back is WALLED UP", not hit.is_empty(),
				"ray hit %s" % (hit.get("collider").name if hit.has("collider") else "nothing"))
		"plug_gone":
			_ok("reading the note takes the wall back out", _plug_ray().is_empty())
		"seal_open":
			var q := PhysicsRayQueryParameters3D.create(Vector3(-8.4, 1, 45.5), Vector3(-9.5, 1, 45.5), 1)
			_ok("three shapes held: the seal is physically gone",
				_level.get_world_3d().direct_space_state.intersect_ray(q).is_empty())
		"secret_opened":
			# ⚠️ A RAY, not a flag. A wall's own state was true for the whole life of a wall that
			# was a hole in the world; the question is whether the player can walk through it.
			var q2 := PhysicsRayQueryParameters3D.create(
				Vector3(-20.4, 1.0, 47.5), Vector3(-21.6, 1.0, 47.5), 1)
			_ok("completing the cradle opened the Morgue's west wall",
				_level.get_world_3d().direct_space_state.intersect_ray(q2).is_empty())
			_ok("…and the level says the secret door is open", bool(_level.call("secret_open")))
		"sanctum_still_sealed":
			_ok("…and the cradle did NOT retract the stone plate any more",
				_level.get_node_or_null("SanctumPlate") != null)
		"in_frame_hall":
			var fr: Rect2 = _level.call("_room_rect", "FrameHall")
			_ok("the player walked into the sixteenth room on foot",
				fr.has_point(Vector2(p.global_position.x, p.global_position.z)),
				"at %v, room %s" % [p.global_position, fr])
		"sanctum_unsealed":
			_ok("reading the hidden page removed the stone plate",
				_level.get_node_or_null("SanctumPlate") == null)
		"loop_broken":
			_ok("reading the corridor note breaks the loop", bool(_level.call("loop_broken")))
		"no_more_laps":
			_ok("no further teleport after the note (walked to z %.1f)" % p.global_position.z,
				int(_level.call("loop_laps")) == 2 and p.global_position.z > 40.0,
				"laps %d" % int(_level.call("loop_laps")))
		"still_on_the_tiles":
			_ok("crossed the causeway without falling", _min_y > -0.6, "lowest y %.2f" % _min_y)
		"exit_locked_before_twist":
			var d := _level.get_node_or_null("ExitDoor")
			_ok("the exit is LOCKED before the twist note", d != null and not bool(d.call("_is_unlocked")))
		"twist_read":
			_ok("the twist note set GameState.twist_read",
				bool(root.get_node("GameState").get("twist_read")))
		"exit_unlocked_and_found":
			var d := _level.get_node_or_null("ExitDoor") as Node3D
			if d == null:
				_ok("ExitDoor exists", false)
				return
			_auto.stop()
			p.velocity = Vector3.ZERO
			p.call("ai_look_at", d.global_position)
			var cam := p.get_node_or_null("Camera3D") as Camera3D
			if cam:
				cam.force_update_transform()
			var t: Node = p.call("ai_interact_target")
			_ok("the interact ray finds the ExitDoor from the walked approach",
				t == d or (t != null and d.is_ancestor_of(t)), "hit %s" % (t.name if t else "nothing"))
			_ok("…and it is unlocked", bool(d.call("_is_unlocked")))
			if _live:
				p.call("ai_interact")
				_exiting = true
				_exit_started = Time.get_ticks_msec()
		_:
			_ok("unknown check " + what, false)


func _steer(target: Vector3) -> void:
	var p: CharacterBody3D = _auto.player
	var aim := Vector3(target.x, p.global_position.y + 1.2, target.z)
	if _live:
		var nearest := 7.8
		for id in (_level.call("get_stalkers") as Dictionary):
			var s: Node = _level.call("get_stalkers")[id]
			var body := s.get("_body") as Node3D
			var distance := p.global_position.distance_to(body.global_position)
			if bool(s.get("_awakened")):
				_encounters[id] = true
			if distance < nearest:
				var query := PhysicsRayQueryParameters3D.create(p.get_node("Camera3D").global_position,
					body.global_position + Vector3(0, 0.9, 0))
				query.exclude = [p.get_rid(), body.get_rid()]
				if p.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
					nearest = distance
					aim = body.global_position + Vector3(0, 0.9, 0)
	p.call("ai_look_at", aim)
	var direction := target - p.global_position
	direction.y = 0
	var local := p.global_basis.inverse() * direction.normalized()
	p.set("ai_move_dir", Vector2(local.x, local.z))
	p.set("ai_sprint", false)


func _finish() -> bool:
	if _live:
		_ok("all five encounters were activated", _encounters.size() == 5, str(_encounters.keys()))
		_ok("completion had no fatal event", not root.get_node("Screamer").get("_is_triggering"))
	_ok("every leg walked under gravity", _stalls == 0, "%d stalls, %d physics ticks" % [_stalls, _total])
	if _auto:
		_auto.release()
	return _report()


func _report() -> bool:
	if _checks < 55:
		print("  FAIL only %d checks ran — did the route abort early?" % _checks)
		_fails += 1
	print("  %d checks, %d failed" % [_checks, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true


# ⭐ THE HALL OF FRAMES, walked (2026-09-20 pass 4).
#
# The route steps through all five in the answer order — with ONE DELIBERATE WRONG STEP first, so
# the slam, the dead lamp and the off-screen re-scramble are on the walked path and not only in
# `check_void_frames.gd`. Every entry is on foot: the player is put down at the frame's own
# drop-out point, a metre out on the floor, and WALKS the last metre under `ai_move_dir` with the
# real body. ⚠️ Never `_step()` or `apply_scramble()` — the whole question is whether the 1.2 s
# dwell fires for someone who walked here.
const FRAME_LEG_TICKS := 900


func _solve_frames(ticks: int) -> bool:
	var p: CharacterBody3D = _auto.player
	var hall: Node = _level.call("frame_hall")
	if hall == null:
		_ok("the Hall of Frames exists", false)
		return true
	var answer: Array = hall.call("answer_order")
	var progress: int = int(hall.call("progress"))
	if _frame_leg < 0:
		_frame_leg = 0
		_frame_ticks = 0
		_auto.stop()
		p.velocity = Vector3.ZERO
		_ok("the frames start scrambled and unsolved",
			not bool(hall.call("is_solved")) and progress == 0,
			"order %s" % str(hall.call("frame_ids")))
	# Which frame are we aiming at? One wrong step first, then the answer order.
	var want: String = String(answer[mini(progress, answer.size() - 1)])
	if not _frame_wrong_done:
		want = String(answer[2])
	var slot: int = int(hall.call("slot_of", want))
	if _frame_target != slot:
		_frame_target = slot
		_frame_ticks = 0
		p.global_position = hall.call("front_point", slot)
		p.velocity = Vector3.ZERO
		p.force_update_transform()
	var aim: Vector3 = hall.call("dwell_point", slot)
	p.call("ai_look_at", aim + Vector3(0, 1.2, 0))
	var dir: Vector3 = aim - p.global_position
	dir.y = 0.0
	if dir.length() > 0.2:
		var local := p.global_basis.inverse() * dir.normalized()
		p.set("ai_move_dir", Vector2(local.x, local.z))
	else:
		p.set("ai_move_dir", Vector2.ZERO)
	_frame_ticks += ticks
	# Wrong step landed?
	if not _frame_wrong_done and int(hall.call("wrong_count")) > 0:
		_frame_wrong_done = true
		_frame_target = -1
		var fr: Rect2 = _level.call("_room_rect", "FrameHall")
		_ok("a wrong step drops the player back out, on the floor and inside the room",
			fr.has_point(Vector2(p.global_position.x, p.global_position.z)),
			"at %v" % p.global_position)
		_ok("…and it does not advance the answer", int(hall.call("progress")) == 0)
		_ok("…and it marks the frames to re-scramble behind the player's back",
			bool(hall.call("rescramble_pending")))
		# Face the doorway and wait for the prop's own off-screen beat.
		p.call("ai_look_at", Vector3(-19.0, 1.2, 47.5))
		p.set("ai_move_dir", Vector2.ZERO)
		_frame_ticks = 0
		return false
	if _frame_wrong_done and bool(hall.call("rescramble_pending")):
		# still re-scrambling: keep looking away
		p.call("ai_look_at", Vector3(-19.0, 1.2, 47.5))
		p.set("ai_move_dir", Vector2.ZERO)
		_frame_target = -1
		if _frame_ticks > FRAME_LEG_TICKS:
			_ok("the frames re-scrambled once the player looked away", false,
				"still pending after %d ticks" % _frame_ticks)
			return true
		return false
	if int(hall.call("progress")) > _frame_leg:
		_frame_leg = int(hall.call("progress"))
		_frame_target = -1
		_frame_ticks = 0
		var fr2: Rect2 = _level.call("_room_rect", "FrameHall")
		if not fr2.has_point(Vector2(p.global_position.x, p.global_position.z)):
			_ok("right step %d left the player inside the room" % _frame_leg, false,
				"at %v" % p.global_position)
	if bool(hall.call("is_solved")):
		if _frame_settle < 0:
			_frame_settle = 0
			return false
		_frame_settle += ticks
		if _frame_settle < 200:
			return false
		var note := _level.get_node_or_null("HiddenNote")
		_ok("stepping through all five in the order they were met solves it",
			int(hall.call("progress")) == 5)
		_ok("…the five line up into a corridor at x -24",
			absf((hall.call("unit", 0) as Node3D).global_position.x + 24.0) < 0.05)
		_ok("…and the page at its end is in the world, through the wrong step and back",
			note != null and bool(note.call("is_revealed")))
		_auto.reset_stuck()
		return true
	if _frame_ticks > FRAME_LEG_TICKS:
		_ok("the dwell at slot %d fired inside its budget" % slot, false,
			"%d ticks, dwell %.2f s, at %v"
				% [_frame_ticks, float(hall.call("dwell_seconds")), p.global_position])
		return true
	return false
