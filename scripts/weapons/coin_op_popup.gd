class_name CoinOpPopup
extends Node3D
## The Coin-Op's "FREE PLAY" popup over a zombie that paid out a bonus token
## (CoinOpMode): arcade letters that pop in, rise a little and fade, with
## the rounds it gave back ("+4 TOKENS") under them, beside the zombie so
## the kill popup over its head stays readable; a headshot payout is pink.
## The same size on screen at any distance. Pooled, like StrikeZoneBanner.

const LIFE := 0.8
const FADE := 0.25
const RISE := 0.45
const TITLE := Color(1.0, 0.82, 0.24)
const SUB := Color(1.0, 0.42, 0.85)
const OUTLINE := Color(0.12, 0.05, 0.24)
## Pixels to the right of the zombie, so the kill popup over its head stays clear.
const SIDE := 230.0

static var _pool: Array = []

var _title: Label3D
var _sub: Label3D
var _tween: Tween
var _headshot := false


## Pops the popup at `at` under `parent` for `rounds` rounds given back.
static func spawn(parent: Node, at: Vector3, rounds: int, headshot: bool) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p: CoinOpPopup = null
	while not _pool.is_empty() and p == null:
		var candidate = _pool.pop_back()
		if is_instance_valid(candidate) and candidate.is_inside_tree():
			p = candidate
	if p == null:
		p = CoinOpPopup.new()
	if p.get_parent() != parent:
		if p.get_parent():
			p.get_parent().remove_child(p)
		parent.add_child(p)
	p._play(at, rounds, headshot)


func _init() -> void:
	_title = _label(56, Vector2(SIDE, 0.0))
	_sub = _label(40, Vector2(SIDE, -54.0))


## A label offset by `at` pixels from the popup's centre.
func _label(font_size: int, at: Vector2) -> Label3D:
	var l := Label3D.new()
	l.font = UiKit.display_font()
	l.font_size = font_size
	l.pixel_size = 0.0012
	l.outline_size = int(font_size * 0.24)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.render_priority = 10
	l.outline_render_priority = 9
	l.offset = at
	add_child(l)
	return l


func _play(at: Vector3, rounds: int, headshot: bool) -> void:
	visible = true
	global_position = at
	_title.text = "FREE PLAY!"
	_sub.text = "+%d TOKENS" % rounds
	_headshot = headshot
	_set_alpha(1.0)
	_title.scale = Vector3.ONE * 1.8
	_sub.scale = Vector3.ONE * 0.01
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_title, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sub, "scale", Vector3.ONE, 0.16).set_delay(0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", at + Vector3.UP * RISE, LIFE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_alpha, 1.0, 0.0, FADE).set_delay(LIFE - FADE)
	_tween.chain().tween_callback(_release)


func _set_alpha(alpha: float) -> void:
	_title.modulate = Color(SUB if _headshot else TITLE, alpha)
	_title.outline_modulate = Color(OUTLINE, alpha)
	_sub.modulate = Color(Color.WHITE, alpha)
	_sub.outline_modulate = Color(OUTLINE, alpha)


func _release() -> void:
	visible = false
	_pool.append(self)
