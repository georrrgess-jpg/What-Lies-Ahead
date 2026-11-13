class_name CareerTile
extends Button
## A dark kit tile on the Career page that can take keyboard focus: a
## contract, a milestone, a weapon's mastery. Its content is whatever is added
## to `body`; `detail` is the longer text the page shows for the tile that is
## focused or under the pointer (the page listens to `highlighted`).

## The tile got keyboard focus or the pointer.
signal highlighted(tile: CareerTile)

## One or two sentences about the tile, shown by the page.
var detail := ""
## Add the tile's content here.
var body: VBoxContainer
var _lifted := false


static func make(min_size: Vector2, padding := 14) -> CareerTile:
	var t := CareerTile.new()
	t.custom_minimum_size = min_size
	t._build(padding)
	return t


func _build(padding: int) -> void:
	focus_mode = Control.FOCUS_ALL
	add_theme_stylebox_override("normal", KitTex.box(&"card"))
	add_theme_stylebox_override("hover", KitTex.box(&"card_hover"))
	add_theme_stylebox_override("pressed", KitTex.box(&"card_hover"))
	add_theme_stylebox_override("focus", KitTex.box(&"focus_ring"))
	body = VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, padding)
	body.add_theme_constant_override("separation", UiKit.GAP_XS)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	mouse_entered.connect(_update_lift.bind(true))
	mouse_exited.connect(_update_lift.bind(false))
	focus_entered.connect(_update_lift.bind(true))
	focus_exited.connect(_update_lift.bind(false))


## Marks the tile with the outline of a selected card (the next level, a
## finished contract).
func set_marked(on: bool) -> void:
	add_theme_stylebox_override("normal", KitTex.box(&"card_selected" if on else &"card"))


func _update_lift(entering: bool) -> void:
	var want := is_hovered() or has_focus()
	if want and entering:
		highlighted.emit(self)
	if want == _lifted:
		return
	_lifted = want
	UiFx.hover(self, want, 1.03)
	if want and entering:
		UiSound.hover()
