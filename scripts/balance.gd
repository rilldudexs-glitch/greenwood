extends RefCounted
# Semua angka keseimbangan (level, HP, damage, XP) ada di sini. Mau lebih gampang / susah?
# Ubah tabel ANCHOR di bawah; fungsi lain otomatis mengikuti. Tidak ada node/proses, jadi gratis untuk FPS.
#
# Pemakaian:  const Bal = preload("res://scripts/balance.gd")   lalu   Bal.mob_hp(30)

const LV_MAX := 1000

# [level, nilai] -> nilai di antara dua titik dihitung lurus (interpolasi).
# HP satuan monster (slime = 1x). Monster besar = kelipatannya; tidak ada monster biasa > MOB_HP_CAP.
const HP_ANCHOR := [[1, 30.0], [10, 60.0], [25, 140.0], [40, 230.0], [60, 350.0], [100, 630.0], [150, 1060.0], [200, 1600.0], [250, 2230.0], [300, 2970.0], [350, 3800.0], [400, 4740.0], [500, 6500.0], [600, 8500.0], [700, 10800.0], [800, 13500.0], [900, 16500.0], [1000, 20000.0], [1200, 27000.0]]
const MOB_HP_CAP := 60000
# Damage satuan monster (slime = 1x).
const DMG_ANCHOR := [[1, 8.0], [10, 30.0], [25, 80.0], [40, 140.0], [60, 230.0], [100, 360.0], [150, 530.0], [200, 700.0], [250, 860.0], [300, 1030.0], [350, 1200.0], [400, 1360.0], [500, 1600.0], [600, 1850.0], [700, 2100.0], [800, 2350.0], [900, 2600.0], [1000, 2900.0], [1200, 3500.0]]
# Perkiraan jumlah monster yang harus dikalahkan untuk naik 1 level (awal gampang, akhir sangat berat).
const KILLS_ANCHOR := [[1, 6.0], [8, 9.0], [20, 25.0], [35, 70.0], [50, 90.0], [60, 100.0], [100, 100.0], [150, 120.0], [200, 140.0], [250, 165.0], [300, 195.0], [350, 225.0], [400, 225.0], [500, 260.0], [600, 300.0], [700, 340.0], [800, 380.0], [900, 420.0], [1000, 460.0], [1200, 550.0]]
const AVG_MOB_XP_FACTOR := 1.6

# Level bos tiap wilayah (Ent, Kalajengking, Yeti, Naga) dan HP-nya.
const BOSS_LEVEL := [150, 230, 310, 400]
const BOSS_HP := [320000, 850000, 1650000, 4000000]
# Rentang level monster biasa per bioma: desa, hutan, gurun, salju, gunung api.
const BIOME_LV := [[1, 1], [1, 100], [100, 190], [190, 270], [270, 350], [350, 430], [430, 500], [500, 570], [570, 650], [650, 710], [710, 780], [780, 840], [840, 900], [900, 950], [950, 1000]]
# Mini boss: musuh elit bernama, 2 per bioma. HP di antara monster biasa dan bos besar.
# kind = jenis monster dasar (gambar & jurus), lv = level, hp = HP maksimum.
const MINI := [
    {"name": "Serigala Alfa", "kind": "wolf", "biome": 1, "lv": 90, "hp": 19000},
    {"name": "Raja Kobold", "kind": "kobold", "biome": 1, "lv": 80, "hp": 15000},
    {"name": "Kelabang Raksasa", "kind": "centipede", "biome": 2, "lv": 170, "hp": 70000},
    {"name": "Mumi Firaun Muda", "kind": "mummy", "biome": 2, "lv": 185, "hp": 79000},
    {"name": "Beruang Kutub Alfa", "kind": "bear", "biome": 3, "lv": 255, "hp": 190000},
    {"name": "Golem Es Kuno", "kind": "golem", "biome": 3, "lv": 245, "hp": 170000},
    {"name": "Ratu Kelelawar Darah", "kind": "bat", "biome": 4, "lv": 340, "hp": 410000},
    {"name": "Golem Magma", "kind": "golem", "biome": 4, "lv": 350, "hp": 470000},
    {"name":"Shade Alpha","kind":"shade_stalker","biome":5,"lv":390,"hp":320000},
    {"name":"Null Warden","kind":"glitch_golem","biome":6,"lv":460,"hp":410000},
    {"name":"Trench Devourer","kind":"deep_maw","biome":7,"lv":520,"hp":520000},
    {"name":"Elder Briar","kind":"rootbound_ogre","biome":8,"lv":590,"hp":650000},
    {"name":"Ronin of Petals","kind":"fallen_ronin","biome":9,"lv":640,"hp":740000},
    {"name":"Myco Tyrant","kind":"cap_guardian","biome":10,"lv":700,"hp":850000},
    {"name":"Aether Harrier","kind":"starved_harpy","biome":11,"lv":760,"hp":980000},
    {"name":"Lost Royal Guard","kind":"forgotten_knight","biome":12,"lv":820,"hp":1150000},
    {"name":"Lumina Guardian","kind":"reef_guardian","biome":13,"lv":880,"hp":1350000},
    {"name":"Verdan Alpha Stag","kind":"verdan_stag","biome":14,"lv":940,"hp":1550000},
    {"name":"Worldroot Herald","kind":"grove_colossus","biome":14,"lv":980,"hp":1800000},
]
const MINI_RESPAWN := 300.0

# Konten boss ekspansi. Boss lama tetap memakai roster dan identitas aslinya.
const EXPANSION_BOSSES := [
    {"name":"Warden of Shadows","style":"warden","biome":5,"lv":430,"hp":5200000},
    {"name":"The Unwritten","style":"unwritten","biome":6,"lv":500,"hp":6500000},
    {"name":"Abyss Leviathan","style":"leviathan","biome":7,"lv":570,"hp":7800000},
    {"name":"Elder Verdant","style":"verdant","biome":8,"lv":650,"hp":9200000},
    {"name":"Sakura Empress","style":"sakura","biome":9,"lv":710,"hp":10800000},
    {"name":"Myconid King","style":"myconid","biome":10,"lv":780,"hp":12500000},
    {"name":"Ether Sovereign","style":"ether","biome":11,"lv":840,"hp":14500000},
    {"name":"Forgotten Monarch","style":"monarch","biome":12,"lv":900,"hp":16500000},
    {"name":"Lumina Tidecaller","style":"lumina","biome":13,"lv":950,"hp":18500000},
    {"name":"Verdant Colossus","style":"colossus","biome":14,"lv":1000,"hp":21000000},
    {"name":"Worldroot Devourer","style":"devourer","biome":14,"lv":1200,"hp":30000000},
]

# 60 identitas musuh ekspansi, dipetakan ke rig/AI yang sudah tersedia agar langsung kompatibel.
const EXPANSION_ENEMIES := [
    "Umbral Slime","Gloomfang Wolf","Shade Stalker","Dusk Bat","Night Kobold","Eclipse Spider",
    "Hollow Wisp","Gravebound Ogre","Ashen Fiend","Rift Serpent","Null Crawler","Glitch Golem",
    "Abyss Eel","Deep Maw","Trench Horror","Blackfin Stalker","Void Jelly","Drowned Mummy",
    "Thorn Sprite","Mossback Bear","Elder Treantling","Briar Goblin","Bloom Wisp","Rootbound Ogre",
    "Petal Fox","Sakura Moth","Crimson Koi","Blossom Spider","Pink Warden","Fallen Ronin",
    "Sporeling","Mushroom Brute","Myco Shaman","Toxic Toad","Cap Guardian","Fungal Bat",
    "Ether Drake","Cloud Wisp","Aether Manta","Prism Golem","Sky Kobold","Starved Harpy",
    "Ruins Sentinel","Forgotten Knight","Dust Revenant","Relic Scorpion","Lost Archer","Ancient Mummy",
    "Lumin Ray","Reef Guardian","Pearl Wisp","Coral Stalker","Tide Serpent","Glow Jelly",
    "Verdan Stag","Canopy Hunter","Elder Boar","Vine Strangler","Pollen Sprite","Grove Colossus"
]

# ------------------------------------------------------------------ ZONA LEVELING
# Tempat berburu tetap: monster dikumpulkan di satu lingkaran kecil dengan rentang level sempit,
# jadi pemain di level berapa pun tinggal pergi ke zona yang cocok. Respawn zona cepat (ZONE_RESPAWN).
#   off   = posisi zona dalam satuan tile dari tengah desa (x+ = timur, y+ = selatan).
#           Kalau sel itu tidak terbuka (pohon/air), otomatis digeser ke tempat terbuka terdekat.
#   lv    = [level terendah, level tertinggi] monster di zona itu.
#   mobs  = jenis monster -> jumlah. Monster elit (ZONE_ELITE) selalu level tertinggi zona.
# Mau tambah / pindah / ubah zona? Cukup edit tabel ini, tidak perlu menyentuh kode lain.
const ZONE_RADIUS := 200.0                 # px (~6 tile)
const ZONE_RESPAWN := 45.0                 # detik; monster zona hidup lagi jauh lebih cepat dari sebaran biasa
const ZONE_ELITE := ["ogre", "red_ogre", "golem", "bear"]
const ZONES := [
    # --- Hutan (Lv 1-100): dari tepi desa makin jauh ke barat makin tinggi
    {"name": "Padang Slime", "biome": 1, "off": Vector2i(-24, 9), "lv": [1, 5], "mobs": {"slime": 9, "bee": 5}},
    {"name": "Hutan Goblin Muda", "biome": 1, "off": Vector2i(5, -26), "lv": [6, 11], "mobs": {"goblin": 9, "slime": 3, "spider": 3}},
    {"name": "Lereng Serigala", "biome": 1, "off": Vector2i(34, 22), "lv": [12, 18], "mobs": {"wolf": 8, "kobold": 5, "bee": 2}},
    {"name": "Rawa Laba-laba", "biome": 1, "off": Vector2i(-30, -18), "lv": [19, 30], "mobs": {"spider": 8, "goblin": 4, "kobold": 3}},
    {"name": "Gua Kelelawar", "biome": 1, "off": Vector2i(-44, 22), "lv": [31, 46], "mobs": {"bat": 7, "wolf": 4, "goblin": 4}},
    {"name": "Hutan Beruang", "biome": 1, "off": Vector2i(-54, -24), "lv": [47, 66], "mobs": {"wolf": 5, "spider": 4, "bear": 2, "ogre": 1}},
    {"name": "Rimba Ogre", "biome": 1, "off": Vector2i(-64, 22), "lv": [71, 86], "mobs": {"goblin": 5, "bat": 4, "ogre": 3, "bear": 1}},
    {"name": "Gerbang Ent", "biome": 1, "off": Vector2i(-58, -4), "lv": [87, 100], "mobs": {"wolf": 4, "fiend": 4, "ogre": 3, "bear": 2}},
    # --- Gurun (Lv 100-190)
    {"name": "Oasis Ular", "biome": 2, "off": Vector2i(42, -12), "lv": [100, 114], "mobs": {"snake": 6, "spider": 4, "kobold": 4}},
    {"name": "Reruntuhan Mumi", "biome": 2, "off": Vector2i(52, 14), "lv": [115, 132], "mobs": {"mummy": 7, "centipede": 4, "bat": 3}},
    {"name": "Lembah Kelabang", "biome": 2, "off": Vector2i(60, -20), "lv": [133, 152], "mobs": {"centipede": 7, "wisp": 3, "goblin": 4}},
    {"name": "Kuburan Firaun", "biome": 2, "off": Vector2i(68, 10), "lv": [153, 171], "mobs": {"mummy": 6, "centipede": 4, "wisp": 3, "golem": 1}},
    {"name": "Badai Pasir", "biome": 2, "off": Vector2i(74, -22), "lv": [172, 190], "mobs": {"mummy": 5, "fiend": 4, "ogre": 2, "red_ogre": 1}},
    # --- Salju (Lv 190-270)
    {"name": "Padang Salju", "biome": 3, "off": Vector2i(-6, -40), "lv": [190, 209], "mobs": {"wolf": 6, "slime": 4, "goblin": 4}},
    {"name": "Hutan Beku", "biome": 3, "off": Vector2i(16, -46), "lv": [210, 229], "mobs": {"wolf": 5, "spider": 4, "bat": 3, "bear": 2}},
    {"name": "Gua Es", "biome": 3, "off": Vector2i(-18, -52), "lv": [230, 249], "mobs": {"wisp": 4, "bat": 4, "golem": 2, "bear": 2}},
    {"name": "Puncak Badai", "biome": 3, "off": Vector2i(22, -60), "lv": [250, 270], "mobs": {"wolf": 4, "fiend": 3, "bear": 3, "golem": 2}},
    # --- Gunung Api (Lv 270-350)
    {"name": "Kaki Gunung Api", "biome": 4, "off": Vector2i(-10, 40), "lv": [270, 289], "mobs": {"fiend": 5, "kobold": 4, "wisp": 3, "slime": 4}},
    {"name": "Lembah Lava", "biome": 4, "off": Vector2i(16, 47), "lv": [290, 309], "mobs": {"fiend": 5, "centipede": 4, "bat": 3, "red_ogre": 1}},
    {"name": "Kawah Merah", "biome": 4, "off": Vector2i(-22, 53), "lv": [310, 329], "mobs": {"fiend": 4, "centipede": 4, "red_ogre": 2, "golem": 2}},
    {"name": "Jantung Magma", "biome": 4, "off": Vector2i(24, 60), "lv": [330, 350], "mobs": {"fiend": 4, "ogre": 2, "golem": 2, "red_ogre": 3}},
    # --- Biome ekspansi World 1 (5-10) & World 2 (11-14): 2 zona per biome. Zona yang biome-nya tidak ada di dunia aktif dilewati main.gd.
    # --- Shadow Reach (Lv 350-430)
    {"name": "Shadow Reach: Tepi", "biome": 5, "off": Vector2i(-95, -30), "lv": [350, 390], "mobs": {"umbral_slime": 4, "gloomfang_wolf": 3, "shade_stalker": 3, "dusk_bat": 2}},
    {"name": "Shadow Reach: Pedalaman", "biome": 5, "off": Vector2i(-102, -93), "lv": [391, 430], "mobs": {"shade_stalker": 3, "dusk_bat": 3, "night_kobold": 3, "eclipse_spider": 3}},
    # --- Undefined Land (Lv 430-500)
    {"name": "Undefined Land: Tepi", "biome": 6, "off": Vector2i(-22, -98), "lv": [430, 465], "mobs": {"hollow_wisp": 4, "gravebound_ogre": 3, "ashen_fiend": 3, "rift_serpent": 2}},
    {"name": "Undefined Land: Pedalaman", "biome": 6, "off": Vector2i(22, -100), "lv": [466, 500], "mobs": {"ashen_fiend": 3, "rift_serpent": 3, "null_crawler": 3, "glitch_golem": 3}},
    # --- Abyssal Land (Lv 500-570)
    {"name": "Abyssal Land: Tepi", "biome": 7, "off": Vector2i(74, -68), "lv": [500, 535], "mobs": {"abyss_eel": 4, "deep_maw": 3, "trench_horror": 3, "blackfin_stalker": 2}},
    {"name": "Abyssal Land: Pedalaman", "biome": 7, "off": Vector2i(132, -41), "lv": [536, 570], "mobs": {"trench_horror": 3, "blackfin_stalker": 3, "void_jelly": 3, "drowned_mummy": 3}},
    # --- Enchanted Forest (Lv 570-650)
    {"name": "Enchanted Forest: Tepi", "biome": 8, "off": Vector2i(95, 30), "lv": [570, 610], "mobs": {"thorn_sprite": 4, "mossback_bear": 3, "elder_treantling": 3, "briar_goblin": 2}},
    {"name": "Enchanted Forest: Pedalaman", "biome": 8, "off": Vector2i(102, 93), "lv": [611, 650], "mobs": {"elder_treantling": 3, "briar_goblin": 3, "bloom_wisp": 3, "rootbound_ogre": 3}},
    # --- Sakura Valley (Lv 650-710)
    {"name": "Sakura Valley: Tepi", "biome": 9, "off": Vector2i(22, 98), "lv": [650, 680], "mobs": {"petal_fox": 4, "sakura_moth": 3, "crimson_koi": 3, "blossom_spider": 2}},
    {"name": "Sakura Valley: Pedalaman", "biome": 9, "off": Vector2i(-22, 100), "lv": [681, 710], "mobs": {"crimson_koi": 3, "blossom_spider": 3, "pink_warden": 3, "fallen_ronin": 3}},
    # --- Mushroom Kingdom (Lv 710-780)
    {"name": "Mushroom Kingdom: Tepi", "biome": 10, "off": Vector2i(-74, 68), "lv": [710, 745], "mobs": {"sporeling": 4, "mushroom_brute": 3, "myco_shaman": 3, "toxic_toad": 2}},
    {"name": "Mushroom Kingdom: Pedalaman", "biome": 10, "off": Vector2i(-132, 41), "lv": [746, 780], "mobs": {"myco_shaman": 3, "toxic_toad": 3, "cap_guardian": 3, "fungal_bat": 3}},
    # --- Ethergrooves (Lv 780-840)
    {"name": "Ethergrooves: Tepi", "biome": 11, "off": Vector2i(-42, -27), "lv": [780, 810], "mobs": {"ether_drake": 4, "cloud_wisp": 3, "aether_manta": 3, "prism_golem": 2}},
    {"name": "Ethergrooves: Pedalaman", "biome": 11, "off": Vector2i(-49, -78), "lv": [811, 840], "mobs": {"aether_manta": 3, "prism_golem": 3, "sky_kobold": 3, "starved_harpy": 3}},
    # --- Forgotten Kingdom (Lv 840-900)
    {"name": "Forgotten Kingdom: Tepi", "biome": 12, "off": Vector2i(27, -42), "lv": [840, 870], "mobs": {"ruins_sentinel": 4, "forgotten_knight": 3, "dust_revenant": 3, "relic_scorpion": 2}},
    {"name": "Forgotten Kingdom: Pedalaman", "biome": 12, "off": Vector2i(78, -49), "lv": [871, 900], "mobs": {"dust_revenant": 3, "relic_scorpion": 3, "lost_archer": 3, "ancient_mummy": 3}},
    # --- Lumins Reef (Lv 900-950)
    {"name": "Lumins Reef: Tepi", "biome": 13, "off": Vector2i(42, 27), "lv": [900, 925], "mobs": {"lumin_ray": 4, "reef_guardian": 3, "pearl_wisp": 3, "coral_stalker": 2}},
    {"name": "Lumins Reef: Pedalaman", "biome": 13, "off": Vector2i(49, 78), "lv": [926, 950], "mobs": {"pearl_wisp": 3, "coral_stalker": 3, "tide_serpent": 3, "glow_jelly": 3}},
    # --- Verdan Height (Lv 950-1000)
    {"name": "Verdan Height: Tepi", "biome": 14, "off": Vector2i(-27, 42), "lv": [950, 975], "mobs": {"verdan_stag": 4, "canopy_hunter": 3, "elder_boar": 3, "vine_strangler": 2}},
    {"name": "Verdan Height: Pedalaman", "biome": 14, "off": Vector2i(-78, 49), "lv": [976, 1000], "mobs": {"elder_boar": 3, "vine_strangler": 3, "pollen_sprite": 3, "grove_colossus": 3}},
]


static func zone_mob_level(zi: int, kind: String) -> int:
    var z: Dictionary = ZONES[zi]
    var lo: int = int(z["lv"][0])
    var hi: int = int(z["lv"][1])
    if ZONE_ELITE.has(kind):
        return clampi(hi, 1, LV_MAX)
    return clampi(randi_range(lo, hi), 1, LV_MAX)

# Bonus level untuk monster elit (ogre, ogre merah) di atas rata-rata bioma.
const ELITE_BONUS := {"ogre": 12, "red_ogre": 25}


static func interp(a: Array, x: float) -> float:
    if x <= float(a[0][0]):
        return float(a[0][1])
    for i in range(1, a.size()):
        var x1: float = float(a[i][0])
        if x <= x1:
            var x0: float = float(a[i - 1][0])
            var y0: float = float(a[i - 1][1])
            return y0 + (float(a[i][1]) - y0) * (x - x0) / (x1 - x0)
    return float(a[a.size() - 1][1])


# ------------------------------------------------------------------ XP
static func xp_needed(lv: int) -> int:
    return int(55.0 + 14.0 * lv + 0.85 * pow(float(lv), 2.3))


# XP satuan satu monster (faktor jenis = xp dasar / 6)
static func mob_xp_unit(lv: int) -> float:
    return float(xp_needed(lv)) / (interp(KILLS_ANCHOR, lv) * AVG_MOB_XP_FACTOR)


# Pengali XP menurut selisih level monster - pemain: monster jauh di bawah = hampir tak ada XP,
# monster lebih tinggi = bonus (maks +50%).
static func xp_diff_mult(mob_lv: int, player_lv: int) -> float:
    # selisih level dihitung relatif: makin tinggi level pemain, makin lebar toleransinya
    # (di level 10 = 1 level per langkah seperti dulu; di level 350 = 35 level per langkah)
    var step: float = maxf(1.0, float(player_lv) / 10.0)
    var d: float = float(mob_lv - player_lv) / step
    if d >= 0.0:
        return 1.0 + minf(d, 10.0) * 0.05
    return maxf(1.0 + d * 0.08, 0.1)


static func gather_xp(lv: int) -> int:
    return maxi(3 + lv / 3, int(mob_xp_unit(lv) * 0.25))


static func quest_xp(lv: int) -> int:
    return int(float(xp_needed(lv)) * 0.3)


# ------------------------------------------------------------------ monster
static func mob_hp(lv: int, base_hp: int) -> int:
    return mini(int(interp(HP_ANCHOR, lv) * float(base_hp) / 30.0), MOB_HP_CAP)


static func mob_dmg(lv: int, base_dmg: int) -> int:
    return int(interp(DMG_ANCHOR, lv) * float(base_dmg) / 8.0)


static func mob_xp(lv: int, base_xp: int) -> int:
    return maxi(int(mob_xp_unit(lv) * float(base_xp) / 6.0), 1)


# Level acak monster biasa menurut bioma + bonus elit
# dist = jarak ke titik awal desa (px). Di hutan, makin jauh dari desa makin tinggi levelnya,
# supaya pemula aman di sekitar desa dan naik pelan-pelan.
# [jarak dari desa (px), level dasar]
const VILLAGE_CURVE := [[0, 1], [700, 1], [1000, 2], [1300, 4], [1700, 8], [2100, 15], [2500, 28], [2900, 45], [3300, 70], [4000, 100]]


static func roll_mob_level(biome_idx: int, kind: String, dist: float = -1.0) -> int:
    var r: Array = BIOME_LV[clampi(biome_idx, 0, BIOME_LV.size() - 1)]
    var lo: int = int(r[0])
    var hi: int = int(r[1])
    var t: float = (randf() + randf()) * 0.5      # condong ke tengah rentang
    if biome_idx == 1 and dist >= 0.0:
        # mulai dihitung dari tepi desa (~560 px): sebaran acak di dekat desa tetap rendah
        t = clampf((dist - 560.0) / 2550.0 + randf_range(-0.08, 0.08), 0.0, 1.0)
        # kurva landai di dekat desa: Lv 1-3 di sekitar desa, baru naik cepat jauh di luar
        var base: float = interp(VILLAGE_CURVE, dist)
        var lvv: int = roundi(base * randf_range(0.8, 1.2))
        return clampi(maxi(lvv, 1) + int(ELITE_BONUS.get(kind, 0)) * (1 if dist > 1800.0 else 0), 1, LV_MAX)
    var lv: int = lo + roundi(float(hi - lo) * t) + int(ELITE_BONUS.get(kind, 0))
    return clampi(lv, 1, LV_MAX)


# ------------------------------------------------------------------ bos
static func boss_dmg(lv: int) -> int:
    return int(interp(DMG_ANCHOR, lv) * 3.0)


static func boss_xp(lv: int) -> int:
    return int(float(xp_needed(lv)) * 1.5)


# ------------------------------------------------------------------ pemain
# Pengali damage serangan pemain menurut level (ditambah dari senjata, STR, dan rarity gear)
static func player_scale(lv: int) -> float:
    var l: float = float(lv - 1)
    return 1.0 + 0.055 * l + 0.0003 * l * l


# Pengali HP / MP maksimum pemain menurut level
static func player_hp_scale(lv: int) -> float:
    return 1.0 + 0.10 * float(lv - 1)


static func player_mp_scale(lv: int) -> float:
    return 1.0 + 0.05 * float(lv - 1)


# ------------------------------------------------------------------ selisih level (monster vs pemain)
# Tanpa ini, statistik (STR/gear) membuat pemain Lv 200 bisa membunuh monster Lv 700 dalam beberapa pukulan.
# Rasio = level monster / level pemain. Sampai GAP_FREE kali lipat tidak ada efek; di atasnya monster makin
# kebal (damage pemain turun) dan makin sakit (damage monster naik). Monster di bawah level pemain tidak berubah.
const GAP_FREE := 1.15
const GAP_DEALT_POW := 1.6       # makin besar = monster tinggi makin kebal
const GAP_TAKEN_POW := 1.2       # makin besar = monster tinggi makin mematikan
const GAP_DEALT_MIN := 0.02      # damage pemain ke monster tak pernah di bawah 2%
const GAP_TAKEN_MAX := 8.0       # damage monster ke pemain tak pernah lebih dari 8x


static func gap_ratio(mob_lv: int, pl_lv: int) -> float:
    return float(mob_lv) / float(maxi(pl_lv, 1))


# Pengali damage pemain -> monster
static func dealt_mult(mob_lv: int, pl_lv: int) -> float:
    var g: float = gap_ratio(mob_lv, pl_lv)
    if g <= GAP_FREE:
        return 1.0
    return maxf(pow(GAP_FREE / g, GAP_DEALT_POW), GAP_DEALT_MIN)


# Pengali damage monster -> pemain
static func taken_mult(mob_lv: int, pl_lv: int) -> float:
    var g: float = gap_ratio(mob_lv, pl_lv)
    if g <= GAP_FREE:
        return 1.0
    return minf(pow(g / GAP_FREE, GAP_TAKEN_POW), GAP_TAKEN_MAX)


# Pertahanan: pengurangan persentase supaya tetap berguna di late game
static func reduce(amount: int, defense: float) -> int:
    return maxi(int(float(amount) * 100.0 / (100.0 + defense * 2.0)), 1)
