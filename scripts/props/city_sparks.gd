class_name CitySparks
extends MultiMeshInstance3D
## Spark bursts from a shorting cable, lamp or the shock trap's coils
## (scenes/props/city_sparks.tscn). The city_sparks shader flies and fades each
## spark; this script only builds the shared MultiMesh and the node's material
## (its burst timing), so there is no per-frame work.

const SHADER := preload("res://art/shaders/city_sparks.gdshader")
const COUNT := 16

## Seconds between bursts.
@export var interval := 2.6
## Chance (0..1) a burst is skipped, for an irregular stutter.
@export var skip := 0.35
## Launch speed of the sparks (m/s); bigger throws them further.
@export var speed := 3.2

static var _multimesh: MultiMesh


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _multimesh == null:
		_multimesh = _build()
	multimesh = _multimesh
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("interval", interval)
	m.set_shader_parameter("skip", skip)
	m.set_shader_parameter("spread_speed", speed)
	material_override = m
	custom_aabb = AABB(Vector3(-3, -4, -3), Vector3(6, 6, 6))


static func _build() -> MultiMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = COUNT
	for i in COUNT:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
	return mm
