class_name KitChip
extends PanelContainer
## Chip / tag: a small coloured plate with dark lettering ("AUTO · RANK 0",
## "NEW", "EQUIPPED", a rarity). Pointed chips have the arrow ends of the
## reference; round ones are plain pills.
##
##   row.add_child(UiKit.chip("AUTO · RANK 3"))
##   row.add_child(UiKit.chip("NEW", UiKit.PINK, 18, false))

var _box: StyleBoxFlat
var _label: Label


static func make(text: String, color := UiKit.CYAN, font_size := 20, pointed := true) -> KitChip:
	var c := KitChip.new()
	c._build(text, color, font_size, pointed)
	return c


func _build(text: String, color: Color, font_size: int, pointed: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# A huge radius clamps to half the height: a pill, or with one segment per
	# corner, a plate with pointed ends.
	_box = UiKit.box(color, Color.TRANSPARENT, 64, 0, 0)
	_box.corner_detail = 1 if pointed else 8
	_box.content_margin_left = font_size * (1.0 if pointed else 0.55)
	_box.content_margin_right = _box.content_margin_left
	_box.border_width_bottom = maxi(2, font_size / 8)
	add_theme_stylebox_override("panel", _box)
	_label = UiKit.label(text, font_size, UiKit.INK, true)
	_label.add_theme_constant_override("shadow_offset_y", 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	set_color(color)


func set_text(text: String) -> void:
	_label.text = text


## Recolours the chip; the lettering turns cream on dark colours.
func set_color(color: Color) -> void:
	_box.bg_color = color
	_box.border_color = color.darkened(0.28)
	_label.add_theme_color_override("font_color", UiKit.INK if color.get_luminance() > 0.35 else UiKit.CREAM)
