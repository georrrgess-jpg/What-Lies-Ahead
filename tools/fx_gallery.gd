extends SceneTree
## Contact sheets for the cosmetic effects, rendered with the real game code:
##
##   xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . --fixed-fps 60 \
##       --resolution 960x540 --script res://tools/fx_gallery.gd -- --mode=<mode> --out=<file.png> [options]
##
## Modes:
##   kill     every kill effect (or --ids=a,b), each 6 m in front of the player
##            in --level, captured at --times (seconds after the kill, default
##            0.2,0.5): one tile per effect and time
##   tracer   every tracer (or --ids), three shots each from the player's view
##            in --level, captured --frames after firing (default 4)
##   icons    the drawn Locker / Shop icons of every kill effect and tracer (or --ids)
##   banners  every banner (or --ids), --page=n of 15 at a time, at the compact
##            player-card shape, plus a narrow (Locker card) shape with --narrow=1
##
## Script mode compiles this file before the autoloads exist, so game
## singletons are reached through root.get_node().

const SIZE := Vector2i(960, 540)

var opts := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
	create_timer(600.0).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _opt(key: String, default_value: String) -> String:
	return String(opts.get(key, default_value))


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _items(slot: StringName) -> Array:
	var ids := _opt("ids", "")
	var out := []
	for it in root.get_node("Cosmetics").items_for(slot):
		if ids == "" or String(it.id) in ids.split(","):
			out.append(it)
	return out


func _run() -> void:
	await _wait(3)
	match _opt("mode", "kill"):
		"banners":
			await _banners()
		"icons":
			await _icons()
		"tracer":
			await _in_level(_tracers)
		_:
			await _in_level(_kills)
	quit(0)


# --- banners ----------------------------------------------------------------------

func _banners() -> void:
	var all := _items(&"banner")
	var page := int(_opt("page", "0"))
	var narrow := _opt("narrow", "0") == "1"
	var per := 24 if narrow else 15
	var cols := 6 if narrow else 3
	var tile := Vector2(150, 92) if narrow else Vector2(306, 84)
	# The project scales its UI from a bigger base size: draw 1:1 here.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.1, 0.18)
	bg.size = Vector2(SIZE)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.position = Vector2(8, 6)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	bg.add_child(grid)
	var view_script = load("res://scripts/cosmetics/banner_view.gd")
	for it in all.slice(page * per, (page + 1) * per):
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		var banner: Control = view_script.new(it, 12.0)
		banner.custom_minimum_size = tile
		box.add_child(banner)
		var label := Label.new()
		label.text = "%s (%s)" % [it.display_name, str(it.params.get("style", it.params.get("pattern", "")))]
		label.add_theme_font_size_override("font_size", 12)
		box.add_child(label)
		grid.add_child(box)
	await _wait(int(_opt("frames", "40")))
	_save(root.get_viewport().get_texture().get_image())


func _icons() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.16, 0.3)
	bg.size = Vector2(SIZE)
	root.add_child(bg)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.position = Vector2(8, 6)
	bg.add_child(grid)
	var icon_script = load("res://scripts/cosmetics/cosmetic_icon.gd")
	for it in _items(&"kill_effect") + _items(&"tracer"):
		var box := VBoxContainer.new()
		var icon: Control = icon_script.new(it)
		icon.custom_minimum_size = Vector2(150, 104)
		box.add_child(icon)
		var label := Label.new()
		label.text = it.display_name
		label.add_theme_font_size_override("font_size", 12)
		box.add_child(label)
		grid.add_child(box)
	await _wait(10)
	_save(root.get_viewport().get_texture().get_image())


# --- in a level -----------------------------------------------------------------

func _in_level(scenario: Callable) -> void:
	var game: Node = root.get_node("Game")
	game.level = root.get_node("GameData").level(StringName(_opt("level", "prize_pier")))
	game.weapon_id = &"pulse_pistol"
	change_scene_to_file(game.level.scene_path)
	var director = null
	while director == null or director.player == null:
		await process_frame
		director = get_first_node_in_group("run_director")
	await _wait(90)
	director.set_process(false)
	director.player.invulnerable = true
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var vm: Array = director.player.camera.find_children("*", "Node3D", false, false)
	for n in vm:
		n.visible = false
	await _wait(5)
	await scenario.call(director)


func _kills(director) -> void:
	var cam: Camera3D = director.player.camera
	var at := cam.global_position - cam.global_transform.basis.z * 6.0 + Vector3.DOWN * 0.3
	var parent: Node = director.get_parent()
	var ke = load("res://scripts/cosmetics/kill_effects.gd")
	var times := Array(_opt("times", "0.2,0.5").split(",")).map(func(s): return float(s))
	var tiles := []
	# unproject_position works in the viewport's (scaled) coordinates.
	var to_image := Vector2(SIZE) / cam.get_viewport().get_visible_rect().size
	var centre := Vector2i(cam.unproject_position(at + Vector3.UP * 0.3) * to_image)
	var half := int(_opt("crop", "130"))
	var crop := Rect2i(centre - Vector2i(half, half), Vector2i(half * 2, half * 2))
	for it in _items(&"kill_effect"):
		ke.play(parent, at, it, false)
		var waited := 0
		for t in times:
			var frames := int(round(t * 60.0)) - waited
			await _wait(frames)
			waited += frames
			tiles.append([root.get_viewport().get_texture().get_image().get_region(crop), "%s %.2fs" % [it.display_name, t]])
		await _wait(maxi(0, 70 - waited))
	_save(_sheet(tiles, 6, Vector2i(158, 158)))


func _tracers(director) -> void:
	var cam: Camera3D = director.player.camera
	var b := cam.global_transform.basis
	var from := cam.global_position - b.z * 0.6 + b.y * -0.18 + b.x * 0.15
	var parent: Node = director.get_parent()
	var ts = load("res://scripts/cosmetics/tracer_styles.gd")
	var tiles := []
	for it in _items(&"tracer"):
		for k in 3:
			var to: Vector3 = from - b.z * (14.0 + k * 10.0) + b.x * (k - 1) * 3.0 + b.y * (k - 1) * 0.8
			if not ts.draw(parent, from, to, 0.04, it):
				load("res://scripts/fx/fx.gd").beam(parent, from, to, Color(0.3, 0.95, 1.0), 0.04)
		await _wait(int(_opt("frames", "4")))
		tiles.append([root.get_viewport().get_texture().get_image().get_region(Rect2i(300, 170, 560, 315)), String(it.display_name)])
		await _wait(50)
	_save(_sheet(tiles, 3, Vector2i(318, 176)))


## Lays images out in a grid with their captions, filling the sheet size.
func _sheet(tiles: Array, cols: int, cell: Vector2i) -> Image:
	var rows := ceili(tiles.size() / float(cols))
	var img := Image.create(cols * cell.x, rows * cell.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.08, 0.14))
	for i in tiles.size():
		var src: Image = tiles[i][0]
		src.convert(Image.FORMAT_RGBA8)
		src.resize(cell.x - 4, cell.y - 4, Image.INTERPOLATE_BILINEAR)
		img.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i((i % cols) * cell.x + 2, (i / cols) * cell.y + 2))
		print("[gallery] tile %d: %s" % [i, tiles[i][1]])
	return img


func _save(img: Image) -> void:
	var out := _opt("out", "/tmp/fx_gallery.png")
	img.save_png(out)
	print("[gallery] saved ", out)
