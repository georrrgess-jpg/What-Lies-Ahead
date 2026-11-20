class_name JinglestarChain
extends RefCounted
## The Jester's Jinglestar's chain and head as a small Verlet rope, in the
## WeaponView's frame (view units: x right, y up, z towards the eye). Point 0
## is the cap's eye (pinned to the handle), points 1..links the joints between
## links, the last point the head's centre (HEAD_MASS times as heavy).
##
## Stable at any frame rate: it steps at a fixed STEP with an accumulator (at
## most MAX_STEPS a frame; a longer frame is dropped, never run as one big
## step), the anchor is swept across the sub-steps, velocities are capped,
## and after the relaxation every segment is set back to its exact length
## from the anchor outwards, so the chain can never stretch or explode. The
## points are kept out of the colliders (capsules: the hand and forearm, the
## handle) and away from the eye. A teleport of the anchor resets it hanging.
##
## Ribbons are lighter ropes of their own (their roots carried by the head):
## a little gravity and a lot of air drag, so they stream behind the head.

## Fixed step (seconds) and the most steps one frame may run.
const STEP := 1.0 / 120.0
const MAX_STEPS := 8
const ITERATIONS := 6
## Gravity (view units / s^2; view units are real-size equivalents).
const GRAVITY := 9.8
## Velocity kept per second (1 = none lost): normal, and with Reduce motion.
const DAMPING := 1.1
const DAMPING_CALM := 5.0
const RIBBON_DRAG := 5.5
const RIBBON_GRAVITY := 0.35
## Fastest a point may move (view units a second).
const MAX_SPEED := 14.0
## The head's weight against one link.
const HEAD_MASS := 8.0
## Radii kept clear of the colliders: a link, the head (with its spikes).
const LINK_RADIUS := 0.008
const HEAD_RADIUS := 0.07
## Nearest a point may come to the eye, and the plane in front of it (view units).
const EYE_CLEAR := 0.3
const NEAR_Z := -0.2
## An anchor jump this far in one frame resets the chain.
const TELEPORT := 0.6

var p := PackedVector3Array()
var q := PackedVector3Array()
var lengths := PackedFloat32Array()
var inv_mass := PackedFloat32Array()
## Ribbons: each [points, previous points, segment length].
var ribbons: Array = []
## Colliders: each [a, b, radius] (capsules), set by the view every frame.
var capsules: Array = []
## The first point the handle's capsule applies to (the joints next to the cap are on it).
var handle_from := 3
var calm := false
var _acc := 0.0
var _anchor := Vector3.ZERO
## Pull on the head: target (view space) and strength (0 = none, 1 = firm).
var pull_target := Vector3.ZERO
var pull := 0.0
## Rate (1/s) at which a full pull draws the head to its target.
var pull_rate := 30.0


## Builds the chain: `segment_lengths` from the anchor (the last is the eye to the
## head's centre), hanging from `anchor` along `down`.
func setup(anchor: Vector3, down: Vector3, segment_lengths: PackedFloat32Array) -> void:
	lengths = segment_lengths
	var n := lengths.size() + 1
	p.resize(n)
	q.resize(n)
	inv_mass.resize(n)
	for i in n:
		inv_mass[i] = 1.0
	inv_mass[0] = 0.0
	inv_mass[n - 1] = 1.0 / HEAD_MASS
	hang(anchor, down)


## Adds a ribbon of `count` segments of `length`, rooted at `root`.
func add_ribbon(root: Vector3, down: Vector3, count: int, length: float) -> void:
	var pts := PackedVector3Array()
	for k in count + 1:
		pts.append(root + down * length * k)
	ribbons.append([pts, pts.duplicate(), length])


## Puts the chain (and ribbons) at rest, hanging straight from `anchor` along `down`.
func hang(anchor: Vector3, down: Vector3) -> void:
	_anchor = anchor
	var at := anchor
	p[0] = anchor
	for i in lengths.size():
		at += down * lengths[i]
		p[i + 1] = at
	q = p.duplicate()
	for r in ribbons:
		var pts: PackedVector3Array = r[0]
		var root := pts[0]
		for k in pts.size():
			pts[k] = root + down * float(r[2]) * k
		r[0] = pts
		r[1] = pts.duplicate()
	_acc = 0.0


## Lays the chain out from `anchor` along `dirs` (one direction a segment), at rest.
func lay(anchor: Vector3, dirs: Array) -> void:
	_anchor = anchor
	p[0] = anchor
	for i in lengths.size():
		p[i + 1] = p[i] + (dirs[mini(i, dirs.size() - 1)] as Vector3).normalized() * lengths[i]
	q = p.duplicate()
	_acc = 0.0


## The head's centre.
func head() -> Vector3:
	return p[p.size() - 1]


## The head's velocity (view units a second).
func head_velocity() -> Vector3:
	var n := p.size() - 1
	return (p[n] - q[n]) / STEP


## Moves every point (and its previous position) by `xf`: what the eye's own
## motion this frame does to a chain hanging in the world, a share `share` of it.
func carry(xf: Transform3D, share: float) -> void:
	if share <= 0.0:
		return
	for i in range(1, p.size()):
		var moved := xf * p[i] - p[i]
		if moved.length() > TELEPORT * 0.5:
			continue
		p[i] += moved * share
		q[i] += moved * share


## Moves the whole rope (and the ribbons) rigidly by `xf`, keeping its shape
## and motion: a paused weapon's chain carried along with its handle.
func move(xf: Transform3D) -> void:
	for i in p.size():
		p[i] = xf * p[i]
		q[i] = xf * q[i]
	for r in ribbons:
		var pts: PackedVector3Array = r[0]
		var prev: PackedVector3Array = r[1]
		for k in pts.size():
			pts[k] = xf * pts[k]
			prev[k] = xf * prev[k]
		r[0] = pts
		r[1] = prev
	_anchor = xf * _anchor


## Advances by `delta` with the anchor moving to `anchor`; `down` is the
## world's down in the view's frame. `ribbon_roots` are the ribbons' roots now.
func advance(delta: float, anchor: Vector3, down: Vector3, ribbon_roots: Array) -> void:
	if anchor.distance_to(_anchor) > TELEPORT:
		hang(anchor, down)
		return
	_acc = minf(_acc + delta, STEP * MAX_STEPS)
	var steps := int(_acc / STEP)
	if steps == 0:
		return
	var from := _anchor
	var keep := exp(-(DAMPING_CALM if calm else DAMPING) * STEP)
	var keep_ribbon := exp(-(RIBBON_DRAG + (DAMPING_CALM if calm else 0.0)) * STEP)
	var most := MAX_SPEED * STEP
	var g := down * GRAVITY * STEP * STEP
	for s in steps:
		_acc -= STEP
		var a := from.lerp(anchor, float(s + 1) / steps)
		p[0] = a
		q[0] = a
		for i in range(1, p.size()):
			var v := (p[i] - q[i]) * keep
			if v.length() > most:
				v = v.normalized() * most
			q[i] = p[i]
			p[i] += v + g
		if pull > 0.0:
			var n := p.size() - 1
			p[n] = p[n].lerp(pull_target, 1.0 - exp(-pull_rate * pull * STEP))
		for it in ITERATIONS:
			_relax()
			_collide()
		_exact()
		_ribbons(ribbon_roots, keep_ribbon, down)
	_anchor = anchor


func _relax() -> void:
	for i in lengths.size():
		var a := p[i]
		var b := p[i + 1]
		var d := b - a
		var dist := d.length()
		if dist < 1e-6:
			continue
		var wa := inv_mass[i]
		var wb := inv_mass[i + 1]
		var corr := d * ((dist - lengths[i]) / dist / (wa + wb))
		p[i] = a + corr * wa
		p[i + 1] = b - corr * wb


## Every segment back to its exact length, from the anchor outwards.
func _exact() -> void:
	for i in lengths.size():
		var d := p[i + 1] - p[i]
		var dist := d.length()
		var fixed := p[i] + (d / dist * lengths[i] if dist > 1e-6 else Vector3.DOWN * lengths[i])
		# The correction is not motion: carried by the previous position too.
		q[i + 1] += fixed - p[i + 1]
		p[i + 1] = fixed


func _collide() -> void:
	var last := p.size() - 1
	for i in range(1, p.size()):
		var r := HEAD_RADIUS if i == last else LINK_RADIUS
		var at := p[i]
		for k in capsules.size():
			if k == 1 and i < handle_from:
				continue
			var c: Array = capsules[k]
			at = _out_of(at, c[0], c[1], float(c[2]) + r)
		p[i] = _clear_of_eye(at, r)


## `at` pushed out of the capsule a-b of radius r.
static func _out_of(at: Vector3, a: Vector3, b: Vector3, r: float) -> Vector3:
	var ab := b - a
	var t := clampf((at - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	var c := a + ab * t
	var d := at - c
	var dist := d.length()
	if dist >= r:
		return at
	var out := d / dist if dist > 1e-5 else ab.cross(Vector3.UP).normalized()
	return c + out * r


static func _clear_of_eye(at: Vector3, r: float) -> Vector3:
	var out := at
	if out.z > NEAR_Z - r:
		out.z = NEAR_Z - r
	var dist := out.length()
	if dist < EYE_CLEAR + r:
		out = out / maxf(dist, 1e-5) * (EYE_CLEAR + r)
	return out


func _ribbons(roots: Array, keep: float, down: Vector3) -> void:
	var g := down * GRAVITY * RIBBON_GRAVITY * STEP * STEP
	for j in ribbons.size():
		var r: Array = ribbons[j]
		var pts: PackedVector3Array = r[0]
		var prev: PackedVector3Array = r[1]
		var length := float(r[2])
		pts[0] = roots[j] if j < roots.size() else pts[0]
		prev[0] = pts[0]
		for k in range(1, pts.size()):
			var v := (pts[k] - prev[k]) * keep
			prev[k] = pts[k]
			pts[k] += v + g
		for k in range(1, pts.size()):
			var d := pts[k] - pts[k - 1]
			var dist := d.length()
			var fixed := pts[k - 1] + (d / dist * length if dist > 1e-6 else down * length)
			prev[k] += fixed - pts[k]
			pts[k] = _clear_of_eye(fixed, 0.01)
		r[0] = pts
		r[1] = prev
