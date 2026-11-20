class_name TinRallyFlag
extends Node3D
## The Tin Sergeant's "Fall in!" flag (TinSergeantMode): a red swallowtail
## pennant on a brass pole planted at the rally point, a gold ring on the
## floor marking the ground the squad guards (TinSoldier.RALLY_GUARD) and a
## FALL IN! sign that pops up when it is planted. It springs up out of the
## floor, waves, and sinks away over the rally's last second.

const POLE_HEIGHT := 1.1
const RISE_TIME := 0.3
const GOLD := Color(0.95, 0.76, 0.23)
const RED := Color(0.89, 0.27, 0.23)

var _pole: Node3D
var _cloth: Node3D
var _ring: MeshInstance3D
var _label: Label3D
var _up := 0.0
var _clock := 0.0
var _sign := 0.0


func _ready() -> void:
	top_level = true
	_pole = Node3D.new()
	add_child(_pole)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.022
	stick.bottom_radius = 0.026
	stick.height = POLE_HEIGHT
	stick.radial_segments = 10
	_pole.add_child(_mesh(stick, _lit(GOLD, 0.8), Vector3(0.0, POLE_HEIGHT * 0.5, 0.0)))
	var ball := SphereMesh.new()
	ball.radius = 0.055
	ball.height = 0.11
	ball.radial_segments = 12
	ball.rings = 6
	_pole.add_child(_mesh(ball, _lit(GOLD, 0.8), Vector3(0.0, POLE_HEIGHT + 0.03, 0.0)))
	var flag := BoxMesh.new()
	flag.size = Vector3(0.5, 0.3, 0.012)
	_cloth = Node3D.new()
	_cloth.position = Vector3(0.0, POLE_HEIGHT - 0.17, 0.0)
	_pole.add_child(_cloth)
	_cloth.add_child(_mesh(flag, _lit(RED, 0.0, 0.35), Vector3(0.27, 0.0, 0.0)))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.97
	ring.outer_radius = 1.0
	ring.rings = 56
	ring.ring_segments = 4
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(GOLD, 0.5)
	_ring = _mesh(ring, glow, Vector3(0.0, 0.05, 0.0))
	_ring.scale = Vector3(TinSoldier.RALLY_GUARD, 1.0, TinSoldier.RALLY_GUARD)
	add_child(_ring)
	_label = Label3D.new()
	_label.text = "FALL IN!"
	_label.font = UiKit.display_font()
	_label.font_size = 96
	_label.pixel_size = 0.004
	_label.outline_size = 18
	_label.modulate = GOLD
	_label.outline_modulate = Color(0.12, 0.08, 0.2)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0.0, POLE_HEIGHT + 0.45, 0.0)
	add_child(_label)
	for node in find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


## Shows the flag at `at` (Vector3.INF hides it); `left` is the seconds the
## rally still holds; `planted` is true on the frame it is (re)planted.
func show_at(at: Vector3, left: float, planted: bool, delta: float) -> void:
	if at == Vector3.INF:
		visible = false
		_up = 0.0
		return
	if not visible:
		_up = 0.0
		_sign = 0.0
	visible = true
	if planted:
		_sign = 1.2
	_clock += delta
	_up = minf(1.0, _up + delta / RISE_TIME)
	_sign = maxf(0.0, _sign - delta)
	var fade := clampf(left, 0.0, 1.0)
	var rise := _ease_out_back(_up) * fade
	global_position = at
	_pole.scale = Vector3(1.0, maxf(0.01, rise), 1.0)
	_cloth.rotation.y = 0.25 * sin(_clock * 6.0)
	_cloth.scale = Vector3(1.0 + 0.06 * sin(_clock * 9.0), 1.0, 1.0)
	var spread := TinSoldier.RALLY_GUARD * lerpf(0.4, 1.0 + 0.015 * sin(_clock * 3.0), minf(1.0, _up * 1.5))
	_ring.scale = Vector3(spread, 1.0, spread)
	_ring.transparency = 1.0 - fade
	_label.visible = _sign > 0.0
	_label.scale = Vector3.ONE * _ease_out_back(clampf((1.2 - _sign) / 0.25, 0.0, 1.0))
	_label.modulate.a = clampf(_sign / 0.3, 0.0, 1.0)


static func _mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = material
	m.position = at
	return m


static func _lit(color: Color, metal: float, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.35
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m


static func _ease_out_back(u: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(u - 1.0, 3.0) + c * pow(u - 1.0, 2.0)
