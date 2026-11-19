"""The Ticket Flipper (ticket_flipper), the melee-slot butterfly knife:
bright, quick and clicky. The balisong's handles clack on their gold pins,
the latch ticks, the blade whips through the air with a thin, airy swish
(never a whistle) and bites with a short slice and a papery "tk"; the heavy
lunge-slash is a rising rush with a flip clack before the cut. All names
start with "tflip_" (audio/mix.tres: the swishes and the lunge on "weapon",
the hit on "impact", the rest on "handling").

    python tools/gen_audio.py ticket_flipper
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import FAST, HANDLE, HIT, MID, punched


def _n(d, seed):
    """Seeded white noise (each sound draws its own, so edits never re-roll another)."""
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(SR * d))


def _clack(gain=1.0, pitch=1.0, seed=1):
    """A handle meeting its pin: a bright metal tick on a small hollow knock."""
    d = 0.05
    tick = band(_n(d, seed), 3100 * pitch, 900) * env(d, 0.0003, 0.012, power=2.6) * 3.0
    ring_ = (tone(1850 * pitch, d) * 0.3 + tone(2730 * pitch, d) * 0.12) * env(d, 0.0005, 0.03, power=2.2)
    knock = sweep(520 * pitch, 260 * pitch, d, "tri") * env(d, 0.0008, 0.02, power=2.0) * 0.5
    return (tick + ring_ + knock) * gain


def _air(d, f0, f1, width=0.45, seed=3, curve=1.0):
    """Moving air: noise in a band whose centre glides f0 -> f1, swelling then falling."""
    w = _n(d, seed)
    out = np.zeros_like(w)
    steps = 12
    seg = len(w) // steps
    for i in range(steps):
        k = (i / (steps - 1)) ** curve
        c = f0 + (f1 - f0) * k
        part = band(w, c, c * width)
        a, b = i * seg, len(w) if i == steps - 1 else (i + 1) * seg
        out[a:b] = part[a:b]
    shape = np.sin(np.pi * np.clip(np.arange(len(w)) / len(w), 0, 1)) ** 1.6
    return filt(out, low=7000) * shape


def _paper(d, centre=2200, gain=1.0, seed=5):
    return band(_n(d, seed), centre, centre * 0.6) * env(d, 0.0008, d * 0.45, power=2.2) * gain


@punched(HANDLE)
def tflip_flip():
    """One flip: the free handle swings round and clacks home, the latch ticks."""
    d = 0.22
    out = silence(d)
    place(out, _air(0.12, 900, 2200, seed=11) * 0.35, 0.0, 1.0)
    place(out, _clack(1.0, 1.0, seed=12), 0.1, 1.0)
    place(out, _clack(0.45, 1.25, seed=13), 0.145, 1.0)
    return filt(out, low=7500, high=150)


@punched(HANDLE)
def tflip_open():
    """The equip flourish: three quick flips, the latch snaps shut and a ticket flutters."""
    d = 0.75
    out = silence(d)
    for i, at in enumerate((0.0, 0.16, 0.3)):
        place(out, _air(0.1, 800 + i * 200, 2100 + i * 200, seed=20 + i) * 0.3, at, 1.0)
        place(out, _clack(0.9, 1.0 + 0.06 * i, seed=24 + i), at + 0.085, 1.0)
    place(out, _clack(1.1, 0.8, seed=30), 0.47, 1.0)
    place(out, click(0.015, 1500, 0.5), 0.475, 1.0)
    place(out, _paper(0.06, 2000, 0.35, seed=31), 0.5, 1.0)
    place(out, (tone(1175, 0.3, "tri") * 0.25 + tone(2350, 0.3) * 0.05) * env(0.3, 0.002, 0.3, power=1.8), 0.49, 0.5)
    return filt(out, low=7500, high=150)


@punched(FAST, thump_gain=0.12, snap_gain=0.0)
def tflip_swish():
    """A light slash: a quick, thin swish of air with a tiny blade shimmer."""
    d = 0.2
    out = _air(d, 1100, 3000, width=0.5, seed=41, curve=0.7) * 0.9
    place(out, _air(0.12, 500, 900, width=0.6, seed=42) * 0.4, 0.03, 1.0)
    return filt(out, low=6500, high=180)


@punched(HIT)
def tflip_hit():
    """The blade bites: a short slice, a soft wet thud and a papery tick."""
    d = 0.3
    out = _sub_thump(190, 80, d, 0.05) * 0.8
    slice_ = band(_n(0.08, 51), 2600, 1300) * env(0.08, 0.0006, 0.05, power=2.0) * 0.8
    place(out, slice_, 0.0, 1.0)
    place(out, filt(_n(0.12, 52), low=1400, high=160) * env(0.12, 0.001, 0.06, power=2.0) * 0.7, 0.004, 1.0)
    place(out, _paper(0.04, 2300, 0.35, seed=53), 0.02, 1.0)
    return filt(out, low=7000)


@punched(MID, thump_gain=0.3)
def tflip_lunge():
    """The heavy lunge-slash: a rising rush of air, a flip clack and a long cut."""
    d = 0.6
    out = silence(d)
    place(out, _air(0.32, 400, 1500, width=0.55, seed=61, curve=1.4) * 0.6, 0.0, 1.0)
    place(out, _clack(0.8, 0.9, seed=62), 0.16, 1.0)
    place(out, _air(0.26, 2600, 900, width=0.5, seed=63, curve=0.6) * 0.95, 0.24, 1.0)
    place(out, sweep(700, 300, 0.2, "tri", curve=0.7) * env(0.2, 0.002, 0.18, power=1.8) * 0.18, 0.25, 1.0)
    return filt(out, low=6500, high=120)


@punched(HANDLE)
def tflip_twirl():
    """The inspect routine's aerial: a fast whirr of air and a run of pin clicks, a catch."""
    d = 0.9
    out = silence(d)
    place(out, _air(0.6, 700, 1800, width=0.4, seed=71) * 0.35, 0.0, 1.0)
    for i in range(7):
        place(out, _clack(0.35 + 0.05 * (i % 3), 1.1 + 0.04 * (i % 2), seed=72 + i), 0.05 + i * 0.075, 1.0)
    place(out, _clack(1.0, 0.85, seed=80), 0.68, 1.0)
    place(out, click(0.015, 1500, 0.45), 0.685, 1.0)
    return filt(out, low=7500, high=150)


SOUNDS = [tflip_flip, tflip_open, tflip_swish, tflip_hit, tflip_lunge, tflip_twirl]

VARIANTS = [(tflip_flip, (0.92, 1.08)), (tflip_swish, (0.9, 1.1)), (tflip_hit, (0.93, 1.07))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
