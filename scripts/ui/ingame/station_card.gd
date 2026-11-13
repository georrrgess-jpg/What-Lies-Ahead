class_name StationCard
extends PanelContainer
## One purchase of the loadout station as a card: the key that buys it, an
## icon, what it is and what it does, and its price in tickets. The price
## turns red when the player cannot pay; an offer that is not for sale right
## now shows why instead ("FULL", "SOLD OUT", "LOADED") and dims.

enum State {
	## For sale and affordable.
	BUY,
	## For sale, but the player has too few tickets.
	POOR,
	## Not for sale: nothing to refill, used up, or already loaded.
	DONE,
}

var _box: StyleBoxTexture
var _icon: HudIcon
var _title: Label
var _effect: Label
var _price_row: HBoxContainer
var _ticket: HudIcon
var _price: Label
var _done_row: HBoxContainer
var _done: Label
var _accent := UiKit.CYAN
var _state := -1
var _shown_price := -1
var _shown_note := ""


## `key` is the key cap text, `icon` a HudIcon kind, `accent` the icon colour.
static func make(key: String, icon: StringName, title: String, effect: String, accent: Color) -> StationCard:
	var c := StationCard.new()
	c._build(key, icon, title, effect, accent)
	return c


func _build(key: String, icon: StringName, title: String, effect: String, accent: Color) -> void:
	_accent = accent
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box = KitTex.box_copy(&"card", Color.WHITE, Vector2(16, 12))
	add_theme_stylebox_override("panel", _box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	head.add_child(UiKit.key_glyph(key, 46.0))
	_title = UiKit.label(title, 26, UiKit.CREAM, true)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.clip_text = true
	head.add_child(_title)
	_icon = HudIcon.make(icon, 38.0, accent)
	head.add_child(_icon)
	_effect = UiKit.label(effect, 22, UiKit.MUTED)
	col.add_child(_effect)
	col.add_child(UiKit.spacer(4))
	_price_row = HBoxContainer.new()
	_price_row.add_theme_constant_override("separation", 8)
	col.add_child(_price_row)
	_ticket = HudIcon.make(&"ticket", 30.0, UiKit.AMBER)
	_price_row.add_child(_ticket)
	_price = UiKit.label("", 30, UiKit.AMBER, true)
	_price_row.add_child(_price)
	_done_row = HBoxContainer.new()
	_done_row.add_theme_constant_override("separation", 8)
	_done_row.visible = false
	col.add_child(_done_row)
	_done_row.add_child(HudIcon.make(&"check", 28.0, UiKit.GREEN))
	_done = UiKit.label("", 26, UiKit.GREEN, true)
	_done_row.add_child(_done)


## Changes what the offer does ("+60 health").
func set_effect(text: String) -> void:
	_effect.text = text


## Shows the offer's state. `note` is the reason shown for State.DONE.
func set_state(state: State, price: int, note := "") -> void:
	if state == _state and price == _shown_price and note == _shown_note:
		return
	var first := _state < 0
	_state = state
	_shown_price = price
	_shown_note = note
	var for_sale := state != State.DONE
	_price_row.visible = for_sale
	_done_row.visible = not for_sale
	_price.text = str(price)
	_done.text = note
	var price_color := UiKit.AMBER if state == State.BUY else UiKit.RED
	_price.add_theme_color_override("font_color", price_color)
	_ticket.color = price_color
	_icon.color = _accent if state == State.BUY else Color(_accent, 0.45)
	_title.add_theme_color_override("font_color", UiKit.CREAM if state == State.BUY else UiKit.MUTED)
	_box.modulate_color = Color.WHITE if state == State.BUY else Color(0.72, 0.7, 0.82)
	if not first and is_visible_in_tree():
		UiFx.pulse(self, 1.05)
