extends MeleeView
## Glow Blade viewmodel (art/models/glow_blade.glb): a neon switchblade.
##
## Equip: the blade comes up folded into the handle and the thumb flicks it
## open on its hinge (Blade, about X) with a snap past open and back, the two
## arcade buttons click in and the edge flares. The edge (BladeEdge) is a
## translucent additive glow that brightens with a heavy's wind-up and flashes
## when a swing connects. Slashes are quick and flat, and the smear is the
## edge's cyan.

const FLICK_SOUND := &"glb_flick"
## Folded angle of the blade (degrees about X) and when the flick happens
## (seconds after the model is built, i.e. while it rises).
const FOLDED := -172.0
const FLICK_AT := 0.1
const FLICK_TIME := 0.16
const EDGE_COLOR := Color(0.55, 0.97, 1.0)
const EDGE_GLOW := 1.25
## Light slashes: flatter and quicker than the shared arcs.
const GLOW_LIGHT_KEYS := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.14, Vector3(0.1, 0.08, 0.02), Vector3(6.0, -16.0, -26.0)],
	[0.38, Vector3(-0.22, 0.01, -0.1), Vector3(-12.0, 22.0, 32.0)],
	[0.56, Vector3(-0.33, -0.07, -0.02), Vector3(-15.0, 30.0, 40.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]

var _blade: Node3D
var _buttons: Node3D
var _edge_mat: StandardMaterial3D
var _flicked := false
var _flash := 0.0
var _hits := 0


func setup(view: WeaponView) -> void:
	super.setup(view)
	view.register_part("Blade")
	view.register_part("Buttons")
	_blade = view.part("Blade")
	_buttons = view.part("Buttons")
	_flicked = false
	var edge := view.model.find_child("BladeEdge", true, false) as MeshInstance3D
	if edge:
		_edge_mat = StandardMaterial3D.new()
		_edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_edge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_edge_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_edge_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		edge.material_override = _edge_mat
		_set_edge(EDGE_GLOW)
	# Menus and stills (no player) show it open.
	if view.player == null:
		_flicked = true


func light_keys() -> Array:
	return GLOW_LIGHT_KEYS


## The equip: no twirl, the flick open is the show (part_motion).
func equip_pose(view: WeaponView, t: float) -> Array:
	var length := view.data.equip_time + FLICK_TIME
	if t >= length:
		return [Vector3.ZERO, Vector3.ZERO]
	# A small wrist turn into the flick and back.
	var k := sin(clampf(t / length, 0.0, 1.0) * PI)
	return [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -22.0 * k)]


func part_motion(view: WeaponView, mode: MeleeMode, delta: float) -> void:
	if _blade == null:
		return
	var rest := view.rest_transform("Blade")
	var angle := 0.0
	if view.player != null:
		var t := _equip - FLICK_AT
		if t < 0.0:
			angle = FOLDED
		elif t < FLICK_TIME:
			angle = lerpf(FOLDED, 0.0, _back_out(t / FLICK_TIME))
		if t >= 0.0 and not _flicked:
			_flicked = true
			_flash = 1.0
			if view.is_visible_in_tree():
				Sfx.play(FLICK_SOUND, -3.0, randf_range(0.97, 1.03))
	_blade.transform = rest * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(angle)), Vector3.ZERO)
	if _buttons:
		var press := clampf(1.0 - absf(_equip - FLICK_AT) / 0.08, 0.0, 1.0)
		_buttons.transform = view.rest_transform("Buttons") * Transform3D(Basis.IDENTITY, Vector3(0.0025 * press, 0.0, 0.0))
	if mode and mode.hits != _hits:
		_hits = mode.hits
		_flash = 1.0
	_flash = maxf(0.0, _flash - delta * 4.0)
	var charge := mode.charge if mode and mode.phase != MeleeMode.Phase.IDLE else 0.0
	var pulse := 0.08 * sin(_time * 5.0)
	_set_edge(EDGE_GLOW + pulse + charge * 1.2 + _flash * 1.6)


func trail_color(_view: WeaponView) -> Color:
	return EDGE_COLOR


func _set_edge(k: float) -> void:
	if _edge_mat:
		_edge_mat.albedo_color = Color(EDGE_COLOR * k, clampf(0.55 + 0.15 * k, 0.0, 1.0))


## Overshoots open a little and settles back (the lock catching).
static func _back_out(t: float) -> float:
	var s := 1.7
	var x := clampf(t, 0.0, 1.0) - 1.0
	return x * x * ((s + 1.0) * x + s) + 1.0
