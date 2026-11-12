extends SceneTree
## Staged stills of any level with any enemies (developer tool, used to check
## the Neon Rooftops zombies and fights; scripts/dev/screenshot.gd only stages
## the boardwalk cast).
##
##   godot --path . --resolution 960x540 --script res://tools/neon_stage_shot.gd -- out.png [options]
##
## Options:
##   --level=<id>                   level to load (default neon_skyline)
##   --pos=x,y,z --yaw=deg --pitch=deg   player feet and view (yaw 0 = -Z)
##   --cam=x,y,z>tx,ty,tz           free camera instead of the player's view
##   --fov=deg
##   --zombie=<id>@x,z[,y][@clip@t] stage an enemy facing the player, posed at
##                                  `t` seconds into `clip` (repeatable)
##   --live=1                       let staged enemies run their AI for --frames
##   --wave=n                       HUD shows wave n (default 3)
##   --fire=n                       fire n shots at the nearest staged enemy
##   --open=1                       open the loadout station (break-time look)
##   --hud=0|1  --frames=n  --weapon=<id>  --profile=<file>
##
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes.

const ZOMBIE_SCENE := "res://scenes/enemies/zombie.tscn"
const STATE_WAVE := 1
const STATE_BREAK := 2

var out_path := ""
var opts := {}
var zombies: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zombie="):
			zombies.append(a.trim_prefix("--zombie="))
		elif a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
		elif out_path == "":
			out_path = a
	# Never hang a batch run: give up after a few minutes.
	create_timer(float(_opt("timeout", "300"))).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _opt(key: String, default_value: String) -> String:
	return String(opts.get(key, default_value))


func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	await _wait(3)
	print("[stage] loading level")
	# Load directly (Game.start_level refuses levels still locked in this profile).
	var game: Node = root.get_node("Game")
	game.level = root.get_node("GameData").level(StringName(_opt("level", "neon_skyline")))
	game.weapon_id = StringName(_opt("weapon", "ion_carbine"))
	change_scene_to_file(game.level.scene_path)
	var director = null
	while director == null or director.player == null:
		await process_frame
		director = get_first_node_in_group("run_director")
	var player = director.player
	print("[stage] level running")
	await _wait(4)
	director.set_process(false)
	director.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.global_position = _vec(_opt("pos", "3,0.1,12.5"))
	player.set_look(deg_to_rad(float(_opt("yaw", "12"))), deg_to_rad(float(_opt("pitch", "0"))))
	var fov := float(_opt("fov", "62"))
	player.camera.fov = fov

	var open := _opt("open", "0") == "1"
	if open:
		director._set_state(STATE_BREAK)
		director.countdown = 14.0
		director.tickets = 340
		director.tickets_changed.emit(340)
	else:
		director.wave_number = int(_opt("wave", "3"))
		director._set_state(STATE_WAVE)
		director.hud._wave.text = "WAVE %02d" % director.wave_number
		director.kiosk.set_open(false)
	director.hud._notice.text = ""
	director.hud.visible = _opt("hud", "1") == "1"

	var live := _opt("live", "0") == "1"
	var scene: PackedScene = load(ZOMBIE_SCENE)
	for spec in zombies:
		var bits := spec.split("@")
		var data = root.get_node("GameData").enemy(StringName(bits[0]))
		if data == null:
			push_warning("unknown enemy " + bits[0])
			continue
		var xz := bits[1].split(",")
		var z = scene.instantiate()
		z.setup(data, player, 1.0)
		z.position = Vector3(float(xz[0]), float(xz[2]) if xz.size() > 2 else player.global_position.y, float(xz[1]))
		director._enemies_root.add_child(z)
		director._alive.append(z)
		var to_player: Vector3 = player.global_position - z.global_position
		z.rotation.y = atan2(to_player.x, to_player.z)
		z.died.connect(director._on_zombie_died)
		if not live:
			z.speed = 0.0
			z.set_physics_process(false)
		var anim := z.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim and bits.size() >= 4:
			var clip := bits[2] if anim.has_animation(bits[2]) else bits[2] + "-loop"
			if anim.has_animation(clip):
				anim.play(clip)
				anim.seek(float(bits[3]), true)
				anim.pause()
	if live:
		player.set_physics_process(true)

	if _opt("cam", "") != "":
		var parts := _opt("cam", "").split(">")
		var cam := Camera3D.new()
		cam.fov = float(_opt("fov", "50"))
		director.get_parent().add_child(cam)
		cam.look_at_from_position(_vec(parts[0]), _vec(parts[1]))
		cam.make_current()
		player.view.visible = false

	var shots := int(_opt("fire", "0"))
	if shots > 0:
		await _wait(10)
		player.set_physics_process(true)
		player.controls_enabled = true
		for i in shots:
			_aim_at_nearest(director, player)
			player.weapons._cooldown = 0.0
			player.weapons._fire()
			await _wait(3)
		player.set_physics_process(live)
	await _wait(int(_opt("frames", "40")))
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var err := img.save_png(out_path)
	print("[stage] saved %s error=%d" % [out_path, err])
	quit(0 if err == OK else 1)


func _aim_at_nearest(director, player) -> void:
	var best = null
	for z in director.alive_enemies():
		if is_instance_valid(z) and not z.is_dead() and (best == null or z.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position)):
			best = z
	if best == null:
		return
	var to: Vector3 = best.global_position + Vector3(0, 1.1, 0) - player.camera.global_position
	player.set_look(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))
