class_name JungleRain
extends MultiMeshInstance3D
## Monsoon rain for Lost Temple, drawn as one MultiMesh of thin streaks (no
## CPUParticles3D, which does not render on the Compatibility renderer). The
## jungle_rain shader moves each drop and wraps it around a box that follows
## the camera. JungleWeather sets `amount` (0 = dry, 1 = downpour).

const SHADER := "res://art/shaders/jungle_rain.gdshader"

@export var drops := 3200
@export var low_detail_drops := 1400
@export var box_size := Vector3(36.0, 20.0, 36.0)
## Roofed volumes (world space) the rain does not fall in; at most 8.
@export var shelters: Array[AABB] = []

var _material: ShaderMaterial


func _ready() -> void:
	add_to_group("graphics_listener")
	add_to_group("jungle_rain")
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The drops are placed by the shader around the camera: never cull them.
	custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER)
	_material.set_shader_parameter("box_size", box_size)
	_apply_shelters()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.material = _material
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = drops
	for i in drops:
		var seed_pos := Vector3(rng.randf() * box_size.x, rng.randf() * box_size.y, rng.randf() * box_size.z)
		mm.set_instance_transform(i, Transform3D(Basis(), seed_pos))
	multimesh = mm
	set_amount(0.0)
	apply_graphics_preset(Settings.is_low_graphics())


## Share of the drops that fall (0..1); hidden entirely when dry.
func set_amount(value: float) -> void:
	_material.set_shader_parameter("amount", value)
	visible = value > 0.001


## Called by the settings screen through the "graphics_listener" group.
func apply_graphics_preset(low: bool) -> void:
	if multimesh:
		multimesh.visible_instance_count = low_detail_drops if low else -1


func _apply_shelters() -> void:
	var lows := PackedVector3Array()
	var highs := PackedVector3Array()
	for box in shelters.slice(0, 8):
		lows.append(box.position)
		highs.append(box.end)
	_material.set_shader_parameter("shelter_count", lows.size())
	# Uniform arrays are fixed size: pad to 8.
	lows.resize(8)
	highs.resize(8)
	_material.set_shader_parameter("shelter_min", lows)
	_material.set_shader_parameter("shelter_max", highs)
