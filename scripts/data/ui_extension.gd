class_name UiExtension
extends Resource
## Registers a piece of UI without editing the shared menu, HUD or results
## scripts. Drop a .tres of this type in data/ui/ and it is picked up:
##
##   MENU_PAGE        a MenuPage script; gets a button on the title screen
##                    (if show_on_title) and can be opened by id.
##   HUD_WIDGET       a Control script with bind(director: RunDirector, player: Player);
##                    added on top of the in-game HUD.
##   RESULTS_SECTION  a script with static func build(result: Dictionary) -> Control;
##                    its Control is added to the end-of-run screen.

enum Kind { MENU_PAGE, HUD_WIDGET, RESULTS_SECTION }

@export var kind: Kind = Kind.MENU_PAGE
@export var id: StringName
@export var title := ""
@export var script_ref: Script
@export var order := 0
@export var show_on_title := true
@export var accent := Color("ff3fa4")
