class_name PlayerCamera
extends Node3D
## The player's head. Every rendered frame it places the camera:
##   - smooth at any refresh rate: the body moves on 60 Hz physics ticks, and
##     the head follows the body's position interpolated between the last two
##     ticks (Player.view_origin()); the look itself is applied directly;
##   - look pitch, recoil and shake;
##   - camera life: a soft bob on the shared step rhythm (Player.gait_phase,
##     the same one that plays the footsteps and bobs the weapon), a slight
##     roll into strafes, a spring-driven landing dip and nod scaled by the
##     impact, eased steps up curbs, a nod while mantling, a dip as a slide
##     drops in, a lean into dashes and long landings, and a field of view
##     that widens a little with speed (sprints, slides) on top of the FOV
##     setting but never while aiming.
## Motion scales with Settings.camera_motion(); shake with Settings.shake_scale().

const SLIDE_HEIGHT := 0.98
## Bob height (peak to peak) walking and sprinting, and the side sway.
const BOB_WALK := 0.02
const BOB_SPRINT := 0.032
const BOB_SIDE := 0.01
## Roll into a strafe at walking speed (degrees).
const STRAFE_ROLL := 1.5
## Extra field of view (degrees) from walking speed up to the slide's top speed.
const SPEED_FOV := 8.0
## Landing dip for the hardest landing (m), the impact speeds it scales
## between, and the nod (degrees) that goes with the full dip.
const LAND_DIP := 0.13
const LAND_IMPACT := Vector2(2.5, 17.0)
const LAND_NOD := 1.5
## Initial spring velocity per unit of wanted peak (for _bump's frequency and damping).
const BUMP_GAIN := 33.0
const JUMP_NOD := 0.8
## Slide entry: nod (degrees) and dip (m).
const SLIDE_NOD := 1.6
const SLIDE_DIP := 0.035
## Dash: lean into a sideways dash, nod into a forward one (degrees), and dip (m).
const DASH_LEAN := 4.0
const DASH_NOD := 1.2
const DASH_DIP := 0.02
## Long landings: roll with the sideways momentum (degrees).
const LAND_LEAN := 3.0
## How fast an eased step-up catches up (1/s).
const STEP_EASE := 16.0

## Vertical field of view from the settings.
var base_fov := 72.0
## Current recoil pitch (radians); recovers on its own.
var recoil := 0.0

var _recoil_yaw := 0.0
var _trauma := 0.0
var _shake_time := 0.0
var _hit_roll := 0.0
var _death_time := 0.0
var _crouch := 0.0
var _roll := 0.0
var _step_offset := 0.0
var _stand_height := 1.62
## x: nod (radians, + looks up), y: height (m), z: roll (radians). Landing
## dips, jump nods, slide and dash kicks.
var _bump := MotionSpring.new(15.0, 0.72)
## x: pitch (radians), z: roll (radians) while mantling or vaulting.
var _traverse_pose := MotionSpring.new(12.0, 0.8)

@onready var player: Player = get_parent()
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_stand_height = position.y


func _process(delta: float) -> void:
	_recover(delta)
	var motion := Settings.camera_motion()
	var aim := player.ads
	_crouch = move_toward(_crouch, 1.0 if player.is_crouched() else 0.0, delta * 7.0)
	var bump := _bump.update(Vector3.ZERO, delta)
	var traverse := _traverse_pose.update(_traverse_target(), delta)

	var local := player.global_basis.inverse() * (player.view_origin() - player.global_position)
	var height := lerpf(_stand_height, SLIDE_HEIGHT, ease(_crouch, -1.8)) + _step_offset
	position = local + Vector3(0.0, height, 0.0) + (_bob() * (1.0 - 0.85 * aim) + Vector3(0.0, bump.y, 0.0)) * motion
	rotation.x = player.look_pitch() + recoil + (bump.x + traverse.x) * motion
	rotation.y = _recoil_yaw

	var shake := _trauma * _trauma * Settings.shake_scale() * lerpf(1.0, 0.5, aim)
	var strafe := clampf(player.local_velocity().x / player.walk_speed, -1.0, 1.0)
	_roll = lerpf(_roll, -deg_to_rad(STRAFE_ROLL) * strafe * (1.0 - 0.7 * aim), 1.0 - exp(-8.0 * delta))
	camera.rotation = Vector3(
		sin(_shake_time * 1.3) * 0.03 * shake,
		sin(_shake_time * 1.7 + 1.0) * 0.03 * shake,
		sin(_shake_time * 2.1 + 2.0) * 0.045 * shake + _hit_roll * Settings.shake_scale()
			+ (_roll + _crouch * 0.05 + traverse.z + bump.z) * motion)
	if not player.alive:
		_slump(delta)
	_update_fov(delta, motion)


## Recoil and damage roll recover; shake is a decaying "trauma" value.
func _recover(delta: float) -> void:
	recoil = lerpf(recoil, 0.0, 1.0 - exp(-9.0 * delta))
	_recoil_yaw = lerpf(_recoil_yaw, 0.0, 1.0 - exp(-10.0 * delta))
	_trauma = maxf(0.0, _trauma - 1.6 * delta)
	_shake_time += delta * 38.0
	_hit_roll = lerpf(_hit_roll, 0.0, 1.0 - exp(-7.0 * delta))
	_step_offset *= exp(-STEP_EASE * delta)


## Head bob on the step rhythm: lowest as each foot lands, highest mid-stride,
## and a side sway that swaps feet.
func _bob() -> Vector3:
	var phase := player.gait_phase
	var height := lerpf(BOB_WALK, BOB_SPRINT, player.sprint_amount)
	var c := cos(phase)
	return Vector3(BOB_SIDE * sin(phase), height * (0.5 - c * c), 0.0) * player.gait_amount


## Mantles look down at the ledge while pulling up; vaults lean into the hop.
func _traverse_target() -> Vector3:
	if not player.is_traversing():
		return Vector3.ZERO
	var k := sin(PI * player.traversal_progress())
	if player.traversal_is_vault():
		return Vector3(deg_to_rad(-2.5) * k, 0.0, deg_to_rad(4.5) * k)
	return Vector3(deg_to_rad(-6.0) * k, 0.0, deg_to_rad(-1.5) * k)


## Slump to the deck and roll over on defeat.
func _slump(delta: float) -> void:
	_death_time = minf(_death_time + delta, 1.0)
	var k := ease(_death_time, -2.2)
	position.y = lerpf(_stand_height, 0.45, k)
	camera.rotation.z += k * 0.6
	rotation.x = lerpf(player.look_pitch(), -0.25, k)


## Speed widens the view a little (sprinting, sliding, slide-jumps); aiming
## zooms to the weapon's ADS field of view.
func _update_fov(delta: float, motion: float) -> void:
	var walk := player.walk_speed * player.weapons.move_scale()
	var fast := clampf((player.horizontal_speed() - walk) / maxf(1.0, player.slide_max_speed - walk), 0.0, 1.0)
	var target := base_fov + SPEED_FOV * fast * motion
	target = lerpf(target, base_fov * player.ads_fov_scale(), ease(player.ads, -1.6))
	camera.fov = lerpf(camera.fov, target, 1.0 - exp(-14.0 * delta))


## Where shots go from: the eye where the camera shows it (the smoothed body
## position, so the reticle is exactly what is hit), turned by the look and
## the recoil only. Shake, nods, roll and bob are visual and leave the point
## of aim alone.
func aim_transform() -> Transform3D:
	var eye := lerpf(_stand_height, SLIDE_HEIGHT, ease(_crouch, -1.8)) + _step_offset
	var turn := Basis.from_euler(Vector3(player.look_pitch() + recoil, _recoil_yaw, 0.0))
	return Transform3D(player.global_basis * turn, player.view_origin() + Vector3.UP * eye)


## The body just climbed a step of `height` m in one tick: ease the view up.
func add_step(height: float) -> void:
	_step_offset -= height


## Touchdown at `impact` m/s: a spring dip and nod, bigger for harder landings.
func land(impact: float) -> void:
	var k := smoothstep(LAND_IMPACT.x, LAND_IMPACT.y, impact)
	if k <= 0.0:
		return
	_bump.kick(Vector3(-deg_to_rad(LAND_NOD) * k, -LAND_DIP * k, 0.0) * BUMP_GAIN)


## A soft landing at the end of a mantle.
func settle() -> void:
	_bump.kick(Vector3(-deg_to_rad(0.8), -0.025, 0.0) * BUMP_GAIN)


func jump_kick() -> void:
	_bump.kick(Vector3(deg_to_rad(JUMP_NOD), 0.0, 0.0) * BUMP_GAIN)


## The slide drops in: a nod and a dip on top of the lowered eye.
func slide_kick() -> void:
	_bump.kick(Vector3(-deg_to_rad(SLIDE_NOD), -SLIDE_DIP, 0.0) * BUMP_GAIN)


## A dash along `local` (the body's space: x right, z back, unit length):
## lean into it sideways, nod into it forward.
func dash_kick(local: Vector3) -> void:
	_bump.kick(Vector3(deg_to_rad(DASH_NOD) * local.z, -DASH_DIP, -deg_to_rad(DASH_LEAN) * local.x) * BUMP_GAIN)


## A long landing rolls the view with the sideways momentum (`side` -1 left .. 1 right).
func land_lean(side: float) -> void:
	_bump.kick(Vector3(0.0, 0.0, -deg_to_rad(LAND_LEAN) * (side if absf(side) > 0.2 else 0.5)) * BUMP_GAIN)


## Kicks the view up by `degrees` and sideways by `yaw_degrees` (recovers on its own).
func add_recoil(degrees: float, yaw_degrees := 0.0) -> void:
	recoil = minf(recoil + deg_to_rad(degrees), deg_to_rad(9.0))
	_recoil_yaw = clampf(_recoil_yaw + deg_to_rad(yaw_degrees), deg_to_rad(-3.0), deg_to_rad(3.0))


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## Rolls the view away from a hit coming from `local` (the source in the
## body's space) and knocks the aim down a little.
func hit_from(local: Vector3) -> void:
	_hit_roll = clampf(-local.x, -1.0, 1.0) * 0.09 + (0.04 if local.z > 0.0 else 0.0)
	recoil -= deg_to_rad(2.5)
