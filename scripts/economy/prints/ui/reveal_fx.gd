class_name RevealFx
extends Control
## The light and confetti of a Prize reveal, drawn on one full-screen layer:
## turning rays and a soft glow behind everything, shockwave rings, confetti
## that bursts and tumbles down, streamers that unfurl, and twinkling
## sparkles. Every particle lives in a fixed pool (packed arrays filled in
## place), so a burst allocates nothing and an idle layer does no work.
##
##   fx.burst(rarity, centre, colour)   # 0 Common .. 3 Legendary
##   fx.sparkle(at, 12, Color.GOLD)     # a twinkle around a point
##   fx.rays = 1.0                      # the turning rays behind the reveal

const CONFETTI := 220
const STREAMERS := 10
const STREAMER_POINTS := 14
const SPARKS := 64
const RINGS := 4
const RAY_COUNT := 20
const GRAVITY := 900.0
## Confetti pieces and streamers per rarity.
const BURST_CONFETTI := [36, 80, 130, 220]
const BURST_STREAMERS := [0, 2, 6, 10]
const BURST_RINGS := [1, 1, 2, 3]
const PALETTE := [Color("ff3fa4"), Color("35f0ff"), Color("ffc24a"), Color("9f8bff"), Color("52f060"), Color("fff3dc")]

## 0-1: the turning rays and glow behind the reveal.
var rays := 0.0
## Where the rays and glow are centred (this control's space).
var centre := Vector2.ZERO
var color := Color.WHITE
## Gold sequence (Legendary): the rays turn gold, wider and faster.
var golden := 0.0
var _time := 0.0
var _active := 0.0
# Confetti.
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _rot := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _life := PackedFloat32Array()
var _col := PackedColorArray()
var _shape := PackedInt32Array()
# Streamers: a launch point, a velocity, an age and a colour each.
var _s_pos := PackedVector2Array()
var _s_vel := PackedVector2Array()
var _s_age := PackedFloat32Array()
var _s_col := PackedColorArray()
var _line := PackedVector2Array()
# Sparkles and rings.
var _k_pos := PackedVector2Array()
var _k_age := PackedFloat32Array()
var _k_col := PackedColorArray()
var _k_next := 0
var _r_age := PackedFloat32Array()
var _r_col := PackedColorArray()
var _r_at := PackedVector2Array()
var _tri := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
var _tri_cols := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
var _star := PackedVector2Array()
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# (Packed arrays are values: each one is sized by name.)
	_pos.resize(CONFETTI)
	_vel.resize(CONFETTI)
	_rot.resize(CONFETTI)
	_spin.resize(CONFETTI)
	_life.resize(CONFETTI)
	_col.resize(CONFETTI)
	_shape.resize(CONFETTI)
	_life.fill(0.0)
	_s_pos.resize(STREAMERS)
	_s_vel.resize(STREAMERS)
	_s_age.resize(STREAMERS)
	_s_age.fill(-1.0)
	_s_col.resize(STREAMERS)
	_line.resize(STREAMER_POINTS)
	_k_pos.resize(SPARKS)
	_k_age.resize(SPARKS)
	_k_age.fill(-1.0)
	_k_col.resize(SPARKS)
	_r_age.resize(RINGS)
	_r_age.fill(-1.0)
	_r_col.resize(RINGS)
	_r_at.resize(RINGS)
	_star.resize(8)


## Clears every particle (the overlay closed or skipped).
func clear() -> void:
	_life.fill(0.0)
	_s_age.fill(-1.0)
	_k_age.fill(-1.0)
	_r_age.fill(-1.0)
	rays = 0.0
	golden = 0.0
	queue_redraw()


## The capsule pops: confetti, streamers and rings by `rarity` (0-3) at `at`.
func burst(rarity: int, at: Vector2, burst_color: Color) -> void:
	rarity = clampi(rarity, 0, 3)
	var count: int = BURST_CONFETTI[rarity]
	var speed := 520.0 + 160.0 * rarity
	var spawned := 0
	for i in CONFETTI:
		if spawned >= count:
			break
		if _life[i] > 0.0:
			continue
		var a := _rng.randf() * TAU
		var v := Vector2.from_angle(a) * speed * _rng.randf_range(0.35, 1.0)
		v.y -= 280.0 * _rng.randf()
		_pos[i] = at + Vector2.from_angle(a) * 30.0
		_vel[i] = v
		_rot[i] = _rng.randf() * TAU
		_spin[i] = _rng.randf_range(-9.0, 9.0)
		_life[i] = _rng.randf_range(1.8, 3.2)
		_col[i] = burst_color.lerp(Color.WHITE, 0.25) if _rng.randf() < 0.45 else PALETTE[_rng.randi() % PALETTE.size()]
		_shape[i] = _rng.randi() % 3
		spawned += 1
	for i in mini(BURST_STREAMERS[rarity], STREAMERS):
		var a := -PI * 0.5 + _rng.randf_range(-1.1, 1.1)
		_s_pos[i] = at
		_s_vel[i] = Vector2.from_angle(a) * _rng.randf_range(700.0, 1050.0)
		_s_age[i] = 0.0
		_s_col[i] = burst_color if i % 2 == 0 else PALETTE[i % PALETTE.size()]
	for i in mini(BURST_RINGS[rarity], RINGS):
		_r_age[i] = -0.12 * i
		_r_col[i] = burst_color
		_r_at[i] = at
	_active = 4.0


## Gold coins and confetti raining from the top (the Legendary sequence).
func rain(count: int) -> void:
	var spawned := 0
	for i in CONFETTI:
		if spawned >= count:
			break
		if _life[i] > 0.0:
			continue
		_pos[i] = Vector2(_rng.randf() * size.x, -_rng.randf() * size.y * 0.5 - 20.0)
		_vel[i] = Vector2(_rng.randf_range(-60.0, 60.0), _rng.randf_range(80.0, 260.0))
		_rot[i] = _rng.randf() * TAU
		_spin[i] = _rng.randf_range(-6.0, 6.0)
		_life[i] = _rng.randf_range(2.4, 3.6)
		_col[i] = Color("ffd35c") if _rng.randf() < 0.7 else Color("fff3dc")
		_shape[i] = 2 if _rng.randf() < 0.5 else 0
		spawned += 1
	_active = 4.0


## A twinkle of `count` sparkles scattered around `at`.
func sparkle(at: Vector2, count: int, sparkle_color: Color, spread := 120.0) -> void:
	for n in count:
		var i := _k_next
		_k_next = (_k_next + 1) % SPARKS
		_k_pos[i] = at + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread * 0.6, spread * 0.6))
		_k_age[i] = -_rng.randf() * 0.35
		_k_col[i] = sparkle_color
	_active = maxf(_active, 1.5)


func _process(delta: float) -> void:
	_time += delta
	if _active <= 0.0 and rays <= 0.0:
		return
	_active = maxf(0.0, _active - delta)
	for i in CONFETTI:
		if _life[i] <= 0.0:
			continue
		var v := _vel[i]
		v.y += GRAVITY * 0.45 * delta
		v *= 1.0 - 1.6 * delta
		v.x += sin(_time * 3.0 + i) * 30.0 * delta
		_vel[i] = v
		_pos[i] += v * delta
		_rot[i] += _spin[i] * delta
		_life[i] -= delta
	for i in STREAMERS:
		if _s_age[i] < 0.0:
			continue
		_s_age[i] += delta
		if _s_age[i] > 2.6:
			_s_age[i] = -1.0
	for i in SPARKS:
		if _k_age[i] > -1.0 and _k_age[i] < 0.9:
			_k_age[i] += delta
		elif _k_age[i] >= 0.9:
			_k_age[i] = -1.0
	for i in RINGS:
		if _r_age[i] > -1.0:
			_r_age[i] += delta
			if _r_age[i] > 1.0:
				_r_age[i] = -1.0
	queue_redraw()


func _draw() -> void:
	if rays > 0.0:
		_draw_rays()
	for i in RINGS:
		if _r_age[i] >= 0.0:
			var t := _r_age[i]
			draw_arc(_r_at[i], 60.0 + t * size.length() * 0.45, 0.0, TAU, 64, Color(_r_col[i], 0.7 * (1.0 - t)), 14.0 * (1.0 - t) + 2.0, true)
	for i in STREAMERS:
		if _s_age[i] >= 0.0:
			_draw_streamer(i)
	for i in CONFETTI:
		if _life[i] > 0.0:
			_draw_piece(i)
	for i in SPARKS:
		if _k_age[i] >= 0.0:
			_draw_sparkle(_k_pos[i], _k_age[i], _k_col[i])


func _draw_rays() -> void:
	var reach := size.length() * 0.7
	var gold := Color("ffd35c")
	var c := color.lerp(gold, golden)
	var turn := _time * (0.16 + golden * 0.25)
	for i in RAY_COUNT:
		var a := turn + TAU * i / RAY_COUNT
		var w := (0.06 + 0.03 * sin(_time * 1.3 + i)) * (1.0 + golden * 0.6)
		_tri[0] = centre
		_tri[1] = centre + Vector2.from_angle(a - w) * reach
		_tri[2] = centre + Vector2.from_angle(a + w) * reach
		_tri_cols[0] = Color(c, (0.3 + golden * 0.25) * rays)
		_tri_cols[1] = Color(c, 0.0)
		_tri_cols[2] = Color(c, 0.0)
		draw_polygon(_tri, _tri_cols)
	for k in 7:
		draw_circle(centre, (7 - k) * 70.0, Color(c, (0.045 + golden * 0.03) * rays))


func _draw_piece(i: int) -> void:
	var fade := clampf(_life[i] / 0.5, 0.0, 1.0)
	var col := Color(_col[i], fade)
	var flip := absf(cos(_rot[i] * 1.7))
	draw_set_transform(_pos[i], _rot[i], Vector2(1.0, 0.25 + 0.75 * flip))
	match _shape[i]:
		0:
			draw_rect(Rect2(-9, -5, 18, 10), col)
		1:
			draw_rect(Rect2(-12, -3, 24, 6), col)
		_:
			draw_circle(Vector2.ZERO, 7.0, col)
			draw_circle(Vector2(-2, -2), 2.5, Color(1, 1, 1, 0.6 * fade))
	draw_set_transform(Vector2.ZERO)


## A streamer: a ribbon thrown up that waves as it falls.
func _draw_streamer(i: int) -> void:
	var t := _s_age[i]
	var alpha := clampf((2.6 - t) / 0.6, 0.0, 1.0)
	var col := _s_col[i]
	for k in STREAMER_POINTS:
		var lag := t - k * 0.035
		if lag < 0.0:
			lag = 0.0
		var p := _s_pos[i] + _s_vel[i] * lag * exp(-lag * 1.2) + Vector2(0, GRAVITY * 0.18 * lag * lag)
		p.x += sin(lag * 7.0 + i * 1.7 + k * 0.6) * 18.0 * minf(1.0, lag * 2.0)
		_line[k] = p
	draw_polyline(_line, Color(col, alpha), 8.0, true)
	draw_polyline(_line, Color(col.lerp(Color.WHITE, 0.5), alpha * 0.6), 2.5, true)


## A four-pointed twinkle that grows and fades.
func _draw_sparkle(at: Vector2, age: float, col: Color) -> void:
	var k := sin(clampf(age / 0.9, 0.0, 1.0) * PI)
	var r := 22.0 * k
	for j in 8:
		var a := TAU * j / 8.0 + age * 2.0
		_star[j] = at + Vector2.from_angle(a) * (r if j % 2 == 0 else r * 0.22)
	draw_colored_polygon(_star, Color(col, k))
	draw_circle(at, r * 0.18, Color(1, 1, 1, k))
