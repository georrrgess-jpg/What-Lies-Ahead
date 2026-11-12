extends SceneTree
## Asset check: loads models, prints their node tree, bounds and animation
## clips, and renders a contact sheet so scale, orientation, origin, materials
## and normals can be verified after an export.
##
##   godot --path . --script res://tools/preview_model.gd -- out.png model_a [model_b ...] \
##         [--yaw=35] [--pitch=-15] [--anim=Walk --time=0.4] [--hide=NodeName] [--bare]
##
## A 1 m grey reference cube sits at the origin next to each model (front = +Z).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ""
	var models: Array[String] = []
	var yaw := 35.0
	var pitch := -14.0
	var anim := ""
	var anim_time := 0.0
	var hide: Array[String] = []
	var bare := false
	for a in args:
		if a.begins_with("--yaw="):
			yaw = float(a.trim_prefix("--yaw="))
		elif a.begins_with("--pitch="):
			pitch = float(a.trim_prefix("--pitch="))
		elif a.begins_with("--anim="):
			anim = a.trim_prefix("--anim=")
		elif a.begins_with("--time="):
			anim_time = float(a.trim_prefix("--time="))
		elif a == "--bare":
			bare = true
		elif a.begins_with("--hide="):
			hide.append(a.trim_prefix("--hide="))
		elif out == "":
			out = a
		else:
			models.append(a)

	await process_frame
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.5, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.5, 0.86)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, 140, 0)
	sun.light_color = Color(1.0, 0.8, 0.62)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	root.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.5, 0.33, 0.3)
	ground.material_override = gm
	if not bare:
		root.add_child(ground)

	var x := 0.0
	var total := AABB()
	var first := true
	for model in models:
		var path := "res://art/models/%s.glb" % model
		var scene := load(path) as PackedScene
		if scene == null:
			print("MISSING ", path)
			continue
		var node: Node3D = scene.instantiate()
		root.add_child(node)
		for h in hide:
			var hn := node.find_child(h, true, false) as Node3D
			if hn:
				hn.visible = false
		var box := _bounds(node)
		print("== %s  size=%s  min=%s  max=%s" % [model, _fmt(box.size), _fmt(box.position), _fmt(box.end)])
		_dump(node, 1)
		var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player:
			for clip in player.get_animation_list():
				var a := player.get_animation(clip)
				print("   clip %-14s length=%.2fs loop=%s tracks=%d" % [clip, a.length, a.loop_mode != Animation.LOOP_NONE, a.get_track_count()])
			if anim != "":
				var clip_name := anim if player.has_animation(anim) else anim + "-loop"
				if player.has_animation(clip_name):
					player.play(clip_name)
					player.seek(anim_time, true)
					player.pause()
		node.position.x = x - box.position.x
		var placed := AABB(box.position + Vector3(node.position.x, 0, 0), box.size)
		total = placed if first else total.merge(placed)
		first = false
		x += box.size.x + 1.0

	# 1 m reference cube.
	var cube := MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	cube.position = Vector3(-1.2, 0.5, 0)
	if not bare:
		root.add_child(cube)

	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	var centre := total.get_center()
	var radius := total.size.length() * 0.5
	var dist := radius / sin(deg_to_rad(20.0)) * (0.8 if bare else 1.0)
	var dir := Vector3(sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), -sin(deg_to_rad(pitch)), cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)))
	cam.look_at_from_position(centre + dir * dist, centre)
	cam.far = dist * 4.0 + 100.0
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	if out != "" and DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(out)
		print("saved ", out)
	quit()


func _fmt(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or not m.visible:
			continue
		var box: AABB = (node.global_transform.affine_inverse() * m.global_transform) * m.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _dump(node: Node, depth: int) -> void:
	var extra := ""
	if node is MeshInstance3D and node.mesh:
		var mats := []
		for i in node.mesh.get_surface_count():
			var m: Material = node.mesh.surface_get_material(i)
			mats.append(m.resource_name if m else "-")
		extra = "  surfaces=%s" % [mats]
	if depth <= 3:
		print("%s%s (%s)%s" % ["   ".repeat(depth), node.name, node.get_class(), extra])
	for c in node.get_children():
		_dump(c, depth + 1)
