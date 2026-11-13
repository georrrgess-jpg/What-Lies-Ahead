class_name Tracer
extends MeshInstance3D
## One shot's energy streak: a tapered beam from the muzzle to the hit point
## that flashes and thins out over a few frames, plus a bright bolt that
## travels along it. Visible even at point-blank range. Finished tracers (and
## their bolts) wait hidden in a pool for the next shot (Tracer.take()).

const LIFE := 0.1
const BOLT_SPEED := 140.0
const BOLT_LENGTH := 2.4

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _dir := Vector3.FORWARD
var _distance := 0.0
var _width := 0.03
var _age := 0.0
var _bolt: MeshInstance3D

static var _pool: Array = []
const POOL_MAX := 48


## A tracer under `parent`: an idle one from the pool, or a new one.
static func take(parent: Node) -> Tracer:
	var t: Tracer = null
	while t == null and not _pool.is_empty():
		var candidate = _pool.pop_back()
		# The pool outlives the level: its old tracers were freed with it.
		if is_instance_valid(candidate) and candidate.is_inside_tree():
			t = candidate
	if t == null:
		t = Tracer.new()
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if t.get_parent() != parent:
		if t.get_parent():
			t.get_parent().remove_child(t)
		parent.add_child(t)
	return t


func launch(from: Vector3, to: Vector3, width: float, bolt_mesh: Mesh, bolt_material: Material) -> void:
	_from = from
	_to = to
	_distance = from.distance_to(to)
	_dir = (to - from) / _distance
	_width = width
	_age = 0.0
	set_process(true)
	if not is_instance_valid(_bolt):
		_bolt = MeshInstance3D.new()
		_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_sibling.call_deferred(_bolt)
	elif _bolt.get_parent() != get_parent():
		_bolt.get_parent().remove_child(_bolt)
		add_sibling(_bolt)
	_bolt.mesh = bolt_mesh
	_bolt.material_override = bolt_material
	_update()


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE and (_bolt == null or 1.0 + _age * BOLT_SPEED - BOLT_LENGTH > _distance):
		_finish()
		return
	_update()


func _update() -> void:
	var t := clampf(_age / LIFE, 0.0, 1.0)
	var up := Vector3.UP if absf(_dir.y) < 0.95 else Vector3.RIGHT
	var b := Basis.looking_at(_dir, up)
	# The beam mesh is a cylinder along Y: thin end at the muzzle, full width at the target.
	var w := _width * (1.0 - t) * 0.9
	visible = t < 1.0
	if visible:
		var y := -b.z * _distance
		global_transform = Transform3D(Basis(b.x * w, y, b.y * w), _from + _dir * (_distance * 0.5))
		transparency = t
	if is_instance_valid(_bolt) and _bolt.is_inside_tree():
		# The bolt starts a metre out so it never fills the screen at the muzzle.
		var head := minf(1.0 + _age * BOLT_SPEED + BOLT_LENGTH * 0.5, _distance)
		var tail := clampf(head - BOLT_LENGTH, minf(1.0, _distance), _distance)
		var length := maxf(0.05, head - tail)
		_bolt.visible = _distance > 1.5 and 1.0 + _age * BOLT_SPEED - BOLT_LENGTH < _distance
		var bw := _width * 1.6
		_bolt.global_transform = Transform3D(Basis(b.x * bw, b.y * bw, b.z * length), _from + _dir * (tail + length * 0.5))


func _finish() -> void:
	if _pool.size() >= POOL_MAX:
		if is_instance_valid(_bolt):
			_bolt.queue_free()
		queue_free()
		return
	visible = false
	if is_instance_valid(_bolt):
		_bolt.visible = false
	set_process(false)
	_pool.append(self)
