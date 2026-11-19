class_name LavaLampoonView
extends RefCounted
## Lava Lampoon viewmodel motion (WeaponData.view_script):
##   lamp      the glass is drawn by art/shaders/lava_lampoon_lamp.gdshader:
##             its wax blobs count the magazine (one blob per ROUNDS_PER_BLOB,
##             the last one shrinking as it is spent), climb and glow brighter
##             with the warm-up groove (LavaLampoonMode.groove) and pulse with
##             every shot
##   wobble    each shot rocks the lamp back on its socket and rattles the
##             cap; it settles on a spring
##   display   the holographic lamp icons on the left flank (Pip0..9), one per blob
##   prompt    the active-reload prompt over the lamp ("TAP R", then GROOVY!),
##             shown by the reload (scripts/weapons/reloads/lava_lampoon_reload.gd)
## Inspect: the lamp is held up to the eye and the wax gets its groove on:
## the blobs heat up and swirl round and up the glass, glow ripples run up it
## twice, the gun sways to the beat and the cap bobs.
## The lamp takes the colour of the equipped energy cell (dress_lamp), in
## first person and in every menu preview.
## The static helpers here are shared with the reload, which poses the same
## parts while it runs.

const LAMP_SHADER := "res://art/shaders/lava_lampoon_lamp.gdshader"
const HOLO_SHADER := "res://art/shaders/holo.gdshader"
const ROUNDS_PER_BLOB := 3.0
const PIPS := 10
const PROMPT := "LavaPrompt"
const RING_TEAL := Color(0.3, 1.0, 0.92)
## Shot wobble: kick (degrees), spring stiffness and damping.
const WOBBLE_KICK := 5.0
const WOBBLE_K := 220.0
const WOBBLE_DAMP := 11.0
const CAP_RATTLE := 0.004
const INSPECT_LENGTH := 3.0
const INSPECT_POSES := [
	[0.0, Vector3(0.14, -0.14, -0.62), Vector3(2.0, 12.0, -4.0)],
	[0.16, Vector3(0.06, -0.16, -0.56), Vector3(4.0, 44.0, 4.0)],
	[0.5, Vector3(0.05, -0.17, -0.54), Vector3(2.0, 36.0, -2.0)],
	[0.8, Vector3(0.06, -0.16, -0.56), Vector3(6.0, 48.0, 2.0)],
	[1.0, Vector3(0.14, -0.15, -0.62), Vector3(2.0, 6.0, 0.0)],
]
const PARTS: Array[String] = ["Lamp", "LampGlass", "LampCap", "LampRingHolo"]

var _lamp: Node3D
var _cap: Node3D
var _glass: MeshInstance3D
var _mat: ShaderMaterial
var _pips: Array[Node3D] = []
var _prompt: Label3D
var _heat := 0.0
var _flare := 0.0
var _wobble := Vector2.ZERO
var _wobble_vel := Vector2.ZERO
var _rattle := 0.0


func setup(v: WeaponView) -> void:
	register(v)
	_lamp = v.part("Lamp")
	_cap = v.part("LampCap")
	_glass = v.part("LampGlass") as MeshInstance3D
	_mat = glass_material(v)
	for i in PIPS:
		_pips.append(v.part("Pip%d" % i))
	var ring := v.part("LampRingHolo") as MeshInstance3D
	if ring:
		var holo := ShaderMaterial.new()
		holo.shader = load(HOLO_SHADER)
		holo.set_shader_parameter("holo_color", RING_TEAL)
		holo.set_shader_parameter("span", 0.01)
		ring.material_override = holo
		ring.visible = false
	_prompt = _build_prompt(v)


func fired(_v: WeaponView) -> void:
	_flare = 1.0
	_wobble_vel += Vector2(-WOBBLE_KICK * randf_range(0.8, 1.2), WOBBLE_KICK * randf_range(-0.5, 0.5)) * 12.0
	_rattle = 1.0


func event(_v: WeaponView, _event_name: StringName) -> void:
	pass


func update(v: WeaponView, delta: float) -> void:
	var w := weapons_of(v)
	var mode := w.mode as LavaLampoonMode if w else null
	_heat = move_toward(_heat, mode.groove if mode else 0.0, delta * (4.0 if mode and mode.groove > _heat else 1.5))
	_flare = maxf(0.0, _flare - delta * 7.0)
	if v.is_reloading() or _mat == null:
		return
	_prompt.visible = false
	var mag := w.magazine() if w else v.data.magazine_size
	set_lamp(_mat, _glass, mag / ROUNDS_PER_BLOB, _heat, 0.0, 0.0, -1.0, _flare)
	show_pips(_pips, ceili(mag / ROUNDS_PER_BLOB))
	_update_wobble(v, delta)


func inspect_length() -> float:
	return INSPECT_LENGTH


func inspect_poses() -> Array:
	return INSPECT_POSES


func inspect_start(_v: WeaponView) -> void:
	Sfx.play(&"weap_lava_groovy", -9.0)


func inspect(v: WeaponView, t: float) -> void:
	if _mat == null:
		return
	var groove := WeaponInspect.hump(t, 0.2, 2.8)
	var w := weapons_of(v)
	var mag := w.magazine() if w else v.data.magazine_size
	var ripple := -1.0
	for start in [0.9, 1.6]:
		if t >= start and t < start + 0.6:
			ripple = (t - start) / 0.6
	set_lamp(_mat, _glass, mag / ROUNDS_PER_BLOB, maxf(_heat, groove), 0.0, groove, ripple, 0.25 * groove * (0.5 + 0.5 * sin(t * 9.0)))
	# Sways to the beat (about two beats a second) and the cap bobs on it.
	var beat := sin(t * PI * 2.0) * groove
	v.model.transform = v.rest_transform("Root") * Transform3D(Basis(Vector3.BACK, deg_to_rad(6.0 * beat)), Vector3(0.0, 0.004 * absf(beat), 0.0))
	if _cap:
		var cap_rest := v.rest_transform("LampCap")
		_cap.transform = Transform3D(cap_rest.basis, cap_rest.origin + Vector3.UP * 0.003 * absf(sin(t * PI * 4.0)) * groove)


func inspect_end(v: WeaponView) -> void:
	if v.model:
		v.model.transform = v.rest_transform("Root")


## The lamp rocks on its socket after each shot and the cap rattles.
func _update_wobble(v: WeaponView, delta: float) -> void:
	_wobble_vel += (-_wobble * WOBBLE_K - _wobble_vel * WOBBLE_DAMP) * delta
	_wobble += _wobble_vel * delta
	_rattle = maxf(0.0, _rattle - delta * 9.0)
	if _lamp:
		var rest := v.rest_transform("Lamp")
		var tilt := Basis.from_euler(Vector3(deg_to_rad(_wobble.x), 0.0, deg_to_rad(_wobble.y)))
		_lamp.transform = Transform3D(rest.basis * tilt, rest.origin)
	if _cap:
		var cap_rest := v.rest_transform("LampCap")
		var hop := absf(sin(_rattle * 9.0)) * _rattle * CAP_RATTLE
		_cap.transform = Transform3D(cap_rest.basis, cap_rest.origin + Vector3.UP * hop)


func _build_prompt(v: WeaponView) -> Label3D:
	var label := Label3D.new()
	label.name = PROMPT
	label.text = prompt_text()
	label.font_size = 64
	label.outline_size = 14
	label.pixel_size = 0.00045
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.modulate = Color(1.0, 0.86, 0.3)
	label.outline_modulate = Color(0.35, 0.05, 0.25)
	label.render_priority = 10
	label.outline_render_priority = 9
	label.visible = false
	v.model.add_child(label)
	return label


# --- shared with the reload ---------------------------------------------------------

## Registers the lamp's moving parts with the view.
static func register(v: WeaponView) -> void:
	for part in PARTS:
		v.register_part(part)
	for i in PIPS:
		v.register_part("Pip%d" % i)


## The held weapon's controller when the view shows that weapon (null in previews).
static func weapons_of(v: WeaponView) -> WeaponController:
	if v.player and v.player.weapons and v.player.weapons.current == v.data:
		return v.player.weapons
	return null


## The lamp glass's wax shader, made on first use.
static func glass_material(v: WeaponView) -> ShaderMaterial:
	return _lamp_material(v.part("LampGlass") as MeshInstance3D)


static func _lamp_material(glass: MeshInstance3D) -> ShaderMaterial:
	if glass == null:
		return null
	if glass.material_override is ShaderMaterial:
		return glass.material_override
	var m := ShaderMaterial.new()
	m.shader = load(LAMP_SHADER)
	glass.material_override = m
	return m


## Fills a Lava Lampoon model's lamp (first person and every menu preview)
## with the live wax, in the colour of the equipped energy cell `cell` (the
## classic orange and magenta without one). WeaponCosmetics.apply calls this
## for every model; models without a lamp are left alone.
static func dress_lamp(model: Node3D, cell: CosmeticItem) -> void:
	var glass := model.find_child("LampGlass", true, false) as MeshInstance3D
	if glass == null:
		return
	var wax := model.find_child("LampWax", true, false) as Node3D
	if wax:
		wax.visible = false
	var tint := Color(0, 0, 0, 0)
	if cell:
		tint = WeaponCosmetics.cell_glow_color(cell.color(0))
		tint.a = 1.0
	_lamp_material(glass).set_shader_parameter("tint", tint)


## Sets every wax parameter; gravity comes from the glass's place in the world.
static func set_lamp(m: ShaderMaterial, glass: Node3D, blobs: float, heat: float, gather: float, swirl: float, ripple: float, flare: float) -> void:
	m.set_shader_parameter("count", blobs)
	m.set_shader_parameter("heat", heat)
	m.set_shader_parameter("gather", gather)
	m.set_shader_parameter("swirl", swirl)
	m.set_shader_parameter("ripple", ripple)
	m.set_shader_parameter("flare", flare)
	if glass and glass.is_inside_tree():
		m.set_shader_parameter("down", (glass.global_transform.basis.inverse() * Vector3.DOWN).normalized())


static func show_pips(pips: Array[Node3D], lit: int) -> void:
	for i in pips.size():
		if pips[i]:
			pips[i].visible = i < lit


## "TAP R" with the key the reload action is bound to.
static func prompt_text() -> String:
	var key := "R"
	if InputMap.has_action(&"reload"):
		for e in InputMap.action_get_events(&"reload"):
			if e is InputEventKey:
				var k := e as InputEventKey
				key = OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
				break
	return "TAP %s" % key
