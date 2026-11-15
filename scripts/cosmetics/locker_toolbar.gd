class_name LockerToolbar
extends HFlowContainer
## The Locker tray's toolbar: a search box and up to four choosers (SORT,
## SHOW, FROM, and FITS on the weapon tabs) that step through their options on
## a press (right-click steps back), plus CLEAR while anything narrows the
## list. It edits a LockerFilters.State that the page keeps per tab. When the
## choosers' texts are too wide for one row (a narrow tray, long choices) the
## last ones wrap to a second row.

signal changed

var state: LockerFilters.State
var _prints := false
## "PRIMARY" or "SECONDARY": the class of the weapon being customised ("" when
## the tab is not per weapon, which hides FITS).
var _weapon_class := ""
var _search: LineEdit
var _sort: SignButton
var _show: SignButton
var _source: SignButton
var _fits: SignButton
var _clear: SignButton


func _init() -> void:
	add_theme_constant_override("h_separation", UiKit.GAP_S)
	add_theme_constant_override("v_separation", UiKit.GAP_S)
	_search = UiKit.search_box("Search by name")
	_search.name = "Search"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size.x = 150
	_search.text_changed.connect(_on_search)
	add_child(_search)
	_sort = _chooser("Order of the cards", _step_sort)
	_show = _chooser("Which cards to show", _step_show)
	_source = _chooser("Where items come from", _step_source)
	_fits = _chooser("", _step_fits)
	_clear = UiKit.sign_button("CLEAR", SignButton.Kind.SECONDARY, 20)
	_clear.tooltip_text = "Show everything again"
	_clear.pressed.connect(_on_clear)
	add_child(_clear)


## Shows `s` (one tab's filters). `prints` switches to the Prints tab's
## choices; `weapon_class` ("PRIMARY", "SECONDARY") names the class of the
## weapon being customised in the FITS texts ("" hides FITS).
func set_state(s: LockerFilters.State, prints: bool, weapon_class := "") -> void:
	state = s
	_prints = prints
	_weapon_class = weapon_class
	_source.visible = not prints
	_fits.visible = not prints and weapon_class != ""
	_search.placeholder_text = "Search prints or serial" if prints else "Search by name"
	if _search.text != s.search:
		_search.text = s.search
	_refresh()


func search_box() -> LineEdit:
	return _search


func _chooser(tip: String, step: Callable) -> SignButton:
	var b := UiKit.sign_button("", SignButton.Kind.NEUTRAL, 20)
	b.tooltip_text = tip + " (right-click: back)"
	b.pressed.connect(step.bind(1))
	b.gui_input.connect(func(e: InputEvent):
		var click := e as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
			UiSound.tab()
			step.call(-1))
	add_child(b)
	return b


func _refresh() -> void:
	_sort.text = "SORT  %s" % LockerFilters.SORT_NAMES[state.sort]
	_sort.tooltip_text = LockerFilters.SORT_HINTS[state.sort]
	var shown: String = LockerFilters.print_show_name(state.show, _weapon_class) if _prints else LockerFilters.SHOW_NAMES[state.show]
	_show.text = "SHOW  %s" % shown
	_source.text = "FROM  %s" % LockerFilters.SOURCE_NAMES[state.source]
	_fits.text = "FITS  %s" % LockerFilters.fits_name(state.fits, _weapon_class)
	_fits.tooltip_text = LockerFilters.FITS_HINTS[state.fits].replace("%s", _weapon_class.to_lower()) + " (right-click: back)"
	_clear.visible = state.narrows()
	_show.modulate = Color(1.25, 1.1, 0.8) if state.show != 0 else Color.WHITE
	_source.modulate = Color(1.25, 1.1, 0.8) if state.source != LockerFilters.Source.ANY else Color.WHITE
	_fits.modulate = Color(1.25, 1.1, 0.8) if state.fits != LockerFilters.Fits.ANY else Color.WHITE


func _step_sort(direction: int) -> void:
	state.sort = posmod(state.sort + direction, LockerFilters.SORT_NAMES.size()) as LockerFilters.Sort
	_after_change()


func _step_show(direction: int) -> void:
	var count := (LockerFilters.PRINT_SHOW_NAMES if _prints else LockerFilters.SHOW_NAMES).size()
	state.show = posmod(state.show + direction, count)
	_after_change()


func _step_source(direction: int) -> void:
	state.source = posmod(state.source + direction, LockerFilters.SOURCE_NAMES.size()) as LockerFilters.Source
	_after_change()


func _step_fits(direction: int) -> void:
	state.fits = posmod(state.fits + direction, LockerFilters.FITS_NAMES.size()) as LockerFilters.Fits
	_after_change()


func _on_search(text: String) -> void:
	state.search = text
	_clear.visible = state.narrows()
	changed.emit()


func _on_clear() -> void:
	state.clear()
	_search.text = ""
	_after_change()
	_sort.grab_focus()


func _after_change() -> void:
	_refresh()
	changed.emit()
