class_name BossShockwave
extends BossMove
## Ground-pound: the alpha rears up (a ring glows at its feet), then pounds the
## floor `waves` times; each pound sends a glowing ring rolling outward along
## the ground. A ring hits a player standing on the floor as it passes them:
## jump it (or be further away than it rolls).

@export var waves := 3
## Seconds between pounds.
@export var gap := 0.75
@export var speed := 8.0
@export var max_radius := 16.0
@export var damage := 9.0
## Half the thickness of the rolling ring (how precise the jump must be).
@export var thickness := 0.55
@export var color := Color(1, 0.6, 0.2)
@export var pound_clip: StringName = &"Attack"
@export var pound_sound: StringName = &"boss_pound"

var _left := 0.0
var _pounds := 0
var _next := 0.0
## Radius of every ring still rolling (-1 = gone), and whether it hit.
var _radii := PackedFloat32Array()
var _rings: Array[MeshInstance3D] = []
var _hit: Array[bool] = []
var _centre := Vector3.ZERO


func begin(z: Zombie) -> void:
	super.begin(z)
	_left = windup
	_pounds = 0
	_next = 0.0


func tick(z: Zombie, delta: float) -> bool:
	z.move_with(Vector3.ZERO)
	_roll(z, delta)
	if _left > 0.0:
		_left -= delta
		return true
	_next -= delta
	if _pounds < waves and _next <= 0.0:
		_next = gap
		_pound(z)
		_pounds += 1
	if _pounds >= waves and _rings.is_empty():
		z.play_animation(z.data.move_animation, 0.25)
		return false
	return true


func cancel(_z: Zombie) -> void:
	_left = 0.0
	_pounds = waves
	for r in _rings:
		if is_instance_valid(r):
			r.queue_free()
	_rings.clear()
	_radii.clear()
	_hit.clear()


func is_winding_up() -> bool:
	return _left > 0.0


func wants_jump(_z: Zombie, point: Vector3) -> bool:
	var d := Vector2(point.x - _centre.x, point.z - _centre.z).length()
	for r in _radii:
		if r < d and d - r < 1.6:
			return true
	return false


func _pound(z: Zombie) -> void:
	_centre = z.global_position
	z.play_animation(pound_clip, 0.05)
	Sfx.play_at(pound_sound, _centre + Vector3.UP, 4.0, randf_range(0.9, 1.05), 18.0)
	z.target.add_shake(0.35)
	var ring := AlphaBossBehaviour.make_ring(color, 0.95)
	z.get_parent().add_child(ring)
	ring.global_position = _centre + Vector3.UP * 0.1
	_rings.append(ring)
	_radii.append(0.8)
	_hit.append(false)
	for i in 8:
		var a := TAU * i / 8.0
		Fx.impact(z.get_parent(), _centre + Vector3(cos(a), 0.15, sin(a)) * 1.6, Vector3.UP, color)


func _roll(z: Zombie, delta: float) -> void:
	var player := z.target
	var flat := player.global_position - _centre
	flat.y = 0.0
	var d := flat.length()
	for i in range(_rings.size() - 1, -1, -1):
		var r := _radii[i] + speed * delta
		_radii[i] = r
		var ring := _rings[i]
		if r >= max_radius or not is_instance_valid(ring):
			if is_instance_valid(ring):
				ring.queue_free()
			_rings.remove_at(i)
			_radii.remove_at(i)
			_hit.remove_at(i)
			continue
		ring.scale = Vector3(r, 3.0, r)
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.95 * (1.0 - r / max_radius) + 0.05
		if not _hit[i] and player.alive and absf(d - r) <= thickness and player.is_on_floor() \
				and absf(player.global_position.y - _centre.y) < 1.5:
			_hit[i] = true
			player.take_damage(damage * z.damage_scale, _centre)
