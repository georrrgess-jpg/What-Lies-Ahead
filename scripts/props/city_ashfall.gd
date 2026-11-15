class_name CityAshfall
extends MultiMeshInstance3D
## Drifting ash over Ashfall City (scenes/props/city_ashfall.tscn), one
## MultiMesh of tiny quads (no particles node, which the Compatibility renderer
## does not draw). The flakes are placed once; the city_ash shader moves them
## and wraps them round a box that follows the camera, so the ash surrounds the
## view anywhere on the map. The script only swings the wind in slow gusts.

const SHADER := preload("res://art/shaders/city_ash.gdshader")

@export var flakes := 1800
@export var low_detail_flakes := 700
@export var box_size := Vector3(44.0, 24.0, 44.0)
## Base wind (world XZ, m/s) and how far gusts swing it.
@export var wind := Vector2(0.8, 0.3)
@export var gust := 0.9

var _material: ShaderMaterial
var _time := 0.0


func _ready() -> void:
	add_to_group("graphics_listener")
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader places the flakes round the camera: never cull them.
	custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("box_size", box_size)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.material = _material
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = flakes
	for i in flakes:
		var seed_pos := Vector3(rng.randf() * box_size.x, rng.randf() * box_size.y, rng.randf() * box_size.z)
		mm.set_instance_transform(i, Transform3D(Basis(), seed_pos))
	multimesh = mm
	apply_graphics_preset(Settings.is_low_graphics())


## Called by the settings screen through the "graphics_listener" group.
func apply_graphics_preset(low: bool) -> void:
	if multimesh:
		multimesh.visible_instance_count = low_detail_flakes if low else -1


func _process(delta: float) -> void:
	_time += delta
	var g := sin(_time * 0.17) * 0.6 + sin(_time * 0.41 + 1.7) * 0.4
	_material.set_shader_parameter("wind", wind + Vector2(g, g * 0.4) * gust)
