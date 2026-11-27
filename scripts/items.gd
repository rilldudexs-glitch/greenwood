extends Node

const Bal = preload("res://scripts/balance.gd")
const GearS = preload("res://scripts/gear.gd")
# Autoload "Items": database item, resep crafting, pedang/tongkat/armor, skin & gacha.

const RAR_COL := [Color(0.8, 0.8, 0.85), Color(0.45, 0.7, 1.0), Color(0.75, 0.5, 1.0), Color(1.0, 0.8, 0.25)]
const RAR_NAME := ["Biasa", "R", "SR", "SSR"]
const TIER_NAMES := ["Kulit", "Besi", "Gurun", "Es", "Magma"]
const TIER_COL := [Color(0.62, 0.42, 0.25), Color(0.72, 0.77, 0.85), Color(0.95, 0.78, 0.3), Color(0.6, 0.88, 1.0), Color(0.9, 0.36, 0.2)]
const ARMOR_SLOTS := ["chest", "legs", "boots", "gloves", "shield"]   # slot armor yang bisa di-craft
const SLOTS := ["chest", "legs", "boots", "gloves", "shield", "pick"]   # + slot beliung (alat tambang)
const SLOT_NAMES := {"chest": "Zirah", "legs": "Legging", "boots": "Sepatu", "gloves": "Sarung Tangan", "shield": "Perisai", "pick": "Beliung"}
const PNG_ITEMS := ["goo", "wood", "crown", "amber", "sunshard", "ankh", "shard", "frost", "gem", "heart", "coal", "obsidian"]

var db := {}
var recipes: Array = []
var sword_order: Array = []
var staff_order: Array = []
var skin_order: Array = []
var skins := {}


func _init() -> void:
    _build_materials()
    _build_swords()
    _build_staffs()
    _build_armor()
    _build_skins()
    _build_misc_recipes()
    _build_biome_items()
    _build_biome_gear_recipes()


func make_entry(id: String, nm: String, type: String, col: Color, price: int, desc: String = "", extra: Dictionary = {}) -> Dictionary:
    var d := {"id": id, "name": nm, "type": type, "color": col, "price": price, "desc": desc}
    for k in extra.keys():
        d[k] = extra[k]
    return d


func _add(id: String, nm: String, type: String, col: Color, price: int, desc: String = "", extra: Dictionary = {}) -> void:
    db[id] = make_entry(id, nm, type, col, price, desc, extra)


func info(id: String) -> Dictionary:
    if db.has(id):
        return db[id]
    # perlengkapan Raven ("rv_<icon>_<rarity>") dibuat saat pertama kali dibutuhkan lalu di-cache
    if id.begins_with("rv_"):
        var rd: Dictionary = Raven.make_item(id)
        if not rd.is_empty():
            db[id] = rd
            return rd
    # perlengkapan bergambar baru: senjata "gw_..." dan armor "ga_..." (lihat scripts/gear.gd)
    if id.begins_with("gw_") or id.begins_with("ga_"):
        var gd: Dictionary = Gear.make_item(id)
        if not gd.is_empty():
            db[id] = gd
            return gd
    return {"id": id, "name": id, "type": "misc", "color": Color.WHITE, "price": 0, "desc": ""}


func item_name(id: String) -> String:
    return String(info(id)["name"])


func has_png(id: String) -> bool:
    return PNG_ITEMS.has(id)


func _build_materials() -> void:
    _add("log", "Kayu Gelondong", "mat", Color(0.55, 0.36, 0.2), 3, "Hasil menebang pohon.")
    _add("stone", "Batu", "mat", Color(0.6, 0.6, 0.65), 2, "Hasil menambang.")
    _add("copper", "Bijih Tembaga", "mat", Color(0.85, 0.5, 0.3), 6, "Bijih tambang hutan.")
    _add("iron", "Bijih Besi", "mat", Color(0.75, 0.78, 0.85), 10, "Dasar senjata & armor.")
    _add("gold", "Bijih Emas", "mat", Color(1.0, 0.82, 0.25), 22, "Bijih langka gurun.")
    _add("crystal", "Kristal Es", "mat", Color(0.6, 0.9, 1.0), 24, "Bijih bening dari salju.")
    _add("ruby", "Rubi Magma", "mat", Color(0.95, 0.2, 0.3), 40, "Bijih langka gunung api.")
    _add("coal", "Bara Api", "mat", Color(0.25, 0.25, 0.3), 8, "Bahan bakar tempa.")
    _add("obsidian", "Obsidian", "mat", Color(0.35, 0.2, 0.5), 20, "Kaca vulkanik tajam.")
    _add("goo", "Lendir", "mat", Color(0.4, 0.9, 0.4), 3, "Dijatuhkan slime.")
    _add("wood", "Kayu Ajaib", "mat", Color(0.5, 0.8, 0.4), 12, "Kayu bertuah.")
    _add("crown", "Pecahan Mahkota", "mat", Color(1.0, 0.85, 0.3), 30, "Dari bos hutan.")
    _add("amber", "Amber Gurun", "mat", Color(1.0, 0.7, 0.2), 10, "Getah membatu.")
    _add("sunshard", "Pecahan Matahari", "mat", Color(1.0, 0.9, 0.4), 18, "Berkilau panas.")
    _add("ankh", "Jimat Firaun", "mat", Color(0.9, 0.8, 0.3), 45, "Dari bos gurun.")
    _add("shard", "Serpihan Es", "mat", Color(0.7, 0.9, 1.0), 10, "Dingin sekali.")
    _add("frost", "Bulu Beku", "mat", Color(0.8, 0.95, 1.0), 18, "Bulu makhluk salju.")
    _add("gem", "Permata Ratu", "mat", Color(0.5, 0.8, 1.0), 45, "Dari bos salju.")
    _add("heart", "Jantung Lava", "mat", Color(1.0, 0.4, 0.2), 60, "Dari bos gunung api.")
    _add("honey", "Madu", "mat", Color(1.0, 0.75, 0.15), 8, "Dari lebah.")
    _add("stinger", "Sengat Lebah", "mat", Color(0.9, 0.8, 0.2), 6, "Tajam & beracun.")
    _add("egg", "Telur", "mat", Color(0.98, 0.95, 0.85), 4, "Dari ayam.")
    _add("feather", "Bulu Ayam", "mat", Color(0.95, 0.95, 0.95), 3, "Ringan.")
    _add("milk", "Susu", "mat", Color(1.0, 1.0, 1.0), 6, "Dari sapi.")
    _add("meat", "Daging Mentah", "mat", Color(0.9, 0.35, 0.35), 7, "Bisa dimasak.")
    _add("leather", "Kulit", "mat", Color(0.7, 0.48, 0.3), 8, "Bahan armor awal.")
    _add("fang", "Taring Ular", "mat", Color(0.95, 0.95, 0.8), 9, "Runcing.")
    _add("venom", "Bisa Ular", "mat", Color(0.6, 0.9, 0.3), 12, "Racun pekat.")
    _add("horn", "Tanduk Fiend", "mat", Color(0.8, 0.2, 0.3), 25, "Panas membara.")
    _add("scrap", "Besi Karatan", "mat", Color(0.6, 0.42, 0.3), 7, "Rongsokan curian goblin.")
    _add("web", "Benang Laba-laba", "mat", Color(0.9, 0.95, 1.0), 9, "Kuat dan lengket.")
    _add("tusk", "Taring Ogre", "mat", Color(0.95, 0.92, 0.8), 20, "Taring raksasa, laku mahal.")
    _add("fish_carp", "Ikan Mas", "fish", Color(1.0, 0.6, 0.2), 8, "Ikan danau hutan.")
    _add("fish_bass", "Ikan Bass", "fish", Color(0.5, 0.75, 0.5), 12, "Gesit.")
    _add("fish_sand", "Ikan Oasis", "fish", Color(0.95, 0.85, 0.4), 15, "Ikan oase gurun.")
    _add("fish_ice", "Ikan Beku", "fish", Color(0.7, 0.9, 1.0), 18, "Dari danau es.")
    _add("fish_lava", "Ikan Magma", "fish", Color(1.0, 0.4, 0.2), 25, "Tahan panas!")
    _add("fish_gold", "Ikan Emas", "fish", Color(1.0, 0.85, 0.2), 60, "Langka! Bisa dijual mahal.")
    _add("grilled", "Ikan Bakar", "food", Color(0.9, 0.6, 0.3), 14, "Pulihkan 70 HP.", {"hp": 70})
    _add("steak", "Steak", "food", Color(0.75, 0.35, 0.25), 22, "Pulihkan 130 HP.", {"hp": 130})
    _add("omelet", "Telur Dadar", "food", Color(1.0, 0.9, 0.4), 16, "Pulihkan 70 MP.", {"mp": 70})
    _add("potion_hp", "Ramuan HP", "potion", Color(1.0, 0.3, 0.35), 10, "Pulihkan 80 HP.", {"hp": 80})
    _add("potion_mp", "Ramuan MP", "potion", Color(0.3, 0.5, 1.0), 10, "Pulihkan 80 MP.", {"mp": 80})
    _add("potion_hp2", "Ramuan HP Besar", "potion", Color(1.0, 0.2, 0.5), 28, "Pulihkan 250 HP.", {"hp": 250})
    _add("potion_mp2", "Ramuan MP Besar", "potion", Color(0.4, 0.3, 1.0), 28, "Pulihkan 250 MP.", {"mp": 250})


func _build_swords() -> void:
    var defs := [
        ["sw_wood", "Pedang Kayu", 6, 26.0, 1.0, "short", Color(0.7, 0.52, 0.3), "none", 1.0, {}, 0, "Pedang latihan."],
        ["sw_iron", "Pedang Besi", 11, 30.0, 1.05, "long", Color(0.82, 0.87, 0.94), "none", 1.0, {"iron": 5, "log": 2}, 30, "Seimbang & andal."],
        ["sw_katana", "Katana Ronin", 15, 34.0, 1.1, "katana", Color(0.92, 0.95, 1.0), "crit", 0.85, {"iron": 6, "leather": 2, "log": 2}, 60, "Cepat. Peluang kritis +15%."],
        ["sw_venom", "Belati Berbisa", 12, 24.0, 0.9, "dagger", Color(0.5, 0.95, 0.35), "poison", 0.7, {"fang": 4, "venom": 3, "iron": 2}, 55, "Sangat cepat. Meracuni musuh."],
        ["sw_flame", "Pedang Api", 22, 36.0, 1.2, "flame", Color(1.0, 0.5, 0.15), "burn", 1.0, {"coal": 8, "obsidian": 3, "iron": 4}, 120, "Membakar musuh."],
        ["sw_sun", "Scimitar Matahari", 19, 36.0, 1.15, "curved", Color(1.0, 0.85, 0.35), "crit", 0.95, {"amber": 6, "sunshard": 3, "gold": 4}, 100, "Kritis +15%, kilau emas."],
        ["sw_frost", "Pedang Es", 26, 38.0, 1.2, "crystal", Color(0.6, 0.9, 1.0), "freeze", 1.0, {"shard": 6, "frost": 4, "crystal": 4}, 150, "Memperlambat musuh."],
        ["sw_thunder", "Pedang Petir", 30, 40.0, 1.25, "zigzag", Color(1.0, 0.95, 0.4), "shock", 1.0, {"gold": 6, "crystal": 3, "ruby": 2}, 220, "Petir menyambar musuh sekitar."],
        ["sw_claymore", "Claymore Raksasa", 40, 44.0, 1.4, "great", Color(0.75, 0.75, 0.82), "knock", 1.5, {"iron": 10, "obsidian": 4, "log": 4}, 240, "Lambat tapi menghantam keras."],
        ["sw_plasma", "Pedang Plasma", 36, 42.0, 1.3, "plasma", Color(0.3, 1.0, 0.9), "drain", 0.9, {"ruby": 4, "crystal": 5, "ankh": 1, "heart": 1}, 400, "Menyedot HP musuh."],
    ]
    for d in defs:
        var id: String = d[0]
        _add(id, d[1], "sword", d[6], int(d[2]) * 4, d[11], {
            "dmg": d[2], "reach": d[3], "scale": d[4], "shape": d[5], "blade": d[6], "fx": d[7], "cd": d[8]})
        sword_order.append(id)
        if not (d[9] as Dictionary).is_empty():
            recipes.append({"out": id, "n": 1, "mats": d[9], "coins": d[10], "cat": "weapon"})


func _build_staffs() -> void:
    var defs := [
        ["st_0", "Tongkat Ranting", 10, 10.0, 220.0, 0, 1, false, 0.0, 1.0, Color(0.6, 0.88, 1.0), "1 bola sihir", {}, 0],
        ["st_1", "Tongkat Hutan", 16, 10.0, 250.0, 0, 1, false, 0.0, 1.4, Color(0.5, 1.0, 0.5), "bola besar & cepat", {"wood": 4, "log": 3, "goo": 4}, 50],
        ["st_2", "Tongkat Oasis", 22, 12.0, 250.0, 2, 1, false, 0.0, 1.4, Color(1.0, 0.75, 0.3), "menembus 2 musuh", {"amber": 5, "sunshard": 3, "log": 3}, 90],
        ["st_3", "Tongkat Es", 30, 15.0, 240.0, 0, 3, false, 0.0, 1.2, Color(0.6, 0.9, 1.0), "tembak 3 arah", {"shard": 6, "frost": 4, "crystal": 3}, 140],
        ["st_4", "Tongkat Magma", 42, 15.0, 230.0, 0, 1, true, 38.0, 1.6, Color(1.0, 0.45, 0.2), "mengejar & meledak", {"coal": 8, "obsidian": 4, "ruby": 3}, 200],
    ]
    for i in defs.size():
        var d: Array = defs[i]
        _add(d[0], d[1], "staff", d[10], int(d[2]) * 4, d[11], {
            "dmg": d[2], "cost": d[3], "speed": d[4], "pierce": d[5], "spread": d[6], "homing": d[7],
            "explode": d[8], "scale": d[9], "color": d[10], "tex": i})
        staff_order.append(d[0])
        if not (d[12] as Dictionary).is_empty():
            recipes.append({"out": d[0], "n": 1, "mats": d[12], "coins": d[13], "cat": "weapon"})


func _build_armor() -> void:
    var base_def := [3, 6, 10, 15, 22]
    var mult := {"chest": 1.0, "legs": 0.7, "boots": 0.4, "gloves": 0.4, "shield": 0.8}
    var amt := {"chest": 6, "legs": 5, "boots": 3, "gloves": 3, "shield": 5}
    var prim := [["leather", "log"], ["iron", "log"], ["gold", "amber"], ["crystal", "frost"], ["obsidian", "coal"]]
    for t in 5:
        for s in ARMOR_SLOTS:
            var id := "ar_%s_%d" % [s, t + 1]
            var df: int = maxi(1, roundi(float(base_def[t]) * float(mult[s])))
            var ex := {"slot": s, "def": df, "tier": t + 1, "hp": 0, "spd": 0.0, "atk": 0, "block": 0.0}
            var desc := "Pertahanan +%d" % df
            if s == "chest":
                ex["hp"] = 10 * (t + 1)
                desc += ", HP maks +%d" % int(ex["hp"])
            elif s == "legs":
                ex["hp"] = 5 * (t + 1)
                desc += ", HP maks +%d" % int(ex["hp"])
            elif s == "boots":
                ex["spd"] = 3.0 * (t + 1)
                desc += ", kecepatan +%d" % int(ex["spd"])
            elif s == "gloves":
                ex["atk"] = 2 * (t + 1)
                desc += ", serangan +%d" % int(ex["atk"])
            else:
                ex["block"] = 0.04 * (t + 1)
                desc += ", tangkis %d%%" % int(float(ex["block"]) * 100.0)
            _add(id, "%s %s" % [SLOT_NAMES[s], TIER_NAMES[t]], "armor", TIER_COL[t], df * 6, desc, ex)
            var n: int = int(amt[s]) + t
            var m := {}
            m[prim[t][0]] = n
            m[prim[t][1]] = 2 + (1 if t > 0 else 0)
            if t == 4 and (s == "chest" or s == "shield"):
                m["heart"] = 1
            recipes.append({"out": id, "n": 1, "mats": m, "coins": 20 * (t + 1) + int(amt[s]) * 4, "cat": "armor"})


func _build_misc_recipes() -> void:
    recipes.append({"out": "potion_hp", "n": 2, "mats": {"honey": 2, "goo": 2}, "coins": 0, "cat": "potion"})
    recipes.append({"out": "potion_mp", "n": 2, "mats": {"feather": 3, "goo": 2}, "coins": 0, "cat": "potion"})
    recipes.append({"out": "potion_hp2", "n": 1, "mats": {"honey": 4, "venom": 1, "milk": 2}, "coins": 10, "cat": "potion"})
    recipes.append({"out": "potion_mp2", "n": 1, "mats": {"feather": 6, "frost": 2, "milk": 2}, "coins": 10, "cat": "potion"})
    recipes.append({"out": "grilled", "n": 1, "mats": {"fish_carp": 1, "log": 1}, "coins": 0, "cat": "food"})
    recipes.append({"out": "grilled", "n": 2, "mats": {"fish_bass": 1, "fish_sand": 1, "log": 1}, "coins": 0, "cat": "food"})
    recipes.append({"out": "steak", "n": 1, "mats": {"meat": 2, "log": 1}, "coins": 0, "cat": "food"})
    recipes.append({"out": "omelet", "n": 1, "mats": {"egg": 2, "milk": 1, "log": 1}, "coins": 0, "cat": "food"})


func _build_skins() -> void:
    # tema: mecha, samurai, street. c1 = warna utama, c2 = aksen, c3 = glow/trim
    var defs := [
        ["skin_default", "Petualang", "adv", 0, Color(0.25, 0.5, 0.85), Color(0.9, 0.75, 0.3), Color(0.35, 0.25, 0.15), "Pakaian awal."],
        ["mecha_r", "Mecha Alpha", "mecha", 1, Color(0.55, 0.6, 0.68), Color(0.2, 0.75, 1.0), Color(0.3, 0.9, 1.0), "Rangka baja bersinar cyan."],
        ["mecha_sr", "Mecha Crimson", "mecha", 2, Color(0.75, 0.15, 0.2), Color(0.15, 0.15, 0.2), Color(1.0, 0.55, 0.2), "Unit tempur merah menyala."],
        ["mecha_ssr", "Mecha Prime", "mecha", 3, Color(0.95, 0.95, 1.0), Color(1.0, 0.8, 0.2), Color(0.4, 1.0, 1.0), "Unit legendaris emas-putih."],
        ["sam_r", "Ronin Pengembara", "samurai", 1, Color(0.3, 0.32, 0.45), Color(0.75, 0.75, 0.8), Color(0.9, 0.9, 0.95), "Samurai tanpa tuan."],
        ["sam_sr", "Samurai Merah", "samurai", 2, Color(0.7, 0.12, 0.15), Color(0.15, 0.12, 0.12), Color(1.0, 0.85, 0.5), "Zirah merah prajurit."],
        ["sam_ssr", "Shogun Emas", "samurai", 3, Color(0.15, 0.12, 0.2), Color(1.0, 0.8, 0.25), Color(1.0, 0.9, 0.5), "Penguasa medan perang."],
        ["st_r", "Street Hoodie", "street", 1, Color(0.35, 0.35, 0.4), Color(0.95, 0.5, 0.15), Color(1.0, 1.0, 1.0), "Hoodie santai & topi."],
        ["st_sr", "Neon Streetwear", "street", 2, Color(0.15, 0.1, 0.25), Color(0.2, 1.0, 0.6), Color(1.0, 0.3, 0.8), "Gaya neon malam hari."],
        ["st_ssr", "Street King", "street", 3, Color(0.95, 0.85, 0.2), Color(0.1, 0.1, 0.12), Color(1.0, 1.0, 1.0), "Raja jalanan berkalung emas."],
    ]
    for d in defs:
        skins[d[0]] = {"id": d[0], "name": d[1], "theme": d[2], "rarity": d[3], "c1": d[4], "c2": d[5], "c3": d[6], "desc": d[7]}
        skin_order.append(d[0])


func skins_of_rarity(r: int) -> Array:
    var out: Array = []
    for id in skin_order:
        if int(skins[id]["rarity"]) == r:
            out.append(id)
    return out


# Kembalikan id skin hasil gacha. Keberuntungan menambah sedikit peluang SR/SSR.
func gacha_roll(luk: int) -> String:
    var r := randf() * 100.0
    var ssr := 3.0 + minf(luk * 0.15, 3.0)
    var sr := 22.0 + minf(luk * 0.3, 6.0)
    var rar := 1
    if r < ssr:
        rar = 3
    elif r < ssr + sr:
        rar = 2
    var pool := skins_of_rarity(rar)
    return pool[randi() % pool.size()]


func dupe_gems(rar: int) -> int:
    return [0, 15, 40, 100][clampi(rar, 0, 3)]


# Pakai item konsumsi. true kalau terpakai.
func use_item(id: String, pl) -> bool:
    var d := info(id)
    var hp: int = int(d.get("hp", 0))
    var mp: int = int(d.get("mp", 0))
    if hp == 0 and mp == 0:
        return false
    if hp > 0 and mp == 0 and pl.hp >= pl.max_hp:
        return false
    if mp > 0 and hp == 0 and pl.mp >= pl.max_mp:
        return false
    var lv: int = pl.level()
    pl.heal(int(float(hp) * Bal.player_hp_scale(lv)), int(float(mp) * Bal.player_mp_scale(lv)))
    return true


func is_equipment(id: String) -> bool:
    var t: String = String(info(id)["type"])
    return t == "sword" or t == "staff" or t == "armor"


func is_usable(id: String) -> bool:
    var t: String = String(info(id)["type"])
    return t == "potion" or t == "food"

# ------------------------------------------------------------------ item khas tiap biome
# Tiap biome punya 2 bahan (jatuh dari monster biome itu) dan 1 makanan/ramuan yang bisa diracik dari kedua bahan
# atau dibeli di pedagang kastil biome tersebut. Id: bi_<biome>_a / _b (bahan), _c (konsumsi).
const BIOME_DROPS := {
    1: [["bi_1_a", 0.20], ["bi_1_b", 0.07]],
    2: [["bi_2_a", 0.20], ["bi_2_b", 0.07]],
    3: [["bi_3_a", 0.20], ["bi_3_b", 0.07]],
    4: [["bi_4_a", 0.20], ["bi_4_b", 0.07]],
    5: [["bi_5_a", 0.20], ["bi_5_b", 0.07]],
    6: [["bi_6_a", 0.20], ["bi_6_b", 0.07]],
    7: [["bi_7_a", 0.20], ["bi_7_b", 0.07]],
    8: [["bi_8_a", 0.20], ["bi_8_b", 0.07]],
    9: [["bi_9_a", 0.20], ["bi_9_b", 0.07]],
    10: [["bi_10_a", 0.20], ["bi_10_b", 0.07]],
    11: [["bi_11_a", 0.20], ["bi_11_b", 0.07]],
    12: [["bi_12_a", 0.20], ["bi_12_b", 0.07]],
    13: [["bi_13_a", 0.20], ["bi_13_b", 0.07]],
    14: [["bi_14_a", 0.20], ["bi_14_b", 0.07]],
    15: [["bi_15_a", 0.20], ["bi_15_b", 0.07]],
}


# Gear khas biome (Epic) yang bisa dibuat dari bahan biome itu: alasan nyata untuk berburu di satu biome.
# Syarat level mengikuti gear (lihat Gear._req_level). Bahan biome jatuh dari monster biome tersebut (BIOME_DROPS).
@warning_ignore("integer_division")
func _build_biome_gear_recipes() -> void:
    var kinds := ["sword", "bow", "axe", "hammer"]
    var armor_cost := {"chest": [20, 8], "legs": [15, 6], "boots": [10, 4], "gloves": [10, 4], "shield": [14, 6]}
    for b in range(1, 15):
        var stage: int = maxi(b - 4, 0)
        var rid: int = 3 + stage * 10
        var a: String = "bi_%d_a" % b
        var bb: String = "bi_%d_b" % b
        var base_coins: int = maxi(Bal.biome_min_lv(b), 5) * 25
        var kind: String = kinds[b % 4]
        var n: int = int(GearS.W_COUNT[kind])
        var tier: int = 4 if b > 4 else clampi(b - 1, 0, 4)
        var lo: int = tier * n / 5
        var hi: int = maxi((tier + 1) * n / 5, lo + 1)
        var widx: int = lo + (b % (hi - lo))
        recipes.append({"out": "gw_%s_%d_%d" % [kind, widx, rid], "n": 1, "mats": {a: 24, bb: 10}, "coins": base_coins * 2, "cat": "weapon"})
        var set_id: String = String(GearS.BIOME_SET[b]) if b <= 4 else String(GearS.BIOME_SET_EXT.get(b, "volcano"))
        var aidx: int = 12 + (b % 6 if b <= 4 else (b - 5) % 6)
        for slot in armor_cost.keys():
            var c: Array = armor_cost[slot]
            recipes.append({"out": "ga_%s_%s_%d_%d" % [set_id, slot, aidx, rid], "n": 1, "mats": {a: int(c[0]), bb: int(c[1])}, "coins": base_coins, "cat": "armor"})


func biome_drops(b: int) -> Array:
    return BIOME_DROPS.get(b, [])


func _build_biome_items() -> void:
    _add("bi_1_a", "Daun Penyembuh", "mat", Color(0.35, 0.75, 0.35), 12, "Daun hutan yang menenangkan luka.")
    _add("bi_1_b", "Getah Rimba", "mat", Color(0.75, 0.60, 0.25), 21, "Getah kental dari pohon tua Greenwood.")
    _add("bi_1_c", "Teh Rimba", "food", Color(0.50, 0.80, 0.40), 42, "Seduhan daun penyembuh. Pulihkan HP dan sedikit MP.", {"hp": 142, "mp": 38})
    _add("bi_2_a", "Kaktus Berair", "mat", Color(0.40, 0.75, 0.45), 16, "Kaktus gurun yang menyimpan air.")
    _add("bi_2_b", "Pasir Kaca", "mat", Color(0.95, 0.85, 0.55), 28, "Pasir yang meleleh jadi kaca oleh matahari.")
    _add("bi_2_c", "Air Oasis", "potion", Color(0.40, 0.80, 0.95), 54, "Air jernih dari oasis. Pulihkan MP dan HP.", {"hp": 65, "mp": 88})
    _add("bi_3_a", "Wol Yeti", "mat", Color(0.90, 0.95, 1.00), 20, "Wol tebal dan hangat dari Yeti.")
    _add("bi_3_b", "Kristal Salju Abadi", "mat", Color(0.70, 0.90, 1.00), 35, "Salju yang tak pernah mencair.")
    _add("bi_3_c", "Sup Hangat", "food", Color(0.95, 0.70, 0.40), 66, "Sup kental penghangat badan. Pulihkan banyak HP.", {"hp": 186, "mp": 54})
    _add("bi_4_a", "Abu Vulkanik", "mat", Color(0.45, 0.40, 0.42), 24, "Abu halus dari kawah gunung api.")
    _add("bi_4_b", "Inti Magma", "mat", Color(1.00, 0.45, 0.15), 42, "Bongkahan magma yang masih menyala.")
    _add("bi_4_c", "Ramuan Api", "food", Color(1.00, 0.40, 0.20), 78, "Ramuan panas yang membakar lelah. Pulihkan HP dan MP.", {"hp": 166, "mp": 98})
    _add("bi_5_a", "Serpihan Bayangan", "mat", Color(0.40, 0.30, 0.60), 28, "Bayangan yang memadat jadi serpihan.")
    _add("bi_5_b", "Tinta Gelap", "mat", Color(0.20, 0.15, 0.30), 49, "Tinta hitam pekat dari Shadow Reach.")
    _add("bi_5_c", "Ramuan Remang", "potion", Color(0.50, 0.35, 0.75), 90, "Ramuan senyap penjernih pikiran. Pulihkan banyak MP.", {"hp": 92, "mp": 130})
    _add("bi_6_a", "Kode Rusak", "mat", Color(0.30, 0.85, 0.90), 32, "Pecahan data yang tak bisa dibaca.")
    _add("bi_6_b", "Piksel Murni", "mat", Color(0.95, 0.40, 0.85), 56, "Satu piksel yang tidak galat.")
    _add("bi_6_c", "Elixir Glitch", "food", Color(0.50, 0.90, 0.95), 102, "Meminumnya terasa seperti mengulang waktu. Pulihkan HP dan MP.", {"hp": 201, "mp": 122})
    _add("bi_7_a", "Mutiara Palung", "mat", Color(0.20, 0.35, 0.55), 36, "Mutiara hitam dari dasar palung.")
    _add("bi_7_b", "Lumut Samudra", "mat", Color(0.30, 0.75, 0.65), 63, "Lumut berpendar dari laut dalam.")
    _add("bi_7_c", "Sup Laut Dalam", "food", Color(0.30, 0.60, 0.75), 114, "Sup kaldu laut yang pekat. Pulihkan banyak HP.", {"hp": 274, "mp": 86})
    _add("bi_8_a", "Serbuk Peri", "mat", Color(0.95, 0.90, 0.50), 40, "Serbuk berkilau yang jatuh dari sayap peri.")
    _add("bi_8_b", "Akar Bercahaya", "mat", Color(0.50, 0.90, 0.55), 70, "Akar yang berpendar lembut di malam hari.")
    _add("bi_8_c", "Madu Peri", "potion", Color(1.00, 0.80, 0.35), 126, "Madu manis penuh sihir. Pulihkan MP dan HP.", {"hp": 118, "mp": 172})
    _add("bi_9_a", "Kelopak Abadi", "mat", Color(1.00, 0.75, 0.85), 44, "Kelopak sakura yang tak pernah layu.")
    _add("bi_9_b", "Kayu Sakura", "mat", Color(0.85, 0.55, 0.55), 77, "Kayu merah muda yang harum.")
    _add("bi_9_c", "Mochi Sakura", "food", Color(1.00, 0.85, 0.90), 138, "Kue ketan manis. Pulihkan banyak HP.", {"hp": 318, "mp": 102})
    _add("bi_10_a", "Spora Cahaya", "mat", Color(0.50, 0.90, 0.70), 48, "Spora yang berpendar di gelap.")
    _add("bi_10_b", "Topi Jamur Emas", "mat", Color(0.95, 0.80, 0.30), 84, "Topi jamur langka berwarna emas.")
    _add("bi_10_c", "Sup Jamur", "food", Color(0.85, 0.55, 0.40), 150, "Sup jamur gurih. Pulihkan HP dan MP.", {"hp": 272, "mp": 170})
    _add("bi_11_a", "Serat Awan", "mat", Color(0.85, 0.92, 1.00), 52, "Serat ringan yang dipintal dari awan.")
    _add("bi_11_b", "Pecahan Petir", "mat", Color(0.90, 0.90, 0.40), 91, "Pecahan petir yang membeku jadi kristal.")
    _add("bi_11_c", "Embun Langit", "potion", Color(0.70, 0.85, 1.00), 162, "Embun murni dari langit. Pulihkan banyak MP.", {"hp": 144, "mp": 214})
    _add("bi_12_a", "Debu Kerajaan", "mat", Color(0.60, 0.58, 0.50), 56, "Debu dari kerajaan yang terlupakan.")
    _add("bi_12_b", "Lencana Kuno", "mat", Color(0.85, 0.75, 0.35), 98, "Lencana prajurit kerajaan lama.")
    _add("bi_12_c", "Anggur Raja", "food", Color(0.60, 0.20, 0.40), 174, "Anggur simpanan istana. Pulihkan HP dan MP.", {"hp": 307, "mp": 194})
    _add("bi_13_a", "Karang Bercahaya", "mat", Color(0.40, 0.85, 0.90), 60, "Karang yang memancarkan cahaya biru.")
    _add("bi_13_b", "Mutiara Cahaya", "mat", Color(0.95, 0.90, 0.95), 105, "Mutiara yang berkilau dari dalam.")
    _add("bi_13_c", "Es Karang", "potion", Color(0.55, 0.90, 0.95), 186, "Penyegar dingin dari terumbu. Pulihkan MP dan HP.", {"hp": 162, "mp": 242})
    _add("bi_14_a", "Daun Verdan", "mat", Color(0.30, 0.70, 0.30), 64, "Daun raksasa dari kanopi Verdan.")
    _add("bi_14_b", "Getah Akar Dunia", "mat", Color(0.60, 0.85, 0.40), 112, "Getah dari Akar Dunia yang masih hidup.")
    _add("bi_14_c", "Teh Akar", "food", Color(0.55, 0.75, 0.35), 198, "Teh pekat dari Akar Dunia. Pulihkan banyak HP.", {"hp": 428, "mp": 142})
    _add("bi_15_a", "Pecahan Prisma", "mat", Color(0.80, 0.70, 1.00), 68, "Pecahan kristal pemecah cahaya.")
    _add("bi_15_b", "Debu Kristal", "mat", Color(0.90, 0.85, 1.00), 119, "Debu halus yang berkilauan.")
    _add("bi_15_c", "Nektar Kristal", "food", Color(0.85, 0.75, 1.00), 210, "Cairan berkilau penuh tenaga. Pulihkan HP dan MP.", {"hp": 360, "mp": 230})
    recipes.append({"out": "bi_1_c", "n": 1, "mats": {"bi_1_a": 3, "bi_1_b": 1}, "coins": 15, "cat": "food"})
    recipes.append({"out": "bi_2_c", "n": 1, "mats": {"bi_2_a": 3, "bi_2_b": 1}, "coins": 20, "cat": "potion"})
    recipes.append({"out": "bi_3_c", "n": 1, "mats": {"bi_3_a": 3, "bi_3_b": 1}, "coins": 25, "cat": "food"})
    recipes.append({"out": "bi_4_c", "n": 1, "mats": {"bi_4_a": 3, "bi_4_b": 1}, "coins": 30, "cat": "food"})
    recipes.append({"out": "bi_5_c", "n": 1, "mats": {"bi_5_a": 3, "bi_5_b": 1}, "coins": 35, "cat": "potion"})
    recipes.append({"out": "bi_6_c", "n": 1, "mats": {"bi_6_a": 3, "bi_6_b": 1}, "coins": 40, "cat": "food"})
    recipes.append({"out": "bi_7_c", "n": 1, "mats": {"bi_7_a": 3, "bi_7_b": 1}, "coins": 45, "cat": "food"})
    recipes.append({"out": "bi_8_c", "n": 1, "mats": {"bi_8_a": 3, "bi_8_b": 1}, "coins": 50, "cat": "potion"})
    recipes.append({"out": "bi_9_c", "n": 1, "mats": {"bi_9_a": 3, "bi_9_b": 1}, "coins": 55, "cat": "food"})
    recipes.append({"out": "bi_10_c", "n": 1, "mats": {"bi_10_a": 3, "bi_10_b": 1}, "coins": 60, "cat": "food"})
    recipes.append({"out": "bi_11_c", "n": 1, "mats": {"bi_11_a": 3, "bi_11_b": 1}, "coins": 65, "cat": "potion"})
    recipes.append({"out": "bi_12_c", "n": 1, "mats": {"bi_12_a": 3, "bi_12_b": 1}, "coins": 70, "cat": "food"})
    recipes.append({"out": "bi_13_c", "n": 1, "mats": {"bi_13_a": 3, "bi_13_b": 1}, "coins": 75, "cat": "potion"})
    recipes.append({"out": "bi_14_c", "n": 1, "mats": {"bi_14_a": 3, "bi_14_b": 1}, "coins": 80, "cat": "food"})
    recipes.append({"out": "bi_15_c", "n": 1, "mats": {"bi_15_a": 3, "bi_15_b": 1}, "coins": 85, "cat": "food"})
