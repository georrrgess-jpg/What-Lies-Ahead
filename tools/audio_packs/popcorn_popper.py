"""The Popcorn Popper (popcorn_popper), a heat-staged kettle cannon: a round
"pomp" from the horn with a crisp popcorn crack, pops that crackle in
flight, soft popcorn puffs and a fat buttery splat, a kettle that whistles
and rattles when it jams, and a reload of a tin lid, rattling kernels, a
squeezy butter pump and a crackling batch popping. All names start with
"pcp_" (audio/mix.tres puts the shot on "weapon", the pops and splats on
"impact" and the rest on "handling").

    python tools/gen_audio.py popcorn_popper
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump


def _pop(pitch=1.0, gain=1.0):
    """One popcorn pop: a hard crack and a short hollow body."""
    d = 0.07
    crack = band(noise(d), 3400 * pitch, 1800) * env(d, 0.0003, 0.012, power=2.5) * 3.0
    body = sweep(900 * pitch, 380 * pitch, d, "sine", 0.5) * env(d, 0.0005, 0.045, power=2.2) * 0.7
    return (crack + body) * gain


def _rattle(d, rate, gain=1.0, seed=2, pitch=1.0):
    """A tin lid chattering on its rim: irregular metallic ticks."""
    rnd = np.random.default_rng(seed)
    out = silence(d)
    t = 0.0
    while t < d - 0.03:
        tick = click(0.025, rnd.uniform(2600, 4200) * pitch, 0.8) + tone(rnd.uniform(1700, 2300) * pitch, 0.025, "tri") * env(0.025, 0.0005, power=3.0) * 0.3
        place(out, tick, t, rnd.uniform(0.5, 1.0))
        t += rnd.uniform(0.5, 1.5) / rate
    return out * gain


def _hiss(d, gain=1.0, centre=6000):
    return band(noise(d), centre, 2600) * gain


def _grains(d, density, gain=1.0, seed=4):
    """Kernels pouring: a dense stream of tiny dry ticks."""
    rnd = np.random.default_rng(seed)
    out = silence(d)
    for _ in range(int(d * density)):
        place(out, click(0.01, rnd.uniform(3000, 6500), 0.4), rnd.uniform(0.0, d - 0.012), rnd.uniform(0.3, 1.0))
    return out * gain


def pcp_fire():
    """A kernel blown out of the horn: a round pomp, a thump and a crack."""
    d = 0.22
    out = _sub_thump(170, 70, d, 0.05) * 0.9
    place(out, sweep(420, 160, 0.09, "sine", 0.5) * env(0.09, 0.001, 0.09, power=2.0) * 0.7, 0.0, 1.0)
    place(out, _pop(1.1, 0.75), 0.006, 1.0)
    place(out, filt(noise(0.06), low=3000, high=400) * env(0.06, 0.001, 0.05, power=2.0) * 0.35, 0.0, 1.0)
    return crush(filt(out, low=8500), 1.5)


def pcp_pop():
    """A kernel popping in flight."""
    return filt(_pop(1.0, 1.0), low=9000)


def pcp_puff():
    """A warm kernel lands: a soft popcorn puff with a little crackle."""
    d = 0.3
    out = filt(noise(d), low=1800, high=200) * env(d, 0.002, 0.12, power=2.0) * 0.8
    for i, at in enumerate((0.0, 0.025, 0.05)):
        place(out, _pop(1.2 + 0.15 * i, 0.5), at, 1.0)
    return filt(out, low=8000)


def pcp_butter():
    """A hot burst: a fat wet splat, a whoomph and a buttery sizzle."""
    d = 0.5
    out = _sub_thump(130, 50, d, 0.12) * 1.0
    place(out, filt(noise(d), low=2400, high=120) * env(d, 0.001, 0.09, power=2.0) * 0.9, 0.0, 1.0)
    place(out, _hiss(0.45, 0.25, 4800) * env(0.45, 0.02, 0.45, power=1.4), 0.03, 1.0)
    for i, at in enumerate((0.01, 0.04, 0.07, 0.11)):
        place(out, _pop(0.9 + 0.12 * i, 0.45), at, 1.0)
    return crush(filt(out, low=8500), 1.3)


def pcp_stage():
    """The kettle climbs a stage: a bright rising two-note ding and a sizzle."""
    d = 0.35
    out = silence(d)
    for i, f in enumerate((880, 1320)):
        place(out, (tone(f, 0.22, "tri") + tone(f * 2, 0.22) * 0.2) * env(0.22, 0.002, 0.22, power=2.0) * 0.4, i * 0.05, 1.0)
    place(out, _hiss(0.25, 0.08) * env(0.25, 0.01, 0.25, power=1.5), 0.0, 1.0)
    return filt(out, low=9500)


def pcp_jam():
    """Overheated: a shrieking steam whistle over a wildly rattling lid, then a hiss."""
    d = 1.4
    t = t_axis(d)
    whistle = (tone(2350, d, "sine", vibrato=0.012, vib_rate=7) + tone(2790, d, "sine", vibrato=0.01, vib_rate=6) * 0.6) * 0.22
    whistle *= np.clip(t / 0.06, 0.0, 1.0) * np.clip((1.05 - t) / 0.4, 0.0, 1.0) ** 1.5
    breath = _hiss(d, 0.25, 5200) * np.clip(t / 0.03, 0.0, 1.0) * np.clip((d - t) / 0.6, 0.0, 1.0)
    out = whistle + breath + _rattle(d, 26, 0.75)
    place(out, clunk(180, 0.12, 0.8), 0.0, 1.0)
    return filt(out, low=10000)


def pcp_unjam():
    """The jam clears: a last hiss and the lid dropping back with a clank."""
    d = 0.4
    out = _hiss(d, 0.15, 4500) * env(d, 0.005, 0.25, power=1.5)
    place(out, clunk(260, 0.1, 0.9), 0.02, 1.0)
    place(out, click(0.02, 3200, 0.6), 0.09, 1.0)
    return filt(out, low=9000)


def pcp_unlatch():
    """The reload starts: the lid's latch clicks open."""
    d = 0.2
    out = click(0.02, 2800, 0.9)
    out = np.concatenate([out, silence(d - len(out) / SR)])
    place(out, click(0.018, 1900, 0.7), 0.05, 1.0)
    place(out, tone(1500, 0.12, "tri") * env(0.12, 0.002, 0.12, power=2.5) * 0.15, 0.05, 1.0)
    return filt(out, low=9000)


def pcp_lid_open():
    """The lid flips open on its hinge with a creak and a puff of steam."""
    d = 0.5
    t = t_axis(d)
    creak = tone(620, d, "saw", vibrato=0.08, vib_rate=23) * env(d, 0.02, 0.22, power=1.2) * 0.07
    out = filt(creak, low=3000, high=300)
    place(out, _hiss(0.35, 0.2, 5500) * env(0.35, 0.01, 0.35, power=1.6), 0.06, 1.0)
    place(out, clunk(330, 0.08, 0.5), 0.17, 1.0)
    place(out, click(0.02, 3000, 0.4), 0.24, 1.0)
    return filt(out * (0.9 + 0.1 * np.sin(2 * np.pi * 4 * t)), low=9000)


def pcp_holo():
    """A hologram prints in: a soft rising shimmer."""
    d = 0.4
    hum = sweep(320, 640, d, "tri") * 0.25 + sweep(960, 1600, d) * 0.06
    return filt((hum + _hiss(d, 0.05, 7000)) * env(d, 0.12, d, power=0.9, release=0.12), low=8000)


def pcp_scoop():
    """The scoop tips: a pour of kernels rattling into the kettle."""
    d = 0.7
    t = t_axis(d)
    stream = _grains(d, 260, 1.0)
    swell = np.clip(t / 0.08, 0.0, 1.0) * np.clip((d - t) / 0.25, 0.0, 1.0)
    out = stream * swell + filt(noise(d), low=1200, high=200) * swell * 0.15
    return filt(out, low=9500)


def pcp_pump():
    """One squeeze of the butter pump: a squelchy push and a drip."""
    d = 0.3
    out = filt(noise(d), low=900, high=120) * env(d, 0.01, 0.12, power=1.6) * 0.6
    place(out, sweep(260, 140, 0.1, "sine", 0.6) * env(0.1, 0.004, 0.1, power=1.8) * 0.6, 0.0, 1.0)
    place(out, sweep(900, 1500, 0.05, "sine") * env(0.05, 0.002, 0.05, power=2.0) * 0.25, 0.16, 1.0)
    return filt(out, low=6000)


def pcp_lid_shut():
    """The lid slams shut: a bright tin clang and a latch snap."""
    d = 0.5
    out = _sub_thump(210, 90, d, 0.06)
    place(out, clunk(300, 0.14, 1.0), 0.0, 1.0)
    for f, g in ((1650, 0.18), (2470, 0.12), (3900, 0.06)):
        place(out, tone(f, 0.4, "sine") * env(0.4, 0.001, 0.4, power=2.6) * g, 0.0, 1.0)
    place(out, click(0.02, 2600, 0.8), 0.035, 1.0)
    return filt(out, low=9500)


def pcp_popping():
    """The fresh batch pops: a crackling run of pops that speeds up and thins out."""
    d = 0.45
    rnd = np.random.default_rng(11)
    out = silence(d)
    for i in range(22):
        at = d * 0.85 * (i / 22) ** 0.8
        place(out, _pop(rnd.uniform(0.8, 1.4), rnd.uniform(0.35, 0.8)), at + rnd.uniform(0.0, 0.01), 1.0)
    return filt(out, low=9500)


def pcp_equip():
    """Raised: a tin clink and a couple of pops in the kettle."""
    d = 0.4
    out = silence(d)
    place(out, tone(2100, 0.25, "sine") * env(0.25, 0.002, 0.25, power=2.4) * 0.2, 0.0, 1.0)
    place(out, click(0.015, 2600, 0.4), 0.0, 1.0)
    place(out, _pop(1.1, 0.6), 0.12, 1.0)
    place(out, _pop(1.3, 0.45), 0.2, 1.0)
    return filt(out, low=9000)


SOUNDS = [pcp_fire, pcp_pop, pcp_puff, pcp_butter, pcp_stage, pcp_jam, pcp_unjam, pcp_unlatch, pcp_lid_open, pcp_holo,
          pcp_scoop, pcp_pump, pcp_lid_shut, pcp_popping, pcp_equip]

VARIANTS = [(pcp_fire, (0.93, 1.07)), (pcp_pop, (0.85, 1.18)), (pcp_puff, (0.9, 1.1)), (pcp_butter, (0.92, 1.08))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
