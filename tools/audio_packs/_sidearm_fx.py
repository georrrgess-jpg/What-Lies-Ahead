"""Shared layers for the sidearms' "epic" sounds (update 14): every fire sound
is a sharp transient, the weapon's own body, a short low punch and a small
room tail; reloads get crisp mechanism clicks, a hologram shimmer and a
"ready" chime. Not a pack (the leading underscore keeps gen_audio from
running it): gen_audio.py and the packs import it.

Every layer draws its noise from its own seeded generator, so these layers
never shift the noise of other sounds in a pack and render the same whether
a pack runs alone or after others.
"""
import numpy as np

from gen_audio import SR, band, env, filt, sweep, t_axis


def hiss(seconds, seed):
    """White noise from its own generator (`seed` picks the take)."""
    return np.random.default_rng(seed).uniform(-1, 1, int(SR * seconds))


def snap(d, seed, centre=3000.0, ms=3.0, gain=1.0):
    """The transient: a 1-5 ms band-limited crack at the start of a `d` s buffer."""
    out = np.zeros(int(SR * d))
    n = int(SR * ms / 1000.0 * 4)
    burst = band(hiss(n / SR, seed), centre, centre * 0.6) * 3.0 + filt(hiss(n / SR, seed + 1), high=1200, low=7000)
    burst *= env(n / SR, 0.0002, ms / 1000.0 * 2, power=2.5)
    out[:n] += burst[:len(out)] * gain
    return out


def punch(d, f0=140.0, f1=48.0, decay=0.09, gain=1.0):
    """The low-end thump (60-150 Hz): a fast-falling sine with a soft 1 ms attack."""
    return sweep(f0, f1, d, "sine", 0.3) * env(d, 0.001, decay, power=2.2) * gain


def duck(x, at=0.004, depth=0.45, release=0.05):
    """Sidechain feel: dips `x` by `depth` right after `at` s and lets it swell back."""
    t = t_axis(len(x) / SR)
    k = np.clip((t - at) / max(release, 1e-4), 0.0, 1.0)
    return x * np.where(t < at, 1.0, 1.0 - depth * (1.0 - k) ** 2)


def room(x, seed, size=0.2, slap=0.05, wet=0.22, dark=3600.0, low_cut=220.0):
    """`x` plus a short tail: one slap-back off a near wall and a small-room
    decay of `size` s. Mono (it sums to itself), darker than the dry sound and
    high-passed so the punch stays dry and tight. The buffer grows by `size`."""
    n = len(x)
    k = min(n, int(SR * 0.006))
    x = x.copy()
    x[n - k:] *= np.linspace(1.0, 0.0, k)  # the dry layers end in silence, not a step
    out = np.concatenate([x, np.zeros(int(SR * size))])
    send = filt(out, low=dark, high=low_cut)
    for delay, g in ((slap, 0.55), (slap * 1.7, 0.3)):
        i = int(SR * delay)
        out[i:] += send[:len(out) - i] * g * wet
    t = t_axis(size)
    ir = filt(hiss(size, seed), low=dark) * np.exp(-5.0 * t / size) * (1.0 - np.exp(-t / 0.006))
    tail = np.fft.irfft(np.fft.rfft(send, len(out) + len(ir)) * np.fft.rfft(ir, len(out) + len(ir)))[:len(out)]
    tail *= wet * np.max(np.abs(x[:n])) / max(np.max(np.abs(tail)), 1e-9)
    return out + tail


def glue(x, drive=1.25, ceiling=9500.0):
    """Soft saturation and a top ceiling: welds the layers into one hit."""
    return np.tanh(filt(x, low=ceiling) * drive) / np.tanh(drive)


def fire(body, seed, crack=3000.0, crack_gain=0.8, low=(140.0, 50.0, 0.09, 1.0), size=0.2, slap=0.045, wet=0.25,
         drive=1.25, ceiling=9000.0, duck_depth=0.3):
    """A whole shot (or hit) around the weapon's own `body`: the transient on top, the
    body ducked under the punch, the punch (`low` = f0, f1, decay, gain) and
    the room tail, glued. Fast autos take a small `size` and `wet`."""
    d = len(body) / SR
    dry = snap(d, seed, crack, 2.5, crack_gain) + duck(body, 0.005, duck_depth, 0.05) + punch(d, *low)
    return glue(room(dry, seed + 1, size, slap, wet), drive, ceiling)


def tick(seed, centre=2600.0, seconds=0.014, gain=1.0):
    """A crisp mechanism click (latch, slide, catch) with a little body."""
    n = hiss(seconds, seed)
    body = band(n, centre, centre * 0.35) * 3.0 + band(n, centre * 0.4, centre * 0.15) * 2.0
    return body * env(seconds, 0.0003, seconds, power=3.0) * 0.5 * gain  # layered on a clunk, it stays under it


def latch(seed, pitch=180.0, gain=1.0):
    """A seated part: a click on top of a short low knock."""
    d = 0.1
    out = sweep(pitch * 1.5, pitch * 0.7, d) * env(d, 0.001, 0.07, power=2.4) * 0.8
    out[:int(SR * 0.014)] += tick(seed, 2200.0)
    return out * 0.45 * gain


def holo(seconds, f0, f1, seed, gain=1.0):
    """A hologram printing in: a rising glassy sweep with a fast flutter and fizz."""
    t = t_axis(seconds)
    tone = sweep(f0, f1, seconds, "sine", 0.8) + sweep(f0 * 2.01, f1 * 2.01, seconds, "sine", 0.8) * 0.35
    flutter = 0.65 + 0.35 * np.sin(2 * np.pi * 28 * t)
    fizz = band(hiss(seconds, seed), 4200, 1400) * 0.25
    return (tone * flutter + fizz) * env(seconds, seconds * 0.5, seconds, power=0.7, release=seconds * 0.35) * gain


def ready(freq=880.0, gain=1.0):
    """The "ready" cue: two quick bell notes a fifth apart, warm and short."""
    out = np.zeros(int(SR * 0.3))
    for at, f in ((0.0, freq), (0.06, freq * 1.5)):
        d = 0.22
        ring = (np.sin(2 * np.pi * f * t_axis(d)) + np.sin(2 * np.pi * f * 2.76 * t_axis(d)) * 0.18) * env(d, 0.001, d, power=2.6)
        i = int(SR * at)
        out[i:i + len(ring)] += ring[:len(out) - i]
    return out * gain


def place_at(buf, x, at, gain=1.0):
    """Mixes `x` into `buf` at `at` seconds (clipped to the buffer)."""
    i = int(SR * at)
    n = min(len(x), len(buf) - i)
    if n > 0:
        buf[i:i + n] += x[:n] * gain
    return buf
