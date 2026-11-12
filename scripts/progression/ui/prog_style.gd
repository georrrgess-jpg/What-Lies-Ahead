class_name ProgStyle
extends RefCounted
## Shared look for the progression UI (Career page, HUD widget, results
## section): level colours, number formatting and small drawing helpers.
## Builds on UiKit's palette and fonts.

## Level brackets: every 10 levels the emblem changes colour.
const LEVEL_COLORS := [Color("35f0ff"), Color("52f060"), Color("ff7cc6"), Color("b46bff"), Color("ffc24a")]
const XP_COLOR := Color("7ff3e8")


static func level_color(lvl: int, time := 0.0) -> Color:
	if lvl >= Progression.MAX_LEVEL:
		return Color.from_hsv(fposmod(time * 0.1, 1.0), 0.5, 1.0)
	return LEVEL_COLORS[clampi((lvl - 1) / 10, 0, LEVEL_COLORS.size() - 1)]


## 12345 -> "12,345".
static func num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Tier colour for a mastery rank (grey when unranked).
static func rank_color(rank: int, time := 0.0) -> Color:
	var t := Mastery.tier(rank)
	return t.color_at(time) if t else Color(0.62, 0.6, 0.72)


## Regular polygon points (pointy-top when `rotation` is -PI/2).
static func polygon(center: Vector2, radius: float, sides: int, rotation := -PI / 2.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		var a := rotation + TAU * i / sides
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


## Fills `pts` with a vertical gradient (top colour -> bottom colour).
static func fill_gradient(ci: CanvasItem, pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	var lo := INF
	var hi := -INF
	for p in pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, (p.y - lo) / maxf(1.0, hi - lo)))
	ci.draw_polygon(pts, cols)


static func outline(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, color, width, true)


## A dark rounded card in the shared style.
static func card(border := Color.TRANSPARENT, fill_alpha := 0.72, padding := 14) -> StyleBoxFlat:
	return UiKit.box(Color(UiKit.INK, fill_alpha), border, 16, 3 if border.a > 0.0 else 0, padding)


## Thin XP bar in the shared style with a custom fill colour.
static func bar(height: float, fill: Color) -> ProgressBar:
	var b := UiKit.progress(0.0, height, fill)
	var bg := UiKit.box(Color(0.03, 0.02, 0.1, 0.85), Color(1, 1, 1, 0.08), int(height / 2), 1, 0)
	b.add_theme_stylebox_override("background", bg)
	return b
