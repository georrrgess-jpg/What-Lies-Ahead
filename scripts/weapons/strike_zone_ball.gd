class_name StrikeZoneBall
extends Node3D
## A bowled ball (the Strike Zone, scripts/weapons/modes/strike_zone_mode.gd).
## It leaves the chamber at its roll speed, drops to the floor with a thud
## and rolls: it follows the floor up and down slopes (gravity along the
## slope speeds it up or slows it down), drops off ledges, bounces off the
## first wall it meets (WALL_KEEP of its speed) and stops at the second.
##
## It bowls over every zombie its lane crosses, once each: weapon damage
## times the wind-up's scale, PIN_FALLOFF less for every pin already down.
## Light zombies are knocked flat (StrikeZoneTopple) and scatter off to the
## sides like pins, each costing the ball PIN_DRAG of its speed. Heavies
## (mass HEAVY_MASS and up) only stagger, take BIG_SCALE and cost it
## HEAVY_DRAG; a boss takes BIG_SCALE and stops the ball dead (it rebounds a
## little). STRIKE_PINS in one roll is a strike: a banner pops
## (StrikeZoneBanner), and the ball goes straight back in the magazine.
##
## After ROLL_TIME, or once it has nearly stopped, a hologram gutter opens
## under it and it sinks away (SINK_TIME). Hits go through
## WeaponController.ring_hit. tools/balance_report.py reads these constants.

const MASK_WORLD := 1
const GRAVITY := 22.0
## Seconds the ball rolls before it sinks into the gutter.
const ROLL_TIME := 3.0
## Rolling friction (m/s lost per second) and the speed below which it sinks.
const FRICTION := 1.6
const STOP_SPEED := 2.5
## Speed (m/s) at which it leaves the chamber downwards (it drops, not lobs).
const DROP_SPEED := 3.5
## A landing faster than this (m/s down) hops once.
const HOP_SPEED := 4.0
## Reach (m) beyond a zombie's capsule at which the ball bowls it over.
const REACH := 0.15
const PIN_FALLOFF := 0.92
## Speed kept after bowling over a light zombie, after a heavy, and off a wall.
const PIN_DRAG := 0.9
const HEAVY_DRAG := 0.55
const WALL_KEEP := 0.75
## Zombies this heavy or heavier only stagger.
const HEAVY_MASS := 2.5
## Damage multiplier on heavies and bosses (the whole ball's weight lands).
const BIG_SCALE := 1.35
## A boss sends the ball back at this share of its speed.
const BOSS_REBOUND := 0.3
## Sideways scatter (m/s) given to a bowled-over light zombie, before its mass.
const SCATTER := 5.5
const STRIKE_PINS := 5
const SINK_TIME := 0.7
const GUTTER_LENGTH := 2.6
const TRAIL := 14
## Near the camera the ball is drawn smaller (it starts in the chamber).
const NEAR_EYE := 2.2
const ROLL_SOUND := &"sz_roll_loop"
const BALL_SCENE := "res://art/models/strike_zone_ball.glb"
const HOLO_SHADER := "res://art/shaders/holo.gdshader"
const PIN_SPARKS := [Color(1.0, 0.98, 0.92), Color(1.0, 0.3, 0.6), Color(0.3, 0.95, 1.0)]
const STRIKE_COLORS := [Color(1.0, 0.85, 0.3), Color(1.0, 0.3, 0.62), Color(0.3, 0.95, 1.0), Color(1.0, 1.0, 1.0)]

var weapon: WeaponData
var controller: WeaponController
var mode: StrikeZoneMode
var velocity := Vector3.ZERO
var pins := 0
var _scale := 1.0
var _fall := 0.0
var _grounded := false
var _bounced := false
var _age := 0.0
var _sink := -1.0
var _struck := {}
var _spin := Basis.IDENTITY
var _ball: Node3D
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _history := PackedVector3Array()
var _gutter: Node3D
var _gutter_mat: ShaderMaterial
var _sink_from := Vector3.ZERO
var _hum: AudioStreamPlayer3D
var _exclude: Array[RID] = []
var _strike := false
## The way it last rolled (flat), for the gutter.
var _heading := Vector3.FORWARD

static var _ball_scene: PackedScene
static var _gutter_meshes: Array[BoxMesh] = []


## Rolls a ball from `from` along the flat direction `dir` at `speed` m/s,
## dealing `scale` times its damage; it leaves at `lift` m/s upward (negative:
## dropped).
static func launch(owner_controller: WeaponController, owner_mode: StrikeZoneMode, from: Vector3, dir: Vector3, speed: float, scale: float,
		lift: float) -> StrikeZoneBall:
	var level := owner_controller.player.get_parent()
	if level == null:
		return null
	var b := StrikeZoneBall.new()
	b.weapon = owner_mode.data
	b.controller = owner_controller
	b.mode = owner_mode
	b.velocity = dir * speed
	b._heading = dir
	b._fall = lift
	b._scale = scale
	b._exclude = [owner_controller.player.get_rid()]
	level.add_child(b)
	b.global_position = from
	return b


func _ready() -> void:
	if _ball_scene == null and ResourceLoader.exists(BALL_SCENE):
		_ball_scene = load(BALL_SCENE)
	_ball = _ball_scene.instantiate() if _ball_scene else Node3D.new()
	_ball.visible = false
	add_child(_ball)
	_disable_shadows(_ball)
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	_trail.global_transform = Transform3D.IDENTITY
	_start_hum()


func _start_hum() -> void:
	var s := Sfx.stream(ROLL_SOUND)
	if s == null:
		return
	if s is AudioStreamWAV and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = int(s.get_length() * s.mix_rate)
	_hum = AudioStreamPlayer3D.new()
	_hum.stream = s
	_hum.bus = &"SFX"
	_hum.unit_size = 7.0
	_hum.volume_db = -4.0 + Sfx.mix_db(ROLL_SOUND)
	_hum.pitch_scale = randf_range(0.95, 1.05)
	add_child(_hum)
	_hum.play()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not is_instance_valid(controller.player):
		queue_free()
		return
	if _sink >= 0.0:
		_sinking(delta)
		return
	_age += delta
	var from := global_position
	_roll(delta)
	_bowl_along(from, global_position)
	if _sink < 0.0 and (_age >= ROLL_TIME or _grounded and _flat_speed() < STOP_SPEED):
		_to_gutter()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var eye_distance := cam.global_position.distance_to(global_position) if cam else NEAR_EYE
	var near := clampf(eye_distance / NEAR_EYE, 0.35, 1.0)
	# It leaves the chamber hidden, until it is clear of the viewmodel.
	_ball.visible = _ball.visible or eye_distance > NEAR_EYE * 0.45
	# Rolls without slipping: it turns by the distance it covers over its radius.
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var r := maxf(0.05, weapon.projectile_size)
	if flat.length() > 0.05 and _sink < 0.0:
		var axis := Vector3.UP.cross(flat.normalized())
		_spin = Basis(axis, flat.length() * delta / r) * _spin
	_ball.basis = _spin.orthonormalized().scaled(Vector3.ONE * near)
	_draw_trail(cam, near < 1.0 or _sink >= 0.0)
	if _hum:
		_hum.pitch_scale = lerpf(0.7, 1.25, clampf(_flat_speed() / maxf(1.0, weapon.projectile_speed), 0.0, 1.0))
		_hum.volume_db = (-4.0 if _grounded else -14.0) + Sfx.mix_db(ROLL_SOUND)


# --- rolling ------------------------------------------------------------------

func _roll(delta: float) -> void:
	var r := weapon.projectile_size
	var step := Vector3(velocity.x, 0.0, velocity.z) * delta
	if step.length() > 0.0001:
		var wall := _ray(global_position, global_position + step + step.normalized() * r)
		if not wall.is_empty() and absf((wall["normal"] as Vector3).y) < 0.6:
			_hit_wall(wall)
			if _sink >= 0.0:
				return
			step = Vector3(velocity.x, 0.0, velocity.z) * delta
	var at := global_position + step
	_fall -= GRAVITY * delta
	var drop := maxf(0.0, -_fall * delta)
	var ground := _ray(at + Vector3.UP * r * 0.9, at + Vector3.DOWN * (r + drop + 0.12))
	var floor_y := -INF
	if not ground.is_empty() and (ground["normal"] as Vector3).y >= 0.6:
		floor_y = (ground["position"] as Vector3).y + r
	var landing := at.y + _fall * delta
	if floor_y > -INF and landing <= floor_y + (0.08 if _grounded else 0.0):
		if not _grounded and _fall < -HOP_SPEED:
			_land(at, -_fall)
			_fall = -_fall * 0.28
			at.y = floor_y + 0.001
		else:
			_fall = 0.0
			at.y = floor_y
			_grounded = true
			_follow_slope(ground["normal"], delta)
	else:
		at.y = landing
		_grounded = false
	global_position = at
	if at.y < controller.player.global_position.y - 40.0:
		queue_free()


## Gravity along the slope it rolls on, and rolling friction.
func _follow_slope(normal: Vector3, delta: float) -> void:
	var along := (Vector3.DOWN * GRAVITY).slide(normal)
	velocity += Vector3(along.x, 0.0, along.z) * delta
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := maxf(0.0, flat.length() - FRICTION * delta)
	velocity = flat.normalized() * speed if flat.length() > 0.001 else Vector3.ZERO
	if speed > 0.1:
		_heading = velocity / speed


func _land(at: Vector3, impact: float) -> void:
	Sfx.play_at(&"sz_thud", at, -2.0, randf_range(0.92, 1.05))
	WeaponFx.burst(get_parent(), at + Vector3.DOWN * weapon.projectile_size, Vector3.UP, PIN_SPARKS, 6, 2.0 + impact * 0.2, 0.25, 0.03)


## Off the first wall it bounces; the second one stops it for the gutter.
func _hit_wall(hit: Dictionary) -> void:
	var n: Vector3 = hit["normal"]
	n = Vector3(n.x, 0.0, n.z).normalized()
	var at: Vector3 = hit["position"]
	WeaponFx.burst(get_parent(), at, n, PIN_SPARKS, 10, 3.5, 0.3, 0.04)
	Sfx.play_at(weapon.bounce_sound, at, -1.0, randf_range(0.92, 1.06))
	global_position = Vector3(at.x, global_position.y, at.z) + n * (weapon.projectile_size + 0.02)
	if _bounced:
		velocity = Vector3.ZERO
		_to_gutter()
		return
	_bounced = true
	velocity = velocity.bounce(n) * WALL_KEEP
	velocity.y = 0.0


func _flat_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


# --- bowling ------------------------------------------------------------------

## Bowls over every zombie the segment `from` - `to` passes (once each).
func _bowl_along(from: Vector3, to: Vector3) -> void:
	var seg := to - from
	var flat := Vector2(seg.x, seg.z)
	var len_sq := flat.length_squared()
	var r := weapon.projectile_size
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead() or _struck.has(z.get_instance_id()):
			continue
		var base := z.global_position
		var s := z.data.body_scale
		var rel := Vector2(base.x - from.x, base.z - from.z)
		var t := clampf(rel.dot(flat) / len_sq, 0.0, 1.0) if len_sq > 0.0001 else 0.0
		var at := from + seg * t
		if at.y + r < base.y - 0.1 or at.y - r > base.y + 1.9 * s:
			continue
		if Vector2(at.x - base.x, at.z - base.z).length() <= r + REACH + z.data.capsule_radius * s:
			_bowl(z, at)
			if _sink >= 0.0 or _flat_speed() < 0.01:
				return


func _bowl(z: Zombie, at: Vector3) -> void:
	_struck[z.get_instance_id()] = true
	var dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var boss := z.rank == Zombie.RANK_BOSS
	var heavy := boss or z.data.mass >= HEAVY_MASS
	var dmg := weapon.damage * _scale * pow(PIN_FALLOFF, pins) * (BIG_SCALE if heavy else 1.0)
	pins += 1
	var point := Vector3(z.global_position.x, at.y, z.global_position.z) - dir * z.data.capsule_radius * z.data.body_scale
	var level := get_parent()
	WeaponFx.burst(level, point, -dir, PIN_SPARKS, 9, 4.0, 0.3, 0.04, 80.0)
	Sfx.play_at(weapon.ricochet_sound, point, -1.0, 1.0 + 0.05 * mini(pins, 8) + randf_range(-0.03, 0.03))
	var killed := controller.ring_hit(weapon, z, point, dir, dmg, false)
	if boss:
		# A boss is the back wall: the ball thumps off it and drops away.
		velocity = -dir * _flat_speed() * BOSS_REBOUND
		_bounced = true
	elif heavy:
		if not killed:
			z.interrupt()
		velocity *= HEAVY_DRAG
	else:
		if not killed:
			StrikeZoneTopple.knock_down(z, _scatter(z, dir))
		velocity *= PIN_DRAG
	if pins == STRIKE_PINS:
		_strike_out(point)


## Bowled-over pins fly off to the side they were hit on, and on down the lane.
func _scatter(z: Zombie, dir: Vector3) -> Vector3:
	var side := dir.cross(Vector3.UP)
	var off := (z.global_position - global_position).dot(side)
	var out := (dir * 0.8 + side * (1.0 if off >= 0.0 else -1.0)).normalized()
	return out * SCATTER * clampf(_flat_speed() / maxf(1.0, weapon.projectile_speed), 0.5, 1.0)


## STRIKE: the banner, a pin burst, and the ball goes back in the magazine.
func _strike_out(at: Vector3) -> void:
	_strike = true
	var rung := mode.scored_strike() if mode else 1
	var level := get_parent()
	StrikeZoneBanner.spawn(level, at + Vector3.UP * 1.9, rung)
	WeaponFx.burst(level, at + Vector3.UP * 0.8, Vector3.UP, STRIKE_COLORS, 36, 6.5, 0.7, 0.06, 160.0)
	WeaponFx.flash(level, at + Vector3.UP * 0.6, STRIKE_COLORS[0], 1.6, 0.22)
	Sfx.play(&"sz_strike", -1.0, 1.0 + 0.06 * mini(rung - 1, 3))
	controller.return_round(weapon)
	controller.player.view.weapon_event(weapon, &"strike")


# --- the gutter ---------------------------------------------------------------

## A hologram gutter opens under the ball and it sinks away.
func _to_gutter() -> void:
	_sink = 0.0
	_sink_from = global_position
	if mode and not _strike:
		mode.missed_strike()
	if _hum:
		_hum.stop()
	var dir := _heading
	_gutter = _build_gutter()
	get_parent().add_child(_gutter)
	var floor_at := global_position + Vector3.DOWN * weapon.projectile_size
	_gutter.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), floor_at + dir * 0.4)
	Sfx.play_at(&"sz_gutter", global_position, -3.0, randf_range(0.95, 1.05))


func _sinking(delta: float) -> void:
	_sink += delta
	var k := clampf(_sink / SINK_TIME, 0.0, 1.0)
	var r := weapon.projectile_size
	# Slides on into the channel as it drops through the floor.
	var on := Vector3(velocity.x, 0.0, velocity.z) * (1.0 - k) * 0.25 * delta
	_sink_from += on
	global_position = _sink_from + Vector3.DOWN * r * 2.2 * k * k
	var open := smoothstep(0.0, 0.25, k) * (1.0 - smoothstep(0.75, 1.0, k))
	if _gutter_mat:
		_gutter_mat.set_shader_parameter("materialize", open)
	if k >= 1.0:
		if is_instance_valid(_gutter):
			_gutter.queue_free()
		queue_free()


func _build_gutter() -> Node3D:
	if _gutter_meshes.is_empty():
		for size in [Vector3(0.62, 0.03, GUTTER_LENGTH), Vector3(0.05, 0.16, GUTTER_LENGTH), Vector3(0.05, 0.16, GUTTER_LENGTH)]:
			var m := BoxMesh.new()
			m.size = size
			_gutter_meshes.append(m)
	_gutter_mat = ShaderMaterial.new()
	_gutter_mat.shader = load(HOLO_SHADER)
	_gutter_mat.set_shader_parameter("holo_color", Color(0.3, 0.95, 1.0))
	_gutter_mat.set_shader_parameter("span", 0.08)
	_gutter_mat.set_shader_parameter("materialize", 0.0)
	var g := Node3D.new()
	var xs := [0.0, -0.33, 0.33]
	var ys := [-0.01, 0.06, 0.06]
	for i in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = _gutter_meshes[i]
		mi.material_override = _gutter_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(xs[i], ys[i], 0.0)
		g.add_child(mi)
	return g


# --- helpers ------------------------------------------------------------------

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD)
	query.exclude = _exclude
	return get_world_3d().direct_space_state.intersect_ray(query)


## A cyan lane streak along the floor behind the ball.
func _draw_trail(cam: Camera3D, hidden: bool) -> void:
	var low := global_position + Vector3.DOWN * weapon.projectile_size * 0.9
	if _history.is_empty() or hidden:
		_history.resize(TRAIL)
		_history.fill(low)
	for i in range(TRAIL - 1, 0, -1):
		_history[i] = _history[i - 1]
	_history[0] = low
	if cam == null or hidden:
		_trail_mesh.clear_surfaces()
		return
	var color := STRIKE_COLORS[0] if _strike else weapon.tracer_color
	WeaponFx.begin_ribbons(_trail_mesh, WeaponFx.ribbon_material())
	WeaponFx.add_ribbon(_trail_mesh, _history, weapon.projectile_size * 1.1, Color(color, 0.5), cam.global_position)
	WeaponFx.end_ribbons(_trail_mesh)


static func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)
