#!/usr/bin/env python3
"""Port of the Windows BetterVR launcher's Graphics-pack resolution fill (launcher/main.cpp).
Usage: make_graphics_pack.py <src BreathOfTheWild_Graphics dir> <dst dir> <eyeW> <eyeH>"""
import math, shutil, sys
from pathlib import Path

ALIGN, RADIUS, PREF_DIST, MIN_W, MIN_H = 8, 32, 32.0, 1280.0, 720.0
RULES = [(640,368,8.0,0.49),(640,360,8.0,0.0),(384,192,7.0,0.0),(320,192,7.0,0.0),(320,180,7.0,0.0),
         (192,96,6.0,0.0),(160,96,6.0,0.0),(160,90,6.0,0.0),(128,48,5.0,0.0),(96,48,5.0,0.0),(80,45,4.0,0.0),(64,64,4.0,0.0)]
PRESETS = [("05",0.5),("075",0.75),("10",1.0),("125",1.25),("15",1.5),("175",1.75),("20",2.0),("225",2.25),("30",3.0)]

def dist_int(v): return abs(v - round(v))
def penalty(w, h):
    return sum((dist_int(w/1280.0*rw) + dist_int(h/720.0*rh + hb)) * wt for rw, rh, wt, hb in RULES)
def align_down(v, a): return v - v % a
def nearest(width, height):
    s = max(1.0, MIN_W/width, MIN_H/height); width *= s; height *= s
    ev = lambda cw, ch: (cw, ch, math.hypot(cw-width, ch-height), penalty(cw, ch))
    tw, th = max(1, round(width)), max(1, round(height))
    target = best = ev(tw, th)
    sw = max(ALIGN, align_down(tw-RADIUS if tw > RADIUS else ALIGN, ALIGN))
    sh = max(ALIGN, align_down(th-RADIUS if th > RADIUS else ALIGN, ALIGN))
    for cw in range(sw, tw+RADIUS+1, ALIGN):
        for ch in range(sh, th+RADIUS+1, ALIGN):
            c = ev(cw, ch)
            if c[2] <= PREF_DIST and (c[3] < best[3] or (c[3] == best[3] and c[2] < best[2])): best = c
    return (best[0], best[1]) if best[3] < target[3] else (target[0], target[1])

src, dst, ew, eh = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
if dst.exists(): shutil.rmtree(dst)
shutil.copytree(src, dst)
rules = (dst/"rules.txt").read_text()
for key, mult in PRESETS:
    w, h = nearest(ew*mult, eh*mult)
    print(f"{mult}x -> {w}x{h}")
    rules = rules.replace(f"__BETTERVR_{key}_NAME__", f"{w}x{h}").replace(f"__BETTERVR_{key}_WIDTH__", str(w)).replace(f"__BETTERVR_{key}_HEIGHT__", str(h))
(dst/"rules.txt").write_text(rules)
