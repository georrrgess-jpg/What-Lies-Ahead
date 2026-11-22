class_name EndlessCard
extends WorldCard
## An endless level's card in the Play page's ENDLESS row: a WorldCard for
## an endless level (Ashfall City: its key art looks up the Broadcast Tower
## plaza at the broken skyscraper and the radio mast), captioned ENDLESS,
## with the best wave instead of stars and the Endless emblem in the corner.
## Without key art it paints its own: an ember sky over a broken skyline
## with a few windows still lit.

const EMBER := Color(1.0, 0.48, 0.18)
const SKY_TOP := Color(0.16, 0.05, 0.09)
const SKY_LOW := Color(0.86, 0.32, 0.12)
## Skyline blocks: [x, width, height] as shares of the card.
const SKYLINE := [[0.0, 0.1, 0.42], [0.09, 0.07, 0.58], [0.15, 0.12, 0.34], [0.26, 0.06, 0.7], [0.31, 0.1, 0.46],
	[0.4, 0.08, 0.3], [0.47, 0.05, 0.78], [0.51, 0.11, 0.5], [0.61, 0.07, 0.38], [0.67, 0.09, 0.62],
	[0.75, 0.06, 0.44], [0.8, 0.1, 0.55], [0.89, 0.11, 0.36]]

var level: LevelData
var _sky := Gradient.new()


## A card for endless `endless_level`, at slot `slot` of the ENDLESS row.
static func make(endless_level: LevelData, slot: int) -> EndlessCard:
	var card := EndlessCard.new()
	card.level = endless_level
	card.index = slot
	card.caption = "ENDLESS"
	var w := WorldData.new()
	w.id = endless_level.id
	w.display_name = endless_level.display_name
	w.tagline = "Waves without end. Buy your way through the gates."
	w.requirement = endless_level.requirement
	w.levels = [endless_level]
	w.accent_color = endless_level.accent_color
	w.secondary_color = UiKit.AMBER
	w.backdrop_color = Color(0.2, 0.07, 0.07)
	card.world = w
	return card


func _init() -> void:
	_sky.set_color(0, SKY_TOP)
	_sky.set_color(1, SKY_LOW)


## Best wave in place of the stars; a locked map shows how close it is.
func refresh() -> void:
	super()
	_stars.visible = false
	var best := EndlessRecords.best_wave()
	if not _unlocked:
		_status.text = lock_progress(level)
		return
	_status.text = "BEST WAVE %d" % best if best > 0 else "OPEN FROM LEVEL 1"
	_status.add_theme_color_override("font_color", UiKit.AMBER if best > 0 else Color.WHITE)


## What still locks endless `endless_level`, with the progress toward a wave
## goal ("BEST WAVE 22 / 30"); "" when it is open.
static func lock_progress(endless_level: LevelData) -> String:
	var req := endless_level.requirement
	if req == null or req.is_met():
		return ""
	if req.kind == Requirement.Kind.ENDLESS_WAVE:
		return "REACH WAVE %d  ·  BEST WAVE %d / %d" % [req.amount, mini(EndlessRecords.best_wave(), req.amount), req.amount]
	return req.describe().to_upper()


func _draw() -> void:
	super()
	if _art:
		return
	# No key art yet: a painted ember dusk and skyline (under the frame).
	var r := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	var bands := 12
	for i in bands:
		var t := float(i) / bands
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y * t, r.size.x, r.size.y / bands + 1.0), _sky.sample(t))
	var ground := r.end.y
	for b in SKYLINE:
		var x: float = r.position.x + r.size.x * float(b[0])
		var w: float = r.size.x * float(b[1])
		var h: float = r.size.y * float(b[2]) * 0.8
		draw_rect(Rect2(x, ground - h, w, h), Color(0.09, 0.04, 0.07))
		# A few windows still lit, the same every time.
		for k in int(h / 26.0):
			if (k * 7 + int(x)) % 3 == 0:
				draw_rect(Rect2(x + w * 0.3, ground - h + 14.0 + k * 26.0, 5, 7), Color(1.0, 0.7, 0.3, 0.8))
	draw_rect(Rect2(r.position.x, ground - 8.0, r.size.x, 8.0), Color(EMBER, 0.6))


## The frame, then the Endless emblem in the corner (a locked map's
## padlock sits there instead).
func _draw_frame() -> void:
	super()
	if _unlocked:
		EndlessEmblem.paint(_frame, Vector2(size.x - 58, 58), 42.0)
