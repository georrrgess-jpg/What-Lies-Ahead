class_name ArsenalShowroom
extends RefCounted
## The Arsenal's 3D set, built once into the preview's viewport: a glowing
## teal pedestal in the middle of a toy-arcade hall at night. Rows of arcade
## cabinets and two prize booths line the hall, a marquee arch of chasing
## bulbs frames the weapon, string lights hang overhead and the lit Ferris
## wheel turns outside the far window. The floor is glossy: the hall shows
## in it as a dim mirror image.
##
## The weapon stays the hero: the whole hall is unshaded (the weapon's key,
## rim and spot lights touch only the weapon, the pedestal and the floor),
## darker and lower in contrast than the weapon, hazed by fog with distance,
## and its far lights are soft bokeh discs. Bulbs chase and two beams sweep
## slowly (ShowroomMotion); both hold still when menu motion is reduced.
## Cheap: primitive meshes, one MultiMesh for every bulb, four lights, glow.
## The pedestal's top is at y = TOP; the weapon floats GAP above it.

const WHEEL_SCENE := "res://art/models/ferris_wheel.glb"
const TOP := 0.0
## Space between the pedestal's top and the weapon's lowest point.
const GAP := 0.06
const PEDESTAL_RADIUS := 0.5
## The floor's height (the pedestal stands on it).
const FLOOR := TOP - 0.24
## The far wall with the window onto the pier.
const BACK_Z := -24.0

const NIGHT := Color("0b0618")
const WALL := Color("1a1036")
const TEAL := Color("1f8f8c")
const TEAL_GLOW := Color("2ee6d6")
const PINK := Color("ff4fa3")
const GOLD := Color("ffc547")
const CREAM := Color("ffe8c2")
const PURPLE := Color("8a5cff")

const _GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 1.0;
void fragment() {
	ALBEDO = tint.rgb * COLOR.rgb * energy;
}
"""

## Additive light (beams, bokeh, the floor glow): `tint` scaled by a soft
## falloff. mode 0: a beam (fades along its length and at its silhouette);
## mode 1: a round disc (fades from the centre). A beam draws only its far
## side (so the pedestal's shaft never hazes over the weapon); a disc both.
const _LIGHT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, %s, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float energy = 1.0;
uniform int mode = 0;
void fragment() {
	float a;
	if (mode == 0) {
		float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
		a = edge * smoothstep(0.0, 0.25, UV.y) * (1.0 - UV.y * 0.75);
	} else {
		float r = length(UV - vec2(0.5)) * 2.0;
		a = pow(clamp(1.0 - r, 0.0, 1.0), 1.6);
	}
	ALBEDO = tint.rgb * COLOR.rgb * energy * a;
}
"""

static var _glow_shader: Shader
static var _light_shaders: Array[Shader] = []


## Adds the set to `vp`; returns the pedestal's glow ring (tinted per weapon).
static func build(vp: SubViewport) -> MeshInstance3D:
	vp.add_child(_environment())
	_add_lights(vp)
	var hall := Node3D.new()
	hall.name = "Hall"
	vp.add_child(hall)
	var bulbs := _Bulbs.new()
	_add_cabinets(hall)
	_add_booths(hall, bulbs)
	_add_arch(hall, bulbs)
	_add_back_wall(hall, bulbs)
	_add_string_lights(bulbs)
	hall.add_child(bulbs.make())
	# The glossy floor: the hall again, mirrored under it and seen through it.
	var mirror := hall.duplicate() as Node3D
	mirror.name = "HallReflection"
	mirror.transform = Transform3D(Basis.from_scale(Vector3(1.0, -1.0, 1.0)), Vector3(0.0, 2.0 * FLOOR, 0.0))
	vp.add_child(mirror)
	_add_floor(vp)
	_add_wheel(vp)
	_add_bokeh(vp)
	_add_backlight(vp)
	var motion := ShowroomMotion.new()
	motion.name = "ShowroomMotion"
	motion.bulbs = bulbs.multimesh
	motion.halos = bulbs.halos
	motion.chase = bulbs.chase
	motion.beams = _add_beams(vp)
	vp.add_child(motion)
	return _add_pedestal(vp)


static func _environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = NIGHT
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.42, 0.8)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	# Haze: the far hall sinks into the night, darker and greyer than the weapon.
	env.fog_enabled = true
	env.fog_light_color = Color("150c2c")
	env.fog_density = 0.075
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.2
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.75
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(1, 0.0)
	env.set_glow_level(2, 0.6)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 0.8)
	env.set_glow_level(5, 0.5)
	var we := WorldEnvironment.new()
	we.environment = env
	return we


## The weapon's lights: a warm key from the front left, a strong cream rim
## from behind, a cool pink fill, a spot straight down on the pedestal and a
## teal glow off the pedestal's ring. The hall is unshaded, so they light
## only the weapon, the pedestal and the floor.
static func _add_lights(vp: SubViewport) -> void:
	for spec in [[Vector3(-30, 35, 0), 1.35, Color(1.0, 0.92, 0.82)], [Vector3(-20, -165, 0), 1.6, Color(1.0, 0.86, 0.95)],
			[Vector3(-8, 125, 0), 0.45, Color(1.0, 0.5, 0.8)]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
		light.light_color = spec[2]
		vp.add_child(light)
	var spot := SpotLight3D.new()
	spot.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 3.4, 1.6)).looking_at(Vector3(0.0, TOP + 0.3, 0.0), Vector3.UP)
	spot.spot_range = 7.0
	spot.spot_angle = 22.0
	spot.spot_attenuation = 0.6
	spot.light_energy = 1.2
	spot.light_color = Color(1.0, 0.9, 0.75)
	vp.add_child(spot)
	var teal := OmniLight3D.new()
	teal.position = Vector3(0.0, TOP + 0.05, 0.6)
	teal.omni_range = 1.6
	teal.light_energy = 0.9
	teal.light_color = TEAL_GLOW
	vp.add_child(teal)


## Two rows of arcade cabinets down the sides of the hall, turned a little to
## the middle: dark bodies, glowing screens and marquees.
static func _add_cabinets(hall: Node3D) -> void:
	var screens := [TEAL_GLOW, PINK, GOLD, PURPLE, TEAL_GLOW, PINK, GOLD]
	for side in [-1.0, 1.0]:
		for i in 7:
			var cab := Node3D.new()
			cab.position = Vector3(side * (3.6 + i * 0.12), FLOOR, -2.5 - i * 2.4)
			cab.rotation.y = -side * deg_to_rad(28.0)
			hall.add_child(cab)
			var tone: Color = screens[(i + (3 if side > 0 else 0)) % screens.size()]
			_box(cab, Vector3(1.0, 1.95, 0.9), Vector3(0.0, 0.975, 0.0), _glow(WALL, 1.0))
			# The cabinet's side trim, the screen, the marquee and the control deck.
			_box(cab, Vector3(1.04, 0.06, 0.94), Vector3(0.0, 1.98, 0.0), _glow(tone, 0.9))
			_box(cab, Vector3(0.78, 0.6, 0.02), Vector3(0.0, 1.32, 0.46), _glow(tone, 0.42))
			_box(cab, Vector3(0.86, 0.22, 0.04), Vector3(0.0, 1.8, 0.46), _glow(CREAM.lerp(tone, 0.4), 0.7))
			_box(cab, Vector3(0.9, 0.08, 0.3), Vector3(0.0, 0.95, 0.56), _glow(tone.darkened(0.45), 1.0))


## Two prize booths at the far end of the rows: striped awnings over lit
## counters with a shelf of prizes.
static func _add_booths(hall: Node3D, bulbs: _Bulbs) -> void:
	for side in [-1.0, 1.0]:
		var booth := Node3D.new()
		booth.position = Vector3(side * 6.2, FLOOR, -19.5)
		booth.rotation.y = -side * deg_to_rad(18.0)
		hall.add_child(booth)
		_box(booth, Vector3(3.2, 1.0, 0.8), Vector3(0.0, 0.5, 0.0), _glow(Color("3a1f5c"), 1.0))
		_box(booth, Vector3(3.3, 0.08, 0.9), Vector3(0.0, 1.02, 0.0), _glow(GOLD, 0.9))
		_box(booth, Vector3(3.2, 2.2, 0.2), Vector3(0.0, 2.1, -0.9), _glow(WALL, 1.0))
		for k in 5:
			var prize := Color(PINK if k % 2 == 0 else TEAL_GLOW).darkened(0.25)
			_box(booth, Vector3(0.36, 0.4, 0.3), Vector3(-1.2 + k * 0.6, 1.9, -0.7), _glow(prize, 0.8))
		for k in 8:
			var stripe := PINK if k % 2 == 0 else CREAM
			var awning := _box(booth, Vector3(0.42, 0.12, 1.3), Vector3(-1.47 + k * 0.42, 3.15, -0.2), _glow(stripe, 0.85))
			awning.rotation.x = deg_to_rad(-16.0)
		for k in 9:
			bulbs.add(booth.transform * Vector3(-1.6 + k * 0.4, 3.0, 0.45), GOLD, 0.06, true)


## The marquee arch that frames the weapon: two posts and a half ring of
## bulbs round a glowing band, with a sign plate on top.
static func _add_arch(hall: Node3D, bulbs: _Bulbs) -> void:
	const Z := -9.0
	const RADIUS := 3.7
	const CENTRE_Y := 1.6
	var band := _glow(PURPLE.darkened(0.15), 1.0)
	for side in [-1.0, 1.0]:
		_box(hall, Vector3(0.45, CENTRE_Y - FLOOR, 0.45), Vector3(side * RADIUS, (CENTRE_Y + FLOOR) * 0.5, Z), band)
		for k in 7:
			bulbs.add(Vector3(side * (RADIUS - 0.3), FLOOR + 0.3 + k * 0.42, Z + 0.25), CREAM, 0.07, true)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.08
	torus.outer_radius = RADIUS + 0.08
	torus.rings = 48
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = band
	ring.rotation.x = PI * 0.5
	ring.position = Vector3(0.0, CENTRE_Y, Z)
	ring.scale = Vector3(1.0, 0.5, 1.0)
	hall.add_child(ring)
	var count := 25
	for k in count:
		var a := PI * k / (count - 1)
		bulbs.add(Vector3(cos(a) * (RADIUS - 0.0), CENTRE_Y + sin(a) * RADIUS, Z + 0.3), GOLD if k % 2 == 0 else PINK, 0.13, true)
	_box(hall, Vector3(3.0, 0.8, 0.2), Vector3(0.0, CENTRE_Y + RADIUS + 0.35, Z + 0.1), _glow(PINK.darkened(0.2), 1.0))
	_box(hall, Vector3(2.6, 0.5, 0.05), Vector3(0.0, CENTRE_Y + RADIUS + 0.35, Z + 0.22), _glow(CREAM, 1.3))


## The far wall: dark panels round a wide arched window onto the night pier,
## its frame outlined in teal light.
static func _add_back_wall(hall: Node3D, bulbs: _Bulbs) -> void:
	var wall := _glow(WALL, 1.0)
	const HALF := 6.0
	const SILL := 0.6
	const LINTEL := 6.5
	_box(hall, Vector3(40.0, SILL - FLOOR, 0.4), Vector3(0.0, (SILL + FLOOR) * 0.5, BACK_Z), wall)
	_box(hall, Vector3(40.0, 6.0, 0.4), Vector3(0.0, LINTEL + 3.0, BACK_Z), wall)
	for side in [-1.0, 1.0]:
		_box(hall, Vector3(14.0, LINTEL - SILL, 0.4), Vector3(side * (HALF + 7.0), (LINTEL + SILL) * 0.5, BACK_Z), wall)
	# Window bars and the teal outline.
	var bar := _glow(Color("120a26"), 1.0)
	for x in [-2.0, 2.0]:
		_box(hall, Vector3(0.18, LINTEL - SILL, 0.2), Vector3(x, (LINTEL + SILL) * 0.5, BACK_Z + 0.1), bar)
	_box(hall, Vector3(HALF * 2.0, 0.18, 0.2), Vector3(0.0, 3.6, BACK_Z + 0.1), bar)
	var edge := _glow(TEAL_GLOW, 0.9)
	_box(hall, Vector3(HALF * 2.0 + 0.3, 0.12, 0.1), Vector3(0.0, SILL, BACK_Z + 0.25), edge)
	_box(hall, Vector3(HALF * 2.0 + 0.3, 0.12, 0.1), Vector3(0.0, LINTEL, BACK_Z + 0.25), edge)
	for side in [-1.0, 1.0]:
		_box(hall, Vector3(0.12, LINTEL - SILL, 0.1), Vector3(side * HALF, (LINTEL + SILL) * 0.5, BACK_Z + 0.25), edge)
	# Neon stripes along the side walls lead the eye to the window.
	for side in [-1.0, 1.0]:
		_box(hall, Vector3(0.4, 8.0, 40.0), Vector3(side * 9.0, FLOOR + 4.0, -6.0), wall)
		_box(hall, Vector3(0.06, 0.08, 34.0), Vector3(side * 8.75, FLOOR + 3.1, -7.0), _glow(PINK, 0.8))
	# The night outside: a deep sky and a few stars.
	_box(hall, Vector3(60.0, 30.0, 0.2), Vector3(0.0, 8.0, -90.0), _glow(Color("1b1450"), 1.0))
	for k in 18:
		var at := Vector3(-28.0 + fmod(k * 13.7, 56.0), 4.0 + fmod(k * 5.3, 14.0), -88.0)
		bulbs.add(at, CREAM, 0.08, false)


## Strings of warm bulbs hung across the hall overhead, sagging a little.
static func _add_string_lights(bulbs: _Bulbs) -> void:
	for row in 4:
		var z := -4.0 - row * 4.5
		for k in 23:
			var t := k / 22.0
			var x := lerpf(-8.6, 8.6, t)
			var y := 4.9 - sin(t * PI) * 0.8
			bulbs.add(Vector3(x, y, z), GOLD if (k + row) % 3 != 0 else PINK, 0.07, true)


## The glossy floor (a dark lacquer the mirrored hall shows faintly through)
## and a teal glow pool round the pedestal.
static func _add_floor(vp: SubViewport) -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 70.0)
	floor_mesh.mesh = plane
	var lacquer := StandardMaterial3D.new()
	lacquer.albedo_color = Color(0.07, 0.04, 0.14, 0.92)
	lacquer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# No highlights of its own: the key light would lay a bright smear on it.
	lacquer.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	floor_mesh.material_override = lacquer
	floor_mesh.position = Vector3(0.0, FLOOR, -20.0)
	vp.add_child(floor_mesh)
	var pool := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(3.4, 3.4)
	pool.mesh = quad
	pool.material_override = _light(TEAL_GLOW, 0.55, 1)
	pool.position = Vector3(0.0, FLOOR + 0.01, 0.0)
	vp.add_child(pool)


## The Ferris wheel out on the pier, beyond the window (it turns slowly,
## unless menu motion is reduced).
static func _add_wheel(vp: SubViewport) -> void:
	var wheel := _instance(WHEEL_SCENE)
	if wheel == null:
		return
	wheel.set_script(load("res://scripts/props/ferris_wheel.gd"))
	wheel.position = Vector3(9.0, -6.0, -62.0)
	wheel.scale = Vector3.ONE * 0.36
	wheel.rotation_degrees.y = -14.0
	vp.add_child(wheel)
	wheel.set_process(not Settings.reduce_motion())
	# A warm glow behind it, so it reads as lit against the night.
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(26.0, 26.0)
	halo.mesh = quad
	halo.material_override = _light(Color("ff7ab8"), 0.35, 1)
	halo.position = Vector3(9.0, 3.5, -70.0)
	vp.add_child(halo)


## Soft out-of-focus discs of light in the middle distance (bokeh).
static func _add_bokeh(vp: SubViewport) -> void:
	var tones := [PINK, TEAL_GLOW, GOLD, PURPLE]
	var mats: Array[ShaderMaterial] = []
	for tone in tones:
		mats.append(_light(tone, 0.22, 1))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for k in 22:
		var disc := MeshInstance3D.new()
		disc.mesh = quad
		disc.material_override = mats[k % mats.size()]
		var x := -7.5 + fmod(k * 4.37, 15.0)
		# Keep the middle (where the weapon is) clear.
		if absf(x) < 2.2:
			x += 4.4 * signf(x if x != 0.0 else 1.0)
		disc.position = Vector3(x, 0.4 + fmod(k * 2.91, 5.2), -6.0 - fmod(k * 3.3, 12.0))
		disc.scale = Vector3.ONE * (0.7 + fmod(k * 0.37, 0.9))
		vp.add_child(disc)


## A wide, soft violet glow behind the pedestal: the weapon's silhouette
## stands out from the hall.
static func _add_backlight(vp: SubViewport) -> void:
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(9.0, 7.0)
	halo.mesh = quad
	halo.material_override = _light(Color("9b5cff"), 0.3, 1)
	halo.position = Vector3(0.0, TOP + 0.8, -5.0)
	vp.add_child(halo)


## Two long beams of light from the ceiling's far corners (ShowroomMotion
## sweeps them slowly).
static func _add_beams(vp: SubViewport) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 7.5, 6.5, -16.0)
		vp.add_child(pivot)
		var beam := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.12
		cone.bottom_radius = 1.6
		cone.height = 10.0
		cone.radial_segments = 24
		cone.cap_top = false
		cone.cap_bottom = false
		beam.mesh = cone
		beam.material_override = _light(Color(PINK if side < 0.0 else TEAL_GLOW).lerp(CREAM, 0.3), 0.09, 0)
		beam.position.y = -5.0
		pivot.add_child(beam)
		pivot.rotation.z = -side * 0.42
		pivot.rotation.x = 0.1
		out.append(pivot)
	return out


## The teal pedestal: a dark plinth, the teal drum, a glowing band round its
## foot, a soft cone of light down onto it and the glowing ring round its
## top (returned: it takes the weapon's tracer colour).
static func _add_pedestal(vp: SubViewport) -> MeshInstance3D:
	var plinth := _cylinder(PEDESTAL_RADIUS * 1.12, 0.1, _material(Color("1b1240"), 0.25, 0.4))
	plinth.position.y = TOP - 0.19
	vp.add_child(plinth)
	# Matte, so the low camera sees teal on its top, not a pale sheen.
	var teal := _material(Color("127370"), 0.85, 0.0)
	teal.metallic_specular = 0.1
	teal.emission_enabled = true
	teal.emission = TEAL_GLOW
	teal.emission_energy_multiplier = 0.22
	var drum := _cylinder(PEDESTAL_RADIUS, 0.16, teal)
	drum.position.y = TOP - 0.08
	vp.add_child(drum)
	var foot := _cylinder(PEDESTAL_RADIUS * 1.13, 0.025, _glow(TEAL_GLOW, 1.6))
	foot.position.y = TOP - 0.15
	vp.add_child(foot)
	var cone := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.15
	shaft.bottom_radius = PEDESTAL_RADIUS * 1.5
	shaft.height = 3.4
	shaft.radial_segments = 32
	shaft.cap_top = false
	shaft.cap_bottom = false
	cone.mesh = shaft
	cone.material_override = _light(CREAM, 0.22, 0)
	cone.position.y = TOP + 1.7
	vp.add_child(cone)
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


# --- building blocks ---------------------------------------------------------------

static func _box(parent: Node, extent: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = extent
	m.mesh = box
	m.material_override = material
	m.position = at
	parent.add_child(m)
	return m


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


## An unshaded colour (`energy` over 1 blooms).
static func _glow(color: Color, energy: float) -> ShaderMaterial:
	if _glow_shader == null:
		_glow_shader = Shader.new()
		_glow_shader.code = _GLOW_SHADER
	var m := ShaderMaterial.new()
	m.shader = _glow_shader
	m.set_shader_parameter(&"tint", color)
	m.set_shader_parameter(&"energy", energy)
	return m


## Additive soft light: mode 0 a beam, 1 a round disc (see _LIGHT_SHADER).
static func _light(color: Color, energy: float, mode: int) -> ShaderMaterial:
	if _light_shaders.is_empty():
		for cull in ["cull_front", "cull_disabled"]:
			var shader := Shader.new()
			shader.code = _LIGHT_SHADER % cull
			_light_shaders.append(shader)
	var m := ShaderMaterial.new()
	m.shader = _light_shaders[mode]
	m.set_shader_parameter(&"tint", color)
	m.set_shader_parameter(&"energy", energy)
	m.set_shader_parameter(&"mode", mode)
	if mode == 1:
		m.render_priority = 1
	return m


static func _instance(path: String) -> Node3D:
	return (load(path) as PackedScene).instantiate() as Node3D if ResourceLoader.exists(path) else null


## Collects every bulb of the hall into one MultiMesh (one draw call), with
## a soft halo round each in a second one; the bulbs marked `chases` take
## part in the chase.
class _Bulbs:
	## Halo size, in bulb radii.
	const HALO := 9.0
	var multimesh: MultiMesh
	var halos: MultiMesh
	## Index of each chasing bulb -> its lit colour.
	var chase := {}
	var _at: PackedVector3Array = []
	var _size: PackedFloat32Array = []
	var _colors: PackedColorArray = []

	func add(at: Vector3, color: Color, radius: float, chases: bool) -> void:
		if chases:
			chase[_at.size()] = color
		_at.append(at)
		_size.append(radius)
		_colors.append(color)

	func make() -> Node3D:
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		multimesh = _multimesh(sphere, 1.0)
		# The camera always looks down -Z, so flat quads facing it will do.
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		halos = _multimesh(quad, HALO)
		var node := Node3D.new()
		node.name = "Bulbs"
		node.add_child(_node(multimesh, ArsenalShowroom._glow(Color.WHITE, 1.9)))
		node.add_child(_node(halos, ArsenalShowroom._light(Color.WHITE, 0.5, 1)))
		return node

	func _multimesh(mesh: Mesh, scale: float) -> MultiMesh:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = _at.size()
		for i in _at.size():
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * _size[i] * scale), _at[i]))
			mm.set_instance_color(i, _colors[i])
		return mm

	func _node(mm: MultiMesh, material: Material) -> MultiMeshInstance3D:
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = material
		return node


## The hall's motion: the bulbs chase (every third one lit, stepping along)
## and the two beams sweep slowly. With reduced menu motion every bulb stays
## lit and the beams hold still.
class ShowroomMotion:
	extends Node3D

	## Chase steps per second, and how far the beams swing (radians).
	const CHASE_RATE := 7.0
	const SWEEP := 0.22
	const SWEEP_RATE := 0.22

	var bulbs: MultiMesh
	var halos: MultiMesh
	var chase := {}
	var beams: Array[Node3D] = []
	var _time := 0.0
	var _step := -1
	var _rest: Array[float] = []

	func _ready() -> void:
		for beam in beams:
			_rest.append(beam.rotation.z)

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		var still := Settings.reduce_motion()
		_time = 0.0 if still else _time + delta
		var step := -1 if still else int(_time * CHASE_RATE) % 3
		if step != _step:
			_step = step
			for i: int in chase:
				var lit: Color = chase[i]
				var shown := lit if step < 0 or i % 3 == step else lit.darkened(0.72)
				bulbs.set_instance_color(i, shown)
				halos.set_instance_color(i, shown if shown == lit else Color.BLACK)
		for k in beams.size():
			beams[k].rotation.z = _rest[k] + sin(_time * SWEEP_RATE * TAU * 0.25 + k * 1.7) * SWEEP
