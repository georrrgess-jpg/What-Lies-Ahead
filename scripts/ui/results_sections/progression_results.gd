class_name ProgressionResultsSection
extends PanelContainer
## Results-screen section (data/ui/results_progression.tres): the account XP
## bar filling up (with a flash and fanfare for every level gained), the XP
## breakdown, mastery bonuses, challenges completed this run and new rewards.
##
## It sits in the results screen's scrolling side column, above the player card.

const WIDTH := 344.0
const FILL_TIME := 2.4
const MAX_REWARDS := 6

var _summary: Dictionary
var _emblem: LevelEmblem
var _level_label: Label
var _gain_label: Label
var _flash_label: Label
var _bar: ProgressBar
var _xp_label: Label
var _next_label: Label
var _shown_level := 1
var _tick := 0.0
var _reveal := 0


## Settles the run if that has not happened yet (Progression.settle is idempotent).
static func build(result: Dictionary) -> Control:
	var summary := Progression.settle(result)
	if summary.is_empty():
		return null
	var section := ProgressionResultsSection.new()
	section._summary = summary
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return section


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.95), UiKit.AMBER, 26, 4, 20))


func _ready() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	_build_level(col)
	_build_breakdown(col)
	_build_challenges(col)
	_build_rewards(col)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_method(_show_xp, float(_summary["xp_before"]), float(_summary["xp_after"]), FILL_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_tick = maxf(0.0, _tick - delta)


# --- level and XP bar ---------------------------------------------------------

func _build_level(col: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := UiKit.label("CAREER", 34, UiKit.AMBER, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var tag := UiKit.label("ACCOUNT XP", 18, UiKit.CYAN, true)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	_shown_level = int(_summary["level_before"])
	_emblem = LevelEmblem.new(_shown_level, 84.0)
	row.add_child(_emblem)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	_level_label = UiKit.arcade_label("LEVEL %d" % _shown_level, 40, Color.WHITE)
	v.add_child(_level_label)
	_gain_label = UiKit.arcade_label("+0 XP", 30, ProgStyle.XP_COLOR)
	v.add_child(_gain_label)
	_flash_label = UiKit.arcade_label("", 26, UiKit.AMBER)
	_flash_label.custom_minimum_size = Vector2(0, 30)
	v.add_child(_flash_label)
	_bar = ProgStyle.bar(18.0, ProgStyle.XP_COLOR)
	_bar.value = Progression.progress_for_xp(int(_summary["xp_before"]))
	col.add_child(_bar)
	_xp_label = UiKit.label("", 18, UiKit.CREAM)
	col.add_child(_xp_label)
	_next_label = UiKit.label("", 18, Color(1, 1, 1, 0.7))
	_next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_next_label)
	_show_level_texts(int(_summary["xp_before"]))


func _show_xp(value: float) -> void:
	var xp := int(value)
	_bar.value = Progression.progress_for_xp(xp)
	_gain_label.text = "+%s XP" % ProgStyle.num(xp - int(_summary["xp_before"]))
	var lvl := Progression.level_for_xp(xp)
	if lvl > _shown_level:
		_shown_level = lvl
		_on_level_reached(lvl)
	_show_level_texts(xp)
	if _tick <= 0.0 and xp < int(_summary["xp_after"]):
		_tick = 0.075
		Sfx.play(&"prog_xp_tick", -14.0, 0.85 + 0.6 * _bar.value)


func _show_level_texts(xp: int) -> void:
	var lvl := Progression.level_for_xp(xp)
	if lvl >= Progression.MAX_LEVEL:
		_xp_label.text = "%s XP  ·  max level" % ProgStyle.num(xp)
		_next_label.text = ""
		return
	_xp_label.text = "%s / %s XP" % [ProgStyle.num(xp - Progression.xp_for_level(lvl)), ProgStyle.num(Progression.xp_for_level(lvl + 1) - Progression.xp_for_level(lvl))]
	_next_label.text = "Level %d: %s" % [lvl + 1, Progression.reward_text(lvl + 1)]


func _on_level_reached(lvl: int) -> void:
	_emblem.level = lvl
	_emblem.flash = 1.0
	_level_label.text = "LEVEL %d" % lvl
	_flash_label.text = "LEVEL UP!" if lvl == int(_summary["level_before"]) + 1 else "LEVEL UP! x%d" % (lvl - int(_summary["level_before"]))
	_flash_label.pivot_offset = Vector2(0.0, 15.0)
	_flash_label.scale = Vector2.ONE * 1.5
	_flash_label.create_tween().tween_property(_flash_label, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(&"prog_level_up", -4.0)


# --- breakdown ---------------------------------------------------------------------

func _build_breakdown(col: VBoxContainer) -> void:
	var lines: Array = _summary["lines"]
	if lines.is_empty():
		col.add_child(UiKit.label("No XP this run.", 22, Color(1, 1, 1, 0.6)))
	for line in lines:
		col.add_child(_reveal_in(_line(line[0], "+%s" % ProgStyle.num(int(line[1])), Color.WHITE)))
	var bonus: Dictionary = _summary["mastery_bonus"]
	if bonus.is_empty():
		return
	col.add_child(_caption("MASTERY BONUSES"))
	for weapon_id in bonus:
		var w := GameData.weapon(weapon_id)
		var parts: Dictionary = bonus[weapon_id]
		var total := 0
		for k in parts:
			total += int(parts[k])
		var detail := ", ".join(parts.keys())
		var name := w.display_name if w else String(weapon_id)
		col.add_child(_reveal_in(_line("%s (%s)" % [name, detail.to_lower()], "+%s" % ProgStyle.num(total), UiKit.CREAM, 19)))


# --- challenges and rewards ----------------------------------------------------------

func _build_challenges(col: VBoxContainer) -> void:
	var done: Array = _summary["challenges"]
	if done.is_empty():
		return
	col.add_child(_caption("CHALLENGES COMPLETE  ·  %d" % done.size()))
	for i in mini(done.size(), 5):
		var ch: Challenge = done[i][0]
		var w := GameData.weapon(done[i][1])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := ProgToasts.check_icon(24.0, UiKit.GREEN)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var name := UiKit.label(ch.display_name + ("  ·  " + w.display_name if w else ""), 20, Color.WHITE, true)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.custom_minimum_size = Vector2(150, 0)
		row.add_child(name)
		row.add_child(UiKit.label("+%s" % ProgStyle.num(ch.xp), 20, UiKit.AMBER, true))
		col.add_child(_reveal_in(row))
	if done.size() > 5:
		col.add_child(UiKit.label("and %d more" % (done.size() - 5), 18, Color(1, 1, 1, 0.6)))


func _build_rewards(col: VBoxContainer) -> void:
	var rewards: Array = _unique_rewards()
	if rewards.is_empty():
		return
	col.add_child(_caption("NEW REWARDS  ·  %d" % rewards.size()))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	for i in mini(rewards.size(), MAX_REWARDS):
		var item: CosmeticItem = rewards[i][0]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 0)
		cell.add_child(RewardArt.new(item, false, Vector2(96, 58)))
		var name := UiKit.label(item.display_name, 15, Color.WHITE, true)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.custom_minimum_size = Vector2(96, 0)
		cell.add_child(name)
		grid.add_child(_reveal_in(cell))
	if rewards.size() > MAX_REWARDS:
		col.add_child(UiKit.label("and %d more in the Career page" % (rewards.size() - MAX_REWARDS), 18, Color(1, 1, 1, 0.6)))


## One entry per item (a camo unlocked on two weapons is listed once).
func _unique_rewards() -> Array:
	var seen := {}
	var out: Array = []
	for pair in _summary["rewards"]:
		var item: CosmeticItem = pair[0]
		if not seen.has(item.id):
			seen[item.id] = true
			out.append(pair)
	return out


# --- helpers -----------------------------------------------------------------------

func _caption(text: String) -> Label:
	var l := UiKit.label(text, 20, UiKit.CYAN, true)
	return _reveal_in(l)


func _line(label: String, value: String, color: Color, font_size := 22) -> Control:
	var row := HBoxContainer.new()
	var l := UiKit.label(label, font_size, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	row.add_child(UiKit.label(value, font_size, ProgStyle.XP_COLOR, true))
	return row


## Staggered fade-in, in build order.
func _reveal_in(c: Control) -> Control:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(0.45 + _reveal * 0.09)
	tw.tween_property(c, "modulate:a", 1.0, 0.25)
	_reveal += 1
	return c
