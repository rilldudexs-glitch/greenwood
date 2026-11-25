extends RefCounted
# Kisah Utama: "Segel Para Penjaga". Quest berantai dengan alur cerita (bukan quest harian acak).
# Dipakai oleh npc.gd (dialog), hud.gd (pelacak), main.gd (kunjungan wilayah), boss.gd & enemy.gd (progres).
#
# Data di Game.p["story"]:  {"ch": bab sekarang, "on": sudah diterima, "n": notifikasi selesai sudah muncul,
#                            "k": {jenis: jumlah kill saat bab diterima}, "v": {biome: 1} wilayah yang sudah dikunjungi}
# Data di Game.p["bosskills"]: {style bos: berapa kali dikalahkan}  (seumur hidup, jadi bos yang sudah dikalahkan sebelum quest tetap dihitung)
#
# Jenis tujuan per bab (semua boleh digabung):
#   "kill"  = {jenis_musuh: jumlah}   dihitung sejak bab diterima
#   "boss"  = {style_bos: jumlah}     dihitung seumur hidup
#   "visit" = [id biome]              dihitung seumur hidup (lihat Story.visit)
#   tanpa tujuan = hanya perlu bicara dengan NPC "turnin"

const Bal = preload("res://scripts/balance.gd")

const NPC_NAMES := {"elder": "Tetua Oren", "gatekeeper": "Penjaga Gerbang Ether"}
const BIOME_NAMES := {1: "Hutan Greenwood", 2: "Gurun Berdebu", 3: "Puncak Salju", 4: "Gunung Api",
    5: "Shadow Reach", 6: "Undefined Land", 7: "Abyssal Land", 8: "Enchanted Forest", 9: "Sakura Valley", 10: "Mushroom Kingdom", 11: "Ethergrooves", 12: "Forgotten Kingdom", 13: "Lumins Reef", 14: "Verdan Height", 15: "Crystal Cavern"}
const NAMES := {
    "slime": "Slime", "bee": "Lebah", "goblin": "Goblin", "spider": "Laba-laba", "wolf": "Serigala", "kobold": "Kobold",
    "mummy": "Mumi", "centipede": "Kelabang",
    "ent": "Ent Kuno", "scorpion": "Ratu Kalajengking", "yeti": "Yeti Perkasa", "dragon": "Naga Api",
    "umbral_slime": "Umbral Slime",
    "shade_stalker": "Shade Stalker",
    "hollow_wisp": "Hollow Wisp",
    "ashen_fiend": "Ashen Fiend",
    "abyss_eel": "Abyss Eel",
    "deep_maw": "Deep Maw",
    "thorn_sprite": "Thorn Sprite",
    "mossback_bear": "Mossback Bear",
    "petal_fox": "Petal Fox",
    "crimson_koi": "Crimson Koi",
    "sporeling": "Sporeling",
    "mushroom_brute": "Mushroom Brute",
    "ether_drake": "Ether Drake",
    "cloud_wisp": "Cloud Wisp",
    "ruins_sentinel": "Ruins Sentinel",
    "forgotten_knight": "Forgotten Knight",
    "lumin_ray": "Lumin Ray",
    "pearl_wisp": "Pearl Wisp",
    "verdan_stag": "Verdan Stag",
    "canopy_hunter": "Canopy Hunter",
    "warden": "Warden of Shadows",
    "unwritten": "The Unwritten",
    "leviathan": "Abyss Leviathan",
    "verdant": "Elder Verdant",
    "sakura": "Sakura Empress",
    "myconid": "Myconid King",
    "ether": "Ether Sovereign",
    "monarch": "Forgotten Monarch",
    "lumina": "Lumina Tidecaller",
    "colossus": "Verdant Colossus",
    "devourer": "Worldroot Devourer",
}

# reward: m = pengali hadiah (koin/XP mengikuti level pemain), gems, items
const CHAPTERS := [
    {
        "title": "Bisikan di Desa", "rec": 1, "where": "Sekitar desa",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Duduklah sebentar, pengembara. Sudah tiga malam desa ini mendengar bisikan dari balik hutan.",
            "Slime dan lebah jadi lebih ganas dari biasanya. Seperti ada yang mengusik mereka.",
            "Bantu aku memeriksanya. Mulai dari yang dekat: kalahkan 6 Slime dan 4 Lebah.",
        ],
        "kill": {"slime": 6, "bee": 4},
        "done": [
            "Hm... kabut tipis menempel di tubuh mereka. Persis seperti cerita kakekku dulu.",
            "Terima kasih, Nak. Tapi ini baru permulaan.",
        ],
        "reward": {"m": 1.0, "gems": 15},
    },
    {
        "title": "Jejak di Hutan", "rec": 7, "where": "Hutan Greenwood (barat)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Bekas cakar dan jejak aneh mengarah ke Hutan Greenwood, di sebelah barat.",
            "Pergilah ke sana dan lihat sendiri. Kalahkan 8 Goblin dan 4 Laba-laba yang menjaga jalan.",
            "Kalau benar dugaanku, mereka membawa sesuatu yang bukan milik mereka.",
        ],
        "visit": [1],
        "kill": {"goblin": 8, "spider": 4},
        "done": [
            "Serpihan batu yang bercahaya... Ini pecahan Segel Penjaga! Jadi dongeng itu benar.",
            "Ada empat Penjaga yang dulu mengurung Kabut Hampa. Segel mereka kini mulai retak.",
        ],
        "reward": {"m": 1.3, "gems": 20, "items": {"potion_hp2": 2}},
    },
    {
        "title": "Serigala Kelaparan", "rec": 15, "where": "Lereng di timur desa",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Serigala dan kobold turun dari lereng. Mereka bukan lapar, mereka lari dari sesuatu.",
            "Kurangi jumlah mereka supaya desa aman, selagi aku menyusun catatan kuno. Kalahkan 10 Serigala dan 6 Kobold.",
        ],
        "kill": {"wolf": 10, "kobold": 6},
        "done": [
            "Catatannya rampung. Dengarkan baik-baik.",
            "Empat Penjaga: Ent Kuno di hutan, Ratu Kalajengking di gurun, Yeti di puncak salju, dan Naga Api di gunung api.",
            "Mereka bukan jahat. Segelnya retak dan mereka kesakitan. Hanya kamu yang bisa menenangkan mereka.",
        ],
        "reward": {"m": 1.5, "gems": 25, "items": {"potion_hp2": 2, "potion_mp2": 2}},
    },
    {
        "title": "Raja Hutan", "rec": 150, "where": "Sarang Ent Kuno, Hutan Greenwood",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Penjaga pertama: Ent Kuno, jauh di dalam hutan. Dia pohon tertua di dunia ini.",
            "Rasa sakitnya membuat dia mengamuk. Jangan remehkan dia, bawa banyak ramuan.",
            "Kalahkan Ent Kuno, dan serpihan segelnya akan pulih.",
        ],
        "boss": {"ent": 1},
        "done": [
            "Kamu merasakannya? Angin hutan jadi tenang lagi.",
            "Satu segel pulih. Tiga lagi.",
        ],
        "reward": {"m": 2.5, "gems": 60, "items": {"potion_hp2": 3}},
    },
    {
        "title": "Pasir yang Bisu", "rec": 115, "where": "Gurun Berdebu (timur)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Kafilah dari gurun berhenti datang. Pasir di sana terlalu sunyi.",
            "Pergilah ke Gurun Berdebu. Kalahkan 8 Mumi dan 5 Kelabang untuk membuka jalan.",
        ],
        "visit": [2],
        "kill": {"mummy": 8, "centipede": 5},
        "done": [
            "Jadi pasir itu menyimpan sarang di bawahnya. Kamu sudah melihat tandanya, kan?",
            "Ratu Kalajengking tidak akan tinggal diam setelah ini.",
        ],
        "reward": {"m": 2.0, "gems": 35, "items": {"potion_hp2": 2}},
    },
    {
        "title": "Ratu Kalajengking", "rec": 230, "where": "Sarang Ratu Kalajengking, Gurun Berdebu",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Penjaga kedua: Ratu Kalajengking. Capitnya membelah batu, ekornya mengalirkan racun gurun.",
            "Dia cepat dan keras kepala. Kalahkan dia sebelum badai pasir berikutnya.",
        ],
        "boss": {"scorpion": 1},
        "done": [
            "Pasir mulai berbisik lagi, kali ini dengan tenang.",
            "Dua segel pulih. Sisanya ada di tempat yang jauh lebih dingin... dan lebih panas.",
        ],
        "reward": {"m": 3.0, "gems": 80, "items": {"potion_hp2": 3, "potion_mp2": 3}},
    },
    {
        "title": "Dingin yang Menyala", "rec": 310, "where": "Puncak Salju (utara)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Di utara, Puncak Salju membeku lebih dalam setiap hari. Yeti Perkasa menjaga puncaknya.",
            "Perjalanan ke sana berat. Naiki puncaknya dan kalahkan Yeti Perkasa.",
        ],
        "visit": [3],
        "boss": {"yeti": 1},
        "done": [
            "Salju berhenti turun. Kamu lihat, kan, matanya sebelum dia tumbang? Dia memohon.",
            "Tiga segel pulih. Tinggal yang terakhir.",
        ],
        "reward": {"m": 3.5, "gems": 100, "items": {"potion_hp2": 4}},
    },
    {
        "title": "Api Terakhir", "rec": 400, "where": "Sarang Naga Api, Gunung Api (selatan)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Penjaga terakhir: Naga Api, di jantung Gunung Api. Dialah yang pertama kali merasakan segel retak.",
            "Ini pertarungan paling berat. Siapkan perlengkapan terbaikmu dan kalahkan Naga Api.",
        ],
        "visit": [4],
        "boss": {"dragon": 1},
        "done": [
            "Gunung itu diam. Untuk pertama kalinya dalam seratus tahun.",
            "Empat serpihan kini ada padamu. Bawalah ke Penjaga Gerbang Ether, dia tahu cara menyatukannya.",
        ],
        "reward": {"m": 4.0, "gems": 120, "items": {"potion_hp2": 5, "potion_mp2": 5}},
    },
    {
        "title": "Gerbang Bergema", "rec": 200, "where": "Gerbang Ether",
        "giver": "elder", "turnin": "gatekeeper",
        "intro": [
            "Temui Penjaga Gerbang Ether. Serpihan segel itu akan menyatu di hadapannya.",
            "Dunia di balik gerbang itu menyimpan jawaban tentang Kabut Hampa. Pergilah, pengembara.",
        ],
        "done": [
            "Serpihan di tanganmu bergetar... Empat Penjaga sudah tenang. Segel utuh kembali.",
            "Kabut Hampa takkan menyebar. Gerbang mengenalimu sebagai Pembawa Segel.",
            "Ketika levelmu mencapai 200, dunia di balik gerbang terbuka untukmu.",
            "Satu lagi: Tetua Oren menunggumu di desa. Kabut Hampa meninggalkan jejak di tepi peta, dan dia ingin kamu melihatnya.",
        ],
        "reward": {"m": 6.0, "gems": 300, "items": {"potion_hp2": 5, "potion_mp2": 5}},
    },
    # --- Retakan di Tepi Dunia: satu bab per wilayah ekspansi (biome 5-10 di World 1, 11-14 di World 2)
    {
        "title": "Bayangan di Tepi Peta", "rec": 430, "where": "Shadow Reach (barat laut)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Segel sudah utuh, tapi aku tetap tidak bisa tidur. Bayangan di barat laut desa makin panjang, bahkan saat tengah hari.",
            "Kabut Hampa sempat merembes keluar sebelum segelnya pulih, lalu menetap di tepi peta. Namanya Shadow Reach.",
            "Masuklah ke sana. Kalahkan 12 Umbral Slime dan 8 Shade Stalker, lalu temui penguasanya: Warden of Shadows.",
        ],
        "visit": [5],
        "kill": {"umbral_slime": 12, "shade_stalker": 8},
        "boss": {"warden": 1},
        "done": [
            "Bayanganmu sendiri terasa lebih ringan, kan? Warden itu dulu penjaga sisi gelap segel.",
            "Dia tidak mengamuk karena benci. Kabut membuatnya lupa bahwa dia sedang menjaga, bukan memburu.",
            "Satu luka di tepi peta tertutup. Masih ada yang lain.",
        ],
        "reward": {"m": 7.0, "gems": 150, "items": {"potion_hp2": 6, "potion_mp2": 6}},
    },
    {
        "title": "Tanah yang Belum Ditulis", "rec": 500, "where": "Undefined Land (utara jauh)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Peta tuaku punya bagian kosong di utara. Bukan belum dijelajahi, tapi memang belum pernah ditulis siapa pun.",
            "Tanah dan langit di sana tampak patah-patah, seperti gambar yang belum selesai. Itulah Undefined Land.",
            "Kalahkan 12 Hollow Wisp dan 8 Ashen Fiend yang berkeliaran, lalu hadapi The Unwritten.",
        ],
        "visit": [6],
        "kill": {"hollow_wisp": 12, "ashen_fiend": 8},
        "boss": {"unwritten": 1},
        "done": [
            "Kamu melihatnya, kan? Makhluk itu terus berganti rupa, seperti mencari bentuk yang pantas.",
            "Kabut Hampa paling betah di tempat yang belum bernama. Setelah The Unwritten tumbang, tanah itu mulai punya bentuk.",
            "Mungkin suatu hari seseorang akan menuliskan namanya. Mungkin kamu.",
        ],
        "reward": {"m": 7.5, "gems": 170, "items": {"potion_hp2": 6, "potion_mp2": 6}},
    },
    {
        "title": "Palung Tanpa Dasar", "rec": 570, "where": "Abyssal Land (timur laut)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Para nelayan bercerita laut di timur laut surut tiba-tiba dan menyisakan palung yang gelap dan dalam. Mereka menyebutnya Abyssal Land.",
            "Sesuatu yang sangat besar bergerak di dasarnya. Kalahkan 12 Abyss Eel dan 8 Deep Maw yang menjaga tepinya.",
            "Lalu turunlah dan temui Abyss Leviathan. Jangan terlalu lama, napas ada batasnya.",
        ],
        "visit": [7],
        "kill": {"abyss_eel": 12, "deep_maw": 8},
        "boss": {"leviathan": 1},
        "done": [
            "Air laut kembali pasang. Nelayan sampai menangis di dermaga.",
            "Leviathan itu bukan monster. Dia penjaga palung yang terlalu lama sendirian dalam gelap.",
            "Kabut bisa masuk lewat hati yang kesepian. Ingat itu, Nak.",
        ],
        "reward": {"m": 8.0, "gems": 190, "items": {"potion_hp2": 7, "potion_mp2": 7}},
    },
    {
        "title": "Hutan yang Mengingat", "rec": 650, "where": "Enchanted Forest (tenggara)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Pohon-pohon di tenggara berbisik dalam bahasa yang tidak kukenal. Hutan itu menyimpan ingatan semua yang pernah tumbuh di sana.",
            "Sekarang ingatannya kusut oleh kabut. Kalahkan 14 Thorn Sprite dan 8 Mossback Bear supaya jalan ke Enchanted Forest terbuka.",
            "Di jantungnya ada Elder Verdant. Hadapi dia dengan hormat, usianya sudah sangat tua.",
        ],
        "visit": [8],
        "kill": {"thorn_sprite": 14, "mossback_bear": 8},
        "boss": {"verdant": 1},
        "done": [
            "Daun-daun berhenti berbisik. Sekarang terdengar seperti nyanyian.",
            "Elder Verdant mengingat semuanya, termasuk para pengembara yang lewat sebelum kamu. Dia menitip salam.",
            "Hutan itu bersaudara dengan Hutan Greenwood. Akarnya menyambung jauh di bawah tanah.",
        ],
        "reward": {"m": 8.5, "gems": 210, "items": {"potion_hp2": 7, "potion_mp2": 7}},
    },
    {
        "title": "Kelopak yang Tak Jatuh", "rec": 710, "where": "Sakura Valley (selatan jauh)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Pengembara yang pulang dari selatan membawa kelopak sakura yang tidak pernah layu. Di Sakura Valley, kelopak itu tidak pernah jatuh.",
            "Waktu di sana seperti berhenti. Kalahkan 14 Petal Fox dan 8 Crimson Koi untuk mendekat.",
            "Penguasanya adalah Sakura Empress. Konon dia menahan musim demi seseorang yang tak kunjung pulang.",
        ],
        "visit": [9],
        "kill": {"petal_fox": 14, "crimson_koi": 8},
        "boss": {"sakura": 1},
        "done": [
            "Kelopaknya akhirnya jatuh? Bagus. Musim memang harus berganti, sesedih apa pun.",
            "Sang Empress menahan waktu karena tak sanggup melepaskan. Kabut Hampa memakai kesedihan itu.",
            "Kadang menolong seseorang berarti membantunya melepaskan.",
        ],
        "reward": {"m": 9.0, "gems": 230, "items": {"potion_hp2": 8, "potion_mp2": 8}},
    },
    {
        "title": "Kerajaan di Bawah Tudung", "rec": 780, "where": "Mushroom Kingdom (barat daya)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Yang terakhir dari tepi peta dunia ini: Mushroom Kingdom di barat daya. Jamur-jamurnya tumbuh sebesar rumah.",
            "Penghuninya mengira kabut itu mimpi indah dan tidak mau bangun. Yang terkena kabut jadi ganas, jangan ragu melawan mereka.",
            "Kalahkan 14 Sporeling dan 8 Mushroom Brute, lalu hadapi Myconid King.",
        ],
        "visit": [10],
        "kill": {"sporeling": 14, "mushroom_brute": 8},
        "boss": {"myconid": 1},
        "done": [
            "Tudung-tudung jamur bergoyang pelan. Mereka akhirnya bangun, dan mereka berterima kasih.",
            "Enam luka di tepi dunia ini sudah tertutup. Aku bangga padamu, Nak.",
            "Tapi kabut tidak berasal dari sini. Akarnya ada jauh di balik Gerbang Ether. Bersiaplah untuk World 2.",
        ],
        "reward": {"m": 10.0, "gems": 300, "items": {"potion_hp2": 8, "potion_mp2": 8}},
    },
    {
        "title": "Langit yang Retak", "rec": 840, "where": "Ethergrooves (World 2, barat laut)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Dunia di balik gerbang ini lebih tua dari Greenwood. Langit di Ethergrooves retak seperti kaca, dan cahayanya jatuh ke tanah.",
            "Kalahkan 14 Ether Drake dan 8 Cloud Wisp yang mengitarinya.",
            "Lalu temui Ether Sovereign, penguasa langit di sana.",
        ],
        "visit": [11],
        "kill": {"ether_drake": 14, "cloud_wisp": 8},
        "boss": {"ether": 1},
        "done": [
            "Langitnya menyatu lagi. Dari sini bahkan bintang-bintang terlihat.",
            "Ether Sovereign menjaga langit supaya tidak runtuh. Kabut membuatnya takut langit akan jatuh, dan ketakutan itu yang meretakkannya.",
            "Ada pola di semua ini, Nak. Tiap penguasa disakiti lewat hal yang paling mereka takuti.",
        ],
        "reward": {"m": 10.5, "gems": 320, "items": {"potion_hp2": 9, "potion_mp2": 9}},
    },
    {
        "title": "Raja yang Dilupakan", "rec": 900, "where": "Forgotten Kingdom (World 2, timur laut)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Di timur laut ada reruntuhan kerajaan yang tak tercatat di buku mana pun. Orang bukan lupa tempatnya, mereka lupa bahwa tempat itu pernah ada.",
            "Kabut Hampa memakan hal-hal yang terlupakan. Kalahkan 14 Ruins Sentinel dan 8 Forgotten Knight yang masih setia berjaga.",
            "Lalu hadapi rajanya: Forgotten Monarch.",
        ],
        "visit": [12],
        "kill": {"ruins_sentinel": 14, "forgotten_knight": 8},
        "boss": {"monarch": 1},
        "done": [
            "Sekarang kerajaan itu punya satu orang yang mengingatnya. Kamu.",
            "Sang Monarch tidak menuntut apa-apa selain diingat. Itu saja yang dia inginkan selama berabad-abad.",
            "Akan kutulis di catatan desa supaya tidak ada yang melupakannya lagi.",
        ],
        "reward": {"m": 11.0, "gems": 340, "items": {"potion_hp2": 9, "potion_mp2": 9}},
    },
    {
        "title": "Pasang Cahaya", "rec": 950, "where": "Lumins Reef (World 2, tenggara)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Di tenggara, terumbu yang bercahaya itu tidak lagi indah. Cahayanya terus naik seperti pasang yang tak mau surut.",
            "Hati-hati, Lumins Reef memikat lalu menenggelamkan. Kalahkan 16 Lumin Ray dan 8 Pearl Wisp di tepinya.",
            "Setelah itu temui Lumina Tidecaller, sang pemanggil pasang.",
        ],
        "visit": [13],
        "kill": {"lumin_ray": 16, "pearl_wisp": 8},
        "boss": {"lumina": 1},
        "done": [
            "Terumbunya meredup dengan lembut. Cahaya yang tenang ternyata yang paling indah.",
            "Lumina memanggil pasang cahaya untuk mengusir kabut, tapi kabut justru tumbuh di dalam cahaya itu.",
            "Niat baik pun bisa diperalat kalau tidak dijaga. Jaga niatmu, Nak.",
        ],
        "reward": {"m": 11.5, "gems": 360, "items": {"potion_hp2": 10, "potion_mp2": 10}},
    },
    {
        "title": "Akar Dunia", "rec": 1000, "where": "Verdan Height (World 2, barat daya)",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Sampai juga kamu di Verdan Height, tempat pohon tumbuh setinggi gunung. Ingat akar hutan yang menyambung di bawah tanah?",
            "Akar-akar itu bermuara di sini: Worldroot, tempat seluruh dunia bersandar. Kabut Hampa paling pekat di sekitarnya.",
            "Kalahkan 16 Verdan Stag dan 8 Canopy Hunter, lalu hadapi Verdant Colossus, penjaga akarnya.",
        ],
        "visit": [14],
        "kill": {"verdan_stag": 16, "canopy_hunter": 8},
        "boss": {"colossus": 1},
        "done": [
            "Colossus itu roboh seperti gunung kecil. Tanahnya bergetar sampai jauh.",
            "Tapi dia bukan yang terakhir. Ada sesuatu bersembunyi di bawah akar itu, dan dialah yang menyebarkan kabut ke seluruh dunia.",
            "Siapkan dirimu sebaik mungkin. Ini pertarungan terakhir.",
        ],
        "reward": {"m": 12.5, "gems": 400, "items": {"potion_hp2": 10, "potion_mp2": 10}},
    },
    {
        "title": "Penelan Akar Dunia", "rec": 1200, "where": "Akar terdalam, Verdan Height",
        "giver": "elder", "turnin": "elder",
        "intro": [
            "Inilah sumbernya: Worldroot Devourer. Dialah yang memakan akar dunia dan meneteskan kabut ke setiap sudut.",
            "Dia bukan penjaga yang terluka seperti yang lain. Dia lapar, dan hanya itu yang dia tahu.",
            "Bawa semua yang kamu punya. Kalahkan dia, Nak, supaya Kabut Hampa tidak punya tempat bersandar lagi.",
        ],
        "visit": [14],
        "boss": {"devourer": 1},
        "done": [
            "Akar dunia mulai pulih. Kamu merasakannya? Seperti dunia menarik napas panjang.",
            "Kabut Hampa mungkin tidak hilang sepenuhnya, tapi dia tak punya rumah lagi. Itu sudah cukup.",
            "Semua Penjaga, dari Ent sampai Devourer, kini mengenalmu. Kamu bukan lagi pengembara. Kamu Pembawa Segel.",
        ],
        "reward": {"m": 16.0, "gems": 600, "items": {"potion_hp2": 12, "potion_mp2": 12}},
    },
]

const FINAL := [
    "Kamu menyelamatkan Greenwood, Nak, bahkan seluruh dunia ini. Dunia mungkin tidak akan pernah tahu, tapi aku tahu.",
    "Konon masih ada gua kristal yang bergema di dunia seberang, belum pernah ada yang menjelajahinya. Tapi itu kisah untuk hari lain.",
    "Kembalilah kapan saja kalau butuh teman bicara.",
]


# ------------------------------------------------------------------ keadaan
static func _s() -> Dictionary:
    if not Game.p.has("story") or typeof(Game.p["story"]) != TYPE_DICTIONARY:
        Game.p["story"] = {"ch": 0, "on": false, "n": false, "k": {}, "v": {}}
    return Game.p["story"]


static func chapter() -> int:
    return int(_s().get("ch", 0))


static func finished() -> bool:
    return chapter() >= CHAPTERS.size()


static func cur() -> Dictionary:
    return CHAPTERS[chapter()]


static func accepted() -> bool:
    return bool(_s().get("on", false))


static func giver() -> String:
    return String(cur()["giver"])


static func turnin() -> String:
    return String(cur()["turnin"])


static func npc_name(role: String) -> String:
    return String(NPC_NAMES.get(role, role))


static func boss_count(style: String) -> int:
    return int(Game.p.get("bosskills", {}).get(style, 0))


static func visited(b: int) -> bool:
    return int(_s().get("v", {}).get(str(b), 0)) > 0


# ------------------------------------------------------------------ progres
# Daftar tujuan bab sekarang: [{"label", "have", "need"}]
static func goals() -> Array:
    var out: Array = []
    if finished():
        return out
    var c: Dictionary = cur()
    var base: Dictionary = _s().get("k", {})
    for b in c.get("visit", []):
        out.append({"label": "Kunjungi %s" % String(BIOME_NAMES.get(int(b), "wilayah")), "have": 1 if visited(int(b)) else 0, "need": 1})
    for k in c.get("kill", {}).keys():
        var need: int = int(c["kill"][k])
        var have: int = clampi(Game.kill_count(k) - int(base.get(k, 0)), 0, need)
        out.append({"label": "Kalahkan %s" % String(NAMES.get(k, k)), "have": have, "need": need})
    for k in c.get("boss", {}).keys():
        var need: int = int(c["boss"][k])
        out.append({"label": "Kalahkan %s" % String(NAMES.get(k, k)), "have": mini(boss_count(k), need), "need": need})
    return out


static func is_complete() -> bool:
    if finished() or not accepted():
        return false
    for g in goals():
        if int(g["have"]) < int(g["need"]):
            return false
    return true


# Teks lengkap untuk dialog: "Kalahkan Slime 3/6, Kalahkan Lebah 4/4"
static func progress_text() -> String:
    var parts: Array = []
    for g in goals():
        parts.append("%s %d/%d" % [g["label"], int(g["have"]), int(g["need"])])
    if parts.is_empty():
        return "Temui %s" % npc_name(turnin())
    return ", ".join(parts)


# Teks singkat untuk pelacak HUD: hanya tujuan yang belum selesai (maks 2)
static func short_text() -> String:
    if is_complete():
        return "Selesai! Temui %s" % npc_name(turnin())
    var parts: Array = []
    for g in goals():
        if int(g["have"]) < int(g["need"]):
            if int(g["need"]) == 1:
                parts.append(String(g["label"]))
            else:
                parts.append("%s %d/%d" % [g["label"], int(g["have"]), int(g["need"])])
    if parts.is_empty():
        return "Temui %s" % npc_name(turnin())
    if parts.size() > 2:
        return "%s, %s +%d" % [parts[0], parts[1], parts.size() - 2]
    return ", ".join(parts)


# Penanda di atas kepala NPC: "!" = ada kisah baru, "?" = siap diselesaikan, "" = tidak ada
static func marker(role: String) -> String:
    if finished():
        return ""
    if not accepted():
        return "!" if giver() == role else ""
    if is_complete() and turnin() == role:
        return "?"
    return ""


# ------------------------------------------------------------------ aksi
static func accept() -> void:
    var s: Dictionary = _s()
    s["on"] = true
    s["n"] = false
    var base := {}
    for k in cur().get("kill", {}).keys():
        base[k] = Game.kill_count(k)
    s["k"] = base
    Game.save()


# Beri hadiah dan maju ke bab berikutnya. pl = node pemain
static func complete(pl) -> void:
    var c: Dictionary = cur()
    var r: Dictionary = c["reward"]
    var m: float = float(r.get("m", 1.0))
    var lv: int = int(Game.p["level"])
    Game.p["coins"] = int(Game.p["coins"]) + int((100.0 + float(lv) * 30.0) * m)
    Game.p["gems"] = int(Game.p["gems"]) + int(r.get("gems", 0))
    for it in r.get("items", {}).keys():
        pl.add_item(String(it), int(r["items"][it]))
    var s: Dictionary = _s()
    s["ch"] = chapter() + 1
    s["on"] = false
    s["n"] = false
    s["k"] = {}
    pl.give_xp(int(float(Bal.quest_xp(lv)) * m))
    Game.save()


# Teks hadiah untuk toast, mis. "Hadiah: 1450 koin, 20 gem, 3500 XP"
static func reward_text() -> String:
    var r: Dictionary = cur()["reward"]
    var m: float = float(r.get("m", 1.0))
    var lv: int = int(Game.p["level"])
    return "%d koin, %d gem, %d XP" % [int((100.0 + float(lv) * 30.0) * m), int(r.get("gems", 0)), int(float(Bal.quest_xp(lv)) * m)]


# Dipanggil setelah kill/boss/kunjungan: kalau tujuan baru saja selesai, beri tahu pemain (sekali saja)
static func check_notice() -> void:
    if finished() or not accepted():
        return
    var s: Dictionary = _s()
    if bool(s.get("n", false)) or not is_complete():
        return
    s["n"] = true
    var hud = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("hud")
    if hud:
        hud.toast("Kisah: tujuan selesai! Temui %s" % npc_name(turnin()))
        hud.show_banner("Kisah Utama: %s" % String(cur()["title"]), 3.0)


# Pemain memasuki biome b (dipanggil main.gd). Kunjungan pertama = penemuan wilayah baru.
static func visit(b: int) -> void:
    var v: Dictionary = _s().get("v", {})
    if v.has(str(b)):
        return
    v[str(b)] = 1
    _s()["v"] = v
    if BIOME_NAMES.has(b):
        var hud = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("hud")
        if hud:
            hud.show_banner("Wilayah baru ditemukan: %s" % String(BIOME_NAMES[b]), 3.0)
    check_notice()
    Game.save()


# Bos dikalahkan oleh pemain lokal (dipanggil boss.gd)
static func on_boss(style: String) -> void:
    Game.count_boss(style)
    check_notice()
