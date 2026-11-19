class_name ArsenalLayout
extends RefCounted
## The Arsenal's responsive rules: from the page's rectangle (canvas pixels)
## and how many screen pixels one canvas pixel takes, how many cards the dock
## shows, how wide the side panels are, how much room goes between regions
## and how the details panel flows.
##
## The canvas is always 1920 wide (canvas_items / expand), so a 1280x720
## window has the same canvas as a 1920x1080 one but every letter is a third
## smaller on screen. The card count therefore follows the dock's width in
## screen pixels: six at 1920x1080 and 1600x900, five at 1366x768 and
## 1280x720, four at 1024x768, never fewer than three.

enum Mode {
	## Wide windows: roomy gaps and paddings.
	WIDE,
	## Smaller windows: tighter gaps and paddings, fewer dock cards.
	COMPACT,
	## Narrow windows (1024 wide): the tightest gaps; the side panels take a
	## larger share of the width so their text stays as large as it can.
	NARROW,
}

## A dock card is never narrower than this on screen (screen pixels), so its
## picture and name stay readable.
const CARD_MIN_SCREEN := 210.0
const CARDS_MAX := 6
const CARDS_MIN := 3
## Width the dock's paging buttons and gaps take out of the row (canvas px).
const DOCK_CHROME := 2 * 64.0 + 4 * UiKit.GAP_S + 2 * 22.0
## Screen widths (pixels) under which the layout tightens and reflows.
const COMPACT_BELOW := 1500.0
const NARROW_BELOW := 1100.0

var mode := Mode.WIDE
var cards := CARDS_MAX
## Space between the regions and inside the panels.
var gap := UiKit.GAP_M
var padding := 22.0
var sidebar_width := 300.0
var details_width := 540.0
var dock_height := 236.0
## The stats in two columns (saves height).
var stat_columns := 1
## Font size of the description: larger on narrow windows, so it reads on
## screen at least as large as at 1366x768 (it scrolls instead of shrinking).
var about_size := 22


## The rules for a page of `page_size` canvas pixels where one canvas pixel is
## `screen_scale` screen pixels.
static func compute(page_size: Vector2, screen_scale: float) -> ArsenalLayout:
	var l := ArsenalLayout.new()
	var screen_width := page_size.x * screen_scale
	if screen_width < NARROW_BELOW:
		l.mode = Mode.NARROW
	elif screen_width < COMPACT_BELOW:
		l.mode = Mode.COMPACT
	var tight := l.mode != Mode.WIDE
	l.gap = UiKit.GAP_S if tight else UiKit.GAP_M
	l.padding = 16.0 if tight else 22.0
	var share := 1.12 if l.mode == Mode.NARROW else 1.0
	l.about_size = 28 if l.mode == Mode.NARROW else 22
	l.sidebar_width = clampf(page_size.x * 0.16 * share, 270.0, 340.0)
	l.details_width = clampf(page_size.x * 0.29 * share, 500.0, 640.0)
	var dock_screen := (page_size.x - DOCK_CHROME) * screen_scale
	l.cards = clampi(int(dock_screen / CARD_MIN_SCREEN), CARDS_MIN, CARDS_MAX)
	# Fewer, wider cards are also taller, so their names stay one size.
	l.dock_height = 236.0 if l.cards >= 6 else 256.0
	# One stat per row needs the height of a tall panel.
	var upper := page_size.y - l.dock_height - l.gap
	l.stat_columns = 1 if upper >= 860.0 else 2
	return l


func _to_string() -> String:
	return "%s cards=%d gap=%d stats=%d" % [Mode.keys()[mode], cards, gap, stat_columns]
