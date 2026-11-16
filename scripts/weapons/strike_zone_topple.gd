class_name StrikeZoneTopple
extends Node3D
## A zombie bowled over by the Strike Zone's ball, like a pin (added as a
## child the first time, StrikeZoneTopple.knock_down). It is knocked out of
## any windup, tips over about its feet away from the ball (FALL_TIME, a
## falling ease with a little bounce), skids along the floor with the
## scatter it was given, lies there for LIE_TIME and gets back up
## (RISE_TIME). Down, it cannot move or attack: a Hold behaviour
## (EnemyBehaviour.on_physics) takes over its movement. Once up it cannot be
## bowled over again for IMMUNE_TIME (it still takes the hit), so rolls
## cannot pin a crowd down for good. Only light zombies are bowled over
## (StrikeZoneBall checks the mass and rank).

const NODE_NAME := "StrikeTopple"
const FALL_TIME := 0.28
const LIE_TIME := 0.75
const RISE_TIME := 0.45
const IMMUNE_TIME := 1.2
## How far it tips (degrees): nearly flat on its back.
const FALL_DEG := 84.0
const DEAD_RIGHT := 0.15
## Skid speed (m/s) lost per second along the floor.
const SKID_DRAG := 9.0

var zombie: Zombie
var _t := -1.0
var _immune := 0.0
var _axis := Vector3.RIGHT
var _skid := Vector3.ZERO
var _hold: Hold
var _rest := Quaternion.IDENTITY


## Movement while down: only the skid, no chasing, no attacks.
class Hold extends EnemyBehaviour:
	var topple: StrikeZoneTopple

	func on_physics(z: Zombie, _delta: float) -> bool:
		if not is_instance_valid(topple):
			return false
		z.move_with(topple.skid())
		return true


## Bowls `z` over, sliding it along `scatter` (m/s, before its mass).
## Returns false when it is already down or still getting its feet back.
static func knock_down(z: Zombie, scatter: Vector3) -> bool:
	var t := z.get_node_or_null(NODE_NAME) as StrikeZoneTopple
	if t == null:
		t = StrikeZoneTopple.new()
		t.name = NODE_NAME
		t.zombie = z
		z.add_child(t)
	return t._knock(scatter)


## True while the zombie is down (falling, lying or getting up).
func is_down() -> bool:
	return _t >= 0.0


## This frame's skid velocity.
func skid() -> Vector3:
	return _skid


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_physics_process(false)


func _knock(scatter: Vector3) -> bool:
	if zombie.is_dead() or is_down() or _immune > 0.0:
		return false
	if zombie.is_winding_up():
		zombie.interrupt()
	var flat := Vector3(scatter.x, 0.0, scatter.z)
	var away := flat.normalized() if flat.length() > 0.01 else -zombie.global_basis.z
	_axis = Vector3.UP.cross(away).normalized()
	_skid = flat / sqrt(maxf(0.5, zombie.data.mass))
	_rest = zombie.model_root.quaternion
	_t = 0.0
	_hold = Hold.new()
	_hold.topple = self
	zombie.behaviours.append(_hold)
	zombie.play_animation(&"Stagger", 0.08)
	set_physics_process(true)
	return true


func _physics_process(delta: float) -> void:
	if not is_down():
		_immune -= delta
		if _immune <= 0.0:
			set_physics_process(false)
		return
	if zombie.is_dead():
		_stand(true)
		return
	_t += delta
	_skid = _skid.move_toward(Vector3.ZERO, SKID_DRAG * delta)
	_tilt(_tip(_t))
	if _t >= FALL_TIME + LIE_TIME + RISE_TIME:
		_stand(false)


## How far over it is (0 standing, 1 flat) at `t` seconds down.
func _tip(t: float) -> float:
	if t < FALL_TIME:
		var k := t / FALL_TIME
		return k * k
	var lie := t - FALL_TIME
	if lie < LIE_TIME:
		# A small bounce as it hits the floor.
		return 1.0 - 0.07 * sin(clampf(lie / 0.22, 0.0, 1.0) * PI)
	var up := clampf((lie - LIE_TIME) / RISE_TIME, 0.0, 1.0)
	return 1.0 - up * up * (3.0 - 2.0 * up)


func _tilt(k: float) -> void:
	var local_axis := (zombie.global_basis.inverse() * _axis).normalized()
	zombie.model_root.quaternion = Quaternion(local_axis, deg_to_rad(FALL_DEG) * k) * _rest


## Back on its feet (or dead: it rolls upright for its death clip over
## DEAD_RIGHT seconds), hands the legs back and lets it go.
func _stand(dead: bool) -> void:
	_t = -1.0
	if dead:
		create_tween().tween_property(zombie.model_root, "quaternion", _rest, DEAD_RIGHT).set_trans(Tween.TRANS_SINE)
	else:
		zombie.model_root.quaternion = _rest
	zombie.behaviours.erase(_hold)
	_hold = null
	_skid = Vector3.ZERO
	if not dead:
		zombie.play_animation(zombie.data.move_animation, 0.2)
	_immune = IMMUNE_TIME
