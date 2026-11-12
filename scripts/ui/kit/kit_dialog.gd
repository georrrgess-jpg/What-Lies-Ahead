class_name KitDialog
extends Control
## Modal dialog: dims the screen and asks a question on a signboard. Focus is
## kept inside it and starts on the safe answer; Esc (or the pause key)
## cancels. Works while the tree is paused.
##
##   UiKit.confirm(self, "LEAVE THE RUN?", "You go back to the main menu.", "LEAVE", _leave)
##   KitDialog.notice(self, "SAVED", "Your settings were saved.")

signal confirmed
signal cancelled

## How many dialogs are open (a screen can ignore its own shortcuts meanwhile).
static var open_count := 0

var _on_yes := Callable()
var _panel: KitPanel
var _dim: ColorRect
var _safe: Button
var _closing := false


## A yes/no question; `on_yes` runs when the player confirms. See UiKit.confirm.
static func ask(host: Node, title: String, text: String, yes_text: String, on_yes: Callable, no_text := "CANCEL") -> KitDialog:
	var d := KitDialog.new()
	d._on_yes = on_yes
	d._build(title, text, yes_text, no_text)
	host.add_child(d)
	return d


## A message with a single button.
static func notice(host: Node, title: String, text: String, ok_text := "OK") -> KitDialog:
	var d := KitDialog.new()
	d._build(title, text, "", ok_text)
	host.add_child(d)
	return d


func _build(title: String, text: String, yes_text: String, no_text: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(UiKit.INK, 0.74)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = UiKit.signboard()
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	col.custom_minimum_size.x = 620
	_panel.add_child(col)
	var head := UiKit.sign_label(title, 52, UiKit.AMBER)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	if text != "":
		var info := UiKit.body(text, 600, UiKit.SIZE_LABEL)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(info)
	col.add_child(UiKit.spacer(UiKit.GAP_S))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UiKit.GAP_L)
	col.add_child(row)
	var no := UiKit.sign_button(no_text, SignButton.Kind.SECONDARY)
	no.custom_minimum_size.x = 250
	no.pressed.connect(_close.bind(false))
	row.add_child(no)
	_safe = no
	if yes_text != "":
		var yes := UiKit.sign_button(yes_text, SignButton.Kind.PRIMARY)
		yes.custom_minimum_size.x = 250
		yes.pressed.connect(_close.bind(true))
		row.add_child(yes)
		_trap(no, yes)
		_trap(yes, no)
	else:
		_trap(no, no)


## Focus cannot leave the dialog's buttons.
func _trap(b: Control, other: Control) -> void:
	for side in [SIDE_LEFT, SIDE_RIGHT]:
		b.set_focus_neighbor(side, b.get_path_to(other))
	for side in [SIDE_TOP, SIDE_BOTTOM]:
		b.set_focus_neighbor(side, b.get_path_to(b))
	b.focus_next = b.get_path_to(other)
	b.focus_previous = b.get_path_to(other)


func _ready() -> void:
	open_count += 1
	UiSound.open()
	UiFx.fade_in(_dim, 0.15)
	UiFx.pop_in.call_deferred(_panel)
	_safe.grab_focus.call_deferred()


func _exit_tree() -> void:
	open_count -= 1


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close(false)


func _close(yes: bool) -> void:
	if _closing:
		return
	_closing = true
	if yes:
		UiSound.confirm()
		confirmed.emit()
		if _on_yes.is_valid():
			_on_yes.call()
	else:
		UiSound.back()
		cancelled.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)
