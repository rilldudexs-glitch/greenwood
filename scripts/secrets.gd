extends RefCounted
# Quest rahasia: NPC tersembunyi di desa dan gurun. Tiap NPC punya beberapa tahap berantai.
# "need"  = bahan yang diserahkan ke NPC
# "kill"  = {jenis_musuh: jumlah}, dihitung sejak tahap itu diterima
# Tahap terakhir membuka peti rahasia (lihat "chest") yang muncul di dunia.

const Journal = preload("res://scripts/journal.gd")
const Story = preload("res://scripts/story.gd")

# Saksi Akar (w1..w14): satu NPC rahasia per biome. Tiap kesaksian menjelaskan sebab-akibat Kabut Hampa
# dan menunjuk saksi berikutnya, berujung pada Aldric di Verdan Height sebelum bos terakhir.
const WITNESS := ["w1", "w2", "w3", "w4", "w5", "w6", "w7", "w8", "w9", "w10", "w11", "w12", "w13", "w14"]

const DATA := {
    "marni": {
        "name": "Nenek Marni",
        "stages": [
            {
                "intro": ["Eh, kamu lihat aku? Kebanyakan orang lewat saja.", "Nenek kehilangan resep sup warisan keluarga. Bahannya telur dan susu.", "Bawakan 3 Telur dan 2 Susu ya, Nak. Nenek tidak akan lupa jasamu."],
                "need": {"egg": 3, "milk": 2},
                "done": ["Harum sekali! Sup ini mengingatkanku pada masa muda.", "Ambil ini, tapi nenek belum selesai bercerita..."],
                "reward": {"coins": 90, "gems": 15, "xp": 40},
            },
            {
                "intro": ["Dulu suamiku menyimpan peti harta di sudut desa. Kuncinya berkarat dan hilang.", "Goblin-goblin itu suka mengumpulkan besi tua. Bawakan 4 Besi Karatan, nenek tempa kunci baru."],
                "need": {"scrap": 4},
                "done": ["Pas sekali! Kuncinya sudah jadi.", "Petinya ada di sudut timur laut desa, di balik pepohonan. Isinya untukmu."],
                "reward": {"coins": 150, "gems": 25, "xp": 80, "items": {"potion_hp2": 2}},
            },
        ],
        "final": ["Terima kasih, Nak. Desa ini beruntung punya pengembara sepertimu.", "Jaga dirimu di luar sana."],
        "chest": {"cell": Vector2i(72, 37), "hint": "Peti Marni muncul di sudut timur laut desa!"},
    },
    "sahar": {
        "name": "Kakek Sahar",
        "stages": [
            {
                "intro": ["Hm... jarang ada yang sampai ke oasis tersembunyi ini.", "Laba-laba gurun merusak jaring penjaga rahasiaku. Aku butuh benang baru.", "Bawakan 5 Benang Laba-laba. Kalau mereka menyerang, jangan diam saja."],
                "need": {"web": 5},
                "done": ["Benang yang bagus. Kamu cukup berani rupanya.", "Tapi ujian sebenarnya belum dimulai."],
                "reward": {"coins": 120, "gems": 20, "xp": 90},
            },
            {
                "intro": ["Pasir menyimpan peti kuno milik karavan terakhir. Penjaganya ogre-ogre gurun.", "Bawakan 2 Taring Ogre sebagai bukti kekuatanmu."],
                "need": {"tusk": 2},
                "done": ["Taring ogre! Kamu pantas mendapatkannya.", "Petinya tersembunyi di balik bukit pasir tenggara. Jangan lupa bawa ramuan."],
                "reward": {"coins": 250, "gems": 45, "xp": 200, "items": {"potion_hp2": 2, "potion_mp2": 2}},
            },
        ],
        "final": ["Pasir telah memilihmu. Pergilah, pengembara."],
        "chest": {"cell": Vector2i(116, 57), "hint": "Peti Sahar muncul di bukit pasir tenggara!"},
    },
    "zahra": {
        "name": "Zahra Penjelajah",
        "stages": [
            {
                "intro": ["Psst! Aku sedang mengintai goblin gurun. Mereka merampok karavan dagang.", "Kalahkan 6 Goblin dan aku akan membayarmu."],
                "kill": {"goblin": 6},
                "done": ["Enam goblin! Karavan bisa lewat lagi.", "Ini upahmu. Masih ada masalah lain..."],
                "reward": {"coins": 140, "gems": 20, "xp": 120},
            },
            {
                "intro": ["Sarang laba-laba bermunculan, dan ada ogre yang berkeliaran di sana.", "Kalahkan 6 Laba-laba dan 1 Ogre. Aku akan tunjukkan peti rahasiaku."],
                "kill": {"spider": 6, "ogre": 1},
                "done": ["Luar biasa! Kamu petarung sejati.", "Petiku ada di utara oasis. Ambil semuanya."],
                "reward": {"coins": 300, "gems": 60, "xp": 260, "items": {"potion_hp2": 3}},
            },
        ],
        "final": ["Sampai jumpa di petualangan berikutnya!"],
        "chest": {"cell": Vector2i(112, 30), "hint": "Peti Zahra muncul di utara oasis!"},
    },
    "w1": {
        "name": "Bibi Lumut", "biome": 1, "gender": "f", "trigger": {"t": "night"},
        "skin": [Color(0.30, 0.50, 0.30), Color(0.85, 0.90, 0.60), Color(0.30, 0.20, 0.10)],
        "stages": [
            {
                "intro": ["Ssst... jangan keras-keras. Kalau siang, pohon-pohon ikut mendengar, dan mereka sedang kesakitan.", "Lihat akar itu? Menghitam dari ujungnya, bukan dari tanahnya. Seperti ada yang menyedot dari tempat yang sangat jauh. Itu sebabnya Ent mengamuk: akarnya perih.", "Goblin menginjak akar muda itu tiap hari. Usir 8 Goblin dulu, nanti kuceritakan ke mana akar itu menunjuk."],
                "kill": {"goblin": 8},
                "done": ["Akar mudanya bernapas lagi. Dengar baik-baik: semua akar yang sakit menarik ke satu arah, barat daya, jauh melewati gerbang.", "Sakit di sini hanya akibat. Sebabnya ada di tempat lain. Cari Tamrin di Gurun Berdebu. Dia melihat air bumi pergi, tapi cuma berani keluar kalau kelabang-kelabang sudah kau tumpas."],
                "reward": {"coins": 290, "gems": 24, "xp": 110, "items": {"potion_hp2": 1, "potion_mp2": 1}},
            },
        ],
        "final": ["Akar menghitam dari ujung karena ada yang menyedot dari jauh. Hanya itu yang kutahu. Cari Tamrin di gurun."],
    },
    "w2": {
        "name": "Tamrin sang Pedagang", "biome": 2, "gender": "m", "trigger": {"t": "kills", "k": "centipede", "n": 6},
        "skin": [Color(0.85, 0.70, 0.40), Color(0.60, 0.30, 0.20), Color(0.30, 0.20, 0.10)],
        "stages": [
            {
                "intro": ["Kau melihatku? Bagus, berarti kelabang-kelabang itu sudah tak mengintai lagi.", "Karavanku selamat dari badai, bukan dari kehausan. Sumur-sumur oasis mengering satu demi satu sejak tiga musim lalu.", "Air bumi tersedot ke bawah, ke akar-akar yang kehausan. Bantu aku: 8 Mumi menjaga sumur terakhir."],
                "kill": {"mummy": 8},
                "done": ["Sumur terakhir aman. Lihat, air di dalamnya bergetar ke arah salju di utara, seperti ditarik.", "Akar kehausan, air pergi, panas bumi ikut hilang. Cari Ibu Salma di Puncak Salju. Dia tahu apa yang terjadi pada dingin. Dia baru mau keluar kalau Yeti sudah tenang."],
                "reward": {"coins": 380, "gems": 28, "xp": 160, "items": {"potion_hp2": 1, "potion_mp2": 1}},
            },
        ],
        "final": ["Air pergi karena akar kehausan. Cari Ibu Salma di Puncak Salju."],
    },
    "w3": {
        "name": "Ibu Salma", "biome": 3, "gender": "f", "trigger": {"t": "boss", "s": "yeti"},
        "skin": [Color(0.55, 0.75, 0.90), Color(0.95, 0.95, 1.00), Color(0.30, 0.30, 0.40)],
        "stages": [
            {
                "intro": ["Yeti itu bukan jahat. Dia lari dari dingin yang salah.", "Panas bumi tersedot ke akar, jadi es naik ke tempat yang seharusnya hangat. Yeti kehilangan gua hangatnya, lalu mengamuk.", "Serigala-serigala memburu yeti yang kebingungan. Singkirkan 10 Serigala."],
                "kill": {"wolf": 10},
                "done": ["Sekarang aku bisa mendengar yang di bawah es. Ada bisikan: 'lapar... lapar'. Itu suara akar, bukan suara monster.", "Penjaga di Gunung Api pernah menyebut siapa yang membuat segel pertama. Cari Ragil si pandai api. Dia hanya mau bicara pada malam bulan memerah."],
                "reward": {"coins": 470, "gems": 32, "xp": 210, "items": {"potion_hp2": 1, "potion_mp2": 1}},
            },
        ],
        "final": ["Dingin yang salah datang dari akar yang lapar. Cari Ragil di Gunung Api saat Bulan Darah."],
    },
    "w4": {
        "name": "Ragil si Pandai Api", "biome": 4, "gender": "m", "trigger": {"t": "blood"},
        "skin": [Color(0.70, 0.25, 0.15), Color(1.00, 0.60, 0.20), Color(0.20, 0.15, 0.10)],
        "stages": [
            {
                "intro": ["Bulan merah... pas. Api tungku hanya jujur pada malam begini.", "Para Penjaga bukan monster. Mereka ditanam. Penenun Akar dulu menempa segel di tiap penjuru untuk menahan lapar akar. Naga di kawah itu salah satunya.", "Segelnya retak karena akar kehilangan sesuatu. Bawakan aku 6 Golem sebagai bijih tempa, akan kutunjukkan arah retaknya."],
                "kill": {"golem": 6},
                "done": ["Retaknya mengarah ke tepi dunia. Dari sanalah kabut turun. Kabut itu bukan awan, itu napas lapar akar.", "Dan napasnya memakan yang tertulis: peta, bayangan, ingatan. Cari Lirih di Shadow Reach. Dia hidup di bayangan yang belum dimakan, tapi hanya percaya pada pembaca jurnal Aldric."],
                "reward": {"coins": 560, "gems": 36, "xp": 260, "items": {"potion_hp2": 2, "potion_mp2": 2}},
            },
        ],
        "final": ["Kabut itu napas lapar akar. Cari Lirih di Shadow Reach, bawa jurnal Aldric."],
    },
    "w5": {
        "name": "Lirih", "biome": 5, "gender": "f", "trigger": {"t": "journal", "j": "j5"},
        "skin": [Color(0.25, 0.20, 0.40), Color(0.70, 0.60, 0.90), Color(0.10, 0.10, 0.15)],
        "stages": [
            {
                "intro": ["Jurnal itu... Aldric. Dia dulu duduk di sini, di tempatmu berdiri.", "Di sini bayanganku diambil satu per satu. Kabut menelan hal-hal yang tercatat. Makin sering sesuatu disebut, makin dulu ia dimakan.", "Aldric menulis supaya dunia ingat, itu sebabnya kabut mengikuti jejaknya. Tolong kurangi 12 Umbral Slime yang menyedot bayangan."],
                "kill": {"umbral_slime": 12},
                "done": ["Terima kasih. Satu hal lagi: kabut tidak punya niat. Dia hanya lapar. Karena itu dia memakan apa pun yang paling dekat.", "Pergilah ke Undefined Land, tempat yang belum selesai ditulis. Ezra, penulis terakhir, ada di sana. Dia muncul setelah kau menaklukkan gua yang galat."],
                "reward": {"coins": 650, "gems": 40, "xp": 310, "items": {"potion_hp2": 2, "potion_mp2": 2}},
            },
        ],
        "final": ["Kabut tidak berniat jahat, dia hanya lapar. Cari Ezra di Undefined Land setelah menaklukkan gua galat."],
    },
    "w6": {
        "name": "Ezra sang Penulis", "biome": 6, "gender": "m", "trigger": {"t": "cave", "c": "galat"},
        "skin": [Color(0.50, 0.50, 0.55), Color(0.90, 0.90, 0.40), Color(0.15, 0.15, 0.20)],
        "stages": [
            {
                "intro": ["Gua galat itu retakan di mana kabut mencoba menulis ulang dunia. Kau selamat darinya, jadi kau pantas mendengar.", "Aku penulis kerajaan terakhir. Dulu kami mencatat tiap benih, tiap akar. Lalu kabut datang dan catatan terpenting lenyap: catatan tentang Benih Pertama.", "Hollow Wisp memakan tintaku. Singkirkan 12 dari mereka."],
                "kill": {"hollow_wisp": 12},
                "done": ["Satu halaman selamat, tintanya masih basah: 'Benih Pertama menopang semua akar. Siapa mencabutnya, mencabut dunia.'", "Berarti seseorang mencabutnya. Cari saksi di dasar laut, Nahkoda Rukh melihat denyutnya berhenti. Dia muncul kalau kau berhasil menembus palung."],
                "reward": {"coins": 740, "gems": 44, "xp": 360, "items": {"potion_hp2": 2, "potion_mp2": 2}},
            },
        ],
        "final": ["Benih Pertama menopang semua akar. Seseorang mencabutnya. Tanya Nahkoda Rukh di Abyssal Land."],
    },
    "w7": {
        "name": "Nahkoda Rukh", "biome": 7, "gender": "m", "trigger": {"t": "cave", "c": "palung"},
        "skin": [Color(0.15, 0.30, 0.45), Color(0.50, 0.85, 0.90), Color(0.10, 0.10, 0.15)],
        "stages": [
            {
                "intro": ["Kau turun ke palung dan kembali hidup. Duduklah.", "Dulu laut ini berdenyut tiap malam ketujuh, seperti jantung. Denyutnya datang dari bawah, dari akar yang menembus dasar. Sekarang denyutnya berhenti. Leviathan marah karena dia penjaganya.", "Deep Maw memakan jangkarku. Habisi 8 Deep Maw."],
                "kill": {"deep_maw": 8},
                "done": ["Denyutnya berhenti sejak benih dicabut, aku yakin. Sebelum itu, laut tenang.", "Siapa yang mencabutnya, hutan tua ingat. Sylvi di Enchanted Forest mengenang segalanya. Dia hanya bicara pada yang membersihkan ranting berduri."],
                "reward": {"coins": 830, "gems": 48, "xp": 410, "items": {"potion_hp2": 2, "potion_mp2": 2}},
            },
        ],
        "final": ["Denyut laut berhenti sejak benih dicabut. Tanya Sylvi di Enchanted Forest."],
    },
    "w8": {
        "name": "Sylvi si Peri Hutan", "biome": 8, "gender": "f", "trigger": {"t": "kills", "k": "thorn_sprite", "n": 10},
        "skin": [Color(0.35, 0.70, 0.40), Color(0.90, 0.95, 0.50), Color(0.20, 0.30, 0.15)],
        "stages": [
            {
                "intro": ["Hutan ini mengingat segalanya, bahkan yang ingin dilupakan.", "Aku ingat seorang raja datang tengah malam membawa pisau perak dan air mata. Dia mencabut sesuatu yang bercahaya dari akar terdalam, lalu pergi ke arah gerbang seberang.", "Beruang berlumut mengacak-acak kenanganku. Singkirkan 6 Mossback Bear."],
                "kill": {"mossback_bear": 6},
                "done": ["Aku tak sempat melihat wajahnya, tapi ingat mahkotanya: berkarat dari dalam. Dia bukan perampok, dia orang yang putus asa.", "Tanya Hanae di Sakura Valley. Kelopak yang tak mau gugur itu bagian dari kisahnya. Dia hanya muncul kalau kau membaca halaman Aldric di lembahnya."],
                "reward": {"coins": 920, "gems": 52, "xp": 460, "items": {"potion_hp2": 3, "potion_mp2": 3}},
            },
        ],
        "final": ["Seorang raja bermahkota berkarat mencabut benih itu. Tanya Hanae di Sakura Valley."],
    },
    "w9": {
        "name": "Hanae", "biome": 9, "gender": "f", "trigger": {"t": "journal", "j": "j9"},
        "skin": [Color(0.95, 0.70, 0.80), Color(1.00, 0.95, 0.95), Color(0.30, 0.20, 0.20)],
        "stages": [
            {
                "intro": ["Kelopak tak jatuh karena waktu di lembah ini macet. Pohon sakura adalah anak dari pohon benih. Begitu induknya dicabut, kami berhenti bergerak dan menunggu.", "Sang Permaisuri tidak berniat jahat. Dia menahan kelopak terakhir supaya ingatan tentang benih tak hilang.", "Petal Fox mencuri kelopak itu satu per satu. Tangkap 14 Petal Fox."],
                "kill": {"petal_fox": 14},
                "done": ["Sang raja mengambil benih bukan karena serakah, tapi untuk menyelamatkan sesuatu. Kau akan mengerti sebentar lagi.", "Jamur memakan yang membusuk, jadi jamur tahu apa yang membusuk di kerajaan itu. Cari Morel di Mushroom Kingdom. Dia hanya mau bicara saat hari gelap."],
                "reward": {"coins": 1010, "gems": 56, "xp": 510, "items": {"potion_hp2": 3, "potion_mp2": 3}},
            },
        ],
        "final": ["Raja itu mengambil benih untuk menyelamatkan sesuatu. Cari Morel di Mushroom Kingdom saat malam."],
    },
    "w10": {
        "name": "Morel si Tabib Jamur", "biome": 10, "gender": "m", "trigger": {"t": "night"},
        "skin": [Color(0.70, 0.35, 0.30), Color(0.95, 0.85, 0.60), Color(0.30, 0.20, 0.15)],
        "stages": [
            {
                "intro": ["Malam: waktu terbaik bicara jujur. Jamur memakan yang mati, dan aku ingat apa yang mati di kerajaan seberang: ribuan rakyat, terserang Wabah Layu.", "Raja mereka putus asa dan mengira benih bercahaya bisa menyembuhkan. Dia benar, wabah mereda. Tapi sembuhnya hanya sehari, dan seluruh akar dunia yang menanggung harganya.", "Sporeling menyebar sampai ke ruang praktikku. Habisi 14 Sporeling."],
                "kill": {"sporeling": 14},
                "done": ["Kerajaan itu ada di seberang gerbang. Tapi sebelum ke sana, dengarkan langit di World 2.", "Akar yang kehilangan benih mencari makanan ke atas. Kirana si peramal awan di Ethergrooves mencatatnya. Dia muncul setelah menara awannya kau taklukkan."],
                "reward": {"coins": 1100, "gems": 60, "xp": 560, "items": {"potion_hp2": 3, "potion_mp2": 3}},
            },
        ],
        "final": ["Wabah Layu membuat raja mencabut benih. Cari Kirana di Ethergrooves, World 2."],
    },
    "w11": {
        "name": "Kirana si Peramal Awan", "biome": 11, "gender": "f", "trigger": {"t": "cave", "c": "aether"},
        "skin": [Color(0.50, 0.60, 0.95), Color(0.95, 0.95, 1.00), Color(0.20, 0.20, 0.40)],
        "stages": [
            {
                "intro": ["Kau menaklukkan menara awan itu. Berarti kau cukup kuat untuk mendengar.", "Akar yang kehilangan benih menjulur mencari makan sampai menyentuh langit. Itu sebabnya langit retak, cuaca kacau, dan naga awan gelisah.", "Ether Drake mengacaukan arah anginku. Singkirkan 14 Ether Drake."],
                "kill": {"ether_drake": 14},
                "done": ["Dari awan kulihat rajanya pulang membawa benih itu. Tapi wabah kembali, dan benih itu lenyap dari istana.", "Tanya ksatria tuanya, Sir Alden di Forgotten Kingdom. Dia baru mau bicara setelah rajanya tumbang."],
                "reward": {"coins": 1190, "gems": 64, "xp": 610, "items": {"potion_hp2": 3, "potion_mp2": 3}},
            },
        ],
        "final": ["Raja membawa benih pulang, lalu benih itu lenyap. Tanya Sir Alden di Forgotten Kingdom."],
    },
    "w12": {
        "name": "Sir Alden", "biome": 12, "gender": "m", "trigger": {"t": "boss", "s": "monarch"},
        "skin": [Color(0.50, 0.50, 0.60), Color(0.85, 0.80, 0.50), Color(0.20, 0.20, 0.25)],
        "stages": [
            {
                "intro": ["Rajaku sudah tenang... terima kasih, pengembara. Duduklah. Akan kuceritakan apa yang tidak ditulis sejarah.", "Wabah Layu membunuh putri raja. Dia mencabut Benih Pertama dari akar dunia, menanamnya di tahta, dan wabah mereda sehari. Esoknya benih itu retak, kerajaan kami lenyap dari ingatan dunia.", "Penjaga tahta kosong belum berhenti berjaga. Habisi 14 Ruins Sentinel supaya mereka beristirahat."],
                "kill": {"ruins_sentinel": 14},
                "done": ["Begitulah semuanya bermula: benih dicabut, akar kelaparan, segel retak, Penjaga mengamuk, kabut menyebar.", "Benih yang retak diseret arus ke laut. Kini dia di Lumins Reef, dijaga Lumina. Mira si penyelam melihatnya. Dia akan muncul kalau kau menjelajahi gua karang di sana."],
                "reward": {"coins": 1280, "gems": 68, "xp": 660, "items": {"potion_hp2": 4, "potion_mp2": 4}},
            },
        ],
        "final": ["Benih dicabut, akar lapar, segel retak, Penjaga mengamuk, kabut menyebar. Benihnya ada di Lumins Reef."],
    },
    "w13": {
        "name": "Mira si Penyelam", "biome": 13, "gender": "f", "trigger": {"t": "cave", "c": "karang"},
        "skin": [Color(0.20, 0.60, 0.70), Color(0.95, 0.85, 0.50), Color(0.15, 0.20, 0.30)],
        "stages": [
            {
                "intro": ["Kau sampai ke gua karang. Berarti kau layak melihat ini.", "Benih itu retak tapi hidup. Dia berkedip di kedalaman, memanggil akar yang memanggilnya balik. Lumina menjaganya supaya tak jatuh ke tangan yang lapar. Tapi ada yang lebih lapar dari siapa pun, di akar terdalam.", "Pearl Wisp memadamkan cahayanya. Singkirkan 8 Pearl Wisp."],
                "kill": {"pearl_wisp": 8},
                "done": ["Bawa pecahan cahayanya ini ke Verdan Height, tempat semua akar bertemu. Cahaya benih akan melukai yang kelaparan di sana.", "Dan di sana orang yang paling lama mengejar kabut menunggumu. Dia akan muncul setelah kau mendengar semua kesaksian."],
                "reward": {"coins": 1370, "gems": 72, "xp": 710, "items": {"potion_hp2": 4, "potion_mp2": 4}},
            },
        ],
        "final": ["Bawa pecahan benih ke Verdan Height. Orang yang paling lama mengejar kabut menunggumu di sana."],
    },
    "w14": {
        "name": "Aldric Voss", "biome": 14, "gender": "m", "trigger": {"t": "truth"},
        "skin": [Color(0.35, 0.30, 0.25), Color(0.90, 0.80, 0.40), Color(0.90, 0.90, 0.90)],
        "stages": [
            {
                "intro": ["Kau membaca jurnalku di tiap tugu, dan mengumpulkan kesaksian semua orang. Tak ada yang pernah sampai sejauh ini.", "Aku Aldric. Aku mengejar kabut karena darahku adalah darah Raja yang Dilupakan. Tanganku yang seharusnya menanggung dosa benih itu. Tugu cahaya kutancapkan supaya benih itu punya jalan pulang.", "Inilah rangkaiannya: benih dicabut, akar kelaparan, segel retak, Penjaga mengamuk, kabut menyebar. Dan dari lapar yang tak tertahan lahirlah Worldroot Devourer. Dia bukan jahat, dia akar yang lapar.", "Bersihkan jalan ke akar terdalam: 8 Canopy Hunter."],
                "kill": {"canopy_hunter": 8},
                "done": ["Segel Akar kuberikan padamu. Cahaya benih melukai Penelan lebih dalam: seranganmu terhadapnya jadi lebih tajam.", "Pergilah ke akar terdalam. Bukan untuk menghancurkan, tapi untuk mengakhiri lapar itu. Kalau kau menang, akar bisa menumbuhkan benih yang baru."],
                "reward": {"coins": 1460, "gems": 76, "xp": 760, "items": {"potion_hp2": 4, "potion_mp2": 4}},
            },
        ],
        "final": ["Pergilah ke akar terdalam, Pembawa Segel. Akhiri lapar itu."],
        "epilog": ["Kabut menghilang... kau merasakannya? Akar mulai menumbuhkan benih baru, hijau dan sangat kecil.","Terima kasih, Pembawa Segel. Aku bisa pulang sekarang, dan jurnalku akhirnya bisa kututup."],
    },
}

# Balasan pemain (dirangkai: N0, P0, N1, P1, N2 ...). Jumlah balasan = jumlah baris NPC - 1.
const PL := {
    "w1": {"intro": ["Pohon-pohon... ikut mendengar?", "Baik, kuusir goblinnya."], "done": ["Barat daya. Aku akan mencari Tamrin."]},
    "w2": {"intro": ["Sumur mengering? Kenapa bisa begitu?", "Oke, mumi itu biar kuurus."], "done": ["Ke arah salju. Mengerti, kuikuti."]},
    "w3": {"intro": ["Jadi Yeti tadi cuma kehilangan rumahnya...", "Serigala-serigala itu kubereskan."], "done": ["Bisikan 'lapar'... Aku akan cari Ragil."]},
    "w4": {"intro": ["Penjaga itu ditanam? Bukan monster?", "Golem ya. Tunggu di sini."], "done": ["Napas lapar akar... Aku ke Shadow Reach."]},
    "w5": {"intro": ["Aku membaca jurnal Aldric. Bayanganmu diambil kabut?", "Slime-nya kukurangi, tenang saja."], "done": ["Kabut cuma lapar, bukan jahat... Aku ke Undefined Land."]},
    "w6": {"intro": ["Benih Pertama? Apa itu?", "Wisp-wisp itu akan kusingkirkan."], "done": ["Berarti ada yang mencabutnya. Aku cari Nahkoda Rukh."]},
    "w7": {"intro": ["Denyut laut berhenti sejak kapan?", "Deep Maw, siap. Kuhabisi."], "done": ["Jadi hutan tua menyimpan jawabannya. Ke Sylvi."]},
    "w8": {"intro": ["Seorang raja? Membawa pisau perak?", "Beruangnya kuusir dulu."], "done": ["Dia orang putus asa, bukan perampok... Kutemui Hanae."]},
    "w9": {"intro": ["Jadi sakura-sakura ini anak pohon benih...", "Rubah kelopak, kutangkap semuanya."], "done": ["Raja itu mau menyelamatkan sesuatu. Sekarang aku ke Morel."]},
    "w10": {"intro": ["Wabah Layu... pantas kerajaan itu lenyap.", "Sporeling ya. Kubereskan."], "done": ["Akar mencari makan ke atas. Aku ke Ethergrooves."]},
    "w11": {"intro": ["Jadi langit retak karena akar kelaparan?", "Ether Drake, kuhabisi."], "done": ["Benihnya lenyap dari istana... Kucari Sir Alden."]},
    "w12": {"intro": ["Sang raja... putrinya sendiri yang jadi alasannya?", "Para Sentinel biar beristirahat. Kuurus."], "done": ["Jadi itu rangkaian sebab-akibatnya. Aku ke Lumins Reef."]},
    "w13": {"intro": ["Benih itu masih hidup? Di sini?", "Pearl Wisp, siap kuusir."], "done": ["Pecahan cahaya ini akan kubawa ke Verdan Height."]},
    "w14": {"intro": ["Kau keturunan Raja yang Dilupakan...", "Jadi Devourer itu cuma akar yang lapar.", "Baik. Kubersihkan jalannya."], "done": ["Aku akan mengakhiri laparnya, bukan menghancurkannya."]},
}


static func weave(lines: Array, pl: Array) -> Array:
    var out: Array = []
    for i in lines.size():
        out.append(lines[i])
        if i < lines.size() - 1 and i < pl.size():
            out.append("@p:" + String(pl[i]))
    return out

const NAMES := {"egg": "Telur", "milk": "Susu", "scrap": "Besi Karatan", "web": "Benang Laba-laba", "tusk": "Taring Ogre", "goblin": "Goblin", "spider": "Laba-laba", "ogre": "Ogre"}


static func stage(id: String) -> int:
    return int(Game.p["secrets"].get(id, 0))


static func finished(id: String) -> bool:
    return stage(id) >= DATA[id]["stages"].size()


static func accepted(id: String) -> bool:
    return bool(Game.p["secrets"].get(id + "_on", false))


# Teks kebutuhan tahap saat ini, mis. "3x Telur, 2x Susu" (dengan kemajuan)
static func progress_text(id: String, pl) -> String:
    var s: Dictionary = DATA[id]["stages"][stage(id)]
    var parts: Array = []
    for k in s.get("need", {}).keys():
        parts.append("%s %d/%d" % [NAMES.get(k, Story.NAMES.get(k, k)), mini(pl.count(k), int(s["need"][k])), int(s["need"][k])])
    var base: Dictionary = Game.p["secrets"].get(id + "_k", {})
    for k in s.get("kill", {}).keys():
        var have: int = Game.kill_count(k) - int(base.get(k, 0))
        parts.append("Kalahkan %s %d/%d" % [NAMES.get(k, Story.NAMES.get(k, k)), clampi(have, 0, int(s["kill"][k])), int(s["kill"][k])])
    return ", ".join(parts)


static func is_complete(id: String, pl) -> bool:
    var s: Dictionary = DATA[id]["stages"][stage(id)]
    for k in s.get("need", {}).keys():
        if pl.count(k) < int(s["need"][k]):
            return false
    var base: Dictionary = Game.p["secrets"].get(id + "_k", {})
    for k in s.get("kill", {}).keys():
        if Game.kill_count(k) - int(base.get(k, 0)) < int(s["kill"][k]):
            return false
    return true


static func accept(id: String) -> void:
    var sec: Dictionary = Game.p["secrets"]
    sec[id + "_on"] = true
    var base := {}
    for k in DATA[id]["stages"][stage(id)].get("kill", {}).keys():
        base[k] = Game.kill_count(k)
    sec[id + "_k"] = base
    Game.save()


# Serahkan bahan, beri hadiah, maju ke tahap berikutnya
static func complete(id: String, pl) -> void:
    var s: Dictionary = DATA[id]["stages"][stage(id)]
    for k in s.get("need", {}).keys():
        pl.remove_item(k, int(s["need"][k]))
    var r: Dictionary = s["reward"]
    Game.p["coins"] = int(Game.p["coins"]) + int(r.get("coins", 0))
    Game.p["gems"] = int(Game.p["gems"]) + int(r.get("gems", 0))
    for it in r.get("items", {}).keys():
        pl.add_item(it, int(r["items"][it]))
    var sec: Dictionary = Game.p["secrets"]
    sec[id] = stage(id) + 1
    sec[id + "_on"] = false
    sec.erase(id + "_k")
    pl.give_xp(int(r.get("xp", 0)))
    Game.save()


# ------------------------------------------------------------------ Saksi Akar
static func is_witness(id: String) -> bool:
    return WITNESS.has(id)


# Jumlah kesaksian (w1..w13) yang sudah diselesaikan
static func truth_count() -> int:
    var n := 0
    for i in 13:
        if finished(WITNESS[i]):
            n += 1
    return n


# Segel Akar (hadiah Aldric): serangan ke Worldroot Devourer lebih tajam
static func has_seal() -> bool:
    return Game.p.has("secrets") and finished("w14")


# Syarat NPC rahasia muncul (dicek saat pemain mendekat). 'main' = adegan utama.
static func trigger_ok(id: String, main) -> bool:
    var t: Dictionary = DATA[id].get("trigger", {})
    match String(t.get("t", "")):
        "night":
            return main != null and main.atmos != null and main.atmos.is_night()
        "kills":
            return Game.kill_count(String(t["k"])) >= int(t["n"])
        "boss":
            return int(Game.p.get("bosskills", {}).get(String(t["s"]), 0)) >= 1
        "blood":
            return main != null and bool(main.blood_moon)
        "journal":
            return Journal.found(String(t["j"]))
        "cave":
            return int(Game.p.get("dungeons", {}).get(String(t["c"]), 0)) > 0
        "truth":
            return truth_count() >= 13
    return true
