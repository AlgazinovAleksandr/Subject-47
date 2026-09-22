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
var _bootstrapped := false
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
	# ⚠️ `not _bootstrapped`, NOT `_level == null`. In Godot 4 a variable holding a FREED node
	# compares equal to null (Issue 223), so the instant any stage staged its own death this
	# block re-entered, re-pointed `_level` at the reloaded scene and ran the WHOLE file a second
	# time — 336 checks, two structural passes, and the reload guard below never reached.
	# `walk_void.gd` was fixed for exactly this in pass 4; this file still had the hole.
	if not _bootstrapped:
		_bootstrapped = true
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
		_drawer_cycle_begin()
		return false
	# ⚠️ `_stage < 9` WAS NOT A "BEFORE THE END" TEST. The stage numbers are labels, not an
	# order — 21, 40, 60 and 75–84 all run before stage 9's fall — so this guard covered eight
	# stages out of thirty and a death anywhere else was silently survived (measured: a death at
	# stage 21 ran the whole file a second time). The only stages that legitimately swap the
	# scene are the fall and its result.
	if current_scene != null and current_scene != _level and _stage != 9 and _stage != 10:
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
	# ⭐ pass 7: the charge's turn is a ONE-FRAME claim and has to be polled, not waited for.
	if _stage == 77:
		_charge_watch(t)
		return false
	if _wait > 0:
		_wait -= t
		return false
	match _stage:
		# ⭐ pass 8: the drawer that opens, shuts and opens again, with the page riding in it.
		110: _drawer_opened()
		111: _drawer_closed()
		112: _drawer_reopened()
		# ⭐ pass 8: the cradle BURNS. 92/96/97 watch the fire alone, 98 catches the figure
		# mid-rise, 93 is the hold.
		96: _cradle_fire_ramped()
		97: _cradle_fire_peak()
		98: _cradle_rising()
		68: _drawing_control()
		69: _drawing_released()
		70: _cradle_begin()
		92: _cradle_dark()
		93: _cradle_shown()
		94: _cradle_restored()
		95: _cradle_handback()
		73: _cradle_control()
		74: _cradle_after()
		75: _charge_begin()
		76: _charge_north_control()
		# 77 is polled above (_charge_watch).
		78: _charge_after()
		79: _charge_once()
		80: _shard_begin()
		81: _shard_watched()
		82: _shard_freed()
		83: _gurney_moved()
		84: _twist_opened()
		85: _room_begin()
		86: _room_wrong_walk()
		87: _room_wrong_done()
		88: _room_still_begin()
		89: _room_still_done()
		90: _room_right_walk()
		91: _room_solved()
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
	_pass5_checks()
	_pass8_answer_order()
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

	# ── the shard lives in the Archive, not under the Morgue slab. ⚠️ Since pass 6 it is simply
	# TAKEABLE there from frame 0 — `_pass6_checks` owns that — and this row keeps pass 3's
	# claim: it is in the Archive's table and not in the Morgue.
	var shard = _level.call("shard")
	var table := _level.get_node_or_null("InvertedTable_Archive")
	_ok("the shard starts in the Archive's table, not under the Morgue slab",
		shard != null
		and Vector2(shard.global_position.x, shard.global_position.z).distance_to(
			Vector2(-3.4, 22.0)) < 0.6,
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
	_stage = 80


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
	# ⭐ pass 5: the corridor charge is a ONE-SHOT, and a snapshot has to carry that it HAPPENED.
	# The Ward frame's rule: a restore records a one-shot, it never replays it.
	_ok("…and the corridor charge's one-shot flag, already fired", d.has("corridor_charge_done")
		and bool(d["corridor_charge_done"]), str(d.get("corridor_charge_done", "missing")))
	root.get_node("GameState").call("save_level_progress", 8, d)
	_level.set("_notes_read", [])
	_level.set("_loop_broken", false)
	_level.set("_loop_laps", 0)
	_level.set("_shard_taken", false)
	_level.set("_cradle_done", false)
	# ⚠️ CLEARED FIRST, or "the charge is restored as spent" is true of a flag that simply never
	# moved — the shape of a control that cannot fail.
	_level.set("_charge_done", false)
	_level.call("_restore_progress")
	_ok("…and _restore_progress puts them back",
		(_level.get("_notes_read") as Array).has("NoteWard") and bool(_level.call("loop_broken"))
		and int(_level.call("loop_laps")) == 2,
		"notes %s broken %s laps %d" % [_level.get("_notes_read"), _level.call("loop_broken"), _level.call("loop_laps")])
	_ok("…including the far-wing chain", bool(_level.get("_shard_taken")) and bool(_level.get("_cradle_done")))
	_ok("…and the corridor charge is restored as SPENT, with no figure replayed",
		bool(_level.call("corridor_charge_done"))
		and _level.get_node_or_null("ChargeFigure") == null)
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
	# ⚠️ RAISED FROM 55 TO 150 (2026-09-20 pass 5), and it is not tidying. `call()` on a method
	# that no longer exists pushes a SCRIPT ERROR and ABORTS THE ENCLOSING FUNCTION — it does not
	# fail anything. Renaming `void_shard.gd:is_revealed()` silently deleted the last eight checks
	# of `_pass3_checks()` (the shard, the slab page, the whole exit-door assembly) and this file
	# printed "134 checks, 0 failed / RESULT: PASS". A floor 80 checks below the real count cannot
	# catch that. Keep this within ~10 of the true total whenever checks are added.
	# ⭐ 195 -> 252 (2026-09-22 pass 6), against a measured 260; -> 307 (pass 7, measured 315).
	if _checks < 307:
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
# ⭐ pass 7's cradle beat: the panic reading taken before the camera is even turned, the lamp
# energies the room was burning at, and whether the turn landed.
var _shadow_panic := 0.0
var _shadow_lights0: Array = []
var _shadow_yaw_ok := false


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
	# ⭐ pass 7: SAMPLED BEFORE THE PRESS, because the beat starts synchronously inside
	# `interact()` — the lights are already at 0 and the zone already inert by the line after.
	_shadow_yaw_ok = false
	_shadow_panic = float(_p.call("get_panic_ratio"))
	_shadow_lights0 = []
	for l in (_level.call("child_room_lights") as Array):
		_shadow_lights0.append(float((l as Light3D).light_energy))
	_ok("the child room has lights to put out, and they are burning (%d)"
		% _shadow_lights0.size(), _shadow_lights0.size() >= 1
		and float(_shadow_lights0[0]) > 0.0, str(_shadow_lights0))
	_ok("…and the torch is ON, so the blackout has something to take",
		bool(_p.call("is_flashlight_on")))
	_ok("…and both DarkZones are live before the beat (they are what must not charge)",
		bool(_level.call("child_dark_zone_live")) and int(_p.get("_dark_zones")) >= 1
		and int(_level.call("dark_zones_live")) == 2,
		"%d live zones, player counts %d" % [int(_level.call("dark_zones_live")),
			int(_p.get("_dark_zones"))])
	_p.call("ai_interact")
	_ok("E on the cradle completes it", bool(cradle.get("done")))
	# ⚠️ AND NOW LOOK AWAY, which is what makes the camera assert mean anything. The stance this
	# stage presses E from is already pointed at the cradle, so "the camera ends up on the
	# cradle" would be true of a beat that never touched it. `ai_look_at` writes `rotation.y`
	# directly; `turn_to_face`'s tween owns the same property and an absolute destination
	# computed at call time, so if the beat is doing the work the view comes back by itself.
	_p.call("ai_look_at", Vector3(-11.0, 1.3, 30.0))
	_p.get_node("Camera3D").force_update_transform()
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
	_stage = 92
	_wait = 30          # 0.5 s: the turn has landed, the room is dark, nothing has appeared


# ⭐ THE CRADLE BEAT (2026-09-22 pass 7) — a shadow in the dark, not a lunge.
#
# ⚠️ THREE SAMPLES, NOT ONE, and the middle one is the whole point. The claim is not "a figure
# appeared" — it is that for a full second there is NOTHING, with the room's lights at zero and
# the torch out, and then one dim light inside the cradle is the only thing in the world. A test
# that only looked at the end state would pass against a beat with no darkness in it at all.
func _cradle_dark() -> void:
	# The camera. A scare must own it (Issue 255) — and unlike the charge, this one has a target
	# that never moves, so the bearing is exact.
	var box: AABB = _level.call("cradle_bbox")
	var at: Vector3 = box.position + box.size * 0.5 + Vector3(0, 0.9, 0)
	_shadow_yaw_ok = _yaw_error_to(at) < 5.0
	_ok("the beat turns the camera onto the cradle (within 5 deg)", _shadow_yaw_ok,
		"%.1f deg off" % _yaw_error_to(at))
	# The dark second.
	var lit := 0
	for l in (_level.call("child_room_lights") as Array):
		if float((l as Light3D).light_energy) > 0.0001:
			lit += 1
	_ok("every light in the child room is at 0 during the dark second (%d checked)"
		% (_level.call("child_room_lights") as Array).size(),
		lit == 0 and (_level.call("child_room_lights") as Array).size() >= 1,
		"%d still burning" % lit)
	_ok("…and the torch is out with it", not bool(_p.call("is_flashlight_on")))
	_ok("…and the level says the room is dark", bool(_level.call("shadow_dark")))
	# ⭐ pass 8. There is no "second of nothing" any more: the fire is lit in the same breath as
	# the blackout, and at 0.5 s it is a small fire with its light still ramping. What must NOT
	# have happened yet is the figure — it rises at t = 3.0 s and not before.
	var fire0: Node = _level.get_node_or_null("CradleFire")
	_cradle_fire_node = fire0
	_ok("the cradle is BURNING half a second in — the beat's only light source",
		fire0 != null and float(fire0.call("light_energy")) > 0.05
		and bool(_level.call("cradle_light_on")),
		"fire %s, energy %.3f" % [fire0 != null,
			float(fire0.call("light_energy")) if fire0 else -1.0])
	_ok("…with its light still RAMPING, not already at the top",
		fire0 != null and float(fire0.call("light_energy")) < 0.75,
		"%.3f" % (float(fire0.call("light_energy")) if fire0 else -1.0))
	_ok("…and NOTHING has risen out of it yet: no figure in the room",
		_level.get_node_or_null("CradleFigure") == null)
	# ⚠️ ISSUE 18. `DarkChildRoom` is a DarkZone over this room and `player.gd` charges
	# DARK_PANIC_RATE 3/s while the torch is off inside one. Measured with a probe on this very
	# stance: with the zone live, 4 s of torch-off moved panic 0.03 -> 8.37; with the zone held
	# off, 8.3667 -> 8.3667, exactly. So the zone being inert is the mechanism, and it is asserted
	# as a fact about the WORLD (the area is not monitoring, the player counts no dark zone) and
	# not merely as "panic did not move".
	# ⚠️ ALL of them, not just this room's: the beat does not freeze input and DarkMorgue is two
	# seconds' walk away, so holding one zone would only move the charge.
	_ok("EVERY DarkZone is held OFF for the beat — Issue 18, never tax the posture",
		not bool(_level.call("child_dark_zone_live")) and int(_p.get("_dark_zones")) == 0
		and int(_level.call("dark_zones_live")) == 0,
		"child %s, %d live zones, player counts %d" % [_level.call("child_dark_zone_live"),
			int(_level.call("dark_zones_live")), int(_p.get("_dark_zones"))])
	_ok("…so the dark second costs ZERO panic",
		absf(float(_p.call("get_panic_ratio")) - _shadow_panic) < 0.001,
		"%.4f -> %.4f" % [_shadow_panic, float(_p.call("get_panic_ratio"))])
	_stage = 96
	_wait = 60          # t = 1.5 s: the ramp is over and the fire is still alone


func _cradle_shown() -> void:
	_cradle_fig = _level.get_node_or_null("CradleFigure")
	var lamp: OmniLight3D = _level.call("cradle_light")
	var box: AABB = _level.call("cradle_bbox")
	var fire: Node = _level.get_node_or_null("CradleFire")
	_ok("the Morgue's west wall is PHYSICALLY open (a ray, not a flag)",
		_secret_ray().is_empty(), "ray hit %s" % _secret_ray().get("collider", "nothing"))
	_ok("the fire is still burning while the face stands in it", fire != null)
	_ok("an ORANGE light is burning INSIDE the cradle, and it is the FIRE'S",
		bool(_level.call("cradle_light_on")) and lamp != null
		and box.grow(0.05).has_point(lamp.global_position)
		and fire != null and fire.is_ancestor_of(lamp)
		and lamp.light_color.r > lamp.light_color.b,
		"%s at %v vs cradle %v+%v" % [lamp != null, lamp.global_position if lamp else Vector3.ZERO,
			box.position, box.size])
	# ⚠️ ENERGY, RANGE **AND DECAY** ASSERTED. This is the one light in the frame and the mask it
	# lights is a ~0.95-albedo surface half a metre away: at Godot's DEFAULT `omni_attenuation`
	# of 1.0 the irradiance is `energy * (1 - (d/range)^4)^2 / d`, which at 0.9 energy and 0.62 m
	# is 1.45 — a flat white face with no detail in it (Issue 21 / SCARY.md §8.8). At decay 0.0
	# the `/d` term is gone and the irradiance can never exceed the energy itself, at any
	# distance. The decay is therefore part of the no-clamp claim and not a style choice.
	_ok("…at <= 1.05 energy over a 3.0 m range with NO 1/d core (decay 0), and nothing emissive on the figure",
		lamp != null and lamp.light_energy <= 1.051 and absf(lamp.omni_range - 3.0) < 0.01
		and absf(lamp.omni_attenuation) < 0.001
		and _no_emission(_cradle_fig) if _cradle_fig else false,
		"%.2f energy / %.1f m / decay %.2f" % [lamp.light_energy if lamp else -1.0,
			lamp.omni_range if lamp else -1.0, lamp.omni_attenuation if lamp else -1.0])
	# …and the arithmetic that claim rests on, computed here from the live geometry rather than
	# quoted: the brightest the mask can be lit is the light's own energy.
	if lamp != null:
		var mask_n := _find_named(_cradle_fig, "Mask") as Node3D if _cradle_fig else null
		var dm: float = lamp.global_position.distance_to(mask_n.global_position) if mask_n else -1.0
		var irr: float = lamp.light_energy * pow(1.0 - pow(dm / lamp.omni_range, 4.0), 2.0) \
			if dm > 0.0 else -1.0
		_ok("…so the irradiance landing on the mask is UNDER the 1.0 that clamps to white",
			irr > 0.3 and irr < 1.0, "mask %.3f m from the flames, irradiance %.3f" % [dm, irr])
	_ok("…and the room is still black around it: every lamp at 0, the torch out",
		not bool(_p.call("is_flashlight_on")) and _lit_child_lights() == 0,
		"%d lamps lit" % _lit_child_lights())
	_ok("a figure is in the cradle", _cradle_fig != null)
	if _cradle_fig != null:
		# ⚠️ MEASURED AGAINST THE CRADLE'S OWN MESH BOUNDING BOX, computed here rather than taken
		# from the number the level passed in. "Crouched in the cradle" is a claim about geometry.
		var fig := _cradle_fig as Node3D
		var flat := Vector2(fig.global_position.x - (box.position.x + box.size.x * 0.5),
			fig.global_position.z - (box.position.z + box.size.z * 0.5)).length()
		_ok("…standing in the cradle's own footprint, sunk below its rim",
			flat < 0.25 and fig.global_position.y < box.position.y,
			"%.2f m off centre, origin y %.2f vs cradle floor %.2f"
			% [flat, fig.global_position.y, box.position.y])
		# …and its MASK is at the rim: that is the image, and it is what "crouched" means here.
		var mask := _find_named(fig, "Mask") as Node3D
		var rim: float = box.position.y + box.size.y
		_ok("…with its mask at the cradle's rim, not towering over it",
			mask != null and absf(mask.global_position.y - rim) < 0.25,
			"mask y %.3f vs rim %.3f" % [mask.global_position.y if mask else -99.0, rim])
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
	# The sound. ⚠️ -2.0 dB SINCE PASS 8, AND IT IS THE USER'S CALL: capture #3 asked for
	# *"the jumpscare itself should be louder"*. `apparition_snarl.ogg` peaks at 0.0 dBFS, so
	# -2.0 dB is 2 dB under the file's own ceiling — there is no louder setting that is not
	# clipping, and this asserts the exact number so a later pass cannot drift it quietly.
	var cs := _level.get_node_or_null("CradleSnarl") as AudioStreamPlayer3D
	# ⭐ 2026-09-23: the user's own `void_fire_jumpscare.mp3` (peak 0.0 dBFS) — -2.0 dB is still the ceiling.
	_ok("…and the user's `void_fire_jumpscare` is playing on Master at -2.0 dB (NOT the corridor's sting)",
		cs != null and cs.stream != null
		and String(cs.stream.resource_path).find("void_fire_jumpscare") >= 0
		and absf(cs.volume_db + 2.0) < 0.01 and cs.bus == "Master" and cs.playing,
		"%s %.1f dB bus %s playing %s" % [cs.stream.resource_path if cs and cs.stream else "-",
			cs.volume_db if cs else 0.0, cs.bus if cs else "-", cs.playing if cs else false])
	# ⚠️ §8.11: creature E stands two metres from the cradle and the player has just been blinded.
	var e = _stalkers.get("E")
	var rect: Rect2 = e.get("protected_player_rect")
	var child: Rect2 = _level.call("_room_rect", "ChildRoom")
	_ok("creature E is suppressed for the beat, by the child room's rect",
		rect.is_equal_approx(child), "%s vs %s" % [rect, child])
	_ok("…so its gaze pressure is zero while it is held off",
		absf(float(e.get_node("ScaryObject").scare_intensity)) < 0.001
		if e.get_node_or_null("ScaryObject") else true)
	_ok("the lit half of the beat costs ZERO panic too",
		absf(float(_p.call("get_panic_ratio")) - _shadow_panic) < 0.001,
		"%.4f -> %.4f" % [_shadow_panic, float(_p.call("get_panic_ratio"))])
	_stage = 94
	_wait = 150         # past the 2.0 s hold, the 0.3 s fade and the 0.4 s tail


func _cradle_restored() -> void:
	var lights: Array = _level.call("child_room_lights")
	var back := 0
	for i in range(lights.size()):
		if i < _shadow_lights0.size() \
				and absf(float((lights[i] as Light3D).light_energy)
					- float(_shadow_lights0[i])) < 0.0001:
			back += 1
	_ok("every child-room lamp is back at the energy it was burning at (%d of %d)"
		% [back, lights.size()], back == lights.size() and lights.size() >= 1)
	_ok("…and the torch is back on", bool(_p.call("is_flashlight_on")))
	_ok("…and the light in the cradle is out", not bool(_level.call("cradle_light_on")))
	_ok("…and the figure is gone — one shot, nothing left in the room",
		_level.get_node_or_null("CradleFigure") == null)
	# ⭐ pass 8. The fire is an EVENT: it exists for the beat and then it is not in the world at
	# all. A flame node left behind would be the level's only emissive prop, burning forever in
	# a room the player walks back through.
	_ok("…and so is the fire — no CradleFire node, and nothing still holding its light",
		_level.get_node_or_null("CradleFire") == null
		and _level.call("cradle_light") == null)
	_ok("…and the loop it was playing stopped with it",
		_level.get_node_or_null("CradleFire/CradleFireLoop") == null)
	_ok("…and a restore can never replay it", bool(_level.call("lunge_spent")))
	# ⚠️ THE ZONE COMES BACK, and it must: holding it off for good would silently delete the
	# child room's darkness rule for the rest of the level. Godot re-emits `body_entered` when
	# `monitoring` is written back to true, so the player's own counter is the proof, not the flag.
	_ok("BOTH DarkZones are live again and the player is registered in this one",
		bool(_level.call("child_dark_zone_live")) and int(_p.get("_dark_zones")) >= 1
		and int(_level.call("dark_zones_live")) == 2,
		"child %s, %d live zones, player counts %d" % [_level.call("child_dark_zone_live"),
			int(_level.call("dark_zones_live")), int(_p.get("_dark_zones"))])
	_ok("THE WHOLE BEAT — 0.3 s turn, 3.0 s of fire, a 0.5 s rise, a 2.0 s hold, a 0.3 s fade and a 0.4 s tail — cost ZERO panic",
		absf(float(_p.call("get_panic_ratio")) - _shadow_panic) < 0.001,
		"%.4f -> %.4f" % [_shadow_panic, float(_p.call("get_panic_ratio"))])
	# ⚠️ E is protected for the beat + 1 s; at this sample that second is still running, which is
	# what the next stage waits out. Asserting the handback here would be asserting the clock.
	_stage = 95
	_wait = 80


func _cradle_handback() -> void:
	var e = _stalkers.get("E")
	var rect: Rect2 = e.get("protected_player_rect")
	_ok("once the beat is over E's suppression is HANDED BACK to the tile hall's rect",
		rect.is_equal_approx(_e_rect), "%s vs %s" % [rect, _e_rect])
	# ── CONTROL: it is the RECT that holds E off, not distance or luck ───────────────────
	# ⚠️ 4.5 m and 0.4 s, deliberately. Issue 228: at 3.0 m/s a wait beside a creature is a
	# DISTANCE, and check_void's own D control once staged its own death by standing 3.7 m away
	# for 1.5 s. 0.4 s buys E 1.2 m against CONTACT_DIST 1.25 — 3.3 m of air.
	e.set("protected_player_rect", Rect2())
	e.set("_awakened", true)
	e.set("_age", 10.0)
	_p.global_position = Vector3(-16.5, 0.1, 32.2)
	_p.force_update_transform()
	_p.call("ai_look_at", Vector3(-19.5, 1.3, 30.5))   # looking AWAY, so E is unobserved
	_e_start = (e.get("_body") as Node3D).global_position
	_stage = 73
	_wait = 24


# The bearing error, in degrees, between where the camera is actually pointed and a world point.
func _yaw_error_to(at: Vector3) -> float:
	var cam := _p.get_node("Camera3D") as Camera3D
	var fwd := -cam.global_transform.basis.z
	var to: Vector3 = at - cam.global_position
	fwd.y = 0.0
	to.y = 0.0
	if fwd.length() < 0.001 or to.length() < 0.001:
		return 999.0
	return rad_to_deg(absf(fwd.normalized().angle_to(to.normalized())))


func _lit_child_lights() -> int:
	var n := 0
	for l in (_level.call("child_room_lights") as Array):
		if float((l as Light3D).light_energy) > 0.0001:
			n += 1
	return n


func _find_named(n: Node, nm: String) -> Node:
	if String(n.name) == nm:
		return n
	for c in n.get_children():
		var f := _find_named(c, nm)
		if f != null:
			return f
	return null


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
	_ok("…and after the control the rect is E's again, not the empty one",
		(e.get("protected_player_rect") as Rect2).is_equal_approx(_e_rect),
		"%s vs %s" % [e.get("protected_player_rect"), _e_rect])
	# Hand the level back to the rest of the file exactly as it found it.
	_level.set("_shard_taken", false)
	_level.set("_cradle_done", false)
	_stage = 75


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


# ⭐ THE PASS-5 CONTENT (2026-09-20): the twist note's own refusal, the receipt on the Ward's
# gurney, the shard that is visible and wedged, the corridor charge, and the cradle figure
# rising from the cradle's geometry instead of from the floor in front of it.
func _pass5_checks() -> void:
	print("--- pass 5: the gate, the receipt, the charge ---")
	# ── the twist note is a SUBCLASS that refuses while the stone stands ───────────────────
	var twist: Node = _level.call("twist_note")
	_ok("TwistNote carries void_twist_note.gd (a note.gd subclass)",
		twist != null and _is_note_script(twist.get_script())
		and String(twist.get_script().resource_path).ends_with("void_twist_note.gd"),
		String(twist.get_script().resource_path) if twist else "missing")
	_ok("…and it is wired to the level that owns the plate",
		twist != null and twist.get("level") == _level)
	_ok("the level reports the stone as standing at frame 0", bool(_level.call("plate_stands")))
	_ok("…so the page refuses by NAME, without offering E",
		twist != null and String(twist.call("prompt_text")) == "The stone covers it.",
		"'%s'" % (twist.call("prompt_text") if twist else ""))
	# ⚠️ A DIRECT call, deliberately: the ray-level controls are in `_twist_gate()`, but this one
	# asks whether the refusal is in the NOTE at all. Issue 30's inverse — a gate that only works
	# because the ray happens not to arrive is not a gate.
	var gs := root.get_node("GameState")
	twist.call("interact")
	_ok("CONTROL: E straight on the note opens nothing while the stone stands",
		not bool(root.get_node("NoteUI").get("is_open")) and not bool(gs.get("twist_read")))

	# ── and the plate itself grew, without landing on the wall's own plane ─────────────────
	var plate := _level.get_node_or_null("SanctumPlate") as Node3D
	var face := plate.get_node_or_null("PlateFace") as MeshInstance3D if plate else null
	var box: BoxMesh = face.mesh as BoxMesh if face else null
	_ok("the plate is 0.90 x 1.10 (it was 0.60 x 0.80)",
		box != null and absf(box.size.x - 0.90) < 0.001 and absf(box.size.y - 1.10) < 0.001,
		str(box.size) if box else "missing")
	# The Sanctum's west wall face is at x -17.90 (nominal -18 + T/2); the note's paper quad is
	# at -17.84. Two visible surfaces in one plane is this project's most common bug class.
	var back: float = plate.global_position.x - 0.03 if plate else 0.0
	_ok("…and its back face clears the wall face by %.3f m (>= 0.02 required)" % (back + 17.90),
		plate != null and back + 17.90 >= 0.02, "back at x %.3f" % back)
	_ok("…and it stands clear of the note's paper quad too (%.3f m)" % (back + 17.835),
		plate != null and back + 17.835 >= 0.02)

	# ── the Ward's touch prop is a gurney, and it is the thing that carries the touch ──────
	var ward := _level.get_node_or_null("WardFragment")
	var gurney := ward.get_node_or_null("HangingGurney") as Node3D if ward else null
	var hang := gurney.get_node_or_null("GurneyHang") as Node3D if gurney else null
	_ok("the Ward's touch prop is a hanging gurney, not an abstract shard",
		gurney != null and hang != null and ward.get_node_or_null("TouchFragment") == null)
	var parts := {"GurneyRail": 0, "GurneyLeg": 0, "GurneyWheel": 0, "GurneyMattress": 0,
		"GurneyStrap": 0, "GurneyHeadBoard": 0}
	var boxes := 0
	if hang:
		for c in hang.get_children():
			if not (c is MeshInstance3D):
				continue
			boxes += 1
			for k in parts.keys():
				if String(c.name).begins_with(k):
					parts[k] = int(parts[k]) + 1
	# Silhouette carries a prop (Issue 35): two rails, four legs, four casters, a mattress
	# standing proud of the frame, a head board and two straps — never one box.
	_ok("…built from parts: 2 rails, 4 legs, 4 wheels, a mattress, a board",
		int(parts["GurneyRail"]) == 2 and int(parts["GurneyLeg"]) == 4
		and int(parts["GurneyWheel"]) == 4 and int(parts["GurneyMattress"]) == 1
		and int(parts["GurneyHeadBoard"]) == 1, str(parts))
	_ok("…all of it BOX geometry (no art quad, nothing borrowed)", boxes >= 12, "%d meshes" % boxes)
	# It hangs: nose-down, from head height to knee height, clear of the floor and the ceiling.
	var aabb := _world_aabb(gurney)
	_ok("…hung nose-down between y %.2f and y %.2f (clear of floor and ceiling)"
		% [aabb.position.y, aabb.position.y + aabb.size.y],
		aabb.position.y > 0.05 and aabb.position.y + aabb.size.y < ROOM_CEIL - 0.1
		and aabb.size.y > 1.4, str(aabb))
	_ok("…and NOTHING in it is emissive (this level has no glow to spend)",
		_no_emission(gurney))
	_ok("…and it has no ScaryObject ancestor: zero panic, like everything else in the Ward",
		_no_scary(ward))
	_ok("the touch prompt names the object now",
		ward != null and String(ward.call("prompt_text")) == "E — Touch the hanging gurney.",
		"'%s'" % (ward.call("prompt_text") if ward else ""))
	_pass6_checks()

	# ── ⭐ pass 6: the shard is in the world from frame 0 and simply TAKEABLE ──────────────
	var shard = _level.call("shard")
	_ok("the shard EXISTS and is VISIBLE at frame 0", shard != null and shard.visible)
	_ok("…lying in the inverted table's basin, above the table's own collider (Issue 230)",
		shard != null and shard.global_position.y > 0.4
		and shard.global_position.distance_to(Vector3(-3.4, 0.42, 22.0)) < 0.02,
		str(shard.global_position) if shard else "missing")
	_ok("…and it OFFERS E from frame 0 — pass 5's wedge is retired (capture #4)",
		shard != null and bool(shard.call("is_freed"))
		and String(shard.call("prompt_text")) == "E — Take the shard.",
		"'%s'" % (shard.call("prompt_text") if shard else ""))
	# ⚠️ `shard_clatter.wav` was DELETED with the wedge: it existed only to announce the
	# release. A stale `load_audio("shard_clatter")` would return null forever and say nothing,
	# so the guard asserts the file is gone rather than that it loads.
	_ok("…and `shard_clatter` is gone from the project with the beat that used it",
		gs.call("load_audio", "shard_clatter") == null)

	# ── the corridor charge: the trigger volume, and nothing armed yet ────────────────────
	# ⭐ z 26, not 42 (pass 6, capture #3): 60 % of the way back down a corridor that runs
	# z 44 -> 14.
	var area := _level.call("charge_area") as Area3D
	var ashape: BoxShape3D = (area.get_child(0) as CollisionShape3D).shape as BoxShape3D if area else null
	_ok("the corridor charge's trigger covers x 11..14, z 25..27 (60 % of the walk back)",
		area != null and ashape != null
		and absf(area.position.x - 12.5) < 0.01 and absf(area.position.z - 26.0) < 0.01
		and absf(ashape.size.x - 3.0) < 0.01 and absf(ashape.size.z - 2.0) < 0.01,
		"%s %s" % [area.position if area else "-", ashape.size if ashape else "-"])
	# ⚠️ `Object.get()` does not see a script CONSTANT — the constant map does.
	var lconsts: Dictionary = _level.get_script().get_script_constant_map()
	var fig_at: Vector3 = lconsts.get("CHARGE_FIGURE_AT", Vector3.ZERO)
	_ok("…and the figure stands 9.5 m further south, under the dead lamp",
		absf(fig_at.z - 16.5) < 0.01 and area != null
		and absf(area.position.z - fig_at.z - 9.5) < 0.01, "figure z %.1f" % fig_at.z)
	# The rush is the CHARGE's clock, and the cradle's is a different one.
	# ⚠️ FIXED 2026-09-23 (pass 8). This line read `fconsts["LUNGE_TIME"]`, a constant PASS 7
	# DELETED when it retired the cradle's rush — so from that pass on the lookup threw
	# "Invalid access to property or key 'LUNGE_TIME' on a base object of type 'Dictionary'",
	# GDScript abandoned the rest of `_pass5_checks()` at that line, and the file still printed
	# a green summary because a runtime SCRIPT ERROR is not a failed `_ok()` and
	# `run_tests.sh` only greps for PARSE errors. Everything below this point in the function
	# had not run since. It now asserts the RETIREMENT as well, which is the claim that went
	# stale, and `has()` cannot throw.
	var fconsts: Dictionary = load("res://scripts/void_cradle_figure.gd").get_script_constant_map()
	_ok("…and the rush is 0.6 s over a 0.25 s turn",
		absf(float(fconsts["CHARGE_TIME"]) - 0.6) < 0.001
		and absf(float(fconsts["TURN_TIME"]) - 0.25) < 0.001,
		"charge %.2f turn %.2f" % [fconsts.get("CHARGE_TIME", -1.0), fconsts.get("TURN_TIME", -1.0)])
	_ok("…and the cradle's old LUNGE_TIME is gone, not merely unused (pass 7 retired the rush)",
		not fconsts.has("LUNGE_TIME"), str(fconsts.keys()))
	# ⭐ pass 8: the cradle's clock is a RISE now, and it is the level that owns its numbers.
	_ok("…while the cradle rises 0.80 m over 0.50 s (the level's own constants)",
		absf(float(lconsts.get("SHADOW_RISE_FROM", -1.0)) - 0.80) < 0.001
		and absf(float(lconsts.get("SHADOW_RISE", -1.0)) - 0.50) < 0.001,
		"%.2f m / %.2f s" % [lconsts.get("SHADOW_RISE_FROM", -1.0), lconsts.get("SHADOW_RISE", -1.0)])
	_ok("…it watches the PLAYER layer only and is not itself solid",
		area != null and area.collision_mask == 1 and area.collision_layer == 0)
	_ok("…and nothing has fired at load", not bool(_level.call("corridor_charge_done"))
		and _level.get_node_or_null("ChargeFigure") == null)
	_ok("…and the user's corridor sting resolves through GameState.load_audio",
		gs.call("load_audio", "void_corridor_jumpscare") != null)
	# ⚠️ -12.3 dB is measured, not chosen (2026-09-23): the shared jumpscare delivered -13.1 dBFS at
	# -10.3 dB; the user's file is -0.8 dBFS mean, so -12.3 dB lands it exactly there.
	_level.call("_fire_corridor_charge")
	var sting := _level.get_node_or_null("ChargeSting") as AudioStreamPlayer3D
	_ok("the charge's sting is the user's `void_corridor_jumpscare`, on Master, at the measured -12.3 dB",
		sting != null and sting.stream != null
		and String(sting.stream.resource_path).find("void_corridor_jumpscare") >= 0
		and absf(sting.volume_db + 12.3) < 0.01 and sting.bus == "Master",
		"%s %.1f dB bus %s" % [sting.stream.resource_path if sting and sting.stream else "-",
			sting.volume_db if sting else 0.0, sting.bus if sting else "-"])
	# …and put the level back: this file fires the charge FOR REAL later, from inside the volume.
	var early := _level.get_node_or_null("ChargeFigure")
	if early:
		_level.remove_child(early)
		early.queue_free()
	_level.set("_charge_done", false)
	_level.set("_charge_protect", -1.0)
	var c0 = _stalkers.get("C", null)
	if c0 and is_instance_valid(c0):
		c0.set("protected_player_rect", _tile_rect)


const ROOM_CEIL := 3.3


func _world_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var found := false
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var w: AABB = mi.global_transform * mi.get_aabb()
			out = w if not found else out.merge(w)
			found = true
		for k in c.get_children():
			stack.append(k)
	return out


func _no_emission(n: Node) -> bool:
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			var m := (c as MeshInstance3D).get_surface_override_material(0)
			if m is StandardMaterial3D and bool((m as StandardMaterial3D).emission_enabled):
				return false
		for k in c.get_children():
			stack.append(k)
	return true


func _no_scary(n: Node) -> bool:
	var walk: Node = n
	while walk != null:
		if walk is ScaryObject:
			return false
		walk = walk.get_parent()
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is ScaryObject:
			return false
		for k in c.get_children():
			stack.append(k)
	return true


# ⭐ THE RECURRING ROOM, WALKED (2026-09-22 pass 6).
#
# ⚠️ EVERY STEP HERE IS A REAL CROSSING under `ai_move_dir` with the real body. The whole point
# of this pass is that the verb is walking; a harness that called `_step()` would be testing the
# function that the 23:47 playtester could not reach. The five stalkers were removed at stage 3.
# ⚠️ `RandomAmbient` was unregistered at bootstrap (Issue 240), which is what lets the
# zero-panic assertions below mean anything.
var _room_hall: Node = null
var _room_panic := 0.0
var _room_order: Array = []
var _room_lit_samples := 0
var _room_lit_violations := 0
var _room_lit_detail := ""
var _room_ticks := 0
var _room_target := Vector3.ZERO
var _room_wrong_id := ""
var _room_stage_seen: Array = []
var _room_order0: Array = []
var _room_pending_stage := 0
# ⚠️ THE PEAK, not the sample. Stage 5 is applied and the 1.5 s settle immediately starts
# tweening the lean back out of it, so a value read a few frames later is already 0.09.
var _room_max_lean := 0.0
# ⚠️ AND THE PEAK DIORAMA SCALE, for exactly the same reason: `_settle()` starts tweening both
# copies down to 0.001 in the frame stage 5 is applied, so a value read six ticks later is
# already 0.28. The first draft read the instantaneous value and went red at 0.281.
var _room_max_scale := 0.0


func _room_begin() -> void:
	print("--- the recurring room: a wrong door ---")
	_room_hall = _level.call("frame_hall")
	_level.call("_open_secret_door")
	_p.set("ai_active", true)
	_room_panic = float(_p.call("get_panic_ratio"))
	_room_stage_seen = []
	# A door that is NOT the one the answer wants first.
	var answer: Array = _room_hall.call("answer_order")
	_room_wrong_id = String(answer[2])
	_aim_room(int(_room_hall.call("slot_of", _room_wrong_id)))
	_room_order = (_room_hall.call("frame_ids") as Array).duplicate()
	_room_order0 = _room_order.duplicate()
	_room_max_lean = 0.0
	_room_max_scale = 0.0
	_room_pending_stage = 0
	_room_lit_samples = 0
	_room_lit_violations = 0
	_room_lit_detail = ""
	_stage = 86


func _aim_room(slot: int) -> void:
	_p.set("ai_move_dir", Vector2.ZERO)
	_p.velocity = Vector3.ZERO
	_p.global_position = _room_hall.call("front_point", slot)
	_p.force_update_transform()
	_room_target = _room_hall.call("back_point", slot)
	_p.call("ai_look_at", _room_target + Vector3(0, 1.2, 0))
	_p.get_node("Camera3D").force_update_transform()
	_room_ticks = 0


func _steer_room() -> void:
	var dir: Vector3 = _room_target - _p.global_position
	dir.y = 0.0
	if dir.length() < 0.15:
		_p.set("ai_move_dir", Vector2.ZERO)
		return
	var local: Vector3 = _p.global_basis.inverse() * dir.normalized()
	_p.set("ai_move_dir", Vector2(local.x, local.z))


# ⚠️ THE LEVEL'S ONE RULE, SAMPLED EVERY FRAME: nothing ever changes while you are looking at
# it. Pass 4 could only satisfy a weakened form of that (Issue 241 — a five-frame room has no
# free bearing, so it exchanged pairs the camera could not see). The cut satisfies the original:
# while the order is moving the screen is BLACK, so this asserts that no sample in which the
# panel was down showed a different order from the sample before it.
func _room_sample_lit() -> void:
	var ids: Array = _room_hall.call("frame_ids")
	var black: bool = bool(_level.call("cut_is_black"))
	if not black:
		_room_lit_samples += 1
		for i in range(ids.size()):
			if String(ids[i]) != String(_room_order[i]):
				_room_lit_violations += 1
				_room_lit_detail = "slot %d went %s -> %s with the screen LIT" \
					% [i, _room_order[i], ids[i]]
	_room_order = ids.duplicate()


func _room_wrong_walk() -> void:
	_room_ticks += 1
	_room_sample_lit()
	_steer_room()
	if int(_room_hall.call("wrong_count")) > 0 and not bool(_room_hall.call("is_stepping")):
		_p.set("ai_move_dir", Vector2.ZERO)
		_p.velocity = Vector3.ZERO
		_stage = 87
		_wait = 4
		return
	if _room_ticks > 900:
		_ok("walking through a wrong door registers a step", false,
			"900 ticks, at %v" % _p.global_position)
		_stage = 88


func _room_wrong_done() -> void:
	_ok("WALKING through a door is the step — no dwell, no posture",
		int(_room_hall.call("wrong_count")) == 1 and int(_room_hall.call("crossings")) == 1,
		"%d crossings" % int(_room_hall.call("crossings")))
	_ok("…and a wrong door drops the room back to stage 0",
		int(_room_hall.call("stage")) == 0)
	_ok("…and puts the player back at the room's entrance",
		_p.global_position.distance_to(_room_hall.call("entrance_point")) < 0.4,
		"at %v" % _p.global_position)
	_ok("…and the five doors were reshuffled: the order really differs",
		(_room_hall.call("frame_ids") as Array) != _room_order0,
		"%s -> %s" % [str(_room_order0), str(_room_hall.call("frame_ids"))])
	# ⚠️ THE ONE-RULE CONTROL, and it asserts its own sample size: "0 samples … PASS" has
	# happened in this project.
	_ok("CONTROL: no door changed in any frame where the screen was LIT (%d lit samples)"
		% _room_lit_samples,
		_room_lit_violations == 0 and _room_lit_samples >= 8, _room_lit_detail)
	_ok("…and the cut really happened", int(_room_hall.call("cuts")) == 1
		and not bool(_level.call("cut_is_black")))
	# The figure at arm's length, for exactly one rendered frame, with no rule of any kind.
	var fig: Node3D = _room_hall.call("watcher")
	_ok("a figure stood at arm's length on the fade-in", fig != null)
	if fig:
		var bad := ""
		var stack: Array = [fig]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is CollisionObject3D or n is CollisionShape3D or n is ScaryObject:
				bad += n.name + " "
			for k in n.get_children():
				stack.append(k)
		_ok("…and it is a PHOTOGRAPH: no collider, no ScaryObject, no rule", bad == "", bad)
		# ⚠️ MEASURED HORIZONTALLY. The figure's ORIGIN sits 0.40 m below the player's feet so
		# that its 2.05 m mask lands on the 1.65 m eye line (`void_cradle_figure.gd`'s own
		# convention), which makes the straight-line distance to the camera 2.1 m for a figure
		# that is 0.6 m in front of it. The first draft measured the diagonal and read as a fail.
		var cam := _p.get_node("Camera3D") as Camera3D
		var flat: float = Vector2(fig.global_position.x - cam.global_position.x,
			fig.global_position.z - cam.global_position.z).length()
		_ok("…0.6 m in front of the camera, not across the room", flat < 1.0, "%.2f m" % flat)
	_ok("…for EXACTLY one process frame",
		int(_room_hall.call("watcher_frames")) == 1,
		"%d frames" % int(_room_hall.call("watcher_frames")))
	_ok("the wrong door costs ZERO panic",
		absf(float(_p.call("get_panic_ratio")) - _room_panic) < 0.001,
		"%.4f -> %.4f" % [_room_panic, float(_p.call("get_panic_ratio"))])
	_stage = 88


# ⚠️ THE CONTROL THAT MATTERS MOST: the thing this pass replaced was a 1.2 s STAND-STILL dwell,
# and the playtester's complaint was that walking through did nothing. Standing dead centre in
# an opening — the posture the old mechanic REQUIRED — must now do nothing at all, including
# when the body's own settling jitter crosses the plane.
func _room_still_begin() -> void:
	print("--- the recurring room: standing still in a doorway ---")
	var slot: int = int(_room_hall.call("slot_of",
		String((_room_hall.call("answer_order") as Array)[0])))
	_p.set("ai_move_dir", Vector2.ZERO)
	_p.velocity = Vector3.ZERO
	_p.global_position = (_room_hall.call("unit", slot) as Node3D).global_position \
		+ Vector3(0, 0.1, 0)
	_p.force_update_transform()
	_room_ticks = int(_room_hall.call("crossings"))
	_stage = 89
	_wait = 130          # a little over two seconds, against the retired 1.2 s dwell


func _room_still_done() -> void:
	_ok("CONTROL: 2 s standing DEAD CENTRE in a doorway steps nothing",
		int(_room_hall.call("crossings")) == _room_ticks
		and int(_room_hall.call("stage")) == 0,
		"%d crossings, stage %d" % [int(_room_hall.call("crossings")),
			int(_room_hall.call("stage"))])
	print("--- the recurring room: five right doors ---")
	_aim_room(int(_room_hall.call("slot_of",
		String((_room_hall.call("answer_order") as Array)[0]))))
	_stage = 90


# Walk the answer. After each right door the stage's own state is asserted, so the ladder is
# measured rung by rung rather than at the end.
func _room_right_walk() -> void:
	_room_ticks += 1
	_room_max_lean = maxf(_room_max_lean, float(_room_hall.call("lean")))
	_room_max_scale = maxf(_room_max_scale, float(_room_hall.call("diorama_scale", 0)))
	# ⚠️ ASSERTED ONE BEAT LATE, on purpose. Stage 3's blink and its doorway figure are placed
	# AFTER the cut comes down — they are things you see for one rendered frame, and placing
	# them under the black would be one frame of a black screen — so the hall has not yet
	# counted the figure in the frame the stage number changes. The first draft read 0 frames
	# and was measuring the ordering, not the beat.
	if _room_pending_stage > 0:
		var pend := _room_pending_stage
		_room_pending_stage = 0
		_assert_stage(pend)
		if bool(_room_hall.call("is_solved")):
			_stage = 91
			_wait = 200
			return
		_aim_room(int(_room_hall.call("slot_of",
			String((_room_hall.call("answer_order") as Array)[pend]))))
		return
	_steer_room()
	if bool(_room_hall.call("is_stepping")):
		_p.set("ai_move_dir", Vector2.ZERO)
		_p.velocity = Vector3.ZERO
		return
	var st: int = int(_room_hall.call("stage"))
	if st > 0 and not _room_stage_seen.has(st):
		_room_stage_seen.append(st)
		_p.set("ai_move_dir", Vector2.ZERO)
		_p.velocity = Vector3.ZERO
		_room_pending_stage = st
		_wait = 6
		return
	if _room_ticks > 1400:
		_ok("the five right doors were walked inside the budget", false,
			"stage %d at %v" % [st, _p.global_position])
		_stage = 91
		_wait = 10


# The lamp tweens at LAMP_RATE 1.2/s and `_assert_stage` runs six ticks after the arrival, so
# "it has dropped to 0.12" is a claim about a value in motion. Accept anything that has left the
# base and is heading for the target — and say which, rather than widening a tolerance silently.
func _lamp_settled(h: Node, want: float) -> bool:
	var e: float = float(h.call("lamp_energy"))
	return e <= 0.25 - 0.01 and e >= want - 0.001


# "" if the subtree carries no collider, no CollisionShape3D and no ScaryObject; the offending
# node names otherwise. P3: every figure in this room is a photograph.
func _rule_free(n: Node) -> String:
	if n == null:
		return "missing"
	var bad := ""
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is CollisionObject3D or c is CollisionShape3D or c is ScaryObject:
			bad += c.name + " "
		for k in c.get_children():
			stack.append(k)
	return bad


func _assert_stage(st: int) -> void:
	var h := _room_hall
	_ok("right door %d: the player is back at the entrance, one stage stranger" % st,
		_p.global_position.distance_to(h.call("entrance_point")) < 0.4
		and int(h.call("stage")) == st, "at %v" % _p.global_position)
	# ⭐ THE PASS-7 LADDER, RUNG BY RUNG, FROM THE ENTRANCE STANCE. Every rung below was chosen
	# because it is full-screen or silhouette-scale INSIDE THE TORCH CONE — the previous ladder's
	# first two rungs were an 8.7 % change in a lamp the player's own torch beats ten to one, and
	# an echo copy standing geometrically inside its own original (Issue 256).
	# The camera roll is asserted on EVERY rung, because it is the one channel with five notches.
	# ⚠️ THE BASE **AND** THE CAMERA NODE. The base is what the room commands; the live value is
	# what the player's eye actually has, and the two are only equal because `_tick_shake()` was
	# taught to displace the base instead of replacing it. Reading only one of them would let a
	# roll that never reached the camera pass.
	_ok("right door %d: the camera is HELD at %.3f rad of roll" % [st, h.call("roll_for", st)],
		absf(float(h.call("camera_roll")) - float(h.call("roll_for", st))) < 0.0005
		and absf(float(h.call("camera_roll_live")) - float(h.call("roll_for", st))) < 0.01,
		"base %.4f, camera %.4f" % [float(h.call("camera_roll")),
			float(h.call("camera_roll_live"))])
	match st:
		1:
			# ⚠️ NOT the lamp: at stage 1 the lamp is deliberately UNTOUCHED now. What stage 1
			# is, is five 1.40 x 2.20 m panels going from albedo 0.02 to 0.55 behind the five
			# memories — the one change that improves the contrast of the thing the player is
			# already staring at, at full torch strength.
			var pale := 0
			for i in range(5):
				if (h.call("backdrop_albedo", i) as Color).is_equal_approx(
						Color(0.55, 0.53, 0.48)):
					pale += 1
			_ok("stage 1: all five backdrops go PALE (albedo 0.02 -> 0.55), %d of 5" % pale,
				pale == 5, str(h.call("backdrop_albedo", 0)))
			_ok("…with NO emission anywhere in the room (SCARY.md §8.8: silhouette, not glow)",
				_no_emission(h))
			_ok("…the room hums, and a whisper starts in the doorway behind your head",
				bool(h.call("hum_playing")) and bool(h.call("back_whisper_playing")))
			# …and the lamp has NOT dropped yet: that rung moved to stage 3.
			_ok("…and the lamp has NOT moved (its drop belongs to stage 3 now)",
				absf(float(h.call("lamp_energy")) - 0.25) < 0.02,
				"%.3f" % float(h.call("lamp_energy")))
		2:
			_ok("stage 2: the dioramas tilt and a second copy is visible",
				absf(float((h.call("unit", 0) as Node3D).get_node("Diorama_"
					+ String((h.call("frame_ids") as Array)[0])).rotation.z) - 0.18) < 0.001
				and (h.call("echo", 0) as Node3D).visible)
			# ⭐ ITEM 3: the echo STEPS SIDEWAYS. The offset is the entire rung — at 0 lateral
			# offset the copy is inside the original's silhouette and cannot be seen at all.
			var off: Vector3 = h.call("echo_offset", 0)
			_ok("…and it stands 0.28 m to the SIDE at full scale, not concentric behind",
				absf(off.x - 0.28) < 0.001 and absf(off.z - (0.48 + 0.10)) < 0.001
				and absf(float(h.call("diorama_scale", 0)) - 1.0) < 0.001,
				"echo at %v" % off)
			_ok("…and the room's own FLOOR carries the corrupted texture now",
				bool(h.call("floor_corrupt"))
				and String(h.call("floor_texture_name")) == "wall_void_corrupt.png",
				"'%s'" % h.call("floor_texture_name"))
			_ok("…and the lamp takes its first colour notch, at unchanged energy",
				(h.call("lamp_color") as Color).is_equal_approx(Color(0.66, 0.47, 1.0))
				and absf(float(h.call("lamp_energy")) - 0.25) < 0.02,
				"%s at %.3f" % [h.call("lamp_color"), float(h.call("lamp_energy"))])
		3:
			_ok("stage 3: whispers come from two of the doors",
				int(h.call("whispers_playing")) == 2,
				"%d playing" % int(h.call("whispers_playing")))
			_ok("…and a figure stood in a NON-answer doorway for one frame",
				int(h.call("door_figure_frames")) >= 1,
				"%d frames" % int(h.call("door_figure_frames")))
			# ⭐ ITEM 4: a ceiling that is not the ceiling comes down, and the lamp with it.
			_ok("…and a false ceiling has descended to 2.70 m with the lamp on it",
				absf(float(h.call("slab_y")) - 2.7) < 0.001
				and absf(float(h.call("lamp_y")) - 2.5) < 0.001,
				"slab %.2f, lamp %.2f" % [float(h.call("slab_y")), float(h.call("lamp_y"))])
			_ok("…and THAT is where the lamp's drop to 0.12 lives now", _lamp_settled(h, 0.12),
				"%.3f" % float(h.call("lamp_energy")))
		4:
			_ok("stage 4: the room's own walls swap to the corrupted texture",
				bool(h.call("walls_corrupt"))
				and String(h.call("wall_texture_name")) == "wall_void_corrupt.png",
				"'%s'" % h.call("wall_texture_name"))
			# ⭐ ITEMS 7 + 8: a SIXTH door, dead centre of the one stance this room has, with
			# something standing in it. ⚠️ Once, never one-per-rung: a door per stage would be an
			# anomaly counter (§8.2), which is the thing this room's header forbids.
			var sixth: Node3D = h.call("sixth_door")
			_ok("…and a SIXTH doorway is standing in the far wall, dead centre",
				bool(h.call("sixth_door_visible")) and sixth != null
				and absf(sixth.global_position.z - 47.0) < 0.01
				and sixth.global_position.x < -26.8,
				str(sixth.global_position) if sixth else "missing")
			var watcher: Node3D = h.call("sixth_watcher")
			_ok("…with a motionless figure in it, which is a PHOTOGRAPH: no collider, no rule",
				watcher != null and _rule_free(watcher) == "", _rule_free(watcher))
			_ok("…and the dioramas have grown to 1.25x",
				absf(float(h.call("diorama_scale", 0)) - 1.25) < 0.001,
				"%.3f" % float(h.call("diorama_scale", 0)))
			_ok("…and the lamp takes its second colour notch",
				(h.call("lamp_color") as Color).is_equal_approx(Color(0.57, 0.33, 1.0)),
				str(h.call("lamp_color")))
		5:
			# ⚠️ THE PEAK LEAN, because the settle's 1.5 s tween starts in the same frame and is
			# already unwinding it — which is the design (the room reaches its worst state and
			# the last door is what takes the lean back out of it).
			_ok("stage 5: the doors leaned 0.10 rad and every whisper is on",
				absf(_room_max_lean - 0.10) < 0.005
				and int(h.call("whispers_playing")) == 5,
				"peak lean %.3f, %d whispers" % [_room_max_lean,
					int(h.call("whispers_playing"))])
			_ok("…the ceiling takes its second notch to 2.20 m, and the lamp with it",
				absf(float(h.call("slab_y")) - 2.2) < 0.001
				and absf(float(h.call("lamp_y")) - 2.0) < 0.001,
				"slab %.2f, lamp %.2f" % [float(h.call("slab_y")), float(h.call("lamp_y"))])
			# ⚠️ THE COMMANDED VALUE **AND** THE OBSERVED PEAK. `_settle()` starts tweening both
			# copies down to 0.001 in the very frame stage 5 is applied, so by the harness's next
			# tick the node reads 1.479 and no tolerance on the observation alone is honest. The
			# room is asked what it commanded (exactly 1.5) and the node is required to have got
			# most of the way there before the settle took it.
			_ok("…the dioramas are jammed in their openings at 1.5x",
				absf(float(h.call("grow_applied")) - 1.5) < 0.0001 and _room_max_scale > 1.4,
				"commanded %.3f, observed peak %.3f"
				% [float(h.call("grow_applied")), _room_max_scale])
			# ⭐ ITEM 9: one memory out of its frame, at 1:1, in the room with you.
			var mem: Node3D = h.call("memory")
			_ok("…and the LAST door's memory is standing in the room at 1:1",
				bool(h.call("memory_visible")) and mem != null and _no_scary(mem),
				"missing" if mem == null else "carries a ScaryObject")
			if mem != null:
				var mb := _world_aabb(mem)
				# ⚠️ A PHYSICS QUERY, NOT A PROPERTY. "Geometry only" is a claim about what the
				# world does, and a disabled CollisionShape3D is one property away from being a
				# 3.4 m wall in the room the puzzle is solved in. This fires a real ray straight
				# through the middle of the prop, in the layer mask the player's own body uses,
				# and requires it to come out the other side.
				var q := PhysicsRayQueryParameters3D.create(
					Vector3(mb.position.x - 0.5, 1.2, mb.position.z + mb.size.z * 0.5),
					Vector3(mb.position.x + mb.size.x + 0.5, 1.2,
						mb.position.z + mb.size.z * 0.5))
				q.collision_mask = 1
				var hit := _p.get_world_3d().direct_space_state.intersect_ray(q)
				_ok("…and a ray goes straight THROUGH it: geometry only, nothing solid",
					hit.is_empty(), "ray hit %s" % hit.get("collider", "nothing"))
				# ⚠️ Clear of the entrance stance's own capsule (radius 0.4) and of the east
				# column's shells, and inside the room. A 1:1 prop in a 6 x 6 room is a placement
				# problem before it is an effect — `ceiling_stair()` is 3.40 m long against a
				# 5.80 m room, so "wholly outside the z 47.5 lane" is geometrically impossible
				# and the honest test is the two clearances that matter.
				var gap: float = (-21.9) - (mb.position.x + mb.size.x)
				_ok("…between the entrance and the east column, and clear of both",
					mb.position.x > -23.30 and mb.position.x + mb.size.x < -22.30
					and mb.position.z > 44.15 and mb.position.z + mb.size.z < 49.85,
					"aabb %v + %v (%.2f m of air to the entrance stance)"
					% [mb.position, mb.size, gap])


func _room_solved() -> void:
	_ok("five right doors settle the room", bool(_room_hall.call("is_solved")))
	# ⭐ THE SETTLE'S OWN LEDGER (pass 7). Pass 6's ruling stands — the room STAYS corrupted, or
	# the last door reads as an undo — so the floor and the walls keep the corrupt texture and
	# the lamp keeps its colour with only its energy resolving. What goes is everything whose
	# staying would read as a mistake over the page the corridor settles onto.
	_ok("…the camera roll is zeroed, on the level's base AND on the camera node",
		absf(float(_room_hall.call("camera_roll"))) < 0.0005
		and absf(float(_room_hall.call("camera_roll_live"))) < 0.01,
		"base %.4f, camera %.4f" % [float(_room_hall.call("camera_roll")),
			float(_room_hall.call("camera_roll_live"))])
	_ok("…the false ceiling, the sixth door, its watcher and the 1:1 memory are all FREED",
		_room_hall.call("slab") == null and _room_hall.call("sixth_door") == null
		and _room_hall.call("sixth_watcher") == null and _room_hall.call("memory") == null,
		"slab %s, sixth %s, memory %s" % [_room_hall.call("slab"),
			_room_hall.call("sixth_door"), _room_hall.call("memory")])
	_ok("…and nothing is left of them in the tree either",
		_room_hall.get_node_or_null("FalseCeiling") == null
		and _room_hall.get_node_or_null("SixthDoor") == null
		and _room_hall.get_node_or_null("MemoryAtFullSize") == null)
	_ok("…the floor and the walls STAY corrupt (the last door is not an undo)",
		bool(_room_hall.call("walls_corrupt")) and bool(_room_hall.call("floor_corrupt"))
		and String(_room_hall.call("floor_texture_name")) == "wall_void_corrupt.png")
	_ok("…the lamp keeps its colour and comes back to the light at 1.0",
		(_room_hall.call("lamp_color") as Color).is_equal_approx(Color(0.57, 0.33, 1.0))
		and float(_room_hall.call("lamp_energy")) > 0.9
		and absf(float(_room_hall.call("lamp_y")) - 2.8) < 0.001,
		"%s at %.2f, y %.2f" % [_room_hall.call("lamp_color"),
			float(_room_hall.call("lamp_energy")), float(_room_hall.call("lamp_y"))])
	_ok("…and the hum and the whisper behind you stay",
		bool(_room_hall.call("hum_playing")) and bool(_room_hall.call("back_whisper_playing")))
	var note = _level.call("hidden_note")
	_ok("…and the page at the corridor's end is in the world",
		note != null and bool(note.call("is_revealed")) and note.visible)
	_p.set("ai_move_dir", Vector2.ZERO)
	_p.velocity = Vector3.ZERO
	_p.global_position = Vector3(-24.0, 0.1, 48.7)
	_p.force_update_transform()
	_p.call("ai_look_at", (note as Node3D).global_position)
	_p.get_node("Camera3D").force_update_transform()
	var t: Node = _p.call("ai_interact_target")
	_ok("…and it is reachable by the shipping ray from inside the settled corridor",
		t == note or (t != null and (note as Node3D).is_ancestor_of(t)),
		"ray hit %s" % (t.name if t else "nothing"))
	_ok("the whole room — five rights, one wrong, five stages — cost ZERO panic",
		absf(float(_p.call("get_panic_ratio")) - _room_panic) < 0.001,
		"%.4f -> %.4f" % [_room_panic, float(_p.call("get_panic_ratio"))])
	# ⭐ AND A RESTORE APPLIES A STAGE WITHOUT REPLAYING IT.
	var snap: Dictionary = _level.call("save_progress")
	_ok("the snapshot carries `frame_stage` and `ward_box_open`",
		snap.has("frame_stage") and int(snap["frame_stage"]) == 5
		and bool(snap.get("ward_box_open", false)),
		"stage %s, box %s" % [snap.get("frame_stage"), snap.get("ward_box_open")])
	_p.set("ai_active", false)
	_stage = 60


# ── THE CORRIDOR CHARGE, driven through the shipping trigger ──────────────────────────────
#
# ⚠️ IT RUNS HERE, WITH ALL FIVE STALKERS STILL ALIVE, because half of what it has to prove is
# about creature C — and `_watch_control()` frees every stalker a few stages later. `_loop_broken`
# is set by hand for the beat and put back: it is the exact flag a snapshot restore sets, no rung
# of the loop ladder is touched, and the real southbound walk into the real Area3D is what fires
# the charge. Nothing here calls `_fire_corridor_charge()`.
# ⚠️ CREATURE C NO LONGER HAS TO BE MOVED, and that is a consequence of the trigger moving to
# z 26 (pass 6). While the volume sat at z 41..43 it CONTAINED C's stance at (13.15, 41), so
# teleporting the player in was teleporting them onto a lethal stalker (Issue 228: a wait beside
# a creature is a distance) and the stage had to relocate it. At z 25..27 the player is 14 m from
# C for the whole beat, so nothing is moved and nothing has to be put back.
var _charge_panic := 0.0
var _charge_fig: Node = null
var _c_rect := Rect2()
# ⭐ pass 7: the bearing at the frame the charge fires and at the frame the rush begins, and how
# far the figure had moved by the latter.
var _charge_ticks := 0
var _charge_yaw_at_fire := -1.0
var _charge_yaw_at_rush := -1.0
var _charge_moved_at_rush := -1.0


func _charge_begin() -> void:
	print("--- the corridor charge at 60 % of the walk back (z 26) ---")
	var c = _stalkers.get("C", null)
	_c_rect = c.get("protected_player_rect") if c else Rect2()
	_level.set("_loop_broken", true)
	_p.set("ai_active", true)
	_p.global_position = Vector3(12.5, 0.1, 25.6)
	_p.force_update_transform()
	# NORTHBOUND first: the way IN. The beat answers the walk back and must not fire here.
	_p.call("ai_look_at", Vector3(12.5, 1.3, 34.0))
	_p.set("ai_move_dir", Vector2(0.0, -1.0))
	_charge_panic = float(_p.call("get_panic_ratio"))
	_stage = 76
	_wait = 24


func _charge_north_control() -> void:
	_ok("CONTROL: walking NORTH through the trigger does not fire the charge",
		not bool(_level.call("corridor_charge_done"))
		and _level.get_node_or_null("ChargeFigure") == null,
		"player at z %.2f, velocity z %.2f" % [_p.global_position.z, _p.velocity.z])
	_ok("…and the control really did cross the volume northbound",
		_p.velocity.z > 0.5 and _p.global_position.z > 26.0,
		"z %.2f, vz %.2f" % [_p.global_position.z, _p.velocity.z])
	# …and now walk the leg BACKWARDS, which is the leg capture 1 of the 02:13 run is about:
	# *"I was going backwards and I did not see the jumpscare."* The player faces NORTH, away
	# from where the figure stands, and moves SOUTH through the trigger. `ai_move_dir` is in the
	# body's own frame, so (0, +1) is "walk backwards" exactly as S does in game.
	_p.global_position = Vector3(12.5, 0.1, 26.6)
	_p.force_update_transform()
	_p.call("ai_look_at", Vector3(12.5, 1.3, 34.0))     # facing AWAY from the figure at z 16.5
	_p.get_node("Camera3D").force_update_transform()
	_p.set("ai_move_dir", Vector2(0.0, 1.0))
	_ok("…and the stance for the charge really is facing AWAY (%.0f deg off the figure)"
		% _yaw_error_to(Vector3(12.5, 1.65, 16.5)),
		_yaw_error_to(Vector3(12.5, 1.65, 16.5)) > 90.0)
	_charge_ticks = 0
	_charge_yaw_at_rush = -1.0
	_charge_moved_at_rush = -1.0
	_charge_yaw_at_fire = -1.0
	_stage = 77


# ⭐ POLLED, NOT WAITED (2026-09-22 pass 7). The claim is *"the camera faces the figure before the
# rush moves it"*, and that is a statement about ONE FRAME — the frame `_begin_charge()` runs on.
# A fixed `_wait` samples whenever it happens to land and would read a camera that the rush's own
# `_face_player()` has since dragged round, which proves nothing. This walks every tick, records
# the bearing at the instant the figure fires AND how far it had moved by then, and stops.
func _charge_watch(_t: int) -> void:
	_charge_ticks += 1
	var fig := _level.get_node_or_null("ChargeFigure")
	if fig == null:
		if _charge_ticks > 240:
			_ok("the backwards walk fired the charge inside the budget", false,
				"240 ticks at z %.2f, vz %.2f" % [_p.global_position.z, _p.velocity.z])
			_stage = 78
			_wait = 10
		return
	if _charge_yaw_at_fire < 0.0:
		_charge_yaw_at_fire = _yaw_error_to(Vector3(12.5, 1.65, 16.5))
	if not bool(fig.call("has_lunged")):
		return
	_charge_yaw_at_rush = _yaw_error_to(Vector3(12.5, 1.65, 16.5))
	_charge_moved_at_rush = (fig as Node3D).global_position.distance_to(Vector3(12.5, 0, 16.5))
	_charge_fired()


func _charge_fired() -> void:
	_charge_fig = _level.get_node_or_null("ChargeFigure")
	var c = _stalkers.get("C", null)
	_ok("walking SOUTH through the trigger fires the charge",
		bool(_level.call("corridor_charge_done")) and _charge_fig != null,
		"at z %.2f, vz %.2f" % [_p.global_position.z, _p.velocity.z])
	# ⭐ ISSUE 255: A SCARE MUST OWN THE CAMERA. The player walked in with their back to this and
	# the beat turned them round; the bearing is read at the exact frame the rush begins, and the
	# figure is proved to have STILL BEEN AT ITS POST at that frame, so the camera came to the
	# figure rather than the figure coming into a camera that never moved.
	_ok("…from a stance facing away (%.0f deg), the camera faces the figure within 5 deg BEFORE "
		% _charge_yaw_at_fire + "the rush begins",
		_charge_yaw_at_rush >= 0.0 and _charge_yaw_at_rush < 5.0
		and _charge_yaw_at_fire > 90.0,
		"%.1f deg off at the rush" % _charge_yaw_at_rush)
	_ok("…and the figure had not started moving yet when that was true",
		_charge_moved_at_rush >= 0.0 and _charge_moved_at_rush < 0.6,
		"%.2f m travelled" % _charge_moved_at_rush)
	_ok("…and the input was never frozen for it (this level freezes only for the cut)",
		not bool(_p.call("is_input_frozen")))
	_ok("…with the figure standing 9.5 m down the corridor under the dead lamp",
		_charge_fig != null
		and (_charge_fig as Node3D).global_position.distance_to(Vector3(12.5, 0, 16.5)) < 1.2
		or bool(_charge_fig.call("has_lunged")) if _charge_fig else false,
		str((_charge_fig as Node3D).global_position) if _charge_fig else "missing")
	if _charge_fig != null:
		# P3: a photograph, not a creature. The one thing a rule-less figure must never become.
		var bad := ""
		var stack: Array = [_charge_fig]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is CollisionObject3D or n is CollisionShape3D or n is ScaryObject:
				bad += n.name + " "
			for k in n.get_children():
				stack.append(k)
		_ok("…and it is a PHOTOGRAPH: no collider, no ScaryObject, no rule", bad == "", bad)
	# ⚠️ §8.11 again: C stands in this corridor and the frame is about to be filled.
	var rect: Rect2 = c.get("protected_player_rect") if c else Rect2()
	_ok("creature C is held off for the beat, by the loop corridor's own rect",
		rect.is_equal_approx(_level.call("_room_rect", "LoopStraight")),
		"%s" % rect)
	_ok("the charge costs ZERO panic",
		absf(float(_p.call("get_panic_ratio")) - _charge_panic) < 0.001,
		"%.4f -> %.4f" % [_charge_panic, float(_p.call("get_panic_ratio"))])
	# ⚠️ STOP WALKING. Issue 228 for the third time on this level: the next wait is 2.8 s and the
	# player was walking south at 4 m/s. Since pass 6 they are walking AWAY from C (which is at
	# z 41 and never moved for this stage), but a bot left walking for three seconds ends up
	# somewhere nobody chose, which is how two of this file's stages staged their own deaths.
	_p.set("ai_move_dir", Vector2.ZERO)
	_p.velocity = Vector3.ZERO
	_stage = 78
	# 2.37 s of beat + protection (TURN 0.25 + CHARGE 1.0 + LINGER 0.12 + 1.0) = 143 ticks.
	_wait = 170


func _charge_after() -> void:
	var c = _stalkers.get("C", null)
	_ok("the figure is gone — one shot, nothing left in the corridor",
		_level.get_node_or_null("ChargeFigure") == null)
	_ok("…and C's suppression is HANDED BACK to the tile hall's rect",
		c != null and (c.get("protected_player_rect") as Rect2).is_equal_approx(_c_rect),
		"%s vs %s" % [c.get("protected_player_rect") if c else "-", _c_rect])
	_ok("the charge cost ZERO panic over the whole beat",
		absf(float(_p.call("get_panic_ratio")) - _charge_panic) < 0.001,
		"%.4f -> %.4f" % [_charge_panic, float(_p.call("get_panic_ratio"))])
	# CONTROL: walk the same leg again. It is one-shot.
	_p.global_position = Vector3(12.5, 0.1, 26.6)
	_p.force_update_transform()
	_p.call("ai_look_at", Vector3(12.5, 1.3, 20.0))
	_p.set("ai_move_dir", Vector2(0.0, -1.0))
	_stage = 79
	_wait = 24


func _charge_once() -> void:
	_ok("CONTROL: a second southbound pass fires nothing",
		_level.get_node_or_null("ChargeFigure") == null
		and bool(_level.call("corridor_charge_done")))
	# Hand the level back exactly as it was found: the loop is not broken yet. C never moved.
	_level.set("_loop_broken", false)
	_p.set("ai_move_dir", Vector2.ZERO)
	_p.set("ai_active", false)
	_stage = 1


# ⭐ THE PASS-6 STRUCTURE: the recurring room and the Ward box, at frame 0.
func _pass6_checks() -> void:
	print("--- pass 6: the recurring room and the Ward box ---")
	var hall: Node = _level.call("frame_hall")
	_ok("the recurring room exists and starts at stage 0",
		hall != null and int(hall.call("stage")) == 0 and not bool(hall.call("is_solved")))
	# ⚠️ THREE WALL BOXES, counted. Stage 4 swaps the room's own walls to a corrupted texture,
	# and the boxes are found by GEOMETRY because RoomBuilder names every wall "Wall" and Godot
	# replaces duplicate names (Issue 237). The x = -21 plane is the MORGUE's 10 m wall and is
	# deliberately NOT one of them; if a later footprint edit makes this count 1 or 5, the rung
	# has quietly changed size and this says so.
	_ok("…and it owns exactly 3 wall boxes (x -27, z 44, z 50 — never the Morgue's x -21)",
		(hall.call("wall_boxes") as Array).size() == 3,
		"%d boxes" % (hall.call("wall_boxes") as Array).size())
	# ⭐ pass 7: …AND ONE FLOOR, found by the same geometric rule. It is the biggest torch-lit
	# surface in the room and it carries stage 2. Asserted the same way and for the same reason
	# as the wall count: a later footprint edit must not silently drop a rung.
	var fl: CSGBox3D = hall.call("floor_box")
	_ok("…and exactly one FLOOR box, 6 x 6 under the room at y -0.1",
		fl != null and absf(fl.size.x - 6.0) < 0.01 and absf(fl.size.z - 6.0) < 0.01
		and fl.position.y < 0.0,
		str(fl.position) + " " + str(fl.size) if fl else "missing")
	_ok("…carrying the level's own wall texture at stage 0",
		String(hall.call("wall_texture_name")) == "wall_void.png",
		"'%s'" % hall.call("wall_texture_name"))
	_ok("…and the floor its own, un-corrupted",
		not bool(hall.call("floor_corrupt"))
		and String(hall.call("floor_texture_name")) == "floor_void.png",
		"'%s'" % hall.call("floor_texture_name"))
	# ── the pass-7 ladder's new hardware, at frame 0 ──────────────────────────────────────
	_ok("the false ceiling exists, parked at 3.0 m, 0.10 m clear of every wall's inner face",
		hall.call("slab") != null and absf(float(hall.call("slab_y")) - 3.0) < 0.001,
		"%.2f" % float(hall.call("slab_y")))
	var slab_box := _world_aabb(hall.call("slab") as Node3D)
	_ok("…and it is 5.6 x 5.6 inside a 6 x 6 room, so it cannot overlap anything",
		absf(slab_box.size.x - 5.6) < 0.01 and absf(slab_box.size.z - 5.6) < 0.01
		and slab_box.position.x > -26.9 and slab_box.position.x + slab_box.size.x < -21.1
		and slab_box.position.z > 44.1 and slab_box.position.z + slab_box.size.z < 49.9,
		"%v + %v" % [slab_box.position, slab_box.size])
	_ok("the sixth door and the memory are BUILT and hidden at stage 0",
		hall.call("sixth_door") != null and not bool(hall.call("sixth_door_visible"))
		and hall.call("memory") != null and not bool(hall.call("memory_visible")))
	# ⚠️ IT IS A VISUAL AGAINST THE WALL, NEVER AN OPENING. `check_shell_sealed` proves the shell
	# is intact; this proves the shell was never asked to be anything else — every piece of the
	# sixth door's geometry lives INSIDE the room, clear of the x = -26.9 wall face.
	var sixth_box := _world_aabb(hall.call("sixth_door") as Node3D)
	_ok("…and every millimetre of the sixth door is inside the room, clear of the far wall",
		sixth_box.position.x > -26.9 and sixth_box.position.x + sixth_box.size.x < -21.1,
		"x %.3f..%.3f against the wall face at -26.900"
		% [sixth_box.position.x, sixth_box.position.x + sixth_box.size.x])
	_ok("…and the backdrops are BLACK at stage 0 (albedo 0.02), not pale",
		(hall.call("backdrop_albedo", 0) as Color).is_equal_approx(Color(0.02, 0.018, 0.026)),
		str(hall.call("backdrop_albedo", 0)))
	_ok("…and the corrupted texture it swaps to really imported (Issue 25)",
		ResourceLoader.exists("res://assets/textures/level_4_void/wall_void_corrupt.png")
		and load("res://assets/textures/level_4_void/wall_void_corrupt.png") != null)
	_ok("…and `room_hum` resolves through GameState.load_audio",
		root.get_node("GameState").call("load_audio", "room_hum") != null)
	# The cut's own panel: present, black, full-rect, PROCESS_MODE_ALWAYS and NOT up at frame 0.
	var rect := _level.get_node_or_null("VoidCutLayer/CutRect") as ColorRect
	_ok("the cut's black panel exists and is down at frame 0",
		rect != null and not rect.visible and rect.color.is_equal_approx(Color(0, 0, 0, 1)))
	_ok("…on a CanvasLayer that keeps processing while the tree is paused",
		rect != null and rect.get_parent() is CanvasLayer
		and (rect.get_parent() as CanvasLayer).process_mode == Node.PROCESS_MODE_ALWAYS)

	# ── the Ward box ──────────────────────────────────────────────────────────────────────
	var box = _level.call("ward_box")
	_ok("`FoldedFrame_Ward_L` is a sealed strapped box now (capture #1)",
		box != null and _level.get_node_or_null("FoldedFrame_Ward_L") == null)
	var bx := _world_aabb(box as Node3D)
	_ok("…about 1.9 x 0.7 x 0.7 and standing on the floor at (-2.6, 14.5)",
		absf(bx.size.x - 1.94) < 0.05 and bx.size.y < 0.85 and absf(bx.size.z - 0.76) < 0.05
		and bx.position.y > -0.01 and bx.position.y < 0.02, str(bx))
	_ok("…and NOTHING in it is emissive (this level has no glow to spend)", _no_emission(box))
	_ok("…and it has no ScaryObject ancestor: zero panic, like everything else in the Ward",
		_no_scary(box))
	# Silhouette carries a prop (Issue 35): runners, base, four walls, a lid, four straps.
	var parts := {"WardBoxRunner": 0, "WardBoxSide": 0, "WardBoxEnd": 0, "WardBoxLidSlab": 0,
		"WardBoxStrap": 0, "WardBoxBuckle": 0}
	var stack: Array = [box]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			for k in parts.keys():
				if String(n.name).begins_with(k):
					parts[k] = int(parts[k]) + 1
		for c in n.get_children():
			stack.append(c)
	_ok("…built from parts: 2 runners, 2 sides, 2 ends, a lid and 4 strap pieces",
		int(parts["WardBoxRunner"]) == 2 and int(parts["WardBoxSide"]) == 2
		and int(parts["WardBoxEnd"]) == 2 and int(parts["WardBoxLidSlab"]) == 1
		and int(parts["WardBoxStrap"]) == 4, str(parts))
	# ⚠️ COINCIDENT SURFACES. The lid slab's underside must clear the walls' top faces — two
	# visible surfaces in one plane is this project's most common bug class.
	var lid := (box as Node3D).get_node_or_null("WardBoxLid/WardBoxLidSlab") as MeshInstance3D
	var rim: float = float(_level.get_script().get_script_constant_map().get("ROOM_H", 0.0))
	var fconst: Dictionary = load("res://scripts/void_fragments.gd").get_script_constant_map()
	var lid_bottom: float = float(fconst["BOX_LID_Y"]) - 0.035
	_ok("…and the lid's underside clears the box rim by %.3f m (>= 0.02 required)"
		% (lid_bottom - float(fconst["BOX_RIM_Y"])),
		lid != null and lid_bottom - float(fconst["BOX_RIM_Y"]) >= 0.02)
	_ok("…the box is SEALED at frame 0 and says so", not bool(box.call("is_open"))
		and String(box.call("prompt_text")) == "The box is sealed."
		and bool(box.call("can_interact")))
	# ── and the bed slat is inside it ─────────────────────────────────────────────────────
	var slat := _level.get_node_or_null("Anchor_slat") as Node3D
	_ok("the bed slat lies INSIDE the box, not at a frame's mouth",
		slat != null and bx.has_point(slat.global_position), str(slat.global_position))
	_ok("…and it refuses BY NAME while the lid is down (Issue 242: gate the target)",
		slat != null and bool(slat.call("is_sealed"))
		and String(slat.call("prompt_text")) == "The box is sealed.",
		"'%s'" % (slat.call("prompt_text") if slat else ""))
	slat.call("interact")
	_ok("CONTROL: …so E straight on the slat takes nothing",
		String(_level.call("carried_anchor")) == "",
		"carrying '%s'" % _level.call("carried_anchor"))

	# ── A RESTORE APPLIES A STAGE WITHOUT REPLAYING IT ────────────────────────────────────
	# ⚠️ Driven through `restore_state()`, the method `_restore_progress()` calls — never by
	# `apply_stage()` directly, because the claim is about the SNAPSHOT path. A snapshot that
	# blinked the player and stood a figure in a doorway would be a restore replaying a one-shot
	# (the Ward frame's rule), and the ladder's whole design is that every rung is reversible.
	var order0: Array = (hall.call("frame_ids") as Array).duplicate()
	var director := _level.get_node_or_null("StareDirector")
	var blinks0: int = int(director.call("fired_count")) if director else 0
	hall.call("restore_state", {"order": order0, "progress": 4, "stage": 4, "wrong": 2,
		"solved": false, "seed": 80920})
	_ok("a restore puts the room back at the stage it was left in",
		int(hall.call("stage")) == 4 and bool(hall.call("walls_corrupt"))
		and bool(hall.call("hum_playing")) and int(hall.call("whispers_playing")) == 2
		and absf(float(hall.call("lamp_energy")) - 0.12) < 0.001,
		"stage %d, lamp %.2f, %d whispers" % [int(hall.call("stage")),
			float(hall.call("lamp_energy")), int(hall.call("whispers_playing"))])
	_ok("…without replaying stage 3's one-shots: no blink, no figure in a doorway",
		hall.call("door_figure") == null
		and (director == null or int(director.call("fired_count")) == blinks0))
	_ok("…and it keeps the permutation it was saved with",
		(hall.call("frame_ids") as Array) == order0)
	hall.call("restore_state", {"order": order0, "progress": 0, "stage": 0, "wrong": 0,
		"solved": false, "seed": 80920})
	_ok("…and stage 0 restores EVERY rung: lamp, hum, whispers, walls, lean, duplicates",
		int(hall.call("stage")) == 0 and not bool(hall.call("walls_corrupt"))
		and String(hall.call("wall_texture_name")) == "wall_void.png"
		and not bool(hall.call("hum_playing")) and int(hall.call("whispers_playing")) == 0
		and absf(float(hall.call("lean"))) < 0.001
		and not (hall.call("echo", 0) as Node3D).visible
		and absf(float(hall.call("lamp_energy")) - 0.25) < 0.001,
		"lamp %.2f, tex '%s', lean %.3f" % [float(hall.call("lamp_energy")),
			hall.call("wall_texture_name"), float(hall.call("lean"))])
	# ⭐ …AND EVERY PASS-7 RUNG WITH THEM. Reversibility is not a nicety here: a wrong door drops
	# the room to stage 0 and the player has to be able to TELL that it did. One rung that did
	# not come back would be a ladder that only ever went up.
	_ok("…and so does the pass-7 half: backdrops, roll, floor, ceiling, colour, echo offset",
		(hall.call("backdrop_albedo", 0) as Color).is_equal_approx(Color(0.02, 0.018, 0.026))
		and absf(float(hall.call("camera_roll"))) < 0.0005
		and not bool(hall.call("floor_corrupt"))
		and String(hall.call("floor_texture_name")) == "floor_void.png"
		and absf(float(hall.call("slab_y")) - 3.0) < 0.001
		and absf(float(hall.call("lamp_y")) - 2.8) < 0.001
		and (hall.call("lamp_color") as Color).is_equal_approx(Color(0.72, 0.58, 1.0))
		and absf(float(hall.call("diorama_scale", 0)) - 1.0) < 0.001
		and not bool(hall.call("sixth_door_visible"))
		and not bool(hall.call("memory_visible"))
		and not bool(hall.call("back_whisper_playing")),
		("roll %.4f, floor '%s', slab %.2f, lamp y %.2f %s, scale %.2f, sixth %s, memory %s"
			% [float(hall.call("camera_roll")), hall.call("floor_texture_name"),
			float(hall.call("slab_y")), float(hall.call("lamp_y")), hall.call("lamp_color"),
			float(hall.call("diorama_scale", 0)), hall.call("sixth_door_visible"),
			hall.call("memory_visible")]))
	# ⚠️ AND A RESTORE AT STAGE 4 CARRIES THE ROLL AND THE SIXTH DOOR, because the snapshot path
	# never walks the ladder — a player who walks back into the room must find the room they
	# left, not the room as it was built.
	hall.call("restore_state", {"order": order0, "progress": 4, "stage": 4, "wrong": 2,
		"solved": false, "seed": 80920})
	_ok("a restore at stage 4 brings the roll, the ceiling, the sixth door and the colour back",
		absf(float(hall.call("camera_roll")) - 0.04) < 0.0005
		and absf(float(hall.call("slab_y")) - 2.7) < 0.001
		and bool(hall.call("sixth_door_visible"))
		and (hall.call("lamp_color") as Color).is_equal_approx(Color(0.57, 0.33, 1.0)),
		"roll %.4f, slab %.2f, sixth %s" % [float(hall.call("camera_roll")),
			float(hall.call("slab_y")), hall.call("sixth_door_visible")])
	hall.call("restore_state", {"order": order0, "progress": 0, "stage": 0, "wrong": 0,
		"solved": false, "seed": 80920})


# ── THE SHARD, THE BOX AND THE GURNEY'S RECEIPT ───────────────────────────────────────────
var _shard_panic := 0.0
var _hang_y0 := 0.0
var _hang_yaw0 := 0.0


func _shard_begin() -> void:
	print("--- the shard, the table's scare, and the box the gurney opens ---")
	var shard = _level.call("shard")
	_p.set("ai_active", true)
	_p.set("ai_move_dir", Vector2.ZERO)
	_p.global_position = Vector3(-3.4, 0.1, 20.6)
	_p.force_update_transform()
	_p.call("ai_look_at", shard.global_position)
	_p.get_node("Camera3D").force_update_transform()
	var t: Node = _p.call("ai_interact_target")
	# ⚠️ THE REAL RAY. Issue 230: the table's own collider used to swallow this ray, and a basin
	# the eye can enter and the E-ray cannot is the fault the whole prop was rebuilt for.
	_ok("the shard is what the interact ray finds from the Archive floor at frame 0",
		t == shard, "ray hit %s" % (t.name if t else "nothing"))
	_ok("…and it offers E rather than refusing (pass 5's wedge is retired)",
		String(shard.call("prompt_text")) == "E — Take the shard.",
		"'%s'" % shard.call("prompt_text"))
	_shard_panic = float(_p.call("get_panic_ratio"))
	# Now look AT the table: `arm_on_sight` arms on one clear frame inside 8 m. The scare must
	# still happen; it must simply not gate anything.
	var table := _level.get_node_or_null("InvertedTable_Archive") as Node3D
	_p.call("ai_look_at", table.global_position + Vector3(0, 0.6, 0))
	_stage = 81
	_wait = 20


func _shard_watched() -> void:
	var table := _level.get_node_or_null("InvertedTable_Archive")
	var shard = _level.call("shard")
	_ok("looking at the table arms it", bool(table.get("armed")))
	_ok("CONTROL: and while it is WATCHED nothing about it has changed",
		not bool(table.get("spent")) and bool(shard.call("is_freed")))
	_p.call("ai_look_at", Vector3(-1.0, 1.3, 19.0))   # turn away, still in the Archive
	_stage = 82
	_wait = 12


func _shard_freed() -> void:
	var table := _level.get_node_or_null("InvertedTable_Archive")
	var shard = _level.call("shard")
	_ok("looking away STILL re-poses the table — the P11 scare survives", bool(table.get("spent")))
	_ok("…and the shard did not move with it: the beat gates nothing now",
		shard.global_position.distance_to(Vector3(-3.4, 0.42, 22.0)) < 0.05,
		str(shard.global_position))
	# …and it is takeable through the real ray.
	_p.global_position = Vector3(-3.4, 0.1, 20.9)
	_p.force_update_transform()
	_p.call("ai_look_at", shard.global_position)
	_p.get_node("Camera3D").force_update_transform()
	var t: Node = _p.call("ai_interact_target")
	_ok("the shard is reachable by the ray from the basin's own approach",
		t == shard, "ray hit %s" % (t.name if t else "nothing"))
	_p.call("ai_interact")
	_ok("…and E takes it", bool(_level.call("has_shard")))
	_level.set("_shard_taken", false)
	_level.call("_update_carried")

	# ── the Ward: the SHUT box is what the ray finds on the slat's approach ───────────────
	var slat := _level.get_node_or_null("Anchor_slat") as Node3D
	var box = _level.call("ward_box")
	_p.global_position = SLAT_STANCE
	_p.force_update_transform()
	_p.call("ai_look_at", slat.global_position)
	_p.get_node("Camera3D").force_update_transform()
	var st: Node = _p.call("ai_interact_target")
	# ⚠️ Defence in depth, and this is the HALF THAT IS PHYSICAL: the shut lid's collider stops
	# a descending ray before it reaches the slat inside. The refusal on the slat itself (see
	# `_pass6_checks`) is the half that survives a grazing angle (Issue 242).
	_ok("CONTROL: with the box shut the ray finds the BOX, and it explains itself",
		st == box and String(st.call("prompt_text")) == "The box is sealed.",
		"ray hit %s" % (st.name if st else "nothing"))

	# ── and the gurney answers the touch under the player's eyes ──────────────────────────
	var ward := _level.get_node_or_null("WardFragment") as Node3D
	var hang := ward.get_node("HangingGurney/GurneyHang") as Node3D
	_hang_y0 = hang.position.y
	_hang_yaw0 = hang.rotation.y
	_p.global_position = Vector3(-2.6, 0.1, 12.2)
	_p.force_update_transform()
	_p.call("ai_look_at", ward.global_position)
	_p.get_node("Camera3D").force_update_transform()
	var wt: Node = _p.call("ai_interact_target")
	_ok("the gurney is what the ray finds from in front of it",
		wt == ward, "ray hit %s" % (wt.name if wt else "nothing"))
	_shard_panic = float(_p.call("get_panic_ratio"))
	_p.call("ai_interact")
	_ok("E arms the Ward's answer", bool(ward.get("armed")))
	_ok("…and the SAME press opens the box, in view across the room",
		bool(_level.call("ward_box_open")) and bool(box.call("is_open")))
	_stage = 83
	_wait = 90          # past the 0.4 s receipt tween AND the 0.18 + 0.8 s lid


# ⚠️ FROM THE NORTH, and that is measured. The gurney's touch volume sits at y 1.25..1.85 over
# z 13.08..13.53 — a ray from the SOUTH to a slat now lying at z 14.56 passes straight through
# it and the ray takes the nearest hit, so the approach had to move to the other side of the
# box. From (-2.6, 15.9) the ray clears the box's north wall top (y 0.42) by 7 cm — and six
# swept stances between 1.5 m and 2.2 m all reach it, which the first, deeper box did not.
const SLAT_STANCE := Vector3(-2.6, 0.1, 15.9)


func _gurney_moved() -> void:
	var ward := _level.get_node_or_null("WardFragment") as Node3D
	var hang := ward.get_node("HangingGurney/GurneyHang") as Node3D
	var box = _level.call("ward_box")
	var slat := _level.get_node_or_null("Anchor_slat") as Node3D
	# ⭐ THE RECEIPT (Issue 243). Two playtests in a row called this touch "nothing happens",
	# because the only answer was five metres away and off-screen. The thing you touch moves.
	_ok("…and the gurney DROPS 0.10 m under the player's own eyes",
		absf((_hang_y0 - hang.position.y) - 0.10) < 0.005,
		"%.3f m" % (_hang_y0 - hang.position.y))
	_ok("…and yaws 6 degrees with it",
		absf(rad_to_deg(hang.rotation.y - _hang_yaw0) - 6.0) < 0.5,
		"%.2f deg" % rad_to_deg(hang.rotation.y - _hang_yaw0))
	_ok("…with a grind at the gurney itself, not across the room",
		ward.get_node_or_null("GurneyGrind") != null)
	# ⭐ pass 6: and the box, 1.2 m away, has ground its lid all the way back IN VIEW.
	_ok("the box's lid has swung fully open, with its own grind at the box",
		absf(float(box.call("lid_angle")) + 2.1) < 0.02
		and (box as Node3D).get_node_or_null("WardBoxGrind") != null,
		"%.3f rad" % float(box.call("lid_angle")))
	_ok("…and the box goes INERT, so the prompt now belongs to what is inside it",
		not bool(box.call("can_interact")))
	_ok("…and the slat stops refusing", not bool(slat.call("is_sealed")))
	_p.global_position = SLAT_STANCE
	_p.force_update_transform()
	_p.call("ai_look_at", slat.global_position)
	_p.get_node("Camera3D").force_update_transform()
	var st: Node = _p.call("ai_interact_target")
	_ok("the bed slat is what the ray finds now, from the same stance that found the box",
		st == slat or (slat != null and st != null and slat.is_ancestor_of(st)),
		"ray hit %s" % (st.name if st else "nothing"))
	_p.call("ai_interact")
	_ok("…and E takes it", String(_level.call("carried_anchor")) == "slat",
		"carrying '%s'" % _level.call("carried_anchor"))
	_level.call("consume_anchor", "slat")
	_ok("the whole box beat costs ZERO panic",
		absf(float(_p.call("get_panic_ratio")) - _shard_panic) < 0.001,
		"%.4f -> %.4f" % [_shard_panic, float(_p.call("get_panic_ratio"))])
	_twist_gate()
	_stage = 84
	# ⚠️ ONE FRAME. `move_aside_instantly()` queue_frees the plate, which lands at the END of the
	# frame — a ray fired in the same frame still finds it (the pass-3 lesson, twice over).
	_wait = 2


# ⭐ THE GRAZING STANCE (Issue 242). The plate is a 6 cm-deep blocker on the same wall as the
# page it covers, and the page sits 0.34 m off the line a player walks up that wall — so there is
# a band of stances from which the interact ray passes the plate's edge and reaches the note's
# collider. The 23:33 run read the level's win condition from inside that band with the whole
# far-wing chain skipped.
#
# ⚠️ THIS SWEEPS THE BAND AND ASSERTS IT IS NOT EMPTY. A control that cannot reach the note
# proves nothing about a gate on the note: if the geometry ever changes so that the plate really
# does block every angle, this goes RED and says so, which is the right answer — it would mean
# the test had stopped testing. (Measured 2026-09-20: it is not empty at either plate size. The
# ray slips past the 0.90 m plate's z edge from z 22.2 by 2 cm. A blocker guards one angle.)
func _twist_gate() -> void:
	print("--- the twist note's gate, from the wall ---")
	var note: Node3D = _level.call("twist_note")
	var gs := root.get_node("GameState")
	var ui := root.get_node("NoteUI")
	var reached := 0
	var opened := 0
	var stances: Array = []
	_p.set("ai_active", true)
	_p.set("ai_move_dir", Vector2.ZERO)
	for i in range(13):
		var z: float = 21.6 + 0.1 * float(i)
		_p.global_position = Vector3(-17.5, 0.1, z)
		_p.force_update_transform()
		_p.call("ai_look_at", note.global_position)
		_p.get_node("Camera3D").force_update_transform()
		var t: Node = _p.call("ai_interact_target")
		if t != note:
			continue
		reached += 1
		stances.append("%.1f" % z)
		_p.call("ai_interact")
		if bool(ui.get("is_open")) or bool(gs.get("twist_read")):
			opened += 1
			if bool(ui.get("is_open")):
				ui.call("_close")
	_ok("the grazing band is REAL: the ray reaches the page past the plate from %d stance(s)"
		% reached, reached > 0, "z = " + ", ".join(stances))
	_ok("…and from every one of them E opens NOTHING while the stone stands",
		opened == 0 and not bool(gs.get("twist_read")), "%d opened" % opened)
	# Face-on, the plate is still a blocker — that half has not regressed.
	_p.global_position = Vector3(-16.4, 0.1, 24.5)
	_p.force_update_transform()
	_p.call("ai_look_at", note.global_position)
	_p.get_node("Camera3D").force_update_transform()
	var f: Node = _p.call("ai_interact_target")
	_ok("face-on, the stone is what the ray finds",
		f != null and String(f.name) == "SanctumPlate",
		"ray hit %s" % (f.name if f else "nothing"))
	# ── and the gate opens exactly when the stone moves, through the level's own path ──
	_level.call("_unseal_sanctum_instantly")
	_ok("moving the stone clears the gate", not bool(_level.call("plate_stands"))
		and String(note.call("prompt_text")) == "E — Read the page.",
		"'%s'" % note.call("prompt_text"))


func _twist_opened() -> void:
	var note: Node3D = _level.call("twist_note")
	var gs := root.get_node("GameState")
	var ui := root.get_node("NoteUI")
	_ok("…and the stone is physically gone a frame later",
		_level.get_node_or_null("SanctumPlate") == null)
	_p.global_position = Vector3(-16.4, 0.1, 24.5)
	_p.force_update_transform()
	_p.call("ai_look_at", note.global_position)
	_p.get_node("Camera3D").force_update_transform()
	var g: Node = _p.call("ai_interact_target")
	_ok("…and the page is what the ray finds now", g == note,
		"ray hit %s" % (g.name if g else "nothing"))
	_p.call("ai_interact")
	_ok("…and E finally opens it", bool(ui.get("is_open")) and bool(gs.get("twist_read")))
	ui.call("_close")
	gs.set("twist_read", false)
	_room_begin()


# ═══════════════════════════════════════════════════════════════════════════════════════
# ⭐ PASS 8 (2026-09-23) — the answer's order, the drawers that shut, and the cradle's fire.
# ═══════════════════════════════════════════════════════════════════════════════════════

# ⚠️ THIS IS THE GUARD THAT WOULD HAVE CAUGHT THE PASS-4 MISTAKE, AND IT IS BUILT SO THAT IT
# COULD FAIL. The recurring room's answer is "the order you met the five things", and from pass 4
# to pass 7 it was `shards, frame, table, chairs, stair` while the stair stood in HALL1 — the
# second room on the only path out of the Threshold. The 23:10 playtester photographed it.
#
# So this reads the five SOURCE PROPS' real world positions out of the live level, locates each
# one inside `level_3.gd:ROOMS` by rect, and asserts `ANSWER` is those five ids sorted by the
# room's index in that table. `ROOMS` is itself in walk order — Threshold, Hall1, PocketA, Ward,
# Archive, LoopIn, … — so the ordering key is the level's own structure and not a second copy of
# the answer written in the test.
#
# ⚠️ IT IS DELIBERATELY NOT A z-SORT. LoopIn's fused chairs stand at z 16.87, NORTH of the
# Archive's inverted table at z 22.0: the Archive is a dead end you walk into and back out of
# before the loop, so a guard keyed on z would demand `shards, stair, frame, chairs, table` and
# be green on a wrong answer. The room index is the honest key and the z values are printed
# beside it so a reader can see why they disagree.
func _pass8_answer_order() -> void:
	print("--- pass 8: the answer is the level's own order ---")
	var hall: Node = _level.call("frame_hall")
	if hall == null:
		_ok("the recurring room exists", false)
		return
	var answer: Array = hall.call("answer_order")
	var dioramas: Dictionary = hall.get_script().get_script_constant_map()["DIORAMAS"]
	var rooms: Array = _level.get_script().get_script_constant_map()["ROOMS"]
	# id -> the node in the level that the diorama is a memory OF.
	var sources := {
		"shards": "HungShards_Threshold",
		"stair": "CeilingStair_Hall1",
		"frame": "FoldedFrame_Ward_R",
		"table": "InvertedTable_Archive",
		"chairs": "FusedChairs_LoopIn",
	}
	_ok("every diorama in the room has a source prop named for this guard",
		sources.size() == answer.size() and sources.size() == dioramas.size(),
		"%d sources / %d answer / %d dioramas" % [sources.size(), answer.size(), dioramas.size()])
	var keyed: Array = []     # [room index, id]
	var zs: Array = []
	var located := 0
	for id in sources:
		var node := _level.get_node_or_null(String(sources[id])) as Node3D
		if node == null:
			_ok("the source prop '%s' for diorama '%s' is in the level" % [sources[id], id], false)
			continue
		var at: Vector3 = node.global_position
		var idx := -1
		var hits := 0
		var room_name := ""
		for i in range(rooms.size()):
			var r: Dictionary = rooms[i]
			var pos: Vector2 = r["pos"]
			var size: Vector2 = r["size"]
			var rect := Rect2(pos - size * 0.5, size)
			if rect.has_point(Vector2(at.x, at.z)):
				hits += 1
				if idx < 0:
					idx = i
					room_name = String(r["name"])
		_ok("'%s' (%s) stands in exactly one room of the level's table: %s at z %.2f"
			% [id, sources[id], room_name, at.z], hits == 1, "%d rooms contain it" % hits)
		# …and it is the room the DIORAMAS table claims, which is what the player is asked to
		# remember. A diorama labelled for a room its source is not in is the same bug wearing
		# a different hat.
		_ok("…and that is the room its diorama names (%s)"
			% String((dioramas[id] as Dictionary)["room"]),
			room_name == String((dioramas[id] as Dictionary)["room"]),
			"%s vs %s" % [room_name, (dioramas[id] as Dictionary)["room"]])
		if idx >= 0:
			keyed.append([idx, String(id)])
			zs.append("%s z %.2f (room #%d)" % [id, at.z, idx])
			located += 1
	_ok("all five source props were located (sample size, not a silent zero)", located == 5,
		"%d located" % located)
	keyed.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var want: Array = []
	for k in keyed:
		want.append(String(k[1]))
	# ⚠️ `==` on Arrays in GDScript is ELEMENT-WISE (Issue 262 learned this the hard way), so
	# this really does compare the orders and not two references.
	_ok("ANSWER is the five memories in the order the level's own ROOMS table meets them",
		Array(answer) == want, "answer %s vs level order %s" % [answer, want])
	print("      source z values: " + " · ".join(zs))
	# And the explicit statement of what the correction was, so a regression names itself.
	_ok("…which puts the Hall1 stair SECOND, not fifth (the pass-4 mistake)",
		answer.size() == 5 and String(answer[1]) == "stair",
		"answer[1] = '%s'" % (answer[1] if answer.size() > 1 else "-"))


# ── the drawers shut again ───────────────────────────────────────────────────────────────
# ⭐ Capture #1 of the 23:10 run: *"You can open those brown cells but you cannot close them."*
# ⚠️ EVERY STEP GOES THROUGH THE REAL RAY AND THE REAL `ai_interact()`. A test that called
# `interact()` on the node would prove the method runs and nothing about whether a player can
# point at the thing — which is the ONLY interesting question here, because an open drawer's
# interact volume had to shrink to the handle band so the page behind it stays readable.
var _dr: Node3D = null
var _dr_page: Node3D = null
var _dr_home := Vector3.ZERO


func _drawer_cycle_begin() -> void:
	print("--- pass 8: a drawer that opens, shuts, and opens again ---")
	_dr = _level.call("page_drawer") as Node3D
	if _dr == null:
		_ok("the page's drawer exists", false)
		_drawing_begin()
		return
	_dr_page = _dr.get_node_or_null("DrawerPage") as Node3D
	_dr_home = _dr.position
	_ok("the page's drawer starts SHUT and offers the pull",
		not bool(_dr.call("is_open"))
		and String(_dr.call("prompt_text")) == "E — Pull the drawer.",
		"'%s'" % _dr.call("prompt_text"))
	_aim_at_drawer(0.0)
	var t: Node = _p.call("ai_interact_target")
	_ok("…and the ray finds it from a metre out", t == _dr,
		"ray hit %s" % (t.name if t else "nothing"))
	_p.call("ai_interact")
	_ok("E pulls it", bool(_dr.call("is_open")))
	_stage = 110
	_wait = 24          # 0.4 s: past the 0.25 s slide


func _drawer_opened() -> void:
	_ok("…and once out, it offers the CLOSE instead",
		String(_dr.call("prompt_text")) == "E — Close the drawer."
		and bool(_dr.call("can_interact")),
		"'%s'" % _dr.call("prompt_text"))
	_ok("…and it really moved 0.35 m out of the carcass",
		absf(_dr.position.z - (_dr_home.z + 0.35)) < 0.01,
		"local z %.3f, home %.3f" % [_dr.position.z, _dr_home.z])
	# ⚠️ THE PAGE FIRST, because this is the thing the shrink exists to protect. The handle band
	# stands 0.09 m PROUD of a front that is 0.10 m in front of the page; if it covered the whole
	# face the ray would stop on the drawer and the page would be unreadable (Issue 231).
	_aim_at_page()
	var t: Node = _p.call("ai_interact_target")
	_ok("the page inside is what the ray finds, PAST the open drawer's own volume",
		t == _dr_page, "ray hit %s" % (t.name if t else "nothing"))
	_p.call("ai_interact")
	var ui := root.get_node("NoteUI")
	_ok("…and E reads it", bool(ui.get("is_open")))
	if bool(ui.get("is_open")):
		ui.call("_close")
	# Now the handle. Aim 0.17 m lower — the band pass 8 shrank the volume to.
	_aim_at_drawer(-0.17)
	var h: Node = _p.call("ai_interact_target")
	_ok("…and the handle band is pointable from the same metre out", h == _dr,
		"ray hit %s" % (h.name if h else "nothing"))
	_p.call("ai_interact")
	_ok("E on the handle shuts it", not bool(_dr.call("is_open")))
	_stage = 111
	_wait = 24


func _drawer_closed() -> void:
	_ok("the drawer is home again", _dr.position.distance_to(_dr_home) < 0.01,
		"local z %.3f vs home %.3f" % [_dr.position.z, _dr_home.z])
	_ok("…and its prompt is the pull once more",
		String(_dr.call("prompt_text")) == "E — Pull the drawer.",
		"'%s'" % _dr.call("prompt_text"))
	# ⚠️ THE PAGE WENT IN WITH IT. It is a CHILD of the drawer body, so "rides inside" is a
	# claim about the world transform and is measured as one.
	_ok("…and the page rode back in with it (it is inside the carcass again)",
		_dr_page != null and _dr.is_ancestor_of(_dr_page)
		and absf(_dr_page.global_position.z - 51.915) < 0.02,
		"page z %.3f" % (_dr_page.global_position.z if _dr_page else -99.0))
	# A shut drawer is a wall in front of the page again — the Issue-231 state, restored.
	_aim_at_page()
	var t: Node = _p.call("ai_interact_target")
	_ok("…so the ray finds the FRONT again, not the page", t == _dr,
		"ray hit %s" % (t.name if t else "nothing"))
	# …and the snapshot no longer lists it.
	var snap: Dictionary = _level.call("save_progress")
	_ok("…and `drawers_opened` no longer names it",
		not (snap.get("drawers_opened", []) as Array).has("Drawer4_1"),
		str(snap.get("drawers_opened", [])))
	_aim_at_drawer(0.0)
	_p.call("ai_interact")
	_ok("E opens it a second time", bool(_dr.call("is_open")))
	_stage = 112
	_wait = 24


func _drawer_reopened() -> void:
	_aim_at_page()
	var t: Node = _p.call("ai_interact_target")
	_ok("…and after a close and a re-open the page is STILL readable through the real ray",
		t == _dr_page, "ray hit %s" % (t.name if t else "nothing"))
	_p.call("ai_interact")
	var ui := root.get_node("NoteUI")
	_ok("…and E still opens it", bool(ui.get("is_open")))
	if bool(ui.get("is_open")):
		ui.call("_close")
	var snap: Dictionary = _level.call("save_progress")
	_ok("…and the snapshot names it again (the set is the OPEN set, both ways)",
		(snap.get("drawers_opened", []) as Array).has("Drawer4_1"),
		str(snap.get("drawers_opened", [])))
	# ⚠️ AND THE RESTORE SHUTS WHAT IS NOT IN THE LIST. Without `close_instantly()` a snapshot
	# taken with a drawer pushed in would leave it standing out on the way back, because
	# `_wire_drawers()` pulls `OPEN_DRAWER` at build time on every load.
	# ⚠️ Driven through `GameState.save_level_progress(8, …)` + the level's own
	# `_restore_progress()`, which takes NO argument and reads the autoload — the real path a
	# back-door return uses. A test that invented its own entry point would not have caught it.
	var gs8 := root.get_node("GameState")
	gs8.call("save_level_progress", 8, {"drawers_opened": []})
	_level.call("_restore_progress")
	var still_open := 0
	for d in (_level.call("drawers") as Array):
		if bool(d.call("is_open")):
			still_open += 1
	_ok("restoring an EMPTY open-set shuts every one of the seventeen", still_open == 0,
		"%d of 17 still open" % still_open)
	gs8.call("save_level_progress", 8, {"drawers_opened": ["Drawer4_1"]})
	_level.call("_restore_progress")
	var reopened := 0
	for d in (_level.call("drawers") as Array):
		if bool(d.call("is_open")):
			reopened += 1
	_ok("…and restoring a one-drawer set opens exactly that one, and only it",
		bool(_dr.call("is_open")) and reopened == 1, "%d open" % reopened)
	# …and leave the level as the rest of this file expects to find it.
	gs8.call("save_level_progress", 8, {})
	_drawing_begin()


# A metre out from the drawer's front face, aiming at a point `dy` above its centre.
func _aim_at_drawer(dy: float) -> void:
	_p.set("ai_active", true)
	_p.set("ai_move_dir", Vector2.ZERO)
	var aim: Vector3 = _dr.to_global(Vector3(0, dy, 0.12))
	var stand: Vector3 = aim + _dr.global_transform.basis.z * 1.0
	_p.global_position = Vector3(stand.x, 0.1, stand.z)
	_p.force_update_transform()
	_p.call("ai_look_at", aim)
	_p.get_node("Camera3D").force_update_transform()


func _aim_at_page() -> void:
	_p.set("ai_active", true)
	_p.set("ai_move_dir", Vector2.ZERO)
	var aim: Vector3 = _dr_page.global_position
	var stand: Vector3 = aim + _dr.global_transform.basis.z * 1.0
	_p.global_position = Vector3(stand.x, 0.1, stand.z)
	_p.force_update_transform()
	_p.call("ai_look_at", aim)
	_p.get_node("Camera3D").force_update_transform()


# ── the fire's own three samples ─────────────────────────────────────────────────────────
# ⚠️ THREE, AND THE MIDDLE ONE IS THE CLAIM. "A fire appeared" would be true of a beat that put
# the figure up in the same frame; what capture #3 asked for is *fire for like 3 seconds and
# THEN this face appears from fire*, so the guard has to prove the fire is alone for those three
# seconds and that the figure arrives after them. 96 is t = 1.5 s (the ramp is done), 97 is
# t = 2.7 s (the fire is full size, still alone), 98 is mid-rise.
var _cradle_fire_node: Node = null
var _fire_e15 := 0.0
var _fire_h15 := 0.0
var _rise_y0 := 0.0


func _cradle_fire_ramped() -> void:
	var fire: Node = _level.get_node_or_null("CradleFire")
	var lamp: OmniLight3D = _level.call("cradle_light")
	_ok("the fire is the SAME node it was at 0.5 s — one fire, not a re-light per frame",
		fire != null and fire == _cradle_fire_node)
	_fire_e15 = float(fire.call("light_energy")) if fire else -1.0
	_ok("by t = 1.5 s its light has ramped to >= 0.7 (0 -> 0.9 over the first second)",
		_fire_e15 >= 0.7, "%.3f" % _fire_e15)
	_ok("…and the ramp really was a ramp: it was under 0.75 at 0.5 s and is over 0.7 now",
		_fire_e15 > 0.05)
	_ok("…on an orange light, not the violet lamp pass 7 used",
		lamp != null and lamp.light_color.r > 0.9 and lamp.light_color.b < 0.35,
		str(lamp.light_color) if lamp else "missing")
	# The flames themselves: six billboarded additive quads, none of them emissive over 1.0.
	var qs: Array = fire.call("quads") if fire else []
	_ok("…and there are six flame quads, all of them unshaded, additive and billboarded",
		qs.size() == 6 and _flames_are_additive(qs), "%d quads" % qs.size())
	_fire_h15 = _tallest_flame(qs)
	_ok("…still GROWING at 1.5 s (the tallest quad is under its full height)",
		_fire_h15 > 0.05 and _fire_h15 < 0.90, "tallest %.3f m" % _fire_h15)
	_ok("…and still nothing has risen out of it",
		_level.get_node_or_null("CradleFigure") == null)
	# ⚠️ THE CRACKLE, ASSERTED BY NAME AND BY GAIN. `GameState.AUDIO_SUBDIRS` is a HARDCODED list
	# and a base name that does not resolve fails SILENTLY — the beat would simply be a fire with
	# no sound and nothing would say so. -4.9 dB is arithmetic: -19.7 dBFS RMS placed 8.0 dB over
	# `room_hum`'s delivered -32.55 dBFS.
	var fl := fire.get_node_or_null("CradleFireLoop") as AudioStreamPlayer3D if fire else null
	_ok("…and `cradle_fire` is looping at the cradle at -4.9 dB on Ambience",
		fl != null and fl.stream != null
		and String(fl.stream.resource_path).find("cradle_fire") >= 0
		and absf(fl.volume_db + 4.9) < 0.01 and fl.bus == AudioBuses.AMBIENCE and fl.playing,
		"%s %.1f dB bus %s playing %s" % [fl.stream.resource_path if fl and fl.stream else "-",
			fl.volume_db if fl else 0.0, fl.bus if fl else "-", fl.playing if fl else false])
	_ok("…and it is looped IN CODE, since every .wav.import here is loop_mode=0",
		fl != null and fl.is_connected("finished", Callable(fl, "play")))
	_ok("the fire's first 1.5 s cost ZERO panic",
		absf(float(_p.call("get_panic_ratio")) - _shadow_panic) < 0.001,
		"%.4f -> %.4f" % [_shadow_panic, float(_p.call("get_panic_ratio"))])
	_stage = 97
	_wait = 72          # t = 2.7 s


func _cradle_fire_peak() -> void:
	var fire: Node = _level.get_node_or_null("CradleFire")
	var qs: Array = fire.call("quads") if fire else []
	var tall := _tallest_flame(qs)
	_ok("by t = 2.7 s the fire is at full size — taller than it was at 1.5 s",
		tall > _fire_h15, "%.3f m -> %.3f m" % [_fire_h15, tall])
	_ok("…and it fills the crib: the tallest flame clears the cradle's rim",
		_flame_top(fire, qs) > (_level.call("cradle_bbox") as AABB).position.y
			+ (_level.call("cradle_bbox") as AABB).size.y,
		"top y %.3f vs rim %.3f" % [_flame_top(fire, qs),
			(_level.call("cradle_bbox") as AABB).position.y
			+ (_level.call("cradle_bbox") as AABB).size.y])
	# ⚠️ THE CLAIM CAPTURE 3 MADE: three seconds of fire, and THEN the face.
	_ok("…and after 2.7 s of fire there is STILL no figure — the face comes after the fire",
		_level.get_node_or_null("CradleFigure") == null)
	_ok("…and the snarl has not fired either", _level.get_node_or_null("CradleSnarl") == null
		or not bool((_level.get_node("CradleSnarl") as AudioStreamPlayer3D).playing))
	_stage = 98
	_wait = 21          # t = 3.05 s: a third of the way up


func _cradle_rising() -> void:
	var fig := _level.get_node_or_null("CradleFigure") as Node3D
	var box: AABB = _level.call("cradle_bbox")
	_ok("the figure is in the world now, one frame or two into the rise", fig != null)
	if fig == null:
		_stage = 93
		_wait = 75
		return
	_rise_y0 = fig.global_position.y
	var home_y: float = box.position.y + box.size.y - 2.12    # rim - MASK_Y
	_ok("…and it is BELOW its final pose: it is coming up through the flames",
		_rise_y0 < home_y - 0.05,
		"y %.3f vs home %.3f" % [_rise_y0, home_y])
	_ok("…and the level's own rise counter agrees it is part way up",
		float(fig.call("rise_progress")) > 0.0 and float(fig.call("rise_progress")) < 1.0,
		"%.3f" % float(fig.call("rise_progress")))
	_ok("…and the snarl went with the rise, not with the fire",
		_level.get_node_or_null("CradleSnarl") != null
		and bool((_level.get_node("CradleSnarl") as AudioStreamPlayer3D).playing))
	_ok("the rise costs ZERO panic too",
		absf(float(_p.call("get_panic_ratio")) - _shadow_panic) < 0.001,
		"%.4f -> %.4f" % [_shadow_panic, float(_p.call("get_panic_ratio"))])
	_stage = 93
	_wait = 66          # t = 4.15 s: risen, holding


# Every flame quad must be UNSHADED + ADD + billboarded, and its albedo must stay inside the
# clamp (Issue 21). Unshaded output IS albedo, so that is where the ceiling has to be read.
func _flames_are_additive(qs: Array) -> bool:
	if qs.is_empty():
		return false
	for q in qs:
		var m := (q as MeshInstance3D).get_surface_override_material(0) as StandardMaterial3D
		if m == null:
			return false
		if m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
			return false
		if m.blend_mode != BaseMaterial3D.BLEND_MODE_ADD:
			return false
		if m.billboard_mode != BaseMaterial3D.BILLBOARD_ENABLED or not m.billboard_keep_scale:
			return false
		if m.albedo_texture == null:
			return false
		if m.albedo_color.r > 1.0 or m.albedo_color.g > 1.0 or m.albedo_color.b > 1.0:
			return false
		if m.emission_enabled and m.emission_energy_multiplier > 1.0:
			return false
	return true


func _tallest_flame(qs: Array) -> float:
	var out := 0.0
	for q in qs:
		var qm := (q as MeshInstance3D).mesh as QuadMesh
		if qm:
			out = maxf(out, qm.size.y)
	return out


func _flame_top(fire: Node, qs: Array) -> float:
	var out := -99.0
	for q in qs:
		var mi := q as MeshInstance3D
		var qm := mi.mesh as QuadMesh
		if qm:
			out = maxf(out, mi.global_position.y + qm.size.y * 0.5)
	return out
