extends SceneTree

# THE VOID (level_3.tscn) — the mechanics behind the three impossible spaces, and the roster.
#
#   * the loop corridor: the seam sends a +z walker back exactly one period with HEADING and
#     VELOCITY preserved (backrooms.gd's teleport zeroes velocity; seamlessness needs it kept),
#     ignores a -z walker, and stops for good once the corridor's note has been read
#   * the floating tiles: CreatureD is watch-only while the player is on them (it watches, it
#     never steps) and stalks again the moment they are off — with a live control that drops
#     the level's tile rect and requires it to step
#   * five stalkers, every one with the scrape tell and every one still lethal (D10)
#   * five safe notes + the twist + three read-to-die traps, the twist inside the Sanctum
#   * the three DarkZones, the DreadZone over the far wing, the Threshold's CalmZone
#   * save_progress() / _restore_progress() round-trip notes_read / loop_broken / loop_laps
#   * a player below FALL_Y arms the screamer on the next frame (asserted, then quit before
#     the reload)
#
# Usage: Godot --headless --path game --script res://tests/check_void.gd

const SCENE := "res://scenes/level_3.tscn"
# ⚠️ THIS FILE HAD NO DEADLINE AND COULD HANG THE WHOLE SUITE. Found 2026-09-20 by running a
# deliberately-broken build as a positive control: with the loop note's refusal disabled, the
# lap-1 control press BROKE the loop, so the second lap could never happen, the waiting stage
# had no match arm, and the test span in _process forever. A guard that can hang is worse
# than one that fails — run_tests.sh never finishes and nothing downstream runs.
const DEADLINE_MS := 120000
const LAP_BUDGET := 1500        # physics ticks one lap of the corridor may take

var _started_at := 0
var _fails := 0
var _checks := 0
var _started := false
var _settle := 0
var _level: Node = null
var _p: CharacterBody3D = null
var _stage := 0
var _wait := 0          # physics ticks still to wait in the current stage
var _last_phys := -1
var _d_start := Vector3.ZERO
var _tile_rect := Rect2()
var _yaw0 := 0.0
var _lap_ticks := 0
var _stalkers: Dictionary = {}
var _want_laps := 1
var _after_lap := 5
var _head_y0 := 0.0
var _flicker_samples: Array = []
var _flicker_ticks := 0


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
		_ok("the whole run finished inside the deadline", false, "stuck at stage %d" % _stage)
		return _report()
	if not _started:
		_started = true
		change_scene_to_file(SCENE)
		return false
	_settle += 1
	if _settle < 14:
		return false
	if _level == null:
		_level = current_scene
		if _level == null or not _level.has_method("get_stalkers"):
			print("  FAIL level_3.tscn did not load, or level_3.gd failed to parse")
			_fails += 1
			return _report()
		_p = _level.get_node_or_null("Player") as CharacterBody3D
		if _p == null:
			_ok("player exists", false)
			return _report()
		_structural()
		_drawing_begin()
		return false
	if current_scene != _level and _stage < 9:
		_ok("the level did not reload mid-test", false, "stage %d" % _stage)
		return _report()
	var t := _ticks()
	# ⚠️ Stage 40 (walking the loop) is polled EVERY frame, not only while `_wait` is counting
	# down. It used to ride inside the _wait branch, so when the wait expired the poll stopped
	# and the stage — which has no match arm — span until the global deadline. The budget
	# inside _watch_lap is what should catch a corridor that stops looping.
	if _stage == 40:
		_watch_lap(t)
		return false
	if _stage == 41:
		_watch_flicker(t)
		return false
	if _wait > 0:
		_wait -= t
		return false
	match _stage:
		68: _drawing_control()
		69: _drawing_released()
		70: _cradle_begin()
		71: _cradle_rising()
		72: _cradle_lunged()
		73: _cradle_control()
		74: _cradle_after()
		1: _begin_watch_only()
		2: _end_watch_only()
		21: _head_frozen_begin()
		22: _head_frozen_end()
		3: _watch_control()
		60: _step_dwell_begin()
		61: _step_dwell_short()
		62: _step_dwell_done()
		63: _step_loopin_begin()
		64: _step_loopin_done()
		4: _begin_lap()
		5: _end_lap()
		42: _after_flicker()
		51: _end_lap_two()
		6: _reverse()
		7: _broken()
		8: _snapshot()
		9: _fall()
		10: return _fall_result()
	return false


# The Void's figure and its head pivot, straight off the live stalker.
func _figure(id: String) -> Node3D:
	var s = _stalkers.get(id)
	if s == null or not is_instance_valid(s):
		return null
	var body := s.get("_body") as Node3D
	return body.get_node_or_null("FracturedFigure") as Node3D if body else null


func _all_nodes(n: Node, out: Array = []) -> Array:
	for c in n.get_children():
		out.append(c)
		_all_nodes(c, out)
	return out


func _is_note_script(script: Script) -> bool:
	var base: Script = load("res://scripts/note.gd")
	var s: Script = script
	while s != null:
		if s == base:
			return true
		s = s.get_base_script()
	return false


# ── structure ─────────────────────────────────────────────────────────────────
func _structural() -> void:
	_stalkers = _level.call("get_stalkers")
	_ok("five stalkers", _stalkers.size() == 5, str(_stalkers.keys()))
	var tells := 0
	var lethal := 0
	for s in _stalkers.values():
		if bool(s.get("scrape_tell")):
			tells += 1
		if bool(s.get("lethal")):
			lethal += 1
	_ok("every stalker carries the scrape tell", tells == _stalkers.size(), "%d of %d" % [tells, _stalkers.size()])
	_ok("every stalker is still lethal (D10: the Void keeps its teeth)", lethal == _stalkers.size(), "%d of %d" % [lethal, _stalkers.size()])

	var safe := 0
	var trap := 0
	var twist: Node3D = null
	# ⚠️ Walk the BASE-SCRIPT chain. `LoopNote` is `void_loop_note.gd`, a note.gd subclass, and
	# `ends_with("note.gd")` matched it only by the accident of its filename.
	# ⚠️ AND WALK THE WHOLE TREE, not just the level's direct children (2026-09-20 pass 3): the
	# Morgue's pointer page lives INSIDE a drawer body so that it slides out with the front, and
	# a top-level scan counted eight notes in a level that has eleven.
	for c in _all_nodes(_level):
		if _is_note_script(c.get_script()):
			if bool(c.get("is_trap")):
				trap += 1
			else:
				safe += 1
			if bool(c.get("is_twist_note")):
				twist = c
	# 5 safe + the twist + the slab's torn page + the page in the drawer + pass 4's hidden page.
	_ok("nine non-trap notes (five, the twist, the two Morgue pages, the hidden one)",
		safe == 9, "%d" % safe)
	_ok("three read-to-die trap notes", trap == 3, "%d" % trap)
	_ok("exactly one twist note", twist != null)
	if twist:
		var sr: Rect2 = _level.call("_room_rect", "Sanctum")
		_ok("the twist note hangs inside the Sanctum",
			sr.has_point(Vector2(twist.global_position.x, twist.global_position.z)),
			"%s in %s" % [twist.global_position, sr])

	var dark := 0
	var dread := 0
	var calm := 0
	for c in _level.get_children():
		if c is DarkZone:
			dark += 1
		elif c is DreadZone:
			dread += 1
		elif c is CalmZone:
			calm += 1
	_ok("two DarkZones (morgue, child's room)", dark == 2, "%d" % dark)
	_ok("one DreadZone over the far wing", dread == 1, "%d" % dread)
	_ok("one CalmZone at the Threshold", calm == 1, "%d" % calm)

	var exit := _level.get_node_or_null("ExitDoor")
	var back := _level.get_node_or_null("BackDoor")
	_ok("ExitDoor waits on the twist note", exit != null and int(exit.get("unlock_condition")) == 3)
	_ok("BackDoor goes back", back != null and bool(back.get("goes_back")))
	_tile_rect = _level.call("tile_rect")
	_ok("the tile hall rect is published", _tile_rect.size.x > 5.0, str(_tile_rect))

	# ⭐ LAP ZERO — the state a normal player meets the loop note in, and the one both runs of
	# the 2026-09-20 playtest read it in. It must be a note.gd SUBCLASS, it must still show a
	# prompt (can_interact() false would hide it entirely and make it read as scenery), the
	# prompt must not offer E, and E must open nothing.
	var loop_note := _level.get_node_or_null("LoopNote")
	_ok("LoopNote is a note.gd subclass with its own lap counter",
		loop_note != null and _is_note_script(loop_note.get_script())
		and loop_note.get_script() != load("res://scripts/note.gd") and int(loop_note.get("laps")) == 0)
	if loop_note:
		# ⭐ 2026-09-20 pass 2: at lap 0 the page IS NOT IN THE WORLD. Not "visible but
		# refusing" — capture #2 photographed that and called it weird. Both halves are
		# asserted: the mesh is hidden AND the interact ray passes straight through it.
		_ok("…and at lap 0 it is INVISIBLE", not loop_note.visible)
		_ok("…and the interact ray passes through where it hangs", _note_ray().is_empty(),
			"ray hit %s" % _note_ray().get("collider", "nothing"))
		_ok("…and that prompt does not offer E", String(loop_note.call("prompt_text")).find("E ") < 0,
			"'%s'" % loop_note.call("prompt_text"))
		loop_note.call("interact")
		_ok("CONTROL: E on the loop note at lap 0 opens nothing",
			not bool(root.get_node("NoteUI").get("is_open")) and not bool(_level.call("loop_broken")))

	_mask_checks()
	_pass3_checks()
	_pass4_checks()
	# ⚠️ `RandomAmbient` IS UNREGISTERED FOR THE REST OF THIS FILE, and it is not tidying: that
	# autoload is global, fires on a random timer in every level, and two of its three events are
	# `add_panic(8.0)` and `add_panic(12.0)`. `check_void_frames` reported "the page costs no
	# panic — 0.072" against an innocent room because a `painting_fall` landed during the beat it
	# was measuring. Any zero-panic claim measured with it running is a coin flip.
	root.get_node("RandomAmbient").call("register_player", null)

	# ⭐ THE RETURN BEATS' AUDIO (2026-09-20 pass 2). A base name that does not resolve is a
	# silent failure: GameState.AUDIO_SUBDIRS is a hardcoded list and a new folder is invisible
	# to it. Every sound the ladder plays is loaded here, by the same call the level makes.
	for base in ["loop_slam", "paper_drop", "stone_grind", "footstep", "stalker_whisper"]:
		_ok("the loop's '%s' resolves through GameState.load_audio" % base,
			root.get_node("GameState").call("load_audio", base) != null)
	var slam := _level.get_node_or_null("LoopSlam") as AudioStreamPlayer3D
	_ok("the send-back slam sits at the LoopIn doorway behind the player",
		slam != null and slam.position.distance_to(Vector3(11.0, 1.5, 15.5)) < 0.01,
		str(slam.position) if slam else "missing")
	var whisper := _level.get_node_or_null("LoopWhisperSouth") as AudioStreamPlayer3D
	_ok("the second whisper emitter exists at the corridor's south end",
		whisper != null and whisper.position.distance_to(Vector3(12.5, 0.9, 15.0)) < 0.01)
	_ok("…and it is SILENT before lap 2", whisper != null and not whisper.playing)

	# ⭐ THE BED LOOPS (2026-09-20 pass 2). `ambient_void.ogg.import` ships loop=false, so the
	# music died after one play (capture #5: "The music stopped playing"). level_3.gd sets it
	# in code; a re-import cannot regress it and this asserts it cannot be dropped.
	var amb := _level.get_node_or_null("AmbientPlayer") as AudioStreamPlayer
	_ok("the ambient bed is loaded and LOOPS", amb != null and amb.stream != null
		and bool(amb.stream.get("loop")), "stream %s" % (amb.stream if amb else null))


# ⭐ THE PASS-3 CONTENT (2026-09-20): the bigger child room, the seventeen searchable drawers,
# the shard that is not in the world yet, and the door that assembles itself.
func _pass3_checks() -> void:
	print("--- pass 3: the room, the drawers, the shard, the door ---")
	# ── the child room. Capture #2: "This room is too small - let's make it bigger, hard to
	# move now." 6 x 7 held the cradle, creature E and a DarkZone.
	var cr: Rect2 = _level.call("_room_rect", "ChildRoom")
	_ok("the child room is 8 x 7 (x -18..-10, z 29.5..36.5)",
		cr.size.is_equal_approx(Vector2(8, 7)) and cr.position.is_equal_approx(Vector2(-18, 29.5)),
		str(cr))
	var sanctum: Rect2 = _level.call("_room_rect", "Sanctum")
	_ok("…sharing the Sanctum's x span exactly, so the z 29.5 wall is ONE interval",
		absf(cr.position.x - sanctum.position.x) < 0.001
		and absf(cr.size.x - sanctum.size.x) < 0.001)
	var dark := _level.get_node_or_null("DarkChildRoom") as Area3D
	var dshape: BoxShape3D = null
	if dark:
		dshape = (dark.get_child(0) as CollisionShape3D).shape as BoxShape3D
	_ok("…and its DarkZone grew with it", dshape != null and dshape.size.is_equal_approx(Vector3(8, 3, 7)),
		str(dshape.size) if dshape else "missing")
	var e = _stalkers.get("E")
	var leash: Rect2 = e.get("leash") if e else Rect2()
	_ok("creature E's leash grew with the room (%.2f x %.2f m, %.1f m²)"
		% [leash.size.x, leash.size.y, leash.size.x * leash.size.y],
		leash.size.is_equal_approx(Vector2(6.9, 5.9)), str(leash))
	# The cradle and E keep their world positions — the room grew around them.
	var cradle := _level.get_node_or_null("Cradle_ChildRoom") as Node3D
	_ok("the cradle did not move with the walls",
		cradle != null and cradle.global_position.distance_to(Vector3(-15.75, 0, 34.3)) < 0.01,
		str(cradle.global_position) if cradle else "missing")

	# ── SEARCH: seventeen fronts, exactly one of them with anything in it.
	var drawers: Array = _level.call("drawers")
	var with_page := 0
	var open_now := 0
	for d in drawers:
		if bool(d.get("holds_page")):
			with_page += 1
		if bool(d.call("is_open")):
			open_now += 1
	_ok("the Morgue's drawer bank has seventeen openable fronts", drawers.size() == 17,
		"%d" % drawers.size())
	_ok("…exactly ONE of which holds anything", with_page == 1, "%d" % with_page)
	# ⭐ 2026-09-20 pass 4: ONE of the seventeen starts pulled. The 18:30 run pulled none of them
	# in 413 s — the bank showed a drawer already OUT on the floor but never a drawer that COULD
	# be pulled. ⚠️ And it must not be 4_1: a search whose one full container is open at the
	# start is not a search.
	_ok("…and exactly ONE of them starts pulled (the bank has a visible moving part)",
		open_now == 1, "%d already open" % open_now)
	var open_name := ""
	for d in drawers:
		if bool(d.call("is_open")):
			open_name = String(d.name)
	_ok("…and it is NOT the drawer that holds the page",
		open_name != "" and open_name != "Drawer4_1", "'%s'" % open_name)
	var page_drawer: Node = _level.call("page_drawer")
	var page := page_drawer.get_node_or_null("DrawerPage") if page_drawer else null
	_ok("the page inside it is a REAL note the journal will keep",
		page != null and _is_note_script(page.get_script()) and not bool(page.get("is_trap")),
		page.name if page else "missing")
	_ok("…and the page is a child of the drawer, so it slides out with the front",
		page != null and page_drawer.is_ancestor_of(page))

	# ── the shard is not in the world until the Archive's table re-poses itself.
	var shard = _level.call("shard")
	var table := _level.get_node_or_null("InvertedTable_Archive")
	_ok("the shard starts hidden in the Archive, not under the Morgue slab",
		shard != null and not bool(shard.call("is_revealed")) and not shard.visible
		and shard.global_position.distance_to(Vector3(-3.4, 0.42, 22.0)) < 0.2,
		str(shard.global_position) if shard else "missing")
	_ok("…and the table that hides it is an arm-on-sight rearranger",
		table != null and bool(table.get("arm_on_sight")) and not bool(table.get("spent")))
	# The hollow it came out of keeps a page instead.
	var slab_page := _level.get_node_or_null("SlabPage")
	_ok("the slab's hollow keeps a torn page where the shard used to be",
		slab_page != null and _is_note_script(slab_page.get_script())
		and slab_page.global_position.distance_to(Vector3(-13.1, 1.84, 45.5)) < 0.05,
		str(slab_page.global_position) if slab_page else "missing")

	# ── the exit door assembles. ⚠️ Measured against the transforms the BUILDER stored on each
	# slab, not against a second copy of the grid in this file.
	var exit_door := _level.get_node_or_null("ExitDoor")
	_ok("the ExitDoor carries void_exit_door.gd and the BackDoor does not",
		exit_door != null and String(exit_door.get_script().resource_path).ends_with("void_exit_door.gd")
		and String(_level.get_node("BackDoor").get_script().resource_path).ends_with("door.gd"))
	var slabs: Array = []
	for c in exit_door.get_children():
		if String(c.name).begins_with("LeafSlab_"):
			slabs.append(c)
	var off := 0
	var worst := 0.0
	for sl in slabs:
		var d: float = (sl as Node3D).position.distance_to(sl.get_meta("true_position"))
		worst = maxf(worst, d)
		if d > 0.004 or (sl as Node3D).rotation.length() > 0.004:
			off += 1
	_ok("CONTROL: before it opens, every slab is off its true sub-rect (%d of %d, worst %.3f m)"
		% [off, slabs.size(), worst], slabs.size() >= 7 and off == slabs.size())
	exit_door.call("snap_assembled")
	var bad := 0
	for sl in slabs:
		if (sl as Node3D).position.distance_to(sl.get_meta("true_position")) > 0.0005 \
				or (sl as Node3D).rotation.length() > 0.0005 \
				or (sl as Node3D).scale.distance_to(sl.get_meta("true_scale")) > 0.0005:
			bad += 1
	_ok("the assembly lands every slab on its own sub-rect with zero tilt", bad == 0,
		"%d of %d still off" % [bad, slabs.size()])
	# ⚠️ AND THE SEAMS CLOSE. Position alone leaves a 3.7 cm gap between every pair of slabs
	# and the blood-red plate behind them turns the finished door into a red grid — the picture
	# pass 2 rejected, rebuilt at the other end of the animation. Measured as the covered area:
	# the eight scaled slabs must tile at least 99 % of the 1.0 x 2.2 leaf.
	var covered := 0.0
	for sl in slabs:
		var stone := (sl as Node3D).get_node("SlabStone") as MeshInstance3D
		var sz: Vector3 = (stone.mesh as BoxMesh).size * (sl as Node3D).scale
		covered += sz.x * sz.y
	_ok("…and the seams close: the slabs tile %.1f %% of the leaf" % (covered / 2.2 * 100.0),
		covered >= 2.2 * 0.99, "%.3f m² of 2.200" % covered)
	_ok("…and the whole leaf is then one plane (all %d slabs at the same z)" % slabs.size(),
		_same_z(slabs))


func _same_z(slabs: Array) -> bool:
	var z := -INF
	for sl in slabs:
		var v: float = (sl as Node3D).position.z
		if z == -INF:
			z = v
		elif absf(v - z) > 0.0005:
			return false
	return slabs.size() > 0


# ── CreatureD watches from the far side and never steps while you are on the tiles ──
func _begin_watch_only() -> void:
	print("--- the bridge stalker ---")
	_level.get_node("AlignmentKeystone").call("restore_state", true, true)
	var d = _stalkers.get("D")
	# The west landing pad: inside the tile rect, with line of sight to D through the
	# Morgue doorway (the line crosses x = -9 at z ~46.1, inside the 1.8 m opening).
	_p.global_position = Vector3(-7.7, 0.1, 45.5)
	_p.force_update_transform()
	_p.call("ai_look_at", Vector3(0.0, 1.3, 45.5))   # looking east: D is not watched
	d.set("_awakened", true)
	d.set("_age", 10.0)
	_d_start = (d.get("_body") as Node3D).global_position
	_stage = 2
	_wait = 120


func _end_watch_only() -> void:
	var d = _stalkers.get("D")
	var moved: float = ((d.get("_body") as Node3D).global_position - _d_start).length()
	_ok("D is watch-only while the player stands on the tiles", bool(d.get("watch_only")))
	_ok("…and did not step in 2 s, awake, unwatched, with line of sight",
		moved < 0.05, "moved %.2f m" % moved)
	# ⭐ THE HEAD FINDS YOU WHILE YOU ARE NOT LOOKING (2026-09-20). D's body has not moved a
	# millimetre above, and in the same two seconds its detached head has swung off its rest
	# yaw toward the camera. This is the one channel the figure gained that costs no panic.
	var figure := _figure("D")
	if figure == null:
		_ok("CreatureD carries the Void figure", false)
	else:
		var head := figure.get_node_or_null("Head") as Node3D
		var rest: float = float(figure.get("_head_rest_yaw"))
		_ok("the detached head turns toward the player while unobserved",
			head != null and absf(angle_difference(rest, head.rotation.y)) > 0.1,
			"rest %.3f -> %.3f rad" % [rest, head.rotation.y if head else 0.0])
	# Now LOOK AT IT. Nothing, including the head, may move by a millimetre.
	_p.call("ai_look_at", (d.get("_body") as Node3D).global_position + Vector3(0, 1.6, 0))
	_stage = 21
	_wait = 40


# ⚠️ THE CONTROL HAS TO MOVE THE PLAYER, and this is the second version of it. The first
# just stood still and watched for 1.5 s: the head-tracking lerp had already converged, so
# breaking the fix (tracking in WATCHED frames too) still measured 0.000091 rad of drift
# against a 0.0001 threshold — a gate that passes whether or not the code is right.
# Teleporting 1.2 m along the tiles while still staring at D demands a 0.25 rad head swing,
# so the broken version now misses by ~500x. The player stays inside the tile rect and keeps
# line of sight through the Morgue doorway, so D remains watch-only and WATCHED throughout.
func _head_frozen_begin() -> void:
	var figure := _figure("D")
	var head := figure.get_node_or_null("Head") as Node3D if figure else null
	_head_y0 = head.rotation.y if head else 0.0
	var d = _stalkers.get("D")
	var aim: Vector3 = (d.get("_body") as Node3D).global_position + Vector3(0, 1.6, 0)
	_d_start = (d.get("_body") as Node3D).global_position
	_p.global_position = Vector3(-7.7, 0.1, 44.3)   # the south branch tile, still in the rect
	_p.force_update_transform()
	_p.call("ai_look_at", aim)
	_stage = 22
	_wait = 90


func _head_frozen_end() -> void:
	var figure := _figure("D")
	var head := figure.get_node_or_null("Head") as Node3D if figure else null
	var d = _stalkers.get("D")
	var moved: float = ((d.get("_body") as Node3D).global_position - _d_start).length()
	_ok("the control really changed the angle it would have to look at",
		absf(_p.global_position.z - 45.5) > 0.9, "player at z %.2f" % _p.global_position.z)
	_ok("CONTROL: while it is WATCHED the head does not move at all",
		head != null and absf(head.rotation.y - _head_y0) < 0.0005,
		"drift %.6f rad" % (absf(head.rotation.y - _head_y0) if head else -1.0))
	_ok("…and neither does the body", moved < 0.05, "moved %.3f m" % moved)
	# CONTROL: with the level's tile rect emptied the flag drops and it must advance.
	_level.set("_tile_rect", Rect2())
	d.set("protected_player_rect", Rect2())
	# ⚠️ 5.9 m AND 0.75 s, NOT 3.7 m and 1.5 s (2026-09-20 pass 2). The Void's stalkers now
	# advance at the user's 3.0 m/s instead of the shared 1.25, and the old control stood the
	# player 3.7 m from D for a second and a half: D covered 4.22 m, reached CONTACT_DIST and
	# KILLED the test's player, the scene reloaded, `_level` compared equal to null (a freed
	# node does — Issue 223) and the whole file restarted and then hung at this stage. The
	# control still has to prove D *steps*, so it keeps the same > 0.3 m assertion with room
	# to spare: 0.75 s at 3.0 m/s is 2.25 m, leaving ~3.6 m of air.
	_d_start = (d.get("_body") as Node3D).global_position
	_p.global_position = Vector3(-16.4, 0.1, 49.4)   # inside the Morgue, inside ENGAGE_DIST 8
	_p.call("ai_look_at", Vector3(-19.0, 1.3, 51.5)) # …and looking AWAY, so D is unwatched
	_p.force_update_transform()
	_stage = 3
	_wait = 45


func _watch_control() -> void:
	var d = _stalkers.get("D")
	var moved: float = ((d.get("_body") as Node3D).global_position - _d_start).length()
	_ok("CONTROL: off the tiles the flag drops", not bool(d.get("watch_only")))
	_ok("CONTROL: and D steps toward the player", moved > 0.3, "moved %.2f m in 0.75 s" % moved)
	_ok("CONTROL: …and the control did not stage its own death",
		current_scene == _level and not bool(root.get_node("Screamer").get("_is_triggering")))
	_level.set("_tile_rect", _tile_rect)
	# The creatures are out of the picture for the rest of the run.
	for s in _stalkers.values():
		if is_instance_valid(s):
			_level.remove_child(s)
			s.queue_free()
	_stage = 60


# ⭐ THE MASK AND ITS RESERVED CENTRE (2026-09-20 pass 2).
#
# The face hangs on a slab 8 cm in front of the skull and BIGGER than it, and the jumble of
# wrong objects is confined to the rim: nothing may cover the middle CLEAR_W of the width or
# CLEAR_H of the height, because the art is a human face and a face broken up before the eye
# can resolve it is not a face. All five variants are measured — the catalogue rotates and
# mirrors per variant, so checking one proves nothing about the other four.
#
# ⚠️ Measured as BOXES in the MASK'S OWN FRAME, not as centre points: a fragment's centre can
# sit outside the reserved rect while half of it lies across an eye.
const CLEAR_W := 0.60
const CLEAR_H := 0.70
const FACE_W := 0.28
const FACE_H := 0.42


func _mask_checks() -> void:
	var seen := 0
	var pieces := 0
	var bad: Array = []
	var smallest := INF
	for id in ["B", "C", "D", "E", "F"]:
		var figure := _figure(id)
		if figure == null:
			continue
		var head := figure.get_node_or_null("Head") as Node3D
		var mask := head.get_node_or_null("Mask") as Node3D if head else null
		if mask == null:
			bad.append("%s has no Mask under its head" % id)
			continue
		seen += 1
		var slab := mask.get_node_or_null("MaskSlab") as MeshInstance3D
		var art := mask.get_node_or_null("BrokenFace") as MeshInstance3D
		if slab == null or art == null:
			bad.append("%s mask is missing its slab or its art" % id)
			continue
		# The slab must be BIGGER than the skull it hangs in front of, and the art must be in
		# front of the slab, never coplanar with it.
		var brow := head.get_node_or_null("FaceBrow") as MeshInstance3D
		if brow:
			var bw: float = brow.get_aabb().size.x * brow.scale.x
			if slab.get_aabb().size.x * slab.scale.x <= bw:
				bad.append("%s mask is no wider than the brow" % id)
		if art.position.z - slab.position.z < 0.004:
			bad.append("%s art is coplanar with the slab (%.4f)" % [id, art.position.z - slab.position.z])
		var rx: float = CLEAR_W * 0.5 * FACE_W
		var ry: float = CLEAR_H * 0.5 * FACE_H
		for c in mask.get_children():
			var mi := c as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			if mi.name == "MaskSlab" or mi.name == "BrokenFace":
				continue
			pieces += 1
			var box := mi.get_aabb()
			var lo := Vector2(INF, INF)
			var hi := -lo
			for k in 8:
				var lp: Vector3 = mi.transform * box.get_endpoint(k)
				lo = Vector2(minf(lo.x, lp.x), minf(lo.y, lp.y))
				hi = Vector2(maxf(hi.x, lp.x), maxf(hi.y, lp.y))
			# Clear if the whole box is outside the reserved band in x, or outside it in y.
			var clear_x: bool = lo.x >= rx or hi.x <= -rx
			var clear_y: bool = lo.y >= ry or hi.y <= -ry
			var margin: float = maxf(maxf(lo.x - rx, -rx - hi.x), maxf(lo.y - ry, -ry - hi.y))
			smallest = minf(smallest, margin)
			if not (clear_x or clear_y):
				bad.append("%s/%s @(%.3f..%.3f, %.3f..%.3f) overlaps the reserved centre by %.3f m"
					% [id, mi.name, lo.x, hi.x, lo.y, hi.y, -margin])
	_ok("all five figures carry a Mask (%d)" % seen, seen == 5)
	_ok("the jumble was actually measured (%d pieces across 5 variants)" % pieces, pieces >= 25)
	_ok("nothing covers the face's middle %.0f%% x %.0f%% (closest piece clears by %.3f m): %s"
		% [CLEAR_W * 100.0, CLEAR_H * 100.0, smallest,
			"clear" if bad.is_empty() else ", ".join(bad.slice(0, 6))], bad.is_empty())


# ⭐ STEP THROUGH (2026-09-20 pass 3). Standing inside the doorway lying flat in Hall2 for
# STEP_DWELL seconds drops you out of the one lying flat in LoopIn, thirty metres back.
#
# ⚠️ BOTH HALVES OF THE CLOCK ARE MEASURED. "It moves a body" is half a test: a frame that
# fired the moment you touched it would pass it, and walking across a doorway on the floor must
# not cost you thirty metres. The short stance below is the control, and it reads the level's
# own dwell counter as well as the drop count so a silently-never-started clock cannot pass it.
# ⚠️ And the destination frame must move NOBODY — the hole is one-way, backwards only, which is
# what keeps it from bypassing anything.
const SHORT_DWELL_TICKS := 48      # 0.80 s at 60 Hz, against STEP_DWELL 1.2
const LONG_DWELL_TICKS := 60       # …and 1.80 s in total, comfortably past it


func _step_dwell_begin() -> void:
	print("--- the flat doorframe in Hall2 ---")
	_p.set("ai_active", true)
	_p.set("ai_move_dir", Vector2.ZERO)
	_p.global_position = Vector3(7.0, 0.1, 44.7)
	_p.call("ai_look_at", Vector3(7.0, 1.3, 48.0))
	_p.force_update_transform()
	_yaw0 = _p.rotation.y
	_stage = 61
	_wait = SHORT_DWELL_TICKS


func _step_dwell_short() -> void:
	var dwell: float = float(_level.get("_step_dwell"))
	_ok("CONTROL: %d ticks inside the frame does NOT drop the player" % SHORT_DWELL_TICKS,
		int(_level.call("step_drops")) == 0 and _p.global_position.z > 40.0,
		"drops %d, at %v" % [int(_level.call("step_drops")), _p.global_position])
	_ok("…and the level's own dwell clock really was running", dwell > 0.5 and dwell < 1.2,
		"%.2f s of the %.1f s it wants" % [dwell, 1.2])
	_stage = 62
	_wait = LONG_DWELL_TICKS


func _step_dwell_done() -> void:
	_ok("standing in it past 1.2 s drops the player out of the LoopIn frame",
		int(_level.call("step_drops")) == 1
		and _p.global_position.distance_to(Vector3(8.0, 0.1, 15.3)) < 0.6,
		"drops %d, at %v" % [int(_level.call("step_drops")), _p.global_position])
	_ok("…keeping the heading it arrived with",
		absf(angle_difference(_yaw0, _p.rotation.y)) < 0.01,
		"yaw %.3f -> %.3f" % [_yaw0, _p.rotation.y])
	_ok("…and it plays a positional frame_drop at the destination",
		_level.get_node_or_null("StepThroughDrop") != null
		and (_level.get_node("StepThroughDrop") as AudioStreamPlayer3D).stream != null)
	_stage = 63
	_wait = 4


func _step_loopin_begin() -> void:
	# CONTROL: the destination frame has no area at all — stand in it and nothing happens.
	_p.global_position = Vector3(8.0, 0.1, 15.3)
	_p.call("ai_look_at", Vector3(8.0, 1.3, 12.0))
	_p.force_update_transform()
	_stage = 64
	_wait = SHORT_DWELL_TICKS + LONG_DWELL_TICKS


func _step_loopin_done() -> void:
	_ok("CONTROL: the LoopIn frame moves nobody — the hole is one way",
		int(_level.call("step_drops")) == 1
		and _p.global_position.distance_to(Vector3(8.0, 0.1, 15.3)) < 0.6,
		"drops %d, at %v" % [int(_level.call("step_drops")), _p.global_position])
	_p.set("ai_active", false)
	_stage = 4


# The shipping interact layer, straight through the LoopNote's hanging point. Layer 2 is
# note.gd's INTERACTABLE_LAYER — the layer the player's own E-ray queries.
func _note_ray() -> Dictionary:
	var n := _level.get_node_or_null("LoopNote") as Node3D
	if n == null:
		return {}
	var at: Vector3 = n.global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0.8, 0, 0), at - Vector3(0.3, 0, 0), 2)
	return _level.get_world_3d().direct_space_state.intersect_ray(q)


# ── the loop seam ─────────────────────────────────────────────────────────────
func _plug_ray() -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(10.0, 1.0, 15.5), Vector3(12.0, 1.0, 15.5), 1)
	return _level.get_world_3d().direct_space_state.intersect_ray(q)


func _walk_the_loop(want: int, after: int) -> void:
	_p.global_position = Vector3(12.5, 0.1, 30.0)
	_p.force_update_transform()
	_p.set("ai_active", true)
	_p.call("ai_look_at", Vector3(12.5, 1.3, 44.0))
	_p.set("ai_move_dir", Vector2(0.0, -1.0))
	_yaw0 = _p.rotation.y
	_lap_ticks = 0
	_want_laps = want
	_after_lap = after
	_stage = 40
	_wait = 400


func _begin_lap() -> void:
	print("--- the loop corridor ---")
	_walk_the_loop(1, 5)


func _watch_lap(t: int) -> void:
	_lap_ticks += t
	if int(_level.call("loop_laps")) >= _want_laps:
		_wait = 0
		_stage = _after_lap
		return
	# ⚠️ A BUDGET, not an open wait. Without it a corridor that stops looping parks this file
	# in a stage with no match arm and it never returns.
	if _lap_ticks > LAP_BUDGET:
		_ok("lap %d happened inside its budget" % _want_laps, false,
			"%d ticks, laps still %d" % [_lap_ticks, int(_level.call("loop_laps"))])
		_wait = 0
		_stage = _after_lap


func _end_lap() -> void:
	var laps: int = int(_level.call("loop_laps"))
	_ok("walking +z through the seam counts a lap", laps >= 1, "%d after %d ticks" % [laps, _lap_ticks])
	_ok("…and puts the player one period back (z 15..18)",
		_p.global_position.z > 15.0 and _p.global_position.z < 18.5, "z %.2f" % _p.global_position.z)
	_ok("heading is preserved across the seam", absf(angle_difference(_yaw0, _p.rotation.y)) < 0.01,
		"yaw %.3f -> %.3f" % [_yaw0, _p.rotation.y])
	_ok("velocity is preserved across the seam (not zeroed)", _p.velocity.z > 1.0,
		"v.z %.2f" % _p.velocity.z)
	# ── rung one of the ladder: a lamp dies, the way back is still open, the note is illegible
	# ⚠️ The LAMP assertions live in _after_flicker(), one stage on. Since 2026-09-20 pass 2
	# every send-back pulses BOTH lamps for a second before the ladder settles them, so reading
	# a lamp's energy in this frame measures the flicker, not the ladder.
	_ok("lap 1 leaves the way back OPEN", _plug_ray().is_empty())
	var note := _level.get_node_or_null("LoopNote")
	_ok("lap 1 leaves the note illegible", note != null and int(note.get("laps")) == 1
		and String(note.call("prompt_text")).find("E ") < 0, "prompt '%s'" % note.call("prompt_text"))
	_ok("lap 1 leaves the note ABSENT (invisible, no collider)",
		not note.visible and _note_ray().is_empty())
	note.call("interact")
	_ok("CONTROL: E on the note at lap 1 opens nothing", not bool(root.get_node("NoteUI").get("is_open")))
	# ⭐ THE LAMPS STUTTER ON EVERY SEND-BACK. Sampled, not assumed: Light_Loop_19 is not one
	# of the lamps lap 1 kills, so it must come back up after the pulse train, and
	# Light_Loop_34 is, so it must end at 0. A flicker that just turned a lamp off once would
	# pass a "did the energy change" test and fail this one.
	_flicker_samples = []
	_flicker_ticks = 0
	_stage = 41


# Polled EVERY frame for ~1.6 s, like stage 40: a `_wait` countdown stops polling the moment
# it expires, and this stage has to watch a tween that runs in the IDLE step.
func _watch_flicker(t: int) -> void:
	_flicker_ticks += t
	var l19 := _level.get_node_or_null("Light_Loop_19") as OmniLight3D
	if l19:
		_flicker_samples.append(l19.light_energy)
	if _flicker_ticks > 110:
		_stage = 42
		_wait = 0


func _after_flicker() -> void:
	var distinct := {}
	var on := 0
	var off := 0
	for e in _flicker_samples:
		distinct[snappedf(float(e), 0.01)] = true
		if float(e) > 0.05:
			on += 1
		else:
			off += 1
	_ok("the flicker was actually sampled (%d frames)" % _flicker_samples.size(),
		_flicker_samples.size() >= 40)
	_ok("a send-back pulses the corridor lamps on AND off", on >= 3 and off >= 3,
		"%d lit frames, %d dark frames, %d distinct levels" % [on, off, distinct.size()])
	var l19 := _level.get_node_or_null("Light_Loop_19") as OmniLight3D
	var l34 := _level.get_node_or_null("Light_Loop_34") as OmniLight3D
	_ok("…and the near lamp is alive again once the flicker ends (lap 1 does not kill it)",
		l19 != null and l19.light_energy > 0.0, "energy %.2f" % (l19.light_energy if l19 else -1.0))
	_ok("lap 1 kills the far loop lamp, and the flicker does not resurrect it",
		l34 != null and l34.light_energy == 0.0, "energy %.2f" % (l34.light_energy if l34 else -1.0))
	_walk_the_loop(2, 51)


func _end_lap_two() -> void:
	var laps: int = int(_level.call("loop_laps"))
	_ok("a second pass counts a second lap", laps >= 2, "%d after %d ticks" % [laps, _lap_ticks])
	var hit: Dictionary = _plug_ray()
	_ok("lap 2 WALLS UP the doorway behind the player", not hit.is_empty(),
		"ray hit %s" % (hit.get("collider").name if hit.has("collider") else "nothing"))
	var note := _level.get_node_or_null("LoopNote")
	_ok("lap 2 makes the note legible", int(note.get("laps")) >= 2
		and String(note.call("prompt_text")).find("E ") >= 0, "prompt '%s'" % note.call("prompt_text"))
	# ⭐ AND PUTS IT IN THE WORLD. Both halves again: the mesh is shown and the E-ray finds it.
	_ok("lap 2 makes the page APPEAR (visible, with a collider the ray finds)",
		note.visible and bool(note.call("is_revealed")) and not _note_ray().is_empty(),
		"visible %s, ray %s" % [note.visible, _note_ray().get("collider", "nothing")])
	_ok("…and it carries its own paper_drop emitter", note.get_node_or_null("PaperDrop") != null)
	_stage = 6
	_reverse_setup()


func _reverse_setup() -> void:
	# Walk BACK through the seam: it must not fire (walking out of the loop is allowed).
	_p.global_position = Vector3(12.5, 0.1, 33.5)
	_p.force_update_transform()
	_p.call("ai_look_at", Vector3(12.5, 1.3, 15.0))
	_p.set("ai_move_dir", Vector2(0.0, -1.0))
	_wait = 150


func _reverse() -> void:
	_ok("walking -z through the seam does NOT teleport", int(_level.call("loop_laps")) == 2
		and _p.global_position.z < 31.5 and _p.global_position.z > 20.0,
		"laps %d, z %.2f" % [int(_level.call("loop_laps")), _p.global_position.z])
	# Break the loop THROUGH THE NOTE'S OWN interact(), not by calling the level's handler:
	# the whole 2026-09-20 change is that the note can refuse, and a direct call to
	# `_on_loop_note_read()` would prove nothing about whether it ever accepts.
	var note := _level.get_node_or_null("LoopNote")
	note.call("interact")
	var ui := root.get_node("NoteUI")
	_ok("at lap 2 E on the note really opens it", bool(ui.get("is_open")))
	ui.call("_close")
	_ok("…and that breaks the loop", bool(_level.call("loop_broken")))
	# ⚠️ The plug is queue_free()d, which lands at the END of the frame — the sweep for it
	# gone is in _broken(), a stage later. Reading it here measures the pre-free physics state.
	_p.global_position = Vector3(12.5, 0.1, 30.0)
	_p.force_update_transform()
	_p.call("ai_look_at", Vector3(12.5, 1.3, 44.0))
	_p.set("ai_move_dir", Vector2(0.0, -1.0))
	_stage = 7
	_wait = 250


func _broken() -> void:
	_ok("once the note is read the seam is inert", bool(_level.call("loop_broken"))
		and int(_level.call("loop_laps")) == 2 and _p.global_position.z > 33.5,
		"laps %d, z %.2f" % [int(_level.call("loop_laps")), _p.global_position.z])
	_ok("…and reading it took the wall plug back out", _plug_ray().is_empty())
	_p.set("ai_move_dir", Vector2.ZERO)
	_p.set("ai_active", false)
	_stage = 8


# ── snapshot ─────────────────────────────────────────────────────────────────
func _snapshot() -> void:
	print("--- save / restore ---")
	# ── rung three, driven from the lap count the way a snapshot restore drives it ──
	_level.set("_loop_laps", 3)
	_level.call("_apply_loop_ladder")
	var lamp19 := _level.get_node_or_null("Light_Loop_19") as OmniLight3D
	_ok("lap 3 kills the near loop lamp too", lamp19 != null and lamp19.light_energy == 0.0,
		"energy %.2f" % (lamp19.light_energy if lamp19 else -1.0))
	var stains := 0
	var raised := 0
	for c in _level.get_children():
		if String(c.name).begins_with("LoopStain_"):
			stains += 1
			if absf((c as Node3D).position.y - 1.75) < 0.001:
				raised += 1
	_ok("lap 3 lifts every wall stain to head height", stains >= 6 and raised == stains,
		"%d of %d stains at y 1.75" % [raised, stains])

	_level.call("_mark_note", "NoteWard")
	_level.set("_loop_laps", 2)
	_level.set("_shard_taken", true)
	_level.set("_cradle_done", true)
	# ⭐ pass 3: one anchor seated, one in hand, one drawer pulled — the state a player who
	# walks out of the back door is actually in.
	_level.call("take_anchor", "slat")
	(_level.call("drawers") as Array)[0].call("open_instantly")
	_level.get_node("AlignmentKeystone").call("place_anchor", 0, true)
	var d: Dictionary = _level.call("save_progress")
	_ok("save_progress carries notes_read / loop_broken / loop_laps",
		d.has("notes_read") and d.has("loop_broken") and d.has("loop_laps"), str(d))
	_ok("…and the 2026-09-20 keys: alignment_views / shard / cradle / fragments",
		d.has("alignment_views") and d.has("shard_taken") and d.has("cradle_done")
		and d.has("fragments_spent") and (d["alignment_views"] as Array).size() == 3, str(d))
	_ok("…and the pass-3 quest keys: anchors / carried / sockets / drawers",
		d.has("anchors_taken") and d.has("carried_anchor") and d.has("sockets_filled")
		and d.has("drawers_opened") and (d["sockets_filled"] as Array).size() == 3, str(d))
	root.get_node("GameState").call("save_level_progress", 8, d)
	_level.set("_notes_read", [])
	_level.set("_loop_broken", false)
	_level.set("_loop_laps", 0)
	_level.set("_shard_taken", false)
	_level.set("_cradle_done", false)
	_level.call("_restore_progress")
	_ok("…and _restore_progress puts them back",
		(_level.get("_notes_read") as Array).has("NoteWard") and bool(_level.call("loop_broken"))
		and int(_level.call("loop_laps")) == 2,
		"notes %s broken %s laps %d" % [_level.get("_notes_read"), _level.call("loop_broken"), _level.call("loop_laps")])
	_ok("…including the far-wing chain", bool(_level.get("_shard_taken")) and bool(_level.get("_cradle_done")))
	_ok("…and the quest: the anchor in hand, the seated socket and the pulled drawer",
		String(_level.call("carried_anchor")) == "slat"
		and bool(_level.get_node("AlignmentKeystone").call("socket_filled", 0))
		and bool((_level.call("drawers") as Array)[0].call("is_open"))
		and _level.get_node_or_null("Anchor_slat") == null,
		"carrying '%s'" % _level.call("carried_anchor"))
	root.get_node("GameState").call("save_level_progress", 8, {})
	_stage = 9


# ── the abyss ─────────────────────────────────────────────────────────────────
func _fall() -> void:
	print("--- the abyss ---")
	_p.global_position = Vector3(-3.0, -5.0, 45.5)
	_p.force_update_transform()
	_stage = 10
	_wait = 2


func _fall_result() -> bool:
	var scr := root.get_node("Screamer")
	_ok("a player below FALL_Y arms the screamer on the next frame", bool(scr.get("_is_triggering")))
	return _report()


func _report() -> bool:
	if _checks < 55:
		print("  FAIL only %d checks ran — did a stage abort?" % _checks)
		_fails += 1
	print("  %d checks, %d failed" % [_checks, _fails])
	print("--------------------------------------------------")
	print("RESULT: ", "PASS" if _fails == 0 else "FAIL (%d)" % _fails)
	print("--------------------------------------------------")
	quit(0 if _fails == 0 else 1)
	return true


# ⭐ THE PASS-4 CONTENT (2026-09-20): the sixteenth room sealed from frame 0, the cradle's giving
# scare, the drawing that becomes a plan, the flat frame that reacts to a dwell, and the loop's
# one swapped object per lap.
func _pass4_checks() -> void:
	print("--- pass 4: the secret door, the lunge, the tells ---")
	# ── the room exists and is SEALED at frame 0 ────────────────────────────────────────────
	var rect: Rect2 = _level.call("_room_rect", "FrameHall")
	_ok("FrameHall is 6 x 6 at x -27..-21, z 44..50",
		rect.size.is_equal_approx(Vector2(6, 6)) and rect.position.is_equal_approx(Vector2(-27, 44)),
		str(rect))
	# ⚠️ A RAY, not `get_node("SecretPlug") != null`. A wall's own `is_solid()` was true for the
	# whole life of a wall that was a hole in the world; object state is not geometry.
	_ok("the Morgue's west wall is SOLID at frame 0 — a ray from inside cannot leave",
		not _secret_ray().is_empty(),
		"ray hit %s" % _secret_ray().get("collider", "NOTHING"))
	_ok("…and what stops it is the plug, in the wall's own material",
		String(_secret_ray().get("collider", null).name if _secret_ray().has("collider") else "")
			== "SecretPlug")
	# ⚠️ AND THE FLOOR UNDER THE DOORWAY IS STILL THERE. The bridge is hidden until the door
	# opens so there is no 4 mm seam saying "door here"; hiding a slab that carried collision
	# would open a hole instead, which is the whole reason this is measured and not assumed.
	var down := _floor_ray(Vector3(-21.0, 1.0, 47.5))
	_ok("…and the floor under the hidden doorway is still solid",
		not down.is_empty(), "ray hit %s" % down.get("collider", "NOTHING"))
	var bridge = _level.call("secret_bridge")
	_ok("…with the doorway's 4 mm floor bridge hidden until it opens",
		bridge != null and not bool(bridge.get("visible")))
	_ok("the level reports the wall as closed", not bool(_level.call("secret_open")))
	# Issue 18: the room the frames are solved in by standing still charges for nothing.
	var dread := _level.get_node_or_null("DreadFarWing") as Area3D
	var dshape: BoxShape3D = (dread.get_child(0) as CollisionShape3D).shape as BoxShape3D if dread else null
	var dz := Rect2(dread.position.x - dshape.size.x * 0.5, dread.position.z - dshape.size.z * 0.5,
		dshape.size.x, dshape.size.z) if dshape else Rect2()
	_ok("Issue 18: DreadFarWing does not reach the new room (z %.1f..%.1f vs 44..50)"
		% [dz.position.y, dz.position.y + dz.size.y],
		not dz.has_point(Vector2(-24, 47)), str(dz))
	var lamp := _level.get_node_or_null("Light_FrameHall") as OmniLight3D
	_ok("the new room has its own lamp at the base the frames raise from",
		lamp != null and absf(lamp.light_energy - 0.25) < 0.001,
		"energy %.2f" % (lamp.light_energy if lamp else -1.0))

	# ── the drawing is still a drawing, and the plan texture is real ───────────────────────
	var art := _level.get_node_or_null("Drawing_ChildRoom/Art") as MeshInstance3D
	var before: Texture2D = null
	if art:
		var m := art.get_surface_override_material(0) as StandardMaterial3D
		before = m.albedo_texture if m else null
	_ok("the child's drawing starts as the drawing",
		before != null and String(before.resource_path).ends_with("void_child_drawing.png"),
		String(before.resource_path) if before else "no texture")
	# ⚠️ The plan is loaded HERE, in the guard, because `ResourceLoader.exists()` returns true for
	# a texture whose import FAILED (Issues 1 and 25) and the prop would then render blank while
	# every guard passed.
	var plan: Texture2D = load("res://assets/textures/level_4_void/void_child_drawing_plan.png")
	_ok("the plan texture really imported (not just exists())", plan != null
		and plan.get_width() > 8 and plan.get_height() > 8,
		"%d x %d" % [plan.get_width() if plan else -1, plan.get_height() if plan else -1])
	_ok("…and it is the same aspect as the drawing it replaces, on the same quad",
		plan != null and before != null
		and absf(float(plan.get_width()) / float(plan.get_height())
			- float(before.get_width()) / float(before.get_height())) < 0.001)

	# ── the Hall2 frame reacts to a dwell and the LoopIn twin does not ─────────────────────
	_ok("Hall2's flat frame has bars to lean and they start at rest",
		absf(float(_level.call("step_bar_lean"))) < 0.0001)
	var twin := _level.get_node_or_null("FlatDoorframe_LoopIn") as Node3D
	var twin_rest: Array = []
	for c in twin.get_children():
		if c is Node3D:
			twin_rest.append((c as Node3D).rotation)
	_level.call("_apply_step_bars", 1.0)
	_ok("…and at a full dwell they really lean toward the black",
		float(_level.call("step_bar_lean")) > 0.2, "%.3f rad" % float(_level.call("step_bar_lean")))
	var twin_moved := 0
	var i := 0
	for c in twin.get_children():
		if c is Node3D:
			if not (c as Node3D).rotation.is_equal_approx(twin_rest[i]):
				twin_moved += 1
			i += 1
	_ok("CONTROL: the LoopIn twin does NOT react — it is the destination, not the verb",
		twin_moved == 0, "%d of its bars moved" % twin_moved)
	_level.call("_apply_step_bars", 0.0)
	_ok("…and stepping out snaps them back", absf(float(_level.call("step_bar_lean"))) < 0.0001)

	# ── P.T.'s swap: one discrete object per lap, at the same spot ─────────────────────────
	var stain := _level.get_node_or_null("LoopStain_27") as Node3D
	_ok("lap 0: the z 27 dressing is the wall stain",
		stain != null and stain.visible and int(_level.call("loop_swap_stage")) == 0)
	_ok("…and neither swapped object is in the world yet (nothing extra to measure at load)",
		_level.get_node_or_null("LoopSwapLeg") == null
		and _level.get_node_or_null("LoopSwapPage") == null)
	var laps_before: int = int(_level.call("loop_laps"))
	_level.set("_loop_laps", 1)
	_level.call("_apply_loop_swap")
	var leg := _level.get_node_or_null("LoopSwapLeg") as Node3D
	_ok("lap 1 swaps the stain for a hung chair leg at the same spot",
		stain != null and not stain.visible and leg != null and leg.visible
		and absf(leg.position.z - 27.0) < 0.01, str(leg.position) if leg else "missing")
	_level.set("_loop_laps", 2)
	_level.call("_apply_loop_swap")
	var page := _level.get_node_or_null("LoopSwapPage") as Node3D
	_ok("lap 2 swaps the leg for a hand-sized page",
		leg != null and not leg.visible and page != null and page.visible
		and absf(page.position.z - 27.0) < 0.01, str(page.position) if page else "missing")
	_ok("…and ONE thing changed per lap, never a redress: the other five stains are untouched",
		_untouched_stains() == 5, "%d of 5 still in place" % _untouched_stains())
	_level.set("_loop_laps", laps_before)
	_level.call("_apply_loop_swap")

	# ── the Ward's touch now points at the OTHER frame, and only inside the Ward ───────────
	var ward := _level.get_node_or_null("WardFragment")
	var right := _level.get_node_or_null("FoldedFrame_Ward_R")
	_ok("the Ward's touch re-poses the RIGHT frame, 5.2 m from the one you touch",
		ward != null and right != null and ward.get("sculpture") == right)
	var wr: Rect2 = ward.get("room_rect") if ward else Rect2()
	_ok("…and the re-pose is gated to the Ward's own rect (the 57 s two-rooms-away bug)",
		wr.has_area() and wr.has_point(Vector2(-2.6, 14.5)) and not wr.has_point(Vector2(-14, 34)),
		str(wr))
	_ok("…with a stone_grind emitter at the frame that answers",
		_level.get_node_or_null("WardGrind") != null)


func _untouched_stains() -> int:
	var n := 0
	for z in [17, 22, 32, 37, 42]:
		var s := _level.get_node_or_null("LoopStain_%d" % z) as Node3D
		if s and s.visible and absf(s.position.z - float(z)) < 0.01:
			n += 1
	return n


# A horizontal sweep across the Morgue -> FrameHall doorway, on layer 1.
func _secret_ray() -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(-20.4, 1.0, 47.5), Vector3(-21.6, 1.0, 47.5), 1)
	return _level.get_world_3d().direct_space_state.intersect_ray(q)


func _floor_ray(at: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(at, at - Vector3(0, 2.0, 0), 1)
	return _level.get_world_3d().direct_space_state.intersect_ray(q)


# ⭐ THE CRADLE GIVES (2026-09-20 pass 4) — driven through the SHIPPING interact ray, never by
# emitting `completed`. A test that drove a win condition by emitting its signal passed for weeks
# on a level that was literally uncompletable; the whole question here is whether the real
# `can_interact()` / prompt / ray path reaches the cradle with a shard in hand.
var _e_rect := Rect2()
var _e_start := Vector3.ZERO
var _panic_before := 0.0
var _cradle_fig: Node = null


func _cradle_begin() -> void:
	print("--- the cradle gives: the lunge, the wall, the plan ---")
	var e = _stalkers.get("E")
	_e_rect = e.get("protected_player_rect")
	_ok("creature E starts protected by the tile hall's rect, like all five",
		_e_rect.has_area(), str(_e_rect))
	_p.set("ai_active", true)
	_p.set("ai_move_dir", Vector2.ZERO)
	_p.global_position = Vector3(-15.75, 0.1, 33.1)
	_p.force_update_transform()
	_level.set("_shard_taken", true)
	_level.call("_update_carried")
	var cradle := _level.get_node_or_null("Cradle_ChildRoom") as Node3D
	_p.call("ai_look_at", cradle.global_position + Vector3(0, 0.9, 0))
	_p.get_node("Camera3D").force_update_transform()
	var t: Node = _p.call("ai_interact_target")
	_ok("the ray finds the cradle body from a stance beside it",
		t == cradle or (t != null and cradle.is_ancestor_of(t)),
		"ray hit %s" % (t.name if t else "nothing"))
	_ok("…and with the shard in hand it invites E",
		String(cradle.call("prompt_text")).begins_with("E —"),
		"'%s'" % cradle.call("prompt_text"))
	_panic_before = float(_p.call("get_panic_ratio"))
	_p.call("ai_interact")
	_ok("E on the cradle completes it", bool(cradle.get("done")))
	# ⭐ ALL THREE ANSWERS AT ONCE — that is what makes it a payoff rather than a tween.
	# ⚠️ The physical sweep for the wall lives one stage on: the plug is `queue_free()`d, which
	# lands at the END of the frame, so a ray fired here measures the pre-free physics state.
	_ok("…and the level says so, with the floor bridge handed back",
		bool(_level.call("secret_open")) and _level.call("secret_plug") == null
		and bool(_level.call("secret_bridge").get("visible")))
	_ok("…and the floor under the now-open doorway is still solid",
		not _floor_ray(Vector3(-21.0, 1.0, 47.5)).is_empty())
	_ok("…and the Sanctum plate has NOT retracted — the hidden note does that now",
		_level.get_node_or_null("SanctumPlate") != null)
	_ok("…and the plate's line has become a pointer instead of a refusal",
		String(_level.get_node("SanctumPlate").call("prompt_text"))
			== "Something else was opened instead.")
	_stage = 71
	_wait = 30          # 0.5 s: inside the 0.6 s HoldBreath silence, before the rise


func _cradle_rising() -> void:
	_cradle_fig = _level.get_node_or_null("CradleFigure")
	var e = _stalkers.get("E")
	_ok("the Morgue's west wall is PHYSICALLY open (a ray, not a flag)",
		_secret_ray().is_empty(), "ray hit %s" % _secret_ray().get("collider", "nothing"))
	_ok("a sixth figure exists during the beat", _cradle_fig != null)
	_ok("…and it has not lunged yet (the 0.6 s silence comes first)",
		_cradle_fig != null and not bool(_cradle_fig.call("has_lunged")))
	# ⚠️ §8.11: creature E stands two metres from the cradle and the player is about to be
	# blinded by a figure filling the frame. It is suppressed with the tile hall's own mechanism.
	var rect: Rect2 = e.get("protected_player_rect")
	var child: Rect2 = _level.call("_room_rect", "ChildRoom")
	_ok("creature E is suppressed for the beat, by the child room's rect",
		rect.is_equal_approx(child), "%s vs %s" % [rect, child])
	_ok("…so its gaze pressure is zero while it is held off",
		absf(float(e.get_node("ScaryObject").scare_intensity)) < 0.001
		if e.get_node_or_null("ScaryObject") else true)
	_stage = 72
	_wait = 50          # past the 0.25 s rise and the 0.35 s lunge


func _cradle_lunged() -> void:
	var fig := _cradle_fig
	_ok("the figure lunged", fig == null or not is_instance_valid(fig)
		or bool(fig.call("has_lunged")))
	if fig != null and is_instance_valid(fig):
		# P3: a photograph, not a creature. No collider anywhere in it, no ScaryObject.
		var bad := ""
		var stack: Array = [fig]
		while not stack.is_empty():
			var c: Node = stack.pop_back()
			if c is CollisionObject3D or c is CollisionShape3D or c is ScaryObject:
				bad += c.name + " "
			for k in c.get_children():
				stack.append(k)
		_ok("…and it is a PHOTOGRAPH: no collider, no ScaryObject, no rule", bad == "", bad)
	_ok("the giving scare cost ZERO panic",
		absf(float(_p.call("get_panic_ratio")) - _panic_before) < 0.001,
		"%.4f -> %.4f" % [_panic_before, float(_p.call("get_panic_ratio"))])
	# ── CONTROL: it is the RECT that holds E off, not distance or luck ───────────────────
	# ⚠️ 4.5 m and 0.4 s, deliberately. Issue 228: at 3.0 m/s a wait beside a creature is a
	# DISTANCE, and check_void's own D control once staged its own death by standing 3.7 m away
	# for 1.5 s. 0.4 s buys E 1.2 m against CONTACT_DIST 1.25 — 3.3 m of air.
	var e = _stalkers.get("E")
	e.set("protected_player_rect", Rect2())
	e.set("_awakened", true)
	e.set("_age", 10.0)
	_p.global_position = Vector3(-16.5, 0.1, 32.2)
	_p.force_update_transform()
	_p.call("ai_look_at", Vector3(-19.5, 1.3, 30.5))   # looking AWAY, so E is unobserved
	_e_start = (e.get("_body") as Node3D).global_position
	_stage = 73
	_wait = 24


func _cradle_control() -> void:
	var e = _stalkers.get("E")
	var moved: float = ((e.get("_body") as Node3D).global_position - _e_start).length()
	_ok("CONTROL: with the rect cleared, E advances on the player", moved > 0.3,
		"moved %.2f m in 0.4 s" % moved)
	_ok("CONTROL: …and the control did not stage its own death",
		current_scene == _level and not bool(root.get_node("Screamer").get("_is_triggering")))
	# ⚠️ RESTORED to the tile rect, NEVER cleared. That rect is what holds all five stalkers off
	# while the player is out on the causeway; clearing it here would quietly delete E's half of a
	# rule that has nothing to do with this scare.
	e.set("protected_player_rect", _e_rect)
	# ⚠️ AND THE PLAYER LEAVES. E is now awake and unleashed toward them, and the next wait is
	# 1.5 s — at 3.0 m/s that is 4.5 m against a 4.5 m gap, i.e. this stage staged its own death
	# on the first build (Issue 228, the second time on this level: a wait beside a creature is a
	# distance, and a speed change re-prices every one). The tile pad is 14 m away and inside the
	# rect that holds all five off.
	_p.global_position = Vector3(-7.7, 0.1, 45.5)
	_p.force_update_transform()
	_stage = 74
	_wait = 90          # past the lunge + the 1.0 s of protection the level owes


func _cradle_after() -> void:
	var e = _stalkers.get("E")
	var rect: Rect2 = e.get("protected_player_rect")
	_ok("once the beat is over E's suppression is HANDED BACK to the tile hall's rect",
		rect.is_equal_approx(_e_rect), "%s vs %s" % [rect, _e_rect])
	_ok("the figure is gone — one shot, nothing left in the room",
		_level.get_node_or_null("CradleFigure") == null)
	_ok("a restore can never replay it", bool(_level.call("lunge_spent")))
	# Hand the level back to the rest of the file exactly as it found it.
	_level.set("_shard_taken", false)
	_level.set("_cradle_done", false)
	_p.set("ai_active", false)
	_stage = 1


# ⭐ THE TELL THAT SAYS WHERE. The drawing is two metres from where the cradle is completed and
# becomes a plan with one door marked — but only when you are not looking at it, which is this
# level's whole grammar. ⚠️ Run BEFORE the cradle: the cradle arms it, and by the time the lunge
# and E's control have finished teleporting the player around it would already have fired, so a
# "not yet" control there proves nothing.
func _drawing_begin() -> void:
	print("--- the drawing that becomes a plan ---")
	_level.call("_arm_drawing_swap")
	_p.set("ai_active", true)
	_p.set("ai_move_dir", Vector2.ZERO)
	_p.global_position = Vector3(-12.0, 0.1, 33.0)
	_p.force_update_transform()
	_p.call("ai_look_at", Vector3(-10.16, 1.5, 33.0))   # straight at it, on the east wall
	_stage = 68
	_wait = 30


func _drawing_control() -> void:
	_ok("CONTROL: armed and WATCHED, the drawing does not change",
		not bool(_level.call("drawing_swapped")))
	_p.call("ai_look_at", Vector3(-17.0, 1.3, 33.0))    # turn to the far wall
	_stage = 69
	_wait = 10


func _drawing_released() -> void:
	_ok("looking away turned the child's drawing into a PLAN",
		bool(_level.call("drawing_swapped")))
	var art := _level.get_node_or_null("Drawing_ChildRoom/Art") as MeshInstance3D
	var m := art.get_surface_override_material(0) as StandardMaterial3D if art else null
	var tex: Texture2D = m.albedo_texture if m else null
	_ok("…and the quad really carries the plan texture now",
		tex != null and String(tex.resource_path).ends_with("void_child_drawing_plan.png"),
		String(tex.resource_path) if tex else "none")
	_ok("…on the same quad, at the same size (the art guard's aspect does not move)",
		art != null and (art.mesh as QuadMesh).size.is_equal_approx(Vector2(0.7, 0.7)),
		str((art.mesh as QuadMesh).size) if art else "missing")
	_stage = 70
