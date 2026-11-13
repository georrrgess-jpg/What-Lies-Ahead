class_name ShowreelShots
extends RefCounted
## The showreel's shot list (docs/SHOWREEL.md has the plan and its timing).
## Every shot is a method that stages one CineStage; build() returns them in
## order. Times inside a shot are its own seconds; the reel is locked to
## audio/music/showreel_trailer.ogg (120 BPM, a bar is 2 s), so lengths add
## up to the cuts in that track: 8 (title hit), 26 (drop), 62 and 66 (title
## card hits), 70 (end).
##
## Actors, levels and cosmetics are referenced by id, so the reel always shows
## the game's current models and effects.

const PIER := "prize_pier"
const NEON := "neon_skyline"
const TIDAL := "tidal_tunnels"
const DUNE := "launch_pad"
const FROST := "summit_lodge"
const STUDIO := "studio"

const WEAPONS: Array[StringName] = [&"pulse_pistol", &"ion_carbine", &"scatter_blaster", &"comet_cannon",
	&"arc_coil", &"bumper_lobber", &"cryo_beam", &"rail_lancer"]
## One showcase finish per weapon in the arsenal run (animated shader skins first).
const ARSENAL_FINISHES: Array[StringName] = [&"fin_galaxy", &"fin_lava", &"fin_holo_foil", &"fin_synthwave",
	&"fin_circuit", &"fin_bubblegum", &"fin_frostbite", &"fin_glitch"]
const SKIN_RUN: Array[StringName] = [&"fin_wireframe", &"fin_marble", &"mastery_prismatic", &"fin_comic",
	&"mastery_gold", &"fin_digicamo", &"mastery_diamond", &"fin_rainbow_swirl"]
const SIGHTS: Array[StringName] = [&"sight_holo_ring", &"sight_heart", &"sight_long_scope"]
const OPERATORS: Array[StringName] = [&"op_boardwalk_ranger", &"op_surf_rescue", &"op_neon_courier", &"op_deep_diver",
	&"op_glitch", &"op_astro_cadet", &"op_frost_guard", &"op_arcade_champion", &"op_midway_maestro"]
## The whole cast, in the order of the line-up (front first).
const CAST: Array[StringName] = [&"boardwalk_bruiser", &"riot_bruiser", &"frost_yeti", &"tourist_shambler",
	&"lifeguard_runner", &"neon_punk", &"hover_courier", &"deep_diver", &"mascot_inker", &"jelly_head",
	&"dune_space_cadet", &"dune_jet_mechanic", &"dune_hazmat_worker", &"frost_ski_racer", &"frost_frozen_tourist"]
const KILL_FX: Array[StringName] = [&"kfx_hearts", &"kfx_pixel", &"kfx_firework", &"kfx_coins", &"kfx_neon_ring", &"kfx_starburst"]


static func build() -> Array[CineShot]:
	var s := ShowreelShots.new()
	var list: Array[CineShot] = [
		# ACT I: cold open (0-8)
		CineShot.make("open_pier", PIER, 3.5, s._open_pier),
		CineShot.make("open_eyes", PIER, 2.5, s._open_eyes),
		CineShot.make("open_spark", PIER, 2.0, s._open_spark),
		# The title hit (8)
		CineShot.make("title", PIER, 2.0, s._title),
		# World tour (10-20)
		CineShot.make("world_pier", PIER, 2.0, s._world_pier),
		CineShot.make("world_neon", NEON, 2.0, s._world_neon),
		CineShot.make("world_tidal", TIDAL, 2.0, s._world_tidal),
		CineShot.make("world_dune", DUNE, 2.0, s._world_dune),
		CineShot.make("world_frost", FROST, 2.0, s._world_frost),
		# The cast (20-26)
		CineShot.make("cast_yeti", FROST, 2.0, s._cast_yeti),
		CineShot.make("cast_bruiser", PIER, 2.0, s._cast_bruiser),
		CineShot.make("cast_horde", PIER, 2.0, s._cast_horde),
		# ACT II: the drop, kills (26-40)
		CineShot.make("kill_headshot", PIER, 2.0, s._kill_headshot),
		CineShot.make("kill_sweep", PIER, 2.0, s._kill_sweep),
		CineShot.make("kill_cryo", PIER, 2.0, s._kill_cryo),
		CineShot.make("kill_arc", PIER, 2.0, s._kill_arc),
		CineShot.make("kill_rail", NEON, 2.0, s._kill_rail),
		CineShot.make("kill_lobber", NEON, 2.0, s._kill_lobber),
		CineShot.make("kill_alpha", NEON, 2.0, s._kill_alpha),
		# The arsenal (40-48)
		CineShot.make("arsenal", STUDIO, 4.0, s._arsenal),
		CineShot.make("skins", STUDIO, 2.0, s._skins),
		CineShot.make("sights", STUDIO, 2.0, s._sights),
		# Operators (48-56)
		CineShot.make("operators", STUDIO, 3.0, s._operators),
		CineShot.make("op_action", PIER, 3.0, s._op_action),
		CineShot.make("op_victory", PIER, 2.0, s._op_victory),
		# Sparks and progression (56-62)
		CineShot.make("sparks", PIER, 2.0, s._sparks),
		CineShot.make("progress", STUDIO, 4.0, s._progress),
		# ACT III: the title card (62-70)
		CineShot.make("finale", PIER, 8.0, s._finale),
	]
	return list


# --- helpers ------------------------------------------------------------------

func _world_of(level_id: String) -> WorldData:
	for w in GameData.worlds():
		for l in w.levels:
			if l and String(l.id) == level_id:
				return w
	return null


func _world_card(st: CineStage, level_id: String) -> void:
	var w := _world_of(level_id)
	var level := GameData.level(StringName(level_id))
	if w and level:
		st.at(0.15, st.overlay.name_card.bind(w.display_name, level.display_name, w.accent_color, 1.35))


func _enemy_name(id: StringName) -> String:
	var e := GameData.enemy(id)
	return e.display_name if e else String(id)


## A first-person weapon (with the operator's arms) that follows the camera.
func _viewmodel(st: CineStage, weapon_id: StringName, finish: StringName = &"") -> Node3D:
	var w := GameData.weapon(weapon_id)
	var model := w.viewmodel.instantiate() as Node3D
	WeaponCosmetics.prepare_preview(model, true)
	st.actors.add_child(model)
	var loadout := Cosmetics.weapon_loadout(weapon_id)
	if finish != &"":
		loadout["finish"] = Cosmetics.item(finish)
	WeaponCosmetics.apply(model, w, loadout)
	var kick := {"v": 0.0}
	model.set_meta(&"kick", kick)
	st.every_frame(func(_t: float):
		kick["v"] = move_toward(kick["v"], 0.0, 0.016 * 6.0)
		var offset := Transform3D(Basis.from_euler(Vector3(deg_to_rad(w.view_rotation_degrees.x + kick["v"] * 6.0), deg_to_rad(w.view_rotation_degrees.y), deg_to_rad(w.view_rotation_degrees.z))),
			w.view_position + Vector3(0, 0, kick["v"] * 0.08))
		model.global_transform = st.camera.global_transform * offset)
	return model


## Recoil on a viewmodel made by _viewmodel().
func _kick(model: Node3D) -> void:
	var k: Dictionary = model.get_meta(&"kick")
	k["v"] = 1.0


func _fire_from(st: CineStage, model: Node3D, weapon_id: StringName, to: Vector3, power := 1.0) -> void:
	_kick(model)
	st.shoot(weapon_id, st.muzzle(model), to, power)


# --- ACT I: cold open ------------------------------------------------------------

func _open_pier(st: CineStage) -> void:
	st.overlay.bars(1.0, 0.0)
	st.overlay.fade(1.0, 0.0)
	st.overlay.fade(0.0, 1.2)
	st.fov(46.0, 42.0)
	st.dolly(Vector3(24, 1.5, 9), Vector3(-12, 3.0, -9), Vector3(16, 1.2, 6.5), Vector3(-14, 3.2, -10), 1.0)
	st.walker(&"tourist_shambler", Vector3(-4, 0, -2), 70.0, 0.55)
	st.walker(&"tourist_shambler", Vector3(-9, 0, 1), 95.0, 0.5)
	st.at(0.9, st.overlay.slide.bind("THE PIER WAS QUIET.", 46, UiKit.CREAM, Vector2(0.5, 0.78), 1.8))


func _open_eyes(st: CineStage) -> void:
	var z := st.zombie(&"tourist_shambler", Vector3(6, 0, 12), 90.0, "Idle", 0.6)
	var face := st.head(z) + Vector3(0.1, -0.05, 0)
	st.fov(32.0, 27.0)
	st.dolly(face + Vector3(3.4, 0.1, 0.9), face + Vector3(0, -0.12, 0), face + Vector3(2.4, 0.05, 0.6), face + Vector3(0, -0.05, 0), -1.4)
	var glow := st.light(face + Vector3(0.55, 0.0, 0.0), Wallet.COLOR_GLOW, 0.0, 1.6)
	st.light(face + Vector3(-0.9, 0.6, -0.8), UiKit.PINK, 1.6, 4.0)
	st.at(1.5, func():
		WeaponFx.flash(st.actors, face + Vector3(0.2, 0.02, 0), Wallet.COLOR_GLOW, 0.12, 0.35)
		st.actors.create_tween().tween_property(glow, "light_energy", 1.2, 0.25))
	st.at(1.6, st.play.bind(z, "Roar", 0.8, 0.0, 0.2))


func _open_spark(st: CineStage) -> void:
	var z := st.walker(&"tourist_shambler", Vector3(5, 0, 12.5), 80.0, 0.6)
	st.walker(&"lifeguard_runner", Vector3(-1, 0, 10.5), 85.0, 0.5)
	st.walker(&"tourist_shambler", Vector3(-4, 0, 15), 95.0, 0.45)
	var eye := Vector3(12.5, 0.45, 14.2)
	st.fov(40.0, 34.0)
	st.dolly(eye, Vector3(4, 1.7, 12.5), eye + Vector3(-0.8, 0.1, 0), Vector3(5, 1.8, 12.8))
	var field := SparkField.new()
	st.actors.add_child(field)
	field.global_position = eye + Vector3(-0.5, 0.0, 0.0)
	st.at(0.9, func(): field.drop(st.head(z), 5))
	st.at(1.75, st.overlay.flash.bind(Color.WHITE, 0.6, 1.0))


# --- the title -----------------------------------------------------------------

func _title(st: CineStage) -> void:
	st.overlay.logo(Vector2(0.5, 0.42), 150)
	st.shake(0.0, 0.12, 0.5)
	st.at(1.75, st.overlay.clear_text.bind(0.2))
	st.fov(55.0, 50.0)
	st.dolly(Vector3(12.5, 0.8, 13.5), Vector3(-2, 1.6, 11), Vector3(15, 6.0, 15.5), Vector3(-4, 1.0, 9), -1.8)
	var spots := [Vector3(-2, 0, 12), Vector3(1, 0, 9.5), Vector3(-5, 0, 10), Vector3(3, 0, 14), Vector3(-7, 0, 14), Vector3(-3, 0, 16.5), Vector3(-10, 0, 11), Vector3(5, 0, 10)]
	var kinds := [&"tourist_shambler", &"lifeguard_runner", &"tourist_shambler", &"boardwalk_bruiser", &"tourist_shambler", &"lifeguard_runner", &"tourist_shambler", &"tourist_shambler"]
	for i in spots.size():
		st.walker(kinds[i], spots[i], 50.0 + 10.0 * (i % 3), 0.7)


# --- world tour ------------------------------------------------------------------

func _world_pier(st: CineStage) -> void:
	_world_card(st, PIER)
	st.fov(48.0, 44.0)
	st.dolly(Vector3(-6, 1.6, -2), Vector3(-34, 10, -29), Vector3(-11, 3.6, -7), Vector3(-34, 11, -29))
	st.walker(&"tourist_shambler", Vector3(-15, 0, -10), 60.0, 0.7)


func _world_neon(st: CineStage) -> void:
	_world_card(st, NEON)
	var l := GameData.level(&"neon_skyline")
	st.fov(50.0, 46.0)
	st.dolly(l.menu_camera_from, l.menu_camera_to, l.menu_camera_from.lerp(l.menu_camera_to, 0.18) + Vector3(0, -1.5, 0), l.menu_camera_to + Vector3(2, 0, 0))
	for i in 3:
		st.walker(&"neon_punk", Vector3(4 + i * 2.2, 0, 4 + i), 200.0, 0.8)


func _world_tidal(st: CineStage) -> void:
	_world_card(st, TIDAL)
	var l := GameData.level(&"tidal_tunnels")
	st.fov(58.0, 54.0)
	st.dolly(l.menu_camera_from, l.menu_camera_to, l.menu_camera_from + (l.menu_camera_to - l.menu_camera_from).normalized() * 2.5, l.menu_camera_to + Vector3(-1.5, 0, 0))


func _world_dune(st: CineStage) -> void:
	_world_card(st, DUNE)
	st.fov(52.0, 48.0)
	st.dolly(Vector3(7, 1.4, 12), Vector3(0, 8, -9), Vector3(9, 3.0, 14.5), Vector3(0, 17, -9))
	st.walker(&"dune_space_cadet", Vector3(2, 0, 5), 160.0, 0.8)
	st.walker(&"dune_hazmat_worker", Vector3(-2, 0, 3), 170.0, 0.8)


func _world_frost(st: CineStage) -> void:
	_world_card(st, FROST)
	var l := GameData.level(&"summit_lodge")
	st.fov(50.0, 46.0)
	st.dolly(l.menu_camera_from, l.menu_camera_to, l.menu_camera_from.lerp(l.menu_camera_to, 0.15), l.menu_camera_to + Vector3(0, 1.5, 0))


# --- the cast --------------------------------------------------------------------

func _cast_yeti(st: CineStage) -> void:
	var z := st.zombie(&"frost_yeti", Vector3(3, 0, 8), 10.0, "Idle", 1.0, true)
	st.fov(44.0, 40.0)
	st.dolly(Vector3(3.6, 0.5, 13.5), Vector3(3, 2.0, 8), Vector3(3.5, 0.45, 12.4), Vector3(3, 2.3, 8))
	st.at(0.85, func():
		st.play(z, "Roar", 1.0, 0.0, 0.15)
		Sfx.play_at(&"bruiser_roar_1", st.head(z), 2.0, 0.8))
	st.shake(0.95, 0.06, 0.5)
	st.at(0.2, st.overlay.name_card.bind(_enemy_name(&"frost_yeti"), "Frostpeak Resort", Color("8fd8ff"), 1.5, true))


func _cast_bruiser(st: CineStage) -> void:
	var z := st.walker(&"boardwalk_bruiser", Vector3(-12, 0, -13), 75.0, 1.0)
	st.walker(&"tourist_shambler", Vector3(-15, 0, -15.5), 70.0, 0.8)
	st.walker(&"lifeguard_runner", Vector3(-14, 0, -10.5), 80.0, 0.9)
	st.fov(36.0, 40.0)
	st.track(func(k: float) -> Transform3D:
		var at := z.global_position if is_instance_valid(z) else Vector3.ZERO
		var from := at + Vector3(4.6 - k * 0.8, 0.6, 1.8)
		return Transform3D(Basis.looking_at(at + Vector3(0, 1.8, 0) - from), from))
	st.at(0.2, st.overlay.name_card.bind(_enemy_name(&"boardwalk_bruiser"), "Boardwalk Breakout", UiKit.AMBER, 1.5))
	st.at(1.1, func(): Sfx.play_at(&"bruiser_roar_2", st.head(z), 0.0, 1.0))


func _cast_horde(st: CineStage) -> void:
	st.slowmo(0.0, 2.0, 0.55)
	var i := 0
	for row in 5:
		for col in 3:
			if i >= CAST.size():
				break
			var x := -9.0 - row * 2.2
			var z := -13.0 + (col - 1) * 2.0 + (row % 2) * 0.8
			st.walker(CAST[i], Vector3(x, 0, z), 90.0, 0.9)
			i += 1
	st.fov(40.0, 46.0)
	st.dolly(Vector3(-1.5, 0.9, -12.5), Vector3(-13, 1.6, -12.6), Vector3(0.5, 1.3, -12.0), Vector3(-13, 1.7, -12.6))
	st.at(0.1, st.overlay.slam.bind("%d KINDS OF TROUBLE" % GameData.enemies().size(), 96, Color.WHITE, Vector2(0.5, 0.2), 1.6, -2.0))


# --- ACT II: kills -----------------------------------------------------------------

func _kill_headshot(st: CineStage) -> void:
	st.overlay.flash(Color.WHITE, 0.4, 1.0)
	var z := st.zombie(&"tourist_shambler", Vector3(-6, 0, 14), 20.0, "Walk", 0.6)
	var head := st.head(z)
	st.fov(36.0, 32.0)
	st.dolly(head + Vector3(0.6, -0.15, 3.4), head + Vector3(-0.2, -0.1, 0), head + Vector3(0.3, -0.05, 3.0), head + Vector3(-0.3, 0.0, 0))
	st.slowmo(0.3, 1.9, 0.3)
	st.at(0.3, func():
		st.shoot(&"pulse_pistol", head + Vector3(9, -0.2, 0.6), head)
		st.kill(z, &"pulse_pistol", true, Vector3(-1, 0, 0)))
	st.at(0.45, st.overlay.slam.bind("HEADSHOT!", 130, UiKit.AMBER, Vector2(0.5, 0.25), 1.0, -4.0))
	st.at(0.35, func(): Sfx.play(&"headshot_ping", -2.0))


func _kill_sweep(st: CineStage) -> void:
	var eye := Vector3(2, 1.6, -13)
	var targets: Array[Zombie] = []
	for i in 5:
		var a := deg_to_rad(-40.0 + i * 20.0)
		var p := eye + Vector3(-cos(a), 0, sin(a)) * (7.0 + (i % 2) * 1.5)
		p.y = 0.0
		targets.append(st.walker(&"tourist_shambler" if i % 2 == 0 else &"lifeguard_runner", p, rad_to_deg(atan2(eye.x - p.x, eye.z - p.z)), 0.8))
	var gun := _viewmodel(st, &"ion_carbine", &"fin_neon_camo")
	st.fov(62.0)
	st.track(func(k: float) -> Transform3D:
		var a := deg_to_rad(lerpf(-46.0, 46.0, ease(clampf((k - 0.1) / 0.75, 0.0, 1.0), -1.3)))
		var look := eye + Vector3(-cos(a), -0.08, sin(a))
		return Transform3D(Basis.looking_at(look - eye), eye))
	for i in 5:
		var z := targets[i]
		st.at(0.3 + i * 0.27, func():
			_fire_from(st, gun, &"ion_carbine", st.chest(z))
			st.kill(z, &"ion_carbine", i == 4, (st.chest(z) - eye).normalized(), 5.0, KILL_FX[i])
			Sfx.play(&"kill_confirm", -4.0))
	st.at(1.25, st.overlay.slam.bind("MULTI-KILL ×5", 110, UiKit.PINK, Vector2(0.5, 0.24), 0.6, 3.0))


func _kill_cryo(st: CineStage) -> void:
	var cryo := GameData.weapon(&"cryo_beam")
	var zs: Array[Zombie] = []
	for i in 3:
		zs.append(st.zombie(&"tourist_shambler" if i != 1 else &"boardwalk_bruiser", Vector3(-4.5 - i * 1.6, 0, 13.0 + 1.2 * i), 100.0, "Walk", 0.7))
	var muzzle := Vector3(3.5, 1.3, 16.5)
	var beam := BeamVisual.new()
	beam.color = cryo.tracer_color
	beam.width = 0.1
	st.actors.add_child(beam)
	st.fov(44.0, 40.0)
	st.dolly(Vector3(0.5, 1.4, 20.5), Vector3(-6, 1.2, 14), Vector3(-0.2, 1.3, 19.6), Vector3(-6.2, 1.1, 14))
	st.every_frame(func(t: float):
		var k := clampi(int((t - 0.15) / 0.3), 0, 2)
		beam.aim(muzzle, st.chest(zs[k]) if is_instance_valid(zs[k]) else muzzle, t > 0.1 and t < 1.15))
	for i in 3:
		st.at(0.3 + i * 0.3, func(): StatusEffects.of(zs[i]).apply(cryo, 9.0))
	st.at(0.12, func(): Sfx.play(cryo.fire_sound, -4.0))
	st.at(1.3, func():
		for i in 3:
			st.kill(zs[i], &"cryo_beam", false, Vector3(-1, 0, 0), 2.0))
	st.shake(1.3, 0.07, 0.4)
	st.at(0.5, st.overlay.slam.bind("FREEZE", 110, Color("9fe4ff"), Vector2(0.3, 0.24), 0.65, -3.0))
	st.at(1.3, st.overlay.slam.bind("SHATTER!", 120, Color.WHITE, Vector2(0.66, 0.26), 0.55, 3.0))


func _kill_arc(st: CineStage) -> void:
	var arc := GameData.weapon(&"arc_coil")
	var zs: Array[Zombie] = []
	var spots := [Vector3(-6, 0, -11), Vector3(-8.2, 0, -12.6), Vector3(-7.4, 0, -15.6), Vector3(-10.2, 0, -14.4), Vector3(-11, 0, -10.8)]
	for p in spots:
		zs.append(st.zombie(&"tourist_shambler" if zs.size() % 2 == 0 else &"lifeguard_runner", p, 95.0, "Walk", 0.6))
	var muzzle := Vector3(0.5, 1.35, -10.0)
	st.fov(50.0, 46.0)
	st.dolly(Vector3(-2.5, 2.4, -7.5), Vector3(-8.5, 0.9, -13), Vector3(-3.0, 2.0, -8.2), Vector3(-8.6, 0.9, -13))
	st.at(0.3, func():
		Sfx.play(arc.fire_sound, -3.0)
		LightningBolt.spawn(st.actors, muzzle, st.chest(zs[0]), arc.tracer_color, 0.09, 0.3, 0.3))
	for i in zs.size():
		st.at(0.3 + i * 0.09, func():
			if i > 0:
				LightningBolt.spawn(st.actors, st.chest(zs[i - 1]), st.chest(zs[i]), arc.tracer_color, 0.07, 0.3, 0.25)
				Sfx.play_at(arc.chain_sound, st.chest(zs[i]), -4.0)
			WeaponFx.shock_crackle(zs[i]))
		st.at(0.75 + i * 0.06, st.kill.bind(zs[i], &"arc_coil", false, Vector3(-1, 0, 0), 3.0))
	st.at(0.45, st.overlay.slam.bind("CHAIN LIGHTNING", 104, arc.tracer_color, Vector2(0.5, 0.22), 1.0, -2.0))


func _kill_rail(st: CineStage) -> void:
	var rail := GameData.weapon(&"rail_lancer")
	var zs: Array[Zombie] = []
	for i in 4:
		zs.append(st.zombie(&"neon_punk" if i % 2 == 0 else &"riot_bruiser" if i == 1 else &"hover_courier", Vector3(-2 - i * 2.2, 0, 2 + i * 0.15), 90.0, "Walk", 0.7))
	var muzzle := Vector3(6, 1.25, 2.2)
	st.fov(38.0, 34.0)
	st.dolly(Vector3(3.5, 0.7, 5.6), Vector3(-5, 1.2, 2), Vector3(3.0, 0.65, 5.0), Vector3(-5, 1.2, 2.2))
	var charge := st.light(muzzle, rail.tracer_color, 0.0, 4.0)
	st.actors.create_tween().tween_property(charge, "light_energy", 6.0, 0.6)
	st.at(0.0, func(): Sfx.play(rail.charge_sound, -4.0))
	st.slowmo(0.62, 1.7, 0.35)
	st.at(0.62, func():
		charge.light_energy = 0.0
		st.shoot(&"rail_lancer", muzzle, st.chest(zs[3]) + Vector3(-6, 0, 0.3), 1.0)
		for i in 4:
			st.kill(zs[i], &"rail_lancer", false, Vector3(-1, 0, 0), 7.0))
	st.shake(0.62, 0.08, 0.4)
	st.at(0.7, st.overlay.slam.bind("PIERCE", 140, rail.tracer_color.lerp(Color.WHITE, 0.3), Vector2(0.5, 0.26), 1.0, -3.0))


func _kill_lobber(st: CineStage) -> void:
	var lob := GameData.weapon(&"bumper_lobber")
	var zs: Array[Zombie] = []
	var centre := Vector3(-3, 0, 1)
	for i in 5:
		var a := TAU * float(i) / 5.0
		zs.append(st.zombie(&"neon_punk" if i % 2 else &"tourist_shambler", centre + Vector3(cos(a), 0, sin(a)) * 1.4, 90.0 + i * 30.0, "Walk", 0.8))
	st.fov(46.0, 42.0)
	st.dolly(Vector3(5, 2.2, 7.5), centre + Vector3(0, 0.8, 0), Vector3(4.2, 1.6, 6.6), centre + Vector3(0, 1.0, 0))
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	var m := StandardMaterial3D.new()
	m.albedo_color = lob.tracer_color
	m.emission_enabled = true
	m.emission = lob.tracer_color
	m.emission_energy_multiplier = 2.0
	sphere.material = m
	ball.mesh = sphere
	st.actors.add_child(ball)
	var start := Vector3(7, 1.4, 3.5)
	st.every_frame(func(t: float):
		var k := clampf((t - 0.05) / 0.6, 0.0, 1.0)
		ball.visible = k > 0.0 and k < 1.0
		ball.global_position = start.lerp(centre + Vector3(0, 0.3, 0), k) + Vector3.UP * sin(k * PI) * 2.6)
	st.at(0.05, func(): Sfx.play(lob.fire_sound, -3.0))
	st.at(0.65, func():
		WeaponFx.explosion(st.actors, centre + Vector3(0, 0.4, 0), lob.tracer_color, 2.6)
		Sfx.play(lob.explosion_sound, 0.0)
		for z in zs:
			st.kill(z, &"bumper_lobber", false, (z.global_position - centre).normalized() + Vector3.UP * 0.3, 9.0))
	st.shake(0.65, 0.14, 0.5)
	st.at(0.7, st.overlay.slam.bind("BOOM!", 160, lob.tracer_color.lerp(Color.WHITE, 0.25), Vector2(0.5, 0.25), 0.9, 4.0))


func _kill_alpha(st: CineStage) -> void:
	var z := st.walker(&"riot_bruiser", Vector3(-6, 0, 2), 90.0, 0.8)
	z.scale = Vector3.ONE * 1.45
	st.move(z, Vector3.ZERO, 1.0)
	var muzzle := Vector3(7, 1.5, 3.4)
	st.fov(40.0, 36.0)
	st.track(func(k: float) -> Transform3D:
		var at := z.global_position if is_instance_valid(z) else Vector3(-4, 0, 2)
		var from := at + Vector3(5.6 - k * 0.6, 0.5, 3.2)
		return Transform3D(Basis.looking_at(at + Vector3(0, 2.4, 0) - from), from))
	for i in 5:
		st.at(0.12 + i * 0.16, func():
			var to := st.chest(z) + Vector3(0, 0.6, 0) * z.scale.y
			st.shoot(&"comet_cannon", muzzle, to)
			st.hit(z, &"comet_cannon", 1.0, to, to - muzzle))
	st.at(0.25, st.overlay.name_card.bind("ALPHA " + _enemy_name(&"riot_bruiser"), "Boss wave", UiKit.RED, 0.9, true))
	st.slowmo(0.95, 2.0, 0.4)
	st.at(0.95, func():
		st.shoot(&"rail_lancer", muzzle, st.chest(z) + Vector3(0, 0.5, 0))
		st.kill(z, &"rail_lancer", false, Vector3(-1, 0, 0), 4.0, &"kfx_firework"))
	st.shake(1.45, 0.16, 0.5)
	st.at(1.15, st.overlay.slam.bind("ALPHA DOWN!", 120, UiKit.AMBER, Vector2(0.5, 0.24), 0.65, -3.0))


# --- the arsenal -----------------------------------------------------------------

func _turntable(st: CineStage, model: Node3D, height := 1.25, span := 1.3) -> Node3D:
	var pivot := Node3D.new()
	st.actors.add_child(pivot)
	pivot.position = Vector3(0, height, 0)
	pivot.add_child(model)
	var box := WeaponCosmetics.visible_bounds(model)
	model.position = -box.get_center()
	pivot.scale = Vector3.ONE * span / maxf(0.01, maxf(box.size.x, maxf(box.size.y, box.size.z)))
	return pivot


func _arsenal(st: CineStage) -> void:
	st.overlay.wipe(0.4)
	var pivots: Array[Node3D] = []
	for i in WEAPONS.size():
		var p := _turntable(st, st.weapon(WEAPONS[i], ARSENAL_FINISHES[i]), 1.3, 1.55)
		p.visible = i == 0
		pivots.append(p)
	st.fov(36.0, 34.0)
	st.dolly(Vector3(0.4, 1.55, 3.1), Vector3(0, 1.2, 0), Vector3(-0.3, 1.45, 2.7), Vector3(0, 1.22, 0))
	st.every_frame(func(t: float):
		var k := clampi(int(t / 0.5), 0, pivots.size() - 1)
		for i in pivots.size():
			pivots[i].visible = i == k
		pivots[k].rotation.y = deg_to_rad(-70.0 + fmod(t, 0.5) * 120.0))
	st.at(0.05, st.overlay.slam.bind("%d WEAPONS" % GameData.weapons().size(), 110, Color.WHITE, Vector2(0.5, 0.17), 3.6, -2.0))
	for i in WEAPONS.size():
		var w := GameData.weapon(WEAPONS[i])
		var fin := Cosmetics.item(ARSENAL_FINISHES[i])
		st.at(i * 0.5 + 0.02, st.overlay.slide.bind("%s  ·  %s" % [w.display_name.to_upper(), fin.display_name.to_upper() if fin else ""], 44, w.tracer_color.lerp(Color.WHITE, 0.3), Vector2(0.5, 0.8), 0.32, i % 2 == 1))
		st.at(i * 0.5 + 0.02, func(): Sfx.play(&"ui_whoosh", -10.0, 1.2))


func _skins(st: CineStage) -> void:
	var model := st.weapon(&"ion_carbine", SKIN_RUN[0], &"charm_duck")
	var pivot := _turntable(st, model, 1.2, 1.5)
	st.fov(30.0, 26.0)
	st.orbit(Vector3(0, 1.2, 0), 2.6, 0.35, -30.0, 25.0, Vector3.ZERO, -1.2)
	st.every_frame(func(t: float): pivot.rotation.z = sin(t * 7.0) * 0.12)
	for i in range(1, SKIN_RUN.size()):
		st.at(i * 0.25, func():
			st.reskin(model, &"ion_carbine", SKIN_RUN[i])
			st.overlay.flash(Color.WHITE, 0.1, 0.25))
	st.at(0.05, st.overlay.slam.bind("%d COSMETICS" % GameData.cosmetics().size(), 110, UiKit.PINK, Vector2(0.5, 0.17), 1.6, 2.0))
	st.at(0.6, st.overlay.slide.bind("ANIMATED SKINS · MASTERY CAMOS · CHARMS", 38, UiKit.CREAM, Vector2(0.5, 0.82), 1.1))


func _sights(st: CineStage) -> void:
	var models: Array[Node3D] = []
	for i in SIGHTS.size():
		var m := st.weapon(&"comet_cannon", &"fin_midnight", &"", SIGHTS[i])
		st.actors.add_child(m)
		m.global_transform = Transform3D(Basis.IDENTITY.rotated(Vector3.UP, deg_to_rad(18.0)), Vector3(0, 1.25, 0))
		m.scale = Vector3.ONE * 2.2
		m.visible = i == 0
		models.append(m)
	st.fov(32.0, 26.0)
	st.dolly(Vector3(1.5, 1.6, 0.9), Vector3(0, 1.38, -0.15), Vector3(1.15, 1.55, 0.6), Vector3(0, 1.4, -0.15))
	st.every_frame(func(t: float):
		var k := clampi(int(t / 0.67), 0, models.size() - 1)
		for i in models.size():
			models[i].visible = i == k)
	for i in range(1, SIGHTS.size()):
		st.at(i * 0.67, func(): Sfx.play(&"weap_switch", -6.0))
	st.at(0.05, st.overlay.slide.bind("SWAP YOUR SIGHTS", 72, UiKit.CYAN, Vector2(0.5, 0.18), 1.7))


# --- operators -------------------------------------------------------------------

func _operators(st: CineStage) -> void:
	st.overlay.wipe(0.4)
	var ops: Array[Node3D] = []
	for i in OPERATORS.size():
		var x := (i - 4) * 1.15
		var op := st.operator(OPERATORS[i], Vector3(x, 0.0 if absf(x) > 1.1 else 0.42, -absf(x) * 0.35), -x * 4.0)
		ops.append(op)
		st.at(0.15 + i * 0.12, func(): Operators.play(op, "Pose"))
	st.fov(40.0, 38.0)
	st.dolly(Vector3(-4.8, 1.3, 4.2), Vector3(-2.5, 1.2, 0), Vector3(4.8, 1.25, 4.4), Vector3(2.5, 1.2, 0), -1.2)
	st.at(0.1, st.overlay.slam.bind("%d OPERATORS" % OPERATORS.size(), 120, Color.WHITE, Vector2(0.5, 0.17), 2.6, -2.0))


func _op_action(st: CineStage) -> void:
	var op := st.operator(&"op_glitch", Vector3(8, 0, 16), -90.0, "Run")
	var gun := st.weapon(&"ion_carbine", &"fin_synthwave")
	Operators.hold_weapon(op, gun)
	st.move(op, Vector3(-Operators.RUN_SPEED, 0, 0), 0.0, 1.5)
	var target := st.walker(&"tourist_shambler", Vector3(-8, 0, 15.4), 90.0, 0.8)
	st.walker(&"lifeguard_runner", Vector3(-10, 0, 17.6), 90.0, 0.7)
	st.at(1.5, Operators.play.bind(op, "AimIdle", "", 0.2))
	st.fov(46.0, 42.0)
	st.track(func(k: float) -> Transform3D:
		var at := op.global_position
		var side := lerpf(3.4, 2.4, ease(k, -1.5))
		var from := at + Vector3(-1.4 + k * 2.6, 1.5, side)
		return Transform3D(Basis.looking_at(at + Vector3(-1.6, 1.15, 0) - from), from))
	for i in 3:
		st.at(1.9 + i * 0.18, func():
			Operators.play(op, "Fire", "AimIdle", 0.05)
			st.shoot(&"ion_carbine", st.muzzle(gun), st.chest(target) if i < 2 else st.head(target)))
	st.at(2.28, st.kill.bind(target, &"ion_carbine", true, Vector3(-1, 0, 0), 4.0, &"kfx_pixel"))
	st.at(0.3, st.overlay.name_card.bind("PLAY IT YOUR WAY", "Third-person operators", UiKit.CYAN, 1.6))


func _op_victory(st: CineStage) -> void:
	var line := [[&"op_arcade_champion", "Victory"], [&"op_surf_rescue", "Wave"], [&"op_astro_cadet", "Pose"]]
	for i in line.size():
		var op := st.operator(line[i][0], Vector3(-6 + i * 1.3, 0, 13 + absf(i - 1) * 0.5), 70.0, "Idle")
		st.at(0.1 + i * 0.12, Operators.play.bind(op, line[i][1]))
	st.fov(40.0, 44.0)
	st.dolly(Vector3(-1.6, 0.55, 16.4), Vector3(-4.7, 1.5, 13.2), Vector3(-1.2, 0.75, 17.0), Vector3(-4.7, 1.4, 13.2))
	for i in 3:
		st.at(0.4 + i * 0.35, func(): Fx.confetti(st.actors, Vector3(-6.0 + i * 1.3, 2.6, 13.0)))


# --- Sparks and progression ------------------------------------------------------

func _sparks(st: CineStage) -> void:
	var eye := Vector3(12.5, 1.55, 12.0)
	var look := Vector3(0, 1.4, 0)
	st.fov(54.0, 50.0)
	st.dolly(eye, look, eye + Vector3(-0.6, 0.1, -0.4), look)
	var field := SparkField.new()
	st.actors.add_child(field)
	field.global_position = eye + (look - eye).normalized() * 0.8 + Vector3(0, -0.25, 0)
	var spots := [Vector3(6.5, 0, 6), Vector3(4.5, 0, 8.4), Vector3(8.2, 0, 4.2), Vector3(9, 0, 7.6), Vector3(6, 0, 10)]
	for i in spots.size():
		var z := st.zombie(&"tourist_shambler" if i % 2 else &"lifeguard_runner", spots[i], 60.0, "Walk", 0.7)
		st.at(0.15 + i * 0.12, func():
			st.kill(z, &"ion_carbine", false, Vector3(-1, 0, -0.3), 3.0)
			field.drop(st.chest(z), 5)
			Sfx.play(&"eco_spark_tick", -6.0, 1.0 + i * 0.05))
	st.at(0.2, st.overlay.spark_counter.bind(1240, 1365, 1.4, Vector2(0.5, 0.2)))
	st.at(0.4, st.overlay.slide.bind("EVERY ZOMBIE STOLE A SPARK. TAKE IT BACK.", 40, UiKit.CREAM, Vector2(0.5, 0.82), 1.3))
	st.at(1.95, st.overlay.clear_text.bind(0.05))


func _progress(st: CineStage) -> void:
	st.overlay.wipe(0.4)
	var op := st.operator(&"op_midway_maestro", Vector3(0, 0.42, 0), 0.0, "Victory")
	st.fov(38.0, 34.0)
	st.orbit(Vector3(0, 0.42, 0), 4.2, 1.4, -35.0, 35.0, Vector3(0, 1.1, 0), -1.2)
	st.at(1.8, Operators.play.bind(op, "Wave"))
	var cards := [["LEVEL UP!", "Player level 12", UiKit.AMBER, &"icon_star", &"prog_level_up"],
		["RANK UP", "Gold mastery", Color("ffd84a"), &"icon_star", &"prog_rank_gold"],
		["NEW UNLOCK", "Galaxy finish", UiKit.PINK, &"icon_check", &"unlock"],
		["CHALLENGE COMPLETE", "50 headshots", UiKit.CYAN, &"icon_check", &"prog_challenge"]]
	for i in cards.size():
		var c: Array = cards[i]
		var at := Vector2(0.3 if i % 2 == 0 else 0.7, 0.42 + (i % 2) * 0.12)
		st.at(0.05 + i * 1.0, func():
			st.overlay.reward_card(c[0], c[1], c[2], 0.62, at, c[3])
			Sfx.play(c[4], -4.0)
			Fx.confetti(st.actors, Vector3(0, 2.4, 0)))


# --- ACT III: the title card -------------------------------------------------------

func _finale(st: CineStage) -> void:
	st.overlay.flash(Color.WHITE, 0.5, 1.0)
	st.overlay.bars(0.0, 1.0)
	var ops := [&"op_boardwalk_ranger", &"op_glitch", &"op_frost_guard"]
	var guns := [&"scatter_blaster", &"ion_carbine", &"rail_lancer"]
	for i in ops.size():
		var op := st.operator(ops[i], Vector3(-2 + i * 1.2, 0, 15 + absf(i - 1) * 0.7), -100.0, "AimIdle")
		Operators.hold_weapon(op, st.weapon(guns[i], ARSENAL_FINISHES[i * 2]))
	for i in 10:
		st.walker(CAST[i % CAST.size()], Vector3(-11 - (i % 4) * 2.0, 0, 12 + (i / 4) * 2.5 + (i % 2)), 90.0, 0.5)
	st.fov(46.0, 52.0)
	st.dolly(Vector3(6, 1.2, 12.5), Vector3(-6, 1.6, 15), Vector3(14, 6.5, 10), Vector3(-9, 2.0, 13), -1.5)
	st.at(0.0, func(): st.overlay.logo(Vector2(0.5, 0.33), 150))
	var counts := PackedStringArray([
		"%d WORLDS" % GameData.worlds().size(), "%d WEAPONS" % GameData.weapons().size(),
		"%d ZOMBIES" % GameData.enemies().size(), "%d OPERATORS" % OPERATORS.size(),
		"%d COSMETICS" % GameData.cosmetics().size()])
	st.at(1.0, st.overlay.chips.bind(counts, Vector2(0.5, 0.6), 0.14, [UiKit.CYAN, UiKit.PINK, UiKit.AMBER, UiKit.CYAN, UiKit.PINK]))
	st.at(4.0, func():
		st.overlay.marquee("PLAY NOW", 84, Vector2(0.5, 0.8))
		st.overlay.flash(Color.WHITE, 0.3, 0.5))
	st.at(6.6, st.overlay.fade.bind(1.0, 1.3))
