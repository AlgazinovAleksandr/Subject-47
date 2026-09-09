extends StaticBody3D
class_name ArchiveLot

# One searchable lot in KONTUR's Recovery Archive (capture #8: "this room looks useless … you
# actually need to take the keycard to open another door … hide it somewhere, not simple to find").
#
# The Archive holds the gate-3 OFFERING — a keycard glowing on a pedestal that FORFEITS the run if
# taken. The bait. The REAL keycard is hidden in one of six inventory lots, and the only way to find
# it is to disturb them one by one against the room's own "DO NOT DISTURB THE INVENTORY" sign. Five
# hold their catalogued item and answer with a dry rattle and nothing else — the price of looking in
# the wrong place is the looking (kitchen/lab-cabinet lesson: no flavour text over an empty result).
# The sixth reveals the keycard, which a SEPARATE press then takes.
#
# ⚠️ ZERO panic, no fail state, no ScaryObject. Disturbing a lot is free; the cost is time and the
# transgression. The forfeit stays on the pedestal, not here.
#
# ⚠️ The builder (kontur.gd:_build_lot) sets `has_key` on exactly one lot per run — restored, never
# re-rolled, from the snapshot (KONTUR's _dark_x rule). It also gives this body a PROTRUDING interact
# collider on layer 2, because the aisle rack's own solid collider would otherwise intercept the ray
# before it reached a lot filed behind its front face (the shelf-collider lesson, bottle_item.gd).

signal searched(has_key)   # emitted once, on the first disturb; kontur.gd owns the consequence

var has_key: bool = false

var _searched: bool = false


func interact() -> void:
	if _searched:
		return
	_searched = true
	_nudge()               # visible feedback: the item is disturbed (no text — the shift IS the message)
	searched.emit(has_key)


# A small rummaged tilt + settle, so pressing E on a decoy clearly DID something even though there
# is nothing to find — the drawer-slide feedback of the Lab cabinet, in miniature.
func _nudge() -> void:
	var base_rot := rotation.y
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "rotation:y", base_rot + deg_to_rad(7.0), 0.12)
	t.parallel().tween_property(self, "position:y", position.y - 0.015, 0.12)
	t.tween_property(self, "rotation:y", base_rot + deg_to_rad(4.0), 0.18)


# Once disturbed, the lot is inert — E does literally nothing (player.gd consults this before it
# shows a prompt or sets an interact target). A decoy stays a rummaged shelf; the key lot hands off
# to the KeyItem the level spawns.
func can_interact() -> bool:
	return not _searched


func is_searched() -> bool:
	return _searched


# The resume path: a lot already searched on a prior visit comes back inert with no sound.
func mark_searched_instantly() -> void:
	_searched = true
