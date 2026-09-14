extends StaticBody3D
# C2 (2026-09-14): the counter bell on the reception nook's desk. E rings it, once; the beat
# (`spur_bell.gd`) owns everything that follows. Prop emits, level decides.
var beat: Node = null
var _rung: bool = false


func can_interact() -> bool:
	return not _rung


func prompt_text() -> String:
	return "E — ring the bell"


func interact() -> void:
	if _rung:
		return
	_rung = true
	if beat and beat.has_method("ring"):
		beat.ring()
