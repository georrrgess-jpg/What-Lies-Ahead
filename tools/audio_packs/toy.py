"""Toybox Town (World 15) sound pack: Toy Shop music and ambience, the Wind-up
Soldier, Plush Brute and Toymaker voices, the train, the wind-up twist.

    python tools/gen_audio.py toy

    audio/music/toy_shop_loop.ogg     32 s midnight toy-shop march (2/4 feel, 120 BPM,
                                      C major): a music-box melody over a toy piano,
                                      pizzicato bass, a toy snare and a woodblock
    audio/music/toy_shop_final.ogg    its final-wave variant (same tempo and length:
                                      timpani, snare rolls, brass stabs, the tune an
                                      octave up on xylophone)
    audio/music/toy_ambience.ogg      12 s: the shop at night (a ticking wall clock, a
                                      low room hum, a far train clatter, a stray
                                      music-box note, a car passing in the street)
    audio/sfx/toy_*.wav               soldier, brute, Toymaker, train and twist sounds
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def music_box(freq, seconds=1.4):
    """Music-box comb tooth: a pure tone with a bright inharmonic ping that
    dies fast, and a long soft ring."""
    return additive(freq, seconds, [(1.0, 1.0, 1.1), (2.0, 0.25, 0.4), (4.2, 0.35, 0.06), (6.8, 0.12, 0.03)]) \
        * adsr(seconds, 0.001, seconds, 1.0, 0.05)


def toy_piano(freq, seconds=0.6):
    """Toy piano: struck metal rods, a little out of tune with themselves."""
    a = additive(freq, seconds, [(1.0, 1.0, 0.5), (2.01, 0.5, 0.2), (3.95, 0.3, 0.08), (5.4, 0.15, 0.05)])
    b = additive(freq * 1.006, seconds, [(1.0, 0.6, 0.45), (2.02, 0.3, 0.18)])
    return (a + b * 0.6) * adsr(seconds, 0.001, seconds, 1.0, 0.04)


def xylophone(freq, seconds=0.5):
    return additive(freq, seconds, [(1.0, 1.0, 0.18), (3.93, 0.5, 0.06), (9.0, 0.15, 0.02)]) * adsr(seconds, 0.001, seconds, 1.0, 0.03)


def pizz(freq, seconds=0.45):
    """Pizzicato double bass, with its own harmonics so small speakers carry it."""
    return audible_bass(pluck(freq, seconds, harmonics=10, decay=0.35, tilt=1.3), 0.35)


def toy_snare(seconds=0.12, gain=1.0):
    t = t_axis(seconds)
    rattle = band(noise(seconds), 3800, 2600) * np.exp(-t * 28)
    skin = np.sin(2 * np.pi * 240 * t) * np.exp(-t * 40)
    return (rattle * 0.9 + skin * 0.5) * gain


def woodblock(freq=900, seconds=0.12):
    t = t_axis(seconds)
    return (np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 2.7 * t)) * np.exp(-t * 45)


def timpani(freq, seconds=0.9):
    t = t_axis(seconds)
    body = np.sin(2 * np.pi * freq * t * (1.0 + 0.04 * np.exp(-t * 20))) + 0.3 * np.sin(2 * np.pi * freq * 1.5 * t)
    return (body + filt(noise(seconds), low=500) * 0.4 * np.exp(-t * 30)) * env(seconds, 0.002, seconds * 0.8, power=1.6)


def brass_stab(semis, seconds=0.3):
    out = silence(seconds)
    t = t_axis(seconds)
    for s in semis:
        f = note(s)
        ph = 2 * np.pi * f * t
        out += filt(np.tanh(2.0 * (np.sin(ph) + 0.5 * np.sin(2 * ph))), low=3000) * 0.3
    return out * env(seconds, 0.01, seconds * 0.8, power=1.2)


def ratchet_clicks(count, span, pitch=2600, accel=1.0):
    """A wind-up key's ratchet: `count` clicks over `span` seconds (accel > 1
    speeds them up toward the end)."""
    out = silence(span + 0.1)
    for k in range(count):
        u = k / max(1, count - 1)
        at = span * (u ** accel)
        place(out, click(0.025, pitch * (0.95 + 0.1 * (k % 2))), at, 0.9)
        place(out, clunk(420 + 40 * (k % 3), 0.04), at, 0.5)
    return out


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

def toy_shop_loop(intense=False):
    """120 BPM, 16 bars of 4/4 (32 s) in C major: C - Am - F - G, then
    C - E7 - F - G7, twice (the tune an octave up the second time round).
    A music-box tune, toy-piano chords on the off-beats, a pizzicato bass on
    1 and 3, a toy snare march and a woodblock tick. intense=True
    (toy_shop_final) adds timpani, snare rolls, brass stabs and a xylophone
    doubling: same tempo and length, so the game cross-fades in time."""
    bpm = 120.0
    beat = 60.0 / bpm
    bars = 16
    d = bars * 4 * beat
    bus = Bus(d)
    prog = [(-9, (0, 4, 7)), (-12, (0, 3, 7)), (-16, (0, 4, 7)), (-14, (0, 4, 7)),
            (-9, (0, 4, 7)), (-5, (0, 4, 7, 10)), (-16, (0, 4, 7)), (-14, (0, 4, 7, 10))]
    # Tune per bar: (semitones from A4, beat, length in beats). C5 = 3.
    tune = [
        [(3, 0, 1), (7, 1, 1), (10, 2, 1), (7, 3, 1)],
        [(12, 0, 1.5), (10, 1.5, 0.5), (7, 2, 2)],
        [(8, 0, 1), (12, 1, 1), (15, 2, 1), (12, 3, 1)],
        [(10, 0, 3), (5, 3, 1)],
        [(3, 0, 1), (7, 1, 1), (10, 2, 1), (15, 3, 1)],
        [(14, 0, 1.5), (11, 1.5, 0.5), (8, 2, 2)],
        [(8, 0, 1), (12, 1, 1), (10, 2, 1), (8, 3, 1)],
        [(7, 0, 2), (5, 2, 1), (2, 3, 1)],
    ]
    kick = sweep(120, 48, 0.2, "sine", 0.45) * env(0.2, 0.001, power=2.2)
    for bar in range(bars):
        root, chord = prog[bar % 8]
        t0 = bar * 4 * beat
        for b in (0, 2):
            bus.add(pizz(note(root - 12), beat * 0.9), t0 + b * beat, 0.8, 0.45)
            bus.add(kick, t0 + b * beat, 0.35)
            bus.add(kick_click(0.5), t0 + b * beat, 0.08)
        bus.add(pizz(note(root - 5), beat * 0.6), t0 + 3 * beat, 0.35, 0.45)
        for b in (1, 3):
            for c in chord[:3]:
                bus.add(toy_piano(note(root + 12 + c), beat * 0.8), t0 + b * beat, 0.07, 0.62)
            bus.add(toy_snare(), t0 + b * beat, 0.32, 0.4)
        for h in range(8):
            bus.add(woodblock(1100 if h % 2 else 850), t0 + h * beat / 2, 0.06 if h % 2 else 0.09, 0.7)
        octave = 12 if bar >= 8 else 0
        for semis, at, length in tune[bar % 8]:
            bus.add(music_box(note(semis + octave), max(1.0, length * beat * 1.6)), t0 + at * beat, 0.3, 0.55)
            if intense:
                bus.add(xylophone(note(semis + 12)), t0 + at * beat, 0.16, 0.35)
        if intense:
            bus.add(timpani(note(root - 24)), t0, 0.4, 0.45)
            bus.add(timpani(note(root - 17)), t0 + 2 * beat, 0.28, 0.45)
            for s in range(8):
                bus.add(toy_snare(0.07), t0 + 3 * beat + s * beat / 8, 0.1 + 0.025 * s, 0.4)
            if bar % 2 == 1:
                bus.add(brass_stab([root + c for c in chord[:3]]), t0 + 3.5 * beat, 0.22, 0.5)
            if bar % 4 == 3:
                bus.add(cymbal(1.4), t0 + 4 * beat, 0.07, 0.6)
        elif bar % 8 == 7:
            bus.add(cymbal(1.2), t0 + 4 * beat, 0.035, 0.6)
    return bus.loop()


def toy_ambience():
    """12 s seamless bed: the shop at night. A low room hum, a wall clock's
    tick-tock, a far toy-train clatter, a stray music-box note and a car
    passing in the street outside."""
    d = 12.0
    n = int(SR * (d + 1.0))
    t = np.arange(n) / SR
    room = filt(rng.uniform(-1, 1, n), low=380, high=50) * 0.35
    hum = (np.sin(2 * np.pi * 55 * t) + 0.4 * np.sin(2 * np.pi * 110 * t)) * 0.035
    left = room + hum
    right = filt(rng.uniform(-1, 1, n), low=380, high=50) * 0.35 + hum * 0.8
    for k in range(24):
        tick = woodblock(1500 if k % 2 == 0 else 1250, 0.05) * 0.5
        place(left if k % 2 else right, tick, k * 0.5, 0.18)
    # A far train clatter: rhythmic rail clicks passing behind the shelves.
    for k in range(10):
        at = 2.0 + k * 0.21
        gain = 0.06 * np.sin(np.pi * k / 9) + 0.02
        place(right, filt(clunk(300, 0.06), low=1800), at, gain)
        place(right, filt(clunk(260, 0.06), low=1800), at + 0.07, gain * 0.8)
    for at, s in ((5.2, 15), (8.4, 10), (8.9, 12)):
        place(left, music_box(note(s), 1.6), at, 0.05)
    car = band(rng.uniform(-1, 1, int(SR * 3.5)), 300, 220) * np.sin(np.pi * np.arange(int(SR * 3.5)) / (SR * 3.5)) ** 2
    place(left, car, 7.0, 0.3)
    place(right, car, 7.4, 0.25)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


# ---------------------------------------------------------------------------
# The Wind-up Soldier
# ---------------------------------------------------------------------------

def toy_soldier_hup_1():
    return groan(210, 0.35, glide=0.3, formants=((700, 160), (1600, 260)), rasp=0.3, wobble=0.05)


def toy_soldier_hup_2():
    return groan(190, 0.4, glide=-0.4, formants=((650, 150), (1500, 240)), rasp=0.35, wobble=0.06)


def toy_soldier_ratchet():
    """The march telegraph: the key in its back winding, quicker and quicker,
    and a spring tightening under it."""
    d = 0.9
    out = silence(d)
    place(out, ratchet_clicks(14, 0.78, 2400, accel=0.7), 0.0, 1.0)
    t = t_axis(d)
    spring = np.sign(np.sin(2 * np.pi * (220 + 380 * t / d) * t)) * (0.3 + 0.7 * t / d) * 0.22
    return crush(out * 0.6 + filt(spring, low=1800, high=150) * env(d, 0.05, d, power=0.5, release=0.05), 3.0)


def toy_soldier_march():
    """The burst: a snare roll into a drum hit and stomping boots."""
    d = 0.8
    out = silence(d)
    for k in range(7):
        place(out, toy_snare(0.06), k * 0.045, 0.35 + 0.08 * k)
    place(out, toy_snare(0.2, 1.4), 0.32, 1.0)
    for k in range(3):
        place(out, clunk(130, 0.1), 0.4 + k * 0.13, 0.7)
    return out


# ---------------------------------------------------------------------------
# The Plush Brute
# ---------------------------------------------------------------------------

def toy_plush_grunt_1():
    return filt(groan(82, 0.8, glide=-0.2, formants=((420, 110), (900, 160)), rasp=0.25, wobble=0.05), low=2200)


def toy_plush_grunt_2():
    return filt(groan(74, 0.9, glide=0.15, formants=((380, 100), (820, 150)), rasp=0.3, wobble=0.06), low=2200)


def toy_plush_squash():
    """The bounce telegraph: stuffing creaking as it squashes down, a spring
    coiling (a rising wobble)."""
    d = 0.95
    t = t_axis(d)
    coil = np.sin(2 * np.pi * (160 + 260 * (t / d) ** 2) * t + 3 * np.sin(2 * np.pi * 14 * t)) * (t / d) * 0.4
    creak = filt(sweep(180, 240, d, "saw", 0.6), low=1400, high=120) * env(d, 0.2, d, power=0.8) * 0.25
    stuffing = band(noise(d), 700, 500) * env(d, 0.3, d, power=0.8) * 0.3
    return coil + creak + stuffing


def toy_plush_boing():
    """The launch: a big cartoon spring boing."""
    d = 0.7
    t = t_axis(d)
    f = 140 + 420 * np.exp(-t * 6) + 30 * np.sin(2 * np.pi * 18 * t) * np.exp(-t * 3)
    out = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(d, 0.003, d, power=1.3) * 0.8
    place(out, filt(noise(0.05), low=2000) * env(0.05, 0.001, power=1.5), 0.0, 0.25)
    return out


def toy_plush_thump():
    """The landing: a soft, heavy flump and a shockwave of stuffing."""
    d = 0.7
    out = silence(d)
    place(out, sweep(110, 38, 0.35, "sine", 0.5) * env(0.35, 0.002, 0.3, power=2.0), 0.0, 1.5)
    place(out, filt(noise(0.3), low=900, high=60) * env(0.3, 0.004, 0.25, power=1.6), 0.0, 0.9)
    place(out, band(noise(0.4), 1500, 1200) * env(0.4, 0.02, 0.35, power=1.2), 0.05, 0.25)
    return out


# ---------------------------------------------------------------------------
# The Toymaker
# ---------------------------------------------------------------------------

def toy_toymaker_laugh_1():
    """A deep 'ho-ho-ho'."""
    out = silence(1.2)
    for k, f in enumerate((86, 80, 72)):
        place(out, groan(f, 0.3, glide=-0.3, formants=((420, 110), (820, 160)), rasp=0.45, wobble=0.04), k * 0.32, 0.9)
    return out


def toy_toymaker_laugh_2():
    """A low chuckle rolling down."""
    out = silence(1.1)
    for k in range(5):
        place(out, groan(92 - k * 5, 0.18, glide=-0.2, formants=((460, 120), (900, 170)), rasp=0.5, wobble=0.04), k * 0.19, 0.8)
    return out


# ---------------------------------------------------------------------------
# The shop: the train and the wind-up twist
# ---------------------------------------------------------------------------

def toy_train_whistle():
    """A toy steam whistle: two breathy chords, 'choo-choo'."""
    d = 1.3
    out = silence(d)
    for at, ln in ((0.0, 0.42), (0.55, 0.65)):
        tt = t_axis(ln)
        chord = sum(np.sin(2 * np.pi * f * tt) for f in (740, 932, 1109)) / 3
        breath = band(noise(ln), 1000, 700) * 0.4
        place(out, (chord + breath) * env(ln, 0.04, ln, power=0.5, release=0.08), at, 0.7)
    return out


def toy_windup_ratchet():
    """The twist winds the shop: a big key cranked round, clicks speeding up,
    then a music-box run up the scale."""
    d = 1.6
    out = silence(d)
    place(out, ratchet_clicks(14, 0.95, 2200, accel=0.75), 0.0, 1.0)
    for k, s in enumerate((3, 7, 10, 15, 19)):
        place(out, music_box(note(s), 0.6), 0.95 + k * 0.07, 0.35)
    return out


def toy_windup_rundown():
    """The springs run down: a music-box phrase slowing and sagging in pitch."""
    d = 2.0
    out = silence(d)
    at = 0.0
    for k, s in enumerate((15, 12, 10, 7, 3, 0)):
        sag = 2 ** (-0.03 * k * k / 12)
        place(out, music_box(note(s) * sag, 0.9), at, 0.45)
        at += 0.16 + k * 0.06
    t = t_axis(d)
    whirr = np.sin(2 * np.pi * (520 * np.exp(-t * 1.2)) * t) * env(d, 0.01, d, power=1.0) * 0.06
    return out + whirr


SOUNDS = [
    toy_soldier_hup_1, toy_soldier_hup_2, toy_soldier_ratchet, toy_soldier_march,
    toy_plush_grunt_1, toy_plush_grunt_2, toy_plush_squash, toy_plush_boing, toy_plush_thump,
    toy_toymaker_laugh_1, toy_toymaker_laugh_2,
    toy_train_whistle, toy_windup_ratchet, toy_windup_rundown,
]

VARIANTS = []

MUSIC = {
    "toy_shop_loop": toy_shop_loop,
    "toy_shop_final": lambda: toy_shop_loop(intense=True),
    "toy_ambience": toy_ambience,
}
