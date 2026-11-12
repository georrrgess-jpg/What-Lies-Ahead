class_name DuneRadCloud
extends Node3D
## The radioactive cloud a hazmat zombie leaves behind (see DuneRadBurstBehaviour).
##   1. Fuse: a glowing core swells and a ring on the ground marks the radius,
##      while a Geiger tick speeds up.
##   2. Burst: one hit to a player inside the ring.
##   3. Cloud: a churning dome that hurts every half second while you stand in it,
##      then fades away and frees itself.

const TICK := 0.5
const COLOR := Color(0.62, 1.0, 0.25)

var fuse := 1.1
var radius := 3.0
var burst_damage := 8.0
var cloud_seconds := 3.5
var damage_per_second := 4.0

var _time := 0.0
var _burst := false
var _tick := 0.0
var _beep := 0.0
var _core: MeshInstance3D
var _dome: MeshInstance3D
var _ring: MeshInstance3D
var _light: OmniLight3D
var _dome_material: ShaderMaterial
var _ring_material: StandardMaterial3D
var _puffs: MultiMeshInstance3D

static var _sphere: SphereMesh
static var _torus: TorusMesh
static var _puff_mesh: QuadMesh


func _ready() -> void:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 20
		_sphere.rings = 10
		_torus = TorusMesh.new()
		_torus.inner_radius = 0.94
		_torus.outer_radius = 1.0
		_torus.rings = 48
		_torus.ring_segments = 6
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	core_mat.albedo_color = Color(COLOR, 0.8)
	_core = _mesh(_sphere, core_mat)
	_core.position.y = 0.9
	_core.scale = Vector3.ONE * 0.3
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.albedo_color = COLOR
	_ring = _mesh(_torus, _ring_material)
	_ring.position.y = 0.06
	_ring.scale = Vector3(radius, 0.4, radius)
	_dome_material = ShaderMaterial.new()
	_dome_material.shader = load("res://art/shaders/dune_rad_cloud.gdshader")
	_dome_material.set_shader_parameter("noise_tex", load("res://art/textures/dune_noise.png"))
	_dome_material.set_shader_parameter("strength", 0.0)
	_dome = _mesh(_sphere, _dome_material)
	_dome.scale = Vector3(radius, radius * 0.7, radius)
	_dome.visible = false
	_puffs = _build_puffs()
	_light = OmniLight3D.new()
	_light.light_color = COLOR
	_light.light_energy = 0.8
	_light.omni_range = radius * 2.2
	_light.position.y = 1.0
	add_child(_light)


## Green vapour churning inside the dome (the same billboard puffs as the rocket's).
func _build_puffs() -> MultiMeshInstance3D:
	if _puff_mesh == null:
		_puff_mesh = QuadMesh.new()
		_puff_mesh.size = Vector2(2, 2)
		var m := ShaderMaterial.new()
		m.shader = load("res://art/shaders/dune_vapour.gdshader")
		m.set_shader_parameter("noise_tex", load("res://art/textures/dune_noise.png"))
		m.set_shader_parameter("lit_color", Color(0.75, 1.0, 0.35))
		m.set_shader_parameter("shadow_color", Color(0.2, 0.55, 0.25))
		m.set_shader_parameter("rise", 1.6)
		m.set_shader_parameter("life", 2.2)
		m.set_shader_parameter("size_start", 0.6)
		m.set_shader_parameter("size_end", 1.6)
		m.set_shader_parameter("opacity", 0.4)
		m.set_shader_parameter("drift", Vector3(0.6, 0.0, 0.0))
		_puff_mesh.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _puff_mesh
	mm.instance_count = 9
	for i in mm.instance_count:
		var a := TAU * i / mm.instance_count
		var r := radius * randf_range(0.2, 0.75)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, randf() * TAU), Vector3(cos(a) * r, 0.2, sin(a) * r)))
		mm.set_instance_custom_data(i, Color(float(i) / mm.instance_count, randf_range(0.85, 1.15), randf_range(0.8, 1.2), randf_range(0.5, 1.0)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-radius - 2.0, -1.0, -radius - 2.0), Vector3(radius * 2.0 + 4.0, 6.0, radius * 2.0 + 4.0))
	node.visible = false
	add_child(node)
	return node


func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	_time += delta
	if not _burst:
		_fuse_tick(delta)
		return
	var age := _time - fuse
	var fade := 1.0 - smoothstep(cloud_seconds - 0.8, cloud_seconds, age)
	_dome_material.set_shader_parameter("strength", smoothstep(0.0, 0.25, age) * fade)
	_ring_material.albedo_color = Color(COLOR * (0.6 + 0.3 * sin(_time * 6.0)), 1.0) * fade
	_light.light_energy = 1.4 * fade
	_puffs.visible = fade > 0.3
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_hurt(damage_per_second * TICK)
	if age >= cloud_seconds:
		queue_free()


func _fuse_tick(delta: float) -> void:
	var k := clampf(_time / fuse, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_time * (10.0 + 30.0 * k))
	_core.scale = Vector3.ONE * lerpf(0.3, 0.9, k) * (0.9 + 0.2 * pulse)
	_ring_material.albedo_color = COLOR * (0.5 + 0.8 * pulse)
	_light.light_energy = 0.6 + 1.6 * k * pulse
	_beep -= delta
	if _beep <= 0.0:
		_beep = lerpf(0.28, 0.07, k)
		Sfx.play_at(&"dune_geiger", global_position + Vector3.UP, -4.0, 1.0 + k * 0.4)
	if _time >= fuse:
		_burst = true
		_core.visible = false
		_dome.visible = true
		_puffs.visible = true
		Sfx.play_at(&"dune_rad_burst", global_position + Vector3.UP, 2.0)
		Fx.impact(get_parent(), global_position + Vector3.UP, Vector3.UP, COLOR)
		Fx.impact(get_parent(), global_position + Vector3.UP * 0.5, Vector3.UP, Color(0.9, 1.0, 0.4))
		_hurt(burst_damage)
		_tick = TICK


func _hurt(amount: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or not player.alive:
		return
	var d := player.global_position - global_position
	if Vector2(d.x, d.z).length() <= radius and absf(d.y) < 2.5:
		player.take_damage(amount, global_position)
