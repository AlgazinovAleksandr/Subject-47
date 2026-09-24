extends StaticBody3D
class_name HouseMap

# The House's cellar-key quest (new feature, replacing last session's Landing
# 2-drawer search): a folded paper map, currently on a stand in the Bathroom.
# interact() opens the 2D maze-chase minigame (maze_chase_ui.gd) as a paused
# full-screen overlay. ⚠️ Since 2026-08-16 that minigame is TWO-STAGE — collect every torn
# fragment of the map, THEN escape to the mark — so a single attempt is roughly three times
# longer than it was, and this prop's `caught` handler is the only thing standing between the
# player and a much longer exposure to the hunter. Nothing here needed to change for it: a
# catch still costs CATCH_PANIC once, still ejects to 3D, and still leaves the map
# interactable for a retry with a different curated layout. Fragments already collected are lost with
# the attempt — there is deliberately no partial-progress carry-over.
# Winning it pops a "Collect the key." toast, frees this
# prop, and emits `won` — the level (level_2.gd) reacts by spawning the real 3D
# key at this exact spot. Getting caught by the maze's monster is handled
# entirely here — a jolt + a one-time panic hit, then the map is interactable
# again for a retry (a new curated layout is dealt for every genuine attempt — a win or a
# catch; never the same one twice in a row. Putting the map DOWN and picking it up again
# resumes the same maze; see `maze_chase_ui.gd:_instance_live` for why ESC used to be a free
# re-roll). ⭐ Since 2026-09-24 (e) the catch's panic is clamped below the bar and the THIRD
# catch in a row is the map's one death — see CATCH_STREAK_FATAL.

const _NOTE_SCRIPT := preload("res://scripts/note.gd")

# Bracketed between beartrap.gd's ESCAPE_INITIAL_PANIC (15, a clean single fail)
# and ESCAPE_FAIL_PANIC (40, a true multi-attempt QTE fail) — a maze catch is a
# single clean fail-and-retry, but ejects the player entirely rather than
# offering an escape window, so it sits just above the lighter of those two.
const CATCH_PANIC := 18.0

# ⭐⭐ THE MAP'S ONE DEATH: THE THIRD CATCH IN A ROW (2026-09-24 e, the user's call — capture #1:
# *"there can be no way you die from the level screamer while you are still playing the game.
# Only after you lost it several times in a row from the monster"*). The map's panic is clamped
# below PANIC_MAX (`MazeChaseUI.add_map_panic`), so this count is the only way it kills.
#   * a catch        → +1; the 3rd fires `Screamer.trigger()`, the House's death and restart;
#   * a win          → back to 0 (the prop is freed on a win anyway; reset for the record);
#   * ESC / a close  → not an attempt, no change;
#   * a level restart→ 0, because the level rebuilds this prop.
# ⚠️ 3 is the user's number, not a tuning dial — changing it is the user's call.
const CATCH_STREAK_FATAL := 3

signal won

var _solved: bool = false
var _ui: MazeChaseUI
var _catch_streak: int = 0


func _ready() -> void:
	_style_mesh()
	_ui = MazeChaseUI.new()
	_ui.won.connect(_on_won)
	_ui.caught.connect(_on_caught)
	add_child(_ui)


func _style_mesh() -> void:
	var mesh := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.3, 0.24)
	mesh.mesh = qm
	mesh.rotation = Vector3(-PI / 2.0, 0, 0)  # lie flat, face up, same as the key
	mesh.set_surface_override_material(0, _NOTE_SCRIPT.paper_material(false))
	add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.34, 0.1, 0.28)
	col.shape = shape
	add_child(col)


func interact() -> void:
	if _solved:
		ScreenText.toast(get_tree(), "Already found it.", Color(0.75, 0.75, 0.75))
		return
	_ui.open()


func _on_won() -> void:
	_solved = true
	_catch_streak = 0
	_log("MAP won (catch streak reset)")
	# Playtest: on a win, pop a clear "go get it" message, and the map itself
	# should vanish rather than linger as a solved-but-still-there prop — the
	# level spawns the real key at this exact spot once the map is gone.
	# H3 (2026-09-16, capture #3): the key's own pickup label is centred, so this line takes
	# the LOWER caption slot — the two were printed on top of each other.
	ScreenText.caption(get_tree(), "Collect the key.", 3.0, Color(0.4, 1.0, 0.4))
	won.emit()
	queue_free()


func _on_caught() -> void:
	_catch_streak += 1
	_log("MAP caught (streak %d/%d)" % [_catch_streak, CATCH_STREAK_FATAL])
	if _catch_streak >= CATCH_STREAK_FATAL:
		Screamer.trigger()
		return
	var p := get_tree().current_scene.get_node_or_null("Player")
	if p and p.has_method("jolt_camera"):
		p.jolt_camera(0.09, 0.45)
	# Clamped like every other map panic write: a catch at 45 % panic used to be a death.
	MazeChaseUI.add_map_panic(p, CATCH_PANIC)


func _log(msg: String) -> void:
	var dbg := get_node_or_null("/root/DebugLog")
	if dbg and dbg.has_method("note"):
		dbg.note(msg)
