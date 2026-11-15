class_name CityFlickerLight
extends Light3D
## Makes an Omni/Spot light in Ashfall City misbehave like the thing it lights:
##   fire    wavers like burning wreckage
##   neon    hums and, every few seconds, stutters off in a short burst
##           (matches the city_neon shader's rhythm, not its exact timing)
##   strobe  police double-flash, alternating `light_color` and `alt_color`
## Each light starts at a random phase so a street of them never pulses in step.

@export_enum("fire", "neon", "strobe") var mode := "fire"
## Second colour for "strobe" (police blue after red).
@export var alt_color := Color(0.2, 0.42, 1.0)
## Strobe cycles per second.
@export var rate := 1.4

var _base_energy := 1.0
var _base_color := Color.WHITE
var _time := 0.0
var _cycle := 8.0


func _ready() -> void:
	_base_energy = light_energy
	_base_color = light_color
	_time = randf() * 20.0
	_cycle = 6.0 + randf() * 5.0


func _process(delta: float) -> void:
	_time += delta
	match mode:
		"neon":
			var off := fmod(_time, _cycle) > _cycle - 1.5 and fmod(floor(_time * 14.0) * 0.618, 1.0) > 0.45
			light_energy = _base_energy * (0.94 + 0.06 * sin(_time * 47.0)) * (0.12 if off else 1.0)
		"strobe":
			var t := fmod(_time * rate, 1.0)
			var on := t < 0.09 or (t > 0.16 and t < 0.25)
			var second := fmod(_time * rate, 2.0) >= 1.0
			light_color = alt_color if second else _base_color
			light_energy = _base_energy if on else _base_energy * 0.08
		_:
			var f := sin(_time * 9.0) * 0.5 + sin(_time * 23.0 + 1.3) * 0.3 + sin(_time * 3.1) * 0.4
			light_energy = _base_energy * (1.0 + f * 0.13)
