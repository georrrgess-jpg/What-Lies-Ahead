extends "res://scripts/run/level_environment.gd"
## Root script for Ashfall City (the Endless map). Does everything
## level_environment.gd does (graphics preset, bulb halos) and adds the burning
## city's life:
##  - ash and embers drifting down round the active camera (fewer on Low);
##  - police light bars (OmniLight3D in group "city_police_light", meta
##    "phase"): the light swaps red and blue;
##  - neon that still flickers (group "city_neon_flicker": signs drop out,
##    lights dip, now and then, each on its own clock);
##  - aviation beacons (group "city_beacon") blinking on the radio mast.

const POLICE_RED := Color(1.0, 0.15, 0.12)
const POLICE_BLUE := Color(0.2, 0.4, 1.0)
## Police bars swap colour this often (seconds per colour).
const POLICE_PERIOD := 0.42
## Neon: seconds between flickers (random in range), and how long one lasts.
const FLICKER_GAP := Vector2(1.5, 7.0)
const FLICKER_LENGTH := Vector2(0.05, 0.22)
const BEACON_PERIOD := 1.6
## Ash and ember particles: [amount on High, amount on Low].
const ASH_AMOUNT := [220, 90]
const EMBER_AMOUNT := [40, 16]
## The ash box round the camera (metres).
const ASH_EXTENTS := Vector3(16.0, 9.0, 16.0)

var _time := 0.0
var _police: Array[OmniLight3D] = []
var _police_energy: Array[float] = []
var _beacons: Array[OmniLight3D] = []
## Flickering nodes: [node, base energy (lights) or -1, next flicker time, end time].
var _flicker: Array = []
var _ash: CPUParticles3D
var _embers: CPUParticles3D


func _ready() -> void:
	_ash = _build_ash()
	_embers = _build_embers()
	add_child(_ash)
	add_child(_embers)
	super()
	for node in get_tree().get_nodes_in_group("city_police_light"):
		if node is OmniLight3D and is_ancestor_of(node):
			_police.append(node)
			_police_energy.append((node as OmniLight3D).light_energy)
	for node in get_tree().get_nodes_in_group("city_beacon"):
		if node is OmniLight3D and is_ancestor_of(node):
			_beacons.append(node)
	for node in get_tree().get_nodes_in_group("city_neon_flicker"):
		if node is Node3D and is_ancestor_of(node):
			var base := (node as OmniLight3D).light_energy if node is OmniLight3D else -1.0
			_flicker.append([node, base, randf_range(FLICKER_GAP.x, FLICKER_GAP.y), 0.0])


func apply_graphics_preset(low: bool) -> void:
	super(low)
	if _ash:
		_ash.amount = ASH_AMOUNT[1 if low else 0]
		_embers.amount = EMBER_AMOUNT[1 if low else 0]


func _process(delta: float) -> void:
	_time += delta
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.global_position
		_ash.global_position = p + Vector3(0, 3.0, 0)
		_embers.global_position = p
	_update_police()
	_update_flicker()
	for b in _beacons:
		b.visible = fmod(_time, BEACON_PERIOD) < BEACON_PERIOD * 0.35


func _update_police() -> void:
	for i in _police.size():
		var l := _police[i]
		var t := _time / POLICE_PERIOD + float(l.get_meta("phase", 0.0))
		var blue := int(floor(t)) % 2 == 1
		l.light_color = POLICE_BLUE if blue else POLICE_RED
		# A quick double strobe at the start of each colour.
		var f := fmod(t, 1.0)
		l.light_energy = _police_energy[i] * (1.0 if f < 0.12 or (f > 0.2 and f < 0.32) else 0.35)


func _update_flicker() -> void:
	for entry in _flicker:
		var node: Node3D = entry[0]
		if _time >= entry[2]:
			entry[3] = _time + randf_range(FLICKER_LENGTH.x, FLICKER_LENGTH.y)
			entry[2] = entry[3] + randf_range(FLICKER_GAP.x, FLICKER_GAP.y)
			if randf() < 0.3:
				entry[2] = entry[3] + 0.08
		var dark: bool = _time < entry[3]
		if entry[1] < 0.0:
			node.visible = not dark
		else:
			(node as OmniLight3D).light_energy = entry[1] * (0.15 if dark else 1.0)


## Grey flakes falling and swirling slowly round the camera.
func _build_ash() -> CPUParticles3D:
	var p := _particles("Ash", ASH_AMOUNT[0], 7.0, Vector2(0.07, 0.07), Color(0.62, 0.58, 0.58, 0.85), false)
	p.emission_box_extents = ASH_EXTENTS
	p.direction = Vector3(0.3, -1.0, 0.15)
	p.spread = 30.0
	p.gravity = Vector3(0.15, -0.35, 0.05)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.7
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	return p


## A few glowing embers lifting on the heat.
func _build_embers() -> CPUParticles3D:
	var p := _particles("Embers", EMBER_AMOUNT[0], 4.0, Vector2(0.05, 0.05), Color(1.0, 0.55, 0.2, 1.0), true)
	p.emission_box_extents = Vector3(ASH_EXTENTS.x, 2.0, ASH_EXTENTS.z)
	p.direction = Vector3.UP
	p.spread = 35.0
	p.gravity = Vector3(0.2, 0.5, 0.0)
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.2
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	ramp.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	p.color_ramp = ramp
	return p


func _particles(particle_name: String, amount: int, lifetime: float, size: Vector2, color: Color, additive: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = particle_name
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var quad := QuadMesh.new()
	quad.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_fog = true
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.extra_cull_margin = 20.0
	return p
