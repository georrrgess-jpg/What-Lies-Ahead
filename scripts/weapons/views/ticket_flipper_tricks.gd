class_name TicketFlipperTricks
extends RefCounted
## The Ticket Flipper's inspect: real balisong tricks, one picked at random
## each inspect (never the same one twice running), and once in every
## RARE_EVERY inspects (a seeded slot in each run of RARE_EVERY) the JACKPOT
## combo. TicketFlipperView hands its inspect hooks to this.
##
## Every trick is a set of keyed tracks over its own seconds:
##   wp, wr  the wrist: the whole model (fist and knife) offset and turned
##           (degrees) about the grip, in the model's axes
##   kp, kr  the knife: HandleA (and all on it) moved and turned (degrees)
##           about kc, after ko has carried it out from the grip (ko turns
##           with it: a knife rolling round the hand)
##   a, bw   the knife's own shape: the blade's turn on HandleA's pin and
##           HandleB's turn against HandleA (open 0/0, shut 180/0, the blade
##           covered by HandleB 0/-180). They stay where the channels allow
##           (a in 0..180, bw in a-180..0), so the handles and the blade
##           swing over the top of the bar and never cut through each other;
##           whole turns are made by the knife (kr), as a real balisong does.
## Cues fire once as the clock passes them (sounds, a camera kick, sparkles).
## The latch swings out whenever the knife is not open and clicks home.
##
## The model's axes: x across the bar (the fingers wrap its -x side), y up,
## -z along the blade. Positions are built from the parts' rest transforms,
## so a new model with the same parts and pins keeps every trick in the hand.

enum Trick { BASIC, AERIAL, FAN, HELIX, ZEN, JACKPOT }

## The ordinary tricks the dice pick from.
const NORMAL: Array[int] = [Trick.BASIC, Trick.AERIAL, Trick.FAN, Trick.HELIX, Trick.ZEN]
## Seconds of each trick (Trick order).
const LENGTHS: Array[float] = [3.0, 3.0, 3.0, 3.2, 3.2, 5.8]
## One inspect in this many is the JACKPOT.
const RARE_EVERY := 15
## The knife side on to the eye, the fist low right (camera space; see WeaponInspect.POSES).
const SIDE_POS := Vector3(0.015, -0.07, -0.45)
const SIDE_ROT := Vector3(4.0, 68.0, 6.0)
## The latch's turn when it is swung out (Latch.x).
const LATCH_OUT := -150.0
## Out to the finger side of the fist, clear of the fingers (view units).
const SIDE_X := -0.072
## The roll round the hand: its radius and how far forward of the fist it rides.
const ROLL_R := 0.088
const ROLL_FWD := -0.13
## How far ahead of the grip the fan spins (view units, -z).
const FAN_FWD := -0.06
## Eases for the stretch ending at a key.
const L := 0   # linear (a knife spinning free)
const S := 1   # ease in and out
const O := 2   # snap: fast out, settling
const I := 3   # gathering speed
const UP := 4  # thrown: decelerating like a toss
const DN := 5  # falling: accelerating like a drop
## The smear: samples kept and the tip speed (view units a second) that lights it fully.
const SMEAR_SAMPLES := 8
const SMEAR_FULL := 2.6
const CONFETTI: Array[Color] = [Color(1.0, 0.25, 0.42), Color(1.0, 0.86, 0.3), Color(0.25, 0.94, 1.0), Color(1.0, 0.97, 0.9)]
const SPARKLE: Array[Color] = [Color(1.0, 0.95, 0.6), Color(1.0, 1.0, 1.0), Color(0.4, 1.0, 1.0)]

## Dev captures: play this trick every time (-1: the dice).
var force := -1
## The trick picked for the inspect starting now (a Trick).
var trick: int = Trick.BASIC

var _rng := RandomNumberGenerator.new()
## Dev captures (--shot-rare=1, as scripts/dev/inspect_strip.gd): every inspect is the JACKPOT.
var _force_rare := false
var _count := 0
var _rare_slot := 0
var _last := -1
var _tracks: Dictionary = {}
var _cues: Array = []
var _cue := 0
var _clack_a := 0
var _clack_b := 0
var _latch_out := 0.0
var _smear: MeshInstance3D
var _smear_mesh: ImmediateMesh
var _samples: Array = []
var _label: Label3D
var _label_at := -1.0
var _prev_t := 0.0
## The knife's places in the model (from the rest transforms).
var _pin := Vector3.ZERO
var _butt := Vector3.ZERO


func _init() -> void:
	_rng.randomize()
	_force_rare = OS.get_cmdline_user_args().has("--shot-rare=1")


## Seeds the dice (the rare slot and the picks), for a repeatable run.
func reseed(value: int) -> void:
	_rng.seed = value
	_count = 0


## Picks the next inspect's trick; returns its length (seconds).
func choose() -> float:
	if _count % RARE_EVERY == 0:
		_rare_slot = _rng.randi_range(0, RARE_EVERY - 1)
	var rare := _force_rare or _count % RARE_EVERY == _rare_slot
	_count += 1
	if force >= 0:
		trick = force
	elif rare:
		trick = Trick.JACKPOT
	else:
		var pool := NORMAL.duplicate()
		pool.erase(_last)
		trick = pool[_rng.randi_range(0, pool.size() - 1)]
		_last = trick
	return LENGTHS[trick]


## The holder's path for the picked trick (WeaponInspect poses).
func poses() -> Array:
	if trick == Trick.JACKPOT:
		# The view tips up after the high toss and back down for the catch.
		return [
			[0.0, SIDE_POS + Vector3(0.02, -0.01, 0.0), SIDE_ROT + Vector3(-4.0, -10.0, 0.0)],
			[0.1, SIDE_POS, SIDE_ROT],
			[0.22, SIDE_POS + Vector3(0.0, -0.13, -0.06), SIDE_ROT + Vector3(-8.0, 4.0, 0.0)],
			[0.36, SIDE_POS, SIDE_ROT],
			[0.72, SIDE_POS + Vector3(0.01, 0.0, 0.0), SIDE_ROT + Vector3(10.0, -16.0, 0.0)],
			[0.88, SIDE_POS + Vector3(-0.01, 0.01, 0.01), SIDE_ROT + Vector3(2.0, -4.0, 4.0)],
			[1.0, SIDE_POS, SIDE_ROT],
		]
	var tilt := Vector3(0.0, 0.0, 3.0) if trick % 2 == 0 else Vector3(-3.0, 4.0, 0.0)
	return [
		[0.0, SIDE_POS + Vector3(0.02, -0.01, 0.0), SIDE_ROT + Vector3(-4.0, -10.0, 0.0)],
		[0.2, SIDE_POS, SIDE_ROT],
		[0.6, SIDE_POS + Vector3(-0.01, 0.005, 0.0), SIDE_ROT + tilt],
		[1.0, SIDE_POS + Vector3(0.0, -0.01, 0.0), SIDE_ROT + Vector3(6.0, -6.0, 0.0)],
	]


## The inspect begins: the picked trick's tracks, a fresh smear.
func start(v: WeaponView) -> void:
	stop(v)
	for part in ["HandleA", "Blade", "HandleB", "Latch", "BladeTip"]:
		v.register_part(part)
	var rest_a := v.rest_transform("HandleA")
	_pin = rest_a.origin
	_butt = rest_a * v.rest_transform("Latch").origin
	_tracks = _build(trick)
	_cues = _cues_of(trick)
	_cue = 0
	_prev_t = 0.0
	_clack_a = _half(0.0)
	_clack_b = _half(0.0)
	_latch_out = 0.0
	_build_smear(v)


## Every frame the inspect plays, `t` seconds in.
func play(v: WeaponView, t: float) -> void:
	if _tracks.is_empty() or v.model == null:
		return
	var wp: Vector3 = _sample("wp", t)
	var wr: Vector3 = _sample("wr", t)
	v.model.transform = v.rest_transform("Root") * Transform3D(Basis.from_euler(wr * (PI / 180.0)), wp)
	var kc: Vector3 = _sample("kc", t)
	var turn := Basis.from_euler((_sample("kr", t) as Vector3) * (PI / 180.0))
	var knife := Transform3D(Basis.IDENTITY, (_sample("kp", t) as Vector3) + kc) * Transform3D(turn, Vector3.ZERO) \
		* Transform3D(Basis.IDENTITY, -kc + (_sample("ko", t) as Vector3))
	var handle_a := v.part("HandleA")
	if handle_a:
		handle_a.transform = knife * v.rest_transform("HandleA")
	var a: float = _sample("a", t)
	var bw: float = _sample("bw", t)
	_pose_parts(v, a, bw)
	_sounds(v, a, bw)
	_fire_cues(v, t)
	_update_label(t)
	_update_smear(v, t)
	_prev_t = t


## The inspect ended or was cancelled: the knife back in the fist, the extras gone.
func stop(v: WeaponView) -> void:
	if v and v.model and v.has_part("HandleA"):
		var handle_a := v.part("HandleA")
		if handle_a:
			handle_a.transform = v.rest_transform("HandleA")
	if _smear:
		_smear.queue_free()
		_smear = null
		_smear_mesh = null
	if _label:
		_label.queue_free()
		_label = null
	_samples.clear()
	_tracks = {}


# --- the tricks ------------------------------------------------------------------

## Each track: [[t, value, ease of the stretch ending here], ...] (the first key's ease is unused).
func _build(which: int) -> Dictionary:
	match which:
		Trick.AERIAL:
			return _aerial()
		Trick.FAN:
			return _fan()
		Trick.HELIX:
			return _helix()
		Trick.ZEN:
			return _zen()
		Trick.JACKPOT:
			return _jackpot()
	return _basic()


## Basic close and open (the bite handle over the top each time), then a
## Y2K pair: two quick flips shut and open with the wrist rolling under them.
func _basic() -> Dictionary:
	return {
		"wp": [[0.0, Vector3.ZERO], [0.45, Vector3(0.0, -0.01, 0.0)], [0.62, Vector3(0.0, 0.012, 0.0), O], [0.82, Vector3(0.0, -0.008, 0.0), O],
			[1.0, Vector3.ZERO], [1.15, Vector3(0.0, 0.01, 0.0), O], [1.32, Vector3(0.0, -0.006, 0.0), O], [1.5, Vector3.ZERO],
			[1.62, Vector3(0.0, 0.014, 0.0), O], [1.8, Vector3(0.0, -0.01, 0.0), O], [2.1, Vector3.ZERO]],
		"wr": [[0.0, Vector3.ZERO], [0.45, Vector3(-10.0, 0.0, 0.0)], [0.62, Vector3(12.0, 0.0, 0.0), O], [0.82, Vector3(-8.0, 0.0, 0.0), O],
			[1.0, Vector3(0.0, 0.0, 0.0)], [1.15, Vector3(10.0, 0.0, 0.0), O], [1.32, Vector3(-6.0, 0.0, 0.0), O], [1.48, Vector3.ZERO],
			[1.62, Vector3(8.0, 0.0, 22.0), O], [1.8, Vector3(-6.0, 0.0, -22.0), O], [2.05, Vector3(0.0, 0.0, 6.0)], [2.6, Vector3.ZERO]],
		"kp": [[0.0, Vector3.ZERO]],
		"kr": [[0.0, Vector3.ZERO]],
		"kc": [[0.0, _pin]],
		"ko": [[0.0, Vector3.ZERO]],
		# Close: HandleB over onto the blade, then both fold back over the top onto HandleA.
		# Open: the reverse. Then the Y2K pair: the blade flicks shut and open.
		"a": [[0.0, 0.0], [0.62, 0.0], [0.82, 180.0, S], [1.0, 180.0], [1.16, 0.0, S], [1.48, 0.0], [1.62, 180.0, O], [1.8, 0.0, O]],
		"bw": [[0.0, 0.0], [0.45, 0.0], [0.62, -180.0, S], [0.82, 0.0, S], [1.0, 0.0], [1.16, -180.0, S], [1.32, 0.0, O]],
	}


## Aerial: a flick tosses the open knife up, it turns twice end over end (and rolls once)
## end over end with the bite handle swinging wide, and drops back into the
## fist by the safe handle; a flip shut and open to finish.
func _aerial() -> Dictionary:
	var centre := _pin.lerp(_butt, 0.3)
	return {
		"wp": [[0.0, Vector3.ZERO], [0.5, Vector3(0.0, -0.025, 0.01)], [0.62, Vector3(0.0, 0.03, -0.01), O], [0.95, Vector3(0.0, 0.0, 0.0)],
			[1.5, Vector3(0.0, 0.012, 0.0)], [1.6, Vector3(0.0, -0.03, 0.0), O], [2.0, Vector3.ZERO]],
		"wr": [[0.0, Vector3.ZERO], [0.5, Vector3(-18.0, 0.0, 0.0)], [0.62, Vector3(22.0, 0.0, 0.0), O], [1.0, Vector3(0.0, 0.0, 0.0)],
			[1.45, Vector3(-6.0, 0.0, 0.0)], [1.6, Vector3(8.0, 0.0, 0.0), O], [2.0, Vector3.ZERO], [2.2, Vector3(6.0, 0.0, 0.0), O],
			[2.42, Vector3(-4.0, 0.0, 0.0), O], [2.7, Vector3.ZERO]],
		"kp": [[0.0, Vector3.ZERO], [0.62, Vector3.ZERO], [1.08, Vector3(0.0, 0.26, -0.01), UP], [1.52, Vector3.ZERO, DN]],
		"kr": [[0.0, Vector3.ZERO], [0.62, Vector3.ZERO], [1.52, Vector3(720.0, 0.0, 360.0), L], [1.53, Vector3(720.0, 0.0, 360.0)]],
		"kc": [[0.0, centre]],
		"ko": [[0.0, Vector3.ZERO]],
		"a": [[0.0, 0.0], [2.0, 0.0], [2.2, 180.0, O], [2.42, 0.0, O]],
		"bw": [[0.0, 0.0], [0.7, 0.0], [1.05, -130.0, S], [1.42, 0.0, I]],
	}


## Fan: shut, the knife slips out beside the fingers and spins end over end
## round its balance point (three turns gathering and losing speed), drops
## back into the fist and flicks open.
func _fan() -> Dictionary:
	var centre := _pin.lerp(_butt, 0.5)
	var up := Vector3(0.0, 0.07, 0.0)
	var side := Vector3(SIDE_X, 0.0, 0.0)
	# It spins a little ahead of the knuckles, so the disc it sweeps clears the fist.
	var spin := side + Vector3(0.0, 0.01, FAN_FWD)
	return {
		"wp": [[0.0, Vector3.ZERO], [0.3, Vector3(0.0, 0.012, 0.0), O], [0.5, Vector3.ZERO], [0.85, Vector3(0.0, 0.01, 0.0)],
			[1.4, Vector3(0.0, -0.012, 0.0)], [1.95, Vector3(0.0, 0.01, 0.0)], [2.4, Vector3.ZERO], [2.55, Vector3(0.0, 0.014, 0.0), O],
			[2.8, Vector3.ZERO]],
		"wr": [[0.0, Vector3.ZERO], [0.3, Vector3(14.0, 0.0, 0.0), O], [0.5, Vector3(0.0, 0.0, 8.0)], [0.85, Vector3(4.0, 0.0, 14.0)],
			[1.4, Vector3(-4.0, 0.0, 10.0)], [1.95, Vector3(4.0, 0.0, 14.0)], [2.35, Vector3.ZERO], [2.55, Vector3(14.0, 0.0, 0.0), O],
			[2.85, Vector3.ZERO]],
		"kp": [[0.0, Vector3.ZERO], [0.42, Vector3.ZERO], [0.52, up, O], [0.62, up + side, S], [0.72, spin, S],
			[2.05, spin], [2.13, up + side, S], [2.23, up, S], [2.33, Vector3.ZERO, I]],
		"kr": [[0.0, Vector3.ZERO], [0.72, Vector3.ZERO], [2.05, Vector3(-1080.0, 0.0, 0.0), S]],
		"kc": [[0.0, centre]],
		"ko": [[0.0, Vector3.ZERO]],
		"a": [[0.0, 0.0], [0.12, 0.0], [0.32, 180.0, O], [2.4, 180.0], [2.58, 0.0, O]],
		"bw": [[0.0, 0.0]],
	}


## Helix: the open knife rolls round the index finger twice, the handles
## splitting into a butterfly each turn as it winds up and back down, then
## settles into the fist.
func _helix() -> Dictionary:
	var finger := Vector3(0.0, -0.03, _pin.z + 0.035)
	var up := Vector3(0.0, 0.07, 0.0)
	var side := Vector3(SIDE_X, 0.0, 0.0)
	return {
		"wp": [[0.0, Vector3.ZERO], [0.35, Vector3(0.0, -0.01, 0.0)], [0.6, Vector3(0.0, 0.006, 0.0)], [1.1, Vector3(0.0, 0.02, 0.0)],
			[1.6, Vector3(0.0, -0.01, 0.0)], [2.1, Vector3(0.0, 0.02, 0.0)], [2.6, Vector3.ZERO]],
		"wr": [[0.0, Vector3.ZERO], [0.4, Vector3(-6.0, 0.0, 10.0)], [1.1, Vector3(4.0, 8.0, 18.0)], [1.7, Vector3(-4.0, -6.0, 8.0)],
			[2.3, Vector3(4.0, 6.0, 14.0)], [2.9, Vector3.ZERO]],
		"kp": [[0.0, Vector3.ZERO], [0.35, Vector3.ZERO], [0.46, up, O], [0.56, up + side, S], [0.66, side, S],
			[1.15, side + Vector3(0.0, 0.03, 0.0), S], [1.65, side + Vector3(0.0, -0.005, 0.0), S], [2.15, side + Vector3(0.0, 0.03, 0.0), S],
			[2.3, side, S], [2.4, up + side, S], [2.5, up, S], [2.6, Vector3.ZERO, I]],
		"kr": [[0.0, Vector3.ZERO], [0.66, Vector3.ZERO], [2.3, Vector3(720.0, 0.0, 0.0), S]],
		"kc": [[0.0, finger]],
		"ko": [[0.0, Vector3.ZERO]],
		"a": [[0.0, 0.0]],
		"bw": [[0.0, 0.0], [0.7, 0.0], [1.05, -125.0, S], [1.45, 0.0, S], [1.85, -125.0, S], [2.25, 0.0, S]],
	}


## Zen rollover: the knife pops up out of the fist and rolls right round the
## hand (over the back of it first) with the bite handle swinging open and
## shut as it goes over, then sinks back into the grip and flips shut and open.
func _zen() -> Dictionary:
	var lifted := Vector3(0.0, ROLL_R, 0.0)
	var out := Vector3(0.0, ROLL_R, ROLL_FWD)
	return {
		"wp": [[0.0, Vector3.ZERO], [0.4, Vector3(0.0, -0.012, 0.0)], [0.55, Vector3(0.0, 0.01, 0.0), O], [0.8, Vector3.ZERO],
			[1.75, Vector3.ZERO], [1.9, Vector3(0.0, -0.015, 0.0), O], [2.2, Vector3.ZERO], [2.4, Vector3(0.0, 0.012, 0.0), O], [2.7, Vector3.ZERO]],
		"wr": [[0.0, Vector3.ZERO], [0.4, Vector3(-8.0, 0.0, 0.0)], [0.55, Vector3(8.0, 0.0, 0.0), O], [0.8, Vector3(4.0, 0.0, -10.0)],
			[1.3, Vector3(4.0, 0.0, 12.0)], [1.75, Vector3(0.0, 0.0, -6.0)], [2.2, Vector3.ZERO], [2.4, Vector3(10.0, 0.0, 0.0), O],
			[2.6, Vector3(-5.0, 0.0, 0.0), O], [2.9, Vector3.ZERO]],
		"kp": [[0.0, Vector3.ZERO]],
		"kr": [[0.0, Vector3.ZERO], [0.72, Vector3.ZERO], [1.72, Vector3(0.0, 0.0, -360.0), S]],
		"kc": [[0.0, Vector3.ZERO]],
		"ko": [[0.0, Vector3.ZERO], [0.42, Vector3.ZERO], [0.56, lifted, O], [0.72, out, S], [1.72, out], [1.84, lifted, S], [1.98, Vector3.ZERO, I]],
		"a": [[0.0, 0.0], [2.2, 0.0], [2.4, 180.0, O], [2.6, 0.0, O]],
		"bw": [[0.0, 0.0], [0.85, 0.0], [1.2, -150.0, S], [1.6, 0.0, S]],
	}


## JACKPOT: a high aerial (three turns and a half twist, the view tipping up
## to follow it), caught into a fan beside the fingers, rolled round the back
## of the hand, then a snap shut and open that locks the latch with a
## sparkle, a burst of ticket confetti and a JACKPOT! sign.
func _jackpot() -> Dictionary:
	var centre := _pin.lerp(_butt, 0.3)
	var up := Vector3(0.0, 0.07, 0.0)
	var side := Vector3(SIDE_X, 0.0, 0.0)
	var lifted := Vector3(0.0, ROLL_R, 0.0)
	var out := Vector3(0.0, ROLL_R, ROLL_FWD)
	return {
		"wp": [[0.0, Vector3.ZERO], [0.45, Vector3(0.0, -0.03, 0.01)], [0.58, Vector3(0.0, 0.04, -0.01), O], [1.0, Vector3(0.0, 0.0, 0.0)],
			[2.0, Vector3(0.0, 0.015, 0.0)], [2.12, Vector3(0.0, -0.04, 0.0), O], [2.5, Vector3.ZERO], [4.6, Vector3.ZERO],
			[4.75, Vector3(0.0, 0.02, 0.0), O], [4.95, Vector3(0.0, -0.015, 0.0), O], [5.3, Vector3.ZERO]],
		"wr": [[0.0, Vector3.ZERO], [0.45, Vector3(-22.0, 0.0, 0.0)], [0.58, Vector3(26.0, 0.0, 0.0), O], [1.1, Vector3(0.0, 0.0, 0.0)],
			[1.95, Vector3(-8.0, 0.0, 0.0)], [2.12, Vector3(10.0, 0.0, 0.0), O], [2.5, Vector3(2.0, 0.0, 10.0)], [3.3, Vector3(4.0, 0.0, 14.0)],
			[3.8, Vector3(4.0, 0.0, -10.0)], [4.3, Vector3(0.0, 0.0, 8.0)], [4.6, Vector3.ZERO], [4.75, Vector3(16.0, 0.0, 0.0), O],
			[4.95, Vector3(-10.0, 0.0, -6.0), O], [5.4, Vector3(4.0, 0.0, 4.0)], [5.8, Vector3.ZERO]],
		"kp": [[0.0, Vector3.ZERO], [0.58, Vector3.ZERO], [1.35, Vector3(0.0, 0.3, -0.02), UP], [2.12, Vector3.ZERO, DN],
			[2.3, Vector3.ZERO], [2.4, up, O], [2.5, up + side, S], [2.6, side, S], [3.5, side], [3.6, side + up, S], [3.7, up, S],
			[3.72, Vector3.ZERO]],
		"kr": [[0.0, Vector3.ZERO], [0.58, Vector3.ZERO], [2.12, Vector3(1080.0, 360.0, 0.0), L], [2.6, Vector3(1080.0, 360.0, 0.0)],
			[3.5, Vector3(1800.0, 360.0, 0.0), S], [3.72, Vector3(1800.0, 360.0, 0.0)], [4.5, Vector3(1800.0, 360.0, -360.0), S]],
		"kc": [[0.0, centre], [3.5, centre], [3.51, Vector3.ZERO]],
		"ko": [[0.0, Vector3.ZERO], [3.7, Vector3.ZERO], [3.72, up], [3.8, out, S], [4.5, out], [4.6, lifted, S], [4.7, Vector3.ZERO, I]],
		"a": [[0.0, 0.0], [4.72, 0.0], [4.84, 180.0, O], [4.97, 0.0, O]],
		"bw": [[0.0, 0.0], [0.7, 0.0], [1.3, -150.0, S], [2.0, 0.0, I], [3.85, 0.0], [4.1, -150.0, S], [4.4, 0.0, S]],
	}


## [t, kind, arg] moments: "snd" a sound, "shake" the camera, "kick" the view
## up (degrees), "jackpot" the latch sparkle, the confetti and the sign.
func _cues_of(which: int) -> Array:
	match which:
		Trick.AERIAL:
			return [[0.6, "snd", &"tflip_swish"], [0.66, "snd", &"tflip_twirl"], [1.52, "shake", 0.12]]
		Trick.FAN:
			return [[0.75, "snd", &"tflip_twirl"], [1.3, "snd", &"tflip_swish"], [2.33, "snd", &"tflip_flip"]]
		Trick.HELIX:
			return [[0.7, "snd", &"tflip_swish"], [1.5, "snd", &"tflip_swish"]]
		Trick.ZEN:
			return [[0.56, "snd", &"tflip_swish"], [1.2, "snd", &"tflip_swish"], [1.98, "snd", &"tflip_flip"]]
		Trick.JACKPOT:
			return [[0.56, "snd", &"tflip_swish"], [0.6, "kick", 5.0], [0.62, "snd", &"tflip_twirl"], [1.3, "snd", &"tflip_twirl"],
				[2.12, "shake", 0.18], [2.12, "snd", &"tflip_flip"], [2.62, "snd", &"tflip_twirl"], [3.8, "snd", &"tflip_swish"],
				[4.97, "jackpot", 0.0]]
	return [[0.6, "snd", &"tflip_swish"], [1.6, "snd", &"tflip_swish"]]


# --- every frame -------------------------------------------------------------------

## The blade, the bite handle and the latch for the knife's shape (a, bw).
func _pose_parts(v: WeaponView, a: float, bw: float) -> void:
	var blade := v.part("Blade")
	var handle_b := v.part("HandleB")
	var latch := v.part("Latch")
	if blade:
		blade.transform = v.rest_transform("Blade") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(a)), Vector3.ZERO)
	if handle_b:
		handle_b.transform = v.rest_transform("HandleB") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(bw - a)), Vector3.ZERO)
	# The latch frees HandleB a little before it moves and clicks home once it is back.
	var off := maxf(absf(_wrap(a)), absf(_wrap(bw)))
	var goal := clampf(off / 12.0, 0.0, 1.0)
	_latch_out = goal if goal > _latch_out else lerpf(_latch_out, goal, 0.35)
	if latch:
		latch.transform = v.rest_transform("Latch") * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(LATCH_OUT * _latch_out)), Vector3.ZERO)


## A pin clack each time the blade or the bite handle passes open or shut;
## the latch click as it snaps home.
func _sounds(v: WeaponView, a: float, bw: float) -> void:
	if not v.is_visible_in_tree():
		return
	var ha := _half(a)
	var hb := _half(bw)
	if ha != _clack_a or hb != _clack_b:
		Sfx.play(&"tflip_flip", -9.0, _rng.randf_range(0.95, 1.1))
	_clack_a = ha
	_clack_b = hb
	if _latch_out < 0.04 and _latch_out > 0.0:
		_latch_out = 0.0
		Sfx.play(&"tflip_latch", -6.0, _rng.randf_range(0.97, 1.04))


func _fire_cues(v: WeaponView, t: float) -> void:
	while _cue < _cues.size() and t >= float(_cues[_cue][0]):
		var cue: Array = _cues[_cue]
		_cue += 1
		match String(cue[1]):
			"snd":
				Sfx.play(cue[2], -6.0, _rng.randf_range(0.96, 1.05))
			"shake":
				if v.player:
					v.player.add_shake(float(cue[2]))
			"kick":
				if v.player:
					v.player.add_recoil(float(cue[2]))
			"jackpot":
				_jackpot_flair(v, t)


## The latch locks: a sparkle on it, ticket confetti off the knife and the sign.
func _jackpot_flair(v: WeaponView, t: float) -> void:
	var handle_a := v.part("HandleA")
	if handle_a == null:
		return
	var latch_at := WeaponInspect.in_model(v, v.part("Latch")) if v.part("Latch") else _butt
	var mid := WeaponInspect.in_model(v, handle_a).lerp(latch_at, 0.5)
	v.spark_burst(latch_at, Vector3(0.0, 1.0, 0.0), SPARKLE, 22, 0.6, 0.5, 0.006)
	v.spark_burst(mid + Vector3(0.0, 0.04, 0.0), Vector3(0.0, 1.0, -0.3), CONFETTI, 44, 1.1, 1.0, 0.012)
	Sfx.play(&"tflip_jackpot", -4.0)
	if v.player:
		v.player.add_shake(0.12)
	_label = Label3D.new()
	_label.name = "JackpotSign"
	_label.text = "JACKPOT!"
	_label.font = UiKit.display_font()
	_label.font_size = 96
	_label.pixel_size = 0.0007
	_label.modulate = Color(1.0, 0.86, 0.3)
	_label.outline_modulate = Color(0.85, 0.1, 0.35)
	_label.outline_size = 22
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.shaded = false
	_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label.position = mid + Vector3(0.0, 0.1, -0.06)
	v.model.add_child(_label)
	_label_at = t


## The sign pops up with an overshoot, hangs, then rises and fades.
func _update_label(t: float) -> void:
	if _label == null:
		return
	var k := t - _label_at
	var pop := 1.0 + 0.35 * exp(-7.0 * k) * sin(k * 18.0) if k > 0.08 else k / 0.08
	_label.scale = Vector3.ONE * maxf(0.01, pop)
	var fade := 1.0 - clampf((k - 0.55) / 0.3, 0.0, 1.0)
	_label.modulate.a = fade
	_label.outline_modulate.a = fade
	_label.position.y += maxf(0.0, t - _prev_t) * 0.05


# --- the smear ----------------------------------------------------------------------

## A faint additive ribbon behind the point while it spins fast.
func _build_smear(v: WeaponView) -> void:
	_smear_mesh = ImmediateMesh.new()
	_smear = MeshInstance3D.new()
	_smear.name = "TrickSmear"
	_smear.mesh = _smear_mesh
	_smear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_smear.material_override = m
	v.add_child(_smear)
	_samples.clear()


func _update_smear(v: WeaponView, t: float) -> void:
	var tip_node := v.part("BladeTip")
	if _smear == null or tip_node == null:
		return
	var tip := v.to_local(tip_node.global_position)
	var root := v.to_local(v.part("HandleA").global_position).lerp(tip, 0.45)
	var dt := maxf(0.001, t - _prev_t)
	var speed := 0.0 if _samples.is_empty() else tip.distance_to(_samples[0][0]) / dt
	_samples.push_front([tip, root, clampf((speed - 0.6) / SMEAR_FULL, 0.0, 1.0)])
	if _samples.size() > SMEAR_SAMPLES:
		_samples.resize(SMEAR_SAMPLES)
	_smear_mesh.clear_surfaces()
	var lit := false
	for s in _samples:
		lit = lit or float(s[2]) > 0.05
	if not lit or _samples.size() < 2:
		return
	var color := v.data.tracer_color
	_smear_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _samples.size():
		var s: Array = _samples[i]
		var fade := (1.0 - float(i) / (_samples.size() - 1)) * float(s[2])
		_smear_mesh.surface_set_color(Color(color, 0.0))
		_smear_mesh.surface_add_vertex(s[1])
		_smear_mesh.surface_set_color(Color(color, 0.55 * fade))
		_smear_mesh.surface_add_vertex(s[0])
	_smear_mesh.surface_end()


# --- helpers -------------------------------------------------------------------------

## A track's value at `t`: each stretch eased by the ease on its end key.
func _sample(track: String, t: float) -> Variant:
	var keys: Array = _tracks[track]
	if t <= float(keys[0][0]):
		return keys[0][1]
	for i in range(1, keys.size()):
		var b: Array = keys[i]
		if t <= float(b[0]):
			var a: Array = keys[i - 1]
			var u := clampf((t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0)
			return lerp(a[1], b[1], _ease(u, int(b[2]) if b.size() > 2 else S))
	return keys[keys.size() - 1][1]


static func _ease(u: float, kind: int) -> float:
	match kind:
		L:
			return u
		O:
			return 1.0 - pow(1.0 - u, 3.0)
		I:
			return u * u * u
		UP:
			return 1.0 - (1.0 - u) * (1.0 - u)
		DN:
			return u * u
	return u * u * (3.0 - 2.0 * u)


## Which half turn an angle is in (open side or shut side), for the clacks.
static func _half(angle: float) -> int:
	return int(floor((angle + 90.0) / 180.0))


## An angle folded into -180..180.
static func _wrap(angle: float) -> float:
	return wrapf(angle, -180.0, 180.0)
