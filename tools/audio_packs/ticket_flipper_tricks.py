"""The Ticket Flipper's inspect tricks (scripts/weapons/views/ticket_flipper_tricks.gd),
added to the tflip_ pack (tools/audio_packs/ticket_flipper.py): the latch snapping
home over the bite handle, and the JACKPOT finale's sparkle: a bright arcade
chime run with a shimmer of ticket confetti. Names start with "tflip_"
(audio/mix.tres: on "handling").

    python tools/gen_audio.py ticket_flipper_tricks
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from weapon_punch import HANDLE, punched


def _n(d, seed):
    """Seeded white noise (each sound draws its own, so edits never re-roll another)."""
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(SR * d))


def _tick(gain, seed):
    """The bail's hard bright tick."""
    d = 0.03
    return band(_n(d, seed), 4200, 1400) * env(d, 0.0002, 0.008, power=2.8) * gain


@punched(HANDLE)
def tflip_latch():
    """The latch bail snaps over the bite handle: a hard bright tick, a small spring ring."""
    d = 0.12
    out = silence(d)
    place(out, _tick(2.6, 91), 0.0, 1.0)
    ring_ = band(_n(0.06, 93), 2900, 700) * env(0.06, 0.0004, 0.03, power=2.4) * 0.5
    place(out, ring_, 0.001, 1.0)
    place(out, sweep(700, 380, 0.03, "tri") * env(0.03, 0.0005, 0.02, power=2.0) * 0.35, 0.0, 1.0)
    place(out, band(_n(0.02, 92), 3000, 900) * env(0.02, 0.0002, 0.006, power=2.6) * 0.9, 0.018, 1.0)
    return filt(out, low=9000, high=200)


@punched(HANDLE)
def tflip_jackpot():
    """JACKPOT!: the latch locks, a rising sparkle of chimes and a flutter of ticket confetti."""
    d = 1.1
    out = silence(d)
    place(out, _tick(1.8, 96), 0.0, 1.0)
    for i, f in enumerate((1568, 1976, 2349, 3136)):
        # Short glassy pings, each roughened by a little band noise so no one tone rings on.
        bell = (tone(f, 0.22) * 0.4 + tone(f * 2.76, 0.22) * 0.1) * env(0.22, 0.002, 0.07, power=2.6)
        bell += band(_n(0.22, 110 + i), f, f * 0.3) * env(0.22, 0.002, 0.08, power=2.0) * 0.3
        place(out, bell * 0.1, 0.03 + i * 0.07, 1.0)
    place(out, band(_n(0.7, 95), 7000, 3000) * env(0.7, 0.05, 0.6, power=1.6) * 0.04, 0.2, 1.0)
    for k in range(9):
        place(out, band(_n(0.03, 100 + k), 2200 + 300 * (k % 3), 1200) * env(0.03, 0.001, 0.02, power=2.2) * 0.12, 0.25 + k * 0.06, 1.0)
    return filt(out, low=11000, high=180)


SOUNDS = [tflip_latch, tflip_jackpot]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
