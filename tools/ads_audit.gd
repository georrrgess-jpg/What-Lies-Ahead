extends SceneTree
## Aim-down-sights audit. Renders every weapon with every sight that fits it,
## aimed at a zombie on Prize Pier, and measures each sight picture. One
## command (needs a renderer, so not --headless; several minutes on a
## software renderer):
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --audio-driver Dummy --rendering-driver opengl3 \
##       --path . --fixed-fps 60 --resolution 960x540 --script res://tools/ads_audit.gd -- [options]
##
## Options:
##   --out=<dir>          where to write (default user://ads_audit)
##   --weapons=a,b        only these weapon ids (default: all)
##   --sights=x,y         only these sight ids (default: every sight that fits)
##   --fov=<deg>          the FOV setting to test at (default 72)
##   --level=<id>  --pos=x,y,z  --yaw=<deg>  --range=<m>   where to stand and how far the target is
##   --profile=<file>     profile to start from (read by the Profile autoload)
##   --frames=1           also save every combination's full frame (ads_<weapon>_<sight>.png)
##   --full=1             render with shadows and anti-aliasing (slower; off by default)
##   --probe=1            instead of the sheets, run the motion probe (below); works with --headless
##
## Output:
##   <out>/ads_<weapon>.png  contact sheet: each sight's frame and its centre
##                           magnified, labelled with the measurements
##   <out>/ads_audit.csv     one row per weapon and sight
##   a table on stdout; exit code 1 if any combination fails
##
## Measured per combination (pixels of the rendered frame):
##   aim_err     distance from the sight's aim point to the true screen centre.
##               Optics: the centre of the reticle as rendered. Its pattern is
##               swapped for a dot, drawn once green and once magenta, and the
##               two frames are differenced, so the background cancels out.
##               Iron sights: where the sight line points on screen.
##   shot_err    distance from where a shot lands (a ray along the player's
##               aim) to the sight's aim point
##   cover       share of the centre window (±WINDOW px) hidden by the weapon
##   clear       pixels of clear view straight below the centre before the
##               weapon or its sight starts
##   frame/upper share of the whole frame, and of its upper half, the weapon covers
## A combination fails when aim_err or shot_err is above MAX_ERROR or cover
## is above MAX_COVER.
##
## The motion probe (--probe=1) plays a few weapons while aiming: strafing,
## walking, jumping, turning and firing. Every frame it compares where the
## optic's reticle is on screen (from the aim the lens shader was given) with
## where a shot fired that instant lands, and where the HUD's centre is. It
## then checks the aim rules: hold and toggle aim, aim cancels sprint, a
## reload or a weapon switch lowers the sight and it comes back up. Exit
## code 1 if a rule fails, or if the reticle is more than MAX_ERROR from the
## shots (on targets beyond PROBE_RANGE) in more than PROBE_SLACK of the
## frames: shots leave from the unshaken eye, so while the camera dips on a
## landing the two part by a pixel or two for a few frames.
##
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes.

const ZOMBIE_SCENE := "res://scenes/enemies/zombie.tscn"
const SIGHTS_SCRIPT := "res://scripts/weapons/sights/weapon_sights.gd"
const STATE_WAVE := 1
## Half-size of the centre window at 540 lines (scaled with the frame height).
const WINDOW := 16
const MAX_ERROR := 1.0
const MAX_COVER := 0.02
## A pixel differs when a channel changes by more than this (a lens's faint
## tint and reflections stay below it).
const DIFF := 0.2
const SETTLE_FRAMES := 8
const TILE := Vector2i(384, 216)
const ZOOM_SOURCE := 108
const COLUMNS := 2
## Probe: shots at targets nearer than this are not held to MAX_ERROR (the
## eye bobs a few millimetres off the line the shots leave from).
const PROBE_RANGE := 4.0
const PROBE_SLACK := 0.05
const PROBE_SIZE := Vector2(960, 540)

var opts := {}
var rows: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
	create_timer(float(_opt("timeout", "1500"))).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _opt(key: String, default_value: String) -> String:
	return String(opts.get(key, default_value))


func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _grab() -> Image:
	await _wait(1)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _run() -> void:
	await _wait(3)
	var data: Node = root.get_node("GameData")
	var game: Node = root.get_node("Game")
	var profile: Node = root.get_node("Profile")
	profile.data["settings"]["fov"] = float(_opt("fov", "72"))
	if _opt("probe", "0") != "1":
		# The weapon at rest: no step bob or breathing while it is measured.
		profile.data["settings"]["camera_motion"] = 0.0
	var weapons: Array = data.weapons()
	if opts.has("weapons"):
		var wanted := _opt("weapons", "").split(",")
		weapons = weapons.filter(func(w): return String(w.id) in wanted)
	game.level = data.level(StringName(_opt("level", "prize_pier")))
	game.weapon_id = weapons[0].id
	change_scene_to_file(game.level.scene_path)
	var director = null
	while director == null or director.player == null:
		await process_frame
		director = get_first_node_in_group("run_director")
	var player = director.player
	await _wait(4)
	director.set_process(false)
	director.set_process_unhandled_input(false)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player._apply_settings()
	director.wave_number = 3
	director._set_state(STATE_WAVE)
	director.hud._wave.text = "WAVE 03"
	director.hud._notice.text = ""
	director.kiosk.set_open(false)
	_stage(director, player)
	# Past the HUD's fade from black.
	await _wait(50)

	var out := _opt("out", "user://ads_audit")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var sights = load(SIGHTS_SCRIPT)
	if _opt("probe", "0") == "1":
		quit(await _probe(player, sights))
		return
	if _opt("full", "0") != "1":
		_render_fast(director.get_parent())
	var cosmetics: Node = root.get_node("Cosmetics")
	var failed := 0
	for weapon in weapons:
		var tiles: Array = []
		for item in cosmetics.items_for(sights.SLOT, weapon.id):
			if opts.has("sights") and not String(item.id) in _opt("sights", "").split(","):
				continue
			var row: Dictionary = await _audit(player, weapon, item, sights)
			if _opt("frames", "0") == "1":
				row["image"].save_png(out.path_join("ads_%s_%s.png" % [weapon.id, item.id]))
			rows.append(row)
			tiles.append(row)
			if not row["ok"]:
				failed += 1
			print("[ads] %-16s %-18s aim %.2f px  shot %.2f px  cover %4.1f%%  clear %3d px  frame %4.1f%%  upper %4.1f%%  %s%s" % [
				row["weapon"], row["sight"], row["aim_err"], row["shot_err"], row["cover"] * 100.0, row["clear"],
				row["frame"] * 100.0, row["upper"] * 100.0, "ok" if row["ok"] else "FAIL", row["note"]])
		await _sheet(out.path_join("ads_%s.png" % weapon.id), tiles)
	_write_csv(out.path_join("ads_audit.csv"))
	print("[ads] %d combinations, %d failed. Sheets and ads_audit.csv in %s" % [rows.size(), failed, ProjectSettings.globalize_path(out)])
	quit(1 if failed > 0 else 0)


## The sight picture does not need shadows or anti-aliasing, and a software
## renderer is several times faster without them.
func _render_fast(level: Node) -> void:
	root.msaa_3d = Viewport.MSAA_DISABLED
	for light in level.find_children("*", "Light3D", true, false):
		light.shadow_enabled = false


## Stands the player at the spot and puts a zombie's head on the point of aim.
func _stage(director, player) -> void:
	player.global_position = _vec(_opt("pos", "5.0,0.0,15.5"))
	var yaw := deg_to_rad(float(_opt("yaw", "12")))
	var distance := float(_opt("range", "9"))
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var enemy = root.get_node("GameData").enemy(&"tourist_shambler")
	var zombie = (load(ZOMBIE_SCENE) as PackedScene).instantiate()
	zombie.setup(enemy, player, 1.0)
	zombie.position = player.global_position + forward * distance
	director._enemies_root.add_child(zombie)
	director._alive.append(zombie)
	zombie.rotation.y = atan2(-forward.x, -forward.z)
	zombie.speed = 0.0
	player.set_look(yaw, atan2(1.5 * enemy.body_scale - 1.62, distance))


## Holds `weapon` wearing `item`, ready at once (no raise animation).
func _hold(player, weapon, item, sights) -> void:
	sights.wear_for_session(weapon.id, item.id)
	player.weapons.set_loadout(weapon.id, &"pulse_pistol" if weapon.id != &"pulse_pistol" else &"ion_carbine")
	var view = player.view
	view._lowering = false
	view._pending = null
	view._build_model(weapon)
	view._raise = 0.0


func _audit(player, weapon, item, sights) -> Dictionary:
	paused = false
	_hold(player, weapon, item, sights)
	var view = player.view
	player.ads = 1.0
	# Fully aimed at once: the zoom is set rather than eased in.
	player.camera.fov = player.head.base_fov * player.ads_fov_scale()
	await _wait(SETTLE_FRAMES)
	# Freeze the game and the shaders' clock, so the frames differ only in what is changed between them.
	paused = true
	Engine.time_scale = 0.0
	var shown: Image = await _grab()
	var rig = view._sight
	var lens_material = rig.lens.get_surface_override_material(0) if rig and rig.lens else null
	var green: Image = shown
	var magenta: Image = shown
	if lens_material:
		# A plain dot (no glow, no over-bright core) in two colours.
		var saved := {}
		for key in ["pattern", "reticle_color", "brightness", "glow"]:
			saved[key] = lens_material.get_shader_parameter(key)
		lens_material.set_shader_parameter("pattern", 0)
		lens_material.set_shader_parameter("brightness", 1.0)
		lens_material.set_shader_parameter("glow", 0.0)
		lens_material.set_shader_parameter("reticle_color", Color(0, 1, 0))
		green = await _grab()
		lens_material.set_shader_parameter("reticle_color", Color(1, 0, 1))
		magenta = await _grab()
		for key in saved:
			lens_material.set_shader_parameter(key, saved[key])
		lens_material.set_shader_parameter("power", 0.0)
	var plain: Image = await _grab()
	view.visible = false
	var bare: Image = await _grab()
	view.visible = true
	Engine.time_scale = 1.0
	paused = false

	var size := Vector2(shown.get_width(), shown.get_height())
	var scale: Vector2 = size / root.get_visible_rect().size
	var centre := size * 0.5
	var camera = player.camera
	var aim: Transform3D = player.aim_transform()
	var note := ""
	var aim_point := centre
	if lens_material:
		aim_point = _marked_centre(green, magenta, centre)
		if aim_point.x < 0.0:
			note = "  (no reticle found)"
	else:
		# Iron sights: where the line from the eye along the sights points.
		var far: Vector3 = view.model.global_transform * (view._eye_local + Vector3(0.0, 0.0, -2000.0))
		aim_point = camera.unproject_position(far) * scale
		if rig and rig.blocked:
			note = "  (sight line blocked: looks over the weapon)"
	var hit := _shot_point(player, aim)
	var shot_px: Vector2 = camera.unproject_position(hit) * scale
	var cover := _cover(plain, bare, centre, size)
	var row := {
		"weapon": String(weapon.id), "sight": String(item.id), "name": item.display_name,
		"aim_err": aim_point.distance_to(centre) if aim_point.x >= 0.0 else 999.0,
		"shot_err": shot_px.distance_to(aim_point) if aim_point.x >= 0.0 else 999.0,
		"cover": cover["window"], "clear": cover["clear"], "frame": cover["frame"], "upper": cover["upper"],
		"note": note, "image": shown,
	}
	row["ok"] = row["aim_err"] <= MAX_ERROR and row["shot_err"] <= MAX_ERROR and row["cover"] <= MAX_COVER
	return row


## Centre of the dot reticle: the pixels that differ between the frame with a
## green dot and the frame with a magenta one, weighted by how much (the
## dot's coverage; whatever is behind it cancels out). (-1, -1) if none do.
func _marked_centre(green: Image, magenta: Image, centre: Vector2) -> Vector2:
	# The strongest difference near the centre is the dot; then its centre of mass.
	var reach := int(green.get_height() * 0.2)
	var peak := Vector2i(-1, -1)
	var most := 0.2
	for y in range(int(centre.y) - reach, int(centre.y) + reach):
		for x in range(int(centre.x) - reach, int(centre.x) + reach):
			var d := _difference(green.get_pixel(x, y), magenta.get_pixel(x, y))
			if d > most:
				most = d
				peak = Vector2i(x, y)
	if peak.x < 0:
		return Vector2(-1.0, -1.0)
	var sum := Vector2.ZERO
	var weight := 0.0
	var spot := int(green.get_height() * 0.03)
	for y in range(peak.y - spot, peak.y + spot + 1):
		for x in range(peak.x - spot, peak.x + spot + 1):
			var d := _difference(green.get_pixel(x, y), magenta.get_pixel(x, y))
			if d > 0.02:
				sum += Vector2(x + 0.5, y + 0.5) * d
				weight += d
	return sum / weight


func _difference(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))


## Where a shot along the player's aim lands (world space).
func _shot_point(player, aim: Transform3D) -> Vector3:
	var from := aim.origin
	var to := from - aim.basis.z * 300.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else to


## What the weapon hides: `plain` has the weapon (no reticle), `bare` does not.
func _cover(plain: Image, bare: Image, centre: Vector2, size: Vector2) -> Dictionary:
	var half := int(round(WINDOW * size.y / 540.0))
	var cx := int(centre.x)
	var cy := int(centre.y)
	var hidden := 0
	for y in range(cy - half, cy + half):
		for x in range(cx - half, cx + half):
			if _difference(plain.get_pixel(x, y), bare.get_pixel(x, y)) > DIFF:
				hidden += 1
	# Clear view straight down from the centre (three columns, two rows in a row).
	var clear := int(size.y) - cy
	for y in range(cy, int(size.y) - 1):
		var solid := 0
		for x in [cx - 2, cx, cx + 2]:
			if _difference(plain.get_pixel(x, y), bare.get_pixel(x, y)) > DIFF \
					and _difference(plain.get_pixel(x, y + 1), bare.get_pixel(x, y + 1)) > DIFF:
				solid += 1
		if solid >= 2:
			clear = y - cy
			break
	# Share of the frame (sampled every other pixel) and of its upper half.
	var all := 0
	var upper := 0
	var samples := 0
	var upper_samples := 0
	for y in range(0, int(size.y), 2):
		for x in range(0, int(size.x), 2):
			var differs := _difference(plain.get_pixel(x, y), bare.get_pixel(x, y)) > DIFF
			samples += 1
			all += 1 if differs else 0
			if y < cy:
				upper_samples += 1
				upper += 1 if differs else 0
	return {"window": float(hidden) / float(4 * half * half), "clear": clear,
		"frame": float(all) / float(samples), "upper": float(upper) / float(upper_samples)}


## One contact sheet: per sight the frame, its centre magnified, and a label.
func _sheet(path: String, tiles: Array) -> void:
	if tiles.is_empty():
		return
	var zoom := TILE.y
	var cell := Vector2i(TILE.x + zoom + 6, TILE.y + 30)
	var grid_rows := int(ceil(tiles.size() / float(COLUMNS)))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(cell.x * COLUMNS + 8, cell.y * grid_rows + 8)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var back := ColorRect.new()
	back.color = Color(0.07, 0.05, 0.12)
	back.size = viewport.size
	viewport.add_child(back)
	for i in tiles.size():
		var row: Dictionary = tiles[i]
		var at := Vector2(8 + (i % COLUMNS) * cell.x, 8 + (i / COLUMNS) * cell.y)
		var image: Image = row["image"]
		var frame := image.duplicate() as Image
		frame.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
		_picture(viewport, frame, at)
		var half := int(ZOOM_SOURCE * image.get_height() / 540.0 * 0.5)
		var crop := image.get_region(Rect2i(image.get_width() / 2 - half, image.get_height() / 2 - half, half * 2, half * 2))
		crop.resize(zoom, zoom, Image.INTERPOLATE_NEAREST)
		_picture(viewport, crop, at + Vector2(TILE.x + 2, 0))
		var label := Label.new()
		label.text = "%s  aim %.2f  shot %.2f  cover %.1f%%  clear %d px  upper %.0f%%  %s" % [row["name"], row["aim_err"],
			row["shot_err"], row["cover"] * 100.0, row["clear"], row["upper"] * 100.0, "OK" if row["ok"] else "FAIL"]
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7) if row["ok"] else Color(1.0, 0.45, 0.45))
		label.position = at + Vector2(2, TILE.y + 3)
		viewport.add_child(label)
	await _wait(3)
	await RenderingServer.frame_post_draw
	var err := viewport.get_texture().get_image().save_png(path)
	print("[ads] sheet %s (error %d)" % [ProjectSettings.globalize_path(path), err])
	viewport.queue_free()


func _picture(parent: Node, image: Image, at: Vector2) -> void:
	var rect := TextureRect.new()
	rect.texture = ImageTexture.create_from_image(image)
	rect.position = at
	parent.add_child(rect)


func _write_csv(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_line("weapon,sight,aim_err_px,shot_err_px,centre_cover,clear_px,frame_share,upper_share,ok,note")
	for row in rows:
		file.store_line("%s,%s,%.3f,%.3f,%.4f,%d,%.4f,%.4f,%s,%s" % [row["weapon"], row["sight"], row["aim_err"], row["shot_err"],
			row["cover"], row["clear"], row["frame"], row["upper"], "ok" if row["ok"] else "FAIL", String(row["note"]).strip_edges()])


# --- motion probe -------------------------------------------------------------------

## Samples, after everything else has moved each frame, where the reticle,
## a shot and the HUD's centre are on screen.
class Sampler extends Node:
	var tool
	var player
	var material
	var active := false
	var samples := 0
	var far_samples := 0
	var far_over := 0
	var worst := 0.0
	var worst_far := 0.0
	var total := 0.0
	var hud_worst := 0.0
	var hud_total := 0.0

	func _init() -> void:
		process_priority = 1000

	func reset() -> void:
		samples = 0
		far_samples = 0
		far_over = 0
		worst = 0.0
		worst_far = 0.0
		total = 0.0
		hud_worst = 0.0
		hud_total = 0.0

	func _process(_delta: float) -> void:
		if not active:
			return
		var camera = player.camera
		var aim: Transform3D = player.aim_transform()
		var hit: Vector3 = tool._shot_point(player, aim)
		var shot: Vector2 = tool._project(camera.global_transform.affine_inverse() * hit, camera.fov)
		var mark: Vector2
		if material:
			var basis: Basis = material.get_shader_parameter("aim_basis")
			mark = tool._project(-basis.z, camera.fov)
		else:
			var view = player.view
			var far: Vector3 = view.model.global_transform * (view._eye_local + Vector3(0.0, 0.0, -2000.0))
			mark = tool._project(camera.global_transform.affine_inverse() * far, camera.fov)
		var error := mark.distance_to(shot)
		var hud_error: float = (tool.PROBE_SIZE * 0.5).distance_to(shot)
		samples += 1
		total += error
		worst = maxf(worst, error)
		hud_total += hud_error
		hud_worst = maxf(hud_worst, hud_error)
		if hit.distance_to(aim.origin) >= tool.PROBE_RANGE:
			far_samples += 1
			far_over += 1 if error > tool.MAX_ERROR else 0
			worst_far = maxf(worst_far, error)


## A point in the camera's space on a PROBE_SIZE screen.
func _project(point: Vector3, fov: float) -> Vector2:
	var k := PROBE_SIZE.y * 0.5 / tan(deg_to_rad(fov) * 0.5) / maxf(1e-6, -point.z)
	return PROBE_SIZE * 0.5 + Vector2(point.x, -point.y) * k


func _press(action: String, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	Input.parse_input_event(e)


func _tap(action: String) -> void:
	_press(action, true)
	await _wait(3)
	_press(action, false)


func _probe(player, sights) -> int:
	var data: Node = root.get_node("GameData")
	var cosmetics: Node = root.get_node("Cosmetics")
	player.set_physics_process(true)
	player.controls_enabled = true
	player.invulnerable = true
	var sampler := Sampler.new()
	sampler.tool = self
	sampler.player = player
	root.add_child(sampler)
	var failed := 0
	for combo in [[&"ion_carbine", &"sight_red_dot"], [&"scatter_blaster", &"sight_holo_ring"],
			[&"rail_lancer", &"sight_long_scope"], [&"arc_coil", &"sight_prism"], [&"pulse_pistol", &"sight_irons"]]:
		var weapon = data.weapon(combo[0])
		_hold(player, weapon, cosmetics.item(combo[1]), sights)
		player.weapons._ammo[weapon.id]["mag"] = weapon.magazine_size
		var rig = player.view._sight
		sampler.material = rig.lens.get_surface_override_material(0) if rig and rig.lens else null
		sampler.reset()
		_press("aim", true)
		await _wait(40)
		sampler.active = true
		await _move(player)
		sampler.active = false
		_press("aim", false)
		await _wait(20)
		var over := float(sampler.far_over) / maxf(1.0, sampler.far_samples)
		var ok: bool = sampler.material == null or over <= PROBE_SLACK
		failed += 0 if ok else 1
		print("[ads] probe %-16s %-17s %s vs shots: mean %.2f px, worst %.2f px (beyond %.0f m: %.2f px, over %.0f px in %.1f%% of %d frames)   HUD centre vs shots: mean %.2f, worst %.2f px  %s" % [
			combo[0], combo[1], "reticle" if sampler.material else "sight line", sampler.total / maxf(1.0, sampler.samples), sampler.worst,
			PROBE_RANGE, sampler.worst_far, MAX_ERROR, over * 100.0, sampler.far_samples, sampler.hud_total / maxf(1.0, sampler.samples),
			sampler.hud_worst, "ok" if ok else "FAIL"])
	failed += await _probe_rules(player, data.weapon(&"ion_carbine"), cosmetics.item(&"sight_red_dot"), sights)
	print("[ads] probe finished, %d failed" % failed)
	return 1 if failed > 0 else 0


## Half a minute of play while aiming: strafes, a walk with a jump, a slow
## turn, then firing on the move.
func _move(player) -> void:
	for action in ["move_right", "move_left"]:
		_press(action, true)
		await _wait(35)
		_press(action, false)
	_press("move_forward", true)
	await _wait(12)
	await _tap("jump")
	await _wait(55)
	_press("move_forward", false)
	_press("move_back", true)
	for i in 60:
		var turn := deg_to_rad(1.2)
		player.set_look(player.rotation.y + turn, player.look_pitch() + sin(i * 0.2) * 0.004)
		player.view.add_look(Vector2(-turn, 0.0))
		await process_frame
	_press("move_back", false)
	_press("fire", true)
	_press("move_left", true)
	await _wait(50)
	_press("move_left", false)
	_press("fire", false)
	await _wait(20)


func _check(label: String, ok: bool) -> int:
	print("[ads] rule %-58s %s" % [label, "ok" if ok else "FAIL"])
	return 0 if ok else 1


## The aim rules: hold, toggle, sprint, reload and switch.
func _probe_rules(player, weapon, item, sights) -> int:
	var settings: Node = root.get_node("Settings")
	var failed := 0
	_hold(player, weapon, item, sights)
	var w = player.weapons
	w._ammo[weapon.id]["mag"] = weapon.magazine_size
	await _wait(10)
	_press("aim", true)
	await _wait(30)
	failed += _check("hold: the sight comes up while the button is held", is_equal_approx(player.ads, 1.0))
	_press("move_forward", true)
	_press("sprint", true)
	await _wait(20)
	failed += _check("aiming keeps the player out of a sprint", not player.sprinting and is_equal_approx(player.ads, 1.0))
	_press("sprint", false)
	_press("move_forward", false)
	w._ammo[weapon.id]["mag"] = 3
	w.start_reload()
	await _wait(25)
	failed += _check("a reload lowers the sight", w.is_reloading() and is_zero_approx(player.ads))
	await _wait(int(weapon.reload_time * 60.0) + 20)
	failed += _check("the sight comes back up after the reload", not w.is_reloading() and is_equal_approx(player.ads, 1.0))
	w.switch_next()
	await _wait(8)
	var dropping: bool = player.ads < 1.0
	await _wait(70)
	failed += _check("a weapon switch lowers the sight and it returns", dropping and is_equal_approx(player.ads, 1.0))
	w.switch_next()
	_press("aim", false)
	await _wait(70)
	failed += _check("hold: the sight drops when the button is let go", is_zero_approx(player.ads))
	_press("move_forward", true)
	_press("sprint", true)
	await _wait(25)
	var was_sprinting: bool = player.sprinting
	_press("aim", true)
	await _wait(30)
	failed += _check("aiming ends a sprint", was_sprinting and not player.sprinting and is_equal_approx(player.ads, 1.0))
	_press("aim", false)
	_press("sprint", false)
	_press("move_forward", false)
	await _wait(30)

	settings.set_value("aim_mode", "toggle")
	await _tap("aim")
	await _wait(30)
	failed += _check("toggle: one tap raises the sight and it stays up", is_equal_approx(player.ads, 1.0))
	await _tap("aim")
	await _wait(30)
	failed += _check("toggle: a second tap lowers it", is_zero_approx(player.ads))
	await _tap("aim")
	await _wait(30)
	_press("move_forward", true)
	await _tap("sprint")
	await _wait(30)
	_press("move_forward", false)
	failed += _check("toggle: sprint lets go of the aim", is_zero_approx(player.ads))
	settings.set_value("aim_mode", "hold")
	return failed
