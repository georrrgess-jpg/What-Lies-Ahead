class_name HintCard
extends CanvasLayer
## A small, non-blocking hint card: slides in at the upper right under the
## score, holds for a few seconds and slides out. Hints that arrive while one
## is showing wait their turn. Works while the game is paused.

const HOLD := 7.0
const WIDTH := 470.0

var _queue: Array = []
var _panel: KitPanel
var _title: Label
var _text: Label
var _busy := false


## Shows (or queues) a hint on top of `scene`.
static func show_hint(scene: Node, title: String, text: String) -> void:
	var card := scene.get_node_or_null("HintCard") as HintCard
	if card == null:
		card = HintCard.new()
		card.name = "HintCard"
		scene.add_child(card)
	card.push(title, text)


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.apply(root)
	add_child(root)
	_panel = UiKit.neon_panel(UiKit.CYAN)
	_panel.set_padding(22, 14)
	_panel.custom_minimum_size.x = WIDTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -UiKit.PAGE_MARGIN
	_panel.offset_right = -UiKit.PAGE_MARGIN
	_panel.offset_top = 236
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_XS)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(head)
	head.add_child(UiKit.chip("TIP", UiKit.CYAN, 18, false))
	_title = UiKit.label("", UiKit.SIZE_LABEL, UiKit.CREAM, true)
	head.add_child(_title)
	_text = UiKit.body("", WIDTH - 44, UiKit.SIZE_BODY, UiKit.CREAM)
	col.add_child(_text)
	_panel.modulate.a = 0.0


func push(title: String, text: String) -> void:
	_queue.append([title, text])
	if not _busy:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var entry: Array = _queue.pop_front()
	_title.text = String(entry[0])
	_text.text = String(entry[1])
	UiSound.toast()
	_panel.pivot_offset = Vector2(_panel.size.x, 0)
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2).from(0.0)
	tw.parallel().tween_property(_panel, "position:x", _panel.position.x, 0.25).from(_panel.position.x + 60.0) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(HOLD)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_next)


## The text showing now ("" when idle). For tests.
func current_text() -> String:
	return _text.text if _busy else ""
