class_name MasteryTier
extends Resource
## One band of weapon mastery ranks (Bronze, Silver, Gold, Diamond, Prismatic).
## Listed in MasteryCurve.tiers; a tier covers ranks from `first_rank` up to
## the next tier's first rank.

@export var id: StringName
@export var display_name := ""
@export var first_rank := 1
## Badge colour and its lighter highlight (UI, toasts, results).
@export var color := Color.WHITE
@export var highlight := Color.WHITE
## Animated hue cycle in the UI (the top tier).
@export var animated := false
## Sound played on reaching a rank in this tier.
@export var sound: StringName


## The tier colour at `time` (seconds); animated tiers cycle through hues.
func color_at(time: float) -> Color:
	if not animated:
		return color
	return Color.from_hsv(fposmod(time * 0.12, 1.0), 0.55, 1.0)
