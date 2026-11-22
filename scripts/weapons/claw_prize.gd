class_name ClawPrize
extends Node3D
## A zombie the Claw Grabber has won (a child added by the first grab,
## ClawPrize.of(zombie)).
##
##   carried   while the claw yanks it to the player a Carry behaviour
##             (EnemyBehaviour.on_physics) takes over its movement: it is
##             dragged along the floor toward the player (move_and_slide, so
##             scenery stops it), lifted off its feet a little, and cannot
##             attack; dropped DROP_GAP from the player, at a wall that holds
##             it up, or when the cable runs out of time
##   dropped   it is bowled over at the player's feet (StrikeZoneTopple: it
##             falls, lies there and gets back up, about 1.7 s); one that
##             cannot be bowled over right now stands dazed for DAZE_TIME
##   Prized    from the grab on, for PRIZE_TIME, it takes PRIZE_BONUS more
##             damage from every hit (whatever weapon, through the
##             DamageStack); a gold prize star spins over its head, and
##             killing it while Prized pops a shower of prize tickets
##
## Heavies and bosses are never carried, but a claw that slips off them still
## marks them Prized. tools/balance_report.py reads these constants.

const NODE_NAME := "ClawPrize"
## Seconds a Prized zombie keeps its bonus, and the bonus (0.35 = +35%).
const PRIZE_TIME := 4.0
const PRIZE_BONUS := 0.35
## Seconds a zombie that cannot be bowled over stands dazed instead.
const DAZE_TIME := 1.3
## Drag speed (m/s) toward the player, and the flat gap (m, past both
## capsules) at which it is dropped.
const YANK_SPEED := 17.0
const DROP_GAP := 1.6
## The longest a carry lasts (s), and how long it may be held up by a wall.
const CARRY_MAX := 1.4
const CARRY_STUCK := 0.12
## How high (m) the carried zombie's model hangs above its feet.
const LIFT := 0.32
const STAR_SIZE := 0.42
const GOLD := Color(1.0, 0.82, 0.25)
const CONFETTI: Array[Color] = [Color(1.0, 0.82, 0.25), Color(1.0, 0.31, 0.64), Color(0.22, 0.94, 1.0), Color(1.0, 0.96, 0.88)]
const WIN_SOUND := &"clw_prize_win"

var zombie: Zombie
var _prized := 0.0
var _carry: Carry
var _daze := 0.0
var _hold: Daze
var _carry_time := 0.0
var _stuck := 0.0
var _lift := 0.0
var _model_rest := Vector3.ZERO
var _star: MeshInstance3D
var _age := 0.0

static var _star_mesh: ArrayMesh
static var _star_mat: StandardMaterial3D


## While carried: dragged toward the player, no chasing, no attacks.
class Carry extends EnemyBehaviour:
	var prize: ClawPrize

	func on_physics(z: Zombie, delta: float) -> bool:
		if not is_instance_valid(prize):
			return false
		prize.carry_step(z, delta)
		return true


## While dazed (it could not be bowled over): stands still.
class Daze extends EnemyBehaviour:
	func on_physics(z: Zombie, _delta: float) -> bool:
		z.move_with(Vector3.ZERO)
		return true


## The prize state of `z`, created on first use.
static func of(z: Zombie) -> ClawPrize:
	var existing := z.get_node_or_null(NODE_NAME) as ClawPrize
	if existing:
		return existing
	var p := ClawPrize.new()
	p.name = NODE_NAME
	p.zombie = z
	z.add_child(p)
	return p


## The damage multiplier the claw's mark puts on `z` (1 when not Prized).
static func damage_scale(z: Zombie) -> float:
	var p := z.get_node_or_null(NODE_NAME) as ClawPrize
	return 1.0 + PRIZE_BONUS if p and p.is_prized() else 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_model_rest = zombie.model_root.position
	zombie.died.connect(_on_died)


func is_prized() -> bool:
	return _prized > 0.0


func is_carried() -> bool:
	return _carry != null


## Marks the zombie Prized (again) for PRIZE_TIME.
func prize() -> void:
	_prized = PRIZE_TIME
	DamageStack.ensure(zombie)
	if _star == null:
		_star = MeshInstance3D.new()
		_star.mesh = _mesh()
		_star.material_override = _material()
		_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_star.top_level = true
		add_child(_star)
	_star.visible = true


## Starts the carry toward the player. False when it cannot be carried now
## (dead, still emerging, already carried or down).
func grab() -> bool:
	if zombie.is_dead() or zombie.state == Zombie.State.EMERGE or _carry != null:
		return false
	var topple := zombie.get_node_or_null(StrikeZoneTopple.NODE_NAME) as StrikeZoneTopple
	if topple and topple.is_down():
		return false
	_end_daze()
	if zombie.is_winding_up():
		zombie.interrupt()
	_carry = Carry.new()
	_carry.prize = self
	zombie.behaviours.append(_carry)
	zombie.play_animation(&"Stagger", 0.06)
	_carry_time = 0.0
	_stuck = 0.0
	return true


## One physics tick of the carry (Carry.on_physics).
func carry_step(z: Zombie, delta: float) -> void:
	_carry_time += delta
	var player := z.target
	if not is_instance_valid(player):
		drop()
		return
	var to := player.global_position - z.global_position
	to.y = 0.0
	var gap := to.length() - z.data.capsule_radius * z.data.body_scale - 0.4
	if gap <= DROP_GAP or _carry_time >= CARRY_MAX:
		drop()
		return
	var before := z.global_position
	var speed := YANK_SPEED / sqrt(maxf(1.0, z.data.mass)) * clampf(gap / 1.5, 0.4, 1.0)
	z.face_toward(to, delta * 4.0)
	z.move_with(to.normalized() * speed)
	var moved := Vector2(z.global_position.x - before.x, z.global_position.z - before.z).length()
	_stuck = _stuck + delta if _carry_time > 0.05 and moved < speed * delta * 0.25 else 0.0
	if _stuck >= CARRY_STUCK:
		drop()


## Lets go of the carried zombie: bowled over where it is (or dazed).
func drop() -> void:
	if _carry == null:
		return
	zombie.behaviours.erase(_carry)
	_carry = null
	_lift = 0.0
	zombie.model_root.position = _model_rest
	if zombie.is_dead():
		return
	var player := zombie.target
	var away := Vector3.ZERO
	if is_instance_valid(player):
		away = zombie.global_position - player.global_position
		away.y = 0.0
		away = away.normalized() * 1.2 if away.length() > 0.05 else Vector3.ZERO
	if not StrikeZoneTopple.knock_down(zombie, away):
		_hold = Daze.new()
		zombie.behaviours.append(_hold)
		_daze = DAZE_TIME
		zombie.play_animation(&"Stagger", 0.08)


func _end_daze() -> void:
	if _hold:
		zombie.behaviours.erase(_hold)
		_hold = null
		if not zombie.is_dead():
			zombie.play_animation(zombie.data.move_animation, 0.2)
	_daze = 0.0


func _process(delta: float) -> void:
	_age += delta
	# The carried zombie hangs from the claw, swinging a little.
	var want := LIFT if _carry != null else 0.0
	_lift = lerpf(_lift, want, 1.0 - exp(-14.0 * delta))
	if _carry != null or _lift > 0.002:
		zombie.model_root.position = _model_rest + Vector3(0.0, _lift, 0.0)
	if _daze > 0.0:
		_daze -= delta
		if _daze <= 0.0:
			_end_daze()
	if _prized > 0.0:
		_prized -= delta
	if _star:
		_star.visible = _prized > 0.0 and not zombie.is_dead()
		if _star.visible:
			var top := zombie.global_position + Vector3.UP * (zombie.data.capsule_height * zombie.data.body_scale + 0.38 + _lift)
			var bob := 0.0 if Settings.reduce_motion() else sin(_age * 4.0) * 0.05
			var spin := 0.0 if Settings.reduce_motion() else _age * 3.2
			# Shrinks away over its last half second.
			var k := clampf(_prized / 0.5, 0.0, 1.0) * STAR_SIZE * (1.0 + 0.12 * sin(_age * 9.0))
			_star.global_transform = Transform3D(Basis(Vector3.UP, spin).scaled(Vector3.ONE * k), top + Vector3.UP * bob)


func _on_died(_z: Zombie, _weapon_id: StringName) -> void:
	if _carry:
		zombie.behaviours.erase(_carry)
		_carry = null
	zombie.model_root.position = _model_rest
	_lift = 0.0
	if _prized <= 0.0:
		return
	_prized = 0.0
	var at := zombie.global_position + Vector3.UP * zombie.data.capsule_height * zombie.data.body_scale
	WeaponFx.burst(zombie.get_parent(), at, Vector3.UP, CONFETTI, 18, 5.0, 0.8, 0.06, 70.0, Vector3(0, -6.0, 0))
	WeaponFx.debris_stars(zombie.get_parent(), at, GOLD, 4)
	Sfx.play_at(WIN_SOUND, at, -4.0, randf_range(0.97, 1.04))


static func _mesh() -> ArrayMesh:
	if _star_mesh:
		return _star_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim: Array[Vector3] = []
	for i in 10:
		var a := PI * 0.5 + i * TAU / 10.0
		var r := 0.5 if i % 2 == 0 else 0.22
		rim.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
	for side in [1.0, -1.0]:
		var centre := Vector3(0, 0, 0.12 * side)
		for i in 10:
			st.set_color(GOLD.lerp(Color.WHITE, 0.35) if i % 2 == 0 else GOLD)
			st.add_vertex(centre)
			if side > 0.0:
				st.add_vertex(rim[(i + 1) % 10])
				st.add_vertex(rim[i])
			else:
				st.add_vertex(rim[i])
				st.add_vertex(rim[(i + 1) % 10])
	_star_mesh = st.commit()
	return _star_mesh


static func _material() -> StandardMaterial3D:
	if _star_mat:
		return _star_mat
	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.vertex_color_use_as_albedo = true
	_star_mat.albedo_color = Color(1.25, 1.15, 0.9)
	_star_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _star_mat
