class_name LoadingScreen
extends CanvasLayer
## Full-screen card shown while a level loads: the level's key art with a slow
## Ken Burns pan, a kit signboard with the world, level, difficulty and the
## loadout, a tip, and a marquee progress bar whose bulbs light up as it loads. The level scene is loaded on a background thread, then
## swapped in. A level without key art gets drifting accent stripes instead.

## Ken Burns: the art slowly zooms in and slides over this many seconds.
const PAN_SECONDS := 14.0
const PAN_ZOOM := Vector2(1.04, 1.13)

var level: LevelData
var _progress := 0.0
var _shown_progress := 0.0
var _bar: _BulbBar
var _status: Label
var _art: TextureRect
var _time := 0.0
var _done := false


## Ignored while a load is already showing (a double-pressed Deploy or Retry).
static func start(tree: SceneTree, target: LevelData) -> void:
	if tree.root.get_children().any(func(n): return n is LoadingScreen):
		return
	# The button that started this keeps focus otherwise; Enter would press it again.
	tree.root.gui_release_focus()
	var screen := LoadingScreen.new()
	screen.level = target
	tree.root.add_child(screen)


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UiKit.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.clip_contents = true
	add_child(root)
	var world := level.world
	var accent := level.accent_color
	var back := world.backdrop_color if world else UiKit.NAVY
	var bg := ColorRect.new()
	bg.color = back.darkened(0.35)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var texture := KeyArt.texture(level)
	if texture:
		_art = TextureRect.new()
		_art.texture = texture
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_art)
		root.add_child(_shade(back))
	else:
		var stripes := _Stripes.new()
		stripes.accent = accent
		stripes.secondary = world.secondary_color if world else UiKit.CYAN
		stripes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(stripes)
	root.add_child(_text_column(world, accent))
	_add_progress(root, accent)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.25)
	ResourceLoader.load_threaded_request(level.scene_path)
	Sfx.play(&"ui_whoosh", -6.0)


## Darkens the left of the art (behind the text) and the bottom (behind the bar).
func _shade(back: Color) -> Control:
	var ink := back.darkened(0.6)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.38, 0.72])
	grad.colors = PackedColorArray([Color(ink, 0.92), Color(ink, 0.7), Color(ink, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	tex.width = 256
	tex.height = 4
	var shade := TextureRect.new()
	shade.texture = tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bottom_grad := Gradient.new()
	bottom_grad.offsets = PackedFloat32Array([0.7, 1.0])
	bottom_grad.colors = PackedColorArray([Color(ink, 0.0), Color(ink, 0.85)])
	var bottom_tex := GradientTexture2D.new()
	bottom_tex.gradient = bottom_grad
	bottom_tex.fill_from = Vector2(0, 0)
	bottom_tex.fill_to = Vector2(0, 1)
	bottom_tex.width = 4
	bottom_tex.height = 256
	var bottom := TextureRect.new()
	bottom.texture = bottom_tex
	bottom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bottom.stretch_mode = TextureRect.STRETCH_SCALE
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(bottom)
	return shade


## The signboard on the left: world, level name, tagline, difficulty and
## the two weapons carried in, then a tip on a neon plate.
func _text_column(world: WorldData, accent: Color) -> Control:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.offset_left = 120
	col.offset_top = -40
	col.offset_bottom = -40
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	var board := UiKit.signboard()
	board.set_padding(40, 30)
	board.custom_minimum_size.x = 860
	col.add_child(board)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiKit.GAP_S)
	board.add_child(v)
	var world_idx := GameData.worlds().find(world) + 1
	v.add_child(UiKit.chip("WORLD %d  ·  %s" % [world_idx, world.display_name.to_upper() if world else ""], world.secondary_color if world else UiKit.CYAN, 24))
	var title := UiKit.sign_label(level.display_name.to_upper(), 92)
	v.add_child(title)
	if world and world.tagline != "":
		v.add_child(UiKit.body(world.tagline, 780, UiKit.SIZE_BODY, UiKit.CREAM))
	v.add_child(UiKit.spacer(UiKit.GAP_XS))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	v.add_child(row)
	var slots := Loadout.run_slots(Game.weapon_id if Game.weapon_id != &"" else Loadout.primary())
	for i in 2:
		var w := GameData.weapon(slots[i])
		if w:
			var plate := UiKit.slot_plate("%s [%d]" % [String(Loadout.SLOT_NAMES[i]).to_upper(), i + 1], w.display_name.to_upper(), UiKit.CYAN)
			plate.active = i == 0
			plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(plate)
	var diff := HBoxContainer.new()
	diff.add_theme_constant_override("separation", UiKit.GAP_S)
	v.add_child(diff)
	diff.add_child(UiKit.label("DIFFICULTY", UiKit.SIZE_LABEL, UiKit.MUTED, true))
	diff.add_child(UiKit.chip(Difficulty.label(Difficulty.current()), UiKit.AMBER, 22))
	var tip_text := level.loading_tips[randi() % level.loading_tips.size()] if level.loading_tips.size() > 0 else "Headshots multiply your score."
	var tip_box := UiKit.neon_panel(accent)
	tip_box.set_padding(26, 14)
	tip_box.custom_minimum_size.x = 860
	var tip_row := HBoxContainer.new()
	tip_row.add_theme_constant_override("separation", UiKit.GAP_M)
	tip_box.add_child(tip_row)
	tip_row.add_child(UiKit.chip("TIP", accent, 22))
	tip_row.add_child(UiKit.body(tip_text, 700, UiKit.SIZE_BODY, Color.WHITE))
	col.add_child(tip_box)
	UiFx.stagger_in.call_deferred([board, tip_box], 0.1, 0.12)
	return col


## "LOADING 42%" over a marquee bar of bulbs along the bottom, plus an accent
## strip at the screen edge.
func _add_progress(root: Control, accent: Color) -> void:
	_status = UiKit.arcade_label("LOADING", 30, Color.WHITE)
	root.add_child(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 120
	_status.offset_right = 700
	_status.offset_top = -150
	_status.offset_bottom = -108
	_bar = _BulbBar.new()
	_bar.accent = accent
	root.add_child(_bar)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_left = 120
	_bar.offset_right = -120
	_bar.offset_top = -104
	_bar.offset_bottom = -58
	var strip := ColorRect.new()
	strip.color = accent
	root.add_child(strip)
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -10


func _process(delta: float) -> void:
	_time += delta
	_pan()
	if _done:
		return
	var prog := []
	var status := ResourceLoader.load_threaded_get_status(level.scene_path, prog)
	if prog.size() > 0:
		_progress = maxf(_progress, float(prog[0]))
	_shown_progress = move_toward(_shown_progress, _progress, delta * 2.5)
	_bar.value = _shown_progress
	_status.text = "LOADING  %d%%" % int(_shown_progress * 100.0)
	# Keep the card up for at least a beat so it reads as intentional.
	if status == ResourceLoader.THREAD_LOAD_LOADED and _time > 1.1:
		_done = true
		_bar.value = 1.0
		_status.text = "LOADING  100%"
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


## Ken Burns: a slow zoom towards the upper right with a slight drift.
func _pan() -> void:
	if _art == null:
		return
	var t := smoothstep(0.0, 1.0, minf(_time / PAN_SECONDS, 1.0))
	var zoom := lerpf(PAN_ZOOM.x, PAN_ZOOM.y, t)
	var screen := _art.get_parent_area_size()
	_art.pivot_offset = screen * Vector2(0.62, 0.42)
	_art.scale = Vector2(zoom, zoom)
	_art.position = Vector2(lerpf(0.0, -screen.x * 0.025, t), 0.0)


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


## The marquee progress bar: a dark rail with a row of bulbs that light up
## as the level loads, the newest one flaring. Redraws only when it changes.
class _BulbBar:
	extends Control
	const SPACING := 40.0
	var accent := UiKit.PINK
	var value := 0.0:
		set(v):
			var lit := int(v * _count())
			value = v
			if lit != _lit:
				_lit = lit
				queue_redraw()
	var _lit := -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _count() -> int:
		return maxi(1, int((size.x - SPACING) / SPACING) + 1)

	func _draw() -> void:
		var rail := UiKit.box(Color(UiKit.INK, 0.86), Color(accent, 0.8), int(size.y * 0.5), 3, 0)
		draw_style_box(rail, Rect2(Vector2.ZERO, size))
		var on := KitTex.tex(&"bulb_on")
		var off := KitTex.tex(&"bulb_off")
		if on == null or off == null:
			return
		var n := _count()
		var bulb := size.y - 12.0
		var step := (size.x - SPACING) / maxf(1.0, n - 1)
		for i in n:
			var c := Vector2(SPACING * 0.5 + step * i, size.y * 0.5)
			var lit := i < _lit
			var r := bulb * (1.2 if lit and i == _lit - 1 else 1.0)
			draw_texture_rect(on if lit else off, Rect2(c - Vector2(r, r) * 0.5, Vector2(r, r)), false)
