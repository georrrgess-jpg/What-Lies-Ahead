class_name HandRig
extends Node

## Runtime side of the articulated hands (art/blender/hand_kit.py) on a weapon
## viewmodel: finds each hand's nodes, keeps the solved grip (the exported
## rest pose), blends every finger between that grip and the open, relaxed,
## spread, pinch, point and fist poses, and can hold a hand's arm on a grip
## anchor while the weapon moves, letting go and taking hold again smoothly.
##
## Nodes, for side S = "R" or "L" (the model's own names):
##   ArmS                 forearm (origin = grip centre); what attach() moves
##   ArmSHand             palm, pivot on the wrist (-Z towards the fingers, +Y the back)
##   ArmSGrip             empty in the palm on the handle's axis (turned like a Grip* anchor)
##   ArmS<Finger>1..3     phalanges, Finger = Index, Middle, Ring, Pinky; Thumb1..3
##   ArmSThumbBase        the ball of the thumb (turns to oppose)
##   ArmS<Finger>Tip      empty on each tip (child of the third phalanx)
##   ArmSPalmPoint        empty on the middle of the palm's face (a catch lands here)
## Every phalanx runs along its local -Z with its nail side +Y and flexes about
## its local X (rest rotation = twist * Basis(X, -flex), the twist a knuckle's
## splay about Y that closes the fingers square round the handle; it fades out
## as the finger opens); the knuckle (…1) also spreads about its local Y.
##
## Usage (a view's setup):  var rig := HandRig.of(view.model)
##   rig.set_pose(&"R", HandRig.Pose.OPEN, 0.2)          # every finger of the right hand
##   rig.set_finger(&"L", &"Index", HandRig.Pose.POINT)   # one finger
##   rig.set_curl(&"R", &"Thumb", 0.5)                    # 0 = open .. 1 = grip, at once
##   rig.attach(&"L", view.part("GripUpper"), 0.15)       # keep the left hand on an anchor
##   rig.detach(&"L", 0.1)                                # let the arm follow its own animation

enum Pose { GRIP, OPEN, RELAXED, SPREAD, PINCH, POINT, FIST }

const SIDES: Array[StringName] = [&"R", &"L"]
const FINGERS: Array[StringName] = [&"Index", &"Middle", &"Ring", &"Pinky", &"Thumb"]
## Flex (degrees, per phalanx) and spread (degrees, + away from the middle
## finger) of the fixed poses; a null flex means "the solved grip".
const FINGER_POSES := {
	Pose.OPEN: {&"Index": [4.0, 3.0, 2.0, 5.0], &"Middle": [4.0, 3.0, 2.0, 0.0], &"Ring": [5.0, 4.0, 3.0, 4.0],
		&"Pinky": [6.0, 5.0, 4.0, 8.0], &"Thumb": [6.0, 8.0, 6.0, 0.0]},
	Pose.RELAXED: {&"Index": [18.0, 24.0, 12.0, 3.0], &"Middle": [24.0, 30.0, 16.0, 0.0], &"Ring": [30.0, 34.0, 18.0, 3.0],
		&"Pinky": [36.0, 38.0, 20.0, 6.0], &"Thumb": [10.0, 16.0, 12.0, 0.0]},
	Pose.SPREAD: {&"Index": [0.0, 0.0, 0.0, 14.0], &"Middle": [0.0, 0.0, 0.0, 1.0], &"Ring": [0.0, 0.0, 0.0, 12.0],
		&"Pinky": [0.0, 0.0, 0.0, 24.0], &"Thumb": [0.0, 0.0, 0.0, 0.0]},
	Pose.PINCH: {&"Index": [38.0, 48.0, 22.0, 0.0], &"Middle": [46.0, 56.0, 30.0, 0.0], &"Ring": [58.0, 64.0, 36.0, 3.0],
		&"Pinky": [66.0, 70.0, 40.0, 6.0], &"Thumb": [24.0, 22.0, 14.0, 0.0]},
	Pose.POINT: {&"Index": [3.0, 2.0, 2.0, 0.0], &"Middle": [85.0, 95.0, 65.0, 0.0], &"Ring": [88.0, 95.0, 65.0, 0.0],
		&"Pinky": [90.0, 95.0, 65.0, 0.0], &"Thumb": [30.0, 40.0, 30.0, 0.0]},
	Pose.FIST: {&"Index": [85.0, 95.0, 65.0, 0.0], &"Middle": [88.0, 98.0, 65.0, 0.0], &"Ring": [90.0, 98.0, 65.0, 0.0],
		&"Pinky": [92.0, 98.0, 65.0, 0.0], &"Thumb": [30.0, 35.0, 40.0, 0.0]},
}
## How far each pose turns the ball of the thumb out of its grip opposition
## (0 = as solved round the handle, 1 = beside the palm, pointing forward).
const THUMB_OUT := {Pose.GRIP: 0.0, Pose.OPEN: 1.0, Pose.RELAXED: 0.55, Pose.SPREAD: 1.0, Pose.PINCH: 0.35,
	Pose.POINT: 0.25, Pose.FIST: 0.15}

## The hands found on the model: side -> _Hand.
var _hands := {}


## A hand's nodes and its live pose.
class _Hand:
	var arm: Node3D
	var hand: Node3D
	var grip: Node3D
	## Finger -> Array[Node3D] (three phalanges).
	var bones := {}
	## Finger -> rest flex per phalanx (the solved grip, degrees).
	var rest_flex := {}
	## Node -> rest Transform3D.
	var rest := {}
	## Node -> the part of its rest turn that is not flex (the knuckle's splay
	## that closes the fingers square round the handle), as a Quaternion.
	var twist := {}
	var thumb_base: Node3D
	## Finger -> the empty on its tip.
	var tips := {}
	var thumb_open: Basis
	var thumb_side := 1.0
	## Finger -> current [f1, f2, f3, spread, thumb_out]; from / to / progress / duration of the blend.
	var now := {}
	var from := {}
	var to := {}
	var t := {}
	var span := {}
	## Attachment: anchor, weight now, weight wanted, rate (1/s), the arm's own (unpinned) transform.
	var anchor: Node3D
	var weight := 0.0
	var goal := 0.0
	var rate := 0.0
	var free := Transform3D.IDENTITY
	var written := Transform3D.IDENTITY


## The rig of `model`, made (and added under it) on first use.
static func of(model: Node3D) -> HandRig:
	var found := model.get_node_or_null(^"HandRig") as HandRig
	if found:
		return found
	var rig := HandRig.new()
	rig.name = "HandRig"
	rig.setup(model)
	model.add_child(rig)
	return rig


func _init() -> void:
	# After the views have animated the weapon this frame.
	process_priority = 100


## Finds the hands of `model` (call again after swapping the model).
func setup(model: Node3D) -> void:
	_hands.clear()
	for side in SIDES:
		var hand := model.find_child("Arm%sHand" % side, true, false) as Node3D
		if hand == null:
			continue
		var h := _Hand.new()
		h.hand = hand
		h.arm = hand.get_parent() as Node3D
		h.grip = hand.get_node_or_null("Arm%sGrip" % side) as Node3D
		h.free = h.arm.transform
		h.written = h.arm.transform
		for finger in FINGERS:
			var chain: Array[Node3D] = []
			var flex: Array[float] = []
			var parent: Node = hand
			if finger == &"Thumb":
				h.thumb_base = hand.find_child("Arm%sThumbBase" % side, true, false) as Node3D
				parent = h.thumb_base
			for k in 3:
				var bone := parent.get_node_or_null("Arm%s%s%d" % [side, finger, k + 1]) as Node3D if parent else null
				if bone == null:
					break
				chain.append(bone)
				h.rest[bone] = bone.transform
				var f0 := _flex_of(bone.transform.basis)
				flex.append(f0)
				h.twist[bone] = Quaternion((bone.transform.basis * Basis(Vector3.RIGHT, deg_to_rad(f0))).orthonormalized())
				parent = bone
			if chain.size() < 3:
				continue
			h.bones[finger] = chain
			h.tips[finger] = chain[2].get_node_or_null("Arm%s%sTip" % [side, finger])
			h.rest_flex[finger] = flex
			var grip_now := [flex[0], flex[1], flex[2], 0.0, 0.0]
			h.now[finger] = grip_now.duplicate()
			h.from[finger] = grip_now.duplicate()
			h.to[finger] = grip_now.duplicate()
			h.t[finger] = 1.0
			h.span[finger] = 0.0
		if h.thumb_base:
			h.rest[h.thumb_base] = h.thumb_base.transform
			h.thumb_side = signf(h.thumb_base.position.x) if h.thumb_base.position.x != 0.0 else 1.0
			h.thumb_open = _thumb_open_basis(h.thumb_side)
		_hands[side] = h


## True if the model has this side's articulated hand.
func has_hand(side: StringName) -> bool:
	return _hands.has(side)


## The arm (forearm) node of a side: what attach() moves.
func arm(side: StringName) -> Node3D:
	return (_hands[side] as _Hand).arm if _hands.has(side) else null


## The palm node of a side (pivot on the wrist): turn it to bend the wrist.
func palm(side: StringName) -> Node3D:
	return (_hands[side] as _Hand).hand if _hands.has(side) else null


## A phalanx node (k = 1 knuckle .. 3 tip).
func bone(side: StringName, finger: StringName, k: int) -> Node3D:
	if not _hands.has(side):
		return null
	var chain: Array = (_hands[side] as _Hand).bones.get(finger, [])
	return chain[k - 1] if k >= 1 and k <= chain.size() else null


## World position of a finger's tip (its Arm<S><Finger>Tip empty).
func fingertip(side: StringName, finger: StringName) -> Vector3:
	var h: _Hand = _hands.get(side)
	var tip: Node3D = h.tips.get(finger) if h else null
	return tip.global_position if tip else Vector3.ZERO


## The empty on the middle of the palm's face (ArmSPalmPoint), or null.
func palm_point(side: StringName) -> Node3D:
	return (_hands[side] as _Hand).hand.get_node_or_null("Arm%sPalmPoint" % side) as Node3D if _hands.has(side) else null


## World transform of the hand's grip (on the handle's axis, turned like the Grip* anchors).
func grip_transform(side: StringName) -> Transform3D:
	var h: _Hand = _hands.get(side)
	if h == null:
		return Transform3D.IDENTITY
	return h.grip.global_transform if h.grip else h.hand.global_transform


## Blends every finger of a side to `pose` over `time` seconds.
func set_pose(side: StringName, pose: Pose, time := 0.15) -> void:
	for finger in FINGERS:
		set_finger(side, finger, pose, time)


## Blends one finger to `pose` over `time` seconds.
func set_finger(side: StringName, finger: StringName, pose: Pose, time := 0.15) -> void:
	var h: _Hand = _hands.get(side)
	if h == null or not h.bones.has(finger):
		return
	var goal: Array
	if pose == Pose.GRIP:
		var f: Array = h.rest_flex[finger]
		goal = [f[0], f[1], f[2], 0.0, 0.0]
	else:
		goal = (FINGER_POSES[pose][finger] as Array).duplicate()
		goal.append(THUMB_OUT[pose] if finger == &"Thumb" else 0.0)
	_blend_to(h, finger, goal, time)


## Sets a finger at once between open (0) and the solved grip (1); above 1 curls past it.
func set_curl(side: StringName, finger: StringName, curl: float) -> void:
	var h: _Hand = _hands.get(side)
	if h == null or not h.bones.has(finger):
		return
	# Written in place: cheap enough to call for every finger every frame.
	var open: Array = FINGER_POSES[Pose.OPEN][finger]
	var f: Array = h.rest_flex[finger]
	var v: Array = h.now[finger]
	for i in 3:
		v[i] = lerpf(open[i], f[i], curl)
	v[3] = lerpf(open[3], 0.0, clampf(curl, 0.0, 1.0))
	v[4] = clampf(1.0 - curl, 0.0, 1.0) if finger == &"Thumb" else 0.0
	h.t[finger] = 1.0
	_apply(h, finger)


## Sets a finger at once to explicit angles: flex per phalanx (degrees), spread
## (degrees away from the middle finger) and, for the thumb, how far its ball
## turns out of the grip (0..1).
func set_angles(side: StringName, finger: StringName, flex: Vector3, spread := 0.0, thumb_out := 0.0) -> void:
	var h: _Hand = _hands.get(side)
	if h == null or not h.bones.has(finger):
		return
	var v: Array = h.now[finger]
	v[0] = flex.x
	v[1] = flex.y
	v[2] = flex.z
	v[3] = spread
	v[4] = thumb_out
	h.t[finger] = 1.0
	_apply(h, finger)


## The solved grip flex of a finger (degrees per phalanx).
func grip_flex(side: StringName, finger: StringName) -> Vector3:
	var h: _Hand = _hands.get(side)
	if h == null or not h.rest_flex.has(finger):
		return Vector3.ZERO
	var f: Array = h.rest_flex[finger]
	return Vector3(f[0], f[1], f[2])


## Keeps the side's arm placed so its hand grips `anchor` (a Grip* empty, or
## any node turned the same way: Y along the handle towards the thumb, Z
## towards the palm), blending in over `time` seconds.
func attach(side: StringName, anchor: Node3D, time := 0.15) -> void:
	var h: _Hand = _hands.get(side)
	if h == null or anchor == null:
		return
	if h.anchor != null and h.anchor != anchor and h.weight > 0.0:
		# Changing anchors: start from where the arm is now.
		h.free = h.arm.transform
		h.weight = 0.0
	h.anchor = anchor
	h.goal = 1.0
	h.rate = 1.0 / time if time > 0.0 else INF


## Lets the side's arm go back to its own (animated) transform over `time` seconds.
func detach(side: StringName, time := 0.15) -> void:
	var h: _Hand = _hands.get(side)
	if h == null:
		return
	h.goal = 0.0
	h.rate = 1.0 / time if time > 0.0 else INF


## How firmly the side's arm is held on its anchor (0..1).
func attached(side: StringName) -> float:
	var h: _Hand = _hands.get(side)
	return h.weight if h else 0.0


## Puts every finger back on the solved grip and lets go of every anchor, at once.
func reset() -> void:
	for side in _hands:
		var h: _Hand = _hands[side]
		for finger in h.bones:
			set_finger(side, finger, Pose.GRIP, 0.0)
		h.anchor = null
		h.weight = 0.0
		h.goal = 0.0
		h.arm.transform = h.free
		h.written = h.free


func _process(delta: float) -> void:
	update(delta)


## Advances the finger blends and the anchors (called every frame by _process).
func update(delta: float) -> void:
	for side in _hands:
		var h: _Hand = _hands[side]
		for finger in h.bones:
			if h.t[finger] < 1.0:
				h.t[finger] = minf(1.0, h.t[finger] + delta / maxf(h.span[finger], 1e-4))
				var k := smoothstep(0.0, 1.0, h.t[finger])
				var a: Array = h.from[finger]
				var b: Array = h.to[finger]
				var v: Array = h.now[finger]
				for i in 5:
					v[i] = lerpf(a[i], b[i], k)
				_apply(h, finger)
		_hold(h, delta)


func _blend_to(h: _Hand, finger: StringName, goal: Array, time: float) -> void:
	h.from[finger] = (h.now[finger] as Array).duplicate()
	h.to[finger] = goal
	h.span[finger] = time
	h.t[finger] = 0.0 if time > 0.0 else 1.0
	if time <= 0.0:
		h.now[finger] = goal.duplicate()
		_apply(h, finger)


func _apply(h: _Hand, finger: StringName) -> void:
	var v: Array = h.now[finger]
	var chain: Array = h.bones[finger]
	# Spread turns the knuckle about the back-of-hand axis, away from the middle finger.
	var away := _spread_sign(h, finger)
	var rest_flex: Array = h.rest_flex[finger]
	for k in 3:
		var b: Node3D = chain[k]
		# The knuckle's splay comes in as the finger closes (none on an open hand).
		var w := clampf(float(v[k]) / maxf(float(rest_flex[k]), 1.0), 0.0, 1.0) if k == 0 else 1.0
		var basis := Basis(Quaternion.IDENTITY.slerp(h.twist[b], w)) * Basis(Vector3.RIGHT, deg_to_rad(-float(v[k])))
		if k == 0 and finger != &"Thumb":
			basis = Basis(Vector3.UP, deg_to_rad(float(v[3]) * away)) * basis
		b.transform = Transform3D(basis, (h.rest[b] as Transform3D).origin)
	if finger == &"Thumb" and h.thumb_base:
		var rest: Transform3D = h.rest[h.thumb_base]
		var q := Quaternion(rest.basis.orthonormalized()).slerp(Quaternion(h.thumb_open), clampf(float(v[4]), 0.0, 1.0))
		h.thumb_base.transform = Transform3D(Basis(q), rest.origin)


## Which way (about the knuckle's +Y) spreads a finger away from the middle finger.
func _spread_sign(h: _Hand, finger: StringName) -> float:
	# A positive turn about +Y swings the finger (-Z) towards -X; the thumb lies on thumb_side.
	var towards_thumb := -h.thumb_side
	match finger:
		&"Index":
			return towards_thumb
		&"Middle":
			return towards_thumb * 0.3
		_:
			return -towards_thumb


func _hold(h: _Hand, delta: float) -> void:
	# Anything else (a view's animation) that moved the arm since our last write sets its free pose.
	if not h.arm.transform.is_equal_approx(h.written):
		h.free = h.arm.transform
	if h.weight != h.goal:
		h.weight = move_toward(h.weight, h.goal, delta * h.rate) if h.rate != INF else h.goal
	if h.weight <= 0.0 or h.anchor == null or not h.anchor.is_inside_tree():
		if h.arm.transform != h.free:
			h.arm.transform = h.free
		h.written = h.arm.transform
		if h.weight <= 0.0 and h.goal <= 0.0:
			h.anchor = null
		return
	var parent := h.arm.get_parent() as Node3D
	var parent_global := parent.global_transform if parent else Transform3D.IDENTITY
	# The grip's place in the arm (through the wrist), so a bent wrist is kept.
	var grip_in_arm := h.hand.transform * (h.grip.transform if h.grip else Transform3D.IDENTITY)
	var pinned := parent_global.affine_inverse() * h.anchor.global_transform * grip_in_arm.affine_inverse()
	var k := smoothstep(0.0, 1.0, h.weight)
	h.arm.transform = h.free.interpolate_with(pinned, k)
	h.written = h.arm.transform


static func _flex_of(basis: Basis) -> float:
	# Rest basis = twist * Basis(X, -flex), the twist turning about Y: the bone's
	# -Z swung towards -Y by flex, its nail side (+Y) tipped back by the same.
	var along := basis * Vector3(0, 0, -1)
	var back := basis * Vector3.UP
	return rad_to_deg(atan2(-along.y, back.y))


## The ball of the thumb's open turn, in the palm's space: the thumb beside
## the palm, pointing forward and out, its nail facing up and out.
static func _thumb_open_basis(thumb_side: float) -> Basis:
	var along := Vector3(thumb_side * 0.55, -0.12, -0.83).normalized()
	var back := Vector3(thumb_side * 0.35, 0.94, 0.0)
	back = (back - along * back.dot(along)).normalized()
	var z := -along
	var x := back.cross(z).normalized()
	return Basis(x, back, z)
