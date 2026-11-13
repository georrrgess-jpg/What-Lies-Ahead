class_name WeaponCharm
extends Node3D
## A charm hanging from a weapon's charm lug (WeaponCosmetics puts it on the
## CharmPoint). It is a little pendulum simulated in world space: it trails
## behind when the player turns, bobs with footsteps, kicks with recoil and
## settles under gravity. Works at any model scale (the viewmodel is scaled
## down).
##
## The swing is limited in the weapon's own space so the charm can never pass
## through the weapon or the hands: it stays outside the weapon's side (the
## lug stands STANDOFF proud of it, see art/blender/weapon_kit.py), swings
## fore and aft only so far, never lifts above level, and is pushed off the
## hands and forearms (also while they move during a reload).

## Effective pendulum length in world metres (sets how lazy the swing feels).
const SWING_LENGTH := 0.32
const DAMPING := 3.2
## Anchor accelerations above this are treated as teleports and ignored.
const MAX_ACCEL := 400.0
## How far the lug's eye stands out from the weapon's side (model units).
const STANDOFF := 0.018
## Clearance kept between the charm and what it rests against (model units).
const SKIN := 0.002
## Swing limits as components of the hang direction in the weapon's space:
## along the barrel (about 25 degrees either way) and upwards (never above
## about 12 degrees over level).
const MAX_FORE_AFT := 0.42
const MAX_LIFT := 0.2
## Radius of the keep-out capsule round each hand and forearm (model units).
const ARM_RADIUS := 0.082
## How much of its speed the charm keeps when it bumps into a limit.
const BOUNCE := 0.25

var _mesh: MeshInstance3D
var _dir := Vector3.DOWN      # world-space direction from the ring to the charm
var _rate := Vector3.ZERO     # d(_dir)/dt
var _prev_pos := Vector3.ZERO
var _prev_vel := Vector3.ZERO
var _frames := 0
var _model: Node3D            # the weapon model: the limits live in its space
var _out := Vector3.LEFT      # outward normal of the weapon's side the lug is on
var _reach := 0.045           # from the ring to the middle of the trinket
var _radius := 0.02           # half thickness of the trinket
var _least_out := 0.0         # least outward lean that keeps the trinket off the weapon's side
var _arms: Array[Node3D] = [] # hand, elbow, hand, elbow


## mesh: a charm from art/models/cosmetic_charms.glb (origin at its ring).
## model: the weapon model it hangs on; `anchor` is the model's CharmPoint
## (null when the model has none and the charm is placed by hand).
func setup(mesh: Mesh, model: Node3D = null, anchor: Node3D = null) -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in mesh.get_surface_count():
		var base := mesh.surface_get_material(i) as BaseMaterial3D
		var special := Operators.special_material(base) if base else null
		if special:
			_mesh.set_surface_override_material(i, special)
	add_child(_mesh)
	var box := mesh.get_aabb()
	# The trinket hangs below a short chain: its middle and half thickness.
	_reach = clampf(-(box.position.y - 0.02) * 0.5, 0.03, 0.07)
	_radius = clampf(maxf(box.size.x, box.size.z) * 0.5, 0.012, 0.03)
	# The widest part may start right below the chain: that is where it would touch first.
	_least_out = clampf((_radius + SKIN - STANDOFF) / minf(_reach, 0.02 + _radius), 0.0, 0.9)
	_model = model
	if model == null:
		return
	var shell := model.find_child("Shell", true, false) as MeshInstance3D
	if shell and anchor:
		var centre := (WeaponCosmetics.to_model(model, shell) * shell.mesh.get_aabb().get_center()).x
		_out = Vector3.LEFT if WeaponCosmetics.to_model(model, anchor).origin.x < centre else Vector3.RIGHT
	for side in ["L", "R"]:
		var hand := model.find_child("Arm" + side, true, false) as Node3D
		var elbow := model.find_child("Elbow" + side, true, false) as Node3D
		if hand and elbow:
			_arms.append(hand)
			_arms.append(elbow)


func _ready() -> void:
	# Hang correctly on the very first frame (thumbnails render only one).
	_constrain()
	_orient()


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
	_constrain()
	_orient()


## Keeps the hang direction inside the limits (in the weapon's space) and
## takes the speed out of whatever it bumped into.
func _constrain() -> void:
	if _model == null or not is_inside_tree():
		return
	var xf := _model.global_transform
	var basis := xf.basis.orthonormalized()
	var d := (basis.inverse() * _dir).normalized()
	var free := d
	d.y = minf(d.y, MAX_LIFT)
	d.z = clampf(d.z, -MAX_FORE_AFT, MAX_FORE_AFT)
	d = d.normalized()
	if not _arms.is_empty():
		d = _clear_of_arms(d, xf.affine_inverse())
	d = _clear_of_side(d)
	if d.is_equal_approx(free):
		return
	var held := (basis * d).normalized()
	var push := held - _dir
	_dir = held
	if push.length_squared() > 1e-10:
		push = push.normalized()
		var into := _rate.dot(push)
		if into < 0.0:
			_rate -= push * into * (1.0 + BOUNCE)
	_rate -= _dir * _rate.dot(_dir)


## The trinket rests against the weapon's side at most: it never leans in
## towards the weapon, and a thick one leans out far enough to clear the side.
func _clear_of_side(d: Vector3) -> Vector3:
	var out := d.dot(_out)
	if out >= _least_out:
		return d
	var along := d - _out * out
	if along.length_squared() < 1e-8:
		along = Vector3.DOWN
	return _out * _least_out + along.normalized() * sqrt(1.0 - _least_out * _least_out)


## Pushes the trinket out of the capsules round the hands and forearms.
func _clear_of_arms(d: Vector3, to_model: Transform3D) -> Vector3:
	var ring := to_model * global_position
	var keep := ARM_RADIUS + _radius
	for i in range(0, _arms.size(), 2):
		var hand := _arms[i]
		if not hand.is_visible_in_tree():
			continue
		var a := to_model * hand.global_position
		var b := a + (to_model * _arms[i + 1].global_position - a) * 2.0
		var bob := ring + d * _reach
		var ab := b - a
		var t := clampf((bob - a).dot(ab) / maxf(1e-6, ab.length_squared()), 0.0, 1.0)
		var nearest := a + ab * t
		var gap := bob - nearest
		var dist := gap.length()
		if dist < keep and dist > 1e-5:
			d = (nearest + gap * (keep / dist) - ring).normalized()
	return d


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
