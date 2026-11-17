extends RefCounted
## Yo-Yo Loco "Around the World": the gun rolls over to show its spool; the
## worn string frays (the coil flickers, shrinks and spits sparks) and
## unspools; the gun swings in towards the middle of the view and the yo-yo
## pops out of the fork on its string and swings one big loop up and round
## in front of it (out to the left, over the top and down the right), turning
## its starred face to the player, while a hologram string rewinds onto the
## spinning spool and turns solid; the yo-yo swoops back into the fork with a
## clack and the gun settles.
##
## Every part is posed each frame from one timeline (WeaponView.drive) on
## smooth curves: the yo-yo's whole path is one spiral (its radius and
## centre swell and shrink on sines, its angle on the same eased clock), so it
## leaves the fork and lands back in it at rest with no snap anywhere.

const ROOT_POS := Vector3(-0.03, 0.02, 0.01)
const ROOT_ROT := Vector3(4.0, 14.0, 16.0)
## Extra swing in while the yo-yo loops, so the loop sits in the middle of the view.
const LOOP_ROOT_ROT := Vector3(6.0, 8.0, -12.0)
## The loop: its centre moves this far from the fork (model space, -Z
## forward), up and to the left, and its radius swells to LOOP_RADIUS; it is
## drawn across the view (in the model's X-Y plane) so it reads as a circle.
const LOOP_CENTRE := Vector3(-0.05, 0.12, -0.07)
const LOOP_RADIUS := 0.105
const LOOP_START := 0.17
const LOOP_END := 0.84
const YOYO_SPIN := 2.4
## Spool turns (degrees): unwinding the frayed string, rewinding the new one.
const UNWIND := -540.0
const REWIND := 1440.0
const LAND_BUMP := Vector3(3.0, 0.0, -2.0)
const FRAY := [Color(0.85, 1.0, 0.35), Color(1.0, 0.55, 0.2), Color(1.0, 1.0, 0.85)]
const LIME := [Color(0.85, 1.0, 0.35), Color(1.0, 1.0, 0.85), Color(1.0, 0.45, 0.85)]
## [timeline point, sound, volume, pitch]
const SOUNDS := [[0.07, &"yoyo_fray", -5.0, 1.0], [0.18, &"yoyo_pop", -6.0, 1.0], [0.3, &"yoyo_whirl", -5.0, 1.0],
	[0.3, &"yoyo_rewind", -8.0, 1.0], [LOOP_END, &"yoyo_clack", -3.0, 1.05]]

var _v: WeaponView
var _d := 1.0
var _s := 0.0
var _landed := false
var _flickered := false
var _tether_len := 0.055


func play(v: WeaponView, d: float) -> void:
	_v = v
	_d = d
	for part in ["Yoyo", "Spool", "Tether"]:
		v.register_part(part)
	var tether := v.part("Tether")
	var yoyo := v.part("Yoyo")
	if tether and yoyo:
		_tether_len = maxf(0.01, v.rest_transform("Yoyo").origin.distance_to(v.rest_transform("Tether").origin))
	v.burst(0.1, d, "EjectPoint", "sparks")
	v.hide_part(0.27, d, "Cell")
	v.holo_build("CellHolo", 0.28, 0.58, d)
	v.solidify("CellHolo", "Cell", 0.68, d)
	v.glow_ramp(0.86, 0.9, d, 1.0, 2.6)
	v.glow_ramp(0.9, 1.0, d, 2.6, 1.0)
	v.drive(d, _step)


## One frame of the reload: `k` is how far it has run (0-1).
func _step(k: float) -> void:
	if _v == null or not is_instance_valid(_v.model):
		return
	for snd in SOUNDS:
		if _s < float(snd[0]) and k >= float(snd[0]):
			Sfx.play(snd[1], snd[2], snd[3])
	if not _landed and k >= LOOP_END:
		_land()
	_s = k
	_pose_root(k)
	_pose_spool(k)
	_pose_coil(k)
	_pose_yoyo(k)


## The gun rolls its spool side up, holds, and settles back with a nod at the catch.
func _pose_root(s: float) -> void:
	var show := _e(0.0, 0.14, s) * (1.0 - _e(0.8, 0.97, s))
	var loop := sin(PI * _e(LOOP_START - 0.05, LOOP_END, s))
	var bump := sin(PI * _e(LOOP_END, 0.95, s))
	_place(_v.part("Root"), _v.rest_transform("Root"), ROOT_POS * show + Vector3(0.0, -0.006, 0.01) * bump,
		ROOT_ROT * show + LOOP_ROOT_ROT * loop + LAND_BUMP * bump)


## The spool unwinds the frayed string, then rewinds the new one fast and settles.
func _pose_spool(s: float) -> void:
	var turn := UNWIND * _e(0.06, 0.26, s) + REWIND * _e(0.28, 0.8, s)
	_place(_v.part("Spool"), _v.rest_transform("Spool"), Vector3.ZERO, Vector3(-turn, 0.0, 0.0))


## The worn coil flickers and shrinks as it frays (hidden at 0.27; the
## hologram takes over and turns solid on its own timeline).
func _pose_coil(s: float) -> void:
	if s >= 0.27:
		return
	var coil := _v.part("Cell")
	if coil == null:
		return
	var fray := _e(0.06, 0.26, s)
	var flicker := 1.0 if fmod(s * _d * 30.0, 1.0) > fray * 0.6 else 0.0
	coil.visible = flicker > 0.5 or fray < 0.05
	var rest := _v.rest_transform("Cell")
	coil.transform = Transform3D(rest.basis.scaled(Vector3(1.0, lerpf(1.0, 0.45, fray), lerpf(1.0, 0.45, fray))), rest.origin)
	if not _flickered and fray > 0.5:
		_flickered = true
		_spark(_v.part("Spool"), FRAY, 10)


## The yo-yo's Around the World and its string from the nose to it.
func _pose_yoyo(s: float) -> void:
	var yoyo := _v.part("Yoyo")
	if yoyo == null:
		return
	var rest := _v.rest_transform("Yoyo")
	var u := _e(LOOP_START, LOOP_END, s)
	var swell := sin(PI * u)
	var a := TAU * u
	# Out to the left, over the top and down the right, across the view.
	var around := Vector3(-sin(a), -cos(a), 0.0) * LOOP_RADIUS * swell
	var centre := LOOP_CENTRE * swell
	var at := rest.origin + centre + around
	# It turns its starred face to the player as the loop opens.
	var face := Basis(Vector3.UP, deg_to_rad(80.0) * swell)
	var spin := Basis(Vector3.RIGHT, -YOYO_SPIN * TAU * s * (1.0 + 2.0 * swell))
	yoyo.transform = Transform3D(rest.basis * face * spin, at)
	_pose_tether(at)


## Stretches the string from the port in the nose to the yo-yo.
func _pose_tether(yoyo_at: Vector3) -> void:
	var tether := _v.part("Tether")
	if tether == null:
		return
	var rest := _v.rest_transform("Tether")
	var to := yoyo_at - rest.origin
	var length := to.length()
	if length < 0.001:
		tether.transform = rest
		return
	var z := -to / length
	var up := Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	tether.transform = Transform3D(Basis(x, y, z * (length / _tether_len)), rest.origin)


## Back in the fork: a clack, a shake and a pinch of sparks.
func _land() -> void:
	_landed = true
	var p := _v.owner as Player
	if p:
		p.add_shake(0.05)
	_spark(_v.part("Yoyo"), LIME, 12)


func _spark(anchor: Node3D, colors: Array, amount: int) -> void:
	if anchor and _v.model:
		_v.spark_burst(_v.model.global_transform.affine_inverse() * anchor.global_position, Vector3.UP, colors, amount, 0.9, 0.3, 0.008)


## Smootherstep of s between a and b (zero speed and acceleration at both ends).
static func _e(a: float, b: float, s: float) -> float:
	var t := clampf((s - a) / (b - a), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _place(node: Node3D, rest: Transform3D, offset: Vector3, rot_deg: Vector3) -> void:
	if node:
		node.transform = Transform3D(rest.basis * Basis.from_euler(rot_deg * (PI / 180.0)), rest.origin + offset)
