extends SceneTree
## Contact sheet for a kit .glb whose top-level objects are separate props
## (art/models/fright_kit.glb, fright_landmarks.glb): lays every mesh out in a
## row-major grid, labels it and renders one still from the front-left.
##
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://tools/fright_sheet.gd -- \
##       out.png res://art/models/fright_kit.glb [--cols=6] [--yaw=30] [--only=Name,Name]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var glb := args[1]
	var cols := 6
	var yaw := 30.0
	var only: PackedStringArray = []
	for a in args.slice(2):
		if a.begins_with("--cols="):
			cols = int(a.trim_prefix("--cols="))
		elif a.begins_with("--yaw="):
			yaw = float(a.trim_prefix("--yaw="))
		elif a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")
	await process_frame
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.03, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.55, 0.86)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	var source: Node3D = (load(glb) as PackedScene).instantiate()
	var meshes: Array[MeshInstance3D] = []
	for n in source.find_children("*", "MeshInstance3D", true, false):
		if only.is_empty() or only.has(String(n.name)):
			meshes.append(n)
	var cell := 0.0
	for mi in meshes:
		var s := mi.mesh.get_aabb().size
		cell = maxf(cell, maxf(s.x, s.z))
	cell += 0.6
	var holder := Node3D.new()
	root.add_child(holder)
	var i := 0
	var top := 0.0
	for mi in meshes:
		var copy := MeshInstance3D.new()
		copy.mesh = mi.mesh
		var aabb := mi.mesh.get_aabb()
		top = maxf(top, aabb.end.y)
		copy.position = Vector3((i % cols) * cell, 0, (i / cols) * cell)
		holder.add_child(copy)
		var label := Label3D.new()
		label.text = String(mi.name)
		label.pixel_size = cell * 0.0016
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = copy.position + Vector3(0, aabb.end.y + cell * 0.08, 0)
		holder.add_child(label)
		i += 1
	var rows := ceili(float(meshes.size()) / cols)
	var centre := Vector3((cols - 1) * cell * 0.5, top * 0.35, (rows - 1) * cell * 0.5)
	var cam := Camera3D.new()
	cam.fov = 40.0
	var dist := maxf(cols * cell, rows * cell + top) * 1.05
	var dir := Basis(Vector3.UP, deg_to_rad(-yaw)) * Vector3(0, 0.55, 1).normalized()
	root.add_child(cam)
	cam.look_at_from_position(centre + dir * dist, centre)
	cam.far = dist * 4.0
	for k in 6:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("fright_sheet: %d meshes -> %s" % [meshes.size(), out])
	source.free()
	quit(0)
