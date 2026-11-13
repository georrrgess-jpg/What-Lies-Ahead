extends Node3D
## Lava Lagoon: gives a model's "LavaMolten" surfaces (crater pool, lava
## streams, the Kahuna head's eyes, the cave's glowing seams) the animated
## lava shader. One material is shared by every model.

const SHADER := preload("res://art/shaders/lava_flow.gdshader")

static var _material: ShaderMaterial


func _ready() -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("flow", Vector2(0.0, 0.05))
		_material.set_shader_parameter("fall", 0.9)
		_material.set_shader_parameter("scale", 0.12)
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m and m.resource_name == "LavaMolten":
				mi.set_surface_override_material(i, _material)
