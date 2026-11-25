# Memotong sheet "Myconid King" (4 arah, 4 frame per animasi; pakai blok atas sheet) jadi atlas sel 96x96.
# Pakai: python3 gen_myconid_sprites.py <sheet.png> <out_atlas.png> [preview.png]
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
SCALE = 0.75
BASE_Y = 90            # kaki di y=90 dari 96 -> "foot" = 0.9375

img, mask, _ = make_alpha(SRC, thr=14.0)
for sx in (463, 796, 1164):      # garis pemisah kolom pada sheet
    mask[:, sx - 3: sx + 3] = False

ROWS = {"idle": (214, 322), "attack": (336, 462), "death": (478, 584)}
# pusat tiap frame (x di sheet). Arah: down = kolom "Down" (depan), up = kolom "Up" (belakang), side = kolom "Right".
CX = {
    "down": [505, 585, 665, 745],
    "up": [160, 238, 320, 400],
    "side": [1210, 1290, 1370, 1455],
}
HALF = {"idle": 42, "attack": 46, "death": 44}
ORDER = [("idle", 5.0, True), ("attack", 8.0, False), ("death", 4.0, False)]
DIRS = ["down", "up", "side"]


GROUP_X = {"down": (470, 790), "up": (130, 450), "side": (1170, 1512)}


def centers(row, d):
    """Pusat tiap sprite dari proyeksi topi (bagian atas baris); kembali ke grid tetap kalau tidak ketemu 4."""
    y0, _ = ROWS[row]
    gx0, gx1 = GROUP_X[d]
    band = mask[y0: y0 + 52, gx0:gx1]
    band = ndi.binary_opening(band, structure=np.ones((1, 3)))
    prof = band.sum(0) > 1
    runs, st = [], None
    for i, v in enumerate(prof):
        if v and st is None:
            st = i
        if (not v) and st is not None:
            runs.append((st, i)); st = None
    if st is not None:
        runs.append((st, len(prof)))
    runs = [r for r in runs if r[1] - r[0] >= 30]
    if row != "death" and len(runs) == 4:
        return [gx0 + (a + b) // 2 for a, b in runs]
    return CX[d]


def cut(row, cx):
    y0, y1 = ROWS[row]
    hw = HALF[row]
    x0, x1 = cx - hw, cx + hw
    m = mask[y0:y1, x0:x1]
    lab, n = ndi.label(ndi.binary_dilation(m, iterations=2))
    keep = np.zeros(m.shape, bool)
    mid = cx - x0
    for k in range(1, n + 1):
        comp = lab == k
        yy, xx = np.where(comp & m)
        if len(yy) < 20 or (xx.max() - xx.min() <= 4 and yy.max() - yy.min() > 30):
            continue        # buang garis pemisah tipis di sheet
        body = comp[int(m.shape[0] * 0.35):, max(mid - 12, 0):mid + 12].any()
        edge = xx.min() <= 1 or xx.max() >= m.shape[1] - 2
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
        bots = []
        for cx in centers(name, d):
            a, c = cut(name, cx)
            ys, _ = np.where(a > 0.5)
            raw[(name, d, cx)] = (a, c)
            bots.append(ys.max() if len(ys) else 0)
        raw[(name, d, "ref")] = float(np.median(bots))

rows = []
for name, fps, loop in ORDER:
    for d in DIRS:
        cells = []
        for cx in centers(name, d):
            a, c = raw[(name, d, cx)]
            spr = sprite(a, c)
            cell = Image.new("RGBA", (CELL, CELL))
            px = CELL // 2 - spr.width // 2
            py = int(round(BASE_Y - raw[(name, d, "ref")] * SCALE))
            sx0, sy0 = max(0, -px), max(0, -py)
            dx0, dy0 = max(0, px), max(0, py)
            ww, hh = min(spr.width - sx0, CELL - dx0), min(spr.height - sy0, CELL - dy0)
            if ww > 0 and hh > 0:
                cell.alpha_composite(spr.crop((sx0, sy0, sx0 + ww, sy0 + hh)), (dx0, dy0))
            cells.append(cell)
        rows.append((f"{name}_{d}", len(cells), fps, loop, cells))

atlas = Image.new("RGBA", (CELL * 4, CELL * len(rows)))
for r, (nm, n, fps, loop, cells) in enumerate(rows):
    print(nm, r, n, fps, loop)
    for i, c in enumerate(cells):
        atlas.alpha_composite(c, (i * CELL, r * CELL))
atlas.save(OUT)
if PREV:
    bg = Image.new("RGBA", atlas.size, (60, 60, 70, 255))
    bg.alpha_composite(atlas)
    bg.resize((atlas.width * 2, atlas.height * 2), Image.NEAREST).convert("RGB").save(PREV)
