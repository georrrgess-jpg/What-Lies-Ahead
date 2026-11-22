extends RefCounted
## Stills of a Prize Prints series in the Locker, to judge every finish where
## players see it: one print of each finish is minted into the (scratch)
## profile, then for each weapon every finish is selected on the case and
## saved as <shot>_<weapon>_<finish>.png, and the finishes' Locker thumbnails
## are laid out on one sheet per weapon (<shot>_thumbs_<weapon>.png).
##
##   godot --path . --resolution 1600x900 -- --profile=<scratch copy> --shot=/tmp/x.png \
##       --shot-scene=locker --shot-run=res://scripts/dev/prints_locker_tour.gd \
##       [--shot-series=series_2] [--shot-weapons=ion_carbine,glow_blade] [--shot-only=fin_a,fin_b]
##       [--shot-frames=40] [--shot-skip=cases|thumbs]

const THUMB_COLUMNS := 8


func run(shot: Node, menu: Node) -> void:
	var page: Node = menu.page("locker")
	var series_id: String = shot._arg("series", "series_2")
	var series := PrizePrints.series_by_id(StringName(series_id))
	if series == null:
		series = PrizePrints.series()
	var finishes: Array = Array(series.finishes)
	var only: String = shot._arg("only", "")
	if only != "":
		finishes = Array(only.split(",", false)).map(func(f): return StringName(f))
	for fid in finishes:
		if PrizePrints.prints_of(fid).is_empty():
			PrizePrints._mint(fid, "counter")
	var frames := int(shot._arg("frames", "40"))
	var skip: String = shot._arg("skip", "")
	var weapons: String = shot._arg("weapons", "ion_carbine,glow_blade")
	for wid in weapons.split(",", false):
		page.select_weapon(StringName(wid))
		if skip != "cases":
			for fid in finishes:
				page.select_item(fid)
				await shot._snap("%s_%s" % [wid, fid], frames)
		if skip != "thumbs":
			await _thumbs(shot, page, finishes, GameData.weapon(StringName(wid)), "thumbs_" + wid)


## Every finish's Locker thumbnail on `weapon`, in a grid over the page.
func _thumbs(shot: Node, page: Node, finishes: Array, weapon: WeaponData, suffix: String) -> void:
	var sheet := ColorRect.new()
	sheet.color = UiKit.INK
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grid := GridContainer.new()
	grid.columns = THUMB_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	sheet.add_child(grid)
	shot.get_tree().root.add_child(sheet)
	var thumbs: CosmeticThumbs = page.get("_thumbs")
	for fid in finishes:
		var cell := VBoxContainer.new()
		var rect := TextureRect.new()
		rect.custom_minimum_size = Vector2(190, 112)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.add_child(rect)
		var item := Cosmetics.item(fid)
		cell.add_child(UiKit.label(item.display_name, 14, CosmeticItem.rarity_color(item.rarity)))
		grid.add_child(cell)
		thumbs.request(item, func(tex: Texture2D): rect.texture = tex, weapon)
	await shot._snap(suffix, 150)
	sheet.queue_free()
