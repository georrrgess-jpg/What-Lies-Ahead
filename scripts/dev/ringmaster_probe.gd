extends RefCounted
## Ringmaster check (a --shot-run script for a level scene): stills of the
## held Ringmaster and a reload strip, saved next to <shot> as
## <shot>_<name>.png, and the Main Event's numbers printed as "[ringmaster]":
##   idle     the meter empty (outer bulbs dark, middle bulbs = the drum's rounds)
##   ready    the meter full: the chip says HOLD AIM, the outer bulbs chase
##   live     the Main Event, firing on the staged zombies: spotlight beams
##   reload   a sheet of the drum swap, RELOAD_FRAMES evenly through it
## Run with the reference zombies staged:
##
##   godot --path . --fixed-fps 30 -- --shot=rm.png --shot-weapon=ringmaster --shot-zombies=1 --shot-run=res://scripts/dev/ringmaster_probe.gd

const RELOAD_FRAMES := [0.06, 0.14, 0.2, 0.3, 0.42, 0.5, 0.57, 0.64, 0.72, 0.78, 0.86, 0.96]
const COLUMNS := 4
const CELL := Vector2i(640, 400)
## The part of the screen the weapon is held in (fractions of the frame).
const CROP := Rect2(0.3, 0.3, 0.7, 0.7)


func run(shot: Node, director: RunDirector) -> void:
	var player := director.player
	var w := player.weapons
	var mode := w.mode as RingmasterMode
	if mode == null:
		print("[ringmaster] the held weapon is not the Ringmaster")
		return
	await shot._wait(30)
	await _save(shot, "idle")
	mode.spotlight = 1.0
	await shot._wait(12)
	await _save(shot, "ready")
	# The Main Event: called, then a stream of rounds at the staged zombies.
	mode.event_left = RingmasterMode.EVENT_TIME
	mode.since_call = RingmasterMode.SPIN_UP
	var kills_before := _dead(director)
	for i in 14:
		shot._aim_at_nearest(director, player)
		w._cooldown = 0.0
		w._fire()
		for f in 2:
			mode.trigger(true, 1.0 / 30.0)
			await shot.get_tree().process_frame
	await _save(shot, "live")
	print("[ringmaster] main event: %d rounds, %d zombies down, %d confetti pops queued or done, meter %.2f" % [
		14, _dead(director) - kills_before, mode._pops.size(), mode.spotlight])
	# The reload strip.
	mode.event_left = 0.0
	mode.spotlight = 0.4
	await shot._wait(10)
	w._ammo[w.current.id]["mag"] = 0
	if not w.start_reload():
		print("[ringmaster] reload did not start")
		return
	var d := w.current.reload_time
	var started := Time.get_ticks_msec()
	var frames: Array[Image] = []
	for k in RELOAD_FRAMES:
		while (Time.get_ticks_msec() - started) / 1000.0 < k * d:
			await shot.get_tree().process_frame
		await RenderingServer.frame_post_draw
		frames.append(_crop(shot))
	var rows := ceili(frames.size() / float(COLUMNS))
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * rows, false, frames[0].get_format())
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLUMNS * CELL.x, i / COLUMNS * CELL.y))
	sheet.save_png(_path(shot, "reload"))
	print("[ringmaster] saved the reload strip (%d frames over %.2f s)" % [frames.size(), d])


func _dead(director: RunDirector) -> int:
	var n := 0
	for z in director.get_tree().get_nodes_in_group("zombies"):
		if z is Zombie and (z as Zombie).is_dead():
			n += 1
	return n


func _crop(shot: Node) -> Image:
	var full := shot.get_viewport().get_texture().get_image()
	var size := Vector2(full.get_size())
	var img := full.get_region(Rect2i(Vector2i(CROP.position * size), Vector2i(CROP.size * size)))
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	return img


func _save(shot: Node, label: String) -> void:
	await RenderingServer.frame_post_draw
	shot.get_viewport().get_texture().get_image().save_png(_path(shot, label))
	print("[ringmaster] saved %s" % label)


func _path(shot: Node, label: String) -> String:
	return String(shot.path).get_basename() + "_%s.png" % label
