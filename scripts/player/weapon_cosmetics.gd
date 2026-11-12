class_name WeaponCosmetics
extends RefCounted
## Applies equipped mastery rewards to a weapon model (viewmodel or armory
## preview). Weapon models follow one naming contract:
##   materials  "Shell" (main colour), "Trim" (panels), "Cell" (energy cell)
##   node       "Decal" (emblem mesh, hidden unless a decal is equipped)

static func apply(model: Node3D, _weapon: WeaponData, equipped: Dictionary) -> void:
	var finish: MasteryReward = equipped.get("finish")
	var cell: MasteryReward = equipped.get("cell")
	var decal: MasteryReward = equipped.get("decal")
	_walk(model, finish, cell)
	var decal_node := model.find_child("Decal", true, false) as MeshInstance3D
	if decal_node:
		decal_node.visible = decal != null
		if decal:
			var m := StandardMaterial3D.new()
			m.albedo_color = decal.color
			m.roughness = 0.35
			m.emission_enabled = true
			m.emission = decal.color
			m.emission_energy_multiplier = 0.35
			decal_node.material_override = m


static func _walk(node: Node, finish: MasteryReward, cell: MasteryReward) -> void:
	if node is MeshInstance3D and node.mesh:
		var mi: MeshInstance3D = node
		for i in mi.mesh.get_surface_count():
			var base := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			var mat_name := String(base.resource_name)
			var replacement: StandardMaterial3D = null
			if mat_name == "Shell" and finish:
				replacement = base.duplicate()
				replacement.albedo_color = finish.color
				replacement.metallic = finish.metallic
				replacement.roughness = finish.roughness
			elif mat_name == "Trim" and finish:
				replacement = base.duplicate()
				replacement.albedo_color = finish.secondary_color
				replacement.metallic = finish.metallic * 0.8
				replacement.roughness = finish.roughness
			elif mat_name == "Cell" and cell:
				replacement = base.duplicate()
				replacement.albedo_color = cell.color
				replacement.emission_enabled = true
				replacement.emission = cell.color
			mi.set_surface_override_material(i, replacement)
	for child in node.get_children():
		_walk(child, finish, cell)
