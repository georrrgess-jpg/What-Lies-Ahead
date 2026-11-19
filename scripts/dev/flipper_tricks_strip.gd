extends RefCounted
## Ticket Flipper trick strips (a --shot-run script for a level scene, with
## --shot-weapon=ticket_flipper): plays each balisong trick in turn
## (TicketFlipperTricks.Trick) and saves one sheet per trick as
## <shot>_<n>.png, frames --shot-step seconds apart (default 0.1). Run with
## --fixed-fps 30 so the frames are evenly spaced whatever the render speed:
##
##   godot --path . --fixed-fps 30 -- --shot=/tmp/t.png --shot-weapon=ticket_flipper --shot-run=res://scripts/dev/flipper_tricks_strip.gd [--shot-tricks=0,5] [--shot-step=0.1]

const COLUMNS := 6
const CELL := Vector2i(400, 300)
const CROP := Rect2(0.12, 0.0, 0.8, 1.0)


func run(shot: Node, director: RunDirector) -> void:
	var view := director.player.view
	var tricks: TicketFlipperTricks = view.get("_view_driver").get("_tricks")
	var step := float(shot._arg("step", "0.1"))
	var which := String(shot._arg("tricks", "0,1,2,3,4,5")).split(",")
	await shot._wait(40)
	for id in which:
		tricks.force = int(id)
		while not view.inspect():
			await shot.get_tree().process_frame
		var length := TicketFlipperTricks.LENGTHS[int(id)]
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
		var out := shot.path.get_basename() + "_%s.png" % id
		sheet.save_png(out)
		print("[tricks] saved %s (%d frames)" % [out, frames.size()])
		while view.is_inspecting():
			await shot.get_tree().process_frame
		await shot._wait(20)
