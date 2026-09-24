extends SceneTree

# MEASURE the Breach approach's mix at the listener on a real walk (2026-09-23, pass 4: the user
# could not hear the walk-in music under the corridor).
#
#   Godot --headless --path game --script res://tests/probe_breach_music_mix.gd
#
# Headless works: the Dummy audio driver still mixes in real time, and AudioEffectCapture reads it.
# Every approach speaker is re-routed, the frame it appears, onto a METER bus that sends where it was
# going (so the Ambience silences still dip it), and each meter bus carries an AudioEffectCapture:
#   M_Music   the walk-in music                       -> Ambience
#   M_Amb     every other Ambience speaker: the vent bed, machinery, beds, the shutter … -> Ambience
#   M_PA      the tannoy (and its chime)              -> Master
#   M_Whisper the technician's whisper                -> Master
#   M_Story   every other Master speaker: the door tell, the victim, clunks … -> Master
#   M_Lvl     the LEVEL's own beds when they are on Master (the AmbientPlayer and its layer) -> Master
# A capture sits BEFORE its bus's downstream Ambience fader, so the Ambience bus's own volume (the
# HoldBreath dip) is added back per window. Master carries a capture too, as the total.
# Levels are RMS dBFS over 0.1 s windows, power-averaged per class; LUFS would read a few dB
# different, but every comparison here is relative, which is what the mix targets are.
const SCENE := "res://scenes/level_6_breach.tscn"
const METERS := ["M_Music", "M_Amb", "M_Lvl", "M_PA", "M_Whisper", "M_Story", "M_Scream", "M_Kill"]
const WIN := 0.1
var _level: Node
var _player: CharacterBody3D
var _approach: Node
var _caps := {}
var _master_cap: AudioEffectCapture
var _acc := {}
var _acc_frames := 0
var _win_t := 0.0
var _windows: Array = []          # [{t, music, amb, pa, whisper, story, total, ambbus, idle}]
var _started := 0


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	change_scene_to_file(SCENE)
	_run.call_deferred()


func _process(delta: float) -> bool:
	if Time.get_ticks_msec() - _started > 420000:
		print("probe timed out")
		quit(1)
	if _approach != null and is_instance_valid(_approach):
		_route()
		_drain(delta)
	return false


func _db(ms: float) -> float:
	return 10.0 * log(maxf(ms, 1e-12)) / log(10.0)


func _setup_buses() -> void:
	for name in METERS:
		if AudioServer.get_bus_index(name) != -1:
			continue
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, "Ambience" if name in ["M_Music", "M_Amb"] else "Master")
		var cap := AudioEffectCapture.new()
		cap.buffer_length = 0.5
		AudioServer.add_bus_effect(i, cap)
		_caps[name] = cap
	_master_cap = AudioEffectCapture.new()
	_master_cap.buffer_length = 0.5
	AudioServer.add_bus_effect(0, _master_cap, AudioServer.get_bus_effect_count(0))
	for k in METERS + ["total"]:
		_acc[k] = 0.0


func _players(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer3D:
			out.append(c)
		_players(c, out)


func _route() -> void:
	var list: Array = []
	_players(_level, list)
	var music: Node = _approach.get("_music")
	for p in list:
		if p.has_meta("probe_bus"):
			continue
		var path := String(p.stream.resource_path) if p.stream else ""
		var to := ""
		if p == music:
			to = "M_Music"
		elif path.contains("approach_pa_") or path.contains("pa_kontur_chime") or String(p.name) == "ApproachPA":
			to = "M_PA"
		elif path.contains("approach_whisper"):
			to = "M_Whisper"
		elif path.contains("approach_technician_scream"):
			to = "M_Scream"
		elif not _approach.is_ancestor_of(p) and p.bus == "Master":
			to = "M_Lvl"
		elif p.bus == "Ambience":
			to = "M_Amb"
		elif p.bus == "Master":
			to = "M_Story"
		if to != "":
			p.bus = to
			p.set_meta("probe_bus", to)


func _ms(buf: PackedVector2Array) -> float:
	var s := 0.0
	for v in buf:
		s += (v.x * v.x + v.y * v.y) * 0.5
	return s


func _drain(_delta: float) -> void:
	var n := _master_cap.get_frames_available()
	if n <= 0:
		return
	_acc["total"] += _ms(_master_cap.get_buffer(n))
	for name in METERS:
		var cap: AudioEffectCapture = _caps[name]
		var m := cap.get_frames_available()
		if m > 0:
			_acc[name] += _ms(cap.get_buffer(m))
	_acc_frames += n
	# windows are counted in AUDIO frames: the Dummy driver mixes in bursts, not once per frame
	if _acc_frames >= int(AudioServer.get_mix_rate() * WIN):
		var amb_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience"))
		var w := {"t": float(_approach.get("_time")), "ambbus": amb_db,
			"idle": _approach.call("_story_idle", 0.0) and is_zero_approx(float(_approach.get("_duck_db"))) and not _approach.get("_threshold_quiet"),
			"pa_active": _approach.call("_pa_active"), "quiet": _approach.get("_threshold_quiet")}
		for k in METERS + ["total"]:
			var lvl := _db(_acc[k] / _acc_frames)
			if k in ["M_Music", "M_Amb"]:
				lvl += amb_db
			w[k] = lvl
			_acc[k] = 0.0
		w["beds"] = _db(pow(10.0, w["M_Amb"] / 10.0) + pow(10.0, w["M_Lvl"] / 10.0))
		var music: AudioStreamPlayer = _approach.get("_music")
		w["music_vol"] = music.volume_db if is_instance_valid(music) else -99.0
		w["music_playing"] = is_instance_valid(music) and music.playing
		_windows.append(w)
		_acc_frames = 0


func _walk(target: Vector3, limit := 25.0) -> void:
	var e := 0.0
	while Vector2(_player.position.x - target.x, _player.position.z - target.z).length() > 0.3 and e < limit:
		_player.call("ai_look_at", Vector3(target.x, 1.75, target.z))
		_player.set("ai_move_dir", Vector2(0, -1))
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second
	_player.set("ai_move_dir", Vector2.ZERO)


func _wait(t: float) -> void:
	var e := 0.0
	while e < t:
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second


func _run() -> void:
	await create_timer(1.8).timeout
	_level = current_scene
	_player = _level.get_node("Player")
	_player.set("ai_active", true)
	_setup_buses()
	_approach = _level.get("_approach")
	var music: AudioStreamPlayer = _approach.get("_music")
	var ogg := music.stream as AudioStreamOggVorbis if music else null
	print("MUSIC  node %s  playing %s  bus %s  volume %.1f dB  loop %s  length %.2f s" % [
		music != null, music.playing if music else false, music.bus if music else "-", music.volume_db if music else 0.0,
		ogg.loop if ogg else false, music.stream.get_length() if music else 0.0])
	var consts: Dictionary = _approach.get_script().get_script_constant_map()
	var points: Array = consts["WALK_POINTS"]
	var tech_stop: Vector3 = consts["TECH_STOP"]
	# the walk-in up to the technician, the real route
	for i in range(1, points.size()):
		await _walk(points[i])
		if (points[i] as Vector3).distance_to(tech_stop) < 0.05:
			break
	# the technician: wait for him, take the handle (the whisper)
	var head: Vector3 = _approach.get("_tech_head")
	var e := 0.0
	while _player.call("ai_interact_target") == null and e < 25.0:
		_player.call("ai_look_at", head)
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second
	_player.call("ai_interact")
	await _wait(5.0)
	# PA 3 in Containment, then the Threshold (the music must be gone there)
	_player.global_position = Vector3(-13.6, 0.1, -26.0)
	await _wait(0.3)
	await _walk(Vector3(-4.0, 0.1, -26.0))
	await _wait(6.0)
	await _walk(Vector3(0.0, 0.1, -26.0))
	await _walk(Vector3(0.0, 0.1, -21.5))
	await _wait(4.0)
	music = _approach.get("_music")
	var still := is_instance_valid(music) and music.playing
	print("MUSIC at the Threshold +4 s: playing %s" % still)
	# the kill sting as `breach_kill_sequence.gd` plays it (flat, -8 dB, Master): the scream's ceiling
	var kill := AudioStreamPlayer.new()
	kill.stream = load("res://assets/audio/level_6_breach/level_6_jumpscare.wav")
	kill.volume_db = -8.0
	kill.bus = "M_Kill"
	kill.set_meta("probe_bus", "M_Kill")
	_level.add_child(kill)
	kill.play()
	await _wait(2.0)
	_report()
	quit(0)


func _pavg(rows: Array, key: String) -> float:
	if rows.is_empty():
		return -99.0
	var s := 0.0
	for r in rows:
		s += pow(10.0, float(r[key]) / 10.0)
	return _db(s / rows.size())


func _pct(rows: Array, a: String, b: String, q: float) -> float:
	if rows.is_empty():
		return -99.0
	var d: Array = rows.map(func(r): return float(r[a]) - float(r[b]))
	d.sort()
	return d[clampi(int(q * (d.size() - 1)), 0, d.size() - 1)]


func _report() -> void:
	print("windows %d (%.1f s)" % [_windows.size(), _windows.size() * WIN])
	var idle := _windows.filter(func(w): return w["idle"] and w["ambbus"] > -1.0 and w["M_PA"] < -60.0 and w["M_Story"] < -45.0 and w["M_Whisper"] < -60.0)
	var pa := _windows.filter(func(w): return w["M_PA"] > -45.0)
	var whisper := _windows.filter(func(w): return w["M_Whisper"] > -45.0)
	var story := _windows.filter(func(w): return w["M_Story"] > -40.0 and w["M_PA"] < -60.0 and w["M_Whisper"] < -60.0 and w["ambbus"] > -1.0)
	var silence := _windows.filter(func(w): return w["ambbus"] < -10.0)
	var quiet := _windows.filter(func(w): return w["quiet"])
	for pair in [["between beats", idle], ["PA lines", pa], ["the whisper", whisper], ["other story beats", story],
			["the silences (Ambience dipped)", silence], ["after threshold_quiet", quiet]]:
		var rows: Array = pair[1]
		print("%-32s n=%4d  music %6.1f  beds %6.1f  PA %6.1f  whisper %6.1f  story %6.1f  total %6.1f" % [
			pair[0], rows.size(), _pavg(rows, "M_Music"), _pavg(rows, "beds"), _pavg(rows, "M_PA"),
			_pavg(rows, "M_Whisper"), _pavg(rows, "M_Story"), _pavg(rows, "total")])
	print("     beds between beats = approach Ambience speakers %.1f + the level's own beds %.1f" % [_pavg(idle, "M_Amb"), _pavg(idle, "M_Lvl")])
	print("MIX  between beats: music - beds = %+.1f dB (target +3..+4)" % (_pavg(idle, "M_Music") - _pavg(idle, "beds")))
	var scream := _windows.filter(func(w): return w["M_Scream"] > -45.0)
	var killw := _windows.filter(func(w): return w["M_Kill"] > -45.0)
	if not scream.is_empty():
		var rest := []
		for w in scream:
			var o: float = pow(10.0, w["M_Music"] / 10.0) + pow(10.0, w["beds"] / 10.0) + pow(10.0, w["M_Story"] / 10.0) + pow(10.0, w["M_Whisper"] / 10.0) + pow(10.0, w["M_PA"] / 10.0)
			rest.append({"o": _db(o)})
		print("MIX  the technician's SCREAM: %.1f dB RMS (n=%d, loudest window %.1f)   everything else then %.1f   music then %.1f   beds %.1f   the victim scene %.1f" % [
			_pavg(scream, "M_Scream"), scream.size(), scream.map(func(w): return w["M_Scream"]).max(), _pavg(rest, "o"),
			_pavg(scream, "M_Music"), _pavg(scream, "beds"), _pavg(scream, "M_Story")])
	if not killw.is_empty():
		print("MIX  the KILL STING (flat, -8 dB): %.1f dB RMS (n=%d, loudest window %.1f)" % [_pavg(killw, "M_Kill"), killw.size(),
			killw.map(func(w): return w["M_Kill"]).max()])
	print("MIX  PA lines: PA - music = %+.1f dB (target >= +6)" % (_pavg(pa, "M_PA") - _pavg(pa, "M_Music")))
	print("MIX  whisper: whisper - music = %+.1f dB (target >= +6)" % (_pavg(whisper, "M_Whisper") - _pavg(whisper, "M_Music")))
	print("MIX  other story: story - music = %+.1f dB" % (_pavg(story, "M_Story") - _pavg(story, "M_Music")))
	print("MEDIAN per 0.1 s window:  between beats music - beds %+.1f   PA - music %+.1f   whisper - music %+.1f   (10th percentile: %+.1f / %+.1f / %+.1f)" % [
		_pct(idle, "M_Music", "beds", 0.5), _pct(pa, "M_PA", "M_Music", 0.5), _pct(whisper, "M_Whisper", "M_Music", 0.5),
		_pct(idle, "M_Music", "beds", 0.1), _pct(pa, "M_PA", "M_Music", 0.1), _pct(whisper, "M_Whisper", "M_Music", 0.1)])
	print("MIX  silences: music %.1f dB   after threshold_quiet: music %.1f dB" % [_pavg(silence, "M_Music"), _pavg(quiet, "M_Music")])
	# a 2 s timeline for the eye
	var i := 0
	while i < _windows.size():
		var chunk := _windows.slice(i, mini(i + 20, _windows.size()))
		var w0: Dictionary = chunk[0]
		print("  t=%6.1f  music %6.1f (vol %6.1f)  beds %6.1f  PA %6.1f  story %6.1f  whisper %6.1f  total %6.1f  amb-bus %5.1f%s" % [
			float(w0["t"]), _pavg(chunk, "M_Music"), float(w0["music_vol"]), _pavg(chunk, "beds"), _pavg(chunk, "M_PA"),
			_pavg(chunk, "M_Story"), _pavg(chunk, "M_Whisper"), _pavg(chunk, "total"), float(w0["ambbus"]),
			"" if w0["music_playing"] else "  (music stopped)"])
		i += 20
