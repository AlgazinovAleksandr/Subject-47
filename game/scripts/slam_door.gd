extends StaticBody3D
class_name SlamDoor

# Interior chase door — deliberately NOT built on door.gd (its UnlockCondition /
# extra_lock / advances_level machinery is irrelevant baggage here). Press E while
# passing through to slam it shut behind you; while closed, the level orchestrator's
# per-frame scan (level_6_breach.gd::_tick_slam_doors) checks whether it's blocking
# Object 12's current path and, if so, calls start_battering(), which in turn calls
# the creature's force_block() — a temporary delay, not a permanent block, matching
# a Nemesis-style chase rather than a puzzle lock.

signal slammed
signal broken_open

@export var batter_time: float = 10.0

# ⭐ THE DOOR IS SIZED FROM ITS DOORWAY NOW (2026-09-03), and until it was, IT HAD NEVER CLOSED.
#
# ⚠️ THE MEASUREMENT. The panel and the blocker were both a hard-coded 1.1 m wide. Breach
# doorways are **1.8 m** (`level_6_breach.gd:DOORS`) and Dungeon doorways are **2.2 m**
# (`dungeon_gen.gd:DOOR_WIDTH`) — and `room_builder.gd:_emit_wall_run()` cuts a doorway
# FULL HEIGHT with no lintel, against room heights of 3.0 m and 3.2 m. So a "closed" door left
#     Breach:  0.35 m of walkable gap EACH SIDE, and 0.8 m of open air above
#     Dungeon: 0.55 m of walkable gap EACH SIDE, and 1.0 m of open air above
# against a player capsule 0.8 m across. Slamming a door on Object 12 has therefore never
# actually blocked it; `check_blocks_path()`'s segment/AABB test assumed a seal the geometry
# never provided.
#
# ⚠️ THE DEFAULTS ARE THE BREACH'S, so `level_6_breach.gd` needs no change to get the fix and
# `dungeon.gd` passes 2.2 / 3.2. Every derived dimension below hangs off these two.
@export var door_width: float = 1.8
@export var door_height: float = 3.0
# Per-level leaf art. Empty falls back to the Breach's; the Dungeon passes its own.
@export var door_texture: String = ""

# The swinging leaf stops here; everything above it is a fixed transom (see `_build_frame`).
const LEAF_H := 2.2
const JAMB_T := 0.08          # jamb thickness, outside the opening
# ⚠️⚠️ 0.26, NOT 0.12 — AND THE OLD NUMBER MEANT THE JAMBS WERE NEVER VISIBLE AT ALL (2026-09-03).
# The comment claimed "how far the frame stands proud of the wall" and the arithmetic said
# otherwise: `RoomBuilder.T` is **0.2**, so a wall spans z -0.1..+0.1 about the doorway plane,
# and a jamb of depth 0.12 centred on that plane spans -0.06..+0.06 — **entirely inside the
# masonry, on both faces, in every level**. Measured by an audit probe: jambs 100 % buried on the
# Breach's `Slam_Corridor1_Junction1` and THE NIGHTMARE's `Slam_0`, while the lintel and transom
# (which sit ABOVE the wall's opening, not inside it) were only 7-8 % buried and did show. So the
# door has been standing in a frame with no visible uprights.
# ⚠️ It must EXCEED the wall thickness, not match it: at exactly 0.2 the jamb faces are coplanar
# with the wall faces and z-fight (Issue 11's family). 0.26 leaves 3 cm proud on each side.
const FRAME_D := 0.26
# ⚠️ -85, NOT -100 (2026-09-03). Past 90 degrees a leaf tilts BACK toward the wall it is hinged
# on and ends up lying almost flat against it — `check_wall_overlap.gd` found the open leaves'
# art quads within 0.02 m of a CSG wall on 4 of the Nightmare's generated doors. That guard had
# nothing to say about this before only because SlamDoor carried no artwork at all, so there
# were no quads to measure; the geometry was always like that.
# ⚠️ 85 is enough BECAUSE THE DOOR IS NOW TWO LEAVES. A single 1.8-2.2 m leaf needed to swing
# well past perpendicular to get out of its own way; a half-width leaf at 85 degrees is already
# clear of the opening, and it reads as a door standing open rather than one folded shut again.
const OPEN_DEG := -85.0

const THUD_INTERVAL := 0.6
const INTERACTABLE_LAYER := 2   # matches note.gd — raycast-hittable, pass-through for movement
const TEX_BREACH := "res://assets/textures/level_6_breach/breach_door.png"

var _closed: bool = false
var _battering: bool = false
# Seconds after a door is broken open during which E cannot re-close it. See `interact()`.
const RESLAM_COOLDOWN := 8.0
var _reslam_lock_t: float = 0.0
var _batter_t: float = 0.0
var _thud_t: float = 0.0

var _hinge: Node3D      # left leaf
var _hinge_r: Node3D    # right leaf, mirrored
var _panel: MeshInstance3D
var _collider: CollisionShape3D
var _block_body: StaticBody3D
var _block_collider: CollisionShape3D
var _batter_audio: AudioStreamPlayer3D


func _ready() -> void:
	_build_frame()
	_build_visual()

	# ⚠️ A raycast never reports a hit against a DISABLED CollisionShape3D. This
	# body's own collider used to start disabled (meant to represent "open, not
	# physically blocking") and only got re-enabled from INSIDE interact() — which
	# made it undetectable by the player's interact ray from the very start: a real
	# playtest could never get a "Press E" prompt on this door at all (found
	# 2026-07-24 — the automated win-path test missed it because it called
	# interact() directly, never through the player's actual raycast/prompt path).
	#
	# Fix: split into two bodies. THIS body's collider is always enabled, on the
	# pass-through interactable layer (note.gd's exact convention: raycast-hittable,
	# invisible to normal movement collision) — it exists purely so E always finds
	# this door. Physical blocking is a separate child body below, since
	# collision_layer/mask apply to a whole body, not per-shape, so one body can't
	# be "always raycastable, sometimes solid" on its own.
	collision_layer = INTERACTABLE_LAYER
	collision_mask = 0
	_collider = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# ⚠️ DEPTH 1.2, NOT 0.1 (2026-08-15). `purge_chamber.gd:43-49` had this exact fault
	# fixed on the 2026-07-24 playtest and wrote down why: "the raycast-hittable box used
	# to match the physical panel exactly — a razor-thin slab at the doorway plane… a
	# player glancing back at the creature or approaching off-axis would miss the z-depth
	# entirely." SlamDoor was never given the same fix and was THINNER still, on doors the
	# player is walking THROUGH (so the approach is routinely oblique) while being chased.
	# Reported as "you need to stand very close" in Levels 6 and 7 — the two levels that
	# are the only users of this class.
	#
	# ⚠️ It is also what de-conflicts this shape from the blocker below. The two used to be
	# identical in size AND position, so on a CLOSED door `intersect_ray` could return
	# `_block_body` — which has no `interact()`, so `player.gd:_is_interactable()` nulled
	# the target and E did nothing in exactly the state you need to reopen it. Depth is
	# what makes the interact box win, the same way PurgeChamber's 1.2 wins over its 0.15.
	#
	# ⚠️ And WIDER than the doorway, offset toward the hinge side, because an OPEN door's
	# art is not where its collider is. `_build_visual()` parks the panel at -100°, which
	# puts it about 0.65 m to -x and 0.54 m to +z of the frame — a metre from the only
	# interactable surface. A player aiming at the door they can SEE got nothing, while a
	# player standing in the empty doorway got the prompt. A CollisionShape3D has to be a
	# direct child of its body, so it cannot simply be parented to the hinge; spanning both
	# positions is the fix that needs no second body and no forwarding script.
	# ⚠️ DERIVED FROM WHERE THE OPEN LEAF ACTUALLY IS, not from a literal (2026-09-03). The old
	# values (1.9 x 1.2, offset -0.3) were hand-fitted to a 1.1 m leaf, and the header above
	# already explains why: an OPEN door's ART IS NOT WHERE ITS COLLIDER IS. `_build_visual()`
	# parks the leaf at OPEN_DEG, which swings it out of the doorway and into the room — so the
	# volume has to span BOTH the closed plane and the open sweep, or a player aiming at the door
	# they can see gets nothing while a player standing in the empty doorway gets the prompt.
	#
	# ⚠️ Widening the leaf 1.1 -> 1.8/2.2 broke exactly that, and `check_interact_reach.gd` caught
	# it: the open panel's centre moved from z 0.54 to z 0.89 while the volume still stopped at
	# z 0.60, so E stopped working on an open Breach door entirely. The extents below are the
	# leaf's own swept envelope:
	#     open far corner  x = -W/2 + W*cos(OPEN_DEG),  z = W*sin(-OPEN_DEG)
	#     closed leaf      x = -W/2 .. +W/2,            z = 0
	var open_rad := deg_to_rad(OPEN_DEG)
	var leaf_w := door_width * 0.5
	var x_min: float = -door_width * 0.5 - absf(leaf_w * cos(open_rad)) - 0.15
	var x_max: float = -x_min
	var z_max: float = leaf_w * sin(-open_rad) + 0.15
	var z_min := -0.6
	shape.size = Vector3(x_max - x_min, LEAF_H, z_max - z_min)
	_collider.shape = shape
	_collider.position = Vector3((x_min + x_max) * 0.5, LEAF_H * 0.5, (z_min + z_max) * 0.5)
	add_child(_collider)

	# The actual physical blocker — default layer (matches the player/walls/every
	# other solid thing), only solid while _closed. Also excluded from creature
	# LOS/detection checks by mask (see creature_object12.gd/_has_los,
	# level_6_breach.gd/_has_clear_los) — an open door must not block sight through
	# its own doorway.
	_block_body = StaticBody3D.new()
	add_child(_block_body)
	_block_collider = CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	# ⚠️ THE FULL WIDTH OF THE DOORWAY. This is the line that makes a closed door closed.
	bshape.size = Vector3(door_width, LEAF_H, 0.1)
	_block_collider.shape = bshape
	_block_collider.position.y = LEAF_H * 0.5
	_block_collider.disabled = true   # only solid while _closed
	_block_body.add_child(_block_collider)

	_batter_audio = AudioStreamPlayer3D.new()
	var batter := GameState.load_audio("door_batter")
	if batter:
		_batter_audio.stream = batter
	_batter_audio.unit_size = 6.0
	add_child(_batter_audio)


# Static (not part of the hinge, so it never rotates with the panel) — a playtest
# note flagged that the door "looks weird" / "floats in the corridor": swung open,
# the bare panel has nothing anchoring it to a wall, so it reads as a random plank
# rather than a door. A visible frame around the closed-door envelope fixes that in
# BOTH states — closed, it reads as a door in a doorway; open, the frame is still
# right there showing what the panel is hinged to.
func _build_frame() -> void:
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.07, 0.07, 0.07)
	frame_mat.metallic = 0.3
	frame_mat.roughness = 0.6

	var half := door_width * 0.5
	var jamb_size := Vector3(JAMB_T, LEAF_H + 0.1, FRAME_D)
	for side in [-1.0, 1.0]:
		var jamb := MeshInstance3D.new()
		var jm := BoxMesh.new()
		jm.size = jamb_size
		jamb.mesh = jm
		jamb.position = Vector3(side * (half + JAMB_T * 0.5), jamb_size.y * 0.5, 0.0)
		jamb.set_surface_override_material(0, frame_mat)
		add_child(jamb)

	var lintel := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(door_width + JAMB_T * 2.0, 0.1, FRAME_D)
	lintel.mesh = lm
	lintel.position = Vector3(0.0, LEAF_H + 0.05, 0.0)
	lintel.set_surface_override_material(0, frame_mat)
	add_child(lintel)

	# ⭐ THE TRANSOM — the half of "a closed door closes the doorway" that a leaf cannot do.
	#
	# ⚠️ `RoomBuilder` cuts every doorway FULL HEIGHT with no lintel of its own, so the opening
	# runs to the ceiling: 3.0 m in the Breach, 3.2 m in the Dungeon, against a 2.2 m leaf. That
	# left 0.8-1.0 m of open sky over every one of these doors, visible from anywhere in the
	# room. A player cannot walk through a gap 2.2 m up, so this is not a route fix — it is the
	# reason the doors "look weird": a door frame with nothing above it does not read as a
	# doorway, it reads as a prop standing in a hole.
	#
	# ⚠️ It is STATIC, not on the hinge. A transom is part of the wall; one that swung with the
	# leaf would be the single thing a door frame may never do (Issue 79's shape, on the
	# Corridor's architraves).
	var gap := door_height - (LEAF_H + 0.1)
	if gap > 0.02:
		var transom := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(door_width + JAMB_T * 2.0, gap, FRAME_D)
		transom.mesh = tm
		transom.name = "Transom"
		transom.position = Vector3(0.0, LEAF_H + 0.1 + gap * 0.5, 0.0)
		transom.set_surface_override_material(0, frame_mat)
		add_child(transom)
		# Solid, and always — the gap above a door is not a route at any door state.
		var tbody := StaticBody3D.new()
		tbody.name = "TransomBody"
		add_child(tbody)
		var tcol := CollisionShape3D.new()
		var tshape := BoxShape3D.new()
		tshape.size = Vector3(door_width + JAMB_T * 2.0, gap, FRAME_D)
		tcol.shape = tshape
		tcol.position = Vector3(0.0, LEAF_H + 0.1 + gap * 0.5, 0.0)
		tbody.add_child(tcol)


# ⭐ TWO LEAVES, NOT ONE (2026-09-03) — and it is not decoration.
#
# ⚠️ WHAT FORCED IT. Sizing the door to its doorway (1.1 m -> 1.8 m Breach, 2.2 m Dungeon) fixed
# the seal and immediately broke something else: a single leaf that wide, swung OPEN_DEG into the
# room, sweeps **1.77 m** of a 3 m corridor and parks its own centre 1.06 m off the doorway
# axis. `check_interact_reach.gd` caught it as "SlamDoor answers 25 deg off-axis: ray sees
# nothing" — the probe stands 2.7 m back from the ART, and the art had moved so far into the room
# that the standing position was inside a wall. That is a real complaint about the door, not
# about the test: an open door is not supposed to occupy half the corridor you are running down.
#
# Two leaves of `door_width / 2`, hinged on opposite jambs, fix all of it at once:
#   * the sweep halves back to 0.90 m (Breach) / 1.10 m (Dungeon) — the old single leaf's 1.08 m
#   * the art stays centred on the doorway whether open or closed
#   * the closed pair still spans the FULL opening, which is the whole point of the resize
#   * and it matches the artwork, which is literally a double blast door with a centre seam
#
# ⚠️ `_hinge` stays the LEFT leaf so `interact()`'s existing tween and `check_interact_reach.gd`'s
# `_art_centre()` (which looks for a mesh under `_hinge`) keep working; `_hinge_r` mirrors it and
# is tweened alongside.
func _build_visual() -> void:
	var half := door_width * 0.5

	# ⚠️ ART ON A QuadMesh, EDGE ON A BoxMesh. A BoxMesh does not map a whole texture per face —
	# it renders a magnified CROP of its own art, which is Issue 24 and its recurrence Issue 31.
	# `door.gd:build_visual()` is the pattern; this class deliberately does not USE door.gd (its
	# UnlockCondition/extra_lock machinery is baggage here) but it must follow the same rule.
	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.09, 0.085, 0.08)
	edge_mat.metallic = 0.4
	edge_mat.roughness = 0.6

	var tex_path: String = door_texture if door_texture != "" else TEX_BREACH
	var tex: Texture2D = load(tex_path) if ResourceLoader.exists(tex_path) else null

	_hinge = _build_leaf(-1.0, half, edge_mat, tex)
	_hinge_r = _build_leaf(1.0, half, edge_mat, tex)
	# ⚠️ DEFERRED, not here: CSG colliders are NOT registered during `_ready()` (Issue 52), so a
	# ray fired now hits nothing and approves every direction.
	get_tree().create_timer(1.5).timeout.connect(_pick_clear_swings)


# ⭐ EACH LEAF SWINGS WHICHEVER WAY IS ACTUALLY CLEAR (2026-09-03).
#
# ⚠️ WHY. THE NIGHTMARE generates its layout, so a doorway can land at a CORNER — a wall running
# along the door's own plane, and another perpendicular to it starting at the jamb. A leaf hinged
# on that jamb then swings straight into the perpendicular wall. Measured on seed 1, SIX of the
# 92 door-art quads sat at **0.0000 m** from a wall box, i.e. inside it: a door visibly sticking
# through masonry. `check_wall_overlap.gd` could not see this before only because SlamDoor had no
# artwork at all and therefore no quads to measure — the geometry was always wrong.
#
# The fix is one ray per leaf. Swing into the room that has space; if both sides are blocked,
# fold that leaf back to a shallow angle rather than pushing it through a wall.
const FOLDED_DEG := -20.0

func _pick_clear_swings() -> void:
	for pair in [[_hinge, -1.0], [_hinge_r, 1.0]]:
		var hinge: Node3D = pair[0]
		if not is_instance_valid(hinge):
			continue
		var side: float = pair[1]
		# ⚠️ A LADDER, NOT FOUR ANGLES (widened 2026-09-03 after a 40-seed sweep). The first
		# version tried only (+/-85, +/-20) and fell through to "hide this leaf's artwork" on
		# **250 of 1864 leaves — 13.4 %**, i.e. roughly one door in seven rendered a bare edge
		# slab beside its textured twin. In a GENERATED maze, corner doorways are common and a
		# 1.1 m leaf hinged on the jamb has a lot of ways to meet a perpendicular wall; four
		# candidates is simply not a search.
		#
		# ⚠️ It walks OUTWARD-TO-CLOSED on each side in turn, so a leaf takes the widest opening
		# it can and only tucks in when it has to. A shallow angle is not a failure: the leaf
		# lies inside its own door frame, which is what a real door in a tight corner does.
		var ladder: Array[float] = []
		# ⚠️ THE RUNGS BETWEEN 85 AND 60 EXIST BECAUSE 85 IS NEVER REACHABLE. Measured by
		# `probe_door_swing.gd`: **62 of 62 leaves** across the Breach and a seeded Dungeon
		# rejected +/-85 and took +/-60 — every single one, which is a structural refusal rather
		# than bad luck. A leaf hinged on the jamb at 85 deg lies 5 deg off the wall plane, so for
		# a 1.1 m leaf its far tip sits ~0.10 m from that plane, and the wall is 0.2 m thick:
		# the tip is inside the masonry by construction and no doorway anywhere can accept it.
		# The ladder was therefore falling a full 25 deg in one step, and every open door in both
		# levels stood a quarter of its own width further into the opening than intended.
		# ⚠️ `OPEN_DEG` is NOT changed — it is still the intent, and it is still tried first, so a
		# thinner wall or an inset hinge would start using it again with no edit here.
		for deg in [OPEN_DEG, -78.0, -72.0, -66.0, -60.0, -40.0, -22.0, -10.0]:
			ladder.append(deg * -side)
			ladder.append(-deg * -side)
		var chosen: float = ladder[ladder.size() - 1]
		var fitted := false
		for cand in ladder:
			if _leaf_fits_at(hinge, cand):
				chosen = cand
				fitted = true
				break
		hinge.rotation_degrees.y = chosen
		hinge.set_meta("open_deg", chosen)
		hinge.set_meta("fitted", fitted)
		# ⚠️ LAST RESORT, and it should now be rare. If not one angle on the ladder fits, the
		# leaf is in a doorway with solid wall on both sides and there is nowhere for it to go.
		# Drop its ARTWORK rather than leave a textured panel embedded in masonry — the plain
		# edge slab still reads as a door edge, and nothing z-fights.
		# ⚠️ Measured before the ladder was widened: this fired on 13.4 % of leaves across 40
		# generated seeds. If it climbs back toward that, the ladder is the thing to look at, not
		# this branch.
		if not fitted:
			for q in _art_quads(hinge):
				q.visible = false


# ⚠️⚠️ MEASURE THE LEAF WHERE IT ACTUALLY IS, not where trigonometry says it will be. The first
# two attempts predicted the swept position from the hinge and an angle, and both were wrong in
# ways that were invisible: doors here carry a level-supplied `rotation.y` of 0 or PI/2, the leaf
# panel is offset inside its own hinge, and the art quads are offset again inside the panel. So:
# set the rotation, force the transforms, and ask where the QUADS are.
#
# ⚠️ POINT QUERIES, NOT RAYS — Issue 59. The hinge sits ON the jamb, i.e. inside the wall slab,
# and CSG collides as a concave trimesh whose backfaces do not register: a ray that STARTS inside
# a CSG box reports a clear path straight through it. That measurement took the embedded-leaf
# count from 6 to 2 rather than to 0, and both survivors were leaves the ray had approved.
func _leaf_fits_at(hinge: Node3D, deg: float) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var before: float = hinge.rotation_degrees.y
	hinge.rotation_degrees.y = deg
	hinge.force_update_transform()
	for c in hinge.get_children():
		if c is Node3D:
			(c as Node3D).force_update_transform()
			for g in c.get_children():
				if g is Node3D:
					(g as Node3D).force_update_transform()
	var mine := _self_rids()
	var ok := true
	for q in _art_quads(hinge):
		var qm := q.mesh as QuadMesh
		var hw: float = (qm.size.x * 0.5 if qm else 0.4) * 0.85
		for f in [-hw, 0.0, hw]:
			var pt: Vector3 = q.global_transform * Vector3(f, 0.0, 0.0)
			var pq := PhysicsPointQueryParameters3D.new()
			pq.position = pt
			pq.collision_mask = 1
			pq.exclude = mine
			if not space.intersect_point(pq, 4).is_empty():
				ok = false
				break
		if not ok:
			break
	hinge.rotation_degrees.y = before
	hinge.force_update_transform()
	return ok


func _art_quads(hinge: Node3D) -> Array:
	var out: Array = []
	for c in hinge.get_children():
		for g in c.get_children():
			if g is MeshInstance3D and String(g.name).begins_with("DoorArt"):
				out.append(g)
	return out


func _self_rids() -> Array[RID]:
	var out: Array[RID] = [get_rid()]
	if is_instance_valid(_block_body):
		out.append(_block_body.get_rid())
	for c in get_children():
		if c is StaticBody3D:
			out.append((c as StaticBody3D).get_rid())
	return out


# One leaf. `side` -1 hinges on the left jamb and swings out to -z-ish; +1 mirrors it.
func _build_leaf(side: float, leaf_w: float, edge_mat: StandardMaterial3D,
		tex: Texture2D) -> Node3D:
	var hinge := Node3D.new()
	hinge.name = "Hinge%s" % ("L" if side < 0.0 else "R")
	hinge.position = Vector3(side * leaf_w, 0.0, 0.0)
	hinge.rotation_degrees.y = OPEN_DEG * -side
	add_child(hinge)

	var panel := MeshInstance3D.new()
	panel.name = "Leaf%s" % ("L" if side < 0.0 else "R")
	var pm := BoxMesh.new()
	pm.size = Vector3(leaf_w, LEAF_H, 0.06)
	panel.mesh = pm
	panel.position = Vector3(-side * leaf_w * 0.5, LEAF_H * 0.5, 0.0)
	panel.set_surface_override_material(0, edge_mat)
	hinge.add_child(panel)
	if _panel == null:
		_panel = panel

	if tex == null:
		return hinge
	var art_mat := StandardMaterial3D.new()
	art_mat.albedo_texture = tex
	art_mat.roughness = 0.85
	# ⚠️ UV-CROP RATHER THAN STRETCH, and each leaf takes ITS OWN HALF of the plate — the
	# artwork is a double door, so the left leaf samples u 0..0.5 and the right 0.5..1 and the
	# centre seam lands exactly where the two leaves meet. Hanging the whole plate on each leaf
	# would put two complete double-doors in one doorway. `check_art_aspect.gd` sweeps all nine
	# levels for exactly this and compares against pixel aspect x uv1_scale, which is why a crop
	# is a legitimate answer and a squash is not.
	var leaf_aspect: float = leaf_w / LEAF_H
	var half_tex_aspect: float = (float(tex.get_width()) * 0.5) / float(tex.get_height())
	var u := 0.5
	var u_off: float = 0.0 if side < 0.0 else 0.5
	var v := 1.0
	var v_off := 0.0
	if half_tex_aspect > leaf_aspect:
		var k: float = leaf_aspect / half_tex_aspect
		u = 0.5 * k
		u_off += 0.5 * (1.0 - k) * 0.5
	else:
		v = half_tex_aspect / leaf_aspect
		v_off = (1.0 - v) * 0.5
	art_mat.uv1_scale = Vector3(u, v, 1.0)
	art_mat.uv1_offset = Vector3(u_off, v_off, 0.0)
	# ⚠️ Emission through the TEXTURE and via MULTIPLY, at 0.08 — `door.gd`'s textured branch
	# verbatim. Godot's default emission_operator is ADD, which lays a flat wash over the artwork
	# (Issue 81), and this project's untextured door branch uses 1.5, which on a textured leaf
	# renders salmon pink at these light levels (Issue 21).
	art_mat.emission_enabled = true
	art_mat.emission_texture = tex
	art_mat.emission = Color(0.35, 0.33, 0.30)
	art_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	art_mat.emission_energy_multiplier = 0.08
	for face in [1.0, -1.0]:
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(leaf_w, LEAF_H)
		quad.mesh = qm
		quad.name = "DoorArt%s%s" % ["L" if side < 0.0 else "R",
			"Front" if face > 0.0 else "Back"]
		quad.position = Vector3(0.0, 0.0, face * 0.034)
		if face < 0.0:
			quad.rotation.y = PI
		quad.set_surface_override_material(0, art_mat)
		panel.add_child(quad)
	return hinge


# ⚠️ Player-reopenable (found 2026-07-24 playtest): interact() used to be one-way —
# once _closed, E did nothing, because the ONLY reopen path was the creature battering
# it via level_6_breach.gd::_tick_slam_doors(), which early-returns while the creature
# is still in PATROL (i.e. the whole familiarization window, or any time it hasn't
# noticed the player). Corridor1 <-> Junction1 has no bypass — a player who slammed it
# early softlocked themselves with no way back and no way forward. Toggling lets the
# player undo their own slam any time the creature isn't already mid-batter.
func interact() -> void:
	if _closed:
		if _battering:
			return   # the creature is already breaking it down; don't fight the tween
		_set_closed(false)   # player can reopen their own slam — see softlock note above interact()
		return
	# ⚠️ A BROKEN DOOR CANNOT BE RE-SLAMMED IMMEDIATELY (added 2026-09-07). `_break_open()` cleared
	# `_battering` and reopened the door, and E could close it again on the very next frame — so a
	# player could re-arm a 10 s block every 10 s for ever and Object 12 could never reach them.
	# Free, indefinite, zero panic. The door is broken; that is the diegetic reason it will not
	# latch again for a moment. ⚠️ It is a COOLDOWN, not a permanent disable: the door is still the
	# level's counter-play and taking it away entirely would be a different game.
	if _reslam_lock_t > 0.0:
		return
	_set_closed(true)
	slammed.emit()
	var player := get_tree().get_first_node_in_group("player")
	var fleeing: bool = false
	if player and player.has_method("get_horizontal_speed"):
		fleeing = player.get_horizontal_speed() > 3.0
	var slam := GameState.load_audio("door_slam")
	if slam:
		var pl := AudioStreamPlayer3D.new()
		pl.stream = slam
		pl.unit_size = 6.0
		pl.volume_db = 2.0 if fleeing else 0.0
		add_child(pl)
		pl.finished.connect(pl.queue_free)
		pl.play()


# Called by the level orchestrator once it determines this door is between the
# creature and its current target. Idempotent — repeated calls while already
# battering just keep the existing countdown.
func start_battering(creature: Node) -> void:
	if not _closed or _battering:
		return
	_battering = true
	_batter_t = batter_time
	_thud_t = 0.0
	if creature and creature.has_method("force_block"):
		creature.force_block(batter_time)


func check_blocks_path(from: Vector3, to: Vector3) -> bool:
	if not _closed:
		return false
	var col_shape := _collider.shape as BoxShape3D
	if not col_shape:
		return false
	var half := col_shape.size * 0.5
	# ⚠️⚠️ ONLY THE Y OFFSET IS SUBTRACTED, AND THAT IS DELIBERATE — it looks like an oversight
	# and is not (verified 2026-09-07 by making the "obvious fix" and watching
	# `check_level6_breach.gd` go red on three doors).
	#
	# `_collider` is the WIDE INTERACT volume, which `_ready()` pushes 0.223 m INTO THE ROOM so the
	# player can reach it past the swinging leaves. Subtracting only `.y` leaves the tested box
	# centred on the DOORWAY PLANE (local z = 0), which is the thing a path test is about; also
	# subtracting `.z` would slide the test volume off the doorway and into the room, and start
	# reporting a door as blocking paths that merely pass in front of it.
	var local_from := to_local(from)
	local_from.y -= _collider.position.y
	var local_to := to_local(to)
	local_to.y -= _collider.position.y
	var aabb := AABB(-half, col_shape.size)
	# ⚠️ AABB.intersects_segment() returns a VARIANT, not a bool — the intersection
	# POINT (Vector3) on a hit and null on a miss. Returning it straight out of a
	# `-> bool` function is a hard runtime type error, which drops the game window:
	# every SlamDoor crashed the level the moment the player slammed one AND Object 12
	# left PATROL (the two guards above). Found 2026-07-27 in the user's own Godot logs;
	# the BackDoor/ExitDoor "worked" only because door.gd has no check_blocks_path.
	return aabb.intersects_segment(local_from, local_to) != null


func _process(delta: float) -> void:
	if _reslam_lock_t > 0.0:
		_reslam_lock_t = maxf(0.0, _reslam_lock_t - delta)
	if not _battering:
		return
	_batter_t -= delta
	_thud_t -= delta
	if _thud_t <= 0.0:
		_thud_t = THUD_INTERVAL
		if _batter_audio.stream:
			_batter_audio.play()
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("jolt_camera"):
			player.jolt_camera(0.05, 0.3)
	if _batter_t <= 0.0:
		_break_open()


func _break_open() -> void:
	_battering = false
	_batter_t = 0.0
	_reslam_lock_t = RESLAM_COOLDOWN
	_set_closed(false)
	broken_open.emit()
	var brk := GameState.load_audio("door_break")
	if brk:
		var pl := AudioStreamPlayer3D.new()
		pl.stream = brk
		pl.unit_size = 6.0
		add_child(pl)
		pl.finished.connect(pl.queue_free)
		pl.play()


func _set_closed(v: bool) -> void:
	_closed = v
	_block_collider.disabled = not v
	# ⚠️ -100.0 was a LITERAL here while `OPEN_DEG` was the constant everywhere else — the two
	# disagreed the moment OPEN_DEG moved, so a reopened door stood at a different angle from a
	# door that had never been slammed. Both now come from the leaf's own chosen angle.
	var target_deg: float = 0.0 if v else float(_hinge.get_meta("open_deg", OPEN_DEG))
	var tween := create_tween()
	# ⚠️ BOTH leaves, and each REOPENS TO THE ANGLE IT CHOSE. `_pick_clear_swings()` may have
	# flipped or folded a leaf because the wall beside it was solid; reopening to a constant
	# would put it straight back through that wall on the first reopen.
	if is_instance_valid(_hinge_r):
		var open_r: float = float(_hinge_r.get_meta("open_deg", OPEN_DEG * -1.0))
		var tw_r := create_tween()
		tw_r.tween_property(_hinge_r, "rotation_degrees:y",
			0.0 if _closed else open_r, 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hinge, "rotation_degrees:y", target_deg, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
