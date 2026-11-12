class_name KillPopup
extends Node3D
## Floating reward above a defeated zombie: the score the kill was worth in
## big arcade digits, a flavour line above it (HEADSHOT, COMBO x1.4) and the
## tickets it paid as a small line below. Popups are pooled, so kills don't
## allocate (and re-rasterise) fresh text objects.

const RISE := 0.9
const LIFE := 0.95
const SCORE_COLOR := Color(1.0, 0.8, 0.25)
const TICKET_COLOR := Color(1.0, 0.95, 0.85)
const OUTLINE := Color(0.12, 0.05, 0.2)

static var _pool: Array = []

var _flavour: Label3D
var _points: Label3D
var _tickets: Label3D
var _tween: Tween


## Shows a popup at `at` (world space) under `parent`.
static func spawn(parent: Node, at: Vector3, points: int, tickets: int, flavour := "", flavour_color := Color.WHITE) -> KillPopup:
	if parent == null or not parent.is_inside_tree():
		return null
	var popup: KillPopup = null
	while not _pool.is_empty() and popup == null:
		# The pool outlives the level (Retry frees the old popups), so check first.
		var candidate = _pool.pop_back()
		if is_instance_valid(candidate) and candidate.is_inside_tree():
			popup = candidate
	if popup == null:
		popup = KillPopup.new()
	if popup.get_parent() != parent:
		if popup.get_parent():
			popup.get_parent().remove_child(popup)
		parent.add_child(popup)
	popup._play(at, points, tickets, flavour, flavour_color)
	return popup


## Rasterises every glyph the popups use, at their sizes, while the level is
## still black behind its fade-in (the first kill would hitch otherwise).
static func warm_up(parent: Node, at: Vector3) -> void:
	var popup := spawn(parent, at, 1234567890, 1234567890, "HEADSHOT COMBO x.", Color.WHITE)
	if popup:
		popup._tween.kill()
		popup._tween = popup.create_tween()
		popup._tween.tween_interval(0.1)
		popup._tween.tween_callback(popup._release)


func _init() -> void:
	_flavour = _label(64, 0.0036, 0.44)
	_points = _label(104, 0.0046, 0.0)
	_tickets = _label(56, 0.0032, -0.36)


func _label(font_size: int, pixel: float, height: float) -> Label3D:
	var l := Label3D.new()
	l.font = UiKit.display_font()
	l.font_size = font_size
	l.pixel_size = pixel
	l.outline_size = int(font_size * 0.24)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.render_priority = 10
	l.outline_render_priority = 9
	l.position.y = height
	add_child(l)
	return l


func _play(at: Vector3, points: int, tickets: int, flavour: String, flavour_color: Color) -> void:
	visible = true
	_points.text = "+%d" % points
	_flavour.text = flavour
	_flavour.visible = flavour != ""
	_tickets.text = "+%d TICKETS" % tickets
	_tickets.visible = tickets > 0
	_set_colors(SCORE_COLOR, flavour_color, 1.0)
	global_position = at
	# Bigger rewards pop bigger (a 600-point headshot reads from across the pier).
	var size := clampf(0.9 + points / 1200.0, 0.9, 1.45)
	scale = Vector3.ONE * size * 0.45
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector3.ONE * size, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", at + Vector3.UP * RISE, LIFE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(a: float): _set_colors(SCORE_COLOR, flavour_color, a), 1.0, 0.0, 0.35).set_delay(LIFE - 0.35)
	_tween.chain().tween_callback(_release)


func _set_colors(score_color: Color, flavour_color: Color, alpha: float) -> void:
	_points.modulate = Color(score_color, alpha)
	_flavour.modulate = Color(flavour_color, alpha)
	_tickets.modulate = Color(TICKET_COLOR, alpha * 0.85)
	_points.outline_modulate = Color(OUTLINE, alpha)
	_flavour.outline_modulate = Color(OUTLINE, alpha)
	_tickets.outline_modulate = Color(OUTLINE, alpha)


func _release() -> void:
	visible = false
	_pool.append(self)
