extends SceneTree
## Contact sheet of Prize Prints worn on weapon models: one tile per print, to
## judge the print layer (pattern seed, shine grade, rare prints).
##
##   xvfb-run -a godot --path . --resolution 960x540 --script res://tools/print_sheet.gd -- <out.png> [options]
##
## Options (comma lists; every combination becomes a tile, in this order):
##   --finishes=fin_a,fin_b   finish ids (default: the whole series)
##   --weapons=ion_carbine    weapon ids (default: the first weapon)
##   --seeds=17               pattern seeds
##   --shines=0.75            shine rolls
##   --vars=none,glitter,holo,misprint   rare prints ("none" = standard, "plain" = no print at all)
##   --columns=5  --tile=192x135  --time=0.6 (seconds of animation before the capture)
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes.

const COSMETICS_SCRIPT := "res://scripts/player/weapon_cosmetics.gd"

var opts := {}
var out_path := ""
var tile := Vector2i(192, 135)
var _next_id := 900000


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
		elif out_path == "":
			out_path = a
	_run.call_deferred()


func _list(key: String, fallback: Array) -> Array:
	return Array(String(opts[key]).split(",", false)) if opts.has(key) else fallback


func _run() -> void:
	await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	RenderingServer.set_default_clear_color(Color(0.16, 0.13, 0.24))
	var data: Node = root.get_node("GameData")
	var cosmetics: Node = root.get_node("Cosmetics")
	var prints = load("res://scripts/economy/prints/prize_prints.gd")
	if opts.has("tile"):
		var wh := String(opts["tile"]).split("x")
		tile = Vector2i(int(wh[0]), int(wh[1]))
	var columns := int(opts.get("columns", "5"))
	var finishes := _list("finishes", Array(prints.series().finishes).map(func(f): return String(f)))
	var weapons := _list("weapons", [String(data.weapons()[0].id)])
	var tiles := 0
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	root.add_child(grid)
	for f in finishes:
		for w in weapons:
			for sd in _list("seeds", ["17"]):
				for sh in _list("shines", ["0.75"]):
					for v in _list("vars", ["none"]):
						_tile(grid, data.weapon(StringName(w)), cosmetics.item(StringName(f)), int(sd), float(sh), String(v))
						tiles += 1
	var wait := int(float(opts.get("time", "0.6")) * 60.0) + 4
	for i in wait:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var rows := ceili(tiles / float(columns))
	img = img.get_region(Rect2i(0, 0, mini(img.get_width(), tile.x * columns), mini(img.get_height(), tile.y * rows)))
	img.save_png(out_path)
	print("[sheet] %d prints -> %s" % [tiles, out_path])
	quit()


func _tile(grid: Control, weapon, finish, seed_value: int, shine: float, variant: String) -> void:
	var box := VBoxContainer.new()
	grid.add_child(box)
	box.add_theme_constant_override("separation", 0)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(tile.x, tile.y - 16)
	var vp := SubViewport.new()
	vp.size = Vector2i(tile.x, tile.y - 16)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	box.add_child(svc)
	var label := Label.new()
	label.text = "%s s%d %.2f %s" % [String(finish.display_name), seed_value, shine, variant]
	label.add_theme_font_size_override("font_size", 11)
	label.custom_minimum_size = Vector2(tile.x, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	box.add_child(label)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.13, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.68, 0.95)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	for spec in [[Vector3(-35, 35, 0), 1.35, Color(1.0, 0.93, 0.85)], [Vector3(-12, -140, 0), 0.8, Color(0.75, 0.6, 1.0)],
			[Vector3(-20, 170, 0), 0.9, Color(0.45, 0.9, 1.0)]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = spec[0]
		l.light_energy = spec[1]
		l.light_color = spec[2]
		vp.add_child(l)
	var model: Node3D = weapon.viewmodel.instantiate()
	var cos = load(COSMETICS_SCRIPT)
	cos.prepare_preview(model)
	vp.add_child(model)
	var loadout := {"finish": finish}
	if variant != "plain":
		_next_id += 1
		loadout["print"] = {"id": "sheet%d" % _next_id, "f": String(finish.id), "seed": seed_value, "shine": shine,
			"var": "" if variant == "none" else variant, "serial": 7}
	cos.apply(model, weapon, loadout)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.environment = env
	vp.add_child(cam)
	var focus: AABB = cos.visible_bounds(model)
	var centre := focus.get_center()
	var radius := maxf(focus.size.length() * 0.5, 0.02)
	var dir := Vector3(-1.0, 0.3, 0.35).normalized()
	cam.near = 0.005
	cam.look_at_from_position(centre + dir * radius / tan(deg_to_rad(15.0)) * float(opts.get("zoom", "0.6")), centre)
