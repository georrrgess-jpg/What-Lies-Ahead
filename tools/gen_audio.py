"""Synthesises every sound in the game from scratch (no third-party audio).

    audio/sfx/*.wav      one-shots: weapons, zombies, arcade cues, UI
    audio/music/*.ogg    looping pier ambience and the boardwalk music loop

    python tools/gen_audio.py        (needs numpy; ffmpeg with libvorbis for the .ogg loops)

Sound names are referenced by StringName from data and scripts (for example a
weapon's `fire_sound`), so add a new function here and use its name there.
"""
import math
import os
import subprocess
import sys
import wave

import numpy as np

SR = 44100
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
SFX = os.path.join(ROOT, "sfx")
MUSIC = os.path.join(ROOT, "music")
rng = np.random.default_rng(42)


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

def t_axis(seconds):
    return np.arange(int(SR * seconds)) / SR


def sweep(f0, f1, seconds, shape="sine", curve=1.0):
    """Oscillator whose frequency glides from f0 to f1."""
    t = t_axis(seconds)
    k = (t / max(seconds, 1e-9)) ** curve
    freq = f0 + (f1 - f0) * k
    phase = 2 * np.pi * np.cumsum(freq) / SR
    return osc(phase, shape)


def tone(freq, seconds, shape="sine", vibrato=0.0, vib_rate=5.0):
    t = t_axis(seconds)
    f = freq * (1.0 + vibrato * np.sin(2 * np.pi * vib_rate * t))
    return osc(2 * np.pi * np.cumsum(f) / SR, shape)


def osc(phase, shape):
    if shape == "sine":
        return np.sin(phase)
    if shape == "square":
        return np.tanh(np.sin(phase) * 6.0)
    if shape == "saw":
        return 2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0
    if shape == "tri":
        return 2.0 * np.abs(2.0 * ((phase / (2 * np.pi)) % 1.0) - 1.0) - 1.0
    raise ValueError(shape)


def noise(seconds):
    return rng.uniform(-1, 1, int(SR * seconds))


def env(seconds, attack=0.005, decay=None, sustain=0.0, release=0.0, power=2.0):
    """Percussive envelope: quick attack, exponential-ish decay to `sustain`."""
    n = int(SR * seconds)
    t = np.arange(n) / SR
    decay = seconds if decay is None else decay
    e = np.clip(1.0 - t / max(decay, 1e-6), 0.0, 1.0) ** power * (1.0 - sustain) + sustain
    e *= np.clip(t / max(attack, 1e-6), 0.0, 1.0)
    if release > 0:
        e *= np.clip((seconds - t) / release, 0.0, 1.0)
    return e


def fade(x, fade_in=0.003, fade_out=0.01):
    n = len(x)
    a, b = int(SR * fade_in), int(SR * fade_out)
    y = x.copy()
    if a > 0:
        y[:a] *= np.linspace(0, 1, a)
    if b > 0:
        y[-b:] *= np.linspace(1, 0, b)
    return y


def filt(x, low=None, high=None, slope=2.0):
    """FFT filter: smooth low-pass at `low` Hz and/or high-pass at `high` Hz."""
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    gain = np.ones_like(f)
    if low:
        gain *= 1.0 / (1.0 + (f / low) ** (2 * slope))
    if high:
        gain *= 1.0 - 1.0 / (1.0 + (f / high) ** (2 * slope))
    return np.fft.irfft(spec * gain, len(x))


def band(x, centre, width):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    return np.fft.irfft(spec * np.exp(-0.5 * ((f - centre) / width) ** 2), len(x))


def place(buf, x, at, gain=1.0):
    """Mix x into buf starting at `at` seconds."""
    i = int(SR * at)
    n = min(len(x), len(buf) - i)
    if n > 0:
        buf[i:i + n] += x[:n] * gain
    return buf


def silence(seconds):
    return np.zeros(int(SR * seconds))


def norm(x, peak=0.85):
    m = np.max(np.abs(x))
    return x if m < 1e-9 else x * (peak / m)


def crush(x, drive=2.0):
    return np.tanh(x * drive) / np.tanh(drive)


def write_wav(name, x, peak=0.85):
    x = norm(fade(np.asarray(x, dtype=np.float64)), peak)
    path = os.path.join(SFX, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    return path


def write_ogg(name, stereo, peak=0.8, quality=5):
    """stereo: array shaped (n, 2). Encoded with ffmpeg/libvorbis."""
    stereo = stereo * (peak / max(1e-9, np.max(np.abs(stereo))))
    tmp = os.path.join(MUSIC, name + ".tmp.wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((stereo * 32767).astype("<i2").tobytes())
    out = os.path.join(MUSIC, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), out], check=True)
    os.remove(tmp)
    return out


def note(semitones_from_a4):
    return 440.0 * 2 ** (semitones_from_a4 / 12.0)


def blip(freq, seconds, shape="square", decay=None, gain=1.0):
    return tone(freq, seconds, shape) * env(seconds, 0.003, decay or seconds, power=1.6) * gain


def click(seconds=0.02, tone_hz=2500, gain=1.0):
    return (band(noise(seconds), tone_hz, tone_hz * 0.5) * 4 + noise(seconds) * 0.3) * env(seconds, 0.0005, power=3.0) * gain


def clunk(pitch=140, seconds=0.12, gain=1.0):
    body = sweep(pitch * 1.6, pitch * 0.7, seconds) * env(seconds, 0.001, power=2.5)
    place(body, click(0.03, 1800), 0.0, 0.7)
    return body * gain


# ---------------------------------------------------------------------------
# Weapons
# ---------------------------------------------------------------------------

def _laser_layer(f0, f1, d, curve, shape="saw"):
    """Downward-zapping energy layer with a little FM wobble (the 'pew')."""
    t = t_axis(d)
    k = (t / d) ** curve
    freq = f0 + (f1 - f0) * k
    mod = 1.0 + 0.08 * np.sin(2 * np.pi * freq * 0.5 * t / max(1.0, f1 / 400))
    return osc(2 * np.pi * np.cumsum(freq * mod) / SR, shape)


def _sub_thump(f0, f1, d, decay):
    return sweep(f0, f1, d, "sine", 0.35) * env(d, 0.0008, decay, power=2.0)


def _shimmer(d, decay, centre=6500):
    """Bright crackle tail: the energy cell discharging."""
    n = band(noise(d), centre, centre * 0.35) * 3.0
    sparkle = (rng.uniform(0, 1, len(n)) > 0.985).astype(float) * rng.uniform(-1, 1, len(n))
    return (n + filt(sparkle, low=9000) * 2.0) * env(d, 0.002, decay, power=2.5)


def pistol_fire():
    """Pulse Pistol: crisp snap, mid 'pew', tight sub punch and a sparkly tail."""
    d = 0.32
    snap = filt(noise(d), high=3000) * env(d, 0.0003, 0.02, power=2.0) * 1.1
    pew = _laser_layer(2400, 380, d, 0.45) * env(d, 0.0008, 0.16, power=2.0) * 0.5
    body = sweep(620, 150, d, "square", 0.5) * env(d, 0.0008, 0.09, power=2.2) * 0.4
    sub = _sub_thump(170, 48, d, 0.12) * 1.1
    tail = _shimmer(d, 0.28) * 0.25
    return crush(filt(snap + pew + body + sub + tail, low=12000), 1.3)


def carbine_fire():
    """Ion Carbine: fast, bright ion crack with a short electric buzz."""
    d = 0.16
    snap = filt(noise(d), high=4200) * env(d, 0.0003, 0.012, power=2.0)
    pew = _laser_layer(3400, 900, d, 0.4) * env(d, 0.0006, 0.08, power=1.8) * 0.45
    buzz = tone(110, d, "square") * env(d, 0.001, 0.07, power=1.5) * 0.18
    sub = _sub_thump(210, 70, d, 0.06) * 0.8
    tail = _shimmer(d, 0.12, 7500) * 0.2
    return crush(filt(snap + pew + buzz + sub + tail, low=13000), 1.25)


def scatter_fire():
    """Scatter Blaster: huge plasma boom, rolling sub and a fizzing cooldown."""
    d = 0.75
    crack = filt(noise(d), high=1800) * env(d, 0.0005, 0.05, power=1.6) * 1.2
    boom = _sub_thump(190, 30, d, 0.45) * 1.5
    blast = filt(noise(d), low=2600) * env(d, 0.001, 0.26, power=2.2) * 0.9
    zap = _laser_layer(1300, 140, d, 0.35, "square") * env(d, 0.001, 0.14, power=2.0) * 0.35
    fizz = _shimmer(d, 0.6, 5200) * 0.35
    return crush(boom + crack + blast + zap + fizz, 1.7)


def charge(seconds, f0=300, f1=1400, gain=1.0):
    return sweep(f0, f1, seconds, "sine", 1.6) * env(seconds, 0.02, seconds * 1.4, power=0.6, release=0.03) * gain


def pistol_reload():
    out = silence(1.25)
    place(out, clunk(190, 0.1), 0.08, 0.8)                                   # cell drops
    place(out, band(noise(0.16), 2200, 900) * env(0.16, 0.03, power=1.0), 0.3, 0.5)   # hand moves
    place(out, clunk(230, 0.12), 0.68, 1.0)                                  # cell seats
    place(out, click(0.03, 3200), 0.95, 0.9)                                 # slide
    place(out, charge(0.22, 500, 1500), 1.0, 0.45)
    return out


def carbine_reload():
    out = silence(1.75)
    place(out, clunk(160, 0.12), 0.25, 0.8)
    place(out, band(noise(0.3), 1500, 700) * env(0.3, 0.08, power=1.0), 0.42, 0.55)   # cell slides out
    place(out, band(noise(0.26), 2000, 800) * env(0.26, 0.1, power=1.0), 0.86, 0.5)   # new cell slides in
    place(out, clunk(210, 0.14), 1.1, 1.0)
    place(out, charge(0.42, 350, 1700), 1.25, 0.5)
    return out


def scatter_reload():
    out = silence(2.3)
    place(out, clunk(110, 0.18), 0.2, 1.0)                                   # break open
    place(out, click(0.03, 1500), 0.32, 0.6)
    place(out, clunk(150, 0.16), 1.0, 0.9)                                   # drum seats
    place(out, clunk(100, 0.2), 1.38, 1.0)                                   # close
    for at in (1.72, 2.02):                                                  # two pumps
        place(out, band(noise(0.09), 1200, 600) * env(0.09, 0.01, power=1.2), at, 0.7)
        place(out, clunk(170, 0.1), at + 0.09, 0.9)
    return out


def empty_click():
    out = silence(0.22)
    place(out, click(0.025, 3000), 0.0, 1.0)
    place(out, sweep(520, 300, 0.14, "square") * env(0.14, 0.002, power=1.5), 0.03, 0.3)
    return out


# ---------------------------------------------------------------------------
# Zombies (non-gory: thwps, pops and cartoon groans)
# ---------------------------------------------------------------------------

def hit_body():
    d = 0.14
    return sweep(380, 130, d, "sine", 0.6) * env(d, 0.001, 0.1, power=2.0) + filt(noise(d), low=1800) * env(d, 0.001, 0.05, power=2.0) * 0.6


def hit_head():
    d = 0.2
    ding = tone(1320, d, "sine") * env(d, 0.001, 0.18, power=2.0) + tone(1980, d, "sine") * env(d, 0.001, 0.1, power=2.0) * 0.5
    body = hit_body()
    body = np.pad(body, (0, max(0, int(SR * d) - len(body))))[: int(SR * d)]
    return ding * 0.7 + body * 0.7


def zombie_pop():
    d = 0.42
    pop = sweep(240, 900, 0.07, "sine", 2.0) * env(0.07, 0.001, power=1.0)
    out = silence(d)
    place(out, pop, 0.0, 1.0)
    place(out, filt(noise(0.05), high=1500) * env(0.05, 0.0005, power=2.0), 0.0, 0.5)
    for i, n in enumerate((12, 16, 19, 24)):
        place(out, blip(note(n), 0.16, "sine", 0.14), 0.05 + i * 0.045, 0.32)
    return out


def groan(base, seconds, glide=-0.25, formants=((520, 120), (1100, 180)), rasp=0.25, wobble=0.04):
    """A cartoon vocal: sawtooth voice through two formant bands."""
    t = t_axis(seconds)
    f = base * (1.0 + glide * (t / seconds)) * (1.0 + wobble * np.sin(2 * np.pi * 5.5 * t) + 0.02 * np.sin(2 * np.pi * 23 * t))
    voice = osc(2 * np.pi * np.cumsum(f) / SR, "saw")
    voice = voice * (1.0 - rasp) + voice * noise(seconds) * rasp * 1.5
    out = sum(band(voice, c, w) for c, w in formants) * 3.0 + filt(voice, low=300) * 0.6
    return out * env(seconds, 0.08, seconds * 1.2, power=0.8, release=seconds * 0.35)


def zombie_groan_1():
    return groan(92, 1.1, glide=-0.28)


def zombie_groan_2():
    return groan(78, 1.3, glide=0.12, formants=((420, 110), (900, 160)))


def zombie_groan_3():
    return groan(105, 0.8, glide=-0.4, formants=((600, 140), (1250, 200)), wobble=0.07)


def runner_screech_1():
    return groan(310, 0.55, glide=0.45, formants=((900, 200), (2100, 350)), rasp=0.5, wobble=0.09)


def runner_screech_2():
    return groan(380, 0.45, glide=-0.3, formants=((1100, 220), (2500, 400)), rasp=0.55, wobble=0.12)


def zombie_windup():
    return groan(120, 0.5, glide=0.9, formants=((500, 130), (1300, 220)), rasp=0.4)


def zombie_swipe():
    d = 0.28
    n = noise(d)
    t = t_axis(d)
    # Whoosh: band-passed noise whose centre sweeps upward then drops.
    a = band(n, 700, 300) * np.clip(1 - t / 0.14, 0, 1)
    b = band(n, 1600, 600) * np.clip(1 - np.abs(t - 0.12) / 0.12, 0, 1)
    c = band(n, 900, 400) * np.clip((t - 0.1) / 0.18, 0, 1) * np.clip(1 - (t - 0.1) / 0.18, 0, 1) * 2
    return (a + b * 1.3 + c) * env(d, 0.02, d * 1.5, power=0.7, release=0.08)


def player_hurt():
    d = 0.3
    thud = sweep(160, 55, d, "sine", 0.5) * env(d, 0.001, 0.2, power=2.0)
    buzz = sweep(330, 180, d, "square", 0.6) * env(d, 0.002, 0.16, power=1.6) * 0.35
    return thud + buzz + filt(noise(d), low=900) * env(d, 0.001, 0.06, power=2.0) * 0.5


# ---------------------------------------------------------------------------
# Arcade cues and UI
# ---------------------------------------------------------------------------

def jingle(notes, step, length, shape="square", gain=1.0, tail=0.25):
    out = silence(step * len(notes) + tail)
    for i, n in enumerate(notes):
        place(out, blip(note(n), length, shape), i * step, gain)
        place(out, blip(note(n + 12), length * 0.7, "sine"), i * step, gain * 0.3)
    return out


def wave_start():
    return jingle([-5, 0, 4, 7], 0.085, 0.2) * 0.9


def final_wave():
    out = silence(1.6)
    for i in range(3):
        place(out, sweep(880, 520, 0.26, "square", 0.8) * env(0.26, 0.004, power=0.8, release=0.05), i * 0.3, 0.5)
    place(out, jingle([-12, -9, -5, 0], 0.11, 0.3, "saw"), 0.9, 0.7)
    place(out, sweep(110, 40, 0.6, "sine") * env(0.6, 0.002, power=1.5), 0.9, 0.9)
    return out


def wave_clear():
    return jingle([0, 4, 7, 12, 16], 0.075, 0.24, "square") * 0.85


def purchase():
    out = silence(0.5)
    place(out, blip(note(19), 0.09, "square"), 0.0, 0.7)
    place(out, blip(note(24), 0.3, "square", 0.28), 0.08, 0.7)
    place(out, blip(note(31), 0.3, "sine", 0.28), 0.08, 0.35)
    place(out, filt(noise(0.2), high=6000) * env(0.2, 0.001, power=2.0), 0.08, 0.2)
    return out


def deny():
    out = silence(0.34)
    for at in (0.0, 0.15):
        place(out, tone(155, 0.13, "square") * env(0.13, 0.003, power=0.6, release=0.03), at, 0.7)
    return filt(out, low=2500)


def swap():
    out = silence(0.3)
    place(out, click(0.03, 2600), 0.0, 0.9)
    place(out, band(noise(0.2), 1800, 800) * env(0.2, 0.04, power=1.2), 0.03, 0.5)
    place(out, clunk(200, 0.1), 0.17, 0.8)
    return out


def unlock():
    out = silence(1.1)
    for i, n in enumerate((7, 12, 16, 19, 24, 28)):
        place(out, blip(note(n), 0.36, "sine", 0.32), i * 0.07, 0.6)
        place(out, blip(note(n), 0.14, "square", 0.12), i * 0.07, 0.22)
    place(out, filt(noise(0.7), high=7000) * env(0.7, 0.05, power=1.5), 0.3, 0.12)
    return out


def portal_open():
    d = 2.2
    rise = sweep(90, 620, d, "saw", 1.8) * env(d, 0.3, d * 2, power=0.5, release=0.6) * 0.35
    shimmer = sum(tone(note(n), d, "sine", 0.004, 6.0) for n in (0, 7, 12, 16)) * env(d, 0.6, d * 2, power=0.5, release=0.9) * 0.22
    whoosh = band(noise(d), 1400, 900) * env(d, 0.8, d * 2, power=0.5, release=0.7) * 0.5
    out = filt(rise, low=3500) + shimmer + whoosh
    place(out, jingle([0, 7, 12, 19], 0.1, 0.4, "square"), 1.3, 0.5)
    return out


def portal_hum():
    """Two-second seamless loop."""
    d = 2.0
    t = t_axis(d)
    hum = sum(np.sin(2 * np.pi * f * t) * g for f, g in ((110, 1.0), (165, 0.5), (220, 0.35), (330, 0.2)))
    hum *= 0.75 + 0.25 * np.sin(2 * np.pi * 3.0 * t)
    shimmer = np.sin(2 * np.pi * 880 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.5 * t)) * 0.12
    return hum + shimmer


def level_clear():
    out = silence(2.0)
    melody = [(0, 0.0), (4, 0.14), (7, 0.28), (12, 0.42), (7, 0.62), (12, 0.76), (16, 0.9)]
    for n, at in melody:
        place(out, blip(note(n), 0.3, "square", 0.26), at, 0.55)
        place(out, blip(note(n - 12), 0.3, "tri", 0.26), at, 0.5)
    for n in (0, 4, 7, 12):
        place(out, tone(note(n), 0.9, "square") * env(0.9, 0.01, 0.9, power=1.2), 1.05, 0.25)
    return out


def defeat():
    out = silence(1.7)
    for i, n in enumerate((0, -1, -3, -7)):
        place(out, tone(note(n - 12), 0.42, "saw", 0.01) * env(0.42, 0.01, 0.4, power=1.0), i * 0.3, 0.5)
    place(out, sweep(160, 45, 0.7, "sine") * env(0.7, 0.01, power=1.2), 1.0, 0.8)
    return filt(out, low=3000)


def ui_hover():
    return blip(note(19), 0.04, "sine", 0.035)


def ui_click():
    out = silence(0.12)
    place(out, blip(note(12), 0.05, "square"), 0.0, 0.8)
    place(out, blip(note(19), 0.08, "square"), 0.035, 0.8)
    return out


def hitmarker():
    """Tight 2D tick confirming a hit."""
    out = silence(0.1)
    place(out, blip(note(31), 0.05, "square", 0.035), 0.0, 0.55)
    place(out, click(0.015, 5600), 0.0, 0.55)
    place(out, sweep(260, 140, 0.05, "sine") * env(0.05, 0.001, power=2.0), 0.0, 0.5)
    return out


def kill_confirm():
    """Punchy arcade kill: thump, glassy 'shatter' and a bright two-note chime.
    The game raises its pitch with the kill combo."""
    out = silence(0.55)
    place(out, _sub_thump(160, 55, 0.18, 0.12), 0.0, 1.1)
    place(out, sweep(300, 1400, 0.05, "sine", 2.0) * env(0.05, 0.001, power=1.0), 0.0, 0.6)
    glass = band(noise(0.3), 5200, 2400) * env(0.3, 0.001, 0.22, power=2.5)
    for k in range(6):
        place(out, blip(rng.uniform(2800, 5200), 0.07, "sine", 0.05) * 0.4, 0.01 + k * 0.022, 0.4)
    place(out, glass, 0.0, 0.5)
    place(out, blip(note(28), 0.22, "sine", 0.2), 0.04, 0.6)
    place(out, blip(note(35), 0.3, "sine", 0.28), 0.1, 0.5)
    place(out, blip(note(35), 0.1, "square", 0.08), 0.1, 0.14)
    return crush(out, 1.2)


def headshot_ping():
    """Bright metallic 'ting' with a crunchy transient: unmistakably a headshot."""
    d = 0.5
    out = silence(d)
    partials = [(2350, 1.0, 0.35), (3720, 0.6, 0.22), (5310, 0.4, 0.15), (6980, 0.25, 0.1)]
    for f, g, dec in partials:
        place(out, tone(f, d, "sine") * env(d, 0.0005, dec, power=1.6) * g, 0.0, 0.5)
    place(out, filt(noise(0.03), high=2500) * env(0.03, 0.0003, power=2.0), 0.0, 0.9)
    place(out, _sub_thump(320, 120, 0.08, 0.06), 0.0, 0.6)
    return out


def combo_up():
    """Short rising blip played on combo milestones."""
    out = silence(0.25)
    for i, n in enumerate((24, 28, 31)):
        place(out, blip(note(n), 0.08, "square", 0.07), i * 0.04, 0.45)
    return out


def jump():
    d = 0.18
    step = _step(120, 200)
    step = np.pad(step, (0, max(0, int(SR * d) - len(step))))[: int(SR * d)]
    return band(noise(d), 900, 500) * env(d, 0.005, 0.12, power=1.5) * 1.6 + step * 0.5


def land():
    d = 0.3
    step = _step(90, 0)
    return _sub_thump(130, 40, d, 0.18) * 1.2 + np.pad(step, (0, int(SR * d) - len(step))) * 0.9


def slide():
    d = 0.7
    scrape = band(noise(d), 1800, 1200) * env(d, 0.02, 0.6, power=0.9) * 1.6
    whoosh = band(noise(d), 600, 300) * env(d, 0.01, 0.4, power=1.2)
    return scrape + whoosh


def reload_vent():
    d = 0.6
    hiss = filt(noise(d), high=2500) * env(d, 0.01, 0.55, power=1.2)
    pop = sweep(900, 300, 0.05, "sine") * env(0.05, 0.001, power=1.5)
    out = hiss * 0.8
    place(out, pop, 0.0, 0.6)
    return out


def reload_materialize():
    """Digital 'print' shimmer rising into a bright lock-in chime."""
    d = 0.5
    sweep_up = sweep(400, 2400, d * 0.7, "saw", 1.5) * env(d * 0.7, 0.02, d, power=0.6) * 0.25
    out = silence(d)
    place(out, filt(sweep_up, low=5000), 0.0, 1.0)
    for i in range(10):
        place(out, blip(rng.uniform(1800, 4200), 0.03, "square", 0.025) * 0.3, i * 0.03, 0.5)
    place(out, blip(note(31), 0.18, "sine", 0.16), 0.33, 0.7)
    place(out, blip(note(38), 0.18, "sine", 0.16), 0.36, 0.4)
    return out


def reload_clunk():
    out = silence(0.3)
    place(out, clunk(140, 0.16), 0.0, 1.0)
    place(out, click(0.02, 3600), 0.0, 0.6)
    place(out, charge(0.18, 600, 1600), 0.05, 0.4)
    return out


def reload_spin():
    d = 0.5
    t = t_axis(d)
    rate = 18 + 40 * (t / d)
    ticks = (np.sin(2 * np.pi * np.cumsum(rate) / SR) > 0.95).astype(float)
    return filt(ticks, low=6000) * env(d, 0.01, d, power=0.6) * 0.8 + sweep(200, 900, d, "sine", 1.5) * env(d, 0.02, d, power=0.8) * 0.2


def _step(seed_hz, bright):
    d = 0.14
    thud = sweep(seed_hz * 1.4, seed_hz * 0.7, d, "sine", 0.5) * env(d, 0.002, 0.09, power=2.2)
    knock = band(noise(d), 900 + bright, 400) * env(d, 0.001, 0.05, power=2.0) * 2.5
    creak = band(noise(d), 2400 + bright, 300) * env(d, 0.01, 0.12, power=1.5) * 0.4
    return thud + knock + creak


def footstep_1():
    return _step(110, 0)


def footstep_2():
    return _step(96, 250)


def heartbeat():
    out = silence(0.42)
    for at, g in ((0.0, 1.0), (0.16, 0.7)):
        place(out, sweep(70, 42, 0.12, "sine", 0.6) * env(0.12, 0.004, power=1.8), at, g)
    return filt(out, low=400)


def bruiser_roar_1():
    return groan(62, 1.4, glide=-0.15, formants=((380, 110), (780, 150)), rasp=0.45, wobble=0.05)


def bruiser_roar_2():
    return groan(70, 1.1, glide=0.2, formants=((420, 120), (850, 170)), rasp=0.5, wobble=0.06)


def bruiser_slam():
    d = 0.6
    out = zombie_swipe()
    out = np.pad(out, (0, int(SR * d) - len(out)))
    place(out, sweep(120, 34, 0.4, "sine", 0.4) * env(0.4, 0.001, 0.3, power=1.8), 0.16, 1.4)
    place(out, filt(noise(0.25), low=1200) * env(0.25, 0.001, 0.12, power=2.0), 0.16, 0.9)
    return crush(out, 1.4)


def _variant(fn, pitch, seed):
    """Re-render a sound with a slightly different pitch and noise seed."""
    global rng
    old = rng
    rng = np.random.default_rng(seed)
    x = fn()
    rng = old
    idx = np.arange(0, len(x) - 1, pitch)
    return np.interp(idx, np.arange(len(x)), x)


def intro_boot():
    """Startup: a CRT-style power-on blip with a rising whine."""
    out = silence(0.6)
    place(out, click(0.02, 3000), 0.0, 0.8)
    place(out, sweep(60, 2400, 0.45, "sine", 2.5) * env(0.45, 0.01, 0.6, power=0.7) * 0.25, 0.02, 1.0)
    place(out, filt(noise(0.3), high=5000) * env(0.3, 0.005, 0.25, power=1.5) * 0.3, 0.0, 1.0)
    return out


def intro_swell():
    """A big synth swell under the sunrise, resolving into a chord."""
    d = 2.2
    out = silence(d)
    for n, g in ((-24, 0.5), (-12, 0.35), (-5, 0.25), (0, 0.22), (4, 0.18)):
        x = tone(note(n), d, "saw", 0.004, 5.0) * env(d, 1.2, d * 1.6, power=0.5, release=0.4)
        place(out, filt(x, low=900 + 300 * (n + 24) / 28), 0.0, g)
    place(out, sweep(200, 3000, 1.6, "sine", 2.0) * env(1.6, 0.8, 2.0, power=0.5) * 0.08, 0.0, 1.0)
    return out


def title_hit():
    """The title lands: deep boom, bright stab and a shimmering tail."""
    d = 1.6
    out = silence(d)
    place(out, sweep(110, 32, 0.9, "sine", 0.4) * env(0.9, 0.002, 0.7, power=1.6), 0.0, 1.3)
    place(out, filt(noise(0.4), low=2500) * env(0.4, 0.001, 0.25, power=2.0), 0.0, 0.6)
    for n in (0, 7, 12, 16, 19):
        place(out, tone(note(n), 1.2, "square") * env(1.2, 0.003, 1.0, power=1.6) * 0.12, 0.0, 1.0)
    place(out, _shimmer(1.4, 1.2, 6000) * 0.3, 0.05, 1.0)
    return crush(out, 1.2)


def title_tick():
    return blip(note(28), 0.06, "square", 0.05) * 0.6 + np.pad(click(0.02, 4200), (0, int(SR * 0.04)))


def ui_whoosh():
    d = 0.45
    t = t_axis(d)
    n = noise(d)
    centre = 400 + 3000 * (t / d)
    out = np.zeros_like(n)
    # Swept band-pass approximated by blending three bands.
    for c, w in ((600, 300), (1500, 700), (3200, 1400)):
        weight = np.exp(-((centre - c) / (w * 1.5)) ** 2)
        out += band(n, c, w) * weight
    return out * env(d, 0.12, d * 1.3, power=0.8, release=0.1) * 2.0


def deploy():
    out = silence(0.9)
    place(out, sweep(150, 900, 0.4, "saw", 1.5) * env(0.4, 0.01, 0.5, power=0.8) * 0.4, 0.0, 1.0)
    place(out, jingle([0, 7, 12], 0.07, 0.25, "square"), 0.25, 0.7)
    place(out, _sub_thump(140, 45, 0.3, 0.2), 0.25, 1.0)
    return out


# ---------------------------------------------------------------------------
# Loops
# ---------------------------------------------------------------------------

def loopable(x, crossfade=1.0):
    """Crossfade the tail into the head so the buffer loops seamlessly."""
    n = int(SR * crossfade)
    head, tail = x[:n], x[-n:]
    ramp = np.linspace(0, 1, n)
    if x.ndim == 2:
        ramp = ramp[:, None]
    mixed = head * ramp + tail * (1 - ramp)
    return np.concatenate([mixed, x[n:-n]])


def pier_ambience():
    """Low-key pier bed: surf, a ride motor and the odd gull."""
    d = 24.0
    t = t_axis(d + 1.0)
    n = len(t)
    surf_l = filt(rng.uniform(-1, 1, n), low=900, high=120)
    surf_r = filt(rng.uniform(-1, 1, n), low=900, high=120)
    swell = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.0 - 1.0)) ** 2.2
    wash = filt(rng.uniform(-1, 1, n), high=2500, low=7000) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 8.0 - 0.2)) ** 6 * 0.35
    motor = sum(np.sin(2 * np.pi * f * t + p) * g for f, g, p in ((55, 1.0, 0), (110, 0.45, 1), (165, 0.2, 2), (82.5, 0.3, 0.5)))
    motor *= (0.8 + 0.2 * np.sin(2 * np.pi * 0.5 * t)) * 0.16
    left = surf_l * swell * 0.8 + wash + motor * 0.9
    right = surf_r * np.roll(swell, int(SR * 0.7)) * 0.8 + np.roll(wash, int(SR * 0.3)) + motor * 0.6
    # Distant gulls.
    for at, pan in ((3.2, 0.25), (11.5, 0.8), (12.1, 0.75), (19.4, 0.4)):
        cry = sweep(2100, 1300, 0.32, "sine", 0.6) * env(0.32, 0.03, 0.4, power=0.8, release=0.1)
        cry = cry * (1 + 0.4 * np.sin(2 * np.pi * 28 * t_axis(0.32))) * 0.11
        for k in range(2):
            place(left, cry, at + k * 0.42, 1 - pan)
            place(right, cry, at + k * 0.42, pan)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


def menu_theme():
    """Menu music: a moody, wide synthwave loop (64 s at 100 BPM), slow
    arpeggios over a pulsing bass, with a brighter B section."""
    bpm = 100.0
    beat = 60.0 / bpm
    bars = 26
    d = bars * 4 * beat
    left, right = silence(d), silence(d)

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    prog = [(-15, (0, 3, 7)), (-19, (0, 4, 7)), (-12, (0, 4, 7)), (-17, (0, 4, 7))]   # F#m D A C# -> roots from A4
    kick = sweep(120, 40, 0.3, "sine", 0.5) * env(0.3, 0.001, power=2.0)
    snare = (filt(noise(0.3), high=1200) * 0.7 + tone(180, 0.3) * 0.2) * env(0.3, 0.001, 0.25, power=1.8)
    for bar in range(bars):
        root, triad = prog[(bar // 2) % 4]
        t0 = bar * 4 * beat
        section_b = 12 <= bar < 24
        drums = bar >= 2
        for b in range(4):
            if drums:
                both(kick, t0 + b * beat, 0.5 if b in (0, 2) else 0.25)
                if b in (1, 3):
                    both(snare, t0 + b * beat, 0.22)
            for h in range(2):
                both(filt(noise(0.04), high=7500) * env(0.04, 0.0005, power=2.5), t0 + (b + h * 0.5) * beat, 0.08 if h else 0.05, 0.65)
        # Pulsing eighth-note bass.
        for e in range(8):
            x = tone(note(root - 12), beat * 0.45, "saw") * env(beat * 0.45, 0.004, beat * 0.5, power=1.2)
            both(filt(x, low=600), t0 + e * beat * 0.5, 0.35)
        # Pad.
        pad = sum(tone(note(root + s2), 4 * beat, "saw", 0.003, 4.0) for s2 in triad)
        both(filt(pad, low=1400 if section_b else 900) * env(4 * beat, 0.6, 8 * beat, power=0.4, release=0.5), t0, 0.06)
        # Arpeggio (sixteenths in B, eighths in A).
        steps = 16 if section_b else 8
        for e in range(steps):
            n = triad[e % 3] + (12 if (e // 3) % 2 else 0)
            x = tone(note(root + 12 + n), beat * 4 / steps * 0.8, "square") * env(beat * 4 / steps * 0.8, 0.003, beat * 0.4, power=1.4)
            both(filt(x, low=3500), t0 + e * beat * 4 / steps, 0.07, 0.25 + 0.5 * (e % 2))
        if section_b and bar % 2 == 0:
            for k, (n, at, ln) in enumerate([(19, 0, 1.5), (16, 1.5, 0.5), (14, 2, 2)]):
                x = tone(note(root + n), ln * beat * 0.95, "saw", 0.006, 5.5) * env(ln * beat * 0.95, 0.02, ln * beat * 1.3, power=0.7, release=0.05)
                both(filt(x, low=2400), t0 + at * beat, 0.09, 0.55)
    stereo = np.stack([left, right], axis=1)
    return loopable(stereo, 1.0)


def boardwalk_loop():
    """64-second arcade loop, 120 BPM, A minor. Section A: Am - F - C - G;
    section B (second half): F - G - Em - Am with a busier lead, so the loop
    does not repeat every half minute."""
    bpm = 120.0
    beat = 60.0 / bpm
    bars = 32
    d = bars * 4 * beat
    left, right = silence(d), silence(d)
    chords = [(-12, (0, 3, 7)), (-16, (0, 4, 7)), (-9, (0, 4, 7)), (-14, (0, 4, 7))]   # root offsets from A4

    def both(x, at, gain, pan=0.5):
        place(left, x, at, gain * (1 - pan) * 2)
        place(right, x, at, gain * pan * 2)

    kick = sweep(150, 45, 0.16, "sine", 0.5) * env(0.16, 0.001, power=2.0)
    hat = filt(noise(0.05), high=7000) * env(0.05, 0.0005, power=2.5)
    snare = (filt(noise(0.14), high=1500) * 0.8 + tone(190, 0.14) * 0.4) * env(0.14, 0.001, power=2.2)
    chords_b = [(-16, (0, 4, 7)), (-14, (0, 4, 7)), (-17, (0, 3, 7)), (-12, (0, 3, 7))]
    for bar in range(bars):
        section_b = bar >= 16
        root, triad = (chords_b if section_b else chords)[(bar // 2) % 4]
        t0 = bar * 4 * beat
        fill = bar % 8 == 7
        for b in range(4):
            both(kick, t0 + b * beat, 0.55)
            if b in (1, 3):
                both(snare, t0 + b * beat, 0.3)
            for h in range(2):
                both(hat, t0 + (b + h * 0.5) * beat, 0.13 if h == 0 else 0.2, 0.62)
            if fill and b >= 2:
                for s in range(4):
                    both(snare, t0 + (b + s * 0.25) * beat, 0.18 + 0.03 * s)
        # Bass: root on the beat with an octave bounce.
        for e in range(8):
            n = root - 12 + (12 if e % 2 else 0)
            both(tone(note(n), beat * 0.48, "tri") * env(beat * 0.48, 0.004, beat * 0.6, power=1.0), t0 + e * beat * 0.5, 0.42)
        # Arpeggio lead.
        pattern = [0, 1, 2, 1, 0, 2, 1, 2] if bar % 4 < 2 else [2, 1, 0, 1, 2, 0, 1, 0]
        for e in range(16):
            step = triad[pattern[e % 8]] + (12 if (e // 8 + bar) % 2 else 0) + (12 if section_b and e % 4 == 3 else 0)
            x = tone(note(root + 12 + step), beat * 0.24, "square") * env(beat * 0.24, 0.003, beat * 0.3, power=1.4)
            both(filt(x, low=4200), t0 + e * beat * 0.25, 0.11, 0.3 + 0.4 * ((e % 4) / 3.0))
        # Soft pad.
        pad = sum(tone(note(root + s), 4 * beat, "sine", 0.003, 5.0) for s in triad) * env(4 * beat, 0.25, 8 * beat, power=0.5, release=0.3)
        both(pad, t0, 0.07)
        # Melody phrase every other pair of bars.
        if bar % 4 in (2, 3):
            if section_b:
                phrase = [(12, 0.0, 0.5), (14, 0.5, 0.5), (15, 1.0, 1.0), (12, 2.0, 0.5), (10, 2.5, 0.5), (7, 3.0, 1.0)] if bar % 4 == 2 \
                    else [(8, 0.0, 1.0), (10, 1.0, 1.0), (7, 2.0, 2.0)]
            else:
                phrase = [(7, 0.0, 1.0), (12, 1.0, 0.5), (10, 1.5, 0.5), (7, 2.0, 1.0), (3, 3.0, 1.0)] if bar % 4 == 2 \
                    else [(5, 0.0, 1.0), (7, 1.0, 1.0), (12, 2.0, 2.0)]
            for semis, at, length in phrase:
                x = tone(note(-12 + semis + 12), length * beat * 0.95, "saw", 0.006, 5.5) * env(length * beat * 0.95, 0.01, length * beat * 1.4, power=0.8, release=0.05)
                both(filt(x, low=2600), t0 + at * beat, 0.1, 0.55)
    return np.stack([left, right], axis=1)


# ---------------------------------------------------------------------------

SFX_SOUNDS = [
    pistol_fire, carbine_fire, scatter_fire, pistol_reload, carbine_reload, scatter_reload, empty_click,
    hit_body, hit_head, zombie_pop, zombie_groan_1, zombie_groan_2, zombie_groan_3, runner_screech_1,
    runner_screech_2, zombie_windup, zombie_swipe, player_hurt, wave_start, final_wave, wave_clear,
    purchase, deny, swap, unlock, portal_open, level_clear, defeat, ui_hover, ui_click,
    hitmarker, kill_confirm, footstep_1, footstep_2, heartbeat, bruiser_roar_1, bruiser_roar_2, bruiser_slam,
    headshot_ping, combo_up, jump, land, slide, reload_vent, reload_materialize, reload_clunk, reload_spin,
    intro_boot, intro_swell, title_hit, title_tick, ui_whoosh, deploy,
]

# Extra takes of the most repeated sounds; the game picks one at random (name_b, name_c).
VARIANTS = [
    (pistol_fire, (0.95, 1.06)), (carbine_fire, (0.94, 1.05)), (scatter_fire, (0.93, 1.07)),
    (hit_body, (0.9, 1.12)), (zombie_pop, (0.92, 1.09)), (footstep_1, (0.9, 1.1)), (footstep_2, (0.88, 1.12)),
    (zombie_groan_1, (0.9, 1.08)), (zombie_groan_2, (0.88, 1.1)), (zombie_groan_3, (0.92, 1.12)),
    (runner_screech_1, (0.9, 1.1)), (runner_screech_2, (0.93, 1.12)), (bruiser_roar_1, (0.9, 1.06)),
    (zombie_swipe, (0.9, 1.1)), (hitmarker, (0.94, 1.06)), (kill_confirm, (0.96, 1.04)), (headshot_ping, (0.96, 1.05)),
]


def write_loop_wav(name, mono, peak=0.7):
    """A mono loop written without fades (so it loops cleanly)."""
    x = norm(np.asarray(mono, dtype=np.float64), peak)
    with wave.open(os.path.join(SFX, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def run_core():
    for fn in SFX_SOUNDS:
        write_wav(fn.__name__, fn())
    for fn, pitches in VARIANTS:
        for suffix, pitch, seed in zip(("_b", "_c"), pitches, (101, 202)):
            write_wav(fn.__name__ + suffix, _variant(fn, pitch, seed))
    write_loop_wav("portal_hum", portal_hum())
    write_ogg("pier_ambience", pier_ambience(), peak=0.7)
    write_ogg("boardwalk_loop", boardwalk_loop(), peak=0.75)
    write_ogg("menu_theme", menu_theme(), peak=0.72)
    print("core: %d sfx + portal_hum, pier_ambience.ogg, boardwalk_loop.ogg" % len(SFX_SOUNDS))


def run_pack(name):
    """Runs tools/audio_packs/<name>.py. A pack module may define:
         SOUNDS   list of functions -> mono array      (written as <fn name>.wav)
         VARIANTS list of (function, (pitch_b, pitch_c)) (writes _b/_c takes)
         LOOPS    dict name -> function -> mono array   (seamless .wav loops)
         MUSIC    dict name -> function -> (n, 2) array (written as .ogg)
       Packs import the helpers with `from gen_audio import *`.
    """
    import importlib
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "audio_packs"))
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    mod = importlib.import_module(name)
    count = 0
    for fn in getattr(mod, "SOUNDS", []):
        write_wav(fn.__name__, fn())
        count += 1
    for fn, pitches in getattr(mod, "VARIANTS", []):
        for suffix, pitch, seed in zip(("_b", "_c"), pitches, (101, 202)):
            write_wav(fn.__name__ + suffix, _variant(fn, pitch, seed))
    for loop_name, fn in getattr(mod, "LOOPS", {}).items():
        write_loop_wav(loop_name, fn())
    for music_name, fn in getattr(mod, "MUSIC", {}).items():
        write_ogg(music_name, fn(), peak=0.75)
    print("pack %s: %d sfx, %d loops, %d music" % (name, count, len(getattr(mod, "LOOPS", {})), len(getattr(mod, "MUSIC", {}))))


def main():
    """python tools/gen_audio.py            -> core sounds + every pack
       python tools/gen_audio.py core       -> only the core sounds
       python tools/gen_audio.py neon_city  -> only tools/audio_packs/neon_city.py"""
    os.makedirs(SFX, exist_ok=True)
    os.makedirs(MUSIC, exist_ok=True)
    wanted = [a for a in sys.argv[1:] if not a.startswith("-")]
    packs_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audio_packs")
    packs = sorted(f[:-3] for f in os.listdir(packs_dir) if f.endswith(".py") and not f.startswith("_"))
    if not wanted or "core" in wanted:
        run_core()
    for pack in packs:
        if not wanted or pack in wanted:
            run_pack(pack)


if __name__ == "__main__":
    main()
