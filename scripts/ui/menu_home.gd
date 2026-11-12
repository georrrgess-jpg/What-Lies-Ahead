class_name MenuHome
extends MenuPage
## The home screen: the neon logo over the live world, the player's operator
## and card, one big PLAY call to action that names the next goal, the
## trailer and tutorial when they exist, small cards for what is new or
## close, and a rotating tip.

## PLAY was pressed: open the Play page on this world.
signal play_requested(world_index: int)

const TIPS := [
	"Right mouse aims down sights: tighter spread and more zoom.",
	"Headshots multiply your score. Chain kills inside 3 seconds for a combo.",
	"Sprint, then press C to slide. Jump out of a slide to keep the speed.",
	"Between waves, the Loadout Station sells energy and snacks and swaps weapons.",
	"Zombies flank. Keep moving and use both lanes around the station.",
	"A flawless wave doubles the wave-clear bonus.",
	"Every zombie carries a stolen Spark. Pop it, bank it, spend it in the shop.",
]

## Page ids the shell has (news cards only link to pages that exist).
var known_pages: Array[String] = []
var _logo: NeonLogo
var _goal_caption: KitChip
var _goal: Label
var _play: SignButton
var _extras: HBoxContainer
var _news: HBoxContainer
var _tip: Label
var _tip_index := 0
var _goal_world := 0
var _entrance: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_left()
	_build_right()
	_tip_index = randi() % TIPS.size()
	_rotate_tip()
	var timer := Timer.new()
	timer.wait_time = 7.0
	timer.autostart = true
	timer.timeout.connect(_rotate_tip)
	add_child(timer)


func refresh() -> void:
	_refresh_goal()
	_refresh_news()


func first_focus() -> Control:
	return _play


## After the intro: the logo's letters drop in and the rest deals in after it.
func animate_in() -> void:
	_logo.appear(0.0, 0.04)
	UiFx.stagger_in(_entrance + _news.get_children(), 0.3, 0.06)


# --- layout -------------------------------------------------------------------------

func _build_left() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 96
	col.offset_top = 34
	col.offset_bottom = -UiKit.GAP_L
	col.custom_minimum_size.x = 1040
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_logo = NeonLogo.new()
	_logo.size_px = 122
	col.add_child(_logo)
	col.add_child(UiKit.filler())
	var goal_row := HBoxContainer.new()
	goal_row.add_theme_constant_override("separation", UiKit.GAP_M)
	goal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(goal_row)
	_goal_caption = UiKit.chip("CONTINUE", UiKit.PINK, 24)
	goal_row.add_child(_goal_caption)
	_goal = UiKit.sign_label("", 38)
	goal_row.add_child(_goal)
	var cta := HBoxContainer.new()
	cta.add_theme_constant_override("separation", UiKit.GAP_L)
	cta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cta)
	_play = UiKit.sign_button("PLAY", SignButton.Kind.PRIMARY, 84)
	_play.custom_minimum_size = Vector2(520, 138)
	_play.pressed.connect(func(): play_requested.emit(_goal_world))
	cta.add_child(_play)
	_extras = HBoxContainer.new()
	_extras.add_theme_constant_override("separation", UiKit.GAP_M)
	_extras.size_flags_vertical = Control.SIZE_SHRINK_END
	cta.add_child(_extras)
	_build_extras()
	col.add_child(UiKit.spacer(UiKit.GAP_S))
	_news = HBoxContainer.new()
	_news.add_theme_constant_override("separation", UiKit.GAP_M)
	col.add_child(_news)
	var ticker := UiKit.card_panel(10)
	ticker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ticker.custom_minimum_size.x = 1040
	col.add_child(ticker)
	_tip = UiKit.label("", 22, UiKit.CREAM)
	_tip.clip_text = true
	ticker.add_child(_tip)
	_entrance = [goal_row, cta, ticker]


## WATCH TRAILER and TUTORIAL, when the game has them.
func _build_extras() -> void:
	if Showreel.available():
		var trailer := UiKit.sign_button("WATCH TRAILER", SignButton.Kind.SECONDARY, 28)
		trailer.icon = KitTex.tex(&"icon_film")
		trailer.add_theme_constant_override("icon_max_width", 34)
		trailer.pressed.connect(func(): Showreel.play(get_tree().current_scene, func(): trailer.grab_focus()))
		_extras.add_child(trailer)
	if Onboarding.has_tutorial():
		var tutorial := UiKit.sign_button("TUTORIAL", SignButton.Kind.NEUTRAL, 28)
		tutorial.icon = KitTex.tex(&"icon_tutorial")
		tutorial.add_theme_constant_override("icon_max_width", 34)
		tutorial.pressed.connect(Onboarding.start_tutorial)
		_extras.add_child(tutorial)


## The operator and the player card on the right.
func _build_right() -> void:
	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -640
	right.offset_right = -64
	right.offset_top = 10
	right.offset_bottom = -UiKit.GAP_L
	right.add_theme_constant_override("separation", UiKit.GAP_S)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	var op := OperatorPreview.new()
	op.custom_minimum_size = Vector2(520, 520)
	op.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(op)
	var card := PlayerCard.build(true)
	card.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(card)


# --- content ------------------------------------------------------------------------

## The next thing to do: the first open world that is not cleared yet.
func _refresh_goal() -> void:
	var worlds := GameData.worlds()
	if worlds.is_empty():
		return
	var any_cleared := false
	_goal_world = -1
	for i in worlds.size():
		var cleared := true
		for l in worlds[i].levels:
			cleared = cleared and Profile.is_level_completed(l.id)
		any_cleared = any_cleared or cleared
		if _goal_world < 0 and not cleared and GameData.is_world_unlocked(worlds[i]):
			_goal_world = i
	var caption := "CONTINUE" if any_cleared else "START HERE"
	if _goal_world < 0:
		# Everything open is cleared: back to the world played last.
		_goal_world = clampi(int(Profile.section("menu").get("world", 0)), 0, worlds.size() - 1)
		caption = "PLAY AGAIN"
	var world := worlds[_goal_world]
	var level_name := world.levels[0].display_name if not world.levels.is_empty() else world.display_name
	_goal_caption.set_text(caption)
	_goal_caption.set_color(world.accent_color)
	_goal.text = "WORLD %d  —  %s" % [_goal_world + 1, level_name.to_upper()]


func _refresh_news() -> void:
	for c in _news.get_children():
		_news.remove_child(c)
		c.queue_free()
	if "career" in known_pages and Progression.level() < Progression.MAX_LEVEL:
		var next := Progression.level() + 1
		var card := _news_card(null, "LEVEL %d  ·  %s XP TO GO" % [next, Wallet.format(Progression.xp_to_next())], Progression.reward_text(next), UiKit.AMBER, "career")
		card.find_child("Icon", true, false).add_child(_pinned_badge(next))
		_news.add_child(card)
	if "locker" in known_pages:
		var fresh := Cosmetics.new_count()
		var text := "%d new item%s to try on" % [fresh, "" if fresh == 1 else "s"] if fresh > 0 else "Operators, skins, sights and more"
		_news.add_child(_news_card(&"icon_star", "LOCKER" + ("  ·  NEW" if fresh > 0 else ""), text, UiKit.PINK, "locker"))
	if "shop" in known_pages:
		_news.add_child(_news_card(&"icon_spark", "SHOP", "%s %s to spend" % [Wallet.format(Wallet.balance()), Wallet.CURRENCY], Wallet.COLOR, "shop"))
	elif "arsenal" in known_pages:
		var open := 0
		for w in GameData.weapons():
			if GameData.is_weapon_unlocked(w):
				open += 1
		_news.add_child(_news_card(&"icon_check", "ARSENAL", "%d of %d weapons unlocked" % [open, GameData.weapons().size()], UiKit.CYAN, "arsenal"))


func _pinned_badge(level: int) -> LevelBadge:
	var badge := UiKit.level_badge(56.0)
	badge.set_level(level)
	return badge


## A small card that opens a page: an icon, a caption in `accent` and a line of text.
func _news_card(icon_name: Variant, caption: String, text: String, accent: Color, page_id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(336, 104)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", KitTex.box(&"card"))
	b.add_theme_stylebox_override("hover", KitTex.box(&"card_hover"))
	b.add_theme_stylebox_override("pressed", KitTex.box(&"card_hover"))
	b.add_theme_stylebox_override("focus", KitTex.box(&"focus_ring"))
	b.mouse_entered.connect(UiSound.hover)
	b.pressed.connect(func():
		UiSound.click()
		open_page.emit(StringName(page_id)))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var holder := CenterContainer.new()
	holder.name = "Icon"
	holder.custom_minimum_size = Vector2(56, 56)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(holder)
	if icon_name != null:
		holder.add_child(UiKit.icon(icon_name, 52.0))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	col.add_child(UiKit.label(caption, 20, accent, true))
	var line := UiKit.label(text, 22, UiKit.CREAM)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.max_lines_visible = 2
	line.add_theme_constant_override("line_spacing", -6)
	col.add_child(line)
	return b


func _rotate_tip() -> void:
	_tip_index = (_tip_index + 1) % TIPS.size()
	_tip.text = "TIP  ·  " + TIPS[_tip_index]
	if is_visible_in_tree():
		UiFx.fade_in(_tip, 0.4)
