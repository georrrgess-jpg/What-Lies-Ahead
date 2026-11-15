class_name Dazzle
extends Node3D
## The Shutterbug's camera-flash daze on one zombie (added as a child the
## first time a flash lands, Dazzle.of(zombie)). A flash knocks a zombie out
## of its windup or charge and staggers it, then leaves it slowed and seeing
## stars for a moment. Each zombie can be staggered by a flash only once per
## COOLDOWN, so the camera never stun-locks; flashes in between only renew the
## slow. Heavy zombies (mass STAGGER_MASS and up) and finale alphas are never
## staggered, only slowed, and shake the daze off sooner (scaled by mass).

const NODE_NAME := "Dazzle"
## Seconds before the same zombie can be staggered by a flash again.
const COOLDOWN := 2.5
const STAGGER_MASS := 5.0
## Speed multiplier of a 1-mass zombie while dazed (heavier ones slow less).
const SLOW := 0.55
const STARS := 3
const STAR_COLORS: Array[Color] = [Color(1.0, 0.92, 0.35), Color(0.75, 0.95, 1.0), Color(1.0, 0.6, 0.9)]
## Stars circle the head this far out (m) and this fast (rad/s).
const ORBIT := 0.28
const ORBIT_SPEED := 5.5

var zombie: Zombie
var _left := 0.0
var _cooldown := 0.0
var _spin := 0.0
var _stars: Array[MeshInstance3D] = []

static var _star_mesh: ArrayMesh
static var _star_mats: Array[StandardMaterial3D] = []


## The daze on `z`, created on first use.
static func of(z: Zombie) -> Dazzle:
	var existing := z.get_node_or_null(NODE_NAME) as Dazzle
	if existing:
		return existing
	var d := Dazzle.new()
	d.name = NODE_NAME
	d.zombie = z
	z.add_child(d)
	return d


## Dazes the zombie for `seconds`; returns true if the flash staggered it.
func apply(seconds: float) -> bool:
	if zombie.is_dead():
		return false
	var mass := maxf(1.0, zombie.data.mass)
	_left = maxf(_left, seconds / sqrt(mass))
	var staggered := false
	if _cooldown <= 0.0:
		_cooldown = COOLDOWN
		if mass < STAGGER_MASS and zombie.rank != Zombie.RANK_BOSS:
			zombie.interrupt()
			staggered = true
	zombie.flash_now()
	_show_stars(true)
	set_physics_process(true)
	return staggered


## True while the zombie is still seeing stars.
func is_dazed() -> bool:
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
		_orbit(delta)
	else:
		_show_stars(false)
		if _cooldown <= 0.0:
			set_physics_process(false)


func _orbit(delta: float) -> void:
	_spin = fmod(_spin + ORBIT_SPEED * delta, TAU)
	var s := zombie.data.body_scale
	var top := (zombie.data.head_height + 0.42) * s
	for i in _stars.size():
		var a := _spin + TAU * i / STARS
		_stars[i].position = Vector3(cos(a) * ORBIT * s, top + sin(a * 2.0 + i) * 0.04, sin(a) * ORBIT * s)


func _show_stars(on: bool) -> void:
	if on and _stars.is_empty():
		for i in STARS:
			var m := MeshInstance3D.new()
			m.mesh = _star()
			m.material_override = _star_mat(i)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.scale = Vector3.ONE * 0.42
			add_child(m)
			_stars.append(m)
	for s in _stars:
		s.visible = on
	if on:
		_orbit(0.0)


## A flat five-pointed star (built once, shared).
static func _star() -> ArrayMesh:
	if _star_mesh:
		return _star_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 10:
		var a0 := PI * 0.5 + i * TAU / 10.0
		var a1 := PI * 0.5 + (i + 1) * TAU / 10.0
		var r0 := 0.5 if i % 2 == 0 else 0.22
		var r1 := 0.22 if i % 2 == 0 else 0.5
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a1) * r1, sin(a1) * r1, 0.0))
		st.add_vertex(Vector3(cos(a0) * r0, sin(a0) * r0, 0.0))
	_star_mesh = st.commit()
	return _star_mesh


## Glowing, camera-facing star material, one per colour.
static func _star_mat(i: int) -> StandardMaterial3D:
	if _star_mats.is_empty():
		for c in STAR_COLORS:
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.billboard_keep_scale = true
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.albedo_color = c
			_star_mats.append(m)
	return _star_mats[i % _star_mats.size()]
