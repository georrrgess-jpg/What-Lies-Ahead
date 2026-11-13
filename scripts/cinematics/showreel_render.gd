extends SceneTree
## Entry point that starts the game straight into the showreel (rendering a
## video, timing runs, contact sheets). See tools/render_showreel.sh.
##
##   godot --path . --script res://scripts/cinematics/showreel_render.gd -- --showreel [options]
##
## Options:
##   --showreel-from=s     start at the shot containing s seconds
##   --showreel-to=s       stop at s seconds
##   --showreel-sheet=dir  save one frame 60% into every shot as
##                         dir/<nn>_<shot>.png (contact sheet frames)
##   --showreel-sheet-at=a,b,...  with --showreel-sheet: frames at these
##                         fractions of every shot instead, as dir/<nn>_<shot>_<k>.png
##   --showreel-report=1   print set load times and the worst frame times
##   --showreel-list=1     print "SHOT <index> <id> <start> <length>" for every shot and quit
##
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes.

var _player
var _sheet := ""
var _captured := {}
var _sheet_at := PackedFloat64Array([0.6])


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
	if opts.has("showreel-sheet-at"):
		_sheet_at = PackedFloat64Array(Array(String(opts["showreel-sheet-at"]).split(",")).map(func(v): return float(v)))
	_player = (load("res://scripts/cinematics/showreel.gd") as GDScript).call("make")
	if String(opts.get("showreel-list", "0")) == "1":
		var t := 0.0
		for i in _player.shots.size():
			var shot = _player.shots[i]
			print("SHOT %d %s %.2f %.2f" % [i, shot.id, t, shot.length])
			t += shot.length
		_player.free()
		quit()
		return
	_player.render_mode = true
	_player.start_at = float(opts.get("showreel-from", "0"))
	_player.stop_at = float(opts.get("showreel-to", "-1"))
	_player.report = String(opts.get("showreel-report", "0")) == "1"
	root.add_child.call_deferred(_player)


func _process(_delta: float) -> bool:
	if _sheet == "" or _player == null or not _player.is_inside_tree():
		return false
	var shot = _player.current_shot()
	if shot == null:
		return false
	var done: int = _captured.get(shot.id, 0)
	if done >= _sheet_at.size() or _player.clock() < shot.start + shot.length * _sheet_at[done]:
		return false
	_captured[shot.id] = done + 1
	var img: Image = root.get_texture().get_image()
	var suffix := "" if _sheet_at.size() == 1 else "_%d" % done
	img.save_png("%s/%02d_%s%s.png" % [_sheet, _player.shots.find(shot), shot.id, suffix])
	return false
