extends Node3D
## Root script for level scenes: applies the graphics preset to this level's
## environment, sun and optional dressing (nodes in group "high_detail").

@onready var world_environment: WorldEnvironment = get_node_or_null("WorldEnvironment")
@onready var sun: DirectionalLight3D = get_node_or_null("Sun")


const HALO_SHADER := "res://art/shaders/bulb_halo.gdshader"

var _halo_material: ShaderMaterial


func _ready() -> void:
	add_to_group("graphics_listener")
	_apply_halos(self)
	apply_graphics_preset(Settings.is_low_graphics())


## Swaps every "BulbHalo" surface (exported from Blender) for an additive glow,
## so the bulbs read as lit even without post-process bloom.
func _apply_halos(node: Node) -> void:
	if _halo_material == null:
		_halo_material = ShaderMaterial.new()
		_halo_material.shader = load(HALO_SHADER)
	if node is MeshInstance3D and node.mesh:
		var mi: MeshInstance3D = node
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m and m.resource_name == "BulbHalo":
				mi.set_surface_override_material(i, _halo_material)
	for child in node.get_children():
		_apply_halos(child)


func apply_graphics_preset(low: bool) -> void:
	if _halo_material:
		_halo_material.set_shader_parameter("strength", 0.4 if low else 0.55)
	if world_environment and world_environment.environment:
		world_environment.environment.glow_enabled = not low
	if sun:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if low else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 45.0 if low else 80.0
	for node in get_tree().get_nodes_in_group("high_detail"):
		if node is Node3D and is_ancestor_of(node):
			node.visible = not low
