extends RefCounted
## Sarsaparilla Six "speed-loader and cap flick": the revolver rolls over to
## show its left side and the cylinder flicks out on its crane, spinning; the
## spent bottle rounds tumble out of the back of it and the off hand comes
## round behind it. A hologram speed-loader (CellHolo: six rounds in a star
## clip) prints in on the palm, is pushed home into the cylinder and
## dissolves in a puff of fizz, leaving fresh rounds behind. Then the thumb
## flicks the gold Last Call cap up: it spins through the air and clicks
## onto the sixth round. A flick of the wrist swings the cylinder back in,
## spinning, ratcheting to a stop; the hammer is thumbed back and the gun
## settles. The swing, rattle, hologram, ratchet and cock are in the reload
## sound (ssx_reload), timed for WeaponData.reload_time; the cap's ping plays
## on the catch.

const ROUNDS := 6
## Where the cylinder sits swung out (model space) and how far it spins out and back in.
const OUT := Vector3(-0.052, 0.006, 0.0)
const SPIN_OUT := 360.0
## Back in: two turns, less the angle it started from, so it stops on the first round.
const SPIN_IN := -720.0
## The hammer cocked (degrees, as the view holds it at rest).
const COCK_DEG := 30.0
## The cap flick: start (Round5 space, by the palm), height of its arc, turns.
const CAP_FROM := Vector3(-0.045, -0.045, 0.06)
const CAP_ARC := 0.075
const CAP_TURNS := 900.0
const CAP_START := 0.58
const CAP_END := 0.72
const FIZZ := [Color(1.0, 0.957, 0.839), Color(1.0, 0.647, 0.227), Color(1.0, 0.85, 0.6)]
const GOLD := [Color(1.0, 0.82, 0.25), Color(1.0, 0.957, 0.839), Color(1.0, 0.239, 0.431)]


func play(v: WeaponView, d: float) -> void:
	for p in ["Cylinder", "Hammer", "ArmL", "Halo5"]:
		v.register_part(p)
	for i in ROUNDS:
		for prefix in ["Round", "Cap", "Soda"]:
			v.register_part("%s%d" % [prefix, i])
	var mag := ROUNDS
	if v.player and v.player.weapons:
		mag = v.player.weapons.magazine()
	var spent := clampi(ROUNDS - mag, 0, ROUNDS)
	for i in ROUNDS:
		_show(v, "Cap%d" % i, i >= spent and i < ROUNDS - 1)
		_show(v, "Soda%d" % i, i >= spent)
	_show(v, "Halo5", false)
	_gun(v, d)
	_cylinder(v, d, spent)
	_hand(v, d)
	_loader(v, d, spent)
	_cap(v, d)
	v.track("Hammer", d, [[0.02, Vector3.ZERO, Vector3(COCK_DEG, 0, 0)], [0.08, Vector3.ZERO, Vector3(COCK_DEG * 0.4, 0, 0)],
		[0.84, Vector3.ZERO, Vector3(COCK_DEG * 0.4, 0, 0)], [0.9, Vector3.ZERO, Vector3(COCK_DEG + 4.0, 0, 0)],
		[0.94, Vector3.ZERO, Vector3(COCK_DEG, 0, 0)]], Tween.TRANS_CUBIC, Tween.EASE_OUT)


## The revolver rolls over to its left side and tips up for the loading,
## dips for the push and the flick, then swings back with a small settle.
func _gun(v: WeaponView, d: float) -> void:
	v.track("Root", d, [[0.12, Vector3(-0.07, 0.05, 0.03), Vector3(6, 34, 12)], [0.3, Vector3(-0.075, 0.055, 0.03), Vector3(8, 38, 14)],
		[0.46, Vector3(-0.075, 0.048, 0.03), Vector3(6, 36, 12)], [0.56, Vector3(-0.075, 0.056, 0.03), Vector3(10, 37, 14)],
		[0.76, Vector3(-0.07, 0.054, 0.03), Vector3(8, 36, 12)], [0.86, Vector3(0.006, -0.006, 0.0), Vector3(-5, -3, -6)],
		[0.94, Vector3(0.0, 0.004, 0.0), Vector3(3, 0, 2)], [1.0, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.04, 0.16, d, 1.0, 0.35)


## Out on the crane with a spin, held out for the loading, back in spinning
## down to a stop on the first round.
func _cylinder(v: WeaponView, d: float, spent: int) -> void:
	# It starts where the shots left it (a sixth a round), so nothing snaps.
	var start := -60.0 * spent
	var keys: Array = [[0.0, Vector3.ZERO, Vector3(0, 0, start), 1.0, "hold"]]
	var out := ReloadKeys.spin(0.1, 0.24, Vector3.BACK, SPIN_OUT, Vector3.ZERO, OUT, 1.0)
	for key in out:
		key[2] = key[2] + Vector3(0, 0, start)
	keys += out
	keys.append([0.76, OUT, Vector3(0, 0, start)])
	var back := ReloadKeys.spin(0.76, 0.92, Vector3.BACK, SPIN_IN - start, OUT, Vector3.ZERO, 1.0)
	for key in back:
		key[2] = key[2] + Vector3(0, 0, start)
	keys += back
	v.track("Cylinder", d, keys, Tween.TRANS_LINEAR)
	# The spent rounds tumble out of the back.
	for i in spent:
		var t0 := 0.25 + 0.012 * i
		var side := -1.0 if i % 2 == 0 else -0.6
		v.track("Round%d" % i, d, [[t0, Vector3.ZERO, Vector3.ZERO], [t0 + 0.05, Vector3(0.012 * side, 0.004, 0.07), Vector3(-60, 0, 20), 0.95],
			[t0 + 0.11, Vector3(0.05 * side, -0.07, 0.15), Vector3(-200, 30, 80), 0.8]], Tween.TRANS_QUAD, Tween.EASE_IN)
		v.hide_part(t0 + 0.11, d, "Round%d" % i)
	v.at(0.25, d, func(): var p := v.owner as Player; if p: p.add_shake(0.03))


## The off hand lets go, comes round behind the swung-out cylinder holding the
## speed-loader, pushes it home, flicks the cap and takes the grip again.
func _hand(v: WeaponView, d: float) -> void:
	v.track("ArmL", d, [[0.08, Vector3(-0.04, -0.03, 0.02), Vector3(0, 0, -8)], [0.2, Vector3(-0.1, -0.03, 0.12), Vector3(-10, 0, -16)],
		[0.32, Vector3(-0.1, -0.01, 0.11), Vector3(-12, 0, -18)], [0.46, Vector3(-0.095, -0.012, 0.075), Vector3(-10, 0, -18)],
		[0.54, Vector3(-0.11, -0.03, 0.1), Vector3(-6, 0, -12)], [0.6, Vector3(-0.1, -0.012, 0.09), Vector3(-18, 0, -14)],
		[0.76, Vector3(-0.08, -0.03, 0.05), Vector3(-6, 0, -10)], [0.9, Vector3.ZERO, Vector3.ZERO]])


## The hologram speed-loader prints in on the palm behind the cylinder, is
## pushed home, and dissolves in fizz leaving fresh rounds.
func _loader(v: WeaponView, d: float, spent: int) -> void:
	v.track("CellHolo", d, [[0.3, OUT + Vector3(-0.004, 0.0, 0.1), Vector3(0, 0, -50), 0.85, "hold"],
		[0.4, OUT + Vector3(0.0, 0.0, 0.05), Vector3(0, 0, -10), 1.0], [0.46, OUT + Vector3(0.0, 0.0, 0.004), Vector3.ZERO]],
		Tween.TRANS_CUBIC, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.3, 0.42, d)
	v.at(0.47, d, _fresh.bind(v, spent))
	v.hide_part(0.5, d, "CellHolo")
	v.glow_ramp(0.47, 0.52, d, 0.35, 2.6)
	v.glow_ramp(0.52, 0.66, d, 2.6, 1.0)


## The rounds the loader leaves behind (the Last Call's cap is still to come).
func _fresh(v: WeaponView, spent: int) -> void:
	for i in spent:
		var r := v.part("Round%d" % i)
		if r:
			r.transform = v.rest_transform("Round%d" % i)
			r.visible = true
	for i in ROUNDS:
		_show(v, "Soda%d" % i, true)
		_show(v, "Cap%d" % i, i < ROUNDS - 1)
	var cyl := v.part("Cylinder")
	if cyl:
		var at := v.model.global_transform.affine_inverse() * cyl.global_position
		v.spark_burst(at + Vector3(0, 0, 0.03), Vector3(0, 0.6, 0.6), FIZZ, 12, 0.7, 0.4, 0.006)


## The Last Call cap: flicked off the thumb, spinning up and over, onto its round.
func _cap(v: WeaponView, d: float) -> void:
	v.at(CAP_START, d, _show.bind(v, "Cap5", true))
	var keys := ReloadKeys.spin(CAP_START, CAP_END, Vector3.RIGHT, CAP_TURNS, CAP_FROM, Vector3.ZERO, 0.4)
	for key in keys:
		var k := clampf((float(key[0]) - CAP_START) / (CAP_END - CAP_START), 0.0, 1.0)
		key[1] = key[1] + Vector3(0.0, CAP_ARC * 4.0 * k * (1.0 - k), 0.0)
	v.track("Cap5", d, keys, Tween.TRANS_LINEAR)
	v.at(CAP_START, d, func(): Sfx.play(&"ssx_click", -10.0, 1.4))
	v.at(CAP_END, d, _capped.bind(v))


func _capped(v: WeaponView) -> void:
	Sfx.play(&"ssx_cap_ping", -5.0)
	var cap := v.part("Cap5")
	if cap:
		var at := v.model.global_transform.affine_inverse() * cap.global_position
		v.spark_burst(at, Vector3(0, 1, 0.3), GOLD, 8, 0.6, 0.3, 0.005)


func _show(v: WeaponView, part: String, on: bool) -> void:
	var p := v.part(part)
	if p:
		p.visible = on
