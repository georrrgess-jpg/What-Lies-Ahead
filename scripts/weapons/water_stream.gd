class_name WaterStream
extends MeshInstance3D
## The Dunk Tank's jet: one wobbling ribbon of water from the muzzle to where
## the last shot ended, drawn while the trigger is held and for LINGER after,
## sagging a little with distance, with a splash where it lands. One per
## weapon mode (DunkTankMode), reused shot after shot.

const LINGER := 0.14
const POINTS := 14
## Drop at the middle of the jet per metre of length.
const SAG := 0.035
const SPLASH_EVERY := 0.06
const CORE := Color(0.86, 0.97, 1.0)
const BODY := Color(0.3, 0.72, 1.0)
const SPLASH := [Color(0.6, 0.88, 1.0), Color(0.95, 1.0, 1.0), Color(0.3, 0.62, 1.0)]

var view: WeaponView
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _left := 0.0
var _splash := 0.0
var _hit_zombie := false
var _im: ImmediateMesh


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_im = ImmediateMesh.new()
	mesh = _im
	global_transform = Transform3D.IDENTITY


## One shot of the jet ended at `to` (`on_zombie`: it splashed on a zombie).
func spray(from: Vector3, to: Vector3, on_zombie: bool) -> void:
	_from = from
	_to = to
	_left = LINGER
	_hit_zombie = on_zombie
	visible = true
	_rebuild()


func _process(delta: float) -> void:
	if _left <= 0.0:
		if visible:
			visible = false
		return
	_left -= delta
	if is_instance_valid(view):
		_from = view.muzzle_position()
	_splash -= delta
	if _splash <= 0.0:
		_splash = SPLASH_EVERY
		var back := (_from - _to).normalized()
		WeaponFx.burst(get_parent(), _to + back * 0.15, back + Vector3.UP * 0.6, SPLASH, 4 if _hit_zombie else 3, 2.6, 0.35, 0.045, 70.0, Vector3(0, -9.0, 0))
	_rebuild()


func _rebuild() -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else _from + Vector3.UP
	var length := _from.distance_to(_to)
	var t := Time.get_ticks_msec() * 0.001
	var fade := sqrt(clampf(_left / LINGER, 0.0, 1.0))
	var pts := PackedVector3Array()
	var side := (_to - _from).cross(Vector3.UP).normalized()
	for i in POINTS + 1:
		var k := float(i) / POINTS
		var wobble := sin(k * 9.0 - t * 40.0) * 0.025 * k
		pts.append(_from.lerp(_to, k) + Vector3.DOWN * SAG * length * sin(k * PI) + side * wobble)
	WeaponFx.begin_ribbons(_im, WeaponFx.ribbon_material(6.0, 3.0))
	WeaponFx.add_ribbon(_im, pts, 0.16, Color(BODY, 0.7 * fade), eye)
	WeaponFx.add_ribbon(_im, pts, 0.06, Color(CORE, fade), eye)
	WeaponFx.end_ribbons(_im)
