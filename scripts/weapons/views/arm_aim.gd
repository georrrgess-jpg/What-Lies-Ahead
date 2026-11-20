class_name ArmAim
extends RefCounted
## Keeps a melee weapon's arms coming from the player's body while the weapon
## swings (a round handle: mallets, clubs). Each arm's elbow stays where it is
## at rest, in the view's frame (x right, y up, z towards the camera); every
## frame the arm
##   swivels  round the handle (with its hand: the grip stays in contact on a
##            round shaft) until its forearm points as near the elbow as it can,
##   bends    at the wrist (the forearm alone; the hand stays on the handle)
##            by up to WRIST_MAX for the rest.
## Both follow smoothly and never faster than their speed limits, so nothing
## snaps when a swing carries the handle past the elbow.
##
##   var arms := ArmAim.new()
##   arms.setup(view)             # after the model is shown
##   arms.update(view, delta)     # after the view posed the model
##
## Needs the hand_kit arm nodes: Arm<S> (origin on the handle's axis, ElbowS
## child), Arm<S>Hand (pivot = the wrist). The handle runs along the model's -Z.

## The handle's direction in the model (the grip towards the working end).
const AXIS := Vector3(0.0, 0.0, -1.0)
## How far from the wrist the elbow is taken to be (view units, real size).
const REACH := 0.7
## The most an arm swivels round the handle either way, and bends at the wrist (degrees).
const SWIVEL_MAX := 100.0
const WRIST_MAX := 32.0
## How fast both follow (1 / seconds) and their top speeds (degrees a second).
const FOLLOW := 14.0
const SWIVEL_SPEED := 260.0
const WRIST_SPEED := 200.0

var _arms: Array[Node3D] = []
var _hands: Array[Node3D] = []
var _arm_rest: Array[Transform3D] = []
var _hand_rest: Array[Transform3D] = []
## Each forearm's rest direction (wrist to elbow) and wrist, in the model.
var _dir: Array[Vector3] = []
var _wrist: Array[Vector3] = []
## Each elbow in the view's frame.
var _elbow: Array[Vector3] = []
var _turn: Array[float] = []
var _bend: Array[Quaternion] = []


func setup(view: WeaponView) -> void:
	_arms.clear()
	_hands.clear()
	_arm_rest.clear()
	_hand_rest.clear()
	_dir.clear()
	_wrist.clear()
	_elbow.clear()
	_turn.clear()
	_bend.clear()
	var model := view.model
	if model == null or view.data == null:
		return
	# The model in the view's frame at rest: the hold, then the model's own rest.
	var hold := Transform3D(Basis.from_euler(view.data.view_rotation_degrees * (PI / 180.0)), view.data.view_position)
	var rest := hold * view.rest_transform("Root")
	for side in ["L", "R"]:
		var arm := model.find_child("Arm" + side, true, false) as Node3D
		var hand := model.find_child("Arm%sHand" % side, true, false) as Node3D
		var elbow := model.find_child("Elbow" + side, true, false) as Node3D
		if arm == null or hand == null or elbow == null:
			continue
		var wrist := arm.transform * hand.position
		var dir := (arm.transform * elbow.position - wrist).normalized()
		_arms.append(arm)
		_hands.append(hand)
		_arm_rest.append(arm.transform)
		_hand_rest.append(hand.transform)
		_dir.append(dir)
		_wrist.append(wrist)
		_elbow.append(rest * (wrist + dir * REACH))
		_turn.append(0.0)
		_bend.append(Quaternion.IDENTITY)


func update(view: WeaponView, delta: float) -> void:
	var model := view.model
	if model == null or _arms.is_empty():
		return
	# The model in the view's frame now, whatever the holder does (swing, aim, inspect).
	var to_model := (view.global_transform.affine_inverse() * model.global_transform).affine_inverse()
	var follow := 1.0 - exp(-FOLLOW * delta)
	for i in _arms.size():
		var rest := _arm_rest[i]
		var grip := rest.origin
		var elbow := to_model * _elbow[i]
		_turn[i] = _swivel(_turn[i], _dir[i], elbow - grip, follow, delta)
		var spin := Basis(AXIS, _turn[i])
		var wrist := grip + spin * (_wrist[i] - grip)
		var dir := spin * _dir[i]
		_bend[i] = _wrist_bend(_bend[i], dir, (elbow - wrist).normalized(), follow, delta)
		var bend := Basis(_bend[i])
		# Swivel about the grip (on the handle's axis), then bend about the wrist.
		var swivelled := Transform3D(spin * rest.basis, grip)
		_arms[i].transform = Transform3D(bend, wrist - bend * wrist) * swivelled
		# The hand stays where the swivel alone puts it.
		_hands[i].transform = _arms[i].transform.affine_inverse() * swivelled * _hand_rest[i]


## The swivel that turns `dir` (across the handle) towards `want`, taken the
## way round nearest the current turn so a target passing behind the handle
## never flips the arm to the other side.
func _swivel(turn: float, dir: Vector3, want: Vector3, follow: float, delta: float) -> float:
	var a := dir - AXIS * dir.dot(AXIS)
	var b := want - AXIS * want.dot(AXIS)
	var goal := turn
	if a.length() > 0.01 and b.length() > 0.01:
		goal = a.signed_angle_to(b, AXIS)
		goal += TAU * roundf((turn - goal) / TAU)
		goal = clampf(goal, -deg_to_rad(SWIVEL_MAX), deg_to_rad(SWIVEL_MAX))
	var most := deg_to_rad(SWIVEL_SPEED) * delta
	return turn + clampf((goal - turn) * follow, -most, most)


## The wrist bend that carries the forearm from `dir` towards `want`, at most
## WRIST_MAX, eased towards from the current bend.
func _wrist_bend(bend: Quaternion, dir: Vector3, want: Vector3, follow: float, delta: float) -> Quaternion:
	var goal := Quaternion.IDENTITY
	var axis := dir.cross(want)
	if axis.length() > 0.001:
		goal = Quaternion(axis.normalized(), minf(dir.angle_to(want), deg_to_rad(WRIST_MAX)))
	var gap := bend.angle_to(goal)
	if gap < 0.0001:
		return goal
	var step := minf(gap * follow, deg_to_rad(WRIST_SPEED) * delta)
	return bend.slerp(goal, step / gap)
