extends Node
class_name AudioBuses

# The minimal bus layout, created at runtime.
#
# SCARY.md §4.1(a) specs a five-bus project layout in a `default_bus_layout.tres`. This
# is deliberately NOT that: there is no bus configuration in `project.godot` at all today
# and the only buses that have ever existed here are `Master` and the runtime
# `"Backrooms"` bus (`backrooms.gd:_ensure_bus`). Following that existing runtime pattern
# keeps the change to one file and cannot break a level by a mis-pathed resource; the
# full layout can land later without contradicting anything here.
#
# Two buses, and the split exists for exactly one reason:
#
#   Master
#   ├── Ambience   beds, room tone, world loops   ← duckable
#   └── Body       heartbeat, footsteps           ← NEVER ducked
#
# ⚠️ `Body` staying un-duckable is what makes every silence effect work. When the world
# goes quiet your own pulse must be the only thing left — that is the entire payload of
# `HoldBreath` and of Backrooms Zone 2's `SilenceZone`. Ducking `Master` instead would
# duck the heartbeat too and destroy the effect it exists to create, which is why
# HoldBreath could not be built before this file existed.

const AMBIENCE := "Ambience"
const BODY := "Body"


# Create `bus_name` if it does not exist; return its index.
#
# ⚠️ Per-level beds NEST UNDER `Ambience` rather than hanging off Master. The Backrooms
# and THE NIGHTMARE each create their own bus so a `SilenceZone` can duck that level's bed
# alone — but if those buses sent straight to Master, a `HoldBreath` dip of `Ambience`
# would do NOTHING in the two levels that most need it (the Backrooms fires `flash_scare`
# on every wrong wall). Nesting gives both: the level ducks its own bus, the global effect
# ducks the parent, and the two compose instead of competing.
#
# Godot resolves a send by name and a bus may only send to one created BEFORE it, which is
# why the `Ambience`/`Body` pair is forced into existence first.
static func ensure(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return idx
	# Core buses hang off Master; everything else nests under Ambience.
	var send := "Master"
	if bus_name != AMBIENCE and bus_name != BODY:
		ensure(AMBIENCE)
		send = AMBIENCE
	idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)
	return idx


# Called once from GameState._ready(), which runs before any scene — so the two core
# buses always exist before a level or a player tries to route audio to them.
static func ensure_core() -> void:
	ensure(AMBIENCE)
	ensure(BODY)
	ensure_master_limiter()


# ⭐ A hard limiter on Master (2026-09-03). The FIRST AudioEffect this project has ever had —
# `grep -rn "AudioEffect" game/scripts/` returned zero hits before this line.
#
# ⚠️ WHY. `screamer.gd` plays every sting at a hard-coded 0 dB, several of those files peak at
# exactly 0.0 dBFS, and on 2026-09-03 nine more were re-mastered UP toward that ceiling
# (`tools/remaster_scares.py`, `tools/sfx_loudness.py`). Meanwhile the heartbeat is on `Body`
# at up to 0 dB, level beds run on `Ambience`, and `_play_at()` one-shots land on Master — and
# a fatal screamer is exactly the moment all of them are loudest at once. Summed, that clips
# the output device, and device clipping does not sound like a loud scream, it sounds like a
# broken speaker. This is protection, not loudness: it does nothing at all until the sum
# exceeds the ceiling.
#
# ⚠️ IT MUST BE IDEMPOTENT. `reset_all()` runs on EVERY level load and `ensure_core()` is
# reachable more than once; adding the effect blindly would stack a limiter per level until
# the mix audibly collapsed. The name check is the guard, and `check_scare_loudness.gd`
# (§3, not `check_audio_buses.gd`) asserts there is exactly one after repeated calls.
const LIMITER_CEILING_DB := -0.5
const LIMITER_NAME := "MasterLimiter"

# ⚠️ THIS IS THE ONE THING IN THE PROJECT THAT TOUCHES `Body`'S OUTPUT, AND THE HEADERS SAYING
# "Body is NEVER ducked" ARE STILL TRUE AS WRITTEN. They are about the DUCKING system — nothing
# routes a `SilenceZone`, a `HoldBreath.dip()` or a level bed through the heartbeat and footsteps,
# so your own pulse survives every hush in the game, which is the property those headers protect.
# What a Master limiter does is different in kind: it is a CEILING on the sum, it is static, it
# applies equally to every bus, and it only acts at all once the SUM is past `LIMITER_CEILING_DB`
# (−0.5 dBFS) — i.e. in exactly the moments that were previously raw clipping. A scream plus a bed
# plus a heartbeat will now pull the heartbeat down instead of distorting all three. ⚠️ How far
# down is however far the sum overshoots −0.5 dBFS, not a fixed "fraction of a dB", and Godot
# 4.6.3's `AudioEffectHardLimiter` holds that reduction for its `release` (0.1 s default) after
# the peak — so the duck outlasts the transient that caused it. That is the trade being made, and
# it is the right one: brief, program-dependent gain reduction beats device clipping. ⚠️ Do not "fix" that by exempting `Body`: routing the heartbeat around the
# limiter would put an unlimited signal back on Master and undo the reason this exists.
static func ensure_master_limiter() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master == -1:
		return
	for i in range(AudioServer.get_bus_effect_count(master)):
		var fx := AudioServer.get_bus_effect(master, i)
		if fx and fx.resource_name == LIMITER_NAME:
			return
	var lim := AudioEffectHardLimiter.new()
	lim.resource_name = LIMITER_NAME
	lim.ceiling_db = LIMITER_CEILING_DB
	AudioServer.add_bus_effect(master, lim)


# How many limiters are on Master. Exists so a test can assert "exactly one" without
# reaching into AudioServer and re-implementing the name check it is trying to verify.
static func master_limiter_count() -> int:
	var master := AudioServer.get_bus_index("Master")
	if master == -1:
		return 0
	var n := 0
	for i in range(AudioServer.get_bus_effect_count(master)):
		var fx := AudioServer.get_bus_effect(master, i)
		if fx and fx.resource_name == LIMITER_NAME:
			n += 1
	return n


# ⭐ A bus for a level's SCORE, sent to Master rather than nested under `Ambience`.
#
# `ensure()` deliberately nests every level bed under `Ambience` so a global dip reaches it.
# That is right for room tone and wrong for music: the Corridor ducks `Ambience` by 40 dB
# for its last 25 m (`_tick_hush`), which is meant to take the WORLD away — the whispers,
# the ambient one-shots — and used to take the score with it, leaving the walk to the fall
# in silence. The user's call on 2026-08-15 was that the music plays for the whole level.
#
# ⚠️ Music on this bus is therefore NOT duckable by `HoldBreath` or a `SilenceZone` either.
# That is the trade and it is the same one `kontur.gd` already makes by leaving
# `kontur_music` on Master. If a level ever wants its score ducked, put it on `Ambience`.
static func ensure_music_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return idx
	idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	return idx


# ⭐ Put every bus back to 0 dB. Called by `GameState.start_current_level()` on EVERY level
# load, and it is a guarantee rather than a tidy-up.
#
# ⚠️ AudioServer buses are GLOBAL and survive `change_scene_to_file`. Nothing about a scene
# change resets a volume, `ensure()` early-returns without touching one, and every per-level
# bed bus nests under `Ambience` — so a single level that ducks a bus and forgets to restore
# it silences every level that follows, for the rest of the process.
#
# That is not hypothetical. `corridor.gd:_tick_hush()` tweened `Ambience` to -40 dB at 296 m
# with no restore of any kind, which is why the Backrooms music was missing on arrival from
# the Corridor but present when the Backrooms was loaded directly (reported 2026-08-15). The
# same shape is latent in `dungeon.gd:_duck_bus()`, which has no `_exit_tree` guard.
#
# A level that wants a duck should still restore it itself; this is the floor under that.
static func reset_all() -> void:
	for i in range(AudioServer.bus_count):
		AudioServer.set_bus_volume_db(i, 0.0)
		AudioServer.set_bus_mute(i, false)
