class_name ShowreelShots
extends RefCounted
## The showreel's shot list (docs/SHOWREEL.md has the plan and its timing).
## Every shot is a method that stages one CineStage; build() returns them in
## order. Times inside a shot are its own seconds; the reel is locked to
## audio/music/showreel_trailer.ogg (120 BPM, a bar is 2 s, a beat 0.5 s), so
## lengths add up to the cuts in that track: 12 (title boom), 16 (the beat
## comes in), 24-39 (the new worlds: a hit on every alpha), 42 (drop), 62
## (arsenal), 72 (operators), 78 and 82 (title card hits), 88 (end).
##
## Actors, levels and cosmetics are referenced by id, so the reel always shows
## the game's current models and effects. The picks below are the only place
## to swap featured items.

const PIER := "prize_pier"
const NEON := "neon_skyline"
const TIDAL := "tidal_tunnels"
const DUNE := "launch_pad"
const FROST := "summit_lodge"
const MALL := "midnight_mall"
const TEMPLE := "lost_temple"
const CANDY := "candy_works"
const LAVA := "lava_lagoon"
const SKY := "sky_harbor"
const BOOT := "boot_camp"
const STUDIO := "studio"

# --- featured items (swap ids here) ---------------------------------------------

## Operators: the line-up (front row first: the newest), the action hero, the
## squad that opens fire, and the three who hold the line in the finale.
const LINEUP_FRONT: Array[StringName] = [&"op_stunt_ace", &"op_halfpipe", &"op_top_dog", &"op_pixel_pal",
	&"op_windup", &"op_cosmic_sheriff", &"op_tide_keeper", &"op_mech_jockey", &"op_timber_jack"]
const LINEUP_BACK: Array[StringName] = [&"op_boardwalk_ranger", &"op_surf_rescue", &"op_neon_courier", &"op_deep_diver",
	&"op_glitch", &"op_astro_cadet", &"op_frost_guard", &"op_arcade_champion", &"op_midway_maestro"]
const HERO := &"op_windup"
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
## The sight brought to the eye in the aim-down-sights shot (on the cannon).
const ADS_SIGHT := &"sightx_gemcut"
const SIGHTS: Array[StringName] = [&"sightx_gallery", &"sightx_gemcut", &"sightx_zombie_eye", &"sightx_periscope"]

## The whole cast, in the order of the march (front first).
const CAST: Array[StringName] = [&"boardwalk_bruiser", &"riot_bruiser", &"frost_yeti", &"jungle_overgrown",
	&"tourist_shambler", &"mall_walker", &"candy_gummy", &"lava_fire_dancer",
	&"lifeguard_runner", &"neon_punk", &"sky_diver", &"jungle_explorer",
	&"hover_courier", &"deep_diver", &"candy_taffy_puller", &"lava_tiki_bartender",
	&"mascot_inker", &"jelly_head", &"mall_flinger", &"sky_balloon_vendor"]
## The five new worlds: [set, its two zombies, its alpha, grade].
const NEW_WORLDS := [
	[MALL, &"mall_walker", &"mall_flinger", &"alpha_night_manager", &"night"],
	[TEMPLE, &"jungle_explorer", &"jungle_overgrown", &"alpha_idol_keeper", &"golden"],
	[CANDY, &"candy_gummy", &"candy_taffy_puller", &"alpha_confectioner", &"day"],
	[LAVA, &"lava_fire_dancer", &"lava_tiki_bartender", &"alpha_kahuna", &"dusk"],
	[SKY, &"sky_diver", &"sky_balloon_vendor", &"alpha_captain", &"day"],
]

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
		# Ten worlds: the first four joined by whip pans (16-24)...
		CineShot.make("world_neon", NEON, 2.0, s._world_neon),
		CineShot.make("world_tidal", TIDAL, 2.0, s._world_tidal),
		CineShot.make("world_dune", DUNE, 2.0, s._world_dune),
		CineShot.make("world_frost", FROST, 2.0, s._world_frost),
		# ...the five new ones, each a landmark and its alpha on a hit (24-39)
		CineShot.make("world_mall", MALL, 2.0, s._world_mall),
		CineShot.make("alpha_mall", MALL, 1.0, s._alpha.bind(0)),
		CineShot.make("world_temple", TEMPLE, 2.0, s._world_temple),
		CineShot.make("alpha_temple", TEMPLE, 1.0, s._alpha.bind(1)),
		CineShot.make("world_candy", CANDY, 2.0, s._world_candy),
		CineShot.make("alpha_candy", CANDY, 1.0, s._alpha.bind(2)),
		CineShot.make("world_lava", LAVA, 2.0, s._world_lava),
		CineShot.make("alpha_lava", LAVA, 1.0, s._alpha.bind(3)),
		CineShot.make("world_sky", SKY, 2.0, s._world_sky),
		CineShot.make("alpha_sky", SKY, 1.0, s._alpha.bind(4)),
		# The breath: the whole cast in slow motion (39-42)
		CineShot.make("cast_horde", PIER, 3.0, s._cast_horde),
		# ACT II: the drop. Play: kills, sights, moves, Sparks (42-62)
		CineShot.make("kill_headshot", PIER, 2.0, s._kill_headshot),
		CineShot.make("kill_sweep", PIER, 3.0, s._kill_sweep),
		CineShot.make("ads", PIER, 2.0, s._ads),
		CineShot.make("boot_camp", BOOT, 2.0, s._boot_camp),
		CineShot.make("moves", BOOT, 3.0, s._moves),
		CineShot.make("kill_cryo", PIER, 2.0, s._kill_cryo),
		CineShot.make("kill_lobber", NEON, 2.0, s._kill_lobber),
		CineShot.make("bounty", PIER, 2.0, s._bounty),
		CineShot.make("kill_alpha", NEON, 2.0, s._kill_alpha),
		# Make it yours: the arsenal, finishes, sights, operators (62-78)
		CineShot.make("arsenal", STUDIO, 4.0, s._arsenal),
		CineShot.make("finishes", STUDIO, 4.0, s._finishes),
		CineShot.make("sights", STUDIO, 2.0, s._sights),
		CineShot.make("operators", STUDIO, 3.0, s._operators),
		CineShot.make("op_action", PIER, 3.0, s._op_action),
		# ACT III: the title card (78-88)
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
func _viewmodel(st: CineStage, weapon_id: StringName, finish: StringName, gloves: StringName, cell: StringName = &"", sight: StringName = &"") -> CineViewmodel:
	var w := GameData.weapon(weapon_id)
	var view := CineViewmodel.new()
	st.actors.add_child(view)
	view.show_weapon(w)
	var loadout := Cosmetics.weapon_loadout(weapon_id)
	loadout["finish"] = Cosmetics.item(finish)
	loadout["arms"] = Cosmetics.item(gloves)
	if cell != &"":
		loadout["cell"] = Cosmetics.item(cell)
	if sight != &"":
		loadout["sight"] = Cosmetics.item(sight)
	WeaponCosmetics.apply(view.model, w, loadout)
	view.refit()
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
	st.whip(70.0, 0.22)


## A new world's landmark: the camera drifts in (never stopping at the cut)
## while two of its zombies come at the lens.
func _landmark(st: CineStage, index: int, from: Vector3, look_from: Vector3, to: Vector3, look_to: Vector3, fov: Vector2, walkers: Array) -> void:
	var w: Array = NEW_WORLDS[index]
	st.overlay.grade(w[4])
	_world_caption(st, w[0])
	st.fov(fov.x, fov.y)
	st.dolly(from, look_from, to, look_to, -1.15)
	for i in walkers.size():
		var spot: Array = walkers[i]
		st.walker(w[1 + i % 2], spot[0], spot[1], 0.85)


## Midnight Mall: down from the glass dome toward the Moonfall Fountain.
func _world_mall(st: CineStage) -> void:
	st.whip(70.0, 0.22, true)
	st.lighting(1.0, 1.0, 1.15)
	_landmark(st, 0, Vector3(-8.0, 7.5, 17.0), Vector3(0, 3.5, -9), Vector3(-5.0, 3.6, 6.5), Vector3(0, 4.2, -11),
		Vector2(52.0, 46.0), [[Vector3(-2.5, 0, -3.0), 10.0], [Vector3(2.5, 0, -4.5), -10.0], [Vector3(4.5, 0, -1.0), -25.0]])


## Lost Temple: rising toward the Jade Idol's carved face at golden hour.
func _world_temple(st: CineStage) -> void:
	st.lighting(1.0, 1.0, 1.1)
	_landmark(st, 1, Vector3(7.0, 1.6, 15.0), Vector3(0, 7.0, -24), Vector3(6.0, 4.2, 7.5), Vector3(0, 8.0, -26),
		Vector2(48.0, 44.0), [[Vector3(-2.0, 0, -6.0), 15.0], [Vector3(3.5, 0, -8.0), -5.0], [Vector3(-5.5, 0, -9.0), 20.0]])


## Candy Works: low across the factory floor to the colossal gumball machine.
func _world_candy(st: CineStage) -> void:
	_landmark(st, 2, Vector3(-10.0, 1.6, 18.0), Vector3(0, 9.0, -28), Vector3(-9.0, 3.6, 9.0), Vector3(0, 11.0, -28),
		Vector2(50.0, 45.0), [[Vector3(-3.0, 0, -4.0), 10.0], [Vector3(-7.0, 0, -2.0), 30.0], [Vector3(3.0, 0, -6.0), -10.0]])


## Lava Lagoon: Mount Kahuna erupts (the world's twist): the sky flares red
## and ember bombs drop into their glowing rings among the fire dancers.
func _world_lava(st: CineStage) -> void:
	st.lighting(1.0, 1.0, 1.2)
	_landmark(st, 3, Vector3(-6.0, 1.7, 17.0), Vector3(14, 24, -300), Vector3(-4.5, 3.2, 10.0), Vector3(16, 28, -300),
		Vector2(50.0, 46.0), [[Vector3(-2.0, 0, -3.0), 5.0], [Vector3(4.0, 0, -5.0), -15.0], [Vector3(-7.5, 0, -1.0), 25.0]])
	var eruption := st.set_root.find_child("Eruption", false, false) as LavaEruption
	if eruption == null:
		return
	# Drive the twist by hand (it normally follows the run director's waves).
	eruption.telegraph = 1.0
	eruption.fall_time = 0.45
	eruption._active = true
	eruption._level = 1.0
	eruption._apply(1.0)
	for spot in [[0.0, Vector3(-4.5, 0, 6.0)], [0.35, Vector3(5.0, 0, 5.5)], [0.7, Vector3(-8.0, 0, 1.5)]]:
		st.at(spot[0], eruption._start.bind(spot[1]))
	st.shake(1.0, 0.05, 0.4)


## Sky Harbor: across the hub isle to the airship Cumulus at its mooring.
func _world_sky(st: CineStage) -> void:
	st.lighting(1.0, 1.0, 1.1)
	_landmark(st, 4, Vector3(-19.0, 1.8, 8.0), Vector3(-53, 12, -1.5), Vector3(-23.5, 3.6, 5.5), Vector3(-53, 14, -1.5),
		Vector2(50.0, 46.0), [[Vector3(-31.0, 0, 1.0), 75.0], [Vector3(-33.0, 0, -2.5), 85.0], [Vector3(-29.0, 0, -4.0), 95.0]])


## Where each new world's alpha walks on (on its own set): [position, yaw].
const ALPHA_SPOTS := [[Vector3(-2.5, 0, -3.5), 0.0], [Vector3(-4.0, 0, -6.5), 0.0], [Vector3(-6.0, 0, -5.0), 10.0],
	[Vector3(-5.0, 0, 6.0), 0.0], [Vector3(-33.0, 0, 0.5), 90.0]]


## A new world's alpha boss walks at a low lens on the hit, its name beside it.
func _alpha(st: CineStage, index: int) -> void:
	var w: Array = NEW_WORLDS[index]
	var spot: Array = ALPHA_SPOTS[index]
	st.overlay.grade(w[4])
	st.lighting(0.85, 1.0, 1.25)
	var z := st.walker(w[3], spot[0], spot[1], 0.8)
	var fwd := Vector3(sin(deg_to_rad(spot[1])), 0, cos(deg_to_rad(spot[1])))
	var side := fwd.cross(Vector3.UP)
	var tall := 1.75 * z.data.body_scale
	st.fov(40.0, 36.0)
	# Far enough back that the whole head and shoulders stay inside the bars.
	st.track(func(k: float) -> Transform3D:
		var at := z.global_position if is_instance_valid(z) else (spot[0] as Vector3)
		var from := at + fwd * lerpf(8.6, 7.8, k) + side * lerpf(1.9, 1.5, k) + Vector3.UP * 1.0
		return Transform3D(Basis.looking_at(at + Vector3.UP * tall * 0.55 - from), from))
	st.light(spot[0] + fwd * 2.5 + Vector3.UP * 3.0, UiKit.PINK if w[4] == &"night" else Color("ffd9a8"), 2.5, 9.0)
	st.shake(0.0, 0.06, 0.5)
	st.at(0.05, st.overlay.title_card.bind(_enemy_name(w[3]), "Alpha", Vector2(0.3, 0.74), 0.4, UiKit.RED, 56))


# --- the cast --------------------------------------------------------------------

## Every kind of zombie marches at the lens in slow motion, low and close.
func _cast_horde(st: CineStage) -> void:
	st.overlay.grade(&"golden")
	st.lighting(0.55, 0.95, 1.1, 0.6)
	st.slowmo(0.0, 3.0, 0.5, 0.01, 0.4)
	var i := 0
	for row in 5:
		for col in 4:
			if i >= CAST.size():
				break
			var x := -9.0 - row * 2.2
			var z := -12.6 + (col - 1.5) * 1.9 + (row % 2) * 0.7
			st.walker(CAST[i], Vector3(x, 0, z), 90.0, 0.9)
			i += 1
	st.fov(40.0, 48.0)
	st.dolly(Vector3(-1.5, 0.6, -12.5), Vector3(-13, 1.8, -12.6), Vector3(0.5, 1.0, -12.0), Vector3(-13, 1.8, -12.6))
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.35)
	st.at(0.15, st.overlay.title_card.bind("%d kinds of trouble" % GameData.enemies().size(), "The horde", Vector2(0.5, 0.2), 1.8, UiKit.AMBER, 72))


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
	# The Neon Skyline finale's named alpha (its data already makes it big),
	# framed from far enough back that its head and shield stay in the frame.
	st.overlay.grade(&"night")
	var z := st.walker(&"alpha_riot", Vector3(-6, 0, 2), 90.0, 0.8)
	st.move(z, Vector3.ZERO, 0.9)
	var muzzle := Vector3(7, 1.5, 3.4)
	st.fov(40.0, 34.0)
	st.track(func(k: float) -> Transform3D:
		var at := z.global_position if is_instance_valid(z) else Vector3(-4, 0, 2)
		var from := at + Vector3(7.0 - k * 0.8, 1.0, 4.0 - k * 0.4)
		return Transform3D(Basis.looking_at(at + Vector3(0, 1.75, 0) - from), from))
	for i in 4:
		st.at(0.1 + i * 0.16, func():
			var to := st.chest(z) + Vector3(0, 0.6, 0) * z.data.body_scale
			st.shoot(&"comet_cannon", muzzle, to)
			st.hit(z, &"comet_cannon", 1.0, to, to - muzzle))
	st.at(0.1, st.overlay.title_card.bind(_enemy_name(&"alpha_riot"), "Alpha", Vector2(0.26, 0.74), 0.6, UiKit.RED, 56))
	st.slowmo(0.9, 2.0, 0.3, 0.15, 0.5)
	st.at(0.9, func():
		st.shoot(&"rail_lancer", muzzle, st.chest(z) + Vector3(0, 0.5, 0), 1.0, true, HERO_TRACER)
		st.kill(z, &"rail_lancer", false, Vector3(-1, 0, 0), 4.0, SHOWPIECE_KILL))
	st.shake(0.95, 0.1, 0.6)
	st.focus_on(func(): return st.chest(z) if is_instance_valid(z) else Vector3(-4, 1.5, 2), 0.3, 0.006)


func _enemy_name(id: StringName) -> String:
	var e := GameData.enemy(id)
	return e.display_name if e else String(id)


## Aim down sights: the cannon comes up to the eye on the game's own eye
## line, its optic's reticle lights on a far head, the view zooms, two shots
## and the head pops in slow motion.
func _ads(st: CineStage) -> void:
	st.overlay.grade(&"day")
	var eye := Vector3(3.0, 1.6, -12.0)
	var z := st.walker(&"lifeguard_runner", Vector3(-13.0, 0, -15.5), 75.0, 0.7)
	st.walker(&"tourist_shambler", Vector3(-11.0, 0, -9.5), 100.0, 0.7)
	var view := _viewmodel(st, &"comet_cannon", ARSENAL_FINISHES[3], GLOVES[1], &"", ADS_SIGHT)
	st.after_camera(func(t: float):
		var k := smoothstep(0.15, 0.6, t)
		view.aim = k
		st.lens_fov(lerpf(64.0, 64.0 / 1.6, k)))
	st.track(func(_k: float) -> Transform3D:
		var head := st.head(z) if is_instance_valid(z) else Vector3(-12.0, 1.6, -15.0)
		var look := head.lerp(eye + (head - eye).normalized() * 10.0 + Vector3(0, -0.6, 2.0), 1.0 - smoothstep(0.0, 0.6, st.t))
		return Transform3D(Basis.looking_at(look - eye), eye))
	st.at(0.05, st.overlay.caption.bind(_item_name(ADS_SIGHT), 1.2, UiKit.CYAN))
	st.at(0.85, func(): _fire_view(st, view, &"comet_cannon", st.chest(z) + Vector3(0, 0.2, 0)))
	st.at(1.05, func():
		_fire_view(st, view, &"comet_cannon", st.head(z), HERO_TRACER)
		st.kill(z, &"comet_cannon", true, Vector3(-1, 0, -0.2), 4.0, KILL_FX[3]))
	st.slowmo(1.05, 2.0, 0.35, 0.12, 0.4)


## Boot Camp: up the training midway past its arches; an operator sprints
## the course toward the loadout station.
func _boot_camp(st: CineStage) -> void:
	st.overlay.grade(&"day")
	var op := st.operator(LINEUP_FRONT[1], Vector3(0.8, 0, -4.0), 180.0, "Run")
	st.move(op, Vector3(0, 0, -Operators.RUN_SPEED))
	st.fov(46.0, 42.0)
	st.dolly(Vector3(2.6, 1.3, 4.5), Vector3(0, 2.4, -30), Vector3(3.4, 4.6, -3.0), Vector3(0, 1.4, -38), -1.15)
	st.at(0.1, st.overlay.title_card.bind("Boot Camp", "Learn the ropes", Vector2(0.5, 0.78), 1.3, UiKit.CYAN, 72))


## First person down the Boot Camp lane: up onto the crates (mantle), over
## the barrier (vault) and under the low sign in a slide, on one camera curve.
func _moves(st: CineStage) -> void:
	st.overlay.grade(&"day")
	var view := _viewmodel(st, &"ion_carbine", ARSENAL_FINISHES[1], GLOVES[0])
	var x := 0.9
	st.spline([
		[0.0, Vector3(x, 1.6, -32.4), Vector3(x, 1.3, -44)],
		[0.45, Vector3(x, 1.55, -35.9), Vector3(x, 1.0, -40)],
		[0.8, Vector3(x, 2.85, -37.3), Vector3(x, 2.2, -45)],
		[1.05, Vector3(x, 2.8, -38.9), Vector3(x, 1.8, -48)],
		[1.35, Vector3(x, 1.6, -41.2), Vector3(x, 1.5, -52)],
		[1.7, Vector3(x, 2.15, -45.0), Vector3(x, 1.5, -55)],
		[1.95, Vector3(x, 1.6, -47.4), Vector3(x, 1.3, -60)],
		[2.3, Vector3(x, 0.95, -50.2), Vector3(x, 0.9, -62)],
		[2.65, Vector3(x, 0.82, -53.0), Vector3(x, 1.0, -64)],
		[3.0, Vector3(x, 1.25, -56.0), Vector3(x, 1.3, -68)],
	])
	st.fov(68.0, 74.0)
	st.every_frame(func(t: float):
		var mantle := smoothstep(0.3, 0.55, t) * (1.0 - smoothstep(0.85, 1.1, t))
		var vault := smoothstep(1.5, 1.65, t) * (1.0 - smoothstep(1.8, 2.0, t))
		view.mantle = maxf(mantle, vault)
		view.slide = smoothstep(2.1, 2.35, t) * (1.0 - smoothstep(2.75, 3.0, t))
		view.sprint = clampf(1.0 - view.mantle - view.slide, 0.0, 1.0)
		view.gait = Vector2(t * TAU * 1.7, view.sprint))
	st.at(0.1, st.overlay.caption.bind("Sprint  ·  mantle  ·  vault  ·  slide  ·  dash", 2.3, UiKit.CREAM))
	st.at(2.15, func(): Sfx.play(&"ui_whoosh", -10.0, 0.7))


## A bounty: the golden runner bolts with its ticket prize and drops to a
## headshot; its Sparks fly out of it and home on the lens.
func _bounty(st: CineStage) -> void:
	st.overlay.grade(&"golden")
	var z := st.walker(&"lifeguard_runner", Vector3(-9.0, 0, 13.5), 90.0, 1.0, true)
	z.set_rank(Zombie.RANK_BOUNTY, 1.0, Color(0.55, 0.42, 0.05))
	st.fov(42.0, 38.0)
	st.track(func(k: float) -> Transform3D:
		var at := z.global_position if is_instance_valid(z) else Vector3(-3, 0, 13.5)
		var from := Vector3(at.x + lerpf(-1.0, 1.4, k), 1.3, 19.5)
		return Transform3D(Basis.looking_at(at + Vector3(0.6, 1.0, 0) - from), from))
	var sparks := SparkField.new()
	st.actors.add_child(sparks)
	st.after_camera(func(_t: float):
		var b := st.camera.global_basis
		sparks.global_position = st.camera.global_position - b.y * 0.35 - b.z * 0.6)
	st.at(0.1, st.overlay.title_card.bind("Bounty", "Catch it, cash it", Vector2(0.5, 0.22), 0.8, UiKit.AMBER, 64))
	st.at(0.8, func():
		st.shoot(&"pulse_pistol", st.head(z) + Vector3(6, 0.3, 5), st.head(z), 1.0, true, HERO_TRACER)
		var at := st.chest(z)
		st.kill(z, &"pulse_pistol", true, Vector3(1, 0, 0), 4.0, &"kfx_jackpot")
		sparks.drop(at, 40))
	st.slowmo(0.8, 1.6, 0.4, 0.1, 0.4)
	st.at(1.0, func(): st.overlay.spark_counter(1200, 1240, 0.8, Vector2(0.5, 0.74)))


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
	st.at(1.6, st.overlay.title_card.bind("%d cosmetics" % GameData.cosmetics().size(), "Sparks buy them in the Shop", Vector2(0.5, 0.22), 1.6, UiKit.PINK, 64))
	st.focus_on(func(): return pivot.global_position, 0.35, 0.006)


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
	# Far enough back that the whole cannon and its optic stay in frame.
	st.fov(32.0, 28.0)
	st.dolly(Vector3(2.0, 1.8, 1.35), Vector3(0, 1.42, -0.1), Vector3(1.7, 1.72, 1.1), Vector3(0, 1.44, -0.1), -1.15)
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
	# Wide enough for whole heads in both rows; the card sits low, over legs.
	st.fov(40.0, 37.0)
	st.dolly(Vector3(-3.6, 1.45, 6.4), Vector3(-1.6, 1.2, 0), Vector3(3.6, 1.5, 6.4), Vector3(1.6, 1.2, 0), -1.15)
	st.at(0.15, st.overlay.title_card.bind("%d operators" % GameData.cosmetics().filter(func(c): return c.slot == &"avatar").size(), "Suit up", Vector2(0.5, 0.84), 2.2, UiKit.AMBER, 64))


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
		# The hero stays whole in frame (head, hands and weapon), a little right
		# of centre, looking into the space the shots go.
		var at := op.global_position
		var side := lerpf(4.4, 3.4, ease(k, -1.5))
		var from := at + Vector3(-0.6 + k * 1.8, 1.55, side)
		return Transform3D(Basis.looking_at(at + Vector3(-0.9, 1.1, 0) - from), from))
	for i in 3:
		st.at(1.9 + i * 0.18, func():
			Operators.play(op, "Fire", "AimIdle", 0.05)
			st.shoot(&"ion_carbine", st.muzzle(gun), st.chest(target) if i < 2 else st.head(target), 1.0, true, TRACERS[1]))
	st.slowmo(2.25, 3.0, 0.35, 0.05, 0.3)
	st.at(2.28, st.kill.bind(target, &"ion_carbine", true, Vector3(-1, 0, 0), 4.0, HERO_KILL))
	st.whip(70.0, 0.2)


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
		"%d COSMETICS" % GameData.cosmetics().size(), "3 DIFFICULTIES"])
	st.at(1.9, st.overlay.chips.bind(counts, Vector2(0.5, 0.6), 0.14, [UiKit.CYAN, UiKit.PINK, UiKit.AMBER, UiKit.CYAN, UiKit.PINK, UiKit.AMBER]))
	st.at(4.0, func(): st.overlay.marquee("PLAY NOW", 84, Vector2(0.5, 0.8)))
	st.at(8.4, st.overlay.fade.bind(1.0, 1.5))
