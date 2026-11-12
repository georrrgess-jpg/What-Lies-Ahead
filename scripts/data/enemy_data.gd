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
## Base score for a kill (before headshot and combo multipliers).
@export var score := 100
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
## How widely this enemy flanks (degrees either side of a straight approach).
@export var flank_degrees := 70.0
## When an ally dies within this distance, this enemy gets enraged (0 = never).
@export var enrage_radius := 9.0
@export var enrage_seconds := 2.0

@export_group("Charge")
## Speed multiplier while charging; 1 or less disables the charge.
@export var charge_speed_mult := 0.0
## Charges start only between these distances (metres) with a clear line.
@export var charge_range := Vector2(5.0, 13.0)
## Roar-and-stare time before the rush; the threat ring warns during it.
@export var charge_telegraph := 0.6
@export var charge_duration := 1.3
@export var charge_cooldown := 7.0

@export_group("Body")
## Model scene for this enemy. Empty = the shared boardwalk zombie
## (art/models/zombie.glb). A custom model needs an AnimationPlayer with clips
## named Idle, Walk, Run and Attack (a "-loop" suffix is fine), ideally the
## rest of the zombie_anim.py set (Stagger, Die_*, Emerge...), a skeleton with
## a "Head" bone, and meshes named Outfit_<outfit> for the body. Its clip
## table (<model>_clips.tres next to it) gives each gait's ground speed.
@export var model_scene: PackedScene
## Outfit mesh shown from the shared zombie model ("Tourist", "Lifeguard" or "Bruiser").
@export var outfit: StringName = &"Tourist"
@export var body_scale := 1.0
@export var capsule_radius := 0.45
## Keep the whole head (hats, costume eyes) inside the capsule: shots that
## miss the capsule miss the zombie.
@export var capsule_height := 1.9
## Fallback head cut for models without a Head bone: hits above this height
## (metres, before body_scale) count as headshots. Models with a Head bone use
## a hitbox that follows the head (sized from the head mesh).
@export var head_height := 1.25
## Scales the head hitbox built from the head mesh.
@export var head_hit_scale := 1.0
## Accessory that guards the head from the front while it is shown (the riot
## shield): frontal shots entering the head below its top edge are blocked.
@export var head_guard_mesh := ""
## Random shirt colours for variety (empty = keep the model's colour).
@export var shirt_colors: Array[Color] = []
@export var skin_colors: Array[Color] = []
## Each entry is one slot: options separated by "|", meshes combined with "+",
## an empty option means nothing. e.g. "Acc_Tourist_Cap|Acc_Tourist_Hair+Acc_Tourist_Shades|"
@export var accessory_slots: PackedStringArray = PackedStringArray()
@export var move_animation: StringName = &"Walk"
## Clip variant suffix tried first for every clip: "Heavy" plays
## Walk_Heavy, Attack_Heavy, Idle_Heavy... where the model has them.
@export var clip_style: StringName = &""
## Big enemies: heavy deaths (Die_Heavy) and heavy staggers.
@export var heavy := false
## Fallback for models without a clip table: the movement speed at which the
## move animation plays at 1x (the table's ground speed wins).
@export var animation_reference_speed := 1.8
@export var avoidance_radius := 0.55

@export_group("Behaviour")
## Extra behaviour components (EnemyBehaviour resources): ranged attacks,
## shields, leaps, splitting on death, auras... Each zombie gets its own copy.
@export var behaviours: Array[EnemyBehaviour] = []

@export_group("Audio")
@export var voice_sounds: Array[StringName] = []
@export var voice_interval := Vector2(3.0, 6.5)
@export var voice_pitch := 1.0
@export var attack_sound: StringName = &"zombie_swipe"

@export_group("World outfits")
## Looks for other worlds: in a level of a listed world this enemy wears that
## look (model, accessories, colours) instead of its own. The Tourist Shambler
## and the Lifeguard Runner dress for every world this way.
@export var world_outfits: Array[EnemyLook] = []

var _world_variants := {}


## This enemy as it looks in `world` (itself when no world outfit applies).
## Each variant is a copy made once and shared by every zombie of that world.
func for_world(world: StringName) -> EnemyData:
	if world == &"" or world_outfits.is_empty():
		return self
	if not _world_variants.has(world):
		var variant := self
		for look in world_outfits:
			if look and look.world == world:
				variant = duplicate() as EnemyData
				look.apply_to(variant)
				break
		_world_variants[world] = variant
	return _world_variants[world]
