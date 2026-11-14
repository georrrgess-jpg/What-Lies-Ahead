extends RefCounted
## Whirligig "vent and spin": the overheated wheel goes dark and blows steam,
## the spent heat canister kicks out of the left flank, a fresh one prints in,
## then the support hand flicks the prize wheel: it spins four turns, the
## ticker clacking slower and slower, and lands with a 'ding-ding' as the
## bulbs flare back on.


func play(v: WeaponView, d: float) -> void:
	v.track("Root", d, [[0.12, Vector3(0.02, 0.03, 0.0), Vector3(-6, 16, 22)], [0.86, Vector3(0.02, 0.03, 0.0), Vector3(-6, 16, 22)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.05, 0.2, d, 1.0, 0.1)
	for t in [0.06, 0.16, 0.26]:
		v.burst(t, d, "VentPoint", "steam")
	# The spent canister kicks out and a new one prints in.
	v.track("Cell", d, [[0.22, Vector3.ZERO, Vector3.ZERO], [0.28, Vector3(-0.03, 0, 0), Vector3.ZERO],
		[0.44, Vector3(-0.2, -0.2, 0.05), Vector3(0, 0, -120), 0.75]], Tween.TRANS_QUAD, Tween.EASE_IN)
	v.burst(0.27, d, "EjectPoint", "sparks")
	v.hide_part(0.44, d, "Cell")
	v.track("CellHolo", d, [[0.46, Vector3(-0.12, 0, 0), Vector3.ZERO, 1.0, "hold"], [0.6, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_CUBIC, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.46, 0.6, d)
	v.solidify("CellHolo", "Cell", 0.62, d)
	# The support hand comes up beside the wheel and flicks it down.
	v.track("ArmL", d, [[0.6, Vector3.ZERO, Vector3.ZERO], [0.66, Vector3(0, -0.05, 0.02), Vector3.ZERO],
		[0.74, Vector3(-0.14, 0.09, -0.19), Vector3(0, 0, -20)], [0.78, Vector3(-0.14, -0.03, -0.2), Vector3(0, 0, -35)],
		[0.86, Vector3(0, -0.05, 0.02), Vector3.ZERO], [0.92, Vector3.ZERO, Vector3.ZERO]])
	v.track("Barrels", d, ReloadKeys.spin(0.77, 1.0, Vector3.BACK, -1440.0, Vector3.ZERO, Vector3.ZERO, 1.0), Tween.TRANS_LINEAR)
	v.at(0.77, d, func(): Sfx.play(&"weap_whirl_jackpot", -3.0))
	# The ticker flaps over the pegs, slower and slower.
	var flaps: Array = [[0.77, Vector3.ZERO, Vector3.ZERO, 1.0, "hold"]]
	var t := 0.77
	var gap := 0.008
	while t + gap < 0.99:
		flaps.append([t + gap * 0.3, Vector3.ZERO, Vector3(28, 0, 0)])
		flaps.append([t + gap, Vector3.ZERO, Vector3.ZERO])
		t += gap
		gap *= 1.22
	v.track("Ticker", d, flaps, Tween.TRANS_LINEAR)
	v.glow_ramp(0.95, 0.98, d, 0.1, 3.2)
	v.glow_ramp(0.98, 1.0, d, 3.2, 1.0)
