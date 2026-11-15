class_name GroundControlRing
extends Node3D
## One ping ring of Ground Control (scripts/weapons/modes/ground_control_mode.gd).
## A flat lime ring that flies along the aim, facing its flight, and grows
## as it goes, so it reads clearly in motion. It passes through every zombie
## inside it (each once per leg), weaker for each one it has passed
## (ATTENUATION, never below MIN_SHARE), and marks them (GroundControlMark).
## Scenery shields a zombie behind it from the ring's centre. The first wall
## (or floor) the ring's centre meets bounces it back like a radar echo, and
## on the way back it can strike the same crowd again; the second wall, or
## the end of its range, ends it in a soft fade.
##
## The charge picks the ring (STEPS): a tap sends a small, fast ping; each
## third of the charge grows it; a full charge is a huge slow ring that
## knocks zombies back, and the overcharged feedback blast (OVERCHARGE) is a
## wider, harder pink one. Hits go through WeaponController.ring_hit.

const MASK_WORLD := 1
## Per charge step: start and end radius (m), speed (m/s), range (m),
## damage share of WeaponData.damage, knockback (m/s on a 1-mass zombie).
const STEPS := [
	{"r0": 0.25, "r1": 0.75, "speed": 42.0, "range": 34.0, "damage": 0.25, "push": 0.4},
	{"r0": 0.35, "r1": 1.3, "speed": 32.0, "range": 36.0, "damage": 0.5, "push": 1.2},
	{"r0": 0.45, "r1": 1.9, "speed": 24.0, "range": 38.0, "damage": 0.75, "push": 2.0},
	{"r0": 0.55, "r1": 2.8, "speed": 17.0, "range": 40.0, "damage": 1.0, "push": 3.6},
]
const OVERCHARGE := {"r0": 0.7, "r1": 4.2, "speed": 19.0, "range": 32.0, "damage": 1.35, "push": 6.0}
## Damage kept for each zombie the ring has already passed through this leg.
const ATTENUATION := 0.82
const MIN_SHARE := 0.4
## How far in front of or behind the ring plane a zombie still counts as crossed.
const SLAB := 0.35
## The radius grows quickly at first and then levels off.
const GROW_EASE := 0.55
const FADE_TIME := 0.16
const BOUNCES := 1
const SHADER := "res://art/shaders/ground_control_ring.gdshader"
const LIME := Color(0.66, 0.9, 0.24)
const PINK := Color(1.0, 0.37, 0.64)
const BOUNCE_SOUND := &"gc_bounce"
const STRIKE_SOUND := &"gc_strike"

var weapon: WeaponData
var controller: WeaponController
var spec: Dictionary
var overcharged := false
var velocity := Vector3.ZERO
var _travel := 0.0
var _radius := 0.2
var _bounces := BOUNCES
var _struck := {}
var _fading := -1.0
var _hits := 0
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _exclude: Array[RID] = []

static var _quad: QuadMesh
static var _shader: Shader


## Sends a ring of charge step `step` (0 tap .. 3 full; 4 = the overcharged
## feedback blast) from `from` along `dir` under `parent`.
static func launch(parent: Node, from: Vector3, dir: Vector3, w: WeaponData, owner_controller: WeaponController, step: int) -> GroundControlRing:
	var ring := GroundControlRing.new()
	ring.weapon = w
	ring.controller = owner_controller
	ring.overcharged = step >= STEPS.size()
	ring.spec = OVERCHARGE if ring.overcharged else STEPS[clampi(step, 0, STEPS.size() - 1)]
	ring.velocity = dir.normalized() * float(ring.spec["speed"])
	parent.add_child(ring)
	ring.global_position = from
	return ring


## Seconds a ring of `step` takes to fly `distance` metres.
static func flight_time(step: int, distance: float) -> float:
	return distance / float(STEPS[clampi(step, 0, STEPS.size() - 1)]["speed"])


func _ready() -> void:
	_exclude.append(controller.player.get_rid())
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(2.0, 2.0)
		_shader = load(SHADER)
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("ring_color", PINK if overcharged else LIME)
	_mat.set_shader_parameter("thickness", 0.2 if overcharged else lerpf(0.26, 0.13, float(spec["r1"]) / 2.8))
	_mat.set_shader_parameter("crackle", 0.6 if overcharged else 0.0)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _quad
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_radius = float(spec["r0"])
	_face()


func _physics_process(delta: float) -> void:
	if _fading >= 0.0:
		_fading += delta
		_mat.set_shader_parameter("fade", 1.0 - _fading / FADE_TIME)
		_set_radius(_radius + float(spec["speed"]) * 0.05 * delta)
		if _fading >= FADE_TIME:
			queue_free()
		return
	var from := global_position
	var step := velocity * delta
	var to := from + step
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD)
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		to = hit["position"] + (hit["normal"] as Vector3) * 0.05
	global_position = to
	_travel += from.distance_to(to)
	var k := clampf(_travel / float(spec["range"]), 0.0, 1.0)
	_set_radius(lerpf(float(spec["r0"]), float(spec["r1"]), pow(k, GROW_EASE)))
	_strike_crossed(step.length())
	if not hit.is_empty():
		_wall(hit)
	elif k >= 1.0:
		_fading = 0.0


## Bounces off the wall once (striking the crowd again on the way back);
## the next wall ends the ring.
func _wall(hit: Dictionary) -> void:
	var normal: Vector3 = hit["normal"]
	WeaponFx.flash(get_parent(), hit["position"], PINK if overcharged else LIME, minf(1.2, _radius))
	if _bounces <= 0:
		_fading = 0.0
		return
	_bounces -= 1
	velocity = velocity.bounce(normal)
	_struck.clear()
	_hits = 0
	_face()
	Sfx.play_at(BOUNCE_SOUND, global_position, -2.0, randf_range(0.95, 1.08))


## Strikes every zombie the ring plane crossed this frame inside its radius.
func _strike_crossed(step_len: float) -> void:
	var dir := velocity.normalized()
	var centre := global_position
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead() or _struck.has(z.get_instance_id()):
			continue
		var s := z.data.body_scale
		var reach := z.data.capsule_radius * s
		var base := z.global_position + Vector3.UP * 0.3 * s
		var top := z.global_position + Vector3.UP * (z.data.capsule_height - 0.2) * s
		var along := (base - centre).dot(dir)
		if along > reach + SLAB or along < -(reach + SLAB + step_len):
			continue
		var point := Geometry3D.get_closest_point_to_segment(centre, base, top)
		var off := point - centre
		var lateral := (off - dir * off.dot(dir)).length()
		if lateral > _radius + reach * 0.6:
			continue
		if not _clear_line(centre, point):
			continue
		_struck[z.get_instance_id()] = true
		_strike(z, point, dir)


func _strike(z: Zombie, point: Vector3, dir: Vector3) -> void:
	var share := maxf(MIN_SHARE, pow(ATTENUATION, _hits))
	_hits += 1
	var dmg := weapon.damage * float(spec["damage"]) * share
	var push := float(spec["push"])
	if push > 0.0:
		var flat := Vector3(dir.x, 0.0, dir.z).normalized()
		z.knockback(flat * push * share / maxf(0.5, sqrt(z.data.mass)))
	GroundControlMark.of(z).mark()
	controller.ring_hit(weapon, z, point, dir, dmg, false)
	Sfx.play_at(STRIKE_SOUND, point, -6.0, randf_range(0.95, 1.1) * (1.15 if overcharged else 1.0))


func _set_radius(r: float) -> void:
	_radius = r
	_mesh.scale = Vector3.ONE * r


## Turns the ring to face along its flight.
func _face() -> void:
	var dir := velocity.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	_mesh.global_basis = Basis.looking_at(dir, up)
	_set_radius(_radius)


func _clear_line(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
