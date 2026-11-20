extends RefCounted
## High Striker framing stills (a --shot-run script for a level scene): draws
## the mallet and saves one full-frame PNG per action and field of view as
## <dir>/<tag>_fov<N>_<state>.png, where <dir> and <tag> come from --shot=<dir>/<tag>.png,
## plus a contact sheet per field of view (<dir>/<tag>_fov<N>_sheet.png).
## Run once per window size (aspect ratio):
##
##   godot --path . --resolution 1920x1080 --fixed-fps 30 -- --shot=/tmp/h/16x9.png --shot-scene=level --shot-zombies=0 --shot-hud=0 --shot-run=res://scripts/dev/hammer_frames.gd [--shot-fovs=72,60,100] [--shot-states=idle,light_30]
##   [--shot-other-states=idle] (the states drawn at the fields of view after the first)

const WEAPON := &"high_striker"
## [name, kind, at]: kind idle | light | windup | heavy | equip | inspect; at = progress, charge or seconds.
const STATES := [
	["idle", "idle", 0.0],
	["light_15", "light", 0.15],
	["light_30", "light", 0.3],
	["light_45", "light", 0.45],
	["light_60", "light", 0.6],
	["light_80", "light", 0.8],
	["windup_50", "windup", 0.5],
	["windup_100", "windup", 1.0],
	["heavy_10", "heavy", 0.1],
	["heavy_impact", "heavy", -1.0],
	["heavy_30", "heavy", 0.3],
	["recovery_55", "heavy", 0.55],
	["recovery_80", "heavy", 0.8],
	["equip_10", "equip", 0.1],
	["equip_30", "equip", 0.3],
	["equip_50", "equip", 0.5],
	["inspect_06", "inspect", 0.6],
	["inspect_12", "inspect", 1.2],
	["inspect_18", "inspect", 1.8],
	["inspect_24", "inspect", 2.4],
]
## Width of a contact sheet cell (pixels; its height keeps the frame's aspect).
const CELL_W := 480
const COLUMNS := 5


func run(shot: Node, director: RunDirector) -> void:
	var player := director.player
	player.invulnerable = true
	player.set_physics_process(true)
	player.controls_enabled = true
	var base: String = shot.path.get_basename()
	var fovs := String(shot._arg("fovs", "72")).split(",", false)
	var only := String(shot._arg("states", "")).split(",", false)
	var only_other := String(shot._arg("other-states", "")).split(",", false)
	# Only the captured frames are drawn: the simulation runs ahead unrendered (--fixed-fps keeps its pace).
	RenderingServer.render_loop_enabled = false
	await _equip(shot, player, WEAPON, true)
	for f in fovs.size():
		var fov := float(fovs[f])
		var pick := only if f == 0 or only_other.is_empty() else only_other
		Profile.data["settings"]["fov"] = fov
		player._apply_settings()
		await shot._wait(10)
		var cells: Array[Image] = []
		for state in STATES:
			if not pick.is_empty() and not pick.has(state[0]):
				continue
			var img := await _pose(shot, player, state[1], float(state[2]))
			if img == null:
				continue
			img.convert(Image.FORMAT_RGB8)
			img.save_png("%s_fov%d_%s.png" % [base, int(fov), state[0]])
			var cell := img.duplicate() as Image
			cell.resize(CELL_W, CELL_W * img.get_height() / img.get_width(), Image.INTERPOLATE_BILINEAR)
			cells.append(cell)
		if cells.size() > 1:
			var cell_size := cells[0].get_size()
			var rows := ceili(cells.size() / float(COLUMNS))
			var sheet := Image.create(cell_size.x * COLUMNS, cell_size.y * rows, false, Image.FORMAT_RGB8)
			for i in cells.size():
				sheet.blit_rect(cells[i], Rect2i(Vector2i.ZERO, cell_size), Vector2i(i % COLUMNS * cell_size.x, i / COLUMNS * cell_size.y))
			sheet.save_png("%s_fov%d_sheet.png" % [base, int(fov)])
	RenderingServer.render_loop_enabled = true
	print("[hammer] saved %s_*" % base)


## Draws `id` (from the other slot when `away` or it is already held).
func _equip(shot: Node, player: Player, id: StringName, wait_out: bool) -> void:
	var w := player.weapons
	var slot := 1 if w.active_slot == 0 else 0
	w.slots[slot] = id
	w.switch_to_slot(slot)
	if wait_out:
		await shot._wait(int((w.current.equip_time + 0.8) * 30.0))


func _pose(shot: Node, player: Player, kind: String, at: float) -> Image:
	var w := player.weapons
	var view := player.view
	match kind:
		"idle":
			await shot._wait(20)
		"equip":
			# Put it away and draw it again; capture `at` seconds into the draw (once it is in hand).
			var other: StringName = &"ion_carbine"
			await _equip(shot, player, other, true)
			await _equip(shot, player, WEAPON, false)
			while view.data == null or view.data.id != WEAPON or view._lowering:
				await shot.get_tree().process_frame
			var frames := 0
			while frames < int(at * 30.0):
				await shot.get_tree().process_frame
				frames += 1
		"inspect":
			if not view.inspect():
				return null
			while view.is_inspecting() and view._inspect.clock < at:
				await shot.get_tree().process_frame
		_:
			var melee := w.mode as MeleeMode
			if melee == null:
				return null
			if at < 0.0:
				at = melee.view_contact.y
			shot._press("aim" if kind != "light" else "fire", true)
			for i in 400:
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
	RenderingServer.render_loop_enabled = true
	await shot._wait(2)
	await RenderingServer.frame_post_draw
	var img := shot.get_viewport().get_texture().get_image()
	w.set_physics_process(true)
	shot._press("aim", false)
	shot._press("fire", false)
	if view.is_inspecting():
		view.cancel_inspect()
	RenderingServer.render_loop_enabled = false
	await shot._wait(int(1.8 * 30.0))
	return img
