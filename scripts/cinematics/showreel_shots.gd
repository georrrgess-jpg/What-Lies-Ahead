class_name ShowreelShots
extends RefCounted
## The trailer's shot list (docs/SHOWREEL.md has the plan and its timing).
## Every shot is a method that stages one CineStage; build() returns them in
## order. Times inside a shot are its own seconds; the reel is locked to
## audio/music/showreel_trailer.ogg: 150 BPM, a beat is 0.4 s, a bar 1.6 s,
## 41.6 s in all. Every cut lands on a beat; the locked hits are 6.0 (logo
## slam), 8.0 (the groove: fifteen worlds), 14.0-16.4 (an alpha a hit),
## 17.2 (cut-out), 17.6 (the drop), 22.0-22.8 (slow motion), 27.2 (Endless),
## 30.4 (Last Ride), 32.0 (make it yours), 35.2 and 38.4 (the finale) and
## 41.6 (the picture is black; the score rings out under a last line).
##
## Actors, levels and cosmetics are referenced by id, so the reel always shows
## the game's current models and effects. The picks below are the only place
## to swap featured items.

const PIER := "prize_pier"
const STUDIO := "studio"
const BOOT := "boot_camp"
const CITY := "endless_city"
const BEAT := 0.4

# --- featured items (swap ids here) ---------------------------------------------

## The fifteen worlds in unlock order: [level, camera from, look from, camera
## to, look to, zombies (walking at the lens), where they stand (ZERO: on
## the floor a few metres in front of the lens's last position)].
const WORLDS := [
	["prize_pier", Vector3(-8.0, 1.3, 7.5), Vector3(-27, 6.5, -22), Vector3(-10.0, 1.9, 4.5), Vector3(-29, 7.0, -22),
		[&"tourist_shambler", &"lifeguard_runner", &"boardwalk_bruiser"], Vector3(-13.5, 0, 0.5)],
	["neon_skyline", Vector3(25, 11, 24), Vector3(-2, 3, -6), Vector3(20.0, 8.0, 18.5), Vector3(-1, 3, -6),
		[&"neon_punk", &"hover_courier", &"riot_bruiser"], Vector3(5.5, 0, 5.0)],
	["tidal_tunnels", Vector3(7.6, 2.3, 6.9), Vector3(-1.5, 5.2, -2.5), Vector3(5.4, 2.6, 4.9), Vector3(-3.0, 5.2, -2.5),
		[&"deep_diver", &"jelly_head", &"mascot_inker"], Vector3.ZERO],
	["launch_pad", Vector3(7, 1.2, 12), Vector3(0, 8, -9), Vector3(8.5, 3.0, 14), Vector3(0, 15, -9),
		[&"dune_space_cadet", &"dune_hazmat_worker", &"dune_jet_mechanic"], Vector3.ZERO],
	["summit_lodge", Vector3(25, 9, 21), Vector3(-4, 4, -12), Vector3(20.5, 6.5, 16.5), Vector3(-4, 5, -12),
		[&"frost_ski_racer", &"frost_yeti", &"frost_frozen_tourist"], Vector3.ZERO],
	["midnight_mall", Vector3(-8.0, 7.5, 17.0), Vector3(0, 3.5, -9), Vector3(-6.5, 5.5, 11.5), Vector3(0, 4.0, -10),
		[&"mall_walker", &"mall_flinger", &"mall_walker"], Vector3(0, 0, -2.5)],
	["lost_temple", Vector3(7.0, 1.6, 15.0), Vector3(0, 7.0, -24), Vector3(6.5, 3.2, 10.5), Vector3(0, 8.0, -25),
		[&"jungle_explorer", &"jungle_overgrown", &"jungle_explorer"], Vector3.ZERO],
	["candy_works", Vector3(-10.0, 1.6, 18.0), Vector3(0, 9.0, -28), Vector3(-9.5, 3.0, 12.5), Vector3(0, 10.5, -28),
		[&"candy_gummy", &"candy_taffy_puller", &"candy_gummy"], Vector3(-3.5, 0, -3.5)],
	["lava_lagoon", Vector3(-6.0, 1.7, 17.0), Vector3(14, 24, -300), Vector3(-5.0, 2.8, 12.5), Vector3(16, 28, -300),
		[&"lava_fire_dancer", &"lava_tiki_bartender", &"lava_fire_dancer"], Vector3.ZERO],
	["sky_harbor", Vector3(-19.0, 1.8, 8.0), Vector3(-53, 12, -1.5), Vector3(-22.0, 3.0, 6.3), Vector3(-53, 13.5, -1.5),
		[&"sky_diver", &"sky_balloon_vendor", &"sky_diver"], Vector3.ZERO],
	["ghost_train", Vector3(9.0, 3.0, 24.0), Vector3(-4, 5, -20), Vector3(6.5, 2.2, 19.5), Vector3(-4, 5.5, -20),
		[&"fright_ghost", &"fright_pumpkin_head", &"fright_ghost"], Vector3(1.5, 0, 8.0)],
	["boomtown", Vector3(-0.8, 1.8, 6.0), Vector3(0.8, 10, 26), Vector3(0.0, 2.6, 9.5), Vector3(0.8, 11, 26),
		[&"gulch_cowpoke", &"gulch_prospector", &"gulch_cowpoke"], Vector3.ZERO],
	["skull_harbor", Vector3(13.0, 3.0, 11.0), Vector3(-24, 7, -6), Vector3(9.5, 2.4, 8.5), Vector3(-24, 7.5, -6),
		[&"cove_deckhand", &"cove_powder_monkey", &"cove_deckhand"], Vector3(1.5, 0, 3.0)],
	["royal_faire", Vector3(9.0, 2.6, 25.0), Vector3(-3, 6, -22), Vector3(6.5, 2.0, 20.0), Vector3(-3, 6.5, -22),
		[&"faire_knight", &"faire_jester", &"faire_knight"], Vector3(1.0, 0, 10.0)],
	["toy_shop", Vector3(-15.0, 3.0, 27.0), Vector3(14, 6, -14), Vector3(-12.0, 2.3, 23.0), Vector3(14, 6.5, -14),
		[&"toy_windup_soldier", &"toy_plush_brute", &"toy_windup_soldier"], Vector3(-4.0, 0, 14.0)],
]
## The four alpha reveals: [level, alpha, where it stands, yaw toward the lens].
const ALPHAS := [
	["ghost_train", &"alpha_ringmaster", Vector3(0.5, 0, 8.0), 20.0],
	["boomtown", &"alpha_rattlebones", Vector3(0.5, 0, 14.5), 180.0],
	["skull_harbor", &"alpha_barnacle", Vector3(2.0, 0, 4.5), 105.0],
	["toy_shop", &"alpha_toymaker", Vector3(-4.0, 0, 15.0), -40.0],
]
## The zombies that lunge at the lens in the muzzle-flash cold open: [level, zombie, where, yaw].
const LUNGES := [
	["neon_skyline", &"neon_punk", Vector3(5.0, 0, 6.5), 200.0],
	["tidal_tunnels", &"jelly_head", Vector3(0.3, 0, 12.0), 0.0],
	["launch_pad", &"dune_space_cadet", Vector3(2.0, 0, 5.0), 160.0],
	["midnight_mall", &"mall_walker", Vector3(0.5, 0, 12.5), 0.0],
]
## Reloads, close up: the weapon reloading in the dark open, and the showcase cuts.
const DARK_RELOAD := &"rail_lancer"
## Where a reload close-up moves the viewmodel (metres in the lens's space):
## left and up toward the middle of the frame, a little nearer.
const CLOSE_UP := Vector3(-0.035, 0.025, 0.0)
## Operators: the line-up (Madame Fortuna in the centre), the three who hold
## the line in the finale.
const LINEUP_FRONT: Array[StringName] = [&"op_stunt_ace", &"op_halfpipe", &"op_top_dog", &"op_pixel_pal",
	&"op_fortuna", &"op_windup", &"op_cosmic_sheriff", &"op_tide_keeper", &"op_mech_jockey"]
const LINEUP_BACK: Array[StringName] = [&"op_boardwalk_ranger", &"op_surf_rescue", &"op_neon_courier", &"op_deep_diver",
	&"op_glitch", &"op_astro_cadet", &"op_frost_guard", &"op_arcade_champion", &"op_midway_maestro", &"op_timber_jack"]
const FINALE_SQUAD: Array[StringName] = [&"op_cosmic_sheriff", &"op_fortuna", &"op_windup"]
const FINALE_GUNS: Array[StringName] = [&"whirligig", &"ticket_ripper", &"rail_lancer"]
## Kill effects of the parade, the sweep and the finale.
const PARADE_FX: Array[StringName] = [&"kfx_confetti", &"kfx_disco", &"kfx_pinata"]
const FINALE_FX: Array[StringName] = [&"kfx_jackpot", &"kfx_firework", &"kfx_tickets", &"kfx_balloon"]
## Tracers: the hero tracer (headshots) and the parade's.
const HERO_TRACER := &"tracer_neon"
const TRACERS: Array[StringName] = [&"tracer_ribbon", &"tracer_heartbeat", &"tracer_candy"]
## Gloves on the first-person arms.
const GLOVES: Array[StringName] = [&"glove_iron_knuckle", &"glove_showtime"]
## Make it yours: eight weapons, one animated Legendary (or Mythic) finish each.
const ARSENAL: Array[StringName] = [&"ticket_ripper", &"lava_lampoon", &"t_minus_six", &"coin_op",
	&"yoyo_loco", &"whirligig", &"strike_zone", &"rail_lancer"]
const ARSENAL_FINISHES: Array[StringName] = [&"fin_jackpot", &"fin_ghost_train", &"fin_treasure_map", &"fin_multiball",
	&"fin_marquee", &"fin_thunderhead", &"fin_galaxy", &"fin_last_light"]
## The sight in the aim-down-sights shot (on the cannon) and the finish of the print.
const ADS_SIGHT := &"sightx_gemcut"
const PRINT_WEAPON := &"ion_carbine"
const PRINT_FINISH := &"fin_kintsugi"

## Shots heavy enough to build during the warm-up instead of at their cut
## (CinePlayer measures each cut: --showreel-report=1).
const BUILT_AHEAD: Array[String] = ["dark_reload", "lunge_0", "lunge_1", "lunge_2", "lunge_3", "title",
	"world_0", "world_1", "world_2", "world_3", "world_4", "world_5", "world_6", "world_7", "world_8", "world_9",
	"world_10", "world_11", "world_12", "world_13", "world_14", "alpha_0", "alpha_1", "alpha_2", "alpha_3",
	"ripper", "reload_lava", "moves", "cryo", "ads", "reload_tminus", "lobber", "coin_op", "parade", "horde",
	"city_wide", "city_street", "last_ride", "arsenal", "operators", "prints", "finale"]

## The low sun over the sea behind the Ferris wheel (Prize Pier), for flares.
const PIER_SUN := Vector3(-120, 9, -70)
const SUN_COLOR := Color(1.0, 0.62, 0.38)


static func build() -> Array[CineShot]:
	var s := ShowreelShots.new()
	var list: Array[CineShot] = [
		# Cold open: a face, a reload in the dark, four flashes (0-4.8)
		CineShot.make("cold_open", PIER, 4 * BEAT, s._cold_open),
		CineShot.make("dark_reload", PIER, 4 * BEAT, s._dark_reload),
	]
	for i in LUNGES.size():
		list.append(CineShot.make("lunge_%d" % i, LUNGES[i][0], BEAT, s._lunge.bind(i)))
	# The breath and the slam (4.8-8.0)
	list.append(CineShot.make("roar", PIER, 3 * BEAT, s._roar))
	list.append(CineShot.make("title", PIER, 5 * BEAT, s._title))
	# Fifteen worlds, a beat each (8.0-14.0)
	for i in WORLDS.size():
		list.append(CineShot.make("world_%d" % i, WORLDS[i][0], BEAT, s._world.bind(i)))
	# Four alphas, a hit each (14.0-17.2), then the cut-out (17.2)
	for i in ALPHAS.size():
		list.append(CineShot.make("alpha_%d" % i, ALPHAS[i][0], 2 * BEAT, s._alpha.bind(i)))
	list.append(CineShot.make("lock_load", PIER, BEAT, s._lock_load))
	# The drop: combat (17.6-27.2)
	list.append_array([
		CineShot.make("ripper", PIER, 4 * BEAT, s._ripper),
		CineShot.make("reload_lava", "lava_lagoon", 2 * BEAT, s._reload_lava),
		CineShot.make("moves", BOOT, 2 * BEAT, s._moves),
		CineShot.make("cryo", PIER, 2 * BEAT, s._cryo),
		CineShot.make("ads", PIER, 3 * BEAT, s._ads),
		CineShot.make("reload_tminus", "launch_pad", 2 * BEAT, s._reload_tminus),
		CineShot.make("lobber", "candy_works", 2 * BEAT, s._lobber),
		CineShot.make("coin_op", "neon_skyline", 3 * BEAT, s._coin_op),
		CineShot.make("parade", "midnight_mall", 2 * BEAT, s._parade),
		CineShot.make("horde", PIER, 2 * BEAT, s._horde),
		# Endless: Ashfall City (27.2-30.4), Last Ride (30.4-32.0)
		CineShot.make("city_wide", CITY, 4 * BEAT, s._city_wide),
		CineShot.make("city_street", CITY, 4 * BEAT, s._city_street),
		CineShot.make("last_ride", PIER, 4 * BEAT, s._last_ride),
		# Make it yours (32.0-35.2)
		CineShot.make("arsenal", STUDIO, 4 * BEAT, s._arsenal),
		CineShot.make("operators", STUDIO, 2 * BEAT, s._operators),
		CineShot.make("prints", STUDIO, 2 * BEAT, s._prints),
		# The finale: hold the line (35.2), the title (38.4), black (41.6)
		CineShot.make("finale", PIER, 16 * BEAT, s._finale),
		# The music's ring-out on black (41.6 to the track's end, 43.4)
		CineShot.make("ring_out", PIER, 4.5 * BEAT, s._ring_out),
	])
	for shot in list:
		shot.prebuild = shot.id in BUILT_AHEAD
	return list


# --- helpers ------------------------------------------------------------------

## A first-person weapon on the game's own viewmodel rig (WeaponView: sway,
## kick, muzzle flash and the weapon's real reload), pinned to the lens, with
## the operator's arms in `gloves`. `lean` moves it in the lens's space (a
## reload close-up brings it in toward the middle of the frame).
func _viewmodel(st: CineStage, weapon_id: StringName, finish: StringName, gloves: StringName, sight: StringName = &"", lean := Vector3.ZERO) -> WeaponView:
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


func _world_of(level_id: String) -> WorldData:
	var l := GameData.level(StringName(level_id))
	return l.world if l else null


func _enemy_name(id: StringName) -> String:
	var e := GameData.enemy(id)
	return e.display_name if e else String(id)


func _weapon_name(id: StringName) -> String:
	var w := GameData.weapon(id)
	return w.display_name if w else String(id)


func _alpha_count() -> int:
	return GameData.enemies().filter(func(e): return String(e.id).begins_with("alpha_")).size()


func _operator_count() -> int:
	return GameData.cosmetics().filter(func(c): return c.slot == &"avatar").size()


func _turntable(st: CineStage, model: Node3D, height := 1.25, span := 1.3) -> Node3D:
	var pivot := Node3D.new()
	st.actors.add_child(pivot)
	pivot.position = Vector3(0, height, 0)
	pivot.add_child(model)
	var box := WeaponCosmetics.visible_bounds(model)
	model.position = -box.get_center()
	pivot.scale = Vector3.ONE * span / maxf(0.01, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	return pivot


# --- cold open (0-8) ------------------------------------------------------------

## Out of black: a slow push on a tourist's face at dusk; its eyes catch cyan light.
func _cold_open(st: CineStage) -> void:
	st.at(0.0, st.overlay.bars.bind(1.0, 0.0))
	st.at(0.0, st.overlay.fade.bind(1.0, 0.0))
	st.at(0.0, st.overlay.fade.bind(0.0, 0.7))
	st.at(0.0, st.overlay.grade.bind(&"dusk"))
	st.lighting(0.3, 0.9, 1.2, 0.25)
	var z := st.zombie(&"tourist_shambler", Vector3(-5, 0, -3), 45.0, "Idle", 0.6)
	var face := st.head(z) + Vector3(0, -0.05, 0)
	var fwd := Vector3(sin(deg_to_rad(45.0)), 0, cos(deg_to_rad(45.0)))
	var side := fwd.cross(Vector3.UP)
	st.fov(28.0, 22.0)
	st.dolly(face + fwd * 2.2 + side * 1.2 + Vector3(0, -0.2, 0), face, face + fwd * 1.5 + side * 0.7 + Vector3(0, -0.08, 0), face + Vector3(0, 0.03, 0), 1.0)
	st.light(face - fwd * 0.9 + Vector3(0, 0.5, 0), UiKit.PINK, 3.0, 3.5)
	st.flare_at(func(): return st.head(z) + fwd * 0.18, Wallet.COLOR_GLOW, 0.3, 0.7, 0.4)
	st.at(1.0, st.play.bind(z, "Roar", 0.5, 0.0, 0.3))
	st.focus_on(func(): return st.head(z), 0.16, 0.009)


## Near darkness, first person: the Rail Lancer's capacitor swap prints its
## hologram and the glow lights the hands; the charge rings snap on.
func _dark_reload(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"dark"))
	st.lighting(0.22, 0.6, 1.6, 0.05)
	var view := _viewmodel(st, DARK_RELOAD, &"fin_thunderhead", GLOVES[1], &"", CLOSE_UP)
	var eye := Vector3(-3.0, 1.6, 6.0)
	st.fov(42.0, 38.0)
	_eye_track(st, eye, eye + Vector3(-1, -0.2, -1), eye + Vector3(-1, -0.1, -0.75), Vector3(-0.1, 0.03, -0.15), 1.0)
	var d := GameData.weapon(DARK_RELOAD).reload_time
	_reload(st, view, DARK_RELOAD, 0.0, d * 0.85)
	_lens_light(st, UiKit.CYAN, Vector3(-0.02, 0.02, -0.12), func(t: float) -> float:
		return 0.6 + 2.6 * smoothstep(0.25, 0.55, t) * (1.0 - smoothstep(1.15, 1.45, t)) + 3.5 * exp(-pow((t - 1.3) * 7.0, 2.0)), 1.4)


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
	var cam := at + fwd * 3.4 + fwd.cross(Vector3.UP) * 0.5 + Vector3.UP * 1.0
	st.fov(48.0, 42.0)
	st.track(func(k: float) -> Transform3D:
		var from := cam + fwd * 0.25 * k
		return Transform3D(Basis.looking_at(st.head(z) + Vector3(0, -0.25, 0) - from), from))
	var muzzle := func() -> Vector3: return st.camera.global_transform * Vector3(0.28, -0.3, -0.6)
	var flash := st.light(Vector3.ZERO, Color(1.0, 0.8, 0.55), 0.0, 9.0)
	st.after_camera(func(t: float):
		flash.global_position = muzzle.call()
		flash.light_energy = 6.0 * maxf(exp(-pow((t - 0.05) * 22.0, 2.0)), exp(-pow((t - 0.22) * 22.0, 2.0))))
	for when in [0.04, 0.21]:
		st.at(when, func(): st.shoot(&"comet_cannon", muzzle.call(), st.chest(z) + Vector3(0, 0.2, 0), 1.0, when < 0.1))
	if index == LUNGES.size() - 1:
		st.at(0.21, st.kill.bind(z, &"comet_cannon", true, -fwd, 4.0))
	else:
		st.at(0.21, st.hit.bind(z, &"comet_cannon", 1.0, st.chest(z), -fwd))
	st.shake(0.05, 0.05, 0.3)


## The breath: a Bruiser in silhouette in the dark lifts its head and roars;
## the frame sinks to black for the slam.
func _roar(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"dark"))
	st.at(0.0, st.overlay.fade.bind(0.25, 0.0))
	st.at(0.75, st.overlay.fade.bind(1.0, 0.4))
	st.lighting(0.1, 0.6, 1.0, 0.05)
	var z := st.zombie(&"boardwalk_bruiser", Vector3(-7, 0, 2), 50.0, "Idle", 0.6)
	st.at(0.05, st.play.bind(z, "Roar", 0.8, 0.0, 0.15))
	var face := st.head(z)
	var fwd := Vector3(sin(deg_to_rad(50.0)), 0, cos(deg_to_rad(50.0)))
	st.fov(34.0, 28.0)
	st.dolly(face + fwd * 3.4 + Vector3(0, -0.9, 0), face, face + fwd * 2.7 + Vector3(0, -0.7, 0), face + Vector3(0, 0.1, 0), 1.0)
	st.light(face - fwd * 1.2 + Vector3(0, 0.9, 0), UiKit.CYAN, 2.5, 3.5)
	st.flare_at(func(): return st.head(z) + fwd * 0.2, UiKit.RED, 0.35, 0.1, 0.2)
	st.shake(0.25, 0.04, 0.6)


## 6.0, the slam: the logo hits over the pier at dusk, the lights come up in
## steps and the camera cranes toward the Ferris wheel over the horde.
func _title(st: CineStage) -> void:
	st.at(0.0, st.overlay.fade.bind(0.0, 0.0))
	st.at(0.0, st.overlay.grade.bind(&"dusk"))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.5, 0.95))
	st.at(0.0, func(): st.overlay.logo(Vector2(0.5, 0.4), 150))
	st.lighting(0.5, 0.95, 0.4, 0.5)
	st.every_frame(func(t: float):
		var env := st.environment()
		if env:
			env.glow_intensity = 0.4 + 0.9 * clampf(floorf(t / 0.1) / 8.0, 0.0, 1.0))
	st.shake(0.0, 0.09, 0.5)
	st.fov(50.0, 44.0)
	st.dolly(Vector3(-9, 0.9, 4.0), Vector3(-20, 2.2, -9), Vector3(-6, 5.5, 7.5), Vector3(-26, 6.0, -22), -1.4)
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.4)
	var kinds := [&"tourist_shambler", &"lifeguard_runner", &"tourist_shambler", &"boardwalk_bruiser", &"tourist_shambler", &"lifeguard_runner", &"neon_punk"]
	for i in kinds.size():
		var p := Vector3(-12.0 - (i % 3) * 2.2 - i * 0.7, 0, -1.0 - ((i + 1) % 3) * 1.9 - i * 0.7)
		st.walker(kinds[i], p, 40.0 + randf_range(-10.0, 10.0), 0.7)


# --- fifteen worlds (8-14) -------------------------------------------------------

## One world a beat: a fast push on its landmark, its own zombies walking at
## the lens, the world's number and name low left; the last four carry the
## "15 worlds" title across their cuts.
func _world(st: CineStage, index: int) -> void:
	var spec: Array = WORLDS[index]
	var level := GameData.level(StringName(spec[0]))
	var look := &"night" if index in [1, 2, 4, 5, 10, 14] else (&"golden" if index in [3, 6, 8, 12] else &"day")
	st.at(0.0, st.overlay.grade.bind(look))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.12, 0.18))
	st.lighting(1.0, 1.0, 1.2)
	st.fov(54.0, 48.0)
	st.dolly(spec[1], spec[2], spec[3], spec[4], 1.0)
	var pack: Vector3 = spec[6]
	if pack == Vector3.ZERO:
		var ahead: Vector3 = spec[4] - spec[3]
		pack = spec[3] + Vector3(ahead.x, 0, ahead.z).normalized() * 6.5
		pack.y = 0.0
	_pack(st, spec[5], pack, spec[1], 1.8, 0.95)
	var w := _world_of(spec[0])
	if w:
		st.at(0.0, st.overlay.tag.bind("World %02d" % (index + 1), w.display_name, w.accent_color.lerp(Color.WHITE, 0.35)))
	elif level:
		st.at(0.0, st.overlay.tag.bind("World %02d" % (index + 1), level.display_name))
	if index >= WORLDS.size() - 4:
		var first := index == WORLDS.size() - 4
		st.at(0.0, st.overlay.stamp.bind("%d worlds" % GameData.worlds().size(), "Story", Vector2(0.5, 0.24), 1.0, UiKit.AMBER, 104, first))
	if spec[0] == "lava_lagoon":
		_erupt(st)


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


# --- alphas (14-17.2) ------------------------------------------------------------

## An alpha at a low lens on its hit: it roars, the frame jolts, its name slams in.
func _alpha(st: CineStage, index: int) -> void:
	var spec: Array = ALPHAS[index]
	var at: Vector3 = spec[2]
	var yaw: float = spec[3]
	st.at(0.0, st.overlay.grade.bind(&"night" if index != 1 else &"golden"))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.25, 0.5))
	st.lighting(0.8, 1.0, 1.3)
	var z := st.zombie(spec[1], at, yaw, "Idle", 1.0)
	st.at(0.02, st.play.bind(z, "Roar", 1.1, 0.0, 0.1))
	var fwd := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	var side := fwd.cross(Vector3.UP)
	var tall := 1.75 * z.data.body_scale
	st.fov(46.0, 38.0)
	st.track(func(k: float) -> Transform3D:
		var from := at + fwd * lerpf(tall * 2.1, tall * 1.75, k) + side * lerpf(1.2, 0.5, k) + Vector3.UP * 0.35
		return Transform3D(Basis.looking_at(at + Vector3.UP * tall * 0.62 - from), from))
	st.light(at + fwd * 2.5 + side * -2.0 + Vector3.UP * 3.0, Color("ffd9a8"), 3.0, 10.0)
	st.light(at - fwd * 1.5 + Vector3.UP * 2.5, UiKit.PINK if index % 2 == 0 else UiKit.CYAN, 4.0, 6.0)
	st.shake(0.0, 0.1, 0.5)
	var w := _world_of(spec[0])
	st.at(0.0, st.overlay.stamp.bind(_enemy_name(spec[1]), "Alpha  ·  " + (w.display_name if w else ""), Vector2(0.5, 0.78), 0.62, UiKit.RED, 84))


## The cut-out: black, and three words.
func _lock_load(st: CineStage) -> void:
	st.at(0.0, st.overlay.fade.bind(0.0, 0.0))
	st.at(0.0, st.overlay.backdrop.bind(1.0))
	st.at(0.0, st.overlay.stamp.bind("Lock and load", "", Vector2(0.5, 0.5), 0.3, UiKit.CREAM, 80))
	st.dolly(Vector3(0, 2, 10), Vector3.ZERO, Vector3(0, 2, 9), Vector3.ZERO)


# --- the drop: combat (17.6-27.2) --------------------------------------------------

## First person, the Ticket Ripper: a spray through a pack, the streak prints
## a golden WINNER round that pierces the line and pops its ticket burst.
func _ripper(st: CineStage) -> void:
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.35, 0.8))
	st.at(0.0, st.overlay.grade.bind(&"golden"))
	var eye := Vector3(2, 1.6, -13)
	var targets: Array[Zombie] = []
	var kinds := [&"tourist_shambler", &"lifeguard_runner", &"boardwalk_bruiser", &"tourist_shambler", &"lifeguard_runner"]
	for i in kinds.size():
		var a := deg_to_rad(-28.0 + i * 14.0)
		var p := eye + Vector3(-cos(a), 0, sin(a)) * (6.5 + (i % 2) * 1.5)
		p.y = 0.0
		targets.append(st.walker(kinds[i], p, _yaw_to(p, eye), 0.9))
	var view := _viewmodel(st, &"ticket_ripper", &"fin_jackpot", GLOVES[0])
	st.fov(64.0)
	st.track(func(k: float) -> Transform3D:
		var a := deg_to_rad(lerpf(-34.0, 30.0, ease(clampf(k * 1.4, 0.0, 1.0), -1.4)))
		var look := eye + Vector3(-cos(a), -0.06, sin(a))
		return Transform3D(Basis.looking_at(look - eye), eye))
	# Fifteen a second along the pack; three drop, then the winner.
	for n in 11:
		var tgt := targets[mini(n / 4, 2)]
		st.at(0.05 + n * 0.067, func():
			if is_instance_valid(tgt) and not tgt.is_dead():
				_fire_view(st, view, &"ticket_ripper", st.chest(tgt) + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.3), 0), &"", n % 2 == 0))
	for i in 3:
		st.at(0.3 + i * 0.27, st.kill.bind(targets[i], &"ticket_ripper", i == 1, Vector3(-1, 0, 0), 4.0))
	st.at(0.9, st.overlay.tag.bind("Streak  ·  15 in a row", "Ticket Ripper", UiKit.AMBER))
	st.at(1.0, _winner.bind(st, view, targets[3], targets[4]))
	st.slowmo(1.0, 1.6, 0.3, 0.05, 0.4)


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
	st.overlay.flash(TicketRipperMode.WINNER_GOLD, 0.3, 0.35)
	st.shake(st.t, 0.05, 0.3)


## Close on the Lava Lampoon's reload at dusk under the volcano: the lamp
## lifts out on its hologram ring and cartwheels, in slow motion.
func _reload_lava(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"dusk"))
	st.lighting(0.7, 0.95, 1.3)
	var view := _viewmodel(st, &"lava_lampoon", &"", GLOVES[1], &"", CLOSE_UP)
	var eye := Vector3(4.0, 1.6, 16.5)
	st.fov(38.0, 34.0)
	_eye_track(st, eye, eye + Vector3(0.25, -0.15, -1), eye + Vector3(0.35, -0.1, -1), Vector3(0, -0.02, -0.08), 1.0)
	var d := GameData.weapon(&"lava_lampoon").reload_time
	_reload(st, view, &"lava_lampoon", 0.0, d, d * 0.22)
	st.slowmo(0.0, 0.8, 0.55, 0.01, 0.2)
	_lens_light(st, Color(1.0, 0.45, 0.25), Vector3(0.2, -0.1, -0.5), func(_t: float) -> float: return 1.4)
	st.at(0.0, st.overlay.tag.bind("Reload", _weapon_name(&"lava_lampoon"), Color(1.0, 0.55, 0.3)))


## First person down the Boot Camp lane: a sprint, a vault and a slide under
## the low sign, on one camera curve.
func _moves(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"day"))
	var view := _viewmodel(st, &"ion_carbine", &"fin_marquee", GLOVES[0])
	var x := 0.9
	st.spline([
		[0.0, Vector3(x, 2.0, -44.6), Vector3(x, 1.6, -55)],
		[0.18, Vector3(x, 2.1, -46.6), Vector3(x, 1.5, -57)],
		[0.34, Vector3(x, 1.6, -48.4), Vector3(x, 1.3, -60)],
		[0.56, Vector3(x, 0.95, -51.2), Vector3(x, 0.9, -62)],
		[0.8, Vector3(x, 0.82, -54.0), Vector3(x, 1.0, -64)],
	])
	st.fov(70.0, 76.0)
	st.every_frame(func(t: float):
		view.staged_mantle = smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.2, 0.34, t))
		view.staged_slide = smoothstep(0.38, 0.52, t)
		view.staged_sprint = clampf(1.0 - view.staged_mantle - view.staged_slide, 0.0, 1.0)
		view.staged_gait = Vector2(t * TAU * 2.2, view.staged_sprint))
	st.at(0.0, st.overlay.tag.bind("Move", "Sprint  ·  vault  ·  slide", UiKit.CYAN))
	st.at(0.38, func(): Sfx.play(&"ui_whoosh", -8.0, 0.7))


## The Cryo Beam sweeps three; they freeze solid and shatter in slow motion.
func _cryo(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"day"))
	var cryo := GameData.weapon(&"cryo_beam")
	var zs: Array[Zombie] = []
	for i in 3:
		zs.append(st.zombie(&"tourist_shambler" if i != 1 else &"boardwalk_bruiser", Vector3(-4.5 - i * 1.6, 0, 13.0 + 1.2 * i), 100.0, "Walk", 0.7))
	var muzzle := Vector3(3.5, 1.3, 16.5)
	var beam := BeamVisual.new()
	beam.color = cryo.tracer_color
	beam.width = 0.12
	st.actors.add_child(beam)
	st.fov(42.0, 36.0)
	st.dolly(Vector3(0.5, 1.4, 20.5), Vector3(-6, 1.2, 14), Vector3(-0.3, 1.25, 19.6), Vector3(-6.2, 1.1, 14), 1.0)
	st.every_frame(func(t: float):
		var k := clampi(int(t / 0.12), 0, 2)
		beam.aim(muzzle, st.chest(zs[k]) if is_instance_valid(zs[k]) else muzzle, t < 0.4))
	for i in 3:
		st.at(0.02 + i * 0.12, func(): StatusEffects.of(zs[i]).apply(cryo, 9.0))
	st.at(0.0, func(): Sfx.play(cryo.fire_sound, -6.0))
	st.slowmo(0.42, 0.8, 0.3, 0.03, 0.2)
	st.at(0.44, func():
		for i in 3:
			st.kill(zs[i], &"cryo_beam", false, Vector3(-1, 0, 0), 2.0))
	st.shake(0.44, 0.06, 0.3)
	st.at(0.0, st.overlay.tag.bind("Freeze  ·  shatter", _weapon_name(&"cryo_beam"), Color("9fe8ff")))


## Aim down sights on the hit: the cannon comes up, its optic's reticle
## lights on a far head, and at 22.0 the head pops in slow motion.
func _ads(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"day"))
	var eye := Vector3(3.0, 1.6, -12.0)
	var z := st.walker(&"lifeguard_runner", Vector3(-13.0, 0, -15.5), 75.0, 0.7)
	st.walker(&"tourist_shambler", Vector3(-11.0, 0, -9.5), 100.0, 0.7)
	var view := _viewmodel(st, &"comet_cannon", &"fin_solar_flare", GLOVES[1], ADS_SIGHT)
	st.after_camera(func(t: float):
		var k := smoothstep(0.0, 0.32, t)
		view.staged_aim = k
		st.lens_fov(lerpf(64.0, 64.0 / 1.6, k)))
	st.track(func(_k: float) -> Transform3D:
		var head := st.head(z) if is_instance_valid(z) else Vector3(-12.0, 1.6, -15.0)
		var look := head.lerp(eye + (head - eye).normalized() * 10.0 + Vector3(0, -0.6, 2.0), 1.0 - smoothstep(0.0, 0.34, st.t))
		return Transform3D(Basis.looking_at(look - eye), eye))
	st.at(0.05, st.overlay.tag.bind("Aim down sights", Cosmetics.item(ADS_SIGHT).display_name if Cosmetics.item(ADS_SIGHT) else "Sights", UiKit.CYAN))
	st.at(0.4, func():
		_fire_view(st, view, &"comet_cannon", st.head(z), HERO_TRACER)
		st.kill(z, &"comet_cannon", true, Vector3(-1, 0, -0.2), 4.0, &"kfx_starburst")
		Sfx.play(&"headshot_ping", -6.0))
	st.slowmo(0.4, 1.2, 0.2, 0.03, 0.3)


## Close on the T-Minus Six's reload at the spaceport: rockets slide down the
## hologram gantry into the pod, the countdown runs, the pod flares.
func _reload_tminus(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"golden"))
	var view := _viewmodel(st, &"t_minus_six", &"fin_treasure_map", GLOVES[0], &"", CLOSE_UP)
	var eye := Vector3(0.0, 1.6, 21.5)
	st.fov(38.0, 34.0)
	_eye_track(st, eye, eye + Vector3(-0.2, -0.12, -1), eye + Vector3(-0.1, -0.05, -1), Vector3(0, 0, -0.1), 1.0)
	var d := GameData.weapon(&"t_minus_six").reload_time
	_reload(st, view, &"t_minus_six", 0.0, d * 0.75, d * 0.25)
	_lens_light(st, UiKit.CYAN, Vector3(0.15, -0.15, -0.45), func(t: float) -> float: return 0.8 + 1.5 * smoothstep(0.5, 0.75, t))
	st.at(0.0, st.overlay.tag.bind("Reload", _weapon_name(&"t_minus_six"), UiKit.CYAN))


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
	st.fov(46.0, 40.0)
	st.dolly(Vector3(4.5, 2.2, 12.5), centre + Vector3(0, 0.8, 0), Vector3(3.8, 1.6, 11.4), centre + Vector3(0, 1.0, 0), 1.0)
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
		var k := clampf(t / 0.28, 0.0, 1.0)
		ball.visible = k < 1.0
		ball.global_position = start.lerp(centre + Vector3(0, 0.3, 0), k) + Vector3.UP * sin(k * PI) * 2.2)
	st.at(0.0, func(): Sfx.play(lob.fire_sound, -5.0))
	st.slowmo(0.29, 0.8, 0.28, 0.02, 0.25)
	st.at(0.28, func():
		WeaponFx.explosion(st.actors, centre + Vector3(0, 0.4, 0), lob.tracer_color, 2.8)
		Sfx.play(lob.explosion_sound, -3.0)
		for z in zs:
			st.kill(z, &"bumper_lobber", false, (z.global_position - centre).normalized() + Vector3.UP * 0.3, 9.0))
	st.shake(0.28, 0.12, 0.45)
	st.flare_at(func(): return centre + Vector3(0, 0.6, 0), lob.tracer_color.lerp(Color.WHITE, 0.3), 0.8, 0.28, 0.02, 0.6, 0.2)
	st.at(0.0, st.overlay.tag.bind("Splash", _weapon_name(&"bumper_lobber"), UiKit.PINK))


## The Coin-Op at night on the rooftops: a spray, a headshot pays FREE PLAY
## (ka-ching), then the coin-return reload.
func _coin_op(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"night"))
	st.lighting(1.1, 1.0, 1.3)
	var eye := Vector3(3.0, 1.6, 12.5)
	var targets := _pack(st, [&"neon_punk", &"hover_courier", &"neon_punk"], Vector3(3.5, 0, 6.5), eye, 1.4, 0.9)
	var view := _viewmodel(st, &"coin_op", &"fin_multiball", GLOVES[1])
	st.fov(58.0, 52.0)
	_eye_track(st, eye, Vector3(1.8, 1.2, 6.0), Vector3(4.0, 0.9, 6.0), Vector3.ZERO, -1.4)
	for n in 7:
		var tgt := targets[mini(n / 3, 2)]
		st.at(0.03 + n * 0.07, func():
			if is_instance_valid(tgt) and not tgt.is_dead():
				_fire_view(st, view, &"coin_op", st.chest(tgt) + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.4), 0), &"", n % 2 == 0))
	st.at(0.2, st.kill.bind(targets[0], &"coin_op", false, Vector3(0, 0, -1), 3.0))
	st.at(0.42, func():
		var at := st.chest(targets[1])
		st.kill(targets[1], &"coin_op", true, Vector3(0, 0, -1), 3.0)
		CoinOpPopup.spawn(st.actors, at + Vector3.UP * 0.3, CoinOpMode.PAYOUT_ROUNDS, true)
		Sfx.play(CoinOpMode.PAYOUT_SOUND, -2.0)
		view.weapon_event(GameData.weapon(&"coin_op"), CoinOpMode.PAYOUT_EVENT))
	_reload(st, view, &"coin_op", 0.55, 1.0, 0.1)
	st.at(0.0, st.overlay.tag.bind("Free play: kills pay ammo", _weapon_name(&"coin_op"), UiKit.AMBER))


## A kill-effect parade in the mall: three zombies pop in confetti, a disco
## ball and a pinata as the camera trucks past.
func _parade(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"night"))
	st.lighting(1.1, 1.0, 1.3)
	var zs := _pack(st, [&"mall_walker", &"mall_flinger", &"mall_walker"], Vector3(0, 0, 4.0), Vector3(0, 0, 14), 2.2, 0.8)
	st.fov(44.0, 40.0)
	st.dolly(Vector3(-4.0, 1.5, 11.0), Vector3(-1.5, 1.2, 4.0), Vector3(-1.0, 1.5, 11.5), Vector3(1.5, 1.2, 4.0), 1.0)
	var muzzle := Vector3(-6.0, 1.4, 12.0)
	for i in 3:
		st.at(0.06 + i * 0.2, func():
			st.shoot(&"ion_carbine", muzzle, st.chest(zs[i]), 1.0, true, TRACERS[i])
			st.kill(zs[i], &"ion_carbine", i == 1, Vector3(1, 0, -0.3), 4.0, PARADE_FX[i]))
	st.at(0.0, st.overlay.tag.bind("Kill effects", "%s  ·  %s  ·  %s" % [_cosmetic_name(PARADE_FX[0]), _cosmetic_name(PARADE_FX[1]), _cosmetic_name(PARADE_FX[2])], UiKit.PINK))


func _rarity_color(id: StringName) -> Color:
	var item := Cosmetics.item(id)
	return CosmeticItem.rarity_color(item.rarity) if item else UiKit.AMBER


func _cosmetic_name(id: StringName) -> String:
	var item := Cosmetics.item(id)
	return item.display_name if item else String(id)


## The horde charges the lens at a run, low at dusk; the camera backs away.
func _horde(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"dusk"))
	st.lighting(0.6, 0.95, 1.1, 0.6)
	var cam := Vector3(-2.0, 0.6, 15.5)
	var kinds := [&"lifeguard_runner", &"tourist_shambler", &"neon_punk", &"boardwalk_bruiser", &"jungle_explorer",
		&"lifeguard_runner", &"cove_deckhand", &"tourist_shambler", &"gulch_cowpoke", &"lifeguard_runner",
		&"fright_pumpkin_head", &"tourist_shambler", &"mall_walker", &"lifeguard_runner"]
	for i in kinds.size():
		var p := Vector3(-8.0 - (i / 4) * 2.3 - (i % 2) * 0.8, 0, 15.0 + ((i % 4) - 1.5) * 1.6)
		st.walker(kinds[i], p, _yaw_to(p, cam) + randf_range(-6.0, 6.0), 1.0, true)
	st.fov(40.0, 46.0)
	st.dolly(cam, Vector3(-12, 1.5, 15.2), cam + Vector3(1.4, 0.15, 0.1), Vector3(-12, 1.6, 15.2), 1.0)
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.45)
	st.shake(0.0, 0.03, 0.8)


# --- Endless, Last Ride (27.2-32.0) ------------------------------------------------

## Ashfall City, wide: a crane down over the burning square as the horde floods in.
func _city_wide(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"ember"))
	st.at(0.0, st.overlay.flash.bind(Color(1.0, 0.6, 0.3), 0.3, 0.6))
	var kinds := [&"city_shambler", &"city_runner", &"city_shambler", &"city_bruiser", &"city_runner", &"city_shambler",
		&"riot_shield", &"city_runner", &"city_shambler", &"tunnel_crawler", &"city_runner", &"city_shambler"]
	var toward := Vector3(0, 0, 40)
	for i in kinds.size():
		var p := Vector3(((i % 4) - 1.5) * 2.2, 0, 13.0 - (i / 4) * 2.6 + (i % 2) * 0.8)
		st.walker(kinds[i], p, _yaw_to(p, toward), 1.0, i % 3 != 0)
	st.fov(50.0, 44.0)
	st.dolly(Vector3(-2.5, 10.0, 33.0), Vector3(0, 2.0, 4), Vector3(-1.5, 4.0, 25.0), Vector3(0, 1.5, 6), -1.2)
	st.at(0.1, st.overlay.stamp.bind("Endless", "Ashfall City", Vector2(0.5, 0.26), 1.3, Color(1.0, 0.55, 0.25), 120))


## Street level in the city: the horde runs at the lens, the wave count climbs
## and the Wrecker looms behind them.
func _city_street(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"ember"))
	var cam := Vector3(1.0, 1.0, 17.0)
	var kinds := [&"city_runner", &"city_shambler", &"tunnel_crawler", &"city_runner", &"firebug", &"city_shambler",
		&"city_runner", &"riot_shield", &"city_shambler"]
	for i in kinds.size():
		var p := Vector3(((i % 3) - 1.0) * 1.9 + randf_range(-0.3, 0.3), 0, 8.5 - (i / 3) * 2.2)
		st.walker(kinds[i], p, _yaw_to(p, cam), 1.0, true)
	var boss := st.walker(&"the_wrecker", Vector3(-6.0, 0, 7.0), _yaw_to(Vector3(-6.0, 0, 7.0), cam), 0.9)
	st.at(0.9, st.play.bind(boss, "Roar", 1.0, 0.0, 0.1))
	st.fov(46.0, 40.0)
	st.dolly(cam, Vector3(-1.0, 2.6, 4), cam + Vector3(-0.8, 0.2, 1.2), Vector3(-2.0, 3.2, 4), 1.0)
	st.at(0.0, func(): st.overlay.counter("WAVE", 5, 30, 1.4, Vector2(0.5, 0.22), Color(1.0, 0.6, 0.3), 104))
	st.shake(0.9, 0.06, 0.6)


## Last Ride, the hardest difficulty: blood red, the Black Knight charges.
func _last_ride(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"blood"))
	st.at(0.0, st.overlay.flash.bind(UiKit.RED, 0.3, 0.7))
	st.lighting(0.5, 0.9, 1.3, 0.5)
	var start := Vector3(-14.0, 0, 15.0)
	var cam := Vector3(-3.0, 0.5, 15.8)
	var z := st.walker(&"alpha_black_knight", start, _yaw_to(start, cam), 1.0, true)
	for i in 4:
		var p := start + Vector3(-2.5 - i * 1.2, 0, (i - 1.5) * 1.8)
		st.walker([&"faire_knight", &"lifeguard_runner"][i % 2], p, _yaw_to(p, cam), 1.0, true)
	st.fov(38.0, 44.0)
	st.track(func(k: float) -> Transform3D:
		var at := z.global_position if is_instance_valid(z) else start
		var from := cam + Vector3(0.4 * k, 0.1 * k, 0.6 * k)
		return Transform3D(Basis.looking_at(at + Vector3.UP * 2.0 - from), from))
	st.slowmo(0.5, 1.6, 0.45, 0.2, 0.2)
	st.shake(0.0, 0.05, 1.6)
	st.light(cam + Vector3(-1, 2, 0), UiKit.RED, 3.0, 14.0)
	st.at(0.05, st.overlay.stamp.bind(Difficulty.LABELS[&"last_ride"], "The hardest difficulty", Vector2(0.5, 0.22), 1.3, UiKit.RED, 120))
	st.at(0.5, st.overlay.tag.bind("No healing  ·  no checkpoints", "Double XP and Sparks", UiKit.RED))


# --- make it yours (32-35.2) ---------------------------------------------------------

## Eight weapons on the turntable, one a half beat, each in an animated
## Legendary (or Mythic) finish; the turn carries on across the swaps.
func _arsenal(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"studio"))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.2, 0.6))
	st.lighting(1.0, 1.0, 1.2)
	var pivots: Array[Node3D] = []
	for i in ARSENAL.size():
		var p := _turntable(st, st.weapon(ARSENAL[i], ARSENAL_FINISHES[i]), 1.3, 1.4)
		p.visible = i == 0
		pivots.append(p)
	st.fov(32.0, 28.0)
	st.dolly(Vector3(0.7, 1.5, 3.2), Vector3(0, 1.25, 0), Vector3(-0.5, 1.4, 2.8), Vector3(0, 1.25, 0), 1.0)
	var step := 4 * BEAT / ARSENAL.size()
	st.every_frame(func(t: float):
		var k := clampi(int(t / step), 0, pivots.size() - 1)
		for i in pivots.size():
			pivots[i].visible = i == k
		pivots[k].rotation.y = deg_to_rad(-70.0 + t * 60.0))
	for i in ARSENAL.size():
		st.at(i * step + 0.01, func():
			if i > 0:
				st.overlay.flash(Color.WHITE, 0.1, 0.25)
			st.overlay.clear_text()
			st.overlay.tag("%d weapons" % GameData.weapons().size(), _cosmetic_name(ARSENAL_FINISHES[i]), _rarity_color(ARSENAL_FINISHES[i])))
	st.at(0.05, func(): st.overlay.stamp("Make it yours", "", Vector2(0.5, 0.2), 1.4, UiKit.AMBER, 88))
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
	st.at(0.0, st.overlay.stamp.bind("%d operators" % _operator_count(), "Suit up", Vector2(0.5, 0.82), 0.6, UiKit.PINK, 72))


## Prize Prints: the capsule machine turns, a Legendary capsule drops and a
## print of a finish lands on the plinth in a gold flash.
func _prints(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"studio"))
	st.lighting(0.8, 1.0, 1.4)
	var pivot := _turntable(st, st.weapon(PRINT_WEAPON, PRINT_FINISH), 1.3, 1.3)
	pivot.visible = false
	st.every_frame(func(t: float):
		pivot.visible = t >= 0.4
		pivot.rotation.y = deg_to_rad(-50.0 + t * 70.0)
		pivot.position.y = 1.3 + 0.5 * pow(1.0 - smoothstep(0.4, 0.55, t), 2.0))
	st.fov(36.0, 32.0)
	st.dolly(Vector3(1.2, 1.55, 3.8), Vector3(-0.7, 1.45, 0), Vector3(0.9, 1.5, 3.3), Vector3(-0.6, 1.45, 0), 1.0)
	var gold := CosmeticItem.rarity_color(CosmeticItem.Rarity.LEGENDARY)
	st.at(0.0, func():
		var machine := CapsuleMachine.new()
		machine.series_text = "SERIES 1"
		machine.custom_minimum_size = Vector2(440, 560)
		st.overlay.place(machine, Vector2(0.26, 0.5))
		machine.turn(gold, true))
	st.at(0.4, func():
		st.overlay.flash(gold, 0.3, 0.6)
		WeaponFx.burst(st.actors, Vector3(0, 1.3, 0), Vector3.UP, [gold, Color.WHITE], 30, 4.0, 0.6, 0.04, 160.0, Vector3(0, -4, 0)))
	st.at(0.0, st.overlay.stamp.bind("Prize Prints", "%d cosmetics" % GameData.cosmetics().size(), Vector2(0.66, 0.8), 0.6, gold, 72))


# --- the finale (35.2-41.6) ------------------------------------------------------------

## Three operators hold the line at dusk as a huge horde charges; slow motion
## and a crane up and back; on 38.4 the logo slams in with the features and
## PLAY NOW, and the picture fades to black on 41.6.
func _finale(st: CineStage) -> void:
	st.at(0.0, st.overlay.grade.bind(&"golden"))
	st.at(0.0, st.overlay.flash.bind(Color.WHITE, 0.6, 0.9))
	st.lighting(0.45, 0.95, 1.25, 0.45)
	var squad: Array[Node3D] = []
	var guns: Array[Node3D] = []
	for i in FINALE_SQUAD.size():
		var op := st.operator(FINALE_SQUAD[i], Vector3(-2 + i * 1.3, 0, 15 + absf(i - 1) * 0.7), -100.0, "AimIdle")
		var gun := st.weapon(FINALE_GUNS[i], ARSENAL_FINISHES[[5, 0, 7][i]])
		Operators.hold_weapon(op, gun)
		squad.append(op)
		guns.append(gun)
	var horde: Array[Zombie] = []
	var kinds := [&"tourist_shambler", &"lifeguard_runner", &"boardwalk_bruiser", &"neon_punk", &"fright_ghost", &"gulch_cowpoke",
		&"cove_deckhand", &"faire_knight", &"toy_windup_soldier", &"candy_gummy", &"mall_walker", &"lava_fire_dancer",
		&"sky_diver", &"jungle_explorer", &"frost_yeti", &"deep_diver", &"tourist_shambler", &"lifeguard_runner"]
	for i in kinds.size():
		var p := Vector3(-10.0 - (i % 5) * 1.8 - (i / 5) * 1.2, 0, 11.5 + (i / 5) * 2.4 + (i % 2) * 0.9)
		horde.append(st.walker(kinds[i], p, 90.0 + randf_range(-8.0, 8.0), 0.9, i % 2 == 0))
	st.fov(40.0, 50.0)
	st.spline([
		[0.0, Vector3(1.6, 0.6, 18.4), Vector3(-8, 1.8, 13)],
		[3.2, Vector3(5.0, 3.6, 22.0), Vector3(-9, 2.2, 12)],
		[6.4, Vector3(9.0, 7.5, 26.0), Vector3(-11, 3.0, 9)],
	])
	st.slowmo(0.4, 3.0, 0.4, 0.3, 0.6)
	_squad_fire(st, squad, guns, horde)
	st.flare_at(func(): return PIER_SUN, SUN_COLOR, 0.5)
	_finale_titles(st)


## The squad opens fire into the front of the horde, a kill effect on each drop.
func _squad_fire(st: CineStage, squad: Array[Node3D], guns: Array[Node3D], horde: Array[Zombie]) -> void:
	for n in 12:
		var who := n % squad.size()
		var tgt := horde[n % horde.size()]
		st.at(0.15 + n * 0.22, func():
			if not is_instance_valid(tgt) or tgt.is_dead():
				return
			Operators.play(squad[who], "Fire", "AimIdle", 0.05)
			st.shoot(FINALE_GUNS[who], st.muzzle(guns[who]), st.chest(tgt), 1.0, n % 2 == 0, HERO_TRACER if who == 1 else &"")
			if n % 2 == 1:
				st.kill(tgt, FINALE_GUNS[who], n % 4 == 1, Vector3(-1, 0, 0), 4.0, FINALE_FX[(n / 2) % FINALE_FX.size()]))


func _finale_titles(st: CineStage) -> void:
	st.at(3.2, st.overlay.flash.bind(Color.WHITE, 0.45, 0.85))
	st.at(3.2, func(): st.overlay.logo(Vector2(0.5, 0.33), 150))
	st.shake(3.2, 0.08, 0.5)
	var counts := PackedStringArray([
		"%d WORLDS" % GameData.worlds().size(), "%d WEAPONS" % GameData.weapons().size(),
		"%d ZOMBIES" % GameData.enemies().size(), "%d ALPHAS" % _alpha_count(), "ENDLESS",
		"%d OPERATORS" % _operator_count(), "LAST RIDE"])
	st.at(3.5, st.overlay.chips.bind(counts, Vector2(0.5, 0.6), 0.08, [UiKit.CYAN, UiKit.PINK, UiKit.AMBER]))
	st.at(4.0, func(): st.overlay.marquee("PLAY NOW", 84, Vector2(0.5, 0.8)))
	st.at(5.6, st.overlay.fade.bind(1.0, 0.8))


## The score rings out on black under the tagline, which fades away.
func _ring_out(st: CineStage) -> void:
	st.at(0.0, st.overlay.fade.bind(0.0, 0.0))
	st.at(0.0, st.overlay.backdrop.bind(1.0))
	st.at(0.0, func():
		var l := st.overlay.caption("An arcade zombie survival", 1.0, UiKit.CREAM)
		l.position.y = st.overlay.root.size.y * 0.5 - l.size.y * 0.5)
	st.dolly(Vector3(0, 2, 10), Vector3.ZERO, Vector3(0, 2, 9), Vector3.ZERO)
