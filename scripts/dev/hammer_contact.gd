extends RefCounted
## High Striker grip contact probe (a --shot-run script for a level scene, runs
## headless): plays idle, a light swing, a full wind-up and heavy slam with its
## recovery, a draw and an inspect, and every frame measures each hand against
## its grip anchor on the mallet: how far the hand's grip point (ArmSGrip) is
## from its anchor (GripLower / GripUpper) and how far the palm turned against
## the handle since the last frame (a wrist snap), and how far the head moved
## (that the action played). Prints one line per action and side:
## "[contact] <action> <side> max_gap=<mm> max_turn=<deg/frame> frames=<n> head_moved=<m>":
##
##   godot --headless --path . --fixed-fps 30 -- --shot=/tmp/x.png --shot-scene=level --shot-zombies=0 --shot-run=res://scripts/dev/hammer_contact.gd

const WEAPON := &"high_striker"
const HANDS := [["L", "GripLower"], ["R", "GripUpper"]]


func run(shot: Node, director: RunDirector) -> void:
	var player := director.player
	player.invulnerable = true
	player.set_physics_process(true)
	player.controls_enabled = true
	var w := player.weapons
	await _draw(shot, player, &"ion_carbine")
	await _draw(shot, player, WEAPON)
	await _measure(shot, player, "equip", 30, func() -> void: pass)
	await _measure(shot, player, "idle", 60, func() -> void: pass)
	await _measure(shot, player, "light", 60, func() -> void:
		shot._press("fire", true)
		await shot._wait(2)
		shot._press("fire", false))
	await shot._wait(30)
	await _measure(shot, player, "windup_heavy_recovery", 120, func() -> void:
		shot._press("aim", true)
		var melee := w.mode as MeleeMode
		for i in 90:
			await shot.get_tree().physics_frame
			if melee.charge >= 1.0:
				break
		shot._press("aim", false))
	await shot._wait(30)
	await _measure(shot, player, "inspect", 100, func() -> void: player.view.inspect())


func _draw(shot: Node, player: Player, id: StringName) -> void:
	var w := player.weapons
	var slot := 1 if w.active_slot == 0 else 0
	w.slots[slot] = id
	w.switch_to_slot(slot)
	while player.view.data == null or player.view.data.id != id:
		await shot.get_tree().process_frame


## Starts `action` (a coroutine) and samples every frame of it and `frames` frames after.
func _measure(shot: Node, player: Player, label: String, frames: int, action: Callable) -> void:
	var model := player.view.model
	var gap := {}
	var turn := {}
	var last := {}
	var nodes := {}
	for h in HANDS:
		nodes[h[0]] = [model.find_child("Arm%sGrip" % h[0], true, false), model.find_child(h[1], true, false),
			model.find_child("Arm%sHand" % h[0], true, false), model.find_child("Handle", true, false)]
		gap[h[0]] = 0.0
		turn[h[0]] = 0.0
	var head := model.find_child("Head", true, false) as Node3D
	var start := head.global_position
	var travel := 0.0
	var done := [false]
	var run_action := func() -> void:
		await action.call()
		done[0] = true
	run_action.call()
	var n := 0
	while n < frames or not done[0]:
		await shot.get_tree().process_frame
		n += 1
		travel = maxf(travel, head.global_position.distance_to(start) / player.view.global_basis.get_scale().x)
		for side in nodes:
			var grip: Node3D = nodes[side][0]
			var anchor: Node3D = nodes[side][1]
			var palm: Node3D = nodes[side][2]
			var handle: Node3D = nodes[side][3]
			if grip == null or anchor == null or palm == null or handle == null:
				continue
			# Model units -> mm (the build's metres).
			var d := grip.global_position.distance_to(anchor.global_position) / player.view.global_basis.get_scale().x * 1000.0
			gap[side] = maxf(gap[side], d)
			var rel := handle.global_basis.orthonormalized().inverse() * palm.global_basis.orthonormalized()
			if last.has(side):
				var q := Quaternion(last[side]).inverse() * Quaternion(rel)
				# The shorter way round (a quaternion and its negative are the same turn).
				var angle := rad_to_deg(q.normalized().get_angle())
				turn[side] = maxf(turn[side], minf(angle, 360.0 - angle))
			last[side] = rel
	for side in nodes:
		print("[contact] %s %s max_gap=%.2fmm max_turn=%.2fdeg/frame frames=%d head_moved=%.2fm" % [label, side, gap[side], turn[side], n, travel])
