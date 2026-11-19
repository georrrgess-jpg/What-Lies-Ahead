extends MeleeView
## Ticket Flipper viewmodel (art/models/ticket_flipper.glb): a balisong.
##
## Its flip is one number, the flip angle `a` (degrees): the blade turns `a`
## about HandleA's pin (Blade.x) while HandleB turns back -a about its own pin,
## so a = 180 is shut (the blade in the handles' channels) and every multiple
## of 360 is open again. The latch on HandleA's butt swings out while the
## knife is anywhere but open.
##   equip   drawn shut, it flips open twice (a 180 -> 900) and the latch snaps
##   idle    every few seconds at rest it flips shut and open again (a fidget)
##   wind-up the heavy's wind-up flips it constantly, faster as it charges;
##           the lunge then settles it open
## A pin clack (tflip_flip) sounds each time it passes open or shut.

const FLIP_SOUND := &"tflip_flip"
## Latch angle (Latch.x) when it is swung out.
const LATCH_OPEN := -150.0
## Equip: from shut through two open flips, over EQUIP_TIME after the draw.
const EQUIP_FROM := 180.0
const EQUIP_TO := 900.0
const EQUIP_DELAY := 0.04
const EQUIP_TIME := 0.5
## Idle fidget: one full flip (shut and open) every FIDGET_GAP seconds at rest.
const FIDGET_GAP := 5.0
const FIDGET_TIME := 0.55
## Wind-up spin (degrees a second) at no charge and at full charge.
const SPIN_SLOW := 540.0
const SPIN_FAST := 1260.0
## How fast the flip settles open after a wind-up (1/s).
const SETTLE_RATE := 16.0

var _blade: Node3D
var _handle_b: Node3D
var _latch: Node3D
var _angle := EQUIP_FROM
var _fidget := 0.0
var _fidget_left := 0.0
var _goal := 0.0
var _last_half := 0


func setup(view: WeaponView) -> void:
	super.setup(view)
	for part in ["Blade", "HandleB", "Latch"]:
		view.register_part(part)
	_blade = view.part("Blade")
	_handle_b = view.part("HandleB")
	_latch = view.part("Latch")
	# Menus and stills (no player) show it open.
	_angle = EQUIP_FROM if view.player else 0.0
	_goal = _angle
	_last_half = _half(_angle)
	_fidget = 0.0


## The draw: a small wrist roll while it flips open in the hand.
func equip_pose(_view: WeaponView, t: float) -> Array:
	var length := EQUIP_DELAY + EQUIP_TIME
	if t >= length:
		return [Vector3.ZERO, Vector3.ZERO]
	var k := sin(clampf(t / length, 0.0, 1.0) * PI)
	return [Vector3(0.0, 0.01 * k, 0.0), Vector3(-8.0 * k, 0.0, 18.0 * k)]


func part_motion(view: WeaponView, mode: MeleeMode, delta: float) -> void:
	if _blade == null or _handle_b == null:
		return
	if view.player != null:
		_advance(mode, delta)
	var half := _half(_angle)
	if half != _last_half:
		_last_half = half
		if view.player != null and view.is_visible_in_tree():
			Sfx.play(FLIP_SOUND, -8.0, randf_range(0.94, 1.08))
	_blade.transform = view.rest_transform("Blade") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(_angle)), Vector3.ZERO)
	_handle_b.transform = view.rest_transform("HandleB") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-_angle)), Vector3.ZERO)
	if _latch:
		var out := clampf(absf(_angle - _nearest_open(_angle)) / 40.0, 0.0, 1.0)
		_latch.transform = view.rest_transform("Latch") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(LATCH_OPEN * out)), Vector3.ZERO)


func _advance(mode: MeleeMode, delta: float) -> void:
	var t := _equip - EQUIP_DELAY
	if t < EQUIP_TIME:
		_angle = lerpf(EQUIP_FROM, EQUIP_TO, ease_out(maxf(t, 0.0) / EQUIP_TIME))
		_goal = _nearest_open(_angle)
		_fidget = 0.0
		return
	var phase := mode.phase if mode else MeleeMode.Phase.IDLE
	if phase == MeleeMode.Phase.WINDUP:
		_angle += lerpf(SPIN_SLOW, SPIN_FAST, mode.charge) * delta
		_goal = _nearest_open(_angle + 180.0)
		_fidget = 0.0
		_fidget_left = 0.0
		return
	if phase == MeleeMode.Phase.IDLE and _fidget_left <= 0.0:
		_fidget += delta
		if _fidget >= FIDGET_GAP:
			_fidget = 0.0
			_fidget_left = FIDGET_TIME
			_goal = _nearest_open(_angle) + 360.0
	elif phase != MeleeMode.Phase.IDLE:
		_fidget = 0.0
	if _fidget_left > 0.0:
		_fidget_left = maxf(0.0, _fidget_left - delta)
		var k := 1.0 - _fidget_left / FIDGET_TIME
		_angle = lerpf(_goal - 360.0, _goal, ease_in_out(k))
		return
	_angle = lerpf(_angle, _goal, 1.0 - exp(-SETTLE_RATE * delta))
	if absf(_angle - _goal) < 0.5:
		_angle = fmod(_goal, 360.0)
		_goal = _angle


## Which half turn the knife is in (open or shut side), for the clack.
static func _half(a: float) -> int:
	return int(floor((a + 90.0) / 180.0))


static func _nearest_open(a: float) -> float:
	return roundf(a / 360.0) * 360.0


# --- inspect: the balisong tricks (TicketFlipperTricks) --------------------------------

var _tricks := TicketFlipperTricks.new()


func inspect_length() -> float:
	return _tricks.choose()


func inspect_poses() -> Array:
	return _tricks.poses()


func inspect_start(v: WeaponView) -> void:
	_tricks.start(v)


func inspect(v: WeaponView, t: float) -> void:
	_tricks.play(v, t)


func inspect_end(v: WeaponView) -> void:
	_tricks.stop(v)
