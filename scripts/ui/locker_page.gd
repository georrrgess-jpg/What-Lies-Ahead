class_name LockerPage
extends MenuPage
## The Locker: everything the player owns or could own, in one place.
## A tab per category (with a count of what is new), the items of the open
## category as cards in a tray (what is worn first, then owned, for sale,
## locked), the selected item live in the display case, and its signboard
## with one action: EQUIP, BUY for Sparks, or what unlocks it.
## Weapon cosmetics are equipped per weapon: the header's weapon plate picks
## the weapon, and the filters narrow the tray to what is owned or for sale.
##
## Keys: arrows browse (the case follows), Enter equips or buys, A / D (or
## the triggers) change category. Mouse: click selects, double-click acts.

## Shown on the purchase stamp of the display case.
const BOUGHT_TEXT := "ADDED TO YOUR LOCKER"
const SIDE_WIDTH := 744.0
const CARD_GAP := 12
## Room around the cards for the hover growth and the focus ring.
const GRID_MARGIN := 14
## Browsing with the keyboard builds the 3D preview once the focus rests.
const PREVIEW_DELAY := 0.09

var _slot: StringName = &"avatar"
var _weapon_id: StringName
var _filter := LockerCatalog.Filter.ALL
var _selected: CosmeticItem
var _built := false
var _trigger_held := 0
var _header: HBoxContainer
var _weapon_box: HBoxContainer
var _weapon_plate: SlotPlate
var _filters: KitTabs
var _collection: Label
var _collection_bar: ProgressBar
var _tabs: KitTabs
var _caption: Label
var _caption_note: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty: Label
var _cards: Array[LockerCard] = []
var _card_group := ButtonGroup.new()
var _thumbs: CosmeticThumbs
var _showcase: CosmeticShowcase
var _panel: CosmeticPanel
var _preview_timer: Timer


func uses_shell_header() -> bool:
	return true


func header_extra() -> Control:
	return _header


func _ready() -> void:
	_weapon_id = StringName(String(Profile.data.get("last_weapon", "")))
	if GameData.weapon(_weapon_id) == null:
		_weapon_id = GameData.default_weapon_id()
	_thumbs = CosmeticThumbs.new()
	add_child(_thumbs)
	_preview_timer = Timer.new()
	_preview_timer.one_shot = true
	_preview_timer.wait_time = PREVIEW_DELAY
	_preview_timer.timeout.connect(_show_preview.bind(false))
	add_child(_preview_timer)
	_build_header()
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	add_child(col)
	col.add_child(_build_tabs())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", UiKit.GAP_L)
	col.add_child(body)
	body.add_child(_build_tray())
	body.add_child(_build_side())
	visibility_changed.connect(_on_visibility_changed)
	Wallet.balance_changed.connect(_on_balance_changed)


func refresh() -> void:
	_built = true
	_refresh_collection()
	_refresh_badges()
	_open(_slot, _selected)
	_deal_cards()


func first_focus() -> Control:
	return _card_of(_selected)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or KitDialog.open_count > 0:
		return
	var step := 0
	if event.is_action_pressed("move_left"):
		step = -1
	elif event.is_action_pressed("move_right"):
		step = 1
	elif event is InputEventJoypadMotion:
		step = _trigger_step(event as InputEventJoypadMotion)
	if step != 0:
		_tabs.step(step)
		get_viewport().set_input_as_handled()


## -1 / 1 once per pull of the left / right trigger.
func _trigger_step(event: InputEventJoypadMotion) -> int:
	var side := 0
	if event.axis == JOY_AXIS_TRIGGER_LEFT:
		side = -1
	elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
		side = 1
	if side == 0:
		return 0
	if event.axis_value < 0.3 and _trigger_held == side:
		_trigger_held = 0
	elif event.axis_value > 0.6 and _trigger_held != side:
		_trigger_held = side
		return side
	return 0


# --- layout ---------------------------------------------------------------------

## Right of the marquee: the weapon plate, the filters and the collection.
func _build_header() -> void:
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", UiKit.GAP_L)
	_weapon_box = HBoxContainer.new()
	_weapon_box.add_theme_constant_override("separation", UiKit.GAP_S)
	_header.add_child(_weapon_box)
	var previous := UiKit.icon_button(&"icon_arrow_left", "Previous weapon")
	previous.pressed.connect(_step_weapon.bind(-1))
	_weapon_box.add_child(previous)
	_weapon_plate = UiKit.slot_plate("WEAPON", "")
	_weapon_plate.custom_minimum_size.x = 400
	_weapon_box.add_child(_weapon_plate)
	var next := UiKit.icon_button(&"icon_arrow_right", "Next weapon")
	next.pressed.connect(_step_weapon.bind(1))
	_weapon_box.add_child(next)
	_header.add_child(UiKit.filler())
	_filters = UiKit.tabs(24)
	_filters.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_filters.add_tab(&"all", "ALL")
	_filters.add_tab(&"owned", "OWNED")
	_filters.add_tab(&"sale", "FOR SALE")
	_filters.tab_changed.connect(_on_filter_changed)
	_header.add_child(_filters)
	var progress := VBoxContainer.new()
	progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_theme_constant_override("separation", UiKit.GAP_XS)
	_header.add_child(progress)
	_collection = UiKit.label("", UiKit.SIZE_LABEL, UiKit.CREAM, true)
	progress.add_child(_collection)
	_collection_bar = UiKit.progress(0.0, 12.0, UiKit.AMBER)
	_collection_bar.custom_minimum_size.x = 230
	progress.add_child(_collection_bar)


## One tab per category on a dark strip across the page.
func _build_tabs() -> Control:
	var strip := UiKit.card_panel(6)
	_tabs = KitTabs.make(24, true)
	_tabs.add_theme_constant_override("separation", UiKit.GAP_XS)
	for cat in LockerCatalog.CATEGORIES:
		var tab := _tabs.add_tab(cat["slot"], String(cat["tab"]))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.tooltip_text = String(cat["label"])
	_tabs.tab_changed.connect(_on_tab_changed)
	strip.add_child(_tabs)
	return strip


## The tray: a caption with what is owned here, and the scrolling card grid.
func _build_tray() -> Control:
	var tray := UiKit.metal_frame(32)
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_XS)
	tray.add_child(col)
	var caption := UiKit.section("", " ")
	_caption = caption.get_child(0) as Label
	_caption_note = caption.get_child(2) as Label
	col.add_child(caption)
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(area)
	_scroll = UiKit.scroll()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.resized.connect(_fit_columns)
	area.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, GRID_MARGIN)
	_scroll.add_child(pad)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", CARD_GAP)
	_grid.add_theme_constant_override("v_separation", CARD_GAP)
	pad.add_child(_grid)
	_empty = UiKit.body("", 0.0, UiKit.SIZE_LABEL, UiKit.MUTED)
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_empty)
	return tray


## The display case over the item's signboard.
func _build_side() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = SIDE_WIDTH
	side.add_theme_constant_override("separation", UiKit.GAP_M)
	_showcase = CosmeticShowcase.new()
	_showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_showcase)
	_panel = CosmeticPanel.new()
	_panel.custom_minimum_size.y = 292
	_panel.equip_requested.connect(_equip)
	_panel.unequip_requested.connect(_unequip)
	_panel.buy_requested.connect(_buy)
	side.add_child(_panel)
	return side


## As many columns as fit the tray (it is wider on an ultrawide screen).
func _fit_columns() -> void:
	var room := _scroll.size.x - GRID_MARGIN * 2.0 - 18.0
	_grid.columns = clampi(int((room + CARD_GAP) / (LockerCard.CARD_SIZE.x + CARD_GAP)), 3, 9)


# --- behaviour ------------------------------------------------------------------

## Opens a category tab (by slot) and selects what is worn there.
func show_category(slot: StringName) -> void:
	_open(slot, null)


## Opens a category and selects `prefer` if it is there, else its first item
## (what is worn, when the filter shows it).
func _open(slot: StringName, prefer: CosmeticItem) -> void:
	_slot = slot
	_tabs.select(slot)
	_weapon_box.visible = LockerCatalog.uses_weapon(slot)
	_refresh_weapon_plate()
	if not _built:
		return
	_fill_grid()
	_scroll.scroll_vertical = 0
	if _card_of(prefer):
		_select(prefer, false)
	else:
		_select(_cards[0].item if _cards[0].visible else null, false)


## Switches the weapon that weapon cosmetics are previewed on and equipped to.
func select_weapon(weapon_id: StringName) -> void:
	if GameData.weapon(weapon_id) == null:
		return
	_weapon_id = weapon_id
	show_category(_slot)


## Selects an item by id (opening its category and, for an item made for one
## weapon, that weapon).
func select_item(id: StringName) -> void:
	var it := Cosmetics.item(id)
	if it == null:
		return
	if it.is_weapon_slot() and it.weapon_id != &"":
		_weapon_id = it.weapon_id
	if _filter != LockerCatalog.Filter.ALL:
		_filter = LockerCatalog.Filter.ALL
		_filters.select(&"all")
	_open(it.slot, it)
	if is_visible_in_tree():
		_focus_selected()


func _ctx() -> StringName:
	return LockerCatalog.context(_slot, _weapon_id)


func _weapon() -> WeaponData:
	return GameData.weapon(_weapon_id)


## Shows the items of the open category on the cards (cards are reused).
func _fill_grid() -> void:
	var items := LockerCatalog.items(_slot, _weapon_id, _filter)
	if _cards.is_empty() or _cards.size() < items.size():
		for i in maxi(1, items.size()) - _cards.size():
			_cards.append(_new_card())
	var weapon := _weapon()
	for i in _cards.size():
		var card := _cards[i]
		card.visible = i < items.size()
		if card.visible:
			card.show_item(items[i], weapon, _thumbs)
	_refresh_caption()
	_empty.visible = items.is_empty()
	match _filter:
		LockerCatalog.Filter.OWNED:
			_empty.text = "Nothing owned here yet.\nPlay to unlock some, or look at what is for sale."
		LockerCatalog.Filter.FOR_SALE:
			_empty.text = "Nothing for sale here right now."
		_:
			_empty.text = "Nothing here yet."


func _new_card() -> LockerCard:
	var card := LockerCard.create()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.button_group = _card_group
	card.pressed.connect(_on_card_pressed.bind(card))
	card.focus_entered.connect(_on_card_focused.bind(card))
	card.gui_input.connect(_on_card_input.bind(card))
	_grid.add_child(card)
	return card


func _card_of(it: CosmeticItem) -> LockerCard:
	if it == null:
		return null
	for card in _cards:
		if card.visible and card.item == it:
			return card
	return null


func _on_card_pressed(card: LockerCard) -> void:
	if card.item != _selected:
		_select(card.item, true)


## Keyboard and gamepad: the case follows the focus.
func _on_card_focused(card: LockerCard) -> void:
	if card.item != _selected:
		_select(card.item, true)


## Enter (or the gamepad's accept) and a double-click act on the item.
func _on_card_input(event: InputEvent, card: LockerCard) -> void:
	var click := event as InputEventMouseButton
	var double_click := click != null and click.double_click and click.button_index == MOUSE_BUTTON_LEFT
	if not double_click and not event.is_action_pressed("ui_accept"):
		return
	card.accept_event()
	if card.item != _selected:
		_select(card.item, true)
	_activate(card.item)


func _select(it: CosmeticItem, by_player: bool) -> void:
	_selected = it
	_panel.show_item(it, _weapon_id)
	_showcase.visible = it != null
	var card := _card_of(it)
	if card == null:
		return
	card.selected = true
	if Cosmetics.is_new(it):
		Cosmetics.mark_seen(it)
		card.set_new(false)
		_refresh_badges()
	if by_player:
		_preview_timer.start()
	else:
		_preview_timer.stop()
		_show_preview(false)


func _show_preview(flourish: bool) -> void:
	if _selected:
		_showcase.show_item(_selected, _weapon(), flourish)


## The item's one action: equip it, buy it, or say why not.
func _activate(it: CosmeticItem) -> void:
	match LockerCatalog.state(it, _weapon_id):
		LockerCatalog.State.OWNED:
			_equip(it)
		LockerCatalog.State.FOR_SALE:
			_buy(it)
		LockerCatalog.State.LOCKED:
			_panel.refused()


func _equip(it: CosmeticItem) -> void:
	if it == null or not Cosmetics.equip(it.slot, it, _ctx()):
		_panel.refused()
		return
	Sfx.play(LockerCatalog.category(it.slot)["sound"], -3.0)
	_after_change(true)


func _unequip(it: CosmeticItem) -> void:
	Cosmetics.equip(it.slot, null, _ctx())
	Sfx.play(&"cos_unequip", -6.0)
	_after_change(false)
	_focus_selected()


func _buy(it: CosmeticItem) -> void:
	var dialog := PurchaseFlow.request(self, it, _ctx(), _on_bought)
	if dialog:
		dialog.cancelled.connect(_focus_selected)


## The purchase moment: the case celebrates, and EQUIP is one press away.
func _on_bought(it: CosmeticItem) -> void:
	Cosmetics.mark_seen(it)
	_refresh_states()
	_panel.refresh()
	_refresh_collection()
	_refresh_caption()
	if it == _selected:
		_showcase.celebrate(BOUGHT_TEXT)
	var action := _panel.action_button()
	if action:
		action.grab_focus.call_deferred()
		_panel.pulse_action.call_deferred()


## Cards, the signboard and the case after equipping or unequipping.
func _after_change(flourish: bool) -> void:
	_refresh_states()
	_panel.refresh()
	_preview_timer.stop()
	_show_preview(flourish)


## The cards on show pop in one after another.
func _deal_cards() -> void:
	UiFx.stagger_in(_cards.filter(func(card: LockerCard) -> bool: return card.visible))


func _focus_selected() -> void:
	var card := _card_of(_selected)
	if card:
		card.grab_focus()


func _refresh_states() -> void:
	for card in _cards:
		if card.visible:
			card.refresh_state()


func _refresh_badges() -> void:
	for cat in LockerCatalog.CATEGORIES:
		_tabs.set_badge(cat["slot"], Cosmetics.new_count(cat["slot"]))


func _refresh_collection() -> void:
	var have := LockerCatalog.collection()
	_collection.text = "COLLECTION  %d / %d" % [have.x, have.y]
	_collection_bar.value = float(have.x) / maxf(1.0, have.y)


## "ION CARBINE SKINS" and how many of the cards on show are owned.
func _refresh_caption() -> void:
	var label := String(LockerCatalog.category(_slot)["label"]).to_upper()
	var weapon := _weapon()
	_caption.text = "%s  ·  %s" % [weapon.display_name.to_upper(), label] if LockerCatalog.is_weapon_slot(_slot) and weapon else label
	var owned := 0
	var shown := 0
	for card in _cards:
		if card.visible:
			shown += 1
			if card.state <= LockerCatalog.State.OWNED:
				owned += 1
	_caption_note.text = "%d of %d owned" % [owned, shown]


func _refresh_weapon_plate() -> void:
	var weapon := _weapon()
	if weapon == null:
		return
	_weapon_plate.set_caption("WEAPON" if LockerCatalog.is_weapon_slot(_slot) else "SHOWN ON")
	_weapon_plate.set_value(weapon.display_name.to_upper())
	_weapon_plate.set_note(Mastery.rank_label(Mastery.rank(weapon.id)).capitalize())


func _step_weapon(direction: int) -> void:
	var weapons := GameData.weapons()
	if weapons.is_empty():
		return
	var at := weapons.find(_weapon())
	UiSound.select()
	select_weapon(weapons[posmod(at + direction, weapons.size())].id)


func _on_tab_changed(slot: StringName) -> void:
	# A / D and the triggers leave the focus on the cards; a click or Enter
	# on a tab keeps it on the tab row.
	var focus := get_viewport().gui_get_focus_owner()
	var on_tabs := focus != null and _tabs.is_ancestor_of(focus)
	show_category(slot)
	_deal_cards()
	if not on_tabs:
		_focus_selected()


func _on_filter_changed(id: StringName) -> void:
	_filter = {&"owned": LockerCatalog.Filter.OWNED, &"sale": LockerCatalog.Filter.FOR_SALE}.get(id, LockerCatalog.Filter.ALL)
	show_category(_slot)


## Prices turn red or gold as the balance changes.
func _on_balance_changed(_balance: int) -> void:
	if _built and is_visible_in_tree():
		_refresh_states()
		_panel.refresh()


## Leaving the page saves which items have been looked at.
func _on_visibility_changed() -> void:
	if not is_visible_in_tree() and _built:
		Profile.save_profile()
