extends RefCounted
## Inspect still (a --shot-run script for a level scene): starts the held
## weapon's inspect and saves the full frame once its clock passes
## --shot-at seconds (full resolution, for close crops of the hands):
##
##   godot --path . --resolution 3840x2160 --fixed-fps 30 -- --shot=still.png --shot-weapon=jinglestar \
##       --shot-run=res://scripts/dev/inspect_still.gd --shot-at=1.2 [--shot-rare=1]


func run(shot: Node, director: RunDirector) -> void:
	var view := director.player.view
	view.inspect_force_rare = shot._arg("rare", "0") == "1"
	var at := float(shot._arg("at", "1.0"))
	await shot._wait(40)
	if not view.inspect():
		print("[inspect] could not start")
		return
	while view.is_inspecting() and view._inspect.clock < at:
		await shot.get_tree().process_frame
	await RenderingServer.frame_post_draw
	shot.get_viewport().get_texture().get_image().save_png(shot.path)
	print("[inspect] saved %s at %.2f s" % [shot.path, at])
