class_name CityBirds
extends MultiMeshInstance3D
## A flock of pigeons on an Ashfall City pavement (a MultiMesh of birds drawn
## with art/shaders/city_flock.gdshader; tools/city/city_life.gd places them).
## They peck about until the camera comes within `scare_radius`, then burst
## up and away from it, wings beating, and are gone; once the camera has been
## away `return_after` seconds, and is out of sight range, they are back.
## Only a distance check runs while they sit (a few times a second); the
## flight moves seven transforms a frame for a few seconds.

@export var scare_radius := 6.5
@export var return_after := 30.0
## The camera must be at least this far for the flock to settle back.
@export var settle_distance := 22.0

const CHECK := 0.2
const FLIGHT := 3.2
const PERCHED := 0
const FLYING := 1
const GONE := 2

var _home: Array[Transform3D] = []
var _velocity: PackedVector3Array
var _state := PERCHED
var _clock := 0.0
var _check := 0.0


func _ready() -> void:
	for i in multimesh.instance_count:
		_home.append(multimesh.get_instance_transform(i))
	_velocity.resize(multimesh.instance_count)
	_check = randf() * CHECK


func _process(delta: float) -> void:
	_clock += delta
	if _state == FLYING:
		_fly(delta)
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = CHECK
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position.distance_to(global_position)
	if _state == PERCHED and d < scare_radius:
		_take_off(cam.global_position)
	elif _state == GONE and _clock > return_after and d > settle_distance:
		_land()


func _take_off(from: Vector3) -> void:
	_state = FLYING
	_clock = 0.0
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	for i in _home.size():
		var spread := away.rotated(Vector3.UP, randf_range(-0.9, 0.9))
		_velocity[i] = spread * randf_range(4.0, 7.0) + Vector3.UP * randf_range(3.0, 5.0)
		var c := multimesh.get_instance_custom_data(i)
		c.a = 1.0
		multimesh.set_instance_custom_data(i, c)


## Climbs away along each bird's velocity, facing where it flies.
func _fly(delta: float) -> void:
	if _clock > FLIGHT:
		_state = GONE
		_clock = 0.0
		visible = false
		return
	for i in _home.size():
		var v := _velocity[i]
		v.y += 3.5 * delta
		_velocity[i] = v
		var xf := multimesh.get_instance_transform(i)
		xf.origin += v * delta
		xf.basis = Basis.looking_at(v.normalized(), Vector3.UP)
		multimesh.set_instance_transform(i, xf)


func _land() -> void:
	_state = PERCHED
	for i in _home.size():
		multimesh.set_instance_transform(i, _home[i])
		var c := multimesh.get_instance_custom_data(i)
		c.a = 0.0
		multimesh.set_instance_custom_data(i, c)
	visible = true
