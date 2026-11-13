extends SceneTree
## Weapon model check: renders contact sheets of the weapon viewmodels so their
## detail, sights, hands, reload keyframes and charms can be judged after a
## rebuild (art/blender/build_weapons*.py).
##
##   godot --path . --resolution 960x540 --script res://tools/weapon_sheet.gd -- <out_dir> [options]
##
## Options:
##   --mode=turn      four views of the bare weapon: three-quarter front, back, top, underside
##   --mode=fp        first person: hip, aiming, sprinting and a side view of both hands
##   --mode=hands     close-ups of the hands on the weapon: player's eye, left, right, below
##                    (--view=0..3 renders just one of them, full size)
##   --mode=reload    first person at six moments of the reload (--times=0.15,0.3,...)
##   --mode=charm     first person while the weapon is shaken, to stress the charm (--charm=<id>)
##   --weapons=a,b    weapon ids (default: all)
##   --finish=<id> --charm=<id> --decal=<id> --arms=<id>   cosmetics to wear (item ids)
##
## One PNG per weapon: <out_dir>/<mode>_<weapon id>.png.
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes.

const VIEW_SCRIPT := "res://scripts/player/weapon_view.gd"
const COSMETICS_SCRIPT := "res://scripts/player/weapon_cosmetics.gd"
const VIEW_SCALE := 0.2
const SPRINT_POS := Vector3(-0.07, -0.06, 0.03)
const SPRINT_ROT := Vector3(-14.0, 26.0, 16.0)
const COSMETIC_DIRS := ["finishes", "charms", "decals", "gloves", "operators", "mastery", "cells"]

var out_dir := ""
var opts := {}
var _grid: GridContainer


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
		elif out_dir == "":
			out_dir = a
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(out_dir)
	var game_data = root.get_node("GameData")
	var mode := String(opts.get("mode", "turn"))
	var wanted := String(opts.get("weapons", "")).split(",", false)
	for w in game_data.weapons():
		if not wanted.is_empty() and not String(w.id) in wanted:
			continue
		_grid = GridContainer.new()
		_grid.add_theme_constant_override("h_separation", 0)
		_grid.add_theme_constant_override("v_separation", 0)
		root.add_child(_grid)
		match mode:
			"turn": _sheet_turn(w)
			"fp": _sheet_fp(w)
			"hands": _sheet_hands(w)
			"reload": await _sheet_reload(w)
			"charm": await _sheet_charm(w)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s_%s.png" % [out_dir, mode, w.id])
		_grid.queue_free()
		await process_frame
	quit()


# --- tiles ----------------------------------------------------------------------

## A tile of the sheet: its own little world with lights. Returns the viewport.
func _tile(size: Vector2i, sky := Color(0.36, 0.42, 0.62)) -> SubViewport:
	var holder := SubViewportContainer.new()
	holder.custom_minimum_size = size
	_grid.add_child(holder)
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	holder.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.6, 0.86)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	for spec in [[Vector3(-42, 150, 0), 1.4, Color(1.0, 0.9, 0.78)], [Vector3(-10, -40, 0), 0.5, Color(0.6, 0.8, 1.0)]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = spec[0]
		l.light_energy = spec[1]
		l.light_color = spec[2]
		vp.add_child(l)
	return vp


func _loadout() -> Dictionary:
	var out := {}
	for key in ["finish", "charm", "decal", "arms"]:
		if not opts.has(key):
			continue
		for dir in COSMETIC_DIRS:
			var path := "res://data/cosmetics/%s/%s.tres" % [dir, opts[key]]
			if ResourceLoader.exists(path):
				out[key] = load(path)
				break
	return out


## The bare weapon (no arms, no hologram parts).
func _bare_model(w) -> Node3D:
	var model: Node3D = w.viewmodel.instantiate()
	for n in model.find_children("*", "Node3D", true, false):
		var nm := String(n.name)
		if nm.begins_with("Arm") or nm.ends_with("Holo"):
			(n as Node3D).visible = false
	load(COSMETICS_SCRIPT).apply(model, w, _loadout())
	return model


func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var hidden := false
		var p: Node = mi
		while p and p != model:
			if p is Node3D and not (p as Node3D).visible:
				hidden = true
			p = p.get_parent()
		if hidden or mi.mesh == null or mi.get_parent().name == "WeaponCharm":
			continue
		var xf := Transform3D.IDENTITY
		p = mi
		while p and p != model:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b := xf * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _sheet_turn(w) -> void:
	_grid.columns = 2
	var views := [Vector3(-0.72, 0.38, -0.78), Vector3(0.74, 0.34, 0.8), Vector3(-0.02, 1.0, 0.03), Vector3(-0.3, -0.9, 0.25)]
	for dir in views:
		var vp := _tile(Vector2i(480, 270))
		var model := _bare_model(w)
		vp.add_child(model)
		var box := _bounds(model)
		model.position = -box.get_center()
		var cam := Camera3D.new()
		cam.fov = 28.0
		vp.add_child(cam)
		var radius := box.size.length() * 0.5
		var up := Vector3.UP if absf(dir.y) < 0.85 else Vector3(-1, 0, 0)
		cam.look_at_from_position(dir.normalized() * radius / tan(deg_to_rad(14.0)) * 0.74, Vector3.ZERO, up)


## A first-person rig in a tile: camera, backdrop and a WeaponView showing `w`.
func _fp_rig(w, size: Vector2i) -> Dictionary:
	var vp := _tile(size, Color(0.55, 0.62, 0.86))
	var cam := Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.02
	cam.position = Vector3(0, 1.62, 0)
	vp.add_child(cam)
	_backdrop(vp)
	var view: Node3D = load(VIEW_SCRIPT).new()
	cam.add_child(view)
	view.show_weapon(w)
	view.set_process(false)
	view._raise = 0.0
	var extra := _loadout()
	if not extra.is_empty():
		var lo: Dictionary = root.get_node("Cosmetics").weapon_loadout(w.id)
		lo.merge(extra, true)
		load(COSMETICS_SCRIPT).apply(view.model, w, lo)
	_pose(view, w, "hip")
	return {"vp": vp, "cam": cam, "view": view}


## Ground, a few distant blocks and a small target dead ahead (what the sights must not hide).
func _backdrop(vp: SubViewport) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.62, 0.42, 0.36)
	ground.material_override = gm
	vp.add_child(ground)
	var cols := [Color(0.9, 0.3, 0.55), Color(0.2, 0.7, 0.68), Color(0.95, 0.75, 0.3), Color(0.5, 0.35, 0.8)]
	for i in 7:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.6, 2.0 + (i % 3), 1.6)
		b.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = cols[i % cols.size()]
		b.material_override = m
		b.position = Vector3((i - 3) * 3.4, bm.size.y * 0.5, -16.0 - (i % 2) * 3.0)
		vp.add_child(b)
	var target := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	target.mesh = sm
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.3, 1.0, 0.4)
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	target.material_override = tm
	target.position = Vector3(0, 1.62, -12.0)
	vp.add_child(target)


func _pose(view, w, pose: String) -> void:
	var holder: Node3D = view._holder
	match pose:
		"ads":
			holder.position = Vector3(0, 0, -w.ads_depth / VIEW_SCALE) - view._sight_local
			holder.rotation_degrees = Vector3.ZERO
		"sprint":
			holder.position = w.view_position + SPRINT_POS
			holder.rotation_degrees = w.view_rotation_degrees + SPRINT_ROT
		_:
			holder.position = w.view_position
			holder.rotation_degrees = w.view_rotation_degrees


func _sheet_fp(w) -> void:
	_grid.columns = 2
	for pose in ["hip", "ads", "sprint", "side"]:
		var rig := _fp_rig(w, Vector2i(480, 270))
		_pose(rig.view, w, pose)
		var cam: Camera3D = rig.cam
		if pose == "ads":
			cam.fov = 72.0 * w.ads_fov_scale
		elif pose == "side":
			# From the player's left, level with the weapon: both hands and the sleeves.
			var grip: Vector3 = cam.position + w.view_position * VIEW_SCALE
			var side := Camera3D.new()
			side.fov = 40.0
			side.near = 0.01
			rig.vp.add_child(side)
			side.look_at_from_position(grip + Vector3(-0.34, 0.03, -0.03), grip + Vector3(0.0, -0.01, -0.035))
			side.current = true


## Close-ups of the model with its arms, in model space (no view scale).
func _sheet_hands(w) -> void:
	_grid.columns = 2
	var eye: Vector3 = -w.view_position
	var views := [eye, Vector3(-0.75, 0.1, 0.12), Vector3(0.75, 0.05, 0.3), Vector3(-0.25, -0.75, 0.45)]
	var only := int(opts.get("view", "-1"))
	if only >= 0:
		_grid.columns = 1
	for i in views.size():
		if only >= 0 and i != only:
			continue
		var vp := _tile(Vector2i(960, 540) if only >= 0 else Vector2i(480, 270))
		var model: Node3D = w.viewmodel.instantiate()
		for n in model.find_children("*Holo", "Node3D", true, false):
			(n as Node3D).visible = false
		load(COSMETICS_SCRIPT).apply(model, w, _loadout())
		vp.add_child(model)
		var cam := Camera3D.new()
		cam.fov = 34.0 if i == 0 else 30.0
		cam.near = 0.01
		vp.add_child(cam)
		var focus := Vector3(0.0, -0.06, -0.1)
		var from: Vector3 = views[i] if i == 0 else focus + (views[i] as Vector3).normalized() * 0.95
		cam.look_at_from_position(from, focus)


func _sheet_reload(w) -> void:
	_grid.columns = 3
	var times := String(opts.get("times", "0.16,0.3,0.44,0.58,0.72,0.88")).split(",")
	for t in times:
		var rig := _fp_rig(w, Vector2i(320, 270))
		var view = rig.view
		view.play_reload(w, 1.0)
		var tween: Tween = view._reload_tween
		tween.pause()
		tween.custom_step(float(t))
	await process_frame


func _sheet_charm(w) -> void:
	_grid.columns = 3
	var rigs := []
	for i in 6:
		rigs.append(_fp_rig(w, Vector2i(320, 270)))
	# Each tile freezes the same shake at a later moment.
	var frames := [8, 16, 26, 38, 52, 70]
	for f in 71:
		for i in rigs.size():
			if f > frames[i]:
				continue
			var view = rigs[i].view
			var t := f / 60.0
			var holder: Node3D = view._holder
			holder.position = w.view_position + Vector3(sin(t * 9.0) * 0.06, sin(t * 13.0) * 0.04, sin(t * 7.0) * 0.03)
			holder.rotation_degrees = w.view_rotation_degrees + Vector3(sin(t * 11.0) * 12.0, sin(t * 6.0) * 22.0, sin(t * 8.0) * 26.0)
		await process_frame
