extends MeleeView
## Glow Blade viewmodel (art/models/glow_blade.glb): a neon switchblade.
##
## Equip: the fist comes up rolled in with the blade folded into the handle,
## the thumb hits the flip-button and the blade flicks open on its hinge
## (Blade, about X) past open and back, the edge flaring. The edge's glow halo
## (BladeEdge) is a translucent additive glow in the colour of the edge core
## (the model's Cell, so a cell cosmetic recolours it); it brightens with a
## heavy's wind-up and flashes when a swing connects or the blade locks.
## Slashes are quick alternating diagonals turned about a point down the
## forearm, so the forearm stays low in the corner and the blade sweeps the
## frame; the heavy is a coiled wind-up over the shoulder and a lunging
## diagonal rip with a snap on release. The smear is the edge's colour.
##
## Inspect: one of three knife tricks (never the same twice running), played
## on "Knife" (everything but the hand) and the Blade: a toss and catch end
## over end, a barrel twirl popped out of the fist, and a snap shut and flick
## open with a light-up flourish.

const FLICK_SOUND := &"glb_flick"
## Folded angle of the blade (degrees about X) and when the flick happens
## (seconds after the model is built, i.e. while it rises).
const FOLDED := -172.0
const FLICK_AT := 0.14
const FLICK_TIME := 0.15
## The edge's colour when the model's Cell can't be read, and its rest glow.
const EDGE_COLOR := Color(0.18, 0.94, 1.0)
const EDGE_GLOW := 1.25
## The swings turn about a point PIVOT_SHARE of the way from the grip to the
## elbow (ElbowR), on the forearm's own line: the forearm stays in the lower
## right corner on its own axis while the hand and blade sweep the frame.
const PIVOT_SHARE := 0.6
## Light slash: cocked up and right, ripped down to the lower left on a
## diagonal, a follow-through and back (mirrored every other swing).
const GLOW_LIGHT_KEYS := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.14, Vector3(0.01, 0.015, 0.01), Vector3(8.0, -9.0, -10.0)],
	[0.36, Vector3(-0.02, -0.02, -0.03), Vector3(-10.0, 16.0, 17.0)],
	[0.58, Vector3(-0.03, -0.035, -0.02), Vector3(-14.0, 20.0, 21.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]
## Heavy, from the wind-up: a lunging diagonal rip across the body, the arm
## driving forward, held through and drawn back.
const GLOW_HEAVY_KEYS := [
	[0.0, Vector3(-0.03, 0.03, 0.015), Vector3(18.0, -6.0, -8.0)],
	[0.2, Vector3(-0.03, -0.02, -0.07), Vector3(-14.0, 19.0, 21.0)],
	[0.42, Vector3(-0.05, -0.05, -0.05), Vector3(-20.0, 25.0, 27.0)],
	[0.62, Vector3(-0.04, -0.04, -0.025), Vector3(-16.0, 20.0, 21.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]
## Idle: every IDLE_FLICK_EVERY seconds at rest the thumb flicks the blade half
## shut and snaps it open again (IDLE_FLICK_TIME long, IDLE_FLICK_ANGLE deep).
const IDLE_FLICK_EVERY := 5.5
const IDLE_FLICK_TIME := 0.5
const IDLE_FLICK_ANGLE := -110.0
## Inspect tricks: their lengths (seconds) and where the knife turns about in
## a toss (its middle, model space: the handle runs along Z, the blade to -Z).
const TRICK_LENGTHS := [2.6, 2.6, 2.7]
const KNIFE_MIDDLE := Vector3(0.0, 0.0, -0.06)
## The toss: when it leaves the fist and is caught (seconds), and how high it
## flies along the blade (model units; it clears the fist before it turns).
const TOSS := Vector2(0.8, 1.5)
const TOSS_HEIGHT := 0.23
## The inspect's own poses (see WeaponInspect.POSES): it stays close to the
## hold (view_rotation_degrees), drawn in toward the middle and turned a little
## to show the flat, so the forearm stays low in the corner and the knife and
## its trick are the show.
const TRICK_POSES := [
	[0.0, Vector3(0.15, -0.09, -0.46), Vector3(55.4, 32.0, -26.7)],
	[0.22, Vector3(0.09, -0.07, -0.46), Vector3(50.0, 40.0, -16.0)],
	[0.78, Vector3(0.09, -0.07, -0.46), Vector3(52.0, 42.0, -14.0)],
	[1.0, Vector3(0.15, -0.09, -0.46), Vector3(55.4, 32.0, -26.7)],
]
const TRICK_SOUND := &"glb_flick"

## The last trick played (shared by every Glow Blade view), so the next differs.
static var _last_trick := -1

var _knife: Node3D
var _blade: Node3D
var _buttons: Node3D
var _edge_mat: StandardMaterial3D
## The Blade mesh's Cell surface (the edge core): its colour tints the halo.
var _core_mesh: MeshInstance3D
var _core_surface := -1
var _edge_color := EDGE_COLOR
## The swing pivot in view units and axes (see PIVOT_SHARE).
var _pivot := Vector3(0.1, -0.25, 0.12)
var _flicked := false
var _flash := 0.0
var _hits := 0
var _phase := MeleeMode.Phase.IDLE
## Seconds at rest (the idle flick's clock) and how far through a flick it is (0-1, -1 none).
var _rest_time := 0.0
var _idle_flick := -1.0
## The running trick (-1 none) and which of its cues have played.
var _trick := -1
var _cues := 0


func setup(view: WeaponView) -> void:
	super.setup(view)
	for part_name in ["Knife", "Blade", "Buttons"]:
		view.register_part(part_name)
	_knife = view.part("Knife")
	_blade = view.part("Blade")
	_buttons = view.part("Buttons")
	_flicked = false
	_find_core(_blade as MeshInstance3D)
	var elbow := view.model.find_child("ElbowR", true, false) as Node3D
	if elbow:
		var hold := Basis.from_euler(view.data.view_rotation_degrees * (PI / 180.0))
		var at := elbow.position
		var n := elbow.get_parent() as Node3D
		while n and n != view.model:
			at = n.transform * at
			n = n.get_parent() as Node3D
		_pivot = hold * at * PIVOT_SHARE
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
	return _pivot


## Coiled back over the shoulder, the point tipped back and the wrist cocked,
## creeping further as it charges.
func windup_pose(charge: float) -> Array:
	var k := 1.0 - pow(1.0 - minf(1.0, charge * 2.2), 3.0)
	var start: Array = GLOW_HEAVY_KEYS[0]
	return [start[1] * k + Vector3(0.005, 0.005, 0.012) * charge, start[2] * k + Vector3(5.0, -3.0, -3.0) * charge]


## A breathing sway with a lazy wrist roll, plus a little roll into each idle flick.
func idle_pose(t: float) -> Array:
	var pose := super.idle_pose(t)
	pose[1] += Vector3(sin(t * 0.8) * 1.5, 0.0, sin(t * 0.55 + 1.0) * 3.0)
	if _idle_flick >= 0.0:
		pose[1] += Vector3(0.0, 0.0, -14.0 * sin(_idle_flick * PI))
	return pose


## The equip: the fist rises rolled in and turns out as the blade flicks open.
func equip_pose(view: WeaponView, t: float) -> Array:
	var length := view.data.equip_time + FLICK_AT + FLICK_TIME + 0.12
	if t >= length:
		return [Vector3.ZERO, Vector3.ZERO]
	var k := _back_out(clampf(t / length, 0.0, 1.0))
	var turn := 1.0 - k
	return [Vector3(0.0, -0.03 * turn, 0.02 * turn), Vector3(18.0 * turn, -10.0 * turn, -34.0 * turn)]


func part_motion(view: WeaponView, mode: MeleeMode, delta: float) -> void:
	if _blade == null:
		return
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
	if _trick < 0:
		_blade.transform = view.rest_transform("Blade") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(angle)), Vector3.ZERO)
	if _buttons:
		var press := clampf(1.0 - absf(_equip - FLICK_AT) / 0.08, 0.0, 1.0)
		_press_button(view, press)
	if mode:
		if mode.hits != _hits:
			_hits = mode.hits
			_flash = 1.0
		# The release snap: a flare as the heavy leaves the wind-up.
		if mode.phase == MeleeMode.Phase.HEAVY and _phase == MeleeMode.Phase.WINDUP:
			_flash = maxf(_flash, 0.8)
		_phase = mode.phase
	_flash = maxf(0.0, _flash - delta * 4.0)
	var charge := mode.charge if mode and mode.phase != MeleeMode.Phase.IDLE else 0.0
	var pulse := 0.08 * sin(_time * 5.0)
	_read_core_color()
	_set_edge(EDGE_GLOW + pulse + charge * 1.2 + _flash * 1.8)


## The idle flick's blade angle this frame (0 when not flicking); it only
## runs at rest, well after the draw, and a swing cuts it off.
func _idle_flick_angle(mode: MeleeMode, delta: float) -> float:
	var resting := mode != null and mode.phase == MeleeMode.Phase.IDLE and not mode.is_busy() and _equip > 1.5 and _trick < 0
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
	return _edge_color


# --- inspect tricks ---------------------------------------------------------------------

func inspect_length() -> float:
	var pick := randi() % 3
	if pick == _last_trick:
		pick = (pick + 1 + randi() % 2) % 3
	_last_trick = pick
	_trick = pick
	return TRICK_LENGTHS[pick]


func inspect_poses() -> Array:
	return TRICK_POSES


func inspect_start(_v: WeaponView) -> void:
	_cues = 0


## Every frame of the trick, `t` seconds in: poses the knife against the
## still fist (and the blade on its hinge), after part_motion.
func inspect(v: WeaponView, t: float) -> void:
	if _trick < 0 or _knife == null:
		return
	var knife := Transform3D.IDENTITY
	var blade := 0.0
	match _trick:
		0:
			knife = _toss(v, t)
		1:
			knife = _twirl(v, t)
		_:
			blade = _snap(v, t)
			knife = _snap_knife(t)
	_knife.transform = v.rest_transform("Knife") * knife
	_blade.transform = v.rest_transform("Blade") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(blade)), Vector3.ZERO)


func inspect_end(v: WeaponView) -> void:
	_trick = -1
	if _knife:
		_knife.transform = v.rest_transform("Knife")
	_press_button(v, 0.0)


## Toss and catch: the knife pops up out of the fist along its blade, turns
## once end over end about its middle while clear of the hand, and drops
## back into the fist with a flare as it is caught.
func _toss(v: WeaponView, t: float) -> Transform3D:
	var flight := clampf((t - TOSS.x) / (TOSS.y - TOSS.x), 0.0, 1.0)
	var lift := TOSS_HEIGHT * 4.0 * flight * (1.0 - flight)
	var spin := -TAU * MeleeView.ease_in_out((flight - 0.22) / 0.56)
	_cue(v, t, [TOSS.x, TOSS.y], [1.0, 1.15])
	if t > TOSS.y and _cues & 4 == 0:
		_cues |= 4
		_flash = 1.0
	var turn := Basis(Vector3.RIGHT, spin)
	return Transform3D(turn, KNIFE_MIDDLE - turn * KNIFE_MIDDLE + Vector3(0.0, 0.0, -lift))


## Barrel twirl: the knife slides half out of the fist, leans out and spins
## three times about its handle (the blade flashing flat, edge, flat), and is
## pushed home.
func _twirl(v: WeaponView, t: float) -> Transform3D:
	var out := WeaponInspect.window(t, 0.5, 0.75) * (1.0 - WeaponInspect.window(t, 1.75, 2.0))
	var spin := MeleeView.ease_in_out(clampf((t - 0.7) / 1.1, 0.0, 1.0))
	_cue(v, t, [0.78, 1.78], [1.0, 1.1])
	if t > 1.8 and _cues & 4 == 0:
		_cues |= 4
		_flash = 1.0
	var lean := Basis(Vector3.RIGHT, -0.2 * out)
	return Transform3D(lean * Basis(Vector3.BACK, spin * TAU * 3.0), Vector3(0.0, 0.0, -0.1 * out))


## Snap and flick: the blade snaps shut into the handle, the closed knife
## rocks in the fist while the lights chase, then flicks open past the lock
## with a burst of sparks off the edge. Returns the blade's angle.
func _snap(v: WeaponView, t: float) -> float:
	var shut := MeleeView.ease_out(clampf((t - 0.55) / 0.14, 0.0, 1.0))
	var open := _back_out(clampf((t - 1.7) / 0.16, 0.0, 1.0))
	_press_button(v, WeaponInspect.hump(t, 1.62, 1.78))
	_cue(v, t, [0.55, 1.7], [0.85, 1.12])
	if t > 1.84 and _cues & 4 == 0:
		_cues |= 4
		_flash = 1.6
		if _base:
			v.spark_burst(WeaponInspect.in_model(v, _base), Vector3.UP, [_edge_color, Color.WHITE], 18, 0.9, 0.35, 0.006)
	# The lights chase while it is shut.
	if t > 0.7 and t < 1.7:
		_flash = maxf(_flash, 0.5 + 0.5 * sin(t * 26.0))
	return FOLDED * shut * (1.0 - open)


## The closed knife rocks a quarter turn each way in the fist.
func _snap_knife(t: float) -> Transform3D:
	var rock := sin(clampf((t - 0.8) / 0.8, 0.0, 1.0) * TAU) * WeaponInspect.hump(t, 0.75, 1.65)
	return Transform3D(Basis(Vector3.BACK, rock * 0.9), Vector3.ZERO)


## Plays the trick's two sounds once each, at times `at` with pitches `pitch`.
func _cue(v: WeaponView, t: float, at: Array, pitch: Array) -> void:
	for i in 2:
		if t >= float(at[i]) and _cues & (1 << i) == 0:
			_cues |= 1 << i
			if v.is_visible_in_tree():
				Sfx.play(TRICK_SOUND, -6.0, float(pitch[i]))


# --- helpers ---------------------------------------------------------------------------

func _press_button(view: WeaponView, press: float) -> void:
	if _buttons:
		_buttons.transform = view.rest_transform("Buttons") * Transform3D(Basis.IDENTITY, Vector3(0.0025 * press, 0.0, 0.0))


## Finds the Cell surface of the Blade mesh (the edge core).
func _find_core(blade: MeshInstance3D) -> void:
	if blade == null or blade.mesh == null:
		return
	for i in blade.mesh.get_surface_count():
		var m := blade.mesh.surface_get_material(i)
		if m and m.resource_name == "Cell":
			_core_mesh = blade
			_core_surface = i
			return


## The edge core's colour now (a cell cosmetic's tint, animated ones included).
func _read_core_color() -> void:
	if _core_mesh == null:
		return
	var m := _core_mesh.get_active_material(_core_surface) as StandardMaterial3D
	if m:
		_edge_color = m.emission if m.emission_enabled else m.albedo_color


func _set_edge(k: float) -> void:
	if _edge_mat:
		_edge_mat.albedo_color = Color(_edge_color * k, clampf(0.55 + 0.15 * k, 0.0, 1.0))


## Overshoots open a little and settles back (the lock catching).
static func _back_out(t: float) -> float:
	var s := 1.7
	var x := clampf(t, 0.0, 1.0) - 1.0
	return x * x * ((s + 1.0) * x + s) + 1.0
