class_name MenuNavTile
extends Button
## A section tile on the home screen (ARSENAL, LOCKER, SHOP, PRIZES, CAREER,
## SETTINGS): an icon, the section's name in sign lettering and one line of
## what is waiting there ("95 new", "1 capsule", "2 / 3 contracts"), with a
## pink count badge on the corner when something is new. A card that grows a
## little and lifts its icon on hover and keyboard focus.

const SIZE := Vector2(180, 100)
const ICON := 40.0

## The page the tile opens.
var page_id := ""
var _icon_holder: CenterContainer
var _title: Label
var _note: Label
var _badge: KitChip


static func make(id: String, title: String, icon: Control) -> MenuNavTile:
	var t := MenuNavTile.new()
	t.page_id = id
	t.name = "Nav_" + id
	t._build(title, icon)
	return t


func _build(title: String, icon: Control) -> void:
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_ALL
	add_theme_stylebox_override("normal", KitTex.box(&"card"))
	add_theme_stylebox_override("hover", KitTex.box(&"card_hover"))
	add_theme_stylebox_override("pressed", KitTex.box(&"card_hover"))
	add_theme_stylebox_override("focus", KitTex.box(&"focus_ring"))
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	col.add_theme_constant_override("separation", -2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiKit.GAP_S)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_icon_holder = CenterContainer.new()
	_icon_holder.custom_minimum_size = Vector2(ICON, ICON)
	_icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_holder.add_child(icon)
	top.add_child(_icon_holder)
	_title = UiKit.sign_label(title, 26)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_title)
	_note = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED)
	_note.clip_text = true
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_note)
	_badge = UiKit.chip("", UiKit.PINK, UiKit.SIZE_SMALL, false)
	_badge.visible = false
	add_child(_badge)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	_badge.position += Vector2(-10, -12)
	mouse_entered.connect(func():
		UiSound.hover()
		_lift(true))
	mouse_exited.connect(func(): if not has_focus(): _lift(false))
	focus_entered.connect(_lift.bind(true))
	focus_exited.connect(_lift.bind(false))
	resized.connect(func(): pivot_offset = size * 0.5)


## The line under the name: cream when it is news, muted when not.
func set_note(text: String, news := false) -> void:
	_note.text = text
	_note.add_theme_color_override("font_color", UiKit.CREAM if news else UiKit.MUTED)


## A count badge on the corner (hidden at 0).
func set_badge(count: int) -> void:
	_badge.visible = count > 0
	if count > 0:
		_badge.set_text(str(count) if count < 100 else "99+")


func _lift(on: bool) -> void:
	UiFx.hover(self, on, 1.05)
	_icon_holder.pivot_offset = _icon_holder.size * 0.5
	var k := 1.18 if on else 1.0
	_icon_holder.create_tween().tween_property(_icon_holder, "scale", Vector2(k, k), UiFx.FAST * 1.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _pressed() -> void:
	UiSound.click()
	UiFx.squash(self, scale.x)


## The Arsenal's icon: a chunky toy blaster in profile.
static func blaster_icon(icon_size := ICON) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(icon_size, icon_size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var k := icon_size / 44.0
		var body := PackedVector2Array([Vector2(4, 12), Vector2(34, 12), Vector2(38, 16), Vector2(38, 22),
			Vector2(20, 22), Vector2(16, 36), Vector2(8, 36), Vector2(10, 22), Vector2(4, 22)])
		for i in body.size():
			body[i] *= k
		var outline := body.duplicate()
		outline.append(body[0])
		c.draw_colored_polygon(body, UiKit.CYAN)
		c.draw_polyline(outline, UiKit.INK, 3.0 * k, true)
		c.draw_rect(Rect2(Vector2(38, 15) * k, Vector2(4, 6) * k), UiKit.PINK)
		c.draw_rect(Rect2(Vector2(8, 15) * k, Vector2(20, 3) * k), Color(1, 1, 1, 0.55))
		c.draw_circle(Vector2(30, 17) * k, 2.5 * k, UiKit.AMBER, true, -1.0, true))
	return c
