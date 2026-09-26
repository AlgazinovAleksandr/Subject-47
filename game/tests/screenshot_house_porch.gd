extends SceneTree

# THE PORCH PASS, PHOTOGRAPHED AND MEASURED (2026-09-24). Needs a render target — run WITHOUT
# --headless:
#   /Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/screenshot_house_porch.gd
#
# Writes /tmp/house_porch/*.png and prints the INTERIOR DARKNESS measurement the spec demands:
# the house stays at ambient 0.0 with the moon and the sky dome in the scene. Each interior pose
# is captured with the moon ON and with it OFF (and the dome hidden), torch off, and the brightest
# pixel of each is compared — "measure darkness as contrast", the frame's max, never its mean.

const OUT := "/tmp/house_porch/"

var _p: CharacterBody3D = null
var _l: Node = null
var _t := 0.0
var _i := 0
var _shots: Array = []
var _results: Array = []


func _initialize() -> void:
	seed(7)
	DirAccess.make_dir_recursive_absolute(OUT)
	change_scene_to_file("res://scenes/level_2_1.tscn")


func _stand(pos: Vector3, look: Vector3) -> void:
	_p.set("velocity", Vector3.ZERO)
	_p.global_position = pos
	_p.call("ai_look_at", look)


func _grab(n: String) -> Image:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(OUT + n + ".png")
	print("wrote ", n)
	return img


# Max and mean luminance of a frame, 0..255, sampled on a grid (a thin bright edge counts).
# ⚠️ The top 8 % and the centre dot are skipped: the objective line is HUD text, and at 178/255 it was the brightest
# thing in every frame, moon or no moon — the first run of this file measured the HUD.
func _lum(img: Image) -> Vector2:
	var mx := 0.0
	var sum := 0.0
	var n := 0
	var w := img.get_width()
	var h := img.get_height()
	for y in range(int(h * 0.08), h, 3):
		for x in range(0, w, 3):
			if absi(x - w / 2) < 30 and absi(y - h / 2) < 40:
				continue     # the crosshair dot — also HUD
			var c := img.get_pixel(x, y)
			var l := (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) * 255.0
			mx = maxf(mx, l)
			sum += l
			n += 1
	return Vector2(mx, sum / maxf(1.0, float(n)))


# The moon's CONTRIBUTION: the largest per-pixel luminance difference between the same pose with
# the moon (and dome) on and off. Zero on an interior surface means no moonlight reached it.
#
# ⚠️ The WINDOW OPENING is masked out: through it you are looking at the moonlit porch, which is
# outdoors and is supposed to differ. `_opening_rect()` projects the opening's corners with the
# camera — ⚠️ in VIEWPORT coordinates, scaled up to the rendered image (1152x648 vs 3024x1701 on
# this machine: CLAUDE.md's unproject_position warning).
func _diff(a: Image, b: Image, mask: Rect2) -> float:
	var mx := 0.0
	var h := mini(a.get_height(), b.get_height())
	var w := mini(a.get_width(), b.get_width())
	for y in range(int(h * 0.08), h, 3):
		for x in range(0, w, 3):
			if mask.has_point(Vector2(x, y)):
				continue
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var la := 0.299 * ca.r + 0.587 * ca.g + 0.114 * ca.b
			var lb := 0.299 * cb.r + 0.587 * cb.g + 0.114 * cb.b
			mx = maxf(mx, absf(la - lb) * 255.0)
	return mx


var _imgs: Dictionary = {}
var _masks: Dictionary = {}


func _opening_rect(img: Image) -> Rect2:
	var cam := _p.get_node("Camera3D") as Camera3D
	var vp := root.get_viewport().get_visible_rect().size
	var sx := float(img.get_width()) / vp.x
	var sy := float(img.get_height()) / vp.y
	var r := Rect2()
	var first := true
	for c in [Vector3(-8.5, 0.0, 5.3), Vector3(-8.5, 0.0, 6.7), Vector3(-8.5, 2.3, 5.3), Vector3(-8.5, 2.3, 6.7),
			Vector3(-8.7, 0.0, 5.3), Vector3(-8.7, 2.3, 6.7), Vector3(-8.7, 0.0, 6.7), Vector3(-8.7, 2.3, 5.3)]:
		if cam.is_position_behind(c):
			continue
		var q := cam.unproject_position(c)
		var pt := Vector2(q.x * sx, q.y * sy)
		if first:
			r = Rect2(pt, Vector2.ZERO)
			first = false
		else:
			r = r.expand(pt)
	return r.grow(12.0) if not first else Rect2()


func _moon(on: bool) -> void:
	var o := _l.get_node("HouseOutdoors")
	(o.get_node("Moonlight") as DirectionalLight3D).visible = on
	(o.get_node("SkyDome") as MeshInstance3D).visible = on


func _process(delta: float) -> bool:
	_t += delta
	if _l == null:
		if _t < 1.6:
			return false
		_l = current_scene
		_p = _l.get_node("Player")
		_p.set_physics_process(false)
		_build_plan()
		_t = 0.0
		return false
	if _i >= _shots.size():
		print("")
		print("--- INTERIOR DARKNESS (torch off; brightest pixel / mean, 0..255) ---")
		for r in _results:
			print(r)
		for pose in ["d_living_floor", "d_living_north", "d_bedroom", "d_hallway"]:
			if _imgs.has(pose + "_moon_on") and _imgs.has(pose + "_moon_off"):
				var mk: Rect2 = _masks[pose + "_moon_on"]
				print("%-20s moon contribution, max per-pixel diff: whole frame %.2f · outside the window opening %.2f  (mask %s)"
					% [pose, _diff(_imgs[pose + "_moon_on"], _imgs[pose + "_moon_off"], Rect2()),
						_diff(_imgs[pose + "_moon_on"], _imgs[pose + "_moon_off"], mk), mk])
		quit(0)
		return true
	var s: Array = _shots[_i]
	if _t < 0.05:
		return false
	if not bool(s[3]):
		# The forest clock charges while shots are taken out among the trees, and the panic HUD's
		# red blur would then be in every later frame. Photographs, not a playthrough.
		_p.set("_panic", 0.0)
		var c: Callable = s[2]
		c.call()
		s[3] = true
		_t = 0.0
		return false
	if _t < float(s[1]):
		return false
	_p.set("_panic", 0.0)
	var img := _grab(String(s[0]))
	if s.size() > 4:
		var m := _lum(img)
		_imgs[String(s[0])] = img
		_masks[String(s[0])] = _opening_rect(img)
		_results.append("%-28s max %6.2f  mean %6.3f" % [s[0], m.x, m.y])
	_i += 1
	_t = 0.0
	return false


# [name, settle seconds, setup callable, done-flag, measure?]
func _build_plan() -> void:
	# No scrawl over the porch shots, and no random apparition wandering into a frame.
	_l.set("_porch_visited", true)
	# ⚠️ And the level's random blackout clock (+4 panic at 24–44 s): with the player's physics
	# off here, `add_panic()` pushes the HUD's red blur and nothing ever pulls it back, so every
	# frame after ~30 s was blurred (26/27 on 2026-09-24 d — measured, the witch adds 0).
	_l.set("_blackout_clock", 99999.0)
	var dir := _l.get_node_or_null("ApparitionDirector")
	if dir:
		dir.queue_free()
	var torch_off := func() -> void: _p.call("force_flashlight_off")
	# force_flashlight_off() NESTS (it counts depth), and the loop below calls it once per moon
	# setting — so the torch comes back with as many restores as there were forces.
	var torch_on := func() -> void:
		_p.call("restore_flashlight")
		_p.call("restore_flashlight")
	# --- interior darkness: the living room and a closed room, moon on vs off ---
	for moon in [true, false]:
		var tag := "moon_on" if moon else "moon_off"
		_shots.append(["d_living_floor_" + tag, 0.4, func() -> void:
			torch_off.call(); _moon(moon)
			_stand(Vector3(-4.0, 0.1, 6.0), Vector3(-8.0, 0.0, 7.5)), false, true])
		_shots.append(["d_living_north_" + tag, 0.4, func() -> void:
			_stand(Vector3(-5.0, 0.1, 5.0), Vector3(-6.0, 1.2, 9.0)), false, true])
		_shots.append(["d_bedroom_" + tag, 0.4, func() -> void:
			_stand(Vector3(-6.0, 0.1, 12.5), Vector3(-9.0, 1.0, 12.5)), false, true])
		_shots.append(["d_hallway_" + tag, 0.4, func() -> void:
			_stand(Vector3(0.0, 0.1, 4.0), Vector3(0.0, 1.2, 10.0)), false, true])
	_shots.append(["00_restore", 0.2, func() -> void: _moon(true); torch_on.call(), false])
	# --- the window, before ---
	_shots.append(["01_window_from_room", 0.5, func() -> void:
		_stand(Vector3(-4.2, 0.1, 6.0), Vector3(-9.0, 1.2, 6.0)), false])
	_shots.append(["02_window_close", 0.5, func() -> void:
		_stand(Vector3(-6.9, 0.1, 6.2), Vector3(-9.0, 1.3, 6.0)), false])
	# --- burst it, then the porch ---
	_shots.append(["03_window_burst", 0.9, func() -> void:
		_l.get_node("HouseWindow").call("break_pane", true)
		_stand(Vector3(-5.8, 0.1, 6.0), Vector3(-9.0, 1.0, 6.0)), false])
	_shots.append(["04_porch_from_room", 0.5, func() -> void:
		_stand(Vector3(-6.0, 0.1, 5.6), Vector3(-11.0, 1.0, 7.4)), false])
	# ⭐ 2026-09-24 (c): the frame is BLADELESS until the blade comes back from the forest.
	_shots.append(["05a_bladeless_from_window", 0.5, func() -> void:
		_stand(Vector3(-8.2, 0.1, 5.4), Vector3(-10.35, 1.3, 7.75)), false])
	_shots.append(["05_guillotine", 0.5, func() -> void:
		_stand(Vector3(-9.1, 0.1, 6.3), Vector3(-10.35, 0.9, 7.75)), false])
	_shots.append(["06_porch_to_yard", 0.5, func() -> void:
		_stand(Vector3(-9.2, 0.1, 5.2), Vector3(-20.0, 1.4, 6.0)), false])
	_shots.append(["07_forest_west", 0.6, func() -> void:
		_stand(Vector3(-19.0, 0.1, 6.0), Vector3(-30.0, 2.0, 5.0)), false])
	_shots.append(["08_forest_back_to_house", 0.6, func() -> void:
		_stand(Vector3(-22.0, 0.1, 6.5), Vector3(-9.0, 1.6, 6.0)), false])
	_shots.append(["09_forest_moon", 0.6, func() -> void:
		_stand(Vector3(-15.0, 0.1, 6.0), Vector3(-40.0, 14.0, -2.0)), false])
	# --- a ghost mid-run ---
	_shots.append(["10_ghost_woman", 0.9, func() -> void:
		_stand(Vector3(-16.0, 0.1, 6.0), Vector3(-26.0, 1.2, 6.0))
		_l.call("_spawn_ghost", 0, Vector3(-26.0, 0, 1.5), Vector3(-26.0, 0, 11.0), _p), false])
	_shots.append(["11_ghost_crawler", 0.8, func() -> void:
		_l.call("_spawn_ghost", 1, Vector3(-25.0, 0, 11.0), Vector3(-25.0, 0, 0.0), _p), false])
	_shots.append(["12_ghost_tall", 1.2, func() -> void:
		_l.call("_spawn_ghost", 2, Vector3(-32.0, 0, 2.0), Vector3(-32.0, 0, 10.0), _p), false])
	# --- ⭐ 2026-09-24 (c): the clearing and the stump with the blade in it ---
	# ⭐⭐ (d): the stump is in the FAR NORTH-WEST CORNER behind one thick trunk (HIDE_TRUNK, to its
	# south-east). The close poses stand on the side AWAY from that trunk; the 22_* poses stand on
	# the two sightlines the trunk is there to cut.
	var stump_at := Vector3(HouseOutdoors.BLADE_CLEARING.x, 0.0, HouseOutdoors.BLADE_CLEARING.y)
	_shots.append(["20_stump_torch_4m", 0.6, func() -> void:
		_stand(stump_at + Vector3(3.6, 0.1, 1.6), stump_at + Vector3(0, 0.55, 0)), false])
	_shots.append(["21_stump_moon_only", 0.5, func() -> void:
		_p.call("force_flashlight_off"), false])
	_shots.append(["22a_trunk_hides_it_7m_on_the_rail_gap_line", 0.6, func() -> void:
		_p.call("restore_flashlight")
		var u := Vector3(-12.0 - stump_at.x, 0.0, 6.0 - stump_at.z).normalized()
		_stand(stump_at + u * 7.0 + Vector3(0, 0.1, 0), stump_at + Vector3(0, 0.6, 0)), false])
	_shots.append(["22b_from_the_forest_middle", 0.6, func() -> void:
		_stand(Vector3(-26.0, 0.1, 6.0), stump_at + Vector3(0, 0.6, 0)), false])
	_shots.append(["22c_from_the_rail_gap", 0.6, func() -> void:
		_stand(Vector3(-12.3, 0.1, 6.0), stump_at + Vector3(0, 0.6, 0)), false])
	_shots.append(["23_stump_close", 0.5, func() -> void:
		_stand(stump_at + Vector3(0.9, 0.1, 1.5), stump_at + Vector3(0, 0.5, 0)), false])
	_shots.append(["24_stump_pulled", 0.6, func() -> void:
		_l.get_node("BladeStump").call("interact"), false])
	# --- the painting down, the hole, the fruit ---
	_shots.append(["13_painting_hole", 0.9, func() -> void:
		_l.call("_force_painting_down")
		_stand(Vector3(0.85, 0.1, 17.0), Vector3(0.85, 1.5, 19.0)), false])
	_shots.append(["14_hole_close", 0.4, func() -> void:
		_stand(Vector3(0.7, 0.1, 17.9), Vector3(0.85, 1.35, 19.0)), false])
	# --- the guillotine loaded, then cut ---
	# Blade mounted and fruit set, by the level's own restore path (the mount tween would hold
	# `_busy` through a second interact on the same frame).
	_shots.append(["15_guillotine_loaded", 0.6, func() -> void:
		var g := _l.get_node("Guillotine")
		g.call("restore", "placed", false, true)
		g.set("blade_in_hand", false)
		_l.set("_blade_state", "mounted")
		_l.set("_melon_state", "placed")
		_l.call("_refresh_carried")
		_stand(Vector3(-9.3, 0.1, 6.6), Vector3(-10.35, 0.7, 7.75)), false])
	_shots.append(["16_guillotine_cut", 1.4, func() -> void:
		_l.get_node("Guillotine").call("interact"), false])
	# ⭐ 2026-09-24 (c): no basket — the cutters and one half on the deck boards.
	_shots.append(["17_cutters_on_deck", 0.4, func() -> void:
		var c := _l.get_node("Guillotine").call("cutters_node") as Node3D
		_stand(Vector3(-9.2, 0.1, 6.6), c.global_position if c else Vector3(-9.9, 0.1, 7.35)), false])
	# --- the witch, on the tree line ---
	_shots.append(["18_witch_tree_line", 0.6, func() -> void:
		_stand(Vector3(-11.0, 0.1, 6.0), Vector3(-18.0, 1.0, 7.0))
		# The guillotine shot above already fired glimpse 3 on its own; only stage a figure if the
		# level did not, or the frame shows two witches (it did, 2026-09-24).
		var have := false
		for c in _l.get_children():
			if c is Watcher:
				have = true
		if not have:
			var w := Watcher.spawn(_l, Vector3(-18.0, 0, 7.0), "res://assets/textures/level_2_house/house_witch.png", 0.0, true, 1.65)
			print("witch spawned by the driver: ", w != null)
		else:
			print("witch already on the tree line (glimpse 3)"), false])
	_shots.append(["19_witch_note_table", 0.5, func() -> void:
		_stand(Vector3(0.0, 0.1, -2.0), Vector3(1.1, 0.8, -0.6)), false])
	# --- ⭐⭐ 2026-09-24 (d): the witch SEEN in the house ---
	# A: standing where SafeNote_First is read, facing it; the level's own "the note was closed"
	# path stages her, turns the camera and holds — captured mid-hold (turn 0.45 s, hold 1.5 s).
	_shots.append(["25_witch_a_bedroom_doorway", 1.3, func() -> void:
		for c in _l.get_children():
			if c is Watcher:
				c.queue_free()       # the tree-line figure from 18
		var n1 := _l.get_node("SafeNote_First") as Node3D
		_stand(Vector3(-7.0, 0.1, n1.global_position.z - 1.6), n1.global_position)
		_l.call("_on_first_note_closed"), false])
	_shots.append(["25b_after_release", 1.6, func() -> void: pass, false])
	# B: the 8-minute sighting, the timer hooked to now, in the Hallway facing north.
	_shots.append(["26_witch_b_behind_in_hallway", 1.5, func() -> void:
		# z 9.8: clear of the Hallway's footsteps-overhead trigger box (z 7.25–8.75, +6 panic) — at
		# z 9.0 the capsule entered it and the panic HUD blurred the frame (measured: B itself adds 0).
		_stand(Vector3(0.0, 0.1, 9.8), Vector3(0.0, 1.4, 14.0))
		_l.set("witch_b_after", 0.0), false])
	# The mounted blade's art, close, in the frame (the loaded/cut shots above show it at 1.5 m).
	_shots.append(["27_blade_art_in_frame", 0.5, func() -> void:
		_stand(Vector3(-9.6, 0.1, 6.9), Vector3(-10.35, 0.85, 7.75)), false])
