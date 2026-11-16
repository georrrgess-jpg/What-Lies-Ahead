class_name YoyoLocoTrip
extends Node3D
## The Yo-Yo Loco's Walk the Dog trip on one zombie (added as a child the
## first time the rolling yo-yo passes it, YoyoLocoTrip.of(zombie)): a loop of
## glowing string snags its ankles, so it stumbles (knocked out of a swing
## and staggered: light zombies only, once per COOLDOWN) and then shuffles,
## slowed, until the string slips off. Heavy zombies, alphas and bosses only
## slow, and less the heavier they are.

const NODE_NAME := "YoyoTrip"
const TIME := 2.2
const COOLDOWN := 3.0
## Speed multiplier of a 1-mass zombie while tripped (heavier ones slow less).
const SLOW := 0.4
## Below this mass (and not heavy, not a boss) a trip makes it stumble.
const STUMBLE_MASS := 3.0
const LOOP_COLOR := Color(0.78, 1.0, 0.25)
const LOOPS := 2

var zombie: Zombie
var _left := 0.0
var _total := 1.0
var _cooldown := 0.0
var _spin := 0.0
var _loops: Array[MeshInstance3D] = []

static var _loop_mesh: TorusMesh
static var _loop_mat: StandardMaterial3D


## The trip on `z`, created on first use.
static func of(z: Zombie) -> YoyoLocoTrip:
	var existing := z.get_node_or_null(NODE_NAME) as YoyoLocoTrip
	if existing:
		return existing
	var t := YoyoLocoTrip.new()
	t.name = NODE_NAME
	t.zombie = z
	z.add_child(t)
	return t


## Trips the zombie; returns true if it stumbled.
func apply() -> bool:
	if zombie.is_dead():
		return false
	_total = TIME / sqrt(maxf(1.0, zombie.data.mass))
	_left = maxf(_left, _total)
	var stumbled := false
	if _cooldown <= 0.0 and zombie.data.mass < STUMBLE_MASS and not zombie.data.heavy and zombie.rank != Zombie.RANK_BOSS:
		_cooldown = COOLDOWN
		zombie.interrupt()
		stumbled = true
	_show(true)
	set_physics_process(true)
	return stumbled


func is_tripped() -> bool:
	return _left > 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if zombie == null or zombie.is_dead():
		_left = 0.0
	if _left > 0.0:
		_left -= delta
		zombie.speed_multiplier *= lerpf(1.0, SLOW, 1.0 / maxf(1.0, zombie.data.mass))
		_pose(delta)
	else:
		_show(false)
		if _cooldown <= 0.0:
			set_physics_process(false)


## The loops wobble round the ankles and shrink away as the trip wears off.
func _pose(delta: float) -> void:
	_spin = fmod(_spin + delta * 7.0, TAU)
	var s := zombie.data.body_scale
	var fade := clampf(_left / maxf(0.1, _total) * 3.0, 0.0, 1.0)
	for i in _loops.size():
		var tilt := Basis(Vector3.RIGHT, 0.35 * sin(_spin + i * 2.1)) * Basis(Vector3.FORWARD, 0.3 * cos(_spin * 1.3 + i))
		var r := zombie.data.capsule_radius * s * (0.85 + 0.12 * i) * lerpf(0.6, 1.0, fade)
		_loops[i].transform = Transform3D(tilt * Basis(Vector3.UP, _spin * (1 if i == 0 else -1)) * Basis.from_scale(Vector3(r, r * 3.0, r)),
			Vector3(0.0, (0.16 + 0.12 * i) * s, 0.0))


func _show(on: bool) -> void:
	if on and _loops.is_empty():
		if _loop_mesh == null:
			_loop_mesh = TorusMesh.new()
			_loop_mesh.inner_radius = 0.93
			_loop_mesh.outer_radius = 1.0
			_loop_mesh.rings = 20
			_loop_mesh.ring_segments = 4
			_loop_mat = StandardMaterial3D.new()
			_loop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_loop_mat.albedo_color = LOOP_COLOR
		for i in LOOPS:
			var m := MeshInstance3D.new()
			m.mesh = _loop_mesh
			m.material_override = _loop_mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(m)
			_loops.append(m)
	for m in _loops:
		m.visible = on
