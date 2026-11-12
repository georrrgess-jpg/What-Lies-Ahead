class_name Onboarding
extends RefCounted
## The first-time experience: the welcome flow after the intro, the skippable
## tutorial and first-run guidance.
##
## The main menu calls wants_first_run() / begin_first_run() once the intro has
## finished, and offers start_tutorial() from the title screen when
## has_tutorial() is true. State lives in Profile.section("onboarding").


## True when the player has never been through (or skipped) the first-run flow.
static func wants_first_run() -> bool:
	return false


## Starts the first-run flow on top of the main menu (`menu` is the MainMenu).
static func begin_first_run(_menu: Node) -> void:
	pass


## True when a tutorial exists that start_tutorial() can launch.
static func has_tutorial() -> bool:
	return false


## Starts the tutorial (replayable any time from the menu).
static func start_tutorial() -> void:
	pass
