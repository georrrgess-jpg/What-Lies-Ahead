extends Control
## In-run Sparks HUD (registered by data/ui/hud_sparks.tres):
##   - the stars that fly from popped zombies to the player (SparkField) with
##     a pickup tick that climbs in pitch while pickups keep coming,
##   - the run's Sparks counter at the bottom centre, where the stars land; it
##     ticks up as each star arrives and shows other payouts (wave clears,
##     level-ups, contracts) as one "+N" that adds up while it is on screen,
##   - the three active contracts with their progress, shown between waves
##     (and for a moment when one is completed), hidden while fighting.

const MARGIN := 48.0
const COUNTER_BOTTOM := -34.0
const CONTRACTS_TOP := 176.0
## Pickups this close together keep the streak (and the pitch) climbing.
const STREAK_WINDOW := 1.1
const STREAK_MAX := 14
const TICK_INTERVAL := 0.04
## Sources that arrive as stars; everything else is added to the counter at once.
const STAR_SOURCES: Array[StringName] = [&"kill", &"headshot", &"combo"]

var _director: RunDirector
var _field: SparkField
var _counter: PanelContainer
var _icon: SparkIcon
var _amount: Label
var _gain: Label
var _gain_tween: Tween
var _gain_sum := 0
var _contracts: PanelContainer
var _rows: VBoxContainer
var _flash_left := 0.0
## Sparks banked but still on their way to the counter as stars.
var _in_flight := 0
var _shown := -1
var _streak := 0
var _streak_left := 0.0
var _tick_left := 0.0
var _pulse := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_counter()
	_build_contracts()


func bind(director: RunDirector, player: Player) -> void:
	_director = director
	_field = SparkField.new()
	_field.name = "SparkField"
	_field.target = player
	director.get_parent().add_child(_field)
	_field.collected.connect(_on_collected)
	Wallet.sparks_dropped.connect(_on_dropped)
	Wallet.earned.connect(_on_earned)
	Progression.contract_completed.connect(_on_contract_completed)
	director.state_changed.connect(_on_state_changed)
	_refresh_contracts()
	_on_state_changed(director.state)


func _process(delta: float) -> void:
	_streak_left -= delta
	if _streak_left <= 0.0:
		_streak = 0
	_tick_left -= delta
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 5.0)
		_counter.scale = Vector2.ONE * (1.0 + 0.1 * _pulse)
	_flash_left = maxf(0.0, _flash_left - delta)
	var want := 0.0
	if _director and _director.is_intermission():
		# The station menu uses the same side of the screen.
		want = 0.0 if _director.kiosk_available() else 1.0
	elif _flash_left > 0.0:
		want = 1.0
	if _contracts.modulate.a != want:
		_contracts.modulate.a = move_toward(_contracts.modulate.a, want, delta * 5.0)
		_contracts.visible = _contracts.modulate.a > 0.0


# --- counter -------------------------------------------------------------------

func _build_counter() -> void:
	_counter = PanelContainer.new()
	var plate := UiKit.box(Color(UiKit.INK, 0.72), Color(Wallet.COLOR, 0.85), 22, 3, 0)
	plate.content_margin_left = 14
	plate.content_margin_right = 22
	plate.content_margin_top = 2
	plate.content_margin_bottom = 4
	_counter.add_theme_stylebox_override("panel", plate)
	_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_counter)
	_counter.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_counter.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_counter.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pin(_counter, COUNTER_BOTTOM)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_counter.add_child(row)
	_icon = SparkIcon.new(40.0)
	row.add_child(_icon)
	_amount = UiKit.arcade_label("0", 40, Wallet.COLOR)
	row.add_child(_amount)
	# Nothing to count before the first Spark (and the controls reminder sits here).
	_counter.modulate.a = 0.0
	_gain = UiKit.arcade_label("", 34, Wallet.COLOR)
	_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gain.modulate.a = 0.0
	add_child(_gain)
	_gain.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_gain.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_gain.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_pin(_gain, COUNTER_BOTTOM - 62.0)


## Pins an anchored control `bottom` pixels from its anchor, centred on it.
static func _pin(c: Control, bottom: float) -> void:
	c.position = Vector2.ZERO
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = bottom
	c.offset_bottom = bottom


func _refresh_counter(pulse: bool) -> void:
	var value := maxi(0, Wallet.run_total() - _in_flight)
	if value == _shown:
		return
	_shown = value
	_amount.text = Wallet.format(value)
	if value > 0 and _counter.modulate.a < 1.0:
		_counter.create_tween().tween_property(_counter, "modulate:a", 1.0, 0.25)
	if pulse:
		_pulse = 1.0
		_icon.flash = 1.0
		_counter.pivot_offset = _counter.size * 0.5


func _on_dropped(at: Vector3, amount: int) -> void:
	_in_flight += amount
	_field.drop(at, amount)


func _on_collected(amount: int) -> void:
	_in_flight = maxi(0, _in_flight - amount)
	_refresh_counter(true)
	_streak = mini(_streak + 1, STREAK_MAX) if _streak_left > 0.0 else 0
	_streak_left = STREAK_WINDOW
	if _tick_left <= 0.0:
		_tick_left = TICK_INTERVAL
		# One semitone per pickup in the streak, up to an octave and a bit.
		Sfx.play(&"eco_spark_tick", -9.0, pow(2.0, _streak / 12.0))


## Payouts that do not arrive as stars: straight onto the counter, with one
## "+N" above it that keeps adding up while it is showing.
func _on_earned(amount: int, source: StringName) -> void:
	if source in STAR_SOURCES:
		return
	_refresh_counter(true)
	_gain_sum += amount
	_gain.text = "+%s" % Wallet.format(_gain_sum)
	if _gain_tween and _gain_tween.is_valid():
		_gain_tween.kill()
	else:
		Sfx.play(&"eco_spark_bank", -7.0)
	_gain.modulate.a = 1.0
	_gain_tween = _gain.create_tween()
	_gain_tween.tween_interval(1.5)
	_gain_tween.tween_property(_gain, "modulate:a", 0.0, 0.4)
	_gain_tween.tween_callback(func(): _gain_sum = 0)


# --- contracts -------------------------------------------------------------------

func _build_contracts() -> void:
	_contracts = PanelContainer.new()
	_contracts.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.7), Color(Wallet.COLOR_GLOW, 0.35), 16, 2, 12))
	_contracts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contracts.position = Vector2(MARGIN, CONTRACTS_TOP)
	_contracts.custom_minimum_size = Vector2(400, 0)
	_contracts.visible = false
	_contracts.modulate.a = 0.0
	add_child(_contracts)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	_contracts.add_child(_rows)


func _refresh_contracts() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_rows.add_child(UiKit.label("CONTRACTS", 20, Wallet.COLOR_GLOW, true))
	for entry in ContractBoard.active():
		_rows.add_child(_contract_row(entry))


func _contract_row(entry: Dictionary) -> Control:
	var done := ContractBoard.is_done(entry)
	var template := ContractBoard.template(entry)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	var text := UiKit.label(ContractBoard.describe(entry), 21, UiKit.GREEN if done else Color.WHITE)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.custom_minimum_size = Vector2(240, 0)
	top.add_child(text)
	var note := "DONE  +%d" % template.sparks if done else "%s / %s" % [Wallet.format(ContractBoard.progress(entry)), Wallet.format(ContractBoard.goal(entry))]
	top.add_child(UiKit.label(note, 20, Wallet.COLOR if done else UiKit.CREAM, true))
	var bar := UiKit.progress(ContractBoard.fraction(entry), 6.0, UiKit.GREEN if done else Wallet.COLOR_GLOW)
	box.add_child(bar)
	return box


func _on_state_changed(state: RunDirector.State) -> void:
	if state == RunDirector.State.PREP or state == RunDirector.State.BREAK:
		_refresh_contracts()


## A contract finished mid-fight: the list shows for a moment with it ticked.
func _on_contract_completed(_entry: Dictionary) -> void:
	Sfx.play(&"eco_contract", -4.0)
	_flash_left = 3.5
	_refresh_contracts()
