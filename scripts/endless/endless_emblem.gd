class_name EndlessEmblem
extends Control
## The Endless mode's emblem: a round badge of the burning city at dusk (the
## broken skyscraper and the radio mast with its red beacon black against an
## ember sky, fires along the street) under a thick ember-to-gold infinity
## sign, in an ember ring. Under 18 px of radius it keeps only the disc, the
## infinity and the ring, so it still reads as a carousel pip. `paint()`
## draws it on any canvas item (the Play page's pips and card badge); as a
## Control it fills its own square.

const EMBER := Color(1.0, 0.48, 0.18)
const GOLD := Color(1.0, 0.84, 0.36)
const SILHOUETTE := Color(0.11, 0.04, 0.09)
const BEACON := Color(1.0, 0.16, 0.1)
## Below this radius (px) the skyline is left out.
const DETAIL_RADIUS := 18.0
## The sky from the top of the disc to its bottom: plum, hot orange, fire gold.
const SKY := [Color(0.22, 0.06, 0.2), Color(0.5, 0.12, 0.2), Color(0.95, 0.36, 0.14), Color(1.0, 0.66, 0.26)]
## Sky bands painted inside the disc.
const BANDS := 10
## Skyline blocks, [x0, x1, top] in shares of the radius from the centre (y down).
const SKYLINE := [[-0.95, -0.66, 0.36], [-0.68, -0.5, 0.22], [-0.2, 0.0, 0.3], [-0.02, 0.22, 0.14],
	[0.2, 0.34, 0.38], [0.56, 0.95, 0.26]]
## The broken skyscraper (shares of the radius): a slab with its top sheared
## off at a slant and a notch knocked out of it.
const TOWER := [[-0.5, 1.0], [-0.5, -0.04], [-0.42, -0.1], [-0.37, -0.02], [-0.3, -0.2], [-0.2, -0.12], [-0.2, 1.0]]
## Fires along the street: [x, height] in shares of the radius.
const FIRES := [[-0.62, 0.2], [-0.08, 0.16], [0.46, 0.22]]
## Where the infinity sign sits (y, share of the radius) and its half width.
const SIGN_Y := -0.4
const SIGN_HALF := 0.62
## Points of the infinity sign's curve.
const CURVE := 56

static var _curve_unit := PackedVector2Array()


static func make(px: float) -> EndlessEmblem:
	var e := EndlessEmblem.new()
	e.custom_minimum_size = Vector2(px, px)
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return e


func _draw() -> void:
	paint(self, size * 0.5, minf(size.x, size.y) * 0.5 / 1.12)


## Draws the emblem on `ci`, centred at `at`, `r` px to the outside of its
## ring (its glow reaches a little further), at `alpha`.
static func paint(ci: CanvasItem, at: Vector2, r: float, alpha := 1.0) -> void:
	ci.draw_circle(at, r * 1.12, Color(EMBER, 0.22 * alpha), true, -1.0, true)
	var inner := r * 0.88
	if r >= DETAIL_RADIUS:
		_paint_sky(ci, at, inner, alpha)
		_paint_city(ci, at, inner, alpha)
		_paint_infinity(ci, at + Vector2(0, inner * SIGN_Y), inner * SIGN_HALF, r, alpha)
	else:
		ci.draw_circle(at, inner, Color(SKY[0], alpha), true, -1.0, true)
		_paint_infinity(ci, at, inner * 0.84, r, alpha)
	ci.draw_arc(at, r * 0.94, 0.0, TAU, 48, Color(EMBER, alpha), maxf(2.0, r * 0.12), true)
	if r >= DETAIL_RADIUS:
		ci.draw_arc(at, r * 0.86, 0.0, TAU, 48, Color(GOLD, 0.7 * alpha), maxf(1.0, r * 0.035), true)


## The dusk inside the disc, in horizontal bands.
static func _paint_sky(ci: CanvasItem, at: Vector2, r: float, alpha: float) -> void:
	for i in BANDS:
		var y0 := -r + 2.0 * r * i / BANDS
		var y1 := -r + 2.0 * r * (i + 1) / BANDS
		var t := float(i) / (BANDS - 1) * (SKY.size() - 1)
		var k := mini(int(t), SKY.size() - 2)
		var c := (SKY[k] as Color).lerp(SKY[k + 1], t - k)
		ci.draw_colored_polygon(_chord_band(at, r, y0, y1), Color(c, alpha))


## The piece of the disc between heights `y0` and `y1` (local, y down).
static func _chord_band(at: Vector2, r: float, y0: float, y1: float) -> PackedVector2Array:
	var w0 := sqrt(maxf(0.0, r * r - y0 * y0))
	var w1 := sqrt(maxf(0.0, r * r - y1 * y1))
	if y0 < 0.0 and y1 > 0.0:
		# The band across the middle is widest at y = 0.
		return PackedVector2Array([at + Vector2(-w0, y0), at + Vector2(w0, y0), at + Vector2(r, 0), at + Vector2(w1, y1),
			at + Vector2(-w1, y1), at + Vector2(-r, 0)])
	return PackedVector2Array([at + Vector2(-w0, y0), at + Vector2(w0, y0), at + Vector2(w1, y1), at + Vector2(-w1, y1)])


## The skyline standing on the rim: the radio mast, the broken skyscraper
## with a few windows still lit, the blocks, and fires at their feet.
static func _paint_city(ci: CanvasItem, at: Vector2, r: float, alpha: float) -> void:
	var dark := Color(SILHOUETTE, alpha)
	var mast := at + Vector2(r * 0.72, 0.0)
	var top := mast + Vector2(0, -r * 0.16)
	var foot := r * 0.12
	ci.draw_colored_polygon(PackedVector2Array([top, mast + Vector2(foot, r * 0.5), mast + Vector2(-foot, r * 0.5)]), dark)
	ci.draw_line(top, top + Vector2(0, -r * 0.14), dark, maxf(1.0, r * 0.04), true)
	ci.draw_circle(top + Vector2(0, -r * 0.15), maxf(1.5, r * 0.055), Color(BEACON, alpha), true, -1.0, true)
	ci.draw_circle(top + Vector2(0, -r * 0.15), maxf(3.0, r * 0.12), Color(BEACON, 0.3 * alpha), true, -1.0, true)
	var tower := PackedVector2Array()
	for p in TOWER:
		tower.append(at + Vector2(float(p[0]), float(p[1])) * r)
	ci.draw_colored_polygon(_clip_bottom(tower, at, r), dark)
	var win := Color(1.0, 0.8, 0.4, 0.95 * alpha)
	for k in 4:
		ci.draw_rect(Rect2(at + Vector2(-0.44 + 0.12 * (k % 2), 0.06 + 0.17 * k) * r, Vector2(0.07, 0.06) * r), win)
	for b in SKYLINE:
		var x0 := float(b[0]) * r
		var x1 := float(b[1]) * r
		var y := float(b[2]) * r
		var block := PackedVector2Array([at + Vector2(x0, r), at + Vector2(x0, y), at + Vector2(x1, y), at + Vector2(x1, r)])
		ci.draw_colored_polygon(_clip_bottom(block, at, r), dark)
	for f in FIRES:
		var base := at + Vector2(float(f[0]) * r, r * 0.7)
		var h := float(f[1]) * r
		ci.draw_circle(base, h * 0.9, Color(EMBER, 0.35 * alpha), true, -1.0, true)
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-h * 0.45, 0), base + Vector2(0, -h), base + Vector2(h * 0.45, 0)]), Color(EMBER, alpha))
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-h * 0.22, 0), base + Vector2(0, -h * 0.55), base + Vector2(h * 0.22, 0)]), Color(GOLD, alpha))


## `poly` with every point below the rim pulled up onto it (the shapes stand
## on the disc's lower edge).
static func _clip_bottom(poly: PackedVector2Array, at: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		var d := p - at
		out.append(at + Vector2(d.x, minf(d.y, sqrt(maxf(0.0, r * r - d.x * d.x)))))
	return out


## The infinity sign: a lemniscate `half` px to each side, outlined in ink,
## ember at its ends to gold where it crosses, a shine along its loops.
static func _paint_infinity(ci: CanvasItem, at: Vector2, half: float, r: float, alpha: float) -> void:
	if _curve_unit.is_empty():
		for i in CURVE + 1:
			var t := TAU * i / CURVE
			var s := sin(t)
			_curve_unit.append(Vector2(cos(t), s * cos(t)) / (1.0 + s * s))
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for p in _curve_unit:
		points.append(at + p * half)
		colors.append(Color(EMBER.lerp(GOLD, 1.0 - absf(p.x)), alpha))
	var width := maxf(3.0, r * 0.17)
	ci.draw_polyline(points, Color(UiKit.INK, 0.9 * alpha), width + maxf(2.0, r * 0.1), true)
	ci.draw_polyline_colors(points, colors, width, true)
	if r < DETAIL_RADIUS:
		return
	for from in [CURVE * 5 / 16, CURVE * 13 / 16]:
		var shine := PackedVector2Array()
		for i in range(from, from + CURVE / 8):
			shine.append(at + _curve_unit[i] * half + Vector2(0, -width * 0.12))
		ci.draw_polyline(shine, Color(1, 1, 1, 0.55 * alpha), maxf(1.0, width * 0.22), true)
