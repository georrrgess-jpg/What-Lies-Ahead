class_name ShowreelShots
extends RefCounted
## The trailer's shot list (docs/SHOWREEL.md has the plan and its timing).
## Every shot is a method that stages one CineStage; build() returns them in
## order. Times inside a shot are its own seconds; the reel is locked to
## audio/music/showreel_trailer.ogg: 120 BPM, a beat is 0.5 s, a bar 2.0 s,
## 56.0 s in all and a ring-out on black to 58.5. Every cut lands on a beat;
## the locked hits are 5.0 (the gun snaps ready), 7.5 (silence), 8.0 (logo
## slam), 10.0 (the groove: fifteen worlds), 17.5 (15 WORLDS), 18-22 (an
## alpha a hit), 23.0 (the cast), 25.5 (silence), 26.0 (the drop), 27.5 (the
## WINNER round), 29.0 (reloads), 35.0-37.0 (half time, the headshot on
## 36.0), 40.0 (Endless), 44.0 (Last Ride), 46.0 (make it yours), 50.0 (the
## finale), 53.0 (the title) and 56.0 (black).
##
## Actors, levels and cosmetics are referenced by id, so the reel always shows
## the game's current models and effects. The picks below are the only place
## to swap featured items.

const PIER := "prize_pier"
const STUDIO := "studio"
const BOOT := "boot_camp"
const CITY := "endless_city"
const BEAT := 0.5

# --- featured items (swap ids here) ---------------------------------------------

## The fifteen worlds in unlock order: [level, camera from, look from, camera
## to, look to, zombies (walking at the lens), where they stand (ZERO: on
## the floor a few metres in front of the lens's last position)].
const WORLDS := [
	["prize_pier", Vector3(-8.0, 1.3, 7.5), Vector3(-27, 6.5, -22), Vector3(-10.0, 1.9, 4.5), Vector3(-29, 7.0, -22),
		[&"tourist_shambler", &"lifeguard_runner", &"boardwalk_bruiser"], Vector3(-13.5, 0, 0.5)],
	["neon_skyline", Vector3(25, 11, 24), Vector3(-2, 3, -6), Vector3(20.0, 8.0, 18.5), Vector3(-1, 3, -6),
		[&"neon_punk", &"hover_courier", &"riot_bruiser"], Vector3(17.2, 6.0, 15.3)],
	["tidal_tunnels", Vector3(7.6, 2.3, 6.9), Vector3(-1.5, 3.2, -2.5), Vector3(5.4, 2.6, 4.9), Vector3(-3.0, 3.0, -2.5),
		[&"deep_diver", &"jelly_head", &"mascot_inker"], Vector3.ZERO],
	["launch_pad", Vector3(7, 1.2, 12), Vector3(0, 8, -9), Vector3(8.5, 3.0, 14), Vector3(0, 15, -9),
		[&"dune_space_cadet", &"dune_hazmat_worker", &"dune_jet_mechanic"], Vector3.ZERO],
	["summit_lodge", Vector3(23.5, 2.6, 19.5), Vector3(-4, 5, -12), Vector3(20.5, 2.0, 16.0), Vector3(-4, 5.5, -12),
		[&"frost_ski_racer", &"frost_yeti", &"frost_frozen_tourist"], Vector3(16.0, 0, 11.0)],
	["midnight_mall", Vector3(-4.8, 3.4, 14.8), Vector3(1, 3.2, -9), Vector3(-4.2, 2.9, 11.5), Vector3(1, 3.0, -10),
		[&"mall_walker", &"mall_flinger", &"mall_walker"], Vector3(-4.0, 0, 3.4)],
	["lost_temple", Vector3(7.0, 1.6, 15.0), Vector3(0, 7.0, -24), Vector3(6.5, 3.2, 10.5), Vector3(0, 8.0, -25),
		[&"jungle_explorer", &"jungle_overgrown", &"jungle_explorer"], Vector3.ZERO],
	["candy_works", Vector3(-10.0, 1.6, 18.0), Vector3(0, 5.0, -28), Vector3(-9.5, 1.8, 12.5), Vector3(0, 5.5, -28),
		[&"candy_gummy", &"candy_taffy_puller", &"candy_gummy"], Vector3(-8.25, 0, 7.15)],
	["lava_lagoon", Vector3(-6.0, 1.7, 17.0), Vector3(14, 24, -300), Vector3(-5.0, 2.8, 12.5), Vector3(16, 28, -300),
		[&"lava_fire_dancer", &"lava_tiki_bartender", &"lava_fire_dancer"], Vector3.ZERO],
	["sky_harbor", Vector3(-19.5, 1.6, 8.4), Vector3(-53, 8.0, -1.5), Vector3(-22.0, 2.0, 7.1), Vector3(-53, 8.5, -1.5),
		[&"sky_diver", &"sky_balloon_vendor", &"sky_diver"], Vector3(-27.26, 1.59, 5.78)],
	["ghost_train", Vector3(9.0, 3.0, 24.0), Vector3(-4, 3.8, -20), Vector3(6.5, 2.2, 19.5), Vector3(-4, 4.0, -20),
		[&"fright_ghost", &"fright_pumpkin_head", &"fright_ghost"], Vector3(4.57, 0, 12.25)],
	["boomtown", Vector3(-0.8, 1.6, 4.5), Vector3(0.8, 7, 26), Vector3(0.0, 1.9, 7.0), Vector3(0.8, 8, 26),
		[&"gulch_cowpoke", &"gulch_prospector", &"gulch_cowpoke"], Vector3(0.3, 0, 12.0)],
	["skull_harbor", Vector3(13.0, 2.6, 11.0), Vector3(-24, 5, -6), Vector3(9.5, 1.7, 8.5), Vector3(-24, 5, -6),
		[&"cove_deckhand", &"cove_powder_monkey", &"cove_deckhand"], Vector3(4.45, 0, 6.32)],
	["royal_faire", Vector3(9.0, 2.4, 25.0), Vector3(-3, 6, -22), Vector3(6.5, 1.6, 20.0), Vector3(-3, 6.5, -22),
		[&"faire_knight", &"faire_jester", &"faire_knight"], Vector3(5.4, 0, 15.1)],
	["toy_shop", Vector3(-15.0, 2.6, 27.0), Vector3(14, 6, -14), Vector3(-12.0, 1.7, 23.0), Vector3(14, 6.5, -14),
		[&"toy_windup_soldier", &"toy_plush_brute", &"toy_windup_soldier"], Vector3(-8.26, 0, 17.68)],
]
## The five alpha reveals: [level, alpha, where it stands, yaw toward the lens].
const ALPHAS := [
	["ghost_train", &"alpha_ringmaster", Vector3(0.5, 0, 8.0), 20.0],
	["boomtown", &"alpha_rattlebones", Vector3(0.5, 0, 14.5), 180.0],
	["skull_harbor", &"alpha_barnacle", Vector3(2.0, 0, 4.5), 105.0],
	["royal_faire", &"alpha_black_knight", Vector3(1.0, 0, 11.0), 25.0],
	["toy_shop", &"alpha_toymaker", Vector3(-4.0, 0, 15.0), -40.0],
]
## The zombies that lunge at the lens in the muzzle-flash cold open: [level, zombie, where, yaw].
const LUNGES := [
	["neon_skyline", &"neon_punk", Vector3(5.0, 0, 6.5), 200.0],
	["tidal_tunnels", &"jelly_head", Vector3(0.3, 0, 12.0), 0.0],
	["launch_pad", &"dune_space_cadet", Vector3(2.0, 0, 5.0), 160.0],
	["midnight_mall", &"mall_walker", Vector3(-1.0, 0, 5.5), 0.0],
]
## The march of the cast: one zombie of every world, and two alphas behind.
const CAST: Array[StringName] = [&"tourist_shambler", &"neon_punk", &"deep_diver", &"dune_space_cadet", &"frost_yeti",
	&"mall_flinger", &"jungle_overgrown", &"candy_taffy_puller", &"lava_fire_dancer", &"sky_balloon_vendor",
	&"fright_pumpkin_head", &"gulch_prospector", &"cove_powder_monkey", &"faire_knight", &"toy_plush_brute"]
const CAST_ALPHAS: Array[StringName] = [&"alpha_kahuna", &"alpha_yeti"]
## The alpha that charges in Last Ride (Prize Pier's own).
const LAST_RIDE_ALPHA := &"alpha_bruiser"
## Reloads: the weapon reloading in the dark open, the cock in the dark
## before the drop, and the four showcase reloads: [weapon, finish, level,
## eye, look at, the rig's turn about the gun from and to (degrees: pitch,
## yaw, roll), reload length, the part shown (fractions)].
const DARK_RELOAD := &"rail_lancer"
const LOCK_LOAD := &"scatter_blaster"
## Where a reload close-up moves the viewmodel (metres in the lens's space):
## left and up toward the middle of the frame, a little nearer.
const CLOSE_UP := Vector3(-0.035, 0.025, 0.02)
const RELOADS := [
	[&"lava_lampoon", &"", "lava_lagoon", Vector3(4.0, 1.6, 16.5), Vector3(4.6, 1.3, 10.0),
		Vector3(4, 16, 0), Vector3(8, 24, 4), 1.6, Vector2(0.22, 0.85)],
	[&"t_minus_six", &"fin_treasure_map", "launch_pad", Vector3(0.0, 1.6, 21.5), Vector3(0.0, 4.0, 10.0),
		Vector3(16, 0, 0), Vector3(22, -8, 0), 1.37, Vector2(0.22, 0.95)],
	[&"coin_op", &"fin_multiball", "neon_skyline", Vector3(3.0, 1.6, 12.5), Vector3(1.0, 1.4, 4.0),
		Vector3(-6, -14, -8), Vector3(-3, -22, -12), 1.3, Vector2(0.15, 0.92)],
	[&"yoyo_loco", &"fin_galaxy", "candy_works", Vector3(-9.5, 1.6, 14.0), Vector3(0, 6.0, -28),
		Vector3(0, -10, 10), Vector3(3, -3, 5), 1.25, Vector2(0.12, 0.92)],
]
## Operators: the line-up (Madame Fortuna in the centre), the three who hold
## the line in the finale.
const LINEUP_FRONT: Array[StringName] = [&"op_stunt_ace", &"op_halfpipe", &"op_top_dog", &"op_pixel_pal",
	&"op_fortuna", &"op_windup", &"op_cosmic_sheriff", &"op_tide_keeper", &"op_mech_jockey"]
const LINEUP_BACK: Array[StringName] = [&"op_boardwalk_ranger", &"op_surf_rescue", &"op_neon_courier", &"op_deep_diver",
	&"op_glitch", &"op_astro_cadet", &"op_frost_guard", &"op_arcade_champion", &"op_midway_maestro", &"op_timber_jack"]
const FINALE_SQUAD: Array[StringName] = [&"op_cosmic_sheriff", &"op_fortuna", &"op_windup"]
const FINALE_GUNS: Array[StringName] = [&"whirligig", &"ticket_ripper", &"rail_lancer"]
const FINALE_FINISHES: Array[StringName] = [&"fin_thunderhead", &"fin_jackpot", &"fin_last_light"]
## Kill effects of the parade and the finale.
const PARADE_FX: Array[StringName] = [&"kfx_confetti", &"kfx_disco", &"kfx_pinata"]
const FINALE_FX: Array[StringName] = [&"kfx_jackpot", &"kfx_firework", &"kfx_tickets", &"kfx_balloon"]
## Tracers: the hero tracer (headshots) and the parade's.
const HERO_TRACER := &"tracer_neon"
const TRACERS: Array[StringName] = [&"tracer_ribbon", &"tracer_heartbeat", &"tracer_candy"]
## Gloves on the first-person arms.
const GLOVES: Array[StringName] = [&"glove_iron_knuckle", &"glove_showtime"]
## Make it yours: four weapons, one animated Legendary (or Mythic) finish each.
const ARSENAL: Array[StringName] = [&"ticket_ripper", &"whirligig", &"strike_zone", &"rail_lancer"]
const ARSENAL_FINISHES: Array[StringName] = [&"fin_jackpot", &"fin_thunderhead", &"fin_galaxy", &"fin_last_light"]
## The sight in the aim-down-sights shot (on the cannon) and the finish of the print.
const ADS_SIGHT := &"sightx_gemcut"
const PRINT_WEAPON := &"ion_carbine"
const PRINT_FINISH := &"fin_kintsugi"

## Shots heavy enough to build during the warm-up instead of at their cut
## (CinePlayer measures each cut: --showreel-report=1).
const BUILT_AHEAD: Array[String] = ["dark_reload", "lunge_0", "lunge_1", "lunge_2", "lunge_3", "roar", "title",
	"world_0", "world_1", "world_2", "world_3", "world_4", "world_5", "world_6", "world_7", "world_8", "world_9",
	"world_10", "world_11", "world_12", "world_13", "world_14", "worlds_card", "alpha_0", "alpha_1", "alpha_2",
	"alpha_3", "alpha_4", "cast", "lock_load", "ripper", "reload_0", "reload_1", "reload_2", "reload_3", "moves",
	"ads", "cryo", "lobber", "coin_op", "parade", "city_wide", "city_street", "last_ride", "arsenal", "operators",
	"prints", "finale", "title_end"]

## Sets loaded behind the black before the first shot (CinePlayer.early_sets):
## Ashfall City's set-up took a 90 ms frame when it loaded mid-reel.
const EARLY_SETS: PackedStringArray = ["endless_city"]
## Sizes of the cards, stamps and counters (their glyphs are drawn once
## behind the black, so no card rasterises them on its cut).
const TYPE_SIZES: PackedInt32Array = [84, 96, 104, 110, 120, 160, 170]

## The low sun over the sea behind the Ferris wheel (Prize Pier), for flares.
const PIER_SUN := Vector3(-120, 9, -70)
const SUN_COLOR := Color(1.0, 0.62, 0.38)


static func build() -> Array[CineShot]:
	var s := ShowreelShots.new()
	var list: Array[CineShot] = [
		# Cold open: a face, a reload in the dark (0-5.0), four flashes (5.0-7.0)
		CineShot.make("cold_open", PIER, 6 * BEAT, s._cold_open),
		CineShot.make("dark_reload", PIER, 4 * BEAT, s._dark_reload),
	]
	for i in LUNGES.size():
		list.append(CineShot.make("lunge_%d" % i, LUNGES[i][0], BEAT, s._lunge.bind(i)))
	# The roar and the silence (7.0-8.0), the slam (8.0-10.0)
	list.append(CineShot.make("roar", PIER, 2 * BEAT, s._roar))
	list.append(CineShot.make("title", PIER, 4 * BEAT, s._title))
	# Fifteen worlds, a beat each (10.0-17.5), and their card (17.5-18.0)
	for i in WORLDS.size():
		list.append(CineShot.make("world_%d" % i, WORLDS[i][0], BEAT, s._world.bind(i)))
	list.append(CineShot.make("worlds_card", WORLDS[WORLDS.size() - 1][0], BEAT, s._worlds_card))
	# Five alphas, a hit each (18.0-23.0), the cast (23.0-24.0)
	for i in ALPHAS.size():
		list.append(CineShot.make("alpha_%d" % i, ALPHAS[i][0], 2 * BEAT, s._alpha.bind(i)))
	list.append(CineShot.make("cast", PIER, 2 * BEAT, s._cast))
	# The breath: lock and load (24.0-25.5), silence (25.5-26.0)
	list.append(CineShot.make("lock_load", PIER, 3 * BEAT, s._lock_load))
	list.append(CineShot.make("silence", PIER, BEAT, s._black))
	# The drop (26.0-29.0), four reloads (29.0-33.0)
	list.append(CineShot.make("ripper", PIER, 6 * BEAT, s._ripper))
	for i in RELOADS.size():
		list.append(CineShot.make("reload_%d" % i, RELOADS[i][2], 2 * BEAT, s._showcase.bind(i)))
	list.append_array([
		# Movement (33.0-35.0), the headshot in half time (35.0-37.0)
		CineShot.make("moves", BOOT, 4 * BEAT, s._moves),
		CineShot.make("ads", PIER, 4 * BEAT, s._ads),
		# Mayhem (37.0-40.0)
		CineShot.make("cryo", PIER, 2 * BEAT, s._cryo),
		CineShot.make("lobber", "candy_works", 2 * BEAT, s._lobber),
		CineShot.make("coin_op", "neon_skyline", BEAT, s._coin_op),
		CineShot.make("parade", "midnight_mall", BEAT, s._parade),
		# Endless: Ashfall City (40.0-44.0), Last Ride (44.0-46.0)
		CineShot.make("city_wide", CITY, 4 * BEAT, s._city_wide),
		CineShot.make("city_street", CITY, 4 * BEAT, s._city_street),
		CineShot.make("last_ride", PIER, 4 * BEAT, s._last_ride),
		# Make it yours (46.0-50.0)
		CineShot.make("arsenal", STUDIO, 4 * BEAT, s._arsenal),
		CineShot.make("operators", STUDIO, 2 * BEAT, s._operators),
		CineShot.make("prints", STUDIO, 2 * BEAT, s._prints),
		# The finale: hold the line (50.0), the title (53.0), black (56.0)
		CineShot.make("finale", PIER, 6 * BEAT, s._finale),
		CineShot.make("title_end", PIER, 6 * BEAT, s._title_end),
		# The music's ring-out on black (56.0 to the track's end, 58.5)
		CineShot.make("ring_out", PIER, 5 * BEAT, s._ring_out),
	])
	for shot in list:
		shot.prebuild = shot.id in BUILT_AHEAD
	return list


# --- helpers ------------------------------------------------------------------

## A first-person weapon on the game's own viewmodel rig (WeaponView: sway,
## kick, muzzle flash and the weapon's real reload) in the operator's arms
## (`gloves`), not yet placed.
func _dressed_view(st: CineStage, weapon_id: StringName, finish: StringName, gloves: StringName, sight: StringName = &"") -> WeaponView:
	var w := GameData.weapon(weapon_id)
	var view := WeaponView.new()
	st.actors.add_child(view)
	view.show_weapon(w)
	var loadout := Cosmetics.weapon_loadout(weapon_id)
	loadout["finish"] = Cosmetics.item(finish) if finish != &"" else null
	loadout["arms"] = Cosmetics.item(gloves)
	if sight != &"":
		loadout["sight"] = Cosmetics.item(sight)
	WeaponCosmetics.apply(view.model, w, loadout)
	view.refit_sight()
	st.at(0.0, func(): st.camera.near = 0.02)
	return view


## The first-person weapon pinned to the lens. `lean` moves it in the lens's
## space (a close-up brings it in toward the middle of the frame).
func _viewmodel(st: CineStage, weapon_id: StringName, finish: StringName, gloves: StringName, sight: StringName = &"", lean := Vector3.ZERO) -> WeaponView:
	var view := _dressed_view(st, weapon_id, finish, gloves, sight)
	st.after_camera(func(_t: float):
		view.global_transform = st.camera.global_transform.translated_local(lean).scaled_local(Vector3.ONE * WeaponView.VIEW_SCALE))
	return view


func _fire_view(st: CineStage, view: WeaponView, weapon_id: StringName, to: Vector3, tracer: StringName = &"", sound := true) -> void:
	view.on_fired(GameData.weapon(weapon_id))
	st.shoot(weapon_id, view.muzzle_position(), to, 1.0, sound, tracer)


## The weapon's real reload at `when`, `duration` long, cut in `skip` seconds
## after it starts (its sound plays from the top).
func _reload(st: CineStage, view: WeaponView, weapon_id: StringName, when: float, duration: float, skip := 0.0) -> void:
	st.at(when, func():
		var w := GameData.weapon(weapon_id)
		view.play_reload(w, duration)
		view.seek_reload(skip)
		Sfx.play(w.reload_sound, -1.0))


## A first-person camera at `eye` turning from `look_from` to `look_to` over the shot.
func _eye_track(st: CineStage, eye: Vector3, look_from: Vector3, look_to: Vector3, drift := Vector3.ZERO, ease_curve := -1.5) -> void:
	st.track(func(k: float) -> Transform3D:
		var e := ease(k, ease_curve)
		var from := eye + drift * e
		return Transform3D(Basis.looking_at(look_from.lerp(look_to, e) - from), from))


## A light pinned near the lens (the glow of a hologram or a muzzle on the hands).
func _lens_light(st: CineStage, color: Color, offset: Vector3, energy: Callable, radius := 2.5) -> OmniLight3D:
	var l := st.light(Vector3.ZERO, color, 0.0, radius)
	st.after_camera(func(t: float):
		l.global_position = st.camera.global_transform * offset
		l.light_energy = energy.call(t))
	return l


## Walkers of `kinds` in a loose pack round `centre`, all walking (or running)
## toward `toward` (the lens).
func _pack(st: CineStage, kinds: Array, centre: Vector3, toward: Vector3, spread := 1.6, pace := 0.9, run := false) -> Array[Zombie]:
	var out: Array[Zombie] = []
	for i in kinds.size():
		var p := centre + Vector3((i - (kinds.size() - 1) * 0.5) * spread, 0, (i % 2) * spread * 0.7)
		out.append(st.walker(kinds[i], p, _yaw_to(p, toward), pace, run))
	return out


static func _yaw_to(from: Vector3, to: Vector3) -> float:
	return rad_to_deg(atan2(to.x - from.x, to.z - from.z))


## A camera move that lands hard: fast out of the cut, settling for the rest
## of the shot (`k` 0-1 to 0-1).
static func _crash(k: float) -> float:
	return 1.0 - pow(1.0 - k, 4.0)


func _world_of(level_id: String) -> WorldData:
	var l := GameData.level(StringName(level_id))
	return l.world if l else null


func _enemy_name(id: StringName) -> String:
	var e := GameData.enemy(id)
	return e.display_name if e else String(id)


## An alpha's epithet ("CHAMPION OF THE LISTS"), from its boss behaviour.
func _epithet(id: StringName) -> String:
	var e := GameData.enemy(id)
	if e:
		for b in e.behaviours:
			if b is AlphaBossBehaviour:
				return (b as AlphaBossBehaviour).title
	return ""


func _weapon_name(id: StringName) -> String:
	var w := GameData.weapon(id)
	return w.display_name if w else String(id)


func _alpha_count() -> int:
	return GameData.enemies().filter(func(e): return String(e.id).begins_with("alpha_")).size()


## Zombie kinds other than the alphas (counted on their own).
func _zombie_count() -> int:
	return GameData.enemies().size() - _alpha_count()


func _operator_count() -> int:
	return GameData.cosmetics().filter(func(c): return c.slot == &"avatar").size()


func _rarity_color(id: StringName) -> Color:
	var item := Cosmetics.item(id)
	return CosmeticItem.rarity_color(item.rarity) if item else UiKit.AMBER


func _cosmetic_name(id: StringName) -> String:
	var item := Cosmetics.item(id)
	return item.display_name if item else String(id)


func _turntable(st: CineStage, model: Node3D, height := 1.25, span := 1.3) -> Node3D:
	var pivot := Node3D.new()
	st.actors.add_child(pivot)
	pivot.position = Vector3(0, height, 0)
	pivot.add_child(model)
	var box := WeaponCosmetics.visible_bounds(model)
	model.position = -box.get_center()
	pivot.scale = Vector3.ONE * span / maxf(0.01, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	return pivot


## The squad of the finale: three operators in a line at the pier rail, each
## with a gun in a Legendary finish, facing the horde (along -x).
func _squad(st: CineStage, guns: Array[Node3D]) -> Array[Node3D]:
	var squad: Array[Node3D] = []
	for i in FINALE_SQUAD.size():
		var op := st.operator(FINALE_SQUAD[i], Vector3(-2 + i * 1.3, 0, 15 + absf(i - 1) * 0.7), -100.0, "AimIdle")
		var gun := st.weapon(FINALE_GUNS[i], FINALE_FINISHES[i])
		Operators.hold_weapon(op, gun)
		squad.append(op)
		guns.append(gun)
	return squad


## A horde of every world charging the squad's line from the west of the pier.
func _horde_of_every_world(st: CineStage, front_x := -10.0) -> Array[Zombie]:
	var horde: Array[Zombie] = []
	var kinds := [&"tourist_shambler", &"lifeguard_runner", &"boardwalk_bruiser", &"neon_punk", &"fright_ghost", &"gulch_cowpoke",
		&"cove_deckhand", &"faire_knight", &"toy_windup_soldier", &"candy_gummy", &"mall_walker", &"lava_fire_dancer",
		&"sky_diver", &"jungle_explorer", &"frost_yeti", &"deep_diver", &"tourist_shambler", &"lifeguard_runner"]
	for i in kinds.size():
		var p := Vector3(front_x - (i % 5) * 1.8 - (i / 5) * 1.2, 0, 11.5 + (i / 5) * 2.4 + (i % 2) * 0.9)
		horde.append(st.walker(kinds[i], p, 90.0 + randf_range(-8.0, 8.0), 0.9, i % 2 == 0))
	return horde


## The pier gate's pillar crosses the finale's crane: hide the gate (the
## last pier shots).
func _hide_gate(st: CineStage) -> void:
	st.at(0.0, func():
		var gate := st.set_root.find_child("PierEntrance", true, false) as Node3D
		if gate:
			gate.visible = false)


# --- cold open (0-10) ------------------------------------------------------------

## Out of black: a slow push on a tourist's face at dusk; its eyes catch cyan
## light and it starts to roar.
func _cold_open(st: CineStage) -> void:
	st.at(0.0, st.overlay.bars.bind(1.0, 0.0))
	st.at(0.0, st.overlay.fade.bind(1.0, 0.0))
	st.at(0.0, st.overlay.fade.bind(0.0, 1.2))
	st.at(0.0, st.overlay.grade.bind(&"dusk"))
	st.lighting(0.3, 0.9, 1.2, 0.25)
	var z := st.zombie(&"tourist_shambler", Vector3(-5, 0, -3), 45.0, "Idle", 0.5)
	var face := st.head(z) + Vector3(0, -0.05, 0)
	var fwd := Vector3(sin(deg_to_rad(45.0)), 0, cos(deg_to_rad(45.0)))
	var side := fwd.cross(Vector3.UP)
	st.fov(30.0, 21.0)
	st.dolly(face + fwd * 2.3 + side * 1.0 + Vector3(0, -0.22, 0), face, face + fwd * 1.45 + side * 0.65 + Vector3(0, -0.08, 0), face + Vector3(0, 0.03, 0), 1.0)
	st.light(face - fwd * 0.9 + Vector3(0, 0.5, 0), UiKit.PINK, 3.0, 3.5)
	st.flare_at(func(): return st.head(z) + fwd * 0.18, Wallet.COLOR_GLOW, 0.35, 1.3, 0.5)
	st.at(2.1, st.play.bind(z, "Roar", 0.5, 0.0, 0.3))
	st.focus_on(func(): return st.head(z), 0.16, 0.009)


## Near darkness, first person: the Rail Lancer's capacitor swap prints its
## hologram and the glow lights the hands; the rails slam home and the charge
## rings snap on at the end of the shot (5.0).
func _dark_reload(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"dark"))
	st.lighting(0.22, 0.6, 1.6, 0.05)
	var view := _viewmodel(st, DARK_RELOAD, &"fin_thunderhead", GLOVES[1], &"", CLOSE_UP)
	var eye := Vector3(-3.0, 1.6, 6.0)
	st.fov(42.0, 36.0)
	_eye_track(st, eye, eye + Vector3(-1, -0.2, -1), eye + Vector3(-1, -0.1, -0.75), Vector3(-0.1, 0.03, -0.15), 1.0)
	_reload(st, view, DARK_RELOAD, 0.0, 2.2)
	_lens_light(st, UiKit.CYAN, Vector3(-0.02, 0.02, -0.12), func(t: float) -> float:
		return 0.6 + 2.6 * smoothstep(0.36, 0.8, t) * (1.0 - smoothstep(1.65, 1.9, t)) + 4.0 * exp(-pow((t - 1.96) * 8.0, 2.0)), 1.4)
	st.shake(1.95, 0.03, 0.25)


## Four flashes in four worlds: a zombie lunges at the lens out of the dark,
## lit by the muzzle; the fourth takes the shot to the head.
func _lunge(st: CineStage, index: int) -> void:
	var spec: Array = LUNGES[index]
	var at: Vector3 = spec[2]
	var yaw: float = spec[3]
	var fwd := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	st.at(0.0, st.overlay.grade.bind(&"dark"))
	st.lighting(0.15, 0.6, 1.4, 0.1)
	var z := st.zombie(spec[1], at, yaw, "Run", 1.1)
	st.move(z, fwd * 3.2)
	var cam := at + fwd * 3.6 + fwd.cross(Vector3.UP) * 0.5 + Vector3.UP * 1.0
	st.fov(48.0, 42.0)
	st.track(func(k: float) -> Transform3D:
		var from := cam + fwd * 0.3 * k
		return Transform3D(Basis.looking_at(st.head(z) + Vector3(0, -0.25, 0) - from), from))
	var muzzle := func() -> Vector3: return st.camera.global_transform * Vector3(0.35, -0.35, -1.2)
	var flash := st.light(Vector3.ZERO, Color(1.0, 0.8, 0.55), 0.0, 9.0)
	st.after_camera(func(t: float):
		flash.global_position = muzzle.call()
		flash.light_energy = 6.0 * maxf(exp(-pow((t - 0.05) * 20.0, 2.0)), exp(-pow((t - 0.27) * 20.0, 2.0))))
	# The tracer and the sound only: the flash is the light on the zombie.
	var gun := GameData.weapon(&"comet_cannon")
	for when in [0.04, 0.26]:
		st.at(when, func():
			WeaponFx.shot(st.actors, muzzle.call(), st.chest(z) + Vector3(0, 0.2, 0), gun, 1.0)
			Sfx.play(gun.fire_sound, -6.0))
	if index == LUNGES.size() - 1:
		st.at(0.26, st.kill.bind(z, &"comet_cannon", true, -fwd, 4.0))
	else:
		st.at(0.26, st.hit.bind(z, &"comet_cannon", 1.0, st.chest(z), -fwd))
	st.shake(0.05, 0.05, 0.35)


## The breath: a Bruiser in silhouette lifts its head and roars; the frame
## sinks to black by 7.5 and holds there for the silence before the slam.
func _roar(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"dark"))
	st.at(0.0, st.overlay.fade.bind(0.0, 0.0))
	st.at(0.12, st.overlay.fade.bind(1.0, 0.38))
	st.lighting(0.1, 0.6, 1.0, 0.05)
	var z := st.zombie(&"boardwalk_bruiser", Vector3(-7, 0, 2), 50.0, "Idle", 0.6)
	st.at(0.0, st.play.bind(z, "Roar", 1.0, 0.25, 0.0))
	var face := st.head(z)
	var fwd := Vector3(sin(deg_to_rad(50.0)), 0, cos(deg_to_rad(50.0)))
	st.fov(32.0, 26.0)
	st.dolly(face + fwd * 3.2 + Vector3(0, -0.85, 0), face, face + fwd * 2.5 + Vector3(0, -0.65, 0), face + Vector3(0, 0.1, 0), 1.0)
	st.light(face - fwd * 1.2 + Vector3(0, 0.9, 0), UiKit.CYAN, 2.5, 3.5)
	st.flare_at(func(): return st.head(z) + fwd * 0.2, UiKit.RED, 0.4, 0.0, 0.1)
	st.shake(0.0, 0.05, 0.5)


## 8.0, the slam: the logo hits over the pier at dusk, the lights come up in
## steps and the camera cranes toward the Ferris wheel over the horde.
func _title(st: CineStage) -> void:
	st.at(0.0, st.overlay.fade.bind(0.0, 0.0))
	st.at(0.0, st.overlay.grade.bind(&"dusk"))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.6, 1.0))
	st.at(0.0, func(): st.overlay.logo(Vector2(0.5, 0.4), 160))
	st.lighting(0.5, 0.95, 0.4, 0.5)
	st.every_frame(func(t: float):
		var env := st.environment()
		if env:
			env.glow_intensity = 0.4 + 0.9 * clampf(floorf(t / 0.125) / 8.0, 0.0, 1.0))
	st.shake(0.0, 0.11, 0.6)
	st.fov(50.0, 44.0)
	st.dolly(Vector3(-9, 0.9, 4.0), Vector3(-20, 2.2, -9), Vector3(-6, 5.5, 7.5), Vector3(-26, 6.0, -22), -1.4)
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.4)
	var kinds := [&"tourist_shambler", &"lifeguard_runner", &"tourist_shambler", &"boardwalk_bruiser", &"tourist_shambler", &"lifeguard_runner", &"neon_punk"]
	for i in kinds.size():
		var p := Vector3(-12.0 - (i % 3) * 2.2 - i * 0.7, 0, -1.0 - ((i + 1) % 3) * 1.9 - i * 0.7)
		st.walker(kinds[i], p, 40.0 + randf_range(-10.0, 10.0), 0.7)


# --- fifteen worlds (10-18) -------------------------------------------------------

## One world a beat: a fast push on its landmark, its own zombies walking at
## the lens, the world's number and name low left.
func _world(st: CineStage, index: int) -> void:
	var spec: Array = WORLDS[index]
	var level := GameData.level(StringName(spec[0]))
	var look := &"night" if index in [1, 2, 4, 5, 10, 14] else (&"golden" if index in [3, 6, 8, 12] else &"day")
	st.at(0.0, st.overlay.grade.bind(look))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.12, 0.18))
	st.lighting(1.0, 1.0, 1.2)
	st.fov(54.0, 47.0)
	st.dolly(spec[1], spec[2], spec[3], spec[4], 1.0)
	_pack(st, spec[5], _pack_spot(spec), spec[3], 1.8, 0.95)
	var w := _world_of(spec[0])
	if w:
		st.at(0.0, st.overlay.tag.bind("World %02d" % (index + 1), w.display_name, w.accent_color.lerp(Color.WHITE, 0.35)))
	elif level:
		st.at(0.0, st.overlay.tag.bind("World %02d" % (index + 1), level.display_name))
	if spec[0] == "lava_lagoon":
		_erupt(st)


## Where a world's zombies stand: their own spot, or on the floor a few metres
## in front of the lens's last position.
func _pack_spot(spec: Array) -> Vector3:
	var pack: Vector3 = spec[6]
	if pack != Vector3.ZERO:
		return pack
	var ahead: Vector3 = spec[4] - spec[3]
	pack = spec[3] + Vector3(ahead.x, 0, ahead.z).normalized() * 6.5
	pack.y = 0.0
	return pack


## 17.5, the stop-hit: the toy shop's push carries on, the world slows to a
## crawl and the count of worlds slams in.
func _worlds_card(st: CineStage) -> void:
	var spec: Array = WORLDS[WORLDS.size() - 1]
	st.at(0.0, st.overlay.grade.bind(&"night"))
	st.at(0.0, st.overlay.flash.bind(UiKit.AMBER, 0.2, 0.5))
	st.lighting(1.0, 1.0, 1.2)
	var to: Vector3 = spec[3]
	var look: Vector3 = spec[4]
	var ahead := (to - (spec[1] as Vector3)) * 0.35
	st.fov(47.0, 44.0)
	st.dolly(to, look, to + ahead, look, 1.0)
	_pack(st, spec[5], _pack_spot(spec) + Vector3(0, 0, -0.8), to, 1.8, 0.95)
	st.slowmo(0.0, 1.0, 0.15, 0.0, 0.01)
	st.shake(0.0, 0.05, 0.3)
	st.at(0.0, st.overlay.card.bind("%d worlds" % GameData.worlds().size(), "Story mode", Vector2(0.5, 0.45), 0.25, UiKit.AMBER, 170))


## Lava Lagoon's twist on cue: Mount Kahuna erupts and an ember bomb drops.
func _erupt(st: CineStage) -> void:
	st.at(0.0, func():
		var eruption := st.set_root.find_child("Eruption", false, false) as LavaEruption
		if eruption == null:
			return
		eruption.telegraph = 0.2
		eruption.fall_time = 0.2
		eruption.erupt_now()
		eruption.strike_at(Vector3(-3.5, 0, 6.0)))


# --- alphas (18-24) ----------------------------------------------------------------

## An alpha on its hit: a crash push up from a low lens as it roars in slow
## motion, the frame jolts, its name and epithet slam in; the world speeds up
## again into the next hit.
func _alpha(st: CineStage, index: int) -> void:
	var spec: Array = ALPHAS[index]
	var at: Vector3 = spec[2]
	var yaw: float = spec[3]
	st.at(0.0, st.overlay.grade.bind(&"night" if index != 1 else &"golden"))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.3, 0.6))
	st.lighting(0.8, 1.0, 1.3)
	var z := st.zombie(spec[1], at, yaw, "Idle", 1.0)
	st.at(0.0, st.play.bind(z, "Roar", 1.0, 0.15, 0.0))
	var fwd := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	var side := fwd.cross(Vector3.UP) * (1.0 if index % 2 == 0 else -1.0)
	var tall := 1.75 * z.data.body_scale
	st.fov(54.0, 36.0)
	st.track(func(k: float) -> Transform3D:
		var c := _crash(k)
		var from := at + fwd * lerpf(tall * 2.6, tall * 1.8, c) + side * lerpf(1.6, 0.5, c) + Vector3.UP * lerpf(0.2, 0.45, c)
		return Transform3D(Basis.looking_at(at + Vector3.UP * tall * lerpf(0.5, 0.66, c) - from), from))
	st.slowmo(0.08, 0.85, 0.35, 0.05, 0.3)
	st.light(at + fwd * 2.5 + side * -2.0 + Vector3.UP * 3.0, Color("ffd9a8"), 3.0, 10.0)
	st.light(at - fwd * 1.5 + Vector3.UP * 2.5, UiKit.PINK if index % 2 == 0 else UiKit.CYAN, 5.0, 7.0)
	st.flare_at(func(): return st.head(z) + fwd * 0.3, UiKit.RED, 0.35, 0.0, 0.05)
	st.shake(0.0, 0.14, 0.55)
	var w := _world_of(spec[0])
	st.at(0.0, st.overlay.card.bind(_enemy_name(spec[1]), "Alpha  ·  " + (w.display_name if w else ""), Vector2(0.5, 0.8), 0.7,
		UiKit.RED, 96, _epithet(spec[1])))


## 23.0, the cast: one of every world marching at a low lens in slow motion,
## two alphas towering behind them, and the counts.
func _cast(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"dusk"))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.2, 0.4))
	st.lighting(0.6, 0.95, 1.2, 0.6)
	var cam := Vector3(-3.0, 0.7, 15.0)
	for i in CAST.size():
		var p := Vector3(-8.5 - (i % 2) * 1.5 - (i / 5) * 0.4, 0, 15.2 + (i - (CAST.size() - 1) * 0.5) * 1.05)
		st.walker(CAST[i], p, _yaw_to(p, cam + Vector3(-1.0, 0, (i - 7) * 0.6)), 0.9)
	for i in CAST_ALPHAS.size():
		var p := Vector3(-13.5, 0, 12.5 + i * 5.5)
		st.walker(CAST_ALPHAS[i], p, _yaw_to(p, cam), 0.8)
	st.fov(46.0, 42.0)
	st.dolly(cam, Vector3(-12, 1.8, 15.2), cam + Vector3(0.6, 0.1, 0.0), Vector3(-12, 2.0, 15.2), 1.0)
	st.slowmo(0.0, 1.0, 0.45, 0.0, 0.01)
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.5)
	st.at(0.05, st.overlay.card.bind("%d zombies  ·  %d alphas" % [_zombie_count(), _alpha_count()], "", Vector2(0.5, 0.2),
		0.75, UiKit.PINK, 104))


## Lock and load: in the dark, first person, the Scatter Blaster snaps shut
## and racks twice; then black for the silence.
func _lock_load(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"dark"))
	st.lighting(0.15, 0.6, 1.4, 0.05)
	var view := _viewmodel(st, LOCK_LOAD, &"fin_ghost_train", GLOVES[0], &"", Vector3(-0.03, 0.02, 0.0))
	var eye := Vector3(-3.0, 1.6, 9.0)
	st.fov(40.0, 34.0)
	_eye_track(st, eye, eye + Vector3(-1, -0.15, -0.6), eye + Vector3(-1, -0.1, -0.45), Vector3(0, 0, -0.1), 1.0)
	var d := 2.4
	_reload(st, view, LOCK_LOAD, 0.0, d, d * 0.52)
	_lens_light(st, UiKit.AMBER, Vector3(0.12, 0.08, -0.25), func(t: float) -> float:
		return 0.5 + 2.4 * exp(-pow((t - 0.43) * 9.0, 2.0)) + 1.6 * exp(-pow((t - 0.85) * 10.0, 2.0)) + 1.6 * exp(-pow((t - 1.13) * 10.0, 2.0)), 1.6)
	_lens_light(st, UiKit.PINK, Vector3(-0.3, 0.1, -0.1), func(_t: float) -> float: return 0.9, 1.4)
	st.shake(0.43, 0.03, 0.2)
	st.at(0.0, st.overlay.card.bind("Lock and load", "", Vector2(0.5, 0.3), 1.2, UiKit.CREAM, 104))
	st.at(1.32, st.overlay.fade.bind(1.0, 0.16))


## Black (a beat of silence before the drop).
func _black(st: CineStage) -> void:
	st.at(0.0, st.overlay.fade.bind(1.0, 0.0))
	st.dolly(Vector3(0, 2, 10), Vector3.ZERO, Vector3(0, 2, 9), Vector3.ZERO)


# --- the drop (26-37) ---------------------------------------------------------------

## 26.0, the drop. First person, the Ticket Ripper: a spray down the lane, three
## drop, the streak prints the golden WINNER round on 27.5 and it pierces the
## last two in slow motion and pops its ticket burst.
func _ripper(st: CineStage) -> void:
	st.at(0.0, st.overlay.fade.bind(0.0, 0.0))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.4, 0.9))
	st.at(0.0, st.overlay.grade.bind(&"golden"))
	var eye := Vector3(2, 1.6, -13)
	var targets: Array[Zombie] = []
	var kinds := [&"tourist_shambler", &"lifeguard_runner", &"boardwalk_bruiser", &"tourist_shambler", &"lifeguard_runner"]
	for i in kinds.size():
		var a := deg_to_rad(-28.0 + i * 13.0)
		var p := eye + Vector3(-cos(a), 0, sin(a)) * (8.0 + (i % 2) * 1.5)
		p.y = 0.0
		targets.append(st.walker(kinds[i], p, _yaw_to(p, eye), 0.9))
	var view := _viewmodel(st, &"ticket_ripper", &"fin_jackpot", GLOVES[0])
	st.track(func(_k: float) -> Transform3D:
		# A sweep along the pack onto the winner's pair, with a steady drift so it never stops.
		var u := clampf(st.t / 1.5, 0.0, 1.0)
		var a := deg_to_rad(lerpf(-34.0, 16.0, 0.85 * ease(u, -1.4) + 0.15 * u) + 3.0 * maxf(0.0, st.t - 1.5))
		var look := eye + Vector3(-cos(a), -0.06, sin(a))
		return Transform3D(Basis.looking_at(look - eye), eye))
	st.after_camera(func(t: float): st.lens_fov(lerpf(64.0, 50.0, smoothstep(1.45, 2.4, t))))
	# Fifteen a second along the pack; three drop, then the winner.
	for n in 19:
		var tgt := targets[mini(n / 6, 2)]
		st.at(0.05 + n * 0.067, func():
			if is_instance_valid(tgt) and not tgt.is_dead():
				_fire_view(st, view, &"ticket_ripper", st.chest(tgt) + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.3), 0), &"", n % 2 == 0))
	for i in 3:
		st.at(0.4 + i * 0.4, st.kill.bind(targets[i], &"ticket_ripper", i == 1, Vector3(-1, 0, 0), 4.0))
	st.at(1.2, st.overlay.tag.bind("Streak  ·  15 in a row", "Ticket Ripper", UiKit.AMBER))
	st.at(1.5, _winner.bind(st, view, targets[3], targets[4]))
	st.slowmo(1.5, 2.75, 0.18, 0.04, 0.4)


## The golden WINNER round: a fat gold streak through the last two, and the burst.
func _winner(st: CineStage, view: WeaponView, a: Zombie, b: Zombie) -> void:
	var gold := GameData.weapon(&"ticket_ripper").duplicate() as WeaponData
	gold.tracer_color = TicketRipperMode.WINNER_GOLD
	gold.tracer_width *= 3.0
	view.on_fired(gold)
	var from := view.muzzle_position()
	var hit := st.chest(a)
	WeaponFx.shot(st.actors, from, hit + (hit - from).normalized() * 9.0, gold, 1.6)
	WeaponFx.flash(st.actors, from, TicketRipperMode.WINNER_GOLD, 0.6, 0.12)
	Sfx.play(TicketRipperMode.WINNER_SOUND, -2.0)
	TicketRipperBurst.show_at(st.actors, hit)
	st.kill(a, &"ticket_ripper", false, (hit - from).normalized(), 6.0, &"kfx_tickets")
	st.kill(b, &"ticket_ripper", false, (hit - from).normalized(), 6.0)
	st.overlay.flash(TicketRipperMode.WINNER_GOLD, 0.35, 0.4)
	st.shake(st.t, 0.06, 0.35)


## A reload showcase: the weapon's real reload, close, in first person, each
## from its own angle: the rig leans in toward the middle of the frame and
## turns about the gun's middle (so the arms still run out of frame toward
## the lens), from one angle to the next over the shot, with a warm key and a
## coloured rim pinned to the gun. The first one carries the RELOADS card.
func _showcase(st: CineStage, index: int) -> void:
	var spec: Array = RELOADS[index]
	var weapon_id: StringName = spec[0]
	var w := GameData.weapon(weapon_id)
	var rim: Color = [Color(1.0, 0.45, 0.25), UiKit.CYAN, UiKit.PINK, Color(0.75, 1.0, 0.35)][index % 4]
	st.at(0.0, st.overlay.grade.bind([&"dusk", &"golden", &"night", &"day"][index % 4]))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.12, 0.25))
	st.lighting(0.8, 1.0, 1.4)
	var view := _dressed_view(st, weapon_id, spec[1], GLOVES[index % 2])
	var eye: Vector3 = spec[3]
	var look: Vector3 = spec[4]
	_eye_track(st, eye, look, look + Vector3(0.6, 0.2, 0), (look - eye).normalized() * 0.15, 1.0)
	# The gun's hip position in the lens's space (metres).
	var pivot := w.view_position * WeaponView.VIEW_SCALE
	st.after_camera(func(t: float):
		var cam := st.camera.global_transform
		var turn := (spec[5] as Vector3).lerp(spec[6], ease(clampf(t / st.length, 0.0, 1.0), -1.6)) * (PI / 180.0)
		var spin := Transform3D(Basis.from_euler(turn), pivot + CLOSE_UP) * Transform3D(Basis.IDENTITY, -pivot)
		view.global_transform = (cam * spin).scaled_local(Vector3.ONE * WeaponView.VIEW_SCALE))
	st.fov(36.0, 32.0)
	var part: Vector2 = spec[8]
	var d: float = spec[7]
	_reload(st, view, weapon_id, 0.0, d, d * part.x)
	_lens_light(st, Color("ffe6c4"), Vector3(0.1, 0.15, -0.05), func(_t: float) -> float: return 1.4, 1.2)
	_lens_light(st, rim, Vector3(-0.15, 0.05, -0.45), func(_t: float) -> float: return 2.4, 1.0)
	if index == 0:
		st.at(0.0, st.overlay.card.bind("Reloads", "Every gun its own", Vector2(0.5, 0.22), 0.65, UiKit.CYAN, 120))
	st.at(0.0, st.overlay.tag.bind("Reload", w.display_name if w else String(weapon_id), rim.lerp(Color.WHITE, 0.2)))


## First person down the Boot Camp lane: a sprint, a vault over the hurdle, a
## sprint and a slide under the DUCK! sign, on one camera curve.
func _moves(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"day"))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.12, 0.2))
	var view := _viewmodel(st, &"ion_carbine", &"fin_marquee", GLOVES[0])
	var x := 0.9
	st.spline([
		[0.0, Vector3(x, 1.6, -41.6), Vector3(x, 1.5, -53)],
		[0.3, Vector3(x, 1.7, -43.9), Vector3(x, 1.3, -56)],
		[0.48, Vector3(x, 2.15, -45.3), Vector3(x, 1.5, -57)],
		[0.68, Vector3(x, 1.6, -46.9), Vector3(x, 1.5, -58)],
		[0.98, Vector3(x, 1.5, -49.7), Vector3(x, 1.3, -60)],
		[1.22, Vector3(x, 0.9, -51.6), Vector3(x, 0.95, -62)],
		[2.0, Vector3(x, 0.82, -55.6), Vector3(x, 1.0, -64)],
	])
	st.fov(68.0, 76.0)
	st.every_frame(func(t: float):
		view.staged_mantle = smoothstep(0.25, 0.38, t) * (1.0 - smoothstep(0.56, 0.72, t))
		view.staged_slide = smoothstep(0.96, 1.12, t)
		view.staged_sprint = clampf(1.0 - view.staged_mantle - view.staged_slide, 0.0, 1.0)
		view.staged_gait = Vector2(t * TAU * 2.2, view.staged_sprint))
	st.at(0.05, st.overlay.tag.bind("Move", "Sprint  ·  vault  ·  slide", UiKit.CYAN))
	st.at(0.96, func(): Sfx.play(&"ui_whoosh", -6.0, 0.7))


## Aim down sights in half time: the cannon comes up, its optic's reticle
## lights on a far head, and on 36.0 the head pops at a fifth of the speed.
func _ads(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"day"))
	var eye := Vector3(3.0, 1.6, -12.0)
	var z := st.walker(&"lifeguard_runner", Vector3(-13.0, 0, -15.5), 75.0, 0.7)
	st.walker(&"tourist_shambler", Vector3(-11.0, 0, -9.5), 100.0, 0.7)
	var view := _viewmodel(st, &"comet_cannon", &"fin_solar_flare", GLOVES[1], ADS_SIGHT)
	st.after_camera(func(t: float):
		var k := smoothstep(0.1, 0.65, t)
		view.staged_aim = k
		st.lens_fov(lerpf(64.0, 64.0 / 1.6, k) - 3.0 * smoothstep(0.9, 1.6, t)))
	st.track(func(_k: float) -> Transform3D:
		var head := st.head(z) if is_instance_valid(z) else Vector3(-12.0, 1.6, -15.0)
		var look := head.lerp(eye + (head - eye).normalized() * 10.0 + Vector3(0, -0.6, 2.0), 1.0 - smoothstep(0.1, 0.7, st.t))
		return Transform3D(Basis.looking_at(look - eye), eye))
	st.at(0.1, st.overlay.tag.bind("Aim down sights", Cosmetics.item(ADS_SIGHT).display_name if Cosmetics.item(ADS_SIGHT) else "Sights", UiKit.CYAN))
	st.at(1.0, func():
		_fire_view(st, view, &"comet_cannon", st.head(z), HERO_TRACER)
		st.kill(z, &"comet_cannon", true, Vector3(-1, 0, -0.2), 4.0, &"kfx_starburst")
		Sfx.play(&"headshot_ping", -6.0)
		st.overlay.stamp("Headshot", "", Vector2(0.5, 0.25), 0.7, UiKit.CYAN, 96))
	st.slowmo(0.0, 1.95, 0.6, 0.0, 0.3)
	st.slowmo(0.97, 1.75, 0.15, 0.03, 0.45)
	st.shake(1.0, 0.03, 0.3)


# --- mayhem (37-40) ---------------------------------------------------------------

## The Cryo Beam sweeps three; they freeze solid and shatter in slow motion.
func _cryo(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"day"))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.15, 0.3))
	var cryo := GameData.weapon(&"cryo_beam")
	var zs: Array[Zombie] = []
	for i in 3:
		zs.append(st.zombie(&"tourist_shambler" if i != 1 else &"boardwalk_bruiser", Vector3(-4.5 - i * 1.6, 0, 13.0 + 1.2 * i), 100.0, "Walk", 0.7))
	var muzzle := Vector3(3.5, 1.3, 16.5)
	var beam := BeamVisual.new()
	beam.color = cryo.tracer_color
	beam.width = 0.12
	st.actors.add_child(beam)
	st.fov(42.0, 35.0)
	st.dolly(Vector3(0.5, 1.4, 20.5), Vector3(-6, 1.2, 14), Vector3(-0.4, 1.25, 19.4), Vector3(-6.2, 1.1, 14), 1.0)
	st.every_frame(func(t: float):
		var k := clampi(int(t / 0.15), 0, 2)
		beam.aim(muzzle, st.chest(zs[k]) if is_instance_valid(zs[k]) else muzzle, t < 0.5))
	for i in 3:
		st.at(0.02 + i * 0.15, func(): StatusEffects.of(zs[i]).apply(cryo, 9.0))
	st.at(0.0, func(): Sfx.play(cryo.fire_sound, -6.0))
	st.slowmo(0.52, 1.0, 0.3, 0.03, 0.01)
	st.at(0.55, func():
		for i in 3:
			st.kill(zs[i], &"cryo_beam", false, Vector3(-1, 0, 0), 2.0))
	st.shake(0.55, 0.06, 0.3)
	st.at(0.0, st.overlay.tag.bind("Freeze  ·  shatter", _weapon_name(&"cryo_beam"), Color("9fe8ff")))


## A gumball arcs into a ring of five on the factory floor; the blast throws
## them apart in slow motion.
func _lobber(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"day"))
	var lob := GameData.weapon(&"bumper_lobber")
	var zs: Array[Zombie] = []
	var centre := Vector3(-2, 0, 6)
	for i in 5:
		var a := TAU * float(i) / 5.0
		zs.append(st.zombie(&"candy_gummy" if i % 2 else &"candy_taffy_puller", centre + Vector3(cos(a), 0, sin(a)) * 1.4, 90.0 + i * 30.0, "Walk", 0.8))
	st.fov(46.0, 39.0)
	st.dolly(Vector3(4.5, 2.2, 12.5), centre + Vector3(0, 0.8, 0), Vector3(3.7, 1.6, 11.2), centre + Vector3(0, 1.0, 0), 1.0)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	var m := StandardMaterial3D.new()
	m.albedo_color = lob.tracer_color
	m.emission_enabled = true
	m.emission = lob.tracer_color
	m.emission_energy_multiplier = 3.0
	sphere.material = m
	ball.mesh = sphere
	st.actors.add_child(ball)
	var start := Vector3(5, 1.6, 10)
	st.every_frame(func(t: float):
		var k := clampf(t / 0.35, 0.0, 1.0)
		ball.visible = k < 1.0
		ball.global_position = start.lerp(centre + Vector3(0, 0.3, 0), k) + Vector3.UP * sin(k * PI) * 2.2)
	st.at(0.0, func(): Sfx.play(lob.fire_sound, -5.0))
	st.slowmo(0.36, 1.0, 0.28, 0.02, 0.01)
	st.at(0.35, func():
		WeaponFx.explosion(st.actors, centre + Vector3(0, 0.4, 0), lob.tracer_color, 2.8)
		Sfx.play(lob.explosion_sound, -3.0)
		for z in zs:
			st.kill(z, &"bumper_lobber", false, (z.global_position - centre).normalized() + Vector3.UP * 0.3, 9.0))
	st.shake(0.35, 0.12, 0.45)
	st.flare_at(func(): return centre + Vector3(0, 0.6, 0), lob.tracer_color.lerp(Color.WHITE, 0.3), 0.8, 0.35, 0.02, 0.8, 0.2)
	st.at(0.0, st.overlay.tag.bind("Splash", _weapon_name(&"bumper_lobber"), UiKit.PINK))


## The Coin-Op at night on the rooftops: a burst, and a headshot pays FREE
## PLAY (ka-ching).
func _coin_op(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"night"))
	st.lighting(1.1, 1.0, 1.3)
	var eye := Vector3(3.0, 1.6, 12.5)
	var targets := _pack(st, [&"neon_punk", &"hover_courier"], Vector3(3.2, 0, 7.0), eye, 1.5, 0.9)
	var view := _viewmodel(st, &"coin_op", &"fin_multiball", GLOVES[1])
	st.fov(56.0, 50.0)
	_eye_track(st, eye, Vector3(2.0, 1.2, 6.5), Vector3(3.6, 1.1, 6.5), Vector3.ZERO, 1.0)
	for n in 5:
		var tgt := targets[mini(n / 3, 1)]
		st.at(0.02 + n * 0.06, func():
			if is_instance_valid(tgt) and not tgt.is_dead():
				_fire_view(st, view, &"coin_op", st.chest(tgt) + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.4), 0), &"", n % 2 == 0))
	st.at(0.12, st.kill.bind(targets[0], &"coin_op", false, Vector3(0, 0, -1), 3.0))
	st.at(0.26, func():
		var at := st.chest(targets[1])
		st.kill(targets[1], &"coin_op", true, Vector3(0, 0, -1), 3.0)
		CoinOpPopup.spawn(st.actors, at + Vector3.UP * 0.3, CoinOpMode.PAYOUT_ROUNDS, true)
		Sfx.play(CoinOpMode.PAYOUT_SOUND, -2.0)
		view.weapon_event(GameData.weapon(&"coin_op"), CoinOpMode.PAYOUT_EVENT))
	st.at(0.0, st.overlay.tag.bind("Free play: kills pay ammo", _weapon_name(&"coin_op"), UiKit.AMBER))


## A kill-effect parade in the mall: three zombies pop in confetti, a disco
## ball and a pinata as the camera trucks past.
func _parade(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"night"))
	st.lighting(1.1, 1.0, 1.3)
	var zs := _pack(st, [&"mall_walker", &"mall_flinger", &"mall_walker"], Vector3(0, 0, 4.0), Vector3(0, 0, 14), 2.2, 0.8)
	st.fov(44.0, 40.0)
	st.dolly(Vector3(-4.0, 1.5, 11.0), Vector3(-1.5, 1.2, 4.0), Vector3(-3.0, 1.6, 11.4), Vector3(0.5, 1.2, 4.0), 1.0)
	var muzzle := Vector3(-6.0, 1.4, 12.0)
	for i in 3:
		st.at(0.03 + i * 0.12, func():
			st.shoot(&"ion_carbine", muzzle, st.chest(zs[i]), 1.0, true, TRACERS[i])
			st.kill(zs[i], &"ion_carbine", i == 1, Vector3(1, 0, -0.3), 4.0, PARADE_FX[i]))
	st.at(0.0, st.overlay.tag.bind("Kill effects", "%s  ·  %s  ·  %s" % [_cosmetic_name(PARADE_FX[0]), _cosmetic_name(PARADE_FX[1]), _cosmetic_name(PARADE_FX[2])], UiKit.PINK))


# --- Endless, Last Ride (40-46) ------------------------------------------------

## 40.0, Ashfall City, wide: a crane down over the burning square as the horde
## floods in, and the card.
func _city_wide(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"ember"))
	st.at(0.0, st.overlay.flash.bind(Color(1.0, 0.6, 0.3), 0.35, 0.7))
	var kinds := [&"city_shambler", &"city_runner", &"city_shambler", &"city_bruiser", &"city_runner", &"city_shambler",
		&"riot_shield", &"city_runner", &"city_shambler", &"tunnel_crawler", &"city_runner", &"city_shambler",
		&"city_runner", &"city_shambler", &"riot_shield", &"city_runner"]
	var toward := Vector3(0, 0, 40)
	for i in kinds.size():
		var p := Vector3(((i % 4) - 1.5) * 2.2, 0, 14.0 - (i / 4) * 2.6 + (i % 2) * 0.8)
		st.walker(kinds[i], p, _yaw_to(p, toward), 1.0, i % 3 != 0)
	st.fov(50.0, 43.0)
	st.dolly(Vector3(-2.5, 10.0, 33.0), Vector3(0, 2.0, 4), Vector3(-1.5, 3.6, 24.5), Vector3(0, 1.5, 6), -1.2)
	st.shake(0.0, 0.08, 0.5)
	st.at(0.0, st.overlay.card.bind("Endless", "Ashfall City", Vector2(0.5, 0.3), 1.5, Color(1.0, 0.55, 0.25), 170))


## Street level in the city: the horde runs at the lens, the wave count climbs
## and the Wrecker looms behind them and roars.
func _city_street(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"ember"))
	var cam := Vector3(1.0, 1.0, 17.0)
	var kinds := [&"city_runner", &"city_shambler", &"tunnel_crawler", &"city_runner", &"firebug", &"city_shambler",
		&"city_runner", &"riot_shield", &"city_shambler"]
	for i in kinds.size():
		var p := Vector3(((i % 3) - 1.0) * 1.9 + randf_range(-0.3, 0.3), 0, 7.5 - (i / 3) * 2.2)
		st.walker(kinds[i], p, _yaw_to(p, cam), 1.0, true)
	var boss := st.walker(&"the_wrecker", Vector3(-6.0, 0, 5.5), _yaw_to(Vector3(-6.0, 0, 5.5), cam), 0.9)
	st.at(1.0, st.play.bind(boss, "Roar", 1.0, 0.0, 0.1))
	st.fov(46.0, 38.0)
	st.dolly(cam, Vector3(-1.0, 2.6, 4), cam + Vector3(-0.9, 0.2, 1.4), Vector3(-2.6, 3.2, 4), 1.0)
	st.at(0.0, func(): st.overlay.counter("WAVE", 5, 30, 1.7, Vector2(0.5, 0.22), Color(1.0, 0.6, 0.3), 110))
	st.slowmo(1.0, 2.0, 0.45, 0.1, 0.01)
	st.shake(1.0, 0.08, 0.7)
	st.at(1.0, func(): st.overlay.tag("Boss waves", _enemy_name(&"the_wrecker"), Color(1.0, 0.6, 0.3)))


## 44.0, Last Ride, the hardest difficulty: blood red, the stop-hit, and Prize
## Pier's alpha charges a low lens in slow motion with its pack.
func _last_ride(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"blood"))
	st.at(0.0, st.overlay.flash.bind(UiKit.RED, 0.35, 0.8))
	st.lighting(0.5, 0.9, 1.3, 0.5)
	var start := Vector3(-13.0, 0, 15.0)
	var cam := Vector3(-3.0, 0.5, 15.8)
	var z := st.walker(LAST_RIDE_ALPHA, start, _yaw_to(start, cam), 1.0, true)
	for i in 4:
		var p := start + Vector3(-2.5 - i * 1.2, 0, (i - 1.5) * 1.8)
		st.walker([&"boardwalk_bruiser", &"lifeguard_runner"][i % 2], p, _yaw_to(p, cam), 1.0, true)
	st.fov(36.0, 44.0)
	st.track(func(k: float) -> Transform3D:
		var at := z.global_position if is_instance_valid(z) else start
		var from := cam + Vector3(0.4 * k, 0.1 * k, 0.6 * k)
		return Transform3D(Basis.looking_at(at + Vector3.UP * 2.0 - from), from))
	st.slowmo(0.0, 2.0, 0.4, 0.0, 0.01)
	st.shake(0.0, 0.07, 2.0)
	st.light(cam + Vector3(-1, 2, 0), UiKit.RED, 3.0, 14.0)
	st.flare_at(func(): return st.head(z) + Vector3(0.3, 0, 0), UiKit.RED, 0.4, 0.3, 0.2)
	st.at(0.0, st.overlay.card.bind(Difficulty.LABELS[&"last_ride"], "The hardest difficulty", Vector2(0.5, 0.26), 1.4, UiKit.RED, 160))
	st.at(0.6, st.overlay.tag.bind("No healing  ·  no checkpoints  ·  double XP", "%s, %s" % [_enemy_name(LAST_RIDE_ALPHA), _epithet(LAST_RIDE_ALPHA).to_lower()], UiKit.RED))


# --- make it yours (46-50) ---------------------------------------------------------

## Four weapons on the turntable, one a beat, each in an animated Legendary
## (or Mythic) finish; the turn carries on across the swaps.
func _arsenal(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"studio"))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.25, 0.7))
	st.lighting(1.0, 1.0, 1.2)
	var pivots: Array[Node3D] = []
	for i in ARSENAL.size():
		var p := _turntable(st, st.weapon(ARSENAL[i], ARSENAL_FINISHES[i]), 1.3, 1.4)
		p.visible = i == 0
		pivots.append(p)
	st.fov(32.0, 27.0)
	st.dolly(Vector3(0.7, 1.5, 3.2), Vector3(0, 1.25, 0), Vector3(-0.5, 1.4, 2.8), Vector3(0, 1.25, 0), 1.0)
	var step := BEAT
	st.every_frame(func(t: float):
		var k := clampi(int(t / step), 0, pivots.size() - 1)
		for i in pivots.size():
			pivots[i].visible = i == k
		pivots[k].rotation.y = deg_to_rad(-70.0 + t * 55.0))
	var shown: Array[Control] = []
	for i in ARSENAL.size():
		st.at(i * step + 0.01, func():
			if i > 0:
				st.overlay.flash(Color.WHITE, 0.12, 0.3)
			for old in shown:
				if is_instance_valid(old):
					old.queue_free()
			shown.clear()
			shown.append(st.overlay.tag("%d weapons" % GameData.weapons().size(), _cosmetic_name(ARSENAL_FINISHES[i]), _rarity_color(ARSENAL_FINISHES[i]))))
	st.at(0.0, st.overlay.card.bind("Make it yours", "", Vector2(0.5, 0.2), 1.6, UiKit.AMBER, 120))
	st.focus_on(func(): return Vector3(0, 1.3, 0), 0.35, 0.006)


## The operators in two rows, Madame Fortuna in the centre in her aura; the
## camera trucks past as they pose.
func _operators(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"studio"))
	st.lighting(0.9, 1.0, 1.2)
	var rows := [[LINEUP_FRONT, 0.9, 0.0], [LINEUP_BACK, -0.9, 0.55]]
	for row in rows:
		var ids: Array[StringName] = row[0]
		for i in ids.size():
			var x: float = (i - (ids.size() - 1) * 0.5) * 1.1 + row[2]
			var op := st.operator(ids[i], Vector3(x, 0.0, row[1] - absf(x) * 0.12), -x * 3.0)
			Operators.play(op, "Pose")
	st.light(Vector3(-4, 2.5, -2.5), UiKit.PINK, 3.0, 9.0)
	st.light(Vector3(4, 2.5, -2.5), UiKit.CYAN, 3.0, 9.0)
	st.light(Vector3(0, 2.6, 2.6), Color("ffe2b0"), 2.0, 5.0)
	st.fov(36.0, 32.0)
	st.dolly(Vector3(-2.6, 1.5, 6.6), Vector3(-0.8, 1.2, 0), Vector3(1.6, 1.4, 6.0), Vector3(0.4, 1.25, 0), 1.0)
	st.at(0.0, st.overlay.card.bind("%d operators" % _operator_count(), "Suit up", Vector2(0.5, 0.8), 0.75, UiKit.PINK, 84))


## Prize Prints: the capsule machine turns, a Legendary capsule drops and a
## print of a finish lands on the plinth in a gold flash.
func _prints(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"studio"))
	st.lighting(0.8, 1.0, 1.4)
	var pivot := _turntable(st, st.weapon(PRINT_WEAPON, PRINT_FINISH), 1.3, 1.3)
	pivot.visible = false
	st.every_frame(func(t: float):
		pivot.visible = t >= 0.5
		pivot.rotation.y = deg_to_rad(-50.0 + t * 60.0)
		pivot.position.y = 1.3 + 0.5 * pow(1.0 - smoothstep(0.5, 0.66, t), 2.0))
	st.fov(36.0, 32.0)
	st.dolly(Vector3(1.4, 1.6, 3.9), Vector3(-0.75, 1.45, 0), Vector3(0.7, 1.5, 3.2), Vector3(-0.55, 1.45, 0), 1.0)
	var gold := CosmeticItem.rarity_color(CosmeticItem.Rarity.LEGENDARY)
	st.at(0.0, func():
		var machine := CapsuleMachine.new()
		machine.series_text = "SERIES 1"
		machine.custom_minimum_size = Vector2(440, 560)
		st.overlay.place(machine, Vector2(0.26, 0.5))
		machine.turn(gold, true))
	st.at(0.5, func():
		st.overlay.flash(gold, 0.3, 0.6)
		WeaponFx.burst(st.actors, Vector3(0, 1.3, 0), Vector3.UP, [gold, Color.WHITE], 30, 4.0, 0.6, 0.04, 160.0, Vector3(0, -4, 0)))
	st.at(0.0, st.overlay.card.bind("Prize Prints", "%d cosmetics" % GameData.cosmetics().size(), Vector2(0.66, 0.8), 0.75, gold, 84))


# --- the finale (50-58.5) ------------------------------------------------------------

## 50.0: three operators hold the line at dusk as a horde of every world
## charges them, in slow motion; the lens starts low in front of them (their
## faces, their guns) and trucks round to their side as the horde reaches
## the frame.
func _finale(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"golden"))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.6, 1.0))
	st.lighting(0.5, 0.95, 1.25, 0.5)
	var guns: Array[Node3D] = []
	var squad := _squad(st, guns)
	var horde := _horde_of_every_world(st, -8.5)
	_hide_gate(st)
	st.fov(38.0, 46.0)
	st.spline([
		[0.0, Vector3(-5.2, 0.9, 18.6), Vector3(-0.6, 1.45, 15.2)],
		[1.5, Vector3(-4.6, 1.15, 20.6), Vector3(-2.0, 1.4, 14.8)],
		[3.0, Vector3(-3.6, 1.4, 22.4), Vector3(-3.6, 1.35, 14.4)],
	])
	st.slowmo(0.0, 3.0, 0.4, 0.0, 0.01)
	st.light(Vector3(-4.5, 2.2, 18.0), Color("ffd2a0"), 2.5, 8.0)
	_squad_fire(st, squad, guns, horde, 0.12, 0.2)
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.5)


## 53.0, the title: a crane up and back over the line and the horde; the logo
## slams in, the feature chips, PLAY NOW; the picture fades to black on 56.0.
func _title_end(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"golden"))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.5, 0.95))
	st.lighting(0.45, 0.95, 1.25, 0.45)
	var guns: Array[Node3D] = []
	var squad := _squad(st, guns)
	var horde := _horde_of_every_world(st, -7.0)
	_hide_gate(st)
	st.fov(46.0, 52.0)
	st.spline([
		[0.0, Vector3(2.4, 2.2, 20.6), Vector3(-8.5, 2.0, 12.6)],
		[3.0, Vector3(4.2, 7.5, 27.0), Vector3(-11, 3.0, 9)],
	])
	st.slowmo(0.0, 3.0, 0.5, 0.0, 0.01)
	_squad_fire(st, squad, guns, horde, 0.1, 0.24)
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.5)
	st.at(0.0, func(): st.overlay.logo(Vector2(0.5, 0.33), 160))
	st.shake(0.0, 0.1, 0.5)
	var counts := PackedStringArray([
		"%d WORLDS" % GameData.worlds().size(), "%d WEAPONS" % GameData.weapons().size(),
		"%d ZOMBIES" % _zombie_count(), "%d ALPHAS" % _alpha_count(), "ENDLESS",
		"%d OPERATORS" % _operator_count(), "LAST RIDE"])
	st.at(0.3, st.overlay.chips.bind(counts, Vector2(0.5, 0.6), 0.07, [UiKit.CYAN, UiKit.PINK, UiKit.AMBER]))
	st.at(0.9, func(): st.overlay.marquee("PLAY NOW", 84, Vector2(0.5, 0.8)))
	st.at(2.3, st.overlay.fade.bind(1.0, 0.7))


## The squad opens fire into the front of the horde, a kill effect on each drop.
func _squad_fire(st: CineStage, squad: Array[Node3D], guns: Array[Node3D], horde: Array[Zombie], first: float, gap: float) -> void:
	for n in 12:
		var who := n % squad.size()
		var tgt := horde[n % horde.size()]
		st.at(first + n * gap, func():
			if not is_instance_valid(tgt) or tgt.is_dead():
				return
			Operators.play(squad[who], "Fire", "AimIdle", 0.05)
			st.shoot(FINALE_GUNS[who], st.muzzle(guns[who]), st.chest(tgt), 1.0, n % 2 == 0, HERO_TRACER if who == 1 else &"")
			if n % 2 == 1:
				st.kill(tgt, FINALE_GUNS[who], n % 4 == 1, Vector3(-1, 0, 0), 4.0, FINALE_FX[(n / 2) % FINALE_FX.size()]))


## The score rings out on black under the tagline, which fades away.
func _ring_out(st: CineStage) -> void:
	st.at(0.0, st.overlay.fade.bind(0.0, 0.0))
	st.at(0.0, st.overlay.backdrop.bind(1.0))
	st.at(0.0, func():
		var l := st.overlay.caption("An arcade zombie survival", 1.5, UiKit.CREAM)
		l.position.y = st.overlay.root.size.y * 0.5 - l.size.y * 0.5)
	st.dolly(Vector3(0, 2, 10), Vector3.ZERO, Vector3(0, 2, 9), Vector3.ZERO)
