class_name HarpoonLine
extends MeshInstance3D
## Riptide's shot: the harpoon streaks out on its line to where the shot
## ended, holds there a beat, then the line reels it back to the muzzle (it
## follows the weapon as the player moves). The line sags a little while it
## is slack and goes taut as it reels.

const OUT_TIME := 0.07
const HOLD_TIME := 0.12
const REEL_TIME := 0.24
const SAG := 0.12
const POINTS := 12

var _view: WeaponView
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _color := Color.WHITE
var _width := 0.03
var _age := 0.0
var _im: ImmediateMesh
var _head: MeshInstance3D

static var _head_mesh: CylinderMesh
static var _head_mats := {}


static func spawn(parent: Node, view: WeaponView, from: Vector3, to: Vector3, color: Color, power: float) -> void:
	if parent == null or not parent.is_inside_tree() or from.distance_to(to) < 0.5:
		return
	var line := HarpoonLine.new()
	line._view = view
	line._from = from
	line._to = to
	line._color = color
	line._width = lerpf(0.02, 0.035, clampf(power, 0.0, 1.0))
	parent.add_child(line)


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_im = ImmediateMesh.new()
	mesh = _im
	if _head_mesh == null:
		_head_mesh = CylinderMesh.new()
		_head_mesh.top_radius = 0.0
		_head_mesh.bottom_radius = 0.05
		_head_mesh.height = 0.32
		_head_mesh.radial_segments = 8
		_head_mesh.rings = 1
	_head = MeshInstance3D.new()
	_head.mesh = _head_mesh
	_head.material_override = _head_material(_color)
	_head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_head.top_level = true
	add_child(_head)
	_rebuild()


## Same material kind as Fx tracers (unshaded, vertex colour), so no new shader.
static func _head_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _head_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color.lerp(Color.WHITE, 0.45)
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_head_mats[key] = m
	return _head_mats[key]


func _process(delta: float) -> void:
	_age += delta
	if _age >= OUT_TIME + HOLD_TIME + REEL_TIME:
		queue_free()
		return
	if is_instance_valid(_view):
		_from = _view.muzzle_position()
	_rebuild()


func _rebuild() -> void:
	# Out to the target, a beat there, then reeled back in.
	var out := clampf(_age / OUT_TIME, 0.0, 1.0)
	var reel := clampf((_age - OUT_TIME - HOLD_TIME) / REEL_TIME, 0.0, 1.0)
	var reach := ease(out, 0.6) * (1.0 - ease(reel, 2.2))
	var tip := _from.lerp(_to, reach)
	var slack := (1.0 - reel) * minf(1.0, _age / (OUT_TIME + HOLD_TIME) * 1.5)
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else _from + Vector3.UP
	var pts := PackedVector3Array()
	for i in POINTS + 1:
		var k := float(i) / POINTS
		pts.append(_from.lerp(tip, k) + Vector3.DOWN * SAG * slack * sin(k * PI) * minf(1.0, _from.distance_to(tip) / 8.0))
	WeaponFx.begin_ribbons(_im, WeaponFx.ribbon_material(0.0, 0.0))
	WeaponFx.add_ribbon(_im, pts, _width * 2.2, Color(_color, 0.35), eye)
	WeaponFx.add_ribbon(_im, pts, _width, Color(_color.lerp(Color.WHITE, 0.5), 0.95), eye)
	WeaponFx.end_ribbons(_im)
	var dir := (_to - _from).normalized()
	if dir.length() < 0.5:
		dir = Vector3.FORWARD
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var x := up.cross(dir).normalized()
	_head.global_transform = Transform3D(Basis(x, dir, x.cross(dir).normalized()), tip)
	_head.visible = reach > 0.02
