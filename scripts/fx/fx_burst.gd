class_name FxBurst
extends MultiMeshInstance3D
## Lightweight particle burst (sparks, hit pops, confetti) simulated in script
## and drawn as one MultiMesh. Used instead of CPUParticles3D, which does not
## render reliably on the Compatibility renderer.

var _pos: PackedVector3Array
var _vel: PackedVector3Array
var _spin: PackedVector3Array
var _rot: PackedVector3Array
var _gravity := Vector3(0, -9.0, 0)
var _drag := 1.5
var _life := 0.5
var _age := 0.0
var _size := 0.1


func setup(origin: Vector3, direction: Vector3, colors: Array, amount: int, speed: float, lifetime: float,
		size: float, spread_degrees: float, gravity: Vector3, mesh_: Mesh) -> void:
	_life = lifetime
	_size = size
	_gravity = gravity
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh_
	mm.instance_count = amount
	multimesh = mm
	var dir := direction.normalized() if direction.length() > 0.01 else Vector3.UP
	var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	_pos.resize(amount)
	_vel.resize(amount)
	_spin.resize(amount)
	_rot.resize(amount)
	var cone := deg_to_rad(spread_degrees)
	for i in amount:
		var a := randf() * TAU
		var r := sin(cone * sqrt(randf()))
		var local := Vector3(cos(a) * r, sin(a) * r, -sqrt(maxf(0.0, 1.0 - r * r)))
		_pos[i] = origin
		_vel[i] = basis * local * speed * randf_range(0.45, 1.0)
		_spin[i] = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
		_rot[i] = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		mm.set_instance_color(i, colors[randi() % colors.size()])
	_update(0.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_update(delta)


func _update(delta: float) -> void:
	var t := _age / _life
	var s := _size * (1.0 if t < 0.7 else (1.0 - t) / 0.3)
	var damp := exp(-_drag * delta)
	for i in _pos.size():
		_vel[i] = _vel[i] * damp + _gravity * delta
		_pos[i] += _vel[i] * delta
		_rot[i] += _spin[i] * delta
		var b := Basis.from_euler(_rot[i]).scaled(Vector3(s, s, s * 0.35))
		multimesh.set_instance_transform(i, Transform3D(b, _pos[i]))
