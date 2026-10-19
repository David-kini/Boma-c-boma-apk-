extends Node3D
## Île flottante : monte et descend lentement en tournant un peu sur elle-même.

var amp: float = 2.0
var spd: float = 0.35
var _t: float = 0.0
var _y0: float = 0.0


func _ready() -> void:
	_y0 = position.y
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	position.y = _y0 + sin(_t * spd) * amp
	rotation.y += delta * 0.02
