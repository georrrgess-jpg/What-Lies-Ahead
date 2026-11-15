class_name CityFire
extends Node3D
## A burning fire for Ashfall City (scenes/props/city_fire.tscn): three crossed
## flame cards, rising embers, a smoke wisp and an optional flickering light.
## Cheap: every fire shares one mesh, one set of materials and one ember
## MultiMesh; the shaders animate them (seeded by position), and the only
## per-frame work is the light's flicker. Scale it with `size`, not the node.

const FLAME_SHADER := preload("res://art/shaders/city_fire.gdshader")
const EMBER_SHADER := preload("res://art/shaders/city_embers.gdshader")
const SMOKE_SHADER := preload("res://art/shaders/city_smoke.gdshader")
const EMBERS := 18

## Flame height in metres is about 1.6 x size.
@export var size := 1.0
@export var with_light := true
@export var light_color := Color(1.0, 0.52, 0.2)
@export var light_energy := 2.2
## Light range at size 1 (grows with size).
@export var light_range := 7.0
@export var with_embers := true
@export var with_smoke := true

static var _flame_mesh: QuadMesh
static var _flame_material: ShaderMaterial
static var _ember_multimesh: MultiMesh
static var _smoke_mesh: QuadMesh
static var _smoke_material: ShaderMaterial

var _light: OmniLight3D
var _embers: MultiMeshInstance3D
var _time := 0.0


func _ready() -> void:
	add_to_group("graphics_listener")
	_build_shared()
	_time = randf() * 10.0
	for k in 3:
		var flame := MeshInstance3D.new()
		flame.name = "Flame%d" % k
		flame.mesh = _flame_mesh
		flame.material_override = _flame_material
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.rotation.y = PI * k / 3.0
		flame.scale = Vector3.ONE * size
		add_child(flame)
	if with_smoke:
		var smoke := MeshInstance3D.new()
		smoke.name = "Smoke"
		smoke.mesh = _smoke_mesh
		smoke.material_override = _smoke_material
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		smoke.extra_cull_margin = 4.0 * size
		smoke.position.y = 1.0 * size
		smoke.scale = Vector3(2.4, 7.0, 1.0) * size
		add_child(smoke)
	if with_embers:
		_embers = MultiMeshInstance3D.new()
		_embers.name = "Embers"
		_embers.multimesh = _ember_multimesh
		_embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_embers.scale = Vector3.ONE * size
		_embers.custom_aabb = AABB(Vector3(-2, 0, -2), Vector3(4, 5, 4))
		add_child(_embers)
	if with_light:
		_light = OmniLight3D.new()
		_light.name = "Light"
		_light.light_color = light_color
		_light.light_energy = light_energy
		_light.omni_range = light_range * sqrt(size)
		_light.omni_attenuation = 1.4
		_light.shadow_enabled = false
		_light.position.y = 0.7 * size
		add_child(_light)
	apply_graphics_preset(Settings.is_low_graphics())


## Called through the "graphics_listener" group: embers are dropped on low graphics.
func apply_graphics_preset(low: bool) -> void:
	if _embers:
		_embers.visible = not low


func _process(delta: float) -> void:
	if _light == null:
		return
	_time += delta
	var f := sin(_time * 9.0) * 0.5 + sin(_time * 23.0 + 1.3) * 0.3 + sin(_time * 3.1) * 0.4
	_light.light_energy = light_energy * (1.0 + f * 0.14)


static func _build_shared() -> void:
	if _flame_mesh:
		return
	_flame_mesh = QuadMesh.new()
	_flame_mesh.size = Vector2(1.2, 1.7)
	_flame_mesh.center_offset = Vector3(0, 0.85, 0)
	_flame_material = ShaderMaterial.new()
	_flame_material.shader = FLAME_SHADER
	var ember_quad := QuadMesh.new()
	ember_quad.size = Vector2(2.0, 2.0)
	var ember_material := ShaderMaterial.new()
	ember_material.shader = EMBER_SHADER
	ember_quad.material = ember_material
	_ember_multimesh = MultiMesh.new()
	_ember_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_ember_multimesh.mesh = ember_quad
	_ember_multimesh.instance_count = EMBERS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	for i in EMBERS:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.4
		_ember_multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(cos(a) * r, 0.5 + rng.randf() * 0.4, sin(a) * r)))
	_smoke_mesh = QuadMesh.new()
	_smoke_mesh.size = Vector2.ONE
	_smoke_mesh.center_offset = Vector3(0, 0.5, 0)
	_smoke_material = ShaderMaterial.new()
	_smoke_material.shader = SMOKE_SHADER
	_smoke_material.set_shader_parameter("opacity", 0.55)
	_smoke_material.set_shader_parameter("speed", 0.12)
	_smoke_material.set_shader_parameter("under_glow", 0.35)
	_smoke_material.set_shader_parameter("lean", 0.35)
