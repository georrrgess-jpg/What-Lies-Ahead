extends Node3D
## Summit Lodge model: swaps the A-frame's glass wall (the "FrostGableGlass"
## surface exported from Blender) for an interior-mapped room, so the hall
## behind the glass has depth: a fireplace, a loft, roof beams and a chandelier.

const SHADER := "res://art/shaders/frost_lodge_interior.gdshader"


func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = load(SHADER)
	for node in find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m and m.resource_name == "FrostGableGlass":
				mi.set_surface_override_material(i, material)
