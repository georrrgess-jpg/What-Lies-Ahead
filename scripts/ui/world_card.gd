class_name WorldCard
extends Control
## One world in the Play page carousel: the world's key art cropped to the
## rounded card, with the world number and name, tagline, progress stars and
## best score over it, and for a locked world a padlock with the unlock
## requirement. The selected card wears a cream sign trim and glows in the
## world's accent. Without key art the card shows the world's colours.
## Click to select. It only redraws when its state changes.

signal pressed

const SIZE := Vector2(460, 248)
const RADIUS := 22

var world: WorldData
var index := 0
var selected := false:
	set(v):
		if selected != v:
			selected = v
			queue_redraw()
			if _frame:
				_frame.queue_redraw()
var _hover := false
var _title: Label
var _art: TextureRect
## Drawn over the art: lock veil, accent bar, trim and padlock.
var _frame: Control
var _status: Label
var _stars: HBoxContainer
var _bg := StyleBoxFlat.new()
var _bar := StyleBoxFlat.new()
var _border := StyleBoxFlat.new()
var _shade := StyleBoxFlat.new()
var _unlocked := true


## Progress stars of a level, 0-3: a third of the waves, two thirds, cleared.
static func stars(level: LevelData) -> int:
	if level == null:
		return 0
	if Profile.is_level_completed(level.id):
		return 3
	var waves := level.wave_set.waves.size() if level.wave_set else 0
	if waves <= 0:
		return 0
	return clampi(Profile.best_wave(level.id) * 3 / waves, 0, 2)


## A row of three star icons with `count` of them gold.
static func star_row(count: int, icon_size := 30.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		row.add_child(UiKit.icon(&"icon_star" if i < count else &"icon_star_empty", icon_size))
	return row


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_unlocked = GameData.is_world_unlocked(world)
	_add_art()
	_frame = Control.new()
	_frame.size = SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	var v := VBoxContainer.new()
	v.position = Vector2(26, 20)
	# A locked card keeps its title clear of the padlock in the corner.
	v.size = Vector2(SIZE.x - 52 - (64.0 if not _unlocked else 0.0), SIZE.y - 42)
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	v.add_child(UiKit.label("WORLD %d" % (index + 1), 22, world.secondary_color, true))
	_title = UiKit.arcade_label(world.display_name.to_upper(), 40, Color.WHITE)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_constant_override("line_spacing", -10)
	v.add_child(_title)
	var tag := UiKit.label(world.tagline, 20, UiKit.CREAM)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tag)
	v.add_child(UiKit.filler())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", UiKit.GAP_S)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	_stars = star_row(0, 28.0)
	foot.add_child(_stars)
	_status = UiKit.label("", 20, Color.WHITE, true)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_status)
	for l: Label in [tag, _status]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override("font_outline_color", Color(UiKit.INK, 0.85))
		l.add_theme_constant_override("outline_size", 6)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	refresh()


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
	m.set_shader_parameter("radius", float(RADIUS))
	m.set_shader_parameter("shade", world.backdrop_color.darkened(0.35))
	m.set_shader_parameter("saturation", 1.0 if _unlocked else 0.2)
	_art.material = m
	add_child(_art)


## Re-reads progress (stars, best score, lock state).
func refresh() -> void:
	_unlocked = GameData.is_world_unlocked(world)
	var best := 0
	var most := 0
	for l in world.levels:
		best = maxi(best, Profile.best_score(l.id))
		most = maxi(most, stars(l))
	_stars.visible = _unlocked
	for i in _stars.get_child_count():
		(_stars.get_child(i) as TextureRect).texture = KitTex.tex(&"icon_star" if i < most else &"icon_star_empty")
	if _unlocked:
		_status.text = "BEST %s" % ScorePanel._fmt(best) if best > 0 else ("CLEARED" if most >= 3 else "NOT PLAYED YET")
		_status.add_theme_color_override("font_color", Color.WHITE)
	else:
		_status.text = "LOCKED  ·  " + world.requirement.describe()
		_status.add_theme_color_override("font_color", UiKit.AMBER)
	if _art:
		(_art.material as ShaderMaterial).set_shader_parameter("saturation", 1.0 if _unlocked else 0.2)
	queue_redraw()
	_frame.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _set_hover(on: bool) -> void:
	_hover = on
	_frame.queue_redraw()
	if on and not selected:
		UiSound.hover()


## Backing fill and the selection glow (under the art).
func _draw() -> void:
	_bg.bg_color = world.backdrop_color.darkened(0.2)
	_bg.set_corner_radius_all(RADIUS)
	_bg.shadow_color = Color(world.accent_color, 0.5 if selected else 0.0)
	_bg.shadow_size = 20 if selected else 0
	draw_style_box(_bg, Rect2(Vector2.ZERO, size))


## Everything over the art: the lock veil, the accent bar, the trim and the padlock.
func _draw_frame() -> void:
	var accent := world.accent_color
	var r := Rect2(Vector2.ZERO, size)
	if not _unlocked:
		_shade.bg_color = Color(0.02, 0.0, 0.06, 0.45)
		_shade.set_corner_radius_all(RADIUS)
		_frame.draw_style_box(_shade, r)
	_bar.bg_color = accent
	_bar.corner_radius_bottom_left = RADIUS
	_bar.corner_radius_bottom_right = RADIUS
	_frame.draw_style_box(_bar, Rect2(0, size.y - 10, size.x, 10))
	_border.draw_center = false
	_border.set_corner_radius_all(RADIUS)
	_border.border_color = UiKit.CREAM if selected else Color(accent, 0.9 if _hover else 0.5)
	_border.set_border_width_all(6 if selected else 3)
	_border.anti_aliasing = true
	_frame.draw_style_box(_border, r)
	if not _unlocked:
		_frame.draw_texture_rect(KitTex.tex(&"icon_lock"), Rect2(size.x - 86, 16, 64, 64), false)
