class_name JinglestarTricks
extends RefCounted
## The Jester's Jinglestar's inspect: flail tricks driven by the hand, one
## picked at random each inspect (never the same one twice running), and,
## one inspect in RARE_ODDS, the GRAND FINALE. JinglestarView hands its
## inspect hooks to this and runs the chain; a trick moves the wrist (the
## whole model about the grip), may throw the handle out of the hand (the
## Handle part, the chain following its cap), curls the fingers (HandRig),
## and pulls the head along a path (JinglestarChain.pull) on top of the
## physics, so the chain always trails it with its own weight.
##
##   FIGURE8  the wrist rolls and the head draws a figure-eight beside the hand
##   WRAP     the head is whirled round the handle, the chain winding onto it
##            and tight, then a flick of the wrist unwinds it in a big swing
##   TOSS     the fingers open, the handle flies up end over end with the head
##            swinging under it, and drops back into the closing hand
##   FINALE   (rare) the flail is raised and whirled overhead, the bell plays a
##            fanfare as the ribbons burst into confetti, and it takes a bow
##
## Cancel rules are WeaponInspect's (fire, aim, a switch, sprint... blend
## back to the hip); stop() puts the handle back in the hand at once.

enum Trick { FIGURE8, WRAP, TOSS, FINALE }

const NORMAL: Array[int] = [Trick.FIGURE8, Trick.WRAP, Trick.TOSS]
## Seconds of each trick (Trick order).
const LENGTHS: Array[float] = [3.2, 3.4, 3.2, 5.2]
## One inspect in this many (on average) is the FINALE.
const RARE_ODDS := 15
## The holder's place (camera space) and turn for the tricks: the flail up
## beside the middle of the screen, a little closer than the hip.
const SIDE_POS := Vector3(0.2, -0.12, -0.64)
const SIDE_ROT := Vector3(58.0, 16.0, -14.0)
## The toss: when the hand lets go and catches, how far the handle flies
## along its length (view units), and the point it turns about (the handle's middle).
const TOSS_FROM := 0.7
const TOSS_TO := 1.55
const TOSS_RISE := 0.34
const TOSS_PIVOT := Vector3(0.0, 0.0, -0.1)
## Seconds the wrist takes to ease back out of a cancelled trick.
const CANCEL_EASE := 0.2
const CONFETTI: Array[Color] = [Color(1.0, 0.82, 0.27), Color(0.55, 0.24, 0.94), Color(0.1, 0.77, 0.54), Color(1.0, 0.36, 0.54), Color(1, 1, 1)]

## The trick picked for the inspect starting now (a Trick).
var trick: int = Trick.FIGURE8
## The head's spin about its chain the trick asks for (degrees a second).
var spin := 0.0

var _rng := RandomNumberGenerator.new()
var _force := -1
var _last := -1
var _view: WeaponView
var _owner: Object
var _rig: HandRig
var _t := 0.0
var _prev_t := 0.0
var _whirl := 0.0
var _active := false
## The wrist's last trick pose, eased back out over CANCEL_EASE after a cancel.
var _wrist_left := Transform3D.IDENTITY
var _ease := 0.0


func _init() -> void:
	_rng.randomize()
	# Dev captures (scripts/dev/inspect_strip.gd): --shot-trick=<Trick> plays that trick every time.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-trick="):
			_force = int(arg.trim_prefix("--shot-trick="))


func setup(view: WeaponView, owner_view: Object) -> void:
	_view = view
	_owner = owner_view


## Picks the next inspect's trick; returns its length (seconds).
func choose() -> float:
	var rare := _view != null and _view.inspect_force_rare
	if _force >= 0:
		trick = _force
	elif rare or _rng.randi_range(1, RARE_ODDS) == 1:
		trick = Trick.FINALE
	else:
		var pool := NORMAL.duplicate()
		pool.erase(_last)
		trick = pool[_rng.randi_range(0, pool.size() - 1)]
		_last = trick
	return LENGTHS[trick]


## The holder's path for the picked trick (WeaponInspect poses).
func poses() -> Array:
	match trick:
		Trick.FINALE:
			return [
				[0.0, SIDE_POS + Vector3(0.04, -0.03, 0.0), SIDE_ROT + Vector3(-6.0, -8.0, 0.0)],
				[0.15, SIDE_POS + Vector3(-0.02, 0.0, -0.04), SIDE_ROT + Vector3(6.0, 0.0, 0.0)],
				[0.6, SIDE_POS + Vector3(-0.03, 0.0, -0.05), SIDE_ROT + Vector3(6.0, -4.0, 0.0)],
				[0.82, SIDE_POS + Vector3(0.0, -0.04, -0.02), SIDE_ROT + Vector3(-18.0, 0.0, 4.0)],
				[1.0, SIDE_POS, SIDE_ROT],
			]
		Trick.TOSS:
			return [
				[0.0, SIDE_POS + Vector3(0.03, -0.02, 0.0), SIDE_ROT + Vector3(-4.0, -6.0, 0.0)],
				[0.18, SIDE_POS + Vector3(0.0, -0.03, 0.0), SIDE_ROT],
				[0.5, SIDE_POS + Vector3(0.0, -0.05, 0.0), SIDE_ROT + Vector3(-6.0, 0.0, 0.0)],
				[1.0, SIDE_POS, SIDE_ROT + Vector3(4.0, -4.0, 0.0)],
			]
	return [
		[0.0, SIDE_POS + Vector3(0.03, -0.02, 0.0), SIDE_ROT + Vector3(-4.0, -6.0, 0.0)],
		[0.2, SIDE_POS, SIDE_ROT],
		[0.65, SIDE_POS + Vector3(-0.01, 0.0, 0.0), SIDE_ROT + Vector3(0.0, 6.0, 3.0)],
		[1.0, SIDE_POS, SIDE_ROT + Vector3(4.0, -4.0, 0.0)],
	]


func start(v: WeaponView) -> void:
	stop(v)
	_t = 0.0
	_prev_t = 0.0
	_whirl = 0.0
	_active = true
	_rig = HandRig.of(v.model) if v.model else null
	if _rig and not _rig.has_hand(&"R"):
		_rig = null


## Every frame the inspect plays, `t` seconds in (the view poses it next frame, in apply).
func play(_v: WeaponView, t: float) -> void:
	_t = t


## The wrist and the handle for the trick now (before the chain steps); after
## a cancel, the wrist easing back while the inspect blends out.
func apply(v: WeaponView, delta: float) -> void:
	if not _active:
		_ease = maxf(0.0, _ease - delta / CANCEL_EASE)
		v.model.transform = v.rest_transform("Root") * Transform3D.IDENTITY.interpolate_with(_wrist_left, smoothstep(0.0, 1.0, _ease))
		return
	var t := _t
	var wrist := Vector3.ZERO
	var turn := Vector3.ZERO
	var handle := Transform3D.IDENTITY
	match trick:
		Trick.FIGURE8:
			var phase := _figure_phase(t)
			var k := WeaponInspect.window(t, 0.3, 0.7) * (1.0 - WeaponInspect.window(t, 2.6, 3.0))
			turn = Vector3(10.0 * sin(phase * 2.0), 6.0 * cos(phase), 22.0 * sin(phase)) * k
			wrist = Vector3(0.012 * sin(phase), 0.008 * sin(phase * 2.0), 0.0) * k
		Trick.WRAP:
			var wind := WeaponInspect.window(t, 0.3, 0.6) * (1.0 - WeaponInspect.window(t, 1.8, 1.95))
			turn = Vector3(0.0, 0.0, 14.0 * sin(t * 13.0)) * wind
			# The flick: a snap of the wrist forward and back.
			var flick := WeaponInspect.hump(t, 1.85, 2.35)
			turn += Vector3(-34.0, 10.0, 16.0) * flick
			wrist += Vector3(-0.01, 0.02, -0.03) * flick
		Trick.TOSS:
			var dip := WeaponInspect.hump(t, 0.35, TOSS_FROM + 0.05) + 0.7 * WeaponInspect.hump(t, TOSS_TO - 0.05, TOSS_TO + 0.35)
			wrist = Vector3(0.0, -0.025, 0.01) * dip
			turn = Vector3(-10.0, 0.0, 0.0) * dip
			if t > TOSS_FROM and t < TOSS_TO:
				var u := (t - TOSS_FROM) / (TOSS_TO - TOSS_FROM)
				var lift := Vector3(0.0, 0.0, -TOSS_RISE * 4.0 * u * (1.0 - u))
				var flip := Basis(Vector3.RIGHT, -TAU * u)
				handle = Transform3D(Basis.IDENTITY, lift + TOSS_PIVOT) * Transform3D(flip, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -TOSS_PIVOT)
		Trick.FINALE:
			var up := WeaponInspect.window(t, 0.2, 0.8) * (1.0 - WeaponInspect.window(t, 3.3, 3.8))
			_whirl = t * lerpf(6.0, 15.0, WeaponInspect.window(t, 0.4, 1.4))
			turn = Vector3(12.0, 0.0, -6.0) * up + Vector3(cos(_whirl), 0.0, sin(_whirl)) * 3.0 * up
			wrist = Vector3(0.0, 0.01, 0.0) * up
			# The bow: the flail dips, the head swinging down in front.
			var bow := WeaponInspect.hump(t, 3.7, 4.9)
			turn += Vector3(-30.0, 0.0, 6.0) * bow
			wrist += Vector3(0.0, -0.03, -0.02) * bow
	_wrist_left = Transform3D(Basis.from_euler(turn * (PI / 180.0)), wrist)
	_ease = 1.0
	v.model.transform = v.rest_transform("Root") * _wrist_left
	var part := v.part("Handle")
	if part:
		part.transform = v.rest_transform("Handle") * handle
	_hand(t)
	_cues(v, t)
	_prev_t = t


## The pull on the head for the trick now (view space), with `anchor` the cap's eye.
func drive(chain: JinglestarChain, anchor: Vector3) -> void:
	var t := _t
	chain.pull = 0.0
	spin = 0.0
	if not _active:
		return
	match trick:
		Trick.FIGURE8:
			var phase := _figure_phase(t)
			var centre := anchor + Vector3(-0.1, -0.12, -0.08)
			chain.pull_target = centre + Vector3(sin(phase) * 0.17, sin(phase * 2.0) * 0.09, cos(phase) * 0.05)
			chain.pull = 0.7 * WeaponInspect.window(t, 0.3, 0.7) * (1.0 - WeaponInspect.window(t, 2.5, 2.9))
			spin = 200.0
		Trick.WRAP:
			# Round the handle's top, closing in as the chain winds on.
			var turns := t * 11.0
			var axis_point := anchor + Vector3(0.0, -0.08, 0.02)
			var r := lerpf(0.2, 0.1, WeaponInspect.window(t, 0.4, 1.6))
			chain.pull_target = axis_point + Vector3(cos(turns), 0.05 * sin(turns * 0.5), sin(turns)) * r
			chain.pull = 0.85 * WeaponInspect.window(t, 0.25, 0.5) * (1.0 - WeaponInspect.window(t, 1.85, 1.95))
			spin = 500.0 * (1.0 - WeaponInspect.window(t, 1.9, 2.6))
		Trick.TOSS:
			spin = 300.0 if t > TOSS_FROM and t < TOSS_TO + 0.3 else 0.0
		Trick.FINALE:
			var whirling := WeaponInspect.window(t, 0.3, 0.8) * (1.0 - WeaponInspect.window(t, 3.2, 3.6))
			var tilt := deg_to_rad(24.0)
			chain.pull_target = anchor + Vector3(-0.1, -0.02, -0.14) + (Vector3.RIGHT * cos(_whirl) + Vector3(0.0, sin(tilt), -cos(tilt)) * sin(_whirl)) * 0.21
			chain.pull = 0.85 * whirling
			spin = 1100.0 * whirling


func stop(v: WeaponView) -> void:
	_active = false
	if v and v.model and v.has_part("Handle"):
		var part := v.part("Handle")
		if part:
			part.transform = v.rest_transform("Handle")
	if _rig:
		_rig.set_pose(&"R", HandRig.Pose.GRIP, 0.1)
		_rig = null
	spin = 0.0


## The figure-eight's phase: two loops round, easing in and out.
static func _figure_phase(t: float) -> float:
	return TAU * 2.0 * smoothstep(0.35, 2.75, t)


## The fingers: they open before the toss leaves the hand and close as it lands,
## loosen for the wrap's flick, and spread for the finale's bow.
func _hand(t: float) -> void:
	if _rig == null:
		return
	var curl := 1.0
	var thumb := 1.0
	match trick:
		Trick.TOSS:
			var open := WeaponInspect.window(t, TOSS_FROM - 0.06, TOSS_FROM + 0.04) * (1.0 - WeaponInspect.window(t, TOSS_TO - 0.08, TOSS_TO + 0.02))
			curl = 1.0 - open
			thumb = 1.0 - open
		Trick.WRAP:
			curl = 1.0 - 0.25 * WeaponInspect.hump(t, 1.85, 2.2)
			thumb = 1.0 - 0.5 * WeaponInspect.hump(t, 1.85, 2.2)
		Trick.FIGURE8:
			thumb = 1.0 - 0.2 * WeaponInspect.window(t, 0.5, 0.8) * (1.0 - WeaponInspect.window(t, 2.5, 2.8))
	for finger in [&"Index", &"Middle", &"Ring", &"Pinky"]:
		_rig.set_curl(&"R", finger, curl)
	_rig.set_curl(&"R", &"Thumb", thumb)


## Sounds and sparkles as the clock passes their moments.
func _cues(v: WeaponView, t: float) -> void:
	var head := _head_in_model(v)
	match trick:
		Trick.FIGURE8:
			for at in [0.9, 1.5, 2.1]:
				if _passed(at, t):
					Sfx.play(&"jingle_jingle", -12.0, randf_range(0.95, 1.1))
		Trick.WRAP:
			if _passed(1.6, t):
				Sfx.play(&"jingle_rattle", -8.0, 0.9)
			if _passed(1.9, t):
				Sfx.play(&"jingle_whoosh", -8.0, 1.1)
			if _passed(2.3, t):
				Sfx.play(&"jingle_jingle", -10.0, 1.0)
		Trick.TOSS:
			if _passed(TOSS_FROM, t):
				Sfx.play(&"jingle_whoosh", -10.0, 1.25)
			if _passed(TOSS_TO, t):
				Sfx.play(&"jingle_catch", -6.0, 1.0)
		Trick.FINALE:
			if _passed(0.5, t):
				Sfx.play(&"jingle_whirl", -6.0, 1.05)
			if _passed(1.5, t):
				Sfx.play(&"jingle_fanfare", -3.0, 1.0)
			for at in [1.55, 1.9, 2.25, 2.6, 2.95]:
				if _passed(at, t):
					v.spark_burst(head, Vector3.UP, CONFETTI, 22, 2.4, 0.9, 0.016)
			if _passed(3.95, t):
				Sfx.play(&"jingle_jingle", -8.0, 0.9)


func _passed(at: float, t: float) -> bool:
	return _prev_t < at and t >= at


func _head_in_model(v: WeaponView) -> Vector3:
	var head := v.part("Head")
	return v.model.to_local(head.global_position) if head else Vector3.ZERO
