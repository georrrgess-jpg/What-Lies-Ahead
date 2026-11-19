class_name MeleeView
extends RefCounted
## The viewmodel motion every melee weapon shares (its WeaponData.view_script
## extends this): a slow idle sway, light swings that slash across the screen
## on eased arcs (alternating sides), the heavy's wind-up (pulled back over
## the shoulder, trembling as it charges) and its big diagonal chop, a shake
## when a swing connects, an equip flourish, and a short additive smear
## behind the blade while it moves fast.
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
## equip_pose) and part_motion for its moving parts.
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
## Smear: samples kept, the share of the edge it covers (from the tip), and
## the blade speed (view units per second) at which it is fully lit.
const TRAIL_SAMPLES := 9
const TRAIL_SPAN := 0.6
const TRAIL_FULL_SPEED := 2.2

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
	if mode and not inspecting:
		var side := 1.0 if mode.swing_index % 2 == 1 else -1.0
		match mode.phase:
			MeleeMode.Phase.LIGHT:
				var pose := _sample(light_keys(), mode.progress())
				goal_pos = _mirror_pos(pose[0], side)
				goal_rot = _mirror_rot(pose[1], side)
			MeleeMode.Phase.HEAVY:
				var pose := _sample(heavy_keys(), mode.progress())
				goal_pos = pose[0]
				goal_rot = pose[1]
			MeleeMode.Phase.WINDUP:
				var pose := windup_pose(mode.charge)
				var shake := mode.charge * mode.charge * 0.006
				goal_pos = pose[0] + Vector3(sin(_time * 63.0) * shake, sin(_time * 49.0 + 1.0) * shake, 0.0)
				goal_rot = pose[1]
				follow = 1.0 - exp(-12.0 * delta)
			_:
				follow = 1.0 - exp(-SETTLE * delta)
		if mode.hits != _hits_seen:
			_hits_seen = mode.hits
			_shake = 1.0
	else:
		follow = 1.0 - exp(-SETTLE * delta)
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


## The wind-up at `charge` 0-1: [position, rotation].
func windup_pose(charge: float) -> Array:
	var k := 1.0 - pow(1.0 - minf(1.0, charge * 2.5), 3.0)
	var start: Array = heavy_keys()[0]
	return [start[1] * k + Vector3(0.0, 0.0, 0.02) * charge, start[2] * k + Vector3(6.0, 0.0, 0.0) * charge]


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


## The pose at `t` along `keys`: each stretch eases in and out, the strike
## stretch (the second) eases out hard so the blade snaps through.
static func _sample(keys: Array, t: float) -> Array:
	for i in range(1, keys.size()):
		var b: Array = keys[i]
		if t <= float(b[0]) or i == keys.size() - 1:
			var a: Array = keys[i - 1]
			var u := clampf((t - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0)
			var k := ease_out(u) if i == 2 else ease_in_out(u)
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
	for s in _samples:
		s[2] = float(s[2]) * exp(-10.0 * delta)
	_trail_mesh.clear_surfaces()
	var lit := false
	for s in _samples:
		lit = lit or float(s[2]) > 0.02
	if not lit or _samples.size() < 2:
		return
	var color := trail_color(view)
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _samples.size():
		var s: Array = _samples[i]
		var fade := (1.0 - float(i) / (_samples.size() - 1)) * float(s[2])
		_trail_mesh.surface_set_color(Color(color, 0.0))
		_trail_mesh.surface_add_vertex(s[1])
		_trail_mesh.surface_set_color(Color(color, 0.75 * fade))
		_trail_mesh.surface_add_vertex(s[0])
	_trail_mesh.surface_end()


## The smear's colour (the weapon's tracer colour).
func trail_color(view: WeaponView) -> Color:
	return view.data.tracer_color
