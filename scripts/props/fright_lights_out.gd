extends Node3D
## Ghost Train's twist. On the wave whose twist is "fright_lights_out" the
## fairground power fails: the lamps stutter for a moment (a fuse pops), then
## the warm lights die and the moon, sky and ambient fade down. Only the green
## lights stay on (the skull's eyes and mouth, the crypt, the crystal ball),
## and every zombie's glowing eyes read through the dark as the glow rises.
## Now and then the power coughs back for a blink. When the wave is cleared
## the power comes back on. Listens to the run director, so it stays calm
## behind the menu. Works on copies of the shared environment and sky.

const TWIST := &"fright_lights_out"

## Share of the ambient, sky and moonlight left in the dark.
@export var dark_level := 0.36
## Seconds the lamps stutter before they die, and to fade either way.
@export var stutter_seconds := 1.6
@export var fade_seconds := 1.4
## Seconds between brief flickers of power during the wave.
@export var flicker_interval := Vector2(6.0, 10.0)

var _director: RunDirector
var _environment: Environment
var _sky: ShaderMaterial
var _base := {}             # property -> value on the environment
var _lights := {}           # Light3D -> its energy
var _warm: Array[Light3D] = []
var _active := false
var _level := 0.0           # 0 = power on, 1 = lights out
var _stutter := 0.0
var _flicker_cool := 0.0
var _blink := 0.0
var _shown := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		we.environment = we.environment.duplicate()
		_environment = we.environment
		if _environment.sky:
			_environment.sky = _environment.sky.duplicate()
			_sky = _environment.sky.sky_material.duplicate() as ShaderMaterial
			_environment.sky.sky_material = _sky
		for key in [&"ambient_light_energy", &"glow_intensity", &"fog_density"]:
			_base[key] = _environment.get(key)
	for node in get_parent().find_children("*", "Light3D", true, false):
		var light := node as Light3D
		_lights[light] = light.light_energy
		if light is OmniLight3D and light.light_color.r > light.light_color.g:
			_warm.append(light)
	set_process(true)


func _process(delta: float) -> void:
	if _director == null:
		_director = get_tree().get_first_node_in_group("run_director") as RunDirector
		if _director:
			_director.wave_started.connect(_on_wave_started)
			_director.wave_cleared.connect(func(_n: int, _t: int): _set_active(false))
			_director.state_changed.connect(_on_state_changed)
		return
	if _stutter > 0.0:
		_stutter -= delta
		_apply(1.0 if _rng.randf() < 0.55 else 0.0)
		return
	var target := 1.0 if _active else 0.0
	if _level != target:
		_level = move_toward(_level, target, delta / fade_seconds)
	if _active and _level >= 1.0:
		_flicker_cool -= delta
		if _flicker_cool <= 0.0:
			_flicker_cool = _rng.randf_range(flicker_interval.x, flicker_interval.y)
			_blink = 0.22
			Sfx.play(&"fright_power_buzz", -2.0, _rng.randf_range(0.9, 1.1))
	_blink = maxf(0.0, _blink - delta)
	_apply(_level * (0.4 if _blink > 0.0 else 1.0))


func _on_wave_started(_number: int, _total: int, _banner: String) -> void:
	var wave := _director.current_wave()
	_set_active(wave != null and wave.twist == TWIST)


func _on_state_changed(state: RunDirector.State) -> void:
	if state != RunDirector.State.WAVE:
		_set_active(false)


func _set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	_flicker_cool = 4.0
	if on:
		_stutter = stutter_seconds
		Sfx.play(&"fright_power_down", 0.0)
	else:
		_stutter = 0.0
		Sfx.play(&"fright_power_up", -2.0)


## k: 0 = power on, 1 = lights out.
func _apply(k: float) -> void:
	if is_equal_approx(k, _shown):
		return
	_shown = k
	if _environment:
		var dim := lerpf(1.0, dark_level, k)
		_environment.ambient_light_energy = float(_base[&"ambient_light_energy"]) * dim
		_environment.glow_intensity = float(_base[&"glow_intensity"]) * lerpf(1.0, 1.45, k)
		_environment.fog_density = float(_base[&"fog_density"]) * lerpf(1.0, 1.5, k)
	if _sky:
		_sky.set_shader_parameter("dim", k)
	for light in _lights:
		if not is_instance_valid(light):
			continue
		var energy: float = _lights[light]
		if light is DirectionalLight3D:
			light.light_energy = energy * lerpf(1.0, dark_level * 0.8, k)
		elif _warm.has(light):
			light.light_energy = energy * (1.0 - k)
