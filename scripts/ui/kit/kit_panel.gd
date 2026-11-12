class_name KitPanel
extends PanelContainer
## The kit's panels, all 9-slice textures from art/ui:
##   SIGNBOARD  cream-trimmed board on dark aubergine: information (stats, details).
##   METAL      riveted teal frame around a dark recess: trays, grids, lists.
##   PLATE      solid teal metal plate: bars and small plaques.
##   NEON       dark plate with a neon outline in `accent`: slots, highlights.
##   CARD       dark rounded tile: items inside another panel.
## Make one with UiKit.signboard() / metal_frame() / metal_plate() /
## neon_panel() / card_panel(), then add one child (usually a box container).

enum Kind { SIGNBOARD, METAL, PLATE, NEON, CARD }

const _BOXES := {
	Kind.SIGNBOARD: &"signboard",
	Kind.METAL: &"metal_frame",
	Kind.PLATE: &"metal_plate",
	Kind.NEON: &"neon_plate",
	Kind.CARD: &"card",
}
## Distance between the extra rivets along the long edges of a METAL frame.
const RIVET_SPACING := 240.0

var kind := Kind.SIGNBOARD
## Outline colour of a NEON panel.
var accent := UiKit.CYAN:
	set(v):
		accent = v
		if kind == Kind.NEON and _box:
			_box.modulate_color = v
var _box: StyleBoxTexture
var _padding := -1.0


static func make(panel_kind: Kind, padding := -1.0) -> KitPanel:
	var p := KitPanel.new()
	p.kind = panel_kind
	p._padding = padding
	p._style()
	return p


func _style() -> void:
	var name: StringName = _BOXES[kind]
	if kind == Kind.NEON or _padding >= 0.0:
		_box = KitTex.box_copy(name, accent if kind == Kind.NEON else Color.WHITE, Vector2(_padding, _padding))
	else:
		_box = KitTex.box(name)
	add_theme_stylebox_override("panel", _box)


## Changes the inner padding (pixels between the frame and the content).
func set_padding(horizontal: float, vertical: float) -> void:
	if _box == KitTex.box(_BOXES[kind]):
		_box = _box.duplicate()
		add_theme_stylebox_override("panel", _box)
	_box.content_margin_left = horizontal
	_box.content_margin_right = horizontal
	_box.content_margin_top = vertical
	_box.content_margin_bottom = vertical


func _draw() -> void:
	if kind != Kind.METAL:
		return
	# Long frames get rivets along the top and bottom rails.
	var rivet := KitTex.tex(&"rivet")
	var count := int(size.x / RIVET_SPACING)
	if rivet == null or count < 2:
		return
	var step := size.x / count
	for i in range(1, count):
		var x := step * i - 12.0
		draw_texture(rivet, Vector2(x, 0.0))
		draw_texture(rivet, Vector2(x, size.y - 24.0))
