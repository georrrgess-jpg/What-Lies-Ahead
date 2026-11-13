class_name StyledTracer
extends MeshInstance3D
## One styled tracer (TracerStyles), of one of two kinds:
## * a mesh built in world space along the shot that shoots out from the
##   muzzle over `reveal` seconds, then fades (lightning flickers while it
##   fades): launch();
## * a pattern tracer: a shared unit mesh stretched along the shot and drawn
##   by art/shaders/tracer_pattern.gdshader, which reveals and fades it through
##   instance uniforms, so no mesh is built for the shot: launch_pattern().
## Finished tracers wait hidden in a pool for the next shot (take()).

const POOL_MAX := 48

static var _pool: Array = []

var _from := Vector3.ZERO
var _dir := Vector3.FORWARD
var _life := 0.15
var _reveal := 0.0
var _flicker := false
var _pattern := false
var _age := 0.0


## A tracer under `parent`: an idle one from the pool, or a new one.
static func take(parent: Node) -> StyledTracer:
	var t: StyledTracer = null
	while t == null and not _pool.is_empty():
		var candidate = _pool.pop_back()
		# The pool outlives the level: its old tracers were freed with it.
		if is_instance_valid(candidate) and candidate.is_inside_tree():
			t = candidate
	if t == null:
		t = StyledTracer.new()
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if t.get_parent() != parent:
		if t.get_parent():
			t.get_parent().remove_child(t)
		parent.add_child(t)
	return t


func launch(from: Vector3, to: Vector3, life: float, reveal: float, flicker: bool) -> void:
	_start(from, to, life, reveal, flicker, false)
	_update()


## Stretches the shared unit mesh (z 0..1 along the shot, x/y across) from
## `from` to `to`, `width` metres across.
func launch_pattern(from: Vector3, to: Vector3, width: float, life: float, reveal: float) -> void:
	_start(from, to, life, reveal, false, true)
	var up := Vector3.UP if absf(_dir.y) < 0.95 else Vector3.RIGHT
	var x := _dir.cross(up).normalized()
	var length := from.distance_to(to)
	global_transform = Transform3D(Basis(x * width, x.cross(_dir).normalized() * width, _dir * length), from)
	# The heartbeat's spikes reach well outside the unit mesh's box.
	extra_cull_margin = 1.0
	set_instance_shader_parameter("length_m", length)
	set_instance_shader_parameter("seed", randf())
	_update()


func _start(from: Vector3, to: Vector3, life: float, reveal: float, flicker: bool, pattern: bool) -> void:
	_from = from
	_dir = (to - from).normalized()
	_life = life
	_reveal = reveal
	_flicker = flicker
	_pattern = pattern
	_age = 0.0
	transparency = 0.0
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		_finish()
		return
	_update()


func _update() -> void:
	var fade := clampf((_age - _reveal) / maxf(0.01, _life - _reveal), 0.0, 1.0)
	if _pattern:
		set_instance_shader_parameter("shown", clampf(_age / _reveal, 0.02, 1.0) if _reveal > 0.0 else 1.0)
		set_instance_shader_parameter("fade", fade * fade)
		set_instance_shader_parameter("age", _age)
		return
	# Stretch along the shot about the muzzle: k = 0 collapsed, 1 full length.
	var k := clampf(_age / _reveal, 0.02, 1.0) if _reveal > 0.0 else 1.0
	var d := _dir
	var b := Basis(Vector3.RIGHT + d * (k - 1.0) * d.x, Vector3.UP + d * (k - 1.0) * d.y, Vector3.BACK + d * (k - 1.0) * d.z)
	global_transform = Transform3D(b, _from - b * _from)
	transparency = fade * fade
	if _flicker:
		visible = randf() > 0.2
		transparency = clampf(fade + randf() * 0.3, 0.0, 1.0)


func _finish() -> void:
	if _pool.size() >= POOL_MAX:
		queue_free()
		return
	visible = false
	set_process(false)
	# A per-shot mesh is not kept alive by the pool.
	if not _pattern:
		mesh = null
	_pool.append(self)
