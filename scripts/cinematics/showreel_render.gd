extends SceneTree
## Entry point that starts the game straight into the showreel (rendering a
## video, timing runs, contact sheets). See tools/render_showreel.sh.
##
##   godot --path . --script res://scripts/cinematics/showreel_render.gd -- --showreel [options]
##
## Options:
##   --showreel-from=s     start at the shot containing s seconds
##   --showreel-to=s       stop at s seconds
##   --showreel-sheet=dir  save one frame from the middle of every shot as
##                         dir/<nn>_<shot>.png (contact sheet frames)
##   --showreel-report=1   print set load times and the worst frame times
##
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes.

var _player
var _sheet := ""
var _captured := {}


func _initialize() -> void:
	var opts := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
	if not "--showreel" in OS.get_cmdline_user_args():
		push_error("showreel_render: pass --showreel")
		quit(1)
		return
	_sheet = String(opts.get("showreel-sheet", ""))
	_player = (load("res://scripts/cinematics/showreel.gd") as GDScript).call("make")
	_player.render_mode = true
	_player.start_at = float(opts.get("showreel-from", "0"))
	_player.stop_at = float(opts.get("showreel-to", "-1"))
	_player.report = String(opts.get("showreel-report", "0")) == "1"
	root.add_child.call_deferred(_player)


func _process(_delta: float) -> bool:
	if _sheet == "" or _player == null or not _player.is_inside_tree():
		return false
	var shot = _player.current_shot()
	if shot == null or _captured.has(shot.id):
		return false
	if _player.clock() >= shot.start + shot.length * 0.6:
		_captured[shot.id] = true
		var img: Image = root.get_texture().get_image()
		img.save_png("%s/%02d_%s.png" % [_sheet, _player.shots.find(shot), shot.id])
	return false
