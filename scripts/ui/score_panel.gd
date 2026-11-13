class_name ScorePanel
extends VBoxContainer
## Top-right score readout: the run score rolling up, the combo (multiplier
## chip, chain length and a bar that drains and turns amber, then red, as the
## chain is about to break) and a feed of awards ("HEADSHOT +50"); multi-kills
## land bigger. `extras` is the place under the combo where the HUD stacks
## small extension widgets.
##
## The panel only processes while a number is rolling or a combo is running,
## and the feed reuses its labels, so kills allocate no nodes.

const FEED_MAX := 4
## Share of the combo window under which the bar turns amber / red.
const HURRY := 0.4
const LAST_CHANCE := 0.18

## Extension widgets of the HUD's "right" slot go in here.
var extras: VBoxContainer

var _score: Label
var _combo_row: HBoxContainer
var _combo: Label
var _mult: KitChip
var _combo_bar: ProgressBar
var _fills: Array[StyleBoxFlat] = []
var _fill_index := -1
var _feed: VBoxContainer
var _feed_labels: Array[Label] = []
var _feed_tweens: Array[Tween] = []
var _feed_next := 0
var _shown := 0.0
var _target := 0
var _keeper: ScoreKeeper
var _pulse := 0.0
var _combo_tween: Tween


func bind(keeper: ScoreKeeper) -> void:
	_keeper = keeper
	keeper.score_changed.connect(_on_score)
	keeper.combo_changed.connect(_on_combo)
	keeper.award.connect(_on_award)


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_END
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	var caption := UiKit.arcade_label("SCORE", 24, UiKit.CYAN)
	caption.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(caption)
	_score = UiKit.arcade_label("0", 64, Color.WHITE)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_score)
	_build_combo()
	extras = VBoxContainer.new()
	extras.add_theme_constant_override("separation", 6)
	extras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(extras)
	_feed = VBoxContainer.new()
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed.add_theme_constant_override("separation", -8)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)
	for i in FEED_MAX:
		var l := UiKit.arcade_label("", 28)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.visible = false
		_feed.add_child(l)
		_feed_labels.append(l)
		_feed_tweens.append(null)
	set_process(false)


func _build_combo() -> void:
	_combo_row = HBoxContainer.new()
	_combo_row.alignment = BoxContainer.ALIGNMENT_END
	_combo_row.add_theme_constant_override("separation", 10)
	_combo_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_row.custom_minimum_size.y = 44
	_combo_row.modulate.a = 0.0
	add_child(_combo_row)
	_combo_bar = UiKit.progress(0.0, 12.0, UiKit.PINK)
	_combo_bar.custom_minimum_size = Vector2(170, 12)
	_combo_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_combo_row.add_child(_combo_bar)
	for color in [UiKit.PINK, UiKit.AMBER, UiKit.RED]:
		_fills.append(UiKit.bar_fill(color, 12.0))
	_combo = UiKit.arcade_label("", 30, UiKit.PINK_LIGHT)
	_combo_row.add_child(_combo)
	_mult = UiKit.chip("x1.0", UiKit.PINK, 26)
	_combo_row.add_child(_mult)


func _process(delta: float) -> void:
	var busy := false
	if _shown < _target:
		_shown = minf(_target, _shown + maxf(40.0, (_target - _shown) * 9.0) * delta)
		_score.text = _fmt(int(_shown))
		busy = true
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 4.0)
		_score.pivot_offset = _score.size * Vector2(1.0, 0.5)
		_score.scale = Vector2.ONE * (1.0 + 0.12 * _pulse)
		busy = true
	if _keeper and _keeper.combo > 1:
		var left := clampf(_keeper.combo_time_left() / ScoreKeeper.COMBO_WINDOW, 0.0, 1.0)
		_combo_bar.value = left
		_set_fill(2 if left < LAST_CHANCE else (1 if left < HURRY else 0))
		busy = true
	if not busy:
		set_process(false)


## The bar's colour: 0 pink, 1 amber (hurry), 2 red (about to break).
func _set_fill(index: int) -> void:
	if index == _fill_index:
		return
	_fill_index = index
	_combo_bar.add_theme_stylebox_override("fill", _fills[index])


## Thousands separators: 12345 -> "12,345".
static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _on_score(total: int, _gained: int) -> void:
	_target = total
	_pulse = 1.0
	set_process(true)


func _on_combo(combo: int, mult: float, _left: float) -> void:
	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	if combo <= 1:
		_combo_tween = create_tween()
		_combo_tween.tween_property(_combo_row, "modulate:a", 0.0, 0.25)
		return
	_combo.text = "COMBO %d" % combo
	_mult.set_text("x%.1f" % mult)
	_combo_row.modulate.a = 1.0
	_mult.pivot_offset = _mult.size * 0.5
	_mult.scale = Vector2.ONE * 1.35
	_combo_tween = create_tween()
	_combo_tween.tween_property(_mult, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	set_process(true)


## Awards reuse the feed's labels; the newest is always on top.
func _on_award(text: String, points: int, color: Color) -> void:
	var slot := _feed_next
	_feed_next = (_feed_next + 1) % FEED_MAX
	var l := _feed_labels[slot]
	var old := _feed_tweens[slot]
	if old and old.is_valid():
		old.kill()
	var big := ScoreKeeper.MULTI_NAMES.has(text)
	l.text = "%s  +%d" % [text, points] if points > 0 else text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 40 if big else 28)
	l.visible = true
	_feed.move_child(l, 0)
	l.modulate.a = 0.0
	l.pivot_offset = Vector2(l.size.x, l.size.y * 0.5)
	l.scale = Vector2.ONE * (1.5 if big else 1.15)
	var tw := l.create_tween()
	_feed_tweens[slot] = tw
	tw.tween_property(l, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(l, "scale", Vector2.ONE, 0.22 if big else 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4 if big else 1.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): l.visible = false)
