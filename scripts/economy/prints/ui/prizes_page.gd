class_name PrizesPage
extends MenuPage
## Prizes: Prize Capsules and Prize Prints (docs/ECONOMY.md, "Prize Prints").
## Registered by data/ui/prizes.tres. One tab each, in the header:
##   CAPSULES       the machine alone, big, with the luck meter, the capsules
##                  held, OPEN / OPEN 5 / BUY and the odds (PrizesCapsulesView);
##   COLLECTION     every print as a card, filters and sort, the inspect view
##                  (wear, keep, recycle) (PrizesCollectionView);
##   TRADE-UP       Prize Fusion: five prints of a rarity into one of the next
##                  (PrizesFusionView);
##   CREDIT COUNTER today's shelf of fresh prints for Capsule Credits;
##   ODDS & INFO    the published odds, luck meter, rare prints, grades,
##                  earning capsules and the series.
## Openings play full screen over the menu (CapsuleReveal, FusionReveal).
## Keys: A / D change tab; Enter on OPEN opens a capsule.

const VIEWS := [[&"capsules", "CAPSULES"], [&"collection", "COLLECTION"], [&"tradeup", "TRADE-UP"],
	[&"counter", "CREDIT COUNTER"], [&"odds", "ODDS & INFO"]]
## The overlays sit above the menu's top bar.
const OVERLAY_LAYER := 20

var thumbs: CosmeticThumbs
var busy := false
var _built := false
var _header: Control
var _tabs: KitTabs
var _view := &"capsules"
var _views := {}
var _reveal: CapsuleReveal
var _fusion: FusionReveal
var _pending: Array = []
var capsules_view: PrizesCapsulesView
var collection_view: PrizesCollectionView
var fusion_view: PrizesFusionView
var counter_view: PrizesCounterView
var odds_view: PrizesOddsView


func uses_shell_header() -> bool:
	return true


func header_extra() -> Control:
	return _header


func _ready() -> void:
	thumbs = CosmeticThumbs.new()
	add_child(thumbs)
	_header = _build_header()
	capsules_view = PrizesCapsulesView.new(self)
	collection_view = PrizesCollectionView.new(self)
	fusion_view = PrizesFusionView.new(self)
	counter_view = PrizesCounterView.new(self)
	odds_view = PrizesOddsView.new(self)
	_views = {&"capsules": capsules_view, &"collection": collection_view, &"tradeup": fusion_view,
		&"counter": counter_view, &"odds": odds_view}
	for id in _views:
		var v: Control = _views[id]
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(v)
	var layer := CanvasLayer.new()
	layer.layer = OVERLAY_LAYER
	add_child(layer)
	_reveal = CapsuleReveal.new()
	_reveal.thumbs = thumbs
	_reveal.closed.connect(_on_reveal_closed)
	_reveal.another_requested.connect(_on_another)
	_reveal.equip_requested.connect(_on_reveal_equip)
	layer.add_child(_reveal)
	_fusion = FusionReveal.new()
	_fusion.closed.connect(_on_reveal_closed)
	_fusion.equip_requested.connect(_on_reveal_equip)
	layer.add_child(_fusion)
	Cosmetics.prints_changed.connect(_on_prints_changed)
	Wallet.balance_changed.connect(func(_b): capsules_view.refresh())
	visibility_changed.connect(_on_visibility_changed)
	show_view(_view)


func refresh() -> void:
	_built = true
	_refresh_badges()
	_refresh_view()


func first_focus() -> Control:
	return capsules_view.first_focus() if _view == &"capsules" else _tabs.button(_view)


func handle_back() -> bool:
	if _reveal.visible:
		_reveal.back()
		return true
	if _fusion.visible:
		_fusion.close()
		return true
	if _view == &"collection" and collection_view.clear_finish_filter():
		return true
	return false


## Opens the collection showing only the prints of one finish (the Locker's PRINTS button).
func show_finish(finish_id: StringName) -> void:
	collection_view.set_finish_filter(finish_id)
	show_view(&"collection")


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or KitDialog.open_count > 0 or _reveal.visible or _fusion.visible:
		return
	var step := 0
	if event.is_action_pressed("move_left"):
		step = -1
	elif event.is_action_pressed("move_right"):
		step = 1
	if step != 0:
		_tabs.step(step)
		get_viewport().set_input_as_handled()


## The weapon prints are shown on: the one a print fits, else the last weapon played.
func weapon_for(p: Dictionary) -> WeaponData:
	var w := String(p.get("w", ""))
	return GameData.weapon(StringName(w)) if w != "" else default_weapon()


func default_weapon() -> WeaponData:
	var w := GameData.weapon(StringName(String(Profile.data.get("last_weapon", ""))))
	return w if w else GameData.weapon(GameData.default_weapon_id())


static func rarity_color(r: int) -> Color:
	return CosmeticItem.rarity_color(clampi(r, 0, 3) as CosmeticItem.Rarity)


static func rarity_name(r: int) -> String:
	return CosmeticItem.rarity_name(clampi(r, 0, 3) as CosmeticItem.Rarity)


# --- tabs ---------------------------------------------------------------------------------

func _build_header() -> Control:
	var strip := UiKit.card_panel(6)
	_tabs = KitTabs.make(22, true)
	_tabs.add_theme_constant_override("separation", UiKit.GAP_XS)
	for v in VIEWS:
		var tab := _tabs.add_tab(v[0], v[1])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(show_view)
	strip.add_child(_tabs)
	return strip


func show_view(id: StringName) -> void:
	var was := _view
	_view = id
	for v in _views:
		(_views[v] as Control).visible = v == id
	_tabs.select(id)
	if _built:
		_refresh_view()
		if was != id:
			UiFx.page_in(_views[id], 1.0 if _tabs.ids().find(id) > _tabs.ids().find(was) else -1.0, 0.0)


func _refresh_view() -> void:
	(_views[_view]).refresh()


func _refresh_badges() -> void:
	_tabs.set_badge(&"capsules", PrizePrints.capsules())
	_tabs.set_badge(&"collection", PrizePrints.new_count())


# --- opening ------------------------------------------------------------------------------

## Opens `count` capsules (1, or 5 for OPEN 5) and plays the opening.
func open_capsules(count: int) -> void:
	if busy:
		return
	count = mini(count, PrizePrints.capsules())
	if count <= 0:
		UiSound.deny()
		capsules_view.deny_open()
		return
	_pending.clear()
	var weapons := []
	for i in count:
		var res := PrizePrints.open_capsule()
		if res.is_empty():
			break
		_pending.append(res)
	# The rarest is revealed last.
	_pending.sort_custom(func(a, b): return PrizePrints.rarity(a["print"]) < PrizePrints.rarity(b["print"]))
	for res in _pending:
		weapons.append(weapon_for(res["print"]))
	busy = true
	Sfx.play(&"prz_insert", -4.0)
	capsules_view.refresh()
	if _pending.size() == 1:
		_reveal.play(_pending[0], weapons[0], PrizePrints.capsules() > 0)
	else:
		_reveal.play_multi(_pending, weapons, PrizePrints.capsules() >= CapsuleReveal.MULTI)


func buy_capsule() -> void:
	if busy:
		return
	var price := PrizePrints.series().capsule_price
	if not PrizePrints.can_buy_capsule():
		Sfx.play(&"eco_deny")
		capsules_view.deny_buy()
		return
	UiKit.confirm(self, "BUY A PRIZE CAPSULE?", "One capsule for %s Tokens. The odds are always on ODDS & INFO; no real money, ever." % Wallet.format(price), "BUY", func():
		if PrizePrints.buy_capsule():
			Sfx.play(&"eco_purchase", -4.0)
			capsules_view.bought())


## Plays Prize Fusion for a trade-up that has happened (`res`, from `picked`).
func play_fusion(res: Dictionary, picked: Array) -> void:
	busy = true
	_pending = [res]
	_fusion.play(res, picked, weapon_for(res["print"]), thumbs)


## Plays the reveal of a Credit Counter buy.
func play_counter(res: Dictionary) -> void:
	busy = true
	_pending = [res]
	_reveal.play(res, weapon_for(res["print"]), false)


func _on_another(count: int) -> void:
	_reveal.close()
	open_capsules(count)


func _on_reveal_equip(p: Dictionary) -> void:
	var weapon := weapon_for(p)
	if PrizePrints.equip(p, weapon.id):
		UiSound.equip()
		UiKit.toast("%s %s is on your %s" % [PrintLook.title(p), PrintLook.serial_text(int(p["serial"])), weapon.display_name], UiKit.GREEN)
	if _reveal.visible:
		_reveal.back()
	else:
		_fusion.close()


func _on_reveal_closed() -> void:
	busy = false
	var last: Dictionary = _pending.back()["print"] if not _pending.is_empty() else {}
	_pending.clear()
	_refresh_badges()
	_refresh_view()
	if not last.is_empty() and PrizePrints.held().has(last):
		collection_view.select(last)
	var focus := first_focus()
	if focus:
		focus.grab_focus.call_deferred()


func _on_prints_changed() -> void:
	if _built and is_visible_in_tree() and not busy:
		_refresh_badges()
		capsules_view.refresh()


func _on_visibility_changed() -> void:
	if is_visible_in_tree() or not _built:
		return
	if _reveal.visible:
		_reveal.close()
	if _fusion.visible:
		_fusion.close()
	Profile.save_profile()
