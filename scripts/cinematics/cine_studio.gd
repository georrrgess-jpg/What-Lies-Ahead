class_name CineStudio
extends Node3D
## The showreel's purpose-built set: a dark carnival stage for the arsenal
## and the operator line-up. A glossy floor with neon rings, a turntable
## plinth, a giant marquee ring behind it, warm key and pink/cyan rims.
## Built from primitives (about a dozen draw calls), so it is ready at once.

const FLOOR := Color("120c2e")
const NAVY := Color("0b0820")


func _ready() -> void:
	name = "Studio"
	_environment()
	_floor()
	_plinth()
	_ring()
	_lights()


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = NAVY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4a3a8a")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("2a1550")
	env.fog_density = 0.035
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _mat(color: Color, emission := 0.0, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _mesh(mesh: Mesh, material: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)
	return mi


func _floor() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 14.0
	disc.bottom_radius = 14.0
	disc.height = 0.2
	disc.radial_segments = 48
	_mesh(disc, _mat(FLOOR, 0.0, 0.18, 0.4), Vector3(0, -0.1, 0))
	for r in [2.2, 4.6, 7.4]:
		var ring := TorusMesh.new()
		ring.inner_radius = r - 0.04
		ring.outer_radius = r + 0.04
		ring.rings = 64
		ring.ring_segments = 6
		_mesh(ring, _mat(UiKit.CYAN if r < 4.0 else UiKit.PINK, 2.6), Vector3(0, 0.01, 0)).scale = Vector3(1, 0.2, 1)


func _plinth() -> void:
	var base := CylinderMesh.new()
	base.top_radius = 1.05
	base.bottom_radius = 1.2
	base.height = 0.42
	base.radial_segments = 32
	_mesh(base, _mat(UiKit.METAL, 0.0, 0.35, 0.6), Vector3(0, 0.21, 0))
	var lip := TorusMesh.new()
	lip.inner_radius = 1.0
	lip.outer_radius = 1.1
	lip.rings = 48
	lip.ring_segments = 8
	_mesh(lip, _mat(UiKit.AMBER, 2.2), Vector3(0, 0.43, 0)).scale = Vector3(1, 0.4, 1)


func _ring() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 5.2
	ring.outer_radius = 5.6
	ring.rings = 72
	ring.ring_segments = 10
	_mesh(ring, _mat(UiKit.PINK, 3.0), Vector3(0, 3.2, -7.5), Vector3(90, 0, 0))
	var inner := TorusMesh.new()
	inner.inner_radius = 4.5
	inner.outer_radius = 4.62
	inner.rings = 72
	inner.ring_segments = 6
	_mesh(inner, _mat(UiKit.CYAN, 2.4), Vector3(0, 3.2, -7.6), Vector3(90, 0, 0))
	# Marquee bulbs around the big ring (one multimesh, one draw call).
	var bulb := SphereMesh.new()
	bulb.radius = 0.13
	bulb.height = 0.26
	bulb.radial_segments = 8
	bulb.rings = 4
	bulb.material = _mat(Color("ffe9a8"), 4.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bulb
	mm.instance_count = 40
	for i in 40:
		var a := TAU * float(i) / 40.0
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 6.0, 3.2 + sin(a) * 6.0, -7.3)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _lights() -> void:
	var key := DirectionalLight3D.new()
	key.light_color = Color("ffe2c4")
	key.light_energy = 1.25
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-38, 28, 0)
	add_child(key)
	for spec in [[Vector3(-5, 3.0, 1.5), UiKit.PINK], [Vector3(5, 3.0, 1.5), UiKit.CYAN], [Vector3(0, 4.5, -4.0), Color("8a5cff")]]:
		var l := OmniLight3D.new()
		l.position = spec[0]
		l.light_color = spec[1]
		l.light_energy = 2.6
		l.omni_range = 11.0
		add_child(l)
