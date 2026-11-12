extends SceneTree
## Developer probe for Tidal Tunnels: loads the level (without starting a run),
## prints whether each spawn room, the tunnel and the portal deck can be
## reached on the navmesh from the player start, and ray-tests the floor beside
## the rotunda openings for gaps, so connectivity problems (ramps, doors, spawn
## rooms, slab seams) show up without a full playthrough.
##
##   godot --headless --path . --script res://tools/aqua_probe.gd

const POINTS := {
	"spawn": Vector3(0, 0.1, 18),
	"portal": Vector3(0, 3.2, 23.6),
	"filtration": Vector3(-17, 0.1, -28),
	"elevator": Vector3(17, 0.1, -26.6),
	"loading": Vector3(24.8, 0.1, 7.2),
	"staff": Vector3(-25.2, 0.1, 11.5),
	"stockroom": Vector3(0, 0.1, 23.0),
	"tunnel": Vector3(0, 0.1, -19.5),
	"ring_n": Vector3(0, 0.1, -10.5),
}


func _initialize() -> void:
	var level: Node3D = (load("res://scenes/levels/tidal_tunnels.tscn") as PackedScene).instantiate()
	var director := level.get_node_or_null("RunDirector")
	if director:
		level.remove_child(director)
		director.free()
	level.set_script(null)
	root.add_child(level)
	for i in 30:
		await physics_frame
	var region := level.get_node("NavigationRegion3D") as NavigationRegion3D
	var map := region.get_navigation_map()
	print("regions=%d polygons=%d" % [NavigationServer3D.map_get_regions(map).size(), region.navigation_mesh.get_polygon_count()])
	for key in POINTS:
		if key == "spawn":
			continue
		var from: Vector3 = POINTS["spawn"]
		var to: Vector3 = POINTS[key]
		var path := NavigationServer3D.map_get_path(map, from, to, true)
		var end := path[path.size() - 1] if path.size() > 0 else Vector3.INF
		var closest := NavigationServer3D.map_get_closest_point(map, to)
		print("%-11s reached=%s end=%s closest=%s points=%d" % [key, end.distance_to(to) < 1.0, end.snapped(Vector3.ONE * 0.1),
			closest.snapped(Vector3.ONE * 0.1), path.size()])
	# Floor check: a downward ray at points around the rotunda openings.
	var space := root.get_world_3d().direct_space_state
	for x in [12.9, 13.3, 13.7, 14.1]:
		for z in [-3.5, -4.0, -4.5, -5.0, -5.5]:
			var from := Vector3(x, 3.0, z)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 10.0, 1))
			var what := "none"
			if not hit.is_empty():
				what = "%s y=%.2f" % [hit["collider"].name, hit["position"].y]
			print("floor (%.1f, %.1f): %s" % [x, z, what])
	quit()
