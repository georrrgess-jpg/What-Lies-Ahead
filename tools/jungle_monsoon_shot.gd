extends SceneTree
## Still of Lost Temple with the Monsoon twist forced on (developer check):
##   xvfb-run -a godot --rendering-driver opengl3 --path . --resolution 960x540 \
##       --script res://tools/jungle_monsoon_shot.gd -- out.png [x,y,z>tx,ty,tz]
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "monsoon.png"
	var cam_text := args[1] if args.size() > 1 else "3,1.7,18>1,3,-10"
	var level: Node3D = (load("res://scenes/levels/lost_temple.tscn") as PackedScene).instantiate()
	level.get_node("RunDirector").queue_free()
	root.add_child(level)
	var parts := cam_text.split(">")
	var cam := Camera3D.new()
	root.add_child(cam)
	var a := parts[0].split(",")
	var b := parts[1].split(",")
	cam.look_at_from_position(Vector3(float(a[0]), float(a[1]), float(a[2])), Vector3(float(b[0]), float(b[1]), float(b[2])))
	cam.fov = 60.0
	cam.current = true
	for i in 5:
		await process_frame
	var weather: Node = level.get_node("Weather")
	weather.set_process(false)
	weather.call("_apply", 1.0)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(out)
	quit(0)
