class_name StrikeZoneView
extends RefCounted
## Strike Zone viewmodel motion (WeaponData.view_script). The loaded ball
## sits in the chamber under the front hood, the spare in the side ball
## return on the left flank (the magazine: Ball when one is loaded, Spare
## when two are).
##
## Winding up (the charge), the kicker pad behind the ball cocks back, the
## ball spins up on the spot and the three lane arrows on the deck light one
## by one; at full wind-up they flash together. A roll slams the kicker
## forward, the ball shoots out under the hood and, with one left, the spare
## hops out of the side return, arcs over the deck and drops into the
## chamber (hop(), shared with the reload). A strike (the ball comes back)
## throws gold sparks over the side return.

const ARROWS := 3
## How far the kicker cocks back at full wind-up (model units, towards the player).
const KICK_BACK := 0.032
## Seconds: the ball leaves the chamber, the kicker swings back, the spare hops in.
const SHOT_OUT := 0.1
const KICK_TIME := 0.22
const LOAD_START := 0.16
const LOAD_END := 0.42
## The ball's spin rate (rad/s) at full wind-up, and how fast the wind-up follows the charge.
const SPIN_RATE := 30.0
const WIND_FOLLOW := 18.0
## Glow of an unlit lane arrow, and the flash of a full wind-up (shares of the base glow).
const ARROW_DIM := 0.14
const ARROW_FULL := 2.4
## The spare's hop into the chamber (model space): the side return, back and
## up, over the deck, down the chamber's back (the rail's last points) and in.
const HOP: Array[Vector3] = [Vector3(-0.106, 0.03, -0.12), Vector3(-0.1, 0.12, -0.07), Vector3(-0.055, 0.15, -0.15),
	Vector3(-0.015, 0.13, -0.21), Vector3(0.0, 0.06, -0.245), Vector3(0.0, 0.044, -0.258)]
const GOLD := [Color(1.0, 0.85, 0.3), Color(1.0, 1.0, 0.85), Color(1.0, 0.3, 0.62)]

static var _curves := {}

var _ball: Node3D
var _spare: Node3D
var _kicker: Node3D
var _arrows: Array[StandardMaterial3D] = []
var _arrow_base := 2.0
var _since_shot := 10.0
var _shot_wind := 0.0
var _wind := 0.0
var _spin := 0.0
var _time := 0.0


func setup(v: WeaponView) -> void:
	register(v)
	_ball = v.part("Ball")
	_spare = v.part("Spare")
	_kicker = v.part("Kicker")
	# The reload's holograms stay hidden until it shows them.
	for holo in ["SpareHolo", "RailHolo"]:
		if v.part(holo):
			v.part(holo).visible = false
	for i in ARROWS:
		var mi := v.part("Arrow%d" % i) as MeshInstance3D
		if mi == null:
			continue
		var m := mi.get_surface_override_material(0) as StandardMaterial3D
		if m == null:
			m = (mi.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
			mi.set_surface_override_material(0, m)
		_arrow_base = m.emission_energy_multiplier
		_arrows.append(m)


## The parts this weapon moves (the view and the reload both pose them).
static func register(v: WeaponView) -> void:
	for part in ["Ball", "Spare", "Kicker", "SpareHolo", "RailHolo"]:
		v.register_part(part)
	for i in ARROWS:
		v.register_part("Arrow%d" % i)


## Where a ball hopping from the side return into the chamber is at `k`
## (0-1): back and up off the return, over the deck's front edge and down
## into the chamber (HOP, model space; the reload hops it back the other way).
static func hop(k: float) -> Vector3:
	return along(HOP, k)


## A point `k` (0-1) of the way along a smooth curve through `points`, at an
## even pace: a Catmull-Rom spline, sampled by its length (so a ball rolling
## along it never speeds up or slows down where two pieces meet).
static func along(points: Array[Vector3], k: float) -> Vector3:
	var key := hash(points)
	if not _curves.has(key):
		var c := Curve3D.new()
		c.bake_interval = 0.002
		var n := points.size()
		for i in n:
			var tangent := (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]) / 6.0
			c.add_point(points[i], -tangent, tangent)
		_curves[key] = c
	var curve: Curve3D = _curves[key]
	return curve.sample_baked(clampf(k, 0.0, 1.0) * curve.get_baked_length(), true)


## A ball turned by rolling `angle` radians along `dir` (model space).
static func rolled(rest: Basis, dir: Vector3, angle: float) -> Basis:
	var axis := Vector3.UP.cross(dir)
	if axis.length() < 0.001:
		return rest
	return Basis(axis.normalized(), angle) * rest


func fired(v: WeaponView) -> void:
	_since_shot = 0.0
	_shot_wind = _wind
	_spin = 0.0
	var vent := v.model.find_child("VentPoint", true, false) as Node3D if v.model else null
	if vent:
		var at := v.model.global_transform.affine_inverse() * vent.global_position
		v.spark_burst(at, Vector3(0, 0.3, -1), [Color(0.3, 0.95, 1.0), Color(1, 1, 1), Color(1.0, 0.3, 0.62)], 8 + int(_shot_wind * 8.0), 1.0, 0.25, 0.008)


func event(v: WeaponView, event_name: StringName) -> void:
	if event_name != &"strike" or _spare == null:
		return
	v.spark_burst(v.rest_transform("Spare").origin, Vector3.UP, GOLD, 18, 1.2, 0.4, 0.01)


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	_time += delta
	if v.is_reloading():
		return
	var w := _weapons(v)
	var mag := w.magazine() if w else v.data.magazine_size
	var charge := w.shown_charge() if w else 0.0
	_wind = lerpf(_wind, charge, 1.0 - exp(-WIND_FOLLOW * delta))
	_spin = wrapf(_spin + _wind * SPIN_RATE * delta, 0.0, TAU)
	_pose_kicker(v)
	_pose_balls(v, mag)
	_light_arrows(mag, charge)


## Cocked back with the wind-up; after a roll it slams forward past its rest and swings back.
func _pose_kicker(v: WeaponView) -> void:
	if _kicker == null:
		return
	var back := KICK_BACK * _wind * _wind
	if _since_shot < KICK_TIME:
		var k := _since_shot / KICK_TIME
		var slam := lerpf(KICK_BACK * _shot_wind * _shot_wind, -0.018, minf(1.0, k * 4.0))
		back = lerpf(slam, 0.0, smoothstep(0.25, 1.0, k))
	_kicker.transform = v.rest_transform("Kicker") * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, back))


func _pose_balls(v: WeaponView, mag: int) -> void:
	if _ball == null or _spare == null:
		return
	var ball_rest := v.rest_transform("Ball")
	var spare_rest := v.rest_transform("Spare")
	var hopping := _since_shot >= LOAD_START and _since_shot < LOAD_END and mag >= 1
	_spare.visible = mag >= 2 or (mag >= 1 and _since_shot < LOAD_START)
	_spare.transform = spare_rest
	if _since_shot < SHOT_OUT:
		# Out under the hood and down onto the lane, spinning forward.
		var k := _since_shot / SHOT_OUT
		_ball.visible = true
		var out := Vector3(0.0, -0.05 * k * k, -0.16 * k)
		_ball.transform = Transform3D(rolled(ball_rest.basis, Vector3.FORWARD, 3.2 * k + _spin), ball_rest.origin + out)
	elif hopping:
		var k := smoothstep(LOAD_START, LOAD_END, _since_shot)
		var at := hop(k)
		_ball.visible = true
		_ball.transform = Transform3D(rolled(ball_rest.basis, Vector3(0.6, 0.0, -1.0).normalized(), -TAU * (1.0 - k)), at)
	else:
		_ball.visible = mag >= 1 and _since_shot >= LOAD_START
		_ball.transform = Transform3D(rolled(ball_rest.basis, Vector3.FORWARD, _spin), ball_rest.origin)


## The lane arrows: the wind-up meter while charging, a slow chase when ready, dim when empty.
func _light_arrows(mag: int, charge: float) -> void:
	for i in _arrows.size():
		var k: float
		if charge > 0.0:
			var lit := clampf(charge * ARROWS - i, 0.0, 1.0)
			k = lerpf(ARROW_DIM, 1.0, lit)
			if charge >= 1.0:
				k = ARROW_FULL * (0.75 + 0.25 * sin(_time * 22.0))
		elif mag <= 0:
			k = ARROW_DIM
		else:
			k = 0.55 + 0.45 * maxf(0.0, sin(_time * 3.2 - i * 1.1))
		_arrows[i].emission_energy_multiplier = _arrow_base * k


static func _weapons(v: WeaponView) -> WeaponController:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return null
	return p.weapons
