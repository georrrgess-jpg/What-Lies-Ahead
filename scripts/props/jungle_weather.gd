class_name JungleWeather
extends Node
## Lost Temple weather: the Monsoon twist. When a wave whose twist is
## `monsoon` starts, a tropical downpour rolls in: the sky clouds over, the
## sun and the haze turn grey-green, the fog closes in, rain sheets down, the
## waterfall runs faster and lightning flashes with thunder. It clears once
## the wave is won. Listens to the run director, so it stays calm behind the main menu.

const TWIST := &"monsoon"

## Seconds for the storm to build or clear.
@export var transition := 5.0
@export var storm_fog_density := 0.026
@export var storm_fog_color := Color(0.36, 0.42, 0.4)
@export var storm_sun_color := Color(0.62, 0.7, 0.72)
@export var storm_sun_energy := 0.35
@export var storm_ambient_energy := 0.55
## Seconds between lightning strikes (random in this range).
@export var lightning_gap := Vector2(5.0, 11.0)

var _director: RunDirector
var _storm := 0.0
var _target := 0.0
var _environment: Environment
var _sky: ShaderMaterial
var _sun: DirectionalLight3D
var _base := {}
var _flash := 0.0
var _next_strike := 0.0
var _falls: Array[ShaderMaterial] = []


func _ready() -> void:
	# Work on copies: the scene's resources are shared with the next Retry.
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		we.environment = we.environment.duplicate(true)
		_environment = we.environment
		_sky = _environment.sky.sky_material as ShaderMaterial if _environment.sky else null
		_base["fog_density"] = _environment.fog_density
		_base["fog_color"] = _environment.fog_light_color
		_base["ambient"] = _environment.ambient_light_energy
	_sun = get_parent().get_node_or_null("Sun") as DirectionalLight3D
	if _sun:
		_base["sun_energy"] = _sun.light_energy
		_base["sun_color"] = _sun.light_color
	for node in get_tree().get_nodes_in_group("jungle_waterfall"):
		var mesh := node as GeometryInstance3D
		var m := mesh.material_override as ShaderMaterial
		if m:
			m = m.duplicate()
			mesh.material_override = m
			_falls.append(m)


func _process(delta: float) -> void:
	if _director == null:
		_director = get_tree().get_first_node_in_group("run_director") as RunDirector
		if _director:
			_director.wave_started.connect(_on_wave_started)
			_director.wave_cleared.connect(_on_wave_cleared)
	var next := move_toward(_storm, _target, delta / transition)
	_flash = maxf(0.0, _flash - delta * 3.5)
	if _storm > 0.6 and _target > 0.0:
		_next_strike -= delta
		if _next_strike <= 0.0:
			_strike()
	if next != _storm or _flash > 0.0:
		_storm = next
		_apply(ease(_storm, -1.6))


func _on_wave_started(_number: int, _total: int, _banner: String) -> void:
	var wave := _director.current_wave()
	if wave and wave.twist == TWIST:
		_target = 1.0
		_next_strike = 2.5


func _on_wave_cleared(_number: int, _total: int) -> void:
	_target = 0.0


func _strike() -> void:
	_next_strike = randf_range(lightning_gap.x, lightning_gap.y)
	_flash = 1.0
	Sfx.play(&"jungle_thunder", -2.0, randf_range(0.9, 1.08))


func _apply(k: float) -> void:
	var flash := _flash * _flash
	if _environment:
		_environment.fog_density = lerpf(_base["fog_density"], storm_fog_density, k)
		_environment.fog_light_color = (_base["fog_color"] as Color).lerp(storm_fog_color, k).lerp(Color(0.85, 0.92, 1.0), flash * 0.6)
		_environment.ambient_light_energy = lerpf(_base["ambient"], storm_ambient_energy, k) + flash * 1.6
	if _sun:
		_sun.light_energy = lerpf(_base["sun_energy"], storm_sun_energy, k) + flash * 1.4
		_sun.light_color = (_base["sun_color"] as Color).lerp(storm_sun_color, k)
	if _sky:
		_sky.set_shader_parameter("storm", k)
	get_tree().call_group("jungle_rain", "set_amount", k)
	for m in _falls:
		m.set_shader_parameter("rate", lerpf(1.2, 2.2, k))
