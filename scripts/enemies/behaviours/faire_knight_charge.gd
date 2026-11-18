class_name FaireKnightChargeBehaviour
extends CityRiotShieldBehaviour
## Armored Knight (Royal Faire): a toy knight behind a big heater shield. Body
## shots from the front clang off the shield until it breaks; headshots over the
## rim and shots from the side or behind land. At mid range it plants the
## shield and raps its sword on the rim three times while the shield's boss
## glints gold and white (the telegraph: the threat ring warns), then charges
## shield-first in a straight line; a hit knocks the player back. After the
## charge its guard swings wide for a moment: sidestep, then shoot it.

## The glint's two colours (swapped through the rap and the charge).
@export var glint_a := Color(1.0, 0.82, 0.3)
@export var glint_b := Color(1.0, 0.98, 0.9)

var _glint := 0.0


## Swaps the shield glint between gold and white.
func _flash_lights(delta: float) -> void:
	_glint += delta * FLASH_RATE
	_light.light_color = glint_a if int(_glint) % 2 == 0 else glint_b
