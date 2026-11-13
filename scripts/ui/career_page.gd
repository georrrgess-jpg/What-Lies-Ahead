class_name CareerPage
extends MenuPage
## Career: where the player stands and what comes next, on one screen.
##   - The level road: every level's reward as a card on a road that scrolls
##     sideways (claimed, NEXT, upcoming), beside the level and its XP bar.
##   - Goals: the three active contracts and the long-term milestones.
##   - Weapon mastery: a card per weapon with tier, rank and the next reward.
##   - Lifetime numbers in the header row.
## Whatever has the keyboard focus (or the pointer) is explained in the line
## under its section. Enter on a road reward or a weapon opens it in the
## Locker. Registered by data/ui/career.tres.

## Claimed levels kept in view to the left of the next one.
const ROAD_LEAD := 2
const MASTERY_COLUMNS := 4

var _header: HBoxContainer
var _level_slot: MarginContainer
var _road_scroll: ScrollContainer
var _road: HBoxContainer
var _road_detail: Label
var _contracts: MarginContainer
var _milestones: HBoxContainer
var _goal_detail: Label
var _goal_note: Label
var _milestone_note: Label
var _mastery: GridContainer
var _mastery_detail: Label
var _thumbs: CosmeticThumbs
var _next_card: Control
## Hash of what the cards were last built from.
var _state := 0


func uses_shell_header() -> bool:
	return true


func header_extra() -> Control:
	return _header


func _ready() -> void:
	_thumbs = CosmeticThumbs.new()
	add_child(_thumbs)
	_header = HBoxContainer.new()
	_header.alignment = BoxContainer.ALIGNMENT_END
	_header.add_theme_constant_override("separation", UiKit.GAP_S)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	add_child(col)
	col.add_child(_build_road())
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	col.add_child(row)
	row.add_child(_build_goals())
	row.add_child(_build_mastery())


func refresh() -> void:
	if _road == null:
		return
	# Rebuilding every card takes a few frames' worth of time: only when the
	# profile (or the day, which rotates contracts) changed since last time.
	var state := hash([Profile.data, Time.get_date_string_from_system()])
	if state == _state:
		UiFx.stagger_in(_mastery.get_children())
		_show_next_level.call_deferred()
		return
	_state = state
	_fill_header()
	_clear(_level_slot)
	_level_slot.add_child(CareerCards.level_block())
	_fill_road()
	_fill_goals()
	_fill_mastery()
	UiFx.stagger_in(_mastery.get_children())
	_show_next_level.call_deferred()


func first_focus() -> Control:
	return _next_card


# --- layout ---------------------------------------------------------------------

## The level block and the road of level rewards on one signboard.
func _build_road() -> Control:
	var board := UiKit.signboard()
	board.set_padding(30, 24)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	board.add_child(row)
	_level_slot = MarginContainer.new()
	_level_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_level_slot)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", UiKit.GAP_XS)
	row.add_child(col)
	col.add_child(UiKit.section("LEVEL ROAD", "Every level pays Sparks and gives one thing"))
	_road_scroll = ScrollContainer.new()
	_road_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_road_scroll.follow_focus = true
	_road_scroll.custom_minimum_size.y = CareerCards.ROAD_CARD.y + 44
	col.add_child(_road_scroll)
	var pad := MarginContainer.new()
	for side in ["left", "top", "right"]:
		pad.add_theme_constant_override("margin_" + side, 14)
	pad.add_theme_constant_override("margin_bottom", 10)
	_road_scroll.add_child(pad)
	_road = HBoxContainer.new()
	_road.add_theme_constant_override("separation", 0)
	pad.add_child(_road)
	_road_detail = _detail_line()
	col.add_child(_road_detail)
	return board


## Contracts and milestones.
func _build_goals() -> Control:
	var board := UiKit.signboard()
	board.custom_minimum_size.x = 760
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	board.add_child(col)
	var contracts_head := UiKit.section("CONTRACTS", " ")
	_goal_note = contracts_head.get_child(2) as Label
	col.add_child(contracts_head)
	_contracts = MarginContainer.new()
	col.add_child(_contracts)
	var milestones_head := UiKit.section("MILESTONES", " ", UiKit.AMBER)
	_milestone_note = milestones_head.get_child(2) as Label
	col.add_child(milestones_head)
	_milestones = HBoxContainer.new()
	_milestones.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(_milestones)
	col.add_child(UiKit.filler())
	_goal_detail = _detail_line()
	_goal_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_goal_detail.max_lines_visible = 2
	_goal_detail.custom_minimum_size.y = 56
	col.add_child(_goal_detail)
	return board


func _build_mastery() -> Control:
	var tray := UiKit.metal_frame(34)
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	tray.add_child(col)
	col.add_child(UiKit.section("WEAPON MASTERY", "Ten ranks per weapon, a reward at each"))
	_mastery = GridContainer.new()
	_mastery.columns = MASTERY_COLUMNS
	_mastery.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mastery.add_theme_constant_override("h_separation", UiKit.GAP_S)
	_mastery.add_theme_constant_override("v_separation", UiKit.GAP_S)
	col.add_child(_mastery)
	_mastery_detail = _detail_line()
	col.add_child(_mastery_detail)
	return tray


## The line under a section that explains the focused tile.
func _detail_line() -> Label:
	var l := UiKit.label("", UiKit.SIZE_SMALL, UiKit.CREAM)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	return l


# --- content --------------------------------------------------------------------

## Lifetime numbers, right of the marquee.
func _fill_header() -> void:
	_clear(_header)
	var clears := 0
	for key in Profile.data["levels"]:
		clears += int(Profile.data["levels"][key].get("clears", 0))
	_header.add_child(CareerCards.stat_tile("ZOMBIES POPPED", Wallet.format(Mastery.total_kills())))
	_header.add_child(CareerCards.stat_tile("LEVEL CLEARS", Wallet.format(clears)))
	_header.add_child(CareerCards.stat_tile("RUNS", Wallet.format(int(Profile.section("progression").get("runs_played", 0)))))
	_header.add_child(CareerCards.stat_tile("CONTRACTS", Wallet.format(ContractBoard.completed_count())))
	_header.add_child(CareerCards.stat_tile("SPARKS EARNED", Wallet.format(Wallet.lifetime_earned()), Wallet.COLOR))


func _fill_road() -> void:
	_clear(_road)
	_next_card = null
	var current := Progression.level()
	for lvl in range(2, Progression.MAX_LEVEL + 1):
		if lvl > 2:
			_road.add_child(CareerCards.road_link(lvl <= current + 1))
		var card := CareerCards.road_card(lvl, current, _thumbs)
		card.focus_entered.connect(_show_road_detail.bind(card))
		card.mouse_entered.connect(_show_road_detail.bind(card))
		card.pressed.connect(_open_reward.bind(card))
		_road.add_child(card)
		if lvl == mini(current + 1, Progression.MAX_LEVEL):
			_next_card = card
	if _next_card:
		_show_road_detail(_next_card)


func _fill_goals() -> void:
	_clear(_contracts)
	var row := CareerCards.contracts_row()
	_contracts.add_child(row)
	for tile: CareerTile in row.get_children():
		tile.highlighted.connect(_show_goal_detail)
	_goal_note.text = "Three at a time  ·  %d completed" % ContractBoard.completed_count()
	_clear(_milestones)
	var reached := 0
	var milestones := ChallengeBook.of_scope(Challenge.Scope.ACCOUNT)
	for ch in milestones:
		var tile := CareerCards.milestone_tile(ch)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.highlighted.connect(_show_goal_detail)
		_milestones.add_child(tile)
		if ChallengeBook.is_complete(ch):
			reached += 1
	_milestone_note.text = "%d of %d reached" % [reached, milestones.size()]
	if row.get_child_count() > 0:
		_show_goal_detail(row.get_child(0) as CareerTile)


func _fill_mastery() -> void:
	_clear(_mastery)
	for w in GameData.weapons():
		var tile := CareerCards.mastery_card(w)
		tile.highlighted.connect(_show_mastery_detail)
		tile.pressed.connect(_open_weapon.bind(w.id))
		_mastery.add_child(tile)
	if _mastery.get_child_count() > 0:
		_show_mastery_detail(_mastery.get_child(0) as CareerTile)


## Scrolls the road so the next level sits near its left end.
func _show_next_level() -> void:
	if _next_card == null:
		return
	var step := CareerCards.ROAD_CARD.x + 20.0
	_road_scroll.scroll_horizontal = int(maxf(0.0, _next_card.position.x - step * ROAD_LEAD))


# --- behaviour ------------------------------------------------------------------

func _show_road_detail(card: Control) -> void:
	_road_detail.text = String(card.get_meta(&"detail", ""))


func _show_goal_detail(tile: CareerTile) -> void:
	_goal_detail.text = tile.detail


func _show_mastery_detail(tile: CareerTile) -> void:
	_mastery_detail.text = tile.detail


## Enter on a cosmetic reward of the road shows it in the Locker.
func _open_reward(card: Control) -> void:
	var locker_card := card as LockerCard
	if locker_card == null or locker_card.item == null:
		return
	open_page.emit(&"locker")
	var locker := _locker()
	if locker:
		locker.select_item(locker_card.item.id)


## Enter on a weapon shows its skins in the Locker.
func _open_weapon(weapon_id: StringName) -> void:
	open_page.emit(&"locker")
	var locker := _locker()
	if locker:
		locker.select_weapon(weapon_id)
		locker.show_category(&"weapon_finish")


func _locker() -> LockerPage:
	var menu := get_tree().current_scene
	return menu.page("locker") as LockerPage if menu.has_method("page") else null


static func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
