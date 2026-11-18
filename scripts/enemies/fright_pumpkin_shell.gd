class_name FrightPumpkinShell
extends Node3D
## A lit pumpkin bomb in flight (the Pumpkin Head's throw): a small carved
## pumpkin with a sparking fuse tumbles along a lobbed arc to the spot its
## BossZone marks on the floor, landing exactly when the zone strikes, and
## bursts in orange pulp and green sparks. It never hurts on its own: the
## zone does.

const SPIN := 9.0

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _time := 1.0
var _apex := 2.0
var _age := 0.0
var _body: Node3D

static var _shell_mesh: SphereMesh
static var _face_mesh: SphereMesh
static var _spark_mesh: SphereMesh


## Throws a pumpkin from `from` to `to`, arriving after `time` seconds.
static func throw(parent: Node, from: Vector3, to: Vector3, time: float, apex: float) -> FrightPumpkinShell:
	var s := FrightPumpkinShell.new()
	s._from = from
	s._to = to
	s._time = maxf(0.2, time)
	s._apex = apex
	parent.add_child(s)
	s.global_position = from
	return s


func _ready() -> void:
	if _shell_mesh == null:
		_shell_mesh = SphereMesh.new()
		_shell_mesh.radius = 0.2
		_shell_mesh.height = 0.32
		_shell_mesh.radial_segments = 12
		_shell_mesh.rings = 6
		var rind := StandardMaterial3D.new()
		rind.albedo_color = Color(0.95, 0.48, 0.1)
		rind.roughness = 0.55
		rind.emission_enabled = true
		rind.emission = Color(1.0, 0.45, 0.1)
		rind.emission_energy_multiplier = 0.25
		_shell_mesh.material = rind
		_face_mesh = SphereMesh.new()
		_face_mesh.radius = 0.12
		_face_mesh.height = 0.14
		_face_mesh.radial_segments = 8
		_face_mesh.rings = 4
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(1.0, 0.85, 0.35)
		_face_mesh.material = glow
		_spark_mesh = SphereMesh.new()
		_spark_mesh.radius = 0.05
		_spark_mesh.height = 0.1
		_spark_mesh.radial_segments = 6
		_spark_mesh.rings = 3
		var spark := StandardMaterial3D.new()
		spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark.albedo_color = Color(0.6, 1.0, 0.45)
		_spark_mesh.material = spark
	_body = Node3D.new()
	add_child(_body)
	for entry in [[_shell_mesh, Vector3.ZERO], [_face_mesh, Vector3(0, 0, 0.13)], [_spark_mesh, Vector3(0, 0.22, 0)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = entry[0]
		mi.position = entry[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 1.4
	light.omni_range = 3.2
	add_child(light)


func _physics_process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / _time, 0.0, 1.0)
	global_position = _from.lerp(_to, t) + Vector3.UP * _apex * 4.0 * t * (1.0 - t)
	_body.rotation.x += SPIN * delta
	if randf() < 0.35:
		Fx.impact(get_parent(), global_position + Vector3.UP * 0.2, Vector3.UP, Color(0.6, 1.0, 0.45))
	if t >= 1.0:
		_burst()


func _burst() -> void:
	var parent := get_parent()
	Fx.impact(parent, _to + Vector3.UP * 0.25, Vector3.UP, Color(1.0, 0.6, 0.15))
	for i in 7:
		var a := TAU * i / 7.0
		Fx.impact(parent, _to + Vector3(cos(a), 0.25, sin(a)) * 0.9, Vector3(cos(a), 1.0, sin(a)), Color(1.0, 0.5, 0.1) if i % 2 else Color(0.55, 1.0, 0.4))
	queue_free()
