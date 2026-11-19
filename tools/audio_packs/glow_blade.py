"""The default melee weapon, the Glow Blade (glow_blade): a neon switchblade.
Sharp, airy and electric: the flick open is a spring snap, a steel ring and a
little neon zap; each swing is a fast air swish with a thin electric edge (three
takes, picked at random, so a flurry never repeats); a hit is a wet slice with
a short zap and a body thud; the heavy release is a bigger, lower whoosh with
a rising crackle. All names start with "glb_" (audio/mix.tres puts the swish
and the heavy on "weapon", the hit on "impact" and the flick on "handling").

    python tools/gen_audio.py glow_blade
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from weapon_punch import HANDLE, HIT, punched


def _air(d, f0, f1, gain=1.0, seed=1, width=0.55):
    """A swish: noise swept through a band-pass from f0 to f1, swelling in the middle."""
    rnd = np.random.default_rng(seed)
    n = int(SR * d)
    t = np.arange(n) / SR
    w = rnd.standard_normal(n)
    centre = f0 * (f1 / f0) ** (t / d)
    out = np.zeros(n)
    block = 256
    for i in range(0, n, block):
        c = float(centre[min(i + block // 2, n - 1)])
        seg = band(w[max(0, i - block):i + block * 2], c, c * width)
        a = i - max(0, i - block)
        out[i:i + block] = seg[a:a + min(block, n - i)]
    shape = np.sin(np.pi * np.clip(t / d, 0.0, 1.0)) ** 1.6
    return out * shape * gain


def _zap(d, f0, f1, gain=1.0):
    """A thin electric edge: a fast saw sweep, buzzed and bright."""
    return sweep(f0, f1, d, "saw", curve=0.7) * env(d, 0.002, d * 0.8, power=1.5) * gain


def _ring(f, d, gain=1.0):
    """A small steel ring: two inharmonic partials."""
    return (tone(f, d) + tone(f * 2.76, d) * 0.4 + tone(f * 5.4, d) * 0.12) * env(d, 0.001, d, power=2.6) * gain


@punched(HANDLE)
def glb_flick():
    """The blade flicks open: a spring snap, the lock's click, a steel ring and a neon zap."""
    d = 0.4
    out = silence(d)
    place(out, _air(0.07, 1800, 5200, 0.4, seed=3), 0.0, 1.0)
    place(out, click(0.01, 3400, 0.9), 0.06, 1.0)
    place(out, clunk(420, 0.05, 0.35), 0.062, 1.0)
    place(out, _ring(2350, 0.2, 0.16), 0.064, 1.0)
    place(out, _zap(0.12, 900, 2600, 0.16), 0.07, 1.0)
    return filt(out, low=9000, high=120)


def glb_swish():
    """One light swing: a quick air swish rising in pitch with a thin electric edge."""
    d = 0.24
    out = _air(d, 700, 2600, 0.9, seed=11)
    place(out, _zap(0.14, 520, 1500, 0.07), 0.05, 1.0)
    return filt(out, low=8000, high=160)


def glb_swish_b():
    """The second take: a shade lower and longer."""
    d = 0.27
    out = _air(d, 560, 2200, 0.9, seed=12)
    place(out, _zap(0.15, 440, 1300, 0.07), 0.06, 1.0)
    return filt(out, low=7500, high=150)


def glb_swish_c():
    """The third take: brighter and snappier."""
    d = 0.21
    out = _air(d, 900, 3200, 0.85, seed=13)
    place(out, _zap(0.12, 640, 1900, 0.08), 0.04, 1.0)
    return filt(out, low=8500, high=180)


@punched(HIT)
def glb_hit():
    """The blade connects: a wet slice, a short neon zap and a body thud."""
    d = 0.3
    rnd = np.random.default_rng(21)
    n = int(SR * d)
    slice_ = band(rnd.standard_normal(n), 2100, 2600) * env(d, 0.001, 0.07, power=1.8) * 0.7
    out = slice_
    place(out, clunk(130, 0.12, 0.8), 0.0, 1.0)
    place(out, _zap(0.08, 1800, 700, 0.2), 0.005, 1.0)
    place(out, filt(rnd.standard_normal(n), low=900, high=120) * env(d, 0.004, 0.12, power=1.5) * 0.35, 0.01, 1.0)
    return filt(out, low=8000)


def glb_heavy():
    """The heavy swing let go: a big low whoosh with a rising crackle of neon."""
    d = 0.5
    out = _air(d, 260, 1700, 1.0, seed=31, width=0.7)
    place(out, _zap(0.3, 260, 1400, 0.12), 0.06, 1.0)
    rnd = np.random.default_rng(32)
    crackle = (rnd.random(int(SR * 0.3)) > 0.985).astype(float) * rnd.standard_normal(int(SR * 0.3))
    place(out, filt(crackle, high=2500) * env(0.3, 0.05, 0.3, power=1.2) * 0.5, 0.1, 1.0)
    return filt(out, low=7500, high=70)


SOUNDS = [glb_flick, glb_swish, glb_swish_b, glb_swish_c, glb_hit, glb_heavy]

VARIANTS = [(glb_hit, (0.92, 1.08))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
