extends SceneTree

# Are the scare stings actually loud, and is the fatal path actually built the way the docs say?
#
#   Godot --headless --path game --script res://tests/check_scare_loudness.gd
#
# ⚠️ WHY THIS EXISTS. `screamer.gd` plays every sting at a hard-coded 0.0 dB on Master —
# `flash_scare()` takes no gain argument and `trigger()` sets no `volume_db` — so THE FILE IS
# THE VOLUME CONTROL and nothing in the project measured it. Measured 2026-09-03, the eight
# fatal per-level screamers spanned -12.62 to -0.18 dBFS (loudest-300 ms). `screamer_lab`, the
# very first death a player ever sees, was the quietest thing the code path could play.
#
# ⚠️ AND THE FATAL PATH DID NOT MATCH ITS OWN DOCUMENTATION. `CLAUDE.md` has always described
# "black flash -> screamer image -> loud audio burst"; the code showed the black panel and the
# face in the SAME frame (the image is a child of the panel) and played the scream on the next
# line, over an unducked ambience bed. `flash_scare()` had ducked since HoldBreath landed; the
# fatal path never had. That is now `_black_then_scream()`, and this test is what stops it
# regressing to a one-liner again.
#
# THREE THINGS ASSERTED, and the third is the one nothing else can see:
#   1. every LEVEL_SCREAMERS entry resolves to a real stream (a missing file silently falls
#      back to the shared pool AND overwrites the audio — see `_apply_level_av`);
#   2. every sting's decoded loudest-300 ms clears a floor;
#   3. the Master limiter exists EXACTLY ONCE after repeated `ensure_core()` + `reset_all()`,
#      which is the failure mode of adding an effect on a path that runs every level load.
#
# ⚠️ THE LOUDNESS IS MEASURED FROM THE IMPORTED STREAM'S OWN SAMPLES, never from a constant
# shared with `tools/remaster_scares.py`. A test that asserts the number the generator typed
# agrees with the generator by construction and measures nothing.

# base name -> floor in dBFS for the loudest 300 ms.
#
# ⚠️ These are FLOORS, set below what was measured after the 2026-09-03 pass so an ordinary
# re-render cannot trip them, but far above where these files used to sit. The comment on each
# row is the measured value at the time it was written; if you raise a floor, re-measure.
const FLOORS := {
	# --- the eight fatal per-level screamers (Screamer.LEVEL_SCREAMERS) ---------------
	"screamer_lab": -5.0,          # was -12.61, now -3.00  (+9.61, tools/remaster_scares.py)
	"screamer_house": -6.0,        # -4.14, already dense; saturating it bought +1.15 for drive 9
	"screamer_corridor": -6.0,     # -3.90
	"all_levels_screamer": -3.0,   # -0.23
	# ⚠️ -7.0 and UNTOUCHED. The 2026-09-03 pass tried to raise this and put the file BACK: the
	# linked per-channel gain pushed its loudest channel 2.82 dB past its own peak, and re-ceiling
	# that left a net gain of +0.36 dB — under MIN_WORTH_DB. A strongly asymmetric stereo file
	# cannot be densified from its mono sum without either clipping or being attenuated.
	"kontur_scream": -7.0,         # -6.18, original bytes
	"level_6_jumpscare": -6.0,     # -4.19
	"screamer_dungeon": -6.0,      # -3.87
	"screamer_void": -6.0,         # -4.22
	# --- survivable flash_scare payloads ---------------------------------------------
	"jumpscare": -4.0,             # -2.14, the reference "this is what loud sounds like"
	"nook_scream": -6.0,           # -3.71
	"crate_shriek": -6.0,          # -3.41
	"screamer_manager": -4.0,      # -1.71
	"dark_jumpscare": -3.0,        # -0.18
	"screamer_forest": -6.0,       # -3.13
	"apparition_snarl": -5.0,      # -2.21
	# --- generated stings, raised via write_wav(loud=) in tools/make_sfx*.py ----------
	"glass_shatter": -12.0,        # was -22.49, now -9.47  (+13.01) — the biggest single win
	"matron_shriek": -7.0,         # was -14.70, now -4.00  (+10.70)
	"screamer_kontur": -5.0,       # was -10.75, now -3.00  (+7.75)
	"screamer_breach": -5.0,       # was -10.47, now -3.00  (+7.47)
	"kontur_flash": -10.0,         # was -14.68, now -7.61  (+7.07)
	"child_laugh": -8.0,           # was -12.88, now -5.98  (+6.90)
	"beartrap_snap": -12.0,        # was -17.99, now -9.88  (+8.11)
	"frame_ignite": -10.0,         # was -12.35, now -7.98  (+4.37)
	"hollow_reveal": -8.0,         # was -8.13, now -5.27   (+2.86)
	"creature_growl_near": -8.0,   # was -8.79, now -5.98   (+2.80)
	"childe_scream": -7.0,         # was -6.97, now -4.97   (+2.00)
	# ⚠️ -9.0 and UNTOUCHED, same reason and worse: 7.38 dB of channel overshoot, net -4.44 after
	# re-ceiling, i.e. the "improvement" would have made it quieter AND clipped 17.97 % of its
	# samples. The first pass shipped exactly that before an audit probe measured it.
	"fridge_scream": -9.0,         # -8.02, original bytes
}

# Deliberately NOT in FLOORS, with the reason. Checked so the exclusion cannot rot into
# "we forgot about these".
const QUIET_ON_PURPOSE := {
	"half_scream": "RandomAmbient's distant 12-panic event — 'distant' is the design",
	"distant_scream": "the word 'distant' is the design",
	"light_pop": "a bulb dying, not a scare",
}

# ⭐ CLIPPING BASELINE — percentage of samples at full scale, measured 2026-09-03.
#
# ⚠️ THIS IS A REGRESSION GUARD, NOT A QUALITY BAR, and the first version got that wrong. An
# absolute "no more than 5 % at full scale" turned red on three files nobody had touched:
# `jumpscare.wav` **34.27 %**, `screamer_manager.wav` **24.54 %**, `level_6_jumpscare` 5.48 %.
# Those are sourced assets that arrived brickwalled; they are the loudest things in the game and
# always have been. A threshold low enough to be a quality bar condemns them, and one high enough
# to permit them (40 %) would not have caught the actual defect — `fridge_scream.ogg` going from
# 2.92 % to 17.97 % on the first remaster pass, which is a doubling-and-a-half of a file that was
# fine before.
#
# ⚠️ So the question this asks is "did THIS file get worse", and the answer needs a per-file
# number. `CLIP_SLACK` absorbs re-encode jitter; anything beyond it is a real change and should
# be re-measured deliberately rather than by widening the slack.
const CLIP_SLACK := 3.0
const CLIP_BASELINE := {
	"acid_hiss": 0.00,
	"ambient_breach": 0.00,
	"ambient_dungeon": 0.00,
	"apparition_drone": 0.00,
	"beartrap_snap": 0.00,
	"blast_door_slam": 0.00,
	"bone_scrape": 0.00,
	"breaker_buzz": 0.00,
	"breaker_hum": 0.00,
	"breaker_spark": 0.00,
	"breaker_throw": 0.00,
	"breathing_behind": 0.00,
	"candle_blow": 0.00,
	"candle_die": 0.00,
	"candle_light": 0.00,
	"chase": 0.00,
	"child_laugh": 0.00,
	"child_peek": 0.00,
	"childe_scream": 0.00,
	"clock_chime": 0.00,
	"cot_sleep": 0.00,
	"crate_shriek": 0.00,
	"creature_growl_near": 0.00,
	"distant_scream": 0.00,
	"door_batter": 0.00,
	"door_break": 0.00,
	"door_seal": 0.00,
	"door_slam": 0.00,
	"emergency_hum": 0.00,
	"flood_haul": 0.00,
	"flood_knock": 0.00,
	"floor_creak": 0.00,
	"fluorescent_buzz_on": 0.00,
	"fluorescent_hum": 0.00,
	"footstep_trail": 0.00,
	"footsteps_above": 0.00,
	"frame_ignite": 0.00,
	"frame_weep": 0.00,
	"fridge_hum": 0.00,
	"glass_break": 0.00,
	"glass_shatter": 0.00,
	"gurney_creak": 0.00,
	"half_scream": 0.00,
	"hollow_knock": 0.00,
	"hollow_reveal": 0.00,
	"jumpscare": 34.27,
	"kontur_flash": 0.00,
	"lamp_wake": 0.00,
	"level_6_jumpscare": 5.48,
	"light_pop": 0.00,
	"lock_buzz": 0.00,
	"locker_settle": 0.00,
	"locker_shove": 0.00,
	"matron_shriek": 0.00,
	"matron_step": 0.00,
	"matron_theme": 0.00,
	"mirror_stare": 0.00,
	"mirror_wake": 0.00,
	"music_box": 0.00,
	"nook_breath": 0.00,
	"nook_scream": 4.75,
	"object12_cell": 0.00,
	"painting_fall": 0.00,
	"pedestal_alarm": 0.00,
	"perekozhnik_shed": 0.00,
	"phone_smash": 0.00,
	"phone_whisper": 0.00,
	"piece_lift": 0.00,
	"pipe_groan": 0.00,
	"plate_done": 0.00,
	"plate_hum": 0.00,
	"plate_ring": 0.00,
	"plate_set": 0.00,
	"rotary_ring": 0.00,
	"sconce_light": 0.00,
	"screamer_breach": 0.00,
	"screamer_kontur": 0.00,
	"screamer_lab": 0.00,
	"screamer_manager": 24.54,
	"seam_draw": 0.00,
	"seam_rip": 0.00,
	"shield_drain_loop": 0.00,
	"shield_stagger": 0.00,
	"skeleton_fall": 0.00,
	"spark_flint": 0.00,
	"sprawl_call_far": 0.00,
	"sprawl_call_near": 0.00,
	"sprawl_wall_hum": 0.00,
	"switch_clunk": 0.00,
	"telegraph_groan": 0.00,
	"tv_static": 0.00,
	"wade_distant": 0.00,
	"wade_step": 0.00,
	"water": 0.00,
	"water_drip": 0.00,
	"wheelchair": 41.38,
	"whisper_dungeon": 0.00,
	"whispers": 0.00,
}

const WINDOW_S := 0.300

var _fails: Array[String] = []
var _checks := 0


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


# Read a SOURCE .wav off disk and return mono floats.
#
# ⚠️ THE IMPORTED STREAM IS NOT DECODABLE AND THAT IS NOT A BUG. Every .wav.import in this
# project carries `compress/mode=2`, i.e. Godot 4 imports them as **QOA**, so the runtime
# `AudioStreamWAV.data` is QOA-compressed and `format` is FORMAT_QOA — there is no way to read
# samples out of it from GDScript. The first version of this test measured the imported stream
# and reported "0 of 27 measured", which would have been a green vacuous pass had the
# sample-count guard below not been written first.
#
# Reading the source file is also the more honest measurement: it is exactly the bytes
# `tools/remaster_scares.py` and `tools/make_sfx*.py` wrote, with no lossy re-encode in between.
#
# ⚠️ It handles BOTH PCM16 (format tag 1) and IEEE FLOAT32 (tag 3). `screamer_void.wav` is
# float32 — Python's own `wave` module refuses that file with "unknown format: 3", which is how
# the remaster tool found out. A parser that assumed PCM16 would read its bytes as garbage and
# report a confident wrong number.
func _decode_wav(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var bytes := f.get_buffer(f.get_length())
	f.close()
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return []
	var fmt_tag := 0
	var channels := 1
	var bits := 16
	var pos := 12
	var out: Array[float] = []
	while pos + 8 <= bytes.size():
		var cid := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var csize := bytes.decode_u32(pos + 4)
		var body := pos + 8
		if cid == "fmt ":
			fmt_tag = bytes.decode_u16(body)
			channels = maxi(1, bytes.decode_u16(body + 2))
			bits = bytes.decode_u16(body + 14)
		elif cid == "data":
			var stride := bits / 8
			var frames := int(csize) / (stride * channels)
			for i in range(frames):
				var acc := 0.0
				for c in range(channels):
					var o := body + (i * channels + c) * stride
					if o + stride > bytes.size():
						break
					if fmt_tag == 3 and bits == 32:
						acc += bytes.decode_float(o)
					elif bits == 16:
						acc += float(bytes.decode_s16(o)) / 32768.0
					elif bits == 8:
						acc += (float(bytes.decode_u8(o)) - 128.0) / 128.0
					elif bits == 32:
						acc += float(bytes.decode_s32(o)) / 2147483648.0
				out.append(acc / channels)
			return out
		# Chunks are word-aligned; an odd size carries a pad byte that is not counted in csize.
		pos = body + int(csize) + (int(csize) & 1)
	return out


# Where load_audio() would find `base` as a .wav, or "" if it only exists compressed.
func _wav_path(gs: Node, base: String) -> String:
	for subdir in gs.get("AUDIO_SUBDIRS"):
		var path := "res://assets/audio/%s/%s.wav" % [subdir, base]
		if FileAccess.file_exists(path):
			return path
	return ""


func _loudest_window_db(samples: Array, sr: int) -> float:
	var n := samples.size()
	if n == 0:
		return -99.0
	var w := mini(n, maxi(1, int(sr * WINDOW_S)))
	# Prefix sum of squares — the naive per-window resum is O(n*w) and on a 10 s file that is
	# slow enough to tempt subsampling, which is how a measurement stops finding the peak.
	var prefix := PackedFloat64Array()
	prefix.resize(n + 1)
	prefix[0] = 0.0
	for i in range(n):
		var s: float = samples[i]
		prefix[i + 1] = prefix[i] + s * s
	var best := 0.0
	for i in range(0, n - w + 1):
		var ms: float = (prefix[i + w] - prefix[i]) / float(w)
		if ms > best:
			best = ms
	if best <= 0.0:
		return -99.0
	return 20.0 * log(sqrt(best)) / log(10.0)


# ⚠️ EVERYTHING RUNS ON THE FIRST _process FRAME, not in _initialize(), and both halves of that
# are load-bearing:
#   * autoloads must be reached through the tree, never as bare identifiers — a `--script` test
#     is PARSED before they register, so `GameState.load_audio(...)` is a COMPILE error here
#     even though it is valid everywhere in game/scripts (check_journal.gd:22 has the same note);
#   * and during `_initialize()` the tree is not active yet, so even `get_node("/root/GameState")`
#     fails with "Can't use get_node() with absolute paths from outside the active scene tree".
func _process(_delta: float) -> bool:
	print("== SCARE LOUDNESS ==")
	var gs := root.get_node_or_null("GameState")
	_ok("GameState autoload present", gs != null)
	if gs == null:
		quit(1)
		return true
	var buses = load("res://scripts/audio_buses.gd")

	# ---------------------------------------------------------------- 1. every entry resolves
	var screamer := root.get_node_or_null("Screamer")
	_ok("the Screamer autoload is present", screamer != null)
	var table: Dictionary = screamer.get("LEVEL_SCREAMERS") if screamer else {}
	_ok("LEVEL_SCREAMERS covers levels 1..8", table.size() >= 8, "%d entries" % table.size())
	for lvl in table.keys():
		var entry: Array = table[lvl]
			# ⚠️ LEVEL_SCREAMERS already stores a full res:// path. Prepending the texture dir
		# produced "res://assets/textures/res://assets/textures/..." and eight confident
		# failures on files that were present all along.
		var img: String = str(entry[0])
		var base: String = str(entry[1])
		_ok("level %s image exists" % str(lvl), ResourceLoader.exists(img), img)
		# ⚠️ `_apply_level_av()` falls through to the SHARED pool if the image is missing, and
		# that fallback overwrites the AUDIO too — so a missing picture silently changes which
		# scream a level dies to. Both halves are asserted for that reason.
		_ok("level %s audio '%s' resolves" % [str(lvl), base],
			gs.load_audio(base) != null)

	# ---------------------------------------------------------------- 2. loudness floors
	var measured := 0
	var unmeasurable: Array[String] = []
	for base in FLOORS.keys():
		if gs.load_audio(String(base)) == null:
			_ok("'%s' resolves" % base, false, "load_audio returned null")
			continue
		var wpath := _wav_path(gs, String(base))
		if wpath == "":
			# .ogg / .mp3 — no sample access from GDScript. Recorded, never passed off as OK.
			unmeasurable.append(String(base))
			continue
		var samples := _decode_wav(wpath)
		if samples.is_empty():
			unmeasurable.append(String(base) + "(unparsed)")
			continue
		var loud := _loudest_window_db(samples, 44100)
		var floor_db: float = FLOORS[base]
		measured += 1
		_ok("'%s' loudest-300ms >= %.1f dBFS" % [base, floor_db], loud >= floor_db,
			"measured %.2f" % loud)

	_ok("measured at least half the table from real samples",
		measured >= FLOORS.size() / 2,
		"%d of %d measured; %d in compressed containers: %s"
			% [measured, FLOORS.size(), unmeasurable.size(), ", ".join(unmeasurable)])

	# ⚠️ A positive control. Without it, a `_decode_wav()` that quietly returned [] for
	# everything would report "0 measured" and every floor assertion would simply never run —
	# the vacuous pass this suite exists to refuse. It writes a real -40 dBFS WAV and requires
	# the same parser and the same window maths to call it quiet.
	var ctrl_path := "user://loudness_control.wav"
	var cf := FileAccess.open(ctrl_path, FileAccess.WRITE)
	var n_ctrl := 44100
	cf.store_buffer("RIFF".to_ascii_buffer())
	cf.store_32(36 + n_ctrl * 2)
	cf.store_buffer("WAVEfmt ".to_ascii_buffer())
	cf.store_32(16); cf.store_16(1); cf.store_16(1)
	cf.store_32(44100); cf.store_32(88200); cf.store_16(2); cf.store_16(16)
	cf.store_buffer("data".to_ascii_buffer())
	cf.store_32(n_ctrl * 2)
	for i in range(n_ctrl):
		cf.store_16(int(sin(TAU * 220.0 * i / 44100.0) * 0.01 * 32767.0) & 0xFFFF)
	cf.close()
	var ctrl_db := _loudest_window_db(_decode_wav(ctrl_path), 44100)
	_ok("CONTROL: a -40 dBFS tone measures as quiet", ctrl_db < -30.0 and ctrl_db > -60.0,
		"measured %.2f (a pass at a high value means the parser is broken)" % ctrl_db)

	# ---------------------------------------------------------------- 2b. nothing is CLIPPED
	# ⚠️ ADDED 2026-09-03, and it is the assertion that was missing when this file shipped. A
	# loudness pass can raise a file's average level and simultaneously ruin it, and NOTHING here
	# looked: the first pass pushed `fridge_scream.ogg` to **17.97 % of samples at full scale**
	# (from 2.92 %) and `kontur_scream.ogg` to 1.71 %, because `remaster_scares.py` derived a gain
	# from the MONO SUM and applied it per channel. Found by an audit probe. A floor on loudness
	# with no ceiling on clipping rewards exactly the wrong thing.
	# ⚠️ A few samples at full scale are normal for a peak-normalised sting; a PERCENTAGE is what
	# distinguishes "it touches 0 dBFS" from "it is squared off".
	var clipped_bad: Array[String] = []
	for base in FLOORS.keys():
		var wp := _wav_path(gs, String(base))
		if wp == "":
			continue
		var s := _decode_wav(wp)
		if s.is_empty():
			continue
		var at_full := 0
		for v in s:
			if absf(v) >= 0.9995:
				at_full += 1
		var frac: float = 100.0 * float(at_full) / float(s.size())
		var allowed: float = float(CLIP_BASELINE.get(base, 2.0)) + CLIP_SLACK
		if frac > allowed:
			clipped_bad.append("%s %.2f%% (was %.2f%%)"
				% [base, frac, float(CLIP_BASELINE.get(base, 0.0))])
	_ok("no sting got MORE clipped", clipped_bad.is_empty(),
		"grew past its baseline + %.1f points: %s" % [CLIP_SLACK, ", ".join(clipped_bad)])

	# ---------------------------------------------------------------- 3. the Master limiter
	# Idempotence is the whole risk: `reset_all()` runs on EVERY level load, so an effect added
	# without a guard stacks one limiter per level until the mix audibly collapses.
	buses.ensure_core()
	buses.reset_all()
	buses.ensure_core()
	buses.ensure_core()
	buses.reset_all()
	_ok("exactly ONE Master limiter after repeated ensure_core()/reset_all()",
		buses.master_limiter_count() == 1,
		"count = %d" % buses.master_limiter_count())

	# ---------------------------------------------------------------- 4. the fatal path shape
	var src := FileAccess.get_file_as_string("res://scripts/screamer.gd")
	_ok("trigger() goes through _black_then_scream()", src.contains("await _black_then_scream()"))
	_ok("the black beat hides the image first",
		src.contains("_screamer_image.visible = false"))
	_ok("the fatal path ducks Ambience like flash_scare does",
		src.count("HoldBreath.dip(get_tree(), PRE_SCARE_SILENCE)") >= 2,
		"%d dip call sites" % src.count("HoldBreath.dip(get_tree(), PRE_SCARE_SILENCE)"))
	# ⚠️ The hold must come OUT of RESTART_DELAY, not be added to it: a longer gap between death
	# and reload is a worse game, and the black beat is meant to be free.
	_ok("BLACK_HOLD is subtracted from RESTART_DELAY, not added",
		src.contains("RESTART_DELAY - BLACK_HOLD"))

	for k in QUIET_ON_PURPOSE.keys():
		_ok("'%s' is deliberately excluded from the floors" % k, not FLOORS.has(k),
			str(QUIET_ON_PURPOSE[k]))

	print("== %d checks, %d failed ==" % [_checks, _fails.size()])
	for f in _fails:
		print("   FAILED: " + f)
	quit(1 if _fails.size() > 0 else 0)
	return true
