extends RefCounted
## Inspect frame strip (a --shot-run script for a level scene): starts the
## held weapon's inspect and saves one sheet of frames 0.1 s apart, cropped
## to the viewmodel, as <shot>. Run with --fixed-fps 30 so the frames are
## evenly spaced whatever the render speed:
##
##   godot --path . --fixed-fps 30 -- --shot=strip.png --shot-weapon=coin_op --shot-run=res://scripts/dev/inspect_strip.gd [--shot-rare=1] [--shot-step=0.1] [--shot-length=3.0]

const COLUMNS := 6
const CELL := Vector2i(400, 300)
## The part of the screen the weapon is held in (fractions of the frame).
const CROP := Rect2(0.22, 0.08, 0.7, 0.92)


func run(shot: Node, director: RunDirector) -> void:
	var player := director.player
	var view := player.view
	view.inspect_force_rare = shot._arg("rare", "0") == "1"
	var step := float(shot._arg("step", "0.1"))
	var length := float(shot._arg("length", "2.7"))
	await shot._wait(40)
	if not view.inspect():
		print("[inspect] could not start")
		return
	var frames: Array[Image] = []
	var t := 0.0
	while t <= length + 0.001:
		while view.is_inspecting() and view._inspect.clock < t:
			await shot.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var full := shot.get_viewport().get_texture().get_image()
		var size := Vector2(full.get_size())
		var img := full.get_region(Rect2i(Vector2i(CROP.position * size), Vector2i(CROP.size * size)))
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		frames.append(img)
		t += step
	var rows := ceili(frames.size() / float(COLUMNS))
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * rows, false, frames[0].get_format())
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLUMNS * CELL.x, i / COLUMNS * CELL.y))
	sheet.save_png(shot.path)
	print("[inspect] saved %s (%d frames)" % [shot.path, frames.size()])
