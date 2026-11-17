class_name PopcornPopperView
extends RefCounted
## Popcorn Popper viewmodel motion (WeaponData.view_script), read from the
## held weapon's PopcornPopperMode:
##   dial      the heat dial's needle follows the kettle's heat (cold to the
##             red jam line), quivers once it runs hot and judders, pinned,
##             through a jam
##   kettle    the silver kettle glows from cold steel to orange as it heats;
##             a jam throbs it red
##   lid       each shot hops the lid on its hinge; it chatters harder the
##             hotter the kettle gets and rattles wildly through a jam, when
##             the whole gun shudders too
##   steam     puffs from the whistle, faster with the heat; a jam blows a
##             plume
##   dome      the popcorn in the glass dome is the magazine: one layer per
##             ROUNDS_PER_LAYER kernels, the top one shrinking as it is spent;
##             each shot jumps the top layers
##   muzzle    warm and hot shots spit popcorn flakes from the horn
## The static helpers here are shared with the reload
## (scripts/weapons/reloads/popcorn_popper_reload.gd), which poses the lid,
## the dome and the holograms while it runs; the dial and the glow carry on.

const HOLO_SHADER := "res://art/shaders/holo.gdshader"
const LAYERS := 8
const PARTS: Array[String] = ["Lid", "HeatNeedle", "Kernels", "ScoopHolo", "PourHolo", "ButterHolo", "DrizzleHolo"]
const HOLOS: Array[String] = ["ScoopHolo", "PourHolo", "ButterHolo", "DrizzleHolo"]
const HOLO_COLOR := Color(1.0, 0.74, 0.18)
## The dial's normal in the model (Godot axes) and the needle's sweep (degrees either side of up).
const DIAL_NORMAL := Vector3(-0.62, 0.55, 0.56)
const NEEDLE_SWEEP := 125.0
## Lid: degrees it hops per shot, how far it chatters when hot and jammed, its spring.
const LID_HOP := 7.0
const LID_K := 520.0
const LID_DAMP := 16.0
const KETTLE_GLOW := Color(1.0, 0.42, 0.12)
const JAM_GLOW := Color(1.0, 0.16, 0.1)
const STEAM := [Color(1.0, 1.0, 1.0, 0.85), Color(0.92, 0.94, 1.0, 0.8), Color(1.0, 0.97, 0.9, 0.8)]
const FLAKES := [Color(1.0, 0.98, 0.9), Color(1.0, 0.9, 0.55), Color(1.0, 0.82, 0.35)]
const BUTTER := [Color(1.0, 0.85, 0.3), Color(1.0, 0.7, 0.18), Color(1.0, 0.96, 0.62)]

var _needle: Node3D
var _lid: Node3D
var _layers: Array[Node3D] = []
var _kettle_mats: Array[StandardMaterial3D] = []
var _heat := 0.0
var _lid_angle := 0.0
var _lid_vel := 0.0
var _hop := 0.0
var _hop_vel := 0.0
var _steam := 0.0
var _time := 0.0
var _shuddering := false
var _muzzle_at := Vector3.ZERO
var _vent_at := Vector3.ZERO


func setup(v: WeaponView) -> void:
	register(v)
	_needle = v.part("HeatNeedle")
	_lid = v.part("Lid")
	_layers = layers(v)
	_kettle_mats = kettle_materials(v)
	holo_materials(v)
	_muzzle_at = model_point(v, "Muzzle")
	_vent_at = model_point(v, "VentPoint")


func fired(v: WeaponView) -> void:
	_lid_vel += LID_HOP * 40.0 * randf_range(0.7, 1.2)
	_hop_vel += 0.35
	var mode := mode_of(v)
	if mode == null:
		return
	match mode.stage():
		PopcornPopperMode.Stage.WARM:
			v.spark_burst(_muzzle_at, Vector3.FORWARD, FLAKES, 2, 0.8, 0.18, 0.006)
		PopcornPopperMode.Stage.HOT:
			v.spark_burst(_muzzle_at, Vector3.FORWARD, BUTTER, 3, 1.0, 0.2, 0.007)


func event(_v: WeaponView, _event_name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	_time += delta
	var mode := mode_of(v)
	var target := mode.heat if mode else 0.0
	var jammed := mode != null and mode.jam > 0.0
	_heat = move_toward(_heat, target, delta * 2.5)
	_pose_needle(v, jammed)
	_glow(jammed)
	_puff_steam(v, delta, jammed)
	if v.is_reloading():
		_shudder(v, false)
		return
	_pose_lid(v, delta, jammed)
	_shudder(v, jammed)
	var w := weapons_of(v)
	var mag := w.magazine() if w else v.data.magazine_size
	show_popcorn(_layers, v, float(mag) / v.data.magazine_size * LAYERS, _bounce(delta))


func _pose_needle(v: WeaponView, jammed: bool) -> void:
	if _needle == null:
		return
	var quiver := sin(_time * 47.0) * 2.5 * smoothstep(0.7, 1.0, _heat)
	if jammed:
		quiver = sin(_time * 61.0) * 5.0 + sin(_time * 23.0) * 3.0
	var deg := lerpf(-NEEDLE_SWEEP, NEEDLE_SWEEP, 1.0 if jammed else _heat) + quiver
	var rest := v.rest_transform("HeatNeedle")
	_needle.transform = Transform3D(Basis(DIAL_NORMAL.normalized(), deg_to_rad(-deg)) * rest.basis, rest.origin)


## The lid: a spring kicked by every shot, chattering with the heat, wild through a jam.
func _pose_lid(v: WeaponView, delta: float, jammed: bool) -> void:
	if _lid == null:
		return
	var chatter := smoothstep(0.55, 1.0, _heat) * 2.0 * absf(sin(_time * 38.0))
	if jammed:
		chatter = 9.0 * absf(sin(_time * 29.0)) + 4.0 * absf(sin(_time * 71.0))
	_lid_vel += (-_lid_angle * LID_K - _lid_vel * LID_DAMP) * delta
	_lid_angle = maxf(0.0, _lid_angle + _lid_vel * delta)
	if _lid_angle <= 0.0 and _lid_vel < 0.0:
		_lid_vel = -_lid_vel * 0.3
	pose_lid(v, _lid_angle + chatter)


## A jam shudders the whole gun (the model about its rest pose).
func _shudder(v: WeaponView, on: bool) -> void:
	if not on and not _shuddering:
		return
	_shuddering = on
	var rest := v.rest_transform("Root")
	if not on:
		v.model.transform = rest
		return
	var r := Vector3(sin(_time * 53.0), sin(_time * 41.0 + 1.0), sin(_time * 67.0 + 2.0)) * 1.2
	v.model.transform = Transform3D(rest.basis * Basis.from_euler(r * (PI / 180.0)), rest.origin + Vector3(0.0, sin(_time * 59.0) * 0.0015, 0.0))


func _glow(jammed: bool) -> void:
	var k := smoothstep(0.3, 1.0, _heat)
	var col := KETTLE_GLOW
	var energy := k * k * 1.6
	if jammed:
		col = JAM_GLOW
		energy = 1.4 + 0.8 * sin(_time * 14.0)
	for m in _kettle_mats:
		m.emission = col
		m.emission_energy_multiplier = energy


## Steam from the whistle: a puff every so often, more as it heats; a plume when jammed.
func _puff_steam(v: WeaponView, delta: float, jammed: bool) -> void:
	var rate := 0.0 if _heat < PopcornPopperMode.WARM_AT else lerpf(2.0, 9.0, smoothstep(PopcornPopperMode.WARM_AT, 1.0, _heat))
	if jammed:
		rate = 26.0
	_steam += rate * delta
	if _steam < 1.0:
		return
	_steam = fmod(_steam, 1.0)
	v.spark_burst(_vent_at, Vector3.UP, STEAM, 3 if jammed else 1, 0.9 if jammed else 0.45, 0.5, 0.007 if jammed else 0.005)


## The dome's top layers jump with each shot and settle.
func _bounce(delta: float) -> float:
	_hop_vel += (-_hop * 600.0 - _hop_vel * 22.0) * delta
	_hop += _hop_vel * delta
	return _hop * 0.004


# --- shared with the reload ---------------------------------------------------------

## Where the empty `anchor` sits in the model's own space (works before the first frame).
static func model_point(v: WeaponView, anchor: String) -> Vector3:
	var node := v.model.find_child(anchor, true, false) as Node3D if v.model else null
	var at := Vector3.ZERO
	while node and node != v.model:
		at = node.transform * at
		node = node.get_parent() as Node3D
	return at


## Registers the moving parts with the view.
static func register(v: WeaponView) -> void:
	for part in PARTS:
		v.register_part(part)
	for i in LAYERS:
		v.register_part("PopLayer%d" % i)


## The held weapon's controller when the view shows that weapon (null in previews).
static func weapons_of(v: WeaponView) -> WeaponController:
	if v.player and v.player.weapons and v.player.weapons.current == v.data:
		return v.player.weapons
	return null


static func mode_of(v: WeaponView) -> PopcornPopperMode:
	var w := weapons_of(v)
	return w.mode as PopcornPopperMode if w else null


static func layers(v: WeaponView) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for i in LAYERS:
		out.append(v.part("PopLayer%d" % i))
	return out


## The lid turned `deg` open on its hinge at the kettle's front (the back
## edge, toward the player, rises).
static func pose_lid(v: WeaponView, deg: float) -> void:
	var lid := v.part("Lid")
	if lid:
		var rest := v.rest_transform("Lid")
		lid.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-deg)) * rest.basis, rest.origin)


## The dome shows `fill` layers of popcorn (fractional: the top one shrinks),
## the top layers lifted by `hop` metres.
static func show_popcorn(dome: Array[Node3D], v: WeaponView, fill: float, hop: float) -> void:
	for i in dome.size():
		var layer := dome[i]
		if layer == null:
			continue
		var k := clampf(fill - i, 0.0, 1.0)
		layer.visible = k > 0.0
		if not layer.visible:
			continue
		var rest := v.rest_transform("PopLayer%d" % i)
		var lift := hop * clampf(1.0 - (fill - 1.0 - i) * 0.5, 0.0, 1.0)
		var w := lerpf(0.55, 1.0, k)
		layer.transform = Transform3D(rest.basis.scaled(Vector3(w, lerpf(0.4, 1.0, k), w)), rest.origin + Vector3.UP * lift)


## Per-instance copies of the kettle's steel, so its glow is this gun's own.
static func kettle_materials(v: WeaponView) -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	for mi in v.model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var base := m.get_surface_override_material(i)
			if base == null:
				base = m.mesh.surface_get_material(i)
			if base == null or base.resource_name != "Kettle" or not base is StandardMaterial3D:
				continue
			var copy := base.duplicate() as StandardMaterial3D
			copy.emission_enabled = true
			copy.emission_energy_multiplier = 0.0
			m.set_surface_override_material(i, copy)
			out.append(copy)
	return out


## The holograms' shader, made once per model; they start hidden.
static func holo_materials(v: WeaponView) -> void:
	for part in HOLOS:
		var node := v.part(part) as MeshInstance3D
		if node == null or node.material_override is ShaderMaterial:
			continue
		var holo := ShaderMaterial.new()
		holo.shader = load(HOLO_SHADER)
		holo.set_shader_parameter("holo_color", HOLO_COLOR)
		holo.set_shader_parameter("span", maxf(0.02, node.mesh.get_aabb().size.y * 0.6))
		holo.set_shader_parameter("materialize", 0.0)
		holo.set_shader_parameter("intensity", 0.9)
		node.material_override = holo
		node.visible = false


static func set_holo(v: WeaponView, part: String, k: float) -> void:
	var node := v.part(part) as MeshInstance3D
	if node == null:
		return
	node.visible = k > 0.001
	var holo := node.material_override as ShaderMaterial
	if holo:
		holo.set_shader_parameter("materialize", k)
