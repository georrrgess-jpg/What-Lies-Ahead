extends CanvasLayer
## In-game HUD. Wave upper left, segmented health lower left, ammo lower
## right, small centre reticle. Tickets, kiosk prompts, the intermission timer
## and the extraction objective appear only when they matter.

const MARGIN := 48.0

var director: RunDirector
var player: Player

var _root: Control
var _wave: Label
var _wave_sub: Label
var _health: SegmentBar
var _ammo: Label
var _slots: WeaponSlots
var _weapon_hud: WeaponHud
var _tickets: Label
var _reticle: Reticle
var _score_panel: ScorePanel
var _kiosk_marker: Waypoint
var _portal_marker: Waypoint
var _threats: ThreatRing
var _reload_arc: ReloadArc
var _banner: Label
var _notice: Label
var _status: Label          # reload / empty prompt under the reticle
var _intermission: PanelContainer
var _intermission_title: Label
var _intermission_hint: Label
var _kiosk: PanelContainer
var _kiosk_rows: VBoxContainer
var _objective: Label
var _controls: Label
var _toasts: VBoxContainer
var _vignette: TextureRect
var _banner_tween: Tween
var _notice_tween: Tween
var _hurt := 0.0
var _kiosk_signature: Array = []


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.theme()
	add_child(_root)
	_build()


func bind(run: RunDirector, p: Player) -> void:
	director = run
	player = p
	_threats.player = p
	_threats.director = run
	run.wave_started.connect(_on_wave_started)
	run.tickets_changed.connect(_on_tickets_changed)
	run.notice.connect(_on_notice)
	run.reward_unlocked.connect(_on_reward_unlocked)
	run.state_changed.connect(_on_state_changed)
	if run.score:
		_score_panel.bind(run.score)
	_kiosk_marker.camera = p.camera
	_kiosk_marker.target = run.kiosk
	_portal_marker.camera = p.camera
	_portal_marker.target = run.portal
	run.run_finished.connect(func(_r): _root.visible = false)
	p.health_changed.connect(_on_health_changed)
	p.damaged.connect(_on_damaged)
	p.weapons.ammo_changed.connect(_on_ammo_changed)
	_slots.bind(p.weapons)
	_weapon_hud.bind(p, _ammo)
	p.weapons.hit_confirmed.connect(_reticle.show_hit)
	p.weapons.fired.connect(p.view.on_fired)
	p.weapons.reload_started.connect(p.view.play_reload)
	p.weapons.weapon_changed.connect(p.view.show_weapon)
	if p.weapons.current:
		_on_ammo_changed(p.weapons.magazine(), p.weapons.reserve())
		p.view.show_weapon(p.weapons.current)
	_on_health_changed(p.health, p.max_health)
	_on_tickets_changed(run.tickets)
	_on_state_changed(run.state)


## Adds an extra widget (from a HUD_WIDGET UiExtension) on top of the HUD.
func add_widget(widget: Control) -> void:
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(widget)


## Level start: hold black for a few frames (while FxWarmup compiles shaders
## underneath), then fade the world in.
func fade_in() -> void:
	var black := ColorRect.new()
	black.color = Color(0.04, 0.02, 0.08)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(black)
	var tw := black.create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(black, "modulate:a", 0.0, 0.5)
	tw.tween_callback(black.queue_free)


# --- construction ---------------------------------------------------------------

func _anchor(c: Control, preset: Control.LayoutPreset, offset: Vector2, grow_h := Control.GROW_DIRECTION_END, grow_v := Control.GROW_DIRECTION_END) -> void:
	_root.add_child(c)
	c.set_anchors_preset(preset)
	c.grow_horizontal = grow_h
	c.grow_vertical = grow_v
	c.position = Vector2.ZERO
	c.offset_left = offset.x
	c.offset_right = offset.x
	c.offset_top = offset.y
	c.offset_bottom = offset.y
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build() -> void:
	# Damage vignette (behind everything else).
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.62, 1.0])
	grad.colors = PackedColorArray([Color(0.55, 0.0, 0.1, 0.0), Color(0.5, 0.0, 0.12, 0.85)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 1.0)   # full strength at the screen edges, not only the corners
	tex.width = 256
	tex.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_root.add_child(_vignette)

	# Upper left: wave.
	_wave = UiKit.arcade_label("WAVE 01", 92)
	_anchor(_wave, Control.PRESET_TOP_LEFT, Vector2(MARGIN, 18))
	_wave_sub = UiKit.arcade_label("", 34, UiKit.CREAM)
	_anchor(_wave_sub, Control.PRESET_TOP_LEFT, Vector2(MARGIN + 4, 122))

	# Upper right: tickets.
	_tickets = UiKit.arcade_label("TICKETS 0", 46, UiKit.AMBER)
	var plate := UiKit.box(Color(UiKit.INK, 0.55), Color.TRANSPARENT, 16, 0, 0)
	plate.content_margin_left = 18
	plate.content_margin_right = 18
	plate.content_margin_top = 2
	plate.content_margin_bottom = 4
	_tickets.add_theme_stylebox_override("normal", plate)
	_anchor(_tickets, Control.PRESET_BOTTOM_RIGHT, Vector2(-MARGIN, -186), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	_tickets.add_theme_font_size_override("font_size", 34)

	# Upper right: score, combo and awards.
	_score_panel = ScorePanel.new()
	_score_panel.custom_minimum_size = Vector2(420, 0)
	_anchor(_score_panel, Control.PRESET_TOP_RIGHT, Vector2(-MARGIN, 14), Control.GROW_DIRECTION_BEGIN)

	# World markers (loadout station during breaks, portal during extraction).
	_kiosk_marker = Waypoint.new()
	_kiosk_marker.label = "LOADOUT STATION"
	_kiosk_marker.visible = false
	_root.add_child(_kiosk_marker)
	_portal_marker = Waypoint.new()
	_portal_marker.label = "EXIT PORTAL"
	_portal_marker.icon = "portal"
	_portal_marker.color = UiKit.CYAN
	_portal_marker.offset = Vector3(0, 4.6, 0)
	_portal_marker.visible = false
	_root.add_child(_portal_marker)

	# Lower left: segmented health.
	_health = SegmentBar.new()
	_health.custom_minimum_size = Vector2(390, 50)
	_anchor(_health, Control.PRESET_BOTTOM_LEFT, Vector2(MARGIN + 8, -MARGIN - 8), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)

	# Lower right: ammo, with the two carried weapons right above it.
	_ammo = UiKit.arcade_label("12 / 60", 92)
	_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchor(_ammo, Control.PRESET_BOTTOM_RIGHT, Vector2(-MARGIN, -26), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	_slots = WeaponSlots.new()
	_anchor(_slots, Control.PRESET_BOTTOM_RIGHT, Vector2(-MARGIN, -134), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	# Charge ring, heat bar, burst pips and seek lock (drawn over everything).
	_weapon_hud = WeaponHud.new()
	_root.add_child(_weapon_hud)

	# Centre: reticle and status.
	_reticle = Reticle.new()
	_reticle.custom_minimum_size = Vector2(120, 120)
	_anchor(_reticle, Control.PRESET_CENTER, Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	_reload_arc = ReloadArc.new()
	_reload_arc.custom_minimum_size = Vector2(120, 120)
	_anchor(_reload_arc, Control.PRESET_CENTER, Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	_threats = ThreatRing.new()
	_threats.custom_minimum_size = Vector2(680, 680)
	_anchor(_threats, Control.PRESET_CENTER, Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	_status = UiKit.arcade_label("", 30, UiKit.AMBER)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(_status, Control.PRESET_CENTER, Vector2(0, 110), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)

	# Banner and notice.
	_banner = UiKit.arcade_label("", 88, Color.WHITE)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.custom_minimum_size = Vector2(1300, 0)
	_banner.add_theme_constant_override("line_spacing", -18)
	_banner.modulate.a = 0.0
	_anchor(_banner, Control.PRESET_CENTER_TOP, Vector2(0, 210), Control.GROW_DIRECTION_BOTH)
	_notice = UiKit.arcade_label("", 36, UiKit.CREAM)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.modulate.a = 0.0
	_anchor(_notice, Control.PRESET_CENTER_BOTTOM, Vector2(0, -200), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)

	# Controls reminder, shown only before the first wave.
	_controls = UiKit.label("WASD move  ·  Shift sprint  ·  Mouse aim  ·  LMB fire  ·  R reload  ·  1 / 2 switch  ·  F start wave  ·  Esc pause\nAt the Loadout Station between waves:  E energy  ·  Q snack  ·  %s / %s swap the held weapon" % [
		Loadout.key_hint(&"kiosk_prev").get_slice(" / ", 0), Loadout.key_hint(&"kiosk_next").get_slice(" / ", 0)], 26, UiKit.CREAM)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.add_theme_color_override("font_outline_color", Color(UiKit.INK, 0.9))
	_controls.add_theme_constant_override("outline_size", 8)
	_controls.add_theme_constant_override("line_spacing", -4)
	_controls.visible = false
	_anchor(_controls, Control.PRESET_CENTER_BOTTOM, Vector2(0, -40), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)

	# Objective (extraction).
	_objective = UiKit.arcade_label("", 44, UiKit.CYAN)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.visible = false
	_anchor(_objective, Control.PRESET_CENTER_TOP, Vector2(0, 40), Control.GROW_DIRECTION_BOTH)

	# Intermission timer.
	_intermission = PanelContainer.new()
	_intermission.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.82), UiKit.CYAN, 22, 3, 14))
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", -4)
	_intermission.add_child(iv)
	_intermission_title = UiKit.label("NEXT WAVE IN 20", 40, Color.WHITE, true)
	_intermission_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(_intermission_title)
	_intermission_hint = UiKit.label("[F] Start now", 26, UiKit.CYAN)
	_intermission_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(_intermission_hint)
	_anchor(_intermission, Control.PRESET_CENTER_TOP, Vector2(0, 30), Control.GROW_DIRECTION_BOTH)

	# Kiosk panel.
	_kiosk = PanelContainer.new()
	_kiosk.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.88), UiKit.AMBER, 24, 4, 22))
	_kiosk_rows = VBoxContainer.new()
	_kiosk_rows.add_theme_constant_override("separation", 2)
	_kiosk.add_child(_kiosk_rows)
	_kiosk.visible = false
	_anchor(_kiosk, Control.PRESET_CENTER_LEFT, Vector2(MARGIN, -40), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BOTH)

	# Unlock toasts.
	_toasts = VBoxContainer.new()
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.add_theme_constant_override("separation", 10)
	_anchor(_toasts, Control.PRESET_CENTER_RIGHT, Vector2(-MARGIN, -60), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BOTH)


# --- per-frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	if director == null or player == null:
		return
	# Reticle gap = the real spread cone projected onto the screen.
	var spread_deg := player.weapons.current_spread()
	var half_h := get_viewport().get_visible_rect().size.y * 0.5
	_reticle.spread_px = tan(deg_to_rad(spread_deg)) / tan(deg_to_rad(player.camera.fov * 0.5)) * half_h
	_reticle.aim = player.ads
	if player.weapons.current:
		var pick := String(Settings.value("reticle_style"))
		_reticle.style = player.weapons.current.reticle_style if pick == "auto" else pick

	# Health vignette: brief flash on damage plus a steady pulse when low.
	_hurt = maxf(0.0, _hurt - delta * 1.8)
	var low := 0.0
	if player.alive and player.health <= player.max_health * 0.25:
		low = 0.25 + 0.12 * sin(Time.get_ticks_msec() * 0.006)
	_vignette.modulate.a = maxf(_hurt * Settings.flash_scale(), low)
	if not player.alive:
		_vignette.modulate.a = 0.7

	# Reload / empty prompt.
	var w := player.weapons
	_reload_arc.progress = w.reload_progress() if w.is_reloading() else -1.0
	if w.current == null:
		_status.text = ""
	elif w.is_reloading():
		_status.text = "VENTING HEAT" if w.current.uses_heat() else "RELOADING"
	elif w.is_emergency_recharging():
		_status.text = "EMERGENCY RECHARGE" if w.magazine() > 0 else "OUT OF ENERGY — RECHARGING"
	elif w.magazine() <= maxi(1, w.current.magazine_size / 4) and w.reserve() > 0:
		_status.text = "[R] RELOAD"
	else:
		_status.text = ""

	match director.state:
		RunDirector.State.WAVE:
			_wave_sub.text = "ZOMBIES  %d" % director.enemies_remaining()
		RunDirector.State.PREP, RunDirector.State.BREAK:
			_wave_sub.text = "INTERMISSION"
			var next := director.wave_number + 1
			_intermission_title.text = "%s IN %d" % ["FINAL WAVE" if next == director.total_waves() else "WAVE %d" % next, int(ceil(director.countdown))]
		RunDirector.State.EXTRACTION:
			_wave_sub.text = "ALL WAVES CLEARED"
			if director.portal:
				var d := player.global_position.distance_to(director.portal.global_position)
				_objective.text = "STEP THROUGH THE PORTAL  ·  %d m" % int(d)

	# Loadout marker: during breaks, whenever the player is not already at it.
	_kiosk_marker.visible = director.is_intermission() and director.kiosk != null and not director.kiosk.player_inside
	var show_kiosk := director.kiosk_available()
	if show_kiosk != _kiosk.visible:
		_kiosk.visible = show_kiosk
	if show_kiosk:
		# Rebuild the panel only when something it shows has changed.
		var signature := [director.tickets, player.weapons.current, player.weapons.active_slot, director.heals_left(),
			player.health >= player.max_health, player.weapons.is_ammo_full()]
		if signature != _kiosk_signature:
			_kiosk_signature = signature
			_refresh_kiosk()
	if director.is_intermission():
		_intermission_hint.text = "[F] Start now" if show_kiosk else "[F] Start now   ·   Loadout station open: follow the marker"


func _refresh_kiosk() -> void:
	for c in _kiosk_rows.get_children():
		c.queue_free()
	var waves := director.waves
	var title := UiKit.label("LOADOUT STATION", 40, UiKit.AMBER, true)
	_kiosk_rows.add_child(title)
	_kiosk_rows.add_child(UiKit.label("Tickets: %d" % director.tickets, 28, UiKit.CREAM))
	_kiosk_rows.add_child(UiKit.spacer(8))
	var ammo_note := "full" if player.weapons.is_ammo_full() else "%d tickets" % waves.ammo_topup_price
	_kiosk_rows.add_child(_kiosk_row("E", "Energy top-up", ammo_note, director.tickets >= waves.ammo_topup_price and not player.weapons.is_ammo_full()))
	var heal_note := "%d tickets" % waves.heal_price
	var can_heal := director.tickets >= waves.heal_price and director.heals_left() > 0 and player.health < player.max_health
	if director.heals_left() <= 0:
		heal_note = "sold out"
	elif player.health >= player.max_health:
		heal_note = "full"
	_kiosk_rows.add_child(_kiosk_row("Q", "Boardwalk snack (+%d health)" % int(waves.heal_amount), heal_note, can_heal))
	_kiosk_rows.add_child(UiKit.spacer(8))
	_kiosk_rows.add_child(_kiosk_swap())


## Free swap: cycle the held slot through every unlocked weapon.
func _kiosk_swap() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var w := player.weapons
	var options := director.station_weapons()
	var slot_name := String(Loadout.SLOT_NAMES[w.active_slot]).to_upper()
	box.add_child(UiKit.label("FREE WEAPON SWAP  ·  %s" % slot_name, 26, UiKit.CYAN, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var can := options.size() > 1
	row.add_child(_key_chip(Loadout.key_hint(&"kiosk_prev").get_slice(" / ", 0), can))
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.INK, 0.8), w.current.tracer_color, 12, 3, 6))
	var name_row := HBoxContainer.new()
	card.add_child(name_row)
	var arrow_l := UiKit.label("◀", 24, UiKit.CREAM if can else Color(1, 1, 1, 0.3))
	name_row.add_child(arrow_l)
	var title := UiKit.label(w.current.display_name.to_upper(), 30, Color.WHITE, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(title)
	var arrow_r := UiKit.label("▶", 24, UiKit.CREAM if can else Color(1, 1, 1, 0.3))
	name_row.add_child(arrow_r)
	row.add_child(card)
	row.add_child(_key_chip(Loadout.key_hint(&"kiosk_next").get_slice(" / ", 0), can))
	box.add_child(row)
	var index := options.find(w.current) + 1
	var note := "%s  ·  %d unlocked to choose from" % [w.current.category, options.size()]
	if index > 0:
		note = "%s  ·  %d of %d" % [w.current.category, index, options.size()]
	if not can:
		note = "Level up to unlock more weapons"
	box.add_child(UiKit.label(note, 24, UiKit.AMBER))
	box.add_child(UiKit.label("1 / 2 picks the slot to swap", 22, Color(1, 1, 1, 0.6)))
	return box


func _key_chip(key: String, enabled: bool) -> Label:
	var chip := UiKit.label(key, 26, UiKit.INK, true)
	chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.custom_minimum_size = Vector2(44, 40)
	chip.add_theme_stylebox_override("normal", UiKit.box(UiKit.CREAM if enabled else Color(0.6, 0.58, 0.7), Color.TRANSPARENT, 8, 0, 2))
	chip.add_theme_constant_override("shadow_offset_y", 0)
	return chip


func _kiosk_row(key: String, text: String, note: String, enabled: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_key_chip(key, enabled))
	var l := UiKit.label(text, 28, Color.WHITE if enabled else Color(1, 1, 1, 0.55))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	if note != "":
		row.add_child(UiKit.label(note, 26, UiKit.AMBER if enabled else Color(1, 1, 1, 0.5)))
	return row


# --- signal handlers --------------------------------------------------------------

func _on_state_changed(state: RunDirector.State) -> void:
	_intermission.visible = state == RunDirector.State.PREP or state == RunDirector.State.BREAK
	_objective.visible = state == RunDirector.State.EXTRACTION
	_portal_marker.visible = state == RunDirector.State.EXTRACTION
	_controls.visible = state == RunDirector.State.PREP
	if state == RunDirector.State.PREP:
		_wave.text = "WAVE 01"


func _on_wave_started(number: int, total: int, banner: String) -> void:
	_wave.text = "WAVE %02d" % number
	var text := banner if banner != "" else ("FINAL WAVE" if number == total else "WAVE %d" % number)
	_show_banner(text, UiKit.PINK_LIGHT if number == total else Color.WHITE)


func _on_tickets_changed(tickets: int) -> void:
	_tickets.text = "TICKETS %d" % tickets


func _on_health_changed(current: float, maximum: float) -> void:
	_health.value = current / maximum


func _on_damaged(_amount: float, source: Vector3) -> void:
	_hurt = 1.0
	_health.flash = 1.0
	_threats.add_hit(source)


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	_ammo.text = "%d / %d" % [magazine, reserve]
	_ammo.add_theme_color_override("font_color", UiKit.RED if magazine == 0 else Color.WHITE)


func _on_notice(text: String, kind: StringName) -> void:
	if kind == &"banner":
		_show_banner(text, UiKit.CYAN)
		return
	var color := UiKit.CREAM
	if kind == &"good":
		color = UiKit.GREEN
	elif kind == &"bad":
		color = UiKit.RED
	_notice.text = text
	_notice.add_theme_color_override("font_color", color)
	if _notice_tween and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(2.2)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.5)


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(1.25, 1.25)
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.18)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(2.0)
	_banner_tween.chain().tween_property(_banner, "modulate:a", 0.0, 0.5)


func _on_reward_unlocked(weapon: WeaponData, reward: CosmeticItem) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.NAVY, 0.92), UiKit.CYAN, 18, 3, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	panel.add_child(v)
	v.add_child(UiKit.label("MASTERY UNLOCK", 24, UiKit.CYAN, true))
	v.add_child(UiKit.label("%s — %s" % [weapon.display_name, reward.display_name], 28, Color.WHITE))
	v.add_child(UiKit.label("%s · equip it in the Locker" % reward.slot_label(), 22, UiKit.CREAM))
	_toasts.add_child(panel)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.tween_interval(4.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)
