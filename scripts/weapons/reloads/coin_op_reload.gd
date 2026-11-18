extends RefCounted
## Coin-Op "coin return": the machine pistol rolls to show its coin tube and
## the support hand slaps the coin-return paddle under its nose; the flap kicks open and the
## last tokens rattle out of the tube and the cup in a spill of brass. A
## hologram roll of tokens prints in over the INSERT COIN slot, spinning
## down; it breaks open in the middle like a real roll over a counter's
## edge, the two wrapper halves tip away and fade, and a stack of hologram
## tokens drops into the slot. The tube fills token by token from the front,
## the star wheel spins the credit in, the slot lip flares and the cabinet
## settles. The slap, rattle, crack and ka-ching are in the reload sound
## (cop_reload), timed for WeaponData.reload_time.

const TOKENS := 15
const BRASS := [Color(1.0, 0.79, 0.24), Color(1.0, 0.93, 0.62), Color(0.85, 0.54, 0.11)]
const HOLO_SHADER := "res://art/shaders/holo.gdshader"
const FEED_TINT := Color(1.0, 0.86, 0.45)
## Model-space offset of the paddle pressed in by the slap.
const PRESS := Vector3(0.0, 0.004, 0.0)
const FADE_STEPS := 6
## When the tube fills: first token, gap between tokens (fractions of d).
const FILL_START := 0.62
const FILL_STEP := 0.013


func play(v: WeaponView, d: float) -> void:
	for part in ["ReturnButton", "ReturnFlap", "FeedHolo", "Wheel", "TiltGlow"]:
		v.register_part(part)
	for i in TOKENS:
		v.register_part("Token%d" % i)
	for i in 3:
		v.register_part("Credit%d" % i)
		_show(v, "Credit%d" % i, false)
	_show(v, "TiltGlow", false)
	var left := _tokens_left(v)
	for i in TOKENS:
		_show(v, "Token%d" % i, i < left)
	_cabinet(v, d)
	_slap(v, d, left)
	_roll(v, d)
	_fill(v, d)


## The whole pistol: rolls to show the tube and the deck, dips for the slap,
## lifts for the roll, then settles home with a small overshoot.
func _cabinet(v: WeaponView, d: float) -> void:
	v.track("Root", d, [[0.1, Vector3(-0.01, 0.025, 0.0), Vector3(10, -6, -22)], [0.2, Vector3(-0.012, 0.018, 0.0), Vector3(7, -6, -25)],
		[0.3, Vector3(-0.012, 0.03, 0.0), Vector3(12, -5, -20)], [0.56, Vector3(-0.015, 0.045, 0.01), Vector3(18, -4, -16)],
		[0.6, Vector3(-0.015, 0.036, 0.01), Vector3(14, -4, -17)], [0.82, Vector3(-0.012, 0.04, 0.0), Vector3(15, -4, -18)],
		[0.92, Vector3(0.0, -0.004, 0.0), Vector3(-3, 1, 3)], [1.0, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.05, 0.16, d, 1.0, 0.2)


## The support hand lets go, drops under the nose and slaps the coin-return
## paddle up; the paddle sinks, the flap kicks open and the spent tokens rattle out.
func _slap(v: WeaponView, d: float, left: int) -> void:
	v.track("ArmL", d, [[0.06, Vector3(-0.05, 0.0, 0.0), Vector3(0, 0, -4)], [0.11, Vector3(-0.05, -0.1, -0.01), Vector3(0, 0, -4)],
		[0.16, Vector3(0.0, -0.09, -0.15), Vector3(-3, 0, -2)], [0.2, Vector3(0.0, -0.035, -0.165), Vector3(-6, 0, 0)],
		[0.25, Vector3(0.0, -0.08, -0.15), Vector3(-3, 0, -2)], [0.31, Vector3(-0.05, -0.1, -0.01), Vector3(0, 0, -4)],
		[0.39, Vector3(-0.05, 0.0, 0.0), Vector3(0, 0, -3)], [0.46, Vector3.ZERO, Vector3.ZERO]])
	v.track("ReturnButton", d, [[0.185, Vector3.ZERO, Vector3.ZERO], [0.2, PRESS, Vector3.ZERO], [0.26, PRESS, Vector3.ZERO],
		[0.32, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.track("ReturnFlap", d, [[0.2, Vector3.ZERO, Vector3.ZERO], [0.23, Vector3.ZERO, Vector3(75, 0, 0)], [0.4, Vector3.ZERO, Vector3(75, 0, 0)],
		[0.46, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.at(0.2, d, func(): var p := v.owner as Player; if p: p.add_shake(0.05))
	# The tokens still in the tube slide to the front and drop out, front first.
	for i in left:
		var t0 := 0.205 + i * 0.006
		v.track("Token%d" % i, d, [[t0, Vector3.ZERO, Vector3.ZERO], [t0 + 0.035, Vector3(0.0, -0.012, -0.01), Vector3(25, 0, 0), 0.9],
			[t0 + 0.06, Vector3(0.006, -0.04, -0.02), Vector3(70, 0, 30), 0.6]], Tween.TRANS_QUAD, Tween.EASE_IN)
		v.hide_part(t0 + 0.06, d, "Token%d" % i)
	for t in [0.22, 0.27]:
		v.at(t, d, _spill.bind(v))


## The hologram roll prints in over the slot, breaks open and feeds it.
func _roll(v: WeaponView, d: float) -> void:
	for half in ["CellHolo", "CapsulesHolo"]:
		v.track(half, d, [[0.3, Vector3(0.0, 0.05, 0.02), Vector3(0, 70, -30), 0.7, "hold"], [0.5, Vector3.ZERO, Vector3.ZERO]],
			Tween.TRANS_CUBIC, Tween.EASE_OUT)
		v.holo_build(half, 0.3, 0.46, d)
	# The break: both halves tip down about the middle and part.
	v.track("CellHolo", d, [[0.53, Vector3(0.0, 0.002, 0.004), Vector3(14, 0, 0)], [0.6, Vector3(0.004, -0.004, 0.02), Vector3(38, 0, -8)],
		[0.7, Vector3(0.012, -0.012, 0.045), Vector3(55, 0, -16), 0.8]], Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.track("CapsulesHolo", d, [[0.53, Vector3(0.0, 0.002, -0.004), Vector3(-14, 0, 0)], [0.6, Vector3(-0.004, -0.004, -0.02), Vector3(-38, 0, 8)],
		[0.7, Vector3(-0.012, -0.012, -0.045), Vector3(-55, 0, 16), 0.8]], Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.at(0.53, d, _crack.bind(v))
	for i in FADE_STEPS:
		v.at(lerpf(0.6, 0.7, float(i + 1) / FADE_STEPS), d, _fade_halves.bind(v, 1.0 - float(i + 1) / FADE_STEPS))
	v.hide_part(0.71, d, "CellHolo")
	v.hide_part(0.71, d, "CapsulesHolo")
	# The stack of hologram tokens drops out of the break into the slot.
	v.at(0.54, d, _feed_on.bind(v))
	v.track("FeedHolo", d, [[0.54, Vector3(0.0, 0.045, 0.0), Vector3.ZERO, 0.9, "hold"], [0.6, Vector3(0.0, 0.03, 0.0), Vector3.ZERO, 1.0],
		[0.74, Vector3(0.0, -0.03, 0.0), Vector3.ZERO, 0.85]], Tween.TRANS_QUAD, Tween.EASE_IN)
	v.hide_part(0.74, d, "FeedHolo")


## The tube fills front to back, each token dropping in with a little
## settle; the star wheel spins the credit in and the slot lip flares.
func _fill(v: WeaponView, d: float) -> void:
	for i in TOKENS:
		var t := FILL_START + i * FILL_STEP
		v.at(t, d, _show.bind(v, "Token%d" % i, true))
		v.track("Token%d" % i, d, [[t, Vector3(0.0, 0.016, 0.006), Vector3(-20, 0, 0), 0.8, "hold"], [t + 0.045, Vector3.ZERO, Vector3.ZERO]],
			Tween.TRANS_BACK, Tween.EASE_OUT)
	v.track("Wheel", d, ReloadKeys.spin(0.66, 0.9, Vector3.RIGHT, -540.0, Vector3.ZERO, Vector3.ZERO, 1.0), Tween.TRANS_LINEAR)
	v.glow_ramp(0.62, 0.84, d, 0.2, 1.0)
	v.glow_ramp(0.84, 0.88, d, 1.0, 3.2)
	v.glow_ramp(0.88, 0.98, d, 3.2, 1.0)
	v.at(0.85, d, _ready.bind(v))


func _show(v: WeaponView, part: String, on: bool) -> void:
	var p := v.part(part)
	if p:
		p.visible = on


## Tokens in the tube when the reload starts (one per two rounds).
func _tokens_left(v: WeaponView) -> int:
	var p := v.player
	if p == null or p.weapons == null or p.weapons.current != v.data:
		return 0
	return clampi(ceili(float(p.weapons.magazine()) / maxf(1.0, v.data.magazine_size) * TOKENS), 0, TOKENS)


func _spill(v: WeaponView) -> void:
	var cup := v.model.find_child("VentPoint", true, false) as Node3D if v.model else null
	if cup:
		var at := v.model.global_transform.affine_inverse() * cup.global_position
		v.spark_burst(at, Vector3(-0.2, -0.4, -0.3), BRASS, 6, 0.7, 0.35, 0.007)


func _crack(v: WeaponView) -> void:
	var slot := v.model.find_child("EjectPoint", true, false) as Node3D if v.model else null
	if slot:
		var at := v.model.global_transform.affine_inverse() * slot.global_position + Vector3(0.0, 0.075, 0.0)
		v.spark_burst(at, Vector3(0, 0.6, 0), BRASS, 7, 0.6, 0.3, 0.006)
	var p := v.owner as Player
	if p:
		p.add_shake(0.03)


func _fade_halves(v: WeaponView, k: float) -> void:
	for half in ["CellHolo", "CapsulesHolo"]:
		var h := v.part(half) as MeshInstance3D
		if h and h.material_override is ShaderMaterial:
			(h.material_override as ShaderMaterial).set_shader_parameter("materialize", k)


func _feed_on(v: WeaponView) -> void:
	var f := v.part("FeedHolo") as MeshInstance3D
	if f == null:
		return
	var sm := ShaderMaterial.new()
	sm.shader = load(HOLO_SHADER)
	sm.set_shader_parameter("holo_color", FEED_TINT)
	sm.set_shader_parameter("span", maxf(0.02, f.mesh.get_aabb().size.y * 0.55))
	sm.set_shader_parameter("materialize", 1.0)
	f.material_override = sm
	f.visible = true


func _ready(v: WeaponView) -> void:
	for i in 3:
		_show(v, "Credit%d" % i, true)
	var slot := v.model.find_child("EjectPoint", true, false) as Node3D if v.model else null
	if slot:
		var at := v.model.global_transform.affine_inverse() * slot.global_position
		v.spark_burst(at, Vector3(0, 1, 0), BRASS, 5, 0.5, 0.25, 0.006)
	var p := v.owner as Player
	if p:
		p.add_shake(0.05)
