class_name ArsenalDock
extends KitPanel
## The Arsenal's bottom dock: one category's weapons as wide cards, a page
## of `per_page` at a time, between the previous / next page buttons, with
## the page count under the next button. Every card is reachable: by the
## buttons, the mouse wheel, the triggers, or by moving the keyboard focus
## past the first or last card of a page. Showing a weapon turns to its page.

signal chosen(w: WeaponData)
## A page of cards was shown (paging, a category switch, a resize).
signal page_shown

const PAGER_WIDTH := 64.0

var per_page := 6
var page := 0
## The width the dock is given (the page's width): the cards share it.
var _room := 0.0
## Weapon id -> its card (every weapon of both categories; only the shown
## category's page is visible).
var _cards := {}
## The shown category's cards, in order.
var _list: Array[ArsenalCard] = []
var _row: HBoxContainer
var _prev: SignButton
var _next: SignButton
var _count: Label
var _fade: Tween


func _init() -> void:
	kind = Kind.METAL
	_style()
	var row := HBoxContainer.new()
	row.name = "DockRow"
	row.add_theme_constant_override("separation", UiKit.GAP_S)
	add_child(row)
	_prev = _pager(&"icon_arrow_left", "Previous page", -1)
	row.add_child(_pager_column(_prev, null))
	_row = HBoxContainer.new()
	_row.name = "Cards"
	_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_theme_constant_override("separation", UiKit.GAP_S)
	row.add_child(_row)
	_next = _pager(&"icon_arrow_right", "Next page", 1)
	_count = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED, true)
	_count.name = "PageCount"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_pager_column(_next, _count))


func _pager(icon_name: StringName, tip: String, step: int) -> SignButton:
	var b := UiKit.icon_button(icon_name, tip)
	b.name = "PagePrev" if step < 0 else "PageNext"
	b.focus_mode = Control.FOCUS_CLICK
	b.pressed.connect(turn.bind(step))
	return b


## A pager button centred in a fixed-width column (with the page count under it).
func _pager_column(button: SignButton, under: Label) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = PAGER_WIDTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", UiKit.GAP_XS)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(button)
	if under:
		col.add_child(under)
	else:
		col.add_child(UiKit.spacer(_count_height()))
	return col


func _count_height() -> float:
	return UiKit.SIZE_SMALL * 1.4


## Makes a card for every weapon of `weapons` (once).
func build(weapons: Array[WeaponData]) -> void:
	for w in weapons:
		var card := ArsenalCard.make(w)
		card.visible = false
		card.pressed.connect(func(): chosen.emit(w))
		card.gui_input.connect(_on_card_input.bind(card))
		_row.add_child(card)
		_cards[w.id] = card


## Shows the cards of `weapons` (a category), from the page holding `focus_id`.
func show_list(weapons: Array[WeaponData], focus_id: StringName) -> void:
	_list.clear()
	for w in weapons:
		_list.append(_cards[w.id])
	page = 0
	show_weapon(focus_id, false)
	_apply_page(false)


func set_per_page(count: int) -> void:
	if count == per_page:
		return
	var first := page * per_page
	per_page = count
	page = clampi(first / per_page, 0, pages() - 1)
	_apply_page(false)
	_size_cards()


func pages() -> int:
	return maxi(1, ceili(float(_list.size()) / per_page))


## Turns to the page holding weapon `id` (if it is in the shown list).
func show_weapon(id: StringName, animate := true) -> void:
	var at := _list.find(_cards.get(id))
	if at < 0:
		return
	var target := at / per_page
	if target != page:
		page = target
		_apply_page(animate)


## Steps `step` pages (clamped).
func turn(step: int) -> void:
	var target := clampi(page + step, 0, pages() - 1)
	if target == page:
		return
	page = target
	_apply_page(true)


func card(id: StringName) -> ArsenalCard:
	return _cards.get(id)


## The cards on the shown page, left to right.
func visible_cards() -> Array[ArsenalCard]:
	var out: Array[ArsenalCard] = []
	for i in range(page * per_page, mini(_list.size(), (page + 1) * per_page)):
		out.append(_list[i])
	return out


func cards() -> Array[ArsenalCard]:
	return _list


## The previewed card wears the outline; every card's tags and picture are re-read.
func refresh(selected_id: StringName, picture: Callable) -> void:
	for id in _cards:
		var c: ArsenalCard = _cards[id]
		c.selected = id == selected_id
		c.refresh(picture.call(c.weapon))


func _apply_page(animate: bool) -> void:
	var shown := visible_cards()
	page_shown.emit()
	for id in _cards:
		var c: ArsenalCard = _cards[id]
		c.visible = shown.has(c)
	# Right of the category's last card the focus stays put (not off to the top bar).
	for c: ArsenalCard in _list:
		c.focus_neighbor_right = NodePath(".") if c == _list[-1] else NodePath()
	_prev.disabled = page <= 0
	_next.disabled = page >= pages() - 1
	_count.text = "%d / %d" % [page + 1, pages()]
	if animate:
		_fade_row()


## The new page's cards fade up (instant with reduced motion).
func _fade_row() -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	_row.modulate.a = 1.0
	if Settings.reduce_motion() or not is_visible_in_tree():
		return
	_row.modulate.a = 0.25
	_fade = create_tween()
	_fade.tween_property(_row, "modulate:a", 1.0, 0.14)


## Every card the same width: the row shared by per_page cards (a short last
## page keeps the width, so cards never jump in size). Worked out from the
## width the page gives the dock (set_room), never from the dock's own size,
## which the cards' minimum widths would hold open.
func _size_cards() -> void:
	var box := get_theme_stylebox("panel")
	var outer := float((_row.get_parent() as HBoxContainer).get_theme_constant("separation"))
	var room := _room - box.get_margin(SIDE_LEFT) - box.get_margin(SIDE_RIGHT) - 2.0 * (PAGER_WIDTH + outer)
	var gap := float(_row.get_theme_constant("separation"))
	var width := floorf((room - gap * (per_page - 1)) / per_page)
	if width <= 0.0:
		return
	for id in _cards:
		(_cards[id] as Control).custom_minimum_size.x = width


## Moving the focus past either end of a page turns the page; the wheel turns pages.
func _on_card_input(event: InputEvent, c: ArsenalCard) -> void:
	var shown := visible_cards()
	if _wheel(event):
		accept_event()
	elif event.is_action_pressed("ui_right") and c == shown[-1] and page < pages() - 1:
		turn(1)
		visible_cards()[0].grab_focus()
		accept_event()
	elif event.is_action_pressed("ui_left") and c == shown[0] and page > 0:
		turn(-1)
		visible_cards()[-1].grab_focus()
		accept_event()


func _gui_input(event: InputEvent) -> void:
	if _wheel(event):
		accept_event()


## Turns a page for a wheel notch; true if `event` was one.
func _wheel(event: InputEvent) -> bool:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed or not wheel.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP]:
		return false
	turn(1 if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
	return true


## The dock's width (its parent's width): the cards are sized to share it.
func set_room(width: float) -> void:
	_room = width
	_size_cards()


func set_spacing(gap: int, padding: float) -> void:
	_row.add_theme_constant_override("separation", gap)
	set_padding(padding, padding * 0.8)
	_size_cards()
