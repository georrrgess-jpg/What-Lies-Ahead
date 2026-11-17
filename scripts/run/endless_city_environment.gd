extends "res://scripts/run/level_environment.gd"
## Root script for Ashfall City (the Endless map). Does everything
## level_environment.gd does (graphics preset, bulb halos) and adds the burning
## city's life (the drifting ash is the kit's city_ashfall scene):
##  - underground (the Metro), the sun and the sky fill are switched off, so
##    no daylight leaks through the hall's ceiling and no city shadows render,
##    and the facades and skyline overhead (group "city_surface") are hidden;
##  - police light bars (OmniLight3D in group "city_police_light", meta
##    "phase"): the light swaps red and blue;
##  - neon that still flickers (group "city_neon_flicker": signs drop out,
##    lights dip, now and then, each on its own clock);
##  - aviation beacons (group "city_beacon": lights and warning lamps) blinking
##    on the radio mast and the Broadcast Tower's roofs;
##  - searchlights (group "city_searchlight", meta "yaw" and "phase") sweeping
##    the smoke from beyond the city;
##  - the weather: an ash storm that comes and goes (thicker haze and smoke,
##    faster ash), lightning behind the skyline (the sky's clouds and a forked
##    bolt, a cold flash on the city, thunder after it) and far explosions;
##  - the police helicopter (group "city_helicopter", meta "centre", "radius",
##    "speed") circling the city, its searchlight sweeping the streets;
##  - sound: the crackle of the nearest few fires (Node3D in group
##    "city_fire") and the nearest ambient emitters (Marker3D in group
##    "city_ambient", meta "sound", "reach", "db": sirens, alarms, police
##    radios, neon buzz, arcing cables, the Metro's drips), each a small pool
##    of positional players moved onto the sources nearest the camera.

const POLICE_RED := Color(1.0, 0.15, 0.12)
const POLICE_BLUE := Color(0.2, 0.4, 1.0)
## Police bars swap colour this often (seconds per colour).
const POLICE_PERIOD := 0.42
## Neon: seconds between flickers (random in range), and how long one lasts.
const FLICKER_GAP := Vector2(1.5, 7.0)
const FLICKER_LENGTH := Vector2(0.05, 0.22)
const BEACON_PERIOD := 1.6
## Searchlights swing this far either side (radians), this fast (rad/s).
const SWEEP := 0.7
const SWEEP_SPEED := 0.23
## Below this height the camera is in the Metro.
const UNDERGROUND_Y := -1.6
const SHADOW_DISTANCE := 50.0
const CRACKLE := &"city_fire_crackle"
## Fires heard at once, how often the nearest are picked, how far one is heard.
const CRACKLE_VOICES := 3
const CRACKLE_CHECK := 0.5
const CRACKLE_RANGE := 26.0
const CRACKLE_DB := -4.0
## Ambient emitters heard at once.
const AMBIENT_VOICES := 4
## The ash storm: one cycle every STORM_PERIOD seconds, at its height for
## about a third of it; the haze thickens by up to STORM_FOG times its base.
const STORM_PERIOD := 150.0
const STORM_FOG := 1.2
const STORM_FOG_COLOR := Color(0.5, 0.36, 0.32)
## Seconds between lightning strikes, calm and at the storm's height; the
## thunder follows after THUNDER_DELAY seconds (random in range).
const LIGHTNING_GAP := Vector2(16.0, 5.0)
const THUNDER_DELAY := Vector2(0.8, 2.6)
const THUNDER := &"city_thunder"
## The flash lights the city through the sky fill (extra energy, cold).
const FLASH_FILL := 1.6
const FLASH_COLOR := Color(0.7, 0.75, 1.0)
## Far explosions: seconds between them, their boom's delay.
const BLAST_GAP := Vector2(25.0, 60.0)
const BLAST_DELAY := Vector2(1.0, 2.2)
const BLAST := &"city_blast_far"
const HELI := &"city_heli_loop"
const P_STORM := &"storm"
const P_FLASH := &"flash"
const P_FLASH_DIR := &"flash_dir"
const P_FLASH_SEED := &"flash_seed"
const P_BLAST := &"blast"
const P_BLAST_DIR := &"blast_dir"

var _time := 0.0
var _police: Array[OmniLight3D] = []
var _police_energy: Array[float] = []
var _beacons: Array[Node3D] = []
var _searchlights: Array[Node3D] = []
## Flickering nodes: [node, base energy (lights) or -1, next flicker time, end time].
var _flicker: Array = []
var _fill: DirectionalLight3D
var _fill_energy := 0.0
var _fill_color := Color.WHITE
var _underground := false
var _surface: Array[Node3D] = []
var _fires: Array[Node3D] = []
## Crackle players and the fire each is on (null: idle).
var _crackle: Array[AudioStreamPlayer3D] = []
var _crackle_on: Array = []
var _crackle_check := 0.0
var _emitters: Array[Node3D] = []
var _ambient: Array[AudioStreamPlayer3D] = []
var _ambient_on: Array = []
## Weather.
var _sky: ShaderMaterial
var _env: Environment
var _fog_density := 0.0
var _fog_color := Color.WHITE
var _ash: CityAshfall
var _storm := 0.0
var _next_flash := 6.0
var _flash_at := -100.0
var _thunder_at := -1.0
var _next_blast := 18.0
var _blast_at := -100.0
var _boom_at := -1.0
## The helicopter, its rotor and its searchlight.
var _heli: Node3D
var _rotor: Node3D
var _heli_beam: Node3D


func _ready() -> void:
	_fill = get_node_or_null("SkyFill")
	super()
	if _fill:
		_fill_energy = _fill.light_energy
		_fill_color = _fill.light_color
	for node in get_tree().get_nodes_in_group("city_police_light"):
		if node is OmniLight3D and is_ancestor_of(node):
			_police.append(node)
			_police_energy.append((node as OmniLight3D).light_energy)
	for node in get_tree().get_nodes_in_group("city_beacon"):
		if node is Node3D and is_ancestor_of(node):
			_beacons.append(node)
	for node in get_tree().get_nodes_in_group("city_searchlight"):
		if node is Node3D and is_ancestor_of(node):
			_searchlights.append(node)
	for node in get_tree().get_nodes_in_group("city_neon_flicker"):
		if node is Node3D and is_ancestor_of(node):
			var base := (node as OmniLight3D).light_energy if node is OmniLight3D else -1.0
			_flicker.append([node, base, randf_range(FLICKER_GAP.x, FLICKER_GAP.y), 0.0])
	for node in get_tree().get_nodes_in_group("city_surface"):
		if node is Node3D and is_ancestor_of(node):
			_surface.append(node)
	for node in get_tree().get_nodes_in_group("city_fire"):
		if node is Node3D and is_ancestor_of(node):
			_fires.append(node)
	for node in get_tree().get_nodes_in_group("city_ambient"):
		if node is Node3D and is_ancestor_of(node):
			_emitters.append(node)
	_build_crackle()
	_build_ambient()
	_find_weather()
	_find_helicopter()


## Shadows reach less far than in the story maps: the city is dense with
## casters and the haze hides the cut.
func apply_graphics_preset(low: bool) -> void:
	super(low)
	if sun:
		sun.directional_shadow_max_distance = 40.0 if low else SHADOW_DISTANCE


func _process(delta: float) -> void:
	_time += delta
	var cam := get_viewport().get_camera_3d()
	if cam:
		var p := cam.global_position
		var below := p.y < UNDERGROUND_Y
		if below != _underground:
			_underground = below
			if sun:
				sun.visible = not below
			if _fill:
				_fill.visible = not below
			for node in _surface:
				node.visible = not below
		_crackle_check -= delta
		if _crackle_check <= 0.0:
			_crackle_check = CRACKLE_CHECK
			_update_crackle(p)
			_update_ambient(p)
	_update_police()
	_update_flicker()
	for b in _beacons:
		b.visible = fmod(_time, BEACON_PERIOD) < BEACON_PERIOD * 0.35
	for s in _searchlights:
		var phase: float = s.get_meta("phase", 0.0)
		s.rotation.y = float(s.get_meta("yaw", 0.0)) + sin(_time * SWEEP_SPEED + phase) * SWEEP
	_update_weather()
	_update_helicopter(delta)


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


# --- weather -------------------------------------------------------------------

func _find_weather() -> void:
	if world_environment and world_environment.environment:
		_env = world_environment.environment
		_fog_density = _env.fog_density
		_fog_color = _env.fog_light_color
		if _env.sky:
			_sky = _env.sky.sky_material as ShaderMaterial
	_ash = find_child("Ashfall", true, false) as CityAshfall


## The storm's strength, lightning and far blasts, once a frame (a few
## uniforms and the fill light; nothing allocated).
func _update_weather() -> void:
	var cycle := sin(_time * TAU / STORM_PERIOD - 1.4)
	_storm = clampf(cycle * 1.6 - 0.35, 0.0, 1.0)
	_storm = _storm * _storm * (3.0 - 2.0 * _storm)
	if _env:
		_env.fog_density = _fog_density * (1.0 + STORM_FOG * _storm)
		_env.fog_light_color = _fog_color.lerp(STORM_FOG_COLOR, _storm * 0.6)
	if _ash:
		_ash.storm = _storm
	if _time >= _next_flash:
		_strike()
	if _time >= _next_blast:
		_explode()
	if _thunder_at > 0.0 and _time >= _thunder_at:
		_thunder_at = -1.0
		Sfx.play(THUNDER, (-10.0 if _underground else -1.0) + _storm * 3.0, randf_range(0.85, 1.1))
	if _boom_at > 0.0 and _time >= _boom_at:
		_boom_at = -1.0
		Sfx.play(BLAST, -12.0 if _underground else -4.0, randf_range(0.85, 1.1))
	var flash := _flash_level(_time - _flash_at)
	var blast := _blast_level(_time - _blast_at)
	if _sky:
		_sky.set_shader_parameter(P_STORM, _storm)
		_sky.set_shader_parameter(P_FLASH, flash)
		_sky.set_shader_parameter(P_BLAST, blast)
	if _fill and not _underground:
		_fill.light_energy = _fill_energy + flash * FLASH_FILL
		_fill.light_color = _fill_color.lerp(FLASH_COLOR, minf(flash, 1.0))


## A lightning strike somewhere on the horizon (over the Broadcast Tower's
## side more often than not); the next comes sooner in the storm.
func _strike() -> void:
	_flash_at = _time
	var gap := lerpf(LIGHTNING_GAP.x, LIGHTNING_GAP.y, _storm)
	_next_flash = _time + randf_range(gap * 0.6, gap * 1.4)
	_thunder_at = _time + randf_range(THUNDER_DELAY.x, THUNDER_DELAY.y)
	var angle := randf_range(-2.4, -0.6) if randf() < 0.6 else randf() * TAU
	if _sky:
		_sky.set_shader_parameter(P_FLASH_DIR, Vector3(cos(angle), randf_range(0.12, 0.3), sin(angle)))
		_sky.set_shader_parameter(P_FLASH_SEED, randf() * 100.0)


func _explode() -> void:
	_blast_at = _time
	_next_blast = _time + randf_range(BLAST_GAP.x, BLAST_GAP.y)
	_boom_at = _time + randf_range(BLAST_DELAY.x, BLAST_DELAY.y)
	var angle := randf() * TAU
	if _sky:
		_sky.set_shader_parameter(P_BLAST_DIR, Vector3(cos(angle), 0.02, sin(angle)))


## A strike's brightness `t` seconds after it: a flash and two flickers.
static func _flash_level(t: float) -> float:
	if t < 0.0 or t > 0.9:
		return 0.0
	var f := exp(-t * 14.0)
	if t > 0.16:
		f += 0.75 * exp(-(t - 0.16) * 11.0)
	if t > 0.38:
		f += 0.45 * exp(-(t - 0.38) * 9.0)
	return f


## A far explosion's glow `t` seconds after it: a quick swell, a slow fade.
static func _blast_level(t: float) -> float:
	if t < 0.0 or t > 4.0:
		return 0.0
	return smoothstep(0.0, 0.12, t) * exp(-t * 1.3)


# --- helicopter ----------------------------------------------------------------

func _find_helicopter() -> void:
	for node in get_tree().get_nodes_in_group("city_helicopter"):
		if node is Node3D and is_ancestor_of(node):
			_heli = node
	if _heli == null:
		return
	_rotor = _heli.get_node_or_null("Rotor")
	_heli_beam = _heli.get_node_or_null("Beam")
	var s := Sfx.stream(HELI)
	if s:
		var p := AudioStreamPlayer3D.new()
		p.name = "RotorSound"
		p.stream = s
		p.bus = Sfx.MIX.bus_of(HELI)
		p.volume_db = Sfx.mix_db(HELI) - 2.0
		p.unit_size = 20.0
		p.max_distance = 180.0
		p.autoplay = true
		_heli.add_child(p)


## Flies the helicopter round its circle (bobbing, banked into the turn) and
## swings its searchlight across the streets below.
func _update_helicopter(delta: float) -> void:
	if _heli == null:
		return
	var centre: Vector3 = _heli.get_meta("centre", Vector3.ZERO)
	var radius: float = _heli.get_meta("radius", 80.0)
	var a := _time * float(_heli.get_meta("speed", 0.06))
	_heli.position = centre + Vector3(cos(a) * radius, sin(a * 3.0) * 3.0, sin(a) * radius)
	# Flying along the circle (counter-clockwise from above), banked inward.
	_heli.rotation = Vector3(0.08, PI - a, -0.16)
	if _rotor:
		_rotor.rotation.y = fmod(_rotor.rotation.y + delta * 31.0, TAU)
	if _heli_beam:
		_heli_beam.rotation.y = sin(_time * 0.37) * 0.9
		_heli_beam.rotation.z = sin(_time * 0.23 + 1.0) * 0.25


# --- sound ---------------------------------------------------------------------

func _build_crackle() -> void:
	var s := Sfx.stream(CRACKLE)
	if s == null or _fires.is_empty():
		return
	for i in mini(CRACKLE_VOICES, _fires.size()):
		var p := AudioStreamPlayer3D.new()
		p.name = "Crackle%d" % i
		p.stream = s
		p.bus = Sfx.MIX.bus_of(CRACKLE)
		p.volume_db = CRACKLE_DB + Sfx.mix_db(CRACKLE)
		p.unit_size = 5.0
		p.max_distance = CRACKLE_RANGE
		add_child(p)
		_crackle.append(p)
		_crackle_on.append(null)


## Moves the crackle players onto the fires nearest `from`; a player whose
## fire is still among the nearest keeps playing, a moved one starts at a
## random point of the loop.
func _update_crackle(from: Vector3) -> void:
	if _crackle.is_empty():
		return
	var near: Array[Node3D] = []
	for f in _fires:
		if f.global_position.distance_to(from) < CRACKLE_RANGE:
			near.append(f)
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(from) < b.global_position.distance_squared_to(from))
	near.resize(mini(near.size(), _crackle.size()))
	for i in _crackle.size():
		if _crackle_on[i] != null and not near.has(_crackle_on[i]):
			_crackle_on[i] = null
			_crackle[i].stop()
	for f in near:
		if _crackle_on.has(f):
			continue
		var i := _crackle_on.find(null)
		_crackle_on[i] = f
		_crackle[i].global_position = f.global_position
		_crackle[i].play(randf() * _crackle[i].stream.get_length())


func _build_ambient() -> void:
	if _emitters.is_empty():
		return
	for i in mini(AMBIENT_VOICES, _emitters.size()):
		var p := AudioStreamPlayer3D.new()
		p.name = "Ambient%d" % i
		p.unit_size = 6.0
		add_child(p)
		_ambient.append(p)
		_ambient_on.append(null)


## Like the crackle: the emitters within their reach of `from` (and on the
## camera's side of the street, above or under it), nearest first relative to
## their reach, get a player each; a newly picked one starts at a random point
## of its loop.
func _update_ambient(from: Vector3) -> void:
	if _ambient.is_empty():
		return
	var near: Array[Node3D] = []
	for e in _emitters:
		var reach: float = e.get_meta("reach", 15.0)
		if (e.global_position.y < UNDERGROUND_Y) == _underground and e.global_position.distance_to(from) < reach:
			near.append(e)
	near.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(from) / float(a.get_meta("reach", 15.0)) \
			< b.global_position.distance_to(from) / float(b.get_meta("reach", 15.0)))
	near.resize(mini(near.size(), _ambient.size()))
	for i in _ambient.size():
		if _ambient_on[i] != null and not near.has(_ambient_on[i]):
			_ambient_on[i] = null
			_ambient[i].stop()
	for e in near:
		if _ambient_on.has(e):
			continue
		var sound := StringName(e.get_meta("sound", ""))
		var s := Sfx.stream(sound)
		if s == null:
			continue
		var i := _ambient_on.find(null)
		var p := _ambient[i]
		_ambient_on[i] = e
		p.stream = s
		p.bus = Sfx.MIX.bus_of(sound)
		p.volume_db = float(e.get_meta("db", 0.0)) + Sfx.mix_db(sound)
		p.max_distance = float(e.get_meta("reach", 15.0))
		p.global_position = e.global_position
		p.play(randf() * s.get_length())
