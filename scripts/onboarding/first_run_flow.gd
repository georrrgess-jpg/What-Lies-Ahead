class_name FirstRunFlow
extends Control
## The welcome for a brand-new profile, right after the intro: three punchy
## cards (who you are, the outbreak, Sparks) with art from the game, then the
## choice between Boot Camp (recommended) and going straight in, which starts
## the guided first deployment (coach marks on PLAY and DEPLOY).
## Enter / NEXT steps through, Esc or SKIP jumps to the choice.

const CARDS := [
	{"title": "WELCOME, RECRUIT", "art": "res://art/keyart/prize_pier.jpg",
		"text": "You just joined the Pier Patrol. Sunset, string lights, cotton candy. And zombies. Lots of zombies."},
	{"title": "THE OUTBREAK", "art": "res://art/keyart/neon_skyline.jpg",
		"text": "The tourists have turned, and five worlds are overrun. Good news: they pop into confetti."},
	{"title": "SPARKS", "art": "res://art/keyart/summit_lodge.jpg", "spark": true,
		"text": "Every zombie carries a stolen Spark: the glow in its eyes. Pop it and bank it, then spend Sparks on cosmetics. Never on power."},
]

var _index := 0
var _board: KitPanel
var _art: TextureRect
var _title: Label
var _text: Label
var _dots: HBoxContainer
var _buttons: HBoxContainer
var _spark: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 40
	var dim := ColorRect.new()
	dim.color = Color(UiKit.INK, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_board = UiKit.signboard()
	_board.set_padding(36, 30)
	center.add_child(_board)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.GAP_XL)
	_board.add_child(row)
	var frame := UiKit.metal_frame(10)
	row.add_child(frame)
	var art_box := Control.new()
	art_box.custom_minimum_size = Vector2(560, 420)
	art_box.clip_contents = true
	frame.add_child(art_box)
	_art = TextureRect.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art_box.add_child(_art)
	_spark = CenterContainer.new()
	_spark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spark.add_child(UiKit.spark_icon(220.0))
	art_box.add_child(_spark)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(520, 420)
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	row.add_child(col)
	col.add_child(UiKit.chip("PIER PATROL BRIEFING", UiKit.PINK, 20))
	_title = UiKit.sign_label("", UiKit.SIZE_TITLE)
	col.add_child(_title)
	_text = UiKit.body("", 500, 30, UiKit.CREAM)
	col.add_child(_text)
	col.add_child(UiKit.filler())
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", UiKit.GAP_S)
	col.add_child(_dots)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", UiKit.GAP_M)
	col.add_child(_buttons)
	_show_card(0)
	UiFx.pop_in(_board)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _index < CARDS.size():
			_show_card(CARDS.size())
		else:
			_skip_tutorial()


## Card `i` (CARDS.size() = the choice).
func _show_card(i: int) -> void:
	_index = i
	for c in _buttons.get_children():
		c.queue_free()
	for c in _dots.get_children():
		c.queue_free()
	for k in CARDS.size() + 1:
		_dots.add_child(UiKit.icon(&"icon_star" if k <= i else &"icon_star_empty", 28.0, UiKit.AMBER))
	if i < CARDS.size():
		var card: Dictionary = CARDS[i]
		_title.text = card["title"]
		_text.text = card["text"]
		_art.texture = load(card["art"]) if ResourceLoader.exists(card["art"]) else null
		_art.modulate = Color(1, 1, 1, 0.45) if card.get("spark", false) else Color.WHITE
		_spark.visible = card.get("spark", false)
		var next := UiKit.sign_button("NEXT", SignButton.Kind.PRIMARY, 34)
		next.name = "FirstFocus"
		next.pressed.connect(func(): _show_card(_index + 1))
		_buttons.add_child(next)
		var skip := UiKit.sign_button("SKIP", SignButton.Kind.NEUTRAL, 26)
		skip.pressed.connect(func(): _show_card(CARDS.size()))
		_buttons.add_child(skip)
		next.grab_focus.call_deferred()
	else:
		_title.text = "READY, RECRUIT?"
		_text.text = "Boot Camp is a 5-minute training run on the midway: moves, aiming, zombies and the Loadout Station. Skip it any time. It pays %d Sparks the first time." % Onboarding.REWARD_SPARKS
		_art.texture = load(CARDS[0]["art"])
		_art.modulate = Color.WHITE
		_spark.visible = false
		var play := UiKit.sign_button("PLAY THE TUTORIAL", SignButton.Kind.PRIMARY, 34)
		play.name = "FirstFocus"
		play.pressed.connect(_play_tutorial)
		_buttons.add_child(play)
		var skip := UiKit.sign_button("SKIP", SignButton.Kind.SECONDARY, 30)
		skip.name = "SkipTutorial"
		skip.pressed.connect(_skip_tutorial)
		_buttons.add_child(skip)
		var rec := UiKit.chip("RECOMMENDED", UiKit.CYAN, 18, false)
		rec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_buttons.add_child(rec)
		_buttons.move_child(rec, 1)
		play.grab_focus.call_deferred()
	UiFx.pulse(_title, 1.06)


func _play_tutorial() -> void:
	Onboarding.start_tutorial()


func _skip_tutorial() -> void:
	Onboarding.mark_tutorial_skipped()
	var menu := get_parent()
	queue_free()
	var marks := menu.get_node_or_null("CoachMarks") as CoachMarks
	if marks:
		marks.recheck()
