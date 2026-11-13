class_name DuneLeapBehaviour
extends EnemyBehaviour
## Shared core of the Dune Spaceport leapers: wind up in place (the threat ring
## warns), fly a ballistic arc to a spot on the navmesh near the player, land
## with a small shockwave. The arc is checked against scenery before take-off,
## so a leaper never passes through walls. Subclasses pick the trigger, the
## landing spot and the effects.

@export var min_range := 4.0
@export var max_range := 12.0
@export var cooldown := 5.0
## Seconds crouched before take-off (telegraph).
@export var windup := 0.6
@export var flight_time := 1.0
## Height of the arc above the straight line between take-off and landing.
@export var apex := 2.5
## Lands this far short of the player, toward where the leap started.
@export var land_offset := 1.0
@export var landing_damage := 12.0
@export var landing_radius := 1.5
@export var windup_clip: StringName = &"Crouch"
@export var flight_clip: StringName = &"Hover"
@export var windup_sound: StringName = &""
@export var launch_sound: StringName = &""
@export var land_sound: StringName = &""
@export var dust_color := Color(0.95, 0.78, 0.55)

var _cool := 0.0
var _wind := 0.0
var _flight := -1.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _anim: AnimationPlayer


func on_ready(z: Zombie) -> void:
	_cool = randf_range(1.5, cooldown)
	_anim = z.find_child("AnimationPlayer", true, false) as AnimationPlayer


func on_physics(z: Zombie, delta: float) -> bool:
	_cool -= delta
	if _wind > 0.0:
		_wind -= delta
		var to := z.target.global_position - z.global_position
		z.face_toward(Vector3(to.x, 0, to.z), delta)
		z.move_with(Vector3.ZERO)
		_on_windup_tick(z, delta)
		if _wind <= 0.0:
			_launch(z)
		return true
	if _flight >= 0.0:
		_fly(z, delta)
		return true
	if _cool <= 0.0 and z.state == Zombie.State.CHASE and z.target.alive and _wants_leap(z):
		_cool = cooldown
		if _plan(z):
			_wind = windup
			z.play_animation(windup_clip, 0.12)
			if windup_sound != &"":
				Sfx.play_at(windup_sound, z.global_position + Vector3.UP, 0.0, randf_range(0.95, 1.05))
			return true
		_cool = 1.2
	return false


func is_winding_up() -> bool:
	return _wind > 0.0 or _flight >= 0.0


## Only the crouch can be broken; a leap already in the air lands.
func interrupt(z: Zombie) -> void:
	if _wind > 0.0:
		_wind = 0.0
		z.play_animation(z.data.move_animation, 0.15)


func is_airborne() -> bool:
	return _flight >= 0.0


## Override: should this zombie leap now? Default: in range with a clear view.
func _wants_leap(z: Zombie) -> bool:
	var d := z.distance_to_target()
	return d >= min_range and d <= max_range and z.has_line_of_sight()


## Override: the point to aim the landing at (snapped to the navmesh after).
func _landing_goal(z: Zombie) -> Vector3:
	var p := z.target.global_position
	var back := z.global_position - p
	back.y = 0.0
	return p + back.normalized() * land_offset


func _on_windup_tick(_z: Zombie, _delta: float) -> void:
	pass


func _on_flight_tick(_z: Zombie, _delta: float, _t: float) -> void:
	pass


func _on_landed(_z: Zombie) -> void:
	pass


## Picks a landing spot on the navmesh and checks the arc is clear.
func _plan(z: Zombie) -> bool:
	var map := z.get_world_3d().navigation_map
	var goal := _landing_goal(z)
	var on_mesh := NavigationServer3D.map_get_closest_point(map, goal)
	if Vector2(on_mesh.x - goal.x, on_mesh.z - goal.z).length() > 2.0:
		return false
	var floor_hit: Variant = _floor_below(z, on_mesh)
	if floor_hit == null:
		return false
	_from = z.global_position
	_to = floor_hit
	if _from.distance_to(_to) < 1.5:
		return false
	var prev := _arc_point(0.0) + Vector3.UP
	var space := z.get_world_3d().direct_space_state
	for i in range(1, 9):
		var p := _arc_point(i / 8.0) + Vector3.UP
		var q := PhysicsRayQueryParameters3D.create(prev, p, 1)
		q.exclude = [z.get_rid()]
		if not space.intersect_ray(q).is_empty():
			return false
		prev = p
	return true


func _floor_below(z: Zombie, at: Vector3) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.2, at + Vector3.DOWN * 3.0, 1)
	q.exclude = [z.get_rid()]
	var hit := z.get_world_3d().direct_space_state.intersect_ray(q)
	return null if hit.is_empty() else hit["position"]


func _arc_point(t: float) -> Vector3:
	return _from.lerp(_to, t) + Vector3.UP * apex * 4.0 * t * (1.0 - t)


func _launch(z: Zombie) -> void:
	_flight = 0.0
	z.play_animation(flight_clip, 0.08)
	if launch_sound != &"":
		Sfx.play_at(launch_sound, z.global_position + Vector3.UP, 1.0, randf_range(0.95, 1.05))
	Fx.impact(z.get_parent(), z.global_position + Vector3.UP * 0.1, Vector3.UP, dust_color)


func _fly(z: Zombie, delta: float) -> void:
	_flight += delta / flight_time
	var t := minf(_flight, 1.0)
	var before := z.global_position
	z.global_position = _arc_point(t)
	z.velocity = Vector3.ZERO
	var step := z.global_position - before
	if Vector2(step.x, step.z).length() > 0.001:
		z.face_toward(Vector3(step.x, 0, step.z), delta * 2.0)
	_on_flight_tick(z, delta, t)
	if _flight >= 1.0:
		_land(z)


func _land(z: Zombie) -> void:
	_flight = -1.0
	z.global_position = _to + Vector3.UP * 0.05
	z.reset_stall(false)
	z.play_animation(z.data.move_animation, 0.15)
	Fx.impact(z.get_parent(), _to + Vector3.UP * 0.1, Vector3.UP, dust_color)
	Fx.impact(z.get_parent(), _to + Vector3(0.6, 0.1, 0.3), Vector3.UP, dust_color)
	Fx.impact(z.get_parent(), _to + Vector3(-0.5, 0.1, -0.4), Vector3.UP, dust_color)
	if land_sound != &"":
		Sfx.play_at(land_sound, _to + Vector3.UP * 0.5, 0.0, randf_range(0.92, 1.08))
	var player := z.target
	if player and player.alive and landing_damage > 0.0:
		var flat := Vector2(player.global_position.x - _to.x, player.global_position.z - _to.z).length()
		if flat <= landing_radius and absf(player.global_position.y - _to.y) < 1.6:
			player.take_damage(landing_damage, _to)
	_on_landed(z)
