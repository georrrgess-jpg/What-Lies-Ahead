#!/usr/bin/env python3
"""Frame-to-frame motion report for a rendered video (the showreel's stutter check).

    python3 tools/video_motion_report.py media/what-lies-ahead-showreel.mp4 \
        [--shots build/showreel/shots.txt] [--from S] [--to S] [--json out.json] [--list]

Decodes the video small and grey (320x180, inside the letterbox bars), then for
every pair of frames measures:

    energy   mean absolute difference (0-255): how much of the picture changed
    flow     the camera's motion in pixels at 320 px wide: phase correlation on a
             4x3 grid of tiles; `pan` is the median tile shift (a pan or tilt),
             `flow` the mean tile shift length (also catches dollies and zooms)
    residual the difference left after undoing the pan: actors and effects

and flags the frames a viewer reads as a stutter:

    dup      a repeated frame: the picture stops for one frame inside a move
    freeze   the camera stops for one frame (or jumps back) inside a move
    jump     the camera's speed spikes or drops for one frame (a hitch)
    jerk     the camera's speed changes sharply and stays changed (a velocity
             step: a move that starts or stops without easing, a whip's edge)
    step     part of the picture holds still for a frame while it moves on the
             frames either side (actors stepping on a slower tick)
    cut-hold the first frames after a cut repeat (a load hitch at the cut)

Cuts are found from the picture (or taken from --shots, the
"SHOT <index> <id> <start> <length>" list tools/render_showreel.sh writes) and
the frame pairs across a cut are not judged. Flagged frames come with their
time and shot, so they can be pulled out with ffmpeg and looked at.
"""
import argparse
import json
import subprocess
import sys

import numpy as np

W, H = 320, 180
# The letterbox bars are 96 of 1080 lines: judge only the picture between them.
BAR = 18
GRID = (4, 3)


def decode(path, start, end):
    cmd = ["ffmpeg", "-nostdin", "-v", "error"]
    if start > 0:
        cmd += ["-ss", str(start)]
    cmd += ["-i", path]
    if end > 0:
        cmd += ["-t", str(end - start)]
    cmd += ["-vf", "scale=%d:%d:flags=area,format=gray" % (W, H), "-f", "rawvideo", "-"]
    raw = subprocess.run(cmd, check=True, stdout=subprocess.PIPE).stdout
    frames = np.frombuffer(raw, np.uint8).reshape(-1, H, W)
    return frames[:, BAR:H - BAR, :].astype(np.float32)


def fps_of(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                          "stream=r_frame_rate", "-of", "csv=p=0", path], check=True,
                         stdout=subprocess.PIPE, text=True).stdout.strip()
    num, den = out.split("/")
    return float(num) / float(den)


def _window(h, w):
    return np.outer(np.hanning(h), np.hanning(w)).astype(np.float32)


def _subpixel(c, i, n):
    """Parabolic peak refinement along one axis."""
    a, b, d = c[(i - 1) % n], c[i], c[(i + 1) % n]
    den = a - 2 * b + d
    return 0.0 if abs(den) < 1e-9 else 0.5 * (a - d) / den


def shift(a, b, win):
    """Translation of b relative to a (pixels) and the correlation peak height."""
    a = (a - a.mean()) * win
    b = (b - b.mean()) * win
    fa, fb = np.fft.rfft2(a), np.fft.rfft2(b)
    cross = fb * np.conj(fa)
    cross /= np.abs(cross) + 1e-6
    corr = np.fft.irfft2(cross, s=a.shape)
    iy, ix = np.unravel_index(np.argmax(corr), corr.shape)
    h, w = corr.shape
    dy = iy + _subpixel(corr[:, ix], iy, h)
    dx = ix + _subpixel(corr[iy, :], ix, w)
    if dy > h / 2:
        dy -= h
    if dx > w / 2:
        dx -= w
    return np.array([dx, dy]), float(corr[iy, ix])


def measure(frames):
    n, h, w = frames.shape
    th, tw = h // GRID[1], w // GRID[0]
    win = _window(th, tw)
    full_win = _window(h, w)
    energy = np.zeros(n)
    pan = np.zeros((n, 2))
    flow = np.zeros(n)
    peak = np.zeros(n)
    residual = np.zeros(n)
    tiles = np.zeros((n, GRID[0] * GRID[1]))
    for i in range(1, n):
        a, b = frames[i - 1], frames[i]
        d = np.abs(b - a)
        energy[i] = d.mean()
        shifts = []
        for ty in range(GRID[1]):
            for tx in range(GRID[0]):
                s, _ = shift(a[ty * th:(ty + 1) * th, tx * tw:(tx + 1) * tw],
                             b[ty * th:(ty + 1) * th, tx * tw:(tx + 1) * tw], win)
                shifts.append(s)
        shifts = np.array(shifts)
        pan[i] = np.median(shifts, axis=0)
        flow[i] = np.linalg.norm(shifts, axis=1).mean()
        _, peak[i] = shift(a, b, full_win)
        sx, sy = int(round(pan[i][0])), int(round(pan[i][1]))
        moved = np.roll(np.roll(a, sy, axis=0), sx, axis=1)
        m = 8
        r = np.abs(b - moved)[m:-m, m:-m]
        residual[i] = r.mean()
        rt = r[: (h - 2 * m) // GRID[1] * GRID[1], : (w - 2 * m) // GRID[0] * GRID[0]]
        rt = rt.reshape(GRID[1], rt.shape[0] // GRID[1], GRID[0], rt.shape[1] // GRID[0])
        tiles[i] = rt.mean(axis=(1, 3)).ravel()
    return energy, pan, flow, peak, residual, tiles


def find_cuts(energy, peak, fps, shots, t0):
    cuts = set()
    if shots:
        for _, _, start, _ in shots:
            f = int(round((start - t0) * fps))
            if 0 < f < len(energy):
                cuts.add(f)
    for i in range(1, len(energy)):
        if energy[i] > 22.0 and peak[i] < 0.08:
            cuts.add(i)
    return sorted(cuts)


def shot_at(shots, t):
    for idx, sid, start, length in shots:
        if start <= t < start + length:
            return sid
    return "-"


def analyse(path, shots, start, end):
    fps = fps_of(path)
    frames = decode(path, start, end)
    energy, pan, flow, peak, residual, tiles = measure(frames)
    n = len(frames)
    cuts = find_cuts(energy, peak, fps, shots, start)
    near_cut = np.zeros(n, bool)
    near_cut[0:2] = True
    near_cut[-1:] = True
    for c in cuts:
        near_cut[max(0, c - 1):min(n, c + 2)] = True
    speed = np.linalg.norm(pan, axis=1)
    flags = []

    def flag(i, kind, value, note=""):
        t = start + i / fps
        flags.append({"frame": i, "time": round(t, 3), "shot": shot_at(shots, t), "kind": kind,
                      "value": round(float(value), 2), "note": note})

    for i in range(2, n - 2):
        if near_cut[i] or near_cut[i - 1] or near_cut[i + 1]:
            continue
        e0, e1, e2 = energy[i - 1], energy[i], energy[i + 1]
        f0, f1, f2 = flow[i - 1], flow[i], flow[i + 1]
        if e1 < 0.35 and min(e0, e2) > 2.0:
            flag(i, "dup", e1, "repeated frame inside a move")
            continue
        around = 0.5 * (f0 + f2)
        if around > 1.2 and f1 < 0.3 * min(f0, f2):
            flag(i, "freeze", f1, "camera stops for a frame (%.1f px around)" % around)
            continue
        # Speed spike or drop for one frame (both neighbours agree, this one does not).
        dev = f1 - around
        if around > 0.6 and abs(dev) > max(1.0, 0.5 * around) and abs(f0 - f2) < 0.35 * around + 0.5:
            flag(i, "jump", dev, "camera speed %.1f px vs %.1f around" % (f1, around))
            continue
        # A lasting step in speed: acceleration far above the move's own.
        acc = np.abs(np.diff(flow[i - 2:i + 3]))
        step_ = abs(f2 - f0)
        if step_ > max(2.5, 0.7 * max(f0, f2)) and acc.max() > 2.0 * (np.median(acc) + 0.3):
            flag(i, "jerk", step_, "camera speed %.1f -> %.1f px/frame" % (f0, f2))
            continue
        r0, r1, r2 = tiles[i - 1], tiles[i], tiles[i + 1]
        held = (r1 < 0.3 * np.minimum(r0, r2)) & (np.minimum(r0, r2) > 4.0)
        if held.sum() >= 2:
            flag(i, "step", held.sum(), "%d tiles hold still for a frame" % held.sum())
    for c in cuts:
        if c + 2 < n and energy[c + 1] < 0.35 and energy[c + 2] > 1.5:
            flag(c + 1, "cut-hold", energy[c + 1], "the first frame after the cut repeats")
    # Merge the per-frame flags into one per adjacent run (a 2-frame jerk is one event).
    events = []
    for f in flags:
        if events and events[-1]["kind"] == f["kind"] and f["frame"] - events[-1]["frame"] <= 2:
            continue
        events.append(f)
    per_shot = {}
    for idx, sid, s0, ln in shots:
        a = int(round((max(s0, start) - start) * fps)) + 2
        b = int(round((min(s0 + ln, start + len(frames) / fps) - start) * fps)) - 1
        if b - a < 4:
            continue
        seg = flow[a:b]
        acc = np.abs(np.diff(seg))
        per_shot[sid] = {"start": s0, "mean_flow": round(float(seg.mean()), 2),
                         "max_flow": round(float(seg.max()), 2),
                         "max_accel": round(float(acc.max()), 2),
                         "p95_accel": round(float(np.percentile(acc, 95)), 2),
                         "events": sum(1 for e in events if e["shot"] == sid)}
    return {"video": path, "fps": fps, "frames": n, "from": start, "cuts": len(cuts),
            "events": events, "counts": _counts(events), "shots": per_shot,
            "mean_speed": round(float(speed.mean()), 2)}


def _counts(events):
    out = {}
    for e in events:
        out[e["kind"]] = out.get(e["kind"], 0) + 1
    return out


def read_shots(path):
    shots = []
    if not path:
        return shots
    with open(path) as f:
        for line in f:
            p = line.split()
            if len(p) == 5 and p[0] == "SHOT":
                shots.append((int(p[1]), p[2], float(p[3]), float(p[4])))
    return shots


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("video")
    ap.add_argument("--shots", default="")
    ap.add_argument("--from", dest="start", type=float, default=0.0)
    ap.add_argument("--to", dest="end", type=float, default=0.0)
    ap.add_argument("--json", default="")
    ap.add_argument("--list", action="store_true", help="print every flagged event")
    args = ap.parse_args()
    shots = read_shots(args.shots)
    rep = analyse(args.video, shots, args.start, args.end)
    print("%s: %d frames at %g fps, %d cuts" % (rep["video"], rep["frames"], rep["fps"], rep["cuts"]))
    print("flagged events: %d %s" % (len(rep["events"]), json.dumps(rep["counts"])))
    if rep["shots"]:
        print("%-16s %6s %6s %6s %7s %7s %6s" % ("shot", "start", "flow", "max", "accel", "p95acc", "flags"))
        for sid, s in rep["shots"].items():
            print("%-16s %6.1f %6.2f %6.2f %7.2f %7.2f %6d" % (sid, s["start"], s["mean_flow"], s["max_flow"],
                                                            s["max_accel"], s["p95_accel"], s["events"]))
    if args.list:
        for e in rep["events"]:
            print("  %7.3f s  f%-5d %-14s %-8s %7.2f  %s" % (e["time"], e["frame"], e["shot"], e["kind"], e["value"], e["note"]))
    if args.json:
        with open(args.json, "w") as f:
            json.dump(rep, f, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
