class_name FxSwarm
extends MultiMeshInstance3D
## Script-simulated particles for cosmetic effects (kill effects, tracer
## sparkles), drawn as one MultiMesh like FxBurst (CPUParticles3D does not
## render reliably on the Compatibility renderer), with more kinds of motion:
## per-particle life and size, tumbling or flipping about one axis, bubbles
## that wobble and pop, blinking pixels, a staggered start and a floor bounce.
##
##   FxSwarm.spawn(parent, origin, mesh, colors, {"count": 30, "speed": Vector2(2, 5), ...})
##
## Config keys (all optional):
##   count, shape ("sphere", "up", "ring", "line"), spread (deg, for "up"),
##   speed (Vector2 min/max), life (Vector2), size (Vector2), gravity (Vector3),
##   drag, spin (rad/s), spin_axis (Vector3, zero = tumble), stretch (Vector3
##   mesh scale, e.g. flat confetti), wobble (m/s sideways), blink (Hz),
##   grow (fraction of life to pop in), pop (true = swell and vanish at the
##   end instead of shrinking), stagger (s), jitter (m), bounce (floor height
##   relative to origin, or omit), line_to (Vector3 end point for "line"),
##   sweep (true = staggered from the start of the line to its end),
##   quantize (m, snaps positions to a pixel grid), align (true = the mesh's
##   -Z follows the velocity, for streaks).

var _pos: PackedVector3Array
var _vel: PackedVector3Array
var _axis: PackedVector3Array
var _angle: PackedFloat32Array
var _spin: PackedFloat32Array
var _life: PackedFloat32Array
var _delay: PackedFloat32Array
var _size: PackedFloat32Array
var _phase: PackedFloat32Array
var _base_rot: Array[Basis] = []
var _age := 0.0
var _max_life := 0.0
var _cfg := {}
var _origin := Vector3.ZERO


static func spawn(parent: Node, origin: Vector3, mesh: Mesh, colors: Array, cfg: Dictionary) -> FxSwarm:
	if parent == null or not parent.is_inside_tree():
		return null
	var s := FxSwarm.new()
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(s)
	s.setup(origin, mesh, colors, cfg)
	return s


func setup(origin: Vector3, mesh: Mesh, colors: Array, cfg: Dictionary) -> void:
	_cfg = cfg
	_origin = origin
	var n := int(cfg.get("count", 20))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	multimesh = mm
	# Packed arrays are values, so each one is resized by name.
	_pos.resize(n)
	_vel.resize(n)
	_axis.resize(n)
	_angle.resize(n)
	_spin.resize(n)
	_life.resize(n)
	_delay.resize(n)
	_size.resize(n)
	_phase.resize(n)
	var speed: Vector2 = cfg.get("speed", Vector2(2.0, 4.0))
	var life: Vector2 = cfg.get("life", Vector2(0.6, 1.0))
	var size: Vector2 = cfg.get("size", Vector2(0.08, 0.12))
	var spin := float(cfg.get("spin", 8.0))
	var axis: Vector3 = cfg.get("spin_axis", Vector3.ZERO)
	var jitter := float(cfg.get("jitter", 0.0))
	var stagger := float(cfg.get("stagger", 0.0))
	for i in n:
		var dir := _direction(i, n)
		var along := randf()
		var start := origin.lerp(cfg.get("line_to", origin), along) if String(cfg.get("shape", "")) == "line" else origin
		_pos[i] = start + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter
		_vel[i] = dir * randf_range(speed.x, speed.y)
		_axis[i] = axis.normalized() if axis != Vector3.ZERO else Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_base_rot.append(Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU)) if axis == Vector3.ZERO else Basis(Vector3.UP, randf() * TAU))
		_angle[i] = randf() * TAU
		_spin[i] = randf_range(-spin, spin)
		_life[i] = randf_range(life.x, life.y)
		_delay[i] = (along if bool(cfg.get("sweep", false)) else randf()) * stagger
		_size[i] = randf_range(size.x, size.y)
		_phase[i] = randf() * TAU
		_max_life = maxf(_max_life, _life[i] + _delay[i])
		mm.set_instance_color(i, colors[randi() % colors.size()])
	_update(0.0)


func _direction(i: int, n: int) -> Vector3:
	match String(_cfg.get("shape", "sphere")):
		"up":
			var cone := deg_to_rad(float(_cfg.get("spread", 35.0)))
			var a := randf() * TAU
			var r := sin(cone * sqrt(randf()))
			return Vector3(cos(a) * r, sqrt(maxf(0.0, 1.0 - r * r)), sin(a) * r)
		"ring":
			var a2 := TAU * (float(i) + randf() * 0.5) / float(n)
			return Vector3(cos(a2), randf_range(-0.12, 0.12), sin(a2)).normalized()
		"line":
			return Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var v := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	return v.normalized() if v.length() > 0.01 else Vector3.UP


func _process(delta: float) -> void:
	_age += delta
	if _age >= _max_life:
		queue_free()
		return
	_update(delta)


func _update(delta: float) -> void:
	var gravity: Vector3 = _cfg.get("gravity", Vector3(0, -6.0, 0))
	var damp := exp(-float(_cfg.get("drag", 1.5)) * delta)
	var wobble := float(_cfg.get("wobble", 0.0))
	var blink := float(_cfg.get("blink", 0.0))
	var grow := float(_cfg.get("grow", 0.12))
	var pop := bool(_cfg.get("pop", false))
	var stretch: Vector3 = _cfg.get("stretch", Vector3.ONE)
	var quantize := float(_cfg.get("quantize", 0.0))
	var align := bool(_cfg.get("align", false))
	var has_floor := _cfg.has("bounce")
	var floor_y := _origin.y + float(_cfg.get("bounce", 0.0))
	for i in _pos.size():
		var t := (_age - _delay[i]) / _life[i]
		if t < 0.0 or t >= 1.0:
			multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), _pos[i]))
			continue
		_vel[i] = _vel[i] * damp + gravity * delta
		var p := _pos[i] + _vel[i] * delta
		if wobble > 0.0:
			p += Vector3(cos(_age * 5.0 + _phase[i]), 0.0, sin(_age * 4.3 + _phase[i])) * wobble * delta
		if has_floor and p.y < floor_y and _vel[i].y < 0.0:
			p.y = floor_y
			_vel[i] = Vector3(_vel[i].x * 0.6, -_vel[i].y * 0.45, _vel[i].z * 0.6)
		_pos[i] = p
		_angle[i] += _spin[i] * delta
		var k := _size[i] * _size_curve(t, grow, pop)
		if blink > 0.0 and sin(_age * blink * TAU + _phase[i]) < -0.3:
			k = 0.0
		var b := Basis(_axis[i], _angle[i]) * _base_rot[i]
		if align and _vel[i].length() > 0.01:
			var v := _vel[i].normalized()
			b = Basis.looking_at(v, Vector3.UP if absf(v.y) < 0.95 else Vector3.RIGHT)
		var draw := p
		if quantize > 0.0:
			draw = (p / quantize).round() * quantize
			b = Basis.IDENTITY
		multimesh.set_instance_transform(i, Transform3D(b.scaled_local(stretch * k), draw))


static func _size_curve(t: float, grow: float, pop: bool) -> float:
	if t < grow:
		return ease(t / grow, 0.4)
	if pop:
		return 1.0 + (0.35 * smoothstep(0.85, 1.0, t)) if t < 0.97 else 0.0
	return 1.0 if t < 0.7 else (1.0 - t) / 0.3
