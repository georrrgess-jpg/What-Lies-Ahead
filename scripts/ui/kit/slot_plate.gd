class_name SlotPlate
extends PanelContainer
## Slot plate: a dark plate with a neon outline holding a small caption over
## a big value, like the "PRIMARY [1] / ION CARBINE" plates of the Arsenal.
## `active` plates glow in their accent; inactive ones wear a cream outline.
##
##   var plate := UiKit.slot_plate("PRIMARY [1]", "ION CARBINE")
##   plate.set_value("PULSE PISTOL")     # pops when the value changes
##   plate.set_note("Pistol · Rank 2")   # small text at the top right

var accent := UiKit.CYAN:
	set(v):
		accent = v
		_restyle()
## The glowing plate is the one in use; the others are cream.
var active := true:
	set(v):
		active = v
		_restyle()
var _box: StyleBoxTexture
var _caption: Label
var _note: Label
var _value: Label


static func make(caption: String, value: String, plate_accent := UiKit.CYAN) -> SlotPlate:
	var p := SlotPlate.new()
	p._build(caption, value)
	p.accent = plate_accent
	return p


func _build(caption: String, value: String) -> void:
	_box = KitTex.box_copy(&"neon_plate", accent, Vector2(22, 8))
	add_theme_stylebox_override("panel", _box)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_caption = UiKit.label(caption, 22, accent, true)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_caption)
	_note = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED)
	head.add_child(_note)
	_value = UiKit.sign_label(value, 36)
	col.add_child(_value)


func set_caption(text: String) -> void:
	_caption.text = text


## Small muted text at the top right ("Carbine · Rank 3"). "" hides it.
func set_note(text: String) -> void:
	_note.text = text


## Changes the value; pops the plate if it is different from before.
func set_value(text: String) -> void:
	if _value.text == text:
		return
	_value.text = text
	if is_visible_in_tree():
		UiFx.pulse(self, 1.05)


func _restyle() -> void:
	if _box == null:
		return
	var c := accent if active else UiKit.CREAM
	_box.modulate_color = c
	_caption.add_theme_color_override("font_color", accent)
