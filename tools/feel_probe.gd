extends SceneTree
## Feel probe: how smoothly aiming down sights and firing move on screen at a
## given refresh rate. Physics runs at the project's 60 ticks a second; the
## render rate is the --fixed-fps value, so one command per refresh rate:
##
##   for hz in 60 75 120 144 165 240; do
##     godot --headless --audio-driver Dummy --path . --fixed-fps $hz --script res://tools/feel_probe.gd -- [options]
##   done
##
## Options:
##   --weapons=a,b   only these weapon ids (default: all)
##   --sights=x,y    only these sight ids (default: every sight that fits)
##   --fire=0        skip the firing runs
##   --detail=1      also print every segment's hitches per channel
##
## The real player on Prize Pier, standing still. For every weapon and sight
## it raises the sight, holds it, lowers it (phase "ads"); per weapon it then
## fires a sustained string from the hip ("hip") and aimed ("aimed"): held
## for automatics and beams, tapped at the fire rate for the others, charged
## and let go for charge weapons. Every rendered frame, after everything else
## has moved, it records:
##   fov      the camera's field of view
##   cam_dir  the camera's view direction       cam_pos  its position
##   vm_dir   the viewmodel's direction, in the camera's space
##   vm_pos   the viewmodel's position, in the camera's space
##   ret      the HUD reticle's gap and fade
## A frame is a hitch when its change differs from the mean of its
## neighbours' by more than HITCH of the largest of the three (a step after a
## still frame, a still frame in a move, a jump): smooth motion sampled at any
## rate stays well under it. Only frames that move (above MOVING of the
## segment's fastest change) count, and the frames a shot lands in are left
## out (a kick starts there, on purpose). Printed per phase and channel:
## hitches / moving frames; then each channel's fastest change per second
## (deg/s for fov and directions, m/s or view units/s for positions): a value
## that jumps in one frame shows up as a peak that grows with the frame rate,
## a smooth one stays put; for the firing phases, the shots fired. For "ads"
## also: how long after the press the picture stops changing (fov and
## viewmodel within SETTLED of their end), and how much the FOV still changes
## once the viewmodel is in place (the sight "swimming").
##
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes.

const SIGHTS_SCRIPT := "res://scripts/weapons/sights/weapon_sights.gd"
const STATE_WAVE := 1
const HITCH := 0.6
const MOVING := 0.03
const FLOOR := 1e-5
const SETTLED := 0.002
const CHANNELS := ["fov", "cam_dir", "cam_pos", "vm_dir", "vm_pos", "ret"]
const PHASES := ["ads", "hip", "aimed"]

var opts := {}
## phase -> channel -> Vector2i(hitches, moving frames)
var totals := {}
## phase -> channel -> fastest change per second
var peaks := {}
## phase -> shots fired
var shots := {}
var arrivals: Array = []
var swims: Array = []


## Records one value per channel every rendered frame, last of all nodes.
class Sampler extends Node:
	var player
	var reticle
	var phase := ""
	var frames: Array = []
	## Indices into `frames` of the frames that saw a shot.
	var shot_frames := {}
	var _shot := false

	func mark_shot() -> void:
		_shot = true

	func _init() -> void:
		process_priority = 100000

	func _process(_delta: float) -> void:
		if phase == "":
			return
		var camera = player.camera
		var inv: Transform3D = camera.global_transform.affine_inverse()
		var holder: Node3D = player.view._holder
		var vm: Transform3D = inv * holder.global_transform
		frames.append({
			"fov": Vector3(camera.fov, 0.0, 0.0),
			"cam_dir": -camera.global_basis.z,
			"cam_pos": camera.global_position,
			"vm_dir": -vm.basis.orthonormalized().z,
			"vm_pos": vm.origin,
			"ret": Vector3(reticle._shown_gap * 0.01, reticle.aim, 0.0),
		})
		if _shot:
			shot_frames[frames.size() - 1] = true
			_shot = false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
	for phase in PHASES:
		totals[phase] = {}
		peaks[phase] = {}
		shots[phase] = 0
		for channel in CHANNELS:
			totals[phase][channel] = Vector2i.ZERO
			peaks[phase][channel] = 0.0
	create_timer(1500.0).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _opt(key: String, default_value: String) -> String:
	return String(opts.get(key, default_value))


func _seconds(time: float) -> void:
	await create_timer(time).timeout


func _press(action: String, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	Input.parse_input_event(e)


func _run() -> void:
	await process_frame
	var data: Node = root.get_node("GameData")
	var game: Node = root.get_node("Game")
	var cosmetics: Node = root.get_node("Cosmetics")
	var sights = load(SIGHTS_SCRIPT)
	var weapons: Array = data.weapons()
	if opts.has("weapons"):
		var wanted := _opt("weapons", "").split(",")
		weapons = weapons.filter(func(w): return String(w.id) in wanted)
	game.level = data.level(&"prize_pier")
	game.weapon_id = weapons[0].id
	change_scene_to_file(game.level.scene_path)
	var director = null
	while director == null or director.player == null:
		await process_frame
		director = get_first_node_in_group("run_director")
	var player = director.player
	await _seconds(0.2)
	director.set_process(false)
	director.set_process_unhandled_input(false)
	director.wave_number = 3
	director._set_state(STATE_WAVE)
	director.kiosk.set_open(false)
	player.global_position = Vector3(5.0, 0.0, 15.5)
	player.set_look(deg_to_rad(12.0), 0.0)
	player.controls_enabled = true
	player.invulnerable = true
	var sampler := Sampler.new()
	sampler.player = player
	sampler.reticle = director.hud._reticle
	player.weapons.fired.connect(func(_w):
		sampler.mark_shot()
		if sampler.phase in shots:
			shots[sampler.phase] += 1)
	root.add_child(sampler)
	await _seconds(0.5)
	for weapon in weapons:
		var items: Array = cosmetics.items_for(sights.SLOT, weapon.id)
		if opts.has("sights"):
			items = items.filter(func(it): return String(it.id) in _opt("sights", "").split(","))
		for item in items:
			_hold(player, weapon, item, sights)
			await _seconds(0.35)
			await _ads(sampler, weapon, item)
		if _opt("fire", "1") == "1" and not items.is_empty():
			_hold(player, weapon, items[0], sights)
			await _seconds(0.35)
			await _fire(sampler, player, weapon, "hip")
			await _fire(sampler, player, weapon, "aimed")
	_report()
	quit(0)


## Holds `weapon` wearing `item`, ready at once (no raise animation).
func _hold(player, weapon, item, sights) -> void:
	sights.wear_for_session(weapon.id, item.id)
	player.weapons.set_loadout(weapon.id, &"pulse_pistol" if weapon.id != &"pulse_pistol" else &"ion_carbine")
	var view = player.view
	view._lowering = false
	view._pending = null
	view._build_model(weapon)
	view._raise = 0.0


func _ads(sampler, weapon, item) -> void:
	sampler.frames = []
	sampler.shot_frames = {}
	sampler.phase = "ads"
	_press("aim", true)
	await _seconds(0.75)
	var frames_in: Array = sampler.frames.duplicate()
	_press("aim", false)
	await _seconds(0.6)
	sampler.phase = ""
	_analyse("ads", sampler.frames, "%s/%s" % [weapon.id, item.id])
	_settle(frames_in, "%s/%s" % [weapon.id, item.id])


func _fire(sampler, player, weapon, phase: String) -> void:
	player.weapons._ammo[weapon.id]["mag"] = weapon.magazine_size
	player.weapons._ammo[weapon.id]["reserve"] = 999
	if phase == "aimed":
		_press("aim", true)
		await _seconds(0.6)
	sampler.frames = []
	sampler.shot_frames = {}
	sampler.phase = phase
	await _trigger(weapon, 1.2)
	await _seconds(0.6)
	sampler.phase = ""
	if phase == "aimed":
		_press("aim", false)
		await _seconds(0.5)
	_analyse(phase, sampler.frames, String(weapon.id), sampler.shot_frames)


## Fires for `time` seconds the way the weapon wants its trigger worked.
func _trigger(weapon, time: float) -> void:
	if weapon.automatic or weapon.beam:
		_press("fire", true)
		await _seconds(time)
		_press("fire", false)
		return
	var hold: float = weapon.charge_time + 0.05 if weapon.charge_time > 0.0 else 0.05
	var left := time
	while left > 0.0:
		_press("fire", true)
		await _seconds(hold)
		_press("fire", false)
		var rest: float = weapon.fire_interval + 0.04
		await _seconds(rest)
		left -= hold + rest


## Counts hitches per channel over one segment of frames.
func _analyse(phase: String, frames: Array, label := "", shot_frames := {}) -> void:
	var line := "[feel]   %-6s %-34s" % [phase, label]
	for channel in CHANNELS:
		var d: Array[Vector3] = []
		for i in range(1, frames.size()):
			d.append(frames[i][channel] - frames[i - 1][channel])
		var peak := 0.0
		for v in d:
			peak = maxf(peak, v.length())
		var floor_v := maxf(FLOOR, peak * MOVING)
		var hitches := 0
		var moving := 0
		for i in range(1, d.size() - 1):
			var m := maxf(d[i].length(), maxf(d[i - 1].length(), d[i + 1].length()))
			if m <= floor_v:
				continue
			# d[i] is the change into frame i + 1.
			if shot_frames.has(i) or shot_frames.has(i + 1) or shot_frames.has(i + 2):
				continue
			moving += 1
			if (d[i] - (d[i - 1] + d[i + 1]) * 0.5).length() > HITCH * m:
				hitches += 1
		totals[phase][channel] += Vector2i(hitches, moving)
		line += " %4d/%-5d" % [hitches, moving]
		var unit := rad_to_deg(1.0) if channel.ends_with("_dir") else 1.0
		peaks[phase][channel] = maxf(peaks[phase][channel], peak * unit / root.get_process_delta_time())
	if _opt("detail", "0") == "1":
		print(line)


## Raising the sight: when the picture stops changing, and how much the FOV
## still moves once the viewmodel has arrived.
func _settle(frames: Array, label: String) -> void:
	var last: Dictionary = frames[frames.size() - 1]
	var fov_end: float = last["fov"].x
	var vm_end: Vector3 = last["vm_pos"]
	var settled_fov := 0
	var settled_vm := 0
	for i in frames.size():
		if absf(frames[i]["fov"].x - fov_end) > SETTLED * fov_end:
			settled_fov = i + 1
		if frames[i]["vm_pos"].distance_to(vm_end) > SETTLED * 0.05:
			settled_vm = i + 1
	var swim := 0.0
	for i in range(maxi(1, settled_vm), frames.size()):
		swim += absf(frames[i]["fov"].x - frames[i - 1]["fov"].x)
	var dt := 0.75 / float(frames.size())
	arrivals.append([label, settled_fov * dt, settled_vm * dt])
	swims.append(swim)


func _report() -> void:
	var hz := roundi(1.0 / maxf(1e-6, root.get_process_delta_time()))
	print("[feel] render %d Hz, physics %d Hz" % [hz, Engine.physics_ticks_per_second])
	var header := "[feel] %-6s" % "phase"
	for channel in CHANNELS:
		header += " %14s" % channel
	print(header)
	for phase in PHASES:
		var line := "[feel] %-6s" % phase
		for channel in CHANNELS:
			var t: Vector2i = totals[phase][channel]
			line += " %6d/%-7d" % [t.x, t.y]
		print(line)
	for phase in PHASES:
		var line := "[feel] %-6s" % phase
		for channel in CHANNELS:
			line += " %14.2f" % peaks[phase][channel]
		print(line + ("   peak per second" if phase == "ads" else "   %d shots" % shots[phase]))
	var fov_t := 0.0
	var vm_t := 0.0
	var fov_worst := 0.0
	var gap_worst := 0.0
	for a in arrivals:
		fov_t += a[1]
		vm_t += a[2]
		fov_worst = maxf(fov_worst, a[1])
		gap_worst = maxf(gap_worst, a[1] - a[2])
	var n := maxf(1.0, arrivals.size())
	var swim_worst := 0.0
	var swim_total := 0.0
	for s in swims:
		swim_worst = maxf(swim_worst, s)
		swim_total += s
	print("[feel] ads settle: fov %.0f ms (worst %.0f), viewmodel %.0f ms; fov still moving %.0f ms after the viewmodel at worst; fov change after arrival mean %.3f deg, worst %.3f deg (%d combos)" % [
		fov_t / n * 1000.0, fov_worst * 1000.0, vm_t / n * 1000.0, gap_worst * 1000.0, swim_total / n, swim_worst, arrivals.size()])
