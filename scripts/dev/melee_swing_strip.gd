extends RefCounted
## Melee swing frame strip (a --shot-run script for a level scene): draws the
## held melee weapon, waits, then plays a scripted sequence through the real
## inputs (two light swings, a full wind-up held, the heavy released) and
## saves one sheet of frames every --shot-step seconds, cropped to the
## viewmodel, as <shot>. Run with --fixed-fps 30 so frames are evenly spaced:
##
##   godot --path . --fixed-fps 30 -- --shot=strip.png --shot-weapon=jinglestar --shot-zombies=0 \
##       --shot-run=res://scripts/dev/melee_swing_strip.gd [--shot-step=0.1] [--shot-seq=equip|light|heavy|all]
##
## equip: the draw and the first second at rest; light: two light swings;
## heavy: a wind-up held to full and the release; all: one after the other.

const COLUMNS := 6
const CELL := Vector2i(400, 225)
const CROP := Rect2(0.1, 0.0, 0.9, 1.0)

var _shot: Node
var _frames: Array[Image] = []
var _step := 0.1
var _clock := 0.0
var _next := 0.0


func run(shot: Node, director: RunDirector) -> void:
	_shot = shot
	_step = float(shot._arg("step", "0.1"))
	var seq := String(shot._arg("seq", "all"))
	var player := director.player
	player.set_physics_process(true)
	player.controls_enabled = true
	player.invulnerable = true
	var tree := shot.get_tree()
	if seq == "equip" or seq == "all":
		# Away and back: the draw.
		var id := player.weapons.current.id
		player.weapons.equip(&"pulse_pistol")
		await _run_for(tree, 0.8)
		player.weapons.equip(id)
		await _run_for(tree, 2.2, true)
	else:
		await _run_for(tree, 1.0)
	if seq == "light" or seq == "all":
		for i in 2:
			shot._press("fire", true)
			await _run_for(tree, 0.1, true)
			shot._press("fire", false)
			await _run_for(tree, 0.65, true)
		await _run_for(tree, 0.6, true)
	if seq == "heavy" or seq == "all":
		shot._press("aim", true)
		await _run_for(tree, 1.3, true)
		shot._press("aim", false)
		await _run_for(tree, 1.6, true)
	_save()


## Lets `seconds` of game time pass, capturing a frame every step when `capture`.
func _run_for(tree: SceneTree, seconds: float, capture := false) -> void:
	var end := _clock + seconds
	while _clock < end:
		await tree.process_frame
		_clock += 1.0 / 30.0
		if capture and _clock >= _next:
			_next = _clock + _step
			await RenderingServer.frame_post_draw
			var full := _shot.get_viewport().get_texture().get_image()
			var size := Vector2(full.get_size())
			var img := full.get_region(Rect2i(Vector2i(CROP.position * size), Vector2i(CROP.size * size)))
			img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
			_frames.append(img)


func _save() -> void:
	if _frames.is_empty():
		print("[strip] no frames")
		return
	var rows := ceili(_frames.size() / float(COLUMNS))
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * rows, false, _frames[0].get_format())
	for i in _frames.size():
		sheet.blit_rect(_frames[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLUMNS * CELL.x, i / COLUMNS * CELL.y))
	sheet.save_png(_shot.path)
	print("[strip] saved %s (%d frames)" % [_shot.path, _frames.size()])
