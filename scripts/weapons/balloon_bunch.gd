class_name BalloonBunch
extends Node3D
## The Balloon Darter's payload on one zombie (a child added by the first dart
## that sticks, BalloonBunch.of(zombie)). Every dart that hits ties on another
## balloon, up to MAX_BALLOONS, each inflating on its string above the dart.
## FUSE seconds after the first dart the whole bunch pops: POP_DAMAGE per
## balloon to the zombie, and a splash of SPLASH_SCALE of that to everything
## within SPLASH_RADIUS. A pop that reaches another zombie carrying balloons
## sets its bunch off too (a chain), a beat later. If the zombie dies first,
## its balloons pop on the spot (the splash only). Darts that land after the
## pop start a new bunch.

const NODE_NAME := "BalloonBunch"
const MAX_BALLOONS := 4
## Seconds from the first dart to the pop.
const FUSE := 0.9
## Damage per balloon to the zombie carrying it.
const POP_DAMAGE := 28.0
## Splash: radius (m) and the share of the pop each neighbour takes.
const SPLASH_RADIUS := 2.4
const SPLASH_SCALE := 0.55
## A neighbour's bunch set off by a pop goes this long after it.
const CHAIN_DELAY := 0.12
const MASK_WORLD := 1
const COLORS: Array[Color] = [Color(1.0, 0.3, 0.62), Color(0.35, 0.9, 1.0), Color(1.0, 0.85, 0.2), Color(0.62, 1.0, 0.3)]
const POP_SOUND := &"gn8b_balloon_pop"
const TIE_SOUND := &"gn8b_balloon_tie"

var zombie: Zombie
var weapon: WeaponData
var controller: WeaponController
var _left := 0.0
var _count := 0
var _time := 0.0
var _balloons: Array[Node3D] = []
var _strings: Array[MeshInstance3D] = []
var _anchors: Array[Vector3] = []

static var _skin_mesh: SphereMesh
static var _string_mesh: CylinderMesh
static var _mats := {}


## The bunch on `z`, created on first use.
static func of(z: Zombie) -> BalloonBunch:
	var existing := z.get_node_or_null(NODE_NAME) as BalloonBunch
	if existing:
		return existing
	var b := BalloonBunch.new()
	b.name = NODE_NAME
	b.zombie = z
	z.add_child(b)
	return b


## A dart of `w` stuck in the zombie at `point` (world space): one more balloon.
func add(w: WeaponData, owner_controller: WeaponController, point: Vector3) -> void:
	if zombie.is_dead():
		return
	weapon = w
	controller = owner_controller
	if _count == 0:
		_left = FUSE
		set_physics_process(true)
	if _count >= MAX_BALLOONS:
		return
	var anchor := zombie.to_local(point)
	anchor.x = clampf(anchor.x, -0.35, 0.35)
	anchor.z = clampf(anchor.z, -0.35, 0.35)
	_anchors.append(anchor)
	_add_balloon(_count)
	_count += 1
	Sfx.play_at(TIE_SOUND, point, -8.0, 0.9 + 0.08 * _count)


## Number of balloons tied on right now.
func balloons() -> int:
	return _count


## Sets the bunch off after `delay` seconds (or sooner, if its fuse is shorter).
func trip(delay: float) -> void:
	if _count > 0:
		_left = minf(_left, delay)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_physics_process(false)
	zombie.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if _count == 0:
		set_physics_process(false)
		return
	_time += delta
	_left -= delta
	_float()
	if _left <= 0.0:
		_pop(true)


func _on_died(_z: Zombie, _weapon: StringName) -> void:
	if _count > 0:
		_pop.call_deferred(false)


## Pops every balloon: damage to the carrier (if alive), splash, chain, confetti.
func _pop(hit_host: bool) -> void:
	if _count == 0:
		return
	var count := _count
	var centre := _bunch_centre()
	_clear_balloons()
	var level := zombie.get_parent()
	WeaponFx.burst(level, centre, Vector3.UP, COLORS + [Color.WHITE], 10 + 6 * count, 5.5, 0.7, 0.05, 180.0, Vector3(0, -7.0, 0))
	WeaponFx.flash(level, centre, COLORS[0], 0.5 + 0.15 * count, 0.12)
	Sfx.play_at(POP_SOUND, centre, -2.0 + count, randf_range(1.06, 1.14) - 0.05 * count)
	if not is_instance_valid(controller):
		return
	var dmg := POP_DAMAGE * count
	var chest := zombie.global_position + Vector3.UP * 1.0 * zombie.data.body_scale
	if hit_host and not zombie.is_dead():
		controller.ring_hit(weapon, zombie, chest, Vector3.UP, dmg, false)
	for node in zombie.get_tree().get_nodes_in_group("zombies"):
		var other := node as Zombie
		if other == null or other == zombie or other.is_dead():
			continue
		var other_chest := other.global_position + Vector3.UP * 1.0 * other.data.body_scale
		if other_chest.distance_to(chest) > SPLASH_RADIUS or not _clear(chest, other_chest):
			continue
		var bunch := other.get_node_or_null(NODE_NAME) as BalloonBunch
		if bunch:
			bunch.trip(CHAIN_DELAY)
		var away := (other_chest - chest).normalized()
		controller.ring_hit(weapon, other, other_chest - away * 0.3, away, dmg * SPLASH_SCALE, false)


func _clear(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD)
	return zombie.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _clear_balloons() -> void:
	for n in _balloons:
		n.queue_free()
	for s in _strings:
		s.queue_free()
	_balloons.clear()
	_strings.clear()
	_anchors.clear()
	_count = 0
	_time = 0.0
	set_physics_process(false)


func _bunch_centre() -> Vector3:
	var sum := Vector3.ZERO
	for b in _balloons:
		sum += b.global_position
	return sum / maxf(1.0, _balloons.size())


# --- looks ---------------------------------------------------------------------

func _add_balloon(i: int) -> void:
	if _skin_mesh == null:
		_skin_mesh = SphereMesh.new()
		_skin_mesh.radius = 0.5
		_skin_mesh.height = 1.15
		_skin_mesh.radial_segments = 14
		_skin_mesh.rings = 8
		_string_mesh = CylinderMesh.new()
		_string_mesh.top_radius = 0.006
		_string_mesh.bottom_radius = 0.006
		_string_mesh.height = 1.0
		_string_mesh.radial_segments = 4
		_string_mesh.rings = 1
	var skin := MeshInstance3D.new()
	skin.mesh = _skin_mesh
	skin.material_override = _skin_mat(COLORS[(i + randi() % 2) % COLORS.size()])
	skin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(skin)
	_balloons.append(skin)
	var line := MeshInstance3D.new()
	line.mesh = _string_mesh
	line.material_override = _skin_mat(Color(1, 1, 1))
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	_strings.append(line)
	_float()


## Balloons bob and sway above their darts, swelling as the fuse burns.
func _float() -> void:
	var s := zombie.data.body_scale
	var swell := 1.0 - _left / FUSE if _count > 0 else 0.0
	for i in _balloons.size():
		var a := TAU * i / MAX_BALLOONS + 0.6
		var anchor := _anchors[i]
		var sway := Vector3(sin(_time * 3.1 + i * 1.7), 0.0, cos(_time * 2.6 + i * 2.3)) * 0.05
		var top := Vector3(cos(a) * 0.22 * s, (zombie.data.head_height + 0.9 + 0.08 * (i % 2)) * s, sin(a) * 0.22 * s) + sway
		var size := lerpf(0.2, 0.42, swell) * s * (1.0 + 0.06 * sin(_time * 9.0 + i))
		var skin := _balloons[i]
		skin.position = top
		skin.scale = Vector3.ONE * size
		var low := top - Vector3(0.0, size * 0.55, 0.0)
		var line := _strings[i]
		var span := low - anchor
		line.position = (low + anchor) * 0.5
		line.basis = Basis(Quaternion(Vector3.UP, span.normalized())).scaled(Vector3(1.0, span.length(), 1.0)) if span.length() > 0.01 else Basis()


static func _skin_mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.25
		m.metallic_specular = 0.8
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.35
		m.rim_enabled = true
		m.rim = 0.6
		_mats[key] = m
	return _mats[key]
