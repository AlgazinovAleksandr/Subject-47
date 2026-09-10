extends SceneTree

# Is a Congregation figure still DARKER than the floor it stands on?
#
#   Godot --path game --script res://tests/probe_congregation_tint.gd     # needs a display
#
# ⚠️ A `probe_*`: it prints, it does not assert, and it is not in the suite. It exists because
# `Congregation.FIGURE_TINT` is a CONSTANT albedo on an UNSHADED billboard, i.e. a fixed rendered
# luminance — while the surface it is supposed to be a silhouette against is lit by the room. The
# premise in `watcher.gd`'s own header is "a dark shape OCCLUDING a lit surface", and that premise
# INVERTS the moment the room gets darker than the figure. The Sprawl's lights were cut hard
# (`DEAD_LIGHT_CHANCE` 0.55, `STRIP_ENERGY` 0.6, ambient 0.07), so the tint has to be re-derived
# rather than assumed — this is cross-level X36 recurring for the same reason it happened the
# first time.
#
# ⚠️ MEASURE THE FIGURE AGAINST WHAT IS BEHIND IT, never against an absolute number (Issue 62).
# The method is `screenshot_cell_visibility.gd`'s: photograph the frame twice, once with the
# figures hidden, and diff to get the mask — a billboard's own alpha is not a screen mask.

const SHOT := "user://congregation_tint.png"
# ⚠️ THREE DISTANCES, NOT ONE. The figure is UNSHADED, so its own luminance does not fall off with
# range — but what is BEHIND it does, and the ratio is the property. A single pose would be an
# anecdote about one background.
const DISTS := [2.5, 4.0, 8.0]
var _di := 0
# The nearest sample's mask area, used as the ceiling every later row must come in under —
# see the CONTAMINATED check in stage 3.
var _first_mask_px := 0


func _find(n: Node, cls: String, out: Array) -> void:
	if n.get_class() == cls or (n.get_script() and String(n.get_script().resource_path)
			.ends_with(cls + ".gd")):
		out.append(n)
	for c in n.get_children():
		_find(c, cls, out)


func _lum(img: Image, mask: PackedInt32Array) -> float:
	var tot := 0.0
	var w := img.get_width()
	for i in mask:
		var c := img.get_pixel(i % w, i / w)
		tot += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	return tot / maxf(1.0, float(mask.size()))


var _t := 0.0
var _stage := 0
var _level: Node = null
var _figs: Array = []
var _hidden: Image = null
var _probe: Node3D = null


func _initialize() -> void:
	change_scene_to_file("res://scenes/backrooms.tscn")


func _process(delta: float) -> bool:
	_t += delta
	if _t < 3.0 or current_scene == null:
		return false
	_t = 0.0
	match _stage:
		0:
			_level = current_scene
			_level.call("_enter_zone", 2)
			_stage = 1
		1:
			# The Congregation lives under the zone-2 node; find every Watcher in the scene.
			_find(_level, "watcher", _figs)
			if _di == 0:
				print("== CONGREGATION TINT ==")
			print("-- eye %.1f m from the nearest figure --" % DISTS[_di])
			print("  figures: %d   FIGURE_TINT %s"
				% [_figs.size(), str(load("res://scripts/congregation.gd")
					.get_script_constant_map().get("FIGURE_TINT"))])
			if _figs.is_empty():
				print("  no figures — nothing to measure")
				quit(1)
				return true
			# Stand the camera in front of one, looking at it.
			var p := _level.get_node_or_null("Player")
			var target: Node3D = _figs[0]
			var eye: Vector3 = target.global_position + Vector3(0, 0.9, DISTS[_di])
			p.global_position = eye
			p.call("ai_look_at", target.global_position + Vector3(0, 1.0, 0))
			# ⚠️ HIDE ONLY THE FIGURE UNDER TEST. Hiding all six made the diff mask the union of
			# six silhouettes at six depths against six different backgrounds — 450k px, ~60 % of
			# the frame — so the "ratio" was an average over the whole field and moved run to run
			# with the Congregation's own randomised placement. One figure, one mask.
			_probe = target
			target.visible = false
			_stage = 2
		2:
			_hidden = get_root().get_viewport().get_texture().get_image()
			_probe.visible = true
			_stage = 3
		3:
			var shown := get_root().get_viewport().get_texture().get_image()
			var mask := PackedInt32Array()
			var w := shown.get_width()
			for y in range(shown.get_height()):
				for x in range(w):
					var a := shown.get_pixel(x, y)
					var b := _hidden.get_pixel(x, y)
					if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.02:
						mask.append(y * w + x)
			if mask.size() < 200:
				print("  the figure covers %d px — reposition, not a measurement" % mask.size())
				quit(1)
				return true
			# ⚠️⚠️ A MASK CAN BE CONTAMINATED, AND THE ONLY GUARD HERE WAS AGAINST IT BEING TOO
			# SMALL. `_hidden` and `shown` are captured a whole stage (~3 s) apart, and in that
			# window the OTHER five figures can relocate (SETTLE_MIN 8 s, six independent timers)
			# and the Sprawl's strips flicker — so the diff picks up whatever else moved and
			# calls it the figure. Measured 2026-09-03: one run's 8 m row reported **1 915 919 px**
			# against 378 706 px at 2.5 m, i.e. 52x the area a billboard can subtend at three
			# times the distance, and that contaminated row read a ratio of 1.00 — the pessimistic
			# direction, and the one X67's "reaches parity at depth" conclusion rests on. A
			# billboard's screen area falls as 1/d², so a farther sample covering MORE pixels than
			# a nearer one is not a measurement of the figure. Reported, not fatal: this is a
			# probe, and the nearer rows of that same run were sound.
			if _first_mask_px > 0 and mask.size() > _first_mask_px:
				print("  ⚠️ CONTAMINATED: %d px at %.1f m exceeds %d px at %.1f m — area must "
					% [mask.size(), float(DISTS[_di]), _first_mask_px, float(DISTS[0])]
					+ "FALL with distance. Something else moved between the two frames; discard "
					+ "this row and re-run.")
			elif _di == 0:
				_first_mask_px = mask.size()
			var fig := _lum(shown, mask)
			var bg := _lum(_hidden, mask)          # what is BEHIND it, same pixels
			print("  figure covers %d px" % mask.size())
			print("  figure luminance   %.5f  (%.1f of 255)" % [fig, fig * 255.0])
			print("  what is behind it  %.5f  (%.1f of 255)" % [bg, bg * 255.0])
			print("  ratio fig/bg       %.2f   %s" % [fig / maxf(bg, 1e-6),
				"DARKER — a silhouette" if fig < bg else "LIGHTER — the premise is inverted"])
			if _di == 0:
				shown.save_png(SHOT)
			_di += 1
			if _di < DISTS.size():
				_stage = 1
				_figs.clear()
			else:
				quit(0)
				return true
		_:
			pass
	return false
