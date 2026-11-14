class_name ReloadKeys
extends RefCounted
## Keyframe helpers for reload scripts (WeaponView.track).
##
## A track's transforms interpolate the short way round, so a part turned by
## a full turn or more in one key does not move at all. spin() breaks a turn
## into steps of a quarter turn or less, timed so the whole turn speeds up,
## slows down or keeps a steady pace. Play the keys with Tween.TRANS_LINEAR.


## Keys turning a part by `degrees` about `axis` (its own X, Y or Z: a unit
## vector) from t0 to t1, sliding from offset `from` to `to` on the way. The
## first key holds the start pose (so the track can follow an earlier one).
## `pace`: 0 steady, 1 slows to a stop (a hand-flicked wheel), -1 speeds up.
static func spin(t0: float, t1: float, axis: Vector3, degrees: float, from := Vector3.ZERO, to := Vector3.ZERO, pace := 0.0) -> Array:
	var steps := maxi(2, ceili(absf(degrees) / 90.0))
	var keys: Array = [[t0, from, Vector3.ZERO, 1.0, "hold"]]
	for i in range(1, steps + 1):
		var k := float(i) / steps
		# Time at which the turn has covered k of its angle.
		var t := k
		if pace > 0.0:
			t = lerpf(k, 1.0 - sqrt(1.0 - k), pace)
		elif pace < 0.0:
			t = lerpf(k, sqrt(k), -pace)
		var angle := fmod(degrees * k, 360.0)
		keys.append([lerpf(t0, t1, t), from.lerp(to, k), axis * angle])
	return keys
