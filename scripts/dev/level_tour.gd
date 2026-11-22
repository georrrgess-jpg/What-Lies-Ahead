extends RefCounted
## Several stills of one level from a list of free cameras, in one launch
## (loading a big map is the slow part). Used through screenshot.gd:
##
##   xvfb-run -a ... --path . --resolution 1600x900 -- --profile=<copy> --shot=out.png \
##       --shot-level=endless_studio --shot-hud=0 --shot-run=res://scripts/dev/level_tour.gd \
##       --shot-tour-cams="name:x,y,z>tx,ty,tz;name2:..." [--shot-open=1] [--shot-frames=60]
##
## Saves <shot>_<name>.png per camera. --shot-open=1 opens every Endless gate
## first (the districts beyond them in view).


func run(shot: Node, director: Node) -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-") and a.contains("="):
			args[a.get_slice("=", 0).trim_prefix("--shot-")] = a.substr(a.find("=") + 1)
	var base := String(args.get("", ""))
	var path: String = shot.get("path")
	var frames := int(args.get("frames", "60"))
	if args.get("open", "0") == "1":
		for gate in shot.get_tree().get_nodes_in_group("endless_gate"):
			gate.call("open")
	var cam := Camera3D.new()
	cam.fov = float(args.get("fov", "70"))
	director.get_parent().add_child(cam)
	cam.make_current()
	for entry in String(args.get("tour-cams", base)).split(";", false):
		var cam_name := entry.get_slice(":", 0)
		var parts := entry.get_slice(":", 1).split(">")
		cam.look_at_from_position(_vec(parts[0]), _vec(parts[1]))
		for i in frames:
			await shot.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var file := "%s_%s.png" % [path.get_basename(), cam_name]
		shot.get_viewport().get_texture().get_image().save_png(file)
		print("[tour] saved ", file, "  fps=", Engine.get_frames_per_second())


static func _vec(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
