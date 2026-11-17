extends RefCounted
## Strike Zone "ball return": the gun swings its nose in and rolls over to
## show its left flank and the chamber, and the kicker cocks back. A ball
## still in the chamber hops back into the side return. A hologram
## ball-return rail curls up from under the gun, past the hood and back over
## the deck's front edge; a fresh ball comes rolling up it from below, slows
## over the crest and drops into the chamber with a clunk and a little
## bounce, still spinning: the spin winds down as it rights itself until its
## finger holes face the player. With the side return empty, a hologram
## spare prints into it and turns solid. The rail dissolves back down, the
## lane arrows chase on, and the kicker and the gun settle.
##
## Every part is posed each frame from one timeline (WeaponView.drive) on
## smooth curves: the ball's pace along the rail is one Hermite curve
## (fast up from below, slow over the crest, quickening into the drop) and it
## turns by exactly the distance it rolls.

## The ball's centre along the rail, model space (build_weapons_strike_zone.py RAIL_PATH).
const RAIL: Array[Vector3] = [Vector3(-0.12, -0.27, -0.34), Vector3(-0.16, -0.15, -0.345), Vector3(-0.17, -0.03, -0.33),
	Vector3(-0.14, 0.08, -0.29), Vector3(-0.075, 0.145, -0.23), Vector3(-0.015, 0.13, -0.205), Vector3(0.0, 0.06, -0.245),
	Vector3(0.0, 0.044, -0.258)]
const BALL_R := 0.05
const ROOT_POS := Vector3(-0.04, 0.045, 0.02)
const ROOT_ROT := Vector3(14.0, 22.0, -26.0)
const KICK_BACK := 0.032
## Timeline: the old ball hops out, the rail rises, the new ball rolls up and lands.
const HOP_OUT := Vector2(0.08, 0.3)
const RAIL_IN := Vector2(0.1, 0.3)
const ROLL := Vector2(0.32, 0.64)
const SPIN := Vector2(0.64, 0.9)
const SPARE_IN := Vector2(0.56, 0.78)
const RAIL_OUT := Vector2(0.82, 0.95)
## Pace along the rail: share of the way at the crest, and the speeds (share
## of the way per share of the roll's time) leaving the bottom, over the
## crest and into the drop.
const CREST_T := 0.74
const CREST_AT := 0.84
const PACE := Vector3(1.6, 0.42, 1.7)
## The finger-hole spin (degrees about the ball's vertical): it starts as
## fast as the ball was rolling when it landed and winds down.
const SPIN_DEG := 300.0
const RAIL_RISE := 0.06
const HOLO_SHADER := "res://art/shaders/holo.gdshader"
const RAIL_SHADER := "res://art/shaders/holo_rail.gdshader"
const CYAN := Color(0.3, 0.95, 1.0)
const SPARKS := [Color(0.3, 0.95, 1.0), Color(1.0, 1.0, 1.0), Color(1.0, 0.3, 0.62)]
## [timeline point, sound, volume, pitch, only when the chamber was loaded]
const SOUNDS := [[0.1, &"sz_hop", -7.0, 1.0, true], [0.12, &"sz_rail", -6.0, 1.0, false], [0.33, &"sz_roll_up", -5.0, 1.0, false],
	[0.64, &"sz_clunk", -3.0, 1.0, false], [0.68, &"sz_spin", -6.0, 1.0, false], [0.93, &"sz_ready", -6.0, 1.0, false]]

var _v: WeaponView
var _d := 1.0
var _s := 0.0
var _loaded := false
var _prev := Vector3.ZERO
var _roll := Basis.IDENTITY
var _landed := Quaternion.IDENTITY
var _spare_done := false
var _rail_mat: ShaderMaterial
var _spare_mat: ShaderMaterial
var _arrows: Array[StandardMaterial3D] = []
var _arrow_base := 2.0


func play(v: WeaponView, d: float) -> void:
	_v = v
	_d = d
	StrikeZoneView.register(v)
	var w := v.player.weapons if v.player else null
	_loaded = w != null and w.current == v.data and w.magazine() >= 1
	_rail_mat = _rail_material(v.part("RailHolo"))
	_spare_mat = _holo(v.part("SpareHolo"), Color(1.0, 0.45, 0.78))
	for i in StrikeZoneView.ARROWS:
		var mi := v.part("Arrow%d" % i) as MeshInstance3D
		if mi and mi.get_surface_override_material(0) is StandardMaterial3D:
			_arrows.append(mi.get_surface_override_material(0))
			_arrow_base = _arrows[-1].emission_energy_multiplier
	_roll = v.rest_transform("Ball").basis
	_prev = RAIL[0]
	v.drive(d, _step)


## A hologram material for `part` (made once and kept on the part).
static func _holo(part: Node3D, color: Color) -> ShaderMaterial:
	var mi := part as MeshInstance3D
	if mi == null:
		return null
	if mi.material_override is ShaderMaterial:
		return mi.material_override
	var m := ShaderMaterial.new()
	m.shader = load(HOLO_SHADER)
	m.set_shader_parameter("holo_color", color)
	var box := mi.mesh.get_aabb()
	m.set_shader_parameter("span", maxf(0.02, maxf(absf(box.position.y), absf(box.end.y))))
	mi.material_override = m
	return m


## The rail's channel shader (made once and kept on the part).
static func _rail_material(part: Node3D) -> ShaderMaterial:
	var mi := part as MeshInstance3D
	if mi == null:
		return null
	if mi.material_override is ShaderMaterial:
		return mi.material_override
	var m := ShaderMaterial.new()
	m.shader = load(RAIL_SHADER)
	m.set_shader_parameter("holo_color", CYAN)
	mi.material_override = m
	return m


## One frame of the reload: `k` is how far it has run (0-1).
func _step(k: float) -> void:
	if _v == null or not is_instance_valid(_v.model):
		return
	for snd in SOUNDS:
		if _s < float(snd[0]) and k >= float(snd[0]) and (_loaded or not snd[4]):
			Sfx.play(snd[1], snd[2], snd[3])
	if _s < ROLL.y and k >= ROLL.y:
		_land()
	if not _loaded and not _spare_done and k >= SPARE_IN.y:
		_spare_solid()
	_s = k
	_pose_root(k)
	_pose_kicker(k)
	_pose_rail(k)
	_pose_ball(k)
	_pose_spare(k)
	_pose_arrows(k)


func _pose_root(s: float) -> void:
	var show := _e(0.0, 0.16, s) * (1.0 - _e(0.84, 1.0, s))
	# The clunk of the landing jolts the gun down a touch.
	var jolt := sin(PI * _e(ROLL.y, ROLL.y + 0.08, s))
	var pos := ROOT_POS * show + Vector3(0.0, -0.006, 0.004) * jolt
	var rot := ROOT_ROT * show + Vector3(-3.5, 0.0, 1.5) * jolt
	_place(_v.part("Root"), _v.rest_transform("Root"), pos, rot)


## Cocked back out of the way, then home with a little overshoot.
func _pose_kicker(s: float) -> void:
	var back := KICK_BACK * _e(0.03, 0.14, s)
	var home := _e(0.86, 0.96, s)
	back = back * (1.0 - home) - 0.006 * sin(PI * home) * home
	_place(_v.part("Kicker"), _v.rest_transform("Kicker"), Vector3(0.0, 0.0, back), Vector3.ZERO)


## The rail curls up from below as it prints in (the hologram builds from its
## foot), and sinks away as it dissolves.
func _pose_rail(s: float) -> void:
	var rail := _v.part("RailHolo")
	if rail == null:
		return
	var grow := _e(RAIL_IN.x, RAIL_IN.y, s)
	var gone := _e(RAIL_OUT.x, RAIL_OUT.y, s)
	rail.visible = s > RAIL_IN.x and s < RAIL_OUT.y
	var drop := Vector3.DOWN * RAIL_RISE * ((1.0 - grow) + gone)
	_place(rail, _v.rest_transform("RailHolo"), drop, Vector3(0.0, 0.0, -6.0 * (1.0 - grow)))
	if _rail_mat:
		_rail_mat.set_shader_parameter("materialize", grow * (1.0 - gone))
		_rail_mat.set_shader_parameter("intensity", 0.9 + 0.5 * sin(PI * _e(ROLL.x, ROLL.y, s)))


func _pose_ball(s: float) -> void:
	var ball := _v.part("Ball")
	if ball == null:
		return
	var rest := _v.rest_transform("Ball")
	if s < HOP_OUT.y:
		# The old ball hops back out into the side return.
		ball.visible = _loaded
		var u := _e(HOP_OUT.x, HOP_OUT.y, s)
		ball.transform = Transform3D(StrikeZoneView.rolled(rest.basis, Vector3(-0.6, 0.0, 1.0).normalized(), TAU * u), StrikeZoneView.hop(1.0 - u))
		return
	if s < ROLL.x:
		ball.visible = false
		return
	ball.visible = true
	if s < ROLL.y:
		var at := StrikeZoneView.along(RAIL, _pace((s - ROLL.x) / (ROLL.y - ROLL.x)))
		_roll_to(at)
		ball.transform = Transform3D(_roll, at)
		return
	# In the chamber: a small bounce, and the finger-hole spin: it keeps
	# turning (now about its vertical), winding down, while it rights itself
	# so the holes come round to face the player.
	var b := _e(ROLL.y, ROLL.y + 0.08, s)
	var bounce := Vector3.UP * 0.009 * sin(PI * b) * (1.0 - b)
	var u := clampf((s - SPIN.x) / (SPIN.y - SPIN.x), 0.0, 1.0)
	var turn := deg_to_rad(SPIN_DEG) * (1.0 - (1.0 - u) * (1.0 - u) * (1.0 - u))
	var settled := Quaternion(Vector3.UP, -deg_to_rad(SPIN_DEG)) * rest.basis.get_rotation_quaternion()
	var q := Quaternion(Vector3.UP, turn) * _landed.slerp(settled, smoothstep(0.0, 1.0, u))
	ball.transform = Transform3D(Basis(q), rest.origin + bounce)


## Turns the rolling ball by the distance it moved on the rail (no slipping):
## about the axis across its path, square to the rail's lift under it.
func _roll_to(at: Vector3) -> void:
	var move := at - _prev
	_prev = at
	var dist := move.length()
	if dist < 0.00001:
		return
	var dir := move / dist
	var up := (Vector3.UP - dir * dir.dot(Vector3.UP))
	up = up.normalized() if up.length() > 0.01 else Vector3.BACK
	var axis := up.cross(dir).normalized()
	_roll = (Basis(axis, dist / BALL_R) * _roll).orthonormalized()


## The share of the rail covered at `t` (0-1 of the roll's time).
func _pace(t: float) -> float:
	if t < CREST_T:
		return _hermite(0.0, CREST_AT, PACE.x * CREST_T, PACE.y * CREST_T, t / CREST_T)
	var span := 1.0 - CREST_T
	return _hermite(CREST_AT, 1.0, PACE.y * span, PACE.z * span, (t - CREST_T) / span)


func _land() -> void:
	_landed = _roll.get_rotation_quaternion()
	var vent := _v.model.find_child("VentPoint", true, false) as Node3D
	if vent:
		_v.spark_burst(_v.model.global_transform.affine_inverse() * vent.global_position, Vector3.UP, SPARKS, 14, 1.0, 0.3, 0.009)
	var p := _v.owner as Player
	if p:
		p.add_shake(0.05)


func _pose_spare(s: float) -> void:
	var spare := _v.part("Spare")
	var holo := _v.part("SpareHolo")
	if spare == null:
		return
	if _loaded:
		spare.visible = s >= HOP_OUT.y
		if holo:
			holo.visible = false
		return
	spare.visible = _spare_done
	if holo == null:
		return
	holo.visible = s > SPARE_IN.x and not _spare_done
	var u := _e(SPARE_IN.x, SPARE_IN.y, s)
	holo.transform = _v.rest_transform("SpareHolo") * Transform3D(Basis(Vector3.UP, (1.0 - u) * PI), Vector3.UP * 0.02 * (1.0 - u))
	if _spare_mat:
		_spare_mat.set_shader_parameter("materialize", u)


func _spare_solid() -> void:
	_spare_done = true
	Sfx.play(&"reload_materialize", -6.0, randf_range(0.97, 1.05))
	_v.spark_burst(_v.rest_transform("Spare").origin, Vector3.UP, SPARKS, 10, 0.8, 0.3, 0.008)


## Dim while the balls change over, then chased back on one by one.
func _pose_arrows(s: float) -> void:
	for i in _arrows.size():
		var on := _e(0.86 + i * 0.03, 0.92 + i * 0.03, s)
		var k := lerpf(1.0, StrikeZoneView.ARROW_DIM, _e(0.02, 0.12, s)) * (1.0 - on) + on * (1.0 + 0.8 * sin(PI * on))
		_arrows[i].emission_energy_multiplier = _arrow_base * k


static func _place(node: Node3D, rest: Transform3D, offset: Vector3, rot_deg: Vector3) -> void:
	if node:
		node.transform = Transform3D(rest.basis * Basis.from_euler(rot_deg * (PI / 180.0)), rest.origin + offset)


## Smooth 0-1 ramp of `s` between `a` and `b`.
static func _e(a: float, b: float, s: float) -> float:
	return smoothstep(a, b, s)


## Cubic Hermite from `p0` to `p1` with end slopes `m0`, `m1` (per unit `t`).
static func _hermite(p0: float, p1: float, m0: float, m1: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * p0 + (t3 - 2.0 * t2 + t) * m0 + (-2.0 * t3 + 3.0 * t2) * p1 + (t3 - t2) * m1
