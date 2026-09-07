extends SceneTree

# ⭐ THE DECISIVE FOOT-SLIDE TEST. Headless is fine — this is numbers, not pixels.
#
#   /Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/probe_gait_slide.gd
#
# `CreatureAnim.CLIP_SPEED` claims each clip's feet travel at a given m/s. This checks that
# claim the only way that settles it: drive the rig forward at a known world speed with the clip
# scaled exactly as `play_locomotion()` would, and measure the PLANTED foot's residual drift.
#
# Stance detection is by TOE HEIGHT, not by "whichever foot moved less" — the latter is
# contaminated by the swap frames where both feet are moving, which is why the in-level probes
# reported a soft 0.21-0.50 that could not be read either way.
#
#   drift = mean world-space horizontal speed of a toe while that toe is planted, in m/s.
#   A perfect gait gives 0.00. Sliding gives a number that scales with the mismatch, and its
#   SIGN says which way: `-` = the feet are under-travelling (the creature moon-walks forward),
#   `+` = over-travelling (it pedals).

const GLB := "res://assets/models/hollow_crown.glb"

# clip -> the world speed the game actually plays it at
const CASES := [
	{"clip": "walk", "speed": 1.825, "who": "CONTROL: walk at its own CLIP_SPEED"},
	{"clip": "charge", "speed": 2.849, "who": "CONTROL: charge at its own CLIP_SPEED (root-motion anchored)"},
	{"clip": "run", "speed": 5.487, "who": "CONTROL: run at its own CLIP_SPEED"},
	{"clip": "unsteady", "speed": 1.489, "who": "CONTROL: unsteady at its own CLIP_SPEED"},
	{"clip": "shamble", "speed": 0.390, "who": "CONTROL: shamble at its own CLIP_SPEED"},
	{"clip": "sprint", "speed": 9.271, "who": "CONTROL: sprint at its own CLIP_SPEED"},
	{"clip": "walk", "speed": 3.65, "who": "NEGATIVE CONTROL: walk at 2x (scale clamps at 1.8, so ~10 %% is EXPECTED)"},
	{"clip": "walk", "speed": 1.8, "who": "SHIPPED: Object 12 PATROL"},
	{"clip": "walk", "speed": 2.6, "who": "SHIPPED: Object 12 INVESTIGATE"},
	{"clip": "run", "speed": 5.0, "who": "SHIPPED: Object 12 CHASE"},
	{"clip": "charge", "speed": 3.4, "who": "SHIPPED: the Matron CHASE"},
	{"clip": "unsteady", "speed": 1.25, "who": "SHIPPED: Void stalker / Still Ones ADVANCING"},
	{"clip": "unsteady", "speed": 1.00, "who": "sweep"},
	{"clip": "unsteady", "speed": 1.10, "who": "sweep"},
	{"clip": "unsteady", "speed": 1.40, "who": "sweep"},
	{"clip": "charge", "speed": 3.00, "who": "sweep"},
	{"clip": "charge", "speed": 3.20, "who": "sweep"},
	{"clip": "run", "speed": 4.50, "who": "sweep"},
	{"clip": "run", "speed": 6.00, "who": "sweep"},
]

const SPEED_SCALE_MIN := 0.6
const SPEED_SCALE_MAX := 1.8
const CLIP_SPEED := {"walk": 1.825, "shamble": 0.390, "unsteady": 1.489,
	"run": 5.487, "sprint": 9.271, "charge": 2.849}

# ⚠️ MEASURED IN THE REAL FRAME LOOP, not by seek(). `AnimationPlayer.seek()` /
# `advance()` from a `--script` SceneTree leaves `Skeleton3D.get_bone_global_pose()` frozen at
# the rest pose — the first version of this probe reported a tidy "100.0 % of body speed" for
# every case INCLUDING both positive controls, which is the signature of a bone that never
# moved. Only the tree's own tick applies the pose.
const WARMUP := 0.6      # s of cycle to discard (blend-in)
const MEASURE := 2.4     # s of cycle to measure

var _root: Node3D
var _ap: AnimationPlayer
var _skel: Skeleton3D
var _lib := ""
var _lt := -1
var _rt := -1
var _case := 0
var _phase := 0
var _t := 0.0
var _world_z := 0.0
var _prev: Array = []
var _lowest := 1e9
var _drift_sum := 0.0
var _drift_n := 0
var _lines: Array[String] = []


func _find(n: Node, cls: String, out: Array) -> void:
	if n.get_class() == cls:
		out.append(n)
	for c in n.get_children():
		_find(c, cls, out)


func _initialize() -> void:
	var packed: PackedScene = load(GLB)
	_root = packed.instantiate()
	root.add_child(_root)
	var a: Array = []
	_find(_root, "AnimationPlayer", a)
	_ap = a[0]
	var s: Array = []
	_find(_root, "Skeleton3D", s)
	_skel = s[0]
	for n in _ap.get_animation_list():
		if String(n).contains("/"):
			_lib = String(n).get_slice("/", 0) + "/"
			break
	for c in CLIP_SPEED.keys():
		var full: String = _lib + String(c)
		if _ap.has_animation(full):
			_ap.get_animation(full).loop_mode = Animation.LOOP_LINEAR

	_lt = _skel.find_bone("LeftToeBase")
	_rt = _skel.find_bone("RightToeBase")
	print("\n  clip @ world speed        scale   planted-toe drift   verdict")
	print("  " + "-".repeat(78))
	_begin()


func _begin() -> void:
	var c: Dictionary = CASES[_case]
	var clip: String = c["clip"]
	var scale: float = clampf(float(c["speed"]) / float(CLIP_SPEED[clip]),
		SPEED_SCALE_MIN, SPEED_SCALE_MAX)
	_ap.play(_lib + clip)
	_ap.speed_scale = scale
	_root.position = Vector3.ZERO
	_t = 0.0
	_world_z = 0.0
	_prev = []
	_lowest = 1e9
	_drift_sum = 0.0
	_drift_n = 0
	_phase = 0


func _toes() -> Array:
	var out: Array = []
	for b in [_lt, _rt]:
		var o := _skel.get_bone_global_pose(b).origin
		out.append(Vector3(o.x, o.y, o.z))
	return out


func _process(delta: float) -> bool:
	if _case >= CASES.size():
		print("")
		print("  scale is clamped to %.1f..%.1f by CreatureAnim.play_locomotion()."
			% [SPEED_SCALE_MIN, SPEED_SCALE_MAX])
		print("  drift = mean world-space horizontal speed of a toe DURING ITS STANCE PHASE,")
		print("  as a fraction of how fast the body is travelling. 0 %% = the foot is planted;")
		print("  100 %% = the foot is simply carried along, i.e. the legs are decoration.")
		quit(0)
		return true

	var c: Dictionary = CASES[_case]
	var world: float = c["speed"]
	_t += delta

	# phase 0: warm up AND learn how low the toe gets, so "planted" is measured not typed
	if _phase == 0:
		for v in _toes():
			_lowest = minf(_lowest, v.y)
		if _t >= WARMUP + MEASURE:
			_phase = 1
			_t = 0.0
			_world_z = 0.0
			_prev = []
		return false

	# phase 1: measure
	_world_z += world * delta
	var now: Array = []
	for v in _toes():
		now.append(Vector3(v.x, v.y, v.z + _world_z * 100.0))   # bone poses are in cm
	if not _prev.is_empty() and delta > 0.0:
		var thresh: float = _lowest + 3.0                        # 3 cm, in bone units
		for k in 2:
			var a: Vector3 = _prev[k]
			var b: Vector3 = now[k]
			if b.y > thresh:
				continue
			var d := Vector2(b.x - a.x, b.z - a.z).length() / 100.0
			var sgn := 1.0 if b.z > a.z else -1.0
			_drift_sum += d * sgn / delta
			_drift_n += 1
	_prev = now
	if _t < MEASURE:
		return false

	var drift: float = _drift_sum / maxf(1, _drift_n)
	var pct: float = 100.0 * absf(drift) / world
	var verdict := "planted"
	if pct > 45.0:
		verdict = "HEAVY SLIDE"
	elif pct > 25.0:
		verdict = "visible slide"
	elif pct > 12.0:
		verdict = "slight slide"
	var scale: float = clampf(world / float(CLIP_SPEED[c["clip"]]),
		SPEED_SCALE_MIN, SPEED_SCALE_MAX)
	_lines.append("  %-9s @ %5.2f m/s  x%.3f  %+6.3f m/s = %5.1f %% of body speed  %-13s %s"
		% [c["clip"], world, scale, drift, pct, verdict, c["who"]])
	print(_lines[_lines.size() - 1])
	_case += 1
	if _case < CASES.size():
		_begin()
	return false
