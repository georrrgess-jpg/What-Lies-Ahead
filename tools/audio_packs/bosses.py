"""Finale alpha audio pack: the telegraphs and hits of the alphas' signature
moves (scripts/enemies/behaviours/boss_*.gd). All synthesised. Every warning
rises (it says "something is coming here"), every hit is a short low thump
with a bright edge, so the two never blur.

    rounds_boss_cast          a signature move winds up: a rising brassy swell
    rounds_boss_zone_warn     a strike marker appears: a quick rising whistle
    rounds_boss_zone_hit      a strike lands: a thump and a crackle
    rounds_boss_crate_smash   a prize booth lands: wood crunch and a spring
    rounds_boss_charge_windup a charge winds up: a snort and a scrape
    rounds_boss_charge        the charge: a rushing whoosh
    rounds_boss_pound         a ground pound: a deep boom
    rounds_boss_beam          a beam sweeps: a buzzing hum that rises
    rounds_boss_surface       Inky bursts up: a splash and a gulp
    rounds_boss_splash        Inky dives: a plunge
    rounds_boss_event         the arena joins in: a low swell and a gong
    rounds_boss_gust          a gale gust: filtered noise swell
    rounds_boss_roar          the entrance / phase roar: a growl over a sub drop
    rounds_boss_dazed         dazed: a cartoon dizzy warble
    rounds_boss_plate_break   an armour plate pops: metal clank and ring
    rounds_boss_defeat        the alpha falls: a fanfare hit and a long boom
    rounds_boss_stone         a stone pillar rises: a grinding rumble
    rounds_boss_geyser        a lava geyser: a hiss and a blorp
    rounds_boss_thunder       lightning: a crack and a rolling rumble

    python tools/gen_audio.py bosses
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import SR


def _bp(x, lo, hi):
    """Band-pass lo..hi Hz (filt takes the low-pass corner first: filt(x, 60, 2400)
    was a 60 Hz low-pass that left the alphas' roars as sub rumble and their
    defeat silent)."""
    return filt(x, low=hi, high=lo)


def _thump(f0=110, f1=40, seconds=0.35, gain=1.0):
    return sweep(f0, f1, seconds, "sine", 0.6) * env(seconds, 0.002, seconds, power=2.4) * gain


def _hiss(seconds, low=2000, high=9000, gain=1.0, attack=0.01):
    return _bp(noise(seconds), low, high) * env(seconds, attack, seconds, power=1.8) * gain


def _growl(base, seconds, rasp=0.35):
    t = t_axis(seconds)
    f = base * (1.0 + 0.25 * np.sin(2 * np.pi * 1.3 * t) - 0.3 * t / seconds)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.5 * np.sign(np.sin(2 * np.pi * np.cumsum(f * 2.01) / SR))
    grit = _bp(noise(seconds), 200, 1600) * rasp * (1.0 + np.sin(2 * np.pi * 31 * t))
    return _bp(body * 0.6 + grit, 60, 2400) * env(seconds, 0.08, seconds, sustain=0.6, release=0.4, power=1.3)


def rounds_boss_cast():
    out = silence(1.0)
    place(out, sweep(180, 420, 0.9, "saw", 1.4) * env(0.9, 0.5, 0.9, power=1.2) * 0.35, 0.0)
    place(out, sweep(270, 630, 0.9, "square", 1.4) * env(0.9, 0.5, 0.9, power=1.2) * 0.15, 0.0)
    return _bp(out, 80, 5000)


def rounds_boss_zone_warn():
    out = silence(0.7)
    place(out, sweep(700, 1900, 0.55, "sine", 1.6) * env(0.55, 0.05, 0.55, power=1.0) * 0.5, 0.0)
    place(out, sweep(1400, 3800, 0.55, "tri", 1.6) * env(0.55, 0.05, 0.55, power=1.0) * 0.15, 0.02)
    return out


def rounds_boss_zone_hit():
    out = silence(0.6)
    place(out, _thump(140, 45, 0.45), 0.0)
    place(out, _hiss(0.25, 1500, 7000, 0.4, 0.001), 0.0)
    return out


def rounds_boss_crate_smash():
    out = silence(0.8)
    place(out, _thump(120, 50, 0.4), 0.0)
    for i in range(7):
        place(out, clunk(300 + 90 * i, 0.06, 0.5), 0.02 + 0.035 * i)
    place(out, sweep(300, 900, 0.3, "sine", 1.0) * np.sin(np.linspace(0, 40, int(SR * 0.3))) * env(0.3, 0.005, 0.3) * 0.3, 0.12)
    return out


def rounds_boss_charge_windup():
    out = silence(1.0)
    place(out, _bp(noise(0.35), 300, 1800) * env(0.35, 0.02, 0.35, power=1.5) * 0.8, 0.0)
    place(out, _growl(90, 0.7, 0.5) * 0.7, 0.25)
    return out


def rounds_boss_charge():
    out = silence(0.9)
    t = t_axis(0.85)
    sweep_band = _bp(noise(0.85), 300, 3000) * (0.4 + 0.6 * np.sin(np.pi * t / 0.85))
    place(out, sweep_band * env(0.85, 0.1, 0.85, power=1.2), 0.0)
    place(out, _thump(90, 50, 0.6, 0.6), 0.0)
    return out


def rounds_boss_pound():
    out = silence(1.0)
    place(out, _thump(90, 28, 0.9, 1.2), 0.0)
    place(out, _hiss(0.2, 400, 3000, 0.4, 0.001), 0.0)
    return out


def rounds_boss_beam():
    seconds = 2.4
    t = t_axis(seconds)
    f = 220 + 160 * t / seconds
    buzz = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.3 + np.sin(2 * np.pi * np.cumsum(f * 3) / SR) * 0.3
    return _bp(buzz * (0.8 + 0.2 * np.sin(2 * np.pi * 14 * t)), 100, 4000) * env(seconds, 0.05, seconds, sustain=0.8, release=0.3, power=1.0)


def rounds_boss_surface():
    out = silence(1.0)
    place(out, _hiss(0.5, 300, 4000, 0.8, 0.002), 0.0)
    place(out, _thump(160, 60, 0.4), 0.0)
    place(out, sweep(500, 180, 0.25, "sine") * env(0.25, 0.01, 0.25) * 0.4, 0.3)
    return out


def rounds_boss_splash():
    out = silence(0.8)
    place(out, sweep(180, 500, 0.3, "sine") * env(0.3, 0.01, 0.3) * 0.4, 0.0)
    place(out, _hiss(0.55, 200, 3000, 0.6, 0.02), 0.05)
    return out


def rounds_boss_event():
    out = silence(2.4)
    place(out, sweep(55, 75, 1.6, "saw", 1.0) * env(1.6, 0.8, 1.6, power=1.0) * 0.4, 0.0)
    gong = sum(tone(f, 1.6, "sine") * 0.3 / (k + 1) for k, f in enumerate((110, 167, 232, 341)))
    place(out, gong * env(1.6, 0.003, 1.6, power=2.0), 0.7)
    return _bp(out, 40, 6000)


def rounds_boss_gust():
    seconds = 1.6
    t = t_axis(seconds)
    swell = np.sin(np.pi * t / seconds) ** 2
    return _bp(noise(seconds), 250, 2200) * swell * 0.8


def rounds_boss_roar():
    out = silence(1.8)
    place(out, _growl(70, 1.6, 0.45), 0.0)
    place(out, sweep(70, 30, 1.2, "sine") * env(1.2, 0.05, 1.2, power=1.5) * 0.6, 0.1)
    return out


def rounds_boss_dazed():
    seconds = 1.2
    t = t_axis(seconds)
    f = 900 + 300 * np.sin(2 * np.pi * 5.0 * t)
    tw = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(seconds, 0.02, seconds, power=1.4) * 0.35
    out = silence(seconds)
    place(out, tw, 0.0)
    for i in range(3):
        place(out, tone(note(19 + 4 * i), 0.18, "tri") * env(0.18, 0.003, 0.18) * 0.2, 0.15 + i * 0.25)
    return out


def rounds_boss_plate_break():
    out = silence(0.9)
    place(out, clunk(220, 0.12, 1.0), 0.0)
    ring = sum(tone(f, 0.8, "sine") / (k + 1) for k, f in enumerate((1250, 1890, 2710)))
    place(out, ring * env(0.8, 0.002, 0.8, power=2.5) * 0.35, 0.0)
    place(out, _hiss(0.12, 3000, 10000, 0.4, 0.001), 0.0)
    return out


def rounds_boss_defeat():
    out = silence(2.8)
    place(out, _thump(80, 25, 1.6, 1.2), 0.0)
    for i, n in enumerate((0, 4, 7, 12)):
        place(out, (tone(note(n), 1.4, "saw") * 0.4 + tone(note(n + 12), 1.4, "square") * 0.15) * env(1.4, 0.01, 1.4, power=1.6) * 0.3, 0.05 + 0.06 * i)
    place(out, _hiss(1.2, 3000, 11000, 0.25, 0.01), 0.05)
    return _bp(out, 30, 9000)


def rounds_boss_stone():
    out = silence(1.0)
    t = t_axis(0.8)
    grind = _bp(noise(0.8), 80, 900) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t))
    place(out, grind * env(0.8, 0.05, 0.8, power=1.3), 0.0)
    place(out, _thump(100, 40, 0.35, 0.8), 0.05)
    return out


def rounds_boss_geyser():
    out = silence(1.0)
    place(out, _hiss(0.8, 1200, 8000, 0.6, 0.01), 0.0)
    place(out, sweep(120, 260, 0.25, "sine") * env(0.25, 0.01, 0.25) * 0.6, 0.0)
    place(out, _thump(100, 40, 0.4, 0.7), 0.0)
    return out


def rounds_boss_thunder():
    out = silence(2.0)
    place(out, _hiss(0.12, 2500, 12000, 1.0, 0.0005), 0.0)
    t = t_axis(1.8)
    rumble = _bp(noise(1.8), 40, 300) * (0.7 + 0.3 * np.sin(2 * np.pi * 3.0 * t))
    place(out, rumble * env(1.8, 0.05, 1.8, power=1.6) * 1.2, 0.05)
    return out


SOUNDS = [
    rounds_boss_cast, rounds_boss_zone_warn, rounds_boss_zone_hit, rounds_boss_crate_smash,
    rounds_boss_charge_windup, rounds_boss_charge, rounds_boss_pound, rounds_boss_beam,
    rounds_boss_surface, rounds_boss_splash, rounds_boss_event, rounds_boss_gust, rounds_boss_roar,
    rounds_boss_dazed, rounds_boss_plate_break, rounds_boss_defeat, rounds_boss_stone,
    rounds_boss_geyser, rounds_boss_thunder,
]
