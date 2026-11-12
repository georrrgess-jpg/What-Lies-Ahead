class_name SpawnPlanner
extends RefCounted
## Chooses the entrance for every spawn by reading the map and the player
## (the "enemy_spawn" markers of the level). The rules, in order of weight:
##
##   - never on top of the player: entrances whose walking route to the
##     player is shorter than MIN_ROUTE are out;
##   - out of sight: an entrance the player is looking at (in view and with a
##     clear line) is a last resort;
##   - no dead time: entrances on the far side of the map lose points for
##     every metre past FAR_ROUTE, and the last few zombies of a wave take
##     the nearest valid entrance;
##   - spread: every spawn loads its entrance for a few seconds, so pressure
##     moves between routes instead of queueing at one door;
##   - fronts: a wave works two entrances at a time (one for a siege, all of
##     them for an ambush) and re-reads them as the player moves;
##   - flankers: late in a wave the fast enemies come through whichever
##     entrance is most behind the player.

enum Role {
	## The wave's current fronts.
	MAIN,
	## Behind the player, away from the fronts.
	FLANK,
	## The nearest valid entrance (the last few zombies of a wave).
	CLOSE,
	## Anywhere valid, spread as evenly as possible (ambushes, specialists).
	SPREAD,
}

## Shortest walking route (m) from an entrance to the player for it to be used.
const MIN_ROUTE := 13.0
## Routes longer than this cost points: the walk in is dead time.
const FAR_ROUTE := 30.0
## Seconds between re-reading routes and sight lines.
const REFRESH := 0.6
## Seconds between re-reading the fronts.
const FRONT_REFRESH := 10.0
## How fast an entrance's load from recent spawns wears off (per second).
const LOAD_DECAY := 0.22

var _player: Player
var _points: Array[Node3D] = []
var _route := PackedFloat32Array()
var _seen := PackedByteArray()
var _load := PackedFloat32Array()
var _fronts: Array[int] = []
var _front_count := 2
var _age := INF
var _front_age := 0.0


func setup(points: Array, player: Player) -> void:
	_player = player
	_points.clear()
	for p in points:
		if p is Node3D:
			_points.append(p)
	_route.resize(_points.size())
	_seen.resize(_points.size())
	_load.resize(_points.size())
	_load.fill(0.0)
	_age = INF


func is_empty() -> bool:
	return _points.is_empty()


func points() -> Array[Node3D]:
	return _points


## Call when a wave starts: how many entrances it works at a time (0 = all).
func begin_wave(front_count: int) -> void:
	_front_count = _points.size() if front_count <= 0 else mini(front_count, _points.size())
	_load.fill(0.0)
	_refresh()
	_pick_fronts()


func tick(delta: float) -> void:
	_age += delta
	_front_age += delta
	for i in _load.size():
		_load[i] = maxf(0.0, _load[i] - LOAD_DECAY * delta)
	if _age >= REFRESH:
		_refresh()
	if _front_age >= FRONT_REFRESH:
		_pick_fronts()


## The entrance for the next spawn (null if the level has none).
func pick(role: Role) -> Node3D:
	if _points.is_empty():
		return null
	if _age >= REFRESH:
		_refresh()
	var best := 0
	var best_score := -INF
	for i in _points.size():
		var score := _score(i, role) + randf() * 0.6
		if score > best_score:
			best_score = score
			best = i
	_load[best] += 1.0
	return _points[best]


## The entrance a surge pours through: a hidden front that is not too far.
func surge_point() -> Node3D:
	if _points.is_empty():
		return null
	_refresh()
	var best := 0
	var best_score := -INF
	for i in _points.size():
		var score := _score(i, Role.MAIN) - _load[i] - absf(_route[i] - 24.0) * 0.05
		if score > best_score:
			best_score = score
			best = i
	return _points[best]


## A sign-painter's name for an entrance: "SpawnRideGate" -> "RIDE GATE".
static func label(point: Node) -> String:
	var raw := String(point.name).trim_prefix("Spawn")
	var out := ""
	for i in raw.length():
		var c := raw[i]
		if i > 0 and c == c.to_upper() and c != c.to_lower() and raw[i - 1] != raw[i - 1].to_upper():
			out += " "
		out += c
	return out.to_upper()


## Walking distance (m) from `from` to the player along the navmesh.
func route_length(from: Vector3) -> float:
	var map := _player.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, from, _player.global_position, true)
	if path.size() < 2:
		return from.distance_to(_player.global_position)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func _score(i: int, role: Role) -> float:
	var route := _route[i]
	var score := 0.0
	if route < MIN_ROUTE:
		score -= 100.0
	if _seen[i]:
		score -= 3.0
	score -= maxf(0.0, route - FAR_ROUTE) * 0.1
	match role:
		Role.MAIN:
			score -= _load[i] * 0.6
			if _fronts.has(i):
				score += 2.0
		Role.FLANK:
			score -= _load[i] * 0.6
			score += _behind(i) * 2.0
			if _fronts.has(i):
				score -= 1.0
		Role.CLOSE:
			score -= route * 0.2
		Role.SPREAD:
			score -= _load[i] * 2.0
	return score


## 1 when the entrance is straight behind the player, -1 straight ahead.
func _behind(i: int) -> float:
	var to := _points[i].global_position - _player.global_position
	to.y = 0.0
	var forward := -_player.global_transform.basis.z
	return -forward.dot(to.normalized()) if to.length() > 0.01 else 0.0


func _refresh() -> void:
	_age = 0.0
	if _player == null or not _player.is_inside_tree():
		return
	var camera := _player.camera
	var eye := camera.global_position
	var forward := -camera.global_transform.basis.z
	var space := _player.get_world_3d().direct_space_state
	for i in _points.size():
		var at := _points[i].global_position
		_route[i] = route_length(at)
		var to := at + Vector3.UP * 1.2 - eye
		var seen := to.length() < 70.0 and forward.dot(to.normalized()) > 0.5
		if seen:
			var query := PhysicsRayQueryParameters3D.create(eye, at + Vector3.UP * 1.2, 1)
			seen = space.intersect_ray(query).is_empty()
		_seen[i] = 1 if seen else 0


## The best `_front_count` entrances right now: valid, hidden, not too far,
## and coming from different directions.
func _pick_fronts() -> void:
	_front_age = 0.0
	_fronts.clear()
	var order: Array[int] = []
	for i in _points.size():
		order.append(i)
	var fronts := _fronts
	while fronts.size() < _front_count and fronts.size() < order.size():
		var best := -1
		var best_score := -INF
		for i in order:
			if fronts.has(i):
				continue
			var score := _score(i, Role.SPREAD) + randf() * 1.5
			# Keep fronts apart: an entrance next to a chosen front is worth less.
			for f in fronts:
				if _points[i].global_position.distance_to(_points[f].global_position) < 22.0:
					score -= 1.5
			if score > best_score:
				best_score = score
				best = i
		if best < 0:
			break
		fronts.append(best)
