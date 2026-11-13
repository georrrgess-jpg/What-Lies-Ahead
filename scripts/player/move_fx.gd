class_name MoveFx
extends RefCounted
## Dust from the player's feet: a trail of flecks while sliding, a puff
## behind a dash and a ring on a long landing. Chunky toy-like flecks drawn
## by FxBurst, which pools its bursts, so a slide allocates nothing once warm.

const COLORS: Array[Color] = [Color(0.93, 0.89, 0.82), Color(0.78, 0.74, 0.68), Color(1.0, 0.98, 0.95)]
const GRAVITY := Vector3(0.0, -5.0, 0.0)

static var _mesh: Mesh


## Flecks thrown up and out to both sides just ahead of the feet, so they
## stream past the edges of the view while sliding along `direction`.
static func trail(parent: Node, feet: Vector3, direction: Vector3) -> void:
	var side := direction.cross(Vector3.UP)
	var ahead := feet + direction * 1.1 + Vector3.UP * 0.05
	_spawn(parent, ahead + side * 0.35, (side + Vector3.UP * 0.8).normalized(), 3, 2.6, 0.45, 0.07, 30.0)
	_spawn(parent, ahead - side * 0.35, (-side + Vector3.UP * 0.8).normalized(), 3, 2.6, 0.45, 0.07, 30.0)


## A low puff kicked back from the feet at the start of a dash.
static func puff(parent: Node, feet: Vector3, direction: Vector3) -> void:
	_spawn(parent, feet + Vector3.UP * 0.1, (-direction + Vector3.UP * 0.4).normalized(), 10, 3.4, 0.5, 0.08, 45.0)


## A ring of dust round the feet after a long drop.
static func ring(parent: Node, feet: Vector3) -> void:
	_spawn(parent, feet + Vector3.UP * 0.05, Vector3.UP, 16, 3.8, 0.55, 0.09, 80.0)


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
