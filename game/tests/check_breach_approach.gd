extends SceneTree

# Walk the shipping approach, cross its physical trigger, and push back against
# the bulkhead. No completion signal or level helper is invoked to reach the hunt.
#
# 2026-09-23 (the approach redesign): the walk is sampled EVERY PHYSICS FRAME, and asserts —
#   * ⭐ PASS 3: panic is exactly 0 on every frame BEFORE the dark room, never above the cap (42)
#     inside it, and only drains after it. The dark room is the approach's one panic term, by the
#     user's call. This line used to assert 0 on every frame, and pass 3 had to change it.
#   * ⭐ PASS 3: the walk stops at the porthole door, takes the handle through the real E ray and
#     turns the wheel with synthesized mouse circles pushed into the viewport; the grille puppet is
#     checked like the hand and must be freed as the door tell ends, before the seal
#   * the real creature is hidden, voiceless and dormant on every frame until the seal
#   * every route beat fires exactly once, in route order, from the approach's own beat log,
#     and every sequence's inner steps fire once, after their parent
#   * the glimpse puppet has no CollisionShape3D, no ScaryObject above or below it, is never
#     emissive, is not the creature's material, waits for the player's LOOK (a negative control
#     stands in the Threshold facing away first), and is freed as it withdraws, before the seal
#   * the machinery layers REPORT the Ambience bus (the 2026-09-22 build asked for "SFX", and a
#     nonexistent bus reads back as "Master", so only a positive check can see it)
#   * the seal stops everything the approach owns
# plus the original bulkhead, retry, return-visit and new-run checks.
const SCENE := "res://scenes/level_6_breach.tscn"
const OUT := "/tmp/breach_approach/"
const SUB_BEATS := {
	"self_waking_lamp_dies": "self_waking_lamp", "door_tell_silence": "door_tell",
	"door_tell_dark": "door_tell", "door_tell_crash": "door_tell", "victim_roar": "victim",
	"victim_scream": "victim", "building_answers": "victim", "victim_thump": "victim",
	"victim_silence": "victim", "victim_drag": "victim", "hand_gone": "hand",
	"door_tell_grille_batter": "door_tell", "door_tell_grille_gone": "door_tell",
	"technician_grip": "technician", "technician_eyes_open": "technician",
	"technician_released": "technician", "technician_eyes_closed": "technician",
	"porthole_swung": "porthole_open",
}
var _level: Node
var _player: CharacterBody3D
var _creature: Node
var _approach: Node
var _fails := 0
var _checks := 0
var _started := 0
var _shots := false
var _walk_seconds := 0.0
var _frames := 0
var _panic_frames := 0
var _panic_max := 0.0
var _loud_frames := 0
var _dark_over := 0
var _dark_peak := 0.0
var _after_rise := 0
var _last_panic := 0.0
var _grille_freed_frames := -1
var _grille_freed_before_seal := false
var _wheel_seconds := 0.0
var _th := 0.0
# ⭐ PASS 4: the walk-in music's timeline, sampled every frame
var _music_frames := 0
var _music_min_busy := 0.0          # its lowest volume while a story beat plays (the story duck)
var _busy_run := 0.0                # seconds the story channel has been continuously busy
var _music_settled_busy_max := -80.0   # its HIGHEST volume once a story beat has run >= 1.2 s, no silence duck
var _music_settled_samples := 0
var _pa_run := 0.0                   # seconds a PA line (or its chime) has been playing
var _music_pa_max := -80.0           # the music's highest volume once a PA line has run 0.5 s
var _music_pa_samples := 0
var _music_max_idle := -80.0        # its highest volume on a quiet frame (its measured level)
var _dip := {"door_tell_silence": 99.0, "victim_silence": 99.0}   # Ambience bus dB just inside each silence
var _amb_base := 0.0
var _music_at_hand := 99.0

func _initialize() -> void:
	_started = Time.get_ticks_msec()
	_shots = OS.get_cmdline_user_args().has("--screenshots")
	change_scene_to_file(SCENE)
	_run.call_deferred()

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started > 300000:
		print("FAIL approach test timed out")
		quit(1)
	return false

func _ok(label: String, yes: bool) -> void:
	_checks += 1
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", label])

func _bind() -> void:
	_level = current_scene
	_player = _level.get_node("Player")
	_player.set("ai_active", true)
	_creature = _level.get("_creature")
	_approach = _level.get("_approach")

func _shot(label: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	root.get_texture().get_image().save_png(OUT + label + ".png")

# One physics frame of evidence: panic and creature quiet, while the approach is not sealed.
func _sample() -> void:
	if _approach.get("completed"):
		return
	_frames += 1
	var panic := float(_player.get("_panic"))
	var in_dark: bool = _approach.get("_in_dark")
	var seen_dark := _count("dark_room") > 0
	if not seen_dark:
		_panic_max = maxf(_panic_max, panic)
		if panic != 0.0:
			_panic_frames += 1
	elif in_dark:
		_dark_peak = maxf(_dark_peak, panic)
		if panic > 42.0001:
			_dark_over += 1
	elif panic > _last_panic + 0.0001:
		_after_rise += 1
	_last_panic = panic
	if not _quiet():
		_loud_frames += 1
	var music: AudioStreamPlayer = _approach.get("_music")
	if is_instance_valid(music) and music.playing:
		_music_frames += 1
		if _approach.call("_pa_active"):
			_pa_run += 1.0 / Engine.physics_ticks_per_second
			if _pa_run >= 0.5 and is_zero_approx(float(_approach.get("_duck_db"))):
				_music_pa_max = maxf(_music_pa_max, music.volume_db)
				_music_pa_samples += 1
		else:
			_pa_run = 0.0
		if _approach.call("_story_idle", 0.0):
			_music_max_idle = maxf(_music_max_idle, music.volume_db)
			_busy_run = 0.0
		else:
			_music_min_busy = minf(_music_min_busy, music.volume_db)
			_busy_run += 1.0 / Engine.physics_ticks_per_second
			# settled under a story beat (the fade is 8 dB/s), with no silence duck and not at the Threshold:
			# this is the frame that proves the STORY duck itself, not a silence or the fade-out
			if _busy_run >= 1.2 and is_zero_approx(float(_approach.get("_duck_db"))) and not _approach.get("_threshold_quiet"):
				_music_settled_busy_max = maxf(_music_settled_busy_max, music.volume_db)
				_music_settled_samples += 1
	var bus := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience"))
	var now := float(_approach.get("_time"))
	for e in _approach.get("beat_log"):
		if _dip.has(e["name"]) and now - float(e["t"]) > 0.25 and now - float(e["t"]) < 0.9:
			_dip[e["name"]] = minf(_dip[e["name"]], bus)
	# the grille puppet: judged on the frames right after it goes, never after the seal
	if _grille_freed_frames >= 0:
		_grille_freed_frames += 1
		if _grille_freed_frames == 3:
			_grille_freed_before_seal = _approach.call("grille_puppet") == null
	elif _count("door_tell_grille_gone") == 1:
		_grille_freed_frames = 0

func _walk(target: Vector3, counted: bool = true) -> void:
	var elapsed := 0.0
	while Vector2(_player.position.x - target.x, _player.position.z - target.z).length() > 0.3:
		_player.call("ai_look_at", Vector3(target.x, 1.75, target.z))
		_player.set("ai_move_dir", Vector2(0, -1))
		await physics_frame
		_sample()
		var delta := 1.0 / Engine.physics_ticks_per_second
		elapsed += delta
		if counted:
			_walk_seconds += delta
		if elapsed > 23.0:
			_ok("walk reaches %s (stopped at %s)" % [target, _player.position], false)
			_player.set("ai_move_dir", Vector2.ZERO)
			return
	_player.set("ai_move_dir", Vector2.ZERO)
	await physics_frame
	_ok("physical route reaches %s" % target, true)

func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await physics_frame
		_sample()
		t += 1.0 / Engine.physics_ticks_per_second

func _quiet() -> bool:
	var voice: Node = _level.get("_creature_voice")
	return not _creature.get("_active") and not _creature.get("_body").visible \
		and not voice.get("_voice").playing and not voice.get("_music").playing \
		and _level.get("_kill_sequence") == null

func _names() -> Array:
	return Array(_approach.call("beat_names"))

func _count(beat: String) -> int:
	return _names().count(beat)

func _has_scary_above_or_below(node: Node) -> bool:
	var n := node
	while n != null:
		if n is ScaryObject:
			return true
		n = n.get_parent()
	return _find(node, func(c): return c is ScaryObject) != null

func _find(node: Node, pred: Callable) -> Node:
	for c in node.get_children():
		if pred.call(c):
			return c
		var deep := _find(c, pred)
		if deep:
			return deep
	return null

func _meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_meshes(c, out)

func _speakers(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer3D:
			out.append(c)
		_speakers(c, out)

func _check_puppet(label: String) -> Node:
	var puppet: Node = _approach.call("hand_puppet")
	_ok("%s: the glimpse puppet exists" % label, puppet != null)
	if puppet == null:
		return null
	_ok("%s: the puppet carries no CollisionShape3D" % label,
		_find(puppet, func(c): return c is CollisionShape3D or c is CollisionObject3D) == null)
	_ok("%s: no ScaryObject above or below the puppet (zero panic, no contact)" % label,
		not _has_scary_above_or_below(puppet))
	var meshes: Array = []
	_meshes(puppet, meshes)
	_ok("%s: the puppet is the real rig (%d meshes)" % [label, meshes.size()], meshes.size() >= 1)
	var creature_mat: Material = _creature.get("_material")
	var ok_mat := not meshes.is_empty()
	for m in meshes:
		var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
		if mat == null or mat == creature_mat or mat.emission_enabled \
				or (m as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			ok_mat = false
	_ok("%s: every puppet mesh has its OWN non-emissive material and casts no shadow" % label, ok_mat)
	_ok("%s: the puppet is not the creature (the real body is untouched)" % label,
		not puppet.is_ancestor_of(_creature) and not _creature.is_ancestor_of(puppet))
	return puppet

# ⭐ PASS 4: at the fused technician on the FAR side of the Plenum. Wait for him to answer (the victim
# is heard first), and take the handle through the real E ray, looking at his face as a player would.
func _take_the_handle() -> void:
	var head: Vector3 = _approach.get("_tech_head")
	var door: Vector3 = _approach.get("_wheel").global_position
	_ok("the technician is on the far side of the Plenum from the porthole door (%.1f m)" % Vector2(head.x - door.x, head.z - door.z).length(),
		Vector2(head.x - door.x, head.z - door.z).length() > 12.0)
	var waited := 0.0
	var target: Node = null
	while waited < 25.0 and target == null:
		_player.call("ai_look_at", head)
		await physics_frame
		_sample()
		waited += 1.0 / Engine.physics_ticks_per_second
		target = _player.call("ai_interact_target")
	_ok("the technician is reachable through the real E ray (after %.1f s at his wall)" % waited,
		target != null and String(target.name) == "TechnicianInteract")
	_player.call("ai_interact")
	await _wait(4.2)
	_ok("the handle is taken", _approach.get("handle_taken"))


# ⭐ PASS 3: at the porthole door, fit the handle and turn the wheel with mouse circles until it opens.
func _turn_the_wheel() -> void:
	_player.call("ai_look_at", Vector3(-44.5, 1.05, -32.87))
	await physics_frame
	_player.call("ai_interact")
	await physics_frame
	_ok("E on the wheel fits the handle and takes hold", _approach.get("wheel_engaged"))
	var dt := 1.0 / Engine.physics_ticks_per_second
	var w := TAU * 0.7
	while not _approach.get("porthole_open") and _wheel_seconds < 30.0:
		var mm := InputEventMouseMotion.new()
		mm.relative = Vector2(-sin(_th), cos(_th)) * 60.0 * w * dt
		root.push_input(mm)
		_th += w * dt
		await physics_frame
		_sample()
		_wheel_seconds += dt
	_ok("the porthole door opens", _approach.get("porthole_open"))
	await _wait(4.0)


func _run() -> void:
	await create_timer(1.8).timeout
	_bind()
	var gs := root.get_node("GameState")
	var constants: Dictionary = _approach.get_script().get_script_constant_map()
	var start: Vector3 = constants["START_SPAWN"]
	var route: Array = constants["ROUTE_BEATS"]
	_ok("first visit starts in the approach", _player.position.distance_to(start) < 0.3 and not _level.get("_approach_complete"))
	_ok("approach objective is distinct from flashlight search", "CONTAINMENT" in String(gs.get("current_objective")))
	_ok("torch remains missing", _player.get("_flashlight_locked") and not _player.call("is_flashlight_on"))
	_ok("creature is absent from view and silent", _quiet())
	_ok("arriving lights the first motion cluster (the rule is taught at the spawn)", _count("arrival_lamps") == 1)
	# ⚠️ The 2026-09-22 approach asked for an "SFX" bus this project has never had. And a check
	# of the form "is s.bus a bus that exists?" CANNOT see that: `AudioStreamPlayer.bus` reads back
	# "Master" for a nonexistent bus (the same silent fallback that hid the bug). Proven while
	# writing this: with the bus renamed to "SFX" such a check stayed green. So the check is
	# POSITIVE — the machinery layers must REPORT Ambience, which they only can if it exists.
	var speakers: Array = []
	_speakers(_approach, speakers)
	var on_ambience := speakers.filter(func(s): return s.bus == "Ambience")
	_ok("the machinery layers report the Ambience bus (%d of %d speakers)" % [on_ambience.size(), speakers.size()],
		on_ambience.size() >= 2 and speakers.all(func(s): return s.bus in ["Master", "Ambience"]))
	_ok("the breathing bed is on Ambience, so silence beats can duck it",
		speakers.any(func(s): return s.bus == "Ambience" and s.playing))
	var music0: AudioStreamPlayer = _approach.get("_music")
	_ok("⭐ the walk-in music plays from the spawn, looped, on Ambience",
		is_instance_valid(music0) and music0.playing and music0.bus == "Ambience"
		and music0.stream is AudioStreamOggVorbis and (music0.stream as AudioStreamOggVorbis).loop)
	_amb_base = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience"))
	await _shot("01_service_arrival")
	# Deliberately wait longer than the hunt grace. It must not run during the approach.
	await create_timer(8.2).timeout
	_ok("waiting in approach cannot activate the creature", _quiet() and is_zero_approx(float(_level.get("_familiarization_t"))))
	_level.call("_on_contact_death")
	_ok("approach cannot start Object12's kill presentation", _level.get("_kill_sequence") == null)
	# A death before the checkpoint must replay the approach.
	gs.call("restart_current_level")
	await create_timer(1.8).timeout
	_bind()
	_ok("pre-threshold death stays at approach entrance", not _level.get("_approach_complete") and _player.position.distance_to(start) < 0.3)
	_ok("a replayed approach starts with a fresh beat log", _names() == ["arrival_lamps"])
	var puppet := _check_puppet("before the walk")
	var grille: Node = _approach.call("grille_puppet")
	_ok("the grille puppet exists before the walk", grille != null)
	if grille:
		_ok("the grille puppet carries no CollisionShape3D", _find(grille, func(c): return c is CollisionShape3D or c is CollisionObject3D) == null)
		_ok("no ScaryObject above or below the grille puppet", not _has_scary_above_or_below(grille))
		var gm: Array = []
		_meshes(grille, gm)
		var gm_ok := not gm.is_empty()
		for m in gm:
			var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
			if mat == null or mat == _creature.get("_material") or mat.emission_enabled \
					or (m as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				gm_ok = false
		_ok("every grille puppet mesh has its OWN non-emissive material and casts no shadow (%d)" % gm.size(), gm_ok)
	var points: Array = constants["WALK_POINTS"]
	var door_stop: Vector3 = constants["DOOR_STOP"]
	var tech_stop: Vector3 = constants["TECH_STOP"]
	_ok("the route visits the technician BEFORE the porthole door",
		points.find(tech_stop) >= 0 and points.find(tech_stop) < points.find(door_stop))
	# Walk everything but the last leg (into the Threshold), sampling every frame.
	for index in range(1, points.size() - 1):
		await _walk(points[index])
		if (points[index] as Vector3).distance_to(tech_stop) < 0.05:
			await _take_the_handle()
		if (points[index] as Vector3).distance_to(door_stop) < 0.05:
			await _turn_the_wheel()
		_player.call("ai_look_at", points[index + 1] + Vector3(0, 1.65, 0))
		await _wait(0.1)
		await _shot("route_%02d" % index)
	_ok("the glimpse has not fired before the Threshold", _count("hand") == 0 and _count("hand_skipped") == 0)
	# NEGATIVE CONTROL: stand inside the Threshold FACING AWAY until every story beat is over.
	# The glimpse must wait for the look; a trigger volume would already have fired.
	_player.call("ai_look_at", Vector3(0, 1.75, -60))
	await _wait(0.2)
	var backed := 0.0
	while _player.position.z < -20.5 and backed < 3.0:
		_player.call("ai_look_at", Vector3(0, 1.75, -60))
		_player.set("ai_move_dir", Vector2(0, 1))
		await physics_frame
		_sample()
		backed += 1.0 / Engine.physics_ticks_per_second
	_player.set("ai_move_dir", Vector2.ZERO)
	var idle := 0.0
	while idle < 10.0 and not _approach.call("_story_idle", 1.5):
		await _wait(0.25)
		idle += 0.25
	await _wait(0.5)
	_ok("threshold reached facing away (z %.2f), story channel idle after %.2f s" % [_player.position.z, idle],
		_player.position.z > -22.0 and _approach.call("_story_idle", 1.5))
	_ok("looking AWAY from the duct does not fire the glimpse", _count("hand") == 0 and is_instance_valid(puppet))
	# Turn to face up the Threshold and finish the route.
	var hand_seen_at := -1.0
	var gone_frames := -1
	var freed_before_seal := false
	var last: Vector3 = points[points.size() - 1]
	var elapsed := 0.0
	while Vector2(_player.position.x - last.x, _player.position.z - last.z).length() > 0.3 and elapsed < 23.0:
		_player.call("ai_look_at", Vector3(last.x, 1.75, last.z))
		_player.set("ai_move_dir", Vector2(0, -1))
		await physics_frame
		_sample()
		var delta := 1.0 / Engine.physics_ticks_per_second
		elapsed += delta
		_walk_seconds += delta
		if hand_seen_at < 0.0 and _count("hand") == 1:
			hand_seen_at = elapsed
			var mh: AudioStreamPlayer = _approach.get("_music")
			_music_at_hand = mh.volume_db if is_instance_valid(mh) and mh.playing else -80.0
			await _shot("03_hand_peak")
		# ⚠️ Judge the free BEFORE the seal: the seal frees the puppet anyway, so a check made after
		# it passed with the free deleted (proven while writing this).
		if gone_frames >= 0:
			gone_frames += 1
			if gone_frames == 3 and not _approach.get("completed"):
				freed_before_seal = not is_instance_valid(puppet)
		elif _count("hand_gone") == 1:
			gone_frames = 0
	_player.set("ai_move_dir", Vector2.ZERO)
	_ok("looking up the Threshold fires the glimpse (after %.2f s)" % hand_seen_at, hand_seen_at >= 0.0)
	var fired_at := float(_approach.get("hand_fire_distance"))
	_ok("the glimpse fires within 3–5 m of the player, close enough to read as a hand (%.2f m)" % fired_at,
		fired_at >= 3.0 and fired_at <= 5.0)
	await _wait(0.4)
	_ok("the glimpse puppet is freed as soon as it withdraws, before the seal", freed_before_seal)
	_ok("and nothing of it survives the seal", not is_instance_valid(puppet) and _approach.call("hand_puppet") == null)
	print("APPROACH WALK GAME SECONDS %.2f" % _walk_seconds)
	_ok("walking time lies within agreed 60–90 seconds", _walk_seconds >= 60 and _walk_seconds <= 90)
	# The beat log, in route order, each exactly once.
	var names := _names()
	print("APPROACH BEATS ", names)
	for b in _approach.get("beat_log"):
		print("  %-22s t=%6.2f  at %s" % [b["name"], b["t"], b["pos"]])
	var in_route := names.filter(func(n): return n in route)
	_ok("every route beat fired exactly once, in route order (%d of %d)" % [in_route.size(), route.size()], in_route == route)
	var subs_ok := true
	for sub in SUB_BEATS:
		var parent: String = SUB_BEATS[sub]
		if names.count(sub) != 1 or names.find(sub) < names.find(parent):
			subs_ok = false
			print("  sub-beat %s: count %d, index %d, parent %s at %d" % [sub, names.count(sub), names.find(sub), parent, names.find(parent)])
	_ok("every sequence step fired once, after its parent (%d steps)" % SUB_BEATS.size(), subs_ok)
	_ok("nothing was skipped", names.count("hand_skipped") == 0)
	# Frame-sampled invariants.
	print("APPROACH FRAMES %d  panic>0 before the dark room on %d (max %.4f)  dark peak %.3f (over cap %d)  rose after %d  creature not quiet on %d" % [
		_frames, _panic_frames, _panic_max, _dark_peak, _dark_over, _after_rise, _loud_frames])
	_ok("the sample is meaningful (%d frames)" % _frames, _frames > 60 * 60)
	_ok("panic is exactly 0 on every frame BEFORE the dark room", _panic_frames == 0 and _panic_max == 0.0)
	_ok("in the dark room panic rises (peak %.2f) and never passes the cap" % _dark_peak, _dark_peak > 1.0 and _dark_over == 0)
	_ok("after the dark room panic only drains (%d frames rose)" % _after_rise, _after_rise == 0)
	_ok("the grille puppet is freed as soon as the lights return, before the seal", _grille_freed_before_seal)
	print("APPROACH WHEEL SECONDS %.2f (mouse circles at 0.7/s)" % _wheel_seconds)
	_ok("three turns of the wheel took roughly 10–15 s of circling (%.2f s)" % _wheel_seconds, _wheel_seconds >= 9.0 and _wheel_seconds <= 15.0)
	_ok("the real creature is hidden, voiceless and dormant on every frame until the seal", _loud_frames == 0)
	# ⭐ PASS 4: the music's timeline
	var consts: Dictionary = _approach.get_script().get_script_constant_map()
	print("APPROACH MUSIC  playing on %d frames  idle level %.1f dB  lowest under a story beat %.1f dB  Ambience %.1f dB -> door-tell silence %.1f, victim silence %.1f  at the hand %.1f dB" % [
		_music_frames, _music_max_idle, _music_min_busy, _amb_base, _dip["door_tell_silence"], _dip["victim_silence"], _music_at_hand])
	_ok("the music played through most of the walk (%d frames)" % _music_frames, _music_frames > 60 * 45)
	_ok("its quiet-frame level is its measured gain (%.1f dB, MUSIC_DB %.1f)" % [_music_max_idle, consts["MUSIC_DB"]],
		absf(_music_max_idle - float(consts["MUSIC_DB"])) < 0.6)
	# ⚠️ Measured against its OWN idle level, never against MUSIC_STORY_DUCK read back: with the duck
	# set to 0 a threshold built from the constant moved with it and stayed green (proven while writing it).
	_ok("it ducks under the story beats: at least 4 dB under its idle level once a beat has run 1.2 s (%.1f dB against %.1f, %d frames)" % [
		_music_settled_busy_max, _music_max_idle, _music_settled_samples],
		_music_settled_samples > 60 and _music_settled_busy_max <= _music_max_idle - 4.0)
	_ok("it makes room for the tannoy: at least 12 dB under its idle level once a PA line has run 0.5 s (%.1f dB against %.1f, %d frames)" % [
		_music_pa_max, _music_max_idle, _music_pa_samples], _music_pa_samples > 60 and _music_pa_max <= _music_max_idle - 12.0)
	_ok("the door tell's silence dips it with the Ambience bus (%.1f dB against %.1f)" % [_dip["door_tell_silence"], _amb_base],
		_dip["door_tell_silence"] <= _amb_base - 10.0)
	_ok("the victim's silence dips it too (%.1f dB against %.1f)" % [_dip["victim_silence"], _amb_base],
		_dip["victim_silence"] <= _amb_base - 10.0)
	_ok("it is silent at the hand's corner (%.1f dB when the hand fired)" % _music_at_hand, _music_at_hand <= -50.0)
	await create_timer(0.5).timeout
	_ok("walking across threshold begins the hunt", _level.get("_approach_complete") and _approach.get("completed"))
	var still: Array = []
	_speakers(_approach, still)
	still = still.filter(func(s): return s.playing and s.name != "BulkheadSlam")
	_ok("the seal stops every approach speaker (%d still playing)" % still.size(), still.is_empty())
	# ⭐ 2026-09-23 (the user's call): ABSENT through the grace, invisible AND without a collider,
	# instead of standing dormant in Junction1. Asserted on the collider too: a hidden body with a live
	# capsule is an invisible wall, and the ScaryObject above it would still charge gaze panic.
	var body_col: CollisionShape3D = _creature.get("_body_collider")
	_ok("threshold keeps the creature ABSENT with full grace", not _creature.get("_body").visible and body_col.disabled
		and not _creature.get("_active") and _level.get("_familiarization_t") < 2.0)
	_ok("search objective begins at the threshold", "FLASHLIGHT" in String(gs.get("current_objective")))
	_player.call("ai_look_at", Vector3(0, 1.4, -3))
	await _shot("02_bulkhead_sealed")
	_player.set("ai_move_dir", Vector2(0, -1))
	await create_timer(0.9).timeout
	_player.set("ai_move_dir", Vector2.ZERO)
	_ok("closed bulkhead physically stops retreat", _player.position.z > -2.8)
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.5, -1), Vector3(0, 1.5, -5), 1)
	query.exclude = [_player.get_rid()]
	_ok("bulkhead blocks a real world ray", not _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	# Live negative control: the shell opening must be open when this leaf is disabled.
	var blocker: CollisionShape3D = _approach.get("_gate_blocker")
	blocker.set_deferred("disabled", true)
	await physics_frame
	await physics_frame
	_ok("disabling gate removes the obstruction (positive control)", _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	blocker.set_deferred("disabled", false)
	await create_timer(7.1).timeout
	_ok("creature activates only after post-entry grace", _creature.get("_active"))
	# ...and APPEARS unseen: present again, somewhere else, far from the player, never in the
	# flashlight room or the purge chamber, and with no "IT IS AWAKE" objective (2026-09-23).
	var appeared: Vector3 = _creature.call("get_creature_position")
	var builder: Node = _level.get("_builder")
	var flat := Vector2(appeared.x - _player.global_position.x, appeared.z - _player.global_position.z).length()
	_ok("it appears present again (visible + solid)", _creature.get("_body").visible and not body_col.disabled)
	_ok("it appears far from the player (%.1f m)" % flat, flat >= 8.0)
	_ok("it never appears in the flashlight room or the purge chamber",
		Vector2(appeared.x, appeared.z).distance_to(Vector2(builder.call("room_center", "EastVault").x, builder.call("room_center", "EastVault").z)) > 0.6
		and Vector2(appeared.x, appeared.z).distance_to(Vector2(builder.call("room_center", "ExitVault").x, builder.call("room_center", "ExitVault").z)) > 0.6)
	_ok("activation is unannounced (objective unchanged)", not ("AWAKE" in String(gs.get("current_objective"))))
	_creature.set_process(false)
	gs.get("level_progress")[6] = _level.call("save_progress")
	change_scene_to_file(SCENE)
	await create_timer(1.8).timeout
	_bind()
	_ok("normal return retains sealed hunt checkpoint", _level.get("_approach_complete") and _approach.get("completed") and _player.position.z > -3)
	_ok("a return visit plays no approach beat and builds no puppet", _names().is_empty() and _approach.call("hand_puppet") == null)
	_ok("⭐ …and no walk-in music (it is never in the hunt)", not is_instance_valid(_approach.get("_music")))
	gs.call("restart_current_level")
	await create_timer(1.8).timeout
	_bind()
	_ok("death after entry skips approach", _level.get("_approach_complete") and _player.position.distance_to(Vector3(0, 0, -2)) < 0.3)
	_ok("hunt retry still resets flashlight", not _level.get("_flashlight_found") and _player.get("_flashlight_locked"))
	_ok("⭐ a hunt retry plays no walk-in music", not is_instance_valid(_approach.get("_music")))
	# The menu reset is the real new-run path: static scene state must not survive it.
	gs.call("go_to_main_menu")
	await create_timer(0.5).timeout
	change_scene_to_file(SCENE)
	await create_timer(1.8).timeout
	_bind()
	_ok("new run restores the entire approach", not _level.get("_approach_complete") and _player.position.distance_to(start) < 0.3 and _quiet())
	_ok("new run has no completed approach snapshot", not _level.call("save_progress")["approach_complete"])
	_ok("new run replays the approach from its first beat, glimpse armed", _names() == ["arrival_lamps"] and _approach.call("hand_puppet") != null)
	_ok("sample count is meaningful", _checks >= 45)
	print("BREACH APPROACH: %d checks, %d failed" % [_checks, _fails])
	current_scene.queue_free()
	await process_frame
	await process_frame
	quit(1 if _fails else 0)
