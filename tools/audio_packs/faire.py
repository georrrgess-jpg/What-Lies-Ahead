"""Castle Kingdom (World 14) sound pack: Royal Faire music and ambience, the
Armored Knight, Jester and Black Knight voices, the knight's shield, the jester's
pins and bells, and the siege engines.

    python tools/gen_audio.py faire

    audio/music/faire_loop.ogg        ~36 s faire jig (6/8, 108 dotted beats per
                                      minute, D dorian): a reedy pipe tune over lute
                                      plucks, a bagpipe drone, tabor and tambourine
    audio/music/faire_final.ogg       its final-wave variant (war drums on every
                                      beat, a trumpet fanfare, a snare drive and the
                                      tune doubled an octave up): same tempo and length
    audio/music/faire_ambience.ogg    15 s: a spring breeze, birdsong, a distant faire
                                      crowd, flapping pennants and a far bell
    audio/sfx/faire_*.wav             enemy, shield, pin, bell and siege sounds
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def pipe(freq, seconds, gain=1.0):
    """A reedy shawm-and-recorder pipe: odd harmonics, a breathy edge and a
    gentle vibrato that blooms after the attack."""
    t = t_axis(seconds)
    vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.6 * t) * np.clip(t / 0.15, 0.0, 1.0)
    x = additive(freq * vib, seconds, [(1, 1.0, None), (2, 0.18, None), (3, 0.42, None), (5, 0.16, None), (7, 0.06, None)])
    breath = band(noise(seconds), freq * 2.5, freq) * 0.07
    return (x + breath) * adsr(seconds, 0.025, 0.12, 0.8, min(0.06, seconds * 0.3)) * gain


def lute(freq, seconds=0.7, gain=1.0):
    """A lute pluck: bright, quickly darkening partials."""
    return pluck(freq, seconds, harmonics=10, decay=0.55, tilt=1.1) * gain


def drone(freq, seconds):
    """Bagpipe drone: two slightly beating reeds, steady."""
    t = t_axis(seconds)
    reed = additive(freq, seconds, [(1, 1.0, None), (2, 0.5, None), (3, 0.35, None), (4, 0.2, None)])
    reed2 = additive(freq * 1.003, seconds, [(1, 0.8, None), (2, 0.4, None), (3, 0.25, None)])
    return (reed + reed2) * (0.9 + 0.1 * np.sin(2 * np.pi * 0.23 * t))


def tabor(seconds=0.35, pitch=95.0):
    """Frame drum: a low thump with a pitch drop and a skin slap."""
    t = t_axis(seconds)
    body = np.sin(2 * np.pi * pitch * t * (1.0 + 0.5 * np.exp(-t * 30))) * np.exp(-t * 11)
    slap = band(noise(seconds), 1800, 1400) * np.exp(-t * 60) * 0.5
    return audible_bass(body, 0.3) + slap


def tambourine(seconds=0.22):
    """A shake of jingles."""
    t = t_axis(seconds)
    jing = band(noise(seconds), 7000, 3000) + band(noise(seconds), 4800, 1200) * 0.6
    return jing * np.exp(-t * 16) * env(seconds, 0.004, seconds, power=1.2)


def war_drum(freq=55.0, seconds=0.7):
    t = t_axis(seconds)
    body = np.sin(2 * np.pi * freq * t * (1.0 + 0.06 * np.exp(-t * 18))) + 0.3 * np.sin(2 * np.pi * freq * 1.6 * t)
    return audible_bass(body * np.exp(-t * 5.5), 0.4) + filt(noise(seconds), low=700) * np.exp(-t * 35) * 0.5


def trumpet(freq, seconds, gain=1.0):
    """A herald's trumpet: a bright brassy tone with a quick swell."""
    t = t_axis(seconds)
    x = bl_osc(freq * (1.0 + 0.004 * np.sin(2 * np.pi * 6 * t)), seconds, "saw")
    return filt(x, low=3400, high=180) * adsr(seconds, 0.03, 0.1, 0.75, min(0.08, seconds * 0.3)) * gain


def snare(seconds=0.14):
    t = t_axis(seconds)
    return (band(noise(seconds), 2600, 1800) + np.sin(2 * np.pi * 190 * t) * 0.4) * np.exp(-t * 28)


def metal_ring(freq, seconds, decay=6.0):
    """An inharmonic metal strike (shields, armour, swords)."""
    t = t_axis(seconds)
    x = sum(np.sin(2 * np.pi * freq * r * t) * a * np.exp(-t * decay * d) for r, a, d in
            ((1.0, 1.0, 1.0), (2.32, 0.6, 1.4), (3.97, 0.4, 1.9), (5.6, 0.25, 2.6), (7.8, 0.15, 3.2)))
    return x * env(seconds, 0.0008, seconds, power=1.0)


def bells(seconds=0.6, count=8, seed_hz=2600.0):
    """A jester's jingle bells: a quick cluster of tiny metal pings."""
    out = silence(seconds)
    for k in range(count):
        f = seed_hz * rng.uniform(0.85, 1.25)
        place(out, metal_ring(f, 0.25, decay=18.0), rng.uniform(0.0, seconds * 0.6), rng.uniform(0.15, 0.3))
    return out


def breeze(n, shift=0.0, slow=9.0):
    t = np.arange(n) / SR
    lo = filt(rng.uniform(-1, 1, n), low=600, high=80)
    hi = filt(rng.uniform(-1, 1, n), low=3000, high=900)
    gust = (0.5 + 0.5 * np.sin(2 * np.pi * t / slow + shift)) ** 2
    return lo * (0.3 + 0.5 * gust) + hi * gust * 0.18


def chirp_song(seconds=0.8):
    """A short bird phrase: two or three quick rising and falling chirps."""
    out = silence(seconds)
    at = 0.0
    for _ in range(int(rng.integers(2, 5))):
        f0 = rng.uniform(2600, 3800)
        d = rng.uniform(0.06, 0.12)
        c = sweep(f0, f0 * rng.uniform(1.15, 1.5), d, "sine", 0.7) * env(d, 0.005, d, power=1.0)
        place(out, c, at, rng.uniform(0.6, 1.0))
        at += d + rng.uniform(0.02, 0.08)
        if at > seconds - 0.15:
            break
    return out


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

def faire_loop(intense=False):
    """6/8 jig at 108 dotted beats a minute, 32 bars (~35.6 s) in D dorian:
    Dm - C - Dm - C - Dm - G - C - Dm. A reedy pipe tune (an octave up the
    second half), lute plucks on the off-beats, a D-A bagpipe drone, tabor on
    the dotted beats and tambourine shakes. intense=True (faire_final) adds war
    drums on every beat, a trumpet fanfare every four bars, a snare drive and
    the tune doubled an octave up: same tempo and length, so the game
    cross-fades in time."""
    beat = 60.0 / 108.0
    eighth = beat / 3.0
    bars = 32
    bar_len = 2 * beat
    d = bars * bar_len
    left, right = silence(d + 2.0), silence(d + 2.0)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    # Roots relative to A4 and chord tones (semitones).
    prog = [(-19, (0, 3, 7)), (-21, (0, 4, 7)), (-19, (0, 3, 7)), (-21, (0, 4, 7)),
            (-19, (0, 3, 7)), (-26, (0, 4, 7)), (-21, (0, 4, 7)), (-19, (0, 3, 7))]
    # The tune: (semitones from A4, eighth in bar, length in eighths).
    tune = [
        [(5, 0, 2), (7, 2, 1), (8, 3, 2), (7, 5, 1)],
        [(3, 0, 2), (5, 2, 1), (7, 3, 3)],
        [(8, 0, 2), (10, 2, 1), (12, 3, 2), (10, 5, 1)],
        [(8, 0, 1), (7, 1, 1), (5, 2, 1), (3, 3, 3)],
        [(12, 0, 2), (12, 2, 1), (14, 3, 2), (12, 5, 1)],
        [(10, 0, 2), (14, 2, 1), (10, 3, 2), (7, 5, 1)],
        [(8, 0, 1), (7, 1, 1), (3, 2, 1), (5, 3, 3)],
        [(5, 0, 6)],
    ]
    both(drone(note(-19), d + 1.0), 0.0, 0.05, 0.35)
    both(drone(note(-12), d + 1.0), 0.0, 0.035, 0.65)
    for bar in range(bars):
        root, chord = prog[bar % 8]
        t0 = bar * bar_len
        for b in (0, 1):
            both(tabor(), t0 + b * beat, 0.5, 0.45)
            both(lute(note(root), 0.5), t0 + b * beat, 0.22, 0.4)
            for k, c in enumerate(chord):
                both(lute(note(root + 12 + c), 0.45), t0 + b * beat + eighth * (1 + (k % 2)), 0.1, 0.62)
        both(tambourine(), t0 + eighth * 2, 0.07, 0.7)
        both(tambourine(), t0 + beat + eighth * 2, 0.06, 0.7)
        octave = 12 if bar >= 16 else 0
        for semis, at, length in tune[bar % 8]:
            both(pipe(note(semis + octave), length * eighth * 0.95), t0 + at * eighth, 0.2, 0.55)
            if intense:
                both(pipe(note(semis + octave + 12), length * eighth * 0.9, 0.5), t0 + at * eighth, 0.1, 0.4)
        if intense:
            for b in (0, 1):
                both(war_drum(), t0 + b * beat, 0.5, 0.5)
                for s in range(3):
                    both(snare(), t0 + b * beat + s * eighth, 0.07 + 0.03 * s, 0.35)
            if bar % 4 == 3:
                for k, s in enumerate((0, 7, 12)):
                    both(trumpet(note(root + 24 + s), eighth * 1.6), t0 + beat + k * eighth, 0.11, 0.55)
            if bar % 8 == 7:
                both(cymbal(1.4), t0 + bar_len, 0.07, 0.6)
        elif bar % 8 == 7:
            both(cymbal(1.2), t0 + bar_len, 0.03, 0.6)
    return fold_loop(left, right, d)


def faire_ambience():
    """15 s seamless bed: a spring breeze, birdsong, a distant faire crowd,
    pennants flapping and a far chapel bell."""
    d = 15.0
    n = int(SR * (d + 1.0))
    t = np.arange(n) / SR
    left = breeze(n, 0.0) * 0.6
    right = breeze(n, 1.9) * 0.6
    murmur = band(rng.uniform(-1, 1, n), 520, 380) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 3.7) ** 2) * 0.12
    left += murmur
    right += np.roll(murmur, SR // 3) * 0.9
    for _ in range(9):
        at = rng.uniform(0, d - 1.0)
        place(left if rng.uniform() < 0.5 else right, chirp_song(), at, rng.uniform(0.04, 0.08))
    for _ in range(16):
        at = rng.uniform(0, d - 0.5)
        flap = band(noise(0.05), 900, 700) * env(0.05, 0.003, 0.04, power=1.5)
        for k in range(3):
            place(left if k % 2 else right, flap, at + k * 0.07, rng.uniform(0.04, 0.09))
    for at in (3.0, 10.5):
        place(left, metal_ring(392.0, 2.4, decay=1.4), at, 0.025)
        place(right, metal_ring(392.0, 2.4, decay=1.4), at + 0.02, 0.02)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


# ---------------------------------------------------------------------------
# Armored Knight
# ---------------------------------------------------------------------------

def helmet(x, delay=0.006, gain=0.6):
    """Through a helm: a short metallic comb echo on a voice."""
    k = int(SR * delay)
    out = x.copy()
    out[k:] += x[:-k] * gain
    return out


def faire_knight_grunt_1():
    return helmet(groan(96, 0.8, glide=-0.2, formants=((480, 110), (1050, 170)), rasp=0.35, wobble=0.05))


def faire_knight_grunt_2():
    return helmet(groan(86, 0.9, glide=0.15, formants=((440, 100), (980, 160)), rasp=0.4, wobble=0.06))


def faire_shield_clang():
    """A shot glancing off the heater shield: a bright clang."""
    d = 0.4
    out = metal_ring(560.0 * rng.uniform(0.95, 1.05), d, decay=9.0)
    return out + band(noise(d), 4200, 2500) * np.exp(-t_axis(d) * 60) * 0.4


def faire_shield_break():
    """The shield gives way: a big clang and splintering wood."""
    d = 0.9
    out = silence(d)
    place(out, metal_ring(380.0, 0.8, decay=4.0), 0.0, 1.0)
    for k in range(7):
        place(out, band(noise(0.06), rng.uniform(900, 2400), 800) * env(0.06, 0.002, power=1.4), 0.03 + k * 0.05, 0.5 - 0.05 * k)
    place(out, sweep(160, 50, 0.3, "sine", 0.5) * env(0.3, 0.002, 0.25, power=2.0), 0.0, 0.7)
    return out


def faire_knight_rap():
    """The charge telegraph: the sword rapped three times on the shield rim
    (on the Drum clip's beats) and a rising scrape of steel."""
    d = 1.15
    out = silence(d)
    for k, at in enumerate((0.21, 0.46, 0.71)):
        place(out, metal_ring(470.0 + 40 * k, 0.35, decay=8.0), at, 0.8)
        place(out, clunk(180, 0.1), at, 0.4)
    place(out, band(sweep(1800, 4200, 0.35, "saw", 1.0), 3000, 2200) * env(0.35, 0.05, 0.3, power=1.0), 0.78, 0.25)
    return out


def faire_knight_charge():
    """The charge: an armour rattle, a battle shout through the helm and a rush."""
    d = 0.9
    out = silence(d)
    place(out, helmet(groan(140, 0.6, glide=0.35, formants=((620, 140), (1300, 220)), rasp=0.45, wobble=0.07)), 0.0, 0.8)
    for k in range(8):
        place(out, metal_ring(rng.uniform(900, 1600), 0.12, decay=25.0), k * 0.09, 0.2)
    place(out, band(noise(d), 900, 700) * env(d, 0.1, d, power=0.8), 0.0, 0.5)
    return out


def faire_knight_bash():
    """Shield or sword landing: a heavy metal thud."""
    d = 0.45
    out = silence(d)
    place(out, sweep(140, 45, 0.3, "sine", 0.5) * env(0.3, 0.001, 0.25, power=2.0), 0.0, 1.2)
    place(out, metal_ring(300.0, 0.4, decay=7.0), 0.0, 0.5)
    place(out, clunk(200, 0.12), 0.0, 0.6)
    return out


# ---------------------------------------------------------------------------
# Jester
# ---------------------------------------------------------------------------

def faire_jester_laugh_1():
    """A giggling cackle: quick rising hiccups."""
    out = silence(0.9)
    for k in range(5):
        place(out, groan(220 + k * 18, 0.13, glide=0.6, formants=((800, 160), (2000, 280)), rasp=0.3, wobble=0.1), k * 0.15, 0.9 - k * 0.08)
    return out


def faire_jester_laugh_2():
    out = silence(1.0)
    for k in range(6):
        place(out, groan(260 - k * 14, 0.12, glide=-0.5, formants=((850, 170), (2200, 300)), rasp=0.35, wobble=0.12), k * 0.14, 0.85)
    return out


def faire_jester_call():
    """The throw telegraph: a sing-song 'hey-ho!' over jingling bells."""
    d = 0.95
    out = silence(d)
    place(out, groan(180, 0.3, glide=0.5, formants=((700, 150), (1600, 240)), rasp=0.25, wobble=0.08), 0.0, 0.9)
    place(out, groan(240, 0.4, glide=-0.3, formants=((600, 140), (1500, 230)), rasp=0.25, wobble=0.08), 0.32, 0.9)
    place(out, bells(0.6, 8), 0.1, 0.5)
    return out


def faire_jester_jingle():
    """A cartwheel: a whirl of bells and a whoosh."""
    d = 0.7
    out = silence(d)
    place(out, bells(0.6, 12, 3000.0), 0.0, 0.7)
    t = t_axis(0.5)
    place(out, band(noise(0.5), 1300, 900) * np.exp(-((t - 0.2) / 0.12) ** 2), 0.0, 0.8)
    return out


def faire_pin_throw():
    """A juggling pin flung: a twirling whoosh and a wooden clack."""
    d = 0.5
    t = t_axis(d)
    whirl = band(noise(d), 1500, 900) * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * t)) * env(d, 0.02, 0.4, power=1.0)
    out = whirl * 0.8
    place(out, clunk(520, 0.08), 0.0, 0.5)
    return out


# ---------------------------------------------------------------------------
# The Black Knight
# ---------------------------------------------------------------------------

def faire_bknight_grunt_1():
    return helmet(groan(62, 0.9, glide=-0.2, formants=((360, 100), (760, 150)), rasp=0.55, wobble=0.05), 0.009, 0.5)


def faire_bknight_grunt_2():
    return helmet(groan(56, 1.0, glide=0.12, formants=((330, 95), (700, 140)), rasp=0.6, wobble=0.06), 0.009, 0.5)


# ---------------------------------------------------------------------------
# The siege engines (the catapult twist and the Black Knight's call)
# ---------------------------------------------------------------------------

def faire_siege_horn():
    """The engines are loosed: a long two-note war horn over a drum roll."""
    d = 2.2
    out = silence(d)
    for f, at, ln in ((147.0, 0.0, 0.9), (196.0, 0.95, 1.1)):
        tt = t_axis(ln)
        horn = np.tanh(2.0 * (np.sin(2 * np.pi * f * tt) + 0.5 * np.sin(2 * np.pi * 2 * f * tt) + 0.2 * np.sin(2 * np.pi * 3 * f * tt)))
        place(out, filt(horn, low=1600) * adsr(ln, 0.1, 0.2, 0.8, 0.2), at, 0.55)
    for k in range(16):
        place(out, war_drum(70.0, 0.3), 0.6 + k * 0.08, 0.12 + 0.02 * (k % 4))
    return out


def faire_boulder_whistle():
    """A boulder on its way: a rope creak, then a falling whistle."""
    d = 1.6
    out = silence(d)
    creak = filt(sweep(200, 280, 0.35, "saw", 0.6), low=1500, high=150) * env(0.35, 0.05, 0.3, power=1.0)
    place(out, creak, 0.0, 0.25)
    whistle = sweep(1500, 700, 1.1, "sine", 0.8) * env(1.1, 0.25, 1.1, power=0.5, release=0.05)
    place(out, whistle, 0.45, 0.5)
    return out


def faire_boulder_impact():
    """A boulder lands: a deep thump and tumbling rubble."""
    d = 0.9
    out = silence(d)
    place(out, sweep(120, 38, 0.5, "sine", 0.5) * env(0.5, 0.001, 0.45, power=2.0), 0.0, 1.4)
    for k in range(9):
        place(out, band(noise(0.05), rng.uniform(500, 1600), 500) * env(0.05, 0.002, power=1.4), 0.04 + k * 0.06, 0.45 - 0.04 * k)
    return out


SOUNDS = [
    faire_knight_grunt_1, faire_knight_grunt_2, faire_shield_clang, faire_shield_break, faire_knight_rap, faire_knight_charge,
    faire_knight_bash, faire_jester_laugh_1, faire_jester_laugh_2, faire_jester_call, faire_jester_jingle, faire_pin_throw,
    faire_bknight_grunt_1, faire_bknight_grunt_2, faire_siege_horn, faire_boulder_whistle, faire_boulder_impact,
]

VARIANTS = []

LOOPS = {}

MUSIC = {
    "faire_loop": faire_loop,
    "faire_final": lambda: faire_loop(intense=True),
    "faire_ambience": faire_ambience,
}
