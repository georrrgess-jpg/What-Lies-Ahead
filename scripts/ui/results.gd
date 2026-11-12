extends CanvasLayer
## End-of-run screen: outcome, score, waves survived and mastery gained per
## weapon, with the registered results sections (Career, player card) beside
## them. After a clear, NEXT WORLD starts the next unlocked level; RETRY and
## MAIN MENU are always there. Laid out for the 1920x1080 HUD canvas.

## The panel fits the 1920x1080 canvas with a margin all round.
const PANEL_SIZE := Vector2(1840, 1016)
const COLUMN_WIDTH := 900.0

var _root: Control


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_result(result: Dictionary) -> void:
	get_tree().paused = true
	Game.capture_mouse(false)
	var victory: bool = result["victory"]
	var level: LevelData = result["level"]

	_root = Control.new()
	_root.theme = UiKit.theme()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.95), UiKit.CYAN if victory else UiKit.PINK, 30, 5, 28))
	panel.custom_minimum_size = PANEL_SIZE
	center.add_child(panel)
	# Layout: header across the top, then the run summary on the left and the
	# registered sections (progression, player card...) scrolling on the right,
	# buttons along the bottom.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	outer.add_child(header)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	body.add_child(col)
	var sections: Array[Control] = []
	for ext in GameData.ui_extensions(UiExtension.Kind.RESULTS_SECTION):
		if ext.script_ref and ext.script_ref.has_method("build"):
			var section: Control = ext.script_ref.build(result)
			if section:
				sections.append(section)
	if not sections.is_empty():
		# As tall as the body: only a run with many unlocks needs to scroll.
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.add_child(scroll)
		var side := VBoxContainer.new()
		side.add_theme_constant_override("separation", 14)
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(side)
		for section in sections:
			side.add_child(section)

	var title := UiKit.arcade_label("LEVEL CLEARED!" if victory else "OVERRUN!", 84, UiKit.CYAN if victory else UiKit.PINK_LIGHT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	var next := next_level(level) if victory else null
	var outcome := "You escaped %s through the portal." % level.display_name if victory \
		else "The zombies got you on wave %d of %s." % [int(result["wave_reached"]), level.display_name]
	if next:
		outcome += "  Next up: World %d, %s." % [GameData.worlds().find(next.world) + 1, next.world.display_name]
	var sub := UiKit.label(outcome, 30, UiKit.CREAM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(sub)

	# Score: big number that counts up, with NEW BEST and a breakdown.
	var score_box := VBoxContainer.new()
	score_box.add_theme_constant_override("separation", -6)
	col.add_child(score_box)
	var score_caption := UiKit.label("SCORE", 26, UiKit.CYAN, true)
	score_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_box.add_child(score_caption)
	var score_value := UiKit.arcade_label("0", 96, Color.WHITE)
	score_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_box.add_child(score_value)
	var final_score := int(result.get("score", 0))
	var counter := create_tween()
	counter.tween_method(func(v: float): score_value.text = ScorePanel._fmt(int(v)), 0.0, float(final_score), 1.2).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if bool(result.get("new_best", false)) and final_score > 0:
		var best := UiKit.arcade_label("NEW BEST!", 38, UiKit.AMBER)
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_box.add_child(best)
		best.pivot_offset = Vector2(260, 24)
		var pop := best.create_tween().set_loops()
		pop.tween_property(best, "scale", Vector2.ONE * 1.08, 0.4)
		pop.tween_property(best, "scale", Vector2.ONE, 0.4)
	else:
		var best_line := UiKit.label("Best: %s" % ScorePanel._fmt(int(result.get("best_score", 0))), 24, UiKit.CREAM)
		best_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_box.add_child(best_line)
	var bd: Dictionary = result.get("score_breakdown", {})
	if not bd.is_empty():
		var parts := []
		for key in [["kills", "Kills"], ["headshots", "Headshots"], ["combo", "Combo"], ["multi", "Multi-kills"], ["style", "Style"], ["waves", "Waves"], ["tickets", "Tickets cashed"]]:
			if int(bd.get(key[0], 0)) > 0:
				parts.append("%s %s" % [key[1], ScorePanel._fmt(int(bd[key[0]]))])
		var line := UiKit.label("  ·  ".join(parts), 22, Color(1, 1, 1, 0.75))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(line)

	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 14)
	col.add_child(stats)
	stats.add_child(_stat("WAVES", "%d / %d" % [int(result["waves_cleared"]), int(result["total_waves"])]))
	stats.add_child(_stat("KILLS", str(int(result["kills"]))))
	stats.add_child(_stat("HEADSHOTS", str(int(result.get("headshots", 0)))))
	stats.add_child(_stat("BEST COMBO", "x%d" % int(result.get("best_combo", 0))))
	var secs := int(result["seconds"])
	stats.add_child(_stat("TIME", "%d:%02d" % [secs / 60, secs % 60]))

	col.add_child(UiKit.spacer(8))
	col.add_child(UiKit.label("WEAPON MASTERY", 34, UiKit.AMBER, true))
	var rows: Array = result["weapons"]
	if rows.is_empty():
		col.add_child(UiKit.label("No mastery earned this run. Land a finishing blow to earn XP.", 26, Color(1, 1, 1, 0.75)))
	var rows_box := VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 8)
	for row in rows:
		rows_box.add_child(_weapon_row(row))
	# Fixed height, scrolling: weapons and unlock lines never push the buttons
	# off screen.
	var rs := ScrollContainer.new()
	rs.custom_minimum_size = Vector2(0, 160)
	rs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rs.add_child(rows_box)
	col.add_child(rs)

	outer.add_child(UiKit.spacer(4))
	outer.add_child(_buttons(next))

	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.35)


## NEXT WORLD (primary, when there is one), then RETRY and MAIN MENU.
func _buttons(next: LevelData) -> Control:
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 32)
	var retry := UiKit.soft_button("RETRY", 44) if next else UiKit.button("RETRY", 48)
	retry.custom_minimum_size = Vector2(320 if next else 380, 84)
	retry.pressed.connect(func(): Game.retry())
	var menu := UiKit.soft_button("MAIN MENU", 44) if next else UiKit.button("MAIN MENU", 48)
	menu.custom_minimum_size = Vector2(320 if next else 380, 84)
	menu.pressed.connect(func(): Game.to_menu())
	if next:
		var go := UiKit.button("NEXT WORLD", 52)
		go.name = "NextWorld"
		go.custom_minimum_size = Vector2(440, 84)
		go.pressed.connect(func(): Game.start_level(next.id, &""))
		buttons.add_child(go)
		go.grab_focus.call_deferred()
	else:
		retry.grab_focus.call_deferred()
	buttons.add_child(retry)
	buttons.add_child(menu)
	return buttons


## The level after `level` in world order, if the player has unlocked it.
static func next_level(level: LevelData) -> LevelData:
	var found := false
	for world in GameData.worlds():
		for l in world.levels:
			if found:
				return l if GameData.is_level_unlocked(l) else null
			found = l == level
	return null


func _stat(caption: String, value: String) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.7), Color.TRANSPARENT, 16, 0, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -8)
	box.add_child(v)
	box.custom_minimum_size = Vector2(168, 0)
	var c := UiKit.label(caption, 20, UiKit.CYAN, true)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	var val := UiKit.label(value, 42, Color.WHITE, true)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(val)
	return box


func _weapon_row(row: Dictionary) -> Control:
	var weapon: WeaponData = row["weapon"]
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.7), Color.TRANSPARENT, 16, 0, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	v.add_child(top)
	var name_label := UiKit.label(weapon.display_name, 34, Color.WHITE, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	top.add_child(UiKit.label("%d kills" % int(row["kills"]), 26, UiKit.CREAM))
	top.add_child(UiKit.label("+%d XP" % int(row["xp_gained"]), 34, UiKit.GREEN, true))

	var rank_before := int(row["rank_before"])
	var rank_after := int(row["rank_after"])
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 14)
	v.add_child(bar_row)
	var rank_text := UiKit.rank_name(rank_after, weapon.max_rank())
	if rank_after > rank_before:
		rank_text = "RANK UP!  %s" % rank_text
	var rank_label := UiKit.label(rank_text, 24, UiKit.AMBER if rank_after > rank_before else UiKit.CYAN, true)
	rank_label.custom_minimum_size = Vector2(250, 0)
	bar_row.add_child(rank_label)
	var xp_after := int(row["xp_after"])
	var ceiling := weapon.xp_ceiling(rank_after)
	var floor_xp := weapon.xp_floor(rank_after)
	var fraction := 1.0 if ceiling < 0 else float(xp_after - floor_xp) / float(maxi(1, ceiling - floor_xp))
	var bar := UiKit.progress(0.0, 20.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(bar)
	bar.create_tween().tween_property(bar, "value", fraction, 0.9).set_delay(0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var xp_text := "%d XP" % xp_after if ceiling < 0 else "%d / %d XP" % [xp_after, ceiling]
	var xp_label := UiKit.label(xp_text, 24, UiKit.CREAM)
	xp_label.custom_minimum_size = Vector2(210, 0)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bar_row.add_child(xp_label)

	var unlocks: Array = row["unlocks"]
	for i in mini(unlocks.size(), 2):
		var reward: CosmeticItem = unlocks[i]
		v.add_child(UiKit.label("UNLOCKED  %s  (%s)" % [reward.display_name, reward.slot_label()], 26, UiKit.AMBER, true))
	if unlocks.size() > 2:
		v.add_child(UiKit.label("and %d more in the Locker" % (unlocks.size() - 2), 22, UiKit.AMBER))
	return box
