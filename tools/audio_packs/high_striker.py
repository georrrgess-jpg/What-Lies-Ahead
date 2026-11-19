"""The High Striker (high_striker), the melee-slot strongman mallet: heavy,
wooden and carnival. A slow, deep whoosh; a solid wooden thud on a body;
the charged ground slam (a big low boom, a wood crack and debris); the puck
zipping up the painted scale and the brass bell's DING, the reward the whole
weapon builds to (a warm bell in concert pitch, fundamental under 1.2 kHz).
All names start with "hstrk_" (audio/mix.tres: the whoosh on "weapon",
the thud and the slam on "impact", the DING on "confirm", the rest on
"handling").

    python tools/gen_audio.py high_striker
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import CUE, HANDLE, HEAVY, HIT, MID, punched


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
    shape = np.sin(np.pi * np.arange(len(w)) / len(w)) ** 1.5
    return filt(out, low=4000) * shape


def _wood(pitch=1.0, gain=1.0, d=0.22, seed=1):
    """A hardwood knock: a hollow body tone with a quick resonant ring."""
    body = (tone(210 * pitch, d) * 0.7 + tone(470 * pitch, d) * 0.35 + tone(890 * pitch, d) * 0.12) * env(d, 0.0006, d * 0.4, power=2.4)
    hit = band(_n(d, seed), 1300 * pitch, 600) * env(d, 0.0003, 0.012, power=2.5) * 1.2
    return (body + hit) * gain


def _bell(f, d, gain=1.0):
    """A brass carnival bell: inharmonic partials, the upper ones dying first, a slow beat."""
    t = t_axis(d)
    beat = 1.0 + 0.05 * np.sin(2 * np.pi * 4.5 * t)
    parts = [(1.0, 1.0, d), (2.0, 0.45, d * 0.7), (2.76, 0.3, d * 0.5), (5.4, 0.12, d * 0.25), (0.5, 0.2, d * 0.9)]
    out = np.zeros(len(t))
    for ratio, g, dec in parts:
        out += tone(f * ratio, d) * env(d, 0.0008, dec, power=1.6) * g
    strike = band(_n(0.02, 7), 2600, 900) * env(0.02, 0.0002, 0.008, power=2.0) * 0.6
    out[:len(strike)] += strike
    return out * beat * gain


@punched(MID, thump_gain=0.25, snap_gain=0.0, thump_hz=(110.0, 50.0))
def hstrk_whoosh():
    """A slow, heavy swing: a deep whoosh that builds and falls away."""
    d = 0.6
    out = _whoosh(d, 160, 520, width=0.7, seed=11, curve=1.2)
    place(out, _whoosh(0.35, 500, 900, width=0.5, seed=12) * 0.25, 0.2, 1.0)
    return filt(out, low=4500, high=70)


@punched(HIT, thump_gain=0.6, thump_hz=(130.0, 50.0))
def hstrk_thud():
    """The head lands on a zombie: a big wooden thud on a body."""
    d = 0.45
    out = _sub_thump(150, 55, d, 0.11)
    place(out, _wood(0.9, 1.5, seed=21), 0.0, 1.0)
    place(out, filt(_n(0.2, 22), low=900, high=100) * env(0.2, 0.001, 0.09, power=2.0) * 0.8, 0.003, 1.0)
    return filt(out, low=5500)


def _debris(d, seed, count=16):
    r = np.random.default_rng(seed)
    out = silence(d)
    for _ in range(count):
        at = r.uniform(0.05, d - 0.08)
        g = band(r.uniform(-1, 1, int(SR * 0.03)), r.uniform(700, 2000), 500) * env(0.03, 0.0005, 0.02, power=2.0)
        place(out, g, at, r.uniform(0.1, 0.35) * (1.0 - at / d))
    return out


@punched(HEAVY, thump_gain=0.55)
def hstrk_slam():
    """The charged slam into the ground: a big low boom, the head's wood crack, debris."""
    d = 0.95
    out = _sub_thump(120, 42, d, 0.3) * 1.3
    place(out, _wood(0.75, 1.5, d=0.35, seed=31), 0.0, 1.0)
    crack = band(_n(0.06, 32), 1800, 1000) * env(0.06, 0.0002, 0.025, power=2.0) * 0.9
    place(out, crack, 0.0, 1.0)
    place(out, filt(_n(0.5, 33), low=700, high=80) * env(0.5, 0.004, 0.35, power=1.6) * 0.6, 0.005, 1.0)
    place(out, _debris(0.8, 34, count=24), 0.05, 1.6)
    return filt(out, low=5500)


@punched(HANDLE)
def hstrk_puck():
    """The puck flies up the scale: a rising zip with ticks as it passes each band."""
    d = 0.5
    zip_ = sweep(180, 720, 0.4, "tri", curve=0.6) * env(0.4, 0.01, 0.4, power=0.8, release=0.05) * 0.35
    rattle = band(_n(0.4, 41), 1100, 500) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 34 * t_axis(0.4)))) * env(0.4, 0.01, 0.4, power=0.9) * 0.4
    out = silence(d)
    place(out, zip_ + rattle, 0.0, 1.0)
    for i in range(5):
        place(out, click(0.012, 1300 + i * 120, 0.35), 0.06 + i * 0.07, 1.0)
    return filt(out, low=6000, high=120)


@punched(CUE, thump_gain=0.0)
def hstrk_ding():
    """DING! The brass bell at the top of the scale (A5, 880 Hz), ringing out."""
    d = 1.4
    out = _bell(880.0, d, 1.0)
    place(out, _bell(880.0 * 1.5, 0.8, 0.12), 0.0, 1.0)
    return filt(out, low=7000, high=200)


@punched(HANDLE)
def hstrk_equip():
    """Raised onto the shoulder: a heavy wooden knock, a grip creak, the bell tinkles."""
    d = 0.7
    out = silence(d)
    place(out, _sub_thump(160, 80, 0.2, 0.06) * 0.6, 0.0, 1.0)
    place(out, _wood(1.0, 0.8, seed=51), 0.0, 1.0)
    place(out, tone(300, 0.2, "tri", vibrato=0.06, vib_rate=21) * env(0.2, 0.05, 0.2, power=1.0) * 0.12, 0.12, 1.0)
    place(out, _bell(880.0, 0.5, 0.18), 0.22, 1.0)
    return filt(out, low=6000, high=90)


@punched(HANDLE)
def hstrk_windup():
    """The heavy wind-up: the handle creaks under the strain and air swells behind the head."""
    d = 0.6
    creak = tone(240, d, "tri", vibrato=0.07, vib_rate=15) * env(d, 0.15, d, power=0.8, release=0.08) * 0.25
    air = _whoosh(d, 140, 320, width=0.6, seed=61, curve=1.5) * 0.6
    return filt(creak + air, low=3500, high=80)


SOUNDS = [hstrk_whoosh, hstrk_thud, hstrk_slam, hstrk_puck, hstrk_ding, hstrk_equip, hstrk_windup]

VARIANTS = [(hstrk_whoosh, (0.93, 1.07)), (hstrk_thud, (0.93, 1.07))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
