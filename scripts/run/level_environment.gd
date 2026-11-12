extends Node3D
## Root script for level scenes: applies the graphics preset to this level's
## environment, sun and optional dressing (nodes in group "high_detail").

@onready var world_environment: WorldEnvironment = get_node_or_null("WorldEnvironment")
@onready var sun: DirectionalLight3D = get_node_or_null("Sun")


func _ready() -> void:
	add_to_group("graphics_listener")
	apply_graphics_preset(Settings.is_low_graphics())


func apply_graphics_preset(low: bool) -> void:
	if world_environment and world_environment.environment:
		world_environment.environment.glow_enabled = not low
	if sun:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if low else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 45.0 if low else 80.0
	for node in get_tree().get_nodes_in_group("high_detail"):
		if node is Node3D and is_ancestor_of(node):
			node.visible = not low
