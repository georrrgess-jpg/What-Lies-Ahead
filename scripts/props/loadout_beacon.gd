class_name LoadoutBeacon
extends Node3D
## Makes the loadout station impossible to miss while it is open: a light
## column visible across the map, two counter-rotating holo rings and a
## floating "LOADOUT" sign. Hidden during waves. Built in code so every
## kiosk in every world gets the same treatment.

const BEAM_HEIGHT := 34.0

var _rings: Array[Node3D] = []
var _sign: Label3D
var _beam: MeshInstance3D
var _time := 0.0
var _open := false
var _fade := 0.0


func _ready() -> void:
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = load("res://art/shaders/beacon.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, BEAM_HEIGHT)
	for i in 3:
		_beam = MeshInstance3D.new()
		_beam.mesh = quad
		_beam.material_override = beam_mat
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beam.position = Vector3(0, 6.8 + BEAM_HEIGHT * 0.5, 0)
		_beam.rotation.y = PI * i / 3.0
		add_child(_beam)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(1.0, 0.78, 0.3)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	for i in 2:
		var torus := TorusMesh.new()
		torus.inner_radius = 2.1 + i * 0.7
		torus.outer_radius = torus.inner_radius + 0.12
		torus.rings = 48
		torus.ring_segments = 6
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = ring_mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position = Vector3(0, 9.4 + i * 0.9, 0)
		ring.rotation_degrees = Vector3(8 if i == 0 else -8, 0, 0)
		add_child(ring)
		_rings.append(ring)
	_sign = Label3D.new()
	_sign.text = "LOADOUT"
	_sign.font = UiKit.display_font()
	_sign.font_size = 160
	_sign.pixel_size = 0.012
	_sign.modulate = Color(1.0, 0.82, 0.3)
	_sign.outline_modulate = Color(0.25, 0.05, 0.25)
	_sign.outline_size = 36
	_sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sign.position = Vector3(0, 11.2, 0)
	_sign.render_priority = 5
	add_child(_sign)
	var sub := Label3D.new()
	sub.text = "AMMO  ·  HEAL  ·  SWAP"
	sub.font = UiKit.body_font()
	sub.font_size = 72
	sub.pixel_size = 0.012
	sub.modulate = Color(0.4, 0.95, 1.0)
	sub.outline_modulate = Color(0.1, 0.03, 0.2)
	sub.outline_size = 22
	sub.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sub.position = Vector3(0, 10.25, 0)
	add_child(sub)
	_apply(0.0)


func set_open(value: bool) -> void:
	_open = value


func _process(delta: float) -> void:
	_time += delta
	_fade = move_toward(_fade, 1.0 if _open else 0.0, delta * 2.5)
	_apply(_fade)
	if _fade <= 0.0:
		return
	_rings[0].rotation.y += delta * 0.9
	_rings[1].rotation.y -= delta * 0.6
	_sign.position.y = 11.2 + sin(_time * 1.8) * 0.15


func _apply(k: float) -> void:
	visible = k > 0.001
	scale = Vector3(1.0, lerpf(0.4, 1.0, ease(k, -2.0)), 1.0)
