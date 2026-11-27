extends RefCounted
# Kemajuan karakter: Pohon Skill (poin dari level) + Achievement & Gelar.
# Disimpan di Game.p: "st" {id_node: rank}, "ach" {id: 1}, "title" (id achievement yang jadi gelar, "" = tanpa).

const Plot = preload("res://scripts/plot.gd")

# ------------------------------------------------------------------ pohon skill
# Poin skill: level 1-100 = 1 poin per 4 level (maks 25), setelah itu 1 poin per 20 level, supaya 60 poin (6 cabang x 10 rank) baru habis di level ~800.
# Reset gratis kapan saja.
const PTS_DIV := 4
const PTS_SLOW_FROM := 100
const PTS_SLOW_DIV := 20
const MAX_RANK := 10

# mul = pengali pasif per rank (ditambah ke 1.0); add = tambahan datar per rank.
# sk_dmg / sk_cd khusus skill job (lihat Player._skill_src_dmg & skill_cd_max).
const NODES := [
    {"id": "pow", "name": "Kekuatan", "desc": "Damage fisik & sihir +3% / rank", "mul": {"melee": 0.03, "magic": 0.03}},
    {"id": "vit", "name": "Ketahanan", "desc": "HP +4%, DEF +3% / rank", "mul": {"hp": 0.04, "def": 0.03}},
    {"id": "agi", "name": "Kelincahan", "desc": "Kecepatan +1.5%, kritikal +1% / rank", "mul": {"spd": 0.015}, "add": {"crit": 0.01}},
    {"id": "sup", "name": "Penopang", "desc": "MP +4%, regen MP +4%, ramuan +3% / rank", "mul": {"mp": 0.04, "regen": 0.04, "potion": 0.03}},
    {"id": "sk_dmg", "name": "Penguasaan Skill", "desc": "Damage skill job +8% / rank", "mul": {}},
    {"id": "sk_cd", "name": "Fokus", "desc": "Jeda skill job -3% / rank", "mul": {}},
]


static func tree() -> Dictionary:
    var d = Game.p.get("st", {})
    if typeof(d) != TYPE_DICTIONARY:
        d = {}
    Game.p["st"] = d
    return d


static func rank(id: String) -> int:
    return int(tree().get(id, 0))


static func spent() -> int:
    var n := 0
    for k in tree().keys():
        n += int(tree()[k])
    return n


static func total_points() -> int:
    var lv: int = int(Game.p.get("level", 1))
    if lv <= PTS_SLOW_FROM:
        return lv / PTS_DIV
    return PTS_SLOW_FROM / PTS_DIV + (lv - PTS_SLOW_FROM) / PTS_SLOW_DIV


static func free_points() -> int:
    return maxi(total_points() - spent(), 0)


static func can_up(id: String) -> bool:
    return free_points() > 0 and rank(id) < MAX_RANK


static func up(id: String) -> bool:
    if not can_up(id):
        return false
    tree()[id] = rank(id) + 1
    return true


static func reset() -> void:
    Game.p["st"] = {}


static func st_mul(k: String) -> float:
    var m := 1.0
    for n in NODES:
        var e: Dictionary = n["mul"]
        if e.has(k):
            m += float(e[k]) * float(rank(String(n["id"])))
    return m * ench_mul(k) * house_mul(k)


static func st_add(k: String) -> float:
    var a := 0.0
    for n in NODES:
        var e: Dictionary = n.get("add", {})
        if e.has(k):
            a += float(e[k]) * float(rank(String(n["id"])))
    return a


static func skill_dmg() -> float:
    return 1.0 + 0.08 * float(rank("sk_dmg"))


static func skill_cd() -> float:
    return 1.0 - 0.03 * float(rank("sk_cd"))


# ------------------------------------------------------------------ achievement
# kind: level | kills | kill (key = jenis monster) | bosses | dungeons | castles | ending | job
# Hadiah: coins, gems. title = gelar yang dibuka (boleh kosong).
const ACH := [
    {"id": "lv10", "name": "Langkah Pertama", "desc": "Capai level 10", "kind": "level", "n": 10, "coins": 300, "title": "Pemula"},
    {"id": "lv50", "name": "Petarung Hutan", "desc": "Capai level 50", "kind": "level", "n": 50, "coins": 2000, "gems": 5, "title": "Petarung"},
    {"id": "lv100", "name": "Veteran", "desc": "Capai level 100", "kind": "level", "n": 100, "coins": 6000, "gems": 15, "title": "Veteran"},
    {"id": "lv250", "name": "Pahlawan Daerah", "desc": "Capai level 250", "kind": "level", "n": 250, "coins": 20000, "gems": 30, "title": "Pahlawan"},
    {"id": "lv500", "name": "Penakluk", "desc": "Capai level 500", "kind": "level", "n": 500, "coins": 60000, "gems": 60, "title": "Penakluk"},
    {"id": "lv1000", "name": "Legenda Hidup", "desc": "Capai level maksimum", "kind": "level", "n": 1000, "coins": 200000, "gems": 150, "title": "Legenda"},
    {"id": "k100", "name": "Pembasmi", "desc": "Kalahkan 100 monster", "kind": "kills", "n": 100, "coins": 500, "title": "Pembasmi"},
    {"id": "k1000", "name": "Pemburu Ulung", "desc": "Kalahkan 1.000 monster", "kind": "kills", "n": 1000, "coins": 5000, "gems": 10, "title": "Pemburu"},
    {"id": "k10000", "name": "Momok Rimba", "desc": "Kalahkan 10.000 monster", "kind": "kills", "n": 10000, "coins": 40000, "gems": 40, "title": "Momok Rimba"},
    {"id": "slime", "name": "Teman Slime", "desc": "Kalahkan 50 slime", "kind": "kill", "key": "slime", "n": 50, "coins": 300, "title": "Pengusir Slime"},
    {"id": "wolf", "name": "Penjegal Serigala", "desc": "Kalahkan 100 serigala", "kind": "kill", "key": "wolf", "n": 100, "coins": 1500, "title": "Pemburu Serigala"},
    {"id": "ogre", "name": "Pemecah Ogre", "desc": "Kalahkan 50 ogre", "kind": "kill", "key": "ogre", "n": 50, "coins": 4000, "gems": 8, "title": "Pemecah Ogre"},
    {"id": "b1", "name": "Pembunuh Bos", "desc": "Kalahkan 1 bos", "kind": "bosses", "n": 1, "coins": 1000, "gems": 5, "title": "Pembunuh Bos"},
    {"id": "b5", "name": "Pemburu Bos", "desc": "Kalahkan 5 bos berbeda", "kind": "bosses", "n": 5, "coins": 8000, "gems": 20, "title": "Pemburu Bos"},
    {"id": "b10", "name": "Raja Bos", "desc": "Kalahkan 10 bos berbeda", "kind": "bosses", "n": 10, "coins": 30000, "gems": 50, "title": "Raja Bos"},
    {"id": "d1", "name": "Penjelajah Gua", "desc": "Taklukkan 1 dungeon", "kind": "dungeons", "n": 1, "coins": 1000, "gems": 5, "title": "Penjelajah Gua"},
    {"id": "d7", "name": "Raja Dungeon", "desc": "Taklukkan 7 dungeon berbeda", "kind": "dungeons", "n": 7, "coins": 15000, "gems": 30, "title": "Raja Dungeon"},
    {"id": "d14", "name": "Penguasa Kegelapan", "desc": "Taklukkan 14 dungeon berbeda", "kind": "dungeons", "n": 14, "coins": 60000, "gems": 80, "title": "Penguasa Kegelapan"},
    {"id": "c1", "name": "Pengembara", "desc": "Temukan 1 kastil", "kind": "castles", "n": 1, "coins": 800, "title": "Pengembara"},
    {"id": "c8", "name": "Penjelajah Dunia", "desc": "Temukan 8 kastil", "kind": "castles", "n": 8, "coins": 12000, "gems": 25, "title": "Penjelajah"},
    {"id": "c15", "name": "Pemilik Peta", "desc": "Temukan 15 kastil", "kind": "castles", "n": 15, "coins": 40000, "gems": 60, "title": "Kartografer"},
    {"id": "t5", "name": "Pendaki Menara", "desc": "Capai lantai 5 Menara Tanpa Ujung", "kind": "tower", "n": 5, "coins": 3000, "gems": 10, "title": "Pendaki"},
    {"id": "t25", "name": "Penakluk Menara", "desc": "Capai lantai 25 Menara Tanpa Ujung", "kind": "tower", "n": 25, "coins": 30000, "gems": 50, "title": "Penakluk Menara"},
    {"id": "t100", "name": "Tanpa Ujung", "desc": "Capai lantai 100 Menara Tanpa Ujung", "kind": "tower", "n": 100, "coins": 150000, "gems": 150, "title": "Sang Tanpa Ujung"},
    {"id": "rush5", "name": "Pemanasan Bos", "desc": "Kalahkan 14 bos berurutan di Boss Rush", "kind": "rush", "n": 14, "coins": 60000, "gems": 100, "title": "Juara Boss Rush"},
    {"id": "job2", "name": "Jalan Warisan", "desc": "Ambil job rahasia atau Legend", "kind": "job", "n": 1, "coins": 5000, "gems": 20, "title": "Pewaris"},
    {"id": "end", "name": "Akhir Cerita", "desc": "Tamatkan cerita utama", "kind": "ending", "n": 1, "coins": 50000, "gems": 100, "title": "Penjaga Greenwood"},
]


static func done() -> Dictionary:
    var d = Game.p.get("ach", {})
    if typeof(d) != TYPE_DICTIONARY:
        d = {}
    Game.p["ach"] = d
    return d


static func is_done(id: String) -> bool:
    return int(done().get(id, 0)) > 0


static func _sum(d) -> int:
    var n := 0
    if typeof(d) == TYPE_DICTIONARY:
        for k in d.keys():
            n += int(d[k])
    return n


static func _count_pos(d) -> int:
    var n := 0
    if typeof(d) == TYPE_DICTIONARY:
        for k in d.keys():
            if int(d[k]) > 0:
                n += 1
    return n


# nilai kemajuan saat ini untuk sebuah achievement
static func value(a: Dictionary) -> int:
    match String(a["kind"]):
        "level":
            return int(Game.p.get("level", 1))
        "kills":
            return _sum(Game.p.get("kills", {}))
        "kill":
            return int(Game.p.get("kills", {}).get(String(a["key"]), 0))
        "bosses":
            return _count_pos(Game.p.get("bosskills", {}))
        "dungeons":
            return _count_pos(Game.p.get("dungeons", {}))
        "castles":
            return _count_pos(Game.p.get("fast", {}))
        "tower":
            return int(Game.p.get("tower", 0))
        "rush":
            return int(Game.p.get("rush", 0))
        "job":
            var j: String = String(Game.p.get("job", ""))
            return 1 if (j in ["root_guard", "seal_weaver", "mist_shade", "wild_caller", "seed_brewer", "seed_bearer"]) else 0
        "ending":
            return 1 if Plot.ending() != "" else 0
    return 0


# Cek semua achievement; kembalikan daftar yang baru terbuka (hadiah langsung diberikan).
static func check() -> Array:
    var fresh: Array = []
    for a in ACH:
        var id: String = String(a["id"])
        if is_done(id):
            continue
        if value(a) >= int(a["n"]):
            done()[id] = 1
            Game.p["coins"] = int(Game.p.get("coins", 0)) + int(a.get("coins", 0))
            Game.p["gems"] = int(Game.p.get("gems", 0)) + int(a.get("gems", 0))
            fresh.append(a)
    return fresh


static func title_text() -> String:
    var id: String = String(Game.p.get("title", ""))
    for a in ACH:
        if String(a["id"]) == id and is_done(id):
            return String(a.get("title", ""))
    return ""


static func set_title(id: String) -> void:
    Game.p["title"] = id if (id == "" or is_done(id)) else ""


# ------------------------------------------------------------------ tempa (enchant) gear
# Disimpan per item: Game.p["ench"] = {item_id: level}. Senjata +7%/level damage, armor +2% DEF & +1.5% HP per level (jumlah semua armor terpasang).
const ENCH_MAX := 10


static func ench_dict() -> Dictionary:
    var d = Game.p.get("ench", {})
    if typeof(d) != TYPE_DICTIONARY:
        d = {}
    Game.p["ench"] = d
    return d


static func ench(id: String) -> int:
    return int(ench_dict().get(id, 0))


static func armor_ench_total() -> int:
    var n := 0
    var eq = Game.p.get("equip", {})
    if typeof(eq) == TYPE_DICTIONARY:
        for s in eq.keys():
            var id: String = String(eq[s])
            if id != "":
                n += ench(id)
    return n


static func ench_mul(k: String) -> float:
    match k:
        "melee":
            return 1.0 + 0.07 * float(ench(String(Game.p.get("sword", ""))))
        "magic":
            return 1.0 + 0.07 * float(ench(String(Game.p.get("staff", ""))))
        "def":
            return 1.0 + 0.02 * float(armor_ench_total())
        "hp":
            return 1.0 + 0.015 * float(armor_ench_total())
    return 1.0


static func ench_cost(lv: int) -> Dictionary:
    return {"coins": 400 * (lv + 1) * (lv + 1), "gems": 0 if lv < 5 else (lv - 3) * 2, "chance": 100 if lv < 5 else 100 - 10 * (lv - 4)}


# Coba tempa satu item. Hasil: "max" | "kurang" | "sukses" | "gagal"
static func ench_try(id: String) -> String:
    var lv: int = ench(id)
    if lv >= ENCH_MAX:
        return "max"
    var c: Dictionary = ench_cost(lv)
    if int(Game.p.get("coins", 0)) < int(c["coins"]) or int(Game.p.get("gems", 0)) < int(c["gems"]):
        return "kurang"
    Game.p["coins"] = int(Game.p["coins"]) - int(c["coins"])
    Game.p["gems"] = int(Game.p["gems"]) - int(c["gems"])
    if randi() % 100 < int(c["chance"]):
        ench_dict()[id] = lv + 1
        return "sukses"
    return "gagal"


# ------------------------------------------------------------------ bestiary
# Daftar monster per biome diambil dari Main.MOB_TABLE (di-load saat dipakai agar tidak terjadi referensi melingkar).
static var _mobs: Dictionary = {}


static func mob_table() -> Dictionary:
    if _mobs.is_empty():
        var m = load("res://scripts/main.gd")
        _mobs = m.MOB_TABLE
    return _mobs


static func biome_names() -> Array:
    return load("res://scripts/world.gd").BNAMES


static func mob_label(kind: String) -> String:
    return kind.replace("_", " ").capitalize()


static func biome_progress(b: int) -> Vector2i:
    var tbl: Dictionary = mob_table().get(b, {})
    var seen := 0
    for k in tbl.keys():
        if int(Game.p.get("kills", {}).get(String(k), 0)) > 0:
            seen += 1
    return Vector2i(seen, tbl.size())


static func bestiary_check() -> Array:
    var out: Array = []
    var done_b = Game.p.get("bst", {})
    if typeof(done_b) != TYPE_DICTIONARY:
        done_b = {}
    Game.p["bst"] = done_b
    for b in mob_table().keys():
        var key := str(b)
        if int(done_b.get(key, 0)) > 0:
            continue
        var pr: Vector2i = biome_progress(int(b))
        if pr.y > 0 and pr.x >= pr.y:
            done_b[key] = 1
            var coins: int = 2000 * (int(b) + 1)
            var gems: int = 5 + 2 * int(b)
            Game.p["coins"] = int(Game.p.get("coins", 0)) + coins
            Game.p["gems"] = int(Game.p.get("gems", 0)) + gems
            out.append({"name": "Bestiary %s lengkap" % String(biome_names()[int(b)]), "coins": coins, "gems": gems})
    return out


# ------------------------------------------------------------------ rumah pemain
const HOUSE_MAX := 5


static func house_lv() -> int:
    return int(Game.p.get("house", 0))


static func house_cost() -> int:
    var l: int = house_lv()
    return 5000 * (l + 1) * (l + 1)


static func house_mul(k: String) -> float:
    var l: float = float(house_lv())
    if k == "hp":
        return 1.0 + 0.02 * l
    if k == "regen":
        return 1.0 + 0.06 * l
    return 1.0


static func stash() -> Dictionary:
    var d = Game.p.get("stash", {})
    if typeof(d) != TYPE_DICTIONARY:
        d = {}
    Game.p["stash"] = d
    return d


static func is_worn(id: String) -> bool:
    var eq = Game.p.get("equip", {})
    return String(Game.p.get("sword", "")) == id or String(Game.p.get("staff", "")) == id or (typeof(eq) == TYPE_DICTIONARY and eq.values().has(id))


# Pindahkan seluruh tumpukan item antara tas dan peti. dir > 0: tas -> peti.
static func move_stack(id: String, dir: int) -> bool:
    var inv: Dictionary = Game.p["inv"]
    var st: Dictionary = stash()
    if dir > 0:
        if not inv.has(id) or is_worn(id):
            return false
        if not st.has(id) and st.size() >= 60:
            return false
        st[id] = int(st.get(id, 0)) + int(inv[id])
        inv.erase(id)
    else:
        if not st.has(id):
            return false
        inv[id] = int(inv.get(id, 0)) + int(st[id])
        st.erase(id)
    return true


# ------------------------------------------------------------------ New Game+
static func ng() -> int:
    return int(Game.p.get("ng", 0))


static func can_ng() -> bool:
    return Plot.ending() != ""


# Reset cerita (plot, quest warga, saksi), simpan level/gear/job/progres. Musuh +60% HP, +35% damage per putaran.
static func start_ng() -> void:
    Game.p["ng_end"] = Plot.ending()
    Game.p["ng"] = ng() + 1
    Game.p["plot"] = {}
    Game.p["sq"] = {}
    Game.p["secrets"] = {}
    Game.p["story"] = {"ch": 0, "on": false, "n": false, "k": {}, "v": {}}
