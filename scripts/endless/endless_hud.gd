class_name EndlessHud
extends Control
## In-run Endless overlay (registered by data/ui/hud_endless.tres), only
## shown in an endless run:
##   - under the wave header: the district the player stands in, in its
##     colour, and the best wave so far;
##   - at the bottom centre: the prompt of the gate or trap the player stands
##     at ("HOLD [E]  OPEN PRECINCT 9   500 tickets"), with the hold filling
##     a bar, in red with what is missing when the tickets are short;
##   - a marker on a supply crate until it is picked up, on a power-up
##     while it lies on the ground, and in the middle of a district just
##     opened (until the player walks in or REVEAL_SECONDS pass);
##   - under the district chip, a timer bar for every timed power-up running
##     (Double Tickets, Rapid Fire), and the weapon in hand's bench tier.

const DISTRICT_POS := Vector2(48, 152)
const PROMPT_BOTTOM := 250.0
const SUPPLY_COLOR := Color(0.35, 1.0, 0.45)
const TIMERS_POS := Vector2(48, 206)
const REVEAL_SECONDS := 12.0

var _director: RunDirector
var _endless: EndlessDirector
var _player: Player
var _district: PanelContainer
var _district_name: Label
var _district_box: StyleBoxFlat
var _best: Label
var _prompt: PanelContainer
var _prompt_box: StyleBoxFlat
var _prompt_text: Label
var _prompt_price: Label
var _prompt_note: Label
var _ticket_icon: Control
var _bar: ProgressBar
var _supply: Waypoint
var _powerup: Waypoint
var _reveal: Waypoint
var _reveal_left := 0.0
var _reveal_id: StringName
var _reveal_spot: Node3D
var _timers: VBoxContainer
## Timed power-up kind -> [row, bar, seconds label].
var _timer_rows := {}
var _tier: Label
var _tier_key := ""
var _shown_key := ""
var _best_shown := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_district()
	_build_prompt()
	_supply = Waypoint.new()
	_supply.label = "SUPPLY DROP"
	_supply.color = SUPPLY_COLOR
	_supply.icon = "kiosk"
	_supply.offset = Vector3(0, 2.6, 0)
	_supply.visible = false
	add_child(_supply)
	_powerup = Waypoint.new()
	_powerup.icon = "star"
	_powerup.offset = Vector3(0, 2.4, 0)
	_powerup.visible = false
	add_child(_powerup)
	_reveal = Waypoint.new()
	_reveal.icon = "portal"
	_reveal.offset = Vector3(0, 4.2, 0)
	_reveal.visible = false
	add_child(_reveal)
	_reveal_spot = Node3D.new()
	add_child(_reveal_spot)
	_build_timers()
	visible = false


## Full screen: the pieces place themselves.
func hud_slot() -> StringName:
	return &"overlay"


func bind(director: RunDirector, player: Player) -> void:
	_director = director
	_endless = director.endless
	_player = player
	if _endless == null:
		set_process(false)
		return
	visible = true
	_supply.camera = player.camera
	_powerup.camera = player.camera
	_reveal.camera = player.camera
	_endless.district_opened.connect(_on_district_opened)
	_endless.powerups.dropped.connect(_on_powerup)
	_endless.powerups.changed.connect(_rebuild_timers)
	_endless.district_entered.connect(_show_district.bind(true))
	_endless.district_opened.connect(func(_d): _shown_key = "")
	_endless.supply_changed.connect(_on_supply)
	_endless.new_best.connect(func(_w): UiFx.pulse(_best, 1.2))
	director.run_finished.connect(func(_r): visible = false)
	_show_district(_endless.current_district(), false)


func _process(delta: float) -> void:
	if _endless == null:
		return
	var best := maxi(_endless.best_before, _director.wave_number)
	if best != _best_shown:
		_best_shown = best
		_best.text = "BEST WAVE %d" % best if best > 0 else "FIRST RUN"
	_update_prompt()
	_update_timers()
	if _reveal.visible:
		_reveal_left -= delta
		var here := _endless.current_district()
		if _reveal_left <= 0.0 or (here and here.id == _reveal_id):
			_reveal.visible = false


# --- district chip -------------------------------------------------------------------

func _build_district() -> void:
	var row := HBoxContainer.new()
	row.position = DISTRICT_POS
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_district = PanelContainer.new()
	_district_box = UiKit.box(Color(UiKit.INK, 0.74), UiKit.AMBER, 20, 2, 4)
	_district_box.content_margin_left = 14
	_district_box.content_margin_right = 18
	_district.add_theme_stylebox_override("panel", _district_box)
	_district.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_district)
	_district_name = UiKit.label("", 26, Color.WHITE, true)
	_district.add_child(_district_name)
	_best = UiKit.arcade_label("", 26, UiKit.MUTED)
	_best.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_best)


func _show_district(d: EndlessDistrict, animate: bool) -> void:
	if d == null:
		return
	_district_name.text = d.display_name.to_upper()
	_district_name.add_theme_color_override("font_color", d.accent_color.lerp(Color.WHITE, 0.35))
	_district_box.border_color = d.accent_color
	if animate and is_visible_in_tree():
		_district.pivot_offset = _district.size * 0.5
		UiFx.pulse(_district, 1.15)


# --- prompt ----------------------------------------------------------------------------

func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt_box = UiKit.box(Color(UiKit.INK, 0.82), UiKit.AMBER, 24, 3, 10)
	_prompt_box.content_margin_left = 20
	_prompt_box.content_margin_right = 24
	_prompt.add_theme_stylebox_override("panel", _prompt_box)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	# A band across the bottom that keeps the prompt centred whatever its width.
	var band := CenterContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -PROMPT_BOTTOM - 90.0
	band.offset_bottom = -PROMPT_BOTTOM
	band.add_child(_prompt)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	row.add_child(UiKit.label("HOLD", 24, UiKit.MUTED, true))
	var key := Loadout.key_hint(&"interact").get_slice(" / ", 0).to_upper()
	row.add_child(UiKit.key_glyph(key, 42.0))
	_prompt_text = UiKit.label("", 30, Color.WHITE, true)
	row.add_child(_prompt_text)
	_ticket_icon = HudIcon.make(&"ticket", 30.0, UiKit.AMBER)
	_ticket_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_ticket_icon)
	_prompt_price = UiKit.label("", 30, UiKit.AMBER, true)
	row.add_child(_prompt_price)
	_prompt_note = UiKit.label("", 22, UiKit.RED, true)
	_prompt_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_prompt_note)
	_bar = UiKit.progress(0.0, 8.0, UiKit.AMBER)
	_bar.custom_minimum_size = Vector2(0, 8)
	col.add_child(_bar)


## Follows the gate or trap the player is at; the texts change only when
## what they say does, the bar every frame while the key is held.
func _update_prompt() -> void:
	var at := _endless.focus
	var p: Dictionary = at.prompt() if at else {}
	if p.is_empty():
		if _prompt.visible:
			_prompt.visible = false
			_shown_key = ""
		return
	var price := int(p.get("price", 0))
	var disabled := bool(p.get("disabled", false))
	var short := price > _director.tickets
	var key := "%s|%d|%s|%s|%s" % [p["action"], price, p.get("note", ""), short, disabled]
	if key != _shown_key:
		_shown_key = key
		var accent: Color = p.get("accent", UiKit.AMBER)
		_prompt_box.border_color = UiKit.RED if short and not disabled else accent
		_prompt_text.text = String(p["action"]).to_upper()
		_prompt_text.add_theme_color_override("font_color", UiKit.MUTED if disabled else accent.lerp(Color.WHITE, 0.45))
		_ticket_icon.visible = price > 0
		_prompt_price.visible = price > 0
		_prompt_price.text = str(price)
		_prompt_price.add_theme_color_override("font_color", UiKit.RED if short else UiKit.AMBER)
		_prompt_note.text = String(p.get("note", "")) if disabled else ("NEED %d MORE" % (price - _director.tickets) if short else String(p.get("perk", "")).to_upper())
		_prompt_note.add_theme_color_override("font_color", UiKit.MUTED if disabled else (UiKit.RED if short else accent.lerp(Color.WHITE, 0.3)))
		_bar.visible = not disabled
		if not _prompt.visible:
			_prompt.visible = true
			_prompt.pivot_offset = _prompt.size * 0.5
			UiFx.pop_in(_prompt, 0.0, 0.8)
	_bar.value = clampf(_endless.hold / EndlessDirector.HOLD_SECONDS, 0.0, 1.0)


# --- power-ups and the bench tier -----------------------------------------------

func _build_timers() -> void:
	_timers = VBoxContainer.new()
	_timers.position = TIMERS_POS
	_timers.add_theme_constant_override("separation", 6)
	_timers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timers)
	_tier = UiKit.label("", 22, UiKit.MUTED, true)
	_timers.add_child(_tier)


## One row per timed power-up running: its name, a draining bar, the seconds.
func _rebuild_timers() -> void:
	for kind in _timer_rows.keys():
		if not _endless.powerups.active.has(kind):
			(_timer_rows[kind][0] as Control).queue_free()
			_timer_rows.erase(kind)
	for kind in _endless.powerups.active:
		if _timer_rows.has(kind):
			continue
		var info: Array = EndlessPowerups.KINDS[kind]
		var color: Color = info[2]
		var row := PanelContainer.new()
		var box := UiKit.box(Color(UiKit.INK, 0.78), color, 16, 2, 4)
		box.content_margin_left = 12
		box.content_margin_right = 12
		row.add_theme_stylebox_override("panel", box)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		col.add_child(line)
		line.add_child(UiKit.label(info[0], 22, color.lerp(Color.WHITE, 0.35), true))
		var secs := UiKit.arcade_label("", 22, Color.WHITE)
		line.add_child(secs)
		var bar := UiKit.progress(1.0, 6.0, color)
		bar.custom_minimum_size = Vector2(220, 6)
		col.add_child(bar)
		_timers.add_child(row)
		row.pivot_offset = Vector2(110, 20)
		UiFx.pop_in(row, 0.0, 0.8)
		_timer_rows[kind] = [row, bar, secs]


func _update_timers() -> void:
	var total := _endless.rules.powerup_seconds
	for kind in _timer_rows:
		var row: Array = _timer_rows[kind]
		var left := _endless.powerups.left(kind)
		(row[1] as ProgressBar).value = clampf(left / total, 0.0, 1.0)
		var text := "%d" % ceili(left)
		if (row[2] as Label).text != text:
			(row[2] as Label).text = text
			# The last seconds blink.
			(row[0] as Control).modulate.a = 1.0 if left > 3.0 or ceili(left) % 2 == 1 else 0.55
	var w := _player.weapons.current
	var t := _endless.upgrades.tier(w.id) if w else 0
	var key := "%s|%d" % [w.id if w else &"", t]
	if key != _tier_key:
		_tier_key = key
		_tier.text = "%s  ·  %s" % [w.display_name.to_upper(), EndlessUpgrades.NAMES[t]] if t > 0 else ""
		_tier.add_theme_color_override("font_color", EndlessUpgrades.TIER_COLORS[t].lerp(Color.WHITE, 0.2))


func _on_powerup(p: EndlessPowerup) -> void:
	_powerup.target = p
	_powerup.visible = p != null
	if p:
		_powerup.label = p.title
		_powerup.color = p.color


## A district just opened: a marker over its middle shows the way in.
func _on_district_opened(d: EndlessDistrict) -> void:
	var at := _endless.district_centre(d.id)
	if at == Vector3.INF:
		return
	_reveal_spot.global_position = at
	_reveal.target = _reveal_spot
	_reveal.label = d.display_name.to_upper()
	_reveal.color = d.accent_color.lerp(Color.WHITE, 0.2)
	_reveal_id = d.id
	_reveal_left = REVEAL_SECONDS
	_reveal.visible = true


func _on_supply(crate: EndlessSupply) -> void:
	_supply.target = crate
	_supply.visible = crate != null
