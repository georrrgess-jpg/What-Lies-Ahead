class_name ShowreelShots
extends RefCounted
## The showreel's shot list (docs/SHOWREEL.md has the plan and its timing).
## Every shot is a method that stages one CineStage; build() returns them in
## order. Times inside a shot are its own seconds; the reel is locked to
## audio/music/showreel_trailer.ogg (120 BPM, a bar is 2 s), so lengths add
## up to the cuts in that track: 12 (title boom), 16 (the beat comes in),
## 28 (drop), 42 (arsenal), 54 (operators), 62 and 66 (title card hits), 72 (end).
##
## Actors, levels and cosmetics are referenced by id, so the reel always shows
## the game's current models and effects. The picks below are the only place
## to swap featured items.

const PIER := "prize_pier"
const NEON := "neon_skyline"
const TIDAL := "tidal_tunnels"
const DUNE := "launch_pad"
const FROST := "summit_lodge"
const STUDIO := "studio"

# --- featured items (swap ids here) ---------------------------------------------

## Operators: the line-up (front row first: the newest), the action hero, the
## squad that opens fire, and the three who hold the line in the finale.
const LINEUP_FRONT: Array[StringName] = [&"op_stunt_ace", &"op_halfpipe", &"op_top_dog", &"op_pixel_pal",
	&"op_windup", &"op_cosmic_sheriff", &"op_tide_keeper", &"op_mech_jockey", &"op_timber_jack"]
const LINEUP_BACK: Array[StringName] = [&"op_boardwalk_ranger", &"op_surf_rescue", &"op_neon_courier", &"op_deep_diver",
	&"op_glitch", &"op_astro_cadet", &"op_frost_guard", &"op_arcade_champion", &"op_midway_maestro"]
const HERO := &"op_windup"
const SQUAD: Array[StringName] = [&"op_stunt_ace", &"op_pixel_pal", &"op_halfpipe"]
const FINALE_SQUAD: Array[StringName] = [&"op_cosmic_sheriff", &"op_glitch", &"op_mech_jockey"]
## Kill effects: the five of the first-person sweep, the hero's, the alpha's showpiece.
const KILL_FX: Array[StringName] = [&"kfx_jackpot", &"kfx_balloon", &"kfx_ghost", &"kfx_disco", &"kfx_tickets"]
const HERO_KILL := &"kfx_pinata"
const SHOWPIECE_KILL := &"kfx_black_hole"
## Tracers: the hero tracer (headshot, finale) and the sweep's run.
const HERO_TRACER := &"tracer_neon"
const TRACERS: Array[StringName] = [&"tracer_neon", &"tracer_ribbon", &"tracer_heartbeat", &"tracer_candy", &"tracer_chevrons"]
## Gloves on the first-person arms.
const GLOVES: Array[StringName] = [&"glove_iron_knuckle", &"glove_showtime"]
## Weapons and one animated finish each for the arsenal run.
const WEAPONS: Array[StringName] = [&"pulse_pistol", &"ion_carbine", &"scatter_blaster", &"comet_cannon",
	&"arc_coil", &"bumper_lobber", &"cryo_beam", &"rail_lancer"]
const ARSENAL_FINISHES: Array[StringName] = [&"fin_marquee", &"fin_data_rain", &"fin_kaleidoscope", &"fin_solar_flare",
	&"fin_thunderhead", &"fin_bass_drop", &"fin_aurora", &"fin_warp"]
## The finishes the camera lingers on (one bar half each), with their cells.
const LINGER: Array[StringName] = [&"fin_marquee", &"fin_cathedral", &"fin_quicksilver", &"fin_kaleidoscope"]
const LINGER_CELLS: Array[StringName] = [&"cellx_marquee", &"cellx_rainbow_road", &"cellx_fusion", &"cellx_twinkle"]
## The charm close-up: [weapon, finish, charm, cell, decal] per side.
const CHARM_RIGS := [[&"scatter_blaster", &"fin_warp", &"charmx_ufo", &"cellx_hyperspace", &"decalx_neon_kitty"],
	[&"pulse_pistol", &"fin_lava_lamp", &"charmx_ferris_wheel", &"cellx_siren", &"decalx_lucky_sevens"]]
const SIGHTS: Array[StringName] = [&"sightx_gallery", &"sightx_gemcut", &"sightx_zombie_eye", &"sightx_periscope"]

## The whole cast, in the order of the march (front first).
const CAST: Array[StringName] = [&"boardwalk_bruiser", &"riot_bruiser", &"frost_yeti", &"tourist_shambler",
	&"lifeguard_runner", &"neon_punk", &"hover_courier", &"deep_diver", &"mascot_inker", &"jelly_head",
	&"dune_space_cadet", &"dune_jet_mechanic", &"dune_hazmat_worker", &"frost_ski_racer", &"frost_frozen_tourist"]

## The low sun over the sea behind the Ferris wheel (Prize Pier), for flares.
const PIER_SUN := Vector3(-120, 9, -70)
const SUN_COLOR := Color(1.0, 0.62, 0.38)


static func build() -> Array[CineShot]:
	var s := ShowreelShots.new()
	var list: Array[CineShot] = [
		# ACT I: cold open, no words (0-12)
		CineShot.make("open_sunset", PIER, 6.0, s._open_sunset),
		CineShot.make("open_eyes", PIER, 3.0, s._open_eyes),
		CineShot.make("open_horde", PIER, 3.0, s._open_horde),
		# The title boom (12)
		CineShot.make("title", PIER, 4.0, s._title),
		# Worlds, joined by whip pans (16-24)
		CineShot.make("world_neon", NEON, 2.0, s._world_neon),
		CineShot.make("world_tidal", TIDAL, 2.0, s._world_tidal),
		CineShot.make("world_dune", DUNE, 2.0, s._world_dune),
		CineShot.make("world_frost", FROST, 2.0, s._world_frost),
		# The cast (24-28)
		CineShot.make("cast_yeti", FROST, 2.0, s._cast_yeti),
		CineShot.make("cast_horde", PIER, 2.0, s._cast_horde),
		# ACT II: the drop, kills (28-42)
		CineShot.make("kill_headshot", PIER, 2.0, s._kill_headshot),
		CineShot.make("kill_sweep", PIER, 3.0, s._kill_sweep),
		CineShot.make("kill_cryo", PIER, 2.0, s._kill_cryo),
		CineShot.make("kill_arc", PIER, 2.0, s._kill_arc),
		CineShot.make("kill_lobber", NEON, 2.0, s._kill_lobber),
		CineShot.make("kill_alpha", NEON, 3.0, s._kill_alpha),
		# The arsenal and its skins (42-54)
		CineShot.make("arsenal", STUDIO, 4.0, s._arsenal),
		CineShot.make("finishes", STUDIO, 4.0, s._finishes),
		CineShot.make("charms", STUDIO, 2.0, s._charms),
		CineShot.make("sights", STUDIO, 2.0, s._sights),
		# Operators (54-62)
		CineShot.make("operators", STUDIO, 3.0, s._operators),
		CineShot.make("op_action", PIER, 3.0, s._op_action),
		CineShot.make("op_squad", PIER, 2.0, s._op_squad),
		# ACT III: the title card (62-72)
		CineShot.make("finale", PIER, 10.0, s._finale),
	]
	return list


# --- helpers ------------------------------------------------------------------

func _world_of(level_id: String) -> WorldData:
	for w in GameData.worlds():
		for l in w.levels:
			if l and String(l.id) == level_id:
				return w
	return null


## The world's name, small and spaced, low in the frame.
func _world_caption(st: CineStage, level_id: String) -> void:
	var w := _world_of(level_id)
	if w:
		st.at(0.3, st.overlay.caption.bind(w.display_name, 1.0, w.accent_color.lerp(Color.WHITE, 0.55)))


## A first-person weapon on the game's own viewmodel rig (WeaponView: sway,
## kick, muzzle flash and the weapon's real reload), pinned to the lens, with
## the operator's arms in `gloves`.
func _viewmodel(st: CineStage, weapon_id: StringName, finish: StringName, gloves: StringName, cell: StringName = &"") -> WeaponView:
	var w := GameData.weapon(weapon_id)
	var view := WeaponView.new()
	st.actors.add_child(view)
	view.show_weapon(w)
	var loadout := Cosmetics.weapon_loadout(weapon_id)
	loadout["finish"] = Cosmetics.item(finish)
	loadout["arms"] = Cosmetics.item(gloves)
	if cell != &"":
		loadout["cell"] = Cosmetics.item(cell)
	WeaponCosmetics.apply(view.model, w, loadout)
	st.camera.near = 0.02
	st.after_camera(func(_t: float):
		view.global_transform = st.camera.global_transform.scaled_local(Vector3.ONE * WeaponView.VIEW_SCALE))
	return view


func _fire_view(st: CineStage, view: WeaponView, weapon_id: StringName, to: Vector3, tracer: StringName = &"") -> void:
	view.on_fired(GameData.weapon(weapon_id))
	st.shoot(weapon_id, view.muzzle_position(), to, 1.0, true, tracer)


## A dark lamp post with a warm bulb, close to the lens (foreground parallax).
func _lamp_post(st: CineStage, pos: Vector3, height := 3.2) -> void:
	var post := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.07
	cyl.height = height
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("1b1024")
	dark.roughness = 0.5
	cyl.material = dark
	post.mesh = cyl
	post.position = pos + Vector3(0, height * 0.5, 0)
	st.actors.add_child(post)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color("ffd9a0")
	hot.emission_enabled = true
	hot.emission = Color("ffc070")
	hot.emission_energy_multiplier = 5.0
	sphere.material = hot
	bulb.mesh = sphere
	bulb.position = pos + Vector3(0, height + 0.1, 0)
	st.actors.add_child(bulb)


func _turntable(st: CineStage, model: Node3D, height := 1.25, span := 1.3) -> Node3D:
	var pivot := Node3D.new()
	st.actors.add_child(pivot)
	pivot.position = Vector3(0, height, 0)
	pivot.add_child(model)
	var box := WeaponCosmetics.visible_bounds(model)
	model.position = -box.get_center()
	pivot.scale = Vector3.ONE * span / maxf(0.01, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	return pivot


func _item_name(id: StringName) -> String:
	var item := Cosmetics.item(id)
	return item.display_name if item else String(id)


# --- ACT I: cold open (no words: the pictures carry it) ------------------------

## Dusk on the pier: a low crane past a lamp post toward the Ferris wheel,
## a lone tourist shambling across in silhouette against the sky.
func _open_sunset(st: CineStage) -> void:
	st.overlay.bars(1.0, 0.0)
	st.overlay.fade(1.0, 0.0)
	st.overlay.fade(0.0, 2.4)
	st.overlay.grade(&"dusk")
	st.lighting(0.35, 0.9, 1.1, 0.3)
	st.fov(40.0, 34.0)
	st.dolly(Vector3(-6, 0.35, 8.5), Vector3(-30, 6.0, -22), Vector3(-9.5, 1.6, 3.5), Vector3(-32, 8.0, -24), -1.4)
	_lamp_post(st, Vector3(-6.6, 0, 5.2))
	var z := st.walker(&"tourist_shambler", Vector3(-12.5, 0, 2.6), 135.0, 0.5)
	st.walker(&"tourist_shambler", Vector3(-20, 0, -8), 120.0, 0.45)
	st.walker(&"lifeguard_runner", Vector3(-23, 0, -12), 100.0, 0.4)
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.45)
	st.focus_on(func(): return st.chest(z), 0.3, 0.004)


## The tourist in close-up, rimmed in neon pink; its eyes catch cyan light
## and it lifts its head into a slow, silent roar.
func _open_eyes(st: CineStage) -> void:
	st.overlay.grade(&"dusk")
	st.lighting(0.3, 0.9, 1.2, 0.25)
	var z := st.zombie(&"tourist_shambler", Vector3(-5, 0, -3), 45.0, "Idle", 0.5)
	var face := st.head(z) + Vector3(0, -0.05, 0)
	var fwd := Vector3(sin(deg_to_rad(45.0)), 0, cos(deg_to_rad(45.0)))
	var side := fwd.cross(Vector3.UP)
	st.fov(30.0, 22.0)
	st.dolly(face + fwd * 2.6 + side * 1.6 + Vector3(0, -0.25, 0), face, face + fwd * 1.7 + side * 0.9 + Vector3(0, -0.1, 0), face + Vector3(0, 0.03, 0), -1.3)
	st.light(face - fwd * 0.9 + Vector3(0, 0.5, 0), UiKit.PINK, 3.0, 3.5)
	var eyes := st.light(face + fwd * 0.3, Wallet.COLOR_GLOW, 0.0, 0.6)
	st.at(1.4, func(): st.actors.create_tween().tween_property(eyes, "light_energy", 0.8, 0.5))
	st.flare_at(func(): return st.head(z) + fwd * 0.18, Wallet.COLOR_GLOW, 0.22, 1.4, 0.5)
	st.at(1.9, st.play.bind(z, "Roar", 0.45, 0.0, 0.4))
	st.focus_on(func(): return st.head(z), 0.16, 0.009)


## Ground level, slow motion: shuffling feet pass the lens, the focus racks
## to the horde walking out of the sunset.
func _open_horde(st: CineStage) -> void:
	st.overlay.grade(&"dusk")
	st.lighting(0.35, 0.9, 1.1, 0.3)
	st.slowmo(0.0, 3.0, 0.5, 0.01, 0.2)
	var eye := Vector3(-7.0, 0.3, 6.0)
	st.fov(44.0, 38.0)
	st.dolly(eye, Vector3(-20, 2.8, -10), eye + Vector3(-0.6, 0.05, -0.6), Vector3(-20, 3.1, -10), 1.0)
	var near := st.walker(&"tourist_shambler", Vector3(-7.6, 0, 4.2), -51.0, 0.8)
	var kinds := [&"tourist_shambler", &"lifeguard_runner", &"boardwalk_bruiser", &"tourist_shambler", &"lifeguard_runner", &"tourist_shambler", &"neon_punk"]
	for i in kinds.size():
		var p := Vector3(-13.0 - (i % 3) * 2.2 - i * 0.6, 0, -2.0 - ((i + 1) % 3) * 1.8 - i * 0.7)
		st.walker(kinds[i], p, 40.0 + randf_range(-8.0, 8.0), 0.7 + 0.05 * (i % 3))
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.5)
	st.overlay.focus(Vector2(0.68, 0.72), 0.12, 0.012)
	st.at(1.0, st.overlay.focus.bind(Vector2(0.4, 0.45), 0.22, 0.008, 0.8))
	st.at(0.0, func(): st.play(near, "Walk", 0.9))


# --- the title -----------------------------------------------------------------

## The boom: the camera cranes up out of the horde to the Ferris wheel and
## the logo rises into the dusk.
func _title(st: CineStage) -> void:
	st.overlay.grade(&"dusk")
	st.overlay.grade(&"golden", 3.0)
	st.lighting(0.5, 0.95, 1.2, 0.5)
	st.at(0.25, func(): st.overlay.logo(Vector2(0.5, 0.4), 150, 1.4))
	st.at(3.3, st.overlay.clear_text.bind(0.6))
	st.shake(0.0, 0.05, 0.9)
	st.fov(50.0, 46.0)
	st.dolly(Vector3(-9, 0.9, 4.0), Vector3(-20, 2.2, -9), Vector3(-5, 7.5, 9.0), Vector3(-26, 6.0, -22), -1.6)
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.4)
	var kinds := [&"tourist_shambler", &"lifeguard_runner", &"tourist_shambler", &"boardwalk_bruiser", &"tourist_shambler", &"lifeguard_runner", &"tourist_shambler", &"neon_punk", &"tourist_shambler"]
	for i in kinds.size():
		var p := Vector3(-12.0 - (i % 3) * 2.2 - i * 0.7, 0, -1.0 - ((i + 1) % 3) * 1.9 - i * 0.7)
		st.walker(kinds[i], p, 40.0 + randf_range(-10.0, 10.0), 0.7)


# --- worlds ----------------------------------------------------------------------

func _world_neon(st: CineStage) -> void:
	st.overlay.grade(&"night")
	st.lighting(1.0, 1.0, 1.1)
	_world_caption(st, NEON)
	var l := GameData.level(&"neon_skyline")
	st.fov(50.0, 44.0)
	st.dolly(l.menu_camera_from, l.menu_camera_to, l.menu_camera_from.lerp(l.menu_camera_to, 0.2) + Vector3(0, -2.0, 0), l.menu_camera_to + Vector3(2, 0, 0))
	st.whip(70.0, 0.25)
	for i in 3:
		st.walker(&"neon_punk", Vector3(4 + i * 2.2, 0, 4 + i), 200.0, 0.8)


func _world_tidal(st: CineStage) -> void:
	st.overlay.grade(&"night")
	st.lighting(1.0, 1.0, 1.0)
	_world_caption(st, TIDAL)
	var l := GameData.level(&"tidal_tunnels")
	st.fov(58.0, 52.0)
	st.dolly(l.menu_camera_from, l.menu_camera_to, l.menu_camera_from + (l.menu_camera_to - l.menu_camera_from).normalized() * 2.8, l.menu_camera_to + Vector3(-1.5, 0, 0))
	st.whip(70.0, 0.25, true)
	st.whip(70.0, 0.25)
	st.walker(&"deep_diver", Vector3(1.5, 0, 1.0), 120.0, 0.7)


func _world_dune(st: CineStage) -> void:
	st.overlay.grade(&"day")
	_world_caption(st, DUNE)
	st.fov(52.0, 46.0)
	st.dolly(Vector3(7, 1.2, 12), Vector3(0, 8, -9), Vector3(9, 3.2, 14.5), Vector3(0, 18, -9))
	st.whip(70.0, 0.25, true)
	st.whip(70.0, 0.25)
	st.walker(&"dune_space_cadet", Vector3(2, 0, 5), 160.0, 0.8)
	st.walker(&"dune_hazmat_worker", Vector3(-2, 0, 3), 170.0, 0.8)
	st.walker(&"dune_jet_mechanic", Vector3(4.5, 0, 2), 190.0, 0.8)


func _world_frost(st: CineStage) -> void:
	st.overlay.grade(&"night")
	st.lighting(1.0, 1.0, 1.3)
	_world_caption(st, FROST)
	var l := GameData.level(&"summit_lodge")
	st.fov(50.0, 44.0)
	st.dolly(l.menu_camera_from, l.menu_camera_to, l.menu_camera_from.lerp(l.menu_camera_to, 0.2) + Vector3(0, -1.5, 0), l.menu_camera_to + Vector3(0, 1.5, 0))
	st.whip(70.0, 0.25, true)


# --- the cast --------------------------------------------------------------------

func _cast_yeti(st: CineStage) -> void:
	st.overlay.grade(&"night")
	st.lighting(0.8, 1.0, 1.3)
	var z := st.zombie(&"frost_yeti", Vector3(3, 0, 8), 10.0, "Idle", 1.0, true)
	st.light(Vector3(3, 2.4, 6.0), Color("8fd8ff"), 2.5, 6.0)
	st.fov(44.0, 36.0)
	st.dolly(Vector3(3.6, 0.45, 13.5), Vector3(3, 2.0, 8), Vector3(3.5, 0.4, 12.0), Vector3(3, 2.4, 8))
	st.at(0.85, func():
		st.play(z, "Roar", 1.0, 0.0, 0.15)
		Sfx.play_at(&"bruiser_roar_1", st.head(z), 0.0, 0.8))
	st.slowmo(0.9, 1.6, 0.45, 0.08, 0.3)
	st.shake(0.95, 0.07, 0.6)


## Every kind of zombie marches at the lens in slow motion, low and close.
func _cast_horde(st: CineStage) -> void:
	st.overlay.grade(&"golden")
	st.lighting(0.55, 0.95, 1.1, 0.6)
	st.slowmo(0.0, 2.0, 0.5, 0.01, 0.15)
	var i := 0
	for row in 5:
		for col in 3:
			if i >= CAST.size():
				break
			var x := -9.0 - row * 2.2
			var z := -13.0 + (col - 1) * 2.0 + (row % 2) * 0.8
			st.walker(CAST[i], Vector3(x, 0, z), 90.0, 0.9)
			i += 1
	st.fov(40.0, 48.0)
	st.dolly(Vector3(-1.5, 0.6, -12.5), Vector3(-13, 1.8, -12.6), Vector3(0.5, 1.0, -12.0), Vector3(-13, 1.8, -12.6))
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.35)
	st.at(0.15, st.overlay.title_card.bind("%d kinds of trouble" % GameData.enemies().size(), "The horde", Vector2(0.5, 0.2), 1.2, UiKit.AMBER, 72))


# --- ACT II: kills -----------------------------------------------------------------

## The drop: a speed ramp into a bolt to the head, the pop in slow motion.
func _kill_headshot(st: CineStage) -> void:
	st.overlay.grade(&"day")
	var z := st.walker(&"tourist_shambler", Vector3(-6, 0, 14), 20.0, 0.8)
	var head := st.head(z)
	st.fov(36.0, 28.0)
	st.dolly(head + Vector3(0.6, -0.15, 3.4), head + Vector3(-0.2, -0.1, 0), head + Vector3(0.3, -0.05, 2.6), head + Vector3(-0.3, 0.0, 0.3))
	st.slowmo(0.3, 1.95, 0.12, 0.05, 0.6)
	st.at(0.3, func():
		st.shoot(&"pulse_pistol", st.head(z) + Vector3(9, -0.2, 0.6), st.head(z), 1.0, true, HERO_TRACER)
		st.kill(z, &"pulse_pistol", true, Vector3(-1, 0, 0)))
	st.at(0.35, func(): Sfx.play(&"headshot_ping", -8.0))
	st.focus_on(func(): return head, 0.2, 0.008)
	st.flare_at(func(): return head, Color(1.0, 0.85, 0.6), 0.22, 0.3, 0.02, 0.35, 0.3)


## First person on the game's own viewmodel: one sweep, five kills in five
## kill effects and five tracers, then the weapon's reload.
func _kill_sweep(st: CineStage) -> void:
	st.overlay.grade(&"day")
	var eye := Vector3(2, 1.6, -13)
	var targets: Array[Zombie] = []
	for i in 5:
		var a := deg_to_rad(-40.0 + i * 20.0)
		var p := eye + Vector3(-cos(a), 0, sin(a)) * (7.0 + (i % 2) * 1.5)
		p.y = 0.0
		targets.append(st.walker(&"tourist_shambler" if i % 2 == 0 else &"lifeguard_runner", p, rad_to_deg(atan2(eye.x - p.x, eye.z - p.z)), 0.9))
	var view := _viewmodel(st, &"ion_carbine", ARSENAL_FINISHES[1], GLOVES[0], LINGER_CELLS[1])
	st.fov(66.0)
	st.track(func(k: float) -> Transform3D:
		var a := deg_to_rad(lerpf(-46.0, 46.0, ease(clampf((k * 1.5 - 0.1) / 0.75, 0.0, 1.0), -1.3)))
		var look := eye + Vector3(-cos(a), -0.08, sin(a))
		return Transform3D(Basis.looking_at(look - eye), eye))
	for i in 5:
		var z := targets[i]
		st.at(0.3 + i * 0.27, func():
			_fire_view(st, view, &"ion_carbine", st.chest(z), TRACERS[i])
			st.kill(z, &"ion_carbine", i == 4, (st.chest(z) - eye).normalized(), 5.0, KILL_FX[i]))
	st.at(1.95, func(): view.play_reload(GameData.weapon(&"ion_carbine"), 1.0))


func _kill_cryo(st: CineStage) -> void:
	st.overlay.grade(&"day")
	var cryo := GameData.weapon(&"cryo_beam")
	var zs: Array[Zombie] = []
	for i in 3:
		zs.append(st.zombie(&"tourist_shambler" if i != 1 else &"boardwalk_bruiser", Vector3(-4.5 - i * 1.6, 0, 13.0 + 1.2 * i), 100.0, "Walk", 0.7))
	var muzzle := Vector3(3.5, 1.3, 16.5)
	var beam := BeamVisual.new()
	beam.color = cryo.tracer_color
	beam.width = 0.1
	st.actors.add_child(beam)
	st.fov(44.0, 38.0)
	st.dolly(Vector3(0.5, 1.4, 20.5), Vector3(-6, 1.2, 14), Vector3(-0.6, 1.2, 19.2), Vector3(-6.2, 1.1, 14))
	st.every_frame(func(t: float):
		var k := clampi(int((t - 0.15) / 0.3), 0, 2)
		beam.aim(muzzle, st.chest(zs[k]) if is_instance_valid(zs[k]) else muzzle, t > 0.1 and t < 1.15))
	for i in 3:
		st.at(0.3 + i * 0.3, func(): StatusEffects.of(zs[i]).apply(cryo, 9.0))
	st.at(0.12, func(): Sfx.play(cryo.fire_sound, -6.0))
	st.slowmo(1.25, 1.95, 0.3, 0.05, 0.4)
	st.at(1.3, func():
		for i in 3:
			st.kill(zs[i], &"cryo_beam", false, Vector3(-1, 0, 0), 2.0))
	st.shake(1.3, 0.06, 0.4)
	st.focus_on(func(): return st.chest(zs[1]) if is_instance_valid(zs[1]) else Vector3(-6, 1, 14), 0.3, 0.006)


func _kill_arc(st: CineStage) -> void:
	st.overlay.grade(&"day")
	var arc := GameData.weapon(&"arc_coil")
	var zs: Array[Zombie] = []
	var spots := [Vector3(-6, 0, -11), Vector3(-8.2, 0, -12.6), Vector3(-7.4, 0, -15.6), Vector3(-10.2, 0, -14.4), Vector3(-11, 0, -10.8)]
	for p in spots:
		zs.append(st.zombie(&"tourist_shambler" if zs.size() % 2 == 0 else &"lifeguard_runner", p, 95.0, "Walk", 0.6))
	var muzzle := Vector3(0.5, 1.35, -10.0)
	st.fov(50.0, 44.0)
	st.dolly(Vector3(-2.5, 2.4, -7.5), Vector3(-8.5, 0.9, -13), Vector3(-3.4, 1.8, -8.6), Vector3(-8.6, 0.9, -13))
	st.at(0.3, func():
		Sfx.play(arc.fire_sound, -5.0)
		LightningBolt.spawn(st.actors, muzzle, st.chest(zs[0]), arc.tracer_color, 0.09, 0.3, 0.3))
	for i in zs.size():
		st.at(0.3 + i * 0.09, func():
			if i > 0:
				LightningBolt.spawn(st.actors, st.chest(zs[i - 1]), st.chest(zs[i]), arc.tracer_color, 0.07, 0.3, 0.25)
				Sfx.play_at(arc.chain_sound, st.chest(zs[i]), -6.0)
			WeaponFx.shock_crackle(zs[i]))
		st.at(0.75 + i * 0.06, st.kill.bind(zs[i], &"arc_coil", false, Vector3(-1, 0, 0), 3.0))
	st.slowmo(0.3, 0.9, 0.4, 0.05, 0.3)
	st.flare_at(func(): return muzzle, arc.tracer_color, 0.4, 0.3, 0.02, 0.5, 0.3)


func _kill_lobber(st: CineStage) -> void:
	st.overlay.grade(&"night")
	var lob := GameData.weapon(&"bumper_lobber")
	var zs: Array[Zombie] = []
	var centre := Vector3(-3, 0, 1)
	for i in 5:
		var a := TAU * float(i) / 5.0
		zs.append(st.zombie(&"neon_punk" if i % 2 else &"tourist_shambler", centre + Vector3(cos(a), 0, sin(a)) * 1.4, 90.0 + i * 30.0, "Walk", 0.8))
	st.fov(46.0, 40.0)
	st.dolly(Vector3(5, 2.2, 7.5), centre + Vector3(0, 0.8, 0), Vector3(4.0, 1.4, 6.2), centre + Vector3(0, 1.0, 0))
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	var m := StandardMaterial3D.new()
	m.albedo_color = lob.tracer_color
	m.emission_enabled = true
	m.emission = lob.tracer_color
	m.emission_energy_multiplier = 3.0
	sphere.material = m
	ball.mesh = sphere
	st.actors.add_child(ball)
	var start := Vector3(7, 1.4, 3.5)
	st.every_frame(func(t: float):
		var k := clampf((t - 0.05) / 0.6, 0.0, 1.0)
		ball.visible = k > 0.0 and k < 1.0
		ball.global_position = start.lerp(centre + Vector3(0, 0.3, 0), k) + Vector3.UP * sin(k * PI) * 2.6)
	st.at(0.05, func(): Sfx.play(lob.fire_sound, -5.0))
	st.slowmo(0.62, 1.9, 0.25, 0.04, 0.5)
	st.at(0.65, func():
		WeaponFx.explosion(st.actors, centre + Vector3(0, 0.4, 0), lob.tracer_color, 2.6)
		Sfx.play(lob.explosion_sound, -3.0)
		for z in zs:
			st.kill(z, &"bumper_lobber", false, (z.global_position - centre).normalized() + Vector3.UP * 0.3, 9.0))
	st.shake(0.65, 0.12, 0.6)
	st.flare_at(func(): return centre + Vector3(0, 0.6, 0), lob.tracer_color.lerp(Color.WHITE, 0.3), 0.7, 0.65, 0.02, 0.8, 0.6)


func _kill_alpha(st: CineStage) -> void:
	# The Neon Skyline finale's named alpha (its data already makes it big).
	st.overlay.grade(&"night")
	var z := st.walker(&"alpha_riot", Vector3(-6, 0, 2), 90.0, 0.8)
	st.move(z, Vector3.ZERO, 1.2)
	var muzzle := Vector3(7, 1.5, 3.4)
	st.fov(40.0, 32.0)
	st.track(func(k: float) -> Transform3D:
		var at := z.global_position if is_instance_valid(z) else Vector3(-4, 0, 2)
		var from := at + Vector3(5.6 - k * 1.2, 0.45, 3.2 - k * 0.6)
		return Transform3D(Basis.looking_at(at + Vector3(0, 2.4, 0) - from), from))
	for i in 5:
		st.at(0.15 + i * 0.18, func():
			var to := st.chest(z) + Vector3(0, 0.6, 0) * z.data.body_scale
			st.shoot(&"comet_cannon", muzzle, to)
			st.hit(z, &"comet_cannon", 1.0, to, to - muzzle))
	st.at(0.25, st.overlay.title_card.bind(_enemy_name(&"alpha_riot"), "Alpha", Vector2(0.24, 0.76), 0.9, UiKit.RED, 56))
	st.slowmo(1.25, 3.0, 0.3, 0.06, 0.6)
	st.at(1.25, func():
		st.shoot(&"rail_lancer", muzzle, st.chest(z) + Vector3(0, 0.5, 0), 1.0, true, HERO_TRACER)
		st.kill(z, &"rail_lancer", false, Vector3(-1, 0, 0), 4.0, SHOWPIECE_KILL))
	st.shake(1.3, 0.12, 0.6)
	st.focus_on(func(): return st.chest(z) if is_instance_valid(z) else Vector3(-4, 1.5, 2), 0.3, 0.006)


func _enemy_name(id: StringName) -> String:
	var e := GameData.enemy(id)
	return e.display_name if e else String(id)


# --- the arsenal -----------------------------------------------------------------

## Eight weapons on the turntable, one per beat, each in an animated finish;
## the turn carries on across the cuts (match cuts).
func _arsenal(st: CineStage) -> void:
	st.overlay.grade(&"studio")
	st.lighting(1.0, 1.0, 1.1)
	var pivots: Array[Node3D] = []
	for i in WEAPONS.size():
		var p := _turntable(st, st.weapon(WEAPONS[i], ARSENAL_FINISHES[i]), 1.3, 1.75)
		p.visible = i == 0
		pivots.append(p)
	st.fov(34.0, 30.0)
	st.dolly(Vector3(0.6, 1.45, 3.2), Vector3(0, 1.2, 0), Vector3(-0.4, 1.38, 2.7), Vector3(0, 1.2, 0))
	st.every_frame(func(t: float):
		var k := clampi(int(t / 0.5), 0, pivots.size() - 1)
		for i in pivots.size():
			pivots[i].visible = i == k
		pivots[k].rotation.y = deg_to_rad(-65.0 + t * 32.0))
	st.at(0.1, st.overlay.title_card.bind("The arsenal", "%d weapons" % GameData.weapons().size(), Vector2(0.5, 0.8), 3.2, UiKit.CYAN, 72))
	for i in range(1, WEAPONS.size()):
		st.at(i * 0.5, func(): Sfx.play(&"ui_whoosh", -16.0, 0.8))


## A slow macro glide along the carbine; the finish changes on the beat and
## the camera lingers on each animated one, a Ferris wheel charm turning.
func _finishes(st: CineStage) -> void:
	st.overlay.grade(&"studio")
	st.lighting(0.8, 1.0, 1.2)
	var model := st.weapon(&"ion_carbine", LINGER[0], &"charmx_ferris_wheel")
	var w := GameData.weapon(&"ion_carbine")
	WeaponCosmetics.apply(model, w, {"finish": Cosmetics.item(LINGER[0]), "cell": Cosmetics.item(LINGER_CELLS[0]), "charm": Cosmetics.item(&"charmx_ferris_wheel")})
	var pivot := _turntable(st, model, 1.25, 1.6)
	pivot.rotation.y = deg_to_rad(90.0)
	st.every_frame(func(t: float): pivot.rotation.z = sin(t * 1.3) * 0.04)
	st.fov(24.0, 20.0)
	st.dolly(Vector3(0.7, 1.45, 1.6), Vector3(0.45, 1.25, 0), Vector3(-0.7, 1.38, 1.5), Vector3(-0.45, 1.22, 0), -1.1)
	st.light(Vector3(0, 2.4, 1.2), Color("ffe6c8"), 1.6, 4.0)
	for i in LINGER.size():
		st.at(i * 1.0 + 0.02, func():
			if i > 0:
				WeaponCosmetics.apply(model, w, {"finish": Cosmetics.item(LINGER[i]), "cell": Cosmetics.item(LINGER_CELLS[i]), "charm": Cosmetics.item(&"charmx_ferris_wheel")})
				st.overlay.flash(Color.WHITE, 0.25, 0.12)
			st.overlay.caption(_item_name(LINGER[i]), 0.55, UiKit.CREAM))
	st.focus_on(func(): return pivot.global_position, 0.35, 0.006)


## Two charms swing as their weapons rock: a saucer spinning its lights, a
## Ferris wheel turning; the camera trucks from one to the other while the
## cells pulse and the decals catch the light.
func _charms(st: CineStage) -> void:
	st.overlay.grade(&"studio")
	st.lighting(0.8, 1.0, 1.2)
	var pivots: Array[Node3D] = []
	var models: Array[Node3D] = []
	for i in CHARM_RIGS.size():
		var r: Array = CHARM_RIGS[i]
		var model := st.weapon(r[0], r[1], r[2])
		WeaponCosmetics.apply(model, GameData.weapon(r[0]), {"finish": Cosmetics.item(r[1]), "charm": Cosmetics.item(r[2]), "cell": Cosmetics.item(r[3]), "decal": Cosmetics.item(r[4])})
		var p := _turntable(st, model, 1.3, 1.0)
		p.position.x = -0.6 + i * 1.2
		p.rotation.y = deg_to_rad(90.0)
		pivots.append(p)
		models.append(model)
	st.every_frame(func(t: float):
		for i in pivots.size():
			pivots[i].rotation.z = sin(t * 2.4 + i * 1.7) * 0.14
			pivots[i].rotation.y = deg_to_rad(90.0 + sin(t * 1.1 + i) * 12.0))
	var charm_at := func(i: int) -> Vector3:
		var anchor := models[i].find_child("CharmPoint", true, false) as Node3D
		return (anchor.global_position if anchor else pivots[i].global_position) + Vector3(0, -0.1, 0)
	st.fov(30.0, 27.0)
	st.track(func(k: float) -> Transform3D:
		var e := ease(k, -1.6)
		var at: Vector3 = (charm_at.call(0) as Vector3).lerp(charm_at.call(1), e)
		var from := at + Vector3(lerpf(0.12, -0.12, e), 0.04, 0.72)
		return Transform3D(Basis.looking_at(at - from), from))
	st.light(Vector3(0, 2.0, 1.4), Color("ffe6c8"), 1.4, 4.0)
	st.at(0.2, st.overlay.title_card.bind("%d cosmetics" % GameData.cosmetics().size(), "Make it yours", Vector2(0.5, 0.8), 1.4, UiKit.PINK, 64))


## The sight changes on a cannon held in profile; the frame holds still so
## each swap reads as a match cut.
func _sights(st: CineStage) -> void:
	st.overlay.grade(&"studio")
	var models: Array[Node3D] = []
	for i in SIGHTS.size():
		var m := st.weapon(&"comet_cannon", &"fin_quicksilver", &"", SIGHTS[i])
		st.actors.add_child(m)
		m.global_transform = Transform3D(Basis.IDENTITY.rotated(Vector3.UP, deg_to_rad(18.0)), Vector3(0, 1.25, 0))
		m.scale = Vector3.ONE * 2.2
		m.visible = i == 0
		models.append(m)
	st.fov(30.0, 24.0)
	st.dolly(Vector3(1.5, 1.6, 0.9), Vector3(0, 1.38, -0.15), Vector3(1.05, 1.52, 0.55), Vector3(0, 1.4, -0.15))
	st.every_frame(func(t: float):
		var k := clampi(int(t / 0.5), 0, models.size() - 1)
		for i in models.size():
			models[i].visible = i == k)
	for i in SIGHTS.size():
		st.at(i * 0.5 + 0.02, func():
			if i > 0:
				Sfx.play(&"weap_switch", -10.0)
			st.overlay.caption(_item_name(SIGHTS[i]), 0.25, UiKit.CYAN))
	st.whip(-70.0, 0.22)


# --- operators -------------------------------------------------------------------

## The line-up: the newest operators in front, the originals behind, each
## striking its pose as the camera trucks past under neon rim lights.
func _operators(st: CineStage) -> void:
	st.overlay.grade(&"studio")
	st.lighting(0.9, 1.0, 1.1)
	var rows := [[LINEUP_FRONT, 0.9, 0.0], [LINEUP_BACK, -0.9, 0.55]]
	var n := 0
	for row in rows:
		var ids: Array[StringName] = row[0]
		for i in ids.size():
			var x: float = (i - (ids.size() - 1) * 0.5) * 1.1 + row[2]
			var op := st.operator(ids[i], Vector3(x, 0.0, row[1] - absf(x) * 0.12), -x * 3.0)
			st.at(0.1 + n * 0.06, func(): Operators.play(op, "Pose"))
			n += 1
	st.whip(-70.0, 0.22, true)
	st.light(Vector3(-4, 2.5, -2.5), UiKit.PINK, 3.0, 9.0)
	st.light(Vector3(4, 2.5, -2.5), UiKit.CYAN, 3.0, 9.0)
	st.fov(38.0, 34.0)
	st.dolly(Vector3(-4.2, 1.1, 5.0), Vector3(-2.0, 1.15, 0), Vector3(4.2, 1.2, 5.0), Vector3(2.0, 1.15, 0), -1.2)
	st.at(0.15, st.overlay.title_card.bind("%d operators" % GameData.cosmetics().filter(func(c): return c.slot == &"avatar").size(), "Suit up", Vector2(0.5, 0.17), 2.2, UiKit.AMBER, 72))


## The hero runs, stops, aims and fires; the chase camera swings round.
func _op_action(st: CineStage) -> void:
	st.overlay.grade(&"golden")
	var op := st.operator(HERO, Vector3(8, 0, 16), -90.0, "Run")
	var gun := st.weapon(&"ion_carbine", ARSENAL_FINISHES[0])
	Operators.hold_weapon(op, gun)
	st.move(op, Vector3(-Operators.RUN_SPEED, 0, 0), 0.0, 1.5)
	var target := st.walker(&"tourist_shambler", Vector3(-8, 0, 15.4), 90.0, 0.8)
	st.walker(&"lifeguard_runner", Vector3(-10, 0, 17.6), 90.0, 0.7)
	st.walker(&"tourist_shambler", Vector3(-11.5, 0, 14.2), 80.0, 0.6)
	st.at(1.5, Operators.play.bind(op, "AimIdle", "", 0.2))
	st.fov(46.0, 40.0)
	st.track(func(k: float) -> Transform3D:
		var at := op.global_position
		var side := lerpf(3.4, 2.2, ease(k, -1.5))
		var from := at + Vector3(-1.4 + k * 2.8, 1.4, side)
		return Transform3D(Basis.looking_at(at + Vector3(-1.6, 1.15, 0) - from), from))
	for i in 3:
		st.at(1.9 + i * 0.18, func():
			Operators.play(op, "Fire", "AimIdle", 0.05)
			st.shoot(&"ion_carbine", st.muzzle(gun), st.chest(target) if i < 2 else st.head(target), 1.0, true, TRACERS[1]))
	st.slowmo(2.25, 3.0, 0.35, 0.05, 0.3)
	st.at(2.28, st.kill.bind(target, &"ion_carbine", true, Vector3(-1, 0, 0), 4.0, HERO_KILL))
	st.whip(70.0, 0.2)


## Three operators open fire together, low and side-on, in slow motion.
func _op_squad(st: CineStage) -> void:
	st.overlay.grade(&"golden")
	var guns := [&"scatter_blaster", &"rail_lancer", &"pulse_pistol"]
	var ops: Array[Node3D] = []
	var models: Array[Node3D] = []
	for i in SQUAD.size():
		var op := st.operator(SQUAD[i], Vector3(-3.2 + i * 1.25, 0, 13.4 + absf(i - 1) * 0.6), -90.0, "AimIdle")
		var m := st.weapon(guns[i], ARSENAL_FINISHES[(i * 3 + 2) % ARSENAL_FINISHES.size()])
		Operators.hold_weapon(op, m)
		ops.append(op)
		models.append(m)
	var targets: Array[Zombie] = []
	for i in 4:
		targets.append(st.walker(CAST[i + 3], Vector3(-11.0 - i * 1.3, 0, 12.4 + i * 0.9), 90.0, 0.8))
	st.whip(70.0, 0.2, true)
	st.slowmo(0.4, 2.0, 0.4, 0.1, 0.2)
	st.fov(40.0, 36.0)
	st.dolly(Vector3(-1.0, 0.5, 17.0), Vector3(-5.5, 1.3, 13.6), Vector3(-1.6, 0.6, 16.4), Vector3(-6.5, 1.3, 13.6))
	for i in 4:
		var z := targets[i]
		var who := i % ops.size()
		st.at(0.35 + i * 0.2, func():
			Operators.play(ops[who], "Fire", "AimIdle", 0.05)
			st.shoot(guns[who], st.muzzle(models[who]), st.chest(z), 1.0, true, TRACERS[(i + 2) % TRACERS.size()])
			st.kill(z, guns[who], i == 3, Vector3(-1, 0, 0), 4.0, KILL_FX[(i + 1) % KILL_FX.size()]))


# --- ACT III: the title card -------------------------------------------------------

## Silhouettes against the sunset: three operators hold the line as the horde
## comes; the camera cranes up and back, the logo rises, PLAY NOW on the hit.
func _finale(st: CineStage) -> void:
	st.overlay.grade(&"golden")
	st.overlay.fade(1.0, 0.0, Color.WHITE)
	st.overlay.fade(0.0, 0.6, Color.WHITE)
	st.lighting(0.45, 0.95, 1.2, 0.45)
	for i in FINALE_SQUAD.size():
		var op := st.operator(FINALE_SQUAD[i], Vector3(-2 + i * 1.2, 0, 15 + absf(i - 1) * 0.7), -100.0, "AimIdle")
		Operators.hold_weapon(op, st.weapon([&"scatter_blaster", &"ion_carbine", &"rail_lancer"][i], ARSENAL_FINISHES[i * 3]))
	for i in 10:
		st.walker(CAST[i % CAST.size()], Vector3(-11 - (i % 4) * 2.0, 0, 12 + (i / 4) * 2.5 + (i % 2)), 90.0, 0.5)
	st.fov(44.0, 52.0)
	st.dolly(Vector3(2.4, 0.45, 18.2), Vector3(-8, 2.0, 9), Vector3(10, 7.0, 22), Vector3(-12, 3.0, 6), -1.5)
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.45)
	st.at(0.5, func(): st.overlay.logo(Vector2(0.5, 0.33), 150, 1.0))
	var counts := PackedStringArray([
		"%d WORLDS" % GameData.worlds().size(), "%d WEAPONS" % GameData.weapons().size(),
		"%d ZOMBIES" % GameData.enemies().size(),
		"%d OPERATORS" % GameData.cosmetics().filter(func(c): return c.slot == &"avatar").size(),
		"%d COSMETICS" % GameData.cosmetics().size()])
	st.at(1.9, st.overlay.chips.bind(counts, Vector2(0.5, 0.6), 0.14, [UiKit.CYAN, UiKit.PINK, UiKit.AMBER, UiKit.CYAN, UiKit.PINK]))
	st.at(4.0, func(): st.overlay.marquee("PLAY NOW", 84, Vector2(0.5, 0.8)))
	st.at(8.4, st.overlay.fade.bind(1.0, 1.5))
