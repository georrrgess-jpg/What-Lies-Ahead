extends Control
## In-run progression HUD (registered by data/ui/hud_progression.tres):
##   - a compact level badge with an XP bar above the health bar; score XP
##     earned since the last wave clear shows as a pending "+N" segment,
##   - one "+N XP" popup per bank (wave clears), never per kill,
##   - LEVEL UP and RANK UP toasts in the level / tier colour. They wait for
##     a calm moment (never mid-wave), several levels or ranks gained at once
##     share one toast, they play one at a time and at most MAX_QUEUED wait
##     (the least important is dropped: the results screen lists everything),
##   - milestone-complete cards on the left (contracts are shown by the
##     Sparks widget, scripts/economy/sparks_hud.gd).

const MARGIN := 48.0
const BADGE_BOTTOM := -128.0
const TOAST_Y := 336.0
const TOAST_HOLD := 2.1
const TICK_INTERVAL := 0.07
## Toasts allowed to wait for their turn.
const MAX_QUEUED := 3
const LEVEL_PRIORITY := 100
## Below the contracts list of the Sparks widget.
const CARDS_TOP := 372.0

var _emblem: LevelEmblem
var _level_label: Label
var _pending_label: Label
var _bar: ProgressBar
var _ghost: ProgressBar
var _badge: Control
var _toast_layer: Control
var _challenges: VBoxContainer
var _director: RunDirector
## Waiting toasts as [priority, builder], most important first.
var _queue: Array = []
var _rank_pending := {}
var _level_pending := 0
var _levels_gained := 0
var _toast_busy := false
var _shown_xp := 0.0
var _target_xp := 0
var _pending := 0
var _tick := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_badge()
	_toast_layer = Control.new()
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_toast_layer)
	_challenges = VBoxContainer.new()
	_challenges.add_theme_constant_override("separation", 10)
	_challenges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_challenges.position = Vector2(MARGIN, CARDS_TOP)
	add_child(_challenges)
	_target_xp = Progression.xp()
	_shown_xp = _target_xp
	_refresh_badge()


func bind(director: RunDirector, _player: Player) -> void:
	_director = director
	Progression.xp_changed.connect(_on_xp_changed)
	Progression.level_up.connect(_on_level_up)
	Progression.xp_banked.connect(_on_xp_banked)
	Progression.pending_changed.connect(_on_pending_changed)
	Progression.challenge_completed.connect(_on_challenge_completed)
	Mastery.rank_up.connect(_on_rank_up)


func _process(delta: float) -> void:
	if not _toast_busy and not _queue.is_empty() and _calm():
		_next_toast()
	if _shown_xp >= _target_xp:
		return
	var gap := _target_xp - _shown_xp
	_shown_xp = minf(_target_xp, _shown_xp + maxf(300.0, gap * 2.4) * delta)
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK_INTERVAL
		Sfx.play(&"prog_xp_tick", -15.0, 0.9 + 0.5 * _bar.value)
	_refresh_badge()


# --- badge ---------------------------------------------------------------------

func _build_badge() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_left = MARGIN + 2.0
	row.offset_top = BADGE_BOTTOM
	row.offset_bottom = BADGE_BOTTOM
	_badge = row
	_emblem = LevelEmblem.new(Progression.level(), 64.0)
	row.add_child(_emblem)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	var top := HBoxContainer.new()
	info.add_child(top)
	_level_label = UiKit.arcade_label("", 28, Color.WHITE)
	_level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_level_label)
	_pending_label = UiKit.arcade_label("", 24, ProgStyle.XP_COLOR)
	top.add_child(_pending_label)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(310, 12)
	info.add_child(stack)
	_ghost = ProgStyle.bar(12.0, Color(ProgStyle.XP_COLOR, 0.35))
	_ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_ghost)
	_bar = UiKit.progress(0.0, 12.0, ProgStyle.XP_COLOR)
	_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_bar)


func _refresh_badge() -> void:
	var shown := int(_shown_xp)
	var lvl := Progression.level_for_xp(shown)
	if lvl != _emblem.level:
		_emblem.level = lvl
		_emblem.flash = 1.0
	_level_label.text = "LEVEL %d" % lvl
	_bar.value = Progression.progress_for_xp(shown)
	var with_pending := shown + _pending
	_ghost.value = 1.0 if Progression.level_for_xp(with_pending) > lvl else Progression.progress_for_xp(with_pending)
	_pending_label.text = "+%s" % ProgStyle.num(_pending) if _pending > 0 else ""


func _on_xp_changed(total: int) -> void:
	_target_xp = total


func _on_pending_changed(amount: int) -> void:
	_pending = amount
	_refresh_badge()


func _on_xp_banked(amount: int, caption: String) -> void:
	if amount <= 0:
		return
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(UiKit.arcade_label("+%s XP" % ProgStyle.num(amount), 46, ProgStyle.XP_COLOR))
	box.add_child(UiKit.arcade_label(caption, 22, UiKit.CREAM))
	add_child(box)
	box.position = Vector2(MARGIN + 84.0, size.y + BADGE_BOTTOM - 150.0)
	box.pivot_offset = Vector2(0, 40)
	box.scale = Vector2.ONE * 1.4
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.set_parallel(true)
	tw.tween_property(box, "modulate:a", 1.0, 0.12)
	tw.tween_property(box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.3)
	tw.chain().tween_property(box, "position:y", box.position.y + 60.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(box, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(box.queue_free)
	Sfx.play(&"prog_xp_bank", -6.0)


# --- toasts --------------------------------------------------------------------

func _on_level_up(lvl: int) -> void:
	# Several levels at once (a big bank) show as one toast for the highest.
	var queued := _level_pending > 0
	_level_pending = lvl
	_levels_gained += 1
	if not queued:
		_enqueue(LEVEL_PRIORITY, _level_toast)


func _on_rank_up(weapon: WeaponData, rank: int) -> void:
	# Several ranks at once show as one toast for the highest.
	var queued := _rank_pending.has(weapon.id)
	_rank_pending[weapon.id] = rank
	if not queued:
		_enqueue(rank, _rank_toast.bind(weapon))


func _level_toast() -> Control:
	Sfx.play(&"prog_level_up", -2.0)
	var panel := ProgToasts.level_up(_level_pending, _levels_gained)
	panel.set_meta("confetti", true)
	_level_pending = 0
	_levels_gained = 0
	return panel


func _rank_toast(weapon: WeaponData) -> Control:
	var rank := int(_rank_pending.get(weapon.id, Mastery.rank(weapon.id)))
	_rank_pending.erase(weapon.id)
	var tier := Mastery.tier(rank)
	Sfx.play(tier.sound if tier else &"unlock", -2.0)
	return ProgToasts.rank_up(weapon, rank)


## Queues a toast; the most important go first and the queue is capped.
func _enqueue(priority: int, builder: Callable) -> void:
	var at := 0
	while at < _queue.size() and int(_queue[at][0]) >= priority:
		at += 1
	_queue.insert(at, [priority, builder])
	while _queue.size() > MAX_QUEUED:
		_drop(_queue.pop_back()[1])


## Forgets what a dropped toast was going to announce.
func _drop(builder: Callable) -> void:
	for weapon in builder.get_bound_arguments():
		if weapon is WeaponData:
			_rank_pending.erase(weapon.id)


## Toasts cover the middle of the screen, so they wait until no wave is running.
func _calm() -> bool:
	return not is_instance_valid(_director) or _director.state != RunDirector.State.WAVE


func _next_toast() -> void:
	if _queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	var panel: Control = _queue.pop_front()[1].call()
	_toast_layer.add_child(panel)
	panel.size = panel.get_combined_minimum_size()
	panel.position = Vector2((size.x - panel.size.x) * 0.5, TOAST_Y)
	ProgToasts.animate(panel, TOAST_HOLD).finished.connect(panel.queue_free)
	if panel.has_meta("confetti"):
		ProgToasts.confetti(_toast_layer, panel.position + panel.size * Vector2(0.5, 0.6))
	get_tree().create_timer(TOAST_HOLD + 0.35, false).timeout.connect(func(): _toast_busy = false)


func _on_challenge_completed(ch: Challenge, weapon_id: StringName) -> void:
	var card := ProgToasts.challenge(ch, weapon_id)
	_challenges.add_child(card)
	while _challenges.get_child_count() > 2:
		_challenges.get_child(0).free()
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.2)
	tw.tween_interval(4.2)
	tw.tween_property(card, "modulate:a", 0.0, 0.5)
	tw.tween_callback(card.queue_free)
	Sfx.play(&"prog_challenge", -3.0)
