class_name Player
extends CharacterBody3D
## First-person controller: movement, mouse look, aim-down-sights and health.
## Shooting lives in the child WeaponController, the viewmodel in WeaponView,
## the camera's motion in PlayerCamera (the Head), and step-ups, mantles and
## vaults in PlayerTraversal.
##
## Movement feel:
##   - ground speed reaches its target quickly and stops quickly; speed above a
##     sprint (after a slide or a slide-jump) bleeds off gently instead;
##   - the air keeps momentum: the input steers the velocity round and tops it
##     up to running speed, but never adds speed beyond what the jump took off with;
##   - jumps forgive a late press (coyote time) and an early one (buffer), fall
##     a little faster than they rise, and stop short if released early;
##   - curbs up to 0.3 m are stepped over; jump at a ledge while pushing toward
##     it to mantle onto it or vault over it (at a run, thin obstacles are
##     vaulted), and a ledge reached in the air is pulled up onto;
##   - sprint + crouch slides under a lowered capsule: a boost on the entry
##     speed that tires when slides are chained, pulled along by slopes;
##   - dash (V or the mouse's back button, on the ground): a short burst along
##     the input, or forward with none, then back to running speed, on a
##     cooldown; jumping out of it carries no more than a slide-jump does;
##   - firing or aiming ends a sprint at once, and the weapon takes a beat to
##     come up out of its sprint pose before it fires.
##
## Aiming down sights: hold the aim button, or tap it with the "toggle" aim
## setting (sprinting, sliding, mantling or switching weapon lets go). The
## sight comes up over the weapon's ads_time (and goes down in ADS_OUT_SCALE
## of it); reloading and switching lower it and it comes back up by itself
## afterwards. The zoom is the weapon's own times that of the sight fitted to
## it. `ads` is the aim the game plays by (spread, speed), stepped with
## physics; `aim_blend` is the same aim as drawn (zoom, viewmodel, reticles),
## eased and advanced every rendered frame so it is smooth at any refresh rate.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source_position: Vector3)
## A hit the shield soaked (all or part of it); `damaged` follows for any rest.
signal shield_hit(absorbed: float, source_position: Vector3)
signal shield_changed(current: float, maximum: float)
signal died
signal jumped
signal landed(impact_speed: float)
signal slide_started
## A dash started along `direction` (flat, unit length, world space).
signal dashed(direction: Vector3)
## A mantle (`vault` false) or vault started / finished.
signal traversal_started(vault: bool)
signal traversal_finished(vault: bool)

const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.14
## A slide pressed this long before touchdown starts as the player lands.
const SLIDE_BUFFER := 0.2
## A slide this soon after the last one gets no boost at all.
const SLIDE_REST := 0.5
const STAND_CAPSULE := 1.8
const SLIDE_CAPSULE := 1.1
## Sprint stays off this long after the trigger is let go.
const SPRINT_BLOCK := 0.3
const SPRINT_IN_TIME := 0.18
## Weapon raise out of a sprint: the weapon's ADS time times this, clamped.
const SPRINT_OUT_SCALE := 0.7
const SPRINT_OUT_RANGE := Vector2(0.1, 0.17)
## The weapon fires once it is this far out of the sprint pose.
const SPRINT_READY := 0.15
## Lowering the sight takes this share of the time to raise it.
const ADS_OUT_SCALE := 0.75
## Forward input needed to grab a ledge.
const LEDGE_INPUT := 0.3
## Lowest ledge a jump on the ground mantles onto (lower ones are just jumped).
const GROUND_MANTLE_MIN := 0.7
const TRAVERSE_COOLDOWN := 0.25
## A dash pressed this long before it is allowed (cooldown, landing) still happens.
const DASH_BUFFER := 0.15
## Falls landing at this speed (m/s, about a 2.2 m drop) kick up dust and thud.
const HARD_LANDING := 12.0
## Seconds between puffs of dust while sliding.
const SLIDE_DUST_EVERY := 0.07
## Steps per metre (one footfall every half cycle of gait_phase).
const STRIDE_WALK := 1.75
const STRIDE_SPRINT := 2.2
## A move longer than this in one tick is a teleport (the camera snaps).
const TELEPORT_DISTANCE := 1.5
## Collision margin: generous against scenery, so the capsule glides along
## the seams between colliders instead of snagging; tiny while zombies are
## close, where a wide margin would let them shove the player around.
const WALL_MARGIN := 0.03
const CROWD_MARGIN := 0.001

@export var walk_speed := 5.2
@export var sprint_speed := 7.6
@export var aim_speed := 3.6
@export var max_health := 100.0
@export_group("Ground")
## How quickly horizontal velocity reaches the target (m/s per second).
@export var acceleration := 55.0
@export var deceleration := 45.0
## Speed above a sprint bleeds off this gently on the ground (m/s per second).
@export var overspeed_bleed := 10.0
@export_group("Air")
## Acceleration toward the input, up to running speed (m/s per second).
@export var air_acceleration := 15.0
## How fast the input can swing the velocity round (degrees per second).
@export var air_turn_rate := 210.0
## Drag with no input, and on speed above a sprint (m/s per second).
@export var air_drag := 0.8
@export var air_overspeed_drag := 1.6
@export var gravity := 23.0
## Extra gravity on the way down, for a snappier jump.
@export var fall_gravity_scale := 1.45
@export var jump_velocity := 7.44
## Letting go of jump while rising keeps this share of the upward speed.
@export var jump_cut := 0.65
@export_group("Slide")
## Boost added to the entry speed, and the slide's top speed.
@export var slide_boost := 3.0
@export var slide_max_speed := 11.0
## Entry needs this share of sprint speed (or a slide pressed as you land).
@export var slide_entry := 0.85
## Friction (m/s per second), the slope's pull (share of gravity), the speed
## below which the slide ends, and its length on flat ground (seconds).
@export var slide_friction := 4.0
@export var slide_slope := 0.9
@export var slide_exit_speed := 4.4
@export var slide_duration := 1.0
## After a slide the boost recovers over this many seconds (chained slides get less).
@export var slide_recovery := 1.6
## Share of the slide's speed a slide-jump carries.
@export var slide_jump_keep := 0.92
@export_group("Dash")
## Burst speed (scaled by the weapon's move speed, like running), its length
## (the last 40% eases back to running speed) and the wait from one dash to the next.
@export var dash_speed := 13.5
@export var dash_time := 0.16
@export var dash_cooldown := 1.2

@onready var head: PlayerCamera = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapons: WeaponController = $Weapons
@onready var view: WeaponView = $Head/Camera3D/WeaponView
@onready var _capsule: CollisionShape3D = $CollisionShape3D
@onready var _crowd: Area3D = $CrowdSense

var health := 100.0
var alive := true
## False while a menu or results screen owns the input.
var controls_enabled := true
## Set when the run is over: lingering clouds and projectiles cannot hurt any more.
var invulnerable := false
## Extra layer that absorbs damage before health (the station overshield).
var shield := 0.0
var max_shield := 0.0
var sprinting := false
var sliding := false
## 0 = hip, 1 = fully aimed down sights: the aim the game plays by, linear
## over the weapon's ads_time and stepped with physics.
var ads := 0.0
## The aim as shown (0-1): eased, and advanced every rendered frame.
var aim_blend := 0.0
## 0-1: how far the weapon is into its lowered sprint pose.
var sprint_amount := 0.0
## Grip of the ground under the player: 1 normally, lower on ice. Surfaces
## (FrostIceRink) set it; it scales acceleration, braking, air control and
## slide friction.
var surface_grip := 1.0
## Step rhythm shared by the footsteps, the head bob and the weapon bob: a
## foot lands each time it passes a multiple of PI.
var gait_phase := 0.0
## 0-1: how strongly the step rhythm shows (0 standing still, airborne or sliding).
var gait_amount := 0.0

var _pitch := 0.0
## The player wants to aim (button held, or toggled on).
var _aim_held := false
var _aim_latched := false
## The sight is wanted up (aim held, not reloading or switching).
var _sight_up := false
## The shown aim's current move: from, to, seconds in and its length.
var _blend_from := 0.0
var _blend_to := 0.0
var _blend_time := 0.0
var _blend_length := 0.0
var _heartbeat_timer := 0.0
var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_rising := false
var _slide_buffer := 0.0
var _slide_dir := Vector3.FORWARD
var _slide_time := 0.0
var _since_slide := 10.0
var _since_landed := 10.0
var _crouched := false
var _was_on_floor := true
var _fall_speed := 0.0
var _floor_y := 0.0
var _sprint_block := 0.0
var _traverse: PlayerTraversal
var _traverse_vault := false
var _traverse_cool := 0.0
var _dash_buffer := 0.0
## Time left in the dash under way (0 when not dashing) and until the next one.
var _dash_left := 0.0
var _dash_cool := 0.0
var _dash_dir := Vector3.FORWARD
var _dust_timer := 0.0
var _tick_prev := Vector3.ZERO
var _tick_curr := Vector3.ZERO
var _stepped := 0.0
var _step_side := false


func _ready() -> void:
	add_to_group("player")
	Loadout.ensure_input_actions()
	ensure_dash_action()
	health = max_health
	# Own copy of the capsule: its height changes while sliding.
	_capsule.shape = _capsule.shape.duplicate()
	_traverse = PlayerTraversal.new(self, (_capsule.shape as CapsuleShape3D).radius)
	_tick_prev = global_position
	_tick_curr = global_position
	_floor_y = global_position.y
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	head.base_fov = clampf(float(Settings.value("fov")), 55.0, 110.0)


## Mouse look is read here, before the GUI, so a toast or card that happens to
## sit under the captured cursor (the screen centre) never swallows the motion.
## Menus that need the mouse release the capture, which stops this.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and controls_enabled and alive:
		# Screen pixels (mouse counts), not viewport units: the same turn at any window size.
		var look: Vector2 = (event as InputEventMouseMotion).screen_relative * Settings.look_radians() * _aim_look_scale()
		rotate_y(-look.x)
		_pitch = clampf(_pitch - look.y * Settings.look_y_sign(), -1.45, 1.45)
		view.add_look(look)


func _unhandled_input(event: InputEvent) -> void:
	if controls_enabled and alive and not event is InputEventMouseMotion:
		_weapon_switch_input(event)


## Aiming slows the look by the zoom (tan of the half-angles), so a target
## crosses the screen at the same speed as from the hip; then the aim setting.
func _aim_look_scale() -> float:
	var half := deg_to_rad(head.base_fov) * 0.5
	var zoom := tan(half * ads_fov_scale()) / tan(half)
	return lerpf(1.0, zoom * float(Settings.value("ads_sensitivity")), aim_blend)


## 1 / 2 pick the primary / secondary slot; the mouse wheel flips between them.
func _weapon_switch_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_1"):
		weapons.switch_to_slot(0)
	elif event.is_action_pressed("weapon_2"):
		weapons.switch_to_slot(1)
	elif event.is_action_pressed("weapon_next") or event.is_action_pressed("weapon_prev"):
		weapons.switch_next()


## The aim-down-sights FOV as a share of the normal FOV: the held weapon's
## own zoom, magnified further by the sight fitted to it.
func ads_fov_scale() -> float:
	var scale := weapons.current.ads_fov_scale if weapons and weapons.current else 0.8
	var zoom := view.sight_zoom()
	if zoom <= 1.0:
		return scale
	var half := deg_to_rad(head.base_fov) * 0.5
	return atan(tan(half * scale) / zoom) / half


func is_aiming() -> bool:
	return ads > 0.5


## True when the weapon may fire: out of its sprint pose and not mid-mantle.
func weapon_ready() -> bool:
	return sprint_amount <= SPRINT_READY and not _traverse.is_active()


func is_crouched() -> bool:
	return _crouched


func is_traversing() -> bool:
	return _traverse.is_active()


func traversal_is_vault() -> bool:
	return _traverse_vault


## 0-1 through the current mantle or vault.
func traversal_progress() -> float:
	return _traverse.progress()


func _physics_process(delta: float) -> void:
	var can_act := controls_enabled and alive
	var input := Vector2.ZERO
	if can_act:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var on_floor := is_on_floor()
	if on_floor:
		_floor_y = global_position.y
	safe_margin = CROWD_MARGIN if _crowd.has_overlapping_bodies() else WALL_MARGIN
	_tick_timers(delta, can_act, on_floor)
	_update_aim(delta, can_act)

	if _traverse.is_active():
		if not alive or not _traverse.step(delta):
			_end_traversal()
		_after_move()
		return

	_update_sprint(delta, can_act, input)
	var wish := global_basis * Vector3(input.x, 0.0, input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	if can_act and _try_traversal(input, wish, on_floor):
		_traverse.step(delta)
		_after_move()
		return
	_update_slide(can_act, on_floor)
	_update_dash(can_act, wish)
	if _dash_left > 0.0:
		_dash_move(delta, on_floor)
	elif sliding:
		_slide_move(delta, can_act, on_floor, wish)
	else:
		_run_move(delta, on_floor, wish)
	_vertical_move(delta, can_act, on_floor)

	var climbed := -1.0
	if on_floor and not sliding and horizontal_speed() > 0.5:
		climbed = _traverse.step_up(Vector3(velocity.x, 0.0, velocity.z) * delta)
	if climbed < 0.0:
		move_and_slide()
	elif climbed > 0.0:
		# The step moved the body this tick; the camera eases up after it.
		_stepped += climbed
		head.add_step(climbed)
	_after_move()


func _tick_timers(delta: float, can_act: bool, on_floor: bool) -> void:
	_coyote = COYOTE_TIME if on_floor else maxf(0.0, _coyote - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_slide_buffer = maxf(0.0, _slide_buffer - delta)
	_traverse_cool = maxf(0.0, _traverse_cool - delta)
	_dash_buffer = maxf(0.0, _dash_buffer - delta)
	_dash_cool = maxf(0.0, _dash_cool - delta)
	_since_landed += delta
	if not sliding:
		_since_slide += delta
	if can_act and Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	if can_act and Input.is_action_just_pressed("slide"):
		_slide_buffer = SLIDE_BUFFER
	if can_act and Input.is_action_just_pressed(&"dash"):
		_dash_buffer = DASH_BUFFER
	# Firing ends a sprint at once and keeps it off while the trigger is busy.
	if can_act and Input.is_action_pressed("fire"):
		_sprint_block = SPRINT_BLOCK
	else:
		_sprint_block = maxf(0.0, _sprint_block - delta)


## Aim down sights: hold the aim button, or tap it to toggle (Settings
## "aim_mode"). Sliding and mantling drop the aim; a reload or a weapon switch
## lowers the sight and it comes back up afterwards.
func _update_aim(delta: float, can_act: bool) -> void:
	var able := can_act and not sliding and not _traverse.is_active() and weapons.current != null
	if not Settings.aim_toggles():
		_aim_latched = false
		_aim_held = able and Input.is_action_pressed("aim")
	else:
		if not able or Input.is_action_just_pressed("sprint"):
			_aim_latched = false
		elif Input.is_action_just_pressed("aim"):
			_aim_latched = not _aim_latched
		_aim_held = _aim_latched
	_sight_up = _aim_held and not weapons.is_reloading() and not weapons.is_switching()
	ads = move_toward(ads, 1.0 if _sight_up else 0.0, delta / _aim_time(_sight_up))


## Seconds to raise (or lower) the sight all the way: the weapon's, scaled by its sight.
func _aim_time(raising: bool) -> float:
	var ads_time := weapons.current.ads_time if weapons.current else 0.18
	return maxf(0.05, ads_time * view.sight_ads_time_scale() * (1.0 if raising else ADS_OUT_SCALE))


## The shown aim, per rendered frame. Each raise or lower starts from where
## the sight is and takes the share of the full time still to go, on
## _aim_curve, so the zoom and the viewmodel (both driven by it) arrive
## together. Without physics (stills, audits) it shows `ads` as set.
func _update_aim_blend(delta: float) -> void:
	if not is_physics_processing():
		aim_blend = ads
		_blend_to = -1.0
		return
	var target := 1.0 if _sight_up else 0.0
	if target != _blend_to:
		_blend_from = aim_blend
		_blend_to = target
		_blend_time = 0.0
		_blend_length = absf(target - aim_blend) * _aim_time(_sight_up)
	_blend_time += delta
	aim_blend = lerpf(_blend_from, _blend_to, _aim_curve(clampf(_blend_time / maxf(_blend_length, 1e-4), 0.0, 1.0)))


## 0-1 over a raise or lower: gathers speed over the first quarter, then a long
## soft arrival; no jump in speed at either end.
static func _aim_curve(t: float) -> float:
	var r := 1.0 - t
	return 1.0 - r * r * r * r * (1.0 + 4.0 * t)


func _update_sprint(delta: float, can_act: bool, input: Vector2) -> void:
	sprinting = can_act and input.y < -0.1 and Input.is_action_pressed("sprint") and not sliding \
		and not _crouched and not _aim_held and _sprint_block <= 0.0
	var target := 1.0 if sprinting else 0.0
	var time := SPRINT_IN_TIME if target > sprint_amount else _sprint_out_time()
	sprint_amount = move_toward(sprint_amount, target, delta / time)


func _sprint_out_time() -> float:
	var ads_time := weapons.current.ads_time if weapons.current else 0.18
	return clampf(ads_time * SPRINT_OUT_SCALE, SPRINT_OUT_RANGE.x, SPRINT_OUT_RANGE.y)


# --- mantle and vault --------------------------------------------------------------

## Jump at a ledge (or reach one in the air) while pushing toward it: mantle
## onto it or vault over it.
func _try_traversal(input: Vector2, wish: Vector3, on_floor: bool) -> bool:
	if _traverse_cool > 0.0 or input.y > -LEDGE_INPUT:
		return false
	var dir := Vector3(wish.x, 0.0, wish.z).normalized()
	# The run-up: brushing the obstacle a tick early must not turn a sprint
	# into a crawl; a dash carries over no faster than a slide.
	var toward := minf(maxf(velocity.dot(dir), sprint_amount * sprint_speed * weapons.move_scale()), slide_max_speed)
	var grounded := on_floor or _coyote > 0.0
	var kind := PlayerTraversal.Kind.NONE
	if grounded and _jump_buffer > 0.0:
		if _crouched and not _stand_up():
			return false
		kind = _traverse.plan(dir, _floor_y, false, toward)
		if kind == PlayerTraversal.Kind.MANTLE and _traverse.planned_height() < GROUND_MANTLE_MIN:
			kind = PlayerTraversal.Kind.NONE
	elif not grounded and not _crouched:
		# Not a ledge the jump is still going to clear by itself.
		var apex_rise := pow(maxf(velocity.y, 0.0), 2.0) / (2.0 * gravity)
		kind = _traverse.plan(dir, _floor_y, true, toward, apex_rise - 0.15)
	if kind == PlayerTraversal.Kind.NONE:
		return false
	_begin_traversal(kind == PlayerTraversal.Kind.VAULT, toward)
	return true


func _begin_traversal(vault: bool, run_up: float) -> void:
	if sliding:
		_end_slide()
	_dash_left = 0.0
	_traverse_vault = vault
	_jump_buffer = 0.0
	_coyote = 0.0
	_jump_rising = false
	_traverse.begin(run_up)
	Sfx.play(&"move_vault" if vault else &"move_mantle", -5.0 if vault else -7.0, randf_range(0.95, 1.05))
	traversal_started.emit(vault)


func _end_traversal() -> void:
	_fall_speed = 0.0
	_traverse_cool = TRAVERSE_COOLDOWN
	if not _traverse_vault:
		head.settle()
		Sfx.play(&"move_mantle_land", -13.0, randf_range(0.95, 1.05))
	traversal_finished.emit(_traverse_vault)


# --- slide ----------------------------------------------------------------------------

func _update_slide(can_act: bool, on_floor: bool) -> void:
	if sliding:
		return
	if _crouched:
		_stand_up()
	if not can_act or _slide_buffer <= 0.0 or not on_floor:
		return
	# Fast enough (a sprint), or a slide pressed as the player lands.
	var speed := horizontal_speed()
	var sprint := sprint_speed * weapons.move_scale()
	if speed >= sprint * slide_entry or (_since_landed < SLIDE_BUFFER and speed >= walk_speed * 0.75):
		_start_slide()


func _start_slide() -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var entry := flat.length()
	_slide_dir = flat / entry if entry > 0.1 else -global_basis.z
	# The boost tires when slides are chained, so slide-hopping never beats running.
	var rested := clampf((_since_slide - SLIDE_REST) / (slide_recovery - SLIDE_REST), 0.0, 1.0)
	var speed := maxf(entry, minf(entry + slide_boost * rested, slide_max_speed))
	velocity.x = _slide_dir.x * speed
	velocity.z = _slide_dir.z * speed
	sliding = true
	_slide_time = 0.0
	_slide_buffer = 0.0
	_set_crouched(true)
	_dust_timer = 0.0
	Sfx.play(&"slide", -6.0, randf_range(0.95, 1.05))
	add_shake(0.12)
	head.slide_kick()
	slide_started.emit()


func _slide_move(delta: float, can_act: bool, on_floor: bool, wish: Vector3) -> void:
	_slide_time += delta
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	var dir := flat / speed if speed > 0.05 else _slide_dir
	var grip := lerpf(1.0, surface_grip, 0.8)
	# A little steering; pulling back brakes.
	var along := wish.dot(dir)
	if wish.length() > 0.1 and along > -0.3:
		var turn := deg_to_rad(40.0) * grip * delta
		dir = dir.rotated(Vector3.UP, clampf(dir.signed_angle_to(wish, Vector3.UP), -turn, turn))
	var friction := slide_friction * grip + maxf(0.0, -along) * 7.0
	# Gravity along the floor: downhill speeds the slide up, uphill slows it.
	var pull := 0.0
	if on_floor:
		var n := get_floor_normal()
		pull = Vector3(n.x, 0.0, n.z).dot(dir) * n.y * gravity * slide_slope
	speed = clampf(speed + (pull - friction) * delta, 0.0, slide_max_speed + 2.0)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_slide_dir = dir
	_slide_dust(delta, on_floor)
	var tired := _slide_time > slide_duration / grip and pull < friction
	if speed < slide_exit_speed or tired or _slide_time > 3.0 or not can_act or _coyote <= 0.0:
		_end_slide()


## A trail of dust from the feet while the slide is on the ground.
func _slide_dust(delta: float, on_floor: bool) -> void:
	_dust_timer -= delta
	if on_floor and _dust_timer <= 0.0:
		_dust_timer = SLIDE_DUST_EVERY
		MoveFx.trail(get_parent(), global_position, _slide_dir)


func _end_slide() -> void:
	sliding = false
	_since_slide = 0.0
	_stand_up()


## Restores the standing capsule if there is room; otherwise the player stays
## low (and slow) until there is. Returns true when standing.
func _stand_up() -> bool:
	if not _crouched:
		return true
	if test_move(global_transform, Vector3.UP * (STAND_CAPSULE - SLIDE_CAPSULE)):
		return false
	_set_crouched(false)
	return true


func _set_crouched(on: bool) -> void:
	_crouched = on
	var shape := _capsule.shape as CapsuleShape3D
	shape.height = SLIDE_CAPSULE if on else STAND_CAPSULE
	_capsule.position.y = shape.height * 0.5


# --- dash -----------------------------------------------------------------------------

## Adds the "dash" InputMap action (V, the mouse's back button) when the
## project does not define it.
static func ensure_dash_action() -> void:
	if InputMap.has_action(&"dash"):
		return
	InputMap.add_action(&"dash")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_V
	InputMap.action_add_event(&"dash", key)
	var thumb := InputEventMouseButton.new()
	thumb.button_index = MOUSE_BUTTON_XBUTTON1
	InputMap.action_add_event(&"dash", thumb)


func is_dashing() -> bool:
	return _dash_left > 0.0


## A dash press starts one on the ground (or just off a ledge) once the
## cooldown is over; a slide under way gives way to it.
func _update_dash(can_act: bool, wish: Vector3) -> void:
	if _dash_left > 0.0 or not can_act or _dash_buffer <= 0.0 or _dash_cool > 0.0 or _coyote <= 0.0:
		return
	if sliding:
		_end_slide()
	var flat := Vector3(wish.x, 0.0, wish.z)
	_dash_dir = flat.normalized() if flat.length_squared() > 0.01 else -global_basis.z
	_dash_left = dash_time
	_dash_cool = dash_cooldown
	_dash_buffer = 0.0
	Sfx.play(&"move_dash", -7.0, randf_range(0.95, 1.05))
	head.dash_kick(global_basis.inverse() * _dash_dir)
	MoveFx.puff(get_parent(), global_position, _dash_dir)
	dashed.emit(_dash_dir)


## Full speed for most of the dash, easing back to running speed at the end;
## running off a ledge ends it once the coyote time is up.
func _dash_move(delta: float, on_floor: bool) -> void:
	_dash_left = maxf(0.0, _dash_left - delta)
	var exit := sprint_speed * weapons.move_scale()
	var k := smoothstep(0.6, 1.0, 1.0 - _dash_left / dash_time)
	var speed := lerpf(dash_speed * weapons.move_scale(), exit, k)
	velocity.x = _dash_dir.x * speed
	velocity.z = _dash_dir.z * speed
	if not on_floor and _coyote <= 0.0:
		_end_dash()


## Stops a dash early (a jump, a ledge): what carries on is no faster than the
## best slide-jump, so a dash never opens a gap a slide-jump cannot cross.
func _end_dash() -> void:
	_dash_left = 0.0
	var flat := Vector2(velocity.x, velocity.z).limit_length(slide_max_speed * slide_jump_keep)
	velocity.x = flat.x
	velocity.z = flat.y


# --- running and the air ----------------------------------------------------------

func _run_move(delta: float, on_floor: bool, wish: Vector3) -> void:
	var speed := sprint_speed if sprinting else walk_speed
	speed = lerpf(speed, aim_speed, ads) * weapons.move_scale()
	if _crouched:
		speed = minf(speed, walk_speed * 0.5)
	var target := wish * speed
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	flat = _ground_move(flat, target, delta) if on_floor else _air_move(flat, target, delta)
	velocity.x = flat.x
	velocity.z = flat.z


func _ground_move(flat: Vector3, target: Vector3, delta: float) -> Vector3:
	if target.length_squared() < 1e-4:
		return flat.move_toward(Vector3.ZERO, deceleration * surface_grip * delta)
	# Momentum beyond a sprint bleeds off gently while it turns to the input.
	var cap := maxf(target.length(), sprint_speed * weapons.move_scale())
	var speed := flat.length()
	if speed > cap:
		target = target.normalized() * maxf(cap, speed - overspeed_bleed * delta)
	return flat.move_toward(target, acceleration * surface_grip * delta)


## Air: no input coasts with light drag. Input within 135° of the motion
## swings the velocity toward it (keeping its speed); within 90° it also tops
## the speed up to the target, never past what the player already has.
## Input against the motion brakes.
func _air_move(flat: Vector3, target: Vector3, delta: float) -> Vector3:
	var speed := flat.length()
	var sprint := sprint_speed * weapons.move_scale()
	if speed > sprint:
		flat = flat.normalized() * maxf(sprint, speed - air_overspeed_drag * delta)
		speed = flat.length()
	if target.length_squared() < 1e-4:
		return flat.move_toward(Vector3.ZERO, air_drag * delta)
	var dir := target.normalized()
	var angle := flat.signed_angle_to(dir, Vector3.UP) if speed > 0.5 else 0.0
	if absf(angle) < deg_to_rad(135.0):
		var turn := deg_to_rad(air_turn_rate) * surface_grip * delta
		flat = flat.rotated(Vector3.UP, clampf(angle, -turn, turn))
	if absf(angle) > deg_to_rad(90.0) and absf(angle) < deg_to_rad(135.0):
		return flat
	var cap := maxf(speed, target.length())
	flat += dir * clampf(target.length() - flat.dot(dir), 0.0, air_acceleration * surface_grip * delta)
	return flat.limit_length(cap)


func _vertical_move(delta: float, can_act: bool, on_floor: bool) -> void:
	if _jump_buffer > 0.0 and _coyote > 0.0 and can_act and _stand_up():
		_jump()
	elif on_floor and velocity.y <= 0.0:
		velocity.y = -1.0
	else:
		# Let go of jump while rising: a shorter hop.
		if _jump_rising and velocity.y > 0.0 and not Input.is_action_pressed("jump"):
			velocity.y *= jump_cut
			_jump_rising = false
		velocity.y -= gravity * (fall_gravity_scale if velocity.y < 0.0 else 1.0) * delta
	if velocity.y <= 0.0:
		_jump_rising = false
	if not on_floor:
		_fall_speed = maxf(_fall_speed, -velocity.y)


func _jump() -> void:
	_jump_buffer = 0.0
	_coyote = 0.0
	if sliding:
		# Slide-jump: carry most of the slide's speed into the air.
		velocity.x *= slide_jump_keep
		velocity.z *= slide_jump_keep
		_end_slide()
	if _dash_left > 0.0:
		_end_dash()
	velocity.y = jump_velocity
	# A jump buffered before landing (key already up) is a full jump.
	_jump_rising = Input.is_action_pressed("jump")
	Sfx.play(&"jump", -9.0, randf_range(0.95, 1.05))
	head.jump_kick()
	jumped.emit()


func _after_move() -> void:
	var now_on_floor := is_on_floor()
	if now_on_floor and not _was_on_floor:
		_on_landed(_fall_speed)
	if now_on_floor:
		_fall_speed = 0.0
	_was_on_floor = now_on_floor
	_record_tick()


func _on_landed(impact: float) -> void:
	_since_landed = 0.0
	# Both feet land: the step rhythm starts afresh.
	gait_phase = roundf(gait_phase / PI) * PI
	head.land(impact)
	if impact < 2.0:
		return
	Sfx.play(&"land", lerpf(-16.0, -6.0, clampf(impact / 12.0, 0.0, 1.0)), randf_range(0.92, 1.05))
	if impact >= HARD_LANDING:
		# A long drop: the view rolls with the sideways momentum, dust rings out.
		head.land_lean(clampf(local_velocity().x / walk_speed, -1.0, 1.0))
		Sfx.play(&"move_land_heavy", -8.0, randf_range(0.95, 1.05))
		MoveFx.ring(get_parent(), global_position)
	landed.emit(impact)


# --- smooth view between physics ticks ---------------------------------------------

func _record_tick() -> void:
	_tick_prev = _tick_curr
	_tick_curr = global_position
	# A step-up is eased by the head instead.
	_tick_prev.y += _stepped
	_stepped = 0.0
	if _tick_prev.distance_to(_tick_curr) > TELEPORT_DISTANCE:
		_tick_prev = _tick_curr


## The body's position interpolated between the last two physics ticks, for a
## camera that moves smoothly at any frame rate. Snaps after a teleport.
func view_origin() -> Vector3:
	if not global_position.is_equal_approx(_tick_curr):
		# Moved outside the physics step (spawn, respawn, staging).
		_tick_prev = global_position
		_tick_curr = global_position
	return _tick_prev.lerp(_tick_curr, Engine.get_physics_interpolation_fraction())


# --- per frame ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_aim_blend(delta)
	_update_gait(delta)
	_heartbeat_tick(delta)


## Advances the step rhythm by the distance walked and plays a footstep each
## time a foot lands. The head and weapon bob read the same phase.
func _update_gait(delta: float) -> void:
	var speed := horizontal_speed()
	var grounded := alive and is_on_floor() and not sliding and _dash_left <= 0.0 and not _traverse.is_active()
	var target := clampf(speed / walk_speed, 0.0, 1.0) if grounded else 0.0
	gait_amount = move_toward(gait_amount, target, delta * 6.0)
	if not grounded or speed < 0.3:
		return
	var before := gait_phase
	gait_phase = fmod(gait_phase + speed * delta / lerpf(STRIDE_WALK, STRIDE_SPRINT, sprint_amount) * PI, TAU * 64.0)
	if floorf(gait_phase / PI) != floorf(before / PI):
		_step_side = not _step_side
		var loud := sprint_amount > 0.5
		Sfx.play(&"footstep_1" if _step_side else &"footstep_2", -12.0 if loud else -15.0, randf_range(0.92, 1.08))


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


## Velocity in the body's own space (x right, z back).
func local_velocity() -> Vector3:
	return global_basis.inverse() * velocity


## The unshaken aim: shots and aim previews start here (see PlayerCamera.aim_transform()).
func aim_transform() -> Transform3D:
	return head.aim_transform()


## Kicks the view up by `degrees` and sideways by `yaw_degrees` (recovers on its own).
func add_recoil(degrees: float, yaw_degrees := 0.0) -> void:
	head.add_recoil(degrees, yaw_degrees)


func add_shake(amount: float) -> void:
	head.add_trauma(amount)


func set_look(yaw: float, pitch: float) -> void:
	rotation.y = yaw
	_pitch = clampf(pitch, -1.45, 1.45)


func look_pitch() -> float:
	return _pitch


func take_damage(amount: float, source_position: Vector3) -> void:
	if not alive or invulnerable or amount <= 0.0:
		return
	# Roll the view away from whoever hit us.
	head.hit_from(global_transform.basis.inverse() * (source_position - global_position))
	var absorbed := minf(shield, amount)
	if absorbed > 0.0:
		shield -= absorbed
		shield_changed.emit(shield, max_shield)
		shield_hit.emit(absorbed, source_position)
		amount -= absorbed
		if amount <= 0.0:
			add_shake(0.25)
			return
	health = maxf(0.0, health - amount)
	add_shake(0.65)
	damaged.emit(amount, source_position)
	health_changed.emit(health, max_health)
	Sfx.play(&"player_hurt", -3.0, randf_range(0.95, 1.05))
	if health <= 0.0:
		alive = false
		controls_enabled = false
		died.emit()


## Sets the shield layer (e.g. a station purchase); 0 removes it.
func set_shield(amount: float, maximum: float) -> void:
	max_shield = maximum
	shield = clampf(amount, 0.0, maximum)
	shield_changed.emit(shield, max_shield)


## Returns how much health was actually restored.
func heal(amount: float) -> float:
	if not alive:
		return 0.0
	var before := health
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)
	return health - before
