class_name SlimePuddle
extends Node3D
## A splat of toxic slime on the floor (the Toxic Ripsaw's shotgun leaves one
## under the zombie it hit hardest). It splats in, wobbles and dries up after
## LIFE seconds; zombies standing in it move at SLOW of their speed (heavier
## ones shrug part of it off, by EnemyData.mass). At most MAX_LIVE puddles
## exist at once: a new one dries up the oldest.

const LIFE := 3.0
const RADIUS := 1.3
const SLOW := 0.6
const MAX_LIVE := 3
## Seconds between checks for who is standing in it.
const SCAN := 0.1
const BLOBS := 5

static var _live: Array[SlimePuddle] = []
static var _disc_mesh: CylinderMesh
static var _blob_mesh: SphereMesh
static var _mats := {}

var _age := 0.0
var _scan := 0.0
var _inside: Array[Zombie] = []


## Drops a puddle on the floor under `at` (nothing if there is no floor close below).
static func spawn(parent: Node, at: Vector3, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var space := (parent as Node3D).get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 2.0, WeaponController.MASK_WORLD))
	if hit.is_empty():
		return
	if _live.size() >= MAX_LIVE:
		_live.pop_front().queue_free()
	var puddle := SlimePuddle.new()
	parent.add_child(puddle)
	puddle.global_position = Vector3(hit["position"]) + Vector3.UP * 0.02
	puddle._build(color)
	_live.append(puddle)


func _build(color: Color) -> void:
	if _disc_mesh == null:
		_disc_mesh = CylinderMesh.new()
		_disc_mesh.top_radius = 1.0
		_disc_mesh.bottom_radius = 1.0
		_disc_mesh.height = 0.02
		_disc_mesh.radial_segments = 20
		_disc_mesh.rings = 1
		_blob_mesh = SphereMesh.new()
		_blob_mesh.radius = 1.0
		_blob_mesh.height = 2.0
		_blob_mesh.radial_segments = 10
		_blob_mesh.rings = 5
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color.lerp(Color(0.3, 0.75, 0.1), 0.35), 0.88)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.45
		m.roughness = 0.15
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	var disc := MeshInstance3D.new()
	disc.mesh = _disc_mesh
	disc.material_override = _mats[key]
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.scale = Vector3(RADIUS * 0.9, 1.0, RADIUS * 0.8)
	disc.rotation.y = randf() * TAU
	add_child(disc)
	for i in BLOBS:
		var blob := MeshInstance3D.new()
		blob.mesh = _blob_mesh
		blob.material_override = _mats[key]
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / BLOBS + randf() * 0.6
		var r := randf_range(0.25, 0.75) * RADIUS
		var size := randf_range(0.18, 0.32)
		blob.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		blob.scale = Vector3(size, size * 0.18, size)
		add_child(blob)
	scale = Vector3(0.2, 1.0, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.12, 1.0, 1.12), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_SINE)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = SCAN
		_find_inside()
	for z in _inside:
		if is_instance_valid(z) and not z.is_dead():
			z.speed_multiplier *= lerpf(1.0, SLOW, 1.0 / sqrt(maxf(1.0, z.data.mass)))
	# Dries up over the last half second.
	var dry := clampf((LIFE - _age) / 0.5, 0.0, 1.0)
	if dry < 1.0:
		scale = Vector3(dry, 1.0, dry)


func _find_inside() -> void:
	_inside.clear()
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var d := z.global_position - global_position
		if absf(d.y) < 1.0 and Vector2(d.x, d.z).length() < RADIUS * scale.x + z.data.capsule_radius * 0.5:
			_inside.append(z)


func _exit_tree() -> void:
	_live.erase(self)
