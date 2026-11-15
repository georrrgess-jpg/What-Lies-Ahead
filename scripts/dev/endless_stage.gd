extends RefCounted
## Stills of the Endless features (run by scripts/dev/screenshot.gd):
##   --shot-scene=kiosk --shot-run=res://scripts/dev/endless_stage.gd --shot=<x.png>
## Saves <x>_trap.png (a fire trap armed under a crowd, a supply crate landed
## beside it) and <x>_open.png (a district paid for: its gate opening, the
## district banner). Use with --scene=res://scenes/levels/endless_testbed.tscn
## for the grey box's square trap, or on the city with --shot-pos/--shot-yaw.


func run(shot: Node, director: RunDirector) -> void:
	var endless := director.endless
	if endless == null:
		push_warning("endless_stage: not an endless level")
		return
	var player := director.player
	director.kiosk.player_inside = false
	director._set_state(RunDirector.State.WAVE)
	var base := String(shot.path).get_basename()
	var trap := _first_trap(endless)
	if trap:
		_crowd(director, trap.global_position, trap.radius * 0.6)
		trap.arm()
		var crate := EndlessSupply.new()
		crate.director = director
		director.get_parent().add_child(crate)
		crate.global_position = trap.global_position + Vector3(trap.radius + 3.0, 0, 2.0)
		crate._time = EndlessSupply.FALL_SECONDS
		var eye := trap.global_position + Vector3(2.0, 0, trap.radius + 8.0)
		player.global_position = eye
		var to := trap.global_position - eye
		player.set_look(atan2(-to.x, -to.z), deg_to_rad(-14.0))
		await _save(shot, base + "_trap.png", 40)
		await shot._wait(150)
		var left := director.alive_enemies().filter(func(z) -> bool: return is_instance_valid(z) and not z.is_dead()).size()
		print("[stage] trap %s: %d of 5 shamblers standing after %.1f s armed" % [trap.kind, left, 190.0 / 60.0])
	var gate := _first_gate(endless)
	if gate:
		var spot := gate.global_position + gate.global_transform.basis.z.normalized() * 9.0
		player.global_position = spot
		var to := gate.global_position - spot
		player.set_look(atan2(-to.x, -to.z), deg_to_rad(6.0))
		director.tickets = gate.data.price + 40
		await shot._wait(10)
		endless.open_district(gate.data)
		await _save(shot, base + "_open.png", 36)


## Saves the screen after `frames` frames (the screenshot tool's own capture quits).
func _save(shot: Node, file: String, frames: int) -> void:
	await shot._wait(frames)
	await RenderingServer.frame_post_draw
	var err := shot.get_viewport().get_texture().get_image().save_png(file)
	print("[shot] saved %s error=%d" % [file, err])


func _first_trap(endless: EndlessDirector) -> EndlessTrap:
	for node in endless.get_tree().get_nodes_in_group("endless_trap"):
		if node is EndlessTrap and endless.is_open((node as EndlessTrap).district):
			return node
	return null


func _first_gate(endless: EndlessDirector) -> EndlessGate:
	for node in endless.get_tree().get_nodes_in_group("endless_gate"):
		if node is EndlessGate and not (node as EndlessGate).is_open:
			return node
	return null


## Shamblers standing in the trap.
func _crowd(director: RunDirector, at: Vector3, spread: float) -> void:
	var scene: PackedScene = load(RunDirector.ZOMBIE_SCENE)
	for i in 5:
		var z: Zombie = scene.instantiate()
		z.setup(GameData.enemy(EndlessDirector.resolve(&"city_shambler")), director.player, 0.0)
		var a := TAU * i / 5.0
		z.position = at + Vector3(cos(a), 0, sin(a)) * spread
		director._enemies_root.add_child(z)
		director._alive.append(z)
