extends MeshInstance3D
## A jack-o'-lantern post on the trail to the exit portal at Ghost Train. It
## glows a soft orange until the portal opens; then (as one of the
## "exit_lights" the portal switches on) the lanterns flare toxic green and
## chase toward the portal. Drives the model's "FrightExitGlow" surface.

## Position along the route; drives the chase.
@export var order := 0

var lit := false
var _material: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	add_to_group("exit_lights")
	_material = StandardMaterial3D.new()
	_material.emission_enabled = true
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m and m.resource_name == "FrightExitGlow":
			set_surface_override_material(i, _material)
	set_lit(false)


func set_lit(value: bool) -> void:
	lit = value
	set_process(value)
	var color := Color(0.45, 1.0, 0.4) if value else Color(1.0, 0.62, 0.25)
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = 1.6 if value else 0.8


func _process(delta: float) -> void:
	_time += delta
	var wave := 0.5 + 0.5 * sin(_time * 5.0 - order * 0.8)
	_material.emission_energy_multiplier = 1.0 + wave * 3.0
