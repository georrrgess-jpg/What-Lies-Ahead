class_name FaireCatapultVolley
extends Node
## The Royal Faire's twist. On the wave whose twist is "catapult" the faire's
## siege engines beyond the walls open up and lob boulders onto the field.
## Every boulder is announced where it will land: a gold ring grows on the
## ground with a creak and a rising whistle, and the boulder arcs in from the
## castle for the last moment of it. Standing in the ring when it lands costs
## `damage`. Rings fall near the player but never stack up on them, never in
## the moat and never at the entrances. Listens to the run director, so it
## stays quiet behind the menu.

const TWIST := &"catapult"
## Where the boulders are thrown from (the trebuchets behind the castle).
const LAUNCH_POINTS: Array[Vector3] = [Vector3(-40.0, 26.0, -70.0), Vector3(40.0, 26.0, -70.0), Vector3(0.0, 30.0, -80.0)]

## Seconds between boulders (a random pick in this range).
@export var interval := Vector2(3.0, 4.0)
## Seconds from the ring appearing to the impact.
@export var telegraph := 1.8
## Seconds of the boulder's flight (the end of the telegraph).
@export var flight_time := 0.9
@export var radius := 2.1
@export var damage := 4.0
## Share of the boulders aimed close to the player (the rest land around them).
@export_range(0.0, 1.0) var near_share := 0.35

var _director: RunDirector
var _active := false
var _cool := 2.0
var _strikes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

static var _ring_mesh: TorusMesh
static var _disc_mesh: CylinderMesh
static var _boulder_mesh: SphereMesh


func _ready() -> void:
	_make_meshes()


func _process(delta: float) -> void:
	if _director == null:
		_director = get_tree().get_first_node_in_group("run_director") as RunDirector
		if _director:
			_director.wave_started.connect(_on_wave_started)
			_director.wave_cleared.connect(func(_n: int, _t: int): _active = false)
			_director.state_changed.connect(_on_state_changed)
	if _active:
		_cool -= delta
		if _cool <= 0.0:
			_cool = _rng.randf_range(interval.x, interval.y)
			_launch()
	_tick(delta)


func _on_wave_started(_number: int, _total: int, _banner: String) -> void:
	var wave := _director.current_wave()
	_active = wave != null and wave.twist == TWIST
	_cool = 3.0
	if _active:
		Sfx.play(&"faire_siege_horn")


func _on_state_changed(state: RunDirector.State) -> void:
	if state != RunDirector.State.WAVE:
		_active = false


## For a cinematic: a boulder lands at `at` after the telegraph, its ring
## growing there first. It hurts no one without a run director.
func strike_at(at: Vector3) -> void:
	_start(at)


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


## The floor under a point (null over the moat, off the field or under a roof).
func _ground(p: Vector3) -> Variant:
	var parent := get_parent() as Node3D
	if parent == null:
		return null
	var space := parent.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 16.0, p + Vector3.DOWN * 6.0, 1)
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
	var boulder := MeshInstance3D.new()
	boulder.mesh = _boulder_mesh
	boulder.visible = false
	parent.add_child(boulder)
	var from: Vector3 = LAUNCH_POINTS[_rng.randi() % LAUNCH_POINTS.size()]
	_strikes.append({"at": at, "from": from, "left": telegraph, "ring": ring, "disc": disc, "boulder": boulder})
	Sfx.play_at(&"faire_boulder_whistle", at + Vector3.UP * 3.0, 0.0, _rng.randf_range(0.95, 1.08))


func _tick(delta: float) -> void:
	for i in range(_strikes.size() - 1, -1, -1):
		var s: Dictionary = _strikes[i]
		s.left -= delta
		var k := clampf(1.0 - s.left / telegraph, 0.0, 1.0)
		var r := lerpf(0.4, radius, minf(k * 1.6, 1.0))
		(s.ring as MeshInstance3D).scale = Vector3(r, 1.0, r)
		(s.disc as MeshInstance3D).scale = Vector3(radius * k, 1.0, radius * k)
		var boulder := s.boulder as MeshInstance3D
		if s.left <= flight_time:
			boulder.visible = true
			var t := 1.0 - maxf(s.left, 0.0) / flight_time
			var from: Vector3 = s.from
			var to: Vector3 = (s.at as Vector3) + Vector3.UP * 0.5
			boulder.global_position = from.lerp(to, t) + Vector3.UP * 14.0 * 4.0 * t * (1.0 - t)
			boulder.rotation = Vector3(t * 9.0, t * 4.0, 0.0)
		if s.left <= 0.0:
			_impact(s.at)
			(s.ring as Node).queue_free()
			(s.disc as Node).queue_free()
			boulder.queue_free()
			_strikes.remove_at(i)


func _impact(at: Vector3) -> void:
	var parent := get_parent()
	Fx.impact(parent, at + Vector3.UP * 0.3, Vector3.UP, Color(0.95, 0.82, 0.45))
	Fx.impact(parent, at + Vector3.UP * 0.3, Vector3.UP, Color(0.8, 0.78, 0.74))
	Sfx.play_at(&"faire_boulder_impact", at + Vector3.UP, 0.0, _rng.randf_range(0.9, 1.1))
	var player := _director.player if _director else null
	if player and player.alive:
		var d := player.global_position - at
		if Vector2(d.x, d.z).length() <= radius and absf(d.y) < 2.5:
			player.take_damage(damage, at)


func _make_meshes() -> void:
	if _ring_mesh:
		return
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.albedo_color = Color(1.0, 0.78, 0.2)
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.88
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 40
	_ring_mesh.ring_segments = 4
	_ring_mesh.material = gold
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, 0.6, 0.12, 0.4)
	_disc_mesh = CylinderMesh.new()
	_disc_mesh.top_radius = 1.0
	_disc_mesh.bottom_radius = 1.0
	_disc_mesh.height = 0.02
	_disc_mesh.radial_segments = 32
	_disc_mesh.material = glow
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.62, 0.6, 0.66)
	rock.roughness = 0.9
	_boulder_mesh = SphereMesh.new()
	_boulder_mesh.radius = 0.55
	_boulder_mesh.height = 1.0
	_boulder_mesh.radial_segments = 8
	_boulder_mesh.rings = 5
	_boulder_mesh.material = rock
