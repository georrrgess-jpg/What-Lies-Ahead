extends RefCounted
## T-Minus Six "launch gantry": the launcher rolls its pod up toward the eye,
## the arming rings go dark and a teal hologram gantry (CellHolo) projects
## over the pod. One by one the empty tubes are filled: a fresh rocket
## appears high on the gantry's rails behind the pod and slides down and
## forward into its tube with a click, while the dish spins up. Then the
## countdown strip runs 3-2-1, the gantry dissolves and the pod flares:
## go for launch. Rockets still in the pod stay put, so a partial reload has
## fewer to load (and is shorter: TMinusSixMode.PARTIAL_RELOAD_CUT).

const ROCKETS := 6
const COUNT := 3
## Where a fresh rocket appears on the rails (above and behind its tube: it
## slides forward and down into the pod through the gantry).
const RAIL_START := Vector3(0.0, 0.09, 0.1)
const RAIL_BEND := Vector3(0.0, 0.035, 0.05)
const LOAD_START := 0.24
const LOAD_END := 0.72
const SLIDE := 0.13
const COUNT_AT := [0.76, 0.82, 0.88]
const TEAL := [Color(0.247, 0.941, 0.831), Color.WHITE, Color(1.0, 0.824, 0.247)]


func play(v: WeaponView, d: float) -> void:
	for i in ROCKETS:
		for prefix in ["Rocket", "Arm", "Pip"]:
			v.register_part("%s%d" % [prefix, i])
	for i in COUNT:
		v.register_part("Count%d" % i)
	for part in ["Dish", "Bulb", "Trigger"]:
		v.register_part(part)
	var mag := v.data.magazine_size
	if v.player and v.player.weapons:
		mag = v.player.weapons.magazine()
	for i in ROCKETS:
		_show(v, "Arm%d" % i, false)
		_show(v, "Pip%d" % i, false)
		_show(v, "Rocket%d" % i, i < mag)
	for i in COUNT:
		_show(v, "Count%d" % i, false)
	# The pod rolls up toward the eye, held while it loads, then a little settle.
	v.track("Root", d, [[0.14, Vector3(-0.02, 0.045, 0.02), Vector3(-8, 16, 18)], [0.74, Vector3(-0.02, 0.045, 0.02), Vector3(-9, 18, 18)],
		[0.86, Vector3(0.0, 0.015, 0.0), Vector3(4, 6, -4)], [0.94, Vector3(0.0, 0.02, 0.0), Vector3(-5, 0, 2)], [1.0, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.04, 0.14, d, 1.0, 0.3)
	# The gantry projects over the pod, rising into place.
	v.track("CellHolo", d, [[0.1, Vector3(0, -0.02, 0), Vector3.ZERO, 0.85, "hold"], [0.24, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.1, 0.26, d)
	v.at(0.1, d, func(): Sfx.play(&"tm6_gantry", -4.0))
	# The empty tubes fill one by one down the rails.
	var empty := ROCKETS - mini(mag, ROCKETS)
	for k in empty:
		var i := mini(mag, ROCKETS) + k
		var t0 := lerpf(LOAD_START, LOAD_END - SLIDE, float(k) / maxf(1.0, empty - 1)) if empty > 1 else LOAD_START + 0.1
		var name := "Rocket%d" % i
		v.at(t0, d, _show.bind(v, name, true))
		v.track(name, d, [[t0, RAIL_START, Vector3(-20, 0, 0), 0.6, "hold"], [t0 + SLIDE * 0.55, RAIL_BEND, Vector3(-6, 0, 0), 0.95],
			[t0 + SLIDE, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		v.at(t0 + SLIDE, d, func(): Sfx.play(&"tm6_rail", -5.0, 1.0 + 0.05 * k))
	v.track("Dish", d, ReloadKeys.spin(0.2, 0.9, Vector3.UP, 1080.0, Vector3.ZERO, Vector3.ZERO, -0.6), Tween.TRANS_LINEAR)
	# Countdown: 3, 2, 1...
	for n in COUNT:
		v.at(COUNT_AT[n], d, _count.bind(v, COUNT - n))
	v.at(0.94, d, _go.bind(v))
	v.solidify("CellHolo", "Cell", 0.94, d)
	v.glow_ramp(0.94, 0.97, d, 0.3, 3.2)
	v.glow_ramp(0.97, 1.0, d, 3.2, 1.0)


func _show(v: WeaponView, part: String, on: bool) -> void:
	var p := v.part(part)
	if p:
		p.visible = on


## The strip shows `lit` lights, with a blip that climbs as it counts down.
func _count(v: WeaponView, lit: int) -> void:
	for i in COUNT:
		_show(v, "Count%d" % i, i < lit)
	Sfx.play(&"tm6_count", -6.0, 1.0 + 0.12 * (COUNT - lit))


## Go: the strip lights up full and sparks fly off the pod's mouth.
func _go(v: WeaponView) -> void:
	for i in COUNT:
		_show(v, "Count%d" % i, true)
	var muzzle := v.model.find_child("Muzzle", true, false) as Node3D if v.model else null
	if muzzle:
		v.spark_burst(v.model.global_transform.affine_inverse() * muzzle.global_position, Vector3(0, 1, -0.5), TEAL, 12, 0.8, 0.3, 0.008)
	Sfx.play(&"tm6_ready", -4.0)
