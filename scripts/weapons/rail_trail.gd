class_name RailTrail
extends MeshInstance3D
## The Rail Lancer's shot: a white-hot core line that snaps on and thins out,
## wrapped in a coloured helix that unwinds outward and fades, so the path of
## a piercing shot hangs in the air for a moment.

const LIFE := 0.55
const CORE_LIFE := 0.16
const HELIX_PITCH := 0.55

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _color := Color.WHITE
var _width := 0.1
var _power := 1.0
var _age := 0.0
var _im: ImmediateMesh


## `power` 0-1 scales the trail with the charge.
static func spawn(parent: Node, from: Vector3, to: Vector3, color: Color, width: float, power: float) -> void:
	if parent == null or not parent.is_inside_tree() or from.distance_to(to) < 0.3:
		return
	var t := RailTrail.new()
	t._from = from
	t._to = to
	t._color = color
	t._width = width
	t._power = clampf(power, 0.2, 1.0)
	parent.add_child(t)


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_im = ImmediateMesh.new()
	mesh = _im
	_rebuild()


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	_rebuild()


func _rebuild() -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else _from + Vector3.UP
	var t := _age / LIFE
	WeaponFx.begin_ribbons(_im, WeaponFx.ribbon_material(14.0, 9.0))
	var line := PackedVector3Array([_from, _to])
	if _age < CORE_LIFE:
		var k := 1.0 - _age / CORE_LIFE
		WeaponFx.add_ribbon(_im, line, _width * (0.6 + _power) * 2.6 * k, Color(_color, 0.8 * k), eye)
		WeaponFx.add_ribbon(_im, line, _width * (0.6 + _power) * k, Color(Color.WHITE, k), eye)
	# The helix starts tight and unwinds outward as it fades.
	var dir := (_to - _from).normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	var length := _from.distance_to(_to)
	var radius := (0.05 + 0.22 * ease(t, 0.4)) * (0.5 + _power * 0.5)
	var steps := clampi(int(length / HELIX_PITCH * 8.0), 8, 400)
	var pts := PackedVector3Array()
	for i in steps + 1:
		var d := length * i / steps
		var a := d / HELIX_PITCH * TAU + _age * 6.0
		pts.append(_from + dir * d + (side * cos(a) + up * sin(a)) * radius)
	var fade := (1.0 - t) * (1.0 - t)
	WeaponFx.add_ribbon(_im, pts, _width * 0.55, Color(_color, fade), eye)
	WeaponFx.end_ribbons(_im)
