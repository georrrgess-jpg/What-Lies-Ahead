class_name MenuButtonFx
extends RefCounted
## Older entry point for menu buttons, kept so existing callers keep working:
## it now returns the kit's SignButton in the family closest to `color`.
## New code should call UiKit.sign_button().


static func make(text_value: String, color: Color, font_size: int, min_size: Vector2) -> SignButton:
	var b := SignButton.make(text_value, _kind_for(color), font_size)
	b.custom_minimum_size = min_size
	return b


static func _kind_for(color: Color) -> SignButton.Kind:
	if color.is_equal_approx(UiKit.PINK):
		return SignButton.Kind.PRIMARY
	if color.is_equal_approx(UiKit.AMBER):
		return SignButton.Kind.GOLD
	if color.is_equal_approx(UiKit.TEAL):
		return SignButton.Kind.SECONDARY
	return SignButton.Kind.NEUTRAL
