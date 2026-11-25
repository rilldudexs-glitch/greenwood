# Memotong sheet "The Unwritten" (1 gambar per animasi per arah) jadi atlas sel 128x128.
# Pakai: python3 gen_unwritten.py <sheet.png> <out_atlas.png> [preview.png]
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SRC, OUT = sys.argv[1], sys.argv[2]
PREV = sys.argv[3] if len(sys.argv) > 3 else None
CELL = 128
SCALE = 0.40
BASE_Y = 116           # dasar jubah di y=116 -> "foot" = 116/128 di boss_sprites.gd

im = np.array(Image.open(SRC).convert("RGBA")).astype(np.float32)
alpha = np.clip((im[..., 3] - 110.0) / 90.0, 0.0, 1.0)
rgb = im[..., :3]

ROWS = {"idle": (125, 275), "move": (278, 412), "melee": (414, 558), "cast": (558, 718), "hurt": (720, 862), "death": (864, 1010)}
COLX = {"down": 304, "up": 658, "side": 1017}      # side = grup berlabel "Left" (menghadap kiri)
HALF = {"down": 160, "up": 160, "side": 160}
ORDER = ["idle", "move", "melee", "cast", "hurt", "death"]
DIRS = ["down", "up", "side"]


def cut(row, d):
    y0, y1 = ROWS[row]
    cx = COLX[d]
    x0, x1 = cx - HALF[d], cx + HALF[d]
    a = alpha[y0:y1, x0:x1].copy()
    lab, n = ndi.label(ndi.binary_dilation(a > 0.5, iterations=4))
    keep = np.zeros(a.shape, bool)
    for k in range(1, n + 1):
        comp = lab == k
        yy, xx = np.where(comp & (a > 0.5))
        if len(yy) < 30:
            continue
        # serpihan baris tetangga menempel di tepi atas/bawah pita
        if (yy.min() <= 1 or yy.max() >= a.shape[0] - 2) and len(yy) < 900:
            continue
        keep |= comp
    return a * keep, rgb[y0:y1, x0:x1], x0, y0


raw = {}
bottoms = {}
for r in ORDER:
    for d in DIRS:
        a, c, x0, y0 = cut(r, d)
        ys, xs = np.where(a > 0.5)
        raw[(r, d)] = (a, c, x0, y0)
        bottoms[(r, d)] = ys.max()
# dasar per baris = median keempat arah, supaya posisi vertikal antar arah konsisten
ref = {r: float(np.median([bottoms[(r, d)] for d in DIRS])) for r in ORDER}


def render(r, d):
    a, c, x0, y0 = raw[(r, d)]
    h, w = a.shape
    pm = np.dstack([c * a[..., None], a * 255.0]).astype(np.float32)
    nw, nh = int(round(w * SCALE)), int(round(h * SCALE))
    ch = [np.array(Image.fromarray(pm[..., i]).resize((nw, nh), Image.LANCZOS)).astype(np.float32) for i in range(4)]
    al = np.clip(ch[3], 0, 255)
    col = np.dstack(ch[:3]) / np.maximum(al[..., None] / 255.0, 1e-3)
    out = np.dstack([np.clip(col, 0, 255), np.where(al > 96, 255, 0)]).astype(np.uint8)
    spr = Image.fromarray(out, "RGBA")
    cell = Image.new("RGBA", (CELL, CELL))
    px = CELL // 2 - nw // 2
    py = int(round(BASE_Y - ref[r] * SCALE))
    sx0, sy0 = max(0, -px), max(0, -py)
    dx0, dy0 = max(0, px), max(0, py)
    ww, hh = min(nw - sx0, CELL - dx0), min(nh - sy0, CELL - dy0)
    if ww > 0 and hh > 0:
        cell.alpha_composite(spr.crop((sx0, sy0, sx0 + ww, sy0 + hh)), (dx0, dy0))
    return cell


atlas = Image.new("RGBA", (CELL, CELL * len(ORDER) * len(DIRS)))
i = 0
for r in ORDER:
    for d in DIRS:
        atlas.alpha_composite(render(r, d), (0, i * CELL))
        print(f"{r}_{d} {i}")
        i += 1
atlas.save(OUT)
if PREV:
    bg = Image.new("RGBA", atlas.size, (60, 60, 70, 255))
    bg.alpha_composite(atlas)
    # contact sheet: 3 kolom (arah) x 6 baris
    sheet = Image.new("RGB", (CELL * 3, CELL * 6))
    for k in range(18):
        sheet.paste(bg.crop((0, k * CELL, CELL, (k + 1) * CELL)).convert("RGB"), ((k % 3) * CELL, (k // 3) * CELL))
    sheet.save(PREV)
