"""Endless mode (Ashfall City) sound pack: the city's music loop and its boss-wave
variant, the ruined-city ambience bed, the burning-wreck crackle and the mode's
cues (gates, districts, waves, supply drops, traps, the boss and a new best).

    python tools/gen_audio.py endless

    audio/music/city_endless_loop.ogg    70 s industrial arcade groove, 110 BPM in
                                         D minor: a stomping kick, anvil snare, a
                                         filter-plucked bass, a catchy square riff,
                                         a far siren and a feedback swell
    audio/music/city_endless_final.ogg   the boss-wave variant: same tempo and length
                                         (the game cross-fades in time), riff all the
                                         way, octave bass, power stabs, claps, risers
    audio/music/city_ambience.ogg        40 s: wind through the ruins, far sirens and
                                         fires, debris settling, metal creaks, crows
    audio/sfx/city_fire_crackle.wav      8 s positional loop for burning wrecks (its .import
                                         sets loop mode Forward, so an AudioStreamPlayer3D
                                         loops it as is; start each wreck at a random offset)
    audio/sfx/end_*.wav                  gate, district, wave, supply, trap, boss and
                                         new-best cues
    audio/sfx/city_*_loop.wav            positional ambient loops (siren, alarm, police
                                         radio, metro drips, neon buzz, helicopter,
                                         arcing cable); loop mode Forward like the crackle
    audio/sfx/city_thunder.wav           thunder after the lightning behind the skyline
    audio/sfx/city_blast_far.wav         a far explosion across the city
"""
import numpy as np

from gen_audio import *  # noqa: F401,F403
import gen_audio as ga


def _r():
    """The generator of whatever is rendering now (render_music seeds it per loop)."""
    return ga.rng


# ---------------------------------------------------------------------------
# Shared voices
# ---------------------------------------------------------------------------

def _metal(base, seconds, decay=0.25, gain=1.0):
    """Inharmonic struck metal (a girder, a shutter rail, an anvil)."""
    t = t_axis(seconds)
    out = np.zeros_like(t)
    for ratio, k, g in ((1.0, 1.0, 1.0), (2.32, 0.62, 0.55), (3.93, 0.4, 0.35), (5.47, 0.27, 0.22)):
        if base * ratio < 7000:
            out += np.sin(2 * np.pi * base * ratio * t + ratio) * np.exp(-t / (decay * k)) * g
    out += band(noise(seconds), 2600, 1300) * env(seconds, 0.0005, 0.02, power=2.0) * 0.5
    return out * gain


def _thud(f0=120.0, f1=38.0, seconds=0.5, decay=0.4):
    """A heavy body landing: a falling sine with a soft knock on top."""
    out = sweep(f0, f1, seconds, "sine", 0.35) * env(seconds, 0.001, decay, power=1.8)
    out += filt(noise(seconds), low=700) * env(seconds, 0.001, 0.05, power=2.0) * 0.7
    return out


def _filter_env(x, bright, dark, decay):
    """A plucked filter: starts open at `bright` Hz and closes to `dark`."""
    t = np.arange(len(x)) / SR
    lo = filt(x, low=dark)
    return lo + (filt(x, low=bright) - lo) * np.exp(-t / decay)


def _horn(semis, seconds, cutoff=1500.0, attack=0.1, droop=0.03):
    """An air horn chord: detuned saw stacks that swell in and sag at the end
    as the pressure runs out."""
    t = t_axis(seconds)
    sag = 1.0 - droop * np.clip((t - seconds * 0.7) / (seconds * 0.3), 0.0, 1.0) ** 2
    out = np.zeros_like(t)
    for s in semis:
        for dt in (0.994, 1.0, 1.006):
            out += bl_osc(note(s) * dt * sag, None, "saw", phase=_r().uniform())
    out = np.tanh(filt(out / len(semis), low=cutoff) * 1.6)
    return out * adsr(seconds, attack, seconds, 1.0, seconds * 0.35)


def _bell(freq, seconds=1.2, gain=1.0):
    """A soft metallic bell for the arcade tags (no partial above 7 kHz)."""
    partials = [(1.0, 1.0, seconds * 0.5), (2.0, 0.35, seconds * 0.3), (2.76, 0.3, seconds * 0.22),
                (4.07, 0.15, seconds * 0.12)]
    partials = [p for p in partials if freq * p[0] < 7000]
    return additive(freq, seconds, partials) * adsr(seconds, 0.002, seconds, 1.0, 0.03) * gain


def _whoosh(seconds, f0, f1, width=0.6):
    """Air moving past: a noise band sweeping from f0 to f1 Hz, bell-shaped."""
    n = int(SR * seconds)
    hops = 24
    out = np.zeros(n)
    win = np.hanning(2 * (n // hops) + 2)
    for k in range(hops):
        c = f0 + (f1 - f0) * k / (hops - 1)
        seg = band(_r().uniform(-1, 1, len(win)), c, c * width) * win
        place(out, seg, k * (n // hops) / SR)
    return out * np.sin(np.pi * np.linspace(0, 1, n)) ** 1.5


def _chain(seconds, rate=18.0, gain=1.0):
    """A chain or shutter slats rattling: many small irregular metal clicks."""
    out = silence(seconds)
    r = _r()
    at = 0.0
    while at < seconds - 0.03:
        f = r.uniform(1400, 3600)
        clink = (np.sin(2 * np.pi * f * t_axis(0.03)) * 0.6 + band(noise(0.03), f, 600)) * env(0.03, 0.0005, 0.025, power=2.5)
        place(out, clink, at, r.uniform(0.4, 1.0))
        at += r.uniform(0.5, 1.5) / rate
    return out * gain


def _crackles(n, rate, rng_, loud=1.0):
    """Burning-wood crackle: short resonant ticks and the odd pop, scattered
    (circularly) over n samples."""
    out = np.zeros(n + int(SR * 0.1))
    count = int(rate * n / SR)
    for _ in range(count):
        at = rng_.uniform(0, n / SR)
        d = rng_.uniform(0.002, 0.007)
        f = rng_.uniform(1800, 5200)
        tick = band(rng_.uniform(-1, 1, int(SR * d) + 32), f, f * 0.4) * np.exp(-np.arange(int(SR * d) + 32) / (SR * d * 0.4))
        place(out, tick, at, rng_.uniform(0.2, 1.0) ** 2 * loud * 3.0)
    for _ in range(max(1, count // 25)):
        at = rng_.uniform(0, n / SR)
        f = rng_.uniform(140, 320)
        pop = np.sin(2 * np.pi * f * t_axis(0.05)) * np.exp(-t_axis(0.05) / 0.012)
        pop += band(rng_.uniform(-1, 1, len(pop)), 1500, 900) * np.exp(-t_axis(0.05) / 0.006)
        place(out, pop, at, rng_.uniform(0.4, 0.9) * loud)
    out[: len(out) - n] += out[n:]
    return out[:n]


# ---------------------------------------------------------------------------
# Music: industrial arcade, 110 BPM, D minor
# ---------------------------------------------------------------------------

BPM = 110.0
BEAT = 60.0 / BPM
BARS = 32

# Two bars per chord: (root semitones from A4, chord tones).
CHORDS_A = [(-19, (0, 3, 7)), (-23, (0, 4, 7)), (-21, (0, 4, 7)), (-24, (0, 4, 7))]   # Dm  Bb  C  A
CHORDS_B = [(-26, (0, 3, 7)), (-23, (0, 4, 7)), (-28, (0, 4, 7)), (-24, (0, 4, 7))]   # Gm  Bb  F  A

# The hook: (semitones from A4, beat, length in beats), one list per bar of the 8-bar phrase.
RIFF = [
    [(12, 0, 0.5), (8, 0.5, 0.5), (5, 1, 0.5), (8, 1.5, 0.5), (12, 2, 0.75), (10, 2.75, 0.75), (8, 3.5, 0.5)],
    [(7, 0, 0.5), (8, 0.5, 0.5), (5, 1, 1.5), (0, 3, 1)],
    [(13, 0, 0.5), (10, 0.5, 0.5), (5, 1, 0.5), (10, 1.5, 0.5), (13, 2, 0.75), (12, 2.75, 0.75), (10, 3.5, 0.5)],
    [(8, 0, 0.5), (10, 0.5, 0.5), (5, 1, 1.5), (1, 3, 1)],
    [(15, 0, 0.5), (12, 0.5, 0.5), (7, 1, 0.5), (12, 1.5, 0.5), (15, 2, 0.75), (13, 2.75, 0.75), (12, 3.5, 0.5)],
    [(10, 0, 0.5), (12, 0.5, 0.5), (7, 1, 1.5), (3, 3, 1)],
    [(16, 0, 0.75), (12, 0.75, 0.75), (13, 1.5, 0.5), (12, 2, 0.5), (7, 2.5, 0.5), (4, 3, 1)],
    [(4, 0, 0.5), (7, 0.5, 0.5), (12, 1, 1.5), (16, 2.5, 0.5), (17, 3, 1)],
]
# Section B's long lead over Gm - Bb - F - A, one list per bar of its 8-bar phrase.
ANTHEM = [
    [(10, 0, 2), (13, 2, 2)], [(12, 0, 3), (10, 3, 1)],
    [(8, 0, 2), (10, 2, 2)], [(13, 0, 4)],
    [(12, 0, 2), (15, 2, 2)], [(17, 0, 3), (15, 3, 1)],
    [(16, 0, 2), (13, 2, 1), (12, 3, 1)], [(12, 0, 4)],
]


def _kick():
    k = sweep(160, 52, 0.34, "sine", 0.4) * env(0.34, 0.001, 0.3, power=1.7)
    k += np.tanh(sweep(160, 52, 0.34, "sine", 0.4) * 3.0) * env(0.34, 0.001, 0.06, power=2.0) * 0.25
    place(k, kick_click(0.5, 2600), 0.0)
    return k


def _anvil_snare():
    """Snare with a struck-metal layer: the city's backbeat."""
    d = 0.36
    sn = (band(noise(d), 1900, 1300) * 0.9 + tone(195, d) * 0.35) * env(d, 0.001, d, power=0.45, release=0.03)
    place(sn, filt(_metal(410, 0.3, 0.12), low=6000), 0.0, 0.35)
    return sn


def _hat(d=0.045, gain=1.0):
    return filt(noise(d), high=6000, low=11000) * env(d, 0.0005, power=2.4) * gain


def _bass(semis, length, bright=1500.0):
    f = note(semis)
    x = bl_osc(f, length, "saw") * 0.6 + bl_osc(f, length, "square", 0.3) * 0.3
    x = _filter_env(x, bright, 320, 0.05) * adsr(length, 0.003, length, 1.0, 0.02)
    return audible_bass(x, 0.35)


def _pluck(semis, length, bright=3200.0):
    f = note(semis)
    x = bl_osc(f, length, "square", 0.35) * 0.7 + bl_osc(f * 1.003, length, "saw") * 0.3
    return _filter_env(x, bright, 900, 0.12) * adsr(length, 0.003, 0.22, 0.35, 0.03)


def _lead(semis, length, cutoff=2600.0):
    """Section B's singing saw lead, with a delayed vibrato."""
    t = t_axis(length)
    f = note(semis) * (1.0 + 0.007 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.15) / 0.3, 0.0, 1.0))
    return filt(supersaw(f, length, 3, 0.1), low=cutoff) * adsr(length, 0.025, length * 0.8, 0.75, 0.08)


def _pad(root, triad, length, cutoff=1200.0):
    x = sum(supersaw(note(root + 12 + s), length, 3, 0.15) for s in triad)
    return filt(x, low=cutoff) * adsr(length, 0.45, length, 1.0, 0.35)


def _siren(length, lo, hi, period):
    """A siren a few blocks away: a slow two-way glide, rounded and low-passed."""
    t = t_axis(length)
    f = lo + (hi - lo) * (0.5 - 0.5 * np.cos(2 * np.pi * t / period))
    x = additive(f, None, [(1.0, 1.0, None), (2.0, 0.3, None), (3.0, 0.12, None)])
    return filt(x, low=1500) * adsr(length, length * 0.25, length, 1.0, length * 0.3)


def _feedback(semis, length):
    """Guitar-amp feedback swelling in: a pure tone with its octave, wavering."""
    t = t_axis(length)
    f = note(semis) * (1.0 + 0.004 * np.sin(2 * np.pi * 4.3 * t) * (t / length))
    x = additive(f, None, [(1.0, 1.0, None), (2.0, 0.25, None), (3.0, 0.06, None)])
    return filt(x, low=2200) * adsr(length, length * 0.65, length, 1.0, length * 0.2)


def _stab(root, length=0.22):
    """A distorted power chord (root, fifth, octave)."""
    x = sum(supersaw(note(root + s), length, 3, 0.12) for s in (0, 7, 12))
    return filt(np.tanh(x * 1.4), low=2300) * adsr(length, 0.004, length * 0.5, 0.3, 0.05)


def _tom(f):
    return sweep(f, f * 0.55, 0.32, "sine", 0.5) * env(0.32, 0.001, 0.3, power=1.4)


def city_endless_loop(intense=False):
    """70-second loop, 110 BPM in D minor, 32 bars. Section A (bars 1-16):
    Dm - Bb - C - A under a stomping kick, an anvil backbeat and a plucked
    bass; the square riff joins at bar 9, a far siren wails at bar 5.
    Section B (bars 17-32): Gm - Bb - F - A with a soaring saw lead over a
    pluck arpeggio, busier hats and the feedback swell into the turnaround.

    intense=True is the boss-wave variant (city_endless_final): the riff from
    the first bar (doubled an octave up), sixteenth hats, claps, an octave
    bass, power stabs, crashes, risers and tom fills. Same tempo and length,
    so the game cross-fades between the two in time."""
    d = BARS * 4 * BEAT
    drums, music, lead, send = Bus(d), Bus(d), Bus(d), Bus(d)
    kick, snare, hand_clap, crash = _kick(), _anvil_snare(), clap(), cymbal(1.8)
    hits = []
    for bar in range(BARS):
        section_b = bar >= 16
        root, triad = (CHORDS_B if section_b else CHORDS_A)[(bar // 2) % 4]
        t0 = bar * 4 * BEAT
        fill = bar % 8 == 7
        # Drums: boom . . boom-boom pattern, anvil on 2 and 4.
        steps = (0, 6, 8, 14) if section_b or intense else (0, 6, 8)
        if fill and not intense:
            steps = (0, 6, 8)
        for s in steps:
            drums.add(kick, t0 + s * BEAT / 4, 0.62)
            hits.append(t0 + s * BEAT / 4)
        for b in (1, 3):
            drums.add(snare, t0 + b * BEAT, 0.36, 0.48)
            send.add(snare, t0 + b * BEAT, 0.12)
            if intense or (section_b and b == 3):
                drums.add(hand_clap, t0 + b * BEAT, 0.2, 0.56)
        for e in range(8):
            accent = 1.0 if e % 2 else 0.6
            drums.add(_hat(0.045, accent), t0 + e * BEAT / 2, 0.17, 0.66)
        if section_b or intense:
            for e in range(8):
                drums.add(_hat(0.03, 0.5), t0 + (e + 0.5) * BEAT / 2, 0.13, 0.34)
        # Struck-pipe percussion on the off-sixteenths, echoing in the ruins.
        for s in (3, 11) if bar % 2 == 0 else (3, 7, 13):
            pipe = filt(_metal(660 if s != 7 else 880, 0.22, 0.09), low=5500)
            drums.add(pipe, t0 + s * BEAT / 4, 0.07, 0.25 + 0.05 * s / 4)
            send.add(pipe, t0 + s * BEAT / 4, 0.07)
        if intense and bar % 8 == 0:
            drums.add(crash, t0, 0.12, 0.38)
            send.add(crash, t0, 0.06)
        if fill:
            drums.add(riser(2 * BEAT), t0 + 2 * BEAT, 0.07 if not intense else 0.1, 0.6)
            for k, f in enumerate((210, 170, 140, 110) if intense or section_b else (170, 120)):
                drums.add(_tom(f), t0 + (3 + k * 0.25) * BEAT, 0.4, 0.3 + 0.12 * k)
        # Bass: syncopated sixteenths on the root, octave on the off-beats.
        pattern = (0, 3, 6, 8, 10, 11, 14) if not intense else (0, 2, 3, 6, 8, 10, 11, 14)
        for s in pattern:
            up = 12 if (s in (6, 14) or (intense and s in (2, 10))) else 0
            ln = BEAT * (0.5 if s in (3, 11) else 0.3)
            music.add(_bass(root - 12 + up, ln, 2200 if intense else 1700 if section_b else 1400), t0 + s * BEAT / 4, 0.34)
        # Pad, two bars per chord.
        if bar % 2 == 0:
            pad = _pad(root, triad, 8 * BEAT, 1500 if section_b or intense else 1100)
            music.add(pad, t0, 0.055, 0.35)
            music.add(np.roll(pad, int(SR * 0.013)), t0, 0.055, 0.65)
            send.add(pad, t0, 0.03)
        # The riff (section A from bar 9, everywhere when intense; answered in B).
        riff_on = (not section_b and bar >= 8) or intense or bar in (30, 31)
        if riff_on:
            for semis, at, length in RIFF[bar % 8]:
                x = _pluck(semis, length * BEAT * 0.9, 3600 if intense else 3000)
                lead.add(x, t0 + at * BEAT, 0.17 if not section_b else 0.1)
                if intense:
                    lead.add(_pluck(semis + 12, length * BEAT * 0.8, 3800), t0 + at * BEAT, 0.035, 0.7)
        # Section B: the anthem lead over a pluck arpeggio.
        if section_b:
            for semis, at, length in ANTHEM[bar % 8]:
                x = _lead(semis, length * BEAT * 0.97, 2800 if intense else 2500)
                music.add(x, t0 + at * BEAT, 0.095, 0.5)
                send.add(x, t0 + at * BEAT, 0.06)
            tones = [triad[0], triad[1], triad[2], 12, triad[2], triad[1]]
            for e in range(16):
                x = _pluck(root + 24 + tones[e % 6], BEAT * 0.22, 2400)
                music.add(x, t0 + e * BEAT / 4, 0.045, 0.3 if e % 2 else 0.7)
        # Power stabs on the "and" of 4 (boss waves).
        if intense:
            st = _stab(root - 12)
            music.add(st, t0 + 3.5 * BEAT, 0.11, 0.5)
            send.add(st, t0 + 3.5 * BEAT, 0.05)
    # A far siren (bars 5-8 and 21-24; every 8 bars when intense) and the feedback swells.
    siren_bars = (4, 12, 20, 28) if intense else (4, 20)
    for bar in siren_bars:
        s = _siren(4 * 4 * BEAT, note(-5), note(2), 4 * BEAT)
        send.add(s, bar * 4 * BEAT, 0.11 if intense else 0.09, 0.75)
        music.add(s, bar * 4 * BEAT, 0.012, 0.8)
    for bar in (14, 30) if not intense else (6, 14, 22, 30):
        fb = _feedback(-7 if bar % 16 == 14 else -5, 2 * 4 * BEAT)
        music.add(fb, bar * 4 * BEAT, 0.05, 0.4)
        send.add(fb, bar * 4 * BEAT, 0.07)
    n = int(d * SR)
    duck = pump(n, hits, depth=0.38, release=0.2)[:, None]
    lead_mix = lead.loop()
    echoes = echo(lead_mix.mean(axis=1), BEAT * 0.75, 0.38, 4, 2800)
    send_mix = send.loop() + echoes * 0.25 + lead_mix * 0.4
    wet = reverb(send_mix[:, 0], send_mix[:, 1], 2.6, 0.03, 3200, 300, seed=91)
    return drums.loop() + (music.loop() + lead_mix + echoes * 0.45) * duck + wet * 0.9


# ---------------------------------------------------------------------------
# Ambience: Ashfall City at dusk
# ---------------------------------------------------------------------------

def _periodic(t, d, cycles, phase=0.0):
    """A sine that makes whole cycles over the loop (so the loop stays seamless)."""
    return np.sin(2 * np.pi * cycles * t / d + phase)


def _caw(base):
    """One crow's caw: a rasping nasal voice falling in pitch."""
    return filt(groan(base, 0.26, glide=-0.28, formants=((1150, 260), (2000, 380)), rasp=0.55, wobble=0.02), low=3800, high=350)


def _moan(t, d, f, cycles, phase, r):
    """Wind whistling through a gap: a wavering tone with a breathy edge that
    swells `cycles` times over the loop (a whole number of turns: seamless)."""
    swell = np.clip(0.5 + 0.5 * _periodic(t, d, cycles, phase), 0.0, 1.0) ** 5
    bend = f * (1.0 + 0.05 * _periodic(t, d, cycles * 2, phase + 0.8) + 0.012 * _periodic(t, d, 97, phase))
    turns = np.cumsum(bend) / SR
    bend *= np.round(turns[-1]) / turns[-1]
    flutter = filt(r.uniform(-1, 1, len(t)), low=6.0)
    flutter = 0.7 + 0.3 * flutter / (np.max(np.abs(flutter)) + 1e-9)
    tone_ = np.sin(2 * np.pi * np.cumsum(bend) / SR) + 0.2 * np.sin(4 * np.pi * np.cumsum(bend) / SR)
    breath = band(r.uniform(-1, 1, len(t)), f, f * 0.25) * 3.0
    return (tone_ * 0.6 + breath) * swell * flutter


def city_ambience():
    """40-second seamless bed: wind moaning through broken windows, a far
    fire roar with crackle, two distant sirens, debris settling (gravel
    trickles, a metal creak, one far collapse) and crows."""
    r = _r()
    d = 40.0
    n = int(SR * d)
    t = np.arange(n) / SR
    bus, send = Bus(d, 6.0), Bus(d, 6.0)
    for side, ph in ((0, 0.0), (1, 2.1)):
        lo = filt(r.uniform(-1, 1, n), low=420, high=45)
        mid = filt(r.uniform(-1, 1, n), low=1800, high=500)
        gust = (0.5 + 0.5 * _periodic(t, d, 3, ph)) * 0.6 + (0.5 + 0.5 * _periodic(t, d, 7, ph * 1.7)) * 0.4
        wind = lo * (0.45 + 0.55 * gust) * 0.9 + mid * gust ** 2 * 0.22
        air = filt(r.uniform(-1, 1, n), low=6000, high=2200) * (0.3 + 0.7 * gust ** 3) * 0.07
        wind += air
        # Moans through the empty window frames: breathy whistles that bend and fade.
        for f, cyc, k in ((330, 3, 0.0), (470, 4, 1.1 + ph), (690, 5, 2.3 + ph * 2)):
            wind += _moan(t, d, f, cyc, k, r) * 0.05
        (bus.left if side == 0 else bus.right)[:n] += wind
    # Fires across town: a deep roar breathing and far crackle.
    roar = filt(r.uniform(-1, 1, n), low=260, high=40) * (0.75 + 0.25 * _periodic(t, d, 11, 0.4)) * 1.1
    far = filt(_crackles(n, 30, r, 0.5), low=4500, high=300)
    bus.left[:n] += roar * 0.6 + far * 0.25
    bus.right[:n] += np.roll(roar, int(SR * 0.4)) * 0.6 + np.roll(far, int(SR * 3.0)) * 0.25
    # Distant sirens: a wail across town and a two-tone further off.
    wail = _siren(9.0, 560, 820, 4.5)
    send.add(wail, 5.0, 0.035, 0.25)
    bus.add(wail, 5.0, 0.004, 0.25)
    ln = 6.0
    two = additive(np.where((t_axis(ln) // 0.75) % 2 == 0, 620.0, 480.0), None, [(1.0, 1.0, None), (2.0, 0.25, None)])
    two = filt(two, low=1300) * adsr(ln, 1.5, ln, 1.0, 1.8)
    send.add(two, 24.0, 0.03, 0.8)
    bus.add(two, 24.0, 0.003, 0.8)
    # Debris settling: gravel trickles down a facade.
    for at, pan in ((2.5, 0.7), (13.0, 0.2), (21.5, 0.55), (33.0, 0.85)):
        ln = r.uniform(0.8, 1.6)
        trickle = silence(ln)
        for _ in range(int(ln * 40)):
            k = r.uniform(0, ln) ** 1.6 / ln ** 0.6
            grain = band(noise(0.02), r.uniform(900, 2600), 500) * env(0.02, 0.0005, power=2.0)
            place(trickle, grain, k, r.uniform(0.3, 1.0))
        bus.add(filt(trickle, low=4500), at, 0.09, pan)
        send.add(trickle, at, 0.05, pan)
    # A girder creaking in the wind and one far collapse.
    for at, pan, f in ((9.0, 0.15, 190.0), (29.0, 0.75, 150.0)):
        ln = 1.8
        creak = bl_osc(f * (1 + 0.25 * np.sin(np.pi * t_axis(ln) / ln)) + 9 * np.sin(2 * np.pi * 7 * t_axis(ln)), None, "saw")
        creak = filt(band(creak, 900, 500) + band(creak, 1700, 300) * 0.5, low=3000) * adsr(ln, 0.4, ln, 1.0, 0.6)
        bus.add(creak, at, 0.025, pan)
        send.add(creak, at, 0.04, pan)
    ln = 4.5
    fall = filt(noise(ln), low=420) * env(ln, 0.05, ln, power=1.6) * 1.4
    place(fall, _thud(70, 30, 1.2, 1.0) * 0.8, 0.0)
    bus.add(fall, 17.0, 0.12, 0.35)
    send.add(fall, 17.0, 0.1, 0.35)
    # Crows: two or three caws, now and then.
    for at, pan, base, count in ((7.0, 0.8, 520, 3), (19.5, 0.3, 470, 2), (31.5, 0.6, 560, 3), (37.0, 0.15, 500, 2)):
        for k in range(count):
            c = _caw(base * r.uniform(0.95, 1.05))
            bus.add(c, at + k * r.uniform(0.38, 0.5), 0.055, pan)
            send.add(c, at + k * 0.45, 0.06, pan)
    dry = bus.loop()
    sends = send.loop()
    wet = reverb(sends[:, 0], sends[:, 1], 3.2, 0.06, 2400, 200, seed=17)
    return dry + wet * 1.3


def city_fire_crackle():
    """8-second mono loop for a burning wreck (seamless; give each wreck its
    own start offset so a street of them never plays in step): a breathing
    low roar, flame flutter, close crackle and pops, and a sap hiss."""
    r = _r()
    d = 8.0
    n = int(SR * d)
    t = np.arange(n) / SR
    flick = 0.7 + 0.18 * _periodic(t, d, 5, 0.3) + 0.12 * _periodic(t, d, 13, 1.9)
    roar = filt(r.uniform(-1, 1, n), low=320, high=50) * flick * 1.3
    flutter = band(r.uniform(-1, 1, n), 900, 500) * (0.55 + 0.45 * _periodic(t, d, 72, 0.0) * _periodic(t, d, 19, 0.7)) * 0.35
    out = roar + flutter * flick
    out += filt(_crackles(n, 42, r, 1.0), low=7500)
    for at in (1.7, 5.9):
        ln = 0.5
        hiss = band(noise(ln), 3600, 1200) * adsr(ln, 0.08, ln, 1.0, 0.25) * 0.12
        place(out, hiss, at)
    return out


# ---------------------------------------------------------------------------
# Ambient emitters (positional loops round the city) and the sky's one-shots
# ---------------------------------------------------------------------------

def _own_rng(seed):
    """Renders a sound with its own seeded generator and leaves the pack's
    shared one untouched, so the sounds rendered after it stay as they were."""
    def wrap(fn):
        def inner():
            shared = ga.rng
            ga.rng = np.random.default_rng(seed)
            try:
                return fn()
            finally:
                ga.rng = shared
        inner.__name__ = fn.__name__
        inner.__doc__ = fn.__doc__
        return inner
    return wrap


def _wrap(buf, n):
    """Folds whatever ran past n samples back onto the start (a seamless loop)."""
    out = np.array(buf[:n], dtype=np.float64)
    tail = buf[n:]
    out[: len(tail)] += tail
    return out


@_own_rng(301)
def city_siren_loop():
    """12-second loop: a police siren wailing a few streets away, rising and
    falling twice, with a short yelp burst between (positional, on the
    Precinct's roofs)."""
    d = 12.0
    n = int(SR * d)
    t = np.arange(n) / SR
    f = 640 + 260 * (0.5 - 0.5 * _periodic(t, d, 2, 0.0))
    yelp = np.abs((t % 6.0) - 4.6) < 0.7
    f = np.where(yelp, 700 + 300 * (0.5 + 0.5 * np.sin(2 * np.pi * 7.0 * t)), f)
    turns = np.cumsum(f) / SR
    f *= np.round(turns[-1]) / turns[-1]
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    return filt(x, low=2200, high=300) * (0.85 + 0.15 * _periodic(t, d, 3, 0.4))


@_own_rng(302)
def city_alarm_loop():
    """4-second loop: a shop's burglar alarm, a fast two-tone beep with a
    tinny bell rattle under it (the Market)."""
    d = 4.0
    n = int(SR * d)
    t = np.arange(n) / SR
    f = np.where((t // 0.25) % 2 == 0, 1320.0, 990.0)
    gate = ((t % 0.25) < 0.21).astype(float)
    x = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.5 * gate
    bell = np.sin(2 * np.pi * 2350 * t) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 24 * t))) * 0.25
    return filt(x + bell, low=4200, high=500)


@_own_rng(303)
def city_radio_loop():
    """10-second loop: a police radio left on in a van: squelch, garbled
    voices through a tiny speaker, static between."""
    r = _r()
    d = 10.0
    n = int(SR * d)
    out = np.zeros(n + SR * 3)
    out[:n] += band(r.uniform(-1, 1, n), 2400, 1600) * 0.05
    for at, ln, base in ((0.6, 1.9, 150.0), (3.4, 1.2, 190.0), (5.8, 2.3, 140.0), (8.6, 0.9, 175.0)):
        m = int(SR * ln)
        tt = np.arange(m) / SR
        syll = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * r.uniform(3.5, 5.5) * tt + r.uniform(0, 6)))
        pitch = base * (1 + 0.15 * np.sin(2 * np.pi * 1.3 * tt))
        voice = bl_osc(pitch, None, "saw")
        voice = band(voice, r.uniform(700, 1000), 300) + band(voice, r.uniform(1600, 2100), 400) * 0.6
        voice = np.tanh(voice * syll * 4.0) * adsr(ln, 0.01, ln, 1.0, 0.02)
        place(out, voice * 0.5, at)
        squelch = band(noise(0.18), 3000, 2000) * env(0.18, 0.001, 0.15, power=1.2)
        place(out, squelch * 0.5, at - 0.12)
        place(out, squelch * 0.4, at + ln)
    return _wrap(filt(out, low=3400, high=400), n)


@_own_rng(304)
def city_drip_loop():
    """9-second loop: water dripping from the Metro's broken ceiling into
    puddles, with the hall's long echo."""
    r = _r()
    d = 9.0
    n = int(SR * d)
    dry = np.zeros(n + SR)
    for _ in range(19):
        at = r.uniform(0, d)
        f = r.uniform(900, 1900)
        tt = t_axis(0.12)
        drop = np.sin(2 * np.pi * (f + 900 * np.exp(-tt / 0.02)) * tt) * np.exp(-tt / 0.03)
        place(dry, drop, at, r.uniform(0.3, 1.0))
    dry = _wrap(dry, n)
    wet = reverb(dry, None, 2.8, 0.04, 2600, 300, seed=23).mean(axis=1)
    hum = filt(r.uniform(-1, 1, n), low=180, high=40) * 0.08
    return dry * 0.6 + wet * 0.9 + hum


@_own_rng(305)
def city_buzz_loop():
    """3-second loop: a failing neon tube: a 100 Hz hum with buzzy harmonics
    and the odd crackling drop-out."""
    r = _r()
    d = 3.0
    n = int(SR * d)
    t = np.arange(n) / SR
    hum = filt(np.sign(np.sin(2 * np.pi * 100 * t)) * 0.3 + np.sin(2 * np.pi * 50 * t) * 0.4, low=1800)
    buzz = band(r.uniform(-1, 1, n), 3200, 1500) * (0.5 + 0.5 * np.sin(2 * np.pi * 100 * t)) * 0.15
    out = hum + buzz
    for at in (0.7, 2.1):
        k = int(SR * at)
        m = int(SR * 0.18)
        out[k:k + m] *= 0.25
        out[k:k + m] += filt(_crackles(m, 140, r, 0.6), low=6000)[:m]
    return out


@_own_rng(306)
def city_heli_loop():
    """4-second loop: a helicopter circling the city: rotor thumps at 5 Hz,
    the turbine whine and a wash of wind."""
    r = _r()
    d = 4.0
    n = int(SR * d)
    t = np.arange(n) / SR
    blade = np.exp(-((t * 5.0) % 1.0) / 0.12)
    thump = filt(r.uniform(-1, 1, n), low=240, high=30) * blade * 2.2
    slap = band(r.uniform(-1, 1, n), 900, 500) * blade ** 3 * 0.4
    whine = np.sin(2 * np.pi * 1850 * t + 0.3 * np.sin(2 * np.pi * 0.25 * t)) * 0.035
    wash = filt(r.uniform(-1, 1, n), low=1200, high=150) * 0.18
    return thump + slap + whine + wash


@_own_rng(307)
def city_sparks_loop():
    """5-second loop: a torn cable arcing: bursts of electric crackle and a
    snapping zap over a live hum."""
    r = _r()
    d = 5.0
    n = int(SR * d)
    t = np.arange(n) / SR
    out = np.sin(2 * np.pi * 120 * t) * 0.06
    for at in (0.3, 1.9, 2.4, 4.1):
        ln = r.uniform(0.12, 0.35)
        m = int(SR * ln)
        zap = band(r.uniform(-1, 1, m), 4200, 3000) * np.abs(np.sin(2 * np.pi * 60 * t_axis(ln)))[:m] * env(ln, 0.002, ln, power=1.5)[:m]
        zap += filt(_crackles(m, 300, r, 0.8), low=8000)[:m] * 0.6
        place(out, zap * 1.3, at)
    return out


@_own_rng(308)
def city_thunder():
    """Rolling thunder far behind the skyline: a crack softened by distance,
    then a long low rumble that rolls and fades."""
    r = _r()
    d = 5.5
    out = filt(noise(d), low=160, high=25) * env(d, 0.25, d, power=1.3) * 1.4
    for k in range(6):
        at = 0.15 + k * r.uniform(0.35, 0.8)
        ln = r.uniform(0.8, 1.6)
        roll = filt(noise(ln), low=380, high=40) * env(ln, 0.05, ln, power=1.6)
        place(out, roll, at, r.uniform(0.4, 0.9))
    crack = filt(noise(0.6), low=1600, high=200) * env(0.6, 0.004, 0.5, power=2.2)
    place(out, crack, 0.05, 0.6)
    return out


@_own_rng(309)
def city_blast_far():
    """A distant explosion across the city: a dull thump, a rolling boom and
    debris pattering down."""
    r = _r()
    d = 3.6
    out = np.zeros(int(SR * d))
    place(out, _thud(90, 28, 1.6, 1.2), 0.0, 1.4)
    place(out, filt(noise(d), low=260, high=30) * env(d, 0.02, d, power=1.5), 0.0, 1.2)
    for _ in range(25):
        at = r.uniform(0.8, 3.0)
        grain = band(noise(0.03), r.uniform(700, 2000), 600) * env(0.03, 0.001, power=2.0)
        place(out, grain, at, r.uniform(0.05, 0.25))
    return filt(out, low=2600)


# ---------------------------------------------------------------------------
# Gates and districts
# ---------------------------------------------------------------------------

def end_gate_open():
    """Paid: the lock clunks, a motor hauls the shutter up with its slats
    rattling, and it slams home at the top."""
    d = 2.0
    out = silence(d)
    place(out, _thud(160, 60, 0.25, 0.18), 0.0, 0.9)
    place(out, filt(_metal(300, 0.4, 0.18), low=5000), 0.0, 0.6)
    ln = 1.45
    tt = t_axis(ln)
    motor_f = 70 + 40 * np.clip(tt / 0.4, 0, 1) - 8 * (tt / ln)
    motor = bl_osc(motor_f, None, "saw") * 0.5 + bl_osc(motor_f * 2.01, None, "square", 0.3) * 0.2
    motor = filt(motor, low=900) * (1 + 0.15 * np.sin(2 * np.pi * 11 * tt)) * adsr(ln, 0.12, ln, 1.0, 0.15)
    place(out, motor, 0.12, 0.4)
    place(out, filt(_chain(ln, 30.0), low=5000) * adsr(ln, 0.2, ln, 1.0, 0.2), 0.14, 1.3)
    for k in range(int(ln * 9)):
        slat = filt(_metal(520 + 40 * (k % 3), 0.08, 0.03), low=4500) + band(noise(0.08), 900, 500) * env(0.08, 0.001, 0.05)
        place(out, slat, 0.2 + k / 9.0, 0.35)
    place(out, _whoosh(ln, 300, 1100, 0.7), 0.14, 0.6)
    place(out, _thud(110, 40, 0.4, 0.3), 1.58, 1.0)
    place(out, filt(_metal(220, 0.42, 0.2), low=5000), 1.58, 0.7)
    return out


def end_gate_denied():
    """Not enough tickets: a low two-note buzzer and the padlock rattling."""
    d = 0.6
    out = silence(d)
    for i, semis in enumerate((-17, -21)):
        ln = 0.17
        buzz = filt(bl_osc(note(semis), ln, "square", 0.5) * 0.6 + bl_osc(note(semis) * 2, ln, "saw") * 0.2, low=1700)
        place(out, buzz * adsr(ln, 0.005, ln, 1.0, 0.03), i * 0.19, 0.7)
    for k in range(3):
        place(out, filt(_metal(1250 + 150 * k, 0.12, 0.05), low=5000), 0.03 + k * 0.07, 0.45)
    place(out, _thud(140, 80, 0.12, 0.08), 0.0, 0.5)
    return out


def end_gate_sting():
    """A district opens: a boom and a bright D major brass chord lifting out
    of the minor, a bell arpeggio over it and a cymbal swell."""
    d = 2.6
    out = silence(d)
    place(out, _thud(90, 32, 1.0, 0.8), 0.0, 1.0)
    place(out, _horn((-31, -19, -15, -12, -7), 1.6, 2200, 0.02, 0.0), 0.0, 0.5)
    for i, semis in enumerate((5, 9, 12, 17)):
        place(out, _bell(note(semis), 1.4, 0.55), 0.05 + i * 0.11)
    place(out, filt(cymbal(1.9), low=7500), 0.02, 0.18)
    place(out, _horn((-19, -12, -7), 1.0, 2600, 0.25, 0.0), 0.5, 0.22)
    return out


def end_district_enter():
    """Walking into a district (its name card): a soft air sweep and a
    two-note mallet tag."""
    d = 1.2
    out = silence(d)
    place(out, _whoosh(0.7, 450, 1500, 0.6), 0.0, 0.35)
    place(out, _bell(note(0), 0.8, 0.45), 0.18)
    place(out, _bell(note(5), 0.9, 0.5), 0.32)
    place(out, sweep(120, 55, 0.3, "sine", 0.4) * env(0.3, 0.003, 0.25, power=1.6), 0.18, 0.35)
    return out


# ---------------------------------------------------------------------------
# Waves, supplies, traps, the boss, the record
# ---------------------------------------------------------------------------

def end_wave_horn():
    """A wave starts: a drum hit, then the city's air-raid horn blows a low
    D minor chord across the rooftops."""
    d = 2.4
    out = silence(d)
    place(out, _thud(130, 42, 0.5, 0.42), 0.0, 1.0)
    place(out, filt(_metal(240, 0.5, 0.25), low=4500), 0.0, 0.45)
    place(out, clap(), 0.0, 0.35)
    horn = _horn((-31, -24, -19, -16), 1.9, 1900, 0.12, 0.04)
    place(out, horn, 0.08, 0.75)
    return out


def end_supply_incoming():
    """A supply drop is on its way: a radio squelch, three beacon beeps and a
    cargo plane droning overhead."""
    d = 2.2
    out = silence(d)
    place(out, filt(noise(0.05), high=900, low=3500) * env(0.05, 0.001, power=1.4), 0.0, 0.35)
    for i in range(3):
        ln = 0.12
        beep = additive(note(3), ln, [(1.0, 1.0, None), (1.5, 0.3, None)]) * adsr(ln, 0.004, ln, 1.0, 0.03)
        place(out, beep, 0.08 + i * 0.17, 0.5)
    ln = 2.0
    tt = t_axis(ln)
    doppler = 95 * (1.12 - 0.24 * np.clip(tt / ln, 0, 1))
    prop = bl_osc(doppler, None, "saw") * 0.4 + bl_osc(doppler * 1.5, None, "saw") * 0.2
    prop = filt(prop, low=800) * (1 + 0.3 * np.sin(2 * np.pi * 23 * tt))
    plane = (prop + band(noise(ln), 600, 400) * 0.6) * np.sin(np.pi * tt / ln) ** 1.8
    place(out, plane, 0.15, 0.7)
    return out


def end_supply_land():
    """The crate lands: a heavy thud, splintering boards, a frame clank, the
    parachute flapping down and a puff of dust."""
    d = 1.4
    out = silence(d)
    place(out, _thud(110, 40, 0.6, 0.45), 0.0, 0.9)
    r = _r()
    for k in range(7):
        f = r.uniform(500, 1600)
        place(out, band(noise(0.05), f, f * 0.5) * env(0.05, 0.0008, 0.04, power=2.0), 0.005 + k * r.uniform(0.008, 0.02), 1.4)
    place(out, filt(_metal(350, 0.35, 0.14), low=4500), 0.01, 0.4)
    ln = 1.0
    tt = t_axis(ln)
    flap = band(noise(ln), 1100, 700) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 17 * tt))) * env(ln, 0.05, ln, power=1.5)
    place(out, filt(flap, low=3500), 0.2, 0.6)
    dust = filt(noise(0.9), low=1800, high=200) * env(0.9, 0.02, 0.9, power=2.0)
    place(out, dust, 0.03, 0.9)
    return out


def end_trap_ready():
    """A trap is armed again: a latch click and a rising two-tone chirp over
    a short power-up hum."""
    d = 0.7
    out = silence(d)
    place(out, click(0.025, 2200), 0.0, 0.5)
    ln = 0.45
    tt = t_axis(ln)
    hum = bl_osc(100 + 80 * tt / ln, None, "saw") * 0.3
    place(out, filt(hum, low=1000) * adsr(ln, 0.05, ln, 1.0, 0.1), 0.0, 0.5)
    for i, semis in enumerate((2, 9)):
        ln = 0.13 if i == 0 else 0.2
        x = additive(note(semis), ln, [(1.0, 1.0, None), (2.0, 0.25, None), (3.0, 0.08, None)]) * adsr(ln, 0.004, ln * 0.6, 0.5, 0.04)
        place(out, x, 0.1 + i * 0.13, 0.55)
    return out


def end_trap_fire():
    """The gas main ignites: a hiss, a deep whoomp and a roaring burst of
    flame that dies down with a few crackles."""
    d = 1.8
    out = silence(d)
    r = _r()
    place(out, band(noise(0.1), 3000, 1200) * adsr(0.1, 0.03, 0.1, 1.0, 0.02), 0.0, 0.2)
    place(out, _thud(95, 36, 0.6, 0.5), 0.08, 0.9)
    place(out, filt(noise(0.3), low=900) * env(0.3, 0.004, 0.2, power=1.6), 0.08, 0.9)
    ln = 1.65
    tt = t_axis(ln)
    flame = filt(noise(ln), low=2400, high=120) * (0.75 + 0.25 * np.sin(2 * np.pi * 13 * tt) * np.sin(2 * np.pi * 4.7 * tt))
    flame *= adsr(ln, 0.06, 0.55, 0.25, 0.5)
    place(out, flame, 0.1, 1.7)
    place(out, filt(_crackles(int(SR * 1.4), 50, r, 0.6), low=7000), 0.3, 0.6)
    return out


def end_trap_shock():
    """The shock grid fires: a capacitor thump, a buzzing arc and crackling
    zaps (kept under 8 kHz)."""
    d = 1.0
    out = silence(d)
    r = _r()
    place(out, _thud(150, 50, 0.25, 0.15), 0.0, 0.7)
    ln = 0.8
    tt = t_axis(ln)
    gate = np.repeat(r.uniform(0.35, 1.0, int(ln * 60) + 1), int(SR / 60) + 1)[: len(tt)]
    buzz = bl_osc(120 + 6 * np.sin(2 * np.pi * 9 * tt), None, "saw") + bl_osc(181, ln, "square", 0.4) * 0.4
    buzz = band(buzz, 1300, 1000) * gate * adsr(ln, 0.005, ln * 0.5, 0.4, 0.2)
    place(out, buzz, 0.0, 0.8)
    for k in range(6):
        ln = r.uniform(0.04, 0.09)
        zap = filt(sweep(r.uniform(2600, 3600), r.uniform(300, 600), ln, "square", 0.5), low=6500) * env(ln, 0.0008, ln, power=1.4)
        place(out, zap, r.uniform(0.0, 0.55), r.uniform(0.2, 0.4))
    return out


def end_boss_siren():
    """The Wrecker is coming: two drum booms and an air-raid siren winding up
    and down with a fifth beneath it (never above ~520 Hz, low-passed)."""
    d = 3.4
    out = silence(d)
    place(out, _thud(90, 30, 0.9, 0.7), 0.0, 1.1)
    place(out, _thud(90, 30, 0.9, 0.7), 1.6, 1.1)
    place(out, filt(_metal(180, 0.8, 0.4), low=3500), 1.6, 0.4)
    ln = 3.2
    tt = t_axis(ln)
    rise = np.where(tt < 1.6, 150 + 370 * (tt / 1.6) ** 0.6, 520 - 220 * (np.clip(tt - 1.6, 0.0, None) / 1.6) ** 1.4)
    rise = rise * (1 + 0.012 * np.sin(2 * np.pi * 5 * tt))
    siren = sum(bl_osc(rise * k, None, "saw", phase=0.3 * k) * g for k, g in ((1.0, 1.0), (2.0 / 3.0, 0.6)))
    siren = filt(np.tanh(siren * 1.2), low=2000) * adsr(ln, 0.25, ln, 1.0, 0.9)
    place(out, siren, 0.05, 0.5)
    return out


def end_new_best():
    """A new best wave: a quick rising arpeggio into a held D major chord with
    bells, a soft boom and a gentle cymbal."""
    d = 2.0
    out = silence(d)
    for i, semis in enumerate((-7, -3, 0, 5, 9)):
        ln = 0.22
        x = filt(bl_osc(note(semis), ln, "square", 0.4) * 0.5 + bl_osc(note(semis), ln, "sine") * 0.6, low=2800)
        place(out, x * adsr(ln, 0.003, ln * 0.5, 0.2, 0.03), i * 0.075, 0.45)
    place(out, _horn((-19, -15, -12, -7, -3), 1.4, 2600, 0.03, 0.0), 0.38, 0.5)
    for i, semis in enumerate((12, 17, 21)):
        place(out, _bell(note(semis), 1.3, 0.3), 0.38 + i * 0.06)
    place(out, sweep(100, 40, 0.5, "sine", 0.4) * env(0.5, 0.002, 0.4, power=1.6), 0.38, 0.7)
    place(out, filt(cymbal(1.4), low=7000), 0.38, 0.14)
    return out


SOUNDS = [
    end_gate_open, end_gate_denied, end_gate_sting, end_district_enter, end_wave_horn,
    end_supply_incoming, end_supply_land, end_trap_ready, end_trap_fire, end_trap_shock,
    end_boss_siren, end_new_best, city_thunder, city_blast_far,
]

VARIANTS = []

LOOPS = {
    "city_fire_crackle": city_fire_crackle,
    "city_siren_loop": city_siren_loop,
    "city_alarm_loop": city_alarm_loop,
    "city_radio_loop": city_radio_loop,
    "city_drip_loop": city_drip_loop,
    "city_buzz_loop": city_buzz_loop,
    "city_heli_loop": city_heli_loop,
    "city_sparks_loop": city_sparks_loop,
}

MUSIC = {
    "city_endless_loop": city_endless_loop,
    "city_endless_final": lambda: city_endless_loop(intense=True),
    "city_ambience": city_ambience,
}
