class_name DamageStack
extends EnemyBehaviour
## The damage a zombie takes extra while weapons have marked it: the Dunk Tank's
## soak, the Markdown Marker's tags and Ground Control's radar mark. Their bonuses
## add up (they do not multiply) and the sum is capped, lower on heavies, so
## stacking all of them cannot melt a boss. Each status asks for the stack once
## (DamageStack.ensure); it is the last behaviour in line, so armour still sees
## the hit first, and it passes damage through untouched when nothing is on.
## tools/balance_report.py reads these constants.

## Most extra damage a normal zombie takes from every mark together (+60%).
const CAP := 0.6
## The same for heavies, alphas and bosses (+45%: the Marker's full stack plus
## Ground Control's mark fit exactly, a third mark adds nothing).
const HEAVY_CAP := 0.45


## Puts the stack on `z` unless it is already there.
static func ensure(z: Zombie) -> void:
	for b in z.behaviours:
		if b is DamageStack:
			return
	z.behaviours.append(DamageStack.new())


## The combined extra damage `z` takes right now (0.3 = +30%), cap applied.
static func bonus(z: Zombie) -> float:
	var sum := Soak.damage_scale(z) + PriceTags.damage_scale(z) + GroundControlMark.damage_scale(z) - 3.0
	return minf(sum, HEAVY_CAP if z.data.heavy else CAP)


func on_hit(z: Zombie, amount: float, _hit_position: Vector3, _headshot: bool) -> float:
	return amount * (1.0 + bonus(z))
