"""The Swirl Smasher (swirl_smasher), the melee-slot giant lollipop club:
round, sweet and crunchy. The swing is a big soft whoosh with a sugary
glint, a hit is a hard-candy "tok" on a body thud, the charged smash cracks
the candy (a brittle snap with a crunch) and sprays sugar shards that
tinkle down like glass beads. Cellophane crinkles on the equip. All names
start with "swirl_" (audio/mix.tres: the whoosh on "weapon", the hit, crack
and shatter on "impact", the rest on "handling").

    python tools/gen_audio.py swirl_smasher
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import HANDLE, HEAVY, HIT, MID, punched


def _n(d, seed):
    """Seeded white noise (each sound draws its own, so edits never re-roll another)."""
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(SR * d))


def _whoosh(d, f0, f1, width=0.6, seed=3, curve=1.0):
    """A broad rush of air: band-passed noise gliding f0 -> f1, swelling then falling."""
    w = _n(d, seed)
    out = np.zeros_like(w)
    steps = 14
    seg = len(w) // steps
    for i in range(steps):
        c = f0 + (f1 - f0) * (i / (steps - 1)) ** curve
        part = band(w, c, c * width)
        a, b = i * seg, len(w) if i == steps - 1 else (i + 1) * seg
        out[a:b] = part[a:b]
    shape = np.sin(np.pi * np.arange(len(w)) / len(w)) ** 1.4
    return filt(out, low=5000) * shape


def _tok(pitch=1.0, gain=1.0, seed=1):
    """Hard candy struck: a glassy-woody knock with two inharmonic partials."""
    d = 0.16
    body = (tone(720 * pitch, d) * 0.6 + tone(1130 * pitch, d) * 0.3 + tone(1890 * pitch, d) * 0.1) * env(d, 0.0005, 0.06, power=2.4)
    hit = band(_n(d, seed), 1600 * pitch, 700) * env(d, 0.0003, 0.012, power=2.5) * 1.5
    return (body + hit) * gain


def _crunch(d, gain=1.0, seed=5, centre=2400):
    """Sugar crunching: dense, uneven crackle grains."""
    r = np.random.default_rng(seed)
    out = silence(d)
    for _ in range(int(d * 140)):
        at = r.uniform(0, d - 0.01)
        g = band(r.uniform(-1, 1, int(SR * 0.008)), r.uniform(centre * 0.6, centre * 1.4), 600) * np.hanning(int(SR * 0.008))
        place(out, g, at, r.uniform(0.2, 0.8) * (1.0 - at / d) ** 1.2)
    return out * gain


def _tinkles(d, count, seed, lo=900, hi=2200, gain=1.0):
    """Shards landing: short bright bead pings scattered in time (fundamentals under 2.2 kHz)."""
    r = np.random.default_rng(seed)
    out = silence(d)
    for _ in range(count):
        at = r.uniform(0.0, d - 0.12) ** 1.0
        f = r.uniform(lo, hi)
        ping = (tone(f, 0.1) * 0.7 + tone(f * 2.76, 0.1) * 0.12) * env(0.1, 0.0008, 0.07, power=2.4)
        place(out, ping, at, r.uniform(0.15, 0.45) * (1.0 - 0.6 * at / d))
    return out * gain


@punched(MID, thump_gain=0.2, snap_gain=0.0)
def swirl_whoosh():
    """A swing: a big, round whoosh with a faint sugary glint at its peak."""
    d = 0.42
    out = _whoosh(d, 260, 900, width=0.7, seed=11, curve=0.8)
    place(out, _whoosh(0.2, 1400, 2400, width=0.4, seed=12) * 0.18, 0.12, 1.0)
    return filt(out, low=5500, high=90)


@punched(HIT, thump_gain=0.5)
def swirl_hit():
    """The candy lands on a zombie: a hard-candy tok over a meaty thud."""
    d = 0.4
    out = _sub_thump(170, 65, d, 0.08)
    place(out, _tok(1.0, 1.5, seed=21), 0.0, 1.0)
    place(out, filt(_n(0.15, 22), low=1200, high=120) * env(0.15, 0.001, 0.07, power=2.0) * 0.7, 0.002, 1.0)
    place(out, _crunch(0.08, 0.6, seed=23), 0.01, 1.0)
    return filt(out, low=6500)


@punched(HEAVY, thump_gain=0.45)
def swirl_crack():
    """The charged smash: the candy cracks with a brittle snap and a deep crunch."""
    d = 0.55
    out = _sub_thump(150, 48, d, 0.14) * 1.1
    snap_ = band(_n(0.05, 31), 2200, 1400) * env(0.05, 0.0002, 0.02, power=2.0) * 2.0
    place(out, snap_, 0.0, 1.0)
    place(out, _tok(0.8, 0.7, seed=32), 0.0, 1.0)
    place(out, _crunch(0.3, 1.2, seed=33, centre=1900), 0.015, 1.0)
    place(out, sweep(300, 120, 0.25, "tri", curve=0.6) * env(0.25, 0.002, 0.2, power=2.0) * 0.25, 0.01, 1.0)
    return filt(out, low=6500)


@punched(HIT, thump_gain=0.15, snap_gain=0.0)
def swirl_shatter():
    """Sugar shards spray out and rain down: a glassy burst and a scatter of tinkles."""
    d = 0.9
    out = silence(d)
    place(out, band(_n(0.12, 41), 2000, 1100) * env(0.12, 0.001, 0.08, power=2.0) * 0.6, 0.0, 1.0)
    place(out, _tinkles(0.85, 22, 42, gain=0.9), 0.02, 1.0)
    place(out, _crunch(0.2, 0.25, seed=43, centre=2600), 0.0, 1.0)
    return filt(out, low=6500, high=200)


@punched(HANDLE)
def swirl_equip():
    """Raised: cellophane crinkles, the stick taps the palm, a sweet little tok."""
    d = 0.5
    r = np.random.default_rng(51)
    out = silence(d)
    for _ in range(26):
        at = r.uniform(0.0, 0.28)
        g = band(r.uniform(-1, 1, int(SR * 0.012)), r.uniform(2400, 4200), 900) * np.hanning(int(SR * 0.012))
        place(out, g, at, r.uniform(0.15, 0.4))
    place(out, clunk(220, 0.08, 0.6), 0.3, 1.0)
    place(out, _tok(1.15, 0.5, seed=52), 0.31, 1.0)
    return filt(out, low=6000, high=150)


@punched(HANDLE)
def swirl_windup():
    """The heavy wind-up: the stick creaks as it bends and the candy hums."""
    d = 0.5
    creak = tone(330, d, "tri", vibrato=0.05, vib_rate=19) * env(d, 0.12, d, power=0.8, release=0.08) * 0.25
    hum = sweep(180, 260, d, "sine") * env(d, 0.2, d, power=0.7, release=0.1) * 0.4
    air = _whoosh(d, 300, 600, width=0.5, seed=61) * 0.25
    return filt(creak + hum + air, low=4000, high=100)


SOUNDS = [swirl_whoosh, swirl_hit, swirl_crack, swirl_shatter, swirl_equip, swirl_windup]

VARIANTS = [(swirl_whoosh, (0.92, 1.08)), (swirl_hit, (0.92, 1.08))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
