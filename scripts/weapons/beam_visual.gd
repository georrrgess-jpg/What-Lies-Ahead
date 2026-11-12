class_name BeamVisual
extends MeshInstance3D
## A continuous weapon beam from the muzzle to whatever it touches: a wobbling
## glow, a hot core, a spiral of frost (or energy) around it, and a flaring
## cap where it lands. Owned by the WeaponController and redrawn every frame
## while the trigger is held.

const SPIRAL_PITCH := 0.7

var color := Color(0.6, 0.9, 1.0)
var width := 0.08
var _on := 0.0
var _target_on := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _time := 0.0
var _im: ImmediateMesh
var _cap: MeshInstance3D


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_im = ImmediateMesh.new()
	mesh = _im
	_cap = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_cap.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = WeaponView._star_texture()
	m.no_depth_test = false
	_cap.material_override = m
	_cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cap.top_level = true
	add_child(_cap)


## Call every frame: where the beam runs and whether it is firing.
func aim(from: Vector3, to: Vector3, firing: bool) -> void:
	_from = from
	_to = to
	_target_on = firing


func _process(delta: float) -> void:
	_time += delta
	_on = move_toward(_on, 1.0 if _target_on else 0.0, delta * (14.0 if _target_on else 7.0))
	visible = _on > 0.01
	_cap.visible = visible
	if not visible:
		return
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else _from + Vector3.UP
	var dir := _to - _from
	var length := dir.length()
	if length < 0.05:
		visible = false
		return
	dir /= length
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	WeaponFx.begin_ribbons(_im, WeaponFx.ribbon_material(22.0, 6.0))
	var wobble := PackedVector3Array()
	var steps := clampi(int(length / 0.4), 6, 60)
	for i in steps + 1:
		var d := length * i / steps
		var k := sin(PI * float(i) / steps)
		var off := side * sin(d * 2.3 - _time * 17.0) * 0.035 * k + up * cos(d * 1.7 - _time * 13.0) * 0.03 * k
		wobble.append(_from + dir * d + off)
	var flicker := 0.85 + 0.15 * sin(_time * 53.0)
	WeaponFx.add_ribbon(_im, wobble, width * 4.0 * _on, Color(color, 0.45 * _on * flicker), eye)
	WeaponFx.add_ribbon(_im, wobble, width * 1.3 * _on, Color(color.lerp(Color.WHITE, 0.7), _on), eye)
	var spiral := PackedVector3Array()
	var turns := clampi(int(length / SPIRAL_PITCH * 10.0), 10, 300)
	for i in turns + 1:
		var d := length * i / turns
		var a := d / SPIRAL_PITCH * TAU - _time * 20.0
		var r := 0.06 + 0.05 * sin(d * 0.8 + _time * 4.0)
		spiral.append(_from + dir * d + (side * cos(a) + up * sin(a)) * r * minf(1.0, d * 2.0))
	WeaponFx.add_ribbon(_im, spiral, width * 0.5 * _on, Color(color.lerp(Color.WHITE, 0.35), 0.8 * _on), eye)
	WeaponFx.end_ribbons(_im)
	_cap.global_position = _to - dir * 0.15
	var s := (0.55 + 0.15 * sin(_time * 40.0)) * _on
	_cap.scale = Vector3(s, s, s)
	(_cap.material_override as StandardMaterial3D).albedo_color = Color(color.lerp(Color.WHITE, 0.4), 0.9 * _on)
