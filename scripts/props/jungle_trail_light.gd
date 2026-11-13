class_name JungleTrailLight
extends Node3D
## A torch stake on the trail to the exit portal at Lost Temple. Its flame
## globe burns a soft orange until the portal opens; then (as one of the
## "exit_lights" the portal switches on) the globes flare jade and chase toward
## the portal. Drives the model's "JungleTorchGlass" surface.

## Position along the route; drives the chase.
@export var order := 0

const IDLE_COLOR := Color(1.0, 0.62, 0.24)
const LIT_COLOR := Color(0.24, 1.0, 0.69)

var lit := false
var _material: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	add_to_group("exit_lights")
	_material = StandardMaterial3D.new()
	_material.emission_enabled = true
	for mi in find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m and m.resource_name == "JungleTorchGlass":
				(mi as MeshInstance3D).set_surface_override_material(i, _material)
	set_lit(false)


func set_lit(value: bool) -> void:
	lit = value
	set_process(value)
	var color := LIT_COLOR if value else IDLE_COLOR
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = 1.6 if value else 1.0


func _process(delta: float) -> void:
	_time += delta
	var wave := 0.5 + 0.5 * sin(_time * 5.0 - order * 0.7)
	_material.emission_energy_multiplier = 1.0 + wave * 3.0
