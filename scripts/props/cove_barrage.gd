extends Node3D
## Skull Harbor's twist ("barrage", the Broadside wave). The Barnacle Queen
## runs out her guns and fires on the quay: each shot is announced where it
## will land by a ring that grows on the ground (a BossZone, so it reads like
## every other marked strike), then the cannon at one of the galleon's gun
## ports booms with a flash and a puff of smoke and the ball arcs in to land
## as the ring fills. Standing in the ring costs `damage`. Rings fall near the
## player but never stack up, never off the floor and never at an entrance.
## The sunset sky smokes up while it lasts. Listens to the run director, so
## it stays quiet behind the menu.

const TWIST := &"barrage"

## Seconds between shots (a random pick in this range).
@export var interval := Vector2(2.0, 3.0)
## Seconds from the ring appearing to the impact, and of the ball's flight.
@export var telegraph := 1.9
@export var flight := 1.25
@export var radius := 2.1
@export var damage := 6.0
## Share of the shots aimed close to the player (the rest land around them).
@export_range(0.0, 1.0) var near_share := 0.35
## Seconds for the sky to smoke up or clear.
@export var transition := 3.0

var _director: RunDirector
var _active := false
var _level := 0.0
var _cool := 2.0
var _shots: Array[Dictionary] = []
var _ports: Array[Node3D] = []
var _sky: ShaderMaterial
var _rng := RandomNumberGenerator.new()

static var _ball_mesh: SphereMesh


func _ready() -> void:
	# Work on a copy: the scene's resources are shared with the next Retry.
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment and we.environment.sky:
		we.environment = we.environment.duplicate()
		we.environment.sky = we.environment.sky.duplicate()
		_sky = we.environment.sky.sky_material.duplicate() as ShaderMaterial
		we.environment.sky.sky_material = _sky
	for node in get_tree().get_nodes_in_group("cove_gunport"):
		_ports.append(node as Node3D)
	if _ball_mesh == null:
		_ball_mesh = SphereMesh.new()
		_ball_mesh.radius = 0.32
		_ball_mesh.height = 0.64
		_ball_mesh.radial_segments = 12
		_ball_mesh.rings = 6
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.16, 0.16, 0.2)
		iron.roughness = 0.4
		iron.metallic = 0.5
		_ball_mesh.material = iron


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
		if _sky:
			_sky.set_shader_parameter("barrage", ease(_level, -1.6))
	if _active and _level > 0.4:
		_cool -= delta
		if _cool <= 0.0:
			_cool = _rng.randf_range(interval.x, interval.y)
			_aim()
	_tick(delta)


func _on_wave_started(_number: int, _total: int, _banner: String) -> void:
	var wave := _director.current_wave()
	_active = wave != null and wave.twist == TWIST
	_cool = 2.5
	if _active:
		Sfx.play(&"cove_broadside_call")


func _on_state_changed(state: RunDirector.State) -> void:
	if state != RunDirector.State.WAVE:
		_active = false


## Picks a landing spot near the player and marks it.
func _aim() -> void:
	var player := _director.player if _director else null
	if player == null or not player.alive or _ports.is_empty():
		return
	for attempt in 6:
		var near := _rng.randf() < near_share
		var dist := _rng.randf_range(0.0, 2.2) if near else _rng.randf_range(3.0, 8.5)
		var a := _rng.randf_range(0.0, TAU)
		var guess := player.global_position + player.velocity * Vector3(1, 0, 1) * 0.6 + Vector3(cos(a), 0, sin(a)) * dist
		var spot: Variant = _ground(guess)
		if spot != null and _clear(spot):
			_mark(spot)
			return


## The floor under a point (null over the water or on a slope).
func _ground(p: Vector3) -> Variant:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 6.0, p + Vector3.DOWN * 6.0, 1)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return null
	var at: Vector3 = hit.position
	if at.y < -0.3 or (hit.normal as Vector3).y < 0.8:
		return null
	return at


func _clear(spot: Vector3) -> bool:
	for s in _shots:
		if (s.at as Vector3).distance_to(spot) < radius * 1.8:
			return false
	for e in get_tree().get_nodes_in_group("enemy_spawn"):
		if (e as Node3D).global_position.distance_to(spot) < 6.0:
			return false
	return true


func _mark(at: Vector3) -> void:
	var port := _ports[0]
	var best := INF
	for p in _ports:
		var d := p.global_position.distance_to(at) + _rng.randf_range(0.0, 6.0)
		if d < best:
			best = d
			port = p
	var zone := BossZone.new()
	zone.radius = radius
	zone.telegraph = telegraph
	zone.damage = damage
	zone.color = Color(1.0, 0.58, 0.2)
	zone.style = BossZone.Style.BURST
	zone.prop = BossZone.Prop.NONE
	zone.warn_sound = &"cove_cannon_whistle"
	zone.hit_sound = &"cove_cannon_impact"
	zone.source = port
	get_parent().add_child(zone)
	zone.global_position = at
	_shots.append({"at": at, "port": port, "left": telegraph, "ball": null})


func _tick(delta: float) -> void:
	for i in range(_shots.size() - 1, -1, -1):
		var s: Dictionary = _shots[i]
		s.left -= delta
		if s.ball == null and s.left <= flight:
			_fire(s)
		if s.ball != null:
			var ball := s.ball as MeshInstance3D
			var t := clampf(1.0 - s.left / flight, 0.0, 1.0)
			var from: Vector3 = s.from
			var to: Vector3 = s.at
			ball.global_position = from.lerp(to, t) + Vector3.UP * (4.0 + from.distance_to(to) * 0.12) * 4.0 * t * (1.0 - t)
		if s.left <= 0.0:
			if s.ball != null:
				(s.ball as Node).queue_free()
			Fx.impact(get_parent(), (s.at as Vector3) + Vector3.UP * 0.3, Vector3.UP, Color(0.55, 0.5, 0.55))
			_shots.remove_at(i)


## The gun fires: flash, smoke and the ball on its way.
func _fire(s: Dictionary) -> void:
	var port := s.port as Node3D
	var from := port.global_position
	s.from = from
	var ball := MeshInstance3D.new()
	ball.mesh = _ball_mesh
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(ball)
	ball.global_position = from
	s.ball = ball
	var out := ((s.at as Vector3) - from) * Vector3(1, 0, 1)
	out = out.normalized() + Vector3.UP * 0.3
	Fx.impact(get_parent(), from, out, Color(1.0, 0.75, 0.3))
	Fx.impact(get_parent(), from, out, Color(0.8, 0.78, 0.82))
	Fx.impact(get_parent(), from + out * 0.6, out, Color(0.65, 0.62, 0.7))
	Sfx.play_at(&"cove_cannon_boom", from, 0.0, _rng.randf_range(0.92, 1.06))
