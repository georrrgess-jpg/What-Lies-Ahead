extends RefCounted
## Ring Toss viewmodel motion (WeaponData.view_script): the loaded hoop lies
## in the cradle and the stack below it shows the rest of the magazine
## (Stack0..3). A shot snaps the flipper paddle forward, the hoop zips off the
## cradle, and a fresh one rises out of the stack. When a thrown ring comes
## home (RingShot -> WeaponView.weapon_event) the catch hooks clamp, the gun
## dips and twists with the catch and sparks fly; a ringer catch (a headshot
## ring) throws gold.

const STACK := 4
## Seconds: the hoop leaves the cradle, then the next one rises into it.
const LAUNCH := 0.07
const RISE_START := 0.2
const RISE_END := 0.32
## How far the hoop flies off the cradle before it vanishes (model space), and
## how far below the cradle the next one waits on the stack.
const LAUNCH_OFFSET := Vector3(0.0, 0.03, -0.26)
const STACK_DROP := Vector3(0.0, -0.036, 0.0)
const FLIP_TIME := 0.14
const CATCH_TIME := 0.32
const PINK := [Color(1.0, 0.45, 0.85), Color(1.0, 1.0, 1.0), Color(1.0, 0.7, 0.95)]
const GOLD := [Color(1.0, 0.85, 0.3), Color(1.0, 1.0, 0.8), Color(1.0, 0.55, 0.85)]

var _ring: Node3D
var _flipper: Node3D
var _hooks: Node3D
var _muzzle: Node3D
var _stack: Array[Node3D] = []
var _since_shot := 10.0
var _since_catch := 10.0
var _ringer := false


func setup(v: WeaponView) -> void:
	for part in ["Ring", "Flipper", "Hooks"]:
		v.register_part(part)
	for i in STACK:
		v.register_part("Stack%d" % i)
		_stack.append(v.part("Stack%d" % i))
	_ring = v.part("Ring")
	_flipper = v.part("Flipper")
	_hooks = v.part("Hooks")
	_muzzle = v.model.find_child("Muzzle", true, false) as Node3D


func fired(_v: WeaponView) -> void:
	_since_shot = 0.0


func event(v: WeaponView, event_name: StringName) -> void:
	_since_catch = 0.0
	_ringer = event_name == &"catch_ringer"
	if _muzzle:
		var at := v.model.global_transform.affine_inverse() * _muzzle.global_position
		v.spark_burst(at, Vector3(0, 1, 0.4), GOLD if _ringer else PINK, 14 if _ringer else 8, 1.0, 0.35, 0.01)


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	_since_catch += delta
	if v.is_reloading():
		return
	var mag := _magazine(v)
	_pose_ring(v, mag)
	for i in _stack.size():
		if _stack[i]:
			_stack[i].visible = i < mag - 1
	if _flipper:
		var flip := sin(clampf(_since_shot / FLIP_TIME, 0.0, 1.0) * PI) * -55.0
		_flipper.transform = v.rest_transform("Flipper") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(flip)), Vector3.ZERO)
	_pose_catch(v)


## The loaded hoop: flying off, hidden, rising from the stack, or at rest.
func _pose_ring(v: WeaponView, mag: int) -> void:
	if _ring == null:
		return
	var rest := v.rest_transform("Ring")
	var t := _since_shot
	if t < LAUNCH:
		var k := t / LAUNCH
		_ring.visible = true
		_ring.transform = Transform3D(rest.basis.scaled(Vector3.ONE * lerpf(1.0, 0.7, k)), rest.origin + LAUNCH_OFFSET * k * k)
	elif t < RISE_START or mag <= 0:
		_ring.visible = false
	elif t < RISE_END:
		var k := smoothstep(RISE_START, RISE_END, t)
		_ring.visible = true
		_ring.transform = Transform3D(rest.basis, rest.origin + STACK_DROP * (1.0 - k))
	else:
		_ring.visible = true
		_ring.transform = rest


## The catch: hooks clamp and the whole gun dips and twists (more for a ringer).
func _pose_catch(v: WeaponView) -> void:
	var k := sin(clampf(_since_catch / CATCH_TIME, 0.0, 1.0) * PI)
	if _hooks:
		_hooks.transform = v.rest_transform("Hooks") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(k * 35.0)), Vector3.ZERO)
	if v.model and _since_catch < CATCH_TIME + 0.05:
		var twist := 1.6 if _ringer else 1.0
		var rot := Vector3(-4.0, 3.0, 7.0) * k * twist
		v.model.transform = v.rest_transform("Root") * Transform3D(Basis.from_euler(rot * (PI / 180.0)), Vector3(0.0, -0.01, 0.012) * k * twist)


func _magazine(v: WeaponView) -> int:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return v.data.magazine_size
	return p.weapons.magazine()
