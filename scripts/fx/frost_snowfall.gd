class_name FrostSnowfall
extends MultiMeshInstance3D
## Falling snow for Summit Lodge, drawn as one MultiMesh of tiny quads (no
## CPUParticles3D, which does not render on the Compatibility renderer).
## The script builds the flakes once and drives the wind; the
## frost_snowfall shader moves each flake and wraps it around a box that
## follows the camera, so the snow surrounds the view wherever it goes.

const SHADER := "res://art/shaders/frost_snowfall.gdshader"

@export var flakes := 2600
@export var low_detail_flakes := 1100
@export var box_size := Vector3(40.0, 22.0, 40.0)
## Base wind (world XZ, m/s) and how far gusts swing it.
@export var wind := Vector2(0.7, 0.25)
@export var gust := 1.4

var _material: ShaderMaterial
var _time := 0.0


func _ready() -> void:
	add_to_group("graphics_listener")
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The flakes are placed by the shader around the camera, never cull them.
	custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER)
	_material.set_shader_parameter("box_size", box_size)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.material = _material
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
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
	# Slow gusts that lean the snowfall one way, then the other.
	var g := sin(_time * 0.21) * 0.6 + sin(_time * 0.53 + 1.7) * 0.4
	_material.set_shader_parameter("wind", wind + Vector2(g, g * 0.35) * gust)
