extends RefCounted
## Ticket Ripper "fresh roll": the gun rolls over to show its drum; the
## drum's left plate (the counter door) swings open on its front hinge; the
## empty spool slides out on its axle, flips up and tumbles away; a hologram
## roll of tickets prints in beside the drum, spinning, glides onto the axle
## and snaps home with a clunk as it turns solid; the door slams shut; then
## the support hand leaves the foregrip, pinches the leading ticket of the
## ribbon and tears it off with a flick, the ribbon swinging after it, and
## returns to the grip.
##
## Every part is posed each frame from one timeline (WeaponView.drive) on
## smootherstep curves and one parabola, so moves blend with no stops
## between keys (render a strip with tools/weapon_sheet.gd --mode=reload).

const ROOT_POS := Vector3(-0.03, 0.03, 0.02)
const ROOT_ROT := Vector3(-4.0, 24.0, 10.0)
## The door's swing (degrees about its vertical hinge, negative = outward).
const DOOR_OPEN := -112.0
## How far the spool slides out along the axle, and the holo roll's start.
const SLIDE_OUT := Vector3(-0.075, 0.0, 0.0)
const HOLO_START := Vector3(-0.085, 0.045, 0.0)
## The support hand: where it pinches the leading ticket and the tear's pull
## (model space offsets from its rest on the foregrip), and its turn.
const GRAB := Vector3(-0.1, 0.035, 0.126)
const RIP := Vector3(-0.05, -0.075, 0.03)
const HAND_ROT := Vector3(0.0, 0.0, 18.0)
## How far below the foregrip the hand comes home from.
const HOME_DROP := 0.07
const SPARKS := [Color(1.0, 0.95, 0.8), Color(1.0, 0.4, 0.55), Color(1.0, 0.84, 0.3), Color(1.0, 0.62, 0.82)]
## [timeline point, sound, volume, pitch]
const SOUNDS := [[0.08, &"tkr_door", -5.0, 1.0], [0.2, &"tkr_eject", -5.0, 1.0], [0.37, &"tkr_holo", -6.0, 1.0],
	[0.6, &"tkr_snap", -3.0, 1.0], [0.7, &"tkr_door", -4.0, 0.85], [0.81, &"tkr_tear", -3.0, 1.0]]
const SNAP_AT := 0.6
## The holo roll's spin (degrees a second) and the seconds the fresh roll coasts it down.
const HOLO_SPIN := 900.0
const COAST := 0.3
const TEAR_AT := 0.81

var _v: WeaponView
var _d := 1.0
var _s := 0.0
var _k0 := 1.0
var _snapped := false
var _torn := false
var _label: Label3D
var _pips: Array[Node3D] = []
var _holo: ShaderMaterial


func play(v: WeaponView, d: float) -> void:
	_v = v
	_d = d
	TicketRipperView.register(v)
	v.register_part("DrumDoor")
	_pips = TicketRipperView.pips(v)
	_label = TicketRipperView.counter_label(v)
	_holo = TicketRipperView.holo_material(v)
	var w := TicketRipperView.weapons_of(v)
	_k0 = TicketRipperView.roll_scale(float(w.magazine()) / v.data.magazine_size if w else 0.0)
	v.glow_ramp(0.06, 0.2, d, 1.0, 0.35)
	v.glow_ramp(SNAP_AT, SNAP_AT + 0.1, d, 3.2, 1.0)
	v.drive(d, _step)


func _step(k: float) -> void:
	if _v == null or not is_instance_valid(_v.model):
		return
	var s := k
	for snd in SOUNDS:
		if _s < float(snd[0]) and s >= float(snd[0]):
			Sfx.play(snd[1], snd[2], snd[3])
	if not _snapped and s >= SNAP_AT:
		_snap()
	if not _torn and s >= TEAR_AT:
		_tear()
	_s = s
	_pose(s)


func _pose(s: float) -> void:
	var v := _v
	var show := _e(0.0, 0.14, s) * (1.0 - _e(0.88, 1.0, s))
	_place(v.part("Root"), v.rest_transform("Root"), ROOT_POS * show, ROOT_ROT * show)
	var door := _e(0.06, 0.18, s) * (1.0 - _slam(s))
	_place(v.part("DrumDoor"), v.rest_transform("DrumDoor"), Vector3.ZERO, Vector3(0.0, DOOR_OPEN * door, 0.0))
	_pose_rolls(s)
	_pose_hand(s)
	_pose_ribbon(s)
	var w := TicketRipperView.weapons_of(v)
	TicketRipperView.show_counter(_label, _pips, w.mode as TicketRipperMode if w else null, s * _d)


## The spent spool slides out, flips up and tumbles away; the hologram roll
## prints in, glides onto the axle (speeding up: it snaps on) and turns solid.
func _pose_rolls(s: float) -> void:
	var v := _v
	if s >= SNAP_AT:
		_pose_fresh(s)
	else:
		var out := _e(0.16, 0.26, s)
		var u := clampf((s - 0.25) / 0.13, 0.0, 1.0)
		var fling := Vector3(-0.07 * u, 0.06 * u - 0.16 * u * u, 0.03 * u)
		var tumble := Vector3(0.0, -40.0 * u, 160.0 * u)
		var roll := v.part("Roll")
		if roll:
			roll.visible = s < 0.38
		TicketRipperView.pose_roll(v, _k0 * (1.0 - 0.3 * u), 420.0 * out + 300.0 * u, SLIDE_OUT * out + fling, tumble)
	var holo := v.part("RollHolo")
	if holo == null:
		return
	holo.visible = s > 0.34 and s < SNAP_AT
	if not holo.visible:
		return
	var print_in := _e(0.34, 0.48, s)
	var glide := _glide(s)
	var at := HOLO_START.lerp(SLIDE_OUT, _e(0.4, 0.5, s)).lerp(Vector3.ZERO, glide)
	var spin := HOLO_SPIN * (s - 0.34) * _d
	var rest := v.rest_transform("RollHolo")
	var b := Basis(Vector3.RIGHT, deg_to_rad(spin)).scaled(Vector3.ONE * lerpf(0.75, 1.0, print_in))
	holo.transform = Transform3D(rest.basis * b, rest.origin + at)
	if _holo:
		_holo.set_shader_parameter("materialize", print_in)
		_holo.set_shader_parameter("intensity", 1.3 + 0.6 * sin(s * _d * 30.0))


## After the snap the fresh roll settles with a little seat bump and coasts its spin down.
func _pose_fresh(s: float) -> void:
	var bump := 0.003 * sin(PI * clampf((s - SNAP_AT) / 0.05, 0.0, 1.0))
	var tc := minf((s - SNAP_AT) * _d, COAST)
	var spin := HOLO_SPIN * ((SNAP_AT - 0.34) * _d + tc - tc * tc / (2.0 * COAST))
	TicketRipperView.pose_roll(_v, 1.0, spin, Vector3(0.0, -bump, 0.0))


## The support hand: off the foregrip, up to the ribbon, the pinch, the tear
## (a quick flick down and out), and back to the grip.
func _pose_hand(s: float) -> void:
	var arm := _v.part("ArmL")
	if arm == null:
		return
	# Out to the left first, then back along the flank, so it clears the
	# firing hand; home again from below, sliding up onto the foregrip.
	var reach := _e(0.62, 0.77, s)
	var rip := _e(TEAR_AT - 0.015, TEAR_AT + 0.05, s)
	var home := _e(0.86, 0.93, s)
	var k := Vector3(_e(0.62, 0.71, s), reach, _e(0.66, 0.77, s)) * (1.0 - home)
	var pos := (GRAB * k + RIP * rip) * (1.0 - home) + Vector3.DOWN * HOME_DROP * home * (1.0 - _e(0.92, 0.99, s))
	var rot := (HAND_ROT * reach + Vector3(0.0, 0.0, 10.0) * rip) * (1.0 - home)
	_place(arm, _v.rest_transform("ArmL"), pos, rot)
	var tip := _v.part("Rib3")
	if tip and _torn:
		var rest := _v.rest_transform("Rib3")
		var u := _e(TEAR_AT, TEAR_AT + 0.05, s)
		tip.transform = Transform3D(rest.basis * Basis(Vector3.BACK, deg_to_rad(-50.0 * u)), rest.origin + Vector3(-0.03, -0.05, 0.02) * u)
		tip.visible = s < TEAR_AT + 0.055


## The ribbon: the pinch draws it out, the tear lets it swing back and ring down.
func _pose_ribbon(s: float) -> void:
	var pull := _e(0.74, TEAR_AT, s) * (1.0 - _e(TEAR_AT, TEAR_AT + 0.02, s))
	var t := maxf(0.0, s - TEAR_AT) * _d
	var ring := sin(t * 18.0) * exp(-t * 5.0) if s > TEAR_AT else 0.0
	var angles := PackedFloat32Array()
	for i in TicketRipperView.RIBS:
		angles.append((8.0 + 6.0 * i) * pull + (6.0 + 5.0 * i) * ring)
	var keep := _v.part("Rib3")
	var keep_tf := keep.transform if keep and _torn else Transform3D()
	TicketRipperView.pose_ribbon(_v, angles, Vector3(-0.004 * pull, 0.0, 0.0))
	if keep and _torn:
		keep.transform = keep_tf


func _snap() -> void:
	_snapped = true
	var roll := _v.part("Roll")
	if roll:
		roll.visible = true
	var p := _v.owner as Player
	if p:
		p.add_shake(0.05)
	_spark(_v.rest_transform("Roll").origin + Vector3(-0.03, 0.03, 0.0), Vector3(-1.0, 0.6, 0.0), 12)


func _tear() -> void:
	_torn = true
	_spark(_v.rest_transform("Rib0").origin + Vector3(-0.07, -0.07, 0.0), Vector3(-0.6, -1.0, 0.2), 14)


func _spark(at: Vector3, dir: Vector3, amount: int) -> void:
	_v.spark_burst(at, dir, SPARKS, amount, 0.8, 0.4, 0.007)


## The door's slam shut: it speeds up as it closes (no ease at the end: it lands).
static func _slam(s: float) -> float:
	var u := clampf((s - 0.62) / 0.08, 0.0, 1.0)
	return u * u * (2.0 - u) if u < 1.0 else 1.0


## The holo roll's glide onto the axle: eased out of the hover, accelerating into the snap.
static func _glide(s: float) -> float:
	var u := clampf((s - 0.5) / (SNAP_AT - 0.5), 0.0, 1.0)
	return u * u * u * (2.0 - u) if u < 1.0 else 1.0


## Smootherstep of s between a and b (zero speed and acceleration at both ends).
static func _e(a: float, b: float, s: float) -> float:
	var t := clampf((s - a) / (b - a), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _place(node: Node3D, rest: Transform3D, offset: Vector3, rot_deg: Vector3) -> void:
	if node:
		node.transform = Transform3D(rest.basis * Basis.from_euler(rot_deg * (PI / 180.0)), rest.origin + offset)
