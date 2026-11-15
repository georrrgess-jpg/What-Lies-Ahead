extends RefCounted
## Ground Control "re-acquire signal": the gun tips up to show its dish and
## the signal bars on the flank drain and drop away. A hologram satellite
## prints in above the dish, drifts down turning slowly and docks into it
## with a lime flash; then a hologram signal-bar meter rises over the gun and
## fills from one bar to five, slides down onto the flank and turns solid,
## and the radar screen chimes back to life. The solar wing stays folded.

const WINGS := 3
const FOLD := 172.0
const HOLO_SHADER := "res://art/shaders/holo.gdshader"
const LIME := Color(0.66, 0.9, 0.24)
const SPARKS := [Color(0.66, 0.9, 0.24), Color(0.95, 1.0, 0.8), Color(1.0, 0.37, 0.64)]

var _sat_mat: ShaderMaterial


func play(v: WeaponView, d: float) -> void:
	for part in ["Dish", "Beacon", "SatHolo"]:
		v.register_part(part)
	for k in WINGS:
		var wing := "Wing%d" % (k + 1)
		v.register_part(wing)
		var fold := Vector3(0, 0, FOLD * (1.0 if k % 2 == 0 else -1.0))
		v.track(wing, d, [[0.0, Vector3.ZERO, fold, 1.0, "hold"], [1.0, Vector3.ZERO, fold, 1.0, "hold"]])
	# Tip the muzzle up and roll the left flank toward the eye, hold, settle.
	v.track("Root", d, [[0.1, Vector3(0.0, 0.02, 0.0), Vector3(16, 4, -10)], [0.5, Vector3(0.0, 0.025, 0.0), Vector3(18, 2, -12)],
		[0.62, Vector3(0.0, 0.015, 0.0), Vector3(6, -6, -22)], [0.86, Vector3(0.0, 0.015, 0.0), Vector3(6, -6, -22)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	# The signal bars drain and the meter drops off the flank.
	v.glow_ramp(0.04, 0.14, d, 1.0, 0.1)
	v.track("Cell", d, [[0.12, Vector3.ZERO, Vector3.ZERO], [0.26, Vector3(-0.05, -0.12, 0.03), Vector3(0, 0, 60), 0.8]],
		Tween.TRANS_QUAD, Tween.EASE_IN)
	v.burst(0.13, d, "EjectPoint", "sparks")
	v.at(0.12, d, func(): Sfx.play(&"reload_clunk", -7.0, 1.2))
	v.hide_part(0.26, d, "Cell")
	# The hologram satellite: prints in above the dish, drifts down turning and docks.
	_satellite(v, d)
	v.track("Dish", d, [[0.5, Vector3.ZERO, Vector3.ZERO], [0.53, Vector3(0, 0, 0.012), Vector3(-5, 0, 0)], [0.62, Vector3.ZERO, Vector3.ZERO]],
		Tween.TRANS_BACK, Tween.EASE_OUT)
	v.at(0.5, d, _docked.bind(v))
	# The hologram signal bars rise over the gun and fill, then slide home.
	v.track("CellHolo", d, [[0.54, Vector3(0.03, 0.1, 0.0), Vector3(0, 0, 0), 1.3, "hold"], [0.8, Vector3(0.03, 0.105, 0.0), Vector3.ZERO, 1.3],
		[0.9, Vector3.ZERO, Vector3.ZERO]], Tween.TRANS_BACK, Tween.EASE_IN)
	v.holo_build("CellHolo", 0.55, 0.8, d)
	for i in 5:
		v.at(0.58 + i * 0.045, d, func(): Sfx.play(&"gc_step", -9.0, 0.95 + 0.1 * i))
	v.solidify("CellHolo", "Cell", 0.9, d)
	v.at(0.93, d, func(): Sfx.play(&"gc_chime", -4.0))


## The satellite flies its own small tween (the hologram shader fades it in).
func _satellite(v: WeaponView, d: float) -> void:
	var sat := v.part("SatHolo") as MeshInstance3D
	if sat == null:
		return
	if _sat_mat == null:
		_sat_mat = ShaderMaterial.new()
		_sat_mat.shader = load(HOLO_SHADER)
		_sat_mat.set_shader_parameter("holo_color", LIME.lerp(Color.WHITE, 0.2))
		_sat_mat.set_shader_parameter("span", 0.05)
	sat.material_override = _sat_mat
	var high := Vector3(0.0, 0.14, -0.02)
	v.track("SatHolo", d, [[0.16, high, Vector3(0, -90, 20), 1.6, "hold"], [0.32, high * 0.6, Vector3(0, 0, 10), 1.4],
		[0.48, Vector3.ZERO, Vector3(0, 60, 0), 1.0]], Tween.TRANS_SINE, Tween.EASE_OUT)
	v.at(0.16, d, func():
		sat.visible = true
		var tw := sat.create_tween()
		tw.tween_method(func(k: float) -> void: _sat_mat.set_shader_parameter("materialize", k), 0.0, 1.0, 0.18 * d))
	v.at(0.18, d, func(): Sfx.play(&"gc_sat", -5.0))
	v.hide_part(0.52, d, "SatHolo")


func _docked(v: WeaponView) -> void:
	Sfx.play(&"gc_dock", -4.0)
	var muzzle := v.model.find_child("Muzzle", true, false) as Node3D if v.model else null
	if muzzle:
		v.spark_burst(v.model.global_transform.affine_inverse() * muzzle.global_position, Vector3(0, 0.4, -1), SPARKS, 14, 1.0, 0.35, 0.009)
