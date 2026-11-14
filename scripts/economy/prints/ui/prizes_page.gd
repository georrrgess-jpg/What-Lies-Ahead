class_name PrizesPage
extends MenuPage
## Prizes: the Prize Capsule machine and the Prize Print collection
## (docs/ECONOMY.md, "Prize Prints"). Registered by data/ui/prizes.tres.
##   - Left: the capsule machine (drawn, animated), the capsules held, OPEN and
##     BUY (Sparks), the luck meter and the Prize Tokens.
##   - Right, by the header tabs:
##       COLLECTION    the prints as cards (filter by rarity, rare prints only,
##                     sort), and the inspect view of the selected one;
##       TRADE-UP      five prints of one rarity into one of the next;
##       TOKEN COUNTER today's shelf of fresh prints for Prize Tokens;
##       ODDS          the published odds, the luck meter, rare prints and
##                     grades, how capsules are earned and the series list.
##   - Opening plays CapsuleReveal over the page.
## Keys: Enter opens a capsule (on the machine), A / D change tab.

const LEFT_WIDTH := 520.0
const CARD_GAP := 12
const GRID_MARGIN := 14
const SORTS := ["NEWEST", "RARITY", "GRADE", "SERIAL", "RARE PRINT"]
const VIEWS := [[&"collection", "COLLECTION"], [&"tradeup", "TRADE-UP"], [&"counter", "TOKEN COUNTER"], [&"odds", "ODDS & INFO"]]

var _built := false
var _busy := false
var _header: Control
var _tabs: KitTabs
var _view := &"collection"
var _views := {}
var _thumbs: CosmeticThumbs
var _machine: CapsuleMachine
var _open: SignButton
var _buy: SignButton
var _capsule_note: Label
var _luck_epic: ProgressBar
var _luck_epic_text: Label
var _luck_legendary: ProgressBar
var _luck_legendary_text: Label
var _tokens_text: Label
var _reveal: CapsuleReveal
var _pending: Dictionary = {}
# Collection.
var _rarity_filter := -1
var _only_rare := false
var _sort := 0
## Shows only the prints of this finish (set from the Locker); &"" = all.
var _finish_filter: StringName
var _rarity_tabs: KitTabs
var _sort_button: SignButton
var _rare_button: SignButton
var _auto_button: SignButton
var _caption: Label
var _caption_note: Label
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty: Label
var _cards: Array[PrintCard] = []
var _card_group := ButtonGroup.new()
var _inspect: PrintInspect
var _selected: Dictionary = {}
# Trade-up.
var _tu_rarity := 0
var _tu_picked: Array = []
var _tu_tabs: KitTabs
var _tu_slots: Array[PrintCard] = []
var _tu_result: Label
var _tu_note: Label
var _tu_button: SignButton
var _tu_grid: GridContainer
var _tu_cards: Array[PrintCard] = []
# Token Counter.
var _counter_row: HBoxContainer
var _counter_tokens: Label
var _counter_clock: Label
# Odds.
var _odds_series: GridContainer


func uses_shell_header() -> bool:
	return true


func header_extra() -> Control:
	return _header


func _ready() -> void:
	_thumbs = CosmeticThumbs.new()
	add_child(_thumbs)
	_header = _build_header()
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	add_child(row)
	row.add_child(_build_machine_side())
	var stack := Control.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	_views[&"collection"] = _build_collection()
	_views[&"tradeup"] = _build_trade_up()
	_views[&"counter"] = _build_counter()
	_views[&"odds"] = _build_odds()
	for id in _views:
		var v: Control = _views[id]
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(v)
	_reveal = CapsuleReveal.new()
	_reveal.closed.connect(_on_reveal_closed)
	_reveal.another_requested.connect(_on_another)
	_reveal.equip_requested.connect(_on_reveal_equip)
	add_child(_reveal)
	Cosmetics.prints_changed.connect(_on_prints_changed)
	Wallet.balance_changed.connect(func(_b): _refresh_machine())
	visibility_changed.connect(_on_visibility_changed)
	_show_view(_view)


func refresh() -> void:
	_built = true
	_refresh_machine()
	_refresh_view()


func first_focus() -> Control:
	return _open


func handle_back() -> bool:
	if _reveal.visible:
		_reveal.close()
		return true
	if _finish_filter != &"":
		_finish_filter = &""
		_fill_collection()
		return true
	return false


## Opens the collection showing only the prints of one finish (the Locker's PRINTS button).
func show_finish(finish_id: StringName) -> void:
	_finish_filter = finish_id
	_rarity_filter = -1
	_rarity_tabs.select(&"all")
	_tabs.select(&"collection", true)
	if _built:
		_fill_collection()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or KitDialog.open_count > 0 or _reveal.visible:
		return
	var step := 0
	if event.is_action_pressed("move_left"):
		step = -1
	elif event.is_action_pressed("move_right"):
		step = 1
	if step != 0:
		_tabs.step(step)
		get_viewport().set_input_as_handled()


static func _rc(r: int) -> Color:
	return CosmeticItem.rarity_color(r as CosmeticItem.Rarity)


static func _rn(r: int) -> String:
	return CosmeticItem.rarity_name(r as CosmeticItem.Rarity)


func _weapon() -> WeaponData:
	var w := GameData.weapon(StringName(String(Profile.data.get("last_weapon", ""))))
	return w if w else GameData.weapon(GameData.default_weapon_id())


# --- header and the machine ------------------------------------------------------------

func _build_header() -> Control:
	var strip := UiKit.card_panel(6)
	_tabs = KitTabs.make(22, true)
	_tabs.add_theme_constant_override("separation", UiKit.GAP_XS)
	for v in VIEWS:
		var tab := _tabs.add_tab(v[0], v[1])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(_show_view)
	strip.add_child(_tabs)
	return strip


func _build_machine_side() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = LEFT_WIDTH
	side.add_theme_constant_override("separation", UiKit.GAP_S)
	var board := UiKit.signboard(14)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(board)
	_machine = CapsuleMachine.new()
	_machine.series_text = "SERIES %d" % PrizePrints.series().number
	_machine.series_name = PrizePrints.series().display_name.to_upper()
	_machine.turned.connect(_on_machine_turned)
	board.add_child(_machine)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", UiKit.GAP_S)
	side.add_child(buttons)
	_open = UiKit.sign_button("OPEN", SignButton.Kind.PRIMARY, 30)
	_open.name = "FirstFocus"
	_open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open.pressed.connect(_open_capsule)
	buttons.add_child(_open)
	_buy = UiKit.sign_button("", SignButton.Kind.GOLD, 24)
	_buy.icon = UiKit.spark_icon(30).texture
	_buy.pressed.connect(_buy_capsule)
	buttons.add_child(_buy)
	_capsule_note = UiKit.body("", LEFT_WIDTH, UiKit.SIZE_SMALL, UiKit.MUTED)
	_capsule_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(_capsule_note)
	var luck := UiKit.card_panel(14)
	side.add_child(luck)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_XS)
	luck.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	head.add_child(UiKit.label("LUCK METER", UiKit.SIZE_LABEL, UiKit.CREAM, true))
	head.add_child(UiKit.filler())
	_tokens_text = UiKit.label("", UiKit.SIZE_SMALL, UiKit.AMBER, true)
	head.add_child(_tokens_text)
	_luck_epic_text = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED)
	col.add_child(_luck_epic_text)
	_luck_epic = UiKit.progress(0.0, 12.0, CosmeticItem.rarity_color(CosmeticItem.Rarity.EPIC))
	col.add_child(_luck_epic)
	_luck_legendary_text = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED)
	col.add_child(_luck_legendary_text)
	_luck_legendary = UiKit.progress(0.0, 12.0, CosmeticItem.rarity_color(CosmeticItem.Rarity.LEGENDARY))
	col.add_child(_luck_legendary)
	return side


func _refresh_machine() -> void:
	if not _built:
		return
	var s := PrizePrints.series()
	var n := PrizePrints.capsules()
	_machine.capsule_count = n
	_open.text = "OPEN CAPSULE" if n > 0 else "NO CAPSULES"
	_open.disabled = n <= 0 or _busy
	_buy.text = "BUY 1  %s" % Wallet.format(s.capsule_price)
	_buy.disabled = _busy or not PrizePrints.can_buy_capsule()
	_capsule_note.text = "%d capsule%s to open  ·  earned from alphas, bounties, the day's first clear" % [n, "" if n == 1 else "s"]
	var luck := PrizePrints.luck()
	_luck_epic_text.text = "Epic or better guaranteed within %d capsule%s" % [luck.x, "" if luck.x == 1 else "s"]
	_luck_epic.value = 1.0 - float(luck.x - 1) / s.epic_pity
	_luck_legendary_text.text = "Legendary guaranteed within %d capsule%s" % [luck.y, "" if luck.y == 1 else "s"]
	_luck_legendary.value = 1.0 - float(luck.y - 1) / s.legendary_pity
	_tokens_text.text = "%d PRIZE TOKENS" % PrizePrints.tokens()


func _open_capsule() -> void:
	if _busy:
		return
	var res := PrizePrints.open_capsule()
	if res.is_empty():
		UiSound.deny()
		UiFx.deny(_open)
		return
	_busy = true
	_pending = res
	Sfx.play(&"prz_insert", -4.0)
	_machine.turn(PrintLook.rarity_color(res["print"]))
	_refresh_machine()


func _buy_capsule() -> void:
	if _busy:
		return
	var price := PrizePrints.series().capsule_price
	if not PrizePrints.can_buy_capsule():
		Sfx.play(&"eco_deny")
		UiFx.deny(_buy)
		return
	UiKit.confirm(self, "BUY A PRIZE CAPSULE?", "One capsule for %s Sparks. Odds are on the ODDS tab; no real money, ever." % Wallet.format(price), "BUY", func():
		if PrizePrints.buy_capsule():
			Sfx.play(&"eco_purchase", -4.0)
			UiFx.pulse(_open)
			_open.grab_focus())


func _on_machine_turned() -> void:
	_machine.take_capsule()
	var from := _machine.get_global_transform_with_canvas() * _machine.chute_point()
	from = _reveal.get_global_transform_with_canvas().affine_inverse() * from
	_reveal.play(_pending, from, _weapon_for(_pending["print"]), PrizePrints.capsules() > 0)


## The weapon a print is revealed on: the one it fits, else the last weapon played.
func _weapon_for(p: Dictionary) -> WeaponData:
	var w := String(p.get("w", ""))
	return GameData.weapon(StringName(w)) if w != "" else _weapon()


func _on_another() -> void:
	_reveal.close()
	_open_capsule()


func _on_reveal_equip(p: Dictionary) -> void:
	var weapon := _weapon_for(p)
	if PrizePrints.equip(p, weapon.id):
		UiSound.equip()
		UiKit.toast("%s %s is on your %s" % [PrintLook.title(p), PrintLook.serial_text(int(p["serial"])), weapon.display_name], UiKit.GREEN)
	_reveal.close()


func _on_reveal_closed() -> void:
	_busy = false
	var p: Dictionary = _pending.get("print", {})
	_pending = {}
	_refresh_machine()
	_refresh_view()
	if not p.is_empty() and PrizePrints.held().has(p) and _view == &"collection":
		_select(p)
	_open.grab_focus.call_deferred()


func _on_prints_changed() -> void:
	if _built and is_visible_in_tree() and not _reveal.visible:
		_refresh_machine()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree() and _built:
		Profile.save_profile()


# --- views ------------------------------------------------------------------------------

func _show_view(id: StringName) -> void:
	_view = id
	for v in _views:
		(_views[v] as Control).visible = v == id
	_tabs.select(id)
	if _built:
		_refresh_view()


func _refresh_view() -> void:
	match _view:
		&"collection":
			_fill_collection()
		&"tradeup":
			_fill_trade_up()
		&"counter":
			_fill_counter()
		&"odds":
			_fill_odds()


# --- collection ---------------------------------------------------------------------------

func _build_collection() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	var tray := UiKit.metal_frame(26)
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tray)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	tray.add_child(col)
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(filters)
	_rarity_tabs = UiKit.tabs(18)
	for t in [[&"all", "ALL"], [&"0", "COMMON"], [&"1", "RARE"], [&"2", "EPIC"], [&"3", "LEGENDARY"]]:
		_rarity_tabs.add_tab(t[0], t[1])
	_rarity_tabs.tab_changed.connect(func(id: StringName):
		_rarity_filter = -1 if id == &"all" else int(String(id))
		_fill_collection())
	filters.add_child(_rarity_tabs)
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(toggles)
	_rare_button = UiKit.sign_button("RARE PRINTS", SignButton.Kind.NEUTRAL, 20)
	_rare_button.toggle_mode = true
	_rare_button.toggled.connect(func(on: bool):
		_only_rare = on
		_fill_collection())
	toggles.add_child(_rare_button)
	_sort_button = UiKit.sign_button("", SignButton.Kind.SECONDARY, 20)
	_sort_button.pressed.connect(func():
		_sort = (_sort + 1) % SORTS.size()
		_fill_collection())
	toggles.add_child(_sort_button)
	toggles.add_child(UiKit.filler())
	var caption := UiKit.section("", " ")
	_caption = caption.get_child(0) as Label
	_caption_note = caption.get_child(2) as Label
	col.add_child(caption)
	var area := Control.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(area)
	_scroll = UiKit.scroll()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.resized.connect(func(): _fit_columns(_grid, _scroll))
	area.add_child(_scroll)
	_grid = _new_grid(_scroll)
	_empty = UiKit.body("", 0.0, UiKit.SIZE_LABEL, UiKit.MUTED)
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_empty)
	_auto_button = UiKit.sign_button("", SignButton.Kind.NEUTRAL, 20)
	_auto_button.tooltip_text = "Plain repeats (Factory or Polished, no rare print, serial above #%03d) become Prize Tokens as they drop." % PrizePrints.series().low_serial
	_auto_button.pressed.connect(func():
		PrizePrints.set_auto_recycle(not PrizePrints.auto_recycle())
		_refresh_auto())
	toggles.add_child(_auto_button)
	_inspect = PrintInspect.new()
	_inspect.custom_minimum_size.x = 440
	_inspect.changed.connect(_on_inspect_changed)
	row.add_child(_inspect)
	return row


func _new_grid(scroll: ScrollContainer) -> GridContainer:
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


func _fit_columns(grid: GridContainer, scroll: ScrollContainer) -> void:
	var room := scroll.size.x - GRID_MARGIN * 2.0 - 18.0
	grid.columns = clampi(int((room + CARD_GAP) / (PrintCard.CARD_SIZE.x + CARD_GAP)), 2, 9)


## The prints the filters let through, sorted.
func _shown_prints() -> Array:
	var list := PrizePrints.held().filter(func(p):
		return (_rarity_filter < 0 or PrizePrints.rarity(p) == _rarity_filter) \
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


func _fill_collection() -> void:
	var list := _shown_prints()
	_fill_cards(_grid, _cards, list, _on_card_chosen)
	_sort_button.text = "SORT: " + SORTS[_sort]
	_refresh_auto()
	var fin := Cosmetics.item(_finish_filter)
	_caption.text = ("PRINTS OF " + fin.display_name.to_upper()) if fin else "YOUR PRINTS"
	_caption_note.text = "%d shown  ·  %d held  ·  %d new" % [list.size(), PrizePrints.held().size(), PrizePrints.new_count()]
	_empty.visible = list.is_empty()
	_empty.text = "No prints yet.\nOpen a Prize Capsule: every one drops a unique print." if PrizePrints.held().is_empty() else "No prints match the filters."
	if _selected.is_empty() or not list.has(_selected):
		_selected = list[0] if not list.is_empty() else {}
	_select(_selected)
	UiFx.stagger_in(_cards.filter(func(c: PrintCard) -> bool: return c.visible))


func _fill_cards(grid: GridContainer, cards: Array[PrintCard], list: Array, chosen: Callable) -> void:
	while cards.size() < list.size():
		var card := PrintCard.create()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.button_group = _card_group if grid == _grid else null
		card.toggle_mode = grid == _grid
		card.pressed.connect(func(): chosen.call(card))
		grid.add_child(card)
		cards.append(card)
	var weapon := _weapon()
	for i in cards.size():
		var card := cards[i]
		card.visible = i < list.size()
		if card.visible:
			card.show_print(list[i], _weapon_for(list[i]) if String(list[i].get("w", "")) != "" else weapon, _thumbs)


func _refresh_auto() -> void:
	_auto_button.text = "AUTO-RECYCLE: " + ("ON" if PrizePrints.auto_recycle() else "OFF")


func _on_card_chosen(card: PrintCard) -> void:
	_select(card.print_data)


func _select(p: Dictionary) -> void:
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
		_fill_collection()
	_refresh_machine()


# --- trade-up -------------------------------------------------------------------------------

func _build_trade_up() -> Control:
	var tray := UiKit.metal_frame(26)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	tray.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_M)
	col.add_child(head)
	head.add_child(UiKit.label("TRADE-UP  ·  %d PRINTS  →  1 OF THE NEXT RARITY" % PrizePrints.series().trade_up_count, UiKit.SIZE_LABEL, UiKit.CREAM, true))
	_tu_tabs = UiKit.tabs(20)
	for r in 3:
		_tu_tabs.add_tab(StringName(str(r)), "%s → %s" % [_rn(r).to_upper(), _rn(r + 1).to_upper()])
	_tu_tabs.tab_changed.connect(func(id: StringName):
		_tu_rarity = int(String(id))
		_tu_picked.clear()
		_fill_trade_up())
	col.add_child(_tu_tabs)
	var press := HBoxContainer.new()
	press.alignment = BoxContainer.ALIGNMENT_CENTER
	press.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(press)
	for i in PrizePrints.series().trade_up_count:
		var slot := PrintCard.create(Vector2(150, 176))
		slot.toggle_mode = false
		slot.pressed.connect(_unpick_slot.bind(i))
		press.add_child(slot)
		_tu_slots.append(slot)
	var arrow := UiKit.arcade_label("→", 64, UiKit.CREAM)
	press.add_child(arrow)
	var result := UiKit.neon_panel(UiKit.PURPLE, 10)
	result.custom_minimum_size = Vector2(150, 176)
	_tu_result = UiKit.arcade_label("?", 96, UiKit.MUTED)
	_tu_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tu_result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.add_child(_tu_result)
	press.add_child(result)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", UiKit.GAP_M)
	col.add_child(actions)
	_tu_note = UiKit.body("", 0.0, UiKit.SIZE_BODY, UiKit.MUTED)
	_tu_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(_tu_note)
	var fill := UiKit.sign_button("AUTO-FILL", SignButton.Kind.SECONDARY, 24)
	fill.tooltip_text = "Fills the press with your least special prints of this rarity."
	fill.pressed.connect(_auto_fill)
	actions.add_child(fill)
	var clear := UiKit.sign_button("CLEAR", SignButton.Kind.NEUTRAL, 24)
	clear.pressed.connect(func():
		_tu_picked.clear()
		_fill_trade_up())
	actions.add_child(clear)
	_tu_button = UiKit.sign_button("TRADE UP", SignButton.Kind.PRIMARY, 28)
	_tu_button.pressed.connect(_confirm_trade_up)
	actions.add_child(_tu_button)
	col.add_child(UiKit.section("ELIGIBLE PRINTS", "favourites and worn prints are protected"))
	var scroll := UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_tu_grid = _new_grid(scroll)
	scroll.resized.connect(func(): _fit_columns(_tu_grid, scroll))
	return tray


func _fill_trade_up() -> void:
	_tu_tabs.select(StringName(str(_tu_rarity)))
	var candidates := PrizePrints.trade_up_candidates(_tu_rarity)
	_tu_picked = _tu_picked.filter(func(p): return candidates.has(p))
	candidates.sort_custom(func(a, b): return PrintLook.score(a) < PrintLook.score(b))
	_fill_cards(_tu_grid, _tu_cards, candidates, _toggle_pick)
	for card in _tu_cards:
		card.set_pick(str(_tu_picked.find(card.print_data) + 1) if _tu_picked.has(card.print_data) else "")
		card.modulate.a = 0.45 if _tu_picked.has(card.print_data) else 1.0
	var weapon := _weapon()
	for i in _tu_slots.size():
		var slot := _tu_slots[i]
		slot.visible = true
		if i < _tu_picked.size():
			slot.show_print(_tu_picked[i], weapon, _thumbs)
			slot.modulate.a = 1.0
		else:
			slot.print_data = {}
			slot.set_title("EMPTY")
			slot.set_image(null)
			slot.set_tag("")
			slot.set_status("")
			slot.set_rarity(Color.TRANSPARENT)
			slot.set_new(false)
			slot.modulate.a = 0.5
	var next := _rc(_tu_rarity + 1)
	_tu_result.add_theme_color_override("font_color", next)
	var problem := PrizePrints.trade_up_problem(_tu_picked)
	_tu_button.disabled = problem != ""
	var need := PrizePrints.series().trade_up_count
	_tu_note.text = "%d of %d picked. Out comes one random %s print with fresh rolls (shine, rare print, serial)." % [_tu_picked.size(), need, _rn(_tu_rarity + 1)] \
		if candidates.size() >= need else "You have %d eligible %s print%s; a trade-up takes %d." % [candidates.size(), _rn(_tu_rarity), "" if candidates.size() == 1 else "s", need]


func _toggle_pick(card: PrintCard) -> void:
	var p := card.print_data
	if _tu_picked.has(p):
		_tu_picked.erase(p)
	elif _tu_picked.size() < PrizePrints.series().trade_up_count:
		_tu_picked.append(p)
	else:
		UiSound.deny()
		return
	_fill_trade_up()


func _unpick_slot(i: int) -> void:
	if i < _tu_picked.size():
		_tu_picked.remove_at(i)
		UiSound.select()
		_fill_trade_up()


func _auto_fill() -> void:
	var candidates := PrizePrints.trade_up_candidates(_tu_rarity)
	candidates.sort_custom(func(a, b): return PrintLook.score(a) < PrintLook.score(b))
	_tu_picked = candidates.slice(0, PrizePrints.series().trade_up_count)
	UiSound.select()
	_fill_trade_up()


func _confirm_trade_up() -> void:
	if PrizePrints.trade_up_problem(_tu_picked) != "":
		UiSound.deny()
		return
	var names := PackedStringArray()
	for p in _tu_picked:
		names.append("%s %s" % [PrintLook.title(p), PrintLook.serial_text(int(p["serial"]))])
	var text := "These five go into the press for good:\n%s\n\nOut comes one random %s print." % ["\n".join(names), _rn(_tu_rarity + 1)]
	UiKit.confirm(self, "TRADE UP?", text, "TRADE UP", _trade_up)


## The five slots shrink into the press one by one, the "?" flares, and the
## new print is revealed like a capsule.
func _trade_up() -> void:
	var picked := _tu_picked.duplicate()
	var res := PrizePrints.trade_up(picked)
	if res.is_empty():
		UiSound.deny()
		return
	_busy = true
	_tu_picked.clear()
	_pending = res
	var tw := create_tween()
	for i in picked.size():
		var slot := _tu_slots[i]
		slot.pivot_offset = slot.size * 0.5
		tw.tween_callback(Sfx.play.bind(&"prz_tick", -8.0, 0.9 + 0.12 * i))
		tw.tween_property(slot, "scale", Vector2.ONE * 0.2, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(slot, "modulate:a", 0.0, 0.14)
	tw.tween_callback(Sfx.play.bind(&"prz_tradeup", -3.0))
	tw.tween_property(_tu_result, "scale", Vector2.ONE * 1.4, 0.18)
	tw.tween_property(_tu_result, "scale", Vector2.ONE, 0.18)
	tw.tween_callback(func():
		for slot in _tu_slots:
			slot.scale = Vector2.ONE
		var from := _reveal.get_global_transform_with_canvas().affine_inverse() * (_tu_result.get_global_transform_with_canvas() * (_tu_result.size * 0.5))
		_reveal.play(res, from, _weapon_for(res["print"]), false))


# --- Token Counter ----------------------------------------------------------------------------

func _build_counter() -> Control:
	var tray := UiKit.metal_frame(26)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	tray.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_M)
	col.add_child(head)
	head.add_child(UiKit.label("THE TOKEN COUNTER", UiKit.SIZE_HEADING, UiKit.CREAM, true))
	head.add_child(UiKit.filler())
	_counter_tokens = UiKit.label("", UiKit.SIZE_HEADING, UiKit.AMBER, true)
	head.add_child(_counter_tokens)
	col.add_child(UiKit.body("Repeats become Prize Tokens; spend them here on a fresh print of today's finishes. " +
		"Each shelf finish can be bought once a day; every print still rolls its own shine, rare print and serial.", 900.0, UiKit.SIZE_BODY, UiKit.MUTED))
	_counter_clock = UiKit.label("", UiKit.SIZE_SMALL, UiKit.CYAN, true)
	col.add_child(_counter_clock)
	_counter_row = HBoxContainer.new()
	_counter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_counter_row.add_theme_constant_override("separation", UiKit.GAP_L)
	_counter_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_counter_row)
	return tray


func _fill_counter() -> void:
	for c in _counter_row.get_children():
		c.queue_free()
	_counter_tokens.text = "%d TOKENS" % PrizePrints.tokens()
	var minutes := ceili(ShopCatalog.seconds_to_rotation() / 60.0)
	_counter_clock.text = "NEW SHELF IN %d H %02d MIN" % [minutes / 60, minutes % 60]
	var weapon := _weapon()
	for fid in PrizePrints.counter_shelf():
		var fin := Cosmetics.item(fid)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", UiKit.GAP_S)
		_counter_row.add_child(col)
		var card := UiKit.item_card(fin.display_name.to_upper(), Vector2(250, 290))
		card.toggle_mode = false
		card.set_rarity(CosmeticItem.rarity_color(fin.rarity))
		card.set_tag(CosmeticItem.rarity_name(fin.rarity).to_upper(), CosmeticItem.rarity_color(fin.rarity))
		var held := PrizePrints.prints_of(fid).size()
		card.set_status("%d held" % held if held > 0 else "not in your collection", UiKit.MUTED)
		_thumbs.request(fin, func(tex: Texture2D): card.set_image(tex), weapon)
		col.add_child(card)
		var price := PrizePrints.counter_price(fid)
		var buy := UiKit.sign_button("SOLD TODAY" if PrizePrints.counter_sold(fid) else "%d TOKENS" % price, SignButton.Kind.GOLD, 26)
		buy.disabled = not PrizePrints.can_buy_at_counter(fid)
		buy.pressed.connect(_buy_at_counter.bind(fid, card))
		card.pressed.connect(_buy_at_counter.bind(fid, card))
		col.add_child(buy)


func _buy_at_counter(fid: StringName, card: Control) -> void:
	if _busy or not PrizePrints.can_buy_at_counter(fid):
		UiSound.deny()
		return
	var fin := Cosmetics.item(fid)
	UiKit.confirm(self, "BUY A FRESH PRINT?", "A new %s print for %d Prize Tokens, with its own rolls." % [fin.display_name, PrizePrints.counter_price(fid)], "BUY", func():
		var res := PrizePrints.buy_at_counter(fid)
		if res.is_empty():
			return
		_busy = true
		_pending = res
		Sfx.play(&"prz_token", -4.0)
		var from := _reveal.get_global_transform_with_canvas().affine_inverse() * (card.get_global_transform_with_canvas() * (card.size * 0.5))
		_reveal.play(res, from, _weapon_for(res["print"]), false))


# --- odds ---------------------------------------------------------------------------------------

func _build_odds() -> Control:
	var tray := UiKit.metal_frame(26)
	var scroll := UiKit.scroll()
	tray.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", UiKit.GAP_XL)
	scroll.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 470
	left.add_theme_constant_override("separation", UiKit.GAP_S)
	cols.add_child(left)
	var s := PrizePrints.series()
	left.add_child(UiKit.section("ODDS PER CAPSULE", "always shown"))
	for r in 4:
		left.add_child(_odds_row(_rn(r).to_upper(), "%d%%" % roundi(s.odds[r] * 100.0), _rc(r)))
	left.add_child(UiKit.body("Luck meter: an Epic or better is guaranteed within %d capsules, a Legendary within %d. With it, the real rates come to about 58 / 26 / 12.5 / 4%%." % [s.epic_pity, s.legendary_pity], 470.0, UiKit.SIZE_SMALL, UiKit.MUTED))
	left.add_child(UiKit.section("RARE PRINTS", "one roll per print"))
	for v in ["glitter", "holo", "misprint"]:
		left.add_child(_odds_row(String(PrintLook.VARIANTS[v]["name"]).to_upper(), PrintLook.variant_odds(v), PrintLook.VARIANTS[v]["color"]))
	left.add_child(UiKit.section("SHINE GRADES", "from a 0-1 shine roll"))
	left.add_child(_odds_row("FACTORY", "%d%%  (below %.2f)" % [roundi(s.polished_at * 100.0), s.polished_at], PrintLook.GRADE_COLORS[0]))
	left.add_child(_odds_row("POLISHED", "%d%%" % roundi((s.mint_at - s.polished_at) * 100.0), PrintLook.GRADE_COLORS[1]))
	left.add_child(_odds_row("MINT", "%d%%  (%.2f and up)" % [roundi((1.0 - s.mint_at) * 100.0), s.mint_at], PrintLook.GRADE_COLORS[2]))
	left.add_child(UiKit.section("EARN CAPSULES"))
	for line in ["%d per alpha defeated" % s.capsules_per_alpha, "%d per bounty claimed" % s.capsules_per_bounty,
			"%d for the day's first clear" % s.capsules_daily_clear, "1 for every %d contracts" % s.contracts_per_capsule,
			"%d per milestone" % s.capsules_per_milestone, "Buy with Sparks: %s each (no real money)" % Wallet.format(s.capsule_price)]:
		left.add_child(UiKit.label("·  " + line, UiKit.SIZE_BODY, UiKit.CREAM))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", UiKit.GAP_S)
	cols.add_child(right)
	right.add_child(UiKit.section("SERIES %d  ·  %s" % [s.number, s.display_name.to_upper()], "%d finishes" % s.finishes.size()))
	right.add_child(UiKit.body("Prints are their own collectibles: a print never takes the plain finish out of the Shop or the reward tracks, and owning the plain finish never stops it dropping. Serials count up per finish on your profile; #001 is a First Edition, #002-#%03d Low Serials." % s.low_serial, 640.0, UiKit.SIZE_SMALL, UiKit.MUTED))
	_odds_series = GridContainer.new()
	_odds_series.columns = 2
	_odds_series.add_theme_constant_override("h_separation", UiKit.GAP_L)
	right.add_child(_odds_series)
	return tray


func _odds_row(caption: String, value: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	var chip := UiKit.chip(caption, color, 18)
	chip.custom_minimum_size.x = 190
	row.add_child(chip)
	row.add_child(UiKit.filler())
	row.add_child(UiKit.label(value, UiKit.SIZE_LABEL, UiKit.CREAM, true))
	return row


func _fill_odds() -> void:
	for c in _odds_series.get_children():
		c.queue_free()
	var by := PrizePrints.by_rarity()
	for r in range(3, -1, -1):
		for fid in by.get(r, []):
			var fin := Cosmetics.item(fid)
			var held := PrizePrints.prints_of(fid).size()
			var text := "%s  %s" % [fin.display_name, ("×%d" % held) if held > 0 else "-"]
			_odds_series.add_child(UiKit.label(text, UiKit.SIZE_SMALL, _rc(r) if held > 0 else Color(_rc(r), 0.5), held > 0))
