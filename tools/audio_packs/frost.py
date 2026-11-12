"""Frostpeak Resort (World 5) sound pack: Summit Lodge music and ambience, the
Ski Racer, Yeti and Frozen Tourist voices, snowballs, ice and frost clouds.

    python tools/gen_audio.py frost

    audio/music/summit_lodge_loop.ogg   62 s wintry loop, two sections: sleigh bells,
                                        celesta arpeggios and a driving beat
    audio/music/summit_lodge_final.ogg  its final-wave variant (denser drums and bells)
    audio/music/frost_ambience.ogg     mountain wind, a crackling fire pit and the
                                        creak and clunk of the chairlift
    audio/sfx/frost_*.wav               enemy and effect sounds
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def sleigh_bell(seconds=0.35, bright=1.0):
    """A shake of small bells: several detuned metallic pings jittered in time."""
    out = silence(seconds)
    for k in range(5):
        at = rng.uniform(0.0, 0.035)
        d = seconds - at
        base = rng.uniform(2600, 3400) * bright
        ping = sum(tone(base * r, d, "sine") * env(d, 0.0008, d * g, power=2.2) * a
                   for r, g, a in ((1.0, 0.5, 1.0), (1.47, 0.35, 0.6), (2.09, 0.25, 0.45), (2.76, 0.18, 0.3)))
        place(out, ping, at, 0.22)
    place(out, band(noise(seconds), 7000, 2500) * env(seconds, 0.001, 0.08, power=2.0), 0.0, 0.5)
    return out


def celesta(freq, seconds, gain=1.0):
    """FM bell: bright attack that mellows as the modulation index decays."""
    t = t_axis(seconds)
    index = 2.6 * np.exp(-t * 7.0) + 0.3
    mod = np.sin(2 * np.pi * freq * 3.5 * t) * index
    car = np.sin(2 * np.pi * freq * t + mod)
    return car * env(seconds, 0.002, seconds * 0.9, power=1.8) * gain


def pluck_bass(freq, seconds):
    t = t_axis(seconds)
    x = osc(2 * np.pi * freq * t, "saw") * 0.6 + np.sin(2 * np.pi * freq * t) * 0.8
    return filt(x, low=900) * env(seconds, 0.003, seconds * 0.8, power=1.4)


def pad_chord(semis, seconds):
    out = sum(tone(note(s), seconds, "tri", 0.004, 4.5 + i * 0.7) for i, s in enumerate(semis))
    return filt(out, low=2200) * env(seconds, seconds * 0.25, seconds * 1.6, power=0.6, release=seconds * 0.2)


# ---------------------------------------------------------------------------
# Music
# ---------------------------------------------------------------------------

def summit_lodge_loop(intense=False):
    """124 BPM, D minor. Section A (bars 1-16): Dm - Bb - F - C with a driving
    beat, sleigh bells on the offbeats and a celesta arpeggio. Section B
    (bars 17-32): Gm - Bb - F - A with a soaring celesta melody, denser bells
    and a sub-bass push, then it turns back to A.

    intense=True is the final-wave variant (summit_lodge_final): sixteenth hats,
    bells on every eighth, claps, crashes and risers throughout, a galloping
    sixteenth bass with a kick pickup, the sub push in both sections and a
    celesta line over section A. Same tempo and length, so
    the game cross-fades between the two in time."""
    bpm = 124.0
    beat = 60.0 / bpm
    bars = 32
    d = bars * 4 * beat
    left, right = silence(d + 2.0), silence(d + 2.0)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    kick = sweep(140, 42, 0.2, "sine", 0.45) * env(0.2, 0.001, power=2.2)
    place(kick, kick_click(0.3), 0.0)
    snare = (band(noise(0.18), 1900, 1000) * 0.8 + tone(205, 0.18) * 0.5) * env(0.18, 0.001, power=2.4)
    hat = filt(noise(0.04), high=8000) * env(0.04, 0.0005, power=2.8)
    bells = [sleigh_bell(0.3, rng.uniform(0.95, 1.06)) for _ in range(6)]
    hand_clap, crash = clap(), cymbal()
    chords_a = [(-7, (0, 3, 7)), (-11, (0, 4, 7)), (-16, (0, 4, 7)), (-9, (0, 4, 7))]      # Dm Bb F C (roots from A4)
    chords_b = [(-14, (0, 3, 7)), (-11, (0, 4, 7)), (-16, (0, 4, 7)), (-12, (0, 4, 7))]    # Gm Bb F A
    for bar in range(bars):
        section_b = bar >= 16
        busy = section_b or intense
        root, triad = (chords_b if section_b else chords_a)[(bar // 2) % 4]
        t0 = bar * 4 * beat
        fill = bar % 8 == 7
        if intense and bar % 8 == 0:
            both(crash, t0, 0.11, 0.6)
        if intense and fill:
            both(riser(2 * beat), t0 + 2 * beat, 0.08, 0.4)
        for b in range(4):
            both(kick, t0 + b * beat, 0.6)
            if b in (1, 3):
                both(snare, t0 + b * beat, 0.32)
                if intense:
                    both(hand_clap, t0 + b * beat, 0.16, 0.45)
            for h in range(4 if busy else 2):
                step = b + h / (4 if busy else 2)
                both(hat, t0 + step * beat, 0.07 if h % 2 == 0 else 0.1, 0.65)
            # Sleigh bells shake on the offbeats (every eighth in section B).
            both(bells[(bar + b) % len(bells)], t0 + (b + 0.5) * beat, 0.2, 0.35)
            if busy:
                both(bells[(bar + b + 3) % len(bells)], t0 + b * beat, 0.11, 0.6)
            if fill and b >= 2:
                for s in range(4):
                    both(snare, t0 + (b + s * 0.25) * beat, 0.16 + 0.04 * s)
        # Driving bass: eighth notes with an octave jump (a sixteenth gallop and
        # a kick pickup when intense).
        steps = 16 if intense else 8
        for e in range(steps):
            n = root - 12 + (12 if (e % 4 == 2 if intense else e % 4 == 3) else 0)
            ln = beat * 4 / steps * 0.9
            both(filt(pluck_bass(note(n), ln), low=1200), t0 + e * beat * 4 / steps, 0.5 if intense else 0.55)
        if intense:
            both(kick, t0 + 3.5 * beat, 0.3)
        if busy and bar % 2 == 0:
            both(sweep(note(root - 24) * 1.02, note(root - 24), 4 * beat, "sine") * env(4 * beat, 0.01, 4 * beat, power=0.8), t0, 0.35)
        # Celesta arpeggio: rising in A, rippling in B.
        pattern = [0, 1, 2, 1, 2, 0, 1, 2] if not section_b else [0, 2, 1, 2, 0, 2, 1, 0]
        for e in range(8):
            semis = root + 12 + triad[pattern[e]] + (12 if e >= 4 else 0)
            both(celesta(note(semis), beat * 0.9, 0.5), t0 + e * beat * 0.5, 0.2, 0.25 + 0.5 * (e / 7.0))
        # Pad.
        both(pad_chord([root + s for s in triad], 4 * beat), t0, 0.16)
        # Section B melody (two-bar phrases).
        if section_b:
            phrases = [
                [(19, 0.0, 1.0), (17, 1.0, 0.5), (15, 1.5, 0.5), (14, 2.0, 2.0)],
                [(12, 0.0, 1.0), (14, 1.0, 1.0), (15, 2.0, 1.0), (17, 3.0, 1.0)],
                [(19, 0.0, 1.5), (22, 1.5, 0.5), (21, 2.0, 1.0), (19, 3.0, 1.0)],
                [(17, 0.0, 1.0), (16, 1.0, 1.0), (13, 2.0, 2.0)],
            ]
            for semis, at, length in phrases[bar % 4]:
                x = celesta(note(semis - 7 + 12), length * beat * 1.2, 1.0) + celesta(note(semis - 7 + 24), length * beat * 1.2, 0.25)
                both(x, t0 + at * beat, 0.24, 0.55)
        elif bar % 4 == 3:
            # A little bell turn at the end of each phrase in section A.
            for i, s in enumerate((12, 15, 19, 24)):
                both(celesta(note(root + s + 12), beat * 0.8, 0.7), t0 + (2 + i * 0.5) * beat, 0.1, 0.7)
        elif intense:
            # A celesta line on the chord tones over the rest of section A.
            line = ((2, 0.0, 1.5), (1, 1.5, 0.5), (0, 2.0, 2.0)) if bar % 2 == 0 else ((1, 0.0, 1.0), (2, 1.0, 1.0), (0, 2.0, 2.0))
            for i, at, length in line:
                semis = root + 24 + triad[i] + (12 if i == 0 and at == 2.0 else 0)
                both(celesta(note(semis), length * beat * 1.2, 1.0), t0 + at * beat, 0.2, 0.55)
    return fold_loop(left, right, d)


def frost_ambience():
    """24 s seamless bed: wind with gusts, a crackling fire pit, chairlift creaks."""
    d = 24.0
    n = int(SR * (d + 1.0))
    t = np.arange(n) / SR
    wind_l = filt(rng.uniform(-1, 1, n), low=700, high=90)
    wind_r = filt(rng.uniform(-1, 1, n), low=700, high=90)
    gust = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.0 - 1.2)) ** 2.5
    gust_r = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.0 + 0.6)) ** 2.5
    whistle = band(rng.uniform(-1, 1, n), 1300, 140) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 12.0)) ** 4 * 0.6
    left = wind_l * gust + whistle * 0.5
    right = wind_r * gust_r + np.roll(whistle, int(SR * 0.4)) * 0.5
    # Fire crackle: sparse pops over a low rumble.
    rumble = filt(rng.uniform(-1, 1, n), low=180) * 0.35
    crackle = np.zeros(n)
    for _ in range(260):
        at = int(rng.uniform(0, n - 3000))
        ln = int(rng.uniform(80, 900))
        pop = band(rng.uniform(-1, 1, ln), rng.uniform(1500, 5000), 1200) * np.exp(-np.arange(ln) / (ln * 0.25))
        crackle[at:at + ln] += pop * rng.uniform(0.15, 0.45)
    left += (rumble + crackle * 0.6) * 0.5
    right += (rumble + crackle * 0.6) * 0.3
    # Chairlift: a chair clunks over the bull wheel, the cable creaks.
    for at in (2.5, 8.5, 14.5, 20.5):
        clank = clunk(95, 0.25, 1.0)
        creak_d = 1.1
        f = 190 * (1 + 0.15 * np.sin(2 * np.pi * 2.3 * t_axis(creak_d)))
        creak = osc(2 * np.pi * np.cumsum(f) / SR, "saw")
        creak = (band(creak, 900, 250) + band(creak, 1900, 300) * 0.6) * env(creak_d, 0.25, creak_d, power=1.0, release=0.3)
        place(left, clank, at, 0.12)
        place(right, clank, at + 0.02, 0.2)
        place(left, creak, at + 0.4, 0.1)
        place(right, creak, at + 0.45, 0.16)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


# ---------------------------------------------------------------------------
# Ski Racer
# ---------------------------------------------------------------------------

def frost_racer_whoop_1():
    return groan(260, 0.6, glide=0.6, formants=((800, 180), (1900, 320)), rasp=0.4, wobble=0.08)


def frost_racer_whoop_2():
    return groan(330, 0.5, glide=-0.35, formants=((950, 200), (2200, 360)), rasp=0.5, wobble=0.1)


def frost_ski_tuck():
    """Crouch into the tuck: a creak of boots and a rising scrape of edges."""
    d = 0.9
    scrape = band(noise(d), 2600, 1400) * env(d, 0.4, d * 1.4, power=0.6, release=0.1)
    rise = sweep(220, 520, d, "saw", 1.4) * env(d, 0.3, d * 1.3, power=0.6, release=0.1)
    out = scrape * 0.8 + filt(rise, low=1600) * 0.35
    place(out, clunk(170, 0.12), 0.0, 0.5)
    return out


def frost_ski_rush():
    """The rush: a fast hiss of skis on snow with a doppler whoosh."""
    d = 1.4
    t = t_axis(d)
    hiss = filt(noise(d), high=2500) * env(d, 0.03, d * 1.2, power=0.8, release=0.2)
    whoosh = sum(band(noise(d), c, 500) * np.exp(-((t - at) / 0.2) ** 2) for c, at in ((900, 0.25), (1800, 0.45), (1100, 0.65)))
    rumble = filt(sweep(160, 60, d, "sine") * env(d, 0.02, d, power=1.2), low=400)
    return hiss * 0.7 + whoosh * 1.4 + rumble * 0.3


# ---------------------------------------------------------------------------
# Yeti
# ---------------------------------------------------------------------------

def frost_yeti_roar():
    """Big rumbling roar with a growly rasp (also the snowball telegraph)."""
    d = 1.3
    body = groan(70, d, glide=0.25, formants=((360, 110), (760, 160)), rasp=0.55, wobble=0.07)
    growl = filt(noise(d), low=500) * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * t_axis(d))) * env(d, 0.08, d, power=0.8, release=0.3)
    return crush(body + growl * 0.6, 1.5)


def frost_yeti_grunt_1():
    return groan(78, 0.7, glide=-0.2, formants=((400, 120), (820, 170)), rasp=0.5, wobble=0.05)


def frost_yeti_grunt_2():
    return groan(66, 0.9, glide=0.1, formants=((340, 100), (700, 150)), rasp=0.55, wobble=0.06)


def frost_snowball_throw():
    """Heave: a grunt and the whoosh of a big snowball leaving the hands."""
    d = 0.6
    out = band(noise(d), 700, 400) * env(d, 0.05, 0.35, power=1.0) * 1.4
    place(out, groan(90, 0.35, glide=-0.3, formants=((450, 120), (900, 170)), rasp=0.5), 0.0, 0.5)
    return out


def frost_snowball_hit():
    """Soft thump and a crunchy burst of snow."""
    d = 0.45
    thump = sweep(150, 50, 0.25, "sine", 0.5) * env(0.25, 0.001, 0.2, power=2.0)
    crunch = band(noise(d), 1800, 1200) * env(d, 0.002, 0.25, power=1.6)
    grains = (rng.uniform(0, 1, int(SR * d)) > 0.992).astype(float) * rng.uniform(-1, 1, int(SR * d))
    out = crunch * 0.9 + filt(grains, low=6000) * 1.5 * env(d, 0.001, 0.3, power=1.2)
    place(out, thump, 0.0, 1.2)
    return out


# ---------------------------------------------------------------------------
# Frozen Tourist, ice and frost
# ---------------------------------------------------------------------------

def frost_frozen_groan_1():
    """Groan through chattering teeth, with an icy creak."""
    d = 1.0
    g = groan(96, d, glide=-0.25, formants=((480, 120), (1000, 180)), rasp=0.3, wobble=0.04)
    chatter = (np.sin(2 * np.pi * 14 * t_axis(d)) > 0.6).astype(float)
    out = g * (0.7 + 0.3 * chatter)
    place(out, band(noise(0.4), 3200, 600) * env(0.4, 0.05, 0.4, power=1.0), 0.3, 0.25)
    return out


def frost_frozen_groan_2():
    return groan(84, 1.2, glide=0.15, formants=((420, 110), (900, 160)), rasp=0.35, wobble=0.09)


def _ice_ping(freq, d, gain):
    return sum(tone(freq * r, d, "sine") * env(d, 0.0005, d * dd, power=2.0) * a
               for r, dd, a in ((1.0, 0.6, 1.0), (2.32, 0.35, 0.5), (3.71, 0.2, 0.3))) * gain


def frost_ice_chip():
    """A glassy tink as a shot chips the ice shell."""
    d = 0.35
    out = _ice_ping(rng.uniform(2400, 3200), d, 0.8)
    place(out, filt(noise(0.03), high=4000) * env(0.03, 0.0003, power=2.0), 0.0, 0.6)
    return out


def frost_ice_shatter():
    """The shell bursts: a crack, a spray of falling shards and a low thud."""
    d = 1.2
    out = silence(d)
    place(out, filt(noise(0.08), high=1500) * env(0.08, 0.0005, power=1.5) * 1.4, 0.0, 1.0)
    place(out, sweep(180, 50, 0.3, "sine", 0.5) * env(0.3, 0.001, power=2.0), 0.0, 0.9)
    for _ in range(26):
        at = rng.uniform(0.02, 0.8)
        place(out, _ice_ping(rng.uniform(1800, 5200), rng.uniform(0.12, 0.35), rng.uniform(0.15, 0.4)), at, 1.0)
    place(out, band(noise(0.9), 4500, 2500) * env(0.9, 0.005, 0.6, power=1.2), 0.02, 0.35)
    return out


def frost_cloud_burst():
    """Freezing mist puffs out: a breathy whoosh and a shimmer."""
    d = 1.1
    whoosh = band(noise(d), 1200, 900) * env(d, 0.05, 0.9, power=0.8, release=0.2)
    shimmer = sum(tone(note(n), d, "sine", 0.006, 7.0) for n in (24, 28, 31, 36)) * env(d, 0.1, d, power=0.8, release=0.3)
    return whoosh * 1.2 + shimmer * 0.12


def frost_chill():
    """Player caught in the frost: a shivering breath and an icy creak."""
    d = 0.8
    breath = band(noise(d), 1800, 900) * env(d, 0.1, 0.7, power=0.8) * (0.7 + 0.3 * np.sin(2 * np.pi * 11 * t_axis(d)))
    creak = sweep(900, 600, d, "saw") * env(d, 0.05, d, power=1.0)
    return breath + band(creak, 1100, 200) * 0.3


SOUNDS = [
    frost_racer_whoop_1, frost_racer_whoop_2, frost_ski_tuck, frost_ski_rush,
    frost_yeti_roar, frost_yeti_grunt_1, frost_yeti_grunt_2, frost_snowball_throw, frost_snowball_hit,
    frost_frozen_groan_1, frost_frozen_groan_2, frost_ice_chip, frost_ice_shatter, frost_cloud_burst, frost_chill,
]

VARIANTS = [
    (frost_ice_chip, (0.9, 1.12)), (frost_snowball_hit, (0.9, 1.1)), (frost_racer_whoop_1, (0.92, 1.1)),
    (frost_frozen_groan_1, (0.9, 1.08)), (frost_yeti_grunt_1, (0.92, 1.06)),
]

MUSIC = {
    "summit_lodge_loop": summit_lodge_loop,
    "summit_lodge_final": lambda: summit_lodge_loop(intense=True),
    "frost_ambience": frost_ambience,
}
