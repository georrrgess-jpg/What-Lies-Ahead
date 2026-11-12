class_name FrostCloud
extends Node3D
## A swirling dome of freezing mist (left by a shattered Frozen Tourist). The
## player moves at `slow` x speed while inside it. Overlapping clouds do not
## stack. The dome swells in, hangs for `seconds`, then fades.

const SHADER := "res://art/shaders/frost_cloud.gdshader"
const FADE := 0.6

@export var radius := 3.2
@export var seconds := 4.5
@export var slow := 0.55

## Clouds currently holding the player, and the speeds they had before.
static var _holding := {}
static var _base_speeds := Vector2.ZERO

var _age := 0.0
var _material: ShaderMaterial
var _dome: MeshInstance3D
var _ring: MeshInstance3D

static var _dome_mesh: SphereMesh
static var _ring_mesh: TorusMesh
static var _ring_mat: StandardMaterial3D


func _ready() -> void:
	if _dome_mesh == null:
		_dome_mesh = SphereMesh.new()
		_dome_mesh.radius = 1.0
		_dome_mesh.height = 2.0
		_dome_mesh.radial_segments = 24
		_dome_mesh.rings = 10
		_dome_mesh.is_hemisphere = true
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.94
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 40
		_ring_mesh.ring_segments = 4
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER)
	_dome = MeshInstance3D.new()
	_dome.mesh = _dome_mesh
	_dome.material_override = _material
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dome)
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_mesh
	_ring.material_override = _ring_material()
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_apply(0.0)
	Sfx.play_at(&"frost_cloud_burst", global_position + Vector3.UP, 0.0, randf_range(0.95, 1.05))


## Bright additive edge ring on the ground (same material setup as the loadout beacon rings).
static func _ring_material() -> StandardMaterial3D:
	if _ring_mat == null:
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.albedo_color = Color(0.55, 0.9, 1.0)
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return _ring_mat


func _physics_process(delta: float) -> void:
	_age += delta
	var life := minf(1.0, _age / 0.25) * clampf((seconds - _age) / FADE, 0.0, 1.0)
	_apply(life)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		var to := player.global_position - global_position
		_hold(player, life > 0.2 and Vector2(to.x, to.z).length() <= radius and absf(to.y) < 2.5)
	if _age >= seconds:
		queue_free()


func _apply(life: float) -> void:
	var swell := lerpf(0.4, 1.0, ease(minf(1.0, _age / 0.35), -2.0))
	_dome.scale = Vector3(radius, radius * 0.62, radius) * swell
	_ring.scale = Vector3(radius, 1.0, radius) * swell
	_ring.position.y = 0.05
	_ring.transparency = 1.0 - life
	_material.set_shader_parameter("life", life)


## Slows the player while at least one cloud holds them.
func _hold(player: Player, inside: bool) -> void:
	var key := get_instance_id()
	if inside == _holding.has(key):
		return
	if inside:
		if _holding.is_empty():
			_base_speeds = Vector2(player.walk_speed, player.sprint_speed)
			Sfx.play(&"frost_chill", -4.0)
		_holding[key] = true
		player.walk_speed = _base_speeds.x * slow
		player.sprint_speed = _base_speeds.y * slow
	else:
		_holding.erase(key)
		if _holding.is_empty():
			player.walk_speed = _base_speeds.x
			player.sprint_speed = _base_speeds.y


func _exit_tree() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null
	if player and is_instance_valid(player):
		_hold(player, false)
	else:
		_holding.erase(get_instance_id())
