extends SceneTree

# The darkness pass: are the three levels actually dark, is the torch actually infinite, and did
# the DarkZones that became unfair actually go away?
#
#   Godot --headless --path game --script res://tests/check_darkness.gd
#
# ⚠️ WHY IT IS ONE TEST AND NOT THREE. The three halves are one decision. Ambient at 0.02 makes
# the torch mandatory; a mandatory torch makes an infinite battery mandatory (a level you cannot
# see is a level you cannot finish, and there is no battery pickup anywhere in the game); and a
# mandatory torch makes "+3/s while your torch is off" stop being a choice and start being an
# ambush. Assert any one of them alone and the other two can silently regress into a level that
# is unplayable rather than dark.
#
# ⚠️ THE DARKZONE ABSENCES CARRY A CONTROL. An absence assertion is trivially true of a level
# that failed to build — `check_dungeon_entities.gd` learned that the hard way (cross-level X51),
# and eleven comfortable OKs on a scene that threw on its first line is the exact shape. So this
# plants a real `DarkZone` in each darkened level and requires the same sweep to find it.
#
# ⚠️ AND IT ASSERTS THE UNCHANGED LEVELS ARE UNCHANGED. The Corridor, the Backrooms and the Void
# keep their DarkZones on purpose (the user's call, D4) — those levels were not part of this
# pass. A sweep that reported "no DarkZones anywhere" would be reporting a bug.

# ⚠️ `max_ambient` TIGHTENED FOR THE LAB AND THE HOUSE (2026-09-07). They went to 0.0 while
# KONTUR stayed at 0.02, and a shared 0.03 ceiling cannot tell those apart — it would have passed
# a silent revert to 0.02 in either of them.
#
# ⚠️ `torch` IS THE OTHER HALF OF THE SAME CHANGE, and without it this file is BLIND to it.
# `_check_torch()` below reads `FLASH_RANGE` / `FLASH_ANGLE` off `player.gd` — the game's
# defaults, which did not move — so a per-level override is invisible to every assertion this
# guard already had. What is checked here is the light the scene actually ends up with.
const DARK_LEVELS := {
	"res://scenes/level_1.tscn":
		{"name": "Lab", "max_ambient": 0.005, "torch": Vector2(11.0, 24.0)},
	"res://scenes/level_2_1.tscn":
		{"name": "House", "max_ambient": 0.005, "torch": Vector2(11.0, 24.0)},
	"res://scenes/kontur.tscn":
		{"name": "KONTUR", "max_ambient": 0.03, "torch": Vector2(18.0, 30.0)},
}
# Levels that must keep the WIDE default beam. KONTUR is in DARK_LEVELS above and is checked
# there; these are the lit ones, and the Breach is the one that matters — `LIGHT_WEAPON_DOT` is
# `cos(FLASH_ANGLE)` and a narrowed beam there would desync the light weapon from the light.
const WIDE_TORCH_LEVELS := {
	"res://scenes/corridor.tscn": "Corridor",
	"res://scenes/level_6_breach.tscn": "Breach",
}
# Levels that MUST still have a DarkZone — they were deliberately left alone.
const KEEPS_DARK_ZONES := {
	"res://scenes/corridor.tscn": "the 145-172 m stretch, with its four beartraps",
	"res://scenes/backrooms.tscn": "one arm goes dark per round, and relights",
	"res://scenes/level_3.tscn": "the Void's rooms C and D",
}

var _fails: Array[String] = []
var _checks := 0
var _queue: Array = []
var _t := 0.0
var _wall := 0.0
var _phase := 0
var _cur := ""


func _ok(label: String, cond: bool, detail: String = "") -> void:
	_checks += 1
	print(("  OK   " if cond else "  FAIL ") + label + ("  " + detail if detail else ""))
	if not cond:
		_fails.append(label)


func _all(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_all(c, out)


func _count_dark_zones() -> int:
	var nodes: Array = []
	_all(current_scene, nodes)
	var n := 0
	for x in nodes:
		if x is DarkZone:
			n += 1
	return n


func _initialize() -> void:
	for path in DARK_LEVELS.keys():
		_queue.append({"path": path, "dark": true})
	for path in KEEPS_DARK_ZONES.keys():
		_queue.append({"path": path, "dark": false})
	for path in WIDE_TORCH_LEVELS.keys():
		_queue.append({"path": path, "dark": false, "wide": true})
	seed(7)   # KONTUR and the Backrooms randomise; pin them
	change_scene_to_file(String(_queue[0]["path"]))
	_cur = String(_queue[0]["path"])


func _process(delta: float) -> bool:
	_wall += delta
	if _wall > 180.0:
		print("TIMEOUT")
		quit(1)
		return true
	_t += delta
	# Levels build a lot in _ready(); give each one real time before measuring.
	if _t < 3.0 or current_scene == null:
		return false
	_t = 0.0

	var entry: Dictionary = _queue[_phase]
	var is_dark: bool = entry["dark"]
	var label: String = String(DARK_LEVELS.get(_cur, {}).get("name", _cur.get_file()))

	if entry.get("wide", false):
		# The unchanged levels: the beam must still be the game's default, or a per-level
		# override has leaked out of the two scenes that asked for one.
		_check_level_torch(String(WIDE_TORCH_LEVELS[_cur]), Vector2(18.0, 30.0))
		return _advance()

	if is_dark:
		# ------------------------------------------------------------------ ambient
		var we := current_scene.get_node_or_null("Environment/WorldEnvironment") as WorldEnvironment
		_ok("%s: has a WorldEnvironment" % label, we != null and we.environment != null)
		if we and we.environment:
			var amb: float = we.environment.ambient_light_energy
			var cap: float = float(DARK_LEVELS[_cur]["max_ambient"])
			_ok("%s: ambient is <= %.3f at spawn" % [label, cap], amb <= cap,
				"ambient_light_energy %.3f (was 0.30-0.35 before the pass)" % amb)
		_check_level_torch(label, DARK_LEVELS[_cur]["torch"])

		# ------------------------------------------------------------------ no lamp is burning
		# ⚠️ The lamps still EXIST — `check_fixtures.gd` asserts a minimum fitting count per level
		# and every fitting is created alongside a lamp, so darkening by deletion turns that guard
		# red. They are held at zero instead.
		var nodes: Array = []
		_all(current_scene, nodes)
		var lamps := 0
		var burning := 0
		var brightest := 0.0
		for x in nodes:
			if x is OmniLight3D:
				lamps += 1
				if (x as OmniLight3D).light_energy > 0.001:
					burning += 1
					brightest = maxf(brightest, (x as OmniLight3D).light_energy)
		_ok("%s: the lamps still exist (not deleted)" % label, lamps >= 6,
			"%d OmniLight3D — check_fixtures.gd needs the fittings that come with them" % lamps)
		if label == "KONTUR":
			# ⚠️ KONTUR is the DELIBERATE half-measure (D2): the Soviet half goes dark and the
			# clinical Airlock/Escort/Terminus wing keeps its lamps, because Gate 7's puzzle IS
			# "the room with no light" and the escort beat needs lamps to kill. So burning lamps
			# are expected — what must be true is that none of them is in the Soviet half.
			# ⚠️ ONE DELIBERATE EXCEPTION: the Gate 3 offering pedestal. Its whole design is a
			# keycard GLOWING ON A LIT PEDESTAL, read identically to the Lab keycard the player
			# has spent five levels being trained to grab — and the test is to walk past it. In a
			# level that is otherwise pitch black that lure gets stronger, not weaker, so this is
			# the one light in the Soviet half that must survive the pass. It is exempted by its
			# PARENT (`OfferingPedestal`), never by a magic energy value, so a room lamp that
			# happened to match its brightness could not sneak through.
			var soviet_burning := 0
			var exempt := 0
			for x in nodes:
				if not (x is OmniLight3D) or (x as OmniLight3D).light_energy <= 0.001:
					continue
				if (x as OmniLight3D).global_position.z >= 51.0:
					continue
				var owner_name := String(x.get_parent().name) if x.get_parent() else ""
				if owner_name.contains("OfferingPedestal"):
					exempt += 1
					continue
				soviet_burning += 1
			_ok("KONTUR: nothing burns in the Soviet half (z < 51)", soviet_burning == 0,
				"%d lit lamp(s) before the Blackout room" % soviet_burning)
			_ok("KONTUR: ...except the Gate 3 pedestal, which IS the lure", exempt == 1,
				"%d pedestal glow(s) — a bait keycard on an unlit pedestal is not bait" % exempt)
			_ok("KONTUR: the clinical wing IS still lit", burning >= 5,
				"%d lit lamps past z 51 — Gate 7 and the escort beat both need them" % burning)
		else:
			_ok("%s: no lamp is burning at spawn" % label, burning == 0,
				"%d lit of %d, brightest %.2f" % [burning, lamps, brightest])

		# ------------------------------------------------------------------ no DarkZone
		var dz := _count_dark_zones()
		_ok("%s: no DarkZone remains" % label, dz == 0,
			("%d found — with the torch now mandatory, +3/s for having it off is a tax on a "
			+ "posture the level imposed (Issue 18)") % dz)

		# ⭐ THE CONTROL. Plant a real DarkZone and require the same sweep to see it.
		var probe := DarkZone.new()
		probe.name = "DarkZoneControlProbe"
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2, 2, 2)
		col.shape = shape
		probe.add_child(col)
		current_scene.add_child(probe)
		_ok("%s: CONTROL — a planted DarkZone IS detected" % label, _count_dark_zones() == 1,
			"if this reads 0 the absence assertion above measures nothing")
		probe.free()
	else:
		var dz2 := _count_dark_zones()
		_ok("%s: still HAS its DarkZone(s)" % _cur.get_file(), dz2 >= 1,
			"%d — %s" % [dz2, KEEPS_DARK_ZONES[_cur]])

	return _advance()


func _advance() -> bool:
	_phase += 1
	if _phase >= _queue.size():
		_check_torch()
		print("== %d checks, %d failed ==" % [_checks, _fails.size()])
		for f in _fails:
			print("   FAILED: " + f)
		quit(1 if _fails.size() > 0 else 0)
		return true
	_cur = String(_queue[_phase]["path"])
	seed(7)
	change_scene_to_file(_cur)
	return false


# ⭐ THE LIGHT THE SCENE ACTUALLY ENDS UP WITH, not the constant that was asked for.
#
# ⚠️ This is the assertion the 2026-09-07 pass could not have shipped without. `player.gd`'s
# `_ready()` writes `FLASH_RANGE`/`FLASH_ANGLE` into the scene's SpotLight3D, and then a level's
# own `_ready()` — which Godot runs afterwards — may narrow it via `set_torch_profile()`. Reading
# the constants (as `_check_torch()` does, correctly, for a different purpose) cannot see that,
# so without this the Lab and the House could silently revert to an 18 m beam with 34 green
# checks.
#
# ⚠️ CONTROL INCLUDED, and it is not a formality: "the light reads 11 m" is trivially true if the
# probe is reading some other light. It plants the default profile back and requires red.
func _check_level_torch(label: String, want: Vector2) -> void:
	var p := current_scene.get_node_or_null("Player") as CharacterBody3D
	var fl: SpotLight3D = null
	if p != null:
		fl = p.get_node_or_null("Camera3D/Flashlight") as SpotLight3D
	_ok("%s: the player's Flashlight was found" % label, fl != null)
	if fl == null:
		return
	_ok("%s: the beam is %.0f m / %.0f deg" % [label, want.x, want.y],
		absf(fl.spot_range - want.x) < 0.01 and absf(fl.spot_angle - want.y) < 0.01,
		"reads %.1f m / %.1f deg" % [fl.spot_range, fl.spot_angle])
	# CONTROL — put the game default back and require the same comparison to notice.
	var keep := Vector2(fl.spot_range, fl.spot_angle)
	var ps: GDScript = load("res://scripts/player.gd")
	fl.spot_range = float(ps.get("FLASH_RANGE"))
	fl.spot_angle = float(ps.get("FLASH_ANGLE"))
	var caught: bool = absf(fl.spot_range - want.x) >= 0.01 or absf(fl.spot_angle - want.y) >= 0.01
	if want.x < 17.0:
		_ok("%s: CONTROL — the default beam IS detected as wrong" % label, caught,
			"if this fails the assertion above cannot tell 11 m from 18 m")
	fl.spot_range = keep.x
	fl.spot_angle = keep.y


# The torch, read off `player.gd` itself rather than off any one scene — `_ready()` writes the
# four values into whatever SpotLight3D the scene shipped, so the script is the source of truth
# and ten `.tscn` files are no longer.
func _check_torch() -> void:
	var ps: GDScript = load("res://scripts/player.gd")
	_ok("the battery is infinite", bool(ps.get("INFINITE_BATTERY")),
		"a level lit only by the torch cannot have a torch that runs out — there is no battery "
		+ "pickup anywhere in the game")
	# ⚠️ THIS READ `ps.get("BATTERY_MAX") != null` AND COULD NOT FAIL — a const that is present
	# is present. It named the property ("kill_flashlight still works") and measured a different
	# one. Found by an audit probe. What actually has to hold is that the ONE-WAY KILL still
	# takes the torch away: the Corridor's noclip and THE NIGHTMARE's candle both depend on it,
	# and `check_dungeon_entities.gd:118` asserts the torch is dead for that whole level.
	_ok("BATTERY_MAX survives as the not-dead sentinel", ps.get("BATTERY_MAX") != null)

	# ⚠️⚠️ THIS WAS TWO `src.contains(...)` GREPS AND THEY DID NOT PROTECT THE PROPERTY.
	# Measured 2026-09-03: comment BOTH lines out of `kill_flashlight()` — leaving the strings
	# in the file as comments — and this test reported **29 of 29 green**, because `contains()`
	# matches a commented-out copy just as happily as live code. Nor did anything else catch it:
	# `check_dungeon_entities.gd`'s "the flashlight is dead" reads `is_flashlight_on()` right
	# after the kill, and the gutted kill still hides the light. What no guard could see is the
	# half that matters — that **F now turns it back on**, which would hand the player a torch
	# through the whole of THE NIGHTMARE and the Corridor's noclip.
	# So drive the shipping path instead of reading the source that implements it.
	var pl := current_scene.get_node_or_null("Player") as CharacterBody3D
	_ok("a live player to drive the torch on", pl != null)
	if pl:
		var f := InputEventAction.new()
		f.action = "toggle_flashlight"
		f.pressed = true
		# ⭐ CONTROL FIRST. "F does nothing" is trivially true if F never reaches the handler at
		# all (a frozen player, an open NoteUI, a renamed action). Prove F works before proving
		# the kill defeats it.
		var before: bool = bool(pl.call("is_flashlight_on"))
		pl.call("_unhandled_input", f)
		_ok("CONTROL — F toggles a healthy torch",
			bool(pl.call("is_flashlight_on")) != before,
			"if this fails every assertion below is vacuous, not passing")

		pl.call("kill_flashlight")
		_ok("kill_flashlight() zeroes the battery sentinel",
			is_equal_approx(float(pl.get("_battery")), 0.0),
			"_battery %.2f — the Corridor's noclip and the candle both read this"
				% float(pl.get("_battery")))
		_ok("kill_flashlight() sets the one-way dead flag", bool(pl.get("_flashlight_dead")))
		_ok("...and the torch goes out", not bool(pl.call("is_flashlight_on")))
		pl.call("_unhandled_input", f)
		_ok("PERMANENT — pressing F cannot resurrect a killed torch",
			not bool(pl.call("is_flashlight_on")),
			"F re-enabled a torch that kill_flashlight() had taken away; infinite battery must "
			+ "not make the one-way kill a no-op")
		# The other re-enable path. `_flash_was_on` is forced true so the only thing left
		# refusing is the `_battery > 0.0 and not _flashlight_dead` gate — otherwise this
		# passes because nothing asked it to turn the light on.
		pl.set("_flash_was_on", true)
		pl.call("restore_flashlight")
		_ok("PERMANENT — restore_flashlight() cannot resurrect it either",
			not bool(pl.call("is_flashlight_on")))
	var energy: float = float(ps.get("FLASH_ENERGY"))
	var rng: float = float(ps.get("FLASH_RANGE"))
	var ang: float = float(ps.get("FLASH_ANGLE"))
	_ok("the beam is wider than it was", energy >= 1.5 and rng >= 17.0 and ang >= 28.0,
		"%.1f energy / %.0f m / %.0f deg (was 1.2 / 15 / 25)" % [energy, rng, ang])

	# ⚠️ MARRIED CONSTANTS. `level_6_breach.gd:LIGHT_WEAPON_DOT` is documented as "a tight cone
	# matching the flashlight's own spot_angle". If the beam widens and the weapon's cone does
	# not, the visible light covers Object 12 while the weapon does not register — which reads as
	# a bug, not as a rule.
	var b: GDScript = load("res://scripts/level_6_breach.gd")
	var dot: float = float(b.get("LIGHT_WEAPON_DOT"))
	var want: float = cos(deg_to_rad(ang))
	_ok("the light weapon's cone still matches the beam", absf(dot - want) < 0.02,
		"LIGHT_WEAPON_DOT %.3f vs cos(%.0f deg) = %.3f" % [dot, ang, want])
