class_name MoveFx
extends RefCounted
## Dust from the player's feet: a trail of flecks while sliding, a kick on a
## dash and a burst on a long landing. All of it starts a little ahead of the
## feet along the view, where a first-person camera can see the floor. Chunky toy-like flecks drawn
## by FxBurst, which pools its bursts, so a slide allocates nothing once warm.

const COLORS: Array[Color] = [Color(0.93, 0.89, 0.82), Color(0.78, 0.74, 0.68), Color(1.0, 0.98, 0.95)]
const GRAVITY := Vector3(0.0, -5.0, 0.0)

static var _mesh: Mesh


## Flecks thrown up and out to both sides ahead of the feet (where the
## lowered view still sees the floor), so they stream past the bottom corners
## of the screen while sliding along `direction`.
static func trail(parent: Node, feet: Vector3, direction: Vector3) -> void:
	var side := direction.cross(Vector3.UP)
	var ahead := feet + direction * 1.8 + Vector3.UP * 0.05
	_spawn(parent, ahead + side * 0.5, (side + Vector3.UP * 0.9).normalized(), 3, 3.2, 0.4, 0.09, 30.0)
	_spawn(parent, ahead - side * 0.5, (-side + Vector3.UP * 0.9).normalized(), 3, 3.2, 0.4, 0.09, 30.0)


## Flecks kicked away from a dash along `direction`, in front of a player
## looking along `facing`.
static func puff(parent: Node, feet: Vector3, facing: Vector3, direction: Vector3) -> void:
	_spawn(parent, feet + facing * 2.4 + Vector3.UP * 0.2, (-direction + Vector3.UP * 0.6).normalized(), 10, 3.6, 0.45, 0.08, 40.0)


## Dust thrown up and out to both sides after a long drop, in front of a
## player looking along `facing`.
static func ring(parent: Node, feet: Vector3, facing: Vector3) -> void:
	var side := facing.cross(Vector3.UP)
	var ahead := feet + facing * 1.6 + Vector3.UP * 0.05
	_spawn(parent, ahead + side * 0.6, (side + Vector3.UP).normalized(), 9, 4.2, 0.55, 0.1, 40.0)
	_spawn(parent, ahead - side * 0.6, (-side + Vector3.UP).normalized(), 9, 4.2, 0.55, 0.1, 40.0)


static func _spawn(parent: Node, at: Vector3, direction: Vector3, amount: int, speed: float, life: float,
		size: float, spread: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	FxBurst.spawn(parent, at, direction, COLORS, amount, speed, life, size, spread, GRAVITY, _fleck())


static func _fleck() -> Mesh:
	if _mesh == null:
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 6
		m.rings = 3
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 1.0
		m.material = mat
		_mesh = m
	return _mesh
