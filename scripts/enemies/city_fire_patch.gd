class_name CityFirePatch
extends Node3D
## Flames licking up from a burning patch of floor (the Firebug's bottle, the
## Wrecker's burning debris): a handful of crossed flame quads (the campfire
## flame shader, animated on the GPU) and a flickering light. They flare up,
## burn for `seconds`, then die down. Added as a child of the BossZone that
## does the damage, so they go with it.

const FLAME_SHADER := preload("res://art/shaders/frost_fire.gdshader")
const FLAMES := 6
const RISE := 0.25
const FADE := 0.6

var radius := 1.6
var seconds := 3.0

var _age := 0.0
var _flames: Array[Node3D] = []
var _light: OmniLight3D

static var _quad: QuadMesh
static var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(1.0, 1.0)
		_quad.center_offset = Vector3(0.0, 0.5, 0.0)
		for i in 3:
			var m := ShaderMaterial.new()
			m.shader = FLAME_SHADER
			m.set_shader_parameter(&"seed", float(i) * 0.37)
			m.set_shader_parameter(&"strength", 1.6)
			_materials.append(m)
	for i in FLAMES:
		var a := TAU * i / FLAMES + randf_range(-0.3, 0.3)
		var r := radius * (0.25 + 0.5 * randf()) if i > 0 else 0.0
		var flame := Node3D.new()
		flame.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		flame.rotation.y = randf() * PI
		for k in 2:
			var mi := MeshInstance3D.new()
			mi.mesh = _quad
			mi.material_override = _materials[(i + k) % _materials.size()]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.rotation.y = k * PI * 0.5
			flame.add_child(mi)
		add_child(flame)
		flame.scale = Vector3.ZERO
		flame.set_meta(&"size", randf_range(0.7, 1.15) * (1.3 if i == 0 else 1.0))
		_flames.append(flame)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.16)
	_light.omni_range = radius * 2.5
	_light.position.y = 0.6
	add_child(_light)


func _process(delta: float) -> void:
	_age += delta
	var k := minf(_age / RISE, 1.0) * clampf((seconds - _age) / FADE, 0.0, 1.0)
	for f in _flames:
		var s: float = f.get_meta(&"size") * k
		f.scale = Vector3(s * 0.9, s * 1.3, s * 0.9)
	_light.light_energy = k * (1.4 + 0.5 * sin(_age * 23.0) * sin(_age * 7.0))
	if _age >= seconds:
		queue_free()
