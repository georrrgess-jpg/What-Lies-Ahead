class_name BossSummon
extends BossMove
## The alpha calls its own minions in: it roars (or blows a whistle, or pours a
## hopper) and after the wind-up `count` of `enemy` pop out around it (the run
## director spawns them through AlphaBossBehaviour.summon_requested, so they
## count toward the wave like any escort). Up to `max_alive` of them at a time.

@export var enemy: StringName = &""
@export var count := 3
## No new call while this many of its summons still stand.
@export var max_alive := 4
@export var color := Color(1, 0.5, 0.8)

var _wind := 0.0
var _spawned: Array[Zombie] = []


func can_start(z: Zombie, distance: float) -> bool:
	for i in range(_spawned.size() - 1, -1, -1):
		if not is_instance_valid(_spawned[i]) or _spawned[i].is_dead():
			_spawned.remove_at(i)
	return _spawned.size() < max_alive and super.can_start(z, distance)


func begin(z: Zombie) -> void:
	super.begin(z)
	_wind = windup


func tick(z: Zombie, delta: float) -> bool:
	z.move_with(Vector3.ZERO)
	_wind -= delta
	if _wind > 0.0:
		return true
	Fx.confetti(z.get_parent(), z.global_position + Vector3.UP * 1.5)
	for i in 6:
		var a := TAU * i / 6.0
		Fx.impact(z.get_parent(), z.global_position + Vector3(cos(a), 0.3, sin(a)) * 1.5, Vector3.UP, color)
	var wanted := mini(count, max_alive - _spawned.size())
	if wanted > 0:
		boss.summon_requested.emit(enemy, wanted, z, _spawned)
	z.play_animation(z.data.move_animation, 0.25)
	return false


func cancel(_z: Zombie) -> void:
	_wind = 0.0


func is_winding_up() -> bool:
	return _wind > 0.0
