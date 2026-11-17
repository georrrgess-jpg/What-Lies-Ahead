"""House tuning: a per-sound post-process applied by tools/gen_audio.py as it
writes each file (write_wav, write_loop_wav, write_music), so a retune found by
the sound audit (tools/sound_audit.py, docs/SOUND_AUDIT.md) is reproducible and
survives any regeneration.

TUNING maps a sound name (its _b/_c takes inherit it) to:
    hp      high-pass (Hz, 4th order): clears rumble small speakers turn into mud
    lp      low-pass (Hz, 4th order): takes the fizz and whistle off the top
    bells   ((centre Hz, gain dB, Q), ...): peaking EQ
    shelf   (corner Hz, gain dB): gentle high shelf (negative = darker)
    pitch   playback-rate factor (1.12 = about two semitones up, and shorter)
Volume is not set here (write_wav normalises the peak): it lives in the
per-sound trims of audio/mix.tres.

    python3 tools/gen_audio.py <pack> --only=name1,name2   rewrite just those files
    python3 tools/gen_audio.py --tuned                       rewrite every sound listed here
"""
import re

import numpy as np

SR = 44100

TUNING = {
}


def tuning_for(name):
    """The entry for `name` or for the sound it is a take of (name_b, name_c)."""
    if name in TUNING:
        return TUNING[name]
    return TUNING.get(re.sub(r"_[bc]$", "", name))


def _gain(n, t):
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = 1e-3
    g = np.ones_like(f)
    if t.get("hp"):
        g /= np.sqrt(1.0 + (t["hp"] / f) ** 8)
    if t.get("lp"):
        g /= np.sqrt(1.0 + (f / t["lp"]) ** 8)
    for fc, gain_db, q in t.get("bells", ()):
        a = 10 ** (gain_db / 40.0)
        w = f / fc
        g *= np.sqrt(((1 - w * w) ** 2 + (w * a / q) ** 2) / ((1 - w * w) ** 2 + (w / (a * q)) ** 2))
    if t.get("shelf"):
        fc, gain_db = t["shelf"]
        g *= 10 ** (gain_db * (f * f / (f * f + fc * fc)) / 20.0)
    return g


def _repitch(x, factor, loop):
    n = len(x)
    idx = np.arange(0, n - (0 if loop else 1), factor)
    src = np.arange(n + 1) if loop else np.arange(n)
    if x.ndim == 1:
        return np.interp(idx, src, np.concatenate([x, x[:1]]) if loop else x)
    return np.stack([np.interp(idx, src, np.concatenate([c, c[:1]]) if loop else c) for c in x.T], axis=1)


def apply(name, x, loop=False):
    """`x` (mono, or (n, 2)) with its tuning; untouched when it has none.
    One-shots are padded so the zero-phase EQ does not wrap the tail onto the
    attack; loops are filtered circularly so they stay seamless."""
    t = tuning_for(name)
    if not t:
        return x
    x = np.asarray(x, dtype=np.float64)
    if t.get("pitch"):
        x = _repitch(x, t["pitch"], loop)
    if any(k in t for k in ("hp", "lp", "bells", "shelf")):
        pad = 0 if loop else int(0.25 * SR)
        n = len(x) + 2 * pad
        shape = (pad, pad) if x.ndim == 1 else ((pad, pad), (0, 0))
        spec = np.fft.rfft(np.pad(x, shape), axis=0)
        g = _gain(n, t)
        spec *= g if x.ndim == 1 else g[:, None]
        x = np.fft.irfft(spec, n, axis=0)[pad:pad + len(x) if pad else None]
    return x
