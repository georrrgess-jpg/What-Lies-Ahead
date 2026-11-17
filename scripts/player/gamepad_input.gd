class_name GamepadInput
extends RefCounted
## Gamepad play. The project's InputMap has keyboard and mouse only (the menus
## already take a pad through the ui_* actions), so a pad could open a level
## but not move, aim or shoot in it. ensure() adds a standard layout to the
## game's actions at start-up, and look() turns the right stick into look:
##
##   left stick    move                 right stick     look
##   RT / LT       fire / aim           A / B           jump / slide
##   X             reload               Y               switch weapon
##   L3            sprint               RB              dash
##   R3            chain saw (Toxic Ripsaw)
##   LB            station: next weapon of the slot
##   D-pad         station: up energy, down snack, left overshield, right boost
##   Start         pause                Back            start the next wave

const AXIS := 0
const BUTTON := 1
## [kind, axis or button, axis direction]
const LAYOUT := {
	&"move_forward": [AXIS, JOY_AXIS_LEFT_Y, -1.0],
	&"move_back": [AXIS, JOY_AXIS_LEFT_Y, 1.0],
	&"move_left": [AXIS, JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [AXIS, JOY_AXIS_LEFT_X, 1.0],
	&"look_left": [AXIS, JOY_AXIS_RIGHT_X, -1.0],
	&"look_right": [AXIS, JOY_AXIS_RIGHT_X, 1.0],
	&"look_up": [AXIS, JOY_AXIS_RIGHT_Y, -1.0],
	&"look_down": [AXIS, JOY_AXIS_RIGHT_Y, 1.0],
	&"fire": [AXIS, JOY_AXIS_TRIGGER_RIGHT, 1.0],
	&"aim": [AXIS, JOY_AXIS_TRIGGER_LEFT, 1.0],
	&"jump": [BUTTON, JOY_BUTTON_A],
	&"slide": [BUTTON, JOY_BUTTON_B],
	&"reload": [BUTTON, JOY_BUTTON_X],
	&"weapon_next": [BUTTON, JOY_BUTTON_Y],
	&"sprint": [BUTTON, JOY_BUTTON_LEFT_STICK],
	&"dash": [BUTTON, JOY_BUTTON_RIGHT_SHOULDER],
	&"melee": [BUTTON, JOY_BUTTON_RIGHT_STICK],
	&"kiosk_next": [BUTTON, JOY_BUTTON_LEFT_SHOULDER],
	&"interact": [BUTTON, JOY_BUTTON_DPAD_UP],
	&"interact_alt": [BUTTON, JOY_BUTTON_DPAD_DOWN],
	&"buy_overshield": [BUTTON, JOY_BUTTON_DPAD_LEFT],
	&"buy_damage_boost": [BUTTON, JOY_BUTTON_DPAD_RIGHT],
	&"pause": [BUTTON, JOY_BUTTON_START],
	&"start_wave": [BUTTON, JOY_BUTTON_BACK],
}
## Stick deadzone for the actions this adds (look, and any action created here).
const DEADZONE := 0.18
## Radians per second at full deflection (yaw, pitch) at look sensitivity 1.0;
## the deflection is squared, so small pushes aim finely.
const LOOK_SPEED := Vector2(3.4, 2.3)

static var _bound := false


## Adds the pad layout to the actions (once): the ones the game adds at
## start-up are created first, so their keys stay.
static func ensure() -> void:
	if _bound:
		return
	_bound = true
	Loadout.ensure_input_actions()
	Player.ensure_dash_action()
	RunDirector.ensure_station_actions()
	WeaponController.ensure_melee_action()
	for action in LAYOUT:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		var bind: Array = LAYOUT[action]
		var e: InputEvent
		if int(bind[0]) == AXIS:
			var m := InputEventJoypadMotion.new()
			m.axis = bind[1]
			m.axis_value = float(bind[2])
			e = m
		else:
			var b := InputEventJoypadButton.new()
			b.button_index = bind[1]
			e = b
		if not InputMap.action_has_event(action, e):
			InputMap.action_add_event(action, e)


## This frame's look from the right stick (radians: x yaw, y pitch), before
## the aim slow-down; zero with the stick at rest.
static func look(delta: float) -> Vector2:
	var stick := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if stick == Vector2.ZERO:
		return Vector2.ZERO
	var sens := Settings.look_radians() / Settings.LOOK_RADIANS
	return stick * stick.length() * LOOK_SPEED * sens * delta
