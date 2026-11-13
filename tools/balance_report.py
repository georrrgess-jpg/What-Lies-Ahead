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
spreads over a pack of four). Armour behaviours (helmets, shields, ice
shells) are approximated as extra health. Numbers are for comparison
between weapons, not exact in-game times.
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
}
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


def weapons():
	out = {}
	for path in sorted(glob.glob(os.path.join(ROOT, "data/weapons/*.tres"))):
		w = dict(WEAPON_DEFAULTS)
		w.update(parse(path))
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
	if w["projectile_speed"] > 0.0:
		dmg = w["damage"] + w["direct_hit_bonus"]
		return dmg, w["fire_interval"]
	if w["charge_time"] > 0.0:
		# Full charge, as a player would against anything slower than a runner.
		return w["damage"] * scale * head_mix, w["fire_interval"] + w["charge_time"]
	dmg = w["damage"] * w["pellets"] * pellet_fraction(w, e, d) * scale * head_mix
	return dmg * w["burst_count"], w["fire_interval"] + (w["burst_count"] - 1) * w["burst_interval"]


def ttk(w, e, d, head):
	"""Seconds from the first shot to the kill, reloads included (starting on a full mag)."""
	hp = e["max_health"] + e["armour"]
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
	first_shot = w["charge_time"] if w["charge_time"] > 0 else 0.0
	return first_shot + (pulls - 1) * cycle + reloads * reload, pulls


def sustained_dps(w, head, d=8.0, e=None):
	e = e or {"capsule_radius": 0.5, "body_scale": 1.0, "capsule_height": 1.9, "mass": 1.0}
	dmg, cycle = pull_damage(w, e, d, head)
	pulls = max(1, int(w["magazine_size"] // w["burst_count"]))
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
	if w["chain_count"] > 0:
		jumps = sum(w["chain_falloff"] ** (k + 1) for k in range(int(min(3, w["chain_count"]))))
		return dmg + w["damage"] * jumps
	if w["splash_radius"] > 0.0:
		return dmg + 3 * w["damage"] * (1 + w["splash_edge_scale"]) / 2
	if w["pierce"] > 0:
		return dmg * sum(w["pierce_falloff"] ** k for k in range(int(min(3, w["pierce"])) + 1))
	return dmg


def ammo_damage(w, head):
	"""Damage a full stock (magazine + max reserve) can deal to single targets."""
	dmg, _ = pull_damage(w, {"capsule_radius": 0.5, "body_scale": 1.0, "capsule_height": 1.9}, 8.0, head)
	return dmg * (w["magazine_size"] + w["reserve_max"]) / w["burst_count"]


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
	print("\n| Weapon | DPS @8m | DPS @20m | crowd/pull | stock dmg | eff. range | tourist@20m |")
	print("|---|---|---|---|---|---|---|")
	for w in ws.values():
		eff = min(w["max_range"], w["falloff_start"] + (w["falloff_end"] - w["falloff_start"]) * 0.35)
		if w["projectile_speed"] > 0:
			eff = min(w["max_range"], w["projectile_speed"] * w["projectile_fuse"] * 0.6)
		t20, _ = ttk(w, es["tourist_shambler"], 20.0, head)
		print(f"| {w['display_name']} | {sustained_dps(w, head):.0f} | {sustained_dps(w, head, 20.0):.0f} | "
			f"{crowd_damage(w):.0f} | {ammo_damage(w, head):.0f} | {eff:.0f} m | {t20:.2f} |")


if __name__ == "__main__":
	main()
