extends RefCounted
## Bullseye Longbow "nock": the bow cants in a little while the drawing hand
## drops to the hip quiver, plucks an arrow out with a rustle, swings it up
## point first over the riser, lays it on the shelf and slides it back until
## the nock clicks onto the string, then the fingers hook the string again
## and the bow settles. The hand and the arrow are posed from the reload's
## progress by scripts/weapons/views/bullseye_bow_view.gd (NOCK_KEYS); this
## plays the bow's own tilt, the sounds and the glints on that timeline.

## The bow's tilt while nocking (model offset, degrees).
const ROOT_POS := Vector3(-0.01, 0.01, 0.0)
const ROOT_ROT := Vector3(4.0, -6.0, 10.0)
const NOCK_SPARK := [Color(1.0, 0.25, 0.62), Color(1.0, 0.86, 0.36), Color(1.0, 0.98, 0.9)]


func play(v: WeaponView, d: float) -> void:
	v.track("Root", d, [[0.2, ROOT_POS, ROOT_ROT], [0.72, ROOT_POS, ROOT_ROT], [0.9, Vector3.ZERO, Vector3(0.0, 0.0, -1.0)],
		[1.0, Vector3.ZERO, Vector3.ZERO]])
	v.at(0.26, d, func() -> void: Sfx.play(&"bb_quiver", -6.0, randf_range(0.95, 1.05)))
	v.at(0.66, d, func() -> void: Sfx.play(&"bb_rest", -9.0))
	v.at(BullseyeBowView.NOCKED - 0.02, d, func() -> void: Sfx.play(&"bb_nock", -4.0))
	v.at(BullseyeBowView.NOCKED, d, func() -> void:
		var nock := v.model.find_child("Nock", true, false) as Node3D
		if nock:
			v.spark_burst(nock.position, Vector3(0, 1, 0), NOCK_SPARK, 8, 1.2, 0.22, 0.006))
	v.glow_ramp(0.0, 0.3, d, 1.0, 0.4)
	v.glow_ramp(BullseyeBowView.NOCKED, 1.0, d, 2.2, 1.0)
