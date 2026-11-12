extends Node
## Stages a still and saves it as a PNG (used to compare against the art
## reference and to check menus). Launched by dev_driver.gd:
##
##   godot --path . --resolution 1672x941 -- --shot=out.png [options]
##
## Options (all optional):
##   --shot-scene=level|menu|play|armory|settings|results|defeat|pause|kiosk
##   --shot-pos=x,y,z      player feet position
##   --shot-yaw=deg        0 looks down -Z, positive turns left
##   --shot-pitch=deg
##   --shot-fov=deg        vertical field of view
##   --shot-weapon=id
##   --shot-zombies=0|1    stage the four reference zombies
##   --shot-hud=0|1
##   --shot-frames=n       frames to wait before capturing

var path := ""
var args := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _arg(key: String, default_value: String) -> String:
	return String(args.get(key, default_value))


func _vec(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _run() -> void:
	var scene_kind := _arg("scene", "level")
	await _wait(3)
	if scene_kind in ["menu", "play", "armory", "settings"]:
		await _wait(10)
		var menu := get_tree().current_scene
		if scene_kind != "menu":
			menu._show(scene_kind)
		await _capture(int(_arg("frames", "30")))
		return

	Game.start_level(&"prize_pier", StringName(_arg("weapon", "ion_carbine")))
	var director: RunDirector = null
	while director == null or director.player == null:
		await get_tree().process_frame
		director = get_tree().get_first_node_in_group("run_director") as RunDirector
	var player := director.player
	await _wait(2)

	# Freeze the run so nothing moves while the still is staged.
	director.set_process(false)
	director.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)

	var pos := _vec(_arg("pos", "5.0,0.0,15.5"))
	player.global_position = pos
	player.set_look(deg_to_rad(float(_arg("yaw", "12"))), deg_to_rad(float(_arg("pitch", "0"))))
	var fov := float(_arg("fov", "62"))
	Profile.data["settings"]["fov"] = fov
	player._apply_settings()
	player.camera.fov = fov

	if scene_kind == "kiosk":
		director.tickets = 260
		director.tickets_changed.emit(260)
		player.health = 60.0
		player.health_changed.emit(60.0, 100.0)
	elif scene_kind in ["results", "defeat"]:
		director._grant(&"ion_carbine", 880, 61)
		director._grant(&"pulse_pistol", 420, 30)
		director.total_kills = 91
		director.elapsed = 412.0
		director.wave_number = 8 if scene_kind == "results" else 6
		director.waves_cleared = 8 if scene_kind == "results" else 5
		director.state = RunDirector.State.CLEARED if scene_kind == "results" else RunDirector.State.DEFEAT
		var screen = (load(RunDirector.RESULTS_SCENE) as PackedScene).instantiate()
		director.get_parent().add_child(screen)
		screen.show_result(director.result())
		director.hud.visible = false
	elif scene_kind == "pause":
		director.wave_number = 3
		director.pause()
	else:
		director.wave_number = 3
		director._set_state(RunDirector.State.WAVE)
		director.hud._wave.text = "WAVE 03"
		director.kiosk.set_open(false)
		if _arg("zombies", "1") == "1":
			_stage_zombies(director, player)
		if _arg("portal", "0") == "1":
			director.portal.activate()

	if _arg("hud", "1") == "0":
		director.hud.visible = false
	await _capture(int(_arg("frames", "45")))


## Four zombies placed roughly where the reference image has them.
func _stage_zombies(director: RunDirector, player: Player) -> void:
	var staged := [
		[&"tourist_shambler", Vector3(1.2, 0, 10.6), 0.30, Color(1.0, 0.33, 0.62)],
		[&"tourist_shambler", Vector3(-2.6, 0, 8.2), 0.75, Color(0.62, 0.3, 0.86)],
		[&"tourist_shambler", Vector3(1.6, 0, 6.4), 0.55, Color(1.0, 0.76, 0.18)],
		[&"lifeguard_runner", Vector3(8.6, 0, 7.4), 0.40, Color.WHITE],
	]
	var scene: PackedScene = load(RunDirector.ZOMBIE_SCENE)
	for entry in staged:
		var data: EnemyData = GameData.enemy(entry[0]).duplicate()
		if entry[0] == &"tourist_shambler":
			data.shirt_colors = [entry[3]] as Array[Color]
		var z: Zombie = scene.instantiate()
		z.setup(data, player, 1.0)
		z.position = entry[1]
		director._enemies_root.add_child(z)
		director._alive.append(z)
		var to_player: Vector3 = player.global_position - z.global_position
		z.rotation.y = atan2(to_player.x, to_player.z)
		z.set_physics_process(false)
		var anim := z.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim and anim.current_animation != "":
			anim.seek(anim.current_animation_length * float(entry[2]), true)
			anim.pause()


func _capture(frames: int) -> void:
	await _wait(frames)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("[shot] saved %s (%dx%d) error=%d" % [path, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)
