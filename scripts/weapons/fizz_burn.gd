class_name FizzBurn
extends Node3D
## The "fizz" status (WeaponData.status_effect = &"fizz", the Sparkler):
## firework sparks that keep burning on a zombie. Every hit adds a stack of
## the weapon's status_amount damage a second (up to MAX_STACKS) and keeps
## the burn going for status_duration after the last hit; then it fizzles out.
##
## The burn ticks quietly: it takes health directly (no flinch, slow or hit
## sound per tick, and it burns past helmets and shields), and only the tick
## that finishes the zombie goes through Zombie.take_hit, so the kill, its
## score and the weapon's mastery are credited like any other. Sparks spit
## off the zombie while it burns, more of them the more stacks it carries.

const NODE_NAME := "FizzBurn"
const MAX_STACKS := 6
## Seconds between damage ticks.
const TICK := 0.4
const COLORS := [Color(1.0, 0.86, 0.3), Color(1.0, 0.45, 0.8), Color(1.0, 1.0, 0.85), Color(0.55, 0.95, 1.0)]

var zombie: Zombie
var stacks := 0
var _per_stack := 0.0
var _left := 0.0
var _tick := TICK
var _spit := 0.0
var _weapon_id: StringName


## The burn on `z`, created on first use.
static func of(z: Zombie) -> FizzBurn:
	var existing := z.get_node_or_null(NODE_NAME) as FizzBurn
	if existing:
		return existing
	var f := FizzBurn.new()
	f.name = NODE_NAME
	f.zombie = z
	z.add_child(f)
	return f


## One hit's worth of sparks: `amount` is the weapon's status_amount times
## the hits it landed (each hit is a stack).
func add(weapon: WeaponData, amount: float) -> void:
	if zombie.is_dead() or weapon.status_amount <= 0.0:
		return
	_weapon_id = weapon.id
	_per_stack = weapon.status_amount
	stacks = mini(MAX_STACKS, stacks + maxi(1, roundi(amount / weapon.status_amount)))
	_left = weapon.status_duration
	if not is_physics_processing():
		_tick = TICK
		set_physics_process(true)


func _ready() -> void:
	# Burns on even while a frozen zombie's own processing is off.
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _physics_process(delta: float) -> void:
	if zombie == null or zombie.is_dead() or stacks <= 0:
		_stop()
		return
	_left -= delta
	_tick -= delta
	_spit -= delta
	if _spit <= 0.0:
		_spit = lerpf(0.3, 0.09, float(stacks) / MAX_STACKS)
		_sparks()
	if _tick <= 0.0:
		_tick += TICK
		_burn(stacks * _per_stack * TICK)
	if _left <= 0.0:
		_stop()


func _burn(dmg: float) -> void:
	if dmg <= 0.0 or zombie.is_dead():
		return
	if dmg < zombie.health:
		zombie.health -= dmg
		return
	var chest := zombie.global_position + Vector3.UP * zombie.data.body_scale
	zombie.take_hit(dmg, chest, Vector3.UP, _weapon_id, false, 0.0)


func _sparks() -> void:
	var s := zombie.data.body_scale
	var at := zombie.global_position + Vector3(randf_range(-0.25, 0.25) * s, randf_range(0.5, 1.6) * s, randf_range(-0.25, 0.25) * s)
	WeaponFx.burst(zombie.get_parent(), at, Vector3.UP, COLORS, 2 + (stacks >> 1), 2.4, 0.3, 0.035, 80.0, Vector3(0, -6.0, 0))


func _stop() -> void:
	stacks = 0
	_left = 0.0
	set_physics_process(false)
