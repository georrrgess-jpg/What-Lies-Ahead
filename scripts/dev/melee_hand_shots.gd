extends RefCounted
## Hand-contact captures of a held knife (a --shot-run script for a level
## scene, with --shot-weapon=ticket_flipper or glow_blade): stills of the hold
## and the swings, an equip strip and one strip per inspect trick, saved next
## to <shot> as <shot>_<name>.png. Run with --fixed-fps 30 so strip frames are
## evenly spaced whatever the render speed:
##
##   godot --path . --fixed-fps 30 -- --shot=/tmp/k.png --shot-weapon=ticket_flipper --shot-zombies=0 --shot-hud=0
##       --shot-run=res://scripts/dev/melee_hand_shots.gd [--shot-sets=stills,equip,tricks] [--shot-tricks=0,1,5]
##       [--shot-step=0.1] [--shot-from=0] [--shot-to=99] [--shot-cell=1]
##
## Trick ids: TicketFlipperTricks.Trick for the flipper, 0-2 (toss, twirl,
## snap) for the Glow Blade. --shot-from/--shot-to keep a strip to that window
## of each trick (seconds), for close looks at a release or a catch; --shot-cell
## scales the strips' cells (2: 800 x 600 each, with a window to match).

const COLUMNS := 6
const CELL := Vector2i(400, 300)
## The part of the screen the knife is held in (fractions of the frame).
const CROP := Rect2(0.3, 0.2, 0.7, 0.8)
const STILL_CROP := Rect2(0.35, 0.25, 0.65, 0.75)

## The strips' cell size (CELL times --shot-cell).
var _cell := CELL


func run(shot: Node, director: RunDirector) -> void:
	var player := director.player
	var view := player.view
	var sets := String(shot._arg("sets", "stills,equip,tricks")).split(",")
	await shot._wait(40)
	if sets.has("equip"):
		view.show_weapon(view.data)
		var frames: Array[Image] = []
		for i in 18:
			await shot._wait(2)
			frames.append(await _frame(shot, CROP))
		_sheet(frames).save_png(_out(shot, "equip"))
		await shot._wait(40)
	if sets.has("stills"):
		await shot._wait(60)
		(await _frame(shot, STILL_CROP, false)).save_png(_out(shot, "idle"))
		for spec in [["light", 0.25], ["light", 0.5], ["windup", 1.0], ["heavy", 0.2], ["heavy", 0.45]]:
			await shot._swing(director, player, String(spec[0]), float(spec[1]))
			(await _frame(shot, STILL_CROP, false)).save_png(_out(shot, "%s_%02d" % [spec[0], int(float(spec[1]) * 100.0)]))
			shot._press("aim", false)
			shot._press("fire", false)
			player.weapons.set_physics_process(true)
			player.set_physics_process(true)
			await shot._wait(90)
	if sets.has("tricks"):
		await _tricks(shot, view)


func _tricks(shot: Node, view: WeaponView) -> void:
	_cell = Vector2i(Vector2(CELL) * float(shot._arg("cell", "1")))
	var driver: Object = view.get("_view_driver")
	var flipper: TicketFlipperTricks = driver.get("_tricks") if driver.get("_tricks") is TicketFlipperTricks else null
	var step := float(shot._arg("step", "0.1"))
	var from := float(shot._arg("from", "0"))
	var to := float(shot._arg("to", "99"))
	var ids := String(shot._arg("tricks", "0,1,2,3,4,5" if flipper else "0,1,2")).split(",")
	for id in ids:
		if flipper:
			flipper.force = int(id)
		else:
			driver.set("force", int(id))
		while not view.inspect():
			await shot.get_tree().process_frame
		var frames: Array[Image] = []
		var t := from
		var end := minf(to, view._inspect.length)
		while t <= end + 0.001:
			while view.is_inspecting() and view._inspect.clock < t:
				await shot.get_tree().process_frame
			frames.append(await _frame(shot, CROP))
			t += step
		_sheet(frames).save_png(_out(shot, "trick%s" % id))
		while view.is_inspecting():
			await shot.get_tree().process_frame
		await shot._wait(20)


func _frame(shot: Node, crop: Rect2, cell := true) -> Image:
	await RenderingServer.frame_post_draw
	var full := shot.get_viewport().get_texture().get_image()
	var size := Vector2(full.get_size())
	var img := full.get_region(Rect2i(Vector2i(crop.position * size), Vector2i(crop.size * size)))
	if cell:
		img.resize(_cell.x, _cell.y, Image.INTERPOLATE_BILINEAR)
	return img


func _sheet(frames: Array[Image]) -> Image:
	var rows := ceili(frames.size() / float(COLUMNS))
	var sheet := Image.create(_cell.x * COLUMNS, _cell.y * rows, false, frames[0].get_format())
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, _cell), Vector2i(i % COLUMNS * _cell.x, i / COLUMNS * _cell.y))
	return sheet


func _out(shot: Node, name: String) -> String:
	var file: String = String(shot.path).get_basename() + "_%s.png" % name
	print("[hands] saved %s" % file)
	return file
