class_name SkyBalloonLobBehaviour
extends LavaCoconutLobBehaviour
## Balloon Vendor: the Tiki Bartender's telegraphed lob (plant the feet, rear
## back with the throw held overhead, a call, the threat ring; a headshot
## during the windup spills it), throwing a water balloon in one of the
## vendor's colours. When the vendor pops, a few of its balloons slip free and
## float away.

## The balloon colours (one picked per throw).
@export var balloon_colors: Array[Color] = [Color(0.91, 0.22, 0.31), Color(1.0, 0.81, 0.35), Color(0.12, 0.71, 0.69),
	Color(1.0, 0.56, 0.71), Color(0.56, 0.82, 1.0)]
## Balloons released when the vendor pops.
@export var escape_count := 3

static var _balloon_meshes: Array[SphereMesh] = []


func on_ready(z: Zombie) -> void:
	super.on_ready(z)
	if _balloon_meshes.is_empty():
		for c in balloon_colors:
			var mesh := SphereMesh.new()
			mesh.radius = 1.0
			mesh.height = 2.3
			mesh.radial_segments = 10
			mesh.rings = 6
			var m := StandardMaterial3D.new()
			m.albedo_color = c
			m.roughness = 0.3
			mesh.material = m
			_balloon_meshes.append(mesh)


func _begin(z: Zombie) -> void:
	var k := randi() % _balloon_meshes.size()
	_held_mesh = _balloon_meshes[k]
	color = balloon_colors[k % balloon_colors.size()]
	super._begin(z)


func on_death(z: Zombie) -> void:
	super.on_death(z)
	var parent := z.get_parent() as Node3D
	if parent == null:
		return
	var top := z.global_position + Vector3.UP * 2.6 * z.data.body_scale
	for i in escape_count:
		var b := MeshInstance3D.new()
		b.mesh = _balloon_meshes[(i + randi()) % _balloon_meshes.size()]
		b.scale = Vector3.ONE * 0.2
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(b)
		b.global_position = top + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.3), randf_range(-0.4, 0.4))
		var drift := Vector3(randf_range(-1.5, 1.5), randf_range(5.0, 7.0), randf_range(-1.5, 1.5))
		var tw := b.create_tween()
		tw.tween_property(b, "global_position", b.global_position + drift, 3.0).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(b, "scale", Vector3.ONE * 0.06, 3.0).set_ease(Tween.EASE_IN)
		tw.tween_callback(b.queue_free)
