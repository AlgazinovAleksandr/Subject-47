extends Node
class_name SpurEscape

# C1 (2026-09-13, the user: "to open the door you just need to wait — maybe you need to press
# Space like we did with the cabinet"). The Corridor's dead-end spurs shut you in; this is the
# way out: MASH SPACE against the door. Three bars (the locker's idiom, `lab_locker.gd`), each
# press worth PRESS of a bar that drains at DECAY per second; a full bar lurches, the third
# forces the door (`SlamDoor.force_open()`). The player is NOT frozen — they can turn and look
# at whatever the spur is doing to them while they push — and there is no fail: a bar that
# drains to zero just sits at zero. If nobody pushes, the door's own batter clock gives after
# `corridor.gd:SPUR_SHUT_TIME`. Zero panic. Each bar emits `bar_filled(n)` so the level can
# stage a beat on it.

signal bar_filled(n: int)
signal escaped

const PRESS := 0.10
const DECAY := 0.18
const START := 0.15
const BARS_NEEDED := 3

var _door: Node = null
var _active: bool = false
var _effort: float = START
var _bars: int = 0
var _ui: CanvasLayer = null
var _bar: ColorRect = null
var _label: Label = null
var _shove: AudioStreamPlayer3D = null


func setup(door: Node) -> void:
	_door = door
	if door.has_signal("broken_open"):
		door.broken_open.connect(finish)
	_shove = AudioStreamPlayer3D.new()
	_shove.name = "ShoveSfx"
	var s: AudioStream = GameState.load_audio("locker_shove")
	if s:
		_shove.stream = s
	_shove.unit_size = 6.0
	_shove.volume_db = 2.0
	add_child(_shove)
	if door is Node3D:
		_shove.global_position = (door as Node3D).global_position + Vector3(0, 1.2, 0)


func begin() -> void:
	_active = true
	_effort = START
	_bars = 0
	_build_ui()


func is_active() -> bool:
	return _active


func bars() -> int:
	return _bars


## One shove. Public so a test can drive the shipping path (Input does not work headless).
func press() -> void:
	if not _active:
		return
	_effort += PRESS
	if _shove and _shove.stream:
		_shove.pitch_scale = randf_range(0.9, 1.1)
		_shove.play()
	if _effort >= 1.0:
		_bars += 1
		_effort = START
		bar_filled.emit(_bars)
		if _bars >= BARS_NEEDED:
			_active = false
			_drop_ui()
			escaped.emit()
			if is_instance_valid(_door) and _door.has_method("force_open"):
				_door.force_open()
			return
	_update_ui()


func finish() -> void:
	_active = false
	_drop_ui()


func _process(delta: float) -> void:
	if not _active:
		return
	if Input.is_action_just_pressed("push_effort"):
		press()
		if not _active:
			return
	_effort = maxf(0.0, _effort - DECAY * delta)
	_update_ui()


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 5
	add_child(_ui)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.06, 0.06, 0.05, 0.85)
	bar_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar_bg.offset_top = -95
	bar_bg.offset_bottom = -65
	bar_bg.offset_left = -205
	bar_bg.offset_right = 205
	_ui.add_child(bar_bg)
	_bar = ColorRect.new()
	_bar.color = Color(0.85, 0.66, 0.22, 1.0)
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_bg.add_child(_bar)
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_font_size_override("font_size", 22)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.offset_top = -140
	_label.offset_bottom = -98
	_label.offset_left = -350
	_label.offset_right = 350
	_ui.add_child(_label)
	_update_ui()


func _update_ui() -> void:
	if not _bar or not _label:
		return
	_bar.anchor_right = clampf(_effort, 0.0, 1.0)
	_label.text = "THE DOOR IS SHUT — MASH [SPACE] TO FORCE IT   (%d / %d)" % \
		[mini(_bars + 1, BARS_NEEDED), BARS_NEEDED]


func _drop_ui() -> void:
	if _ui:
		_ui.queue_free()
		_ui = null
		_bar = null
		_label = null
