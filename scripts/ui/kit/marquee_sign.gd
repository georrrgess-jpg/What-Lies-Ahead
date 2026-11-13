class_name MarqueeSign
extends Control
## Marquee sign: a crimson board in a gold frame with a row of light bulbs
## chasing around it and chunky cream lettering. Used for page titles.
##
##   var sign := UiKit.marquee("ARSENAL")
##   sign.flash()          # all bulbs on for a moment (the page just opened)
##
## The bulbs step a few times a second from a Timer; nothing runs per frame.

## Seconds between chase steps.
const STEP := 0.16
## Every CHASE-th bulb is lit, and the lit ones travel around the sign.
const CHASE := 3
const BULB_SPACING := 46.0
const BULB_SIZE := 34.0
## Centre line of the frame, inside the control's rectangle.
const RAIL := 11.0
const CORNER := 26.0

var text := "":
	set(v):
		text = v
		if _label:
			_label.text = v
			_fit()
var font_size := 72
var _label: Label
var _phase := 0
var _flash := 0
var _bulbs := PackedVector2Array()
var _timer: Timer


static func make(text_value: String, size_px := 72) -> MarqueeSign:
	var s := MarqueeSign.new()
	s.font_size = size_px
	s.text = text_value
	return s


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UiKit.sign_label(text, font_size)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_timer = Timer.new()
	_timer.wait_time = STEP
	_timer.autostart = true
	_timer.timeout.connect(_step)
	add_child(_timer)
	resized.connect(_place_bulbs)
	visibility_changed.connect(func(): _timer.paused = not is_visible_in_tree())
	_fit()


## All bulbs on for a moment, then the chase resumes.
func flash() -> void:
	_flash = 4
	queue_redraw()


func _fit() -> void:
	var text_size := UiKit.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	custom_minimum_size = Vector2(text_size.x + font_size * 1.5, font_size * 1.1 + 62.0)
	_place_bulbs()


## Bulb centres: evenly along the four straight runs of the frame.
func _place_bulbs() -> void:
	_bulbs.clear()
	var w := size.x
	var h := size.y
	if w < 2.0 * CORNER or h < 2.0 * CORNER:
		return
	var nx := maxi(2, int(round((w - 2.0 * CORNER) / BULB_SPACING)) + 1)
	var ny := maxi(1, int(round((h - 2.0 * CORNER) / BULB_SPACING)) - 1)
	for i in nx:
		_bulbs.append(Vector2(lerpf(CORNER, w - CORNER, float(i) / (nx - 1)), RAIL))
	for i in ny:
		_bulbs.append(Vector2(w - RAIL, lerpf(CORNER, h - CORNER, float(i + 1) / (ny + 1))))
	for i in nx:
		_bulbs.append(Vector2(lerpf(w - CORNER, CORNER, float(i) / (nx - 1)), h - RAIL))
	for i in ny:
		_bulbs.append(Vector2(RAIL, lerpf(h - CORNER, CORNER, float(i + 1) / (ny + 1))))
	queue_redraw()


func _step() -> void:
	_phase = (_phase + 1) % CHASE
	if _flash > 0:
		_flash -= 1
	queue_redraw()


func _draw() -> void:
	draw_style_box(KitTex.box(&"marquee"), Rect2(Vector2.ZERO, size))
	var on := KitTex.tex(&"bulb_on")
	var off := KitTex.tex(&"bulb_off")
	if on == null or off == null:
		return
	var half := Vector2(BULB_SIZE, BULB_SIZE) * 0.5
	var rect := Rect2(Vector2.ZERO, Vector2(BULB_SIZE, BULB_SIZE))
	for i in _bulbs.size():
		rect.position = _bulbs[i] - half
		var lit := _flash > 0 or (i + _phase) % CHASE == 0
		draw_texture_rect(on if lit else off, rect, false)
