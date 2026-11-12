class_name MenuPage
extends Control
## Base for main-menu pages registered through UiExtension (data/ui/*.tres).
## Emit `back` to return to the title; `refresh()` is called every time the
## page is shown.

signal back
## Ask the menu to open another page by id (e.g. "play").
signal open_page(page_id: StringName)


func refresh() -> void:
	pass


## Optional: the control that should take keyboard/gamepad focus when shown.
func first_focus() -> Control:
	return find_child("FirstFocus", true, false) as Control
