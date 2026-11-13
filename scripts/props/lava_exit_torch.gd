extends Node3D
## A torch stake on the trail to the exit portal at Lava Lagoon. It burns a
## soft orange until the portal opens; then (as one of the "exit_lights" the
## portal switches on) the torches flare cyan and chase toward the portal.
## Drives the model's "LavaExitGlow" surfaces.

## Position along the route; drives the chase.
@export var order := 0

var lit := false
var _material: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	add_to_group("exit_lights")
	_material = StandardMaterial3D.new()
	_material.emission_enabled = true
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m and m.resource_name == "LavaExitGlow":
				mi.set_surface_override_material(i, _material)
	set_lit(false)


func set_lit(value: bool) -> void:
	lit = value
	set_process(value)
	var color := Color(0.25, 0.95, 1.0) if value else Color(1.0, 0.55, 0.22)
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = 1.6 if value else 0.5


func _process(delta: float) -> void:
	_time += delta
	var wave := 0.5 + 0.5 * sin(_time * 5.0 - order * 0.7)
	_material.emission_energy_multiplier = 1.0 + wave * 3.0
