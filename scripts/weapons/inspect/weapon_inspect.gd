class_name WeaponInspect
extends RefCounted
## The inspect of the held weapon (the `inspect` action), run by WeaponView.
## The weapon comes up toward the camera, turns to show its flank, tips to
## show its top and goes back to the hip, on one smooth curve: a spline
## through the poses (POSES, or the view's own), eased out of and back into
## the hip pose. The weapon turns about the middle of its bounds and is kept
## far enough from the eye that no corner of it, at any angle, reaches the
## camera's near plane.
##
## Fire, aim, reload, a switch, sprint, slide, a dash, a mantle or a hit taken
## cancel it at once: the weapon blends back to the hip over CANCEL_TIME
## instead of snapping, and the view's special (WeaponView._inspect_special)
## stops. It cannot start while the weapon is busy (reloading, switching,
## charging, just fired) or the player is.

## Seconds of a whole inspect (a view may ask for its own length).
const LENGTH := 2.5
## Seconds to ease out of the hip pose into the curve, and back at the end.
const EASE_IN := 0.45
const EASE_OUT := 0.55
## Seconds a cancelled inspect takes to blend back to the hip.
const CANCEL_TIME := 0.2
## A shot this recent (seconds) keeps an inspect from starting.
const AFTER_SHOT := 0.35
## Closest the weapon's bounding sphere may come to the eye (view units; the
## camera's near plane is 0.1).
const NEAR := 0.16
## The generic poses: [time 0-1 of the length, where the middle of the
## weapon is (view units, camera space), its turn (degrees: pitch, yaw, roll)].
## Yaw turns the muzzle left to show the right flank; pitch lifts the muzzle
## so the top faces the eye.
const POSES := [
	[0.0, Vector3(0.14, -0.14, -0.62), Vector3(2.0, 24.0, -6.0)],
	[0.2, Vector3(0.07, -0.09, -0.54), Vector3(6.0, 66.0, -12.0)],
	[0.4, Vector3(0.06, -0.08, -0.52), Vector3(2.0, 78.0, -6.0)],
	[0.62, Vector3(0.06, -0.1, -0.53), Vector3(44.0, 26.0, -4.0)],
	[0.8, Vector3(0.09, -0.12, -0.57), Vector3(38.0, 10.0, 6.0)],
	[1.0, Vector3(0.14, -0.15, -0.62), Vector3(6.0, 4.0, 0.0)],
]

## Seconds since this inspect began (-1: none running).
var clock := -1.0
## The length and poses of the running inspect.
var length := LENGTH
var poses: Array = POSES
## 1 while running, falling to 0 over CANCEL_TIME once cancelled.
var _fade := 0.0
var _cancelled := false
var _since_shot := 10.0
## The weapon's bounds in the model's space (arms and holograms left out).
var _centre := Vector3.ZERO
var _radius := 0.3


func running() -> bool:
	return clock >= 0.0


## True while it plays (not while it blends back after a cancel).
func playing() -> bool:
	return clock >= 0.0 and not _cancelled


## Starts it for `v`'s model with `poses_in` over `length_in` seconds.
func begin(v: WeaponView, length_in: float, poses_in: Array) -> void:
	_measure(v)
	clock = 0.0
	length = maxf(1.0, length_in)
	poses = poses_in
	_fade = 1.0
	_cancelled = false


## Blends back to the hip from wherever it is.
func cancel() -> void:
	if playing():
		_cancelled = true


func note_shot() -> void:
	_since_shot = 0.0
	cancel()


## True when an inspect may start now.
func can_start(v: WeaponView) -> bool:
	return not running() and _since_shot >= AFTER_SHOT and not busy(v)


## True while the player or the weapon is doing something an inspect gives way to.
static func busy(v: WeaponView) -> bool:
	if v.data == null or v.model == null or not v.model.visible or v.is_reloading() or v.is_lowering():
		return true
	var p := v.player
	if p == null:
		return false
	if not p.alive or not p.controls_enabled or p.aim_blend > 0.04 or p.sprint_amount > 0.12 \
			or p.sliding or p.is_traversing() or p.is_dashing():
		return true
	if Input.is_action_pressed(&"fire") or Input.is_action_pressed(&"aim") or Input.is_action_pressed(WeaponController.MELEE_ACTION):
		return true
	var w := p.weapons
	return w == null or w.current != v.data or w.is_reloading() or w.is_switching() or w.is_charging() or w.is_beaming()


## Moves the clock on. Returns false when it has finished (or blended back).
func advance(v: WeaponView, delta: float) -> bool:
	_since_shot += delta
	if not running():
		return false
	clock += delta
	if not _cancelled and busy(v):
		_cancelled = true
	if _cancelled:
		_fade = maxf(0.0, _fade - delta / CANCEL_TIME)
	if clock >= length or _fade <= 0.0:
		clock = -1.0
		return false
	return true


## How much of the inspect pose shows (0 at the hip, 1 on the curve).
func weight() -> float:
	if not running():
		return 0.0
	var k := smoothstep(0.0, EASE_IN, clock) * (1.0 - smoothstep(length - EASE_OUT, length, clock))
	return k * smoothstep(0.0, 1.0, _fade)


## The holder's transform (camera space) on the curve now.
func pose() -> Transform3D:
	var t := clampf(clock / length, 0.0, 1.0)
	var centre := _spline(t, 1)
	var turn := _spline(t, 2)
	var b := Basis.from_euler(turn * (PI / 180.0))
	centre.z = minf(centre.z, -(_radius + NEAR))
	return Transform3D(b, centre - b * _centre)


## A point on the spline through the poses' field `field` (1 position, 2
## turn) at `t`: Catmull-Rom tangents, still at both ends.
func _spline(t: float, field: int) -> Vector3:
	var n := poses.size()
	if n == 1 or t <= float(poses[0][0]):
		return poses[0][field]
	for i in n - 1:
		var t0: float = poses[i][0]
		var t1: float = poses[i + 1][0]
		if t > t1 and i < n - 2:
			continue
		var p0: Vector3 = poses[i][field]
		var p1: Vector3 = poses[i + 1][field]
		var m0 := _tangent(i, field)
		var m1 := _tangent(i + 1, field)
		var span := maxf(0.0001, t1 - t0)
		var s := clampf((t - t0) / span, 0.0, 1.0)
		var s2 := s * s
		var s3 := s2 * s
		return p0 * (2.0 * s3 - 3.0 * s2 + 1.0) + m0 * span * (s3 - 2.0 * s2 + s) \
			+ p1 * (-2.0 * s3 + 3.0 * s2) + m1 * span * (s3 - s2)
	return poses[n - 1][field]


func _tangent(i: int, field: int) -> Vector3:
	if i <= 0 or i >= poses.size() - 1:
		return Vector3.ZERO
	var dt := float(poses[i + 1][0]) - float(poses[i - 1][0])
	return ((poses[i + 1][field] as Vector3) - (poses[i - 1][field] as Vector3)) / maxf(0.0001, dt)


## The middle and size of the weapon's visible meshes, in the holder's space.
func _measure(v: WeaponView) -> void:
	var box := AABB()
	var first := true
	for node in v.model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or _skipped(mi, v.model):
			continue
		var xf := v.holder_space(mi)
		var b := xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		_centre = Vector3.ZERO
		_radius = 0.3
		return
	_centre = box.get_center()
	_radius = box.size.length() * 0.5


## Arms, hands and holograms are not the weapon.
static func _skipped(node: Node, model: Node) -> bool:
	var n := node
	while n and n != model:
		var s := String(n.name)
		if s.begins_with("Arm") or s.ends_with("Holo"):
			return true
		n = n.get_parent()
	return false
