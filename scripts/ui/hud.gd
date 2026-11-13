extends CanvasLayer
## In-game HUD. Built from the UI kit, but light: neon chips and outlined
## arcade lettering over the play area, kit panels only for the loadout
## station. Zones on the 1920x1080 canvas:
##
##   upper left    wave header: WAVE 03 / 08, round chip, zombies left
##   top centre    objective pill (what to do now, countdown, portal distance),
##                 under it the "top" widget slot, under that the banner zone
##   upper right   score, combo meter, the "right" widget slot, award feed;
##                 below them the notice stack (notices, unlocks: at most 3)
##   left          the loadout station panel (only while standing at it)
##   centre        reticle, reload ring, weapon aids, damage and threat arcs
##   lower left    health cells with the overshield strip (the level badge of
##                 the progression widget sits right above them)
##   lower right   tickets and damage boost chips, the two weapon slots, ammo
##
## Extension widgets (UiExtension HUD_WIDGET, see add_widget):
##   * a widget with `func hud_slot() -> StringName` goes where it asks:
##       &"top"      stacked under the objective pill, centred (a boss health
##                   bar: up to about 900 x 70)
##       &"right"    stacked under the combo meter, right-aligned (a Sparks
##                   counter: a chip up to about 420 x 56)
##       &"overlay"  full screen; the widget places itself
##   * a widget without hud_slot() that anchors itself in _init/_ready (the
##     progression widget covers the whole screen) is an overlay;
##   * anything else gets a default place: "top" if it is at least
##     WIDE_WIDGET wide, otherwise "right".
##   Keep overlays out of the zones above; the free areas are the left edge
##   between y 190 and 880 while the station is closed, and the bottom centre.
##
## What the run director's `notice(text, kind)` does here:
##   &"info" / &"good" / &"bad"   a line in the notice stack
##   &"banner" (or "banner_<style>", styles in HudBanner.STYLES)
##                               a big banner; "TITLE — SUBTITLE" or a line
##                               break splits it. One sent within 0.4 s of a
##                               wave start keeps "WAVE n" as its kicker and
##                               names the round in the wave header.
##   &"objective"                replaces the objective text until the run
##                               changes state ("" restores the default)
##   &"round"                    sets the round chip of the wave header

const MARGIN := 48.0
const BOOST_COLOR := Color(1.0, 0.42, 0.12)
const HEADSHOT_COLOR := Color(1.0, 0.45, 0.7)
## Health share under which the screen edge pulses red.
const LOW_HEALTH := 0.25
## A widget at least this wide goes to the "top" slot by default.
const WIDE_WIDGET := 480.0
## The reload / empty prompts under the reticle.
const STATUS_TEXTS: Array[String] = ["", "RELOADING", "VENTING HEAT", "EMERGENCY RECHARGE", "OUT OF ENERGY — RECHARGING", "RELOAD"]

var director: RunDirector
var player: Player

var _root: Control
## Everything that belongs to play; faded out when the run ends.
var _play: Control
var _header: HudWave
## The header's "WAVE 03" label and a stand-in for the newest notice; the
## staging tools (scripts/dev/screenshot.gd, tools/neon_stage_shot.gd) set
## their text.
var _wave: Label
var _notice: _NoticeProxy
var _objective: HudObjective
var _top_slot: VBoxContainer
var _health: SegmentBar
var _ammo: HudAmmo
var _slots: WeaponSlots
var _weapon_hud: WeaponHud
var _tickets: Label
var _tickets_chip: PanelContainer
var _boost: PanelContainer
var _boost_text: Label
var _boost_tween: Tween
var _boost_glow: BoostGlow
var _reticle: Reticle
var _score_panel: ScorePanel
var _kiosk_marker: Waypoint
var _portal_marker: Waypoint
var _threats: ThreatRing
var _reload_arc: ReloadArc
var _banner: HudBanner
var _stack: HudStack
var _status: Label          # reload / empty prompt under the reticle
var _status_key: Control
var _station: StationPanel
var _controls: Control
var _vignette: TextureRect
var _thumbs: WeaponThumbs
var _hurt := 0.0
var _vignette_alpha := 0.0
var _status_code := 0
var _wave_total := 0
var _wave_start_msec := -100000
var _custom_objective := ""
var _objective_key := -1
var _station_key := -1
var _station_weapon: WeaponData
var _shown_tickets := -1
var _clear_award := ""


func _ready() -> void:
	layer = 5
	add_to_group(&"hud")
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.apply(_root)
	add_child(_root)
	_build()


func bind(run: RunDirector, p: Player) -> void:
	director = run
	player = p
	_threats.player = p
	_threats.director = run
	_boost_glow.player = p
	run.wave_started.connect(_on_wave_started)
	run.tickets_changed.connect(_on_tickets_changed)
	run.notice.connect(_on_notice)
	run.reward_unlocked.connect(_on_reward_unlocked)
	run.state_changed.connect(_on_state_changed)
	run.overshield_changed.connect(_on_overshield_changed)
	run.damage_boost_changed.connect(_on_damage_boost_changed)
	run.run_finished.connect(_on_run_finished)
	Events.enemy_killed.connect(_on_enemy_killed)
	_build_controls(run.level)
	_station.configure(_station_offers())
	KillPopup.warm_up(run.get_parent(), p.camera.global_position - p.camera.global_transform.basis.z * 3.0)
	if run.score:
		_score_panel.bind(run.score)
		run.score.award.connect(_on_award)
	_kiosk_marker.camera = p.camera
	_kiosk_marker.target = run.kiosk
	_portal_marker.camera = p.camera
	_portal_marker.target = run.portal
	p.health_changed.connect(_on_health_changed)
	p.damaged.connect(_on_damaged)
	p.shield_hit.connect(_on_shield_hit)
	p.weapons.ammo_changed.connect(_on_ammo_changed)
	p.weapons.weapon_changed.connect(_on_weapon_changed)
	_slots.bind(p.weapons)
	_weapon_hud.bind(p, _ammo)
	p.weapons.hit_confirmed.connect(_reticle.show_hit)
	p.weapons.fired.connect(p.view.on_fired)
	p.weapons.reload_started.connect(p.view.play_reload)
	p.weapons.weapon_changed.connect(p.view.show_weapon)
	if p.weapons.current:
		_on_weapon_changed(p.weapons.current)
		p.view.show_weapon(p.weapons.current)
	_on_health_changed(p.health, p.max_health)
	_on_tickets_changed(run.tickets)
	_on_overshield_changed(run.overshield, run.waves.overshield_amount)
	_on_damage_boost_changed(run.damage_boost)
	_on_state_changed(run.state)
	_thumbs.bake(Loadout.available())


## Adds an extension widget (a HUD_WIDGET UiExtension) to the HUD. Where it
## goes is described at the top of this file: the slot it asks for with
## hud_slot(), the whole screen if it anchors itself, or a default slot.
func add_widget(widget: Control) -> void:
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot: StringName = widget.hud_slot() if widget.has_method("hud_slot") else &""
	if slot == &"":
		# Let the widget set itself up, then see whether it took a place.
		_play.add_child(widget)
		if widget.anchor_right > 0.0 or widget.anchor_bottom > 0.0 or widget.position != Vector2.ZERO:
			return
		slot = &"top" if widget.get_combined_minimum_size().x >= WIDE_WIDGET else &"right"
		_play.remove_child(widget)
	match slot:
		&"top":
			widget.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_top_slot.add_child(widget)
		&"right":
			widget.size_flags_horizontal = Control.SIZE_SHRINK_END
			_score_panel.extras.add_child(widget)
		_:
			_play.add_child(widget)


## Shows a card (an unlock toast, a challenge card) in the notice stack.
func push_card(card: Control, seconds := 4.5) -> void:
	_stack.push_card(card, HudStack.Priority.REWARD, seconds)


## What the objective pill asks of the player right now (for the pause menu).
func objective_text() -> String:
	return _objective.current()


## Names the round in the wave header ("BLITZ", "BOSS ROUND"); "" clears it.
func set_round_type(text: String, color := UiKit.CYAN) -> void:
	_header.set_chip(text.to_upper(), color)


## Hides the wave counter and clears the start-of-run notices (the tutorial
## shows its own objective card there).
func hide_wave_counter() -> void:
	_header.visible = false
	_stack.clear()


## Level start: hold black for a few frames (while FxWarmup compiles shaders
## underneath), then fade the world in.
func fade_in() -> void:
	var black := ColorRect.new()
	black.color = Color(0.04, 0.02, 0.08)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(black)
	_play.modulate.a = 0.0
	var tw := black.create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(black, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(_play, "modulate:a", 1.0, 0.4).set_delay(0.15)
	tw.tween_callback(black.queue_free)


# --- construction ---------------------------------------------------------------

func _anchor(c: Control, preset: Control.LayoutPreset, offset: Vector2, grow_h := Control.GROW_DIRECTION_END, grow_v := Control.GROW_DIRECTION_END, parent: Control = null) -> void:
	(parent if parent else _play).add_child(c)
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
	_build_vignette()
	_play = Control.new()
	_play.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_play)
	_build_markers()
	_build_top()
	_build_bottom()
	_build_centre()
	_station = StationPanel.new()
	_anchor(_station, Control.PRESET_TOP_LEFT, Vector2(MARGIN - 6.0, 190))
	_thumbs = WeaponThumbs.new()
	add_child(_thumbs)
	# The banner stays up after play has faded (level cleared, defeat).
	_banner = HudBanner.new()
	_root.add_child(_banner)
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_left = 0
	_banner.offset_right = 0
	_banner.offset_top = 178
	_banner.offset_bottom = 408
	_notice = _NoticeProxy.new()
	_notice.stack = _stack


## Damage vignette (behind everything else).
func _build_vignette() -> void:
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


## World markers (loadout station during breaks, portal during extraction).
func _build_markers() -> void:
	_kiosk_marker = Waypoint.new()
	_kiosk_marker.label = "LOADOUT STATION"
	_kiosk_marker.visible = false
	_play.add_child(_kiosk_marker)
	_portal_marker = Waypoint.new()
	_portal_marker.label = "EXIT PORTAL"
	_portal_marker.icon = "portal"
	_portal_marker.color = UiKit.CYAN
	_portal_marker.offset = Vector3(0, 4.6, 0)
	_portal_marker.visible = false
	_play.add_child(_portal_marker)


## Upper left: wave. Top centre: objective and the "top" widget slot.
## Upper right: score, combo, the "right" widget slot, awards, notices.
func _build_top() -> void:
	_header = HudWave.new()
	_wave = _header.title
	_anchor(_header, Control.PRESET_TOP_LEFT, Vector2(MARGIN, 10))
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	_anchor(top, Control.PRESET_CENTER_TOP, Vector2(0, 22), Control.GROW_DIRECTION_BOTH)
	_objective = HudObjective.new()
	_objective.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_objective.visible = false
	top.add_child(_objective)
	_top_slot = VBoxContainer.new()
	_top_slot.add_theme_constant_override("separation", 8)
	_top_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_top_slot)
	_score_panel = ScorePanel.new()
	_score_panel.custom_minimum_size = Vector2(420, 0)
	_anchor(_score_panel, Control.PRESET_TOP_RIGHT, Vector2(-MARGIN, 6), Control.GROW_DIRECTION_BEGIN)
	_stack = HudStack.new()
	_anchor(_stack, Control.PRESET_TOP_RIGHT, Vector2(-MARGIN, 396), Control.GROW_DIRECTION_BEGIN)


## Lower left: health. Lower right: chips, weapon slots, ammo.
func _build_bottom() -> void:
	_health = SegmentBar.new()
	_health.custom_minimum_size = Vector2(450, 70)
	_anchor(_health, Control.PRESET_BOTTOM_LEFT, Vector2(MARGIN, -MARGIN), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	var corner := VBoxContainer.new()
	corner.add_theme_constant_override("separation", 8)
	_anchor(corner, Control.PRESET_BOTTOM_RIGHT, Vector2(-MARGIN, -MARGIN + 14.0), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_END
	chips.add_theme_constant_override("separation", 10)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_child(chips)
	_boost = _pill(BOOST_COLOR, &"boost")
	_boost_text = _boost.get_child(0).get_child(1) as Label
	_boost.visible = false
	chips.add_child(_boost)
	_boost_glow = BoostGlow.new()
	add_child(_boost_glow)
	_tickets_chip = _pill(UiKit.AMBER, &"ticket")
	_tickets = _tickets_chip.get_child(0).get_child(1) as Label
	chips.add_child(_tickets_chip)
	_slots = WeaponSlots.new()
	corner.add_child(_slots)
	_ammo = HudAmmo.new()
	_ammo.size_flags_horizontal = Control.SIZE_SHRINK_END
	corner.add_child(_ammo)
	# Charge ring, heat gauge, burst pips and seek lock (drawn over everything).
	_weapon_hud = WeaponHud.new()
	_play.add_child(_weapon_hud)


## A dark pill with an icon and a number or a word, outlined in `accent`.
func _pill(accent: Color, icon: StringName) -> PanelContainer:
	var pill := PanelContainer.new()
	var box := UiKit.box(Color(UiKit.INK, 0.72), Color(accent, 0.9), 22, 2, 2)
	box.content_margin_left = 12
	box.content_margin_right = 16
	pill.add_theme_stylebox_override("panel", box)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	row.add_child(HudIcon.make(icon, 30.0, accent))
	var text := UiKit.label("", 30, accent.lerp(Color.WHITE, 0.25), true)
	text.add_theme_constant_override("shadow_offset_y", 2)
	row.add_child(text)
	return pill


## Centre: reticle, reload ring, threat arcs and the status prompt.
func _build_centre() -> void:
	_reticle = Reticle.new()
	_reticle.custom_minimum_size = Vector2(120, 120)
	_anchor(_reticle, Control.PRESET_CENTER, Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	_reload_arc = ReloadArc.new()
	_reload_arc.custom_minimum_size = Vector2(120, 120)
	_anchor(_reload_arc, Control.PRESET_CENTER, Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	_threats = ThreatRing.new()
	_threats.custom_minimum_size = Vector2(ThreatRing.WARN_RADIUS, ThreatRing.WARN_RADIUS) * 2.0
	_anchor(_threats, Control.PRESET_CENTER, Vector2.ZERO, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 10)
	_anchor(status, Control.PRESET_CENTER, Vector2(0, 112), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	_status_key = UiKit.key_glyph(_short_key(&"reload"), 44.0)
	_status_key.visible = false
	status.add_child(_status_key)
	_status = UiKit.arcade_label("", 30, UiKit.AMBER)
	status.add_child(_status)


## The first-wave reminder of the keys, as key caps along the bottom.
func _build_controls(level: LevelData) -> void:
	var plate := PanelContainer.new()
	var box := UiKit.box(Color(UiKit.INK, 0.6), Color.TRANSPARENT, 26, 0, 6)
	box.content_margin_left = 22
	box.content_margin_right = 22
	plate.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)
	for entry in [["WASD", "Move"], ["SHIFT", "Sprint"], ["LMB", "Fire"], ["RMB", "Aim"], [_short_key(&"reload"), "Reload"],
			["1 / 2", "Switch"], [_short_key(&"start_wave"), "Start wave"], [_short_key(&"pause"), "Pause"]]:
		row.add_child(UiKit.key_prompt(entry[0], entry[1]))
	plate.visible = false
	plate.tooltip_text = level.display_name
	_controls = plate
	_anchor(plate, Control.PRESET_CENTER_BOTTOM, Vector2(0, -134), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)


## The first key bound to `action`, for prompts ("Escape" becomes "ESC").
func _short_key(action: StringName) -> String:
	var key := Loadout.key_hint(action).get_slice(" / ", 0)
	return "ESC" if key == "Escape" else key.to_upper()


## The four purchases of the station, in the order of their keys.
func _station_offers() -> Array:
	var waves := director.waves
	return [
		{"key": _short_key(&"interact"), "icon": &"bolt", "title": "ENERGY", "effect": "Refill your weapons", "accent": UiKit.CYAN},
		{"key": _short_key(&"interact_alt"), "icon": &"heart", "title": director.level.heal_item_name.to_upper(),
			"effect": "+%d health" % int(waves.heal_amount), "accent": UiKit.RED},
		{"key": _short_key(&"buy_overshield"), "icon": &"shield", "title": "OVERSHIELD",
			"effect": "+%d shield" % int(waves.overshield_amount), "accent": SegmentBar.SHIELD_COLOR},
		{"key": _short_key(&"buy_damage_boost"), "icon": &"boost", "title": "DAMAGE BOOST",
			"effect": "+%d%% next wave" % director.boost_percent(), "accent": BOOST_COLOR},
	]


# --- per-frame ------------------------------------------------------------------

func _process(delta: float) -> void:
	if director == null or player == null:
		return
	_feed_reticle()
	_update_vignette(delta)
	_update_weapon_status()
	_header.set_wave(director.wave_number, director.total_waves())
	if director.state == RunDirector.State.WAVE:
		var left := director.enemies_remaining()
		_wave_total = maxi(_wave_total, left)
		_header.set_remaining(left, _wave_total)
	_update_objective()
	# Loadout marker: during breaks, whenever the player is not already at it.
	var marker := director.is_intermission() and director.kiosk != null and not director.kiosk.player_inside
	if marker != _kiosk_marker.visible:
		_kiosk_marker.visible = marker
	var at_station := director.kiosk_available()
	_update_station(at_station)
	# The reminder repeats keys the station panel shows: one of them at a time.
	var remind := director.state == RunDirector.State.PREP and not at_station
	if remind != _controls.visible:
		_controls.visible = remind


func _feed_reticle() -> void:
	# Reticle gap = the real spread cone projected onto the screen.
	var spread_deg := player.weapons.current_spread()
	var half_h := get_viewport().get_visible_rect().size.y * 0.5
	_reticle.spread_px = tan(deg_to_rad(spread_deg)) / tan(deg_to_rad(player.camera.fov * 0.5)) * half_h
	_reticle.aim = player.ads
	if player.weapons.current:
		var pick := String(Settings.value("reticle_style"))
		_reticle.style = player.weapons.current.reticle_style if pick == "auto" else pick


## Health vignette: a brief flash on damage plus a steady pulse when low.
func _update_vignette(delta: float) -> void:
	_hurt = maxf(0.0, _hurt - delta * 1.8)
	var alpha := _hurt * Settings.flash_scale()
	if not player.alive:
		alpha = 0.7
	elif player.health <= player.max_health * LOW_HEALTH:
		alpha = maxf(alpha, 0.25 + 0.12 * sin(Time.get_ticks_msec() * 0.006))
	if not is_equal_approx(alpha, _vignette_alpha):
		_vignette_alpha = alpha
		_vignette.modulate.a = alpha


## Reload ring, the ammo bar's reload fill and the prompt under the reticle.
func _update_weapon_status() -> void:
	var w := player.weapons
	var reloading := w.is_reloading()
	var progress := w.reload_progress() if reloading else -1.0
	_reload_arc.progress = progress
	_ammo.reload = progress
	var code := 0
	if w.current == null:
		code = 0
	elif reloading:
		code = 2 if w.current.uses_heat() else 1
	elif w.is_emergency_recharging():
		code = 3 if w.magazine() > 0 else 4
	elif w.magazine() <= maxi(1, w.current.magazine_size / 4) and w.reserve() > 0:
		code = 5
	if code != _status_code:
		_status_code = code
		_status.text = STATUS_TEXTS[code]
		_status_key.visible = code == 5


## The objective pill follows the run's state; texts are rebuilt only when
## the number they show changes.
func _update_objective() -> void:
	var state := director.state
	var number := 0
	match state:
		RunDirector.State.PREP, RunDirector.State.BREAK:
			number = int(ceil(director.countdown))
		RunDirector.State.WAVE:
			number = director.enemies_remaining()
			number = number if number <= 3 else 4
		RunDirector.State.EXTRACTION:
			number = int(player.global_position.distance_to(director.portal.global_position)) if director.portal else 0
	var key := int(state) * 100000 + number
	if key == _objective_key:
		return
	_objective_key = key
	match state:
		RunDirector.State.PREP, RunDirector.State.BREAK:
			var next := director.wave_number + 1
			var name := "FINAL WAVE" if next == director.total_waves() else "WAVE %d" % next
			var text := _custom_objective if _custom_objective != "" else ("GET READY" if state == RunDirector.State.PREP else "INTERMISSION")
			_objective.set_objective(&"clock", text, UiKit.CYAN, "%s IN %d" % [name, number], _short_key(&"start_wave"), "Start now")
			_station.set_next_wave("START %s" % name, number, _short_key(&"start_wave"))
		RunDirector.State.WAVE:
			if _custom_objective != "":
				_objective.set_objective(&"zombie", _custom_objective, UiKit.CYAN)
			elif number >= 1 and number <= 3:
				_objective.set_objective(&"zombie", "HUNT DOWN THE LAST %d" % number if number > 1 else "ONE ZOMBIE LEFT", UiKit.AMBER)
			else:
				_objective.set_objective(&"zombie", "CLEAR THE WAVE", UiKit.CYAN)
		RunDirector.State.EXTRACTION:
			var text := _custom_objective if _custom_objective != "" else "REACH THE PORTAL"
			_objective.set_objective(&"portal", text, UiKit.CYAN, "%d m" % number)
		_:
			_objective.set_objective(&"zombie", "")


## Opens and closes the station panel and keeps it current. The panel's
## values are pushed only when one of them changed.
func _update_station(show: bool) -> void:
	if not show:
		_station.close()
		_station_key = -1
		return
	_station.open()
	var w := player.weapons
	var waves := director.waves
	var tickets := director.tickets
	var ammo_full := w.is_ammo_full()
	var health_full := player.health >= player.max_health
	var shield_full := director.overshield >= waves.overshield_amount
	var key := (((((tickets * 2 + w.active_slot) * 8 + director.heals_left()) * 2 + int(ammo_full)) * 2 + int(health_full)) * 2 + int(shield_full)) * 4 + int(director.damage_boost)
	if key == _station_key and w.current == _station_weapon:
		return
	_station_key = key
	_station_weapon = w.current
	_station.set_tickets(tickets)
	_station.set_offer(0, _offer_state(ammo_full, tickets, waves.ammo_topup_price), waves.ammo_topup_price, "FULL")
	var heal_note := "SOLD OUT" if director.heals_left() <= 0 else "FULL"
	_station.set_offer(1, _offer_state(director.heals_left() <= 0 or health_full, tickets, waves.heal_price), waves.heal_price, heal_note)
	_station.set_offer(2, _offer_state(shield_full, tickets, waves.overshield_price), waves.overshield_price, "FULL")
	_station.set_offer(3, _offer_state(director.damage_boost != RunDirector.Boost.NONE, tickets, waves.damage_boost_price), waves.damage_boost_price, "LOADED")
	var options := director.station_weapons()
	_thumbs.bake(options)
	_station.set_swap("%s  ·  slot %d" % [String(Loadout.SLOT_NAMES[w.active_slot]).to_upper(), w.active_slot + 1], options, options.find(w.current),
		_short_key(&"kiosk_prev"), _short_key(&"kiosk_next"))


func _offer_state(done: bool, tickets: int, price: int) -> StationCard.State:
	if done:
		return StationCard.State.DONE
	return StationCard.State.BUY if tickets >= price else StationCard.State.POOR


# --- signal handlers --------------------------------------------------------------

func _on_state_changed(state: RunDirector.State) -> void:
	_custom_objective = ""
	_objective_key = -1
	_portal_marker.visible = state == RunDirector.State.EXTRACTION
	match state:
		RunDirector.State.WAVE:
			_header.set_chip("", UiKit.CYAN)
		RunDirector.State.PREP:
			_header.set_remaining(-1, 0)
			_header.set_chip("GET READY", UiKit.CYAN)
		RunDirector.State.BREAK:
			_header.set_remaining(-1, 0)
			_header.set_chip("INTERMISSION", UiKit.CYAN)
		RunDirector.State.EXTRACTION:
			_header.set_remaining(-1, 0)
			_header.set_chip("ALL WAVES CLEARED", UiKit.GREEN)


## Round intro. A wave's banner text reads "KICKER — NAME: HINT"; the name
## also labels the round in the wave header.
func _on_wave_started(number: int, total: int, banner: String) -> void:
	_wave_start_msec = Time.get_ticks_msec()
	_wave_total = director.enemies_remaining()
	_header.set_wave(number, total)
	var final := number == total
	var kicker := "FINAL WAVE" if final else "WAVE %d" % number
	var title := kicker
	var sub := "%d ZOMBIES INCOMING" % _wave_total if _wave_total > 0 else ""
	var parts := HudBanner.split(banner)
	if parts[1] != "":
		kicker = parts[0]
		title = parts[1]
	elif parts[0] != "":
		title = parts[0]
	var hint := title.find(": ")
	if hint > 0:
		sub = title.substr(hint + 2)
		title = title.substr(0, hint)
	if title == kicker:
		kicker = ""
		_header.set_chip("FINAL WAVE" if final else "", UiKit.PINK)
	else:
		_header.set_chip(title, UiKit.PINK if final else UiKit.CYAN)
	_banner.show_banner(title, sub, kicker, &"final" if final else &"wave", HudBanner.HOLD, true)


func _on_tickets_changed(tickets: int) -> void:
	if tickets == _shown_tickets:
		return
	var gained := tickets > _shown_tickets and _shown_tickets >= 0
	_shown_tickets = tickets
	_tickets.text = str(tickets)
	if gained and _tickets_chip.is_visible_in_tree():
		UiFx.pulse(_tickets_chip, 1.08)


func _on_health_changed(current: float, maximum: float) -> void:
	_health.max_points = maximum
	_health.value = current / maximum


func _on_damaged(_amount: float, source: Vector3) -> void:
	_hurt = 1.0
	_health.flash = 1.0
	_threats.add_hit(source)


## The overshield soaked a hit: flash the shield strip, not the screen.
func _on_shield_hit(_absorbed: float, source: Vector3) -> void:
	_hurt = maxf(_hurt, 0.3)
	_health.shield_flash = 1.0
	_threats.add_hit(source)


func _on_overshield_changed(value: float, _maximum: float) -> void:
	_health.shield = value / maxf(1.0, player.max_health)
	_health.shield_flash = 1.0


func _on_damage_boost_changed(boost: RunDirector.Boost) -> void:
	_boost_glow.set_boost(boost)
	_boost.visible = boost != RunDirector.Boost.NONE
	if _boost_tween and _boost_tween.is_valid():
		_boost_tween.kill()
	_boost.modulate.a = 1.0
	if boost == RunDirector.Boost.ACTIVE:
		_boost_text.text = "DAMAGE +%d%%" % director.boost_percent()
		# Running: the chip breathes for the whole wave.
		_boost_tween = _boost.create_tween().set_loops()
		_boost_tween.tween_property(_boost, "modulate:a", 0.6, 0.4).set_trans(Tween.TRANS_SINE)
		_boost_tween.tween_property(_boost, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	elif boost == RunDirector.Boost.READY:
		_boost_text.text = "BOOST READY"
		UiFx.pulse(_boost, 1.12)


## Score popup above the zombie, with its headshot / combo flavour.
func _on_enemy_killed(enemy: Node, _weapon_id: StringName, headshot: bool, points: int) -> void:
	var z := enemy as Zombie
	if z == null or director == null or not z.is_inside_tree():
		return
	var flavour := "HEADSHOT" if headshot else ""
	if director.score and director.score.combo > 1:
		flavour = "HEADSHOT  x%.1f" % director.score.multiplier() if headshot else "COMBO x%.1f" % director.score.multiplier()
	var color := HEADSHOT_COLOR if headshot else UiKit.CYAN
	var head := z.global_position + Vector3.UP * (1.1 * z.data.body_scale + 0.9)
	KillPopup.spawn(z.get_parent(), head, points, z.data.tickets, flavour, color)


func _on_weapon_changed(weapon: WeaponData) -> void:
	_ammo.accent = weapon.tracer_color
	_on_ammo_changed(player.weapons.magazine(), player.weapons.reserve())


func _on_ammo_changed(magazine: int, reserve: int) -> void:
	var weapon := player.weapons.current
	_ammo.set_ammo(magazine, reserve, weapon.magazine_size if weapon else 1)


## The wave-clear award becomes the subtitle of the "WAVE n CLEARED" banner.
func _on_award(text: String, points: int, _color: Color) -> void:
	if text == "WAVE CLEAR" or text == "FLAWLESS WAVE":
		_clear_award = ("FLAWLESS!  +%d" if text == "FLAWLESS WAVE" else "+%d SCORE") % points


func _on_notice(text: String, kind: StringName) -> void:
	var kind_name := String(kind)
	if kind_name.begins_with("banner"):
		_show_notice_banner(text, StringName(kind_name.trim_prefix("banner").trim_prefix("_")))
	elif kind == &"objective":
		_custom_objective = text.to_upper()
		_objective_key = -1
	elif kind == &"round":
		set_round_type(text)
	else:
		var priority := HudStack.Priority.INFO
		if kind == &"good":
			priority = HudStack.Priority.GOOD
		elif kind == &"bad":
			priority = HudStack.Priority.BAD
			_station.deny()
		_stack.push(text, priority, _notice_icon(text))


func _show_notice_banner(text: String, style: StringName) -> void:
	var parts := HudBanner.split(text)
	if style == &"":
		style = HudBanner.style_for(text)
	var sub := parts[1]
	if style == &"cleared" and _clear_award != "":
		sub = _clear_award if sub == "" else "%s  ·  %s" % [_clear_award, sub]
		_clear_award = ""
	# A banner right after a wave start names the round in the header too.
	if Time.get_ticks_msec() - _wave_start_msec < int(HudBanner.MERGE_WINDOW * 1000.0):
		_header.set_chip(parts[0].to_upper(), UiKit.RED if style == &"boss" else UiKit.CYAN)
	_banner.show_banner(parts[0], sub, "", style)


## The icon that fits a notice ("" if none does).
func _notice_icon(text: String) -> StringName:
	var t := text.to_lower()
	if t.contains("ticket"):
		return &"ticket"
	if t.contains("shield"):
		return &"shield"
	if t.contains("boost"):
		return &"boost"
	if t.contains("energy"):
		return &"bolt"
	if t.contains("health"):
		return &"heart"
	return &""


func _on_reward_unlocked(weapon: WeaponData, reward: CosmeticItem) -> void:
	var card := UiKit.neon_panel(UiKit.AMBER)
	card.set_padding(20, 10)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -6)
	card.add_child(v)
	v.add_child(UiKit.label("MASTERY UNLOCK", 22, UiKit.AMBER, true))
	v.add_child(UiKit.label("%s — %s" % [weapon.display_name, reward.display_name], 28, Color.WHITE, true))
	v.add_child(UiKit.label("%s · equip it in the Locker" % reward.slot_label(), 20, UiKit.CREAM))
	push_card(card)


## The run is over: play steps aside and the outcome takes the screen until
## the results arrive.
func _on_run_finished(result: Dictionary) -> void:
	var tw := _play.create_tween()
	tw.tween_property(_play, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func(): _play.visible = false)
	if bool(result.get("abandoned", false)):
		return
	var level: LevelData = result["level"]
	if bool(result["victory"]):
		_banner.show_banner("LEVEL CLEARED!", level.display_name, "", &"victory", 0.4)
	else:
		_banner.show_banner("OVERRUN!", "Wave %d of %d" % [int(result["wave_reached"]), int(result["total_waves"])], level.display_name, &"defeat", 1.0)


## Lets the staging tools clear or set the notice line through `_notice.text`.
class _NoticeProxy:
	var stack: HudStack
	var text := "":
		set(v):
			text = v
			if v == "":
				stack.clear()
			else:
				stack.push(v)
