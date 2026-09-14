extends StaticBody3D
# C4: the blind room's release lever. E pulls it; the room decides.
var room: Node = null
var _pulled: bool = false


func can_interact() -> bool:
	return not _pulled


func prompt_text() -> String:
	return "E — pull the lever"


func interact() -> void:
	if _pulled:
		return
	_pulled = true
	if room and room.has_method("release"):
		room.call("release", "lever")
