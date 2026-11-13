class_name MallExitArrow
extends MeshInstance3D
## A floor chevron on Midnight Mall's route to the portal (one of the
## "exit_lights" the portal switches on). While the portal is shut it is a
## faint inlay that barely shows on the terrazzo; once it opens the arrows turn
## bright teal and chase toward the exit.

## Position along the route; drives the chase.
@export var order := 0

var lit := false
var _material: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	add_to_group("exit_lights")
	_material = StandardMaterial3D.new()
	_material.emission_enabled = true
	_material.roughness = 0.3
	material_override = _material
	set_lit(false)


func set_lit(value: bool) -> void:
	lit = value
	set_process(value)
	_material.albedo_color = Color(0.25, 0.95, 0.9) if value else Color(0.62, 0.58, 0.78)
	_material.emission = Color(0.25, 0.95, 0.9) if value else Color(0.45, 0.4, 0.7)
	_material.emission_energy_multiplier = 1.6 if value else 0.15


func _process(delta: float) -> void:
	_time += delta
	var wave := 0.5 + 0.5 * sin(_time * 5.0 - order * 0.7)
	_material.emission_energy_multiplier = 0.8 + wave * 2.6
