class_name WorldCard
extends Control
## One world in the Play page carousel: the world's key art cropped to the
## rounded card, with the world number and name, tagline, level count and best
## score over it in the world's accent styling, and a lock overlay with the
## unlock requirement. Without key art the card shows accent stripes instead.
## Click to select.

signal pressed

const SIZE := Vector2(520, 280)

var world: WorldData
var index := 0
var selected := false
var _hover := 0.0
var _time := 0.0
var _title: Label
var _art: TextureRect
## Drawn over the art: accent stripes, bottom bar, border and padlock.
var _frame: Control
var _tag: Label
var _status: Label
## Reused every frame (the card redraws while it animates).
var _bg := StyleBoxFlat.new()
var _bar := StyleBoxFlat.new()
var _border := StyleBoxFlat.new()
var _shade := StyleBoxFlat.new()
var _unlocked := -1


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_add_art()
	_frame = Control.new()
	_frame.size = SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	var v := VBoxContainer.new()
	v.position = Vector2(30, 26)
	v.size = Vector2(SIZE.x - 60, SIZE.y - 50)
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var num := UiKit.label("WORLD %d" % (index + 1), 24, world.secondary_color, true)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(num)
	_title = UiKit.arcade_label(world.display_name.to_upper(), 46, Color.WHITE)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_title)
	_tag = UiKit.label(world.tagline, 22, UiKit.CREAM)
	_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_tag)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	_status = UiKit.label("", 22, Color.WHITE, true)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_status)
	if _art:
		# Over the art, the small text gets an ink outline to stay crisp.
		for l in [_tag, _status]:
			l.add_theme_color_override("font_outline_color", Color(UiKit.INK, 0.85))
			l.add_theme_constant_override("outline_size", 6)
	_refresh_status()


## The first level's key art, rounded and shaded so the text reads over it.
func _add_art() -> void:
	var texture := KeyArt.texture(world.levels[0]) if not world.levels.is_empty() else null
	if texture == null:
		return
	_art = TextureRect.new()
	_art.texture = texture
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.size = SIZE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(KeyArt.CARD_SHADER)
	m.set_shader_parameter("rect_size", SIZE)
	m.set_shader_parameter("radius", 26.0)
	m.set_shader_parameter("shade", world.backdrop_color.darkened(0.35))
	m.set_shader_parameter("saturation", 1.0 if GameData.is_world_unlocked(world) else 0.2)
	_art.material = m
	add_child(_art)


func _refresh_status() -> void:
	var cleared := 0
	var best := 0
	for l in world.levels:
		if Profile.is_level_completed(l.id):
			cleared += 1
		best = maxi(best, Profile.best_score(l.id))
	if not GameData.is_world_unlocked(world):
		_status.text = "LOCKED  ·  " + world.requirement.describe()
		_status.add_theme_color_override("font_color", UiKit.AMBER)
	else:
		_status.text = "%d/%d CLEARED   ·   BEST %s" % [cleared, world.levels.size(), ScorePanel._fmt(best)]
		_status.add_theme_color_override("font_color", Color.WHITE)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _process(delta: float) -> void:
	_time += delta
	var want := 1.0 if Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()) else 0.0
	_hover = move_toward(_hover, want, delta * 6.0)
	queue_redraw()
	_frame.queue_redraw()


## Backing fill and the selection glow (under the art).
func _draw() -> void:
	var bg := _bg
	bg.bg_color = world.backdrop_color.darkened(0.2)
	bg.set_corner_radius_all(26)
	bg.set_border_width_all(0)
	bg.shadow_color = Color(world.accent_color, 0.45 if selected else 0.0)
	bg.shadow_size = 18 if selected else 0
	draw_style_box(bg, Rect2(Vector2.ZERO, size))


## Everything over the art: stripes (plain cards only), the accent bar, the
## border and the padlock.
func _draw_frame() -> void:
	var accent := world.accent_color
	var r := Rect2(Vector2.ZERO, size)
	if _art == null:
		# Diagonal accent stripes on the right, drifting slowly.
		var off := fmod(_time * 12.0, 46.0)
		for i in 9:
			var x := size.x - 230.0 + i * 46.0 - off
			var c := accent if i % 2 == 0 else world.secondary_color
			var pts := PackedVector2Array([Vector2(x, 8), Vector2(x + 22, 8), Vector2(x + 22 - 90, size.y - 8), Vector2(x - 90, size.y - 8)])
			var clip := PackedVector2Array()
			for p in pts:
				clip.append(Vector2(clampf(p.x, size.x * 0.55, size.x - 12), p.y))
			_frame.draw_colored_polygon(clip, Color(c, 0.18))
	if _unlocked < 0:
		_unlocked = 1 if GameData.is_world_unlocked(world) else 0
	if _unlocked == 0:
		_frame.draw_style_box(_lock_shade(), r)
	# Accent bar along the bottom.
	var bar := _bar
	bar.bg_color = accent
	bar.corner_radius_bottom_left = 26
	bar.corner_radius_bottom_right = 26
	_frame.draw_style_box(bar, Rect2(0, size.y - 12, size.x, 12))
	var border := _border
	border.draw_center = false
	border.set_corner_radius_all(26)
	border.border_color = accent if selected else Color(accent, 0.45 + 0.4 * _hover)
	border.set_border_width_all(5 if selected else 3)
	border.anti_aliasing = true
	_frame.draw_style_box(border, r)
	if _unlocked == 0:
		# Padlock.
		var c := Vector2(size.x - 70, 60)
		_frame.draw_arc(c + Vector2(0, -8), 16, PI, TAU, 16, UiKit.AMBER, 6.0, true)
		_frame.draw_rect(Rect2(c + Vector2(-22, -6), Vector2(44, 34)), UiKit.AMBER)
		_frame.draw_circle(c + Vector2(0, 10), 5, UiKit.INK)


## Rounded dark veil over a locked world.
func _lock_shade() -> StyleBoxFlat:
	var shade := _shade
	shade.bg_color = Color(0.02, 0.0, 0.06, 0.45)
	shade.set_corner_radius_all(26)
	return shade
