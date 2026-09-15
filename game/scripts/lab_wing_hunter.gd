extends Node3D
class_name LabWingHunter

# THE PRESENCE in the Lab's dark wing (L1.3, 2026-09-13, the user's pick: "something hunts you
# by sound in it"). It follows the player's own FOOTSTEP TRAIL — never a straight line through
# masonry — at SPEED while they walk and stops dead when they stop, so the only rule to learn is
# "stop and it stops". It cannot come inside KEEP_OUT; a contact costs CONTACT_PANIC and a jolt,
# and it drops back DROP_BACK along the trail. Because it is slower than a walking player it only
# ever GAINS on you when you walk back toward it — i.e. out of a dead end — which is the wing.
#
# ⚠️ NON-LETHAL BY CONSTRUCTION: no `Screamer`, no collider, no `ScaryObject`, no kill radius.
# The torch is locked off in the wing, so the figure is an AUDIO presence (`bone_scrape` while it
# moves); the dim billboard is there for the moment the lights come back — and `sleep()` hides it
# then anyway. `SCARY.md` §8.4's one-chase-level rule is not touched: this thing never chases.

const SPEED := 1.6
const KEEP_OUT := 2.5
const CONTACT_PANIC := 12.0
const DROP_BACK := 6.0
const TRAIL_STEP := 0.5
const COOLDOWN := 4.0
const WAKE_GRACE := 6.0
const SCRAPE_DB := -3.0

var _player: CharacterBody3D = null
var _trail: PackedVector3Array = PackedVector3Array()
var _seg: int = 0          # index of the trail point it is walking toward
var _awake := false
var _cool := 0.0
var _scrape: AudioStreamPlayer3D = null
var _quad: MeshInstance3D = null
var contacts: int = 0


static func build(parent: Node, player: CharacterBody3D, tex_path: String) -> LabWingHunter:
	var h := LabWingHunter.new()
	h.name = "WingPresence"
	h._player = player
	parent.add_child(h)
	h._build_figure(tex_path)
	return h


func _build_figure(tex_path: String) -> void:
	_quad = MeshInstance3D.new()
	_quad.name = "Figure"
	var mesh := QuadMesh.new()
	var aspect := 0.5
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path)
		mat.albedo_texture = tex
		if tex and tex.get_height() > 0:
			aspect = float(tex.get_width()) / float(tex.get_height())
	mat.albedo_color = Color(0.22, 0.21, 0.24, 1.0)   # a shape, never a lamp
	mesh.size = Vector2(2.1 * aspect, 2.1)
	_quad.mesh = mesh
	_quad.set_surface_override_material(0, mat)
	_quad.position.y = 1.05
	add_child(_quad)
	_scrape = AudioStreamPlayer3D.new()
	_scrape.name = "Drag"
	var s := GameState.load_audio("bone_scrape")
	if s:
		_scrape.stream = s
		_scrape.finished.connect(_scrape.play)
	_scrape.volume_db = SCRAPE_DB
	_scrape.unit_size = 6.0
	_scrape.max_db = 3.0
	_scrape.bus = AudioBuses.AMBIENCE
	add_child(_scrape)
	_scrape.position.y = 0.4


# Start at `from` (the wing's entrance), with the trail running from there to the player.
func wake(from: Vector3) -> void:
	_awake = true
	_cool = WAKE_GRACE
	_trail = PackedVector3Array([Vector3(from.x, 0.0, from.z), _flat(_player.global_position)])
	global_position = _trail[0]
	_seg = 1
	visible = true


func sleep() -> void:
	_awake = false
	visible = false
	if _scrape and _scrape.playing:
		_scrape.stop()


func is_awake() -> bool:
	return _awake


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _process(delta: float) -> void:
	if not _awake or _player == null or not is_instance_valid(_player):
		return
	_cool = maxf(0.0, _cool - delta)
	var here := _flat(_player.global_position)
	if here.distance_to(_trail[_trail.size() - 1]) >= TRAIL_STEP:
		_trail.append(here)
	var moving: bool = Vector2(_player.velocity.x, _player.velocity.z).length() > 0.3
	if _scrape and _scrape.stream:
		if moving and not _scrape.playing:
			_scrape.play()
		elif not moving and _scrape.playing:
			_scrape.stop()
	if moving:
		var budget := SPEED * delta
		while budget > 0.0 and _seg < _trail.size():
			var to: Vector3 = _trail[_seg] - global_position
			var d := to.length()
			if d <= budget:
				global_position = _trail[_seg]
				budget -= d
				_seg += 1
			else:
				global_position += to / d * budget
				budget = 0.0
	# Never inside KEEP_OUT: the contact, then it falls back down its own trail.
	if global_position.distance_to(here) < KEEP_OUT and _cool <= 0.0:
		_contact()


func _contact() -> void:
	contacts += 1
	_cool = COOLDOWN
	if _player.has_method("add_panic"):
		_player.add_panic(CONTACT_PANIC)
	if _player.has_method("jolt_camera"):
		_player.jolt_camera(0.16, 0.4)
	var s := GameState.load_audio("nook_scream")
	if s:
		var a := AudioStreamPlayer3D.new()
		a.stream = s
		a.volume_db = -8.0
		a.unit_size = 6.0
		a.max_db = 3.0
		a.bus = AudioBuses.AMBIENCE
		add_child(a)
		a.finished.connect(a.queue_free)
		a.play()
	drop_back(DROP_BACK)


# Retreat `metres` back down ITS OWN path — from where it stands toward the trail's start —
# so the drop is away from the player whichever way they turned. (The first version walked back
# from the trail's END, which after a player doubles back lands right next to them.)
func drop_back(metres: float) -> void:
	var left := metres
	var i := clampi(_seg, 1, _trail.size() - 1)   # heading toward trail[i]; behind it lies trail[i-1]
	var at: Vector3 = global_position
	while i > 0 and left > 0.0:
		var seg_len: float = at.distance_to(_trail[i - 1])
		if seg_len >= left:
			at = at + (_trail[i - 1] - at).normalized() * left
			left = 0.0
			break
		left -= seg_len
		i -= 1
		at = _trail[i]
	global_position = at
	_seg = maxi(i, 1) if left <= 0.0 else 1
