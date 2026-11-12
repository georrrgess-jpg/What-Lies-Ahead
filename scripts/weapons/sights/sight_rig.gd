class_name SightRig
extends Node3D
## The sight fitted to one weapon model (a child of the model, made by
## WeaponSights.apply): the weapon's own iron sights, or an optic clamped to
## its top. fit() says where the eye must be to look down the sight, and
## set_aim() keeps an optic's reticle on the player's true point of aim.
##
## It works on any weapon model. A model built to the contract has a
## "SightMount" empty on its top rail (where an optic's base sits), a
## "SightPoint" empty (the eye line of its iron sights) and iron-sight parts
## named "IronSight*". Without a SightMount the mount is found on top of the
## model near the SightPoint. Either way the model's outline is measured
## (SightProfile) and the optic is raised on a riser, or the eye lifted, until
## nothing on the weapon covers the point of aim; iron-sight parts are hidden
## under an optic, and any that would cover the aim point are hidden too.

## The camera's near plane in model units (0.02 m at WeaponView.VIEW_SCALE).
const NEAR := 0.1
## Kept clear under an optic's axis / an iron sight line / a view over a
## blocked sight line (tangent of the angle).
const CLEAR_OPTIC := 0.045
const CLEAR_IRONS := 0.003
const CLEAR_OVER := 0.05
## Aimed field of view assumed until fit() is called (menu previews).
const DEFAULT_FOV := 50.0
const RISER_SIZE := Vector2(0.034, 0.052)
const MAX_RISER := 0.14

var item: CosmeticItem
## The optic draws its own reticle (the HUD's is hidden while aimed).
var has_reticle := false
## Aimed, only the view through the eyepiece is shown (long scopes).
var scope_view := false
## Magnification on top of the weapon's own aimed zoom.
var zoom := 1.0
## Multiplier on the weapon's time to raise the sight.
var ads_time_scale := 1.0
## How dark the screen edges get when aimed (0-1).
var vignette := 0.22
## The optic's window (null for iron sights) and half its height in model units.
var lens: MeshInstance3D
var lens_radius := 0.0
## Iron sights only: the built-in sight line is covered by the weapon, so the
## eye looks over the top instead.
var blocked := false

var _model: Node3D
var _weapon: WeaponData
var _optic: Node3D
var _riser: MeshInstance3D
var _material: ShaderMaterial
var _sight_point := Vector3(0.0, 0.13, 0.05)
var _irons: Array[Node] = []
var _fill := 0.3
## The optic's axis height above its base, its window and both ends along z.
var _axis := 0.04
var _lens_z := 0.0
var _front := -0.04
var _rear := 0.04

static var _blocking_irons := {}


func setup(model: Node3D, weapon: WeaponData, sight: CosmeticItem) -> void:
	_model = model
	_weapon = weapon
	item = sight
	var point := model.find_child("SightPoint", true, false) as Node3D
	if point:
		_sight_point = WeaponCosmetics.to_model(model, point).origin
	_irons = model.find_children("IronSight*", "Node3D", true, false)
	_optic = WeaponSights.build_optic(sight)
	for part in _irons:
		(part as Node3D).visible = _optic == null
	zoom = maxf(1.0, float(WeaponSights.setting(sight, "zoom", 1.0)))
	ads_time_scale = float(WeaponSights.setting(sight, "ads_time", 1.0))
	if _optic == null:
		return
	add_child(_optic)
	_read_optic()
	fit(DEFAULT_FOV)


func _read_optic() -> void:
	has_reticle = true
	scope_view = bool(WeaponSights.setting(item, "scope_view", false))
	vignette = float(WeaponSights.setting(item, "vignette", vignette))
	_fill = float(WeaponSights.setting(item, "fill", _fill))
	for child in _optic.get_children():
		var node_name := String(child.name)
		if node_name.ends_with("_Lens"):
			lens = child as MeshInstance3D
			_material = lens.get_surface_override_material(0) as ShaderMaterial
			_axis = lens.position.y
			_lens_z = lens.position.z
			lens_radius = lens.mesh.get_aabb().size.y * 0.5
		elif node_name.ends_with("_Body"):
			var box := (child as MeshInstance3D).transform * (child as MeshInstance3D).mesh.get_aabb()
			_front = box.position.z
			_rear = box.end.z


func _key(kind: String) -> String:
	return "%s|%s" % [_weapon.id if _weapon else StringName(_model.name), kind]


## Places the sight for an aimed vertical field of view of `fov` degrees and
## returns where the eye must be (in the model's space) to look down it.
func fit(fov: float) -> Vector3:
	var half := tan(deg_to_rad(fov) * 0.5)
	return _fit_optic(half) if _optic else _fit_irons(half)


func _fit_optic(half: float) -> Vector3:
	var mount_node := _model.find_child("SightMount", true, false) as Node3D
	var mount := WeaponCosmetics.to_model(_model, mount_node).origin if mount_node else _sight_point
	var profile := SightProfile.of(_model, _key("optic"), mount.x, _irons)
	# The window fills a set share of the aimed view, at any field of view.
	var relief := clampf(lens_radius / (_fill * half), _rear - _lens_z + NEAR + 0.05, 0.7)
	if mount_node == null:
		mount = _find_mount(profile, relief, half)
	var solved := _solve(profile, mount, relief, half)
	var raise: float = solved.x
	position = mount + Vector3(0.0, raise, 0.0)
	_place_riser(profile, mount, raise)
	return Vector3(mount.x, mount.y + raise + _axis, solved.y)


## For an optic based at `mount`: Vector2(how far it must be raised, the eye's z).
func _solve(profile: SightProfile, mount: Vector3, relief: float, half: float) -> Vector2:
	var axis_y := mount.y + _axis
	var eye_z := profile.clear_eye_z(mount.z + _lens_z + relief, axis_y, half * 1.05, NEAR, 0.4)
	var need := profile.needed_height(eye_z, CLEAR_OPTIC, NEAR)
	# The housing also has to sit above whatever lies under its whole length.
	var under := profile.range_between(mount.z + _front, mount.z + _rear).y
	return Vector2(clampf(maxf(need - axis_y, under - mount.y), 0.0, MAX_RISER), eye_z)


## A model without a SightMount: the spot on top of the weapon near its
## SightPoint that needs the lowest riser and gives the base an even seat.
func _find_mount(profile: SightProfile, relief: float, half: float) -> Vector3:
	var best := _sight_point
	var best_cost := INF
	for i in range(-3, 9):
		var z := _sight_point.z - i * 0.02
		var seat := profile.range_between(z - RISER_SIZE.y * 0.5, z + RISER_SIZE.y * 0.5)
		if seat.y <= SightProfile.EMPTY:
			continue
		var mount := Vector3(_sight_point.x, seat.y, z)
		var cost := _solve(profile, mount, relief, half).x + (seat.y - seat.x) * 0.5 + absf(z - _sight_point.z) * 0.15
		if cost < best_cost:
			best = mount
			best_cost = cost
	return best


## A block under the base wherever the optic stands clear of the weapon.
func _place_riser(profile: SightProfile, mount: Vector3, raise: float) -> void:
	var seat := profile.range_between(mount.z - RISER_SIZE.y * 0.5, mount.z + RISER_SIZE.y * 0.5)
	var floor_y := mount.y if seat.y <= SightProfile.EMPTY else minf(seat.x, mount.y)
	var height := minf(mount.y + raise - floor_y, MAX_RISER)
	if height < 0.003:
		if _riser:
			_riser.visible = false
		return
	if _riser == null:
		_riser = MeshInstance3D.new()
		_riser.name = "Riser"
		_riser.mesh = BoxMesh.new()
		_riser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var body := _optic.find_child("*_Body", false, false) as MeshInstance3D
		if body:
			_riser.material_override = body.mesh.surface_get_material(0)
		add_child(_riser)
	_riser.visible = true
	(_riser.mesh as BoxMesh).size = Vector3(RISER_SIZE.x, height + 0.006, RISER_SIZE.y)
	_riser.position = Vector3(0.0, -height * 0.5, 0.0)


func _fit_irons(half: float) -> Vector3:
	var profile := SightProfile.of(_model, _key("irons"), _sight_point.x, _irons)
	var depth := (_weapon.ads_depth if _weapon else 0.11) / WeaponView.VIEW_SCALE
	var eye_z := profile.clear_eye_z(_sight_point.z + depth, _sight_point.y, half * 1.05, NEAR, 0.4)
	blocked = profile.needed_height(eye_z, CLEAR_IRONS, NEAR) > _sight_point.y
	var eye := Vector3(_sight_point.x, _sight_point.y, eye_z)
	if blocked:
		eye.y = profile.needed_height(eye_z, CLEAR_OVER, NEAR)
	_hide_blocking_irons(eye)
	return eye


## Iron-sight parts that cover the point of aim (a glass panel, a hood) are
## hidden; posts that reach up to it and rings around it stay.
func _hide_blocking_irons(eye: Vector3) -> void:
	if _irons.is_empty():
		return
	var key := _key("irons")
	if not _blocking_irons.has(key):
		var rays: Array[Vector3] = [Vector3(-0.004, 0.006, -1.0).normalized(), Vector3(0.004, 0.006, -1.0).normalized()]
		var names: Array[String] = []
		for part in _irons:
			if SightProfile.rays_blocked(_model, part, eye, rays) > 0:
				names.append(String(part.name))
		_blocking_irons[key] = names
	var hidden: Array = _blocking_irons[key]
	for part in _irons:
		(part as Node3D).visible = not hidden.has(String(part.name))


## Menus paint the reticle on the glass; the viewmodel turns that off and
## drives the reticle with set_aim().
func set_preview(on: bool) -> void:
	if _material:
		_material.set_shader_parameter("preview", 1.0 if on else 0.0)


## Points the reticle along `aim` (the true aim in the camera's space) at
## strength `power` (0-1). `occlude` 1 closes a scope's glass (dark).
func set_aim(aim: Basis, power: float, occlude := 0.0) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("aim_basis", aim)
	_material.set_shader_parameter("power", power)
	_material.set_shader_parameter("occlude", occlude)


## Re-reads the reticle colour (after the setting changed).
func refresh_color() -> void:
	if _material:
		_material.set_shader_parameter("reticle_color", WeaponSights.reticle_color(item))
