class_name BowArrow
extends Node3D
## One arrow of the Bullseye Longbow (BullseyeBowMode). It flies on a slight
## arc (WeaponData.projectile_gravity) with a short streak behind it and is a
## ray-style hit on what it meets (WeaponController.strike: headshots and
## falloff over the distance flown). A Bullseye passes through `pierce`
## zombies first (each PIERCE_FALLOFF of the last) and pins the next one
## (it staggers). Then it sticks:
##   in a zombie   on the bone it struck (the head for a headshot); when the
##                 zombie dies the arrow drops out of it to the floor
##   in scenery    point first, quivering for a moment
## An arrow lying in scenery or on the floor is picked up by walking over it
## while the bow is carried (WeaponController.catch_round: one arrow back),
## with a pop and a twinkle. At most MAX_STUCK lie about; the oldest goes.

const MASK_WORLD := 1
const MASK_ENEMIES := 4
## Lifetime in flight (s) and while stuck (s, then it shrinks away).
const FUSE := 3.0
const STUCK_LIFE := 50.0
const MAX_STUCK := 24
## How deep the point sinks into scenery and into a zombie (m).
const EMBED_WORLD := 0.16
const EMBED_ZOMBIE := 0.12
const PIERCE_FALLOFF := 0.85
## Pick-up reach around the player's middle (m), and how often it is checked (s).
const PICKUP_REACH := 1.45
const PICKUP_CHECK := 0.1
## The arrow at world size (m): shaft length and radius, and how far behind
## the point (the node's origin) the shaft's far end sits.
const LENGTH := 0.8
const TIP := 0.865
## It shows once this far from the bow (m), clear of the camera.
const SHOW_AFTER := 1.2
const SHAFT_R := 0.011
const QUIVER_TIME := 0.55
const STREAK_LENGTH := 1.6
const THUNK_SOUND := &"bb_thunk"
const PICKUP_SOUND := &"bb_pickup"
const PIN_SOUND := &"bb_pin"
const GOLD := Color(1.0, 0.82, 0.25)
const CHIPS := [Color(0.71, 0.15, 0.17), Color(1.0, 0.95, 0.82), Color(0.98, 0.8, 0.3)]
const TWINKLE := [Color(1.0, 0.86, 0.36), Color(1.0, 0.98, 0.9), Color(1.0, 0.36, 0.62)]

enum State { FLYING, STUCK_ZOMBIE, FALLING, LYING }

var controller: WeaponController
var data: WeaponData
var velocity := Vector3.ZERO
var state := State.FLYING
var bullseye := false
var _scale := 1.0
var _pierce := 0
var _fuse := FUSE
var _travelled := 0.0
var _exclude: Array[RID] = []
var _streak: MeshInstance3D
var _age := 0.0
var _quiver := 0.0
var _quiver_axis := Vector3.RIGHT
var _rest_basis := Basis.IDENTITY
var _check := 0.0
var _host: Zombie

static var _stuck: Array[BowArrow] = []
static var _meshes := {}
static var _mats := {}


## Looses an arrow of `weapon` from `from` with velocity `vel` (damage scale
## `scale`), passing through `pierce` zombies before it pins one.
static func launch(owner: WeaponController, weapon: WeaponData, from: Vector3, vel: Vector3, scale: float, pierce: int, is_bullseye: bool) -> void:
	var level := owner.player.get_parent()
	if level == null:
		return
	var a := BowArrow.new()
	a.controller = owner
	a.data = weapon
	a.velocity = vel
	a._scale = scale
	a._pierce = pierce
	a.bullseye = is_bullseye
	a._exclude = [owner.player.get_rid()]
	level.add_child(a)
	a.global_position = from
	a._orient()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()


func _build() -> void:
	if _meshes.is_empty():
		_make_shared()
	_part(&"shaft", &"shaft", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, TIP - LENGTH * 0.5 + 0.05)))
	_part(&"point", &"brass", Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, TIP - LENGTH - 0.02)))
	_part(&"ferrule", &"brass", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, TIP - LENGTH + 0.035)))
	_part(&"nock", &"nock", Transform3D(Basis.IDENTITY, Vector3(0, 0, TIP + 0.055)))
	for k in 3:
		var turn := Basis(Vector3.BACK, TAU * k / 3.0 + PI * 0.5)
		_part(&"feather", &"cream" if k == 0 else &"red", Transform3D(turn, turn * Vector3(0, SHAFT_R + 0.018, 0) + Vector3(0, 0, TIP - 0.035)))
	_streak = MeshInstance3D.new()
	_streak.mesh = _meshes[&"streak"]
	_streak.material_override = _mats[&"streak_gold" if bullseye else &"streak"]
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streak)
	if bullseye:
		_part(&"glint", &"glint", Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.01)))
	visible = false


func _part(mesh: StringName, material: StringName, xf: Transform3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _meshes[mesh]
	m.material_override = _mats[material]
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.transform = xf
	add_child(m)
	return m


static func _make_shared() -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = SHAFT_R
	shaft.bottom_radius = SHAFT_R
	shaft.height = LENGTH
	shaft.radial_segments = 8
	shaft.rings = 1
	_meshes[&"shaft"] = shaft
	var point := CylinderMesh.new()
	point.top_radius = 0.002
	point.bottom_radius = SHAFT_R * 1.9
	point.height = 0.09
	point.radial_segments = 8
	point.rings = 1
	_meshes[&"point"] = point
	var ferrule := CylinderMesh.new()
	ferrule.top_radius = SHAFT_R * 1.3
	ferrule.bottom_radius = SHAFT_R * 1.3
	ferrule.height = 0.04
	ferrule.radial_segments = 8
	ferrule.rings = 1
	_meshes[&"ferrule"] = ferrule
	var nock := SphereMesh.new()
	nock.radius = SHAFT_R * 1.5
	nock.height = SHAFT_R * 4.0
	nock.radial_segments = 8
	nock.rings = 4
	_meshes[&"nock"] = nock
	var feather := BoxMesh.new()
	feather.size = Vector3(0.003, 0.036, 0.15)
	_meshes[&"feather"] = feather
	var glint := SphereMesh.new()
	glint.radius = 0.03
	glint.height = 0.06
	glint.radial_segments = 8
	glint.rings = 4
	_meshes[&"glint"] = glint
	var streak := BoxMesh.new()
	streak.size = Vector3(0.018, 0.018, 1.0)
	_meshes[&"streak"] = streak
	_mats[&"shaft"] = _lit(Color(0.94, 0.88, 0.77), 0.0)
	_mats[&"brass"] = _lit(Color(0.85, 0.64, 0.25), 0.8)
	_mats[&"red"] = _lit(Color(0.91, 0.2, 0.23), 0.0)
	_mats[&"cream"] = _lit(Color(1.0, 0.95, 0.86), 0.0)
	_mats[&"nock"] = _glow(Color(1.0, 0.25, 0.62), 2.2)
	_mats[&"glint"] = _glow(GOLD, 3.0)
	_mats[&"streak"] = _trail(Color(1.0, 0.95, 0.85, 0.32))
	_mats[&"streak_gold"] = _trail(Color(1.0, 0.8, 0.25, 0.6))


static func _lit(color: Color, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func _trail(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	return m


func _physics_process(delta: float) -> void:
	match state:
		State.FLYING:
			_fly(delta)
		State.FALLING:
			_fall(delta)
		State.STUCK_ZOMBIE:
			pass
		State.LYING:
			_lie(delta)


func _fly(delta: float) -> void:
	_fuse -= delta
	if _fuse <= 0.0 or not is_instance_valid(controller):
		queue_free()
		return
	velocity.y -= data.projectile_gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var space := get_world_3d().direct_space_state
	# A Bullseye may pass through zombies: keep tracing the rest of the step.
	for _i in BullseyeBowMode.BULLSEYE_PIERCE + 2:
		var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD | MASK_ENEMIES)
		query.exclude = _exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var at: Vector3 = hit["position"]
		_travelled += from.distance_to(at)
		var collider = hit["collider"]
		var dir := velocity.normalized()
		if collider is Zombie and not collider.is_dead():
			var z: Zombie = collider
			var head := z.is_head_hit(at, from)
			var killed := controller.strike(data, z, at, dir, _travelled, _scale)
			WeaponFx.burst(get_parent(), at, -dir, [Color(1, 1, 1), GOLD if bullseye else CHIPS[0]], 6, 2.4, 0.3, 0.03)
			if _pierce > 0:
				_pierce -= 1
				_scale *= PIERCE_FALLOFF
				_exclude.append(z.get_rid())
				WeaponFx.flash(get_parent(), at, GOLD, 0.35, 0.12)
				from = at
				continue
			if bullseye and not killed:
				z.interrupt()
				Sfx.play_at(PIN_SOUND, at, -2.0, randf_range(0.95, 1.05))
			_stick_in_zombie(z, at, dir, head)
			return
		_stick_in_world(hit, dir)
		return
	_travelled += from.distance_to(to)
	global_position = to
	_orient()


## Faces the flight (the origin is the point), the streak trailing behind
## the nock (it grows over the first metres).
func _orient() -> void:
	var dir := velocity.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	global_basis = Basis.looking_at(dir, up)
	visible = _travelled >= SHOW_AFTER
	if _streak:
		var length := clampf(_travelled - SHOW_AFTER - TIP, 0.0, STREAK_LENGTH)
		_streak.visible = length > 0.05
		_streak.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 1.0, maxf(0.01, length))), Vector3(0, 0, TIP + 0.06 + length * 0.5))


func _stick_in_world(hit: Dictionary, dir: Vector3) -> void:
	var at: Vector3 = hit["position"]
	var level := get_parent()
	ImpactMarks.scuff(level, hit, dir, data)
	WeaponFx.burst(level, at + hit["normal"] * 0.03, hit["normal"], CHIPS, 7, 2.2, 0.35, 0.03)
	if bullseye:
		WeaponFx.flash(level, at, GOLD, 0.45, 0.14)
	Sfx.play_at(THUNK_SOUND, at, -1.0, randf_range(0.92, 1.08))
	global_position = at + dir * EMBED_WORLD
	visible = true
	_settle()
	_quiver = QUIVER_TIME
	_quiver_axis = dir.cross(Vector3.UP).normalized() if absf(dir.y) < 0.95 else Vector3.RIGHT
	state = State.LYING


func _stick_in_zombie(z: Zombie, at: Vector3, dir: Vector3, head: bool) -> void:
	_settle()
	global_position = at + dir * EMBED_ZOMBIE
	visible = true
	var holder: Node3D = z
	var skeleton := z.skeleton()
	if skeleton:
		var bone := &"Head" if head else &"Spine"
		if skeleton.find_bone(bone) >= 0:
			holder = _bone_holder(skeleton, bone)
	reparent(holder, true)
	_host = z
	state = State.STUCK_ZOMBIE
	if not z.died.is_connected(_on_host_died):
		z.died.connect(_on_host_died)
	if z.is_dead():
		_on_host_died(z, data.id)


## A BoneAttachment3D on `skeleton` that follows `bone` (one per bone, shared).
static func _bone_holder(skeleton: Skeleton3D, bone: StringName) -> Node3D:
	var key := "BowPin" + String(bone)
	var existing := skeleton.get_node_or_null(key) as Node3D
	if existing:
		return existing
	var att := BoneAttachment3D.new()
	att.name = key
	att.bone_name = bone
	skeleton.add_child(att)
	return att


## The arrow's host died: a moment later it drops out of the falling body.
func _on_host_died(_z: Zombie, _weapon: StringName) -> void:
	get_tree().create_timer(0.35, false).timeout.connect(_drop)


func _drop() -> void:
	if state != State.STUCK_ZOMBIE or not is_inside_tree():
		return
	var level := controller.player.get_parent() if is_instance_valid(controller) else null
	if level == null:
		queue_free()
		return
	reparent(level, true)
	scale = Vector3.ONE
	velocity = Vector3(randf_range(-1.0, 1.0), 1.2, randf_range(-1.0, 1.0))
	state = State.FALLING


## Tumbles to the floor and lies there to be picked up.
func _fall(delta: float) -> void:
	velocity.y -= 14.0 * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to - Vector3.UP * SHAFT_R * 2.0, MASK_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		rotate_object_local(Vector3.RIGHT, delta * 7.0)
		return
	var at: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var along := -global_basis.z
	along = (along - normal * along.dot(normal))
	if along.length() < 0.05:
		along = normal.cross(Vector3.RIGHT)
	global_basis = Basis.looking_at(along.normalized(), normal)
	global_position = at + normal * SHAFT_R * 1.2 + along.normalized() * LENGTH * 0.5
	Sfx.play_at(THUNK_SOUND, at, -9.0, 1.35)
	_settle()
	state = State.LYING


## Counts the arrow among those lying about (the oldest goes past MAX_STUCK).
func _settle() -> void:
	if _streak:
		_streak.visible = false
	if _stuck.has(self):
		return
	_stuck.append(self)
	while _stuck.size() > MAX_STUCK:
		var old: BowArrow = _stuck.pop_front()
		if is_instance_valid(old) and old != self:
			old.queue_free()


func _exit_tree() -> void:
	if state != State.STUCK_ZOMBIE:
		_stuck.erase(self)


## Stuck or lying: quivers, ages out, and goes back in the quiver when walked over.
func _lie(delta: float) -> void:
	_age += delta
	if _quiver > 0.0:
		if _quiver >= QUIVER_TIME:
			_rest_basis = global_basis
		_quiver = maxf(0.0, _quiver - delta)
		var k := _quiver / QUIVER_TIME
		global_basis = Basis(_quiver_axis, sin((QUIVER_TIME - _quiver) * 55.0) * 0.07 * k * k) * _rest_basis
	if _age > STUCK_LIFE:
		scale = Vector3.ONE * maxf(0.01, 1.0 - (_age - STUCK_LIFE) * 3.0)
		if _age > STUCK_LIFE + 0.33:
			queue_free()
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = PICKUP_CHECK
	if not is_instance_valid(controller) or not controller.player.alive:
		return
	if not controller.slots.has(data.id):
		return
	var ammo := controller.ammo_of(data.id)
	if ammo.x >= data.magazine_size and ammo.y >= data.reserve_max:
		return
	var body := controller.player.global_position + Vector3.UP * 0.9
	var middle := global_position + global_basis.z * LENGTH * 0.5
	if body.distance_to(middle) > PICKUP_REACH and body.distance_to(global_position) > PICKUP_REACH:
		return
	controller.catch_round(data)
	Sfx.play(PICKUP_SOUND, -6.0, randf_range(0.96, 1.06))
	WeaponFx.burst(get_parent(), middle, Vector3.UP, TWINKLE, 8, 2.0, 0.4, 0.025, 60.0, Vector3(0, -2.0, 0))
	queue_free()
