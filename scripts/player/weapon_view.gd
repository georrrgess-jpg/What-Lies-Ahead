class_name WeaponView
extends Node3D
## First-person viewmodel: shows the held weapon and arms, applies mastery
## cosmetics, and animates its motion, recoil, reloads, the muzzle flash, the
## lower/raise of a weapon switch, charging and beams.
##
## Motion is a set of poses blended through springs (so moves overshoot and
## settle a little, like a weapon held in hands): the lowered and canted
## sprint pose, a tilt into strafes, a lag behind the look and behind rising
## and falling, a dip and kick on jumps and landings, a roll while sliding and
## a lowered weapon while mantling. The bob follows the player's step rhythm,
## in time with the footsteps, and only on the ground. All of it fades out
## when aiming down sights, where the sight sits exactly on the screen centre.
##
## The whole rig is scaled down and held very close to the camera. On screen it
## looks identical, but it can no longer poke through walls or zombies.

const VIEW_SCALE := 0.2
## Poses (position in view units, rotation in degrees) added to the hip pose.
const SPRINT_POS := Vector3(-0.07, -0.06, 0.03)
const SPRINT_ROT := Vector3(-14.0, 26.0, 16.0)
const SLIDE_POS := Vector3(-0.02, -0.035, 0.02)
const SLIDE_ROT := Vector3(-4.0, 6.0, -10.0)
const MANTLE_POS := Vector3(-0.03, -0.09, 0.04)
const MANTLE_ROT := Vector3(-20.0, 8.0, 6.0)
const VAULT_POS := Vector3(-0.02, -0.06, 0.03)
const VAULT_ROT := Vector3(-12.0, 4.0, -12.0)
## Tilt into a strafe at walking speed (degrees), and how far the weapon trails.
const STRAFE_ROLL := 4.0
const STRAFE_SHIFT := 0.012
## Lag behind vertical speed (view units per m/s, and its limit).
const RISE_LAG := 0.004
const RISE_LAG_MAX := 0.03
## Lag behind the look: degrees of lag per degree turned, and its limit.
const LOOK_LAG := 0.3
const LOOK_LAG_MAX := 6.0
## Bob per step: side swing, dip as a foot lands (view units), roll (degrees).
const BOB_SIDE := 0.012
const BOB_DIP := 0.015
const BOB_ROLL := 1.0
## Initial spring velocity per unit of wanted peak (for the pose springs).
const KICK_GAIN := 30.0
const HOLO_SHADER := "res://art/shaders/holo.gdshader"
## Parts the reload animations may move (see art/blender/build_weapons.py).
const ANIMATED_PARTS := ["Cell", "CellHolo", "Slide", "Hammer", "Panel", "Vents", "Barrels", "Pump",
	"Drum", "Capsules", "CapsulesHolo", "ArmL", "ArmR"]

var data: WeaponData
var model: Node3D
var _holder: Node3D
var _muzzle: Node3D
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_time := 0.0

## Pose offsets on top of the hip pose: position (view units), rotation (degrees).
var _pose_pos := MotionSpring.new(15.0, 0.6)
var _pose_rot := MotionSpring.new(15.0, 0.6)
## Lag behind the look: x yaw, y pitch (degrees).
var _look := MotionSpring.new(10.0, 0.5)
var _kick := 0.0
var _kick_rot := 0.0
var _raise := 1.0          # 1 = lowered off-screen, 0 = in firing position
var _reload_tween: Tween
var _glow_mats: Array[StandardMaterial3D] = []   # per-instance copies of the cell glow
var _glow_base := 2.6
var _holo_mats := {}                               # part name -> ShaderMaterial
var _rest := {}            # node -> rest Transform3D, for reload animations
var _pending: WeaponData   # weapon to show once the old one is lowered
var _reload_player: Object # the running custom reload (WeaponData.reload_script)
var _lowering := false
var _time := 0.0
## Where the sight sits in model space; aiming puts this point on the screen centre.
var _sight_local := Vector3(0, 0.13, 0)

@onready var player: Player = owner as Player


func _ready() -> void:
	scale = Vector3.ONE * VIEW_SCALE
	_holder = Node3D.new()
	_holder.name = "Holder"
	add_child(_holder)
	if player:
		player.jumped.connect(_on_jumped)
		player.landed.connect(_on_landed)
		player.slide_started.connect(_on_slide_started)
		player.traversal_finished.connect(_on_traversal_finished)


## The view turned by `look` radians (x right, y down) this frame: the
## weapon trails behind the turn and swings back.
func add_look(look: Vector2) -> void:
	_look.value += Vector3(look.x, look.y, 0.0) * rad_to_deg(LOOK_LAG)
	_look.value = _look.value.limit_length(LOOK_LAG_MAX)


func _on_jumped() -> void:
	_kick_pose(Vector3(0.0, -0.02, 0.0), Vector3(-2.0, 0.0, 0.0))


func _on_landed(impact: float) -> void:
	var k := minf(impact * 0.004, 0.05)
	_kick_pose(Vector3(0.0, -k, 0.0), Vector3(-3.0 * k / 0.05, 0.0, 0.0))


func _on_slide_started() -> void:
	_kick_pose(Vector3(0.0, -0.02, 0.01), Vector3(-2.0, 0.0, -4.0))


func _on_traversal_finished(vault: bool) -> void:
	if not vault:
		_kick_pose(Vector3(0.0, -0.025, 0.0), Vector3(-3.0, 0.0, 0.0))


## A jolt that the pose springs carry through and settle (about `pos` and `rot` at its peak).
func _kick_pose(pos: Vector3, rot: Vector3) -> void:
	_pose_pos.kick(pos * KICK_GAIN)
	_pose_rot.kick(rot * KICK_GAIN)


## Shows `weapon`. If another weapon is up, it is lowered out of view first
## (WeaponController.LOWER_TIME), then the new one is raised over its equip_time.
func show_weapon(weapon: WeaponData) -> void:
	if _lowering and weapon == data:
		_lowering = false
		_pending = null
		return
	if model and data and weapon != data and is_visible_in_tree():
		_pending = weapon
		_lowering = true
		_kill_reload_tween()
		_reset_parts()
		return
	_build_model(weapon)


func _build_model(weapon: WeaponData) -> void:
	data = weapon
	_kill_reload_tween()
	if model:
		model.queue_free()
	model = weapon.viewmodel.instantiate() if weapon.viewmodel else _placeholder_model()
	_holder.add_child(model)
	model.position = Vector3.ZERO
	_disable_shadows(model)
	_muzzle = model.find_child("Muzzle", true, false) as Node3D
	var sight := model.find_child("SightPoint", true, false) as Node3D
	_sight_local = _local_to_model(sight) if sight else Vector3(0, 0.13, 0.05)
	_rest.clear()
	for part_name in ANIMATED_PARTS:
		var part := model.find_child(part_name, true, false) as Node3D
		if part:
			_rest[part_name] = {"node": part, "transform": part.transform}
	# "Root" tilts the whole weapon (and both hands) during reloads.
	_rest["Root"] = {"node": model, "transform": model.transform}
	_build_flash()
	WeaponCosmetics.apply(model, weapon, Cosmetics.weapon_loadout(weapon.id))
	_setup_reload_materials()
	_raise = 1.0
	_kick = 0.0


## Position of `node` in the model's own space (works before the first frame).
func _local_to_model(node: Node3D) -> Vector3:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n and n != model:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf.origin


func muzzle_position() -> Vector3:
	if _muzzle and is_instance_valid(_muzzle):
		return _muzzle.global_position
	return global_position + global_transform.basis * Vector3(0.25, -0.2, -0.8)


func on_fired(weapon: WeaponData) -> void:
	_kick = minf(_kick + weapon.view_kick, weapon.view_kick * 2.2)
	_kick_rot = minf(_kick_rot + weapon.recoil_kick * 1.6, 14.0)
	if weapon.beam:
		return
	_flash_time = 0.05
	if _flash:
		_flash.visible = Settings.flash_scale() > 0.05
		_flash.rotate_object_local(Vector3.UP, randf() * TAU)
		_flash.scale = Vector3.ONE * randf_range(0.85, 1.2) * lerpf(0.5, 1.0, Settings.flash_scale()) * (1.4 if weapon.pellets > 1 else 1.0)
	if _flash_light:
		_flash_light.visible = Settings.flash_scale() > 0.05
		_flash_light.light_energy = 3.0 * Settings.flash_scale()


func _process(delta: float) -> void:
	if data == null or model == null:
		return
	_time += delta
	if _lowering:
		_raise = move_toward(_raise, 1.0, delta / WeaponController.LOWER_TIME)
		if _raise >= 1.0:
			_lowering = false
			_build_model(_pending)
			_pending = null
			return
	else:
		_raise = move_toward(_raise, 0.0, delta / maxf(0.05, data.equip_time))
	_kick = lerpf(_kick, 0.0, 1.0 - exp(-14.0 * delta))
	_kick_rot = lerpf(_kick_rot, 0.0, 1.0 - exp(-12.0 * delta))
	var ease_raise := _raise * _raise
	# Aim down sights: square the gun up and slide it so the sight lands on the
	# exact screen centre. Motion and kick are damped so the sight picture holds.
	var aim := ease(player.ads if player else 0.0, -1.8)
	if _reload_tween and _reload_tween.is_valid():
		aim *= 0.25

	var pose_pos := _pose_pos.update(_pose_target_pos(), delta)
	var pose_rot := _pose_rot.update(_pose_target_rot(), delta)
	var look := _look.update(Vector3.ZERO, delta)
	var look_pos := Vector3(-look.x, look.y, 0.0) * 0.004
	var look_rot := Vector3(look.y, look.x, look.x * 0.8)
	var bob := _bob() * (1.0 - 0.85 * aim)
	var bob_pos := Vector3(bob.x, bob.y, 0.0)
	var charge := _weapon_state(delta)

	var hip_pos := data.view_position + bob_pos + charge + pose_pos + look_pos \
		+ Vector3(0.0, -ease_raise * 0.45, _kick)
	var hip_rot := data.view_rotation_degrees + pose_rot + look_rot \
		+ Vector3(_kick_rot + ease_raise * -35.0, 0.0, bob.z)
	var ads_pos := Vector3(0, 0, -data.ads_depth / VIEW_SCALE) - _sight_local \
		+ (look_pos + pose_pos * 0.5) * 0.3 + Vector3(0.0, 0.0, _kick * 0.5) + bob_pos * 0.15
	var ads_rot := Vector3(_kick_rot * 0.35, 0.0, 0.0) + (look_rot + pose_rot) * 0.1
	_holder.position = hip_pos.lerp(ads_pos + charge * 0.4, aim)
	_holder.rotation_degrees = hip_rot.lerp(ads_rot, aim)

	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			if _flash:
				_flash.visible = false
			if _flash_light:
				_flash_light.visible = false


## Where the movement poses pull the weapon (view units): sprint, slide,
## mantle or vault, a trail behind strafes and behind vertical speed.
func _pose_target_pos() -> Vector3:
	if player == null:
		return Vector3.ZERO
	var lv := player.local_velocity()
	var strafe := clampf(lv.x / player.walk_speed, -1.0, 1.0)
	var target := SPRINT_POS * player.sprint_amount \
		+ Vector3(-STRAFE_SHIFT * strafe, clampf(-lv.y * RISE_LAG, -RISE_LAG_MAX, RISE_LAG_MAX), 0.0)
	if player.sliding:
		target += SLIDE_POS
	if player.is_traversing():
		target += VAULT_POS if player.traversal_is_vault() else MANTLE_POS
	return target


func _pose_target_rot() -> Vector3:
	if player == null:
		return Vector3.ZERO
	var strafe := clampf(player.local_velocity().x / player.walk_speed, -1.0, 1.0)
	var target := SPRINT_ROT * player.sprint_amount + Vector3(0.0, 0.0, -STRAFE_ROLL * strafe)
	if player.sliding:
		target += SLIDE_ROT
	if player.is_traversing():
		target += VAULT_ROT if player.traversal_is_vault() else MANTLE_ROT
	return target


## Bob on the player's step rhythm: a side swing across each stride and a dip
## as each foot lands. x, y in view units; z is the roll in degrees.
func _bob() -> Vector3:
	if player == null:
		return Vector3.ZERO
	var phase := player.gait_phase
	var c := cos(phase)
	var size := player.gait_amount * (1.0 + 0.5 * player.sprint_amount)
	return Vector3(BOB_SIDE * sin(phase), BOB_DIP * (0.5 - c * c * c * c), BOB_ROLL * sin(phase)) * size


## Charge, heat and beam feedback. Returns the viewmodel offset for this frame
## (a pull-back and tremble while charging).
func _weapon_state(delta: float) -> Vector3:
	var w := player.weapons if player else null
	if w == null or w.current != data:
		return Vector3.ZERO
	var charge := w.charge_progress()
	var reloading := _reload_tween != null and _reload_tween.is_valid()
	if not reloading and (charge > 0.0 or data.uses_heat() or data.charge_time > 0.0):
		var flicker := 0.85 + 0.15 * sin(_time * 45.0)
		_set_glow(1.0 + charge * charge * 2.4 * flicker + w.heat() * 1.2)
	if w.is_beaming() and _flash:
		_flash.visible = Settings.flash_scale() > 0.05
		_flash.scale = Vector3.ONE * randf_range(0.5, 0.75) * lerpf(0.5, 1.0, Settings.flash_scale())
		_flash.rotate_object_local(Vector3.UP, delta * 9.0)
		_flash_time = 0.06
	var shake := charge * charge * 0.006
	return Vector3(randf_range(-shake, shake), randf_range(-shake, shake), charge * 0.035)


# --- reload animations ------------------------------------------------------
# Each weapon names a style in its data. A reload is a set of keyframe tracks
# on the model's named parts (offsets in the model's space, rotations in
# degrees about the part's own pivot), plus timed events: hologram build-up,
# glow ramps, steam and sparks. Times are fractions of the reload duration.

func play_reload(weapon: WeaponData, duration: float) -> void:
	_kill_reload_tween()
	_reset_parts()
	_reload_tween = create_tween().set_parallel(true)
	if weapon.reload_script:
		# Kept until the next reload so callbacks bound to it stay valid.
		_reload_player = weapon.reload_script.new()
		_reload_player.play(self, duration)
		return
	match weapon.reload_style:
		&"side_swap": _reload_vent_purge(duration)
		&"break_open": _reload_break_open(duration)
		_: _reload_holo_print(duration)


func cancel_reload() -> void:
	_kill_reload_tween()
	_reset_parts()


func _kill_reload_tween() -> void:
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()
	_reload_tween = null


func _reset_parts() -> void:
	for key in _rest:
		var entry: Dictionary = _rest[key]
		var node: Node3D = entry["node"]
		if is_instance_valid(node):
			node.transform = entry["transform"]
			node.visible = not String(key).ends_with("Holo")
	_set_glow(1.0)


func _setup_reload_materials() -> void:
	# Per-instance copies of every "Cell" glow surface so reloads can dim and
	# flare the energy without touching other weapons.
	_glow_mats.clear()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.name.ends_with("Holo"):
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.get_surface_override_material(i) as StandardMaterial3D
			if mat == null:
				mat = m.mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null or not (mat.resource_name == "Cell" or mat.emission_enabled and mat.resource_name.begins_with("Cell")):
				continue
			var copy: StandardMaterial3D = mat.duplicate()
			m.set_surface_override_material(i, copy)
			_glow_mats.append(copy)
			_glow_base = copy.emission_energy_multiplier
	_holo_mats.clear()
	for holo_name in ["CellHolo", "CapsulesHolo"]:
		var node := model.find_child(holo_name, true, false) as MeshInstance3D
		if node == null:
			continue
		var sm := ShaderMaterial.new()
		sm.shader = load(HOLO_SHADER)
		var tint: Color = _glow_mats[0].albedo_color if not _glow_mats.is_empty() else Color(0.35, 0.95, 1.0)
		sm.set_shader_parameter("holo_color", tint.lerp(Color.WHITE, 0.15))
		sm.set_shader_parameter("span", maxf(0.02, node.mesh.get_aabb().size.y * 0.55))
		node.material_override = sm
		node.visible = false
		_holo_mats[holo_name] = sm


## 1 = normal glow, 0 = dark, >1 = flare.
func _set_glow(k: float) -> void:
	for m in _glow_mats:
		m.emission_energy_multiplier = _glow_base * k


## `k` comes first so tween_method can drive it with the part name bound.
func _set_holo(k: float, part_name: String) -> void:
	if _holo_mats.has(part_name):
		_holo_mats[part_name].set_shader_parameter("materialize", k)


func _part(part_name: String) -> Node3D:
	return _rest[part_name]["node"] if _rest.has(part_name) else null


func _pose(part_name: String, offset: Vector3, rot_deg: Vector3, scale_k := 1.0) -> Transform3D:
	var rest: Transform3D = _rest[part_name]["transform"]
	var b := rest.basis * Basis.from_euler(rot_deg * (PI / 180.0))
	return Transform3D(b.scaled_local(Vector3.ONE * scale_k), rest.origin + offset)


## Keyframe track: keys = [[t, offset, rot_deg, (scale)], ...], t in 0-1 of d.
## The pose before the first key is the rest pose.
func _track(part_name: String, d: float, keys: Array, trans := Tween.TRANS_SINE, ease_type := Tween.EASE_IN_OUT) -> void:
	var node := _part(part_name)
	if node == null:
		return
	var prev_t := 0.0
	var prev := _pose(part_name, Vector3.ZERO, Vector3.ZERO)
	for k in keys:
		var t: float = k[0]
		var to := _pose(part_name, k[1], k[2], k[3] if k.size() > 3 else 1.0)
		var dur := maxf(0.001, (t - prev_t) * d)
		if k.size() > 4 and k[4] == "hold":
			# Jump straight to the pose at time t (after holding the previous one).
			_reload_tween.tween_callback(func(): if is_instance_valid(node): node.transform = to).set_delay(t * d)
		else:
			_reload_tween.tween_property(node, "transform", to, dur).from(prev).set_delay(prev_t * d).set_trans(trans).set_ease(ease_type)
		prev_t = t
		prev = to


func _at(t: float, d: float, fn: Callable) -> void:
	_reload_tween.tween_callback(fn).set_delay(t * d)


func _glow_ramp(t0: float, t1: float, d: float, from_k: float, to_k: float) -> void:
	_reload_tween.tween_method(_set_glow, from_k, to_k, maxf(0.001, (t1 - t0) * d)).set_delay(t0 * d)


func _holo_build(part_name: String, t0: float, t1: float, d: float) -> void:
	var node := _part(part_name)
	if node == null:
		return
	_at(t0, d, func(): node.visible = true; _set_holo(0.0, part_name))
	_reload_tween.tween_method(_set_holo.bind(part_name), 0.0, 1.0, maxf(0.001, (t1 - t0) * d)).set_delay(t0 * d)


## Swap a hologram for the real part: hide the holo, show the solid one, flare.
func _solidify(holo: String, solid: String, t: float, d: float) -> void:
	_at(t, d, func():
		var h := _part(holo)
		var s := _part(solid)
		if h:
			h.visible = false
		if s:
			s.transform = _rest[solid]["transform"]
			s.visible = true
		Sfx.play(&"reload_materialize", -6.0, randf_range(0.97, 1.05)))
	_glow_ramp(t, t + 0.12, d, 3.2, 1.0)


## A puff of steam or a shower of sparks at a named empty, in the model's space.
func _burst(t: float, d: float, anchor: String, kind: String) -> void:
	_at(t, d, func():
		var a := model.find_child(anchor, true, false) as Node3D if model else null
		if a == null:
			return
		var origin := _local_to_model(a)
		var b := FxBurst.new()
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(b)
		if kind == "steam":
			b.setup(origin, Vector3(-0.3, 1, 0), [Color(1, 1, 1), Color(1.0, 0.8, 0.95), Color(0.8, 0.95, 1.0)],
				14, 0.35, 0.7, 0.035, 35.0, Vector3(0, 0.25, 0), _burst_mesh())
			Sfx.play(&"reload_vent", -7.0, randf_range(0.95, 1.05))
		else:
			b.setup(origin, Vector3(0, -1, 0.3), [Color(0.4, 1.0, 1.0), Color.WHITE, Color(1.0, 0.5, 0.85)],
				12, 0.9, 0.35, 0.012, 70.0, Vector3(0, -2.0, 0), _burst_mesh()))


static var _burst_mesh_cache: Mesh


static func _burst_mesh() -> Mesh:
	if _burst_mesh_cache == null:
		var q := BoxMesh.new()
		q.size = Vector3.ONE
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		q.material = m
		_burst_mesh_cache = q
	return _burst_mesh_cache


# --- public reload API (for WeaponData.reload_script) -------------------------
# A custom reload script looks like:
#   extends RefCounted
#   func play(v: WeaponView, d: float) -> void:
#       v.track("Cell", d, [[0.2, Vector3(0, -0.3, 0), Vector3(0, 0, 90)], [0.6, Vector3.ZERO, Vector3.ZERO]])
#       v.burst(0.25, d, "VentPoint", "steam")
# Times are fractions (0-1) of the reload duration d. Offsets are in the
# model's own space; rotations are degrees about the part's own pivot.

func track(part: String, d: float, keys: Array, trans := Tween.TRANS_SINE, ease_type := Tween.EASE_IN_OUT) -> void:
	_track(part, d, keys, trans, ease_type)


func at(t: float, d: float, fn: Callable) -> void:
	_at(t, d, fn)


func glow_ramp(t0: float, t1: float, d: float, from_k: float, to_k: float) -> void:
	_glow_ramp(t0, t1, d, from_k, to_k)


func holo_build(part: String, t0: float, t1: float, d: float) -> void:
	_holo_build(part, t0, t1, d)


func solidify(holo_part: String, solid_part: String, t: float, d: float) -> void:
	_solidify(holo_part, solid_part, t, d)


## kind: "steam" or "sparks"; anchor: an empty in the model (EjectPoint, VentPoint, Muzzle...).
func burst(t: float, d: float, anchor: String, kind: String) -> void:
	_burst(t, d, anchor, kind)


func hide_part(t: float, d: float, part: String) -> void:
	_at(t, d, func(): var p := _part(part); if p: p.visible = false)


func has_part(part: String) -> bool:
	return _rest.has(part)


## Register extra animated parts (beyond ANIMATED_PARTS) for a custom model.
func register_part(part: String) -> void:
	if _rest.has(part) or model == null:
		return
	var node := model.find_child(part, true, false) as Node3D
	if node:
		_rest[part] = {"node": node, "transform": node.transform}


## Pulse Pistol "holo-print": the support hand lets go, the spent cell drops
## out of the grip and spins away, a new one is printed as a hologram and
## slides up into the grip, solidifies with a flare, and the slide snaps home.
func _reload_holo_print(d: float) -> void:
	_track("Root", d, [[0.14, Vector3(0, 0.02, 0), Vector3(14, 6, -26)], [0.78, Vector3(0, 0.02, 0), Vector3(14, 6, -26)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	_track("Slide", d, [[0.1, Vector3(0, 0, 0.055), Vector3.ZERO], [0.8, Vector3(0, 0, 0.055), Vector3.ZERO],
		[0.86, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_IN)
	_track("Hammer", d, [[0.1, Vector3.ZERO, Vector3(-40, 0, 0)], [0.82, Vector3.ZERO, Vector3(-40, 0, 0)], [0.9, Vector3.ZERO, Vector3.ZERO]])
	_glow_ramp(0.08, 0.2, d, 1.0, 0.15)
	# Straight down the grip first (the grip leans 14 degrees), then it tumbles away.
	_track("Cell", d, [[0.14, Vector3.ZERO, Vector3.ZERO], [0.27, Vector3(0, -0.2, 0.05), Vector3.ZERO],
		[0.42, Vector3(0, -0.46, 0.16), Vector3(360, 0, 90), 0.7]], Tween.TRANS_QUAD, Tween.EASE_IN)
	_burst(0.16, d, "EjectPoint", "sparks")
	_at(0.42, d, func(): var c := _part("Cell"); if c: c.visible = false)
	_track("CellHolo", d, [[0.44, Vector3(0, -0.2, 0.05), Vector3.ZERO, 1.0, "hold"], [0.62, Vector3(0, -0.2, 0.05), Vector3.ZERO],
		[0.74, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_holo_build("CellHolo", 0.44, 0.7, d)
	_solidify("CellHolo", "Cell", 0.76, d)
	_burst(0.84, d, "VentPoint", "steam")
	# The support hand slides forward off the firing hand, drops away, and comes back the same way.
	_track("ArmL", d, [[0.1, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO], [0.22, Vector3(-0.15, -0.16, 0.0), Vector3(0, 0, -12)],
		[0.72, Vector3(-0.15, -0.16, 0.0), Vector3(0, 0, -12)], [0.84, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO],
		[0.94, Vector3.ZERO, Vector3.ZERO]])


## Ion Carbine "vent purge": vents flip up and blow steam, the cage swings
## open, the spent cell spins out sideways, a hologram cell slides in and
## solidifies, the cage slams shut and the coils light one by one.
func _reload_vent_purge(d: float) -> void:
	_track("Root", d, [[0.14, Vector3(0.02, 0.02, 0), Vector3(-6, 22, 28)], [0.82, Vector3(0.02, 0.02, 0), Vector3(-6, 22, 28)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	_track("Vents", d, [[0.14, Vector3.ZERO, Vector3(-70, 0, 0)], [0.86, Vector3.ZERO, Vector3(-70, 0, 0)], [0.94, Vector3.ZERO, Vector3.ZERO]],
		Tween.TRANS_BACK, Tween.EASE_OUT)
	_burst(0.16, d, "VentPoint", "steam")
	_burst(0.3, d, "VentPoint", "steam")
	_glow_ramp(0.12, 0.3, d, 1.0, 0.1)
	_track("Panel", d, [[0.2, Vector3.ZERO, Vector3.ZERO], [0.34, Vector3.ZERO, Vector3(0, 0, 115)], [0.78, Vector3.ZERO, Vector3(0, 0, 115)],
		[0.84, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	_track("Cell", d, [[0.36, Vector3.ZERO, Vector3.ZERO], [0.56, Vector3(-0.34, -0.05, 0.0), Vector3(0, 0, 0), 0.8]], Tween.TRANS_QUAD, Tween.EASE_IN)
	# The support hand drops off the foregrip, reaches out under the cell, and returns the same way.
	_track("ArmL", d, [[0.2, Vector3.ZERO, Vector3.ZERO], [0.3, Vector3(0, -0.11, 0.02), Vector3.ZERO], [0.42, Vector3(-0.22, -0.13, 0.05), Vector3.ZERO],
		[0.54, Vector3(-0.3, -0.07, 0.05), Vector3.ZERO], [0.74, Vector3(-0.22, -0.13, 0.05), Vector3.ZERO],
		[0.86, Vector3(0, -0.11, 0.02), Vector3.ZERO], [0.95, Vector3.ZERO, Vector3.ZERO]])
	_burst(0.42, d, "EjectPoint", "sparks")
	_at(0.56, d, func(): var c := _part("Cell"); if c: c.visible = false)
	_track("CellHolo", d, [[0.57, Vector3(-0.22, 0, 0), Vector3.ZERO, 1.0, "hold"], [0.74, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_holo_build("CellHolo", 0.57, 0.74, d)
	_solidify("CellHolo", "Cell", 0.76, d)
	_at(0.84, d, func(): Sfx.play(&"reload_clunk", -4.0); var p := owner as Player; if p: p.add_shake(0.08))
	# Coils light one after another.
	_glow_ramp(0.86, 0.93, d, 0.6, 2.6)
	_glow_ramp(0.93, 1.0, d, 2.6, 1.0)


## Scatter Blaster "break open": the barrels drop on their hinge, both spent
## capsules kick out, new ones print in, the drum spins up, the action slams
## shut and the pump racks twice (the support hand rides the pump: ArmL is
## its child).
func _reload_break_open(d: float) -> void:
	_track("Root", d, [[0.12, Vector3(0, 0.03, 0.02), Vector3(10, 10, -14)], [0.66, Vector3(0, 0.03, 0.02), Vector3(10, 10, -14)],
		[0.8, Vector3.ZERO, Vector3.ZERO]])
	_track("Barrels", d, [[0.14, Vector3.ZERO, Vector3(-38, 0, 0)], [0.64, Vector3.ZERO, Vector3(-38, 0, 0)], [0.7, Vector3.ZERO, Vector3.ZERO]],
		Tween.TRANS_BACK, Tween.EASE_OUT)
	_glow_ramp(0.1, 0.22, d, 1.0, 0.1)
	_track("Capsules", d, [[0.18, Vector3.ZERO, Vector3.ZERO], [0.36, Vector3(0, 0.22, 0.2), Vector3(220, 0, 0), 0.8]], Tween.TRANS_QUAD, Tween.EASE_OUT)
	_burst(0.19, d, "EjectPoint", "sparks")
	_at(0.36, d, func(): var c := _part("Capsules"); if c: c.visible = false)
	_holo_build("CapsulesHolo", 0.38, 0.58, d)
	_solidify("CapsulesHolo", "Capsules", 0.6, d)
	_track("Drum", d, [[0.6, Vector3.ZERO, Vector3.ZERO], [0.78, Vector3.ZERO, Vector3(360, 0, 0)]], Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_at(0.62, d, func(): Sfx.play(&"reload_spin", -6.0))
	_at(0.7, d, func(): Sfx.play(&"reload_clunk", -2.0); var p := owner as Player; if p: p.add_shake(0.12))
	_burst(0.71, d, "VentPoint", "steam")
	for i in 2:
		var t0 := 0.74 + i * 0.12
		_track("Pump", d, [[t0, Vector3.ZERO, Vector3.ZERO, 1.0, "hold"], [t0 + 0.05, Vector3(0, 0, 0.068), Vector3.ZERO], [t0 + 0.11, Vector3.ZERO, Vector3.ZERO]],
			Tween.TRANS_QUAD, Tween.EASE_OUT)


# --- helpers ------------------------------------------------------------------

func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)


static var _flash_texture: ImageTexture


## Six-pointed star with a white-hot centre, drawn once and shared.
static func _star_texture() -> ImageTexture:
	if _flash_texture:
		return _flash_texture
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / n * 2.0 - Vector2.ONE
			var r := p.length()
			var a := atan2(p.y, p.x)
			var rays := pow(absf(cos(a * 3.0)), 6.0) * 0.55
			var shape := clampf(1.0 - r / (0.45 + rays), 0.0, 1.0)
			var core := clampf(1.0 - r / 0.32, 0.0, 1.0)
			var v := clampf(shape * shape + core, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, v))
	_flash_texture = ImageTexture.create_from_image(img)
	return _flash_texture


func _build_flash() -> void:
	_flash = null
	_flash_light = null
	if _muzzle == null:
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _star_texture()
	mat.albedo_color = data.tracer_color.lerp(Color.WHITE, 0.35) * 1.6
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.42)
	_flash = MeshInstance3D.new()
	_flash.mesh = quad
	_flash.material_override = mat
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	_muzzle.add_child(_flash)
	# The quad faces back along the barrel, i.e. toward the camera.
	_flash.rotation_degrees = Vector3(90, 0, 0)
	var side := MeshInstance3D.new()
	side.mesh = quad
	side.material_override = mat
	side.scale = Vector3(0.55, 1.6, 1.0)
	side.position = Vector3(0, 0.12, 0)
	side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.add_child(side)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = data.tracer_color
	_flash_light.omni_range = 6.0
	_flash_light.visible = false
	_muzzle.add_child(_flash_light)


func _placeholder_model() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.16, 0.5)
	body.mesh = box
	body.name = "Shell"
	root.add_child(body)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.02, -0.3)
	root.add_child(muzzle)
	return root
