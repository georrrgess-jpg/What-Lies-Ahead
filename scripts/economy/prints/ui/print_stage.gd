class_name PrintStage
extends LockerStage
## The reveal's 3D turntable: the Locker's weapon stage (LockerStage) with a
## few moves for the moment a print arrives. The print drops onto the stand
## and spins up, the camera pushes in, a band of light sweeps across the
## print's silhouette (dull for Factory, bright for Polished, a double sweep
## for Mint), and for Prize Fusion a hologram scans the print into being from
## the bottom up. The effects are one canvas shader on the stage's own
## picture (the viewport's alpha masks them to the weapon and its stand).

const SHADER := """shader_type canvas_item;
uniform float sweep = -1.0;
uniform float sweep_power = 0.0;
uniform vec4 sweep_tint : source_color = vec4(1.0);
uniform float holo = 1.0;
uniform vec4 holo_tint : source_color = vec4(0.35, 0.95, 1.0, 1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// The shine: a slanted band of light across the silhouette.
	float d = (UV.x + (1.0 - UV.y) * 0.45) - sweep * 1.45;
	float band = exp(-d * d * 220.0) + 0.35 * exp(-d * d * 30.0);
	c.rgb += sweep_tint.rgb * band * sweep_power * c.a;
	// The hologram: rows above the scan line are still being built.
	if (holo < 1.0) {
		float edge = 1.0 - holo * 1.15;
		float built = smoothstep(edge - 0.02, edge + 0.02, UV.y);
		float lines = 0.55 + 0.45 * sin(UV.y * 420.0 + TIME * 30.0);
		vec3 ghost = holo_tint.rgb * (0.6 + 0.8 * c.a) * lines;
		float mixk = clamp((holo - 0.55) * 2.2, 0.0, 1.0);
		vec3 rebuilt = mix(ghost * c.a + holo_tint.rgb * 0.25 * c.a, c.rgb, mixk);
		float scan = exp(-pow((UV.y - edge) * 60.0, 2.0));
		c.rgb = rebuilt + holo_tint.rgb * scan * 1.4;
		c.a = c.a * built * (0.75 + 0.25 * mixk) + scan * 0.65 * step(0.001, holo);
	}
	COLOR = c;
}"""

static var _shader: Shader

var _fx: ShaderMaterial
var _drop: Tween


func _ready() -> void:
	super._ready()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_fx = ShaderMaterial.new()
	_fx.shader = _shader
	material = _fx


## Shows the print on the stand at rest (no drop, no sweep).
func show_print(weapon: WeaponData, p: Dictionary) -> void:
	var loadout := Cosmetics.weapon_loadout(weapon.id) if weapon else {}
	loadout["finish"] = PrizePrints.finish_of(p)
	loadout["print"] = p
	show_weapon(weapon, loadout)
	set_holo(1.0)
	set_sweep(-1.0)


## The print falls onto the stand with a bounce, spins up a full turn as it
## settles, and the camera eases in.
func drop_in(seconds := 0.9) -> void:
	if _drop:
		_drop.kill()
	_pivot.position.y = 0.9
	_yaw = 62.0 - 360.0
	_idle = -seconds
	_camera.fov = 52.0
	_drop = create_tween().set_parallel(true)
	_drop.tween_property(_pivot, "position:y", 0.0, seconds * 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_drop.tween_property(self, "_yaw", 62.0, seconds * 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drop.tween_property(_camera, "fov", 38.0, seconds * 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Settles everything at once (skip).
func settle() -> void:
	if _drop:
		_drop.kill()
	_pivot.position.y = 0.0
	_yaw = 62.0
	_camera.fov = 38.0
	set_sweep(-1.0)
	set_holo(1.0)


## One sweep of light across the print: brighter and wider with the grade.
func sweep_tween(grade: int, tint: Color) -> Tween:
	_fx.set_shader_parameter("sweep_tint", tint.lerp(Color.WHITE, 0.55))
	_fx.set_shader_parameter("sweep_power", [0.45, 0.9, 1.5][clampi(grade, 0, 2)])
	var tw := create_tween()
	tw.tween_method(set_sweep, -0.2, 1.2, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if grade >= 2:
		tw.tween_method(set_sweep, -0.2, 1.2, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(set_sweep.bind(-1.0))
	return tw


func set_sweep(v: float) -> void:
	_fx.set_shader_parameter("sweep", v)


## 0 = nothing built yet, 1 = the finished print (no hologram).
func set_holo(v: float) -> void:
	_fx.set_shader_parameter("holo", v)
