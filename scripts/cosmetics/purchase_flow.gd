class_name PurchaseFlow
extends RefCounted
## Buying a cosmetic with Sparks, the same way in the Locker and the Shop:
## the refusal when it is locked or too dear (with what is missing and how to
## earn it), the confirm dialog, the purchase itself and its sound, and the
## burst of Sparks that celebrates it.
##
##   PurchaseFlow.request(self, item, weapon_id, _on_bought)   # _on_bought(item)

## How Sparks are earned, for every "not enough" message.
const EARN_HINT := "Pop zombies, clear waves and finish goals to earn more."
const BURST_SPARKS := 18


## Sparks the player still needs to afford `it` (0 when they can).
static func shortfall(it: CosmeticItem) -> int:
	return maxi(0, Cosmetics.price_of(it) - Wallet.balance())


## Starts buying `it` (for `weapon_id` when its requirement is per weapon).
## Refuses with a toast when it is locked or too dear; otherwise asks, buys
## and calls `on_bought(it)`. Returns the confirm dialog, or null if refused.
static func request(from: Control, it: CosmeticItem, weapon_id: StringName, on_bought: Callable) -> KitDialog:
	if it == null or not Cosmetics.is_for_sale(it):
		return null
	if not Cosmetics.can_unlock_purchase(it, weapon_id):
		UiSound.deny()
		UiKit.toast("Locked: %s first." % it.requirement.describe(), UiKit.AMBER, &"icon_lock")
		return null
	var price := Cosmetics.price_of(it)
	if not Wallet.can_afford(price):
		UiSound.deny()
		UiKit.toast("%s more %s needed. %s" % [Wallet.format(shortfall(it)), Wallet.CURRENCY, EARN_HINT], UiKit.RED, &"icon_spark", 5.0)
		return null
	var left := Wallet.balance() - price
	var text := "%s for %s %s.\nYou keep %s." % [LockerCatalog.category_label(it), Wallet.format(price), Wallet.CURRENCY, Wallet.format(left)]
	return UiKit.confirm(_host(from), "BUY %s?" % it.display_name.to_upper(), text, "BUY",
		func(): _buy(it, weapon_id, on_bought))


static func _buy(it: CosmeticItem, weapon_id: StringName, on_bought: Callable) -> void:
	if not Cosmetics.buy(it, weapon_id):
		UiSound.deny()
		return
	UiSound.purchase()
	UiKit.toast("%s is yours. It is in your Locker." % it.display_name, Wallet.COLOR, &"icon_spark")
	if on_bought.is_valid():
		on_bought.call(it)


## Dialogs cover the whole screen, not just the page that asked.
static func _host(from: Control) -> Node:
	var scene := from.get_tree().current_scene
	return scene if scene is Control else from


## A burst of Sparks flying out of the middle of `over` (drawn above it).
static func burst(over: Control) -> void:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.add_child(layer)
	var centre := over.size * 0.5
	var reach := minf(over.size.x, over.size.y) * 0.5
	var tw := layer.create_tween().set_parallel(true)
	for i in BURST_SPARKS:
		var spark := UiKit.spark_icon(randf_range(26.0, 54.0))
		spark.size = spark.custom_minimum_size
		spark.pivot_offset = spark.size * 0.5
		spark.position = centre - spark.size * 0.5
		layer.add_child(spark)
		var angle := TAU * (i + randf() * 0.6) / BURST_SPARKS
		var target := centre + Vector2(cos(angle), sin(angle) * 0.8) * reach * randf_range(0.7, 1.25) - spark.size * 0.5
		var time := randf_range(0.5, 0.8)
		tw.tween_property(spark, "position", target, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(spark, "rotation", randf_range(-1.5, 1.5), time)
		tw.tween_property(spark, "modulate:a", 0.0, 0.3).set_delay(time - 0.3)
	tw.chain().tween_callback(layer.queue_free)
