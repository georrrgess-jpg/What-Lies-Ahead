extends Node
## Player options. Values live in the profile; this applies them to the engine.

signal changed

## Mouse look at "Look sensitivity" 1.0, in radians per mouse count (screen
## pixel): about 34 cm of mouse travel per 360° turn with an 800 DPI mouse.
const LOOK_RADIANS := TAU / (34.0 / 2.54 * 800.0)
## Look speed of the old "mouse_sensitivity" at 1.0 (radians per pixel of a
## 1920x1080 window), to carry a value saved by an older version across.
const LEGACY_LOOK_RADIANS := 0.0022
const LOOK_RANGE := Vector2(0.1, 5.0)
## Defaults of options newer than Profile.DEFAULT_SETTINGS.
const EXTRA_DEFAULTS := {"look_sensitivity": 1.0, "camera_motion": 1.0}

var _headless := false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	apply_all()


func value(key: String):
	var saved: Dictionary = Profile.data["settings"]
	if saved.has(key):
		return saved[key]
	if key == "look_sensitivity":
		return _carried_look_sensitivity()
	return Profile.DEFAULT_SETTINGS.get(key, EXTRA_DEFAULTS.get(key))


## A profile saved before "Look sensitivity" existed keeps its own look speed:
## a changed "mouse_sensitivity" becomes the same turn per mouse count, and the
## old default becomes the new default.
func _carried_look_sensitivity() -> float:
	var old := float(Profile.data["settings"].get("mouse_sensitivity", 1.0))
	if is_equal_approx(old, float(Profile.DEFAULT_SETTINGS.get("mouse_sensitivity", 1.0))):
		return EXTRA_DEFAULTS["look_sensitivity"]
	return clampf(old * LEGACY_LOOK_RADIANS / LOOK_RADIANS, LOOK_RANGE.x, LOOK_RANGE.y)


## Mouse look in radians per mouse count, from "Look sensitivity".
func look_radians() -> float:
	return LOOK_RADIANS * clampf(float(value("look_sensitivity")), LOOK_RANGE.x, LOOK_RANGE.y)


func set_value(key: String, v, persist := false) -> void:
	Profile.data["settings"][key] = v
	apply_all()
	if persist:
		Profile.save_profile()


func save() -> void:
	Profile.save_profile()


func reset_to_defaults() -> void:
	Profile.data["settings"] = Profile.DEFAULT_SETTINGS.duplicate()
	apply_all()
	Profile.save_profile()


func is_low_graphics() -> bool:
	return String(value("graphics")) == "low"


## Multiplier for camera shake (0 = off).
func shake_scale() -> float:
	return clampf(float(value("camera_shake")), 0.0, 1.0)


## Multiplier for head bob, roll, landing dips, sway and speed FOV (0 = off).
func camera_motion() -> float:
	return clampf(float(value("camera_motion")), 0.0, 1.0)


## Multiplier for screen flashes and muzzle light (0 = off).
func flash_scale() -> float:
	return clampf(float(value("flashes")), 0.0, 1.0)


## -1 when "Invert look Y" is on, else 1: multiplies vertical mouse look.
func look_y_sign() -> float:
	return -1.0 if bool(value("invert_y")) else 1.0


func apply_all() -> void:
	_apply_audio()
	_apply_graphics()
	_apply_window()
	changed.emit()


func _apply_audio() -> void:
	_set_bus("Master", float(value("master_volume")))
	_set_bus("Music", float(value("music_volume")))
	_set_bus("SFX", float(value("sfx_volume")))
	_set_bus("Ambience", float(value("ambience_volume")))


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.001)))


func _apply_graphics() -> void:
	var low := is_low_graphics()
	var vp := get_tree().root
	vp.msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X
	vp.scaling_3d_scale = 0.75 if low else 1.0
	RenderingServer.directional_shadow_atlas_set_size(2048 if low else 4096, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_HARD if low else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	# Level scenes tag optional dressing so the low preset can drop it.
	get_tree().call_group("graphics_listener", "apply_graphics_preset", low)


func _apply_window() -> void:
	if _headless:
		return
	var want_full := bool(value("fullscreen"))
	var is_full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if want_full != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED)
