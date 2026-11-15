class_name PrizesFusionView
extends HBoxContainer
## The TRADE-UP tab, Prize Fusion: on the left the fusion machine
## (FusionChamber) with five pods for the picked prints around a core that
## shows what comes out, the rarity to fuse, AUTO-FILL, CLEAR and FUSE; on the
## right every eligible print of that rarity (favourites and worn prints are
## protected). FUSE confirms, trades up and plays FusionReveal.

const MACHINE_WIDTH := 780.0

var _page: PrizesPage
var _rarity := 0
var _picked: Array = []
var _tabs: KitTabs
var _chamber: FusionChamber
var _note: Label
var _fuse: SignButton
var _grid: GridContainer
var _cards: Array[PrintCard] = []
var _caption_note: Label


func _init(page: PrizesPage) -> void:
	_page = page
	add_theme_constant_override("separation", UiKit.GAP_L)
	add_child(_build_machine())
	var tray := UiKit.metal_frame(24)
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(tray)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	tray.add_child(col)
	var caption := UiKit.section("ELIGIBLE PRINTS", " ")
	_caption_note = caption.get_child(2) as Label
	col.add_child(caption)
	var scroll := UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_grid = PrizesCollectionView.new_grid(scroll)
	scroll.resized.connect(func(): PrizesCollectionView.fit_columns(_grid, scroll))


func _build_machine() -> Control:
	var panel := UiKit.neon_panel(FusionChamber.CYAN, 22)
	panel.custom_minimum_size.x = MACHINE_WIDTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_M)
	col.add_child(head)
	head.add_child(UiKit.arcade_label("PRIZE FUSION", 54, FusionChamber.CYAN))
	head.add_child(UiKit.filler())
	var how := UiKit.label("%d IN  →  1 OUT" % PrizePrints.series().trade_up_count, UiKit.SIZE_LABEL, UiKit.CREAM, true)
	how.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(how)
	_tabs = UiKit.tabs(18)
	for r in 3:
		var tab := _tabs.add_tab(StringName(str(r)), "%s → %s" % [PrizesPage.rarity_name(r).to_upper(), PrizesPage.rarity_name(r + 1).to_upper()])
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(func(id: StringName):
		_rarity = int(String(id))
		_picked.clear()
		refresh())
	col.add_child(_tabs)
	_chamber = FusionChamber.new()
	_chamber.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chamber.custom_minimum_size = Vector2(0, 380)
	_chamber.mouse_filter = Control.MOUSE_FILTER_STOP
	_chamber.pod_pressed.connect(_unpick)
	col.add_child(_chamber)
	_note = UiKit.body("", MACHINE_WIDTH - 44.0, UiKit.SIZE_SMALL, UiKit.MUTED)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_note)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", UiKit.GAP_M)
	col.add_child(actions)
	var fill := UiKit.sign_button("AUTO-FILL", SignButton.Kind.SECONDARY, 24)
	fill.tooltip_text = "Fills the pods with your least special prints of this rarity."
	fill.pressed.connect(auto_fill)
	actions.add_child(fill)
	var clear := UiKit.sign_button("CLEAR", SignButton.Kind.NEUTRAL, 24)
	clear.pressed.connect(func():
		_picked.clear()
		refresh())
	actions.add_child(clear)
	_fuse = UiKit.sign_button("FUSE!", SignButton.Kind.PRIMARY, 30)
	_fuse.custom_minimum_size.x = 220
	_fuse.pressed.connect(_confirm)
	actions.add_child(_fuse)
	return panel


func refresh() -> void:
	_tabs.select(StringName(str(_rarity)))
	var candidates := PrizePrints.trade_up_candidates(_rarity)
	_picked = _picked.filter(func(p): return candidates.has(p))
	candidates.sort_custom(func(a, b): return PrintLook.score(a) < PrintLook.score(b))
	PrizesCollectionView.fill_cards(_page, _grid, _cards, candidates, _toggle, null)
	for card in _cards:
		var at := _picked.find(card.print_data)
		card.set_pick(str(at + 1) if at >= 0 else "")
		card.modulate.a = 0.45 if at >= 0 else 1.0
	_fill_pods()
	var need := PrizePrints.series().trade_up_count
	_fuse.disabled = PrizePrints.trade_up_problem(_picked) != ""
	_caption_note.text = "%d %s  ·  favourites and worn prints are protected" % [candidates.size(), PrizesPage.rarity_name(_rarity)]
	_note.text = "%d of %d in the pods. Out comes one random %s print with fresh rolls: shine, rare print, serial." % [_picked.size(), need, PrizesPage.rarity_name(_rarity + 1)] \
		if candidates.size() >= need else "You have %d eligible %s print%s; Prize Fusion takes %d." % [candidates.size(), PrizesPage.rarity_name(_rarity), "" if candidates.size() == 1 else "s", need]


func _fill_pods() -> void:
	var next := PrizesPage.rarity_color(_rarity + 1)
	_chamber.core_color = next
	_chamber.core_text = "?"
	for i in FusionChamber.PODS:
		var has := i < _picked.size()
		_chamber.pod_colors[i] = PrintLook.rarity_color(_picked[i]) if has else FusionChamber.CYAN
		_chamber.pod_textures[i] = CosmeticThumbs.cached_print(_picked[i], _page.weapon_for(_picked[i])) if has else null
		if has and _chamber.pod_textures[i] == null:
			var p: Dictionary = _picked[i]
			_page.thumbs.request_print(p, func(tex: Texture2D):
				var at := _picked.find(p)
				if at >= 0:
					_chamber.pod_textures[at] = tex, _page.weapon_for(p))
	_chamber.charge = 0.15 * _picked.size() / FusionChamber.PODS


func _toggle(card: PrintCard) -> void:
	var p := card.print_data
	if _picked.has(p):
		_picked.erase(p)
	elif _picked.size() < PrizePrints.series().trade_up_count:
		_picked.append(p)
		Sfx.play(&"prz_fuse_slot", -8.0, 0.9 + 0.1 * _picked.size())
	else:
		UiSound.deny()
		return
	refresh()


func _unpick(i: int) -> void:
	if i < _picked.size():
		_picked.remove_at(i)
		UiSound.select()
		refresh()


func auto_fill() -> void:
	var candidates := PrizePrints.trade_up_candidates(_rarity)
	candidates.sort_custom(func(a, b): return PrintLook.score(a) < PrintLook.score(b))
	_picked = candidates.slice(0, PrizePrints.series().trade_up_count)
	UiSound.select()
	refresh()


func _confirm() -> void:
	if PrizePrints.trade_up_problem(_picked) != "":
		UiSound.deny()
		return
	var names := PackedStringArray()
	for p in _picked:
		names.append("%s %s" % [PrintLook.title(p), PrintLook.serial_text(int(p["serial"]))])
	var text := "These five go into the fusion chamber for good:\n%s\n\nOut comes one random %s print." % ["\n".join(names), PrizesPage.rarity_name(_rarity + 1)]
	UiKit.confirm(self, "FUSE THESE PRINTS?", text, "FUSE", _fuse_now)


func _fuse_now() -> void:
	var picked := _picked.duplicate()
	var res := PrizePrints.trade_up(picked)
	if res.is_empty():
		UiSound.deny()
		return
	_picked.clear()
	_page.play_fusion(res, picked)
