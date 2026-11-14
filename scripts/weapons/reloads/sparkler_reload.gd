extends RefCounted
## Sparkler "strike a match": the burnt-out canister pops off the flank and
## tumbles away while the support hand drops out of view; a fresh canister
## prints in as a hologram and solidifies with its fuse dark. The hand comes
## back up holding a match, flicks it alight in a shower of sparks, and a
## spark leaps from the flame to the fuse, which catches and races alight
## from the nose back to the grip. A shake puts the match out, a flick sends
## it spinning away, and the hand returns to the grip.

const SEGMENTS := 8
const FLAME := [Color(1.0, 0.75, 0.25), Color(1.0, 1.0, 0.8), Color(1.0, 0.45, 0.2)]
const SPARKS := [Color(1.0, 0.85, 0.35), Color(1.0, 1.0, 0.85), Color(1.0, 0.5, 0.85)]
const SparklerView := preload("res://scripts/weapons/views/sparkler_view.gd")


func play(v: WeaponView, d: float) -> void:
	for part in ["MatchHolo", "MatchFlame"]:
		v.register_part(part)
	for i in SEGMENTS:
		v.register_part("FuseSeg%d" % i)
	# Starting a reload resets every part: put back the fuse already burnt.
	var lit := SEGMENTS
	if v.player and v.player.weapons:
		lit = ceili(float(v.player.weapons.magazine()) / maxf(1.0, v.data.magazine_size) * SEGMENTS)
	for i in range(lit, SEGMENTS):
		_show(v, "FuseSeg%d" % i, false)
	v.track("Root", d, [[0.12, Vector3(-0.01, 0.025, 0.0), Vector3(8, -8, -16)], [0.84, Vector3(-0.01, 0.025, 0.0), Vector3(8, -8, -16)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.06, 0.16, d, 1.0, 0.25)
	# The spent canister pops off the flank and tumbles away to the left.
	v.track("Cell", d, [[0.12, Vector3.ZERO, Vector3.ZERO], [0.2, Vector3(-0.05, 0.05, 0.0), Vector3(0, 0, 40)],
		[0.34, Vector3(-0.3, -0.08, 0.05), Vector3(120, 30, 260), 0.8]], Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.at(0.13, d, func(): Sfx.play(&"reload_clunk", -7.0, 1.4))
	v.burst(0.14, d, "EjectPoint", "steam")
	v.hide_part(0.34, d, "Cell")
	# A fresh canister prints in from the left and seats, its fuse still dark.
	v.track("CellHolo", d, [[0.36, Vector3(-0.08, 0.0, 0.0), Vector3(0, 0, -30), 1.0, "hold"], [0.5, Vector3(-0.02, 0.0, 0.0), Vector3.ZERO],
		[0.54, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_CUBIC, Tween.EASE_OUT)
	v.holo_build("CellHolo", 0.36, 0.52, d)
	v.at(0.545, d, _fuse_dark.bind(v))
	v.solidify("CellHolo", "Cell", 0.55, d)
	v.glow_ramp(0.56, 0.6, d, 3.2, 0.3)
	# The support hand slides off, drops out of view for a match and comes back up with it.
	v.track("ArmL", d, [[0.06, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO], [0.18, Vector3(-0.12, -0.32, 0.04), Vector3(0, 0, -12)],
		[0.36, Vector3(-0.12, -0.32, 0.04), Vector3(0, 0, -12)], [0.5, Vector3(-0.11, -0.01, -0.07), Vector3(0, 0, 32)],
		[0.56, Vector3(-0.1, 0.01, -0.08), Vector3(12, 0, 44)], [0.6, Vector3(-0.11, -0.01, -0.07), Vector3(0, 0, 32)],
		[0.82, Vector3(-0.11, -0.01, -0.07), Vector3(0, 0, 32)], [0.87, Vector3(-0.12, -0.05, -0.05), Vector3(0, 0, 14)],
		[0.94, Vector3(-0.03, -0.012, -0.085), Vector3.ZERO], [1.0, Vector3.ZERO, Vector3.ZERO]])
	v.at(0.3, d, func(): _show(v, "MatchHolo", true); _show(v, "MatchFlame", false))
	# Flick: the match flares.
	v.at(0.57, d, _strike.bind(v))
	# A spark leaps from the flame to the nose of the fuse...
	for i in 4:
		v.at(0.62 + i * 0.025, d, _leap.bind(v, (i + 1) / 4.0))
	# ...and the fuse catches, racing from the nose back to the grip.
	for i in SEGMENTS:
		var seg := SEGMENTS - 1 - i
		v.at(0.72 + i * 0.014, d, _light.bind(v, seg))
	v.at(0.72, d, func(): Sfx.play(&"gn2_sparkler_fizz", -6.0))
	v.glow_ramp(0.72, 0.84, d, 0.3, 2.8)
	v.glow_ramp(0.84, 0.96, d, 2.8, 1.0)
	# Shake the match out, flick it away.
	v.at(0.84, d, _snuff.bind(v))
	v.track("MatchHolo", d, [[0.86, Vector3.ZERO, Vector3.ZERO, 1.0, "hold"], [0.94, Vector3(-0.12, 0.08, -0.04), Vector3(0, 0, 300), 0.9]],
		Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.hide_part(0.94, d, "MatchHolo")


func _show(v: WeaponView, part: String, on: bool) -> void:
	var p := v.part(part)
	if p:
		p.visible = on


func _fuse_dark(v: WeaponView) -> void:
	for i in SEGMENTS:
		_show(v, "FuseSeg%d" % i, false)


func _strike(v: WeaponView) -> void:
	_show(v, "MatchFlame", true)
	var tip := _point(v, "MatchTip")
	v.spark_burst(tip, Vector3(0, 1, 0), FLAME, 16, 1.2, 0.3, 0.008)
	Sfx.play(&"gn2_sparkler_match", -3.0)


## One step of the spark's leap from the match to the fuse (k 0-1 of the way).
func _leap(v: WeaponView, k: float) -> void:
	var a := _point(v, "MatchTip")
	var b := _point(v, "FuseFront")
	var at := a.lerp(b, k) + Vector3(0, sin(k * PI) * 0.04, 0)
	v.spark_burst(at, b - a, SPARKS, 5, 0.4, 0.2, 0.007)


func _light(v: WeaponView, seg: int) -> void:
	var p := v.part("FuseSeg%d" % seg)
	if p == null:
		return
	p.visible = true
	v.spark_burst(SparklerView.model_point(v, p), Vector3(-0.3, 1, 0), SPARKS, 4, 0.6, 0.22, 0.007)


func _snuff(v: WeaponView) -> void:
	_show(v, "MatchFlame", false)
	var tip := _point(v, "MatchTip")
	v.spark_burst(tip, Vector3(0, 1, 0), [Color(0.85, 0.85, 0.9), Color(0.6, 0.6, 0.7)], 6, 0.3, 0.5, 0.012)


func _point(v: WeaponView, node_name: String) -> Vector3:
	return SparklerView.model_point(v, v.model.find_child(node_name, true, false) as Node3D)
