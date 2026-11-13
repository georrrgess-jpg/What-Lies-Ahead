extends RefCounted
## Headless check that the showreel hands the menu back intact: played to the
## end and skipped with a key, the menu is the current scene again, in the
## tree, with its camera, music and input back, the time scale is 1 and no
## nodes are left behind. Run it with:
##
##   godot --headless --path . --fixed-fps 60 -- --profile=<scratch copy> --shot=/tmp/x.png \
##       --shot-scene=menu --shot-run=res://scripts/cinematics/showreel_probe.gd
##
## Prints one "[probe] ok|FAIL ..." line per check and a final summary.

var _tree: SceneTree
var _menu: Node
var _failed := 0
var _checks := 0


func run(shot: Node, menu: Node) -> void:
	_tree = shot.get_tree()
	_menu = menu
	await _frames(30)
	var before := _counted_nodes()
	var music := _playing_music()
	await _play(-1.0)
	_check_restored(before, music, "played to the end")
	await _play(9.0)
	_check_restored(before, music, "skipped with a key")
	print("[probe] DONE %d checks, %d failed" % [_checks, _failed])


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failed += 1
	print("[probe] %s %s" % ["ok" if ok else "FAIL", what])


func _frames(count := 3) -> void:
	for i in count:
		await _tree.process_frame


## The players (menu theme, ambience) that were audible before the reel.
func _playing_music() -> Array:
	return Sfx.get_children().filter(func(c): return c is AudioStreamPlayer and c.playing and not c.stream_paused)


## Nodes in the tree, leaving out one-shot sounds still playing under Sfx
## (with the Dummy audio driver they never finish).
func _counted_nodes() -> int:
	return _tree.get_node_count() - Sfx.get_child_count()


## Plays the reel; with `skip_at` >= 0 a key press skips it at that time.
func _play(skip_at: float) -> void:
	var done := {"v": false}
	var reel := Showreel.play(_menu, func(): done["v"] = true)
	await _frames(2)
	_check(not _menu.is_inside_tree() and _tree.current_scene == reel, "menu suspended while the reel plays")
	while not done["v"]:
		await _tree.process_frame
		if skip_at >= 0.0 and is_instance_valid(reel) and reel.clock() >= skip_at:
			var key := InputEventKey.new()
			key.keycode = KEY_SPACE
			key.physical_keycode = KEY_SPACE
			key.pressed = true
			Input.parse_input_event(key)
			skip_at = -1.0
	await _frames(30)


func _check_restored(before: int, music: Array, how: String) -> void:
	_check(_menu.is_inside_tree() and _tree.current_scene == _menu, how + ": menu is back as the current scene")
	var cam := _menu.get_viewport().get_camera_3d()
	_check(cam != null and _menu.is_ancestor_of(cam), how + ": the menu's camera is current")
	_check(is_equal_approx(Engine.time_scale, 1.0), how + ": time scale is 1")
	var audible := music.filter(func(p): return is_instance_valid(p) and p.playing and not p.stream_paused)
	_check(not music.is_empty() and audible.size() == music.size(), how + ": menu music and ambience resumed (%d of %d)" % [audible.size(), music.size()])
	_check(_tree.root.get_node_or_null("CinePlayer") == null, how + ": the player is gone")
	var after := _counted_nodes()
	_check(after <= before, how + ": node count %d before, %d after" % [before, after])
