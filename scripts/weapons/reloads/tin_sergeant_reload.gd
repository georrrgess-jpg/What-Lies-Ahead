extends RefCounted
## Tin Sergeant "fall in": the gun tips its deck and left flank to the eye
## and the big key winds itself two turns, ratcheting. The soldier at the
## hatch (if any) ducks into the chest, and a column of three hologram
## soldiers marches in single file across the deck from the left edge: each
## one stamps to a halt over the hatch, about-turns to face front and drops
## in (the hatch flaps, a clunk and a spark). The third stays: he turns solid
## in the hatch with a flare and springs to attention as the gun comes back.
##
## Every part is posed each frame from one timeline (WeaponView.drive) on
## smootherstep curves; the one hologram soldier (CellHolo, on the Soldier's
## pivot) plays all three marchers.

const ROOT_POS := Vector3(-0.04, 0.03, 0.06)
const ROOT_ROT := Vector3(24.0, 16.0, 20.0)
const TURNS := 2.0
const WIND_START := 0.14
const WIND_END := 0.84
## The marchers' trips (fractions of the reload) and where each starts and
## halts, relative to the soldier's pivot in the hatch (model space).
const TRIPS: Array[float] = [0.18, 0.4, 0.62, 0.84]
const START := Vector3(-0.085, 0.057, 0.008)
const HALT := Vector3(0.0, 0.057, 0.0)
const SOLID_AT := 0.84
const HATCH_FLAP := -30.0
const SPARKS := [Color(1.0, 0.82, 0.23), Color(0.3, 0.5, 1.0), Color(0.89, 0.27, 0.23), Color(1.0, 1.0, 1.0)]

var _v: WeaponView
var _d := 1.0
var _had := false
var _clicks := 0
var _landed := 0
var _solid := false


func play(v: WeaponView, d: float) -> void:
	_v = v
	_d = d
	for part in ["Hatch", "Soldier", "SoldierArm", "Key", "CellHolo"]:
		v.register_part(part)
	_had = v.player != null and v.player.weapons != null and v.player.weapons.magazine() > 0
	v.glow_ramp(0.03, 0.14, d, 1.0, 0.3)
	for k in 3:
		v.holo_build("CellHolo", TRIPS[k], TRIPS[k] + 0.05, d)
	v.solidify("CellHolo", "Soldier", SOLID_AT, d)
	v.at(0.02, d, func(): Sfx.play(&"ts_wind", -8.0, 1.1))
	v.drive(d, _step)


## One frame of the reload: `s` is how far it has run (0-1).
func _step(s: float) -> void:
	if _v == null or not is_instance_valid(_v.model):
		return
	var show := _e(0.0, 0.12, s) * (1.0 - _e(0.86, 1.0, s))
	_place(_v.part("Root"), _v.rest_transform("Root"), ROOT_POS * show, ROOT_ROT * show)
	var turns := TURNS * _e(WIND_START, WIND_END, s)
	_place(_v.part("Key"), _v.rest_transform("Key"), Vector3.ZERO, Vector3(-360.0 * turns, 0.0, 0.0))
	while _clicks < int(turns * 4.0):
		_clicks += 1
		Sfx.play(&"ts_tick", -8.0, 0.9 + 0.05 * _clicks)
	_pose_soldier(s)
	_pose_marcher(s)
	_pose_hatch(s)


## The loaded soldier ducks into the chest; the new one, once solid, springs
## up to attention.
func _pose_soldier(s: float) -> void:
	var soldier := _v.part("Soldier")
	if soldier == null:
		return
	var rest := _v.rest_transform("Soldier")
	if s < SOLID_AT:
		var duck := _e(0.06, 0.16, s)
		soldier.visible = _had and duck < 0.99
		soldier.transform = rest * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.05 * duck, 0.0))
		return
	if not _solid:
		_solid = true
		Sfx.play(&"ts_land", -5.0, 1.3)
		var p := _v.owner as Player
		if p:
			p.add_shake(0.04)
		_spark(16)
	soldier.visible = true
	var u := clampf((s - SOLID_AT) / 0.12, 0.0, 1.0)
	var pop := 0.012 * sin(PI * u) * (1.0 - u * 0.5)
	soldier.transform = rest * Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0 + 0.12 * sin(PI * u), 1.0)), Vector3(0.0, pop, 0.0))


## The hologram marcher: in from the left edge with a stiff stamping march,
## a halt, an about-turn to face front and a drop into the hatch.
func _pose_marcher(s: float) -> void:
	var holo := _v.part("CellHolo")
	if holo == null or s < TRIPS[0] or s >= SOLID_AT:
		return
	var k := 0
	while k < 2 and s >= TRIPS[k + 1]:
		k += 1
	var u := (s - TRIPS[k]) / (TRIPS[k + 1] - TRIPS[k])
	var walk := _e(0.08, 0.66, u)
	var at := START.lerp(HALT, walk)
	var steps := u * _d * (TRIPS[k + 1] - TRIPS[k]) * 7.0
	var stamp := absf(sin(steps * PI)) * (1.0 - _e(0.6, 0.7, u))
	at.y += 0.004 * stamp
	var face := lerpf(-90.0, 0.0, _e(0.68, 0.82, u))
	var drop := _e(0.84, 1.0, u)
	at.y -= HALT.y * drop
	var roll := 5.0 * sin(steps * PI) * (1.0 - _e(0.6, 0.7, u))
	holo.visible = u < 0.995 or k == 2
	holo.transform = _v.rest_transform("CellHolo") * Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(face), deg_to_rad(roll))), at)
	if drop >= 0.99 and _landed <= k and k < 2:
		_landed = k + 1
		Sfx.play(&"ts_land", -9.0, 1.4 + 0.1 * k)
		_spark(8)


## The hatch flaps as each marcher drops through it.
func _pose_hatch(s: float) -> void:
	var flap := 0.0
	for k in 3:
		var a := lerpf(TRIPS[k], TRIPS[k + 1], 0.84)
		var b := TRIPS[k + 1] + 0.03
		flap = maxf(flap, sin(PI * clampf((s - a) / (b - a), 0.0, 1.0)))
	_place(_v.part("Hatch"), _v.rest_transform("Hatch"), Vector3.ZERO, Vector3(0.0, 0.0, HATCH_FLAP * flap))


func _spark(amount: int) -> void:
	var a := _v.model.find_child("EjectPoint", true, false) as Node3D
	if a:
		_v.spark_burst(_v.model.global_transform.affine_inverse() * a.global_position, Vector3.UP, SPARKS, amount, 0.8, 0.35, 0.006)


## Smootherstep of s between a and b (zero speed and acceleration at both ends).
static func _e(a: float, b: float, s: float) -> float:
	var t := clampf((s - a) / (b - a), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _place(node: Node3D, rest: Transform3D, offset: Vector3, rot_deg: Vector3) -> void:
	if node:
		node.transform = Transform3D(rest.basis * Basis.from_euler(rot_deg * (PI / 180.0)), rest.origin + offset)
