class_name FrostWeather
extends Node
## Summit Lodge weather. When the final wave starts a whiteout rolls in: the
## snowfall thickens and blows sideways, the fog closes in and the aurora
## flares crimson. It clears again once the wave is won. Listens to the run
## director, so it stays calm behind the main menu.

## Seconds for the storm to build or clear.
@export var transition := 6.0
@export var storm_fog_density := 0.0075
@export var storm_fog_color := Color(0.52, 0.5, 0.78)
@export var storm_hem_color := Color(1.0, 0.25, 0.42)
@export var storm_top_color := Color(0.62, 0.2, 0.95)

var _director: RunDirector
var _storm := 0.0
var _target := 0.0
var _environment: Environment
var _fog_density := 0.0
var _fog_color := Color.BLACK
var _aurora: Array[ShaderMaterial] = []
var _hem_colors: Array[Color] = []
var _top_colors: Array[Color] = []


func _ready() -> void:
	# Work on copies: the scene's resources are shared with the next Retry.
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		we.environment = we.environment.duplicate()
		_environment = we.environment
		_fog_density = _environment.fog_density
		_fog_color = _environment.fog_light_color
	for node in get_tree().get_nodes_in_group("frost_aurora"):
		var mesh := node as GeometryInstance3D
		var m := mesh.material_override as ShaderMaterial
		if m:
			m = m.duplicate()
			mesh.material_override = m
			_aurora.append(m)
			_hem_colors.append(m.get_shader_parameter("hem_color"))
			_top_colors.append(m.get_shader_parameter("top_color"))


func _process(delta: float) -> void:
	if _director == null:
		_director = get_tree().get_first_node_in_group("run_director") as RunDirector
		if _director:
			_director.wave_started.connect(_on_wave_started)
			_director.wave_cleared.connect(func(_n: int, _t: int): _target = 0.0)
	var next := move_toward(_storm, _target, delta / transition)
	if next != _storm:
		_storm = next
		_apply(ease(_storm, -1.8))


func _on_wave_started(number: int, total: int, _banner: String) -> void:
	_target = 1.0 if number == total else 0.0


func _apply(k: float) -> void:
	if _environment:
		_environment.fog_density = lerpf(_fog_density, storm_fog_density, k)
		_environment.fog_light_color = _fog_color.lerp(storm_fog_color, k)
	for i in _aurora.size():
		_aurora[i].set_shader_parameter("hem_color", _hem_colors[i].lerp(storm_hem_color, k))
		_aurora[i].set_shader_parameter("top_color", _top_colors[i].lerp(storm_top_color, k))
		_aurora[i].set_shader_parameter("speed", lerpf(1.0, 2.4, k))
	get_tree().call_group("frost_snowfall", "set_storm", k)
