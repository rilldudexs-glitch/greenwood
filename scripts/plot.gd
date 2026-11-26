extends RefCounted
# Alur plot: flashback kesaksian, twist Tetua Oren, hilangnya Bibi Lumut (w1), desa yang berubah, dan 3 ending
# setelah Worldroot Devourer. Data di Game.p["plot"]: {"twist": 0/1, "lost": 0/1, "end": "", "stage": int, "flash": {id: 1}}.

const Secrets = preload("res://scripts/secrets.gd")

const FLASH := {
    "w1": ["Akar muda di Greenwood dulu hijau sampai ke ujungnya.", "Lalu suatu malam semua pohon berdesir pelan, dan akar-akar itu mulai menghitam dari ujung, satu demi satu."],
    "w2": ["Sumur terakhir oasis berbunyi seperti sedang ditarik dari bawah.", "Airnya turun, turun, lalu lenyap tanpa suara."],
    "w3": ["Es merayap naik ke gua hangat yang dulu jadi rumah Yeti.", "Yeti menatap ke selatan lama sekali, lalu meraung pada dingin yang bukan miliknya."],
    "w4": ["Di dalam tungku, retak pada segel terakhir bersinar merah.", "Penenun Akar pertama menempanya sambil menangis, tahu segel itu tak akan bertahan selamanya."],
    "w5": ["Kabut menjilat bayangan di Shadow Reach satu per satu.", "Aldric menulis secepat mungkin, dan kabut mengikuti ujung penanya."],
    "w6": ["Halaman tentang Benih Pertama memudar, kata demi kata.", "Ezra mencoba menyalinnya, tapi tintanya menguap sebelum kering."],
    "w7": ["Malam ketujuh, laut tak lagi berdenyut.", "Leviathan menatap dasar, menunggu jantung yang tak pernah kembali."],
    "w8": ["Seorang pria bermahkota karat berlutut di akar terdalam.", "Pisau peraknya gemetar. Air matanya jatuh ke tanah, tepat di tempat benih bercahaya."],
    "w9": ["Kelopak terakhir berhenti jatuh di tengah udara.", "Sang Permaisuri menahannya, takut ingatan tentang benih ikut gugur bersamanya."],
    "w10": ["Jamur menjalar di tubuh rakyat yang terkena Wabah Layu.", "Sang raja menggenggam benih bercahaya dan berbisik, 'Satu hari saja. Beri aku satu hari.'"],
    "w11": ["Dari awan terlihat akar menjulur ke langit, mencari makan.", "Petir pertama retak tanpa ada awan di atasnya."],
    "w12": ["Putri kecil itu tersenyum untuk terakhir kalinya sebelum Wabah Layu merenggutnya.", "Esok harinya benih retak. Kerajaan itu menyusut, lalu dilupakan dunia."],
    "w13": ["Benih yang retak hanyut ke laut dan berkedip di antara karang.", "Lumina melingkarinya pelan, menjaganya dari kegelapan yang kelaparan."],
    "w14": ["Seorang anak keturunan raja menancapkan tugu cahaya pertama di tanah yang gersang.", "'Beri benih jalan pulang,' bisiknya. 'Biar aku yang menanggung dosanya.'"],
}

const MOOD := {
    0: ["Desa ini damai. Semoga tetap begitu.", "Panen bagus tahun ini!", "Kudengar ada pengembara yang membantu Tetua Oren."],
    1: ["Kau lihat kabut tipis di tepi hutan pagi tadi?", "Ayam-ayam gelisah akhir-akhir ini.", "Malam terasa lebih dingin dari biasanya."],
    2: ["Kabutnya makin dekat ke desa. Aku mulai takut.", "Anak-anak dilarang main dekat hutan.", "Banyak yang bilang kita harus mengungsi."],
    3: ["Kabut sudah menyentuh pagar desa... tapi katanya ada yang berjuang untuk kita.", "Kami hanya bisa berdoa untukmu, pengembara.", "Tetua Oren tampak gelisah, seperti menyimpan sesuatu."],
    4: ["Kabut mereda, tapi akar dunia tampak layu. Entah sampai kapan.", "Kita selamat, tapi rasanya ini belum benar-benar selesai."],
    5: ["Ada pohon raksasa tumbuh di jantung dunia. Katanya itu kamu, pengembara.", "Kabut lenyap. Kami hidup tenang berkat pengorbananmu."],
    6: ["Tunas benih baru tumbuh di dekat desa! Dunia bernapas lagi.", "Bunga mekar di mana-mana. Terima kasih, Pembawa Benih!"],
}


static func p() -> Dictionary:
    if not Game.p.has("plot") or typeof(Game.p["plot"]) != TYPE_DICTIONARY:
        Game.p["plot"] = {}
    return Game.p["plot"]


static func ending() -> String:
    return String(p().get("end", ""))


# ------------------------------------------------------------------ desa berubah
static func village_stage() -> int:
    var e := ending()
    if e == "kill":
        return 4
    if e == "feed":
        return 5
    if e == "replant":
        return 6
    var t: int = Secrets.truth_count()
    if t < 3:
        return 0
    if t < 7:
        return 1
    if t < 11:
        return 2
    return 3


static func mood_line(seed: int) -> String:
    var a: Array = MOOD[village_stage()]
    return String(a[seed % a.size()])


# Dipanggil setiap kali pemain memuat/menyelesaikan kesaksian; menampilkan banner saat desa naik tahap
static func check_stage(hud) -> void:
    var s: int = village_stage()
    if s <= int(p().get("stage", 0)) or s > 3:
        return
    p()["stage"] = s
    var msgs := {1: "Kabut tipis terlihat di tepi Desa Greenwood...", 2: "Kabut makin dekat ke Desa Greenwood.", 3: "Kabut menyentuh pagar Desa Greenwood!"}
    if hud and msgs.has(s):
        hud.show_banner(String(msgs[s]), 3.5)


# Setelah satu kesaksian selesai: flashback sekali, lalu callback
static func on_testimony(id: String, hud, then: Callable = Callable()) -> void:
    check_stage(hud)
    var fl: Dictionary = p().get("flash", {})
    p()["flash"] = fl
    if FLASH.has(id) and not fl.has(id):
        fl[id] = 1
        Game.save()
        hud.flashback("Kilas Balik", FLASH[id], then)
    elif then.is_valid():
        then.call()


# ------------------------------------------------------------------ Bibi Lumut (w1)
# fase 0 = normal, 1 = firasat (4+ kesaksian), 2 = perpisahan (6+ kesaksian), 3 = sudah hilang
static func w1_phase() -> int:
    if int(p().get("lost", 0)) == 1:
        return 3
    if not Secrets.finished("w1"):
        return 0
    var t: int = Secrets.truth_count()
    if t >= 6:
        return 2
    if t >= 4:
        return 1
    return 0


static func w1_lost() -> bool:
    return int(p().get("lost", 0)) == 1


static func w1_foreboding() -> Array:
    return [
        "Kabutnya sudah sampai ke akar yang tidak terjangkau, Nak.",
        "@p:Bibi pucat sekali. Bibi baik-baik saja?",
        "Aku sudah tua, tapi akar muda di sini masih perlu dijaga. Datanglah lagi kalau kau sempat.",
    ]


static func run_w1_goodbye(npc, hud, pl) -> void:
    var lines: Array = [
        "Kau datang... Duduklah sebentar, Nak.",
        "@p:Bibi? Kabut di sekeliling Bibi...",
        "Tidak apa-apa. Kabut ini bukan jahat, hanya lapar. Aku sudah lama merasakannya memanggilku.",
        "@p:Aku bisa membawa Bibi pergi dari sini!",
        "Jangan. Akar-akar muda ini belum selesai tumbuh, dan seseorang harus tinggal bersama mereka. Terima kasih sudah mendengarkan ceritaku.",
        "Ini, bawalah teh daunku. Minumlah kalau kau lelah, dan ingat: akar yang sakit hanyalah akibat, bukan akhir.",
    ]
    hud.say(npc.npc_name, lines, _w1_vanish.bind(npc, hud, pl))


static func _w1_vanish(npc, hud, pl) -> void:
    p()["lost"] = 1
    pl.add_item("bi_1_c", 5)
    Game.save()
    Audio.sfx("heal")
    hud.show_banner("Kabut menelan Bibi Lumut...", 4.0)
    hud.toast("Bibi Lumut memberimu 5 Teh Rimba.")
    if is_instance_valid(npc):
        npc.fade_out()


# ------------------------------------------------------------------ twist Tetua Oren
static func twist_ready() -> bool:
    return int(p().get("twist", 0)) == 0 and Secrets.truth_count() >= 13


static func run_twist(npc, hud, pl) -> void:
    var flash: Array = [
        "Gerbang akar, tengah malam. Seorang penjaga muda berjubah penenun berdiri menghalangi seorang raja.",
        "Raja itu memohon, 'Putriku sekarat. Hanya benih itu yang tersisa.'",
        "Si penjaga muda menurunkan tongkatnya, dan membiarkan raja itu lewat.",
    ]
    hud.flashback("Malam Pencabutan", flash, _twist_talk.bind(npc, hud, pl))


static func _twist_talk(npc, hud, pl) -> void:
    var lines: Array = [
        "Kau sudah mengumpulkan semua kesaksian, Nak. Maka kini giliranku jujur.",
        "@p:Tetua... apa maksudmu?",
        "Penjaga muda dalam ingatan itu adalah aku. Aku Penenun Akar terakhir, dan akulah yang membiarkan sang raja mencabut Benih Pertama.",
        "@p:Jadi Tetua sudah tahu semuanya sejak awal?",
        "Sejak hari pertama kau datang. Aku tak sanggup menghadapinya sendirian. Aku menyuruhmu mencari kesaksian supaya ada yang berani mendengar kebenaran, dan memaafkanku bila bisa.",
        "@p:Tetua keliru. Tapi menyembunyikannya lebih lama hanya akan menambah luka.",
        "Terima kasih. Pergilah menemui Aldric. Dia keturunan raja itu, dan dia menunggumu.",
    ]
    hud.say(npc.npc_name, lines, _twist_done.bind(hud, pl))


static func _twist_done(hud, pl) -> void:
    p()["twist"] = 1
    Game.p["gems"] = int(Game.p["gems"]) + 150
    Game.save()
    Audio.sfx("levelup")
    hud.show_banner("KEBENARAN TERUNGKAP", 3.5)
    hud.toast("Tetua Oren memberimu 150 gem sebagai tanda maaf.")


# ------------------------------------------------------------------ ending
static func ending_pending() -> bool:
    return ending() == "" and int(Game.p.get("bosskills", {}).get("devourer", 0)) >= 1


static func ending_scene() -> void:
    if not ending_pending():
        return
    var hud = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("hud")
    if hud == null:
        return
    var fl: Array = [
        "Worldroot Devourer berhenti bergerak. Akar-akar raksasanya bergetar pelan, tak lagi mengamuk.",
        "Di dasar tubuhnya, serpihan Benih Pertama berkedip. Lapar itu tak hilang, hanya menunggu.",
        "Kabut diam. Dunia menahan napas. Semuanya tergantung pada apa yang kau lakukan sekarang.",
    ]
    hud.flashback("Akar Terdalam", fl, _ending_ask.bind(hud))


static func _ending_ask(hud) -> void:
    hud.choose("Akar Terdalam", "Pilihan ini PERMANEN.\nApa yang kau lakukan pada akar yang lapar ini?",
        ["Akhiri dia (Bunuh)", "Beri makan dengan benihmu", "Tanam kembali Benih Pertama"], _ending_pick.bind(hud))


static func _ending_pick(i: int, hud) -> void:
    var e: String = ["kill", "feed", "replant"][clampi(i, 0, 2)]
    var texts := {
        "kill": ["Kau mengakhirinya. Akar itu layu dalam diam, dan kabut perlahan mereda.", "Tapi tanpa Benih, akar dunia akan kelaparan lagi suatu hari nanti. Kau memberi dunia waktu, bukan penyembuhan."],
        "feed": ["Kau menanamkan cahaya benihmu ke akar yang lapar.", "Tubuhmu menyatu dengan akar dunia, dan kau menjadi penjaganya. Kabut lenyap, dan kau dikenang sebagai Penjaga Akar."],
        "replant": ["Kau menanam kembali serpihan Benih Pertama di akar terdalam.", "Cahaya hijau menjalar ke seluruh dunia. Tunas baru tumbuh. Dunia sembuh, dan kau mewarisi kekuatan benih itu."],
    }
    p()["end"] = e
    p()["stage"] = 3
    var gems := {"kill": 300, "feed": 200, "replant": 200}
    Game.p["gems"] = int(Game.p["gems"]) + int(gems[e])
    if e == "kill":
        Game.p["coins"] = int(Game.p["coins"]) + 20000
    Game.save()
    var pl = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("player")
    if pl:
        pl.recalc()
    Audio.sfx("levelup")
    var titles := {"kill": "ENDING: AKAR YANG LAYU", "feed": "ENDING: PENJAGA AKAR", "replant": "ENDING: BENIH BARU"}
    hud.show_banner(String(titles[e]), 5.0)
    hud.flashback("Epilog", texts[e])


# Pengali pasif dari ending (dipakai Jobs.mul)
# Ending yang pernah dicapai (tetap tersimpan setelah New Game+ mereset cerita)
static func ending_kept() -> String:
    var e := ending()
    return e if e != "" else String(Game.p.get("ng_end", ""))


static func end_mul(k: String) -> float:
    if ending_kept() == "feed" and (k == "hp" or k == "def"):
        return 1.15
    return 1.0
