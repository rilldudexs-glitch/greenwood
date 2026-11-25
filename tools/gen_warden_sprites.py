# Memotong sheet "Warden of Shadows" (gambar presentasi) jadi atlas sel 64x64 untuk bos.
# Pakai: python3 gen_warden.py <sheet.png> <out_atlas.png> [preview.png]
import sys
import numpy as np
from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]
PREV = sys.argv[3] if len(sys.argv) > 3 else None
CELL = 64
SCALE = 0.44          # sheet asli ~112px tinggi -> ~49px di sel 64
FOOT = 61             # kaki di y=61 (sama dengan SPRITE_FOOT di boss.gd: 61/64)

im = np.array(Image.open(SRC).convert("RGBA")).astype(np.float32)
A = im[..., 3]
# alpha sheet berbulu (glow); buang halo supaya tepi sprite bersih
alpha = np.clip((A - 110.0) / 90.0, 0.0, 1.0)
rgb = im[..., :3]

ROWS = {"idle": (140, 280), "move": (285, 412), "melee": (414, 548), "cast": (552, 695), "hurt": (698, 845), "death": (850, 1000)}
# pusat kolom tiap frame: (arah) -> daftar x. "side" = grup yang aslinya menghadap KANAN (berlabel "Left" di sheet).
CX = {
    "idle":  {"down": [165, 252, 337, 419], "up": [552, 631, 709, 788], "side": [921, 1009, 1098]},
    "move":  {"down": [165, 252, 337, 419], "up": [552, 631, 709, 788], "side": [915, 1005, 1100]},
    "melee": {"down": [160, 255, 350, 440], "up": [556, 635, 715, 800], "side": [925, 1000, 1098]},
    "cast":  {"down": [160, 258, 348, 445], "up": [558, 800], "side": [934]},
    "hurt":  {"down": [165, 255, 340, 425], "up": [562, 639, 720, 795], "side": [926, 1015, 1107]},
    "death": {"down": [165, 262, 350, 450], "up": [555, 639, 715, 812], "side": [925, 1028, 1136]},
}
# frame tambahan yang dibalik (grup yang aslinya menghadap kiri): cast sisi
FLIP = {"cast": {"side": [1383, 1484]}}
# lebar jendela potong (kiri, kanan) dalam px sheet; efek tebasan butuh lebih lebar ke kanan
WIN = {"melee": (44, 80), "cast": (46, 52)}
ORDER = [("idle", 5.0, True), ("move", 8.0, True), ("melee", 8.0, False), ("cast", 6.0, False), ("hurt", 1.0, False), ("death", 5.0, False)]
DIRS = ["down", "up", "side"]


def frame(row, cx, flip=False):
    y0, y1 = ROWS[row]
    L, R = WIN.get(row, (44, 44))
    x0, x1 = int(cx - L), int(cx + R)
    a = alpha[y0:y1, x0:x1].copy()
    c = rgb[y0:y1, x0:x1]
    # buang serpihan frame tetangga: komponen yang menyentuh tepi jendela dan jauh dari badan
    from scipy import ndimage as ndi
    lab, n = ndi.label(ndi.binary_dilation(a > 0.5, iterations=3))
    keep = np.zeros_like(a, dtype=bool)
    hh, ww = a.shape
    mid = int(cx - x0)
    for k in range(1, n + 1):
        comp = lab == k
        yy, xx = np.where(comp & (a > 0.5))
        if len(yy) < 25:
            continue
        body = comp[int(hh * 0.45):, max(mid - 12, 0):mid + 12].any()
        edge = xx.min() <= 1 or xx.max() >= ww - 2
        if body or not edge:
            keep |= comp
    a = a * keep
    ys, xs = np.where(a > 0.5)
    if len(ys) == 0:
        return Image.new("RGBA", (CELL, CELL))
    bottom = ys.max()
    rgba = np.dstack([c, a * 255.0]).astype(np.uint8)
    # premultiply untuk resize bersih
    pm = rgba.astype(np.float32)
    pm[..., :3] *= pm[..., 3:4] / 255.0
    img = Image.fromarray(pm.astype(np.uint8), "RGBA")
    # Image RGBA premultiplied manual: resize tiap kanal
    w, h = img.size
    nw, nh = max(int(round(w * SCALE)), 1), max(int(round(h * SCALE)), 1)
    chans = [Image.fromarray(pm[..., i]).resize((nw, nh), Image.LANCZOS) for i in range(4)]
    out = np.dstack([np.array(ch) for ch in chans]).astype(np.float32)
    al = np.clip(out[..., 3], 0, 255)
    col = out[..., :3] / np.maximum(al[..., None] / 255.0, 1e-3)
    out = np.dstack([np.clip(col, 0, 255), np.where(al > 96, 255, 0)]).astype(np.uint8)
    spr = Image.fromarray(out, "RGBA")
    if flip:
        spr = spr.transpose(Image.FLIP_LEFT_RIGHT)
    cell = Image.new("RGBA", (CELL, CELL))
    # pusat badan (cx) di tengah sel; kaki (dasar sprite) di y=FOOT
    px = int(round(CELL / 2 - (cx - x0) * SCALE)) if not flip else int(round(CELL / 2 - (x1 - cx) * SCALE))
    py = int(round(FOOT - bottom * SCALE - 0.5))
    cell.alpha_composite(spr, (px, py)) if (px >= 0 and py >= 0 and px + nw <= CELL and py + nh <= CELL) else paste_clip(cell, spr, px, py)
    return cell


def paste_clip(cell, spr, px, py):
    sx0, sy0 = max(0, -px), max(0, -py)
    dx0, dy0 = max(0, px), max(0, py)
    w = min(spr.width - sx0, CELL - dx0)
    h = min(spr.height - sy0, CELL - dy0)
    if w > 0 and h > 0:
        cell.alpha_composite(spr.crop((sx0, sy0, sx0 + w, sy0 + h)), (dx0, dy0))


rows = []      # (nama, jumlah_frame, fps, loop, [cells])
for name, fps, loop in ORDER:
    for d in DIRS:
        cells = [frame(name, x) for x in CX[name][d]]
        for x in FLIP.get(name, {}).get(d, []):
            cells.append(frame(name, x, flip=True))
        rows.append((f"{name}_{d}", len(cells), fps, loop, cells))

atlas = Image.new("RGBA", (CELL * 4, CELL * len(rows)))
for r, (_, n, _, _, cells) in enumerate(rows):
    for i, c in enumerate(cells):
        atlas.alpha_composite(c, (i * CELL, r * CELL))
atlas.save(OUT)
for r, (nm, n, fps, loop, _) in enumerate(rows):
    print(nm, r, n, fps, loop)
if PREV:
    bg = Image.new("RGBA", atlas.size, (60, 60, 70, 255))
    bg.alpha_composite(atlas)
    bg.resize((atlas.width * 2, atlas.height * 2), Image.NEAREST).convert("RGB").save(PREV)
