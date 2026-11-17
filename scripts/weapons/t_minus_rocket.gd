class_name TMinusRocket
extends Node3D
## One gyrojet mini-rocket of the T-Minus Six (scripts/weapons/modes/t_minus_six_mode.gd).
##
##   seeker  a painted rocket: it leaves the pod on its slot's petal of a
##           blossom (fanned out and up, so the swarm opens like a flower and
##           arcs over low cover), boosts, then turns ever harder onto the
##           painted zombie's head (seek_point). If that zombie dies first it
##           takes the nearest live zombie within RETARGET of it.
##   dumb    no paint: one straight, fast, unguided rocket.
##
## The flight path is exact; only the drawn rocket corkscrews round it
## (CORKSCREW, tightening onto the target), and it leaves a soft teal smoke
## ribbon behind it that coils round its track in a tight spiral (SPIRAL_*,
## laid by distance flown, so it keeps its shape at any frame rate): it
## widens and fades towards its tail and is shaded lighter where the coil
## passes in front of the track, with a short glow at the nozzle. A rocket strikes the first zombie its path meets (head or body,
## where it hits; headshots per head_scale) or the painted head once within
## HIT_RADIUS of it, and pops with a small splash
## (SPLASH_DAMAGE within SPLASH_RADIUS); scenery or the end of its FUSE pops
## it too. Hits go through WeaponController.ring_hit.

const MASK_WORLD := 1
const MASK_ENEMIES := 4
const BOOST_SPEED := 15.0
const SEEK_SPEED := 31.0
const DUMB_SPEED := 55.0
## Seconds a seeker flies its petal before it starts to turn, and to full speed.
const BOOST_TIME := 0.1
const ACCEL_TIME := 0.4
## Turn rate (1/s) as the seeker settles onto its target.
const STEER_START := 3.0
const STEER_END := 24.0
const STEER_RAMP := 0.35
## A seeker flies its blossom clear of scenery for this long (it fans out
## over the cover the paint looked past), then pops on what it meets.
const CLEAR_TIME := 0.22
## The blossom (across the upper half): how far each petal leans out from
## the aim, and up.
const PETAL := 0.42
const PETAL_LIFT := 0.15
const HIT_RADIUS := 0.45
const RETARGET := 9.0
const FUSE := 2.6
const SPLASH_RADIUS := 1.5
const SPLASH_DAMAGE := 18.0
const HEAVY_HEAD_SHARE := 0.6
## Corkscrew radius (m) of the drawn rocket, its turn rate (rad/s), and the
## distance to the target inside which it closes onto the true path.
const CORKSCREW := 0.2
const CORK_RATE := 21.0
const CORK_CLOSE := 4.0
const TRAIL := 24
## Smoke ribbon width at the nozzle and at the tail (it billows out), and its
## opacity at the nozzle (it fades to nothing at the tail).
const SMOKE_WIDTH := Vector2(0.06, 0.19)
const SMOKE_ALPHA := 0.92
## How much lighter / darker the smoke is where the coil faces the eye / turns away.
const SMOKE_TWIST := 0.3
## The smoke coil: radians per metre flown (a turn every 1.6 m), its radius
## at the nozzle and at the tail, and the points laid per frame of history.
const SPIRAL_TWIST := 3.9
const SPIRAL_RADIUS := Vector2(0.02, 0.16)
const SPIRAL_STEPS := 3
## Trail points the additive nozzle glow covers, and its width.
const GLOW_POINTS := 5
const GLOW_WIDTH := 0.1
const SMOKE_SHADER := "res://art/shaders/t_minus_smoke.gdshader"
## Near the camera the rocket is drawn smaller and without its trail.
const NEAR_EYE := 2.4
const LAUNCH_SOUND := &"tm6_launch"
const POP_SOUND := &"tm6_pop"
const TEAL := Color(0.247, 0.941, 0.831)
const CREAM := Color(1.0, 0.957, 0.863)
const FLAME := Color(1.0, 0.82, 0.25)
const POP_COLORS := [Color(0.247, 0.941, 0.831), Color(1.0, 0.824, 0.247), Color(1.0, 0.957, 0.863), Color(0.91, 0.247, 0.247)]

var weapon: WeaponData
var controller: WeaponController
var target: Zombie
var velocity := Vector3.ZERO
var _seeker := false
var _slot := 0
var _delay := 0.0
var _dir := Vector3.FORWARD
var _from := Vector3.ZERO
var _age := 0.0
var _flown := 0.0
var _goal := Vector3.ZERO
var _cork := 0.0
var _cork_side := 1.0
var _drawn := Vector3.ZERO
var _body: Node3D
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _history := PackedVector3Array()
## Per trail point: the metres flown when it was laid.
var _laid := PackedFloat32Array()
## The smoke coil built from the history each frame (reused buffers): its
## points, their metres flown and their offset direction from the track.
var _coil := PackedVector3Array()
var _coil_d := PackedFloat32Array()
var _coil_out := PackedVector3Array()
var _query: PhysicsRayQueryParameters3D
var _launched := false
var _cast_from := Vector3.ZERO

static var _meshes := {}
static var _smoke_mat: ShaderMaterial


## Fires a rocket from `from` along `dir` under `parent`. With a `seek`
## zombie it is a seeker taking slot `slot` of the blossom, leaving the pod
## `delay` seconds from now; without, a dumb rocket.
static func launch(parent: Node, from: Vector3, dir: Vector3, w: WeaponData, owner_controller: WeaponController, seek: Zombie, slot: int, delay: float) -> TMinusRocket:
	var r := TMinusRocket.new()
	r.weapon = w
	r.controller = owner_controller
	r.target = seek
	r._seeker = seek != null
	r._slot = slot
	r._delay = delay
	r._dir = dir.normalized()
	r._from = from
	parent.add_child(r)
	return r


## A rocket's headshot multiplier on `z`: the weapon's, but only
## HEAVY_HEAD_SHARE of its bonus on heavies and bosses (the little rockets
## glance off big skulls).
static func head_scale(w: WeaponData, z: Zombie) -> float:
	return lerpf(1.0, w.headshot_multiplier, HEAVY_HEAD_SHARE) if z.data.heavy else w.headshot_multiplier


## Where a rocket aims on `z`: the middle of its head (the head capsule the
## zombie keeps on its Head bone), or about head height without one.
static func seek_point(z: Zombie) -> Vector3:
	var head := z.get_node_or_null("HeadShape") as Node3D
	if head:
		return head.global_position
	return z.global_position + Vector3.UP * (z.data.head_height + 0.12) * z.data.body_scale


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_add_mesh(&"body", Vector3(0, 0, 0))
	_add_mesh(&"nose", Vector3(0, 0, -0.14))
	_add_mesh(&"flame", Vector3(0, 0, 0.14))
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	_trail.global_transform = Transform3D.IDENTITY
	_query = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.FORWARD, MASK_WORLD | MASK_ENEMIES)
	_query.exclude = [controller.player.get_rid()]
	_cork_side = 1.0 if _slot % 2 == 0 else -1.0
	_cork = _slot * TAU / 6.0
	visible = false
	if _delay <= 0.0:
		_leave_pod()


func _leave_pod() -> void:
	_launched = true
	visible = true
	# A rocket that waited in the pod leaves from where the pod is now.
	if _delay > 0.0 and is_instance_valid(controller.player) and controller.current == weapon:
		_from = controller.player.view.muzzle_position()
	global_position = _from
	_drawn = _from
	# The first step is cast from the eye: a zombie right at the muzzle is struck.
	_cast_from = controller.player.camera.global_position if controller.current == weapon else _from
	if _seeker:
		var side := _dir.cross(Vector3.UP)
		side = side.normalized() if side.length() > 0.05 else Vector3.RIGHT
		var up := side.cross(_dir).normalized()
		# The petals fan across the upper half, right to left by slot.
		var a := PI * (0.1 + 0.8 * (_slot % 6) / 5.0) + randf_range(-0.12, 0.12)
		velocity = (_dir + (side * cos(a) + up * (sin(a) + PETAL_LIFT)) * PETAL).normalized() * BOOST_SPEED
	else:
		velocity = _dir * DUMB_SPEED
	_goal = seek_point(target) if _seeker and is_instance_valid(target) else _from + _dir * weapon.max_range
	if _slot > 0:
		Sfx.play(LAUNCH_SOUND, -7.0, randf_range(0.95, 1.1) + 0.03 * _slot)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(controller) or not is_instance_valid(controller.player):
		queue_free()
		return
	if not _launched:
		_delay -= delta
		if _delay <= 0.0:
			_leave_pod()
		return
	_age += delta
	if _age >= FUSE:
		_pop(global_position, Vector3.UP, null)
		return
	if _seeker:
		_steer(delta)
	var from := global_position
	var to := from + velocity * delta
	if _seeker and is_instance_valid(target) and not target.is_dead() and _near_goal(from, to):
		_pop(_goal, velocity.normalized(), target, true)
		return
	_query.from = from if _age > delta else _cast_from
	_query.to = to
	_query.collision_mask = MASK_ENEMIES if _seeker and _age < CLEAR_TIME else MASK_WORLD | MASK_ENEMIES
	var hit := get_world_3d().direct_space_state.intersect_ray(_query)
	if not hit.is_empty():
		var z := hit["collider"] as Zombie
		_pop(hit["position"], hit["normal"] if z == null else velocity.normalized(), z if z and not z.is_dead() else null)
		return
	_flown += from.distance_to(to)
	global_position = to
	if not _seeker and _flown >= weapon.max_range:
		_pop(to, Vector3.UP, null)


func _process(delta: float) -> void:
	if not _launched:
		return
	var dir := velocity.normalized() if velocity.length() > 0.1 else _dir
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.05 else Vector3.RIGHT
	var up := side.cross(dir).normalized()
	# The corkscrew opens up out of the pod and closes onto the target.
	var radius := CORKSCREW * (1.0 if _seeker else 0.25) * clampf(_flown / 2.0, 0.0, 1.0)
	if _seeker:
		radius *= clampf(global_position.distance_to(_goal) / CORK_CLOSE, 0.0, 1.0)
	_cork += delta * CORK_RATE * _cork_side
	var drawn := global_position + (side * cos(_cork) + up * sin(_cork)) * radius
	var heading := (drawn - _drawn) if drawn.distance_to(_drawn) > 0.001 else dir
	_drawn = drawn
	var cam := get_viewport().get_camera_3d()
	var near := clampf(cam.global_position.distance_to(drawn) / NEAR_EYE, 0.12, 1.0) if cam else 1.0
	_body.global_transform = Transform3D(Basis.looking_at(heading.normalized(), up), drawn).scaled_local(Vector3.ONE * near)
	_draw_trail(cam, near < 0.6)


# --- flight -------------------------------------------------------------------

func _steer(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dead():
		target = _retarget()
	if is_instance_valid(target):
		_goal = seek_point(target)
	var speed := lerpf(BOOST_SPEED, SEEK_SPEED, clampf((_age - BOOST_TIME) / ACCEL_TIME, 0.0, 1.0))
	var want := velocity.normalized()
	if _age >= BOOST_TIME:
		var to := _goal - global_position
		if to.length() > 0.05:
			var steer := lerpf(STEER_START, STEER_END, clampf((_age - BOOST_TIME) / STEER_RAMP, 0.0, 1.0))
			want = want.lerp(to.normalized(), minf(1.0, steer * delta)).normalized()
	velocity = want * speed
	# Lost its zombie and nothing to take over: it pops where it was headed.
	if not is_instance_valid(target) and global_position.distance_to(_goal) < HIT_RADIUS * 2.0:
		_pop(global_position, Vector3.UP, null)


## The nearest live zombie within RETARGET of where the old target was.
func _retarget() -> Zombie:
	var best: Zombie = null
	var best_d := RETARGET
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var d := z.global_position.distance_to(_goal)
		if d < best_d:
			best = z
			best_d = d
	return best


## True if the step `from` - `to` passes within HIT_RADIUS of the goal.
func _near_goal(from: Vector3, to: Vector3) -> bool:
	return Geometry3D.get_closest_point_to_segment(_goal, from, to).distance_to(_goal) <= HIT_RADIUS


# --- the pop ------------------------------------------------------------------

## Pops at `at`: a direct hit on `struck` (`on_head` when it homed onto the
## painted head), then the splash on the zombies round it.
func _pop(at: Vector3, normal: Vector3, struck: Zombie, on_head := false) -> void:
	var level := get_parent()
	var dir := velocity.normalized() if velocity.length() > 0.1 else _dir
	if struck:
		var head := on_head or struck.is_head_hit(at, at - dir * 0.6)
		var dmg := weapon.damage * (head_scale(weapon, struck) if head else 1.0)
		controller.ring_hit(weapon, struck, at, dir, dmg, head)
	_splash(at, struck, dir)
	WeaponFx.flash(level, at, FLAME, 0.75, 0.12)
	WeaponFx.burst(level, at, -dir if struck else normal, POP_COLORS, 14, 5.0, 0.35, 0.045, 150.0)
	Sfx.play_at(POP_SOUND, at, -1.0, randf_range(0.93, 1.1), 12.0)
	queue_free()


func _splash(at: Vector3, struck: Zombie, dir: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z == struck or z.is_dead():
			continue
		var chest := z.global_position + Vector3.UP * 1.05 * z.data.body_scale
		if chest.distance_to(at) > SPLASH_RADIUS + z.data.capsule_radius * z.data.body_scale:
			continue
		var q := PhysicsRayQueryParameters3D.create(at, chest, MASK_WORLD)
		if not space.intersect_ray(q).is_empty():
			continue
		var away := z.global_position - at
		away.y = 0.0
		var push := away.normalized() if away.length() > 0.05 else dir
		controller.ring_hit(weapon, z, chest, push, SPLASH_DAMAGE, false)


# --- drawing ------------------------------------------------------------------

func _add_mesh(kind: StringName, offset: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = offset
	_body.add_child(mi)


## The rocket's three shared meshes: a cream body, a red nose cone and an
## additive flame (pointing along -Z, the way the rocket flies).
static func _mesh(kind: StringName) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m := StandardMaterial3D.new()
	var mesh: Mesh
	match kind:
		&"body":
			var c := CylinderMesh.new()
			c.top_radius = 0.035
			c.bottom_radius = 0.035
			c.height = 0.2
			c.radial_segments = 10
			c.rings = 1
			m.albedo_color = CREAM
			m.emission_enabled = true
			m.emission = CREAM
			m.emission_energy_multiplier = 0.4
			mesh = c
		&"nose":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.036
			c.height = 0.09
			c.radial_segments = 10
			c.rings = 1
			m.albedo_color = Color(0.91, 0.247, 0.247)
			m.emission_enabled = true
			m.emission = Color(0.91, 0.247, 0.247)
			m.emission_energy_multiplier = 0.5
			mesh = c
		_:
			var s := SphereMesh.new()
			s.radius = 0.04
			s.height = 0.16
			s.radial_segments = 10
			s.rings = 5
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			m.albedo_color = Color(FLAME, 0.7)
			mesh = s
	# The meshes stand along Y: lay them along -Z.
	var turned := ArrayMesh.new()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var lay := Basis(Vector3.RIGHT, -PI * 0.5)
	for i in verts.size():
		verts[i] = lay * verts[i]
		norms[i] = lay * norms[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TANGENT] = null
	turned.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	turned.surface_set_material(0, m)
	mesh = turned
	_meshes[kind] = mesh
	return mesh


func _draw_trail(cam: Camera3D, hidden: bool) -> void:
	if _history.is_empty() or hidden:
		_history.resize(TRAIL)
		_history.fill(_drawn)
		_laid.resize(TRAIL)
		_laid.fill(_flown)
	for i in range(TRAIL - 1, 0, -1):
		_history[i] = _history[i - 1]
		_laid[i] = _laid[i - 1]
	_history[0] = _drawn
	_laid[0] = _flown
	_trail_mesh.clear_surfaces()
	if cam == null or hidden:
		return
	_build_coil()
	var color := TEAL if _seeker else FLAME
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _smoke_material())
	_strip(cam.global_position, _coil.size(), color.lerp(CREAM, 0.3), true)
	_trail_mesh.surface_end()
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, WeaponFx.ribbon_material())
	_strip(cam.global_position, GLOW_POINTS * SPIRAL_STEPS, color, false)
	_trail_mesh.surface_end()


## Lays the smoke coil round the history: SPIRAL_STEPS points per frame of
## track, each turned by the distance flown, opening out from the nozzle.
func _build_coil() -> void:
	var count := (TRAIL - 1) * SPIRAL_STEPS + 1
	_coil.resize(count)
	_coil_d.resize(count)
	_coil_out.resize(count)
	for n in count:
		var i := mini(n / SPIRAL_STEPS, TRAIL - 2)
		var t := float(n - i * SPIRAL_STEPS) / SPIRAL_STEPS
		var a := _history[i]
		var b := _history[i + 1]
		var along := (a - b).normalized() if a.distance_squared_to(b) > 0.000001 else velocity.normalized()
		var side := along.cross(Vector3.UP)
		side = side.normalized() if side.length_squared() > 0.0025 else Vector3.RIGHT
		var up := side.cross(along).normalized()
		var d := lerpf(_laid[i], _laid[i + 1], t)
		var turn := d * SPIRAL_TWIST * _cork_side + _slot
		var out := side * cos(turn) + up * sin(turn)
		var f := float(n) / float(count - 1)
		_coil[n] = a.lerp(b, t) + out * lerpf(SPIRAL_RADIUS.x, SPIRAL_RADIUS.y, sqrt(f))
		_coil_d[n] = d
		_coil_out[n] = out


## A camera-facing strip through the first `count` coil points: the smoke
## (widening, fading, twist-shaded) or the nozzle glow (narrowing to the tail).
func _strip(eye: Vector3, count: int, color: Color, smoke: bool) -> void:
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_c := Color()
	for i in count:
		var p := _coil[i]
		var f := float(i) / float(count - 1)
		var tangent := (_coil[mini(i + 1, count - 1)] - _coil[maxi(i - 1, 0)]).normalized()
		var to_eye := (eye - p).normalized()
		var width := lerpf(SMOKE_WIDTH.x, SMOKE_WIDTH.y, f) if smoke else GLOW_WIDTH * (1.0 - f)
		var side := tangent.cross(to_eye).normalized() * width * 0.5
		var c := color
		if smoke:
			var shade := 1.0 + SMOKE_TWIST * _coil_out[i].dot(to_eye)
			c = Color(color.r * shade, color.g * shade, color.b * shade, SMOKE_ALPHA * pow(1.0 - f, 1.4))
		else:
			c.a = 0.8 * (1.0 - f)
		var l := p - side
		var r := p + side
		if i > 0:
			_vert(prev_l, _coil_d[i - 1], 0.0, prev_c)
			_vert(prev_r, _coil_d[i - 1], 1.0, prev_c)
			_vert(r, _coil_d[i], 1.0, c)
			_vert(prev_l, _coil_d[i - 1], 0.0, prev_c)
			_vert(r, _coil_d[i], 1.0, c)
			_vert(l, _coil_d[i], 0.0, c)
		prev_l = l
		prev_r = r
		prev_c = c


func _vert(at: Vector3, u: float, v: float, color: Color) -> void:
	_trail_mesh.surface_set_color(color)
	_trail_mesh.surface_set_uv(Vector2(u, v))
	_trail_mesh.surface_add_vertex(at)


static func _smoke_material() -> ShaderMaterial:
	if _smoke_mat == null:
		_smoke_mat = ShaderMaterial.new()
		_smoke_mat.shader = load(SMOKE_SHADER)
	return _smoke_mat
