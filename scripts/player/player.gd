class_name Player
extends CharacterBody3D
## First-person controller: grounded WASD movement, mouse look, health.
## Shooting lives in the child WeaponController; visuals in WeaponView.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source_position: Vector3)
signal died

const LOOK_SCALE := 0.0022

@export var walk_speed := 5.2
@export var sprint_speed := 7.6
## How quickly horizontal velocity reaches the target (m/s per second).
@export var acceleration := 55.0
@export var deceleration := 45.0
@export var max_health := 100.0
@export var gravity := 22.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapons: WeaponController = $Weapons
@onready var view: WeaponView = $Head/Camera3D/WeaponView

var health := 100.0
var alive := true
## False while a menu or results screen owns the input.
var controls_enabled := true
var sprinting := false

var _pitch := 0.0
var _recoil := 0.0
var _trauma := 0.0
var _shake_time := 0.0
var _base_fov := 72.0
var _hit_roll := 0.0
var _death_time := 0.0
var _step_distance := 0.0
var _step_side := false
var _heartbeat_timer := 0.0


func _ready() -> void:
	add_to_group("player")
	health = max_health
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	_base_fov = clampf(float(Settings.value("fov")), 55.0, 110.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls_enabled and alive:
		var sens := LOOK_SCALE * float(Settings.value("mouse_sensitivity"))
		rotate_y(-event.relative.x * sens)
		_pitch = clampf(_pitch - event.relative.y * sens, -1.45, 1.45)
		view.add_sway(event.relative)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if controls_enabled and alive:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	sprinting = input.y < -0.1 and Input.is_action_pressed("sprint") and controls_enabled and alive
	var wish := transform.basis * Vector3(input.x, 0.0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var target := wish * (sprint_speed if sprinting else walk_speed)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if target.length() > 0.01 else deceleration
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()


func _process(delta: float) -> void:
	# Recoil recovers on its own; shake is driven by a decaying "trauma" value.
	_recoil = lerpf(_recoil, 0.0, 1.0 - exp(-9.0 * delta))
	_trauma = maxf(0.0, _trauma - 1.6 * delta)
	_shake_time += delta * 38.0
	_hit_roll = lerpf(_hit_roll, 0.0, 1.0 - exp(-7.0 * delta))
	var shake := _trauma * _trauma * Settings.shake_scale()
	head.rotation.x = _pitch + _recoil
	camera.rotation = Vector3(
		sin(_shake_time * 1.3) * 0.03 * shake,
		sin(_shake_time * 1.7 + 1.0) * 0.03 * shake,
		sin(_shake_time * 2.1 + 2.0) * 0.045 * shake + _hit_roll * Settings.shake_scale())
	if not alive:
		# Slump to the deck and roll over on defeat.
		_death_time = minf(_death_time + delta, 1.0)
		var k := ease(_death_time, -2.2)
		head.position.y = lerpf(1.62, 0.45, k)
		camera.rotation.z += k * 0.6
		head.rotation.x = lerpf(_pitch, -0.25, k)
	_footsteps(delta)
	_heartbeat_tick(delta)
	var target_fov := _base_fov + (5.0 if sprinting else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-8.0 * delta))


func _footsteps(delta: float) -> void:
	if not alive or not is_on_floor():
		return
	var speed := horizontal_speed()
	if speed < 0.5:
		_step_distance = 0.0
		return
	_step_distance += speed * delta
	var stride := 2.2 if sprinting else 1.75
	if _step_distance >= stride:
		_step_distance = 0.0
		_step_side = not _step_side
		Sfx.play(&"footstep_1" if _step_side else &"footstep_2", -15.0 if not sprinting else -12.0, randf_range(0.92, 1.08))


func _heartbeat_tick(delta: float) -> void:
	if not alive or health > max_health * 0.3:
		_heartbeat_timer = 0.0
		return
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		_heartbeat_timer = 0.8 if health > max_health * 0.15 else 0.6
		Sfx.play(&"heartbeat", -6.0)


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func add_recoil(degrees: float) -> void:
	_recoil = minf(_recoil + deg_to_rad(degrees), deg_to_rad(9.0))


func add_shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func set_look(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	_pitch = clampf(pitch, -1.45, 1.45)


func look_pitch() -> float:
	return _pitch


func take_damage(amount: float, source_position: Vector3) -> void:
	if not alive or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	add_shake(0.65)
	# Roll the view away from whoever hit us.
	var local := global_transform.basis.inverse() * (source_position - global_position)
	_hit_roll = clampf(-local.x, -1.0, 1.0) * 0.09 + (0.04 if local.z > 0.0 else 0.0)
	_recoil -= deg_to_rad(2.5)
	damaged.emit(amount, source_position)
	health_changed.emit(health, max_health)
	Sfx.play(&"player_hurt", -3.0, randf_range(0.95, 1.05))
	if health <= 0.0:
		alive = false
		controls_enabled = false
		died.emit()


## Returns how much health was actually restored.
func heal(amount: float) -> float:
	if not alive:
		return 0.0
	var before := health
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)
	return health - before
