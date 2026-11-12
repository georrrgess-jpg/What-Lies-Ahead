class_name WeaponCosmetics
extends RefCounted
## Applies equipped weapon cosmetics to a weapon model (viewmodel or menu
## preview). Weapon models follow one naming contract:
##   materials  "Shell" (main colour), "Trim" (panels), "Cell" (energy glow)
##   node       "Decal" (emblem mesh, hidden unless a decal is equipped)
## `loadout` is Cosmetics.weapon_loadout(weapon_id): {finish, cell, decal, charm}.

static func apply(model: Node3D, _weapon: WeaponData, loadout: Dictionary) -> void:
	var finish: CosmeticItem = loadout.get("finish")
	var cell: CosmeticItem = loadout.get("cell")
	var decal: CosmeticItem = loadout.get("decal")
	_walk(model, finish, cell)
	var decal_node := model.find_child("Decal", true, false) as MeshInstance3D
	if decal_node:
		decal_node.visible = decal != null
		if decal:
			var m := StandardMaterial3D.new()
			m.albedo_color = decal.color(0)
			m.roughness = 0.35
			m.emission_enabled = true
			m.emission = decal.color(0)
			m.emission_energy_multiplier = 0.35
			decal_node.material_override = m


static func _walk(node: Node, finish: CosmeticItem, cell: CosmeticItem) -> void:
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
				replacement.albedo_color = finish.color(0)
				replacement.metallic = float(finish.params.get("metallic", 0.0))
				replacement.roughness = float(finish.params.get("roughness", 0.5))
			elif mat_name == "Trim" and finish:
				replacement = base.duplicate()
				replacement.albedo_color = finish.color(1, base.albedo_color)
				replacement.metallic = float(finish.params.get("metallic", 0.0)) * 0.8
				replacement.roughness = float(finish.params.get("roughness", 0.5))
			elif mat_name == "Cell" and cell:
				replacement = base.duplicate()
				replacement.albedo_color = cell.color(0)
				replacement.emission_enabled = true
				replacement.emission = cell.color(0)
			mi.set_surface_override_material(i, replacement)
	for child in node.get_children():
		_walk(child, finish, cell)
