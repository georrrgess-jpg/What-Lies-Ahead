"""The Toxic Ripsaw: a slime-pellet shotgun with a chain saw. Punchy and
wet, with the top end rolled off so the saw buzzes instead of whining. All
names start with "weap_ripsaw_" (audio/mix.tres: fire on "weapon", the saw's
bite and the splat on "impact", the rest on "handling").

    python tools/gen_audio.py ripsaw
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump
from weapon_punch import HEAVY, HIT, punched


def _engine(d, f0, f1, curve=1.0, grit=0.5):
    """Two-stroke putter: a pulse train whose rate glides f0 -> f1, a little
    chain rattle on top, low-passed so it growls instead of whining."""
    t = t_axis(d)
    k = (t / max(d, 1e-9)) ** curve
    freq = f0 + (f1 - f0) * k
    phase = 2 * np.pi * np.cumsum(freq) / SR
    pulse = np.clip(np.sin(phase) * 3.0, -1, 1) * 0.5 + osc(phase * 2, "saw") * 0.22 + np.sin(phase * 0.5) * 0.25
    rattle = band(noise(d), 1500, 500) * (0.5 + 0.5 * np.sin(phase * 3)) * grit
    return filt(pulse + rattle, low=2200, high=55)


def _squelch(d, f0=520, f1=160, gain=1.0):
    """Wet slap: a falling bubbly tone in a burst of low noise."""
    t = t_axis(d)
    wobble = 1.0 + 0.25 * np.sin(2 * np.pi * 38 * t)
    glide = sweep(f0, f1, d, "sine", 0.5) * wobble * env(d, 0.002, d * 0.8, power=1.8) * 0.6
    slap = filt(noise(d), low=1800, high=180) * env(d, 0.001, d * 0.35, power=2.2) * 0.9
    return (glide + slap) * gain


def _bubbles(d, count, seed, lo=500, hi=1300):
    """A run of small rising bloops (slime glugging)."""
    r = np.random.default_rng(seed)
    out = silence(d)
    for _ in range(count):
        at = r.uniform(0, d - 0.06)
        f = r.uniform(lo, hi)
        b = sweep(f, f * 1.7, 0.05, "sine", 0.6) * env(0.05, 0.004, 0.05, power=1.5)
        place(out, b, at, r.uniform(0.25, 0.5))
    return out


# ---------------------------------------------------------------------------
# Shotgun
# ---------------------------------------------------------------------------

@punched(HEAVY)
def weap_ripsaw_fire():
    """A slime blast: deep thump, a wet splat and a gloopy tail."""
    d = 0.5
    thump = _sub_thump(170, 40, d, 0.22) * 1.5
    crack = filt(noise(d), high=700, low=4200) * env(d, 0.0006, 0.035, power=1.8) * 0.9
    splat = _squelch(0.32, 640, 170, 0.9)
    out = thump + crack
    place(out, splat, 0.01, 1.0)
    place(out, _bubbles(0.3, 5, 3, 420, 900), 0.12, 0.4)
    return crush(filt(out, low=6500), 1.5)


@punched(HIT)
def weap_ripsaw_splat():
    """The slime splatting onto a zombie and the floor."""
    d = 0.28
    out = _squelch(d, 420, 140, 1.0)
    place(out, _bubbles(0.2, 3, 5, 600, 1100), 0.05, 0.35)
    return filt(out, low=5000)


# ---------------------------------------------------------------------------
# Saw
# ---------------------------------------------------------------------------

def weap_ripsaw_idle():
    """Seamless running saw: the engine at speed and the chain whirring."""
    d = 1.0
    eng = _engine(d + 0.12, 58, 58, grit=0.45)
    whirr = band(noise(d + 0.12), 900, 300) * (0.6 + 0.4 * np.sin(2 * np.pi * 116 * t_axis(d + 0.12))) * 0.35
    return loopable(eng * 0.9 + whirr, 0.12)


def weap_ripsaw_rev():
    """Revving up: the engine climbs from a putter to a roar."""
    d = 0.42
    eng = _engine(d, 22, 60, curve=0.6, grit=0.55) * env(d, 0.02, d, sustain=0.75, power=0.8)
    out = eng.copy()
    place(out, click(0.02, 1200), 0.0, 0.4)
    return filt(out, low=3000)


@punched(HIT, room_gain=0.05)
def weap_ripsaw_bite():
    """The chain biting in: a grinding rasp with a wet chew."""
    d = 0.34
    t = t_axis(d)
    grind = band(noise(d), 1100, 450) * (0.55 + 0.45 * np.sin(2 * np.pi * 64 * t)) * env(d, 0.004, d, power=1.3) * 1.1
    growl = _engine(d, 46, 40, grit=0.3) * env(d, 0.004, d, power=1.2) * 0.55
    chew = _squelch(0.2, 360, 150, 0.6)
    out = grind + growl
    place(out, chew, 0.02, 1.0)
    return filt(out, low=3800)


def weap_ripsaw_sputter():
    """Out of slime: the engine coughs and dies."""
    d = 0.7
    out = silence(d)
    for i, (at, f) in enumerate(((0.0, 40), (0.13, 30), (0.28, 22), (0.45, 16))):
        cough = _engine(0.12, f, f * 0.8, grit=0.4) * env(0.12, 0.004, 0.12, power=1.6)
        place(out, cough, at, 1.0 - i * 0.2)
    place(out, filt(noise(0.2), low=900) * env(0.2, 0.01, 0.2, power=2.0), 0.48, 0.3)
    return filt(out, low=2600)


def weap_ripsaw_start():
    """Raised: the pull-cord zips out, the engine coughs, catches and revs once."""
    d = 0.85
    out = silence(d)
    zip_ = band(noise(0.2), 1400, 600) * np.linspace(0.3, 1.0, int(SR * 0.2)) * env(0.2, 0.01, 0.2, sustain=0.4, power=1.0)
    place(out, zip_, 0.14, 0.6)
    place(out, clunk(260, 0.06), 0.14, 0.4)
    place(out, _engine(0.1, 28, 24, grit=0.4) * env(0.1, 0.003, 0.1, power=1.6), 0.36, 0.8)
    catch = _engine(0.42, 30, 64, curve=0.5, grit=0.5) * env(0.42, 0.01, 0.42, sustain=0.0, power=1.1)
    place(out, catch, 0.44, 1.0)
    return filt(out, low=3200)


# ---------------------------------------------------------------------------
# Reload
# ---------------------------------------------------------------------------

def weap_ripsaw_reload():
    """Rack latch, the new rack printing in and seating (the glugs and the pump are their own sounds)."""
    out = silence(1.5)
    place(out, click(0.025, 1600), 0.05, 0.5)                                       # latch
    place(out, clunk(240, 0.08), 0.42, 0.7)                                         # rack pops off
    place(out, band(noise(0.3), 2000, 700) * env(0.3, 0.06, power=1.0), 0.97, 0.25)  # new rack prints in
    place(out, clunk(300, 0.1), 1.36, 0.9)                                          # seats
    return filt(out, low=7000)


def weap_ripsaw_glug():
    """Slime sloshing in a canister: a wet gulp and bubbles."""
    d = 0.4
    gulp = sweep(260, 120, 0.16, "sine", 0.6) * env(0.16, 0.004, 0.16, power=1.6) * 0.7
    out = silence(d)
    place(out, gulp, 0.0, 1.0)
    place(out, _bubbles(0.36, 7, 9, 380, 900), 0.03, 0.8)
    place(out, filt(noise(0.12), low=1200, high=200) * env(0.12, 0.003, power=2.0), 0.0, 0.4)
    return filt(out, low=5000)


def weap_ripsaw_pump():
    """The under-pump racked back and forward."""
    out = silence(0.3)
    place(out, clunk(200, 0.08), 0.0, 0.9)
    place(out, band(noise(0.06), 1600, 600) * env(0.06, 0.004, power=1.5), 0.02, 0.4)
    place(out, clunk(280, 0.09), 0.13, 1.0)
    return filt(out, low=7000)


SOUNDS = [
    weap_ripsaw_fire, weap_ripsaw_splat, weap_ripsaw_rev, weap_ripsaw_bite, weap_ripsaw_sputter,
    weap_ripsaw_start, weap_ripsaw_reload, weap_ripsaw_glug, weap_ripsaw_pump,
]

VARIANTS = [(weap_ripsaw_fire, (0.95, 1.05)), (weap_ripsaw_bite, (0.93, 1.08))]

LOOPS = {"weap_ripsaw_idle": weap_ripsaw_idle}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
