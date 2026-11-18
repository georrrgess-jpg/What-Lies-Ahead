class_name MenuHome
extends MenuPage
## The home screen, laid out for one obvious action:
##   left, top to bottom: the neon logo;
##   the hero (MenuHero): the world PLAY opens, its key art large, with a
##   pager through the open worlds; the big pink PLAY with the ENDLESS tile
##   beside it as the strong second; two news cards (the next level reward
##   or the closest contract, and today's featured Shop pick); a rotating tip.
##   right: the trailer and tutorial, the operator, the player card, and the section tiles (Arsenal,
##   Locker, Shop, Prizes, Career, Settings), each saying what waits there.
## The live world behind the menu follows the hero's world.

## PLAY was pressed: open the Play page on this world.
signal play_requested(world_index: int)
## The ENDLESS tile was pressed: open the Play page in Endless mode.
signal endless_requested
## The hero shows this level: the shell puts its world behind the menu.
signal world_shown(level: LevelData)

const TIPS := [
	"Right mouse aims down sights: tighter spread and more zoom.",
	"Headshots score half again. Chain kills inside 3 seconds to build the combo.",
	"Sprint, then press C to slide. Jump out of a slide to keep the speed.",
	"Between waves, spend tickets at the Loadout Station on boosts, or swap weapons for free.",
	"Zombies flank. Keep moving and use both lanes around the station.",
	"A flawless wave doubles the wave-clear bonus.",
	"Every zombie carries a stolen Spark. Pop it, bank it, spend it in the shop.",
]

## Width of the left column (the hero, PLAY row, news row).
const COLUMN_W := 860.0
## Width of the right column (the player card and the section tiles).
const SIDE_W := 560.0
const PLAY_SIZE := Vector2(540, 128)
const NEWS_CARD := Vector2(422, 104)
const ENDLESS_EMBLEM := 76.0
## Accent of the Prizes page.
const PRIZES_ACCENT := Color(0.62, 0.55, 1.0)
## Seconds between the glints of light across PLAY (the eye's resting place).
const GLINT_EVERY := 5.5
## The section tiles, in reading order: page id, name.
const SECTIONS := [
	["arsenal", "ARSENAL"], ["locker", "LOCKER"], ["shop", "SHOP"],
	["prizes", "PRIZES"], ["career", "CAREER"], ["settings", "SETTINGS"],
]

## Page ids the shell has (cards and tiles only link to pages that exist).
var known_pages: Array[String] = []
var _logo: NeonLogo
var _hero: MenuHero
var _endless: Button
var _endless_art: TextureRect
var _endless_chip: KitChip
var _endless_note: Label
var _today: Button
var _today_holder: CenterContainer
var _today_caption: Label
var _today_name: Label
var _today_price: HBoxContainer
var _play: SignButton
var _extras: HBoxContainer
var _news: HBoxContainer
var _tiles: GridContainer
var _tile: Dictionary = {}
var _tip: Label
var _tip_index := 0
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
	var glint := Timer.new()
	glint.wait_time = GLINT_EVERY
	glint.autostart = true
	glint.timeout.connect(_glint)
	add_child(glint)
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
	_hero.refresh()
	_on_world_changed(_hero.world_index, null)
	_refresh_endless()
	_refresh_news()
	_refresh_today()
	_refresh_tiles()


func first_focus() -> Control:
	return _play


## After the intro: the logo's letters drop in and the rest deals in after it.
func animate_in() -> void:
	_logo.appear(0.0, 0.04)
	UiFx.stagger_in(_entrance + _tiles.get_children(), 0.3, 0.05)


# --- layout -------------------------------------------------------------------------

func _build_left() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	col.offset_left = 96
	col.offset_top = 28
	col.offset_bottom = -UiKit.GAP_L
	col.custom_minimum_size.x = COLUMN_W
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	_logo = NeonLogo.new()
	_logo.size_px = 92
	col.add_child(_logo)
	col.add_child(UiKit.filler())
	_hero = MenuHero.create()
	_hero.world_changed.connect(_on_world_changed)
	col.add_child(_hero)
	var cta := HBoxContainer.new()
	cta.add_theme_constant_override("separation", UiKit.GAP_M)
	cta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cta)
	_play = UiKit.sign_button("PLAY", SignButton.Kind.PRIMARY, 84)
	_play.name = "PlayButton"
	_play.custom_minimum_size = PLAY_SIZE
	UiKit.tooltip(_play, "Pick your loadout and difficulty, then deploy")
	_play.pressed.connect(func(): play_requested.emit(_hero.world_index))
	cta.add_child(_play)
	if not GameData.endless_levels().is_empty():
		_endless = _build_endless()
		_endless.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cta.add_child(_endless)
	_news = HBoxContainer.new()
	_news.add_theme_constant_override("separation", UiKit.GAP_M)
	_news.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_news)
	_today = _build_today()
	_news.add_child(_today)
	var ticker := UiKit.card_panel(10)
	col.add_child(ticker)
	_tip = UiKit.label("", UiKit.SIZE_SMALL, UiKit.CREAM)
	_tip.clip_text = true
	_tip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ticker.add_child(_tip)
	_entrance = [_hero, cta, _news, ticker]


## TRAILER and TUTORIAL, small, over the operator, when the game has them.
func _build_extras() -> void:
	if Showreel.available():
		var trailer := UiKit.sign_button("TRAILER", SignButton.Kind.SECONDARY, 24)
		trailer.icon = KitTex.tex(&"icon_film")
		trailer.add_theme_constant_override("icon_max_width", 28)
		UiKit.tooltip(trailer, "Watch the trailer")
		trailer.pressed.connect(func(): Showreel.play(get_tree().current_scene, func(): trailer.grab_focus()))
		_extras.add_child(trailer)
	if Onboarding.has_tutorial():
		var tutorial := UiKit.sign_button("TUTORIAL", SignButton.Kind.NEUTRAL, 24)
		tutorial.icon = KitTex.tex(&"icon_tutorial")
		tutorial.add_theme_constant_override("icon_max_width", 28)
		tutorial.pressed.connect(Onboarding.start_tutorial)
		_extras.add_child(tutorial)


## The ENDLESS tile: the city's key art behind the emblem, a NEW MODE (or
## ENDLESS) chip, the mode's name and its record.
func _build_endless() -> Button:
	var b := Button.new()
	b.name = "EndlessTile"
	b.custom_minimum_size = Vector2(0, PLAY_SIZE.y)
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	b.add_theme_stylebox_override("normal", KitTex.box_copy(&"neon_plate", EndlessCard.EMBER))
	b.add_theme_stylebox_override("hover", KitTex.box_copy(&"neon_plate", EndlessCard.EMBER.lightened(0.35)))
	b.add_theme_stylebox_override("pressed", KitTex.box_copy(&"neon_plate", EndlessCard.EMBER.lightened(0.35)))
	b.add_theme_stylebox_override("focus", KitTex.box(&"focus_ring"))
	UiKit.tooltip(b, "Endless: survive waves without end in Ashfall City")
	_endless_art = TextureRect.new()
	_endless_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	_endless_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_endless_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_endless_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(KeyArt.CARD_SHADER)
	m.set_shader_parameter("radius", 10.0)
	m.set_shader_parameter("shade", Color(0.12, 0.04, 0.1))
	m.set_shader_parameter("shade_amount", 0.8)
	_endless_art.material = m
	_endless_art.resized.connect(func(): m.set_shader_parameter("rect_size", _endless_art.size))
	b.add_child(_endless_art)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	row.offset_left = 14
	row.add_theme_constant_override("separation", UiKit.GAP_S)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var emblem := EndlessEmblem.make(ENDLESS_EMBLEM)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(emblem)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_endless_chip = UiKit.chip("NEW MODE", UiKit.PINK, UiKit.SIZE_SMALL)
	_endless_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_endless_chip)
	var title := UiKit.arcade_label("ENDLESS", 46)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title)
	_endless_note = UiKit.label("", UiKit.SIZE_SMALL, UiKit.CREAM)
	_endless_note.clip_text = true
	_endless_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_endless_note.add_theme_color_override("font_outline_color", Color(UiKit.INK, 0.85))
	_endless_note.add_theme_constant_override("outline_size", 6)
	_endless_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_endless_note)
	_hover_fx(b)
	b.pressed.connect(func():
		UiSound.click()
		UiFx.squash(b, b.scale.x)
		endless_requested.emit())
	return b


## The operator, the player card and the section tiles on the right.
func _build_right() -> void:
	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -SIDE_W - 64
	right.offset_right = -64
	right.offset_top = UiKit.GAP_S
	right.offset_bottom = -UiKit.GAP_L
	right.add_theme_constant_override("separation", UiKit.GAP_M)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	_extras = HBoxContainer.new()
	_extras.add_theme_constant_override("separation", UiKit.GAP_M)
	_extras.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(_extras)
	_build_extras()
	var op := OperatorPreview.new()
	op.custom_minimum_size = Vector2(SIDE_W, 360)
	op.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(op)
	var card := PlayerCard.build(true)
	card.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(card)
	_tiles = GridContainer.new()
	_tiles.columns = 3
	_tiles.add_theme_constant_override("h_separation", UiKit.GAP_M)
	_tiles.add_theme_constant_override("v_separation", UiKit.GAP_M)
	_tiles.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(_tiles)


## The section tiles for the pages the shell has (built on the first refresh,
## once the shell has said which pages exist).
func _build_tiles() -> void:
	for entry in SECTIONS:
		var id: String = entry[0]
		if id not in known_pages:
			continue
		var tile := MenuNavTile.make(id, entry[1], _tile_icon(id))
		tile.custom_minimum_size.x = (SIDE_W - UiKit.GAP_M * 2) / 3.0
		tile.pressed.connect(func(): open_page.emit(StringName(id)))
		_tiles.add_child(tile)
		_tile[id] = tile


static func _tile_icon(id: String) -> Control:
	match id:
		"arsenal":
			return MenuNavTile.blaster_icon()
		"locker":
			return UiKit.icon(&"icon_star", MenuNavTile.ICON)
		"shop":
			return UiKit.icon(&"icon_spark", MenuNavTile.ICON)
		"prizes":
			return _capsule_icon(MenuNavTile.ICON)
		"career":
			return UiKit.level_badge(MenuNavTile.ICON + 4.0)
	return UiKit.icon(&"icon_gear", MenuNavTile.ICON)


## Today's featured Shop pick: its picture, the discount, name and price.
func _build_today() -> Button:
	var b := _card_button(NEWS_CARD, "shop")
	b.name = "TodaysPick"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := b.get_child(0) as HBoxContainer
	_today_holder = CenterContainer.new()
	_today_holder.custom_minimum_size = Vector2(76, 76)
	_today_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_today_holder)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_today_caption = UiKit.label("", UiKit.SIZE_SMALL, Wallet.COLOR, true)
	_today_caption.clip_text = true
	_today_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_today_caption)
	_today_name = UiKit.sign_label("", 28)
	_today_name.clip_text = true
	_today_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_today_name)
	_today_price = HBoxContainer.new()
	_today_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_today_price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(_today_price)
	return b


# --- content ------------------------------------------------------------------------

## The hero moved to another world: the live world behind follows it.
func _on_world_changed(_index: int, _level: LevelData) -> void:
	var world := GameData.worlds()[_hero.world_index] if _hero.world_index >= 0 else null
	if world and not world.levels.is_empty():
		world_shown.emit(world.levels[0])


## The ENDLESS tile's chip and line: NEW MODE and the pitch until the first
## run, then the best wave and score.
func _refresh_endless() -> void:
	if _endless == null:
		return
	KeyArt.request(GameData.endless_levels()[0], _show_endless_art)
	var fresh := MenuPlay.endless_is_new()
	_endless_chip.visible = fresh
	var best := EndlessRecords.best_wave()
	if best > 0:
		_endless_note.text = "Best wave %d  ·  %s" % [best, ScorePanel._fmt(EndlessRecords.best_score())]
	else:
		_endless_note.text = "Waves without end"


func _show_endless_art(art: Texture2D) -> void:
	_endless_art.texture = art


## "Best wave 3 / 8", "Cleared  ·  best 48,210" or "Not played yet  ·  7 waves".
static func goal_progress(level: LevelData) -> String:
	if level == null:
		return ""
	var waves := level.wave_set.waves.size() if level.wave_set else 0
	if Profile.is_level_completed(level.id):
		return "Cleared  ·  best %s" % ScorePanel._fmt(Profile.best_score(level.id))
	if Profile.best_wave(level.id) > 0:
		return "Best wave %d / %d" % [mini(Profile.best_wave(level.id), waves), waves]
	return "Not played yet  ·  %d waves" % waves


## The news row: the next level's reward (or, at the top level, the contract
## closest to done) and today's Shop pick.
func _refresh_news() -> void:
	for c in _news.get_children():
		if c != _today:
			_news.remove_child(c)
			c.queue_free()
	if "career" in known_pages:
		var goal := _career_card()
		if goal:
			_news.add_child(goal)
			_news.move_child(goal, 0)


func _career_card() -> Button:
	if Progression.level() < Progression.MAX_LEVEL:
		var next := Progression.level() + 1
		var card := _news_card(null, "LEVEL %d  ·  %s XP TO GO" % [next, Wallet.format(Progression.xp_to_next())], Progression.reward_text(next), UiKit.AMBER, "career")
		card.find_child("Icon", true, false).add_child(_pinned_badge(next))
		return card
	var best: Dictionary = {}
	for entry: Dictionary in ContractBoard.active():
		if not ContractBoard.is_done(entry) and (best.is_empty() or ContractBoard.fraction(entry) > ContractBoard.fraction(best)):
			best = entry
	if best.is_empty():
		return null
	return _news_card(&"icon_check", "CONTRACT  ·  %d / %d" % [ContractBoard.progress(best), ContractBoard.goal(best)], ContractBoard.describe(best), UiKit.CYAN, "career")


## Today's featured pick: the first one with a picture ready (a baked
## thumbnail from the Shop or a drawn icon), else the first one.
func _refresh_today() -> void:
	var picks := ShopCatalog.featured() if "shop" in known_pages else ([] as Array[CosmeticItem])
	_today.visible = not picks.is_empty()
	if picks.is_empty():
		return
	var pool := _today_pool(picks)
	var pick: CosmeticItem = pool[0]
	var art: Control = null
	for it in pool:
		art = _pick_art(it)
		if art:
			pick = it
			break
	for c in _today_holder.get_children():
		_today_holder.remove_child(c)
		c.queue_free()
	if art == null:
		art = UiKit.icon(&"icon_spark", 60.0)
	_today_holder.add_child(art)
	_today_caption.text = "TODAY'S PICK  ·  %d%% OFF  ·  %s" % [roundi(ShopCatalog.discount(pick) * 100.0), LockerCatalog.category_label(pick).to_upper()]
	_today_name.text = pick.display_name.to_upper()
	for c in _today_price.get_children():
		_today_price.remove_child(c)
		c.queue_free()
	if not Cosmetics.is_for_sale(pick):
		_today_price.add_child(UiKit.chip("OWNED", UiKit.GREEN, UiKit.SIZE_SMALL, false))
	else:
		var price := ShopCatalog.price(pick)
		_today_price.add_child(UiKit.price_tag(price, UiKit.SIZE_SMALL, Wallet.can_afford(price)))


## The picks worth showing first: the ones the player can buy now, else the
## ones still for sale (cheapest first), else all of them.
static func _today_pool(picks: Array[CosmeticItem]) -> Array[CosmeticItem]:
	var sale := picks.filter(func(it: CosmeticItem) -> bool: return Cosmetics.is_for_sale(it))
	var now := sale.filter(func(it: CosmeticItem) -> bool: return Wallet.can_afford(ShopCatalog.price(it)))
	var out: Array[CosmeticItem] = []
	if not now.is_empty():
		out.assign(now)
	elif not sale.is_empty():
		out.assign(sale)
		out.sort_custom(func(a: CosmeticItem, b: CosmeticItem) -> bool: return ShopCatalog.price(a) < ShopCatalog.price(b))
	else:
		out.assign(picks)
	return out


## A picture of `it` that costs nothing to show, or null.
func _pick_art(it: CosmeticItem) -> Control:
	var thumb := CosmeticThumbs.cached(it, GameData.weapon(ShopCatalog.buy_context(it)))
	if thumb:
		var rect := TextureRect.new()
		rect.texture = thumb
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(76, 76)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rect
	if it.slot in [&"weapon_cell", &"kill_effect", &"tracer"]:
		var icon := CosmeticIcon.new(it)
		icon.custom_minimum_size = Vector2(76, 76)
		return icon
	return null


## What waits in each section: a line and, for what is new, a count badge.
func _refresh_tiles() -> void:
	if _tiles.get_child_count() == 0:
		_build_tiles()
	if _tile.has("arsenal"):
		var open := GameData.weapons().filter(func(w): return GameData.is_weapon_unlocked(w)).size()
		(_tile["arsenal"] as MenuNavTile).set_note("%d / %d weapons" % [open, GameData.weapons().size()])
	if _tile.has("locker"):
		var fresh := Cosmetics.new_count()
		_set_tile("locker", "%d new to try on" % fresh if fresh > 0 else "Looks & operators", fresh)
	if _tile.has("shop"):
		var fresh_shop := ShopCatalog.new_count()
		_set_tile("shop", "%d new items" % fresh_shop if fresh_shop > 0 else "Daily deals", fresh_shop)
	if _tile.has("prizes"):
		var n := PrizePrints.capsules()
		_set_tile("prizes", "%d capsule%s to open" % [n, "" if n == 1 else "s"] if n > 0 else "Your prize prints", n)
	if _tile.has("career"):
		(_tile["career"] as MenuNavTile).set_note("Level · contracts")
	if _tile.has("settings"):
		(_tile["settings"] as MenuNavTile).set_note("Controls · audio")


func _set_tile(id: String, note: String, count: int) -> void:
	var tile := _tile[id] as MenuNavTile
	tile.set_note(note, count > 0)
	tile.set_badge(count)


## A prize capsule: a violet dome over a cream base, with a shine.
static func _capsule_icon(icon_size := 52.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(icon_size, icon_size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var k := icon_size / 52.0
		var mid := Vector2(26, 26) * k
		c.draw_circle(mid, 22.0 * k, UiKit.INK, true, -1.0, true)
		c.draw_arc(mid, 10.0 * k, PI, TAU, 16, PRIZES_ACCENT, 20.0 * k, true)
		c.draw_arc(mid, 10.0 * k, 0.0, PI, 16, UiKit.CREAM, 20.0 * k, true)
		c.draw_line(Vector2(5, 26) * k, Vector2(47, 26) * k, UiKit.INK, 3.0 * k, true)
		c.draw_circle(mid + Vector2(-8, -9) * k, 4.0 * k, Color(1, 1, 1, 0.75), true, -1.0, true))
	return c


func _pinned_badge(level: int) -> LevelBadge:
	var badge := UiKit.level_badge(56.0)
	badge.set_level(level)
	return badge


## Grows `b` a little on hover and focus, with the hover sound.
static func _hover_fx(b: Control) -> void:
	b.mouse_entered.connect(func():
		UiSound.hover()
		UiFx.hover(b, true, 1.03))
	b.mouse_exited.connect(func(): if not b.has_focus(): UiFx.hover(b, false))
	b.focus_entered.connect(func(): UiFx.hover(b, true, 1.03))
	b.focus_exited.connect(func(): UiFx.hover(b, false))
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)


## A card-styled button of `card_size` that opens `page_id`, with an empty
## row (its first child) to fill.
func _card_button(card_size: Vector2, page_id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = card_size
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", KitTex.box(&"card"))
	b.add_theme_stylebox_override("hover", KitTex.box(&"card_hover"))
	b.add_theme_stylebox_override("pressed", KitTex.box(&"card_hover"))
	b.add_theme_stylebox_override("focus", KitTex.box(&"focus_ring"))
	_hover_fx(b)
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
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var head := UiKit.label(caption, UiKit.SIZE_SMALL, accent, true)
	head.clip_text = true
	col.add_child(head)
	var line := UiKit.label(text, 22, UiKit.CREAM)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.max_lines_visible = 2
	line.add_theme_constant_override("line_spacing", -6)
	col.add_child(line)
	return b


## A band of light crosses PLAY now and then while the home screen is up.
func _glint() -> void:
	if not is_visible_in_tree() or _play.shine >= 0.0:
		return
	var tw := _play.create_tween()
	tw.tween_property(_play, "shine", 1.0, 0.5).from(0.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _play.shine = -1.0)


func _rotate_tip() -> void:
	_tip_index = (_tip_index + 1) % TIPS.size()
	_tip.text = "TIP  ·  " + TIPS[_tip_index]
	if is_visible_in_tree():
		UiFx.fade_in(_tip, 0.4)
