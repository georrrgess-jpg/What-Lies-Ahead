extends RefCounted
## Ground Control viewmodel motion (WeaponData.view_script). The charge is
## shown on the gun in its three steps: the pink beacon on the whip antenna
## blinks faster, and the solar wing on the right flank unfolds one more
## tile per step (Wing1..3, an accordion folded shut at rest). Each ping
## kicks the dish back, harder the bigger the ring. An overcharge turns the
## dish's glowing face pink and makes it crackle with sparks; a stall sags
## the gun and puts the radar screen to static. The radar screen
## (RadarScreen, ground_control_radar.gdshader) sweeps and blips where
## zombies are around the player; the signal bars on the left flank (Bar0..4)
## show the magazine.
## Inspect: the gun turns its dish to the eye, the solar wing unfolds tile by
## tile, the dish sweeps the sky left and right, locks on and pings (the core
## flashes, a ring of sparks, a chime), and the wing folds away again.

const BARS := 5
const WINGS := 3
## Folded angle of each wing tile about its hinge (alternating, accordion).
const FOLD := 172.0
const WING_SPEED := 16.0
## Beacon blinks a second: idle, at full charge, overcharged.
const BLINK_IDLE := 1.2
const BLINK_FULL := 7.0
const BLINK_OVER := 14.0
const KICK_TIME := 0.32
## Size of the dish while aiming, against its hip size.
const AIM_DISH_SCALE := 0.62
const RADAR_SHADER := "res://art/shaders/ground_control_radar.gdshader"
const RADAR_RANGE := 30.0
const RADAR_REFRESH := 0.2
const LIME := Color(0.66, 0.9, 0.24)
const PINK := Color(1.0, 0.37, 0.64)
const INSPECT_LENGTH := 2.9
const PING_AT := 1.95
## The dish's sweep (degrees either way) and how long each pass takes.
const SWEEP := 32.0
const INSPECT_POSES := [
	[0.0, Vector3(0.14, -0.14, -0.62), Vector3(2.0, -16.0, -2.0)],
	[0.18, Vector3(0.05, -0.1, -0.56), Vector3(10.0, -100.0, 6.0)],
	[0.45, Vector3(0.03, -0.09, -0.55), Vector3(12.0, -128.0, 4.0)],
	[0.7, Vector3(0.03, -0.09, -0.55), Vector3(10.0, -134.0, 2.0)],
	[0.86, Vector3(0.08, -0.12, -0.58), Vector3(6.0, -60.0, 0.0)],
	[1.0, Vector3(0.14, -0.15, -0.62), Vector3(2.0, -6.0, 0.0)],
]
const CRACKLE := [Color(1.0, 0.45, 0.75), Color(1.0, 0.95, 1.0), Color(0.75, 0.95, 0.4)]

var _wings: Array[Node3D] = []
var _wing_open: Array[float] = [0.0, 0.0, 0.0]
var _bars: Array[Node3D] = []
var _dish: Node3D
var _beacon: Node3D
var _muzzle: Node3D
var _core_mat: StandardMaterial3D
var _beacon_mat: StandardMaterial3D
var _radar: ShaderMaterial
var _blips := PackedVector2Array()
var _radar_left := 0.0
var _blink := 0.0
var _since_shot := 10.0
var _shot_power := 0.0
var _crackle := 0.0
var _was_stalled := false
var _pinged := false


func setup(v: WeaponView) -> void:
	for part in ["Dish", "Beacon", "SatHolo"]:
		v.register_part(part)
	for k in WINGS:
		v.register_part("Wing%d" % (k + 1))
		_wings.append(v.part("Wing%d" % (k + 1)))
	for i in BARS:
		v.register_part("Bar%d" % i)
		_bars.append(v.part("Bar%d" % i))
	_dish = v.part("Dish")
	_beacon = v.part("Beacon")
	_muzzle = v.model.find_child("Muzzle", true, false) as Node3D
	_core_mat = _own_material(v.model.find_child("DishCore", true, false) as MeshInstance3D)
	_beacon_mat = _own_material(_beacon as MeshInstance3D)
	var screen := v.model.find_child("RadarScreen", true, false) as MeshInstance3D
	if screen:
		_radar = ShaderMaterial.new()
		_radar.shader = load(RADAR_SHADER)
		screen.material_override = _radar
	_blips.resize(6)


func fired(v: WeaponView) -> void:
	_since_shot = 0.0
	var mode := _mode(v)
	_shot_power = 1.0 if mode == null else [0.35, 0.55, 0.8, 1.0, 1.4][clampi(mode.last_step, 0, 4)]
	if mode and mode.last_step > 3 and _muzzle:
		v.spark_burst(_model_point(v, _muzzle), Vector3(0, 0.3, -1), CRACKLE, 22, 1.6, 0.4, 0.012)


func event(_v: WeaponView, _event_name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	_since_shot += delta
	var w := v.player.weapons if v.player else null
	var held := w != null and w.current == v.data
	var mode := _mode(v)
	var charge := w.shown_charge() if held else 0.0
	var over := mode.overcharge() if mode else 0.0
	var stall := mode.stall_left() if mode else 0.0
	_update_radar(v, delta, charge, stall)
	if v.is_reloading():
		return
	_pose_wings(v, delta, charge)
	_pose_beacon(delta, charge, over, stall)
	_pose_dish(v, delta, over, stall)
	_show_bars(v)


func inspect_length() -> float:
	return INSPECT_LENGTH


func inspect_poses() -> Array:
	return INSPECT_POSES


func inspect_start(_v: WeaponView) -> void:
	_pinged = false


func inspect(v: WeaponView, t: float) -> void:
	for k in _wings.size():
		var open := WeaponInspect.window(t, 0.35 + k * 0.14, 0.55 + k * 0.14) * (1.0 - WeaponInspect.window(t, 2.25 + (2 - k) * 0.1, 2.45 + (2 - k) * 0.1))
		_wing_open[k] = open
		if _wings[k]:
			var side := 1.0 if k % 2 == 0 else -1.0
			var fold := deg_to_rad(FOLD * (1.0 - open) * side) - sin(open * PI) * 0.12 * side
			_wings[k].transform = v.rest_transform("Wing%d" % (k + 1)) * Transform3D(Basis(Vector3.BACK, fold), Vector3.ZERO)
	if _dish:
		# Sweeps left and right, slows, locks on dead ahead; the ping kicks it back.
		var sweep := sin(clampf((t - 0.7) / 1.1, 0.0, 1.0) * TAU * 1.5) * SWEEP * (1.0 - WeaponInspect.window(t, 1.45, 1.8))
		var nod := 6.0 * WeaponInspect.hump(t, 0.7, 1.8)
		var kick := WeaponInspect.hump(t, PING_AT, PING_AT + 0.3) * (1.0 - clampf((t - PING_AT) / 0.3, 0.0, 1.0))
		var b := Basis.from_euler(Vector3(deg_to_rad(nod - 8.0 * kick), deg_to_rad(sweep), 0.0))
		_dish.transform = v.rest_transform("Dish") * Transform3D(b, Vector3(0.0, 0.0, 0.03 * kick))
	if _core_mat:
		var flash := exp(-maxf(0.0, t - PING_AT) * 6.0) if t >= PING_AT else 0.0
		_core_mat.emission = LIME.lerp(Color(0.9, 1.0, 0.85), flash)
		_core_mat.albedo_color = _core_mat.emission
		_core_mat.emission_energy_multiplier = 2.4 + flash * 5.0
	if _beacon_mat and t > 0.6 and t < PING_AT:
		_beacon_mat.emission_energy_multiplier = 0.3 + 3.2 * float(fmod(t * 5.0, 1.0) < 0.4)
	if t >= PING_AT and not _pinged:
		_pinged = true
		_ping(v)


func inspect_end(_v: WeaponView) -> void:
	_wing_open = [0.0, 0.0, 0.0]


## The lock-on ping: a chime and a ring of sparks off the dish's rim.
func _ping(v: WeaponView) -> void:
	Sfx.play(&"gc_chime", -8.0, 1.1)
	if _dish == null:
		return
	var centre := _model_point(v, _dish) + Vector3(0.0, 0.0, -0.06)
	for i in 10:
		var a := TAU * i / 10.0
		var out := Vector3(cos(a), sin(a), -0.25)
		v.spark_burst(centre + Vector3(cos(a), sin(a), 0.0) * 0.1, out, CRACKLE if i % 2 == 0 else [LIME, Color.WHITE], 2, 0.8, 0.35, 0.007)


## Each step of the charge unfolds one more tile of the solar wing.
func _pose_wings(v: WeaponView, delta: float, charge: float) -> void:
	var steps := int(floor(charge * WINGS + 0.0001))
	for k in _wings.size():
		var goal := 1.0 if steps > k else 0.0
		_wing_open[k] = move_toward(_wing_open[k], goal, WING_SPEED * delta * (1.0 if goal > _wing_open[k] else 0.5))
		if _wings[k] == null:
			continue
		var eased := smoothstep(0.0, 1.0, _wing_open[k])
		var fold := deg_to_rad(FOLD * (1.0 - eased) * (1.0 if k % 2 == 0 else -1.0))
		# A little overshoot as the tile snaps open.
		fold -= sin(eased * PI) * 0.12 * (1.0 if k % 2 == 0 else -1.0)
		_wings[k].transform = v.rest_transform("Wing%d" % (k + 1)) * Transform3D(Basis(Vector3.BACK, fold), Vector3.ZERO)


## The beacon blinks faster as the charge builds, frantic when overcharged, dark in a stall.
func _pose_beacon(delta: float, charge: float, over: float, stall: float) -> void:
	var rate := lerpf(BLINK_IDLE, BLINK_FULL, charge) if over <= 0.0 else lerpf(BLINK_FULL, BLINK_OVER, over)
	_blink = fmod(_blink + rate * delta, 1.0)
	var on := 0.0 if stall > 0.0 else pow(0.5 + 0.5 * cos(_blink * TAU), 3.0)
	if _beacon:
		_beacon.scale = Vector3.ONE * (1.0 + on * 0.35)
	if _beacon_mat:
		_beacon_mat.emission_energy_multiplier = 0.3 + on * 3.2


## The dish kicks back with each ping, trembles and glows pink when
## overcharged (with crackling sparks), and droops in a stall.
func _pose_dish(v: WeaponView, delta: float, over: float, stall: float) -> void:
	if _dish == null:
		return
	var k := 0.0
	if _since_shot < KICK_TIME:
		var t := _since_shot / KICK_TIME
		k = sin(t * PI) * (1.0 - t) * 1.6 * _shot_power
	var shiver := over * 0.004
	var jitter := Vector3(sin(Time.get_ticks_msec() * 0.083) * shiver, 0.0, sin(Time.get_ticks_msec() * 0.061) * shiver)
	var droop := clampf(stall * 2.0, 0.0, 1.0)
	var basis := Basis.from_euler(Vector3(deg_to_rad(-6.0 * k - 14.0 * droop), 0.0, 0.0))
	# Aiming draws the dish in, so the big disc does not hide the view down the sights.
	basis = basis.scaled(Vector3.ONE * lerpf(1.0, AIM_DISH_SCALE, smoothstep(0.0, 1.0, v.player.ads) if v.player else 0.0))
	_dish.transform = v.rest_transform("Dish") * Transform3D(basis, Vector3(0.0, -0.004 * droop, 0.03 * k) + jitter)
	if _core_mat:
		var flicker := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.05)
		_core_mat.emission = LIME.lerp(PINK, over)
		_core_mat.albedo_color = _core_mat.emission
		_core_mat.emission_energy_multiplier = 0.4 if stall > 0.0 else 2.4 * lerpf(1.0, flicker * 1.6, over)
	if over >= 1.0 and _muzzle:
		_crackle -= delta
		if _crackle <= 0.0:
			_crackle = randf_range(0.05, 0.11)
			var at := _model_point(v, _muzzle) + Vector3(randf_range(-0.06, 0.06), randf_range(-0.06, 0.06), 0.03)
			v.spark_burst(at, Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0), CRACKLE, 3, 0.6, 0.18, 0.006)
	if stall > 0.0 and not _was_stalled:
		v.spark_burst(_model_point(v, _muzzle) if _muzzle else Vector3.ZERO, Vector3.UP, [Color(0.6, 0.6, 0.65), Color(0.9, 0.9, 0.95)], 10, 0.5, 0.6, 0.012)
	_was_stalled = stall > 0.0


## The signal bars on the flank count the magazine (five bars = full).
func _show_bars(v: WeaponView) -> void:
	var w := v.player.weapons if v.player else null
	var mag := v.data.magazine_size
	if w and w.current == v.data:
		mag = w.magazine()
	var lit := ceili(float(mag) / v.data.magazine_size * BARS)
	for i in _bars.size():
		if _bars[i]:
			_bars[i].visible = i < lit


## The radar screen: sweep, blips of nearby zombies (refreshed a few times a
## second), brighter rings while charging, static in a stall.
func _update_radar(v: WeaponView, delta: float, charge: float, stall: float) -> void:
	if _radar == null:
		return
	_radar.set_shader_parameter("charge", charge)
	_radar.set_shader_parameter("static_amount", clampf(stall * 3.0, 0.0, 1.0))
	_radar_left -= delta
	if _radar_left > 0.0 or v.player == null:
		return
	_radar_left = RADAR_REFRESH
	var count := 0
	var me := v.player.global_position
	var basis := v.player.global_basis
	for node in v.get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var to := z.global_position - me
		if to.length() > RADAR_RANGE:
			continue
		var local := basis.inverse() * to
		_blips[count] = Vector2(local.x, -local.z) / RADAR_RANGE * 0.95
		count += 1
		if count >= _blips.size():
			break
	_radar.set_shader_parameter("blip_count", count)
	_radar.set_shader_parameter("blips", _blips)


## A per-instance copy of the material on `mi` (so the glow can change on this weapon only).
func _own_material(mi: MeshInstance3D) -> StandardMaterial3D:
	if mi == null or mi.mesh == null:
		return null
	var base := mi.get_active_material(0) as StandardMaterial3D
	if base == null:
		return null
	var m := base.duplicate() as StandardMaterial3D
	m.emission_enabled = true
	mi.material_override = m
	return m


func _model_point(v: WeaponView, node: Node3D) -> Vector3:
	return v.model.global_transform.affine_inverse() * node.global_position


func _mode(v: WeaponView) -> GroundControlMode:
	var w := v.player.weapons if v.player else null
	if w == null or w.current != v.data:
		return null
	return w.mode as GroundControlMode
