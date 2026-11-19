extends RefCounted
## Bakes every weapon's WeaponThumbs picture and saves them as one contact
## sheet (6 a row, each on a checker so the transparent frame shows), next to
## the --shot path as <shot>_thumbs.png. Prints, per weapon, the box the
## picture's opaque pixels fill ("[thumbs] <id> box=x,y wxh"). Needs a renderer:
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --profile=<scratch copy> \
##       --shot=/tmp/x.png --shot-scene=menu --shot-run=res://scripts/dev/thumbs_sheet.gd

const COLS := 6
const PAD := 6


func run(shot: Node, _menu: Node) -> void:
	var thumbs := WeaponThumbs.new()
	shot.add_child(thumbs)
	var weapons := GameData.weapons()
	thumbs.bake(weapons)
	for i in 1200:
		await shot.get_tree().process_frame
		if weapons.all(func(w: WeaponData) -> bool: return WeaponThumbs.texture(w).get_meta("baked")):
			break
	var cell := WeaponThumbs.SIZE + Vector2i(PAD, PAD)
	var rows := ceili(weapons.size() / float(COLS))
	var sheet := Image.create_empty(cell.x * COLS + PAD, cell.y * rows + PAD, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.08, 0.16))
	for i in weapons.size():
		var w := weapons[i]
		var image := WeaponThumbs.texture(w).get_image()
		image.convert(Image.FORMAT_RGBA8)
		var at := Vector2i(PAD + (i % COLS) * cell.x, PAD + (i / COLS) * cell.y)
		var back := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
		for y in back.get_height():
			for x in back.get_width():
				back.set_pixel(x, y, Color(0.22, 0.2, 0.3) if (x / 12 + y / 12) % 2 == 0 else Color(0.28, 0.26, 0.36))
		back.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		sheet.blit_rect(back, Rect2i(Vector2i.ZERO, back.get_size()), at)
		var used := image.get_used_rect()
		print("[thumbs] %s box=%d,%d %dx%d baked=%s" % [w.id, used.position.x, used.position.y, used.size.x, used.size.y, WeaponThumbs.texture(w).get_meta("baked")])
	var path: String = shot.path.get_basename() + "_thumbs.png"
	sheet.save_png(path)
	print("[thumbs] saved %s" % path)
