"""Fright Fair (World 11) sound pack: Ghost Train music and ambience, the
Bedsheet Ghost, Pumpkin Head and Ringmaster Rictus voices and tells, the
pumpkin bomb and the Lights Out twist.

    python tools/gen_audio.py fright

    audio/music/ghost_train_loop.ogg    ~33 s spooky-fun midnight waltz (3/4, 132 BPM,
                                        D minor): a fairground pipe organ, a bony
                                        xylophone, pizzicato bass, a theremin line,
                                        rattles and a woodblock
    audio/music/ghost_train_final.ogg   its final-wave variant (timpani on every
                                        downbeat, a rattle drive, organ stabs and a
                                        ghostly choir pad); same tempo and length
    audio/music/fright_ambience.ogg     16 s: night wind, crickets, a distant
                                        out-of-tune carousel organ, creaks, an owl
                                        and the clink of a chain
    audio/sfx/fright_*.wav              enemy, pumpkin-bomb and power sounds
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def organ(freq, seconds, gain=1.0):
    """Fairground pipe organ: stacked sine ranks (8', 4', 2 2/3', 2') with a
    slow tremulant and a breathy chiff on the attack."""
    t = t_axis(seconds)
    trem = 1.0 + 0.08 * np.sin(2 * np.pi * 5.2 * t)
    x = sum(np.sin(2 * np.pi * freq * r * t) * a for r, a in ((1.0, 1.0), (2.0, 0.5), (3.0, 0.28), (4.0, 0.18), (6.0, 0.06)))
    chiff = band(noise(seconds), freq * 3, freq) * np.exp(-t * 30) * 0.3
    return filt(x * trem + chiff, low=5000) * env(seconds, 0.03, seconds, power=0.35, release=0.07) * gain


def xylo(freq, seconds=0.5):
    """Xylophone of bones: a hard knock and quickly decaying wooden partials."""
    t = t_axis(seconds)
    x = sum(np.sin(2 * np.pi * freq * r * t) * a * np.exp(-t * d) for r, a, d in ((1.0, 1.0, 11.0), (3.93, 0.45, 22.0), (9.2, 0.15, 40.0)))
    knock = band(noise(0.02), 2400, 1600) * env(0.02, 0.0005, 0.02, power=2.0)
    out = x * env(seconds, 0.001, seconds, power=1.0)
    place(out, knock, 0.0, 0.5)
    return out


def pizz(freq, seconds):
    """Pizzicato bass: a plucked string that thumps and dies away."""
    t = t_axis(seconds)
    x = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(4 * np.pi * freq * t) + 0.12 * np.sin(6 * np.pi * freq * t)
    return audible_bass(x * np.exp(-t * 5.5), 0.35) * env(seconds, 0.004, seconds, power=1.2)


def theremin(freq, seconds, gain=1.0):
    """Theremin: a pure tone with a wide, slow vibrato that swells in."""
    t = t_axis(seconds)
    depth = 0.012 * np.clip(t / 0.3, 0.0, 1.0)
    f = freq * (1.0 + depth * np.sin(2 * np.pi * 5.5 * t))
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.12 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    return x * env(seconds, 0.08, seconds, power=0.4, release=0.1) * gain


def rattle(seconds=0.12):
    """A dry rattle of bones (shaker-like)."""
    out = silence(seconds)
    for k in range(5):
        place(out, band(noise(0.015), 3800, 2200) * env(0.015, 0.001, power=1.6), k * seconds / 6, 0.9 - k * 0.12)
    return out


def woodblock(freq=900, seconds=0.12):
    t = t_axis(seconds)
    return (np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 2.7 * t)) * np.exp(-t * 45)


def timpani(freq, seconds=0.9):
    t = t_axis(seconds)
    body = np.sin(2 * np.pi * freq * t * (1.0 + 0.04 * np.exp(-t * 20))) + 0.3 * np.sin(2 * np.pi * freq * 1.5 * t)
    return (body + filt(noise(seconds), low=500) * 0.4 * np.exp(-t * 30)) * env(seconds, 0.002, seconds * 0.8, power=1.6)


def choir(semis, seconds, gain=1.0):
    """An 'ooh' pad: detuned saws through two vowel formants."""
    out = silence(seconds)
    t = t_axis(seconds)
    for s in semis:
        f = note(s)
        for det in (0.996, 1.004):
            saw = 2.0 * ((f * det * t) % 1.0) - 1.0
            out += (band(saw, 400, 220) + band(saw, 850, 300) * 0.5) * 0.25
    return out * env(seconds, 0.25, seconds, power=0.4, release=0.3) * gain


def night_wind(n, shift=0.0, slow=9.0):
    t = np.arange(n) / SR
    lo = filt(rng.uniform(-1, 1, n), low=420, high=50)
    hi = filt(rng.uniform(-1, 1, n), low=2200, high=600)
    gust = (0.5 + 0.5 * np.sin(2 * np.pi * t / slow + shift)) ** 2
    whistle = (0.5 + 0.5 * np.sin(2 * np.pi * t / (slow * 0.7) + 1.1 + shift)) ** 5
    return lo * (0.3 + 0.7 * gust) + hi * whistle * 0.3


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

def ghost_train_loop(intense=False):
    """132 BPM waltz, 24 bars (~32.7 s) in D minor: Dm - A7 - Dm - Gm, then
    Bb - A7 - Dm - Dm, three times: the organ takes the tune first, then the
    theremin (an octave down), then organ and xylophone together. Pizzicato
    oom on 1, organ chords on 2 and 3, rattles and a woodblock. intense=True
    (ghost_train_final) adds timpani, a rattle drive, organ stabs and a choir
    pad: same tempo and length, so the game cross-fades in time."""
    bpm = 132.0
    beat = 60.0 / bpm
    bars = 24
    d = bars * 3 * beat
    left, right = silence(d + 2.0), silence(d + 2.0)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    prog = [(-7, (0, 3, 7)), (-12, (0, 4, 7, 10)), (-7, (0, 3, 7)), (-14, (0, 3, 7)),
            (-11, (0, 4, 7)), (-12, (0, 4, 7, 10)), (-7, (0, 3, 7)), (-7, (0, 3, 7))]
    tune = [
        [(0, 0, 1), (5, 1, 1), (8, 2, 1)],
        [(7, 0, 2), (4, 2, 1)],
        [(5, 0, 1), (8, 1, 1), (12, 2, 1)],
        [(10, 0, 3)],
        [(13, 0, 1), (12, 1, 1), (10, 2, 1)],
        [(8, 0, 1), (7, 1, 1), (4, 2, 1)],
        [(5, 0, 2), (0, 2, 1)],
        [(5, 0, 3)],
    ]
    kick = sweep(100, 42, 0.25, "sine", 0.45) * env(0.25, 0.001, power=2.2)
    for bar in range(bars):
        root, chord = prog[bar % 8]
        t0 = bar * 3 * beat
        section = bar // 8
        both(pizz(note(root - 12), beat * 0.95), t0, 0.9, 0.45)
        both(kick, t0, 0.45)
        both(kick_click(0.5), t0, 0.08)
        for b in (1, 2):
            both(organ(note(root + 12 + chord[1]), beat * 0.5, 0.5) + organ(note(root + 12 + chord[2]), beat * 0.5, 0.5), t0 + b * beat, 0.07, 0.62)
            both(rattle(), t0 + b * beat, 0.1, 0.3)
        both(woodblock(1100 if bar % 2 else 800), t0 + 2.5 * beat, 0.05, 0.7)
        for semis, at, length in tune[bar % 8]:
            if section == 1:
                both(theremin(note(semis - 12), length * beat * 0.98), t0 + at * beat, 0.2, 0.55)
            else:
                both(organ(note(semis), length * beat * 0.95), t0 + at * beat, 0.18, 0.55)
            if section == 2 or intense:
                both(xylo(note(semis + 12)), t0 + at * beat, 0.11, 0.7)
        if intense:
            both(timpani(note(root - 24), 0.9), t0, 0.42, 0.45)
            for s in range(6):
                both(rattle(0.06), t0 + (1 + s / 3) * beat, 0.08 + 0.015 * s, 0.35)
            if bar % 2 == 1:
                both(organ(note(root) , beat * 0.35) + organ(note(root + chord[1]), beat * 0.35) + organ(note(root + chord[2]), beat * 0.35),
                     t0 + 2 * beat, 0.09, 0.5)
            if bar % 4 == 0:
                both(choir([root + 12 + c for c in chord[:3]], 4 * 3 * beat * 0.98), t0, 0.06, 0.4)
            if bar % 8 == 7:
                both(cymbal(1.4), t0 + 2 * beat, 0.07, 0.6)
        elif bar % 8 == 7:
            both(cymbal(1.2), t0 + 2 * beat, 0.035, 0.6)
    return fold_loop(left, right, d)


def fright_ambience():
    """16 s seamless bed: night wind, crickets, a distant out-of-tune carousel
    organ drifting in and out, a few creaks, an owl and a chain clink."""
    d = 16.0
    n = int(SR * (d + 1.0))
    t = np.arange(n) / SR
    left = night_wind(n, 0.0) * 0.7
    right = night_wind(n, 1.9) * 0.7
    # Crickets: pulsed high chirps in both ears.
    for ch, f0, rate in ((left, 4300, 7.0), (right, 4700, 6.3)):
        chirp = np.sin(2 * np.pi * f0 * t) * (np.sin(2 * np.pi * rate * t) > 0.6) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 3.7))
        ch += filt(chirp, low=6000, high=3000) * 0.025
    # The far carousel organ: a slow, detuned waltz fragment through a lowpass.
    far = silence(d + 1.0)
    beat = 60.0 / 100.0
    melody = [5, 8, 12, 10, 8, 7, 5, 4, 5, 0, 5, 8]
    for k, s in enumerate(melody):
        place(far, organ(note(s) * 0.995, beat * 0.9, 0.6), 2.0 + k * beat, 0.5)
        if k % 3 == 0:
            place(far, organ(note(s - 19), beat * 2.6, 0.5), 2.0 + k * beat, 0.35)
    far = filt(far, low=1100, high=180) * (0.5 + 0.5 * np.sin(2 * np.pi * t / d)) ** 2
    left += far * 0.08
    right += far * 0.12
    for at in (4.5, 11.2):
        f = rng.uniform(150, 210)
        creak = sweep(f, f * 1.25, 0.6, "saw", 0.6) * env(0.6, 0.1, 0.5, power=1.0)
        place(right if at > 8 else left, filt(creak, low=1500, high=120), at, 0.05)
    for at in (7.0, 7.55):
        hoot = tone(392 if at < 7.3 else 349, 0.32, "sine", vibrato=0.01, vib_rate=4.0) * env(0.32, 0.04, 0.3, power=0.8)
        place(left, filt(hoot, low=900), at, 0.05)
    for at in (13.0, 13.12, 13.21):
        place(right, band(noise(0.04), 3200, 1200) * env(0.04, 0.001, power=2.0) + tone(2100, 0.04) * env(0.04, 0.001, power=2.0) * 0.4, at, 0.05)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


# ---------------------------------------------------------------------------
# Bedsheet Ghost
# ---------------------------------------------------------------------------

def fright_ghost_moan_1():
    """A hollow 'ooOOooh'."""
    return groan(220, 1.0, glide=0.35, formants=((380, 110), (820, 160)), rasp=0.08, wobble=0.12)


def fright_ghost_moan_2():
    return groan(196, 1.1, glide=-0.3, formants=((360, 100), (760, 150)), rasp=0.06, wobble=0.14)


def fright_ghost_wail():
    """The fade telegraph: a rising 'BOO-ooo' wail with a shiver of breath."""
    d = 0.7
    t = t_axis(d)
    f = 300 + 360 * (t / d) ** 0.6
    wail = np.sin(2 * np.pi * np.cumsum(f * (1.0 + 0.03 * np.sin(2 * np.pi * 9 * t))) / SR)
    vowel = band(wail * 0.6 + band(noise(d), 700, 400) * 0.2, 650, 500) + band(wail, 1200, 400) * 0.4
    return vowel * env(d, 0.03, d, power=0.6, release=0.1) * 1.6


def fright_ghost_fade():
    """The fade: a soft inward whoosh and a glassy shimmer."""
    d = 0.6
    t = t_axis(d)
    whoosh = band(noise(d), 1600, 1200) * np.sin(np.pi * t / d) ** 2
    shimmer = sum(np.sin(2 * np.pi * f * t) for f in (1760, 2217, 2637)) * np.exp(-t * 6) * 0.12
    return whoosh * 0.8 + shimmer


# ---------------------------------------------------------------------------
# Pumpkin Head
# ---------------------------------------------------------------------------

def fright_pumpkin_groan_1():
    return groan(96, 1.0, glide=-0.2, formants=((480, 120), (950, 170)), rasp=0.4, wobble=0.05)


def fright_pumpkin_groan_2():
    return groan(86, 1.1, glide=0.2, formants=((440, 110), (900, 160)), rasp=0.45, wobble=0.06)


def fright_pumpkin_fuse():
    """The throw telegraph: a match strike, then a fizzing fuse."""
    d = 1.0
    out = silence(d)
    strike = band(noise(0.12), 2600, 1800) * env(0.12, 0.004, 0.1, power=1.0)
    place(out, strike, 0.0, 1.1)
    t = t_axis(d - 0.12)
    fizz = band(noise(d - 0.12), 5200, 3000) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t) ** 2) * np.clip(t / 0.05, 0, 1)
    place(out, fizz, 0.1, 0.5)
    return out


def fright_pumpkin_throw():
    """A heavy pumpkin hurled: a grunt of effort and a tumbling whoosh."""
    d = 0.55
    t = t_axis(d)
    whoosh = band(noise(d), 900, 700) * np.exp(-((t - 0.2) / 0.14) ** 2) * 1.3
    huff = groan(120, 0.25, glide=-0.4, formants=((520, 120), (1000, 160)), rasp=0.5, wobble=0.0)
    out = whoosh
    place(out, huff, 0.0, 0.5)
    return out


def fright_pumpkin_splat():
    """The bomb bursts: a pop, a wet squelch of pulp and a sparkle."""
    d = 0.7
    out = silence(d)
    place(out, sweep(170, 50, 0.3, "sine", 0.5) * env(0.3, 0.001, 0.25, power=2.0), 0.0, 1.2)
    place(out, filt(noise(0.06), low=2500, high=200) * env(0.06, 0.001, power=1.5), 0.0, 1.0)
    t = t_axis(0.35)
    squelch = np.sin(2 * np.pi * (240 + 160 * np.sin(2 * np.pi * 14 * t)) * t) * env(0.35, 0.005, 0.3, power=1.4)
    place(out, filt(squelch, low=1400), 0.03, 0.5)
    for k in range(5):
        place(out, tone(2400 + 400 * k, 0.08) * env(0.08, 0.001, power=2.0), 0.08 + k * 0.05, 0.08)
    return out


# ---------------------------------------------------------------------------
# Ringmaster Rictus
# ---------------------------------------------------------------------------

def fright_ringmaster_laugh_1():
    """A deep 'ho-ho-hoo'."""
    out = silence(1.2)
    for k, f in enumerate((92, 88, 84)):
        place(out, groan(f, 0.3, glide=-0.3, formants=((420, 110), (820, 160)), rasp=0.45, wobble=0.03), k * 0.28, 1.0 - k * 0.1)
    return out


def fright_ringmaster_laugh_2():
    out = silence(1.1)
    for k, f in enumerate((80, 86, 90, 80)):
        place(out, groan(f, 0.24, glide=0.2, formants=((380, 100), (760, 150)), rasp=0.5, wobble=0.03), k * 0.22, 0.9)
    return out


def fright_ringmaster_cackle():
    """The summon / lantern telegraph: a rising cackle over a cymbal swell."""
    out = silence(1.2)
    for k in range(6):
        place(out, groan(140 + k * 14, 0.14, glide=0.4, formants=((620, 140), (1300, 200)), rasp=0.5, wobble=0.0), k * 0.13, 0.9)
    t = t_axis(1.2)
    place(out, cymbal(1.2) * (t / 1.2) ** 2, 0.0, 0.25)
    return out


def fright_ringmaster_whistle():
    """The spotlight / parade telegraph: a ringmaster's two-tone whistle."""
    d = 0.9
    out = silence(d)
    for f, at, ln in ((1950, 0.0, 0.32), (1640, 0.38, 0.45)):
        tt = t_axis(ln)
        w = np.sin(2 * np.pi * f * tt * (1.0 + 0.01 * np.sin(2 * np.pi * 30 * tt))) + band(noise(ln), f, 400) * 0.3
        place(out, w * env(ln, 0.01, ln, power=0.5, release=0.04), at, 0.6)
    return out


# ---------------------------------------------------------------------------
# Lights Out
# ---------------------------------------------------------------------------

def fright_power_down():
    """The fairground power fails: a fuse pops, the generator winds down."""
    d = 2.2
    out = silence(d)
    place(out, filt(noise(0.05), low=3000, high=300) * env(0.05, 0.001, power=1.5), 0.0, 1.4)
    place(out, sweep(140, 40, 0.25, "sine", 0.5) * env(0.25, 0.001, 0.2, power=2.0), 0.0, 1.0)
    t = t_axis(1.9)
    f = 120 * (1.0 - t / 1.9 * 0.7)
    hum = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.5 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    place(out, filt(np.tanh(hum * 1.5), low=1200) * env(1.9, 0.02, 1.9, power=1.0), 0.15, 0.6)
    for k in range(4):
        place(out, band(noise(0.03), 4000, 2000) * env(0.03, 0.001, power=1.5), 0.2 + k * 0.17 + 0.05 * k, 0.4)
    return out


def fright_power_up():
    """The power comes back: a clunk and a rising hum."""
    d = 1.3
    out = silence(d)
    place(out, clunk(160, 0.15), 0.0, 0.9)
    t = t_axis(1.1)
    f = 50 + 70 * (t / 1.1) ** 0.5
    hum = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.4 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    place(out, filt(np.tanh(hum * 1.5), low=1500) * env(1.1, 0.05, 1.1, power=0.6, release=0.1), 0.1, 0.5)
    return out


def fright_power_buzz():
    """The power coughs: a short electrical buzz."""
    d = 0.35
    t = t_axis(d)
    buzz = np.sign(np.sin(2 * np.pi * 120 * t)) * 0.5 + band(noise(d), 2500, 1500) * 0.4
    return filt(buzz, low=3500) * env(d, 0.005, d, power=1.0) * (0.6 + 0.4 * (np.sin(2 * np.pi * 30 * t) > 0))


SOUNDS = [
    fright_ghost_moan_1, fright_ghost_moan_2, fright_ghost_wail, fright_ghost_fade,
    fright_pumpkin_groan_1, fright_pumpkin_groan_2, fright_pumpkin_fuse, fright_pumpkin_throw, fright_pumpkin_splat,
    fright_ringmaster_laugh_1, fright_ringmaster_laugh_2, fright_ringmaster_cackle, fright_ringmaster_whistle,
    fright_power_down, fright_power_up, fright_power_buzz,
]

VARIANTS = []

MUSIC = {
    "ghost_train_loop": ghost_train_loop,
    "ghost_train_final": lambda: ghost_train_loop(intense=True),
    "fright_ambience": fright_ambience,
}
