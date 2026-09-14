extends Node3D

# LEVEL 7 — THE NIGHTMARE (DUNGEON_NIGHTMARES.md).
#
# You are put to sleep. There is no light down here but a candle that burns for
# sixty seconds, and you have four. The dungeon rearranges itself every time, so
# there is nothing to memorise and nothing to trust except your ears — which is
# fine, because the only thing you actually need to hear is the moment the wind
# stops. That is when something else is in here with you. It walks slower than you
# do. You will never have to run from it, and if you do run you will not hear the
# next one coming.
#
# ⭐⭐ "HARD TO LOSE, EASY TO BE SCARED" (2026-09-12, the user's verdict on the first hand
# playtest: *"it is very simple to get killed in this level. I think it should not be that way"*).
# The six-seed completion bot agreed: 0 wins, 2 deaths, 4 budgets burned wandering — six
# independent death paths (the Matron's touch, a statue's lunge, a spark near a statue, the
# invisible Hollow One, a painting at 5 sconces, the beartraps) in a level whose thesis is
# keeping your nerve. Every one of them is gone. THE PANIC BAR IS THE ONLY DEATH:
#   - the HUNTER (the Parasite, a new model) catches you: an in-world lunge into the camera, a
#     sting, +CATCH_PANIC, and it lets go — the wave is over
#   - a Still One reaches you: a survivable face flash, +STARTLE_PANIC, and it topples for good
#   - a Weeping Frame stared at past 5 sconces burns out (gaze panic was the whole price)
#   - the Hollow One and the beartraps are cut; the spark is a free burst of light that still
#     wakes the statues
# and the scares moved from a COUNT LADDER to the ROOMS: every chamber is dealt an archetype
# (dungeon_gen.gd:_deal_kinds, dungeon_rooms.gd) with its own props and its one scare. The
# sconce count keeps two gates: the hunter wakes at 3, the finale at 7. The lattice grew to
# 24x24 and there is a found MAP (dungeon_map_ui.gd) that draws only what you have walked.
#
# ── The rules that make the chase survivable without removing it (§B1, kept) ──────
# 1. The hunter's chase speed is 3.4 m/s — BELOW the player's 4.0 walk. Walking
#    away always works. Sprinting is a shortcut you may buy with panic.
# 2. The tell arrives before contact is possible and is free to act on: it SCREAMS
#    every 10-20 s while it hunts, and the chase cue plays only once it has seen you.
# 3. ⭐ SPRINTING DEAFENS YOU. Your own footsteps mask the hunter's steps and calls.
# 4. The silence does not damage you — it stops you HEALING. set_no_decay(true),
#    zero additive pressure. Net panic change from a monster's mere presence is 0.
# 5. It hunts by EAR: sprinting, a spark, a slammed door and a sconce catching all
#    call it. Walking quietly is the technique; running is the emergency brake.
#
# ⚠️ §B10's bans are HARD and every one of them is a double-jeopardy audit item.
# NO DarkZone (the darkness is the medium, not the penalty — Issue 18), NO
# DreadZone, NO enable_standstill_panic(), NO RandomAmbient (its 4 m blind pops are
# indistinguishable from this level's real positional tells — see _start_ambience),
# NO ApparitionDirector, NO time limit, and since 2026-09-12 NO `Screamer.trigger()`
# anywhere in this file or dungeon_rooms.gd. check_dungeon_entities.gd and
# check_dungeon_hunter.gd assert all of them.

const PRESERVE := ["Environment", "AmbientPlayer", "HUDCanvas", "Player"]
const TEX := "res://assets/textures/level_9_dungeon/"
const BREACH_TEX := "res://assets/textures/level_6_breach/"
const SHARED_TEX := "res://assets/textures/shared/"

# The crane up into the Antechamber, played on WAKING only — the reward for seven sconces.
# ⚠️ There is deliberately no clip for the other direction: `dungeon_sleep` was never generated,
# so going under keeps its 1.6 s fade. See _after_blackout() for why that asymmetry is fine.
# ⚠️ The .ogv opens AND closes on BLACK, and both fades are added in transcode rather than
# generated — the raw clip opens lit and ends lit. The in-fade is what lets it cut cleanly from the
# fade-to-black that precedes it; the out-fade is what stops it snapping into the near-black live
# Antechamber (measured 0.171 vs 0.008 — see _on_wake_cutscene_finished).
const WAKE_VIDEO := "res://assets/video/dungeon_wake.ogv"
const _DOOR_SCRIPT := preload("res://scripts/door.gd")
const _NOTE_SCRIPT := preload("res://scripts/note.gd")
const _SCONCE_SCRIPT := preload("res://scripts/wall_sconce.gd")
const _CANDLE_SCRIPT := preload("res://scripts/candle.gd")
const _GEN_SCRIPT := preload("res://scripts/dungeon_gen.gd")
const _CHILD_SCRIPT := preload("res://scripts/dn_child.gd")
const _STALKER_SCRIPT := preload("res://scripts/creature_stalker.gd")
const _MATRON_SCRIPT := preload("res://scripts/creature_object12.gd")
const _SLAM_SCRIPT := preload("res://scripts/slam_door.gd")
const _HIDE_SCRIPT := preload("res://scripts/hiding_spot.gd")
const _CALM_SCRIPT := preload("res://scripts/calm_zone.gd")
const _ROOMS_SCRIPT := preload("res://scripts/dungeon_rooms.gd")
const _MAP_SCRIPT := preload("res://scripts/dungeon_map_ui.gd")
const _KEY_SCRIPT := preload("res://scripts/key_item.gd")

# The Antechamber is hand-built and always identical — the one fixed place in a
# level that otherwise rearranges itself. It sits well clear of the lattice.
const ANTE_ORIGIN := Vector3(0, 0, -46)
const ANTE_SIZE := Vector2(9, 8)
const ANTE_H := 3.4

# ⚠️ ONE audio bus for everything diegetic, so the Matron's arrival can duck it all
# at once — silence_zone.gd already proves the mechanism.
#
# The player's heartbeat and footsteps go to AudioBuses.BODY, which is never ducked
# (player.gd routes them there; audio_buses.gd owns the layout). That is the half of
# the silence architecture that makes the other half mean anything: when the world
# goes quiet, your own pulse is what is left. DO NOT route anything of the player's
# body to this bus, and do not duck Master instead — ducking Master would take the
# heartbeat with it and destroy the exact effect this mechanic exists to create.
const AUDIO_BUS := "Dungeon"
const BED_DB := -9.0
const MUSIC_DB := -7.0
const DUCKED_DB := -24.0
# ⚠️ THE CHASE CUE AND THE HUNTER'S VOICE ARE NOT ON THE DUNGEON BUS. That bus is ducked to
# DUCKED_DB for the whole of every wave — a cue routed through it would play 24 dB down at the
# one moment it exists for. They get their own runtime bus under Ambience (so HoldBreath's dip
# before the sting still reaches them), and never the Body bus.
const CHASE_BUS := "DungeonChase"

const SCONCE_TOTAL := 7
const BURNOUT_PANIC := 5.0        # only in the open, no primary present (§B8)
const BATTER_PANIC := 4.0
const SPRINT_DEAF_DB := -18.0

# ⭐ The two panic terms of the no-death roster (2026-09-12, both the user's numbers):
const CATCH_PANIC := 20.0         # the hunter's catch — 3 catches without recovering = the bar
const STARTLE_PANIC := 12.0       # a Still One reaching you (it then topples for good)

# The hunter's cycle (§B4.2's shape, retuned 2026-09-12: wakes at 3, ~60 s on / ~30 s off). It
# is NOT always there, and that uncertainty is the whole feeling.
const MATRON_FIRST_SCONCE := 3
const MATRON_HUNT := 60.0
const MATRON_GAP := 30.0
const MATRON_HUNT_LATE := 65.0
const MATRON_GAP_LATE := 25.0
const MATRON_MIN_SPAWN_DIST := 12.0
const MATRON_CHASE_SPEED := 3.4   # ⚠️ below the player's 4.0 walk — §B1 rule 1
const MATRON_DETECT_DARK := 5.0
const MATRON_DETECT_LIT := 9.0    # a lit candle is seen from further
const HUNTER_CALL_MIN := 10.0     # seconds between its calls while it hunts
const HUNTER_CALL_MAX := 20.0
const HUNTER_VOICE_DB := -2.0
const LAIR_WAVE := 40.0           # the Larder beat's hunt, whatever the clock says
const LAIR_RISE := 1.6            # ...and how long it stands there before it comes
const LUNGE_DIST := 0.6           # the catch: its face this far from the camera
const CUE_ON_DB := 0.0
const CUE_OFF_DB := -60.0
const CUE_IN_TIME := 0.25
const CUE_OUT_TIME := 1.5
const NOISE_SPRINT_R := 14.0      # how far each noise carries to the hunter's ears
const NOISE_SPARK_R := 12.0
const NOISE_DOOR_R := 16.0
const NOISE_SCONCE_R := 18.0

# ⚠️ Leave this false. See the block in _darken_ambient() for what was measured.
const FOG_EXPERIMENT := false

const FRAME_AUDIBLE_SCONCE := 3
const FRAME_IGNITE_SCONCE := 5    # they IGNITE and burn out now; they used to kill

var _gen = null
var _builder: RoomBuilder = null
var _candle: Candle = null
var _sconces: Array = []
var _sconces_lit: int = 0
var _frames: Array = []
var _still_ones: Array = []
var _matron = null
var _child = null
var _kneeler: Node3D = null
# The room archetypes (dungeon_rooms.gd) and their one-shot scares.
var _room_handles: Dictionary = {}       # room name -> handles from DungeonRooms.build()
var _scares_fired: Array = []            # room names whose scare has fired
var _rooms_seen: Array = []              # every room the player has stood in (the map)
var _current_room: String = ""
var _in_cistern := false
# The hunter's audio and its catch.
var _chase_cue: AudioStreamPlayer = null
var _hunter_voice: AudioStreamPlayer3D = null
var _voice_t: float = 0.0
var _voice_alt := false
var _catching := false
var _sprint_noise_t := 0.0
# The found map.
var _map = null
var _map_found := false
var _slam_doors: Array = []
var _exit_door: StaticBody3D = null
var _bed: StaticBody3D = null
var _cot: StaticBody3D = null

var _layout_seed: int = 0
var _content_seed: int = 0
var _in_dungeon: bool = false
var _matron_present: bool = false
var _matron_t: float = 0.0
var _matron_active_window: bool = false
var _env: Environment = null
# §B7 asks for ~0.02. Measured at that value the chambers render as pure black with
# a lit patch of floor under the candle and no wall anywhere — which is not "you
# cannot see the far wall", it is "you cannot see the room". 0.045 keeps the far
# wall unreadable (the candle's 4.5 m range is what enforces that) while leaving
# just enough shape to orient by, and it is still ~5x darker than any other level.
var _base_ambient: float = 0.045
var _ambient_player: AudioStreamPlayer = null
var _music: AudioStreamPlayer = null
var _matron_theme: AudioStreamPlayer3D = null
var _matron_steps: AudioStreamPlayer3D = null
var _teach_beats: Dictionary = {}


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameState.current_level = 7

	_roll_seeds()
	_clear_old_scene()
	_ensure_bus()
	_generate()
	_build_geometry()
	_build_antechamber()
	_spawn_candle()
	_spawn_sconces()
	_spawn_frames()
	_spawn_props()
	_spawn_rooms()
	_spawn_entities()
	_spawn_level_doors()
	_spawn_map()
	_place_player()
	_darken_ambient()
	_start_ambience()
	_refresh_exit()

	# ⚠️ RandomAmbient is deliberately NOT registered. It is global, fires every
	# 18-35 s, plays floor_creak / painting_fall / half_scream at a random point
	# within 4 m of the player with NO line-of-sight check, and adds 5/8/12 panic.
	# In every other level that is atmosphere. Here it would destroy the level: this
	# level's ENTIRE skill expression is "distinguish a real positional audio tell
	# from ambience", and a random half_scream 4 m away is indistinguishable from
	# the Matron while a random floor_creak is indistinguishable from the Hollow
	# One's knock. Opting out is a no-op omission — just do not call it.

	GameState.set_objective("PROTOCOL 7 — REM DEPRIVATION. LIE DOWN WHEN READY.")
	_restore_progress()


func _player() -> CharacterBody3D:
	return get_node_or_null("Player") as CharacterBody3D


# Both ends of the Antechamber, per GameState.entered_from_ahead: you came back
# through the NEXT level's back door, so you should be standing at the exit.
# ⚠️ Always the Antechamber, never the dungeon — walking back into this level must
# not drop you into a dungeon you have not been put to sleep into.
func _place_player() -> void:
	var p := _player()
	if p == null:
		return
	if GameState.entered_from_ahead:
		p.global_position = ANTE_ORIGIN + Vector3(3.2, 0.1, 0)
		p.rotation = Vector3(0, PI / 2.0, 0)     # came back through the level door (east) — face the room (west)
	else:
		# ⚠️ 2026-09-09 (cap #5): entering from the Breach back door, the player used to face +PI/2
		# (-X, straight at the door they just came through). Face INTO the Antechamber instead
		# (+X, toward the cot / candle rack / brazier — "look at the level itself").
		p.global_position = ANTE_ORIGIN + Vector3(-3.2, 0.1, 0)
		p.rotation = Vector3(0, -PI / 2.0, 0)


# Seeds are rolled ONCE and then persisted. ⚠️ On resume they are RESTORED, never
# re-rolled: restoring "5 sconces lit" against a re-rolled layout would mark
# progress on a dungeon that no longer exists — the exact warning already attached
# to KONTUR's _dark_x.
func _roll_seeds() -> void:
	var saved := GameState.get_level_progress(7)
	if saved.has("layout_seed"):
		_layout_seed = int(saved["layout_seed"])
		_content_seed = int(saved["content_seed"])
		return
	# ⚠️ Test-only seed override, the same kind of affordance as player.gd's ai_*
	# surface. Without it every launch builds a DIFFERENT dungeon, so a geometry
	# assertion cannot be compared between runs and a failure cannot be reproduced
	# — which is exactly how the first wall-overlap numbers here were misread as
	# getting worse when they were simply measuring different dungeons.
	#   Godot ... res://scenes/dungeon.tscn -- --dungeon-seed 12345
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == "--dungeon-seed":
			_layout_seed = int(args[i + 1])
			_content_seed = _layout_seed * 31 + 7
			return
	_layout_seed = randi()
	_content_seed = randi()


func _clear_old_scene() -> void:
	for child in get_children():
		if PRESERVE.has(child.name):
			continue
		# ⚠️ remove_child BEFORE queue_free (Issue 17): queue_free is deferred, so
		# the dying node still owns its NAME while _ready() builds the replacement,
		# and Godot silently renames the new one on collision.
		remove_child(child)
		child.queue_free()


func _generate() -> void:
	_gen = _GEN_SCRIPT.new()
	_gen.generate(_layout_seed, _content_seed)


# ── Geometry ────────────────────────────────────────────────────────────────────
func _build_geometry() -> void:
	_builder = RoomBuilder.new()
	_builder.wall_mat = _mat(TEX + "dungeon_wall_stone.png", 0.30, Color(0.20, 0.20, 0.21))
	_builder.floor_mat = _mat(TEX + "dungeon_floor.png", 0.32, Color(0.16, 0.15, 0.14))
	_builder.ceil_mat = _mat(TEX + "dungeon_ceiling.png", 0.30, Color(0.10, 0.10, 0.10))
	add_child(_builder)
	_builder.build(_rooms_with_skins(), _gen.doorways)
	_stagger_bridge_overlaps()
	_add_corridor_drop_ceilings()


# ⚠️ RoomBuilder's doorway floor bridges Z-FIGHT WITH EACH OTHER in this level, and
# only in this level. Each bridge extends BRIDGE_PAD (1.3 m) either side of its
# doorway plane, so two bridges overlap whenever two doorways sit within 2.6 m of
# each other — which in a 3 m cell lattice is EVERY corner junction, because a 1x1
# turn room has doorways on two perpendicular walls 3 m apart. Hand-authored levels
# never hit it: their doorways are metres apart.
#
# BRIDGE_SINK (4 mm) stops a bridge fighting the ROOM FLOOR, but every bridge is
# sunk by the SAME amount, so bridge-vs-bridge is exactly coplanar. Rather than
# change a shared constant that four other levels depend on, stagger the colliding
# ones upward by 3 mm each — above check_wall_overlap's 2 mm COPLANAR threshold and
# far below anything a player can feel or that move_and_slide has to step over.
# ISSUES_SOLUTIONS Issue 43.
func _stagger_bridge_overlaps() -> void:
	# ⚠️ Identified by GEOMETRY, not by name. RoomBuilder names every bridge
	# "DoorFloor", and Godot renames name-colliding siblings to "@CSGBox3D@N" — so
	# matching on the name finds exactly one bridge out of forty and silently does
	# nothing (which is what the first version of this function did).
	# The signature is exact: a bridge is BRIDGE_PAD * 2 = 2.6 m along one horizontal
	# axis, and every room dimension here is a multiple of CELL = 3.0.
	const BRIDGE_SPAN := RoomBuilder.BRIDGE_PAD * 2.0
	var bridges: Array = []
	for child in _builder.get_children():
		if not (child is CSGBox3D):
			continue
		var c: CSGBox3D = child
		if c.position.y > 0.0 or absf(c.size.y - RoomBuilder.T) > 0.01:
			continue
		if absf(c.size.x - BRIDGE_SPAN) < 0.01 or absf(c.size.z - BRIDGE_SPAN) < 0.01:
			bridges.append(c)
	# Greedy conflict-free assignment: each bridge takes the lowest 3 mm step that is
	# clear of EVERY already-placed bridge it overlaps in plan. Counting collisions
	# instead is not enough — two bridges that both overlap the same third one would
	# get the same offset and end up coplanar with each other.
	var placed: Array = []
	var base_y: float = bridges[0].position.y if not bridges.is_empty() else 0.0
	for b in bridges:
		var box: CSGBox3D = b
		var taken: Array = []
		for p in placed:
			var q: CSGBox3D = p
			var ox: float = minf(box.position.x + box.size.x * 0.5, q.position.x + q.size.x * 0.5) \
				- maxf(box.position.x - box.size.x * 0.5, q.position.x - q.size.x * 0.5)
			var oz: float = minf(box.position.z + box.size.z * 0.5, q.position.z + q.size.z * 0.5) \
				- maxf(box.position.z - box.size.z * 0.5, q.position.z - q.size.z * 0.5)
			if ox > 0.35 and oz > 0.35:
				taken.append(q.position.y)
		# ⚠️ DOWNWARD. Staggering upward closes the 4 mm BRIDGE_SINK gap and starts a
		# NEW fight against the room floor at y=0 — measured: raising bridges to
		# -0.101/-0.098 put their top faces within 1-2 mm of the floor plane, which
		# is precisely what BRIDGE_SINK exists to prevent. Going down keeps every
		# bridge at least 4 mm clear of the floor; the cost is a sub-centimetre dip
		# in the doorway, which is a DROP rather than a step and is an order of
		# magnitude below the 140 mm lip that once made the House cellar unenterable.
		var step := 0
		while step < 5:
			var y: float = base_y - 0.003 * step
			var clash := false
			for t in taken:
				if absf(float(t) - y) < 0.0025:
					clash = true
					break
			if not clash:
				box.position.y = y
				break
			step += 1
		placed.append(box)


# ⚠️ Negative V. A positive uv1_scale.y renders every wall texture upside-down under
# triplanar mapping — the wainscot lands at mid-wall and the lower half reads as a
# mirrored duplicate, which is Issue 19's "two textures merging into each other".
# RoomBuilder.make_material() negates it for you; a hand-rolled one must not forget.
func _mat(tex_path: String, scale: float, fallback: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.94
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path)
		if tex != null:
			mat.albedo_texture = tex
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3(scale, -scale, scale)
			# Darken every surface: §B7 point 3. At ~0.45 light energy albedo
			# contributes far less than emission, so a dark wall falls off to black
			# inside the candle radius on its own. That IS fog, for free, and it is
			# physically motivated rather than a post-process.
			mat.albedo_color = Color(0.62, 0.62, 0.64)
			return mat
	mat.albedo_color = fallback
	return mat


# Three skins, escalating deeper in: damp stone -> old brick -> charred masonry.
# ⚠️ dungeon_wall_ash was NOT generated — breach_incinerator_wall.png already is
# exactly "charred/blood-slicked masonry, value <= 0.25", and cross-level texture
# reuse is established practice here (level_6_breach builds its base skin out of
# KONTUR's and the Lab's).
func _rooms_with_skins() -> Array:
	var brick := _mat(TEX + "dungeon_wall_brick.png", 0.30, Color(0.19, 0.15, 0.13))
	var ash := _mat(BREACH_TEX + "breach_incinerator_wall.png", 0.32, Color(0.13, 0.12, 0.12))
	var out: Array = []
	var i := 0
	for r in _gen.rooms:
		var room: Dictionary = r.duplicate()
		var nm: String = room["name"]
		# Skin by distance from spawn: the deeper you go, the worse the stone.
		var d: int = _gen.room_distance(_gen.spawn_room, nm)
		if d >= 7:
			room["wall_mat"] = ash
		elif d >= 4:
			room["wall_mat"] = brick
		if nm == _gen.bed_room:
			room["wall_mat"] = ash
		out.append(room)
		i += 1
	return out


# §B6 step 6 wants chambers to feel taller than corridors. ⚠️ It cannot be done with
# RoomBuilder's per-room "h": its wall dedup is keyed on (axis, plane, HEIGHT), so
# a 3.2 chamber abutting a 2.6 corridor makes BOTH emit a slab on the shared plane —
# four slabs where there should be two, with coincident faces (measured in
# tests/probe_mixed_height.gd; ISSUES_SOLUTIONS Issue 41). So every room is one
# height and corridors get a separate drop ceiling hung under the real one. The
# 0.6 m gap means nothing is coplanar and check_wall_overlap stays clean.
func _add_corridor_drop_ceilings() -> void:
	var mat := _mat(TEX + "dungeon_ceiling.png", 0.34, Color(0.09, 0.09, 0.09))
	for nm in _gen.corridor_names:
		var r: Rect2i = _gen.room_rect(nm)
		var c: Vector3 = _gen.room_center_world(nm)
		var box := CSGBox3D.new()
		box.name = "DropCeil_" + nm
		box.size = Vector3(r.size.x * _gen.CELL, 0.18, r.size.y * _gen.CELL)
		box.position = Vector3(c.x, _gen.CORRIDOR_CEIL_H, c.z)
		box.material = mat
		box.use_collision = true
		add_child(box)


# ── The Antechamber ─────────────────────────────────────────────────────────────
# Small, hand-built, always identical, lit by one guttering brazier. DN2's hub
# hotel is the sequel's best structural feature and a whole level's worth of
# hand-built content; this is the 5% of it that earns 80% of the feeling (§B11).
func _build_antechamber() -> void:
	var ab := RoomBuilder.new()
	ab.name = "AnteBuilder"
	ab.wall_mat = _mat(TEX + "dungeon_wall_stone.png", 0.30, Color(0.24, 0.23, 0.22))
	ab.floor_mat = _mat(TEX + "dungeon_floor.png", 0.32, Color(0.18, 0.17, 0.16))
	ab.ceil_mat = _mat(TEX + "dungeon_ceiling.png", 0.30, Color(0.12, 0.12, 0.12))
	add_child(ab)
	ab.build([{
		"name": "Antechamber",
		"pos": Vector2(ANTE_ORIGIN.x, ANTE_ORIGIN.z),
		"size": ANTE_SIZE,
		"h": ANTE_H,
	}], [])

	# A brazier: the only warm light in the level that you did not have to light.
	var brazier := OmniLight3D.new()
	brazier.name = "AnteBrazier"
	brazier.omni_range = 9.0
	brazier.omni_attenuation = 1.4
	brazier.light_color = Color(1.0, 0.72, 0.4)
	brazier.light_energy = 0.75
	brazier.position = ANTE_ORIGIN + Vector3(3.0, 1.6, 3.0)
	add_child(brazier)

	# Safe ground, before and after (§B8).
	var calm := Area3D.new()
	calm.name = "AnteCalm"
	calm.set_script(_CALM_SCRIPT)
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 6.5
	cs.shape = sph
	calm.add_child(cs)
	calm.position = ANTE_ORIGIN + Vector3(0, 1.0, 0)
	add_child(calm)

	_cot = _build_cot(ANTE_ORIGIN + Vector3(0, 0, 2.0))
	_build_protocol_note(ANTE_ORIGIN + Vector3(-3.2, 1.3, 0.0), PI / 2.0)
	_build_scrawl(ANTE_ORIGIN + Vector3(0, 1.7, -3.85))
	_build_candle_rack(ANTE_ORIGIN + Vector3(2.6, 0.0, -2.4))


# ⚠️ interact(), not a trigger volume. The player CHOOSES to go under — which is
# what makes the fiction land: "You will be put down", and you agree to it.
func _build_cot(pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Cot"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.set_script(preload("res://scripts/dungeon_cot.gd"))
	add_child(body)
	body.used.connect(_on_cot_used)
	return body


func _build_protocol_note(pos: Vector3, y_rot: float) -> void:
	var body := StaticBody3D.new()
	body.name = "ProtocolNote"
	body.set_script(_NOTE_SCRIPT)
	body.position = pos
	body.rotation.y = y_rot
	body.note_text = "PROTOCOL 7 — REM DEPRIVATION\n\n" \
		+ "Subject 47 has demonstrated composure under observation.\n" \
		+ "Composure under observation is not composure.\n" \
		+ "We are now removing the observation.\n\n" \
		+ "You will be put down. What you find below is not ours — it is yours, " \
		+ "and it has been there since before we found you. You will be given a " \
		+ "candle because we cannot give you anything that runs on our power " \
		+ "down there.\n\n" \
		+ "Trial 7c: the subject reports the rooms are not the same rooms. The subject " \
		+ "reports the statues are closer. We have left the subject a plan of the lower " \
		+ "floor; it shows only what the subject has walked. Nothing down there can end " \
		+ "the subject. The subject can end the subject.\n\n" \
		+ "The trial will be repeated until the data is consistent.\n" \
		+ "Do not be alarmed by the repetition.\n" \
		+ "YOU WILL NOT REMEMBER IT AS REPETITION."
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.34, 0.44, 0.01)
	mesh.mesh = bm
	mesh.set_surface_override_material(0, _NOTE_SCRIPT.paper_material(false))
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.42, 0.52, 0.12)
	col.shape = sh
	body.add_child(col)


# "YOU CANNOT HEAR IT OVER YOURSELF." — the sprint-deafens rule, taught here,
# before the player has anything to run from (§B9).
func _build_scrawl(pos: Vector3) -> void:
	var lbl := Label3D.new()
	lbl.name = "AnteScrawl"
	lbl.text = "YOU CANNOT HEAR IT\nOVER YOURSELF"
	lbl.font_size = 64
	lbl.pixel_size = 0.0032
	lbl.modulate = Color(0.72, 0.06, 0.06)
	lbl.outline_size = 0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.position = pos
	add_child(lbl)

	if ResourceLoader.exists(TEX + "dn_tally_wall.png"):
		var tally := MeshInstance3D.new()
		tally.name = "AnteTally"
		var qm := QuadMesh.new()
		qm.size = Vector2(1.4, 1.4)
		tally.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(TEX + "dn_tally_wall.png")
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 1.0
		tally.set_surface_override_material(0, m)
		tally.position = pos + Vector3(2.6, -0.3, 0.02)
		add_child(tally)


func _build_candle_rack(pos: Vector3) -> void:
	var rack := MeshInstance3D.new()
	rack.name = "CandleRack"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.9, 0.35)
	rack.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.17, 0.14, 0.11)
	m.roughness = 0.95
	rack.set_surface_override_material(0, m)
	rack.position = pos + Vector3(0, 0.45, 0)
	add_child(rack)
	for i in range(4):
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.035
		cm.height = 0.22
		c.mesh = cm
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.86, 0.83, 0.72)
		cmat.roughness = 0.8
		c.set_surface_override_material(0, cmat)
		c.position = pos + Vector3(-0.24 + i * 0.16, 1.01, 0)
		add_child(c)


# ── Candle + spark ──────────────────────────────────────────────────────────────
func _spawn_candle() -> void:
	var p := _player()
	if p == null:
		return
	# ⚠️ The candle REPLACES the flashlight. Zero new code — kill_flashlight() is
	# already implemented and already used by the Backrooms noclip. F now only
	# clicks, which is the correct read: their equipment does not work down here.
	p.kill_flashlight()
	_candle = _CANDLE_SCRIPT.new()
	_candle.name = "Candle"
	var cam := p.get_node_or_null("Camera3D")
	if cam:
		cam.add_child(_candle)
	else:
		p.add_child(_candle)
	_candle.burned_out.connect(_on_candle_burned_out)


func _unhandled_input(event: InputEvent) -> void:
	if _candle == null or NoteUI.is_open or get_tree().paused:
		return
	var p := _player()
	if p and p.is_input_frozen():
		return
	if event.is_action_pressed("toggle_flashlight"):
		_toggle_candle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("spark"):
		_do_spark()
		get_viewport().set_input_as_handled()


func _toggle_candle() -> void:
	var was := _candle.burning
	if _candle.toggle():
		_play_at("candle_light", _player().global_position, -4.0)
	elif was:
		_play_at("candle_blow", _player().global_position, -8.0)
	else:
		ScreenText.toast(get_tree(), "NO CANDLES LEFT", Color(0.8, 0.7, 0.5), 1.6)
	_refresh_matron_detection()


func _do_spark() -> void:
	_candle.spark()
	var p := _player()
	if p == null:
		return
	_play_at("spark_flint", p.global_position, -6.0)
	_hunter_noise(p.global_position, NOISE_SPARK_R)

	# A spark advances every Still One one step (DN's rule). ⚠️ It no longer KILLS within 2 m
	# of an awake one — that branch is the non-lethal startle now (`lethal = false`).
	for s in _still_ones:
		if is_instance_valid(s):
			s.on_spark(p.global_position)


func _on_candle_burned_out() -> void:
	var p := _player()
	if p == null:
		return
	_play_at("candle_die", p.global_position, -2.0)
	if not _candle.burnout_shown():
		_candle.mark_burnout_shown()
		ScreenText.toast(get_tree(), "THE CANDLE IS OUT", Color(0.85, 0.7, 0.4), 2.4)
	# §B8: the gut-drop as the light dies — but only if you are actually exposed.
	# Not while a primary is present (that would stack), and not near a lit sconce.
	if not _matron_present and not _near_lit_sconce(p.global_position, 8.0):
		p.add_panic(BURNOUT_PANIC)
	_refresh_matron_detection()


func _near_lit_sconce(pos: Vector3, radius: float) -> bool:
	for s in _sconces:
		if is_instance_valid(s) and s.is_lit and s.global_position.distance_to(pos) <= radius:
			return true
	return false


# ── Sconces ─────────────────────────────────────────────────────────────────────
func _spawn_sconces() -> void:
	for spot in _gen.sconce_spots:
		var nm: String = spot["room"]
		var side: Vector2 = spot["side"]
		# ⚠️ inset 0.16, and the generator has guaranteed this side carries no
		# doorway. wall_point()'s inset is measured from the room's NOMINAL
		# boundary while the wall's inner face is T/2 in from it, so 0.10 is
		# exactly coplanar and anything less is buried (Issues 11, 26).
		var pos: Vector3 = _builder.wall_point(nm, side, 1.7, 0.16)
		var sconce := _SCONCE_SCRIPT.new()
		sconce.name = "Sconce_" + nm
		sconce.position = pos
		sconce.rotation.y = atan2(-side.x, -side.y)
		add_child(sconce)
		sconce.lit.connect(_on_sconce_interact.bind(sconce))
		_sconces.append(sconce)


func _on_sconce_interact(sconce) -> void:
	if _candle == null or not _candle.burning:
		ScreenText.toast(get_tree(), "NOTHING TO LIGHT IT WITH", Color(0.8, 0.75, 0.6), 1.8)
		return
	sconce.light_it()
	_sconces_lit += 1
	_play_at("sconce_light", sconce.global_position, 0.0)
	# D1 (2026-09-13): a lit sconce gives a candle back — the seven are worth seven more, so the
	# night's light budget covers its 12–15 minutes (4 + 4 caches = 480 s did not).
	if _candle and _candle.add_candle():
		ScreenText.toast(get_tree(), "A CANDLE FROM THE SCONCE  (%d/%d)" % [_candle.candles, Candle.CARRY_CAP],
			Color(0.85, 0.75, 0.55), 1.8)
	_hunter_noise(sconce.global_position, NOISE_SCONCE_R)
	_on_sconce_count_changed()
	# ⭐ The room's own scare, if this room has one (dungeon_rooms.gd).
	var nm: String = String(sconce.name).trim_prefix("Sconce_")
	_fire_room_scare(nm)
	_map_refresh()


# The escalation clock (§B3). The level physically gets SAFER as you progress —
# more light, more calm islands — while the roster escalates to compensate. That is
# DN's "same objects, different rules" teaching structure compressed into one night.
# ⭐ Two count gates and the finale — that is all the count does now. The scares live in the
# rooms (dungeon_rooms.gd), dealt per dungeon, fired by that room's sconce or first entry.
func _on_sconce_count_changed() -> void:
	GameState.set_objective("SCONCES LIT: %d / %d" % [_sconces_lit, SCONCE_TOTAL])

	if _sconces_lit >= FRAME_AUDIBLE_SCONCE:
		for f in _frames:
			if is_instance_valid(f):
				f.set_audible(true)
	if _sconces_lit >= FRAME_IGNITE_SCONCE:
		for f in _frames:
			if is_instance_valid(f):
				f.set_ignites(true)
	if _sconces_lit >= MATRON_FIRST_SCONCE and not _matron_active_window:
		_matron_active_window = true
		_matron_t = 6.0
	if _sconces_lit >= SCONCE_TOTAL:
		_finale()


# 7/7: the bed is uncovered, every statue is awake whether or not you have seen it, and the
# hunter is loose for the walk back — the level's one moment where everything is on at once.
func _finale() -> void:
	_reveal_bed()
	for st in _still_ones:
		if is_instance_valid(st) and not st.has_fallen():
			st.wake()
	if _matron != null:
		_matron_active_window = true
		if not _matron_present:
			_matron_t = minf(_matron_t, 4.0)


# ── Weeping Frames ──────────────────────────────────────────────────────────────
func _spawn_frames() -> void:
	var art := [TEX + "painting_matron.png", TEX + "painting_witness.png"]
	var i := 0
	for spot in _gen.frame_spots:
		var nm: String = spot["room"]
		var side: Vector2 = spot["side"]
		var pos: Vector3 = _builder.wall_point(nm, side, 1.8, 0.16)
		# Along the wall, so two paintings share it (dungeon_gen.gd's `offset`).
		var along := Vector3(-side.y, 0.0, side.x)
		pos += along * float(spot.get("offset", 0.0))
		var frame := preload("res://scripts/weeping_frame.gd").new()
		frame.name = "Frame_%s_%d" % [nm, i]
		frame.position = pos
		frame.rotation.y = atan2(-side.x, -side.y)
		frame.art_path = art[i % art.size()]
		frame.open_eyes_path = TEX + "painting_matron_open.png"
		add_child(frame)
		_frames.append(frame)
		i += 1


# ── Props ───────────────────────────────────────────────────────────────────────
func _spawn_props() -> void:
	# Candle caches.
	for nm in _gen.candle_rooms:
		var c: Vector3 = _gen.room_center_world(nm)
		var pickup := preload("res://scripts/key_item.gd").new()
		pickup.name = "CandleCache_" + nm
		pickup.label_text = "Candle taken"
		pickup.position = c + Vector3(0.9, 0.55, 0.6)
		add_child(pickup)
		pickup.picked_up.connect(_on_candle_picked)
		var mesh := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.035
		cm.bottom_radius = 0.04
		cm.height = 0.24
		mesh.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.88, 0.85, 0.74)
		m.roughness = 0.8
		mesh.set_surface_override_material(0, m)
		pickup.add_child(mesh)
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(0.35, 0.4, 0.35)
		col.shape = sh
		pickup.add_child(col)
		pickup.collision_layer = 2
		pickup.collision_mask = 0

	# Hiding spots — DN has none, but enter_hiding() is already built and is a
	# BETTER answer to a slow pursuer than sprinting is. Two: enough to be a real
	# option, few enough that it is not the default.
	for nm in _gen.hiding_rooms:
		var sides: Array = _gen.free_sides(nm)
		if sides.is_empty():
			continue
		var side: Vector2 = sides[0]
		var spot := _HIDE_SCRIPT.new()
		spot.name = "Hide_" + nm
		spot.prop_kind = "cabinet"
		spot.position = _builder.wall_point(nm, side, 0.0, 0.22)
		spot.rotation.y = atan2(-side.x, -side.y)
		add_child(spot)

	# ⚠️ No beartraps since 2026-09-12: 15 + 40 panic on a failed escape was a death in a level
	# whose only death is now the panic bar, and a limp during a chase is the double-jeopardy shape.

	# SlamDoors on chamber<->corridor thresholds. Mary's door-pounding, already
	# written and already tested — and the battering thud is ALSO a locator, so it
	# teaches you exactly where she is.
	for idx in _gen.slam_doorways:
		var d: Dictionary = _gen.doorways[idx]
		var door := _SLAM_SCRIPT.new()
		door.name = "Slam_%d" % idx
		# ⚠️ THE DUNGEON'S DOORWAYS ARE 2.2 m WIDE AND ITS ROOMS 3.2 m TALL, and SlamDoor's
		# defaults are the Breach's 1.8 / 3.0. Left at the defaults, a "closed" dungeon door
		# leaves 0.2 m of gap each side and 0.2 m of open air above — it had 0.55 m and 1.0 m
		# before the class was sized at all. These MUST track dungeon_gen.gd's own constants.
		door.door_width = DungeonGen.DOOR_WIDTH
		door.door_height = DungeonGen.ROOM_H
		door.door_texture = TEX + "dungeon_door.png"
		door.position = Vector3(d["pos"].x, 0.0, d["pos"].y)
		door.rotation.y = 0.0 if d["dir"] == "z" else PI / 2.0
		add_child(door)
		_slam_doors.append(door)
		door.slammed.connect(_on_door_slammed)

	_build_bed()


func _on_candle_picked() -> void:
	if _candle and _candle.add_candle():
		ScreenText.toast(get_tree(), "CANDLE  (%d/%d)" % [_candle.candles, Candle.CARRY_CAP],
			Color(0.85, 0.8, 0.6), 1.6)


func _on_door_slammed() -> void:
	var p := _player()
	if p:
		p.add_panic(BATTER_PANIC)


# The bed — the exit. Hidden until 7/7 burn.
func _build_bed() -> void:
	var c: Vector3 = _gen.room_center_world(_gen.bed_room)
	_bed = StaticBody3D.new()
	_bed.name = "TheBed"
	_bed.collision_layer = 1
	_bed.collision_mask = 0
	_bed.position = c
	_bed.set_script(preload("res://scripts/dungeon_cot.gd"))
	_bed.is_exit = true
	add_child(_bed)
	_bed.used.connect(_on_bed_used)
	_bed.visible = false
	_bed.process_mode = Node.PROCESS_MODE_DISABLED


func _reveal_bed() -> void:
	if _bed == null:
		return
	_bed.visible = true
	_bed.process_mode = Node.PROCESS_MODE_INHERIT
	GameState.set_objective("SEVEN LIT. THE BED IS UNCOVERED. GO BACK TO SLEEP.")
	ScreenText.scrawl(get_tree(), "IT IS ALL LIT.", 4.0)
	_refresh_exit()


# ── Entities ────────────────────────────────────────────────────────────────────
func _spawn_entities() -> void:
	_spawn_still_ones()
	_spawn_matron()
	_child = _CHILD_SCRIPT.new()
	_child.name = "TheChild"
	add_child(_child)
	_child.register_player(_player())


# DN's skeletons. ~35% are DUDS — approach one and it topples with a crash and is
# inert forever. You cannot tell a dud from a killer without walking up to one, and
# toppling is the GOOD outcome.
func _spawn_still_ones() -> void:
	var i := 0
	for nm in _gen.still_one_rooms:
		var s = _STALKER_SCRIPT.new()
		s.name = "StillOne_" + nm
		var h: Dictionary = _room_handles.get(nm, {})
		# In a Cells room it stands in the barred niche, leashed to it; in a Crypt it stands in
		# the first sarcophagus. Anywhere else, off the room centre as before.
		if h.has("statue_pos"):
			s.position = h["statue_pos"]
		else:
			s.position = _gen.room_center_world(nm) + Vector3(0.6, 0, -0.6)
		if h.has("leash"):
			s.leash = h["leash"]
		s.scrape_tell = true
		s.spark_reactive = true
		# ⭐ NON-LETHAL (2026-09-12). Reaching you is a survivable face flash + STARTLE_PANIC and
		# it topples for good — see _on_still_one_caught. The spark-kill branch takes the same path.
		s.lethal = false
		# The FIRST one is always a dud, and the generator puts a Still One in a
		# chamber near the spawn: §B9's teaching beat. Walk up, it falls over, and
		# you have now learned the silhouette AND that they can be inert. The
		# second one in the level is real.
		s.is_dud = (i == 0) or (randf() < 0.35)
		add_child(s)
		s.caught.connect(_on_still_one_caught.bind(s))
		_still_ones.append(s)
		i += 1


# A statue reached you. A survivable flash of its face, the panic term, and (in the stalker
# itself) the topple. Never a death — the user's call, 2026-09-12.
func _on_still_one_caught(_s: Node) -> void:
	var p := _player()
	if p == null:
		return
	Screamer.flash_scare(TEX + "dn_stillone_face.png", "stillone_shriek", 0.6)
	p.jolt_camera(0.15, 0.4)
	p.add_panic(STARTLE_PANIC)


func _spawn_matron() -> void:
	_matron = _MATRON_SCRIPT.new()
	_matron.name = "TheHunter"
	# ⚠️ position BEFORE add_child: _ready() seeds the inner body's transform from
	# global_transform the moment it enters the tree (Issue 10).
	_matron.position = _gen.room_center_world(_gen.bed_room)
	# ⭐ THE PARASITE (2026-09-12): a second model, a non-lethal catch, no teleporting when it
	# loses you (the waves are what make it come and go), and the dungeon's doorway graph so it
	# walks doorway to doorway instead of through the masonry.
	_matron.model = "parasite"
	# Its own palette: pale, cold, and NOT self-lit — at 0.045 ambient an emissive creature is
	# the brightest thing in the level, and this one is meant to be found by its voice.
	_matron.albedo_tint = Color(0.62, 0.6, 0.58)
	_matron.emission_base = 0.0
	_matron.lethal_contact = false
	_matron.relocate_when_lost = false
	_matron.chase_speed = MATRON_CHASE_SPEED
	_matron.patrol_speed = 1.5
	_matron.investigate_speed = 2.2
	_matron.detect_range = MATRON_DETECT_DARK
	add_child(_matron)
	var wps := PackedVector3Array()
	for nm in _gen.matron_spawn_rooms:
		wps.append(_gen.room_center_world(nm))
	_matron.set_waypoints(wps)
	_matron.set_portals(_gen.rooms, _gen.doorways)
	_matron.caught.connect(_on_hunter_caught)
	# Dormant until the count gate or the Larder; _tick_matron owns the spawn/hunt/despawn cycle.
	_matron.visible = false

	_matron_theme = AudioStreamPlayer3D.new()
	_matron_theme.name = "MatronTheme"
	var mt := GameState.load_audio("matron_theme")
	if mt:
		_matron_theme.stream = mt
		_matron_theme.finished.connect(_matron_theme.play)
	_matron_theme.unit_size = 18.0
	_matron_theme.volume_db = -60.0
	_matron_theme.bus = AUDIO_BUS
	_matron.add_child(_matron_theme)

	_matron_steps = AudioStreamPlayer3D.new()
	_matron_steps.name = "MatronSteps"
	var ms := GameState.load_audio("matron_step")
	if ms:
		_matron_steps.stream = ms
	_matron_steps.unit_size = 14.0
	_matron_steps.volume_db = -4.0
	_matron_steps.bus = AUDIO_BUS
	_matron.add_child(_matron_steps)

	# ⭐ Its voice: a positional call every HUNTER_CALL_MIN..MAX s while it hunts, on the
	# un-ducked chase bus, so you hear it coming across the dungeon. Sprinting deafens it.
	_hunter_voice = AudioStreamPlayer3D.new()
	_hunter_voice.name = "HunterVoice"
	_hunter_voice.unit_size = 14.0
	_hunter_voice.max_db = 6.0
	_hunter_voice.volume_db = HUNTER_VOICE_DB
	_hunter_voice.bus = CHASE_BUS
	_matron.add_child(_hunter_voice)

	# ⭐ The chase cue: the user's supplied cue, looped by tools/make_loop.py, non-positional,
	# faded in only while it is IN CHASE AND CAN SEE YOU, faded out when it loses you.
	_chase_cue = AudioStreamPlayer.new()
	_chase_cue.name = "ChaseCue"
	var cue := GameState.load_audio("parasite_chase")
	if cue:
		_chase_cue.stream = cue
		_chase_cue.finished.connect(_chase_cue.play)
	_chase_cue.volume_db = CUE_OFF_DB
	_chase_cue.bus = CHASE_BUS
	add_child(_chase_cue)


# The Chapel's scare: the Kneeling Man appears kneeling at the altar. A large crawling shadow
# that CANNOT HARM YOU AT ALL — within 2.5 m he simply dissolves and relocates. Pure gaze panic,
# and the whisperer: "Look behind you" is the exact lie KONTUR's escort gate already tells.
func spawn_kneeler_at(pos: Vector3) -> void:
	if _kneeler != null:
		return
	_kneeler = preload("res://scripts/kneeling_man.gd").new()
	_kneeler.name = "TheKneelingMan"
	_kneeler.position = pos
	add_child(_kneeler)
	_kneeler.register_player(_player())


# ── The Matron's cycle ──────────────────────────────────────────────────────────
# She SPAWNS, hunts for HUNT_TIME, DESPAWNS, waits SPAWN_GAP, respawns. She is not
# always there, and that uncertainty is the whole feeling. DN's actual model.
func _tick_matron(delta: float) -> void:
	if not _matron_active_window or _matron == null:
		return
	_matron_t -= delta
	if _matron_t > 0.0:
		if _matron_present:
			_update_matron_audio()
		return

	if _matron_present:
		_despawn_matron()
	else:
		_spawn_matron_now()


func _spawn_matron_now() -> void:
	var p := _player()
	if p == null:
		return
	var spot := _matron_spawn_spot(p.global_position)
	if spot == Vector3.INF:
		_matron_t = 6.0
		return
	_spawn_matron_at(spot, MATRON_HUNT_LATE if _sconces_lit >= 6 else MATRON_HUNT)


# Put the hunter at `spot`, awake, for `hunt_time` seconds. Shared by the clock and the Larder.
func _spawn_matron_at(spot: Vector3, hunt_time: float) -> void:
	var p := _player()
	if p == null or _matron == null:
		return
	_matron.place_body(spot, p.global_position)
	_matron.visible = true
	_matron.activate()
	_matron_present = true
	_matron_t = hunt_time
	_voice_t = randf_range(2.0, 5.0)   # the first call comes soon after it appears

	# ⭐ THE SILENCE. Duck the whole diegetic bus and stop panic healing. The
	# heartbeat is NOT on this bus, so what is left is your own pulse — DN's
	# signature effect, reproduced exactly.
	_duck_bus(true)
	p.set_no_decay(true)
	if _matron_theme and _matron_theme.stream and not _matron_theme.playing:
		_matron_theme.play()

	# Taught ONCE, ever, and deliberately while the player is standing in a lit
	# sconce's CalmZone so the lesson costs nothing (§B9).
	if not _teach_beats.get("silence_taught", false):
		_teach_beats["silence_taught"] = true
		ScreenText.scrawl(get_tree(), "IT'S QUIET.", 3.5)


func _despawn_matron() -> void:
	_matron_present = false
	_matron.visible = false
	_matron.set("_active", false)
	_matron_t = MATRON_GAP_LATE if _sconces_lit >= 6 else MATRON_GAP
	_duck_bus(false)
	var p := _player()
	if p:
		p.set_no_decay(false)
	if _matron_theme and _matron_theme.playing:
		_matron_theme.stop()
	if _hunter_voice and _hunter_voice.playing:
		_hunter_voice.stop()
	if _chase_cue:
		_chase_cue.volume_db = CUE_OFF_DB
		if _chase_cue.playing:
			_chase_cue.stop()


# ⭐ THE CATCH (2026-09-12, the user's choice: "jumpscare, panic spike, it lets go"). The
# creature emits `caught` at contact_dist with line of sight; this stages it: pin the player,
# turn them to it, bring its face LUNGE_DIST from the camera, the sting on Master with a breath
# of silence before it, the jolt, CATCH_PANIC — then it lets go and the wave is over. Nothing here
# touches the Screamer; the panic bar is the only thing that can end the run.
func _on_hunter_caught() -> void:
	if _catching or _matron == null:
		return
	var p := _player()
	if p == null:
		return
	_catching = true
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	p.freeze_input()
	var cam: Camera3D = p.get_node_or_null("Camera3D") as Camera3D
	var head: Vector3 = _matron.get_creature_position() + Vector3(0, 1.6, 0)
	if p.has_method("turn_to_face"):
		p.turn_to_face(head, 0.18)
	HoldBreath.dip(get_tree(), 0.5)
	if cam:
		var fwd: Vector3 = -cam.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length() < 0.05:
			fwd = Vector3(0, 0, -1)
		var at: Vector3 = cam.global_position + fwd.normalized() * LUNGE_DIST
		_matron.place_body(Vector3(at.x, 0.0, at.z), p.global_position)
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(p):
		_catching = false
		return
	_play_master("parasite_jumpscare", 0.0)
	p.jolt_camera(0.12, 0.5)
	p.add_panic(CATCH_PANIC)
	await get_tree().create_timer(0.9).timeout
	if not is_instance_valid(p) or not is_instance_valid(_matron):
		_catching = false
		return
	# It lets go: three metres back, then gone. The wave is over.
	var away: Vector3 = _matron.get_creature_position() - p.global_position
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3(0, 0, 1)
	_matron.place_body(_matron.get_creature_position() + away.normalized() * 3.0, p.global_position)
	_despawn_matron()
	p.unfreeze_input()
	_catching = false


# ⭐ THE LARDER (dungeon_rooms.gd): lighting the lair's sconce puts the hunter three metres
# behind you, facing you, already chasing — "it is beside you, run". A wave regardless of the
# clock, and it wakes the hunter even before the third sconce.
func lair_beat(_room: String, fallback: Vector3) -> void:
	var room_name: String = _room
	var p := _player()
	if p == null or _matron == null:
		return
	if _matron_present:
		_despawn_matron()
	_matron_active_window = true
	# A ladder of marks around the player — behind first, then over each shoulder, then in
	# front — each validated by rays and by being fully inside a room (Issue 40: never a shape
	# query against CSG). Measured 2026-09-12: the single "3 m behind" mark landed ON the wall of a
	# 6 m chamber and the fallback was 1.2 m from the player, i.e. an instant catch.
	var back: Vector3 = p.global_transform.basis.z
	back.y = 0.0
	back = back.normalized()
	var spot := Vector3.INF
	var cands: Array = [back * 3.0, back * 2.4, back.rotated(Vector3.UP, 0.7) * 2.6,
		back.rotated(Vector3.UP, -0.7) * 2.6, -back * 3.0, back * 2.0]
	# ...then a ring at 2.4-3.2 m all round: a 6 m larder with two hanging shapes and a block
	# refused every fixed mark on seed 202 (measured).
	for k in range(12):
		var ang: float = TAU * float(k) / 12.0
		cands.append(back.rotated(Vector3.UP, ang) * (2.4 if k % 2 == 0 else 3.2))
	for cand in cands:
		var m: Vector3 = p.global_position + cand
		if _spot_clear(p, m):
			spot = m
			break
	if spot == Vector3.INF:
		# Nothing fits around the player: take the handle's mark or the room centre, whichever is
		# further from them, but never inside 2 m.
		var c: Vector3 = _gen.room_center_world(room_name)
		spot = fallback if fallback.distance_to(p.global_position) >= c.distance_to(p.global_position) else c
		if spot.distance_to(p.global_position) < 2.0:
			var away: Vector3 = spot - p.global_position
			away.y = 0.0
			if away.length() < 0.05:
				away = back
			spot = p.global_position + away.normalized() * 2.4
	_spawn_matron_at(spot, LAIR_WAVE)
	_matron.force_chase()
	# ⚠️ It STANDS UP first. Measured on the first render: 3 m at 3.4 m/s is 0.9 s, which is
	# exactly the turn plus the freeze below — the catch fired as control came back, and a beat
	# whose only answer is "run" gave nobody the chance to. force_block() holds the walk (the
	# gait runs at a quarter rate, a slow rise) and the catch still needs 1.0 m of contact.
	_matron.force_block(LAIR_RISE)
	p.velocity.x = 0.0
	p.velocity.z = 0.0
	p.freeze_input()
	if p.has_method("turn_to_face"):
		p.turn_to_face(_matron.get_creature_position() + Vector3(0, 1.5, 0), 0.35)
	var t := get_tree().create_timer(0.55)
	t.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.unfreeze_input())


# Is `spot` on the floor, inside a room, with a clear line from the player's eye to a chest
# there? Rays only (Issue 40): a shape query inside CSG reports nothing.
func _spot_clear(p: CharacterBody3D, spot: Vector3) -> bool:
	var room: String = _gen.room_at(spot)
	if room == "":
		return false
	# The body is ~0.5 m wide: every point of that footprint must be in the SAME room, or the
	# mark is on a wall.
	for off in [Vector3(0.5, 0, 0), Vector3(-0.5, 0, 0), Vector3(0, 0, 0.5), Vector3(0, 0, -0.5)]:
		if _gen.room_at(spot + off) != room:
			return false
	var space := get_world_3d().direct_space_state
	var cam: Camera3D = p.get_node_or_null("Camera3D") as Camera3D
	var eye: Vector3 = cam.global_position if cam else p.global_position + Vector3(0, 1.6, 0)
	# Layer 1 only: a candle cache's layer-2 interact volume is not a wall (Issue 40's cousin —
	# the first version masked everything and a pickup on the floor vetoed a clear mark).
	var q := PhysicsRayQueryParameters3D.create(eye, spot + Vector3(0, 0.9, 0))
	q.exclude = [p.get_rid()]
	q.collision_mask = 1
	if not space.intersect_ray(q).is_empty():
		return false
	# And the reverse ray, chest to eye — the creature's own line-of-sight test — so a mark that
	# ends just inside a prop cannot pass one way and fail the other.
	var q2 := PhysicsRayQueryParameters3D.create(spot + Vector3(0, 0.9, 0), eye)
	q2.exclude = [p.get_rid()]
	q2.collision_mask = 1
	return space.intersect_ray(q2).is_empty()


func _hunter_noise(pos: Vector3, radius: float) -> void:
	if _matron_present and _matron != null:
		_matron.notify_noise(pos, radius)


func _tick_noise(delta: float, p: CharacterBody3D) -> void:
	if not p.is_sprinting():
		_sprint_noise_t = 0.0
		return
	_sprint_noise_t += delta
	if _sprint_noise_t >= 0.5:
		_sprint_noise_t = 0.0
		_hunter_noise(p.global_position, NOISE_SPRINT_R)


func _tick_hunter_voice(delta: float) -> void:
	if not _matron_present or _matron == null or _hunter_voice == null:
		return
	var st: int = _matron.get_state()
	if st != 1 and st != 2 and st != 3:   # INVESTIGATE / CHASE / SEARCH
		return
	_voice_t -= delta
	if _voice_t > 0.0:
		return
	_voice_t = randf_range(HUNTER_CALL_MIN, HUNTER_CALL_MAX)
	var s := GameState.load_audio("parasite_growl" if _voice_alt else "matron_shriek")
	_voice_alt = not _voice_alt
	if s == null:
		s = GameState.load_audio("matron_shriek")
	if s:
		_hunter_voice.stream = s
		_hunter_voice.pitch_scale = randf_range(0.9, 1.05)
		_hunter_voice.play()


func _tick_chase_cue(delta: float) -> void:
	if _chase_cue == null or _chase_cue.stream == null:
		return
	var want: bool = _matron_present and _matron != null and _matron.get_state() == 2 \
		and _matron.has_line_of_sight()
	if want and not _chase_cue.playing:
		_chase_cue.play()
	var target: float = CUE_ON_DB if want else CUE_OFF_DB
	var rate: float = (CUE_ON_DB - CUE_OFF_DB) / (CUE_IN_TIME if want else CUE_OUT_TIME)
	_chase_cue.volume_db = move_toward(_chase_cue.volume_db, target, rate * delta)
	if not want and _chase_cue.playing and _chase_cue.volume_db <= CUE_OFF_DB + 0.5:
		_chase_cue.stop()


func _play_master(base_name: String, volume_db: float) -> void:
	var s := GameState.load_audio(base_name)
	if s == null:
		return
	var pl := AudioStreamPlayer.new()
	pl.stream = s
	pl.volume_db = volume_db
	pl.bus = "Master"
	add_child(pl)
	pl.play()
	pl.finished.connect(pl.queue_free)


func _matron_spawn_spot(from: Vector3) -> Vector3:
	# A random CHAMBER at least MATRON_MIN_SPAWN_DIST away, never a corridor.
	# DN's rule verbatim.
	var pool: Array = []
	for nm in _gen.matron_spawn_rooms:
		var c: Vector3 = _gen.room_center_world(nm)
		if c.distance_to(from) >= MATRON_MIN_SPAWN_DIST:
			pool.append(c)
	if pool.is_empty():
		return Vector3.INF
	return pool[randi() % pool.size()]


func _update_matron_audio() -> void:
	var p := _player()
	if p == null or _matron == null:
		return
	var d: float = _matron.get_creature_position().distance_to(p.global_position)
	# The theme's volume envelope tracks her distance — DN's "the music fades as she
	# loses you". That envelope is the player's sonar, and it is free.
	if _matron_theme:
		_matron_theme.volume_db = lerpf(-4.0, -34.0, clampf(d / 26.0, 0.0, 1.0))
	if _matron_steps and d < 14.0 and not _matron_steps.playing:
		_matron_steps.pitch_scale = randf_range(0.92, 1.08)
		_matron_steps.play()


func _refresh_matron_detection() -> void:
	if _matron == null:
		return
	# A lit candle is seen from further away — the candle's cost, against the
	# Child-suppression that is its benefit.
	_matron.detect_range = MATRON_DETECT_LIT if (_candle and _candle.burning) \
		else MATRON_DETECT_DARK


# ── Audio ───────────────────────────────────────────────────────────────────────
func _ensure_bus() -> void:
	# Delegates to AudioBuses rather than re-rolling backrooms.gd's _ensure_bus():
	# one place that knows how a runtime bus is made.
	AudioBuses.ensure(AUDIO_BUS)
	AudioBuses.ensure(CHASE_BUS)


func _duck_bus(ducked: bool) -> void:
	var idx := AudioServer.get_bus_index(AUDIO_BUS)
	if idx == -1:
		return
	var target: float = DUCKED_DB if ducked else 0.0
	# Bus volume is not a node property, so tween a throwaway object and mirror it
	# (silence_zone.gd's idiom).
	var holder := {"v": AudioServer.get_bus_volume_db(idx)}
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		AudioServer.set_bus_volume_db(idx, v), holder["v"], target, 0.6)


func _start_ambience() -> void:
	_ambient_player = get_node_or_null("AmbientPlayer") as AudioStreamPlayer
	if _ambient_player:
		var bed := GameState.load_audio("ambient_dungeon")
		if bed:
			_ambient_player.stream = bed
			_ambient_player.volume_db = BED_DB
			_ambient_player.bus = AUDIO_BUS
			# ⚠️ Every .wav.import here is loop_mode=0, so a loop is the
			# finished -> play reconnect. walk_lab_wing.gd asserts this idiom.
			if not _ambient_player.finished.is_connected(_ambient_player.play):
				_ambient_player.finished.connect(_ambient_player.play)
			_ambient_player.play()

	# The user-supplied score. It goes ON the duckable bus deliberately: the music
	# CUTTING is DN's signature tell, and a featureless wind bed alone is a weaker
	# version of the same beat.
	var music := GameState.load_audio("dungeon_music")
	if music:
		_music = AudioStreamPlayer.new()
		_music.name = "DungeonMusic"
		_music.stream = music
		_music.volume_db = MUSIC_DB
		_music.bus = AUDIO_BUS
		add_child(_music)
		_music.finished.connect(_music.play)
		_music.play()


func _play_at(base_name: String, pos: Vector3, volume_db: float) -> void:
	var s := GameState.load_audio(base_name)
	if s == null:
		return
	var pl := AudioStreamPlayer3D.new()
	pl.stream = s
	pl.unit_size = 8.0
	pl.max_db = 6.0
	pl.volume_db = volume_db
	pl.bus = AUDIO_BUS
	pl.position = pos
	add_child(pl)
	pl.play()
	pl.finished.connect(pl.queue_free)


# ── Lighting ────────────────────────────────────────────────────────────────────
# §B7: darkness WITHOUT fog. Ambient ~0.02 and a pure black background mean that
# beyond the candle's 4.5 m radius there is literally no light, so unlit geometry
# renders black. That is fog, for free, and it is physically motivated.
# ⚠️ Do NOT add a depth-fade ColorRect shader — that is fog by another name, it is
# outside this project's rendering contract, and it would fight PanicHUD's
# BlurRect/TintRect stack.
func _darken_ambient() -> void:
	var we := get_node_or_null("Environment/WorldEnvironment") as WorldEnvironment
	if we == null:
		we = _find_world_env(self)
	if we == null or we.environment == null:
		return
	# Duplicate before mutating: the Environment resource is SHARED between scenes,
	# so editing it in place would darken every other level too.
	_env = we.environment.duplicate()
	we.environment = _env
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0, 0, 0)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.5, 0.52, 0.58)
	_env.ambient_light_energy = _base_ambient

	# §B7's legitimate, non-fog framing device. A cold blue-grey rather than the
	# warm tints the other levels use: the candle is the only warm thing down here
	# and the vignette should not compete with it.
	# ⚠️ NOT a depth-fade shader — that is fog by another name and is rejected by
	# both §B7 and SCARY.md §8.9. This is screen-space and depth-independent.
	Vignette.spawn(self, Color(0.55, 0.58, 0.7, 1.0), 2.2)

	# ── The fog EXPERIMENT (SCARY.md §4.3, DUNGEON_NIGHTMARES.md §B7) ──────────
	# ⚠️ OFF, and it must stay off until the user decides otherwise.
	#
	# This level is the only sane venue for the experiment — it is the only one with
	# no legacy emission tuning to break — and §B7 requires it to be fully playable
	# and correct WITHOUT fog, which it is. Flip this to true to A/B it.
	#
	# Measured with it on: fog fills the volume the candle cannot reach, so the
	# "wall of black at 4.5 m" becomes a soft grey gradient. That reads as more
	# conventionally atmospheric AND it destroys the mechanic — §B7's whole argument
	# is that darkness here is RANGE FALLOFF, physically motivated, and that the
	# edge of the candle's reach is the thing you are afraid of. Fog puts a floor
	# under the darkness: nothing is ever fully black, so the Hollow One's reveal
	# has less to emerge from and an unlit sconce stops being genuinely invisible.
	# It also lifts the apparent brightness of every surface at once, which is
	# exactly the "recolours every emission value in the project" risk §4.3 flags.
	if FOG_EXPERIMENT:
		_env.fog_enabled = true
		_env.fog_light_color = Color(0.06, 0.06, 0.08)
		_env.fog_density = 0.035
		_env.fog_sky_affect = 0.0


func _find_world_env(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for c in node.get_children():
		var r := _find_world_env(c)
		if r != null:
			return r
	return null


# ── Doors ───────────────────────────────────────────────────────────────────────
func _spawn_level_doors() -> void:
	var back := _make_door("BackDoor", false, true)
	back.position = ANTE_ORIGIN + Vector3(-4.4, 1.2, 0)
	back.rotation.y = PI / 2.0

	_exit_door = _make_door("ExitDoor", true, false)
	_exit_door.position = ANTE_ORIGIN + Vector3(4.4, 1.2, 0)
	_exit_door.rotation.y = -PI / 2.0


func _make_door(door_name: String, advances: bool, back: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = door_name
	body.set_script(_DOOR_SCRIPT)
	body.advances_level = advances
	body.goes_back = back
	# ⚠️ Box for depth, QuadMesh for the art. A texture on a BoxMesh face renders a
	# magnified CROP of itself (Issue 24, recurred as Issue 31).
	_DOOR_SCRIPT.build_visual(body, Vector3(1.25, 2.45, 0.15), TEX + "dungeon_door.png")
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.25, 2.45, 0.2)
	col.shape = sh
	body.add_child(col)
	add_child(body)
	return body


func _refresh_exit() -> void:
	if not is_instance_valid(_exit_door):
		return
	var done: bool = _sconces_lit >= SCONCE_TOTAL and _teach_beats.get("woke", false)
	_exit_door.extra_lock = not done
	_exit_door.locked_message = "YOU ARE STILL ASLEEP — %d OF %d SCONCES" % [
		_sconces_lit, SCONCE_TOTAL]


# ── Sleep / wake ────────────────────────────────────────────────────────────────
func _on_cot_used() -> void:
	if _in_dungeon:
		return
	_sleep_transition(true)


func _on_bed_used() -> void:
	if not _in_dungeon:
		return
	_teach_beats["woke"] = true
	_sleep_transition(false)


func _sleep_transition(into_dungeon: bool) -> void:
	var p := _player()
	if p == null:
		return
	p.freeze_input()
	_play_at("cot_sleep", p.global_position, -2.0)
	var fade := ColorRect.new()
	var layer := CanvasLayer.new()
	layer.layer = 60
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	add_child(layer)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 1.6)
	tw.tween_callback(_after_blackout.bind(into_dungeon, fade, layer))


# ⚠️ The two directions are NOT symmetric any more. Going under is still a fade — `dungeon_sleep`
# was never generated. Waking has a clip, and it is the reward for seven sconces, so it gets the
# screen. The teleport happens here either way, under full black, before anything is shown.
func _after_blackout(into_dungeon: bool, fade: ColorRect, layer: CanvasLayer) -> void:
	if into_dungeon:
		_finish_transition(true, true)
		_lift_black(fade, layer)
		return

	# ⚠️ unfreeze = false. `_finish_transition` hands control back on its last line, and doing
	# that here would leave the player walking around behind ten seconds of video.
	_finish_transition(false, false)
	var cutscene := CutscenePlayer.play(self, WAKE_VIDEO)
	if cutscene == null:
		# Headless, or no file: the original 1.2 s fade-up, to the frame.
		_lift_black(fade, layer)
		var pf := _player()
		if pf != null:
			pf.unfreeze_input()
		return
	cutscene.finished.connect(_on_wake_cutscene_finished.bind(fade, layer))


# ⚠️ THE CLIP FADES OUT TO BLACK, AND THE LEVEL FADES BACK UP — do not "simplify" this into a hard
# cut. A hard cut was tried first, on the reasoning that the clip's last frame IS the Antechamber
# so there was nothing to hide. That reasoning was wrong and the measurement is why:
# `screenshot_wake_cutscene.gd` photographed both sides of the join and the clip's last frame reads
# **0.171 mean luminance against the live room's 0.008** — a 21x snap. Veo lights a stone room like
# a film set; this level runs at ambient 0.045 with no flashlight and an unlit candle, and the
# Antechamber at that moment is a black room with a red door in it.
#
# So `dungeon_wake.ogv` carries `fade=t=out` (see assets_src/README.md) and hands over ON BLACK,
# where the layer-60 ColorRect underneath is already black — nothing changes on screen when
# `CutscenePlayer` frees itself — and the ordinary fade-up then reveals the room.
func _on_wake_cutscene_finished(fade: ColorRect, layer: CanvasLayer) -> void:
	if not is_instance_valid(layer) or not is_instance_valid(fade):
		return
	_lift_black(fade, layer)
	var p := _player()
	if p != null:
		p.unfreeze_input()


func _lift_black(fade: ColorRect, layer: CanvasLayer) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 1.2)
	tw.tween_callback(layer.queue_free)


func _finish_transition(into_dungeon: bool, unfreeze: bool = true) -> void:
	var p := _player()
	if p == null:
		return
	_in_dungeon = into_dungeon
	if into_dungeon:
		var c: Vector3 = _gen.room_center_world(_gen.spawn_room)
		p.global_position = c + Vector3(0, 0.1, 0)
		GameState.set_objective("SCONCES LIT: 0 / %d" % SCONCE_TOTAL)
		ScreenText.caption(get_tree(),
			"F — LIGHT THE CANDLE.    C — STRIKE A SPARK.", 6.0)
	else:
		p.global_position = ANTE_ORIGIN + Vector3(0, 0.1, 0)
		GameState.set_objective("THE TRIAL IS LOGGED. LEAVE.")
		_refresh_exit()
	if unfreeze:
		p.unfreeze_input()


# ── Per-frame orchestration ─────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not _in_dungeon:
		return
	var p := _player()
	if p == null:
		return

	_tick_matron(delta)
	_tick_sprint_deafness(p)
	_tick_ambient_dip()
	_tick_slam_doors()
	_tick_noise(delta, p)
	_tick_hunter_voice(delta)
	_tick_chase_cue(delta)
	_tick_room_tracking(p)
	if _in_cistern:
		p.apply_slow(0.6)   # re-applied per frame while wading, the Flood's idiom

	# The Child: harmless, always. Only while the candle is OUT (its suppression is
	# the candle's one clean upside), and ⚠️ only when no primary entity is present
	# — DN2's rule that the game never stacks a fake scare onto a real threat.
	var primary_out: bool = _matron_present
	var candle_out: bool = _candle == null or not _candle.burning
	if _child:
		_child.tick(delta, candle_out and not primary_out)


# ⭐ §B1 rule 3. Your own footsteps mask the Matron's steps and the Hollow One's
# knock. Diegetically true, mechanically vicious, and it needs no new economy —
# just a volume duck while sprinting. RUNNING MAKES YOU BLIND TO THE THING THAT
# WOULD HAVE MADE PANIC UNNECESSARY.
func _tick_sprint_deafness(p: CharacterBody3D) -> void:
	var sprinting: bool = p.is_sprinting()
	if _hunter_voice:
		_hunter_voice.volume_db = HUNTER_VOICE_DB + (SPRINT_DEAF_DB if sprinting else 0.0)
	if _matron_steps:
		_matron_steps.volume_db = -4.0 + (SPRINT_DEAF_DB if sprinting else 0.0)
	if _matron_theme and _matron_present:
		var base: float = _matron_theme.volume_db
		if sprinting:
			_matron_theme.volume_db = minf(base, -30.0)


# The post-spark dip: "after that, it gets darker than before, until your vision is
# back to normal." This is what makes a FREE action feel expensive.
func _tick_ambient_dip() -> void:
	if _env == null or _candle == null:
		return
	var dip: float = _candle.dip_ratio()
	_env.ambient_light_energy = _base_ambient * (1.0 - 0.85 * dip)


# ⚠️ THE SAME THREE GUARDS AS `level_6_breach.gd:_tick_slam_doors()` — see the long comment there
# for what each one closes. This is the second copy of that loop and it had the identical faults:
# STAGGERED was not excluded, a degenerate zero-length segment was fed to the AABB test, and a door
# anywhere on the line could stop the Matron in open floor for 10 s.
const BATTER_REACH := 4.0


func _tick_slam_doors() -> void:
	if not _matron_present or _matron == null:
		return
	var st: int = _matron.get_state()
	if st == 0 or st == 4:   # State.PATROL (nothing to block) / State.STAGGERED (already down)
		return
	var here: Vector3 = _matron.get_creature_position()
	var target: Vector3 = _matron.get_current_target()
	if here.distance_to(target) < 0.05:
		return
	for d in _slam_doors:
		if not is_instance_valid(d):
			continue
		if here.distance_to((d as Node3D).global_position) > BATTER_REACH:
			continue
		if d.check_blocks_path(here, target):
			d.start_battering(_matron)


# ── Progress ────────────────────────────────────────────────────────────────────
func save_progress() -> Dictionary:
	return {
		"layout_seed": _layout_seed,
		"content_seed": _content_seed,
		"sconces_lit": _sconces_lit,
		"candles_held": _candle.candles if _candle else Candle.CARRY_CAP,
		"teach_beats_done": _teach_beats.duplicate(),
		"in_dungeon": _in_dungeon,
		"map_found": _map_found,
		"rooms_seen": _rooms_seen.duplicate(),
		"scares_fired": _scares_fired.duplicate(),
	}


func _restore_progress() -> void:
	var data := GameState.get_level_progress(7)
	if data.is_empty():
		return
	_teach_beats = (data.get("teach_beats_done", {}) as Dictionary).duplicate()
	if _candle:
		_candle.candles = int(data.get("candles_held", Candle.CARRY_CAP))
	# The scares are restored as SPENT before the sconces are relit, so a relit sconce fires
	# nothing (its room is already in the list); the map comes back with what it had drawn.
	_scares_fired = (data.get("scares_fired", []) as Array).duplicate()
	_rooms_seen = (data.get("rooms_seen", []) as Array).duplicate()
	_map_found = bool(data.get("map_found", false))
	if _map:
		_map.set_found(_map_found)
	if _map_found and is_instance_valid(get_node_or_null("MapPickup")):
		get_node("MapPickup").queue_free()
	var want: int = int(data.get("sconces_lit", 0))
	for i in range(mini(want, _sconces.size())):
		_sconces[i].light_it()
		_sconces_lit += 1
		var nm: String = String(_sconces[i].name).trim_prefix("Sconce_")
		if not _scares_fired.has(nm):
			_scares_fired.append(nm)
	if _sconces_lit > 0:
		_on_sconce_count_changed()
	_map_refresh()
	if bool(data.get("in_dungeon", false)):
		_in_dungeon = true
		var p := _player()
		if p:
			p.global_position = _gen.room_center_world(_gen.spawn_room) + Vector3(0, 0.1, 0)
	_refresh_exit()


# ── Room archetypes (dungeon_rooms.gd) ──────────────────────────────────────────
func _spawn_rooms() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _content_seed * 7 + 3
	for nm in _gen.chamber_names:
		var kind: String = _gen.kind_of(nm)
		if kind == "":
			continue
		_room_handles[nm] = _ROOMS_SCRIPT.build(kind, self, _builder, _gen, nm, rng)


# The one scare a room owns, once. Refused (and retried in 0.25 s) while a note is open, the
# tree is paused or the player is frozen — the cellar child's rule: a scare fired at a player
# who cannot react is a scare nobody gets.
func _fire_room_scare(nm: String) -> void:
	if _scares_fired.has(nm) or not _room_handles.has(nm):
		return
	var p := _player()
	if p == null:
		return
	if NoteUI.is_open or get_tree().paused or p.is_input_frozen():
		var t := get_tree().create_timer(0.25)
		t.timeout.connect(_fire_room_scare.bind(nm))
		return
	_scares_fired.append(nm)
	_ROOMS_SCRIPT.fire(_gen.kind_of(nm), _room_handles[nm], self, p)


func _room_has_sconce(nm: String) -> bool:
	for sp in _gen.sconce_spots:
		if sp["room"] == nm:
			return true
	return false


# Which room the player is in, for the map and for the entry-triggered scares (rooms with no
# sconce fire on first entry; rooms with one fire when it is lit).
func _tick_room_tracking(p: CharacterBody3D) -> void:
	var nm: String = _gen.room_at(p.global_position)
	if nm == "" or nm == _current_room:
		return
	_current_room = nm
	if not _rooms_seen.has(nm):
		_rooms_seen.append(nm)
		_map_refresh()
	if _room_handles.has(nm) and not _room_has_sconce(nm):
		_fire_room_scare(nm)


# ── callbacks the archetypes fire (dungeon_rooms.gd) ────────────────────────────
func frames_in_room(nm: String) -> Array:
	var out: Array = []
	for f in _frames:
		if is_instance_valid(f) and String(f.name).begins_with("Frame_" + nm + "_"):
			out.append(f)
	return out


# The Gallery: the painting furthest from where the player is looking drops off its wall.
func gallery_drop(nm: String) -> void:
	var p := _player()
	var best = null
	var best_score := -INF
	for f in frames_in_room(nm):
		if f.has_fallen():
			continue
		var score := 0.0
		if p:
			var cam: Camera3D = p.get_node_or_null("Camera3D") as Camera3D
			var to: Vector3 = (f as Node3D).global_position - p.global_position
			var fwd: Vector3 = -cam.global_transform.basis.z if cam else Vector3.FORWARD
			score = -fwd.dot(to.normalized())   # behind the player scores highest
		if score > best_score:
			best_score = score
			best = f
	if best == null:
		return
	best.fall()
	if p:
		p.jolt_camera(0.08, 0.3)


# The Well: the Child peeks over the rim. Deferred once if the hunter is out (DN2: never a fake
# scare on top of a real threat).
func child_peek_at(pos: Vector3) -> void:
	if _child == null:
		return
	if _matron_present:
		var t := get_tree().create_timer(8.0)
		t.timeout.connect(func() -> void:
			if _child and not _matron_present:
				_child.fire_now(0, pos))
		return
	_child.fire_now(0, pos)


# The Crypt: the statue in the sarcophagus is awake without ever having been looked at.
func wake_statue_in(nm: String) -> void:
	for st in _still_ones:
		if is_instance_valid(st) and String(st.name) == "StillOne_" + nm and not st.has_fallen():
			st.wake()


# The Cistern: wading. Re-applied per frame in _process while inside.
func cistern_set(_nm: String, inside: bool) -> void:
	_in_cistern = inside


# ── The map (dungeon_map_ui.gd) ─────────────────────────────────────────────────
func _spawn_map() -> void:
	_map = _MAP_SCRIPT.new()
	_map.name = "DungeonMap"
	add_child(_map)
	_map.setup(_gen)
	# The folded plan: on the Antechamber's candle rack, next to the four candles the protocol
	# note says you are given. A KeyItem so the shipping interact ray and prompt find it.
	var pickup := _KEY_SCRIPT.new()
	pickup.name = "MapPickup"
	pickup.label_text = "The plan of the lower floor"
	pickup.position = ANTE_ORIGIN + Vector3(2.6, 0.93, -2.4) + Vector3(0.55, 0, 0.1)
	pickup.collision_layer = 2
	pickup.collision_mask = 0
	add_child(pickup)
	var sheet := MeshInstance3D.new()
	sheet.name = "FoldedPlan"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.02, 0.16)
	sheet.mesh = bm
	sheet.set_surface_override_material(0, _NOTE_SCRIPT.paper_material(false))
	pickup.add_child(sheet)
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.4, 0.3, 0.35)
	col.shape = sh
	pickup.add_child(col)
	pickup.picked_up.connect(_on_map_picked)


func _on_map_picked() -> void:
	_map_found = true
	if _map:
		_map.set_found(true)
	ScreenText.caption(get_tree(), "M — THE PLAN. IT DRAWS ONLY WHAT YOU HAVE WALKED.", 5.0)


func _map_refresh() -> void:
	if _map == null:
		return
	var lit: Array = []
	for sc in _sconces:
		if is_instance_valid(sc) and sc.is_lit:
			lit.append(sc.global_position)
	_map.refresh(_rooms_seen, lit)


# ── Test surface ────────────────────────────────────────────────────────────────
# Read by check_dungeon_entities.gd / walk_dungeon.gd. Exposing the generator lets a
# test assert against the DATA that produced the geometry as well as the geometry.
func get_gen():
	return _gen


func get_sconces() -> Array:
	return _sconces


func sconces_lit() -> int:
	return _sconces_lit


func get_hunter():
	return _matron


func hunter_present() -> bool:
	return _matron_present


func get_map():
	return _map


func rooms_seen() -> Array:
	return _rooms_seen


func scares_fired() -> Array:
	return _scares_fired


func room_handles() -> Dictionary:
	return _room_handles
