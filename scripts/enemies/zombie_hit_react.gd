class_name ZombieHitReact
extends SkeletonModifier3D
## Additive hit reactions for a zombie rig, layered over whatever clip is
## playing: a hit twists the torso toward the side that was struck and rocks
## it back, a headshot snaps the head back, then damped springs settle it.
## Locomotion never stops for a light hit (heavy hits play the Stagger clip).

## Spring stiffness (1/s^2) and damping (1/s): settles in about 0.35 s with
## one small overshoot.
const STIFFNESS := 260.0
const DAMPING := 15.0
## Largest kick per hit (radians per second of spring velocity).
const MAX_KICK := 22.0

var _spine := -1
var _head := -1
## Spring state (radians): torso twist, torso pitch, head pitch, head roll.
var _pos := Vector4.ZERO
var _vel := Vector4.ZERO


## Finds the bones on `skeleton` (call after adding this as its child).
func setup(skeleton: Skeleton3D) -> void:
	_spine = skeleton.find_bone("Spine")
	_head = skeleton.find_bone("Head")
	active = _spine >= 0 and _head >= 0


## Kicks the springs for a hit. `local_point` is where the hit landed and
## `local_dir` the shot direction, both in the zombie's own space (+X its
## left, +Y up, +Z its front, origin at its feet); `strength` is 0..1.
func kick(local_point: Vector3, local_dir: Vector3, headshot: bool, strength: float) -> void:
	var s := clampf(strength, 0.35, 1.0) * MAX_KICK
	var d := local_dir.normalized()
	# Torque about the body axis: a frontal hit on the left shoulder turns it back.
	var twist := local_point.z * d.x - local_point.x * d.z
	if absf(twist) < 0.05:
		twist = randf_range(-0.12, 0.12)
	# A chest hit from the front rocks the torso back; a leg hit tips it forward.
	var lean := (local_point.y - 0.9) * d.z if local_point.y > 0.9 else -0.3 * d.z
	_vel.x += clampf(twist * 3.2, -1.0, 1.0) * s * 0.9
	_vel.y += clampf(lean * 1.6, -1.0, 1.0) * s * 0.4
	if headshot:
		_vel.z += clampf(d.z, -1.0, 1.0) * s + signf(d.z) * s * 0.3
		_vel.w += clampf(-d.x, -1.0, 1.0) * s * 0.5 + randf_range(-0.2, 0.2) * s


func _process_modification_with_delta(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	_vel += (-STIFFNESS * _pos - DAMPING * _vel) * dt
	_pos += _vel * dt
	if _pos.length_squared() < 1e-6 and _vel.length_squared() < 1e-5:
		_pos = Vector4.ZERO
		_vel = Vector4.ZERO
		return
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	_rotate(skeleton, _spine, Basis(Vector3.UP, _pos.x) * Basis(Vector3.RIGHT, _pos.y))
	_rotate(skeleton, _head, Basis(Vector3.RIGHT, _pos.z) * Basis(Vector3.BACK, _pos.w))


## Turns `bone` about its own origin by `turn`, given in skeleton space.
func _rotate(skeleton: Skeleton3D, bone: int, turn: Basis) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var global_basis := turn * skeleton.get_bone_global_pose(bone).basis
	skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * global_basis).get_rotation_quaternion())
