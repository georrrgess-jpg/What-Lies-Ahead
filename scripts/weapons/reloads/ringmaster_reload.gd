extends RefCounted
## Ringmaster "drum swap": the rifle rolls its drum face to you; the support
## hand leaves the foregrip and thumbs the drum latch; the spent drum spins
## out of the well, its rings whirling and its bulbs dying, and drops away
## tumbling; the hand dips and comes back up with a fresh drum printing in as
## a hologram, tilts it in and slaps it home (it turns solid with a clunk and
## a spark); the three rings spin up counter-rotating while the bulbs chase
## round like a theatre marquee and light up row by row; the hand racks the
## brass charging handle, lets it snap home with a flick of the wrist and
## swings back to the foregrip.
##
## Every part is posed each frame from one timeline (WeaponView.drive) on
## smootherstep curves, so moves blend with no stops between keys (render a
## strip with tools/weapon_sheet.gd --mode=reload).

const ROOT_POS := Vector3(-0.05, 0.05, 0.03)
const ROOT_ROT := Vector3(-8.0, 30.0, 22.0)
## The support hand (offsets from its rest on the foregrip, model space):
## on the drum's latch (also where it holds the fresh drum seated), down where
## it fetches the fresh one, on the charging handle, and its flourish.
const HAND_LATCH := Vector3(-0.092, 0.018, 0.113)
const HAND_LOW := Vector3(-0.08, -0.2, 0.123)
const HAND_RACK := Vector3(-0.1, 0.11, 0.235)
const RACK_PULL := 0.042
## How far below the foregrip the hand slides off it and comes back from.
const GRIP_DROP := 0.12
const HAND_FLICK := Vector3(-0.09, 0.03, 0.12)
const HAND_ROT_LATCH := Vector3(0.0, 0.0, 8.0)
const HAND_ROT_RACK := Vector3(0.0, 0.0, 10.0)
## The spent drum's fall and tumble.
const FALL := Vector3(0.015, -0.36, -0.02)
const TUMBLE := Vector3(-210.0, 0.0, 0.0)
## The fresh drum's tilt as it comes in, and how fast the rings spin it up.
const HOLO_TILT := Vector3(-18.0, 0.0, 10.0)
const RING_SPIN := [540.0, -810.0, 1080.0]
const HOLO_SHADER := "res://art/shaders/holo.gdshader"
const HOLO_TINT := Color(1.0, 0.82, 0.42)
const SPARKS := [Color(1.0, 0.95, 0.75), Color(1.0, 0.82, 0.25), Color(0.95, 0.2, 0.32), Color(1.0, 0.65, 0.2)]
## [timeline point, sound, volume, pitch]
const SOUNDS := [[0.13, &"rm_latch", -4.0, 1.0], [0.16, &"rm_drop", -4.0, 1.0], [0.36, &"rm_holo", -7.0, 1.0],
	[0.56, &"rm_slap", -2.0, 1.0], [0.58, &"rm_spin", -5.0, 1.0], [0.72, &"rm_rack", -4.0, 0.92], [0.79, &"rm_rack", -3.0, 1.12]]
const OUT_AT := 0.16
const SNAP_AT := 0.56
const RACK_AT := 0.79

var _v: WeaponView
var _d := 1.0
var _s := 0.0
var _snapped := false
var _released := false
var _holo: ShaderMaterial
var _outer: Array[Node3D] = []
var _mid: Array[Node3D] = []


func play(v: WeaponView, d: float) -> void:
	_v = v
	_d = d
	RingmasterView.register(v)
	_outer = RingmasterView.bulbs(v, "BulbO", RingmasterView.OUTER)
	_mid = RingmasterView.bulbs(v, "BulbM", RingmasterView.MID)
	_holo = _holo_material(v)
	v.glow_ramp(0.1, 0.22, d, 1.0, 0.3)
	v.glow_ramp(SNAP_AT, SNAP_AT + 0.12, d, 3.0, 1.0)
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
	if not _released and s >= RACK_AT:
		_release()
	_s = s
	_pose(s)


func _pose(s: float) -> void:
	var v := _v
	var show := _e(0.0, 0.12, s) * (1.0 - _e(0.88, 1.0, s))
	_place(v.part("Root"), v.rest_transform("Root"), ROOT_POS * show, ROOT_ROT * show)
	_pose_drums(s)
	_pose_rings(s)
	_pose_bulbs(s)
	_pose_handle(s)
	_place(v.part("ArmL"), v.rest_transform("ArmL"), _hand_pos(s), _hand_rot(s))


## The spent drum spins out and falls; the hologram drum rides up in the hand,
## tilts square and is slapped home.
func _pose_drums(s: float) -> void:
	var v := _v
	var drum := v.part("Drum")
	if drum and s < SNAP_AT:
		var u := clampf((s - OUT_AT) / 0.15, 0.0, 1.0)
		var kick := _e(OUT_AT, OUT_AT + 0.04, s)
		var off := Vector3(0.0, -0.012, 0.0) * kick + FALL * u * u
		_place(drum, v.rest_transform("Drum"), off, TUMBLE * u * u)
		drum.visible = s < OUT_AT + 0.15
	var holo := v.part("DrumHolo")
	if holo == null:
		return
	holo.visible = s > 0.3 and s < SNAP_AT
	if not holo.visible:
		return
	var seat := _e(0.44, SNAP_AT, s)
	var off := _hand_pos(s) - HAND_LATCH
	_place(holo, v.rest_transform("DrumHolo"), off, HOLO_TILT * (1.0 - seat))
	if _holo:
		_holo.set_shader_parameter("materialize", _e(0.32, 0.5, s))
		_holo.set_shader_parameter("intensity", 1.3 + 0.5 * sin(s * _d * 28.0))


## Before the swap the spent rings whirl down; after it they spin up and coast.
func _pose_rings(s: float) -> void:
	var t: float
	if s < SNAP_AT:
		var u := clampf((s - OUT_AT) / 0.2, 0.0, 1.0)
		t = 0.25 * u
	else:
		var since := (s - SNAP_AT) * _d
		var run := 0.55
		var tc := minf(since, run)
		t = tc - tc * tc / (2.0 * run)
	RingmasterView.pose_rings(_v, RING_SPIN[0] * t, RING_SPIN[1] * t, RING_SPIN[2] * t)


## Dark while the drum is out; after the slap the bulbs chase round like a
## marquee, faster and faster, then light up row by row.
func _pose_bulbs(s: float) -> void:
	var dark := s > OUT_AT and s < SNAP_AT
	var since := (s - SNAP_AT) * _d
	var chase := s >= SNAP_AT and since < 0.5
	var step := int(since * lerpf(10.0, 26.0, clampf(since / 0.5, 0.0, 1.0)))
	var fill := clampf((since - 0.5) / 0.25, 0.0, 1.0)
	for i in _outer.size():
		if _outer[i]:
			_outer[i].visible = not dark and ((i + step) % 3 == 0 if chase else (s < OUT_AT or float(i) < fill * _outer.size()))
	for i in _mid.size():
		if _mid[i]:
			_mid[i].visible = not dark and ((i + step) % 2 == 0 if chase else (s < OUT_AT or float(i) < fill * _mid.size()))


## The charging handle goes back with the hand and snaps home when let go.
func _pose_handle(s: float) -> void:
	var back := _e(0.7, 0.77, s) * (1.0 - _snap_home(s))
	_place(_v.part("Handle"), _v.rest_transform("Handle"), Vector3(0.0, 0.0, RACK_PULL * back), Vector3.ZERO)


## The support hand's path: latch, down for the fresh drum, up to seat it,
## back to the handle, the rack, the flick and home to the foregrip.
func _hand_pos(s: float) -> Vector3:
	var down := _e(0.22, 0.32, s) * (1.0 - _e(0.36, 0.5, s))
	var slap := _slap(s)
	var to_rack := _e(0.6, 0.69, s)
	var pull := _e(0.7, 0.77, s) * (1.0 - _e(RACK_AT, RACK_AT + 0.02, s))
	var flick := WeaponInspect.hump(s, RACK_AT, 0.9)
	# Down off the foregrip first, out to the left, then back to the latch;
	# home again below the foregrip, in from the left, and up onto it last.
	var p := HAND_LATCH * Vector3(_e(0.03, 0.09, s), _e(0.06, 0.13, s), _e(0.05, 0.13, s))
	p.y -= GRIP_DROP * _e(0.0, 0.04, s) * (1.0 - _e(0.06, 0.13, s))
	p = p.lerp(HAND_LOW, down)
	p += Vector3(0.0, -0.014, 0.0) * (1.0 - slap) * _e(0.4, 0.5, s)
	p = p.lerp(HAND_RACK, to_rack) + Vector3(0.0, 0.0, RACK_PULL) * pull
	p += HAND_FLICK * flick
	var home_yz := _e(0.84, 0.91, s)
	var home_x := _e(0.88, 0.94, s)
	var rise := _e(0.94, 0.99, s)
	return Vector3(lerpf(p.x, 0.0, home_x), lerpf(p.y, -GRIP_DROP * (1.0 - rise), home_yz), lerpf(p.z, 0.0, home_yz))


func _hand_rot(s: float) -> Vector3:
	var latch := _e(0.02, 0.09, s) * (1.0 - _e(0.6, 0.69, s))
	var rack := _e(0.6, 0.69, s)
	var flick := WeaponInspect.hump(s, RACK_AT, 0.9)
	var home := _e(0.84, 0.96, s)
	return (HAND_ROT_LATCH * latch + HAND_ROT_RACK * rack + Vector3(0.0, 0.0, 40.0) * flick) * (1.0 - home)


func _snap() -> void:
	_snapped = true
	var drum := _v.part("Drum")
	if drum:
		drum.transform = _v.rest_transform("Drum")
		drum.visible = true
	var holo := _v.part("DrumHolo")
	if holo:
		holo.visible = false
	var p := _v.owner as Player
	if p:
		p.add_shake(0.06)
	_spark(_v.rest_transform("Drum").origin + Vector3(-0.035, 0.05, 0.0), Vector3(-1.0, 0.5, 0.0), 14)


func _release() -> void:
	_released = true
	_spark(_v.rest_transform("Handle").origin + Vector3(-0.02, 0.0, 0.01), Vector3(-0.8, 0.6, 0.3), 8)


func _spark(at: Vector3, dir: Vector3, amount: int) -> void:
	_v.spark_burst(at, dir, SPARKS, amount, 0.8, 0.4, 0.007)


## The hologram drum's shader, made on first use; the part starts hidden.
static func _holo_material(v: WeaponView) -> ShaderMaterial:
	var holo := v.part("DrumHolo") as MeshInstance3D
	if holo == null:
		return null
	if holo.material_override is ShaderMaterial:
		return holo.material_override
	var m := ShaderMaterial.new()
	m.shader = load(HOLO_SHADER)
	m.set_shader_parameter("holo_color", HOLO_TINT)
	m.set_shader_parameter("span", 0.14)
	holo.material_override = m
	holo.visible = false
	return m


## The last approach of the slap: it speeds up into the seat (no ease at the end: it lands).
static func _slap(s: float) -> float:
	var u := clampf((s - 0.48) / (SNAP_AT - 0.48), 0.0, 1.0)
	return u * u if u < 1.0 else 1.0


## The handle's snap home once let go: fast, no ease at the end.
static func _snap_home(s: float) -> float:
	var u := clampf((s - RACK_AT) / 0.025, 0.0, 1.0)
	return u * u if u < 1.0 else 1.0


## Smootherstep of s between a and b (zero speed and acceleration at both ends).
static func _e(a: float, b: float, s: float) -> float:
	var t := clampf((s - a) / (b - a), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _place(node: Node3D, rest: Transform3D, offset: Vector3, rot_deg: Vector3) -> void:
	if node:
		node.transform = Transform3D(rest.basis * Basis.from_euler(rot_deg * (PI / 180.0)), rest.origin + offset)
