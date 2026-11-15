class_name CityFirebugBehaviour
extends EnemyBehaviour
## Firebug (Ashfall City, Neon Market): keeps to mid range and throws lit
## bottles. The wind-up is the tell: it stops, flicks its lighter to the rag
## (the bottle appears in its hand, burning) and cocks its arm back while the
## threat ring warns. On release a ring marks the floor where the bottle will
## land (where the player is heading) and the bottle lobs in to land exactly
## as the ring fills: a burst of fire, then a short-lived burning patch.
## Step out of the ring, and out of the flames. A headshot during the wind-up
## makes it drop the bottle. It backs off when the player gets close (its
## walk played in reverse, so it steps backwards), but a cornered Firebug
## claws like any zombie.

@export var min_range := 6.0
@export var max_range := 22.0
@export var cooldown := 5.5
@export var windup := 1.0
## Damage of the burst where the bottle lands, and of the patch per second.
@export var damage := 9.0
@export var damage_per_second := 6.0
@export var radius := 1.7
@export var linger := 3.2
@export var projectile_speed := 13.0
## How much of the player's motion the throw leads.
@export var lead := 0.55
@export var apex := 2.4
@export var color := Color(1.0, 0.5, 0.12)
@export var bottle_mesh := "Acc_Firebug_Bottle"
@export var throw_clip: StringName = &"Throw_Bottle"
@export var windup_sound: StringName = &"cz_firebug_light"
@export var throw_sound: StringName = &"cz_firebug_throw"
@export var smash_sound: StringName = &"cz_bottle_smash"

@export_group("Distance")
## Backs away while the player is closer than this (and it has room).
@export var retreat_range := 5.0
@export var retreat_seconds := 0.9
@export var retreat_cooldown := 3.5
## Speed while backing off, as a fraction of its walking speed.
@export var retreat_speed := 0.85

## Fraction of the throw clip at which the arm comes forward.
const RELEASE_FRACTION := 21.0 / 30.0

var _cool := 3.0
var _winding := 0.0
var _retreat := 0.0
var _retreat_cool := 0.0
var _backing := false
var _anim: AnimationPlayer
var _bottle: Node3D


func on_ready(z: Zombie) -> void:
	_anim = z.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_bottle = z.model_root.find_child(bottle_mesh, true, false) as Node3D
	if _bottle:
		_bottle.visible = false
	_cool = randf_range(1.5, cooldown)


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	_retreat_cool -= delta
	if _winding > 0.0:
		_winding -= delta
		z.face_toward(BossMove.flat_to_target(z), delta * 1.5)
		z.move_with(Vector3.ZERO)
		if _winding <= 0.0:
			_release(z)
		return true
	if z.state != Zombie.State.CHASE or not z.target.alive:
		_backing = false
		return false
	var d := z.distance_to_target()
	if _cool <= 0.0 and d >= min_range and d <= max_range and z.has_line_of_sight():
		_begin(z)
		return true
	if _retreat > 0.0 or (_retreat_cool <= 0.0 and d < retreat_range and d > 2.2):
		return _back_off(z, delta)
	_stop_backing(z)
	return false


func on_hit(z: Zombie, amount: float, _hit_position: Vector3, headshot: bool) -> float:
	if headshot:
		interrupt(z)
	return amount


func interrupt(z: Zombie) -> void:
	if _winding <= 0.0:
		return
	_winding = 0.0
	_cool = cooldown * 0.6
	_show_bottle(false)
	if _anim:
		_anim.speed_scale = 1.0
	Fx.impact(z.get_parent(), z.global_position + Vector3.UP * 1.8 * z.data.body_scale, Vector3.UP, color)
	Sfx.play_at(smash_sound, z.global_position + Vector3.UP, -4.0, 1.2)
	z.play_animation(&"Stagger", 0.05)


func on_death(_z: Zombie) -> void:
	_show_bottle(false)


func is_winding_up() -> bool:
	return _winding > 0.0


func _begin(z: Zombie) -> void:
	_cool = cooldown
	_winding = windup
	_retreat = 0.0
	_backing = false
	_show_bottle(true)
	if _anim and _anim.has_animation(throw_clip):
		_anim.play(throw_clip, 0.1)
		_anim.speed_scale = _anim.get_animation(throw_clip).length * RELEASE_FRACTION / windup
	Sfx.play_at(windup_sound, z.global_position + Vector3.UP * 1.6, 0.0, randf_range(0.95, 1.05))


## Releases the bottle: marks the landing spot and sends it on its way.
func _release(z: Zombie) -> void:
	_show_bottle(false)
	if _anim:
		_anim.speed_scale = 1.0
	var player := z.target
	var from := z.global_position + Vector3.UP * 2.0 * z.data.body_scale
	var t := clampf(z.distance_to_target() / projectile_speed, 0.6, 1.5)
	var aim := player.global_position + player.velocity * Vector3(1, 0, 1) * t * lead
	var zone := BossZone.new()
	zone.radius = radius
	zone.telegraph = t
	zone.damage = damage
	zone.color = color
	zone.prop = BossZone.Prop.NONE
	zone.linger = linger
	zone.linger_dps = damage_per_second
	zone.warn_sound = &""
	zone.hit_sound = smash_sound
	zone.source = z
	z.get_parent().add_child(zone)
	zone.global_position = BossMove.floor_point(z, aim)
	CityFireBottle.throw(z.get_parent(), from, zone, t, apex, linger)
	Sfx.play_at(throw_sound, from, 0.0, randf_range(0.92, 1.06))
	z.play_animation(z.data.move_animation, 0.3)


## Backs away from a player who closed in, facing them, toward the walkable
## floor behind it (a cornered Firebug stands and fights).
func _back_off(z: Zombie, delta: float) -> bool:
	if _retreat <= 0.0:
		_retreat = retreat_seconds
		_retreat_cool = retreat_cooldown
	_retreat -= delta
	var to := BossMove.flat_to_target(z)
	var spot := NavigationServer3D.map_get_closest_point(z.get_world_3d().navigation_map, z.global_position - to * 1.5)
	var step := spot - z.global_position
	step.y = 0.0
	if step.length() < 0.4 or step.normalized().dot(to) > 0.0:
		_retreat = 0.0
		_stop_backing(z)
		return false
	if not _backing:
		_backing = true
		z.play_backpedal(z.speed * retreat_speed)
	z.face_toward(to, delta)
	z.move_with(step.normalized() * z.speed * retreat_speed)
	return true


## Hands the legs back to the walk once it stops backing off.
func _stop_backing(z: Zombie) -> void:
	if _backing:
		_backing = false
		z.play_animation(z.data.move_animation, 0.2)


func _show_bottle(on: bool) -> void:
	if is_instance_valid(_bottle):
		_bottle.visible = on
