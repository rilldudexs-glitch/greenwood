extends RefCounted
# Fog of war untuk minimap. Peta ditutup kabut sampai pemain menjelajahinya.
#  - Grid kasar 128x64 (1 sel = 4 tile) -> gambar kecil, murah di HP kelas bawah.
#  - Tiap sel menyimpan "kejernihan" 0-255 (0 = tertutup kabut, 255 = terlihat jelas).
#  - Tiap biome punya gaya sendiri (lihat STYLE): radius pandang, warna & pola kabut,
#    bentuk tepi (wob), dan apakah kabut menutup lagi seiring waktu (decay).
#  - Disimpan di Game.p["fog"][id dunia] (deflate + base64), jadi ikut file save.
# Dipakai oleh hud.gd (digambar di atas minimap, bos di kabut disembunyikan).

const CELL := 4                  # tile per sel fog
const FW := 128
const FH := 64
const TICK := 0.25               # detik antar pembaruan
const DECAY_EVERY := 3.0         # detik antar langkah kabut menutup lagi
const FLUSH_EVERY := 2.0         # detik antar penulisan ke Game.p (kalau ada perubahan)
const SEEN_MIN := 90             # kejernihan minimum supaya dianggap "sudah terlihat"

enum P { MIST, SPECK, STRIPE, WAVE, SWIRL }

# Indeks = id biome (lihat IDS di world.gd).
#  r     radius pandang (tile)            col/hi  warna dasar & warna highlight kabut
#  a     ketebalan kabut (0-1)            pat     pola   mix  kuat pola   th  ambang bintik (SPECK)
#  wob   ketidakteraturan tepi (0-0.6)    decay   kejernihan yang hilang tiap DECAY_EVERY detik (0 = permanen)
#  floor batas bawah kejernihan saat kabut menutup lagi
const STYLE := [
    # 0 Desa: tanah hangat, pandangan lega
    {"r": 18, "col": Color(0.20, 0.15, 0.10), "hi": Color(0.35, 0.27, 0.17), "a": 0.93, "pat": P.MIST, "mix": 0.6, "th": 0.0, "wob": 0.05, "decay": 0, "floor": 0},
    # 1 Hutan: kanopi rapat, pandangan sempit & tepi bergerigi
    {"r": 11, "col": Color(0.04, 0.12, 0.06), "hi": Color(0.10, 0.27, 0.12), "a": 0.95, "pat": P.MIST, "mix": 0.9, "th": 0.0, "wob": 0.30, "decay": 0, "floor": 0},
    # 2 Gurun: terbuka luas, kabut debu bergaris tertiup angin
    {"r": 21, "col": Color(0.36, 0.26, 0.12), "hi": Color(0.66, 0.50, 0.25), "a": 0.92, "pat": P.STRIPE, "mix": 0.85, "th": 0.0, "wob": 0.10, "decay": 0, "floor": 0},
    # 3 Salju: badai putih berbintik; jejak tertimbun salju (kabut menutup lagi pelan)
    {"r": 12, "col": Color(0.60, 0.70, 0.82), "hi": Color(0.96, 0.98, 1.00), "a": 0.96, "pat": P.SPECK, "mix": 0.9, "th": 0.78, "wob": 0.15, "decay": 3, "floor": 70},
    # 4 Gunung api: asap pekat dengan percik bara; abu menimbun jejak
    {"r": 12, "col": Color(0.10, 0.03, 0.02), "hi": Color(1.00, 0.42, 0.10), "a": 0.96, "pat": P.SPECK, "mix": 1.0, "th": 0.90, "wob": 0.20, "decay": 2, "floor": 100},
    # 5 Shadow Reach: nyaris gelap total, hanya cahaya kecil di sekitarmu; jejak cepat ditelan gelap
    {"r": 7, "col": Color(0.01, 0.005, 0.03), "hi": Color(0.32, 0.16, 0.52), "a": 1.0, "pat": P.SPECK, "mix": 1.0, "th": 0.94, "wob": 0.10, "decay": 9, "floor": 0},
    # 6 Undefined Land: tepi kacau seperti glitch
    {"r": 12, "col": Color(0.10, 0.07, 0.18), "hi": Color(0.60, 0.48, 0.90), "a": 0.95, "pat": P.SPECK, "mix": 1.0, "th": 0.85, "wob": 0.55, "decay": 0, "floor": 0},
    # 7 Abyssal Land: air gelap bergelombang; jejak perlahan tenggelam
    {"r": 9, "col": Color(0.00, 0.04, 0.08), "hi": Color(0.10, 0.45, 0.62), "a": 0.97, "pat": P.WAVE, "mix": 0.8, "th": 0.0, "wob": 0.15, "decay": 4, "floor": 20},
    # 8 Enchanted Forest: kabut sihir berputar
    {"r": 12, "col": Color(0.04, 0.16, 0.12), "hi": Color(0.42, 0.92, 0.72), "a": 0.94, "pat": P.SWIRL, "mix": 0.85, "th": 0.0, "wob": 0.25, "decay": 0, "floor": 0},
    # 9 Sakura Valley: kelopak berhamburan
    {"r": 14, "col": Color(0.32, 0.13, 0.20), "hi": Color(1.00, 0.72, 0.82), "a": 0.92, "pat": P.SPECK, "mix": 0.9, "th": 0.82, "wob": 0.20, "decay": 0, "floor": 0},
    # 10 Mushroom Kingdom: spora, tepi menggumpal tak beraturan
    {"r": 11, "col": Color(0.16, 0.07, 0.22), "hi": Color(0.92, 0.40, 0.92), "a": 0.95, "pat": P.SPECK, "mix": 1.0, "th": 0.86, "wob": 0.45, "decay": 0, "floor": 0},
    # 11 Ethergrooves: embun es bergelombang
    {"r": 14, "col": Color(0.07, 0.18, 0.28), "hi": Color(0.52, 0.86, 1.00), "a": 0.94, "pat": P.WAVE, "mix": 0.7, "th": 0.0, "wob": 0.15, "decay": 0, "floor": 0},
    # 12 Forgotten Kingdom: debu reruntuhan kuno
    {"r": 12, "col": Color(0.14, 0.11, 0.09), "hi": Color(0.42, 0.36, 0.29), "a": 0.95, "pat": P.MIST, "mix": 0.8, "th": 0.0, "wob": 0.15, "decay": 0, "floor": 0},
    # 13 Lumins Reef: air terang berpendar
    {"r": 14, "col": Color(0.03, 0.20, 0.23), "hi": Color(0.42, 1.00, 0.95), "a": 0.92, "pat": P.WAVE, "mix": 0.9, "th": 0.0, "wob": 0.20, "decay": 0, "floor": 0},
    # 14 Verdan Height: dataran tinggi, pandangan jauh
    {"r": 19, "col": Color(0.08, 0.18, 0.07), "hi": Color(0.46, 0.76, 0.30), "a": 0.92, "pat": P.MIST, "mix": 0.7, "th": 0.0, "wob": 0.05, "decay": 0, "floor": 0},
    # 15 Crystal Cavern: bintang kristal berkilau
    {"r": 13, "col": Color(0.08, 0.08, 0.28), "hi": Color(0.62, 0.72, 1.00), "a": 0.95, "pat": P.SPECK, "mix": 1.0, "th": 0.88, "wob": 0.25, "decay": 0, "floor": 0},
]

var tex: ImageTexture
var world
var _img: Image
var _clar := PackedByteArray()            # kejernihan per sel
var _bio := PackedByteArray()             # biome per sel
var _decay_cells: Array = []              # indeks sel yang bisa menutup lagi
var _persist := true
var _wid := 0
var _t := 0.0
var _decay_t := 0.0
var _flush_t := 0.0
var _last_tile := Vector2i(-9999, -9999)
var _tex_dirty := false
var _save_dirty := false
var _ppos := Vector2.ZERO                 # posisi pemain terakhir (satuan sel fog)


func setup(w, start_pos: Vector2) -> void:
    world = w
    _wid = int(w.world_id)
    # klien co-op memakai dunia host: jangan menimpa fog dunia sendiri
    _persist = not (Net.active and not Net.is_host)
    _clar.resize(FW * FH)
    _bio.resize(FW * FH)
    for cy in FH:
        for cx in FW:
            var tx: int = clampi(cx * CELL + CELL / 2, 0, w.W - 1)
            var ty: int = clampi(cy * CELL + CELL / 2, 0, w.H - 1)
            var b: int = clampi(int(w.biome[w.idx(tx, ty)]), 0, STYLE.size() - 1)
            _bio[cy * FW + cx] = b
            if int(STYLE[b]["decay"]) > 0:
                _decay_cells.append(cy * FW + cx)
    if _persist:
        _load()
    _img = Image.create(FW, FH, false, Image.FORMAT_RGBA8)
    for cy in FH:
        for cx in FW:
            _paint(cx, cy)
    tex = ImageTexture.create_from_image(_img)
    _reveal(start_pos)
    _flush_tex()


# ------------------------------------------------------------------ pembaruan
# Dipanggil tiap frame dari hud.gd; kerja nyata hanya tiap TICK detik.
func tick(delta: float, pos: Vector2, indoors: bool) -> void:
    _t += delta
    if _t < TICK:
        return
    var dt: float = _t
    _t = 0.0
    if not indoors:
        var tile := Vector2i(floori(pos.x / 32.0), floori(pos.y / 32.0))
        if tile != _last_tile:
            _last_tile = tile
            _reveal(pos)
        _decay_t += dt
        if _decay_t >= DECAY_EVERY:
            _decay_t = 0.0
            _decay_step()
    if _tex_dirty:
        _flush_tex()
    if _save_dirty:
        _flush_t += dt
        if _flush_t >= FLUSH_EVERY:
            _flush_t = 0.0
            _store()


# Sudah terlihat (bos / penanda tidak digambar di dalam kabut)
func seen_at(pos: Vector2) -> bool:
    var cx: int = clampi(floori(pos.x / 32.0) / CELL, 0, FW - 1)
    var cy: int = clampi(floori(pos.y / 32.0) / CELL, 0, FH - 1)
    return int(_clar[cy * FW + cx]) >= SEEN_MIN


# Buka kabut di satu area (petunjuk jurnal, meteor, dst), di luar radius pandang biasa.
func reveal_area(pos: Vector2, radius_tiles: float) -> void:
    var cc := Vector2(pos.x / 32.0 / float(CELL), pos.y / 32.0 / float(CELL))
    var rc: float = radius_tiles / float(CELL)
    var span: int = int(ceilf(rc)) + 1
    var x0: int = floori(cc.x)
    var y0: int = floori(cc.y)
    for cy in range(maxi(y0 - span, 0), mini(y0 + span + 1, FH)):
        for cx in range(maxi(x0 - span, 0), mini(x0 + span + 1, FW)):
            var d: float = Vector2(float(cx) + 0.5, float(cy) + 0.5).distance_to(cc)
            var k: float = clampf((rc - d) / maxf(rc * 0.4, 0.01), 0.0, 1.0)
            var v: int = int(k * 255.0)
            var i: int = cy * FW + cx
            if v > int(_clar[i]):
                _clar[i] = v
                _paint(cx, cy)
                _tex_dirty = true
                _save_dirty = true


func _reveal(pos: Vector2) -> void:
    var cc := Vector2(pos.x / 32.0 / float(CELL), pos.y / 32.0 / float(CELL))
    _ppos = cc
    var b: int = int(_bio[clampi(floori(cc.y), 0, FH - 1) * FW + clampi(floori(cc.x), 0, FW - 1)])
    var st: Dictionary = STYLE[b]
    var rc: float = float(st["r"]) / float(CELL)
    var wob: float = float(st["wob"])
    var span: int = int(ceilf(rc * (1.0 + wob))) + 1
    var x0: int = floori(cc.x)
    var y0: int = floori(cc.y)
    for cy in range(maxi(y0 - span, 0), mini(y0 + span + 1, FH)):
        for cx in range(maxi(x0 - span, 0), mini(x0 + span + 1, FW)):
            var d: float = Vector2(float(cx) + 0.5, float(cy) + 0.5).distance_to(cc)
            var rr: float = rc
            if wob > 0.0:
                rr *= 1.0 - wob + wob * 2.0 * _hh(cx, cy, 7)     # tepi tak beraturan
            var k: float = clampf((rr - d) / maxf(rr * 0.35, 0.01), 0.0, 1.0)
            var v: int = int(k * 255.0)
            var i: int = cy * FW + cx
            if v > int(_clar[i]):
                _clar[i] = v
                _paint(cx, cy)
                _tex_dirty = true
                _save_dirty = true


# Kabut menutup lagi di biome tertentu (salju, bara, gelap, ...), kecuali dekat pemain
func _decay_step() -> void:
    if _decay_cells.is_empty():
        return
    for i in _decay_cells:
        var c: int = int(_clar[i])
        var b: int = int(_bio[i])
        var st: Dictionary = STYLE[b]
        var fl: int = int(st["floor"])
        if c <= fl:
            continue
        var cx: int = i % FW
        var cy: int = i / FW
        var near: float = float(st["r"]) / float(CELL) * 1.2
        if Vector2(float(cx) + 0.5, float(cy) + 0.5).distance_to(_ppos) < near:
            continue
        _clar[i] = maxi(c - int(st["decay"]), fl)
        _paint(cx, cy)
        _tex_dirty = true
        _save_dirty = true


# ------------------------------------------------------------------ gambar
func _paint(cx: int, cy: int) -> void:
    var i: int = cy * FW + cx
    var st: Dictionary = STYLE[int(_bio[i])]
    var h: float = _hh(cx, cy, 3)
    var t := 0.0
    match int(st["pat"]):
        P.MIST:
            t = 0.5 + 0.5 * sin(float(cx) * 0.7 + sin(float(cy) * 0.45) * 2.2)
            t = t * 0.7 + h * 0.3
        P.SPECK:
            t = 1.0 if h > float(st["th"]) else h * 0.15
        P.STRIPE:
            t = 0.5 + 0.5 * sin(float(cy) * 1.9 + sin(float(cx) * 0.22) * 2.6)
            t = t * 0.8 + h * 0.2
        P.WAVE:
            t = 0.5 + 0.5 * sin(float(cx) * 0.55 + float(cy) * 0.8)
            t = t * 0.85 + h * 0.15
        P.SWIRL:
            t = 0.5 + 0.5 * sin(float(cx) * 0.35 + sin(float(cy) * 0.4) * 3.0) * cos(float(cy) * 0.3 + float(cx) * 0.1)
    var col: Color = (st["col"] as Color).lerp(st["hi"] as Color, clampf(t, 0.0, 1.0) * float(st["mix"]))
    col.a = float(st["a"]) * (1.0 - float(_clar[i]) / 255.0)
    _img.set_pixel(cx, cy, col)


func _flush_tex() -> void:
    _tex_dirty = false
    tex.update(_img)


static func _hh(x: int, y: int, s: int) -> float:
    var n: int = x * 374761393 + y * 668265263 + s * 1274126177
    n = (n ^ (n >> 13)) * 1274126177
    return float((n ^ (n >> 16)) & 0xffff) / 65535.0


# ------------------------------------------------------------------ simpan / muat
func _store() -> void:
    _save_dirty = false
    if not _persist:
        return
    if typeof(Game.p.get("fog")) != TYPE_DICTIONARY:
        Game.p["fog"] = {}
    Game.p["fog"][str(_wid)] = Marshalls.raw_to_base64(_clar.compress(FileAccess.COMPRESSION_DEFLATE))


func flush() -> void:
    if _save_dirty:
        _store()


func _load() -> void:
    var fg = Game.p.get("fog", {})
    if typeof(fg) != TYPE_DICTIONARY or not fg.has(str(_wid)):
        return
    var raw: PackedByteArray = Marshalls.base64_to_raw(str(fg[str(_wid)]))
    if raw.is_empty():
        return
    var data: PackedByteArray = raw.decompress(FW * FH, FileAccess.COMPRESSION_DEFLATE)
    if data.size() == FW * FH:
        _clar = data
