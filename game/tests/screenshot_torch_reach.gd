extends SceneTree

# HOW FAR CAN YOU SEE, AND WITH THE TORCH OFF, HOW MUCH?
#
#   ⚠️ RUN WITHOUT --headless. It needs a render target.
#   /Applications/Godot.app/Contents/MacOS/Godot --path game \
#       --script res://tests/screenshot_torch_reach.gd
#
# Writes to /tmp/torch_reach/ and prints a contrast table.
#
# ⚠️ THIS IS THE ONLY THING THAT CAN ANSWER PART 4. The darkness change is ambient 0.02 -> 0.0
# plus an 11 m / 24 deg beam in the Lab and the House, and NO headless guard can tell you whether
# the result is atmospheric or unplayable: `check_reachable.gd`, `walk_cellar.gd` and
# `autoplay_house_route.gd` are all physics-only and walk a black room exactly as fast as a lit
# one. `check_darkness.gd` asserts the numbers. This measures the picture.
#
# ⚠️ CONTRAST, NEVER AN ABSOLUTE LEVEL — ISSUES_SOLUTIONS Issue 62, which this project got wrong
# twice on the same prop. "Peak 1.5 of 255, therefore invisible" is false when the background is
# literally 0.0000: against nothing, 1.5 is the only thing in the frame. Every row below is the
# prop's own screen rectangle measured against a RING of the surface around it.
#
# ⚠️ THE `peak` COLUMN IS CONTAMINATED AND THE `mean` IS NOT. The crosshair is a white `Label` at
# alpha 0.7 dead centre of the screen — luminance exactly **0.698** — and the prop's bounding box
# is centred on it by construction, so every torch-off row reports `peak 0.6980` while its mean
# reads 0.0000. Read the MEAN and the RATIO; the peak is there to catch a blown-out surface, and
# 0.698 exactly is the tell that you are looking at the reticle.
#
# ⚠️ AND THE COORDINATE SPACES DIFFER. `unproject_position()` returns VIEWPORT coordinates while
# `get_image()` returns the RENDERED image — 1152x648 against 3024x1701 on this machine. Mixing
# them measures the wrong part of the frame and reports it confidently. Everything is scaled.

const OUT := "/tmp/torch_reach/"
const SETTLE := 3.2
# ⚠️ Domestic distances. The first ladder was 3/6/9/12/15 and most rows came back "no room" —
# measured clear space in front of these props is 5.3 m (the Records locker), 5.9 m (the cellar
# gate), 10.4 m (an exam table). A 15 m row in a 6 m room photographs masonry.
const DISTANCES := [2.0, 3.0, 4.5, 6.0, 8.0, 11.0]

# Per scene: the props to walk up to. Chosen because each is something the player MUST find —
# the House's cellar gate is also the Part 3 verification (its planks were 1.5 m too high and it
# read as a blank slab), and a note is the class of object the whole emissive pass is about.
const TARGETS := {
	"res://scenes/level_1.tscn": {
		"name": "Lab",
		"props": ["RecordsLocker", "ExamTable", "Breaker_Exam1"],
	},
	"res://scenes/level_2_1.tscn": {
		"name": "House",
		"props": ["CellarGate", "KitchenTable", "MusicBox"],
	},
	# ⚠️ The Breach is NOT a darkened level — it runs at ambient 0.28 — and is here for a
	# different question: after the 2026-09-07 door pass, do its four door families read as one
	# set? The contrast columns are meaningless at this ambient; the PICTURES are the point.
	"res://scenes/level_6_breach.tscn": {
		"name": "Breach",
		"props": ["ExitDoor", "Slam_Corridor1_Junction1", "PurgeChamber", "Casing_0_17"],
	},
}

var _t := 0.0
var _armed := false
var _q: Array = []
var _phase := 0
var _prop_i := 0
var _dist_i := 0
var _torch := true
var _level: Node = null
var _player: CharacterBody3D = null
var _props: Array = []
var _rows: Array = []
var _clear_run := 0.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_q = TARGETS.keys()
	seed(7)
	change_scene_to_file(String(_q[0]))


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


# Find each named prop (prefix match — several are suffixed with coordinates).
func _collect_props(names: Array) -> Array:
	var nodes: Array = []
	_all(_level, nodes)
	var out: Array = []
	for want in names:
		for x in nodes:
			if x is Node3D and String(x.name).begins_with(String(want)):
				out.append(x)
				break
	return out


# The union of a node's own meshes, in world space.
func _world_aabb(n: Node3D) -> AABB:
	var nodes: Array = []
	_all(n, nodes)
	var box := AABB()
	var first := true
	for x in nodes:
		if not (x is MeshInstance3D) or (x as MeshInstance3D).mesh == null:
			continue
		var mi := x as MeshInstance3D
		var local: AABB = mi.get_aabb()
		var t := mi.global_transform
		for i in range(8):
			var p: Vector3 = t * (local.position + local.size * Vector3(
				float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1)))
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box


# Which of the four horizontal axes has the most clear space in front of the prop? Rays from the
# prop's own centre at eye height; the longest unobstructed run wins.
func _clearest_dir(centre: Vector3) -> Vector3:
	var space := _player.get_world_3d().direct_space_state
	var best := Vector3(0, 0, 1)
	var best_d := -1.0
	_clear_run = 0.0
	for dir in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		var from := Vector3(centre.x, 1.5, centre.z)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 18.0)
		q.collision_mask = 1
		q.exclude = [_player.get_rid()]
		var hit := space.intersect_ray(q)
		var reach: float = 18.0 if hit.is_empty() \
			else from.distance_to(hit["position"] as Vector3)
		if reach > best_d:
			best_d = reach
			best = dir
	_clear_run = best_d
	return best


func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


# Sample the prop's screen rectangle and a ring around it. Returns
# {prop_mean, prop_max, ring_mean, px}.
func _measure(img: Image, cam: Camera3D, box: AABB) -> Dictionary:
	var vp: Vector2 = cam.get_viewport().get_visible_rect().size
	var scale := Vector2(float(img.get_width()) / vp.x, float(img.get_height()) / vp.y)
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for i in range(8):
		var w: Vector3 = box.position + box.size * Vector3(
			float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1))
		if cam.is_position_behind(w):
			return {}
		var sp: Vector2 = cam.unproject_position(w) * scale
		lo = Vector2(minf(lo.x, sp.x), minf(lo.y, sp.y))
		hi = Vector2(maxf(hi.x, sp.x), maxf(hi.y, sp.y))
	var x0 := int(clampf(lo.x, 0, img.get_width() - 1))
	var x1 := int(clampf(hi.x, 0, img.get_width() - 1))
	var y0 := int(clampf(lo.y, 0, img.get_height() - 1))
	var y1 := int(clampf(hi.y, 0, img.get_height() - 1))
	if x1 - x0 < 2 or y1 - y0 < 2:
		return {}
	var pm := 0.0
	var pk := 0.0
	var pn := 0
	for y in range(y0, y1 + 1, 2):
		for x in range(x0, x1 + 1, 2):
			var l := _lum(img.get_pixel(x, y))
			pm += l
			pk = maxf(pk, l)
			pn += 1
	# The ring: a band of the same thickness outside the box, which is the wall behind it.
	var pad := maxi(8, int((x1 - x0) * 0.35))
	var rm := 0.0
	var rn := 0
	for y in range(maxi(0, y0 - pad), mini(img.get_height() - 1, y1 + pad) + 1, 3):
		for x in range(maxi(0, x0 - pad), mini(img.get_width() - 1, x1 + pad) + 1, 3):
			if x >= x0 and x <= x1 and y >= y0 and y <= y1:
				continue
			rm += _lum(img.get_pixel(x, y))
			rn += 1
	if pn == 0 or rn == 0:
		return {}
	return {"prop_mean": pm / pn, "prop_max": pk, "ring_mean": rm / rn, "px": pn}


func _process(delta: float) -> bool:
	_t += delta
	if _t < SETTLE or current_scene == null:
		return false
	if _level == null:
		_level = current_scene
		_player = _level.get_node_or_null("Player") as CharacterBody3D
		var cfg: Dictionary = TARGETS[String(_q[_phase])]
		_props = _collect_props(cfg["props"])
		print("\n=== %s: %d of %d target props found ==="
			% [cfg["name"], _props.size(), (cfg["props"] as Array).size()])
		for p in _props:
			print("    %s" % String((p as Node3D).name))

	if _prop_i >= _props.size():
		_phase += 1
		if _phase >= _q.size():
			_report()
			quit(0)
			return true
		_level = null
		_props = []
		_prop_i = 0
		_dist_i = 0
		_torch = true
		_armed = false
		_t = 0.0
		seed(7)
		change_scene_to_file(String(_q[_phase]))
		return false

	var prop := _props[_prop_i] as Node3D
	var box := _world_aabb(prop)
	var centre: Vector3 = box.position + box.size * 0.5
	var cam := _player.get_node_or_null("Camera3D") as Camera3D

	# ⚠️ SET THIS FRAME, CAPTURE NEXT. The frame is already submitted by the time _process runs.
	if not _armed:
		var d: float = DISTANCES[_dist_i]
		# ⚠️ BACK OFF ALONG WHICHEVER AXIS ACTUALLY HAS ROOM, measured. The first version used the
		# prop's own local -Z, which for the CellarGate is INSIDE the ramp shaft: its decorated
		# face points +Z, toward the kitchen the player approaches from. A prop's "front" is not
		# recoverable from its transform in this project — half of these are built from parts with
		# no consistent facing — so the honest answer is to ask the physics where the open space
		# is rather than to assume.
		var away := _clearest_dir(centre)
		# ⚠️ And do not stand inside the far wall. A 15 m row in a 6 m room measures masonry and
		# reports it as "the prop is invisible", which is a true statement about nothing.
		if d > _clear_run - 0.8:
			print("  %-46s (no room: only %.1f m of clear space)"
				% [String(prop.name) + " @ %.0fm" % d, _clear_run])
			_armed = false
			_torch = true
			_dist_i += 1
			if _dist_i >= DISTANCES.size():
				_dist_i = 0
				_prop_i += 1
			return false
		var eye := centre + away * d
		eye.y = 0.1
		_player.global_position = eye
		# ⚠️ NO `+= PI` HERE. `Node3D.look_at()` already points the node's **-Z** at the target,
		# and the player's forward IS -Z — so the "player forward is -Z, therefore add PI"
		# reflex (correct when you have computed a yaw with `atan2` yourself) turns the camera
		# 180 degrees AWAY. Measured: every single row read "(off screen)".
		_player.look_at(Vector3(centre.x, eye.y + 1.65, centre.z), Vector3.UP)
		_player.rotation.x = 0.0
		_player.rotation.z = 0.0
		if cam:
			cam.rotation.x = clampf(atan2(centre.y - (eye.y + 1.65), d), -1.2, 1.2)
		_player.force_update_transform()
		if cam:
			cam.force_update_transform()
		var fl := _player.get_node_or_null("Camera3D/Flashlight") as SpotLight3D
		if fl:
			fl.visible = _torch
		_armed = true
		return false

	var img := get_root().get_texture().get_image()
	var m := _measure(img, cam, box)
	var d2: float = DISTANCES[_dist_i]
	var nm := "%s_%s_%02.0fm_%s.png" % [
		String(TARGETS[String(_q[_phase])]["name"]), String(prop.name), d2,
		"torch" if _torch else "dark"]
	img.save_png(OUT + nm)
	if m.is_empty():
		print("  %-46s (off screen)" % nm)
	else:
		var ratio: float = float(m["prop_mean"]) / maxf(0.0005, float(m["ring_mean"]))
		print("  %-46s prop mean %.4f  peak %.4f   wall %.4f   ratio %5.2fx  (%d px)"
			% [nm, m["prop_mean"], m["prop_max"], m["ring_mean"], ratio, m["px"]])
		_rows.append({"name": nm, "d": d2, "torch": _torch, "ratio": ratio,
			"prop": m["prop_mean"], "wall": m["ring_mean"]})
	_armed = false
	_torch = not _torch
	if _torch:
		_dist_i += 1
		if _dist_i >= DISTANCES.size():
			_dist_i = 0
			_prop_i += 1
	return false


func _report() -> void:
	print("\n=== SUMMARY: prop-vs-wall luminance ratio ===")
	print("   A ratio near 1.0 means the prop is indistinguishable from the surface behind it.")
	print("   With the torch OFF, that is the intended result at distance: nothing is visible")
	print("   until you bring the beam to it. With the torch ON it must rise as you close in.")
	for r in _rows:
		print("   %-46s %5.2fx" % [r["name"], r["ratio"]])
	print("\nwrote %d shots to %s" % [_rows.size(), OUT])
