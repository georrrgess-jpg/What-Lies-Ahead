"""Sugar Rush Factory (World 8) sound pack: Candy Works music and ambience, the
Gummy Bear, Taffy Puller and Confectioner voices, the taffy whirl and lash, the
gummy wobble and the Sugar Rush siren.

    python tools/gen_audio.py candy

    audio/music/candy_works_loop.ogg    30 s bouncy candy-pop loop at 128 BPM in C:
                                        music box, marimba, a springy bass and
                                        toy-box drums, two sections and a turnaround
    audio/music/candy_works_final.ogg   its final-wave variant (claps, crashes, a
                                        gallop bass and a doubled melody)
    audio/music/candy_ambience.ogg      the factory floor: a machine hum, the clatter
                                        of the belts, steam hisses, a far ding and
                                        the bubbling chocolate river
    audio/sfx/candy_*.wav               enemy and effect sounds
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def music_box(freq, seconds, gain=1.0):
    """A plucked comb tine: bright FM attack, a pure ringing tail."""
    t = t_axis(seconds)
    index = 1.8 * np.exp(-t * 18.0) + 0.15
    car = np.sin(2 * np.pi * freq * t + np.sin(2 * np.pi * freq * 4.0 * t) * index)
    return car * env(seconds, 0.001, seconds * 0.7, power=2.2) * gain


def marimba(freq, seconds, gain=1.0):
    """Wooden bar: a fundamental and a quick fourth partial, soft mallet."""
    t = t_axis(seconds)
    x = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 3.9 * t) * np.exp(-t * 30.0)
    return x * env(seconds, 0.002, seconds * 0.45, power=2.0) * gain


def spring_bass(freq, seconds):
    """A round bass with a little upward 'boing' at the start of each note."""
    t = t_axis(seconds)
    f = freq * (1.0 + 0.06 * np.exp(-t * 40.0))
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) * 0.9 + osc(ph, "tri") * 0.4
    return filt(x, low=1000) * env(seconds, 0.004, seconds * 0.85, power=1.3)


def soft_pad(semis, seconds):
    out = sum(tone(note(s), seconds, "tri", 0.003, 4.0 + i * 0.6) for i, s in enumerate(semis))
    return filt(out, low=1800) * env(seconds, seconds * 0.2, seconds * 1.5, power=0.6, release=seconds * 0.2)


def boing(seconds=0.28, f0=220, f1=620):
    """A spring 'boing' (the toy-box accent)."""
    t = t_axis(seconds)
    f = f0 + (f1 - f0) * (1 - np.exp(-t * 18.0)) + 30 * np.sin(2 * np.pi * 18 * t) * np.exp(-t * 8)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(seconds, 0.002, seconds * 0.8, power=1.6)


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

# I-vi-IV-V in section A; IV-V-iii-vi then ii-V in section B (roots from A4).
CHORDS_A = [(-9, (0, 4, 7)), (-12, (0, 3, 7)), (-16, (0, 4, 7)), (-14, (0, 4, 7))]     # C Am F G
CHORDS_B = [(-16, (0, 4, 7)), (-14, (0, 4, 7)), (-17, (0, 3, 7)), (-12, (0, 3, 7))]    # F G Em Am
TURN = [(-19, (0, 3, 7)), (-14, (0, 4, 7)), (-9, (0, 4, 7)), (-14, (0, 4, 7))]          # Dm G C G
# The hook: (semitones above C5 = 3, start in beats, length in beats), one bar each.
HOOK = [
    [(7, 0.0, 0.5), (4, 0.5, 0.5), (7, 1.0, 0.5), (12, 1.5, 1.0), (11, 2.5, 0.5), (9, 3.0, 1.0)],
    [(9, 0.0, 0.5), (7, 0.5, 0.5), (4, 1.0, 1.0), (0, 2.0, 0.5), (2, 2.5, 0.5), (4, 3.0, 1.0)],
    [(5, 0.0, 0.5), (9, 0.5, 0.5), (12, 1.0, 1.0), (9, 2.0, 0.5), (7, 2.5, 0.5), (5, 3.0, 1.0)],
    [(7, 0.0, 1.0), (11, 1.0, 0.5), (14, 1.5, 0.5), (12, 2.0, 1.0), (11, 3.0, 1.0)],
]


def candy_works_loop(intense=False):
    """128 BPM, C major, 16 bars. Section A (bars 1-8): the music-box hook over
    C - Am - F - G with marimba off-beats and a springy bass. Section B (9-12):
    F - G - Em - Am with the hook up an octave on marimba and the music box
    sparkling arpeggios, boings on every fourth bar. Turnaround (13-16):
    Dm - G - C - G with a rising run back to the top.

    intense=True (candy_works_final): claps, crashes and risers, sixteenth hats,
    a galloping bass, the hook doubled an octave up. Same tempo and length."""
    bpm = 128.0
    beat = 60.0 / bpm
    bars = 16
    d = bars * 4 * beat
    left, right = silence(d + 2.0), silence(d + 2.0)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    kick = sweep(150, 45, 0.18, "sine", 0.45) * env(0.18, 0.001, power=2.2)
    place(kick, kick_click(0.25), 0.0)
    snare = (band(noise(0.16), 2200, 1200) * 0.8 + tone(230, 0.16) * 0.45) * env(0.16, 0.001, power=2.4)
    hat = filt(noise(0.035), high=8500) * env(0.035, 0.0005, power=2.8)
    shaker = band(noise(0.07), 6000, 2500) * env(0.07, 0.01, 0.06, power=1.5)
    hand_clap, crash = clap(), cymbal()
    spring = boing()
    for bar in range(bars):
        section = 0 if bar < 8 else (1 if bar < 12 else 2)
        root, triad = (CHORDS_A, CHORDS_B, TURN)[section][bar % 4]
        t0 = bar * 4 * beat
        if intense and bar % 4 == 0:
            both(crash, t0, 0.1, 0.6)
        if bar == bars - 1 or (intense and bar % 8 == 7):
            both(riser(2 * beat), t0 + 2 * beat, 0.08, 0.4)
        for b in range(4):
            both(kick, t0 + b * beat, 0.58)
            if b in (1, 3):
                both(snare, t0 + b * beat, 0.3)
                if intense:
                    both(hand_clap, t0 + b * beat, 0.16, 0.45)
            for h in range(4 if intense else 2):
                step = b + h / (4 if intense else 2)
                both(hat, t0 + step * beat, 0.06 if h % 2 == 0 else 0.09, 0.65)
            both(shaker, t0 + (b + 0.5) * beat, 0.08, 0.3)
            # Marimba on the off-beats: the chord's third and fifth.
            for k, s in enumerate(triad[1:]):
                both(marimba(note(root + 12 + s), beat * 0.45, 0.6), t0 + (b + 0.5) * beat, 0.12, 0.3 + 0.4 * k)
        if bar % 4 == 3 and section != 2:
            both(spring, t0 + 3.5 * beat, 0.16, 0.7)
        # Bass: root on the beat, octave on the "and" (a gallop when intense).
        steps = 16 if intense else 8
        for e in range(steps):
            n = root - 12 + (12 if e % 4 == (2 if intense else 1) else 0) + (7 if e % 8 == 6 else 0)
            ln = beat * 4 / steps * 0.85
            both(spring_bass(note(n), ln), t0 + e * beat * 4 / steps, 0.48 if intense else 0.52)
        both(soft_pad([root + s for s in triad], 4 * beat), t0, 0.13)
        # The hook: music box in A, marimba an octave up in B; arpeggios in the turnaround.
        if section < 2:
            for semis, at, length in HOOK[bar % 4]:
                f = note(semis + 3 + (12 if section == 1 else 0))
                voice = music_box(f, length * beat * 1.4, 1.0) if section == 0 else marimba(f, length * beat * 1.2, 1.0)
                both(voice, t0 + at * beat, 0.22, 0.55)
                if intense:
                    both(music_box(f * 2.0, length * beat * 1.2, 0.5), t0 + at * beat, 0.1, 0.45)
            if section == 1:
                for e in range(8):
                    semis = root + 24 + triad[e % 3] + (12 if e >= 4 else 0)
                    both(music_box(note(semis), beat * 0.6, 0.45), t0 + e * beat * 0.5, 0.11, 0.2 + 0.6 * (e / 7.0))
        else:
            run = [0, 1, 2, 1, 0, 1, 2, 2] if bar < bars - 1 else [0, 1, 2, 0, 1, 2, 0, 2]
            for e in range(8):
                semis = root + 12 + triad[run[e]] + (12 if e >= 4 else 0) + (12 if bar == bars - 1 and e >= 6 else 0)
                both(music_box(note(semis), beat * 0.7, 0.8), t0 + e * beat * 0.5, 0.18, 0.3 + 0.4 * (e / 7.0))
    return fold_loop(left, right, d)


def candy_ambience():
    """16 s seamless bed: the hall's machine hum, belts clattering, steam
    hisses, the chocolate river bubbling and a far-off bell."""
    d = 16.0
    n = int(SR * (d + 1.0))
    t = np.arange(n) / SR
    hum = (np.sin(2 * np.pi * 110 * t) * 0.4 + np.sin(2 * np.pi * 220 * t) * 0.25 + np.sin(2 * np.pi * 330 * t) * 0.1)
    hum *= 0.55 + 0.1 * np.sin(2 * np.pi * t / 6.0)
    air = filt(rng.uniform(-1, 1, n), low=900, high=60) * 0.5
    left = hum * 0.12 + air
    right = hum * 0.11 + filt(rng.uniform(-1, 1, n), low=900, high=60) * 0.5
    # Belt rollers: a steady soft clatter, panned apart.
    for side, rate, buf in ((0, 7.5, left), (1, 6.4, right)):
        k = 0.0
        while k < d:
            place(buf, band(noise(0.03), 1500 + 300 * side, 700) * env(0.03, 0.001, power=2.0), k, 0.05 * rng.uniform(0.6, 1.0))
            k += 1.0 / rate
    # Chocolate river: low bubbling plops.
    for _ in range(46):
        at = rng.uniform(0.0, d)
        f = rng.uniform(140, 320)
        plop = sweep(f, f * 1.8, 0.09, "sine", 0.6) * env(0.09, 0.004, 0.08, power=1.8)
        place(left if rng.random() < 0.5 else right, filt(plop, low=900), at, 0.12)
    # Steam vents and a far bell.
    for at in (2.5, 10.0):
        hiss = band(noise(1.4), 4200, 2600) * env(1.4, 0.08, 1.4, power=0.9, release=0.4)
        place(left, hiss, at, 0.09)
        place(right, hiss, at + 0.05, 0.06)
    for at in (6.0,):
        ding = music_box(note(15), 2.2, 1.0) + music_box(note(22), 2.2, 0.5)
        place(left, ding, at, 0.05)
        place(right, ding, at + 0.03, 0.07)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


# ---------------------------------------------------------------------------
# Gummy Bear
# ---------------------------------------------------------------------------

def _squelch(d, f0, f1):
    t = t_axis(d)
    f = f0 + (f1 - f0) * t / d
    wet = np.sin(2 * np.pi * np.cumsum(f * (1 + 0.3 * np.sin(2 * np.pi * 23 * t))) / SR)
    return filt(wet, low=1400) * env(d, 0.01, d, power=1.0, release=0.1)


def candy_gummy_squelch_1():
    """A wet, wobbly groan through a mouthful of jelly."""
    d = 0.8
    g = groan(120, d, glide=0.3, formants=((600, 160), (1300, 220)), rasp=0.2, wobble=0.14)
    return g * 0.8 + _squelch(d, 180, 90) * 0.5


def candy_gummy_squelch_2():
    d = 1.0
    g = groan(104, d, glide=-0.2, formants=((520, 140), (1150, 200)), rasp=0.25, wobble=0.18)
    return g * 0.8 + _squelch(d, 120, 220) * 0.45


def candy_gummy_wobble():
    """A hit on jelly: a springy wub-wub that settles."""
    d = 0.45
    t = t_axis(d)
    f = 150 + 70 * np.sin(2 * np.pi * 14 * t) * np.exp(-t * 7)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(d, 0.002, d * 0.8, power=1.4) * 0.9
    place(x, _squelch(0.2, 400, 200), 0.0, 0.25)
    return x


# ---------------------------------------------------------------------------
# Taffy Puller
# ---------------------------------------------------------------------------

def candy_taffy_grunt_1():
    return groan(92, 0.8, glide=-0.25, formants=((440, 130), (950, 180)), rasp=0.45, wobble=0.05)


def candy_taffy_grunt_2():
    return groan(84, 0.9, glide=0.2, formants=((400, 120), (880, 170)), rasp=0.5, wobble=0.06)


def candy_taffy_whirl():
    """The windup: a stretchy whine rising over a rope whooshing round and
    round faster (1.2 s, matching the whirl)."""
    d = 1.25
    t = t_axis(d)
    rate = 3.0 + 6.0 * t / d
    swoosh = band(noise(d), 900, 600) * (0.5 + 0.5 * np.sin(2 * np.pi * np.cumsum(rate) / SR)) ** 2
    whine = sweep(260, 760, d, "saw", 1.3)
    whine = band(whine, 1200, 600) * env(d, 0.2, d * 1.4, power=0.6, release=0.05)
    return swoosh * 1.1 * env(d, 0.05, d * 1.2, power=0.5, release=0.05) + whine * 0.35


def candy_taffy_snap():
    """The lash: a rubbery thwack and a stretchy twang snapping back."""
    d = 0.5
    t = t_axis(d)
    crack = filt(noise(0.05), high=1500) * env(0.05, 0.0004, power=1.6)
    twang_f = 520 * np.exp(-t * 3.0) + 120
    twang = np.sin(2 * np.pi * np.cumsum(twang_f * (1 + 0.04 * np.sin(2 * np.pi * 30 * t))) / SR) * env(d, 0.002, d * 0.7, power=1.4)
    out = twang * 0.7
    place(out, crack, 0.0, 1.0)
    place(out, sweep(160, 60, 0.15, "sine", 0.5) * env(0.15, 0.001, power=2.0), 0.0, 0.6)
    return out


# ---------------------------------------------------------------------------
# The Confectioner and the Sugar Rush
# ---------------------------------------------------------------------------

def candy_chef_laugh_1():
    """A deep, rolling 'ho-ho-ho' groan."""
    d = 1.3
    out = silence(d)
    for i, at in enumerate((0.0, 0.35, 0.7)):
        place(out, groan(82 - i * 4, 0.42, glide=-0.3, formants=((480, 130), (900, 180)), rasp=0.45, wobble=0.04), at, 0.8)
    return out


def candy_chef_laugh_2():
    return groan(70, 1.1, glide=0.25, formants=((420, 120), (820, 170)), rasp=0.55, wobble=0.09)


def candy_siren():
    """The Sugar Rush alarm: a two-tone factory siren with a candy bell on top."""
    d = 1.8
    t = t_axis(d)
    f = np.where((t * 2.5) % 1.0 < 0.5, 660.0, 880.0)
    siren = osc(2 * np.pi * np.cumsum(f) / SR, "square") * 0.4 + np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.6
    siren = filt(siren, low=3000) * env(d, 0.05, d * 1.2, power=0.6, release=0.3)
    out = siren * 0.6
    for i, s in enumerate((15, 19, 22, 27)):
        place(out, music_box(note(s + 12), 0.8, 1.0), i * 0.12, 0.25)
    return out


SOUNDS = [
    candy_gummy_squelch_1, candy_gummy_squelch_2, candy_gummy_wobble,
    candy_taffy_grunt_1, candy_taffy_grunt_2, candy_taffy_whirl, candy_taffy_snap,
    candy_chef_laugh_1, candy_chef_laugh_2, candy_siren,
]

VARIANTS = [
    (candy_gummy_wobble, (0.9, 1.12)), (candy_taffy_snap, (0.92, 1.08)), (candy_gummy_squelch_1, (0.9, 1.1)),
]

LOOPS = {}

MUSIC = {
    "candy_works_loop": candy_works_loop,
    "candy_works_final": lambda: candy_works_loop(intense=True),
    "candy_ambience": candy_ambience,
}
