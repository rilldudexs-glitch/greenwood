extends Node2D
# Dungeon (gua) instan. Dibuat baru tiap kali pemain masuk lewat mulut gua (cave_gate.gd) di dunia terbuka.
# Letaknya jauh di luar peta dunia (ORIGIN), jadi tidak bentrok dengan dunia terbuka. Isinya selalu:
# 6 ruangan -> ruang awal (pintu keluar) -> 4 ruang monster -> ruang bos. Bos jatuh = hadiah besar + pintu keluar baru.
# Mati di dalam = kembali ke checkpoint seperti biasa (lihat main.dungeon_leave).
#
# TIAP GUA UNIK (lihat DEFS):
#   gen   = bentuk gua: "rooms" (ruangan persegi), "cavern" (gua organik berkelok), "maze" (labirin),
#           "hub" (lingkaran ruang mengitari aula bos), "gauntlet" (lorong zig-zag panjang)
#   feat  = mekanik khas: lava / poison (lantai berbahaya), spikes / glitch (jebakan berdenyut), fall (benda
#           jatuh yang ditandai dulu), current (arus pendorong), portal (teleport antar ruang), heal (kolam pemulih),
#           doors (gerbang tertutup sampai ruangan dibersihkan), dark (gelap, hanya terang di sekitar pemain)
#   deco  = hiasan lantai khas biome, + palet warna sendiri.
#
# Dipakai oleh: main.gd (dungeon_enter / dungeon_leave), world.gd (is_solid_at untuk proyektil), hud.gd (label minimap).

const Bal = preload("res://scripts/balance.gd")
const ChestScript = preload("res://scripts/chest.gd")

const TILE := 32
const GW := 64
const GH := 44
const ORIGIN := Vector2(24000.0, 2000.0)     # peta dunia hanya 16384 x 8192 px, jadi ini aman di luar peta

# hp bos = tetap (seperti mini boss). Level monster naik dari "lo" di ruang pertama ke "hi" di ruang terakhir.
const DEFS := {
    "akar": {
        "name": "Gua Akar Tua", "biome": 1, "lo": 37, "hi": 52, "rec": 37,
        "mobs": ["bat", "spider", "goblin", "kobold", "slime"],
        "boss": {"name": "Beruang Gua Murka", "kind": "bear", "lv": 56, "hp": 10500},
        "floor": [Color(0.20, 0.17, 0.13), Color(0.23, 0.19, 0.15)], "wall": Color(0.10, 0.08, 0.07), "face": Color(0.17, 0.12, 0.09),
        "torch": Color(1.0, 0.6, 0.2), "tint": Color(0.72, 0.74, 0.80),
        "gen": "cavern", "feat": ["fall"], "fall": "root", "deco": "roots",
    },
    "makam": {
        "name": "Makam Pasir Terlupa", "biome": 2, "lo": 133, "hi": 171, "rec": 133,
        "mobs": ["mummy", "centipede", "snake", "spider", "wisp"],
        "boss": {"name": "Firaun Penjaga Makam", "kind": "mummy", "lv": 175, "hp": 107000},
        "floor": [Color(0.55, 0.45, 0.28), Color(0.50, 0.41, 0.25)], "wall": Color(0.28, 0.21, 0.12), "face": Color(0.42, 0.32, 0.18),
        "torch": Color(1.0, 0.72, 0.25), "tint": Color(0.82, 0.76, 0.70),
        "gen": "maze", "feat": ["spikes"], "plate": Color(0.85, 0.78, 0.6), "deco": "bones",
    },
    "es": {
        "name": "Gua Es Berdenyut", "biome": 3, "lo": 230, "hi": 270, "rec": 230,
        "mobs": ["wolf", "bear", "golem", "wisp", "bat"],
        "boss": {"name": "Golem Inti Es", "kind": "golem", "lv": 275, "hp": 318000},
        "floor": [Color(0.55, 0.68, 0.78), Color(0.50, 0.63, 0.74)], "wall": Color(0.22, 0.33, 0.48), "face": Color(0.34, 0.49, 0.65),
        "torch": Color(0.5, 0.85, 1.0), "tint": Color(0.74, 0.82, 0.98),
        "gen": "rooms", "feat": ["fall"], "fall": "icicle", "deco": "frost",
    },
    "magma": {
        "name": "Dapur Magma", "biome": 4, "lo": 310, "hi": 350, "rec": 310,
        "mobs": ["fiend", "red_ogre", "golem", "wisp", "bat"],
        "boss": {"name": "Raja Ogre Api", "kind": "red_ogre", "lv": 355, "hp": 670000},
        "floor": [Color(0.24, 0.13, 0.10), Color(0.28, 0.15, 0.11)], "wall": Color(0.10, 0.05, 0.05), "face": Color(0.32, 0.11, 0.07),
        "torch": Color(1.0, 0.35, 0.1), "tint": Color(0.92, 0.72, 0.68),
        "gen": "hub", "feat": ["lava"], "haz": Color(1.0, 0.38, 0.08), "haz_pct": 0.07, "deco": "ember",
    },
    "gelap": {
        "name": "Lorong Tanpa Cahaya", "biome": 5, "lo": 391, "hi": 428, "rec": 391,
        "mobs": ["shade_stalker", "dusk_bat", "night_kobold", "eclipse_spider"],
        "boss": {"name": "Penguasa Kegelapan", "kind": "shade_stalker", "lv": 435, "hp": 400000},
        "floor": [Color(0.10, 0.09, 0.14), Color(0.12, 0.10, 0.16)], "wall": Color(0.04, 0.03, 0.06), "face": Color(0.09, 0.07, 0.13),
        "torch": Color(0.65, 0.4, 1.0), "tint": Color(0.30, 0.28, 0.42),
        "gen": "gauntlet", "feat": ["dark"], "dark": 230.0, "deco": "shade",
    },
    "galat": {
        "name": "Reruntuhan Galat", "biome": 6, "lo": 466, "hi": 498, "rec": 466,
        "mobs": ["null_crawler", "glitch_golem", "ashen_fiend", "rift_serpent"],
        "boss": {"name": "Entitas Korup", "kind": "glitch_golem", "lv": 505, "hp": 520000},
        "floor": [Color(0.16, 0.13, 0.26), Color(0.19, 0.15, 0.30)], "wall": Color(0.07, 0.05, 0.14), "face": Color(0.22, 0.14, 0.38),
        "torch": Color(0.9, 0.4, 1.0), "tint": Color(0.80, 0.74, 0.96),
        "gen": "rooms", "feat": ["glitch"], "plate": Color(1.0, 0.3, 0.9), "deco": "glitch",
    },
    "palung": {
        "name": "Palung Hitam", "biome": 7, "lo": 536, "hi": 568, "rec": 536,
        "mobs": ["abyss_eel", "deep_maw", "trench_horror", "void_jelly"],
        "boss": {"name": "Raja Palung", "kind": "deep_maw", "lv": 575, "hp": 650000},
        "floor": [Color(0.05, 0.12, 0.17), Color(0.06, 0.14, 0.20)], "wall": Color(0.02, 0.05, 0.08), "face": Color(0.05, 0.16, 0.24),
        "torch": Color(0.3, 0.9, 1.0), "tint": Color(0.40, 0.55, 0.72),
        "gen": "cavern", "feat": ["dark", "current"], "dark": 300.0, "flow": Color(0.4, 0.8, 1.0), "deco": "water",
    },
    "sihir": {
        "name": "Sarang Akar Sihir", "biome": 8, "lo": 611, "hi": 648, "rec": 611,
        "mobs": ["elder_treantling", "briar_goblin", "bloom_wisp", "rootbound_ogre"],
        "boss": {"name": "Treant Penjaga", "kind": "rootbound_ogre", "lv": 655, "hp": 800000},
        "floor": [Color(0.09, 0.19, 0.14), Color(0.11, 0.22, 0.16)], "wall": Color(0.04, 0.09, 0.07), "face": Color(0.10, 0.26, 0.18),
        "torch": Color(0.5, 1.0, 0.7), "tint": Color(0.68, 0.90, 0.80),
        "gen": "maze", "feat": ["portal"], "pad": Color(0.5, 1.0, 0.75), "deco": "leaf",
    },
    "kuil": {
        "name": "Kuil Kelopak", "biome": 9, "lo": 681, "hi": 708, "rec": 681,
        "mobs": ["petal_fox", "sakura_moth", "blossom_spider", "pink_warden", "fallen_ronin"],
        "boss": {"name": "Ronin Kuil Tua", "kind": "fallen_ronin", "lv": 715, "hp": 920000},
        "floor": [Color(0.40, 0.25, 0.30), Color(0.44, 0.28, 0.33)], "wall": Color(0.20, 0.10, 0.15), "face": Color(0.42, 0.20, 0.30),
        "torch": Color(1.0, 0.6, 0.75), "tint": Color(0.92, 0.80, 0.88),
        "gen": "gauntlet", "feat": ["heal"], "pad": Color(1.0, 0.75, 0.85), "deco": "petal",
    },
    "spora": {
        "name": "Gua Spora", "biome": 10, "lo": 746, "hi": 778, "rec": 746,
        "mobs": ["myco_shaman", "toxic_toad", "cap_guardian", "fungal_bat", "mushroom_brute"],
        "boss": {"name": "Raja Jamur Gua", "kind": "cap_guardian", "lv": 785, "hp": 1050000},
        "floor": [Color(0.20, 0.10, 0.26), Color(0.23, 0.12, 0.30)], "wall": Color(0.10, 0.05, 0.14), "face": Color(0.26, 0.12, 0.34),
        "torch": Color(0.95, 0.45, 0.95), "tint": Color(0.80, 0.72, 0.92),
        "gen": "cavern", "feat": ["poison"], "haz": Color(0.45, 0.85, 0.20), "haz_pct": 0.04, "deco": "spore",
    },
    "aether": {
        "name": "Lorong Aether", "biome": 11, "lo": 811, "hi": 838, "rec": 811,
        "mobs": ["ether_drake", "aether_manta", "prism_golem", "sky_kobold", "starved_harpy"],
        "boss": {"name": "Harpy Kelaparan", "kind": "starved_harpy", "lv": 845, "hp": 1200000},
        "floor": [Color(0.50, 0.62, 0.74), Color(0.46, 0.58, 0.72)], "wall": Color(0.24, 0.32, 0.50), "face": Color(0.38, 0.52, 0.72),
        "torch": Color(0.7, 0.95, 1.0), "tint": Color(0.80, 0.88, 1.0),
        "gen": "hub", "feat": ["current"], "flow": Color(0.9, 0.98, 1.0), "deco": "cloud",
    },
    "takhta": {
        "name": "Ruang Takhta Terlupa", "biome": 12, "lo": 871, "hi": 898, "rec": 871,
        "mobs": ["ruins_sentinel", "forgotten_knight", "dust_revenant", "lost_archer"],
        "boss": {"name": "Ksatria Raja", "kind": "forgotten_knight", "lv": 905, "hp": 1400000},
        "floor": [Color(0.36, 0.32, 0.27), Color(0.33, 0.29, 0.24)], "wall": Color(0.16, 0.13, 0.10), "face": Color(0.30, 0.25, 0.19),
        "torch": Color(1.0, 0.78, 0.4), "tint": Color(0.78, 0.74, 0.70),
        "gen": "rooms", "feat": ["doors", "fall"], "fall": "debris", "deco": "ruin",
    },
    "karang": {
        "name": "Gua Karang Cahaya", "biome": 13, "lo": 926, "hi": 948, "rec": 926,
        "mobs": ["lumin_ray", "pearl_wisp", "coral_stalker", "tide_serpent", "glow_jelly"],
        "boss": {"name": "Penjaga Karang", "kind": "reef_guardian", "lv": 955, "hp": 1650000},
        "floor": [Color(0.06, 0.24, 0.28), Color(0.07, 0.27, 0.31)], "wall": Color(0.02, 0.10, 0.13), "face": Color(0.06, 0.30, 0.36),
        "torch": Color(0.4, 1.0, 0.95), "tint": Color(0.46, 0.70, 0.78),
        "gen": "hub", "feat": ["dark", "heal"], "dark": 330.0, "pad": Color(0.45, 1.0, 0.95), "deco": "coral",
    },
    "menara": {
        "name": "Menara Tanpa Ujung", "biome": 1, "lo": 1, "hi": 1, "rec": 1,
        "mobs": ["slime"],
        "boss": {"name": "Penjaga Lantai", "kind": "bear", "lv": 1, "hp": 400},
        "floor": [Color(0.20, 0.17, 0.13), Color(0.23, 0.19, 0.15)], "wall": Color(0.10, 0.08, 0.07), "face": Color(0.17, 0.12, 0.09),
        "torch": Color(0.7, 0.8, 1.0), "tint": Color(0.80, 0.82, 0.90),
        "gen": "rooms", "feat": [], "deco": "roots",
    },
    "rush": {
        "name": "Boss Rush", "biome": 1, "lo": 1, "hi": 1, "rec": 1,
        "mobs": ["slime"],
        "boss": {"name": "Bos", "kind": "bear", "lv": 1, "hp": 400},
        "floor": [Color(0.17, 0.13, 0.18), Color(0.2, 0.15, 0.21)], "wall": Color(0.08, 0.06, 0.09), "face": Color(0.15, 0.1, 0.13),
        "torch": Color(1.0, 0.55, 0.3), "tint": Color(0.9, 0.8, 0.85),
        "gen": "rooms", "feat": [], "deco": "roots",
    },
    "verdan": {
        "name": "Sarang Verdan", "biome": 14, "lo": 976, "hi": 998, "rec": 976,
        "mobs": ["verdan_stag", "canopy_hunter", "elder_boar", "vine_strangler", "grove_colossus"],
        "boss": {"name": "Kolosus Hutan", "kind": "grove_colossus", "lv": 1000, "hp": 1950000},
        "floor": [Color(0.14, 0.24, 0.10), Color(0.16, 0.27, 0.11)], "wall": Color(0.06, 0.11, 0.05), "face": Color(0.14, 0.30, 0.10),
        "torch": Color(0.85, 1.0, 0.4), "tint": Color(0.78, 0.92, 0.72),
        "gen": "maze", "feat": ["fall"], "fall": "thorn", "deco": "vine",
    },
}
# urutan gua di dunia (sesuai nomor biome); gua yang biome-nya tidak ada di dunia aktif dilewati main.gd
# Menara Tanpa Ujung: lantai acak tanpa batas. Tema, level, dan HP bos dihitung ulang tiap lantai (lihat _tower_def).
const TOWER_HP := [[1, 400], [56, 10500], [175, 107000], [355, 670000], [1000, 1950000]]
const ORDER := ["akar", "makam", "es", "magma", "gelap", "galat", "palung", "sihir", "kuil", "spora", "aether", "takhta", "karang", "verdan"]

# Pewarna & bentuk benda jatuh per gaya (fall)
const FALL_COL := {
    "root": Color(0.45, 0.30, 0.15), "icicle": Color(0.75, 0.92, 1.0),
    "debris": Color(0.60, 0.55, 0.48), "thorn": Color(0.40, 0.75, 0.20),
}

var id := "akar"
var def: Dictionary = {}
var main
var player
var grid := PackedByteArray()      # 1 = lantai, 0 = dinding
var edge := PackedByteArray()      # 1 = dinding yang bersentuhan dengan lantai (itulah yang bertabrakan)
var haz := PackedByteArray()       # 1 = lantai berbahaya (lava / racun)
var rooms: Array = []              # Rect2i (satuan sel)
var exits: Array = []              # posisi dunia pintu keluar
var rect := Rect2()
var boss_dead := false
var rstage := 0                    # tahap Boss Rush (0 = bos pertama)
var tfloor := 0                    # nomor lantai (hanya Menara Tanpa Ujung)
var nexts: Array = []              # pintu lantai berikutnya (menara)
var _hint_ms := 0
var _tint: CanvasModulate
var _t := 0.0
# --- mekanik khas
var _links: Array = []             # jalur koridor ruang i -> i+1 (untuk gerbang)
var haz_cells: Array = []          # Vector2i sel berbahaya
var plates: Array = []             # {"c": Vector2i, "ph": float, "per": float}
var plate_at := {}                 # Vector2i -> indeks plates
var pads: Array = []               # portal {"p": Vector2 (lokal), "to": int} / kolam pemulih {"p", "used"}
var heals: Array = []
var flows: Array = []              # {"r": Rect2 (lokal px), "dir": Vector2}
var doors: Array = []              # {"cells": Array, "room": int, "body": StaticBody2D, "open": bool}
var strikes: Array = []            # {"p": Vector2 (lokal), "t": float}
var _lamp: PointLight2D
var _layer: Node2D
var _haz_cd := 0.0
var _plate_cd := 0.0
var _fall_t := 2.5
var _pad_cd := 0.0
var _door_chk := 0.0


class Torch extends Node2D:
    var col := Color(1, 0.6, 0.2)
    var _t := randf() * 6.0

    func _process(d: float) -> void:
        _t += d
        queue_redraw()

    func _draw() -> void:
        var f: float = sin(_t * 9.0) * 0.5 + sin(_t * 5.3) * 0.5
        draw_circle(Vector2(0, -2), 26.0 + f * 3.0, Color(col.r, col.g, col.b, 0.07))
        draw_circle(Vector2(0, -2), 15.0 + f * 2.0, Color(col.r, col.g, col.b, 0.12))
        draw_rect(Rect2(-2, 0, 4, 9), Color(0.25, 0.17, 0.1))
        draw_circle(Vector2(0, -3), 4.5 + f * 0.8, col)
        draw_circle(Vector2(0, -4), 2.4 + f * 0.5, Color(1, 0.95, 0.7))


class ExitMark extends Node2D:
    var _t := 0.0
    var label := "KELUAR"

    func _process(d: float) -> void:
        _t += d
        queue_redraw()

    func _draw() -> void:
        var f: float = sin(_t * 3.0)
        draw_circle(Vector2.ZERO, 24.0 + f * 2.0, Color(0.4, 0.9, 1.0, 0.16))
        draw_circle(Vector2.ZERO, 15.0 + f * 1.5, Color(0.55, 0.95, 1.0, 0.30))
        draw_arc(Vector2.ZERO, 18.0, _t * 2.0, _t * 2.0 + TAU * 0.75, 24, Color(0.8, 1.0, 1.0, 0.9), 2.0)
        var font := ThemeDB.fallback_font
        draw_string_outline(font, Vector2(-24, -30), label, HORIZONTAL_ALIGNMENT_CENTER, 48, 11, 3, Color(0, 0, 0, 0.9))
        draw_string(font, Vector2(-24, -30), label, HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color(0.8, 1.0, 1.0))


# Lapisan animasi di atas lantai: jebakan, benda jatuh, arus, portal, gerbang (digambar oleh dungeon.draw_dynamic)
class Layer extends Node2D:
    var dg

    func _process(_d: float) -> void:
        queue_redraw()

    func _draw() -> void:
        if dg != null:
            dg.draw_dynamic(self)


# ------------------------------------------------------------------ akses
func contains(pos: Vector2) -> bool:
    return rect.has_point(pos)


func is_wall_at(pos: Vector2) -> bool:
    var c := Vector2i(floori((pos.x - ORIGIN.x) / TILE), floori((pos.y - ORIGIN.y) / TILE))
    if c.x < 0 or c.y < 0 or c.x >= GW or c.y >= GH:
        return true
    return grid[c.y * GW + c.x] == 0


func cell_pos(c: Vector2i) -> Vector2:
    return ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * TILE


func _lp(c: Vector2i) -> Vector2:
    return (Vector2(c) + Vector2(0.5, 0.5)) * TILE


func start_pos() -> Vector2:
    var c: Vector2i = (rooms[0] as Rect2i).get_center()
    return cell_pos(Vector2i(c.x + 1, c.y))


# ------------------------------------------------------------------ bangun
# Dipanggil main.dungeon_enter setelah node ini dimasukkan ke scene.
func build(pl) -> void:
    player = pl
    main = get_tree().current_scene
    def = DEFS[id]
    if id == "menara":
        def = _tower_def()
    elif id == "rush":
        def = _rush_def()
    position = ORIGIN
    rect = Rect2(ORIGIN, Vector2(GW * TILE, GH * TILE))
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    _generate(rng)
    _mark_edges()
    _build_collision()
    _tint = CanvasModulate.new()
    _tint.color = def["tint"]
    add_child(_tint)
    queue_redraw()
    _decorate(rng)
    _setup_features(rng)
    _populate(rng)


func _tower_def() -> Dictionary:
    var fl: int = maxi(int(Game.p.get("tower_cur", 1)), 1)
    tfloor = fl
    var plv: int = int(Game.p.get("level", 1))
    var tl: int = clampi(plv + (fl - 1) * 2, 1, 1000)
    var theme := "akar"
    for k in ORDER:
        if int(DEFS[k]["lo"]) <= tl:
            theme = String(k)
    var t: Dictionary = (DEFS[theme] as Dictionary).duplicate(true)
    t["lo"] = clampi(tl - 3, 1, 1000)
    t["hi"] = clampi(tl + 3, 1, 1000)
    t["rec"] = tl
    t["name"] = "Menara Tanpa Ujung - Lantai %d" % fl
    var gens := ["rooms", "cavern", "maze", "hub", "gauntlet"]
    t["gen"] = gens[randi() % gens.size()]
    var b: Dictionary = t["boss"]
    var bl: int = clampi(tl + 5, 1, 1000)
    b["lv"] = bl
    b["hp"] = int(Bal.interp(TOWER_HP, float(bl)) * (1.0 + 0.08 * float(fl - 1)) * Bal.comp(bl))
    b["name"] = "Penjaga Lantai %d" % fl
    return t


# Boss Rush: bos semua dungeon berurutan di satu arena, level mengikuti level pemain.
func _rush_boss(stage: int) -> Dictionary:
    var src: Dictionary = DEFS[ORDER[stage]]["boss"]
    var plv: int = int(Game.p.get("level", 1))
    var bl: int = clampi(plv + 2 + stage * 2, 1, 1000)
    return {"name": "%s (%d/%d)" % [String(src["name"]), stage + 1, ORDER.size()], "kind": String(src["kind"]), "lv": bl,
        "hp": int(Bal.interp(TOWER_HP, float(bl)) * (1.3 + 0.1 * float(stage)))}


func _rush_def() -> Dictionary:
    var t: Dictionary = (DEFS["rush"] as Dictionary).duplicate(true)
    t["rec"] = int(Game.p.get("level", 1))
    t["boss"] = _rush_boss(0)
    rstage = 0
    return t


func _rush_spawn(stage: int) -> void:
    if stage > 0 and (not is_inside_tree() or main == null or main.dungeon != self):
        return
    var bc: Vector2i = (rooms[5] as Rect2i).get_center()
    var b: Dictionary = _rush_boss(stage)
    def["boss"] = b
    _spawn_mob_at(String(b["kind"]), Vector2i(bc.x + 2, bc.y), int(b["lv"]), {"name": String(b["name"]), "hp": int(b["hp"])}, 5)
    boss_dead = false
    main.hud.show_banner("Boss Rush %d/%d: %s" % [stage + 1, ORDER.size(), String(b["name"])], 3.0)


func _feat(f: String) -> bool:
    return (def["feat"] as Array).has(f)


# kuas persegi (2r+1) di sekitar sel
func _carve(x0: int, y0: int, x1: int, y1: int) -> void:
    for y in range(maxi(y0, 1), mini(y1, GH - 2) + 1):
        for x in range(maxi(x0, 1), mini(x1, GW - 2) + 1):
            grid[y * GW + x] = 1


func _brush(c: Vector2i, r: int = 1) -> void:
    _carve(c.x - r, c.y - r, c.x + r, c.y + r)


func _carve_rect(r: Rect2i) -> void:
    _carve(r.position.x, r.position.y, r.position.x + r.size.x - 1, r.position.y + r.size.y - 1)


# koridor lebar 3 sel berbentuk L (horizontal dulu) dari a ke b; kembalikan sel-sel garis tengahnya
func _tunnel(a: Vector2i, b: Vector2i) -> Array:
    var cells: Array = []
    var p := a
    _brush(p)
    while p.x != b.x:
        p.x += signi(b.x - p.x)
        cells.append(p)
        _brush(p)
    while p.y != b.y:
        p.y += signi(b.y - p.y)
        cells.append(p)
        _brush(p)
    return cells


# terowongan berkelok (acak) dari a ke b, sesekali melebar jadi rongga
func _tunnel_wiggly(a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> Array:
    var cells: Array = []
    var p := a
    var n := 0
    while p != b and n < 900:
        n += 1
        var dx: int = signi(b.x - p.x)
        var dy: int = signi(b.y - p.y)
        var r: float = rng.randf()
        if r < 0.14:
            if rng.randf() < 0.5:
                p.x += rng.randi_range(-1, 1)
            else:
                p.y += rng.randi_range(-1, 1)
        elif dx != 0 and (dy == 0 or rng.randf() < 0.5):
            p.x += dx
        elif dy != 0:
            p.y += dy
        p.x = clampi(p.x, 3, GW - 4)
        p.y = clampi(p.y, 3, GH - 4)
        cells.append(p)
        _brush(p)
        if n % 9 == 0:
            _blob_at(p, rng.randi_range(2, 3))
    if p != b:
        cells.append_array(_tunnel(p, b))        # jaga-jaga: pastikan tersambung
    _brush(b)
    return cells


func _blob_at(c: Vector2i, r: int) -> void:
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r + 1:
                _carve(c.x + dx, c.y + dy, c.x + dx, c.y + dy)


# ruangan berbentuk gumpalan organik di dalam rect
func _blob_room(r: Rect2i, rng: RandomNumberGenerator) -> void:
    var cx: float = float(r.position.x) + float(r.size.x) * 0.5
    var cy: float = float(r.position.y) + float(r.size.y) * 0.5
    var rx: float = float(r.size.x) * 0.5
    var ry: float = float(r.size.y) * 0.5
    var sv: float = float(rng.randi() % 1000)
    for y in range(r.position.y, r.position.y + r.size.y):
        for x in range(r.position.x, r.position.x + r.size.x):
            var dx: float = (float(x) + 0.5 - cx) / rx
            var dy: float = (float(y) + 0.5 - cy) / ry
            var ang: float = atan2(dy, dx)
            var wob: float = 1.0 + 0.22 * sin(ang * 3.0 + sv) + 0.12 * sin(ang * 7.0 + sv * 1.7)
            if dx * dx + dy * dy < wob * wob * 0.9:
                _carve(x, y, x, y)


func _generate(rng: RandomNumberGenerator) -> void:
    grid.resize(GW * GH)
    grid.fill(0)
    haz.resize(GW * GH)
    haz.fill(0)
    rooms = []
    _links = []
    match String(def["gen"]):
        "cavern":
            _gen_cavern(rng)
        "maze":
            _gen_maze(rng)
        "hub":
            _gen_hub(rng)
        "gauntlet":
            _gen_gauntlet(rng)
        _:
            _gen_rooms(rng)
    if String(def["gen"]) != "maze":
        for i in range(1, rooms.size()):
            _pillars(rng, rooms[i])


# enam ruangan di grid 3x2 (ukuran acak) -- dipakai "rooms" dan "cavern"
func _grid_rooms(rng: RandomNumberGenerator) -> void:
    var bw: int = GW / 3
    var bh: int = GH / 2
    var order := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 1), Vector2i(0, 1)]
    var maxw: int = bw - 4
    var maxh: int = bh - 4
    for i in order.size():
        var b: Vector2i = order[i]
        var w: int = rng.randi_range(9, maxw)
        var h: int = rng.randi_range(9, maxh)
        if i == 0:
            w = rng.randi_range(8, 11)
            h = rng.randi_range(8, 11)
        elif i == order.size() - 1:
            w = maxw
            h = maxh
        var x: int = b.x * bw + 2 + rng.randi_range(0, maxw - w)
        var y: int = b.y * bh + 2 + rng.randi_range(0, maxh - h)
        rooms.append(Rect2i(x, y, w, h))


func _link_all(rng: RandomNumberGenerator, wiggly: bool) -> void:
    for i in rooms.size() - 1:
        var ca: Vector2i = (rooms[i] as Rect2i).get_center()
        var cb: Vector2i = (rooms[i + 1] as Rect2i).get_center()
        _links.append(_tunnel_wiggly(ca, cb, rng) if wiggly else _tunnel(ca, cb))


func _gen_rooms(rng: RandomNumberGenerator) -> void:
    _grid_rooms(rng)
    for r in rooms:
        _carve_rect(r)
    _link_all(rng, false)


func _gen_cavern(rng: RandomNumberGenerator) -> void:
    _grid_rooms(rng)
    for r in rooms:
        _blob_room(r, rng)
    _link_all(rng, true)


# labirin 15x10 sel (jalan lebar 3, dinding tebal 1) + 6 ruangan di atasnya
func _gen_maze(rng: RandomNumberGenerator) -> void:
    var mw := 15
    var mh := 10
    var vis := PackedByteArray()
    vis.resize(mw * mh)
    vis.fill(0)
    var stack: Array = [Vector2i(0, 0)]
    vis[0] = 1
    _brush(_mc(Vector2i(0, 0)))
    var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    while not stack.is_empty():
        var cur: Vector2i = stack.back()
        var opts: Array = []
        for d in dirs:
            var n: Vector2i = cur + d
            if n.x >= 0 and n.y >= 0 and n.x < mw and n.y < mh and vis[n.y * mw + n.x] == 0:
                opts.append(n)
        if opts.is_empty():
            stack.pop_back()
            continue
        var nx: Vector2i = opts[rng.randi() % opts.size()]
        vis[nx.y * mw + nx.x] = 1
        _maze_link(cur, nx)
        stack.append(nx)
    # beberapa tembok dirobohkan supaya ada jalan memutar (tidak melulu buntu)
    for k in 22:
        var c := Vector2i(rng.randi_range(0, mw - 1), rng.randi_range(0, mh - 1))
        var d: Vector2i = dirs[rng.randi() % 4]
        var n2: Vector2i = c + d
        if n2.x >= 0 and n2.y >= 0 and n2.x < mw and n2.y < mh:
            _maze_link(c, n2)
    rooms = [Rect2i(2, 2, 9, 9), Rect2i(26, 2, 9, 9), Rect2i(50, 2, 9, 9), Rect2i(26, 28, 9, 9), Rect2i(2, 28, 9, 9), Rect2i(44, 26, 15, 15)]
    for r in rooms:
        _carve_rect(r)
    # urutan ruang tidak mengikuti koridor di labirin: jalur gerbang tidak dipakai
    for i in 5:
        _links.append([])


func _mc(c: Vector2i) -> Vector2i:
    return Vector2i(3 + 4 * c.x, 3 + 4 * c.y)


func _maze_link(a: Vector2i, b: Vector2i) -> void:
    var pa: Vector2i = _mc(a)
    var pb: Vector2i = _mc(b)
    var p := pa
    _brush(p)
    while p != pb:
        p += Vector2i(signi(pb.x - p.x), signi(pb.y - p.y))
        _brush(p)


# aula bos di tengah; empat bilik di sudut, dihubungkan melingkar
func _gen_hub(rng: RandomNumberGenerator) -> void:
    rooms = [
        Rect2i(2, 17, 9, 9),                                                     # awal (kiri tengah)
        Rect2i(12 + rng.randi_range(0, 2), 2, 12, 10),                           # kiri atas
        Rect2i(40 + rng.randi_range(0, 2), 2, 12, 10),                           # kanan atas
        Rect2i(40 + rng.randi_range(0, 2), 31, 12, 10),                          # kanan bawah
        Rect2i(12 + rng.randi_range(0, 2), 31, 12, 10),                          # kiri bawah
        Rect2i(22, 14, 19, 16),                                                  # aula bos (tengah)
    ]
    for r in rooms:
        _carve_rect(r)
    _link_all(rng, false)


# lorong zig-zag panjang: ruangan kecil bergantian atas/bawah
func _gen_gauntlet(rng: RandomNumberGenerator) -> void:
    var cs := [Vector2i(7, 12), Vector2i(17, 31), Vector2i(28, 12), Vector2i(38, 31), Vector2i(48, 12)]
    rooms = [Rect2i(3, 8, 8, 8)]
    for i in range(1, 5):
        var c: Vector2i = cs[i]
        var w: int = rng.randi_range(8, 10)
        var h: int = rng.randi_range(8, 10)
        rooms.append(Rect2i(c.x - w / 2, c.y - h / 2, w, h))
    rooms.append(Rect2i(50, 22, 12, 17))
    for r in rooms:
        _carve_rect(r)
    _link_all(rng, false)


# Pilar 2x2 acak di ruangan besar; jalur tengah (baris/kolom pusat) dibiarkan bebas supaya koridor tidak tertutup
func _pillars(rng: RandomNumberGenerator, r: Rect2i) -> void:
    if r.size.x < 10 or r.size.y < 10:
        return
    var c: Vector2i = r.get_center()
    for k in 5:
        var px: int = rng.randi_range(r.position.x + 2, r.position.x + r.size.x - 4)
        var py: int = rng.randi_range(r.position.y + 2, r.position.y + r.size.y - 4)
        if absi(px - c.x) < 3 or absi(py - c.y) < 3:
            continue
        for dy in 2:
            for dx in 2:
                grid[(py + dy) * GW + px + dx] = 0


func _floor_at(x: int, y: int) -> bool:
    return x >= 0 and y >= 0 and x < GW and y < GH and grid[y * GW + x] == 1


func _mark_edges() -> void:
    edge.resize(GW * GH)
    edge.fill(0)
    for y in GH:
        for x in GW:
            if grid[y * GW + x] == 1:
                continue
            var near := false
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    if _floor_at(x + dx, y + dy):
                        near = true
            if near:
                edge[y * GW + x] = 1


func _build_collision() -> void:
    var body := StaticBody2D.new()
    body.collision_layer = 1
    body.collision_mask = 0
    add_child(body)
    for y in GH:
        var x := 0
        while x < GW:
            if edge[y * GW + x] == 1:
                var x0 := x
                while x < GW and edge[y * GW + x] == 1:
                    x += 1
                var sh := CollisionShape2D.new()
                var rs := RectangleShape2D.new()
                rs.size = Vector2((x - x0) * TILE, TILE)
                sh.shape = rs
                sh.position = Vector2(x0 * TILE + (x - x0) * TILE * 0.5, y * TILE + TILE * 0.5)
                body.add_child(sh)
            else:
                x += 1


# ------------------------------------------------------------------ gambar (statis, sekali)
func _draw() -> void:
    if grid.is_empty():
        return
    var fl: Array = def["floor"]
    var wall: Color = def["wall"]
    var face: Color = def["face"]
    var hz: Color = def.get("haz", Color(1, 0.4, 0.1))
    var dk: String = String(def.get("deco", ""))
    draw_rect(Rect2(-700, -700, GW * TILE + 1400, GH * TILE + 1400), Color(0.015, 0.015, 0.02))
    for y in GH:
        for x in GW:
            var i: int = y * GW + x
            var px: float = x * TILE
            var py: float = y * TILE
            if grid[i] == 1:
                if haz.size() == GW * GH and haz[i] == 1:
                    draw_rect(Rect2(px, py, TILE, TILE), Color(hz.r * 0.55, hz.g * 0.55, hz.b * 0.55))
                    draw_rect(Rect2(px + 3, py + 3, TILE - 6, TILE - 6), Color(hz.r * 0.8, hz.g * 0.8, hz.b * 0.8))
                    continue
                draw_rect(Rect2(px, py, TILE, TILE), fl[(x + y) % 2])
                _deco(dk, px, py, (x * 7349 + y * 1597) % 17)
            elif edge[i] == 1:
                draw_rect(Rect2(px, py, TILE, TILE), wall)
                if _floor_at(x, y + 1):                       # sisi depan dinding (menghadap selatan)
                    draw_rect(Rect2(px, py + TILE - 14, TILE, 14), face)
                    draw_line(Vector2(px, py + TILE - 14), Vector2(px + TILE, py + TILE - 14), Color(1, 1, 1, 0.10), 1.5)
                elif _floor_at(x, y - 1):                     # sisi atas dinding bawah
                    draw_rect(Rect2(px, py, TILE, 4), Color(1, 1, 1, 0.07))


# hiasan lantai khas tiap biome (hsh = 0..16 pseudo-acak per sel)
func _deco(kind: String, px: float, py: float, hsh: int) -> void:
    if hsh > 3:
        return
    match kind:
        "roots":
            if hsh == 0:
                draw_polyline(PackedVector2Array([Vector2(px + 4, py + 24), Vector2(px + 13, py + 17), Vector2(px + 22, py + 21), Vector2(px + 28, py + 12)]), Color(0.32, 0.21, 0.12, 0.8), 2.0)
            elif hsh == 1:
                draw_circle(Vector2(px + 20, py + 10), 2.5, Color(0.25, 0.4, 0.18, 0.7))
        "bones":
            if hsh == 0:
                draw_line(Vector2(px + 8, py + 20), Vector2(px + 22, py + 14), Color(0.9, 0.88, 0.78, 0.8), 2.0)
                draw_circle(Vector2(px + 8, py + 20), 2.2, Color(0.9, 0.88, 0.78, 0.8))
                draw_circle(Vector2(px + 22, py + 14), 2.2, Color(0.9, 0.88, 0.78, 0.8))
            elif hsh == 1:
                draw_arc(Vector2(px + 16, py + 22), 10.0, PI * 1.1, PI * 1.9, 8, Color(0, 0, 0, 0.14), 1.5)
        "frost":
            if hsh <= 1:
                draw_line(Vector2(px + 6, py + 10), Vector2(px + 16, py + 18), Color(1, 1, 1, 0.32), 1.5)
                draw_line(Vector2(px + 16, py + 18), Vector2(px + 26, py + 14), Color(1, 1, 1, 0.26), 1.5)
        "ember":
            if hsh == 0:
                draw_circle(Vector2(px + 10, py + 20), 3.0, Color(1.0, 0.45, 0.1, 0.5))
                draw_circle(Vector2(px + 10, py + 20), 1.4, Color(1.0, 0.8, 0.3, 0.9))
            elif hsh == 1:
                draw_line(Vector2(px + 6, py + 8), Vector2(px + 18, py + 14), Color(0, 0, 0, 0.3), 1.5)
        "shade":
            if hsh == 0:
                draw_circle(Vector2(px + 14, py + 14), 4.0, Color(0.5, 0.3, 0.8, 0.12))
            elif hsh == 1:
                draw_circle(Vector2(px + 20, py + 22), 6.0, Color(0, 0, 0, 0.25))
        "glitch":
            if hsh == 0:
                draw_rect(Rect2(px + 4, py + 10, 12, 3), Color(1.0, 0.3, 0.9, 0.55))
            elif hsh == 1:
                draw_rect(Rect2(px + 12, py + 20, 14, 3), Color(0.3, 1.0, 1.0, 0.5))
            elif hsh == 2:
                draw_line(Vector2(px, py + 6), Vector2(px + TILE, py + 6), Color(1, 1, 1, 0.12), 1.0)
        "water":
            if hsh == 0:
                draw_arc(Vector2(px + 16, py + 16), 8.0, 0.0, TAU, 12, Color(0.4, 0.8, 1.0, 0.25), 1.5)
            elif hsh == 1:
                draw_circle(Vector2(px + 22, py + 10), 2.0, Color(0.5, 0.9, 1.0, 0.3))
        "leaf":
            if hsh == 0:
                draw_colored_polygon(PackedVector2Array([Vector2(px + 8, py + 18), Vector2(px + 14, py + 10), Vector2(px + 20, py + 18), Vector2(px + 14, py + 22)]), Color(0.3, 0.7, 0.4, 0.6))
            elif hsh == 1:
                draw_circle(Vector2(px + 22, py + 8), 2.0, Color(0.9, 0.95, 0.4, 0.6))
        "petal":
            if hsh == 0:
                draw_colored_polygon(PackedVector2Array([Vector2(px + 10, py + 16), Vector2(px + 14, py + 11), Vector2(px + 18, py + 16), Vector2(px + 14, py + 20)]), Color(1.0, 0.72, 0.82, 0.75))
            elif hsh == 1:
                draw_circle(Vector2(px + 22, py + 22), 2.0, Color(1, 1, 1, 0.5))
        "spore":
            if hsh == 0:
                draw_circle(Vector2(px + 12, py + 14), 4.0, Color(0.95, 0.4, 0.95, 0.35))
            elif hsh == 1:
                draw_circle(Vector2(px + 22, py + 22), 2.0, Color(0.4, 0.95, 1.0, 0.6))
        "cloud":
            if hsh <= 1:
                draw_arc(Vector2(px + 16, py + 18), 9.0, PI, TAU, 10, Color(1, 1, 1, 0.22), 2.0)
        "ruin":
            if hsh == 0:
                draw_polyline(PackedVector2Array([Vector2(px + 4, py + 8), Vector2(px + 12, py + 15), Vector2(px + 9, py + 24)]), Color(0, 0, 0, 0.3), 1.5)
            elif hsh == 1:
                draw_rect(Rect2(px + 2, py + 2, TILE - 4, TILE - 4), Color(1, 1, 1, 0.05), false, 1.0)
        "coral":
            if hsh == 0:
                draw_circle(Vector2(px + 10, py + 20), 2.5, Color(0.4, 1.0, 0.95, 0.55))
                draw_circle(Vector2(px + 16, py + 16), 1.8, Color(0.4, 1.0, 0.95, 0.4))
            elif hsh == 1:
                draw_circle(Vector2(px + 22, py + 12), 2.0, Color(1.0, 0.6, 0.75, 0.5))
        "vine":
            if hsh == 0:
                draw_polyline(PackedVector2Array([Vector2(px + 4, py + 6), Vector2(px + 14, py + 14), Vector2(px + 10, py + 24), Vector2(px + 24, py + 28)]), Color(0.25, 0.55, 0.15, 0.7), 2.0)
        _:
            if hsh == 0:
                draw_circle(Vector2(px + 10, py + 21), 2.5, Color(0, 0, 0, 0.18))
            elif hsh == 1:
                draw_line(Vector2(px + 6, py + 8), Vector2(px + 18, py + 14), Color(0, 0, 0, 0.16), 1.5)


func _decorate(_rng: RandomNumberGenerator) -> void:
    var per: int = 1 if _feat("dark") else 2
    for r in rooms:
        var rr: Rect2i = r
        for k in per:
            var cx: int = rr.position.x + int(float(rr.size.x) * (0.28 + 0.44 * float(k) if per == 2 else 0.5))
            # cari dinding di atas lantai pertama pada kolom itu
            for y in range(rr.position.y, rr.position.y + rr.size.y):
                if _floor_at(cx, y):
                    if not _floor_at(cx, y - 1):
                        var t := Torch.new()
                        t.col = def["torch"]
                        t.position = Vector2(cx * TILE + TILE * 0.5, (y - 1) * TILE + TILE * 0.55)
                        add_child(t)
                    break


# ------------------------------------------------------------------ mekanik khas gua
func _setup_features(rng: RandomNumberGenerator) -> void:
    if _feat("lava") or _feat("poison"):
        _place_haz(rng)
    if _feat("spikes") or _feat("glitch"):
        _place_plates(rng)
    if _feat("portal"):
        _place_portals(rng)
    if _feat("heal"):
        _place_heals(rng)
    if _feat("current"):
        _place_flows()
    if _feat("doors"):
        _place_doors()
    if _feat("dark"):
        _lamp = PointLight2D.new()
        var g := Gradient.new()
        g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
        g.offsets = PackedFloat32Array([0.0, 1.0])
        var tex := GradientTexture2D.new()
        tex.gradient = g
        tex.fill = GradientTexture2D.FILL_RADIAL
        tex.fill_from = Vector2(0.5, 0.5)
        tex.fill_to = Vector2(1.0, 0.5)
        tex.width = 256
        tex.height = 256
        _lamp.texture = tex
        _lamp.texture_scale = float(def["dark"]) / 128.0
        _lamp.color = Color(1.0, 0.92, 0.75)
        _lamp.energy = 1.15
        add_child(_lamp)
    _layer = Layer.new()
    _layer.dg = self
    add_child(_layer)


# kolam lava / racun: bukan di baris/kolom tengah ruangan supaya jalur ke koridor tetap aman
func _place_haz(rng: RandomNumberGenerator) -> void:
    for ri in range(1, 6):
        var r: Rect2i = rooms[ri]
        var c: Vector2i = r.get_center()
        var pools: int = rng.randi_range(3, 5)
        for k in pools:
            var pc := Vector2i(rng.randi_range(r.position.x + 2, r.position.x + r.size.x - 3), rng.randi_range(r.position.y + 2, r.position.y + r.size.y - 3))
            var rad: int = rng.randi_range(1, 2)
            for dy in range(-rad, rad + 1):
                for dx in range(-rad, rad + 1):
                    if dx * dx + dy * dy > rad * rad + 1:
                        continue
                    var x: int = pc.x + dx
                    var y: int = pc.y + dy
                    if absi(x - c.x) < 2 or absi(y - c.y) < 2:
                        continue
                    if _floor_at(x, y) and haz[y * GW + x] == 0:
                        haz[y * GW + x] = 1
                        haz_cells.append(Vector2i(x, y))


# jebakan duri berdenyut: gugus 2x2 di ruangan 1..5 (aman -> peringatan -> aktif)
func _place_plates(rng: RandomNumberGenerator) -> void:
    var glitch: bool = _feat("glitch")
    for ri in range(1, 6):
        var r: Rect2i = rooms[ri]
        for k in 6:
            var bx: int = rng.randi_range(r.position.x + 1, r.position.x + r.size.x - 3)
            var by: int = rng.randi_range(r.position.y + 1, r.position.y + r.size.y - 3)
            var per: float = rng.randf_range(1.6, 3.6) if glitch else 3.0
            var ph: float = rng.randf() * per
            for dy in 2:
                for dx in 2:
                    var c := Vector2i(bx + dx, by + dy)
                    if _floor_at(c.x, c.y) and not plate_at.has(c):
                        plate_at[c] = plates.size()
                        plates.append({"c": c, "ph": ph, "per": per})


func _free_cell(rng: RandomNumberGenerator, r: Rect2i, avoid: float) -> Vector2i:
    for k in 40:
        var c: Vector2i = _rand_cell(rng, r, avoid)
        if haz[c.y * GW + c.x] == 0 and not plate_at.has(c):
            return c
    return r.get_center()


# dua pasang portal: ruang 1 <-> 3, ruang 2 <-> 4
func _place_portals(rng: RandomNumberGenerator) -> void:
    var pairs := [[1, 3], [2, 4]]
    for pr in pairs:
        var ca: Vector2i = _free_cell(rng, rooms[pr[0]], 2.5)
        var cb: Vector2i = _free_cell(rng, rooms[pr[1]], 2.5)
        var ia: int = pads.size()
        pads.append({"p": _lp(ca), "to": ia + 1})
        pads.append({"p": _lp(cb), "to": ia})


# kolam pemulih sekali pakai di ruang 1..4
func _place_heals(rng: RandomNumberGenerator) -> void:
    for ri in range(1, 5):
        var c: Vector2i = _free_cell(rng, rooms[ri], 3.0)
        heals.append({"p": _lp(c), "used": false})


# arus mendorong di sepanjang baris tengah ruang 1..4 (arah bergantian)
func _place_flows() -> void:
    for ri in range(1, 5):
        var r: Rect2i = rooms[ri]
        var c: Vector2i = r.get_center()
        var dir := Vector2(1, 0) if ri % 2 == 1 else Vector2(-1, 0)
        flows.append({"r": Rect2(Vector2(r.position.x + 1, c.y - 1) * TILE, Vector2(r.size.x - 2, 3) * TILE), "dir": dir})
        if r.size.y >= 10:
            flows.append({"r": Rect2(Vector2(c.x - 1, r.position.y + 1) * TILE, Vector2(3, r.size.y - 2) * TILE), "dir": Vector2(0, 1) if ri % 2 == 1 else Vector2(0, -1)})


# gerbang di pintu keluar ruang 1..4 menuju ruang berikutnya: tertutup sampai monster ruang itu habis
func _place_doors() -> void:
    for ri in range(1, 5):
        var path: Array = _links[ri]
        var rr: Rect2i = rooms[ri]
        var prev: Vector2i = rr.get_center()
        for c in path:
            var cc: Vector2i = c
            if not rr.has_point(cc):
                var cells: Array = []
                if cc.x != prev.x:
                    for dy in range(-1, 2):
                        cells.append(Vector2i(cc.x, cc.y + dy))
                else:
                    for dx in range(-1, 2):
                        cells.append(Vector2i(cc.x + dx, cc.y))
                var body := StaticBody2D.new()
                body.collision_layer = 1
                body.collision_mask = 0
                add_child(body)
                for cell in cells:
                    var sh := CollisionShape2D.new()
                    var rs := RectangleShape2D.new()
                    rs.size = Vector2(TILE, TILE)
                    sh.shape = rs
                    sh.position = _lp(cell)
                    body.add_child(sh)
                doors.append({"cells": cells, "room": ri, "body": body, "open": false})
                break
            prev = cc


# ------------------------------------------------------------------ animasi (lapisan dinamis)
func _plate_state(idx: int) -> int:
    # 0 = aman, 1 = peringatan, 2 = aktif
    var pl: Dictionary = plates[idx]
    var u: float = fposmod(_t + float(pl["ph"]), float(pl["per"])) / float(pl["per"])
    if u < 0.55:
        return 0
    if u < 0.75:
        return 1
    return 2


func draw_dynamic(ci: CanvasItem) -> void:
    if player == null or not is_instance_valid(player):
        return
    var pp: Vector2 = player.global_position - ORIGIN
    var near := 620.0
    # lava / racun berdenyut
    if not haz_cells.is_empty():
        var hz: Color = def["haz"]
        var f: float = sin(_t * 3.0) * 0.5 + 0.5
        for c in haz_cells:
            var cp: Vector2 = _lp(c)
            if cp.distance_to(pp) > near:
                continue
            ci.draw_rect(Rect2(cp - Vector2(13, 13), Vector2(26, 26)), Color(hz.r, hz.g, hz.b, 0.18 + 0.18 * sin(_t * 2.4 + float(c.x + c.y))))
            if (c.x * 3 + c.y * 5) % 4 == 0:
                ci.draw_circle(cp + Vector2(sin(_t * 1.7 + float(c.x)) * 6.0, cos(_t * 1.3 + float(c.y)) * 6.0), 2.4 + f, Color(1.0, 0.95, 0.6, 0.55))
    # jebakan duri
    if not plates.is_empty():
        var pc: Color = def.get("plate", Color(0.8, 0.8, 0.8))
        var glitch: bool = _feat("glitch")
        for i in plates.size():
            var c: Vector2i = plates[i]["c"]
            var cp2: Vector2 = _lp(c)
            if cp2.distance_to(pp) > near:
                continue
            var st: int = _plate_state(i)
            var jit := Vector2(randf_range(-1.5, 1.5), 0.0) if (glitch and st == 2) else Vector2.ZERO
            ci.draw_rect(Rect2(cp2 - Vector2(12, 12) + jit, Vector2(24, 24)), Color(0, 0, 0, 0.22))
            if st == 0:
                ci.draw_circle(cp2, 2.0, Color(pc.r, pc.g, pc.b, 0.45))
            elif st == 1:
                for k in 3:
                    ci.draw_line(cp2 + Vector2(-6 + 6 * k, 6), cp2 + Vector2(-6 + 6 * k, 0), Color(1.0, 0.85, 0.3, 0.9), 2.0)
            else:
                for k in 3:
                    ci.draw_colored_polygon(PackedVector2Array([cp2 + Vector2(-9 + 9 * k - 3, 8) + jit, cp2 + Vector2(-9 + 9 * k, -12) + jit, cp2 + Vector2(-9 + 9 * k + 3, 8) + jit]), Color(1.0, 0.35, 0.3) if not glitch else pc)
    # arus
    for fl in flows:
        var fr: Rect2 = fl["r"]
        if not fr.grow(300.0).has_point(pp):
            continue
        var fc: Color = def["flow"]
        var dir: Vector2 = fl["dir"]
        ci.draw_rect(fr, Color(fc.r, fc.g, fc.b, 0.07))
        var len_: float = fr.size.x if absf(dir.x) > 0.5 else fr.size.y
        var n: int = int(len_ / 64.0)
        for k in n + 1:
            var u: float = fposmod(_t * 0.5 + float(k) / float(n + 1), 1.0)
            var cp3: Vector2 = fr.position + (Vector2(fr.size.x * u, fr.size.y * 0.5) if absf(dir.x) > 0.5 else Vector2(fr.size.x * 0.5, fr.size.y * u))
            if dir.x < 0.0:
                cp3.x = fr.position.x + fr.size.x - (cp3.x - fr.position.x)
            if dir.y < 0.0:
                cp3.y = fr.position.y + fr.size.y - (cp3.y - fr.position.y)
            ci.draw_polyline(PackedVector2Array([cp3 - dir * 7.0 + dir.orthogonal() * 7.0, cp3 + dir * 5.0, cp3 - dir * 7.0 - dir.orthogonal() * 7.0]), Color(fc.r, fc.g, fc.b, 0.55), 2.0)
    # portal
    if not pads.is_empty():
        var pcol: Color = def["pad"]
        for pd in pads:
            var p: Vector2 = pd["p"]
            ci.draw_circle(p, 22.0 + sin(_t * 3.0) * 2.0, Color(pcol.r, pcol.g, pcol.b, 0.16))
            ci.draw_arc(p, 16.0, _t * 2.5, _t * 2.5 + TAU * 0.7, 20, Color(pcol.r, pcol.g, pcol.b, 0.9), 2.0)
            ci.draw_arc(p, 9.0, -_t * 3.0, -_t * 3.0 + TAU * 0.6, 14, Color(1, 1, 1, 0.8), 1.5)
    # kolam pemulih
    if not heals.is_empty():
        var hc: Color = def["pad"]
        for hd in heals:
            var p2: Vector2 = hd["p"]
            if bool(hd["used"]):
                ci.draw_circle(p2, 14.0, Color(0.2, 0.2, 0.25, 0.4))
                continue
            ci.draw_circle(p2, 20.0 + sin(_t * 2.0) * 2.0, Color(hc.r, hc.g, hc.b, 0.2))
            ci.draw_circle(p2, 12.0, Color(hc.r, hc.g, hc.b, 0.45))
            ci.draw_line(p2 + Vector2(-6, 0), p2 + Vector2(6, 0), Color(1, 1, 1, 0.9), 3.0)
            ci.draw_line(p2 + Vector2(0, -6), p2 + Vector2(0, 6), Color(1, 1, 1, 0.9), 3.0)
    # gerbang
    for dr in doors:
        if bool(dr["open"]):
            continue
        for cell in dr["cells"]:
            var cpd: Vector2 = _lp(cell)
            ci.draw_rect(Rect2(cpd - Vector2(15, 15), Vector2(30, 30)), Color(0.35, 0.12, 0.10, 0.92))
            ci.draw_line(cpd + Vector2(-10, -15), cpd + Vector2(-10, 15), Color(0.7, 0.7, 0.75), 3.0)
            ci.draw_line(cpd + Vector2(10, -15), cpd + Vector2(10, 15), Color(0.7, 0.7, 0.75), 3.0)
    # benda jatuh (peringatan -> hantaman)
    if not strikes.is_empty():
        var sc: Color = FALL_COL.get(String(def.get("fall", "debris")), Color.WHITE)
        for s in strikes:
            var sp: Vector2 = s["p"]
            var u2: float = clampf(float(s["t"]) / 0.9, 0.0, 1.0)
            ci.draw_circle(sp, 36.0, Color(1.0, 0.2, 0.15, 0.10 + 0.20 * u2))
            ci.draw_arc(sp, 36.0 * u2, 0.0, TAU, 24, Color(1.0, 0.4, 0.3, 0.9), 2.0)
            if u2 > 0.7:
                ci.draw_line(sp + Vector2(0, -140.0 * (1.0 - u2) * 3.3), sp, sc, 4.0)


# ------------------------------------------------------------------ isi
func _rand_cell(rng: RandomNumberGenerator, r: Rect2i, avoid_center: float) -> Vector2i:
    var c: Vector2i = r.get_center()
    for k in 30:
        var x: int = rng.randi_range(r.position.x + 1, r.position.x + r.size.x - 2)
        var y: int = rng.randi_range(r.position.y + 1, r.position.y + r.size.y - 2)
        if _floor_at(x, y) and haz[y * GW + x] == 0 and Vector2(x - c.x, y - c.y).length() >= avoid_center:
            return Vector2i(x, y)
    return c


func _spawn_mob_at(kind: String, cell: Vector2i, lv: int, mdef: Dictionary = {}, room: int = -1):
    var e = main.spawn_mob(kind, int(def["biome"]), cell_pos(cell), clampi(lv, 1, 1000), -1, mdef)
    if e != null:
        e.set_meta("dungeon", true)        # tidak hidup lagi di dunia terbuka saat mati (lihat main.enemy_died)
        e.set_meta("room", room)           # dipakai gerbang: terbuka kalau semua monster ruang ini mati
    return e


func _spawn_chest(cell: Vector2i) -> void:
    var c = ChestScript.new()
    c.uid = -1                              # peti gua tidak disimpan sebagai "sudah dibuka"
    c.biome_idx = int(def["biome"])
    c.position = cell_pos(cell)
    main.entities.add_child(c)


func _populate(rng: RandomNumberGenerator) -> void:
    var mobs: Array = def["mobs"]
    var lo: float = float(def["lo"])
    var hi: float = float(def["hi"])
    exits.append(cell_pos((rooms[0] as Rect2i).get_center() + Vector2i(-2, 0)))
    _add_exit_mark(exits[0])
    if id == "rush":
        _rush_spawn(0)
        return
    # ruang 1..4: monster, level naik tiap ruang
    for i in range(1, 5):
        var r: Rect2i = rooms[i]
        var lvl: float = lerpf(lo, hi, float(i - 1) / 3.0)
        var n: int = rng.randi_range(3, 5) + (1 if i >= 3 else 0)
        for k in n:
            var kind: String = String(mobs[rng.randi() % mobs.size()])
            _spawn_mob_at(kind, _rand_cell(rng, r, 3.0), int(lvl) + rng.randi_range(-2, 2), {}, i)
        if i == 2 or i == 4:
            _spawn_chest(_rand_cell(rng, r, 3.5))
    # ruang bos
    var br: Rect2i = rooms[5]
    var bc: Vector2i = br.get_center()
    var b: Dictionary = def["boss"]
    _spawn_mob_at(String(b["kind"]), Vector2i(bc.x + 2, bc.y), int(b["lv"]), {"name": String(b["name"]), "hp": int(b["hp"])}, 5)
    for k in 2:
        _spawn_mob_at(String(mobs[rng.randi() % mobs.size()]), _rand_cell(rng, br, 5.0), int(hi), {}, 5)


func _add_exit_mark(pos: Vector2, label: String = "KELUAR") -> void:
    var m := ExitMark.new()
    m.label = label
    m.position = pos - ORIGIN
    add_child(m)


# Dipanggil main.mini_died(-1) saat bos gua kalah
func boss_down() -> void:
    if boss_dead:
        return
    boss_dead = true
    if id == "rush":
        rstage += 1
        if rstage < ORDER.size():
            main.spawn_pickup("coin", cell_pos((rooms[5] as Rect2i).get_center()) + Vector2(0, 30), 300 + 60 * int(def["boss"]["lv"]))
            boss_dead = false
            main.hud.show_banner("Bos %d kalah! Berikutnya muncul..." % rstage, 2.5)
            main.get_tree().create_timer(3.0).timeout.connect(_rush_spawn.bind(rstage))
            return
    var br: Rect2i = rooms[5]
    var bc: Vector2i = br.get_center()
    var center: Vector2 = cell_pos(bc)
    var b: Dictionary = def["boss"]
    var lv: int = int(b["lv"])
    var biome: int = int(def["biome"])
    var luk: int = int(player.stat("luk")) if player != null else 0
    main.spawn_pickup("coin", center + Vector2(-20, 24), (200 + lv * 30) * 3)
    if id != "menara":
        main.spawn_pickup("gems", center + Vector2(20, 24), 40 + lv / 4)
    elif tfloor % 5 == 0:
        main.spawn_pickup("gems", center + Vector2(20, 24), 20 + tfloor)
    main.spawn_pickup("item:potion_hp2", center + Vector2(0, 34), 3)
    main.spawn_pickup("item:potion_mp2", center + Vector2(-34, 30), 2)
    for k in 2:
        main.spawn_pickup("item:" + Gear.roll_gear(biome, luk, 1), center + Vector2(-16 + k * 32, 48), 1)
    _spawn_chest(Vector2i(bc.x, bc.y + 3))
    var ex: Vector2 = cell_pos(Vector2i(bc.x, bc.y - 3))
    exits.append(ex)
    _add_exit_mark(ex)
    if id == "rush":
        Game.p["rush"] = ORDER.size()
        Game.p["rush_clear"] = int(Game.p.get("rush_clear", 0)) + 1
        main.hud.show_banner("BOSS RUSH SELESAI!", 4.0)
        Audio.sfx("win")
        Game.save()
        return
    if id == "menara":
        Game.p["tower"] = maxi(int(Game.p.get("tower", 0)), tfloor)
        var nx: Vector2 = cell_pos(Vector2i(bc.x + 4, bc.y - 3))
        nexts.append(nx)
        _add_exit_mark(nx, "LANTAI %d" % (tfloor + 1))
        Audio.sfx("win")
        main.hud.show_banner("Lantai %d selesai!  Pintu kiri = keluar, kanan = lantai berikut" % tfloor, 4.0)
        Game.save()
        return
    var clears: Dictionary = Game.p.get("dungeons", {})
    var first: bool = int(clears.get(id, 0)) == 0
    clears[id] = int(clears.get(id, 0)) + 1
    Game.p["dungeons"] = clears
    if first:
        Game.p["gems"] = int(Game.p["gems"]) + 100
    Audio.sfx("win")
    main.hud.show_banner("%s ditaklukkan!%s" % [String(def["name"]), "  (+100 gem, pertama kali)" if first else ""], 4.0)
    Game.save()


# Hapus semua entity yang ada di dalam gua (monster sisa, pickup, peti). Dipanggil saat keluar / pingsan.
func cleanup() -> void:
    for n in main.entities.get_children():
        if n == player or not (n is Node2D):
            continue
        if rect.has_point((n as Node2D).global_position):
            n.queue_free()


# ------------------------------------------------------------------ loop
func _physics_process(d: float) -> void:
    if player == null or player.dead or main == null:
        return
    _t += d
    if _lamp != null:
        _lamp.position = player.global_position - ORIGIN + Vector2(0, -6)
    _tick_features(d)
    for nx in nexts:
        if player.global_position.distance_to(nx) < 44.0 and Input.is_action_just_pressed("interact"):
            Game.p["tower_cur"] = tfloor + 1
            main.dungeon_next()
            return
    for e in exits:
        if player.global_position.distance_to(e) < 44.0:
            if Input.is_action_just_pressed("interact"):
                main.dungeon_leave()
                return
            if Time.get_ticks_msec() - _hint_ms > 3000:
                _hint_ms = Time.get_ticks_msec()
                main.hud.show_banner("Tekan E untuk keluar dari gua", 2.0)


func _hurt(pct: float, src: String) -> void:
    # persen dari HP maks; dikalikan balik oleh faktor pertahanan supaya tetap terasa di level tinggi
    var raw: float = float(player.max_hp) * pct * (100.0 + float(player.defense()) * 2.0) / 100.0
    player.take_damage(maxi(int(raw), 1), Vector2.ZERO, src)


func _tick_features(d: float) -> void:
    var pl: Vector2 = player.global_position - ORIGIN
    var cell := Vector2i(floori(pl.x / TILE), floori(pl.y / TILE))
    # lantai lava / racun
    if cell.x >= 0 and cell.y >= 0 and cell.x < GW and cell.y < GH and haz[cell.y * GW + cell.x] == 1:
        _haz_cd -= d
        if _haz_cd <= 0.0:
            _haz_cd = 0.6
            _hurt(float(def.get("haz_pct", 0.05)), "lava" if _feat("lava") else "poison")
    else:
        _haz_cd = 0.0
    # duri
    if plate_at.has(cell):
        if _plate_state(int(plate_at[cell])) == 2:
            _plate_cd -= d
            if _plate_cd <= 0.0:
                _plate_cd = 0.5
                _hurt(0.09, "spike")
    # arus
    for fl in flows:
        if (fl["r"] as Rect2).has_point(pl):
            player.move_and_collide((fl["dir"] as Vector2) * 85.0 * d)
            break
    # portal (cooldown supaya tidak bolak-balik)
    _pad_cd = maxf(_pad_cd - d, 0.0)
    if _pad_cd <= 0.0:
        for pd in pads:
            if (pd["p"] as Vector2).distance_to(pl) < 20.0:
                var dest: Vector2 = pads[int(pd["to"])]["p"]
                player.global_position = ORIGIN + dest + Vector2(0, 28)
                player.cam.reset_smoothing()
                _pad_cd = 1.4
                Audio.sfx("checkpoint")
                main.fx_ring(player.global_position, 60.0, def["pad"], 0.5)
                break
    # kolam pemulih
    for hd in heals:
        if not bool(hd["used"]) and (hd["p"] as Vector2).distance_to(pl) < 24.0:
            hd["used"] = true
            player.heal(int(float(player.max_hp) * 0.35), int(float(player.max_mp) * 0.35))
            main.fx_burst(player.global_position, def["pad"], 14, 70.0, 0.7, -20.0, 2.5, "star")
    # benda jatuh
    if _feat("fall"):
        _tick_falls(d, pl)
    # gerbang
    if not doors.is_empty():
        _door_chk -= d
        if _door_chk <= 0.0:
            _door_chk = 0.5
            _check_doors()


func _tick_falls(d: float, pl: Vector2) -> void:
    _fall_t -= d
    if _fall_t <= 0.0:
        _fall_t = 2.2
        for k in 6:
            var p: Vector2 = pl + Vector2(randf_range(-110.0, 110.0), randf_range(-110.0, 110.0))
            if not is_wall_at(ORIGIN + p):
                strikes.append({"p": p, "t": 0.0})
                break
    for i in range(strikes.size() - 1, -1, -1):
        var s: Dictionary = strikes[i]
        s["t"] = float(s["t"]) + d
        if float(s["t"]) >= 0.9:
            var sp: Vector2 = s["p"]
            strikes.remove_at(i)
            main.fx_burst(ORIGIN + sp, FALL_COL.get(String(def.get("fall", "debris")), Color.WHITE), 12, 90.0, 0.5, 120.0, 2.5, "dot")
            main.fx_ring(ORIGIN + sp, 36.0, Color(1.0, 0.5, 0.4), 0.3)
            if sp.distance_to(pl) < 38.0:
                _hurt(0.12, "fall")


func _check_doors() -> void:
    var enemies: Array = get_tree().get_nodes_in_group("enemies")
    for dr in doors:
        if bool(dr["open"]):
            continue
        var alive := 0
        for e in enemies:
            if is_instance_valid(e) and not e.is_queued_for_deletion() and int(e.get_meta("room", -1)) == int(dr["room"]) and int(e.get("hp")) > 0:
                alive += 1
        if alive == 0:
            dr["open"] = true
            (dr["body"] as StaticBody2D).queue_free()
            Audio.sfx("checkpoint")
            main.hud.show_banner("Gerbang terbuka!", 2.0)
