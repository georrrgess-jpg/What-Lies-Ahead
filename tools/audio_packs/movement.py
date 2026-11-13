"""Player movement sounds: the mantle (hands slap onto a ledge, a pull-up and
the feet settling on top), the vault (a palm slap and a quick whoosh over),
the dash (a shoe scuff and a short rush of air) and the heavy landing after a
long drop (a deep thud and grit settling).
Footsteps, jump, land and slide are in the core set (tools/gen_audio.py).

    python tools/gen_audio.py movement
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403  (sweep, noise, band, filt, env, place, silence, ...)

MUSIC = {}


def _slap(d=0.09, centre=1400, gain=1.0):
    """A gloved palm landing on a hard edge: a short knock with a body thump."""
    knock = band(noise(d), centre, centre * 0.45) * env(d, 0.0008, d * 0.35, power=2.4) * 2.2
    thump = sweep(190, 90, d, "sine", 0.5) * env(d, 0.001, d * 0.5, power=2.0)
    return (knock + thump) * gain


def _rustle(d, centre=2600, gain=1.0):
    """Clothes and gear shifting: soft band noise with a slow swell."""
    return band(noise(d), centre, centre * 0.5) * env(d, d * 0.3, d, power=1.3) * gain


def _whoosh(d, f0, f1, gain=1.0):
    """Air past the body: noise swept through a moving band."""
    n = int(SR * d)
    out = np.zeros(n)
    parts = 8
    for i in range(parts):
        seg = d / parts
        centre = f0 + (f1 - f0) * (i + 0.5) / parts
        place(out, band(noise(seg * 1.6), centre, centre * 0.4) * np.hanning(int(SR * seg * 1.6)), i * seg, 1.0)
    return out * env(d, d * 0.35, d, power=1.1) * gain


def move_mantle():
    d = 0.42
    out = silence(d)
    place(out, _slap(0.09, 1300), 0.0, 0.9)
    place(out, _slap(0.09, 1600), 0.05, 0.7)
    place(out, _rustle(0.3, 2400), 0.06, 0.35)
    place(out, _whoosh(0.26, 420, 900), 0.1, 0.5)
    return out


def move_mantle_land():
    d = 0.16
    thud = sweep(150, 80, d, "sine", 0.5) * env(d, 0.002, 0.1, power=2.2)
    knock = band(noise(d), 1000, 420) * env(d, 0.001, 0.05, power=2.0) * 2.0
    return thud + knock + _rustle(d, 2200, 0.25)


def move_vault():
    d = 0.46
    out = silence(d)
    place(out, _slap(0.08, 1500), 0.0, 1.0)
    place(out, _whoosh(0.34, 500, 1500), 0.04, 0.8)
    place(out, _rustle(0.22, 2800), 0.08, 0.3)
    return out


def move_dash():
    d = 0.32
    out = silence(d)
    scuff = band(noise(0.07), 2200, 1400) * env(0.07, 0.001, 0.05, power=2.0) * 1.4
    place(out, scuff, 0.0, 0.8)
    place(out, sweep(160, 70, 0.08, "sine", 0.5) * env(0.08, 0.001, 0.05, power=2.0), 0.0, 0.6)
    place(out, _whoosh(0.28, 1400, 500), 0.01, 1.0)
    place(out, _rustle(0.16, 3000), 0.02, 0.3)
    return out


def move_land_heavy():
    d = 0.5
    out = silence(d)
    place(out, sweep(110, 38, 0.32, "sine", 0.5) * env(0.32, 0.002, 0.22, power=2.0), 0.0, 1.0)
    place(out, band(noise(0.12), 700, 380) * env(0.12, 0.001, 0.08, power=2.0) * 1.6, 0.0, 0.8)
    grit = band(noise(0.4), 3200, 1800) * env(0.4, 0.03, 0.4, power=1.6)
    place(out, grit, 0.05, 0.25)
    return out


SOUNDS = [move_mantle, move_mantle_land, move_vault, move_dash, move_land_heavy]
VARIANTS = [(move_mantle, (0.94, 1.06)), (move_vault, (0.93, 1.07)), (move_dash, (0.92, 1.08))]
