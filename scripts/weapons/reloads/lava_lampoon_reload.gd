extends RefCounted
## Lava Lampoon "groove flip": the gun rolls over to show the lamp; the cap
## pops; the lamp unscrews and lifts out on a spinning teal hologram ring;
## it does a slow cartwheel upside down while the spent wax sinks into one
## lump; the lump splits into fresh blobs as it carries on round and rights
## itself; it drops back and twist-locks into the socket with a clunk, and a
## ripple of glow runs from the base to the cap.
##
## Every part is posed each frame from one timeline (WeaponView.drive) on
## smooth curves, so moves blend into each other with no stops between keys.
## Active reload (LavaLampoonMode): while the lamp is upside down the ring
## burns magenta and "TAP R" shows over it. A press in time skips the rest of
## the flip: the lamp snaps round in LavaLampoonMode.SKIP_TIME, on a curve
## that keeps its speed going in and out, and "GROOVY!" pops; then the
## twist-lock plays as usual. A press too early flickers the ring grey.

const LIFT := Vector3(-0.042, 0.14, 0.012)
const UNSCREW_RISE := 0.012
## Turns of the lamp: out (unscrewing), while it hovers, and back in.
const UNSCREW_DEG := -540.0
const HOVER_DEG := -120.0
## The flip turns about the glass's middle (model space, above the lamp's pivot).
const FLIP_CENTRE := Vector3(0.0, 0.05, 0.0)
const ROOT_POS := Vector3(-0.01, 0.025, 0.0)
const ROOT_ROT := Vector3(9.0, -7.0, -17.0)
const RING_SPIN := 520.0
const HOT := Color(1.0, 0.25, 0.62)
const GOOD := Color(1.0, 0.9, 0.35)
const MISS := Color(0.55, 0.55, 0.62)
const SPARKS := [Color(1.0, 0.86, 0.3), Color(1.0, 0.3, 0.6), Color(1.0, 1.0, 0.85), Color(0.3, 1.0, 0.92)]
## [timeline point, sound, volume, pitch]
const SOUNDS := [[0.11, &"weap_lava_unscrew", -6.0, 1.0], [0.24, &"weap_lava_lift", -7.0, 1.0], [0.38, &"weap_lava_flip", -5.0, 1.0],
	[0.5, &"weap_lava_glug", -6.0, 1.0], [0.67, &"weap_lava_flip", -6.0, 1.15], [0.8, &"weap_lava_unscrew", -6.0, 1.25],
	[0.93, &"weap_lava_ripple", -6.0, 1.0]]

var _v: WeaponView
var _d := 1.0
var _s := 0.0
var _start_blobs := 10.0
var _full_blobs := 10.0
var _skip := -1.0
var _skip_from := 0.0
var _skip_left := 0.0
var _missed := 0.0
## A press came too early: the one try of this reload is spent.
var _spent := false
var _groovy := 0.0
var _locked := false
var _mat: ShaderMaterial
var _pips: Array[Node3D] = []
var _label: Label3D


func play(v: WeaponView, d: float) -> void:
	_v = v
	_d = d
	LavaLampoonView.register(v)
	_mat = LavaLampoonView.glass_material(v)
	for i in LavaLampoonView.PIPS:
		_pips.append(v.part("Pip%d" % i))
	if v.has_meta(LavaLampoonMode.SKIP_META):
		v.remove_meta(LavaLampoonMode.SKIP_META)
	var mag := v.data.magazine_size
	var full := v.data.magazine_size
	var w := LavaLampoonView.weapons_of(v)
	if w:
		mag = w.magazine()
		full = mini(v.data.magazine_size, mag + w.reserve())
	_start_blobs = mag / LavaLampoonView.ROUNDS_PER_BLOB
	_full_blobs = full / LavaLampoonView.ROUNDS_PER_BLOB
	_label = v.model.find_child(LavaLampoonView.PROMPT, false, false) as Label3D
	var ring := v.part("LampRingHolo")
	if ring and ring is MeshInstance3D:
		var holo := (ring as MeshInstance3D).material_override as ShaderMaterial
		if holo:
			holo.set_shader_parameter("materialize", 0.0)
	v.drive(d, _step)


## One frame of the reload: `k` is how far the reload has run (0-1).
func _step(k: float) -> void:
	if _v == null or not is_instance_valid(_v.model):
		return
	var s := _timeline(k)
	for snd in SOUNDS:
		if _s < float(snd[0]) and s >= float(snd[0]):
			Sfx.play(snd[1], snd[2], snd[3])
	if not _locked and s >= 0.915:
		_lock()
	_s = s
	_pose(s, k)


## Reload time `k` to the animation's timeline: the same until a skip, then
## a quick run to the twist-lock and the rest at normal speed.
func _timeline(k: float) -> float:
	if k >= 1.0:
		return 1.0
	if _skip < 0.0 and _v.has_meta(LavaLampoonMode.SKIP_META):
		var p := float(_v.get_meta(LavaLampoonMode.SKIP_META)[0])
		_v.remove_meta(LavaLampoonMode.SKIP_META)
		if p < 0.0:
			_missed = 1.0
			_spent = true
		else:
			_skip = p
			_skip_from = _s
			_skip_left = LavaLampoonMode.SKIP_TIME + (1.0 - LavaLampoonMode.LOCK_AT) * _d
			_groovy = 1.0
			_spark("LampGlass", 18)
	if _skip < 0.0:
		return k
	var r := (k - _skip) / maxf(0.001, 1.0 - _skip) * _skip_left
	var fast := LavaLampoonMode.SKIP_TIME
	if r >= fast:
		return minf(1.0, LavaLampoonMode.LOCK_AT + (r - fast) / _d)
	return _hermite(_skip_from, LavaLampoonMode.LOCK_AT, fast / _d, r / fast)


func _pose(s: float, k: float) -> void:
	var v := _v
	# The gun rolls over to show the lamp and back.
	var show := _e(0.0, 0.14, s) * (1.0 - _e(0.86, 1.0, s))
	_place(v.part("Root"), v.rest_transform("Root"), ROOT_POS * show, ROOT_ROT * show)
	# The lamp: unscrew and lift out, hover, the cartwheel, drop and screw home.
	var unscrew := _e(0.1, 0.3, s)
	var lift := _e(0.2, 0.42, s)
	var drop := _drop(s)
	var hover := _e(0.38, 0.46, s) * (1.0 - _e(0.76, 0.82, s))
	var turn := UNSCREW_DEG * _e(0.1, 0.34, s) + HOVER_DEG * _e(0.3, 0.8, s) - (UNSCREW_DEG + HOVER_DEG) * _e(0.8, 0.92, s)
	var flip := 180.0 * _e(0.36, 0.6, s) + 180.0 * _e(0.66, 0.8, s)
	var bob := Vector3(0.0, sin(s * _d * 5.0) * 0.004, 0.0) * hover
	var base := (Vector3.UP * UNSCREW_RISE * unscrew + LIFT * lift) * (1.0 - drop) + bob + Vector3.DOWN * _seat_bump(s)
	var lamp := v.part("Lamp")
	if lamp:
		var rest := v.rest_transform("Lamp")
		var spin := Basis(Vector3.UP, deg_to_rad(turn))
		var cartwheel := Transform3D(Basis(Vector3.BACK, deg_to_rad(flip)), Vector3.ZERO)
		var about := Transform3D(Basis.IDENTITY, FLIP_CENTRE) * cartwheel * Transform3D(Basis.IDENTITY, -FLIP_CENTRE)
		lamp.transform = Transform3D(Basis.IDENTITY, rest.origin + base) * about * Transform3D(rest.basis * spin, Vector3.ZERO)
	_pose_cap(s)
	_pose_ring(s, base)
	_pose_prompt(s)
	_pose_wax(s, k)


## The cap pops up with a tilt and bounces back; it dings once more at the lock.
func _pose_cap(s: float) -> void:
	var cap := _v.part("LampCap")
	if cap == null:
		return
	var u := _e(0.02, 0.22, s)
	var pop := sin(PI * u) * (1.0 - 0.55 * u)
	var ding := sin(PI * _e(0.92, 0.98, s)) * 0.3
	var rest := _v.rest_transform("LampCap")
	_place(cap, rest, Vector3(-0.004, 0.017, 0.0) * pop + Vector3.UP * 0.012 * ding, Vector3(0.0, 0.0, 32.0) * pop + Vector3(0.0, 0.0, -8.0) * ding)


## The hologram ring prints in under the lamp, carries it out spinning, burns
## magenta in the flip window and dissolves after the lock.
func _pose_ring(s: float, base: Vector3) -> void:
	var ring := _v.part("LampRingHolo") as MeshInstance3D
	if ring == null:
		return
	ring.visible = s > 0.06 and s < 0.985
	var holo := ring.material_override as ShaderMaterial
	var window := _window(s)
	var pulse := 1.0 + 0.08 * sin(s * _d * 26.0) * window
	var rest := _v.rest_transform("LampRingHolo")
	var spin := Basis(Vector3.UP, deg_to_rad(RING_SPIN * s * _d + 300.0 * window * s * _d))
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(8.0 * sin(s * _d * 3.0)))
	ring.transform = Transform3D((tilt * spin).scaled(Vector3.ONE * pulse * lerpf(0.7, 1.0, _e(0.06, 0.18, s))), rest.origin + base)
	if holo == null:
		return
	holo.set_shader_parameter("materialize", _e(0.06, 0.16, s) * (1.0 - _e(0.92, 0.985, s)))
	var col := LavaLampoonView.RING_TEAL.lerp(HOT, window).lerp(GOOD, _groovy).lerp(MISS, _missed)
	holo.set_shader_parameter("holo_color", col)
	holo.set_shader_parameter("intensity", 1.2 + window * 0.8 + _groovy * 1.5)


## "TAP R" over the lamp while the flip window is open; "GROOVY!" after a skip.
func _pose_prompt(s: float) -> void:
	var label := _label
	if label == null:
		return
	var lamp := _v.part("Lamp")
	var window := _window(s)
	_groovy = maxf(0.0, _groovy - _v.get_process_delta_time() * 2.2) if _skip >= 0.0 else 0.0
	_missed = maxf(0.0, _missed - _v.get_process_delta_time() * 2.5)
	var shown := window > 0.02 and _skip < 0.0 and not _spent and LavaLampoonView.weapons_of(_v) != null
	label.visible = shown or _groovy > 0.0
	if not label.visible or lamp == null:
		return
	label.position = _v.rest_transform("Lamp").origin + LIFT + Vector3(-0.075, 0.07, 0.0)
	if _groovy > 0.0:
		label.text = "GROOVY!"
		label.modulate = Color(GOOD, minf(1.0, _groovy * 2.0))
		label.scale = Vector3.ONE * (1.0 + 0.5 * (1.0 - _groovy))
	else:
		label.text = LavaLampoonView.prompt_text()
		label.modulate = Color(HOT.lerp(Color.WHITE, 0.4), window)
		label.scale = Vector3.ONE * (0.85 + 0.15 * window + 0.06 * sin(s * _d * 20.0))


## The wax: the spent blobs slump and pool, the lump slides to the cap as the
## lamp turns over, then splits into a full lamp of fresh blobs; the display
## goes dark and refills; the glow ripple after the lock.
func _pose_wax(s: float, k: float) -> void:
	var pool := (0.7 * _e(0.12, 0.4, s) + 0.3 * _e(0.4, 0.55, s)) * (1.0 - _e(0.6, 0.84, s))
	var blobs := _start_blobs if s < 0.6 else _full_blobs
	var swirl := sin(PI * _e(0.34, 0.82, s)) * 0.6
	var ripple := lerpf(-0.1, 1.15, _e(0.915, 1.0, s)) if s > 0.915 and k < 1.0 else -1.0
	var flare := 1.0 - _e(0.915, 1.0, s) if s > 0.915 else 0.0
	if _mat:
		LavaLampoonView.set_lamp(_mat, _v.part("LampGlass"), blobs, 0.0, pool, swirl, ripple, flare + _groovy)
	var lit := ceili(_start_blobs)
	if s > 0.12:
		lit = 0 if s < 0.84 else ceili(_full_blobs * _e(0.84, 0.92, s))
	LavaLampoonView.show_pips(_pips, lit)


## Twist-lock: a clunk, a shake and a pinch of sparks at the socket.
func _lock() -> void:
	_locked = true
	Sfx.play(LavaLampoonMode.LOCK_SOUND, -3.0)
	var p := _v.owner as Player
	if p:
		p.add_shake(0.06)
	_spark("Lamp", 10)


func _spark(anchor: String, amount: int) -> void:
	var a := _v.part(anchor)
	if a and _v.model:
		_v.spark_burst(_v.model.global_transform.affine_inverse() * a.global_position, Vector3.UP, SPARKS, amount, 0.9, 0.35, 0.008)


## 0-1 how open the active-reload window is (eased at its edges).
func _window(s: float) -> float:
	return _e(LavaLampoonMode.WINDOW_START - 0.02, LavaLampoonMode.WINDOW_START + 0.02, s) * (1.0 - _e(LavaLampoonMode.WINDOW_END - 0.02, LavaLampoonMode.WINDOW_END + 0.02, s))


## The drop into the socket: it speeds up as it falls (no ease at the bottom: it lands).
static func _drop(s: float) -> float:
	var u := clampf((s - 0.8) / 0.115, 0.0, 1.0)
	return u * u * (2.0 - u) if u < 1.0 else 1.0


## The little settle after it lands.
static func _seat_bump(s: float) -> float:
	return 0.004 * sin(PI * clampf((s - 0.915) / 0.04, 0.0, 1.0))


## Smootherstep of s between a and b (zero speed and acceleration at both ends).
static func _e(a: float, b: float, s: float) -> float:
	var t := clampf((s - a) / (b - a), 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


## Cubic from a to b over u 0-1 that starts and ends at `slope` (timeline per
## unit of u), so the skip leaves the flip and enters the lock at full pace.
static func _hermite(a: float, b: float, slope: float, u: float) -> float:
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * a + (u3 - 2.0 * u2 + u) * slope + (-2.0 * u3 + 3.0 * u2) * b + (u3 - u2) * slope


static func _place(node: Node3D, rest: Transform3D, offset: Vector3, rot_deg: Vector3) -> void:
	if node:
		node.transform = Transform3D(rest.basis * Basis.from_euler(rot_deg * (PI / 180.0)), rest.origin + offset)
