extends Node3D

# Level 6 — THE BREACH. Object 12, KONTUR's subject, loose. A Nemesis/Mr.X-style
# pursuit level built procedurally with RoomBuilder, following the exact
# .tscn-minimal / PRESERVE-whitelist pattern kontur.gd established: the .tscn keeps
# only Environment/AmbientPlayer/Player, everything else is built here in _ready().
#
# Familiarization window: Object 12 stays dormant at its patrol start for
# FAMILIARIZATION_TIME seconds (Mr.X pacing — learn the layout before the threat
# appears), then activates and roams the level for good.
#
# Win/lose: the ONLY permanent win condition is luring the creature into the
# PurgeChamber (see purge_chamber.gd) — light-as-weapon only staggers it temporarily,
# contact is instant-fatal like every other creature in the game. No DreadZone, no
# DarkZone, no extra trap props: this level's pressure is the chase itself plus the
# game's existing sprint-panic economy, deliberately not more trap-grammar.

const PRESERVE := ["Environment", "AmbientPlayer", "HUDCanvas", "Player"]
const TEX := "res://assets/textures/level_6_breach/"
const LAB_TEX := "res://assets/textures/level_1_lab/"
const KONTUR_TEX := "res://assets/textures/level_5_kontur/"
const _DOOR_SCRIPT := preload("res://scripts/door.gd")
const _NOTE_SCRIPT := preload("res://scripts/note.gd")

# The familiarization window exists so the player can learn the layout before the threat
# appears — which is only worth paying for ONCE. On a retry they already know the rooms,
# so the wait is dead time; the window shortens instead of disappearing, because the
# first seconds after a restart are also when the player is re-orienting at the entrance.
# Attempt count comes from GameState.level_attempts (survives the death, cleared per run).
const FAMILIARIZATION_FIRST := 30.0   # first attempt at this level in this run
const FAMILIARIZATION_RETRY := 10.0   # every attempt after a death here
const PATROL_LOOP := ["Junction1", "Atrium", "Junction2", "WardB", "Corridor1"]
# ⚠️ 18.0, MARRIED TO `player.gd:FLASH_RANGE` (2026-09-03) — the same argument this file already
# makes one line below for the CONE, made for the reach. The torch went 15 -> 18 m in the darkness
# pass; leaving this at 12 means the beam visibly lands on Object 12 from 15 m and the shield does
# not drain, which reads as the weapon being broken rather than as a rule about distance.
const LIGHT_WEAPON_RANGE := 18.0
# ⚠️ 0.866 = cos(30 deg), MARRIED TO `player.gd:FLASH_ANGLE` (2026-09-03). The old comment on
# this line already said "tight cone matching the flashlight's own spot_angle", and 0.9 was
# cos(25 deg) — correct while the torch was 25 degrees. The darkness pass widened it to 30, and
# leaving this at 0.9 would mean the visible beam covers Object 12 while the light weapon does
# not register, which reads as a bug rather than as a rule. A small Level 6 difficulty change,
# made for consistency and flagged rather than done silently.
const LIGHT_WEAPON_DOT := 0.866    # cos(player.gd FLASH_ANGLE)
const DOOR_TEX := "res://assets/textures/level_6_breach/breach_door.png"
const SPRINT_NOISE_RADIUS := 14.0
const SLAM_NOISE_RADIUS := 16.0

# A single spine running +z, with two bypass loops (WardA east of Atrium/Junction2,
# Archive west of Junction2/WardB) so route-planning and breaking line-of-sight
# actually mean something. Every pair of connected rooms shares an EXACT wall plane
# (RoomBuilder's hard rule — see ISSUES_SOLUTIONS.md's coincident-surface playbook);
# z-ranges are annotated per room for exactly that reason, matching kontur.gd's ROOMS
# table style.
const ROOMS := [
	{ "name": "Entry",       "pos": Vector2(0, 0),     "size": Vector2(6, 6) },   # z -3 ..  3
	{ "name": "Corridor1",   "pos": Vector2(0, 7),     "size": Vector2(4, 8) },   # z  3 .. 11
	{ "name": "Junction1",   "pos": Vector2(0, 14),    "size": Vector2(8, 6) },   # z 11 .. 17
	{ "name": "Records",     "pos": Vector2(-7, 14),   "size": Vector2(6, 6) },   # z 11 .. 17
	{ "name": "Atrium",      "pos": Vector2(0, 22),    "size": Vector2(8, 10) },  # z 17 .. 27
	{ "name": "WardA",       "pos": Vector2(7, 25),    "size": Vector2(6, 16) },  # z 17 .. 33
	{ "name": "Junction2",   "pos": Vector2(0, 30),    "size": Vector2(8, 6) },   # z 27 .. 33
	{ "name": "ArchiveA",    "pos": Vector2(-7, 30.5), "size": Vector2(6, 7) },   # z 27 .. 34
	{ "name": "ArchiveB",    "pos": Vector2(-7, 37.5), "size": Vector2(6, 7) },   # z 34 .. 41
	{ "name": "WardB",       "pos": Vector2(0, 37),    "size": Vector2(8, 8) },   # z 33 .. 41
	{ "name": "WardC",       "pos": Vector2(0, 45),    "size": Vector2(8, 8) },   # z 41 .. 49
	{ "name": "PurgeAnte",   "pos": Vector2(0, 52),    "size": Vector2(5, 6) },   # z 49 .. 55
	{ "name": "Incinerator", "pos": Vector2(0, 58.5),  "size": Vector2(7, 7) },   # z 55 .. 62
]

const DOORS := [
	{ "pos": Vector2(0, 3),   "width": 1.8, "dir": "z" },   # Entry <-> Corridor1
	{ "pos": Vector2(0, 11),  "width": 1.8, "dir": "z" },   # Corridor1 <-> Junction1
	{ "pos": Vector2(-4, 14), "width": 1.8, "dir": "x" },   # Junction1 <-> Records
	{ "pos": Vector2(0, 17),  "width": 1.8, "dir": "z" },   # Junction1 <-> Atrium
	{ "pos": Vector2(4, 21),  "width": 1.8, "dir": "x" },   # Atrium <-> WardA
	{ "pos": Vector2(0, 27),  "width": 1.8, "dir": "z" },   # Atrium <-> Junction2
	{ "pos": Vector2(4, 30),  "width": 1.8, "dir": "x" },   # WardA <-> Junction2
	{ "pos": Vector2(-4, 30), "width": 1.6, "dir": "x" },   # Junction2 <-> ArchiveA
	{ "pos": Vector2(0, 33),  "width": 1.8, "dir": "z" },   # Junction2 <-> WardB
	{ "pos": Vector2(-7, 34), "width": 1.6, "dir": "z" },   # ArchiveA <-> ArchiveB
	{ "pos": Vector2(-4, 37), "width": 1.6, "dir": "x" },   # ArchiveB <-> WardB
	{ "pos": Vector2(0, 41),  "width": 1.8, "dir": "z" },   # WardB <-> WardC
	{ "pos": Vector2(0, 49),  "width": 1.8, "dir": "z" },   # WardC <-> PurgeAnte
	{ "pos": Vector2(0, 55),  "width": 2.2, "dir": "z" },   # PurgeAnte <-> Incinerator (PurgeChamber sits here)
]

# The visual arc IS the story: facility -> structural rupture -> organic decay,
# extending KONTUR's two-tier skin system to three tiers. Incinerator/PurgeAnte get
# their own scorched-steel skin.
const RUPTURED_ROOMS := ["Junction1", "Records", "Atrium", "WardA", "Junction2"]
const ORGANIC_ROOMS := ["ArchiveA", "ArchiveB", "WardB", "WardC"]
const SCORCHED_ROOMS := ["PurgeAnte", "Incinerator"]

var _builder: RoomBuilder
var _lights: Array = []
var _slam_doors: Array = []
var _creature: CreatureObject12
var _purge_chamber: PurgeChamber
var _exit_door: StaticBody3D
var _creature_defeated: bool = false
var _creature_awake: bool = false
var _familiarization_t: float = 0.0
var _familiarization_time: float = FAMILIARIZATION_FIRST


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameState.current_level = 6

	_familiarization_time = FAMILIARIZATION_FIRST if GameState.get_level_attempts(6) == 0 else FAMILIARIZATION_RETRY

	_clear_old_scene()
	_build_geometry()
	_place_player()
	_spawn_lights()
	_spawn_creature()
	_spawn_hiding_spots()
	_spawn_slam_doors()
	_spawn_purge_chamber()
	_spawn_signs()
	_spawn_notes()
	_spawn_level_doors()
	_frame_bare_openings()
	_refresh_exit()
	_start_ambience()
	_boost_ambient(0.28)

	GameState.set_objective("OBJECT 12 HAS NOT NOTICED YOU YET — MOVE.")
	_restore_progress()


func _player() -> CharacterBody3D:
	return get_node_or_null("Player") as CharacterBody3D


func _clear_old_scene() -> void:
	for child in get_children():
		if PRESERVE.has(child.name):
			continue
		# ⚠️ remove_child BEFORE queue_free. queue_free() is deferred to the end of the
		# frame, so a node freed this way is STILL A CHILD — and still holding its name
		# — while _ready() builds the replacement level. Godot then renames the new
		# node on the collision (Issue 17), and every later get_node("ExitDoor") in
		# these levels silently missed: probed on the Lab, both doors came back as
		# @StaticBody3D@332 / @334. remove_child() detaches immediately, so the name is
		# free by the time the new door is added. (Found 2026-07-27 by the autoplay
		# harness, which is the first thing that ever looked a door up by name.)
		remove_child(child)
		child.queue_free()


# ---------------------------------------------------------------- geometry

func _build_geometry() -> void:
	_builder = RoomBuilder.new()
	_builder.wall_mat = _mat(KONTUR_TEX + "kontur_facility_wall.png", 0.4, Color(0.5, 0.52, 0.5))
	_builder.floor_mat = _mat(LAB_TEX + "lab_floor.png", 0.4, Color(0.32, 0.32, 0.3))
	_builder.ceil_mat = _mat(LAB_TEX + "lab_ceiling.png", 0.4, Color(0.22, 0.22, 0.2))
	add_child(_builder)
	_builder.build(_rooms_with_skins(), DOORS)


# Negative V, like every other builder in this project — a positive uv1_scale.y
# renders wall textures upside-down under triplanar mapping.
func _mat(tex_path: String, scale: float, fallback: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.92
	if tex_path != "" and ResourceLoader.exists(tex_path):
		mat.albedo_texture = load(tex_path)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(scale, -scale, scale)
	else:
		mat.albedo_color = fallback
	return mat


func _rooms_with_skins() -> Array:
	var ruptured := _mat(TEX + "breach_wall_ruptured.png", 0.35, Color(0.34, 0.3, 0.28))
	var organic := _mat(TEX + "breach_wall_organic.png", 0.35, Color(0.16, 0.1, 0.1))
	var organic_floor := _mat(TEX + "breach_floor_scorched.png", 0.4, Color(0.08, 0.06, 0.06))
	var scorched := _mat(TEX + "breach_incinerator_wall.png", 0.4, Color(0.15, 0.13, 0.12))

	var out: Array = []
	for r in ROOMS:
		var room: Dictionary = r.duplicate()
		var n: String = room["name"]
		if SCORCHED_ROOMS.has(n):
			room["wall_mat"] = scorched
			room["floor_mat"] = scorched
		elif ORGANIC_ROOMS.has(n):
			room["wall_mat"] = organic
			room["floor_mat"] = organic_floor
		elif RUPTURED_ROOMS.has(n):
			room["wall_mat"] = ruptured
		out.append(room)
	return out


const ENTRY_SPAWN := Vector3(0, 0.1, -2.0)
const EXIT_SPAWN := Vector3(0, 0.1, 59.5)     # Incinerator, just inside the exit

func _place_player() -> void:
	var p := _player()
	if not p:
		return
	if GameState.entered_from_ahead:
		p.global_position = EXIT_SPAWN
		p.rotation = Vector3(0, 0, 0)
	else:
		p.global_position = ENTRY_SPAWN
		p.rotation = Vector3(0, PI, 0)   # face +z, down the spine


# ---------------------------------------------------------------- progress snapshot
#
# One boolean, as the exit lock is one boolean. If Object 12 has already been purged,
# walking back to KONTUR and returning must not resurrect it — re-running a chase you
# have already won is the purest form of the BACKLOG #30 complaint.

func save_progress() -> Dictionary:
	return {"creature_defeated": _creature_defeated}


func _restore_progress() -> void:
	var data := GameState.get_level_progress(6)
	if not bool(data.get("creature_defeated", false)):
		return
	_creature_defeated = true
	if is_instance_valid(_creature) and _creature.has_method("lure_into_trap"):
		_creature.lure_into_trap()
	_refresh_exit()
	GameState.set_objective("IT IS SEALED. LEAVE.")


# ---------------------------------------------------------------- lighting

func _spawn_lights() -> void:
	# Cool/clean near Entry, warming and dimming toward the organic wing, a hot
	# scorched-orange at the Incinerator.
	_add_lamp("Entry", Vector3(0, 2.6, 0), 0.55, Color(0.85, 0.88, 0.9))
	_add_lamp("Corridor1", Vector3(0, 2.6, 7), 0.45, Color(0.8, 0.85, 0.88))
	_add_lamp("Junction1", Vector3(0, 2.6, 14), 0.4, Color(0.75, 0.7, 0.6))
	_add_lamp("Records", Vector3(-7, 2.6, 14), 0.4, Color(0.75, 0.7, 0.6))
	_add_lamp("Atrium", Vector3(0, 2.6, 22), 0.42, Color(0.7, 0.62, 0.55))
	_add_lamp("WardA", Vector3(7, 2.6, 25), 0.35, Color(0.65, 0.55, 0.5))
	_add_lamp("Junction2", Vector3(0, 2.6, 30), 0.35, Color(0.6, 0.5, 0.45))
	_add_lamp("ArchiveA", Vector3(-7, 2.4, 30.5), 0.28, Color(0.5, 0.35, 0.3))
	_add_lamp("ArchiveB", Vector3(-7, 2.4, 37.5), 0.25, Color(0.45, 0.3, 0.28))
	_add_lamp("WardB", Vector3(0, 2.4, 37), 0.28, Color(0.5, 0.3, 0.28))
	_add_lamp("WardC", Vector3(0, 2.4, 45), 0.22, Color(0.45, 0.25, 0.25))
	_add_lamp("PurgeAnte", Vector3(0, 2.6, 52), 0.6, Color(0.85, 0.9, 0.95))
	_add_lamp("Incinerator", Vector3(0, 2.6, 58.5), 0.7, Color(0.9, 0.75, 0.55))


func _add_lamp(lamp_name: String, pos: Vector3, energy: float, color: Color) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = "Lamp_" + lamp_name
	lamp.position = pos
	lamp.light_energy = energy
	lamp.light_color = color
	lamp.omni_range = 10.0
	add_child(lamp)
	_lights.append([lamp, energy])


# ---------------------------------------------------------------- creature

func _spawn_creature() -> void:
	_creature = CreatureObject12.new()
	# Set BEFORE add_child(): CreatureObject12._ready() seeds _body's transform from
	# global_transform the moment it enters the tree (the ScaryObject transform-chain
	# discipline — see Issue 10). Setting position after add_child() would move only
	# the outer Node3D, which _body never inherits from, leaving the creature stuck
	# at the origin. The level root itself carries no offset, so local position ==
	# global position here.
	_creature.position = _builder.room_center("Junction1")
	add_child(_creature)
	var wps := PackedVector3Array()
	for room in PATROL_LOOP:
		wps.append(_builder.room_center(room))
	_creature.set_waypoints(wps)
	# ⚠️ THE SAME GRAPH-AGNOSTIC CONTRACT AS `set_waypoints()` — the creature is handed the shape
	# of the world and never reads this file. Without it `_move_toward()` beelines through walls;
	# see the block above `set_portals()`. THE NIGHTMARE deliberately does not call this, so its
	# Matron keeps the old behaviour until it has been tested there on its own.
	_creature.set_portals(ROOMS, DOORS)
	_creature.staggered.connect(_on_creature_staggered)
	_creature.recovered.connect(_on_creature_recovered)


func _on_creature_staggered(duration: float) -> void:
	# Name the number. The stagger is now a randomised 5-7 s (BACKLOG #26) instead of a
	# flat 25 s, and a repel you cannot time is a repel you cannot plan around — the
	# whole point of the light weapon is buying a known amount of distance.
	ScreenText.toast(get_tree(), "IT RECOILS — %.0f SECONDS" % duration, Color(1.0, 0.6, 0.5))
	var p := _player()
	if p and p.has_method("jolt_camera"):
		p.jolt_camera(0.08, 0.4)
	_play_at("shield_stagger", _creature.get_creature_position(), 4.0)


# `recovered` was emitted by the creature from the day it was written and connected to
# NOTHING, so the end of a stagger was completely silent: it simply started moving
# again. With a 25 s window that was survivable ignorance; at 5-7 s the player needs to
# know the instant their head start is over.
func _on_creature_recovered() -> void:
	ScreenText.toast(get_tree(), "IT IS UP AGAIN", Color(1.0, 0.35, 0.3))
	_play_at("creature_growl_near", _creature.get_creature_position(), 2.0)


func _tick_familiarization(delta: float) -> void:
	# ⚠️ A RESTORED, ALREADY-WON LEVEL STILL RAN THIS CLOCK. `_restore_progress()` sets
	# `_creature_defeated` and kills the creature, but the gate was `_creature_awake` alone — so
	# walking back in through KONTUR's back door scrawled "IT IS AWAKE." at t=30.2 over a
	# creature that is already in the incinerator, and called `activate()` on the corpse. It was
	# inert only because `lure_into_trap()` also calls `set_process(false)`, which is luck rather
	# than a guard.
	if _creature_defeated or _creature_awake:
		return
	_familiarization_t += delta
	if _familiarization_t >= _familiarization_time:
		_creature_awake = true
		_creature.activate()
		GameState.set_objective("IT IS AWAKE.")
		ScreenText.scrawl(get_tree(), "IT IS AWAKE.", 3.0, 40)


func _tick_noise() -> void:
	var p := _player()
	if not p or not _creature:
		return
	if p.has_method("is_sprinting") and p.is_sprinting():
		_creature.notify_noise(p.global_position, SPRINT_NOISE_RADIUS)


func _tick_light_weapon(delta: float) -> void:
	var p := _player()
	if not p or not _creature or not p.has_method("is_flashlight_on"):
		return
	if not p.is_flashlight_on():
		return
	var cam: Camera3D = p.get_node_or_null("Camera3D")
	if not cam:
		return
	var creature_pos: Vector3 = _creature.get_creature_position() + Vector3(0, 0.9, 0)
	var to_creature := creature_pos - cam.global_position
	if to_creature.length() > LIGHT_WEAPON_RANGE:
		return
	# ⚠️ Horizontal-only, same fix and same reason as creature_object12.gd's own
	# _detect_player() FOV check (see the comment there): dotting the camera's FULL 3D
	# forward against the FULL 3D to-creature vector mixes in the vertical gap between
	# the camera's eye height and the creature's aim point (chest, +0.9). At close range
	# that gap dominates the vector — a player standing right next to the creature has
	# to look steeply down just to satisfy the dot product, which LIGHT_WEAPON_DOT=0.9's
	# tight cone makes nearly impossible. Found 2026-07-24 playtest: flashlight aimed
	# point-blank at the creature "did not stop him." Flatten to horizontal for aim;
	# height still matters for range/LOS above.
	var forward := -cam.global_transform.basis.z
	var forward_flat := Vector2(forward.x, forward.z)
	var to_creature_flat := Vector2(to_creature.x, to_creature.z)
	if to_creature_flat.length() > 0.01:
		if forward_flat.normalized().dot(to_creature_flat.normalized()) < LIGHT_WEAPON_DOT:
			return
	if not _has_clear_los(cam.global_position, creature_pos, p):
		return
	_creature.apply_light_damage(delta)


func _has_clear_los(from: Vector3, to: Vector3, player: Node) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid(), _creature.get_body_rid()]
	# Layer 1 only — see creature_object12.gd:_has_los for why (an open SlamDoor/
	# PurgeChamber's always-enabled interact collider, layer 2, must not block a
	# beam of light through its own open doorway).
	query.collision_mask = 1
	return space.intersect_ray(query).is_empty()


# ---------------------------------------------------------------- hiding spots

func _spawn_hiding_spots() -> void:
	_add_hiding_spot("Corridor1", Vector2(1, 0), "locker")
	_add_hiding_spot("Records", Vector2(0, 1), "cabinet")
	_add_hiding_spot("Atrium", Vector2(-1, 0), "desk")
	_add_hiding_spot("ArchiveA", Vector2(0, -1), "locker")
	_add_hiding_spot("WardB", Vector2(1, 0), "locker")
	_add_hiding_spot("WardC", Vector2(-1, 0), "cabinet")


func _add_hiding_spot(room: String, side: Vector2, kind: String) -> void:
	var spot := HidingSpot.new()
	spot.prop_kind = kind
	var pos := _builder.wall_point(room, side, 0.0, 0.22)
	spot.position = pos
	# Must face AWAY from the wall it's mounted on (into the room), i.e. -side, not
	# side — atan2(side.x, side.y) pointed the door's front (and its clearance
	# offset) INTO the wall instead, which is exactly what check_wall_overlap.gd's
	# QuadMesh-clearance check caught. kontur.gd:_make_sign() gets this right
	# empirically (side (1,0)/east -> -PI/2, side (-1,0)/west -> +PI/2); this is
	# that same formula generalized to all four sides.
	spot.rotation.y = atan2(-side.x, -side.y)
	add_child(spot)


# ---------------------------------------------------------------- slam doors

func _spawn_slam_doors() -> void:
	_add_slam_door("Slam_Corridor1_Junction1", Vector3(0, 0, 11), 0)
	_add_slam_door("Slam_Atrium_WardA", Vector3(4, 0, 21), 90)
	_add_slam_door("Slam_ArchiveB_WardB", Vector3(-4, 0, 37), 90)   # closes the loop
	_add_slam_door("Slam_WardB_WardC", Vector3(0, 0, 41), 0)


# The width of the doorway nearest `at`, from this level's own `DOORS` table. Nearest rather than
# exact because a slam door is placed at the THRESHOLD and a doorway is recorded at the wall
# plane; they agree to within a few cm but not to the bit.
# ⚠️ Falls back to SlamDoor's own default and WARNS rather than guessing, because a silent
# fallback is exactly how the 1.6 m doorway got a 1.8 m door in the first place.
func _doorway_width_at(at: Vector2) -> float:
	var best := -1.0
	var best_d := 3.0
	for d in DOORS:
		var dd: float = (Vector2(d["pos"]) - at).length()
		if dd < best_d:
			best_d = dd
			best = float(d["width"])
	if best < 0.0:
		push_warning("SlamDoor at %s matches no DOORS entry — falling back to the default width"
			% str(at))
		return 1.8
	return best


# Named, not anonymous: Godot renames colliding generated siblings using the CLASS
# name (Issue 17), so four unnamed SlamDoors report as @StaticBody3D@138/148/... and a
# failing assertion can't tell you WHICH door broke. Every name here is unique.
func _add_slam_door(door_name: String, pos: Vector3, yaw_deg: float) -> void:
	var door := SlamDoor.new()
	door.name = door_name
	door.position = pos
	door.rotation_degrees.y = yaw_deg
	# ⚠️⚠️ THE DOORWAY'S OWN WIDTH, READ OUT OF `DOORS` (2026-09-03). This used to pass nothing,
	# so every door took `SlamDoor`'s 1.8 m default — and **one of the four doorways in this level
	# is 1.6 m**: `Junction2 <-> ArchiveA` at (-4, 30). `Slam_ArchiveB_WardB` sits at (-4, 37)
	# but the sizing bug is the same class, and the symptom was unmistakable once the door was
	# built from its own dimensions: a 1.8 m leaf pair cannot swing anywhere inside a 1.6 m
	# opening, so `_pick_clear_swings()` walked its whole ladder, found nothing, and fell through
	# to its last resort — **all four art quads hidden, i.e. a bare untextured slab** standing
	# where a rusted blast door should be. Found by an audit probe, not by a test.
	# ⚠️ Looked up rather than typed, so a doorway that is re-sized in `DOORS` cannot silently
	# leave its door behind. `RoomBuilder.DEFAULT_H` is this level's room height.
	door.door_width = _doorway_width_at(Vector2(pos.x, pos.z))
	door.door_height = RoomBuilder.DEFAULT_H
	add_child(door)
	door.slammed.connect(_on_slam_door_slammed.bind(door))
	_slam_doors.append(door)


func _on_slam_door_slammed(door: SlamDoor) -> void:
	if _creature:
		_creature.notify_noise(door.global_position, SLAM_NOISE_RADIUS)


# ⚠️⚠️ THREE GUARDS, ADDED 2026-09-07, AND EACH CLOSES A MEASURED DEFECT.
#
# 1. **STAGGERED is excluded as well as PATROL.** `get_current_target()` returns the creature's OWN
#    position while staggered, so `check_blocks_path(here, here)` is a degenerate zero-length
#    segment — and `AABB.intersects_segment(p, p)` is true whenever the point is inside the box.
#    `_enter_stagger()`'s own comment says the creature routinely falls "dead-center in a doorway",
#    so slamming that door restarted a 10 s block on a creature that was already down, adding 10 s
#    to a beat whose length the level announces out loud.
# 2. **A degenerate segment is never fed to the AABB test at all**, whatever the state.
# 3. **A proximity gate.** `check_blocks_path()` is a pure segment/AABB test with no distance term,
#    so a door 25 m up the corridor that happens to lie on the line stopped the creature dead in
#    open floor for 10 s. ⚠️ This gate is also what makes the contact check staying live during a
#    block FAIR (see `creature_object12.gd:_process`) — with it, "battering" and "on top of you"
#    are the same place. The two changes ship together or neither does.
const BATTER_REACH := 4.0


func _tick_slam_doors() -> void:
	if not _creature:
		return
	var st: int = _creature.get_state()
	if st == CreatureObject12.State.PATROL or st == CreatureObject12.State.STAGGERED:
		return
	var here := _creature.get_creature_position()
	var target := _creature.get_current_target()
	if here.distance_to(target) < 0.05:
		return
	for door in _slam_doors:
		if here.distance_to(door.global_position) > BATTER_REACH:
			continue
		if door.check_blocks_path(here, target):
			door.start_battering(_creature)


# ---------------------------------------------------------------- purge chamber

func _spawn_purge_chamber() -> void:
	_purge_chamber = PurgeChamber.new()
	# ⚠️ NAMED. It was the only door in the level Godot auto-named ("@StaticBody3D@187"), which
	# makes it unfindable by anything that looks a prop up by name — Issue 17's shape.
	_purge_chamber.name = "PurgeChamber"
	_purge_chamber.position = Vector3(0, 0, 55)
	# World-space AABB of the Incinerator room (pos (0,58.5) size (7,7) -> z 55..62).
	_purge_chamber.trap_bounds = AABB(Vector3(-3.5, -0.5, 55.0), Vector3(7.0, 4.5, 7.0))
	add_child(_purge_chamber)
	_purge_chamber.creature_path = _purge_chamber.get_path_to(_creature)
	_purge_chamber.creature_trapped.connect(_on_creature_trapped)


func _on_creature_trapped() -> void:
	_creature_defeated = true
	_refresh_exit()
	GameState.set_objective("THE SEAL IS LIFTED. LEAVE.")
	ScreenText.toast(get_tree(), "OBJECT 12 — TERMINATED", Color(0.6, 1.0, 0.6))


# ---------------------------------------------------------------- signage

func _spawn_signs() -> void:
	# Fixed rotation, NOT billboard — a billboarded quad mounted this close to a
	# wall rotates INTO the wall at most viewing angles as the player walks around
	# (the classic depth-fight-resolves-per-angle bug: see ISSUES_SOLUTIONS.md's
	# coincident-surface playbook). kontur.gd's _make_sign() never billboards for
	# exactly this reason — mirror that pattern instead.
	_make_sign(_builder.wall_point("Entry", Vector2(1, 0), 1.6, 0.22), -PI / 2.0,
		"SUBLEVEL K-9\nCONTAINMENT BREACH")
	# A last reminder right before the trap room itself — a player who skipped the
	# opening note (or forgot it under pressure) gets one more chance to understand
	# the mechanic before they need it.
	_make_sign(_builder.wall_point("PurgeAnte", Vector2(-1, 0), 1.6, 0.22), PI / 2.0,
		"FINAL CONTAINMENT AHEAD\nLURE IT IN — SEAL THE DOOR")


func _make_sign(pos: Vector3, y_rot: float, text: String) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = y_rot
	add_child(root)

	var plate := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 0.75)
	plate.mesh = quad
	var pmat := StandardMaterial3D.new()
	var sign_tex := TEX + "object12_sign.png"
	if ResourceLoader.exists(sign_tex):
		var ptex := load(sign_tex)
		pmat.albedo_texture = ptex
		pmat.emission_enabled = true
		pmat.emission_texture = ptex
		pmat.emission_energy_multiplier = 0.55
	else:
		pmat.albedo_color = Color(0.4, 0.38, 0.35)
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	plate.set_surface_override_material(0, pmat)
	root.add_child(plate)

	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 44
	lbl.pixel_size = 0.0016
	lbl.modulate = Color(0.1, 0.1, 0.1)
	lbl.outline_size = 0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector3(0, 0, 0.012)
	root.add_child(lbl)


# ---------------------------------------------------------------- notes

# A playtest (2026-07-24) flagged that nothing in the level actually explains
# the win condition — the objective HUD only ever says "move" / "it is awake",
# never what to DO about it. One note at spawn, in Subject 47's own voice
# (matching every other level's opening note), fixes that directly rather than
# making the player infer "lure it into a room and shut a door" from nothing.
func _spawn_notes() -> void:
	_make_note(_builder.wall_point("Entry", Vector2(-1, 0), 1.4, 0.22), PI / 2.0,
		"Subject 47 — if you are reading this, KONTUR held. Something else did not.\n\nObject 12 is loose in this wing. It hunts by sight and sound. It moves faster than you walk. It does not move faster than you run.\n\nSustained light will wound it and drop it — that is not an ending, only a delay. It will rise again.\n\nThe only ending is the old decontamination chamber at the far end of this corridor. Lead it inside. Seal the door behind it.\n\nThere is no other way out.")


func _make_note(pos: Vector3, y_rot: float, text: String) -> void:
	var note := StaticBody3D.new()
	note.set_script(_NOTE_SCRIPT)
	note.note_text = text
	note.position = pos
	note.rotation.y = y_rot
	add_child(note)

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.32, 0.42, 0.01)
	mesh.mesh = bm
	mesh.set_surface_override_material(0, _NOTE_SCRIPT.paper_material(false))
	note.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.5, 0.12)
	col.shape = shape
	note.add_child(col)


# ---------------------------------------------------------------- level doors

func _spawn_level_doors() -> void:
	var back := _make_door("BackDoor", false, true)
	back.position = Vector3(0, 1.2, -2.85)

	_exit_door = _make_door("ExitDoor", true, false)
	_exit_door.position = Vector3(0, 1.2, 61.85)
	_exit_door.rotation.y = PI
	_place_door_casings()


func _make_door(door_name: String, advances: bool, back: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = door_name
	body.set_script(_DOOR_SCRIPT)
	body.advances_level = advances
	body.goes_back = back
	add_child(body)
	# ⭐ THROUGH `door.gd:build_visual()` SINCE 2026-09-03, and it should always have been.
	#
	# ⚠️ WHAT THIS REPLACED. A hand-rolled `BoxMesh(1.0, 2.2, 0.15)` at albedo (0.15,0.01,0.01)
	# with emission (0.35,0.02,0.02) at multiplier **1.5** — i.e. verbatim the UNTEXTURED branch
	# of `door_material()`, which `door.gd:26-40` documents as the "red brick" fallback it was
	# superseded by. This file has `preload`ed `door.gd` since the day it was written (see
	# `_DOOR_SCRIPT`) and simply never called its builder, so the Breach's two doors were flat
	# emissive slabs while every other level in the game had real leaves.
	#
	# ⚠️ It escaped `check_art_aspect.gd` for the same reason it looked wrong: a prop carrying NO
	# texture has no aspect to be stretched, so the one guard that sweeps all nine levels for
	# distorted artwork had nothing to say about it. `level_6_breach/` had no door texture at
	# all until `tools/make_breach_door.py`.
	#
	# ⚠️ 1.6 x 2.4, not 1.0 x 2.2: these are freight doors in a containment wing, and the
	# doorways around them are 1.8 m. `build_visual()` puts the art on a QuadMesh and the edge on
	# a box (Issue 24), and `door_material()`'s TEXTURED branch drops the emission multiplier to
	# 0.08 — at 1.5 a textured leaf renders salmon pink at this level's light levels (Issue 21).
	const DOOR_SIZE := Vector3(1.6, 2.4, 0.14)
	# ⚠️ MULTIPLY, matching the slam doors (2026-09-07). `door.gd`'s default is Godot's ADD, which
	# lays a flat red wash over the whole leaf; the slam doors tint the texture's own shape. Same
	# PNG, two different pictures. The RED stays — these are the only two doors in the level that
	# are actually a way out.
	_DOOR_SCRIPT.build_visual(body, DOOR_SIZE, DOOR_TEX, 1.0, true)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(DOOR_SIZE.x, DOOR_SIZE.y, DOOR_SIZE.z + 0.06)
	col.shape = shape
	body.add_child(col)
	_build_door_casing(body, DOOR_SIZE)
	return body


# ⭐ A CASING, so the leaf reads as a door in a wall rather than a picture ON one.
#
# ⚠️ `door.gd:build_visual()` gives you a leaf and nothing else — every level that wants the
# door to look SEATED builds its own architrave (`corridor.gd:_spawn_door_frame()`,
# `intro_room.gd:_build_door_casing()`, `slam_door.gd:_build_frame()`). The Breach never did, so
# even after the leaf became real artwork it rendered as a flat rectangle floating on flat
# concrete. Two jambs and a head is the whole fix.
#
# ⚠️ NO COLLIDERS. A collider on the only doorway wall is how this project seals a room by
# accident — `intro_room.gd` carries the same warning verbatim, and `check_doorways.gd` sweeps
# all nine levels for exactly that.
# ⚠️ SIBLINGS of the leaf, never children: `door.gd` frees or flashes the leaf, and a frame that
# went with it would leave a hole.
# Second half of `_build_door_casing()`: now that every door has its final position and yaw,
# move each casing piece into place. Split in two because `_spawn_level_doors()` sets the
# transform after `_make_door()` returns.
func _place_door_casings() -> void:
	for child in get_children():
		if not (child is MeshInstance3D) or not child.has_meta("casing_for"):
			continue
		var door := get_node_or_null(child.get_meta("casing_for")) as Node3D
		if door == null:
			continue
		child.global_transform = door.global_transform.translated_local(
			child.get_meta("casing_offset"))


# ⭐ ONE ARCHITRAVE FOR THE WHOLE LEVEL (2026-09-07, from *"make sure all the doors look the
# same"*). The Breach had THREE frame profiles and nine openings with none at all: the exit casing
# was jamb 0.10 / depth 0.13 / metallic 0.45, `slam_door.gd`'s frame is jamb 0.08 / depth 0.26 /
# metallic 0.3, and `purge_chamber.gd`'s is jamb 0.10 / depth 0.26 / metallic 0.6.
#
# ⚠️ THE BREACH-LOCAL GEOMETRY MOVES TO MATCH THE SLAM DOORS, NEVER THE REVERSE.
# `slam_door.gd`'s `JAMB_T`, `FRAME_D` and `LEAF_H` are `const` and shared with THE NIGHTMARE's
# 27 doors / 54 leaves; changing them there would re-dress a level nobody asked about.
const FRAME_TINT := Color(0.07, 0.07, 0.07)   # slam_door.gd's frame material
const FRAME_METALLIC := 0.3
const FRAME_ROUGH := 0.6
const FRAME_JAMB := 0.08                       # slam_door.gd:JAMB_T
const FRAME_DEPTH := 0.26                      # slam_door.gd:FRAME_D
# ⚠️ DEPTH MUST EXCEED `RoomBuilder.T` (0.2) OR THE CASING IS BURIED. A 0.13-deep casing centred
# on the doorway plane spans -0.065..+0.065 inside a wall that spans -0.1..+0.1 — invisible from
# both faces. That is the same fault `purge_chamber.gd` records for its own jambs.


static func _frame_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = FRAME_TINT
	m.metallic = FRAME_METALLIC
	m.roughness = FRAME_ROUGH
	return m


func _build_door_casing(body: Node3D, size: Vector3) -> void:
	var mat := _frame_material()
	const T := FRAME_JAMB
	const D := FRAME_DEPTH
	var parent := body.get_parent()
	if parent == null:
		return
	for spec in [
			{"n": "CasingL", "s": Vector3(T, size.y + T * 2.0, D),
				"p": Vector3(-(size.x * 0.5 + T * 0.5), 0.0, 0.0)},
			{"n": "CasingR", "s": Vector3(T, size.y + T * 2.0, D),
				"p": Vector3(size.x * 0.5 + T * 0.5, 0.0, 0.0)},
			{"n": "CasingHead", "s": Vector3(size.x + T * 2.0, T, D),
				"p": Vector3(0.0, size.y * 0.5 + T * 0.5, 0.0)}]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec["s"]
		mi.mesh = bm
		mi.name = "%s_%s" % [body.name, spec["n"]]
		mi.set_surface_override_material(0, mat)
		parent.add_child(mi)
		# ⚠️ Positioned in the DOOR's frame and then baked to world, because the caller sets
		# `body.position` and `body.rotation.y` AFTER `_make_door()` returns — a casing parented
		# to the level and positioned from `body.global_position` here would sit at the origin.
		mi.set_meta("casing_offset", spec["p"])
		mi.set_meta("casing_for", body.get_path())


# ⭐ THE NINE BARE OPENINGS GET THE SAME CASING (2026-09-07, the user's call).
#
# `RoomBuilder` cuts a doorway as a rectangular hole floor-to-ceiling with no lintel, no jamb and
# no threshold, showing the wall's own skin on the cut edges. Fourteen of this level's openings
# carry a door (4 slam + 1 purge) or are a wall prop; the other NINE were raw holes standing
# beside seven framed doors — arguably the level's biggest visual inconsistency, and the reason
# "all the doors look the same" could not be answered by touching only the doors.
#
# ⚠️ BUILT HERE, NOT IN `RoomBuilder`. That class is shared by the Lab, the House, KONTUR, the
# Breach and THE NIGHTMARE; framing doorways there would re-dress five levels.
# ⚠️ NO COLLIDERS. A collider on the only doorway wall is how this project seals a room by
# accident — `check_doorways.gd` exists because of exactly that.
func _frame_bare_openings() -> void:
	var taken := {}
	for d in _slam_doors:
		if is_instance_valid(d):
			taken[Vector2(snappedf((d as Node3D).global_position.x, 0.1),
				snappedf((d as Node3D).global_position.z, 0.1))] = true
	if _purge_chamber:
		taken[Vector2(snappedf(_purge_chamber.global_position.x, 0.1),
			snappedf(_purge_chamber.global_position.z, 0.1))] = true

	var mat := _frame_material()
	var h: float = RoomBuilder.DEFAULT_H
	for entry in DOORS:
		var p: Vector2 = entry["pos"]
		if taken.has(Vector2(snappedf(p.x, 0.1), snappedf(p.y, 0.1))):
			continue
		var w: float = float(entry["width"])
		var holder := Node3D.new()
		holder.name = "Casing_%.0f_%.0f" % [p.x, p.y]
		holder.position = Vector3(p.x, 0.0, p.y)
		# "z" means the doorway is cut in a wall perpendicular to z, so its width runs along x.
		holder.rotation.y = 0.0 if String(entry["dir"]) == "z" else PI / 2.0
		add_child(holder)
		for spec in [
				{"s": Vector3(FRAME_JAMB, h, FRAME_DEPTH),
					"p": Vector3(-(w * 0.5 + FRAME_JAMB * 0.5), h * 0.5, 0.0)},
				{"s": Vector3(FRAME_JAMB, h, FRAME_DEPTH),
					"p": Vector3(w * 0.5 + FRAME_JAMB * 0.5, h * 0.5, 0.0)},
				# The head sits just under the ceiling — the opening is full height, so there is
				# no lintel to imitate, only the top edge to finish.
				{"s": Vector3(w + FRAME_JAMB * 2.0, 0.1, FRAME_DEPTH),
					"p": Vector3(0.0, h - 0.05, 0.0)}]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = spec["s"]
			mi.mesh = bm
			mi.position = spec["p"]
			mi.set_surface_override_material(0, mat)
			holder.add_child(mi)


func _refresh_exit() -> void:
	if not is_instance_valid(_exit_door):
		return
	_exit_door.extra_lock = not _creature_defeated
	_exit_door.locked_message = "SEAL WILL NOT LIFT — THE SUBJECT IS STILL LOOSE"


func _play_at(base_name: String, pos: Vector3, volume_db: float = 0.0) -> void:
	var stream := GameState.load_audio(base_name)
	if not stream:
		return
	var pl := AudioStreamPlayer3D.new()
	pl.stream = stream
	pl.volume_db = volume_db
	pl.unit_size = 8.0
	pl.max_db = 6.0
	add_child(pl)
	pl.position = pos
	pl.finished.connect(pl.queue_free)
	pl.play()


# ---------------------------------------------------------------- ambience

func _boost_ambient(energy: float) -> void:
	var we: WorldEnvironment = get_node_or_null("Environment/WorldEnvironment")
	if not we or not we.environment:
		return
	var env: Environment = we.environment.duplicate()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = energy
	env.ambient_light_color = Color(0.09, 0.08, 0.08)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	we.environment = env


func _start_ambience() -> void:
	var ambient: AudioStreamPlayer = get_node_or_null("AmbientPlayer")
	if not ambient:
		return
	var s := GameState.load_audio("ambient_breach")
	if not s:
		s = GameState.load_audio("ambient_kontur")   # fallback until the Breach bed exists
	if s:
		ambient.stream = s
		ambient.volume_db = -8.0
		ambient.finished.connect(ambient.play)
		ambient.play()
	# Secondary layer — the user-provided mystical_sound.mp3, mirroring kontur.gd's
	# optional kontur_music node. Never the primary bed: an arbitrary sourced .mp3
	# isn't guaranteed loop-clean, so the primary bed stays the procedural one.
	var layer := GameState.load_audio("ambient_breach_layer")
	if layer:
		var mp := AudioStreamPlayer.new()
		mp.stream = layer
		mp.volume_db = -14.0
		add_child(mp)
		mp.finished.connect(mp.play)
		mp.play()


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	_tick_familiarization(delta)
	_tick_slam_doors()
	_tick_light_weapon(delta)
	_tick_noise()
