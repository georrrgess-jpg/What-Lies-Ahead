class_name MenuHome
extends MenuPage
## The home screen: the neon logo over the live world; the next goal on a
## plate (the world's key art, stars, best wave) over one big PLAY call to
## action; the trailer and tutorial when they exist; small cards for what is
## new or close (next level reward, Locker, capsules to open); a rotating tip;
## and on the right the operator, today's featured Shop pick and the player
## card.

## PLAY was pressed: open the Play page on this world.
signal play_requested(world_index: int)

const TIPS := [
	"Right mouse aims down sights: tighter spread and more zoom.",
	"Headshots score half again. Chain kills inside 3 seconds to build the combo.",
	"Sprint, then press C to slide. Jump out of a slide to keep the speed.",
	"Between waves, spend tickets at the Loadout Station on boosts, or swap weapons for free.",
	"Zombies flank. Keep moving and use both lanes around the station.",
	"A flawless wave doubles the wave-clear bonus.",
	"Every zombie carries a stolen Spark. Pop it, bank it, spend it in the shop.",
]

## Size of the goal's key art.
const GOAL_ART := Vector2(208, 117)
const NEWS_CARD := Vector2(336, 104)
## Accent of the Prizes page's hook.
const PRIZES_ACCENT := Color(0.62, 0.55, 1.0)

## Page ids the shell has (news cards only link to pages that exist).
var known_pages: Array[String] = []
var _logo: NeonLogo
var _goal_panel: KitPanel
var _goal_art: TextureRect
var _goal_caption: KitChip
var _goal_world_label: Label
var _goal: Label
var _goal_stars: HBoxContainer
var _goal_note: Label
## Today's featured Shop pick, on the right over the player card.
var _today: Button
var _today_holder: CenterContainer
var _today_caption: Label
var _today_name: Label
var _today_price: HBoxContainer
var _play: SignButton
var _extras: HBoxContainer
var _news: HBoxContainer
var _tip: Label
var _tip_index := 0
var _goal_world := 0
var _entrance: Array[Control] = []
## Seconds without input while this page has focus (attract mode).
var _idle := 0.0
var _attract: CinePlayer


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
	set_process(Showreel.available() and DisplayServer.get_name() != "headless")


## Attract mode: after Showreel.attract_delay() seconds on the home page with
## no input, the trailer plays and hands focus back to PLAY when it ends.
func _process(delta: float) -> void:
	if is_instance_valid(_attract) or not is_visible_in_tree():
		_idle = 0.0
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or not is_ancestor_of(focus):
		_idle = 0.0
		return
	_idle += delta
	if _idle >= Showreel.attract_delay():
		_idle = 0.0
		_attract = Showreel.play(get_tree().current_scene, func(): if is_instance_valid(_play): _play.grab_focus())


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton \
			or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0):
		_idle = 0.0


func refresh() -> void:
	_refresh_goal()
	_refresh_news()
	_refresh_today()


func first_focus() -> Control:
	return _play


## After the intro: the logo's letters drop in and the rest deals in after it.
func animate_in() -> void:
	_logo.appear(0.0, 0.04)
	UiFx.stagger_in(_entrance + _news.get_children() + [_today], 0.3, 0.06)


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
	var goal_row := _build_goal()
	col.add_child(goal_row)
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


## The next goal on a dark plate so it reads over the live world: the
## world's key art, CONTINUE / START HERE, its name, stars and best wave.
func _build_goal() -> Control:
	_goal_panel = UiKit.neon_panel(UiKit.PINK, 12)
	_goal_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	_goal_panel.add_child(row)
	_goal_art = TextureRect.new()
	_goal_art.custom_minimum_size = GOAL_ART
	_goal_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_goal_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_goal_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(KeyArt.CARD_SHADER)
	m.set_shader_parameter("rect_size", GOAL_ART)
	m.set_shader_parameter("radius", 12.0)
	m.set_shader_parameter("shade_amount", 0.0)
	_goal_art.material = m
	row.add_child(_goal_art)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiKit.GAP_M)
	col.add_child(top)
	_goal_caption = UiKit.chip("CONTINUE", UiKit.PINK, 22)
	top.add_child(_goal_caption)
	_goal_world_label = UiKit.label("", 22, UiKit.MUTED, true)
	_goal_world_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_goal_world_label)
	_goal = UiKit.sign_label("", 44)
	col.add_child(_goal)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(foot)
	_goal_stars = WorldCard.star_row(0, 28.0)
	foot.add_child(_goal_stars)
	_goal_note = UiKit.label("", 22, UiKit.CREAM)
	_goal_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_goal_note)
	return _goal_panel


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
	_today = _build_today()
	_today.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(_today)
	var card := PlayerCard.build(true)
	card.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(card)


## Today's featured Shop pick: its picture, the discount, name and price.
func _build_today() -> Button:
	var b := _card_button(Vector2(PlayerCard.COMPACT_SIZE.x, 112), "shop")
	var row := b.get_child(0) as HBoxContainer
	_today_holder = CenterContainer.new()
	_today_holder.custom_minimum_size = Vector2(84, 84)
	_today_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_today_holder)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_today_caption = UiKit.label("", 20, Wallet.COLOR, true)
	col.add_child(_today_caption)
	_today_name = UiKit.sign_label("", 32)
	_today_name.clip_text = true
	col.add_child(_today_name)
	_today_price = HBoxContainer.new()
	_today_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_today_price)
	_today_price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


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
	var level: LevelData = world.levels[0] if not world.levels.is_empty() else null
	_goal_caption.set_text(caption)
	_goal_caption.set_color(world.accent_color)
	_goal_panel.accent = world.accent_color
	_goal_world_label.text = "WORLD %d  ·  %s" % [_goal_world + 1, world.display_name.to_upper()]
	_goal.text = (level.display_name if level else world.display_name).to_upper()
	KeyArt.request(level, _show_goal_art)
	var count := WorldCard.world_stars(world)
	for i in _goal_stars.get_child_count():
		(_goal_stars.get_child(i) as TextureRect).texture = KitTex.tex(&"icon_star" if i < count else &"icon_star_empty")
	_goal_note.text = _goal_progress(level)


func _show_goal_art(art: Texture2D) -> void:
	_goal_art.texture = art
	_goal_art.visible = art != null


## "Best wave 3 / 8", "Cleared  ·  best 48,210" or "Not played yet".
static func _goal_progress(level: LevelData) -> String:
	if level == null:
		return ""
	var waves := level.wave_set.waves.size() if level.wave_set else 0
	if Profile.is_level_completed(level.id):
		return "Cleared  ·  best %s" % ScorePanel._fmt(Profile.best_score(level.id))
	if Profile.best_wave(level.id) > 0:
		return "Best wave %d / %d" % [mini(Profile.best_wave(level.id), waves), waves]
	return "Not played yet  ·  %d waves" % waves


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
	if "prizes" in known_pages and PrizePrints.capsules() > 0:
		var n := PrizePrints.capsules()
		var prizes := _news_card(null, "PRIZES  ·  %d CAPSULE%s" % [n, "" if n == 1 else "S"], "Open %s for a one-of-a-kind print" % ("it" if n == 1 else "them"), PRIZES_ACCENT, "prizes")
		prizes.find_child("Icon", true, false).add_child(_capsule_icon())
		_news.add_child(prizes)
	elif "shop" in known_pages:
		_news.add_child(_news_card(&"icon_spark", "SHOP", "%s %s to spend" % [Wallet.format(Wallet.balance()), Wallet.CURRENCY], Wallet.COLOR, "shop"))
	elif "arsenal" in known_pages:
		var open := 0
		for w in GameData.weapons():
			if GameData.is_weapon_unlocked(w):
				open += 1
		_news.add_child(_news_card(&"icon_check", "ARSENAL", "%d of %d weapons unlocked" % [open, GameData.weapons().size()], UiKit.CYAN, "arsenal"))


## Today's featured pick: the first one with a picture ready (a baked
## thumbnail from the Shop or a drawn icon), else the first one.
func _refresh_today() -> void:
	var picks := ShopCatalog.featured() if "shop" in known_pages else ([] as Array[CosmeticItem])
	_today.visible = not picks.is_empty()
	if picks.is_empty():
		return
	var pick: CosmeticItem = picks[0]
	var art: Control = null
	for it in picks:
		art = _pick_art(it)
		if art:
			pick = it
			break
	for c in _today_holder.get_children():
		_today_holder.remove_child(c)
		c.queue_free()
	if art == null:
		art = UiKit.icon(&"icon_spark", 64.0)
	_today_holder.add_child(art)
	_today_caption.text = "TODAY'S PICK  ·  %d%% OFF  ·  %s" % [roundi(ShopCatalog.discount(pick) * 100.0), LockerCatalog.category_label(pick).to_upper()]
	_today_name.text = pick.display_name.to_upper()
	for c in _today_price.get_children():
		_today_price.remove_child(c)
		c.queue_free()
	var owned := not Cosmetics.is_for_sale(pick)
	if owned:
		_today_price.add_child(UiKit.chip("OWNED", UiKit.GREEN, 20, false))
	else:
		var price := ShopCatalog.price(pick)
		_today_price.add_child(UiKit.price_tag(price, UiKit.SIZE_LABEL, Wallet.can_afford(price)))


## A picture of `it` that costs nothing to show, or null.
func _pick_art(it: CosmeticItem) -> Control:
	var thumb := CosmeticThumbs.cached(it, GameData.weapon(ShopCatalog.buy_context(it)))
	if thumb:
		var rect := TextureRect.new()
		rect.texture = thumb
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(84, 84)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rect
	if it.slot in [&"weapon_cell", &"kill_effect", &"tracer"]:
		var icon := CosmeticIcon.new(it)
		icon.custom_minimum_size = Vector2(84, 84)
		return icon
	return null


## A prize capsule: a violet dome over a cream base, with a shine.
static func _capsule_icon() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(52, 52)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var mid := Vector2(26, 26)
		c.draw_circle(mid, 22.0, UiKit.INK, true, -1.0, true)
		c.draw_arc(mid, 10.0, PI, TAU, 16, PRIZES_ACCENT, 20.0, true)
		c.draw_arc(mid, 10.0, 0.0, PI, 16, UiKit.CREAM, 20.0, true)
		c.draw_line(Vector2(5, 26), Vector2(47, 26), UiKit.INK, 3.0, true)
		c.draw_circle(mid + Vector2(-8, -9), 4.0, Color(1, 1, 1, 0.75), true, -1.0, true))
	return c


func _pinned_badge(level: int) -> LevelBadge:
	var badge := UiKit.level_badge(56.0)
	badge.set_level(level)
	return badge


## A card-styled button of `card_size` that opens `page_id`, with an empty
## row (its first child) to fill. It grows a little on hover and focus.
func _card_button(card_size: Vector2, page_id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = card_size
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", KitTex.box(&"card"))
	b.add_theme_stylebox_override("hover", KitTex.box(&"card_hover"))
	b.add_theme_stylebox_override("pressed", KitTex.box(&"card_hover"))
	b.add_theme_stylebox_override("focus", KitTex.box(&"focus_ring"))
	b.mouse_entered.connect(func():
		UiSound.hover()
		UiFx.hover(b, true, 1.03))
	b.mouse_exited.connect(func(): if not b.has_focus(): UiFx.hover(b, false))
	b.focus_entered.connect(func(): UiFx.hover(b, true, 1.03))
	b.focus_exited.connect(func(): UiFx.hover(b, false))
	b.pressed.connect(func():
		UiSound.click()
		UiFx.squash(b, b.scale.x)
		open_page.emit(StringName(page_id)))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	return b


## A small card that opens a page: an icon, a caption in `accent` and a line of text.
func _news_card(icon_name: Variant, caption: String, text: String, accent: Color, page_id: String) -> Button:
	var b := _card_button(NEWS_CARD, page_id)
	var row := b.get_child(0) as HBoxContainer
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
	var head := UiKit.label(caption, 20, accent, true)
	head.clip_text = true
	col.add_child(head)
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
