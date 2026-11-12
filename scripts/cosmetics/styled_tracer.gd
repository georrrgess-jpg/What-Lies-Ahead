class_name StyledTracer
extends MeshInstance3D
## One styled tracer (TracerStyles): a mesh built in world space along the
## shot that shoots out from the muzzle over `reveal` seconds, then fades.
## Lightning flickers while it fades.

var _from := Vector3.ZERO
var _dir := Vector3.FORWARD
var _life := 0.15
var _reveal := 0.0
var _flicker := false
var _age := 0.0


func launch(from: Vector3, to: Vector3, life: float, reveal: float, flicker: bool) -> void:
	_from = from
	_dir = (to - from).normalized()
	_life = life
	_reveal = reveal
	_flicker = flicker
	_update()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_update()


func _update() -> void:
	# Stretch along the shot about the muzzle: k = 0 collapsed, 1 full length.
	var k := clampf(_age / _reveal, 0.02, 1.0) if _reveal > 0.0 else 1.0
	var d := _dir
	var b := Basis(Vector3.RIGHT + d * (k - 1.0) * d.x, Vector3.UP + d * (k - 1.0) * d.y, Vector3.BACK + d * (k - 1.0) * d.z)
	global_transform = Transform3D(b, _from - b * _from)
	var fade := clampf((_age - _reveal) / maxf(0.01, _life - _reveal), 0.0, 1.0)
	transparency = fade * fade
	if _flicker:
		visible = randf() > 0.2
		transparency = clampf(fade + randf() * 0.3, 0.0, 1.0)
