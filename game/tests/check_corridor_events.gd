extends SceneTree

# The Corridor's two scripted PROP events, driven through their real code paths.
#
#   Godot --headless --path game --script res://tests/check_corridor_events.gd
#
# Both exist because of the 2026-08-17 playtest, and both are things a smoke test, a
# screenshot and every geometry sweep in the project are structurally blind to:
#
#   A. THE RUNNING SILHOUETTE (`_ev_silhouette`). The user: *"it is too far away from me. Can
#      we make it run when I'm much closer so that I can actually see it."* "Can I see it" is
#      an APPARENT SIZE question, and nothing in this project had ever measured one. So this
#      unprojects the real figure through the real player camera and reports the number — with
#      a control that rebuilds the OLD placement and requires it to measure small, because a
#      threshold nothing has ever failed is not a threshold.
#
#   C. THE ENTRANCE NOTE'S FACING (2026-08-18). A page lying flat has a right way up, and it
#      shipped 180° out — the first document in the level, upside down to the only person who
#      can read it. Nothing measured it: the two guards that look at wall props ask "is there
#      something behind this" and "is the artwork stretched", and a page rotated about its own
#      normal answers both correctly.
#
#   D. THE FALSE DOOR'S PAYLOAD (2026-08-18). Which sting it plays, and how bright the picture
#      is. Both are asserted against something the game already declares — `Screamer`'s own
#      shared/fatal table, and this level's own fatal screamer image — rather than against a
#      constant typed in here.
#
#   B. THE FALSE ROOM 217 (`FalseExitDoor`). A brand-new interactable that swings a COLLIDER
#      into a 3 m corridor at a corner the player must turn. This project has shipped that
#      exact defect three times in one week (Issues 65, 67, 76). It is also a one-shot, and a
#      one-shot that re-arms or that keeps offering a prompt after it has fired is invisible
#      until someone presses E twice.
#
# ⚠️ THE WIN PATH IS NEVER SHORT-CIRCUITED. `opened` is never emitted by this test; the door is
# opened by driving `player.ai_interact()` so the real raycast, `can_interact()` and prompt
# path all run (the project's standing rule, learned from a test that drove `cleared.emit()`
# and passed for weeks on an uncompletable level).

const SCENE := "res://scenes/corridor.tscn"
const W := 3.0
const MIN_FREE_WIDTH := 1.2      # a player capsule is ~0.8 m across
const MIN_APPARENT := 0.10       # the runner must stand >= 10 % of the screen's height
const OLD_APPARENT_MAX := 0.06   # ...and the placement it replaced must measure under 6 %

var _t := 0.0
var _stage := 0
var _fails: Array[String] = []
var _checks := 0
var _scene: Node = null
var _player: CharacterBody3D = null
var _door: Node3D = null
var _panic_before := 0.0
var _panic_gain := 0.0
var _spawn_xf := Transform3D.IDENTITY


func _initialize() -> void:
	change_scene_to_file(SCENE)


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


# ---------------------------------------------------------------- helpers

func _cam() -> Camera3D:
	return _player.get_node_or_null("Camera3D") as Camera3D


# Point the player at a world position (yaw only — the camera child carries pitch).
func _face(from: Vector3, target: Vector3) -> void:
	var d := target - from
	d.y = 0.0
	d = d.normalized()
	_player.global_position = from
	_player.rotation.y = atan2(-d.x, -d.z)


# The fraction of the VIEWPORT'S HEIGHT a node's world-space bounds occupy, measured by
# unprojecting the eight corners of its aggregate AABB through the live camera. Resolution
# independent on purpose: headless runs at the project's default size and a pixel count would
# mean something different on the user's machine.
func _apparent_height(root: Node3D) -> float:
	var cam := _cam()
	if cam == null:
		return 0.0
	var pts: Array[Vector3] = []
	for n in _descendants(root):
		if not (n is VisualInstance3D):
			continue
		var aabb: AABB = (n as VisualInstance3D).get_aabb()
		for c in 8:
			pts.append((n as Node3D).global_transform * aabb.get_endpoint(c))
	if pts.is_empty():
		return 0.0
	var lo := INF
	var hi := -INF
	for p in pts:
		# ⚠️ Anything behind the eye unprojects to nonsense; drop it rather than clamp it.
		if cam.is_position_behind(p):
			continue
		var s := cam.unproject_position(p)
		lo = minf(lo, s.y)
		hi = maxf(hi, s.y)
	if not is_finite(lo) or not is_finite(hi):
		return 0.0
	return (hi - lo) / float(cam.get_viewport().get_visible_rect().size.y)


func _descendants(n: Node, out: Array[Node] = []) -> Array[Node]:
	out.append(n)
	for c in n.get_children():
		_descendants(c, out)
	return out


func _find(root: Node, prefix: String) -> Node:
	for n in _descendants(root):
		if String(n.name).begins_with(prefix):
			return n
	return null


# The widest contiguous run of empty floor across a corridor line, measured with POINT
# QUERIES. ⚠️ Never `intersect_shape`: a capsule wholly inside a CSG slab comes back CLEAR
# (Issue 40), which is exactly the case being tested for.
func _free_width(centre: Vector3, lateral: Vector3, y: float) -> float:
	var space := _player.get_world_3d().direct_space_state
	var step := 0.05
	var best := 0.0
	var run := 0.0
	var i := -int(W / 2.0 / step)
	while i <= int(W / 2.0 / step):
		var p: Vector3 = centre + lateral * (i * step) + Vector3(0, y, 0)
		var q := PhysicsPointQueryParameters3D.new()
		q.position = p
		q.collide_with_areas = false
		q.collide_with_bodies = true
		# ⚠️ EXCLUDE THE PLAYER. They are standing 2.4 m from the door because this test just
		# walked them there to press E, and their own capsule chopped the free run from 2.20 m
		# to 1.15 m — a failure that looked exactly like the door sealing the corner.
		q.exclude = [_player.get_rid()]
		if space.intersect_point(q, 4).is_empty():
			run += step
			best = maxf(best, run)
		else:
			run = 0.0
		i += 1
	return best


# ---------------------------------------------------------------- the run

func _process(delta: float) -> bool:
	_t += delta
	match _stage:
		0:
			if _t < 1.0:
				return false
			_scene = current_scene
			_player = _scene.get_node_or_null("Player") as CharacterBody3D
			_ok("the player exists", _player != null)
			_ok("the camera exists", _cam() != null)
			if _player == null or _cam() == null:
				return _report()
			# ⚠️ SAMPLED BEFORE ANYTHING MOVES THE PLAYER. `_silhouette()` teleports them 219 m
			# down the level, so the spawn pose has to be captured on the frame the scene is
			# handed over — this is the only reference the note-facing check has that is not
			# the same table the level built the note from.
			_spawn_xf = _player.global_transform
			_silhouette()
			_false_door_static()
			_false_door_payload()
			_entrance_note()
			_stage = 1
			_t = 0.0
		1:
			# ⚠️ POSITION AND PRESS E ARE TWO FRAMES APART, deliberately. `_interact_target` is
			# recomputed in the player's own `_process` from a raycast, so asking for it in the
			# same frame the player was teleported reads the target from where they USED to be
			# — which is null, and which would have made this look like a broken door.
			if _t < 0.2:
				return false
			_false_door_place()
			_stage = 2
			_t = 0.0
		2:
			if _t < 0.4:
				return false
			_false_door_open()
			_stage = 3
			_t = 0.0
		3:
			# 2026-09-10: the beat is IN THE WORLD now. Watch it every frame — the panic lands at
			# the lunge (FALSE_DOOR_LUNGE_AT), not at E; the figure must come to the face and
			# then leave; the camera is pinned and then released; and NO fullscreen panel may
			# ever show. The scrawl lands at FALSE_DOOR_SCRAWL_DELAY 1.6 and lives 3.6 s.
			_false_door_watch(delta)
			if _t < 2.8:
				return false
			_false_door_after()
			_stage = 4
			_t = 0.0
		4:
			# ⚠️ A PHYSICS FRAME, not a process frame. `intersect_point` reads the physics
			# server's state, so a body added and positioned in the previous call is simply not
			# there yet — the first version of this control reported 3.05 m of free floor with
			# a 2.4 m block standing in it.
			if _t < 0.4:
				return false
			_ok("the figure is GONE once it has fled (freed, not parked)",
				_find(_scene, "DoorLunger") == null)
			_free_width_control()
			_c1_spacing()
			_c1_shut_in_start()
			_stage = 5
			_t = 0.0
		5:
			# The shut-in: sprung at t=0; the door must be closed and battering for ~10 s, the
			# torch dead, and open again after SPUR_SHUT_TIME.
			if _t > 0.4 and not _shut_checked:
				_shut_checked = true
				_ok("C1: the spur door is CLOSED behind the player", bool(_spur_door.get("_closed")))
				_ok("C1: ...and battering (E cannot reopen it)", bool(_spur_door.get("_battering")))
				_ok("C1: the spur's torch died", not bool(_spur_torch.get("lit")))
				_ok("C1: a scrape rides under it", _scene.get_node_or_null("Spur0Scrape") != null)
				_ok("C1: the shut-in costs zero panic (nothing ADDED; decay is free to run)",
					_player.get_panic_ratio() <= _panic_before_shut + 0.005,
					"%.3f -> %.3f" % [_panic_before_shut, _player.get_panic_ratio()])
			# 2026-09-13: the way out is the Space-mash escape. Drive it through the shipping
			# SpurEscape.press(): bar 1, bar 2 (the shadow crosses under the door), bar 3 forces it.
			if _t > 1.0 and not _mash_done:
				_mash_done = true
				var esc: Node = _scene.get_node_or_null("Spur0Escape")
				_ok("C1: a SpurEscape is live behind the shut door", esc != null and bool(esc.call("is_active")))
				_ok("C1: the fallback clock is SPUR_SHUT_TIME and it is >= 20 s",
					float(_spur_door.get("batter_time")) == float(_cs().get("SPUR_SHUT_TIME")) and float(_cs().get("SPUR_SHUT_TIME")) >= 20.0)
				if esc:
					# Press until the second bar lands (the bar had a second of decay first).
					var guard := 0
					while int(esc.call("bars")) < 2 and guard < 40:
						esc.call("press")
						guard += 1
					_ok("C1: two bars in, the door is still shut", bool(_spur_door.get("_closed")) and int(esc.call("bars")) == 2,
						"%d presses, %d bars" % [guard, int(esc.call("bars"))])
					_ok("C1: the second bar sent a SHADOW across the light under the door (note spur)",
						_scene.get_node_or_null("Spur0Shadow") != null)
					guard = 0
					while bool(esc.call("is_active")) and guard < 20:
						esc.call("press")
						guard += 1
					_ok("C1: the third bar FORCES the door", not bool(_spur_door.get("_closed")))
					_ok("C1: ...and the escape UI is gone", not bool(esc.call("is_active")))
					_ok("C1: ...and the shut-in still cost zero panic", _player.get_panic_ratio() <= _panic_before_shut + 0.005)
			if _mash_done and _t > 1.6:
				_ok("C1: ...and the scrape stops", _scene.get_node_or_null("Spur0Scrape") == null)
				_c2_bell_start()
				_stage = 50
				_t = 0.0
		50:
			# C4 (2026-09-15, the user's design): ring → the lights die for BLACKOUT_S → they come
			# back and the 217 key is beside the bell → E takes it → it is what opens door 217.
			# The mouth door NEVER closes. Zero panic throughout.
			var beat: Node = _scene.get_node_or_null("Spur1BellBeat")
			var lamp := _scene.get_node_or_null("Spur1DeskLamp") as OmniLight3D
			# ⚠️ Never name `SpurBell` here: a SceneTree script compiles before the autoloads exist,
			# so a class it depends on that mentions `GameState` fails to compile with it.
			var bcs: Dictionary = (beat.get_script() as GDScript).get_script_constant_map() if beat != null else {}
			var after: float = float(bcs.get("BLACKOUT_AFTER", 1.2))
			var dark: float = float(bcs.get("BLACKOUT_S", 4.5))
			if _t > 0.3 and not _bell_rung:
				_bell_rung = true
				_ok("C4: ringing the bell does NOT shut the door behind you", not bool((_bell_door as Node).get("_closed")))
				_ok("C4: ...and no key yet", _scene.get_node_or_null("Spur1Key") == null)
				_panic_before_bell = _player.get_panic_ratio()
			if _t > after + 0.5 and not _bell_turned:
				_bell_turned = true
				_ok("C4: %.1f s after the ding the lights are OUT" % after, beat != null and bool(beat.call("is_dark")))
				_ok("C4: ...the desk lamp is dead", lamp != null and lamp.light_energy < 0.05, "%.2f" % (lamp.light_energy if lamp else -1.0))
				_ok("C4: ...your own torch is taken", not bool(_player.call("is_flashlight_on")) and bool(_player.get("_flashlight_locked")))
				_ok("C4: ...something is walking up the spur in the dark", beat != null and beat.get_node_or_null("BellSteps") != null)
				_ok("C4: ...and still no key", _scene.get_node_or_null("Spur1Key") == null)
			if _t > after + dark + 0.6:
				var key := _scene.get_node_or_null("Spur1Key")
				_ok("C4: the lights come back", beat != null and bool(beat.call("is_done")) and not bool(beat.call("is_dark"))
					and lamp != null and lamp.light_energy > 0.5 and bool(_player.call("is_flashlight_on")))
				_ok("C4: ...and the 217 key is lying beside the bell", key != null
					and (key as Node3D).global_position.distance_to((_scene.get_node("Spur1Bell") as Node3D).global_position) < 0.4)
				_ok("C4: ...the walker is gone", beat != null and beat.get_node_or_null("BellSteps") == null)
				_ok("C4: ...the door STILL never closed", not bool((_bell_door as Node).get("_closed")))
				if key != null:
					(key as Node).call("interact")
					_ok("C4: E takes the key and you carry it", bool(beat.call("has_key")) and String(root.get_node("/root/GameState").get("carried_item")).contains("217"))
					_ok("C4: ...which unlocks door 217", _door != null and bool(_door.call("has_key")))
				_ok("C4: ...and all of it cost nothing", _player.get_panic_ratio() <= _panic_before_bell + 0.005)
				_c3_cupboard_start()
				_stage = 51
				_t = 0.0
		51:
			var cb: Node = _scene.get_node_or_null("Spur2CupboardBeat")
			if _t > 0.5 and not _cup_checked:
				_cup_checked = true
				_ok("C3: stepping into the cupboard seals it", cb != null and bool(cb.call("is_sealed")))
				_ok("C7: ...the door has slammed shut behind you", not bool(_scene.get_node("Spur2ClosetDoor").call("is_ajar")))
				_ok("C3: ...and the Manager is walking the spur", _scene.get_node_or_null("CupboardFigure") != null)
				# C3 (2026-09-15): the seal TAKES the torch and SAYS the rule — the user sat in here
				# with the torch on for 88 s: "how do I get away from here?"
				_ok("C3: the seal takes your torch (F is locked)", not bool(_player.call("is_flashlight_on")) and bool(_player.get("_flashlight_locked")))
				var said := false
				for n in _descendants(root):
					if n is Label and String((n as Label).text).contains("MOVE"):
						said = true
				_ok("C3: ...and the scrawl says DON'T MOVE", said)
			# A breach at t 1.5-2.5: the slats stop a walk headless and F is locked, so the torch is
			# lit on the raw node — the state the beat READS — to exercise the pause + clock reset.
			if _t > 1.5 and _t < 2.5 and not _cup_torch_on:
				_cup_torch_on = true
				(_player.get("flashlight") as Node3D).visible = true
			elif _t >= 2.5 and not _cup_move_checked:
				_cup_move_checked = true
				var fig := _scene.get_node_or_null("CupboardFigure")
				_ok("C3: a lit torch stops it outside the slats", fig != null and not bool(fig.call("is_walking")))
				_ok("C3: ...and resets the stillness clock", float(cb.call("still_time")) < 1.0, "%.2f" % float(cb.call("still_time")))
				(_player.get("flashlight") as Node3D).visible = false
			if _t > 12.5:
				_ok("C3: holding still (torch off) for HOLD_S releases you", bool(cb.call("is_released")), "%.1f s still" % float(cb.call("still_time")))
				_ok("C3: ...and gives the torch back", not bool(_player.get("_flashlight_locked")))
				_ok("C7: ...and the door is open again", bool(_scene.get_node("Spur2ClosetDoor").call("is_ajar")))
				_ok("C3: ...for free", _player.get_panic_ratio() <= _panic_before_cup + 0.005, "%.3f -> %.3f" % [_panic_before_cup, _player.get_panic_ratio()])
				_c1_manager_start()
				_stage = 6
				_t = 0.0
		6:
			var fig := _find(_scene, "ManagerFigure") as Node3D
			_mgr_panic_max = maxf(_mgr_panic_max, _player.get_panic_ratio())
			if fig:
				_mgr_seen = true
				var cam := _cam()
				_mgr_nearest = minf(_mgr_nearest, Vector2(fig.global_position.x - cam.global_position.x, fig.global_position.z - cam.global_position.z).length())
				if cam.is_position_in_frustum(fig.global_position + Vector3(0, 1.0, 0)):
					_mgr_in_frame = true
			if _t > 4.5:
				_ok("C1: the Manager is a figure IN THE WORLD", _mgr_seen)
				_ok("C1: ...on screen", _mgr_in_frame)
				_ok("C1: ...that came to arm's length", _mgr_nearest <= 1.0, "%.2f m" % _mgr_nearest)
				_ok("C1: ...costing MANAGER_PANIC (peak over the beat)", _mgr_panic_max - _panic_before_mgr >= float(_cs().get("MANAGER_PANIC")) / 50.0 - 0.02,
					"peak %.2f from %.2f" % [_mgr_panic_max, _panic_before_mgr])
				_ok("C1: ...and gone afterwards", _find(_scene, "ManagerFigure") == null)
				_ok("C1: ...with NO fullscreen flash", not _mgr_flash)
				return _report()
			var scr := root.get_node_or_null("Screamer")
			if scr and scr.get("_black_panel") != null and (scr.get("_black_panel") as CanvasItem).visible:
				_mgr_flash = true
	return false


# ---- A. THE RUNNING SILHOUETTE ------------------------------------------------------------

func _silhouette() -> void:
	var cs: GDScript = _scene.get_script()
	var trig: float = float(cs.get("SILHOUETTE_TRIGGER"))
	var cross: float = float(cs.get("SILHOUETTE_CROSS"))
	var side_off: float = float(cs.get("SILHOUETTE_SIDE"))
	var db: float = float(cs.get("SILHOUETTE_DB"))
	var max_db: float = float(cs.get("SILHOUETTE_MAX_DB"))

	# ⚠️ The one number that must NOT have moved. The brief was explicit: the beat gets closer
	# and louder, and the panic it costs is the user's call and was not compounded.
	_ok("SILHOUETTE_PANIC is still 20", is_equal_approx(float(cs.get("SILHOUETTE_PANIC")), 20.0),
		"%.1f" % float(cs.get("SILHOUETTE_PANIC")))
	_ok("the figure runs across AHEAD of the trigger, not behind it", cross > trig,
		"trigger %.0f m, crossing %.0f m -> %.1f m ahead" % [trig, cross, cross - trig])
	# ⚠️ The start and end must be BEHIND the walls. The corridor's inner faces are at W/2 and
	# the slabs are 0.3 m thick, so anything past 1.5 is out of sight and past 1.8 is outside
	# the building. At 8 m the old ±1.2 (inside the hall) would have the figure blinking into
	# existence in mid-air.
	_ok("it enters and leaves from BEHIND the walls", side_off > W / 2.0 + 0.3,
		"±%.2f m against a wall face at %.2f m" % [side_off, W / 2.0])

	# Stand the player at the trigger, facing along the corridor, and fire the REAL event.
	var here := _scene.call("_path_point", trig) as Dictionary
	var there := _scene.call("_path_point", cross) as Dictionary
	_face(here.pos as Vector3, there.pos as Vector3)
	_panic_before = _player.get_panic_ratio()
	_scene.call("_ev_silhouette")

	var fig := _find(_scene, "SilhouetteRunner") as Node3D
	_ok("the figure was spawned", fig != null)
	if fig == null:
		return

	# ---- IS IT A FIGURE, or a pill? Issue 35: bringing a capsule closer makes it a bigger
	# capsule. Parts, and dark parts — this thing must OCCLUDE the lit wall, not glow.
	var meshes: Array[Node] = []
	for n in _descendants(fig):
		if n is MeshInstance3D:
			meshes.append(n)
	_ok("it is built from PARTS, not one capsule", meshes.size() >= 6,
		"%d meshes" % meshes.size())
	var brightest := 0.0
	var worst_emission := 0.0
	for m in meshes:
		var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
		if mat == null:
			continue
		var a: Color = mat.albedo_color
		brightest = maxf(brightest, (a.r + a.g + a.b) / 3.0)
		if mat.emission_enabled:
			worst_emission = maxf(worst_emission, mat.emission_energy_multiplier)
	_ok("it is a dark silhouette, not a lit prop", brightest < 0.08 and worst_emission <= 0.5,
		"albedo %.3f, emission x%.2f" % [brightest, worst_emission])

	# ---- APPARENT SIZE, the actual complaint.
	var now := _apparent_height(fig)
	_ok("the figure is big enough on screen to read as a figure", now >= MIN_APPARENT,
		"%.1f %% of the screen's height at %.1f m"
			% [now * 100.0, (fig.global_position - _player.global_position).length()])

	# ---- THE CONTROL, and it is what makes the number above mean anything: rebuild the OLD
	# placement — a 1.75 m capsule at d=228.5 seen from d=205 — and require it to be small.
	var old_fig := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 1.75
	old_fig.mesh = cap
	_scene.add_child(old_fig)
	var old_here := _scene.call("_path_point", 205.0) as Dictionary
	var old_there := _scene.call("_path_point", 228.5) as Dictionary
	old_fig.global_position = (old_there.pos as Vector3) + Vector3(0, 0.9, 0)
	var keep := _player.global_transform
	_face(old_here.pos as Vector3, old_there.pos as Vector3)
	var before := _apparent_height(old_fig)
	_ok("CONTROL: the placement this replaced measures SMALL", before <= OLD_APPARENT_MAX,
		"%.1f %% at 23.5 m -> the new one is %.1fx larger" % [before * 100.0, now / maxf(before, 1e-6)])
	old_fig.queue_free()
	_player.global_transform = keep

	# ---- THE SOUND RIDES THE FIGURE. `_play_at` parents to the level; this one must not.
	var emitter: AudioStreamPlayer3D = null
	for n in _descendants(fig):
		if n is AudioStreamPlayer3D:
			emitter = n
	_ok("the scream is a CHILD of the runner, so it travels with it", emitter != null)
	if emitter != null:
		_ok("...and it is the right sample", emitter.stream != null
			and emitter.stream.resource_path.get_file().get_basename() == "jumpscare",
			emitter.stream.resource_path if emitter.stream else "null")
		_ok("...at the gain the constant declares", is_equal_approx(emitter.volume_db, db),
			"%.1f dB" % emitter.volume_db)
		# ⚠️ `shared/jumpscare.wav` peaks at 0.0 dBFS, so the default max_db 6.0 would let a
		# SPRINTING player who closes to 4 m add another 6 dB and clip the master.
		_ok("...with max_db pinned so a close pass cannot clip",
			is_equal_approx(emitter.max_db, max_db), "%.1f dB" % emitter.max_db)

	_ok("the event still costs exactly SILHOUETTE_PANIC",
		is_equal_approx((_player.get_panic_ratio() - _panic_before) * 50.0,
			float(cs.get("SILHOUETTE_PANIC"))),
		"+%.1f" % ((_player.get_panic_ratio() - _panic_before) * 50.0))
	_player.set("_panic", 0.0)


# ---- B. THE FALSE ROOM 217 ----------------------------------------------------------------

# ---- C1 ------------------------------------------------------------------------------------
var _spur_door: Node = null
var _mash_done := false
var _spur_torch: Node = null
var _shut_checked := false
var _panic_before_shut := 0.0
var _panic_before_mgr := 0.0
var _mgr_seen := false
var _mgr_in_frame := false
var _mgr_nearest := 999.0
var _mgr_flash := false
var _mgr_panic_max := 0.0


func _cs() -> Dictionary:
	return (_scene.get_script() as GDScript).get_script_constant_map()


# The three big one-shots and the two mirrors, pairwise >= 50 m apart (the user: "all the
# jumpscares will be in different parts of the level"). The Manager's two telegraphs are ONE
# beat (one of them pays off), so the nearest of the two counts.
func _c1_spacing() -> void:
	var cs := _cs()
	var beats := {
		"false door": float(cs["FALSE_DOOR_DIST"]),
		"manager (nearest telegraph)": float((cs["TELEGRAPH_AT"] as Array).min()),
		"running creature": float(cs["SILHOUETTE_TRIGGER"]),
		"mirror 1": float((cs["TURN_MIRRORS"] as Array)[0][0]),
		"mirror 2": float((cs["TURN_MIRRORS"] as Array)[1][0]),
	}
	var names := beats.keys()
	var worst := INF
	var pair := ""
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			var d := absf(float(beats[names[i]]) - float(beats[names[j]]))
			if d < worst:
				worst = d
				pair = "%s vs %s" % [names[i], names[j]]
	_ok("C1: every big beat is >= 50 m from every other", worst >= 50.0, "nearest pair %s at %.0f m" % [pair, worst])
	_ok("C1: the corridor is ~455 m with three side passages", (cs["SIDE_PASSAGES"] as Array).size() == 3
		and absf(float(_scene.get("_total_len")) - 455.0) < 0.01)
	_ok("C1: the last mirror is at the last corner (410)", is_equal_approx(float((cs["TURN_MIRRORS"] as Array)[1][0]), 410.0))
	var spurs: Array = _scene.call("spurs")
	_ok("C1: three spurs were built, each with a door and a torch (only the note spur has a trap)", spurs.size() == 3
		and spurs.all(func(e): return is_instance_valid(e["door"]) and is_instance_valid(e["torch"]))
		and is_instance_valid((spurs[0] as Dictionary)["trap"]))
	# C4 (2026-09-15): the bell spur moved to 208 and lost the whisper — it is silent until rung.
	_ok("C4: no spur whispers any more (the bell nook is silent until rung)", _scene.get_node_or_null("Spur1Plea") == null)
	_ok("C4: the bell spur sits BEFORE door 217 (the key is served first, no backtracking)",
		float(((cs["SIDE_PASSAGES"] as Array)[1] as Dictionary)["at"]) < float(cs["FALSE_DOOR_DIST"]))
	# 2026-09-13: three DIFFERENT spurs (the user: "they need to present something different").
	var kinds: Array = []
	for e in spurs:
		kinds.append(String(e["kind"]))
	_ok("C1: the three spurs are three different kinds", kinds.size() == 3 and kinds[0] != kinds[1] and kinds[1] != kinds[2] and kinds[0] != kinds[2], str(kinds))
	_ok("C1: the note spur carries a readable page on its end wall", _scene.get_node_or_null("Spur0Note") != null
		and (_scene.get_node("Spur0Note") as Node).has_method("interact") and _scene.get_node("Spur0Note").get_node_or_null("NotePage") != null)
	# 2026-09-14 (C2/C3): the bell nook and the cupboard replace the plea and mirror spurs.
	_ok("C2: the bell spur has a desk and a bell that answers E", _scene.get_node_or_null("Spur1Desk") != null
		and _scene.get_node_or_null("Spur1Bell") != null and _scene.get_node("Spur1Bell").has_method("interact")
		and String(_scene.get_node("Spur1Bell").call("prompt_text")).contains("ring"))
	_ok("C2: ...and no trap volume (the bell springs it, not arriving)", _scene.get_node_or_null("Spur1Trap") == null)
	# C7 (2026-09-16): a service CLOSET behind a real door (the slats and the mirror are gone —
	# the mirror read as a window onto another room).
	_ok("C7: the cupboard spur ends in a closet behind a real hotel door", _scene.get_node_or_null("Spur2Cupboard") != null
		and _scene.get_node_or_null("Spur2ClosetDoor") != null and bool(_scene.get_node("Spur2ClosetDoor").call("is_ajar"))
		and _scene.get_node_or_null("Spur2ClosetStrip") != null)
	_ok("C7: ...and no mirror in it any more", _scene.get_node_or_null("Spur2CupboardMirror") == null)
	_ok("C3: ...and no trap volume either", _scene.get_node_or_null("Spur2Trap") == null)
	_ok("C1: only the note spur keeps the Space-mash", (spurs[0] as Dictionary)["kind"] == "note")
	# C4 (2026-09-14): two corner branches, a footprint trail into each, a loop-back and a blind room.
	var branches: Array = _scene.call("corner_branches")
	_ok("C4: two corner branches were built", branches.size() == 2)
	var prints := 0
	for n in _scene.get_children():
		if String(n.name).begins_with("Footprint"):
			prints += 1
	_ok("C4: the wet trail exists (>= 30 prints across both corners)", prints >= 30, "%d" % prints)
	if branches.size() == 2:
		_ok("C4: 320 loops back, 365 is the blind room", String((branches[0] as Dictionary)["kind"]) == "loop"
			and String((branches[1] as Dictionary)["kind"]) == "blind" and (branches[1] as Dictionary)["room"] != null)
		_ok("C4: the blind room has its lever, map and gate", _scene.get_node_or_null("Blind1Lever") != null
			and _scene.get_node_or_null("Blind1Map") != null and _scene.get_node_or_null("Blind1Gate") != null)
		for b in branches:
			var bd: Dictionary = b
			var clear2 := true
			for name in beats:
				if absf(float(beats[name]) - float(bd["corner"])) < 8.0:
					clear2 = false
			_ok("C4: branch at %.0f is >= 8 m from every big beat" % float(bd["corner"]), clear2)
	# C5: the seventh ajar door, on the note spur's side. It swings ajar AS YOU APPROACH (so it
	# sits flush for check_prop_mounting at load) with a figure in its gap, and is shut once
	# you are past. Drive the tick with the player placed, then put them back.
	var bdoor := _scene.get_node_or_null("AjarDoor_break")
	_ok("C5: the rhythm-break door exists", bdoor != null)
	if bdoor != null:
		_ok("C5: ...flush at load (it swings on the approach)", not bool(bdoor.call("is_ajar")))
		var keep: Vector3 = _player.global_position
		var bat: float = float(_scene.get("BREAK_DOOR_AT"))
		_player.global_position = (_scene.call("_path_point", bat - 6.0) as Dictionary)["pos"] + Vector3(0, 0.1, 0)
		_scene.call("_tick_break_door")
		_ok("C5: approaching it swings it ajar", bool(bdoor.call("is_ajar")))
		# C6 (2026-09-16): a DOUBLE door onto a real room — the second leaf opens with it, and a
		# ray through the doorway travels into the bedroom instead of hitting wallpaper.
		var bdoor2 := _scene.get_node_or_null("AjarDoor_break2")
		_ok("C6: the second leaf exists and opens with the first", bdoor2 != null and bool(bdoor2.call("is_ajar")))
		var pt0: Dictionary = _scene.call("_path_point", bat)
		var side_v: Vector3 = (pt0["side"] as Vector3) * float(_scene.get("BREAK_DOOR_SIDE"))
		var from: Vector3 = (pt0["pos"] as Vector3) + Vector3(0, 1.2, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + side_v * 8.0)
		q.collision_mask = 1
		var hit := _player.get_world_3d().direct_space_state.intersect_ray(q)
		var depth: float = from.distance_to(hit.position) if hit else 99.0
		_ok("C6: there is a ROOM behind the doors (%.2f m to the back wall)" % depth, depth > 1.5 + 2.5 and depth < 1.5 + 4.0)
		_ok("C6: ...with a bed in it", _scene.get_node_or_null("BreakRoomBed") != null)
		var fig := _scene.get_node_or_null("BreakDoorFigure") as Node3D
		_ok("C5: ...with a figure standing in the hall", fig != null)
		if fig:
			var fp: Dictionary = _scene.call("_path_point", bat + float(_scene.get("BREAK_FIGURE_PAST")))
			var off := Vector2(fig.global_position.x - (fp["pos"] as Vector3).x, fig.global_position.z - (fp["pos"] as Vector3).z).length()
			_ok("C5: ...in the MIDDLE of the way, 2 m past the door (%.2f m off the centreline)" % off, off < 0.3)
		# walk up to it: within BREAK_FIGURE_GONE_M it is gone and the door is shut
		_player.global_position = (_scene.call("_path_point", bat + 0.5) as Dictionary)["pos"] + Vector3(0, 0.1, 0)
		_scene.call("_tick_break_door")
		_ok("C5: at arm's reach the beat is done and the figure is gone", bool(_scene.get("_break_done")))
		_ok("C6: ...and BOTH leaves slam shut", not bool(bdoor.call("is_ajar")) and (bdoor2 == null or not bool(bdoor2.call("is_ajar"))))
		_player.global_position = keep
	# C2 (2026-09-13): two forks, each a loop with a shut door, a note and a dead torch; zero panic.
	var forks: Array = _scene.call("forks")
	_ok("C2: two forks were built", forks.size() == 2)
	for f in forks:
		var i2: int = int(f["index"])
		_ok("C2: fork %d's door starts SHUT" % i2, bool((f["door"] as Node).get("_closed")))
		_ok("C2: fork %d carries a readable note" % i2, _scene.get_node_or_null("Fork%dNote" % i2) != null)
		_ok("C2: fork %d has a dead torch at its mouth" % i2, _scene.get_node_or_null("Fork%dDeadTorch" % i2) != null
			and not bool(_scene.get_node("Fork%dDeadTorch" % i2).get("lit")))
		var fa: float = float((cs["FORKS"] as Array)[i2]["at"])
		var fb: float = fa + float((cs["FORKS"] as Array)[i2]["across"])
		var clear := true
		for name in beats:
			var bd: float = float(beats[name])
			if bd > fa - 8.0 and bd < fb + 8.0:
				clear = false
		_ok("C2: fork %d (%.0f-%.0f m) sits clear of every big beat" % [i2, fa, fb], clear)


func _c1_shut_in_start() -> void:
	var spurs: Array = _scene.call("spurs")
	var e: Dictionary = spurs[0]
	_spur_door = e["door"]
	_spur_torch = e["torch"]
	_panic_before_shut = _player.get_panic_ratio()
	# Walk into the far end of spur 0.
	var deep: Vector3 = (e["mouth"] as Vector3) + (e["dir"] as Vector3) * (float(e["len"]) - 1.2)
	_player.global_position = deep + Vector3(0, 0.1, 0)
	_player.velocity = Vector3.ZERO


var _bell_rung := false
var _bell_turned := false
var _bell_door: Node = null
var _bell_mouth: Vector3 = Vector3.ZERO
var _panic_before_bell := 0.0
var _cup_checked := false
var _cup_move_checked := false
var _cup_torch_on := false
var _panic_before_cup := 0.0


func _c2_bell_start() -> void:
	var e: Dictionary = (_scene.call("spurs") as Array)[1]
	_bell_door = e["door"]
	_bell_mouth = e["mouth"]
	var desk: Node3D = _scene.get_node("Spur1Desk")
	# stand in front of the desk, facing it, and ring through the shipping ray
	_player.global_position = desk.global_position - (e["dir"] as Vector3) * 1.4 + Vector3(0, 0.1, 0)
	_player.velocity = Vector3.ZERO
	var bell: Node3D = _scene.get_node("Spur1Bell")
	_player.call("ai_look_at", bell.global_position)
	_player.set("_panic", 0.0)
	(bell as Node).call("interact")


func _c3_cupboard_start() -> void:
	var e: Dictionary = (_scene.call("spurs") as Array)[2]
	var cup: Node3D = _scene.get_node("Spur2Cupboard")
	_panic_before_cup = 0.0
	# "...for free" measures the cupboard's OWN cost; the global RandomAmbient metronome
	# (5/8/12 panic every 18–35 s) is not part of it and fired inside the 12.5 s window once.
	var ra := root.get_node_or_null("/root/RandomAmbient")
	if ra:
		ra.set_process(false)
	_player.set("_panic", 0.0)
	_player.global_position = cup.global_position + Vector3(0, 0.1, 0)
	_player.velocity = Vector3.ZERO
	_player.call("ai_look_at", (e["mouth"] as Vector3) + Vector3(0, 1.4, 0))


func _c1_manager_start() -> void:
	# Stand where the second telegraph pays off, facing down the corridor, and fire it.
	var d: float = float((_cs()["TELEGRAPH_AT"] as Array)[1])
	var pt: Dictionary = _scene.call("_path_point", d)
	_player.global_position = (pt["pos"] as Vector3) + Vector3(0, 0.1, 0)
	_player.velocity = Vector3.ZERO
	_player.call("ai_look_at", (pt["pos"] as Vector3) + (pt["dir"] as Vector3) * 10.0 + Vector3(0, 1.6, 0))
	_player.set("_panic", 0.0)
	_panic_before_mgr = _player.get_panic_ratio()
	_scene.set("_manager_fired", false)
	_scene.call("_ev_manager")


func _false_door_static() -> void:
	var cs: GDScript = _scene.get_script()
	_door = _find(_scene, "FalseExitDoor") as Node3D
	_ok("the false exit door exists", _door != null)
	if _door == null:
		return

	var dist: float = float(cs.get("FALSE_DOOR_DIST"))
	var total: float = float(_scene.get("_total_len"))
	_ok("it is nowhere near the real exit", total - dist >= 100.0,
		"%.0f m from the door at %.0f m" % [total - dist, total])
	# ⚠️ Not on a mirror corner — those two are spoken for and already carry two beats each.
	var clash := false
	for m in (cs.get("TURN_MIRRORS") as Array):
		if absf(float(m[0]) - dist) < 5.0:
			clash = true
	_ok("it is not on a turn-mirror corner", not clash, "d=%.0f m" % dist)

	# It has to look like an exit from FAR AWAY or the deception never starts. Measured the
	# same way the silhouette is: from the far end of the approach leg.
	var far := _scene.call("_path_point", dist - 44.0) as Dictionary
	var keep := _player.global_transform
	_face(far.pos as Vector3, _door.global_position)
	var frame := _find(_scene, "FalseExitFrame") as Node3D
	_ok("the blood-red frame exists", frame != null)
	if frame != null:
		var lit := false
		var energy := 0.0
		for n in _descendants(frame):
			var mi := n as MeshInstance3D
			if mi == null:
				continue
			var mat := mi.material_override as StandardMaterial3D
			if mat != null and mat.emission_enabled:
				lit = true
				energy = maxf(energy, mat.emission_energy_multiplier)
		_ok("the frame is emissive — the exit livery", lit, "energy x%.2f" % energy)
		# ⚠️ Issue 21: above 1.0 this renderer clamps to flat white with no detail.
		_ok("...and not above the 1.0 clamp", energy <= 1.0, "x%.2f" % energy)
		_ok("it is visible from the far end of the approach",
			_apparent_height(frame) > 0.02,
			"%.2f %% of screen height at 44 m" % (_apparent_height(frame) * 100.0))
	var glow := _find(_scene, "FalseExitGlow") as OmniLight3D
	_ok("there is a real red light, not only emission", glow != null,
		"range %.1f m" % (glow.omni_range if glow != null else 0.0))
	# The dark beartrap stretch must stay dark: DARK_ZONES ends at 172.
	if glow != null:
		var zones: Array = cs.get("DARK_ZONES")
		var nearest := INF
		for z in zones:
			nearest = minf(nearest, absf(dist - float((z as Vector2).y)))
		_ok("its light cannot reach the dark beartrap stretch", glow.omni_range < nearest,
			"range %.1f m vs %.1f m away" % [glow.omni_range, nearest])

	_ok("it advertises a prompt before it has been used", _door.call("can_interact"))
	# The leaf must be the 217 art. If this ever silently falls back, the whole trap is a
	# generic hotel door and nothing about the beat works.
	var face := _find(_door, "Face_front") as MeshInstance3D
	_ok("the leaf wears the 217 artwork", face != null
		and (face.material_override as StandardMaterial3D) != null
		and (face.material_override as StandardMaterial3D).albedo_texture != null
		and (face.material_override as StandardMaterial3D).albedo_texture.resource_path
			.get_file() == "hotel_door_217.png",
		String((face.material_override as StandardMaterial3D).albedo_texture.resource_path)
			if face != null else "no face")
	_player.global_transform = keep


func _false_door_place() -> void:
	if _door == null:
		return
	# Stand where a player walking up to it would, and aim at the MESH, never at the collider —
	# aiming at the collider is what let a previous version of `check_interact_reach.gd` pass
	# against volumes a player could not actually hit.
	var cs: GDScript = _scene.get_script()
	var dist: float = float(cs.get("FALSE_DOOR_DIST"))
	var approach := _scene.call("_path_point", dist - 0.9) as Dictionary
	var leaf := _find(_door, "Leaf") as MeshInstance3D
	var aim: Vector3 = leaf.global_position if leaf != null else _door.global_position
	_face(approach.pos as Vector3, aim)
	_cam().rotation.x = 0.0
	_player.set("ai_active", true)


func _false_door_open() -> void:
	if _door == null:
		return
	_panic_before = _player.get_panic_ratio()
	_ok("the shipping raycast finds it", _player.call("ai_interact_target") == _door,
		"%.2f m away, target %s"
			% [_player.global_position.distance_to(_door.global_position),
				str(_player.call("ai_interact_target"))])
	# C4 (2026-09-15): without the bell's key E does nothing — no swing, no figure, no panic.
	_ok("C4: it requires the key", bool(_door.get("requires_key")) and not bool(_door.call("has_key")))
	_player.call("ai_interact")
	_ok("C4: E without the key does not open it", not bool(_door.call("is_used")) and is_zero_approx(_door.rotation.y - _door_rest_y())
		and _find(_scene, "DoorLunger") == null)
	_ok("C4: ...and costs nothing", is_equal_approx(_player.get_panic_ratio(), _panic_before))
	var toast := false
	for n in _descendants(root):
		if n is Label and String((n as Label).text).contains("needs a key"):
			toast = true
	_ok("C4: ...and it says so (\"It needs a key.\")", toast)
	_ok("C4: ...and still answers E afterwards", bool(_door.call("can_interact")))
	# the bell served it — the C4 stage later proves the handoff through the beat itself
	_door.call("give_key")
	_player.call("ai_interact")
	# ⚠️ The spike is measured as a PEAK over the following frames (`_false_door_watch`), not
	# here: since 2026-09-10 it lands with the lunge, FALSE_DOOR_LUNGE_AT after E. Panic decays
	# at 3.5/s, so the peak is sampled every frame and compared with a tolerance of one frame's
	# decay — measuring it after a fixed wait once reported +8.4 for a +15 event.
	_panic_gain = 0.0
	_panic_peak = _panic_before
	_panic_prev = _panic_before * 50.0
	_panic_prev_set = true
	_lunger_seen = false
	_lunger_nearest = INF
	_lunger_farthest = 0.0
	_flash_seen = false
	_pin_seen = false
	_pin_released = false


var _panic_peak := 0.0
var _panic_prev := 0.0
var _panic_prev_set := false
var _lunger_seen := false
var _lunger_nearest := INF
var _lunger_farthest := 0.0
var _flash_seen := false
var _pin_seen := false
var _pin_released := false


func _false_door_watch(_delta: float) -> void:
	# The spike is the largest FRAME-TO-FRAME jump, not "peak minus the level at E": the
	# baseline decays at 3.5/s during the 0.30 s before the lunge, and measuring against it
	# reported +13.9 for a +15 event.
	var now: float = _player.get_panic_ratio() * 50.0
	if _panic_peak > 0.0 or _panic_prev_set:
		_panic_gain = maxf(_panic_gain, now - _panic_prev)
	_panic_prev = now
	_panic_prev_set = true
	_panic_peak = maxf(_panic_peak, _player.get_panic_ratio())
	var screamer := root.get_node_or_null("/root/Screamer")
	if screamer:
		var panel := screamer.get("_black_panel") as CanvasItem
		if panel and panel.visible:
			_flash_seen = true
	var l := _find(_scene, "DoorLunger") as Node3D
	if l:
		_lunger_seen = true
		var d: float = _cam().global_position.distance_to(l.global_position + Vector3(0, 1.2, 0))
		if float(l.call("alpha")) > 0.5:
			_lunger_nearest = minf(_lunger_nearest, d)
		_lunger_farthest = maxf(_lunger_farthest, d)
	if _t > 0.5 and _t < 1.2 and _player.is_input_frozen():
		_pin_seen = true
	if _t > 2.2 and not _player.is_input_frozen():
		_pin_released = true


func _false_door_after() -> void:
	if _door == null:
		return
	var cs: GDScript = _scene.get_script()
	_ok("opening it costs FALSE_DOOR_PANIC and nothing else",
		absf(_panic_gain - float(cs.get("FALSE_DOOR_PANIC"))) < 0.5, "+%.1f" % _panic_gain)
	_ok("the leaf actually swung", not is_zero_approx(_door.rotation.y - _door_rest_y()),
		"%.1f deg" % rad_to_deg(absf(_door.rotation.y - _door_rest_y())))
	# ---- THE THING THAT COMES OUT (2026-09-10).
	_ok("a figure came out of the doorway", _lunger_seen)
	_ok("...to arm's length of the camera", _lunger_nearest <= 1.1,
		"nearest %.2f m while visible" % _lunger_nearest)
	_ok("...and then ran away", _lunger_farthest >= 6.0, "farthest %.2f m" % _lunger_farthest)
	_ok("NO fullscreen picture was shown at any point — the flash is gone by design", not _flash_seen)
	_ok("the camera was pinned on it", _pin_seen)
	_ok("...and handed back afterwards", _pin_released)

	# ---- THE SCRAWL. The user asked for "the title written with red that It was an illusion",
	# and `ScreenText.scrawl` parents to the TREE ROOT, not to the level.
	var want: String = String(cs.get("FALSE_DOOR_SCRAWL"))
	var found := ""
	for n in _descendants(root):
		if n is Label and String((n as Label).text) == want:
			found = want
	_ok("the blood-red scrawl says it was an illusion", found == want,
		"looked for %s" % want)

	# ---- ONE-SHOT.
	_ok("it goes inert once it has fired", not _door.call("can_interact"))
	var p2: float = _player.get_panic_ratio()
	_door.call("interact")
	_ok("...and a second press costs nothing", is_equal_approx(_player.get_panic_ratio(), p2))

	# ---- IT MUST NOT SEAL THE CORNER. The leaf's collider swings with it, into a 3 m hall,
	# at a corner the player is required to turn. Issues 65/67/76 are three shipped instances
	# of an interactable narrowing a route by being used.
	var dist: float = float(cs.get("FALSE_DOOR_DIST"))
	var worst := 99.0
	var worst_at := 0.0
	for off in [0.1, 0.2, 0.4, 0.8, 1.2, 1.8, 2.4]:
		var pt := _scene.call("_path_point", dist + off) as Dictionary
		var free: float = _free_width(pt.pos as Vector3, pt.side as Vector3, 1.0)
		if free < worst:
			worst = free
			worst_at = off
	_ok("the OPEN door still leaves a walkable corner", worst >= MIN_FREE_WIDTH,
		"narrowest %.2f m of %.1f, %.1f m past the corner" % [worst, W, worst_at])

	_spawn_free_width_control(dist)


# ---- C. THE ENTRANCE NOTE READS FROM THE APPROACH ------------------------------------------
#
# 2026-08-18 capture 001: *"Turn it 180 degrees, it is currently the wrong side from the place
# I enter the room"*. A page lying flat has a right way up and nothing in this project had ever
# measured one — `check_note_mounting.gd` asks whether there is something BEHIND a prop and
# `check_art_aspect.gd` asks whether its artwork is stretched; both are perfectly happy with a
# document rotated 180° about its own normal.
#
# ⚠️ THE REFERENCE IS THE SPAWN, NOT THE PATH TABLE. `corridor.gd` now yaws the note from
# `pt.dir`, so asserting against `_path_point()` would only prove the level agrees with itself.
# `_spawn_xf` is read out of `corridor.tscn` before anything in this test moves the player.
const NOTE_FACE_DOT := 0.85     # the text's up vs. the walking direction
const NOTE_FLAT_DOT := 0.99     # the page's normal vs. world up
const NOTE_TABLE_GAP := 0.35    # how far under the page the table may be before it is floating

func _entrance_note() -> void:
	var note := _find(_scene, "IntroNote") as Node3D
	_ok("the entrance note exists", note != null)
	if note == null:
		return
	var page := _find(note, "NotePage") as MeshInstance3D
	_ok("...and it carries a real page quad", page != null)
	if page == null:
		return

	# Two independent readings of "which way is the player coming from", so the assertion
	# cannot be satisfied by the level's own bookkeeping alone.
	var spawn_pos: Vector3 = _spawn_xf.origin
	var spawn_fwd: Vector3 = -_spawn_xf.basis.z
	spawn_fwd.y = 0.0
	spawn_fwd = spawn_fwd.normalized()
	var to_note: Vector3 = page.global_position - spawn_pos
	to_note.y = 0.0
	to_note = to_note.normalized()
	_ok("the note is ahead of the spawn, along the way the player is facing",
		spawn_fwd.dot(to_note) > 0.7,
		"spawn %s facing %s, note %s" % [str(spawn_pos.round()), str(spawn_fwd), str(page.global_position.round())])
	# ⚠️ THE APPROACH IS THE SPAWN'S FACING, not the spawn->note vector. The table stands 1.05 m
	# off the centreline, so spawn->note is a 28° diagonal (dot 0.885) and a threshold set
	# against it would be within 0.035 of passing a page turned 90°. The player walks PAST this
	# table, they do not walk AT it. Sound only while the note is still on the level's first
	# straight, which is what the next line requires.
	var path_dir: Vector3 = ((_scene.call("_path_point", 4.0) as Dictionary).dir as Vector3).normalized()
	_ok("the spawn faces straight down the segment the note is on",
		spawn_fwd.dot(path_dir) > 0.99, "dot %+.4f" % spawn_fwd.dot(path_dir))

	var normal: Vector3 = page.global_basis.z.normalized()
	var text_up: Vector3 = page.global_basis.y.normalized()
	_ok("the page lies flat, artwork upward", normal.dot(Vector3.UP) > NOTE_FLAT_DOT,
		"normal %s (dot %.4f)" % [str(normal), normal.dot(Vector3.UP)])
	# THE ACTUAL COMPLAINT. On a page lying flat, the top of the lettering must point AWAY
	# from the reader — a reader standing where the player arrives from reads "up the page"
	# as "further along the corridor". Pointing it back at them is upside-down text.
	_ok("the lettering reads right way up to a player arriving from the spawn",
		text_up.dot(spawn_fwd) > NOTE_FACE_DOT,
		"text-up %s vs the spawn's heading %s -> dot %+.3f"
			% [str(text_up), str(spawn_fwd), text_up.dot(spawn_fwd)])

	# ⚠️ THE ROTATION MUST NOT HAVE LIFTED IT OFF THE TABLE. Turning a prop is exactly how a
	# mounted thing becomes a floating thing, and the table is a CSG box that this page is
	# meant to be lying ON.
	var space := _player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		page.global_position + Vector3(0, 0.02, 0),
		page.global_position - Vector3(0, NOTE_TABLE_GAP, 0))
	q.collide_with_areas = false
	q.exclude = [_player.get_rid(), (note as StaticBody3D).get_rid()]
	var hit := space.intersect_ray(q)
	_ok("the page is still resting on something solid, not floating",
		not hit.is_empty(),
		"table %.3f m below" % ((page.global_position.y - (hit.position as Vector3).y) if not hit.is_empty() else -1.0))


# ---- D. THE FALSE DOOR'S PAYLOAD -----------------------------------------------------------
#
# 2026-08-18 capture 002: *"Use the sounds for shared screamers and make it louder. Make the
# image more dark and aggressive"*. Both halves are properties of the ASSET, not of the
# mechanism, and the mechanism is what every other check in this file measures.
func _false_door_payload() -> void:
	var cs: GDScript = _scene.get_script()

	# ---- THE SOUND. `Screamer.FALLBACK_AUDIO` is the shared screamer sting — the one
	# `_apply_level_av()` pairs with the shared `screamers/` image pool — so "the sounds for
	# shared screamers" is a name this test can read rather than a string it has to trust.
	# ⚠️ THROUGH THE NODE, never the bare identifier — an autoload's name is not in scope when
	# a `--script` SceneTree compiles (check_bus_leak.gd carries the same note).
	var screamer := root.get_node_or_null("/root/Screamer")
	var gs := root.get_node_or_null("/root/GameState")
	_ok("the Screamer and GameState autoloads are present", screamer != null and gs != null)
	if screamer == null or gs == null:
		return
	var shared: String = String(screamer.get("FALLBACK_AUDIO"))
	var base: String = String(cs.get("FALSE_DOOR_SCREAM"))
	_ok("the flash uses the SHARED screamer sting", base == shared,
		"%s vs Screamer.FALLBACK_AUDIO %s" % [base, shared])
	_ok("...and it actually resolves to a stream", gs.call("load_audio", base) != null, base)
	# ⚠️ AND IT IS NOT THIS LEVEL'S DEATH SOUND. The Corridor dies to `screamer_corridor`
	# (`Screamer.LEVEL_SCREAMERS[3]`); a SURVIVABLE trap that plays the level's fatal sting
	# teaches the player that the death sound is free, which is the objection INTRO.md §301
	# raises against reusing it. The shared sting is heard nowhere else in this level.
	var level_av: Dictionary = screamer.get("LEVEL_SCREAMERS")
	var fatal: String = String((level_av.get(3) as Array)[1])
	_ok("...and it is NOT the sound the player dies to in this level", base != fatal,
		"survivable %s vs fatal %s" % [base, fatal])

	# ---- THE IMPACT LAYER (2026-09-10): the "louder" that exists past the limiter's ceiling.
	var impact: String = String(cs.get("FALSE_DOOR_IMPACT"))
	_ok("the sub-bass impact layer resolves to a stream", impact != ""
		and gs.call("load_audio", impact) != null, impact)

	# ---- THE FIGURE (2026-09-10). Not a fullscreen picture any more: an unshaded billboard
	# cutout that comes to 0.6 m of the eye. Its albedo IS its final colour, so it must be a
	# real RGBA cutout (or it billboards as a rectangle — the apparition_figure.jpg bug), dark
	# enough not to be a flashbang at arm's length, and still legible.
	var fig := _cutout_stats(String(cs.get("FALSE_DOOR_FIGURE_PATH")))
	_ok("the figure's texture loaded", fig.n > 0, "%d opaque pixels sampled" % fig.n)
	if fig.n == 0:
		return
	_ok("...and it is a real RGBA cutout, not a card", fig.has_alpha and fig.coverage > 0.15
		and fig.coverage < 0.85, "alpha=%s, %.0f %% opaque" % [fig.has_alpha, fig.coverage * 100.0])
	_ok("...dark enough for arm's length in a renderer with no tonemapping", fig.mean <= 115.0,
		"opaque-pixel mean %.1f of 255" % fig.mean)
	_ok("...with essentially no blown-out pixels", fig.hot <= 1.0,
		"%.2f %% above 0.90 sRGB" % fig.hot)
	_ok("...but still legible — not a black cut-out", fig.p99 >= 40.0,
		"p99 luminance %.1f of 255" % fig.p99)

	# ---- THE MANAGER (C2, 2026-09-15: "should look more creepy... regenerate the image"). A
	# green-screened flux generation keyed by `tools/cutout_green.py`; the same cutout rules.
	var mgr := _cutout_stats("res://assets/textures/level_3_corridor/manager_figure.png")
	_ok("C2: the Manager's texture loaded", mgr.n > 0, "%d opaque pixels sampled" % mgr.n)
	if mgr.n > 0:
		_ok("C2: ...a real RGBA cutout with a figure in it", mgr.has_alpha and mgr.coverage > 0.15
			and mgr.coverage < 0.85, "alpha=%s, %.0f %% opaque" % [mgr.has_alpha, mgr.coverage * 100.0])
		_ok("C2: ...dark enough for the hall", mgr.mean <= 115.0, "opaque-pixel mean %.1f of 255" % mgr.mean)
		_ok("C2: ...no blown-out pixels", mgr.hot <= 1.0, "%.2f %% above 0.90 sRGB" % mgr.hot)
		_ok("C2: ...and legible", mgr.p99 >= 40.0, "p99 luminance %.1f of 255" % mgr.p99)


# Mean / p99 / hot % over the OPAQUE pixels of an RGBA cutout, plus its alpha coverage.
func _cutout_stats(path: String) -> Dictionary:
	var out := {"n": 0, "mean": 0.0, "p99": 0.0, "hot": 0.0, "has_alpha": false, "coverage": 0.0}
	if not ResourceLoader.exists(path):
		return out
	var tex: Texture2D = load(path)
	var img: Image = tex.get_image()
	if img != null and img.is_compressed():
		img.decompress()   # textures import VRAM-compressed since 2026-09-13 (memory); get_pixel needs raw
	if img == null:
		return out
	if img.is_compressed():
		img.decompress()
	out.has_alpha = img.detect_alpha() != Image.ALPHA_NONE
	var lums: Array[float] = []
	var opaque := 0
	var total := 0
	var hot := 0
	var step := 3
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			total += 1
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			opaque += 1
			var l := (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0
			lums.append(l)
			if l > 0.90 * 255.0:
				hot += 1
	if opaque == 0:
		return out
	lums.sort()
	var sum := 0.0
	for l in lums:
		sum += l
	out.n = opaque
	out.mean = sum / float(opaque)
	out.p99 = lums[mini(lums.size() - 1, int(lums.size() * 0.99))]
	out.hot = 100.0 * float(hot) / float(opaque)
	out.coverage = float(opaque) / float(maxi(1, total))
	return out


# Mean / p99 / percentage-above-0.90 luminance of an imported texture, stride-sampled.
# ⚠️ Stride, never `Image.resize`: a bilinear downsample AVERAGES, which is exactly how a
# small blown-out highlight disappears from the statistic that exists to find it.
func _image_stats(path: String) -> Dictionary:
	var out := {"n": 0, "mean": 0.0, "p99": 0.0, "hot": 0.0}
	if not ResourceLoader.exists(path):
		return out
	var tex: Texture2D = load(path)
	if tex == null:
		return out
	var img: Image = tex.get_image()
	if img != null and img.is_compressed():
		img.decompress()   # textures import VRAM-compressed since 2026-09-13 (memory); get_pixel needs raw
	if img == null:
		return out
	if img.is_compressed():
		img.decompress()
	var lums: Array[float] = []
	var hot := 0
	var step := 3
	var y := 0
	while y < img.get_height():
		var x := 0
		while x < img.get_width():
			var c: Color = img.get_pixel(x, y)
			var l: float = (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * 255.0
			lums.append(l)
			if l > 0.90 * 255.0:
				hot += 1
			x += step
		y += step
	if lums.is_empty():
		return out
	lums.sort()
	var total := 0.0
	for l in lums:
		total += l
	out.n = lums.size()
	out.mean = total / float(lums.size())
	out.p99 = lums[int(float(lums.size()) * 0.99)]
	out.hot = float(hot) / float(lums.size()) * 100.0
	return out


# ⚠️ A PERMANENT POSITIVE CONTROL, and it is not optional here. Swinging this leaf to 150°
# was tried as a control and the measurement stayed green at 2.55 m — a 0.909 m panel
# CANNOT seal a 3 m hall from a wall at any angle, so the assertion above is unfalsifiable
# by the prop it is guarding. That makes it worth exactly nothing unless something proves
# it still measures. Its real value is a future re-placement (a wider leaf, a side wall, a
# second door), which is precisely the case this control simulates.
var _control_pt: Dictionary = {}

func _spawn_free_width_control(dist: float) -> void:
	var pt := _scene.call("_path_point", dist + 1.2) as Dictionary
	_control_pt = pt
	var blocker := StaticBody3D.new()
	blocker.name = "FreeWidthControl"
	var bcol := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(2.4, 2.0, 0.6)
	bcol.shape = bshape
	blocker.add_child(bcol)
	_scene.add_child(blocker)
	blocker.global_position = (pt.pos as Vector3) + (pt.side as Vector3) * 0.3 + Vector3(0, 1.0, 0)
	blocker.rotation.y = atan2((pt.side as Vector3).z, (pt.side as Vector3).x)


func _free_width_control() -> void:
	if _control_pt.is_empty():
		return
	var blocked: float = _free_width(_control_pt.pos as Vector3, _control_pt.side as Vector3, 1.0)
	_ok("CONTROL: a real obstruction in the same corner IS measured",
		blocked < MIN_FREE_WIDTH, "%.2f m free with the control block in place" % blocked)
	var b := _find(_scene, "FreeWidthControl")
	if b != null:
		b.queue_free()


# The rest angle, recovered from the frame that never rotates.
func _door_rest_y() -> float:
	var frame := _find(_scene, "FalseExitFrame") as Node3D
	return frame.rotation.y if frame != null else 0.0


func _report() -> bool:
	print("  %d checks, %d failed" % [_checks, _fails.size()])
	if _fails.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		print("RESULT: FAIL — ", ", ".join(_fails))
		quit(1)
	return true
