class_name DungeonMapUI
extends CanvasLayer

# ⭐ THE FOUND MAP (2026-09-12, the user's call: "maybe you can find the map and navigate through
# that"). A folded plan picked up in the first chamber; M opens it over the screen WITHOUT
# pausing — the hunter keeps coming while you read. It draws ONLY the rooms the player has walked
# through (fog of war), marks the sconces that are lit, and NEVER shows where the player is. It
# answers "is this new ground", which the 24x24 lattice with a 4.5 m candle made impossible
# (bot: two of six seeds never got past one sconce); it does not answer "where is the next
# sconce", which is still the night's work.
#
# ⚠️ `DUNGEON_NIGHTMARES.md` §B11 rejected DN's GPS minimap as "Issue 34 in the flesh" — a
# trail-drawing map that shows your position solves navigation outright. This one shows the
# rooms you have seen and nothing about you; `tests/check_dungeon_map.gd` greps this file for any
# read of the player's position and fails if it finds one.
#
# Non-pausing on purpose (DN2's rule). Refused while a note is open, the tree is paused, or the
# player is frozen (JournalUI.can_open()'s three guards); closed by a screamer/pause like the
# journal (Issue 9's self-drop). Layer 48, under JournalUI's 49.

const PARCHMENT := "res://assets/textures/level_2_house/house_map_maze_bg.png"
const MAP_PX := 640.0
const INK := Color(0.16, 0.10, 0.06, 0.82)
const INK_LINE := Color(0.10, 0.06, 0.03, 0.95)
const FLAME := Color(0.95, 0.66, 0.22, 1.0)
const CORRIDOR_SHRINK := 0.55   # corridors drawn thinner than chambers, so the plan reads as one

var _gen = null
var _rooms_seen: Array = []
var _lit_positions: Array = []
var _found := false
var _root: Control
var _canvas: MapCanvas
var _hint: Label


class MapCanvas extends Control:
	var gen = null
	var rooms_seen: Array = []
	var lit: Array = []
	var scale_px := 1.0
	var origin := Vector2.ZERO

	func _draw() -> void:
		if gen == null:
			return
		var grid: float = DungeonGen.GRID * DungeonGen.CELL
		scale_px = MAP_PX / grid
		origin = size * 0.5
		for nm in rooms_seen:
			var r: Rect2i = gen.room_rect(nm)
			if r.size == Vector2i.ZERO:
				continue
			var is_corridor: bool = gen.corridor_names.has(nm)
			var x0: float = (r.position.x - DungeonGen.GRID * 0.5) * DungeonGen.CELL
			var z0: float = (r.position.y - DungeonGen.GRID * 0.5) * DungeonGen.CELL
			var w: float = r.size.x * DungeonGen.CELL
			var d: float = r.size.y * DungeonGen.CELL
			var rect := Rect2(origin + Vector2(x0, z0) * scale_px, Vector2(w, d) * scale_px)
			if is_corridor:
				var shrink: float = DungeonGen.CELL * CORRIDOR_SHRINK * 0.5 * scale_px
				if r.size.x >= r.size.y:
					rect = rect.grow_individual(0, -shrink, 0, -shrink)
				else:
					rect = rect.grow_individual(-shrink, 0, -shrink, 0)
			draw_rect(rect, INK, true)
			draw_rect(rect, INK_LINE, false, 2.0)
		for p in lit:
			var v: Vector3 = p
			var at: Vector2 = origin + Vector2(v.x, v.z) * scale_px
			draw_circle(at, 6.0, FLAME)
			draw_circle(at, 9.0, Color(FLAME.r, FLAME.g, FLAME.b, 0.35))


func _ready() -> void:
	layer = 48
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "MapRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)
	var sheet := Control.new()
	sheet.custom_minimum_size = Vector2(MAP_PX + 120, MAP_PX + 120)
	centre.add_child(sheet)
	var bg := TextureRect.new()
	if ResourceLoader.exists(PARCHMENT):
		bg.texture = load(PARCHMENT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.62, 0.56, 0.46, 1.0)   # darkened: it is read by candlelight
	sheet.add_child(bg)
	_canvas = MapCanvas.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(_canvas)
	var title := Label.new()
	title.text = "TRIAL 7 — PLAN OF THE LOWER FLOOR"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.18, 0.11, 0.06))
	title.position = Vector2(40, 22)
	sheet.add_child(title)
	_hint = Label.new()
	_hint.text = "only what you have walked is drawn.  you are not on this map.        [M] close"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.25, 0.16, 0.09))
	_hint.position = Vector2(40, MAP_PX + 80)
	sheet.add_child(_hint)
	_root.visible = false


func setup(gen) -> void:
	_gen = gen
	_canvas.gen = gen


func set_found(found: bool) -> void:
	_found = found


func is_found() -> bool:
	return _found


func is_open() -> bool:
	return _root.visible


# `lit_positions` are the world positions of the lit sconces (never the player's).
func refresh(rooms_seen: Array, lit_positions: Array) -> void:
	_rooms_seen = rooms_seen.duplicate()
	_lit_positions = lit_positions.duplicate()
	_canvas.rooms_seen = _rooms_seen
	_canvas.lit = _lit_positions
	_canvas.queue_redraw()


func drawn_room_count() -> int:
	return _rooms_seen.size()


func can_toggle() -> bool:
	if not _found:
		return false
	if NoteUI.is_open or get_tree().paused:
		return false
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("is_input_frozen") and p.is_input_frozen():
		return false
	return true


func toggle() -> void:
	if _root.visible:
		close()
		return
	if not can_toggle():
		if not _found:
			ScreenText.toast(get_tree(), "YOU HAVE NO MAP", Color(0.8, 0.72, 0.55), 1.4)
		return
	_canvas.queue_redraw()
	_root.visible = true


func close() -> void:
	_root.visible = false


func _process(_delta: float) -> void:
	# Issue 9's self-drop: a screamer pauses the tree from under us; a note opening over the map
	# would leave two overlays. Either way the map goes.
	if _root.visible and (get_tree().paused or NoteUI.is_open):
		close()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
