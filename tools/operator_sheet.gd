extends SceneTree
## Operator check: renders the operators (art/models/operator_<id>.glb, built by
## art/blender/build_operators.py) with their in-game materials so outfits,
## clips and the held weapon can be judged after a rebuild.
##
##   godot --path . --resolution 960x540 --script res://tools/operator_sheet.gd -- <out.png> [options]
##
## Options:
##   --mode=lineup    every operator (or --ops) side by side in one pose
##   --mode=clips     one operator (--ops=<id>): a grid of clips x moments x views
##   --ops=a,b        operator ids without the "operator_" prefix (default: all)
##   --clip=Pose --time=0.6   the lineup's clip and moment
##   --clips=Idle,Run,AimIdle,Fire,Victory,Wave,Pose  --times=0.15,0.5,0.85 (fractions of each clip)
##   --yaws=20,160    camera yaws for the clip grid (degrees; 0 = the operator's front)
##   --weapon=<id>    a weapon in the WeaponSocket in AimIdle and Fire (default ion_carbine; "none" for none)
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes.

const OPERATORS_SCRIPT := "res://scripts/cosmetics/operators.gd"
const COSMETICS_SCRIPT := "res://scripts/player/weapon_cosmetics.gd"
const HELD_CLIPS := ["AimIdle", "Fire"]
const CELL := Vector2i(160, 270)

var out := ""
var opts := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
		elif out == "":
			out = a
	_run.call_deferred()


func _run() -> void:
	await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var ops := String(opts.get("ops", "")).split(",", false)
	if ops.is_empty():
		for f in DirAccess.get_files_at("res://art/models"):
			if f.begins_with("operator_") and f.ends_with(".glb"):
				ops.append(f.trim_prefix("operator_").trim_suffix(".glb"))
	if String(opts.get("mode", "lineup")) == "clips":
		await _clips(ops[0])
	else:
		await _lineup(ops)
	quit()


func _world(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.42, 0.66)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.62, 0.9)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	parent.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.3, 0.38)
	ground.material_override = gm
	parent.add_child(ground)


func _operator(id: String) -> Node3D:
	var scene := load("res://art/models/operator_%s.glb" % id) as PackedScene
	if scene == null:
		push_error("missing operator " + id)
		return null
	var node: Node3D = scene.instantiate()
	load(OPERATORS_SCRIPT).apply_materials(node)
	return node


func _pose(node: Node3D, clip: String, frac: float) -> void:
	var anim := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		return
	var name := clip if anim.has_animation(clip) else clip + "-loop"
	if not anim.has_animation(name):
		return
	anim.play(name)
	anim.seek(anim.get_animation(name).length * frac, true)
	anim.pause()


func _hold(node: Node3D) -> void:
	var weapon_id := String(opts.get("weapon", "ion_carbine"))
	var scene := load("res://art/models/%s.glb" % weapon_id) as PackedScene
	var socket := node.find_child("WeaponSocket", true, false) as Node3D
	if scene == null or socket == null:
		return
	var w: Node3D = scene.instantiate()
	load(COSMETICS_SCRIPT).prepare_preview(w)
	socket.add_child(w)


func _lineup(ops: PackedStringArray) -> void:
	var vp := _viewport(Vector2i(960, 540))
	_world(vp)
	var spacing := 1.05
	var x0 := -spacing * (ops.size() - 1) * 0.5
	for i in ops.size():
		var node := _operator(ops[i])
		if node == null:
			continue
		vp.add_child(node)
		node.position = Vector3(x0 + spacing * i, 0, 0)
		_pose(node, String(opts.get("clip", "Idle")), float(opts.get("time", "0.3")))
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var span := spacing * ops.size() * 0.55
	cam.look_at_from_position(Vector3(0, 1.3, maxf(4.6, span / tan(deg_to_rad(15.0)) * 0.42)), Vector3(0, 1.05, 0))
	await _save(vp)


func _clips(id: String) -> void:
	var clips := String(opts.get("clips", "Idle,Run,AimIdle,Fire,Victory,Wave,Pose")).split(",")
	var times := String(opts.get("times", "0.15,0.5,0.85")).split(",")
	var yaws := String(opts.get("yaws", "25,150")).split(",")
	var cols := times.size() * yaws.size()
	var vp := _viewport(Vector2i(CELL.x * cols, CELL.y * clips.size()))
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	vp.add_child(grid)
	for clip in clips:
		for t in times:
			for yaw in yaws:
				var svc := SubViewportContainer.new()
				var sub := SubViewport.new()
				sub.size = CELL
				sub.own_world_3d = true
				svc.add_child(sub)
				grid.add_child(svc)
				_world(sub)
				var node := _operator(id)
				sub.add_child(node)
				if clip in HELD_CLIPS and String(opts.get("weapon", "")) != "none":
					_hold(node)
				_pose(node, clip, float(t))
				var cam := Camera3D.new()
				cam.fov = 34.0
				sub.add_child(cam)
				var a := deg_to_rad(float(yaw))
				cam.look_at_from_position(Vector3(sin(a) * 4.0, 1.5, cos(a) * 4.0), Vector3(0, 1.0, 0))
				var label := Label.new()
				label.text = "%s %s" % [clip, t]
				label.add_theme_font_size_override("font_size", 11)
				svc.add_child(label)
	await _save(vp)


func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	return vp


func _save(vp: SubViewport) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("saved ", out)
