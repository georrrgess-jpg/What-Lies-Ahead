class_name WelcomeBackCard
extends Control
## One-time card for a returning save that was carried over to the Sparks
## economy: what is new in a few lines, the Sparks back pay it received and
## the way to the Shop. Shown instead of the first-run flow (see Onboarding).

const NEWS := [
	"Sparks: every zombie drops one. Spend them in the Shop on cosmetics.",
	"Sights you can swap, rebuilt weapons, operators and zombies.",
	"New rounds and difficulties, and Boot Camp on the title screen.",
]

var sparks := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var board := UiKit.signboard()
	board.set_padding(40, 30)
	center.add_child(board)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	board.add_child(col)
	col.add_child(UiKit.marquee("WELCOME BACK!", 56))
	for line in NEWS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UiKit.GAP_S)
		row.add_child(UiKit.icon(&"icon_star", 26.0, UiKit.AMBER))
		row.add_child(UiKit.body(line, 680, UiKit.SIZE_BODY, UiKit.CREAM))
		col.add_child(row)
	if sparks > 0:
		var pay := HBoxContainer.new()
		pay.alignment = BoxContainer.ALIGNMENT_CENTER
		pay.add_theme_constant_override("separation", UiKit.GAP_M)
		pay.add_child(UiKit.label("BACK PAY FOR YOUR PROGRESS", UiKit.SIZE_LABEL, UiKit.AMBER, true))
		pay.add_child(UiKit.price_tag(sparks, 40))
		col.add_child(pay)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", UiKit.GAP_L)
	col.add_child(buttons)
	var shop := UiKit.sign_button("OPEN THE SHOP", SignButton.Kind.GOLD, 34)
	shop.name = "FirstFocus"
	shop.pressed.connect(_close.bind(true))
	buttons.add_child(shop)
	var later := UiKit.sign_button("LATER", SignButton.Kind.SECONDARY, 30)
	later.pressed.connect(_close.bind(false))
	buttons.add_child(later)
	UiFx.pop_in(board)
	UiSound.sparks()
	shop.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close(false)


func _close(to_shop: bool) -> void:
	var menu := get_parent()
	queue_free()
	if to_shop and menu.has_method("page") and menu.page("shop") != null:
		menu.call("_open_from_here", "shop")
