class_name FrostIceShellBehaviour
extends EnemyBehaviour
## Frozen Tourist: encased in ice that soaks up most of the damage until it
## shatters. Every hit chips the shell (it counts the full damage) while only
## a fraction reaches the tourist; headshots get more through. When the shell
## breaks the ice meshes vanish in a burst of shards. On death the tourist
## bursts into a frost cloud that slows the player (FrostCloud).

## Damage the shell absorbs before it shatters.
@export var shell_health := 70.0
## Fraction of each hit that gets through while the shell holds.
@export var body_damage_scale := 0.3
@export var head_damage_scale := 0.75
## Meshes whose names start with this are the shell (hidden when it breaks).
@export var shell_prefix := "Acc_Frozen_Ice"
@export var cloud_radius := 3.2
@export var cloud_seconds := 4.5
## Movement speed multiplier for the player inside the cloud.
@export var cloud_slow := 0.55

var _shell := 0.0
var _meshes: Array[Node] = []

static var _shard_mesh: Mesh


func on_ready(z: Zombie) -> void:
	_shell = shell_health
	_meshes = z.find_children(shell_prefix + "*", "MeshInstance3D", true, false)


func on_hit(z: Zombie, amount: float, hit_position: Vector3, headshot: bool) -> float:
	if _shell <= 0.0:
		return amount
	_shell -= amount
	_shards(z.get_parent(), hit_position, 6, 3.5)
	if _shell <= 0.0:
		_shatter(z, hit_position)
	else:
		Sfx.play_at(&"frost_ice_chip", hit_position, -4.0, randf_range(0.9, 1.15))
	return amount * (head_damage_scale if headshot else body_damage_scale)


func on_death(z: Zombie) -> void:
	if _shell > 0.0:
		_shatter(z, z.global_position + Vector3.UP)
	var cloud := FrostCloud.new()
	cloud.radius = cloud_radius
	cloud.seconds = cloud_seconds
	cloud.slow = cloud_slow
	z.get_parent().add_child(cloud)
	cloud.global_position = z.global_position


func _shatter(z: Zombie, at: Vector3) -> void:
	_shell = 0.0
	for mi in _meshes:
		if is_instance_valid(mi):
			(mi as Node3D).visible = false
	_shards(z.get_parent(), z.global_position + Vector3.UP * 1.1 * z.data.body_scale, 34, 6.0)
	_shards(z.get_parent(), at, 10, 4.0)
	Sfx.play_at(&"frost_ice_shatter", at, 2.0, randf_range(0.95, 1.05))


## Glassy ice chips flying off the shell.
static func _shards(parent: Node, at: Vector3, amount: int, speed: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	if _shard_mesh == null:
		var prism := PrismMesh.new()
		prism.size = Vector3.ONE
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		prism.material = m
		_shard_mesh = prism
	var burst := FxBurst.new()
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(burst)
	var colors := [Color(0.62, 0.92, 1.0), Color(0.9, 0.98, 1.0), Color(0.45, 0.78, 1.0)]
	burst.setup(at, Vector3.UP, colors, amount, speed, 0.65, 0.14, 160.0, Vector3(0, -12.0, 0), _shard_mesh)
