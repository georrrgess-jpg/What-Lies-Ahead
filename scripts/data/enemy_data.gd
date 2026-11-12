class_name EnemyData
extends Resource
## One enemy variant. Both variants share scenes/enemies/zombie.tscn and
## scripts/enemies/zombie.gd; this resource supplies the differences.

## Stable ID referenced by wave data.
@export var id: StringName
@export var display_name := ""

@export_group("Stats")
@export var max_health := 100.0
@export var move_speed := 1.8
## Each zombie gets move_speed * (1 +/- this) so groups string out.
@export_range(0.0, 0.5) var speed_variance := 0.12
@export var turn_speed := 6.0
@export var tickets := 10
@export var xp := 10

@export_group("Attack")
@export var damage := 20.0
## Distance at which the windup starts.
@export var attack_range := 1.7
## The hit lands if the player is still within this distance after the windup.
@export var attack_reach := 2.3
@export var attack_windup := 0.7
@export var attack_recover := 0.8
## Forward burst (m/s) when the swipe lands; the attack only hits in front.
@export var lunge_speed := 3.0
## Heavier zombies are pushed less by knockback and stagger less often.
@export var mass := 1.0

@export_group("Body")
## Outfit mesh shown from the shared zombie model ("Tourist", "Lifeguard" or "Bruiser").
@export var outfit: StringName = &"Tourist"
@export var body_scale := 1.0
@export var capsule_radius := 0.45
@export var capsule_height := 1.9
## Hits above this height (metres, before body_scale) count as headshots.
@export var head_height := 1.25
## Random shirt colours for variety (empty = keep the model's colour).
@export var shirt_colors: Array[Color] = []
@export var skin_colors: Array[Color] = []
## Each entry is one slot: options separated by "|", meshes combined with "+",
## an empty option means nothing. e.g. "Acc_Tourist_Cap|Acc_Tourist_Hair+Acc_Tourist_Shades|"
@export var accessory_slots: PackedStringArray = PackedStringArray()
@export var move_animation: StringName = &"Walk"
## Movement speed at which the move animation plays at 1x.
@export var animation_reference_speed := 1.8
@export var avoidance_radius := 0.55

@export_group("Audio")
@export var voice_sounds: Array[StringName] = []
@export var voice_interval := Vector2(3.0, 6.5)
@export var voice_pitch := 1.0
@export var attack_sound: StringName = &"zombie_swipe"
