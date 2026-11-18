"""Gold Rush Gulch (World 12) sound pack: Boomtown music and ambience, the
Cowpoke, Prospector and Sheriff Rattlebones voices, the quick-draw, the dig, the
dynamite, the mine train and the dust storm.

    python tools/gen_audio.py gulch

    audio/music/boomtown_loop.ogg      32 s high-noon gallop (4/4, 120 BPM, A minor):
                                       a whistled tune and a harmonica answer over
                                       a boom-chick upright bass and strummed
                                       guitar, clip-clop woodblocks, a rattle
                                       shaker, a warm hall
    audio/music/boomtown_final.ogg     its final-wave variant (toms on the gallop,
                                       a train-beat snare, brass stabs, the tune up
                                       an octave on a twangy lead)
    audio/music/gulch_ambience.ogg     16 s: hot desert wind, cicadas, a creaking
                                       windmill, a far train whistle, a hawk's cry
    audio/sfx/gulch_*.wav              enemy, quick-draw, dig, dynamite, coaster and
                                       storm sounds
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403

BPM = 120.0
BEAT = 60.0 / BPM
BARS = 16
LENGTH = BARS * 4 * BEAT

# A minor: (root semitones from A4, chord tones) per bar of the 8-bar phrase.
PROG = [(0, (0, 3, 7)), (0, (0, 3, 7)), (-7, (0, 3, 7)), (-5, (0, 4, 7, 10)),
        (0, (0, 3, 7)), (-2, (0, 4, 7)), (-4, (0, 4, 7)), (-5, (0, 4, 7, 10))]
# The tune: (semitones from A4, beat, length in beats) per bar.
TUNE = [
    [(0, 0, 1.5), (7, 1.5, 0.5), (12, 2, 2)],
    [(10, 0, 1), (7, 1, 1), (8, 2, 1), (7, 3, 1)],
    [(5, 0, 1.5), (8, 1.5, 0.5), (12, 2, 1), (10, 3, 1)],
    [(11, 0, 3), (7, 3, 1)],
    [(12, 0, 1.5), (15, 1.5, 0.5), (14, 2, 1), (12, 3, 1)],
    [(10, 0, 2), (7, 2, 2)],
    [(8, 0, 1), (7, 1, 1), (5, 2, 1), (3, 3, 1)],
    [(4, 0, 2), (2, 2, 1), (-1, 3, 1)],
]


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def whistle(freq, seconds, gain=1.0):
    """A whistled note: a pure tone with a slow vibrato and a breath of air."""
    t = t_axis(seconds)
    vib = 1.0 + 0.008 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.25, 0, 1)
    x = np.sin(2 * np.pi * freq * np.cumsum(vib) / SR)
    air = band(noise(seconds), freq * 1.5, freq) * 0.06
    return (x + air) * adsr(seconds, 0.04, 0.4, 0.8, min(0.08, seconds * 0.3)) * gain


def harmonica(freq, seconds, gain=1.0):
    """A reedy harmonica note: a narrow pulse through a soft filter, with a
    little tremolo."""
    t = t_axis(seconds)
    x = bl_osc(freq, seconds, "square", width=0.3) * 0.6 + bl_osc(freq * 1.003, seconds, "saw") * 0.3
    trem = 1.0 + 0.15 * np.sin(2 * np.pi * 6.0 * t)
    return filt(x * trem, low=2400, high=180) * adsr(seconds, 0.03, 0.3, 0.75, min(0.06, seconds * 0.3)) * gain


def guitar(freq, seconds=0.5):
    return pluck(freq, seconds, harmonics=14, decay=0.35, tilt=0.9)


def twang(freq, seconds=0.5):
    """A bright twangy lead: a pluck with a quick pitch dip into the note."""
    t = t_axis(seconds)
    bend = 1.0 - 0.03 * np.exp(-t * 30)
    x = np.sin(2 * np.pi * freq * np.cumsum(bend) / SR) + 0.5 * np.sin(4 * np.pi * freq * np.cumsum(bend) / SR) \
        + 0.25 * np.sin(6 * np.pi * freq * np.cumsum(bend) / SR)
    return x * adsr(seconds, 0.003, seconds * 0.5, 0.3, 0.03)


def strum(root, chord, seconds=0.45, spread=0.012):
    out = silence(seconds + 0.1)
    for k, c in enumerate(chord):
        place(out, guitar(note(root + c), seconds), k * spread, 0.28)
    return out


def upright(freq, seconds):
    return audible_bass(pluck(freq, seconds, harmonics=8, decay=0.5, tilt=1.3), 0.35)


def woodblock(pitch=900, seconds=0.09):
    t = t_axis(seconds)
    return (np.sin(2 * np.pi * pitch * t) * 0.8 + band(noise(seconds), pitch * 2.2, 600) * 0.4) * np.exp(-t * 55)


def shaker(seconds=0.09):
    """A rattle shaker on the off-beats (a dry, rattlesnake hiss)."""
    t = t_axis(seconds)
    return band(noise(seconds), 7000, 4000) * (1.0 - np.exp(-t * 200)) * np.exp(-t * 40)


def snare(seconds=0.18):
    t = t_axis(seconds)
    return band(noise(seconds), 3500, 3000) * np.exp(-t * 22) + np.sin(2 * np.pi * 190 * t) * np.exp(-t * 35) * 0.4


def tom(freq, seconds=0.35):
    t = t_axis(seconds)
    return np.sin(2 * np.pi * freq * t * (1.0 + 0.3 * np.exp(-t * 18))) * np.exp(-t * 9)


def brass(semis, seconds=0.35):
    out = silence(seconds)
    for s in semis:
        out += filt(bl_osc(note(s), seconds, "saw"), low=2600) * 0.3
    return out * adsr(seconds, 0.02, 0.2, 0.6, 0.06)


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

def boomtown_loop(intense=False):
    """120 BPM gallop, 16 bars (32 s) in A minor: Am - Am - Dm - E7 / Am - G -
    F - E7, twice. Boom-chick upright bass on 1 and 3, guitar strums on 2 and 4,
    a clip-clop gallop on woodblocks; the tune is whistled the first time and
    taken by the harmonica the second. intense=True (boomtown_final) adds toms
    on the gallop, a train-beat snare, brass stabs and a twangy lead an octave
    up: same tempo and length, so the game cross-fades in time."""
    band_, lead, drums = Bus(LENGTH), Bus(LENGTH), Bus(LENGTH)
    for bar in range(BARS):
        root, chord = PROG[bar % 8]
        t0 = bar * 4 * BEAT
        bass_root = note(root - 24)
        band_.add(upright(bass_root, BEAT * 0.9), t0, 0.9, 0.45)
        band_.add(upright(note(root - 24 + 7), BEAT * 0.9), t0 + 2 * BEAT, 0.75, 0.45)
        for b in (1, 3):
            band_.add(strum(root - 12, chord), t0 + b * BEAT, 0.55, 0.62)
        for e in range(8):
            drums.add(shaker(), t0 + e * 0.5 * BEAT, 0.3 if e % 2 else 0.18, 0.75)
        for b in range(4):
            drums.add(woodblock(950), t0 + b * BEAT, 0.28, 0.3)
            drums.add(woodblock(720), t0 + (b + 0.333) * BEAT, 0.18, 0.7)
            drums.add(woodblock(600), t0 + (b + 0.667) * BEAT, 0.14, 0.7)
        second = bar >= 8
        for semis, at, length in TUNE[bar % 8]:
            dur = length * BEAT * 0.95
            if intense:
                lead.add(twang(note(semis + 12), dur + 0.2), t0 + at * BEAT, 0.3, 0.55)
                lead.add(harmonica(note(semis), dur), t0 + at * BEAT, 0.12, 0.4)
            elif second:
                lead.add(harmonica(note(semis), dur), t0 + at * BEAT, 0.3, 0.55)
            else:
                lead.add(whistle(note(semis + 12), dur), t0 + at * BEAT, 0.34, 0.5)
        if second and not intense:
            for k, c in enumerate(chord[:3]):
                lead.add(whistle(note(root + c + 12), BEAT * 1.8, 0.4), t0 + k * 1.3 * BEAT, 0.05, 0.35)
        if intense:
            for b in range(4):
                drums.add(tom(note(root - 24) * 2, 0.3), t0 + b * BEAT, 0.35, 0.4)
                for s in range(4):
                    drums.add(snare(0.1), t0 + (b + s * 0.25) * BEAT, 0.08 + 0.06 * (s == 2), 0.6)
            drums.add(snare(0.22), t0 + BEAT, 0.3, 0.55)
            drums.add(snare(0.22), t0 + 3 * BEAT, 0.3, 0.55)
            if bar % 2 == 1:
                band_.add(brass([root + c for c in chord[:3]]), t0 + 3.5 * BEAT, 0.35, 0.5)
            if bar % 8 == 7:
                drums.add(cymbal(1.4), t0 + 4 * BEAT, 0.12, 0.6)
        elif bar % 8 == 7:
            drums.add(cymbal(1.2), t0 + 4 * BEAT, 0.05, 0.6)
    mix = band_.loop() + lead.loop() + drums.loop()
    hall = reverb(lead.loop()[:, 0] * 0.6 + band_.loop()[:, 0] * 0.3, lead.loop()[:, 1] * 0.6 + band_.loop()[:, 1] * 0.3,
                  seconds=2.2, dark=3400)
    return mix + hall * 0.4


def gulch_ambience():
    """16 s seamless bed: hot wind over the gulch, cicadas buzzing in bursts, a
    creaking windmill, a far steam whistle and a hawk."""
    d = 16.0
    n = int(SR * (d + 1.0))
    t = np.arange(n) / SR
    left = filt(rng.uniform(-1, 1, n), low=600, high=70) * (0.4 + 0.3 * np.sin(2 * np.pi * t / 8.0) ** 2)
    right = filt(rng.uniform(-1, 1, n), low=600, high=70) * (0.4 + 0.3 * np.sin(2 * np.pi * t / 8.0 + 1.4) ** 2)
    for start, ln, side in ((1.0, 3.5, 0), (6.5, 4.0, 1), (11.5, 3.0, 0)):
        tt = t_axis(ln)
        buzz = band(noise(ln), 5200, 1600) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 38 * tt))) * env(ln, 0.6, ln, power=0.8, release=0.6)
        place(left if side == 0 else right, buzz, start, 0.05)
    for at in (3.0, 9.2, 13.8):
        f = rng.uniform(160, 220)
        creak = sweep(f, f * 1.25, 0.7, "saw", 0.6) * env(0.7, 0.1, 0.6, power=1.0)
        place(right, filt(creak, low=1500, high=140), at, 0.04)
    whistle_ = silence(1.6)
    for f, at in ((523, 0.0), (659, 0.0), (784, 0.0)):
        place(whistle_, filt(bl_osc(f, 1.4, "square", width=0.4), low=1800) * adsr(1.4, 0.1, 0.8, 0.7, 0.3), at, 0.25)
    place(left, whistle_, 7.5, 0.035)
    hawk = sweep(2400, 1500, 0.9, "sine", 0.6) * env(0.9, 0.02, 0.8, power=1.2) * (1 + 0.3 * np.sin(2 * np.pi * 30 * t_axis(0.9)))
    place(right, hawk, 4.6, 0.025)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


# ---------------------------------------------------------------------------
# Cowpoke
# ---------------------------------------------------------------------------

def gulch_cowpoke_yeehaw_1():
    return groan(260, 0.6, glide=0.9, formants=((750, 170), (1900, 300)), rasp=0.35, wobble=0.1)


def gulch_cowpoke_yeehaw_2():
    return groan(220, 0.7, glide=0.6, formants=((680, 160), (1700, 280)), rasp=0.4, wobble=0.12)


def gulch_cowpoke_draw():
    """The quick-draw telegraph: a jingle of spurs, the creak of leather and a
    bright 'ting' as the glint flashes."""
    d = 0.92
    out = silence(d)
    for k in range(5):
        f = rng.uniform(3200, 4600)
        jingle_ = (np.sin(2 * np.pi * f * t_axis(0.12)) + 0.5 * np.sin(2 * np.pi * f * 1.48 * t_axis(0.12))) * np.exp(-t_axis(0.12) * 30)
        place(out, jingle_, 0.04 + k * 0.06, 0.12)
    creak = filt(sweep(180, 260, 0.35, "saw", 0.5), low=1400, high=120) * env(0.35, 0.05, 0.3, power=1.0)
    place(out, creak, 0.25, 0.25)
    ting = (np.sin(2 * np.pi * 2637 * t_axis(0.5)) + 0.4 * np.sin(2 * np.pi * 5274 * t_axis(0.5))) * np.exp(-t_axis(0.5) * 7)
    place(out, ting, 0.5, 0.35)
    return out


def gulch_cowpoke_shot():
    """A toy cap gun: a sharp pop, a snap of paper cap and a tiny ricochet."""
    d = 0.5
    out = silence(d)
    place(out, filt(noise(0.05), low=6000, high=600) * env(0.05, 0.001, power=2.0), 0.0, 1.3)
    place(out, sweep(500, 120, 0.12, "sine", 0.5) * env(0.12, 0.001, 0.1, power=2.0), 0.0, 0.8)
    place(out, click(0.02, 3800, 0.6), 0.01, 0.6)
    place(out, sweep(3200, 1800, 0.25, "sine", 0.7) * env(0.25, 0.01, 0.2, power=1.5), 0.12, 0.12)
    return out


# ---------------------------------------------------------------------------
# Prospector
# ---------------------------------------------------------------------------

def gulch_prospector_grumble_1():
    return groan(96, 1.0, glide=-0.2, formants=((480, 110), (1000, 170)), rasp=0.35, wobble=0.06)


def gulch_prospector_grumble_2():
    return groan(84, 1.1, glide=0.2, formants=((440, 100), (950, 160)), rasp=0.4, wobble=0.08)


def gulch_prospector_dig():
    """The dig telegraph: two shovel bites into dry earth and a pick's clink."""
    d = 0.8
    out = silence(d)
    for at in (0.0, 0.32):
        bite = band(noise(0.22), 1200, 900) * env(0.22, 0.005, 0.2, power=1.2)
        place(out, bite, at, 0.7)
        place(out, sweep(260, 120, 0.15, "sine", 0.5) * env(0.15, 0.002, power=2.0), at, 0.4)
    clink = (np.sin(2 * np.pi * 1800 * t_axis(0.3)) + 0.6 * np.sin(2 * np.pi * 2700 * t_axis(0.3))) * np.exp(-t_axis(0.3) * 14)
    place(out, clink, 0.6, 0.25)
    return out


def gulch_prospector_pop():
    """It bursts up: a deep thump and a spray of gravel."""
    d = 0.8
    out = silence(d)
    place(out, sweep(140, 40, 0.35, "sine", 0.5) * env(0.35, 0.001, 0.3, power=2.0), 0.0, 1.4)
    place(out, filt(noise(0.2), low=2500, high=200) * env(0.2, 0.002, power=1.5), 0.0, 0.8)
    for k in range(10):
        pebble = band(noise(0.03), rng.uniform(1800, 3200), 900) * env(0.03, 0.001, power=1.8)
        place(out, pebble, 0.1 + k * 0.045 + rng.uniform(0, 0.03), 0.35 - 0.025 * k)
    return out


# ---------------------------------------------------------------------------
# Sheriff Rattlebones
# ---------------------------------------------------------------------------

def gulch_sheriff_growl_1():
    return groan(70, 0.9, glide=-0.2, formants=((380, 100), (800, 150)), rasp=0.55, wobble=0.05)


def gulch_sheriff_growl_2():
    return groan(62, 1.0, glide=0.15, formants=((340, 95), (720, 140)), rasp=0.6, wobble=0.07)


def gulch_sheriff_fuse():
    """The dynamite windup: a match strike and a fizzing, crackling fuse."""
    d = 0.9
    out = silence(d)
    place(out, band(noise(0.12), 3000, 2000) * env(0.12, 0.003, 0.1, power=1.0), 0.0, 0.6)
    t = t_axis(0.75)
    fizz = band(noise(0.75), 5000, 3000) * (0.6 + 0.4 * np.sin(2 * np.pi * 17 * t)) * env(0.75, 0.05, 0.75, power=0.6, release=0.05)
    place(out, fizz, 0.12, 0.35)
    for k in range(8):
        place(out, click(0.01, rng.uniform(2500, 4500), 0.5), 0.15 + rng.uniform(0, 0.65), 0.4)
    return out


# ---------------------------------------------------------------------------
# Mine train and dust storm
# ---------------------------------------------------------------------------

def gulch_coaster_clack():
    """The chain lift catches: a run of heavy clacks."""
    d = 1.8
    out = silence(d)
    for k in range(14):
        place(out, clunk(170 + (k % 2) * 30, 0.08), k * 0.12, 0.5)
    return out


def gulch_coaster_whoosh():
    """Over the top: rails rumbling, a rush of air and a far whoop from the cars."""
    d = 2.2
    t = t_axis(d)
    rumble = filt(noise(d), low=300, high=40) * np.sin(np.pi * t / d) ** 0.8
    rush = band(noise(d), 1500, 1200) * np.exp(-((t - 0.8) / 0.45) ** 2)
    whoop = groan(330, 0.6, glide=0.8, formants=((800, 180), (2100, 320)), rasp=0.1, wobble=0.1)
    out = rumble * 1.2 + rush * 0.9
    place(out, whoop, 0.5, 0.15)
    return out


def gulch_wind_gust():
    """A gust of the dust storm: a rising, gritty howl."""
    d = 1.8
    t = t_axis(d)
    shape = np.sin(np.pi * t / d) ** 1.4
    howl = filt(noise(d), low=900, high=120) + band(noise(d), 2200, 1500) * 0.5
    grit = band(noise(d), 6000, 3000) * (rng.uniform(0, 1, len(t)) > 0.97) * 0.8
    return (howl + grit) * shape


SOUNDS = [
    gulch_cowpoke_yeehaw_1, gulch_cowpoke_yeehaw_2, gulch_cowpoke_draw, gulch_cowpoke_shot,
    gulch_prospector_grumble_1, gulch_prospector_grumble_2, gulch_prospector_dig, gulch_prospector_pop,
    gulch_sheriff_growl_1, gulch_sheriff_growl_2, gulch_sheriff_fuse,
    gulch_coaster_clack, gulch_coaster_whoosh, gulch_wind_gust,
]

VARIANTS = []

LOOPS = {}

MUSIC = {
    "boomtown_loop": boomtown_loop,
    "boomtown_final": lambda: boomtown_loop(intense=True),
    "gulch_ambience": gulch_ambience,
}
