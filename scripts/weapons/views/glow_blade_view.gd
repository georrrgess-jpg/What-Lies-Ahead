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
## The swings turn about the shoulder (SHOULDER, from the grip in view
## units), so the forearm stays low and the blade sweeps the frame.
const SHOULDER := Vector3(0.12, -0.3, 0.55)
## Light slash: a diagonal cut from high right to low left across the frame.
const GLOW_LIGHT_KEYS := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.16, Vector3(0.04, 0.04, 0.03), Vector3(16.0, -16.0, -22.0)],
	[0.38, Vector3(-0.04, -0.02, -0.08), Vector3(-14.0, 24.0, 26.0)],
	[0.56, Vector3(-0.06, -0.04, -0.04), Vector3(-24.0, 34.0, 32.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]
## Heavy: wound up high over the shoulder, then a big chop down through the middle.
const GLOW_HEAVY_KEYS := [
	[0.0, Vector3(0.02, 0.05, 0.06), Vector3(30.0, -10.0, -24.0)],
	[0.24, Vector3(-0.03, -0.03, -0.1), Vector3(-26.0, 18.0, 20.0)],
	[0.46, Vector3(-0.05, -0.05, -0.05), Vector3(-38.0, 26.0, 26.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]
## Idle: every IDLE_FLICK_EVERY seconds at rest the thumb flicks the blade half
## shut and snaps it open again (IDLE_FLICK_TIME long, IDLE_FLICK_ANGLE deep).
const IDLE_FLICK_EVERY := 5.5
const IDLE_FLICK_TIME := 0.5
const IDLE_FLICK_ANGLE := -110.0

var _blade: Node3D
var _buttons: Node3D
var _edge_mat: StandardMaterial3D
var _flicked := false
var _flash := 0.0
var _hits := 0
## Seconds at rest (the idle flick's clock) and how far through a flick it is (0-1, -1 none).
var _rest_time := 0.0
var _idle_flick := -1.0


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


func heavy_keys() -> Array:
	return GLOW_HEAVY_KEYS


func swing_pivot() -> Vector3:
	return SHOULDER


## The shared sway, plus a little wrist roll into each idle flick.
func idle_pose(t: float) -> Array:
	var pose := super.idle_pose(t)
	if _idle_flick >= 0.0:
		pose[1] += Vector3(0.0, 0.0, -14.0 * sin(_idle_flick * PI))
	return pose


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
		angle += _idle_flick_angle(mode, delta)
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


## The idle flick's blade angle this frame (0 when not flicking); it only
## runs at rest, well after the draw, and a swing cuts it off.
func _idle_flick_angle(mode: MeleeMode, delta: float) -> float:
	var resting := mode != null and mode.phase == MeleeMode.Phase.IDLE and not mode.is_busy() and _equip > 1.5
	if not resting:
		_rest_time = 0.0
		_idle_flick = -1.0
		return 0.0
	_rest_time += delta
	if _idle_flick < 0.0 and _rest_time >= IDLE_FLICK_EVERY:
		_rest_time = 0.0
		_idle_flick = 0.0
	if _idle_flick < 0.0:
		return 0.0
	_idle_flick += delta / IDLE_FLICK_TIME
	if _idle_flick >= 1.0:
		_idle_flick = -1.0
		return 0.0
	# Half shut fast, then snapped open past the lock and back.
	if _idle_flick < 0.35:
		return IDLE_FLICK_ANGLE * MeleeView.ease_out(_idle_flick / 0.35)
	var k := _back_out((_idle_flick - 0.35) / 0.65)
	if k > 0.95 and _flash < 0.5:
		_flash = 0.7
	return IDLE_FLICK_ANGLE * (1.0 - k)


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
