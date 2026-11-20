extends RefCounted
## Full-size inspect or reload frames of the held weapon (a --shot-run script
## for a level scene), for checking small parts such as the Tin Sergeant's
## soldier: saves <shot>_<t>.png, the right two thirds of the screen at full
## resolution, at each of --shot-times (seconds into the inspect, or into the
## reload with --shot-reload=1; --shot-rare=1 forces the rare inspect).

const CROP := Rect2(0.33, 0.25, 0.67, 0.75)


func run(shot: Node, director: RunDirector) -> void:
	var player := director.player
	var view := player.view
	view.inspect_force_rare = shot._arg("rare", "0") == "1"
	var reload := shot._arg("reload", "0") == "1"
	await shot._wait(40)
	var clock := 0.0
	if reload:
		player.weapons._ammo[player.weapons.current.id]["mag"] = 0
		player.weapons.start_reload()
	elif not view.inspect():
		print("[frames] could not start")
		return
	for ts in String(shot._arg("times", "1.0")).split(","):
		var t := float(ts)
		if reload:
			while clock < t:
				await shot.get_tree().process_frame
				clock += shot.get_process_delta_time()
		else:
			while view.is_inspecting() and view._inspect.clock < t:
				await shot.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var full := shot.get_viewport().get_texture().get_image()
		var size := Vector2(full.get_size())
		var img := full.get_region(Rect2i(Vector2i(CROP.position * size), Vector2i(CROP.size * size)))
		img.save_png("%s_%s.png" % [String(shot.path).get_basename(), ts])
	print("[frames] saved")
