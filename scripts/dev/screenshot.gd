extends Node
## Stages a still and saves it as a PNG (used to compare against the art
## reference and to check menus). Launched by dev_driver.gd:
##
##   godot --path . --resolution 1672x941 -- --shot=out.png [options]
##
## Options (all optional):
##   --shot-level=<id>     level to load (default prize_pier)
##   --shot-scene=level|intro|menu|results|defeat|pause|kiosk|kit|<any menu page id: play, settings, locker, arsenal, career, ...>
##                         (kit = the UI kit gallery, scripts/ui/kit/kit_gallery.gd)
##   --shot-locker=<slot>  with --shot-scene=locker: open that tab (avatar, weapon_finish, gloves...)
##   --shot-item=<id>      with --shot-scene=locker: select that cosmetic (opens its tab)
##   --shot-filter=owned|sale   with --shot-scene=locker: the tray's filter
##   --shot-sparks=n       menu scenes: set the Sparks balance first
##   --shot-tour=all|buy   with --shot-scene=locker: several stills in one run, saved as <shot>_<name>.png:
##                         all = every category; buy = --shot-item before, in the confirm dialog, bought, equipped
##   --shot-run=<file.gd>  menu scenes: instead of a still, run that script's `run(shot, menu)` (headless
##                         probes; see scripts/dev/meta_pages_probe.gd), then quit
##   --shot-pos=x,y,z      player feet position
##   --shot-yaw=deg        0 looks down -Z, positive turns left
##   --shot-pitch=deg
##   --shot-fov=deg        vertical field of view
##   --shot-weapon=id
##   --shot-zombies=0|1    stage the four reference zombies
##   --shot-hud=0|1
##   --shot-frames=n       frames to wait before capturing
##   --shot-reload=1       start a reload just before the wait (to check reload animations)
##   --shot-portal=1       open the portal and light the exit route
##   --shot-fire=n         fire n shots at the nearest staged zombie, then wait --shot-frames
##   --shot-hurt=1         hit the player from the left (damage feedback check)
##   --shot-cam=x,y,z>tx,ty,tz   free camera from x,y,z looking at tx,ty,tz (hides the viewmodel)
##   --shot-anim=Clip:t    pose every staged zombie at time t (seconds) of Clip
##   --shot-near=1         stage one zombie of each kind close to the player instead of four
##   --shot-fx=confetti|pop|burst|tracer|muzzle   spawn one effect 3 m in front of the camera
##   --shot-stutter=1      kill three zombies one at a time and print every frame's duration
##   --shot-move=1         movement probe: jump height, slide speed, rail wall
##   --shot-ads=1          hold aim-down-sights
##   --shot-threat=1       a zombie behind-right of the player starts its windup (threat warning check)

var path := ""
var args := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _arg(key: String, default_value: String) -> String:
	return String(args.get(key, default_value))


func _vec(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _run() -> void:
	var scene_kind := _arg("scene", "level")
	await _wait(3)
	if scene_kind == "intro":
		# Startup intro at a given time (--shot-frames at 60 fps).
		await _wait(10)
		var intro := IntroOverlay.new()
		get_tree().current_scene.add_child(intro)
		await _capture(int(_arg("frames", "120")))
		return
	# Anything that is not an in-level scene is treated as a menu page id.
	if not scene_kind in ["level", "results", "defeat", "pause", "kiosk"]:
		await _wait(10)
		var menu := get_tree().current_scene
		if scene_kind == "kit":
			# The UI kit's gallery: every component on one screen.
			menu.add_child(KitGallery.new())
		elif scene_kind != "menu":
			menu._show(scene_kind)
		_stage_wallet()
		if scene_kind == "locker":
			_stage_locker(menu.page("locker"))
		if _arg("run", "") != "":
			await (load(_arg("run", "")) as GDScript).new().run(self, menu)
			get_tree().quit()
		elif _arg("tour", "") != "":
			await _tour_locker(menu.page("locker"), _arg("tour", ""))
			get_tree().quit()
		else:
			await _capture(int(_arg("frames", "30")))
		return

	Game.start_level(StringName(_arg("level", "prize_pier")), StringName(_arg("weapon", "ion_carbine")))
	var director: RunDirector = null
	while director == null or director.player == null:
		await get_tree().process_frame
		director = get_tree().get_first_node_in_group("run_director") as RunDirector
	var player := director.player
	await _wait(2)

	# Freeze the run so nothing moves while the still is staged.
	director.set_process(false)
	director.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)

	var pos := _vec(_arg("pos", "5.0,0.0,15.5"))
	player.global_position = pos
	player.set_look(deg_to_rad(float(_arg("yaw", "12"))), deg_to_rad(float(_arg("pitch", "0"))))
	var fov := float(_arg("fov", "62"))
	Profile.data["settings"]["fov"] = fov
	player._apply_settings()
	player.camera.fov = fov

	if scene_kind == "kiosk":
		director.tickets = 260
		director.tickets_changed.emit(260)
		player.health = 60.0
		player.health_changed.emit(60.0, 100.0)
	elif scene_kind in ["results", "defeat"]:
		director._grant(&"ion_carbine", 880, 61)
		director._grant(&"pulse_pistol", 420, 30)
		director.total_kills = 91
		director.elapsed = 412.0
		director.wave_number = 8 if scene_kind == "results" else 6
		director.waves_cleared = 8 if scene_kind == "results" else 5
		director.state = RunDirector.State.CLEARED if scene_kind == "results" else RunDirector.State.DEFEAT
		var screen = (load(RunDirector.RESULTS_SCENE) as PackedScene).instantiate()
		director.get_parent().add_child(screen)
		screen.show_result(director.result())
		director.hud.visible = false
	elif scene_kind == "pause":
		director.wave_number = 3
		director.pause()
	else:
		director.wave_number = 3
		director._set_state(RunDirector.State.WAVE)
		director.hud._wave.text = "WAVE 03"
		director.hud._notice.text = ""
		director.kiosk.set_open(false)
		if _arg("zombies", "1") == "1":
			_stage_zombies(director, player)
		if _arg("portal", "0") == "1":
			director.portal.activate()

	if _arg("hud", "1") == "0":
		director.hud.visible = false
	if _arg("ads", "0") == "1":
		player.ads = 1.0
	if _arg("reload", "0") == "1":
		player.weapons._ammo[player.weapons.current.id]["mag"] = 1
		player.weapons.start_reload()
	if _arg("cam", "") != "":
		var parts := _arg("cam", "").split(">")
		var cam := Camera3D.new()
		cam.fov = float(_arg("fov", "50"))
		director.get_parent().add_child(cam)
		cam.look_at_from_position(_vec(parts[0]), _vec(parts[1]))
		cam.make_current()
		player.view.visible = false
	if _arg("move", "0") == "1":
		await _move_probe(player)
		return
	if _arg("stutter", "0") == "1":
		await _stutter_test(director, player)
		return
	var shots := int(_arg("fire", "0"))
	if shots > 0:
		await _wait(10)
		player.set_physics_process(true)
		player.controls_enabled = true
		for i in shots:
			_aim_at_nearest(director, player)
			player.weapons._cooldown = 0.0
			player.weapons._fire()
			await _wait(4)
			var hp := []
			for z in director.alive_enemies():
				if is_instance_valid(z):
					hp.append("%s %.0f%s" % [z.data.id, z.health, " dead" if z.is_dead() else ""])
			print("[shot] after shot %d: %s  look_pitch=%.2f head_pitch=%.2f" % [i + 1, hp, player.look_pitch(), player.head.rotation.x])
		player.set_physics_process(false)
	var fx := _arg("fx", "")
	if fx != "":
		var at := player.camera.global_position - player.camera.global_transform.basis.z * 3.0
		match fx:
			"confetti": Fx.confetti(director.get_parent(), at)
			"pop": Fx.hit_pop(director.get_parent(), at, -player.camera.global_transform.basis.z, true)
			"burst": Fx.kill_burst(director.get_parent(), at)
			"muzzle":
				player.view.on_fired(player.weapons.current)
				Fx.tracer(director.get_parent(), player.view.muzzle_position(), at - player.camera.global_transform.basis.z * 12.0, player.weapons.current.tracer_color, player.weapons.current.tracer_width)
			"tracer": Fx.tracer(director.get_parent(), player.view.muzzle_position(), at - player.camera.global_transform.basis.z * 12.0, Color(0.3, 0.95, 1.0), 0.035)
	if _arg("threat", "0") == "1":
		var z: Zombie = (load(RunDirector.ZOMBIE_SCENE) as PackedScene).instantiate()
		z.setup(GameData.enemy(&"tourist_shambler"), player, 1.0)
		z.position = player.global_position + player.global_transform.basis * Vector3(1.6, 0, 1.4)
		director._enemies_root.add_child(z)
		director._alive.append(z)
		z.speed = 0.0
		await _wait(2)
		z._begin_attack()
	if _arg("hurt", "0") == "1":
		await _wait(5)
		player.take_damage(20.0, player.global_position - player.global_transform.basis.x * 4.0)
	await _capture(int(_arg("frames", "45")))


## Locker page: weapon (--shot-weapon), tab (--shot-locker), item (--shot-item).
func _stage_locker(page: Node) -> void:
	if page == null:
		return
	if _arg("weapon", "") != "":
		page.select_weapon(StringName(_arg("weapon", "")))
	if _arg("locker", "") != "":
		page.show_category(StringName(_arg("locker", "")))
	if _arg("item", "") != "":
		page.select_item(StringName(_arg("item", "")))
	if _arg("filter", "") != "":
		page._filters.select(StringName(_arg("filter", "")), true)


## --shot-sparks: the balance the menu pages see.
func _stage_wallet() -> void:
	if _arg("sparks", "") == "":
		return
	Profile.section("wallet")["balance"] = int(_arg("sparks", "0"))
	Wallet.balance_changed.emit(Wallet.balance())


## --shot-tour: several Locker stills in one run (the launch is the slow part).
func _tour_locker(page: Node, tour: String) -> void:
	var frames := int(_arg("frames", "40"))
	if tour == "buy":
		var item := Cosmetics.item(StringName(_arg("item", "")))
		await _snap("1_before", frames)
		page._activate(item)
		await _snap("2_confirm", 24)
		for node in get_tree().current_scene.get_children():
			if node is KitDialog:
				node._close(true)
		await _snap("3_bought", 22)
		await _wait(120)
		page._activate(item)
		await _snap("4_equipped", 30)
		return
	for cat in LockerCatalog.CATEGORIES:
		page.show_category(cat["slot"])
		await _snap(String(cat["slot"]), frames)


## Saves a still next to the --shot path, as <shot>_<suffix>.png, and carries on.
func _snap(suffix: String, frames: int) -> void:
	await _wait(frames)
	await RenderingServer.frame_post_draw
	var file := "%s_%s.png" % [path.get_basename(), suffix]
	var err := get_viewport().get_texture().get_image().save_png(file)
	print("[shot] saved %s error=%d" % [file, err])


func _press(action: String, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	Input.parse_input_event(e)


func _move_probe(player: Player) -> void:
	player.set_physics_process(true)
	player.controls_enabled = true
	await _wait(10)
	# 1. Jump in place.
	var y0 := player.global_position.y
	var top := y0
	_press("jump", true)
	for f in 60:
		await get_tree().physics_frame
		top = maxf(top, player.global_position.y)
		if f == 2:
			_press("jump", false)
	print("[move] jump height %.2f m, back on floor: %s" % [top - y0, player.is_on_floor()])
	# 2. Sprint, then slide.
	player.set_look(0.0, 0.0)
	_press("move_forward", true)
	_press("sprint", true)
	for f in 40:
		await get_tree().physics_frame
	var sprint := player.horizontal_speed()
	_press("slide", true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_press("slide", false)
	var peak := 0.0
	for f in 20:
		await get_tree().physics_frame
		peak = maxf(peak, player.horizontal_speed())
	print("[move] sprint %.1f m/s, slide peak %.1f m/s, sliding=%s, camera y %.2f" % [sprint, peak, player.sliding, player.head.position.y])
	_press("move_forward", false)
	_press("sprint", false)
	for f in 60:
		await get_tree().physics_frame
	# 3. Try to jump over the ocean rail (x = 14).
	player.global_position = Vector3(12.5, 0.1, 5.0)
	player.velocity = Vector3.ZERO
	player.set_look(-PI * 0.5, 0.0)
	await get_tree().physics_frame
	_press("move_forward", true)
	_press("sprint", true)
	for f in 90:
		if f % 20 == 2:
			_press("jump", true)
		if f % 20 == 5:
			_press("jump", false)
		await get_tree().physics_frame
	_press("move_forward", false)
	_press("sprint", false)
	print("[move] rail test: x=%.2f (rail at 14.0) -> %s" % [player.global_position.x, "BLOCKED" if player.global_position.x < 14.0 else "ESCAPED"])
	get_tree().quit(0)


## Measures frame times around kills: the first kill of a session is where
## one-off costs (shader compiles, font atlases, first audio) show up.
func _stutter_test(director: RunDirector, player: Player) -> void:
	await _wait(30)
	player.set_physics_process(true)
	player.controls_enabled = true
	var scene: PackedScene = load(RunDirector.ZOMBIE_SCENE)
	for round_i in 3:
		var z: Zombie = scene.instantiate()
		z.setup(GameData.enemy(&"tourist_shambler"), player, 1.0)
		z.position = player.global_position + player.global_transform.basis * Vector3(0, 0, -5)
		director._enemies_root.add_child(z)
		director._alive.append(z)
		z.speed = 0.0
		z.died.connect(director._on_zombie_died)
		await _wait(20)
		var times: Array[int] = []
		var last := Time.get_ticks_usec()
		var shots := 0
		for f in 70:
			if is_instance_valid(z) and not z.is_dead() and f % 6 == 0:
				_aim_at_nearest(director, player)
				player.weapons._cooldown = 0.0
				player.weapons._fire()
				shots += 1
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			times.append(now - last)
			last = now
		var sorted := times.duplicate()
		sorted.sort()
		var median: int = sorted[sorted.size() / 2]
		var worst: int = sorted[-1]
		print("[stutter] kill %d: median %.1f ms, worst %.1f ms (%.1fx), shots %d  frames>%.0fms: %s" % [round_i + 1, median / 1000.0, worst / 1000.0, float(worst) / maxf(1.0, median), shots,
			median * 2.0 / 1000.0, times.map(func(t): return int(t / 1000)).filter(func(t): return t > median * 2.0 / 1000.0)])
	get_tree().quit(0)


func _aim_at_nearest(director: RunDirector, player: Player) -> void:
	var best: Zombie = null
	for z in director.alive_enemies():
		if is_instance_valid(z) and not z.is_dead() and (best == null or z.global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position)):
			best = z
	if best == null:
		return
	var to := best.global_position + Vector3(0, 1.0, 0) - player.camera.global_position
	player.set_look(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


## Four zombies placed roughly where the reference image has them.
func _stage_zombies(director: RunDirector, player: Player) -> void:
	var staged := [
		[&"tourist_shambler", Vector3(1.2, 0, 10.6), 0.30, Color(1.0, 0.33, 0.62)],
		[&"tourist_shambler", Vector3(-2.6, 0, 8.2), 0.75, Color(0.62, 0.3, 0.86)],
		[&"tourist_shambler", Vector3(1.6, 0, 6.4), 0.55, Color(1.0, 0.76, 0.18)],
		[&"lifeguard_runner", Vector3(8.6, 0, 7.4), 0.40, Color.WHITE],
	]
	if _arg("near", "0") == "1":
		staged = [
			[&"tourist_shambler", player.global_position + Vector3(-1.1, 0, -4.2), 0.3, Color(1.0, 0.33, 0.62)],
			[&"lifeguard_runner", player.global_position + Vector3(1.4, 0, -4.6), 0.4, Color.WHITE],
		]
	var pose := _arg("anim", "")
	var scene: PackedScene = load(RunDirector.ZOMBIE_SCENE)
	for entry in staged:
		var data: EnemyData = GameData.enemy(entry[0]).duplicate()
		if entry[0] == &"tourist_shambler":
			data.shirt_colors = [entry[3]] as Array[Color]
		var z: Zombie = scene.instantiate()
		z.setup(data, player, 1.0)
		z.position = entry[1]
		director._enemies_root.add_child(z)
		director._alive.append(z)
		var to_player: Vector3 = player.global_position - z.global_position
		z.rotation.y = atan2(to_player.x, to_player.z)
		# Stand still but stay live, so hit flashes clear, knockback and deaths
		# play out, and kills are counted by the run like in real play.
		z.speed = 0.0
		z.died.connect(director._on_zombie_died)
		var anim := z.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim and pose != "":
			var bits := pose.split(":")
			var clip := bits[0] if anim.has_animation(bits[0]) else bits[0] + "-loop"
			if anim.has_animation(clip):
				anim.play(clip)
				anim.seek(float(bits[1]), true)
				anim.pause()
		elif anim and anim.current_animation != "":
			anim.seek(anim.current_animation_length * float(entry[2]), true)
			anim.pause()


func _capture(frames: int) -> void:
	await _wait(frames)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("[shot] saved %s (%dx%d) error=%d" % [path, img.get_width(), img.get_height(), err])
	get_tree().quit(0 if err == OK else 1)
