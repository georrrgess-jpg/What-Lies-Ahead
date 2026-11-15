class_name LavaPuddle
extends Node3D
## A small lava puddle splatted by a Lava Lampoon glob. It glows for LIFE
## seconds and burns every zombie standing in it for BURN_DPS (heavies and
## bosses too: it is small). Puddles do not stack: a glob landing within
## MERGE of a live puddle only keeps that one hot (its life starts again), so
## spreading fire across a chokepoint covers more ground than tunnelling one
## zombie. At most MAX_LIVE exist; a new one cools the oldest.
##
## The burn is quiet like FizzBurn: it takes health directly (no flinch or
## hit sound per tick) and only the tick that finishes a zombie goes through
## Zombie.take_hit, so the kill and its mastery are credited to the weapon.

const LIFE := 1.5
const RADIUS := 0.85
const MERGE := 1.3
const MAX_LIVE := 10
const BURN_DPS := 24.0
const TICK := 0.25
## Seconds over which a puddle crusts over and shrinks at the end.
const COOL := 0.4
const BUBBLES := 3
const EMBERS := [Color(1.0, 0.86, 0.3), Color(1.0, 0.45, 0.1), Color(1.0, 0.25, 0.4)]

static var _live: Array[LavaPuddle] = []
static var _disc_mesh: CylinderMesh
static var _bubble_mesh: SphereMesh
static var _crust_mat: StandardMaterial3D
static var _lava_mat: StandardMaterial3D
static var _bubble_mat: StandardMaterial3D

var controller: WeaponController
var weapon: WeaponData
var _age := 0.0
var _tick := 0.0
var _swell := 0.0
var _lava: MeshInstance3D
var _bubbles: Array[MeshInstance3D] = []
var _phase: PackedFloat32Array = []


## A puddle on the floor at `at` (a floor point), or a hotter old one nearby.
static func spawn(owner_controller: WeaponController, at: Vector3, w: WeaponData) -> void:
	if not is_instance_valid(owner_controller) or not owner_controller.is_inside_tree():
		return
	for p in _live:
		if is_instance_valid(p) and p.global_position.distance_to(at) < MERGE:
			p._refresh()
			return
	if _live.size() >= MAX_LIVE:
		_live.pop_front().queue_free()
	var puddle := LavaPuddle.new()
	puddle.controller = owner_controller
	puddle.weapon = w
	owner_controller.player.get_parent().add_child(puddle)
	puddle.global_position = at + Vector3.UP * 0.025
	puddle._build()
	_live.append(puddle)


func _build() -> void:
	if _disc_mesh == null:
		_disc_mesh = CylinderMesh.new()
		_disc_mesh.top_radius = 1.0
		_disc_mesh.bottom_radius = 1.0
		_disc_mesh.height = 0.02
		_disc_mesh.radial_segments = 18
		_disc_mesh.rings = 1
		_bubble_mesh = SphereMesh.new()
		_bubble_mesh.radius = 1.0
		_bubble_mesh.height = 2.0
		_bubble_mesh.radial_segments = 8
		_bubble_mesh.rings = 4
		_crust_mat = StandardMaterial3D.new()
		_crust_mat.albedo_color = Color(0.23, 0.13, 0.2)
		_crust_mat.emission_enabled = true
		_crust_mat.emission = Color(1.0, 0.3, 0.08)
		_crust_mat.emission_energy_multiplier = 0.5
		_crust_mat.roughness = 0.7
		_lava_mat = StandardMaterial3D.new()
		_lava_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_lava_mat.albedo_color = Color(1.0, 0.5, 0.12)
		_bubble_mat = StandardMaterial3D.new()
		_bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_bubble_mat.albedo_color = Color(1.0, 0.86, 0.32)
	var crust := _disc(_crust_mat, Vector3(RADIUS, 1.0, RADIUS * 0.86))
	crust.position.y = -0.005
	_lava = _disc(_lava_mat, Vector3(RADIUS * 0.78, 1.0, RADIUS * 0.66))
	for i in BUBBLES:
		var b := MeshInstance3D.new()
		b.mesh = _bubble_mesh
		b.material_override = _bubble_mat
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := TAU * i / BUBBLES + randf() * 1.2
		b.position = Vector3(cos(a), 0.0, sin(a)) * randf_range(0.15, 0.5) * RADIUS
		add_child(b)
		_bubbles.append(b)
		_phase.append(randf())
	rotation.y = randf() * TAU
	scale = Vector3(0.25, 1.0, 0.25)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.1, 1.0, 1.1), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_SINE)


func _disc(m: Material, s: Vector3) -> MeshInstance3D:
	var d := MeshInstance3D.new()
	d.mesh = _disc_mesh
	d.material_override = m
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.scale = s
	add_child(d)
	return d


## Another glob landed on it: hot again from the start, with a little swell.
func _refresh() -> void:
	_age = 0.0
	_swell = 1.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFE or not is_instance_valid(controller):
		queue_free()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick += TICK
		_burn_inside()
	_swell = maxf(0.0, _swell - delta * 5.0)
	var cool := clampf((LIFE - _age) / COOL, 0.0, 1.0)
	var s := cool * (1.0 + _swell * 0.12)
	_lava.scale = Vector3(RADIUS * 0.78 * s, 1.0, RADIUS * 0.66 * s)
	for i in BUBBLES:
		var t := fmod(_age * 1.6 + _phase[i], 1.0)
		_bubbles[i].scale = Vector3.ONE * (0.05 + 0.07 * t) * cool * (1.0 - smoothstep(0.85, 1.0, t))
	if cool < 1.0:
		var shrink := lerpf(0.6, 1.0, cool)
		scale = Vector3(shrink, 1.0, shrink)


func _burn_inside() -> void:
	var dmg := BURN_DPS * TICK * controller.damage_multiplier
	var r := RADIUS * scale.x
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or z.is_dead():
			continue
		var d := z.global_position - global_position
		if absf(d.y) > 0.8 or Vector2(d.x, d.z).length() > r + z.data.capsule_radius * 0.5 * z.data.body_scale:
			continue
		if dmg < z.health:
			z.health -= dmg
		else:
			z.take_hit(dmg, z.global_position + Vector3.UP * z.data.body_scale, Vector3.UP, weapon.id, false, 0.0)
		WeaponFx.burst(get_parent(), z.global_position + Vector3.UP * 0.2, Vector3.UP, EMBERS, 2, 2.0, 0.3, 0.03, 50.0, Vector3(0, -3.0, 0))


func _exit_tree() -> void:
	_live.erase(self)
