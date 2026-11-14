class_name PrizesResultsSection
extends PanelContainer
## Results-screen section (data/ui/results_prizes.tres): the Prize Capsules
## this run earned and why (alphas, bounties, the day's first clear,
## contracts, milestones), and how many are waiting on the Prizes page.
## Nothing is shown for a run that earned none.

var _summary: Dictionary


## Settles the run's capsules if that has not happened yet (PrizePrints.settle is idempotent).
static func build(result: Dictionary) -> Control:
	var summary := PrizePrints.settle(result)
	if int(summary.get("total", 0)) <= 0:
		return null
	var section := PrizesResultsSection.new()
	section._summary = summary
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return section


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.95), Color("9f8bff"), 26, 4, 18))


func _ready() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	add_child(row)
	var capsule := CapsuleIcon.new()
	capsule.custom_minimum_size = Vector2(64, 64)
	row.add_child(capsule)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var total := int(_summary["total"])
	col.add_child(UiKit.label("+%d PRIZE CAPSULE%s" % [total, "" if total == 1 else "S"], UiKit.SIZE_LABEL, UiKit.CREAM, true))
	var parts := PackedStringArray()
	for line in _summary["lines"]:
		parts.append("%s +%d" % [line[0], int(line[1])])
	col.add_child(UiKit.label("  ·  ".join(parts), UiKit.SIZE_SMALL, UiKit.MUTED))
	var waiting := UiKit.label("%d TO OPEN ON THE PRIZES PAGE" % int(_summary["capsules"]), UiKit.SIZE_SMALL, Color("9f8bff"), true)
	row.add_child(waiting)
	waiting.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): Sfx.play(&"prz_shake", -10.0))


## A small two-tone capsule.
class CapsuleIcon extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		draw_circle(c, r, UiKit.CREAM)
		var pts := PackedVector2Array()
		for k in 17:
			var a := PI + PI * k / 16.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color("9f8bff"))
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color("5a4aa8"), 2.0, true)
		draw_circle(c + Vector2(-r * 0.35, -r * 0.45), r * 0.16, Color(1, 1, 1, 0.7))
