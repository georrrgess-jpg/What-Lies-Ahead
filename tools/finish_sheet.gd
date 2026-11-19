extends SceneTree
## Finish check: renders a grid of weapon models, one tile per (finish, weapon),
## so new weapon finishes can be judged side by side.
##
##   godot --path . --resolution 1440x810 --script res://tools/finish_sheet.gd -- <out.png> --finishes=a,b,c --weapons=x,y [--cols=3] [--tile=480x270] [--time=0.0] [--zoom=0.85] [--dark=1]
##
## --cells=a,b,c instead of --finishes puts those energy cells on the bare
## finish (the Lava Lampoon's lamp takes the cell's colour).
##
## Weapons run along the rows, finishes along the columns. --time advances the
## animated finishes by that many seconds before the capture (frames are
## stepped, so it is approximate). Script mode compiles this file before the
## autoloads exist, so it only uses untyped references to game classes.

const COSMETICS_SCRIPT := "res://scripts/player/weapon_cosmetics.gd"
const COSMETIC_DIRS := ["finishes", "charms", "decals", "gloves", "operators", "mastery", "cells"]

var opts := {}
var out_path := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
		elif out_path == "":
			out_path = a
	_run.call_deferred()


func _find(id: String):
	for dir in COSMETIC_DIRS:
		var path := "res://data/cosmetics/%s/%s.tres" % [dir, id]
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _run() -> void:
	await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var finishes := String(opts.get("finishes", "")).split(",", false)
	var cells := String(opts.get("cells", "")).split(",", false)
	var wanted := String(opts.get("weapons", "pulse_pistol")).split(",", false)
	var parts := String(opts.get("tile", "480x270")).split("x")
	var size := Vector2i(int(parts[0]), int(parts[1]))
	var grid := GridContainer.new()
	grid.columns = int(opts.get("cols", finishes.size() + cells.size()))
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	root.add_child(grid)
	var game_data = root.get_node("GameData")
	for wid in wanted:
		for w in game_data.weapons():
			if String(w.id) == wid:
				for fid in finishes:
					_tile(grid, size, w, _find(fid))
				for cid in cells:
					_tile(grid, size, w, null, _find(cid))
	var t := float(opts.get("time", "0"))
	var steps := int(t * 30.0) + 6
	for i in steps:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path)
	quit()


func _tile(grid: GridContainer, size: Vector2i, w, finish, cell = null) -> void:
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = size
	grid.add_child(holder)
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.24, 0.34) if opts.has("dark") else Color(0.36, 0.42, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.6, 0.86)
	env.ambient_light_energy = 0.3 if opts.has("dark") else 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	for spec in [[Vector3(-42, 150, 0), 0.5 if opts.has("dark") else 1.4, Color(1.0, 0.9, 0.78)], [Vector3(-10, -40, 0), 0.5, Color(0.6, 0.8, 1.0)]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = spec[0]
		l.light_energy = spec[1]
		l.light_color = spec[2]
		vp.add_child(l)
	var model: Node3D = w.viewmodel.instantiate()
	for n in model.find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		if nm.begins_with("Arm") or nm.ends_with("Holo"):
			(n as Node3D).visible = false
	var lo := {}
	if finish != null:
		lo["finish"] = finish
	if cell != null:
		lo["cell"] = cell
	load(COSMETICS_SCRIPT).apply(model, w, lo)
	vp.add_child(model)
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var xf := Transform3D.IDENTITY
		var p: Node = m
		while p and p != model:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b := xf * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	model.position = -box.get_center()
	var cam := Camera3D.new()
	cam.fov = 28.0
	vp.add_child(cam)
	var radius := box.size.length() * 0.5
	cam.look_at_from_position(Vector3(-0.95, 0.3, -0.32).normalized() * radius / tan(deg_to_rad(14.0)) * float(opts.get("zoom", "0.85")), Vector3.ZERO)
