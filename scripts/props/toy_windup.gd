class_name ToyWindUp
extends Node3D
## Toy Shop's twist. On the wave whose twist is "wind_up" the whole shop runs
## on clockwork: a ratchet winds every zombie tight and the horde runs fast for
## a few seconds, then the springs run down (a falling tune, a RUNNING DOWN
## call) and they slow almost to a stop, the moment to strike, before the
## ratchet winds them again. The toy train speeds up and slows with them.
## Listens to the run director, so it stays calm behind the menu.

const TWIST := &"wind_up"

@export var wound_seconds := 6.0
@export var rundown_seconds := 2.6
## Chase-speed multipliers while wound and while run down.
@export var wound_speed := 1.35
@export var rundown_speed := 0.35
## Multiplier change per second (how fast the spring catches or slips).
@export var ease_rate := 1.8
@export var wind_sound: StringName = &"toy_windup_ratchet"
@export var rundown_sound: StringName = &"toy_windup_rundown"

var _director: RunDirector
var _train: ToyTrain
var _active := false
var _time := 0.0
var _scale := 1.0


func _process(delta: float) -> void:
	if _director == null:
		_director = get_tree().get_first_node_in_group("run_director") as RunDirector
		if _director:
			_director.wave_started.connect(_on_wave_started)
			_director.wave_cleared.connect(func(_n: int, _t: int): _active = false)
			_director.state_changed.connect(_on_state_changed)
			_train = get_parent().find_child("Train", true, false) as ToyTrain
		return
	var target := 1.0
	if _active:
		var cycle := wound_seconds + rundown_seconds
		var before := fmod(_time, cycle)
		_time += delta
		var now := fmod(_time, cycle)
		if before < wound_seconds and now >= wound_seconds:
			Sfx.play(rundown_sound)
			_director.notice.emit("RUNNING DOWN — STRIKE NOW", &"good")
		elif now < before:
			Sfx.play(wind_sound)
		target = wound_speed if now < wound_seconds else rundown_speed
	_scale = move_toward(_scale, target, ease_rate * delta)
	if _train:
		_train.pace = _scale


func _physics_process(_delta: float) -> void:
	if _director == null or is_equal_approx(_scale, 1.0):
		return
	for z in _director.alive_enemies():
		if is_instance_valid(z) and z != _director.boss:
			z.speed_multiplier *= _scale


func _on_wave_started(_number: int, _total: int, _banner: String) -> void:
	var wave := _director.current_wave()
	_active = wave != null and wave.twist == TWIST
	if _active:
		_time = 0.0
		Sfx.play(wind_sound)


func _on_state_changed(state: RunDirector.State) -> void:
	if state != RunDirector.State.WAVE:
		_active = false
