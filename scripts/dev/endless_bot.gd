class_name EndlessBot
extends RefCounted
## The dev driver's Endless errands (--autoplay=endless, scripts/dev/dev_driver.gd):
## on top of the usual fight-and-shop bot it buys a gate in a break when it
## can afford the cheapest one and keep RESERVE tickets, arms a trap it is
## near when a crowd stands in it, walks to a supply crate once it lands, and
## logs every wave ("[dev] ENDLESS wave=..") for the balance table in
## docs/ENDLESS.md. In a break it buys whichever is cheaper, the next gate or
## the next Upgrade Bench tier of the weapon in hand; it runs over to a
## power-up that is a short walk away.

## Tickets the bot keeps after buying a gate (heals, energy, overshield).
const RESERVE := 150
## Zombies inside a trap's radius before the bot runs over to arm it.
const TRAP_CROWD := 4
## A trap further than this (m) is not worth the walk mid-wave.
const TRAP_REACH := 14.0
## A zombie this close (m) has reached the player (time-to-reach in the spawn log).
const REACH := 3.0
## A power-up further than this walk (m) is left where it lies.
const POWERUP_REACH := 24.0

var dev: Node
var _errand: Node3D
var _goal := Vector3.ZERO
var _errand_time := 0.0
var _last_wave := 0
var _gates_bought := 0
var _traps_armed := 0
var _upgrades := 0
var _tier_before := 0
var _wave_start := 0.0
var _gate_goal := Vector3.ZERO
## Spawn fairness of the wave in progress: zombie instance id -> [spawn time,
## entrance index], and the wave's totals (see _measure_spawns()).
var _tracked := {}
var _spawn_stats := {}


func _init(driver: Node) -> void:
	dev = driver


## Logs the start of every wave and measures where its zombies come from.
func tick(_delta: float) -> void:
	var run: RunDirector = dev._director
	if run == null or run.endless == null:
		return
	if run.state == RunDirector.State.WAVE:
		_measure_spawns(run)
	if run.wave_number != _last_wave and run.state == RunDirector.State.WAVE:
		_log_spawns(_last_wave)
		_last_wave = run.wave_number
		var wave := run.current_wave()
		print("[dev] ENDLESS wave=%d kind=%s title=\"%s\" enemies=%d cap=%d interval=%.2f health=x%.2f tickets=%d districts=%d hp=%d t=%.0fs last_wave=%.0fs" % [
			run.wave_number, run.endless.waves.kind_of(run.wave_number), wave.title, run.enemies_remaining(), wave.max_alive,
			wave.spawn_interval, run.endless.health_scale(), run.tickets, run.endless.open_districts().size(),
			int(run.player.health), run.elapsed, run.elapsed - _wave_start])
		_wave_start = run.elapsed


## Notes every zombie the frame it appears (straight distance, walking route,
## in the player's view, which entrance) and the moment it first gets within
## REACH m of the player.
func _measure_spawns(run: RunDirector) -> void:
	var eye := run.player.camera.global_position
	var forward := -run.player.camera.global_transform.basis.z
	for z in run.alive_enemies():
		if not is_instance_valid(z):
			continue
		var key := z.get_instance_id()
		var entry: Array = _tracked.get(key, [])
		if entry.is_empty():
			_tracked[key] = [run.elapsed, false]
			# A boss's own minions pop out beside it: not an entrance spawn.
			if is_instance_valid(run.boss) and z != run.boss and z.global_position.distance_to(run.boss.global_position) < 4.0:
				_add(&"summons", 1.0)
			else:
				_note_spawn(run, z, eye, forward)
		elif not entry[1] and z.global_position.distance_to(run.player.global_position) < REACH:
			entry[1] = true
			_add(&"reach_sum", run.elapsed - float(entry[0]))
			_add(&"reached", 1.0)


func _note_spawn(run: RunDirector, z: Zombie, eye: Vector3, forward: Vector3) -> void:
	var at := z.global_position
	var dist := at.distance_to(run.player.global_position)
	var to := at + Vector3.UP * 1.2 - eye
	var seen := forward.dot(to.normalized()) > 0.5 and to.length() < 70.0
	if seen:
		var query := PhysicsRayQueryParameters3D.create(eye, at + Vector3.UP * 1.2, 1)
		seen = run.player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	_add(&"count", 1.0)
	_add(&"dist_sum", dist)
	_add(&"route_sum", run.planner.route_length(at))
	_add(&"near", 1.0 if dist < 14.0 else 0.0)
	_add(&"seen", 1.0 if seen else 0.0)
	_spawn_stats[&"min"] = minf(float(_spawn_stats.get(&"min", INF)), dist)
	var nearest := -1
	var best := INF
	var points := run.planner.points()
	for i in points.size():
		var d := points[i].global_position.distance_to(at)
		if d < best:
			best = d
			nearest = i
	var used: Dictionary = _spawn_stats.get(&"entrances", {})
	used[nearest] = true
	_spawn_stats[&"entrances"] = used


func _add(key: StringName, value: float) -> void:
	_spawn_stats[key] = float(_spawn_stats.get(key, 0.0)) + value


## One line per wave: "[dev] ENDLESS spawns wave=.. n=.. dist=.. route=..".
func _log_spawns(wave: int) -> void:
	var n := float(_spawn_stats.get(&"count", 0.0))
	if wave > 0 and n > 0.0:
		var reached := float(_spawn_stats.get(&"reached", 0.0))
		print("[dev] ENDLESS spawns wave=%d n=%d dist=%.1f min=%.1f route=%.1f near14=%d in_view=%d entrances=%d reach=%.1fs reached=%d summons=%d" % [
			wave, int(n), _spawn_stats[&"dist_sum"] / n, _spawn_stats[&"min"], _spawn_stats[&"route_sum"] / n,
			int(_spawn_stats[&"near"]), int(_spawn_stats[&"seen"]), (_spawn_stats[&"entrances"] as Dictionary).size(),
			_spawn_stats.get(&"reach_sum", 0.0) / maxf(1.0, reached), int(reached), int(_spawn_stats.get(&"summons", 0.0))])
	_spawn_stats.clear()
	_tracked.clear()


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
	var p := e.powerups.pickup
	if is_instance_valid(p) and p.time_left() > 2.0 and _reachable(run, p.global_position) \
			and run.planner.route_length(p.global_position) < POWERUP_REACH:
		_goal = p.global_position
		return p
	if run.is_intermission():
		var gate := _pick_gate(run)
		var price := e.upgrades.next_price(run.player.weapons.current.id)
		if price > 0 and run.tickets >= price + RESERVE and (gate == null or price < gate.data.price):
			var bench := _pick_bench(run)
			if bench:
				return bench
		if gate:
			_goal = _gate_goal
		return gate
	# Traps on the big waves, or with tickets to spare after the next gate.
	var big := e.waves.kind_of(run.wave_number) in [&"horde", &"boss"]
	var spare := run.tickets - run.level.endless.trap_price - (RESERVE if big else saving_for())
	if run.state == RunDirector.State.WAVE and spare >= 0:
		return _pick_trap(run)
	return null


## Tickets the bot keeps back for the cheapest gate it can still open or the
## next bench tier (0 when there is nothing left to buy).
func saving_for() -> int:
	var run: RunDirector = dev._director
	var cheapest := run.endless.upgrades.next_price(run.player.weapons.current.id)
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
			_gate_goal = side
	return best


## The nearest bench of an open district the bot can walk up to.
func _pick_bench(run: RunDirector) -> EndlessBench:
	var map := run.player.get_world_3d().navigation_map
	var best: EndlessBench = null
	var best_d := INF
	for node in run.get_tree().get_nodes_in_group("endless_bench"):
		var bench := node as EndlessBench
		if bench == null or not run.endless.is_open(bench.district):
			continue
		var spot := NavigationServer3D.map_get_closest_point(map, bench.global_position + bench.global_transform.basis.z.normalized() * 1.4)
		var d := spot.distance_to(run.player.global_position)
		if spot.distance_to(bench.global_position) < EndlessBench.REACH - 0.3 and d < best_d and _reachable(run, spot):
			best = bench
			best_d = d
			_goal = spot
	if best:
		_tier_before = run.endless.upgrades.tier(run.player.weapons.current.id)
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
	if _errand is EndlessBench:
		return run.endless.upgrades.tier(run.player.weapons.current.id) != _tier_before
	return false


func _finish(run: RunDirector) -> void:
	dev._set_held("interact", false)
	if _errand is EndlessGate and (_errand as EndlessGate).is_open:
		_gates_bought += 1
		print("[dev] ENDLESS gate %s opened on wave %d: tickets left %d, districts %d" % [
			(_errand as EndlessGate).district, run.wave_number, run.tickets, run.endless.open_districts().size()])
	elif _errand is EndlessBench:
		var w := run.player.weapons.current
		var t := run.endless.upgrades.tier(w.id)
		if t != _tier_before:
			_upgrades += 1
			print("[dev] ENDLESS upgrade %s to %s on wave %d: tickets left %d" % [w.id, EndlessUpgrades.NAMES[t], run.wave_number, run.tickets])
	elif _errand is EndlessTrap and (_errand as EndlessTrap).state == EndlessTrap.State.ACTIVE:
		_traps_armed += 1
		print("[dev] ENDLESS trap %s armed on wave %d" % [(_errand as EndlessTrap).kind, run.wave_number])
	_errand = null


## The run's Endless line for the end of the run (death or --max-seconds).
func report(timeout: bool) -> void:
	var run: RunDirector = dev._director
	if run == null or run.endless == null:
		return
	_log_spawns(_last_wave)
	print("[dev] ENDLESS RESULT wave=%d timeout=%s difficulty=%s time=%.0fs kills=%d tickets=%d districts=%d/%d gates=%d traps=%d upgrades=%d powerups=%d best_wave=%d score=%d" % [
		run.wave_number, timeout, run.difficulty, run.elapsed, run.total_kills, run.tickets, run.endless.open_districts().size(),
		run.level.endless.districts.size(), _gates_bought, _traps_armed, _upgrades, run.endless.powerups.taken, EndlessRecords.best_wave(), run.score.score if run.score else 0])
