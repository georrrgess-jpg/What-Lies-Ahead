class_name ExitLight
extends MeshInstance3D
## One marker light on the route to the portal. Dark until the portal opens,
## then the lights chase toward the exit in cyan.

## Position along the route; drives the chase animation.
@export var order := 0

var lit := false
var _material: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	add_to_group("exit_lights")
	_material = StandardMaterial3D.new()
	# Unlit: a dark inset panel that sits quietly in the deck.
	_material.albedo_color = Color(0.22, 0.17, 0.2)
	_material.roughness = 0.35
	_material.emission_enabled = true
	_material.emission = Color(0.2, 0.95, 1.0)
	_material.emission_energy_multiplier = 0.0
	material_override = _material
	set_process(false)


func set_lit(value: bool) -> void:
	lit = value
	set_process(value)
	_material.albedo_color = Color(0.2, 0.95, 1.0) if value else Color(0.22, 0.17, 0.2)
	_material.emission_energy_multiplier = 1.5 if value else 0.0


func _process(delta: float) -> void:
	_time += delta
	var wave := 0.5 + 0.5 * sin(_time * 5.0 - order * 0.7)
	_material.emission_energy_multiplier = 0.8 + wave * 2.2
