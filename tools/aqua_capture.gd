extends SceneTree
## Developer tool for Tidal Tunnels: runs the real game (main menu -> level via
## the dev bot, so pass --autoplay=clear) and, alongside the bot, traces the
## player and/or saves screenshots of live play.
##
##   godot --path . --script res://tools/aqua_capture.gd -- --autoplay=clear --level=tidal_tunnels \
##       [--trace=5] [--shots=/tmp/x --shot-times=60,90] [--cam=x,y,z>tx,ty,tz] [--speed=4]
##
## --trace=n        print the player's position, state and nearest zombies every n seconds
## --shots=prefix   save prefix_<t>.png at each time in --shot-times (seconds of run time)
## --cam=a>b        capture from a free camera at a looking at b instead of the player view
## --speed=n        Engine.time_scale while waiting between shots (1 during the capture)
##
## The run is reached untyped (no RunDirector/Zombie type hints): this script is
## compiled before the autoloads exist, so it must not pull in game classes.

const MENU := "res://scenes/ui/main_menu.tscn"

var _trace := 0.0
var _shots := ""
var _times: Array[float] = []
var _cam := ""
var _speed := 1.0
var _clock := 0.0
var _next_trace := 0.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--trace="):
			_trace = float(arg.trim_prefix("--trace="))
		elif arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
		elif arg.begins_with("--shot-times="):
			for t in arg.trim_prefix("--shot-times=").split(","):
				_times.append(float(t))
		elif arg.begins_with("--cam="):
			_cam = arg.trim_prefix("--cam=")
		elif arg.begins_with("--speed="):
			_speed = float(arg.trim_prefix("--speed="))
	_times.sort()
	change_scene_to_file.call_deferred(MENU)
	_run.call_deferred()


func _run() -> void:
	var director: Node = null
	while director == null or director.get("player") == null:
		await process_frame
		director = get_first_node_in_group("run_director")
	Engine.time_scale = _speed
	while true:
		await process_frame
		if not is_instance_valid(director):
			return
		_clock = director.elapsed
		if _trace > 0.0 and _clock >= _next_trace:
			_next_trace = _clock + _trace
			_print_trace(director)
		if not _times.is_empty() and _clock >= _times[0] - 0.05:
			var t: float = _times.pop_front()
			await _capture(director, t)
			if _times.is_empty() and _trace <= 0.0:
				quit(0)
				return


func _print_trace(director: Node) -> void:
	var p: Node3D = director.player
	var near := []
	for z in director.alive_enemies():
		if is_instance_valid(z) and not z.is_dead():
			near.append("%s@%s" % [z.data.id, z.global_position.snapped(Vector3.ONE * 0.5)])
	print("[trace] t=%.0f state=%d wave=%d pos=%s hp=%d alive=%d %s" % [_clock, director.state,
		director.wave_number, p.global_position.snapped(Vector3.ONE * 0.1), int(p.health), near.size(), " ".join(near.slice(0, 4))])


func _capture(director: Node, t: float) -> void:
	Engine.time_scale = 1.0
	var cam: Camera3D = null
	if _cam != "":
		var parts := _cam.split(">")
		cam = Camera3D.new()
		cam.fov = 55.0
		director.get_parent().add_child(cam)
		cam.look_at_from_position(_vec(parts[0]), _vec(parts[1]))
		cam.make_current()
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s_%03d.png" % [_shots, int(t)]
	root.get_texture().get_image().save_png(path)
	print("[capture] saved %s at t=%.1f wave=%d alive=%d" % [path, director.elapsed, director.wave_number, director.alive_enemies().size()])
	if cam:
		cam.queue_free()
		director.player.camera.make_current()
	Engine.time_scale = _speed


func _vec(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
