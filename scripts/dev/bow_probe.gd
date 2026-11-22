extends RefCounted
## Bullseye Longbow capture (a --shot-run script for a level scene, with
## --shot-weapon=bullseye_bow): stills of the draw, the loose and the nock
## reload saved as one sheet <shot> plus full-size frames <shot>_<name>.png.
## Run with --fixed-fps 30 so the timings hold whatever the render speed:
##
##   godot --path . --fixed-fps 30 -- --shot=bow.png --shot-weapon=bullseye_bow --shot-run=res://scripts/dev/bow_probe.gd [--shot-ads=1]

const COLUMNS := 4
const CELL := Vector2i(480, 270)


func run(shot: Node, director: RunDirector) -> void:
	var player := director.player
	var w := player.weapons
	var frames: Array[Image] = []
	var names: Array[String] = []
	var aim: bool = shot._arg("ads", "0") == "1"
	if aim:
		Input.action_press(&"aim")
	await shot._wait(50)
	await _grab(shot, frames, names, "idle")
	Input.action_press(&"fire")
	await _until(shot, func() -> bool: return w.charge_progress() >= 0.5)
	await _grab(shot, frames, names, "half")
	await _until(shot, func() -> bool: return w.charge_progress() >= 1.0)
	await shot.get_tree().physics_frame
	await _grab(shot, frames, names, "full")
	# Held on past the Bullseye window: fatigue.
	for i in 40:
		await shot.get_tree().physics_frame
	await _grab(shot, frames, names, "tired")
	Input.action_release(&"fire")
	Input.action_press(&"fire")
	await _until(shot, func() -> bool: return w.charge_progress() >= 1.0)
	await shot.get_tree().physics_frame
	Input.action_release(&"fire")
	await shot.get_tree().physics_frame
	await _grab(shot, frames, names, "loose")
	for i in 3:
		await shot.get_tree().physics_frame
	await _grab(shot, frames, names, "ring")
	await _until(shot, func() -> bool: return w.is_reloading())
	for k in [0.15, 0.3, 0.45, 0.6, 0.72, 0.84, 0.95]:
		await _until(shot, func() -> bool: return not w.is_reloading() or w.reload_progress() >= k)
		await _grab(shot, frames, names, "nock%02d" % int(k * 100))
	if aim:
		Input.action_release(&"aim")
	await _until(shot, func() -> bool: return not w.is_reloading())
	await shot._wait(10)
	# Aimed: the sight up at full draw.
	Input.action_press(&"aim")
	Input.action_press(&"fire")
	await _until(shot, func() -> bool: return w.charge_progress() >= 1.0 and player.aim_blend >= 0.99)
	await _grab(shot, frames, names, "ads_full")
	Input.action_release(&"fire")
	Input.action_release(&"aim")
	await _until(shot, func() -> bool: return w.is_reloading())
	await _until(shot, func() -> bool: return not w.is_reloading())
	# A Bullseye at the nearest zombie's head: in flight, then stuck.
	var target := _nearest(player)
	if target:
		var eye := player.camera.global_position
		var to := target.global_position + Vector3.UP * 1.55 * target.data.body_scale - eye
		player.set_look(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()) + 0.004)
		await shot._wait(12)
		Input.action_press(&"fire")
		await _until(shot, func() -> bool: return w.charge_progress() >= 1.0)
		await shot.get_tree().physics_frame
		Input.action_release(&"fire")
		for i in 3:
			await shot.get_tree().physics_frame
		await _grab(shot, frames, names, "flight")
		await shot._wait(20)
		await _grab(shot, frames, names, "stuck")
	# The inspect: the pluck and the spin.
	await _until(shot, func() -> bool: return not w.is_reloading())
	await shot._wait(15)
	var view := player.view
	if view.inspect():
		for t in [0.5, 1.0, 1.1, 1.8, 2.1, 2.9]:
			await _until(shot, func() -> bool: return not view.is_inspecting() or view._inspect.clock >= t)
			await _grab(shot, frames, names, "inspect%02d" % int(t * 10))
	var rows := ceili(frames.size() / float(COLUMNS))
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * rows, false, frames[0].get_format())
	for i in frames.size():
		var img := frames[i].duplicate() as Image
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLUMNS * CELL.x, i / COLUMNS * CELL.y))
	sheet.save_png(shot.path)
	for i in frames.size():
		if names[i] in ["idle", "half", "full", "loose", "nock45", "nock72", "tired", "ads_full", "stuck", "inspect11", "inspect21"]:
			frames[i].save_png(shot.path.get_basename() + "_" + names[i] + ".png")
	print("[bow] saved %s (%d frames)" % [shot.path, frames.size()])


func _grab(shot: Node, frames: Array[Image], names: Array[String], label: String) -> void:
	await RenderingServer.frame_post_draw
	frames.append(shot.get_viewport().get_texture().get_image())
	names.append(label)


## Waits physics frames until `done` is true (at most 300).
func _until(shot: Node, done: Callable) -> void:
	for i in 300:
		if done.call():
			return
		await shot.get_tree().physics_frame
	print("[bow] timed out waiting")


func _nearest(player: Player) -> Zombie:
	var best: Zombie = null
	var best_d := 1e9
	for node in player.get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z and not z.is_dead():
			var d := z.global_position.distance_to(player.global_position)
			if d < best_d:
				best = z
				best_d = d
	return best
