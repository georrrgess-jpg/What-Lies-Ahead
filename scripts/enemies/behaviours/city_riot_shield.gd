class_name CityRiotShieldBehaviour
extends NeonRiotShieldBehaviour
## Riot Shield (Ashfall City, Precinct 9): a riot cop behind a tall clear
## shield. Body shots from the front clang off it (it soaks them until it
## cracks); headshots over the rim and shots from the side or behind land.
## At mid range it plants the shield and beats its baton on the rim three
## times while the shield's light bar flashes red and blue (the telegraph: the
## threat ring warns), then rushes shield-first in a straight line; a hit
## knocks the player back hard. After the rush the shield swings wide for a
## moment: sidestep the rush, then shoot it while it recovers.

@export_group("Bash")
@export var min_range := 3.5
@export var max_range := 11.0
@export var cooldown := 7.5
## Seconds of baton drumming before the rush.
@export var drum_time := 1.05
## Share of the drum after which the rush direction is locked (strafe after it).
@export_range(0.0, 1.0) var lock_fraction := 0.7
@export var rush_speed := 9.5
@export var rush_time := 0.75
@export var damage := 22.0
@export var shove := 8.0
@export var hit_radius := 1.5
## Seconds the shield stays wide after a rush (every shot lands).
@export var exposed_time := 1.3
@export var drum_clip: StringName = &"Drum"
@export var rush_clip: StringName = &"Run"
@export var recover_clip: StringName = &"Recover"
@export var drum_sound: StringName = &"cz_riot_drum"
@export var rush_sound: StringName = &"cz_riot_rush"
@export var bash_sound: StringName = &"cz_riot_bash"

## Light bar flash rate (colour swaps per second) during the drum and rush.
const FLASH_RATE := 9.0
const RED := Color(1.0, 0.16, 0.22)
const BLUE := Color(0.18, 0.42, 1.0)

var _cool := 3.0
var _drum := 0.0
var _rush := 0.0
var _exposed := 0.0
var _dir := Vector3.FORWARD
var _hit := false
var _flash := 0.0
var _light: OmniLight3D


func on_ready(z: Zombie) -> void:
	super.on_ready(z)
	_cool = randf_range(2.0, cooldown)
	_light = OmniLight3D.new()
	_light.omni_range = 4.5
	_light.light_energy = 2.2
	_light.shadow_enabled = false
	_light.visible = false
	z.add_child(_light)
	_light.position = Vector3(0.0, 1.62, 0.7) * z.data.body_scale


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	if _drum > 0.0:
		_tick_drum(z, delta)
		return true
	if _rush > 0.0:
		_tick_rush(z, delta)
		return true
	if _exposed > 0.0:
		_exposed -= delta
		z.move_with(Vector3.ZERO)
		if _exposed <= 0.0:
			z.play_animation(z.data.move_animation, 0.25)
		return true
	if _cool <= 0.0 and is_shielded() and z.state == Zombie.State.CHASE and z.target.alive:
		var d := z.distance_to_target()
		if d >= min_range and d <= max_range and z.has_line_of_sight():
			_begin(z)
			return true
	return false


func on_hit(z: Zombie, amount: float, hit_position: Vector3, headshot: bool) -> float:
	if _exposed > 0.0:
		return amount
	return super.on_hit(z, amount, hit_position, headshot)


func is_winding_up() -> bool:
	return _drum > 0.0 or _rush > 0.0


## A heavy hit during the drum breaks the bash (a rush in flight carries on).
func interrupt(z: Zombie) -> void:
	if _drum <= 0.0:
		return
	_drum = 0.0
	_cool = cooldown * 0.5
	_light.visible = false
	z.play_animation(z.data.move_animation, 0.15)


func on_death(_z: Zombie) -> void:
	_drum = 0.0
	_rush = 0.0
	if is_instance_valid(_light):
		_light.visible = false


func _begin(z: Zombie) -> void:
	_cool = cooldown
	_drum = drum_time
	_dir = BossMove.flat_to_target(z)
	_light.visible = true
	z.play_animation(drum_clip, 0.1)
	Sfx.play_at(drum_sound, z.global_position + Vector3.UP * 1.4, 0.0, randf_range(0.95, 1.05))


func _tick_drum(z: Zombie, delta: float) -> void:
	_drum -= delta
	if _drum > drum_time * (1.0 - lock_fraction):
		_dir = BossMove.flat_to_target(z)
	z.face_toward(_dir, delta * 2.0)
	z.move_with(Vector3.ZERO)
	_flash_lights(delta)
	if _drum <= 0.0:
		_rush = rush_time
		_hit = false
		z.play_animation(rush_clip, 0.06)
		Sfx.play_at(rush_sound, z.global_position + Vector3.UP, 2.0, randf_range(0.95, 1.05))


func _tick_rush(z: Zombie, delta: float) -> void:
	_rush -= delta
	var before := z.global_position
	z.face_toward(_dir, delta * 4.0)
	z.move_with(_dir * rush_speed)
	_flash_lights(delta)
	_contact(z)
	var stuck := before.distance_to(z.global_position) < rush_speed * delta * 0.25 and _rush < rush_time - 0.15
	if _rush <= 0.0 or _hit or stuck:
		_end_rush(z)


func _contact(z: Zombie) -> void:
	var player := z.target
	if _hit or not player.alive:
		return
	var rel := player.global_position - z.global_position
	rel.y = 0.0
	if rel.length() > hit_radius * z.data.body_scale or rel.normalized().dot(_dir) < 0.2:
		return
	_hit = true
	player.take_damage(damage, z.global_position)
	player.velocity += _dir * shove + Vector3.UP * 3.0
	player.add_shake(0.25)
	Sfx.play_at(bash_sound, player.global_position + Vector3.UP, 2.0, randf_range(0.95, 1.05))
	Fx.impact(z.get_parent(), player.global_position + Vector3.UP, -_dir, spark_color)


func _end_rush(z: Zombie) -> void:
	_rush = 0.0
	_light.visible = false
	_exposed = exposed_time
	z.play_animation(recover_clip, 0.08)


func _break(z: Zombie, at: Vector3) -> void:
	super._break(z, at)
	_drum = 0.0
	if is_instance_valid(_light):
		_light.visible = false


## Swaps the light bar's glow between red and blue.
func _flash_lights(delta: float) -> void:
	_flash += delta * FLASH_RATE
	_light.light_color = RED if int(_flash) % 2 == 0 else BLUE
