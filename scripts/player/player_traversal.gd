class_name PlayerTraversal
extends RefCounted
## Step-up, mantle and vault for the player's capsule.
##
##   step_up()   lifts the capsule onto a curb or seam up to STEP_HEIGHT when it
##               walks into one (a wall stays a wall);
##   plan()      looks for a ledge ahead. A MANTLE climbs onto a top deep
##               enough to stand on; a VAULT hops over a thin obstacle to the
##               floor beyond;
##   begin() / step()   then drive the body through the move, one physics tick
##               at a time, with move_and_slide (so a zombie in the way blocks it).
##
## Every move is swept with the capsule itself before it starts (test_move with
## the player's own collision mask): up, across, then down onto the landing.
## So a move never ends inside geometry or under a low ceiling, and it never
## crosses the invisible player-only walls (physics layer 5), which stop the
## sweep like any other wall.

enum Kind { NONE, MANTLE, VAULT }

const STEP_HEIGHT := 0.3
## A surface this flat (normal.y) is floor ahead, not a step; a step's top must be this flat.
const STEP_FLAT := 0.95
## How far past this tick's travel a step is looked for.
const STEP_LOOKAHEAD := 0.08
## Lowest ledge worth a mantle from the ground (lower ones are a plain jump).
const LEDGE_MIN := 0.45
## Highest ledge, above the feet and above the floor the player last stood
## on: what a full jump reaches, so jump + mantle never reaches a perch a jump
## alone could not.
const LEDGE_MAX := 1.25
## How far ahead of the capsule a ledge can be grabbed.
const REACH := 0.65
## Clearance above the ledge while moving over it.
const CLEARANCE := 0.08
## Where the capsule centre ends up, past the ledge's front edge.
const MANTLE_DEPTH := 0.32
## Vault: tallest and deepest obstacle, deepest drop on the far side.
const VAULT_MAX_HEIGHT := 1.1
const VAULT_MAX_DEPTH := 0.8
const VAULT_MAX_DROP := 1.5
## Share of the run-up speed a vault keeps, and its slowest crossing speed.
const VAULT_KEEP := 0.85
const VAULT_MIN_SPEED := 4.6
## From this run-up speed a vault wins over a mantle where both fit.
const VAULT_PREFER_SPEED := 6.0
## Share of the run-up speed a mantle keeps, and its slowest exit.
const MANTLE_KEEP := 0.7
const MANTLE_MIN_EXIT := 2.2
## Speed over the top once the capsule clears the ledge.
const MANTLE_OVER_SPEED := 4.6
const FLOOR_NORMAL := 0.7
const TOP_NORMAL := 0.85
const MASK_WORLD := 1
const MASK_ENEMIES := 4

## The move in progress (NONE when idle).
var kind := Kind.NONE

var _body: CharacterBody3D
var _radius := 0.4
var _hit := KinematicCollision3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
# The last plan.
var _plan_kind := Kind.NONE
var _plan_dir := Vector3.ZERO
var _plan_ledge := 0.0
var _plan_gap := 0.0
var _plan_forward := 0.0
# The move in progress.
var _dir := Vector3.ZERO
var _start := Vector3.ZERO
var _ledge := 0.0
var _rise := 0.0
var _gap := 0.0
var _forward := 0.0
var _rise_time := 0.2
var _speed := 0.0
var _exit_speed := 0.0
var _elapsed := 0.0
var _over_time := -1.0
var _duration := 0.3


func _init(body: CharacterBody3D, radius: float) -> void:
	_body = body
	_radius = radius
	_ray.collision_mask = MASK_WORLD


func is_active() -> bool:
	return kind != Kind.NONE


## 0-1 through the move in progress (1 when idle).
func progress() -> float:
	return clampf(_elapsed / _duration, 0.0, 1.0) if is_active() else 1.0


## Height of the planned ledge above the feet.
func planned_height() -> float:
	return _plan_ledge - _body.global_position.y


# --- step-up --------------------------------------------------------------------

## Moves the body by this tick's horizontal travel `motion` when it is about
## to walk into a step: the capsule's round bottom rolls up over the step's
## edge, a little higher each tick, exactly as far forward as it would have
## walked. Returns the height gained (0 or more), or -1 if there is no step
## ahead (the body is then untouched and moves normally).
func step_up(motion: Vector3) -> float:
	var xf := _body.global_transform
	var travel := motion.length()
	if travel < 1e-3:
		return -1.0
	var dir := motion / travel
	# Look a little further than this tick: move_and_slide would wedge the
	# capsule against the edge before a sweep of this tick's travel sees it.
	if not _sweep(xf, dir * (travel + STEP_LOOKAHEAD)):
		return -1.0
	if _hit.get_normal().y > STEP_FLAT or _is_enemy(_hit.get_collider()):
		return -1.0
	# A step has a flat top just past its edge, no higher than STEP_HEIGHT.
	var past := _hit.get_position() + dir * 0.04
	var top := _cast(Vector3(past.x, xf.origin.y + STEP_HEIGHT + 0.05, past.z), Vector3(past.x, xf.origin.y + 0.01, past.z))
	if top.is_empty() or (top["normal"] as Vector3).y < STEP_FLAT or top["position"].y > xf.origin.y + STEP_HEIGHT + 0.01:
		return -1.0
	var up := Vector3.UP * (STEP_HEIGHT + 0.05)
	if _sweep(xf, up):
		return -1.0
	var raised := xf.translated(up)
	# Down a little past the start height: before the capsule reaches the edge
	# it lands back on the floor it is on.
	if _sweep(raised, motion) or not _sweep(raised.translated(motion), -up * 1.3):
		return -1.0
	var landing := raised.origin + motion + _hit.get_travel()
	_body.global_position = landing
	return maxf(0.0, landing.y - xf.origin.y)


# --- planning ---------------------------------------------------------------------

## Looks for a ledge along `dir` (flat, unit length). `floor_y` is the height
## of the floor the player last stood on, `speed` the run-up speed toward the
## ledge. `vault_only` skips mantles (sprinting into a low barrier).
## Returns the kind of move found; begin() starts it.
func plan(dir: Vector3, floor_y: float, airborne: bool, speed: float, vault_only := false) -> Kind:
	_plan_kind = Kind.NONE
	var xf := _body.global_transform
	var feet := xf.origin
	if not _sweep(xf, dir * REACH):
		return Kind.NONE
	var normal := _hit.get_normal()
	if normal.y > FLOOR_NORMAL or normal.dot(dir) > -0.5 or _is_enemy(_hit.get_collider()):
		return Kind.NONE
	var face := maxf((_hit.get_position() - feet).dot(dir), _radius)
	var ledge := _find_top(feet, dir, face, floor_y, airborne)
	if is_nan(ledge):
		return Kind.NONE
	var rise := ledge + CLEARANCE - feet.y
	if _sweep(xf, Vector3.UP * rise):
		return Kind.NONE
	var raised := xf.translated(Vector3.UP * rise)
	var can_mantle := not vault_only and _check_mantle(raised, feet, dir, face, ledge)
	var mantle_forward := _plan_forward
	var can_vault := ledge - feet.y <= VAULT_MAX_HEIGHT and _check_vault(raised, feet, dir, face, ledge)
	if can_vault and (vault_only or speed >= VAULT_PREFER_SPEED or not can_mantle):
		_plan_kind = Kind.VAULT
	elif can_mantle:
		_plan_kind = Kind.MANTLE
		_plan_forward = mantle_forward
	else:
		return Kind.NONE
	_plan_dir = dir
	_plan_ledge = ledge
	_plan_gap = face - _radius
	return _plan_kind


## Top of the obstacle just past its face, within the allowed heights; NAN if none.
func _find_top(feet: Vector3, dir: Vector3, face: float, floor_y: float, airborne: bool) -> float:
	var top_limit := minf(feet.y, floor_y) + LEDGE_MAX
	var low_limit := feet.y + (0.05 if airborne else LEDGE_MIN)
	if top_limit < low_limit:
		return NAN
	var probe := feet + dir * (face + 0.12)
	var hit := _cast(Vector3(probe.x, top_limit + 0.25, probe.z), Vector3(probe.x, low_limit - 0.02, probe.z))
	if hit.is_empty():
		return NAN
	var y: float = hit["position"].y
	if (hit["normal"] as Vector3).y < TOP_NORMAL or y > top_limit or y < low_limit:
		return NAN
	return y


## A mantle needs the capsule to fit on top, with the top under its centre.
func _check_mantle(raised: Transform3D, feet: Vector3, dir: Vector3, face: float, ledge: float) -> bool:
	var forward := face + MANTLE_DEPTH
	if _sweep(raised, dir * forward):
		return false
	var over := raised.translated(dir * forward)
	if not _sweep(over, Vector3.DOWN * (CLEARANCE + 0.15)) or _hit.get_normal().y < FLOOR_NORMAL:
		return false
	var centre := feet + dir * forward
	var support := _cast(Vector3(centre.x, ledge + 0.2, centre.z), Vector3(centre.x, ledge - 0.12, centre.z))
	if support.is_empty():
		return false
	_plan_forward = forward
	return true


## A vault needs a thin obstacle, room to pass over it, and a floor on the far
## side that is lower than its top and not far below the run-up.
func _check_vault(raised: Transform3D, feet: Vector3, dir: Vector3, face: float, ledge: float) -> bool:
	var y := ledge - 0.06
	var far := feet + dir * (face + VAULT_MAX_DEPTH + 0.05)
	var near := feet + dir * (face + 0.02)
	var back := _cast(Vector3(far.x, y, far.z), Vector3(near.x, y, near.z))
	if back.is_empty() or (back["normal"] as Vector3).dot(dir) < 0.5:
		return false
	var depth := ((back["position"] as Vector3) - feet).dot(dir) - face
	var forward := face + depth + _radius + 0.12
	if _sweep(raised, dir * forward):
		return false
	var over := raised.translated(dir * forward)
	var drop := ledge + CLEARANCE - feet.y + VAULT_MAX_DROP
	if not _sweep(over, Vector3.DOWN * drop) or _hit.get_normal().y < FLOOR_NORMAL:
		return false
	var landing := over.origin.y + _hit.get_travel().y
	if landing > ledge - 0.3:
		return false
	_plan_forward = forward
	return true


## Sweeps the capsule from `from` by `motion` with the body's own safe margin
## (as move_and_slide does); true if it hits something (details in _hit).
func _sweep(from: Transform3D, motion: Vector3) -> bool:
	return _body.test_move(from, motion, _hit, _body.safe_margin)


func _cast(from: Vector3, to: Vector3) -> Dictionary:
	_ray.from = from
	_ray.to = to
	return _body.get_world_3d().direct_space_state.intersect_ray(_ray)


static func _is_enemy(collider: Object) -> bool:
	return collider is CollisionObject3D and ((collider as CollisionObject3D).collision_layer & MASK_ENEMIES) != 0


# --- the move -------------------------------------------------------------------

## Starts the last planned move. `velocity` is the body's velocity before it.
func begin(velocity: Vector3) -> void:
	kind = _plan_kind
	_dir = _plan_dir
	_start = _body.global_position
	_ledge = _plan_ledge
	_rise = _plan_ledge + CLEARANCE - _start.y
	_gap = _plan_gap
	_forward = _plan_forward
	_elapsed = 0.0
	_over_time = -1.0
	var toward := maxf(0.0, velocity.dot(_dir))
	if kind == Kind.VAULT:
		_speed = maxf(toward * VAULT_KEEP, VAULT_MIN_SPEED)
		_rise_time = 0.07 + 0.07 * _rise
		_exit_speed = _speed
		_duration = maxf(_rise_time, _forward / _speed)
	else:
		_speed = MANTLE_OVER_SPEED
		_rise_time = 0.15 + 0.08 * _rise
		_exit_speed = maxf(toward * MANTLE_KEEP, MANTLE_MIN_EXIT)
		_duration = _rise_time * 0.85 + (_forward - _gap) / _speed


## Advances the move by one physics tick. Returns false once it has finished
## (or was blocked); the body is then left with its exit velocity.
func step(delta: float) -> bool:
	_elapsed += delta
	var pos := _body.global_position
	var done := (pos - _start).dot(_dir)
	if done >= _forward:
		_finish()
		return false
	if _elapsed > _duration * 2.0 + 0.25:
		_abort()
		return false
	var k := minf(_elapsed / _rise_time, 1.0)
	var target_y := _start.y + _rise * (1.0 - pow(1.0 - k, 3.0))
	_body.velocity = _dir * _horizontal_speed(pos) + Vector3.UP * (target_y - pos.y) / delta
	_body.move_and_slide()
	return true


## Mantle: drift to the wall while pulling up, then roll over the top once the
## feet clear the ledge. Vault: keep the run-up speed all the way.
func _horizontal_speed(pos: Vector3) -> float:
	if kind == Kind.VAULT:
		return _speed
	if _over_time < 0.0:
		if pos.y < _ledge + 0.02:
			return _gap / _rise_time
		_over_time = _elapsed
	return lerpf(_gap / _rise_time, _speed, smoothstep(0.0, 0.07, _elapsed - _over_time))


func _finish() -> void:
	var vault := kind == Kind.VAULT
	kind = Kind.NONE
	_body.velocity = _dir * _exit_speed
	if vault:
		# Leave the top with a little lift; gravity brings the player down beyond.
		_body.velocity.y = 1.2
	else:
		_body.move_and_collide(Vector3.DOWN * (CLEARANCE + 0.04))


func _abort() -> void:
	kind = Kind.NONE
	_body.velocity = Vector3(0.0, minf(_body.velocity.y, 0.0), 0.0)
