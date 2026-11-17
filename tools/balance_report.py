#!/usr/bin/env python3
"""Weapon balance report from data: time-to-kill per weapon x enemy, sustained
DPS, ammo economy and effective range, read straight from data/weapons/*.tres
and data/enemies/**/*.tres.

    python3 tools/balance_report.py [--head=0.3] [--dist=8]

The model follows scripts/player/weapon_controller.gd: hip fire (no ADS),
`--head` of single-shot hits land on the head (the playtest bot aims at the
head 30% of the time), damage falloff at `--dist` metres, shotgun pellets
sampled in their cone against the target's capsule (Monte Carlo), burst,
charge, beam heat and frozen bonus included. Splash and chain hit one target
here; their crowd value is in the "crowd" column (damage one trigger pull
spreads over a pack of four; ricochets count like chain jumps). Fizz burn
(the Sparkler) adds its average burn over each pull's time. The Shutterbug's flash (its mode's
reach and far-end falloff, no headshots) hits every zombie of the pack; the Balloon Darter's
darts are simulated with their balloon pops (BalloonBunch fuse, balloons per zombie, pop
damage and splash, read from the scripts). The Teacup Twister's whirl adds its spin ticks
to the pop and gathers the pack into the cup (scripts/weapons/twister_vortex.gd); the Dunk
Tank's soak multiplies its own hits (scripts/weapons/soak.gd), the Road Rager's hubcap
(scripts/weapons/hubcap_shot.gd) hits its target on the way out and back, is paced by its
round trips (catches refill it, so it never reloads or runs dry) and slices through the
whole pack, a pile-up hitting harder; the Popcorn Popper climbs its heat stages
(scripts/weapons/modes/popcorn_popper_mode.gd) from warm each magazine and pulses the trigger
to stay hot, its warm puffs and hot butter bursts splashing the pack; the Lava Lampoon fires its warm-up groove's slower shots
first and its target burns in the lava puddle under it (the pack walks through it); the Markdown
Marker's tags (scripts/weapons/markdown_marker_tags.gd) mark the target down per tag, a full stack
pops for its own damage and splash and refunds tags (a longer magazine); the T-Minus Six
dumb-fires from the hip (its rockets pop with a small splash, scripts/weapons/t_minus_rocket.gd),
and its aimed swarm (one lock per LOCK_TIME, rockets seeking heads, less of the bonus on heavies)
is printed below the tables; the "amp" column is the
damage bonus a status lends every other weapon. Ground Control's full-charge ring
(scripts/weapons/ground_control_ring.gd) passes through the whole pack, weaker for each
zombie it has passed, and its mark (scripts/weapons/ground_control_mark.gd) adds its bonus
to every hit after the first. Armour behaviours (helmets, shields, ice
shells) are approximated as extra health. Numbers are for comparison
between weapons, not exact in-game times. The Jack Pot's boxes (scripts/weapons/jack_pot_box.gd)
punch the zombie that sets them off for the full damage and splash the rest; bosses and the
heaviest alphas take only BOSS_SCALE of it; its field of boxes is printed below the tables.
"""
import glob
import math
import os
import random
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

WEAPON_DEFAULTS = {
	"magazine_size": 12, "reserve_max": 96, "reload_time": 1.3, "fire_interval": 0.22,
	"damage": 34.0, "pellets": 1, "spread_degrees": 0.3, "falloff_start": 30.0,
	"falloff_end": 70.0, "falloff_min_scale": 0.6, "headshot_multiplier": 1.6, "max_range": 70.0,
	"charge_time": 0.0, "charge_min_fraction": 0.2, "charge_min_damage_scale": 0.2,
	"burst_count": 1, "burst_interval": 0.07, "beam": False, "projectile_speed": 0.0,
	"projectile_fuse": 2.0, "splash_radius": 0.0, "splash_edge_scale": 0.35,
	"direct_hit_bonus": 0.0, "pierce": 0, "pierce_falloff": 0.85, "chain_count": 0,
	"chain_falloff": 0.75, "status_effect": "", "status_amount": 0.0,
	"frozen_damage_scale": 1.0, "shatter_damage": 0.0, "regen_rate": 0.0, "regen_delay": 0.4,
	"ricochet_count": 0, "ricochet_falloff": 0.8, "status_duration": 1.5,
}
# Fizz (FizzBurn): stacks per target, and the share of the full burn a target
# carries on average while it is being sprayed (the stacks build up).
FIZZ_MAX_STACKS = 6
FIZZ_RAMP = 0.75
# Constants of the weapons whose behaviour lives in a script (WeaponData.mode_script).
SCRIPT_CONSTS = {"flash": "scripts/weapons/modes/shutterbug_mode.gd", "balloon": "scripts/weapons/balloon_bunch.gd",
	"marker": "scripts/weapons/markdown_marker_tags.gd"}


def gd_consts(rel_path):
	"""`const NAME := number` values of a GDScript file (mode tuning lives there)."""
	out = {}
	path = os.path.join(ROOT, rel_path)
	if not os.path.exists(path):
		return out
	for line in open(path, encoding="utf-8"):
		m = re.match(r'^const (\w+) := (-?[\d.]+)\s*$', line.strip())
		if m:
			out[m.group(1)] = float(m.group(2))
	return out


# Weapons whose mode adds damage their WeaponData does not show.
VORTEX = gd_consts("scripts/weapons/twister_vortex.gd")
SOAK = gd_consts("scripts/weapons/soak.gd")
HUBCAP = gd_consts("scripts/weapons/hubcap_shot.gd")
PING = gd_consts("scripts/weapons/ground_control_ring.gd")
MARK = gd_consts("scripts/weapons/ground_control_mark.gd")
TMINUS = gd_consts("scripts/weapons/modes/t_minus_six_mode.gd")
TMINUS.update(gd_consts("scripts/weapons/t_minus_rocket.gd"))
# Share of a painted swarm's rockets that land on the head they seek.
TMINUS_SEEK_HEAD = 0.85
STACK = gd_consts("scripts/weapons/damage_stack.gd")
MODE_OF = {"teacup_twister": "vortex", "dunk_tank": "soak"}
# The Lava Lampoon: its warm-up groove (mode) and the lava puddle its globs leave.
LAVA_MODE = gd_consts("scripts/weapons/modes/lava_lampoon_mode.gd")
LAVA_PUDDLE = gd_consts("scripts/weapons/lava_lampoon_puddle.gd")
# The Yo-Yo Loco: its yo-yo's flight, Sleeper and Walk the Dog (scripts/weapons/yoyo_loco_shot.gd).
YOYO = gd_consts("scripts/weapons/yoyo_loco_shot.gd")
# The Popcorn Popper: its heat stages (mode) and its kernels' splash puffs and butter bursts.
POPCORN_MODE = gd_consts("scripts/weapons/modes/popcorn_popper_mode.gd")
POPCORN = gd_consts("scripts/weapons/popcorn_kernels.gd")
# Share of the pop a gathered zombie takes (they spin near the cup's centre).
VORTEX_POP_SHARE = 0.8
JACKPOT = gd_consts("scripts/weapons/jack_pot_box.gd")
ENEMY_DEFAULTS = {"max_health": 100.0, "body_scale": 1.0, "capsule_radius": 0.45,
	"capsule_height": 1.9, "mass": 1.0, "move_speed": 2.0}
# Extra effective health from armour behaviours (helmet, riot shield, ice shell).
ARMOUR_FIELDS = ("helmet_health", "shield_health", "shell_health")
ENEMY_ORDER = ["lifeguard_runner", "tourist_shambler", "neon_punk", "deep_diver",
	"frost_frozen_tourist", "dune_hazmat_worker", "boardwalk_bruiser", "riot_bruiser", "frost_yeti",
	"alpha_bruiser"]
SHORT = {"lifeguard_runner": "runner", "tourist_shambler": "tourist", "neon_punk": "punk",
	"deep_diver": "diver", "frost_frozen_tourist": "iced", "dune_hazmat_worker": "hazmat",
	"boardwalk_bruiser": "bruiser", "riot_bruiser": "riot", "frost_yeti": "yeti",
	"alpha_bruiser": "Bruno"}


def parse(path):
	"""Top-level and sub-resource `key = value` pairs of a .tres (numbers, bools, names)."""
	out = {}
	for line in open(path, encoding="utf-8"):
		m = re.match(r'^(\w+) = (.+)$', line.strip())
		if not m:
			continue
		key, raw = m.groups()
		raw = raw.strip()
		if raw in ("true", "false"):
			out[key] = raw == "true"
		elif re.match(r'^-?[\d.]+$', raw):
			out[key] = float(raw)
		elif raw.startswith('&"') or raw.startswith('"'):
			out.setdefault(key, raw.strip('&"'))
	return out


def mode_script_path(path):
	"""res:// path of the weapon's mode_script, or ''."""
	text = open(path, encoding="utf-8").read()
	m = re.search(r'^mode_script = ExtResource\("(\w+)"\)', text, re.M)
	if not m:
		return ""
	r = re.search(r'path="([^"]+)" id="%s"' % m.group(1), text)
	return r.group(1) if r else ""


def weapons():
	out = {}
	for path in sorted(glob.glob(os.path.join(ROOT, "data/weapons/*.tres"))):
		w = dict(WEAPON_DEFAULTS)
		w.update(parse(path))
		w["mode_script_path"] = mode_script_path(path)
		out[w["id"]] = w
	return dict(sorted(out.items(), key=lambda kv: kv[1].get("sort_order", 0)))


def enemies():
	out = {}
	for path in glob.glob(os.path.join(ROOT, "data/enemies/**/*.tres"), recursive=True):
		e = dict(ENEMY_DEFAULTS)
		e.update(parse(path))
		e["armour"] = sum(e.get(f, 0.0) for f in ARMOUR_FIELDS)
		if "body_damage_scale" in e:
			e["armour"] += e["max_health"] * (1.0 / e["body_damage_scale"] - 1.0) * 0.5
		out[e["id"]] = e
	return out


def script_consts(key):
	"""`const NAME := number` lines of a mode's script."""
	out = {}
	for line in open(os.path.join(ROOT, SCRIPT_CONSTS[key]), encoding="utf-8"):
		m = re.match(r'^const (\w+) := (-?[\d.]+)$', line.strip())
		if m:
			out[m.group(1)] = float(m.group(2))
	return out


def mode_kind(w):
	"""'flash' (Shutterbug), 'balloon' (Balloon Darter), 'hubcap' (Road Rager) or ''."""
	mode = w.get("mode_script_path", "")
	if mode.endswith("hubcap_boomerang_mode.gd"):
		return "hubcap"
	if mode.endswith("ground_control_mode.gd"):
		return "ping"
	if mode.endswith("shutterbug_mode.gd"):
		return "flash"
	if mode.endswith("balloon_darter_mode.gd"):
		return "balloon"
	if mode.endswith("markdown_marker_mode.gd"):
		return "marker"
	if mode.endswith("t_minus_six_mode.gd"):
		return "tminus"
	if mode.endswith("yoyo_loco_mode.gd"):
		return "yoyo"
	if mode.endswith("jack_pot_mode.gd"):
		return "jackpot"
	return ""


def flash_scale(d):
	"""Share of a hip flash's damage at d metres (0 beyond its reach)."""
	c = script_consts("flash")
	reach, full = c["HIP_REACH"], c["FULL_RANGE"]
	if d > reach:
		return 0.0
	t = min(1.0, max(0.0, (d - full) / (reach - full)))
	return 1.0 + (c["FAR_SCALE"] - 1.0) * t


def balloon_sim(w, hp, d, head):
	"""Balloon Darter on one target: darts at the fire rate (reloads included),
	each tying a balloon until the bunch pops. Returns (seconds, darts) to deal hp."""
	c = script_consts("balloon")
	dart = w["damage"] * falloff(w, d) * (1.0 + head * (w["headshot_multiplier"] - 1.0))
	t, dealt, darts, mag = 0.0, 0.0, 0, int(w["magazine_size"])
	fuse_at, balloons = None, 0
	while t < 60.0:
		darts += 1
		mag -= 1
		dealt += dart
		if dealt >= hp:
			return t, darts
		if fuse_at is None:
			fuse_at = t + c["FUSE"]
		balloons = min(int(c["MAX_BALLOONS"]), balloons + 1)
		t_next = t + (w["fire_interval"] if mag > 0 else w["reload_time"])
		if mag <= 0:
			mag = int(w["magazine_size"])
		if fuse_at <= t_next:
			dealt += c["POP_DAMAGE"] * balloons
			if dealt >= hp:
				return fuse_at, darts
			fuse_at, balloons = None, 0
		t = t_next
	return math.inf, darts


def marker_sim(w, hp, d, head, heavy=False):
	"""Markdown Marker on one target: tags stack the mark-down, the dart that hits a
	full stack pops it (its own damage, the tags back in the magazine) and the
	stack starts again. Returns (seconds, darts) to deal hp."""
	c = script_consts("marker")
	dart = w["damage"] * falloff(w, d) * (1.0 + head * (w["headshot_multiplier"] - 1.0))
	t, dealt, darts, mag, tags = 0.0, 0.0, 0, int(w["magazine_size"]), 0
	while t < 60.0:
		darts += 1
		mag -= 1
		dealt += dart * (1.0 + c["TAG_BONUS"] * tags)
		if tags >= c["MAX_TAGS"]:
			dealt += c["POP_DAMAGE"] * (c["HEAVY_POP_SCALE"] if heavy else 1.0)
			tags = 0
			mag = min(int(w["magazine_size"]), mag + int(c["POP_REFUND"]))
		else:
			tags += 1
		if dealt >= hp:
			return t, darts
		t += w["fire_interval"] if mag > 0 else w["reload_time"]
		if mag <= 0:
			mag = int(w["magazine_size"])
	return math.inf, darts


def marker_cycle():
	"""Darts in one stack-and-pop cycle, and the darts it costs (the pop refunds some)."""
	c = script_consts("marker")
	n = int(c["MAX_TAGS"]) + 1
	return n, n - int(c["POP_REFUND"])


def hubcap_cycle(w):
	"""Seconds between throws when every hubcap is caught: the round trip
	(out to max_range, the hang, home) shared by the magazine, or the fire rate."""
	out = w["max_range"] / (w["projectile_speed"] * (1.0 - HUBCAP["OUT_SLOWDOWN"] / 3.0))
	back = w["max_range"] / (w["projectile_speed"] * (HUBCAP["BACK_START"] + HUBCAP["BACK_TOP"]) * 0.5)
	return max(w["fire_interval"], (out + HUBCAP["HANG_TIME"] + back) / w["magazine_size"])


def falloff(w, d):
	if d <= w["falloff_start"]:
		return 1.0
	t = min(1.0, (d - w["falloff_start"]) / max(0.01, w["falloff_end"] - w["falloff_start"]))
	return 1.0 + (w["falloff_min_scale"] - 1.0) * t


def pellet_fraction(w, e, d, samples=4000):
	"""Share of pellets landing on the capsule (a 2r x h rectangle seen from d metres)."""
	if w["pellets"] <= 1:
		return 1.0
	rnd = random.Random(7)
	half_w = e["capsule_radius"] * e["body_scale"]
	h = e["capsule_height"] * e["body_scale"]
	aim_y = 1.0 * e["body_scale"]
	tan_s = math.tan(math.radians(w["spread_degrees"]))
	hit = 0
	for _ in range(samples):
		a = rnd.random() * math.tau
		r = tan_s * math.sqrt(rnd.random()) * d
		x, y = r * math.cos(a), aim_y + r * math.sin(a)
		hit += abs(x) <= half_w and 0.0 <= y <= h
	return hit / samples


def pull_damage(w, e, d, head):
	"""Average damage of one trigger pull to one target, and the pull's duration."""
	scale = falloff(w, d)
	head_mix = 1.0 + head * (w["headshot_multiplier"] - 1.0)
	if mode_kind(w) == "flash":
		return w["damage"] * flash_scale(d), w["fire_interval"]
	if mode_kind(w) == "hubcap":
		# Aimed down the sights it strikes the target on the way out and back.
		return 2.0 * w["damage"] * head_mix, hubcap_cycle(w)
	if mode_kind(w) == "ping":
		# A full-charge ring (no headshots); the mark it leaves makes the next ones hit harder.
		return w["damage"] * MARK.get("DAMAGE_BONUS", 1.0), w["fire_interval"] + w["charge_time"]
	if mode_kind(w) == "balloon":
		# Per dart, its share of a bunch: MAX_BALLOONS of the darts fired in one fuse pop.
		c = script_consts("balloon")
		per_fuse = math.floor(c["FUSE"] / w["fire_interval"]) + 1
		share = min(1.0, c["MAX_BALLOONS"] / per_fuse)
		return w["damage"] * falloff(w, d) * head_mix + c["POP_DAMAGE"] * share, w["fire_interval"]
	if mode_kind(w) == "marker":
		# Per dart, its share of a stack-and-pop cycle: the mark-down on it and the pop.
		c = script_consts("marker")
		n, _ = marker_cycle()
		marked = sum(1.0 + c["TAG_BONUS"] * i for i in range(n)) / n
		return w["damage"] * falloff(w, d) * head_mix * marked + c["POP_DAMAGE"] / n, w["fire_interval"]
	if mode_kind(w) == "yoyo":
		# A tap: one hit (headshots count), paced by the yo-yo's round trip to the target.
		if d > w["max_range"]:
			return 0.0, w["fire_interval"]
		return w["damage"] * head_mix, max(w["fire_interval"], yoyo_trip(d))
	if mode_kind(w) == "jackpot":
		# The punch on the zombie that sets the box off; bosses are only nudged.
		boss = e.get("mass", 1.0) >= JACKPOT["BOSS_MASS"]
		return w["damage"] * (JACKPOT["BOSS_SCALE"] if boss else 1.0), w["fire_interval"]
	if w["ricochet_count"] > 0:
		# A thrown ring (RingShot) flies straight at its first target and can headshot.
		return w["damage"] * head_mix, w["fire_interval"]
	if MODE_OF.get(w["id"]) == "vortex":
		return w["damage"] + vortex_spin(), w["fire_interval"]
	if w["id"] == "lava_lampoon":
		# A glob hits like a ray shot; the target burns in the puddle under it meanwhile.
		cycle = lava_cycle(w)
		return w["damage"] * scale * head_mix + LAVA_PUDDLE["BURN_DPS"] * cycle, cycle
	if w["id"] == "popcorn_popper":
		# Kernels hit like ray shots; a magazine climbs from warm, then pulses hot.
		return w["damage"] * scale * head_mix, popcorn_cycle(w)[0]
	if w["projectile_speed"] > 0.0:
		dmg = w["damage"] + w["direct_hit_bonus"]
		return dmg, w["fire_interval"]
	if w["charge_time"] > 0.0:
		# Full charge, as a player would against anything slower than a runner.
		return w["damage"] * scale * head_mix, w["fire_interval"] + w["charge_time"]
	dmg = w["damage"] * w["pellets"] * pellet_fraction(w, e, d) * scale * head_mix * (1.0 + amp(w))
	cycle = w["fire_interval"] + (w["burst_count"] - 1) * w["burst_interval"]
	return dmg * w["burst_count"] + fizz_per_pull(w, cycle), cycle


def lava_cycle(w):
	"""Average seconds per shot over a magazine: the warm-up groove's slow shots, then the data rate."""
	warm = math.ceil(LAVA_MODE["GROOVE_TIME"] / LAVA_MODE["WARM_INTERVAL"])
	mag = w["magazine_size"]
	return (LAVA_MODE["GROOVE_TIME"] + (mag - warm) * w["fire_interval"]) / mag


def popcorn_cycle(w):
	"""Popcorn Popper over one magazine (the kettle keeps warm through reloads), pulsed to stay under the jam:
	(average seconds per shot, share of warm shots, share of hot shots)."""
	m = POPCORN_MODE
	per = m["HEAT_PER_SHOT"]
	warm = (m["HOT_AT"] - m["WARM_AT"]) / per
	hot = max(0.0, w["magazine_size"] - warm)
	rest = per / m["COOL_RATE"]
	time = warm * m["WARM_INTERVAL"] + hot * (w["fire_interval"] + rest)
	return time / w["magazine_size"], warm / w["magazine_size"], hot / w["magazine_size"]


def vortex_spin():
	"""Spin damage a zombie in the cup takes over one whirl (ticks until it pops)."""
	if not VORTEX:
		return 0.0
	return math.floor(VORTEX["WHIRL_TIME"] / VORTEX["WHIRL_TICK"]) * VORTEX["WHIRL_TICK_DAMAGE"]


def amp(w):
	"""Damage bonus the weapon's status lends every hit on the target (soak; a full stack of tags)."""
	if mode_kind(w) == "ping":
		return MARK.get("DAMAGE_BONUS", 1.0) - 1.0
	if mode_kind(w) == "marker":
		c = script_consts("marker")
		return c["TAG_BONUS"] * c["MAX_TAGS"]
	return SOAK.get("DAMAGE_BONUS", 1.0) - 1.0 if MODE_OF.get(w["id"]) == "soak" else 0.0


def fizz_per_pull(w, cycle):
	"""Burn damage a fizzing target takes over one pull's time while sprayed."""
	if w["status_effect"] != "fizz":
		return 0.0
	return w["status_amount"] * FIZZ_MAX_STACKS * FIZZ_RAMP * cycle


def ttk(w, e, d, head):
	"""Seconds from the first shot to the kill, reloads included (starting on a full mag)."""
	hp = e["max_health"] + e["armour"]
	if mode_kind(w) == "balloon":
		return balloon_sim(w, hp, d, head)
	if mode_kind(w) == "marker":
		return marker_sim(w, hp, d, head, bool(e.get("heavy", False)))
	dmg, cycle = pull_damage(w, e, d, head)
	if dmg <= 0.0:
		return math.inf, math.inf
	if w["beam"] and w["status_effect"] == "chill":
		ticks_to_freeze = math.ceil(math.sqrt(max(0.5, e["mass"])) / max(0.01, w["status_amount"]))
		frozen_hp = hp - dmg * ticks_to_freeze
		pulls = ticks_to_freeze + max(0, math.ceil(frozen_hp / (dmg * w["frozen_damage_scale"])))
	else:
		pulls = math.ceil(hp / dmg)
	shots_per_pull = w["burst_count"]
	mag_pulls = max(1, int(w["magazine_size"] // shots_per_pull))
	reloads = (pulls - 1) // mag_pulls
	reload = w["reload_time"]
	if w["regen_rate"] > 0.0:
		reload = w["magazine_size"] / w["regen_rate"] if reloads else 0.0
	if mode_kind(w) == "hubcap":
		reload = 0.0
	first_shot = w["charge_time"] if w["charge_time"] > 0 else 0.0
	if MODE_OF.get(w["id"]) == "vortex":
		# The whirl deals its damage over WHIRL_TIME, after the shell's flight (~0.5 s at 8 m).
		first_shot += VORTEX.get("WHIRL_TIME", 0.0) + 0.5
	return first_shot + (pulls - 1) * cycle + reloads * reload, pulls


def sustained_dps(w, head, d=8.0, e=None):
	e = e or {"capsule_radius": 0.5, "body_scale": 1.0, "capsule_height": 1.9, "mass": 1.0}
	dmg, cycle = pull_damage(w, e, d, head)
	if mode_kind(w) == "hubcap":
		return dmg / cycle
	pulls = max(1, int(w["magazine_size"] // w["burst_count"]))
	if mode_kind(w) == "marker":
		n, cost = marker_cycle()
		pulls = int(pulls * n / cost)
	reload = w["reload_time"]
	if w["regen_rate"] > 0.0:
		# Heat: fire a full bar, cool it back from empty (vent) each cycle.
		reload = w["reload_time"] + 0.0
	if w["beam"] and w["status_effect"] == "chill":
		dmg *= w["frozen_damage_scale"] * 0.85  # most ticks land on a frozen target
	return dmg * pulls / (pulls * cycle + reload)


def crowd_damage(w, d=8.0):
	"""Damage one trigger pull spreads over a pack of four standing close together."""
	e = {"capsule_radius": 0.5, "body_scale": 1.0, "capsule_height": 1.9}
	dmg, _ = pull_damage(w, e, d, 0.0)
	if mode_kind(w) == "flash":
		# All four in the cone, between its centre line and its rim.
		rim = script_consts("flash")["RIM_SCALE"]
		return 4 * dmg * (1.0 + rim) / 2
	if mode_kind(w) == "hubcap":
		# From the hip: through all four on the way out, two on the loop home,
		# the strikes after the pile-up harder.
		strikes = 6
		pile = int(HUBCAP["PILEUP"])
		return w["damage"] * (min(strikes, pile) + max(0, strikes - pile) * HUBCAP["PILEUP_BONUS"])
	if mode_kind(w) == "marker":
		# The popping dart into one of the pack: the pop splashes the other three (half
		# way to the rim) and tags each.
		c = script_consts("marker")
		dart = w["damage"] * (1.0 + c["TAG_BONUS"] * c["MAX_TAGS"])
		return dart + c["POP_DAMAGE"] * (1.0 + 3 * (1.0 + c["POP_EDGE"]) / 2)
	if mode_kind(w) == "tminus":
		# A dumb rocket into one of the pack: its pop splashes the other three.
		return dmg + 3 * TMINUS["SPLASH_DAMAGE"]
	if mode_kind(w) == "balloon":
		# One dart into one of the pack: its balloon pops and splashes the other three.
		c = script_consts("balloon")
		return w["damage"] + c["POP_DAMAGE"] * (1.0 + 3 * c["SPLASH_SCALE"])
	if w["chain_count"] > 0:
		jumps = sum(w["chain_falloff"] ** (k + 1) for k in range(int(min(3, w["chain_count"]))))
		return dmg + w["damage"] * jumps
	if w["ricochet_count"] > 0:
		hops = sum(w["ricochet_falloff"] ** (k + 1) for k in range(int(min(3, w["ricochet_count"]))))
		return dmg + w["damage"] * hops
	if mode_kind(w) == "ping":
		# Through all four, weaker for each one passed (no bounce counted).
		return w["damage"] * MARK.get("DAMAGE_BONUS", 1.0) * sum(max(PING["MIN_SHARE"], PING["ATTENUATION"] ** k) for k in range(4))
	if MODE_OF.get(w["id"]) == "vortex":
		return dmg + 3 * (vortex_spin() + w["damage"] * VORTEX_POP_SHARE)
	if w["id"] == "lava_lampoon":
		# The pack walks through the puddle (about a second each at shambling pace).
		return dmg + 3 * LAVA_PUDDLE["BURN_DPS"] * 2 * LAVA_PUDDLE["RADIUS"] / 2.0
	if w["id"] == "popcorn_popper":
		# The other three take the warm shots' puffs and the hot shots' bursts (half way to the rim).
		_, warm, hot = popcorn_cycle(w)
		edge = (1 + POPCORN["SPLASH_EDGE"]) / 2
		return dmg + 3 * edge * (warm * POPCORN["PUFF_DAMAGE"] + hot * POPCORN["BURST_DAMAGE"])
	if w["splash_radius"] > 0.0:
		return dmg + 3 * w["damage"] * (1 + w["splash_edge_scale"]) / 2
	if w["pierce"] > 0:
		return dmg * sum(w["pierce_falloff"] ** k for k in range(int(min(3, w["pierce"])) + 1))
	return dmg


def ammo_damage(w, head):
	"""Damage a full stock (magazine + max reserve) can deal to single targets."""
	if mode_kind(w) == "hubcap":
		return math.inf
	dmg, _ = pull_damage(w, {"capsule_radius": 0.5, "body_scale": 1.0, "capsule_height": 1.9}, 8.0, head)
	stock = (w["magazine_size"] + w["reserve_max"]) / w["burst_count"]
	if mode_kind(w) == "marker":
		n, cost = marker_cycle()
		stock *= n / cost
	return dmg * stock


def yoyo_trip(d):
	"""Seconds for a Yo-Yo Loco tap at a target d metres away: out, and home (YoyoLocoShot.round_trip)."""
	out = d / YOYO["OUT_SPEED"]
	accel = (YOYO["BACK_START"] + YOYO["BACK_TOP"]) * 0.5 * YOYO["BACK_ACCEL"]
	if d > accel:
		return out + YOYO["BACK_ACCEL"] + (d - accel) / YOYO["BACK_TOP"]
	a = (YOYO["BACK_TOP"] - YOYO["BACK_START"]) / YOYO["BACK_ACCEL"]
	return out + (math.sqrt(YOYO["BACK_START"] ** 2 + 2.0 * a * d) - YOYO["BACK_START"]) / a


def yoyo_sleeper(w, seconds):
	"""Yo-Yo Loco Sleeper on one zombie for `seconds` after the hit: (damage of
	the hit and the grind, rounds of string wear)."""
	dealt, t, tick = w["damage"], 0.0, YOYO["SLEEP_TICK"]
	while t + tick <= seconds + 1e-6:
		t += tick
		k = min(1.0, t / YOYO["SLEEP_RAMP"]) ** (1.0 / 0.7)
		dealt += (YOYO["SLEEP_DPS_START"] + (YOYO["SLEEP_DPS_TOP"] - YOYO["SLEEP_DPS_START"]) * k) * tick
	return dealt, 1 + int(seconds / YOYO["SLEEP_ROUND_TIME"])


def tminus_swarm(w, heavy=False):
	"""T-Minus Six aimed: (single-target DPS of full paints, damage of one full
	swarm spread over a pack of four standing close, seconds per volley)."""
	n = int(min(TMINUS["MAX_LOCKS"], w["magazine_size"]))
	bonus = (w["headshot_multiplier"] - 1.0) * (TMINUS["HEAVY_HEAD_SHARE"] if heavy else 1.0)
	rocket = w["damage"] * (1.0 + TMINUS_SEEK_HEAD * bonus)
	volley = n * TMINUS["LOCK_TIME"] + n * TMINUS["RIPPLE"] + 0.35
	single = rocket * n / (volley + w["reload_time"])
	# Each pop splashes about one and a half of the pack's other zombies.
	crowd = n * (rocket + 1.5 * TMINUS["SPLASH_DAMAGE"])
	return single, crowd, volley


def main():
	head = 0.3
	dist = 8.0
	for arg in sys.argv[1:]:
		if arg.startswith("--head="):
			head = float(arg.split("=")[1])
		elif arg.startswith("--dist="):
			dist = float(arg.split("=")[1])
	ws = weapons()
	es = enemies()
	order = [i for i in ENEMY_ORDER if i in es]
	print(f"TTK in seconds at {dist:g} m, {int(head * 100)}% headshots, hip fire (pulls in brackets)\n")
	print("| Weapon | " + " | ".join(SHORT[i] for i in order) + " |")
	print("|---" * (len(order) + 1) + "|")
	for w in ws.values():
		cells = []
		for i in order:
			t, n = ttk(w, es[i], dist, head)
			cells.append(f"{t:.2f} ({n})")
		print(f"| {w['display_name']} | " + " | ".join(cells) + " |")
	print("\n| Weapon | Slot | DPS @8m | DPS @20m | crowd/pull | stock dmg | eff. range | tourist@20m | amp |")
	print("|---|---|---|---|---|---|---|---|---|")
	for w in ws.values():
		eff = min(w["max_range"], w["falloff_start"] + (w["falloff_end"] - w["falloff_start"]) * 0.35)
		if w["projectile_speed"] > 0:
			eff = min(w["max_range"], w["projectile_speed"] * w["projectile_fuse"] * 0.6)
		t20, _ = ttk(w, es["tourist_shambler"], 20.0, head)
		print(f"| {w['display_name']} | {w.get('slot_class', 'primary')} | {sustained_dps(w, head):.0f} | {sustained_dps(w, head, 20.0):.0f} | "
			f"{crowd_damage(w):.0f} | {ammo_damage(w, head):.0f} | {eff:.0f} m | {t20:.2f} | {amp(w) * 100:+.0f}% |")
	for w in ws.values():
		if mode_kind(w) == "tminus":
			single, crowd, volley = tminus_swarm(w)
			boss, _, _ = tminus_swarm(w, heavy=True)
			n = int(min(TMINUS["MAX_LOCKS"], w["magazine_size"]))
			print(f"\n{w['display_name']} aimed: a full paint of {n} in {volley:.2f} s, {int(TMINUS_SEEK_HEAD * 100)}% of the rockets "
				f"on the head: {single:.0f} DPS on one light zombie, {boss:.0f} on a heavy or boss; one swarm over a pack of four {crowd:.0f}")
	for w in ws.values():
		if mode_kind(w) == "yoyo":
			full, rounds = yoyo_sleeper(w, YOYO["SLEEP_MAX"])
			short, short_rounds = yoyo_sleeper(w, 1.0)
			heavy = es["boardwalk_bruiser"]["max_health"]
			t = 0.0
			while yoyo_sleeper(w, t)[0] < heavy and t < YOYO["SLEEP_MAX"]:
				t += YOYO["SLEEP_TICK"]
			dog_cycle = 2.0 * (w["max_range"] - YOYO["DOG_DROP"]) / YOYO["DOG_SPEED"] + 0.3
			print(f"\n{w['display_name']} Sleeper (hold through a hit): {short:.0f} in the first second ({short_rounds} rounds), "
				f"{full:.0f} over a full {YOYO['SLEEP_MAX']:g} s ({rounds} rounds, top {YOYO['SLEEP_DPS_TOP']:.0f} DPS); "
				f"a Bruiser ({heavy:.0f}) drops {t + yoyo_trip(dist):.2f} s after the throw. Walk the Dog: "
				f"{w['damage'] * YOYO['DOG_SCALE']:.0f} and a trip to every zombie it rolls past, one walk {dog_cycle:.2f} s")
		if mode_kind(w) == "jackpot":
			edge = w["damage"] * (1 + w["splash_edge_scale"]) / 2
			field = int(JACKPOT["MAX_BOXES"]) * (w["damage"] + 3 * edge)
			print(f"\n{w['display_name']} field: {int(JACKPOT['MAX_BOXES'])} boxes armed {JACKPOT['ARM_TIME']:g} s after landing, "
				f"each {w['damage']:.0f} to the zombie that sets it off and {edge:.0f} on average to the rest within {w['splash_radius']:g} m; "
				f"a pack of four walking into the field takes {field:.0f}; a boss {w['damage'] * JACKPOT['BOSS_SCALE']:.0f} a box")
	tags = gd_consts("scripts/weapons/markdown_marker_tags.gd")
	own = {"Marker tags": tags["TAG_BONUS"] * tags["MAX_TAGS"], "Ground Control mark": MARK["DAMAGE_BONUS"] - 1.0,
		"Dunk Tank soak": SOAK["DAMAGE_BONUS"] - 1.0}
	raw = sum(own.values())
	print("\nMark-down stack (they add up, capped; the cap is lower on heavies and bosses): "
		+ ", ".join(f"{k} +{v * 100:.0f}%" for k, v in own.items())
		+ f"; all three +{raw * 100:.0f}% -> +{min(raw, STACK['CAP']) * 100:.0f}% on a zombie,"
		f" +{min(raw, STACK['HEAVY_CAP']) * 100:.0f}% on a heavy or boss")


if __name__ == "__main__":
	main()
