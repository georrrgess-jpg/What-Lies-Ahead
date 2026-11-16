class_name OperatorAura
extends Node3D
## The animated aura of a Mythic operator in the menu previews (OperatorPreview:
## Locker, Shop, home menu, player card). The operator item's params.aura
## names the style; "fortune" is Madame Fortuna's:
##   - full: a turning sigil on the floor, a crystal ball (with its own cyan
##     light) and five fortune cards circling her, sparkles spiralling up;
##   - compact (portraits): a halo of turning rays behind the head and the
##     sparkles round the shoulders.
## The sigil, the sparkles, the cards' faces and the ball's mist move in
## shaders; only the ball and the cards are placed each frame (six transforms).
## reveal() plays the entrance: the sigil and the orbits spread out from her.
##
##   var aura := OperatorAura.create(item, compact)   # null for other operators
##   if aura: viewport.add_child(aura); aura.reveal()

const GLOW_SHADER := "res://art/shaders/aura_fortune_glow.gdshader"
const CARD_SHADER := "res://art/shaders/aura_fortune_card.gdshader"
const SPARKLE_SHADER := "res://art/shaders/aura_fortune_sparkle.gdshader"
const ORB_SHADER := "res://art/shaders/aura_fortune_orb.gdshader"
const CARDS := 5
const SPARKLES := 40
const CARD_ORBIT := 0.8
const CARD_HEIGHT := 0.92
const BALL_ORBIT := 0.66
const BALL_HEIGHT := 1.28
const REVEAL_TIME := 1.1

var compact := false
var _time := 0.0
## 0 (gathered at her feet) to 1 (full orbits); tweened by reveal().
var _spread := 1.0
var _cards: Array[MeshInstance3D] = []
var _ball: Node3D
var _faded: Array[ShaderMaterial] = []


## The aura for `item`, or null when the operator has none.
static func create(item: CosmeticItem, compact_view := false) -> OperatorAura:
	if item == null or String(item.params.get("aura", "")) != "fortune":
		return null
	var aura := OperatorAura.new()
	aura.name = "OperatorAura"
	aura.compact = compact_view
	return aura


func _ready() -> void:
	if compact:
		add_child(_quad(Vector2(1.5, 1.5), _glow_material(1), Vector3(0.0, 1.62, -0.5)))
		add_child(_sparkles(0.42, 1.05, 1.1, 0.04))
		return
	var sigil := _quad(Vector2(2.1, 2.1), _glow_material(0), Vector3(0.0, 0.014, 0.0))
	sigil.rotation_degrees.x = -90.0
	add_child(sigil)
	add_child(_sparkles(0.62, 0.05, 2.1, 0.05))
	for i in CARDS:
		var card := _quad(Vector2(0.16, 0.256), _card_material(i), Vector3.ZERO)
		_cards.append(card)
		add_child(card)
	_ball = _crystal_ball()
	add_child(_ball)
	_place()


func _process(delta: float) -> void:
	_time += delta
	if not compact:
		_place()


## The entrance: everything spreads out from her feet and brightens.
func reveal() -> void:
	_spread = 0.0
	_set_strength(0.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_spread", 1.0, REVEAL_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_strength, 0.0, 1.0, REVEAL_TIME * 0.7).set_trans(Tween.TRANS_SINE)


func _set_strength(value: float) -> void:
	for m in _faded:
		m.set_shader_parameter("strength", value)


## Cards circle one way, turning to flash their backs; the ball circles the other way.
func _place() -> void:
	for i in _cards.size():
		var a := _time * 0.42 + TAU * i / CARDS
		var out := Vector3(cos(a), 0.0, sin(a))
		var spin := sin(_time * 0.9 + i * 1.7) * 1.1
		var b := Basis.looking_at(-out, Vector3.UP).rotated(Vector3.UP, spin)
		b = b.rotated(out.cross(Vector3.UP).normalized(), 0.18 * sin(_time * 1.1 + i))
		var lift := CARD_HEIGHT + 0.09 * sin(_time * 1.3 + i * 2.1)
		_cards[i].transform = Transform3D(b.scaled(Vector3.ONE * maxf(_spread, 0.01)), out * CARD_ORBIT * _spread + Vector3.UP * lift * _spread)
	var ba := -_time * 0.33 + 0.6
	_ball.position = Vector3(cos(ba), 0.0, sin(ba)) * BALL_ORBIT * _spread + Vector3.UP * (BALL_HEIGHT + 0.06 * sin(_time * 1.7)) * maxf(_spread, 0.2)


func _quad(size: Vector2, m: Material, at: Vector3) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	return mi


func _shader_material(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	_faded.append(m)
	return m


func _glow_material(mode: int) -> ShaderMaterial:
	var m := _shader_material(GLOW_SHADER)
	m.set_shader_parameter("mode", mode)
	return m


func _card_material(symbol: int) -> ShaderMaterial:
	var m := _shader_material(CARD_SHADER)
	m.set_shader_parameter("symbol", symbol)
	return m


## Sparkles spiralling up: one MultiMesh, a seed per instance, moved by the shader.
func _sparkles(radius: float, base: float, height: float, size: float) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = SPARKLES
	for i in SPARKLES:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		mm.set_instance_custom_data(i, Color(fmod(i * 0.618034, 1.0), 0.0, 0.0, 0.0))
	var m := _shader_material(SPARKLE_SHADER)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("base", base)
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("size", size)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader moves the sparkles far from the instance origins.
	mmi.custom_aabb = AABB(Vector3(-1.5, -0.2, -1.5), Vector3(3.0, 3.6, 3.0))
	return mmi


## The crystal ball: a misty glass sphere on a little gold stand, with a light.
func _crystal_ball() -> Node3D:
	var root := Node3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	sphere.radial_segments = 24
	sphere.rings = 12
	var orb := MeshInstance3D.new()
	orb.mesh = sphere
	orb.material_override = _shader_material(ORB_SHADER)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(orb)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.062
	ring.outer_radius = 0.085
	ring.rings = 24
	var stand := MeshInstance3D.new()
	stand.mesh = ring
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.76, 0.24)
	gold.metallic = 0.8
	gold.roughness = 0.25
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.6, 0.2)
	gold.emission_energy_multiplier = 0.4
	stand.material_override = gold
	stand.position.y = -0.085
	root.add_child(stand)
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.85, 1.0)
	light.light_energy = 1.2
	light.omni_range = 1.1
	light.shadow_enabled = false
	root.add_child(light)
	return root
