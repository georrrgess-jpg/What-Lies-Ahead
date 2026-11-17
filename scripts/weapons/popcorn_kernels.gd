class_name PopcornKernels
extends Node3D
## Every Popcorn Popper kernel in flight, flown and drawn by one node per
## level (made on the first shot): raw kernels, popped popcorn and their
## short trails are three MultiMeshes, so ten shots a second make no nodes.
##
## A kernel flies fast with a little drop and strikes the first zombie it
## touches like a ray shot (WeaponController.strike: headshots, falloff,
## confirms); skimming a zombie counts. Its landing depends on the stage it
## was fired in (PopcornPopperMode.Stage):
##   cold  a kernel: the hit and a few husk flakes
##   warm  pops into popcorn after POP_DISTANCE (a puff of flakes and a soft
##         pop) and lands in a small puff: PUFF_DAMAGE to every other zombie
##         within PUFF_RADIUS
##   hot   leaves the muzzle popped and buttered, bigger, and bursts:
##         BURST_DAMAGE to every other zombie within BURST_RADIUS, and the
##         struck zombie and all it splashes are buttered (PopcornButter)
## Splash falls off to SPLASH_EDGE at the rim and scenery shields zombies
## behind it. tools/balance_report.py reads these constants.

const NODE_NAME := "PopcornKernels"
const MAX := 40
const TRAIL := 3
## Drop (m/s²).
const GRAVITY := 3.0
## Touching distance to a zombie's body (m), on top of the kernel's size.
const REACH := 0.14
const POP_DISTANCE := 4.0
const PUFF_RADIUS := 1.5
const PUFF_DAMAGE := 10.0
const BURST_RADIUS := 2.5
const BURST_DAMAGE := 15.0
const SPLASH_EDGE := 0.45
## Radius per stage: a kernel, warm popcorn, hot buttered popcorn (m).
const SIZES: Array[float] = [0.03, 0.055, 0.072]
## Metres over which a shot swells to full size after the muzzle.
const GROW_DISTANCE := 1.5
## Seconds of the squash-and-stretch as a kernel pops.
const POP_TIME := 0.12
const KERNEL_TOP := Color(1.0, 0.84, 0.3)
const KERNEL_TIP := Color(0.78, 0.38, 0.12)
const POPPED_TOP := Color(1.0, 0.99, 0.93)
const POPPED_SHADE := Color(0.95, 0.82, 0.6)
const BUTTER_TINT := Color(1.0, 0.86, 0.36)
const TRAIL_COLORS: Array[Color] = [Color(1.0, 0.72, 0.25, 0.5), Color(1.0, 0.95, 0.8, 0.5), Color(1.0, 0.75, 0.2, 0.8)]
const FLAKES := [Color(1.0, 0.98, 0.9), Color(1.0, 0.93, 0.7), Color(1.0, 0.82, 0.38)]
const HUSKS := [Color(1.0, 0.8, 0.3), Color(0.8, 0.45, 0.15), Color(1.0, 0.95, 0.75)]
const BUTTER := [Color(1.0, 0.85, 0.3), Color(1.0, 0.96, 0.62), Color(1.0, 0.66, 0.16), Color(1.0, 1.0, 0.92)]
const POP_SOUND := &"pcp_pop"
const PUFF_SOUND := &"pcp_puff"
const BUTTER_SOUND := &"pcp_butter"

static var _kernel_mesh: ArrayMesh
static var _popcorn_mesh: ArrayMesh
static var _trail_mesh: SphereMesh
static var _solid_mat: StandardMaterial3D
static var _trail_mat: StandardMaterial3D

var controller: WeaponController
var weapon: WeaponData
var _n := 0
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _last := PackedVector3Array()
var _stage := PackedInt32Array()
var _popped := PackedFloat32Array()
var _travel := PackedFloat32Array()
var _scale := PackedFloat32Array()
var _fuse := PackedFloat32Array()
var _turn := PackedFloat32Array()
var _kernels: MultiMeshInstance3D
var _popcorn: MultiMeshInstance3D
var _trail: MultiMeshInstance3D
var _query := PhysicsRayQueryParameters3D.new()
var _zombies: Array[Node] = []


## Fires a kernel of `w` from `from` along `dir` (damage scale `scale`) in
## heat stage `stage`.
static func fire(owner_controller: WeaponController, from: Vector3, dir: Vector3, w: WeaponData, scale: float, stage: int) -> void:
	var level := owner_controller.player.get_parent()
	if level == null:
		return
	var flight := level.get_node_or_null(NODE_NAME) as PopcornKernels
	if flight == null:
		flight = PopcornKernels.new()
		flight.name = NODE_NAME
		level.add_child(flight)
	flight.controller = owner_controller
	flight.weapon = w
	flight._add(from, dir * w.projectile_speed, stage, scale)


func _ready() -> void:
	_build_shared()
	# Packed arrays are values: each is sized in place.
	_pos.resize(MAX)
	_vel.resize(MAX)
	_last.resize(MAX)
	_popped.resize(MAX)
	_travel.resize(MAX)
	_scale.resize(MAX)
	_fuse.resize(MAX)
	_turn.resize(MAX)
	_stage.resize(MAX)
	_kernels = _multimesh(_kernel_mesh, _solid_mat, MAX)
	_popcorn = _multimesh(_popcorn_mesh, _solid_mat, MAX)
	_trail = _multimesh(_trail_mesh, _trail_mat, MAX * TRAIL)
	_query.collision_mask = WeaponController.MASK_WORLD | WeaponController.MASK_ENEMIES
	set_physics_process(false)


func _add(from: Vector3, velocity: Vector3, stage: int, scale: float) -> void:
	if _n >= MAX:
		_remove(0)
	var i := _n
	_n += 1
	_pos[i] = from
	_last[i] = from
	_vel[i] = velocity
	_stage[i] = stage
	# Hot kernels pop at the muzzle; warm ones on the way.
	_popped[i] = 0.0 if stage == PopcornPopperMode.Stage.HOT else -1.0
	_travel[i] = 0.0
	_scale[i] = scale
	_fuse[i] = weapon.projectile_fuse
	_turn[i] = randf() * TAU
	_query.exclude = [controller.player.get_rid()]
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _n == 0 or not is_instance_valid(controller):
		_n = 0
		_draw_all()
		set_physics_process(false)
		return
	_zombies = get_tree().get_nodes_in_group("zombies")
	var space := get_world_3d().direct_space_state
	var i := 0
	while i < _n:
		if _step(i, delta, space):
			i += 1
	_draw_all()


## Moves kernel `i` one frame. Returns false when it landed (it was removed).
func _step(i: int, delta: float, space: PhysicsDirectSpaceState3D) -> bool:
	_fuse[i] -= delta
	if _fuse[i] <= 0.0:
		_remove(i)
		return false
	if _popped[i] >= 0.0:
		_popped[i] += delta
	elif _stage[i] == PopcornPopperMode.Stage.WARM and _travel[i] >= POP_DISTANCE:
		_pop_in_flight(i)
	var v := _vel[i]
	v.y -= GRAVITY * delta
	_vel[i] = v
	var from := _pos[i]
	var to := from + v * delta
	var near := _zombie_near(to, _size(i))
	if near:
		_land(i, to, -v.normalized(), near)
		return false
	_query.from = from
	_query.to = to
	var hit := space.intersect_ray(_query)
	if hit.is_empty():
		_travel[i] += from.distance_to(to)
		_last[i] = from
		_pos[i] = to
		return true
	var at: Vector3 = hit["position"]
	_travel[i] += from.distance_to(at)
	var collider: Object = hit["collider"]
	if collider is Zombie and not (collider as Zombie).is_dead():
		_land(i, at, hit["normal"], collider)
	else:
		ImpactMarks.shot(get_parent(), hit, v.normalized(), weapon)
		_land(i, at, hit["normal"], null)
	return false


## A warm kernel pops on the way: a puff of flakes and a soft pop.
func _pop_in_flight(i: int) -> void:
	_popped[i] = 0.0
	WeaponFx.burst(get_parent(), _pos[i], _vel[i].normalized(), FLAKES, 3, 1.6, 0.22, 0.016, 120.0)
	Sfx.play_at(POP_SOUND, _pos[i], -12.0, randf_range(0.85, 1.2), 10.0)


## Proximity: a kernel that skims a zombie still hits it.
func _zombie_near(at: Vector3, size: float) -> Zombie:
	var reach := size + REACH
	for node in _zombies:
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var base := z.global_position
		if at.y < base.y or at.y > base.y + 1.85 * z.data.body_scale:
			continue
		if Vector2(at.x - base.x, at.z - base.z).length() <= (0.3 + reach) * z.data.body_scale:
			return z
	return null


## Kernel `i` lands at `at` (on `struck`, if any): the hit, then its stage's splash.
func _land(i: int, at: Vector3, normal: Vector3, struck: Zombie) -> void:
	var dir := _vel[i].normalized()
	var stage := _stage[i]
	var scale := _scale[i]
	var travel := _travel[i]
	var level := get_parent()
	_remove(i)
	if struck:
		controller.strike(weapon, struck, at, dir, travel, scale)
	match stage:
		PopcornPopperMode.Stage.COLD:
			WeaponFx.burst(level, at, normal, HUSKS, 4, 1.8, 0.25, 0.014, 80.0)
		PopcornPopperMode.Stage.WARM:
			WeaponFx.burst(level, at, normal, FLAKES, 8, 2.6, 0.4, 0.024, 90.0)
			WeaponFx.flash(level, at, POPPED_TOP, PUFF_RADIUS * 0.45, 0.12)
			Sfx.play_at(PUFF_SOUND, at, -8.0, randf_range(0.9, 1.12), 14.0)
			_splash(at, PUFF_RADIUS, PUFF_DAMAGE * scale, struck, false)
		PopcornPopperMode.Stage.HOT:
			WeaponFx.burst(level, at, normal, BUTTER, 14, 3.6, 0.5, 0.03, 100.0)
			WeaponFx.burst(level, at, Vector3.UP, FLAKES, 6, 2.4, 0.45, 0.026, 70.0)
			WeaponFx.flash(level, at, BUTTER_TINT, BURST_RADIUS * 0.5, 0.18)
			Sfx.play_at(BUTTER_SOUND, at, -5.0, randf_range(0.92, 1.08), 16.0)
			if struck and not struck.is_dead():
				PopcornButter.of(struck).butter()
			_splash(at, BURST_RADIUS, BURST_DAMAGE * scale, struck, true)


## Splash damage to every zombie within `radius` of `at` but `struck`,
## falling off to SPLASH_EDGE at the rim; scenery shields those behind it.
func _splash(at: Vector3, radius: float, dmg: float, struck: Zombie, butter: bool) -> void:
	var space := get_world_3d().direct_space_state
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z == struck or z.is_dead():
			continue
		var chest := z.global_position + Vector3.UP * 1.05 * z.data.body_scale
		var d := minf(at.distance_to(chest), at.distance_to(z.global_position + Vector3.UP * 0.4))
		if d > radius:
			continue
		var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.15, chest, WeaponController.MASK_WORLD)
		if not space.intersect_ray(q).is_empty():
			continue
		var away := z.global_position - at
		away.y = 0.0
		away = away.normalized() if away.length() > 0.05 else Vector3.FORWARD
		controller.ring_hit(weapon, z, chest - away * 0.3, away, dmg * lerpf(1.0, SPLASH_EDGE, d / radius), false)
		if butter and not z.is_dead():
			PopcornButter.of(z).butter()


func _remove(i: int) -> void:
	_n -= 1
	if i == _n:
		return
	_pos[i] = _pos[_n]
	_vel[i] = _vel[_n]
	_last[i] = _last[_n]
	_stage[i] = _stage[_n]
	_popped[i] = _popped[_n]
	_travel[i] = _travel[_n]
	_scale[i] = _scale[_n]
	_fuse[i] = _fuse[_n]
	_turn[i] = _turn[_n]


## Visual radius of kernel `i`: its stage's size, swelling out of the muzzle,
## with a squash-and-stretch as it pops.
func _size(i: int) -> float:
	var popped := _popped[i] >= 0.0
	var base: float = SIZES[_stage[i]] if popped else SIZES[0]
	var grow := clampf(_travel[i] / GROW_DISTANCE, 0.3, 1.0)
	if popped and _popped[i] < POP_TIME:
		var u := _popped[i] / POP_TIME
		grow *= lerpf(0.5, 1.0, u) + 0.35 * sin(PI * u)
	return base * grow


func _draw_all() -> void:
	var kernels := _kernels.multimesh
	var popcorn := _popcorn.multimesh
	var trail := _trail.multimesh
	var nk := 0
	var np := 0
	for i in _n:
		var s := _size(i)
		var dir := _vel[i].normalized()
		var spin := Basis(dir, _turn[i] + _travel[i] * 2.0) * Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
		var xf := Transform3D(spin.scaled(Vector3.ONE * s), _pos[i])
		if _popped[i] >= 0.0:
			popcorn.set_instance_transform(np, xf)
			popcorn.set_instance_color(np, BUTTER_TINT if _stage[i] == PopcornPopperMode.Stage.HOT else Color.WHITE)
			np += 1
		else:
			kernels.set_instance_transform(nk, xf)
			kernels.set_instance_color(nk, Color.WHITE)
			nk += 1
		var tail := _last[i] - _pos[i]
		var col: Color = TRAIL_COLORS[_stage[i] if _popped[i] >= 0.0 else 0]
		for t in TRAIL:
			var k := float(t + 1) / (TRAIL + 1)
			trail.set_instance_transform(i * TRAIL + t, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s * (0.8 - k * 0.5)), _pos[i] + tail * k * 1.6))
			trail.set_instance_color(i * TRAIL + t, col)
	kernels.visible_instance_count = nk
	popcorn.visible_instance_count = np
	trail.visible_instance_count = _n * TRAIL


func _multimesh(mesh: Mesh, material: Material, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Kernels fly anywhere in the level: never culled by the node's own bounds.
	mmi.custom_aabb = AABB(Vector3(-500, -100, -500), Vector3(1000, 400, 1000))
	add_child(mmi)
	return mmi


## The kernel, the popcorn and the trail droplet, made on first use.
static func _build_shared() -> void:
	if _kernel_mesh:
		return
	# A teardrop kernel, its tip pointing back along the flight.
	_kernel_mesh = _lumps([[Vector3.ZERO, 1.0, Vector3(0.8, 0.8, 1.15)]], KERNEL_TOP, KERNEL_TIP, true)
	# A popped kernel: a fluffy cluster of lobes.
	_popcorn_mesh = _lumps([[Vector3.ZERO, 0.75, Vector3.ONE], [Vector3(0.55, 0.3, 0.1), 0.55, Vector3.ONE],
		[Vector3(-0.5, 0.35, -0.15), 0.6, Vector3.ONE], [Vector3(0.05, -0.45, 0.35), 0.55, Vector3.ONE],
		[Vector3(0.1, 0.2, -0.6), 0.5, Vector3.ONE], [Vector3(-0.2, -0.3, -0.35), 0.45, Vector3.ONE]], POPPED_TOP, POPPED_SHADE, false)
	_trail_mesh = SphereMesh.new()
	_trail_mesh.radius = 1.0
	_trail_mesh.height = 2.0
	_trail_mesh.radial_segments = 8
	_trail_mesh.rings = 4
	_solid_mat = StandardMaterial3D.new()
	_solid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_solid_mat.vertex_color_use_as_albedo = true
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.vertex_color_use_as_albedo = true
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD


## A mesh of sphere lobes [centre, radius, stretch], shaded in its vertex
## colours from `light` on top to `dark` below (or toward -Z: a kernel's tip).
static func _lumps(lobes: Array, light: Color, dark: Color, along_z: bool) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	var src := sphere.get_mesh_arrays()
	var src_v: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var src_n: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var src_i: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	for lobe: Array in lobes:
		var centre: Vector3 = lobe[0]
		var r: float = lobe[1]
		var stretch: Vector3 = lobe[2]
		var base := verts.size()
		for k in src_v.size():
			var p := src_v[k] * stretch * r + centre
			verts.append(p)
			normals.append(src_n[k])
			var shade := (-p.z / stretch.z * 0.5 + 0.5) if along_z else (src_n[k].y * 0.5 + 0.5)
			colors.append(dark.lerp(light, clampf(shade * 1.3 - 0.1, 0.0, 1.0)))
		for k in src_i:
			index.append(base + k)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
