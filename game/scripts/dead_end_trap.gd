extends Area3D
class_name DeadEndTrap

# C1 (2026-09-13): the far end of a Corridor side passage. Walk into it once and it fires
# `sprung`; `corridor.gd:_on_spur_sprung` slams the mouth, kills the spur's torch and batters
# the door for ten seconds. One-shot. Zero panic of its own — a sensor, nothing more.

signal sprung

var _sprung := false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body)


func _on_body(b: Node) -> void:
	if _sprung or not b.is_in_group("player"):
		return
	_sprung = true
	sprung.emit()


func is_sprung() -> bool:
	return _sprung
