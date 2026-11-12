extends OmniLight3D
## Campfire light: the energy and colour waver like burning logs.

var _base_energy := 1.0
var _base_color := Color.WHITE
var _time := 0.0


func _ready() -> void:
	_base_energy = light_energy
	_base_color = light_color
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	var f := sin(_time * 9.0) * 0.5 + sin(_time * 23.0 + 1.3) * 0.3 + sin(_time * 3.1) * 0.4
	light_energy = _base_energy * (1.0 + f * 0.12)
	light_color = _base_color.lerp(Color(1.0, 0.42, 0.14), 0.15 + f * 0.1)
