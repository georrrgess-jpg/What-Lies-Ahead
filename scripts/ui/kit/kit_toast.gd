class_name KitToast
extends CanvasLayer
## Toasts: short messages that pop in under the top bar, stack, and leave by
## themselves. One shared layer above every screen (it works while paused).
##
##   UiKit.toast("Loadout saved")
##   UiKit.toast("Not enough Sparks", UiKit.RED)
##   UiKit.toast("450 Sparks banked", Wallet.COLOR, &"icon_spark")

const MAX_WIDTH := 760.0
const TOP := 108.0

static var _layer: KitToast

var _stack: VBoxContainer


## Shows a toast (see UiKit.toast).
static func show_toast(text: String, accent: Color, icon_name: StringName, seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if not is_instance_valid(_layer):
		_layer = KitToast.new()
		tree.root.add_child.call_deferred(_layer)
	_layer._push.call_deferred(text, accent, icon_name, seconds)


func _init() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	UiKit.apply(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_stack = VBoxContainer.new()
	_stack.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stack.offset_top = TOP
	_stack.add_theme_constant_override("separation", UiKit.GAP_S)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stack)


func _push(text: String, accent: Color, icon_name: StringName, seconds: float) -> void:
	var panel := UiKit.neon_panel(accent)
	panel.set_padding(26, 12)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_M)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	if icon_name != &"":
		row.add_child(UiKit.icon(icon_name, 40.0))
	var label := UiKit.label(text, UiKit.SIZE_BODY, UiKit.CREAM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if UiKit.body_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_BODY).x > MAX_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = MAX_WIDTH
	row.add_child(label)
	_stack.add_child(panel)
	UiSound.toast()
	var tw := UiFx.pop_in(panel)
	tw.chain().tween_interval(seconds)
	tw.chain().tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(panel.queue_free)
