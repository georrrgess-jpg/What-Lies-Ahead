class_name EndlessBot
extends RefCounted
## The dev driver's Endless errands (--autoplay=endless, scripts/dev/dev_driver.gd):
## on top of the usual fight-and-shop bot it buys a gate in a break when it
## can afford the cheapest one and keep RESERVE tickets, arms a trap it is
## near when a crowd stands in it, walks to a supply crate once it lands, and
## logs every wave ("[dev] ENDLESS wave=..") for the balance table in
## docs/ENDLESS.md.

## Tickets the bot keeps after buying a gate (heals, energy, overshield).
const RESERVE := 150
## Zombies inside a trap's radius before the bot runs over to arm it.
const TRAP_CROWD := 4
## A trap further than this (m) is not worth the walk mid-wave.
const TRAP_REACH := 14.0

var dev: Node
var _errand: Node3D
var _goal := Vector3.ZERO
var _errand_time := 0.0
var _last_wave := 0
var _gates_bought := 0
var _traps_armed := 0
var _wave_start := 0.0


func _init(driver: Node) -> void:
	dev = driver


## Logs the start of every wave.
func tick(_delta: float) -> void:
	var run: RunDirector = dev._director
	if run == null or run.endless == null:
		return
	if run.wave_number != _last_wave and run.state == RunDirector.State.WAVE:
		_last_wave = run.wave_number
		var wave := run.current_wave()
		print("[dev] ENDLESS wave=%d kind=%s title=\"%s\" enemies=%d cap=%d interval=%.2f health=x%.2f tickets=%d districts=%d hp=%d t=%.0fs last_wave=%.0fs" % [
			run.wave_number, run.endless.waves.kind_of(run.wave_number), wave.title, run.enemies_remaining(), wave.max_alive,
			wave.spawn_interval, run.endless.health_scale(), run.tickets, run.endless.open_districts().size(),
			int(run.player.health), run.elapsed, run.elapsed - _wave_start])
		_wave_start = run.elapsed


## True while the bot is on an Endless errand (the dev driver then leaves the
## movement to it).
func busy(delta: float) -> bool:
	var run: RunDirector = dev._director
	if run == null or run.endless == null or not run.player.alive:
		return false
	if _errand == null or not is_instance_valid(_errand):
		_errand = _pick(run)
		_errand_time = 0.0
		if _errand == null:
			return false
	_errand_time += delta
	if _errand_time > 25.0 or _done(run):
		_finish(run)
		return false
	var at := run.player.global_position.distance_to(_goal) < 1.6
	dev._release("fire")
	if at:
		dev._stop_moving()
		dev._set_held("interact", true)
	else:
		dev._set_held("interact", false)
		dev._walk_to(_goal, delta, true)
	return true


## The next errand: a crate, a gate (breaks) or a trap (waves).
func _pick(run: RunDirector) -> Node3D:
	var e := run.endless
	if is_instance_valid(e.supply) and e.supply.landed and _reachable(run, e.supply.global_position):
		_goal = e.supply.global_position
		return e.supply
	if run.is_intermission():
		return _pick_gate(run)
	# Traps on the big waves, or with tickets to spare after the next gate.
	var big := e.waves.kind_of(run.wave_number) in [&"horde", &"boss"]
	var spare := run.tickets - run.level.endless.trap_price - (RESERVE if big else saving_for())
	if run.state == RunDirector.State.WAVE and spare >= 0:
		return _pick_trap(run)
	return null


## Tickets the bot keeps back for the cheapest gate it can still open (0 when none is left).
func saving_for() -> int:
	var run: RunDirector = dev._director
	var cheapest := 0
	for node in run.get_tree().get_nodes_in_group("endless_gate"):
		var gate := node as EndlessGate
		if gate and not gate.is_open and gate.data and (cheapest == 0 or gate.data.price < cheapest):
			cheapest = gate.data.price
	return cheapest + RESERVE if cheapest > 0 else 0


func _pick_gate(run: RunDirector) -> EndlessGate:
	var best: EndlessGate = null
	for node in run.get_tree().get_nodes_in_group("endless_gate"):
		var gate := node as EndlessGate
		if gate == null or gate.is_open or gate.data == null or run.tickets < gate.data.price + RESERVE:
			continue
		var side := _open_side(run, gate)
		if side == Vector3.INF:
			continue
		if best == null or gate.data.price < best.data.price:
			best = gate
			_goal = side
	return best


func _pick_trap(run: RunDirector) -> EndlessTrap:
	for node in run.get_tree().get_nodes_in_group("endless_trap"):
		var trap := node as EndlessTrap
		if trap == null or trap.state != EndlessTrap.State.READY or not run.endless.is_open(trap.district):
			continue
		if trap.global_position.distance_to(run.player.global_position) > TRAP_REACH:
			continue
		var crowd := 0
		for z in run.alive_enemies():
			if is_instance_valid(z) and z.global_position.distance_to(trap.global_position) < trap.radius:
				crowd += 1
		if crowd >= TRAP_CROWD:
			_goal = NavigationServer3D.map_get_closest_point(run.player.get_world_3d().navigation_map,
				trap.global_position + (run.player.global_position - trap.global_position).normalized() * (trap.radius + 0.6))
			return trap
	return null


## A spot in the gate's zone on the side the bot can walk to (INF if none).
func _open_side(run: RunDirector, gate: EndlessGate) -> Vector3:
	var map := run.player.get_world_3d().navigation_map
	for s in [1.0, -1.0]:
		var want: Vector3 = gate.global_position + gate.global_transform.basis.z.normalized() * 2.2 * s
		var spot := NavigationServer3D.map_get_closest_point(map, want)
		if spot.distance_to(want) < 1.5 and _reachable(run, spot):
			return spot
	return Vector3.INF


func _reachable(run: RunDirector, to: Vector3) -> bool:
	var map := run.player.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, run.player.global_position, to, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(to) < 1.2


func _done(run: RunDirector) -> bool:
	if _errand is EndlessGate:
		return (_errand as EndlessGate).is_open or run.tickets < (_errand as EndlessGate).data.price
	if _errand is EndlessTrap:
		return (_errand as EndlessTrap).state != EndlessTrap.State.READY
	return false


func _finish(run: RunDirector) -> void:
	dev._set_held("interact", false)
	if _errand is EndlessGate and (_errand as EndlessGate).is_open:
		_gates_bought += 1
		print("[dev] ENDLESS gate %s opened on wave %d: tickets left %d, districts %d" % [
			(_errand as EndlessGate).district, run.wave_number, run.tickets, run.endless.open_districts().size()])
	elif _errand is EndlessTrap and (_errand as EndlessTrap).state == EndlessTrap.State.ACTIVE:
		_traps_armed += 1
		print("[dev] ENDLESS trap %s armed on wave %d" % [(_errand as EndlessTrap).kind, run.wave_number])
	_errand = null


## The run's Endless line for the end of the run (death or --max-seconds).
func report(timeout: bool) -> void:
	var run: RunDirector = dev._director
	if run == null or run.endless == null:
		return
	print("[dev] ENDLESS RESULT wave=%d timeout=%s difficulty=%s time=%.0fs kills=%d tickets=%d districts=%d/%d gates=%d traps=%d best_wave=%d score=%d" % [
		run.wave_number, timeout, run.difficulty, run.elapsed, run.total_kills, run.tickets, run.endless.open_districts().size(),
		run.level.endless.districts.size(), _gates_bought, _traps_armed, EndlessRecords.best_wave(), run.score.score if run.score else 0])
