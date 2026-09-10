extends StaticBody3D
class_name WallSheet

# A pinned KONTUR notice covering something. Press E and it tears off the wall and falls, revealing
# whatever was behind it. KONTUR Gate 2 (2026-09-09, the user's design, captures #5/#6): the shelf
# shows only WRONG agents (bleach / poison / water); the vinegar is hidden behind one of these, with
# NO hint — just the E prompt, so the player tries it and guesses.
#
# Layer 2 / mask 0 (note.gd's convention): the interaction ray hits it, but the player walks through
# it rather than into it. No text overlay — this is a cover, not a reading.

signal torn

const LAYER := 2

# ⚠️ 2026-09-09 (cap #2): a WallSheet can now carry a real REDACTED SIGN texture instead of the
# "НЕ ВСКРЫВАТЬ" label, so KONTUR Gate 2's own "APPROVED AGENT" sign becomes the tear-away cover —
# "hidden in the space behind that sign". Set `sign_texture_path` (+ `sheet_size` for the sign's
# dimensions) before add_child; leave it empty for the generic pinned notice.
var sign_texture_path: String = ""
var sheet_size: Vector2 = Vector2(0.5, 0.68)

var _torn: bool = false


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	_build()


func _build() -> void:
	var paper := MeshInstance3D.new()
	paper.name = "Paper"
	var q := QuadMesh.new()
	q.size = sheet_size
	paper.mesh = q
	var m := StandardMaterial3D.new()
	var tex: Texture2D = null
	if sign_texture_path != "" and ResourceLoader.exists(sign_texture_path):
		var loaded := load(sign_texture_path)
		if loaded is Texture2D:
			tex = loaded
	if tex:
		# The redacted sign, sized from its own artwork (like kontur.gd:_make_sign) so it reads as
		# the same institutional notice the rest of the level uses — MULTIPLY emission at the signs'
		# 0.40, not Godot's default ADD (Issue 81).
		q.size = Vector2(sheet_size.y * float(tex.get_width()) / float(tex.get_height()), sheet_size.y)
		m.albedo_texture = tex
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
		m.emission_energy_multiplier = 0.40
	else:
		# ⚠️ DARK paper, no emission — near-white is the brightest paint in this renderer (Issue 63),
		# and a self-lit notice in a room at ambient 0.02 would be the brightest object in it.
		m.albedo_color = Color(0.22, 0.21, 0.18)
	m.roughness = 0.92
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.set_surface_override_material(0, m)
	paper.position.z = 0.012
	add_child(paper)

	if tex == null:
		# A header so it reads as an institutional notice rather than a blank card. It says nothing
		# about what is behind it — "DO NOT OPEN" is exactly the invitation.
		var lbl := Label3D.new()
		lbl.name = "SheetHeader"
		lbl.shaded = true
		lbl.text = "К.О.Н.Т.У.Р.\nНЕ ВСКРЫВАТЬ"
		lbl.font_size = 44
		lbl.pixel_size = 0.0011
		lbl.modulate = Color(0.52, 0.48, 0.42)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector3(0, 0.12, 0.02)
		add_child(lbl)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3((paper.mesh as QuadMesh).size.x, (paper.mesh as QuadMesh).size.y, 0.08)
	col.shape = shape
	add_child(col)


func interact() -> void:
	if _torn:
		return
	_torn = true
	# Stop intercepting the ray at once, so what is revealed behind it is reachable while it falls.
	collision_layer = 0
	torn.emit()
	# It comes off the wall and drops.
	var t := create_tween()
	t.tween_property(self, "position:y", position.y - 0.9, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "rotation:z", deg_to_rad(38.0), 0.5)
	t.tween_callback(queue_free)


# Resume path: the notice was already torn on an earlier visit. Silent removal.
func mark_torn() -> void:
	_torn = true
	queue_free()
