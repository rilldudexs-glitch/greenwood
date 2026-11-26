extends RefCounted
# Kemajuan karakter: Pohon Skill (poin dari level) + Achievement & Gelar.
# Disimpan di Game.p: "st" {id_node: rank}, "ach" {id: 1}, "title" (id achievement yang jadi gelar, "" = tanpa).

const Plot = preload("res://scripts/plot.gd")

# ------------------------------------------------------------------ pohon skill
# Poin skill = level / PTS_DIV (naik level 4x = 1 poin). Reset gratis kapan saja.
const PTS_DIV := 4
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
    return int(Game.p.get("level", 1)) / PTS_DIV


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
    return m


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
