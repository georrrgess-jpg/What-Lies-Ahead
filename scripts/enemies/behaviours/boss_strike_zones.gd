class_name BossStrikeZones
extends BossMove
## A pattern of telegraphed ground strikes (BossZone): lava geysers, tentacles
## from below, prize booths thrown from on high, stone pillars, ice walls,
## gummy drops. The alpha plants its feet for the wind-up, then the strikes are
## placed one after another (`stagger` apart) in a pattern:
##
##   CHASE         each strike lands where the player stands when it is placed:
##                 standing still is punished, moving keeps you clear
##   AROUND        one on the player and the rest on a ring around them
##   LINE          a row from the alpha out past the player, near to far
##   SCATTER       random spots near the player
##   RING_BOSS     a ring around the alpha itself (pillars, a moat of fire)

enum Pattern { CHASE, AROUND, LINE, SCATTER, RING_BOSS }

@export var pattern := Pattern.CHASE
@export var count := 4
## Seconds between strikes being placed.
@export var stagger := 0.45
## Distance of the ring / scatter from its centre.
@export var spread := 4.0
## Seconds the alpha keeps its feet planted after the last strike is placed.
@export var hold := 0.4
## The clip it plays while placing the strikes.
@export var cast_clip: StringName = &"Attack"

@export_group("Strike")
@export var radius := 2.0
@export var telegraph := 1.2
@export var damage := 12.0
@export var color := Color(1, 0.5, 0.2)
@export var style := BossZone.Style.BURST
@export var prop := BossZone.Prop.COLUMN
@export var prop_color := Color(1, 0.6, 0.3)
@export var prop_height := 3.0
@export var hits_airborne := false
@export var linger := 0.0
@export var linger_dps := 0.0
@export_range(0.1, 1.0) var linger_slow := 1.0
@export var pillar_seconds := 0.0
@export var warn_sound: StringName = &"boss_zone_warn"
@export var hit_sound: StringName = &"boss_zone_hit"

var _left := 0.0
var _placed := 0
var _next := 0.0
var _dir := Vector3.FORWARD


func begin(z: Zombie) -> void:
	super.begin(z)
	_left = windup
	_placed = 0
	_next = 0.0


func tick(z: Zombie, delta: float) -> bool:
	z.move_with(Vector3.ZERO)
	if _left > 0.0:
		_left -= delta
		z.face_toward(flat_to_target(z), delta * 2.0)
		if _left <= 0.0:
			_dir = flat_to_target(z)
			z.play_animation(cast_clip, 0.1)
		return true
	_next -= delta
	if _placed < count and _next <= 0.0:
		_next = stagger
		_place(z, _placed)
		_placed += 1
	if _placed >= count:
		_left -= delta
		if _left <= -hold:
			z.play_animation(z.data.move_animation, 0.25)
			return false
	return true


func cancel(_z: Zombie) -> void:
	_left = 0.0
	_placed = count


func is_winding_up() -> bool:
	return _left > 0.0


func _place(z: Zombie, i: int) -> void:
	var at := _point(z, i)
	var zone := BossZone.new()
	zone.radius = radius
	zone.telegraph = telegraph
	zone.damage = damage * z.damage_scale
	zone.color = color
	zone.style = style
	zone.prop = prop
	zone.prop_color = prop_color
	zone.prop_height = prop_height
	zone.hits_airborne = hits_airborne
	zone.linger = linger
	zone.linger_dps = linger_dps * z.damage_scale
	zone.linger_slow = linger_slow
	zone.pillar_seconds = pillar_seconds
	zone.warn_sound = warn_sound
	zone.hit_sound = hit_sound
	zone.source = z
	z.get_parent().add_child(zone)
	zone.global_position = floor_point(z, at)


func _point(z: Zombie, i: int) -> Vector3:
	var player := z.target.global_position
	match pattern:
		Pattern.CHASE:
			return player
		Pattern.AROUND:
			if i == 0:
				return player
			var a := TAU * (i - 1) / maxf(1.0, count - 1) + randf() * 0.4
			return player + Vector3(cos(a), 0.0, sin(a)) * spread
		Pattern.LINE:
			var step := radius * 1.7
			return z.global_position + _dir * (2.5 + step * i)
		Pattern.SCATTER:
			var a := randf() * TAU
			return player + Vector3(cos(a), 0.0, sin(a)) * randf_range(0.0, spread)
	var b := TAU * i / maxf(1.0, count) + atan2(_dir.z, _dir.x)
	return z.global_position + Vector3(cos(b), 0.0, sin(b)) * spread
