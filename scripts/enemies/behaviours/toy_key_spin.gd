class_name ToyKeySpinBehaviour
extends EnemyBehaviour
## The brass wind-up key in the back of Toy Shop's clockwork zombies (the
## Wind-up Soldier and the Toymaker). It rides the Spine bone and turns as the
## zombie goes: steadily while it walks, in a fast whirr while any of its
## moves winds up (the HUD threat ring warns at the same time), so the key is
## a second tell you can read from behind. Purely visual.

## The key model (its shaft runs along -Z from its origin).
@export var key_scene: PackedScene
## Where the shaft enters the back, in the model's rest space (metres).
@export var mount := Vector3(0.0, 1.22, -0.27)
@export var key_scale := 1.0
## Turning speed (degrees per second) while walking and while winding up.
@export var walk_rate := 120.0
@export var windup_rate := 1080.0
## How fast the turning speed follows (degrees per second, per second).
@export var spin_up := 2400.0

var _key: Node3D
var _rate := 0.0


func on_ready(z: Zombie) -> void:
	if key_scene == null:
		return
	var skeletons := z.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	var bone := skeleton.find_bone("Spine")
	if bone < 0:
		return
	var holder := BoneAttachment3D.new()
	holder.bone_name = "Spine"
	skeleton.add_child(holder)
	_key = key_scene.instantiate() as Node3D
	holder.add_child(_key)
	_key.transform = skeleton.get_bone_global_rest(bone).affine_inverse() * Transform3D(Basis().scaled(Vector3.ONE * key_scale), mount)


func on_physics(z: Zombie, delta: float) -> bool:
	if _key == null:
		return false
	var target := windup_rate if z.is_winding_up() else walk_rate
	_rate = move_toward(_rate, target, spin_up * delta)
	_key.rotate_object_local(Vector3.BACK, deg_to_rad(_rate) * delta)
	return false
