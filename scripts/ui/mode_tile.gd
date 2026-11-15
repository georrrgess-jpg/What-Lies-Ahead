class_name ModeTile
extends Button
## One of the Play page's two mode tabs (STORY, ENDLESS): a large card with
## the mode's emblem (a ringed toy planet for the story's worlds, the Endless
## emblem), its name, a line about it and an optional NEW badge. Toggle
## buttons in one group: the picked tab wears the selected card and a bar
## in its accent. Focusable; grows a little on hover and focus like the
## kit's cards.

const SIZE := Vector2(392, 104)
const EMBLEM := 80.0
const STORY_ACCENT := UiKit.CYAN

## &"story" or &"endless".
var mode: StringName
var accent := UiKit.CYAN
var _note: Label
var _badge: KitChip
var _bar := StyleBoxFlat.new()


static func make(mode_id: StringName, title: String, accent_color: Color, group: ButtonGroup) -> ModeTile:
	var t := ModeTile.new()
	t.mode = mode_id
	t.accent = accent_color
	t.button_group = group
	t._build(title)
	return t


func _build(title: String) -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = SIZE
	add_theme_stylebox_override("normal", KitTex.box(&"card"))
	add_theme_stylebox_override("hover", KitTex.box(&"card_hover"))
	add_theme_stylebox_override("pressed", KitTex.box(&"card_selected"))
	add_theme_stylebox_override("hover_pressed", KitTex.box(&"card_selected"))
	add_theme_stylebox_override("focus", KitTex.box(&"focus_ring"))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	row.offset_left = 14
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var icon: Control = EndlessEmblem.make(EMBLEM) if mode == &"endless" else _story_icon()
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var name_label := UiKit.sign_label(title, 46)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_label)
	_note = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED, true)
	_note.clip_text = true
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_note)
	_badge = UiKit.chip("NEW", UiKit.PINK, 20, false)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	add_child(_badge)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	_badge.position += Vector2(8, -8)
	toggled.connect(func(_on: bool) -> void: refresh_state())
	mouse_entered.connect(func():
		UiSound.hover()
		UiFx.hover(self, true, 1.03))
	mouse_exited.connect(func(): if not has_focus(): UiFx.hover(self, false))
	focus_entered.connect(func(): UiFx.hover(self, true, 1.03))
	focus_exited.connect(func(): UiFx.hover(self, false))
	resized.connect(func(): pivot_offset = size * 0.5)


## Follows the pressed state (also after set_pressed_no_signal()).
func refresh_state() -> void:
	_note.add_theme_color_override("font_color", UiKit.CREAM if button_pressed else UiKit.MUTED)
	queue_redraw()


func set_note(text: String) -> void:
	_note.text = text


## The NEW badge in the corner (pops in when it appears).
func set_new(on: bool) -> void:
	if on and not _badge.visible and is_visible_in_tree():
		UiFx.pop_in(_badge)
	_badge.visible = on


## The accent bar along the bottom of the picked tab.
func _draw() -> void:
	if not button_pressed:
		return
	_bar.bg_color = accent
	_bar.set_corner_radius_all(4)
	draw_style_box(_bar, Rect2(28, size.y - 9, size.x - 56, 6))


## The story's emblem: a ringed toy planet in a cyan ring, two stars by it.
func _story_icon() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(EMBLEM, EMBLEM)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): paint_story(c, c.size * 0.5, EMBLEM * 0.5 / 1.12))
	return c


## Draws the story emblem on `ci` at `at`, `r` px to the outside of its ring.
static func paint_story(ci: CanvasItem, at: Vector2, r: float) -> void:
	ci.draw_circle(at, r * 1.12, Color(STORY_ACCENT, 0.2), true, -1.0, true)
	ci.draw_circle(at, r * 0.88, UiKit.NAVY, true, -1.0, true)
	var ring := PackedVector2Array()
	var tilt := Transform2D(-0.38, Vector2.ZERO)
	for i in 41:
		var a := TAU * i / 40.0
		ring.append(at + tilt * (Vector2(cos(a), sin(a) * 0.3) * r * 0.66))
	# The back half of the orbit, the planet, then the front half over it.
	ci.draw_polyline(ring.slice(20, 41), UiKit.PINK.darkened(0.25), r * 0.09, true)
	ci.draw_circle(at, r * 0.4, Color(0.25, 0.75, 0.95), true, -1.0, true)
	ci.draw_circle(at + Vector2(r * 0.1, r * 0.1), r * 0.3, Color(0.16, 0.55, 0.85), true, -1.0, true)
	ci.draw_circle(at + Vector2(-r * 0.14, -r * 0.14), r * 0.1, Color(1, 1, 1, 0.55), true, -1.0, true)
	ci.draw_polyline(ring.slice(0, 21), UiKit.PINK, r * 0.09, true)
	for s in [[Vector2(-0.52, -0.42), 0.09], [Vector2(0.5, 0.44), 0.07], [Vector2(0.44, -0.5), 0.05]]:
		_star(ci, at + (s[0] as Vector2) * r, r * float(s[1]))
	ci.draw_arc(at, r * 0.94, 0.0, TAU, 48, STORY_ACCENT, maxf(2.0, r * 0.12), true)


## A four-point twinkle.
static func _star(ci: CanvasItem, at: Vector2, s: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 2.2), at + Vector2(s * 0.6, 0), at + Vector2(0, s * 2.2), at + Vector2(-s * 0.6, 0)]), Wallet.COLOR)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 2.2, 0), at + Vector2(0, -s * 0.6), at + Vector2(s * 2.2, 0), at + Vector2(0, s * 0.6)]), Wallet.COLOR)
