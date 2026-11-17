"""The Yo-Yo Loco (update 13 secondary): a wrist launcher that snaps a toy
yo-yo out on a glowing string. Plastic clacks, a whippy string zing out and a
zip back, a buzzing grind for the Sleeper, a rattling roll for Walk the Dog
and a whooshing loop for the Around the World reload. Bright but rounded,
the top end rolled off so nothing turns shrill. All names start with "yoyo_"
(audio/mix.tres puts the throw on "weapon", hits, trips and the grind on
"impact", the rest on "handling").

    python tools/gen_audio.py yoyo_loco
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump

import _sidearm_fx as fx


def _clack(freq, d, gain=1.0):
    """Two hard plastic halves knocking: a short hollow pitched knock."""
    body = (tone(freq, d, "tri") + tone(freq * 2.7, d) * 0.35) * env(d, 0.0005, d * 0.5, power=3.0)
    hit = filt(noise(d), high=1200, low=6000) * env(d, 0.0003, 0.012, power=2.0) * 0.7
    return (body + hit) * gain


def _zing(f0, f1, d, gain=1.0):
    """A taut string whipping: a gliding twang with a breathy edge."""
    t = t_axis(d)
    freq = f0 + (f1 - f0) * (t / d) ** 0.6
    twang = osc(2 * np.pi * np.cumsum(freq) / SR, "tri") * 0.6 + osc(2 * np.pi * np.cumsum(freq * 2.01) / SR, "sine") * 0.25
    air = band(noise(d), (f0 + f1) * 1.5, 1600) * 0.35
    return (twang + air) * env(d, 0.003, d, power=1.4, release=d * 0.3) * gain


def _whoosh(d, f0=500, f1=1500, gain=1.0):
    return band(noise(d), (f0 + f1) * 0.5, abs(f1 - f0) + 200) * env(d, d * 0.4, d, power=0.8, release=d * 0.4) * gain


def yoyo_throw():
    """The snap out: a thumb flick, a clack off the fork and the string zinging out."""
    d = 0.32
    out = _sub_thump(210, 90, d, 0.05) * 0.9
    place(out, _clack(700, 0.06, 0.7), 0.0, 1.0)
    place(out, _zing(500, 1400, 0.22, 0.5), 0.01, 1.0)
    place(out, click(0.015, 2200, 0.5), 0.0, 1.0)
    return fx.fire(out, 9001, 2600, 0.5, (120, 55, 0.07, 0.8), 0.18, 0.045, 0.22, 1.15, 7000)


def yoyo_hit():
    """The yo-yo cracking into a zombie: a meaty thock and a plastic clack."""
    d = 0.26
    thock = filt(noise(d), low=1500, high=100) * env(d, 0.001, 0.04, power=2.0) * 0.9
    out = _sub_thump(170, 78, d, 0.06) + thock
    place(out, _clack(560, 0.1, 0.6), 0.0, 1.0)
    return fx.fire(out, 9011, 2400, 0.5, (120, 62, 0.07, 0.7), 0.15, 0.04, 0.2, 1.3, 6500, 0.2)


def yoyo_snap():
    """The string goes taut and reels it in: a short zip."""
    return filt(_zing(1300, 700, 0.14, 0.45), low=6000)


def yoyo_catch():
    """Home: the yo-yo slaps into the fork and spins."""
    d = 0.3
    out = silence(d)
    place(out, _clack(820, 0.08, 0.9), 0.0, 1.0)
    place(out, clunk(300, 0.06, 0.5), 0.0, 1.0)
    t = t_axis(0.2)
    whirr = band(noise(0.2), 1500, 700) * (0.5 + 0.5 * np.sin(2 * np.pi * 40 * t)) * env(0.2, 0.01, 0.2, power=1.2) * 0.3
    place(out, whirr, 0.03, 1.0)
    return filt(out, low=7000)


def yoyo_clack():
    """A wall, the floor, the fork at the end of the reload: a clean clack."""
    return filt(_clack(640, 0.12, 0.9), low=6500)


def yoyo_trip():
    """Walk the Dog snags an ankle: a string zip and a stumbling thud."""
    d = 0.32
    out = silence(d)
    place(out, _zing(900, 500, 0.12, 0.45), 0.0, 1.0)
    place(out, _sub_thump(140, 60, 0.2, 0.05) * 0.8, 0.04, 1.0)
    place(out, _clack(480, 0.07, 0.4), 0.02, 1.0)
    return fx.fire(out, 9021, 2200, 0.3, (120, 50, 0.07, 0.6), 0.15, 0.04, 0.2, 1.1, 6000, 0.15)


def yoyo_equip():
    """Raised: the spool ratchets and the yo-yo seats in the fork."""
    out = silence(0.4)
    for i in range(4):
        place(out, click(0.012, 2400 - i * 150, 0.35), 0.03 + i * 0.045, 1.0)
    place(out, _clack(760, 0.07, 0.6), 0.24, 1.0)
    fx.place_at(out, fx.holo(0.14, 650, 1400, 9041, 0.12), 0.05)
    return filt(out, low=7000)


def yoyo_reload():
    """The reload starts: the gun rolls over with a soft rattle."""
    d = 0.18
    out = band(noise(d), 1800, 900) * env(d, 0.02, d, power=1.2) * 0.25
    place(out, click(0.015, 1600, 0.35), 0.0, 1.0)
    fx.place_at(out, fx.tick(9051, 2200, gain=0.3), 0.0)
    return filt(out, low=6000)


def yoyo_fray():
    """The worn string frays: crackling snaps and a sagging twang."""
    d = 0.4
    out = _zing(700, 380, 0.3, 0.35)
    for i, at in enumerate((0.0, 0.05, 0.11, 0.16)):
        place(out, click(0.01, 3000 - i * 300, 0.45), at, 1.0)
    return filt(out, low=6500)


def yoyo_pop():
    """The yo-yo pops out of the fork."""
    out = silence(0.18)
    place(out, _clack(900, 0.06, 0.6), 0.0, 1.0)
    place(out, _zing(600, 1100, 0.12, 0.3), 0.01, 1.0)
    return filt(out, low=7000)


def yoyo_whirl():
    """Around the World: the loop whooshing past, rising then falling."""
    d = 0.75
    t = t_axis(d)
    centre = 900 + 700 * np.sin(np.pi * t / d)
    swish = band(noise(d), 1100, 900) * (0.4 + 0.6 * np.sin(np.pi * t / d) ** 2)
    hum = osc(2 * np.pi * np.cumsum(centre * 0.25) / SR, "tri") * 0.12
    return filt((swish * 0.6 + hum) * env(d, 0.05, d, power=1.0, release=0.12), low=5000)


def yoyo_rewind():
    """The spool rewinding the new string: a fast ratcheting zip, climbing."""
    d = 0.8
    t = t_axis(d)
    rate = 18 + 30 * (t / d)
    ratchet = (np.sin(2 * np.pi * np.cumsum(rate) / SR) > 0.85).astype(float)
    ticks = filt(noise(d), high=1800, low=5000) * ratchet * 0.5
    whine = osc(2 * np.pi * np.cumsum(500 + 500 * t / d) / SR, "tri") * 0.08
    return filt((ticks + whine) * env(d, 0.03, d, power=0.8, release=0.08), low=6000)


def yoyo_grind_loop():
    """The Sleeper: a buzzing plastic grind against the zombie (seamless)."""
    d = 0.5
    t = t_axis(d + 0.1)
    buzz = osc(2 * np.pi * 95 * t, "saw") * 0.18 * (0.7 + 0.3 * np.sin(2 * np.pi * 24 * t))
    rasp = band(noise(d + 0.1), 1400, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 36 * t)) * 0.5
    return loopable(filt(buzz + rasp, low=4500), 0.1)


def yoyo_roll_loop():
    """Walk the Dog: a rattling roll along the floor (seamless)."""
    d = 0.5
    t = t_axis(d + 0.1)
    rattle = band(noise(d + 0.1), 900, 600) * (0.45 + 0.55 * np.abs(np.sin(2 * np.pi * 14 * t)))
    hum = tone(140, d + 0.1, "tri") * 0.12
    return loopable(filt(rattle * 0.55 + hum, low=3500), 0.1)


SOUNDS = [yoyo_throw, yoyo_hit, yoyo_snap, yoyo_catch, yoyo_clack, yoyo_trip, yoyo_equip, yoyo_reload, yoyo_fray, yoyo_pop,
          yoyo_whirl, yoyo_rewind]

VARIANTS = [(yoyo_throw, (0.95, 1.06)), (yoyo_hit, (0.92, 1.08)), (yoyo_trip, (0.93, 1.07))]

LOOPS = {"yoyo_grind_loop": yoyo_grind_loop, "yoyo_roll_loop": yoyo_roll_loop}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
