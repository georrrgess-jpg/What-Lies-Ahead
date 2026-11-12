class_name Player
extends CharacterBody3D
## First-person controller: WASD movement with sprint, jump and slide, mouse
## look, aim-down-sights, health. Shooting lives in the child
## WeaponController; visuals in WeaponView.
##
## Movement feel:
##   - ground speed reaches its target quickly and stops quickly (no ice);
##   - jumps forgive a late press (coyote time) and an early press (buffer);
##   - sprint + crouch starts a slide that keeps momentum and can be jumped out of;
##   - landings dip the camera, scaled by fall speed.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source_position: Vector3)
signal died
signal jumped
signal landed(impact_speed: float)
signal slide_started

const LOOK_SCALE := 0.0022
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.14
const STAND_HEIGHT := 1.62
const SLIDE_HEIGHT := 1.0

@export var walk_speed := 5.2
@export var sprint_speed := 7.6
@export var aim_speed := 3.6
## How quickly horizontal velocity reaches the target (m/s per second).
@export var acceleration := 55.0
@export var deceleration := 45.0
## Steering while airborne (fraction of ground acceleration).
@export var air_control := 0.35
@export var max_health := 100.0
@export var gravity := 22.0
@export var jump_velocity := 7.4
@export var slide_speed := 10.5
@export var slide_duration := 0.75
@export var slide_cooldown := 0.6

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapons: WeaponController = $Weapons
@onready var view: WeaponView = $Head/Camera3D/WeaponView

var health := 100.0
var alive := true
## False while a menu or results screen owns the input.
var controls_enabled := true
var sprinting := false
var sliding := false
## 0 = hip, 1 = fully aimed down sights. Eased by the weapon's ads_time.
var ads := 0.0

var _pitch := 0.0
var _recoil := 0.0
var _recoil_yaw := 0.0
var _trauma := 0.0
var _shake_time := 0.0
var _base_fov := 72.0
var _hit_roll := 0.0
var _death_time := 0.0
var _head_height := STAND_HEIGHT
var _step_distance := 0.0
var _step_side := false
var _heartbeat_timer := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _land_dip := 0.0
var _slide_left := 0.0
var _slide_cool := 0.0
var _slide_dir := Vector3.ZERO
var _crouch := 0.0          # 0 standing, 1 slide height (camera only)


func _ready() -> void:
	add_to_group("player")
	Loadout.ensure_input_actions()
	_head_height = head.position.y
	health = max_health
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	_base_fov = clampf(float(Settings.value("fov")), 55.0, 110.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls_enabled and alive:
		var sens := LOOK_SCALE * float(Settings.value("mouse_sensitivity"))
		# Aiming slows the look in proportion to the zoom, so tracking feels the same.
		sens *= lerpf(1.0, _ads_fov_scale() * float(Settings.value("ads_sensitivity")), ads)
		rotate_y(-event.relative.x * sens)
		_pitch = clampf(_pitch - event.relative.y * sens, -1.45, 1.45)
		view.add_sway(event.relative * lerpf(1.0, 0.35, ads))
	elif controls_enabled and alive:
		_weapon_switch_input(event)


## 1 / 2 pick the primary / secondary slot; the mouse wheel flips between them.
func _weapon_switch_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_1"):
		weapons.switch_to_slot(0)
	elif event.is_action_pressed("weapon_2"):
		weapons.switch_to_slot(1)
	elif event.is_action_pressed("weapon_next") or event.is_action_pressed("weapon_prev"):
		weapons.switch_next()


func _ads_fov_scale() -> float:
	return weapons.current.ads_fov_scale if weapons and weapons.current else 0.8


func is_aiming() -> bool:
	return ads > 0.5


func _physics_process(delta: float) -> void:
	var can_act := controls_enabled and alive
	var input := Vector2.ZERO
	if can_act:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Aim down sights (hold right mouse). Sprinting and sliding drop the aim.
	var wants_aim := can_act and Input.is_action_pressed("aim") and not sliding and weapons.current != null
	var ads_time := weapons.current.ads_time if weapons.current else 0.18
	ads = move_toward(ads, 1.0 if wants_aim else 0.0, delta / maxf(0.05, ads_time))

	sprinting = can_act and input.y < -0.1 and Input.is_action_pressed("sprint") and ads < 0.3 and not sliding
	var on_floor := is_on_floor()

	# --- jump timing helpers ---
	_coyote = COYOTE_TIME if on_floor else maxf(0.0, _coyote - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	if can_act and Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER

	# --- slide ---
	_slide_cool = maxf(0.0, _slide_cool - delta)
	if can_act and Input.is_action_just_pressed("slide") and on_floor and not sliding and _slide_cool <= 0.0 \
			and horizontal_speed() > walk_speed * 0.8:
		sliding = true
		_slide_left = slide_duration
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		_slide_dir = flat.normalized() if flat.length() > 0.1 else -transform.basis.z
		var boost := maxf(flat.length(), slide_speed)
		velocity.x = _slide_dir.x * boost
		velocity.z = _slide_dir.z * boost
		Sfx.play(&"slide", -6.0, randf_range(0.95, 1.05))
		add_shake(0.12)
		slide_started.emit()

	var wish := transform.basis * Vector3(input.x, 0.0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)

	if sliding:
		_slide_left -= delta
		# Momentum bleeds off; a little steering keeps it controllable.
		horizontal = horizontal.move_toward(Vector3.ZERO, 7.0 * delta)
		horizontal += wish * 4.0 * delta
		if _slide_left <= 0.0 or horizontal.length() < walk_speed * 0.7 or not can_act:
			sliding = false
			_slide_cool = slide_cooldown
	else:
		var speed := sprint_speed if sprinting else walk_speed
		speed = lerpf(speed, aim_speed, ads) * weapons.move_scale()
		var target := wish * speed
		var rate := acceleration if target.length() > 0.01 else deceleration
		if not on_floor:
			rate *= air_control
			# Keep momentum from a slide-jump: never brake below current speed in the air.
			if target.length() < horizontal.length() and target.length() > 0.01:
				target = target.normalized() * horizontal.length()
		horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	# --- vertical ---
	if _jump_buffer > 0.0 and _coyote > 0.0 and can_act:
		_jump_buffer = 0.0
		_coyote = 0.0
		velocity.y = jump_velocity
		if sliding:
			# Slide-jump: carry the slide's speed into the air.
			sliding = false
			_slide_cool = slide_cooldown * 0.5
		Sfx.play(&"jump", -9.0, randf_range(0.95, 1.05))
		jumped.emit()
	elif on_floor and velocity.y <= 0.0:
		velocity.y = -1.0
	else:
		velocity.y -= gravity * delta
	if not on_floor:
		_fall_speed = maxf(_fall_speed, -velocity.y)

	move_and_slide()

	var now_on_floor := is_on_floor()
	if now_on_floor and not _was_on_floor:
		_on_landed(_fall_speed)
	if now_on_floor:
		_fall_speed = 0.0
	_was_on_floor = now_on_floor


func _on_landed(impact: float) -> void:
	if impact < 2.0:
		return
	_land_dip = clampf(impact / 14.0, 0.05, 0.22)
	Sfx.play(&"land", lerpf(-16.0, -6.0, clampf(impact / 12.0, 0.0, 1.0)), randf_range(0.92, 1.05))
	landed.emit(impact)


func _process(delta: float) -> void:
	# Recoil recovers on its own; shake is driven by a decaying "trauma" value.
	_recoil = lerpf(_recoil, 0.0, 1.0 - exp(-9.0 * delta))
	_recoil_yaw = lerpf(_recoil_yaw, 0.0, 1.0 - exp(-10.0 * delta))
	_trauma = maxf(0.0, _trauma - 1.6 * delta)
	_shake_time += delta * 38.0
	_hit_roll = lerpf(_hit_roll, 0.0, 1.0 - exp(-7.0 * delta))
	_land_dip = lerpf(_land_dip, 0.0, 1.0 - exp(-9.0 * delta))
	_crouch = move_toward(_crouch, 1.0 if sliding else 0.0, delta * 7.0)
	var shake := _trauma * _trauma * Settings.shake_scale() * lerpf(1.0, 0.5, ads)
	head.position.y = lerpf(_head_height, SLIDE_HEIGHT, ease(_crouch, -1.8)) - _land_dip * Settings.shake_scale()
	head.rotation.x = _pitch + _recoil
	head.rotation.y = _recoil_yaw
	camera.rotation = Vector3(
		sin(_shake_time * 1.3) * 0.03 * shake,
		sin(_shake_time * 1.7 + 1.0) * 0.03 * shake,
		sin(_shake_time * 2.1 + 2.0) * 0.045 * shake + _hit_roll * Settings.shake_scale() + _crouch * 0.05)
	if not alive:
		# Slump to the deck and roll over on defeat.
		_death_time = minf(_death_time + delta, 1.0)
		var k := ease(_death_time, -2.2)
		head.position.y = lerpf(_head_height, 0.45, k)
		camera.rotation.z += k * 0.6
		head.rotation.x = lerpf(_pitch, -0.25, k)
	_footsteps(delta)
	_heartbeat_tick(delta)
	var target_fov := _base_fov + (5.0 if sprinting else 0.0) + (8.0 * _crouch)
	target_fov = lerpf(target_fov, _base_fov * _ads_fov_scale(), ease(ads, -1.6))
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-14.0 * delta))


func _footsteps(delta: float) -> void:
	if not alive or not is_on_floor() or sliding:
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


## Kicks the view up by `degrees` and sideways by `yaw_degrees` (recovers on its own).
func add_recoil(degrees: float, yaw_degrees := 0.0) -> void:
	_recoil = minf(_recoil + deg_to_rad(degrees), deg_to_rad(9.0))
	_recoil_yaw = clampf(_recoil_yaw + deg_to_rad(yaw_degrees), deg_to_rad(-3.0), deg_to_rad(3.0))


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
