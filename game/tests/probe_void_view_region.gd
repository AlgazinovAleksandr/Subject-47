extends SceneTree

# THROWAWAY PROBE (2026-09-20 pass 2) — maps the solvable region of each Void viewpoint.
#
# The user's ruling: the tolerances are set FROM A MEASUREMENT, not from a plausible number.
# For each view it sweeps a 0.3 m grid over that view's own tile at eye 1.65 +/- 0.15 m while
# facing the shape +/- 15 degrees, and reports the fraction of samples for which
# `void_alignment.aligned_from()` is true, plus the worst seam error at the tile's centre and
# at its corners. The permanent version of this sweep lives in `check_void_alignment.gd`;
# this file is for iterating on the numbers.
#
#   Godot --headless --path game --script res://tests/probe_void_view_region.gd

const SCENE := "res://scenes/level_3.tscn"
const STEP := 0.30
const EYE_HEIGHTS := [1.50, 1.65, 1.80]
const YAWS := [-15.0, 0.0, 15.0]
const TILE := 1.6

# The tile each viewpoint stands on, and the neighbouring tile centres that are the control.
const TILES := [
	{"size": Vector2(2.0, 2.2), "near": [Vector2(-1.8, 47.0), Vector2(-1.8, 44.0),
		Vector2(-5.6, 47.4), Vector2(-5.6, 43.6)]},
	{"size": Vector2(TILE, TILE), "near": [Vector2(-0.2, 45.5)]},
	{"size": Vector2(TILE, TILE), "near": [Vector2(-1.8, 44.0), Vector2(-5.6, 43.6)]},
]

var _settle := 0
var _done := false


func _process(_d: float) -> bool:
	if _done:
		return true
	_settle += 1
	if _settle == 1:
		change_scene_to_file(SCENE)
		return false
	if _settle < 14:
		return false
	_done = true
	_run()
	quit(0)
	return true


# ⚠️ SYMMETRIC about the tile centre. The first version walked from -half in STEP increments
# and stopped short of +half, so the "worst corner" sample was outside the grid it claimed to
# cover and the two numbers disagreed.
func _offsets(extent: float) -> Array:
	var out: Array = []
	var half: float = extent * 0.5 - 0.10
	var k: int = int(floor(half / STEP + 0.0001))
	for i in range(-k, k + 1):
		out.append(float(i) * STEP)
	return out


func _run() -> void:
	var lvl := current_scene
	var puzzle := lvl.get_node("AlignmentKeystone")
	var views: Array = puzzle.get("VIEWS")
	print("VOID VIEW REGION PROBE — step %.2f m, eye %s, yaw %s deg" % [STEP, EYE_HEIGHTS, YAWS])
	for v in range(views.size()):
		var spec: Dictionary = views[v]
		var feet: Vector3 = spec["feet"]
		var aim: Vector3 = puzzle.call("view_aim", v)
		var size: Vector2 = TILES[v]["size"]
		var xs: Array = _offsets(size.x)
		var zs: Array = _offsets(size.y)
		var total := 0
		var hits := 0
		var cell_total := 0
		var cell_hits := 0
		var worst_centre := 0.0
		var worst_grid := 0.0
		for dx in xs:
			for dz in zs:
				cell_total += 1
				var cell_any := false
				worst_grid = maxf(worst_grid, float(puzzle.call("seam_error", v,
					Vector3(feet.x + dx, 1.65, feet.z + dz))))
				for h in EYE_HEIGHTS:
					var eye := Vector3(feet.x + dx, h, feet.z + dz)
					var base := (aim - eye).normalized()
					for yaw in YAWS:
						var fwd: Vector3 = base.rotated(Vector3.UP, deg_to_rad(yaw))
						total += 1
						if bool(puzzle.call("aligned_from", v, eye, fwd)):
							hits += 1
							cell_any = true
				if cell_any:
					cell_hits += 1
		worst_centre = float(puzzle.call("seam_error", v, Vector3(feet.x, 1.65, feet.z)))
		var corner := Vector3(feet.x + size.x * 0.5 - 0.1, 1.65, feet.z + size.y * 0.5 - 0.1)
		var worst_corner: float = float(puzzle.call("seam_error", v, corner))
		print("  %-7s %3d/%3d samples aligned (%.1f%%)   %2d/%2d grid cells (%.1f%%)"
			% [spec["nm"], hits, total, 100.0 * float(hits) / maxf(1.0, float(total)),
				cell_hits, cell_total, 100.0 * float(cell_hits) / maxf(1.0, float(cell_total))])
		print("          radius %.2f seam %.3f face %.2f | seam error: centre %.4f, corner %.4f, WORST OVER GRID %.4f rad"
			% [spec["radius"], spec["seam"], spec["face"], worst_centre, worst_corner, worst_grid])
		_sweep(puzzle, v, feet, size)
		for n in (TILES[v]["near"] as Array):
			var neye := Vector3(n.x, 1.65, n.y)
			var nf := (aim - neye).normalized()
			var al: bool = bool(puzzle.call("aligned_from", v, neye, nf))
			print("          CONTROL adjacent (%.1f, %.1f) at %.2f m: aligned=%s  seam err %.4f"
				% [n.x, n.y, Vector2(n.x - feet.x, n.y - feet.z).length(), al,
					float(puzzle.call("seam_error", v, neye))])
	# Cross-talk: no shape may align from another shape's tile.
	for v in range(views.size()):
		for w in range(views.size()):
			if v == w:
				continue
			var feet: Vector3 = (views[w] as Dictionary)["feet"]
			var eye := Vector3(feet.x, 1.65, feet.z)
			var fwd := (puzzle.call("view_aim", v) as Vector3 - eye).normalized()
			if bool(puzzle.call("aligned_from", v, eye, fwd)):
				print("  CROSS-TALK: view %s aligns from view %s's tile"
					% [(views[v] as Dictionary)["nm"], (views[w] as Dictionary)["nm"]])
	print("PROBE DONE")


# What grid coverage each candidate seam limit would buy, with the view's radius as configured.
# The ratchet: pick the TIGHTEST limit that still clears the user's 70 % floor.
func _sweep(puzzle: Node, v: int, feet: Vector3, size: Vector2) -> void:
	var errs: Array = []
	var radius: float = float((puzzle.get("VIEWS") as Array)[v]["radius"])
	for dx in _offsets(size.x):
		for dz in _offsets(size.y):
			if Vector2(dx, dz).length() > radius:
				continue
			var worst := 0.0
			for h in EYE_HEIGHTS:
				worst = maxf(worst, float(puzzle.call("seam_error", v,
					Vector3(feet.x + dx, h, feet.z + dz))))
			errs.append(worst)
	var cells: int = _offsets(size.x).size() * _offsets(size.y).size()
	var line := "          seam sweep (cells of %d):" % cells
	for limit in [0.08, 0.10, 0.12, 0.14, 0.16, 0.20, 0.25, 0.30, 0.40]:
		var n := 0
		for e in errs:
			if e <= limit:
				n += 1
		line += "  %.2f=%d%%" % [limit, int(round(100.0 * float(n) / float(cells)))]
	print(line)
