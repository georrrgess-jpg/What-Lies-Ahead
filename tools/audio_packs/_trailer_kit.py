"""The trailer score's instruments and studio (used by showreel.py).

Everything is synthesised: no samples. Pitches are semitones from A4 (A4 = 0,
D4 = -7, D2 = -31). Instruments return mono arrays, or (n, 2) stereo where the
ensemble itself is spread (choir, strings).

    choir      many detuned voices (own vibrato, drift, onset) through vowel
               formant filters ("ah", "oh", "oo"), breath noise in the vowel
    strings    ensemble legato (slow bow attack, brightening, bow noise),
               spiccato (short envelopes, filter snap, bow scrape), tremolo
    brass      additive players whose brightness follows the envelope and the
               velocity, a pitch scoop into each note, three-player unison
    drums      taiko / toms / snare as pitched membrane modes with a pitch drop
               and a stick transient; kick; shaker; crash
    impacts    sub drop + mid body + struck-plate metal + noise crack + rumble
    carnival   band organ (flue + reed ranks, tremulant, chiff), music box,
               glockenspiel, tower bell
    fx         risers, reverse swells, whooshes, drone, wind, heartbeat
    studio     a convolution hall built from a synthesised impulse response
               (early reflections + a tail whose highs die first), envelope-
               following filters, bus compressor, sidechain, gates, M/S
"""
import math

import numpy as np

from gen_audio import SR, adsr, band, bl_osc, filt

R = np.random.default_rng(1)


def reseed(seed):
    """Every render starts from the same random state (the score is reproducible)."""
    global R
    R = np.random.default_rng(seed)


def hz(semis):
    return 440.0 * 2 ** (np.asarray(semis, dtype=np.float64) / 12.0)


def taxis(seconds):
    return np.arange(int(SR * seconds)) / SR


def noise(seconds):
    return R.uniform(-1.0, 1.0, int(SR * seconds))


def smooth_noise(seconds, rate):
    """A slowly wandering curve in about [-1, 1] (`rate` Hz)."""
    n = int(SR * seconds)
    k = max(2, int(seconds * rate) + 3)
    pts = R.uniform(-1, 1, k)
    return np.interp(np.arange(n), np.linspace(0, n, k), pts)


def stereo(x, pan=0.5):
    """Equal-power pan of a mono signal into (n, 2)."""
    return x[:, None] * np.array([math.cos(pan * math.pi / 2), math.sin(pan * math.pi / 2)]) * math.sqrt(2)


def haas(x, ms=11.0, side=1):
    """Width without phase trouble in the lows: one side is the other delayed
    by `ms`, high-passed so the bass stays centred."""
    d = int(SR * ms / 1000)
    late = np.concatenate([np.zeros(d), x[:-d]]) if d else x
    late = filt(late, high=300) + filt(x, low=300)
    return np.stack([x, late] if side > 0 else [late, x], axis=1)


# ---------------------------------------------------------------------------
# Filters
# ---------------------------------------------------------------------------

_CUTS = np.geomspace(40.0, 18000.0, 22)


def tv_lowpass(x, cutoff, slope=1.5):
    """Low-pass whose cutoff moves per sample (`cutoff` an array or number):
    a bank of zero-phase filtered copies blended in log-frequency. Used for
    every envelope-following filter (brass brightness, bass snap, sweeps)."""
    n = len(x)
    fc = np.clip(np.broadcast_to(np.asarray(cutoff, dtype=np.float64), (n,)), _CUTS[0], _CUTS[-1])
    pos = np.interp(np.log(fc), np.log(_CUTS), np.arange(len(_CUTS)))
    lo = np.clip(np.floor(pos).astype(int), 0, len(_CUTS) - 2)
    k = pos - lo
    out = np.zeros(n)
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    for i in range(lo.min(), lo.max() + 2):
        w = (1 - k) * (lo == i) + k * (lo == i - 1)
        if not np.any(w):
            continue
        out += np.fft.irfft(spec / (1.0 + (f / _CUTS[i]) ** (2 * slope)), n) * w
    return out


def tv_band(x, centre, q=2.0):
    """Band-pass with a moving centre (two tv_lowpass copies subtracted)."""
    c = np.asarray(centre, dtype=np.float64)
    return tv_lowpass(x, c * (1 + 0.5 / q)) - tv_lowpass(x, c / (1 + 0.5 / q))


def eq_bell(x, fc, gain_db, q=1.0):
    spec = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    f[0] = 1e-3
    a = 10 ** (gain_db / 40.0)
    w = f / fc
    g = np.sqrt(((1 - w * w) ** 2 + (w * a / q) ** 2) / ((1 - w * w) ** 2 + (w / (a * q)) ** 2))
    return np.fft.irfft(spec * (g if x.ndim == 1 else g[:, None]), len(x), axis=0)


def hp(x, fc, slope=2.0):
    if x.ndim == 2:
        return np.stack([filt(x[:, 0], high=fc, slope=slope), filt(x[:, 1], high=fc, slope=slope)], axis=1)
    return filt(x, high=fc, slope=slope)


def lp(x, fc, slope=2.0):
    if x.ndim == 2:
        return np.stack([filt(x[:, 0], low=fc, slope=slope), filt(x[:, 1], low=fc, slope=slope)], axis=1)
    return filt(x, low=fc, slope=slope)


def sat(x, drive=1.5):
    """Gentle tape-like saturation (unity gain for small signals)."""
    return np.tanh(x * drive) / drive


# ---------------------------------------------------------------------------
# Choir
# ---------------------------------------------------------------------------

# (centre Hz, bandwidth Hz, level dB): a mixed alto/soprano section.
VOWELS = {
    "ah": ((790, 90, 0), (1180, 110, -5), (2800, 160, -22), (3550, 200, -30), (4950, 250, -48)),
    "oh": ((470, 80, 0), (820, 90, -9), (2800, 150, -24), (3500, 200, -32), (4950, 250, -50)),
    "oo": ((350, 70, 0), (640, 80, -12), (2700, 150, -32), (3400, 200, -40)),
}


def _formant_gain(f, vowel):
    g = np.full_like(f, 0.015)
    for fc, bw, db in VOWELS[vowel]:
        g += 10 ** (db / 20.0) / np.sqrt(1.0 + ((f - fc) / (bw / 2.0)) ** 2)
    g *= 1.0 / np.sqrt(1.0 + (130.0 / np.maximum(f, 1.0)) ** 4)      # no rumble from the chest
    g *= 1.0 / (1.0 + (f / 6500.0) ** 4)                               # no fizz
    return g


def formant(x, vowel):
    spec = np.fft.rfft(x)
    return np.fft.irfft(spec * _formant_gain(np.fft.rfftfreq(len(x), 1.0 / SR), vowel), len(x))


def choir(notes, seconds, vowel="ah", attack=0.25, release=0.6, singers=6, vibrato=0.22, breath=0.06):
    """A choir chord (n, 2): `singers` voices per note, each with its own
    detune, vibrato (rate, depth, delayed onset), slow pitch drift, onset
    jitter and level, glottal saw source; the voices are split left/right and
    each side goes through the vowel's formant filter with breath noise."""
    n = int(SR * seconds)
    t = np.arange(n) / SR
    sides = [np.zeros(n), np.zeros(n)]
    for semis in notes:
        f0 = float(hz(semis))
        for v in range(singers):
            cents = R.normal(0, 8)
            rate = R.uniform(4.6, 5.9)
            depth = vibrato * R.uniform(0.6, 1.2) * np.clip((t - 0.25) / 0.6, 0, 1)
            pitch = cents / 100 + depth * np.sin(2 * np.pi * rate * t + R.uniform(0, 6.3)) + 0.06 * smooth_noise(seconds, 3.0)
            onset = int(R.uniform(0, 0.035) * SR)
            f = f0 * 2 ** (pitch / 12.0)
            voice = bl_osc(f, None, "saw") * 0.75 + bl_osc(f, None, "square", 0.42) * 0.25
            voice *= (0.8 + 0.2 * smooth_noise(seconds, 1.5)) * R.uniform(0.7, 1.0)
            voice *= np.clip(t / 0.01, 0, 1)
            if onset:
                voice = np.concatenate([np.zeros(onset), voice[:-onset]])
            sides[v % 2] += voice
    shape = adsr(seconds, attack, 1.0, 1.0, min(release, seconds * 0.5))
    out = []
    for side in sides:
        air = noise(seconds) * breath * len(notes)
        out.append(formant(side + air, vowel) * shape)
    scale = 1.0 / (len(notes) * singers) ** 0.5
    return np.stack(out, axis=1) * scale


# ---------------------------------------------------------------------------
# Strings
# ---------------------------------------------------------------------------

def _ensemble(f0, seconds, players, spread=0.1, vib=0.12):
    """A string section: band-limited saws with individual vibrato and drift."""
    t = taxis(seconds)
    sides = [np.zeros(len(t)), np.zeros(len(t))]
    for p in range(players):
        pitch = R.uniform(-spread, spread) + vib * R.uniform(0.5, 1.0) * np.sin(2 * np.pi * R.uniform(4.6, 6.2) * t + R.uniform(0, 6.3)) \
            * np.clip(t / 0.4, 0, 1) + 0.04 * smooth_noise(seconds, 2.0)
        sides[p % 2] += bl_osc(f0 * 2 ** (pitch / 12.0), None, "saw", phase=R.uniform())
    return sides


def strings(notes, seconds, attack=0.45, release=0.7, bright=3200.0, players=6):
    """Legato section chord (n, 2): slow bow attack, the tone brightening as
    the bow bites, bow noise, a soft release."""
    t = taxis(seconds)
    shape = adsr(seconds, attack, 1.0, 1.0, min(release, seconds * 0.6))
    out = []
    sides = [np.zeros(len(t)), np.zeros(len(t))]
    for s in notes:
        a, b = _ensemble(float(hz(s)), seconds, players)
        sides[0] += a
        sides[1] += b
    cutoff = 500 + (bright - 500) * np.clip(t / (attack * 1.5), 0, 1) ** 0.7
    for side in sides:
        bow = band(noise(seconds), 2600, 1400) * 0.05 * len(notes)
        x = tv_lowpass(side, cutoff, 1.3) + bow
        out.append(filt(x, high=110) * shape)
    return np.stack(out, axis=1) / (len(notes) * players) ** 0.5


def spiccato(semis, seconds=0.13, vel=1.0, players=3):
    """One short bounced-bow note (mono): fast attack, a filter that snaps
    shut, a scrape of rosin on the attack."""
    t = taxis(seconds)
    f0 = float(hz(semis))
    x = sum(bl_osc(f0 * 2 ** (R.uniform(-0.08, 0.08) / 12), seconds, "saw", phase=R.uniform()) for _ in range(players)) / players
    cut = 700 + (1500 + 2500 * vel) * np.exp(-t / 0.045)
    x = tv_lowpass(x, cut, 1.2)
    scrape = band(noise(seconds), 3200, 1500) * np.exp(-t / 0.008) * 0.25
    shape = np.clip(t / 0.004, 0, 1) * np.exp(-t / (0.055 + 0.02 * vel))
    shape *= np.clip((seconds - t) / 0.01, 0, 1)
    return (x + scrape) * shape * vel


def tremolo(notes, seconds, rate=13.0, attack=0.3, bright=2800.0):
    """Bowed tremolo (n, 2): the section's bows each moving at their own rate."""
    base = strings(notes, seconds, attack=attack, bright=bright, players=6)
    t = taxis(seconds)
    out = []
    for c in range(2):
        r = rate * R.uniform(0.93, 1.07)
        am = 0.55 + 0.45 * np.abs(np.sin(np.pi * r * t + R.uniform(0, 3)))
        out.append(base[:, c] * am)
    return np.stack(out, axis=1)


# ---------------------------------------------------------------------------
# Brass
# ---------------------------------------------------------------------------

def brass_note(semis, seconds, vel=1.0, attack=0.03, release=0.25, players=3, scoop=0.6, sustain=0.75):
    """A brass section note (mono): additive players whose upper harmonics
    open with the envelope and the velocity (the "blat" of a hard attack),
    each scooping up into the pitch, slightly late, slightly detuned."""
    n = int(SR * seconds)
    t = np.arange(n) / SR
    f0 = float(hz(semis))
    out = np.zeros(n)
    amp = adsr(seconds, attack, 0.35, sustain, min(release, seconds * 0.5))
    for p in range(players):
        late = int(R.uniform(0, 0.014) * SR)
        cents = R.normal(0, 5) / 100
        vib = 0.08 * np.sin(2 * np.pi * R.uniform(4.8, 5.6) * t) * np.clip((t - 0.35) / 0.5, 0, 1)
        pitch = cents - scoop * np.exp(-t / 0.035) + vib
        phase = 2 * np.pi * np.cumsum(f0 * 2 ** (pitch / 12.0)) / SR + R.uniform(0, 6.3)
        bright = vel * (0.25 + 0.75 * amp) + 0.5 * vel * np.exp(-t / 0.06)
        width = 1.0 + 9.0 * bright           # how many harmonics speak
        x = np.zeros(n)
        kmax = int(min(28, 7500.0 / f0))
        for k in range(1, kmax + 1):
            x += np.sin(k * phase) * (k ** -0.7) * np.exp(-(k - 1) / width)
        x *= np.clip(t / 0.006, 0, 1)                    # each player's own soft onset
        if late:
            x = np.concatenate([np.zeros(late), x[:-late]])
        out += x
    out = np.tanh(out / players * amp * 1.4)
    breath = band(noise(seconds), 1800, 900) * np.exp(-t / 0.05) * 0.06 * vel
    return out + breath


def brass(notes, seconds, **kw):
    return sum(brass_note(s, seconds, **kw) for s in notes) / max(1, len(notes)) ** 0.6


# ---------------------------------------------------------------------------
# Drums and impacts
# ---------------------------------------------------------------------------

MEMBRANE = ((1.0, 1.0, 1.0), (1.593, 0.55, 0.55), (2.136, 0.4, 0.4), (2.296, 0.3, 0.33), (2.653, 0.22, 0.25),
            (2.918, 0.16, 0.2), (3.156, 0.12, 0.16), (3.501, 0.08, 0.12))


def membrane(f0, seconds, decay, drop=0.4, drop_tau=0.035, stick=0.5, stick_hz=2400.0, modes=MEMBRANE):
    """A struck drum head: circular-membrane modes (Bessel ratios), all
    pitched up at the strike and falling (tension relaxing), a stick
    transient (click + band of noise) on the first milliseconds."""
    t = taxis(seconds)
    bend = 1.0 + drop * np.exp(-t / drop_tau)
    phase = 2 * np.pi * np.cumsum(f0 * bend) / SR
    x = np.zeros(len(t))
    for ratio, gain, dk in modes:
        if f0 * ratio > 0.4 * SR:
            continue
        x += np.sin(phase * ratio + R.uniform(0, 0.3)) * gain * np.exp(-t / (decay * dk))
    click = band(noise(seconds), stick_hz, stick_hz * 0.6) * np.exp(-t / 0.004) * stick
    shape = np.clip(t / 0.0012, 0, 1)
    return (x + click) * shape


def taiko(f0=58.0, seconds=1.4, vel=1.0):
    """Big drum: deep membrane, a slap of skin, a short thud of air."""
    x = membrane(f0, seconds, 0.38 + 0.12 * vel, drop=0.5, stick=0.35 * vel, stick_hz=1800)
    t = taxis(seconds)
    air = filt(noise(seconds), low=200) * np.exp(-t / 0.05) * 0.6
    return (x + air) * vel


def tom(f0=110.0, seconds=0.7, vel=1.0):
    return membrane(f0, seconds, 0.22, drop=0.35, stick=0.45, stick_hz=3000) * vel


def kick(seconds=0.5, vel=1.0, punch=1.0):
    t = taxis(seconds)
    f = 48 + 110 * np.exp(-t / 0.03) + 40 * np.exp(-t / 0.006)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.22) * np.clip(t / 0.001, 0, 1)
    click = filt(noise(seconds), high=1500, low=6000) * np.exp(-t / 0.003) * np.clip(t / 0.0004, 0, 1) * 0.35 * punch
    return np.tanh((body + click) * 1.4) * vel


def snare(seconds=0.45, vel=1.0, tone=1.0):
    """Shell modes plus the snare wires (band of noise) plus the stick crack."""
    t = taxis(seconds)
    shell = membrane(190, seconds, 0.12, drop=0.25, stick=0.0) * 0.6 * tone
    wires = filt(noise(seconds), high=1800, low=7500) * np.exp(-t / (0.09 + 0.04 * vel)) * 0.8
    crack = filt(noise(seconds), high=1200, low=5000) * np.exp(-t / 0.006) * 0.9
    return (shell + wires + crack) * np.clip(t / 0.0008, 0, 1) * vel


def shaker(seconds=0.09, vel=1.0):
    t = taxis(seconds)
    x = filt(noise(seconds), high=4200, low=8500)
    return x * np.clip(t / 0.012, 0, 1) * np.exp(-t / 0.025) * vel


def hat(seconds=0.07, vel=1.0, open_=False):
    """Six detuned square partials (a metal disc) plus noise, band-limited to 10 kHz."""
    t = taxis(seconds)
    x = sum(bl_osc(f, seconds, "square") for f in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0)) / 6
    x = filt(x + noise(seconds) * 0.6, high=6500, low=10000)
    return x * np.exp(-t / (0.18 if open_ else 0.025)) * np.clip(t / 0.0007, 0, 1) * vel


def crash(seconds=3.0, vel=1.0, dark=9000.0):
    """A crash cymbal: a bright wash of inharmonic partials and noise whose
    highs fade first."""
    t = taxis(seconds)
    ratios = R.uniform(1.0, 9.0, 40)
    x = sum(np.sin(2 * np.pi * 420.0 * r * t + R.uniform(0, 6.3)) * r ** -0.5 for r in ratios) / 12
    x = x + noise(seconds) * 0.9
    bright = tv_lowpass(x, 2500 + (dark - 2500) * np.exp(-t / 0.7), 1.2)
    x = filt(bright, high=600) * np.exp(-t / (0.9 * seconds / 3.0)) * np.clip(t / 0.002, 0, 1)
    return x * vel


PLATE = ((1.0, 1.0, 1.5), (1.504, 0.8, 1.2), (1.742, 0.7, 1.0), (2.296, 0.55, 0.85), (2.653, 0.5, 0.7),
         (3.161, 0.4, 0.55), (3.598, 0.32, 0.45), (4.07, 0.25, 0.35), (4.54, 0.2, 0.3), (5.39, 0.14, 0.22))


def metal(base=180.0, seconds=2.5, decay=1.0, vel=1.0):
    """A struck steel plate: inharmonic partials in beating pairs (the
    shimmer), each dying at its own rate, plus the strike."""
    t = taxis(seconds)
    x = np.zeros(len(t))
    for ratio, gain, dk in PLATE:
        f = base * ratio
        if f > 9000:
            continue
        for beat in (1.0, 1.0 + R.uniform(0.002, 0.006)):
            x += np.sin(2 * np.pi * f * beat * t + R.uniform(0, 6.3)) * gain * np.exp(-t / (decay * dk))
    strike = band(noise(seconds), 3500, 1800) * np.exp(-t / 0.006) * 1.2
    return (x * 0.35 + strike) * np.clip(t / 0.0006, 0, 1) * vel


def impact(size=1.0, seconds=5.0, metal_base=150.0):
    """The trailer hit: a sub drop, a mid body punch, struck metal, a noise
    crack and a long low rumble. The transient is on sample 0."""
    t = taxis(seconds)
    sub_f = 26 + 38 * np.exp(-t / (0.35 * size)) + 30 * np.exp(-t / 0.02)
    sub = np.sin(2 * np.pi * np.cumsum(sub_f) / SR) * np.exp(-t / (1.1 * size)) * np.clip(t / 0.002, 0, 1)
    body_f = 52 + 120 * np.exp(-t / 0.05)
    body = np.sin(2 * np.pi * np.cumsum(body_f) / SR) * np.exp(-t / 0.18) * 0.9
    thump = filt(noise(seconds), low=380) * np.exp(-t / 0.07) * 1.6
    clang = metal(metal_base, seconds, decay=0.9 * size) * 0.55
    crack = filt(noise(seconds), high=1500, low=9000) * np.exp(-t / 0.012) * 0.9
    rumble = filt(noise(seconds), low=140) * np.exp(-t / (1.4 * size)) * np.clip(t / 0.05, 0, 1) * 2.2
    x = np.tanh((sub * 1.1 + body + thump + rumble * 0.6) * 0.9)
    return (x + clang + crack * 2.5) * size


def boom(seconds=4.0, size=1.0):
    """A low boom without metal (softer endings, the half-time thud)."""
    t = taxis(seconds)
    f = 28 + 44 * np.exp(-t / 0.3) + 40 * np.exp(-t / 0.015)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / (1.0 * size)) * np.clip(t / 0.002, 0, 1)
    x += filt(noise(seconds), low=220) * np.exp(-t / 0.12) * 1.4
    x += filt(noise(seconds), high=900, low=4000) * np.exp(-t / 0.008) * 0.4
    return np.tanh(x) * size


# ---------------------------------------------------------------------------
# Carnival colour
# ---------------------------------------------------------------------------

def organ(semis, seconds, vel=1.0, reed=0.6):
    """Fairground band organ: a flue rank (8' + 4'), a reed rank, the
    tremulant wobbling pitch and level together, a chiff at the onset."""
    t = taxis(seconds)
    f0 = float(hz(semis))
    trem = np.sin(2 * np.pi * 6.4 * t + R.uniform(0, 6.3))
    f = f0 * 2 ** (0.09 * trem / 12)
    phase = 2 * np.pi * np.cumsum(f) / SR
    flue = np.sin(phase) + 0.45 * np.sin(2 * phase) + 0.18 * np.sin(3 * phase) + 0.3 * np.sin(4 * phase)
    rd = bl_osc(f * 1.002, None, "square", 0.28)
    rd = filt(rd, low=2600, slope=1.2) * reed
    chiff = band(noise(seconds), f0 * 3, f0) * np.exp(-t / 0.025) * 0.4
    shape = adsr(seconds, 0.018, 0.2, 0.85, min(0.06, seconds * 0.3)) * (1 + 0.12 * trem)
    return (flue * 0.6 + rd + chiff) * shape * vel * 0.55


def music_box(semis, seconds=1.4, wow=0.0, vel=1.0):
    """A music-box tine: a pure fundamental, a quick inharmonic chime, the
    pluck of the pin; `wow` detunes it (a mechanism running down)."""
    t = taxis(seconds)
    f0 = float(hz(semis)) * 2 ** (wow / 12)
    x = np.zeros(len(t))
    for ratio, gain, dk in ((1.0, 1.0, 0.9), (3.0, 0.12, 0.2), (5.93, 0.18, 0.08), (9.8, 0.06, 0.03)):
        if f0 * ratio < 15000:
            x += np.sin(2 * np.pi * f0 * ratio * t) * gain * np.exp(-t / dk)
    pin = filt(noise(seconds), high=2500, low=7000) * np.exp(-t / 0.002) * 0.15
    return (x + pin) * np.clip(t / 0.001, 0, 1) * np.clip((seconds - t) / 0.03, 0, 1) * vel


def glock(semis, seconds=1.2, vel=1.0):
    """Glockenspiel bar: free-bar partials (1, 2.76, 5.40, 8.93), mallet tick."""
    t = taxis(seconds)
    f0 = float(hz(semis))
    x = np.zeros(len(t))
    for ratio, gain, dk in ((1.0, 1.0, 0.8), (2.76, 0.3, 0.18), (5.40, 0.12, 0.05), (8.93, 0.05, 0.02)):
        if f0 * ratio < 15000:
            x += np.sin(2 * np.pi * f0 * ratio * t) * gain * np.exp(-t / dk)
    tick = band(noise(seconds), 4000, 1500) * np.exp(-t / 0.0015) * 0.2
    return (x + tick) * np.clip(t / 0.0006, 0, 1) * np.clip((seconds - t) / 0.03, 0, 1) * vel


BELL = ((0.5, 0.35, 2.4), (1.0, 1.0, 1.6), (1.183, 0.5, 1.2), (1.506, 0.35, 0.9), (2.0, 0.4, 0.7),
        (2.514, 0.2, 0.5), (2.662, 0.18, 0.4), (3.011, 0.12, 0.3))


def bell(semis, seconds=3.0, vel=1.0):
    """A tower bell: hum, strike, minor-third tierce, quint, nominal."""
    t = taxis(seconds)
    f0 = float(hz(semis))
    x = np.zeros(len(t))
    for ratio, gain, dk in BELL:
        for beat in (1.0, 1.0015):
            x += np.sin(2 * np.pi * f0 * ratio * beat * t + R.uniform(0, 6.3)) * gain * np.exp(-t / dk) * 0.5
    strike = band(noise(seconds), 2500, 1200) * np.exp(-t / 0.003) * 0.3
    return (x + strike) * np.clip(t / 0.0008, 0, 1) * np.clip((seconds - t) / 0.05, 0, 1) * vel


def pluck(semis, seconds=0.35, vel=1.0, bright=1.0):
    """A soft synth pluck for the arpeggios: two saws, a filter snapping shut."""
    t = taxis(seconds)
    f0 = float(hz(semis))
    x = bl_osc(f0 * 1.003, seconds, "saw") + bl_osc(f0 * 0.997, seconds, "saw")
    x = tv_lowpass(x, 500 + 3000 * bright * np.exp(-t / 0.05), 1.3)
    return x * np.clip(t / 0.002, 0, 1) * np.exp(-t / 0.12) * np.clip((seconds - t) / 0.01, 0, 1) * vel * 0.5


# ---------------------------------------------------------------------------
# Lead and bass
# ---------------------------------------------------------------------------

def lead(notes, beat, glide=0.045, cutoff=3000.0, voices=5, detune=0.14):
    """A singing supersaw lead for a phrase [(semis, start beat, beats)]:
    legato glides, a delayed vibrato, each note's filter opening on its
    attack, saturated. Returns (mono, start seconds)."""
    start = notes[0][1] * beat
    end = (notes[-1][1] + notes[-1][2]) * beat
    d = end - start + 0.4
    n = int(SR * d)
    t = np.arange(n) / SR
    semis = np.full(n, float(notes[0][0]))
    amp = np.zeros(n)
    cut = np.full(n, cutoff * 0.4)
    for i, (s, at, ln) in enumerate(notes):
        a = int((at * beat - start) * SR)
        b = int(((at + ln) * beat - start) * SR)
        prev = notes[i - 1][0] if i else s
        u = np.arange(n - a) / SR
        semis[a:] = s + (prev - s) * np.exp(-u / glide)
        local = np.arange(b - a) / SR
        amp[a:b] = np.maximum(amp[a:b], np.clip(local / 0.012, 0, 1) * (0.85 + 0.15 * np.exp(-local / 0.15)))
        tail = min(n, b + int(0.12 * SR))
        amp[b:tail] = np.maximum(amp[b:tail], np.linspace(amp[b - 1] if b > a else 0, 0, tail - b))
        cut[a:b] = cutoff * (0.55 + 0.45 * np.exp(-local / 0.18)) + cutoff * 0.25
    vib = 0.18 * np.sin(2 * np.pi * 5.4 * t) * np.clip((t - 0.25) / 0.5, 0, 1)
    f = 440.0 * 2 ** ((semis + vib) / 12.0)
    x = np.zeros(n)
    for v in range(voices):
        off = detune * (2.0 * v / (voices - 1) - 1.0)
        x += bl_osc(f * 2 ** (off / 12.0), None, "saw", phase=R.uniform())
    x = tv_lowpass(x / voices, cut, 1.4)
    amp = np.convolve(amp, np.ones(64) / 64, mode="same")
    return np.tanh(1.8 * x * amp) / 1.4, start


def bass_note(semis, seconds, vel=1.0, drive=1.5, grit=0.0):
    """Synth bass: saw + square through a filter that snaps from bright to
    dark after the attack, saturated; a clean sine sub under it; `grit` adds a
    distorted mid layer (the drop). Returns (body, sub)."""
    t = taxis(seconds)
    f0 = float(hz(semis))
    raw = bl_osc(f0, seconds, "saw") * 0.6 + bl_osc(f0 * 1.004, seconds, "square", 0.4) * 0.4
    cut = 260 + (900 + 1600 * vel) * np.exp(-t / 0.06)
    x = np.tanh(drive * tv_lowpass(raw, cut, 1.4))
    if grit:
        g = np.tanh(6.0 * filt(raw, low=1800)) * grit
        x = x + filt(g, high=250, low=2400) * 0.5
    shape = adsr(seconds, 0.003, 0.15, 0.75, min(0.03, seconds * 0.3))
    sub = np.sin(2 * np.pi * f0 * t) * shape
    if f0 > 70:
        sub = np.sin(np.pi * f0 * t) * shape            # the octave below for high notes
    return filt(x * shape, high=90) * vel, sub * vel


# ---------------------------------------------------------------------------
# Effects
# ---------------------------------------------------------------------------

def riser(seconds, top=7000.0, pitched=(-19, -12, -7), octaves=2.0):
    """Noise sweeping up in a narrowing band plus a detuned chord gliding up
    `octaves`, tremolo speeding up; it ends at full level on its last sample."""
    t = taxis(seconds)
    u = t / seconds
    centre = 300 * (top / 300) ** (u ** 1.6)
    swish = tv_band(noise(seconds), centre, 1.8)
    tone_ = np.zeros(len(t))
    for s in pitched:
        f = float(hz(s)) * 2 ** (octaves * u ** 2)
        tone_ += bl_osc(f, None, "saw", phase=R.uniform()) + bl_osc(f * 1.006, None, "saw", phase=R.uniform())
    tone_ = tv_lowpass(tone_ / (2 * len(pitched)), 600 + 4000 * u ** 2, 1.3)
    trem = 0.7 + 0.3 * np.sin(2 * np.pi * np.cumsum(4 + 20 * u ** 2) / SR)
    shape = (u ** 2.2) * np.clip((seconds - t) / 0.004, 0, 1)
    return (swish * 0.9 + tone_ * 0.7 * trem) * shape


def reverse_cymbal(seconds=1.0):
    """A crash played backwards: it swells and stops dead on its last sample."""
    x = crash(seconds + 0.05, 1.0, dark=7000)[: int(SR * seconds)]
    x = x[::-1].copy()
    x[:int(0.02 * SR)] *= np.linspace(0, 1, int(0.02 * SR))
    x[-int(0.003 * SR):] *= np.linspace(1, 0, int(0.003 * SR))
    return x


def reverse_swell(x, seconds):
    """Reverse a (reverberated) sound so it swells into its own end."""
    n = int(SR * seconds)
    y = x[:n][::-1].copy()
    k = int(0.05 * SR)
    y[:k] *= np.linspace(0, 1, k)[:, None] if y.ndim == 2 else np.linspace(0, 1, k)
    y[-int(0.003 * SR):] *= np.linspace(1, 0, int(0.003 * SR))[:, None] if y.ndim == 2 else np.linspace(1, 0, int(0.003 * SR))
    return y


def whoosh(seconds=0.6, peak=0.5, lo=400.0, hi=3500.0):
    """Air rushing past (n, 2): a band of noise sweeping up to the peak and
    back down, panning across."""
    t = taxis(seconds)
    u = t / seconds
    k = np.where(u < peak, u / peak, 1 - (u - peak) / (1 - peak))
    centre = lo * (hi / lo) ** k
    x = tv_band(noise(seconds), centre, 1.5) * k ** 2.2
    pan = np.clip(u, 0, 1)
    return np.stack([x * np.cos(pan * np.pi / 2), x * np.sin(pan * np.pi / 2)], axis=1) * 1.4


def drone(semis, seconds):
    """A dark bowed-metal drone: root and fifth, slowly beating, breathing."""
    t = taxis(seconds)
    x = np.zeros(len(t))
    for s, g in ((semis, 1.0), (semis + 7, 0.5), (semis + 12, 0.35)):
        for d in (-0.07, 0.0, 0.08):
            x += bl_osc(float(hz(s + d)), seconds, "saw", phase=R.uniform()) * g
    cut = 260 + 200 * (0.5 + 0.5 * smooth_noise(seconds, 0.4))
    x = tv_lowpass(x / 6, cut, 1.2)
    sub = np.sin(2 * np.pi * float(hz(semis)) * t) * 0.6
    return x + sub


def wind(seconds):
    """Dusk wind off the sea (n, 2): noise in a wandering band, gusting."""
    out = []
    for _ in range(2):
        centre = 500 * 2 ** (1.2 * smooth_noise(seconds, 0.5))
        gust = 0.55 + 0.45 * smooth_noise(seconds, 0.35)
        out.append(tv_band(noise(seconds), centre, 1.3) * gust)
    return np.stack(out, axis=1)


def heartbeat(vel=1.0):
    """A deep double pulse: a sub thump with an audible upper knock."""
    d = 0.7
    t = taxis(d)
    out = np.zeros(len(t))
    for at, g in ((0.0, 1.0), (0.22, 0.65)):
        u = np.clip(t - at, 0, None)
        f = 46 + 30 * np.exp(-u / 0.03)
        beat = np.sin(2 * np.pi * np.cumsum(f * (t >= at)) / SR) * np.exp(-u / 0.12) * (t >= at)
        knock = filt(noise(d), low=500, high=120) * np.exp(-u / 0.02) * (t >= at) * 0.5
        out += (beat + knock) * g * np.clip(u / 0.004, 0, 1)
    return out * vel


def tick(vel=1.0, pitch=2800.0):
    """A clock/mechanism tick."""
    d = 0.06
    t = taxis(d)
    x = band(noise(d), pitch, pitch * 0.3) * np.exp(-t / 0.004)
    x += np.sin(2 * np.pi * pitch * 0.5 * t) * np.exp(-t / 0.01) * 0.3
    return x * vel


# ---------------------------------------------------------------------------
# Studio
# ---------------------------------------------------------------------------

def hall_ir(seconds=3.2, predelay=0.02, seed=5, rt=((250, 1.15), (1200, 1.0), (4000, 0.65), (20000, 0.35)),
            early=12, width=1.0, shared=0.35):
    """A stereo hall impulse response: sparse early reflections, then a
    dense noise tail whose decay time depends on frequency (`rt`: band top
    Hz, RT60 as a fraction of `seconds`), so the highs die first and the
    tail darkens like a real room. The two sides are mostly independent
    noise (wide) with a `shared` part, so the tail stays mono-compatible."""
    r = np.random.default_rng(seed)
    n = int(SR * seconds)
    t = np.arange(n) / SR
    f = np.fft.rfftfreq(n, 1.0 / SR)
    common = r.standard_normal(n)
    sides = []
    for _ in range(2):
        w = r.standard_normal(n) * math.sqrt(1 - shared) + common * math.sqrt(shared)
        spec = np.fft.rfft(w)
        tail = np.zeros(n)
        lo_edge = 0.0
        for top, frac in rt:
            mask = ((f >= lo_edge) & (f < top)).astype(float)
            part = np.fft.irfft(spec * mask, n)
            tail += part * np.exp(-6.9 * t / (seconds * frac))
            lo_edge = top
        tail *= 1.0 - np.exp(-t / 0.025)                  # the tail builds in
        er = np.zeros(n)
        for _k in range(early):
            i = int(r.uniform(0.004, 0.075) * SR)
            er[i] += r.uniform(-1, 1) * (1.0 - i / (0.09 * SR)) * 3.0
        er = filt(er, low=6000)
        ir = (tail + er * width) * 1.0
        ir = np.concatenate([np.zeros(int(predelay * SR)), ir])
        sides.append(ir / np.sqrt(np.sum(ir * ir)))
    return np.stack(sides, axis=1)


def convolve(x, ir):
    """Linear FFT convolution of (n, 2) with a stereo IR, cut to n samples."""
    n = len(x)
    size = 1 << int(math.ceil(math.log2(n + len(ir))))
    out = np.empty((n, 2))
    for c in range(2):
        y = np.fft.irfft(np.fft.rfft(x[:, c], size) * np.fft.rfft(ir[:, c], size), size)
        out[:, c] = y[:n]
    return out


def compress(x, thresh_db=-18.0, ratio=3.0, attack=0.005, release=0.15, knee=6.0, block=32, key=None):
    """Feed-forward RMS compressor (stereo-linked, soft knee); `key` lets
    another signal drive it (sidechain). Returns x with the gain applied."""
    src = x if key is None else key
    n = len(x)
    nb = -(-n // block)
    p = np.pad((src * src).mean(axis=1) if src.ndim == 2 else src * src, (0, nb * block - n)).reshape(nb, block).mean(axis=1)
    lvl = 10 * np.log10(p + 1e-12)
    over = lvl - thresh_db
    gr = np.where(over <= -knee / 2, 0.0, np.where(over >= knee / 2, over * (1 - 1 / ratio),
                                                   (1 - 1 / ratio) * (over + knee / 2) ** 2 / (2 * knee)))
    ca, cr = math.exp(-block / (attack * SR)), math.exp(-block / (release * SR))
    g, cur = np.empty(nb), 0.0
    for i, v in enumerate(gr):
        cur = v + (cur - v) * (ca if v > cur else cr)
        g[i] = cur
    per = np.interp(np.arange(n), (np.arange(nb) + 0.5) * block, g)
    gain = 10 ** (-per / 20)
    return x * (gain[:, None] if x.ndim == 2 else gain)


def duck(n, hits, depth, pre=0.03, release=0.45, shape=2.0):
    """Sidechain gain curve: dips by `depth` (reached 0.6 x `pre` before each
    hit and held to it) and swells back over `release` s."""
    t = np.arange(n) / SR
    worst = np.zeros(n)
    for at, d in hits:
        a, b = max(0, int(SR * (at - pre))), min(n, int(SR * (at + release)))
        u = t[a:b] - at
        v = np.where(u < 0, d * depth * np.clip((1 + u / pre) / 0.4, 0, 1) ** 1.5, d * depth * np.clip(1 - u / release, 0, 1) ** shape)
        worst[a:b] = np.maximum(worst[a:b], v)
    return 1.0 - worst


def gate(n, closed, ramp=0.004, reopen=0.001):
    """1, except 0 over each (start, end) span: it closes over `ramp` s before
    the start and reopens over `reopen` s from the end (no clicks, and nothing
    leaks ahead of the hit that ends the silence)."""
    t = np.arange(n) / SR
    g = np.ones(n)
    for a, b in closed:
        g = np.minimum(g, np.clip((a - t) / ramp, 0, 1) + np.clip((t - b) / reopen, 0, 1))
    return np.clip(g, 0, 1)


def mono_lows(x, fc=140.0):
    """Mid/side: the side channel high-passed (lows in mono)."""
    mid, side = (x[:, 0] + x[:, 1]) * 0.5, (x[:, 0] - x[:, 1]) * 0.5
    side = filt(side, high=fc)
    return np.stack([mid + side, mid - side], axis=1)


def widen(x, amount=1.2):
    mid, side = (x[:, 0] + x[:, 1]) * 0.5, (x[:, 0] - x[:, 1]) * 0.5
    return np.stack([mid + side * amount, mid - side * amount], axis=1)
