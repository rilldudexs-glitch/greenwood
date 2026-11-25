extends RefCounted
# Dialog & adegan pembuka bos dunia terbuka (dipakai boss.gd).
#   intro  = dialog sebelum bertarung (sekali, saat pertama bertemu; tersimpan di Game.p["bseen"])
#   phase2 = satu kalimat pendek saat HP bos tinggal separuh (tampil sebagai banner, tidak menjeda game)
#   last   = kata-kata terakhir setelah bos kalah
#   again  = sindiran singkat setiap bertemu lagi (sesudah intro pernah dilihat)
# Kunci = style bos (lihat boss.gd). Mau ubah dialog? Cukup edit teks di tabel ini.

const DATA := {
    "ent": {
        "intro": [
            "Akar... sakit... Ada yang merobek akarku dari bawah tanah.",
            "Aku berjanji menjaga hutan ini. Tapi rasa sakit ini menutupi semua janji.",
            "Pergilah, kecil. Sebelum aku lupa bahwa kau bukan musuhku.",
        ],
        "phase2": "Ranting-rantingku tak mau patuh!",
        "last": [
            "Ah... sakitnya mereda. Akar-akarku bisa bernapas lagi.",
            "Terima kasih, pengembara. Jaga hutan ini untukku.",
        ],
        "again": "Kau kembali, kecil. Semoga kali ini aku sempat mengenalimu.",
    },
    "scorpion": {
        "intro": [
            "Berhenti. Siapa pun yang melintasi pasir ini harus membayar sesuatu.",
            "Dulu aku menjaga mata air, bukan mengusir orang. Racun ini kutukar dengan umurku sendiri.",
            "Sekarang kabut berbisik bahwa semua yang mendekat ingin mencurinya. Maafkan aku, aku tak bisa berhenti.",
        ],
        "phase2": "Capitku bergerak sendiri!",
        "last": [
            "Mata airnya... aku bisa mendengarnya lagi. Gemericik yang dulu.",
            "Jaga oasis itu, pengembara. Hanya itu pintaku.",
        ],
        "again": "Pasir ini masih milikku. Tapi kali ini aku coba menahan diri.",
    },
    "yeti": {
        "intro": [
            "Dingin... dingin sekali. Pergi, jangan mendekat.",
            "Ada suara di kepalaku yang menyuruhku membekukan segalanya. Aku tak mau, tapi tubuhku menurut.",
            "Kalau kau memang kuat... hentikan aku.",
        ],
        "phase2": "Tolong... aku tak bisa berhenti!",
        "last": [
            "Hangat... Apakah begini rasanya salju yang tenang?",
            "Terima kasih telah menghentikanku.",
        ],
        "again": "Kau kembali... tolong, kali ini cepatlah.",
    },
    "dragon": {
        "intro": [
            "Akhirnya datang juga Pembawa Segel. Aku yang pertama merasakan retakan itu, seratus tahun lalu.",
            "Panasnya merayap ke dalam jiwaku. Aku melawan, tapi api tak pernah tahu cara menyerah.",
            "Maka buktikan bahwa segel itu pantas ditempa ulang. Bakar semua keraguanku!",
        ],
        "phase2": "Api sejati baru saja dimulai!",
        "last": [
            "Panas ini akhirnya padam. Aku bisa tidur.",
            "Empat telah tenang. Waspadalah pada yang tak berbentuk di tepi dunia.",
        ],
        "again": "Kau lagi? Bagus. Aku suka lawan yang tak jera.",
    },
    "warden": {
        "intro": [
            "Berhenti. Tak seorang pun boleh melewati pintu bayangan ini.",
            "Aku mendengar langkahmu, dan setiap langkah terdengar seperti perburuan.",
            "Kalau kau bukan ancaman, buktikan. Kalau kau ancaman, aku akan bertindak.",
        ],
        "phase2": "Bayangan! Berdirilah bersamaku!",
        "last": [
            "Aku ingat sekarang. Aku menjaga, bukan memburu.",
            "Maafkan aku, pengembara. Bayanganku akhirnya terasa ringan.",
        ],
        "again": "Pintu ini masih kujaga. Kali ini aku akan mendengar lebih baik.",
    },
    "unwritten": {
        "intro": [
            "Siapa aku? Serigala? Burung? Menara? Tolong, katakan aku ini apa.",
            "Setiap bentuk yang kucoba terasa salah. Kabut bilang tak ada yang cukup baik.",
            "Kau punya nama dan bentuk. Beri aku salah satunya, atau biarkan aku merebutnya.",
        ],
        "phase2": "Bentukku terus pecah!",
        "last": [
            "Aku punya bentuk? Aku bisa merasakan tepiku sendiri.",
            "Terima kasih. Aku akan mencari namaku sendiri.",
        ],
        "again": "Kau kembali. Apakah aku sudah punya nama?",
    },
    "leviathan": {
        "intro": [
            "Lama sekali... tak ada yang turun ke sini.",
            "Dulu para pelaut melempar bunga. Kini hanya gelap, dan suara yang bilang aku sudah dilupakan.",
            "Kalau kau datang untuk menyakitiku, lakukan cepat. Kalau tidak, jangan pergi dulu.",
        ],
        "phase2": "Jangan tinggalkan aku sendiri lagi!",
        "last": [
            "Kau menemukan bunga di dasar air itu, ya? Jadi masih ada yang ingat.",
            "Terima kasih telah turun. Airnya terasa hangat sekarang.",
        ],
        "again": "Kau turun lagi? Kalau begitu, tinggallah sebentar.",
    },
    "verdant": {
        "intro": [
            "Aku ingat semua yang pernah berjalan di bawah dahanku. Semuanya sekaligus, dan semuanya terasa baru.",
            "Kemarin dan hari ini kusut jadi satu. Kau kawan, atau seseorang yang pernah menyakitiku?",
            "Maafkan aku bila salah mengenali. Genggam senjatamu erat-erat.",
        ],
        "phase2": "Ingatan ini menusuk akarku!",
        "last": [
            "Simpulnya terurai satu per satu. Aku bisa memilah lagi mana yang sudah lewat.",
            "Sampaikan salamku pada Ent di Hutan Greenwood. Dia pasti bangga padamu.",
        ],
        "again": "Kali ini aku mengingatmu. Itu sudah lebih baik dari sebelumnya.",
    },
    "sakura": {
        "intro": [
            "Jangan sentuh pohon itu. Selama kelopaknya belum jatuh, janjiku masih hidup.",
            "Dia berjanji pulang sebelum musim berganti. Maka kutahan musim itu selama diperlukan.",
            "Kalau kau datang untuk menjatuhkan kelopaknya, langkahi aku dulu.",
        ],
        "phase2": "Kelopakku, jangan jatuh dulu!",
        "last": [
            "Jadi dia memintaku hidup... sejak dulu.",
            "Kelopaknya jatuh, dan ternyata tak sesakit yang kutakutkan. Terima kasih.",
        ],
        "again": "Pohon itu masih berbunga. Jangan ganggu, kumohon.",
    },
    "myconid": {
        "intro": [
            "Selamat datang, tamu! Tak perlu terburu-buru. Duduklah, minum teh jamur, nikmati mimpinya.",
            "Di sini tak ada yang menua, tak ada yang berpulang. Mengapa kau mau terbangun?",
            "Sayang sekali. Tamu yang tak mau tidur harus ditidurkan.",
        ],
        "phase2": "Mimpi ini tak boleh berakhir!",
        "last": [
            "Dingin... jadi begini rasanya terbangun. Dunia nyata lebih berat, ya?",
            "Tapi lebih berharga. Terima kasih sudah membangunkan kami.",
        ],
        "again": "Teh jamurnya masih hangat. Yakin tak mau mampir?",
    },
    "ether": {
        "intro": [
            "Diam! Jangan guncang langit ini. Satu retakan lagi dan semuanya runtuh.",
            "Tiap malam kuhitung bintang satu per satu. Pernah satu padam, dan itu tak akan terulang.",
            "Siapa pun yang menantangku mengancam atap dunia. Kau tak akan melewati langitku!",
        ],
        "phase2": "Bintang-bintang! Jangan jatuh!",
        "last": [
            "Langit masih di atas sana. Ia bertahan tanpa kugenggam.",
            "Rupanya aku boleh beristirahat. Terima kasih, Pembawa Segel.",
        ],
        "again": "Langit ini rapuh. Kalau mau lewat, pelan-pelan.",
    },
    "monarch": {
        "intro": [
            "Siapa yang berani masuk ke aula ini? Berlutut, atau sebutkan namamu!",
            "Aku raja kerajaan ini... dulu. Ukiran namaku sudah hilang dari gerbang. Katakan, kau tahu siapa aku?",
            "Kau tak tahu juga. Tak seorang pun tahu. Maka biar kau ingat aku lewat pertarungan ini!",
        ],
        "phase2": "Ingat aku! Ingatlah namaku!",
        "last": [
            "Kau akan mengingatnya, bukan? Hanya itu yang kuminta.",
            "Terima kasih. Sekarang aku boleh tidur.",
        ],
        "again": "Katakan padaku, kau masih mengingatku?",
    },
    "lumina": {
        "intro": [
            "Cahayaku melindungi semua pelaut. Jangan dipadamkan! Kabut akan datang kalau terang berkurang!",
            "Tiap senja kupanggil pasang, dan tiap senja kabut mendekat lebih rapat.",
            "Maka aku harus lebih terang. Lebih terang lagi! Untuk memadamkanku, lewati dulu gelombangku.",
        ],
        "phase2": "Lebih terang! Lebih terang lagi!",
        "last": [
            "Redup... ternyata menenangkan. Aku tak sadar betapa lelahnya aku.",
            "Biarkan terumbu beristirahat. Terima kasih, penolongku.",
        ],
        "again": "Cahayaku tetap menyala. Tapi mungkin boleh sedikit redup.",
    },
    "colossus": {
        "intro": [
            "Berhenti. Di bawah kakiku ada Worldroot, dan sesuatu sedang menggerogotinya.",
            "Aku tumbuh untuk menjaga akar ini. Aku tak boleh mundur, meski tubuhku sendiri dikerat kabut.",
            "Melangkah lebih jauh, dan kau harus melewatiku dulu, pengembara.",
        ],
        "phase2": "Akar ini tak akan kuserahkan!",
        "last": [
            "Akarnya masih berdenyut. Pergilah, hentikan yang lapar itu.",
            "Dia ada di bawah. Hati-hati, Pembawa Segel.",
        ],
        "again": "Aku masih menjaga akar ini. Turunlah kalau kau memang berani.",
    },
    "devourer": {
        "intro": [
            "......lapar.",
            "Akar... enak. Dunia... enak. Semua... mau kumakan.",
            "Kau... kecil. Tapi segelmu... berbau enak sekali.",
        ],
        "phase2": "LAPAR... LAPAR!",
        "last": [
            "Lapar... berhenti...",
            "Akhirnya... diam.",
        ],
        "again": "...lapar. Kau... lagi.",
    },
}


static func has_intro(style: String) -> bool:
    return DATA.has(style)


static func intro(style: String) -> Array:
    return DATA.get(style, {}).get("intro", [])


static func phase2(style: String) -> String:
    return String(DATA.get(style, {}).get("phase2", ""))


static func last_words(style: String) -> Array:
    return DATA.get(style, {}).get("last", [])


static func again(style: String) -> String:
    return String(DATA.get(style, {}).get("again", ""))
