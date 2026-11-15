class_name CityFireBottle
extends Node3D
## A lit bottle in flight (the Firebug's throw): a green glass bottle with a
## burning rag tumbles along a lobbed arc to the spot its BossZone marks on the
## floor, landing exactly when the zone strikes. It shatters there and sets
## the zone burning (CityFirePatch). It never hurts on its own: the zone does.

const SPIN := 14.0

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _time := 1.0
var _apex := 2.0
var _age := 0.0
var _zone: BossZone
var _linger := 3.0
var _body: Node3D

static var _glass_mesh: CylinderMesh
static var _flame_mesh: SphereMesh


## Throws a bottle from `from` to `zone`'s centre, arriving after `time`; the
## zone burns for `linger` seconds after it lands.
static func throw(parent: Node, from: Vector3, zone: BossZone, time: float, apex: float, linger: float) -> CityFireBottle:
	var b := CityFireBottle.new()
	b._from = from
	b._to = zone.global_position
	b._time = maxf(0.2, time)
	b._apex = apex
	b._zone = zone
	b._linger = linger
	parent.add_child(b)
	b.global_position = from
	return b


func _ready() -> void:
	if _glass_mesh == null:
		_glass_mesh = CylinderMesh.new()
		_glass_mesh.top_radius = 0.035
		_glass_mesh.bottom_radius = 0.07
		_glass_mesh.height = 0.3
		_glass_mesh.radial_segments = 10
		_glass_mesh.rings = 1
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.3, 0.75, 0.38)
		glass.roughness = 0.15
		glass.emission_enabled = true
		glass.emission = Color(0.2, 0.6, 0.3)
		glass.emission_energy_multiplier = 0.4
		_glass_mesh.material = glass
		_flame_mesh = SphereMesh.new()
		_flame_mesh.radius = 0.09
		_flame_mesh.height = 0.26
		_flame_mesh.radial_segments = 8
		_flame_mesh.rings = 4
		var flame := StandardMaterial3D.new()
		flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame.albedo_color = Color(1.0, 0.72, 0.25)
		_flame_mesh.material = flame
	_body = Node3D.new()
	add_child(_body)
	var glass_mi := MeshInstance3D.new()
	glass_mi.mesh = _glass_mesh
	glass_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(glass_mi)
	var flame_mi := MeshInstance3D.new()
	flame_mi.mesh = _flame_mesh
	flame_mi.position.y = 0.22
	flame_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(flame_mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 1.6
	light.omni_range = 3.5
	add_child(light)


func _physics_process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / _time, 0.0, 1.0)
	global_position = _from.lerp(_to, t) + Vector3.UP * _apex * 4.0 * t * (1.0 - t)
	_body.rotation.x += SPIN * delta
	if randf() < 0.4:
		Fx.impact(get_parent(), global_position + Vector3.UP * 0.15, Vector3.UP, Color(1.0, 0.55, 0.15))
	if t >= 1.0:
		_shatter()


func _shatter() -> void:
	var parent := get_parent()
	Fx.impact(parent, _to + Vector3.UP * 0.2, Vector3.UP, Color(0.5, 0.95, 0.55))
	for i in 6:
		var a := TAU * i / 6.0
		Fx.impact(parent, _to + Vector3(cos(a), 0.25, sin(a)) * 0.8, Vector3(cos(a), 1.0, sin(a)), Color(1.0, 0.5, 0.12))
	if is_instance_valid(_zone):
		var patch := CityFirePatch.new()
		patch.radius = _zone.radius
		patch.seconds = _linger
		_zone.add_child(patch)
	queue_free()
