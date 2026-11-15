class_name GroundControlMark
extends Node3D
## Ground Control's radar mark on one zombie, added as a child the first time
## a ping ring passes through it (GroundControlMark.of(zombie)). A marked
## zombie wears a lime outline drawn through walls (an additive rim overlay)
## and a radar blip over its head, and takes DAMAGE_BONUS more from every
## hit, whatever weapon it comes from (an EnemyBehaviour on_hit filter, last
## in line, like the Dunk Tank's soak). The mark lasts MARK_TIME after the
## last ring. tools/balance_report.py reads these constants.

const NODE_NAME := "GroundControlMark"
const MARK_TIME := 4.0
## Damage multiplier of every hit a marked zombie takes.
const DAMAGE_BONUS := 1.15
## The last FADE_TIME seconds the outline fades out.
const FADE_TIME := 0.8
## The overlay is laid again this often (a hit flash takes the slot for a moment).
const REAPPLY := 0.1
const SHADER := "res://art/shaders/ground_control_mark.gdshader"
const BLIP_COLOR := Color(0.66, 0.9, 0.24)

var zombie: Zombie
var _left := 0.0
var _reapply := 0.0
var _bonus: Marked
var _meshes: Array[MeshInstance3D] = []
var _overlay: ShaderMaterial
var _blip: MeshInstance3D

static var _blip_mesh: QuadMesh
static var _blip_mat: StandardMaterial3D


## The extra damage a marked zombie takes.
class Marked extends EnemyBehaviour:
	func on_hit(_z: Zombie, amount: float, _hit_position: Vector3, _headshot: bool) -> float:
		return amount * DAMAGE_BONUS


## The mark on `z`, created on first use.
static func of(z: Zombie) -> GroundControlMark:
	var existing := z.get_node_or_null(NODE_NAME) as GroundControlMark
	if existing:
		return existing
	var m := GroundControlMark.new()
	m.name = NODE_NAME
	m.zombie = z
	z.add_child(m)
	return m


## True while `z` carries a mark.
static func is_marked(z: Zombie) -> bool:
	var m := z.get_node_or_null(NODE_NAME) as GroundControlMark
	return m != null and m.is_on()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for mi in zombie.model_root.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			_meshes.append(mi)
	_overlay = ShaderMaterial.new()
	_overlay.shader = load(SHADER)
	_blip = MeshInstance3D.new()
	_blip.mesh = _blip_quad()
	_blip.material_override = _blip_material()
	_blip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blip.position = Vector3.UP * (zombie.data.capsule_height + 0.35) * zombie.data.body_scale
	_blip.visible = false
	add_child(_blip)
	zombie.died.connect(func(_z: Zombie, _w: StringName) -> void: _clear())
	set_physics_process(false)


func is_on() -> bool:
	return _left > 0.0


## A ring passed through: marked (again) for MARK_TIME.
func mark() -> void:
	if zombie.is_dead():
		return
	if not is_on():
		_bonus = Marked.new()
		zombie.behaviours.append(_bonus)
		_blip.visible = true
		_reapply = 0.0
		set_physics_process(true)
	_left = MARK_TIME
	_blip.scale = Vector3.ONE * 1.6


func _physics_process(delta: float) -> void:
	if zombie == null or zombie.is_dead():
		_clear()
		return
	_left -= delta
	if _left <= 0.0:
		_clear()
		return
	var fade := clampf(_left / FADE_TIME, 0.0, 1.0)
	_overlay.set_shader_parameter("strength", fade)
	_blip.scale = _blip.scale.lerp(Vector3.ONE * lerpf(0.6, 1.0, fade), 1.0 - exp(-10.0 * delta))
	_reapply -= delta
	if _reapply <= 0.0:
		_reapply = REAPPLY
		_set_overlay(true)


func _clear() -> void:
	_left = 0.0
	set_physics_process(false)
	_set_overlay(false)
	if _blip:
		_blip.visible = false
	if _bonus and is_instance_valid(zombie):
		zombie.behaviours.erase(_bonus)
	_bonus = null


## Lays the outline on every mesh whose overlay slot is free (or free again
## after a hit flash); another status's own overlay is left alone.
func _set_overlay(on: bool) -> void:
	for m in _meshes:
		if not is_instance_valid(m):
			continue
		if on and m.material_overlay == null:
			m.material_overlay = _overlay
		elif not on and m.material_overlay == _overlay:
			m.material_overlay = null


## A lime diamond over the head, drawn through walls, facing the camera.
static func _blip_quad() -> QuadMesh:
	if _blip_mesh == null:
		_blip_mesh = QuadMesh.new()
		_blip_mesh.size = Vector2(0.035, 0.035)
	return _blip_mesh


static func _blip_material() -> StandardMaterial3D:
	if _blip_mat == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.no_depth_test = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.fixed_size = true
		m.albedo_texture = _diamond_texture()
		m.albedo_color = BLIP_COLOR
		m.render_priority = 4
		_blip_mat = m
	return _blip_mat


## A ring-in-a-diamond blip, drawn once.
static func _diamond_texture() -> ImageTexture:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2(x + 0.5, y + 0.5) / size * 2.0 - Vector2.ONE
			var d := absf(p.x) + absf(p.y)
			var edge := clampf(1.0 - absf(d - 0.78) * 9.0, 0.0, 1.0)
			var core := clampf(1.0 - p.length() * 3.2, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, maxf(edge, core)))
	return ImageTexture.create_from_image(img)
