class_name UiKit
extends RefCounted
## Entry point of the UI kit: the palette, type scale and fonts, the Theme,
## and one-line constructors for every component in scripts/ui/kit/.
## The look is a carnival arcade: marquee signs with bulbs, riveted teal
## metal, cream-trimmed signboards on dark aubergine, neon cyan and pink.
## docs/UI_STYLE.md shows every component with examples.
##
##   root.theme = UiKit.theme()            # or UiKit.apply(root)
##   var deploy := UiKit.sign_button("DEPLOY")
##   var panel := UiKit.signboard()
##   UiKit.toast("Loadout saved")

const PINK := Color("ff3fa4")
const PINK_LIGHT := Color("ff7cc6")
const PINK_DARK := Color("b81f72")
const CYAN := Color("35f0ff")
const AMBER := Color("ffc24a")
const TEAL := Color("17a3a3")
const NAVY := Color("1b1446")
const INK := Color("120c2e")
const PURPLE := Color("6a34b8")
const CREAM := Color("fff3dc")
const GREEN := Color("52f060")
const RED := Color("ff4d6a")
## Signboard face (the dark aubergine inside cream trim).
const PANEL := Color("1d1338")
## Painted metal of frames and plates.
const METAL := Color("2b918c")
## Secondary text on dark panels.
const MUTED := Color("b9add9")

## Type scale (canvas pixels on the 1920x1080 canvas). Display sizes use the
## display font (Lilita One), body sizes the body font (Baloo 2).
const SIZE_HERO := 96
const SIZE_TITLE := 64
const SIZE_HEADING := 44
const SIZE_BUTTON := 36
const SIZE_LABEL := 26
const SIZE_BODY := 24
const SIZE_SMALL := 20
## Spacing steps: use these, not arbitrary numbers.
const GAP_XS := 4
const GAP_S := 8
const GAP_M := 16
const GAP_L := 24
const GAP_XL := 40
## Distance from the screen edge to page content.
const PAGE_MARGIN := 48

const DISPLAY_FONT_PATH := "res://art/fonts/LilitaOne-Regular.ttf"
const BODY_FONT_PATH := "res://art/fonts/Baloo2-Variable.ttf"

static var _theme: Theme
static var _display: Font
static var _body: Font


static func display_font() -> Font:
	if _display == null:
		_display = load(DISPLAY_FONT_PATH) if ResourceLoader.exists(DISPLAY_FONT_PATH) else ThemeDB.fallback_font
	return _display


static func body_font() -> Font:
	if _body == null:
		if ResourceLoader.exists(BODY_FONT_PATH):
			var variation := FontVariation.new()
			variation.base_font = load(BODY_FONT_PATH)
			variation.variation_opentype = {"wght": 650}
			_body = variation
		else:
			_body = ThemeDB.fallback_font
	return _body


## Flat rounded box, for small inner tiles. Panels and buttons should use the
## textured kit pieces (signboard(), metal_frame(), sign_button() ...).
static func box(fill: Color, border := Color.TRANSPARENT, radius := 18, border_width := 0, padding := 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(padding)
	sb.anti_aliasing = true
	return sb


## Gives `root` the kit's theme and texture filtering (smooth when the canvas
## is scaled down). Call it on the top Control of a screen.
static func apply(root: Control) -> void:
	root.theme = theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 28

	# Buttons: pink fairground signs with a darker lip.
	t.set_stylebox("normal", "Button", KitTex.button(&"btn", &"pink", &"normal"))
	t.set_stylebox("hover", "Button", KitTex.button(&"btn", &"pink", &"hover"))
	t.set_stylebox("pressed", "Button", KitTex.button(&"btn", &"pink", &"pressed"))
	t.set_stylebox("hover_pressed", "Button", KitTex.button(&"btn", &"pink", &"pressed"))
	t.set_stylebox("disabled", "Button", KitTex.button(&"btn", &"grey", &"normal"))
	t.set_stylebox("focus", "Button", KitTex.box(&"focus_ring"))
	t.set_font("font", "Button", display_font())
	t.set_font_size("font_size", "Button", 38)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_hover_pressed_color", "Button", CREAM)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.45))
	t.set_color("font_outline_color", "Button", Color(INK, 0.55))
	t.set_constant("outline_size", "Button", 8)
	t.set_color("icon_normal_color", "Button", CREAM)
	t.set_color("icon_hover_color", "Button", Color.WHITE)
	t.set_color("icon_pressed_color", "Button", CREAM)
	t.set_color("icon_focus_color", "Button", Color.WHITE)
	t.set_color("icon_disabled_color", "Button", Color(1, 1, 1, 0.4))

	var board := KitTex.box_copy(&"signboard", Color.WHITE, Vector2(32, 30))
	t.set_stylebox("panel", "PanelContainer", board)
	t.set_stylebox("panel", "Panel", board)
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_shadow_color", "Label", Color(INK, 0.7))
	t.set_constant("shadow_offset_y", "Label", 3)
	t.set_constant("shadow_offset_x", "Label", 0)

	# Sliders.
	var track := box(Color(INK, 0.95), Color("4a3b86"), 9, 2, 0)
	track.content_margin_top = 9
	track.content_margin_bottom = 9
	var fill := box(CYAN, Color("9df8ff"), 9, 0, 0)
	fill.border_width_top = 3
	fill.content_margin_top = 9
	fill.content_margin_bottom = 9
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", KitTex.tex(&"knob"))
	t.set_icon("grabber_highlight", "HSlider", KitTex.tex(&"knob_hover"))

	# Scrollbars.
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(Color(INK, 0.85), Color("3a2d6b"), 8, 2, 7))
		t.set_stylebox("scroll_focus", bar, box(Color(INK, 0.85), CYAN, 8, 2, 7))
		t.set_stylebox("grabber", bar, box(METAL, Color.TRANSPARENT, 7, 0, 7))
		t.set_stylebox("grabber_highlight", bar, box(METAL.lightened(0.25), Color.TRANSPARENT, 7, 0, 7))
		t.set_stylebox("grabber_pressed", bar, box(CYAN, Color.TRANSPARENT, 7, 0, 7))

	t.set_stylebox("panel", "TooltipPanel", box(INK, CYAN, 12, 2, 12))
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_font_size("font_size", "TooltipLabel", 22)
	_theme = t
	return t


# --- text ----------------------------------------------------------------------------

static func label(text: String, size := 28, color := Color.WHITE, display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if display:
		l.add_theme_font_override("font", display_font())
	return l


## Big arcade text: display font with a dark outline, like the reference HUD.
static func arcade_label(text: String, size := 72, color := Color.WHITE) -> Label:
	var l := label(text, size, color, true)
	l.add_theme_color_override("font_outline_color", Color(INK, 0.85))
	l.add_theme_constant_override("outline_size", maxi(6, size / 7))
	l.add_theme_constant_override("shadow_offset_y", maxi(3, size / 16))
	return l


## Chunky cream sign lettering (signboard titles, slot plates).
static func sign_label(text: String, size := SIZE_HEADING, color := CREAM) -> Label:
	var l := label(text, size, color, true)
	l.add_theme_color_override("font_outline_color", Color("1a0f26"))
	l.add_theme_constant_override("outline_size", maxi(4, size / 9))
	l.add_theme_constant_override("shadow_offset_y", maxi(2, size / 18))
	return l


## Body text that wraps inside `width`.
static func body(text: String, width := 0.0, size := SIZE_BODY, color := CREAM) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func spacer(height := 16.0, width := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A spacer that takes all the room left in a box container.
static func filler() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Section header: cyan caption, a hairline that fills the row, optional note.
static func section(text: String, note := "", color := CYAN) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP_M)
	row.add_child(label(text, SIZE_LABEL, color, true))
	var line := ColorRect.new()
	line.color = Color(color, 0.28)
	line.custom_minimum_size = Vector2(24, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	if note != "":
		row.add_child(label(note, SIZE_SMALL, MUTED))
	return row


# --- buttons -------------------------------------------------------------------------

## Primary (pink) button. Kept for existing callers; same as sign_button(text).
static func button(text: String, font_size := 38) -> Button:
	return SignButton.make(text, SignButton.Kind.PRIMARY, font_size)


## Secondary (teal) button.
static func soft_button(text: String, font_size := 30) -> Button:
	return SignButton.make(text, SignButton.Kind.SECONDARY, font_size)


## A sign-shaped button. `kind`: PRIMARY (pink, the one action a screen is
## about), SECONDARY (teal), GOLD (spend Sparks, claim), NEUTRAL (purple).
static func sign_button(text: String, kind := SignButton.Kind.PRIMARY, font_size := SIZE_BUTTON) -> SignButton:
	return SignButton.make(text, kind, font_size)


## The BACK sign (teal plate with pointed ends). Plays the back sound.
static func back_button(text := "BACK") -> SignButton:
	return SignButton.make(text, SignButton.Kind.BACK, 30)


## Small square button with an icon from art/ui (e.g. &"icon_gear").
static func icon_button(icon: StringName, tooltip := "") -> SignButton:
	return SignButton.make_icon(icon, tooltip)


## A toggle for tabs and option rows: purple when off, pink when on. Give the
## buttons of one row the same ButtonGroup.
static func toggle_button(text: String, group: ButtonGroup = null, font_size := 26) -> SignButton:
	return SignButton.make_toggle(text, group, font_size)


# --- panels --------------------------------------------------------------------------

## Cream-trimmed signboard: the main panel for information.
static func signboard(padding := -1.0) -> KitPanel:
	return KitPanel.make(KitPanel.Kind.SIGNBOARD, padding)


## Riveted teal metal frame around a dark recess: trays, lists, grids.
static func metal_frame(padding := -1.0) -> KitPanel:
	return KitPanel.make(KitPanel.Kind.METAL, padding)


## Solid teal metal plate (bars, small plaques).
static func metal_plate(padding := -1.0) -> KitPanel:
	return KitPanel.make(KitPanel.Kind.PLATE, padding)


## Dark plate with a neon outline in `accent`.
static func neon_panel(accent := CYAN, padding := -1.0) -> KitPanel:
	var p := KitPanel.make(KitPanel.Kind.NEON, padding)
	p.accent = accent
	return p


## Dark rounded card backing (tiles inside a panel).
static func card_panel(padding := -1.0) -> KitPanel:
	return KitPanel.make(KitPanel.Kind.CARD, padding)


## Marquee sign with animated bulbs: page titles.
static func marquee(text: String, font_size := 72) -> MarqueeSign:
	return MarqueeSign.make(text, font_size)


## Slot plate: small caption over a big value ("PRIMARY [1]" / "ION CARBINE").
static func slot_plate(caption: String, value: String, accent := CYAN) -> SlotPlate:
	return SlotPlate.make(caption, value, accent)


## Item card (weapon, cosmetic, shop offer). See ItemCard for its states.
static func item_card(title: String, card_size := Vector2(220, 250)) -> ItemCard:
	return ItemCard.make(title, card_size)


## Chip / tag. `pointed` gives it the arrow ends of the reference chips.
static func chip(text: String, color := CYAN, font_size := 20, pointed := true) -> KitChip:
	return KitChip.make(text, color, font_size, pointed)


## One stat: name on the left, value on the right, optional bar between.
static func stat_row(caption: String, value := "", with_bar := false) -> StatRow:
	return StatRow.make(caption, value, with_bar)


## Row of tabs. add_tab(id, text) for each, then connect tab_changed.
static func tabs(font_size := 26) -> KitTabs:
	return KitTabs.make(font_size)


# --- bars, scrolling -------------------------------------------------------------------

## Progress bar: recessed dark track with a glossy fill. Returns the ProgressBar.
static func progress(value: float, height := 18.0, fill_color := CYAN) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	var radius := int(height / 2)
	bar.add_theme_stylebox_override("background", box(Color(INK, 0.95), Color("4a3b86"), radius, 2 if height >= 12.0 else 1, 0))
	bar.add_theme_stylebox_override("fill", bar_fill(fill_color, height))
	return bar


## The fill style of progress(): `color` with a lighter gloss line on top.
static func bar_fill(color: Color, height := 18.0) -> StyleBoxFlat:
	var fill := box(color, color.lightened(0.45), int(height / 2), 0, 0)
	fill.border_width_top = 3 if height >= 14.0 else (2 if height >= 10.0 else 0)
	fill.border_blend = true
	return fill


## Vertical scroll area with the kit's scrollbar; follows keyboard focus.
static func scroll(min_size := Vector2.ZERO) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = min_size
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.follow_focus = true
	return s


# --- player, currency --------------------------------------------------------------------

## The Spark icon (four-point star) at `icon_size` pixels.
static func spark_icon(icon_size := 32.0) -> TextureRect:
	return icon(&"icon_spark", icon_size)


## Any icon from art/ui at `icon_size` pixels, tinted with `color`.
static func icon(name: StringName, icon_size := 32.0, color := Color.WHITE) -> TextureRect:
	var r := TextureRect.new()
	r.texture = KitTex.tex(name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(icon_size, icon_size)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.modulate = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Spark icon and an amount, for prices and rewards. Red when `affordable` is false.
static func price_tag(amount: int, font_size := SIZE_LABEL, affordable := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spark_icon(font_size * 1.15))
	var l := label(Wallet.format(amount), font_size, Wallet.COLOR if affordable else RED, true)
	l.name = "Amount"
	row.add_child(l)
	return row


## The player's Sparks balance; follows the Wallet and counts up on change.
static func sparks_chip() -> SparksChip:
	return SparksChip.new()


## Shield with the player's level (follows Progression unless a level is set).
static func level_badge(badge_size := 72.0) -> LevelBadge:
	return LevelBadge.make(badge_size)


# --- prompts, feedback -----------------------------------------------------------------

## A keycap: key_glyph("ESC"). "LMB" and "RMB" draw a mouse.
static func key_glyph(key: String, glyph_size := 40.0) -> Control:
	return KeyGlyph.make(key, glyph_size)


## A keycap followed by what it does: key_prompt("ESC", "Back").
static func key_prompt(key: String, action: String) -> HBoxContainer:
	return KeyGlyph.prompt(key, action)


## Shows a short message that slides in at the top of the screen and leaves by
## itself. `accent` colours its outline (AMBER notice, GREEN success, RED error).
static func toast(text: String, accent := AMBER, icon_name: StringName = &"", seconds := 3.5) -> void:
	KitToast.show_toast(text, accent, icon_name, seconds)


## Modal yes/no question over `host`; `on_yes` runs if the player confirms.
## Focus starts on the safe answer. Returns the dialog (signals confirmed,
## cancelled).
static func confirm(host: Node, title: String, text: String, yes_text: String, on_yes: Callable, no_text := "CANCEL") -> KitDialog:
	return KitDialog.ask(host, title, text, yes_text, on_yes, no_text)


## Sets the hover text of `control` (styled by the theme).
static func tooltip(control: Control, text: String) -> void:
	control.tooltip_text = text


static func rank_name(rank: int, max_rank: int) -> String:
	if rank >= max_rank:
		return "MASTERED"
	return "RANK %d" % rank
