"""The Jester's Jinglestar (jinglestar), the melee-slot court jester's flail:
gold chain and jingle bells. Swings are a whooshing rope of air with the
bells shivering on top, hits a hollow brassy clonk with a bell spray over a
body thud, the heavy slam a deep clang and a bell crash; the chain rattles
when it jerks, the whirl hums and jingles, the Encore climbs in little bell
steps and its shockwave is a bright jingle burst; the rare inspect plays a
short court fanfare. All names start with "jingle_" (audio/mix.tres: the
whooshes on "weapon", the hits, slam and shockwave on "impact", the rest on
"handling").

    python tools/gen_audio.py jinglestar
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import CUE, HANDLE, HEAVY, HIT, MID, punched


def _n(d, seed):
    """Seeded white noise (each sound draws its own, so edits never re-roll another)."""
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(SR * d))


def _whoosh(d, f0, f1, width=0.6, seed=3, curve=1.0):
    """A rush of air: band-passed noise gliding f0 -> f1, swelling then falling."""
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


def _ting(f, d=0.22, gain=1.0):
    """One small jingle bell: a bright, slightly inharmonic ping with a fast shimmer."""
    body = tone(f, d) * 0.6 + tone(f * 2.41, d) * 0.22 + tone(f * 3.9, d) * 0.08
    wob = 1.0 + 0.25 * np.sin(2 * np.pi * 23.0 * t_axis(d))
    return body * wob * env(d, 0.0008, d * 0.55, power=2.2) * gain


def _jingles(d, count, seed, lo=1250, hi=2050, gain=1.0, spread=1.0):
    """A shake of jingle bells: pings scattered over the first `spread` of d."""
    r = np.random.default_rng(seed)
    out = silence(d)
    for _ in range(count):
        at = r.uniform(0.0, max(0.001, (d - 0.15) * spread))
        place(out, _ting(r.uniform(lo, hi), 0.14, r.uniform(0.2, 0.5)), at, 1.0)
    return out * gain


def _links(d, count, seed, gain=1.0):
    """Chain links knocking: short metallic ticks in a loose run."""
    r = np.random.default_rng(seed)
    out = silence(d)
    for i in range(count):
        at = (i / count) * (d - 0.03) + r.uniform(-0.006, 0.006)
        f = r.uniform(2600, 3600)
        tick = (tone(f, 0.03) * 0.5 + band(r.uniform(-1, 1, int(SR * 0.03)), f * 0.8, 900) * 0.5) * env(0.03, 0.0003, 0.012, power=2.5)
        place(out, tick, max(0.0, at), r.uniform(0.3, 0.7))
    return out * gain


def _clonk(pitch=1.0, gain=1.0, seed=1):
    """The star-ball landing: a hollow brassy clonk (a dented bell)."""
    d = 0.3
    body = (tone(420 * pitch, d) * 0.55 + tone(1010 * pitch, d) * 0.3 + tone(1730 * pitch, d) * 0.15) * env(d, 0.0005, 0.11, power=2.2)
    hit = band(_n(d, seed), 1500 * pitch, 900) * env(d, 0.0003, 0.01, power=2.5) * 1.3
    return (body + hit) * gain


def _note(semis, d, gain=1.0):
    """A brass-ish note (A4 + semis): a bright saw with a soft attack and a little vibrato."""
    f = 440.0 * 2 ** (semis / 12.0)
    x = tone(f, d, "saw", vibrato=0.006, vib_rate=5.5) * 0.5 + tone(f * 2, d, "tri") * 0.2
    return filt(x, low=3200) * env(d, 0.02, d, power=0.6, release=0.06) * gain


@punched(MID, thump_gain=0.2, snap_gain=0.0)
def jingle_whoosh():
    """A swing: the head whips round on its chain, the bells shivering on top."""
    d = 0.42
    out = _whoosh(d, 320, 1100, width=0.65, seed=11, curve=0.8)
    place(out, _jingles(0.4, 7, 12, gain=0.35), 0.03, 1.0)
    place(out, _links(0.12, 4, 13, gain=0.25), 0.0, 1.0)
    return filt(out, low=6500, high=110)


@punched(HEAVY, thump_gain=0.25, snap_gain=0.0)
def jingle_heavy():
    """The heavy let go: a big low whoosh down out of the whirl."""
    d = 0.55
    out = _whoosh(d, 180, 700, width=0.7, seed=21, curve=0.7) * 1.1
    place(out, _jingles(0.5, 6, 22, lo=1000, hi=1700, gain=0.3), 0.05, 1.0)
    return filt(out, low=5500, high=80)


@punched(HIT, thump_gain=0.5)
def jingle_hit():
    """The head lands: a brassy clonk over a meaty thud, the bells spraying."""
    d = 0.5
    out = _sub_thump(165, 60, d, 0.08)
    place(out, _clonk(1.0, 1.4, seed=31), 0.0, 1.0)
    place(out, filt(_n(0.14, 32), low=1300, high=120) * env(0.14, 0.001, 0.06, power=2.0) * 0.6, 0.002, 1.0)
    place(out, _jingles(0.45, 9, 33, gain=0.45), 0.01, 1.0)
    return filt(out, low=7000)


@punched(HEAVY, thump_gain=0.5)
def jingle_slam():
    """The charged slam: a deep clang, a bell crash and the chain slapping down."""
    d = 0.9
    out = _sub_thump(130, 42, d, 0.16) * 1.15
    place(out, _clonk(0.62, 1.3, seed=41), 0.0, 1.0)
    place(out, _clonk(0.93, 0.5, seed=42), 0.004, 1.0)
    place(out, _jingles(0.85, 16, 43, lo=1100, hi=2100, gain=0.6, spread=0.6), 0.01, 1.0)
    place(out, _links(0.2, 6, 44, gain=0.4), 0.05, 1.0)
    return filt(out, low=7000)


@punched(HANDLE)
def jingle_rattle():
    """The chain jerks: a run of link knocks and a bell's shiver."""
    d = 0.22
    out = _links(0.16, 6, 51, gain=0.8)
    place(out, _jingles(0.2, 3, 52, gain=0.3), 0.01, 1.0)
    return filt(out, low=7000, high=300)


@punched(HANDLE)
def jingle_jingle():
    """A shake of the bells (the inspect's flourishes)."""
    d = 0.5
    out = _jingles(d, 12, 61, gain=0.8)
    return filt(out, low=7000, high=300)


@punched(HANDLE)
def jingle_whirl():
    """The wind-up whirl: a hum rising under a pulsing rope of air and bells."""
    d = 0.9
    t = t_axis(d)
    air = _whoosh(d, 250, 650, width=0.6, seed=71) * (0.6 + 0.4 * np.sin(2 * np.pi * (6 + 6 * t / d) * t))
    hum = sweep(150, 260, d, "tri") * env(d, 0.25, d, power=0.7, release=0.1) * 0.25
    out = air * 0.7 + hum
    place(out, _jingles(0.85, 10, 72, gain=0.35), 0.05, 1.0)
    return filt(out, low=5500, high=90)


@punched(CUE)
def jingle_step():
    """An Encore step: one bright bell (the game pitches each step up)."""
    d = 0.3
    out = _ting(1568, d, 1.0) + _ting(2093, d, 0.35)
    return filt(out, low=8000, high=300)


@punched(CUE)
def jingle_fizzle():
    """The Encore ends: two bells falling and a little sigh of the chain."""
    d = 0.45
    out = silence(d)
    place(out, _ting(1318, 0.25, 0.7), 0.0, 1.0)
    place(out, _ting(988, 0.3, 0.6), 0.1, 1.0)
    place(out, _links(0.12, 3, 81, gain=0.3), 0.18, 1.0)
    return filt(out, low=7000, high=250)


@punched(HIT, thump_gain=0.3)
def jingle_encore():
    """The full Encore's shockwave: a bright jingle burst over a round boom."""
    d = 0.8
    out = _sub_thump(120, 50, d, 0.12) * 0.8
    for i, f in enumerate((1047, 1319, 1568, 2093)):
        place(out, _ting(f, 0.4, 0.7), i * 0.035, 1.0)
    place(out, _jingles(0.75, 18, 91, lo=1300, hi=2300, gain=0.6, spread=0.5), 0.02, 1.0)
    return filt(out, low=8000, high=60)


@punched(HANDLE)
def jingle_catch():
    """The toss lands in the palm: a slap, a link rattle and a bell."""
    d = 0.3
    out = band(_n(d, 101), 900, 600) * env(d, 0.0005, 0.03, power=2.0) * 0.8
    place(out, clunk(200, 0.08, 0.5), 0.0, 1.0)
    place(out, _links(0.12, 4, 102, gain=0.5), 0.01, 1.0)
    place(out, _ting(1480, 0.2, 0.4), 0.03, 1.0)
    return filt(out, low=6500, high=120)


@punched(HANDLE)
def jingle_equip():
    """Drawn: the chain slithers out, the head drops and the bells settle."""
    d = 0.6
    out = _links(0.3, 9, 111, gain=0.6)
    place(out, _clonk(1.4, 0.25, seed=112), 0.3, 1.0)
    place(out, _jingles(0.3, 7, 113, gain=0.5), 0.3, 1.0)
    return filt(out, low=6500, high=150)


@punched(CUE)
def jingle_fanfare():
    """The rare inspect: a short court fanfare (ta-ta-taaa, ta-TAAA) with bells."""
    d = 1.6
    out = silence(d)
    # A major: E-E-A... C#-E.
    for at, semis, length in ((0.0, 7, 0.12), (0.14, 7, 0.12), (0.28, 12, 0.36), (0.7, 16, 0.14), (0.86, 19, 0.6)):
        place(out, _note(semis, length + 0.08, 0.7), at, 1.0)
        place(out, _note(semis - 12, length + 0.08, 0.3), at, 1.0)
    place(out, _jingles(1.2, 20, 121, gain=0.4, spread=0.9), 0.25, 1.0)
    place(out, _ting(1760, 0.6, 0.6), 0.86, 1.0)
    return filt(out, low=7000, high=120)


SOUNDS = [jingle_whoosh, jingle_heavy, jingle_hit, jingle_slam, jingle_rattle, jingle_jingle, jingle_whirl, jingle_step,
          jingle_fizzle, jingle_encore, jingle_catch, jingle_equip, jingle_fanfare]

VARIANTS = [(jingle_whoosh, (0.92, 1.08)), (jingle_hit, (0.92, 1.08)), (jingle_rattle, (0.9, 1.1))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
