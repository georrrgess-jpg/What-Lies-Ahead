extends CanvasLayer
## End-of-run screen in the kit's look. Top: a marquee with the outcome and
## a line about what happened. Left signboard: the score counting up (with
## NEW BEST), four stat tiles, the score breakdown and the weapon mastery
## gained. Right: the registered results sections (Career, Sparks earned,
## player card...) in a metal tray that scrolls when they do not fit.
## Bottom: the primary action first: NEXT WORLD after a clear, CONTINUE FROM
## WAVE N after a defeat past a checkpoint, then RETRY and MAIN MENU.
## Laid out for the 1920x1080 HUD canvas (fits 1280x720 and 16:10 scaled).

const MARGIN := 40.0
const LEFT_WIDTH := 980.0
## Seconds the score takes to count up.
const COUNT_TIME := 1.4

var _root: Control


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_result(result: Dictionary) -> void:
	get_tree().paused = true
	Game.capture_mouse(false)
	var victory: bool = result["victory"]
	var level: LevelData = result["level"]
	var next := next_level(level) if victory else null

	_root = Control.new()
	UiKit.apply(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = MARGIN
	outer.offset_right = -MARGIN
	outer.offset_top = 24
	outer.offset_bottom = -28
	outer.add_theme_constant_override("separation", UiKit.GAP_M)
	_root.add_child(outer)

	var header := _header(result, victory, level, next)
	outer.add_child(header)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", UiKit.GAP_L)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var summary := _summary(result, victory)
	body.add_child(summary)
	var side := _sections(result)
	if side:
		body.add_child(side)
	else:
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buttons := _buttons(victory, next)
	outer.add_child(buttons)

	UiSound.open()
	UiFx.fade_in(dim, 0.25)
	UiFx.stagger_in([header, summary, side, buttons].filter(func(c): return c != null), 0.05, 0.08)


# --- header ---------------------------------------------------------------------

func _header(result: Dictionary, victory: bool, level: LevelData, next: LevelData) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_XS)
	var sign := UiKit.marquee("LEVEL CLEARED!" if victory else "OVERRUN!", 64)
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(sign)
	sign.flash.call_deferred()
	var secs := int(result["seconds"])
	var outcome := "You escaped %s through the portal in %d:%02d." % [level.display_name, secs / 60, secs % 60] if victory \
		else "The zombies got you on wave %d of %d in %s." % [int(result["wave_reached"]), int(result["total_waves"]), level.display_name]
	if next:
		outcome += "  Next up: World %d, %s." % [GameData.worlds().find(next.world) + 1, next.world.display_name]
	var sub := UiKit.label(outcome, UiKit.SIZE_LABEL, UiKit.CREAM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	return col


# --- run summary --------------------------------------------------------------------

func _summary(result: Dictionary, victory: bool) -> Control:
	var board := UiKit.signboard()
	board.set_padding(36, 26)
	board.custom_minimum_size.x = LEFT_WIDTH
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	board.add_child(col)
	col.add_child(_score(result, victory))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(stats)
	stats.add_child(_stat("WAVES", "%d / %d" % [int(result["waves_cleared"]), int(result["total_waves"])], UiKit.CYAN))
	stats.add_child(_stat("KILLS", Wallet.format(int(result["kills"])), UiKit.GREEN))
	stats.add_child(_stat("HEADSHOTS", Wallet.format(int(result.get("headshots", 0))), UiKit.PINK_LIGHT))
	stats.add_child(_stat("BEST COMBO", "x%d" % int(result.get("best_combo", 0)), UiKit.AMBER))
	var line := _breakdown(result)
	if line:
		col.add_child(line)
	col.add_child(UiKit.section("WEAPON MASTERY", "", UiKit.AMBER))
	var rows: Array = result["weapons"]
	if rows.is_empty():
		col.add_child(UiKit.body("No mastery earned this run. Land a finishing blow to earn XP.", 0, UiKit.SIZE_BODY, UiKit.MUTED))
		return board
	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", UiKit.GAP_S)
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for row in rows:
		rows_box.add_child(_weapon_row(row))
	# Weapons and unlock lines scroll; they never push the buttons off screen.
	var scroll := UiKit.scroll(Vector2(0, 120))
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows_box)
	col.add_child(scroll)
	return board


## The score in big digits counting up, with NEW BEST or the best so far.
func _score(result: Dictionary, victory: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -6)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(names)
	names.add_child(UiKit.label("SCORE", UiKit.SIZE_HEADING, UiKit.CYAN, true))
	var final_score := int(result.get("score", 0))
	var best_new := bool(result.get("new_best", false)) and final_score > 0
	var best := UiKit.chip("NEW BEST!", UiKit.AMBER, 26) if best_new \
		else UiKit.chip("BEST %s" % Wallet.format(int(result.get("best_score", 0))), UiKit.PURPLE, 22)
	best.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	names.add_child(best)
	var value := UiKit.arcade_label("0", UiKit.SIZE_HERO, Color.WHITE if victory else UiKit.CREAM)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	var tw := UiFx.count_up(value, 0, final_score, COUNT_TIME)
	tw.tween_callback(func():
		UiFx.pulse(value, 1.08)
		if best_new:
			UiSound.confirm()
			UiFx.pulse(best, 1.3))
	if best_new:
		# NEW BEST lands when the count does.
		best.modulate.a = 0.0
		best.create_tween().tween_property(best, "modulate:a", 1.0, 0.15).set_delay(COUNT_TIME)
	return row


func _stat(caption: String, value: String, accent: Color) -> Control:
	var tile := UiKit.card_panel()
	tile.set_padding(14, 10)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	tile.add_child(v)
	var c := UiKit.label(caption, UiKit.SIZE_SMALL, accent, true)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	var val := UiKit.sign_label(value, 48)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(val)
	return tile


## Where the points came from, as one muted line ("Kills 4,200 · Combo 900").
func _breakdown(result: Dictionary) -> Control:
	var bd: Dictionary = result.get("score_breakdown", {})
	var parts := []
	for key in [["kills", "Kills"], ["headshots", "Headshots"], ["combo", "Combo"], ["multi", "Multi-kills"], ["style", "Style"], ["waves", "Waves"], ["tickets", "Tickets cashed"]]:
		if int(bd.get(key[0], 0)) > 0:
			parts.append("%s %s" % [key[1], Wallet.format(int(bd[key[0]]))])
	if parts.is_empty():
		return null
	var line := UiKit.body("  ·  ".join(parts), 0, UiKit.SIZE_SMALL, UiKit.MUTED)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return line


func _weapon_row(row: Dictionary) -> Control:
	var weapon: WeaponData = row["weapon"]
	var tile := UiKit.card_panel()
	tile.set_padding(18, 10)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", UiKit.GAP_XS)
	tile.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", UiKit.GAP_M)
	v.add_child(top)
	var name_label := UiKit.sign_label(weapon.display_name.to_upper(), 30)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(UiKit.label("%d kills" % int(row["kills"]), UiKit.SIZE_BODY, UiKit.MUTED))
	top.add_child(UiKit.label("+%s XP" % Wallet.format(int(row["xp_gained"])), 30, UiKit.GREEN, true))

	var rank_before := int(row["rank_before"])
	var rank_after := int(row["rank_after"])
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", UiKit.GAP_M)
	v.add_child(bar_row)
	var ranked_up := rank_after > rank_before
	var rank := UiKit.chip(("RANK UP!  " if ranked_up else "") + UiKit.rank_name(rank_after, weapon.max_rank()), UiKit.AMBER if ranked_up else UiKit.CYAN, 20)
	bar_row.add_child(rank)
	var xp_after := int(row["xp_after"])
	var ceiling := weapon.xp_ceiling(rank_after)
	var floor_xp := weapon.xp_floor(rank_after)
	var fraction := 1.0 if ceiling < 0 else float(xp_after - floor_xp) / float(maxi(1, ceiling - floor_xp))
	var bar := UiKit.progress(0.0, 16.0, UiKit.AMBER if ranked_up else UiKit.CYAN)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(bar)
	UiFx.fill_to(bar, fraction, 0.9, 0.5)
	var xp_text := "%s XP" % Wallet.format(xp_after) if ceiling < 0 else "%s / %s" % [Wallet.format(xp_after), Wallet.format(ceiling)]
	var xp_label := UiKit.label(xp_text, UiKit.SIZE_SMALL, UiKit.CREAM)
	xp_label.custom_minimum_size = Vector2(170, 0)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar_row.add_child(xp_label)

	var unlocks: Array = row["unlocks"]
	if not unlocks.is_empty():
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", UiKit.GAP_S)
		v.add_child(chips)
		for i in mini(unlocks.size(), 3):
			var reward: CosmeticItem = unlocks[i]
			chips.add_child(UiKit.chip("UNLOCKED  %s" % reward.display_name.to_upper(), UiKit.PINK, 18, false))
		if unlocks.size() > 3:
			chips.add_child(UiKit.label("+%d more in the Locker" % (unlocks.size() - 3), UiKit.SIZE_SMALL, UiKit.AMBER))
	return tile


# --- registered sections ------------------------------------------------------------

## The RESULTS_SECTION extensions (in their order) in a metal tray that
## scrolls; null when there are none.
func _sections(result: Dictionary) -> Control:
	var sections: Array[Control] = []
	for ext in GameData.ui_extensions(UiExtension.Kind.RESULTS_SECTION):
		if ext.script_ref and ext.script_ref.has_method("build"):
			var section: Control = ext.script_ref.build(result)
			if section:
				sections.append(section)
	if sections.is_empty():
		return null
	var tray := UiKit.metal_frame()
	tray.set_padding(26, 26)
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame := Control.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tray.add_child(frame)
	var scroll := UiKit.scroll()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(scroll)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", UiKit.GAP_M)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(side)
	for section in sections:
		side.add_child(section)
	_add_edge_fades(frame, scroll)
	_reveal_tail(scroll)
	return tray


## Fades over the top / bottom edge of `scroll` while there is more to see that way.
func _add_edge_fades(frame: Control, scroll: ScrollContainer) -> void:
	var fades: Array[TextureRect] = []
	for top in [true, false]:
		var grad := Gradient.new()
		grad.colors = PackedColorArray([Color(UiKit.INK, 0.95), Color(UiKit.INK, 0.0)])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill_from = Vector2(0, 0) if top else Vector2(0, 1)
		tex.fill_to = Vector2(0, 1) if top else Vector2(0, 0)
		tex.width = 4
		tex.height = 64
		var fade := TextureRect.new()
		fade.texture = tex
		fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fade.stretch_mode = TextureRect.STRETCH_SCALE
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		fade.offset_right = -18   # leave the scroll bar clear
		if top:
			fade.offset_bottom = 64
		else:
			fade.offset_top = -64
		frame.add_child(fade)
		fades.append(fade)
	var bar := scroll.get_v_scroll_bar()
	var update := func(_v = 0.0):
		fades[0].visible = bar.value > 1.0
		fades[1].visible = bar.value < bar.max_value - bar.page - 1.0
	bar.changed.connect(update)
	bar.value_changed.connect(update)
	update.call()


## When the sections are taller than the tray: once the XP bar has filled,
## glide down to the last section (unless the player scrolled).
func _reveal_tail(scroll: ScrollContainer) -> void:
	var tw := scroll.create_tween()
	tw.tween_interval(3.4)
	tw.tween_callback(func():
		var bar := scroll.get_v_scroll_bar()
		var bottom := int(bar.max_value - bar.page)
		if bottom > 0 and scroll.scroll_vertical == 0:
			scroll.create_tween().tween_property(scroll, "scroll_vertical", bottom, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))


# --- actions ------------------------------------------------------------------------

## The primary action first (pink, focused): NEXT WORLD after a clear,
## CONTINUE FROM WAVE N after a defeat past a checkpoint, otherwise RETRY.
func _buttons(victory: bool, next: LevelData) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	var primary: SignButton = null
	if next:
		primary = _button(row, "NEXT WORLD", SignButton.Kind.PRIMARY, func(): Game.start_level(next.id, &""))
		primary.name = "NextWorld"
	elif not victory and Game.can_continue_run():
		primary = _button(row, "CONTINUE FROM WAVE %d" % Game.checkpoint_wave, SignButton.Kind.PRIMARY, func(): Game.continue_run())
		primary.name = "ContinueRun"
	var retry := _button(row, "RETRY", SignButton.Kind.SECONDARY if primary else SignButton.Kind.PRIMARY, func(): Game.retry())
	retry.name = "Retry"
	var menu := _button(row, "MAIN MENU", SignButton.Kind.NEUTRAL if primary else SignButton.Kind.SECONDARY, func(): Game.to_menu())
	menu.name = "MainMenu"
	(primary if primary else retry).grab_focus.call_deferred()
	return row


func _button(row: HBoxContainer, text: String, kind: SignButton.Kind, action: Callable) -> SignButton:
	var b := UiKit.sign_button(text, kind, 40 if kind == SignButton.Kind.PRIMARY else UiKit.SIZE_BUTTON)
	b.custom_minimum_size = Vector2(380 if kind == SignButton.Kind.PRIMARY else 300, 86)
	b.pressed.connect(action)
	row.add_child(b)
	return b


## The level after `level` in world order, if the player has unlocked it.
static func next_level(level: LevelData) -> LevelData:
	var found := false
	for world in GameData.worlds():
		for l in world.levels:
			if found:
				return l if GameData.is_level_unlocked(l) else null
			found = l == level
	return null
