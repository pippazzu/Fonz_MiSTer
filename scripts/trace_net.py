#!/usr/bin/env python3
"""Follow a wire on the native scan of the main schematic and list junction candidates.

Usage (coordinates are native-scan pixels):

    python scripts/trace_net.py X Y DIR [--turns auto|none] [--max-legs N]
                                [--crops OUTDIR] [--image PATH]

DIR is L, R, U or D. The walker keeps to the wire across plain crossings,
re-centring on it as the scan drifts. When the wire ends it looks for a
single perpendicular continuation (a corner) and turns ("--turns auto",
the default). Where it finds none, or more than one, it stops and reports.

Junction candidates: the drawing marks joins with small open circles. A
19x19 window around a join holds about 145 dark pixels on the native scan,
a plain crossing 95-117 and a bare wire about 60. Every point scoring above
--dot (default 128) is reported with its score. Check each one by eye: a
pin stub, a corner or lettering can also score high. With --crops, a
400x400 crop with the walked path in red is saved for every candidate and
for the end point.

Faint runs: the scan drops out in places, which stops the walk. Restart
from the stop point with a larger --gap and --max-legs 1 (a large gap on a
multi-leg walk can carry the walker past a corner).

Example, IC28 pin 1 to IC100 pin 3 (the IC3B /Q6 net, checked by hand on
6 November 2026):

    python scripts/trace_net.py 11263 4540 U

This is an aid, not a proof. Record the coordinates of anything you rely
on, and confirm it in a crop.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

Image.MAX_IMAGE_PIXELS = None
DIRS = {"L": (-1, 0), "R": (1, 0), "U": (0, -1), "D": (0, 1)}
NAMES = {v: k for k, v in DIRS.items()}


def dark(img, x, y):
    h, w = img.shape
    return 0 <= x < w and 0 <= y < h and img[y, x]


def walk_leg(img, x, y, d, max_gap=12):
    """Walk straight in direction d. Return (end_x, end_y, points)."""
    dx, dy = d
    gap = 0
    pts = []
    last = (x, y)
    h, w = img.shape
    while 10 < x < w - 10 and 10 < y < h - 10:
        win = img[y - 4:y + 5, x] if dx else img[y, x - 4:x + 5]
        k = np.where(win)[0]
        if len(k):
            gap = 0
            c = int(round(k.mean()))
            if abs(c - 4) <= 2:      # stay on our wire, ignore a crossing's bulk
                if dx:
                    y += c - 4
                else:
                    x += c - 4
            pts.append((x, y))
            last = (x, y)
        else:
            gap += 1
            if gap > max_gap:
                break
        x += dx
        y += dy
    return last[0], last[1], pts


def continuation(img, x, y, d):
    """Perpendicular wires leaving the end point (x, y) of a leg walked in d."""
    found = []
    for p in DIRS.values():
        if p == d or p == (-d[0], -d[1]):
            continue
        for off in range(-6, 7):            # the corner can sit a few pixels off
            bx = x + off * d[0]
            by = y + off * d[1]
            run = sum(dark(img, bx + k * p[0], by + k * p[1]) for k in range(6, 26))
            if run >= 16:
                found.append((p, bx, by))
                break
    return found


def dots_on(img, pts, threshold):
    hits = []
    for x, y in pts[::2]:
        s = int(img[y - 9:y + 10, x - 9:x + 10].sum())
        if s > threshold:
            if hits and abs(hits[-1][0] - x) + abs(hits[-1][1] - y) < 25:
                if s > hits[-1][2]:
                    hits[-1] = (x, y, s)
            else:
                hits.append((x, y, s))
    return hits


def save_crop(gray, path, cx, cy, pts, size=400):
    h, w = gray.shape
    x0, y0 = max(cx - size // 2, 0), max(cy - size // 2, 0)
    x1, y1 = min(x0 + size, w), min(y0 + size, h)
    out = Image.fromarray(gray[y0:y1, x0:x1]).convert("RGB")
    dr = ImageDraw.Draw(out)
    for px, py in pts:
        if x0 <= px < x1 and y0 <= py < y1:
            dr.point((px - x0, py - y0), fill=(255, 0, 0))
    dr.ellipse((cx - x0 - 12, cy - y0 - 12, cx - x0 + 12, cy - y0 + 12), outline=(0, 160, 0), width=2)
    out.save(path)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("x", type=int)
    ap.add_argument("y", type=int)
    ap.add_argument("dir", choices=list(DIRS))
    ap.add_argument("--turns", choices=["auto", "none"], default="auto")
    ap.add_argument("--max-legs", type=int, default=20)
    ap.add_argument("--dot", type=int, default=128)
    ap.add_argument("--gap", type=int, default=12,
                    help="largest break in a wire to bridge (raise for faint runs; "
                         "above ~25 it can jump between neighbouring parallel wires)")
    ap.add_argument("--crops")
    ap.add_argument("--image", default=os.path.join("tmp", "trace", "native.png"))
    a = ap.parse_args(argv)

    gray = np.asarray(Image.open(a.image).convert("L"))
    img = gray < 150
    x, y, d = a.x, a.y, DIRS[a.dir]
    # Snap the start onto the nearest wire running in the walk direction.
    for off in sorted(range(-10, 11), key=abs):
        sx, sy = (x, y + off) if d[0] else (x + off, y)
        if all(dark(img, sx + k * d[0], sy + k * d[1]) for k in range(0, 8)):
            x, y = sx, sy
            break
    path = []
    all_hits = []
    for leg in range(a.max_legs):
        ex, ey, pts = walk_leg(img, x, y, d, a.gap)
        path += pts
        hits = dots_on(img, pts, a.dot)
        all_hits += hits
        print(f"leg {leg + 1}: {NAMES[d]} from ({x},{y}) to ({ex},{ey})")
        for hx, hy, s in hits:
            print(f"    junction candidate ({hx},{hy}) score {s}")
        if a.turns == "none":
            break
        nxt = continuation(img, ex, ey, d)
        if len(nxt) != 1:
            why = "no perpendicular wire" if not nxt else "several perpendicular wires"
            print(f"stop at ({ex},{ey}): {why} (pin, junction or text?)")
            break
        d, x, y = nxt[0][0], nxt[0][1] + nxt[0][0][0] * 3, nxt[0][2] + nxt[0][0][1] * 3
    if a.crops:
        os.makedirs(a.crops, exist_ok=True)
        save_crop(gray, os.path.join(a.crops, "end.png"), ex, ey, path)
        for i, (hx, hy, s) in enumerate(all_hits):
            save_crop(gray, os.path.join(a.crops, f"junction{i + 1}_{hx}_{hy}.png"), hx, hy, path)
        print(f"crops written to {a.crops}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
