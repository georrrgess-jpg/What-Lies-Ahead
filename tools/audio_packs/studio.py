"""Starlot Studios (the second Endless map) sound pack: its music loop, the
boss-wave variant and the backlot's night ambience.

    python tools/gen_audio.py studio

    audio/music/studio_endless_loop.ogg   32 s monster-movie swing, 120 BPM in
                                          D minor: a walking upright bass, brushed
                                          snare and ride, vibraphone chords, muted
                                          brass stabs and a theremin melody
    audio/music/studio_endless_final.ogg  the boss-wave variant: same tempo and
                                          length, timpani, brass on every bar, a
                                          driving ride, the theremin an octave up
    audio/music/studio_ambience.ogg       16 s bed: night wind over the lot, crickets,
                                          a generator's hum and a far crowd murmur
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403


BPM = 120.0
BEAT = 60.0 / BPM
BARS = 16
# Two bars per chord: Dm - Bb7 - Gm6 - A7 (A), Dm - Eb7 - Dm - A7 (B). Roots from A4.
CHORDS_A = [(-19, (0, 3, 7, 9)), (-23, (0, 4, 7, 10)), (-26, (0, 3, 7, 9)), (-24, (0, 4, 7, 10))]
CHORDS_B = [(-19, (0, 3, 7, 10)), (-18, (0, 4, 7, 10)), (-19, (0, 3, 7, 9)), (-24, (0, 4, 7, 10))]
# The theremin line per two-bar chord: (semitones over the chord root + 24, beat, length).
THEREMIN = [
    [(7, 0.0, 3.0), (8, 3.0, 1.0), (7, 4.0, 2.0), (3, 6.0, 2.0)],
    [(4, 0.0, 2.0), (7, 2.0, 2.0), (10, 4.0, 3.0), (9, 7.0, 1.0)],
    [(3, 0.0, 3.0), (2, 3.0, 1.0), (0, 4.0, 2.0), (3, 6.0, 2.0)],
    [(7, 0.0, 2.0), (4, 2.0, 2.0), (1, 4.0, 2.0), (-2, 6.0, 2.0)],
]


def upright(freq, seconds):
    """Plucked upright bass: a round body with a soft thump."""
    t = t_axis(seconds)
    body = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(4 * np.pi * freq * t) * np.exp(-t * 6.0)
    thump = filt(noise(seconds), low=500) * np.exp(-t * 40.0) * 0.4
    return (body * env(seconds, 0.004, seconds * 0.8, power=1.4) + thump) * 0.9


def vibes(freq, seconds, gain=1.0):
    """Vibraphone: a bar's two partials with a slow tremolo."""
    t = t_axis(seconds)
    trem = 0.8 + 0.2 * np.sin(2 * np.pi * 5.5 * t)
    x = np.sin(2 * np.pi * freq * t) + 0.25 * np.sin(2 * np.pi * freq * 4.0 * t) * np.exp(-t * 8.0)
    return x * trem * env(seconds, 0.002, seconds, power=1.3) * gain


def brass(semis, seconds):
    """A muted brass stab: detuned saws through a closing filter."""
    x = sum(bl_osc(note(s) * (1.0 + 0.003 * i), seconds, "saw") for i, s in enumerate(semis))
    return filt(x, low=1400) * adsr(seconds, 0.02, seconds * 0.6, 0.4, 0.05) * 0.35


def theremin(semis, seconds, glide_from=None):
    """Sine with a wide vibrato, sliding in from the previous note."""
    t = t_axis(seconds)
    f1 = note(semis)
    f0 = note(glide_from) if glide_from is not None else f1
    freq = f1 + (f0 - f1) * np.exp(-t * 14.0)
    freq = freq * (1.0 + 0.012 * np.sin(2 * np.pi * 6.0 * t) * np.clip(t * 2.0, 0.0, 1.0))
    x = bl_osc(freq, seconds, "sine") + 0.12 * bl_osc(freq * 2.0, seconds, "sine")
    return x * adsr(seconds, 0.06, seconds, 0.85, 0.12)


def brush(seconds=0.18):
    return band(noise(seconds), 3200, 2600) * env(seconds, 0.01, seconds, power=1.2)


def ride(seconds=0.5):
    return filt(cymbal(seconds), low=9000) * 0.8


def timpani(freq):
    d = 1.2
    return (sweep(freq * 1.15, freq, d, "sine", 0.3) + filt(noise(d), low=300) * np.exp(-t_axis(d) * 18.0) * 0.6) * env(d, 0.002, d, power=1.5)


def studio_endless_loop(intense=False):
    """32-second loop, 120 BPM swing in D minor, 16 bars. Section A (bars
    1-8): Dm - Bb7 - Gm6 - A7, a walking bass, brushes and ride, vibraphone
    chords, the theremin melody from bar 3. Section B (bars 9-16): Dm - Eb7 -
    Dm - A7 with muted brass stabs answering the theremin.

    intense=True is the boss-wave variant (studio_endless_final): timpani on
    the downbeats, brass every bar, a driving ride, kicks on every beat and the
    theremin doubled an octave up. Same tempo and length."""
    d = BARS * 4 * BEAT
    left, right = silence(d + 2.0), silence(d + 2.0)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    kick = sweep(110, 45, 0.25, "sine", 0.45) * env(0.25, 0.001, power=2.2)
    swing = 2.0 / 3.0
    prev = None
    for bar in range(BARS):
        section_b = bar >= 8
        root, shape = (CHORDS_B if section_b else CHORDS_A)[(bar // 2) % 4]
        t0 = bar * 4 * BEAT
        # Drums: ride in swung eighths, brushes on 2 and 4, a soft kick.
        for b in range(4):
            both(kick, t0 + b * BEAT, 0.42 if (b % 2 == 0 or intense) else 0.18)
            both(ride(), t0 + b * BEAT, 0.08 if not intense else 0.11, 0.7)
            if b % 2 == 1 or intense:
                both(ride(0.3), t0 + (b + swing) * BEAT, 0.05 if not intense else 0.08, 0.7)
            if b in (1, 3):
                both(brush(), t0 + b * BEAT, 0.22, 0.35)
        if intense and bar % 2 == 0:
            both(timpani(note(root - 24)), t0, 0.5, 0.45)
        if bar % 8 == 7:
            both(riser(2 * BEAT), t0 + 2 * BEAT, 0.05 if not intense else 0.08, 0.5)
        # Walking bass: root, fifth, octave, a chromatic step into the next bar.
        walk = [0, 7, 12, 11] if bar % 2 == 0 else [10, 7, 3, 1]
        for b, s in enumerate(walk):
            both(upright(note(root - 12 + s), BEAT * 0.9), t0 + b * BEAT, 0.55, 0.45)
        # Vibraphone chords on the "and" of 1 and on 3.
        if bar % 2 == 0:
            for at in (swing, 2.0):
                for i, s in enumerate(shape):
                    both(vibes(note(root + 12 + s), BEAT * 2.5, 0.5), t0 + at * BEAT, 0.07, 0.3 + 0.13 * i)
        # Brass stabs: answering phrases in B, every bar when intense.
        if (section_b and bar % 2 == 1) or intense:
            for at in ((2.0 + swing, 0.4), (3.0 + swing, 0.6)):
                both(brass([root + s for s in shape[:3]], at[1] * BEAT * 1.5), t0 + at[0] * BEAT, 0.22, 0.6)
        # The theremin, from bar 3 (from bar 1 when intense).
        if bar % 2 == 0 and (bar >= 2 or intense):
            for semis, at, length in THEREMIN[(bar // 2) % 4]:
                s = root + 24 + semis
                x = theremin(s, length * BEAT, prev)
                both(x, t0 + at * BEAT, 0.16, 0.55)
                if intense:
                    both(theremin(s + 12, length * BEAT, None if prev is None else prev + 12), t0 + at * BEAT, 0.05, 0.6)
                prev = s
    return fold_loop(left, right, d)


def studio_ambience():
    """16-second bed: wind over the lot, crickets, a generator's low hum and a
    far crowd murmur (the premiere)."""
    d = 16.0
    out = silence(d)
    wind = filt(noise(d), low=600) * (0.6 + 0.4 * np.sin(2 * np.pi * t_axis(d) / 8.0) ** 2)
    place(out, wind, 0.0, 0.5)
    hum = (tone(60, d) * 0.5 + tone(120, d) * 0.3 + tone(180, d) * 0.1) * 0.25
    place(out, hum, 0.0, 0.5)
    crowd = band(noise(d), 700, 500) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * t_axis(d) / 4.0)))
    place(out, crowd, 0.0, 0.18)
    for k in range(40):
        at = (k * 0.39 + (k % 3) * 0.07) % (d - 0.2)
        chirp = tone(4300 + (k % 5) * 90, 0.05) * env(0.05, 0.002, 0.04)
        place(out, chirp, at, 0.05)
    return np.stack([out, np.roll(out, int(SR * 0.017))], axis=1)


SOUNDS = []

VARIANTS = []

LOOPS = {}

MUSIC = {
    "studio_endless_loop": studio_endless_loop,
    "studio_endless_final": lambda: studio_endless_loop(intense=True),
    "studio_ambience": studio_ambience,
}
