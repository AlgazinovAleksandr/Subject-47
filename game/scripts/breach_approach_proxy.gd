extends StaticBody3D

# An interact volume for `breach_approach.gd` (2026-09-23 pass 3): the dead technician and the
# porthole door's wheel. It owns NO logic. The player's real E ray hits this body,
# `player.gd:_try_interact()` calls `interact()`, and the approach decides what happens. That
# keeps the one story channel, the beat log and the snapshot in a single file.
#
# ⚠️ LAYER 2, like `note.gd`'s volumes: the interact ray hits it, but movement ignores it. The
# SOLID collider of whatever it sits on is a separate layer-1 body, sized a few cm SMALLER, so
# the ray meets this volume first. A tie would be decided arbitrarily by the physics server.

var on_interact: Callable
var can: Callable
var prompt: Callable


func interact() -> void:
	if on_interact.is_valid():
		on_interact.call()


func can_interact() -> bool:
	return can.call() if can.is_valid() else true


func prompt_text() -> String:
	return String(prompt.call()) if prompt.is_valid() else "Press E"
