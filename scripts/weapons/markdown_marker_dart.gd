class_name MarkerDart
extends Node3D
## One glowing cream price-tag dart of the Markdown Marker. It flies fast
## (SPEED) with a slight drop (GRAVITY), fluttering as it goes, and is a
## plain ray-style hit on the first zombie it touches (MarkdownMarkerMode.dart_hit: headshots, falloff over the distance
## flown, then the tag sticks or a full stack pops). On scenery it leaves a
## scuff and a pinch of paper.

const MASK_WORLD := 1
const MASK_ENEMIES := 4
## Flight speed (m/s), drop (m/s²) and lifetime (s): fast enough to land like a
## shot inside the weapon's range, with an arc that shows on long throws.
const SPEED := 130.0
const GRAVITY := 6.0
const FUSE := 0.55
const SHADER := "res://art/shaders/markdown_marker_tag.gdshader"
const DART_SIZE := Vector2(0.15, 0.09)
const STREAK_LENGTH := 0.7
const PAPER := [Color(1.0, 0.96, 0.88), Color(1.0, 0.31, 0.64), Color(1.0, 0.82, 0.25)]

var mode: MarkdownMarkerMode
var velocity := Vector3.ZERO
var _scale := 1.0
var _fuse := 0.0
var _travelled := 0.0
var _spin := 0.0
var _tag: MeshInstance3D
var _streak: MeshInstance3D
var _exclude: Array[RID] = []

static var _tag_mesh: QuadMesh
static var _tag_mat: ShaderMaterial
static var _streak_mesh: BoxMesh


## Fires a dart of `owner_mode`'s weapon from `from` along `dir` (damage scale `scale`).
static func launch(owner_mode: MarkdownMarkerMode, from: Vector3, dir: Vector3, scale: float) -> void:
	var player := owner_mode.controller.player
	var level := player.get_parent()
	if level == null:
		return
	var d := MarkerDart.new()
	d.mode = owner_mode
	d.velocity = dir * SPEED
	d._scale = scale
	d._fuse = FUSE
	d._spin = randf() * TAU
	d._exclude = [player.get_rid()]
	level.add_child(d)
	d.global_position = from
	d._orient()


func _ready() -> void:
	if _tag_mesh == null:
		_tag_mesh = QuadMesh.new()
		_tag_mesh.size = DART_SIZE
		_tag_mat = ShaderMaterial.new()
		_tag_mat.shader = load(SHADER)
		_tag_mat.set_shader_parameter("fill_color", PAPER[0])
		_tag_mat.set_shader_parameter("border_color", PAPER[1])
		_tag_mat.set_shader_parameter("glow", 1.8)
		_streak_mesh = BoxMesh.new()
		_streak_mesh.size = Vector3(0.025, 0.025, 1.0)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(1.0, 0.85, 0.9, 0.45)
		_streak_mesh.material = m
	_tag = MeshInstance3D.new()
	_tag.mesh = _tag_mesh
	_tag.material_override = _tag_mat
	_tag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_tag)
	_streak = MeshInstance3D.new()
	_streak.mesh = _streak_mesh
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streak)


func _physics_process(delta: float) -> void:
	_fuse -= delta
	if _fuse <= 0.0 or not is_instance_valid(mode.controller):
		queue_free()
		return
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK_WORLD | MASK_ENEMIES)
	query.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_travelled += from.distance_to(to)
		global_position = to
		_spin += delta * 26.0
		_orient()
		return
	var at: Vector3 = hit["position"]
	_travelled += from.distance_to(at)
	var collider = hit["collider"]
	if collider is Zombie and not collider.is_dead():
		mode.dart_hit(collider, at, velocity.normalized(), _travelled, _scale)
		WeaponFx.burst(get_parent(), at, -velocity.normalized(), PAPER, 5, 2.2, 0.25, 0.03)
	else:
		ImpactMarks.scuff(get_parent(), hit, velocity.normalized(), mode.data)
		WeaponFx.burst(get_parent(), at + hit["normal"] * 0.04, hit["normal"], PAPER, 6, 2.0, 0.3, 0.03)
	queue_free()


## The tag faces sideways to the flight and flutters round it; the streak trails behind.
func _orient() -> void:
	var dir := velocity.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var b := Basis.looking_at(dir, up)
	_tag.basis = b * Basis(Vector3.FORWARD, _spin) * Basis(Vector3.RIGHT, PI * 0.5)
	var length := minf(STREAK_LENGTH, _travelled)
	_streak.transform = Transform3D(b.scaled_local(Vector3(1.0, 1.0, maxf(0.01, length))), dir * -length * 0.5)
