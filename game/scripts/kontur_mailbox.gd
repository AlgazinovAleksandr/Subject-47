extends StaticBody3D
class_name KonturMailbox

# KONTUR Landing's mailbox. The level (kontur.gd:_spawn_mailbox) builds the mesh and
# collider as children and sets `hint_text` — this script only owns the interaction,
# the same division of labor as key_item.gd and offering_pedestal.gd.
#
# Rebuilt 2026-07-25 from a flat photo-decal into a real 12-slot bank (playtest
# capture #4). Only SLOT 12 opens: `door_hinge` is handed over by the builder, and
# the first interact() swings it before the note appears, so the note reads as having
# come OUT of the box rather than off the wall. Re-reading afterwards leaves the door
# open — the box has already been opened; closing it again would be a lie.
#
# ⚠️ THE SWING USED TO BE INVISIBLE (fixed 2026-08-16). interact() started the Tween and
# then called NoteUI.show_note() on the very next line — and show_note() PAUSES THE TREE. A
# Tween does not advance until the following frame, and while the tree is paused that frame
# never arrives, so the door sat shut behind the fullscreen note and only swung after the
# player closed it. Four lines below a header that describes the opposite behaviour. The
# note is now fired from the tween's `finished`: open, then see, then read.
#
# ⚠️ THE SLOT IS STIFF, and deliberately not a minigame. `PRESSES_NEEDED` presses on E, each
# one groaning and shifting the door a couple of degrees before it springs back, then it
# gives. No bar, no timer, no failure — this is the `LightSwitch.presses_needed` idiom the
# Intro ward established (a stuck switch is frightening at zero mechanical cost), NOT
# lab_locker.gd's tug-of-war. There is nothing to lose here and nothing to be good at; the
# resistance exists so that a mailbox nobody has opened in thirty years opens like one.

@export var hint_text: String = ""

const OPEN_ANGLE_DEG := -105.0
const SWING_TIME := 0.35

# Total presses to open. Two that stick, one that gives.
const PRESSES_NEEDED := 3
const STICK_ANGLE_DEG := -7.0     # how far the jammed door shifts before springing back
const STICK_TIME := 0.13

# Set by the builder, not exported — it is a node from the mesh this script does not
# construct, so there is nothing sensible to point an inspector path at.
var door_hinge: Node3D = null
# capture #1: where the page rests once the slot is open (slot-12 local centre + cell size), so
# the player SEES the paper sitting there and takes it with a separate E — the lab-cabinet /
# sunken-item "open, then take" beat, one step further than the old "open and the note pops".
var paper_anchor: Vector3 = Vector3.ZERO
var cell_size: Vector2 = Vector2(0.3, 0.3)

var _opened: bool = false
var _presses: int = 0
var _shift: Tween = null      # the stuck-press wobble; kept only so a new press can kill it
var _paper: Node3D = null     # the page resting in the open slot, until taken
var _note_taken: bool = false


func interact() -> void:
	if _note_taken:
		# Already read: the page is on the HUD/journal now; re-show it on demand.
		NoteUI.show_note(hint_text)
		return
	if _opened:
		# The slot is open and the page is sitting in it — this press TAKES it.
		_take_paper()
		return
	_presses += 1
	if _presses < PRESSES_NEEDED:
		_stick()
		return
	_opened = true
	_swing_open()


# It moves, and it does not open. The shift is what stops a stuck slot reading as a broken
# game: the press unambiguously registered, and only the RESULT failed to arrive —
# light_switch.gd's plate-blip, in metal.
func _stick() -> void:
	_play_creak(1.35, -5.0)
	if not is_instance_valid(door_hinge):
		return
	# ⚠️ A rapid second press must COUNT, not be swallowed. Killing the running tween and
	# starting a new one is what makes mashing feel like tugging at a jammed door; an
	# `if _busy: return` guard here reads as the game ignoring you, which is the one thing a
	# deliberately-stiff prop cannot afford (light_switch.gd's blip exists for the same
	# reason). The tween handle is kept solely so it can be killed.
	if _shift and _shift.is_valid():
		_shift.kill()
	_shift = create_tween()
	_shift.set_trans(Tween.TRANS_QUAD)
	_shift.tween_property(door_hinge, "rotation_degrees:y", STICK_ANGLE_DEG, STICK_TIME)
	_shift.tween_property(door_hinge, "rotation_degrees:y", 0.0, STICK_TIME * 1.6)


func _swing_open() -> void:
	_play_creak(1.0, -2.0)
	if not is_instance_valid(door_hinge):
		# No hinge to watch (a stripped test rig): reveal the page immediately so the
		# open-then-take flow still has something to take.
		_reveal_paper()
		return
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(door_hinge, "rotation_degrees:y", OPEN_ANGLE_DEG, SWING_TIME)
	# ⚠️ Connected, not awaited, and NOT called on the next line — see the header. The page
	# appears AFTER the door finishes swinging, so you open the box and THEN see the paper.
	t.finished.connect(_reveal_paper)


# The page becomes visible, resting just inside the open slot. It is not read yet — the next E
# takes it (capture #1: "make it show to me first so then I will pick it up").
func _reveal_paper() -> void:
	if not is_inside_tree() or _note_taken or _paper != null:
		return
	var paper := MeshInstance3D.new()
	paper.name = "MailboxPage"
	var q := QuadMesh.new()
	# ⚠️ 2026-09-09 (cap #1): the page was tiny and dim inside a dark slot — "the note was not
	# visible". Now it nearly fills the slot, STICKS OUT of the mouth like a letter, and is bright
	# enough to read in the dark. Sized to the cell, proud of the face, tilted forward.
	q.size = Vector2(minf(cell_size.x * 0.82, 0.22), minf(cell_size.y * 0.95, 0.28))
	paper.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.83, 0.74)   # pale paper
	var page_tex := _page_texture()
	if page_tex:
		m.albedo_texture = page_tex
	m.emission_enabled = true                   # catches the eye in the dark slot
	m.emission = Color(0.80, 0.77, 0.68)
	if page_tex:
		m.emission_texture = page_tex
	m.emission_energy_multiplier = 0.55
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	paper.material_override = m
	# paper_anchor is the slot's local centre at the face plane; push the page OUT of the mouth
	# (+z local) and tilt it forward so it reads as a letter sitting in the open slot.
	paper.position = paper_anchor + Vector3(0, cell_size.y * 0.06, 0.06)
	paper.rotation_degrees = Vector3(20, 0, 0)
	add_child(paper)
	_paper = paper


# A simple aged-paper look for the page, reusing note.gd's paper_material if present so it matches
# every other page in the game; otherwise the plain cream albedo above carries it.
func _page_texture() -> Texture2D:
	var p := "res://assets/textures/level_5_kontur/kontur_note_page.png"
	if ResourceLoader.exists(p):
		var t := load(p)
		if t is Texture2D:
			return t
	return null


func _take_paper() -> void:
	if _note_taken:
		return
	_note_taken = true
	if is_instance_valid(_paper):
		_paper.queue_free()
	_paper = null
	_play_creak(1.2, -6.0)             # the small rustle of lifting it out
	# ⚠️ ARCHIVE IT (P2-D5, 2026-09-09). This is a Gate-7 hint in the one level whose whole
	# fairness net is the TAB journal, and for its entire life it was shown once and never
	# recorded — the player could not re-read it two gates later at the Blackout. It is not a
	# trap note, so record_note is safe, and GameState.record_note de-dupes, so re-opening the
	# box (the resume path) does not double-file it.
	GameState.record_note(hint_text, GameState.current_level)
	NoteUI.show_note(hint_text)


func is_open() -> bool:
	return _opened


func presses_made() -> int:
	return _presses


# `metal_creak` (sourced, converted from FLAC 2026-08-16) if it is there, otherwise the
# generic door creak this prop used before it existed.
func _play_creak(pitch: float, vol: float) -> void:
	var s := GameState.load_audio("metal_creak")
	if not s:
		s = GameState.load_audio("creak")
	if not s:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.unit_size = 5.0
	p.volume_db = vol
	p.pitch_scale = pitch
	add_child(p)
	if is_instance_valid(door_hinge):
		p.position = door_hinge.position
	p.finished.connect(p.queue_free)
	p.play()
