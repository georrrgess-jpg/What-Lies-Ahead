class_name RingmasterView
extends RefCounted
## Ringmaster viewmodel motion (WeaponData.view_script). The drum's three
## rings (RingOuter, RingMid, RingHub, children of Drum) turn on the axle,
## each its own way; every shot clicks them on a notch, and through the Main
## Event they spin up hard. The marquee bulbs are the gauges: the outer
## ring's twelve (BulbO0..11) fill with the Spotlight meter, the middle
## ring's eight (BulbM0..7) count the drum's rounds; once the meter is full
## the outer bulbs chase like a marquee, and through the Main Event every
## bulb chases. The gold tassel (Tassel) swings with the shots and the walk;
## the spotlight under the barrel's front (Spot) sweeps through the Main Event.
##
## Inspect: the rifle swings its drum face to you and the rings spin up
## counter-rotating, bulbs chasing; it swings across to its right flank,
## racks the charging handle, then tips its top hat with a spin. One time
## in CURTAIN_CHANCE it is the Curtain Call: two spotlights sweep across the
## rifle, every bulb flashes, a fanfare plays and the hat throws confetti.

const OUTER := 12
const MID := 8
## Degrees each ring clicks per shot, and their idle drift (degrees a second).
const CLICK := [7.5, -11.25, 15.0]
const DRIFT := [9.0, -14.0, 22.0]
## Their Main Event spin (degrees a second).
const EVENT_SPIN := [420.0, -620.0, 860.0]
const RINGS := ["RingOuter", "RingMid", "RingHub"]
## Marquee chase steps a second: meter full, and through the Main Event.
const CHASE_READY := 9.0
const CHASE_LIVE := 20.0
## The tassel's swing: spring, damping, kick per shot (degrees).
const TASSEL_SPRING := 70.0
const TASSEL_DAMP := 6.0
const TASSEL_KICK := 9.0
## Inspect.
const INSPECT_LENGTH := 3.6
const CURTAIN_CHANCE := 1.0 / 15.0
const CONFETTI := [Color(1.0, 0.84, 0.25), Color(0.93, 0.16, 0.3), Color(1.0, 0.97, 0.88), Color(0.35, 0.78, 1.0), Color(1.0, 0.45, 0.75)]
const BEAM_COLOR := Color(1.0, 0.93, 0.7, 0.26)
const INSPECT_POSES := [
	[0.0, Vector3(0.14, -0.14, -0.64), Vector3(2.0, 10.0, -6.0)],
	[0.14, Vector3(0.05, -0.08, -0.58), Vector3(8.0, -58.0, 12.0)],
	[0.36, Vector3(0.04, -0.07, -0.56), Vector3(12.0, -70.0, 14.0)],
	[0.56, Vector3(0.06, -0.08, -0.58), Vector3(6.0, 34.0, -10.0)],
	[0.72, Vector3(0.06, -0.1, -0.57), Vector3(30.0, 46.0, -6.0)],
	[0.87, Vector3(0.09, -0.12, -0.6), Vector3(12.0, 20.0, 0.0)],
	[1.0, Vector3(0.14, -0.15, -0.64), Vector3(4.0, 4.0, 0.0)],
]

var _rings: Array[Node3D] = []
var _outer: Array[Node3D] = []
var _mid: Array[Node3D] = []
var _tassel: Node3D
var _spot: Node3D
var _hat: Node3D
var _handle: Node3D
var _angles := [0.0, 0.0, 0.0]
var _targets := [0.0, 0.0, 0.0]
var _time := 0.0
var _swing := Vector2.ZERO
var _swing_v := Vector2.ZERO
var _curtain := false
var _fanfare := false
var _confetti := false
var _racked := false
var _beams: Array[MeshInstance3D] = []


func setup(v: WeaponView) -> void:
	register(v)
	for r in RINGS:
		_rings.append(v.part(r))
	_outer = bulbs(v, "BulbO", OUTER)
	_mid = bulbs(v, "BulbM", MID)
	_tassel = v.part("Tassel")
	_spot = v.part("Spot")
	_hat = v.part("Hat")
	_handle = v.part("Handle")


func fired(_v: WeaponView) -> void:
	for i in 3:
		_targets[i] += CLICK[i]
	_swing_v += Vector2(randf_range(-0.4, 0.4), 1.0) * TASSEL_KICK * 6.0


func event(_v: WeaponView, _event_name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	_time += delta
	var mode := mode_of(v)
	var live := mode != null and mode.live()
	_swing_tassel(v, delta, live)
	_pose_spot(v, live)
	if v.is_reloading() or v.is_inspecting():
		return
	var spin := mode.spin() if live else 0.0
	for i in 3:
		_targets[i] += (DRIFT[i] + (EVENT_SPIN[i] - DRIFT[i]) * spin) * delta
		_angles[i] = lerpf(_angles[i], _targets[i], 1.0 - exp(-16.0 * delta))
	pose_rings(v, _angles[0], _angles[1], _angles[2])
	_light(v, mode)


## The bulbs as gauges: the meter on the outer ring, the rounds on the middle
## ring; a marquee chase once the meter is full, all chasing in the Main Event.
func _light(v: WeaponView, mode: RingmasterMode) -> void:
	var meter := mode.spotlight if mode else 0.0
	var live := mode != null and mode.live()
	var w := weapons_of(v)
	var rounds := float(w.magazine()) / v.data.magazine_size if w else 1.0
	var step := int(_time * (CHASE_LIVE if live else CHASE_READY))
	for i in _outer.size():
		if _outer[i] == null:
			continue
		if live:
			_outer[i].visible = (i + step) % 2 == 0
		elif meter >= 1.0:
			_outer[i].visible = (i + step) % 3 != 0
		else:
			_outer[i].visible = i < roundi(meter * OUTER)
	for i in _mid.size():
		if _mid[i] == null:
			continue
		if live:
			_mid[i].visible = (i + step) % 2 == 1
		else:
			_mid[i].visible = i < ceili(rounds * MID - 0.01)


## A damped spring kicked by the shots and dragged by the walk.
func _swing_tassel(v: WeaponView, delta: float, live: bool) -> void:
	if _tassel == null:
		return
	var p := v.player
	var drag := Vector2.ZERO
	if p:
		var vel := p.velocity
		drag = Vector2(vel.x, vel.z).rotated(p.rotation.y) * 1.6
	if live:
		drag.x += sin(_time * 9.0) * 6.0
	_swing_v += (-_swing * TASSEL_SPRING - _swing_v * TASSEL_DAMP + Vector2(drag.x, -drag.y) * 4.0) * delta
	_swing += _swing_v * delta
	_swing = _swing.clamp(Vector2(-35.0, -35.0), Vector2(35.0, 35.0))
	var rest := v.rest_transform("Tassel")
	_tassel.transform = rest * Transform3D(Basis.from_euler(Vector3(deg_to_rad(_swing.y), 0.0, deg_to_rad(_swing.x))), Vector3.ZERO)


## The little spotlight under the barrel sweeps side to side through the Main Event.
func _pose_spot(v: WeaponView, live: bool) -> void:
	if _spot == null:
		return
	var yaw := sin(_time * 5.0) * 18.0 if live else 0.0
	_spot.transform = v.rest_transform("Spot") * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), Vector3.ZERO)


# --- inspect ---------------------------------------------------------------------

func inspect_length() -> float:
	return INSPECT_LENGTH


func inspect_poses() -> Array:
	return INSPECT_POSES


func inspect_start(v: WeaponView) -> void:
	inspect_end(v)
	_curtain = v.inspect_rare(CURTAIN_CHANCE)
	_fanfare = false
	_confetti = false
	_racked = false
	if _curtain:
		_make_beams(v)


## The rings spin up counter-rotating, the handle racks, the hat tips and spins.
func inspect(v: WeaponView, t: float) -> void:
	var spin := WeaponInspect.window(t, 0.45, 1.6)
	var settle := WeaponInspect.window(t, 1.6, 2.4)
	var turn := spin * 2.0 + settle * 0.6
	pose_rings(v, _angles[0] + 360.0 * turn, _angles[1] - 540.0 * turn, _angles[2] + 720.0 * turn)
	var step := int(t * (CHASE_LIVE if _curtain else CHASE_READY * 1.5))
	var flash := _curtain and t > 0.6 and int(t * 6.0) % 2 == 0
	for i in _outer.size():
		if _outer[i]:
			_outer[i].visible = flash or (i + step) % 3 != 0
	for i in _mid.size():
		if _mid[i]:
			_mid[i].visible = flash or (i + step) % 2 == 0
	# The charging handle: back and home with a snap.
	if _handle:
		var pull := WeaponInspect.window(t, 1.75, 1.88) * (1.0 - WeaponInspect.window(t, 1.92, 1.98))
		_handle.transform = v.rest_transform("Handle") * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.045 * pull))
		if t >= 1.8 and not _racked:
			_racked = true
			Sfx.play(&"rm_rack", -5.0)
	# The hat tips (about its brim's top edge) and spins a full turn about the bore.
	if _hat:
		var tip := WeaponInspect.hump(t, 2.3, 3.1)
		var whirl := WeaponInspect.window(t, 2.35, 2.95) * TAU
		var lift := Vector3(0.0, 0.012 * tip, -0.01 * tip)
		var b := Basis(Vector3.RIGHT, deg_to_rad(-28.0 * tip)) * Basis(Vector3.FORWARD, whirl)
		_hat.transform = v.rest_transform("Hat") * Transform3D(b, lift)
		if t >= 2.35 and not _confetti:
			_confetti = true
			Sfx.play(&"rm_hat", -6.0)
			if _curtain:
				var at := WeaponInspect.in_model(v, _hat) + Vector3(0.0, 0.03, -0.05)
				FxBurst.spawn(v.model, at, Vector3(0, 1, -0.4), CONFETTI, 36, 0.9, 1.1, 0.006, 70.0, Vector3(0, -0.8, 0), WeaponView._burst_mesh())
	if _curtain:
		if t >= 0.5 and not _fanfare:
			_fanfare = true
			Sfx.play(&"rm_fanfare", -6.0)
		_sweep_beams(t)


func inspect_end(v: WeaponView) -> void:
	_curtain = false
	for b in _beams:
		if is_instance_valid(b):
			b.queue_free()
	_beams.clear()
	for part in ["Hat", "Handle"]:
		var node := v.part(part)
		if node:
			node.transform = v.rest_transform(part)


## Two soft spotlight cones from above the rifle for the Curtain Call.
func _make_beams(v: WeaponView) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = BEAM_COLOR
	var cone := CylinderMesh.new()
	cone.top_radius = 0.004
	cone.bottom_radius = 0.085
	cone.height = 0.6
	cone.radial_segments = 24
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var layers := 1
	var sample := v.part("Drum") as VisualInstance3D
	if sample:
		layers = sample.layers
	for i in 2:
		var b := MeshInstance3D.new()
		b.name = "CurtainBeam%d" % i
		b.mesh = cone
		b.material_override = m
		b.layers = layers
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.visible = false
		v.model.add_child(b)
		_beams.append(b)


## The cones' apexes stay high left and high right; they swing across the rifle.
func _sweep_beams(t: float) -> void:
	var on := WeaponInspect.window(t, 0.35, 0.6) * (1.0 - WeaponInspect.window(t, 3.0, 3.4))
	for i in _beams.size():
		var b := _beams[i]
		if not is_instance_valid(b):
			continue
		b.visible = on > 0.01
		var side := -1.0 if i == 0 else 1.0
		var apex := Vector3(side * 0.32, 0.42, -0.1)
		var sweep := sin(t * 1.7 + i * 2.1) * 0.16
		var aim := Vector3(sweep * side, -0.02, -0.15 + 0.08 * cos(t * 1.3 + i))
		var axis := (apex - aim).normalized()
		var basis := Basis(Quaternion(Vector3.UP, axis))
		b.transform = Transform3D(basis.scaled(Vector3(1.0, 1.0, 1.0) * maxf(0.05, on)), (apex + aim) * 0.5)


# --- shared with the reload -----------------------------------------------------

static func register(v: WeaponView) -> void:
	for part in ["Drum", "DrumHolo", "Handle", "Hat", "Tassel", "Spot"] + RINGS:
		v.register_part(part)
	for i in OUTER:
		v.register_part("BulbO%d" % i)
	for i in MID:
		v.register_part("BulbM%d" % i)


static func bulbs(v: WeaponView, prefix: String, count: int) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i in count:
		out.append(v.part("%s%d" % [prefix, i]))
	return out


## Turns the three rings to these angles (degrees about the axle) from rest.
static func pose_rings(v: WeaponView, outer: float, mid: float, hub: float) -> void:
	var angles := [outer, mid, hub]
	for i in 3:
		var node := v.part(RINGS[i])
		if node:
			node.transform = v.rest_transform(RINGS[i]) * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(angles[i])), Vector3.ZERO)


## The held weapon's controller when the view shows that weapon (null in previews).
static func weapons_of(v: WeaponView) -> WeaponController:
	if v.player and v.player.weapons and v.player.weapons.current == v.data:
		return v.player.weapons
	return null


static func mode_of(v: WeaponView) -> RingmasterMode:
	var w := weapons_of(v)
	return w.mode as RingmasterMode if w else null
