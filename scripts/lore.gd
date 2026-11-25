extends RefCounted
# Prasasti kuno: 56 catatan tersembunyi (4 per biome): 16 di biome 1-4 + 40 di biome 5-14 (World 1 dan World 2)
# yang menceritakan legenda Para Penjaga dan Kabut Hampa. Dibaca lewat lore_stone.gd. Pengembara "Kelana Sunyi" memberi petunjuk lokasinya.
# Data di Game.p["lore"]: {id_prasasti: 1}

const Bal = preload("res://scripts/balance.gd")

const STONES := [
    # --- Hutan Greenwood (biome 1)
    {"id": "f1", "biome": 1, "title": "Prasasti Akar I: Sebelum Desa", "lines": [
        "Sebelum ada desa, hutan ini hanyalah satu pohon besar yang tumbuh di atas retakan bumi.",
        "Dari retakan itu merembes kabut dingin yang melahap apa pun yang disentuhnya."]},
    {"id": "f2", "biome": 1, "title": "Prasasti Akar II: Sumpah Ent", "lines": [
        "Pohon itu berjanji menutup retakan dengan akarnya. Manusia pertama menamainya Ent Kuno.",
        "Ia tidak meminta imbalan, hanya agar hutan ini dijaga."]},
    {"id": "f3", "biome": 1, "title": "Prasasti Akar III: Segel Pertama", "lines": [
        "Seorang pandai batu menempa Segel pertama dan menancapkannya di akar tertua.",
        "Kabut mundur. Penduduk menangis lega, lalu lupa berterima kasih."]},
    {"id": "f4", "biome": 1, "title": "Prasasti Akar IV: Pesan", "lines": [
        "Kalau kau membaca ini, segelnya pasti sudah retak.",
        "Jangan benci sang Penjaga. Kemarahannya hanyalah rasa sakit yang tak punya kata."]},
    # --- Gurun Berdebu (biome 2)
    {"id": "d1", "biome": 2, "title": "Catatan Kafilah I", "lines": [
        "Kami menyusuri gurun mencari air dan menemukan sarang besar di bawah pasir yang bergetar.",
        "Penjaga sarang itu menatap kami, tapi tidak menyerang. Ia hanya menjaga sesuatu."]},
    {"id": "d2", "biome": 2, "title": "Catatan Kafilah II", "lines": [
        "Kata penunjuk jalan kami, Ratu Kalajengking dulu seorang penjaga mata air.",
        "Ia menukar seluruh umurnya dengan capit dan racun supaya kabut tak sampai ke oase."]},
    {"id": "d3", "biome": 2, "title": "Reruntuhan Makam", "lines": [
        "Firaun pertama dikubur bersama Segel kedua, dengan perintah: jangan pernah dicuri.",
        "Para pencuri tetap datang. Sebagian masih berjalan di lorong makam sebagai mumi."]},
    {"id": "d4", "biome": 2, "title": "Pasir yang Mengingat", "lines": [
        "Pasir gurun menyimpan ingatan, dan ingatan terakhirnya adalah suara retakan.",
        "Sejak itu badai selalu datang dari arah sarang sang Ratu."]},
    # --- Puncak Salju (biome 3)
    {"id": "s1", "biome": 3, "title": "Surat di Balik Es I", "lines": [
        "Sudah empat musim dingin aku tinggal di sini. Yeti itu tidak pernah turun gunung.",
        "Ia hanya menggeram dari puncak, seperti sedang memanggil seseorang."]},
    {"id": "s2", "biome": 3, "title": "Surat di Balik Es II", "lines": [
        "Aku pernah melihat matanya dari dekat. Biru, jernih, dan sangat letih.",
        "Kurasa ia menjaga Segel ketiga sendirian terlalu lama."]},
    {"id": "s3", "biome": 3, "title": "Dinding Gua Es", "lines": [
        "Dinding gua ini berdenyut pelan setiap tengah malam, seperti jantung yang melambat.",
        "Kata orang dulu, kalau denyutnya berhenti, dunia lupa cara menghangat."]},
    {"id": "s4", "biome": 3, "title": "Pesan Pendaki Terakhir", "lines": [
        "Aku hampir sampai puncak. Dinginnya mulai terasa seperti sentuhan tangan.",
        "Siapa pun kau, bawa ramuan lebih banyak dariku."]},
    # --- Gunung Api (biome 4)
    {"id": "v1", "biome": 4, "title": "Tulisan di Batu Panas I", "lines": [
        "Gunung ini bukan marah. Ia mengerang karena ada yang menekan dari dalam.",
        "Naga yang tinggal di jantungnya adalah yang pertama merasakan segel itu retak."]},
    {"id": "v2", "biome": 4, "title": "Tulisan di Batu Panas II", "lines": [
        "Dulu Naga Api terbang bebas di atas Greenwood dan menyalakan obor-obor desa.",
        "Kini ia hanya bisa mengamuk, tapi bara di dadanya masih ingat cara menghangatkan."]},
    {"id": "v3", "biome": 4, "title": "Dapur Magma", "lines": [
        "Para pandai kuno menempa Segel keempat di sini, lahar sebagai api dan sumpah sebagai palu.",
        "Mereka lupa satu hal: segel yang ditempa terburu-buru akan retak lebih dulu."]},
    {"id": "v4", "biome": 4, "title": "Catatan Terakhir", "lines": [
        "Empat Penjaga, empat Segel, satu kabut yang menunggu.",
        "Pembawa Segel akan datang suatu hari. Semoga ia datang sebelum semuanya terlambat."]},
    # --- Retakan di Tepi Dunia: biome 5-10 (World 1) dan 11-14 (World 2). "Catatan Selin" = jurnal murid sang pandai batu.
    # --- Shadow Reach (biome 5)
    {"id": "sh1", "biome": 5, "title": "Catatan Selin I: Tepi Peta", "lines": [
        "Namaku Selin, murid sang pandai batu. Guruku menyuruhku mencatat tempat yang tersentuh kabut sebelum ingatan tentangnya hilang.",
        "Di barat laut, bayangan jatuh ke arah yang salah. Aku mulai dari sini."]},
    {"id": "sh2", "biome": 5, "title": "Pintu Sisi Gelap", "lines": [
        "Setiap segel punya dua sisi: yang menerangi, dan yang menjaga dari dalam gelap. Penjaga sisi gelap disebut Warden.",
        "Ia berdiri di ambang pintu bayangan, menjaga agar apa yang tertidur tidak terbangun."]},
    {"id": "sh3", "biome": 5, "title": "Bisikan yang Salah", "lines": [
        "Kabut tidak membawa suara baru, hanya memutarbalikkan yang lama. Warden mendengar \"jaga\" sebagai \"buru\".",
        "Sejak itu setiap yang lewat ia kira ancaman, termasuk cahayanya sendiri."]},
    {"id": "sh4", "biome": 5, "title": "Pesan di Batu Hitam", "lines": [
        "Siapa pun yang menenangkan Warden akan mendapati bayangannya lebih ringan. Itu bukan sihir, hanya rasa lega.",
        "Lanjutkan ke utara. Ada tanah yang belum selesai ditulis, dan ia menunggu seseorang yang berani menamainya."]},
    # --- Undefined Land (biome 6)
    {"id": "un1", "biome": 6, "title": "Catatan Selin II: Tanah Kosong", "lines": [
        "Di sini tanah dan langit saling bertukar tempat. Tiga hari kujelajahi, tak satu pun batu mau diam di tempatnya.",
        "Kuberi nama pada sebuah bukit kecil. Esoknya ia sudah pindah, tapi namanya tetap ada."]},
    {"id": "un2", "biome": 6, "title": "Sebelum Ada Kata", "lines": [
        "Tanah ini lahir sebelum bahasa, jadi belum ada yang menyebutnya dan ia belum sepenuhnya selesai.",
        "Dari tanah yang belum selesai itu lahir satu penjaga. Orang menyebutnya The Unwritten, sebab tak seorang pun sempat menamainya."]},
    {"id": "un3", "biome": 6, "title": "Rupa yang Terus Berganti", "lines": [
        "The Unwritten mencoba menjadi serigala, lalu burung, lalu menara, mencari bentuk yang dikenali orang.",
        "Kabut membisikkan bahwa tak ada bentuk yang cukup baik, jadi ia terus mencoba tanpa pernah puas."]},
    {"id": "un4", "biome": 6, "title": "Tinta Terakhir", "lines": [
        "Catatan Selin tertinggal di sini: \"Aku tak berani menamai seluruh tanah ini. Itu tugas orang yang lebih berani dariku.\"",
        "Jalan berikutnya menurun ke timur laut, ke tempat laut pernah surut. Bawalah napas yang panjang."]},
    # --- Abyssal Land (biome 7)
    {"id": "ab1", "biome": 7, "title": "Catatan Selin III: Laut yang Surut", "lines": [
        "Air surut sejauh mata memandang, menyisakan palung yang bahkan cahaya enggan turuni.",
        "Bulu kudukku berdiri. Di dasar sana, sesuatu bernapas pelan, seperti makhluk yang tertidur sambil menangis."]},
    {"id": "ab2", "biome": 7, "title": "Penjaga Palung", "lines": [
        "Sebelum kabut datang, Leviathan adalah penjaga palung, menjaga agar air dan gelap tetap pada tempatnya.",
        "Para pelaut menghormatinya dan melemparkan bunga ke ombak setiap kali melewati palung itu."]},
    {"id": "ab3", "biome": 7, "title": "Sunyi yang Terlalu Lama", "lines": [
        "Para pelaut berhenti melempar bunga. Pelayaran dipindahkan, dan palung itu dilupakan.",
        "Dalam sunyi yang panjang, kabut hanya perlu berbisik: \"Tak ada yang peduli padamu.\""]},
    {"id": "ab4", "biome": 7, "title": "Bunga di Dasar Air", "lines": [
        "Di dasar palung ada satu bunga laut yang tak pernah layu. Entah siapa yang menaruhnya.",
        "Mungkin seseorang masih mengingat. Kalau kau turun, bawalah kabar itu pada sang penjaga."]},
    # --- Enchanted Forest (biome 8)
    {"id": "en1", "biome": 8, "title": "Catatan Selin IV: Hutan Berbisik", "lines": [
        "Hutan ini berbisik tanpa henti, dan aku mengerti sebagian: ia sedang menghitung ingatannya.",
        "Setiap pohon memegang satu kenangan. Kalau satu hilang, seluruh hutan ikut gelisah."]},
    {"id": "en2", "biome": 8, "title": "Akar yang Menyambung", "lines": [
        "Akar Enchanted Forest merambat jauh di bawah tanah dan bertemu akar Hutan Greenwood.",
        "Dulu keduanya berbagi satu kenangan: hari pertama kabut ditahan oleh sebatang pohon yang berani."]},
    {"id": "en3", "biome": 8, "title": "Ingatan yang Kusut", "lines": [
        "Kabut Hampa masuk lewat celah di antara kenangan, lalu mengikatnya jadi simpul.",
        "Elder Verdant kini mengingat segalanya sekaligus, dan tak sanggup memilah mana yang sudah lewat."]},
    {"id": "en4", "biome": 8, "title": "Daun Terakhir", "lines": [
        "Daun di sini jatuh dalam urutan yang sama tiap musim, seakan menulis sesuatu di tanah.",
        "Kalau kau menyusunnya dari awal sampai akhir, bunyinya: \"Ingatlah, tapi jangan terjebak.\""]},
    # --- Sakura Valley (biome 9)
    {"id": "sa1", "biome": 9, "title": "Catatan Selin V: Musim yang Berhenti", "lines": [
        "Kelopak sakura melayang di udara dan tak pernah mendarat. Setengah hari kutunggu, tak satu pun jatuh.",
        "Di sini waktu menahan napas. Aku berbisik pelan supaya tidak mengganggunya."]},
    {"id": "sa2", "biome": 9, "title": "Janji di Bawah Pohon", "lines": [
        "Sakura Empress dulu seorang ratu yang berjanji menunggu kekasihnya di bawah pohon sakura sampai musim berikutnya.",
        "Kekasihnya berlayar ke arah kabut dan tak pernah kembali."]},
    {"id": "sa3", "biome": 9, "title": "Musim yang Ditahan", "lines": [
        "Sang ratu menahan musim agar kelopak tak jatuh. Katanya, \"kalau bunga terakhir jatuh, janjiku ikut berakhir.\"",
        "Kabut Hampa menyukai janji yang tak sanggup dilepas. Ia menjadikannya rantai."]},
    {"id": "sa4", "biome": 9, "title": "Surat yang Tak Terkirim", "lines": [
        "Di bawah akar pohon tertua terkubur sepucuk surat berpita merah, tak pernah dibuka.",
        "Isinya satu kalimat: \"Jangan menungguku. Hiduplah.\" Sang Empress tak pernah sempat membacanya."]},
    # --- Mushroom Kingdom (biome 10)
    {"id": "mu1", "biome": 10, "title": "Catatan Selin VI: Tudung Raksasa", "lines": [
        "Jamur di sini sebesar rumah, dan penghuninya, para Sporeling, ramah sekali. Mereka menawariku teh dan cerita.",
        "Tapi mata mereka sayu, seperti orang yang tidur terlalu lama dan belum benar-benar bangun."]},
    {"id": "mu2", "biome": 10, "title": "Raja Jamur yang Bijak", "lines": [
        "Myconid King dulu memimpin dengan menumbuhkan: ia mengajari warganya menyuburkan tanah, bukan menaklukkannya.",
        "Lewat lorong-lorong miselium, kerajaannya diam-diam menopang akar-akar lain di seluruh benua."]},
    {"id": "mu3", "biome": 10, "title": "Mimpi yang Terlalu Manis", "lines": [
        "Kabut datang membawa mimpi: pesta tak berujung, panen yang tak pernah habis, tak ada yang berpulang.",
        "Para Sporeling tidur sambil tersenyum, dan tak seorang pun mau dibangunkan."]},
    {"id": "mu4", "biome": 10, "title": "Peringatan dari Jauh", "lines": [
        "Selin menulis tergesa: \"Miselium ini berpilin ke barat daya, lalu menghilang ke arah gerbang. Akar kabut bukan di sini.\"",
        "Gerbang Ether menanti di balik semua ini. Pembawa Segel harus menyeberang."]},
    # --- Ethergrooves (biome 11)
    {"id": "et1", "biome": 11, "title": "Catatan Selin VII: Seberang Gerbang", "lines": [
        "Kuseberangi Gerbang Ether dengan lutut gemetar. Dunia di sini lebih tua dan lebih sunyi dari yang kubayangkan.",
        "Langitnya seperti kaca retak, dan cahayanya jatuh ke tanah seperti serpihan."]},
    {"id": "et2", "biome": 11, "title": "Penjaga Langit", "lines": [
        "Ether Sovereign tidak menjaga tanah. Ia menjaga langit, agar bintang tak lepas dan atap dunia tak runtuh.",
        "Setiap malam ia menghitung bintang satu per satu, memastikan tak ada yang hilang."]},
    {"id": "et3", "biome": 11, "title": "Satu Bintang yang Padam", "lines": [
        "Pada suatu malam, kabut menelan satu bintang kecil dan Sovereign melihatnya padam.",
        "Sejak itu ia yakin langit akan runtuh kalau ia lengah sedetik saja, dan retakan pun mulai merambat."]},
    {"id": "et4", "biome": 11, "title": "Langit Itu Kuat", "lines": [
        "Langit lebih kuat daripada ketakutan siapa pun yang menjaganya.",
        "Yang membuatnya retak bukan kabut, melainkan sang penjaga yang tak berani mengendur."]},
    # --- Forgotten Kingdom (biome 12)
    {"id": "fo1", "biome": 12, "title": "Catatan Selin VIII: Kerajaan Tanpa Nama", "lines": [
        "Kutemukan gerbang kota, menara, dan jalan berlapis batu. Tapi tak ada peta, buku, atau lagu yang menyebut kota ini.",
        "Kurasa itu sebabnya ia begitu sepi: bukan karena kosong, tapi karena tak diingat."]},
    {"id": "fo2", "biome": 12, "title": "Singgasana Debu", "lines": [
        "Raja kerajaan ini dikenal adil dan dicintai rakyatnya. Namanya diukir di setiap gerbang.",
        "Kini ukiran itu terkikis, dan tak seorang pun bisa membacanya."]},
    {"id": "fo3", "biome": 12, "title": "Dilupakan Perlahan", "lines": [
        "Kabut tidak menghapus kerajaan itu sekaligus. Ia mencuri satu per satu: nama jalan, lagu pengantar tidur, lalu nama sang raja.",
        "Para ksatria tetap berjaga. Mereka tak ingat apa yang dijaga, hanya tahu bahwa mereka harus."]},
    {"id": "fo4", "biome": 12, "title": "Satu Permintaan", "lines": [
        "Di dasar singgasana tergores satu kalimat, dengan kuku dan bukan pahat: \"Sebut namaku sekali saja.\"",
        "Kalau kau membacanya, ingatlah. Itu satu-satunya hadiah yang ia minta."]},
    # --- Lumins Reef (biome 13)
    {"id": "lu1", "biome": 13, "title": "Catatan Selin IX: Terumbu yang Menyala", "lines": [
        "Terumbu di sini menyala biru dan hijau seperti kota di bawah air. Aku nyaris lupa tujuanku karena indahnya.",
        "Lalu kusadari cahayanya naik terlalu cepat, seperti pasang yang tak mau berhenti."]},
    {"id": "lu2", "biome": 13, "title": "Pemanggil Pasang", "lines": [
        "Lumina Tidecaller memanggil pasang cahaya tiap senja, supaya kapal-kapal tak tersesat dalam gelap.",
        "Para nelayan menyebutnya \"ibu terumbu\", dan tiap anak diajari menyebut namanya dengan hormat."]},
    {"id": "lu3", "biome": 13, "title": "Cahaya yang Terlalu Terang", "lines": [
        "Ketika kabut datang, Lumina melipatgandakan cahayanya untuk mengusirnya.",
        "Tapi kabut tak takut terang. Ia hanya bersembunyi di dalamnya, makin tebal di balik tiap kilau."]},
    {"id": "lu4", "biome": 13, "title": "Redup yang Menenangkan", "lines": [
        "Terumbu yang sehat tak menyala sepanjang hari. Ia redup di malam hari supaya yang hidup bisa beristirahat.",
        "Sampaikan pada sang Tidecaller: cahaya yang dipaksa terus menyala tak lagi melindungi, ia hanya melelahkan."]},
    # --- Verdan Height (biome 14)
    {"id": "ve1", "biome": 14, "title": "Catatan Selin X: Menara Hijau", "lines": [
        "Verdan Height adalah ujung dunia yang sanggup kujangkau. Pohonnya setinggi gunung, akarnya sebesar jalan raya.",
        "Semua akar itu mengalir ke satu arah, ke bawah. Aku tak berani mengikutinya."]},
    {"id": "ve2", "biome": 14, "title": "Worldroot", "lines": [
        "Worldroot adalah akar pertama, tempat semua akar hutan menyambung dan seluruh dunia bersandar.",
        "Tiap pohon, tiap miselium, tiap sungai bawah tanah berbagi napas dengannya."]},
    {"id": "ve3", "biome": 14, "title": "Yang Lapar di Bawah Akar", "lines": [
        "Sebelum Penjaga mana pun, sebelum Segel mana pun, sesuatu terbangun lapar di bawah Worldroot.",
        "Ia memakan akar, dan dari lubang bekas gigitannya merembeslah Kabut Hampa yang kemudian dikenal dunia."]},
    {"id": "ve4", "biome": 14, "title": "Catatan Terakhir Selin", "lines": [
        "Aku pulang malam ini. Aku tak sanggup menghadapi yang di bawah sana, jadi kutulis ini supaya yang sanggup tahu ke mana harus pergi.",
        "Pembawa Segel, kalau kau membaca ini, kau sudah menenangkan semua yang terluka. Tinggal yang lapar. Tolong, akhiri ini."]},
]


# Biome asli: 16 prasasti pertama punya hadiah tersendiri
const CLASSIC := [1, 2, 3, 4]


static func _all_found(biomes: Array) -> bool:
    for st in STONES:
        if biomes.has(int(st["biome"])) and not found(String(st["id"])):
            return false
    return true


static func _d() -> Dictionary:
    if not Game.p.has("lore") or typeof(Game.p["lore"]) != TYPE_DICTIONARY:
        Game.p["lore"] = {}
    return Game.p["lore"]


static func total() -> int:
    return STONES.size()


static func found(id: String) -> bool:
    return int(_d().get(id, 0)) > 0


static func count() -> int:
    var n := 0
    for s in STONES:
        if found(String(s["id"])):
            n += 1
    return n


static func biome_total(b: int) -> int:
    var n := 0
    for s in STONES:
        if int(s["biome"]) == b:
            n += 1
    return n


static func biome_count(b: int) -> int:
    var n := 0
    for s in STONES:
        if int(s["biome"]) == b and found(String(s["id"])):
            n += 1
    return n


static func get_def(id: String) -> Dictionary:
    for s in STONES:
        if String(s["id"]) == id:
            return s
    return {}


# Tandai prasasti terbaca (pertama kali = hadiah). Kembalikan {"first": bool, "msg": String, "banner": String}
static func mark(id: String, pl) -> Dictionary:
    var out := {"first": false, "msg": "", "banner": ""}
    if found(id):
        return out
    var d: Dictionary = get_def(id)
    if d.is_empty():
        return out
    _d()[id] = 1
    out["first"] = true
    var lv: int = int(Game.p["level"])
    var coins: int = 60 + lv * 8
    var gems: int = 4
    var items := {}
    var b: int = int(d["biome"])
    var extra := ""
    if biome_count(b) >= biome_total(b):
        var bg: int = 30 if b <= 4 else 50
        gems += bg
        items["potion_hp2"] = 2 if b <= 4 else 4
        extra = "  Semua prasasti wilayah ini terbaca! (+%d gem)" % bg
    if b <= 4 and _all_found(CLASSIC):
        # 16 prasasti pertama (hadiah lama tetap ada)
        gems += 200
        coins += 5000 + lv * 100
        items["potion_mp2"] = int(items.get("potion_mp2", 0)) + 5
        out["banner"] = "Semua prasasti kuno terbaca: Penerus Para Penjaga!"
    if count() >= total():
        gems += 500
        coins += 20000 + lv * 200
        items["potion_mp2"] = int(items.get("potion_mp2", 0)) + 10
        out["banner"] = "Semua prasasti di kedua dunia terbaca: Penjaga Ingatan!"
    Game.p["coins"] = int(Game.p["coins"]) + coins
    Game.p["gems"] = int(Game.p["gems"]) + gems
    for it in items.keys():
        pl.add_item(String(it), int(items[it]))
    pl.give_xp(int(float(Bal.quest_xp(lv)) * 0.2))
    out["msg"] = "Prasasti ditemukan (%d/%d)  +%d koin, +%d gem%s" % [count(), total(), coins, gems, extra]
    Game.save()
    return out
