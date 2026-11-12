"""Neon Rooftops (World 2) audio pack: a synthwave loop and its final-wave
variant, the rain-and-city ambience bed, zombie voices and the behaviour sounds (spray can, hover leap,
riot shield). Everything is synthesised; generate with

    python tools/gen_audio.py neon
"""
from gen_audio import *  # noqa: F401,F403
import gen_audio as ga


def _rng():
    return ga.rng


# ---------------------------------------------------------------------------
# Voices
# ---------------------------------------------------------------------------

def neon_punk_jeer_1():
    """A jeering, sing-song 'heyyy'."""
    return groan(150, 0.75, glide=0.35, formants=((720, 150), (1650, 260)), rasp=0.35, wobble=0.07)


def neon_punk_jeer_2():
    """Groan that breaks into a three-beat cackle."""
    out = silence(1.0)
    place(out, groan(128, 0.5, glide=-0.25, formants=((640, 140), (1450, 240)), rasp=0.4), 0.0, 1.0)
    for i in range(3):
        place(out, groan(190 - i * 12, 0.13, glide=-0.2, formants=((800, 160), (1900, 280)), rasp=0.5, wobble=0.0), 0.5 + i * 0.15, 0.8)
    return out


def _bleeps(seconds, start_hz, count, gain=0.35):
    out = silence(seconds)
    for i in range(count):
        f = start_hz * (1.0 + 0.18 * ((i * 7) % 5))
        place(out, blip(f, 0.06, "square", 0.05), i * seconds / count, gain)
    return out


def neon_courier_chirp_1():
    """Screech with a delivery-bot bleep riding on top."""
    d = 0.55
    out = groan(360, d, glide=0.55, formants=((1000, 220), (2300, 380)), rasp=0.45, wobble=0.1)
    return out + filt(_bleeps(d, 1700, 4), low=6000)


def neon_courier_chirp_2():
    d = 0.45
    out = groan(420, d, glide=-0.35, formants=((1150, 230), (2600, 400)), rasp=0.5, wobble=0.12)
    return out + filt(_bleeps(d, 2100, 3, 0.3), low=6000)


def _radio(x):
    """Walkie-talkie colour: band-limited, crunchy, squelch clicks at both ends."""
    y = crush(filt(x, low=2600, high=450) * 2.5, 2.2)
    out = np.concatenate([silence(0.05), y, silence(0.08)])
    place(out, filt(noise(0.04), high=2000) * env(0.04, 0.001, power=1.5), 0.0, 0.6)
    place(out, filt(noise(0.06), high=1500) * env(0.06, 0.001, power=1.2), 0.05 + len(y) / SR, 0.5)
    return out


def neon_riot_bark_1():
    """Growl through a riot helmet radio."""
    g = groan(68, 1.0, glide=-0.18, formants=((420, 120), (900, 170)), rasp=0.55, wobble=0.05)
    static = band(noise(1.0), 1800, 900) * env(1.0, 0.02, 1.0, power=0.5) * 0.25
    return _radio(g + static)


def neon_riot_bark_2():
    g = groan(76, 0.8, glide=0.25, formants=((460, 130), (950, 180)), rasp=0.6, wobble=0.06)
    static = band(noise(0.8), 2200, 900) * env(0.8, 0.02, 0.8, power=0.5) * 0.25
    return _radio(g + static)


# ---------------------------------------------------------------------------
# Attacks and behaviours
# ---------------------------------------------------------------------------

def _clang(d=0.5, base=340.0, gain=1.0):
    """Inharmonic metallic strike."""
    t = t_axis(d)
    out = np.zeros_like(t)
    for ratio, decay, g in ((1.0, 0.35, 1.0), (2.43, 0.22, 0.6), (3.71, 0.16, 0.45), (5.89, 0.1, 0.3)):
        out += np.sin(2 * np.pi * base * ratio * t) * np.exp(-t / decay) * g
    out += filt(noise(d), high=2500) * env(d, 0.0005, 0.03, power=2.0) * 0.6
    return out * gain


def neon_punk_swipe():
    """Whoosh with a spray-can rattle in the fist."""
    out = zombie_swipe()
    out = np.pad(out, (0, int(SR * 0.35) - len(out)))
    for i in range(3):
        place(out, click(0.02, 3200, 0.6), 0.03 + i * 0.05, 0.5)
    return out


def neon_riot_bash():
    """Shield bash: heavy thud plus a ringing clang."""
    d = 0.7
    out = silence(d)
    place(out, zombie_swipe(), 0.0, 0.7)
    place(out, sweep(110, 32, 0.45, "sine", 0.4) * env(0.45, 0.001, 0.32, power=1.8), 0.15, 1.5)
    place(out, _clang(0.5, 260, 0.7), 0.15, 1.0)
    return crush(out, 1.3)


def neon_spray_rattle():
    """The spray can being shaken: the mixing ball clacking back and forth."""
    d = 0.9
    out = silence(d)
    for i in range(11):
        at = i * 0.075 + (0.012 if i % 2 else 0.0)
        place(out, click(0.03, 2800 + 400 * (i % 3), 1.0), at, 0.7 - 0.02 * i)
        place(out, tone(1900, 0.05, "sine") * env(0.05, 0.001, power=2.5), at, 0.15)
    return out


def neon_spray_hiss():
    """Short aerosol burst."""
    d = 0.3
    hiss = filt(noise(d), high=3500, low=12000) * env(d, 0.005, 0.28, power=0.9, release=0.05)
    spit = filt(noise(0.04), high=1500) * env(0.04, 0.001, power=2.0)
    out = hiss * 0.9
    place(out, spit, 0.0, 0.5)
    return out


def neon_leap_charge():
    """Hover boots spooling up: rising whine with a tremolo and a whoosh."""
    d = 0.65
    t = t_axis(d)
    whine = sweep(280, 1900, d, "square", 1.6) * 0.25 + sweep(560, 3800, d, "sine", 1.6) * 0.3
    whine *= 0.7 + 0.3 * np.sin(2 * np.pi * 26 * t)
    air = band(noise(d), 1200, 700) * np.clip(t / d, 0, 1) ** 2 * 0.8
    return filt(whine + air, low=9000) * env(d, 0.05, d * 1.6, power=0.6, release=0.04)


def neon_leap_land():
    """Landing slam: sub thump, electric zap and a grating clank."""
    d = 0.6
    out = silence(d)
    place(out, sweep(130, 34, 0.45, "sine", 0.4) * env(0.45, 0.001, 0.35, power=1.8), 0.0, 1.5)
    place(out, filt(noise(0.2), low=1500) * env(0.2, 0.001, 0.1, power=2.0), 0.0, 0.9)
    zap = sweep(2400, 300, 0.18, "square", 0.6) * env(0.18, 0.001, 0.15, power=1.5)
    place(out, filt(zap, low=7000), 0.01, 0.35)
    place(out, _clang(0.3, 520, 0.4), 0.02, 1.0)
    return crush(out, 1.4)


def neon_shield_block():
    """A shot pinging off the riot shield."""
    d = 0.3
    out = _clang(d, 820, 0.7)
    out += sweep(3200, 1800, d, "sine", 0.5) * env(d, 0.001, 0.12, power=2.0) * 0.4
    return out


def neon_shield_break():
    """The shield shatters and powers down."""
    d = 1.1
    out = silence(d)
    for i in range(16):
        at = 0.02 * i + 0.003 * (i % 3)
        place(out, band(noise(0.08), 3000 + 450 * (i % 5), 900) * env(0.08, 0.001, power=2.0), at, 0.7 - 0.03 * i)
    place(out, _clang(0.6, 470, 0.8), 0.0, 1.0)
    place(out, sweep(900, 70, 0.8, "saw", 0.7) * env(0.8, 0.01, 0.8, power=1.0) * 0.35, 0.15, 1.0)
    place(out, sweep(160, 40, 0.4, "sine", 0.4) * env(0.4, 0.001, 0.3, power=1.8), 0.0, 1.2)
    return crush(filt(out, low=10000), 1.3)


# ---------------------------------------------------------------------------
# Ambience: rain on the roofs, the city far below
# ---------------------------------------------------------------------------

def neon_ambience():
    """40-second bed: steady rain and droplets, a low city drone with passing
    traffic, a neon transformer buzz, one far siren and a roll of thunder."""
    r = _rng()
    d = 40.0
    t = t_axis(d + 1.5)
    n = len(t)
    rain_l = filt(r.uniform(-1, 1, n), low=7500, high=350)
    rain_r = filt(r.uniform(-1, 1, n), low=7500, high=350)
    gust = 0.8 + 0.2 * np.sin(2 * np.pi * t / 11.0) + 0.08 * np.sin(2 * np.pi * t / 3.3)
    left = rain_l * gust * 0.32
    right = rain_r * np.roll(gust, int(SR * 1.3)) * 0.32
    # Droplets ticking on metal and puddles.
    for _ in range(900):
        at = r.uniform(0, d + 1.0)
        pan = r.uniform(0, 1)
        f = r.uniform(1800, 5200)
        drop = tone(f, 0.04, "sine") * env(0.04, 0.0005, power=3.0) * r.uniform(0.02, 0.08)
        place(left, drop, at, 1 - pan)
        place(right, drop, at, pan)
    # City drone and transformer buzz.
    drone = filt(r.uniform(-1, 1, n), low=180) * 1.6
    hum = sum(np.sin(2 * np.pi * f * t + p) * g for f, g, p in ((50, 0.5, 0), (100, 0.3, 1), (150, 0.15, 2)))
    buzz = osc(2 * np.pi * 120 * t, "square") * 0.015 * (0.7 + 0.3 * (np.sin(2 * np.pi * 0.37 * t) > 0.6))
    left += drone * 0.5 + hum * 0.05 + buzz
    right += drone * 0.5 + hum * 0.05 + buzz * 0.6
    # Traffic swooshes far below.
    for at, pan, length in ((2.0, 0.2, 4.0), (9.5, 0.8, 5.0), (17.0, 0.4, 3.5), (25.0, 0.7, 4.5), (33.0, 0.3, 4.0)):
        sw = band(noise(length), 500, 300) * np.sin(np.pi * t_axis(length) / length) ** 2 * 0.25
        place(left, sw, at, 1 - pan)
        place(right, sw, at, pan)
    # One distant siren and a thunder roll.
    s_len = 6.0
    st = t_axis(s_len)
    siren = osc(2 * np.pi * np.cumsum(780 + 180 * np.sin(2 * np.pi * 0.7 * st)) / SR, "tri")
    siren = filt(siren, low=1800) * np.sin(np.pi * st / s_len) ** 1.5 * 0.05
    place(left, siren, 21.0, 0.4)
    place(right, siren, 21.0, 0.6)
    th_len = 7.0
    thunder = filt(r.uniform(-1, 1, int(SR * th_len)), low=140) * env(th_len, 0.6, th_len, power=1.4) * 1.8
    place(left, thunder, 6.0, 1.0)
    place(right, np.roll(thunder, int(SR * 0.08)), 6.0, 1.0)
    return loopable(np.stack([left, right], axis=1), 1.5)


# ---------------------------------------------------------------------------
# Music: synthwave, 100 BPM, F# minor
# ---------------------------------------------------------------------------

def neon_skyline_loop(intense=False):
    """77-second synthwave loop, 100 BPM in F# minor. Section A (bars 1-16):
    F#m - D - A - E under a pumping pad, rolling bass and a delayed arpeggio.
    Section B (bars 17-32): D - E - C#m - F#m with a soaring saw lead and
    busier drums, so the loop does not repeat every half minute.

    intense=True is the final-wave variant (neon_skyline_final): sixteenth
    hats and claps throughout, crashes and risers, an octave-jumping bass, the
    arp doubled an octave up and a chord-tone anthem lead over section A. Same
    tempo and length, so the game cross-fades between the two in time."""
    bpm = 100.0
    beat = 60.0 / bpm
    bars = 32
    d = bars * 4 * beat
    left, right = silence(d + 2.0), silence(d + 2.0)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    chords_a = [(-15, (0, 3, 7)), (-19, (0, 4, 7)), (-12, (0, 4, 7)), (-17, (0, 4, 7))]
    chords_b = [(-19, (0, 4, 7)), (-17, (0, 4, 7)), (-20, (0, 3, 7)), (-15, (0, 3, 7))]
    kick = sweep(160, 40, 0.28, "sine", 0.45) * env(0.28, 0.001, 0.26, power=1.6)
    place(kick, kick_click(0.4), 0.0)
    hand_clap, crash = clap(), cymbal()
    sn_len = 0.34
    snare = (band(noise(sn_len), 1800, 1400) * 0.9 + tone(185, sn_len) * 0.35) * env(sn_len, 0.001, sn_len * 1.05, power=0.35, release=0.03)
    snare_tail = filt(noise(0.7), low=5000, high=600) * env(0.7, 0.01, 0.7, power=2.0) * 0.35
    hat = filt(noise(0.05), high=7500) * env(0.05, 0.0005, power=2.5)
    open_hat = filt(noise(0.22), high=6500) * env(0.22, 0.001, power=1.5)
    tom = lambda f: sweep(f, f * 0.55, 0.3, "sine", 0.5) * env(0.3, 0.001, 0.28, power=1.4)

    # Sidechain envelope: everything melodic ducks under the kick.
    duck = np.ones(len(left))
    kick_times = [b * beat for b in range(bars * 4)]
    tt = t_axis((len(left)) / SR)
    for kt in kick_times:
        i0 = int(kt * SR)
        seg = tt[: int(beat * SR)]
        duck[i0:i0 + len(seg)] = np.minimum(duck[i0:i0 + len(seg)], 1.0 - 0.55 * np.exp(-seg / 0.11))

    pad_l, pad_r = silence(len(left) / SR), silence(len(left) / SR)
    mel_l, mel_r = silence(len(left) / SR), silence(len(left) / SR)

    def melodic(x, at, gain, pan=0.5):
        place(mel_l, x, at, gain * (1 - pan) * 2)
        place(mel_r, x, at, gain * pan * 2)

    for bar in range(bars):
        section_b = bar >= 16
        root, triad = (chords_b if section_b else chords_a)[(bar // 2) % 4]
        t0 = bar * 4 * beat
        fill = bar % 8 == 7
        if intense and bar % 8 == 0:
            both(crash, t0, 0.11, 0.4)
        if intense and fill:
            both(riser(2 * beat), t0 + 2 * beat, 0.08, 0.6)
        for b in range(4):
            both(kick, t0 + b * beat, 0.62)
            if b in (1, 3):
                both(snare, t0 + b * beat, 0.32)
                both(snare_tail, t0 + b * beat + 0.05, 0.12, 0.3)
                both(snare_tail, t0 + b * beat + 0.09, 0.12, 0.7)
                if intense:
                    both(hand_clap, t0 + b * beat, 0.18, 0.55)
            both(hat, t0 + (b + 0.5) * beat, 0.2, 0.65)
            if section_b or intense:
                both(hat, t0 + (b + 0.25) * beat, 0.09, 0.35)
                both(hat, t0 + (b + 0.75) * beat, 0.09, 0.35)
        both(open_hat, t0 + 3.5 * beat, 0.12, 0.7)
        if intense:
            both(open_hat, t0 + 1.5 * beat, 0.1, 0.3)
        if fill:
            for k, f in enumerate((220, 180, 150, 120)):
                both(tom(f), t0 + (3 + k * 0.25) * beat, 0.35, 0.3 + 0.13 * k)
        # Rolling 16th bass on the root (jumping an octave every beat when intense).
        for s in range(16):
            n = root - 12 + (12 if (s % 4 == 2 if intense else s % 8 == 6) else 0)
            ln = beat * 0.22
            x = tone(note(n), ln, "saw") * env(ln, 0.003, ln * 1.1, power=1.2)
            x = filt(x, low=1100 if intense else 900 if section_b else 650)
            melodic(x, t0 + s * beat * 0.25, 0.32)
        # Lush pad: three detuned saws per chord tone, slow attack.
        ln = 4 * beat
        voice = sum(tone(note(root + s) * dt, ln, "saw") for s in triad for dt in (0.996, 1.0, 1.004))
        voice = filt(voice, low=(1900 if section_b else 1400) + (500 if intense else 0)) * env(ln, 0.35, ln * 2.0, power=0.5, release=0.25)
        place(pad_l, voice, t0, 0.05)
        place(pad_r, np.roll(voice, int(SR * 0.012)), t0, 0.05)
        # Arpeggio with a dotted-eighth ping-pong delay (doubled an octave up when intense).
        pattern = [0, 1, 2, 1, 2, 3, 2, 1] if bar % 2 == 0 else [0, 2, 1, 3, 2, 1, 2, 3]
        tones = list(triad) + [12]
        for e in range(16):
            step = tones[pattern[e % 8]] + (12 if e >= 8 and section_b else 0)
            ln = beat * 0.22
            x = tone(note(root + 12 + step), ln, "square") * env(ln, 0.002, ln * 1.2, power=1.3)
            x = filt(x, low=4000)
            at = t0 + e * beat * 0.25
            melodic(x, at, 0.1, 0.45)
            melodic(x, at + beat * 0.75, 0.05, 0.85)
            melodic(x, at + beat * 1.5, 0.03, 0.15)
            if intense:
                hi = tone(note(root + 24 + step), ln, "square") * env(ln, 0.002, ln, power=1.5)
                melodic(filt(hi, low=6000), at, 0.035, 0.7)
        # Saw lead in section B (and an answer phrase at the end of A); when
        # intense, section A gets an anthem line on the chord tones.
        phrases = {
            0: [(7, 0.0, 1.5), (5, 1.5, 0.5), (4, 2.0, 1.0), (0, 3.0, 1.0)],
            1: [(2, 0.0, 1.0), (4, 1.0, 1.0), (7, 2.0, 2.0)],
            2: [(9, 0.0, 1.0), (7, 1.0, 0.5), (4, 1.5, 0.5), (7, 2.0, 1.5), (9, 3.5, 0.5)],
            3: [(12, 0.0, 2.0), (11, 2.0, 1.0), (7, 3.0, 1.0)],
        }
        lead = None
        if section_b or bar in (14, 15):
            lead = phrases[bar % 4]
        elif intense:
            lead = [(triad[2], 0.0, 1.5), (triad[1], 1.5, 0.5), (triad[0] + 12, 2.0, 2.0)] if bar % 2 == 0 \
                else [(triad[1], 0.0, 1.0), (triad[2], 1.0, 1.0), (triad[1], 2.0, 2.0)]
        for semis, at, length in lead or ():
            ln = length * beat * 0.95
            x = sum(tone(note(root + 12 + semis) * dt, ln, "saw", 0.008, 5.5) for dt in (0.997, 1.003))
            x = filt(x, low=3400) * env(ln, 0.02, ln * 1.5, power=0.7, release=0.06)
            melodic(x, t0 + at * beat, 0.085, 0.5)
            melodic(x, t0 + at * beat + beat * 0.75, 0.035, 0.2)
            melodic(x, t0 + at * beat + beat * 0.75, 0.035, 0.8)

    left += (pad_l + mel_l) * duck
    right += (pad_r + mel_r) * duck
    return fold_loop(left, right, d)


SOUNDS = [
    neon_punk_jeer_1, neon_punk_jeer_2, neon_courier_chirp_1, neon_courier_chirp_2, neon_riot_bark_1, neon_riot_bark_2,
    neon_punk_swipe, neon_riot_bash, neon_spray_rattle, neon_spray_hiss, neon_leap_charge, neon_leap_land,
    neon_shield_block, neon_shield_break,
]

VARIANTS = [
    (neon_punk_jeer_1, (0.92, 1.08)), (neon_courier_chirp_1, (0.9, 1.1)), (neon_riot_bark_1, (0.93, 1.06)),
    (neon_spray_hiss, (0.9, 1.12)), (neon_shield_block, (0.92, 1.1)), (neon_leap_land, (0.92, 1.06)),
]

MUSIC = {
    "neon_skyline_loop": neon_skyline_loop,
    "neon_skyline_final": lambda: neon_skyline_loop(intense=True),
    "neon_ambience": neon_ambience,
}
