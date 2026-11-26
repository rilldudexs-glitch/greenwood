extends Node2D
# Dunia terbuka 512x256 tile. Ada dua dunia terpisah (Game.world_id()):
#   World 1 = desa + hutan/gurun/salju/gunung api + biome 5-10 (Shadow .. Mushroom)
#   World 2 = desa pos (hub) + biome 11-14 (Ethergrooves .. Verdan)
# Semua wilayah terhubung oleh jalan tanah berkelok dan dirender dengan chunk streaming.

const Art = preload("res://scripts/art.gd")
const Chunk = preload("res://scripts/chunk.gd")

const TILE := 32
const W := 512
const H := 256
const CH := 16
const CHUNK_PX := CH * TILE            # 512 px
const BAKE_PER_FRAME := 2              # chunk yang digambar per frame saat loading
const CENTER := Vector2i(256, 128)
const OLD_C := Vector2i(64, 48)        # pusat koordinat desain desa lama
const VO := Vector2i(192, 80)           # = CENTER - OLD_C
# Pengaturan streaming chunk: hanya chunk di sekitar pemain yang ada di memori
const STREAM_LOAD := 1                 # bake chunk dalam jarak ini (satuan chunk)
const STREAM_KEEP := 2                 # buang chunk yang lebih jauh dari ini
const IDS := ["village", "forest", "desert", "snow", "volcano", "shadow", "undefined", "abyssal", "enchanted", "sakura", "mushroom", "ethergrooves", "forgotten", "lumins", "verdan", "crystal"]
const BNAMES := ["Desa Greenwood", "Hutan Greenwood", "Gurun Berdebu", "Puncak Salju", "Gunung Api", "Shadow Reach", "Undefined Land", "Abyssal Land", "Enchanted Forest", "Sakura Valley", "Mushroom Kingdom", "Ethergrooves", "Forgotten Kingdom", "Lumins Reef", "Verdan Height", "Crystal Cavern"]
const MUSIC := ["village", "forest", "desert", "snow", "volcano", "shadow", "undefined", "abyss", "enchanted", "sakura", "mushroom", "ether", "forgotten", "reef", "verdan", "crystal"]
const MAP_COL := [Color(0.6,0.42,0.25), Color(0.25,0.55,0.25), Color(0.88,0.74,0.42), Color(0.85,0.92,1.0), Color(0.6,0.2,0.15), Color(0.12,0.10,0.20), Color(0.38,0.32,0.52), Color(0.08,0.16,0.24), Color(0.22,0.48,0.25), Color(0.88,0.48,0.62), Color(0.55,0.32,0.68), Color(0.28,0.55,0.72), Color(0.42,0.36,0.28), Color(0.25,0.78,0.82), Color(0.36,0.62,0.32), Color(0.32,0.30,0.78)]
const BIOME_MULT := [1.0, 1.0, 1.7, 2.6, 3.8, 4.5, 5.0, 5.5, 4.2, 4.0, 4.8, 6.0, 6.5, 7.0, 7.5, 8.0]

enum K { GROUND, DIRT, PLAZA, WATER, TREE, BUSH, ROCK, HOUSE, STUMP }

# Sarang bos World 1 (koordinat absolut; digeser dari peta lama 256x192 ke pusat baru)
const LAIRS_W1 := [
    {"biome": 1, "style": "ent", "cell": Vector2i(176, 128), "name": "Ent Kuno"},
    {"biome": 2, "style": "scorpion", "cell": Vector2i(336, 128), "name": "Ratu Kalajengking"},
    {"biome": 3, "style": "yeti", "cell": Vector2i(256, 72), "name": "Yeti Perkasa"},
    {"biome": 4, "style": "dragon", "cell": Vector2i(256, 184), "name": "Naga Api"},
]
# Biome yang ada di tiap dunia (indeks = id dunia)
const WORLD_BIOMES := [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    [0, 11, 12, 13, 14, 15],
]
const PORTAL_W1 := Vector2i(356, 68)    # fallback jika kastil Enchanted Forest tidak ditemukan
const PORTAL_W2 := Vector2i(256, 114)   # portal kembali ke World 1, di utara desa pos

var world_id := 0
var LAIRS: Array = []
var _portal_w1_cell := Vector2i(-1, -1)

# [x0, y0, tipe, varian] ; semua 4x3 tile, menghadap selatan
const PLOTS := [
    [46, 42, "house", 0], [52, 42, "house", 1], [58, 42, "shop", 0], [66, 42, "smith", 0], [72, 42, "house", 2], [78, 42, "house", 3],
    [46, 52, "house", 4], [52, 52, "house", 0], [58, 52, "healer", 0], [66, 52, "gacha", 0], [72, 52, "house", 1], [78, 52, "house", 2],
]

var kind := PackedByteArray()
var biome := PackedByteArray()
var ore := {}            # idx -> id bijih (untuk ROCK)
var hits := {}           # idx -> sisa pukulan
var regrow := {}         # idx -> {"t": detik, "to": K}
var houses: Array = []
var cbodies := {}        # Vector2i chunk -> StaticBody2D (tabrakan per chunk, digabung jadi kotak besar)
var slots := {}          # Vector2i chunk -> {"vp", "spr", "drawer", "free_in"} (hasil bake)
var _bake_queue: Array = []
var _bake_total := 0
var _pending: Array = []   # chunk yang penggambarnya masih menunggu selesai dirender
var _col_center := Vector2i(-99, -99)
var baked := false
signal baked_all
var textures: Array = []
var dirt_tex: Array = []
var dirt_by_biome: Array = []   # per biome: daftar tekstur jalan tanah
var edge_by_biome: Array = []   # per biome: strip 12 potongan tepi jalan (edges.png)
var plaza_tex: Texture2D
var reachable_mask := PackedByteArray()
var open_by_biome: Array = []
var sd := 0
var _acc := 0.0
var _noise_tree := FastNoiseLite.new()
var _trail_dirty := {}            # chunk yang tabrakannya perlu dibangun ulang setelah jalan kecil digali
var trunk_pts: Array = []        # titik-titik jalan utama (untuk menyambung gubuk)
var safe_zones: Array = []       # Rect2i sel: area gubuk/perumahan (monster tidak muncul di sini)
var castles: Array = []          # kastil/istana tiap biome: {x, y, w, h, vis_h, biome}
var castle_by_biome: Array = []  # per biome: sprite kastil (assets/castles/<biome>.png) atau null
var _stream_t := 0.0
var _stream_ck := Vector2i(-99, -99)
var _player_ref = null


func _ready() -> void:
    add_to_group("world")
    world_id = clampi(Game.world_id(), 0, WORLD_BIOMES.size() - 1)
    sd = (int(Game.world_seed) + world_id * 7919) & 0x7fffffff
    LAIRS = LAIRS_W1.duplicate() if world_id == 0 else []
    open_by_biome.resize(IDS.size())
    for bi in IDS.size():
        open_by_biome[bi] = []
    _load_textures()
    _noise_tree.seed = sd + 13
    _noise_tree.frequency = 0.09
    _generate()
    _build_collision()
    _compute_reachable()
    _queue_bake()


# ------------------------------------------------------------------ util
# Koordinat peta lama (128x96) -> peta baru. vil = bagian desa (geser saja), far = daerah luar (diskala 1.5x)
static func vil(c: Vector2i) -> Vector2i:
    return c + VO


static func far(c: Vector2i) -> Vector2i:
    var d: Vector2 = Vector2(c - OLD_C) * 1.5
    return CENTER + Vector2i(roundi(d.x), roundi(d.y))


func _h(x: int, y: int, s: int) -> int:
    var n: int = x * 374761393 + y * 668265263 + s * 1274126177 + sd
    n = (n ^ (n >> 13)) * 1274126177
    return absi(n ^ (n >> 16))


func idx(x: int, y: int) -> int:
    return y * W + x


func cell_of(pos: Vector2) -> Vector2i:
    return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func in_bounds(c: Vector2i) -> bool:
    return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func get_kind(c: Vector2i) -> int:
    if not in_bounds(c):
        return K.TREE
    return kind[idx(c.x, c.y)]


func is_solid_kind(k: int) -> bool:
    return k == K.WATER or k == K.TREE or k == K.BUSH or k == K.ROCK or k == K.HOUSE


func is_solid_cell(c: Vector2i) -> bool:
    return is_solid_kind(get_kind(c))


func is_solid_at(pos: Vector2) -> bool:
    if has_meta("dungeon_node"):                       # di dalam dungeon: dinding gua (proyektil berhenti di dinding)
        var dg = get_meta("dungeon_node")
        if is_instance_valid(dg) and dg.contains(pos):
            return dg.is_wall_at(pos)
    return is_solid_cell(cell_of(pos))


func cell_center(c: Vector2i) -> Vector2:
    return (Vector2(c) + Vector2(0.5, 0.5)) * TILE


func world_size() -> Vector2:
    return Vector2(W * TILE, H * TILE)


func has_biome(b: int) -> bool:
    return (WORLD_BIOMES[world_id] as Array).has(b)


func portal_cell() -> Vector2i:
    if world_id == 0 and _portal_w1_cell.x >= 0:
        return _portal_w1_cell
    return PORTAL_W1 if world_id == 0 else PORTAL_W2


func portal_pos() -> Vector2:
    return cell_center(portal_cell())


# Titik jalan utama dari desa ke tiap biome ekspansi (dan portal di World 1)
func _anchor_points() -> Array:
    var out: Array = []
    var n: int = 6 if world_id == 0 else 5
    var r: float = 108.0 if world_id == 0 else 100.0
    for k in n:
        var a: float = -PI + (float(k) + 0.5) * TAU / float(n)
        var c := Vector2i(CENTER.x + roundi(cos(a) * r), CENTER.y + roundi(sin(a) * r))
        out.append(Vector2i(clampi(c.x, 8, W - 9), clampi(c.y, 8, H - 9)))
    return out


func spawn_point() -> Vector2:
    return cell_center(Vector2i(CENTER.x, CENTER.y + 3))


func biome_at(pos: Vector2) -> int:
    var c := cell_of(pos)
    if not in_bounds(c):
        return 1
    return biome[idx(c.x, c.y)]


func in_village(pos: Vector2) -> bool:
    return biome_at(pos) == 0


func lair_center(i: int) -> Vector2:
    return cell_center(LAIRS[i]["cell"])


# ------------------------------------------------------------------ tekstur
func _load_textures() -> void:
    for id in IDS:
        var dir_id: String = "forest" if id == "village" else id
        var dir := "res://assets/biomes/%s/" % dir_id
        textures.append({
            "ground": load(dir + "ground.png"), "ground2": load(dir + "ground2.png"),
            "path": load(dir + "path.png"), "floor": load(dir + "floor.png"),
            "water": load(dir + "water.png"), "tree": load(dir + "tree.png"), "bush": load(dir + "bush.png"),
        })
    # tanah coklat: pakai PNG baru (fallback ke versi kode kalau file hilang)
    dirt_tex = []
    for n in ["dirt", "dirt2", "dirt3"]:
        var dp: String = "res://assets/tiles/%s.png" % n
        if ResourceLoader.exists(dp):
            dirt_tex.append(load(dp))
    if dirt_tex.size() < 3:
        dirt_tex = [_make_dirt(1, Color(0.56, 0.39, 0.23)), _make_dirt(2, Color(0.53, 0.37, 0.21)), _make_dirt(3, Color(0.58, 0.41, 0.25))]
    # jalan tanah per biome (assets/biomes/<biome>/dirt*.png); kalau tidak ada pakai set umum
    dirt_by_biome = []
    edge_by_biome = []
    for id in IDS:
        var did: String = "forest" if id == "village" else id
        var lst: Array = []
        for n in ["dirt", "dirt2", "dirt3", "dirt4"]:
            var bp: String = "res://assets/biomes/%s/%s.png" % [did, n]
            if ResourceLoader.exists(bp):
                lst.append(load(bp))
        if lst.is_empty():
            lst = dirt_tex
        dirt_by_biome.append(lst)
        var ep: String = "res://assets/biomes/%s/edges.png" % did
        edge_by_biome.append(load(ep) if ResourceLoader.exists(ep) else null)
    plaza_tex = _make_plaza()
    # sprite kastil per biome (assets/castles/<biome>.png); kalau tidak ada, pakai kotak pengganti
    castle_by_biome = []
    for id in IDS:
        var cp: String = "res://assets/castles/%s.png" % id
        castle_by_biome.append(load(cp) if ResourceLoader.exists(cp) else null)


func _make_dirt(s: int, base: Color) -> ImageTexture:
    var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    var r := RandomNumberGenerator.new()
    r.seed = s * 7919
    for y in 32:
        for x in 32:
            var c: Color = base
            var n: float = r.randf()
            if n < 0.12:
                c = base.darkened(0.14)
            elif n < 0.22:
                c = base.lightened(0.1)
            img.set_pixel(x, y, c)
    for i in 9:
        var px: int = r.randi_range(1, 29)
        var py: int = r.randi_range(1, 30)
        var pc: Color = Color(0.7, 0.62, 0.52) if i % 2 == 0 else base.darkened(0.3)
        img.set_pixel(px, py, pc)
        img.set_pixel(px + 1, py, pc.darkened(0.15))
    return ImageTexture.create_from_image(img)


func _make_plaza() -> ImageTexture:
    var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
    var r := RandomNumberGenerator.new()
    r.seed = 4242
    for y in 32:
        for x in 32:
            var row: int = y / 8
            var off: int = 0 if row % 2 == 0 else 8
            var edge: bool = (y % 8 == 0) or ((x + off) % 16 == 0)
            var c := Color(0.66, 0.6, 0.52) if not edge else Color(0.42, 0.37, 0.32)
            if not edge and r.randf() < 0.12:
                c = c.darkened(0.08)
            img.set_pixel(x, y, c)
    return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ pembuatan peta
func _generate() -> void:
    kind.resize(W * H)
    biome.resize(W * H)
    var wob := FastNoiseLite.new()
    wob.seed = sd + 3
    wob.frequency = 0.05
    var wob2 := FastNoiseLite.new()
    wob2.seed = sd + 7
    wob2.frequency = 0.05
    for y in H:
        for x in W:
            var dx: float = float(x - CENTER.x)
            var dy: float = float(y - CENTER.y)
            var d: float = sqrt(dx * dx + dy * dy)
            var b := 1
            var ex: float = dx + wob.get_noise_2d(x, y) * 8.0
            var ey: float = dy + wob2.get_noise_2d(x, y) * 8.0
            if d < 17.5:
                b = 0
            elif world_id == 1:
                # World 2: lima irisan biome 11-15 mengelilingi desa pos
                var sector2: int = int(floor((atan2(ey, ex) + PI) / TAU * 5.0)) % 5
                b = 11 + sector2
            elif d < 82.0:
                # Zona lama tetap di sekitar desa agar konten dan save lama tetap cocok.
                if ex > absf(ey) * 0.9:
                    b = 2
                elif ey < 0.0 and -ey > absf(ex) * 0.9:
                    b = 3
                elif ey > 0.0 and ey > absf(ex) * 0.9:
                    b = 4
                else:
                    b = 1
            else:
                # World 1: biome 5-10 sebagai 6 irisan sampai ke tepi peta
                var sector: int = int(floor((atan2(ey, ex) + PI) / TAU * 6.0)) % 6
                b = 5 + sector
            biome[idx(x, y)] = b
            kind[idx(x, y)] = K.GROUND

    var rng := RandomNumberGenerator.new()
    rng.seed = sd
    # danau / oasis / lava
    var lakes := {1: 20, 2: 7, 3: 13, 4: 13, 5: 8, 6: 5, 7: 12, 8: 12, 9: 10, 10: 14, 11: 10, 12: 8, 13: 18, 14: 12, 15: 10}
    for b in lakes.keys():
        if not has_biome(int(b)):
            continue
        var made := 0
        var tries := 0
        var want_lakes: int = int(lakes[b]) * (2 if int(b) >= 5 else 1)
        while made < want_lakes and tries < 900:
            tries += 1
            var cx: int = rng.randi_range(5, W - 6)
            var cy: int = rng.randi_range(5, H - 6)
            if biome[idx(cx, cy)] != b:
                continue
            if absi(cx - CENTER.x) < 8 or absi(cy - CENTER.y) < 8:
                continue
            _blob(K.WATER, cx, cy, rng.randi_range(2, 4), rng)
            made += 1
    _blob(K.WATER, 51 + VO.x, 63 + VO.y, 3, rng)   # kolam dekat desa (untuk memancing)

    # pohon, semak, batu
    for y in H:
        for x in W:
            var i := idx(x, y)
            if kind[i] != K.GROUND:
                continue
            var b: int = biome[i]
            var hv: int = _h(x, y, 3)
            var r1: float = float(hv % 1000) / 1000.0
            var r2: float = float((hv / 1000) % 1000) / 1000.0
            var nv: float = _noise_tree.get_noise_2d(x, y)
            var p_tree := 0.0
            var p_bush := 0.0
            var p_rock := 0.0
            match b:
                0:
                    p_tree = 0.012
                    p_bush = 0.03
                1:
                    p_tree = 0.6 if nv > 0.05 else 0.05
                    p_bush = 0.07
                    p_rock = 0.02
                2:
                    p_tree = 0.05 if nv > 0.2 else 0.012
                    p_bush = 0.05
                    p_rock = 0.03
                3:
                    p_tree = 0.5 if nv > 0.1 else 0.05
                    p_bush = 0.04
                    p_rock = 0.03
                4:
                    p_tree = 0.08 if nv > 0.25 else 0.015
                    p_bush = 0.06
                    p_rock = 0.045
                5:
                    p_tree = 0.18 if nv > -0.1 else 0.04
                    p_bush = 0.10
                    p_rock = 0.07
                6, 7:
                    p_tree = 0.025
                    p_bush = 0.035
                    p_rock = 0.16
                8, 9, 10:
                    p_tree = 0.48 if nv > -0.05 else 0.12
                    p_bush = 0.13
                    p_rock = 0.035
                11, 12, 13, 14, 15:
                    p_tree = 0.28 if nv > 0.0 else 0.06
                    p_bush = 0.10
                    p_rock = 0.12
            if nv < -0.45 and b != 0:
                p_rock += 0.15
            if r1 < p_tree:
                kind[i] = K.TREE
            elif r1 < p_tree + p_bush:
                kind[i] = K.BUSH
            elif r2 < p_rock:
                kind[i] = K.ROCK
                ore[i] = _pick_ore(b, float((hv / 7) % 1000) / 1000.0)

    # jalan tanah berkelok (menyambung desa ke tiap sarang bos), lalu cabang ke gubuk/perumahan
    trunk_pts = []
    for lr in LAIRS:
        var lc: Vector2i = lr["cell"]
        _wind_road(Vector2(CENTER), Vector2(lc), 15.0, 20 + int(lr["biome"]), rng, true, 2)
    # jalan utama ke tiap biome ekspansi / portal
    var ai := 0
    for ap in _anchor_points():
        _wind_road(Vector2(CENTER), Vector2(ap), 15.0, 60 + ai, rng, true, 3)
        ai += 1
    # jalan melintang di depan rumah desa
    for x in range(44 + VO.x, 85 + VO.x):
        _road(x, 57 + VO.y)
        _road(x, 58 + VO.y)
    # alun-alun
    for y in range(46 + VO.y, 50 + VO.y):
        for x in range(60 + VO.x, 68 + VO.x):
            kind[idx(x, y)] = K.PLAZA
    # rumah desa
    for pl in PLOTS:
        var x0: int = int(pl[0]) + VO.x
        var y0: int = int(pl[1]) + VO.y
        for yy in 3:
            for xx in 4:
                kind[idx(x0 + xx, y0 + yy)] = K.HOUSE
        houses.append({"x": x0, "y": y0, "w": 4, "h": 3, "kind": pl[2], "variant": pl[3]})
        var north: bool = y0 < CENTER.y
        var yy2: int = y0 + 3
        var lim: int = (CENTER.y - 1) if north else (57 + VO.y)
        while yy2 < lim:
            _road(x0 + 1, yy2)
            _road(x0 + 2, yy2)
            yy2 += 1
    _place_castles(rng)          # kastil dulu, lalu portal ditempatkan di samping kastil Enchanted Forest
    if world_id == 0:
        _place_world2_portal_by_enchanted_castle(rng)
    _place_shortcuts(rng)
    _place_outposts(rng)
    _thin_thickets()
    # sarang bos
    for lr in LAIRS:
        var lc: Vector2i = lr["cell"]
        for yy in range(lc.y - 6, lc.y + 7):
            for xx in range(lc.x - 6, lc.x + 7):
                if Vector2(xx - lc.x, yy - lc.y).length() <= 6.2 and in_bounds(Vector2i(xx, yy)):
                    var ii := idx(xx, yy)
                    if kind[ii] != K.DIRT:
                        kind[ii] = K.GROUND
    # tepi peta
    for y in H:
        for x in W:
            if x < 2 or y < 2 or x >= W - 2 or y >= H - 2:
                kind[idx(x, y)] = K.TREE


# ------------------------------------------------------------------ kastil / kerajaan
# Satu kastil di tiap biome ekspansi (id >= 5). Ukuran tapak dihitung dari sprite-nya:
# lebar = lebar sprite (tile) - 1, tinggi tapak (padat) = 60% tinggi sprite, sisanya menjulang di atas.
func _place_castles(rng: RandomNumberGenerator) -> void:
    castles = []
    for b in range(1, IDS.size()):
        if not has_biome(b):
            continue
        var tex: Texture2D = castle_by_biome[b]
        var cw := 7
        var ch := 4
        var vis_h := 6
        if tex != null:
            cw = maxi(4, int(tex.get_width() / TILE) - 1)
            vis_h = int(ceil(float(tex.get_height()) / float(TILE)))
            ch = maxi(3, int(float(vis_h) * 0.6))
        var site: Vector2i = _find_castle_site(b, cw, ch, vis_h, rng)
        if site.x < 0:
            continue
        _build_castle(site, cw, ch, vis_h, b, rng)

# Portal World 2 selalu berada di sisi kastil Enchanted Forest (biome 8).
# Area portal dibersihkan dan disambungkan langsung ke jalan gerbang kastil.
func _place_world2_portal_by_enchanted_castle(rng: RandomNumberGenerator) -> void:
    _portal_w1_cell = PORTAL_W1
    for ci in castles.size():
        var cs: Dictionary = castles[ci]
        if int(cs["biome"]) != 8:
            continue
        var x: int = int(cs["x"])
        var y: int = int(cs["y"])
        var cw: int = int(cs["w"])
        var ch: int = int(cs["h"])
        var candidates := [
            Vector2i(x + cw + 4, y + ch + 1),
            Vector2i(x - 4, y + ch + 1),
            Vector2i(x + cw / 2, y + ch + 7),
            Vector2i(x + cw / 2, y - 5)
        ]
        for candidate in candidates:
            if in_bounds(candidate) and biome[idx(candidate.x, candidate.y)] == 8:
                _portal_w1_cell = candidate
                break
        var pc := _portal_w1_cell
        for yy in range(pc.y - 5, pc.y + 6):
            for xx in range(pc.x - 5, pc.x + 6):
                var c := Vector2i(xx, yy)
                if Vector2(xx - pc.x, yy - pc.y).length() <= 4.6 and in_bounds(c):
                    var pidx := idx(xx, yy)
                    if kind[pidx] != K.WATER and kind[pidx] != K.HOUSE:
                        kind[pidx] = K.GROUND
                        ore.erase(pidx)
        _wind_road(_castle_gate(ci), Vector2(pc), 5.0, 1800 + pc.x * 3 + pc.y, rng, true, 2)
        return
    push_warning("Kastil Enchanted Forest tidak ditemukan; portal memakai lokasi fallback.")


# Kastil diletakkan di PUSAT tiap biome: rata-rata posisi semua sel biome itu, lalu cari lokasi valid
# terdekat dari pusat dengan menyusuri cincin yang makin lebar.
func _find_castle_site(b: int, cw: int, ch: int, vis_h: int, _rng: RandomNumberGenerator) -> Vector2i:
    var up: int = vis_h - ch                       # bagian sprite yang menjulang di atas tapak
    var sx := 0.0
    var sy := 0.0
    var n := 0
    for y in range(4, H - 4):
        for x in range(4, W - 4):
            if biome[idx(x, y)] == b:
                sx += float(x)
                sy += float(y)
                n += 1
    if n == 0:
        return Vector2i(-1, -1)
    var ctr := Vector2(sx / float(n), sy / float(n))
    var pc := Vector2(portal_cell())
    for pass_i in 2:                               # putaran ke-2 lebih longgar terhadap sarang bos
        var lair_gap: float = 20.0 if pass_i == 0 else 10.0
        for rad in range(0, 80, 2):
            var steps: int = 1 if rad == 0 else maxi(8, rad * 2)
            for s in steps:
                var cc: Vector2 = ctr + Vector2.from_angle(TAU * float(s) / float(steps)) * float(rad)
                var x: int = roundi(cc.x) - cw / 2
                var y: int = roundi(cc.y) - ch / 2
                if x < 10 or y < up + 8 or x > W - 11 - cw or y > H - 14 - ch:
                    continue
                if _castle_fits(x, y, cw, ch, up, vis_h, b, lair_gap, pc):
                    return Vector2i(x, y)
    push_warning("Kastil biome %d tidak menemukan lokasi" % b)
    return Vector2i(-1, -1)


func _castle_fits(x: int, y: int, cw: int, ch: int, up: int, vis_h: int, b: int, lair_gap: float, pc: Vector2) -> bool:
    for yy in [y - up, y, y + ch + 4]:
        for xx in [x, x + cw / 2, x + cw]:
            if biome[idx(xx, yy)] != b:
                return false
    var c := Vector2i(x, y)
    if Vector2(c).distance_to(pc) < 24.0:
        return false
    for lr in LAIRS:
        if Vector2(c - Vector2i(lr["cell"])).length() < lair_gap:
            return false
    var area := Rect2i(x - 4, y - up - 3, cw + 8, vis_h + 10)
    for sz in safe_zones:
        if area.intersects(sz):
            return false
    for yy in range(y - up - 3, y + ch + 6):
        for xx in range(x - 3, x + cw + 4):
            if kind[idx(xx, yy)] == K.WATER:
                return false
    return true


func _build_castle(site: Vector2i, cw: int, ch: int, vis_h: int, b: int, rng: RandomNumberGenerator) -> void:
    var up: int = vis_h - ch
    # bersihkan lahan (pohon/semak/batu)
    for yy in range(site.y - up - 3, site.y + ch + 6):
        for xx in range(site.x - 3, site.x + cw + 4):
            var i := idx(xx, yy)
            if kind[i] != K.WATER:
                kind[i] = K.GROUND
                ore.erase(i)
    # tapak kastil (padat)
    for yy in ch:
        for xx in cw:
            kind[idx(site.x + xx, site.y + yy)] = K.HOUSE
    # jalan dari gerbang
    var gx: int = site.x + cw / 2 - 1
    for yy in range(site.y + ch, site.y + ch + 3):
        _road(gx, yy)
        _road(gx + 1, yy)
    castles.append({"x": site.x, "y": site.y, "w": cw, "h": ch, "vis_h": vis_h, "biome": b})
    safe_zones.append(Rect2i(site.x - 4, site.y - up - 3, cw + 8, vis_h + 10))
    # jalan utama dari desa ke gerbang kastil (kastil di pusat biome = tujuan jalan utama)
    var start := Vector2i(gx, site.y + ch + 3)
    _wind_road(Vector2(CENTER), Vector2(start), 15.0, 300 + site.x * 5 + site.y, rng, true, 3)


func _castle_gate(i: int) -> Vector2:
    var cs: Dictionary = castles[i]
    return Vector2(int(cs["x"]) + int(cs["w"]) / 2 - 1, int(cs["y"]) + int(cs["h"]) + 3)


# Jalan pintas: tiap kastil disambung ke 2 kastil terdekat (tanpa lewat desa), jadi antar-biome bisa dilintasi langsung.
func _place_shortcuts(rng: RandomNumberGenerator) -> void:
    var n: int = castles.size()
    if n < 2:
        return
    var done := {}
    for i in n:
        var ds: Array = []
        for j in n:
            if j != i:
                ds.append([_castle_gate(i).distance_to(_castle_gate(j)), j])
        ds.sort_custom(func(p, q): return p[0] < q[0])
        for k in mini(2, ds.size()):
            var j2: int = int(ds[k][1])
            var key: String = "%d_%d" % [mini(i, j2), maxi(i, j2)]
            if done.has(key) or float(ds[k][0]) > 150.0:
                continue
            done[key] = true
            _wind_road(_castle_gate(i), _castle_gate(j2), 10.0, 700 + i * 31 + j2, rng, true, 2)


# Menipiskan hutan terlalu rapat: pohon yang dikelilingi >= 5 pohon lain sebagian dibuka supaya bisa dilewati.
func _thin_thickets() -> void:
    for y in range(4, H - 4):
        for x in range(4, W - 4):
            var i := idx(x, y)
            if kind[i] != K.TREE:
                continue
            var n := 0
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    if (dx != 0 or dy != 0) and kind[idx(x + dx, y + dy)] == K.TREE:
                        n += 1
            if n >= 5 and (_h(x, y, 11) % 100) < 45:
                kind[i] = K.GROUND


# Jalan kecil dari jalan utama terdekat ke sebuah titik menarik (gerbang gua, prasasti, tugu jurnal).
# Dipanggil main.gd sebelum dunia digambar.
func carve_trail(pos: Vector2) -> void:
    var c: Vector2i = cell_of(pos)
    if not in_bounds(c) or trunk_pts.is_empty():
        return
    var best := Vector2i(-1, -1)
    var bd := 1.0e9
    for tp in trunk_pts:
        var d: float = Vector2(tp - c).length()
        if d < bd:
            bd = d
            best = tp
    if best.x >= 0 and bd > 4.0 and bd < 130.0:
        var r := RandomNumberGenerator.new()
        _wind_road(Vector2(c), Vector2(best), 6.0, 900 + c.x * 3 + c.y, r, false, 1)
        var lo := Vector2i(maxi(mini(c.x, best.x) - 14, 0), maxi(mini(c.y, best.y) - 14, 0))
        var hi := Vector2i(mini(maxi(c.x, best.x) + 14, W - 1), mini(maxi(c.y, best.y) + 14, H - 1))
        for cy in range(lo.y / CH, hi.y / CH + 1):
            for cx in range(lo.x / CH, hi.x / CH + 1):
                _trail_dirty[Vector2i(cx, cy)] = true


func finish_trails() -> void:
    for ck in _trail_dirty.keys():
        _build_chunk_collision(ck)
    _trail_dirty.clear()


func castle_front(i: int) -> Vector2:
    var cs: Dictionary = castles[i]
    return cell_center(Vector2i(int(cs["x"]) + int(cs["w"]) / 2, int(cs["y"]) + int(cs["h"]) + 2))


# Jalan berkelok dari a ke b: simpangan memakai noise 1D, mengecil dekat ujung-ujungnya
func _wind_road(a: Vector2, b: Vector2, amp: float, seed_i: int, rng: RandomNumberGenerator, store: bool = true, tier: int = 1) -> void:
    var nz := FastNoiseLite.new()
    nz.seed = sd + seed_i
    nz.frequency = 0.045
    var dist: float = a.distance_to(b)
    var steps: int = int(dist * 1.6)
    if steps < 2:
        return
    var dirv: Vector2 = (b - a).normalized()
    var perp: Vector2 = dirv.orthogonal()
    for s in range(steps + 1):
        var t: float = float(s) / float(steps)
        var env: float = clampf((minf(t * dist, (1.0 - t) * dist) - 12.0) / 12.0, 0.0, 1.0)
        var off: float = nz.get_noise_1d(t * dist) * amp * 1.6 * env
        var p: Vector2 = a.lerp(b, t) + perp * off
        var cx: int = roundi(p.x)
        var cy: int = roundi(p.y)
        _stamp_road(cx, cy, tier)
        if store and s % 3 == 0:
            trunk_pts.append(Vector2i(cx, cy))


# Gubuk tunggal dan perumahan kecil di hutan/gurun/salju (tidak di gunung api), disambung jalan setapak
func _place_outposts(rng: RandomNumberGenerator) -> void:
    # [biome, jumlah perumahan, jumlah gubuk]
    var plan := [[1, 3, 7], [2, 2, 4], [3, 2, 4], [5, 2, 4], [6, 1, 3], [7, 1, 3], [8, 2, 4], [9, 2, 4], [10, 2, 4], [11, 2, 4], [12, 2, 4], [13, 2, 4], [14, 2, 4], [15, 2, 4]]
    var taken: Array = []
    for lr in LAIRS:
        taken.append(lr["cell"])
    taken.append(portal_cell())
    for cs in castles:
        taken.append(Vector2i(int(cs["x"]), int(cs["y"])))
    for pr in plan:
        var b: int = int(pr[0])
        if not has_biome(b):
            continue
        var mult: int = 2 if b >= 5 else 1       # biome ekspansi lebih luas -> lebih banyak pos
        for k in (int(pr[1]) + int(pr[2])) * mult:
            var hamlet: bool = k < int(pr[1]) * mult
            var n_house: int = rng.randi_range(3, 4) if hamlet else 1
            var site: Vector2i = _find_site(b, n_house, taken, rng)
            if site.x < 0:
                continue
            taken.append(site)
            _build_outpost(site, n_house, b, hamlet, rng)


func _find_site(b: int, n_house: int, taken: Array, rng: RandomNumberGenerator) -> Vector2i:
    var wdt: int = 4 + (n_house - 1) * 6
    for tr in 900:
        var x: int = rng.randi_range(8, W - 9 - wdt)
        var y: int = rng.randi_range(8, H - 14)
        var c := Vector2i(x, y)
        if biome[idx(x, y)] != b or biome[idx(x + wdt, y + 4)] != b:
            continue
        if Vector2(c - CENTER).length() < 42.0 or Vector2(c - CENTER).length() > 190.0:
            continue
        var ok := true
        for t in taken:
            if Vector2(c - Vector2i(t)).length() < 24.0:
                ok = false
                break
        if not ok:
            continue
        # jangan menimpa air
        for yy in range(y - 1, y + 6):
            for xx in range(x - 1, x + wdt + 1):
                if kind[idx(xx, yy)] == K.WATER:
                    ok = false
        if ok:
            return c
    return Vector2i(-1, -1)


func _build_outpost(site: Vector2i, n_house: int, b: int, hamlet: bool, rng: RandomNumberGenerator) -> void:
    var wdt: int = 4 + (n_house - 1) * 6
    # bersihkan lahan (pohon/semak/batu) dengan margin
    for yy in range(site.y - 2, site.y + 8):
        for xx in range(site.x - 2, site.x + wdt + 2):
            var i := idx(xx, yy)
            if kind[i] != K.WATER:
                kind[i] = K.GROUND
                ore.erase(i)
    var variants := [2, 0, 1, 4]
    for h in n_house:
        var x0: int = site.x + h * 6
        for yy in 3:
            for xx in 4:
                kind[idx(x0 + xx, site.y + yy)] = K.HOUSE
        var v: int = 2 if not hamlet else int(variants[rng.randi() % variants.size()])
        houses.append({"x": x0, "y": site.y, "w": 4, "h": 3, "kind": "hut" if not hamlet else "house", "variant": v, "biome": b})
        # halaman depan
        _road(x0 + 1, site.y + 3)
        _road(x0 + 2, site.y + 3)
    if hamlet:
        for xx in range(site.x, site.x + wdt):
            _road(xx, site.y + 4)
    safe_zones.append(Rect2i(site.x - 3, site.y - 3, wdt + 6, 12))
    # jalan setapak ke jalan utama terdekat
    var start := Vector2i(site.x + 1, site.y + 4)
    var best := Vector2i(-1, -1)
    var bd := 1.0e9
    for tp in trunk_pts:
        var d: float = Vector2(tp - start).length()
        if d < bd:
            bd = d
            best = tp
    if best.x >= 0 and bd > 3.0:
        _wind_road(Vector2(start), Vector2(best), 5.0, 100 + site.x * 7 + site.y, rng, false)


# Tiga tingkat jalan. tier 3 = jalan utama (lebar 4, pinggir 2 petak dibersihkan dari pohon),
# tier 2 = jalan pintas (lebar 3, pinggir 1), tier 1 = jalan kecil/setapak (lebar 2, pinggir 1).
func _stamp_road(cx: int, cy: int, tier: int) -> void:
    var w: int = 2 if tier <= 1 else (3 if tier == 2 else 4)
    var v: int = 2 if tier >= 3 else 1
    var r0: int = -(w - 1) / 2
    for yy in range(r0 - v, r0 + w + v):
        for xx in range(r0 - v, r0 + w + v):
            var x: int = cx + xx
            var y: int = cy + yy
            if x < 1 or y < 1 or x >= W - 1 or y >= H - 1:
                continue
            if xx >= r0 and xx < r0 + w and yy >= r0 and yy < r0 + w:
                _road(x, y)
            else:
                var i := idx(x, y)
                var k: int = kind[i]
                if k == K.TREE or k == K.BUSH or k == K.ROCK:
                    kind[i] = K.GROUND
                    ore.erase(i)


func _road(x: int, y: int) -> void:
    if x < 1 or y < 1 or x >= W - 1 or y >= H - 1:
        return
    var i := idx(x, y)
    if kind[i] == K.HOUSE:
        return
    kind[i] = K.DIRT
    ore.erase(i)


func _pick_ore(b: int, r: float) -> String:
    match b:
        1:
            if r < 0.28:
                return "copper"
            if r < 0.4:
                return "iron"
        2:
            if r < 0.3:
                return "iron"
            if r < 0.5:
                return "gold"
        3:
            if r < 0.35:
                return "crystal"
            if r < 0.5:
                return "iron"
        4, 5, 7, 11, 12:
            if r < 0.35:
                return "coal"
            if r < 0.6:
                return "obsidian"
            if r < 0.7:
                return "ruby"
        6, 13, 15:
            if r < 0.45:
                return "crystal"
            if r < 0.65:
                return "gold"
        8, 9, 10, 14:
            if r < 0.3:
                return "copper"
            if r < 0.55:
                return "crystal"
    return "stone"


func _blob(tile: int, cx: int, cy: int, r: int, rng: RandomNumberGenerator) -> void:
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy > r * r + rng.randi_range(-1, 2):
                continue
            var x := cx + dx
            var y := cy + dy
            if x < 3 or y < 3 or x >= W - 3 or y >= H - 3:
                continue
            var i := idx(x, y)
            if kind[i] == K.GROUND or kind[i] == K.TREE or kind[i] == K.BUSH or kind[i] == K.ROCK:
                kind[i] = tile
                ore.erase(i)


# ------------------------------------------------------------------ collision
# Tabrakan dibuat per chunk. Sel padat yang berdekatan digabung jadi kotak besar (jauh lebih
# sedikit shape), dan hanya chunk di sekitar pemain (3x3) yang aktif di mesin fisika.
func _build_collision() -> void:
    for cy in range(H / CH):
        for cx in range(W / CH):
            _build_chunk_collision(Vector2i(cx, cy))


func _build_chunk_collision(ck: Vector2i) -> void:
    var body: StaticBody2D = cbodies.get(ck)
    if body == null:
        body = StaticBody2D.new()
        body.collision_layer = 1
        body.collision_mask = 0
        body.process_mode = Node.PROCESS_MODE_DISABLED
        add_child(body)
        cbodies[ck] = body
    else:
        for ch in body.get_children():
            body.remove_child(ch)
            ch.queue_free()
    var x0: int = ck.x * CH
    var y0: int = ck.y * CH
    var open := {}                  # kunci "xa,xb" -> [xa, xb, y_awal]
    var rects: Array = []           # [xa, xb, ya, yb]
    for y in range(y0, y0 + CH):
        var runs := {}
        var x := x0
        while x < x0 + CH:
            if is_solid_kind(kind[idx(x, y)]):
                var xs := x
                while x < x0 + CH and is_solid_kind(kind[idx(x, y)]):
                    x += 1
                runs[xs * 1000 + x] = [xs, x]
            else:
                x += 1
        for k in open.keys():
            if not runs.has(k):
                var o: Array = open[k]
                rects.append([o[0], o[1], o[2], y])
                open.erase(k)
        for k in runs.keys():
            if not open.has(k):
                var r: Array = runs[k]
                open[k] = [r[0], r[1], y]
    for k in open.keys():
        var o2: Array = open[k]
        rects.append([o2[0], o2[1], o2[2], y0 + CH])
    for r in rects:
        var cs := CollisionShape2D.new()
        var sh := RectangleShape2D.new()
        sh.size = Vector2(float(int(r[1]) - int(r[0])) * TILE, float(int(r[3]) - int(r[2])) * TILE)
        cs.shape = sh
        cs.position = Vector2(float(int(r[0]) + int(r[1])) * 0.5 * TILE, float(int(r[2]) + int(r[3])) * 0.5 * TILE)
        body.add_child(cs)


# Aktifkan tabrakan hanya untuk chunk di sekitar 'pos' (dipanggil tiap pemain pindah chunk)
func update_collision_ring(pos: Vector2, force: bool = false) -> void:
    var ck := Vector2i(floori(pos.x / CHUNK_PX), floori(pos.y / CHUNK_PX))
    if ck == _col_center and not force:
        return
    _col_center = ck
    for key in cbodies.keys():
        var want: bool = absi(key.x - ck.x) <= 1 and absi(key.y - ck.y) <= 1
        var m: int = Node.PROCESS_MODE_INHERIT if want else Node.PROCESS_MODE_DISABLED
        var b: StaticBody2D = cbodies[key]
        if b.process_mode != m:
            b.process_mode = m


func _set_kind(c: Vector2i, k: int) -> void:
    var i := idx(c.x, c.y)
    kind[i] = k
    _build_chunk_collision(Vector2i(c.x / CH, c.y / CH))
    _patch_cell(c)


# ------------------------------------------------------------------ bake chunk -> tekstur
# Tiap chunk digambar SEKALI ke sebuah SubViewport (saat loading), lalu hanya ditampilkan
# sebagai Sprite2D. Perubahan kecil (pohon ditebang/tumbuh) hanya menambal beberapa sel.
func _queue_bake() -> void:
    _bake_queue = []
    _bake_total = 0
    request_around(spawn_point())


func _chunk_of(pos: Vector2) -> Vector2i:
    return Vector2i(clampi(floori(pos.x / CHUNK_PX), 0, W / CH - 1), clampi(floori(pos.y / CHUNK_PX), 0, H / CH - 1))


# Pastikan chunk di sekitar 'pos' sudah / akan di-bake (dipanggil main saat pemain muncul & saat bermain)
func request_around(pos: Vector2) -> void:
    var c: Vector2i = _chunk_of(pos)
    var added := 0
    for dy in range(-STREAM_LOAD, STREAM_LOAD + 1):
        for dx in range(-STREAM_LOAD, STREAM_LOAD + 1):
            var ck := Vector2i(c.x + dx, c.y + dy)
            if ck.x < 0 or ck.y < 0 or ck.x >= W / CH or ck.y >= H / CH:
                continue
            if slots.has(ck) or _bake_queue.has(ck):
                continue
            _bake_queue.append(ck)
            added += 1
    if not baked:
        _bake_total += added
    var kept: Array = []
    for ck in _bake_queue:
        if maxi(absi(ck.x - c.x), absi(ck.y - c.y)) <= STREAM_KEEP:
            kept.append(ck)
        elif not baked:
            _bake_total -= 1
    _bake_queue = kept
    _bake_queue.sort_custom(func(a, b):
        return (Vector2(a) * CHUNK_PX).distance_squared_to(pos) < (Vector2(b) * CHUNK_PX).distance_squared_to(pos))
    # buang chunk yang sudah jauh
    for ck in slots.keys():
        if maxi(absi(ck.x - c.x), absi(ck.y - c.y)) > STREAM_KEEP and not _pending.has(ck):
            var sl: Dictionary = slots[ck]
            sl["vp"].queue_free()
            sl["spr"].queue_free()
            slots.erase(ck)


func bake_progress() -> float:
    if baked:
        return 1.0
    var done: int = _bake_total - _bake_queue.size() - _pending.size()
    return clampf(float(done) / float(maxi(_bake_total, 1)), 0.0, 1.0)


func _bake_step() -> void:
    # buang penggambar yang sudah selesai dirender (beberapa frame setelah UPDATE_ONCE)
    var i := 0
    while i < _pending.size():
        var sl: Dictionary = slots[_pending[i]]
        sl["free_in"] = int(sl["free_in"]) - 1
        if int(sl["free_in"]) <= 0:
            sl["drawer"].queue_free()
            sl["drawer"] = null
            _pending.remove_at(i)
        else:
            i += 1
    for n in BAKE_PER_FRAME:
        if _bake_queue.is_empty():
            break
        var nk: Vector2i = _bake_queue.pop_front()
        if not slots.has(nk):
            _bake_chunk(nk)
    if not baked and _bake_queue.is_empty() and _pending.is_empty():
        baked = true
        baked_all.emit()


func _bake_chunk(ck: Vector2i) -> void:
    var origin := Vector2(ck.x * CHUNK_PX, ck.y * CHUNK_PX)
    var vp := SubViewport.new()
    vp.size = Vector2i(CHUNK_PX, CHUNK_PX)
    vp.transparent_bg = false
    vp.disable_3d = true
    vp.gui_disable_input = true
    vp.msaa_2d = Viewport.MSAA_DISABLED
    vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
    vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
    vp.render_target_update_mode = SubViewport.UPDATE_ONCE
    add_child(vp)
    var d = Chunk.new()
    d.world = self
    d.cx = ck.x
    d.cy = ck.y
    d.position = -origin
    vp.add_child(d)
    var spr := Sprite2D.new()
    spr.centered = false
    spr.texture = vp.get_texture()
    spr.position = origin
    spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    add_child(spr)
    slots[ck] = {"vp": vp, "spr": spr, "drawer": d, "free_in": 3}
    _pending.append(ck)


# Tambal ulang sel di sekitar 'c' pada semua chunk yang bersinggungan (tanpa bake ulang penuh)
func _patch_cell(c: Vector2i) -> void:
    var x0 := maxi(c.x - 1, 0)
    var x1 := mini(c.x + 1, W - 1)
    var y0 := maxi(c.y - 1, 0)
    var y1 := mini(c.y + 1, H - 1)
    for ky in range(maxi((y0 - 1) / CH, 0), mini((y1 + 1) / CH, H / CH - 1) + 1):
        for kx in range(maxi((x0 - 1) / CH, 0), mini((x1 + 1) / CH, W / CH - 1) + 1):
            var ck := Vector2i(kx, ky)
            if not slots.has(ck):
                continue
            var ex0: int = kx * CH - 1
            var ex1: int = kx * CH + CH
            var ey0: int = ky * CH - 1
            var ey1: int = ky * CH + CH
            var list: Array = []
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    if x >= ex0 and x <= ex1 and y >= ey0 and y <= ey1:
                        list.append(Vector2i(x, y))
            if list.is_empty():
                continue
            var sl: Dictionary = slots[ck]
            var d = sl["drawer"]
            if d != null and d.cells.is_empty():
                continue   # bake penuh chunk ini masih berjalan; ia sudah memakai data terbaru
            if d == null:
                d = Chunk.new()
                d.world = self
                d.cx = kx
                d.cy = ky
                d.position = -Vector2(kx * CHUNK_PX, ky * CHUNK_PX)
                sl["vp"].add_child(d)
                sl["drawer"] = d
                d.cells = list
                _pending.append(ck)
            else:
                # sudah ada tambalan menunggu: gabungkan daftar sel
                for cc in list:
                    if not d.cells.has(cc):
                        d.cells.append(cc)
                d.cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
                d.queue_redraw()
            sl["free_in"] = 3
            sl["vp"].render_target_update_mode = SubViewport.UPDATE_ONCE


func _compute_reachable() -> void:
    reachable_mask.resize(W * H)
    var start: Vector2i = Vector2i(CENTER.x, CENTER.y + 3)
    var stack: Array[Vector2i] = [start]
    reachable_mask[idx(start.x, start.y)] = 1
    while not stack.is_empty():
        var cur: Vector2i = stack.pop_back()
        for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
            var n: Vector2i = cur + d
            if not in_bounds(n):
                continue
            var ni := idx(n.x, n.y)
            if reachable_mask[ni] == 0 and not is_solid_cell(n):
                reachable_mask[ni] = 1
                stack.append(n)
    for y in H:
        for x in W:
            var i := idx(x, y)
            if reachable_mask[i] == 1 and _is_open(Vector2i(x, y), 1) and not _in_safe_zone(x, y):
                open_by_biome[biome[i]].append(Vector2i(x, y))


func _in_safe_zone(x: int, y: int) -> bool:
    for z in safe_zones:
        if z.has_point(Vector2i(x, y)):
            return true
    return false


func _is_open(c: Vector2i, clearance: int) -> bool:
    for dy in range(-clearance, clearance + 1):
        for dx in range(-clearance, clearance + 1):
            if is_solid_cell(c + Vector2i(dx, dy)):
                return false
    return true


# Posisi acak yang bisa dijangkau di biome tertentu, menjauh dari 'avoid'
func random_pos_in_biome(b: int, avoid: Vector2 = Vector2.ZERO, min_d: float = 0.0, rng: RandomNumberGenerator = null) -> Vector2:
    if b < 0 or b >= open_by_biome.size():
        return spawn_point()
    var lst: Array = open_by_biome[b]
    if lst.is_empty():
        return spawn_point()
    for i in 80:
        var n: int = (rng.randi() if rng else randi()) % lst.size()
        var p: Vector2 = cell_center(lst[n])
        if p.distance_to(avoid) >= min_d:
            return p
    return cell_center(lst[0])


# Cari titik terbuka terdekat dari sebuah sel
func find_open(c: Vector2i, clearance: int = 1) -> Vector2:
    for r in range(0, 12):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if maxi(absi(dx), absi(dy)) != r:
                    continue
                var cc := c + Vector2i(dx, dy)
                if in_bounds(cc) and _is_open(cc, clearance):
                    return cell_center(cc)
    return cell_center(c)


func house_front(i: int) -> Vector2:
    var hs: Dictionary = houses[i]
    return Vector2((int(hs["x"]) + 2) * TILE, (int(hs["y"]) + 3) * TILE + 20.0)


func house_index(kind_name: String) -> int:
    for i in houses.size():
        if houses[i]["kind"] == kind_name:
            return i
    return 0


# ------------------------------------------------------------------ aksi mengumpulkan
# Cari tebangan/tambang/air tepat di depan pemain
func gather_target(pos: Vector2, dir: Vector2) -> Dictionary:
    for dist in [12.0, 22.0, 32.0]:
        var c := cell_of(pos + dir * dist)
        if not in_bounds(c):
            continue
        var k := get_kind(c)
        if k == K.TREE:
            return {"type": "tree", "cell": c}
        if k == K.ROCK:
            return {"type": "rock", "cell": c}
        if k == K.WATER:
            return {"type": "water", "cell": c}
    return {}


# Pukul pohon/batu. Kembalikan {"done": bool, "ore": String}
func hit_cell(c: Vector2i) -> Dictionary:
    var i := idx(c.x, c.y)
    var k: int = kind[i]
    if k != K.TREE and k != K.ROCK:
        return {"done": false}
    if not hits.has(i):
        hits[i] = 3 if k == K.TREE else 4
    hits[i] = int(hits[i]) - 1
    if int(hits[i]) > 0:
        return {"done": false}
    hits.erase(i)
    var o: String = String(ore.get(i, "stone"))
    if k == K.TREE:
        _set_kind(c, K.STUMP)
        regrow[i] = {"t": 90.0, "to": K.TREE}
    else:
        ore.erase(i)
        _set_kind(c, K.GROUND)
        regrow[i] = {"t": 150.0, "to": K.ROCK, "ore": o}
    return {"done": true, "ore": o}


func _process(delta: float) -> void:
    if not _bake_queue.is_empty() or not _pending.is_empty():
        _bake_step()
    if baked and not has_meta("in_dungeon"):
        _stream_t -= delta
        if _stream_t <= 0.0:
            _stream_t = 0.3
            if _player_ref == null or not is_instance_valid(_player_ref):
                _player_ref = get_tree().get_first_node_in_group("player")
            if _player_ref != null:
                var ck: Vector2i = _chunk_of(_player_ref.global_position)
                if ck != _stream_ck:
                    _stream_ck = ck
                    request_around(_player_ref.global_position)
    _acc += delta
    if _acc < 1.0:
        return
    var dt := _acc
    _acc = 0.0
    var done: Array = []
    for i in regrow.keys():
        regrow[i]["t"] = float(regrow[i]["t"]) - dt
        if float(regrow[i]["t"]) <= 0.0:
            var c := Vector2i(int(i) % W, int(i) / W)
            var pl = get_tree().get_first_node_in_group("player")
            if pl and pl.global_position.distance_to(cell_center(c)) < 28.0:
                regrow[i]["t"] = 5.0
                continue
            if regrow[i].has("ore"):
                ore[i] = regrow[i]["ore"]
            _set_kind(c, int(regrow[i]["to"]))
            done.append(i)
    for i in done:
        regrow.erase(i)


# ------------------------------------------------------------------ minimap
func make_minimap() -> ImageTexture:
    var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
    for y in H:
        for x in W:
            var i := idx(x, y)
            var c: Color = MAP_COL[biome[i]]
            match int(kind[i]):
                K.WATER:
                    c = Color(0.25, 0.5, 0.9)
                K.TREE:
                    c = c.darkened(0.35)
                K.DIRT, K.PLAZA:
                    c = Color(0.55, 0.38, 0.22)
                K.HOUSE:
                    c = Color(0.9, 0.3, 0.25)
                K.ROCK:
                    c = Color(0.5, 0.5, 0.55)
            img.set_pixel(x, y, c)
    return ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ gambar
func draw_chunk(ci: CanvasItem, cx: int, cy: int) -> void:
    var x0 := cx * CH
    var y0 := cy * CH
    # margin 1 sel supaya garis tepi/overhang dari sel tetangga ikut tergambar (viewport memotong)
    for y in range(maxi(y0 - 1, 0), mini(y0 + CH + 1, H)):
        for x in range(maxi(x0 - 1, 0), mini(x0 + CH + 1, W)):
            _draw_cell(ci, x, y)
    var area := Rect2(Vector2(x0 * TILE, y0 * TILE), Vector2(CHUNK_PX, CHUNK_PX))
    _draw_structures(ci, area)


func _draw_structures(ci: CanvasItem, area: Rect2) -> void:
    var portal := portal_pos()
    if Rect2(portal - Vector2(100, 100), Vector2(200, 200)).intersects(area):
        ci.draw_arc(portal, 52.0, 0.0, TAU, 48, Color(0.35, 0.85, 1.0, 0.95), 7.0)
        ci.draw_arc(portal, 39.0, 0.0, TAU, 48, Color(0.62, 0.38, 1.0, 0.9), 3.0)
        ci.draw_line(portal + Vector2(-26, 28), portal + Vector2(0, -36), Color(0.65, 0.9, 1.0), 4.0)
        ci.draw_line(portal + Vector2(0, -36), portal + Vector2(26, 28), Color(0.65, 0.9, 1.0), 4.0)
        ci.draw_line(portal + Vector2(26, 28), portal + Vector2(-26, 28), Color(0.65, 0.9, 1.0), 4.0)
        ci.draw_string(ThemeDB.fallback_font, portal + Vector2(-70, 82), ("WORLD 2 • LV 200+" if world_id == 0 else "WORLD 1 • KEMBALI"), HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color(0.75, 0.9, 1.0))
    for hs in houses:
        var hr := Rect2(float(int(hs["x"]) * TILE), float(int(hs["y"]) * TILE), float(int(hs["w"]) * TILE), float(int(hs["h"]) * TILE)).grow(56.0)
        if hr.intersects(area):
            Art.draw_house(ci, int(hs["x"]) * TILE, int(hs["y"]) * TILE, hs["w"], hs["h"], hs["kind"], hs["variant"], int(hs.get("biome", 0)))
    for lr in LAIRS:
        var lc: Vector2 = cell_center(lr["cell"])
        if Rect2(lc - Vector2(190, 190), Vector2(380, 380)).intersects(area):
            _draw_lair(ci, lc, int(lr["biome"]))
    for cs in castles:
        _draw_castle(ci, cs, area)


func _draw_castle(ci: CanvasItem, cs: Dictionary, area: Rect2) -> void:
    var cb: int = int(cs["biome"])
    var ct: Texture2D = castle_by_biome[cb]
    var px: float = float(int(cs["x"]) * TILE)
    var base_y: float = float((int(cs["y"]) + int(cs["h"])) * TILE)
    var wpx: float = float(int(cs["w"]) * TILE)
    var pos := Vector2(px, base_y - float(int(cs["vis_h"]) * TILE))
    var sz := Vector2(wpx, float(int(cs["vis_h"]) * TILE))
    if ct != null:
        sz = ct.get_size()
        pos = Vector2(floorf(px + (wpx - sz.x) / 2.0), base_y - sz.y + 4.0)
    if not Rect2(pos - Vector2(0, 24), sz + Vector2(0, 24)).intersects(area):
        return
    if ct != null:
        ci.draw_texture(ct, pos)
    else:
        var col: Color = MAP_COL[cb]
        ci.draw_rect(Rect2(pos, sz), col.darkened(0.45))
        ci.draw_rect(Rect2(pos, sz), col.lightened(0.2), false, 3.0)
    var label: String = "Kastil " + String(BNAMES[cb])
    ci.draw_string(ThemeDB.fallback_font, pos + Vector2(sz.x * 0.5 - 70.0, -6.0), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color(1, 1, 1, 0.9))


# Gambar ulang sel tertentu (tambalan). 'cells' sudah terurut baris demi baris.
func draw_cells(ci: CanvasItem, list: Array) -> void:
    var bb := Rect2(Vector2(list[0]) * TILE, Vector2(TILE, TILE))
    for c in list:
        _draw_cell(ci, c.x, c.y)
        bb = bb.merge(Rect2(Vector2(c) * TILE, Vector2(TILE, TILE)))
    _draw_structures(ci, bb)


func _draw_lair(ci: CanvasItem, c: Vector2, b: int) -> void:
    var col: Color = MAP_COL[b].darkened(0.5)
    ci.draw_arc(c, 150.0, 0.0, TAU, 56, Color(col.r, col.g, col.b, 0.55), 4.0)
    ci.draw_arc(c, 120.0, 0.0, TAU, 56, Color(col.r, col.g, col.b, 0.35), 2.0)
    for i in 8:
        var a: float = TAU * i / 8.0
        ci.draw_line(c + Vector2.from_angle(a) * 120.0, c + Vector2.from_angle(a + 0.4) * 150.0, Color(col.r, col.g, col.b, 0.6), 3.0)
        var sp: Vector2 = c + Vector2.from_angle(a + 0.2) * 162.0
        Art.ellipse(ci, sp, 7.0, 5.0, Color(0.4, 0.4, 0.45))
        Art.ellipse(ci, sp + Vector2(-1, -2), 4.0, 2.5, Color(0.6, 0.6, 0.66))


func _draw_cell(ci: CanvasItem, x: int, y: int) -> void:
    var i := idx(x, y)
    var k: int = kind[i]
    var b: int = biome[i]
    var pos := Vector2(x * TILE, y * TILE)
    var tx: Dictionary = textures[b]
    var hv := _h(x, y, 1)
    match k:
        K.WATER:
            ci.draw_texture(tx["water"], pos)
            _shore(ci, x, y, pos, b)
            if hv % 7 == 0:
                var sx: float = pos.x + float(hv % 20) + 4.0
                ci.draw_line(Vector2(sx, pos.y + 12), Vector2(sx + 6, pos.y + 12), Color(1, 1, 1, 0.35), 1.0)
            return
        K.DIRT:
            var dl: Array = dirt_by_biome[b]
            ci.draw_texture(dl[hv % dl.size()], pos)
            _dirt_edges(ci, x, y, pos, b, hv)
            return
        K.PLAZA:
            ci.draw_texture(plaza_tex, pos)
            return
    # tanah dasar + variasi warna + percampuran antar biome
    var v: float = 0.93 + float(hv % 100) / 100.0 * 0.12
    var gtex: Texture2D = tx["ground2"] if hv % 5 == 0 else tx["ground"]
    ci.draw_texture(gtex, pos, Color(v, v, v))
    for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        var nx: int = x + d.x
        var ny: int = y + d.y
        if nx >= 0 and ny >= 0 and nx < W and ny < H:
            var nb: int = biome[idx(nx, ny)]
            if nb != b and nb != 0 and b != 0 and (hv + d.x * 3 + d.y * 5) % 3 == 0:
                ci.draw_texture(textures[nb]["ground"], pos, Color(1, 1, 1, 0.7))
    match k:
        K.GROUND, K.STUMP:
            _decor(ci, b, pos, hv)
            if k == K.STUMP:
                Art.draw_stump(ci, pos + Vector2(16, 16))
        K.TREE:
            _draw_obj(ci, tx["tree"], pos)
        K.BUSH:
            _decor(ci, b, pos, hv)
            _draw_obj(ci, tx["bush"], pos)
        K.ROCK:
            Art.draw_rock(ci, pos + Vector2(16, 17), String(ore.get(i, "stone")), IDS[b], hv / 3)
        K.HOUSE:
            pass


func _draw_obj(ci: CanvasItem, t: Texture2D, pos: Vector2) -> void:
    # sprite pohon/semak: rata tengah-bawah di dalam sel, boleh lebih tinggi dari 1 tile
    var sz: Vector2 = t.get_size()
    ci.draw_texture(t, pos + Vector2(floorf((float(TILE) - sz.x) / 2.0), float(TILE) - sz.y))


func _shore(ci: CanvasItem, x: int, y: int, pos: Vector2, b: int) -> void:
    var col := Color(1, 1, 1, 0.35)
    if b == 4:
        col = Color(1.0, 0.8, 0.3, 0.5)
    if get_kind(Vector2i(x, y - 1)) != K.WATER:
        ci.draw_rect(Rect2(pos.x, pos.y, TILE, 3), col)
    if get_kind(Vector2i(x, y + 1)) != K.WATER:
        ci.draw_rect(Rect2(pos.x, pos.y + TILE - 3, TILE, 3), Color(0, 0, 0, 0.18))
    if get_kind(Vector2i(x - 1, y)) != K.WATER:
        ci.draw_rect(Rect2(pos.x, pos.y, 3, TILE), col)
    if get_kind(Vector2i(x + 1, y)) != K.WATER:
        ci.draw_rect(Rect2(pos.x + TILE - 3, pos.y, 3, TILE), col)


# Transisi tepi jalan: tanah dasar biome "merembes" ke pinggir tile jalan dengan bentuk bergerigi.
# edges.png = 12 potongan 32x32: N0 N1 E0 E1 S0 S1 W0 W1 lalu sudut NW NE SE SW.
func _dirt_edges(ci: CanvasItem, x: int, y: int, pos: Vector2, b: int = 0, hv: int = 0) -> void:
    var et: Texture2D = edge_by_biome[b]
    if et == null:
        _dirt_edges_plain(ci, x, y, pos, b)
        return
    var pn: bool = _is_path(x, y - 1)
    var pe: bool = _is_path(x + 1, y)
    var ps: bool = _is_path(x, y + 1)
    var pw: bool = _is_path(x - 1, y)
    if not pn:
        _edge_piece(ci, et, pos, hv % 2)
    if not pe:
        _edge_piece(ci, et, pos, 2 + (hv / 2) % 2)
    if not ps:
        _edge_piece(ci, et, pos, 4 + (hv / 4) % 2)
    if not pw:
        _edge_piece(ci, et, pos, 6 + (hv / 8) % 2)
    if pn and pw and not _is_path(x - 1, y - 1):
        _edge_piece(ci, et, pos, 8)
    if pn and pe and not _is_path(x + 1, y - 1):
        _edge_piece(ci, et, pos, 9)
    if ps and pe and not _is_path(x + 1, y + 1):
        _edge_piece(ci, et, pos, 10)
    if ps and pw and not _is_path(x - 1, y + 1):
        _edge_piece(ci, et, pos, 11)


func _edge_piece(ci: CanvasItem, et: Texture2D, pos: Vector2, i: int) -> void:
    ci.draw_texture_rect_region(et, Rect2(pos, Vector2(TILE, TILE)), Rect2(float(i * 32), 0.0, 32.0, 32.0))


func _dirt_edges_plain(ci: CanvasItem, x: int, y: int, pos: Vector2, b: int = 0) -> void:
    # garis tepi jalan dibuat tipis & sesuai biome supaya tekstur tanah tetap kelihatan
    var e := Color(0.30, 0.20, 0.10, 0.45)
    var g := Color(0.28, 0.5, 0.2, 0.35)
    var use_g := true
    match IDS[b]:
        "desert":
            e = Color(0.45, 0.28, 0.12, 0.4)
            use_g = false
        "snow":
            e = Color(0.32, 0.28, 0.30, 0.4)
            use_g = false
        "volcano":
            e = Color(0.08, 0.04, 0.06, 0.55)
            use_g = false
    var t := 2.0
    if not _is_path(x, y - 1):
        ci.draw_rect(Rect2(pos.x, pos.y, TILE, t), e)
        if use_g:
            ci.draw_rect(Rect2(pos.x, pos.y - 2, TILE, 2), g)
    if not _is_path(x, y + 1):
        ci.draw_rect(Rect2(pos.x, pos.y + TILE - t, TILE, t), e)
    if not _is_path(x - 1, y):
        ci.draw_rect(Rect2(pos.x, pos.y, t, TILE), e)
    if not _is_path(x + 1, y):
        ci.draw_rect(Rect2(pos.x + TILE - t, pos.y, t, TILE), e)


func _is_path(x: int, y: int) -> bool:
    var k := get_kind(Vector2i(x, y))
    return k == K.DIRT or k == K.PLAZA or k == K.HOUSE


func _ox(hv: int, shift: int, span: int) -> float:
    return float((hv >> shift) % span) + 2.0


# Hiasan kecil di tanah: rumput, kerikil, bunga, jamur, retakan, kristal es, bara
func _decor(ci: CanvasItem, b: int, pos: Vector2, hv: int) -> void:
    var r1: float = float(hv % 100) / 100.0
    var r2: float = float((hv / 100) % 100) / 100.0
    var r3: float = float((hv / 10000) % 100) / 100.0
    match b:
        0, 1:
            var gc := Color(0.2, 0.5, 0.2, 0.9)
            if r1 < 0.6:
                for j in 3:
                    var bx: float = pos.x + _ox(hv, j * 3 + 1, 26)
                    var by: float = pos.y + 8.0 + _ox(hv, j * 3 + 2, 20)
                    var lean: float = 1.0 if (hv >> (j + 4)) % 2 == 0 else -1.0
                    ci.draw_line(Vector2(bx, by), Vector2(bx + lean, by - 3.0), gc.lightened(0.1 * j), 1.0)
                    ci.draw_line(Vector2(bx + 1, by), Vector2(bx + 1 - lean, by - 4.0), gc, 1.0)
            if r2 < 0.16:
                var fx: float = pos.x + _ox(hv, 5, 24)
                var fy: float = pos.y + 8.0 + _ox(hv, 9, 16)
                var cols := [Color(1, 1, 1), Color(1, 0.9, 0.25), Color(1, 0.55, 0.7), Color(0.75, 0.55, 1.0), Color(1, 0.4, 0.35), Color(0.5, 0.75, 1.0)]
                var fc: Color = cols[int(r3 * 100.0) % cols.size()]
                ci.draw_rect(Rect2(fx, fy, 1, 3), Color(0.2, 0.55, 0.25))
                ci.draw_rect(Rect2(fx - 1, fy - 2, 3, 1), fc)
                ci.draw_rect(Rect2(fx, fy - 3, 1, 3), fc)
                ci.draw_rect(Rect2(fx, fy - 2, 1, 1), Color(1, 0.85, 0.2))
            if r2 > 0.88:
                var kx: float = pos.x + _ox(hv, 7, 24)
                var ky: float = pos.y + 8.0 + _ox(hv, 11, 18)
                ci.draw_rect(Rect2(kx, ky, 3, 2), Color(0.55, 0.55, 0.58))
                ci.draw_rect(Rect2(kx + 1, ky - 1, 2, 1), Color(0.7, 0.7, 0.72))
                ci.draw_rect(Rect2(kx + 4, ky + 1, 1, 1), Color(0.45, 0.45, 0.48))
            if r3 < 0.03:
                var mx: float = pos.x + _ox(hv, 13, 22)
                var my: float = pos.y + 12.0 + _ox(hv, 3, 12)
                ci.draw_rect(Rect2(mx, my, 1, 3), Color(0.95, 0.9, 0.8))
                ci.draw_rect(Rect2(mx - 1, my - 2, 3, 2), Color(0.85, 0.2, 0.2))
                ci.draw_rect(Rect2(mx, my - 2, 1, 1), Color.WHITE)
        2:
            if r1 < 0.22:
                var kx2: float = pos.x + _ox(hv, 2, 24)
                var ky2: float = pos.y + _ox(hv, 6, 24)
                ci.draw_rect(Rect2(kx2, ky2, 3, 2), Color(0.62, 0.5, 0.36))
                ci.draw_rect(Rect2(kx2, ky2, 2, 1), Color(0.78, 0.66, 0.5))
            if r2 < 0.2:
                var gx: float = pos.x + _ox(hv, 4, 24)
                var gy: float = pos.y + 8.0 + _ox(hv, 8, 18)
                ci.draw_line(Vector2(gx, gy), Vector2(gx - 1, gy - 4), Color(0.7, 0.6, 0.3), 1.0)
                ci.draw_line(Vector2(gx + 1, gy), Vector2(gx + 2, gy - 3), Color(0.62, 0.55, 0.28), 1.0)
            if r3 < 0.1:
                var cx2: float = pos.x + _ox(hv, 10, 18)
                var cy2: float = pos.y + _ox(hv, 12, 18)
                ci.draw_polyline(PackedVector2Array([Vector2(cx2, cy2), Vector2(cx2 + 3, cy2 + 2), Vector2(cx2 + 2, cy2 + 5), Vector2(cx2 + 6, cy2 + 7)]), Color(0.5, 0.4, 0.25, 0.7), 1.0)
            if r3 > 0.985:
                var bx2: float = pos.x + _ox(hv, 3, 20)
                var by2: float = pos.y + _ox(hv, 9, 20)
                ci.draw_line(Vector2(bx2, by2), Vector2(bx2 + 7, by2 + 2), Color(0.95, 0.93, 0.85), 2.0)
                ci.draw_circle(Vector2(bx2, by2), 1.6, Color(0.95, 0.93, 0.85))
        3:
            if r1 < 0.28:
                var sx: float = pos.x + _ox(hv, 2, 26)
                var sy: float = pos.y + _ox(hv, 6, 26)
                ci.draw_rect(Rect2(sx, sy, 1, 1), Color(1, 1, 1, 0.95))
                ci.draw_rect(Rect2(sx - 1, sy, 3, 1), Color(0.85, 0.95, 1.0, 0.7))
                ci.draw_rect(Rect2(sx, sy - 1, 1, 3), Color(0.85, 0.95, 1.0, 0.7))
            if r2 < 0.2:
                var tx2: float = pos.x + _ox(hv, 4, 24)
                var ty2: float = pos.y + 8.0 + _ox(hv, 8, 18)
                ci.draw_line(Vector2(tx2, ty2), Vector2(tx2 - 1, ty2 - 3), Color(0.55, 0.75, 0.8), 1.0)
                ci.draw_line(Vector2(tx2 + 1, ty2), Vector2(tx2 + 2, ty2 - 4), Color(0.7, 0.88, 0.92), 1.0)
            if r3 < 0.08:
                var kx3: float = pos.x + _ox(hv, 7, 22)
                var ky3: float = pos.y + 8.0 + _ox(hv, 11, 16)
                ci.draw_rect(Rect2(kx3, ky3, 3, 2), Color(0.6, 0.65, 0.75))
                ci.draw_rect(Rect2(kx3, ky3, 3, 1), Color(0.95, 0.97, 1.0))
        4:
            if r1 < 0.22:
                var ex: float = pos.x + _ox(hv, 2, 20)
                var ey: float = pos.y + _ox(hv, 6, 20)
                ci.draw_polyline(PackedVector2Array([Vector2(ex, ey), Vector2(ex + 3, ey + 2), Vector2(ex + 1, ey + 4), Vector2(ex + 5, ey + 7)]), Color(1.0, 0.45, 0.1, 0.9), 1.0)
                ci.draw_polyline(PackedVector2Array([Vector2(ex, ey), Vector2(ex + 3, ey + 2), Vector2(ex + 1, ey + 4), Vector2(ex + 5, ey + 7)]), Color(1.0, 0.8, 0.3, 0.4), 3.0)
            if r2 < 0.2:
                var kx4: float = pos.x + _ox(hv, 4, 24)
                var ky4: float = pos.y + _ox(hv, 8, 24)
                ci.draw_rect(Rect2(kx4, ky4, 3, 2), Color(0.18, 0.15, 0.18))
                ci.draw_rect(Rect2(kx4, ky4, 2, 1), Color(0.32, 0.28, 0.32))
            if r3 < 0.1:
                ci.draw_rect(Rect2(pos.x + _ox(hv, 3, 28), pos.y + _ox(hv, 9, 28), 1, 1), Color(1.0, 0.6, 0.2, 0.9))
        15:
            # Crystal Cavern: kilau kristal kecil, serpihan, retakan bercahaya
            if r1 < 0.22:
                var sx5: float = pos.x + _ox(hv, 2, 26)
                var sy5: float = pos.y + _ox(hv, 6, 26)
                ci.draw_rect(Rect2(sx5, sy5, 1, 1), Color(0.85, 0.95, 1.0, 0.95))
                ci.draw_rect(Rect2(sx5 - 1, sy5, 3, 1), Color(0.45, 0.75, 1.0, 0.55))
                ci.draw_rect(Rect2(sx5, sy5 - 1, 1, 3), Color(0.45, 0.75, 1.0, 0.55))
            if r2 < 0.14:
                var kx5: float = pos.x + _ox(hv, 4, 24)
                var ky5: float = pos.y + 8.0 + _ox(hv, 8, 18)
                ci.draw_line(Vector2(kx5, ky5), Vector2(kx5 - 1, ky5 - 4), Color(0.55, 0.45, 0.95), 1.0)
                ci.draw_line(Vector2(kx5 + 1, ky5), Vector2(kx5 + 2, ky5 - 3), Color(0.4, 0.8, 1.0), 1.0)
                ci.draw_line(Vector2(kx5 + 3, ky5), Vector2(kx5 + 3, ky5 - 5), Color(0.8, 0.6, 1.0), 1.0)
            if r3 < 0.06:
                var cx5: float = pos.x + _ox(hv, 10, 18)
                var cy5: float = pos.y + _ox(hv, 12, 18)
                ci.draw_polyline(PackedVector2Array([Vector2(cx5, cy5), Vector2(cx5 + 3, cy5 + 2), Vector2(cx5 + 2, cy5 + 5), Vector2(cx5 + 6, cy5 + 7)]), Color(0.45, 0.8, 1.0, 0.55), 1.0)
