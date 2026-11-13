class_name JungleBramble
extends Node3D
## A strip of thorny vines that bursts out of the ground along a straight line
## (left by an Overgrown's vine lash). The player moves at `slow` x speed while
## standing in it. Overlapping brambles do not stack. The thorns spring up,
## hold for `seconds`, then sink back into the ground.

const RISE := 0.14
const SINK := 0.5

@export var start := Vector3.ZERO
@export var direction := Vector3.FORWARD
@export var length := 8.0
@export var width := 1.7
@export var seconds := 3.5
@export var slow := 0.6

## Brambles currently holding the player, and the speeds they had before.
static var _holding := {}
static var _base_speeds := Vector2.ZERO
static var _thorn_mesh: CylinderMesh
static var _vine_mesh: BoxMesh

var _age := 0.0
var _thorns: MultiMeshInstance3D


func _ready() -> void:
	if _thorn_mesh == null:
		_thorn_mesh = CylinderMesh.new()
		_thorn_mesh.top_radius = 0.0
		_thorn_mesh.bottom_radius = 0.09
		_thorn_mesh.height = 0.7
		_thorn_mesh.radial_segments = 5
		_thorn_mesh.rings = 1
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 0.55, 0.22)
		m.roughness = 0.8
		m.emission_enabled = true
		m.emission = Color(0.25, 0.8, 0.3)
		m.emission_energy_multiplier = 0.4
		_thorn_mesh.material = m
		_vine_mesh = BoxMesh.new()
		_vine_mesh.size = Vector3(0.16, 0.16, 1.0)
		var vm := StandardMaterial3D.new()
		vm.albedo_color = Color(0.2, 0.36, 0.16)
		vm.roughness = 0.85
		_vine_mesh.material = vm
	global_position = start
	var basis := Basis.looking_at(direction, Vector3.UP)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := int(length * 3.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _thorn_mesh
	mm.instance_count = count
	for i in count:
		var along := (i + rng.randf()) / count * length
		var across := rng.randf_range(-0.5, 0.5) * width
		var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)) * Basis(Vector3.BACK, rng.randf_range(-0.5, 0.5))
		var s := rng.randf_range(0.6, 1.3)
		mm.set_instance_transform(i, Transform3D(tilt.scaled(Vector3(s, s, s)), Vector3(across, 0.3 * s, -along)))
	_thorns = MultiMeshInstance3D.new()
	_thorns.multimesh = mm
	_thorns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_thorns.basis = basis
	add_child(_thorns)
	for k in 2:
		var vine := MeshInstance3D.new()
		vine.mesh = _vine_mesh
		vine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vine.transform = Transform3D(Basis(basis.x, basis.y, basis.z * length), direction * length * 0.5 + basis.x * (k - 0.5) * width * 0.4 + Vector3.UP * 0.05)
		add_child(vine)
	_apply()
	for i in 6:
		var p := start + direction * length * (i + 0.5) / 6.0
		Fx.impact(get_parent(), p + Vector3.UP * 0.2, Vector3.UP, Color(0.4, 0.85, 0.3))


## True when `point` (feet) stands on the strip.
func covers(point: Vector3) -> bool:
	var rel := point - start
	if absf(rel.y) > 1.6:
		return false
	rel.y = 0.0
	var along := rel.dot(direction)
	var across := absf(rel.dot(Vector3(-direction.z, 0, direction.x)))
	return along >= -0.4 and along <= length + 0.4 and across <= width * 0.5 + 0.3


func _physics_process(delta: float) -> void:
	_age += delta
	_apply()
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		_hold(player, _age < seconds and covers(player.global_position))
	if _age >= seconds + SINK:
		queue_free()


## Thorns spring up, then sink at the end.
func _apply() -> void:
	var up := ease(minf(1.0, _age / RISE), 0.4)
	var down := clampf((seconds + SINK - _age) / SINK, 0.0, 1.0)
	_thorns.scale = Vector3(1.0, maxf(0.01, up * down), 1.0)


## Slows the player while at least one bramble holds them.
func _hold(player: Player, inside: bool) -> void:
	var key := get_instance_id()
	if inside == _holding.has(key):
		return
	if inside:
		if _holding.is_empty():
			_base_speeds = Vector2(player.walk_speed, player.sprint_speed)
			Sfx.play(&"jungle_snare", -4.0)
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
