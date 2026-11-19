class_name RankPips
extends Control
## A row of rounded pips for ranks: the earned ones filled, the next one
## filled as far as its progress, the rest empty. Like the Arsenal's
## "MASTERY 2 / 10" track. Redraws only when set.
##
##   var pips := RankPips.make(UiKit.AMBER)
##   pips.set_ranks(2, 10, 0.4)       # two earned, 40% into the third

const HEIGHT := 18.0
const GAP := 6.0

var _empty := _box(Color(UiKit.INK, 0.95), Color("4a3b86"))
var _full: StyleBoxFlat
var _rank := 0
var _count := 10
var _progress := 0.0


static func make(fill_color := UiKit.AMBER) -> RankPips:
	var p := RankPips.new()
	p._full = _box(fill_color, fill_color.lightened(0.4))
	p.custom_minimum_size = Vector2(0, HEIGHT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.resized.connect(p.queue_redraw)
	return p


## `rank` of `count` earned, `progress` (0-1) into the next.
func set_ranks(rank: int, count: int, progress: float) -> void:
	_rank = clampi(rank, 0, maxi(1, count))
	_count = maxi(1, count)
	_progress = clampf(progress, 0.0, 1.0) if rank < count else 0.0
	queue_redraw()


func _draw() -> void:
	var w := (size.x - GAP * (_count - 1)) / _count
	if w <= 2.0:
		return
	var h := minf(size.y, HEIGHT)
	var y := (size.y - h) * 0.5
	for i in _count:
		var r := Rect2(i * (w + GAP), y, w, h)
		draw_style_box(_empty, r)
		var fill := 1.0 if i < _rank else (_progress if i == _rank else 0.0)
		if fill > 0.0:
			draw_style_box(_full, Rect2(r.position, Vector2(maxf(h, r.size.x * fill), h)))


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(HEIGHT * 0.5))
	return sb
