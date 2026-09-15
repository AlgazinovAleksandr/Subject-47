extends Node3D
class_name DoorLunger

# The thing behind the false room 217 (2026-09-10, the user's replay of the Corridor: *"make it
# look more natural — like something is actually showing up from there and trying to make you
# scared and then runs away"*). It replaces a fullscreen `flash_scare` picture with a figure IN
# THE WORLD: it stands in the doorway as the leaf swings, lunges to arm's length, holds there,
# then turns and sprints away round the corner and is gone.
#
# A billboard cutout like `watcher.gd`'s — unshaded, TRANSPARENCY_ALPHA, fixed-Y billboard so
# it always faces the player, the quad sized from the texture's own aspect (SCARY.md §7.1(4)).
# ⚠️ NO RULES OF ITS OWN: no collider, no `ScaryObject`, no kill radius, no `Screamer`, no
# panic. The level (`corridor.gd:_on_false_door_opened`) owns the sting, the jolt, the panic
# and the scrawl; this node owns only the motion. That split is the project's convention
# (`sprawl_dweller.gd`, `watcher.gd`) and it is what keeps a beat re-tunable from one place.
#
# ⚠️ `false_door_lunger.png` must stay a real RGBA cutout or this billboards as a solid
# rectangle (the `apparition_figure.jpg` bug). `tools/cutout_alpha.py` makes it one.

signal lunged     # it has reached arm's length
signal gone       # it has fled and freed itself

const FADE_IN := 0.08
const SHUDDER_HZ := 9.0
const SHUDDER_AMP := 0.035

var _quad: MeshInstance3D = null
var _mat: StandardMaterial3D = null
var _height := 2.0
var _shudder := false
var _shudder_t := 0.0
var _base_pos := Vector3.ZERO
var _fleeing := false
var _flee_from := Vector3.ZERO
var _flee_to := Vector3.ZERO
var _flee_speed := 6.0
var _flee_fade_m := 2.5
var _flee_len := 1.0


static func build(parent: Node, at: Vector3, tex_path: String, height: float = 2.0) -> DoorLunger:
	var l := DoorLunger.new()
	l.name = "DoorLunger"
	l._height = height
	parent.add_child(l)
	l.global_position = at
	l._build_figure(tex_path)
	return l


func _build_figure(tex_path: String) -> void:
	_quad = MeshInstance3D.new()
	_quad.name = "Figure"
	var mesh := QuadMesh.new()
	var aspect := 0.5
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex_path != "" and ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path)
		_mat.albedo_texture = tex
		if tex and tex.get_height() > 0:
			aspect = float(tex.get_width()) / float(tex.get_height())
	else:
		_mat.albedo_color = Color(0.05, 0.05, 0.06, 1.0)
	mesh.size = Vector2(_height * aspect, _height)
	_quad.mesh = mesh
	_quad.set_surface_override_material(0, _mat)
	_quad.position.y = _height / 2.0
	_mat.albedo_color.a = 0.0
	add_child(_quad)


## L2 (2026-09-14, Issue 208). An UNSHADED billboard renders at its texture's own values, and
## `wing_monster.png` is ~12 % grey — against the Lab wing's black (torch locked off) that is
## nothing. `apparition.gd`'s figure reads in the dark because it carries its albedo as
## EMISSION at 1.6; this gives a lunger the same knob. Off by default: the Manager and the
## false-door figure stand in lit corridors and were tuned without it.
func set_glow(energy: float) -> void:
	if _mat == null:
		return
	_mat.emission_enabled = energy > 0.0
	if _mat.albedo_texture:
		_mat.emission_texture = _mat.albedo_texture
	_mat.emission = Color(1, 1, 1)
	_mat.emission_energy_multiplier = energy


## A short-range light that travels with the figure (the walls around it light up as it comes).
func add_light(range_m: float, energy: float, colour: Color = Color(0.8, 0.85, 1.0)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.name = "LungerLight"
	l.omni_range = range_m
	l.light_energy = energy
	l.light_color = colour
	l.position = Vector3(0, _height * 0.6, 0)
	add_child(l)
	return l


## C3: a WALK (no shudder, no self-free) at `speed` toward `point`, pausable — the pass-by.
var _walking: bool = false
var _walk_to: Vector3 = Vector3.ZERO
var _walk_speed: float = 1.0
var _walk_paused: bool = false
signal walked      # it reached the walk's end (and is still there; the caller frees it)


func walk_to(point: Vector3, speed: float) -> void:
	_shudder = false
	_fleeing = false
	_walking = true
	_walk_paused = false
	_walk_to = Vector3(point.x, global_position.y, point.z)
	_walk_speed = maxf(0.2, speed)
	var fade := create_tween()
	fade.tween_property(_mat, "albedo_color:a", 1.0, 0.4)


func set_walk_paused(paused: bool) -> void:
	_walk_paused = paused


func is_walking() -> bool:
	return _walking and not _walk_paused


## Just stand there: fade in over `time`, no motion (the C5 doorway figure, where a Watcher's
## 0.9 m clearance fan can never pass).
func appear(time: float = 0.3) -> void:
	var fade := create_tween()
	fade.tween_property(_mat, "albedo_color:a", 1.0, maxf(0.01, time))


func figure_height() -> float:
	return _height


func alpha() -> float:
	return _mat.albedo_color.a if _mat else 0.0


func is_fleeing() -> bool:
	return _fleeing


# Resolve and go for the target point (feet), over `time` seconds, then shudder in place.
func lunge_to(point: Vector3, time: float) -> void:
	var fade := create_tween()
	fade.tween_property(_mat, "albedo_color:a", 1.0, FADE_IN)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position", point, time)
	tw.tween_callback(func() -> void:
		_base_pos = global_position
		_shudder = true
		lunged.emit()
	)


# Turn and go: a straight run to `point` at `speed` m/s, fading out over the last `fade_m`.
func flee_to(point: Vector3, speed: float, fade_m: float) -> void:
	_shudder = false
	_fleeing = true
	_flee_from = global_position
	_flee_to = Vector3(point.x, global_position.y, point.z)
	_flee_speed = maxf(0.5, speed)
	_flee_fade_m = maxf(0.1, fade_m)
	_flee_len = maxf(0.01, _flee_from.distance_to(_flee_to))


func _process(delta: float) -> void:
	if _walking:
		if _walk_paused:
			return
		var wto := _walk_to - global_position
		var wstep := _walk_speed * delta
		if wto.length() <= wstep:
			global_position = _walk_to
			_walking = false
			walked.emit()
			return
		global_position += wto.normalized() * wstep
		return
	if _shudder:
		_shudder_t += delta
		var s := sin(_shudder_t * TAU * SHUDDER_HZ) * SHUDDER_AMP
		global_position = _base_pos + Vector3(s, absf(s) * 0.4, 0.0)
		return
	if not _fleeing:
		return
	var to := _flee_to - global_position
	var step := _flee_speed * delta
	if to.length() <= step:
		_finish()
		return
	global_position += to.normalized() * step
	var left := _flee_to.distance_to(global_position)
	if left < _flee_fade_m and _mat:
		_mat.albedo_color.a = clampf(left / _flee_fade_m, 0.0, 1.0)


func _finish() -> void:
	_fleeing = false
	gone.emit()
	queue_free()
