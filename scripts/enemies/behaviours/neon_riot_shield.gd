class_name NeonRiotShieldBehaviour
extends EnemyBehaviour
## Riot Bruiser: a riot shield covers its front. Body shots from the front
## mostly hit the shield (cyan sparks and a clang; only a little damage gets
## through). Headshots over the shield, and shots from the side or behind,
## hit normally. The shield soaks `shield_health` before it shatters; then
## the bruiser drops its guard and enrages.

## Hits whose direction from the zombie is within this cone (dot with its
## facing) count as frontal.
@export var front_cone := 0.25
## Share of a frontal body shot the shield absorbs.
@export_range(0.0, 1.0) var block_fraction := 0.85
@export var shield_health := 240.0
## Accessory mesh hidden when the shield breaks.
@export var shield_mesh := "Acc_Riot_Shield"
@export var rage_seconds := 4.0
@export var spark_color := Color(0.35, 0.95, 1.0)
@export var block_sound: StringName = &"neon_shield_block"
@export var break_sound: StringName = &"neon_shield_break"

## Minimum seconds between block sparks/clangs, so beams and fast weapons
## don't stack dozens of them.
const BLOCK_FX_GAP := 0.12

var _shield := 0.0
var _mesh: Node3D
var _next_fx_ms := 0


func on_ready(z: Zombie) -> void:
	_shield = shield_health
	_mesh = z.model_root.find_child(shield_mesh, true, false) as Node3D


func on_hit(z: Zombie, amount: float, hit_position: Vector3, headshot: bool) -> float:
	if _shield <= 0.0 or headshot:
		return amount
	var forward := Vector3(sin(z.rotation.y), 0.0, cos(z.rotation.y))
	var to_hit := hit_position - z.global_position
	to_hit.y = 0.0
	if to_hit.length() < 0.01 or forward.dot(to_hit.normalized()) < front_cone:
		return amount
	var blocked := amount * block_fraction
	_shield -= blocked
	var now := Time.get_ticks_msec()
	if now >= _next_fx_ms:
		_next_fx_ms = now + int(BLOCK_FX_GAP * 1000.0)
		Fx.impact(z.get_parent(), hit_position, to_hit.normalized(), spark_color)
		Sfx.play_at(block_sound, hit_position, -3.0, randf_range(0.9, 1.1))
	if _shield <= 0.0:
		_break(z, hit_position)
	return amount - blocked


## True while the shield still stands (for HUD or other behaviours).
func is_shielded() -> bool:
	return _shield > 0.0


func _break(z: Zombie, at: Vector3) -> void:
	if _mesh:
		_mesh.visible = false
	Fx.kill_burst(z.get_parent(), at)
	Fx.impact(z.get_parent(), at, Vector3.UP, spark_color)
	Sfx.play_at(break_sound, at, 2.0, 1.0)
	z.enrage(rage_seconds)
