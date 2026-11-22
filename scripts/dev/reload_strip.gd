extends RefCounted
## Reload frame strip (a --shot-run script for a level scene): empties a
## round from the held weapon, starts its reload and saves one sheet of
## frames at even shares of the reload, cropped to the viewmodel, as <shot>.
## --shot-strip=inspect samples the weapon's inspect instead; --shot-strip=all
## saves <shot>_reload.png, _inspect.png, _rare.png (the rare inspect) and
## _ads.png (a full frame down the sights). Run with --fixed-fps 30 so the frames are evenly spaced:
##
##   godot --path . --fixed-fps 30 -- --shot=strip.png --shot-weapon=claw_grabber --shot-run=res://scripts/dev/reload_strip.gd \
##       [--shot-count=12] [--shot-crop=x,y,w,h (fractions of the frame)] [--shot-strip=inspect|all]

const COLUMNS := 4
const CELL := Vector2i(540, 364)
## The part of the screen the weapon is held in (fractions of the frame), unless --shot-crop says.
const CROP := Rect2(0.44, 0.33, 0.56, 0.67)


func run(shot: Node, director: RunDirector) -> void:
	var crop := CROP
	var c: PackedStringArray = String(shot._arg("crop", "")).split(",", false)
	if c.size() == 4:
		crop = Rect2(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
	var count := int(shot._arg("count", "12"))
	var what := String(shot._arg("strip", "reload"))
	var base := String(shot.path).get_basename()
	await shot._wait(40)
	if what == "reload" or what == "all":
		await _strip(shot, director, false, crop, count, shot.path if what == "reload" else base + "_reload.png")
	if what == "inspect" or what == "all":
		await _strip(shot, director, true, crop, count, shot.path if what == "inspect" else base + "_inspect.png")
	if what == "all":
		director.player.view.inspect_force_rare = true
		await _strip(shot, director, true, crop, count, base + "_rare.png")
		# Down the sights, full frame.
		shot._press("aim", true)
		await shot._wait(50)
		await RenderingServer.frame_post_draw
		shot.get_viewport().get_texture().get_image().save_png(base + "_ads.png")
		shot._press("aim", false)
		print("[reload] saved %s" % (base + "_ads.png"))


func _strip(shot: Node, director: RunDirector, inspecting: bool, crop: Rect2, count: int, file: String) -> void:
	var w := director.player.weapons
	var view := director.player.view
	if inspecting:
		if not view.inspect():
			print("[reload] could not start the inspect")
			return
	else:
		w.spend_rounds(w.current, 1)
		if not w.start_reload():
			print("[reload] could not start")
			return
	var length := view._inspect_length()
	var frames: Array[Image] = []
	for i in count:
		var k := float(i) / float(count - 1) * 0.98
		if inspecting:
			while view.is_inspecting() and view._inspect.clock < k * length:
				await shot.get_tree().process_frame
		else:
			while w.is_reloading() and w.reload_progress() < k:
				await shot.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var full: Image = shot.get_viewport().get_texture().get_image()
		var size := Vector2(full.get_size())
		var img := full.get_region(Rect2i(Vector2i(crop.position * size), Vector2i(crop.size * size)))
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		frames.append(img)
	# Let the motion finish before the next strip.
	while view.is_inspecting() or w.is_reloading():
		await shot.get_tree().process_frame
	await shot._wait(20)
	var rows := ceili(frames.size() / float(COLUMNS))
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * rows, false, frames[0].get_format())
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLUMNS * CELL.x, i / COLUMNS * CELL.y))
	sheet.save_png(file)
	print("[reload] saved %s (%d frames)" % [file, frames.size()])
