"""Shared "epic" layering for the primary weapons' sounds (update 14).

`punch(x, ...)` takes a weapon sound as its generator renders it and wraps it
in the house weapon recipe:

    transient  a 1-4 ms band-limited snap (the trigger break)
    body       the weapon's own sound, ducked a little under the thump
    thump      a short 60-150 Hz sine drop (the chest punch)
    tail       two dark slap-back taps and a small-room bloom (mono-safe)
    voicing    a 35 Hz high-pass (no rumble/DC), a high-shelf cut above
               `shelf_hz` (never piercing) and a soft clip

Everything here draws from its own seeded generator, never from gen_audio's
`rng`, so wrapping a pack's sound does not re-roll the sounds after it.
"""
import zlib

import numpy as np

from gen_audio import SR, env, filt, sweep


def _rng(tag, n):
    return np.random.default_rng(zlib.crc32(("%s:%d" % (tag, n)).encode()))


def _shelf(x, hz, db):
    """High-shelf of `db` above `hz` (smooth, FFT)."""
    if not db:
        return x
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    g = 10 ** (db / 20.0)
    k = 1.0 / (1.0 + (hz / np.maximum(f, 1.0)) ** 2)
    return np.fft.irfft(spec * (1.0 + (g - 1.0) * k), len(x))


def snap(seconds=0.004, centre=3200.0, seed="snap"):
    """The transient: a few ms of band-passed noise with an instant attack."""
    n = int(SR * 0.03)
    w = _rng(seed, n).standard_normal(n)
    w = filt(w, high=centre * 0.55, low=centre * 1.8)
    return w * env(0.03, 0.0002, seconds, power=2.0)


def thump(f0=140.0, f1=55.0, decay=0.07, seconds=0.25):
    """The low punch: a fast sine drop."""
    return sweep(f0, f1, seconds, "sine", 0.4) * env(seconds, 0.0015, decay, power=2.0)


def room(x, seconds=0.22, dark=2600.0, seed="room"):
    """A small-room bloom of x: decaying noise IR, darker than the dry sound."""
    n = int(SR * seconds)
    t = np.arange(n) / SR
    ir = _rng(seed, n).standard_normal(n) * np.exp(-6.9 * t / seconds) * (1.0 - np.exp(-t / 0.004))
    ir = filt(ir, low=dark, high=180.0)
    ir /= np.sqrt(np.sum(ir * ir))
    m = len(x) + n
    return np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)


def punch(x, *, snap_gain=0.35, snap_hz=3200.0, snap_ms=3.0,
          thump_gain=0.6, thump_hz=(140.0, 55.0), thump_decay=0.07, duck=0.3,
          slap=(0.028, 0.047), slap_gain=0.16, room_gain=0.12, room_s=0.2,
          shelf_hz=5000.0, shelf_db=-3.0, low=11000.0, drive=1.25, seed="w"):
    """Wraps a weapon sound in the house recipe (see the module doc). Gains are
    relative to the body's own peak, so callers can wrap any generator."""
    body = np.asarray(x, dtype=np.float64)
    body = body / max(1e-9, np.max(np.abs(body)))
    k = min(len(body) // 4, int(SR * 0.012))
    body[len(body) - k:] *= np.linspace(1.0, 0.0, k) ** 2    # no click where the dry sound stops
    tail_s = max(slap) + room_s if (slap_gain or room_gain) else 0.0
    out = np.zeros(len(body) + int(SR * tail_s))
    th = thump(thump_hz[0], thump_hz[1], thump_decay, min(0.4, max(0.12, thump_decay * 4)))
    t = np.arange(len(body)) / SR
    duck_env = 1.0 - duck * np.clip(1.0 - t / (thump_decay * 0.8), 0.0, 1.0) ** 2 * np.clip(t / 0.003, 0.0, 1.0)
    out[:len(body)] += body * duck_env
    out[:len(th)] += th * thump_gain
    sn = snap(snap_ms / 1000.0, snap_hz, seed + ":snap")
    out[:len(sn)] += sn * snap_gain / max(1e-9, np.max(np.abs(sn)))
    dry = out.copy()
    for k, delay in enumerate(slap):
        i = int(SR * delay)
        out[i:] += filt(dry, low=2400 - 500 * k, high=200)[:len(out) - i] * slap_gain * (0.6 ** k)
    if room_gain:
        out += room(dry, room_s, seed=seed + ":room")[:len(out)] * room_gain
    pad = int(SR * 0.1)                 # FFT filters ring both ways: keep that ringing out of the sound
    out = _shelf(filt(np.concatenate([out, np.zeros(pad)]), low=low, high=35.0), shelf_hz, shelf_db)[:len(out)]
    return np.tanh(out * drive) / np.tanh(drive)
