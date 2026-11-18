extends Node
## Royal Faire: re-dresses the instanced props the level generator marked
## (group "faire_dress", meta "faire_dress"; tools/build_royal_faire.gd).
## Castle stone gets the block texture, tents, awnings, banners and roofs
## their colours, and small props a draw range. Overrides on the children of an
## instanced model do not save with a scene, so the generator stores the wishes
## on each instance and this applies them once, when the level loads.

const STONE_TEXTURE := "res://art/textures/faire_stone.png"
const STONE_NORMAL := "res://art/textures/faire_stone_normal.png"
## World-projected scale of the stone blocks (as the generator's walls).
const STONE_SCALE := 0.42

var _stone: StandardMaterial3D
var _colours := {}


func _ready() -> void:
	for node in get_tree().get_nodes_in_group(&"faire_dress"):
		var wishes: Dictionary = node.get_meta(&"faire_dress", {})
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			_apply(mi as MeshInstance3D, wishes)


func _apply(mi: MeshInstance3D, wishes: Dictionary) -> void:
	if wishes.has("range"):
		mi.visibility_range_end = float(wishes["range"])
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i)
		if m == null or not wishes.has(m.resource_name):
			continue
		var wish: Variant = wishes[m.resource_name]
		mi.set_surface_override_material(i, _stone_material() if wish is String else _colour(wish))


func _stone_material() -> StandardMaterial3D:
	if _stone == null:
		_stone = StandardMaterial3D.new()
		_stone.albedo_texture = load(STONE_TEXTURE)
		_stone.uv1_triplanar = true
		_stone.uv1_world_triplanar = true
		_stone.uv1_scale = Vector3.ONE * STONE_SCALE
		_stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_stone.normal_enabled = true
		_stone.normal_texture = load(STONE_NORMAL)
		_stone.normal_scale = 0.8
		_stone.roughness = 0.85
	return _stone


func _colour(color: Color) -> StandardMaterial3D:
	if not _colours.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.6
		_colours[color] = m
	return _colours[color]
