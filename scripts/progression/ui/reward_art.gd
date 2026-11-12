class_name RewardArt
extends Control
## Preview art for one reward, drawn to fit its rect:
##   weapon_finish  animated swatch (art/shaders/mastery_swatch.gdshader)
##   banner         animated banner (art/shaders/mastery_banner.gdshader)
##   weapon_cell    glowing energy orb      title   name plate
##   other slots    rarity gem               stamp   Pier Pass stamp (no item)
## Locked rewards are shown greyed out with a padlock.

const SWATCH_SHADER := "res://art/shaders/mastery_swatch.gdshader"
const BANNER_SHADER := "res://art/shaders/mastery_banner.gdshader"
const PATTERNS := ["stripes", "swirl", "bulbs", "waves", "checker", "sunburst", "stars", "chevrons"]

var item: CosmeticItem
var stamp_name := ""
var locked := false
var _rect: ColorRect
var _time := 0.0


func _init(reward: CosmeticItem = null, is_locked := false, min_size := Vector2(96, 96)) -> void:
	item = reward
	locked = is_locked
	custom_minimum_size = min_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A Pier Pass stamp instead of an item.
static func stamp(text: String, is_locked := false, min_size := Vector2(96, 96)) -> RewardArt:
	var art := RewardArt.new(null, is_locked, min_size)
	art.stamp_name = text
	return art


func _ready() -> void:
	if item and (item.slot == &"weapon_finish" or item.slot == &"banner"):
		_rect = ColorRect.new()
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rect.material = _material()
		add_child(_rect)
		resized.connect(_fit)
		_fit.call_deferred()


func _process(delta: float) -> void:
	_time += delta
	if item and item.slot == &"weapon_cell" and not locked:
		queue_redraw()


## Finish swatch style for the shader: 0 paint, 1 metal, 2 gold, 3 diamond, 4 prismatic.
static func finish_style(finish: CosmeticItem) -> int:
	var shader := String(finish.params.get("shader", ""))
	if shader.contains("prismatic") or shader.contains("holo"):
		return 4
	if shader.contains("diamond"):
		return 3
	if shader.contains("gold"):
		return 2
	return 1 if float(finish.params.get("metallic", 0.0)) >= 0.5 else 0


## One material per preview: the shaders need this preview's size.
func _material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if item.slot == &"banner":
		m.shader = load(BANNER_SHADER)
		m.set_shader_parameter("base_color", item.color(0, UiKit.PURPLE))
		m.set_shader_parameter("pattern_color", item.color(1, UiKit.PINK))
		m.set_shader_parameter("accent_color", item.color(2, UiKit.CREAM))
		m.set_shader_parameter("pattern", maxi(0, PATTERNS.find(String(item.params.get("pattern", "stripes")))))
	else:
		m.shader = load(SWATCH_SHADER)
		m.set_shader_parameter("shell_color", item.color(0))
		m.set_shader_parameter("trim_color", item.color(1, item.color(0).darkened(0.4)))
		m.set_shader_parameter("style", finish_style(item))
		var extra: Dictionary = item.params.get("shader_params", {})
		m.set_shader_parameter("hue_offset", float(extra.get("hue_offset", 0.0)))
		m.set_shader_parameter("hue_range", float(extra.get("hue_range", 1.0)))
	m.set_shader_parameter("locked", locked)
	return m


func _fit() -> void:
	if _rect == null:
		return
	var s := size
	if item.slot == &"weapon_finish":
		var side := minf(s.x, s.y)
		s = Vector2(side, side)
	_rect.position = (size - s) * 0.5
	_rect.size = s
	var m := _rect.material as ShaderMaterial
	m.set_shader_parameter("rect_size", s)
	m.set_shader_parameter("corner", minf(s.x, s.y) * 0.2)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	if item == null:
		if stamp_name != "":
			_draw_stamp(c, r * 0.92)
	else:
		match String(item.slot):
			"weapon_cell": _draw_cell(c, r * 0.62)
			"title": _draw_title()
			"weapon_finish", "banner": pass
			_: _draw_gem(c, r * 0.6)
	if locked:
		_draw_lock(c + Vector2(r * 0.55, r * 0.55) if item and item.slot != &"title" else Vector2(size.x - 18, size.y - 18), 11.0)


func _draw_cell(c: Vector2, r: float) -> void:
	var col := item.color(0) if not locked else Color(0.45, 0.42, 0.55)
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	for i in 6:
		var k := 1.0 - i / 6.0
		draw_circle(c, r * (1.0 + 0.55 * k), Color(col, 0.07 * (1.0 - k) * (0.7 + 0.3 * pulse)))
	draw_circle(c + Vector2(0, r * 0.12), r, Color(UiKit.INK, 0.5))
	draw_circle(c, r, col.darkened(0.35))
	draw_circle(c, r * 0.78, col)
	draw_circle(c - Vector2(r * 0.28, r * 0.3), r * 0.26, Color(1, 1, 1, 0.75))
	draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.35), maxf(1.0, r * 0.08), true)


func _draw_title() -> void:
	var col := item.color(0, UiKit.CREAM) if not locked else Color(0.6, 0.58, 0.7)
	var plate := Rect2(Vector2(4, size.y * 0.5 - 22), Vector2(size.x - 8, 44))
	draw_style_box(UiKit.box(Color(UiKit.INK, 0.9), Color(col, 0.7), 10, 2, 0), plate)
	var font := UiKit.display_font()
	var text := item.display_name.to_upper()
	var fs := 22
	while fs > 12 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > plate.size.x - 16:
		fs -= 1
	var y := plate.get_center().y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(plate.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, fs, col)


func _draw_gem(c: Vector2, r: float) -> void:
	var col := CosmeticItem.rarity_color(item.rarity) if not locked else Color(0.45, 0.42, 0.55)
	ProgStyle.fill_gradient(self, ProgStyle.polygon(c, r, 4), col.lightened(0.4), col.darkened(0.4))
	ProgStyle.outline(self, ProgStyle.polygon(c, r * 0.6, 4), Color(1, 1, 1, 0.5), 2.0)


func _draw_stamp(c: Vector2, r: float) -> void:
	var col := UiKit.AMBER if not locked else Color(0.55, 0.52, 0.66)
	draw_circle(c, r, Color(UiKit.INK, 0.85))
	draw_arc(c, r * 0.94, 0, TAU, 48, col, maxf(2.0, r * 0.07), true)
	var dashes := 18
	for i in dashes:
		var a := TAU * i / dashes
		draw_arc(c, r * 0.76, a, a + TAU / dashes * 0.55, 6, Color(col, 0.7), maxf(1.0, r * 0.04), true)
	ProgStyle.fill_gradient(self, _star(c, r * 0.46), col.lightened(0.3), col.darkened(0.2))


func _star(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + TAU * i / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	return pts


func _draw_lock(at: Vector2, s: float) -> void:
	draw_circle(at, s * 1.35, Color(UiKit.INK, 0.92))
	draw_arc(at + Vector2(0, -s * 0.25), s * 0.42, PI, TAU, 12, Color.WHITE, maxf(1.5, s * 0.18), true)
	draw_rect(Rect2(at + Vector2(-s * 0.6, -s * 0.2), Vector2(s * 1.2, s * 0.85)), Color.WHITE)
