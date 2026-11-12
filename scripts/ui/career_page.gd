class_name CareerPage
extends MenuPage
## Career: account level and progress, the next rewards on the level track,
## weapon mastery for every weapon (tier badge, rank, XP, kills, reward strip)
## and challenges with progress bars. Weapon lists scroll, so any number of
## weapons fits. Registered by data/ui/career.tres.

const TRACK_LENGTH := 8

var _card_slot: MarginContainer
var _track_title: Label
var _track: HBoxContainer
var _tab_buttons := {}
var _content: VBoxContainer
var _scroll: ScrollContainer
var _tab := "mastery"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.94), UiKit.PINK, 26, 4, 26))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(1700, 0)
	panel.add_child(col)
	col.add_child(_header())
	_card_slot = MarginContainer.new()
	col.add_child(_card_slot)
	_track_title = UiKit.label("", 28, UiKit.AMBER, true)
	col.add_child(_track_title)
	_track = HBoxContainer.new()
	_track.add_theme_constant_override("separation", 10)
	col.add_child(_track)
	col.add_child(_tabs())
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 380)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_style_scrollbar(_scroll.get_v_scroll_bar())
	col.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 22)
	_scroll.add_child(margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	margin.add_child(_content)
	refresh()


func refresh() -> void:
	if _content == null:
		return
	_clear(_card_slot)
	_card_slot.add_child(CareerCards.player_card())
	_build_track()
	_select_tab(_tab)


func _header() -> Control:
	var head := HBoxContainer.new()
	var title := UiKit.label("CAREER", 64, UiKit.AMBER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back_button := UiKit.soft_button("BACK", 30)
	back_button.pressed.connect(func(): back.emit())
	head.add_child(back_button)
	return head


func _tabs() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var group := ButtonGroup.new()
	for entry in [["mastery", "WEAPON MASTERY"], ["challenges", "CHALLENGES"]]:
		var b := UiKit.soft_button(entry[1], 28)
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(320, 0)
		var on := UiKit.box(UiKit.PINK, UiKit.PINK_DARK, 18, 0, 10)
		on.border_width_bottom = 6
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.pressed.connect(_on_tab_pressed.bind(entry[0]))
		row.add_child(b)
		_tab_buttons[entry[0]] = b
		if entry[0] == "mastery":
			b.name = "FirstFocus"
	var hint := UiKit.label("Mastery rewards unlock per weapon. Click an unlocked one to equip it.", 20, Color(1, 1, 1, 0.6))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)
	return row


func _build_track() -> void:
	_clear(_track)
	var lvl := Progression.level()
	var first := mini(lvl + 1, Progression.MAX_LEVEL - TRACK_LENGTH + 1)
	_track_title.text = "REWARD TRACK  ·  EVERY LEVEL UNLOCKS SOMETHING" if lvl < Progression.MAX_LEVEL else "REWARD TRACK  ·  MAX LEVEL, EVERYTHING UNLOCKED"
	for l in range(first, first + TRACK_LENGTH):
		_track.add_child(CareerCards.track_card(l, lvl))


func _on_tab_pressed(tab: String) -> void:
	_select_tab(tab)
	_scroll.scroll_vertical = 0


func _select_tab(tab: String) -> void:
	_tab = tab
	(_tab_buttons[tab] as Button).set_pressed_no_signal(true)
	_clear(_content)
	if tab == "mastery":
		_build_mastery()
	else:
		_build_challenges()


func _build_mastery() -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	for w in GameData.weapons():
		grid.add_child(CareerCards.weapon_card(w, _select_tab.bind("mastery")))


func _build_challenges() -> void:
	var done := ChallengeBook.completion()
	_content.add_child(_section("ACCOUNT CHALLENGES", "%d / %d complete overall" % [done.x, done.y]))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)
	for ch in ChallengeBook.of_scope(Challenge.Scope.ACCOUNT):
		grid.add_child(CareerCards.challenge_tile(ch, &""))
	var weapon_challenges := ChallengeBook.of_scope(Challenge.Scope.WEAPON)
	if weapon_challenges.is_empty():
		return
	_content.add_child(_section("WEAPON CHALLENGES", "Every weapon has its own set; rewards include mastery XP"))
	for w in GameData.weapons():
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		head.add_child(TierBadge.new(Mastery.rank(w.id), 40.0))
		var name := UiKit.label(w.display_name.to_upper(), 28, Color.WHITE, true)
		name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(name)
		_content.add_child(head)
		var row := GridContainer.new()
		row.columns = mini(weapon_challenges.size(), 5)
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_constant_override("v_separation", 10)
		_content.add_child(row)
		for ch in weapon_challenges:
			row.add_child(CareerCards.challenge_tile(ch, w.id, true))


func _section(title: String, note: String) -> Control:
	var row := HBoxContainer.new()
	var t := UiKit.label(title, 30, UiKit.CYAN, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var n := UiKit.label(note, 20, Color(1, 1, 1, 0.65))
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(n)
	return row


static func _style_scrollbar(bar: ScrollBar) -> void:
	bar.custom_minimum_size = Vector2(14, 0)
	bar.add_theme_stylebox_override("scroll", UiKit.box(Color(UiKit.INK, 0.8), Color.TRANSPARENT, 7, 0, 0))
	bar.add_theme_stylebox_override("grabber", UiKit.box(UiKit.PINK, Color.TRANSPARENT, 7, 0, 0))
	bar.add_theme_stylebox_override("grabber_highlight", UiKit.box(UiKit.PINK_LIGHT, Color.TRANSPARENT, 7, 0, 0))
	bar.add_theme_stylebox_override("grabber_pressed", UiKit.box(UiKit.CYAN, Color.TRANSPARENT, 7, 0, 0))


static func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
