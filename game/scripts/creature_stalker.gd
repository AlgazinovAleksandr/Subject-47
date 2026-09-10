extends Node3D
class_name CreatureStalker

# The Void's creatures. Each stands motionless until you look at it — then,
# the moment you look away, it closes the distance. Reach you and it lunges into
# the camera and the screamer takes you. Staring to freeze it also feeds panic,
# so you cannot simply watch one forever: look too long and the panic bar fills;
# look away and it advances. Weeping-Angel logic, line-of-sight gated so a
# creature in another room stays dormant until you enter.

const STALK_SPEED := 1.25       # m/s while unobserved — slower than a walk, faster than a crawl
const CONTACT_DIST := 1.25      # horizontal distance that triggers the lunge
const ENGAGE_DIST := 8.0        # creature activates only when player enters its room
const FOV_DOT := 0.55           # cos of the half-angle that counts as "looked at"
const GAZE_INTENSITY := 0.6     # mild panic while you stare it down
const CHEST := 0.9              # ray target / facing height
const START_GRACE := 5.0        # opening seconds where nothing hunts — time to read the room
const STARE_OFF_TIME := 4.0     # continuous gaze to dismiss — costs 48 panic; requires nerve

# ── THE NIGHTMARE's "Still Ones" (DUNGEON_NIGHTMARES.md §B4.1) ──────────────────
# CreatureStalker is ALREADY a weeping angel, which is the luckiest fit in that
# whole proposal. These three additions port DN's skeletons on top of it.
#
# ⚠️ ALL THREE DEFAULT TO OFF, so the Void's four creatures are byte-for-byte
# unchanged. Only dungeon.gd sets them.

# ⭐ The scrape tell: a positional loop gated on ADVANCING. This is a genuine
# FAIRNESS UPGRADE over the Void, where the only tell is looking — consider
# back-porting it there once it has been played.
@export var scrape_tell: bool = false

# ⭐ The dud. ~35% of Still Ones topple with a crash when you get close and are then
# inert forever. This is the teaching beat and the tension engine at the same time:
# YOU CANNOT TELL A DUD FROM A KILLER WITHOUT WALKING UP TO ONE. And toppling is the
# GOOD outcome — a fallen one can never stand up again.
@export var is_dud: bool = false
@export var dud_fall_dist: float = 3.0

# The light reaction. A spark within SPARK_STEP_RANGE advances every Still One one
# step instantly; a spark within SPARK_KILL_DIST of an ACTIVE one is fatal. DN's
# exact rule, and the reason light is dangerous in that level.
@export var spark_reactive: bool = false
const SPARK_STEP := 1.0
const SPARK_STEP_RANGE := 8.0
const SPARK_KILL_DIST := 2.0

signal toppled

var _fallen: bool = false
var _scrape: AudioStreamPlayer3D = null

var _player: CharacterBody3D
var _camera: Camera3D
var _body: StaticBody3D
var _space: PhysicsDirectSpaceState3D
var _awakened: bool = false     # only stalks once you have actually seen it
var _fired: bool = false
var _age: float = 0.0           # seconds since the level began
var _stare_off_timer: float = 0.0


func _ready() -> void:
	# Drop the bare untextured capsule the scene shipped (the invisibility bug).
	for child in get_children():
		if child is MeshInstance3D:
			child.queue_free()

	# A gaze-reactive collider nested under a ScaryObject so player.gd's parent
	# walk from the ray-hit body finds the panic source above it. ScaryObject is
	# a plain Node and breaks the Node3D transform chain, so the body carries the
	# world transform itself — seeded here from the scene placement, then moved
	# directly in _process. The visual figure rides on the body so it follows.
	var scary := ScaryObject.new()
	scary.scare_intensity = GAZE_INTENSITY
	add_child(scary)
	_body = StaticBody3D.new()
	scary.add_child(_body)
	_body.global_transform = global_transform
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.7
	col.shape = shape
	col.position.y = 0.85
	_body.add_child(col)

	_build_visual()


# ⭐ THE ANIMATED MODEL (2026-09-03). Was `Void_creature.glb`, which carried **no animation
# tracks at all** — so the Void's four creatures and THE NIGHTMARE's Still Ones were rigid
# T-poses, and the `_pose_arms_down()` / `_rotate_bone()` pair that used to sit here (measured
# in 2026-08 to move nothing) was the whole of the project's skeletal code. Both are deleted.
#
# ⚠️ THIS SCRIPT NEVER HAD A RETINT AT ALL, which is why the Void's creatures rendered as the
# raw pale Mixamo "WhiteClown" skin — bright, and the opposite of the dark occluding shape the
# design calls for. It has one now.
var _anim: CreatureAnim = null

# Gait modes. Named rather than inlined because the freeze case is the level's whole mechanic.
enum Gait { DORMANT, WATCHED, ADVANCING }
var _gait: int = -1

func _build_visual() -> void:
	_anim = CreatureAnim.build(_body)
	if _anim:
		_apply_retint()
	else:
		_build_visual_procedural()
		_add_eye_glow()  # eye glow only on the procedural fallback


# ⚠️ TINT, DO NOT REPLACE. `CreatureAnim.apply_tint` duplicates the model's imported material so
# `albedo_texture` survives and `albedo_color` multiplies it. A fresh StandardMaterial3D here
# would throw the 1024 skin away — which is exactly what `creature_object12.gd` used to do.
#
# ⚠️ ALBEDO 0.55, NOT 0.02. `watcher.gd`'s premise — "a dark shape OCCLUDING a lit surface" —
# inverts wherever the background is darker than the figure, and these levels are about to run
# at ~0.02 ambient where the ONLY light is the player's own torch. A near-black creature in a
# black room lit by a beam you are pointing at it is invisible until it touches you, which is
# not fair and not frightening. 0.55 keeps the skin's own detail and lets the torch find it.
#
# ⚠️ MEASURED at 0.02 ambient under the post-darkness-pass torch (1.6 energy / 18 m / 30 deg),
# creature mean luminance against the lit floor around it — `tests/screenshot_creature.gd`:
#
#     3 m   ratio 3.09   lit BY the beam — bright, detailed, unmistakable
#     8 m   ratio 1.44   still brighter than its background
#    15 m   ratio 0.35   a DARK SHAPE against a lit floor — watcher.gd's premise, intact
#
# i.e. the tint inverts from figure-brighter to figure-darker somewhere around 10-12 m, and it
# is legible on both sides of that. Pushing it lower loses the near case; pushing it higher
# loses the far one.
# ⚠️ Zero emission: it must never be visible outside the beam.
const TINT := Color(0.55, 0.55, 0.58)

func _apply_retint() -> void:
	if _anim:
		_anim.apply_tint(TINT, 1.0, 0.1, Color.BLACK, 0.0)


# Set the gait to match what the creature is actually doing this frame.
#
# ⚠️⚠️ `Gait.WATCHED` IS THE LEVEL'S ENTIRE MECHANIC. This is a Weeping Angel: it moves only
# while it is NOT being looked at. While the model was a T-pose that rule was invisible — a
# statue looks identical watched or not — and with a real walk cycle, legs that kept moving
# while you stared straight at it would actively contradict the one rule the player has to
# learn. `CreatureAnim.freeze()` sets speed_scale to 0, so it stops MID-STRIDE and resumes the
# same stride when you look away, rather than snapping to a pose.
func _set_gait(mode: int) -> void:
	if _anim == null or _gait == mode:
		return
	_gait = mode
	match mode:
		Gait.WATCHED:
			_anim.freeze(true)
		Gait.ADVANCING:
			_anim.freeze(false)
			_anim.play_locomotion(CreatureAnim.CLIP_UNSTEADY, STALK_SPEED)
		Gait.DORMANT:
			_anim.freeze(false)
			# Alive, but not coming for you: a barely-moving standing sway.
			_anim.play(CreatureAnim.CLIP_SHAMBLE, 0.35)


func _build_visual_procedural() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.012, 0.012, 0.018)
	dark.roughness = 1.0
	dark.emission_enabled = true
	dark.emission = Color(0.18, 0.015, 0.02)
	dark.emission_energy_multiplier = 0.5

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.15
	torso_mesh.height = 2.2
	torso.mesh = torso_mesh
	torso.position.y = 1.2
	torso.set_surface_override_material(0, dark)
	_body.add_child(torso)

	for side in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.38, 0.06, 0.07)
		arm.mesh = arm_mesh
		arm.set_surface_override_material(0, dark)
		arm.position = Vector3(side * 0.24, 1.7, 0.0)
		arm.rotation_degrees.z = -side * 18.0
		_body.add_child(arm)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.16
	head_mesh.height = 0.32
	head.mesh = head_mesh
	head.position.y = 2.45
	head.set_surface_override_material(0, dark)
	_body.add_child(head)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color.BLACK
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(0.95, 0.08, 0.05)
	eye_mat.emission_energy_multiplier = 5.0
	for ex in [-0.06, 0.06]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.03
		eye_mesh.height = 0.06
		eye.mesh = eye_mesh
		eye.position = Vector3(ex, 2.48, 0.13)
		eye.set_surface_override_material(0, eye_mat)
		_body.add_child(eye)


func _add_eye_glow() -> void:
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.25, 0.35, 1.0)
	glow.light_energy = 0.35
	glow.omni_range = 1.8
	glow.position = Vector3(0, 1.75, 0.1)  # eye height — ~1.75 m on GLB, near head on procedural
	_body.add_child(glow)


func _process(delta: float) -> void:
	if _fired or _fallen:
		return
	_age += delta
	if not _player:
		# ⚠️ The relative path holds only while this node is a DIRECT child of the
		# level root next to Player. THE NIGHTMARE spawns these from a builder-owned
		# graph, so fall back to the "player" group — the same lookup player.gd
		# registers itself into, and what creature_object12.gd already uses.
		_player = get_node_or_null("../Player") as CharacterBody3D
		if not _player:
			_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if not _player:
			return
		_camera = _player.get_node_or_null("Camera3D") as Camera3D
	if not _camera:
		return

	var cam_pos := _camera.global_position
	var here: Vector3 = _body.global_position
	var my_pos: Vector3 = here + Vector3(0, CHEST, 0)
	var to_me: Vector3 = my_pos - cam_pos

	# A dud topples when you get close enough to find out what it was. Checked
	# BEFORE the engage-distance early-out, and regardless of whether it is being
	# observed — walking up to one is exactly the act being resolved.
	if is_dud and to_me.length() <= dud_fall_dist:
		_topple()
		return

	if to_me.length() > ENGAGE_DIST:
		_set_scrape(false)
		# ⚠️⚠️ THE FREEZE HAS TO HOLD AT ANY DISTANCE, and this early return used to skip it.
		# The stalk RULE was never wrong — nothing translates out here — but the animation
		# contradicted it: past ENGAGE_DIST 8 m a stared-at creature kept playing `shamble`,
		# which carries **0.515 m** of lateral hips excursion, so it visibly swayed while the
		# player looked straight at it. Measured: speed_scale 0.00 at 4.0 and 7.5 m, **0.35 at
		# 9, 12 and 20 m**. This script's own header designs for legibility at 15 m, and
		# `check_creature_anim.gd` only ever tested at 4.
		# ⚠️ It computes `observed` for the GAIT ONLY and deliberately does NOT set `_awakened`
		# — waking a creature from 20 m would change the stalk rule itself, which is not the bug.
		if _looks_observed(cam_pos, my_pos, to_me):
			_set_gait(Gait.WATCHED)
		else:
			_set_gait(Gait.DORMANT)
		return

	var los := _has_line_of_sight(cam_pos, my_pos)
	var forward := -_camera.global_transform.basis.z
	var observed := los and forward.dot(to_me.normalized()) > FOV_DOT
	if observed:
		_awakened = true
		_stare_off_timer += delta
		_set_scrape(false)   # frozen while watched, so the drag stops too
		_set_gait(Gait.WATCHED)
		if _stare_off_timer >= STARE_OFF_TIME:
			_dismiss()
		return  # frozen while watched
	_stare_off_timer = 0.0  # reset the moment the player looks away
	if not _awakened or not los:
		_set_scrape(false)
		_set_gait(Gait.DORMANT)
		return  # never seen, or a wall is between us — stay put
	if _age < START_GRACE:
		_set_scrape(false)
		_set_gait(Gait.DORMANT)
		return  # opening grace: seen, but not yet hunting

	var flat := Vector2(here.x - _player.global_position.x,
		here.z - _player.global_position.z).length()
	if flat <= CONTACT_DIST:
		_lunge()
		return

	var dir := Vector3(_player.global_position.x - here.x, 0,
		_player.global_position.z - here.z).normalized()
	_body.global_position = here + dir * STALK_SPEED * delta
	_body.rotation.y = atan2(dir.x, dir.z)
	_set_scrape(true)   # advancing: the dry wooden drag is the tell
	_set_gait(Gait.ADVANCING)


# Is the player looking at us right now? Used ONLY to decide the gait beyond ENGAGE_DIST — the
# in-range branch computes its own `observed` because that one also drives `_awakened` and the
# stare-off timer, which must not fire from across a level.
func _looks_observed(cam_pos: Vector3, my_pos: Vector3, to_me: Vector3) -> bool:
	if not _has_line_of_sight(cam_pos, my_pos):
		return false
	var forward := -_camera.global_transform.basis.z
	return forward.dot(to_me.normalized()) > FOV_DOT


func _has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	if not _space:
		_space = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_player.get_rid(), _body.get_rid()]
	# Nothing between the camera and the creature (excluding the two of us) = clear.
	return _space.intersect_ray(query).is_empty()


func _dismiss() -> void:
	_stare_off_timer = 0.0
	_awakened = false
	_set_gait(Gait.DORMANT)
	if _player:
		var away := Vector3(_body.global_position.x - _player.global_position.x,
			0, _body.global_position.z - _player.global_position.z).normalized()
		_body.global_position += away * 3.0


func _lunge() -> void:
	_fired = true
	_set_scrape(false)
	# The last thing you see is it coming at full tilt, not mid-shuffle.
	if _anim:
		_anim.play(CreatureAnim.CLIP_CHARGE, 1.4, 0.05)
	global_position = _camera.global_position - _camera.global_transform.basis.z * 0.3
	Screamer.trigger()


# ── THE NIGHTMARE additions (inert unless the matching @export is set) ──────────

# The dud outcome: a loud crash, and it is inert forever. Pure jumpscare — and this
# is the GOOD result, which is what makes approaching one a real decision.
func _topple() -> void:
	_fallen = true
	_set_scrape(false)
	# ⚠️ Stop the clip BEFORE the topple tween. A rigid thing falls over; a walking one does
	# not, and an AnimationPlayer left running would keep the legs cycling as it hits the floor.
	if _anim:
		_anim.halt()
	var tw := create_tween()
	tw.tween_property(_body, "rotation:x", deg_to_rad(-88.0), 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var s := GameState.load_audio("skeleton_fall")
	if s:
		var pl := AudioStreamPlayer3D.new()
		pl.stream = s
		pl.unit_size = 14.0
		pl.volume_db = 2.0
		_body.add_child(pl)
		pl.play()
	toppled.emit()


func _set_scrape(on: bool) -> void:
	if not scrape_tell:
		return
	if _scrape == null:
		_scrape = AudioStreamPlayer3D.new()
		_scrape.name = "BoneScrape"
		var s := GameState.load_audio("bone_scrape")
		if s == null:
			scrape_tell = false
			return
		_scrape.stream = s
		_scrape.unit_size = 6.0
		_scrape.volume_db = -4.0
		# ⚠️ Every .wav.import in this project is loop_mode=0, so a loop has to be
		# re-triggered from `finished`. walk_lab_wing.gd asserts this exact idiom.
		_body.add_child(_scrape)
		_scrape.finished.connect(_scrape.play)
	if on and not _scrape.playing:
		_scrape.play()
	elif not on and _scrape.playing:
		_scrape.stop()


# Called by dungeon.gd for every Still One when the player sparks.
# DN's exact rule: light advances them, and light too close to an ACTIVE one kills.
func on_spark(spark_pos: Vector3) -> void:
	if not spark_reactive or _fired or _fallen:
		return
	var here: Vector3 = _body.global_position
	var d: float = Vector2(here.x - spark_pos.x, here.z - spark_pos.z).length()
	if d > SPARK_STEP_RANGE:
		return
	if _awakened and d <= SPARK_KILL_DIST:
		_lunge()
		return
	# One step closer, instantly. The flash woke it and it used the moment.
	_awakened = true
	var dir := Vector3(spark_pos.x - here.x, 0.0, spark_pos.z - here.z)
	if dir.length() < 0.05:
		return
	_body.global_position = here + dir.normalized() * SPARK_STEP


func has_fallen() -> bool:
	return _fallen


func is_active() -> bool:
	return _awakened and not _fallen and not _fired
