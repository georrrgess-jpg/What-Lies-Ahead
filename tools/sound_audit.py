#!/usr/bin/env python3
"""Sound-design audit: measures every sound effect and music loop, finds the
ones that are too loud, too quiet, too harsh or out of family, and draws a
log-frequency spectrogram of each one on contact sheets per category.

    python3 tools/sound_audit.py                         table of outliers + family summary
    python3 tools/sound_audit.py --csv out.csv           every measurement as CSV
    python3 tools/sound_audit.py --sheets docs/sound_audit/after
                                                         contact sheets (jpg) per family
    python3 tools/sound_audit.py --only pcp_,weap_rail_  only sounds starting with these
    python3 tools/sound_audit.py --family weapon         only one family

The house targets (docs/SOUND_AUDIT.md) are the constants under TARGETS. The
in-game level of a sound (`eff`) comes from tools/audio_mix_report.py: the
file's loudest K-weighted 100 ms window + its loudest gameplay call's
volume_db + audio/mix.tres (category gain + trim) + the bus chain, with a
positional sound taken 4 m in front of the listener. Loops (music, ambience)
use their integrated loudness at the level's volume instead.

Per-file columns:
    sec      length (s)            peak   sample peak (dBFS)
    rms      RMS of the active part (dBFS)
    lufs     loudness estimate: loudest 400 ms K-weighted block (loops: gated integrated)
    crest    peak - rms (dB): punch; low = squashed/droning, very high = a lone click
    cent     spectral centroid (Hz): brightness
    hf4/hf8  share of energy above 4 / 8 kHz (%): harshness
    tone     strongest narrow tone (Hz) and its share of the energy (%): whistles
    low80    share of energy below 80 Hz (%): mud / rumble
    dc       DC offset (% of peak)   clip   samples at full scale
    click    start / end discontinuity (% of peak); for loops the seam (only when it jumps
             further than any sample step inside the loop)
    eff      effective in-game level (dB at the output, K-weighted)
Needs numpy and Pillow; ffmpeg decodes the .ogg loops.
"""
import argparse
import glob
import os
import re
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_mix_report as amr  # noqa: E402

ROOT = amr.ROOT
SR = amr.SR

# House targets (see docs/SOUND_AUDIT.md). Bands are eff (dB at the output).
TARGETS = {
    "loud_db": 5.0,         # louder than the family median by this much: flag
    "quiet_db": 8.0,        # quieter than the family median by this much: flag
    "hf8_pct": 6.0,         # energy above 8 kHz: ceiling
    "hf4_pct": 30.0,        # energy above 4 kHz: ceiling
    "tone_pct": 25.0,       # a single narrow tone above 1.2 kHz holding this share: a whistle
    "tone_hz": 1200.0,
    "low80_pct": 35.0,      # energy below 80 Hz: mud (bosses, slams and thumps may go higher)
    "click_pct": 5.0,       # a start/end jump bigger than this share of the peak
    "dc_pct": 2.0,
    "cent_oct": 1.5,        # centroid this many octaves off the family median: out of family
}
# House bands per family: the ceiling of the in-game level (eff, dB); see the
# table in docs/SOUND_AUDIT.md. Nothing goes above CEILING_DB.
HOUSE_MAX = {"weapon": -11.0, "handling": -16.0, "confirm": -16.0, "impact": -13.0, "kill_effect": -17.0,
             "enemy_voice": -16.0, "enemy_attack": -11.0, "enemy_telegraph": -11.0, "enemy_special": -11.0,
             "cue": -10.0, "player": -17.0, "ui": -14.0, "ambience": -16.0, "music": -26.0, "ambience_bed": -31.0}
CEILING_DB = -9.0
# Families allowed more low end by design (thumps, bosses, music, beds).
LOW_OK = ("enemy_attack", "enemy_special", "music", "ambience", "ambience_bed")
# Families allowed a bright, tonal character (UI blips, pings, chimes).
TONE_OK = ("confirm", "ui", "cue", "kill_effect")
LOOP_SFX = None   # filled from gen_audio's LOOPS: seamless .wav loops


# ---------------------------------------------------------------------------
# Measuring
# ---------------------------------------------------------------------------

def loop_names():
    """Names of the .wav loops (written by write_loop_wav)."""
    names = {"portal_hum"}
    for path in glob.glob(os.path.join(ROOT, "tools/audio_packs/*.py")):
        text = open(path, encoding="utf-8").read()
        m = re.search(r"^LOOPS = \{(.*?)^\}", text, re.M | re.S)
        if m:
            names.update(re.findall(r'"(\w+)":', m.group(1)))
    return names


def spectrum(mono):
    """Averaged power spectrum (Welch, 4096-point Hann), frequencies."""
    n = 4096
    if len(mono) < n:
        mono = np.concatenate([mono, np.zeros(n - len(mono))])
    hop = n // 2
    frames = np.lib.stride_tricks.sliding_window_view(mono, n)[::hop]
    p = (np.abs(np.fft.rfft(frames * np.hanning(n), axis=1)) ** 2).mean(axis=0)
    return p, np.fft.rfftfreq(n, 1.0 / SR)


def measure(path, loop):
    """Every column of the audit for one file."""
    raw = amr.load(path)
    m = amr.measure(path, loop)
    mono = raw.mean(axis=1)
    peak = max(1e-9, np.max(np.abs(mono)))
    p, f = spectrum(mono)
    audible = (f >= 20) & (f < 20000)
    total = p[audible].sum() + 1e-20
    i = int(np.argmax(np.where(f > 40, p, 0)))
    tone = p[max(0, i - 3):i + 4].sum() / total
    m.update({
        "crest": m["peak"] - m["rms"],
        "cent": float((p[audible] * f[audible]).sum() / total),
        "hf4": float(100 * p[f >= 4000].sum() / total),
        "hf8": float(100 * p[f >= 8000].sum() / total),
        "tone_hz": float(f[i]), "tone": float(100 * tone),
        "low80": float(100 * p[(f >= 20) & (f < 80)].sum() / total),
        "dc": float(100 * abs(mono.mean()) / peak),
        "clip": int((np.abs(raw) >= 32767 / 32768).sum()),
    })
    if loop:   # the seam, counted only when it jumps further than the sound itself ever does
        jump = abs(mono[0] - mono[-1])
        m["click"] = float(100 * jump / peak) if jump > 1.5 * np.max(np.abs(np.diff(mono))) else 0.0
    else:
        m["click"] = float(100 * max(abs(mono[0]), abs(mono[-1])) / peak)
    return m


WEAPON_PACKS = ("weapons", "guns_new1", "guns_new2", "guns8", "guns8b", "ground_control", "hubcap", "jack_pot",
                "lava_lampoon", "markdown_marker", "popcorn_popper", "ripsaw", "strike_zone", "t_minus_six", "yoyo_loco",
                "tin_sergeant")
CORE_WEAPON = ("pistol_fire", "carbine_fire", "scatter_fire", "pistol_reload", "carbine_reload", "scatter_reload",
               "empty_click")


def packs():
    """Sound name -> the generator that writes it (a pack name or "core")."""
    owner = {}
    for path in glob.glob(os.path.join(ROOT, "tools/audio_packs/*.py")):
        pack = os.path.basename(path)[:-3]
        text = open(path, encoding="utf-8").read()
        for name in re.findall(r"^def ([a-z]\w*)\(", text, re.M) + re.findall(r'^    "(\w+)":', text, re.M):
            owner[name] = pack
    return owner


def owner_of(name, pack_of):
    """"wpn" for a weapon lane's sound, "" for the rest of the game."""
    base = re.sub(r"_[bc]$", "", name)
    pack = pack_of.get(base, pack_of.get(name, "core"))
    return "wpn" if pack in WEAPON_PACKS or base in CORE_WEAPON or base.startswith("reload_") else ""


def family_of(name, mix):
    return mix.category(name)


def collect(only=(), family=None):
    """name -> row dict with measurements, family and effective level."""
    mix, busses = amr.Mix(), amr.bus_gains()
    loops = loop_names()
    sfx = sorted(glob.glob(os.path.join(ROOT, "audio/sfx/*.wav")))
    names = [os.path.basename(p)[:-4] for p in sfx]
    sites = amr.call_sites(names)
    pack_of = packs()
    rows = {}
    known = set(names)
    for path, name in zip(sfx, names):
        if only and not name.startswith(tuple(only)):
            continue
        # A take (name_b, name_c) is played, mixed and judged as its base sound.
        base = re.sub(r"_[bc]$", "", name)
        base = base if base != name and base in known else name
        fam = family_of(base, mix)
        if family and fam != family:
            continue
        loop = name in loops
        m = measure(path, loop)
        e = amr.effective(base, m, sites, mix, busses)
        if e is None:   # no call site found: the mix gain at volume 0, non-positional
            g = mix.gain_db(base) + busses.get(mix.bus_of(base), 0.0)
            e = {"effK": m["k100"] + g, "mix": mix.gain_db(base), "call": None, "where": ""}
        m.update(name=name, kind="sfx", family=fam, loop=loop, eff=e["effK"] if not loop else m["lufs"] + e["effK"] - m["k100"],
                 mix=e["mix"], call=e["call"], where=e["where"], path=path, pack=pack_of.get(base, "core"),
                 owner=owner_of(name, pack_of))
        rows[name] = m
    for track, lvl, bus in music_levels(mix, busses):
        if only and not track.startswith(tuple(only)):
            continue
        fam = "ambience_bed" if track.endswith("_ambience") else "music"
        if family and fam != family:
            continue
        path = os.path.join(ROOT, "audio/music/%s.ogg" % track)
        m = measure(path, True)
        m.update(name=track, kind="music", family=fam, loop=True, eff=m["lufs"] + lvl + bus, mix=lvl, call=None,
                 where="", path=path, pack="", owner="")
        rows[track] = m
    return rows


def music_levels(mix, busses):
    """(track, loudest volume_db + mix it plays at, bus gain) for every .ogg."""
    best = {}
    for lv in amr.levels():
        for kind in ("music", "music_final", "ambience"):
            track = lv.get(kind)
            if not track:
                continue
            lvl = lv["ambience_volume_db" if kind == "ambience" else "music_volume_db"] + mix.gain_db(track)
            best[track] = max(best.get(track, -99.0), lvl)
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "audio/music/*.ogg"))):
        track = os.path.basename(path)[:-4]
        amb = track.endswith("_ambience")
        lvl = best.get(track, (-8.0 if amb else -9.0) + mix.gain_db(track))
        out.append((track, lvl, busses.get("Ambience" if amb else "Music", 0.0)))
    return out


# ---------------------------------------------------------------------------
# Outliers
# ---------------------------------------------------------------------------

def flag(rows):
    """Adds row["flags"]: a list of short reasons; returns family medians."""
    med = {}
    for fam in sorted(set(r["family"] for r in rows.values())):
        fr = [r for r in rows.values() if r["family"] == fam and not re.search(r"_[bc]$", r["name"])]
        med[fam] = {"eff": float(np.median([r["eff"] for r in fr])), "cent": float(np.median([r["cent"] for r in fr])),
                    "n": len(fr)}
    t = TARGETS
    for r in rows.values():
        fam, f = r["family"], []
        d = r["eff"] - med[fam]["eff"]
        if d > t["loud_db"]:
            f.append("loud+%.0f" % d)
        top = HOUSE_MAX.get(fam, CEILING_DB)
        if r["eff"] > CEILING_DB + 0.25 or r["eff"] > top + 0.5:
            f.append("over band %.0f" % min(top, CEILING_DB))
        if d < -t["quiet_db"]:
            f.append("quiet%.0f" % d)
        if r["hf8"] > t["hf8_pct"]:
            f.append("hf8k %.0f%%" % r["hf8"])
        elif r["hf4"] > t["hf4_pct"]:
            f.append("hf4k %.0f%%" % r["hf4"])
        if r["tone"] > t["tone_pct"] and r["tone_hz"] > t["tone_hz"] and fam not in TONE_OK:
            f.append("whistle %.0fHz %.0f%%" % (r["tone_hz"], r["tone"]))
        if r["low80"] > t["low80_pct"] and fam not in LOW_OK:
            f.append("mud %.0f%%" % r["low80"])
        if r["click"] > t["click_pct"]:
            f.append("click %.0f%%" % r["click"])
        if r["dc"] > t["dc_pct"]:
            f.append("dc")
        if r["clip"] > 0:
            f.append("clip")
        oct_off = np.log2(max(r["cent"], 1.0) / med[fam]["cent"])
        if abs(oct_off) > t["cent_oct"]:
            f.append("%s %.1foct" % ("bright" if oct_off > 0 else "dull", abs(oct_off)))
        r["flags"] = f
    return med


# ---------------------------------------------------------------------------
# Spectrogram contact sheets
# ---------------------------------------------------------------------------

TILE_W, TILE_H, LABEL_H = 240, 120, 16
F_LO, F_HI = 30.0, 18000.0
_STOPS = np.array([[0, 0, 4], [40, 11, 84], [101, 21, 110], [159, 42, 99], [212, 72, 66], [245, 125, 21],
                   [250, 193, 39], [252, 255, 164]], dtype=np.float64)


def colormap(v):
    """v in 0..1 -> RGB (a magma-like ramp)."""
    pos = np.clip(v, 0, 1) * (len(_STOPS) - 1)
    i = np.minimum(pos.astype(int), len(_STOPS) - 2)
    k = (pos - i)[..., None]
    return (_STOPS[i] * (1 - k) + _STOPS[i + 1] * k).astype(np.uint8)


def spectrogram(mono, width=TILE_W, height=TILE_H - LABEL_H):
    """Log-frequency spectrogram as an RGB array (height, width, 3), -80..0 dBFS."""
    n = 2048
    hop = max(32, len(mono) // width)
    pad = np.concatenate([np.zeros(n // 2), mono, np.zeros(n)])
    frames = np.lib.stride_tricks.sliding_window_view(pad, n)[::hop][:width]
    mag = np.abs(np.fft.rfft(frames * np.hanning(n), axis=1)) * 4.0 / n
    f = np.fft.rfftfreq(n, 1.0 / SR)
    rows = np.geomspace(F_LO, F_HI, height + 1)
    out = np.empty((height, len(frames)))
    for j in range(height):
        sel = (f >= rows[j]) & (f < rows[j + 1])
        if sel.any():
            out[height - 1 - j] = mag[:, sel].max(axis=1)
        else:
            k = np.searchsorted(f, rows[j])
            out[height - 1 - j] = mag[:, min(k, len(f) - 1)]
    dbv = 20 * np.log10(np.maximum(out, 1e-9))
    img = colormap((dbv + 80) / 80)
    if img.shape[1] < width:   # short sounds: time runs at hop 32 and the rest stays dark
        img = np.concatenate([img, np.zeros((height, width - img.shape[1], 3), np.uint8)], axis=1)
    return img


def sheets(rows, out_dir, per_page=60, cols=6):
    from PIL import Image, ImageDraw, ImageFont
    os.makedirs(out_dir, exist_ok=True)
    font = ImageFont.load_default(size=11)
    written = []
    for fam in sorted(set(r["family"] for r in rows.values())):
        fr = sorted((r for r in rows.values() if r["family"] == fam), key=lambda r: r["name"])
        for page in range(0, len(fr), per_page):
            chunk = fr[page:page + per_page]
            nrows = -(-len(chunk) // cols)
            sheet = Image.new("RGB", (cols * (TILE_W + 4) + 4, nrows * (TILE_H + 4) + 4), (24, 24, 28))
            draw = ImageDraw.Draw(sheet)
            for idx, r in enumerate(chunk):
                x0, y0 = 4 + (idx % cols) * (TILE_W + 4), 4 + (idx // cols) * (TILE_H + 4)
                mono = amr.load(r["path"]).mean(axis=1)
                sheet.paste(Image.fromarray(spectrogram(mono)), (x0, y0 + LABEL_H))
                for hz in (100, 1000, 10000):   # faint guides at 100 Hz, 1 kHz, 10 kHz
                    y = y0 + LABEL_H + int((1 - np.log(hz / F_LO) / np.log(F_HI / F_LO)) * (TILE_H - LABEL_H))
                    draw.line([(x0, y), (x0 + 5, y)], fill=(140, 140, 150))
                bad = bool(r.get("flags"))
                draw.rectangle([x0, y0, x0 + TILE_W - 1, y0 + LABEL_H - 1], fill=(120, 30, 30) if bad else (40, 40, 48))
                draw.text((x0 + 3, y0 + 2), "%s %.1fs" % (r["name"][:27], r["seconds"]), fill=(235, 235, 235), font=font)
                draw.text((x0 + TILE_W - 3, y0 + 2), "%+.0f" % r["eff"], fill=(255, 220, 120), font=font, anchor="ra")
            path = os.path.join(out_dir, "%s_%d.jpg" % (fam, page // per_page + 1))
            sheet.save(path, quality=78)
            written.append(path)
    return written


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

COLS = ("seconds", "peak", "rms", "lufs", "crest", "cent", "hf4", "hf8", "tone_hz", "tone", "low80", "dc", "clip", "click",
        "mix", "eff")


def write_csv(rows, path):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w") as f:
        f.write("name,kind,family,pack,owner," + ",".join(COLS) + ",flags\n")
        for r in sorted(rows.values(), key=lambda r: (r["family"], r["name"])):
            vals = ["%.2f" % r[c] if isinstance(r[c], float) else str(r[c]) for c in COLS]
            f.write("%s,%s,%s,%s,%s,%s,%s\n" % (r["name"], r["kind"], r["family"], r["pack"], r["owner"], ",".join(vals),
                                                " | ".join(r["flags"])))


def summary(rows, med):
    print("%-16s %4s %7s %7s %6s %6s %6s %6s" % ("family", "n", "eff", "spread", "cent", "hf4%", "crest", "flagged"))
    for fam, m in med.items():
        fr = [r for r in rows.values() if r["family"] == fam]
        effs = [r["eff"] for r in fr]
        print("%-16s %4d %7.1f %7.1f %6.0f %6.1f %6.1f %6d" % (
            fam, len(fr), m["eff"], np.percentile(effs, 90) - np.percentile(effs, 10), m["cent"],
            np.median([r["hf4"] for r in fr]), np.median([r["crest"] for r in fr]), sum(1 for r in fr if r["flags"])))
    print("\n%-28s %-3s %-15s %5s %6s %6s %6s %5s %5s %5s  %s" % (
        "flagged sound", "own", "family", "sec", "peak", "eff", "cent", "hf4", "hf8", "low80", "why"))
    for r in sorted(rows.values(), key=lambda r: (r["family"], r["name"])):
        if r["flags"] and not re.search(r"_[bc]$", r["name"]):
            print("%-28s %-3s %-15s %5.2f %6.1f %6.1f %6.0f %5.1f %5.1f %5.1f  %s" % (
                r["name"], r["owner"], r["family"], r["seconds"], r["peak"], r["eff"], r["cent"], r["hf4"], r["hf8"], r["low80"],
                ", ".join(r["flags"])))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv")
    ap.add_argument("--sheets")
    ap.add_argument("--only", default="", help="comma-separated name prefixes")
    ap.add_argument("--family")
    args = ap.parse_args()
    only = [p for p in args.only.split(",") if p]
    rows = collect(only, args.family)
    med = flag(rows)
    summary(rows, med)
    if args.csv:
        write_csv(rows, args.csv)
        print("wrote", args.csv)
    if args.sheets:
        print("wrote %d sheets to %s" % (len(sheets(rows, args.sheets)), args.sheets))


if __name__ == "__main__":
    main()
