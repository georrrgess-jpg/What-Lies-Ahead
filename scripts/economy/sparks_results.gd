class_name SparksResultsSection
extends PanelContainer
## Results-screen section (data/ui/results_sparks.tres): the Sparks this run
## earned counting up, where they came from, the wallet balance, and the
## three contracts: the ones just completed, how far the others are, and the
## new ones dealt for the next run.

const COUNT_TIME := 1.6
const COLUMNS := 2

var _summary: Dictionary
var _run: Dictionary
var _total: Label
var _icon: SparkIcon
var _tick := 0.0
var _reveal := 0


## Settles the run's Sparks if that has not happened yet (Wallet.settle is idempotent).
static func build(result: Dictionary) -> Control:
	var summary := Wallet.settle(result)
	if summary.is_empty():
		return null
	var section := SparksResultsSection.new()
	section._summary = summary
	section._run = Progression.settle(result)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return section


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.95), Wallet.COLOR, 26, 4, 20))


func _ready() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	_build_total(col)
	_build_breakdown(col)
	_build_contracts(col)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_method(_show_total, 0.0, float(_summary["total"]), COUNT_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_tick = maxf(0.0, _tick - delta)


# --- total -----------------------------------------------------------------------

func _build_total(col: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	_icon = SparkIcon.new(64.0)
	head.add_child(_icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -8)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(names)
	names.add_child(UiKit.label("SPARKS EARNED", 30, Wallet.COLOR, true))
	names.add_child(UiKit.label("Wallet: %s  ·  spend them in the Shop" % Wallet.format(int(_summary["balance"])), 20, UiKit.CREAM))
	_total = UiKit.arcade_label("+0", 64, Wallet.COLOR)
	_total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_total)


func _show_total(value: float) -> void:
	_total.text = "+%s" % Wallet.format(int(value))
	if _tick <= 0.0 and int(value) < int(_summary["total"]):
		_tick = 0.07
		_icon.flash = 0.6
		Sfx.play(&"eco_spark_tick", -13.0, 1.0 + 0.9 * value / maxf(1.0, float(_summary["total"])))


# --- breakdown ---------------------------------------------------------------------

func _build_breakdown(col: VBoxContainer) -> void:
	var lines: Array = _summary["lines"]
	if lines.is_empty():
		col.add_child(UiKit.label("No Sparks this run. Pop a zombie to free its Spark.", 22, Color(1, 1, 1, 0.6)))
		return
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 0)
	col.add_child(grid)
	for line in lines:
		var label: String = line[0]
		if label == "Tickets cashed":
			label = "%s tickets cashed" % Wallet.format(int(_summary["tickets_cashed"]))
		grid.add_child(_reveal_in(_line(label, "+%s" % Wallet.format(int(line[1])))))


func _line(label: String, value: String) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UiKit.label(label, 21, Color.WHITE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(150, 0)
	row.add_child(l)
	row.add_child(UiKit.label(value, 21, Wallet.COLOR, true))
	return row


# --- contracts -------------------------------------------------------------------

func _build_contracts(col: VBoxContainer) -> void:
	var done: Array = _run.get("contracts", [])
	var fresh: Array = _run.get("new_contracts", [])
	var active := ContractBoard.active()
	if done.is_empty() and active.is_empty():
		return
	col.add_child(_reveal_in(UiKit.label("CONTRACTS", 20, Wallet.COLOR_GLOW, true)))
	for entry in done:
		col.add_child(_reveal_in(_contract_row(entry, "DONE")))
	for entry in active:
		col.add_child(_reveal_in(_contract_row(entry, "NEW" if fresh.has(entry) else "")))


func _contract_row(entry: Dictionary, tag: String) -> Control:
	var template := ContractBoard.template(entry)
	var done := tag == "DONE"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	if done:
		var check := ProgToasts.check_icon(24.0, UiKit.GREEN)
		check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(check)
	elif tag != "":
		row.add_child(UiKit.label(tag, 18, Wallet.COLOR_GLOW, true))
	var text := UiKit.label(ContractBoard.describe(entry), 21, UiKit.GREEN if done else Color.WHITE)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.custom_minimum_size = Vector2(200, 0)
	row.add_child(text)
	if not done:
		var bar := UiKit.progress(ContractBoard.fraction(entry), 8.0, Wallet.COLOR_GLOW)
		bar.custom_minimum_size = Vector2(120, 8)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var count := UiKit.label("%s / %s" % [Wallet.format(ContractBoard.progress(entry)), Wallet.format(ContractBoard.goal(entry))], 19, UiKit.CREAM, true)
		count.custom_minimum_size = Vector2(110, 0)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(count)
	var reward := HBoxContainer.new()
	reward.add_theme_constant_override("separation", 4)
	reward.custom_minimum_size = Vector2(86, 0)
	reward.alignment = BoxContainer.ALIGNMENT_END
	reward.modulate.a = 1.0 if done else 0.7
	reward.add_child(UiKit.label("+%d" % template.sparks if template else "", 20, Wallet.COLOR, true))
	reward.add_child(SparkIcon.new(22.0))
	row.add_child(reward)
	return row


## Staggered fade-in, in build order.
func _reveal_in(c: Control) -> Control:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_interval(0.35 + _reveal * 0.06)
	tw.tween_property(c, "modulate:a", 1.0, 0.2)
	_reveal += 1
	return c
