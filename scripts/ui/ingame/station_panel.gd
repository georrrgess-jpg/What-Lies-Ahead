class_name StationPanel
extends Control
## The loadout station's panel (left side of the HUD, shown while the player
## stands at the station between waves): a signboard with the tickets
## balance, the four purchases as cards, the free weapon swap as a row of
## weapon cards and a footer with the key that starts the next wave and the
## time left. Built once; the HUD pushes values in and each setter only
## touches what changed.
##
##   panel.configure(offers)                 # once: key, icon, title, effect per card
##   panel.set_tickets(260)
##   panel.set_offer(0, StationCard.State.BUY, 100)
##   panel.set_swap("PRIMARY", weapons, 1, "Z", "X")
##   panel.set_next_wave("START WAVE 4", 18)
##   panel.open() / panel.close()

const WIDTH := 600.0
const SLIDE := 60.0

var _board: KitPanel
var _tickets: Label
var _tickets_chip: PanelContainer
var _grid: GridContainer
var _cards: Array[StationCard] = []
var _slot_note: Label
var _swap_cards: Array[PanelContainer] = []
var _swap_pictures: Array[TextureRect] = []
var _swap_names: Array[Label] = []
var _swap_keys: Array[Label] = []
var _swap_note: Label
var _next: Label
var _next_key: Label
var _timer: Label
var _shown_tickets := -1
var _shown_seconds := -1
var _shown_swap := ""
var _tween: Tween
var _is_open := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_board = UiKit.signboard()
	_board.set_padding(30, 24)
	_board.custom_minimum_size.x = WIDTH
	add_child(_board)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_board.add_child(col)
	_build_header(col)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	col.add_child(_grid)
	_build_swap(col)
	_build_footer(col)


func _build_header(col: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_M)
	col.add_child(head)
	var title := UiKit.sign_label("LOADOUT STATION", 40, UiKit.AMBER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_tickets_chip = PanelContainer.new()
	var box := UiKit.box(Color(UiKit.INK, 0.9), Color(UiKit.AMBER, 0.9), 22, 2, 4)
	box.content_margin_left = 14
	box.content_margin_right = 18
	_tickets_chip.add_theme_stylebox_override("panel", box)
	_tickets_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_tickets_chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_tickets_chip.add_child(row)
	row.add_child(HudIcon.make(&"ticket", 32.0, UiKit.AMBER))
	_tickets = UiKit.label("0", 32, UiKit.AMBER, true)
	row.add_child(_tickets)


func _build_swap(col: VBoxContainer) -> void:
	var caption := UiKit.section("FREE WEAPON SWAP")
	_slot_note = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED)
	caption.add_child(_slot_note)
	col.add_child(caption)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	_swap_keys.append(_key_cap(row))
	for i in 3:
		var held := i == 1
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", KitTex.box_copy(&"card_selected" if held else &"card", Color.WHITE, Vector2(8, 6)))
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -4)
		card.add_child(v)
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(176, 84) if held else Vector2(112, 54)
		picture.modulate = Color.WHITE if held else Color(0.75, 0.72, 0.88)
		v.add_child(picture)
		var name_label := UiKit.label("", 22 if held else 16, UiKit.CREAM if held else UiKit.MUTED, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.clip_text = true
		v.add_child(name_label)
		_swap_cards.append(card)
		_swap_pictures.append(picture)
		_swap_names.append(name_label)
	_swap_keys.append(_key_cap(row))
	_swap_note = UiKit.label("", UiKit.SIZE_SMALL, UiKit.AMBER)
	_swap_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_swap_note)


func _key_cap(row: HBoxContainer) -> Label:
	var cap := UiKit.key_glyph("?", 46.0)
	row.add_child(cap)
	return cap.get_child(0) as Label


func _build_footer(col: VBoxContainer) -> void:
	var plate := UiKit.neon_panel(UiKit.PINK)
	plate.set_padding(16, 8)
	col.add_child(plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	plate.add_child(row)
	var cap := UiKit.key_glyph("F", 46.0)
	_next_key = cap.get_child(0) as Label
	row.add_child(cap)
	_next = UiKit.sign_label("START WAVE", 30)
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_next)
	row.add_child(HudIcon.make(&"clock", 30.0, UiKit.CYAN))
	_timer = UiKit.label("0:00", 32, UiKit.CYAN, true)
	_timer.custom_minimum_size.x = 70
	row.add_child(_timer)


## Sets up the purchase cards. Each offer: { key, icon, title, effect, accent }.
func configure(offers: Array) -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()
	for offer in offers:
		var card := StationCard.make(offer["key"], offer["icon"], offer["title"], offer["effect"], offer["accent"])
		_grid.add_child(card)
		_cards.append(card)


## The tickets balance: counts to the new value, and pops when tickets are spent.
func set_tickets(tickets: int) -> void:
	if tickets == _shown_tickets:
		return
	var from := _shown_tickets
	_shown_tickets = tickets
	if from < 0 or not is_visible_in_tree():
		_tickets.text = str(tickets)
		return
	UiFx.count_up(_tickets, from, tickets, 0.35, func(n: int) -> String: return str(n))
	UiFx.pulse(_tickets_chip, 1.1)


## State of purchase card `index` (see StationCard.set_state).
func set_offer(index: int, state: StationCard.State, price: int, note := "") -> void:
	if index < _cards.size():
		_cards[index].set_state(state, price, note)


## The free swap: the held slot's name, the weapons it can take and which one
## it holds now, with the keys that step back and forward.
func set_swap(slot_name: String, weapons: Array[WeaponData], index: int, prev_key: String, next_key: String) -> void:
	var count := weapons.size()
	var held: WeaponData = weapons[index] if index >= 0 and index < count else null
	var signature := "%s|%d|%d|%s" % [slot_name, count, index, held.id if held else &""]
	if signature == _shown_swap:
		return
	var first := _shown_swap == ""
	_shown_swap = signature
	_slot_note.text = slot_name
	_swap_keys[0].text = prev_key
	_swap_keys[1].text = next_key
	# The neighbours: the previous weapon needs three to choose from, the next two.
	var shown: Array[WeaponData] = [null, held, null]
	if held and count >= 3:
		shown[0] = weapons[posmod(index - 1, count)]
	if held and count >= 2:
		shown[2] = weapons[posmod(index + 1, count)]
	for i in 3:
		var w := shown[i]
		_swap_cards[i].visible = w != null
		if w:
			_swap_pictures[i].texture = WeaponThumbs.texture(w)
			_swap_names[i].text = w.display_name.to_upper()
	for key in _swap_keys:
		(key.get_parent() as Control).modulate.a = 1.0 if count > 1 else 0.35
	if held == null:
		_swap_note.text = ""
	elif count <= 1:
		_swap_note.text = "Level up to unlock more weapons"
	else:
		_swap_note.text = "%s  ·  %d of %d  ·  1 / 2 picks the slot" % [held.category, index + 1, count]
	if not first and is_visible_in_tree():
		UiFx.pulse(_swap_cards[1], 1.06)


## The footer: what the start key does and the seconds left in the break.
func set_next_wave(text: String, seconds: int, key := "F") -> void:
	if _next.text != text:
		_next.text = text
		_next_key.text = key
	if seconds == _shown_seconds:
		return
	_shown_seconds = seconds
	_timer.text = "%d:%02d" % [seconds / 60, seconds % 60]
	_timer.add_theme_color_override("font_color", UiKit.RED if seconds <= 5 else UiKit.CYAN)


## A purchase was refused: the tickets shake.
func deny() -> void:
	if _is_open:
		UiFx.deny(_tickets_chip)


## Slides the panel in from the left edge.
func open() -> void:
	if _is_open:
		return
	_is_open = true
	_restart_tween()
	visible = true
	_board.position.x = -SLIDE
	_board.modulate.a = 0.0
	_tween.set_parallel(true)
	_tween.tween_property(_board, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_board, "modulate:a", 1.0, 0.16)
	UiFx.stagger_in(_cards, 0.06)
	UiSound.open()


## Slides it back out.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_restart_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_board, "position:x", -SLIDE, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_board, "modulate:a", 0.0, 0.16)
	_tween.chain().tween_callback(func(): visible = false)


func _restart_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
