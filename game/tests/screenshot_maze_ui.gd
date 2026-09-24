extends SceneTree

# Dev tool: open the House's map-and-chase minigame and dump a screenshot of it — since
# 2026-09-24 (e), one per CURATED layout (`MazeChaseUI.CURATED_SEEDS`), plus a 4x3 sheet.
#
# Run (note: NO --headless, it needs a render target):
#   Godot --path game --script res://tests/screenshot_maze_ui.gd
# Writes /tmp/shots/house_maze_ui.png (the first board, the historical name),
#        /tmp/shots/house_maze_<seed>.png for each of the twelve, and
#        /tmp/shots/house_maze_sheet.png (all twelve, 4x3, in CURATED_SEEDS order).
#
# The existing screenshot_scene.gd harness can only teleport the player and aim a
# camera, so it can never reach this UI — the minigame is behind an interact() call
# on the Bathroom map prop. Its legibility was a confirmed playtest finding (capture
# #3: "the text is not clearly visible, as well as the icons — they are too small"),
# and legibility is exactly the kind of fix that cannot be asserted, so it needs an
# eyeball. This drives the real interaction path rather than instancing MazeChaseUI
# on its own, so what lands in the shot is what a player actually sees. Each layout is
# loaded with the UI's own `_load_layout()` (what `open()` does on a new attempt), then
# `interact()` opens it exactly as a player would.

const OUT := "/tmp/shots/"
const SETTLE := 20            # frames between opening a board and shooting it
const SHEET_COLS := 4
const THUMB_W := 768

var _frame := 0
var _map: Node = null
var _ui: Node = null
var _seeds: Array = []
var _i := 0
var _opened_at := -1
var _shots: Array[Image] = []


func _initialize() -> void:
	change_scene_to_file("res://scenes/level_2_1.tscn")


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 8:
		_map = _find_map(current_scene)
		if not _map:
			print("FAIL: no HouseMap prop found in the level")
			quit(1)
			return true
		_ui = _map.get("_ui")
		_seeds = (_ui.get_script() as Script).get("CURATED_SEEDS")
		if _seeds.is_empty():
			print("FAIL: CURATED_SEEDS is empty")
			quit(1)
			return true
		DirAccess.make_dir_recursive_absolute(OUT)
	elif _frame > 8 and _opened_at < 0 and _i < _seeds.size():
		_ui.call("_load_layout", int(_seeds[_i]))
		_map.interact()
		_opened_at = _frame
	elif _opened_at >= 0 and _frame - _opened_at == SETTLE:
		var img := get_root().get_texture().get_image()
		var s: int = int(_seeds[_i])
		img.save_png(OUT + "house_maze_%d.png" % s)
		if _i == 0:
			img.save_png(OUT + "house_maze_ui.png")
		print("shot: house_maze_%d  (%d/%d)" % [s, _i + 1, _seeds.size()])
		_shots.append(img)
		_ui.call("_close")
		_opened_at = -1
		_i += 1
		if _i >= _seeds.size():
			_save_sheet()
			quit(0)
			return true
	return false


func _save_sheet() -> void:
	var w0: int = _shots[0].get_width()
	var h0: int = _shots[0].get_height()
	var th: int = int(round(float(THUMB_W) * float(h0) / float(w0)))
	var rows: int = int(ceil(float(_shots.size()) / float(SHEET_COLS)))
	var sheet := Image.create(THUMB_W * SHEET_COLS, th * rows, false, Image.FORMAT_RGBA8)
	for i in _shots.size():
		var t: Image = _shots[i].duplicate()
		t.convert(Image.FORMAT_RGBA8)
		t.resize(THUMB_W, th, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(t, Rect2i(0, 0, THUMB_W, th),
			Vector2i((i % SHEET_COLS) * THUMB_W, (i / SHEET_COLS) * th))
	sheet.save_png(OUT + "house_maze_sheet.png")
	print("sheet: house_maze_sheet (%dx%d)" % [sheet.get_width(), sheet.get_height()])


func _find_map(n: Node) -> Node:
	# Duck-typed on the `won` signal rather than `is HouseMap`: naming a game class
	# in a SceneTree script compiles it before the autoloads exist, which is how
	# walk_lab_wing.gd once broke the very level it was measuring.
	if n.has_signal("won") and n.has_method("interact"):
		return n
	for c in n.get_children():
		var found := _find_map(c)
		if found:
			return found
	return null
