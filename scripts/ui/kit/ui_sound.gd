class_name UiSound
extends RefCounted
## The kit's UI sounds in one place, so every screen uses the same cue for
## the same thing. The sounds come from tools/audio_packs/ui.py (and the three
## older ones in gen_audio.py); a missing file is skipped quietly by Sfx.
## Kit components call these themselves: a page only needs them for its own
## custom interactions.


## Pointer or focus moved onto something interactive.
static func hover() -> void:
	Sfx.play(&"ui_hover", -14.0)


## A button was pressed.
static func click() -> void:
	Sfx.play(&"ui_click", -6.0)


## Back / cancel / close.
static func back() -> void:
	Sfx.play(&"ui_back", -7.0)


## A tab or a segment of an option row changed.
static func tab() -> void:
	Sfx.play(&"ui_tab", -8.0)


## An item card was selected.
static func select() -> void:
	Sfx.play(&"ui_select", -8.0)


## Something was equipped or applied.
static func equip() -> void:
	Sfx.play(&"ui_equip", -5.0)


## The action is not possible (locked, cannot afford).
static func deny() -> void:
	Sfx.play(&"ui_deny", -6.0)


## A confirming answer in a dialog; a claim.
static func confirm() -> void:
	Sfx.play(&"ui_confirm", -5.0)


## A dialog or overlay opened.
static func open() -> void:
	Sfx.play(&"ui_open", -8.0)


## A toast appeared.
static func toast() -> void:
	Sfx.play(&"ui_toast", -8.0)


## One tick of a number counting up.
static func tick() -> void:
	Sfx.play(&"ui_tick", -14.0)


## Sparks were spent.
static func purchase() -> void:
	Sfx.play(&"ui_purchase", -4.0)


## Sparks landed in the wallet.
static func sparks() -> void:
	Sfx.play(&"ui_sparks", -7.0)


## A page changed.
static func page() -> void:
	Sfx.play(&"ui_whoosh", -14.0, 1.3)
