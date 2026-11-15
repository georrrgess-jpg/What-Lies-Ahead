"""The Markdown Marker (markdown_marker), a price-tag labeller pistol: a crisp
plastic lever clack and a paper thwip per tag, a sticker slap on a hit, and
the Clearance Pop: a cash-register ka-ching over a confetti pop and a spill
of coins. Bright and toy-like, the top end rolled off so it never turns
shrill under rapid fire. All names start with "mdm_" (audio/mix.tres puts
the shot on "weapon", the stick and the pop on "impact", the rest on
"handling").

    python tools/gen_audio.py markdown_marker
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump


def _clack(freq, d=0.06, gain=1.0):
    """A hard plastic lever snapping shut: a hollow knock and a tick."""
    knock = (tone(freq, d, "tri") + tone(freq * 2.7, d) * 0.3) * env(d, 0.0005, d * 0.5, power=2.6)
    tick = filt(noise(d), high=1800, low=7000) * env(d, 0.0003, 0.012, power=2.0) * 0.7
    return (knock + tick) * gain


def _thwip(d=0.12, f0=2600, f1=900, gain=1.0):
    """Paper whipping off the roll: a falling band of noise."""
    out = silence(d)
    hiss = noise(d)
    # Three overlapping bands, later ones lower: the pitch falls as the tag leaves.
    for k, c in enumerate((f0, (f0 + f1) * 0.5, f1)):
        seg = band(hiss, c, 700) * env(d, 0.002 + k * 0.01, d * (0.5 + 0.2 * k), power=1.4)
        out += seg * (1.0 - 0.25 * k)
    return out * gain


def _bell(freq, d, gain=1.0):
    """A small cash-register bell: bright inharmonic partials, a long ring."""
    out = silence(d)
    for ratio, g in ((1.0, 1.0), (2.76, 0.45), (5.4, 0.2), (8.9, 0.08)):
        out += tone(freq * ratio, d) * env(d, 0.0008, d / ratio ** 0.4, power=1.6) * g
    return out * gain


def _coins(d, count=7, gain=1.0, seed=3):
    """Coins spilling: little metallic tinks at random moments."""
    rng = np.random.default_rng(seed)
    out = silence(d)
    for _ in range(count):
        f = rng.uniform(2600, 4200)
        at = rng.uniform(0.0, d - 0.1)
        place(out, _bell(f, 0.09, 0.22), at, 1.0)
        place(out, click(0.01, f * 0.6, 0.15), at, 1.0)
    return out * gain


def mdm_fire():
    """One tag: the lever clacks up, the tag thwips out of the nozzle with a soft pop."""
    d = 0.3
    out = _sub_thump(190, 95, d, 0.04) * 0.6
    place(out, _clack(520, 0.07, 0.9), 0.0, 1.0)
    place(out, _thwip(0.13, 3000, 1100, 0.6), 0.008, 1.0)
    place(out, blip(1400, 0.05, "sine", gain=0.25), 0.0, 1.0)
    return crush(filt(out, low=7000), 1.2)


def mdm_stick():
    """A tag slapping onto a zombie: a wet-ish sticker smack with a tiny chirp."""
    d = 0.18
    smack = filt(noise(d), high=300, low=3500) * env(d, 0.0005, 0.03, power=2.4) * 0.9
    chirp = sweep(1500, 2100, 0.05, "sine") * env(0.05, 0.002, 0.05, power=1.5) * 0.3
    out = smack + _sub_thump(160, 90, d, 0.03) * 0.5
    place(out, chirp, 0.012, 1.0)
    return filt(out, low=6500)


def mdm_pop():
    """Clearance Pop: a confetti pop, the register's ka-ching and a spill of coins."""
    d = 0.9
    out = silence(d)
    pop = filt(noise(0.12), high=200, low=5000) * env(0.12, 0.0005, 0.05, power=2.2) + _sub_thump(150, 60, 0.12, 0.06)
    place(out, pop, 0.0, 1.0)
    place(out, _clack(380, 0.08, 0.6), 0.03, 1.0)              # the drawer "ka"
    place(out, _bell(1568, 0.6, 0.55), 0.07, 1.0)               # the "ching"
    place(out, _bell(2093, 0.5, 0.3), 0.07, 1.0)
    place(out, _coins(0.6, 8, 0.8), 0.14, 1.0)
    return filt(out, low=8000)


def mdm_equip():
    """Raised: a quick lever double-clack and the drum ratchets a notch."""
    out = silence(0.32)
    place(out, _clack(480, 0.06, 0.6), 0.0, 1.0)
    place(out, _clack(560, 0.06, 0.7), 0.1, 1.0)
    for i in range(3):
        place(out, click(0.012, 2200 + 300 * i, 0.35), 0.18 + i * 0.03, 1.0)
    return filt(out, low=7500)


def mdm_reload():
    """End of the roll (1.6 s): the roll pops out, the receipt flutters away, the drawer
    slides out with a ka-ching, a new roll spins in with a ratchet, the drawer snaps shut."""
    out = silence(1.6)
    place(out, clunk(300, 0.08, 0.6), 0.17, 1.0)                                    # roll pops out
    t = t_axis(0.42)
    flutter = band(noise(0.42), 1600, 900) * (0.55 + 0.45 * np.sin(2 * np.pi * 22 * t)) * env(0.42, 0.04, 0.42, power=1.1)
    place(out, flutter, 0.37, 0.35)                                                  # receipt flutters
    place(out, filt(noise(0.12), high=600, low=3000) * env(0.12, 0.01, 0.12, power=1.2), 0.48, 0.4)  # drawer slides
    place(out, _clack(400, 0.07, 0.6), 0.6, 1.0)                                    # "ka"
    place(out, _bell(1568, 0.5, 0.45), 0.62, 1.0)                                   # "ching"
    place(out, _coins(0.3, 4, 0.5, seed=5), 0.66, 1.0)
    for i in range(9):                                                              # roll spins in
        place(out, click(0.012, 1800 + 120 * i, 0.3 - 0.02 * i), 0.69 + i * 0.04 * (1.0 + i * 0.06), 1.0)
    place(out, band(noise(0.25), 2400, 1200) * env(0.25, 0.05, 0.25, power=1.0) * 0.2, 0.68, 1.0)
    place(out, clunk(260, 0.1, 0.8), 1.07, 1.0)                                     # roll seats
    place(out, _clack(540, 0.07, 0.9), 1.22, 1.0)                                   # drawer snaps shut
    place(out, _thwip(0.1, 2400, 1200, 0.3), 1.25, 1.0)                             # first tag out
    return filt(out, low=8000)


SOUNDS = [mdm_fire, mdm_stick, mdm_pop, mdm_equip, mdm_reload]

VARIANTS = [(mdm_fire, (0.95, 1.05)), (mdm_stick, (0.92, 1.08)), (mdm_pop, (0.96, 1.04))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
