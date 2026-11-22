class_name PrizesCapsulesView
extends HBoxContainer
## The CAPSULES tab: the Prize Capsule machine alone, big and centred under a
## spotlight, with the luck meter and what earns capsules on its left, and
## the capsules held, OPEN CAPSULE, OPEN 5, BUY and the odds on its right.
## Over the machine, one tab per series picks which series capsules open
## (PrizePrints.select_series); the machine is painted for it and a line
## under the tabs says what the series is and how much of it is collected.

const SIDE_WIDTH := 430.0
const SPOT := """shader_type canvas_item;
void fragment() {
	vec2 d = (UV - vec2(0.5, 0.55)) * vec2(1.0, 0.9);
	float g = smoothstep(0.55, 0.0, length(d));
	COLOR = vec4(vec3(1.0, 0.35, 0.7) * 0.55 + vec3(0.4, 0.3, 1.0) * 0.45, g * g * 0.42);
	float floor_glow = smoothstep(0.32, 0.0, length((UV - vec2(0.5, 0.95)) * vec2(1.0, 4.0)));
	COLOR += vec4(1.0, 0.8, 0.4, 1.0) * floor_glow * 0.25;
}"""

var _page: PrizesPage
var _machine: CapsuleMachine
var _series_tabs: KitTabs
var _series_line: Label
var _count: Label
var _count_note: Label
var _open: SignButton
var _open_five: SignButton
var _buy: SignButton
var _luck_epic: ProgressBar
var _luck_epic_text: Label
var _luck_legendary: ProgressBar
var _luck_legendary_text: Label
var _tokens: Label


func _init(page: PrizesPage) -> void:
	_page = page
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", UiKit.GAP_L)
	add_child(_build_luck())
	add_child(_build_machine())
	add_child(_build_actions())


func first_focus() -> Control:
	return _open


func _build_luck() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = SIDE_WIDTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	var board := UiKit.signboard(22)
	col.add_child(board)
	var luck := VBoxContainer.new()
	luck.add_theme_constant_override("separation", UiKit.GAP_S)
	board.add_child(luck)
	luck.add_child(UiKit.sign_label("LUCK METER", 40))
	luck.add_child(UiKit.body("Every capsule without one fills the meter: an Epic or better is guaranteed, and so is a Legendary.", SIDE_WIDTH - 44.0, UiKit.SIZE_SMALL, UiKit.MUTED))
	_luck_epic_text = UiKit.label("", UiKit.SIZE_BODY, UiKit.CREAM)
	luck.add_child(_luck_epic_text)
	_luck_epic = UiKit.progress(0.0, 18.0, PrizesPage.rarity_color(2))
	luck.add_child(_luck_epic)
	_luck_legendary_text = UiKit.label("", UiKit.SIZE_BODY, UiKit.CREAM)
	luck.add_child(_luck_legendary_text)
	_luck_legendary = UiKit.progress(0.0, 18.0, PrizesPage.rarity_color(3))
	luck.add_child(_luck_legendary)
	var earn := UiKit.card_panel(18)
	col.add_child(earn)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	earn.add_child(list)
	list.add_child(UiKit.label("EARN CAPSULES", UiKit.SIZE_LABEL, UiKit.CYAN, true))
	var s := PrizePrints.series()
	for line in ["%d per alpha defeated" % s.capsules_per_alpha, "%d per bounty claimed" % s.capsules_per_bounty,
			"%d for the day's first clear" % s.capsules_daily_clear, "1 for every %d contracts" % s.contracts_per_capsule,
			"%d per milestone" % s.capsules_per_milestone]:
		list.add_child(UiKit.label("·  " + line, UiKit.SIZE_SMALL, UiKit.CREAM))
	return col


func _build_machine() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size.x = 520
	col.add_theme_constant_override("separation", UiKit.GAP_XS)
	_series_tabs = KitTabs.make(20, true)
	_series_tabs.add_theme_constant_override("separation", UiKit.GAP_XS)
	for s in PrizePrints.all_series():
		var tab := _series_tabs.add_tab(s.id, "SERIES %d  ·  %s" % [s.number, s.display_name.to_upper()])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.tooltip_text = s.tagline
	_series_tabs.tab_changed.connect(_on_series_picked)
	col.add_child(_series_tabs)
	_series_line = UiKit.label("", UiKit.SIZE_SMALL, UiKit.CREAM)
	_series_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_series_line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_series_line.add_theme_constant_override("outline_size", 8)
	_series_line.add_theme_color_override("font_outline_color", UiKit.INK)
	col.add_child(_series_line)
	var stage := Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(stage)
	var spot := ColorRect.new()
	spot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SPOT
	var m := ShaderMaterial.new()
	m.shader = shader
	spot.material = m
	stage.add_child(spot)
	_machine = CapsuleMachine.new()
	_machine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_machine)
	return col


func _on_series_picked(id: StringName) -> void:
	if _page.busy:
		_series_tabs.select(PrizePrints.series().id)
		return
	PrizePrints.select_series(id)
	refresh()
	UiFx.pulse(_machine)


func _build_actions() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = SIDE_WIDTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	var plate := UiKit.signboard(22)
	col.add_child(plate)
	var held := VBoxContainer.new()
	held.add_theme_constant_override("separation", 0)
	plate.add_child(held)
	held.add_child(UiKit.label("YOUR CAPSULES", UiKit.SIZE_LABEL, UiKit.CYAN, true))
	_count = UiKit.arcade_label("x0", 96, UiKit.AMBER)
	held.add_child(_count)
	_count_note = UiKit.label("", UiKit.SIZE_SMALL, UiKit.MUTED)
	held.add_child(_count_note)
	var credits := HBoxContainer.new()
	credits.add_theme_constant_override("separation", UiKit.GAP_S)
	held.add_child(credits)
	credits.add_child(UiKit.icon(&"icon_credit", UiKit.SIZE_BODY * 2.2))
	_tokens = UiKit.label("", UiKit.SIZE_BODY, UiKit.CREAM, true)
	credits.add_child(_tokens)
	_open = UiKit.sign_button("OPEN CAPSULE", SignButton.Kind.PRIMARY, 34)
	_open.name = "FirstFocus"
	_open.custom_minimum_size.y = 84
	_open.pressed.connect(func(): _page.open_capsules(1))
	col.add_child(_open)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(row)
	_open_five = UiKit.sign_button("OPEN 5", SignButton.Kind.SECONDARY, 26)
	_open_five.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open_five.tooltip_text = "Open five capsules in one go."
	_open_five.pressed.connect(func(): _page.open_capsules(CapsuleReveal.MULTI))
	row.add_child(_open_five)
	_buy = UiKit.sign_button("", SignButton.Kind.GOLD, 26)
	_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy.icon = UiKit.spark_icon(28).texture
	_buy.add_theme_constant_override("icon_max_width", 44)
	_buy.pressed.connect(_page.buy_capsule)
	row.add_child(_buy)
	var odds := UiKit.card_panel(16)
	col.add_child(odds)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", UiKit.GAP_XS)
	odds.add_child(lines)
	lines.add_child(UiKit.label("ODDS PER CAPSULE", UiKit.SIZE_SMALL, UiKit.CYAN, true))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", UiKit.GAP_XS)
	chips.add_theme_constant_override("v_separation", UiKit.GAP_XS)
	lines.add_child(chips)
	var s := PrizePrints.series()
	for r in 4:
		chips.add_child(UiKit.chip("%s %d%%" % [PrizesPage.rarity_name(r).to_upper(), roundi(s.odds[r] * 100.0)], PrizesPage.rarity_color(r), 16))
	var more := UiKit.sign_button("ODDS & INFO", SignButton.Kind.NEUTRAL, 20)
	more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	more.pressed.connect(_page.show_view.bind(&"odds"))
	lines.add_child(more)
	return col


func refresh() -> void:
	var s := PrizePrints.series()
	_series_tabs.select(s.id)
	_machine.dress(s)
	var got := PrizePrints.collected(s)
	_series_line.text = "%s  ·  %d / %d collected" % [s.tagline, got.x, got.y]
	_series_line.tooltip_text = _series_line.text
	var n := PrizePrints.capsules()
	_machine.capsule_count = n
	_count.text = "x%d" % n
	_count_note.text = "ready to open" if n > 0 else "earn them in runs, or buy one"
	_tokens.text = "%d CAPSULE CREDITS" % PrizePrints.tokens()
	_open.text = "OPEN CAPSULE" if n > 0 else "NO CAPSULES"
	_open.disabled = n <= 0 or _page.busy
	_open_five.disabled = n < CapsuleReveal.MULTI or _page.busy
	_buy.text = "BUY  %s" % Wallet.format(s.capsule_price)
	_buy.disabled = _page.busy or not PrizePrints.can_buy_capsule()
	var luck := PrizePrints.luck()
	_luck_epic_text.text = "Epic or better within %d capsule%s" % [luck.x, "" if luck.x == 1 else "s"]
	_luck_epic.value = 1.0 - float(luck.x - 1) / s.epic_pity
	_luck_legendary_text.text = "Legendary within %d capsule%s" % [luck.y, "" if luck.y == 1 else "s"]
	_luck_legendary.value = 1.0 - float(luck.y - 1) / s.legendary_pity


func deny_open() -> void:
	UiFx.deny(_open)


func deny_buy() -> void:
	UiFx.deny(_buy)


func bought() -> void:
	refresh()
	UiFx.pulse(_count)
	_open.grab_focus()
