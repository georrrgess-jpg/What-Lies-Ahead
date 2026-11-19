class_name PrizesOddsView
extends ScrollContainer
## The ODDS & INFO tab: three columns of panels. The published odds per
## capsule (with bars) and the luck meter; what a print rolls (rare prints,
## shine grades, serials); how capsules are earned, repeats and Capsule Credits, and
## every finish of the series with how many of its prints are held.

const COLUMN := 520.0

var _page: PrizesPage
var _series: GridContainer


func _init(page: PrizesPage) -> void:
	_page = page
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(center)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", UiKit.GAP_L)
	center.add_child(cols)
	var s := PrizePrints.series()
	var a := _column(cols)
	a.add_child(_panel("ODDS PER CAPSULE", "always shown", _odds_rows(s)))
	a.add_child(_panel("LUCK METER", "", [UiKit.body("An Epic or better is guaranteed within %d capsules, a Legendary within %d. A forced Epic keeps Legendary's share of the top two. With the meter the real rates come to about 58 / 26 / 12.5 / 4%%." % [s.epic_pity, s.legendary_pity], COLUMN - 40.0, UiKit.SIZE_SMALL, UiKit.CREAM)]))
	var b := _column(cols)
	var rare: Array = []
	for v in ["glitter", "holo", "misprint"]:
		rare.append(_row(String(PrintLook.VARIANTS[v]["name"]).to_upper(), PrintLook.variant_odds(v), PrintLook.VARIANTS[v]["color"]))
	b.add_child(_panel("RARE PRINTS", "one roll per print", rare))
	b.add_child(_panel("SHINE GRADES", "from a 0-1 shine roll", [
		_row("FACTORY", "%d%%  (below %.2f)" % [roundi(s.polished_at * 100.0), s.polished_at], PrintLook.GRADE_COLORS[0]),
		_row("POLISHED", "%d%%" % roundi((s.mint_at - s.polished_at) * 100.0), PrintLook.GRADE_COLORS[1]),
		_row("MINT", "%d%%  (%.2f and up)" % [roundi((1.0 - s.mint_at) * 100.0), s.mint_at], PrintLook.GRADE_COLORS[2])]))
	b.add_child(_panel("SERIALS", "per finish, on your profile", [UiKit.body("#001 is a First Edition, #002-#%03d Low Serials, #007 / #077 / #777 Lucky 7s. A serial is never reused." % s.low_serial, COLUMN - 40.0, UiKit.SIZE_SMALL, UiKit.CREAM)]))
	var c := _column(cols)
	var earn: Array = []
	for line in ["%d per alpha defeated" % s.capsules_per_alpha, "%d per bounty claimed" % s.capsules_per_bounty,
			"%d for the day's first clear" % s.capsules_daily_clear, "1 for every %d contracts" % s.contracts_per_capsule,
			"%d per milestone" % s.capsules_per_milestone, "Buy with Arcade Tokens: %s each (no real money)" % Wallet.format(s.capsule_price)]:
		earn.append(UiKit.label("·  " + line, UiKit.SIZE_SMALL, UiKit.CREAM))
	c.add_child(_panel("EARN CAPSULES", "", earn))
	_series = GridContainer.new()
	_series.columns = 2
	_series.add_theme_constant_override("h_separation", UiKit.GAP_L)
	_series.add_theme_constant_override("v_separation", 0)
	c.add_child(_panel("SERIES %d  ·  %s" % [s.number, s.display_name.to_upper()], "%d finishes" % s.finishes.size(), [_series]))


func _column(parent: Control) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = COLUMN
	col.add_theme_constant_override("separation", UiKit.GAP_M)
	parent.add_child(col)
	return col


func _panel(title: String, note: String, rows: Array) -> Control:
	var board := UiKit.signboard(20)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UiKit.GAP_S)
	board.add_child(col)
	col.add_child(UiKit.section(title, note))
	for r in rows:
		col.add_child(r)
	return board


func _odds_rows(s: PrintSeries) -> Array:
	var rows: Array = []
	for r in 4:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UiKit.GAP_M)
		var chip := UiKit.chip(PrizesPage.rarity_name(r).to_upper(), PrizesPage.rarity_color(r), 18)
		chip.custom_minimum_size.x = 170
		row.add_child(chip)
		var bar := UiKit.progress(s.odds[r] / s.odds[0], 14.0, PrizesPage.rarity_color(r))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var value := UiKit.label("%d%%" % roundi(s.odds[r] * 100.0), UiKit.SIZE_LABEL, UiKit.CREAM, true)
		value.custom_minimum_size.x = 64
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		rows.append(row)
	return rows


func _row(caption: String, value: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	var chip := UiKit.chip(caption, color, 18)
	chip.custom_minimum_size.x = 210
	row.add_child(chip)
	row.add_child(UiKit.filler())
	row.add_child(UiKit.label(value, UiKit.SIZE_BODY, UiKit.CREAM, true))
	return row


func refresh() -> void:
	for c in _series.get_children():
		c.queue_free()
	var by := PrizePrints.by_rarity()
	for r in range(3, -1, -1):
		for fid in by.get(r, []):
			var fin := Cosmetics.item(fid)
			var held := PrizePrints.prints_of(fid).size()
			var text := "%s  %s" % [fin.display_name, ("×%d" % held) if held > 0 else "-"]
			_series.add_child(UiKit.label(text, UiKit.SIZE_SMALL, PrizesPage.rarity_color(r) if held > 0 else Color(PrizesPage.rarity_color(r), 0.5), held > 0))
