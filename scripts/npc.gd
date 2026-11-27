extends Node2D
# NPC desa: tokoh penting (tetua, pedagang, pandai besi, tabib, gacha, nelayan, penambang,
# penebang), warga dengan percakapan acak, dan NPC rahasia (marni, sahar, zahra) dengan quest
# berantai. Semua NPC berdiri diam di tempatnya (hanya menoleh ke pemain).

const Art = preload("res://scripts/art.gd")
const Secrets = preload("res://scripts/secrets.gd")
const Story = preload("res://scripts/story.gd")
const Jobs = preload("res://scripts/jobs.gd")
const Plot = preload("res://scripts/plot.gd")
const Sidequests = preload("res://scripts/sidequests.gd")
const Lore = preload("res://scripts/lore.gd")

const NAMES := ["Budi", "Siti", "Joko", "Ayu", "Dewi", "Agus", "Rina", "Tono", "Wati", "Eko", "Lina", "Bayu", "Mira", "Rudi", "Sari", "Dani", "Putri", "Hendra", "Nina", "Galih", "Ratna", "Fajar", "Intan", "Wahyu", "Citra", "Bagas", "Yuni", "Arif", "Lestari", "Dimas", "Mega", "Raka", "Tari", "Surya", "Laras", "Gilang", "Maya", "Ilham", "Ratih", "Yoga", "Kirana", "Bima", "Sekar", "Teguh", "Anjani", "Pandu", "Wulan", "Satria", "Dian", "Reza", "Nia", "Okta", "Tika", "Herman", "Lilis", "Cahyo", "Rani", "Jaka", "Endang", "Slamet"]
static var _used_names: Array = []

# Pedagang kastil: satu per biome, berdiri di gerbang kastil. Dagangan, nama, dan harga jual beda tiap biome.
const BMER := {
    1: {"name": "Pak Rimbun", "g": "m", "skin": [Color(0.3, 0.5, 0.3), Color(0.9, 0.8, 0.5), Color(0.3, 0.2, 0.1)], "title": "Dagangan Rimba",
        "lines": ["Salam, pengelana! Aku menjaga gerbang kastil hutan ini sejak akarnya mulai menghitam.", "Madu, kulit, dan besi pilihan. Semua dari hutan sendiri."],
        "stock": ["potion_hp", "potion_hp2", "omelet", "honey", "leather", "iron", "log", "bi_1_a", "bi_1_c"]},
    2: {"name": "Syekh Tamar", "g": "m", "skin": [Color(0.85, 0.7, 0.4), Color(0.2, 0.55, 0.6), Color(0.3, 0.2, 0.1)], "title": "Pasar Gurun",
        "lines": ["Air lebih berharga dari emas di sini, sahabatku. Tapi aku menjual keduanya.", "Amber, pecahan matahari, ikan oasis. Barang asli gurun."],
        "stock": ["potion_hp", "potion_mp", "steak", "amber", "sunshard", "fish_sand", "gold", "bi_2_a", "bi_2_c"]},
    3: {"name": "Nyonya Beku", "g": "f", "skin": [Color(0.6, 0.78, 0.92), Color(0.95, 0.97, 1.0), Color(0.3, 0.3, 0.4)], "title": "Lapak Salju",
        "lines": ["Brr! Mendekatlah ke gerbang, di sini sedikit lebih hangat.", "Serpihan es, bulu beku, dan ikan beku. Segar sepanjang tahun!"],
        "stock": ["potion_hp2", "potion_mp2", "grilled", "shard", "frost", "fish_ice", "crystal", "bi_3_a", "bi_3_c"]},
    4: {"name": "Si Bara", "g": "m", "skin": [Color(0.7, 0.25, 0.15), Color(1.0, 0.65, 0.2), Color(0.2, 0.15, 0.1)], "title": "Bengkel Bara",
        "lines": ["Panas? Biasa saja. Aku berdagang di kaki kawah sejak sebelum kau lahir.", "Bara, obsidian, rubi, dan jantung lava. Hati-hati, masih hangat."],
        "stock": ["potion_hp2", "steak", "coal", "obsidian", "ruby", "fish_lava", "heart", "bi_4_a", "bi_4_c"]},
    5: {"name": "Remang si Kelabu", "g": "m", "skin": [Color(0.25, 0.2, 0.4), Color(0.7, 0.6, 0.9), Color(0.1, 0.1, 0.15)], "title": "Lapak Bayangan",
        "lines": ["Sst. Jangan terlalu terang di sini, bayangan tak suka.", "Bisa ular, taring, tanduk. Barang yang dicari orang yang tak mau ditanya."],
        "stock": ["potion_mp2", "potion_hp2", "venom", "web", "fang", "horn", "bi_5_a", "bi_5_c"]},
    6: {"name": "Pak Galat", "g": "m", "skin": [Color(0.3, 0.6, 0.7), Color(0.9, 0.3, 0.8), Color(0.15, 0.15, 0.2)], "title": "Toko Galat",
        "lines": ["Selamat datang di toko... toko... toko. Maaf, tempat ini suka mengulang.", "Harga bisa berubah, tapi barangnya asli. Kurasa."],
        "stock": ["potion_mp", "potion_mp2", "scrap", "iron", "gold", "bi_6_a", "bi_6_c"]},
    7: {"name": "Juragan Palung", "g": "m", "skin": [Color(0.15, 0.35, 0.5), Color(0.5, 0.85, 0.9), Color(0.1, 0.1, 0.15)], "title": "Dermaga Palung",
        "lines": ["Kapal terakhirku kandas, tapi daganganku selamat.", "Ikan emas, bisa laut, permata dasar palung. Tawar-menawar boleh."],
        "stock": ["potion_hp2", "grilled", "fish_gold", "fish_ice", "venom", "gem", "bi_7_a", "bi_7_c"]},
    8: {"name": "Fenn si Peri Dagang", "g": "f", "skin": [Color(0.4, 0.7, 0.4), Color(0.95, 0.9, 0.5), Color(0.2, 0.3, 0.15)], "title": "Kios Hutan Sihir",
        "lines": ["Halo halo! Lihat, bunga-bunga ikut menawar harga untukmu.", "Madu, kayu ajaib, dan permata. Semua berkilau sedikit."],
        "stock": ["potion_mp2", "omelet", "honey", "wood", "egg", "milk", "gem", "bi_8_a", "bi_8_c"]},
    9: {"name": "Hanzo sang Saudagar", "g": "m", "skin": [Color(0.9, 0.55, 0.7), Color(0.2, 0.2, 0.3), Color(0.9, 0.9, 0.95)], "title": "Kedai Sakura",
        "lines": ["Kelopak tak pernah gugur di sini, tapi harga bisa turun kalau kau sopan.", "Madu, susu, bulu, dan ikan emas dari kolam kuil."],
        "stock": ["potion_hp2", "potion_mp2", "steak", "honey", "milk", "feather", "fish_gold", "bi_9_a", "bi_9_c"]},
    10: {"name": "Bu Jamur", "g": "f", "skin": [Color(0.75, 0.3, 0.3), Color(0.95, 0.9, 0.8), Color(0.3, 0.2, 0.15)], "title": "Warung Jamur",
        "lines": ["Ayo, ayo, jangan malu-malu! Jamurnya jinak kok, kecuali yang itu.", "Daging, lendir, bisa. Dan ramuan untuk yang keracunan."],
        "stock": ["potion_hp", "potion_hp2", "omelet", "meat", "goo", "venom", "bi_10_a", "bi_10_c"]},
    11: {"name": "Saudagar Awan", "g": "m", "skin": [Color(0.5, 0.6, 0.95), Color(0.95, 0.95, 1.0), Color(0.2, 0.2, 0.4)], "title": "Lapak Awan",
        "lines": ["Lantai di sini bergetar? Biasa, kami berdagang di atas angin.", "Bulu, kristal, pecahan matahari. Ringan dibawa."],
        "stock": ["potion_mp2", "feather", "crystal", "sunshard", "gem", "bi_11_a", "bi_11_c"]},
    12: {"name": "Kopral Debu", "g": "m", "skin": [Color(0.5, 0.5, 0.55), Color(0.85, 0.8, 0.5), Color(0.2, 0.2, 0.25)], "title": "Gudang Reruntuhan",
        "lines": ["Aku prajurit terakhir yang masih punya kios. Raja kami sudah tiada, tapi stok masih ada.", "Pecahan mahkota, jimat, besi tua. Sisa kerajaan."],
        "stock": ["potion_hp2", "potion_mp2", "crown", "ankh", "scrap", "tusk", "bi_12_a", "bi_12_c"]},
    13: {"name": "Bu Mutiara", "g": "f", "skin": [Color(0.2, 0.6, 0.7), Color(0.95, 0.85, 0.5), Color(0.15, 0.2, 0.3)], "title": "Toko Terumbu",
        "lines": ["Pelan-pelan, karangnya licin. Selamat datang di tokoku.", "Ikan, kristal, dan permata. Semua bercahaya di gelap."],
        "stock": ["potion_mp2", "grilled", "fish_bass", "fish_gold", "gem", "crystal", "bi_13_a", "bi_13_c"]},
    14: {"name": "Pak Verdan", "g": "m", "skin": [Color(0.3, 0.55, 0.3), Color(0.9, 0.85, 0.5), Color(0.2, 0.15, 0.1)], "title": "Gudang Akar",
        "lines": ["Kau sudah dekat dengan akar terdalam. Bawa bekal yang cukup.", "Ramuan besar, kayu ajaib, jantung lava. Persiapan terbaik sebelum ke bawah."],
        "stock": ["potion_hp2", "potion_mp2", "steak", "wood", "honey", "heart", "gem", "bi_14_a", "bi_14_c"]},
    15: {"name": "Prisma si Penjaga", "g": "f", "skin": [Color(0.6, 0.45, 0.9), Color(0.85, 0.95, 1.0), Color(0.2, 0.15, 0.3)], "title": "Galeri Kristal",
        "lines": ["Semua yang kau lihat memantulkan dirimu. Jangan kaget.", "Kristal, rubi, jantung lava. Dagangan akhir dunia."],
        "stock": ["potion_hp2", "potion_mp2", "crystal", "gem", "ruby", "heart", "bi_15_a", "bi_15_c"]},
}

const LINES := [
    ["Selamat datang di Desa Greenwood!", "Jangan lupa bawa ramuan sebelum masuk hutan."],
    ["Pagi ini ikan di kolam banyak sekali. Coba memancing di dekat air!", "Tekan tombol aksi saat tanda ! muncul."],
    ["Kayu dan bijih dari alam bisa dibuat jadi pedang dan armor di meja pandai besi.", "Tebang pohon, tambang batu, semuanya berguna!"],
    ["Di gurun sebelah timur ada Ratu Kalajengking. Jangan sombong sebelum levelmu tinggi.", "Naikkan stat VIT kalau sering terkena serangan."],
    ["Sapi dan ayam di luar desa tidak galak. Dagingnya enak kalau dibakar!", "Tapi lebah dan ular itu galak sekali."],
    ["Katanya Mesin Gacha di sebelah selatan menjual baju keren: mecha, samurai, sampai anak jalanan.", "Aku belum pernah beruntung dapat SSR."],
    ["Utara itu salju abadi. Di sana ada Yeti Perkasa yang sangat kuat.", "Bawa banyak Ramuan HP kalau mau menantangnya."],
    ["Gunung api di selatan panas sekali. Naga Api menjaga puncaknya.", "Obsidian dan rubi hanya ada di sana."],
    ["Bunga-bunga di desa ini mekar sepanjang tahun.", "Cantik ya? Aku suka duduk di sini sore hari."],
    ["Nak, naikkan stat DEX supaya seranganmu lebih cepat.", "LUK juga bagus, peluang kritis dan drop jadi naik."],
    ["Aku menjaga desa ini. Monster tidak berani masuk ke dalam desa.", "Kalau kamu terluka, istirahatlah di sini."],
    ["Kamu terlihat kuat! Sudah mencoba Katana Ronin? Kritisnya mantap.", "Bahannya besi dan kulit."],
]
# Sprite tiap NPC (file assets/sprites/h_<id>.png). Warga biasa memakai salah satu dari VILLAGERS.
const SPRITE_ID := {"elder": "n_tetua", "merchant": "n_pedagang", "smith": "n_alkemis", "healer": "n_tabib", "gacha": "n_madam",
    "fisher": "n_pemancing", "miner": "n_penambang", "lumber": "n_biasa", "marni": "n_putri", "sahar": "n_kesatria", "zahra": "n_madam",
    "gatekeeper": "n_penjaga", "wanderer": "n_pengemis", "c_king": "n_raja", "c_queen": "n_putri", "c_guard": "n_penjaga", "c_knight": "n_kesatria"}
const VILLAGERS := ["n_biasa", "n_anak", "n_madam", "n_pengemis", "n_penambang", "n_pemancing", "n_biasa", "n_anak", "n_madam", "n_alkemis"]
const VILLAGERS_F := ["n_madam", "n_anak", "n_putri"]
const PALETTES := [Color(0.85, 0.35, 0.3), Color(0.3, 0.55, 0.85), Color(0.35, 0.7, 0.4), Color(0.9, 0.7, 0.25), Color(0.7, 0.4, 0.75), Color(0.9, 0.55, 0.3), Color(0.5, 0.5, 0.55)]

var role := "villager"
var npc_name := "Warga"
var gender := "m"
var skin := {}
var home := Vector2.ZERO
var wander := false
var lines: Array = []
var player
var world

var _t := randf() * 10.0
var _dir := 0
var _flip := false
var _rd := 0.0
var _pending_secret := ""
var _job_offer: Array = []
var _veiled := false        # saksi rahasia: tersembunyi sampai syarat muncul terpenuhi
var _veil_t := 0.0


func _ready() -> void:
    add_to_group("npcs")
    add_to_group("lod")
    player = get_tree().get_first_node_in_group("player")
    world = get_tree().get_first_node_in_group("world")
    home = position
    if skin.is_empty():
        var c: Color = PALETTES[randi() % PALETTES.size()]
        skin = {"theme": "adv", "rarity": 0, "c1": c, "c2": c.lightened(0.4), "c3": Color(0.35, 0.25, 0.15)}
    match role:
        "elder":
            npc_name = "Tetua Oren"
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.45, 0.3, 0.6), "c2": Color(0.95, 0.85, 0.4), "c3": Color(0.3, 0.2, 0.1)}
        "merchant":
            npc_name = "Pak Dagang"
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.85, 0.6, 0.2), "c2": Color(1.0, 0.9, 0.5), "c3": Color(0.3, 0.2, 0.1)}
        "smith":
            npc_name = "Pandai Gora"
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.4, 0.4, 0.45), "c2": Color(0.9, 0.5, 0.2), "c3": Color(0.2, 0.2, 0.2)}
        "healer":
            npc_name = "Tabib Lila"
            gender = "f"
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.95, 0.95, 0.95), "c2": Color(0.9, 0.25, 0.3), "c3": Color(0.3, 0.2, 0.1)}
        "gacha":
            npc_name = "Madam Gem"
            gender = "f"
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.65, 0.3, 0.8), "c2": Color(1.0, 0.8, 0.3), "c3": Color(0.3, 0.2, 0.1)}
        "fisher":
            npc_name = "Nelayan Udin"
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.3, 0.55, 0.7), "c2": Color(0.9, 0.85, 0.5), "c3": Color(0.3, 0.2, 0.1)}
        "miner":
            npc_name = "Penambang Karto"
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.55, 0.45, 0.35), "c2": Color(0.95, 0.8, 0.2), "c3": Color(0.3, 0.2, 0.1)}
        "lumber":
            npc_name = "Penebang Joni"
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.7, 0.2, 0.2), "c2": Color(0.3, 0.3, 0.3), "c3": Color(0.3, 0.2, 0.1)}
        "marni":
            npc_name = Secrets.DATA["marni"]["name"]
            gender = "f"
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.5, 0.35, 0.55), "c2": Color(0.85, 0.8, 0.85), "c3": Color(0.8, 0.8, 0.8)}
        "sahar":
            npc_name = Secrets.DATA["sahar"]["name"]
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.85, 0.75, 0.55), "c2": Color(0.6, 0.35, 0.2), "c3": Color(0.85, 0.85, 0.85)}
        "zahra":
            npc_name = Secrets.DATA["zahra"]["name"]
            gender = "f"
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.2, 0.5, 0.55), "c2": Color(0.95, 0.6, 0.2), "c3": Color(0.25, 0.15, 0.1)}
        "wanderer":
            npc_name = "Kelana Sunyi"
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.35, 0.3, 0.25), "c2": Color(0.8, 0.7, 0.45), "c3": Color(0.2, 0.15, 0.1)}
        "gatekeeper":
            npc_name = "Penjaga Gerbang Ether"
            skin = {"theme": "adv", "rarity": 0, "c1": Color(0.18, 0.25, 0.48), "c2": Color(0.35, 0.85, 1.0), "c3": Color(0.12, 0.12, 0.2)}
        _:
            if Secrets.DATA.has(role) and Secrets.is_witness(role):
                var wd: Dictionary = Secrets.DATA[role]
                npc_name = String(wd["name"])
                gender = String(wd["gender"])
                var wc: Array = wd["skin"]
                skin = {"theme": "adv", "rarity": 0, "c1": wc[0], "c2": wc[1], "c3": wc[2]}
                _veiled = not bool(Game.p["secrets"].get(role + "_seen", false))
                if _veiled:
                    remove_from_group("npcs")
            elif role.begins_with("bm_") and BMER.has(int(role.substr(3))):
                var bd: Dictionary = BMER[int(role.substr(3))]
                npc_name = String(bd["name"])
                gender = String(bd["g"])
                var bc: Array = bd["skin"]
                skin = {"theme": "adv", "rarity": 0, "c1": bc[0], "c2": bc[1], "c3": bc[2]}
            elif role.begins_with("c_"):
                match role:
                    "c_king":
                        npc_name = "Raja Aldric"
                        lines = ["Selamat datang di istanaku, pengelana.", "Kerajaan ini aman selama pahlawan seperti dirimu masih berjalan di negeri ini."]
                    "c_queen":
                        npc_name = "Putri Elara"
                        lines = ["Ayahku selalu bilang, keberanian itu soal terus melangkah.", "Aku suka melihat para petualang pulang dengan selamat."]
                    "c_knight":
                        npc_name = "Ksatria Kerajaan"
                        lines = ["Aku bersumpah melindungi kastil ini.", "Monster di luar sana makin liar. Jaga dirimu."]
                    _:
                        npc_name = "Penjaga Kastil"
                        lines = ["Berhenti! ...Oh, kamu pahlawan itu. Silakan lewat.", "Gerbang ini kujaga siang dan malam."]
            elif Sidequests.is_role(role):
                var sd: Array = Sidequests.NPC[Sidequests.biome_of(role)]
                npc_name = String(sd[0])
                gender = String(sd[1])
                var sc: Color = PALETTES[Sidequests.biome_of(role) % PALETTES.size()]
                skin = {"theme": "adv", "rarity": 0, "c1": sc, "c2": sc.lightened(0.45), "c3": Color(0.3, 0.2, 0.12)}
            else:
                lines = LINES[randi() % LINES.size()]
                if npc_name == "Warga":
                    npc_name = _pick_name()


# NPC tidak berjalan; hanya menoleh ke pemain yang mendekat. Gambar ulang jarang (10 Hz)
# dan hanya kalau dekat layar.
func _process(delta: float) -> void:
    _t += delta
    _rd += delta
    if player == null:
        return
    var to: Vector2 = player.global_position - global_position
    var d2: float = to.length_squared()
    if d2 > 160000.0:
        return
    if _veiled:
        _veil_t += delta
        if _veil_t >= 1.0:
            _veil_t = 0.0
            if Secrets.trigger_ok(role, get_tree().current_scene):
                _unveil()
        return
    if d2 < 6400.0:
        _set_dir(to)
    if _rd >= 0.1:
        _rd = 0.0
        queue_redraw()


# nama warga unik (tidak kembar) sampai daftar habis, lalu diulang
static func _pick_name() -> String:
    var free: Array = []
    for n in NAMES:
        if not _used_names.has(n):
            free.append(n)
    if free.is_empty():
        _used_names.clear()
        free = NAMES.duplicate()
    var pick: String = String(free[randi() % free.size()])
    _used_names.append(pick)
    return pick


func _unveil() -> void:
    _veiled = false
    add_to_group("npcs")
    Game.p["secrets"][role + "_seen"] = true
    var main = get_tree().current_scene
    main.fx_burst(global_position, Color(0.9, 0.85, 1.0), 14, 60.0, 0.8, -20.0, 2.0, "star")
    Audio.sfx("select")
    var hud = get_tree().get_first_node_in_group("hud")
    if hud:
        hud.toast("Seseorang muncul di dekatmu...")
    queue_redraw()


# Tanda quest di atas kepala ("!" tersedia, "?" siap lapor), dipakai minimap & panah pelacak
func quest_mark() -> String:
    if role.begins_with("sq_") and player:
        return Sidequests.marker(role, player)
    if role == "elder":
        var q: Dictionary = Game.p["quest"]
        if q["type"] == "none" or Game.quest_done():
            return "!"
    return ""


func fade_out() -> void:
    var tw := create_tween()
    tw.tween_property(self, "modulate:a", 0.0, 2.0)
    tw.tween_callback(queue_free)


func _sprite_id() -> String:
    if role.begins_with("sq_"):
        return String(VILLAGERS[Sidequests.biome_of(role) % VILLAGERS.size()])
    if SPRITE_ID.has(role):
        return String(SPRITE_ID[role])
    if role.begins_with("bm_"):
        return "n_penyihir"
    if gender == "f":
        return String(VILLAGERS_F[int(get_instance_id()) % VILLAGERS_F.size()])
    return String(VILLAGERS[int(get_instance_id()) % VILLAGERS.size()])


func _set_dir(d: Vector2) -> void:
    if absf(d.x) > absf(d.y):
        _dir = 2
        _flip = d.x < 0.0
    elif d.y < 0.0:
        _dir = 1
    else:
        _dir = 0


func _draw() -> void:
    if _veiled:
        return
    Art.shadow(self, 9.0, 8.0)
    if role == "gacha":
        Art.draw_gacha_machine(self, Vector2(34, 2), _t)
    var o := {"skin": skin, "gender": gender, "dir": _dir, "flip": _flip, "t": _t, "phase": 0.0, "moving": false,
        "sprite_id": _sprite_id()}
    if role == "smith":
        o["held"] = {"kind": "tool", "tool": "axe"}
        o["weapon_ang"] = PI / 2.0 - 0.6
    elif role == "miner":
        o["held"] = {"kind": "tool", "tool": "pick"}
        o["weapon_ang"] = PI / 2.0 - 0.6
    elif role == "lumber":
        o["held"] = {"kind": "tool", "tool": "axe"}
        o["weapon_ang"] = PI / 2.0 - 0.6
    elif role == "fisher":
        o["held"] = {"kind": "tool", "tool": "rod"}
        o["weapon_ang"] = PI / 2.0 - 1.0
    if role == "elder":
        o["gender"] = "m"
    Art.draw_human(self, o)
    if player and player.global_position.distance_to(global_position) < 200.0:
        var nc := Color(1, 1, 0.8) if role == "villager" or role == "wanderer" else Color(1.0, 0.92, 0.55)
        draw_string_outline(ThemeDB.fallback_font, Vector2(-60, -24), npc_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, 3, Color(0, 0, 0, 0.85))
        draw_string(ThemeDB.fallback_font, Vector2(-60, -24), npc_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, nc)
    if Secrets.DATA.has(role) and not Secrets.finished(role) and Secrets.accepted(role) and Secrets.is_complete(role, player):
        draw_string(ThemeDB.fallback_font, Vector2(-10, -30 + sin(_t * 5.0) * 2.0), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 20, Color(0.8, 0.55, 1.0))
    if role == "elder":
        var q: Dictionary = Game.p["quest"]
        if q["type"] == "none" or Game.quest_done():
            draw_string(ThemeDB.fallback_font, Vector2(-10, -30 + sin(_t * 5.0) * 2.0), "!", HORIZONTAL_ALIGNMENT_CENTER, 20, 20, Color(1, 0.85, 0.2))
    if role.begins_with("sq_") and player:
        var qm: String = Sidequests.marker(role, player)
        if qm != "":
            draw_string(ThemeDB.fallback_font, Vector2(-10, -30 + sin(_t * 5.0) * 2.0), qm, HORIZONTAL_ALIGNMENT_CENTER, 20, 20, Color(0.4, 0.95, 0.85))
    var sm: String = Story.marker(role)
    if sm != "":
        draw_string(ThemeDB.fallback_font, Vector2(8, -30 + sin(_t * 5.0 + 1.0) * 2.0), sm, HORIZONTAL_ALIGNMENT_CENTER, 20, 20, Color(1.0, 0.5, 0.1))


# ------------------------------------------------------------------ interaksi
# Alur dialog memakai method + Callable.bind agar mudah dibaca (hasil pilihan masuk sebagai argumen pertama).
func interact(pl) -> void:
    var hud = get_tree().get_first_node_in_group("hud")
    if hud == null or hud.busy():
        return
    Audio.sfx("blip")
    if role != "elder" and Story.marker(role) == "?":
        _talk_story(hud, pl)
        return
    match role:
        "elder":
            _talk_elder(hud, pl)
        "merchant":
            hud.say(npc_name, ["Selamat datang! Ramuan segar, harga bersahabat."], _merchant_menu.bind(hud))
        "smith":
            hud.say(npc_name, ["Bawa bahan, aku tempa jadi senjata dan armor."], hud.open_menu.bind("craft"))
        "healer":
            hud.say(npc_name, ["Kamu kelihatan lelah. Biar kupulihkan."], _heal.bind(pl))
        "gacha":
            hud.say(npc_name, ["Halo! Coba keberuntunganmu. Skin mecha, samurai, dan street boy menantimu!"], _gacha_menu.bind(hud))
        "fisher":
            hud.say(npc_name, ["Ikan itu butuh kesabaran. Berdiri di tepi air lalu tekan tombol Aksi.", "Ikan Emas jarang sekali, tapi bayarannya gem!"], _sell_menu.bind(hud, "Mau jual ikan?", "Jual ikan", "fish"))
        "miner":
            hud.say(npc_name, ["Batu dan bijih ada di mana-mana. Tiap daerah punya bijih berbeda.", "Besi di hutan, emas di gurun, kristal di salju, rubi di gunung api."], _sell_menu.bind(hud, "Mau jual bijih?", "Jual bijih", "ore"))
        "lumber":
            hud.say(npc_name, ["Pohon yang ditebang tumbuh lagi. Kayu gelondong dipakai hampir semua resep."], _sell_menu.bind(hud, "Mau jual kayu?", "Jual kayu", "log"))
        "marni", "sahar", "zahra":
            _talk_secret(hud, pl)
        "wanderer":
            _talk_wanderer(hud, pl)
        "gatekeeper":
            if pl.level() < 200:
                hud.say(npc_name, ["Gerbang World 2 belum bisa dibuka. Kembalilah saat levelmu mencapai 200.", "Di balik gerbang ada Ethergrooves, Forgotten Kingdom, Lumins Reef, dan Verdan Height."])
            elif bool(Game.p.get("world2_unlocked", false)):
                hud.say(npc_name, ["Gerbang sudah terbuka. Dunia di baliknya menunggumu."])
            else:
                hud.say(npc_name, ["Levelmu cukup. Apa kamu siap menyeberang ke World 2?"], _enter_world2.bind(pl))
        _:
            if Secrets.is_witness(role):
                _talk_secret(hud, pl)
                return
            if role.begins_with("bm_") and BMER.has(int(role.substr(3))):
                var bd: Dictionary = BMER[int(role.substr(3))]
                hud.say(npc_name, bd["lines"], _bm_menu.bind(hud, bd, int(role.substr(3))))
                return
            if Sidequests.is_role(role):
                Sidequests.talk(self, hud, pl)
                return
            var l: Array = []
            for ln in lines:
                l.append(ln)
            if role == "villager":
                l.append(Plot.mood_line(get_instance_id()))
            hud.say(npc_name, l)


func _enter_world2(pl) -> void:
    Game.p["world2_unlocked"] = true
    Game.save()
    var w = get_tree().get_first_node_in_group("world")
    if w != null:
        pl.global_position = w.find_open(Vector2i(228, 24))
    var hud = get_tree().get_first_node_in_group("hud")
    if hud:
        hud.show_banner("WORLD 2 — THE OUTER REALMS", 4.0)


# ------------------------------------------------------------------ quest rahasia
func _talk_secret(hud, pl) -> void:
    var id: String = role
    var d: Dictionary = Secrets.DATA[id]
    if Secrets.finished(id):
        if id == "w1":
            var ph: int = Plot.w1_phase()
            if ph == 2:
                Plot.run_w1_goodbye(self, hud, pl)
                return
            elif ph == 1:
                hud.say(npc_name, Plot.w1_foreboding())
                return
        if d.has("epilog") and Story.finished():
            hud.say(npc_name, d["epilog"])
        else:
            hud.say(npc_name, d["final"])
        return
    var s: Dictionary = d["stages"][Secrets.stage(id)]
    if not Secrets.accepted(id):
        var il: Array = s["intro"]
        if Secrets.PL.has(id):
            il = Secrets.weave(il, Secrets.PL[id]["intro"])
        hud.say(npc_name, il, _secret_offer.bind(hud, id))
    elif Secrets.is_complete(id, pl):
        var dl: Array = s["done"]
        if Secrets.PL.has(id):
            dl = Secrets.weave(dl, Secrets.PL[id]["done"])
        hud.say(npc_name, dl, _secret_done.bind(hud, pl, id))
    else:
        hud.say(npc_name, ["Kamu belum selesai. %s." % Secrets.progress_text(id, pl)])


func _secret_offer(hud, id: String) -> void:
    hud.choose(npc_name, "Terima permintaan ini?", ["Terima", "Nanti saja"], _secret_pick.bind(hud, id))


func _secret_pick(i: int, hud, id: String) -> void:
    if i == 0:
        Secrets.accept(id)
        Audio.sfx("select")
        hud.toast("Quest rahasia diterima: %s" % Secrets.progress_text(id, player))


func _secret_done(hud, pl, id: String) -> void:
    Secrets.complete(id, pl)
    Audio.sfx("win")
    hud.toast("Quest rahasia selesai!")
    if Secrets.is_witness(id):
        hud.toast("Kepingan Kebenaran %d/13" % Secrets.truth_count())
        if id == "w14":
            hud.toast("Segel Akar didapat: seranganmu ke Worldroot Devourer lebih tajam!")
        Plot.on_testimony(id, hud)
    elif Secrets.finished(id):
        var main = get_tree().current_scene
        main.spawn_secret_chest(id, true)
        hud.toast(String(Secrets.DATA[id]["chest"]["hint"]))


# ------------------------------------------------------------------ pengembara
func _talk_wanderer(hud, pl) -> void:
    var h: String = get_tree().current_scene.lore_hint(pl.global_position)
    var lines: Array = [
        "Aku hanya berjalan ke mana angin membawa. Kau pencari prasasti kuno, ya?",
        "Sejauh ini kau sudah membaca %d dari %d prasasti." % [Lore.count(), Lore.total()],
    ]
    if h == "":
        lines.append("Semuanya sudah kau baca. Kisah itu sekarang milikmu.")
    else:
        lines.append(h)
    hud.say(npc_name, lines)


# ------------------------------------------------------------------ kisah utama
func _talk_story(hud, pl) -> void:
    if Story.finished():
        hud.say(npc_name, Story.FINAL)
        return
    var c: Dictionary = Story.cur()
    if not Story.accepted():
        if Story.giver() == role:
            hud.say(npc_name, c["intro"], _story_offer.bind(hud))
        else:
            hud.say(npc_name, ["Soal itu, temui %s." % Story.npc_name(Story.giver())])
    elif Story.is_complete():
        if Story.turnin() == role:
            hud.say(npc_name, c["done"], _story_done.bind(hud, pl))
        else:
            hud.say(npc_name, ["Tujuanmu sudah selesai. Temui %s." % Story.npc_name(Story.turnin())])
    else:
        hud.say(npc_name, [
            "Kisah \"%s\": %s." % [String(c["title"]), Story.progress_text()],
            "Lokasi: %s. Level disarankan: %d." % [String(c["where"]), int(c["rec"])],
        ])


func _story_offer(hud) -> void:
    var c: Dictionary = Story.cur()
    hud.choose(npc_name, "Kisah: %s\nLevel disarankan: %d  |  %s\nHadiah: %s" % [String(c["title"]), int(c["rec"]), String(c["where"]), Story.reward_text()], ["Terima", "Nanti saja"], _story_pick.bind(hud))


func _story_pick(i: int, hud) -> void:
    if i == 0:
        Story.accept()
        Audio.sfx("select")
        hud.toast("Kisah dimulai: %s" % String(Story.cur()["title"]))
        hud.show_banner("Kisah Utama: %s" % String(Story.cur()["title"]), 3.0)
        Story.check_notice()


func _story_done(hud, pl) -> void:
    var rt: String = Story.reward_text()
    Story.complete(pl)
    Audio.sfx("win")
    hud.toast("Kisah selesai! Hadiah: %s" % rt)
    if Story.finished():
        hud.show_banner("KISAH UTAMA TAMAT", 4.0)
    else:
        hud.toast("Kisah berlanjut... Temui %s" % Story.npc_name(Story.giver()))


func _merchant_menu(hud) -> void:
    hud.choose(npc_name, "Mau apa?", ["Beli", "Jual barang", "Tidak jadi"], _merchant_pick.bind(hud))


func _merchant_pick(i: int, hud) -> void:
    if i == 0:
        hud.open_menu("shop", {"mode": "buy"})
    elif i == 1:
        hud.open_menu("shop", {"mode": "sell", "mult": 1.0, "filter": ""})


func _bm_menu(hud, bd: Dictionary, b: int) -> void:
    hud.choose(npc_name, "Mau apa?", ["Beli", "Jual barang (harga lebih baik)", "Tidak jadi"], _bm_pick.bind(hud, bd, b))


func _bm_pick(i: int, hud, bd: Dictionary, b: int) -> void:
    if i == 0:
        hud.open_menu("shop", {"mode": "buy", "stock": bd["stock"], "title": bd["title"]})
    elif i == 1:
        hud.open_menu("shop", {"mode": "sell", "mult": 1.0 + 0.03 * float(b), "filter": ""})


func _heal(pl) -> void:
    pl.full_heal()
    get_tree().current_scene.fx_burst(pl.global_position, Color(0.5, 1.0, 0.6), 14, 50.0, 0.8, -30.0, 2.0, "star")


func _gacha_menu(hud) -> void:
    hud.choose(npc_name, "Gem: %d  (60 gem / tarik)" % int(Game.p["gems"]), ["Tarik x1", "Tarik x10 (540)", "Lemari skin", "Pergi"], _gacha_pick.bind(hud))


func _gacha_pick(i: int, hud) -> void:
    if i == 0:
        hud.gacha_pull(1)
    elif i == 1:
        hud.gacha_pull(10)
    elif i == 2:
        hud.open_menu("skin")


func _sell_menu(hud, prompt: String, label: String, filter: String) -> void:
    hud.choose(npc_name, prompt, [label, "Tidak"], _sell_pick.bind(hud, filter))


func _sell_pick(i: int, hud, filter: String) -> void:
    if i == 0:
        hud.open_menu("shop", {"mode": "sell", "mult": 1.3, "filter": filter})


func _talk_elder(hud, pl) -> void:
    if Plot.twist_ready():
        Plot.run_twist(self, hud, pl)
        return
    if Plot.ending_pending():
        Plot.ending_scene()
        return
    if not bool(Game.p["intro"]):
        Game.p["intro"] = true
        hud.say(npc_name, [
            "Selamat datang, pengembara! Aku Tetua Oren, penjaga Desa Greenwood.",
            "@p:Terima kasih, Tetua. Tempat ini kelihatannya damai.",
            "Dunia ini terbuka: hutan di barat, gurun di timur, salju di utara, gunung api di selatan.",
            "@p:Luas sekali. Aku harus mulai dari mana?",
            "Tiap daerah punya bos yang kuat. Tidak wajib dikalahkan, tapi hadiahnya besar.",
            "@p:Siap. Aku akan hati-hati.",
            "Tebang pohon, tambang batu, dan memancing untuk bahan crafting. Naikkan statmu di menu!",
        ], _elder_menu.bind(hud, pl))
        return
    _elder_menu(hud, pl)


# Menu Tetua Oren selama Kisah Utama belum tamat: pilih kisah atau tugas harian
func _elder_menu(hud, pl) -> void:
    var tag := ""
    var m: String = Story.marker("elder")
    if m == "!":
        tag = " (baru!)"
    elif m == "?":
        tag = " (siap diselesaikan)"
    elif Story.finished():
        tag = " (tamat)"
    hud.choose(npc_name, "Ada yang bisa kubantu, Nak?", ["Kisah Utama" + tag, "Tugas Harian", "Kabar Pengembara", "Jalan Warisan (Job)", "Pergi"], _elder_pick.bind(hud, pl))


func _elder_pick(i: int, hud, pl) -> void:
    if i == 0:
        _talk_story(hud, pl)
    elif i == 1:
        _elder_daily(hud, pl)
    elif i == 2:
        hud.say(npc_name, [get_tree().current_scene.wanderer_rumor()])
    elif i == 3:
        _elder_job(hud)


# ------------------------------------------------------------------ Jalan Warisan (job rahasia & Legend)
func _elder_job(hud) -> void:
    var cur: String = Jobs.cur()
    var av: Array = Jobs.available()
    if av.is_empty():
        var lines: Array = ["Jalanmu saat ini: %s." % Jobs.name_of(cur)]
        if cur != "" and int(Jobs.DATA[cur]["tier"]) == 2:
            lines.append("Kau pewaris Benih Pertama. Tak ada jalan yang lebih tinggi lagi.")
        else:
            lines.append("Dengarkan kesaksian para saksi tersembunyi. Warisan mereka membuka jalan baru bagi jalanmu.")
            lines.append("Kalau kau menanam kembali Benih Pertama setelah Worldroot Devourer tumbang, jalan terakhir akan terbuka.")
        hud.say(npc_name, lines)
        return
    _job_offer = av
    var names: Array = []
    for id in av:
        names.append(String(Jobs.DATA[id]["name"]))
    names.append("Nanti saja")
    hud.say(npc_name, ["Aku merasakan warisan menyelimutimu, Nak.", "Pilihan ini PERMANEN. Pikirkan baik-baik."], _elder_job_choose.bind(hud, names))


func _elder_job_choose(hud, names: Array) -> void:
    hud.choose(npc_name, "Jalan mana yang kau ambil?", names, _elder_job_pick.bind(hud))


func _elder_job_pick(i: int, hud) -> void:
    if i >= _job_offer.size():
        return
    var id: String = String(_job_offer[i])
    var d: Dictionary = Jobs.DATA[id]
    hud.choose(npc_name, "%s\n%s\nSkill: %s\nYakin? Tidak bisa diganti." % [String(d["name"]), String(d["desc"]), String(d["skill"]["name"])], ["Ya, ambil jalan ini", "Batal"], _elder_job_confirm.bind(hud, id))


func _elder_job_confirm(i: int, hud, id: String) -> void:
    if i != 0 or not Jobs.can_take(id):
        return
    Jobs.take(id)
    var pl = hud.player
    if pl:
        pl.recalc()
        pl.refresh_pet()
    Audio.sfx("levelup")
    hud.show_banner("JOB BARU: " + Jobs.name_of(id).to_upper(), 3.5)
    hud.say(npc_name, ["Jalanmu kini: %s." % Jobs.name_of(id), "Pakai skill barumu dengan tombol skill."])


func _elder_daily(hud, pl) -> void:
    var q: Dictionary = Game.p["quest"]
    if q["type"] == "none":
        _offer(hud, pl)
    elif Game.quest_done():
        hud.say(npc_name, ["Hebat! Ini hadiahmu: %d koin, %d gem, dan pengalaman." % [int(q["coins"]), int(q["gems"])]], _reward.bind(hud, pl))
    else:
        hud.say(npc_name, ["Tugasmu: %s. Baru %d dari %d." % [String(q["label"]), int(q["have"]), int(q["need"])]])


func _reward(hud, pl) -> void:
    var q: Dictionary = Game.p["quest"]
    Game.p["coins"] = int(Game.p["coins"]) + int(q["coins"])
    Game.p["gems"] = int(Game.p["gems"]) + int(q["gems"])
    Audio.sfx("win")
    var xp: int = int(q["xp"])
    Game.p["quest"] = {"type": "none", "need": 0, "have": 0, "coins": 0, "gems": 0, "xp": 0, "label": ""}
    pl.give_xp(xp)
    Game.save()
    _offer(hud, pl)


var _pending := {}


func _offer(hud, _pl) -> void:
    _pending = Game.make_quest(int(Game.p["level"]))
    hud.choose(npc_name, "Tugas baru: %s\nHadiah: %d koin, %d gem, %d XP" % [_pending["label"], _pending["coins"], _pending["gems"], _pending["xp"]], ["Terima", "Nanti saja"], _offer_pick.bind(hud))


func _offer_pick(i: int, hud) -> void:
    if i == 0:
        Game.p["quest"] = _pending
        Audio.sfx("select")
        hud.toast("Quest diterima: %s" % _pending["label"])
