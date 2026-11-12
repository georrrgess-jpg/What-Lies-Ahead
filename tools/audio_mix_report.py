#!/usr/bin/env python3
"""Audio mix report: measures every sound, music and ambience file and the level
each one reaches in the game (file + call site + mix table + busses), so the mix
can be re-checked after any change to a sound, a call site or audio/mix.tres.

    python3 tools/audio_mix_report.py                 key sounds, every loop, spectra
    python3 tools/audio_mix_report.py --all           every sound effect
    python3 tools/audio_mix_report.py --csv out.csv   the full table as CSV
    python3 tools/audio_mix_report.py --mixdown prize_pier /tmp/mix.wav
                                                      20 s listen-proxy: music, ambience
                                                      and a scripted fight at game levels

Needs numpy, and ffmpeg to decode the .ogg loops.

Sound columns (dB per output channel; a mono file plays on both channels):
    peak    sample peak of the file (dBFS)
    st100   loudest 100 ms RMS window of the file (dBFS)
    k100    the same through the ITU-R BS.1770 K-weighting: a perceived
            short-term level, so a bright tick and a broadband shot compare fairly
    call    the call-site volume_db (the loudest gameplay call)
    mix     gain from audio/mix.tres (category + per-sound trim)
    bus     bus chain at the default settings (bus volume, sliders, sends)
    eff     st100 as heard: file + call + mix + bus. A positional sound is taken
            at NEAR_M metres in front of the listener (Godot's inverse-distance
            law, the max_db cap and the -3 dB centre pan)
    effK    the same for k100
    outpk   the sound's own peak at the output (dBFS), before the Master limiter
Loop columns: st100 p95, integrated loudness (LUFS), the level's volume_db
(+ mix), and eff / effL = p95 / LUFS as heard, plus energy per band.
"""
import argparse
import glob
import math
import os
import re
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SR = 44100
NEAR_M = 4.0          # distance a positional sound is measured at
PAN_CENTRE_DB = -3.01  # Godot's speaker-placement panning, source straight ahead
MAX_DISTANCE = 70.0    # Sfx.play_at max_distance (linear fade to silence)

KEY_SOUNDS = [
    "pistol_fire", "carbine_fire", "scatter_fire", "weap_arc_fire", "weap_rail_fire", "weap_cannon_fire",
    "weap_lobber_fire", "weap_lobber_boom", "weap_cryo_start", "weap_cryo_loop",
    "hitmarker", "kill_confirm", "headshot_ping", "combo_up", "hit_body", "hit_head", "zombie_pop",
    "zombie_groan_1", "runner_screech_1", "bruiser_roar_1", "zombie_swipe", "bruiser_slam",
    "neon_punk_jeer_1", "neon_spray_hiss", "neon_shield_block", "neon_shield_break", "neon_leap_land",
    "aqua_octo_gurgle_1", "aqua_ink_spit", "aqua_jelly_zap", "aqua_helmet_crack",
    "dune_cadet_radio_1", "dune_land_thump", "dune_jet_burn", "dune_rad_burst",
    "frost_racer_whoop_1", "frost_ski_rush", "frost_yeti_roar", "frost_snowball_hit", "frost_ice_shatter",
    "footstep_1", "player_hurt", "land", "reload_clunk", "wave_start", "final_wave", "wave_clear",
    "portal_open", "level_clear", "purchase", "ui_click", "ui_hover",
]

BANDS = [(20, 45), (45, 80), (80, 150), (150, 600), (600, 2500), (2500, 6000), (6000, 16000)]


# ---------------------------------------------------------------------------
# Loading and measuring
# ---------------------------------------------------------------------------

def load(path):
    """(n, channels) float array at SR."""
    if path.endswith(".wav"):
        with wave.open(path, "rb") as w:
            ch, width, rate = w.getnchannels(), w.getsampwidth(), w.getframerate()
            raw = w.readframes(w.getnframes())
        assert width == 2 and rate == SR, path
        return np.frombuffer(raw, "<i2").astype(np.float64).reshape(-1, ch) / 32768.0
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "s16le", "-ac", "2", "-ar", str(SR), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(out, "<i2").astype(np.float64).reshape(-1, 2) / 32768.0


def _biquad_mag(b, a, freqs):
    z = np.exp(-1j * 2 * np.pi * freqs / SR)
    return np.abs((b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z))


def _k_weight_mag(freqs):
    """|H| of the BS.1770 K-weighting (high shelf +4 dB at 1.5 kHz, high-pass at 38 Hz)."""
    a_lin = 10 ** (4.0 / 40)
    w0 = 2 * np.pi * 1500.0 / SR
    alpha = np.sin(w0) / (2 * (1 / np.sqrt(2)))
    c, s = np.cos(w0), 2 * np.sqrt(a_lin) * alpha
    shelf = _biquad_mag([a_lin * ((a_lin + 1) + (a_lin - 1) * c + s), -2 * a_lin * ((a_lin - 1) + (a_lin + 1) * c),
                         a_lin * ((a_lin + 1) + (a_lin - 1) * c - s)],
                        [(a_lin + 1) - (a_lin - 1) * c + s, 2 * ((a_lin - 1) - (a_lin + 1) * c), (a_lin + 1) - (a_lin - 1) * c - s], freqs)
    w0 = 2 * np.pi * 38.0 / SR
    alpha = np.sin(w0) / (2 * 0.5)
    c = np.cos(w0)
    hp = _biquad_mag([(1 + c) / 2, -(1 + c), (1 + c) / 2], [1 + alpha, -2 * c, 1 - alpha], freqs)
    return shelf * hp


def k_weight(x, loop):
    """Zero-phase K-weighting; loops are filtered circularly (as they play)."""
    pad = 0 if loop else int(0.5 * SR)
    n = len(x) + pad
    spec = np.fft.rfft(x, n, axis=0)
    spec *= _k_weight_mag(np.fft.rfftfreq(n, 1.0 / SR))[:, None]
    return np.fft.irfft(spec, n, axis=0)


def window_ms(x, seconds, hop, loop=False):
    """Mean square per channel over sliding windows: shape (windows, channels)."""
    w = max(1, int(seconds * SR))
    h = max(1, int(hop * SR))
    if loop:
        x = np.concatenate([x, x[:w]])
    if len(x) < w:
        x = np.concatenate([x, np.zeros((w - len(x), x.shape[1]))])
    c = np.concatenate([np.zeros((1, x.shape[1])), np.cumsum(x * x, axis=0)])
    starts = np.arange(0, len(x) - w + 1, h)
    return (c[starts + w] - c[starts]) / w


def db(v):
    return 10 * np.log10(np.maximum(v, 1e-12))


def as_played(x):
    """Mono files play on both channels."""
    return np.repeat(x, 2, axis=1) if x.shape[1] == 1 else x


def measure(path, loop):
    x = as_played(load(path))
    m = {"peak": 20 * np.log10(max(1e-9, np.max(np.abs(x)))), "seconds": len(x) / SR}
    st = db(window_ms(x, 0.1, 0.01, loop).mean(axis=1))
    m["st100"] = float(st.max())
    m["st100_p95"] = float(np.percentile(st, 95))
    k = k_weight(x, loop)
    m["k100"] = float(db(window_ms(k, 0.1, 0.01, loop).mean(axis=1)).max())
    blocks = window_ms(k, 0.4, 0.1, loop).sum(axis=1)
    lufs = -0.691 + db(blocks)
    if loop:
        gated = blocks[lufs > -70]
        rel = -0.691 + db(gated.mean()) - 10
        m["lufs"] = float(-0.691 + db(blocks[(lufs > -70) & (lufs > rel)].mean()))
        m["rms"] = float(db((x * x).mean()))
        m["bands"] = band_energy(x)
    else:
        m["lufs"] = float(lufs.max())
        env = db(window_ms(x, 0.01, 0.005).mean(axis=1))
        active = np.nonzero(env > env.max() - 40)[0]
        a, b = int(active[0] * 0.005 * SR), int(active[-1] * 0.005 * SR + 0.01 * SR)
        m["rms"] = float(db((x[a:b] ** 2).mean()))
    return m


def band_energy(x):
    """Energy per band in dB relative to the total (20 Hz - 16 kHz)."""
    spec = np.abs(np.fft.rfft(x.mean(axis=1))) ** 2
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    total = spec[(f >= 20) & (f < 16000)].sum()
    out = {}
    for lo, hi in BANDS:
        out["%d-%d" % (lo, hi)] = float(db(spec[(f >= lo) & (f < hi)].sum() / total))
    for name, (lo, hi) in {"low": (20, 150), "mid": (600, 2500), "high": (2500, 12000)}.items():
        out[name] = float(db(spec[(f >= lo) & (f < hi)].sum() / total))
    return out


# ---------------------------------------------------------------------------
# The game's side: busses, settings, mix table, call sites, levels
# ---------------------------------------------------------------------------

def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def limiter():
    """Master HardLimiter settings: {"ceiling", "pre_gain"} in dB, or None."""
    text = read("audio/default_bus_layout.tres")
    m = re.search(r'\[sub_resource type="AudioEffect(?:Hard)?Limiter"[^\]]*\](.*?)(?=\n\[|\Z)', text, re.S)
    if not m or "bus/0/effect/0/effect" not in text:
        return None
    ceiling = re.search(r"ceiling_db = (-?[\d.]+)", m.group(1))
    pre = re.search(r"pre_gain_db = (-?[\d.]+)", m.group(1))
    return {"ceiling": float(ceiling.group(1)) if ceiling else -0.3, "pre_gain": float(pre.group(1)) if pre else 0.0}


def bus_gains():
    """Bus name -> total gain to the output at default settings (dB), including
    the Master limiter's pre-gain. Godot applies a bus's effects before its
    volume, so the Master volume (the slider) sits after the limiter."""
    text = read("audio/default_bus_layout.tres")
    busses = {"Master": {"volume": 0.0, "send": None}}
    for idx in sorted(set(re.findall(r"bus/(\d+)/name", text)), key=int):
        name = re.search(r'bus/%s/name = &"(\w+)"' % idx, text).group(1)
        vol = re.search(r"bus/%s/volume_db = (-?[\d.]+)" % idx, text)
        send = re.search(r'bus/%s/send = &"(\w+)"' % idx, text)
        busses[name] = {"volume": float(vol.group(1)) if vol else 0.0, "send": send.group(1) if send else "Master"}
    defaults = dict((k, float(v)) for k, v in re.findall(r'"(\w+_volume)":\s*(-?[\d.]+)', read("scripts/autoload/profile.gd")))
    for bus, key in re.findall(r'_set_bus\("(\w+)", float\(value\("(\w+)"\)\)\)', read("scripts/autoload/settings.gd")):
        if bus in busses and key in defaults:
            busses[bus]["volume"] = 20 * math.log10(max(defaults[key], 0.001))   # the slider replaces it
    lim = limiter()
    busses["Master"]["volume"] += lim["pre_gain"] if lim else 0.0

    def total(name):
        b = busses[name]
        return b["volume"] + (total(b["send"]) if b["send"] in busses and name != "Master" else 0.0)

    return {name: total(name) for name in busses}


def master_slider_db():
    """The Master bus volume at default settings (applied after the limiter)."""
    defaults = dict((k, float(v)) for k, v in re.findall(r'"(\w+_volume)":\s*(-?[\d.]+)', read("scripts/autoload/profile.gd")))
    return 20 * math.log10(max(defaults.get("master_volume", 1.0), 0.001))


def _tres_dict(text, prop):
    m = re.search(r"^%s = (?:Dictionary\[[^\]]*\]\()?\{(.*?)\}" % prop, text, re.M | re.S)
    if not m:
        return {}
    out = {}
    for key, val in re.findall(r'&?"([^"]+)":\s*(&"[^"]*"|-?[\d.]+(?:e-?\d+)?)', m.group(1)):
        out[key] = val[2:-1] if val.startswith("&") else float(val)
    return out


class Mix:
    """Mirror of SoundMix (scripts/data/sound_mix.gd); empty when there is no table."""

    def __init__(self):
        path = os.path.join(ROOT, "audio/mix.tres")
        text = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
        self.gain = _tres_dict(text, "category_gain_db")
        self.bus = _tres_dict(text, "category_bus")
        self.category_of = _tres_dict(text, "sound_category")
        self.trim = _tres_dict(text, "sound_trim_db")
        d = re.search(r'^default_category = &"(\w+)"', text, re.M)
        self.default = d.group(1) if d else "misc"
        sfx = read("scripts/autoload/sfx.gd")
        near = re.search(r"const NEAR_HEADROOM_DB := (-?[\d.]+)", sfx)
        # Before the mix table, play_at left Godot's absolute max_db of +3 dB.
        self.near_headroom = float(near.group(1)) if near else None
        self.present = bool(text)

    def category(self, sound):
        if sound in self.category_of:
            return self.category_of[sound]
        best = ""
        for key in self.category_of:
            if key.endswith("_") and sound.startswith(key) and len(key) > len(best):
                best = key
        return self.category_of[best] if best else self.default

    def gain_db(self, sound):
        return self.gain.get(self.category(sound), 0.0) + self.trim.get(sound, 0.0)

    def bus_of(self, sound):
        return self.bus.get(self.category(sound), "SFX") if self.present else "SFX"

    def max_db(self, volume_db):
        return 3.0 if self.near_headroom is None else volume_db + self.near_headroom


def split_args(s):
    out, depth, cur, quote = [], 0, "", None
    for ch in s:
        if quote:
            cur += ch
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
            continue
        cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def _numbers(expr):
    if expr is None:
        return [0.0]
    expr = expr.strip()
    if re.fullmatch(r"-?[\d.]+", expr):
        return [float(expr)]
    if expr.startswith("lerpf("):
        return [float(v) for v in re.findall(r"-?\d+\.?\d*", expr)[:2]]
    if " if " in expr:
        a, rest = expr.split(" if ", 1)
        b = rest.split(" else ", 1)[1] if " else " in rest else "0"
        return _numbers(a) + _numbers(b)
    nums = [float(v) for v in re.findall(r"(?<![\w.])-?\d+\.\d+|(?<![\w.])-?\d+(?![\w.])", expr)]
    return nums or [0.0]


class Sources:
    """Where sound names come from: data resources, scenes and export defaults."""

    def __init__(self, names):
        self.names = names
        self.texts = {}
        for pattern in ("data/**/*.tres", "scenes/**/*.tscn", "scenes/**/*.tres", "scripts/**/*.gd"):
            for path in glob.glob(os.path.join(ROOT, pattern), recursive=True):
                with open(path, encoding="utf-8") as f:
                    self.texts[os.path.relpath(path, ROOT)] = f.read()

    def field(self, field, dict_only=False, script=None):
        """Sound names assigned to `field`. With `script`, only that script's export
        default and the scenes/resources that use it (a behaviour's own export)."""
        found = set()
        family = self.family(script) if script else set()
        for path, text in self.texts.items():
            is_gd = path.endswith(".gd")
            if script and path != script and (is_gd or not any(("res://" + f) in text for f in family)):
                continue
            if not dict_only and not is_gd:
                for m in re.finditer(r"^%s = (.*)$" % re.escape(field), text, re.M):
                    found.update(re.findall(r'&"(\w+)"', m.group(1)))
            if is_gd and not dict_only and script:
                for m in re.finditer(r"var %s\b[^=\n]*=\s*(.*)$" % re.escape(field), text, re.M):
                    found.update(re.findall(r'&"(\w+)"', m.group(1)))
            if is_gd:
                found.update(re.findall(r'"%s":\s*&"(\w+)"' % re.escape(field), text))
        return found

    def family(self, script):
        """A script and every script that extends it (by path or class_name)."""
        out = {script}
        cls = re.search(r"^class_name (\w+)", self.texts.get(script, ""), re.M)
        for path, text in self.texts.items():
            if path.endswith(".gd") and (('extends "res://%s"' % script) in text
                                         or (cls and re.search(r"^extends %s\b" % cls.group(1), text, re.M))):
                out.add(path)
        return out

    def resolve(self, expr, path, lines, line_no):
        found = set(n for n in re.findall(r'&"(\w+)"', expr) if n)
        m = re.search(r'StringName\("(\w+)"\s*\+', expr)
        if m:
            found.update(n for n in self.names if n.startswith(m.group(1)))
        if '["sound"]' in expr:
            found.update(self.field("sound", dict_only=True))
        for ident in re.findall(r"[A-Za-z_][\w.]*", expr):
            last = ident.split(".")[-1]
            if ident.isupper() or (last.isupper() and "_" in last):
                c = re.search(r'const %s\s*:?=\s*&"(\w+)"' % last, self.texts[path])
                if c:
                    found.add(c.group(1))
            elif last.endswith("_sound") or last.endswith("_sounds"):
                found.update(self.field(last, script=None if "." in ident else path))
            elif ident == "sound":
                for back in range(line_no - 1, max(0, line_no - 20), -1):
                    v = re.search(r"var sound\b[^=]*=\s*(.*)$", lines[back])
                    if v:
                        found.update(self.resolve(v.group(1), path, lines, back))
                        break
            elif ident.endswith(".sound"):
                found.update(self.field("sound"))
        return found


def call_sites(names):
    """sound -> list of {where, vol (max), vol_min, positional, unit}."""
    src = Sources(names)
    sites = {}
    call_re = re.compile(r"\b(Sfx\.play_at|Sfx\.play|_play_on)\s*\(")
    for path, text in src.texts.items():
        if not path.endswith(".gd") or path == "scripts/autoload/sfx.gd":
            continue
        lines = text.split("\n")
        for i, line in enumerate(lines):
            for m in call_re.finditer(line):
                if line.lstrip().startswith("func "):
                    continue
                depth, j = 1, m.end()
                while j < len(line) and depth:
                    depth += {"(": 1, ")": -1}.get(line[j], 0)
                    j += 1
                args = split_args(line[m.end():j - 1])
                kind = m.group(1)
                if kind == "Sfx.play":
                    sound, vol, positional, unit = args[0], args[1] if len(args) > 1 else None, False, 0.0
                elif kind == "Sfx.play_at":
                    sound, vol, positional = args[0], args[2] if len(args) > 2 else None, True
                    unit = float(args[4]) if len(args) > 4 and re.fullmatch(r"[\d.]+", args[4]) else 9.0
                else:
                    sound, vol, positional, unit = args[1], args[2], False, 0.0
                vols = _numbers(vol)
                for name in src.resolve(sound, path, lines, i):
                    sites.setdefault(name, []).append({
                        "where": "%s:%d" % (path, i + 1), "vol": max(vols), "vol_min": min(vols),
                        "positional": positional, "unit": unit, "direct": kind == "_play_on"})
    # Exit portal hum: an AudioStreamPlayer3D in the portal scenes.
    sites.setdefault("portal_hum", []).append({"where": "scenes/props/portal.tscn", "vol": 0.0, "vol_min": 0.0,
                                               "positional": True, "unit": 8.0, "direct": True})
    return sites


def levels():
    defaults = {k: float(v) for k, v in re.findall(r"@export var (\w+_volume_db) := (-?[\d.]+)", read("scripts/data/level_data.gd"))}
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data/levels/*.tres"))):
        if path.endswith("_waves.tres"):
            continue
        text = open(path, encoding="utf-8").read()
        lv = {"id": re.search(r'^id = &"(\w+)"', text, re.M).group(1)}
        for key in ("music", "ambience", "music_final"):
            m = re.search(r'^%s = &"(\w+)"' % key, text, re.M)
            lv[key] = m.group(1) if m else None
        for key in ("music_volume_db", "ambience_volume_db"):
            m = re.search(r"^%s = (-?[\d.]+)" % key, text, re.M)
            lv[key] = float(m.group(1)) if m else defaults.get(key, 0.0)
        out.append(lv)
    menu = re.search(r"play_music\(MENU_MUSIC, (-?[\d.]+)\)", read("scripts/ui/main_menu.gd"))
    out.append({"id": "(menu)", "music": "menu_theme", "music_final": None, "ambience": None,
                "music_volume_db": float(menu.group(1)) if menu else -9.0, "ambience_volume_db": 0.0})
    return out


# ---------------------------------------------------------------------------
# Effective levels
# ---------------------------------------------------------------------------

def near_gain(mix, vol, unit, distance=NEAR_M):
    """Gain Godot gives a positional sound at `distance` (volume_db included)."""
    att = min(mix.max_db(vol), vol + 20 * math.log10(unit / distance))
    return att + 20 * math.log10(1 - distance / MAX_DISTANCE) + PAN_CENTRE_DB


def effective(name, m, sites, mix, busses):
    """Level of the loudest gameplay call of a sound (menus only if nothing else plays it)."""
    calls = [s for s in sites.get(name, []) if not s["where"].startswith(("scripts/ui", "scripts/cosmetics/locker"))] \
        or sites.get(name, [])
    if not calls:
        return None

    def gain_of(site):
        mix_db = 0.0 if site["direct"] else mix.gain_db(name)
        vol = site["vol"] + mix_db
        gain = near_gain(mix, vol, site["unit"]) if site["positional"] else vol
        return gain + busses.get("SFX" if site["direct"] else mix.bus_of(name), 0.0), mix_db

    best = max(calls, key=lambda s: gain_of(s)[0])
    total, mix_db = gain_of(best)
    bus = busses.get("SFX" if best["direct"] else mix.bus_of(name), 0.0)
    return {"call": best["vol"], "mix": mix_db, "bus": bus, "where": best["where"], "pos": best["positional"],
            "direct": best["direct"], "eff": m["st100"] + total, "effK": m["k100"] + total, "outpk": m["peak"] + total}


def base_names():
    names = []
    for path in sorted(glob.glob(os.path.join(ROOT, "audio/sfx/*.wav"))):
        n = os.path.basename(path)[:-4]
        if not re.search(r"_[bcd]$", n):
            names.append(n)
    return names


def report(args):
    mix, busses = Mix(), bus_gains()
    names = base_names()
    sites = call_sites(names)
    rows = []
    wanted = names if args.all or args.csv else [n for n in KEY_SOUNDS if n in names]
    for n in wanted:
        m = measure(os.path.join(ROOT, "audio/sfx/%s.wav" % n), loop=n in ("portal_hum", "weap_cryo_loop"))
        e = effective(n, m, sites, mix, busses)
        rows.append((n, m, e))
    print("Busses at default settings (dB to output): " + ", ".join("%s %.1f" % kv for kv in busses.items()))
    print("Mix table: %s; positional sounds measured at %.0f m in front (near cap: %s)\n" % (
        "audio/mix.tres" if mix.present else "none", NEAR_M,
        "max_db +3 absolute" if mix.near_headroom is None else "volume +%.0f dB" % mix.near_headroom))
    hdr = "%-22s %-15s %6s %6s %6s %6s %6s %6s %4s %7s %7s %6s" % (
        "sound", "category", "peak", "st100", "k100", "call", "mix", "bus", "3D", "eff", "effK", "outpk")
    print(hdr)
    print("-" * len(hdr))
    for n, m, e in rows:
        if e is None:
            print("%-22s %-15s %6.1f %6.1f %6.1f   (no call site)" % (n, mix.category(n), m["peak"], m["st100"], m["k100"]))
            continue
        print("%-22s %-15s %6.1f %6.1f %6.1f %6.1f %6s %6.1f %4s %7.1f %7.1f %6.1f" % (
            n, mix.category(n), m["peak"], m["st100"], m["k100"], e["call"], "n/a" if e["direct"] else "%.1f" % e["mix"],
            e["bus"], "yes" if e["pos"] else "", e["eff"], e["effK"], e["outpk"]))
    print("(mix n/a: played on its own player from Sfx.stream(), outside the mix table)\n")
    loops(mix, busses)
    if args.csv:
        with open(args.csv, "w") as f:
            f.write("sound,category,peak,st100,k100,rms,call,mix,bus,positional,eff,effK,outpk,where\n")
            for n, m, e in rows:
                e = e or dict.fromkeys(("call", "mix", "bus", "pos", "eff", "effK", "outpk", "where"), "")
                f.write("%s,%s,%.2f,%.2f,%.2f,%.2f,%s,%s,%s,%s,%s,%s,%s,%s\n" % (
                    n, mix.category(n), m["peak"], m["st100"], m["k100"], m["rms"], e["call"], e["mix"], e["bus"],
                    e["pos"], e["eff"], e["effK"], e["outpk"], e["where"]))
        print("wrote", args.csv)


def loops(mix, busses):
    print("%-22s %-14s %6s %6s %6s %6s %6s %7s %7s   %s" % (
        "loop", "level", "peak", "st100", "p95", "lufs", "lvl", "eff", "effL", "low/mid/high vs total (dB)"))
    seen = {}
    for lv in levels():
        for kind in ("music", "music_final", "ambience"):
            track = lv.get(kind)
            if not track:
                continue
            path = os.path.join(ROOT, "audio/music/%s.ogg" % track)
            if not os.path.exists(path):
                continue
            if track not in seen:
                seen[track] = measure(path, loop=True)
            m = seen[track]
            lvl = lv["ambience_volume_db" if kind == "ambience" else "music_volume_db"] + mix.gain_db(track)
            bus = busses.get("Ambience" if kind == "ambience" else "Music", 0.0)
            b = m["bands"]
            print("%-22s %-14s %6.1f %6.1f %6.1f %6.1f %6.1f %7.1f %7.1f   %5.1f %5.1f %5.1f" % (
                track, lv["id"], m["peak"], m["st100"], m["st100_p95"], m["lufs"], lvl,
                m["st100_p95"] + lvl + bus, m["lufs"] + lvl + bus, b["low"], b["mid"], b["high"]))
    print("\nSpectra (energy per band relative to the total, dB):")
    print("%-22s " % "loop" + " ".join("%9s" % ("%d-%d" % band) for band in BANDS))
    for track, m in seen.items():
        print("%-22s " % track + " ".join("%9.1f" % m["bands"]["%d-%d" % band] for band in BANDS))


# ---------------------------------------------------------------------------
# Listen-proxy mixdown
# ---------------------------------------------------------------------------

# A scripted 20 s fight per world: (time, sound, distance m or None for 2D, azimuth deg).
COMMON_FIGHT = (
    [(1.0 + k * 0.095, "carbine_fire", None, 0) for k in range(30)]
    + [(1.02 + k * 0.095, "hitmarker", None, 0) for k in range(30) if k % 3 != 2]
    + [(1.03 + k * 0.19, "hit_body", 9.0, -10) for k in range(15)]
    + [(2.0, "kill_confirm", None, 0), (2.0, "zombie_pop", 8.0, -15), (2.9, "kill_confirm", None, 0),
       (2.9, "zombie_pop", 6.0, 20), (3.8, "headshot_ping", None, 0), (3.85, "kill_confirm", None, 0)]
    + [(4.6 + k * 0.32, "pistol_fire", None, 0) for k in range(5)]
    + [(4.62 + k * 0.32, "hitmarker", None, 0) for k in range(4)]
    + [(6.0, "zombie_groan_1", 7.0, -40), (6.5, "runner_screech_1", 10.0, 50), (7.0, "zombie_swipe", 1.8, 0),
       (7.15, "player_hurt", None, 0), (8.6, "scatter_fire", None, 0), (8.62, "kill_confirm", None, 0),
       (8.62, "zombie_pop", 4.0, 0), (9.2, "reload_clunk", None, 0), (10.0, "final_wave", None, 0)]
    + [(11.0 + k * 0.095, "carbine_fire", None, 0) for k in range(36)]
    + [(11.02 + k * 0.095, "hitmarker", None, 0) for k in range(36) if k % 4 != 3]
    + [(12.0, "kill_confirm", None, 0), (13.0, "kill_confirm", None, 0), (13.0, "combo_up", None, 0),
       (12.4, "weap_lobber_boom", 10.0, 30), (14.2, "headshot_ping", None, 0), (14.25, "kill_confirm", None, 0),
       (15.2, "bruiser_roar_1", 12.0, -30), (16.5, "wave_clear", None, 0)]
    + [(1.0 + k * 0.45, "footstep_1" if k % 2 else "footstep_2", None, 0) for k in range(10)]
)
WORLD_FIGHT = {
    "prize_pier": [(5.5, "bruiser_slam", 5.0, 15), (12.8, "runner_screech_2", 6.0, -60)],
    "neon_skyline": [(5.4, "neon_punk_jeer_1", 6.0, -20), (6.2, "neon_spray_hiss", 7.0, 30), (7.6, "neon_shield_block", 6.0, 0),
                     (8.0, "neon_shield_break", 6.0, 0), (12.6, "neon_leap_land", 4.0, 40)],
    "tidal_tunnels": [(5.4, "aqua_octo_gurgle_1", 7.0, -30), (6.2, "aqua_ink_spit", 8.0, 25), (7.4, "aqua_jelly_charge", 5.0, 10),
                      (8.0, "aqua_jelly_zap", 5.0, 10), (12.6, "aqua_helmet_crack", 6.0, 0)],
    "launch_pad": [(5.4, "dune_cadet_radio_1", 7.0, -30), (6.2, "dune_jet_burn", 8.0, 25), (7.4, "dune_geiger", 5.0, 10),
                   (8.0, "dune_rad_burst", 5.0, 10), (12.6, "dune_land_thump", 4.0, -20)],
    "summit_lodge": [(5.4, "frost_racer_whoop_1", 7.0, -30), (6.2, "frost_ski_rush", 6.0, 25), (7.4, "frost_snowball_hit", 3.0, 10),
                     (8.0, "frost_ice_shatter", 6.0, 0), (12.6, "frost_yeti_roar", 9.0, -20)],
}


def _pan(azimuth):
    """Godot's stereo speaker-placement gains (tightness 1) for a source azimuth."""
    src = np.array([math.sin(math.radians(azimuth)), 0.0, -math.cos(math.radians(azimuth))])
    speakers = [np.array([-1, 0, -1]) / math.sqrt(2), np.array([1, 0, -1]) / math.sqrt(2)]
    g = [0.5 * (1 + s.dot(src)) / 1.5 for s in speakers]
    total = math.sqrt(sum(v * v for v in g))
    return np.array([v / total for v in g])


def _limit(x, ceiling_db=-1.0, release=0.1, lookahead=0.0015):
    """Look-ahead peak limiter like the Master bus HardLimiter."""
    ceiling = 10 ** (ceiling_db / 20)
    peak = np.max(np.abs(x), axis=1)
    need = np.minimum(1.0, ceiling / np.maximum(peak, 1e-9))
    la = int(lookahead * SR)
    padded = np.concatenate([need, np.ones(la)])
    stack = np.min(np.stack([padded[k:k + len(need)] for k in range(la + 1)]), axis=0)
    g = np.empty_like(stack)
    coef = math.exp(-1.0 / (release * SR))
    cur = 1.0
    for i, v in enumerate(stack):
        cur = v if v < cur else v + (cur - v) * coef
        g[i] = cur
    return x * g[:, None], g


def mixdown(level_id, out_path, seconds=20.0, switch_at=10.0):
    mix, busses = Mix(), bus_gains()
    names = base_names()
    sites = call_sites(names)
    lv = next(l for l in levels() if l["id"] == level_id)
    n = int(seconds * SR)
    out = np.zeros((n, 2))

    def loop(track, gain_db, start, stop, offset=0.0, fade_in=0.0, fade_out=0.0):
        x = load(os.path.join(ROOT, "audio/music/%s.ogg" % track))
        idx = (np.arange(n) + int(offset * SR)) % len(x)
        y = x[idx] * 10 ** (gain_db / 20)
        t = np.arange(n) / SR
        w = ((t >= start) & (t < stop)).astype(float)
        if fade_in:
            w *= np.clip((t - start) / fade_in, 0, 1) ** 0.5
        if fade_out:
            w *= np.clip((stop - t) / fade_out, 0, 1) ** 0.5
        out[:] += y * w[:, None]

    music_gain = lv["music_volume_db"] + busses["Music"]
    loop(lv["music"], music_gain + mix.gain_db(lv["music"]), 0, switch_at + (0.6 if lv.get("music_final") else seconds),
         fade_out=0.6 if lv.get("music_final") else 0)
    if lv.get("music_final"):
        loop(lv["music_final"], music_gain + mix.gain_db(lv["music_final"]), switch_at, seconds, fade_in=0.6)
    if lv.get("ambience"):
        loop(lv["ambience"], lv["ambience_volume_db"] + busses["Ambience"] + mix.gain_db(lv["ambience"]), 0, seconds)

    cache = {}
    for at, sound, distance, azimuth in COMMON_FIGHT + WORLD_FIGHT.get(level_id, []):
        if sound not in cache:
            cache[sound] = load(os.path.join(ROOT, "audio/sfx/%s.wav" % sound))[:, 0]
        x = cache[sound]
        calls = sites.get(sound) or [{"vol": 0.0, "unit": 9.0, "direct": False}]
        call = max(calls, key=lambda s: s["vol"])
        vol = call["vol"] + mix.gain_db(sound)
        bus = busses.get(mix.bus_of(sound), 0.0)
        if distance is None:
            gains = np.array([1.0, 1.0]) * 10 ** ((vol + bus) / 20)
        else:
            unit = call.get("unit") or 9.0
            att = min(mix.max_db(vol), vol + 20 * math.log10(unit / distance))
            mult = 10 ** (att / 20) * max(0.0, 1 - distance / MAX_DISTANCE)
            gains = _pan(azimuth) * mult * 10 ** (bus / 20)
            if mult < 1.0:
                # Godot's distance high-shelf: -24 dB above 5 kHz as the sound fades.
                spec = np.fft.rfft(x)
                f = np.fft.rfftfreq(len(x), 1.0 / SR)
                shelf = 10 ** ((1 - mult) * -24 / 20)
                spec *= np.where(f > 5000, shelf, 1.0)
                x = np.fft.irfft(spec, len(x))
        i = int(at * SR)
        k = min(len(x), n - i)
        out[i:i + k] += x[:k, None] * gains[None, :]
    # The chain gains include the Master slider, which Godot applies after the limiter.
    master = 10 ** (master_slider_db() / 20)
    lim = limiter()
    pre = out / master
    if lim:
        limited, g = _limit(pre, lim["ceiling"])
    else:
        limited, g = pre, np.ones(n)
    limited = limited * master
    with wave.open(out_path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(limited, -1, 1) * 32767).astype("<i2").tobytes())

    def stats(x, a, b):
        seg = x[int(a * SR):int(b * SR)]
        k = k_weight(seg, loop=False)[: len(seg)]
        blocks = window_ms(k, 0.4, 0.1).sum(axis=1)
        st = db(window_ms(seg, 0.1, 0.01).mean(axis=1))
        return -0.691 + db(blocks.mean()), float(st.max()), float(np.percentile(st, 50))

    print("mixdown %s -> %s" % (level_id, out_path))
    reduction = -20 * np.log10(g)
    if lim:
        print("  limiter in %.1f dBFS peak; output peak %.1f dBFS; reducing %.1f%% of the time (>2 dB: %.1f%%), max %.1f dB" % (
            20 * np.log10(np.max(np.abs(pre))), 20 * np.log10(np.max(np.abs(limited))), 100 * np.mean(reduction > 0.01),
            100 * np.mean(reduction > 2.0), reduction.max()))
    else:
        print("  no limiter: peak %.1f dBFS, %.2f%% of samples clip" % (
            20 * np.log10(np.max(np.abs(limited))), 100 * np.mean(np.max(np.abs(limited), axis=1) >= 1.0)))
    for label, a, b in (("whole 20 s", 0, seconds), ("fight (1-9 s)", 1, 9), ("final wave (11-15 s)", 11, 15),
                        ("music+ambience only (17-20 s)", 17, 20)):
        lufs, st_max, st_med = stats(limited, a, b)
        print("  %-30s %6.1f LUFS   st100 max %6.1f  median %6.1f dBFS" % (label, lufs, st_max, st_med))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true", help="every sound effect, not just the key ones")
    ap.add_argument("--csv", help="write the full table to this CSV file")
    ap.add_argument("--mixdown", nargs=2, metavar=("LEVEL", "OUT_WAV"), help="render a 20 s listen-proxy for a level")
    args = ap.parse_args()
    if args.mixdown:
        mixdown(*args.mixdown)
    else:
        report(args)


if __name__ == "__main__":
    sys.exit(main())
