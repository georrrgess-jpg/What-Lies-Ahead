class_name BossZone
extends Node3D
## One telegraphed ground strike of an alpha's signature move (placed by
## BossStrikeZones, BossCharge trails and BossBurrow). It always reads the same
## way: a ring and a disc grow on the floor for `telegraph` seconds, brighter
## and faster as the hit nears, with a warning sound; then the strike lands
## (something bursts up out of the floor or drops onto it) and anyone standing
## inside is hit. Optionally it leaves a patch behind (fire, ink, ice: damage
## per second and/or a slow while standing in it) or a solid column the player
## can hide behind (BossBeam sweeps are blocked by it) and cannot walk through.
##
## Live zones are listed in `live` so the bot can step out of a marked circle
## the way a player would, and so beams can check for cover.

enum Style { BURST, DROP }
enum Prop { NONE, COLUMN, SPIKES, BOX, SPHERE }

## Seconds the dropped prop takes to fall (the end of the telegraph).
const FALL_TIME := 0.45
## Seconds the burst prop takes to shoot up, and to sink back.
const RISE_TIME := 0.12
const SINK_TIME := 0.5
## Collision layer of a pillar: player_walls (the player bumps into it,
## zombies and bullets pass through, so it never breaks the horde's routes).
const PILLAR_LAYER := 16
## Damage ticks per second inside a lingering patch.
const TICK := 0.5

## Zones on the floor right now (telegraphing, lingering or standing).
static var live: Array[BossZone] = []

static var _ring_mesh: TorusMesh
static var _disc_mesh: CylinderMesh
static var _meshes := {}

var radius := 2.0
var telegraph := 1.2
var damage := 10.0
var color := Color(1, 0.5, 0.2)
var style := Style.BURST
var prop := Prop.COLUMN
var prop_color := Color(1, 0.6, 0.3)
## Height of the prop (a column, the fall height scale of a dropped box...).
var prop_height := 3.0
## True: the strike also hits a player in the air (a falling stall); false: a
## jump clears it (a floor burst).
var hits_airborne := false
## Seconds a patch stays after the hit (0 = none) and what it does.
var linger := 0.0
var linger_dps := 0.0
var linger_slow := 1.0
## Seconds a solid column stands after the hit (0 = none).
var pillar_seconds := 0.0
var warn_sound: StringName = &"rounds_boss_zone_warn"
var hit_sound: StringName = &"rounds_boss_zone_hit"
## The alpha that placed it (damage is booked to its position).
var source: Node3D

var _age := 0.0
var _struck := false
var _tick := 0.0
var _ring: MeshInstance3D
var _disc: MeshInstance3D
var _prop: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _disc_mat: StandardMaterial3D
var _body: StaticBody3D
var _slowing := false

## Speeds the player had before the first patch slowed them.
static var _slowed := {}
static var _base_speeds := Vector2.ZERO


func _ready() -> void:
	live.append(self)
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.9
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 32
		_ring_mesh.ring_segments = 4
		_disc_mesh = CylinderMesh.new()
		_disc_mesh.top_radius = 1.0
		_disc_mesh.bottom_radius = 1.0
		_disc_mesh.height = 0.02
		_disc_mesh.radial_segments = 28
		_disc_mesh.rings = 1
	_ring_mat = _glow(color, 0.9)
	_disc_mat = _glow(color, 0.15)
	_ring = _mesh(_ring_mesh, _ring_mat)
	_ring.position.y = 0.07
	_disc = _mesh(_disc_mesh, _disc_mat)
	_disc.position.y = 0.05
	if prop != Prop.NONE:
		var m := StandardMaterial3D.new()
		m.albedo_color = prop_color
		m.roughness = 0.6
		m.emission_enabled = true
		m.emission = prop_color
		m.emission_energy_multiplier = 0.6
		_prop = _mesh(_prop_mesh(prop), m)
		_prop.visible = false
		_prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var size := _prop_size()
		_prop.scale = Vector3(size.x, size.y, size.x)
	_apply(0.0)
	Sfx.play_at(warn_sound, global_position + Vector3.UP * 0.5, -4.0, randf_range(0.95, 1.08), 10.0)


func _exit_tree() -> void:
	live.erase(self)
	_set_slow(false)


## True while the marker is still a warning (the strike has not landed).
func is_threat() -> bool:
	return not _struck


## True while the zone hurts or blocks: a warning, a patch, or a column.
func is_dangerous() -> bool:
	return not _struck or (_age < telegraph + linger and linger_dps > 0.0)


## True when `point` (feet) stands inside the circle.
func covers(point: Vector3, margin := 0.0) -> bool:
	var rel := point - global_position
	if rel.y < -1.5 or rel.y > 2.5:
		return false
	rel.y = 0.0
	return rel.length() <= radius + margin


## True while a standing column blocks the line from `from` to `to`.
func blocks(from: Vector3, to: Vector3) -> bool:
	if _body == null:
		return false
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var c := Vector2(global_position.x, global_position.z)
	var closest := Geometry2D.get_closest_point_to_segment(c, a, b)
	return closest.distance_to(c) <= radius * 0.85


func _physics_process(delta: float) -> void:
	_age += delta
	if not _struck:
		var k := clampf(_age / telegraph, 0.0, 1.0)
		_apply(k)
		if style == Style.DROP and is_instance_valid(_prop):
			var fall := clampf((_age - (telegraph - FALL_TIME)) / FALL_TIME, 0.0, 1.0)
			_prop.visible = fall > 0.0
			_prop.position.y = lerpf(prop_height * 4.0 + 8.0, _prop_size().y * 0.5, fall * fall)
		if _age >= telegraph:
			_strike()
		return
	var after := _age - telegraph
	_tick_prop(after)
	if linger > 0.0 and after < linger:
		_tick_patch(delta, after)
	elif _slowing:
		_set_slow(false)
	if _body and after >= pillar_seconds:
		_body.queue_free()
		_body = null
	if after >= maxf(linger, pillar_seconds) + SINK_TIME:
		queue_free()


func _strike() -> void:
	_struck = true
	_ring.visible = false
	_disc_mat.albedo_color = Color(color, 0.35 if linger > 0.0 else 0.0)
	_disc.visible = linger > 0.0
	if is_instance_valid(_prop):
		_prop.visible = true
	Sfx.play_at(hit_sound, global_position + Vector3.UP, 2.0, randf_range(0.92, 1.08), 14.0)
	for i in 5 if damage > 0.0 else 0:
		var a := TAU * i / 5.0
		Fx.impact(get_parent(), global_position + Vector3(cos(a), 0.2, sin(a)) * radius * 0.6, Vector3.UP, color)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.alive and covers(player.global_position) and (hits_airborne or player.is_on_floor()):
		player.take_damage(damage, _source_position())
	if pillar_seconds > 0.0:
		_raise_pillar(player)


## A burst prop shoots up and sinks; a dropped one settles and sinks; a
## pillar stands for its seconds first.
func _tick_prop(after: float) -> void:
	if not is_instance_valid(_prop):
		return
	var hold := maxf(pillar_seconds, 0.35 if style == Style.BURST else 0.9)
	var down := clampf((hold + SINK_TIME - after) / SINK_TIME, 0.0, 1.0)
	var size := _prop_size()
	if style == Style.BURST:
		var up := ease(clampf(after / RISE_TIME, 0.0, 1.0), 0.4)
		_prop.scale = Vector3(size.x, maxf(0.01, size.y * up), size.x)
		_prop.position.y = size.y * (up * 0.5 - (1.0 - down))
	else:
		_prop.position.y = size.y * (0.5 - (1.0 - down))


func _tick_patch(delta: float, after: float) -> void:
	_disc_mat.albedo_color = Color(color, 0.3 + 0.08 * sin(after * 6.0))
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var inside := player.alive and covers(player.global_position, -0.2)
	if linger_slow < 1.0:
		_set_slow(inside)
	if linger_dps <= 0.0 or not inside:
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		player.take_damage(linger_dps * TICK, _source_position())


## A solid column the player bumps into and hides behind. It never rises on
## top of the player: if they stand in it, it stays a floor burst.
func _raise_pillar(player: Player) -> void:
	if player and covers(player.global_position, 0.6):
		pillar_seconds = 0.0
		return
	_body = StaticBody3D.new()
	_body.collision_layer = PILLAR_LAYER
	_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius * 0.55
	cyl.height = prop_height
	shape.shape = cyl
	shape.position.y = prop_height * 0.5
	_body.add_child(shape)
	add_child(_body)


func _apply(k: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_age * lerpf(8.0, 26.0, k))
	_ring.scale = Vector3(radius, 1.0 + 2.0 * k, radius)
	_disc.scale = Vector3(radius * maxf(0.05, k), 1.0, radius * maxf(0.05, k))
	_ring_mat.albedo_color = Color(color.lightened(0.25 * pulse), 0.55 + 0.45 * k)
	_disc_mat.albedo_color = Color(color, 0.12 + 0.3 * k)


func _set_slow(on: bool) -> void:
	if on == _slowing:
		return
	var player := get_tree().get_first_node_in_group("player") as Player if is_inside_tree() else null
	_slowing = on
	var key := get_instance_id()
	if on:
		if _slowed.is_empty() and player:
			_base_speeds = Vector2(player.walk_speed, player.sprint_speed)
		_slowed[key] = true
	else:
		_slowed.erase(key)
	if player == null or not is_instance_valid(player):
		return
	var k := linger_slow if not _slowed.is_empty() else 1.0
	player.walk_speed = _base_speeds.x * k
	player.sprint_speed = _base_speeds.y * k


func _source_position() -> Vector3:
	return source.global_position if is_instance_valid(source) else global_position


## Width and height of the prop (its meshes are unit-sized and scaled).
func _prop_size() -> Vector2:
	match prop:
		Prop.BOX:
			return Vector2(radius * 1.1, prop_height)
		Prop.SPHERE:
			return Vector2(radius * 1.1, radius * 1.1)
	return Vector2(radius * 0.55, prop_height)


func _mesh(mesh: Mesh, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func _prop_mesh(kind: Prop) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var mesh: Mesh
	match kind:
		Prop.BOX:
			mesh = BoxMesh.new()
		Prop.SPHERE:
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 14
			s.rings = 7
			mesh = s
		_:
			var c := CylinderMesh.new()
			c.top_radius = 0.7 if kind == Prop.COLUMN else 0.0
			c.bottom_radius = 1.0
			c.height = 1.0
			c.radial_segments = 10
			c.rings = 1
			mesh = c
	_meshes[kind] = mesh
	return mesh


static func _glow(tint: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(tint, alpha)
	return m
