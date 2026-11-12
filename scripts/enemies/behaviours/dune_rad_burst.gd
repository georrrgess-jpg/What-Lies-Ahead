class_name DuneRadBurstBehaviour
extends EnemyBehaviour
## Irradiated hazmat worker: when it goes down, its suit swells and ticks for
## `fuse` seconds (a glowing ring marks the danger zone), then bursts into a
## radioactive cloud that hurts while the player stands in it. Step out of the
## ring during the fuse and nothing happens.

@export var fuse := 1.1
@export var radius := 3.0
@export var burst_damage := 8.0
@export var cloud_seconds := 3.5
@export var damage_per_second := 5.0


func on_death(z: Zombie) -> void:
	var cloud := DuneRadCloud.new()
	cloud.fuse = fuse
	cloud.radius = radius
	cloud.burst_damage = burst_damage
	cloud.cloud_seconds = cloud_seconds
	cloud.damage_per_second = damage_per_second
	z.get_parent().add_child(cloud)
	cloud.global_position = z.global_position
