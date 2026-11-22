extends RefCounted
## Reload frame strip (a --shot-run script for a level scene): empties a
## round from the held weapon, starts its reload and saves one sheet of
## frames at even shares of the reload, cropped to the viewmodel, as <shot>.
## Run with --fixed-fps 30 so the frames are evenly spaced:
##
##   godot --path . --fixed-fps 30 -- --shot=strip.png --shot-weapon=claw_grabber --shot-run=res://scripts/dev/reload_strip.gd [--shot-count=12]

const COLUMNS := 4
const CELL := Vector2i(480, 360)
## The part of the screen the weapon is held in (fractions of the frame).
const CROP := Rect2(0.22, 0.08, 0.7, 0.92)


func run(shot: Node, director: RunDirector) -> void:
	var w := director.player.weapons
	var count := int(shot._arg("count", "12"))
	await shot._wait(40)
	w.spend_rounds(w.current, 1)
	if not w.start_reload():
		print("[reload] could not start")
		return
	var frames: Array[Image] = []
	for i in count:
		var k := float(i) / float(count - 1) * 0.98
		while w.is_reloading() and w.reload_progress() < k:
			await shot.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var full := shot.get_viewport().get_texture().get_image()
		var size := Vector2(full.get_size())
		var img := full.get_region(Rect2i(Vector2i(CROP.position * size), Vector2i(CROP.size * size)))
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		frames.append(img)
	var rows := ceili(frames.size() / float(COLUMNS))
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * rows, false, frames[0].get_format())
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLUMNS * CELL.x, i / COLUMNS * CELL.y))
	sheet.save_png(shot.path)
	print("[reload] saved %s (%d frames)" % [shot.path, frames.size()])
