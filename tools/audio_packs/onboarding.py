"""Onboarding pack: Boot Camp's carnival-gallery sounds and BOLT's voice blips
(scripts/onboarding/). Bright, short and in the UI pack's key.

    python3 tools/gen_audio.py onboarding
"""
import gen_audio
from gen_audio import *  # noqa: F401,F403


def rand(lo, hi, n=None):
    return gen_audio.rng.uniform(lo, hi, n)


def soft(freq, seconds, shape="sine", decay=None, gain=1.0):
    return tone(freq, seconds, shape) * env(seconds, 0.004, decay or seconds * 0.9) * gain


def onb_blip():
    """BOLT talking: a tiny square chirp with a robotic wobble (one per word)."""
    d = 0.07
    f = note(rand(14, 22))
    return filt(tone(f, d, "square", vibrato=0.04, vib_rate=38.0) * env(d, 0.003, d * 0.8), low=3800) * 0.45


def onb_pop():
    """A balloon popping: a bright crack with a rubbery tail."""
    d = 0.22
    crack = filt(noise(d), high=1800) * env(d, 0.001, 0.05, power=1.5)
    snap = sweep(900, 260, 0.08, "tri") * env(0.08, 0.001, 0.07)
    out = silence(d)
    place(out, crack, 0.0, 0.9)
    place(out, snap, 0.0, 0.5)
    return out


def onb_target_up():
    """A gallery target flipping up: wooden clack and a spring."""
    out = silence(0.22)
    place(out, clunk(260, 0.07, 0.8), 0.0)
    place(out, click(0.015, 3200, 0.5), 0.0)
    place(out, sweep(500, 1500, 0.16, "sine", 0.6) * env(0.16, 0.005, 0.15) * 0.25, 0.02)
    return out


def onb_ding():
    """A gallery bell: the target was hit."""
    out = silence(0.7)
    for semi, gain in ((24, 0.55), (36, 0.22), (43, 0.1)):
        place(out, soft(note(semi), 0.65, "sine", 0.6), 0.0, gain)
    place(out, click(0.01, 4200, 0.5), 0.0)
    return out


def onb_buzz():
    """Not that one: a soft carnival buzzer."""
    d = 0.24
    return filt(tone(note(-17), d, "saw") * env(d, 0.005, d, power=0.6), low=1600) * 0.4


def onb_step():
    """A step done: three quick rising notes and a sparkle."""
    out = silence(0.5)
    for i, semi in enumerate((12, 16, 19, 24)):
        place(out, soft(note(semi), 0.18, "square", 0.15), i * 0.05, 0.28)
    place(out, soft(note(31), 0.3, "sine", 0.28), 0.2, 0.25)
    return filt(out, low=6500)


def onb_section():
    """A new section of the course: a short marquee fanfare."""
    out = silence(0.7)
    for i, semi in enumerate((7, 12, 16)):
        place(out, soft(note(semi), 0.14, "saw", 0.12), i * 0.09, 0.22)
    place(out, soft(note(19), 0.42, "saw", 0.4), 0.27, 0.26)
    return filt(out, low=4200)


def onb_complete():
    """Graduation: a carnival fanfare with a cymbal swell."""
    out = silence(1.8)
    melody = ((12, 0.0), (16, 0.12), (19, 0.24), (24, 0.36), (19, 0.52), (24, 0.64))
    for semi, at in melody:
        place(out, soft(note(semi), 0.3, "saw", 0.26), at, 0.22)
        place(out, soft(note(semi - 12), 0.3, "square", 0.26), at, 0.12)
    place(out, soft(note(28), 0.9, "saw", 0.85), 0.8, 0.24)
    place(out, soft(note(24), 0.9, "saw", 0.85), 0.8, 0.2)
    swell = filt(noise(1.0), high=6000) * env(1.0, 0.5, 0.5, power=1.0) * 0.18
    place(out, swell, 0.6)
    return filt(out, low=7000)


SOUNDS = [onb_blip, onb_pop, onb_target_up, onb_ding, onb_buzz, onb_step, onb_section, onb_complete]
VARIANTS = [(onb_blip, (0.9, 1.1))]

MUSIC = {}
LOOPS = {}
