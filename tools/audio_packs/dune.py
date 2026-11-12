"""Dune Spaceport sound pack (World 4, Launch Pad 9).

    python tools/gen_audio.py dune

Music:   launch_pad_loop  space-western loop, 104 BPM, ~74 s: section A (twang guitar,
                          galloping drums, whistled tune), section B (theremin lead,
                          pad swells, synth arpeggio).
         launch_pad_final the final-wave variant (driving drums, walking bass).
Bed:    dune_ambience    desert wind and gusts, distant engines, PA chimes with a
                          muffled announcer, far-off clanks and a reversing tug.
Enemies: dune_cadet_radio_*, dune_mechanic_grunt_*, dune_hazmat_breath_* (voices),
         dune_leap_charge / dune_leap_whoosh / dune_land_thump (Space Cadet pounce),
         dune_jet_ignite / dune_jet_burn (jetpack hop), dune_geiger / dune_rad_burst
         (hazmat cloud).
"""
from gen_audio import *  # noqa: F401,F403
from gen_audio import _sub_thump


# ---------------------------------------------------------------------------
# Shared voices
# ---------------------------------------------------------------------------

def radio(x, crackle=0.25):
    """Squeeze a sound through a walkie-talkie: band-limit, clip, add static."""
    y = filt(x, low=2800, high=380)
    y = crush(y * 2.5, 2.2)
    n = len(y)
    static = filt(rng.uniform(-1, 1, n), high=2500) * crackle
    pops = (rng.uniform(0, 1, n) > 0.9993).astype(float) * rng.uniform(-1, 1, n) * 2.0
    return y + static * (0.4 + 0.6 * np.abs(np.sin(np.arange(n) / SR * 23.0))) + filt(pops, low=6000)


def squelch(seconds=0.12):
    """Radio key-off: a short burst of static."""
    return filt(noise(seconds), high=1800) * env(seconds, 0.002, seconds, power=0.6) * 0.8


def dune_cadet_radio_1():
    g = groan(118, 0.9, glide=-0.2, formants=((640, 140), (1300, 220)), rasp=0.3, wobble=0.06)
    out = silence(1.15)
    place(out, squelch(0.08), 0.0, 0.6)
    place(out, radio(g), 0.06, 1.0)
    place(out, squelch(0.14), 0.98, 0.9)
    return out


def dune_cadet_radio_2():
    g = groan(140, 0.7, glide=0.35, formants=((720, 150), (1500, 240)), rasp=0.35, wobble=0.09)
    out = silence(0.95)
    place(out, blip(note(19), 0.05, "sine", 0.05), 0.0, 0.4)
    place(out, radio(g), 0.05, 1.0)
    place(out, squelch(0.12), 0.78, 0.9)
    return out


def dune_mechanic_grunt_1():
    return groan(84, 0.95, glide=-0.3, formants=((470, 110), (980, 170)), rasp=0.45, wobble=0.05)


def dune_mechanic_grunt_2():
    out = silence(1.0)
    place(out, groan(96, 0.4, glide=0.2, formants=((520, 120), (1050, 180)), rasp=0.5), 0.0, 1.0)
    place(out, groan(80, 0.5, glide=-0.35, formants=((450, 110), (900, 160)), rasp=0.5), 0.42, 1.0)
    return out


def _breath(seconds, inhale):
    n = band(noise(seconds), 1400 if inhale else 900, 700)
    shape = env(seconds, seconds * (0.6 if inhale else 0.1), seconds, power=0.8, release=seconds * 0.3)
    return n * shape


def dune_hazmat_breath_1():
    """Gas-mask breathing with the valve clicking."""
    out = silence(1.6)
    place(out, _breath(0.6, True), 0.0, 0.8)
    place(out, click(0.02, 2000), 0.62, 0.5)
    place(out, _breath(0.7, False), 0.7, 0.9)
    place(out, filt(groan(90, 0.6, glide=-0.15, formants=((420, 100), (800, 150)), rasp=0.3), low=900), 0.8, 0.45)
    return out


def dune_hazmat_breath_2():
    out = silence(1.3)
    place(out, _breath(0.45, True), 0.0, 0.8)
    place(out, click(0.02, 2400), 0.47, 0.5)
    place(out, _breath(0.55, False), 0.52, 0.8)
    for i in range(3):
        place(out, click(0.01, 4000), 0.9 + i * 0.09, 0.35)
    return out


# ---------------------------------------------------------------------------
# Behaviours
# ---------------------------------------------------------------------------

def dune_leap_charge():
    """Space Cadet crouch: a springy sci-fi charge-up."""
    d = 0.6
    t = t_axis(d)
    rise = sweep(220, 880, d, "sine", 1.4) * (1 + 0.3 * np.sin(2 * np.pi * 18 * t))
    out = rise * env(d, 0.05, d * 1.3, power=0.6, release=0.05) * 0.6
    place(out, radio(groan(150, 0.4, glide=0.5, formants=((700, 150), (1400, 220)), rasp=0.3)), 0.1, 0.5)
    return out


def dune_leap_whoosh():
    d = 0.75
    t = t_axis(d)
    whoosh = band(noise(d), 900, 500) * np.sin(np.pi * np.clip(t / d, 0, 1)) ** 1.5
    boing = sweep(620, 180, d, "sine", 0.6) * env(d, 0.005, d, power=1.2) * 0.35
    return whoosh * 1.2 + boing


def dune_land_thump():
    d = 0.5
    out = _sub_thump(140, 38, d, 0.3) * 1.3
    place(out, filt(noise(0.3), low=2500) * env(0.3, 0.001, 0.2, power=1.8), 0.0, 0.6)
    place(out, band(noise(0.35), 3500, 1500) * env(0.35, 0.01, 0.3, power=1.2), 0.02, 0.35)   # sand spray
    return crush(out, 1.3)


def dune_jet_ignite():
    """Jetpack sputter: three coughs of flame, then catch."""
    d = 0.8
    out = silence(d)
    for i, at in enumerate((0.0, 0.16, 0.3, 0.42)):
        burst = filt(noise(0.09), low=3000, high=200) * env(0.09, 0.002, 0.08, power=1.5)
        place(out, burst, at, 0.6 + i * 0.15)
        place(out, click(0.02, 1500), at, 0.4)
    roar = filt(noise(0.35), low=1800, high=120) * env(0.35, 0.05, 0.6, power=0.5, release=0.05)
    place(out, roar, 0.45, 0.9)
    return out


def dune_jet_burn():
    d = 1.4
    t = t_axis(d)
    roar = filt(noise(d), low=2200, high=90) * (0.8 + 0.2 * np.sin(2 * np.pi * 31 * t))
    rumble = sweep(70, 52, d, "saw", 0.8) * 0.25
    hiss = filt(noise(d), high=4500) * 0.18
    return (roar + filt(rumble, low=300) + hiss) * env(d, 0.04, d * 1.1, power=0.7, release=0.25)


def dune_geiger():
    out = silence(0.05)
    place(out, click(0.006, 4200, 1.0), 0.0, 1.0)
    place(out, click(0.004, 2600, 0.6), 0.008, 0.5)
    return out


def dune_rad_burst():
    d = 1.2
    out = _sub_thump(110, 30, d, 0.4) * 1.4
    place(out, filt(noise(0.5), low=4000) * env(0.5, 0.002, 0.3, power=1.5), 0.0, 0.8)
    t = t_axis(d)
    sizzle = band(noise(d), 5200, 2000) * env(d, 0.05, d, power=0.8) * (0.6 + 0.4 * np.sin(2 * np.pi * 47 * t))
    place(out, sizzle, 0.0, 0.5)
    place(out, sweep(300, 1600, 0.6, "square", 1.5) * env(0.6, 0.01, 0.6, power=1.0) * 0.12, 0.05, 1.0)
    return crush(out, 1.4)


SOUNDS = [dune_cadet_radio_1, dune_cadet_radio_2, dune_mechanic_grunt_1, dune_mechanic_grunt_2,
          dune_hazmat_breath_1, dune_hazmat_breath_2, dune_leap_charge, dune_leap_whoosh, dune_land_thump,
          dune_jet_ignite, dune_jet_burn, dune_geiger, dune_rad_burst]
VARIANTS = [(dune_cadet_radio_1, (0.92, 1.08)), (dune_mechanic_grunt_1, (0.9, 1.1)),
            (dune_hazmat_breath_1, (0.94, 1.06)), (dune_land_thump, (0.9, 1.1))]


# ---------------------------------------------------------------------------
# Music: space-western loop
# ---------------------------------------------------------------------------

def pluck(freq, seconds, bright=1.0, bend=0.012):
    """Twangy plucked string: decaying harmonics, highs die first, a small pitch drop."""
    t = t_axis(seconds)
    f = freq * (1.0 + bend * np.exp(-t * 30.0))
    phase = 2 * np.pi * np.cumsum(f) / SR
    out = np.zeros_like(t)
    for k in range(1, 11):
        amp = (1.0 / k) * (0.6 if k % 2 == 0 else 1.0) * bright ** (k - 1)
        out += np.sin(phase * k) * amp * np.exp(-t * (1.6 + 0.9 * k))
    return out * env(seconds, 0.002, seconds * 3, power=0.3, release=0.02)


def theremin(freq_path, seconds):
    """Wobbly sine lead (freq_path: array of Hz per sample) with slow vibrato."""
    t = t_axis(seconds)
    f = freq_path * (1.0 + 0.012 * np.sin(2 * np.pi * 5.6 * t))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) + 0.12 * np.sin(ph * 2) + 0.05 * np.sin(ph * 3))


def reverb(x, seconds=1.6, mix=0.25, seed=5):
    """Convolution with a decaying-noise impulse (spring-ish room)."""
    r = np.random.default_rng(seed)
    n = int(SR * seconds)
    ir = r.uniform(-1, 1, n) * np.exp(-np.arange(n) / SR * 4.0)
    ir = filt(ir, low=5000, high=200)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    size = 1
    while size < len(x) + n:
        size *= 2
    y = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x) + n]
    return y * mix


def launch_pad_loop(intense=False):
    """intense=True is the final-wave variant (launch_pad_final): kick on every
    beat with a gallop pickup, a brushed train beat, shaker, synth arp and pad
    throughout, a walking eighth bass, crashes and the whistled tune from the
    top. Same tempo and length, so the game cross-fades between the two in time."""
    bpm = 104.0
    beat = 60.0 / bpm
    bars = 32
    d = bars * 4 * beat
    tail = 2.0
    total = d + tail
    dry_l, dry_r = silence(total), silence(total)
    wet = silence(total)

    def put(x, at, gain, pan=0.5, send=0.0):
        place(dry_l, x, at, gain * (1 - pan) * 2)
        place(dry_r, x, at, gain * pan * 2)
        if send > 0:
            place(wet, x, at, gain * send)

    # E minor western: Em - C - D - Em (A), G - D - Am - B7 (B). Roots as semitones from A4.
    prog_a = [(-17, (0, 3, 7)), (-21, (0, 4, 7)), (-19, (0, 4, 7)), (-17, (0, 3, 7))]
    prog_b = [(-14, (0, 4, 7)), (-19, (0, 4, 7)), (-12, (0, 3, 7)), (-22, (0, 4, 7, 10))]
    kick = sweep(120, 42, 0.2, "sine", 0.5) * env(0.2, 0.001, power=2.0)
    place(kick, kick_click(0.3), 0.0)
    rim = (band(noise(0.04), 2200, 600) * 3 + tone(820, 0.04) * 0.5) * env(0.04, 0.0005, power=2.5)
    snare = (filt(noise(0.18), high=1200) * 0.7 + tone(180, 0.18) * 0.3) * env(0.18, 0.001, power=2.0)
    brush = band(noise(0.07), 3200, 1800) * env(0.07, 0.004, power=1.6)
    shaker = filt(noise(0.06), high=6000) * env(0.06, 0.01, power=1.5)
    crash = cymbal(2.0)
    for bar in range(bars):
        section_b = bar >= 16
        root, chord = (prog_b if section_b else prog_a)[(bar // 2) % 4]
        t0 = bar * 4 * beat
        last = bar == bars - 1
        if intense and bar % 8 == 0:
            put(crash, t0, 0.1, 0.6, 0.3)
        if intense and bar % 8 == 7:
            put(riser(2 * beat), t0 + 2 * beat, 0.07, 0.4)
        # Galloping drums: kick on 1 and 3, the "horse trot" on the rim, snare on
        # 2 and 4 (intense: kick on every beat with a pickup, a brushed train beat).
        for b in range(4):
            put(kick, t0 + b * beat, 0.5 if b in (0, 2) or intense else 0.25)
            if intense and b in (1, 3):
                put(kick, t0 + (b + 0.75) * beat, 0.2)
            if b in (1, 3):
                put(snare, t0 + b * beat, 0.26 if section_b or intense else 0.18, 0.5, 0.3)
            for s, g in ((0.0, 0.16), (0.5, 0.1), (0.75, 0.13)):
                put(rim, t0 + (b + s) * beat, g, 0.35)
            if section_b or intense:
                for s in range(4):
                    put(shaker, t0 + (b + s * 0.25) * beat, 0.06 + 0.03 * (s % 2), 0.7)
            if intense:
                for s in range(4):
                    put(brush, t0 + (b + s * 0.25) * beat, 0.05 if s % 2 else 0.08, 0.55)
        if bar % 8 == 7 and not last:
            for s in range(6):
                put(snare, t0 + (2.5 + s * 0.25) * beat, 0.12 + s * 0.03, 0.5, 0.3)
        # Bass: root and fifth, a walking pickup into the next chord (walking
        # eighths when intense).
        if intense:
            for e, step in enumerate((0, 0, 7, 7, 0, 0, 7, 12)):
                put(pluck(note(root - 12 + step), beat * 0.5, bright=0.55, bend=0.004), t0 + e * beat * 0.5, 0.42)
        else:
            for b in range(4):
                n = root - 12 + (7 if b == 2 else 0)
                put(pluck(note(n), beat * 0.95, bright=0.55, bend=0.004), t0 + b * beat, 0.5)
        # Twang guitar: broken-chord arpeggio in eighths, dotted rhythm in B.
        pattern = [0, 2, 1, 2, 0, 2, 1, 3] if not section_b else [0, 1, 2, 3, 2, 1, 2, 1]
        for e in range(8):
            if section_b and e in (3, 7) and bar % 2 == 1:
                continue
            idx = pattern[e] % len(chord)
            step = chord[idx] + (12 if pattern[e] >= len(chord) else 0)
            n = root + 12 + step
            put(pluck(note(n), beat * 1.6, bright=0.75), t0 + e * beat * 0.5, 0.17, 0.3 if e % 2 else 0.42, 0.55)
        # Warm pad in section B (detuned saws through a low-pass), everywhere when intense.
        if section_b or intense:
            pad = sum(osc(2 * np.pi * np.cumsum(np.full(int(SR * 4 * beat), note(root + 12 + s) * (1 + det))) / SR, "saw")
                      for s in chord[:3] for det in (-0.003, 0.003))
            pad = filt(pad, low=1400) * env(4 * beat, 0.6, 8 * beat, power=0.5, release=0.4)
            put(pad, t0, 0.035, 0.5, 0.4)
            # Retro synth arpeggio in sixteenths, quiet and bright.
            for e in range(16):
                step = chord[e % len(chord)] + 24 + (12 if e % 8 >= 4 else 0)
                x = tone(note(root + step), beat * 0.2, "square") * env(beat * 0.2, 0.002, beat * 0.25, power=1.5)
                put(filt(x, low=5000), t0 + e * beat * 0.25, 0.045, 0.2 + 0.6 * ((e % 4) / 3.0), 0.3)
    # Melodies: a whistled tune in A (bars 8-15), the theremin in B (bars 16-31).
    whistle = [(7, 0.0, 1.5), (5, 1.5, 0.5), (3, 2.0, 1.0), (0, 3.0, 1.0), (-2, 4.0, 1.5), (0, 5.5, 0.5), (3, 6.0, 2.0),
               (7, 8.0, 1.5), (10, 9.5, 0.5), (8, 10.0, 1.0), (7, 11.0, 1.0), (5, 12.0, 2.0), (3, 14.0, 2.0),
               (7, 16.0, 1.5), (5, 17.5, 0.5), (3, 18.0, 1.0), (0, 19.0, 1.0), (-2, 20.0, 1.5), (3, 21.5, 0.5), (0, 22.0, 4.0),
               (-5, 26.0, 1.0), (-2, 27.0, 1.0), (0, 28.0, 4.0)]
    # Intense: the tune also opens the loop (bars 0-7 share the chords of 8-15).
    for start in (0, 8) if intense else (8,):
        for semis, at, length in whistle:
            f = note(semis - 5 + 12)
            dur = length * beat * 0.95
            x = theremin(np.full(int(SR * dur), f), dur) * env(dur, 0.04, dur * 1.3, power=0.6, release=0.08)
            put(filt(x, low=3800) + filt(noise(dur), low=4000, high=1500) * 0.02, start * 4 * beat + at * beat, 0.13, 0.6, 0.6)
    lead = [(12, 0, 3), (10, 3, 1), (7, 4, 2), (5, 6, 2), (7, 8, 3), (3, 11, 1), (5, 12, 4),
            (12, 16, 3), (14, 19, 1), (15, 20, 2), (14, 22, 2), (12, 24, 2), (10, 26, 2), (7, 28, 4),
            (7, 32, 2), (10, 34, 2), (12, 36, 3), (10, 39, 1), (7, 40, 4), (5, 44, 2), (3, 46, 2),
            (5, 48, 3), (7, 51, 1), (10, 52, 2), (12, 54, 2), (14, 56, 4), (11, 60, 4)]
    for i, (semis, at, length) in enumerate(lead):
        dur = length * beat
        prev = lead[i - 1][0] if i > 0 else semis
        n = int(SR * dur)
        glide = np.minimum(np.arange(n) / (SR * 0.09), 1.0)
        path = note(prev - 5) + (note(semis - 5) - note(prev - 5)) * glide
        x = theremin(path, dur) * env(dur, 0.06, dur * 1.2, power=0.5, release=0.1)
        put(x, 16 * 4 * beat + at * beat, 0.12, 0.45, 0.7)
    stereo_wet = reverb(wet, 1.8, 0.35)
    left = dry_l + stereo_wet[: len(dry_l)]
    right = dry_r + np.roll(stereo_wet[: len(dry_r)], int(SR * 0.013))
    # Fold the tail back onto the start so the loop is seamless.
    n = int(SR * d)
    left[: len(left) - n] += left[n:]
    right[: len(right) - n] += right[n:]
    return np.stack([left[:n], right[:n]], axis=1)


# ---------------------------------------------------------------------------
# Ambience
# ---------------------------------------------------------------------------

def _announcer(seconds):
    """A muffled PA voice: formant tones gated like syllables."""
    t = t_axis(seconds)
    base = 150 * (1 + 0.08 * np.sin(2 * np.pi * 0.7 * t))
    voice = osc(2 * np.pi * np.cumsum(base) / SR, "saw")
    formant = band(voice, 650, 160) * 2 + band(voice, 1250, 220) * 1.5
    syll = (np.sin(2 * np.pi * 4.3 * t) > -0.2).astype(float) * (np.sin(2 * np.pi * 0.9 * t + 1) > -0.6)
    syll = filt(syll, low=30)
    return radio(formant * syll, crackle=0.08) * env(seconds, 0.05, seconds * 2, power=0.3, release=0.2)


def dune_ambience():
    d = 30.0
    t = t_axis(d + 1.0)
    n = len(t)
    # Wind: two decorrelated noise beds with slow gusts and a whistling resonance.
    gust = 0.55 + 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 10.0 - 0.6)) ** 2
    gust2 = 0.5 + 0.5 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 7.5 + 1.3)) ** 3
    wl = filt(rng.uniform(-1, 1, n), low=1100, high=90) * gust
    wr = filt(rng.uniform(-1, 1, n), low=1100, high=90) * np.roll(gust, int(SR * 1.1))
    whistle = band(rng.uniform(-1, 1, n), 1750, 60) * gust2 * 2.5
    sand = filt(rng.uniform(-1, 1, n), high=5000) * gust2 * 0.12
    # Distant engines: a low drone plus one slow test-firing swell.
    drone = sum(np.sin(2 * np.pi * f * t + p) * g for f, g, p in ((41, 1.0, 0), (55, 0.6, 1.1), (82.5, 0.25, 0.4)))
    drone *= 0.09 * (0.85 + 0.15 * np.sin(2 * np.pi * 0.11 * t))
    swell = filt(rng.uniform(-1, 1, n), low=220, high=25) * np.exp(-((t - 15.0) / 4.0) ** 2) * 0.9
    left = wl * 0.55 + whistle * 0.25 + sand + drone + swell * 0.8
    right = wr * 0.55 + np.roll(whistle, int(SR * 0.4)) * 0.18 + np.roll(sand, 900) + drone * 0.9 + swell
    # PA chimes ("ding-dong") followed by a muffled announcement.
    for at, pan in ((4.0, 0.3), (19.5, 0.7)):
        chime = silence(1.6)
        place(chime, blip(note(7), 0.9, "sine", 0.8), 0.0, 0.5)
        place(chime, blip(note(3), 1.1, "sine", 1.0), 0.45, 0.5)
        chime = reverb(chime, 1.2, 0.6)[: len(chime)] + chime
        voice = _announcer(3.2)
        for x, offset, g in ((chime, 0.0, 0.16), (voice, 1.4, 0.07)):
            place(left, x, at + offset, g * (1 - pan) * 2)
            place(right, x, at + offset, g * pan * 2)
    # Far-off clanks and a reversing tug's beeper.
    for at, pan in ((8.3, 0.8), (12.9, 0.2), (26.2, 0.6)):
        clank = clunk(90, 0.25) * 0.5
        clank = clank + reverb(clank, 1.4, 0.8)[: len(clank)]
        place(left, clank, at, 0.12 * (1 - pan))
        place(right, clank, at, 0.12 * pan)
    for k in range(6):
        beep = blip(1150, 0.18, "square", 0.17) * 0.5
        place(left, filt(beep, low=3000), 22.0 + k * 0.45, 0.025)
        place(right, filt(beep, low=3000), 22.0 + k * 0.45, 0.04)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


MUSIC = {
    "launch_pad_loop": launch_pad_loop,
    "launch_pad_final": lambda: launch_pad_loop(intense=True),
    "dune_ambience": dune_ambience,
}
