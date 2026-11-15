extends RefCounted
## Markdown Marker "end of the roll": the labeller tips over to show its
## drum; the empty roll pops out and its last curl of receipt flutters away as
## a hologram, fading; the cash drawer slides out of the grip with a ka-ching
## and a glint of coins; a fresh hologram tag roll spins down into the drum,
## solidifies, and the drawer snaps shut as the first tag slides into the
## nozzle. The ka-ching, spin and snap are in the reload sound (mdm_reload),
## timed for WeaponData.reload_time.

const PIPS := 3
const HOLO_SHADER := "res://art/shaders/holo.gdshader"
const RECEIPT_TINT := Color(1.0, 0.62, 0.84)
const COINS := [Color(1.0, 0.79, 0.24), Color(1.0, 0.95, 0.7), Color(1.0, 0.31, 0.64)]
## The drawer's slide (model space): out along the grip's front, a touch down.
const DRAWER_OUT := Vector3(0.0, -0.018, -0.066)
## Steps of the receipt's fade (the reload API has callbacks, not tweens).
const FADE_STEPS := 8


func play(v: WeaponView, d: float) -> void:
	for part in ["Tag", "Lever", "Drawer", "ReceiptHolo"]:
		v.register_part(part)
	for i in PIPS:
		v.register_part("Pip%d" % i)
		_show(v, "Pip%d" % i, false)
	_show(v, "Tag", false)
	# Lift and roll the labeller to show the drum, then tip it up for the drawer,
	# then back with a little settle.
	v.track("Root", d, [[0.12, Vector3(-0.01, 0.04, 0.0), Vector3(12, 10, 20)], [0.3, Vector3(-0.01, 0.045, 0.0), Vector3(14, 10, 22)],
		[0.38, Vector3(-0.02, 0.085, 0.0), Vector3(20, 14, 26)], [0.72, Vector3(-0.02, 0.085, 0.0), Vector3(18, 14, 24)],
		[0.84, Vector3(0.0, 0.006, 0.0), Vector3(-5, -2, -5)], [1.0, Vector3.ZERO, Vector3.ZERO]])
	v.glow_ramp(0.06, 0.16, d, 1.0, 0.25)
	# The empty roll pops up out of the drum...
	v.track("Cell", d, [[0.1, Vector3.ZERO, Vector3.ZERO], [0.18, Vector3(0.0, 0.05, 0.0), Vector3(-70, 0, 0)],
		[0.24, Vector3(0.015, 0.075, 0.01), Vector3(-150, 0, 10), 0.85]], Tween.TRANS_QUAD, Tween.EASE_OUT)
	v.hide_part(0.24, d, "Cell")
	# ...and its receipt curls off as a hologram, fluttering up and away as it fades.
	v.at(0.23, d, _receipt_on.bind(v))
	v.track("ReceiptHolo", d, [[0.23, Vector3(0.0, 0.07, 0.0), Vector3.ZERO, 1.2, "hold"], [0.32, Vector3(0.05, 0.12, 0.02), Vector3(10, 30, -35), 1.9],
		[0.4, Vector3(0.1, 0.16, 0.05), Vector3(-15, 70, 20), 1.8], [0.5, Vector3(0.18, 0.22, 0.09), Vector3(25, 110, -60), 1.1]])
	for i in FADE_STEPS:
		v.at(lerpf(0.36, 0.5, float(i + 1) / FADE_STEPS), d, _receipt_fade.bind(v, 1.0 - float(i + 1) / FADE_STEPS))
	v.hide_part(0.51, d, "ReceiptHolo")
	# The cash drawer slides out with a ka-ching.
	v.track("Drawer", d, [[0.3, Vector3.ZERO, Vector3.ZERO], [0.38, DRAWER_OUT, Vector3.ZERO], [0.7, DRAWER_OUT, Vector3.ZERO],
		[0.76, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_OUT)
	v.at(0.38, d, _coins.bind(v))
	# A fresh hologram roll spins down into the drum and solidifies.
	v.track("CellHolo", d, ReloadKeys.spin(0.42, 0.66, Vector3.RIGHT, -810.0, Vector3(0.0, 0.1, 0.0), Vector3.ZERO, 1.0), Tween.TRANS_LINEAR)
	v.holo_build("CellHolo", 0.42, 0.6, d)
	v.solidify("CellHolo", "Cell", 0.67, d)
	v.at(0.67, d, func(): var p := v.owner as Player; if p: p.add_shake(0.05))
	# The drawer snaps shut, the first tag slides out and the pips flash.
	v.at(0.76, d, _snap.bind(v))
	v.glow_ramp(0.76, 0.8, d, 0.25, 3.0)
	v.glow_ramp(0.8, 0.92, d, 3.0, 1.0)
	v.track("Lever", d, [[0.78, Vector3.ZERO, Vector3.ZERO], [0.82, Vector3.ZERO, Vector3(-16, 0, 0)], [0.88, Vector3.ZERO, Vector3.ZERO]])


func _show(v: WeaponView, part: String, on: bool) -> void:
	var p := v.part(part)
	if p:
		p.visible = on


func _receipt_on(v: WeaponView) -> void:
	var r := v.part("ReceiptHolo") as MeshInstance3D
	if r == null:
		return
	var sm := ShaderMaterial.new()
	sm.shader = load(HOLO_SHADER)
	sm.set_shader_parameter("holo_color", RECEIPT_TINT)
	sm.set_shader_parameter("span", maxf(0.02, r.mesh.get_aabb().size.y * 0.55))
	sm.set_shader_parameter("materialize", 1.0)
	r.material_override = sm
	r.visible = true


func _receipt_fade(v: WeaponView, k: float) -> void:
	var r := v.part("ReceiptHolo") as MeshInstance3D
	if r and r.material_override is ShaderMaterial:
		(r.material_override as ShaderMaterial).set_shader_parameter("materialize", k)


func _coins(v: WeaponView) -> void:
	var a := v.model.find_child("VentPoint", true, false) as Node3D if v.model else null
	if a:
		var at := v.model.global_transform.affine_inverse() * a.global_position
		v.spark_burst(at + DRAWER_OUT, Vector3(0, 1, -0.4), COINS, 10, 0.8, 0.4, 0.008)


func _snap(v: WeaponView) -> void:
	_show(v, "Tag", true)
	for i in PIPS:
		_show(v, "Pip%d" % i, true)
	var p := v.owner as Player
	if p:
		p.add_shake(0.06)
	var m := v.model.find_child("Muzzle", true, false) as Node3D if v.model else null
	if m:
		var at := v.model.global_transform.affine_inverse() * m.global_position
		v.spark_burst(at, Vector3(0, 0.4, -1), COINS, 6, 0.6, 0.25, 0.006)
