extends RefCounted
## The Arsenal stand with every weapon: one still per weapon (saved next to the
## --shot path as <shot>_<weapon>.png) and one line per weapon with how far the
## model's underside is from each cradle pad ("gap" > 0 floats, < 0 cuts in)
## and how far its lowest point is above the turntable ("rest", ~0: it sits).
##
##   godot --path . --resolution 960x540 -- --profile=<copy> --shot=/tmp/stand.png \
##       --shot-scene=arsenal --shot-run=res://scripts/dev/arsenal_stand_probe.gd

## A pad this far (metres, turntable space) from the model counts as floating.
const TOUCH := 0.004


func run(shot: Node, menu: Node) -> void:
	var page = menu.page("arsenal")
	var bad := 0
	for w in GameData.weapons():
		page._select(w)
		await shot._wait(4)
		var seat: Dictionary = page._seats.get(w.id, {})
		var line := "[stand] %-18s" % w.id
		var pads := 0
		for i in 2:
			var pad: float = seat["pads"][i] if seat else -INF
			if pad == -INF:
				line += "  pad%d: none" % i
				continue
			pads += 1
			var under: float = page._underside(page._corners(seat["along"]), seat["stations"][i])
			var gap := under - pad
			line += "  pad%d gap %+.4f" % [i, gap]
			if absf(gap) > TOUCH:
				bad += 1
		# The lowest point of the model rests on the turntable.
		var low := INF
		for c in page._corners(seat["along"]):
			low = minf(low, c.z)
		var rest: float = low - page.TURNTABLE_TOP
		line += "  rest %+.4f" % rest
		if rest > TOUCH or rest < -TOUCH:
			bad += 1
		print(line)
		if shot.path != "":
			await shot._snap(String(w.id), 20)
	print("[stand] DONE %d weapons, %d problems" % [GameData.weapons().size(), bad])
