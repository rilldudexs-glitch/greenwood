extends Node2D

const Bal = preload("res://scripts/balance.gd")
const Story = preload("res://scripts/story.gd")
# Adegan utama dunia terbuka. Membuat dunia, NPC, monster, bos, peti, api unggun,
# HUD dan pemain; juga menyediakan helper efek (fx_*) dan spawn (spawn_*).

const FX = preload("res://scripts/fx.gd")
const WorldScript = preload("res://scripts/world.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const HudScript = preload("res://scripts/hud.gd")
const NpcScript = preload("res://scripts/npc.gd")
const EnemyScene = preload("res://scenes/enemy.tscn")
const BossScene = preload("res://scenes/boss.tscn")
const PlayerScene = preload("res://scenes/player.tscn")
const PickupScene = preload("res://scenes/pickup.tscn")
const Secrets = preload("res://scripts/secrets.gd")
const Plot = preload("res://scripts/plot.gd")
const Sidequests = preload("res://scripts/sidequests.gd")
const ChestScript = preload("res://scripts/chest.gd")
const CheckpointScript = preload("res://scripts/checkpoint.gd")
const DungeonScript = preload("res://scripts/dungeon.gd")
const CaveGateScript = preload("res://scripts/cave_gate.gd")
const Lore = preload("res://scripts/lore.gd")
const AtmosScript = preload("res://scripts/atmosphere.gd")
const AmbientScript = preload("res://scripts/ambient.gd")
const GlowScript = preload("res://scripts/glow.gd")
const EventsScript = preload("res://scripts/world_events.gd")
const JournalPageScript = preload("res://scripts/journal_page.gd")
const Journal = preload("res://scripts/journal.gd")
const LoreStoneScript = preload("res://scripts/lore_stone.gd")

const MOB_TABLE := {
	0: {"chicken": 6, "cow": 3},
	1: {"slime": 12, "bee": 8, "goblin": 12, "spider": 8, "cow": 6, "chicken": 6, "snake": 5, "fiend": 2, "ogre": 2,
		"wolf": 6, "kobold": 6, "bat": 4, "bear": 2},
	2: {"snake": 10, "spider": 8, "goblin": 9, "ogre": 4, "wisp": 5, "fiend": 4, "slime": 4, "red_ogre": 1,
		"mummy": 8, "centipede": 8, "bat": 5, "golem": 2, "kobold": 4},
	3: {"slime": 8, "wisp": 5, "goblin": 9, "spider": 6, "ogre": 5, "fiend": 5, "snake": 2, "cow": 3, "red_ogre": 1,
		"wolf": 8, "bear": 4, "golem": 3, "bat": 4},
	4: {"slime": 6, "wisp": 6, "fiend": 9, "spider": 6, "goblin": 6, "ogre": 4, "red_ogre": 5, "snake": 4,
		"golem": 5, "centipede": 6, "bat": 6, "kobold": 6, "mummy": 3},
	5: {"umbral_slime": 4, "gloomfang_wolf": 4, "shade_stalker": 3, "dusk_bat": 3, "night_kobold": 3, "eclipse_spider": 3, "dusk_wraith": 3, "umbral_archer": 3, "cursed_knight": 3, "shadow_brute": 3, "shadow_soul_reaper": 3, "ethereal_wisp": 3, "dark_mage": 3, "revenant": 3, "royal_executor": 3},
	6: {"hollow_wisp": 4, "gravebound_ogre": 3, "ashen_fiend": 3, "rift_serpent": 3, "null_crawler": 3, "glitch_golem": 3, "voidling": 3, "glitch_mite": 3, "rift_mimic": 3, "corrupted_drone": 3, "glitch_knight": 3, "dimensional_wraith": 3, "pixel_swarm": 3, "data_sentinel": 3, "void_leviathan": 3},
	7: {"abyss_eel": 4, "deep_maw": 3, "trench_horror": 3, "blackfin_stalker": 3, "void_jelly": 3, "drowned_mummy": 3, "abyssal_slime": 3, "abyssal_crab": 3, "leviathan_larva": 3, "sea_siren": 3, "coral_golem": 3, "depth_reaper": 3, "krakenling": 3, "reef_golem": 3, "abyssal_archer": 3, "sea_drake": 3, "pearl_guardian": 3, "oceanic_horror": 3, "abyssal_colossus": 3, "trident_warden": 3},
	8: {"thorn_sprite": 4, "mossback_bear": 3, "elder_treantling": 3, "briar_goblin": 3, "bloom_wisp": 3, "rootbound_ogre": 3, "bloom_slime": 3, "petal_pixie": 3, "thorn_spider": 3, "moss_golem": 3, "fey_knight": 3, "moon_deer": 3, "forest_mage": 3, "vine_crawler": 3, "spore_moth": 3, "root_horror": 3, "fungal_walker": 3, "ancient_spirit": 3, "verdant_colossus": 3, "sylvan_beast": 3},
	9: {"petal_fox": 4, "sakura_moth": 3, "crimson_koi": 3, "blossom_spider": 3, "pink_warden": 3, "fallen_ronin": 3, "cherry_oni": 3, "blossom_spirit": 3, "red_crane": 3, "sakura_spirit": 3, "sakura_archer": 3, "sakura_oni_warrior": 3, "fallen_hanami": 3, "sakura_beast": 3, "flower_wisp": 3, "blossom_guardian": 3, "shrine_guard": 3, "cherry_dragon": 3, "sakura_mage": 3, "divine_sakura": 3},
	10: {"sporeling": 4, "mushroom_brute": 3, "myco_shaman": 3, "toxic_toad": 3, "cap_guardian": 3, "fungal_bat": 3, "spore_shooter": 3, "myco_spider": 3, "mushroom_mage": 3, "shroom_archer": 3, "cap_knight": 3, "mushroom_beast": 3, "spore_wisp": 3, "toadstool_golem": 3, "mushroom_drone": 3, "fungus_hydra": 3, "spore_knight": 3, "giant_mushroom": 3, "royal_mushroom": 3, "mushroom_overlord": 3},
	11: {"ether_drake": 4, "cloud_wisp": 3, "aether_manta": 3, "prism_golem": 3, "sky_kobold": 3, "starved_harpy": 3, "wind_colossus": 3, "arcane_golem": 3, "rune_sentinel": 3, "ether_elemental": 3, "crystal_wraith": 3, "shadow_herald": 3, "soul_reaver": 3, "void_spider": 3, "ether_shooter": 3, "dream_stalker": 3, "fallen_sorcerer": 3, "rift_guardian": 3, "astral_shade": 3, "nebula_gazer": 3, "grave_warden": 3, "void_archon": 3, "ether_lord": 3, "the_aether_colossus": 3},
	12: {"ruins_sentinel": 4, "forgotten_knight": 3, "dust_revenant": 3, "relic_scorpion": 3, "lost_archer": 3, "ancient_mummy": 3, "ghost": 3, "lich_mage": 3, "wraith": 3, "cursed_armor": 3, "grave_slime": 3, "necro_bat": 3, "grave_guardian": 3, "phantom_knight": 3, "soul_reaper": 3, "specter": 3, "bone_dragon": 3, "death_mage": 3, "lost_spirit": 3, "the_forgotten_king": 3},
	13: {"lumin_ray": 4, "reef_guardian": 3, "pearl_wisp": 3, "coral_stalker": 3, "tide_serpent": 3, "glow_jelly": 3, "reef_fish": 2, "violet_fish": 2, "angler_fish": 2, "reef_perch": 2, "armored_coral_crab": 2, "magma_coral_crab": 2, "crystal_coral": 2, "sea_urchin": 2, "pufferfish": 2, "bubble_polyp": 2, "pearl_slug": 2, "seahorse": 2, "striped_reef_fish": 2, "violet_piranha": 2, "kelp_spirit": 2, "pink_jelly": 2, "shard_imp": 2, "clam_mimic": 2, "bubble_imp": 2, "shard_minnow": 2, "lumin_jelly": 2, "reef_stalker": 2, "coral_hydra": 2, "pearl_siren": 2, "tide_warden": 2, "radiant_leviathan": 2},
	14: {"verdan_stag": 4, "canopy_hunter": 3, "elder_boar": 3, "vine_strangler": 3, "pollen_sprite": 3, "grove_colossus": 3, "verdant_sporeling": 3, "verdant_mushroom_brute": 3, "myconid_mage": 3, "toadstool_guard": 3, "fungal_stalker": 3, "kings_spore": 3, "verdant_moss_golem": 3, "fungal_giant": 3, "verdant_ent": 3, "spore_queen": 3},
}
const PACK := {"goblin": 3, "wolf": 3, "bat": 3, "kobold": 2}                                  # jenis yang muncul berkelompok
const MIN_DIST := {"ogre": 700.0, "red_ogre": 800.0, "golem": 600.0, "bear": 500.0}         # elit: jauh dari titik awal / pemain
const RESPAWN_T := {}
const BOSS_SPD := [42.0, 55.0, 48.0, 52.0]      # HP, level, damage, XP bos dihitung di balance.gd
const CHESTS_PER_BIOME := [4, 20, 14, 14, 14, 16, 14, 14, 16, 16, 16, 18, 18, 18, 18]
const MOB_DENSITY := 0.85                          # peta 2.25x lebih luas; monster tidak dikali penuh agar FPS aman
const RESPAWN_SEC := 300.0                        # monster & bos hidup lagi setelah 5 menit
const SCATTER_MULT := 0.35                        # sebaran acak dikurangi; monster utama sekarang ada di zona leveling (Bal.ZONES)

var world
var hud
var player
var entities: Node2D
var fx_layer: Node2D
var _respawns: Array = []
var _zone_pos: Array = []          # pusat tiap zona leveling (px), sudah disesuaikan ke tempat terbuka
var _zone_cells: Array = []        # tiap zona: daftar sel terbuka di dalam lingkarannya
var _cur_zone := -1
var _boss_nodes: Array = []
var _lod_t := 0.0
var wanderer_biome := -1            # biome tempat Kelana Sunyi muncul hari ini (-1 = tidak ada)
var atmos = null                   # siang-malam & cuaca (atmosphere.gd)
var events = null                  # event dunia: Bulan Darah, meteor (world_events.gd)
var blood_moon := false            # true saat Bulan Darah (dibaca enemy.gd: monster lebih galak, hadiah lebih besar)
var _tower_next := false
const LOAD_TIPS := [
	"Ngobrol dengan tiap penduduk desa, kadang mereka menyimpan petunjuk.",
	"Temukan kastil di tiap biome untuk membuka teleport di Peta.",
	"Zona monster sudah dibagi per level. Cari yang cocok denganmu.",
	"Potion bisa diketuk langsung dari tombol di bawah layar.",
	"Skill tree dan gelar ada di menu jeda, bagian Karakter.",
	"Menara Tanpa Ujung dekat desa cocok buat farming level.",
	"Bos kembali setelah beberapa menit, jadi tidak perlu terburu-buru.",
	"Bahan dari monster dipakai di Crafting untuk membuat gear.",
	"Kritikal muncul sebagai angka kuning besar.",
	"Aktifkan Mode hemat di setelan kalau game terasa berat.",
	"Pet kamu ikut menyerang musuh di dekat. Panggil lewat skill job.",
	"Hati-hati bos berlevel jauh di atasmu, damage-mu hampir tidak terasa.",
	"Tugas Warga tersebar di setiap biome, cari tanda seru di atas kepala NPC.",
	"Malam hari kunang-kunang dan kelelawar keluar. Bawa banyak potion.",
	"Pilihan di akhir cerita menentukan nasib Greenwood.",
]
var dungeon = null                 # dungeon yang sedang dimasuki pemain (dungeon.gd) atau null
var _return_pos := Vector2.ZERO    # posisi di dunia terbuka untuk kembali dari dungeon
var _loading: CanvasLayer
var _load_bar: ColorRect
var _load_lbl: Label


func _ready() -> void:
	if not Game.in_game:
		Game.new_game("Petualang", "m")
	world = WorldScript.new()
	world.name = "World"
	add_child(world)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	fx_layer = Node2D.new()
	add_child(fx_layer)
	hud = HudScript.new()
	hud.name = "HUD"
	add_child(hud)

	player = PlayerScene.instantiate()
	var sp: Vector2 = world.spawn_point()
	var saved: Array = Game.p["pos"]
	if saved.size() == 2 and not world.is_solid_at(Vector2(saved[0], saved[1])):
		sp = Vector2(saved[0], saved[1])
	player.position = sp
	entities.add_child(player)
	hud.setup(world, player)
	atmos = AtmosScript.new()
	atmos.name = "Atmosphere"
	add_child(atmos)
	atmos.setup(self, player, world)
	var amb = AmbientScript.new()
	amb.name = "Ambient"
	add_child(amb)
	amb.setup(self, player, world, atmos)
	var glow = GlowScript.new()
	glow.name = "Glow"
	add_child(glow)
	glow.setup(self, player, world, atmos)
	events = EventsScript.new()
	events.name = "WorldEvents"
	add_child(events)
	events.setup(self, player, world, atmos)
	# co-op: klien tidak membuat monster/bos sendiri; semuanya dikirim host (lihat net.gd)
	var is_client: bool = Net.active and not Net.is_host
	Net.on_main_ready(self, entities, player)

	_spawn_npcs()
	if not is_client:
		_spawn_mobs()
	_setup_zones()
	if not is_client:
		_spawn_zone_mobs()
		_spawn_bosses()
		_spawn_expansion_bosses()
		for mi in Bal.MINI.size():
			if world.has_biome(int(Bal.MINI[mi]["biome"])):
				_spawn_mini(mi)
	_spawn_chests()
	_spawn_secret_chests()
	_spawn_checkpoints()
	_spawn_cave_gates()
	_spawn_lore_stones()
	_spawn_journal_pages()
	_carve_trails()
	world.update_collision_ring(player.position, true)
	world.request_around(player.position)
	_lod_update()
	# dunia digambar (bake) per chunk dulu; selama itu permainan ditahan di balik layar loading
	entities.process_mode = Node.PROCESS_MODE_DISABLED
	_build_loading()
	world.baked_all.connect(_on_world_baked)
	if not bool(Game.p["intro"]):
		hud.show_banner("Selamat datang di Greenwood! Temui Tetua Oren", 4.0)


func _process(delta: float) -> void:
	if _loading != null:
		var pr: float = world.bake_progress()
		_load_bar.size.x = 360.0 * pr
		_load_lbl.text = "Memuat dunia... %d%%" % int(pr * 100.0)
	else:
		world.update_collision_ring(player.global_position)
		_portal_check()
		_lod_t -= delta
		if _lod_t <= 0.0:
			_lod_t = 0.25
			_lod_update()
			_zone_check()
	var keep: Array = []
	for r in _respawns:
		r["t"] = float(r["t"]) - delta
		if float(r["t"]) <= 0.0:
			if r.has("zone"):
				_spawn_zone_mob(int(r["zone"]), String(r["kind"]), true)
				continue
			if r.has("mini"):
				_spawn_mini(int(r["mini"]))
				continue
			if r.has("boss"):
				var li: int = int(r["boss"])
				if player.global_position.distance_to(world.lair_center(li)) < 500.0:
					r["t"] = 5.0
					keep.append(r)
				else:
					_spawn_boss(li)
				continue
			if r.has("expansion_boss"):
				var ei: int = int(r["expansion_boss"])
				var ep: Vector2 = world.random_pos_in_biome(int(Bal.EXPANSION_BOSSES[ei]["biome"]))
				if player.global_position.distance_to(ep) < 500.0:
					r["t"] = 5.0
					keep.append(r)
				else:
					_spawn_expansion_boss(ei)
				continue
			var kind: String = String(r["kind"])
			var p: Vector2 = world.random_pos_in_biome(int(r["biome"]), player.global_position, float(MIN_DIST.get(kind, 280.0)))
			spawn_mob(kind, int(r["biome"]), p)
		else:
			keep.append(r)
	_respawns = keep


# ------------------------------------------------------------------ loading & LOD
func _build_loading() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 60
	add_child(_loading)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(bg)
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_CENTER)
	bg.add_child(c)
	var back := ColorRect.new()
	back.color = Color(1, 1, 1, 0.15)
	back.position = Vector2(-182, 20)
	back.size = Vector2(364, 12)
	c.add_child(back)
	_load_bar = ColorRect.new()
	_load_bar.color = Color(0.45, 0.9, 0.45)
	_load_bar.position = Vector2(-180, 22)
	_load_bar.size = Vector2(0, 8)
	c.add_child(_load_bar)
	_load_lbl = Label.new()
	_load_lbl.position = Vector2(-180, -18)
	_load_lbl.size = Vector2(360, 30)
	_load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_load_lbl.add_theme_font_override("font", load("res://assets/fonts/DejaVuSans.ttf"))
	_load_lbl.add_theme_font_size_override("font_size", 18)
	c.add_child(_load_lbl)
	var tip := Label.new()
	tip.position = Vector2(-220, 52)
	tip.size = Vector2(440, 60)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_override("font", load("res://assets/fonts/DejaVuSans.ttf"))
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", Color(0.75, 0.85, 0.7))
	tip.text = "Tips: " + String(LOAD_TIPS[randi() % LOAD_TIPS.size()])
	c.add_child(tip)


func _on_world_baked() -> void:
	entities.process_mode = Node.PROCESS_MODE_INHERIT
	if _loading != null:
		_loading.queue_free()
		_loading = null
	_lod_update()


# Musuh/NPC/peti yang jauh dari pemain dimatikan (tidak diproses, tidak digambar, keluar dari
# fisika). Ini yang menjaga FPS tetap stabil walau dunia berisi ratusan makhluk.
func _lod_update() -> void:
	if player == null:
		return
	var pts: Array = [player.global_position]
	if Net.active and Net.is_host:                  # co-op: monster dekat pemain mana pun tetap aktif
		for g in Net.ghosts.values():
			if is_instance_valid(g):
				pts.append(g.global_position)
	var on_r: float = Perf.active_radius
	var on2: float = on_r * on_r
	var off2: float = (on_r + 60.0) * (on_r + 60.0)
	for n in get_tree().get_nodes_in_group("lod"):
		var d2: float = 1.0e18
		for q in pts:
			d2 = minf(d2, n.global_position.distance_squared_to(q))
		var on: bool = n.process_mode != Node.PROCESS_MODE_DISABLED
		if on and d2 > off2:
			n.process_mode = Node.PROCESS_MODE_DISABLED
			n.visible = false
		elif not on and d2 < on2:
			n.process_mode = Node.PROCESS_MODE_INHERIT
			n.visible = true


# ------------------------------------------------------------------ spawn dunia
func _spawn_npcs() -> void:
	var roles := {"merchant": "shop", "smith": "smith", "healer": "healer", "gacha": "gacha"}
	for r in roles.keys():
		var hs: Dictionary = world.houses[world.house_index(roles[r])]
		_add_npc(String(r), world.find_open(Vector2i(int(hs["x"]) + 2, int(hs["y"]) + 4)))
	_add_npc("elder", world.find_open(world.vil(Vector2i(61, 51))))
	_add_npc("fisher", world.find_open(world.vil(Vector2i(55, 62))))
	_add_npc("miner", world.find_open(world.vil(Vector2i(82, 50))))
	_add_npc("lumber", world.find_open(world.vil(Vector2i(45, 50))))
	if world.world_id == 0:
		# NPC rahasia dengan quest berantai (desa & gurun) + penjaga portal World 2
		_add_npc("marni", world.random_pos_in_biome(5, world.spawn_point(), 1500.0))
		_add_npc("sahar", world.find_open(world.far(Vector2i(101, 52))))
		_add_npc("zahra", world.find_open(world.far(Vector2i(108, 40))))
		_add_npc("gatekeeper", world.find_open(world.portal_cell() + Vector2i(-4, 3)))
		# Kelana Sunyi: pengembara yang pindah biome tiap hari; memberi petunjuk lokasi prasasti kuno
		var wr := RandomNumberGenerator.new()
		wr.seed = int(Game.world_seed) + int(Time.get_unix_time_from_system() / 86400.0) * 31
		wanderer_biome = 1 + int(wr.randi() % 4)
		_add_npc("wanderer", world.random_pos_in_biome(wanderer_biome, world.spawn_point(), 900.0, wr))
	# Saksi Akar: NPC rahasia bernama di tiap biome; muncul hanya setelah syarat tertentu (lihat secrets.gd)
	var sr := RandomNumberGenerator.new()
	sr.seed = int(Game.world_seed) + 4242 + world.world_id * 17
	for wid in Secrets.WITNESS:
		var wb: int = int(Secrets.DATA[wid]["biome"])
		if wid == "w1" and Plot.w1_lost():
			continue
		if world.has_biome(wb):
			_add_npc(String(wid), world.random_pos_in_biome(wb, world.spawn_point(), 700.0, sr))
	# Tugas Warga: satu pemberi tugas bernama di tiap biome (tersebar di seluruh peta)
	var qr := RandomNumberGenerator.new()
	qr.seed = int(Game.world_seed) + 7171 + world.world_id * 13
	for qb in Sidequests.NPC.keys():
		if world.has_biome(int(qb)):
			_add_npc("sq_%d" % int(qb), world.random_pos_in_biome(int(qb), world.spawn_point(), 500.0, qr))
	# Pedagang kastil: satu di gerbang tiap kastil biome (dagangan & harga jual khas biome)
	for ci in world.castles.size():
		var cs: Dictionary = world.castles[ci]
		_add_npc("bm_%d" % int(cs["biome"]), world.find_open(Vector2i(int(cs["x"]) + int(cs["w"]) / 2 + 3, int(cs["y"]) + int(cs["h"]) + 2)))
		# Penghuni kastil: dua penjaga mengapit gerbang, satu ksatria; raja dan putri di kastil pertama
		var gx: int = int(cs["x"]) + int(cs["w"]) / 2
		var gy: int = int(cs["y"]) + int(cs["h"]) + 2
		_add_npc("c_guard", world.find_open(Vector2i(gx - 3, gy)))
		_add_npc("c_guard", world.find_open(Vector2i(gx + 6, gy)))
		_add_npc("c_knight", world.find_open(Vector2i(gx - 6, gy + 2)))
		if ci == 0:
			_add_npc("c_king", world.find_open(Vector2i(gx - 1, gy + 3)))
			_add_npc("c_queen", world.find_open(Vector2i(gx + 3, gy + 3)))
	for i in 10:
		_add_npc("villager", world.random_pos_in_biome(0))
	# Penduduk di tiap perumahan/gubuk luar desa: satu warga per rumah di perumahan, separuh gubuk dihuni.
	var hr := RandomNumberGenerator.new()
	hr.seed = int(Game.world_seed) + 9393 + world.world_id * 11
	for hs2 in world.houses:
		if not hs2.has("biome"):
			continue
		if String(hs2["kind"]) == "hut" and hr.randf() < 0.5:
			continue
		_add_npc("villager", world.find_open(Vector2i(int(hs2["x"]) + 2, int(hs2["y"]) + 5)))
	# Penduduk di desa-desa kecil World 1 dan World 2.
	for b in range(5, 15):
		if not world.has_biome(b):
			continue
		for j in 2:
			_add_npc("villager", world.random_pos_in_biome(b, world.spawn_point(), 900.0))


# Jalan kecil dari jalan utama ke gerbang gua, prasasti, dan tugu jurnal (sebelum dunia di-bake).
func _carve_trails() -> void:
	for n in entities.get_children():
		var sp = n.get_script()
		if sp == null or not (n is Node2D):
			continue
		var pth: String = String(sp.resource_path)
		if pth.ends_with("cave_gate.gd") or pth.ends_with("lore_stone.gd") or pth.ends_with("journal_page.gd"):
			world.carve_trail(n.global_position)
	world.finish_trails()


func _add_npc(role: String, pos: Vector2) -> void:
	var n = NpcScript.new()
	n.role = role
	n.position = pos
	entities.add_child(n)


func _spawn_mobs() -> void:
	for b in MOB_TABLE.keys():
		if not world.has_biome(int(b)):
			continue
		var tbl: Dictionary = MOB_TABLE[b]
		for k in tbl.keys():
			var n: int = int(round(float(tbl[k]) * MOB_DENSITY))
			if EnemyScript.BASE.has(k) and not bool(EnemyScript.BASE[k]["passive"]):
				n = int(round(float(n) * SCATTER_MULT))     # sapi/ayam tetap; monster agresif lebih sedikit & dikumpulkan di zona
			var pack: int = int(PACK.get(k, 1))
			var md: float = float(MIN_DIST.get(k, 160.0))
			var i := 0
			while i < n:
				var base: Vector2 = world.random_pos_in_biome(int(b), world.spawn_point(), md)
				var cnt: int = mini(pack, n - i)
				for j in cnt:
					var p: Vector2 = base
					if j > 0:
						p = base + Vector2.from_angle(randf() * TAU) * randf_range(14.0, 34.0)
						if world.is_solid_at(p):
							p = base
					spawn_mob(String(k), int(b), p)
				i += cnt


func spawn_mob(kind: String, biome_idx: int, pos: Vector2, lv: int = 0, mini_idx: int = -1, mdef: Dictionary = {}):
	# enemy.gd yang terpasang belum punya data jenis ini (mis. wolf/kobold/bat/bear/golem/mummy/centipede): lewati
	if not EnemyScript.BASE.has(kind):
		return null
	var e = EnemyScene.instantiate()
	e.kind = kind
	e.level = lv
	if mini_idx >= 0:                       # harus diisi sebelum add_child (_ready membaca ini)
		var d: Dictionary = Bal.MINI[mini_idx]
		e.is_mini = true
		e.mini_name = String(d["name"])
		e.mini_idx = mini_idx
		e.mini_hp = int(d["hp"])
	if not mdef.is_empty():                  # bos dungeon: seperti mini boss (HP tetap) tapi tanpa respawn
		e.is_mini = true
		e.mini_name = String(mdef["name"])
		e.mini_idx = -1
		e.mini_hp = int(mdef["hp"])
	e.biome_idx = biome_idx
	e.position = pos
	entities.add_child(e)
	return e


func enemy_died(_e, kind: String, biome_idx: int) -> void:
	if _e != null and _e.has_meta("dungeon"):      # monster dungeon tidak hidup lagi (dungeon dibuat baru tiap masuk)
		return
	if _e != null and _e.has_meta("zone"):         # monster zona leveling: respawn cepat di zona yang sama
		_respawns.append({"zone": int(_e.get_meta("zone")), "kind": kind, "t": Bal.ZONE_RESPAWN})
		return
	_respawns.append({"kind": kind, "biome": biome_idx, "t": RESPAWN_SEC})


# Klien: buat "puppet" monster/bos sesuai data dari host (lihat net.gd). Hanya digambar, AI di host.
func net_spawn(info: Dictionary):
	var pos := Vector2(float(info["x"]), float(info["y"]))
	if String(info["t"]) == "boss":
		var b = BossScene.instantiate()
		b.puppet = true
		b.style = String(info["style"])
		b.boss_name = String(info["bname"])
		b.biome_idx = int(info["biome"])
		b.level = int(info["lv"])
		b.max_hp = int(info["mhp"])
		b.dmg = int(info["dmg"])
		b.xp_reward = int(info["xp"])
		b.net_id = int(info["id"])
		b.position = pos
		entities.add_child(b)
		return b
	var kind: String = String(info["kind"])
	if not EnemyScript.BASE.has(kind):
		return null
	var e = EnemyScene.instantiate()
	e.puppet = true
	e.net_id = int(info["id"])
	e.kind = kind
	e.level = int(info["lv"])
	e.biome_idx = int(info["biome"])
	if bool(info["mini"]):
		e.is_mini = true
		e.mini_name = String(info["mname"])
		e.mini_idx = int(info["midx"])
		e.mini_hp = int(info["mhp"])
	e.position = pos
	entities.add_child(e)
	return e


# ------------------------------------------------------------------ zona leveling (lihat Bal.ZONES)
# Cari pusat zona di tempat terbuka (paling banyak sel kosong di sekitarnya) lalu catat sel-selnya.
func _setup_zones() -> void:
	_zone_pos.clear()
	_zone_cells.clear()
	for zi in Bal.ZONES.size():
		var z: Dictionary = Bal.ZONES[zi]
		var b: int = int(z["biome"])
		if not world.has_biome(b):                    # zona milik dunia lain: isi kosong supaya indeks tetap sejajar
			_zone_pos.append(Vector2.ZERO)
			_zone_cells.append([])
			continue
		var rc: int = ceili(Bal.ZONE_RADIUS / float(world.TILE))
		var want: Vector2i = world.CENTER + (z["off"] as Vector2i)
		var lst: Array = world.open_by_biome[b]
		var local: Array = []
		var nearest: Vector2i = want
		var nd := 1.0e9
		for cv in lst:
			var c: Vector2i = cv
			var dd: float = Vector2(c - want).length()
			if dd < nd:
				nd = dd
				nearest = c
			if dd <= 10.0:
				local.append(c)
		if local.is_empty():
			local.append(nearest)
		var best: Vector2i = local[0]
		var best_score := -1.0e9
		var step: int = maxi(1, local.size() / 16)
		var i := 0
		while i < local.size():
			var cand: Vector2i = local[i]
			var cnt := 0
			for cv in local:
				var c2: Vector2i = cv
				if Vector2(c2 - cand).length() <= float(rc):
					cnt += 1
			var score: float = float(cnt) - Vector2(cand - want).length() * 0.5
			if score > best_score:
				best_score = score
				best = cand
			i += step
		var ctr: Vector2 = world.cell_center(best)
		var cells: Array = []
		for cv in lst:
			var c3: Vector2i = cv
			var pc: Vector2 = world.cell_center(c3)
			if pc.distance_to(ctr) > Bal.ZONE_RADIUS:
				continue
			var near_lair := false
			for li in world.LAIRS.size():
				if pc.distance_to(world.lair_center(li)) < 380.0:
					near_lair = true
					break
			if not near_lair:
				cells.append(c3)
		_zone_pos.append(ctr)
		_zone_cells.append(cells)


func _spawn_zone_mobs() -> void:
	for zi in Bal.ZONES.size():
		var mobs: Dictionary = Bal.ZONES[zi]["mobs"]
		for k in mobs.keys():
			for n in int(mobs[k]):
				_spawn_zone_mob(zi, String(k), false)


func _spawn_zone_mob(zi: int, kind: String, avoid_player: bool) -> void:
	var cells: Array = _zone_cells[zi]
	if cells.is_empty():
		return
	var p: Vector2 = world.cell_center(cells[randi() % cells.size()])
	if avoid_player and player != null:             # jangan muncul tepat di depan pemain
		for t in 8:
			if p.distance_to(player.global_position) >= 160.0:
				break
			p = world.cell_center(cells[randi() % cells.size()])
	var e = spawn_mob(kind, int(Bal.ZONES[zi]["biome"]), p, Bal.zone_mob_level(zi, kind))
	if e != null:
		e.set_meta("zone", zi)


# Banner saat pemain masuk zona leveling
func _zone_check() -> void:
	if dungeon != null:
		return
	var pp: Vector2 = player.global_position
	var found := -1
	for zi in _zone_pos.size():
		if (_zone_cells[zi] as Array).is_empty():
			continue
		if pp.distance_to(_zone_pos[zi]) < Bal.ZONE_RADIUS + 40.0:
			found = zi
			break
	if found != _cur_zone:
		_cur_zone = found
		if found >= 0:
			var z: Dictionary = Bal.ZONES[found]
			var lo: int = int(z["lv"][0])
			var pl: int = int(Game.p.get("level", 1))
			var tag := ""
			if pl < int(float(lo) * 0.6):
				tag = "\nSANGAT BERBAHAYA - musuh jauh di atas levelmu!"
			elif pl < int(float(lo) * 0.85):
				tag = "\nBerbahaya - levelmu masih kurang"
			hud.show_banner("Zona Leveling: %s  (Lv %d-%d)%s" % [z["name"], lo, int(z["lv"][1]), tag], 3.5)
	Story.visit(world.biome_at(pp))    # wilayah baru ditemukan (juga tujuan Kisah Utama)


# Mini boss ke-idx (lihat Bal.MINI). Muncul jauh dari desa; hidup lagi setelah MINI_RESPAWN detik.
func _spawn_mini(idx: int) -> void:
	var d: Dictionary = Bal.MINI[idx]
	var p: Vector2 = world.random_pos_in_biome(int(d["biome"]), world.spawn_point(), 900.0)
	spawn_mob(String(d["kind"]), int(d["biome"]), p, int(d["lv"]), idx)


func mini_died(idx: int) -> void:
	if idx < 0:                                    # bos dungeon
		if dungeon != null:
			dungeon.boss_down()
		return
	_respawns.append({"mini": idx, "t": Bal.MINI_RESPAWN})


func _spawn_bosses() -> void:
	for i in world.LAIRS.size():
		_spawn_boss(i)


func _spawn_boss(i: int) -> void:
	var lr: Dictionary = world.LAIRS[i]
	var blv: int = int(Bal.BOSS_LEVEL[i])
	var b = BossScene.instantiate()
	b.style = String(lr["style"])
	b.boss_name = String(lr["name"])
	b.biome_idx = int(lr["biome"])
	b.level = blv
	b.max_hp = int(Bal.BOSS_HP[i])
	b.dmg = Bal.boss_dmg(blv)
	b.speed = float(BOSS_SPD[i])
	b.xp_reward = Bal.boss_xp(blv)
	b.position = world.lair_center(i)
	b.set_meta("lair", i)
	entities.add_child(b)
	_boss_nodes.append(b)


func _spawn_expansion_bosses() -> void:
	for i in Bal.EXPANSION_BOSSES.size():
		if world.has_biome(int(Bal.EXPANSION_BOSSES[i]["biome"])):
			_spawn_expansion_boss(i)


func _spawn_expansion_boss(i: int) -> void:
	var data: Dictionary = Bal.EXPANSION_BOSSES[i]
	var b = BossScene.instantiate()
	b.style = String(data["style"])
	b.boss_name = String(data["name"])
	b.biome_idx = int(data["biome"])
	b.level = int(data["lv"])
	b.max_hp = int(data["hp"])
	b.dmg = int(float(Bal.boss_dmg(b.level)) * 0.25)
	b.speed = 48.0
	b.xp_reward = Bal.boss_xp(b.level)
	b.position = world.random_pos_in_biome(b.biome_idx, world.spawn_point(), 1800.0)
	b.set_meta("expansion_boss", i)
	entities.add_child(b)
	_boss_nodes.append(b)


# Bos hidup lagi di sarangnya setelah RESPAWN_SEC detik (tunggu bila pemain masih di dekat sarang)
func boss_died(b) -> void:
	if b != null and b.has_meta("lair"):
		_respawns.append({"boss": int(b.get_meta("lair")), "t": RESPAWN_SEC})
	elif b != null and b.has_meta("expansion_boss"):
		_respawns.append({"expansion_boss": int(b.get_meta("expansion_boss")), "t": RESPAWN_SEC})


func _spawn_chests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Game.world_seed) + 99 + world.world_id * 31
	var uid := 0
	for b in CHESTS_PER_BIOME.size():
		for i in int(CHESTS_PER_BIOME[b]):
			var this_uid: int = uid                    # penomoran tetap stabil walau biome tidak ada di dunia ini
			uid += 1
			if not world.has_biome(b):
				continue
			var c = ChestScript.new()
			c.uid = this_uid + world.world_id * 5000   # uid peti tiap dunia terpisah (satu daftar peti terbuka per save)
			c.biome_idx = b
			c.opened = Game.chests_opened.has(c.uid)
			c.position = world.random_pos_in_biome(b, world.spawn_point(), 120.0, rng)
			entities.add_child(c)


# Peti rahasia muncul setelah rangkaian quest NPC rahasia selesai (tersimpan di save)
func _spawn_secret_chests() -> void:
	if world.world_id != 0:                    # peti rahasia hanya ada di World 1
		return
	for id in Secrets.DATA.keys():
		if Secrets.DATA[id].has("chest") and Secrets.finished(id):
			spawn_secret_chest(String(id), false)


func spawn_secret_chest(id: String, fresh: bool) -> void:
	var uid: int = 1000 + Secrets.DATA.keys().find(id)
	var c = ChestScript.new()
	c.uid = uid
	c.secret = id
	c.biome_idx = 2 if id != "marni" else 0
	c.opened = Game.chests_opened.has(uid)
	var sc: Vector2i = Secrets.DATA[id]["chest"]["cell"]
	c.position = world.find_open(world.vil(sc) if id == "marni" else world.far(sc))
	entities.add_child(c)
	if fresh:
		fx_burst(c.position, Color(0.8, 0.55, 1.0), 14, 60.0, 0.8, -20.0, 2.0, "star")


func _spawn_checkpoints() -> void:
	var cells: Array = []
	if world.world_id == 0:
		cells = [world.vil(Vector2i(63, 51)), world.far(Vector2i(32, 47)), world.far(Vector2i(22, 47)), world.far(Vector2i(96, 47)), world.far(Vector2i(106, 47)), world.far(Vector2i(63, 28)), world.far(Vector2i(63, 21)), world.far(Vector2i(63, 68)), world.far(Vector2i(63, 76))]
		# api unggun tambahan di tiap biome ekspansi World 1 (jalan utama menuju pusat tiap irisan)
		var ap: Array = world._anchor_points()
		for k in ap.size() - 1:                       # elemen terakhir = portal
			cells.append(ap[k])
	else:
		cells = [world.vil(Vector2i(63, 51))]
		cells.append_array(world._anchor_points())
	var base_uid: int = 0 if world.world_id == 0 else 100
	for i in cells.size():
		var c = CheckpointScript.new()
		c.uid = base_uid + i
		c.active = Game.checkpoints.has(c.uid)
		c.position = world.find_open(cells[i])
		entities.add_child(c)


# ------------------------------------------------------------------ portal antar dunia
var _portal_hint_ms := 0


func _portal_check() -> void:
	if player == null or world == null or (Net.active and not Net.is_host):
		return
	if player.global_position.distance_to(world.portal_pos()) > 56.0:
		return
	var to_w2: bool = world.world_id == 0
	if Input.is_action_just_pressed("interact"):
		if Net.active:
			hud.show_banner("Portal tidak bisa dipakai saat co-op", 2.5)
		elif to_w2 and int(Game.p["level"]) < 200:
			hud.show_banner("Portal World 2 butuh Level 200 (kamu Lv %d)" % int(Game.p["level"]), 3.0)
		else:
			Game.switch_world(1 if to_w2 else 0)
		return
	if Time.get_ticks_msec() - _portal_hint_ms > 3000:
		_portal_hint_ms = Time.get_ticks_msec()
		hud.show_banner("Tekan E untuk masuk ke %s" % ("World 2" if to_w2 else "World 1"), 2.0)


# ------------------------------------------------------------------ prasasti kuno
func _spawn_lore_stones() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Game.world_seed) + 4242 + world.world_id * 97
	for sd in Lore.STONES:
		if not world.has_biome(int(sd["biome"])):
			continue    # prasasti biome ini ada di dunia lain
		var s = LoreStoneScript.new()
		s.stone_id = String(sd["id"])
		s.biome = int(sd["biome"])
		s.position = world.random_pos_in_biome(int(sd["biome"]), world.spawn_point(), 700.0, rng)
		entities.add_child(s)


# Tugu Jurnal Aldric: satu per biome dunia ini, posisinya tetap per dunia (seed). Lihat journal.gd.
func _spawn_journal_pages() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Game.world_seed) + 9157 + world.world_id * 131
	for pd in Journal.pages_of(world):
		var b: int = int(pd["biome"])
		var pg = JournalPageScript.new()
		pg.page_id = String(pd["id"])
		pg.biome = b
		pg.world = world
		pg.position = world.random_pos_in_biome(b, world.spawn_point(), 700.0, rng)
		entities.add_child(pg)


# Petunjuk arah ke prasasti yang belum dibaca terdekat (dipakai Kelana Sunyi). Kosong = semua sudah terbaca.
func lore_hint(from: Vector2) -> String:
	var best = null
	var bd := 1.0e18
	for s in get_tree().get_nodes_in_group("lore"):
		if Lore.found(String(s.stone_id)):
			continue
		var d: float = from.distance_to(s.global_position)
		if d < bd:
			bd = d
			best = s
	if best == null:
		return ""
	var v: Vector2 = best.global_position - from
	var dirs := ["timur", "tenggara", "selatan", "barat daya", "barat", "barat laut", "utara", "timur laut"]
	var di: int = int(roundf(fposmod(atan2(v.y, v.x), TAU) / (TAU / 8.0))) % 8
	return "Ada prasasti yang belum kau baca di %s, ke arah %s, sekitar %d langkah dari sini." % [String(world.BNAMES[int(best.biome)]), String(dirs[di]), int(bd / 32.0)]


func wanderer_rumor() -> String:
	if wanderer_biome < 0:
		return "Belum ada kabar baru, Nak."
	return "Kudengar Kelana Sunyi, si pengembara, terlihat di %s hari ini. Ia tahu banyak soal prasasti kuno." % String(world.BNAMES[wanderer_biome])


# ------------------------------------------------------------------ dungeon (gua)
# Mulut gua: satu per biome (1-14, tiap gua unik), posisi tetap per dunia. Lihat cave_gate.gd & dungeon.gd.
func _spawn_cave_gates() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Game.world_seed) + 777 + world.world_id * 53
	for did in DungeonScript.ORDER:
		var d: Dictionary = DungeonScript.DEFS[did]
		if not world.has_biome(int(d["biome"])):
			continue                                     # gua ini milik biome dunia lain
		var g = CaveGateScript.new()
		g.dungeon_id = String(did)
		g.position = world.random_pos_in_biome(int(d["biome"]), world.spawn_point(), 900.0, rng)
		entities.add_child(g)
	if world.has_biome(1):                              # Menara Tanpa Ujung: dekat desa, hanya di dunia 1
		var tg = CaveGateScript.new()
		tg.dungeon_id = "menara"
		tg.position = world.random_pos_in_biome(1, world.spawn_point(), 560.0, rng)
		entities.add_child(tg)
		var rg = CaveGateScript.new()
		rg.dungeon_id = "rush"
		rg.position = world.random_pos_in_biome(1, world.spawn_point(), 640.0, rng)
		entities.add_child(rg)


# Menara Tanpa Ujung: keluar lalu masuk lagi dengan lantai berikutnya (tower_cur sudah diatur dungeon.gd)
func dungeon_next() -> void:
	dungeon_leave()
	_tower_next = true
	dungeon_enter("menara")
	_tower_next = false


func dungeon_enter(did: String) -> void:
	if did == "menara" and not _tower_next:
		Game.p["tower_cur"] = int(Game.p.get("tower", 0)) + 1
	if dungeon != null or player == null or player.dead or not DungeonScript.DEFS.has(did):
		return
	if Net.active:
		hud.show_banner("Gua tidak bisa dipakai saat co-op", 2.5)
		return
	_return_pos = player.global_position
	Game.p["pos"] = [_return_pos.x, _return_pos.y]       # kalau game ditutup di dalam gua, muncul lagi di mulut gua
	var d = DungeonScript.new()
	d.id = did
	dungeon = d
	add_child(d)
	move_child(d, entities.get_index())                  # digambar di bawah entity
	d.build(player)
	world.set_meta("in_dungeon", true)
	world.set_meta("dungeon_node", d)
	world.set_meta("dungeon_name", String(d.def["name"]))
	player.global_position = d.start_pos()
	player.cam.limit_left = int(d.rect.position.x)
	player.cam.limit_top = int(d.rect.position.y)
	player.cam.limit_right = int(d.rect.end.x)
	player.cam.limit_bottom = int(d.rect.end.y)
	player.cam.reset_smoothing()
	Audio.sfx("checkpoint")
	hud.show_banner("%s  (disarankan Lv %d+)" % [String(d.def["name"]), int(d.def["rec"])], 3.5)


# died = true: dipanggil player._respawn (posisi diatur oleh respawn sendiri)
func dungeon_leave(died: bool = false) -> void:
	if dungeon == null:
		return
	var d = dungeon
	dungeon = null
	d.cleanup()
	d.queue_free()
	for k in ["in_dungeon", "dungeon_node", "dungeon_name"]:
		if world.has_meta(k):
			world.remove_meta(k)
	var ws: Vector2 = world.world_size()
	player.cam.limit_left = 0
	player.cam.limit_top = 0
	player.cam.limit_right = int(ws.x)
	player.cam.limit_bottom = int(ws.y)
	if died:
		return
	player.global_position = _return_pos
	player.cam.reset_smoothing()
	player._region = -1
	world.update_collision_ring(_return_pos, true)
	world.request_around(_return_pos)
	_lod_update()
	Audio.sfx("checkpoint")


func dungeon_abort() -> void:
	dungeon_leave(true)


# ------------------------------------------------------------------ pickup
func spawn_pickup(kind: String, pos: Vector2, amount: int = 1) -> void:
	var p = PickupScene.instantiate()
	p.kind = kind
	p.amount = amount
	p.position = pos
	entities.add_child(p)


# ------------------------------------------------------------------ efek
func _fx(kind: String, pos: Vector2, life: float):
	var f = FX.new()
	f.kind = kind
	f.life = life
	f.position = pos
	return f


func _fx_full(extra: int = 0) -> bool:
	return fx_layer.get_child_count() >= Perf.fx_cap + extra


func fx_burst(pos: Vector2, color: Color, n: int, speed: float, life: float, grav: float = 0.0, size: float = 2.0, shape: String = "dot") -> void:
	if _fx_full():
		return
	var f = _fx("burst", pos, life)
	f.col = color
	f.count = maxi(int(float(n) * Perf.fx_scale), 2)
	f.speed = speed
	f.grav = grav
	f.size = size
	f.shape = shape
	fx_layer.add_child(f)


func fx_text(pos: Vector2, text: String, color: Color, size: float = 13.0) -> void:
	if _fx_full(16):
		return
	var f = _fx("text", pos, 0.9)
	f.text = text
	f.col = color
	f.size = size
	fx_layer.add_child(f)


func fx_ring(pos: Vector2, radius: float, color: Color, life: float) -> void:
	if _fx_full(8):
		return
	var f = _fx("ring", pos, life)
	f.radius = radius
	f.col = color
	fx_layer.add_child(f)


func fx_tele(pos: Vector2, radius: float, color: Color, life: float) -> void:
	var f = _fx("tele", pos, life)
	f.radius = radius
	f.col = color
	fx_layer.add_child(f)


func fx_slash(pos: Vector2, angle: float, radius: float, color: Color) -> void:
	if _fx_full(8):
		return
	var f = _fx("slash", pos, 0.22)
	f.radius = radius
	f.ang = angle
	f.col = color
	fx_layer.add_child(f)


func fx_bolt(a: Vector2, b: Vector2, color: Color) -> void:
	if _fx_full(8):
		return
	var f = _fx("bolt", Vector2.ZERO, 0.25)
	var pts := PackedVector2Array()
	var n := 6
	for i in n + 1:
		var u: float = float(i) / n
		var p: Vector2 = a.lerp(b, u)
		if i != 0 and i != n:
			p += Vector2(randf_range(-7, 7), randf_range(-7, 7))
		pts.append(p)
	f.pts = pts
	f.col = color
	fx_layer.add_child(f)
	Audio.sfx("bolt", 1.4)
