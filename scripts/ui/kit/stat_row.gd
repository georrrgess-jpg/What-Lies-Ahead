class_name StatRow
extends HBoxContainer
## One stat: its name in cream capitals on the left and the value on the
## right, like the six stats of the Arsenal signboard. With a bar, a slim
## meter sits between them.
##
##   var dps := UiKit.stat_row("DPS")
##   dps.set_value("131")                  # text only
##   var range := UiKit.stat_row("RANGE", "", true)
##   range.set_value("36 m", 0.6)          # text and a bar at 60%

var _caption: Label
var _value: Label
var _bar: ProgressBar


static func make(caption: String, value := "", with_bar := false) -> StatRow:
	var r := StatRow.new()
	r._build(caption, value, with_bar)
	return r


func _build(caption: String, value: String, with_bar: bool) -> void:
	add_theme_constant_override("separation", UiKit.GAP_M)
	_caption = UiKit.label(caption, 28, UiKit.CREAM, true)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_caption)
	if with_bar:
		_caption.size_flags_horizontal = Control.SIZE_FILL
		_caption.custom_minimum_size.x = 170
		_bar = UiKit.progress(0.0, 14.0)
		_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(_bar)
	_value = UiKit.label(value, 28, Color.WHITE)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value.custom_minimum_size.x = 76
	add_child(_value)


## Sets the value text and, for a row with a bar, the bar (0-1, animated).
func set_value(text: String, fraction := -1.0) -> void:
	_value.text = text
	if _bar and fraction >= 0.0:
		if is_visible_in_tree():
			UiFx.fill_to(_bar, clampf(fraction, 0.0, 1.0))
		else:
			_bar.value = clampf(fraction, 0.0, 1.0)


## Colour of the bar's fill.
func set_bar_color(color: Color) -> void:
	if _bar:
		_bar.add_theme_stylebox_override("fill", UiKit.bar_fill(color, 14.0))


## Font size of the caption and value (default 28).
func set_font_size(font_size: int) -> void:
	_caption.add_theme_font_size_override("font_size", font_size)
	_value.add_theme_font_size_override("font_size", font_size)
