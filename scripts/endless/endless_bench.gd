class_name EndlessBench
extends Node3D
## The Upgrade Bench of an Endless map, built by the EndlessDirector at an
## `endless_feature` marker of kind "upgrade_bench" (front toward the
## marker's +Z). Standing at it, the player holds interact to pay for the next
## tier of the weapon in hand (EndlessUpgrades: Mk I-III). A chunky
## workbench under a neon sign, a pegboard of tools and a hologram of a
## weapon turning over the vice; the sign names the tier the weapon in hand
## would get next.

## How close (m) the player stands to use it.
const REACH := 2.6
const NEON := Color(0.35, 0.9, 1.0)
const STEEL := Color(0.24, 0.26, 0.3)
const TOP := Color(0.85, 0.42, 0.16)
const BOARD := Color(0.16, 0.2, 0.3)
const TOOLS: Array[Color] = [Color(1.0, 0.78, 0.2), Color(1.0, 0.35, 0.45), Color(0.45, 1.0, 0.55), Color(0.35, 0.8, 1.0)]

var district: StringName
var director: RunDirector
## True while the player stands close enough to use it.
var player_inside := false

var _sign: Label3D
var _holo: Node3D
var _glow: OmniLight3D
var _shown := ""
var _time := 0.0
var _flash := 0.0


func _ready() -> void:
	add_to_group("endless_bench")
	_build()


## What the HUD prompt says while the player stands here.
func prompt() -> Dictionary:
	var w := _weapon()
	if w == null:
		return {}
	var up := director.endless.upgrades
	var t := up.tier(w.id)
	if t >= EndlessUpgrades.MAX_TIER:
		return {"action": "%s  ·  MK III" % w.display_name, "price": 0, "accent": EndlessUpgrades.TIER_COLORS[t],
			"note": "fully upgraded", "disabled": true}
	return {"action": "upgrade %s to %s" % [w.display_name, EndlessUpgrades.NAMES[t + 1]], "price": up.next_price(w.id),
		"accent": EndlessUpgrades.TIER_COLORS[t + 1], "perk": up.next_perk(w)}


## The bench was used: a burst of sparks and the hologram flashes.
func celebrate() -> void:
	_flash = 1.0
	EndlessProps.burst(get_parent(), to_global(Vector3(0, 1.3, 0)), Vector3.UP, TOOLS, 30, 4.5, 0.8, 0.1, 70.0)


func _process(delta: float) -> void:
	_time += delta
	var player := director.player if director else null
	player_inside = player != null and player.alive and player.global_position.distance_to(global_position) < REACH
	if _holo:
		_holo.rotation.y += delta * (4.0 if _flash > 0.0 else 0.9)
		_holo.position.y = 1.65 + sin(_time * 2.0) * 0.04
		_holo.scale = Vector3.ONE * (1.0 + _flash * 0.35)
	_flash = maxf(0.0, _flash - delta * 1.5)
	if _glow:
		_glow.light_energy = 1.6 + _flash * 3.0 + sin(_time * 3.0) * 0.15
	_update_sign()


## The sign names the next tier of the weapon in hand (only when it changes).
func _update_sign() -> void:
	var w := _weapon()
	if w == null or director.endless == null:
		return
	var t := director.endless.upgrades.tier(w.id)
	var text := "UPGRADES\n%s" % ("MAXED" if t >= EndlessUpgrades.MAX_TIER else "%s  %d" % [EndlessUpgrades.NAMES[t + 1], director.endless.upgrades.next_price(w.id)])
	if text == _shown:
		return
	_shown = text
	_sign.text = text
	_sign.modulate = EndlessUpgrades.TIER_COLORS[mini(t + 1, EndlessUpgrades.MAX_TIER)].lerp(Color.WHITE, 0.25)


func _weapon() -> WeaponData:
	if director == null or director.player == null or director.endless == null:
		return null
	return director.player.weapons.current


# --- looks ---------------------------------------------------------------------

## A workbench (front toward +Z): steel legs and an orange top with a hazard
## edge, a vice, a pegboard of glowing tools behind, a neon sign over it and a
## hologram weapon turning above the vice. One collision box keeps the player
## out of it.
func _build() -> void:
	var steel := EndlessProps.mat(STEEL, 0.0, 0.45)
	for x in [-0.95, 0.95]:
		for z in [-0.35, 0.35]:
			EndlessProps.box(self, Vector3(0.14, 0.9, 0.14), Vector3(x, 0.45, z), steel)
	EndlessProps.box(self, Vector3(2.0, 0.08, 0.7), Vector3(0, 0.25, 0), steel)
	EndlessProps.box(self, Vector3(2.3, 0.14, 1.0), Vector3(0, 0.97, 0), EndlessProps.mat(TOP, 0.0, 0.6))
	EndlessProps.box(self, Vector3(2.32, 0.08, 0.06), Vector3(0, 0.97, 0.52), EndlessProps.hazard_mat())
	# The vice and a toolbox on the top.
	EndlessProps.box(self, Vector3(0.36, 0.22, 0.3), Vector3(0.0, 1.15, 0.1), steel)
	EndlessProps.box(self, Vector3(0.12, 0.14, 0.34), Vector3(0.0, 1.3, 0.1), EndlessProps.mat(Color(0.9, 0.2, 0.25), 0.0, 0.4))
	EndlessProps.box(self, Vector3(0.6, 0.3, 0.34), Vector3(-0.75, 1.19, -0.15), EndlessProps.mat(Color(0.85, 0.12, 0.15), 0.0, 0.5))
	EndlessProps.box(self, Vector3(0.62, 0.05, 0.36), Vector3(-0.75, 1.36, -0.15), steel)
	EndlessProps.box(self, Vector3(0.28, 0.12, 0.22), Vector3(0.8, 1.1, 0.05), EndlessProps.mat(Color(0.95, 0.75, 0.15), 0.0, 0.5))
	# The pegboard and its tools.
	EndlessProps.box(self, Vector3(2.3, 1.4, 0.08), Vector3(0, 1.75, -0.48), EndlessProps.mat(BOARD, 0.0, 0.8))
	EndlessProps.box(self, Vector3(2.4, 0.08, 0.14), Vector3(0, 2.48, -0.46), EndlessProps.hazard_mat())
	for i in 6:
		var at := Vector3(-0.85 + i * 0.34, 1.75 + (0.18 if i % 2 == 0 else -0.12), -0.42)
		var size := Vector3(0.08, 0.42, 0.04) if i % 3 != 1 else Vector3(0.24, 0.1, 0.04)
		EndlessProps.box(self, size, at, EndlessProps.mat(TOOLS[i % TOOLS.size()], 1.2))
	# The neon sign over the board.
	EndlessProps.box(self, Vector3(1.9, 0.5, 0.1), Vector3(0, 2.95, -0.46), EndlessProps.mat(Color(0.08, 0.08, 0.12)))
	EndlessProps.box(self, Vector3(1.96, 0.05, 0.12), Vector3(0, 3.22, -0.44), EndlessProps.mat(NEON, 3.0))
	EndlessProps.box(self, Vector3(1.96, 0.05, 0.12), Vector3(0, 2.68, -0.44), EndlessProps.mat(NEON, 3.0))
	_sign = EndlessProps.sign(self, "", 34, Color.WHITE, Vector3(0, 2.95, -0.38))
	_sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_sign.pixel_size = 0.006
	_build_hologram()
	_glow = EndlessProps.light(self, NEON, 1.6, 6.0, Vector3(0, 2.2, 0.6))
	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.3, 1.1, 1.05)
	shape.shape = box
	shape.position = Vector3(0, 0.55, -0.02)
	body.add_child(shape)
	add_child(body)


## A blocky weapon silhouette in additive light, turning over the vice.
func _build_hologram() -> void:
	_holo = Node3D.new()
	_holo.name = "Hologram"
	_holo.position = Vector3(0, 1.65, 0.1)
	add_child(_holo)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(NEON, 0.55)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	EndlessProps.box(_holo, Vector3(0.7, 0.14, 0.12), Vector3(0, 0.06, 0), m)
	EndlessProps.box(_holo, Vector3(0.12, 0.24, 0.1), Vector3(-0.12, -0.12, 0), m)
	EndlessProps.box(_holo, Vector3(0.3, 0.05, 0.05), Vector3(0.48, 0.08, 0), m)
	EndlessProps.box(_holo, Vector3(0.16, 0.08, 0.08), Vector3(0.06, 0.17, 0), m)
	EndlessProps.cylinder(self, 0.32, 0.03, Vector3(0, 1.28, 0.1), EndlessProps.mat(NEON, 2.5), 16)
