class_name HudWave
extends VBoxContainer
## The HUD's wave header (upper left): "WAVE 03 / 08", under it a chip with
## the round type or the phase (INTERMISSION, ALL CLEAR) and, during a wave,
## how many zombies are left with a bar that empties as they pop.
##
## Everything is set from outside and only touches a label when its value
## really changed, so it is free while nothing happens.

## The big "WAVE 03" label (the staging tools set its text directly).
var title: Label
var _total: Label
var _chip: KitChip
var _left_row: HBoxContainer
var _left: Label
var _bar: ProgressBar
var _number := -1
var _total_waves := -1
var _remaining := -1
var _chip_text := ""


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", -6)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 12)
	add_child(head)
	title = UiKit.arcade_label("WAVE 01", 76)
	head.add_child(title)
	_total = UiKit.arcade_label("", 36, UiKit.MUTED)
	_total.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_total)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	_chip = UiKit.chip("", UiKit.CYAN, 24)
	_chip.visible = false
	row.add_child(_chip)
	_left_row = HBoxContainer.new()
	_left_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_row.add_theme_constant_override("separation", 8)
	_left_row.visible = false
	row.add_child(_left_row)
	_left_row.add_child(HudIcon.make(&"zombie", 30.0, UiKit.GREEN))
	_left = UiKit.arcade_label("0", 34, UiKit.CREAM)
	_left.custom_minimum_size.x = 44
	_left_row.add_child(_left)
	_bar = UiKit.progress(1.0, 12.0, UiKit.GREEN)
	_bar.custom_minimum_size = Vector2(150, 12)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_left_row.add_child(_bar)


## Shows wave `number` of `total` (pops when the number changes).
func set_wave(number: int, total: int) -> void:
	if number == _number and total == _total_waves:
		return
	var changed := number != _number and _number >= 0
	_number = number
	_total_waves = total
	title.text = "WAVE %02d" % maxi(1, number)
	_total.text = "/ %02d" % total
	if changed and is_visible_in_tree():
		UiFx.pulse(title, 1.12)


## The chip under the wave number: a round type ("BLITZ") or a phase
## ("INTERMISSION"). An empty text hides it.
func set_chip(text: String, color := UiKit.CYAN) -> void:
	if text == _chip_text:
		return
	_chip_text = text
	_chip.visible = text != ""
	if text == "":
		return
	_chip.set_text(text)
	_chip.set_color(color)
	if is_visible_in_tree():
		UiFx.pulse(_chip, 1.1)


## Zombies still to pop in this wave, out of `total`. A negative count hides
## the counter (between waves).
func set_remaining(left: int, total: int) -> void:
	if left == _remaining:
		return
	var dropped := left < _remaining
	_remaining = left
	_left_row.visible = left >= 0
	if left < 0:
		return
	_left.text = str(left)
	_bar.value = float(left) / maxf(1.0, total)
	if dropped and left <= 3 and is_visible_in_tree():
		UiFx.pulse(_left, 1.25)
