"""Gear pack (update 24): the sound layers of the six new cosmetic kill effects.

    python tools/gen_audio.py gear
"""
import gen_audio
from gen_audio import *  # noqa: F401,F403


def rand(lo, hi, n=None):
    """Random numbers from the generator gen_audio reseeds for each pack."""
    return gen_audio.rng.uniform(lo, hi, n)


def chime(freq, seconds, gain=1.0):
    """A soft struck chime (two partials, quick decay)."""
    out = tone(freq, seconds) * env(seconds, 0.001, seconds * 0.7, power=1.6)
    out += tone(freq * 2.76, seconds) * env(seconds, 0.001, seconds * 0.3, power=1.6) * 0.35
    return out * gain


def pop(seconds=0.05, low=2500, high=300, gain=1.0):
    """A short filtered noise pop."""
    return filt(noise(seconds), low=low, high=high) * env(seconds, 0.0005, seconds, power=3.0) * gain


def sparkle(seconds, centre=7000, density=0.993, gain=1.0):
    """Sparse glittery ticks."""
    n = int(SR * seconds)
    ticks = (rand(0, 1, n) > density).astype(float) * rand(-1, 1, n)
    return filt(ticks, low=centre * 1.6, high=centre * 0.5) * env(seconds, 0.01, seconds, power=1.2) * gain * 3.0


def cos_kill_magic_trick():
    """A soft smoke whoosh, then a ta-da: a bright major arpeggio and glitter."""
    d = 1.3
    out = silence(d)
    t = t_axis(0.35)
    puff = filt(noise(0.35), low=1800, high=200) * np.sin(np.pi * t / 0.35) ** 2
    place(out, puff * 0.5, 0.0)
    for i, s in enumerate((0, 4, 7, 12)):
        place(out, filt(chime(note(s + 3), 0.6, gain=0.24), low=6000), 0.22 + i * 0.05)
    place(out, sparkle(0.7, 8000, gain=0.4), 0.3)
    return out


def cos_kill_gumballs():
    """A crank clunk, then gumballs clattering and bouncing on a hard floor."""
    d = 1.4
    out = silence(d)
    place(out, filt(tone(90, 0.12, "tri") * env(0.12, 0.002, 0.1, power=2.0), low=900) * 0.5, 0.0)
    place(out, pop(0.04, 1500, 150, 0.6), 0.0)
    for i in range(14):
        at = 0.12 + i * rand(0.04, 0.09)
        if at < d - 0.1:
            place(out, filt(chime(rand(1400, 2600), 0.08, gain=0.18), low=6000, high=600), at)
            place(out, pop(0.02, 4000, 900, 0.18), at)
    return out


def cos_kill_fireflies():
    """A soft breathy swell with twinkling chimes drifting up."""
    d = 1.6
    out = silence(d)
    t = t_axis(1.2)
    breath = filt(noise(1.2), low=2400, high=500) * np.sin(np.pi * t / 1.2) ** 2
    place(out, breath * 0.22, 0.0)
    for i, s in enumerate((7, 11, 14, 19, 23, 26)):
        place(out, filt(chime(note(s + 3), 0.5, gain=0.12), low=7000), 0.08 + i * 0.17 + rand(0.0, 0.04))
    place(out, sparkle(1.0, 9000, 0.996, gain=0.25), 0.2)
    return out


def cos_kill_card_burst():
    """A deck riffle: a burst of quick card flicks fanning out, then a flutter."""
    d = 0.9
    out = silence(d)
    for i in range(16):
        at = i * rand(0.012, 0.02)
        place(out, pop(0.018, rand(2600, 3600), rand(700, 1100), 0.4), at)
    t = t_axis(0.5)
    flutter = filt(noise(0.5), low=2600, high=500) * (0.6 + 0.4 * np.sin(2 * np.pi * 26 * t)) * env(0.5, 0.02, 0.5, power=1.6)
    place(out, flutter * 0.25, 0.25)
    return out


def cos_kill_ring_toss():
    """Plastic hoops whirring out, then ringing clatters as they land."""
    d = 1.3
    out = silence(d)
    t = t_axis(0.4)
    whirr = filt(noise(0.4), low=3000, high=600) * (0.5 + 0.5 * np.sin(2 * np.pi * 18 * t)) * np.sin(np.pi * t / 0.4)
    place(out, whirr * 0.3, 0.0)
    for i in range(6):
        at = 0.45 + i * rand(0.05, 0.1)
        place(out, filt(chime(rand(700, 1100), 0.25, gain=0.2), low=4000, high=300), at)
        place(out, pop(0.03, 3000, 400, 0.2), at)
    return out


def cos_kill_soda_fizz():
    """A cap pop, a foamy rush of fizz and a few late bubbles."""
    d = 1.4
    out = silence(d)
    place(out, pop(0.03, 3500, 500, 0.6), 0.0)
    place(out, filt(tone(520, 0.06, "sine") * env(0.06, 0.001, 0.05, power=2.0), low=3000) * 0.3, 0.0)
    t = t_axis(1.0)
    rush = filt(noise(1.0), low=3800, high=700) * env(1.0, 0.02, 1.0, power=1.3)
    place(out, rush * 0.3, 0.02)
    for i in range(10):
        at = 0.1 + i * rand(0.06, 0.12)
        if at < d - 0.1:
            place(out, filt(sweep(rand(600, 900), rand(1400, 2000), 0.04, "sine") * env(0.04, 0.002, 0.04, power=2.0), low=4000) * 0.12, at)
    return out


SOUNDS = [cos_kill_magic_trick, cos_kill_gumballs, cos_kill_fireflies, cos_kill_card_burst, cos_kill_ring_toss, cos_kill_soda_fizz]

# This pack has no music or loops.
MUSIC = {}
LOOPS = {}
