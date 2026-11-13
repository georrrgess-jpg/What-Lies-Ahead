class_name CandySugarRush
extends Node
## Candy Works' Sugar Rush twist, as the factory shows it: when a wave with
## the `sugar_rush` twist starts, the sirens wail and strobe pink, the haze
## turns candy-pink and every machine (group "candy_machine") races; it all
## settles once the wave is won. The speed-up of the zombies themselves is in
## WaveTwist. Listens to the run director, so it stays calm behind the menu.

## Seconds for the rush to build or settle.
@export var transition := 2.5
@export var rush_fog_color := Color(1.0, 0.45, 0.7)
@export var rush_fog_density := 0.006
@export var rush_ambient := Color(1.0, 0.62, 0.82)
## How much faster the machines run at the height of the rush.
@export var machine_rush := 3.0
@export var siren_sound: StringName = &"candy_siren"

var _director: RunDirector
var _environment: Environment
var _fog_color := Color.BLACK
var _fog_density := 0.0
var _ambient := Color.BLACK
var _sirens: Array[OmniLight3D] = []
var _machines: Array[Node] = []
var _level := 0.0
var _target := 0.0
var _time := 0.0


func _ready() -> void:
	# Work on a copy: the scene's resource is shared with the next Retry.
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		we.environment = we.environment.duplicate()
		_environment = we.environment
		_fog_color = _environment.fog_light_color
		_fog_density = _environment.fog_density
		_ambient = _environment.ambient_light_color
	for node in get_tree().get_nodes_in_group("candy_siren"):
		if node is OmniLight3D:
			_sirens.append(node)
			node.visible = false


func _process(delta: float) -> void:
	if _director == null:
		_director = get_tree().get_first_node_in_group("run_director") as RunDirector
		if _director:
			_machines = get_tree().get_nodes_in_group("candy_machine")
			_director.wave_started.connect(_on_wave_started)
			_director.wave_cleared.connect(func(_n: int, _t: int): _target = 0.0)
	var was := _level
	_level = move_toward(_level, _target, delta / transition)
	if _level <= 0.0 and was <= 0.0:
		return
	_time += delta
	_apply(ease(_level, -1.6))


func _on_wave_started(_number: int, _total: int, _banner: String) -> void:
	var wave := _director.current_wave()
	_target = 1.0 if wave and wave.twist == &"sugar_rush" else 0.0
	if _target > 0.0:
		Sfx.play(siren_sound, -4.0)


func _apply(k: float) -> void:
	if _environment:
		_environment.fog_light_color = _fog_color.lerp(rush_fog_color, k)
		_environment.fog_density = lerpf(_fog_density, rush_fog_density, k)
		_environment.ambient_light_color = _ambient.lerp(rush_ambient, k)
	var rush := lerpf(1.0, machine_rush, k)
	for node in _machines:
		if is_instance_valid(node):
			node.set(&"rush", rush)
	var strobe := 0.5 + 0.5 * sin(_time * 9.0)
	for i in _sirens.size():
		var light := _sirens[i]
		light.visible = k > 0.02
		light.light_energy = k * (0.6 + 2.4 * (strobe if i % 2 == 0 else 1.0 - strobe))
