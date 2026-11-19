extends MeleeView
## High Striker viewmodel (art/models/high_striker.glb): the strongman mallet.
##
##   puck   rides the painted scale on the handle (Puck slides along the
##          handle, local -Z): it creeps up as the heavy winds up, jumps a
##          little on every light hit and, when a slam lands
##          (HighStrikerMode.slams), flies to the top and rings the bell,
##          then slides back down
##   bell   shakes when rung (DING), and tinkles on the draw
## Swings are slow and heavy: long wind-ups, a hard snap through, a slow
## recovery; the heavy is a straight overhead slam.

const PUCK_SOUND := &"hstrk_puck"
const DING_SOUND := &"hstrk_ding"
## The puck's travel along the handle (model units, from the build script).
const PUCK_TRAVEL := 0.325
## Share of the scale a full wind-up and a light hit push the puck up.
const WINDUP_RISE := 0.6
const HIT_RISE := 0.22
## Seconds for the puck to fly to the bell, how long it stays, how fast it slides back (share/s).
const FLY_TIME := 0.22
const HOLD_TIME := 0.5
const SLIDE_RATE := 1.4
## Bell shake: degrees and how fast it dies (1/s).
const BELL_SHAKE := 18.0
const BELL_DECAY := 5.0
const STRIKER_LIGHT_KEYS := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.28, Vector3(0.14, 0.08, 0.08), Vector3(18.0, -10.0, -38.0)],
	[0.5, Vector3(-0.14, -0.12, -0.1), Vector3(-34.0, 34.0, 16.0)],
	[0.66, Vector3(-0.28, -0.24, -0.02), Vector3(-46.0, 44.0, 20.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]
const STRIKER_HEAVY_KEYS := [
	[0.0, Vector3(-0.04, 0.03, -0.1), Vector3(-10.0, -60.0, 10.0)],
	[0.2, Vector3(-0.04, -0.08, -0.16), Vector3(-55.0, 4.0, 8.0)],
	[0.42, Vector3(-0.06, -0.16, -0.08), Vector3(-66.0, 8.0, 12.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]

var _puck: Node3D
var _bell: Node3D
var _level := 0.0
var _fly := -1.0
var _hold := 0.0
var _ring := 0.0
var _slams := 0
var _hits := 0


func setup(view: WeaponView) -> void:
	super.setup(view)
	view.register_part("Puck")
	view.register_part("Bell")
	_puck = view.part("Puck")
	_bell = view.part("Bell")
	var mode := _mode(view)
	_slams = int(mode.get("slams")) if mode and mode.get("slams") != null else 0
	_hits = mode.hits if mode else 0
	_ring = 0.6 if view.player else 0.0


func light_keys() -> Array:
	return STRIKER_LIGHT_KEYS


func heavy_keys() -> Array:
	return STRIKER_HEAVY_KEYS


## The draw: hauled up from below with a heavy overshoot.
func equip_pose(view: WeaponView, t: float) -> Array:
	var length := maxf(0.1, view.data.equip_time + 0.25)
	if t >= length:
		return [Vector3.ZERO, Vector3.ZERO]
	var u := t / length
	var k := 1.0 - ease_out(u)
	var over := sin(u * PI) * 0.5 * (1.0 - u)
	return [Vector3(0.04 * k, -0.25 * k, 0.0), Vector3(-40.0 * k + 6.0 * over, 0.0, -20.0 * k)]


func part_motion(view: WeaponView, mode: MeleeMode, delta: float) -> void:
	if mode:
		var slams := int(mode.get("slams")) if mode.get("slams") != null else 0
		if slams != _slams:
			_slams = slams
			_fly = 0.0
			if view.is_visible_in_tree():
				Sfx.play(PUCK_SOUND, -6.0, randf_range(0.97, 1.03))
		if mode.hits != _hits:
			_hits = mode.hits
			if mode.phase == MeleeMode.Phase.LIGHT:
				_level = minf(1.0, _level + HIT_RISE)
	var goal := 0.0
	if _fly >= 0.0:
		_fly += delta
		_level = lerpf(_level, 1.0, clampf(_fly / FLY_TIME, 0.0, 1.0))
		if _fly >= FLY_TIME:
			_fly = -1.0
			_level = 1.0
			_hold = HOLD_TIME
			_ring = 1.0
			if view.is_visible_in_tree():
				Sfx.play(DING_SOUND, -3.0, 1.0)
	elif _hold > 0.0:
		_hold -= delta
	elif mode and mode.phase == MeleeMode.Phase.WINDUP:
		goal = WINDUP_RISE * mode.charge
		_level = maxf(_level, goal)
	else:
		_level = maxf(goal, _level - SLIDE_RATE * delta)
	if _puck:
		_puck.transform = view.rest_transform("Puck") * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -PUCK_TRAVEL * _level))
	_ring = maxf(0.0, _ring - delta * 0.8)
	if _bell:
		var shake := BELL_SHAKE * _ring * _ring * sin(_time * 38.0) * exp(-BELL_DECAY * (1.0 - _ring))
		_bell.transform = view.rest_transform("Bell") * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(shake)), Vector3.ZERO)
