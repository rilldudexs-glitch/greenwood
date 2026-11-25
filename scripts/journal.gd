extends RefCounted
# Jurnal Aldric: penjelajah yang menancapkan tugu cahaya di tiap biome dan menulis satu halaman di tiap tugu.
# Tiap halaman menunjuk arah ke tugu berikutnya (rantai). Membaca halaman = hadiah + kabut peta terbuka di
# sekitar tugu berikutnya + panah kompas di tepi layar saat sudah dekat. Halaman terakhir tiap dunia = harta besar.
# Data di Game.p["jurnal"]: {id_halaman: 1}. Id halaman = "j" + nomor biome (j1..j10 World 1, j11..j15 World 2).

const Bal = preload("res://scripts/balance.gd")

const PAGES := [
    {"id": "j1", "biome": 1, "title": "Jurnal Aldric, Halaman 1: Pintu Hutan", "lines": [
        "Hari pertama. Aku meninggalkan Desa Greenwood dengan peta kosong dan keyakinan berlebihan.",
        "Kata Tetua, Kabut Hampa berasal dari tepi dunia. Aku akan mengejarnya, tugu demi tugu."]},
    {"id": "j2", "biome": 2, "title": "Jurnal Aldric, Halaman 2: Debu dan Haus", "lines": [
        "Pasir menelan jejakku tiga kali hari ini. Maka aku menancapkan tugu cahaya supaya yang menyusul tak tersesat.",
        "Cahayanya hanya menyala bagi mereka yang membawa jurnalku."]},
    {"id": "j3", "biome": 3, "title": "Jurnal Aldric, Halaman 3: Putih Tak Berujung", "lines": [
        "Jariku mati rasa, tapi tintaku tidak membeku. Aneh, seolah jurnal ini sendiri yang hangat.",
        "Dari puncak terdengar geraman. Sesuatu di balik badai sedang memanggil."]},
    {"id": "j4", "biome": 4, "title": "Jurnal Aldric, Halaman 4: Tanah yang Bernapas", "lines": [
        "Gunung ini bernapas. Tiap hembusan melempar bara ke langit, dan langit membalasnya dengan abu.",
        "Sang naga di kawah tidak menyerangku. Ia hanya menatap, seperti menunggu seseorang yang lebih pantas."]},
    {"id": "j5", "biome": 5, "title": "Jurnal Aldric, Halaman 5: Tanpa Bayangan", "lines": [
        "Di sini cahaya menyerah lebih dulu daripada nyaliku. Aku menulis dengan satu tangan, obor di tangan lain.",
        "Jejakku lenyap secepat kutinggalkan. Kalau kau membaca ini, kau sudah lebih berani dariku."]},
    {"id": "j6", "biome": 6, "title": "Jurnal Aldric, Halaman 6: Tanah Belum Selesai", "lines": [
        "Tanah ini seperti belum selesai dibuat. Pohon tumbuh miring, batu melayang, dan arah utara berganti-ganti.",
        "Kompasku berputar tanpa henti. Aku berjalan dengan firasat, dan untungnya firasatku masih jujur."]},
    {"id": "j7", "biome": 7, "title": "Jurnal Aldric, Halaman 7: Air Penelan Cahaya", "lines": [
        "Air di sini hitam seperti tinta. Cahaya obor tenggelam sebelum menyentuh dasar.",
        "Sesuatu di bawah sana mengetuk perahuku dua kali, pelan, seperti tamu yang sopan."]},
    {"id": "j8", "biome": 8, "title": "Jurnal Aldric, Halaman 8: Hutan yang Mendengar", "lines": [
        "Pepohonan di sini berbisik. Kukira itu angin, sampai salah satunya menyebut namaku.",
        "Kabut sihir berputar mengikuti langkah kaki. Aku belajar berjalan pelan supaya hutan tak merasa dikejar."]},
    {"id": "j9", "biome": 9, "title": "Jurnal Aldric, Halaman 9: Lembah Kelopak", "lines": [
        "Kelopak jatuh tanpa henti, dan sudah lama aku tidak merasa setenang ini.",
        "Tapi Kabut Hampa pernah sampai ke sini. Di bawah pohon tertua kutemukan sisa segel yang retak."]},
    {"id": "j10", "biome": 10, "title": "Jurnal Aldric, Halaman 10: Kerajaan Kecil", "lines": [
        "Jamur sebesar rumah, spora yang bersinar, dan penduduk yang tak pernah bertanya siapa aku.",
        "Kata mereka, yang kucari bukan di ujung dunia, melainkan di ujung ingatan. Aku belum paham maksudnya."]},
    {"id": "j11", "biome": 11, "title": "Jurnal Aldric, Halaman 11: Dunia Kedua", "lines": [
        "Portal membawaku ke dunia yang lebih dingin dan sunyi. Aku mulai ragu ini ujung perjalananku.",
        "Alur cahaya di tanah menuntun langkahku. Seseorang, atau sesuatu, pernah lewat sini lebih dulu."]},
    {"id": "j12", "biome": 12, "title": "Jurnal Aldric, Halaman 12: Kerajaan Terlupakan", "lines": [
        "Istana runtuh ini dulu pusat para Penjaga. Tak satu pun nama tersisa di dindingnya.",
        "Mereka menghapus nama sendiri agar Kabut Hampa tak bisa memanggil mereka."]},
    {"id": "j13", "biome": 13, "title": "Jurnal Aldric, Halaman 13: Karang Menyala", "lines": [
        "Karang di sini berpendar seperti bintang yang tenggelam. Aku menyelam sampai paru-paruku menjerit.",
        "Di dasar kutemukan batu tulis: segel terakhir tidak disembunyikan, melainkan dititipkan."]},
    {"id": "j14", "biome": 14, "title": "Jurnal Aldric, Halaman 14: Dataran Tertinggi", "lines": [
        "Dari sini seluruh dunia tampak kecil. Kabut Hampa terlihat menipis di kejauhan.",
        "Artinya segel itu bekerja dan para penjaganya masih berjaga. Aku hanya terlambat membaca tandanya."]},
    {"id": "j15", "biome": 15, "title": "Jurnal Aldric, Halaman 15: Gua Kristal", "lines": [
        "Halaman terakhir. Kutulis di dalam gua yang bernyanyi tiap kali aku bernapas.",
        "Kalau kau sampai sini, terima kasih sudah memungut jejakku. Ambillah hartaku, dan lanjutkan sisanya."]},
]

const DIRS := ["timur", "tenggara", "selatan", "barat daya", "barat", "barat laut", "utara", "timur laut"]
# tugu terakhir tiap dunia (hadiah besar)
const FINAL := {"j10": 0, "j15": 1}


static func _d() -> Dictionary:
    if typeof(Game.p.get("jurnal")) != TYPE_DICTIONARY:
        Game.p["jurnal"] = {}
    return Game.p["jurnal"]


static func found(id: String) -> bool:
    return int(_d().get(id, 0)) > 0


static func get_def(id: String) -> Dictionary:
    for p in PAGES:
        if String(p["id"]) == id:
            return p
    return {}


# Halaman milik dunia w (urut sesuai rantai)
static func pages_of(world) -> Array:
    var out: Array = []
    for p in PAGES:
        if world.has_biome(int(p["biome"])):
            out.append(p)
    return out


static func count_in(world) -> int:
    var n := 0
    for p in pages_of(world):
        if found(String(p["id"])):
            n += 1
    return n


# Id halaman yang sedang dicari: yang pertama belum dibaca. Halaman pertama baru dicari setelah perkenalan di desa.
static func target_id(world) -> String:
    var lst: Array = pages_of(world)
    for i in lst.size():
        var id: String = String(lst[i]["id"])
        if found(id):
            continue
        if i == 0 and not bool(Game.p.get("intro", false)):
            return ""
        return id
    return ""


# Halaman sesudah id dalam rantai dunia ini ("" kalau terakhir)
static func next_id(world, id: String) -> String:
    var lst: Array = pages_of(world)
    for i in lst.size():
        if String(lst[i]["id"]) == id and i + 1 < lst.size():
            return String(lst[i + 1]["id"])
    return ""


static func dir_name(v: Vector2) -> String:
    var di: int = int(roundf(fposmod(atan2(v.y, v.x), TAU) / (TAU / 8.0))) % 8
    return String(DIRS[di])


# Hadiah membaca halaman pertama kali. Kembalikan {"first", "msg", "banner"}
static func mark(id: String, pl, world) -> Dictionary:
    var out := {"first": false, "msg": "", "banner": ""}
    if found(id):
        return out
    var d: Dictionary = get_def(id)
    if d.is_empty():
        return out
    _d()[id] = 1
    out["first"] = true
    var lv: int = int(Game.p["level"])
    var coins: int = 40 + lv * 6
    var gems: int = 3
    var extra := ""
    if FINAL.has(id):
        var w2: bool = int(FINAL[id]) == 1
        gems += 300 if w2 else 200
        coins += (6000 if w2 else 3000) + lv * 100
        pl.add_item("potion_hp2", 4)
        pl.add_item("potion_mp2", 4)
        pl.add_item(Gear.roll_gear(int(d["biome"]), int(pl.stat("luk")), 4 if w2 else 3), 1)
        out["banner"] = "Jurnal Aldric lengkap! Harta sang penjelajah menjadi milikmu"
        extra = "  Harta Aldric didapat!"
    Game.p["coins"] = int(Game.p["coins"]) + coins
    Game.p["gems"] = int(Game.p["gems"]) + gems
    pl.give_xp(int(float(Bal.quest_xp(lv)) * 0.15))
    out["msg"] = "Halaman jurnal (%d/%d)  +%d koin, +%d gem%s" % [count_in(world), pages_of(world).size(), coins, gems, extra]
    Game.save()
    return out
