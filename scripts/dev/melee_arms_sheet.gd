extends RefCounted
## Arms and hands sheet (a --shot-run script for a level scene): one row per
## weapon (the four melee weapons and a gun for comparison), one column per
## action (idle, light swing, wind-up, heavy swing, inspect), cropped to the
## viewmodel, saved as <shot>. Checks the gloves, cuffs and forearms read the
## same in every action:
##
##   godot --path . --fixed-fps 30 -- --shot=arms.png --shot-scene=level --shot-zombies=0 --shot-hud=0 --shot-run=res://scripts/dev/melee_arms_sheet.gd [--shot-sheet-weapons=a,b]

const WEAPONS := "glow_blade,ticket_flipper,swirl_smasher,high_striker,ion_carbine"
## [label, kind, at]: kind idle | light | windup | heavy | inspect; at = progress, charge or seconds.
const CELLS := [
	["idle", "idle", 0.0],
	["light .3", "light", 0.3],
	["windup 1", "windup", 1.0],
	["heavy .12", "heavy", 0.12],
	["heavy .35", "heavy", 0.35],
	["inspect 1s", "inspect", 1.0],
]
const CELL := Vector2i(320, 240)
const CROP := Rect2(0.2, 0.1, 0.8, 0.9)


func run(shot: Node, director: RunDirector) -> void:
	var player := director.player
	player.invulnerable = true
	player.set_physics_process(true)
	player.controls_enabled = true
	var weapons: PackedStringArray = String(shot._arg("sheet-weapons", WEAPONS)).split(",", false)
	var sheet := Image.create(CELL.x * CELLS.size(), CELL.y * weapons.size(), false, Image.FORMAT_RGB8)
	for row in weapons.size():
		await _equip(shot, player, StringName(weapons[row]))
		for col in CELLS.size():
			var img := await _pose(shot, player, CELLS[col][1], float(CELLS[col][2]))
			if img:
				img.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(col * CELL.x, row * CELL.y))
	sheet.save_png(shot.path)
	print("[arms] saved %s (%d weapons)" % [shot.path, weapons.size()])


func _equip(shot: Node, player: Player, id: StringName) -> void:
	var w := player.weapons
	if w.current and w.current.id == id:
		return
	var slot := 1 if w.active_slot == 0 else 0
	w.slots[slot] = id
	w.switch_to_slot(slot)
	await shot._wait(int((w.current.equip_time + 0.8) * 30.0))


func _pose(shot: Node, player: Player, kind: String, at: float) -> Image:
	var w := player.weapons
	var view := player.view
	var melee := w.mode as MeleeMode
	if kind in ["light", "windup", "heavy"] and melee == null:
		return null
	match kind:
		"idle":
			await shot._wait(20)
		"inspect":
			if not view.inspect():
				return null
			while view.is_inspecting() and view._inspect.clock < at:
				await shot.get_tree().process_frame
		_:
			shot._press("aim" if kind != "light" else "fire", true)
			for i in 300:
				await shot.get_tree().physics_frame
				if kind == "heavy" and melee.phase == MeleeMode.Phase.WINDUP and melee.charge >= 1.0:
					shot._press("aim", false)
				if kind == "light" and melee.phase == MeleeMode.Phase.LIGHT:
					shot._press("fire", false)
				var phase := MeleeMode.Phase.WINDUP if kind == "windup" else (MeleeMode.Phase.LIGHT if kind == "light" else MeleeMode.Phase.HEAVY)
				var k := melee.charge if kind == "windup" else melee.progress()
				if melee.phase == phase and k >= at:
					break
	w.set_physics_process(false)
	await shot._wait(3)
	await RenderingServer.frame_post_draw
	var full := shot.get_viewport().get_texture().get_image()
	var size := Vector2(full.get_size())
	var img := full.get_region(Rect2i(Vector2i(CROP.position * size), Vector2i(CROP.size * size)))
	img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
	w.set_physics_process(true)
	shot._press("aim", false)
	shot._press("fire", false)
	if view.is_inspecting():
		view.cancel_inspect()
	await shot._wait(int(1.6 * 30.0))
	return img
