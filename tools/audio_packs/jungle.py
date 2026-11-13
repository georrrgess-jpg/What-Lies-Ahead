"""Jungle Expedition (World 7) sound pack: Lost Temple music and ambience, the
Lost Explorer and Overgrown voices, the vine lash, brambles and the monsoon.

    python tools/gen_audio.py jungle

    audio/music/lost_temple_loop.ogg         34 s adventure loop at 112 BPM, two sections:
                                             log drums, congas and shakers under a marimba
                                             ostinato, then a wooden-flute melody
    audio/music/lost_temple_final.ogg        its final-wave variant (toms, claps, a galloping
                                             bass and the flute over both sections)
    audio/music/jungle_ambience.ogg          birds and insects, a distant waterfall, frogs
    audio/sfx/jungle_*.wav                   enemy, vine, bramble and thunder sounds
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def marimba(freq, seconds, gain=1.0):
    """Wooden bar: fundamental, the 4th partial and a mallet tick, quick decay."""
    t = t_axis(seconds)
    body = np.sin(2 * np.pi * freq * t) * np.exp(-t * 6.0) + np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-t * 22.0) * 0.35
    tick = band(noise(0.015), freq * 6.0, freq * 3.0) * env(0.015, 0.0002, power=2.0)
    out = body * env(seconds, 0.002, seconds, power=0.6)
    place(out, tick, 0.0, 0.3)
    return out * gain


def log_drum(freq, seconds=0.35, gain=1.0):
    """Slit drum: a hollow knock with a short pitch drop."""
    t = t_axis(seconds)
    f = freq * (1.0 + 0.25 * np.exp(-t * 40.0))
    body = osc(2 * np.pi * np.cumsum(f) / SR, "sine") + osc(2 * np.pi * np.cumsum(f * 2.02) / SR, "sine") * 0.3
    return body * env(seconds, 0.001, seconds, power=2.6) * gain


def conga(freq, slap=False, gain=1.0):
    d = 0.22
    t = t_axis(d)
    f = freq * (1.0 + 0.4 * np.exp(-t * 60.0))
    body = osc(2 * np.pi * np.cumsum(f) / SR, "sine") * env(d, 0.001, d, power=2.8)
    hit = band(noise(0.03), 2400 if slap else 1200, 900) * env(0.03, 0.0005, power=2.0)
    out = body
    place(out, hit, 0.0, 0.9 if slap else 0.4)
    return out * gain


def shaker(gain=1.0):
    d = 0.07
    return band(noise(d), 7500, 3500) * env(d, 0.012, d, power=1.6) * gain


def flute(freq, seconds, gain=1.0):
    """Wooden flute: a breathy sine with a slow vibrato that grows in."""
    t = t_axis(seconds)
    vib = 1.0 + 0.012 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.35, 0, 1)
    ph = 2 * np.pi * np.cumsum(freq * vib) / SR
    voice = np.sin(ph) + np.sin(2 * ph) * 0.18 + np.sin(3 * ph) * 0.06
    breath = band(noise(seconds), freq * 2.0, freq) * 0.12
    return (voice + breath) * env(seconds, 0.05, seconds * 1.4, power=0.5, release=min(0.12, seconds * 0.3)) * gain


def wood_bass(freq, seconds):
    t = t_axis(seconds)
    x = np.sin(2 * np.pi * freq * t) + osc(2 * np.pi * freq * t, "tri") * 0.5
    return filt(x, low=700) * env(seconds, 0.004, seconds * 0.9, power=1.3)


def pad(semis, seconds):
    out = sum(tone(note(s), seconds, "tri", 0.003, 4.0 + i * 0.6) for i, s in enumerate(semis))
    return filt(out, low=1800) * env(seconds, seconds * 0.3, seconds * 1.6, power=0.6, release=seconds * 0.2)


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

def lost_temple_loop(intense=False):
    """112 BPM, D dorian. Section A (bars 1-8): Dm - C - Dm - Am under a marimba
    ostinato, log drums and congas. Section B (bars 9-16): Bb - C - Dm - A with a
    wooden-flute melody, then it turns back to A.

    intense=True is the final-wave variant (lost_temple_final): toms on every
    beat, claps, shakers on sixteenths, risers into each section, a galloping
    bass and the flute over section A too. Same tempo and length, so the game
    cross-fades between the two in time."""
    bpm = 112.0
    beat = 60.0 / bpm
    bars = 16
    d = bars * 4 * beat
    left, right = silence(d + 2.0), silence(d + 2.0)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    kick = sweep(120, 45, 0.22, "sine", 0.45) * env(0.22, 0.001, power=2.2)
    place(kick, kick_click(0.25), 0.0)
    hand_clap, crash = clap(), cymbal()
    chords_a = [(-7, (0, 3, 7)), (-9, (0, 4, 7)), (-7, (0, 3, 7)), (-12, (0, 3, 7))]     # Dm C Dm Am (roots from A4)
    chords_b = [(-11, (0, 4, 7)), (-9, (0, 4, 7)), (-7, (0, 3, 7)), (-12, (0, 4, 7))]    # Bb C Dm A
    for bar in range(bars):
        section_b = bar >= 8
        root, triad = (chords_b if section_b else chords_a)[bar % 4]
        t0 = bar * 4 * beat
        fill = bar % 4 == 3
        if intense and bar % 8 == 0:
            both(crash, t0, 0.1, 0.4)
        if intense and bar % 8 == 7:
            both(riser(2 * beat), t0 + 2 * beat, 0.08, 0.6)
        # Kick on 1 and the "and" of 2; log drums answer.
        both(kick, t0, 0.55)
        both(kick, t0 + 1.5 * beat, 0.4)
        both(kick, t0 + 2.5 * beat, 0.3 if not intense else 0.45)
        if intense:
            both(kick, t0 + 3 * beat, 0.4)
        for i, (at, semis) in enumerate(((0.75, -17), (1.0, -12), (2.0, -14), (3.25, -17), (3.5, -12))):
            both(log_drum(note(root + semis + 7 - 12 * (i % 2)) * 0.5, 0.3), t0 + at * beat, 0.24, 0.3 + 0.4 * (i % 2))
        # Congas: a tumbao pattern.
        for at, slap, f in ((0.5, False, 210), (1.5, True, 300), (2.0, False, 210), (2.5, False, 300), (3.5, True, 300), (3.75, False, 210)):
            both(conga(f, slap), t0 + at * beat, 0.22, 0.65 if f > 250 else 0.4)
        # Shakers on eighths (sixteenths when intense).
        steps = 16 if intense else 8
        for e in range(steps):
            both(shaker(), t0 + e * 4 * beat / steps, 0.09 if e % 2 else 0.06, 0.7)
        if intense:
            both(hand_clap, t0 + beat, 0.14, 0.45)
            both(hand_clap, t0 + 3 * beat, 0.14, 0.55)
            for b in range(4):
                both(log_drum(note(-29 + (b % 2) * 5), 0.4, 1.2), t0 + b * beat, 0.16, 0.5)
        if fill:
            for s in range(6):
                both(conga(260 - s * 15, s % 2 == 0), t0 + (2.5 + s * 0.25) * beat, 0.2 + 0.03 * s, 0.3 + 0.08 * s)
        # Bass.
        bass_steps = [(0.0, 0, 0.9), (1.5, 0, 0.4), (2.0, 7, 0.4), (2.5, 12, 0.4), (3.5, 10 if not triad[1] == 4 else 7, 0.4)]
        if intense:
            bass_steps = [(e * 0.5, (0, 0, 7, 0, 12, 7, 10, 7)[e], 0.42) for e in range(8)]
        for at, semis, ln in bass_steps:
            both(wood_bass(note(root - 24 + semis), ln * beat * 1.6), t0 + at * beat, 0.55)
        # Marimba ostinato.
        pattern = [0, 2, 1, 2, 0, 2, 1, 2] if not section_b else [0, 1, 2, 1, 0, 2, 1, 0]
        for e in range(8):
            semis = root + 12 + triad[pattern[e]] + (12 if e in (2, 6) else 0)
            both(marimba(note(semis), beat * 0.6), t0 + e * beat * 0.5, 0.22, 0.3 + 0.4 * (e % 2))
        both(pad([root + s for s in triad], 4 * beat), t0, 0.12)
        # Flute: section B melody; the intense loop plays an answer over section A too.
        phrases_b = [
            [(14, 0.0, 1.5), (12, 1.5, 0.5), (10, 2.0, 1.0), (9, 3.0, 1.0)],
            [(7, 0.0, 1.0), (9, 1.0, 1.0), (10, 2.0, 1.0), (12, 3.0, 1.0)],
            [(14, 0.0, 1.0), (17, 1.0, 1.0), (15, 2.0, 0.5), (14, 2.5, 1.5)],
            [(12, 0.0, 1.0), (11, 1.0, 1.0), (7, 2.0, 2.0)],
        ]
        phrases_a = [
            [(5, 0.0, 1.0), (7, 1.0, 0.5), (8, 1.5, 0.5), (12, 2.0, 2.0)],
            [(10, 0.0, 1.5), (8, 1.5, 0.5), (7, 2.0, 2.0)],
            [(5, 0.0, 1.0), (8, 1.0, 1.0), (12, 2.0, 1.0), (15, 3.0, 1.0)],
            [(14, 0.0, 2.0), (12, 2.0, 2.0)],
        ]
        if section_b or intense:
            for semis, at, length in (phrases_b if section_b else phrases_a)[bar % 4]:
                both(flute(note(semis - 7 + 12), length * beat * 1.1), t0 + at * beat, 0.22 if section_b else 0.17, 0.55)
    return fold_loop(left, right, d)


def _birds(n, count, lo, hi, gain):
    out = np.zeros(n)
    for _ in range(count):
        at = int(rng.uniform(0, n - SR))
        d = rng.uniform(0.06, 0.25)
        f0 = rng.uniform(lo, hi)
        chirps = int(rng.integers(1, 4))
        for c in range(chirps):
            s = sweep(f0 * rng.uniform(0.9, 1.1), f0 * rng.uniform(1.2, 1.6), d, "sine") * env(d, 0.01, d, power=1.5)
            start = at + int(c * d * SR * 1.3)
            out[start:start + len(s)] += s * gain * rng.uniform(0.5, 1.0)
    return out


def jungle_ambience():
    """16 s seamless bed: insects, bird calls, frogs and the distant waterfall."""
    d = 16.0
    n = int(SR * (d + 1.0))
    t = np.arange(n) / SR
    falls_l = filt(rng.uniform(-1, 1, n), low=900, high=60) * 0.5
    falls_r = filt(rng.uniform(-1, 1, n), low=900, high=60) * 0.35
    insects = band(rng.uniform(-1, 1, n), 5200, 900) * (0.55 + 0.45 * np.sin(2 * np.pi * 7.0 * t) ** 2) * 0.22
    cicada = band(rng.uniform(-1, 1, n), 3900, 300) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 6.0)) ** 3 * 0.35
    left = falls_l + insects + cicada * 0.6 + _birds(n, 18, 1800, 3600, 0.16)
    right = falls_r + np.roll(insects, int(SR * 0.3)) + cicada + _birds(n, 15, 2200, 4200, 0.14)
    # Frogs: low wooden croaks.
    for _ in range(12):
        at = rng.uniform(0.5, d - 1.0)
        f = rng.uniform(140, 220)
        croak = groan(f, 0.18, glide=0.2, formants=((600, 180), (1300, 260)), rasp=0.2, wobble=0.0) * 0.25
        place(left if rng.uniform() < 0.5 else right, croak, at, 0.5)
    # A distant macaw-ish squawk now and then.
    for at in (4.0, 11.5):
        sq = groan(620, 0.35, glide=0.3, formants=((1400, 300), (2600, 400)), rasp=0.4, wobble=0.1)
        place(left, sq, at, 0.08)
        place(right, sq, at + 0.03, 0.05)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


# ---------------------------------------------------------------------------
# Lost Explorer
# ---------------------------------------------------------------------------

def jungle_explorer_yell_1():
    return groan(240, 0.55, glide=0.5, formants=((850, 200), (1700, 300)), rasp=0.35, wobble=0.12)


def jungle_explorer_yell_2():
    return groan(300, 0.45, glide=-0.3, formants=((700, 180), (2000, 340)), rasp=0.45, wobble=0.09)


def jungle_explorer_hup():
    """Leap telegraph: a rustle of leaves and a rising 'hup!'."""
    d = 0.7
    rustle = band(noise(d), 3400, 2200) * env(d, 0.25, d, power=0.8, release=0.08)
    out = rustle * 0.8
    place(out, groan(280, 0.3, glide=0.7, formants=((900, 200), (2100, 300)), rasp=0.3, wobble=0.05), 0.35, 0.9)
    return out


def jungle_leap_land():
    """Landing: a thump, snapped twigs and a leafy swish."""
    d = 0.5
    thump = sweep(150, 48, 0.28, "sine", 0.5) * env(0.28, 0.001, 0.25, power=2.0)
    swish = band(noise(d), 2800, 1800) * env(d, 0.002, 0.35, power=1.4)
    out = swish * 0.7
    place(out, thump, 0.0, 1.3)
    for _ in range(4):
        place(out, click(0.02, rng.uniform(1500, 3000)), rng.uniform(0.0, 0.12), 0.5)
    return out


# ---------------------------------------------------------------------------
# Overgrown, vines and brambles
# ---------------------------------------------------------------------------

def jungle_overgrown_groan_1():
    """A deep, leafy groan with a creak of wood in it."""
    d = 1.0
    g = groan(72, d, glide=-0.2, formants=((380, 110), (800, 160)), rasp=0.5, wobble=0.05)
    creak = sweep(420, 300, d, "saw") * env(d, 0.2, d, power=1.0)
    return g + band(creak, 900, 200) * 0.25


def jungle_overgrown_groan_2():
    return groan(64, 1.1, glide=0.15, formants=((340, 100), (720, 150)), rasp=0.55, wobble=0.07)


def jungle_vine_creak():
    """The lash telegraph: fists into the ground, a long wooden creak and a
    rising rustle of vines creeping out."""
    d = 1.15
    t = t_axis(d)
    f = 150 * (1 + 0.3 * t / d) * (1 + 0.1 * np.sin(2 * np.pi * 3.0 * t))
    creak = osc(2 * np.pi * np.cumsum(f) / SR, "saw")
    creak = (band(creak, 800, 200) + band(creak, 1700, 300) * 0.5) * env(d, 0.15, d, power=0.8, release=0.1)
    rustle = band(noise(d), 3000, 2000) * env(d, d * 0.8, d, power=0.5, release=0.05)
    out = creak * 0.9 + rustle * 0.6
    place(out, clunk(80, 0.2, 1.4), 0.0, 1.0)
    return out


def jungle_vine_burst():
    """Thorny vines burst out of the ground: a crack, a whip and a leafy crash."""
    d = 0.8
    out = silence(d)
    place(out, sweep(160, 45, 0.3, "sine", 0.5) * env(0.3, 0.001, power=2.0), 0.0, 1.2)
    whip = band(noise(0.18), 3500, 2500) * env(0.18, 0.002, 0.12, power=1.4)
    place(out, whip, 0.02, 1.2)
    place(out, band(noise(0.6), 2200, 1800) * env(0.6, 0.01, 0.5, power=1.2), 0.05, 0.6)
    for _ in range(6):
        place(out, click(0.02, rng.uniform(1200, 2600)), rng.uniform(0.0, 0.2), 0.5)
    return out


def jungle_snare():
    """Player caught in the brambles: a tangle of leaves and a tug."""
    d = 0.6
    rustle = band(noise(d), 2600, 1600) * env(d, 0.02, 0.5, power=1.0)
    tug = sweep(300, 180, 0.25, "saw") * env(0.25, 0.01, power=1.5)
    out = rustle
    place(out, band(tug, 700, 200), 0.05, 0.6)
    return out


def jungle_thunder():
    """Monsoon lightning: a sharp crack rolling into a long rumble."""
    d = 2.4
    out = silence(d)
    place(out, filt(noise(0.12), high=1200) * env(0.12, 0.0005, power=1.6) * 1.2, 0.0, 1.0)
    rumble = filt(noise(d), low=220) * env(d, 0.05, d, power=1.0, release=0.8)
    rumble *= 0.7 + 0.3 * np.sin(2 * np.pi * 2.3 * t_axis(d)) ** 2
    place(out, rumble, 0.05, 2.0)
    return out


SOUNDS = [
    jungle_explorer_yell_1, jungle_explorer_yell_2, jungle_explorer_hup, jungle_leap_land,
    jungle_overgrown_groan_1, jungle_overgrown_groan_2, jungle_vine_creak, jungle_vine_burst, jungle_snare, jungle_thunder,
]

VARIANTS = [(jungle_leap_land, (0.9, 1.1))]

LOOPS = {}

MUSIC = {
    "lost_temple_loop": lost_temple_loop,
    "lost_temple_final": lambda: lost_temple_loop(intense=True),
    "jungle_ambience": jungle_ambience,
}
