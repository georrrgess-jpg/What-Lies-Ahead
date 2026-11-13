class_name Onboarding
extends RefCounted
## The first-time experience: the welcome flow after the intro, the skippable
## Boot Camp tutorial, one-time hints during the first runs and coach marks on
## the menu pages.
##
## The main menu calls wants_first_run() / begin_first_run() once the intro has
## finished, and offers start_tutorial() from the title screen when
## has_tutorial() is true. Game calls install() once at startup, which adds the
## OnboardingHub (hints in runs, coach marks in the menu).
##
## State lives in Profile.section("onboarding"):
##   first_run   true once the welcome flow was shown (or the profile is a returning one)
##   tutorial    "" | "skipped" | "completed"
##   rewarded    true once the Boot Camp reward was paid (it pays once)
##   seen        hint and coach-mark ids already shown
##   guide       the guided first deployment step ("", "play", "deploy", "done")

const LEVEL_PATH := "res://data/tutorial/boot_camp.tres"
const SECTION := "onboarding"
## The one-time reward for finishing Boot Camp.
const REWARD_SPARKS := 200
const REWARD_ITEM := &"title_pier_patrol"


static func _sec() -> Dictionary:
	return Profile.section(SECTION)


## Adds the hub that shows hints and coach marks. Game calls this once.
static func install(game: Node) -> void:
	if game.has_node("OnboardingHub"):
		return
	var hub := OnboardingHub.new()
	hub.name = "OnboardingHub"
	game.add_child(hub)


## True when the player has never been through (or skipped) the first-run flow
## and the profile has no progress of its own.
static func wants_first_run() -> bool:
	if wants_welcome_back():
		return true
	if bool(_sec().get("first_run", false)):
		return false
	if is_returning_profile():
		_sec()["first_run"] = true
		return false
	return true


## A save carried over to the Sparks economy (LegacyGrant) that has not seen
## the one-time "Welcome back" card yet.
static func wants_welcome_back() -> bool:
	return Profile.section("economy").has("legacy") and not seen(&"welcome_back")


## Sparks the carried-over save was paid (0 if none).
static func legacy_sparks() -> int:
	var legacy = Profile.section("economy").get("legacy", {})
	return int(legacy.get("sparks", 0)) if legacy is Dictionary else 0


## A profile that has played: any XP, Sparks, runs or level progress.
static func is_returning_profile() -> bool:
	if Progression.xp() > 0 or Wallet.lifetime_earned() > 0:
		return true
	if int(Profile.section("progression").get("runs_played", 0)) > 0:
		return true
	return not (Profile.data.get("levels", {}) as Dictionary).is_empty()


## Starts the first-run flow on top of the main menu (`menu` is the MainMenu).
static func begin_first_run(menu: Node) -> void:
	if wants_welcome_back():
		mark_seen(&"welcome_back")
		_sec()["first_run"] = true
		Profile.save_profile()
		var card := WelcomeBackCard.new()
		card.name = "WelcomeBackCard"
		card.sparks = legacy_sparks()
		menu.add_child(card)
		return
	_sec()["first_run"] = true
	Profile.save_profile()
	var flow := FirstRunFlow.new()
	flow.name = "FirstRunFlow"
	menu.add_child(flow)


## True when a tutorial exists that start_tutorial() can launch.
static func has_tutorial() -> bool:
	return ResourceLoader.exists(LEVEL_PATH)


## Starts the tutorial (replayable any time from the menu).
static func start_tutorial() -> void:
	var data := load(LEVEL_PATH) as LevelData
	if data:
		Game.start_tutorial(data)


## "" (never finished or skipped), "skipped" or "completed".
static func tutorial_state() -> String:
	return String(_sec().get("tutorial", ""))


## Records a skip (unless it was completed before). Saves.
static func mark_tutorial_skipped() -> void:
	if tutorial_state() != "completed":
		_sec()["tutorial"] = "skipped"
	if String(_sec().get("guide", "")) == "":
		_sec()["guide"] = "play"
	Profile.save_profile()


## Records a finished Boot Camp and pays the reward the first time only.
## Returns what was paid: {"sparks": int, "item": CosmeticItem or null}.
static func complete_tutorial() -> Dictionary:
	var sec := _sec()
	sec["tutorial"] = "completed"
	if String(sec.get("guide", "")) == "":
		sec["guide"] = "deploy"
	var paid := {"sparks": 0, "item": null}
	if not bool(sec.get("rewarded", false)):
		sec["rewarded"] = true
		Wallet.earn(REWARD_SPARKS, &"tutorial")
		paid["sparks"] = REWARD_SPARKS
		var item := Cosmetics.item(REWARD_ITEM)
		if item and not Cosmetics.is_owned(item):
			Cosmetics.grant(item)
			paid["item"] = item
	Profile.save_profile()
	return paid


# --- hints and coach marks ----------------------------------------------------------

## True when gameplay tips are switched on (Settings, "tips").
static func tips_enabled() -> bool:
	return bool(Profile.data["settings"].get("tips", true))


## True if the hint or coach mark `id` was shown before.
static func seen(id: StringName) -> bool:
	return (_sec().get("seen", []) as Array).has(String(id))


## Remembers that `id` was shown (saved with the next profile save).
static func mark_seen(id: StringName) -> void:
	var list: Array = _sec().get("seen", [])
	if not list.has(String(id)):
		list.append(String(id))
		_sec()["seen"] = list


## The guided first deployment: "" (off), "play", "deploy" or "done".
static func guide_step() -> String:
	return String(_sec().get("guide", ""))


static func set_guide_step(step: String) -> void:
	_sec()["guide"] = step
	Profile.save_profile()
