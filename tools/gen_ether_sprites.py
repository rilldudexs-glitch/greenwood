# Memotong sheet "Ether Sovereign" (4 panel arah, 5 frame per animasi) jadi atlas sel 96x96 (5 frame per baris).
# Pakai: python3 gen_ether_sprites.py <sheet.png> <out_atlas.png> [preview.png]
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
CELL = 96
SCALE = 0.62
BASE_Y = 90            # kaki di y=90 dari 96 -> "foot" = 0.9375
NF = 5

img, mask, _ = make_alpha(SRC, thr=14.0)

TOP = {"idle": (198, 326), "attack": (330, 466), "death": (466, 576)}
BOT = {"idle": (628, 752), "attack": (756, 876), "death": (878, 996)}
# arah -> (baris y, pusat frame x). down = panel "Down", up = panel "Up", side = panel "Right" (menghadap kanan).
GROUPS = {
    "down": (TOP, [957, 1082, 1208, 1335, 1457]),
    "up": (TOP, [188, 315, 440, 568, 690]),
    "side": (BOT, [957, 1085, 1210, 1335, 1457]),
}
HALF = 62
ORDER = [("idle", 6.0, True), ("attack", 9.0, False), ("death", 5.0, False)]
DIRS = ["down", "up", "side"]


def refine(cx, y0, y1):
    for _ in range(3):
        m = mask[y0:y1, cx - HALF: cx + HALF]
        xs = np.where(m)[1]
        if len(xs) < 50:
            break
        cx = int(cx - HALF + xs.mean())
    return cx


def cut(y0, y1, cx):
    x0, x1 = cx - HALF, cx + HALF
    m = mask[y0:y1, x0:x1]
    lab, n = ndi.label(ndi.binary_dilation(m, iterations=2))
    keep = np.zeros(m.shape, bool)
    mid = cx - x0
    for k in range(1, n + 1):
        comp = lab == k
        yy, xx = np.where(comp & m)
        if len(yy) < 20 or (xx.max() - xx.min() <= 4 and yy.max() - yy.min() > 30):
            continue
        body = comp[int(m.shape[0] * 0.35):, max(mid - 14, 0):mid + 14].any()
        edge = xx.min() <= 1 or xx.max() >= m.shape[1] - 2 or yy.min() <= 0 or yy.max() >= m.shape[0] - 1
        if body or not edge:
            keep |= comp
    a = ndi.binary_fill_holes(m & keep).astype(np.float32)
    return a, img[y0:y1, x0:x1]


def sprite(a, c):
    h, w = a.shape
    pm = np.dstack([c * a[..., None], a * 255.0]).astype(np.float32)
    nw, nh = int(round(w * SCALE)), int(round(h * SCALE))
    ch = [np.array(Image.fromarray(pm[..., i]).resize((nw, nh), Image.LANCZOS)).astype(np.float32) for i in range(4)]
    al = np.clip(ch[3], 0, 255)
    col = np.dstack(ch[:3]) / np.maximum(al[..., None] / 255.0, 1e-3)
    out = np.dstack([np.clip(col, 0, 255), np.where(al > 110, 255, 0)]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


raw = {}
for name, _, _ in ORDER:
    for d in DIRS:
        rows, cxs = GROUPS[d]
        y0, y1 = rows[name]
        bots, items = [], []
        for cx0 in cxs:
            cx = refine(cx0, y0, y1)
            a, c = cut(y0, y1, cx)
            ys, _ = np.where(a > 0.5)
            items.append((a, c))
            bots.append(ys.max() if len(ys) else 0)
        raw[(name, d)] = (items, float(np.median(bots)))

rows_out = []
for name, fps, loop in ORDER:
    for d in DIRS:
        items, ref = raw[(name, d)]
        cells = []
        for a, c in items:
            spr = sprite(a, c)
            cell = Image.new("RGBA", (CELL, CELL))
            px = CELL // 2 - spr.width // 2
            py = int(round(BASE_Y - ref * SCALE))
            sx0, sy0 = max(0, -px), max(0, -py)
            dx0, dy0 = max(0, px), max(0, py)
            ww, hh = min(spr.width - sx0, CELL - dx0), min(spr.height - sy0, CELL - dy0)
            if ww > 0 and hh > 0:
                cell.alpha_composite(spr.crop((sx0, sy0, sx0 + ww, sy0 + hh)), (dx0, dy0))
            cells.append(cell)
        rows_out.append((f"{name}_{d}", len(cells), fps, loop, cells))

atlas = Image.new("RGBA", (CELL * NF, CELL * len(rows_out)))
for r, (nm, n, fps, loop, cells) in enumerate(rows_out):
    print(nm, r, n, fps, loop)
    for i, c in enumerate(cells):
        atlas.alpha_composite(c, (i * CELL, r * CELL))
atlas.save(OUT)
if PREV:
    bg = Image.new("RGBA", atlas.size, (60, 60, 70, 255))
    bg.alpha_composite(atlas)
    bg.resize((atlas.width * 2, atlas.height * 2), Image.NEAREST).convert("RGB").save(PREV)
