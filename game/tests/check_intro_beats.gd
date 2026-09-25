extends SceneTree

# The Intro Room's dread beats — and, above all, that it is still UNLOSEABLE.
#
# This room shipped with literally zero scares: no panic source, no RandomAmbient, no
# ApparitionDirector, no objective line — 60-120 s of nothing. "The ward is occupied"
# (2026-07-28) fills it with dread only, and the hard constraint agreed with the user is
# that **nothing here may ever raise panic**. That is what this test defends: it samples
# panic at every beat, including through the jolt, and fails if it moves at all.
#
# It also pins the beats themselves, because each one is a thing a future edit could
# silently delete without breaking anything else:
#   * two occupied gurneys, and NOT the one the player spawns on
#   * the first switch press glimpses a tube that actually reaches an occupied bed
#   * the tube over the table stays dead, AND THE CANDLE IS LIT, so the note is lit by the
#     candle alone — ⚠️ this used to assert only the dead tube, i.e. only the absence half
#     of its own sentence, and the candle was in fact invisible and emitting nothing for the
#     entire life of the procedurally-rebuilt room (2026-08-16)
#   * one of the two covered beds is EMPTY once the lights are on
#   * the wheelchair turns from the line the player actually walks, with margin
#   * the breathing is gone once the lights are on
#
# ⭐ 2026-09-24, THE INTAKE WING. The ward is now the fourth room of six, and this test walks the
# three before it first, driving the level's own beats (the straps' interact(), the torch KeyItem,
# the ward door's interact()) rather than faking their state:
#   * the cell: you wake on the CELL bed; no covered body there; three straps, in order only;
#     the cell door is locked until the third, then buzzes open; the torch is locked
#   * the hall: the torch is ISSUED there, and taking it unlocks the ward door
#   * the ward door's opening blacks the wing out BEFORE the old beats begin: every bulb dead,
#     the ambient at zero, the torch taken back, the breathing and the path glow spawned
# ⚠️ The unloseable rule changed with it (the user's call, 2026-09-24): the intro has a panic
# CEILING of 0.6 (check_intro_panic_ceiling.gd) because calibration will teach panic. What this
# file asserts is that the bar stays at EXACTLY ZERO through the cell, the hall and the ward — none
# of those three may move it — and never passes the ceiling.
#
# ⚠️ TIME-based, not frame-based. Headless runs uncapped so a frame count is not a clock;
# check_audio_buses.gd reported a false failure that way before it was fixed.
#
#   Godot --headless --path game --script res://tests/check_intro_beats.gd

const WAKE_WAIT := 0.5        # the cell is built in _ready(); sample it before the tween ends
const GLIMPSE_SAMPLE := 0.22  # inside the stuck press's 0.06 up + 0.4 hold
const REVEAL_WAIT := 1.4      # _flicker_on is 0.6 s; the breath fade is 0.5 s

var _t := 0.0
var _stage := 0
var _stage_at := 0.0
var _fails: Array[String] = []
var _checks := 0
var _scene: Node = null
var _player: CharacterBody3D = null
var _switch: Node = null
var _peak_panic := 0.0
var _wc: Node3D = null
var _wc_yaw := 0.0
var _wstage := 0              # the wing's own sub-stages, before the old ward stages
var _cstage := 0              # calibration + airlock sub-stages, after the old ward stages
var _in_calib := false        # _peak_panic stops at the calibration door; _peak_all never does
var _peak_all := 0.0
var _screamed := false
var _vo3_checked := false


func _initialize() -> void:
	change_scene_to_file("res://scenes/intro_room.tscn")


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _ceiling_lights() -> Array:
	var out: Array = []
	for c in _scene.get_children():
		# begins_with, not ==: the tubes are CeilingLight_0/1/2 (unique names, Issue 17).
		if c is OmniLight3D and String(c.name).begins_with("CeilingLight"):
			out.append(c)
	return out


func _sheets() -> Array:
	var out: Array = []
	for c in _scene.get_children():
		# One node per covered body: the form is built from parts under a single Node3D
		# (see intro_room.gd:_build_sheeted_form), so this counts BODIES, not boxes.
		if String(c.name).begins_with("SheetedForm_"):
			out.append(c)
	return out


func _advance(next: int) -> void:
	_stage = next
	_stage_at = _t


func el_w() -> float:
	return _t - _stage_at


func _consts() -> Dictionary:
	return _scene.get_script().get_script_constant_map()


# The wing, stage by stage. Returns true once it is done and the old ward stages may run.
func _wing(delta: float) -> bool:
	match _wstage:
		0:
			_scene = current_scene
			if _t < WAKE_WAIT:
				return false
			_player = _scene.get_node_or_null("Player") as CharacterBody3D
			_ok("player found", _player != null)
			if _player == null:
				quit(1)
				return false
			var c := _consts()
			var cell_bed: Vector3 = c["CELL_GURNEY_POS"]
			var p := _player.global_position
			_ok("you wake on the CELL bed", Vector2(p.x, p.z).distance_to(Vector2(cell_bed.x, cell_bed.z)) < 0.8,
				"at %v" % p)
			var nearest := 999.0
			for sh in _sheets():
				var sp: Vector3 = (sh as Node3D).position
				nearest = minf(nearest, Vector2(sp.x, sp.z).distance_to(Vector2(cell_bed.x, cell_bed.z)))
			_ok("no covered body on the bed you wake on", nearest > 2.0, "nearest %.2f m" % nearest)
			_ok("and nobody else in it yet (the occupant is the hall's beat)",
				_scene.get_node_or_null("CellOccupant") == null)
			_ok("the breathing waits for the ward (it spawns on the blackout)",
				_scene.get_node_or_null("FarBreath") == null)
			# ⭐ Third hand playtest (2026-09-25): NO BUCKLING. The restraints are scenery, already open.
			_ok("the bed has its three restraints", _scene.get_node_or_null("Strap_2") != null
				and _scene.get_node_or_null("Strap_3") == null)
			var hung := 0
			var interactive := 0
			for i in 3:
				var st: Node = _scene.get_node("Strap_%d" % i)
				for n in [st] + st.find_children("*", "", true, false):
					if n.has_method("interact") or n is CollisionObject3D:
						interactive += 1
				for pv in (_scene.get("_strap_visuals") as Array)[i]:
					if absf((pv[0] as Node3D).rotation.z) > 3.0:
						hung += 1
			_ok("…already UNBUCKLED — all four loose ends hang off the bed", hung == 4, "%d hung" % hung)
			_ok("…and NOT interactable (no interact(), no body for the ray)", interactive == 0,
				"%d interactive nodes" % interactive)
			_ok("no legs sheet — nothing looks down your own body", _scene.get_node_or_null("CellLegsSheet") == null)
			var cam0 := _player.get_node("Camera3D") as Camera3D
			_ok("you come to LYING on the pillow", cam0.position.y < 0.4 and cam0.global_position.y < 1.0,
				"eye %.2f over the body, %.2f in the world" % [cam0.position.y, cam0.global_position.y])
			var door: Node = _scene.get_node_or_null("CellDoor")
			_ok("the cell door exists and is LOCKED", door != null and door.get("locked") == true)
			_ok("the torch is locked in the cell", _player.get("_flashlight_locked") == true)
			_ok("the player is frozen through the wake-up", _player.is_input_frozen())
			_wstage = 1
		1:
			# WAKEUP_TWEEN_TIME + SIT_UP_TIME + STAND_TIME = 3.3 s.
			if _t < 3.7:
				return false
			var c1 := _consts()
			var cam := _player.get_node("Camera3D") as Camera3D
			var stand: Vector3 = c1["CELL_STAND_POS"]
			_ok("~3 s later you are STANDING beside the bed — the eye at 1.65, input free",
				absf(cam.position.y - float(c1["STANDING_EYE"])) < 0.02 and not _player.is_input_frozen()
					and Vector2(_player.global_position.x, _player.global_position.z).distance_to(Vector2(stand.x, stand.z)) < 0.2,
				"eye %.2f, frozen %s, at %v" % [cam.position.y, _player.is_input_frozen(), _player.global_position])
			_ok("VO1 spoke as you stood", _has_caption("Good morning, forty-six— forty-seven."))
			_ok("…and the door has not released yet (it waits for the line)",
				_scene.get_node("CellDoor").call("is_open") == false)
			_ok("no E was pressed, and none is wanted: the restraints are not under the ray",
				_player.ai_interact_target() == null or not String(_player.ai_interact_target().get_path()).contains("Strap_"))
			_stage_at = _t
			_wstage = 2
		2:
			if _scene.get_node("CellDoor").call("is_open") == true:
				_ok("when VO1 ends the cell door releases and swings open — with no input", el_w() > 2.0,
					"%.1f s after you stood" % el_w())
				_ok("still ZERO panic", is_zero_approx(_peak_panic))
				_ok("the ward door is locked until the torch is taken",
					_scene.get_node("WardEntryDoor").get("locked") == true)
				# The hall. (Its glimpse is check_intro_glimpse.gd's.)
				_player.global_position = Vector3(-7.0, 0.05, 16.5)
				_stage_at = _t
				_wstage = 5
			elif _t - _stage_at > 10.0:
				_ok("when VO1 ends the cell door releases and swings open — with no input", false)
				quit(1)
				return false
		5:
			if _t - _stage_at < 0.4:
				return false
			var torch: Node = _scene.get_node_or_null("IssuedTorch")
			_ok("the torch is on its tray in the hall", torch != null)
			if torch:
				torch.call("interact")
			_ok("taking it unlocks the torch", _player.get("_flashlight_locked") == false)
			_ok("…and the ward door", _scene.get_node("WardEntryDoor").get("locked") == false)
			var lit := 0
			for b in _scene.get("_bulbs"):
				if (b[0] as Light3D).light_energy > 0.05:
					lit += 1
			_ok("the wing's bulbs are burning before the ward door opens", lit >= 7, "%d lit" % lit)
			_player.global_position = Vector3(-3.0, 0.05, 10.3)
			_scene.get_node("WardEntryDoor").call("interact")
			_stage_at = _t
			_wstage = 6
		6:
			if _t - _stage_at < 0.3:
				return false
			var lit := 0
			for b in _scene.get("_bulbs"):
				if (b[0] as Light3D).light_energy > 0.001:
					lit += 1
			_ok("opening the ward door kills EVERY light in the wing", lit == 0, "%d still lit" % lit)
			var env: Environment = _scene.get("_env")
			_ok("…and the ambient", env != null and env.ambient_light_energy < 0.001)
			_ok("…and takes the torch back", _player.get("_flashlight_locked") == true)
			_ok("the breathing starts in the dark ward", _scene.get_node_or_null("FarBreath") != null)
			var glows: int = (_scene.get("_path_glow_lights") as Array).size()
			_ok("the path glow leads from the ward entry", glows > 0, "%d lights" % glows)
			_ok("still ZERO panic after the cell, the hall and the blackout", is_zero_approx(_peak_panic),
				"peak %.4f" % _peak_panic)
			_switch = _scene.get_node_or_null("LightSwitch")
			_ok("the ward's light switch exists", _switch != null)
			if _switch == null:
				quit(1)
				return false
			return true
	return false


func _process(delta: float) -> bool:
	_t += delta
	if _player:
		if not _in_calib:
			_peak_panic = maxf(_peak_panic, _player.get_panic_ratio())
		_peak_all = maxf(_peak_all, _player.get_panic_ratio())
		var scr := root.get_node_or_null("Screamer")
		if scr and scr.get("_is_triggering") == true:
			_screamed = true

	if _stage == 0:
		if not _wing(delta):
			return false

		# --- the occupied ward -------------------------------------------------------
		var sheets := _sheets()
		_ok("two gurneys are occupied", sheets.size() == 2, "found %d" % sheets.size())
		# ⚠️ The player spawns lying on GURNEY_POS. A solid form on THAT bed would push
		# them out of the world, which is the class of bug check_spawn_blocked.gd exists
		# for — so assert the sheets keep well clear of it.
		var spawn_xz := Vector2(0.0, 7.0)   # intro_room.gd GURNEY_POS — the ward's EMPTY bed now
		var nearest := 999.0
		for s in sheets:
			var p: Vector3 = (s as Node3D).position
			nearest = minf(nearest, Vector2(p.x, p.z).distance_to(spawn_xz))
		_ok("no sheeted form on the ward's empty gurney", nearest > 2.0,
			"nearest is %.2f m away" % nearest)

		_ok("the breathing at the far wall is playing",
			_scene.get_node_or_null("FarBreath") != null)
		var lights := _ceiling_lights()
		_ok("three ceiling tubes exist", lights.size() == 3, "found %d" % lights.size())
		var all_dark := true
		for l in lights:
			if (l as OmniLight3D).light_energy > 0.001:
				all_dark = false
		_ok("every tube is dark before the switch", all_dark)

		# --- NO jumpscare in this room ------------------------------------------------
		# The user cut the mid-fumble nightmare flash on the first playtest (2026-07-28).
		# Asserted as an absence so it cannot quietly come back: the cold open already
		# spends that image, and this is the one room with no fail state.
		_ok("there is NO jumpscare volume in the intro",
			_scene.get_node_or_null("FumbleJolt") == null)
		_advance(1)

	elif _stage == 1 and _t - _stage_at > 0.8:
		_ok("nothing has cost panic so far", is_zero_approx(_peak_panic),
			"peak %.3f" % _peak_panic)

		# --- the switch sticks --------------------------------------------------------
		_switch.call("interact")
		_advance(2)

	elif _stage == 2 and _t - _stage_at > GLIMPSE_SAMPLE:
		# One tube — the far one, furthest from the gurney — is briefly alight.
		var lit := 0
		var lit_z := 0.0
		for l in _ceiling_lights():
			if (l as OmniLight3D).light_energy > 0.05:
				lit += 1
				lit_z = (l as OmniLight3D).position.z
		_ok("the stuck press glimpses exactly one tube", lit == 1, "%d lit" % lit)
		# ⚠️ REPLACES "and it is the FAR end of the ward" (2026-08-16). That assertion was
		# true and useless: the far tube is at z=-6 with omni_range 9, and both occupied
		# beds sat at z=+5..+6, eleven metres away — so the best beat in the room lit bare
		# floor and could not show a single covered body. What matters is not WHICH tube it
		# is, it is whether the flash reaches something worth seeing.
		var reach := 0.0
		var nearest_bed := 999.0
		for l in _ceiling_lights():
			if (l as OmniLight3D).light_energy > 0.05:
				reach = (l as OmniLight3D).omni_range
				for s in _sheets():
					nearest_bed = minf(nearest_bed,
						(s as Node3D).global_position.distance_to((l as OmniLight3D).global_position))
		_ok("and its light actually reaches an occupied bed", nearest_bed < reach,
			"nearest covered body is %.2f m from the lit tube (z=%.1f), range %.1f"
				% [nearest_bed, lit_z, reach])
		_advance(3)

	elif _stage == 3 and _t - _stage_at > 0.9:
		# The glimpse must go away again — a stuck press that left the room dimly lit
		# would rob the real reveal of its contrast.
		var still_lit := 0
		for l in _ceiling_lights():
			if (l as OmniLight3D).light_energy > 0.001:
				still_lit += 1
		_ok("the glimpse fades back to full dark", still_lit == 0,
			"%d still lit" % still_lit)

		# --- the real reveal ----------------------------------------------------------
		_switch.call("interact")
		_advance(4)

	elif _stage == 4 and _t - _stage_at > REVEAL_WAIT:
		var dead := 0
		var alive := 0
		for l in _ceiling_lights():
			if (l as OmniLight3D).light_energy > 0.1:
				alive += 1
			else:
				dead += 1
		_ok("the reveal lights the ward", alive == 2, "%d alive" % alive)
		_ok("but the tube over the table stays dead", dead == 1, "%d dead" % dead)
		_ok("the breathing is gone once the lights are on",
			_scene.get_node_or_null("FarBreath") == null)

		# --- the candle, i.e. the OTHER half of "lit by the candle alone" ----------------
		# ⚠️ `visible` is the assertion that matters. _darken_scene() hides this light for
		# the blind fumble; nothing restored it, so it tweened up to a perfectly good
		# energy on a hidden node — and a hidden Node3D light emits NOTHING. Measured
		# 2026-08-16: visible=false, energy=1.972. With the tube above the table
		# deliberately dead, the note the player is REQUIRED to read had no light on it.
		var candle: OmniLight3D = _scene.get("candle_light")
		_ok("the candle light exists", candle != null)
		if candle:
			_ok("the candle is VISIBLE after the reveal", candle.visible,
				"visible=%s" % candle.visible)
			_ok("…and is actually burning", candle.light_energy > 1.0,
				"energy %.3f" % candle.light_energy)
			# A light with no emitter is the other half of the same bug: this room had a
			# CandleLight and no candle at all, hanging 2.2 m above the table.
			var nearest_mesh := 999.0
			var who := "-"
			for c in _scene.get_children():
				if not (c is MeshInstance3D or c is CSGShape3D):
					continue
				var d: float = (c as Node3D).global_position.distance_to(candle.global_position)
				if d < nearest_mesh:
					nearest_mesh = d
					who = String(c.name)
			_ok("…and there is a real candle under it, not a bare light",
				nearest_mesh < 0.35, "nearest prop is %s at %.3f m" % [who, nearest_mesh])

		# --- one bed is empty afterwards (B2) --------------------------------------------
		# No sound, no panic, no camera move: only the count changes.
		_ok("one of the two covered beds is empty once the lights are on",
			_sheets().size() == 1, "%d covered bodies remain" % _sheets().size())

		# --- the wheelchair turns WHILE WATCHED (playtest 2026-07-28) -----------------
		# The inverse of MovedProp's rule, deliberately: the player must be close AND
		# looking, so the turn cannot be missed. Arm it, then stand in front of it.
		var wc := _scene.get_node_or_null("Wheelchair") as Node3D
		_ok("the wheelchair exists", wc != null)
		if wc:
			_wc = wc
			_wc_yaw = wc.rotation.y
			_scene.call("_arm_wheelchair")
			# Stand well back and look away: it must NOT turn yet.
			_player.global_position = wc.global_position + Vector3(0, 0.1, 8.0)
			var cam2 := _player.get_node("Camera3D") as Camera3D
			cam2.rotation.y = 0.0
			_advance(5)
			return false

		_finish()
		return true

	elif _stage == 5 and _t - _stage_at > 0.8:
		_ok("the wheelchair does not turn from across the room",
			is_equal_approx(_wc.rotation.y, _wc_yaw),
			"yaw %.3f" % _wc.rotation.y)

		# --- is the chair within reach of the route the player actually walks? ------------
		# The note is on the table at x=0 and the exit door is at x=0, so the walk from
		# reading the note to leaving runs along x=0. The chair's LATERAL offset from that
		# line is the closest the player ever gets to it without deliberately detouring.
		# ⚠️ Margin, not a knife-edge: the chair used to sit at x=3.0 against a limit of
		# 3.2, which is 0.2 m — and because the distance test was full-3D at the time, the
		# real allowance was 2.741 m of floor and the beat could not fire AT ALL.
		var limit: float = _scene.get_script().get("WHEELCHAIR_TURN_DIST")
		var lateral: float = absf(_wc.global_position.x)
		_ok("the wheelchair is within reach of the note-to-door line, with margin",
			lateral <= limit - 0.5,
			"lateral %.2f m vs limit %.2f (was 3.00)" % [lateral, limit])

		# --- and it fires at the full horizontal reach ------------------------------------
		# ⚠️ Deliberately probed at 3.0 m, NOT at the chair's own 2.4 m. 3.0 m is what the
		# old placement offered, and it is the distance that separates a horizontal test
		# from a 3D one: with the camera 1.65 m up, sqrt(3.0^2 + 1.65^2) = 3.42 > 3.2, so a
		# distance test that mixes in the vertical component fails this and only this.
		_player.global_position = _wc.global_position + Vector3(0, 0.1, 3.0)
		var cam3 := _player.get_node("Camera3D") as Camera3D
		cam3.look_at(_wc.global_position + Vector3(0, 0.5, 0), Vector3.UP)
		_advance(6)

	elif _stage == 6 and _t - _stage_at > 0.6:
		# --- the turn has a SOUND, and it is the purpose-made one ------------------------
		# ⚠️ Sampled at +0.6 s, not with the rotation at +1.8 s: the emitter fades out over
		# WHEELCHAIR_SFX_FADE_START + FADE_TIME (1.6 s) and frees itself, so a later check
		# would find nothing and could not tell "played and finished" from "never played".
		# ⚠️ The FILE is asserted, not just that something plays. `wheelchair_turn` never
		# existed and this beat fell back to `gurney_creak` for the life of the feature —
		# a fallback that works is exactly the kind of thing that hides a missing asset.
		var sfx := _scene.get_node_or_null("WheelchairTurnSfx") as AudioStreamPlayer3D
		_ok("the wheelchair turn plays a sound", sfx != null)
		if sfx:
			var src := "" if sfx.stream == null else sfx.stream.resource_path
			_ok("…and it is the purpose-made wheelchair sample, not the creak fallback",
				src.get_file().get_basename() == "wheelchair", "stream: %s" % src)
			# ⚠️ Read off the script, never a literal: the literal -7.6 sat here while the
			# constant moved to +1.0 (2026-09-10), which is exactly how a test starts asserting
			# the past. The ceiling is asserted too — Godot's default max_db 3.0 silently eats
			# any gain a near emitter is given.
			var consts: Dictionary = _scene.get_script().get_script_constant_map()
			var want_db := float(consts.get("WHEELCHAIR_SFX_DB", -999.0))
			var want_max := float(consts.get("WHEELCHAIR_SFX_MAX_DB", -999.0))
			_ok("…at the gain the level's own constant names",
				is_equal_approx(sfx.volume_db, want_db),
				"volume_db %.2f vs WHEELCHAIR_SFX_DB %.2f" % [sfx.volume_db, want_db])
			_ok("…and it is LOUD — the 2026-09-10 call, +1.0 dB on a -2.3 dBFS file",
				want_db >= 0.5, "WHEELCHAIR_SFX_DB %.2f" % want_db)
			_ok("…with a raised ceiling so the gain is not clamped away at 2.7 m",
				sfx.max_db >= 8.0 and is_equal_approx(sfx.max_db, want_max),
				"max_db %.2f" % sfx.max_db)
		_advance(7)

	elif _stage == 7 and _t - _stage_at > 1.4:
		_ok("it DOES turn at the full horizontal reach (3.0 m of floor, eye 1.65 m up)",
			absf(_wc.rotation.y - _wc_yaw) > deg_to_rad(25.0),
			"turned %.1f degrees" % rad_to_deg(_wc.rotation.y - _wc_yaw))
		_ok("…and the whole wheelchair beat still cost ZERO panic",
			is_zero_approx(_peak_panic), "peak %.4f" % _peak_panic)
		_advance(8)

	elif _stage == 8:
		if _calibration(delta):
			_finish()
			return true

	if _t > 150.0:
		print("RESULT: FAIL — timed out at stage %d" % _stage)
		quit(1)
		return true
	return false


func _captions() -> Array:
	return _scene.get("_captions") as Array


func _has_caption(text: String) -> bool:
	return _captions().has(text)


# ⭐ CALIBRATION + THE AIRLOCK (phase 5). Gaze through the REAL camera (ai_look_at; the player's
# own _handle_gaze raycast and _update_panic do the rest), the sprint on the SHIPPING movement path
# (ai_move_dir + ai_sprint), the tray and every door through the real interact ray.
func _look(at: Vector3) -> void:
	# ⚠️ The wheelchair stages above aim the CAMERA itself (cam.look_at), which leaves a yaw on the
	# camera node that ai_look_at (body yaw + camera pitch) never clears — the gaze ray then points
	# somewhere else entirely. Zero it first.
	var cam := _player.get_node("Camera3D") as Camera3D
	cam.rotation = Vector3(cam.rotation.x, 0.0, 0.0)
	_player.ai_look_at(at)
	_player.set("_pitch", (_player.get_node("Camera3D") as Camera3D).rotation.x)


func _calibration(delta: float) -> bool:
	var el := _t - _stage_at
	match _cstage:
		0:
			var note: Node = _scene.get_node("Note")
			note.call("interact")
			root.get_node("NoteUI").call("_close")
			var ward: Node = _scene.get_node("WardDoor")
			_ok("lit + the note read unlocks the ward's far door", ward.get("locked") == false)
			var exit: Node = _scene.get_node("ExitDoor")
			_ok("…but the airlock exit waits for calibration", exit.call("_is_unlocked") == false,
				"'%s'" % exit.get("locked_message"))
			_ok("…and so does the airlock door", _scene.get_node("AirlockDoor").get("locked") == true)
			_player.global_position = Vector3(0.6, 0.05, -7.6)
			_player.velocity = Vector3.ZERO
			_look(Vector3(0, 1.3, -9.0))
			_cstage = 1
			_stage_at = _t
		1:
			if el < 0.2:
				return false
			var ward: Node3D = _scene.get_node("WardDoor")
			var tgt: Node = _player.ai_interact_target()
			_ok("the ward door answers the real interact ray", tgt != null and ward.is_ancestor_of(tgt),
				"target %s" % (str(tgt.get_path()) if tgt else "nothing"))
			_player.ai_interact()
			_cstage = 2
			_stage_at = _t
		2:
			if el < 1.4:
				return false
			_ok("the ward door opened", _scene.get_node("WardDoor").call("is_open") == true)
			_ok("ZERO panic through the cell, the hall and the ward — up to the calibration door",
				is_zero_approx(_peak_panic), "peak %.4f" % _peak_panic)
			_in_calib = true
			_player.global_position = Vector3(0, 0.05, -10.4)
			_cstage = 3
			_stage_at = _t
		3:
			# VO3 (~3.5 s) and then the projector.
			if el < 0.5:
				return false
			if not _vo3_checked:
				_vo3_checked = true
				_ok("entering calibration: VO3", _has_caption("Look at the screen, forty-seven."))
			if el < 4.6:
				return false
			var scary: Node = _scene.get_node("ProjectorScary")
			_ok("the projector is running — but standing, the screen moves nothing",
				_scene.get("_slide_i") == 0 and float(scary.get("scare_intensity")) == 0.0,
				"slide %s intensity %.2f" % [_scene.get("_slide_i"), float(scary.get("scare_intensity"))])
			_ok("…and the chair is called: SIT DOWN.", _has_caption("SIT DOWN."))
			_ok("…and there is no floor mark any more", _scene.get_node_or_null("StandHereMark") == null)
			var chair: Node3D = _scene.get_node("SubjectChair")
			_player.global_position = chair.global_position + Vector3(0.9, -0.75, 1.0)
			_player.velocity = Vector3.ZERO
			_look(chair.global_position)
			_cstage = 40
			_stage_at = _t
		40:
			if el < 0.2:
				return false
			var chair: Node = _scene.get_node("SubjectChair")
			var ct: Node = _player.ai_interact_target()
			_ok("the chair answers the real interact ray (E — sit)", ct == chair,
				"target %s %s at %v" % [str(ct.get_path()) if ct else "nothing", ct.get_script().resource_path if ct and ct.get_script() else "-", (ct as Node3D).global_position if ct else Vector3.ZERO])
			_player.ai_interact()
			_cstage = 41
			_stage_at = _t
		41:
			if el < 1.3:
				return false
			var screen0: Vector3 = _scene.get_script().get_script_constant_map()["SCREEN_POS"]
			var cam := _player.get_node("Camera3D") as Camera3D
			var d := cam.global_position.distance_to(screen0)
			_ok("seated: the body is pinned (the movement-only QTE pin)", _scene.get("_seated") == true
				and _player.is_input_frozen() and _player.get("_input_frozen") == false)
			_ok("seated: the eye is %.2f m from the screen — inside GAZE_RANGE 3.0 with margin" % d, d < 2.7,
				"eye %v" % cam.global_position)
			_ok("seated: the eye is at sitting height", cam.global_position.y > 1.0 and cam.global_position.y < 1.4,
				"%.2f" % cam.global_position.y)
			_cstage = 4
			_stage_at = _t
		4:
			var screen: Vector3 = _scene.get_script().get_script_constant_map()["SCREEN_POS"]
			_look(screen)
			if _has_caption("LOOK AWAY."):
				_ok("watching the slides from the CHAIR fills the bar to LOOK AWAY.",
					_player.get_panic_ratio() >= 0.34 and _scene.get("_seated") == true,
					"panic %.3f after %.1f s, seated %s" % [_player.get_panic_ratio(), el, _scene.get("_seated")])
				var cam := _player.get_node("Camera3D") as Camera3D
				var q := PhysicsRayQueryParameters3D.create(cam.global_position,
					cam.global_position - cam.global_basis.z * 3.0)
				q.exclude = [_player.get_rid()]
				var h := _player.get_world_3d().direct_space_state.intersect_ray(q)
				_ok("…through a gaze ray that really lands on the screen's ScaryObject body",
					not h.is_empty() and String(h["collider"].name) == "ProjectorScreen"
						and h["collider"].get_parent() == _scene.get_node("ProjectorScary"),
					"hit %s" % (str(h["collider"].name) if not h.is_empty() else "nothing"))
				_look(screen + Vector3(0, 0, 12.0))      # turn round, away from the screen
				_cstage = 5
				_stage_at = _t
			elif el > 40.0:
				_ok("watching the slides fills the bar to LOOK AWAY.", false,
					"panic %.3f after 40 s" % _player.get_panic_ratio())
				return true
		5:
			if not _has_caption("GOOD."):
				if el > 4.0:
					_ok("looking away for 1.5 s completes the lesson", false)
					return true
				return false
			_ok("looking away for 1.5 s completes the lesson (GOOD.)", el >= 1.4, "after %.2f s" % el)
			_ok("…and the projector stops", float(_scene.get_node("ProjectorScary").get("scare_intensity")) == 0.0)
			_cstage = 50
			_stage_at = _t
		50:
			if el < 1.2:
				return false
			_ok("GOOD. stands you up beside the chair, free", _scene.get("_seated") == false
				and not _player.is_input_frozen() and (_player.get_node("Camera3D") as Camera3D).position.y > 1.6)
			_cstage = 6
			_stage_at = _t
		6:
			# ⚠️ No line any more (second hand playtest, 2026-09-25, capture #4): GOOD. is the end of
			# the gaze lesson and the observer answers straight away.
			if el < 3.0:
				return false
			_ok("there is no WALK TO THE LINE. step any more", not _has_caption("WALK TO THE LINE.")
				and _scene.get_node_or_null("CalibrationLine") == null)
			_cstage = 8
			_stage_at = _t
		8:
			if el < 0.5:
				return false
			# The forbidden tray, through the real ray.
			var tray: Node3D = _scene.get_node("ForbiddenTray")
			_player.global_position = tray.global_position + Vector3(-1.0, -0.85, 0.3)
			_player.velocity = Vector3.ZERO
			_look(tray.global_position)
			_cstage = 9
			_stage_at = _t
		9:
			if el < 0.2:
				return false
			var tray: Node = _scene.get_node("ForbiddenTray")
			_ok("the DO NOT TOUCH tray answers the real interact ray", _player.ai_interact_target() == tray)
			_player.ai_interact()
			_ok("touching it spikes panic — pinned at the 0.6 ceiling",
				is_equal_approx(_player.get_panic_ratio(), 0.6), "panic %.3f" % _player.get_panic_ratio())
			_ok("…and is rebuked", _has_caption("WE SAID NOT TO TOUCH IT. NOTED."))
			_cstage = 10
			_stage_at = _t
		10:
			if _scene.get_node("AirlockDoor").get("locked") == false:
				_ok("VO4, and the airlock door unlocks", _has_caption("Much better than last time."))
				var ad: Node3D = _scene.get_node("AirlockDoor")
				_player.global_position = Vector3(-2.8, 0.05, -18.5)
				_player.velocity = Vector3.ZERO
				_look(ad.global_position + Vector3(0, 1.3, 0))
				_cstage = 11
				_stage_at = _t
			elif el > 9.0:
				_ok("VO4, and the airlock door unlocks", false)
				return true
		11:
			if el < 0.2:
				return false
			var ad: Node3D = _scene.get_node("AirlockDoor")
			var tgt: Node = _player.ai_interact_target()
			_ok("the airlock door answers the real interact ray", tgt != null and ad.is_ancestor_of(tgt))
			_player.ai_interact()
			_cstage = 12
			_stage_at = _t
		12:
			if el < 1.4:
				return false
			_player.global_position = Vector3(-5.6, 0.05, -18.4)
			_player.velocity = Vector3.ZERO
			_cstage = 13
			_stage_at = _t
		13:
			var exit: Node = _scene.get_node("ExitDoor")
			if exit.call("_is_unlocked") == true:
				_ok("the airlock: buzzer, VO5, and the exit unlocks", _has_caption("You may proceed."))
				_ok("the whole calibration peaked AT the ceiling and never past it",
					_peak_all <= 0.6001 and _peak_all >= 0.55, "peak %.4f" % _peak_all)
				_ok("…and no screamer fired, anywhere in the intro", not _screamed)
				return true
			elif el > 9.0:
				_ok("the airlock: buzzer, VO5, and the exit unlocks", false)
				return true
	return false


func _finish() -> void:
	# The whole point of the room. ⭐ 2026-09-24: ZERO through cell, hall and ward; calibration —
	# the only room allowed to move the bar — peaks at the ceiling and no further (asserted above).
	_ok("panic stayed at ZERO through the cell, the hall and the ward",
		is_zero_approx(_peak_panic), "peak %.4f of PANIC_MAX" % _peak_panic)
	_ok("…and the intro's panic ceiling is set (unloseable by construction)",
		is_equal_approx(float(_player.call("get_panic_ceiling")), 0.6),
		"ceiling %.2f" % float(_player.call("get_panic_ceiling")))

	print("")
	print("%d checks, %d failed" % [_checks, _fails.size()])
	if _fails.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		for f in _fails:
			print("  FAIL: " + f)
		print("RESULT: FAIL")
		quit(1)
