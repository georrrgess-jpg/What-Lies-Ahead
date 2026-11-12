class_name LightningBolt
extends MeshInstance3D
## A crackling electric arc between two points: a jagged, camera-facing
## ribbon that re-rolls its zig-zag a few times, with a forked branch, and
## fades out. Used by chain weapons and the shock status.

const REROLL := 0.035

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _color := Color.WHITE
var _width := 0.06
var _life := 0.16
var _age := 0.0
var _reroll := 0.0
var _jitter := 0.25
var _im: ImmediateMesh


## Spawns a bolt under `parent` (world-space points).
static func spawn(parent: Node, from: Vector3, to: Vector3, color: Color, width := 0.06, life := 0.16, jitter := 0.25) -> LightningBolt:
	if parent == null or not parent.is_inside_tree():
		return null
	var b := LightningBolt.new()
	b._from = from
	b._to = to
	b._color = color
	b._width = width
	b._life = life
	b._jitter = jitter
	parent.add_child(b)
	return b


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_im = ImmediateMesh.new()
	mesh = _im
	_rebuild()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	_reroll -= delta
	if _reroll <= 0.0:
		_rebuild()


func _rebuild() -> void:
	_reroll = REROLL
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else _from + Vector3.UP
	var fade := 1.0 - _age / _life
	var length := _from.distance_to(_to)
	var segments := clampi(int(length / 0.45) + 3, 4, 18)
	var main := _zigzag(_from, _to, segments, _jitter * clampf(length / 4.0, 0.35, 1.4))
	WeaponFx.begin_ribbons(_im, WeaponFx.ribbon_material())
	var glow := Color(_color, 0.55 * fade)
	WeaponFx.add_ribbon(_im, main, _width * 4.5, glow, eye)
	WeaponFx.add_ribbon(_im, main, _width, Color(_color.lerp(Color.WHITE, 0.6), fade), eye)
	# One fork that splits off part-way and fizzles out.
	if segments > 4:
		var k := randi_range(1, segments - 3)
		var start := main[k]
		var off := (_to - _from).normalized().cross(Vector3.UP).normalized() * randf_range(-1.0, 1.0) + Vector3.UP * randf_range(-0.4, 0.6)
		var end := start + (_to - _from).normalized() * length * 0.22 + off * length * 0.12
		var fork := _zigzag(start, end, 3, _jitter * 0.5)
		WeaponFx.add_ribbon(_im, fork, _width * 0.7, Color(_color.lerp(Color.WHITE, 0.4), 0.8 * fade), eye)
	WeaponFx.end_ribbons(_im)


func _zigzag(a: Vector3, b: Vector3, segments: int, amount: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var dir := b - a
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	for i in segments + 1:
		var t := float(i) / segments
		var p := a.lerp(b, t)
		if i > 0 and i < segments:
			var k := sin(t * PI)
			p += (side * randf_range(-1, 1) + up * randf_range(-1, 1)) * amount * k
		pts.append(p)
	return pts
