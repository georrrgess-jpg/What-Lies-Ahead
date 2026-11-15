extends SceneTree
## Renders a key-art still of each level (every world's, then the endless
## levels) from its menu camera (LevelData.menu_camera_from / menu_camera_to)
## into art/keyart/<level_id>.jpg.
## The loading screen and the Play page's world cards show them (KeyArt).
## Re-run it whenever a level's look changes, then re-import the project.
##
## Needs a renderer (never --headless). Render above the output size for
## smoother edges:
##
##   xvfb-run -a godot --audio-driver Dummy --rendering-driver opengl3 --path . \
##       --resolution 1280x720 --script res://tools/capture_keyart.gd [-- options]
##   godot --headless --path . --import
##
## Options:
##   <level_id> ...     only these levels (default: every level of every world)
##   --size=WxH         output size (default 960x540)
##   --frames=n         frames to let the scene settle before capturing (default 40)
##   --fov=deg          camera field of view (default 52, the menu backdrop's)
##   --cam=x,y,z>tx,ty,tz   another camera than the level's (to try a framing)
##   --out=<dir>        write there instead of art/keyart/ (trial framings)
##
## Script mode compiles this file before the autoloads exist, so it only uses
## untyped references to game classes.

const OUT_DIR := "res://art/keyart/"
## Levels framed wider than the menu's lens (a tall subject from close by):
## Ashfall City looks up the Broadcast Tower plaza at the broken skyscraper
## and the radio mast.
const FOV := {"endless_city": 72.0}

var _only: Array[String] = []
var _size := Vector2i(960, 540)
var _frames := 40
var _fov := 52.0
var _fov_set := false
var _cam := ""
var _out := OUT_DIR


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			var wh := a.trim_prefix("--size=").split("x")
			_size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--frames="):
			_frames = int(a.trim_prefix("--frames="))
		elif a.begins_with("--fov="):
			_fov = float(a.trim_prefix("--fov="))
			_fov_set = true
		elif a.begins_with("--cam="):
			_cam = a.trim_prefix("--cam=")
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=").trim_suffix("/") + "/"
		elif not a.begins_with("--"):
			_only.append(a)
	# Never hang a batch run.
	create_timer(900.0).timeout.connect(func(): quit(2))
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _run() -> void:
	await _wait(3)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var data = root.get_node("GameData")
	var levels := []
	for world in data.worlds():
		levels.append_array(world.levels)
	levels.append_array(data.endless_levels())
	var failed := 0
	for level in levels:
		if _only.is_empty() or _only.has(String(level.id)):
			if not await _capture(level):
				failed += 1
	quit(1 if failed > 0 else 0)


func _capture(level) -> bool:
	var packed: PackedScene = load(level.scene_path)
	if packed == null:
		push_error("keyart: cannot load %s" % level.scene_path)
		return false
	var scene := packed.instantiate()
	# Scenery only, like the menu backdrop: no run, player or HUD.
	var director := scene.find_child("RunDirector", true, false)
	if director:
		director.get_parent().remove_child(director)
		director.free()
	root.add_child(scene)
	var camera := Camera3D.new()
	camera.fov = float(FOV.get(String(level.id), _fov)) if not _fov_set else _fov
	camera.far = 900.0
	scene.add_child(camera)
	var from: Vector3 = level.menu_camera_from
	var to: Vector3 = level.menu_camera_to
	if _cam != "":
		var ends := _cam.split(">")
		from = _vec(ends[0])
		to = _vec(ends[1])
	camera.look_at_from_position(from, to)
	camera.make_current()
	await _wait(_frames)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	scene.queue_free()
	await _wait(2)
	img.convert(Image.FORMAT_RGB8)
	_fit(img)
	var path := _out + String(level.id) + ".jpg"
	var err := img.save_jpg(ProjectSettings.globalize_path(path) if path.begins_with("res://") else path, 0.92)
	print("[keyart] %s -> %s (%dx%d) error=%d" % [level.id, path, img.get_width(), img.get_height(), err])
	return err == OK


static func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


## Crops the capture to the output aspect (centred) and scales it down.
func _fit(img: Image) -> void:
	var aspect := float(_size.x) / float(_size.y)
	var w := img.get_width()
	var h := img.get_height()
	if absf(float(w) / h - aspect) > 0.01:
		var crop_w := mini(w, int(round(h * aspect)))
		var crop_h := mini(h, int(round(crop_w / aspect)))
		var region := img.get_region(Rect2i((w - crop_w) / 2, (h - crop_h) / 2, crop_w, crop_h))
		img.copy_from(region)
	img.resize(_size.x, _size.y, Image.INTERPOLATE_LANCZOS)
