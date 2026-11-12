extends Node
## The player's Sparks: the permanent currency.
##
## Every zombie carries a stolen Spark (the glow in its eyes). Popping one
## sets it free, and the player banks it. Sparks are earned by playing (kills,
## waves, clears, level-ups, mastery, challenges, leftover tickets) and spent in
## the shop on cosmetics that are for sale (CosmeticItem.price > 0). They never
## buy power: weapons and anything that changes combat come from progression.
##
## State lives in Profile.section("wallet"). Earning during a run only changes
## memory; the run director's commits save it. Spending saves immediately.

## The balance changed (earned or spent).
signal balance_changed(balance: int)
signal earned(amount: int, source: StringName)
signal spent(amount: int, what: StringName)

const CURRENCY := "Sparks"
const CURRENCY_SINGULAR := "Spark"
## Colour used for Sparks everywhere in the UI.
const COLOR := Color("ffd84a")
const COLOR_GLOW := Color("38f0ff")


func _sec() -> Dictionary:
	var s := Profile.section("wallet")
	if not s.has("balance"):
		s["balance"] = 0
	if not s.has("lifetime"):
		s["lifetime"] = 0
	return s


## Sparks the player can spend now.
func balance() -> int:
	return int(_sec()["balance"])


## Sparks ever earned (for stats and challenges).
func lifetime_earned() -> int:
	return int(_sec()["lifetime"])


func can_afford(amount: int) -> bool:
	return amount <= balance()


## Adds Sparks. `source` names where they came from (&"kill", &"wave",
## &"clear", &"level_up", &"mastery", &"challenge", &"tickets", ...).
func earn(amount: int, source: StringName = &"") -> void:
	if amount <= 0:
		return
	var s := _sec()
	s["balance"] = int(s["balance"]) + amount
	s["lifetime"] = int(s["lifetime"]) + amount
	earned.emit(amount, source)
	balance_changed.emit(int(s["balance"]))


## Takes Sparks if the player has them and saves the profile. `what` names the
## purchase (an item id). Returns false, changing nothing, if they cannot pay.
func spend(amount: int, what: StringName = &"") -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	var s := _sec()
	s["balance"] = int(s["balance"]) - amount
	Profile.save_profile()
	spent.emit(amount, what)
	balance_changed.emit(int(s["balance"]))
	return true


## "1,250" (thousands separators), for every place an amount is shown.
static func format(amount: int) -> String:
	var digits := str(absi(amount))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + out
