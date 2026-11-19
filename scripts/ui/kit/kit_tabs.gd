class_name KitTabs
extends HBoxContainer
## A row of tabs: toggle sign buttons (purple, the selected one pink) that
## behave as one group. Left/right moves between them with the keyboard or a
## gamepad; step() lets a page bind shoulder buttons or Q/E.
##
##   var tabs := UiKit.tabs()
##   tabs.add_tab(&"mastery", "WEAPON MASTERY")
##   tabs.add_tab(&"challenges", "CHALLENGES", 3)   # with a count badge
##   tabs.tab_changed.connect(_show_tab)
##   tabs.select(&"mastery")

## The player picked another tab (not emitted by select() unless asked).
signal tab_changed(id: StringName)

## Padding (px) moved from a badged tab's left side to its right.
const BADGE_ROOM := 14.0

var current: StringName
var _group := ButtonGroup.new()
var _buttons := {}
var _order: Array[StringName] = []
var _font_size := 26
var _quiet := false


## `quiet` tabs are dark when off (for rows on a dark bar) instead of purple.
static func make(font_size := 26, quiet := false) -> KitTabs:
	var t := KitTabs.new()
	t._font_size = font_size
	t._quiet = quiet
	t.add_theme_constant_override("separation", UiKit.GAP_S)
	return t


## Adds a tab and returns its button. `badge` > 0 shows a small count on it.
func add_tab(id: StringName, text: String, badge := 0) -> SignButton:
	var b := SignButton.make_tab(text, _group, _font_size) if _quiet else SignButton.make_toggle(text, _group, _font_size)
	b.pressed.connect(_on_pressed.bind(id))
	add_child(b)
	_buttons[id] = b
	_order.append(id)
	set_badge(id, badge)
	if _order.size() == 1:
		current = id
		b.set_pressed_no_signal(true)
	return b


## The button of a tab (null if there is none).
func button(id: StringName) -> SignButton:
	return _buttons.get(id)


## Shows `count` in a small gold badge on the tab (0 hides it).
func set_badge(id: StringName, count: int) -> void:
	var b: SignButton = _buttons.get(id)
	if b == null:
		return
	var badge := b.get_node_or_null("Badge") as KitChip
	if count <= 0:
		if badge:
			badge.visible = false
		return
	if badge == null:
		badge = KitChip.make("", UiKit.AMBER, 16, false)
		badge.name = "Badge"
		b.add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		# Inside the tab's top right corner, clear of the frame above the row
		# and of the neighbouring tab (it grows to the left as the count widens).
		badge.position += Vector2(-6, 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reserve_badge_room(b)
	badge.visible = true
	badge.set_text(str(count))


## Shifts the tab's label left by moving `BADGE_ROOM` of padding from its
## left side to its right, so the label never runs under the badge and the
## tab keeps its width (rows of tabs such as the Shop's still fit).
func _reserve_badge_room(b: SignButton) -> void:
	for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		var box := b.get_theme_stylebox(state)
		if box == null:
			continue
		var wide := box.duplicate() as StyleBox
		var moved := minf(BADGE_ROOM, box.get_margin(SIDE_LEFT) - 8.0)
		wide.content_margin_left = box.get_margin(SIDE_LEFT) - moved
		wide.content_margin_right = box.get_margin(SIDE_RIGHT) + moved
		# KitTex.fit_frames rebuilds a squeezed frame from this base.
		wide.set_meta(&"kit_base", wide)
		b.add_theme_stylebox_override(state, wide)


## The tab ids, left to right.
func ids() -> Array[StringName]:
	return _order


## No tab selected (the screen shows something that is not one of the tabs).
func clear_selection() -> void:
	current = &""
	for id in _buttons:
		(_buttons[id] as SignButton).set_pressed_no_signal(false)


## Selects a tab. `emit` true also emits tab_changed.
func select(id: StringName, emit := false) -> void:
	var b: SignButton = _buttons.get(id)
	if b == null:
		return
	current = id
	for key in _buttons:
		(_buttons[key] as SignButton).set_pressed_no_signal(key == id)
	if emit:
		tab_changed.emit(id)


## Moves to the next (1) or previous (-1) tab, wrapping, and emits tab_changed.
func step(direction: int) -> void:
	if _order.is_empty():
		return
	var i := posmod(_order.find(current) + direction, _order.size())
	UiSound.tab()
	select(_order[i], true)


func _on_pressed(id: StringName) -> void:
	if id == current:
		return
	current = id
	tab_changed.emit(id)
