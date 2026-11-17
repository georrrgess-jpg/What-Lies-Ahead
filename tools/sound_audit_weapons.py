#!/usr/bin/env python3
"""Weapon fire sounds against the house targets (docs/SOUND_AUDIT.md): one row
per weapon (data/weapons/*.tres) with its fire sound's in-game level and the
ceiling it must sit under: -17 for a fast auto (8+ shots a second), -14 for the
rest, -11 for a big shot (one every 0.4 s or slower); and the floor it should
stay above: -20 (-22 for a fast auto, heard many times over).

    python3 tools/sound_audit_weapons.py [audit.csv]
        reads an audit CSV (tools/sound_audit.py --csv); without one it measures now
"""
import csv
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sound_audit  # noqa: E402

ROOT = sound_audit.ROOT
FLOOR_DB = -20.0
FLOOR_AUTO_DB = -22.0


def weapons():
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data/weapons/*.tres"))):
        text = open(path, encoding="utf-8").read()
        sound = re.search(r'^fire_sound = &"(\w+)"', text, re.M)
        interval = re.search(r"^fire_interval = ([\d.]+)", text, re.M)
        auto = re.search(r"^automatic = (\w+)", text, re.M)
        out.append({"id": os.path.basename(path)[:-5], "sound": sound.group(1) if sound else "",
                    "interval": float(interval.group(1)) if interval else 0.0,
                    "auto": bool(auto and auto.group(1) == "true")})
    return out


def ceiling(w):
    if w["auto"] and 0 < w["interval"] <= 0.125:
        return -17.0
    return -11.0 if w["interval"] >= 0.4 else -14.0


def main():
    if len(sys.argv) > 1:
        rows = {r["name"]: r for r in csv.DictReader(open(sys.argv[1]))}
    else:
        rows = sound_audit.collect()
        sound_audit.flag(rows)
        rows = {k: {c: str(v) for c, v in r.items()} for k, r in rows.items()}
    print("%-18s %-20s %5s %4s %6s %6s %5s %5s %5s %6s  %s" % (
        "weapon", "fire sound", "shot/s", "auto", "peak", "eff", "hf4", "hf8", "low80", "max", "verdict"))
    for w in weapons():
        r = rows.get(w["sound"])
        if r is None:
            print("%-18s %-20s (no file)" % (w["id"], w["sound"]))
            continue
        eff, top = float(r["eff"]), ceiling(w)
        floor = FLOOR_AUTO_DB if top == -17.0 else FLOOR_DB
        verdict = "over %+.1f" % (eff - top) if eff > top + 0.25 else ("under %+.1f" % (eff - floor) if eff < floor else "ok")
        print("%-18s %-20s %5.1f %4s %6.1f %6.1f %5.1f %5.1f %5.1f %6.1f  %s" % (
            w["id"], w["sound"], 1.0 / w["interval"] if w["interval"] else 0.0, "yes" if w["auto"] else "",
            float(r["peak"]), eff, float(r["hf4"]), float(r["hf8"]), float(r["low80"]), top, verdict))


if __name__ == "__main__":
    main()
