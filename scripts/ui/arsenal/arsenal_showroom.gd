class_name ArsenalShowroom
extends RefCounted
## The Arsenal's 3D set, built into the preview's viewport: a teal pedestal
## on the end of the pier at sunset, the railing and two lamps behind it, the
## sea and Prize Pier's Ferris wheel far off. Fog and a low, warm light keep
## the background soft so the weapon reads first. The pedestal's top is at
## y = TOP; the weapon floats GAP above it.

const WHEEL_SCENE := "res://art/models/ferris_wheel.glb"
## How far behind the pedestal the pier's railing runs.
const RAIL_Z := -16.0
const TOP := 0.0
## Space between the pedestal's top and the weapon's lowest point.
const GAP := 0.06
const PEDESTAL_RADIUS := 0.5
const TEAL := Color("1f8f8c")
const DECK := Color("4a2c4f")


## Adds the set to `vp`; returns the pedestal's glow ring (tinted per weapon).
static func build(vp: SubViewport) -> MeshInstance3D:
	vp.add_child(_environment())
	_add_lights(vp)
	_add_deck(vp)
	_add_scenery(vp)
	return _add_pedestal(vp)


static func _environment() -> WorldEnvironment:
	var dusk := ProceduralSkyMaterial.new()
	dusk.sky_top_color = Color("24194f")
	dusk.sky_horizon_color = Color("c8697f")
	dusk.sky_curve = 0.12
	dusk.ground_horizon_color = Color("7a3f6e")
	dusk.ground_bottom_color = Color("1a1238")
	dusk.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = dusk
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.42, 0.85)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Haze over the far set: the wheel and the sea stay soft behind the weapon.
	env.fog_enabled = true
	env.fog_light_color = Color("5b3a78")
	env.fog_density = 0.022
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	return we


## A warm key from the front left, a pink rim from behind (the low sun), a
## cool fill and a spot over the pedestal.
static func _add_lights(vp: SubViewport) -> void:
	for spec in [[Vector3(-28, 32, 0), 1.25, Color(1.0, 0.9, 0.8)], [Vector3(-14, -160, 0), 0.9, Color(1.0, 0.55, 0.7)],
			[Vector3(-6, 120, 0), 0.35, Color(0.55, 0.75, 1.0)]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
		light.light_color = spec[2]
		vp.add_child(light)
	var spot := SpotLight3D.new()
	spot.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 2.6, 0.6)).looking_at(Vector3(0.0, TOP, 0.0), Vector3.FORWARD)
	spot.spot_range = 4.0
	spot.spot_angle = 30.0
	spot.light_energy = 1.6
	spot.light_color = Color(1.0, 0.86, 0.66)
	vp.add_child(spot)


## The pier's boards under the pedestal, running out to a railing with two
## lamps (plain shapes: the far set stays simple and soft).
static func _add_deck(vp: SubViewport) -> void:
	var deck := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 30.0)
	deck.mesh = plane
	deck.material_override = _material(DECK, 0.85, 0.0)
	deck.position = Vector3(0.0, TOP - 0.24, -10.0)
	vp.add_child(deck)
	var wood := _material(Color("5b3768"), 0.8, 0.0)
	for y in [0.55, 1.0]:
		_add_box(vp, Vector3(40.0, 0.07, 0.07), Vector3(0.0, TOP - 0.24 + y, RAIL_Z), wood)
	for i in 21:
		_add_box(vp, Vector3(0.1, 1.1, 0.1), Vector3(-20.0 + i * 2.0, TOP - 0.24 + 0.55, RAIL_Z), wood)
	for x in [-6.5, 7.0]:
		_add_box(vp, Vector3(0.12, 2.6, 0.12), Vector3(x, TOP - 0.24 + 1.3, RAIL_Z + 0.3), _material(Color("2a1d4a"), 0.6, 0.3))
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.32
		bulb.mesh = sphere
		var glow_mat := _material(Color(1.0, 0.82, 0.55), 0.5, 0.0)
		glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_mat.disable_fog = true
		bulb.material_override = glow_mat
		bulb.position = Vector3(x, TOP - 0.24 + 2.7, RAIL_Z + 0.3)
		vp.add_child(bulb)
		var glow := OmniLight3D.new()
		glow.position = bulb.position + Vector3(0.0, -0.2, 0.4)
		glow.omni_range = 4.0
		glow.light_energy = 1.2
		glow.light_color = Color(1.0, 0.78, 0.5)
		vp.add_child(glow)


static func _add_box(vp: SubViewport, extent: Vector3, at: Vector3, material: Material) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = extent
	m.mesh = box
	m.material_override = material
	m.position = at
	vp.add_child(m)


## The sea and the Ferris wheel on the horizon.
static func _add_scenery(vp: SubViewport) -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	sea.mesh = plane
	sea.material_override = _material(Color("33265f"), 0.3, 0.4)
	sea.position = Vector3(0, -3.4, -200)
	vp.add_child(sea)
	var wheel := _instance(WHEEL_SCENE)
	if wheel:
		wheel.set_script(load("res://scripts/props/ferris_wheel.gd"))
		wheel.position = Vector3(15.0, -6.0, -58.0)
		wheel.scale = Vector3.ONE * 0.33
		wheel.rotation_degrees.y = -18.0
		vp.add_child(wheel)
		# The wheel turns slowly, unless menu motion is reduced.
		wheel.set_process(not Settings.reduce_motion())


## The teal pedestal: a dark plinth, the teal drum and a glowing ring round
## its top edge (returned: it takes the weapon's tracer colour).
static func _add_pedestal(vp: SubViewport) -> MeshInstance3D:
	var plinth := _cylinder(PEDESTAL_RADIUS * 1.12, 0.1, _material(Color("1b1240"), 0.6, 0.2))
	plinth.position.y = TOP - 0.19
	vp.add_child(plinth)
	var drum := _cylinder(PEDESTAL_RADIUS, 0.16, _material(TEAL, 0.35, 0.55))
	drum.position.y = TOP - 0.08
	vp.add_child(drum)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = PEDESTAL_RADIUS * 0.9
	torus.outer_radius = PEDESTAL_RADIUS * 0.95
	torus.rings = 64
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position.y = TOP + 0.002
	vp.add_child(ring)
	return ring


static func _cylinder(radius: float, height: float, material: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 64
	m.mesh = c
	m.material_override = material
	return m


static func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func _instance(path: String) -> Node3D:
	return (load(path) as PackedScene).instantiate() as Node3D if ResourceLoader.exists(path) else null
