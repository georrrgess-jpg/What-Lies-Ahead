"""The Jack Pot (update 13 secondary): a candy-striped mortar pistol that lobs
jack-in-the-box mines. Toy-box sounds: a hollow spring 'thoonk' per shot, a
wooden clack as a box lands, a music-box ditty while it winds up and a ding
when it arms, then the big cartoon BOING, a glove's thwack and a confetti
poof. The reload's comb plucks one music-box note at a time (the game picks
the pitch). All names start with "jp_" (audio/mix.tres puts the shot on
"weapon", the pop and the punch on "impact", the rest on "handling").

    python tools/gen_audio.py jack_pot
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump

C5 = 523.25


def _music_note(freq, d=0.5, gain=1.0):
    """One music-box tine: a bright pluck with the comb's metallic overtones."""
    tine = additive(freq, d, [(1, 1.0, d * 0.7), (3.0, 0.32, d * 0.25), (5.4, 0.12, d * 0.12), (8.9, 0.05, d * 0.06)])
    return tine * adsr(d, 0.001, d, 1.0, 0.02) * gain


def _spring(f0, f1, d, wobble=34.0, depth=0.22, gain=1.0):
    """A cartoon spring: a glide with a fast wobble (the coil ringing)."""
    t = t_axis(d)
    freq = (f0 + (f1 - f0) * (t / d) ** 0.6) * (1.0 + depth * np.sin(2 * np.pi * wobble * t) * np.exp(-3.0 * t / d))
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return (np.sin(phase) * 0.7 + np.sin(2 * phase) * 0.25) * env(d, 0.003, d, power=1.4, release=d * 0.25) * gain


def jp_fire():
    """The shot: a hollow mortar 'thoonk', the launch spring's twang and a ratchet click."""
    d = 0.45
    out = _sub_thump(170, 70, d, 0.09) * 1.3
    place(out, band(noise(0.06), 900, 700) * env(0.06, 0.0005, 0.05, power=2.0) * 0.8, 0.0, 1.0)
    place(out, _spring(260, 520, 0.3, wobble=28.0, depth=0.25, gain=0.35), 0.01, 1.0)
    place(out, click(0.02, 2200, 0.5), 0.0, 1.0)
    return crush(filt(out, low=7000), 1.3)


def jp_land():
    """A box lands: a wooden clack and a little springy bounce."""
    d = 0.3
    out = clunk(330, 0.08, 0.9)
    place(out, click(0.02, 1500, 0.6), 0.0, 1.0)
    place(out, _spring(420, 300, 0.16, wobble=40.0, depth=0.15, gain=0.25), 0.03, 1.0)
    return filt(np.concatenate([out, silence(max(0.0, d - len(out) / SR))]), low=7000)


def jp_tune():
    """Winding up: a ratchet under a quick music-box ditty."""
    d = 0.85
    out = silence(d)
    for i in range(10):
        place(out, click(0.012, 3200, 0.22), i * 0.075, 1.0)
    notes = [0, 4, 7, 4, 9, 7]
    for i, n in enumerate(notes):
        place(out, _music_note(C5 * 2 ** (n / 12), 0.35, 0.5), 0.02 + i * 0.12, 1.0)
    return filt(out, low=9000)


def jp_armed():
    """Armed: a bright two-tone ding."""
    out = silence(0.5)
    place(out, _music_note(C5 * 2, 0.45, 0.6), 0.0, 1.0)
    place(out, _music_note(C5 * 2 * 1.5, 0.4, 0.45), 0.06, 1.0)
    return filt(out, low=9000)


def jp_boing():
    """The pop: the lid bursts, a big cartoon BOING, a slide-whistle rise and confetti crackle."""
    d = 0.9
    out = _sub_thump(140, 60, d, 0.06) * 0.9
    place(out, clunk(260, 0.07, 0.7), 0.0, 1.0)
    place(out, _spring(110, 230, 0.75, wobble=18.0, depth=0.35, gain=0.8), 0.01, 1.0)
    place(out, sweep(700, 1700, 0.22, "sine", 0.7) * env(0.22, 0.02, 0.22, power=1.0) * 0.18, 0.02, 1.0)
    t = t_axis(0.4)
    crackle = band(noise(0.4), 5000, 3000) * (np.random.default_rng(13).random(len(t)) > 0.97) * 2.0
    place(out, crackle * env(0.4, 0.01, 0.4, power=1.5), 0.05, 0.5)
    return crush(filt(out, low=8500), 1.2)


def jp_punch():
    """The glove lands: a padded thwack."""
    d = 0.25
    out = _sub_thump(120, 50, d, 0.05) * 1.4
    place(out, band(noise(0.05), 1100, 900) * env(0.05, 0.0005, 0.04, power=2.2) * 1.2, 0.0, 1.0)
    place(out, band(noise(0.03), 3200, 1600) * env(0.03, 0.0005, 0.02, power=2.0) * 0.4, 0.0, 1.0)
    return crush(filt(out, low=7000), 1.5)


def jp_poof():
    """The spent box vanishes: a soft puff and a sparkle."""
    d = 0.35
    out = band(noise(d), 1400, 1200) * env(d, 0.01, d, power=2.0) * 0.5
    place(out, _music_note(C5 * 4, 0.2, 0.18), 0.03, 1.0)
    return filt(out, low=8000)


def jp_pluck():
    """One music-box note for the reload's comb (pitched by the game)."""
    return filt(_music_note(C5 * 2, 0.5, 0.8), low=9500)


def jp_clunk():
    """A box clicks home into the cup."""
    out = clunk(240, 0.1, 0.9)
    place(out, click(0.02, 2400, 0.6), 0.0, 1.0)
    return filt(out, low=7500)


def jp_tease():
    """The loaded box's lid jumps up a crack: a tiny boing."""
    return filt(_spring(320, 560, 0.22, wobble=36.0, depth=0.22, gain=0.5), low=8000)


def jp_grab():
    """The hand takes the crank: a rattle of the handle."""
    out = silence(0.2)
    place(out, click(0.02, 1800, 0.6), 0.0, 1.0)
    place(out, click(0.015, 2600, 0.4), 0.05, 1.0)
    return filt(out, low=8000)


def jp_reload():
    """The reload's start: the gun turns over with a clack."""
    out = silence(0.3)
    place(out, clunk(200, 0.09, 0.6), 0.0, 1.0)
    return filt(out, low=7000)


def jp_equip():
    """Raised: the crank ratchets and the box gives a muffled boing inside."""
    out = silence(0.45)
    for i in range(3):
        place(out, click(0.014, 2800, 0.35), i * 0.06, 1.0)
    place(out, _spring(240, 360, 0.2, wobble=30.0, depth=0.2, gain=0.3), 0.2, 1.0)
    return filt(out, low=6500)


SOUNDS = [jp_fire, jp_land, jp_tune, jp_armed, jp_boing, jp_punch, jp_poof, jp_pluck, jp_clunk, jp_tease, jp_grab, jp_reload, jp_equip]

VARIANTS = [(jp_fire, (0.95, 1.05)), (jp_boing, (0.92, 1.08)), (jp_punch, (0.9, 1.1))]

LOOPS = {}
# `from gen_audio import *` also imports gen_audio's MUSIC folder path; this pack has no music.
MUSIC = {}
