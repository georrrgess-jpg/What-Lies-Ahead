extends RefCounted
## Popcorn Popper "fresh batch": the gun rolls over to show the kettle; the
## lid unlatches and flips open on its hinge with a bounce and a puff of
## steam; a hologram scoop prints in, slides over the kettle and tips,
## shaking a stream of kernels in (the kernels heap up); it tips back and
## fades; a hologram butter pump drops in and pumps twice, drizzling a
## wiggling ribbon of butter over them; the lid slams shut with a clang and
## the kettle flares; then the fresh batch pops: the dome fills layer by
## layer from the bottom, each layer bouncing in with a burst of flakes
## while the lid chatters, and the gun rolls back.
##
## Every part is posed each frame from one timeline (WeaponView.drive) on
## smooth curves (smootherstep blends, an overshoot that settles for the
## lid and the popcorn, an accelerating slam), so moves flow into each
## other with no stops between keys. The dome shows the old popcorn until
## the fresh batch pops, and is full exactly when the reload ends.

const ROOT_POS := Vector3(-0.012, 0.022, 0.0)
const ROOT_ROT := Vector3(11.0, -6.0, -18.0)
const LID_OPEN := 118.0
## The scoop's way in (offset from its home, model space) and its pour tilt.
const SCOOP_FROM := Vector3(-0.07, 0.05, 0.02)
const SCOOP_TILT := -72.0
const BUTTER_FROM := Vector3(0.05, 0.06, -0.01)
const PUMP_DIP := 0.007
## The fresh popcorn pops in over this part of the timeline.
const POP_START := 0.81
const POP_END := 0.95
const KERNELS := [Color(1.0, 0.8, 0.3), Color(1.0, 0.68, 0.2), Color(1.0, 0.92, 0.55)]
const BUTTER := [Color(1.0, 0.86, 0.32), Color(1.0, 0.95, 0.6)]
const STEAM := [Color(1.0, 1.0, 1.0, 0.85), Color(0.92, 0.94, 1.0, 0.8)]
const FLAKES := [Color(1.0, 0.98, 0.9), Color(1.0, 0.92, 0.65), Color(1.0, 0.84, 0.4)]
## [timeline point, sound, volume, pitch]
const SOUNDS := [[0.07, &"pcp_lid_open", -5.0, 1.0], [0.2, &"pcp_holo", -9.0, 1.0], [0.33, &"pcp_scoop", -5.0, 1.0],
	[0.6, &"pcp_holo", -9.0, 1.15], [0.64, &"pcp_pump", -6.0, 1.0], [0.7, &"pcp_pump", -6.0, 1.1],
	[0.795, &"pcp_lid_shut", -3.0, 1.0], [0.83, &"pcp_popping", -4.0, 1.0]]
## Moments (timeline) for one-shot bursts: [point, kind].
const BURSTS := [[0.13, &"steam"], [0.36, &"kernels"], [0.41, &"kernels"], [0.46, &"kernels"], [0.51, &"kernels"],
	[0.655, &"butter"], [0.69, &"butter"], [0.72, &"butter"], [0.8, &"steam"]]

var _v: WeaponView
var _d := 1.0
var _s := 0.0
var _start_fill := 8.0
var _full_fill := 8.0
var _layers: Array[Node3D] = []
var _popped := 0
var _eject := Vector3.ZERO
var _dome := Vector3.ZERO
var _pour := Vector3.ZERO
var _nozzle := Vector3.ZERO


func play(v: WeaponView, d: float) -> void:
	_v = v
	_d = d
	PopcornPopperView.register(v)
	PopcornPopperView.holo_materials(v)
	_layers = PopcornPopperView.layers(v)
	var mag := v.data.magazine_size
	var full := v.data.magazine_size
	var w := PopcornPopperView.weapons_of(v)
	if w:
		mag = w.magazine()
		full = mini(v.data.magazine_size, mag + w.reserve())
	_start_fill = float(mag) / v.data.magazine_size * PopcornPopperView.LAYERS
	_full_fill = float(full) / v.data.magazine_size * PopcornPopperView.LAYERS
	_popped = ceili(_start_fill)
	_eject = PopcornPopperView.model_point(v, "EjectPoint")
	_dome = PopcornPopperView.model_point(v, "DomePoint")
	_pour = v.rest_transform("PourHolo").origin
	_nozzle = v.rest_transform("ButterHolo").origin
	v.glow_ramp(0.1, 0.22, d, 1.0, 0.25)
	v.glow_ramp(0.79, 0.85, d, 0.25, 2.2)
	v.glow_ramp(0.85, 0.99, d, 2.2, 1.0)
	v.drive(d, _step)


## One frame of the reload: `s` is how far it has run (0-1).
func _step(s: float) -> void:
	if _v == null or not is_instance_valid(_v.model):
		return
	for snd in SOUNDS:
		if _s < float(snd[0]) and s >= float(snd[0]):
			Sfx.play(snd[1], snd[2], snd[3])
	for b in BURSTS:
		if _s < float(b[0]) and s >= float(b[0]):
			_burst(b[1])
	_s = s
	var show := _e(0.0, 0.13, s) * (1.0 - _e(0.88, 1.0, s))
	_place(_v.part("Root"), _v.rest_transform("Root"), ROOT_POS * show, ROOT_ROT * show)
	PopcornPopperView.pose_lid(_v, _lid(s))
	_pose_kernels(s)
	_pose_scoop(s)
	_pose_butter(s)
	_pose_popcorn(s)


## The lid (degrees open): a latch hop, the flip open with an overshoot that
## settles, then the slam (speeding up into the rim) and a small rebound,
## and the chatter of the popping batch.
func _lid(s: float) -> float:
	var hop := 6.0 * sin(PI * _e(0.03, 0.08, s))
	var open := LID_OPEN * _overshoot(_e(0.07, 0.27, s))
	var shut := _slam(clampf((s - 0.74) / 0.055, 0.0, 1.0))
	var rebound := 7.0 * sin(PI * clampf((s - 0.795) / 0.04, 0.0, 1.0)) * (1.0 - clampf((s - 0.795) / 0.04, 0.0, 1.0) * 0.5)
	var chatter := 3.5 * absf(sin((s - POP_START) * _d * 40.0)) * _e(POP_START, POP_START + 0.02, s) * (1.0 - _e(POP_END - 0.02, POP_END + 0.02, s))
	return hop * (1.0 - _e(0.07, 0.1, s)) + open * (1.0 - shut) + rebound + chatter


## The kernels in the kettle: a few left, then heaping up as the scoop pours.
func _pose_kernels(s: float) -> void:
	var k := _v.part("Kernels")
	if k == null:
		return
	var heap := lerpf(0.35, 1.0, _e(0.36, 0.56, s))
	var rest := _v.rest_transform("Kernels")
	k.transform = Transform3D(rest.basis.scaled(Vector3(lerpf(0.7, 1.0, heap), heap, lerpf(0.7, 1.0, heap))), rest.origin)


## The scoop prints in off to the left, glides over the kettle, tips and
## shakes the kernels in, tips back and glides out as it fades.
func _pose_scoop(s: float) -> void:
	var scoop := _v.part("ScoopHolo")
	var pour := _v.part("PourHolo")
	PopcornPopperView.set_holo(_v, "ScoopHolo", _e(0.17, 0.26, s) * (1.0 - _e(0.57, 0.66, s)))
	if scoop:
		var away := 1.0 - _e(0.19, 0.33, s) + _e(0.55, 0.66, s)
		var tilt := SCOOP_TILT * _e(0.32, 0.39, s) * (1.0 - _e(0.51, 0.58, s))
		var shake := 4.0 * sin(s * _d * 34.0) * _e(0.38, 0.41, s) * (1.0 - _e(0.48, 0.51, s))
		var rest := _v.rest_transform("ScoopHolo")
		scoop.transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(tilt + shake)) * rest.basis, rest.origin + SCOOP_FROM * away)
	# The stream runs from the tipped lip into the kettle, then thins away from the top.
	var flow := _e(0.35, 0.38, s) * (1.0 - _e(0.5, 0.54, s))
	PopcornPopperView.set_holo(_v, "PourHolo", flow)
	if pour:
		var rest := _v.rest_transform("PourHolo")
		var sway := Basis(Vector3.BACK, 0.12 * sin(s * _d * 22.0))
		pour.transform = Transform3D(sway * rest.basis.scaled(Vector3(lerpf(0.6, 1.0, flow), maxf(0.01, flow), lerpf(0.6, 1.0, flow))), rest.origin)


## The butter pump drops in over the kettle, dips twice (a drizzle ribbon
## wiggling down into the kernels) and lifts away as it fades.
func _pose_butter(s: float) -> void:
	var pump := _v.part("ButterHolo")
	var drizzle := _v.part("DrizzleHolo")
	PopcornPopperView.set_holo(_v, "ButterHolo", _e(0.57, 0.63, s) * (1.0 - _e(0.73, 0.78, s)))
	var away := 1.0 - _e(0.57, 0.64, s) + _e(0.73, 0.79, s)
	var dip := PUMP_DIP * (sin(PI * _e(0.635, 0.675, s)) + sin(PI * _e(0.69, 0.73, s)))
	var at := Vector3.DOWN * dip + BUTTER_FROM * away
	if pump:
		var rest := _v.rest_transform("ButterHolo")
		pump.transform = Transform3D(rest.basis, rest.origin + at)
	var flow := _e(0.63, 0.66, s) * (1.0 - _e(0.71, 0.745, s))
	PopcornPopperView.set_holo(_v, "DrizzleHolo", flow)
	if drizzle:
		var rest := _v.rest_transform("DrizzleHolo")
		var wiggle := Basis(Vector3.UP, 0.5 * sin(s * _d * 18.0)) * Basis(Vector3.BACK, 0.18 * sin(s * _d * 11.0))
		drizzle.transform = Transform3D(wiggle * rest.basis.scaled(Vector3(1.0, maxf(0.01, flow), 1.0)), rest.origin + at)


## The dome: the old popcorn until the batch pops, then each fresh layer
## bounces in from the bottom with a burst of flakes. Each layer settles on
## exactly the pose the view gives it, so the hand-back is seamless.
func _pose_popcorn(s: float) -> void:
	if s >= 1.0:
		PopcornPopperView.show_popcorn(_layers, _v, _full_fill, 0.0)
		return
	var u := clampf((s - POP_START) / (POP_END - POP_START), 0.0, 1.0)
	var fill := lerpf(_start_fill, _full_fill, u)
	for i in _layers.size():
		var layer := _layers[i]
		if layer == null:
			continue
		var had := clampf(_start_fill - i, 0.0, 1.0)
		var goal := clampf(_full_fill - i, 0.0, 1.0)
		var grow := clampf((clampf(fill - i, 0.0, 1.0) - had) / maxf(0.001, goal - had), 0.0, 1.0) if goal > had else 0.0
		var rest := _v.rest_transform("PopLayer%d" % i)
		var size: Vector3
		if had > 0.0:
			size = _layer_size(lerpf(had, goal, _overshoot(grow)))
		else:
			size = _layer_size(goal) * _overshoot(grow)
		layer.visible = size.y > 0.001
		layer.transform = Transform3D(rest.basis.scaled(size), rest.origin)
		if grow > 0.0 and i >= _popped:
			_popped = i + 1
			_v.spark_burst(rest.origin + Vector3.UP * 0.01, Vector3.UP, FLAKES, 5, 0.7, 0.3, 0.005)
			Sfx.play(&"pcp_pop", -10.0, 1.0 + 0.06 * i)


## A layer's scale at fill `k` (0-1), as PopcornPopperView.show_popcorn draws it.
static func _layer_size(k: float) -> Vector3:
	if k <= 0.0:
		return Vector3.ZERO
	var w := lerpf(0.55, 1.0, k)
	return Vector3(w, lerpf(0.4, 1.0, k), w)


func _burst(kind: StringName) -> void:
	match kind:
		&"steam":
			_v.spark_burst(_eject, Vector3.UP, STEAM, 7, 0.7, 0.55, 0.007)
		&"kernels":
			_v.spark_burst(_pour, Vector3.DOWN, KERNELS, 5, 0.5, 0.25, 0.005)
		&"butter":
			_v.spark_burst(_nozzle, Vector3.DOWN, BUTTER, 3, 0.4, 0.3, 0.004)


## 0 to 1 with a springy overshoot that settles (zero speed at both ends
## when fed a smootherstep).
static func _overshoot(u: float) -> float:
	if u <= 0.0:
		return 0.0
	if u >= 1.0:
		return 1.0
	return 1.0 - pow(1.0 - u, 3.0) * cos(u * PI * 2.5)


## The slam: it speeds up as it falls (no ease at the rim: it lands).
static func _slam(u: float) -> float:
	return u * u * (2.0 - u) if u < 1.0 else 1.0


## Smootherstep of s between a and b (zero speed and acceleration at both ends).
static func _e(a: float, b: float, s: float) -> float:
	var t := clampf((s - a) / (b - a), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func _place(node: Node3D, rest: Transform3D, offset: Vector3, rot_deg: Vector3) -> void:
	if node:
		node.transform = Transform3D(rest.basis * Basis.from_euler(rot_deg * (PI / 180.0)), rest.origin + offset)
