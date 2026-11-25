extends RefCounted
# Job / kelas. Job awal dipilih di New Game. Job rahasia & Legend dibuka lewat Tetua Oren (Jalan Warisan),
# sekali pilih = permanen. Data job disimpan di Game.p["job"] (id string, "" = tanpa job / save lama).

const Secrets = preload("res://scripts/secrets.gd")
const Plot = preload("res://scripts/plot.gd")

const BASE := ["knight", "mage", "archer", "swordsman", "priest", "shade", "tamer", "alchemist"]
const ADVANCED := ["root_guard", "seal_weaver", "mist_shade", "wild_caller", "seed_brewer"]
const LEGEND := "seed_bearer"

# stats = bonus stat awal (hanya job awal). mul = pengali pasif: melee, magic, hp, mp, spd, def, cd (jeda serang),
# regen (MP), reach (jangkauan tebas), potion (efek ramuan); add = tambahan datar: crit.
# skill: kind area | dash | blink. src = melee | magic | best. Lihat Player._job_skill.
const DATA := {
    "knight": {"name": "Ksatria", "tier": 0, "desc": "Tebasan jarak dekat, HP & DEF tinggi.",
        "stats": {"str": 3, "vit": 3}, "mul": {"melee": 1.1, "hp": 1.2, "def": 1.15},
        "skill": {"name": "Tebasan Memutar", "cd": 7.0, "kind": "area", "at": "self", "r": 64.0, "mult": 1.7, "src": "melee", "col": Color(1, 0.8, 0.4)}},
    "mage": {"name": "Penyihir", "tier": 0, "desc": "Sihir kuat, MP besar, tapi HP tipis.",
        "stats": {"int": 5, "dex": 1}, "mul": {"magic": 1.3, "mp": 1.3, "hp": 0.9, "regen": 1.4},
        "skill": {"name": "Ledakan Api", "cd": 8.0, "kind": "area", "at": "ahead", "dist": 70.0, "r": 85.0, "mult": 2.4, "src": "magic", "status": "burn", "col": Color(1, 0.5, 0.15)}},
    "archer": {"name": "Pemanah", "tier": 0, "desc": "Lincah, jangkauan serang panjang, sering kritikal.",
        "stats": {"dex": 4, "luk": 2}, "mul": {"spd": 1.1, "reach": 1.35}, "add": {"crit": 0.08},
        "skill": {"name": "Hujan Panah", "cd": 8.0, "kind": "area", "at": "ahead", "dist": 110.0, "r": 80.0, "mult": 0.9, "src": "melee", "pulses": 4, "gap": 0.25, "col": Color(0.7, 1, 0.5)}},
    "swordsman": {"name": "Pendekar Pedang", "tier": 0, "desc": "Cepat menebas, kritikal tinggi.",
        "stats": {"str": 2, "dex": 3, "luk": 1}, "mul": {"cd": 0.85}, "add": {"crit": 0.1},
        "skill": {"name": "Tebasan Kilat", "cd": 6.0, "kind": "dash", "dist": 140.0, "mult": 2.0, "src": "melee", "col": Color(0.8, 0.95, 1)}},
    "priest": {"name": "Pendeta", "tier": 0, "desc": "Cahaya penyembuh, MP awet.",
        "stats": {"int": 3, "vit": 2, "luk": 1}, "mul": {"mp": 1.2, "regen": 1.5, "hp": 1.1, "magic": 1.1},
        "skill": {"name": "Cahaya Suci", "cd": 10.0, "kind": "area", "at": "self", "r": 90.0, "mult": 1.2, "src": "magic", "heal": 0.35, "invuln": 0.5, "col": Color(1, 0.95, 0.6)}},
    "shade": {"name": "Pemburu Bayangan", "tier": 0, "desc": "Damage besar dari dekat, tapi rapuh.",
        "stats": {"dex": 3, "luk": 3, "str": 1}, "mul": {"melee": 1.15, "hp": 0.85, "spd": 1.08}, "add": {"crit": 0.12},
        "skill": {"name": "Langkah Bayangan", "cd": 7.0, "kind": "blink", "range": 260.0, "mult": 2.6, "src": "melee", "crit": true, "col": Color(0.6, 0.3, 0.9)}},
    "tamer": {"name": "Penjinak", "tier": 0, "desc": "Seimbang, memanggil sahabat rimba untuk menyerang.",
        "stats": {"vit": 2, "str": 1, "int": 1, "dex": 1, "luk": 1}, "mul": {"hp": 1.1},
        "skill": {"name": "Panggil Sahabat", "cd": 9.0, "kind": "area", "at": "self", "r": 105.0, "mult": 1.0, "src": "melee", "pulses": 3, "gap": 0.45, "col": Color(0.5, 0.9, 0.4)}},
    "alchemist": {"name": "Alkemis", "tier": 0, "desc": "Bom racun, ramuan jadi 1,5x lebih manjur.",
        "stats": {"int": 3, "vit": 1, "luk": 2, "dex": 1}, "mul": {"potion": 1.5},
        "skill": {"name": "Bom Racun", "cd": 8.0, "kind": "area", "at": "ahead", "dist": 100.0, "r": 75.0, "mult": 1.8, "src": "magic", "status": "poison", "col": Color(0.5, 1, 0.3)}},

    # ---- job rahasia (dibuka lewat kesaksian) ----
    "root_guard": {"name": "Penjaga Akar", "tier": 1, "desc": "Tameng akar: HP & DEF sangat tinggi.",
        "from": ["knight", "tamer"], "need": ["w1", "w4"], "need_text": "Kesaksian Bibi Lumut & Ragil",
        "mul": {"melee": 1.25, "hp": 1.4, "def": 1.4},
        "skill": {"name": "Perisai Akar", "cd": 9.0, "kind": "area", "at": "self", "r": 75.0, "mult": 2.2, "src": "melee", "invuln": 1.5, "col": Color(0.4, 0.9, 0.3)}},
    "seal_weaver": {"name": "Penenun Segel", "tier": 1, "desc": "Segel sihir yang membekukan musuh.",
        "from": ["mage", "priest"], "need": ["w5", "w6"], "need_text": "Kesaksian Lirih & Ezra",
        "mul": {"magic": 1.4, "mp": 1.4, "regen": 1.5},
        "skill": {"name": "Segel Beku", "cd": 10.0, "kind": "area", "at": "self", "r": 130.0, "mult": 1.8, "src": "magic", "status": "freeze", "heal": 0.15, "col": Color(0.7, 0.9, 1)}},
    "mist_shade": {"name": "Bayangan Kabut", "tier": 1, "desc": "Menembus kabut, lincah dan mematikan.",
        "from": ["shade", "swordsman"], "need": ["w5", "w9"], "need_text": "Kesaksian Lirih & Hanae",
        "mul": {"melee": 1.3, "spd": 1.15}, "add": {"crit": 0.2},
        "skill": {"name": "Tembus Kabut", "cd": 7.0, "kind": "blink", "range": 320.0, "mult": 3.2, "src": "melee", "crit": true, "invuln": 1.0, "col": Color(0.7, 0.7, 0.9)}},
    "wild_caller": {"name": "Pemanggil Rimba", "tier": 1, "desc": "Roh hutan bertarung di sisimu.",
        "from": ["tamer", "archer"], "need": ["w8", "w9"], "need_text": "Kesaksian Sylvi & Hanae",
        "mul": {"melee": 1.2, "spd": 1.12, "hp": 1.2},
        "skill": {"name": "Roh Rimba", "cd": 10.0, "kind": "area", "at": "self", "r": 120.0, "mult": 1.1, "src": "melee", "pulses": 5, "gap": 0.4, "col": Color(0.4, 1, 0.6)}},
    "seed_brewer": {"name": "Peracik Benih", "tier": 1, "desc": "Ramuan dan bom yang menumbuhkan penyembuh.",
        "from": ["alchemist", "priest"], "need": ["w10"], "need_text": "Kesaksian Morel",
        "mul": {"magic": 1.3, "potion": 2.0, "hp": 1.2, "regen": 1.4},
        "skill": {"name": "Kebun Racun", "cd": 9.0, "kind": "area", "at": "ahead", "dist": 100.0, "r": 95.0, "mult": 1.3, "src": "magic", "status": "poison", "pulses": 3, "gap": 0.5, "heal": 0.07, "col": Color(0.6, 1, 0.5)}},

    # ---- class Legend (hadiah akhir cerita) ----
    "seed_bearer": {"name": "Penumbuh Benih", "tier": 2, "desc": "Pewaris Benih Pertama. Semua kemampuan meningkat.",
        "need_text": "Pilih ending Tanam Kembali setelah Worldroot Devourer",
        "mul": {"melee": 1.3, "magic": 1.3, "hp": 1.3, "mp": 1.3, "spd": 1.1, "def": 1.3, "regen": 1.5, "potion": 1.5}, "add": {"crit": 0.1},
        "skill": {"name": "Kebangkitan Benih", "cd": 10.0, "kind": "area", "at": "self", "r": 150.0, "mult": 1.6, "src": "best", "pulses": 3, "gap": 0.35, "heal": 0.1, "invuln": 1.0, "col": Color(0.7, 1, 0.5)}},
}


# Gaya senjata melayang & warna aura tiap job (dipakai player.gd)
const LOOK := {
    "knight": ["greatsword", Color(0.85, 0.88, 0.95)], "mage": ["staff", Color(1.0, 0.5, 0.15)],
    "archer": ["bow", Color(0.7, 1.0, 0.5)], "swordsman": ["katana", Color(0.8, 0.95, 1.0)],
    "priest": ["holy", Color(1.0, 0.95, 0.6)], "shade": ["dagger", Color(0.65, 0.35, 0.95)],
    "tamer": ["spear", Color(0.5, 0.9, 0.4)], "alchemist": ["flask", Color(0.5, 1.0, 0.3)],
    "root_guard": ["greatsword", Color(0.4, 0.9, 0.3)], "seal_weaver": ["staff", Color(0.7, 0.9, 1.0)],
    "mist_shade": ["dagger", Color(0.75, 0.75, 0.95)], "wild_caller": ["bow", Color(0.4, 1.0, 0.6)],
    "seed_brewer": ["flask", Color(0.6, 1.0, 0.5)], "seed_bearer": ["holy", Color(0.7, 1.0, 0.5)],
}


static func look() -> Array:
    var j := cur()
    if j == "" or not LOOK.has(j):
        return []
    return LOOK[j]


# Jenis pendamping hewan untuk job ini ("" = tidak ada)
static func pet_style() -> String:
    match cur():
        "tamer":
            return "wolf"
        "wild_caller":
            return "stag"
    return ""


static func cur() -> String:
    var j: String = String(Game.p.get("job", ""))
    return j if DATA.has(j) else ""


static func name_of(id: String) -> String:
    return String(DATA[id]["name"]) if DATA.has(id) else "Petualang"


static func mul(k: String) -> float:
    var j := cur()
    var e: float = Plot.end_mul(k)
    if j == "":
        return e
    return float(DATA[j].get("mul", {}).get(k, 1.0)) * e


static func add(k: String) -> float:
    var j := cur()
    if j == "":
        return 0.0
    return float(DATA[j].get("add", {}).get(k, 0.0))


# Skill job aktif; kosong = skill bawaan (tebasan memutar)
static func skill() -> Dictionary:
    var j := cur()
    if j == "":
        return {}
    return DATA[j]["skill"]


static func start_stats(id: String) -> Dictionary:
    var st := {"str": 1, "int": 1, "vit": 1, "dex": 1, "luk": 1}
    if DATA.has(id):
        var b: Dictionary = DATA[id].get("stats", {})
        for k in b.keys():
            st[k] = int(st[k]) + int(b[k])
    return st


static func legend_ready() -> bool:
    return Plot.ending() == "replant"


static func can_take(id: String) -> bool:
    var j := cur()
    if not DATA.has(id) or id == j:
        return false
    var d: Dictionary = DATA[id]
    var t: int = int(d["tier"])
    if t == 0:
        return false
    if j != "" and int(DATA[j]["tier"]) >= t:
        return false            # permanen: tidak bisa turun / pindah sejajar
    if t == 2:
        return legend_ready()
    if not (d["from"] as Array).has(j):
        return false
    for w in d["need"]:
        if not Secrets.finished(String(w)):
            return false
    return true


# Daftar job lanjutan/legend yang bisa diambil sekarang
static func available() -> Array:
    var out: Array = []
    for id in ADVANCED + [LEGEND]:
        if can_take(id):
            out.append(id)
    return out


static func take(id: String) -> void:
    Game.p["job"] = id
    Game.save()
