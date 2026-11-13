class_name TutorialHud
extends CanvasLayer
## Boot Camp's own HUD layer, over the normal HUD (which keeps health, ammo,
## score and the station panel):
##   - the objective card, upper left: section, the step's objective and keys,
##     and the section's checklist;
##   - BOLT's speech bubble, bottom centre, typed out with a blip per word;
##   - the hold-to-skip prompt under the card at the start of each section;
##   - the graduation card at the end, with DEPLOY TO PRIZE PIER.

const CARD_WIDTH := 560.0
const SKIP_PROMPT_SECONDS := 9.0

var course: TutorialCourse

var _root: Control
var _card: KitPanel
var _section_chip: KitChip
var _section: Label
var _title: Label
var _objective: Label
var _keys: HFlowContainer
var _list: VBoxContainer
var _rows: Array[Control] = []
var _station_row: HBoxContainer
var _skip: HBoxContainer
var _skip_bar: ProgressBar
var _skip_time := 0.0
var _guide: KitPanel
var _portrait: GuidePortrait
var _speech: Label
var _queue: Array[String] = []
var _line_tween: Tween
var _line_left := 0.0
var _blip_chars := 0


func _ready() -> void:
	layer = 6
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.apply(_root)
	add_child(_root)
	_build_card()
	_build_skip()
	_build_guide()


func bind(c: TutorialCourse) -> void:
	course = c


# --- construction ---------------------------------------------------------------------

func _build_card() -> void:
	_card = UiKit.signboard()
	_card.set_padding(26, 20)
	_card.custom_minimum_size.x = CARD_WIDTH
	_card.position = Vector2(UiKit.PAGE_MARGIN, 36)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_M)
	col.add_child(head)
	_section_chip = UiKit.chip("BOOT CAMP", UiKit.PINK, 20)
	head.add_child(_section_chip)
	_section = UiKit.label("", UiKit.SIZE_LABEL, UiKit.CYAN, true)
	head.add_child(_section)
	_title = UiKit.sign_label("", 44)
	col.add_child(_title)
	_objective = UiKit.body("", CARD_WIDTH - 60, UiKit.SIZE_BODY, UiKit.CREAM)
	col.add_child(_objective)
	_keys = HFlowContainer.new()
	_keys.add_theme_constant_override("h_separation", UiKit.GAP_M)
	_keys.add_theme_constant_override("v_separation", UiKit.GAP_XS)
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_keys)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	col.add_child(_list)


func _build_skip() -> void:
	_skip = HBoxContainer.new()
	_skip.add_theme_constant_override("separation", UiKit.GAP_S)
	_skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_skip)
	_skip.add_child(KeyGlyph.make("ENTER", 40.0))
	var l := UiKit.arcade_label("HOLD TO SKIP THIS SECTION", 24, UiKit.CREAM)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skip.add_child(l)
	_skip_bar = UiKit.progress(0.0, 10.0, UiKit.PINK)
	_skip_bar.custom_minimum_size = Vector2(110, 10)
	_skip_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skip.add_child(_skip_bar)
	_skip.modulate.a = 0.0


func _build_guide() -> void:
	_guide = UiKit.neon_panel(UiKit.PINK)
	_guide.set_padding(20, 12)
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_guide)
	_guide.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_guide.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_guide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_guide.offset_top = -36
	_guide.offset_bottom = -36
	_guide.offset_left = 0
	_guide.offset_right = 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide.add_child(row)
	_portrait = GuidePortrait.new()
	_portrait.custom_minimum_size = Vector2(104, 112)
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(name_row)
	name_row.add_child(UiKit.label(TutorialScript.GUIDE_NAME, UiKit.SIZE_LABEL, UiKit.PINK_LIGHT, true))
	name_row.add_child(UiKit.label(TutorialScript.GUIDE_ROLE, UiKit.SIZE_SMALL, UiKit.MUTED))
	_speech = UiKit.body("", 660, 28, Color.WHITE)
	_speech.custom_minimum_size.y = 76
	_speech.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col.add_child(_speech)
	_station_row = HBoxContainer.new()
	_station_row.add_theme_constant_override("separation", UiKit.GAP_S)
	_station_row.visible = false
	col.add_child(_station_row)
	_guide.modulate.a = 0.0


# --- steps ----------------------------------------------------------------------------

## Shows step `i`; `new_section` rebuilds the checklist and shows the skip prompt.
func show_step(i: int, new_section: bool) -> void:
	var s := TutorialCourse.step(i)
	var section := int(s["section"])
	if new_section or _rows.is_empty():
		_build_list(section)
		_skip_time = SKIP_PROMPT_SECONDS
		Sfx.play(&"onb_section", -5.0)
	var first := 0
	var count := 0
	for k in course.step_count():
		if TutorialCourse.step(k)["section"] == section:
			if count == 0:
				first = k
			count += 1
	_section.text = "%s  ·  %d / %d" % [TutorialScript.SECTIONS[section], i - first + 1, count]
	_title.text = String(s["title"]).to_upper()
	_objective.text = s["objective"]
	for c in _keys.get_children():
		c.queue_free()
	for k in s["keys"]:
		_keys.add_child(KeyGlyph.prompt(_key_name(k[0]), k[1]))
	for r in _rows.size():
		_style_row(r, first + r, i)
	# At the station the HUD's own station panel takes the left side: the
	# card steps aside and the purchase ticks ride on BOLT's bubble.
	_card.visible = String(s["id"]) != "station"
	_list.visible = String(s["id"]) != "portal"
	_station_row.visible = String(s["id"]) == "station"
	_card.pivot_offset = Vector2(0, 0)
	UiFx.pulse(_title, 1.08)


func _build_list(section: int) -> void:
	for c in _list.get_children():
		c.queue_free()
	_rows.clear()
	_list.add_child(UiKit.spacer(UiKit.GAP_XS))
	for k in course.step_count():
		var s := TutorialCourse.step(k)
		if int(s["section"]) != section:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UiKit.GAP_S)
		var mark := UiKit.icon(&"icon_check", 26.0)
		mark.name = "Mark"
		row.add_child(mark)
		var l := UiKit.label(String(s["title"]), UiKit.SIZE_BODY, UiKit.MUTED)
		l.name = "Text"
		row.add_child(l)
		_list.add_child(row)
		_rows.append(row)


func _style_row(r: int, step_index: int, current: int) -> void:
	var row := _rows[r]
	var done := course.completed.has(String(TutorialCourse.step(step_index)["id"]))
	var mark := row.get_node("Mark") as TextureRect
	var text := row.get_node("Text") as Label
	mark.modulate = UiKit.GREEN if done else (Color(1, 1, 1, 0.0) if step_index != current else Color(UiKit.CYAN, 0.5))
	text.add_theme_color_override("font_color", UiKit.CREAM if step_index == current else (UiKit.GREEN if done else UiKit.MUTED))


## The step was completed: tick its row.
func tick(step_index: int) -> void:
	var section := int(TutorialCourse.step(step_index)["section"])
	var r := 0
	for k in step_index:
		if int(TutorialCourse.step(k)["section"]) == section:
			r += 1
	if r < _rows.size():
		var mark := _rows[r].get_node("Mark") as TextureRect
		mark.modulate = UiKit.GREEN
		UiFx.pulse(mark, 1.5)


## The four station purchases as ticks: energy, snack, overshield, swap.
func show_station(parts: Array[bool]) -> void:
	var names := ["ENERGY", "SNACK", "SHIELD", "SWAP"]
	if _station_row.get_child_count() == 0:
		for n in names:
			_station_row.add_child(UiKit.chip(n, UiKit.MUTED, 18, false))
	for k in names.size():
		var chip := _station_row.get_child(k) as KitChip
		chip.set_color(UiKit.GREEN if parts[k] else Color(UiKit.MUTED, 0.7))


func _key_name(token: String) -> String:
	match token:
		"WASD", "MOUSE", "LMB", "RMB", "WHEEL":
			return token
	return Loadout.key_hint(StringName(token)).get_slice(" / ", 0).to_upper()


# --- skip prompt ----------------------------------------------------------------------

func set_skip_progress(fraction: float) -> void:
	_skip_bar.value = fraction
	if fraction > 0.0:
		_skip_time = maxf(_skip_time, 1.0)


func _process(delta: float) -> void:
	_skip_time = maxf(0.0, _skip_time - delta)
	_skip.modulate.a = clampf(_skip_time, 0.0, 1.0)
	_skip.position = _card.position + Vector2(8, (_card.size.y if _card.visible else 0.0) + UiKit.GAP_S)
	_tick_speech(delta)


# --- the guide ------------------------------------------------------------------------

## Queues lines for BOLT; `interrupt` replaces whatever he was saying.
func say(lines: Array, interrupt := false) -> void:
	if interrupt:
		_queue.clear()
		_line_left = 0.0
	for l in lines:
		_queue.append(String(l))
	if _line_left <= 0.0:
		_next_line()


func _next_line() -> void:
	if _queue.is_empty():
		_portrait.talking = false
		var tw := _guide.create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(_guide, "modulate:a", 0.35, 0.6)
		return
	var line: String = _queue.pop_front()
	_speech.text = line
	_speech.visible_ratio = 0.0
	_blip_chars = 0
	_guide.modulate.a = 1.0
	_portrait.talking = true
	if _line_tween and _line_tween.is_valid():
		_line_tween.kill()
	var type_time := line.length() * 0.028
	_line_tween = create_tween()
	_line_tween.tween_property(_speech, "visible_ratio", 1.0, type_time)
	_line_tween.tween_callback(func(): _portrait.talking = false)
	_line_left = type_time + 1.6 + line.length() * 0.03


func _tick_speech(delta: float) -> void:
	if _line_left <= 0.0:
		return
	var shown := _speech.visible_characters
	if _speech.visible_ratio < 1.0 and shown >= _blip_chars + 4:
		_blip_chars = shown
		Sfx.play(&"onb_blip", -12.0, randf_range(0.92, 1.12))
	_line_left -= delta
	if _line_left <= 0.0:
		_next_line()


## The line BOLT is saying now ("" when quiet). For tests and screenshots.
func current_line() -> String:
	return _speech.text if _line_left > 0.0 else ""


# --- the end --------------------------------------------------------------------------

## The graduation card: time, score, the reward (or that it was paid before)
## and the two ways out.
func show_finale(paid: Dictionary) -> void:
	_card.visible = false
	_skip.visible = false
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var board := UiKit.signboard()
	board.set_padding(48, 36)
	center.add_child(board)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	board.add_child(col)
	var sign := UiKit.marquee("BOOT CAMP COMPLETE", 64)
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(sign)
	var seconds := int(paid.get("seconds", 0.0))
	var stats := UiKit.label("%d:%02d on the course  ·  %s points" % [seconds / 60, seconds % 60, Wallet.format(int(paid.get("score", 0)))], UiKit.SIZE_LABEL, UiKit.CREAM)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(stats)
	col.add_child(_reward_row(paid))
	var line := UiKit.body(TutorialScript.LINE_DONE, 760, UiKit.SIZE_BODY, UiKit.MUTED)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(line)
	col.add_child(UiKit.spacer(UiKit.GAP_S))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", UiKit.GAP_L)
	col.add_child(buttons)
	var deploy := UiKit.sign_button("DEPLOY TO PRIZE PIER", SignButton.Kind.PRIMARY, 40)
	deploy.name = "DeployButton"
	deploy.pressed.connect(_deploy)
	buttons.add_child(deploy)
	var menu := UiKit.sign_button("MAIN MENU", SignButton.Kind.SECONDARY, 32)
	menu.name = "MenuButton"
	menu.pressed.connect(func(): Game.to_menu())
	buttons.add_child(menu)
	UiFx.pop_in(board)
	sign.flash()
	deploy.grab_focus.call_deferred()
	say([TutorialScript.LINE_DONE], true)


func _reward_row(paid: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	var sparks := int(paid.get("sparks", 0))
	if sparks <= 0:
		var note := "Finish live fire to earn the graduation bonus" if paid.get("unearned", false) else "Reward already collected  ·  replay any time"
		row.add_child(UiKit.label(note, UiKit.SIZE_LABEL, UiKit.MUTED))
		return row
	var plate := UiKit.card_panel(16)
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", UiKit.GAP_S)
	plate.add_child(inner)
	inner.add_child(UiKit.label("GRADUATION BONUS", UiKit.SIZE_LABEL, UiKit.AMBER, true))
	inner.add_child(UiKit.price_tag(sparks, 34))
	row.add_child(plate)
	var item: CosmeticItem = paid.get("item")
	if item:
		var tag := UiKit.card_panel(16)
		var t := HBoxContainer.new()
		t.add_theme_constant_override("separation", UiKit.GAP_S)
		tag.add_child(t)
		t.add_child(UiKit.label("%s:" % item.slot_label().to_upper(), UiKit.SIZE_LABEL, UiKit.CYAN, true))
		t.add_child(UiKit.label(item.display_name, 30, Color.WHITE, true))
		row.add_child(tag)
	return row


func _deploy() -> void:
	Onboarding.set_guide_step("done")
	Game.start_level(&"prize_pier", Loadout.primary())
