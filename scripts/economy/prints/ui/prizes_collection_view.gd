class_name PrizesCollectionView
extends HBoxContainer
## The COLLECTION tab: every print held as a card in a wide grid, filtered by
## rarity and grade (and rare prints only), sorted five ways, and the inspect
## view of the selected print (PrintInspect: wear it, keep it, recycle it).

const CARD_GAP := 12
const GRID_MARGIN := 14
const INSPECT_WIDTH := 470.0
const SORTS := ["NEWEST", "RARITY", "GRADE", "SERIAL", "RARE PRINT"]
const GRADE_TABS := [[&"any", "ANY GRADE"], [&"0", "FACTORY"], [&"1", "POLISHED"], [&"2", "MINT"]]

var _page: PrizesPage
var _rarity := -1
var _grade := -1
var _only_rare := false
var _sort := 0
## Shows only the prints of this finish (set from the Locker); &"" = all.
var _finish_filter: StringName
var _rarity_tabs: KitTabs
var _grade_tabs: KitTabs
var _sort_button: SignButton
var _rare_button: SignButton
var _auto_button: SignButton
var _finish_chip: SignButton
var _caption: Label
var _caption_note: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty: Label
var _cards: Array[PrintCard] = []
var _card_group := ButtonGroup.new()
var _inspect: PrintInspect
var _selected: Dictionary = {}


func _init(page: PrizesPage) -> void:
	_page = page
	add_theme_constant_override("separation", UiKit.GAP_L)
	var tray := UiKit.metal_frame(24)
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(tray)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	tray.add_child(col)
	col.add_child(_build_filters())
	col.add_child(_build_toggles())
	var caption := UiKit.section("", " ")
	_caption = caption.get_child(0) as Label
	_caption_note = caption.get_child(2) as Label
	col.add_child(caption)
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(area)
	_scroll = UiKit.scroll()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.add_child(_scroll)
	_grid = new_grid(_scroll)
	_scroll.resized.connect(func(): fit_columns(_grid, _scroll))
	_empty = UiKit.body("", 0.0, UiKit.SIZE_LABEL, UiKit.MUTED)
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_empty)
	_inspect = PrintInspect.new()
	_inspect.custom_minimum_size.x = INSPECT_WIDTH
	_inspect.changed.connect(_on_inspect_changed)
	add_child(_inspect)


func _build_filters() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	_rarity_tabs = UiKit.tabs(18)
	for t in [[&"all", "ALL"], [&"0", "COMMON"], [&"1", "RARE"], [&"2", "EPIC"], [&"3", "LEGENDARY"]]:
		_rarity_tabs.add_tab(t[0], t[1])
	_rarity_tabs.tab_changed.connect(func(id: StringName):
		_rarity = -1 if id == &"all" else int(String(id))
		refresh())
	row.add_child(_rarity_tabs)
	row.add_child(UiKit.filler())
	_grade_tabs = UiKit.tabs(18)
	for t in GRADE_TABS:
		_grade_tabs.add_tab(t[0], t[1])
	_grade_tabs.tab_changed.connect(func(id: StringName):
		_grade = -1 if id == &"any" else int(String(id))
		refresh())
	row.add_child(_grade_tabs)
	return row


func _build_toggles() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_S)
	_rare_button = UiKit.sign_button("RARE PRINTS ONLY", SignButton.Kind.NEUTRAL, 18)
	_rare_button.toggle_mode = true
	_rare_button.toggled.connect(func(on: bool):
		_only_rare = on
		refresh())
	row.add_child(_rare_button)
	_sort_button = UiKit.sign_button("", SignButton.Kind.SECONDARY, 18)
	_sort_button.tooltip_text = "Change the order: " + ", ".join(SORTS).to_lower()
	_sort_button.pressed.connect(func():
		_sort = (_sort + 1) % SORTS.size()
		refresh())
	row.add_child(_sort_button)
	_finish_chip = UiKit.sign_button("", SignButton.Kind.GOLD, 18)
	_finish_chip.tooltip_text = "Show every print again."
	_finish_chip.pressed.connect(clear_finish_filter)
	row.add_child(_finish_chip)
	row.add_child(UiKit.filler())
	_auto_button = UiKit.sign_button("", SignButton.Kind.NEUTRAL, 18)
	_auto_button.tooltip_text = "Plain repeats (Factory or Polished, no rare print, serial above #%03d) become Prize Tokens as they drop." % PrizePrints.series().low_serial
	_auto_button.pressed.connect(func():
		PrizePrints.set_auto_recycle(not PrizePrints.auto_recycle())
		_refresh_auto())
	row.add_child(_auto_button)
	return row


## A padded grid of cards in `scroll` (shared with the Trade-Up tab).
static func new_grid(scroll: ScrollContainer) -> GridContainer:
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, GRID_MARGIN)
	scroll.add_child(pad)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", CARD_GAP)
	grid.add_theme_constant_override("v_separation", CARD_GAP)
	pad.add_child(grid)
	return grid


## As many card columns as `scroll` has room for.
static func fit_columns(grid: GridContainer, scroll: ScrollContainer) -> void:
	var room := scroll.size.x - GRID_MARGIN * 2.0 - 18.0
	grid.columns = clampi(int((room + CARD_GAP) / (PrintCard.CARD_SIZE.x + CARD_GAP)), 2, 12)


## Fills `cards` (grown as needed, reused) in `grid` with `list`; a click calls `chosen(card)`.
static func fill_cards(page: PrizesPage, grid: GridContainer, cards: Array[PrintCard], list: Array, chosen: Callable, group: ButtonGroup) -> void:
	while cards.size() < list.size():
		var card := PrintCard.create()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.button_group = group
		card.toggle_mode = group != null
		card.pressed.connect(func(): chosen.call(card))
		grid.add_child(card)
		cards.append(card)
	for i in cards.size():
		var card := cards[i]
		card.visible = i < list.size()
		if card.visible:
			card.show_print(list[i], page.weapon_for(list[i]), page.thumbs)


func set_finish_filter(finish_id: StringName) -> void:
	_finish_filter = finish_id
	_rarity = -1
	_grade = -1
	_rarity_tabs.select(&"all")
	_grade_tabs.select(&"any")


## Drops the finish filter; false if there was none.
func clear_finish_filter() -> bool:
	if _finish_filter == &"":
		return false
	_finish_filter = &""
	refresh()
	return true


## The prints the filters let through, sorted.
func _shown() -> Array:
	var list := PrizePrints.held().filter(func(p):
		return (_rarity < 0 or PrizePrints.rarity(p) == _rarity) \
			and (_grade < 0 or PrizePrints.grade(p) == _grade) \
			and (not _only_rare or String(p.get("var", "")) != "") \
			and (_finish_filter == &"" or StringName(String(p["f"])) == _finish_filter))
	match _sort:
		0:
			list.reverse()
		1:
			list.sort_custom(func(a, b): return PrintLook.score(a) > PrintLook.score(b))
		2:
			list.sort_custom(func(a, b): return float(a["shine"]) > float(b["shine"]))
		3:
			list.sort_custom(func(a, b): return int(a["serial"]) < int(b["serial"]))
		4:
			var order := {"misprint": 0, "holo": 1, "glitter": 2, "": 3}
			list.sort_custom(func(a, b): return order[String(a.get("var", ""))] < order[String(b.get("var", ""))] if a.get("var", "") != b.get("var", "") else PrintLook.score(a) > PrintLook.score(b))
	return list


func refresh() -> void:
	var list := _shown()
	fill_cards(_page, _grid, _cards, list, _on_card_chosen, _card_group)
	_sort_button.text = "SORT: " + SORTS[_sort]
	_refresh_auto()
	var fin := Cosmetics.item(_finish_filter)
	_finish_chip.visible = fin != null
	_finish_chip.text = ("ONLY %s  ✕" % fin.display_name.to_upper()) if fin else ""
	_caption.text = ("PRINTS OF " + fin.display_name.to_upper()) if fin else "YOUR PRINTS"
	_caption_note.text = "%d shown  ·  %d held  ·  %d new" % [list.size(), PrizePrints.held().size(), PrizePrints.new_count()]
	_empty.visible = list.is_empty()
	_empty.text = "No prints yet.\nOpen a Prize Capsule on the CAPSULES tab: every one drops a unique print." if PrizePrints.held().is_empty() else "No prints match the filters."
	if _selected.is_empty() or not list.has(_selected):
		_selected = list[0] if not list.is_empty() else {}
	select(_selected)
	UiFx.stagger_in(_cards.filter(func(c: PrintCard) -> bool: return c.visible))


func _refresh_auto() -> void:
	_auto_button.text = "AUTO-RECYCLE: " + ("ON" if PrizePrints.auto_recycle() else "OFF")


func _on_card_chosen(card: PrintCard) -> void:
	select(card.print_data)


## Shows `p` in the inspect view and marks its card.
func select(p: Dictionary) -> void:
	_selected = p
	_inspect.show_print(p)
	for card in _cards:
		if card.visible and card.print_data == p:
			card.selected = true
			if bool(p.get("new", false)):
				PrizePrints.mark_seen(p)
				card.refresh_state()


func _on_inspect_changed() -> void:
	for card in _cards:
		if card.visible:
			card.refresh_state()
	if _inspect.print_data.is_empty():
		_selected = {}
		refresh()
