extends RefCounted
## Claw Grabber probe (a --shot-run script for a level scene): fires the claw
## through the real inputs and checks what it does.
##
##   grab     a Tourist stands 9 m ahead: tapped, it must end up at the
##            player's feet, Prized and bowled over (or dazed), on the navmesh
##   heavy    a Bruiser stands 10 m ahead: tapped, the claw slips (the player
##            stays put, the Bruiser is Prized); held, the player is reeled to it
##   grapple  from the level's spawn and from points round it, the trigger is
##            held at walls and floors in every direction (12 yaws x 4 pitches):
##            every reel must end on the navmesh, no higher than a jump, with
##            nothing solid between start and end (a capsule-height ray at
##            knee, waist and chest), never further than its range
##
##   godot --headless --path . --fixed-fps 60 -- --shot=/tmp/c.png --shot-level=prize_pier \
##       --shot-weapon=claw_grabber --shot-run=res://scripts/dev/claw_grabber_probe.gd
##
## With a renderer it also saves <shot>_yank.png (the Tourist on its way in)
## and <shot>_reel.png (the player reeling toward the Bruiser).

const YAWS := 12
const PITCHES := [-30.0, -12.0, 0.0, 12.0]
## Where the grapple tests stand, round the spawn (m, flat offsets).
const STANDS := [Vector3.ZERO, Vector3(4, 0, 0), Vector3(-4, 0, 3), Vector3(0, 0, -5)]
const MASK_SOLID := 1 | 16

var _shot: Node
var _player: Player
var _director: RunDirector
var _start := Vector3.ZERO
var _fails := 0
var _headless := true


func run(shot: Node, director: RunDirector) -> void:
	_shot = shot
	_director = director
	_player = director.player
	_player.invulnerable = true
	_player.set_physics_process(true)
	_player.controls_enabled = true
	_headless = DisplayServer.get_name() == "headless"
	_start = _player.global_position
	await _frames(30)
	if _player.weapons.current == null or _player.weapons.current.id != &"claw_grabber":
		print("[claw] the Claw Grabber is not in hand")
		return
	await _grab_test()
	await _heavy_test()
	await _grapple_test()
	print("[claw] level %s: %d problems" % [String(_shot._arg("level", "prize_pier")), _fails])


func _frames(n: int) -> void:
	for i in n:
		await _shot.get_tree().physics_frame


func _mode() -> ClawGrabberMode:
	return _player.weapons.mode as ClawGrabberMode


func _reset(at: Vector3) -> void:
	_shot._press("fire", false)
	_player.stop_reel()
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	var mode := _mode()
	if mode:
		mode._cooldown = 0.0
	_player.weapons.top_up()


func _aim_at(p: Vector3) -> void:
	var to := p - _player.camera.global_position
	_player.set_look(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


func _spawn(kind: StringName, at: Vector3) -> Zombie:
	var z: Zombie = (load(RunDirector.ZOMBIE_SCENE) as PackedScene).instantiate()
	z.setup(GameData.enemy(kind), _player, 1.0)
	z.position = at
	_director._enemies_root.add_child(z)
	z.speed = 0.0
	z.skip_emerge()
	z.max_health = 1.0e6
	z.health = 1.0e6
	return z


## A clear spot `d` metres from the start along the navmesh in some direction.
func _ahead(d: float) -> Vector3:
	var map := _player.get_world_3d().navigation_map
	for k in 16:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, k * TAU / 16.0)
		var p := NavigationServer3D.map_get_closest_point(map, _start + dir * d)
		if Vector2(p.x - _start.x, p.z - _start.z).length() > d * 0.85 and absf(p.y - _start.y) < 0.6 and _clear(_start, p):
			return p
	return Vector3.INF


func _clear(a: Vector3, b: Vector3) -> bool:
	var space := _player.get_world_3d().direct_space_state
	for h in [0.4, 0.9, 1.5]:
		var q := PhysicsRayQueryParameters3D.create(a + Vector3.UP * h, b + Vector3.UP * h, MASK_SOLID)
		q.exclude = [_player.get_rid()]
		if not space.intersect_ray(q).is_empty():
			return false
	return true


func _fire(hold: float) -> void:
	_shot._press("fire", true)
	await _frames(maxi(1, int(hold * 60.0)))
	_shot._press("fire", false)


func _wait_home(seconds: float) -> void:
	var left := int(seconds * 60.0)
	while left > 0 and (_mode().is_out() or _player.is_reeling()):
		await _frames(1)
		left -= 1


func _save(suffix: String) -> void:
	if _headless:
		return
	await RenderingServer.frame_post_draw
	var file := "%s_%s.png" % [String(_shot.path).get_basename(), suffix]
	_shot.get_tree().root.get_viewport().get_texture().get_image().save_png(file)
	print("[claw] saved ", file)


func _grab_test() -> void:
	var at := _ahead(9.0)
	if at == Vector3.INF:
		print("[claw] grab: no clear spot 9 m out")
		return
	_reset(_start)
	var z := _spawn(&"tourist_shambler", at)
	await _frames(5)
	_aim_at(z.global_position + Vector3.UP * 1.0)
	await _frames(2)
	var hp := z.health
	await _fire(0.05)
	var nearest := INF
	var saved := false
	var downed := false
	for i in 90:
		await _frames(1)
		var d := Vector2(z.global_position.x - _player.global_position.x, z.global_position.z - _player.global_position.z).length()
		nearest = minf(nearest, d)
		var prize := z.get_node_or_null(ClawPrize.NODE_NAME) as ClawPrize
		if prize and prize.is_carried() and d < 6.0 and not saved:
			saved = true
			await _save("yank")
		var topple := z.get_node_or_null(StrikeZoneTopple.NODE_NAME) as StrikeZoneTopple
		downed = downed or (topple != null and topple.is_down())
	var prize := z.get_node_or_null(ClawPrize.NODE_NAME) as ClawPrize
	var prized := prize != null and prize.is_prized()
	var bonus := DamageStack.bonus(z)
	var on_nav := _on_navmesh(z.global_position)
	var ok := nearest < 3.2 and downed and prized and on_nav and hp - z.health > 1.0
	print("[claw] grab: dealt %.0f, pulled from %.1f m to %.2f m, bowled over %s, Prized %s (+%.0f%%), on navmesh %s -> %s" % [
		hp - z.health, at.distance_to(_start), nearest, downed, prized, bonus * 100.0, on_nav, "ok" if ok else "FAIL"])
	if not ok:
		_fails += 1
	z.queue_free()
	await _wait_home(2.0)
	await _frames(20)


func _heavy_test() -> void:
	var at := _ahead(10.0)
	if at == Vector3.INF:
		print("[claw] heavy: no clear spot 10 m out")
		return
	_reset(_start)
	var z := _spawn(&"boardwalk_bruiser", at)
	await _frames(5)
	# A tap: the claw slips off, the player stays.
	_aim_at(z.global_position + Vector3.UP * 1.1)
	await _frames(2)
	await _fire(0.05)
	await _wait_home(2.0)
	var moved := _player.global_position.distance_to(_start)
	var prize := z.get_node_or_null(ClawPrize.NODE_NAME) as ClawPrize
	var ok := moved < 0.5 and prize != null and prize.is_prized() and Vector2(z.global_position.x - at.x, z.global_position.z - at.z).length() < 1.2
	print("[claw] heavy tap: player moved %.2f m, Bruiser moved %.2f m, Prized %s -> %s" % [
		moved, Vector2(z.global_position.x - at.x, z.global_position.z - at.z).length(), prize != null and prize.is_prized(), "ok" if ok else "FAIL"])
	if not ok:
		_fails += 1
	await _frames(20)
	# Held: the player is reeled to it.
	_reset(_start)
	_aim_at(z.global_position + Vector3.UP * 1.1)
	await _frames(2)
	_shot._press("fire", true)
	var saved := false
	for i in 80:
		await _frames(1)
		if _player.is_reeling() and not saved and _player.global_position.distance_to(_start) > 2.0:
			saved = true
			await _save("reel")
	_shot._press("fire", false)
	await _wait_home(2.0)
	var gap := Vector2(z.global_position.x - _player.global_position.x, z.global_position.z - _player.global_position.z).length()
	ok = gap < 3.4 and gap > 1.2 and _on_navmesh(_player.global_position)
	print("[claw] heavy hold: reeled from %.1f m to %.2f m of the Bruiser, on navmesh %s -> %s" % [
		Vector2(at.x - _start.x, at.z - _start.z).length(), gap, _on_navmesh(_player.global_position), "ok" if ok else "FAIL"])
	if not ok:
		_fails += 1
	z.queue_free()
	await _frames(10)


func _grapple_test() -> void:
	var reels := 0
	var shots := 0
	var longest := 0.0
	## Reels that ended on the floor just beside the navmesh (props carve it), not counted as problems.
	var beside := 0
	for offset in STANDS:
		var stand := NavigationServer3D.map_get_closest_point(_player.get_world_3d().navigation_map, _start + offset)
		if offset != Vector3.ZERO and (not _clear(_start, stand) or absf(stand.y - _start.y) > 0.5):
			continue
		for yi in YAWS:
			for pitch in PITCHES:
				_reset(stand + Vector3.UP * 0.05)
				await _frames(3)
				var from := _player.global_position
				_player.set_look(yi * TAU / YAWS, deg_to_rad(pitch))
				await _frames(1)
				shots += 1
				_shot._press("fire", true)
				await _frames(24)
				_shot._press("fire", false)
				await _wait_home(2.5)
				await _frames(12)
				var to := _player.global_position
				var flat := Vector2(to.x - from.x, to.z - from.z).length()
				if flat < 0.5:
					continue
				reels += 1
				longest = maxf(longest, flat)
				var problems: PackedStringArray = []
				var off := _off_navmesh(to)
				if off > 1.5:
					problems.append("%.1f m off the navmesh" % off)
				elif off > 0.8:
					beside += 1
				if to.y - from.y > ClawGrabberReel.MAX_RISE + 0.2:
					problems.append("rose %.2f m" % (to.y - from.y))
				if not _clear(from, to):
					problems.append("scenery between start and end")
				if flat > ClawGrabberReel.RANGE + ClawGrabberReel.LAND_SLOP + 0.5:
					problems.append("too far (%.1f m)" % flat)
				if not problems.is_empty():
					_fails += 1
					print("[claw] grapple yaw %d pitch %.0f from %s: %.1f m to %s: %s" % [yi * 360 / YAWS, pitch, from, flat, to, ", ".join(problems)])
	print("[claw] grapple: %d shots, %d reels, longest %.1f m, %d ended 0.8-1.5 m beside the navmesh" % [shots, reels, longest, beside])


## Flat metres from `p` to the navmesh (INF when the nearest navmesh is a floor above or below).
func _off_navmesh(p: Vector3) -> float:
	var q := NavigationServer3D.map_get_closest_point(_player.get_world_3d().navigation_map, p)
	return Vector2(q.x - p.x, q.z - p.z).length() if absf(q.y - p.y) < 1.0 else INF


func _on_navmesh(p: Vector3) -> bool:
	var q := NavigationServer3D.map_get_closest_point(_player.get_world_3d().navigation_map, p)
	return Vector2(q.x - p.x, q.z - p.z).length() < 0.8 and absf(q.y - p.y) < 1.0
