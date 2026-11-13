class_name SparksChip
extends PanelContainer
## The player's Sparks balance: the Spark icon and the amount on a dark pill
## with a gold rim. It follows the Wallet: when the balance changes the
## number rolls to the new value and the icon pulses.
##
##   bar.add_child(UiKit.sparks_chip())

var _icon: TextureRect
var _amount: Label
var _shown := 0


func _init() -> void:
	var sb := UiKit.box(Color(UiKit.INK, 0.9), Color(Wallet.COLOR, 0.85), 24, 2, 6)
	sb.content_margin_left = 12
	sb.content_margin_right = 20
	add_theme_stylebox_override("panel", sb)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tooltip_text = "%s: set free from every zombie you pop. Spend them on cosmetics." % Wallet.CURRENCY
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = UiKit.spark_icon(40.0)
	row.add_child(_icon)
	_amount = UiKit.label("0", 32, Wallet.COLOR, true)
	_amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_amount)


func _ready() -> void:
	_shown = Wallet.balance()
	_amount.text = Wallet.format(_shown)
	Wallet.balance_changed.connect(_on_balance_changed)


func _on_balance_changed(balance: int) -> void:
	if not is_visible_in_tree():
		_shown = balance
		_amount.text = Wallet.format(balance)
		return
	if balance > _shown:
		UiSound.sparks()
	UiFx.count_up(_amount, _shown, balance, 0.5)
	UiFx.pulse(_icon, 1.3)
	_shown = balance
