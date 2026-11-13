class_name FxSwarm
extends MultiMeshInstance3D
## Script-simulated particles for cosmetic effects (kill effects, tracer
## sparkles), drawn as one MultiMesh like FxBurst (CPUParticles3D does not
## render reliably on the Compatibility renderer), with more kinds of motion:
## per-particle life and size, tumbling or flipping about one axis, bubbles
## that wobble and pop, blinking pixels, a staggered start and a floor bounce.
## Finished swarms wait hidden in a pool for the next effect, keeping their
## MultiMesh buffer.
##
##   FxSwarm.spawn(parent, origin, mesh, colors, {"count": 30, "speed": Vector2(2, 5), ...})
##
## Config keys (all optional):
##   count, shape ("sphere", "up", "ring", "line"), spread (deg, for "up"),
##   speed (Vector2 min/max; negative moves inwards / down), life (Vector2),
##   size (Vector2), gravity (Vector3), drag, spin (rad/s), spin_axis
##   (Vector3, zero = tumble), steady (true = every particle spins at exactly
##   `spin`), stretch (Vector3 mesh scale, e.g. flat confetti), wobble (m/s
##   sideways), blink (Hz), grow (fraction of life to pop in), pop (true =
##   swell and vanish at the end instead of shrinking), stagger (s), delay
##   (s, a fixed wait before every particle, for later phases of one effect),
##   jitter (m), bounce (floor height relative to origin, or omit), line_to
##   (Vector3 end point for "line"), even (true = evenly spaced along the
##   line), sweep (true = staggered from the start of the line to its end),
##   box (Vector3: start anywhere in a box round the origin), sweep_y (true =
##   staggered from the bottom of the box to its top), radius (m: start on a
##   shell round the origin), orbit (rad/s about the vertical through the
##   origin: swirls), quantize (m, snaps positions to a pixel grid), align
##   (true = the mesh's -Z follows the velocity, for streaks), face (Vector3:
##   the mesh's +Z points this way, e.g. at the camera), sway (rad, rocks to
##   and fro about the spin axis at sway_hz), reel (s: the spin slows to a
##   stop, landing square, like a slot reel), expand (size multiplier reached
##   at the end of life, for shock rings), fade (true = the colour's alpha
##   follows the life, for additive flashes).

const POOL_MAX := 48

## Idle swarms kept for reuse (hidden, not processing).
static var _pool: Array = []

var _pos: PackedVector3Array
var _vel: PackedVector3Array
var _axis: PackedVector3Array
var _angle: PackedFloat32Array
var _spin: PackedFloat32Array
var _life: PackedFloat32Array
var _delay: PackedFloat32Array
var _size: PackedFloat32Array
var _phase: PackedFloat32Array
var _color: PackedColorArray
var _base_rot: Array[Basis] = []
var _age := 0.0
var _max_life := 0.0
var _cfg := {}
var _origin := Vector3.ZERO


## A swarm under `parent`, taken from the pool when one is free, already set up.
static func spawn(parent: Node, origin: Vector3, mesh: Mesh, colors: Array, cfg: Dictionary) -> FxSwarm:
	if parent == null or not parent.is_inside_tree():
		return null
	var s: FxSwarm = null
	while s == null and not _pool.is_empty():
		var candidate = _pool.pop_back()
		# The pool outlives the level: its old swarms were freed with it.
		if is_instance_valid(candidate) and candidate.is_inside_tree():
			s = candidate
	if s == null:
		s = FxSwarm.new()
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if s.get_parent() != parent:
		if s.get_parent():
			s.get_parent().remove_child(s)
		parent.add_child(s)
	s.setup(origin, mesh, colors, cfg)
	return s


func setup(origin: Vector3, mesh: Mesh, colors: Array, cfg: Dictionary) -> void:
	_cfg = cfg
	_origin = origin
	_age = 0.0
	_max_life = 0.0
	visible = true
	set_process(true)
	var n := int(cfg.get("count", 20))
	var mm := multimesh
	if mm == null:
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		multimesh = mm
	mm.mesh = mesh
	# A pooled swarm keeps its buffer when it is big enough (but not wasteful).
	if mm.instance_count < n or mm.instance_count > n * 3:
		mm.instance_count = n
	mm.visible_instance_count = n
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
	_color.resize(n)
	_base_rot.resize(n)
	var speed: Vector2 = cfg.get("speed", Vector2(2.0, 4.0))
	var life: Vector2 = cfg.get("life", Vector2(0.6, 1.0))
	var size: Vector2 = cfg.get("size", Vector2(0.08, 0.12))
	var spin := float(cfg.get("spin", 8.0))
	var steady := bool(cfg.get("steady", false))
	var axis: Vector3 = cfg.get("spin_axis", Vector3.ZERO)
	var jitter := float(cfg.get("jitter", 0.0))
	var stagger := float(cfg.get("stagger", 0.0))
	var delay := float(cfg.get("delay", 0.0))
	var radius := float(cfg.get("radius", 0.0))
	var box: Vector3 = cfg.get("box", Vector3.ZERO)
	var face: Vector3 = cfg.get("face", Vector3.ZERO)
	var is_line := String(cfg.get("shape", "")) == "line"
	var even := bool(cfg.get("even", false))
	for i in n:
		var dir := _direction(i, n)
		var along := (float(i) + 0.5) / n if even else randf()
		var start := origin.lerp(cfg.get("line_to", origin), along) if is_line else origin + dir * radius
		var cell := Vector3(randf(), randf(), randf())
		if box != Vector3.ZERO:
			start += (cell - Vector3.ONE * 0.5) * box
			along = cell.y if bool(cfg.get("sweep_y", false)) else along
		_pos[i] = start + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * jitter
		_vel[i] = dir * randf_range(speed.x, speed.y)
		_axis[i] = axis.normalized() if axis != Vector3.ZERO else Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		_base_rot[i] = _start_basis(axis, face)
		_angle[i] = 0.0 if face != Vector3.ZERO else randf() * TAU
		_spin[i] = spin if steady else randf_range(-spin, spin)
		_life[i] = randf_range(life.x, life.y)
		_delay[i] = delay + (along if bool(cfg.get("sweep", false)) or cfg.has("sweep_y") else randf()) * stagger
		_size[i] = randf_range(size.x, size.y)
		_phase[i] = randf() * TAU
		_max_life = maxf(_max_life, _life[i] + _delay[i])
		_color[i] = colors[randi() % colors.size()]
		mm.set_instance_color(i, _color[i])
	_update(0.0)


static func _start_basis(axis: Vector3, face: Vector3) -> Basis:
	if face != Vector3.ZERO:
		var f := face.normalized()
		return Basis.looking_at(-f, Vector3.UP if absf(f.y) < 0.95 else Vector3.BACK)
	if axis == Vector3.ZERO:
		return Basis.from_euler(Vector3(randf() * TAU, randf() * TAU, randf() * TAU))
	return Basis(Vector3.UP, randf() * TAU)


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
		_finish()
		return
	_update(delta)


func _finish() -> void:
	if _pool.size() >= POOL_MAX:
		queue_free()
		return
	visible = false
	set_process(false)
	_pool.append(self)


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
	var orbit := float(_cfg.get("orbit", 0.0)) * delta
	var sway := float(_cfg.get("sway", 0.0))
	var sway_hz := float(_cfg.get("sway_hz", 2.0))
	var reel := float(_cfg.get("reel", 0.0))
	var expand := float(_cfg.get("expand", 1.0))
	var fade := bool(_cfg.get("fade", false))
	for i in _pos.size():
		var local := _age - _delay[i]
		var t := local / _life[i]
		if t < 0.0 or t >= 1.0:
			multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), _pos[i]))
			continue
		_vel[i] = _vel[i] * damp + gravity * delta
		var p := _pos[i] + _vel[i] * delta
		if orbit != 0.0:
			p = _origin + (p - _origin).rotated(Vector3.UP, orbit)
			_vel[i] = _vel[i].rotated(Vector3.UP, orbit)
		if wobble > 0.0:
			p += Vector3(cos(_age * 5.0 + _phase[i]), 0.0, sin(_age * 4.3 + _phase[i])) * wobble * delta
		if has_floor and p.y < floor_y and _vel[i].y < 0.0:
			p.y = floor_y
			_vel[i] = Vector3(_vel[i].x * 0.6, -_vel[i].y * 0.45, _vel[i].z * 0.6)
		_pos[i] = p
		_angle[i] += _spin[i] * delta
		var angle := _angle[i]
		if reel > 0.0:
			angle = _spin[i] * pow(maxf(0.0, reel - local), 2.0) / (2.0 * reel)
		if sway > 0.0:
			angle += sin(local * sway_hz * TAU) * sway
		var k := _size[i] * _size_curve(t, grow, pop) * lerpf(1.0, expand, ease(t, 0.4))
		if blink > 0.0 and sin(_age * blink * TAU + _phase[i]) < -0.3:
			k = 0.0
		var b := Basis(_axis[i], angle) * _base_rot[i]
		if align and _vel[i].length() > 0.01:
			var v := _vel[i].normalized()
			b = Basis.looking_at(v, Vector3.UP if absf(v.y) < 0.95 else Vector3.RIGHT)
		var draw := p
		if quantize > 0.0:
			draw = (p / quantize).round() * quantize
			b = Basis.IDENTITY
		multimesh.set_instance_transform(i, Transform3D(b.scaled_local(stretch * k), draw))
		if fade:
			multimesh.set_instance_color(i, Color(_color[i], _color[i].a * (1.0 - t) * (1.0 - t)))


static func _size_curve(t: float, grow: float, pop: bool) -> float:
	if t < grow:
		return ease(t / grow, 0.4)
	if pop:
		return 1.0 + (0.35 * smoothstep(0.85, 1.0, t)) if t < 0.97 else 0.0
	return 1.0 if t < 0.7 else (1.0 - t) / 0.3
