extends RefCounted
## Melee hit-rate probe (a --shot-run script for a level scene, headless):
## stages one zombie at a time (a runner, a tourist, a bruiser, an alpha, the
## low tunnel crawler and the tall Wrecker) at several distances and angles
## from the player, who stands still, walks forward or strafes (or the zombie
## walks in), then swings light and heavy with each melee weapon through the
## real inputs, and prints the hit rate per case:
##
##   godot --headless --path . --fixed-fps 60 -- --shot=/tmp/x.png --shot-scene=level --shot-zombies=0 --shot-run=res://scripts/dev/melee_hit_probe.gd [--shot-probe-weapons=a,b] [--shot-probe-kinds=a,b] [--shot-probe-motions=still,forward]
##
## A trial is "in" when, at the moment of the swing (the light's press, the
## heavy's release), the zombie's surface is within the weapon's max_range and
## its centre within melee_arc_degrees of the facing; "out" when it is more
## than 90 degrees off the facing, or (standing or strafing: walking forward or
## a zombie walking in closes the gap on purpose) beyond the swing's whole
## reach (MeleeMode.reach_bonus and LOCK_REACH) + OUT_MARGIN. Trials in between
## are not counted. The High Striker's heavy slam is an area blow round a point
## ahead of the player (counted as out hits when it catches one). Then the input cases a player meets: the aim
## tapped during a light swing, tapped while sprinting, and released at once.

const WEAPONS := "glow_blade,ticket_flipper,swirl_smasher,high_striker"
const KINDS := "lifeguard_runner,tourist_shambler,boardwalk_bruiser,alpha_bruiser,tunnel_crawler,the_wrecker"
const MOTIONS := "still,forward,strafe,approach"
const DISTANCES := [0.8, 1.6, 2.4, 3.0, 3.5]
## Angles as shares of the weapon's melee_arc_degrees, and one from behind (degrees).
const ANGLE_SHARES := [0.0, 0.5, 0.95]
const BEHIND := 150.0
const OUT_MARGIN := 0.3
const START := Vector3(5.0, 0.0, 15.5)

var _shot: Node
var _player: Player
var _director: RunDirector
## "weapon|swing|kind|motion" -> [in_hits, in_trials, out_hits, out_trials]
var _table := {}


func run(shot: Node, director: RunDirector) -> void:
	_shot = shot
	_director = director
	_player = director.player
	_player.invulnerable = true
	_player.set_physics_process(true)
	_player.controls_enabled = true
	var weapons: PackedStringArray = String(shot._arg("probe-weapons", WEAPONS)).split(",", false)
	var kinds: PackedStringArray = String(shot._arg("probe-kinds", KINDS)).split(",", false)
	var motions: PackedStringArray = String(shot._arg("probe-motions", MOTIONS)).split(",", false)
	var started := Time.get_ticks_msec()
	for id in weapons:
		await _equip(StringName(id))
		for swing in ["light", "heavy"]:
			for kind in kinds:
				for motion in motions:
					var arc := _player.weapons.current.melee_arc_degrees
					for d in DISTANCES:
						for share in ANGLE_SHARES:
							await _trial(id, swing, kind, motion, d, arc * share, int(d * 10.0) % 2 == 0)
						await _trial(id, swing, kind, motion, d, BEHIND, false)
				print("[probe] %s %s %s done at %.0f s" % [id, swing, kind, (Time.get_ticks_msec() - started) / 1000.0])
		await _input_cases(id)
		_report()
	print("[probe] done in %.0f s" % ((Time.get_ticks_msec() - started) / 1000.0))


func _equip(id: StringName) -> void:
	var w := _player.weapons
	if w.current and w.current.id == id:
		return
	var slot := 1 if w.active_slot == 0 else 0
	w.slots[slot] = id
	w.switch_to_slot(slot)
	await _frames(int((w.current.equip_time + 0.6) * 60.0))


func _frames(n: int) -> void:
	for i in n:
		await _shot.get_tree().physics_frame


func _reset_player() -> void:
	for action in ["fire", "aim", "move_forward", "move_left", "sprint"]:
		_shot._press(action, false)
	_player.global_position = START
	_player.velocity = Vector3.ZERO
	_player.set_look(0.0, 0.0)


func _spawn(kind: String, at: Vector3, walks: bool) -> Zombie:
	var data: EnemyData = GameData.enemy(StringName(kind)).duplicate()
	data.behaviours = [] as Array[EnemyBehaviour]
	var z: Zombie = (load(RunDirector.ZOMBIE_SCENE) as PackedScene).instantiate()
	z.setup(data, _player, 1.0)
	z.position = at
	_director._enemies_root.add_child(z)
	var to_player := _player.global_position - z.global_position
	z.rotation.y = atan2(to_player.x, to_player.z)
	if not walks:
		z.speed = 0.0
	z.max_health = 1.0e6
	z.health = 1.0e6
	return z


## One swing at one staged zombie; records it in the table.
func _trial(id: String, swing: String, kind: String, motion: String, d: float, a: float, left: bool) -> void:
	_reset_player()
	await _frames(2)
	var side := 1.0 if left else -1.0
	var dir := Vector3(-sin(deg_to_rad(a)) * side, 0.0, -cos(deg_to_rad(a)))
	var walks := motion == "approach"
	var z := _spawn(kind, START + dir * (d + (1.2 if walks else 0.0)), walks)
	await _frames(3)
	var melee := _player.weapons.mode as MeleeMode
	if motion == "forward":
		_shot._press("move_forward", true)
	elif motion == "strafe":
		_shot._press("move_left", true)
	var start_index := melee.swing_index
	var verdict := ""
	if swing == "light":
		if motion != "still":
			await _frames(12)
		verdict = _classify(z, false, motion)
		_shot._press("fire", true)
		await _frames(2)
		_shot._press("fire", false)
	else:
		_shot._press("aim", true)
		var guard := 0
		while not (melee.phase == MeleeMode.Phase.WINDUP and melee.charge >= 1.0) and guard < 200:
			await _frames(1)
			guard += 1
		verdict = _classify(z, true, motion)
		_shot._press("aim", false)
	var guard := 0
	while (melee.phase != MeleeMode.Phase.IDLE or melee.swing_index == start_index) and guard < 240:
		await _frames(1)
		guard += 1
	var hit := z.health < 1.0e6 - 0.01
	if verdict == "in" and not hit and motion != "approach":
		var to := z.global_position - _player.global_position
		print("[miss] %s %s %s %s d=%.1f a=%.0f; now %.2f m, %.0f deg, dy %.2f" % [id, swing, kind, motion, d, a, Vector2(to.x, to.z).length(),
			rad_to_deg(Vector2(-_player.global_transform.basis.z.x, -_player.global_transform.basis.z.z).angle_to(Vector2(to.x, to.z))), to.y])
	_reset_player()
	z.queue_free()
	await _frames(1)
	if verdict == "":
		return
	var key := "%s|%s|%s|%s" % [id, swing, kind, motion]
	var row: Array = _table.get(key, [0, 0, 0, 0])
	if verdict == "in":
		row[0] += int(hit)
		row[1] += 1
	else:
		row[2] += int(hit)
		row[3] += 1
	_table[key] = row


## "in", "out" or "" (between) for `z` right now.
func _classify(z: Zombie, heavy: bool, motion: String) -> String:
	var data := _player.weapons.current
	var melee := _player.weapons.mode as MeleeMode
	var whole := data.max_range + melee.reach_bonus(heavy) + MeleeMode.LOCK_REACH + OUT_MARGIN
	var to := z.global_position - _player.global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var gap := flat.length() - z.data.capsule_radius * z.data.body_scale
	var forward := -_player.global_transform.basis.z
	var angle := rad_to_deg(Vector3(forward.x, 0.0, forward.z).normalized().angle_to(flat.normalized()))
	if angle > 90.0 or (gap > whole and motion in ["still", "strafe"]):
		return "out"
	if gap <= data.max_range and angle <= data.melee_arc_degrees:
		return "in"
	return ""


## The aim tapped in the ways a player taps it: did a heavy swing come out?
func _input_cases(id: String) -> void:
	var melee := _player.weapons.mode as MeleeMode
	var cases := {"tap_during_light": 0, "tap_while_sprinting": 0, "quick_tap": 0}
	for i in 8:
		for case in cases.keys():
			_reset_player()
			await _frames(30)
			match case:
				"tap_during_light":
					_shot._press("fire", true)
					await _frames(int(melee.data.fire_interval * 60.0 * 0.6))
					_shot._press("fire", false)
					_shot._press("aim", true)
					await _frames(4)
					_shot._press("aim", false)
				"tap_while_sprinting":
					_shot._press("move_forward", true)
					_shot._press("sprint", true)
					await _frames(40)
					_shot._press("aim", true)
					await _frames(6)
					_shot._press("aim", false)
				"quick_tap":
					_shot._press("aim", true)
					await _frames(1)
					_shot._press("aim", false)
			var heavy := false
			for f in 150:
				await _frames(1)
				heavy = heavy or melee.phase == MeleeMode.Phase.HEAVY
			cases[case] += int(heavy)
	for case in cases.keys():
		print("[probe] input %s %s: heavy %d/8" % [id, case, cases[case]])


## Prints the table so far (after each weapon, so a cut-short run still reports).
func _report() -> void:
	var keys := _table.keys()
	keys.sort()
	print("[probe] weapon|swing|kind|motion  in-hit-rate  out-hits")
	var totals := {}
	for key in keys:
		var row: Array = _table[key]
		print("[probe] %s  %d/%d  %d/%d" % [key, row[0], row[1], row[2], row[3]])
		var bits := String(key).split("|")
		for group in [bits[0] + "|" + bits[1], "all|" + bits[1] + "|" + bits[2], "all|" + bits[1] + "|" + bits[3]]:
			var t: Array = totals.get(group, [0, 0, 0, 0])
			for i in 4:
				t[i] += row[i]
			totals[group] = t
	var groups := totals.keys()
	groups.sort()
	for group in groups:
		var t: Array = totals[group]
		print("[probe] TOTAL %s  in %d/%d (%.0f%%)  out %d/%d" % [group, t[0], t[1], 100.0 * t[0] / maxf(1, t[1]), t[2], t[3]])
