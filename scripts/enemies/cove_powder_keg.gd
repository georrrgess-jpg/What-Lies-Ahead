class_name CovePowderKeg
extends Node3D
## A powder keg in flight (the Powder Monkey's throw): a banded keg with a
## sparking fuse tumbles along a lobbed arc to the spot its BossZone marks,
## lands, rolls a little and fizzes, swelling and flashing faster as the fuse
## burns down, and is gone when the zone strikes (the zone's burst is the
## blast). It never hurts on its own: the zone does.

const SPIN := 9.0

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _time := 1.0
var _apex := 2.0
var _fuse := 1.0
var _age := 0.0
var _body: Node3D
var _spark: MeshInstance3D
var _zone: BossZone

static var _keg_mesh: CylinderMesh
static var _band_mesh: CylinderMesh
static var _spark_mesh: SphereMesh


## Throws a keg from `from` to `zone`'s centre, landing after `time`; it fizzes
## there for `fuse` seconds (the zone strikes at time + fuse).
static func throw(parent: Node, from: Vector3, zone: BossZone, time: float, apex: float, fuse: float) -> CovePowderKeg:
	var k := CovePowderKeg.new()
	k._from = from
	k._to = zone.global_position
	k._time = maxf(0.2, time)
	k._apex = apex
	k._fuse = fuse
	k._zone = zone
	parent.add_child(k)
	k.global_position = from
	return k


func _ready() -> void:
	if _keg_mesh == null:
		_make_meshes()
	_body = Node3D.new()
	add_child(_body)
	var keg := MeshInstance3D.new()
	keg.mesh = _keg_mesh
	keg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(keg)
	for y in [-0.12, 0.12]:
		var band := MeshInstance3D.new()
		band.mesh = _band_mesh
		band.position.y = y
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(band)
	_spark = MeshInstance3D.new()
	_spark.mesh = _spark_mesh
	_spark.position.y = 0.3
	_spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(_spark)


func _physics_process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / _time, 0.0, 1.0)
	if t < 1.0:
		global_position = _from.lerp(_to, t) + Vector3.UP * _apex * 4.0 * t * (1.0 - t)
		_body.rotation.x += SPIN * delta
	else:
		# Landed: settle upright, fizz and swell as the fuse burns down.
		var burn := clampf((_age - _time) / _fuse, 0.0, 1.0)
		global_position = _to + Vector3.UP * 0.22
		_body.rotation.x = lerp_angle(_body.rotation.x, 0.0, minf(1.0, delta * 12.0))
		var pulse := 1.0 + 0.08 * burn * sin(_age * (20.0 + burn * 40.0))
		_body.scale = Vector3.ONE * (1.0 + burn * 0.15) * pulse
		if randf() < 0.25:
			Fx.impact(get_parent(), global_position + Vector3.UP * 0.35, Vector3.UP, Color(1.0, 0.75, 0.3))
	_spark.scale = Vector3.ONE * (0.8 + randf() * 0.6)
	if _age >= _time + _fuse or not is_instance_valid(_zone):
		Fx.impact(get_parent(), _to + Vector3.UP * 0.5, Vector3.UP, Color(0.6, 0.55, 0.6))
		queue_free()


static func _make_meshes() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.71, 0.45, 0.25)
	wood.roughness = 0.75
	_keg_mesh = CylinderMesh.new()
	_keg_mesh.top_radius = 0.2
	_keg_mesh.bottom_radius = 0.2
	_keg_mesh.height = 0.42
	_keg_mesh.radial_segments = 12
	_keg_mesh.rings = 1
	_keg_mesh.material = wood
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.23, 0.24, 0.3)
	iron.roughness = 0.45
	iron.metallic = 0.5
	_band_mesh = CylinderMesh.new()
	_band_mesh.top_radius = 0.215
	_band_mesh.bottom_radius = 0.215
	_band_mesh.height = 0.05
	_band_mesh.radial_segments = 12
	_band_mesh.rings = 1
	_band_mesh.material = iron
	var spark := StandardMaterial3D.new()
	spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark.albedo_color = Color(1.0, 0.82, 0.35)
	_spark_mesh = SphereMesh.new()
	_spark_mesh.radius = 0.07
	_spark_mesh.height = 0.14
	_spark_mesh.radial_segments = 8
	_spark_mesh.rings = 4
	_spark_mesh.material = spark
