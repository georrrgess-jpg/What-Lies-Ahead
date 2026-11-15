extends RefCounted
## Balloon Darter "new clip and a party trick": the pistol tips up, the empty
## dart clip drops out from under the barrel and the support hand swats it
## away; a full clip prints in as a hologram and is slapped home. Then the
## flourish: the plunger is pumped three times, the gauge needle swings back
## to green, and every pump blows up a balloon on the muzzle, bigger and
## bigger, until it pops in a shower of confetti.

const TAILS := 6
const CONFETTI := [Color(1.0, 0.3, 0.62), Color(0.35, 0.9, 1.0), Color(1.0, 0.85, 0.2), Color(0.62, 1.0, 0.3), Color.WHITE]


func play(v: WeaponView, d: float) -> void:
	for part in ["Dart", "Plunger", "Needle", "BalloonHolo"]:
		v.register_part(part)
	for i in TAILS:
		v.register_part("Tail%d" % i)
	_show(v, "Dart", false)
	v.track("Root", d, [[0.12, Vector3(0.0, 0.03, 0.0), Vector3(12, 6, 20)], [0.6, Vector3(0.0, 0.03, 0.0), Vector3(12, 6, 20)],
		[0.68, Vector3(0.0, 0.02, 0.0), Vector3(4, -4, -6)], [0.96, Vector3(0.0, 0.02, 0.0), Vector3(4, -4, -6)], [1.0, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.06, 0.16, d, 1.0, 0.25)
	# The empty clip drops out and is swatted away.
	for i in TAILS:
		_show(v, "Tail%d" % i, false)
	v.track("Cell", d, [[0.14, Vector3.ZERO, Vector3.ZERO], [0.24, Vector3(0, -0.1, 0), Vector3.ZERO],
		[0.36, Vector3(-0.24, -0.22, 0.04), Vector3(60, 0, 200), 0.8]], Tween.TRANS_QUAD, Tween.EASE_IN)
	v.at(0.15, d, func(): Sfx.play(&"reload_clunk", -6.0, 1.3))
	v.burst(0.16, d, "EjectPoint", "sparks")
	v.hide_part(0.36, d, "Cell")
	v.track("ArmL", d, [[0.1, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO], [0.24, Vector3(-0.15, -0.06, -0.04), Vector3(0, 0, -14)],
		[0.3, Vector3(-0.17, -0.08, -0.07), Vector3(0, 0, -30)], [0.36, Vector3(-0.15, -0.06, -0.04), Vector3(0, 0, -14)],
		[0.56, Vector3(-0.15, -0.06, -0.04), Vector3(0, 0, -14)], [0.64, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO],
		[0.7, Vector3.ZERO, Vector3.ZERO]])
	# A full clip prints in below and is slapped home.
	v.track("CellHolo", d, [[0.38, Vector3(0, -0.12, 0), Vector3(0, 90, 0), 1.0, "hold"], [0.52, Vector3(0, -0.1, 0), Vector3.ZERO],
		[0.58, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.38, 0.54, d)
	v.solidify("CellHolo", "Cell", 0.58, d)
	v.at(0.58, d, _clip_full.bind(v))
	v.at(0.58, d, func(): Sfx.play(&"reload_clunk", -3.0); var p := v.owner as Player; if p: p.add_shake(0.06))
	# Flourish: three pumps, the needle back to green, the balloon swelling with each.
	var pumps := [0.66, 0.74, 0.82]
	var keys := []
	var balloon := []
	for i in pumps.size():
		var t: float = pumps[i]
		keys.append([t, Vector3(0, 0, 0.035), Vector3.ZERO])
		keys.append([t + 0.05, Vector3.ZERO, Vector3.ZERO])
		balloon.append([t + 0.05, Vector3.ZERO, Vector3(0, 0, 8 - 16 * (i % 2)), 0.6 + 0.65 * i])
		v.at(t, d, func(): Sfx.play(&"gn8b_dart_pump", -4.0, 1.0 + 0.06 * i))
	v.track("Plunger", d, keys, Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.track("Needle", d, [[0.66, Vector3.ZERO, Vector3(-55, 0, 0), 1.0, "hold"], [0.88, Vector3.ZERO, Vector3(55, 0, 0)]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.at(0.66, d, _show.bind(v, "BalloonHolo", true))
	balloon.insert(0, [0.66, Vector3.ZERO, Vector3.ZERO, 0.15, "hold"])
	balloon.append([0.9, Vector3(0, 0.004, 0), Vector3(0, 0, -6), 2.4])
	v.track("BalloonHolo", d, balloon, Tween.TRANS_BACK, Tween.EASE_OUT)
	v.at(0.92, d, _pop.bind(v))
	v.at(0.93, d, _show.bind(v, "Dart", true))
	v.glow_ramp(0.92, 0.95, d, 0.25, 3.0)
	v.glow_ramp(0.95, 1.0, d, 3.0, 1.0)


func _show(v: WeaponView, part: String, on: bool) -> void:
	var p := v.part(part)
	if p:
		p.visible = on


func _clip_full(v: WeaponView) -> void:
	for i in TAILS:
		_show(v, "Tail%d" % i, true)


func _pop(v: WeaponView) -> void:
	_show(v, "BalloonHolo", false)
	Sfx.play(&"gn8b_balloon_pop", -4.0, 1.25)
	var p := v.owner as Player
	if p:
		p.add_shake(0.08)
	var muzzle := v.model.find_child("Muzzle", true, false) as Node3D if v.model else null
	if muzzle:
		var at := v.model.global_transform.affine_inverse() * muzzle.global_position
		v.spark_burst(at + Vector3(0, 0, -0.04), Vector3.UP, CONFETTI, 22, 1.2, 0.5, 0.012)
