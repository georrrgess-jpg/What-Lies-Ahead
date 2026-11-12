class_name ScoreKeeper
extends Node
## Run score. Every kill is worth the enemy's base points, multiplied by:
##   - headshot multiplier (finishing blow to the head),
##   - combo multiplier (kills chained within COMBO_WINDOW of each other),
## plus flat bonuses for multi-kills (several kills within MULTI_WINDOW),
## longshots, close calls (kill while under 25% health), and wave clears
## (with a no-damage bonus). The run director owns one of these; the HUD and
## results screen read it.

signal score_changed(score: int, gained: int)
signal combo_changed(combo: int, multiplier: float, time_left: float)
## A labelled award to flash on screen: "HEADSHOT", "DOUBLE KILL", ...
signal award(text: String, points: int, color: Color)

const COMBO_WINDOW := 3.2
const MULTI_WINDOW := 0.6
const COMBO_STEP := 0.1          # +10% per chained kill
const COMBO_MAX := 3.0
const LONGSHOT_DISTANCE := 28.0
const MULTI_NAMES := ["", "", "DOUBLE KILL", "TRIPLE KILL", "QUAD KILL", "MEGA KILL"]

var score := 0
var combo := 0
var best_combo := 0
var kills := 0
var headshot_kills := 0
var _combo_left := 0.0
var _multi_count := 0
var _multi_left := 0.0
var _multi_points := 0
var _damage_this_wave := 0.0
## Points per category, for the results breakdown.
var breakdown := {"kills": 0, "headshots": 0, "combo": 0, "multi": 0, "style": 0, "waves": 0}


func multiplier() -> float:
	return minf(COMBO_MAX, 1.0 + COMBO_STEP * maxf(0, combo - 1))


func combo_time_left() -> float:
	return _combo_left


func _process(delta: float) -> void:
	if _combo_left > 0.0:
		_combo_left -= delta
		if _combo_left <= 0.0:
			combo = 0
			combo_changed.emit(0, 1.0, 0.0)
	if _multi_left > 0.0:
		_multi_left -= delta
		if _multi_left <= 0.0:
			_close_multi()


## Call on every kill. Returns the points it was worth.
func on_kill(base_points: int, headshot: bool, headshot_mult: float, distance: float, player_health_frac: float) -> int:
	kills += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	_combo_left = COMBO_WINDOW
	var base := float(base_points)
	var head_bonus := 0.0
	if headshot:
		headshot_kills += 1
		head_bonus = base * (headshot_mult - 1.0)
	var subtotal := base + head_bonus
	var combo_bonus := subtotal * (multiplier() - 1.0)
	var gained := int(round(subtotal + combo_bonus))
	breakdown["kills"] += int(base)
	breakdown["headshots"] += int(round(head_bonus))
	breakdown["combo"] += int(round(combo_bonus))
	if headshot:
		award.emit("HEADSHOT", int(round(head_bonus)), UiKit.AMBER)
	if distance >= LONGSHOT_DISTANCE:
		gained += _style("LONGSHOT", 50)
	if player_health_frac > 0.0 and player_health_frac < 0.25:
		gained += _style("CLOSE CALL", 75)
	_multi_count += 1
	_multi_points += base_points
	_multi_left = MULTI_WINDOW
	score += gained
	score_changed.emit(score, gained)
	combo_changed.emit(combo, multiplier(), _combo_left)
	return gained


func _style(label: String, points: int) -> int:
	breakdown["style"] += points
	award.emit(label, points, UiKit.CYAN)
	return points


func _close_multi() -> void:
	if _multi_count >= 2:
		var label: String = MULTI_NAMES[mini(_multi_count, MULTI_NAMES.size() - 1)]
		var bonus := 50 * (_multi_count - 1) * _multi_count
		breakdown["multi"] += bonus
		score += bonus
		award.emit(label, bonus, UiKit.PINK_LIGHT)
		score_changed.emit(score, bonus)
	_multi_count = 0
	_multi_points = 0


func on_player_damaged(amount: float) -> void:
	_damage_this_wave += amount


## Wave-clear bonus: 100 per wave number, doubled if the wave was flawless.
func on_wave_cleared(wave_number: int) -> int:
	var bonus := 100 * wave_number
	var flawless := _damage_this_wave <= 0.0
	if flawless:
		bonus *= 2
	_damage_this_wave = 0.0
	breakdown["waves"] += bonus
	score += bonus
	award.emit("FLAWLESS WAVE" if flawless else "WAVE CLEAR", bonus, UiKit.GREEN if flawless else UiKit.CREAM)
	score_changed.emit(score, bonus)
	return bonus


func on_wave_started() -> void:
	_damage_this_wave = 0.0
