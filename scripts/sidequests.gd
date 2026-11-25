extends RefCounted
# Tugas Warga: satu pemberi quest bernama di tiap biome, tersebar di seluruh peta. Tiap NPC punya 3 tugas berurutan
# (berburu -> kumpulkan bahan biome -> tugas besar). Data di Game.p["sq"]: {role: {"st": tahap 0-3, "on": diterima, "b": {jenis: kill awal}}}

const Bal = preload("res://scripts/balance.gd")

# biome: [nama, gender, gelar, jenis musuh, nama musuh, masalah, ucapan terima kasih]
const NPC := {
    1: ["Pak Rimba", "m", "Pemburu Hutan", "goblin", "Goblin", "Goblin makin berani merampas jebakan dan hasil buruanku.", "Hutan jadi sedikit lebih tenang."],
    2: ["Bu Fatma", "f", "Penjaga Oasis", "mummy", "Mumi", "Mumi-mumi keluar dari reruntuhan dan mengusik karavan yang singgah.", "Karavan bisa singgah dengan tenang lagi."],
    3: ["Kak Beku", "m", "Pemandu Salju", "wolf", "Serigala", "Serigala lapar mengincar para pendaki yang tersesat.", "Jalur pendakian aman lagi."],
    4: ["Nyai Bara", "f", "Penjaga Kawah", "red_ogre", "Red Ogre", "Red Ogre terus menyerang para penambang batu api.", "Para penambang bisa bekerja lagi."],
    5: ["Kelam", "m", "Pengintai Bayangan", "umbral_slime", "Umbral Slime", "Slime bayangan menelan cahaya lentera kami satu per satu.", "Cahaya lentera kami menyala kembali."],
    6: ["Galat", "f", "Penjaga Celah", "hollow_wisp", "Hollow Wisp", "Wisp kosong menghapus jejak jalan yang kami buat.", "Jalan setapak kami tampak lagi."],
    7: ["Kapten Arus", "m", "Pelaut Palung", "abyss_eel", "Abyss Eel", "Belut jurang merobek jaring dan memangsa ikan kami.", "Jaring kami utuh lagi."],
    8: ["Rimbun", "f", "Penjaga Hutan Peri", "thorn_sprite", "Thorn Sprite", "Peri duri mengacaukan bunga-bunga yang kami rawat.", "Bunga-bunga mekar lagi."],
    9: ["Bu Sakura", "f", "Tukang Kebun Lembah", "petal_fox", "Petal Fox", "Rubah kelopak mencuri bunga untuk perayaan musim semi kami.", "Perayaan bisa berlangsung."],
    10: ["Jamur Tua", "m", "Tabib Hutan Jamur", "sporeling", "Sporeling", "Sporeling menyebar dan mencemari kebun obat kami.", "Kebun obat bersih lagi."],
    11: ["Awan", "m", "Penjaga Menara", "ether_drake", "Ether Drake", "Naga awan mengacaukan angin dan mengganggu penerbangan kami.", "Langit tenang lagi."],
    12: ["Sir Debu", "m", "Penjaga Reruntuhan", "ruins_sentinel", "Ruins Sentinel", "Sentinel reruntuhan tak mengenal kawan lagi dan menyerang siapa pun.", "Reruntuhan bisa dijelajahi tanpa takut."],
    13: ["Mutiara", "f", "Penyelam Karang", "lumin_ray", "Lumin Ray", "Pari bercahaya menyengat para penyelam yang mencari mutiara.", "Mutiara bisa dicari dengan aman."],
    14: ["Kayu Tua", "m", "Penjaga Hutan Tinggi", "verdan_stag", "Verdan Stag", "Rusa Verdan yang kebingungan menerobos kebun kami.", "Kebun kami pulih."],
    15: ["Kristal", "f", "Penjelajah Gua", "", "", "Gua ini bergema, tapi bahan kristalnya langka dan susah dicari.", "Persediaan kami cukup lagi."],
}


static func s(role: String) -> Dictionary:
    if not Game.p.has("sq") or typeof(Game.p["sq"]) != TYPE_DICTIONARY:
        Game.p["sq"] = {}
    var d: Dictionary = Game.p["sq"]
    if not d.has(role):
        d[role] = {"st": 0, "on": false, "b": {}}
    return d[role]


static func biome_of(role: String) -> int:
    return int(role.substr(3))


static func is_role(role: String) -> bool:
    return role.begins_with("sq_") and NPC.has(biome_of(role))


# Tujuan tahap st: {"kill": n, "a": n, "b": n}
static func goal(b: int, st: int) -> Dictionary:
    var hunts: bool = String(NPC[b][3]) != ""
    match st:
        0:
            return {"kill": 8} if hunts else {"a": 5}
        1:
            return {"a": 6}
        _:
            var g := {"b": 2}
            if hunts:
                g["kill"] = 10
            return g


static func _count(pl, id: String) -> int:
    return int(Game.p["inv"].get(id, 0))


static func _done_kills(role: String, kind: String) -> int:
    var base: int = int(s(role)["b"].get(kind, 0))
    return Game.kill_count(kind) - base


static func is_complete(role: String, pl) -> bool:
    var b := biome_of(role)
    var g: Dictionary = goal(b, int(s(role)["st"]))
    if g.has("kill") and _done_kills(role, String(NPC[b][3])) < int(g["kill"]):
        return false
    if g.has("a") and _count(pl, "bi_%d_a" % b) < int(g["a"]):
        return false
    if g.has("b") and _count(pl, "bi_%d_b" % b) < int(g["b"]):
        return false
    return true


static func marker(role: String, pl) -> String:
    if not is_role(role):
        return ""
    var q: Dictionary = s(role)
    if int(q["st"]) >= 3:
        return ""
    if not bool(q["on"]):
        return "!"
    if is_complete(role, pl):
        return "?"
    return ""


static func goal_text(role: String, pl) -> String:
    var b := biome_of(role)
    var g: Dictionary = goal(b, int(s(role)["st"]))
    var parts: Array = []
    if g.has("kill"):
        parts.append("%s %d/%d" % [String(NPC[b][4]), mini(_done_kills(role, String(NPC[b][3])), int(g["kill"])), int(g["kill"])])
    if g.has("a"):
        parts.append("%s %d/%d" % [Items.info("bi_%d_a" % b).get("name", "Bahan"), mini(_count(pl, "bi_%d_a" % b), int(g["a"])), int(g["a"])])
    if g.has("b"):
        parts.append("%s %d/%d" % [Items.info("bi_%d_b" % b).get("name", "Bahan"), mini(_count(pl, "bi_%d_b" % b), int(g["b"])), int(g["b"])])
    return ", ".join(PackedStringArray(parts))


static func goal_full(role: String) -> String:
    var b := biome_of(role)
    var g: Dictionary = goal(b, int(s(role)["st"]))
    var parts: Array = []
    if g.has("kill"):
        parts.append("kalahkan %d %s" % [int(g["kill"]), String(NPC[b][4])])
    if g.has("a"):
        parts.append("bawakan %d %s" % [int(g["a"]), Items.info("bi_%d_a" % b).get("name", "bahan")])
    if g.has("b"):
        parts.append("bawakan %d %s" % [int(g["b"]), Items.info("bi_%d_b" % b).get("name", "bahan")])
    return " dan ".join(PackedStringArray(parts))


static func reward_mult(st: int) -> float:
    return [0.5, 0.7, 1.2][clampi(st, 0, 2)]


static func talk(npc, hud, pl) -> void:
    var role: String = npc.role
    var b := biome_of(role)
    var d: Array = NPC[b]
    var q: Dictionary = s(role)
    var st: int = int(q["st"])
    if st >= 3:
        hud.say(npc.npc_name, ["%s" % String(d[6]), "Kau selalu diterima di sini, %s." % String(Game.p["name"])])
        return
    if not bool(q["on"]):
        var intro: Array = []
        if st == 0:
            intro = ["Halo, pengembara! Aku %s, %s di sini." % [String(d[0]), String(d[2]).to_lower()], String(d[5]), "@p:Aku bisa bantu. Apa yang harus kulakukan?", "Tolong %s." % goal_full(role)]
        elif st == 1:
            intro = ["Kau kembali! Bantuanmu tadi sangat berarti.", "Sekarang aku butuh bahan untuk membereskan sisanya.", "@p:Bahan apa yang perlu dicari?", "Tolong %s." % goal_full(role)]
        else:
            intro = ["Satu hal lagi, dan ini yang terbesar.", String(d[5]), "@p:Serahkan padaku.", "Tolong %s. Aku akan membalasmu pantas." % goal_full(role)]
        hud.say(npc.npc_name, intro, _offer.bind(hud, npc))
    elif is_complete(role, pl):
        var lines: Array = ["Kau berhasil! Aku tak menyangka secepat ini.", "@p:Senang bisa membantu.", String(d[6]) if st == 2 else "Terima kasih banyak. Ini upahmu."]
        hud.say(npc.npc_name, lines, _done.bind(hud, npc, pl))
    else:
        hud.say(npc.npc_name, ["Belum selesai ya? Ingat: %s." % goal_text(role, pl)])


static func _offer(hud, npc) -> void:
    hud.choose(npc.npc_name, "Terima tugas ini?\n%s" % goal_full(npc.role), ["Terima", "Nanti saja"], _pick.bind(hud, npc))


static func _pick(i: int, hud, npc) -> void:
    if i != 0:
        return
    var role: String = npc.role
    var q: Dictionary = s(role)
    var kind: String = String(NPC[biome_of(role)][3])
    var base: Dictionary = {}
    if kind != "":
        base[kind] = Game.kill_count(kind)
    q["b"] = base
    q["on"] = true
    Game.save()
    Audio.sfx("select")
    hud.toast("Tugas diterima dari %s" % npc.npc_name)


static func _done(hud, npc, pl) -> void:
    var role: String = npc.role
    var b := biome_of(role)
    var q: Dictionary = s(role)
    var st: int = int(q["st"])
    if not is_complete(role, pl):
        return
    var g: Dictionary = goal(b, st)
    if g.has("a"):
        pl.remove_item("bi_%d_a" % b, int(g["a"]))
    if g.has("b"):
        pl.remove_item("bi_%d_b" % b, int(g["b"]))
    var m: float = reward_mult(st)
    var lv: int = int(Game.p["level"])
    var coins: int = int((100.0 + float(lv) * 30.0) * m)
    Game.p["coins"] = int(Game.p["coins"]) + coins
    Game.p["gems"] = int(Game.p["gems"]) + int(10.0 + 15.0 * m * 2.0)
    pl.give_xp(int(float(Bal.quest_xp(lv)) * m))
    if st == 2:
        pl.add_item("bi_%d_c" % b, 3)
        hud.toast("Bonus: 3 %s" % String(Items.info("bi_%d_c" % b).get("name", "hadiah")))
    q["st"] = st + 1
    q["on"] = false
    q["b"] = {}
    Game.save()
    Audio.sfx("win")
    hud.toast("Tugas selesai! +%d koin" % coins)
