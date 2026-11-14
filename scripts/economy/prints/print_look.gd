class_name PrintLook
extends RefCounted
## How a print reads: names and colours of grades and rare prints, the serial
## stamp, the mint date, a ranking score, and the uniforms the finish shaders'
## print layer takes (art/shaders/finish_common.gdshaderinc).

const GRADES := ["Factory", "Polished", "Mint"]
const GRADE_COLORS := [Color("b9add9"), Color("7fe3ff"), Color("8dffc4")]
const VARIANTS := {
	"glitter": {"name": "Glitter", "color": Color("ff6fd0"), "short": "GLITTER"},
	"holo": {"name": "Holo", "color": Color("9f8bff"), "short": "HOLO"},
	"misprint": {"name": "Gold-ink Misprint", "color": Color("ffc24a"), "short": "MISPRINT"},
}
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## How far the pattern seed moves a pattern (model units; weapons are 0.4-1.0 long).
const SPREAD := Vector3(0.35, 0.2, 0.6)
const MAX_ANGLE := 0.12
## Pattern scale range (regular grids move visibly only when their pitch changes).
const SCALE_RANGE := Vector2(0.86, 1.16)
const SHADER_VARIANT := {"": 0, "glitter": 1, "holo": 2, "misprint": 3}


static func grade_name(p: Dictionary) -> String:
	return GRADES[PrizePrints.grade(p)]


static func grade_color(p: Dictionary) -> Color:
	return GRADE_COLORS[PrizePrints.grade(p)]


static func variant_name(p: Dictionary) -> String:
	return String(VARIANTS.get(String(p.get("var", "")), {}).get("name", ""))


static func variant_color(p: Dictionary) -> Color:
	return VARIANTS.get(String(p.get("var", "")), {}).get("color", Color.WHITE)


## "1 / 50": how rare a rare print is, from the series odds.
static func variant_odds(v: String) -> String:
	var s := PrizePrints.series()
	var chance: float = {"glitter": s.glitter_chance, "holo": s.holo_chance, "misprint": s.misprint_chance}.get(v, 0.0)
	return "1 / %d" % roundi(1.0 / chance) if chance > 0.0 else ""


## "#007", "#1,204".
static func serial_text(serial: int) -> String:
	return "#" + ("%03d" % serial if serial < 1000 else Wallet.format(serial))


## What makes a serial special: "FIRST EDITION", "LOW SERIAL", "LUCKY 7s" or "".
static func serial_tag(serial: int) -> String:
	if serial == 1:
		return "FIRST EDITION"
	if serial in [7, 77, 777, 7777]:
		return "LUCKY 7s"
	if serial <= PrizePrints.series().low_serial:
		return "LOW SERIAL"
	return ""


## "14 Nov 2026".
static func minted_text(p: Dictionary) -> String:
	var d := Time.get_date_dict_from_unix_time(int(p.get("minted", 0)))
	return "%d %s %d" % [d["day"], MONTHS[int(d["month"]) - 1], d["year"]]


## "Seafoam Dots · Holo".
static func title(p: Dictionary) -> String:
	var fin := PrizePrints.finish_of(p)
	var text := fin.display_name if fin else String(p.get("f", ""))
	var v := variant_name(p)
	return text + ("  ·  " + v if v != "" else "")


static func rarity_color(p: Dictionary) -> Color:
	return CosmeticItem.rarity_color(PrizePrints.rarity(p) as CosmeticItem.Rarity)


static func rarity_name(p: Dictionary) -> String:
	return CosmeticItem.rarity_name(PrizePrints.rarity(p) as CosmeticItem.Rarity)


## A ranking of how special a print is (higher is better): rarity first, then
## the rare print, the grade, and a low serial.
static func score(p: Dictionary) -> float:
	var v := {"": 0.0, "glitter": 1.0, "holo": 2.0, "misprint": 3.0}.get(String(p.get("var", "")), 0.0) as float
	var serial := int(p.get("serial", 9999))
	var low := 1.0 if serial <= PrizePrints.series().low_serial else 0.0
	return PrizePrints.rarity(p) * 1000.0 + v * 200.0 + float(p.get("shine", 0.0)) * 100.0 + low * 50.0 + 10.0 / maxf(1.0, serial)


## The print layer's uniforms for `p` (see finish_common.gdshaderinc). The
## pattern seed drives a fixed placement: the same seed always lands the same.
static func uniforms(p: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p.get("seed", 0)) * 7919 + 104729
	var offset := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * SPREAD
	return {
		"print_on": true,
		"print_offset": offset,
		"print_angle": rng.randf_range(-MAX_ANGLE, MAX_ANGLE),
		"print_scale": rng.randf_range(SCALE_RANGE.x, SCALE_RANGE.y),
		"print_seed": rng.randf(),
		"print_shine": float(p.get("shine", 0.5)),
		"print_variant": int(SHADER_VARIANT.get(String(p.get("var", "")), 0)),
	}
