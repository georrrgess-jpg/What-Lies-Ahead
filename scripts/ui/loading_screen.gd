class_name LoadingScreen
extends CanvasLayer
## Full-screen card shown while a level loads: world and level name in the
## level's accent colours, a tip, and an animated progress ring. The level
## scene is loaded on a background thread, then swapped in.

var level: LevelData
var _progress := 0.0
var _ring: Control
var _status: Label
var _time := 0.0
var _done := false


static func start(tree: SceneTree, target: LevelData) -> void:
	var screen := LoadingScreen.new()
	screen.level = target
	tree.root.add_child(screen)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UiKit.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var world := level.world
	var accent := level.accent_color
	var back := world.backdrop_color if world else UiKit.NAVY
	var bg := ColorRect.new()
	bg.color = back.darkened(0.35)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	# Diagonal accent stripes sweeping across.
	var stripes := _Stripes.new()
	stripes.accent = accent
	stripes.secondary = world.secondary_color if world else UiKit.CYAN
	stripes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stripes)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.offset_left = 140
	col.add_theme_constant_override("separation", 4)
	root.add_child(col)
	var world_idx := GameData.worlds().find(world) + 1
	col.add_child(UiKit.arcade_label("WORLD %d  ·  %s" % [world_idx, world.display_name.to_upper() if world else ""], 36, world.secondary_color if world else UiKit.CYAN))
	col.add_child(UiKit.arcade_label(level.display_name.to_upper(), 120, Color.WHITE))
	var tag := UiKit.label(world.tagline if world else "", 30, UiKit.CREAM)
	col.add_child(tag)
	col.add_child(UiKit.spacer(40))
	var tip_text := level.loading_tips[randi() % level.loading_tips.size()] if level.loading_tips.size() > 0 else "Headshots multiply your score."
	var tip_box := PanelContainer.new()
	tip_box.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.7), accent, 16, 3, 18))
	tip_box.custom_minimum_size = Vector2(820, 0)
	var tip := UiKit.label("TIP  ·  " + tip_text, 28, Color.WHITE)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_box.add_child(tip)
	col.add_child(tip_box)
	_ring = _Ring.new()
	_ring.accent = accent
	_ring.custom_minimum_size = Vector2(140, 140)
	root.add_child(_ring)
	_ring.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ring.offset_left = -240
	_ring.offset_top = -240
	_ring.offset_right = -100
	_ring.offset_bottom = -100
	_status = UiKit.arcade_label("LOADING", 28, Color.WHITE)
	root.add_child(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_status.offset_left = -420
	_status.offset_top = -90
	_status.offset_right = -100
	_status.offset_bottom = -50
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.25)
	ResourceLoader.load_threaded_request(level.scene_path)
	Sfx.play(&"ui_whoosh", -6.0)


func _process(delta: float) -> void:
	_time += delta
	if _done:
		return
	var prog := []
	var status := ResourceLoader.load_threaded_get_status(level.scene_path, prog)
	if prog.size() > 0:
		_progress = maxf(_progress, float(prog[0]))
	(_ring as _Ring).progress = _progress
	_status.text = "LOADING  %d%%" % int(_progress * 100.0)
	# Keep the card up for at least a beat so it reads as intentional.
	if status == ResourceLoader.THREAD_LOAD_LOADED and _time > 1.1:
		_done = true
		var packed: PackedScene = ResourceLoader.load_threaded_get(level.scene_path)
		get_tree().paused = false
		get_tree().change_scene_to_packed(packed)
		var tw := create_tween()
		tw.tween_interval(0.25)
		tw.tween_property(get_child(0), "modulate:a", 0.0, 0.35)
		tw.tween_callback(queue_free)
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_done = true
		get_tree().change_scene_to_file(level.scene_path)
		queue_free()


class _Ring:
	extends Control
	var accent := UiKit.PINK
	var progress := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		draw_arc(c, r, 0, TAU, 64, Color(UiKit.INK, 0.8), 14.0, true)
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, accent, 10.0, true)
		var a := _t * 4.0
		draw_arc(c, r * 0.68, a, a + 1.6, 24, Color(UiKit.CYAN, 0.9), 6.0, true)
		draw_arc(c, r * 0.68, a + PI, a + PI + 1.6, 24, Color(UiKit.CYAN, 0.9), 6.0, true)


class _Stripes:
	extends Control
	var accent := UiKit.PINK
	var secondary := UiKit.CYAN
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		var w := 120.0
		var off := fmod(_t * 90.0, w * 2.0)
		var x := -s.y - w * 2.0 + off
		var i := 0
		while x < s.x + s.y:
			var c := accent if i % 2 == 0 else secondary
			var pts := PackedVector2Array([Vector2(x, s.y), Vector2(x + w * 0.5, s.y), Vector2(x + w * 0.5 + s.y * 0.6, 0), Vector2(x + s.y * 0.6, 0)])
			draw_colored_polygon(pts, Color(c, 0.07))
			x += w * 2.0
			i += 1
		draw_rect(Rect2(0, s.y - 10, s.x, 10), accent)
