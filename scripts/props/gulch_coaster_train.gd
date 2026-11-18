extends Node3D
## Boomtown's Runaway Mine Train: the loco and its ore cars run the coaster
## circuit traced by tools/build_boomtown.gd. They crawl up the lift hill on the
## chain, then let gravity have them (speed from the drop below the crest)
## through the loop over Main Street, and race back through the rock out of
## sight. Cars are the children Car0 (the loco) .. CarN, spaced `spacing`
## apart; each rides the track's frame, so they turn upside down in the loop.

## The circuit as samples (closed: the last sample runs back to the first).
@export var points := PackedVector3Array()
## The track's up vector at each sample.
@export var ups := PackedVector3Array()
## 1 where the sample is inside the rock (cars hidden, run fast).
@export var hidden := PackedByteArray()
## Distance range of the chain lift (metres along the circuit).
@export var lift := Vector2.ZERO
## Height of the lift's crest (the train's speed comes from the drop below it).
@export var top_y := 24.5
@export var spacing := 2.3
@export var lift_speed := 3.6
@export var hidden_speed := 16.0
@export var max_speed := 21.0

const GRAVITY := 9.8
const FRICTION := 0.9

var _lengths := PackedFloat32Array()
var _total := 0.0
var _s := 0.0
var _speed := 3.6
var _cars: Array[Node3D] = []
var _was_lift := false


func _ready() -> void:
	_lengths.resize(points.size())
	var total := 0.0
	for i in points.size():
		if i > 0:
			total += points[i].distance_to(points[i - 1])
		_lengths[i] = total
	_total = total + points[points.size() - 1].distance_to(points[0]) if points.size() > 1 else 0.0
	for child in get_children():
		if child is Node3D:
			_cars.append(child)
	# Start with the train part-way up the lift, out of step with any replay.
	_s = lerpf(lift.x, lift.y, 0.2)
	set_process(_total > 0.0)


func _process(delta: float) -> void:
	var head := _sample(_s)
	var on_lift := _s >= lift.x and _s <= lift.y
	var target := lift_speed
	if on_lift:
		target = lift_speed
	elif _is_hidden(_s):
		target = hidden_speed
	else:
		target = clampf(sqrt(lift_speed * lift_speed + 2.0 * GRAVITY * maxf(0.0, top_y - head.origin.y)) * FRICTION, lift_speed, max_speed)
	_speed = move_toward(_speed, target, delta * 14.0)
	if _was_lift and not on_lift:
		Sfx.play_at(&"gulch_coaster_whoosh", head.origin, 2.0, 1.0, 22.0)
	elif on_lift and not _was_lift:
		Sfx.play_at(&"gulch_coaster_clack", head.origin, 0.0, 1.0, 16.0)
	_was_lift = on_lift
	_s = fposmod(_s + _speed * delta, _total)
	for i in _cars.size():
		var d := fposmod(_s - i * spacing, _total)
		var car := _cars[i]
		car.transform = _sample(d)
		car.visible = not _is_hidden(d)


func _is_hidden(d: float) -> bool:
	return hidden.size() > 0 and hidden[_index(d)] == 1


## Index of the last sample at or before distance d (binary search).
func _index(d: float) -> int:
	var lo := 0
	var hi := _lengths.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if _lengths[mid] <= d:
			lo = mid
		else:
			hi = mid - 1
	return lo


## The car frame at distance d: Z along the track, Y the track's up.
func _sample(d: float) -> Transform3D:
	var i := _index(d)
	var j := (i + 1) % points.size()
	var seg_end := _lengths[j] if j > 0 else _total
	var seg := maxf(0.001, seg_end - _lengths[i])
	var t := clampf((d - _lengths[i]) / seg, 0.0, 1.0)
	var pos := points[i].lerp(points[j], t)
	var forward := (points[j] - points[i]).normalized()
	var up := ups[i].lerp(ups[j], t).normalized()
	var side := up.cross(forward).normalized()
	up = forward.cross(side).normalized()
	return Transform3D(Basis(side, up, forward), pos)
