extends RefCounted
## Tin Sergeant stress probe (a --shot-run script for a level scene): stages
## a 40-zombie crowd walking in on the player, measures frame times for
## PHASE seconds without soldiers, then keeps EXTRA soldiers out at once (more
## than TinSoldier.MAX_SOLDIERS, past the cap on purpose) for PHASE seconds
## and measures again. Reports each soldier's life (seconds from landing to
## pop) and any that stood still while marching, and saves a still mid-way (<shot>).
##
##   godot --path . --rendering-driver opengl3 -- --shot=/tmp/s.png --shot-weapon=tin_sergeant \
##       --shot-run=res://scripts/dev/tin_squad_probe.gd

const CROWD := 40
const EXTRA := 8
const PHASE := 5.0
const KINDS: Array[StringName] = [&"tourist_shambler", &"tourist_shambler", &"lifeguard_runner", &"boardwalk_bruiser"]


func run(shot: Node, director: RunDirector) -> void:
	var player := director.get_tree().get_first_node_in_group("player") as Player
	var tree := director.get_tree()
	player.set_physics_process(true)
	player.invulnerable = true
	var map := player.get_world_3d().navigation_map
	var scene: PackedScene = load(RunDirector.ZOMBIE_SCENE)
	for i in CROWD:
		var a := TAU * i / CROWD
		var r := 12.0 + 10.0 * fmod(i * 0.618, 1.0)
		var at := player.global_position + Vector3(cos(a), 0.0, sin(a)) * r
		at = NavigationServer3D.map_get_closest_point(map, at)
		var z: Zombie = scene.instantiate()
		z.setup(GameData.enemy(KINDS[i % KINDS.size()]), player, 1.0)
		z.position = at
		director._enemies_root.add_child(z)
		director._alive.append(z)
		z.died.connect(director._on_zombie_died)
		z.skip_emerge()
	await tree.physics_frame
	var base := await _measure(tree, PHASE, Callable())
	# Harmless soldiers, so the crowd stays 40 strong while they march and pop.
	var dud: WeaponData = player.weapons.current.duplicate()
	dud.damage = 0.0
	dud.direct_hit_bonus = 0.0
	var lives := {}
	var stood := {}
	var seen := {}
	var keep := func() -> void:
		var out := TinSoldier.live(player.weapons)
		var level := player.get_parent()
		for k in range(out.size(), EXTRA):
			var a := randf() * TAU
			var from := player.global_position + Vector3(cos(a) * 1.5, 1.4, sin(a) * 1.5)
			var vel := Vector3(cos(a), 0.0, sin(a)) * randf_range(3.0, 7.0) + Vector3.UP * 3.0
			TinSoldier._take(level).begin(player.weapons, dud, from, vel)
		for s in TinSoldier.live(player.weapons):
			var id := s.get_instance_id()
			if s.phase == TinSoldier.Phase.MARCH:
				lives[id] = s._life
				if not seen.has(id):
					seen[id] = [s.global_position, s._life]
				elif s._life - float(seen[id][1]) > 3.0:
					if s.global_position.distance_to(seen[id][0]) < 0.5 and s._goal != Vector3.INF and s._speed > 0.5:
						stood[id] = true
					seen[id] = [s.global_position, s._life]
	var squad := await _measure(tree, PHASE, keep, shot)
	var max_life := 0.0
	for id in lives:
		max_life = maxf(max_life, float(lives[id]))
	print("[tin] crowd %d, alive now %d" % [CROWD, director.alive_enemies().size()])
	print("[tin] frame ms without soldiers: avg %.2f max %.2f (physics avg %.2f)" % [base[0], base[1], base[2]])
	print("[tin] frame ms with %d soldiers: avg %.2f max %.2f (physics avg %.2f)" % [EXTRA, squad[0], squad[1], squad[2]])
	print("[tin] soldiers marched %d, longest march %.1f s (limit %.1f), stood still while marching: %d" % [lives.size(), max_life, TinSoldier.MARCH_LIFE, stood.size()])
	print("[tin] player hp %.0f" % player.health)
	var phases := {}
	for s in TinSoldier._live:
		phases[s.phase] = phases.get(s.phase, 0) + 1
	print("[tin] phases now ", phases, " pool ", TinSoldier._pool.size())


## Average and worst frame time (ms, the worst after the first second's warm-up) and average physics time over `seconds`,
## calling `each` every frame; saves stills half way when `shot` is given.
func _measure(tree: SceneTree, seconds: float, each: Callable, shot: Node = null) -> Array:
	var total := 0.0
	var worst := 0.0
	var phys := 0.0
	var frames := 0
	var t := 0.0
	var saved := false
	while t < seconds:
		var start := Time.get_ticks_usec()
		if each.is_valid():
			each.call()
		await tree.process_frame
		var ms := (Time.get_ticks_usec() - start) / 1000.0
		t += ms / 1000.0
		total += ms
		if t > 1.0:
			worst = maxf(worst, ms)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		frames += 1
		if shot and not saved and t > seconds * 0.6 and DisplayServer.get_name() != "headless":
			saved = true
			await RenderingServer.frame_post_draw
			tree.root.get_viewport().get_texture().get_image().save_png(shot.path)
	return [total / maxi(1, frames), worst, phys / maxi(1, frames)]
