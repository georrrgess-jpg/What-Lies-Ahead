extends MeleeView
## Ticket Flipper viewmodel (art/models/ticket_flipper.glb): a balisong held
## upright in the fist like the Glow Blade, the knife the hero.
##
## Its flip is one number, the flip angle `a` (degrees): the blade turns `a`
## about HandleA's pin (Blade.x) and HandleB turns `a` more about its own pin
## (HandleB.x), so the bite handle goes right round as the blade goes half
## round, the way a real balisong opens. a = 0 is open, -180 (or 180) shut;
## counting down swings both over the top of the fist. HandleB can also swing
## out on its own (`_bite`) for the idle's tease. The latch on HandleA's butt
## swings out while the knife is anywhere but open.
##   equip   drawn shut, flicked open with a wrist roll, round once more and caught
##   idle    a breathing sway; every few seconds at rest either a full
##           rollover flip or a bite-handle tease (swung out and slapped home)
##   light   fast flat slashes, alternating sides, with a long follow-through
##   heavy   the wind-up flips it once (shut and open) and draws it back by
##           the cheek, point on the target, trembling as it charges; the
##           release is a lunging stab with a twist, then the pull-out
## The hand (HandRig) keeps its solved grip on the bar, its fingertips and
## thumb giving way a beat before the bite handle or the blade swings past
## them (TicketFlipperTricks.shape_hand) and closing again behind it.
## A pin clack (tflip_flip) sounds each time it passes open or shut. While the
## view inspects, the parts are left to the inspect tricks.

const FLIP_SOUND := &"tflip_flip"
## Latch angle (Latch.x) when it is swung out.
const LATCH_OPEN := -150.0
## Equip: from shut, open, round once more and caught, over EQUIP_TIME after EQUIP_DELAY.
const EQUIP_FROM := -180.0
const EQUIP_TO := -720.0
const EQUIP_DELAY := 0.06
const EQUIP_TIME := 0.56
## Idle fidgets: one every FIDGET_GAP seconds at rest, alternating a rollover
## (a full flip, ROLL_TIME long) and a tease (the bite handle swung TEASE_ANGLE out, TEASE_TIME long).
const FIDGET_GAP := 4.2
const ROLL_TIME := 0.62
const TEASE_TIME := 0.7
const TEASE_ANGLE := -125.0
## The wind-up's flip (shut and open again) at its start.
const WINDUP_FLIP_TIME := 0.3
## The swings turn about the elbow (from the grip, view units: down the forearm,
## which runs to the lower right and back towards the player), so the arm
## stays low while the knife sweeps the frame.
const ELBOW := Vector3(0.25, -0.12, 0.22)
## Light slash, right to left (mirrored every other swing): cocked out to the
## right, whipped flat across the middle, followed through low left.
const FLIP_LIGHT_KEYS := [
	[0.0, Vector3.ZERO, Vector3.ZERO],
	[0.14, Vector3(0.04, 0.03, 0.02), Vector3(3.0, -8.0, -8.0)],
	[0.36, Vector3(-0.08, 0.035, -0.05), Vector3(-5.0, 12.0, 12.0)],
	[0.6, Vector3(-0.12, 0.015, -0.02), Vector3(-9.0, 16.0, 16.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]
## Heavy: from the wind-up (drawn back by the cheek, point on the target) the
## lunge drives the point straight down the middle, twists, and pulls out.
const FLIP_HEAVY_KEYS := [
	[0.0, Vector3(0.02, 0.0, 0.03), Vector3(-4.0, 8.0, -6.0)],
	[0.2, Vector3(-0.06, 0.03, -0.16), Vector3(-6.0, 10.0, 6.0)],
	[0.4, Vector3(-0.07, 0.03, -0.18), Vector3(-6.0, 10.0, 16.0)],
	[0.62, Vector3(-0.02, 0.01, -0.04), Vector3(0.0, 4.0, 8.0)],
	[1.0, Vector3.ZERO, Vector3.ZERO],
]

var _blade: Node3D
var _handle_b: Node3D
var _latch: Node3D
var _angle := EQUIP_FROM
## Extra swing of the bite handle on its own pin (the tease), degrees.
var _bite := 0.0
var _rest := 0.0
var _fidget_t := -1.0
var _fidgets := 0
var _windup_t := -1.0
var _last_half := 0
var _rig: HandRig
## The knife's shape last frame (blade, bite handle), to see where it is heading.
var _was := Vector2.ZERO


func setup(view: WeaponView) -> void:
	super.setup(view)
	for part in ["Blade", "HandleB", "Latch"]:
		view.register_part(part)
	_blade = view.part("Blade")
	_handle_b = view.part("HandleB")
	_latch = view.part("Latch")
	# Menus and stills (no player) show it open.
	_angle = EQUIP_FROM if view.player else 0.0
	_last_half = _half(_angle)
	_rest = 0.0
	_fidget_t = -1.0
	_windup_t = -1.0
	_rig = HandRig.of(view.model)
	if not _rig.has_hand(&"R"):
		_rig = null
	_was = Vector2(_angle, 2.0 * _angle)


func light_keys() -> Array:
	return FLIP_LIGHT_KEYS


func heavy_keys() -> Array:
	return FLIP_HEAVY_KEYS


func swing_pivot() -> Vector3:
	return ELBOW


## Drawn back fast (most of the way in the first third of the charge), then
## a slow extra pull and a tightening wrist as it charges.
func windup_pose(charge: float) -> Array:
	var start: Array = FLIP_HEAVY_KEYS[0]
	var k := ease_out(minf(1.0, charge * 3.0))
	return [(start[1] as Vector3) * k + Vector3(0.0, 0.0, 0.012) * charge, (start[2] as Vector3) * k + Vector3(0.0, 0.0, -4.0) * charge]


## The draw: the wrist rolls out and back as it flicks open, and the knife
## pops up a little at the catch.
func equip_pose(_view: WeaponView, t: float) -> Array:
	var length := EQUIP_DELAY + EQUIP_TIME + 0.12
	if t >= length:
		return [Vector3.ZERO, Vector3.ZERO]
	var u := clampf(t / length, 0.0, 1.0)
	var roll := sin(u * PI)
	var pop := sin(clampf((u - 0.7) / 0.3, 0.0, 1.0) * PI)
	return [Vector3(-0.02 * roll, 0.02 * pop, 0.02 * roll), Vector3(10.0 * roll - 6.0 * pop, -8.0 * roll, 28.0 * roll)]


## A breathing sway, plus the wrist following each fidget.
func idle_pose(t: float) -> Array:
	var pose := [Vector3(0.004 * sin(t * 0.8), sin(t * 1.6) * 0.005, 0.0), Vector3(sin(t * 1.1) * 1.6, sin(t * 0.7) * 2.0, sin(t * 0.9) * 2.4)]
	if _fidget_t >= 0.0:
		var k := sin(clampf(_fidget_t, 0.0, 1.0) * PI)
		if _fidgets % 2 == 1:
			pose[1] += Vector3(6.0 * k, -6.0 * k, 22.0 * k)
			pose[0] += Vector3(0.0, 0.015 * k, 0.0)
		else:
			pose[1] += Vector3(0.0, 0.0, -14.0 * k)
	return pose


func part_motion(view: WeaponView, mode: MeleeMode, delta: float) -> void:
	if _blade == null or _handle_b == null or view.is_inspecting():
		return
	if view.player != null:
		_advance(mode, delta)
	var half := _half(_angle)
	if half != _last_half:
		_last_half = half
		if view.player != null and view.is_visible_in_tree():
			Sfx.play(FLIP_SOUND, -8.0, randf_range(0.94, 1.08))
	_blade.transform = view.rest_transform("Blade") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(_angle)), Vector3.ZERO)
	_handle_b.transform = view.rest_transform("HandleB") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(_angle + _bite)), Vector3.ZERO)
	if _latch:
		var off := maxf(absf(_angle - _nearest_open(_angle)), absf(_bite))
		var out := clampf(off / 30.0, 0.0, 1.0)
		_latch.transform = view.rest_transform("Latch") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(LATCH_OPEN * out)), Vector3.ZERO)
	_pose_hand(delta)


## The fingers and thumb for the knife's shape now and where it is heading
## (the blade at _angle, the bite handle at 2 _angle + _bite).
func _pose_hand(delta: float) -> void:
	var now := Vector2(_angle, 2.0 * _angle + _bite)
	var step := now - _was
	# A whole turn wrapped back to open in one frame is no motion.
	if absf(step.x) > 90.0 or absf(step.y) > 180.0:
		step = Vector2.ZERO
	var ahead := now + step / maxf(delta, 0.001) * TicketFlipperTricks.LEAD
	_was = now
	if _rig == null:
		return
	var hand := TicketFlipperTricks.shape_hand(now.x, now.y).min(TicketFlipperTricks.shape_hand(ahead.x, ahead.y))
	for finger in [&"Index", &"Middle", &"Ring", &"Pinky"]:
		_rig.set_curl(&"R", finger, hand.x)
	_rig.set_curl(&"R", &"Thumb", hand.y)


func _advance(mode: MeleeMode, delta: float) -> void:
	_bite = 0.0
	var t := _equip - EQUIP_DELAY
	if t < EQUIP_TIME:
		_angle = lerpf(EQUIP_FROM, EQUIP_TO, _catch(maxf(t, 0.0) / EQUIP_TIME))
		_rest = 0.0
		return
	var phase := mode.phase if mode else MeleeMode.Phase.IDLE
	# The wind-up's flip: shut and open again in WINDUP_FLIP_TIME as the knife is drawn back.
	if phase == MeleeMode.Phase.WINDUP and _windup_t < 0.0:
		_windup_t = 0.0
	if _windup_t >= 0.0:
		_windup_t += delta / WINDUP_FLIP_TIME
		_angle = -360.0 * _catch(_windup_t)
		_fidget_t = -1.0
		_rest = 0.0
		if _windup_t >= 1.0 and phase != MeleeMode.Phase.WINDUP:
			_windup_t = -1.0
		if _windup_t >= 1.0:
			_angle = 0.0
		return
	if phase != MeleeMode.Phase.IDLE or (mode and mode.is_busy()):
		_fidget_t = -1.0
		_rest = 0.0
		_angle = 0.0
		return
	_rest += delta
	if _fidget_t < 0.0 and _rest >= FIDGET_GAP:
		_rest = 0.0
		_fidget_t = 0.0
		_fidgets += 1
	if _fidget_t < 0.0:
		_angle = 0.0
		return
	var tease := _fidgets % 2 == 1
	_fidget_t += delta / (TEASE_TIME if tease else ROLL_TIME)
	if _fidget_t >= 1.0:
		_fidget_t = -1.0
		_angle = 0.0
		return
	if tease:
		# Swung out fast, hangs, then slapped home past the stop and back.
		var k := _fidget_t
		var out := ease_out(k / 0.3) if k < 0.3 else (1.0 if k < 0.55 else 1.0 - _catch((k - 0.55) / 0.45))
		_bite = TEASE_ANGLE * out
		_angle = 0.0
	else:
		_angle = -360.0 * _catch(_fidget_t)


## Overshoots a little past the end and settles back (the handles slapping shut on the stop).
static func _catch(t: float) -> float:
	var s := 1.3
	var x := clampf(t, 0.0, 1.0) - 1.0
	return x * x * ((s + 1.0) * x + s) + 1.0


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
