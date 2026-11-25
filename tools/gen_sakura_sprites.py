# Memotong sheet "Sakura Empress" (latar gelap, 1 gambar per animasi per arah) jadi atlas sel 128x128.
# Pakai: python3 gen_sakura_sprites.py <sheet.png> <out_atlas.png> [preview.png]
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

def make_alpha(path, thr=14.0, sigma=35.0, iters=4):
    img = np.array(Image.open(path).convert("RGB")).astype(np.float32)
    valid = np.ones(img.shape[:2], np.float32)
    bg = np.stack([ndi.median_filter(img[..., c][::4, ::4], size=45) for c in range(3)], -1)
    bg = np.stack([ndi.zoom(bg[..., c], 4, order=1)[: img.shape[0], : img.shape[1]] for c in range(3)], -1)
    for _ in range(iters):
        diff = np.abs(img - bg).max(-1)
        valid = (diff < thr).astype(np.float32)
        valid = ndi.binary_erosion(valid > 0, iterations=2).astype(np.float32)
        w = ndi.gaussian_filter(valid, sigma) + 1e-4
        bg = np.stack([ndi.gaussian_filter(img[..., c] * valid, sigma) / w for c in range(3)], -1)
    diff = np.abs(img - bg).max(-1)
    m = diff > thr
    return img, m, diff


SRC, OUT = sys.argv[1], sys.argv[2]
PREV = sys.argv[3] if len(sys.argv) > 3 else None
CELL = 128
SCALE = 0.40
BASE_Y = 116           # kaki di y=116 dari 128 -> "foot" = 0.90625

img, mask, _ = make_alpha(SRC, thr=26.0)

ROWS = {"idle": (138, 275), "move": (275, 410), "slash": (410, 545), "flower": (545, 675), "hurt": (675, 795), "death": (795, 885)}
COLS = {"down": (135, 458), "up": (490, 805), "side": (1205, 1518)}     # side = grup "Right" (pedang ke kanan = menghadap kanan)
ORDER = ["idle", "move", "slash", "flower", "hurt", "death"]
DIRS = ["down", "up", "side"]


def cut(row, d):
    y0, y1 = ROWS[row]
    x0, x1 = COLS[d]
    m = mask[y0:y1, x0:x1]
    m = ndi.binary_closing(m, iterations=1)
    lab, n = ndi.label(ndi.binary_dilation(m, iterations=3))
    keep = np.zeros(m.shape, bool)
    for k in range(1, n + 1):
        comp = lab == k
        yy, xx = np.where(comp & m)
        if len(yy) < 60:
            continue
        if (yy.min() <= 1 or yy.max() >= m.shape[0] - 2) and len(yy) < 1200:
            continue
        keep |= comp
    keep &= ndi.binary_dilation(m, iterations=1)
    a = (m & keep).astype(np.float32)
    a = ndi.binary_fill_holes(a > 0).astype(np.float32) * np.where(keep, 1.0, 0.0)
    return a, img[y0:y1, x0:x1]


raw, bottoms = {}, {}
for r in ORDER:
    for d in DIRS:
        a, c = cut(r, d)
        ys, xs = np.where(a > 0.5)
        raw[(r, d)] = (a, c, int((xs.min() + xs.max()) // 2))
        bottoms[(r, d)] = ys.max()
ref = {r: float(np.median([bottoms[(r, d)] for d in DIRS])) for r in ORDER}


def render(r, d):
    a, c, mid = raw[(r, d)]
    h, w = a.shape
    pm = np.dstack([c * a[..., None], a * 255.0]).astype(np.float32)
    nw, nh = int(round(w * SCALE)), int(round(h * SCALE))
    ch = [np.array(Image.fromarray(pm[..., i]).resize((nw, nh), Image.LANCZOS)).astype(np.float32) for i in range(4)]
    al = np.clip(ch[3], 0, 255)
    col = np.dstack(ch[:3]) / np.maximum(al[..., None] / 255.0, 1e-3)
    out = np.dstack([np.clip(col, 0, 255), np.where(al > 110, 255, 0)]).astype(np.uint8)
    spr = Image.fromarray(out, "RGBA")
    cell = Image.new("RGBA", (CELL, CELL))
    px = int(round(CELL / 2 - mid * SCALE))
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
    sheet = Image.new("RGB", (CELL * 3, CELL * 6))
    for k in range(18):
        sheet.paste(bg.crop((0, k * CELL, CELL, (k + 1) * CELL)).convert("RGB"), ((k % 3) * CELL, (k // 3) * CELL))
    sheet.save(PREV)
