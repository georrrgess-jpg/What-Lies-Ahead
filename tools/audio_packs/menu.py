"""The main menu theme: "Last Light on the Pier".

    python tools/gen_audio.py menu

Carnival at sunset meets synthwave. D major, 108 BPM, 32 bars = 71.1 s, a
seamless loop (every effect is circular, so tails wrap into the start).

    bars  0-3   intro    pads open up, a distant calliope plays the hook,
                         shaker and a soft bass; a riser into the verse
    bars  4-11  verse    the hook on a singing glide lead over a bouncy octave
                         bass, kick/snare, pads pumping with the kick
    bars 12-19  chorus   "royal road" lift (G A F#m Bm), plucked arp,
                         claps, open hats, a music-box answer
    bars 20-27  bridge   B minor turn, half-time drums and toms, a softer
                         lead over the calliope, then Bb-C rising home
    bars 28-31  reprise  the hook once more; the last bar thins out so the
                         intro's D chord lands as a fresh start

Every instrument is band-limited (polyBLEP saws, additive plucks and bells),
the lead is low-passed and the hats sit low, so nothing is shrill. The theme
shares the startup screen's sound (cine_startup in showreel.py ends on the
same D chord and quotes the hook's first notes).
"""
from gen_audio import *  # noqa: F401,F403

BPM = 108.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BARS = 32
LENGTH = BARS * BAR

# Pad voicings (semitones from A4) and the bass root under them.
CHORDS = {
    "D": ((-7, -3, 0, 5), -31), "Dmaj7": ((-7, -3, 0, 4), -31), "Bm7": ((-10, -7, -3, 0), -22),
    "Gmaj7": ((-14, -10, -7, -3), -26), "A": ((-12, -8, -5, 0), -24),
    "F#m7": ((-15, -12, -8, -5), -27), "Em7": ((-17, -14, -10, -7), -29), "G": ((-14, -10, -7, -2), -26),
    "F#m": ((-15, -12, -8, -3), -27), "Bm": ((-10, -7, -3, 2), -22), "F#": ((-15, -11, -8, -3), -27),
    "Bb": ((-11, -7, -4, 1), -23), "C": ((-9, -5, -2, 3), -21),
}
PROGRESSION = (
    ["D", "Bm7", "Gmaj7", "A"]                                       # intro
    + ["Dmaj7", "F#m7", "Gmaj7", "A", "Dmaj7", "Bm7", "Em7", "A"]    # verse
    + ["G", "A", "F#m", "Bm", "G", "A", "D", "D"]                    # chorus
    + ["Bm", "G", "Em7", "F#", "Bm", "G", "Bb", "C"]                 # bridge
    + ["D", "Bm7", "G", "A"]                                         # reprise
)

# Melody: per bar, (semitones from A4, beat, beats).
HOOK = [(0, 0, 0.5), (5, 0.5, 0.5), (9, 1, 1.5), (7, 2.5, 0.5), (5, 3, 0.5), (7, 3.5, 0.5)]
VERSE = [
    HOOK,
    [(4, 0, 1.5), (0, 1.5, 1.5)],
    [(2, 0, 0.5), (5, 0.5, 0.5), (10, 1, 1.5), (9, 2.5, 0.5), (7, 3, 0.5), (9, 3.5, 0.5)],
    [(7, 0, 2.5), (4, 3, 0.5), (2, 3.5, 0.5)],
    HOOK,
    [(9, 0, 1), (5, 1, 0.5), (2, 1.5, 1.5)],
    [(10, 0, 0.5), (9, 0.5, 0.5), (7, 1, 1), (5, 2, 0.5), (2, 2.5, 0.5), (5, 3, 1)],
    [(7, 0, 3)],
]
CHORUS = [
    [(5, 0, 0.5), (7, 0.5, 0.5), (9, 1, 1), (10, 2, 1), (9, 3, 0.5), (7, 3.5, 0.5)],
    [(7, 0, 1.5), (12, 1.5, 1.5), (10, 3, 0.5), (9, 3.5, 0.5)],
    [(9, 0, 1.5), (4, 1.5, 1.5), (7, 3, 1)],
    [(5, 0, 2), (0, 3, 0.5), (5, 3.5, 0.5)],
    [(5, 0, 0.5), (7, 0.5, 0.5), (9, 1, 1), (10, 2, 1), (12, 3, 0.5), (14, 3.5, 0.5)],
    [(16, 0, 1.5), (14, 1.5, 0.5), (12, 2, 1), (7, 3, 1)],
    [(9, 0, 1.5), (7, 1.5, 0.5), (5, 2, 2)],
    [],
]
BRIDGE = [
    [(9, 0, 2), (5, 2, 1), (2, 3, 1)],
    [(10, 0, 1.5), (9, 1.5, 0.5), (5, 2, 2)],
    [(7, 0, 2), (10, 2, 1), (14, 3, 1)],
    [(13, 0, 3)],
    [(14, 0, 1.5), (9, 1.5, 1.5), (5, 3, 1)],
    [(10, 0, 1.5), (5, 1.5, 1.5), (2, 3, 1)],
    [(5, 0, 1), (8, 1, 1), (13, 2, 2)],
    [(10, 0, 1), (7, 1, 1), (10, 2, 1), (12, 3, 1)],
]
REPRISE = [HOOK, VERSE[5], VERSE[2], [(7, 0, 2)]]
# The music box answers the chorus (bars 15 and 19), the calliope plays the hook in the intro.
ANSWER = [(17, 0, 0.5), (14, 0.5, 0.5), (12, 1, 0.5), (9, 1.5, 0.5), (12, 2, 1), (5, 3, 1)]


def _hz(semis):
    return 440.0 * 2 ** (semis / 12.0)


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

def _pad(voicing, seconds, cutoff):
    """Warm analog pad: three detuned band-limited saws per note, low-passed,
    slow attack and a long release (overlaps the next chord)."""
    x = sum(supersaw(_hz(s), seconds, 3, 0.1) for s in voicing)
    return filt(x, low=cutoff, slope=1.5) * adsr(seconds, 0.35, 1.0, 0.85, 0.8)


def _bass(semis, seconds, bright=1.0):
    """Bouncy synth bass: saw + square, its filter closing after the attack,
    saturated, plus a clean sine sub on the root."""
    f = _hz(semis)
    raw = bl_osc(f, seconds, "saw") * 0.6 + bl_osc(f, seconds, "square", 0.4) * 0.4
    dark, open_ = filt(raw, low=320), filt(raw, low=1400 * bright)
    t = t_axis(seconds)
    x = np.tanh(1.6 * (dark + (open_ - dark)[: len(t)] * np.exp(-t / 0.07)))
    return (x + bl_osc(f, seconds, "sine") * 0.6) * adsr(seconds, 0.003, 0.18, 0.7, 0.03)


def _lead(notes):
    """Singing lead for one phrase [(semis, start beat, beats)]: two detuned
    band-limited voices gliding between legato notes, delayed vibrato,
    low-passed, gently saturated. Returns (mono phrase, start seconds)."""
    start = notes[0][1] * BEAT
    end = (notes[-1][1] + notes[-1][2]) * BEAT
    d = end - start + 0.35
    n = int(SR * d)
    t = np.arange(n) / SR
    semis = np.full(n, float(notes[0][0]))
    amp = np.zeros(n)
    vib_age = np.zeros(n)
    prev_end = None
    for s, at, ln in notes:
        a = int(SR * (at * BEAT - start))
        b = min(n, int(SR * ((at + ln) * BEAT - start)))
        glide = 0.045 if prev_end is not None and abs(a - prev_end) < SR * 0.02 else 0.0
        seg = np.arange(n - a) / SR
        if glide:
            semis[a:] = s + (semis[a] - s) * np.exp(-seg / (glide / 3))
        else:
            semis[a:] = s
        vib_age[a:] = seg
        note_env = adsr((b - a) / SR + 0.12, 0.012 if glide == 0 else 0.03, 0.25, 0.8, 0.12)
        note_env = note_env[: n - a] if len(note_env) > n - a else np.pad(note_env, (0, n - a - len(note_env)))
        amp[a:] = np.maximum(amp[a:], note_env)
        prev_end = b
    vibrato = 0.16 * np.clip((vib_age - 0.22) / 0.35, 0, 1) * np.sin(2 * np.pi * 5.3 * t)
    f = 440.0 * 2 ** ((semis + vibrato) / 12.0)
    voice = (bl_osc(f * 2 ** (0.06 / 12), None, "saw") + bl_osc(f * 2 ** (-0.06 / 12), None, "square", 0.32) * 0.6
             + bl_osc(f, None, "sine") * 0.5)
    voice = filt(voice, low=2600, slope=1.5)
    return np.tanh(1.4 * voice * amp) * 0.8, start


def calliope(semis, seconds):
    """Steam calliope pipe: a few harmonics, breath and a wide wobbly vibrato."""
    t = t_axis(seconds)
    f = _hz(semis) * 2 ** (0.22 * np.sin(2 * np.pi * 6.2 * t) / 12.0)
    pipe = additive(f, None, [(1, 1.0, None), (2, 0.45, None), (3, 0.22, None), (4, 0.08, None)])
    breath = band(noise(seconds), _hz(semis) * 2, _hz(semis)) * 0.25
    return (pipe + breath) * adsr(seconds, 0.035, 0.3, 0.75, 0.07)


def _music_box(semis, seconds=0.9):
    """Soft music-box tine: a pure fundamental, quick harmonic chime."""
    partials = [(1, 1.0, 0.55), (2, 0.25, 0.18), (3.0, 0.1, 0.08), (4.2, 0.05, 0.04)]
    return additive(_hz(semis), seconds, partials) * adsr(seconds, 0.002, seconds, 1.0, 0.05)


def _kick():
    d = 0.36
    t = t_axis(d)
    f = 46 + 110 * np.exp(-t / 0.035)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * adsr(d, 0.001, 0.16, 0.0, 0.05)
    out = np.tanh(1.8 * body)
    place(out, kick_click(0.25, 2400), 0.0)
    return out


def _snare():
    d = 0.3
    t = t_axis(d)
    body = (np.sin(2 * np.pi * 185 * t) + np.sin(2 * np.pi * 290 * t) * 0.5) * np.exp(-t / 0.045)
    rattle = filt(noise(d), low=6500, high=1300) * np.exp(-t / 0.09)
    return (body * 0.55 + rattle) * adsr(d, 0.001, d, 1.0, 0.04)


def _hat(seconds=0.045, centre=7200):
    return band(noise(seconds), centre, centre * 0.3) * adsr(seconds, 0.001, seconds * 0.3, 0.0, 0.01)


def _shaker():
    d = 0.07
    return band(noise(d), 4800, 1800) * adsr(d, 0.012, 0.03, 0.0, 0.02)


def _tom(f0, d=0.4):
    t = t_axis(d)
    f = f0 * (1 + 0.5 * np.exp(-t / 0.03))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * adsr(d, 0.002, 0.14, 0.0, 0.05)


def _soft_crash(d=2.2):
    n = noise(d)
    return filt(filt(n, high=3000), low=9000) * adsr(d, 0.004, d * 0.35, 0.0, 0.3)


def _swell(seconds):
    """Reverse-cymbal swell into a downbeat."""
    t = t_axis(seconds)
    return filt(noise(seconds), low=7000, high=1500) * (t / seconds) ** 2.5 * np.clip((seconds - t) / 0.02, 0, 1)


# ---------------------------------------------------------------------------
# Arrangement
# ---------------------------------------------------------------------------

def _section(bar):
    if bar < 4:
        return "intro"
    if bar < 12:
        return "verse"
    if bar < 20:
        return "chorus"
    if bar < 28:
        return "bridge"
    return "reprise"


def _phrase(first_bar, bars):
    """One lead phrase over consecutive bars, in beats from the top of the loop."""
    return [(s, (first_bar + i) * 4 + at, ln) for i, notes in enumerate(bars) for s, at, ln in notes]


def _stems():
    """Renders the arrangement into five buses; returns them and the kick times."""
    drums, bass, pads, lead, keys = Bus(LENGTH), Bus(LENGTH), Bus(LENGTH), Bus(LENGTH), Bus(LENGTH)
    kick, snare, clap_ = _kick(), _snare(), clap(0.25)
    kicks = []
    for bar, name in enumerate(PROGRESSION):
        voicing, root = CHORDS[name]
        sec = _section(bar)
        t0 = bar * BAR
        last = bar == BARS - 1
        # --- pads (open up across the song) ---
        cutoff = {"intro": 700 + 180 * bar, "verse": 1300, "chorus": 1900, "bridge": 1200, "reprise": 1700}[sec]
        pads.add(_pad(voicing, BAR + 0.9, cutoff), t0, 0.2)
        # --- drums ---
        full = sec in ("verse", "chorus", "reprise")
        half = sec == "bridge" and bar < 24
        for b in range(4):
            at = t0 + b * BEAT
            if full or (sec == "bridge" and not half):
                if b in (0, 2) or (sec == "chorus" and b == 3):
                    drums.add(kick, at, 0.85 if b != 3 else 0.5)
                    kicks.append(at)
                if b in (1, 3) and not (last and b == 3):
                    drums.add(snare, at, 0.42)
                    if sec == "chorus":
                        drums.add(clap_, at + 0.006, 0.3, 0.55)
            elif half:
                if b == 0:
                    drums.add(kick, at, 0.8)
                    kicks.append(at)
                if b == 2:
                    drums.add(snare, at, 0.4)
            if sec == "chorus" and b in (1, 3):
                drums.add(_hat(0.16, 7000), at + 0.5 * BEAT, 0.08, 0.68)
            if sec != "intro" or bar >= 2:
                for h in (0, 1):
                    swing = 0.04 * BEAT if h else 0.0
                    drums.add(_hat(), at + 0.5 * BEAT * h + swing, 0.07 if h else 0.04, 0.66)
            for s in range(4):
                accent = (0.06, 0.03, 0.045, 0.03)[s]
                drums.add(_shaker(), at + s * 0.25 * BEAT + (0.03 * BEAT if s % 2 else 0.0), accent, 0.36)
        if bar in (3, 11, 27):
            drums.add(_swell(2 * BEAT), t0 + 2 * BEAT, 0.12, 0.5)
        if bar in (4, 12, 20, 28):
            drums.add(_soft_crash(), t0, 0.07, 0.42)
        if bar in (23, 27):
            for k, f0 in enumerate((150, 125, 104, 88)):
                drums.add(_tom(f0), t0 + (2 + 0.5 * k) * BEAT, 0.5, 0.35 + 0.1 * k)
        if bar == 19:
            for s in range(8):
                drums.add(snare, t0 + (2 + s * 0.25) * BEAT, 0.08 + 0.025 * s)
        # --- bass ---
        if sec == "intro":
            if bar >= 1:
                for b in (0, 2):
                    bass.add(_bass(root, BEAT * 1.8, 0.6), t0 + b * BEAT, 0.5)
        elif half:
            bass.add(_bass(root, BAR * 0.96, 0.7), t0, 0.55)
            bass.add(_bass(root + 12, BEAT * 0.45, 0.8), t0 + 3.5 * BEAT, 0.35)
        else:
            pattern = [0, 12, 0, 12, 0, 12, 7, 12]
            for e, step in enumerate(pattern):
                if last and e >= 6:
                    break
                ln = BEAT * (0.42 if step else 0.47)
                gain = 0.55 if step == 0 else 0.42
                bass.add(_bass(root + step, ln), t0 + e * 0.5 * BEAT, gain)
            if bar % 2 == 1 and not last:
                bass.add(_bass(root + 10, BEAT * 0.2), t0 + 3.75 * BEAT, 0.3)
        # --- arp (chorus, bridge, reprise) ---
        if sec in ("chorus", "bridge", "reprise") and not last:
            tones = sorted(set(s + 12 for s in voicing[1:]) | {voicing[0] + 24})
            order = [0, 1, 2, 3, 2, 1, 0, 1]
            for e in range(16 if sec != "bridge" or bar >= 24 else 8):
                step = BEAT / 4 if sec != "bridge" or bar >= 24 else BEAT / 2
                s = tones[order[e % 8] % len(tones)]
                pl = pluck(_hz(s), 0.3, 10, 0.18, 1.3)
                keys.add(pl, t0 + e * step, 0.075, 0.25 if e % 2 else 0.75)
    # --- calliope hook (intro) and in the bridge, music-box answers ---
    for bar, notes in enumerate(VERSE[:4]):
        for s, at, ln in notes:
            keys.add(calliope(s, ln * BEAT * 0.96), bar * BAR + at * BEAT, 0.16 if bar < 2 else 0.2, 0.62)
    for i, notes in enumerate(BRIDGE):
        for s, at, ln in notes:
            keys.add(calliope(s - 12, ln * BEAT * 0.96), (20 + i) * BAR + at * BEAT, 0.1, 0.62)
    for bar in (15, 19):
        for s, at, ln in ANSWER:
            keys.add(_music_box(s), bar * BAR + at * BEAT, 0.18, 0.3)
    # --- lead ---
    for first_bar, bars, gain, cutoff in ((4, VERSE, 0.3, None), (12, CHORUS, 0.3, None), (20, BRIDGE, 0.2, 1800), (28, REPRISE, 0.3, None)):
        x, start = _lead(_phrase(first_bar, bars))
        lead.add(filt(x, low=cutoff) if cutoff else x, start, gain)
    return {"drums": drums.loop(), "bass": bass.loop(), "pads": pads.loop(), "lead": lead.loop(), "keys": keys.loop()}, kicks


def _processed(stems, kicks):
    """The stems after the pump, chorus, hall and echo: what is summed."""
    d_mix, b_mix, p_mix, l_mix, k_mix = (stems[k] for k in ("drums", "bass", "pads", "lead", "keys"))
    g = pump(len(d_mix), kicks, depth=0.45, release=0.3)[:, None]
    pads_wide = chorus(p_mix.mean(axis=1)) * 0.8 + p_mix * 0.4
    sends = pads_wide * 0.35 + l_mix * 0.5 + k_mix * 0.6 + d_mix * 0.12
    return {
        "drums": d_mix * 0.8, "bass": b_mix * (0.28 + 0.52 * g), "pads": pads_wide * g, "lead": l_mix,
        "keys": k_mix * (0.6 + 0.4 * g), "hall": reverb(sends[:, 0], sends[:, 1], seconds=2.6, dark=3200) * 0.5,
        "delay": echo(l_mix.mean(axis=1) * 0.5 + k_mix.mean(axis=1) * 0.4, 0.75 * BEAT, 0.38, 5, low=2600) * 0.4,
    }


def menu_theme():
    mix = sum(_processed(*_stems()).values())
    return np.tanh(mix * 0.9) / 0.9


SOUNDS = []
LOOPS = {}
MUSIC = {"menu_theme": menu_theme}
