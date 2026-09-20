extends Node

@export var max_blur_strength: float = 1.0
@export var max_tint_blend: float = 0.5

@onready var _blur_material: ShaderMaterial = $BlurRect.material
@onready var _tint_material: ShaderMaterial = $TintRect.material

const _OBJECTIVE_REST_ALPHA := 0.5   # resting opacity — readable but unobtrusive
const _CARRY_REST_ALPHA := 0.45
var _objective_label: Label = null
var _carry_label: Label = null


func _ready() -> void:
	_build_objective_label()
	_build_carry_label()
	GameState.objective_changed.connect(_on_objective_changed)
	GameState.carried_changed.connect(_on_carried_changed)
	# Re-announce on a mid-level reload where GameState already holds the goal.
	if GameState.current_objective != "":
		_on_objective_changed(GameState.current_objective)
	if GameState.carried_item != "":
		_on_carried_changed(GameState.carried_item)


func _build_objective_label() -> void:
	_objective_label = Label.new()
	_objective_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective_label.offset_top = 22.0
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 18)
	_objective_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	# A soft shadow so the line stays legible over bright and dark walls alike.
	_objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_objective_label.add_theme_constant_override("shadow_offset_x", 1)
	_objective_label.add_theme_constant_override("shadow_offset_y", 1)
	_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_label.modulate.a = 0.0
	add_child(_objective_label)


# Announce the new goal: fade up to full, then settle to a quiet resting alpha.
func _on_objective_changed(text: String) -> void:
	if not _objective_label:
		return
	_objective_label.text = text
	if text == "":
		_objective_label.modulate.a = 0.0
		return
	var tween := create_tween()
	tween.tween_property(_objective_label, "modulate:a", 1.0, 0.35)
	tween.tween_interval(2.0)
	tween.tween_property(_objective_label, "modulate:a", _OBJECTIVE_REST_ALPHA, 1.2)


# The game has several "walk to the obstacle, press E, the level checks what you are
# holding" gates — the cellar key, KONTUR's three bottles, KONTUR's hammer — and until
# now nothing on screen ever said what you were carrying. One quiet line under the
# objective, deliberately NOT an icon strip: same shape as the objective label, no new
# UI system and no per-item art.
func _build_carry_label() -> void:
	_carry_label = Label.new()
	_carry_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_carry_label.offset_top = 48.0     # directly under the objective line (top 22 + ~26)
	_carry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_carry_label.add_theme_font_size_override("font_size", 15)
	_carry_label.add_theme_color_override("font_color", Color(0.72, 0.80, 0.70))
	_carry_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_carry_label.add_theme_constant_override("shadow_offset_x", 1)
	_carry_label.add_theme_constant_override("shadow_offset_y", 1)
	_carry_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_carry_label.modulate.a = 0.0
	add_child(_carry_label)


func _on_carried_changed(item: String) -> void:
	if not _carry_label:
		return
	if item == "":
		_carry_label.text = ""
		var out := create_tween()
		out.tween_property(_carry_label, "modulate:a", 0.0, 0.3)
		return
	_carry_label.text = "CARRYING: %s" % item.to_upper()
	var tween := create_tween()
	tween.tween_property(_carry_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(_carry_label, "modulate:a", _CARRY_REST_ALPHA, 1.0)


# ⭐ THE PANIC-BAR LIE (2026-09-20 — SCARY.md P8 effect 1, built for the Void's stare director).
# The player re-drives this HUD every frame (player.gd `_update_panic` / `add_panic`), so a lie has
# to live HERE: for `seconds` the shaders show `ratio` instead of whatever the player sends, then
# the next real call restores the truth. Real `_panic` never moves — the WORLD lies, the RULES do
# not (§8.6). Byte-identical behaviour while no lie is active.
var _lie_until_ms: int = 0
var _lie_ratio: float = 0.0


func lie(ratio: float, seconds: float) -> void:
	_lie_ratio = clampf(ratio, 0.0, 1.0)
	_lie_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
	_apply_ratio(_lie_ratio)


func is_lying() -> bool:
	return Time.get_ticks_msec() < _lie_until_ms


func set_panic_ratio(ratio: float) -> void:
	_apply_ratio(_lie_ratio if is_lying() else ratio)


func _apply_ratio(ratio: float) -> void:
	if not _blur_material or not _tint_material:
		return
	ratio = clampf(ratio, 0.0, 1.0)
	_blur_material.set_shader_parameter("blur_amount", ratio * max_blur_strength)
	_tint_material.set_shader_parameter("blend_amount", ratio * max_tint_blend)
