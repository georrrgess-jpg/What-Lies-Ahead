class_name LavaEruption
extends Node
## Lava Lagoon's twist. On the wave whose twist is "eruption" Mount Kahuna
## blows: the sky and the crater flare red and ember bombs rain on the resort.
## Every bomb is announced where it will land: a glowing ring grows on the
## ground with a rising whistle, and the bomb drops in for the last moment of
## it. Standing in the ring when it lands costs `damage`. Rings fall near the
## player but never stack up on them, never on the lava and never at the
## entrances. Listens to the run director, so it stays calm behind the menu.

const TWIST := &"eruption"

## Seconds between bombs (a random pick in this range).
@export var interval := Vector2(2.3, 3.4)
## Seconds from the ring appearing to the impact.
@export var telegraph := 1.7
## Seconds of the bomb's fall (the end of the telegraph).
@export var fall_time := 0.6
@export var radius := 2.0
@export var damage := 7.0
## Share of the bombs aimed close to the player (the rest land around them).
@export_range(0.0, 1.0) var near_share := 0.4
## Seconds for the sky to flare up or calm down.
@export var transition := 3.0

var _director: RunDirector
var _active := false
var _level := 0.0
var _cool := 2.0
var _strikes: Array[Dictionary] = []
var _sky: ShaderMaterial
var _plumes: Array[ShaderMaterial] = []
var _crater: OmniLight3D
var _crater_energy := 0.0
var _rng := RandomNumberGenerator.new()

static var _ring_mesh: TorusMesh
static var _disc_mesh: CylinderMesh
static var _bomb_mesh: SphereMesh


func _ready() -> void:
	# Work on copies: the scene's resources are shared with the next Retry.
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment and we.environment.sky:
		we.environment = we.environment.duplicate()
		we.environment.sky = we.environment.sky.duplicate()
		_sky = we.environment.sky.sky_material.duplicate() as ShaderMaterial
		we.environment.sky.sky_material = _sky
	for node in get_tree().get_nodes_in_group("lava_plume"):
		var mi := node as MeshInstance3D
		var m := (mi.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		mi.material_override = m
		_plumes.append(m)
	_crater = get_tree().get_first_node_in_group("lava_crater_light") as OmniLight3D
	if _crater:
		_crater_energy = _crater.light_energy
	_make_meshes()


func _process(delta: float) -> void:
	if _director == null:
		_director = get_tree().get_first_node_in_group("run_director") as RunDirector
		if _director:
			_director.wave_started.connect(_on_wave_started)
			_director.wave_cleared.connect(func(_n: int, _t: int): _active = false)
			_director.state_changed.connect(_on_state_changed)
	var target := 1.0 if _active else 0.0
	if _level != target:
		_level = move_toward(_level, target, delta / transition)
		_apply(ease(_level, -1.6))
	if _active and _level > 0.5:
		_cool -= delta
		if _cool <= 0.0:
			_cool = _rng.randf_range(interval.x, interval.y)
			_launch()
	_tick(delta)


func _on_wave_started(_number: int, _total: int, _banner: String) -> void:
	var wave := _director.current_wave()
	_active = wave != null and wave.twist == TWIST
	_cool = 2.5
	if _active:
		Sfx.play(&"lava_eruption_rumble")


func _on_state_changed(state: RunDirector.State) -> void:
	if state != RunDirector.State.WAVE:
		_active = false


func _apply(k: float) -> void:
	if _sky:
		_sky.set_shader_parameter("eruption", k)
	for m in _plumes:
		m.set_shader_parameter("under_glow", 1.0 + 1.6 * k)
		m.set_shader_parameter("speed", 0.05 + 0.08 * k)
	if _crater:
		_crater.light_energy = _crater_energy * (1.0 + 2.5 * k)


## Picks a landing spot near the player and starts its ring.
func _launch() -> void:
	var player := _director.player if _director else null
	if player == null or not player.alive:
		return
	for attempt in 6:
		var near := _rng.randf() < near_share
		var dist := _rng.randf_range(0.0, 2.5) if near else _rng.randf_range(3.0, 9.0)
		var a := _rng.randf_range(0.0, TAU)
		var guess := player.global_position + player.velocity * Vector3(1, 0, 1) * 0.6 + Vector3(cos(a), 0, sin(a)) * dist
		var spot: Variant = _ground(guess)
		if spot != null and _clear(spot):
			_start(spot)
			return


## The floor under a point (null over the lava, off the shelf or under a roof).
func _ground(p: Vector3) -> Variant:
	var parent := get_parent() as Node3D
	if parent == null:
		return null
	var space := parent.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 14.0, p + Vector3.DOWN * 6.0, 1)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return null
	var at: Vector3 = hit.position
	if at.y < -0.3 or (hit.normal as Vector3).y < 0.8:
		return null
	return at


func _clear(spot: Vector3) -> bool:
	for s in _strikes:
		if (s.at as Vector3).distance_to(spot) < radius * 1.8:
			return false
	for e in get_tree().get_nodes_in_group("enemy_spawn"):
		if (e as Node3D).global_position.distance_to(spot) < 6.0:
			return false
	return true


func _start(at: Vector3) -> void:
	var parent := get_parent() as Node3D
	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.global_position = at + Vector3.UP * 0.06
	var disc := MeshInstance3D.new()
	disc.mesh = _disc_mesh
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(disc)
	disc.global_position = at + Vector3.UP * 0.04
	var bomb := MeshInstance3D.new()
	bomb.mesh = _bomb_mesh
	bomb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bomb.visible = false
	parent.add_child(bomb)
	_strikes.append({"at": at, "left": telegraph, "ring": ring, "disc": disc, "bomb": bomb})
	Sfx.play_at(&"lava_bomb_whistle", at + Vector3.UP * 3.0, 0.0, _rng.randf_range(0.95, 1.08))


func _tick(delta: float) -> void:
	for i in range(_strikes.size() - 1, -1, -1):
		var s: Dictionary = _strikes[i]
		s.left -= delta
		var k := clampf(1.0 - s.left / telegraph, 0.0, 1.0)
		var r := lerpf(0.4, radius, minf(k * 1.6, 1.0))
		(s.ring as MeshInstance3D).scale = Vector3(r, 1.0, r)
		(s.disc as MeshInstance3D).scale = Vector3(radius * k, 1.0, radius * k)
		var bomb := s.bomb as MeshInstance3D
		if s.left <= fall_time:
			bomb.visible = true
			bomb.global_position = (s.at as Vector3) + Vector3.UP * (0.3 + 26.0 * maxf(s.left, 0.0) / fall_time)
		if s.left <= 0.0:
			_impact(s.at)
			(s.ring as Node).queue_free()
			(s.disc as Node).queue_free()
			bomb.queue_free()
			_strikes.remove_at(i)


func _impact(at: Vector3) -> void:
	var parent := get_parent()
	Fx.impact(parent, at + Vector3.UP * 0.3, Vector3.UP, Color(1.0, 0.5, 0.15))
	Fx.impact(parent, at + Vector3.UP * 0.3, Vector3.UP, Color(1.0, 0.85, 0.35))
	Sfx.play_at(&"lava_bomb_impact", at + Vector3.UP, 0.0, _rng.randf_range(0.9, 1.1))
	var player := _director.player if _director else null
	if player and player.alive:
		var d := player.global_position - at
		if Vector2(d.x, d.z).length() <= radius and absf(d.y) < 2.5:
			player.take_damage(damage, at)


func _make_meshes() -> void:
	if _ring_mesh:
		return
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0, 0.45, 0.12)
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.88
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 40
	_ring_mesh.ring_segments = 4
	_ring_mesh.material = hot
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, 0.3, 0.08, 0.45)
	_disc_mesh = CylinderMesh.new()
	_disc_mesh.top_radius = 1.0
	_disc_mesh.bottom_radius = 1.0
	_disc_mesh.height = 0.02
	_disc_mesh.radial_segments = 32
	_disc_mesh.material = glow
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.2, 0.08, 0.06)
	rock.emission_enabled = true
	rock.emission = Color(1.0, 0.45, 0.12)
	rock.emission_energy_multiplier = 3.0
	_bomb_mesh = SphereMesh.new()
	_bomb_mesh.radius = 0.45
	_bomb_mesh.height = 0.9
	_bomb_mesh.radial_segments = 10
	_bomb_mesh.rings = 5
	_bomb_mesh.material = rock
