class_name EndlessResultsSection
extends PanelContainer
## Results-screen section of an Endless run (data/ui/results_endless.tres),
## at the top of the side column: the wave reached ("WAVE 14 · NEW BEST"),
## the districts the run opened, the rewards it unlocked and the next one to
## chase. Nothing is shown for a story level.

const WIDTH := 344.0
const EMBER := Color(1.0, 0.48, 0.18)

var _result: Dictionary
var _wave: Label


static func build(result: Dictionary) -> Control:
	var endless: Dictionary = result.get("endless", {})
	var level: LevelData = result.get("level")
	if endless.is_empty() or level == null or not level.is_endless():
		return null
	var section := EndlessResultsSection.new()
	section._result = result
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return section


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.05, 0.06, 0.95), EMBER, 26, 4, 20))


func _ready() -> void:
	var level: LevelData = _result["level"]
	var endless: Dictionary = _result["endless"]
	var wave := int(_result["wave_reached"])
	var best := bool(endless.get("new_best_wave", false)) and int(endless.get("best_before", 0)) > 0
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	col.add_child(UiKit.label("ENDLESS  ·  %s" % level.display_name.to_upper(), 20, EMBER, true))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	_wave = UiKit.arcade_label("WAVE %d" % wave, 64, Color.WHITE)
	head.add_child(_wave)
	if best:
		var chip := UiKit.chip("NEW BEST", UiKit.AMBER, 22)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(chip)
	else:
		var note := UiKit.label("BEST %d" % maxi(wave, int(endless.get("best_before", 0))), 22, UiKit.MUTED, true)
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(note)
	_districts(col, level.endless, endless)
	_rewards(col, level.endless, endless, wave)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	if best:
		Sfx.play(&"end_new_best", -3.0)
		tw.tween_callback(func(): UiFx.pulse(_wave, 1.15))


func _districts(col: VBoxContainer, rules: EndlessRules, endless: Dictionary) -> void:
	col.add_child(UiKit.label("DISTRICTS  %d / %d" % [int(endless.get("districts_open", 1)), int(endless.get("districts_total", 1))], 20, UiKit.CREAM, true))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	col.add_child(flow)
	var opened: Array = endless.get("opened", [])
	for d in rules.districts:
		var open := d.price == 0 or String(d.id) in opened
		var chip := UiKit.chip(d.display_name.to_upper(), d.accent_color if open else UiKit.MUTED.darkened(0.3), 18, false)
		chip.modulate.a = 1.0 if open else 0.55
		flow.add_child(chip)


func _rewards(col: VBoxContainer, rules: EndlessRules, endless: Dictionary, wave: int) -> void:
	var earned := EndlessRewards.earned(rules, int(endless.get("best_before", 0)), wave, endless.get("first_opened", []))
	if not earned.is_empty():
		col.add_child(UiKit.label("UNLOCKED", 20, UiKit.AMBER, true))
		for e in earned:
			col.add_child(_reward_row(e, true))
	var next := EndlessRewards.next_goal(rules)
	if not next.is_empty():
		col.add_child(UiKit.label("NEXT REWARD", 20, UiKit.MUTED, true))
		col.add_child(_reward_row(next, false))


func _reward_row(e: Dictionary, earned: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 30)
	dot.color = e["color"]
	row.add_child(dot)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UiKit.label(String(e["name"]).to_upper(), 22, Color.WHITE if earned else UiKit.CREAM, true))
	v.add_child(UiKit.label("%s  ·  %s" % [e["kind"], e["goal"]], 18, (e["color"] as Color).lerp(Color.WHITE, 0.3) if earned else UiKit.MUTED))
	return row
