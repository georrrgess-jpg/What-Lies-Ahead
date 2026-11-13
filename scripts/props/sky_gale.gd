class_name SkyGale
extends Node3D
## Sky Harbor's twist. On the wave whose twist is "gale" the wind rises over
## the islands: the sky greys and races, the cloud sea rolls faster, bunting
## whips, every pinwheel and propeller spins up, and gusts sweep streaks and
## confetti across the decks. Each gust leans on the player: a gentle,
## collision-safe drift (the railings and walls hold, nothing pushes anyone
## off an island) that swings to a new heading every few seconds, announced by
## a rising whoosh. Listens to the run director, so it stays calm behind the menu.

const TWIST := &"gale"

## Drift speed of the steady wind and the extra at the peak of a gust (m/s).
@export var push := 1.1
@export var gust_push := 1.3
## Seconds between gusts (a random pick in this range).
@export var gust_interval := Vector2(4.5, 6.5)
## Seconds for the weather to build up or calm down.
@export var transition := 2.5

var _director: RunDirector
var _active := false
var _level := 0.0
var _heading := Vector3(-1, 0, 0.3).normalized()
var _target_heading := _heading
var _gust := 0.0
var _gust_cool := 2.0
var _sky: ShaderMaterial
var _sea: ShaderMaterial
var _bunting: Array[ShaderMaterial] = []
var _streaks: CPUParticles3D
var _confetti: CPUParticles3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	SkySpinner.wind = 1.0
	# Work on copies: the scene's resources are shared with the next Retry.
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment and we.environment.sky:
		we.environment = we.environment.duplicate()
		we.environment.sky = we.environment.sky.duplicate()
		_sky = we.environment.sky.sky_material.duplicate() as ShaderMaterial
		we.environment.sky.sky_material = _sky
	var sea := get_tree().get_first_node_in_group("sky_cloud_sea") as MeshInstance3D
	if sea:
		_sea = (sea.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		sea.material_override = _sea
	var shared := {}
	for node in get_tree().get_nodes_in_group("sky_bunting"):
		var gi := node as GeometryInstance3D
		var m := gi.material_override as ShaderMaterial
		if not shared.has(m):
			shared[m] = m.duplicate()
			_bunting.append(shared[m])
		gi.material_override = shared[m]
	_streaks = _make_particles(70, Vector2(0.025, 1.6), true)
	_confetti = _make_particles(40, Vector2(0.12, 0.12), false)


func _exit_tree() -> void:
	SkySpinner.wind = 1.0


func _process(delta: float) -> void:
	if _director == null:
		_director = get_tree().get_first_node_in_group("run_director") as RunDirector
		if _director:
			_director.wave_started.connect(_on_wave_started)
			_director.wave_cleared.connect(func(_n: int, _t: int): _active = false)
			_director.state_changed.connect(_on_state_changed)
	var target := 1.0 if _active else 0.0
	if _level != target:
		_level = move_toward(_level, target, delta / transition)
	_heading = _heading.slerp(_target_heading, minf(1.0, delta * 0.8)).normalized()
	_gust = maxf(0.0, _gust - delta * 0.45)
	if _active and _level > 0.5:
		_gust_cool -= delta
		if _gust_cool <= 0.0:
			_begin_gust()
	_apply(ease(_level, -1.6), delta)


func _physics_process(delta: float) -> void:
	if _level <= 0.01 or _director == null:
		return
	var player := _director.player
	if player == null or not player.alive or not player.controls_enabled:
		return
	var speed := (push + gust_push * sin(_gust * PI)) * ease(_level, -1.6)
	player.move_and_collide(_heading * speed * delta)


func _on_wave_started(_number: int, _total: int, _banner: String) -> void:
	var wave := _director.current_wave()
	_active = wave != null and wave.twist == TWIST
	_gust_cool = 3.0
	if _active:
		Sfx.play(&"sky_gale_horn")


func _on_state_changed(state: RunDirector.State) -> void:
	if state != RunDirector.State.WAVE:
		_active = false


## A new gust: a fresh heading (never straight back the way it blew) and a whoosh.
func _begin_gust() -> void:
	_gust_cool = _rng.randf_range(gust_interval.x, gust_interval.y)
	_gust = 1.0
	var a := atan2(_target_heading.z, _target_heading.x) + _rng.randf_range(0.8, 2.2) * (1.0 if _rng.randf() < 0.5 else -1.0)
	_target_heading = Vector3(cos(a), 0, sin(a))
	Sfx.play(&"sky_gale_gust", 0.0, _rng.randf_range(0.9, 1.1))


func _apply(k: float, _delta: float) -> void:
	SkySpinner.wind = 1.0 + 2.6 * k + 1.2 * k * _gust
	if _sky:
		_sky.set_shader_parameter("gale", k)
	if _sea:
		_sea.set_shader_parameter("speed", 1.0 + 5.0 * k)
	for m in _bunting:
		m.set_shader_parameter("gust", 1.0 + 2.2 * k + _gust * k)
	var player := _director.player if _director else null
	var on := k > 0.3 and player != null
	for p in [_streaks, _confetti]:
		p.emitting = on
		if on:
			p.global_position = player.global_position + Vector3.UP * 2.0 - _heading * 10.0
			p.direction = _heading + Vector3.UP * 0.05
	if on:
		var v := 16.0 + 10.0 * _gust
		_streaks.initial_velocity_min = v
		_streaks.initial_velocity_max = v * 1.3
		_confetti.initial_velocity_min = v * 0.45
		_confetti.initial_velocity_max = v * 0.6


func _make_particles(amount: int, size: Vector2, streak: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.4
	p.emitting = false
	p.local_coords = false
	var quad := QuadMesh.new()
	quad.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if not streak else BaseMaterial3D.BILLBOARD_DISABLED
	quad.material = m
	p.mesh = quad
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14.0, 4.0, 14.0)
	p.spread = 8.0 if streak else 25.0
	p.gravity = Vector3.ZERO if streak else Vector3(0, -1.5, 0)
	p.particle_flag_align_y = streak
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ramp := Gradient.new()
	if streak:
		ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
		ramp.add_point(0.3, Color(1.0, 0.98, 0.94, 0.45))
		ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 1.0, 1.0, 0.0))
	else:
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		p.hue_variation_min = -0.5
		p.hue_variation_max = 0.5
		p.color = Color(1.0, 0.35, 0.45)
		ramp.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
		ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	p.color_ramp = ramp
	add_child(p)
	return p
