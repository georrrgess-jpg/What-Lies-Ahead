class_name ScorePanel
extends VBoxContainer
## Top-right score readout: rolling score counter, combo meter that drains,
## and a feed of awards ("HEADSHOT +50", "TRIPLE KILL +300").

const FEED_MAX := 4

var _score: Label
var _combo_row: HBoxContainer
var _combo: Label
var _combo_bar: ProgressBar
var _feed: VBoxContainer
var _shown := 0.0
var _target := 0
var _keeper: ScoreKeeper
var _pulse := 0.0


func bind(keeper: ScoreKeeper) -> void:
	_keeper = keeper
	keeper.score_changed.connect(_on_score)
	keeper.combo_changed.connect(_on_combo)
	keeper.award.connect(_on_award)


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score = UiKit.arcade_label("0", 58, Color.WHITE)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_score)
	_combo_row = HBoxContainer.new()
	_combo_row.alignment = BoxContainer.ALIGNMENT_END
	_combo_row.add_theme_constant_override("separation", 10)
	add_child(_combo_row)
	_combo_bar = UiKit.progress(0.0, 10.0, UiKit.PINK)
	_combo_bar.custom_minimum_size = Vector2(150, 10)
	_combo_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_combo_row.add_child(_combo_bar)
	_combo = UiKit.arcade_label("", 32, UiKit.PINK_LIGHT)
	_combo_row.add_child(_combo)
	_combo_row.modulate.a = 0.0
	_feed = VBoxContainer.new()
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed.add_theme_constant_override("separation", -6)
	add_child(_feed)


func _process(delta: float) -> void:
	# Rolling counter.
	if _shown < _target:
		_shown = minf(_target, _shown + maxf(40.0, (_target - _shown) * 9.0) * delta)
		_score.text = _fmt(int(_shown))
	_pulse = maxf(0.0, _pulse - delta * 4.0)
	_score.scale = Vector2.ONE * (1.0 + 0.12 * _pulse)
	_score.pivot_offset = _score.size * Vector2(1.0, 0.5)
	if _keeper and _keeper.combo > 1:
		_combo_bar.value = clampf(_keeper.combo_time_left() / ScoreKeeper.COMBO_WINDOW, 0.0, 1.0)


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


func _on_combo(combo: int, mult: float, _left: float) -> void:
	if combo <= 1:
		var tw := create_tween()
		tw.tween_property(_combo_row, "modulate:a", 0.0, 0.25)
		return
	_combo.text = "x%.1f  COMBO %d" % [mult, combo]
	_combo_row.modulate.a = 1.0
	_combo.pivot_offset = _combo.size * 0.5
	_combo.scale = Vector2.ONE * 1.3
	create_tween().tween_property(_combo, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_award(text: String, points: int, color: Color) -> void:
	var l := UiKit.arcade_label("%s  +%d" % [text, points] if points > 0 else text, 28, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_feed.add_child(l)
	_feed.move_child(l, 0)
	while _feed.get_child_count() > FEED_MAX:
		var old := _feed.get_child(_feed.get_child_count() - 1)
		_feed.remove_child(old)
		old.queue_free()
	l.modulate.a = 0.0
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.1)
	tw.tween_interval(1.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
