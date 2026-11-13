extends SceneTree
## Contact sheet of weapon attachments (energy cells, charms, decals, sights)
## worn on weapon models, one tile per item, to judge new cosmetics.
##
##   xvfb-run -a godot --path . --resolution 960x540 --script res://tools/attach_sheet.gd -- <out.png> [options]
##
## Options:
##   --slot=weapon_cell|weapon_charm|weapon_decal|weapon_sight
##   --ids=a,b,...      item ids (default: every item of the slot whose id has --prefix)
##   --prefix=cellx_    with no --ids: the id prefix to pick items by
##   --weapon=<id>      the weapon to wear them (default: the first weapon)
##   --view=close|side  close: framed on the attachment; side: the whole weapon from its left
##   --time=<s>         seconds to let animations run before the capture
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes.

const COSMETICS_SCRIPT := "res://scripts/player/weapon_cosmetics.gd"
const COLUMNS := 5
const TILE := Vector2i(192, 135)

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


func _run() -> void:
	await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var cosmetics: Node = root.get_node("Cosmetics")
	var data: Node = root.get_node("GameData")
	var slot := StringName(String(opts.get("slot", "weapon_cell")))
	var weapon = data.weapon(StringName(String(opts.get("weapon", "")))) if opts.has("weapon") else data.weapons()[0]
	var items := []
	var ids := String(opts.get("ids", "")).split(",", false)
	for it in cosmetics.items_for(slot, weapon.id):
		if (ids.is_empty() and String(it.id).begins_with(String(opts.get("prefix", "")))) or String(it.id) in ids:
			items.append(it)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	root.add_child(grid)
	for it in items:
		grid.add_child(_tile(weapon, slot, it))
	var wait := int(float(opts.get("time", "0.6")) * 60.0) + 4
	for i in wait:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var rows := ceili(items.size() / float(COLUMNS))
	img = img.get_region(Rect2i(0, 0, mini(img.get_width(), TILE.x * COLUMNS), mini(img.get_height(), TILE.y * rows)))
	img.save_png(out_path)
	print("[sheet] %d items -> %s" % [items.size(), out_path])
	quit()


func _tile(weapon, slot: StringName, item) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(TILE.x, TILE.y - 16)
	var vp := SubViewport.new()
	vp.size = Vector2i(TILE.x, TILE.y - 16)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	box.add_child(svc)
	var label := Label.new()
	label.text = String(item.display_name)
	label.add_theme_font_size_override("font_size", 11)
	label.custom_minimum_size = Vector2(TILE.x, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.13, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.75, 0.95)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	vp.add_child(sun)
	var model: Node3D = weapon.viewmodel.instantiate()
	var cos = load(COSMETICS_SCRIPT)
	cos.prepare_preview(model)
	var key: String = {"weapon_cell": "cell", "weapon_charm": "charm", "weapon_decal": "decal", "weapon_sight": "sight"}[String(slot)]
	vp.add_child(model)
	cos.apply(model, weapon, {key: item})
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.environment = env
	vp.add_child(cam)
	var focus: AABB = cos.visible_bounds(model)
	if String(opts.get("view", "close")) == "close":
		focus = _focus(model, slot, focus)
	var centre := focus.get_center()
	var radius := maxf(focus.size.length() * 0.5, 0.02)
	var dir := Vector3(-1.0, 0.35, 0.45).normalized()
	if slot == &"weapon_sight":
		dir = Vector3(-0.35, 0.3, 1.0).normalized()
	cam.look_at_from_position(centre + dir * radius / tan(deg_to_rad(15.0)) * 1.05, centre)
	return box


## The bounds of the attachment itself.
func _focus(model: Node3D, slot: StringName, whole: AABB) -> AABB:
	var cos = load(COSMETICS_SCRIPT)
	var out := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var take := false
		match String(slot):
			"weapon_charm": take = mi.get_parent().name == "WeaponCharm" or mi.get_parent().get_parent().name == "WeaponCharm"
			"weapon_decal": take = mi.name == "DecalSkin"
			"weapon_sight": take = String(mi.name).ends_with("_Body")
			"weapon_cell": take = mi.name in ["Cell", "Capsules", "Drum"]
		if not take:
			continue
		var b: AABB = cos.to_model(model, mi) * mi.mesh.get_aabb()
		if slot == &"weapon_charm":
			b = mi.global_transform * mi.mesh.get_aabb()
			b.position -= model.global_position
		out = b if first else out.merge(b)
		first = false
	if first:
		return whole
	return out.grow(out.size.length() * (0.25 if slot == &"weapon_cell" else 0.1))
