class_name TwisterVortex
extends Node3D
## Teacup Twister's shell. It flies as a lobbed, spinning teacup (gravity and
## loft from the WeaponData, so the aim arc preview shows where it lands) and
## opens a whirl where it comes down: on the floor under a wall or zombie it
## struck, or where its fuse ran out.
##
## The whirl spins for WHIRL_TIME. Zombies within PULL_RADIUS are caught: a
## Hold behaviour (EnemyBehaviour.on_physics) takes over their movement and
## drags them along a spiral into the cup, so they cannot attack while they
## spin; the catch knocks them out of any windup. Pull and swirl speed fall
## with the zombie's weight (1 / sqrt(mass)). The whirl holds the crowd, not
## the big hitters: zombies from CAPTURE_MASS up (Bruisers, Riot Shields,
## Yetis, alphas) and bosses are never caught, it only drags at their feet
## (HEAVY_DRAG) while they keep swinging. A cup that lands on one of them
## (within CUP_RADIUS) latches on and rides with it, so a big target cannot
## simply walk out of the cup before it pops. A zombie flung out by a pop
## cannot be caught again for FREE_TIME, so chained cups cannot hold a crowd
## for good. Zombies inside CUP_RADIUS take WHIRL_TICK_DAMAGE every WHIRL_TICK, quietly like a burn (only the finishing tick is a full
## hit). Then the cup pops: the weapon's splash (damage, splash_radius,
## splash_push) through WeaponController.projectile_detonated, hurling the
## bunched-up crowd outward. tools/balance_report.py reads these constants.

const MASK_WORLD := 1
const MASK_ENEMIES := 4
## Seconds the whirl spins before it pops.
const WHIRL_TIME := 1.8
## Zombies within this radius (m, flat) are dragged in.
const PULL_RADIUS := 7.0
## Spiral speeds (m/s) on a 1-mass zombie: inward, and round the cup.
const PULL_SPEED := 4.4
const SWIRL_SPEED := 3.0
## Zombies this close to the centre stop moving inward and just spin.
const CORE := 0.7
## Zombies inside this radius take whirl damage.
const CUP_RADIUS := 2.3
const WHIRL_TICK := 0.3
const WHIRL_TICK_DAMAGE := 16.0
## Zombies this heavy or heavier (the Bruiser class, 2.6+), and bosses, are not
## caught, only slowed.
const CAPTURE_MASS := 2.5
const HEAVY_DRAG := 0.5
## Seconds a zombie flung out by a pop cannot be caught by another whirl:
## longer than a whirl, so back-to-back cups free a crowd at least as long as
## they held it.
const FREE_TIME := 2.0
## Height (m) above or below the centre a zombie may stand and still be caught.
const REACH_UP := 2.5
const SPIRAL_ARMS := 3
const SPIRAL_POINTS := 18
const TRAIL := 9
const WHIRL_SOUND := &"gn8_twister_whirl"
const CUP_COLORS: Array[Color] = [Color(1.0, 0.42, 0.78), Color(0.35, 0.92, 1.0), Color(1.0, 0.86, 0.3)]

var weapon: WeaponData
var controller: WeaponController
var velocity := Vector3.ZERO
var _fuse := 0.0
var _open := false
var _age := 0.0
var _tick := WHIRL_TICK
var _centre := Vector3.ZERO
## The heavy or boss the cup latched onto (null when it sits on the floor).
var _rider: Zombie
var _held := {}            # zombie instance id -> Hold
var _exclude: Array[RID] = []
var _cup: Node3D
var _shell: Node3D
var _trail: MultiMeshInstance3D
var _history: Array[Vector3] = []
var _spiral: MeshInstance3D
var _im: ImmediateMesh
var _confetti := 0.0

static var _mats := {}
## Zombie instance id -> msec until which no whirl may catch it again.
static var _free_until := {}
static var _cup_mesh: CylinderMesh
static var _saucer_mesh: CylinderMesh
static var _rim_mesh: TorusMesh
static var _dot_mesh: SphereMesh


## Movement of one caught zombie: a spiral into the whirl's centre.
class Hold extends EnemyBehaviour:
	var vortex: TwisterVortex

	func on_physics(z: Zombie, delta: float) -> bool:
		if not is_instance_valid(vortex):
			return false
		z.move_with(vortex.spiral_velocity(z))
		z.face_toward(vortex.spiral_velocity(z), delta)
		return true


## Fires a shell of `w` from `from` with launch velocity `vel`.
static func launch(owner_controller: WeaponController, from: Vector3, vel: Vector3, w: WeaponData) -> void:
	var level := owner_controller.player.get_parent()
	if level == null:
		return
	var v := TwisterVortex.new()
	v.weapon = w
	v.controller = owner_controller
	v.velocity = vel
	v._exclude = [owner_controller.player.get_rid()]
	level.add_child(v)
	v.global_position = from
	v._update_trail()


func _ready() -> void:
	_fuse = weapon.projectile_fuse
	_build_meshes()
	_shell = _teacup(weapon.projectile_size * 2.2)
	add_child(_shell)
	_trail = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _dot_mesh
	mm.instance_count = TRAIL
	_trail.multimesh = mm
	_trail.material_override = _glow(CUP_COLORS[0], 0.55)
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)


func _physics_process(delta: float) -> void:
	if _open:
		_whirl(delta)
	else:
		_fly(delta)


func _process(delta: float) -> void:
	if not _open:
		_shell.rotate_object_local(Vector3.UP, 14.0 * delta)
		return
	var k := clampf(_age / WHIRL_TIME, 0.0, 1.0)
	_cup.rotate_y((4.0 + 10.0 * k) * delta)
	var grow := minf(1.0, _age / 0.18)
	_cup.scale = Vector3.ONE * (ease(grow, 0.4) * (1.0 + 0.12 * sin(_age * 22.0) * k))
	_draw_spiral(k)
	_confetti -= delta
	if _confetti <= 0.0:
		_confetti = 0.07
		var a := randf() * TAU
		var at := _centre + Vector3(cos(a), 0.0, sin(a)) * randf_range(1.0, PULL_RADIUS * 0.7) + Vector3.UP * randf_range(0.2, 1.6)
		var swirl := Vector3(-sin(a), 0.4, cos(a))
		WeaponFx.burst(get_parent(), at, swirl, CUP_COLORS, 3, 4.0, 0.5, 0.05, 30.0, Vector3(0, -2.0, 0))


# --- flight ----------------------------------------------------------------------

func _fly(delta: float) -> void:
	_fuse -= delta
	if _fuse <= 0.0:
		_open_at(global_position)
		return
	velocity.y -= weapon.projectile_gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD | MASK_ENEMIES)
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		var near := _zombie_near(to)
		if near:
			_open_at(to)
			return
		global_position = to
		_update_trail()
		return
	_open_at(Vector3(hit["position"]) + Vector3(hit["normal"]) * 0.1)


## Proximity: a shell that skims past a zombie opens on it.
func _zombie_near(at: Vector3) -> Zombie:
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var base := z.global_position
		if at.y < base.y - 0.1 or at.y > base.y + 1.8 * z.data.body_scale:
			continue
		if Vector2(at.x - base.x, at.z - base.z).length() <= 0.55 * z.data.body_scale:
			return z
	return null


func _update_trail() -> void:
	_history.push_front(global_position)
	if _history.size() > TRAIL:
		_history.pop_back()
	var mm := _trail.multimesh
	for i in TRAIL:
		var p: Vector3 = _history[mini(i, _history.size() - 1)]
		var s := weapon.projectile_size * (1.0 - float(i) / TRAIL) * 0.9
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p))


## Opens the whirl on the floor below `at` (or at `at` when there is none close).
func _open_at(at: Vector3) -> void:
	_open = true
	var ground := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at + Vector3.DOWN * 4.0, MASK_WORLD))
	_centre = Vector3(ground["position"]) + Vector3.UP * 0.04 if not ground.is_empty() else at
	global_position = _centre
	_shell.visible = false
	_trail.visible = false
	_cup = _whirl_cup()
	add_child(_cup)
	_spiral = MeshInstance3D.new()
	_im = ImmediateMesh.new()
	_spiral.mesh = _im
	_spiral.top_level = true
	_spiral.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spiral)
	_spiral.global_transform = Transform3D.IDENTITY
	WeaponFx.flash(get_parent(), _centre + Vector3.UP * 0.5, CUP_COLORS[0], 1.4, 0.2)
	WeaponFx.shockwave(get_parent(), _centre + Vector3.UP * 0.2, CUP_COLORS[1], PULL_RADIUS * 0.6)
	Sfx.play_at(WHIRL_SOUND, _centre + Vector3.UP, 0.0, randf_range(0.97, 1.03), 14.0)
	_rider = _latch_target()


## The nearest uncatchable zombie (heavy or boss) within CUP_RADIUS of the
## landing point, which the cup then rides on.
func _latch_target() -> Zombie:
	var best: Zombie = null
	var best_d := CUP_RADIUS
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead() or (z.data.mass < CAPTURE_MASS and z.rank != Zombie.RANK_BOSS):
			continue
		var d := Vector2(z.global_position.x - _centre.x, z.global_position.z - _centre.z).length()
		if d <= best_d and absf(z.global_position.y - _centre.y) <= REACH_UP:
			best = z
			best_d = d
	return best


# --- the whirl -------------------------------------------------------------------

func _whirl(delta: float) -> void:
	_age += delta
	if is_instance_valid(_rider) and not _rider.is_dead():
		_centre.x = _rider.global_position.x
		_centre.z = _rider.global_position.z
		global_position = _centre
	_tick -= delta
	var tick := _tick <= 0.0
	if tick:
		_tick += WHIRL_TICK
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var flat := Vector2(z.global_position.x - _centre.x, z.global_position.z - _centre.z).length()
		var caught := flat <= PULL_RADIUS and absf(z.global_position.y - _centre.y) <= REACH_UP
		if not caught:
			_release(z)
			continue
		if _capturable(z):
			_hold(z)
		elif not _held.has(z.get_instance_id()):
			z.speed_multiplier *= HEAVY_DRAG
		if tick and flat <= CUP_RADIUS:
			_spin_damage(z)
	if _age >= WHIRL_TIME:
		_pop()


func _capturable(z: Zombie) -> bool:
	if z.data.mass >= CAPTURE_MASS or z.rank == Zombie.RANK_BOSS:
		return false
	var key := z.get_instance_id()
	if _held.has(key):
		return true
	if int(_free_until.get(key, 0)) > Time.get_ticks_msec():
		return false
	# One whirl at a time: a zombie another cup holds stays with it.
	for b in z.behaviours:
		if b is Hold and is_instance_valid((b as Hold).vortex):
			return false
	return true


func _hold(z: Zombie) -> void:
	var key := z.get_instance_id()
	if _held.has(key):
		return
	var h := Hold.new()
	h.vortex = self
	z.behaviours.append(h)
	_held[key] = [z, h]
	z.interrupt()


func _release(z: Zombie) -> void:
	var key := z.get_instance_id()
	if not _held.has(key):
		return
	var entry: Array = _held[key]
	z.behaviours.erase(entry[1])
	_held.erase(key)


## Lets go of every caught zombie; each is free of whirls for FREE_TIME.
func _release_all() -> void:
	var until := Time.get_ticks_msec() + int(FREE_TIME * 1000.0)
	for key in _held.keys():
		var entry: Array = _held[key]
		if not is_instance_valid(entry[0]):
			continue
		var z: Zombie = entry[0]
		z.behaviours.erase(entry[1])
		_free_until[key] = until
	_held.clear()
	if _free_until.size() > 64:
		var now := Time.get_ticks_msec()
		for key in _free_until.keys():
			if int(_free_until[key]) < now:
				_free_until.erase(key)


## Where a caught zombie is dragged this frame: in along a spiral, faster
## round the cup the closer it gets, slower the heavier it is.
func spiral_velocity(z: Zombie) -> Vector3:
	var to := Vector3(_centre.x - z.global_position.x, 0.0, _centre.z - z.global_position.z)
	var d := to.length()
	if d < 0.01:
		return Vector3.ZERO
	var inward := to / d
	var around := Vector3(-inward.z, 0.0, inward.x)
	var weight := 1.0 / sqrt(maxf(0.5, z.data.mass))
	var pull := PULL_SPEED * clampf((d - CORE) / 1.5, 0.0, 1.0)
	var swirl := SWIRL_SPEED * lerpf(1.3, 0.6, clampf(d / PULL_RADIUS, 0.0, 1.0))
	return (inward * pull + around * swirl) * weight


## A whirl tick: taken like a burn (no flinch or hit sound per tick); the
## tick that finishes the zombie is a real hit, so the kill is credited.
func _spin_damage(z: Zombie) -> void:
	var dmg := WHIRL_TICK_DAMAGE * Soak.damage_scale(z) * StatusEffects.damage_scale(z)
	if is_instance_valid(controller):
		dmg *= controller.damage_multiplier
	if dmg < z.health:
		z.health -= dmg
		return
	var chest := z.global_position + Vector3.UP * z.data.body_scale
	z.take_hit(dmg, chest, (chest - _centre).normalized(), weapon.id, false, 2.0)


func _pop() -> void:
	set_physics_process(false)
	set_process(false)
	_release_all()
	var at := _centre + Vector3.UP * 0.6
	ImpactMarks.blast(get_parent(), at, weapon, {})
	if is_instance_valid(controller):
		controller.projectile_detonated(weapon, at, null, Vector3.UP)
	else:
		WeaponFx.explosion(get_parent(), at, weapon.tracer_color, weapon.splash_radius)
	WeaponFx.burst(get_parent(), at, Vector3.UP, CUP_COLORS, 40, 8.0, 1.0, 0.1, 90.0, Vector3(0, -7.0, 0))
	queue_free()


func _exit_tree() -> void:
	_release_all()


# --- looks -----------------------------------------------------------------------

## Three glowing spiral arms winding down into the cup, turning with the whirl.
func _draw_spiral(k: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam else _centre + Vector3(0, 2, 4)
	var spin := _age * (5.0 + 6.0 * k)
	var fade := 1.0 - clampf((_age - WHIRL_TIME + 0.15) / 0.15, 0.0, 1.0)
	WeaponFx.begin_ribbons(_im, WeaponFx.ribbon_material(2.0, 0.0))
	for arm in SPIRAL_ARMS:
		var pts := PackedVector3Array()
		for i in SPIRAL_POINTS:
			var u := float(i) / (SPIRAL_POINTS - 1)
			var a := spin + TAU * arm / SPIRAL_ARMS + u * 4.2
			var r := lerpf(PULL_RADIUS * 0.85, 0.35, u)
			pts.append(_centre + Vector3(cos(a) * r, 0.15 + u * u * 2.0, sin(a) * r))
		var c := CUP_COLORS[arm % CUP_COLORS.size()]
		WeaponFx.add_ribbon(_im, pts, 0.28, Color(c, 0.35 * fade), eye)
		WeaponFx.add_ribbon(_im, pts, 0.1, Color(c.lerp(Color.WHITE, 0.5), 0.9 * fade), eye)
	WeaponFx.end_ribbons(_im)


## The spinning cup of light the whirl stands in: saucer, cup and a gold rim.
func _whirl_cup() -> Node3D:
	var root := Node3D.new()
	var saucer := MeshInstance3D.new()
	saucer.mesh = _saucer_mesh
	saucer.material_override = _glow(CUP_COLORS[1], 0.14)
	saucer.scale = Vector3(CUP_RADIUS + 0.5, 1.0, CUP_RADIUS + 0.5)
	root.add_child(saucer)
	var cup := MeshInstance3D.new()
	cup.mesh = _cup_mesh
	cup.material_override = _glow(CUP_COLORS[0], 0.12)
	cup.scale = Vector3(CUP_RADIUS, 0.9, CUP_RADIUS)
	cup.position.y = 0.45
	root.add_child(cup)
	var rim := MeshInstance3D.new()
	rim.mesh = _rim_mesh
	rim.material_override = _glow(CUP_COLORS[2], 0.4)
	rim.scale = Vector3.ONE * CUP_RADIUS
	rim.position.y = 0.9
	root.add_child(rim)
	for c in root.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.scale = Vector3.ONE * 0.01
	return root


## The flying shell: a little pink teacup on its saucer.
func _teacup(size: float) -> Node3D:
	var root := Node3D.new()
	var cup := MeshInstance3D.new()
	cup.mesh = _cup_mesh
	cup.material_override = _solid(CUP_COLORS[0])
	cup.scale = Vector3(size, size * 1.2, size)
	cup.position.y = size * 0.5
	root.add_child(cup)
	var saucer := MeshInstance3D.new()
	saucer.mesh = _saucer_mesh
	saucer.material_override = _solid(Color(1.0, 0.95, 0.85))
	saucer.scale = Vector3(size * 1.5, 1.0, size * 1.5)
	root.add_child(saucer)
	var rim := MeshInstance3D.new()
	rim.mesh = _rim_mesh
	rim.material_override = _glow(CUP_COLORS[2], 0.9)
	rim.scale = Vector3.ONE * size
	rim.position.y = size * 1.15
	root.add_child(rim)
	for c in root.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func _build_meshes() -> void:
	if _cup_mesh:
		return
	_cup_mesh = CylinderMesh.new()
	_cup_mesh.top_radius = 1.0
	_cup_mesh.bottom_radius = 0.62
	_cup_mesh.height = 1.0
	_cup_mesh.radial_segments = 20
	_cup_mesh.rings = 1
	_cup_mesh.cap_top = false
	_saucer_mesh = CylinderMesh.new()
	_saucer_mesh.top_radius = 1.0
	_saucer_mesh.bottom_radius = 0.8
	_saucer_mesh.height = 0.06
	_saucer_mesh.radial_segments = 24
	_saucer_mesh.rings = 1
	_rim_mesh = TorusMesh.new()
	_rim_mesh.inner_radius = 0.95
	_rim_mesh.outer_radius = 1.05
	_rim_mesh.rings = 24
	_rim_mesh.ring_segments = 6
	_dot_mesh = SphereMesh.new()
	_dot_mesh.radius = 1.0
	_dot_mesh.height = 2.0
	_dot_mesh.radial_segments = 8
	_dot_mesh.rings = 4


static func _glow(c: Color, alpha: float) -> StandardMaterial3D:
	var key := "g%s%.2f" % [c.to_html(), alpha]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(c, alpha)
		_mats[key] = m
	return _mats[key]


static func _solid(c: Color) -> StandardMaterial3D:
	var key := "s" + c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.8
		m.roughness = 0.3
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]
