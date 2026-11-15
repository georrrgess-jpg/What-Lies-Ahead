extends RefCounted
## Road Rager "pit stop": the gun rolls over to show the rack, the support
## hand yanks the empty rack off the flank and tosses it; a hologram rack of
## hubcaps prints in and is slammed home. Then the flourish: the top hubcap is
## flipped up off the rack, spins in the air and drops onto the tray, the
## pitching tyres rev with a screech and the magnet clacks.

const SPARES := 2
const EMBER := [Color(1.0, 0.55, 0.15), Color(1.0, 0.95, 0.8), Color(1.0, 0.82, 0.3)]


func play(v: WeaponView, d: float) -> void:
	for part in ["Loaded", "WheelL", "WheelR", "Catcher"]:
		v.register_part(part)
	for i in SPARES:
		v.register_part("Cap%d" % i)
	# Starting a reload resets every part: put back only what is still loaded.
	var mag := v.data.magazine_size
	if v.player and v.player.weapons:
		mag = v.player.weapons.magazine()
	for i in SPARES:
		var c := v.part("Cap%d" % i)
		if c:
			c.visible = i < mag - 1
	var loaded := v.part("Loaded")
	if loaded:
		loaded.visible = mag > 0
	# Roll the rack side up, hold, then back for the flip.
	v.track("Root", d, [[0.1, Vector3(0.01, 0.025, 0.0), Vector3(4, -6, -20)], [0.62, Vector3(0.01, 0.025, 0.0), Vector3(4, -6, -20)],
		[0.72, Vector3(0.0, 0.01, 0.0), Vector3(-2, 0, -4)], [0.84, Vector3(0.0, 0.03, 0.0), Vector3(-9, 0, 3)], [0.95, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.06, 0.16, d, 1.0, 0.2)
	# The empty rack is yanked off the flank and tossed down to the left.
	v.track("Cell", d, [[0.14, Vector3.ZERO, Vector3.ZERO], [0.22, Vector3(-0.05, 0.01, 0.0), Vector3(0, 0, 10)],
		[0.36, Vector3(-0.3, -0.24, 0.06), Vector3(30, 40, 160), 0.8]], Tween.TRANS_QUAD, Tween.EASE_IN)
	v.at(0.15, d, func(): Sfx.play(&"reload_clunk", -6.0, 1.15))
	v.burst(0.18, d, "EjectPoint", "sparks")
	v.hide_part(0.36, d, "Cell")
	# The support hand leaves the foregrip, grabs the rack, comes back with the new one.
	v.track("ArmL", d, [[0.1, Vector3(-0.04, 0.01, 0.06), Vector3(0, 0, -10)], [0.2, Vector3(-0.1, 0.04, 0.14), Vector3(0, 10, -24)],
		[0.3, Vector3(-0.2, -0.06, 0.12), Vector3(0, 14, -36)], [0.42, Vector3(-0.12, 0.0, 0.14), Vector3(0, 10, -20)],
		[0.6, Vector3(-0.1, 0.03, 0.14), Vector3(0, 10, -24)], [0.7, Vector3(-0.04, 0.01, 0.06), Vector3(0, 0, -10)],
		[0.78, Vector3.ZERO, Vector3.ZERO]])
	# A hologram rack prints in beside the flank and is slammed home.
	v.track("CellHolo", d, [[0.38, Vector3(-0.08, 0.0, 0.0), Vector3(0, 0, -20), 1.0, "hold"], [0.54, Vector3(-0.04, 0.0, 0.0), Vector3.ZERO],
		[0.6, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.38, 0.56, d)
	v.at(0.6, d, _rack_full.bind(v))
	v.solidify("CellHolo", "Cell", 0.6, d)
	v.at(0.6, d, func(): Sfx.play(&"reload_clunk", -3.0, 0.9); var p := v.owner as Player; if p: p.add_shake(0.06))
	# The flip: up off the rack, spinning, and down onto the tray.
	v.at(0.68, d, func(): if loaded: loaded.visible = true)
	v.track("Loaded", d, _flip_keys(0.68, 0.92), Tween.TRANS_LINEAR)
	v.at(0.7, d, func(): Sfx.play(&"hub_flip", -5.0))
	v.track("WheelL", d, ReloadKeys.spin(0.86, 1.0, Vector3.UP, 1080.0, Vector3.ZERO, Vector3.ZERO, 1.0), Tween.TRANS_LINEAR)
	v.track("WheelR", d, ReloadKeys.spin(0.86, 1.0, Vector3.UP, -1080.0, Vector3.ZERO, Vector3.ZERO, 1.0), Tween.TRANS_LINEAR)
	v.track("Catcher", d, [[0.9, Vector3.ZERO, Vector3.ZERO], [0.93, Vector3(0, 0, 0.02), Vector3(-16, 0, 0)], [1.0, Vector3.ZERO, Vector3.ZERO]])
	v.at(0.92, d, _landed.bind(v))
	v.glow_ramp(0.92, 0.95, d, 0.6, 3.0)
	v.glow_ramp(0.95, 1.0, d, 3.0, 1.0)


## The flip off the rack: a hop up and over onto the tray, two turns on the
## way (in quarter-turn keys, so the turn is not taken the short way round).
func _flip_keys(t0: float, t1: float) -> Array:
	var start := Vector3(-0.07, 0.0, 0.2)
	var keys: Array = [[t0, start, Vector3(0, 0, 90), 0.6, "hold"]]
	var steps := 8
	for i in range(1, steps + 1):
		var k := float(i) / steps
		var at := start.lerp(Vector3.ZERO, k) + Vector3(0.0, sin(k * PI) * 0.13, 0.0)
		keys.append([lerpf(t0, t1, k), at, Vector3(0, fmod(720.0 * k, 360.0), 90.0 * (1.0 - k)), lerpf(0.6, 1.0, k)])
	return keys


## The new rack, full.
func _rack_full(v: WeaponView) -> void:
	for i in SPARES:
		var c := v.part("Cap%d" % i)
		if c:
			c.visible = true


func _landed(v: WeaponView) -> void:
	Sfx.play(&"hub_catch", -4.0, 1.1)
	var muzzle := v.model.find_child("Muzzle", true, false) as Node3D if v.model else null
	if muzzle:
		v.spark_burst(v.model.global_transform.affine_inverse() * muzzle.global_position, Vector3.UP, EMBER, 12, 0.9, 0.3, 0.009)
