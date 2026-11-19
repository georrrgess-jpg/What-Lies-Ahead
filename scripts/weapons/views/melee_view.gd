class_name MeleeView
extends RefCounted
## The viewmodel motion every melee weapon shares (its WeaponData.view_script
## extends this): a slow idle sway, light swings that slash across the screen
## on eased arcs (alternating sides), the heavy's wind-up (pulled back over
## the shoulder, coiling and trembling as it charges) and its big diagonal
## chop, a hit-stop and shake when a swing connects, an equip flourish, and a
## smear behind the blade while it moves fast.
##
## It poses the whole model ("Root", WeaponView.part) as an offset on top of
## the hip pose WeaponView gives the holder, following the held weapon's
## MeleeMode (phase, progress(), charge, swing_index, hits). Poses are
## [position offset (view units), rotation (degrees)] in the view's own axes
## (x right, y up, z back toward the eye; pitch tips the point toward the eye,
## yaw turns it left, roll turns it anticlockwise on screen), about the
## model's origin (the grip; keep rolls under about 40 degrees or the forearm
## swings up into view), whatever the weapon's hold
## (view_rotation_degrees). The light swing keys run from right to left and
## are mirrored for every other swing. A weapon's own
## view overrides the pose hooks (light_keys, heavy_keys, windup_pose,
## equip_pose, contact_at) and part_motion for its moving parts.
##
## Timing: each swing has a strike stretch (the light's second, from keys[1]
## to keys[2], eased out so the blade snaps through; the heavy's first, from
## the wind-up to keys[1], snapping out of the release) and connects
## contact_at() of the way through: CONTACT_SHARE of the strike stretch's
## travel. The view reports both moments to the MeleeMode (view_contact), so
## the hit lands on the frame the blade crosses the screen. A swing starts from
## wherever the pose was (a half wind-up, a settle) and blends into its keys
## over its first stretch, so nothing pops. A connect holds the swing for a
## few hundredths of a second (HIT_STOP) and jolts it.
##
## Inspect: while WeaponView reports is_inspecting() (the generic inspect or a
## weapon's own), the swing poses ease out and leave the model to it.

## Light swing keys: [t (0-1 of the swing), position, rotation].
const LIGHT_KEYS := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.16, Vector3(0.1, 0.08, 0.02), Vector3(5.0, -15.0, -25.0)],
	[0.4, Vector3(-0.2, 0.0, -0.1), Vector3(-12.0, 20.0, 30.0)],
	[0.58, Vector3(-0.32, -0.08, -0.02), Vector3(-15.0, 28.0, 38.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]
## Heavy swing keys, from the wind-up pose (t 0) through the chop.
const HEAVY_KEYS := [
	[0.0, Vector3(0.06, 0.16, 0.08), Vector3(20.0, -12.0, -28.0)],
	[0.24, Vector3(-0.16, -0.06, -0.14), Vector3(-30.0, 18.0, 30.0)],
	[0.46, Vector3(-0.3, -0.2, -0.04), Vector3(-38.0, 26.0, 38.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]
## How fast the pose follows the swing keys out of a swing (1/s).
const SETTLE := 14.0
## The key that ends the strike stretch of a light (and a heavy) swing.
const LIGHT_STRIKE := 2
const HEAVY_STRIKE := 1
## Share of the strike stretch's travel at which a light (heavy) swing connects.
const CONTACT_SHARE := Vector2(0.4, 0.5)
## Seconds a connect holds a light (heavy) swing.
const HIT_STOP := Vector2(0.045, 0.08)
## The wind-up: share of the charge by which it is mostly drawn back, and the
## extra coil (position, degrees) it gathers on to a full charge.
const WINDUP_DRAW := 0.35
const WINDUP_COIL_POS := Vector3(0.012, 0.012, 0.03)
const WINDUP_COIL_ROT := Vector3(8.0, -3.0, -4.0)
## Smear: samples kept, the share of the edge it covers (from the tip), the
## blade speed (view units per second) at which it is fully lit, and the
## points drawn between two samples (a smooth curve through them).
const TRAIL_SAMPLES := 12
const TRAIL_SPAN := 0.6
const TRAIL_FULL_SPEED := 2.2
const TRAIL_STEPS := 3

var _pos := Vector3.ZERO
var _rot := Vector3.ZERO
var _time := 0.0
var _equip := 0.0
var _hits_seen := 0
var _shake := 0.0
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _samples: Array = []     # [tip, base, strength] in the WeaponView's space
var _tip: Node3D
var _base: Node3D
## The phase and swing the pose last followed (a change starts a blend).
var _phase_seen := -1
var _swing_seen := -1
## The pose a swing started from, blended out over its first stretch.
var _from_pos := Vector3.ZERO
var _from_rot := Vector3.ZERO
## Hit-stop: seconds left held, and how far (share of the swing) the pose lags the swing.
var _stop := 0.0
var _lag := 0.0
## 0-1 pulse when the wind-up tops out.
var _ready_pulse := 0.0
var _was_full := false


func setup(view: WeaponView) -> void:
	_tip = view.model.find_child("BladeTip", true, false) as Node3D
	_base = view.model.find_child("SwingPoint", true, false) as Node3D
	_equip = 0.0
	var mode := _mode(view)
	_hits_seen = mode.hits if mode else 0
	if view.player:
		_build_trail(view)


func fired(_view: WeaponView) -> void:
	pass


func event(_view: WeaponView, _event_name: StringName) -> void:
	pass


func update(view: WeaponView, delta: float) -> void:
	_time += delta
	_equip += delta
	var model := view.model
	if model == null:
		return
	var mode := _mode(view)
	var goal_pos := Vector3.ZERO
	var goal_rot := Vector3.ZERO
	var follow := 1.0
	var inspecting := view.has_method("is_inspecting") and bool(view.call("is_inspecting"))
	if mode:
		mode.view_contact = Vector2(contact_at(false), contact_at(true))
	if mode and not inspecting:
		if int(mode.phase) != _phase_seen or mode.swing_index != _swing_seen:
			_phase_seen = mode.phase
			_swing_seen = mode.swing_index
			_from_pos = _pos
			_from_rot = _rot
			_lag = 0.0
			_stop = 0.0
		if mode.hits != _hits_seen:
			_hits_seen = mode.hits
			_shake = 1.0
			_stop = HIT_STOP.y if mode.phase == MeleeMode.Phase.HEAVY else HIT_STOP.x
		if _stop > 0.0:
			_stop -= delta
			_lag += delta / mode.swing_time()
		else:
			_lag *= exp(-16.0 * delta)
		var t := maxf(0.0, mode.progress() - _lag)
		var side := 1.0 if mode.swing_index % 2 == 1 else -1.0
		match mode.phase:
			MeleeMode.Phase.LIGHT:
				var keys := light_keys()
				var pose := _sample(keys, t, LIGHT_STRIKE)
				var start: Array = keys[0]
				var blend := 1.0 - ease_in_out(t / maxf(0.01, float(keys[1][0])))
				goal_pos = _mirror_pos(pose[0], side) + (_from_pos - _mirror_pos(start[1], side)) * blend
				goal_rot = _mirror_rot(pose[1], side) + (_from_rot - _mirror_rot(start[2], side)) * blend
			MeleeMode.Phase.HEAVY:
				var keys := heavy_keys()
				var pose := _sample(keys, t, HEAVY_STRIKE)
				var start: Array = keys[0]
				var blend := 1.0 - ease_in_out(t / maxf(0.01, float(keys[1][0])))
				goal_pos = pose[0] + (_from_pos - start[1]) * blend
				goal_rot = pose[1] + (_from_rot - start[2]) * blend
			MeleeMode.Phase.WINDUP:
				var pose := windup_pose(mode.charge)
				var full := mode.charge >= 1.0
				if full and not _was_full:
					_ready_pulse = 1.0
				_was_full = full
				# Trembles harder as the power gathers; a small push when it tops out.
				var shake := mode.charge * mode.charge * 0.006
				var tremble := Vector3(sin(_time * 63.0), sin(_time * 49.0 + 1.0), 0.0)
				goal_pos = pose[0] + tremble * shake + Vector3(0.0, 0.0, -0.012) * _ready_pulse
				goal_rot = pose[1] + Vector3(sin(_time * 57.0), sin(_time * 71.0 + 2.0), 0.0) * mode.charge * mode.charge * 0.8
				follow = 1.0 - exp(-12.0 * delta)
			_:
				follow = 1.0 - exp(-SETTLE * delta)
		if mode.phase != MeleeMode.Phase.WINDUP:
			_was_full = false
	else:
		follow = 1.0 - exp(-SETTLE * delta)
	_ready_pulse = maxf(0.0, _ready_pulse - delta * 5.0)
	_pos = _pos.lerp(goal_pos, follow)
	_rot = _rot.lerp(goal_rot, follow)
	_shake = maxf(0.0, _shake - delta * 7.0)
	var jolt := Vector3(sin(_time * 90.0), cos(_time * 77.0), 0.0) * 0.012 * _shake * _shake
	var equip := equip_pose(view, _equip)
	var idle := idle_pose(_time) if mode == null or mode.phase == MeleeMode.Phase.IDLE else [Vector3.ZERO, Vector3.ZERO]
	if inspecting:
		equip = [Vector3.ZERO, Vector3.ZERO]
		idle = [Vector3.ZERO, Vector3.ZERO]
	var rest := view.rest_transform("Root")
	var rot: Vector3 = (_rot + equip[1] + idle[1]) * (PI / 180.0)
	if not inspecting or not (_pos.is_zero_approx() and _rot.is_zero_approx()):
		# The pose is in the view's axes: turned into the model's (held at view_rotation_degrees).
		var hold := Basis.from_euler(view.data.view_rotation_degrees * (PI / 180.0))
		var back := hold.inverse()
		# Turned about swing_pivot() (the grip by default; a shoulder keeps the arm low).
		var turn := Basis.from_euler(rot)
		var pivot := swing_pivot()
		model.transform = rest * Transform3D(back * turn * hold, back * (_pos + jolt + equip[0] + idle[0] + pivot - turn * pivot))
	part_motion(view, mode, delta)
	_update_trail(view, delta, mode != null and (mode.phase == MeleeMode.Phase.LIGHT or mode.phase == MeleeMode.Phase.HEAVY) and not inspecting)


# --- hooks for a weapon's own view ---------------------------------------------------

## Keys of a light swing (see LIGHT_KEYS).
func light_keys() -> Array:
	return LIGHT_KEYS


## Keys of a heavy swing (see HEAVY_KEYS).
func heavy_keys() -> Array:
	return HEAVY_KEYS


## The wind-up at `charge` 0-1: [position, rotation]. Mostly drawn back to
## the heavy's first key by WINDUP_DRAW of the charge, then it keeps coiling a
## little further as the power gathers (the release blends out of whatever
## pose this gives, so a half wind-up swings cleanly too).
func windup_pose(charge: float) -> Array:
	var k := 0.85 * ease_out(charge / WINDUP_DRAW) + 0.15 * ease_in_out(charge)
	var coil := charge * charge
	var start: Array = heavy_keys()[0]
	return [start[1] * k + WINDUP_COIL_POS * coil, start[2] * k + WINDUP_COIL_ROT * coil]


## The share of a light (heavy) swing at which it connects: CONTACT_SHARE of
## the way along its strike stretch (see the class notes). A weapon whose keys
## meet the target elsewhere in the swing overrides this.
func contact_at(heavy: bool) -> float:
	var keys := heavy_keys() if heavy else light_keys()
	var strike := HEAVY_STRIKE if heavy else LIGHT_STRIKE
	if keys.size() <= strike:
		return -1.0
	var a := float(keys[strike - 1][0])
	var b := float(keys[strike][0])
	# The inverse of the stretch's ease (cubic out for the light, quadratic out for the heavy).
	var u := 1.0 - (sqrt(1.0 - CONTACT_SHARE.y) if heavy else pow(1.0 - CONTACT_SHARE.x, 1.0 / 3.0))
	return a + (b - a) * u


## The equip flourish `t` seconds after the weapon was taken: a quick twirl
## about the handle while it rises. [position, rotation].
func equip_pose(view: WeaponView, t: float) -> Array:
	var length := maxf(0.1, view.data.equip_time + 0.12)
	if t >= length:
		return [Vector3.ZERO, Vector3.ZERO]
	var k := ease_out(t / length)
	return [Vector3.ZERO, Vector3(0.0, (1.0 - k) * 360.0, 0.0)]


## The point the swing poses turn about, in view units from the model's origin
## (the grip) in the view's axes. ZERO turns the weapon in the hand; a point
## back and down toward the shoulder swings the whole arm, so the forearm stays
## low while the weapon sweeps across the screen.
func swing_pivot() -> Vector3:
	return Vector3.ZERO


## A slow idle sway at time `t` (seconds): [position, rotation].
func idle_pose(t: float) -> Array:
	return [Vector3(0.0, sin(t * 1.6) * 0.004, 0.0), Vector3(sin(t * 1.1) * 1.2, sin(t * 0.7) * 1.5, sin(t * 0.9) * 1.0)]


## The weapon's own moving parts, every frame (a blade on its hinge).
func part_motion(_view: WeaponView, _mode: MeleeMode, _delta: float) -> void:
	pass


# --- helpers -------------------------------------------------------------------------

## Cubic ease-out, 0-1.
static func ease_out(t: float) -> float:
	var r := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - r * r * r


## Smooth ease-in-out, 0-1.
static func ease_in_out(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Quadratic ease-out, 0-1 (the heavy's release: fast out of the wind-up, still readable).
static func snap_out(t: float) -> float:
	var r := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - r * r


## The pose at `t` along `keys`: each stretch eases in and out, the strike
## stretch (ending at key `strike`: LIGHT_STRIKE for a light swing,
## HEAVY_STRIKE for the heavy out of its wind-up) eases out so the blade
## snaps through.
static func _sample(keys: Array, t: float, strike := LIGHT_STRIKE) -> Array:
	for i in range(1, keys.size()):
		var b: Array = keys[i]
		if t <= float(b[0]) or i == keys.size() - 1:
			var a: Array = keys[i - 1]
			var u := clampf((t - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0)
			var k := ease_in_out(u)
			if i == strike:
				k = ease_out(u) if strike == LIGHT_STRIKE else snap_out(u)
			return [(a[1] as Vector3).lerp(b[1], k), (a[2] as Vector3).lerp(b[2], k)]
	return [Vector3.ZERO, Vector3.ZERO]


static func _mirror_pos(p: Vector3, side: float) -> Vector3:
	return Vector3(p.x * side, p.y, p.z)


static func _mirror_rot(r: Vector3, side: float) -> Vector3:
	return Vector3(r.x, r.y * side, r.z * side)


func _mode(view: WeaponView) -> MeleeMode:
	if view.player == null or view.player.weapons == null or view.player.weapons.current != view.data:
		return null
	return view.player.weapons.mode as MeleeMode


# --- the smear -------------------------------------------------------------------------

func _build_trail(view: WeaponView) -> void:
	if _tip == null or _base == null:
		return
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.name = "SwingTrail"
	_trail.mesh = _trail_mesh
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	_trail.material_override = m
	# Under the view, beside the model: the smear stays where the blade was, not on the blade.
	view.add_child(_trail)
	view.model.tree_exiting.connect(_trail.queue_free)


func _update_trail(view: WeaponView, delta: float, swinging: bool) -> void:
	if _trail == null or not is_instance_valid(_trail):
		return
	var tip := view.to_local(_tip.global_position)
	var base := view.to_local(_base.global_position).lerp(tip, 1.0 - TRAIL_SPAN)
	var speed := 0.0
	if not _samples.is_empty():
		speed = (tip - (_samples[0][0] as Vector3)).length() / maxf(delta, 0.001)
	var strength := clampf(speed / TRAIL_FULL_SPEED, 0.0, 1.0) if swinging else 0.0
	_samples.push_front([tip, base, strength])
	if _samples.size() > TRAIL_SAMPLES:
		_samples.resize(TRAIL_SAMPLES)
	for sample in _samples:
		sample[2] = float(sample[2]) * exp(-9.0 * delta)
	_trail_mesh.clear_surfaces()
	var lit := false
	for sample in _samples:
		lit = lit or float(sample[2]) > 0.02
	if not lit or _samples.size() < 3:
		return
	# A smooth ribbon through the samples: clear at its inner edge, the weapon's
	# colour through the middle and a hot, near-white edge along the tip's path,
	# narrowing toward the tip as it ages.
	var color := trail_color(view)
	var hot := color.lerp(Color.WHITE, 0.55)
	var rows: Array = []   # [tip, middle, inner edge, fade]
	var last := _samples.size() - 1
	for i in last:
		for step in TRAIL_STEPS:
			var u := float(step) / TRAIL_STEPS
			var tip_p := _curve(_samples, i, u, 0)
			var base_p := _curve(_samples, i, u, 1)
			var age := (float(i) + u) / last
			var fade := (1.0 - age) * lerpf(float(_samples[i][2]), float(_samples[i + 1][2]), u)
			var inner := base_p.lerp(tip_p, age * 0.5)
			rows.append([tip_p, inner.lerp(tip_p, 0.55), inner, fade])
	var end_tip: Vector3 = _samples[last][0]
	rows.append([end_tip, end_tip, end_tip, 0.0])
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		var fa := float(a[3])
		var fb := float(b[3])
		_quad(a[2], b[2], a[1], b[1], Color(color, 0.0), Color(color, 0.0), Color(color, 0.5 * fa), Color(color, 0.5 * fb))
		_quad(a[1], b[1], a[0], b[0], Color(color, 0.5 * fa), Color(color, 0.5 * fb), Color(hot, 0.95 * fa), Color(hot, 0.95 * fb))
	_trail_mesh.surface_end()


## Two triangles from the inner edge (a0 to b0) to the outer (a1 to b1).
func _quad(a0: Vector3, b0: Vector3, a1: Vector3, b1: Vector3, ca0: Color, cb0: Color, ca1: Color, cb1: Color) -> void:
	for v in [[a0, ca0], [a1, ca1], [b1, cb1], [a0, ca0], [b1, cb1], [b0, cb0]]:
		_trail_mesh.surface_set_color(v[1])
		_trail_mesh.surface_add_vertex(v[0])


## A Catmull-Rom point `u` of the way from sample i to i + 1 (`which` 0 the tip, 1 the base).
static func _curve(samples: Array, i: int, u: float, which: int) -> Vector3:
	var p0: Vector3 = samples[maxi(i - 1, 0)][which]
	var p1: Vector3 = samples[i][which]
	var p2: Vector3 = samples[mini(i + 1, samples.size() - 1)][which]
	var p3: Vector3 = samples[mini(i + 2, samples.size() - 1)][which]
	var u2 := u * u
	return 0.5 * (2.0 * p1 + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * u2 * u)


## The smear's colour (the weapon's tracer colour).
func trail_color(view: WeaponView) -> Color:
	return view.data.tracer_color
