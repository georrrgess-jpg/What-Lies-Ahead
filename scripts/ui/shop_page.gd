class_name ShopPage
extends MenuPage
## The Shop: the prize counter where Sparks become cosmetics.
##   - Today's picks under the awning: the featured items at a discount, with
##     the time left until they change.
##   - A shelf per section of ShopCatalog (tabs in the header row, with a count
##     of what is new), items as cards with their price, OWNED, or what still
##     locks them.
##   - The selected item live in the display case, and its signboard with one
##     action: BUY (with a confirm), how many Sparks are missing and how to
##     earn them, or EQUIP IN LOCKER for what is already owned.
## Keys: arrows browse, Enter buys, A / D (or the triggers) change section.
## Registered by data/ui/shop.tres.

const BOUGHT_TEXT := "SOLD!  IT IS IN YOUR LOCKER"
const SIDE_WIDTH := 744.0
const CARD_GAP := 12
const GRID_MARGIN := 14
const FEATURED_CARD := Vector2(200, 190)
const SHELF_CARD := Vector2(176, 196)
const PREVIEW_DELAY := 0.09

var _slot: StringName
var _selected: CosmeticItem
var _built := false
var _trigger_held := 0
var _header: Control
var _sign: KitChip
var _featured_row: HBoxContainer
var _featured_cards: Array[LockerCard] = []
var _tabs: KitTabs
var _caption: Label
var _caption_note: Label
var _scroll: ScrollContainer
var _grid: GridContainer
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
	_thumbs = CosmeticThumbs.new()
	add_child(_thumbs)
	_preview_timer = Timer.new()
	_preview_timer.one_shot = true
	_preview_timer.wait_time = PREVIEW_DELAY
	_preview_timer.timeout.connect(_show_preview)
	add_child(_preview_timer)
	var clock := Timer.new()
	clock.wait_time = 20.0
	clock.autostart = true
	clock.timeout.connect(_refresh_countdown)
	add_child(clock)
	_header = _build_tabs()
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	add_child(row)
	var counter := VBoxContainer.new()
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counter.add_theme_constant_override("separation", UiKit.GAP_S)
	row.add_child(counter)
	counter.add_child(_build_featured())
	counter.add_child(_build_shelf())
	row.add_child(_build_side())
	visibility_changed.connect(_on_visibility_changed)
	Wallet.balance_changed.connect(_on_balance_changed)


## Makes the picks and the first shelf's cards ahead of the first visit,
## a few per frame (they stay hidden until refresh() fills them).
func prewarm(queue: BuildQueue) -> void:
	if _tabs.ids().is_empty():
		return
	var shelf := ShopCatalog.items(_tabs.ids()[0]).size()
	var picks := ShopCatalog.featured().size()
	for i in range(0, maxi(shelf, picks), 3):
		queue.add(_prewarm_cards.bind(mini(i + 3, shelf), mini(i + 3, picks)))


func _prewarm_cards(shelf: int, picks: int) -> void:
	while _cards.size() < shelf:
		var card := _new_card(SHELF_CARD)
		card.visible = false
		_grid.add_child(card)
		_cards.append(card)
	while _featured_cards.size() < picks:
		var card := _new_card(FEATURED_CARD)
		card.visible = false
		_featured_row.add_child(card)
		_featured_cards.append(card)


func refresh() -> void:
	_built = true
	_refresh_countdown()
	_fill_featured()
	_refresh_badges()
	if _slot == &"" and not _tabs.ids().is_empty():
		_slot = _tabs.ids()[0]
	_fill_shelf()
	if _selected == null or _card_of(_selected) == null:
		_select(_first_item(), false)
	else:
		_select(_selected, false)
	UiFx.stagger_in(_featured_cards.filter(_is_shown) + _cards.filter(_is_shown))


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

## Today's picks on a signboard under the counter's awning.
func _build_featured() -> Control:
	var board := UiKit.signboard()
	board.set_padding(30, 20)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	board.add_child(col)
	var awning := Awning.new()
	col.add_child(awning)
	_sign = UiKit.chip("", UiKit.INK, 24)
	_sign.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sign.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sign.grow_vertical = Control.GROW_DIRECTION_BOTH
	awning.add_child(_sign)
	_featured_row = HBoxContainer.new()
	_featured_row.add_theme_constant_override("separation", CARD_GAP)
	var pad := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	pad.add_child(_featured_row)
	col.add_child(pad)
	return board


## The sections, right of the marquee.
func _build_tabs() -> Control:
	var strip := UiKit.card_panel(6)
	_tabs = KitTabs.make(22, true)
	_tabs.add_theme_constant_override("separation", UiKit.GAP_XS)
	for section in ShopCatalog.sections():
		var tab := _tabs.add_tab(section["slot"], String(LockerCatalog.category(section["slot"])["tab"]))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.tooltip_text = String(section["title"])
	_tabs.tab_changed.connect(_on_tab_changed)
	strip.add_child(_tabs)
	return strip


## The shelf: a caption and the scrolling cards of the open section.
func _build_shelf() -> Control:
	var tray := UiKit.metal_frame(32)
	tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_XS)
	tray.add_child(col)
	var caption := UiKit.section("", " ")
	_caption = caption.get_child(0) as Label
	_caption_note = caption.get_child(2) as Label
	col.add_child(caption)
	_scroll = UiKit.scroll()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.resized.connect(_fit_columns)
	col.add_child(_scroll)
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
	return tray


func _build_side() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = SIDE_WIDTH
	side.add_theme_constant_override("separation", UiKit.GAP_M)
	_showcase = CosmeticShowcase.new()
	_showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_showcase)
	_panel = CosmeticPanel.new()
	_panel.shop_mode = true
	_panel.custom_minimum_size.y = 292
	_panel.buy_requested.connect(_buy)
	_panel.locker_requested.connect(_open_in_locker)
	side.add_child(_panel)
	return side


func _fit_columns() -> void:
	var room := _scroll.size.x - GRID_MARGIN * 2.0 - 18.0
	_grid.columns = clampi(int((room + CARD_GAP) / (SHELF_CARD.x + CARD_GAP)), 3, 9)


# --- content --------------------------------------------------------------------

func _fill_featured() -> void:
	var picks := ShopCatalog.featured()
	while _featured_cards.size() < picks.size():
		var card := _new_card(FEATURED_CARD)
		_featured_row.add_child(card)
		_featured_cards.append(card)
	for i in _featured_cards.size():
		var card := _featured_cards[i]
		card.visible = i < picks.size()
		if card.visible:
			card.show_item(picks[i], _weapon_for(picks[i]), _thumbs)


func _fill_shelf() -> void:
	_tabs.select(_slot)
	var items := ShopCatalog.items(_slot)
	while _cards.size() < items.size():
		var card := _new_card(SHELF_CARD)
		_grid.add_child(card)
		_cards.append(card)
	for i in _cards.size():
		var card := _cards[i]
		card.visible = i < items.size()
		if card.visible:
			card.show_item(items[i], _weapon_for(items[i]), _thumbs)
	_scroll.scroll_vertical = 0
	_refresh_caption()


func _new_card(card_size: Vector2) -> LockerCard:
	var card := LockerCard.create(card_size)
	card.shop_mode = true
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.button_group = _card_group
	card.pressed.connect(_on_card_chosen.bind(card))
	card.focus_entered.connect(_on_card_chosen.bind(card))
	card.gui_input.connect(_on_card_input.bind(card))
	return card


## The weapon an item is shown on and bought for.
func _weapon_for(it: CosmeticItem) -> WeaponData:
	var weapon := GameData.weapon(ShopCatalog.buy_context(it))
	if weapon == null:
		weapon = GameData.weapon(StringName(String(Profile.data.get("last_weapon", ""))))
	return weapon if weapon else GameData.weapon(GameData.default_weapon_id())


## The card showing `it`: on the shelf if it is there, else among the picks.
func _card_of(it: CosmeticItem) -> LockerCard:
	if it == null:
		return null
	for card in _cards + _featured_cards:
		if card.visible and card.item == it:
			return card
	return null


## What to select when nothing is: the first pick still for sale, else the
## first item of the shelf.
func _first_item() -> CosmeticItem:
	for card in _featured_cards:
		if card.visible and Cosmetics.is_for_sale(card.item):
			return card.item
	return _cards[0].item if not _cards.is_empty() and _cards[0].visible else null


static func _is_shown(card: LockerCard) -> bool:
	return card.visible


# --- behaviour ------------------------------------------------------------------

## Opens a section's shelf (by slot).
func show_section(slot: StringName) -> void:
	if _tabs.button(slot) == null:
		return
	_slot = slot
	if _built:
		_fill_shelf()
		_select(_cards[0].item if _cards[0].visible else null, false)


## Selects an item of the shop by id (opening its section).
func select_item(id: StringName) -> void:
	var it := Cosmetics.item(id)
	if it == null or it.price <= 0:
		return
	show_section(it.slot)
	_select(it, false)
	await get_tree().process_frame
	var card := _card_of(it)
	if card and _grid.is_ancestor_of(card):
		_scroll.ensure_control_visible(card)


func _on_card_chosen(card: LockerCard) -> void:
	if card.item != _selected:
		_select(card.item, true)


## Enter (or the gamepad's accept) and a double-click buy.
func _on_card_input(event: InputEvent, card: LockerCard) -> void:
	var click := event as InputEventMouseButton
	var double_click := click != null and click.double_click and click.button_index == MOUSE_BUTTON_LEFT
	if not double_click and not event.is_action_pressed("ui_accept"):
		return
	card.accept_event()
	if card.item != _selected:
		_select(card.item, true)
	if Cosmetics.is_for_sale(card.item):
		_buy(card.item)
	else:
		_open_in_locker(card.item)


func _select(it: CosmeticItem, by_player: bool) -> void:
	_selected = it
	_panel.show_item(it, ShopCatalog.buy_context(it) if it else &"")
	_showcase.visible = it != null
	var card := _card_of(it)
	if card == null:
		return
	card.selected = true
	if ShopCatalog.is_new(it):
		ShopCatalog.mark_seen(it)
		_refresh_states()
		_refresh_badges()
	if by_player:
		_preview_timer.start()
	else:
		_preview_timer.stop()
		_show_preview()


func _show_preview() -> void:
	if _selected:
		_showcase.show_item(_selected, _weapon_for(_selected))


func _buy(it: CosmeticItem) -> void:
	var dialog := PurchaseFlow.request(self, it, ShopCatalog.buy_context(it), _on_bought)
	if dialog:
		dialog.cancelled.connect(_focus_selected)


## Sold: the case celebrates and the Locker is one press away.
func _on_bought(it: CosmeticItem) -> void:
	_refresh_states()
	_panel.refresh()
	_refresh_caption()
	if it == _selected:
		_showcase.celebrate(BOUGHT_TEXT)
	var action := _panel.action_button()
	if action:
		action.grab_focus.call_deferred()
		_panel.pulse_action.call_deferred()


## Shows an owned item in the Locker, ready to equip; BACK returns here.
func _open_in_locker(it: CosmeticItem) -> void:
	open_page.emit(&"locker")
	var menu := get_tree().current_scene
	var locker := menu.page("locker") as LockerPage if menu.has_method("page") else null
	if locker:
		locker.select_item(it.id)


func _focus_selected() -> void:
	var card := _card_of(_selected)
	if card:
		card.grab_focus()


func _refresh_states() -> void:
	for card in _cards + _featured_cards:
		if card.visible:
			card.refresh_state()


func _refresh_badges() -> void:
	for slot in _tabs.ids():
		_tabs.set_badge(slot, ShopCatalog.new_count(slot))
		var badge := _tabs.button(slot).get_node_or_null("Badge") as Control
		if badge:
			badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			badge.position += Vector2(-6.0, 2.0)


func _refresh_caption() -> void:
	var have := ShopCatalog.progress(_slot)
	var all := ShopCatalog.progress()
	_caption.text = String(LockerCatalog.category(_slot)["label"]).to_upper()
	_caption_note.text = "%d of %d owned here  ·  %d of %d in the whole shop" % [have.x, have.y, all.x, all.y]


## "TODAY'S PICKS  ·  25% OFF  ·  NEW IN 5 H 12 MIN" on the awning.
func _refresh_countdown() -> void:
	var minutes := ceili(ShopCatalog.seconds_to_rotation() / 60.0)
	var left := "%d H %02d MIN" % [minutes / 60, minutes % 60] if minutes >= 60 else "%d MIN" % minutes
	_sign.set_text("TODAY'S PICKS  ·  %d%% OFF  ·  NEW IN %s" % [roundi(Wallet.rules.featured_discount * 100.0), left])


func _on_tab_changed(slot: StringName) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var on_tabs := focus != null and _tabs.is_ancestor_of(focus)
	show_section(slot)
	UiFx.stagger_in(_cards.filter(_is_shown))
	if not on_tabs:
		_focus_selected()


func _on_balance_changed(_balance: int) -> void:
	if _built and is_visible_in_tree():
		_refresh_states()
		_panel.refresh()


## Leaving the shop saves which new arrivals have been looked at.
func _on_visibility_changed() -> void:
	if not is_visible_in_tree() and _built:
		Profile.save_profile()


## The striped awning of the prize counter, drawn across the top of the picks.
class Awning extends Control:
	const STRIPE := 40.0

	func _init() -> void:
		custom_minimum_size.y = 38
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var count := maxi(1, int(ceil(size.x / STRIPE)))
		var width := size.x / count
		var drop := size.y - width * 0.5 - 1.0
		for i in count:
			var color := UiKit.PINK if i % 2 == 0 else UiKit.CREAM
			var x := width * i
			draw_rect(Rect2(x, 0.0, width + 0.5, drop), color)
			draw_circle(Vector2(x + width * 0.5, drop), width * 0.5, color)
			draw_rect(Rect2(x, 0.0, width + 0.5, 4.0), color.darkened(0.25))
