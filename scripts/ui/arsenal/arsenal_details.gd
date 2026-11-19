class_name ArsenalDetails
extends KitPanel
## The Arsenal's right panel: the selected weapon's name and firing tags,
## what it does, six stats, its mastery and the button that equips it. Only
## the description scrolls (inside its own box) when it is longer than the
## room left; the name, stats, mastery and button always show.
##
## The button says what pressing it does: EQUIP PRIMARY / EQUIP SECONDARY,
## or, disabled, EQUIPPED or LOCKED · what unlocks it (the full requirement
## is also written above it).

signal equip_pressed

const NAME_SIZE := 52
const NAME_MIN_SIZE := 38
const BUTTON_SIZE := 34
const BUTTON_MIN_SIZE := 22
## Tags shown as pills under the chip (the first tag is on the chip).
const MAX_PILLS := 4

var _scroll: ScrollContainer
var _body: VBoxContainer
var _name: Label
var _chip: KitChip
var _pills: HFlowContainer
var _about: Label
var _stats: GridContainer
var _stat_values: Array[Label] = []
var _stat_captions: Array[Label] = []
var _rank: Label
var _tier: Label
var _pips: RankPips
var _note: Label
var _equip: SignButton
var _fade: Tween


func _init() -> void:
	kind = Kind.SIGNBOARD
	_style()
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", UiKit.GAP_S)
	add_child(_body)
	_build_head()
	_build_stats()
	_build_mastery()
	_body.add_child(_build_action())


func _build_head() -> void:
	_name = UiKit.sign_label("", NAME_SIZE)
	_name.name = "WeaponName"
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.add_theme_constant_override("line_spacing", -10)
	_name.resized.connect(_fit_name)
	_body.add_child(_name)
	_chip = UiKit.chip("", UiKit.CYAN, 24)
	_body.add_child(_chip)
	_scroll = UiKit.scroll()
	_scroll.name = "AboutScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = false
	_body.add_child(_scroll)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", UiKit.GAP_S)
	_scroll.add_child(text)
	_pills = HFlowContainer.new()
	_pills.alignment = FlowContainer.ALIGNMENT_CENTER
	_pills.add_theme_constant_override("h_separation", UiKit.GAP_S)
	_pills.add_theme_constant_override("v_separation", UiKit.GAP_XS)
	text.add_child(_pills)
	_about = UiKit.body("", 0.0, 22, UiKit.CREAM)
	_about.name = "About"
	_about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_about.add_theme_constant_override("line_spacing", -4)
	text.add_child(_about)


func _build_stats() -> void:
	_stats = GridContainer.new()
	_stats.add_theme_constant_override("h_separation", UiKit.GAP_S)
	_stats.add_theme_constant_override("v_separation", UiKit.GAP_XS)
	_body.add_child(_stats)
	for entry in ArsenalStats.STATS:
		var tile := UiKit.card_panel()
		tile.set_padding(14, 4)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats.add_child(tile)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UiKit.GAP_S)
		tile.add_child(row)
		var caption := UiKit.label(entry[0], 24, UiKit.CREAM, true)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		_stat_captions.append(caption)
		var value := UiKit.label("", 24, Color.WHITE)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_stat_values.append(value)


func _build_mastery() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_S)
	_body.add_child(head)
	_rank = UiKit.label("", 26, UiKit.AMBER, true)
	_rank.name = "MasteryRank"
	head.add_child(_rank)
	_tier = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED)
	_tier.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tier.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_tier.clip_text = true
	head.add_child(_tier)
	_pips = RankPips.make(UiKit.AMBER)
	_pips.name = "MasteryPips"
	_body.add_child(_pips)


## The requirement line (locked weapons) and the button: the coach mark's anchor.
func _build_action() -> Control:
	var action := VBoxContainer.new()
	action.name = "CoachAnchor"
	action.add_theme_constant_override("separation", UiKit.GAP_XS)
	action.add_child(UiKit.spacer(UiKit.GAP_XS))
	_note = UiKit.body("", 0.0, UiKit.SIZE_SMALL, UiKit.AMBER)
	_note.name = "UnlockNote"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action.add_child(_note)
	_equip = UiKit.sign_button("EQUIP", SignButton.Kind.PRIMARY, BUTTON_SIZE)
	_equip.name = "EquipButton"
	_equip.custom_minimum_size.y = 76
	_equip.clip_text = true
	_equip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_equip.pressed.connect(func(): equip_pressed.emit())
	_equip.resized.connect(_fit_button)
	action.add_child(_equip)
	return action


## Fills the panel for `w`; `changed` is true when it is a different weapon
## than before (the text fades across and scrolls back to the top).
func show_weapon(w: WeaponData, changed: bool) -> void:
	_name.text = w.display_name.to_upper()
	_fit_name()
	var tags := ArsenalStats.tags(w)
	var rank := Mastery.rank(w.id)
	_chip.set_text("%s  ·  %s" % [tags[0] if not tags.is_empty() else w.category.to_upper(), UiKit.rank_name(rank, w.max_rank())])
	_chip.set_color(w.tracer_color.lerp(Color.WHITE, 0.25))
	_fill_pills(tags, w)
	_about.text = w.role
	for i in ArsenalStats.STATS.size():
		_stat_captions[i].text = ArsenalStats.caption(w, i)
		_stat_values[i].text = ArsenalStats.stat(w, ArsenalStats.STATS[i][1])
	_rank.text = "MASTERY  %d / %d" % [rank, w.max_rank()]
	_tier.text = Mastery.rank_label(rank)
	_tier.tooltip_text = _tier.text
	_pips.set_ranks(rank, w.max_rank(), Mastery.rank_progress(w.id))
	refresh_action(w)
	if changed:
		_scroll.scroll_vertical = 0
		_fade_in()


## The button's state for `w` (also after equipping).
func refresh_action(w: WeaponData) -> void:
	var unlocked := GameData.is_weapon_unlocked(w)
	_note.visible = not unlocked
	_note.text = "Unlock: %s" % ArsenalStats.unlock_text(w) if not unlocked else ""
	if not unlocked:
		_equip.text = "LOCKED  ·  %s" % ArsenalStats.short_unlock(w).to_upper()
	elif Loadout.slot_of(w.id) >= 0:
		_equip.text = "EQUIPPED"
	else:
		_equip.text = "EQUIP %s" % String(Loadout.SLOT_NAMES[Loadout.slot_for(w)]).to_upper()
	_equip.disabled = not unlocked or Loadout.slot_of(w.id) >= 0
	_equip.focus_mode = Control.FOCUS_NONE if _equip.disabled else Control.FOCUS_ALL
	_equip.tooltip_text = _note.text if not unlocked else "Equip it (F, pad Y)"
	_fit_button()


## The description's font size (ArsenalLayout.about_size).
func set_about_size(font_size: int) -> void:
	_about.add_theme_font_size_override(&"font_size", font_size)


## Two columns of stats when the panel is short, one when it is tall.
func set_stat_columns(columns: int) -> void:
	_stats.columns = columns


func equip_button() -> SignButton:
	return _equip


func _fill_pills(tags: Array[String], w: WeaponData) -> void:
	for c in _pills.get_children():
		_pills.remove_child(c)
		c.queue_free()
	_pills.visible = tags.size() > 1
	for i in range(1, mini(tags.size(), MAX_PILLS + 1)):
		_pills.add_child(UiKit.chip(tags[i], w.tracer_color.lerp(UiKit.INK, 0.72), 18, false))


## The name in the largest size that fits one line, down to NAME_MIN_SIZE;
## below that it wraps (the label grows taller).
func _fit_name() -> void:
	var room := _name.size.x - 12.0
	if room <= 0.0:
		return
	var font := UiKit.display_font()
	var font_size := NAME_SIZE
	while font_size > NAME_MIN_SIZE and font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 2
	if _name.get_theme_font_size(&"font_size") != font_size:
		_name.add_theme_font_size_override(&"font_size", font_size)


## The button's label in the largest size that fits, down to BUTTON_MIN_SIZE.
func _fit_button() -> void:
	var room := _equip.size.x - 60.0
	if room <= 0.0:
		return
	var font := UiKit.display_font()
	var font_size := BUTTON_SIZE
	while font_size > BUTTON_MIN_SIZE and font.get_string_size(_equip.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 2
	if _equip.get_theme_font_size(&"font_size") != font_size:
		_equip.add_theme_font_size_override(&"font_size", font_size)


## A quick fade of the panel when the weapon changes (instant with reduced motion).
func _fade_in() -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	_body.modulate.a = 1.0
	if Settings.reduce_motion() or not is_visible_in_tree():
		return
	_body.modulate.a = 0.35
	_fade = create_tween()
	_fade.tween_property(_body, "modulate:a", 1.0, 0.16)
