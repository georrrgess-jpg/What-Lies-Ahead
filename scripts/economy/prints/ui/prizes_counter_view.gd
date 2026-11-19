class_name PrizesCounterView
extends VBoxContainer
## The CREDIT COUNTER tab: a fairground prize counter. The Capsule Credits
## held (PrizePrints "tokens" in code) and when the shelf changes on a
## signboard, today's four finishes (one per rarity) as big cards with their
## credit price, and how repeats become credits. Every buy is a fresh print with its own rolls, revealed like a
## capsule.

const CARD := Vector2(300, 330)

var _page: PrizesPage
var _tokens: Label
var _clock: Label
var _shelf: HBoxContainer


func _init(page: PrizesPage) -> void:
	_page = page
	add_theme_constant_override("separation", UiKit.GAP_M)
	var board := UiKit.signboard(20)
	add_child(board)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_L)
	board.add_child(head)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(UiKit.sign_label("THE CREDIT COUNTER", 52))
	titles.add_child(UiKit.body("Repeats become Capsule Credits. Trade them here for a fresh print of today's finishes: each can be bought once a day, and each still rolls its own shine, rare print and serial.",
		980.0, UiKit.SIZE_SMALL, UiKit.MUTED))
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 0)
	head.add_child(right)
	var credits := HBoxContainer.new()
	credits.alignment = BoxContainer.ALIGNMENT_END
	credits.add_theme_constant_override("separation", UiKit.GAP_S)
	right.add_child(credits)
	credits.add_child(UiKit.icon(&"icon_credit", 96.0))
	_tokens = UiKit.arcade_label("", 64, UiKit.AMBER)
	_tokens.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits.add_child(_tokens)
	_clock = UiKit.label("", UiKit.SIZE_SMALL, UiKit.CYAN, true)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_clock)
	var tray := UiKit.metal_frame(24)
	tray.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tray)
	var center := CenterContainer.new()
	tray.add_child(center)
	_shelf = HBoxContainer.new()
	_shelf.add_theme_constant_override("separation", UiKit.GAP_XL)
	center.add_child(_shelf)
	var rates := HBoxContainer.new()
	rates.alignment = BoxContainer.ALIGNMENT_CENTER
	rates.add_theme_constant_override("separation", UiKit.GAP_S)
	add_child(rates)
	rates.add_child(UiKit.label("A RECYCLED REPEAT PAYS", UiKit.SIZE_SMALL, UiKit.CREAM, true))
	var s := PrizePrints.series()
	for r in 4:
		rates.add_child(UiKit.chip("%s  %d" % [PrizesPage.rarity_name(r).to_upper(), s.token_value[r]], PrizesPage.rarity_color(r), 16))


func refresh() -> void:
	for c in _shelf.get_children():
		c.queue_free()
	_tokens.text = "%d CREDITS" % PrizePrints.tokens()
	var minutes := ceili(ShopCatalog.seconds_to_rotation() / 60.0)
	_clock.text = "NEW SHELF IN %d H %02d MIN" % [minutes / 60, minutes % 60]
	var weapon := _page.default_weapon()
	for fid in PrizePrints.counter_shelf():
		_shelf.add_child(_offer(fid, weapon))
	UiFx.stagger_in(_shelf.get_children())


func _offer(fid: StringName, weapon: WeaponData) -> Control:
	var fin := Cosmetics.item(fid)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	var rarity_col := CosmeticItem.rarity_color(fin.rarity)
	var card := UiKit.item_card(fin.display_name.to_upper(), CARD)
	card.toggle_mode = false
	card.set_rarity(rarity_col)
	card.set_tag(CosmeticItem.rarity_name(fin.rarity).to_upper(), rarity_col)
	var held := PrizePrints.prints_of(fid).size()
	card.set_status("%d held" % held if held > 0 else "not in your collection", UiKit.MUTED)
	_page.thumbs.request(fin, func(tex: Texture2D): card.set_image(tex), weapon)
	col.add_child(card)
	var price := PrizePrints.counter_price(fid)
	var buy := UiKit.sign_button("SOLD TODAY" if PrizePrints.counter_sold(fid) else "%d CREDITS" % price, SignButton.Kind.GOLD, 26)
	buy.icon = KitTex.tex(&"icon_credit")
	buy.disabled = not PrizePrints.can_buy_at_counter(fid)
	buy.pressed.connect(_buy.bind(fid))
	card.pressed.connect(_buy.bind(fid))
	col.add_child(buy)
	return col


func _buy(fid: StringName) -> void:
	if _page.busy or not PrizePrints.can_buy_at_counter(fid):
		UiSound.deny()
		return
	var fin := Cosmetics.item(fid)
	UiKit.confirm(self, "BUY A FRESH PRINT?", "A new %s print for %d Capsule Credits, with its own rolls." % [fin.display_name, PrizePrints.counter_price(fid)], "BUY", func():
		var res := PrizePrints.buy_at_counter(fid)
		if res.is_empty():
			return
		Sfx.play(&"prz_token", -4.0)
		_page.play_counter(res))
