extends RefCounted
## Jack Pot "wind-up": the gun turns its left flank to the eye, the support
## hand takes the crank and winds it two turns (speeding up, then easing
## to a stop), the brass drum turns with it and the comb plucks a music-box
## tune, one note per quarter turn. Meanwhile the box in the cup (if any)
## sinks into the magazine, and a fresh box prints in as a hologram above the
## cup, spins down into it and turns solid with a clunk. The hand goes back to
## the grip, and the lid bursts up a crack and slaps shut: the clown in it is
## wound and ready.
##
## Every part is posed each frame from one timeline (WeaponView.drive) on
## smootherstep curves, so the moves blend into each other with no stops
## between keys; the hand follows the crank's knob exactly while it winds.

const TURNS := 2.0
const WIND_START := 0.2
const WIND_END := 0.72
## The crank handle's centre relative to the crank's hub at rest (model space;
## art/blender/build_weapons_jack_pot.py KNOB_OUT, CRANK_R).
const KNOB := Vector3(-0.071, 0.044, 0.0)
## Where each hand waits, out of sight, while the other is on the crank.
const HAND_AWAY := Vector3(-0.1, -0.3, 0.08)
const ROOT_POS := Vector3(-0.05, 0.035, 0.05)
const ROOT_ROT := Vector3(10.0, 24.0, -12.0)
## The hologram box hovers this far above and ahead of the cup (model space) and spins down into it.
const HOLO_FROM := Vector3(0.0, 0.085, -0.03)
const HOLO_SPIN := 360.0
const HOLO_IN := 0.42
const SOLID_AT := 0.8
const SINK := 0.075
## The launch cup's axis in model space (as in jack_pot_view.gd): the box slides along it.
const CUP_AXIS := Vector3(0.0, 0.375, -0.927)
## The comb's tune: one note per quarter turn of the crank (pitch ratios of the pluck).
const TUNE: Array[float] = [1.0, 1.26, 1.5, 1.26, 1.68, 1.5, 1.26, 2.0]
const SPARKS := [Color(1.0, 0.82, 0.23), Color(0.35, 0.96, 0.75), Color(1.0, 0.42, 0.84), Color(1.0, 1.0, 1.0)]

var _v: WeaponView
var _d := 1.0
var _had_box := false
var _note := 0
var _solid := false
var _slapped := false
var _teased := false


func play(v: WeaponView, d: float) -> void:
	_v = v
	_d = d
	for part in ["Box", "Lid", "Crank", "Drum", "ArmLFist"]:
		v.register_part(part)
	_had_box = v.data.magazine_size > 0
	if v.player and v.player.weapons:
		_had_box = v.player.weapons.magazine() > 0
	v.glow_ramp(0.03, 0.14, d, 1.0, 0.25)
	v.holo_build("CellHolo", HOLO_IN, 0.62, d)
	v.solidify("CellHolo", "Box", SOLID_AT, d)
	v.at(0.04, d, func(): Sfx.play(&"jp_grab", -6.0))
	v.drive(d, _step)


## One frame of the reload: `s` is how far it has run (0-1).
func _step(s: float) -> void:
	if _v == null or not is_instance_valid(_v.model):
		return
	var show := _e(0.0, 0.12, s) * (1.0 - _e(0.86, 1.0, s))
	_place(_v.part("Root"), _v.rest_transform("Root"), ROOT_POS * show, ROOT_ROT * show)
	var angle := TAU * TURNS * _e(WIND_START, WIND_END, s)
	_pose_crank(angle)
	_pose_hand(s, angle)
	_play_notes(angle)
	_pose_box(s)
	_pose_holo(s)


func _pose_crank(angle: float) -> void:
	_place(_v.part("Crank"), _v.rest_transform("Crank"), Vector3.ZERO, Vector3(-rad_to_deg(angle), 0.0, 0.0))
	_place(_v.part("Drum"), _v.rest_transform("Drum"), Vector3.ZERO, Vector3(0.0, 0.0, rad_to_deg(angle) * 1.5))


## The support hand ducks out of sight (the grip hand is a wrapped pistol grip),
## and its other pose, a fist, comes up from below, closes on the crank handle
## and rides it round; then they swap back.
func _pose_hand(s: float, angle: float) -> void:
	var grip := _v.part("ArmL")
	var fist := _v.part("ArmLFist")
	if grip == null or fist == null:
		return
	var out := _e(0.0, 0.1, s) * (1.0 - _e(0.84, 0.97, s))
	grip.visible = out < 0.999
	var rest := _v.rest_transform("ArmL")
	grip.transform = Transform3D(rest.basis, rest.origin + HAND_AWAY * out)
	var reach := _e(0.08, 0.2, s) * (1.0 - _e(0.73, 0.85, s))
	fist.visible = s > 0.07 and reach > 0.001
	var knob := _v.rest_transform("Crank").origin + Basis(Vector3.RIGHT, -angle) * KNOB
	fist.transform = Transform3D(_v.rest_transform("ArmLFist").basis, knob + HAND_AWAY * (1.0 - reach))


## A note each time the crank passes a quarter turn.
func _play_notes(angle: float) -> void:
	var n := int(angle / (TAU * 0.25))
	while _note < n and _note < TUNE.size():
		Sfx.play(&"jp_pluck", -5.0, TUNE[_note])
		_note += 1


## The box in the cup sinks into the magazine to make room; once the new one
## is solid, the lid bursts up a crack and slaps shut.
func _pose_box(s: float) -> void:
	var box := _v.part("Box")
	if box == null:
		return
	if s < SOLID_AT:
		var sink := _e(0.28, 0.4, s)
		box.visible = _had_box and sink < 0.99
		box.transform = _v.rest_transform("Box") * Transform3D(Basis.IDENTITY, CUP_AXIS * -SINK * sink)
		return
	if not _solid:
		_solid = true
		Sfx.play(&"jp_clunk", -4.0)
		var p := _v.owner as Player
		if p:
			p.add_shake(0.05)
		_spark(16)
	box.visible = true
	var settle := 0.006 * sin(PI * _e(SOLID_AT, 0.86, s))
	box.transform = _v.rest_transform("Box") * Transform3D(Basis.IDENTITY, CUP_AXIS * -settle)
	var tease := sin(PI * _e(0.86, 0.94, s))
	if s >= 0.86 and not _teased:
		_teased = true
		Sfx.play(&"jp_tease", -5.0)
	if s >= 0.94 and not _slapped:
		_slapped = true
		Sfx.play(&"jp_clunk", -8.0, 1.4)
	_place(_v.part("Lid"), _v.rest_transform("Lid"), Vector3.ZERO, Vector3(38.0 * tease, 0.0, 0.0))


## The hologram box hovers out over the cup, spins down into it and is gone
## when it turns solid (WeaponView.solidify). It waits at its start, unseen,
## until it prints in.
func _pose_holo(s: float) -> void:
	var holo := _v.part("CellHolo")
	if holo == null or s >= SOLID_AT:
		return
	var u := _e(HOLO_IN, SOLID_AT - 0.02, s)
	var rest := _v.rest_transform("CellHolo")
	var spin := Basis(Vector3.UP, deg_to_rad(HOLO_SPIN * (1.0 - u)))
	var bob := 0.004 * sin((s - HOLO_IN) * _d * 9.0) * (1.0 - u)
	holo.transform = Transform3D(rest.basis * spin.scaled(Vector3.ONE * lerpf(0.75, 1.0, u)), rest.origin + HOLO_FROM * (1.0 - u) + Vector3.UP * bob)


func _spark(amount: int) -> void:
	var a := _v.model.find_child("EjectPoint", true, false) as Node3D
	if a:
		_v.spark_burst(_v.model.global_transform.affine_inverse() * a.global_position, Vector3.UP, SPARKS, amount, 0.9, 0.35, 0.008)


## Smootherstep of s between a and b (zero speed and acceleration at both ends).
static func _e(a: float, b: float, s: float) -> float:
	var t := clampf((s - a) / (b - a), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _place(node: Node3D, rest: Transform3D, offset: Vector3, rot_deg: Vector3) -> void:
	if node:
		node.transform = Transform3D(rest.basis * Basis.from_euler(rot_deg * (PI / 180.0)), rest.origin + offset)
