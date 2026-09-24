extends SceneTree

# MEASURE the ceiling drop at the listener (2026-09-24, the user: "the noise of the red object falling
# from the ceiling … should be louder"). A real walk under the hatch in ApproachContainment; the Master
# bus is captured (the Dummy driver mixes headless) in 0.1 s RMS windows: the 1.5 s before the drop fires
# as the background, then the 3 s after. Reference points from probe_breach_music_mix (same method):
# the technician's scream -14.8 dB, the kill sting -10.8 dB.
const SCENE := "res://scenes/level_6_breach.tscn"
const WIN := 0.1
var _cap: AudioEffectCapture
var _rows: Array = []        # [t, db]
var _acc := 0.0
var _n := 0
var _t := 0.0
var _started := 0
var _run_on := false


func _initialize() -> void:
	_started = Time.get_ticks_msec()
	change_scene_to_file(SCENE)
	_run.call_deferred()


func _process(delta: float) -> bool:
	if Time.get_ticks_msec() - _started > 120000:
		print("probe timed out")
		quit(1)
	if _run_on and _cap:
		var k := _cap.get_frames_available()
		if k > 0:
			for f in _cap.get_buffer(k):
				_acc += (f.x * f.x + f.y * f.y) * 0.5
				_n += 1
		_t += delta
		if _t >= WIN and _n > 0:
			_rows.append([Time.get_ticks_msec() / 1000.0, 10.0 * log(maxf(_acc / _n, 1e-12)) / log(10.0)])
			_acc = 0.0
			_n = 0
			_t = 0.0
	return false


func _run() -> void:
	_cap = AudioEffectCapture.new()
	_cap.buffer_length = 1.0
	AudioServer.add_bus_effect(0, _cap, AudioServer.get_bus_effect_count(0))
	await create_timer(1.6).timeout
	var level := current_scene
	var player: CharacterBody3D = level.get_node("Player")
	var approach: Node = level.get("_approach")
	player.set("ai_active", true)
	player.global_position = Vector3(-13.0, 0.1, -26.0)
	player.rotation.y = -PI / 2.0
	await create_timer(0.5).timeout
	_cap.clear_buffer()
	_run_on = true
	var fired_at := -1.0
	var e := 0.0
	while e < 9.0:
		player.call("ai_look_at", Vector3(0.0, 1.6, -26.0))
		player.set("ai_move_dir", Vector2(0, -1) if player.global_position.x < -8.4 else Vector2.ZERO)
		await physics_frame
		e += 1.0 / Engine.physics_ticks_per_second
		if fired_at < 0.0 and (approach.call("beat_names") as PackedStringArray).has("ceiling_drop"):
			fired_at = Time.get_ticks_msec() / 1000.0
		if fired_at > 0.0:
			var dt := Time.get_ticks_msec() / 1000.0 - fired_at
			if absf(dt - 0.3) < 0.01 or absf(dt - 1.1) < 0.01 or absf(dt - 2.8) < 0.01:
				print("  beds duck at +%.1f s: %.1f dB" % [dt, float(approach.get("_duck_db"))])
		if fired_at > 0.0 and Time.get_ticks_msec() / 1000.0 - fired_at > 3.2:
			break
	_run_on = false
	if fired_at < 0.0:
		print("the drop never fired")
		quit(1)
		return
	var before: Array = []
	var after: Array = []
	for r in _rows:
		if r[0] < fired_at and r[0] > fired_at - 1.5:
			before.append(r[1])
		elif r[0] >= fired_at and r[0] <= fired_at + 3.0:
			after.append(r[1])
	var peak := -200.0
	for v in after:
		peak = maxf(peak, v)
	var first := 0.0
	var cnt := 0
	for i in mini(10, after.size()):
		first += pow(10.0, after[i] / 10.0)
		cnt += 1
	var bg := 0.0
	for v in before:
		bg += pow(10.0, v / 10.0)
	print("DROP  background %.1f dB  |  loudest 0.1 s window %.1f dB  |  first 1.0 s %.1f dB  |  (scream ref -14.8, kill ref -10.8)"
		% [10.0 * log(bg / maxf(1, before.size())) / log(10.0), peak, 10.0 * log(first / maxf(1, cnt)) / log(10.0)])
	quit(0)
