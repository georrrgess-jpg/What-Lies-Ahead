extends RefCounted
## The loadout station's FREE WEAPON SWAP row with every weapon held in turn
## (its neighbours either side), at 1600x900 and 1024x768, saved as one sheet
## next to the --shot path: <shot>_swap_<w>x<h>.png, and the contact sheet of
## every picture (scripts/dev/thumbs_sheet.gd). Needs a renderer:
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --profile=<scratch copy> \
##       --shot=/tmp/x.png --shot-scene=kiosk --shot-run=res://scripts/dev/kiosk_thumbs_probe.gd

const SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(1024, 768)]
const COLS := 3

var _tree: SceneTree


func run(shot: Node, director: Node) -> void:
	_tree = shot.get_tree()
	var hud: Node = director.get("hud")
	var station: StationPanel = hud.get("_station")
	var weapons := GameData.weapons()
	(hud.get("_thumbs") as WeaponThumbs).bake(weapons)
	# The contact sheet of every picture too (<shot>_thumbs.png).
	await (load("res://scripts/dev/thumbs_sheet.gd") as GDScript).new().run(shot, null)
	for s in SIZES:
		_tree.root.size = s
		await _frames(30)
		var shots: Array[Image] = []
		for i in weapons.size():
			station.set_swap("PRIMARY  ·  slot 1", weapons, i, "Z", "X")
			await _frames(4)
			await RenderingServer.frame_post_draw
			var cards: Array = station.get("_swap_cards")
			var rect := _screen_rect(cards[0]).merge(_screen_rect(cards[2])).grow(4)
			var full := _tree.root.get_texture().get_image()
			shots.append(full.get_region(Rect2i(rect).intersection(Rect2i(Vector2i.ZERO, full.get_size()))))
		var cell := shots[0].get_size()
		var rows := ceili(shots.size() / float(COLS))
		var sheet := Image.create_empty(cell.x * COLS, cell.y * rows, false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, cell), Vector2i((i % COLS) * cell.x, (i / COLS) * cell.y))
		var file := "%s_swap_%dx%d.png" % [String(shot.path).get_basename(), s.x, s.y]
		sheet.save_png(file)
		print("[kiosk] saved %s" % file)


static func _screen_rect(c: Control) -> Rect2:
	return c.get_viewport().get_final_transform() * c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame
