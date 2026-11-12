class_name WeaponCharm
extends Node3D
## A charm hanging from a weapon (WeaponCosmetics puts it on the CharmPoint).
## It is a little pendulum simulated in world space: it trails behind when the
## player turns, bobs with footsteps, kicks with recoil and settles under
## gravity. Works at any model scale (the viewmodel is scaled down).

## Effective pendulum length in world metres (sets how lazy the swing feels).
const SWING_LENGTH := 0.32
const DAMPING := 2.6
## Anchor accelerations above this are treated as teleports and ignored.
const MAX_ACCEL := 400.0

var _mesh: MeshInstance3D
var _dir := Vector3.DOWN      # world-space direction from the ring to the charm
var _rate := Vector3.ZERO     # d(_dir)/dt
var _prev_pos := Vector3.ZERO
var _prev_vel := Vector3.ZERO
var _frames := 0


## mesh: a charm from art/models/cosmetic_charms.glb (origin at its ring).
func setup(mesh: Mesh) -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in mesh.get_surface_count():
		var base := mesh.surface_get_material(i) as BaseMaterial3D
		var special := Operators.special_material(base) if base else null
		if special:
			_mesh.set_surface_override_material(i, special)
	add_child(_mesh)


func _process(delta: float) -> void:
	if delta <= 0.0 or not is_inside_tree():
		return
	delta = minf(delta, 1.0 / 30.0)
	var pos := global_position
	var vel := (pos - _prev_pos) / delta
	var accel := (vel - _prev_vel) / delta
	_prev_pos = pos
	_prev_vel = vel
	_frames += 1
	if _frames < 3 or accel.length() > MAX_ACCEL:
		accel = Vector3.ZERO
	# The charm feels gravity minus the anchor's acceleration.
	var force := Vector3(0, -9.8, 0) - accel
	var tangent := force - _dir * force.dot(_dir)
	_rate += tangent / SWING_LENGTH * delta
	_rate -= _dir * _rate.dot(_dir)
	_rate *= exp(-DAMPING * delta)
	_dir = (_dir + _rate * delta).normalized()
	_orient()


func _orient() -> void:
	var parent := get_parent() as Node3D
	if parent == null:
		return
	# Hang along _dir (in the parent's space), keeping the charm's front facing
	# back towards the player as much as possible.
	var up := -(parent.global_transform.basis.inverse() * _dir).normalized()
	var front := Vector3.BACK - up * Vector3.BACK.dot(up)
	if front.length() < 0.05:
		front = Vector3.RIGHT
	var right := up.cross(front.normalized()).normalized()
	transform.basis = Basis(right, up, right.cross(up).normalized())
