extends RefCounted
# Gambar prosedural (tanpa file gambar): karakter beranimasi lengan/kaki, monster, bos,
# senjata, ikon item, bangunan. Semua fungsi static, dipanggil dari _draw() node.

static var _tex_cache := {}
const HOUSE_SPR := {"smith": "smith", "shop": "tavern", "healer": "green", "gacha": "mill"}
const HOUSE_VARIANTS := ["red", "blue", "thatch", "blue", "manor"]

# ---- sprite PNG (assets/sprites). Kalau file tidak ada, semua fungsi jatuh balik ke gambar kode.
const SPR_DIR := "res://assets/sprites/"
const WALK := [1, 0, 1, 2]      # urutan kolom langkah sprite 3 kolom (kiri, diam, kanan)
# skin -> [sprite laki-laki, sprite perempuan]  (file h_<id>.png)
const SKIN_SPR := {
	"skin_default": ["m01", "f01"],
	"mecha_r": ["m02", "f02"], "mecha_sr": ["s01", "s01"], "mecha_ssr": ["m09", "f24"],
	"sam_r": ["m16", "f22"], "sam_sr": ["m17", "f09"], "sam_ssr": ["m06", "f06"],
	"st_r": ["m14", "f03"], "st_sr": ["m18", "f10"], "st_ssr": ["m15", "f07"],
}
const BIOME_TINT := {
	"forest": Color(1, 1, 1), "desert": Color(1.0, 0.92, 0.7),
	"snow": Color(0.78, 0.9, 1.0), "volcano": Color(1.0, 0.62, 0.5),
}
# jenis musuh -> sprite. f = nama file (atau per biome), s = skala, fly = melayang, tint = warna per biome
const MOB_SPR := {
	"slime": {"f": {"forest": "death_slime", "desert": "ochre_jelly", "snow": "ochre_jelly", "volcano": "ochre_jelly"}, "s": 2.0, "tint": true},
	"bee": {"f": "bloodshot_eye", "s": 1.6, "fly": true, "tint": true},
	"fiend": {"f": "mob_fiend", "s": 1.0},
	"wisp": {"f": {"forest": "mob_ghost_forest", "desert": "mob_ghost_desert", "snow": "mob_ghost_snow", "volcano": "mob_ghost_volcano"}, "s": 1.0, "fly": true},
	"goblin": {"f": "mob_goblin", "s": 1.0, "tint": true},
	"ogre": {"f": "brawny_ogre", "s": 2.8, "tint": true},
	"red_ogre": {"f": "stone_troll", "s": 3.2, "color": Color(1.0, 0.6, 0.5)},
}


static func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


# Path sheet sprite manusia (96x128: 3 kolom langkah x 4 baris arah bawah/kiri/kanan/atas)
static func _human_sheet(o: Dictionary) -> String:
	if o.has("sprite_id"):
		return SPR_DIR + "h_" + String(o["sprite_id"]) + ".png"
	var sk: Dictionary = o["skin"]
	var pair: Array = SKIN_SPR.get(String(sk.get("id", "skin_default")), SKIN_SPR["skin_default"])
	var idx: int = 1 if String(o["gender"]) == "f" else 0
	return SPR_DIR + "h_" + String(pair[idx]) + ".png"


static func _human_sprite(ci: CanvasItem, stx: Texture2D, o: Dictionary, dir: int, flip: bool, mv: bool, ph: float, bob: float, held: Dictionary, hand: Vector2, wa: float, t: float, base: Transform2D, sc: float) -> void:
	var row: int = 0
	if dir == 1:
		row = 3
	elif dir == 2:
		row = 1 if flip else 2
	var col: int = 1
	if mv:
		col = int(WALK[posmod(int(ph / 1.8), 4)])
	if dir == 1 and not held.is_empty():
		draw_held(ci, held, hand, wa, t, base)
	var off: Vector2 = o.get("offset", Vector2.ZERO)
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(sc, sc), 0.0, off))
	ci.draw_texture_rect_region(stx, Rect2(-16.0, -22.0 + bob, 32.0, 32.0), Rect2(col * 32, row * 32, 32, 32))
	if dir != 1 and not held.is_empty():
		draw_held(ci, held, hand, wa, t, base)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


# Sheet musuh baru (assets/sprites/m_*.png, hasil tools/gen_mob_sprites.py): sel 64x64, 7 kolom x 2 baris.
# Kolom 0 = depan, 5 = belakang, 6 = samping (menghadap kanan). Baris = 2 pose langkah.
# side = punya sprite samping yang bagus; fly = melayang; tint = diwarnai per biome
const MOB_SHEET := {
	"spider": {"f": "m_spider"},
	"slime": {"f": "m_slime", "tint": true},
	"goblin": {"f": "m_goblin", "side": true},
	"ogre": {"f": "m_ogre", "side": true},
	"red_ogre": {"f": "m_red_ogre", "side": true},
	"fiend": {"f": "m_fiend"},
	"wisp": {"f": "m_whip", "fly": true},
	"cow": {"f": "m_cow"},
	"chicken": {"f": "m_chicken", "side": true},
	"bee": {"f": "m_bee", "fly": true, "flap": true},
}


static func _mob_sheet(ci: CanvasItem, o: Dictionary, spec: Dictionary, tx: Texture2D, biome: String, t: float, mv: bool, atk: float) -> void:
	var sc: float = 1.0 + atk * 0.12
	var col := Color.WHITE
	if bool(spec.get("tint", false)):
		col = BIOME_TINT.get(biome, Color.WHITE)
	if bool(o.get("rage", false)):
		col = Color(1.0, 0.45, 0.4)
	if bool(o.get("stun", false)):
		col = col.darkened(0.3)
	var lift: float = 0.0
	if bool(spec.get("fly", false)):
		lift = sin(t * 3.0) * 2.0 - 5.0
	var vel: Vector2 = o.get("vel", Vector2.ZERO)
	var c: int = 0
	var r: int = 0
	if mv:
		r = int(t * 6.0) % 2
		if absf(vel.y) > absf(vel.x) * 1.1:
			c = 5 if vel.y < 0.0 else 0
		elif bool(spec.get("side", false)):
			c = 6
	else:
		r = int(t * 1.6) % 2
	if bool(spec.get("flap", false)):
		r = int(t * 9.0) % 2          # lebah selalu mengepak
	var w: float = 64.0 * sc
	ci.draw_texture_rect_region(tx, Rect2(-w / 2.0, 11.0 - 61.0 * sc + lift, w, w), Rect2(c * 64, r * 64, 64, 64), col)


# ---- Musuh PNG buatan sendiri (assets/mobs/<jenis>.png, mini boss: mini_<jenis>.png) ----
# Strip horizontal: lebar = jumlah frame x tinggi (frame persegi). Walk cepat saat bergerak, pelan saat diam.
# Saat menyerang dipakai strip assets/mobs_baru/strips/<nama>_attack.png (atau attack1 untuk mini boss) kalau ada.
# size = ukuran gambar di layar (px), fly = melayang
const MOB_NEW := {
	"wolf": {"size": 30.0},
	"kobold": {"size": 28.0},
	"bat": {"size": 28.0, "fly": true},
	"bear": {"size": 40.0},
	"golem": {"size": 44.0},
	"mummy": {"size": 32.0},
	"centipede": {"size": 34.0},
}
# Gambar khusus per jenis monster (kind asli, bukan archetype): strip assets/mobs/<src>.png
# (hasil tools/slice_mob_sheets.py; frame persegi, lebar = jumlah frame x tinggi). Dipilih lewat o["skind"].
const MOB_SKIN := {
	"abyss_eel": {"src": "deep_serpent", "size": 44.0},
	"deep_maw": {"src": "void_angler", "size": 52.0},
	"trench_horror": {"src": "abyssal_guardian", "size": 66.0},
	"blackfin_stalker": {"src": "ocean_shade", "size": 42.0, "fly": true},
	"void_jelly": {"src": "tidal_horror", "size": 42.0, "fly": true},
	"drowned_mummy": {"src": "tide_wraith", "size": 48.0},
	"thorn_sprite": {"src": "forest_sprite", "size": 45.0},
	"mossback_bear": {"src": "woodland_stalker", "size": 60.0},
	"elder_treantling": {"src": "treantling", "size": 66.0},
	"briar_goblin": {"src": "dryad_archer", "size": 42.0},
	"bloom_wisp": {"src": "nature_wisp", "size": 42.0, "fly": true},
	"rootbound_ogre": {"src": "ent_guardian", "size": 63.0},
	"ether_drake": {"src": "aether_drake", "size": 30.0},
	"cloud_wisp": {"src": "void_wisp", "size": 28.0, "fly": true},
	"aether_manta": {"src": "cloud_manta", "size": 28.0, "fly": true},
	"prism_golem": {"src": "ether_crystal_golem", "size": 44.0},
	"sky_kobold": {"src": "mist_dancer", "size": 28.0},
	"starved_harpy": {"src": "sky_harrier", "size": 30.0},
	"ruins_sentinel": {"src": "bone_golem", "size": 66.0},
	"forgotten_knight": {"src": "dark_knight", "size": 42.0},
	"dust_revenant": {"src": "zombie", "size": 48.0},
	"relic_scorpion": {"src": "death_hound", "size": 51.0},
	"lost_archer": {"src": "skeleton_archer", "size": 42.0},
	"ancient_mummy": {"src": "undead_soldier", "size": 48.0},
	"lumin_ray": {"src": "manta_ray", "size": 28.0, "fly": true},
	"reef_guardian": {"src": "crystal_crab", "size": 44.0},
	"pearl_wisp": {"src": "bubble_wisp", "size": 28.0, "fly": true},
	"coral_stalker": {"src": "coral_crab", "size": 30.0},
	"tide_serpent": {"src": "sea_serpent", "size": 30.0},
	"glow_jelly": {"src": "glow_jellyfish", "size": 26.0},
	"petal_fox": {"src": "petal_kitsune", "size": 45.0},
	"sakura_moth": {"src": "bloom_moth", "size": 42.0, "fly": true},
	"crimson_koi": {"src": "petal_serpent", "size": 45.0},
	"blossom_spider": {"src": "petal_assassin", "size": 45.0},
	"pink_warden": {"src": "sakura_golem", "size": 66.0},
	"fallen_ronin": {"src": "sakura_ronin", "size": 42.0},
	"sporeling": {"src": "mushroom_slime", "size": 39.0},
	"mushroom_brute": {"src": "toad_warrior", "size": 63.0},
	"myco_shaman": {"src": "toad_shaman", "size": 42.0, "fly": true},
	"toxic_toad": {"src": "poison_shroom", "size": 45.0},
	"cap_guardian": {"src": "fungus_golem", "size": 66.0},
	"fungal_bat": {"src": "fungal_bat", "size": 42.0, "fly": true},
	"umbral_slime": {"src": "void_shade", "size": 39.0},
	"gloomfang_wolf": {"src": "gloom_hound", "size": 45.0},
	"shade_stalker": {"src": "shadow_stalker", "size": 45.0},
	"dusk_bat": {"src": "nightfang", "size": 42.0, "fly": true},
	"night_kobold": {"src": "fallen_knight", "size": 42.0},
	"eclipse_spider": {"src": "shade_spider", "size": 45.0},
	"hollow_wisp": {"src": "error_specter", "size": 42.0, "fly": true},
	"gravebound_ogre": {"src": "fragment_guardian", "size": 63.0},
	"ashen_fiend": {"src": "lost_sentinel", "size": 45.0},
	"rift_serpent": {"src": "glitch_serpent", "size": 45.0},
	"null_crawler": {"src": "void_crawler", "size": 51.0},
	"glitch_golem": {"src": "null_golem", "size": 66.0},
	"verdan_stag": {"src": "verdant_stalker", "size": 30.0},
	"canopy_hunter": {"src": "forest_wolf", "size": 28.0},
	"elder_boar": {"src": "thorn_boar", "size": 40.0},
	"vine_strangler": {"src": "carnivorous_plant", "size": 34.0},
	"pollen_sprite": {"src": "wood_sprite", "size": 28.0, "fly": true},
	"grove_colossus": {"src": "ancient_treant", "size": 46.0},
	"abyssal_slime": {"src": "abyssal_slime", "size": 40.0},
	"abyssal_crab": {"src": "abyssal_crab", "size": 44.0},
	"leviathan_larva": {"src": "leviathan_larva", "size": 52.0},
	"sea_siren": {"src": "sea_siren", "size": 44.0},
	"coral_golem": {"src": "coral_golem", "size": 66.0},
	"depth_reaper": {"src": "depth_reaper", "size": 44.0},
	"krakenling": {"src": "krakenling", "size": 44.0},
	"reef_golem": {"src": "reef_golem", "size": 66.0},
	"abyssal_archer": {"src": "abyssal_archer", "size": 42.0},
	"sea_drake": {"src": "sea_drake", "size": 42.0, "fly": true},
	"pearl_guardian": {"src": "pearl_guardian", "size": 66.0},
	"oceanic_horror": {"src": "oceanic_horror", "size": 64.0},
	"abyssal_colossus": {"src": "abyssal_colossus", "size": 68.0},
	"trident_warden": {"src": "trident_warden", "size": 64.0},
	"bloom_slime": {"src": "bloom_slime", "size": 39.0},
	"petal_pixie": {"src": "petal_pixie", "size": 42.0, "fly": true},
	"thorn_spider": {"src": "thorn_spider", "size": 45.0},
	"moss_golem": {"src": "moss_golem", "size": 66.0},
	"fey_knight": {"src": "fey_knight", "size": 42.0},
	"moon_deer": {"src": "moon_deer", "size": 45.0},
	"forest_mage": {"src": "forest_mage", "size": 42.0, "fly": true},
	"vine_crawler": {"src": "vine_crawler", "size": 45.0},
	"spore_moth": {"src": "spore_moth", "size": 42.0, "fly": true},
	"root_horror": {"src": "root_horror", "size": 63.0},
	"fungal_walker": {"src": "fungal_walker", "size": 48.0},
	"ancient_spirit": {"src": "ancient_spirit", "size": 42.0, "fly": true},
	"verdant_colossus": {"src": "verdant_colossus", "size": 69.0},
	"sylvan_beast": {"src": "sylvan_beast", "size": 45.0},
	"dusk_wraith": {"src": "dusk_wraith", "size": 42.0, "fly": true},
	"umbral_archer": {"src": "umbral_archer", "size": 42.0},
	"cursed_knight": {"src": "cursed_knight", "size": 42.0},
	"shadow_brute": {"src": "shadow_brute", "size": 63.0},
	"shadow_soul_reaper": {"src": "shadow_soul_reaper", "size": 45.0},
	"ethereal_wisp": {"src": "ethereal_wisp", "size": 42.0, "fly": true},
	"dark_mage": {"src": "dark_mage", "size": 42.0},
	"revenant": {"src": "revenant", "size": 42.0},
	"royal_executor": {"src": "royal_executor", "size": 69.0},
	"voidling": {"src": "voidling", "size": 39.0},
	"glitch_mite": {"src": "glitch_mite", "size": 45.0},
	"rift_mimic": {"src": "rift_mimic", "size": 66.0},
	"corrupted_drone": {"src": "corrupted_drone", "size": 42.0, "fly": true},
	"glitch_knight": {"src": "glitch_knight", "size": 42.0},
	"dimensional_wraith": {"src": "dimensional_wraith", "size": 42.0, "fly": true},
	"pixel_swarm": {"src": "pixel_swarm", "size": 39.0},
	"data_sentinel": {"src": "data_sentinel", "size": 66.0},
	"void_leviathan": {"src": "void_leviathan", "size": 69.0},
	"verdant_sporeling": {"src": "verdant_sporeling", "size": 26.0},
	"verdant_mushroom_brute": {"src": "verdant_mushroom_brute", "size": 42.0},
	"myconid_mage": {"src": "myconid_mage", "size": 28.0},
	"toadstool_guard": {"src": "toadstool_guard", "size": 28.0},
	"fungal_stalker": {"src": "fungal_stalker", "size": 30.0},
	"kings_spore": {"src": "kings_spore", "size": 26.0},
	"verdant_moss_golem": {"src": "verdant_moss_golem", "size": 44.0},
	"fungal_giant": {"src": "fungal_giant", "size": 42.0},
	"verdant_ent": {"src": "verdant_ent", "size": 44.0},
	"spore_queen": {"src": "spore_queen", "size": 46.0},
	"cherry_oni": {"src": "cherry_oni", "size": 63.0},
	"blossom_spirit": {"src": "blossom_spirit", "size": 42.0, "fly": true},
	"red_crane": {"src": "red_crane", "size": 42.0, "fly": true},
	"sakura_spirit": {"src": "sakura_spirit", "size": 42.0, "fly": true},
	"sakura_archer": {"src": "sakura_archer", "size": 42.0},
	"sakura_oni_warrior": {"src": "sakura_oni_warrior", "size": 63.0},
	"fallen_hanami": {"src": "fallen_hanami", "size": 42.0, "fly": true},
	"sakura_beast": {"src": "sakura_beast", "size": 45.0},
	"flower_wisp": {"src": "flower_wisp", "size": 42.0, "fly": true},
	"blossom_guardian": {"src": "blossom_guardian", "size": 66.0},
	"shrine_guard": {"src": "shrine_guard", "size": 63.0},
	"cherry_dragon": {"src": "cherry_dragon", "size": 69.0},
	"sakura_mage": {"src": "sakura_mage", "size": 42.0},
	"divine_sakura": {"src": "divine_sakura", "size": 69.0},
	"spore_shooter": {"src": "spore_shooter", "size": 42.0},
	"myco_spider": {"src": "myco_spider", "size": 45.0},
	"mushroom_mage": {"src": "mushroom_mage", "size": 42.0},
	"shroom_archer": {"src": "shroom_archer", "size": 42.0},
	"cap_knight": {"src": "cap_knight", "size": 42.0},
	"mushroom_beast": {"src": "mushroom_beast", "size": 60.0},
	"spore_wisp": {"src": "spore_wisp", "size": 28.0, "fly": true},
	"toadstool_golem": {"src": "toadstool_golem", "size": 66.0},
	"mushroom_drone": {"src": "mushroom_drone", "size": 42.0, "fly": true},
	"fungus_hydra": {"src": "fungus_hydra", "size": 51.0},
	"spore_knight": {"src": "spore_knight", "size": 42.0},
	"giant_mushroom": {"src": "giant_mushroom", "size": 63.0},
	"royal_mushroom": {"src": "royal_mushroom", "size": 69.0},
	"mushroom_overlord": {"src": "mushroom_overlord", "size": 69.0},
	"wind_colossus": {"src": "wind_colossus", "size": 46.0},
	"arcane_golem": {"src": "arcane_golem", "size": 44.0},
	"rune_sentinel": {"src": "rune_sentinel", "size": 44.0},
	"ether_elemental": {"src": "ether_elemental", "size": 28.0, "fly": true},
	"crystal_wraith": {"src": "crystal_wraith", "size": 30.0},
	"shadow_herald": {"src": "shadow_herald", "size": 30.0},
	"soul_reaver": {"src": "soul_reaver", "size": 30.0},
	"void_spider": {"src": "void_spider", "size": 30.0},
	"ether_shooter": {"src": "ether_shooter", "size": 28.0, "fly": true},
	"dream_stalker": {"src": "dream_stalker", "size": 30.0},
	"fallen_sorcerer": {"src": "fallen_sorcerer", "size": 28.0},
	"rift_guardian": {"src": "rift_guardian", "size": 42.0},
	"astral_shade": {"src": "astral_shade", "size": 28.0, "fly": true},
	"nebula_gazer": {"src": "nebula_gazer", "size": 28.0, "fly": true},
	"grave_warden": {"src": "grave_warden", "size": 42.0},
	"void_archon": {"src": "void_archon", "size": 46.0},
	"ether_lord": {"src": "ether_lord", "size": 42.0},
	"the_aether_colossus": {"src": "the_aether_colossus", "size": 46.0},
	"ghost": {"src": "ghost", "size": 42.0, "fly": true},
	"lich_mage": {"src": "lich_mage", "size": 42.0},
	"wraith": {"src": "wraith", "size": 42.0, "fly": true},
	"cursed_armor": {"src": "cursed_armor", "size": 42.0},
	"grave_slime": {"src": "grave_slime", "size": 39.0},
	"necro_bat": {"src": "necro_bat", "size": 42.0, "fly": true},
	"grave_guardian": {"src": "grave_guardian", "size": 66.0},
	"phantom_knight": {"src": "phantom_knight", "size": 42.0},
	"soul_reaper": {"src": "soul_reaper", "size": 45.0},
	"specter": {"src": "specter", "size": 42.0, "fly": true},
	"bone_dragon": {"src": "bone_dragon", "size": 69.0},
	"death_mage": {"src": "death_mage", "size": 42.0},
	"lost_spirit": {"src": "lost_spirit", "size": 42.0, "fly": true},
	"the_forgotten_king": {"src": "the_forgotten_king", "size": 69.0},
	"reef_fish": {"src": "reef_fish", "size": 42.0, "fly": true},
	"violet_fish": {"src": "violet_fish", "size": 42.0, "fly": true},
	"angler_fish": {"src": "angler_fish", "size": 45.0},
	"reef_perch": {"src": "reef_perch", "size": 42.0, "fly": true},
	"armored_coral_crab": {"src": "armored_coral_crab", "size": 30.0},
	"magma_coral_crab": {"src": "magma_coral_crab", "size": 30.0},
	"crystal_coral": {"src": "crystal_coral", "size": 44.0},
	"sea_urchin": {"src": "sea_urchin", "size": 26.0},
	"pufferfish": {"src": "pufferfish", "size": 26.0},
	"bubble_polyp": {"src": "bubble_polyp", "size": 28.0, "fly": true},
	"pearl_slug": {"src": "pearl_slug", "size": 26.0},
	"seahorse": {"src": "seahorse", "size": 28.0, "fly": true},
	"striped_reef_fish": {"src": "striped_reef_fish", "size": 28.0, "fly": true},
	"violet_piranha": {"src": "violet_piranha", "size": 28.0, "fly": true},
	"kelp_spirit": {"src": "kelp_spirit", "size": 30.0},
	"pink_jelly": {"src": "pink_jelly", "size": 28.0, "fly": true},
	"shard_imp": {"src": "shard_imp", "size": 28.0},
	"clam_mimic": {"src": "clam_mimic", "size": 26.0},
	"bubble_imp": {"src": "bubble_imp", "size": 28.0, "fly": true},
	"shard_minnow": {"src": "shard_minnow", "size": 28.0, "fly": true},
	"lumin_jelly": {"src": "lumin_jelly", "size": 28.0, "fly": true},
	"reef_stalker": {"src": "reef_stalker", "size": 28.0, "fly": true},
	"coral_hydra": {"src": "coral_hydra", "size": 30.0},
	"pearl_siren": {"src": "pearl_siren", "size": 28.0, "fly": true},
	"tide_warden": {"src": "tide_warden", "size": 44.0},
	"radiant_leviathan": {"src": "radiant_leviathan", "size": 46.0},
	"crystal_golem": {"src": "crystal_golem", "size": 66.0},
	"crystal_slime": {"src": "crystal_slime", "size": 39.0},
	"gem_bat": {"src": "gem_bat", "size": 42.0, "fly": true},
	"crystal_archer": {"src": "crystal_archer", "size": 42.0},
	"crystal_mage": {"src": "crystal_mage", "size": 42.0, "fly": true},
	"rock_elemental": {"src": "rock_elemental", "size": 66.0},
	"crystal_spider": {"src": "crystal_spider", "size": 45.0},
	"shard_wraith": {"src": "shard_wraith", "size": 42.0, "fly": true},
	"crystal_serpent": {"src": "crystal_serpent", "size": 45.0},
	"ice_crystal_knight": {"src": "ice_crystal_knight", "size": 42.0},
	"crystal_beast": {"src": "crystal_beast", "size": 45.0},
	"prism_guardian": {"src": "prism_guardian", "size": 66.0},
	"crystal_demon": {"src": "crystal_demon", "size": 45.0},
	"crystal_drone": {"src": "crystal_drone", "size": 42.0, "fly": true},
	"frost_wisp": {"src": "frost_wisp", "size": 42.0, "fly": true},
	"crystal_hydra": {"src": "crystal_hydra", "size": 51.0},
	"shard_golem": {"src": "shard_golem", "size": 66.0},
	"crystal_reaper": {"src": "crystal_reaper", "size": 45.0},
	"diamond_colossus": {"src": "diamond_colossus", "size": 69.0},
	"crystal_overlord": {"src": "crystal_overlord", "size": 63.0},
}
const MOB_STRIP_DIR := "res://assets/mobs/"
const MOB_ATK_DIR := "res://assets/mobs_baru/strips/"


static func _mob_new(ci: CanvasItem, o: Dictionary, kind: String, t: float, mv: bool, atk: float) -> bool:
	var sk: String = String(o.get("skind", ""))
	var spec: Dictionary
	var sname: String = kind
	if MOB_SKIN.has(sk):
		spec = MOB_SKIN[sk]
		sname = String(spec["src"])
	elif MOB_NEW.has(kind):
		spec = MOB_NEW[kind]
	else:
		return false
	var mini: bool = bool(o.get("mini", false))
	var nm: String = ("mini_" + sname) if mini else sname
	var tx: Texture2D = tex(MOB_STRIP_DIR + nm + ".png")
	if tx == null:
		if not mini:
			return false
		nm = sname
		tx = tex(MOB_STRIP_DIR + nm + ".png")
		if tx == null:
			return false
	var frame_w: int = tx.get_height()
	var n: int = maxi(tx.get_width() / maxi(frame_w, 1), 1)
	var f: int = 0
	if mv:
		f = posmod(int(t * 8.0), n)
	else:
		f = posmod(int(t * 2.0), n)
	# animasi serang (kalau file strip serangnya ada)
	if atk > 0.05:
		var atx: Texture2D = tex(MOB_ATK_DIR + nm + ("_attack1.png" if mini else "_attack.png"))
		if atx != null:
			tx = atx
			frame_w = atx.get_height()
			n = maxi(atx.get_width() / maxi(frame_w, 1), 1)
			f = clampi(int(atk * float(n)), 0, n - 1)
	var col := Color.WHITE
	if bool(o.get("rage", false)):
		col = Color(1.0, 0.45, 0.4)
	if bool(o.get("stun", false)):
		col = col.darkened(0.3)
	var lift: float = 0.0
	if bool(spec.get("fly", false)):
		lift = sin(t * 3.0) * 2.0 - 5.0
	var w: float = float(spec["size"]) * (1.0 + atk * 0.12)
	ci.draw_texture_rect_region(tx, Rect2(-w / 2.0, 11.0 - w + lift, w, w), Rect2(f * frame_w, 0, frame_w, frame_w), col)
	return true


# Gambar musuh dari sprite. true = berhasil (sprite ada), false = pakai gambar kode lama.
static func _mob_sprite(ci: CanvasItem, o: Dictionary, kind: String, biome: String, t: float, mv: bool, atk: float) -> bool:
	if _mob_new(ci, o, kind, t, mv, atk):
		return true
	if MOB_SHEET.has(kind):
		var ms: Dictionary = MOB_SHEET[kind]
		var mt: Texture2D = tex(SPR_DIR + String(ms["f"]) + ".png")
		if mt != null:
			_mob_sheet(ci, o, ms, mt, biome, t, mv, atk)
			return true
	if not MOB_SPR.has(kind):
		return false
	var spec: Dictionary = MOB_SPR[kind]
	var f = spec["f"]
	var fname: String = ""
	if f is Dictionary:
		fname = String(f.get(biome, f["forest"]))
	else:
		fname = String(f)
	var tx: Texture2D = tex(SPR_DIR + fname + ".png")
	if tx == null:
		return false
	var sc: float = float(spec["s"]) * (1.0 + atk * 0.12)
	var col := Color.WHITE
	if bool(spec.get("tint", false)):
		col = BIOME_TINT.get(biome, Color.WHITE)
	if spec.has("color"):
		col = spec["color"]
	if bool(o.get("rage", false)):
		col = Color(1.0, 0.45, 0.4)
	if bool(o.get("stun", false)):
		col = col.darkened(0.3)
	var lift: float = 0.0
	if bool(spec.get("fly", false)):
		lift = sin(t * 3.0) * 2.0 - 5.0
	var src := Rect2(0, 0, 16, 16)
	var size: float = 16.0
	if tx.get_width() > 64:
		# sheet 96x128: baris 2 = menghadap kanan (dibalik oleh skala 'face' di draw_mob)
		var c: int = 1
		if mv:
			c = int(WALK[posmod(int(t * 7.0), 4)])
		src = Rect2(c * 32, 64, 32, 32)
		size = 32.0
	else:
		src = Rect2(posmod(int(t * 6.0), 4) * 16, 0, 16, 16)
	var w: float = size * sc
	ci.draw_texture_rect_region(tx, Rect2(-w / 2.0, 11.0 - w + lift, w, w), src, col)
	return true


# ---- pahlawan (skin default): atlas animasi hasil tools/gen_hero_sprites.py ----------------
# Tiap animasi: fps + loop (berulang) atau satu-kali berdasarkan progres u (0..1). "frames" = urutan frame
# yang dipakai dari baris atlas (boleh subset). Sprite menghadap KANAN; kiri = dibalik.
const HeroSprites = preload("res://scripts/hero_sprites.gd")
const HERO_ANIM := {
	"idle": {"fps": 5.0, "loop": true},
	"walk": {"fps": 9.0, "loop": true},
	"run": {"fps": 12.0, "loop": true},
	"ready": {"as": "idle", "fps": 3.0, "loop": true, "frames": [1, 2, 1, 2]},   # sikap siaga setelah menyerang
	"attack1": {},                                                                 # tebasan
	"attack2": {},                                                                 # tebasan berat
	"attack3": {},                                                                 # putaran
	"special": {"as": "attack3"},                                                  # sihir / busur (memakai gerak putaran)
	"hurt": {"frames": [0, 1, 2, 3]},
	"knock": {"as": "hurt", "frames": [0, 1, 2, 3, 4]},
	"death": {},
}


static func hero_ready() -> bool:
	return tex(HeroSprites.FILE) != null


# Arah hadap 4 penjuru untuk atlas pahlawan (down / left / right / up).
static func hero_dir(face: Vector2) -> String:
	if absf(face.x) > absf(face.y):
		return "left" if face.x < 0.0 else "right"
	return "up" if face.y < 0.0 else "down"


# Gambar satu frame pahlawan di titik (0,0)=pusat badan (kaki di y=+10). true = berhasil.
# Atlas baru sudah punya sprite kiri & kanan, jadi tidak perlu dibalik (parameter flip dipertahankan
# supaya pemanggil lama tetap jalan). face = arah hadap pemain.
static func draw_hero(ci: CanvasItem, anim: String, u: float, t: float, _flip: bool, face: Vector2 = Vector2.DOWN) -> bool:
	var tx: Texture2D = tex(HeroSprites.FILE)
	var cfg: Dictionary = HERO_ANIM.get(anim, {})
	var src_anim: String = String(cfg.get("as", anim))
	if tx == null or not HeroSprites.ANIMS.has(src_anim):
		return false
	var info: Array = HeroSprites.ANIMS[src_anim]
	var seq: Array = []
	if cfg.has("frames"):
		seq = cfg["frames"]
	else:
		for k in int(info[1]):
			seq.append(k)
	var n: int = seq.size()
	var f: int = 0
	if bool(cfg.get("loop", false)):
		f = int(t * float(cfg.get("fps", 8.0))) % n
	else:
		f = mini(int(clampf(u, 0.0, 1.0) * float(n)), n - 1)
	var cell: int = HeroSprites.CELL
	var row: int = int(info[0]) * 4 + int(HeroSprites.DIRS[hero_dir(face)])
	var src := Rect2(int(seq[f]) * cell, row * cell, cell, cell)
	ci.draw_texture_rect_region(tx, Rect2(-HeroSprites.AXIS_X, 10.0 - HeroSprites.FOOT_Y, cell, cell), src)
	return true


# ------------------------------------------------------------------ gerak badan pahlawan (untuk armor & senjata)
# Armor/senjata digambar terpisah dari sprite badan, jadi tidak ikut naik-turun saat jalan. Fungsi ini membaca atlas
# pahlawan sekali (tinggi puncak sprite tiap frame) dan mengembalikan geseran badan frame sekarang terhadap rata-rata
# animasinya, supaya armor/senjata bisa digeser sama persis. Hanya untuk idle/jalan/lari (gerak serang tidak dihitung).
static var _hero_img: Image = null
static var _hero_top := {}      # row*256+kolom -> y puncak sprite dalam sel (-1 = tidak ada)
static var _hero_mean := {}     # kunci anim -> rata-rata y puncak


static func _hero_frame_top(tx: Texture2D, row: int, col: int) -> float:
	var key: int = row * 256 + col
	if _hero_top.has(key):
		return float(_hero_top[key])
	if _hero_img == null:
		_hero_img = tx.get_image()
		if _hero_img != null and _hero_img.is_compressed():
			_hero_img.decompress()
	var v := -1.0
	if _hero_img != null:
		var cell: int = HeroSprites.CELL
		var r := Rect2i(col * cell, row * cell, cell, cell)
		if Rect2i(Vector2i.ZERO, _hero_img.get_size()).encloses(r):
			var used: Rect2i = _hero_img.get_region(r).get_used_rect()
			if used.size.y > 0:
				v = float(used.position.y)
	_hero_top[key] = v
	return v


static func hero_body_offset(anim: String, _u: float, t: float, face: Vector2) -> Vector2:
	if anim != "walk" and anim != "run" and anim != "idle" and anim != "ready":
		return Vector2.ZERO
	var tx: Texture2D = tex(HeroSprites.FILE)
	var cfg: Dictionary = HERO_ANIM.get(anim, {})
	var src_anim: String = String(cfg.get("as", anim))
	if tx == null or not HeroSprites.ANIMS.has(src_anim):
		return Vector2.ZERO
	var info: Array = HeroSprites.ANIMS[src_anim]
	var seq: Array = []
	if cfg.has("frames"):
		seq = cfg["frames"]
	else:
		for k in int(info[1]):
			seq.append(k)
	var n: int = seq.size()
	if n == 0:
		return Vector2.ZERO
	var row: int = int(info[0]) * 4 + int(HeroSprites.DIRS[hero_dir(face)])
	var mkey: String = "%s:%d" % [anim, row]
	if not _hero_mean.has(mkey):
		var sum := 0.0
		var cnt := 0
		for c in seq:
			var tp: float = _hero_frame_top(tx, row, int(c))
			if tp >= 0.0:
				sum += tp
				cnt += 1
		_hero_mean[mkey] = sum / float(cnt) if cnt > 0 else -1.0
	var mean: float = float(_hero_mean[mkey])
	var f: int = int(t * float(cfg.get("fps", 8.0))) % n
	var top: float = _hero_frame_top(tx, row, int(seq[f]))
	if mean < 0.0 or top < 0.0:
		return Vector2.ZERO
	return Vector2(0.0, clampf(top - mean, -3.0, 3.0))


# ---- Armor ikut gerak waktu menyerang / kena hit / mati
# Untuk gerak selain jalan-diam, geseran badan dihitung dari "jangkar kepala" tiap frame: titik tengah (median x) dan y
# baris pertama yang cukup lebar (>= 7 piksel, jadi ujung pedang yang tipis tidak ikut terhitung), dibanding rata-rata
# pose diam arah yang sama. Hasil di-cache per frame (dipindai sekali saja).
static var _hero_head := {}         # row*256+kolom -> Vector2(x, y) jangkar kepala dalam sel (-1,-1 = kosong)
static var _hero_idle_head := {}    # indeks arah -> rata-rata jangkar pose diam


static func _hero_frame_head(tx: Texture2D, row: int, col: int) -> Vector2:
	var key: int = row * 256 + col
	if _hero_head.has(key):
		return _hero_head[key]
	var v := Vector2(-1.0, -1.0)
	_hero_frame_top(tx, row, col)          # memastikan atlas sudah termuat (_hero_img)
	if _hero_img != null:
		var cell: int = HeroSprites.CELL
		var ox: int = col * cell
		var oy: int = row * cell
		var isz: Vector2i = _hero_img.get_size()
		if ox + cell <= isz.x and oy + cell <= isz.y:
			var top := -1
			for y in cell:
				var cnt := 0
				for x in cell:
					if _hero_img.get_pixel(ox + x, oy + y).a > 0.5:
						cnt += 1
				if cnt >= 7:
					top = y
					break
			if top >= 0:
				var xs: Array = []
				for y in range(top, mini(top + 8, cell)):
					for x in cell:
						if _hero_img.get_pixel(ox + x, oy + y).a > 0.5:
							xs.append(x)
				if not xs.is_empty():
					xs.sort()
					v = Vector2(float(xs[xs.size() / 2]), float(top))
	_hero_head[key] = v
	return v


static func _hero_idle_anchor(tx: Texture2D, dir_idx: int) -> Vector2:
	if _hero_idle_head.has(dir_idx):
		return _hero_idle_head[dir_idx]
	var info: Array = HeroSprites.ANIMS["idle"]
	var row: int = int(info[0]) * 4 + dir_idx
	var sum := Vector2.ZERO
	var n := 0
	for c in int(info[1]):
		var h: Vector2 = _hero_frame_head(tx, row, c)
		if h.x >= 0.0:
			sum += h
			n += 1
	var m := Vector2(-1.0, -1.0)
	if n > 0:
		m = sum / float(n)
	_hero_idle_head[dir_idx] = m
	return m


# Geseran armor (piksel layar, tidak perlu dibalik kiri/kanan karena atlas punya sprite kiri & kanan).
# Jalan/lari/diam memakai hero_body_offset; serang / sihir / kena hit / knockback / mati mengikuti jangkar kepala.
static func hero_armor_offset(anim: String, u: float, t: float, face: Vector2) -> Vector2:
	if anim == "walk" or anim == "run" or anim == "idle" or anim == "ready":
		return hero_body_offset(anim, u, t, face)
	var tx: Texture2D = tex(HeroSprites.FILE)
	var cfg: Dictionary = HERO_ANIM.get(anim, {})
	var src_anim: String = String(cfg.get("as", anim))
	if tx == null or not HeroSprites.ANIMS.has(src_anim):
		return Vector2.ZERO
	var info: Array = HeroSprites.ANIMS[src_anim]
	var seq: Array = []
	if cfg.has("frames"):
		seq = cfg["frames"]
	else:
		for k in int(info[1]):
			seq.append(k)
	var n: int = seq.size()
	if n == 0:
		return Vector2.ZERO
	var f: int = mini(int(clampf(u, 0.0, 1.0) * float(n)), n - 1)
	var dir_idx: int = int(HeroSprites.DIRS[hero_dir(face)])
	var row: int = int(info[0]) * 4 + dir_idx
	var h: Vector2 = _hero_frame_head(tx, row, int(seq[f]))
	var m: Vector2 = _hero_idle_anchor(tx, dir_idx)
	if h.x < 0.0 or m.x < 0.0:
		return Vector2.ZERO
	var lim: float = 26.0 if anim == "death" else 9.0
	return Vector2(clampf(h.x - m.x, -lim, lim), clampf(h.y - m.y, -lim, lim))


static func rect(ci: CanvasItem, x: float, y: float, w: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(x, y, w, h), col)


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, segs: int = 16) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var a: float = TAU * float(i) / float(segs)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)


static func shadow(ci: CanvasItem, y: float, r: float) -> void:
	ci.draw_set_transform(Vector2(0, y), 0.0, Vector2(1.0, 0.4))
	ci.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.3))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ================================================================== MANUSIA
# o: dir(0 bawah,1 atas,2 samping) flip t phase moving gender skin(dict) held(dict) weapon_ang arm_target
#    chest_c legs_c boots_c gloves_c shield_c
static func draw_human(ci: CanvasItem, o: Dictionary) -> void:
	var dir: int = int(o["dir"])
	var flip: bool = bool(o.get("flip", false))
	var t: float = float(o["t"])
	var ph: float = float(o["phase"])
	var mv: bool = bool(o["moving"])
	var fem: bool = String(o["gender"]) == "f"
	var sk: Dictionary = o["skin"]
	var theme: String = String(sk["theme"])
	var c1: Color = sk["c1"]
	var c2: Color = sk["c2"]
	var c3: Color = sk["c3"]
	var rar: int = int(sk["rarity"])
	var swing: float = sin(ph) if mv else 0.0
	var bob: float = (-absf(sin(ph)) * 1.4) if mv else sin(t * 2.2) * 0.5

	var skin_c := Color(0.97, 0.79, 0.65)
	var hair_c := Color(0.62, 0.33, 0.14)
	if fem:
		hair_c = Color(0.92, 0.72, 0.3)
	var torso_c: Color = c1
	var legs_c := Color(0.35, 0.27, 0.2)
	var boot_c := Color(0.3, 0.2, 0.12)
	var glove_c: Color = skin_c
	var belt_c := Color(0.35, 0.22, 0.1)
	match theme:
		"mecha":
			legs_c = c1.darkened(0.2)
			boot_c = c2
			glove_c = c2
			belt_c = c2
		"samurai":
			legs_c = c1.darkened(0.25)
			boot_c = Color(0.18, 0.14, 0.12)
			glove_c = c2
			belt_c = c3
		"street":
			legs_c = Color(0.24, 0.3, 0.5)
			boot_c = Color(0.95, 0.95, 0.97)
			belt_c = c2
	var sleeve_c: Color = torso_c
	if o.has("chest_c"):
		torso_c = o["chest_c"]
		sleeve_c = torso_c
	if o.has("legs_c"):
		legs_c = o["legs_c"]
	if o.has("boots_c"):
		boot_c = o["boots_c"]
	if o.has("gloves_c"):
		glove_c = o["gloves_c"]
	var has_shield: bool = o.has("shield_c")

	var sc: float = float(o.get("scale", 1.0))
	var base := Transform2D(0.0, Vector2((-1.0 if flip else 1.0) * sc, sc), 0.0, o.get("offset", Vector2.ZERO))
	ci.draw_set_transform_matrix(base)

	# ---- pose lengan
	var sh_a := Vector2.ZERO
	var sh_b := Vector2.ZERO
	var hand_a := Vector2.ZERO
	var hand_b := Vector2.ZERO
	var idle: float = sin(t * 2.2) * 0.5
	if dir == 2:
		sh_a = Vector2(0.5, -3.0 + bob)
		sh_b = sh_a
		var aa: float = swing * 0.95
		hand_a = sh_a + Vector2(sin(aa) * 7.5, cos(aa) * 7.5)
		hand_b = sh_b + Vector2(-sin(aa) * 7.5, cos(aa) * 7.5)
	else:
		sh_a = Vector2(5.5, -3.0 + bob)
		sh_b = Vector2(-5.5, -3.0 + bob)
		hand_a = sh_a + Vector2(0.8, 7.5 - swing * 2.4 + idle)
		hand_b = sh_b + Vector2(-0.8, 7.5 + swing * 2.4 - idle)
	if o.has("arm_target"):
		var tv: Vector2 = o["arm_target"]
		if flip:
			tv.x = -tv.x
		hand_a = sh_a + tv
	var wa: float = float(o.get("weapon_ang", PI / 2.0))
	if flip:
		wa = PI - wa
	var held: Dictionary = o.get("held", {})

	# ---- sprite PNG (kalau ada); gambar kode di bawah hanya jadi cadangan
	var stx: Texture2D = tex(_human_sheet(o))
	if stx != null:
		_human_sprite(ci, stx, o, dir, flip, mv, ph, bob, held, hand_a, wa, t, base, sc)
		return

	if dir == 1 and not held.is_empty():
		draw_held(ci, held, hand_a, wa, t, base)
	# ---- perisai di punggung (samping/belakang)
	if has_shield and dir != 0:
		_shield(ci, Vector2(-3.5 if dir == 2 else 0.0, -0.5 + bob), o["shield_c"], 0.8 if dir == 2 else 1.0)
	# ---- kaki
	var leg_top: float = 3.0 + bob
	var lw: float = 4.0 if theme == "samurai" else 3.0
	if dir == 2:
		for k in 2:
			var front: bool = k == 1
			var lx: float = (swing * 3.2 if front else -swing * 3.2) - lw / 2.0
			var lift: float = maxf(swing if front else -swing, 0.0) * 2.2
			var bot: float = 10.0 - lift
			rect(ci, lx, leg_top, lw, bot - leg_top, legs_c.darkened(0.12) if not front else legs_c)
			rect(ci, lx - 0.5, bot - 3.0, lw + 1.5, 3.0, boot_c)
			if theme == "street":
				rect(ci, lx - 0.5, bot - 1.0, lw + 1.5, 1.0, c2)
	else:
		for k in 2:
			var sg: float = -1.0 if k == 0 else 1.0
			var lift2: float = maxf(swing * sg, 0.0) * 2.5
			var lx2: float = sg * 2.6 - lw / 2.0
			var bot2: float = 10.0 - lift2
			rect(ci, lx2, leg_top, lw, bot2 - leg_top, legs_c)
			rect(ci, lx2 - 0.5, bot2 - 3.0, lw + 1.0, 3.0, boot_c)
			if theme == "mecha":
				rect(ci, lx2, leg_top + 3.0, lw, 1.0, c3)
			elif theme == "street":
				rect(ci, lx2 - 0.5, bot2 - 1.0, lw + 1.0, 1.0, c2)
	# ---- lengan jauh (samping)
	if dir == 2:
		_arm(ci, sh_b, hand_b, sleeve_c.darkened(0.15), glove_c.darkened(0.1))
	# ---- badan
	var tw: float = 10.0 if dir != 2 else 7.0
	var tx: float = -tw / 2.0
	var ol_c := Color(0.16, 0.1, 0.12)
	rect(ci, tx - 0.8, -5.8 + bob, tw + 1.6, 10.6, ol_c)
	rect(ci, tx, -5.0 + bob, tw, 9.0, torso_c)
	rect(ci, tx, -5.0 + bob, tw, 1.5, torso_c.lightened(0.18))
	rect(ci, tx, 2.0 + bob, tw, 2.0, torso_c.darkened(0.22))
	if fem and theme != "mecha":
		var sw: float = 6.5 if dir != 2 else 5.0
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(-tw / 2.0, 2.0 + bob), Vector2(tw / 2.0, 2.0 + bob),
			Vector2(sw, 6.5 + bob + absf(swing) * 0.5), Vector2(-sw, 6.5 + bob + absf(swing) * 0.5)]),
			torso_c.darkened(0.12) if not o.has("legs_c") else legs_c)
	rect(ci, tx, 2.0 + bob, tw, 1.0, belt_c)
	match theme:
		"mecha":
			var pulse: float = 0.6 + 0.4 * sin(t * 4.0)
			if dir == 0:
				ci.draw_circle(Vector2(0, -1.0 + bob), 2.6, Color(c3.r, c3.g, c3.b, 0.35 * pulse))
				ci.draw_circle(Vector2(0, -1.0 + bob), 1.5, c3)
				rect(ci, -4.0, -4.0 + bob, 8.0, 1.0, c2)
			elif dir == 2:
				ci.draw_circle(Vector2(1.5, -1.0 + bob), 1.4, c3)
			else:
				rect(ci, -2.0, -4.0 + bob, 4.0, 5.0, c2)
			if dir != 2:
				rect(ci, -8.0, -5.0 + bob, 3.5, 3.0, c2)
				rect(ci, 4.5, -5.0 + bob, 3.5, 3.0, c2)
		"samurai":
			if dir != 2:
				rect(ci, -8.5, -5.0 + bob, 4.0, 3.5, c2)
				rect(ci, 4.5, -5.0 + bob, 4.0, 3.5, c2)
				ci.draw_line(Vector2(-4, -4 + bob), Vector2(4, 2 + bob), c3, 1.0)
				ci.draw_line(Vector2(4, -4 + bob), Vector2(-4, 2 + bob), c3, 1.0)
			else:
				rect(ci, -2.0, -5.0 + bob, 4.0, 3.5, c2)
			rect(ci, tx, 2.5 + bob, tw, 1.5, c3)
		"street":
			rect(ci, tx + 1.0, -5.0 + bob, tw - 2.0, 2.0, c2)
			if dir == 0:
				ci.draw_line(Vector2(-1.5, -3 + bob), Vector2(-1.5, 0 + bob), Color.WHITE, 1.0)
				ci.draw_line(Vector2(1.5, -3 + bob), Vector2(1.5, 0 + bob), Color.WHITE, 1.0)
				rect(ci, -3.0, 0.0 + bob, 6.0, 2.0, torso_c.darkened(0.2))
				if rar >= 3:
					for i in 5:
						ci.draw_circle(Vector2(-2.0 + i, -2.5 + bob + absf(i - 2.0) * 0.4), 0.6, Color(1.0, 0.85, 0.2))
		_:
			rect(ci, tx + 2.0, -5.0 + bob, tw - 4.0, 1.5, c2)
			if dir != 1:
				rect(ci, -1.0, 2.0 + bob, 2.0, 1.0, Color(1.0, 0.85, 0.3))
	if o.has("chest_c") and dir != 2:
		rect(ci, -8.0, -5.0 + bob, 3.0, 3.0, torso_c.lightened(0.25))
		rect(ci, 5.0, -5.0 + bob, 3.0, 3.0, torso_c.lightened(0.25))
	if theme == "samurai" and dir != 1:
		# katana di pinggang
		ci.draw_line(Vector2(-4.5, 2.0 + bob), Vector2(-9.0, 7.5 + bob), Color(0.15, 0.12, 0.12), 1.6)

	# ---- kepala (chibi: lebih besar, outline, mata berkilau)
	var hy: float = -13.5 + bob
	var face_c: Color = skin_c
	if theme == "mecha":
		face_c = c1
	rect(ci, -5.3, hy - 1.8, 10.6, 11.0, ol_c)
	if fem and theme != "mecha" and dir != 2:
		rect(ci, -6.6, hy - 0.8, 4.0, 13.0, ol_c)
		rect(ci, 2.6, hy - 0.8, 4.0, 13.0, ol_c)
	rect(ci, -4.5, hy, 9.0, 8.5, face_c)
	if theme != "mecha":
		rect(ci, -4.5, hy + 7.0, 9.0, 1.5, face_c.darkened(0.12))
		# rambut
		if dir == 0:
			rect(ci, -4.8, hy - 1.2, 9.6, 3.6, hair_c)
			rect(ci, -4.8, hy, 1.8, 5.5, hair_c)
			rect(ci, 3.0, hy, 1.8, 5.5, hair_c)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-3.0, hy + 2.2), Vector2(-0.5, hy + 2.2), Vector2(-2.2, hy + 4.4)]), hair_c)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0.5, hy + 2.2), Vector2(3.0, hy + 2.2), Vector2(1.2, hy + 4.2)]), hair_c)
			rect(ci, -3.5, hy - 1.0, 4.0, 1.0, hair_c.lightened(0.3))
			if theme == "adv":
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-3.5, hy - 1.2), Vector2(-2.0, hy - 4.0), Vector2(-0.8, hy - 1.2)]), hair_c)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-1.0, hy - 1.2), Vector2(0.8, hy - 4.8), Vector2(2.2, hy - 1.2)]), hair_c)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(1.8, hy - 1.2), Vector2(3.6, hy - 3.6), Vector2(4.4, hy - 1.0)]), hair_c)
			if fem:
				rect(ci, -5.8, hy, 2.4, 11.5, hair_c)
				rect(ci, 3.4, hy, 2.4, 11.5, hair_c)
		elif dir == 1:
			rect(ci, -4.8, hy - 1.2, 9.6, 9.8, hair_c)
			rect(ci, -2.5, hy + 1.0, 5.0, 1.2, hair_c.lightened(0.25))
			if fem:
				rect(ci, -5.3, hy, 10.6, 12.5, hair_c)
		else:
			rect(ci, -4.8, hy - 1.2, 9.6, 3.6, hair_c)
			rect(ci, -4.8, hy, 5.2, 8.5, hair_c)
			rect(ci, -3.5, hy - 1.0, 4.0, 1.0, hair_c.lightened(0.3))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0.0, hy + 2.0), Vector2(4.2, hy + 2.0), Vector2(1.5, hy + 4.0)]), hair_c)
			if fem:
				rect(ci, -8.0, hy + 3.0 + sin(t * 4.0 + ph) * 0.8, 4.0, 8.0, hair_c)
	# wajah
	var eye_c := Color(0.12, 0.2, 0.5)
	if dir == 0:
		if theme != "mecha":
			for ex: float in [-3.3, 1.1]:
				rect(ci, ex, hy + 3.4, 2.2, 3.0, Color(0.08, 0.08, 0.14))
				rect(ci, ex + 0.3, hy + 4.0, 1.6, 2.2, eye_c.lightened(0.15))
				rect(ci, ex + 0.3, hy + 3.7, 0.9, 0.9, Color.WHITE)
			rect(ci, -0.5, hy + 6.8, 1.0, 0.7, Color(0.75, 0.32, 0.3))
			rect(ci, -4.0, hy + 5.6, 1.6, 1.0, Color(1.0, 0.55, 0.55, 0.65))
			rect(ci, 2.4, hy + 5.6, 1.6, 1.0, Color(1.0, 0.55, 0.55, 0.65))
	elif dir == 2:
		if theme != "mecha":
			rect(ci, 1.2, hy + 3.4, 2.4, 3.0, Color(0.08, 0.08, 0.14))
			rect(ci, 1.6, hy + 4.0, 1.7, 2.2, eye_c.lightened(0.15))
			rect(ci, 1.6, hy + 3.7, 0.9, 0.9, Color.WHITE)
			rect(ci, 2.9, hy + 6.8, 1.2, 0.7, Color(0.75, 0.32, 0.3))
	# atribut tema di kepala
	match theme:
		"mecha":
			var vis: Color = c3
			if dir == 0:
				rect(ci, -3.5, hy + 3.0, 7.0, 2.4, vis)
			elif dir == 2:
				rect(ci, 0.5, hy + 3.0, 4.0, 2.4, vis)
			rect(ci, -4.5, hy - 1.5, 9.0, 2.5, c1.lightened(0.2))
			ci.draw_line(Vector2(3, hy - 1.5), Vector2(4.5, hy - 5.5), c2, 1.0)
			ci.draw_circle(Vector2(4.5, hy - 5.5), 1.0, c3)
		"samurai":
			rect(ci, -5.0, hy - 2.5, 10.0, 3.5, c2.darkened(0.3) if rar > 1 else c2)
			rect(ci, -5.5, hy + 0.5, 1.5, 3.0, c2)
			rect(ci, 4.0, hy + 0.5, 1.5, 3.0, c2)
			ci.draw_line(Vector2(0, hy - 2.5), Vector2(-4.5, hy - 7.0), c3, 1.5)
			ci.draw_line(Vector2(0, hy - 2.5), Vector2(4.5, hy - 7.0), c3, 1.5)
			if rar >= 3:
				ci.draw_circle(Vector2(0, hy - 1.0), 1.2, Color(1.0, 0.3, 0.3))
		"street":
			rect(ci, -4.8, hy - 2.0, 9.6, 3.5, c2)
			if dir == 0:
				rect(ci, -4.8, hy + 1.2, 9.6, 1.2, c2.darkened(0.25))
			elif dir == 2:
				rect(ci, 2.0, hy + 1.2, 6.0, 1.2, c2.darkened(0.25))
			if rar >= 2:
				rect(ci, -6.0, hy + 2.0, 1.8, 4.0, c3)
				rect(ci, 4.2, hy + 2.0, 1.8, 4.0, c3)
			if rar >= 3 and dir == 0:
				rect(ci, -3.8, hy + 3.2, 7.6, 2.2, Color(0.05, 0.05, 0.08))
		_:
			if fem and dir == 0:
				rect(ci, 2.0, hy - 1.5, 3.0, 2.0, c2)   # pita
	# ---- lengan dekat + perisai depan
	if dir == 2:
		_arm(ci, sh_a, hand_a, sleeve_c, glove_c)
	else:
		_arm(ci, sh_b, hand_b, sleeve_c, glove_c)
		_arm(ci, sh_a, hand_a, sleeve_c, glove_c)
		if has_shield and dir == 0:
			_shield(ci, hand_b + Vector2(-2.0, -2.5), o["shield_c"], 1.0)
	if dir != 1 and not held.is_empty():
		draw_held(ci, held, hand_a, wa, t, base)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _arm(ci: CanvasItem, sh: Vector2, hand: Vector2, sleeve: Color, glove: Color) -> void:
	ci.draw_line(sh, hand, glove, 3.0)
	ci.draw_line(sh, sh + (hand - sh) * 0.62, sleeve, 3.4)
	rect(ci, hand.x - 1.8, hand.y - 1.5, 3.6, 3.2, glove)


static func _shield(ci: CanvasItem, c: Vector2, col: Color, s: float) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-4, -5) * s, c + Vector2(4, -5) * s, c + Vector2(4, 1) * s,
		c + Vector2(0, 6) * s, c + Vector2(-4, 1) * s])
	ci.draw_colored_polygon(pts, col.darkened(0.15))
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), col.lightened(0.35), 1.0)
	ci.draw_circle(c + Vector2(0, -0.5) * s, 1.6 * s, col.lightened(0.4))


# ================================================================== SENJATA DI TANGAN
static func draw_held(ci: CanvasItem, held: Dictionary, hand: Vector2, ang: float, t: float, base: Transform2D) -> void:
	if held.has("gi"):
		Gear.draw_held(ci, String(held["gsheet"]), int(held["gi"]), hand, ang, base, float(held.get("hl", 28.0)))
		return
	var kind: String = String(held["kind"])
	if kind == "sword":
		draw_sword(ci, held["data"], hand, ang, t, base)
	elif kind == "staff":
		var st: Texture2D = held["tex"]
		if st:
			ci.draw_set_transform_matrix(base * Transform2D(ang + PI / 2.0, hand))
			ci.draw_texture(st, Vector2(-16, -38))
			ci.draw_set_transform_matrix(base)
	elif kind == "tool":
		ci.draw_set_transform_matrix(base * Transform2D(ang, hand))
		var tool: String = String(held["tool"])
		ci.draw_line(Vector2(-3, 0), Vector2(15, 0), Color(0.5, 0.33, 0.18), 2.0)
		if tool == "axe":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(11, -1), Vector2(13, -6), Vector2(18, -5), Vector2(17, 5), Vector2(13, 6), Vector2(11, 1)]), Color(0.78, 0.8, 0.86))
		elif tool == "pick":
			ci.draw_polyline(PackedVector2Array([Vector2(10, -7), Vector2(14, -3), Vector2(15, 3), Vector2(10, 7)]), Color(0.78, 0.8, 0.86), 2.5)
		elif tool == "rod":
			ci.draw_line(Vector2(15, 0), Vector2(30, -3), Color(0.6, 0.42, 0.22), 1.2)
		ci.draw_set_transform_matrix(base)


static func sword_points(shape: String, L: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		"short":
			pts = PackedVector2Array([Vector2(2, -1.6), Vector2(L - 3, -1.6), Vector2(L, 0), Vector2(L - 3, 1.6), Vector2(2, 1.6)])
		"long":
			pts = PackedVector2Array([Vector2(2, -2.0), Vector2(L - 4, -2.0), Vector2(L, 0), Vector2(L - 4, 2.0), Vector2(2, 2.0)])
		"katana":
			pts = PackedVector2Array([Vector2(2, -1.0), Vector2(L * 0.6, -1.4), Vector2(L, -0.6), Vector2(L - 1, 0.8), Vector2(L * 0.6, 0.9), Vector2(2, 1.0)])
		"dagger":
			pts = PackedVector2Array([Vector2(2, -2.2), Vector2(L - 3, -1.8), Vector2(L, 0), Vector2(L - 3, 1.8), Vector2(2, 2.2)])
		"flame":
			pts = PackedVector2Array([Vector2(2, -2.2), Vector2(L * 0.3, -3.2), Vector2(L * 0.5, -2.0), Vector2(L * 0.7, -3.2), Vector2(L, 0), Vector2(L * 0.7, 3.2), Vector2(L * 0.5, 2.0), Vector2(L * 0.3, 3.2), Vector2(2, 2.2)])
		"curved":
			pts = PackedVector2Array([Vector2(2, -1.5), Vector2(L * 0.5, -3.0), Vector2(L * 0.85, -2.2), Vector2(L, 1.2), Vector2(L * 0.8, 0.0), Vector2(L * 0.5, 0.4), Vector2(2, 1.5)])
		"crystal":
			pts = PackedVector2Array([Vector2(2, -1.5), Vector2(L * 0.35, -3.4), Vector2(L * 0.6, -2.0), Vector2(L, 0), Vector2(L * 0.6, 2.0), Vector2(L * 0.35, 3.4), Vector2(2, 1.5)])
		"zigzag":
			pts = PackedVector2Array([Vector2(2, -1.0), Vector2(L * 0.3, -3.0), Vector2(L * 0.5, 0.5), Vector2(L * 0.7, -2.5), Vector2(L, 0), Vector2(L * 0.65, 2.0), Vector2(L * 0.45, -0.5), Vector2(L * 0.25, 2.5), Vector2(2, 1.0)])
		"great":
			pts = PackedVector2Array([Vector2(2, -3.5), Vector2(L - 6, -3.8), Vector2(L, 0), Vector2(L - 6, 3.8), Vector2(2, 3.5)])
		_:
			pts = PackedVector2Array([Vector2(2, -1.2), Vector2(L, -1.2), Vector2(L + 2, 0), Vector2(L, 1.2), Vector2(2, 1.2)])
	return pts


static func sword_length(shape: String) -> float:
	match shape:
		"short": return 14.0
		"long": return 18.0
		"katana": return 21.0
		"dagger": return 10.0
		"flame": return 19.0
		"curved": return 17.0
		"crystal": return 19.0
		"zigzag": return 18.0
		"great": return 27.0
	return 21.0


# Gambar pedang dari gagang (pos) menuju arah ang. base = transform dasar (mis. flip).
static func draw_sword(ci: CanvasItem, d: Dictionary, pos: Vector2, ang: float, t: float, base: Transform2D, sc: float = 1.0) -> void:
	if d.has("gsheet"):
		Gear.draw_held(ci, String(d["gsheet"]), int(d["gi"]), pos, ang, base, float(d.get("hl", 30.0)) * sc)
		return
	var shape: String = String(d["shape"])
	var col: Color = d["blade"]
	var fx: String = String(d["fx"])
	var L: float = sword_length(shape) * float(d["scale"]) * 0.85
	# ---- sprite pedang PNG (assets/weapons/<id>.png, 32x32, ujung kiri-atas, gagang kanan-bawah)
	var stx: Texture2D = tex("res://assets/weapons/" + String(d.get("id", "")) + ".png")
	if stx != null:
		var k: float = (L + 8.0) / 36.0 * sc
		ci.draw_set_transform_matrix(base * Transform2D(ang + 3.0 * PI / 4.0, Vector2(k, k), 0.0, pos))
		ci.draw_texture(stx, Vector2(-26.0, -26.0))
		ci.draw_set_transform_matrix(base)
		return
	ci.draw_set_transform_matrix(base * Transform2D(ang, Vector2(sc, sc), 0.0, pos))
	var pts := sword_points(shape, L)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	if fx != "none":
		var pulse: float = 0.25 + 0.12 * sin(t * 9.0)
		ci.draw_polyline(closed, Color(col.r, col.g, col.b, pulse + 0.1), 6.0)
	ci.draw_colored_polygon(pts, col)
	ci.draw_polyline(closed, col.darkened(0.45), 1.0)
	ci.draw_line(Vector2(3, 0), Vector2(L - 1, 0), col.lightened(0.5), 1.0)
	if shape == "plasma":
		ci.draw_line(Vector2(3, 0), Vector2(L + 1, 0), Color(1, 1, 1, 0.9), 1.4)
	# gagang & pelindung
	var grip := Color(0.35, 0.2, 0.12)
	var guard := Color(0.85, 0.7, 0.3)
	if shape == "katana" or shape == "curved":
		guard = Color(0.8, 0.65, 0.25)
	elif shape == "great":
		guard = Color(0.5, 0.5, 0.58)
	elif shape == "plasma":
		guard = Color(0.3, 0.35, 0.45)
		grip = Color(0.2, 0.22, 0.3)
	ci.draw_line(Vector2(-4, 0), Vector2(1.5, 0), grip, 2.4)
	var gw: float = 4.5 if shape != "great" else 6.0
	if shape == "katana":
		ci.draw_circle(Vector2(1.5, 0), 2.2, guard)
	else:
		rect(ci, 0.5, -gw, 2.2, gw * 2.0, guard)
	ci.draw_circle(Vector2(-4.5, 0), 1.3, guard)
	# percikan efek
	if fx == "burn":
		for i in 4:
			var u: float = fmod(t * 1.6 + float(i) * 0.25, 1.0)
			ci.draw_circle(Vector2(L * (0.3 + 0.15 * i), -3.0 - u * 6.0), 1.6 * (1.0 - u), Color(1.0, 0.6 - 0.3 * u, 0.1, 0.9 - u * 0.5))
	elif fx == "freeze":
		for i in 3:
			var v: float = fmod(t * 1.1 + float(i) * 0.33, 1.0)
			ci.draw_circle(Vector2(L * (0.3 + 0.25 * i), 3.0 + v * 5.0), 1.0 * (1.0 - v), Color(0.85, 0.97, 1.0, 0.9))
	elif fx == "shock":
		if int(t * 14.0) % 3 == 0:
			ci.draw_polyline(PackedVector2Array([Vector2(L * 0.3, -3.5), Vector2(L * 0.45, 2.0), Vector2(L * 0.6, -3.0), Vector2(L * 0.8, 3.0)]), Color(1, 1, 0.6), 1.0)
	elif fx == "poison":
		var w: float = fmod(t * 1.3, 1.0)
		ci.draw_circle(Vector2(L * 0.5, 2.0 + w * 5.0), 1.5 * (1.0 - w), Color(0.5, 1.0, 0.3, 0.9))
	elif fx == "drain":
		var w2: float = fmod(t * 1.5, 1.0)
		ci.draw_circle(Vector2(L * (0.9 - 0.7 * w2), 0.0), 1.6 * (1.0 - w2) + 0.4, Color(1.0, 0.3, 0.5, 0.9))
	ci.draw_set_transform_matrix(base)


# ================================================================== MONSTER
const SLIME_COL := {"forest": Color(0.4, 0.85, 0.4), "desert": Color(0.95, 0.8, 0.35), "snow": Color(0.6, 0.85, 1.0), "volcano": Color(1.0, 0.45, 0.2)}
const SNAKE_COL := {"forest": Color(0.3, 0.75, 0.3), "desert": Color(0.85, 0.7, 0.35), "snow": Color(0.8, 0.92, 1.0), "volcano": Color(0.85, 0.2, 0.15)}
const GOBLIN_COL := {"forest": Color(0.42, 0.72, 0.3), "desert": Color(0.78, 0.6, 0.3), "snow": Color(0.6, 0.78, 0.82), "volcano": Color(0.75, 0.3, 0.22)}
const SPIDER_COL := {"forest": Color(0.3, 0.2, 0.34), "desert": Color(0.72, 0.52, 0.28), "snow": Color(0.78, 0.88, 0.97), "volcano": Color(0.17, 0.12, 0.14)}
const SPIDER_MARK := {"forest": Color(0.55, 0.95, 0.3), "desert": Color(0.28, 0.15, 0.08), "snow": Color(0.35, 0.55, 0.95), "volcano": Color(1.0, 0.5, 0.15)}
const OGRE_COL := {"forest": Color(0.5, 0.62, 0.32), "desert": Color(0.8, 0.6, 0.4), "snow": Color(0.72, 0.8, 0.9), "volcano": Color(0.42, 0.36, 0.38)}
const WISP_COL := {"forest": Color(0.6, 1.0, 0.7), "desert": Color(1.0, 0.9, 0.4), "snow": Color(0.6, 0.9, 1.0), "volcano": Color(1.0, 0.55, 0.25)}


const WOLF_COL := {"forest": Color(0.5, 0.46, 0.42), "desert": Color(0.78, 0.62, 0.4), "snow": Color(0.9, 0.93, 0.97), "volcano": Color(0.24, 0.19, 0.19)}
const KOBOLD_COL := {"forest": Color(0.78, 0.45, 0.25), "desert": Color(0.85, 0.65, 0.3), "snow": Color(0.55, 0.65, 0.8), "volcano": Color(0.72, 0.22, 0.18)}
const BAT_COL := {"forest": Color(0.36, 0.28, 0.4), "desert": Color(0.55, 0.4, 0.3), "snow": Color(0.7, 0.78, 0.9), "volcano": Color(0.45, 0.12, 0.14)}
const BEAR_COL := {"forest": Color(0.45, 0.3, 0.18), "desert": Color(0.62, 0.45, 0.28), "snow": Color(0.95, 0.96, 0.98), "volcano": Color(0.2, 0.15, 0.14)}
const GOLEM_COL := {"forest": Color(0.5, 0.55, 0.45), "desert": Color(0.8, 0.65, 0.42), "snow": Color(0.7, 0.86, 0.96), "volcano": Color(0.28, 0.24, 0.25)}
const GOLEM_GLOW := {"forest": Color(0.5, 1.0, 0.5), "desert": Color(1.0, 0.85, 0.3), "snow": Color(0.5, 0.9, 1.0), "volcano": Color(1.0, 0.45, 0.1)}
const CENTI_COL := {"forest": Color(0.55, 0.3, 0.15), "desert": Color(0.78, 0.5, 0.2), "snow": Color(0.5, 0.55, 0.75), "volcano": Color(0.7, 0.15, 0.1)}

# o: kind biome t face flash moving seed atk
static func draw_mob(ci: CanvasItem, o: Dictionary) -> void:
	var kind: String = String(o["kind"])
	var biome: String = String(o.get("biome", "forest"))
	var t: float = float(o["t"]) + float(o.get("seed", 0.0))
	var face: float = float(o.get("face", 1.0))
	var mv: bool = bool(o.get("moving", false))
	var atk: float = float(o.get("atk", 0.0))
	var msc: float = float(o.get("scale", 1.0))     # mini boss lebih besar (kaki tetap di tanah)
	ci.draw_set_transform(Vector2(0.0, 10.0 * (1.0 - msc)), 0.0, Vector2(face * msc, msc))
	if _mob_sprite(ci, o, kind, biome, t, mv, atk):
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	match kind:
		"slime":
			_slime(ci, t, biome, atk)
		"bee":
			_bee(ci, t)
		"cow":
			_cow(ci, t, mv)
		"chicken":
			_chicken(ci, t, mv)
		"snake":
			_snake(ci, t, biome, mv, atk)
		"fiend":
			_fiend(ci, t, atk)
		"wisp":
			_wisp(ci, t, biome)
		"goblin":
			_goblin(ci, t, biome, mv, atk)
		"spider":
			_spider(ci, t, biome, mv, atk)
		"ogre":
			_ogre(ci, t, biome, mv, atk, false, false, bool(o.get("stun", false)))
		"red_ogre":
			_ogre(ci, t, biome, mv, atk, true, bool(o.get("rage", false)), bool(o.get("stun", false)))
		"wolf":
			_wolf(ci, t, biome, mv, atk)
		"kobold":
			_kobold(ci, t, biome, mv, atk)
		"bat":
			_bat(ci, t, biome, atk)
		"bear":
			_bear(ci, t, biome, mv, atk, bool(o.get("stun", false)))
		"golem":
			_golem(ci, t, biome, mv, atk, bool(o.get("rage", false)), bool(o.get("stun", false)))
		"mummy":
			_mummy(ci, t, biome, mv, atk)
		"centipede":
			_centipede(ci, t, biome, mv, atk)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _slime(ci: CanvasItem, t: float, biome: String, atk: float) -> void:
	var col: Color = SLIME_COL.get(biome, Color(0.4, 0.85, 0.4))
	var sq: float = sin(t * 5.0) * 0.1 + atk * 0.2
	var rx: float = 10.0 * (1.0 + sq)
	var ry: float = 8.0 * (1.0 - sq)
	var c := Vector2(0, 7.0 - ry)
	ellipse(ci, c + Vector2(0, 0.6), rx + 1.0, ry + 1.0, col.darkened(0.45))
	ellipse(ci, c, rx, ry, col)
	ellipse(ci, c + Vector2(-3.0, -ry * 0.4), rx * 0.35, ry * 0.25, Color(1, 1, 1, 0.45))
	var ey: float = c.y - 1.0
	ellipse(ci, Vector2(-3.5, ey), 1.8, 2.4, Color(0.08, 0.1, 0.12), 8)
	ellipse(ci, Vector2(3.5, ey), 1.8, 2.4, Color(0.08, 0.1, 0.12), 8)
	ci.draw_circle(Vector2(-3.0, ey - 0.8), 0.7, Color.WHITE)
	ci.draw_circle(Vector2(4.0, ey - 0.8), 0.7, Color.WHITE)
	ci.draw_line(Vector2(-1.5, ey + 3.0), Vector2(1.5, ey + 3.0), Color(0.08, 0.1, 0.12), 1.0)
	if biome == "volcano":
		for i in 3:
			var u: float = fmod(t * 1.2 + i * 0.33, 1.0)
			ci.draw_circle(Vector2(-4.0 + i * 4.0, c.y - ry - u * 5.0), 1.6 * (1.0 - u), Color(1.0, 0.7, 0.2, 0.9))
	elif biome == "snow":
		rect(ci, -5.0, c.y - ry - 1.0, 10.0, 2.0, Color(1, 1, 1, 0.9))
	elif biome == "desert":
		rect(ci, -2.0, c.y - ry - 3.0, 4.0, 3.0, Color(0.3, 0.7, 0.3))


static func _bee(ci: CanvasItem, t: float) -> void:
	var y: float = sin(t * 8.0) * 1.5 - 4.0
	var flap: float = 3.0 + sin(t * 55.0) * 2.0
	ellipse(ci, Vector2(-2.0, y - 6.0), 3.5, flap, Color(0.85, 0.95, 1.0, 0.65), 10)
	ellipse(ci, Vector2(2.0, y - 6.0), 3.5, flap, Color(0.85, 0.95, 1.0, 0.65), 10)
	ellipse(ci, Vector2(0, y), 6.5, 4.8, Color(1.0, 0.82, 0.15))
	rect(ci, -2.5, y - 4.0, 1.6, 8.0, Color(0.15, 0.12, 0.08))
	rect(ci, 0.5, y - 4.0, 1.6, 8.0, Color(0.15, 0.12, 0.08))
	ci.draw_circle(Vector2(6.0, y), 3.0, Color(0.15, 0.12, 0.08))
	ci.draw_circle(Vector2(7.0, y - 1.0), 0.9, Color.WHITE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-6.5, y - 1.5), Vector2(-10.0, y), Vector2(-6.5, y + 1.5)]), Color(0.3, 0.2, 0.1))


static func _cow(ci: CanvasItem, t: float, mv: bool) -> void:
	var w: float = sin(t * 8.0) * 2.0 if mv else 0.0
	var leg := Color(0.9, 0.9, 0.9)
	for i in 4:
		var lx: float = [-8.0, -4.0, 3.0, 7.0][i]
		var sg: float = 1.0 if i % 2 == 0 else -1.0
		rect(ci, lx + w * sg * 0.4, 2.0, 2.6, 7.0 - maxf(w * sg, 0.0) * 0.5, leg if i < 2 else leg.darkened(0.12))
		rect(ci, lx + w * sg * 0.4, 7.5, 2.6, 1.5, Color(0.25, 0.2, 0.18))
	ellipse(ci, Vector2(0, -1.0), 12.0, 7.5, Color(0.97, 0.97, 0.97))
	ellipse(ci, Vector2(-4.0, -3.0), 3.5, 2.8, Color(0.2, 0.18, 0.2), 8)
	ellipse(ci, Vector2(4.0, 1.0), 3.0, 2.4, Color(0.2, 0.18, 0.2), 8)
	ellipse(ci, Vector2(1.0, 3.5), 1.5, 1.1, Color(1.0, 0.7, 0.75), 6)
	ci.draw_line(Vector2(-11.5, -4.0), Vector2(-14.0, 1.0 + sin(t * 3.0) * 2.0), Color(0.25, 0.2, 0.22), 1.5)
	rect(ci, 9.0, -9.0, 7.5, 7.0, Color(0.97, 0.97, 0.97))
	rect(ci, 13.5, -5.5, 3.5, 3.5, Color(1.0, 0.7, 0.75))
	rect(ci, 9.5, -11.0, 1.5, 3.0, Color(0.9, 0.85, 0.7))
	rect(ci, 14.0, -11.0, 1.5, 3.0, Color(0.9, 0.85, 0.7))
	rect(ci, 11.2, -7.5, 1.5, 1.7, Color(0.1, 0.1, 0.12))


static func _chicken(ci: CanvasItem, t: float, mv: bool) -> void:
	var peck: float = sin(t * 7.0) * 1.3 if not mv else sin(t * 14.0) * 0.8
	var step: float = sin(t * 14.0) * 1.5 if mv else 0.0
	ci.draw_line(Vector2(-1.0, 3.0), Vector2(-1.0 + step, 8.0), Color(0.95, 0.65, 0.2), 1.2)
	ci.draw_line(Vector2(2.0, 3.0), Vector2(2.0 - step, 8.0), Color(0.95, 0.65, 0.2), 1.2)
	ellipse(ci, Vector2(-1.0, -0.5), 6.5, 5.0, Color(0.98, 0.98, 0.95))
	ellipse(ci, Vector2(-2.0, 0.0), 3.5, 2.5, Color(0.88, 0.88, 0.82), 8)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-6.0, -3.0), Vector2(-10.0, -6.0), Vector2(-8.0, -1.0)]), Color(0.9, 0.9, 0.85))
	ci.draw_circle(Vector2(5.0, -6.0 + peck), 3.2, Color(0.98, 0.98, 0.95))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(7.5, -6.8 + peck), Vector2(10.5, -5.8 + peck), Vector2(7.5, -4.8 + peck)]), Color(1.0, 0.7, 0.2))
	ci.draw_circle(Vector2(5.0, -9.0 + peck), 1.2, Color(0.9, 0.15, 0.15))
	ci.draw_circle(Vector2(6.5, -8.5 + peck), 1.0, Color(0.9, 0.15, 0.15))
	ci.draw_circle(Vector2(6.0, -6.8 + peck), 0.7, Color(0.05, 0.05, 0.05))


static func _snake(ci: CanvasItem, t: float, biome: String, mv: bool, atk: float) -> void:
	var col: Color = SNAKE_COL.get(biome, Color(0.3, 0.75, 0.3))
	var spd: float = 9.0 if mv else 3.0
	var n := 12
	for k in n:
		var i: int = n - 1 - k
		var amp: float = 1.2 + float(i) * 0.35
		var p := Vector2(float(-i) * 2.8 + 8.0, sin(t * spd - float(i) * 0.6) * amp + 4.0)
		var r: float = maxf(3.4 - float(i) * 0.17, 1.1)
		var cc: Color = col if i % 2 == 0 else col.darkened(0.25)
		ci.draw_circle(p, r + 0.7, col.darkened(0.55))
		ci.draw_circle(p, r, cc)
	var hp := Vector2(8.0, sin(t * spd) * 1.2 + 4.0)
	ci.draw_circle(hp, 4.2, col.lightened(0.1))
	ci.draw_circle(hp + Vector2(2.0, -1.5), 1.3, Color(1.0, 0.95, 0.3))
	ci.draw_circle(hp + Vector2(2.4, -1.5), 0.6, Color(0.05, 0.05, 0.05))
	if int(t * 5.0) % 2 == 0 or atk > 0.0:
		ci.draw_line(hp + Vector2(4.0, 1.0), hp + Vector2(8.0, 1.0), Color(0.95, 0.2, 0.25), 1.0)
		ci.draw_line(hp + Vector2(8.0, 1.0), hp + Vector2(10.0, -0.5), Color(0.95, 0.2, 0.25), 1.0)
		ci.draw_line(hp + Vector2(8.0, 1.0), hp + Vector2(10.0, 2.5), Color(0.95, 0.2, 0.25), 1.0)


static func _fiend(ci: CanvasItem, t: float, atk: float) -> void:
	var y: float = sin(t * 3.0) * 2.0 - 3.0
	var fl: float = sin(t * 14.0) * 0.5
	var wing := Color(0.35, 0.08, 0.2)
	for s in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(s * 4.0, y - 2.0), Vector2(s * 15.0, y - 9.0 + fl * 6.0), Vector2(s * 13.0, y - 1.0 + fl * 3.0),
			Vector2(s * 9.0, y + 2.0), Vector2(s * 4.0, y + 3.0)]), wing)
	if atk > 0.0:
		ci.draw_circle(Vector2(0, y), 14.0, Color(1.0, 0.3, 0.1, 0.25 * atk))
	ci.draw_line(Vector2(-3.0, y + 5.0), Vector2(-9.0, y + 9.0 + fl * 2.0), Color(0.6, 0.12, 0.2), 1.5)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-9.0, y + 9.0 + fl * 2.0), Vector2(-12.0, y + 6.0), Vector2(-7.0, y + 6.5)]), Color(0.6, 0.12, 0.2))
	ellipse(ci, Vector2(0, y + 1.5), 5.5, 6.5, Color(0.72, 0.14, 0.24))
	ellipse(ci, Vector2(0, y + 3.0), 3.0, 4.0, Color(0.9, 0.5, 0.4), 8)
	ci.draw_circle(Vector2(0, y - 6.0), 5.2, Color(0.78, 0.16, 0.26))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-4.5, y - 9.0), Vector2(-7.0, y - 15.0), Vector2(-1.5, y - 10.5)]), Color(0.2, 0.1, 0.1))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(4.5, y - 9.0), Vector2(7.0, y - 15.0), Vector2(1.5, y - 10.5)]), Color(0.2, 0.1, 0.1))
	ci.draw_circle(Vector2(-2.2, y - 6.5), 1.5, Color(1.0, 0.9, 0.2))
	ci.draw_circle(Vector2(2.2, y - 6.5), 1.5, Color(1.0, 0.9, 0.2))
	ci.draw_circle(Vector2(-2.2, y - 6.5), 0.6, Color(0.1, 0.0, 0.0))
	ci.draw_circle(Vector2(2.2, y - 6.5), 0.6, Color(0.1, 0.0, 0.0))
	ci.draw_line(Vector2(-2.0, y - 3.5), Vector2(2.0, y - 3.5), Color(0.1, 0.0, 0.0), 1.0)
	rect(ci, -2.0, y - 3.3, 1.0, 1.4, Color.WHITE)
	rect(ci, 1.0, y - 3.3, 1.0, 1.4, Color.WHITE)


static func _wisp(ci: CanvasItem, t: float, biome: String) -> void:
	var col: Color = WISP_COL.get(biome, Color(0.6, 1.0, 0.7))
	var y: float = sin(t * 4.0) * 2.5 - 3.0
	for i in 4:
		var u: float = float(i) / 4.0
		ci.draw_circle(Vector2(sin(t * 5.0 - i) * 2.0, y + 6.0 + i * 3.0), 4.5 - i, Color(col.r, col.g, col.b, 0.4 - u * 0.3))
	ci.draw_circle(Vector2(0, y), 13.0, Color(col.r, col.g, col.b, 0.12))
	ci.draw_circle(Vector2(0, y), 10.0, Color(col.r, col.g, col.b, 0.25))
	ci.draw_circle(Vector2(0, y), 7.0, Color(col.r, col.g, col.b, 0.7))
	ci.draw_circle(Vector2(0, y), 5.0, col.lightened(0.5))
	ellipse(ci, Vector2(1.0, y), 2.4, 3.2, Color(0.1, 0.1, 0.2), 8)
	ci.draw_circle(Vector2(1.6, y - 1.2), 0.8, Color.WHITE)


static func _goblin(ci: CanvasItem, t: float, biome: String, mv: bool, atk: float) -> void:
	var skin: Color = GOBLIN_COL.get(biome, Color(0.42, 0.72, 0.3))
	var dk: Color = skin.darkened(0.3)
	var cloth := Color(0.5, 0.33, 0.2)
	if biome == "snow":
		cloth = Color(0.35, 0.4, 0.55)
	elif biome == "volcano":
		cloth = Color(0.25, 0.18, 0.2)
	elif biome == "desert":
		cloth = Color(0.62, 0.2, 0.15)
	var ph: float = t * 13.0
	var step: float = sin(ph) * 2.2 if mv else 0.0
	var hop: float = absf(sin(ph)) * 1.2 if mv else sin(t * 3.0) * 0.4
	var by: float = -hop + atk * 1.5
	# kaki + sepatu
	rect(ci, -4.0 + step, 3.0 + by * 0.3, 3.0, 5.5, dk)
	rect(ci, 1.0 - step, 3.0 + by * 0.3, 3.0, 5.5, dk)
	rect(ci, -5.0 + step, 8.0, 4.5, 2.0, Color(0.2, 0.13, 0.09))
	rect(ci, 0.5 - step, 8.0, 4.5, 2.0, Color(0.2, 0.13, 0.09))
	# lengan belakang & badan
	ci.draw_circle(Vector2(-6.0, -1.0 + by), 2.0, dk)
	ellipse(ci, Vector2(0, -1.5 + by), 6.0, 6.5, cloth)
	rect(ci, -5.5, 1.0 + by, 11.0, 1.6, cloth.darkened(0.35))
	ellipse(ci, Vector2(0, -3.0 + by), 3.0, 3.0, cloth.lightened(0.12), 8)
	# kepala: telinga runcing besar
	var hy: float = -10.0 + by
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-4.0, hy - 1.0), Vector2(-12.0, hy - 5.0), Vector2(-4.5, hy + 3.0)]), skin.darkened(0.12))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(4.0, hy - 1.0), Vector2(12.0, hy - 5.0), Vector2(4.5, hy + 3.0)]), skin)
	ellipse(ci, Vector2(0, hy), 6.0, 5.5, skin)
	ellipse(ci, Vector2(2.6, hy + 1.5), 1.6, 1.2, skin.darkened(0.2), 6)
	# mata menyala + alis marah
	ci.draw_circle(Vector2(-2.2, hy - 1.0), 1.5, Color(1.0, 0.9, 0.2))
	ci.draw_circle(Vector2(2.6, hy - 1.0), 1.5, Color(1.0, 0.9, 0.2))
	ci.draw_circle(Vector2(-1.9, hy - 1.0), 0.6, Color(0.1, 0.0, 0.0))
	ci.draw_circle(Vector2(2.9, hy - 1.0), 0.6, Color(0.1, 0.0, 0.0))
	ci.draw_line(Vector2(-4.0, hy - 3.2), Vector2(-0.8, hy - 2.0), Color(0.1, 0.1, 0.05), 1.0)
	ci.draw_line(Vector2(4.6, hy - 3.2), Vector2(1.2, hy - 2.0), Color(0.1, 0.1, 0.05), 1.0)
	ci.draw_line(Vector2(-2.0, hy + 3.4), Vector2(3.0, hy + 3.4), Color(0.12, 0.04, 0.04), 1.0)
	rect(ci, -1.5, hy + 2.1, 1.0, 1.8, Color.WHITE)
	rect(ci, 1.8, hy + 2.1, 1.0, 1.8, Color.WHITE)
	# aksesori khas biome
	if biome == "desert":
		rect(ci, -5.8, hy - 4.6, 11.6, 2.2, Color(0.85, 0.25, 0.2))
		ci.draw_line(Vector2(-5.8, hy - 3.5), Vector2(-9.0, hy - 1.0), Color(0.85, 0.25, 0.2), 1.5)
	elif biome == "snow":
		ellipse(ci, Vector2(0, hy - 5.0), 7.0, 3.2, Color(0.95, 0.97, 1.0), 10)
		ci.draw_circle(Vector2(0, hy - 8.4), 1.6, Color(0.95, 0.97, 1.0))
	elif biome == "volcano":
		ellipse(ci, Vector2(0, hy - 3.8), 6.3, 3.2, Color(0.2, 0.17, 0.2), 10)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-5.5, hy - 4.0), Vector2(-9.0, hy - 10.0), Vector2(-3.0, hy - 5.5)]), Color(0.9, 0.85, 0.7))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(5.5, hy - 4.0), Vector2(9.0, hy - 10.0), Vector2(3.0, hy - 5.5)]), Color(0.9, 0.85, 0.7))
	else:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-5.0, hy - 4.0), Vector2(0.0, hy - 8.5), Vector2(5.0, hy - 4.0)]), Color(0.45, 0.3, 0.15))
	# gada kayu: terangkat, lalu diayun saat menyerang
	var hand := Vector2(7.0, -1.0 + by)
	var ang: float = -1.1 + clampf(atk, 0.0, 1.0) * 1.9
	var tip: Vector2 = hand + Vector2.from_angle(ang) * 11.0
	ci.draw_line(hand, tip, Color(0.45, 0.3, 0.15), 3.0)
	ci.draw_circle(tip, 3.4, Color(0.4, 0.26, 0.12))
	ci.draw_circle(tip + Vector2(1.0, -1.0), 0.9, Color(0.75, 0.75, 0.78))
	ci.draw_circle(hand, 2.2, skin)


static func _spider(ci: CanvasItem, t: float, biome: String, mv: bool, atk: float) -> void:
	var col: Color = SPIDER_COL.get(biome, Color(0.3, 0.2, 0.34))
	var mark: Color = SPIDER_MARK.get(biome, Color(0.55, 0.95, 0.3))
	var sp: float = 17.0 if mv else 4.0
	var amp: float = 1.8 if mv else 0.5
	var low: float = atk * 2.0
	var by: float = 2.0 + low
	var leg: Color = col.darkened(0.25)
	# 4 pasang kaki: lutut terangkat lalu telapak menapak
	for i in 4:
		var u: float = float(i)
		var spread: float = (u - 1.5) * 0.9
		var ax: float = 3.0 - u * 2.4
		for s in [-1.0, 1.0]:
			var wig: float = sin(t * sp + u * 1.6 + (0.0 if s > 0.0 else PI)) * amp
			var a0 := Vector2(ax, by)
			var knee: Vector2 = a0 + Vector2(spread * 5.0 + wig * 0.5, s * 5.5 - 5.0 + low * 0.5)
			var foot: Vector2 = Vector2(a0.x + spread * 10.0 + wig, by + s * 8.5 + 1.0)
			ci.draw_line(a0, knee, leg, 1.6)
			ci.draw_line(knee, foot, leg, 1.2)
	# perut besar + tanda khas, dada, kepala
	ellipse(ci, Vector2(-6.0, by + 0.5), 7.0, 5.6, col)
	ellipse(ci, Vector2(-7.0, by - 1.5), 3.6, 2.0, col.lightened(0.18), 8)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-8.0, by - 1.0), Vector2(-4.0, by), Vector2(-8.0, by + 2.4), Vector2(-9.5, by + 0.6)]), mark)
	ellipse(ci, Vector2(1.5, by), 4.4, 3.8, col.lightened(0.06))
	ci.draw_circle(Vector2(6.0, by - 0.4), 3.1, col.lightened(0.1))
	# mata (empat titik) + taring
	for e in [Vector2(7.2, by - 2.0), Vector2(8.2, by - 0.8), Vector2(5.6, by - 2.4), Vector2(7.8, by + 0.6)]:
		ci.draw_circle(e, 0.8, Color(1.0, 0.2, 0.2) if biome != "volcano" else Color(1.0, 0.85, 0.2))
	ci.draw_line(Vector2(8.4, by + 1.6), Vector2(9.4, by + 4.0), Color(0.95, 0.95, 0.85), 1.0)
	ci.draw_line(Vector2(7.2, by + 2.0), Vector2(7.6, by + 4.4), Color(0.95, 0.95, 0.85), 1.0)
	if biome == "volcano":
		ci.draw_circle(Vector2(-6.0, by), 6.0, Color(1.0, 0.4, 0.1, 0.18))


# ---------------------------------------------------------------- musuh baru
static func _wolf(ci: CanvasItem, t: float, biome: String, mv: bool, atk: float) -> void:
	var col: Color = WOLF_COL.get(biome, Color(0.5, 0.46, 0.42))
	var dk: Color = col.darkened(0.35)
	var ph: float = t * 14.0 if mv else t * 2.0
	var bob: float = absf(sin(ph)) * 1.2 if mv else sin(t * 2.0) * 0.4
	var cr: float = atk * 2.5
	# kaki (4)
	for i in 4:
		var lx: float = -8.0 + float(i) * 5.0
		var sw: float = sin(ph + float(i) * 1.6) * 2.6 if mv else 0.0
		ci.draw_line(Vector2(lx, 1.0 + cr), Vector2(lx + sw, 9.0), dk if i % 2 == 0 else col.darkened(0.15), 2.0)
	# ekor
	ci.draw_line(Vector2(-10.0, -3.0 + cr - bob), Vector2(-17.0, -6.0 + sin(t * 6.0) * 2.0 + cr), col, 3.0)
	# badan
	ellipse(ci, Vector2(-1.0, -2.0 + cr - bob), 10.5, 5.8, col)
	ellipse(ci, Vector2(-1.0, 0.0 + cr - bob), 8.0, 3.0, col.lightened(0.18), 10)
	# kepala
	var hy: float = -5.0 + cr - bob
	ellipse(ci, Vector2(9.0, hy), 5.2, 4.4, col.lightened(0.05), 12)
	ellipse(ci, Vector2(14.0, hy + 1.6), 3.6, 2.4, col.lightened(0.12), 10)
	ci.draw_circle(Vector2(17.0, hy + 1.0), 1.2, Color(0.08, 0.06, 0.06))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(6.0, hy - 3.0), Vector2(7.0, hy - 8.0), Vector2(9.5, hy - 3.6)]), dk)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(9.5, hy - 3.4), Vector2(11.5, hy - 8.0), Vector2(12.5, hy - 2.6)]), dk)
	ci.draw_circle(Vector2(11.0, hy - 1.0), 1.1, Color(1.0, 0.8, 0.15) if biome != "volcano" else Color(1.0, 0.3, 0.1))
	if atk > 0.3:
		ci.draw_line(Vector2(13.0, hy + 3.2), Vector2(14.0, hy + 5.4), Color(0.97, 0.97, 0.9), 1.2)
		ci.draw_line(Vector2(15.5, hy + 3.2), Vector2(16.2, hy + 5.4), Color(0.97, 0.97, 0.9), 1.2)


static func _kobold(ci: CanvasItem, t: float, biome: String, mv: bool, atk: float) -> void:
	var skin: Color = KOBOLD_COL.get(biome, Color(0.78, 0.45, 0.25))
	var dk: Color = skin.darkened(0.35)
	var ph: float = t * 12.0 if mv else 0.0
	var step: float = sin(ph) * 2.0 if mv else 0.0
	var bob: float = absf(sin(ph)) * 1.0 if mv else sin(t * 2.5) * 0.4
	# ekor
	ci.draw_line(Vector2(-4.0, 0.0 - bob), Vector2(-11.0, 2.0 + sin(t * 5.0) * 2.0), dk, 2.0)
	# kaki
	ci.draw_line(Vector2(-2.0, 2.0), Vector2(-2.0 + step, 9.0), dk, 2.2)
	ci.draw_line(Vector2(2.0, 2.0), Vector2(2.0 - step, 9.0), dk, 2.2)
	# badan + kain
	ellipse(ci, Vector2(0.0, -3.0 - bob), 5.0, 6.0, skin)
	rect(ci, -4.0, -0.5 - bob, 8.0, 4.0, Color(0.4, 0.3, 0.2))
	# tombak (terangkat saat melempar)
	var ax: float = 6.0 + atk * 2.0
	var ay: float = -6.0 - atk * 6.0 - bob
	ci.draw_line(Vector2(ax - 6.0, ay + 10.0), Vector2(ax + 4.0, ay - 6.0), Color(0.55, 0.4, 0.25), 1.4)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(ax + 3.0, ay - 4.0), Vector2(ax + 4.5, ay - 9.0), Vector2(ax + 6.0, ay - 4.0)]), Color(0.8, 0.82, 0.86))
	ci.draw_line(Vector2(3.0, -4.0 - bob), Vector2(ax - 2.0, ay + 7.0), skin, 2.0)
	# kepala: moncong anjing + telinga
	var hy: float = -12.0 - bob
	ellipse(ci, Vector2(1.0, hy), 5.0, 4.4, skin.lightened(0.05), 12)
	ellipse(ci, Vector2(5.5, hy + 1.6), 3.0, 2.0, skin.lightened(0.15), 8)
	ci.draw_circle(Vector2(8.0, hy + 1.0), 0.9, Color(0.1, 0.05, 0.05))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-3.0, hy - 2.0), Vector2(-6.0, hy - 8.0), Vector2(-0.5, hy - 3.6)]), dk)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0.5, hy - 3.6), Vector2(2.5, hy - 9.0), Vector2(3.5, hy - 2.8)]), dk)
	ci.draw_circle(Vector2(3.4, hy - 0.8), 1.0, Color(1.0, 0.9, 0.2))
	ci.draw_circle(Vector2(3.7, hy - 0.8), 0.45, Color(0.1, 0.0, 0.0))


static func _bat(ci: CanvasItem, t: float, biome: String, atk: float) -> void:
	var col: Color = BAT_COL.get(biome, Color(0.36, 0.28, 0.4))
	var y: float = sin(t * 4.0) * 2.0 - 6.0 + atk * 3.0
	var fl: float = sin(t * 22.0)
	# sayap (mengepak)
	for s in [-1.0, 1.0]:
		var tip := Vector2(s * (13.0 + fl * 1.5), y - 5.0 - fl * 5.0)
		var mid := Vector2(s * 8.0, y - 7.0 - fl * 2.0)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(s * 2.0, y - 1.0), mid, tip, Vector2(s * 9.0, y + 1.0), Vector2(s * 5.0, y + 3.0)]), col.darkened(0.15))
		ci.draw_line(Vector2(s * 2.0, y - 1.0), tip, col.lightened(0.2), 1.0)
	# badan + kepala + telinga
	ellipse(ci, Vector2(0.0, y), 3.8, 4.6, col)
	ci.draw_circle(Vector2(0.0, y - 5.0), 3.2, col.lightened(0.08))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-3.0, y - 6.0), Vector2(-3.4, y - 10.5), Vector2(-0.8, y - 7.6)]), col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(3.0, y - 6.0), Vector2(3.4, y - 10.5), Vector2(0.8, y - 7.6)]), col)
	ci.draw_circle(Vector2(-1.3, y - 5.4), 0.8, Color(1.0, 0.25, 0.2))
	ci.draw_circle(Vector2(1.3, y - 5.4), 0.8, Color(1.0, 0.25, 0.2))
	if atk > 0.1 or fl > 0.7:
		ci.draw_line(Vector2(-0.9, y - 3.4), Vector2(-0.9, y - 1.8), Color(0.97, 0.97, 0.92), 0.9)
		ci.draw_line(Vector2(0.9, y - 3.4), Vector2(0.9, y - 1.8), Color(0.97, 0.97, 0.92), 0.9)


static func _bear(ci: CanvasItem, t: float, biome: String, mv: bool, atk: float, stun: bool) -> void:
	var col: Color = BEAR_COL.get(biome, Color(0.45, 0.3, 0.18))
	var dk: Color = col.darkened(0.3)
	var ph: float = t * 7.0 if mv else 0.0
	var bob: float = absf(sin(ph)) * 1.2 if mv else sin(t * 1.8) * 0.5
	if stun:
		bob = 1.5 + sin(t * 20.0) * 0.5
	var rise: float = atk * 4.0        # berdiri / mengangkat cakar saat bersiap
	# kaki belakang & depan
	for i in 4:
		var lx: float = -10.0 + float(i) * 6.5
		var sw: float = sin(ph + float(i) * 1.7) * 2.4 if mv else 0.0
		ci.draw_line(Vector2(lx, 0.0), Vector2(lx + sw, 10.0), dk, 4.6)
		ci.draw_circle(Vector2(lx + sw, 10.0), 2.6, dk)
	# badan
	ellipse(ci, Vector2(-1.0, -7.0 - bob - rise * 0.5), 14.0, 9.5, col)
	ellipse(ci, Vector2(-3.0, -4.0 - bob - rise * 0.5), 9.0, 5.0, col.lightened(0.12), 12)
	# kepala
	var hy: float = -10.0 - bob - rise
	ellipse(ci, Vector2(12.0, hy), 6.4, 5.6, col.lightened(0.05), 14)
	ellipse(ci, Vector2(17.0, hy + 2.0), 3.4, 2.6, col.lightened(0.3), 10)
	ci.draw_circle(Vector2(19.5, hy + 1.2), 1.4, Color(0.08, 0.05, 0.05))
	ci.draw_circle(Vector2(9.0, hy - 5.0), 2.4, dk)
	ci.draw_circle(Vector2(13.5, hy - 5.4), 2.4, dk)
	ci.draw_circle(Vector2(13.5, hy - 1.4), 1.2, Color(0.95, 0.85, 0.3))
	ci.draw_circle(Vector2(13.9, hy - 1.4), 0.55, Color(0.1, 0.0, 0.0))
	# cakar depan terangkat
	if atk > 0.1:
		var cx: float = 14.0 + atk * 4.0
		var cy: float = -12.0 - atk * 6.0 - bob
		ci.draw_line(Vector2(8.0, -9.0 - bob), Vector2(cx, cy), dk, 5.0)
		for k in 3:
			ci.draw_line(Vector2(cx + float(k) * 1.6 - 1.6, cy), Vector2(cx + float(k) * 1.6 - 0.6, cy - 3.4), Color(0.95, 0.95, 0.88), 1.0)


static func _golem(ci: CanvasItem, t: float, biome: String, mv: bool, atk: float, rage: bool, stun: bool) -> void:
	var stone: Color = GOLEM_COL.get(biome, Color(0.5, 0.55, 0.45))
	var glow: Color = GOLEM_GLOW.get(biome, Color(0.5, 1.0, 0.5))
	if rage:
		glow = Color(1.0, 0.3, 0.15)
	var dk: Color = stone.darkened(0.35)
	var ph: float = t * 4.5 if mv else 0.0
	var step: float = sin(ph) * 2.2 if mv else 0.0
	var bob: float = absf(sin(ph)) * 1.0 if mv else 0.0
	if stun:
		bob = 1.5
	var pulse: float = 0.6 + 0.4 * sin(t * 3.0) + atk * 0.5
	if rage:
		ci.draw_circle(Vector2(0.0, -10.0), 24.0 + sin(t * 10.0) * 1.5, Color(1.0, 0.25, 0.1, 0.14))
	# kaki
	rect(ci, -9.0 + step * 0.5, 0.0, 7.0, 10.0, dk)
	rect(ci, 2.0 - step * 0.5, 0.0, 7.0, 10.0, dk)
	# lengan (terangkat saat menghantam)
	var lift: float = atk * 9.0
	rect(ci, -18.0, -16.0 - bob - lift, 6.0, 15.0, dk)
	rect(ci, 12.0, -16.0 - bob - lift, 6.0, 15.0, dk)
	rect(ci, -19.5, -3.0 - bob - lift, 9.0, 7.0, stone.darkened(0.15))
	rect(ci, 10.5, -3.0 - bob - lift, 9.0, 7.0, stone.darkened(0.15))
	# badan batu + retakan bercahaya
	rect(ci, -12.0, -22.0 - bob, 24.0, 22.0, stone)
	rect(ci, -12.0, -22.0 - bob, 24.0, 4.0, stone.lightened(0.18))
	var gc := Color(glow.r, glow.g, glow.b, 0.55 + 0.35 * pulse)
	ci.draw_line(Vector2(-6.0, -17.0 - bob), Vector2(-2.0, -10.0 - bob), gc, 1.4)
	ci.draw_line(Vector2(-2.0, -10.0 - bob), Vector2(-6.0, -4.0 - bob), gc, 1.4)
	ci.draw_line(Vector2(6.0, -16.0 - bob), Vector2(3.0, -8.0 - bob), gc, 1.4)
	ci.draw_circle(Vector2(0.0, -11.0 - bob), 3.0, gc)
	# kepala
	var hy: float = -28.0 - bob
	rect(ci, -7.0, hy - 6.0, 14.0, 12.0, stone.lightened(0.06))
	rect(ci, -7.0, hy - 6.0, 14.0, 2.4, stone.lightened(0.2))
	rect(ci, -4.5, hy - 1.5, 3.0, 2.4, glow)
	rect(ci, 1.5, hy - 1.5, 3.0, 2.4, glow)
	if biome == "snow":
		ellipse(ci, Vector2(0.0, hy - 6.5), 8.0, 2.4, Color(0.97, 0.99, 1.0), 10)
	elif biome == "volcano":
		ci.draw_line(Vector2(-3.0, hy - 6.0), Vector2(-5.0, hy - 11.0), Color(1.0, 0.5, 0.1, 0.8), 1.4)
		ci.draw_line(Vector2(3.0, hy - 6.0), Vector2(4.0, hy - 12.0), Color(1.0, 0.5, 0.1, 0.8), 1.4)


static func _mummy(ci: CanvasItem, t: float, biome: String, mv: bool, atk: float) -> void:
	var wrap := Color(0.88, 0.82, 0.66)
	if biome == "snow":
		wrap = Color(0.82, 0.88, 0.92)
	elif biome == "volcano":
		wrap = Color(0.62, 0.5, 0.42)
	var dk: Color = wrap.darkened(0.3)
	var ph: float = t * 5.0 if mv else 0.0
	var step: float = sin(ph) * 1.8 if mv else 0.0
	var bob: float = absf(sin(ph)) * 0.8 if mv else sin(t * 1.5) * 0.4
	# kaki
	rect(ci, -4.5 + step * 0.5, 1.0, 3.6, 9.0, wrap)
	rect(ci, 0.9 - step * 0.5, 1.0, 3.6, 9.0, wrap)
	# badan
	rect(ci, -6.0, -12.0 - bob, 12.0, 14.0, wrap)
	for i in 4:
		ci.draw_line(Vector2(-6.0, -10.0 + float(i) * 3.4 - bob), Vector2(6.0, -8.0 + float(i) * 3.4 - bob), dk, 1.0)
	# lengan terjulur ke depan (naik saat menembak)
	var up: float = atk * 4.0
	ci.draw_line(Vector2(4.0, -9.0 - bob), Vector2(13.0, -9.0 - up - bob), wrap, 3.0)
	ci.draw_line(Vector2(-3.0, -9.0 - bob), Vector2(8.0, -11.0 - up - bob), dk, 3.0)
	if atk > 0.2:
		ci.draw_circle(Vector2(15.0, -9.0 - up - bob), 2.0 + atk * 2.0, Color(0.9, 0.8, 0.35, 0.6))
	# kepala dibalut + mata menyala + perban menjuntai
	var hy: float = -17.0 - bob
	ellipse(ci, Vector2(0.0, hy), 5.6, 5.8, wrap.lightened(0.04), 12)
	ci.draw_line(Vector2(-5.0, hy - 1.0), Vector2(5.0, hy - 2.4), dk, 1.0)
	ci.draw_line(Vector2(-5.0, hy + 2.0), Vector2(5.0, hy + 1.2), dk, 1.0)
	ci.draw_circle(Vector2(-1.8, hy - 0.4), 1.1, Color(0.4, 1.0, 0.7))
	ci.draw_circle(Vector2(2.4, hy - 0.4), 1.1, Color(0.4, 1.0, 0.7))
	ci.draw_line(Vector2(-5.0, -1.0 - bob), Vector2(-8.0, 4.0 + sin(t * 3.0) * 1.5), dk, 1.4)


static func _centipede(ci: CanvasItem, t: float, biome: String, mv: bool, atk: float) -> void:
	var col: Color = CENTI_COL.get(biome, Color(0.55, 0.3, 0.15))
	var dk: Color = col.darkened(0.35)
	var sp: float = 12.0 if mv else 2.5
	var n: int = 7
	# ruas tubuh berombak dari ekor (kiri) ke kepala (kanan)
	for i in n:
		var u: float = float(i)
		var x: float = -15.0 + u * 4.6 + atk * u * 0.4
		var y: float = 4.0 + sin(t * sp * 0.5 - u * 0.9) * (2.4 if mv else 0.8) - atk * 1.0
		# kaki kiri-kanan
		var wig: float = sin(t * sp + u * 1.3) * (2.0 if mv else 0.6)
		ci.draw_line(Vector2(x, y), Vector2(x - 1.0 + wig, y - 5.5), dk, 1.2)
		ci.draw_line(Vector2(x, y), Vector2(x - 1.0 - wig, y + 5.0), dk, 1.2)
		ellipse(ci, Vector2(x, y), 3.6, 3.4, col if i % 2 == 0 else col.lightened(0.12), 10)
	# kepala + sungut + capit
	var hx: float = -15.0 + float(n) * 4.6 + atk * float(n) * 0.4
	var hy: float = 4.0 + sin(t * sp * 0.5 - float(n) * 0.9) * (2.4 if mv else 0.8) - atk
	ellipse(ci, Vector2(hx, hy), 4.6, 4.0, dk.lightened(0.1), 12)
	ci.draw_circle(Vector2(hx + 1.6, hy - 1.4), 0.9, Color(1.0, 0.9, 0.2))
	ci.draw_line(Vector2(hx + 3.0, hy - 2.6), Vector2(hx + 7.0, hy - 5.4 + sin(t * 6.0)), dk, 1.0)
	var pin: float = 1.0 + atk * 1.6
	ci.draw_line(Vector2(hx + 3.5, hy + 1.6), Vector2(hx + 7.5, hy + 1.0 - pin), Color(0.95, 0.9, 0.7), 1.4)
	ci.draw_line(Vector2(hx + 3.5, hy + 2.6), Vector2(hx + 7.5, hy + 3.2 + pin), Color(0.95, 0.9, 0.7), 1.4)


static func _ogre(ci: CanvasItem, t: float, biome: String, mv: bool, atk: float, red: bool, rage: bool, stun: bool) -> void:
	var skin: Color = OGRE_COL.get(biome, Color(0.5, 0.62, 0.32))
	var cloth := Color(0.42, 0.28, 0.16)
	var horn := Color(0.9, 0.88, 0.75)
	if red:
		skin = Color(0.98, 0.3, 0.14) if rage else Color(0.82, 0.2, 0.18)
		cloth = Color(0.2, 0.13, 0.14)
		horn = Color(0.14, 0.11, 0.11)
	var dk: Color = skin.darkened(0.35)
	var ph: float = t * 6.5
	var step: float = sin(ph) * 2.6 if mv else 0.0
	var bob: float = absf(sin(ph)) * 1.4 if mv else sin(t * 2.0) * 0.6
	if stun:
		bob = 1.5 + sin(t * 20.0) * 0.5
	if rage:
		ci.draw_circle(Vector2(0, -10.0), 24.0 + sin(t * 10.0) * 1.5, Color(1.0, 0.2, 0.1, 0.16))
	# kaki + sepatu
	rect(ci, -10.0 + step * 0.5, 1.0, 8.0, 10.0, dk)
	rect(ci, 2.0 - step * 0.5, 1.0, 8.0, 10.0, dk)
	rect(ci, -11.0 + step * 0.5, 9.0, 10.0, 3.0, Color(0.22, 0.15, 0.1))
	rect(ci, 1.0 - step * 0.5, 9.0, 10.0, 3.0, Color(0.22, 0.15, 0.1))
	# lengan belakang
	ci.draw_line(Vector2(-11.0, -14.0 - bob), Vector2(-15.0, -4.0 - bob * 0.5), dk, 6.0)
	ci.draw_circle(Vector2(-15.0, -3.0 - bob * 0.5), 3.6, dk)
	# badan, perut, sabuk, cawat
	ellipse(ci, Vector2(0, -9.0 - bob), 13.0, 12.5, skin)
	ellipse(ci, Vector2(1.5, -6.0 - bob), 8.0, 8.0, skin.lightened(0.14), 12)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-8.0, 3.0 - bob), Vector2(8.0, 3.0 - bob), Vector2(5.0, 10.0), Vector2(-5.0, 10.0)]), cloth)
	rect(ci, -12.0, -1.5 - bob, 24.0, 4.0, cloth.darkened(0.2))
	ci.draw_circle(Vector2(0, 0.5 - bob), 2.2, Color(0.95, 0.8, 0.3) if red else Color(0.7, 0.7, 0.74))
	# hiasan biome
	if biome == "snow" and not red:
		ellipse(ci, Vector2(0, -18.0 - bob), 14.0, 4.2, Color(0.96, 0.98, 1.0), 12)
	elif biome == "desert" and not red:
		rect(ci, -15.5, -9.0 - bob, 3.0, 2.2, Color(1.0, 0.85, 0.3))
	elif biome == "volcano":
		ci.draw_line(Vector2(-4.0, -13.0 - bob), Vector2(0.0, -8.0 - bob), Color(1.0, 0.5, 0.1), 1.2)
		ci.draw_line(Vector2(0.0, -8.0 - bob), Vector2(-2.0, -4.0 - bob), Color(1.0, 0.5, 0.1), 1.2)
	if red:
		for sx in [-9.0, 9.0]:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(sx - 2.5, -18.0 - bob), Vector2(sx, -25.0 - bob), Vector2(sx + 2.5, -18.0 - bob)]), Color(0.75, 0.75, 0.78))
	# kepala
	var hy: float = -24.0 - bob
	ellipse(ci, Vector2(-5.0, hy + 1.0), 2.8, 3.4, dk, 8)
	ellipse(ci, Vector2(2.0, hy), 9.0, 8.0, skin)
	ci.draw_line(Vector2(-3.0, hy - 3.6), Vector2(3.0, hy - 2.2), dk, 2.2)
	ci.draw_line(Vector2(4.0, hy - 2.6), Vector2(9.0, hy - 3.4), dk, 2.0)
	var eye := Color(1.0, 0.95, 0.5) if red else Color(1.0, 0.85, 0.2)
	ci.draw_circle(Vector2(0.0, hy - 0.6), 1.6, eye)
	ci.draw_circle(Vector2(6.0, hy - 0.8), 1.8, eye)
	ci.draw_circle(Vector2(0.4, hy - 0.6), 0.7, Color(0.15, 0.0, 0.0))
	ci.draw_circle(Vector2(6.4, hy - 0.8), 0.7, Color(0.15, 0.0, 0.0))
	ci.draw_line(Vector2(-1.0, hy + 4.0), Vector2(8.0, hy + 4.0), Color(0.12, 0.04, 0.04), 1.4)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0.0, hy + 4.4), Vector2(2.4, hy + 4.4), Vector2(1.4, hy - 0.4)]), Color(0.97, 0.95, 0.85))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(5.0, hy + 4.4), Vector2(7.4, hy + 4.4), Vector2(6.4, hy - 0.4)]), Color(0.97, 0.95, 0.85))
	if red:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-3.0, hy - 5.0), Vector2(-7.0, hy - 14.0), Vector2(0.0, hy - 7.0)]), horn)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(6.0, hy - 6.0), Vector2(10.0, hy - 15.0), Vector2(11.0, hy - 5.0)]), horn)
	else:
		for k in 3:
			ci.draw_line(Vector2(-2.0 + k * 3.5, hy - 7.0), Vector2(-3.0 + k * 4.5, hy - 11.0), dk.darkened(0.3), 1.5)
	# lengan depan memegang gada berduri; terangkat saat bersiap menghantam
	var sh := Vector2(11.0, -15.0 - bob)
	var hand: Vector2 = sh + Vector2(5.0, 7.0).lerp(Vector2(-2.0, -11.0), clampf(atk, 0.0, 1.0))
	ci.draw_line(sh, hand, skin, 6.0)
	var ang: float = lerpf(-0.9, -2.3, clampf(atk, 0.0, 1.0))
	var tip: Vector2 = hand + Vector2.from_angle(ang) * 19.0
	ci.draw_line(hand, tip, Color(0.4, 0.27, 0.14), 4.0)
	ci.draw_circle(tip, 6.0, Color(0.34, 0.22, 0.12))
	for k in 4:
		ci.draw_circle(tip + Vector2.from_angle(ang + (float(k) - 1.5) * 0.8) * 6.0, 1.5, Color(0.78, 0.78, 0.82))
	ci.draw_circle(hand, 3.6, skin)
	if stun:
		for k in 3:
			var a: float = t * 6.0 + float(k) * TAU / 3.0
			ci.draw_circle(Vector2(2.0 + cos(a) * 9.0, hy - 11.0 + sin(a) * 2.5), 1.4, Color(1.0, 0.95, 0.4))


# ================================================================== BOS
# o: style(ent|scorpion|yeti|dragon) t face moving atk phase2
static func draw_boss(ci: CanvasItem, o: Dictionary) -> void:
	var style: String = String(o["style"])
	var t: float = float(o["t"])
	var face: float = float(o.get("face", 1.0))
	var atk: float = float(o.get("atk", 0.0))
	var p2: bool = bool(o.get("phase2", false))
	var mv: bool = bool(o.get("moving", false))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(face, 1.0))
	match style:
		"ent":
			_boss_ent(ci, t, atk, p2, mv)
		"scorpion":
			_boss_scorpion(ci, t, atk, p2, mv)
		"yeti":
			_boss_yeti(ci, t, atk, p2, mv)
		_:
			_boss_dragon(ci, t, atk, p2, mv)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _boss_ent(ci: CanvasItem, t: float, atk: float, p2: bool, mv: bool) -> void:
	var bark := Color(0.42, 0.27, 0.15)
	var w: float = sin(t * 5.0) * 3.0 if mv else 0.0
	ci.draw_line(Vector2(-10, 14), Vector2(-14 + w, 28), bark.darkened(0.2), 8.0)
	ci.draw_line(Vector2(10, 14), Vector2(14 - w, 28), bark.darkened(0.2), 8.0)
	ci.draw_line(Vector2(-14 + w, 28), Vector2(-20 + w, 30), bark.darkened(0.2), 4.0)
	ci.draw_line(Vector2(14 - w, 28), Vector2(20 - w, 30), bark.darkened(0.2), 4.0)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-17, 20), Vector2(-13, -16), Vector2(13, -16), Vector2(17, 20)]), bark)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, 18), Vector2(-7, -12), Vector2(7, -12), Vector2(8, 18)]), bark.lightened(0.12))
	for i in 4:
		ci.draw_line(Vector2(-12 + i * 8, 16), Vector2(-11 + i * 8, -10), bark.darkened(0.35), 1.0)
	var arm_up: float = atk * 14.0
	for s in [-1.0, 1.0]:
		var sw: float = sin(t * 2.0 + s) * 2.0
		var hand := Vector2(s * 30.0, 6.0 - arm_up + sw)
		ci.draw_line(Vector2(s * 14.0, -6.0), hand, bark.darkened(0.1), 8.0)
		ci.draw_circle(hand, 6.0, Color(0.25, 0.6, 0.25))
		ci.draw_circle(hand + Vector2(2, -2), 3.5, Color(0.35, 0.75, 0.3))
	var leaf := Color(0.2, 0.55, 0.22) if not p2 else Color(0.75, 0.45, 0.15)
	for k in [Vector2(-16, -22), Vector2(0, -30), Vector2(16, -22), Vector2(-8, -18), Vector2(9, -19), Vector2(-24, -14), Vector2(24, -14)]:
		ci.draw_circle(k + Vector2(0, sin(t * 2.0 + k.x) * 1.0), 11.0, leaf)
		ci.draw_circle(k + Vector2(-3, -3), 6.0, leaf.lightened(0.18))
	var eye := Color(1.0, 0.8, 0.2) if not p2 else Color(1.0, 0.25, 0.15)
	ellipse(ci, Vector2(-6, -6), 3.0, 2.2, eye, 8)
	ellipse(ci, Vector2(6, -6), 3.0, 2.2, eye, 8)
	ci.draw_circle(Vector2(-6, -6), 1.0, Color.BLACK)
	ci.draw_circle(Vector2(6, -6), 1.0, Color.BLACK)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, 4), Vector2(-3, 2), Vector2(0, 5), Vector2(3, 2), Vector2(6, 4), Vector2(3, 9), Vector2(-3, 9)]), Color(0.15, 0.08, 0.05))


static func _boss_scorpion(ci: CanvasItem, t: float, atk: float, p2: bool, mv: bool) -> void:
	var sh := Color(0.78, 0.55, 0.25) if not p2 else Color(0.7, 0.25, 0.2)
	var dk: Color = sh.darkened(0.4)
	var w: float = sin(t * 12.0) * 3.0 if mv else 0.0
	for i in 4:
		var lx: float = -12.0 + i * 8.0
		var sg: float = 1.0 if i % 2 == 0 else -1.0
		ci.draw_line(Vector2(lx, 6), Vector2(lx - 4 + w * sg, 20), dk, 2.0)
		ci.draw_line(Vector2(lx, 6), Vector2(lx + 4 + w * sg, 20), dk, 2.0)
	# ekor melengkung
	var tail_up: float = atk * 8.0
	var prev := Vector2(-18, 0)
	for i in 7:
		var u: float = float(i) / 6.0
		var p := Vector2(-22.0 - sin(u * 2.6) * 6.0, -4.0 - u * 30.0 - tail_up * u + sin(t * 3.0 + u * 3.0) * 1.5)
		ci.draw_line(prev, p, dk, 7.0 - u * 2.0)
		ci.draw_circle(p, 5.0 - u * 1.5, sh)
		prev = p
	ci.draw_colored_polygon(PackedVector2Array([prev + Vector2(-3, -2), prev + Vector2(6, 4), prev + Vector2(2, 10)]), Color(0.95, 0.9, 0.5))
	ellipse(ci, Vector2(0, 0), 24.0, 15.0, dk)
	ellipse(ci, Vector2(0, -1), 23.0, 14.0, sh)
	for i in 4:
		ci.draw_line(Vector2(-14 + i * 9, -11), Vector2(-14 + i * 9, 9), dk, 1.0)
	for s in [1.0]:
		for c in [-1.0, 1.0]:
			var sh2 := Vector2(18.0, c * 8.0)
			var hand := Vector2(34.0 + sin(t * 3.0 + c) * 2.0 + atk * 6.0, c * 16.0)
			ci.draw_line(sh2, hand, dk, 5.0)
			ci.draw_colored_polygon(PackedVector2Array([hand + Vector2(-4, -5), hand + Vector2(10, -3), hand + Vector2(10, 3), hand + Vector2(-4, 5)]), sh)
			ci.draw_line(hand + Vector2(1, 0), hand + Vector2(10, 0), dk, 1.0)
	ci.draw_circle(Vector2(20, -4), 1.8, Color(1.0, 0.2, 0.2))
	ci.draw_circle(Vector2(20, 4), 1.8, Color(1.0, 0.2, 0.2))


static func _boss_yeti(ci: CanvasItem, t: float, atk: float, p2: bool, mv: bool) -> void:
	var fur := Color(0.92, 0.96, 1.0) if not p2 else Color(0.8, 0.88, 1.0)
	var sh: Color = fur.darkened(0.15)
	var w: float = sin(t * 5.0) * 3.0 if mv else 0.0
	ellipse(ci, Vector2(-9, 24 + w * 0.3), 8.0, 6.0, sh)
	ellipse(ci, Vector2(9, 24 - w * 0.3), 8.0, 6.0, sh)
	ellipse(ci, Vector2(0, 6), 22.0, 22.0, sh)
	ellipse(ci, Vector2(0, 4), 21.0, 21.0, fur)
	var up: float = atk * 22.0
	for s in [-1.0, 1.0]:
		var hand := Vector2(s * 28.0, 12.0 - up + sin(t * 2.0 + s) * 2.0)
		ci.draw_line(Vector2(s * 16.0, -4.0), hand, sh, 12.0)
		ellipse(ci, hand, 8.0, 8.0, fur)
		for k in 3:
			ci.draw_circle(hand + Vector2(-3 + k * 3, 6), 1.3, Color(0.3, 0.35, 0.5))
	ellipse(ci, Vector2(0, -12), 13.0, 11.0, fur)
	ellipse(ci, Vector2(0, -10), 9.0, 7.5, Color(0.4, 0.55, 0.8))
	ci.draw_circle(Vector2(-4, -12), 2.0, Color(0.7, 1.0, 1.0))
	ci.draw_circle(Vector2(4, -12), 2.0, Color(0.7, 1.0, 1.0))
	ci.draw_circle(Vector2(-4, -12), 0.8, Color.BLACK)
	ci.draw_circle(Vector2(4, -12), 0.8, Color.BLACK)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-5, -6), Vector2(5, -6), Vector2(0, -2)]), Color(0.15, 0.1, 0.2))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-4, -6), Vector2(-2, -6), Vector2(-3, -3)]), Color.WHITE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(2, -6), Vector2(4, -6), Vector2(3, -3)]), Color.WHITE)
	for k in [-1.0, 0.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(k * 7 - 3, -20), Vector2(k * 7 + 3, -20), Vector2(k * 7, -30 + absf(k) * 4)]), Color(0.6, 0.9, 1.0, 0.9))


static func _boss_dragon(ci: CanvasItem, t: float, atk: float, p2: bool, mv: bool) -> void:
	var sk := Color(0.75, 0.15, 0.12) if not p2 else Color(0.5, 0.1, 0.35)
	var fl: float = sin(t * 4.0) * 8.0
	for s in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(s * 10, -4), Vector2(s * 34, -26 + fl), Vector2(s * 40, -6 + fl * 0.5),
			Vector2(s * 30, 0), Vector2(s * 26, 8), Vector2(s * 10, 6)]), sk.darkened(0.25))
		ci.draw_line(Vector2(s * 10, -2), Vector2(s * 34, -24 + fl), sk.darkened(0.5), 1.5)
	var tl := Vector2(0, 26)
	for i in 6:
		var u: float = float(i) / 5.0
		var p := Vector2(sin(t * 3.0 + u * 3.0) * 8.0 * u, 26.0 + u * 14.0)
		ci.draw_circle(p, 9.0 - u * 6.0, sk.darkened(0.15))
		tl = p
	ci.draw_colored_polygon(PackedVector2Array([tl + Vector2(-4, 2), tl + Vector2(4, 2), tl + Vector2(0, 9)]), Color(1.0, 0.5, 0.2))
	ellipse(ci, Vector2(0, 8), 17.0, 20.0, sk.darkened(0.2))
	ellipse(ci, Vector2(0, 8), 16.0, 19.0, sk)
	for i in 5:
		ellipse(ci, Vector2(0, -2.0 + i * 6.0), 8.0, 2.6, Color(1.0, 0.85, 0.5), 8)
	for s in [-1.0, 1.0]:
		ci.draw_line(Vector2(s * 12, 14), Vector2(s * 16, 30), sk.darkened(0.2), 6.0)
		ci.draw_circle(Vector2(s * 16, 30), 4.0, sk.darkened(0.2))
	ellipse(ci, Vector2(0, -16), 12.0, 10.0, sk)
	ellipse(ci, Vector2(0, -9), 8.0, 6.0, sk.lightened(0.15))
	for s in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([Vector2(s * 7, -23), Vector2(s * 14, -36), Vector2(s * 3, -25)]), Color(0.95, 0.9, 0.7))
		ci.draw_circle(Vector2(s * 5, -17), 2.2, Color(1.0, 0.85, 0.2))
		ci.draw_circle(Vector2(s * 5, -17), 0.9, Color.BLACK)
		ci.draw_circle(Vector2(s * 3, -10), 0.9, Color(0.2, 0.05, 0.05))
	if atk > 0.0:
		ci.draw_circle(Vector2(0, -6), 6.0 + atk * 10.0, Color(1.0, 0.55, 0.15, 0.55))
		ci.draw_circle(Vector2(0, -6), 3.0 + atk * 5.0, Color(1.0, 0.9, 0.4, 0.8))


# ================================================================== BANGUNAN & PROPS
# Rumah desa: w x h tile (32px). Digambar dari pojok kiri-atas (px, py).
static func draw_house(ci: CanvasItem, px: float, py: float, w: int, h: int, kind: String, variant: int, biome: int = 0) -> void:
	var W: float = w * 32.0
	var H: float = h * 32.0
	# sprite rumah PNG (assets/houses). Kalau file tidak ada, jatuh balik ke gambar kode di bawah.
	var hname: String = HOUSE_SPR.get(kind, "")
	if hname == "":
		hname = String(HOUSE_VARIANTS[variant % HOUSE_VARIANTS.size()])
	var ht: Texture2D = null
	if biome > 0 and not HOUSE_SPR.has(kind):
		ht = tex("res://assets/houses/b%d_%s.png" % [biome, hname])     # rumah khas biome
	if ht == null:
		ht = tex("res://assets/houses/%s.png" % hname)
	if ht != null:
		ci.draw_texture(ht, Vector2(floorf(px + (W - ht.get_width()) / 2.0), py + H - ht.get_height() + 2.0))
		return
	var roofs := [Color(0.75, 0.3, 0.25), Color(0.3, 0.45, 0.7), Color(0.6, 0.45, 0.25), Color(0.35, 0.6, 0.4), Color(0.6, 0.35, 0.55)]
	var roof: Color = roofs[variant % roofs.size()]
	var wall := Color(0.9, 0.82, 0.65)
	match kind:
		"smith":
			roof = Color(0.35, 0.35, 0.42)
			wall = Color(0.6, 0.55, 0.5)
		"shop":
			roof = Color(0.85, 0.6, 0.2)
		"healer":
			roof = Color(0.3, 0.65, 0.55)
			wall = Color(0.95, 0.95, 0.95)
		"gacha":
			roof = Color(0.65, 0.3, 0.8)
			wall = Color(0.95, 0.85, 0.95)
	var roof_h: float = 34.0
	# dinding
	rect(ci, px + 2, py + roof_h - 6, W - 4, H - roof_h + 6, wall)
	rect(ci, px + 2, py + H - 6, W - 4, 6, wall.darkened(0.25))
	for i in int((W - 4) / 8.0):
		ci.draw_line(Vector2(px + 4 + i * 8, py + roof_h), Vector2(px + 4 + i * 8, py + H - 6), wall.darkened(0.08), 1.0)
	# atap
	ci.draw_colored_polygon(PackedVector2Array([Vector2(px - 4, py + roof_h), Vector2(px + 14, py), Vector2(px + W - 14, py), Vector2(px + W + 4, py + roof_h)]), roof)
	for i in 4:
		ci.draw_line(Vector2(px - 2 + i * 1.0, py + 8 + i * 7), Vector2(px + W + 2 - i * 1.0, py + 8 + i * 7), roof.darkened(0.25), 1.0)
	ci.draw_line(Vector2(px - 4, py + roof_h), Vector2(px + W + 4, py + roof_h), roof.darkened(0.5), 2.0)
	# pintu
	var dx: float = px + W / 2.0 - 7.0
	var dy: float = py + H - 26.0
	rect(ci, dx, dy, 14, 26, Color(0.4, 0.25, 0.14))
	rect(ci, dx + 2, dy + 2, 10, 24, Color(0.5, 0.32, 0.18))
	ci.draw_circle(Vector2(dx + 11, dy + 14), 1.2, Color(1, 0.85, 0.3))
	# jendela
	if w >= 4:
		for sx in [px + 10.0, px + W - 28.0]:
			rect(ci, sx, py + roof_h + 8, 18, 14, Color(0.35, 0.22, 0.12))
			rect(ci, sx + 2, py + roof_h + 10, 14, 10, Color(0.65, 0.85, 1.0))
			ci.draw_line(Vector2(sx + 9, py + roof_h + 10), Vector2(sx + 9, py + roof_h + 20), Color(0.35, 0.22, 0.12), 1.0)
	# ciri khas
	match kind:
		"smith":
			rect(ci, px + W - 18, py - 10, 10, 22, Color(0.3, 0.3, 0.35))
			ci.draw_circle(Vector2(px + W - 13, py - 14), 4.0, Color(0.7, 0.7, 0.75, 0.6))
			ci.draw_line(Vector2(px + 8, py + H - 10), Vector2(px + 20, py + H - 22), Color(0.8, 0.8, 0.85), 2.0)
		"shop":
			for i in 5:
				rect(ci, px + 6 + i * ((W - 12) / 5.0), py + roof_h - 2, (W - 12) / 10.0, 8, Color(0.95, 0.95, 0.95))
		"healer":
			rect(ci, px + W / 2.0 - 2, py + 12, 4, 14, Color(0.9, 0.2, 0.25))
			rect(ci, px + W / 2.0 - 7, py + 17, 14, 4, Color(0.9, 0.2, 0.25))
		"gacha":
			ci.draw_circle(Vector2(px + W / 2.0, py + 18), 8.0, Color(1.0, 0.85, 0.3))
			ci.draw_circle(Vector2(px + W / 2.0, py + 18), 5.0, Color(1.0, 0.5, 0.8))
		_:
			rect(ci, px + 8, py - 8, 8, 18, Color(0.5, 0.35, 0.3))


# Batu/bijih: atlas assets/props/rocks_sheet.png (dibuat tools/gen_rock_sprites.py), sel 48x48,
# 12 varian ukuran per baris. Kalau atlas tidak ada, jatuh balik ke gambar kode di bawah.
const ROCK_SHEET := "res://assets/props/rocks_sheet.png"
const ROCK_CELL := 48
const ROCK_VARIANTS := 12
const ROCK_ROW := {"stone": 0, "moss": 1, "copper": 2, "iron": 3, "gold": 4, "crystal": 5, "ruby": 6, "coal": 7, "obsidian": 8}
const ROCK_TINT := {"desert": Color(1.0, 0.88, 0.7), "snow": Color(0.92, 0.97, 1.0), "volcano": Color(0.55, 0.5, 0.55)}


static func draw_rock(ci: CanvasItem, c: Vector2, ore: String, biome: String, variant: int = 0) -> void:
	var t: Texture2D = tex(ROCK_SHEET)
	if t == null:
		_draw_rock_code(ci, c, ore, biome)
		return
	var key := ore
	var tint := Color.WHITE
	if ore == "stone":
		key = "moss" if biome == "forest" else "stone"
		tint = ROCK_TINT.get(biome, Color.WHITE)
	var row: int = int(ROCK_ROW.get(key, 0))
	var col: int = posmod(variant, ROCK_VARIANTS)
	# dasar batu sejajar dasar sel 32px (c = tengah sel + (0,1))
	var dst := Rect2(c.x - ROCK_CELL * 0.5, c.y + 12.0 - (ROCK_CELL - 2.0), ROCK_CELL, ROCK_CELL)
	ci.draw_texture_rect_region(t, dst, Rect2(col * ROCK_CELL, row * ROCK_CELL, ROCK_CELL, ROCK_CELL), tint)


static func _draw_rock_code(ci: CanvasItem, c: Vector2, ore: String, biome: String) -> void:
	var base := Color(0.55, 0.56, 0.62)
	match biome:
		"desert":
			base = Color(0.72, 0.6, 0.42)
		"snow":
			base = Color(0.7, 0.75, 0.85)
		"volcano":
			base = Color(0.3, 0.26, 0.3)
	var pts := PackedVector2Array([c + Vector2(-12, 10), c + Vector2(-14, 0), c + Vector2(-7, -10), c + Vector2(3, -12), c + Vector2(12, -5), c + Vector2(14, 6), c + Vector2(8, 11)])
	ci.draw_colored_polygon(pts, base.darkened(0.3))
	var pts2 := PackedVector2Array([c + Vector2(-10, 8), c + Vector2(-11, -1), c + Vector2(-5, -8), c + Vector2(3, -9), c + Vector2(10, -4), c + Vector2(11, 5), c + Vector2(6, 9)])
	ci.draw_colored_polygon(pts2, base)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -2), c + Vector2(-4, -7), c + Vector2(2, -8), c + Vector2(-2, -3)]), base.lightened(0.25))
	if ore != "stone":
		var oc: Color = Items.info(ore)["color"]
		for k in [Vector2(-4, 0), Vector2(4, -3), Vector2(1, 5), Vector2(-6, 6), Vector2(7, 3)]:
			ci.draw_circle(c + k, 2.2, oc.darkened(0.3))
			ci.draw_circle(c + k + Vector2(-0.4, -0.4), 1.5, oc)


static func draw_stump(ci: CanvasItem, c: Vector2) -> void:
	ellipse(ci, c + Vector2(0, 6), 8.0, 4.0, Color(0.35, 0.22, 0.12))
	rect(ci, c.x - 7, c.y, 14, 6, Color(0.45, 0.3, 0.16))
	ellipse(ci, c + Vector2(0, 0), 7.0, 3.5, Color(0.72, 0.55, 0.32))
	ellipse(ci, c + Vector2(0, 0), 3.5, 1.8, Color(0.6, 0.43, 0.24))


static func draw_gacha_machine(ci: CanvasItem, c: Vector2, t: float) -> void:
	rect(ci, c.x - 10, c.y - 6, 20, 18, Color(0.7, 0.25, 0.4))
	rect(ci, c.x - 12, c.y + 10, 24, 4, Color(0.3, 0.15, 0.25))
	ellipse(ci, c + Vector2(0, -12), 12.0, 11.0, Color(0.75, 0.9, 1.0, 0.55))
	var cols := [Color(1, 0.4, 0.4), Color(0.4, 0.8, 1), Color(1, 0.9, 0.3), Color(0.6, 1, 0.5), Color(0.9, 0.5, 1)]
	for i in 5:
		ci.draw_circle(c + Vector2(-6 + (i % 3) * 6, -14 + (i / 3) * 6 + sin(t * 3.0 + i) * 1.0), 3.0, cols[i])
	rect(ci, c.x - 3, c.y + 2, 6, 5, Color(0.1, 0.05, 0.1))
	ci.draw_circle(c + Vector2(0, -22), 2.0 + 0.8 * sin(t * 5.0), Color(1.0, 0.9, 0.3))


# ================================================================== IKON ITEM
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float) -> void:
	var d: Dictionary = Items.info(id)
	var col: Color = d["color"]
	var type: String = String(d["type"])
	var u: float = s / 32.0
	if d.has("gsheet"):
		Gear.draw_icon(ci, d, c, s)
		return
	if d.has("icon"):
		ci.draw_set_transform(c, 0.0, Vector2(u, u))
		ci.draw_texture(Raven.icon(int(d["icon"])), Vector2(-16, -16))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	ci.draw_set_transform(c, 0.0, Vector2(u, u))
	if Items.has_png(id):
		var tx: Texture2D = tex("res://assets/items/mat_%s.png" % id)
		if tx:
			ci.draw_texture(tx, -tx.get_size() / 2.0)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
	match type:
		"sword":
			ci.draw_set_transform(c, 0.0, Vector2(u, u))
			draw_sword(ci, d, Vector2(-12, 12), -PI / 4.0, 0.0, Transform2D(0.0, Vector2(u, u), 0.0, c), 1.0)
		"staff":
			var st: Texture2D = tex("res://assets/weapons/staff_%d.png" % int(d["tex"]))
			if st:
				ci.draw_set_transform(c, 0.0, Vector2(u * 0.7, u * 0.7))
				ci.draw_texture(st, -st.get_size() / 2.0)
		"armor":
			_icon_armor(ci, String(d["slot"]), col)
		"fish":
			ellipse(ci, Vector2(-2, 0), 10.0, 6.0, col)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(14, -6), Vector2(14, 6)]), col.darkened(0.2))
			ci.draw_circle(Vector2(-8, -1), 1.4, Color.BLACK)
		"potion":
			rect(ci, -3, -12, 6, 6, Color(0.8, 0.8, 0.85))
			rect(ci, -4, -13, 8, 2, Color(0.55, 0.35, 0.2))
			ci.draw_circle(Vector2(0, 2), 10.0, Color(0.85, 0.9, 1.0, 0.8))
			ci.draw_circle(Vector2(0, 3), 8.0, col)
			ci.draw_circle(Vector2(-3, 0), 2.0, Color(1, 1, 1, 0.6))
		"food":
			if id == "omelet":
				ellipse(ci, Vector2.ZERO, 11.0, 8.0, Color(1.0, 0.95, 0.5))
				ellipse(ci, Vector2(0, 0), 6.0, 4.0, Color(1.0, 0.8, 0.2))
			elif id == "steak":
				ellipse(ci, Vector2.ZERO, 11.0, 8.0, col.darkened(0.3))
				ellipse(ci, Vector2(0, 0), 8.0, 5.5, col)
				ci.draw_line(Vector2(-5, -2), Vector2(5, 2), Color(0.3, 0.1, 0.05), 1.5)
			else:
				ellipse(ci, Vector2(-2, 0), 10.0, 6.0, col)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(14, -6), Vector2(14, 6)]), col.darkened(0.2))
				ci.draw_line(Vector2(-6, -3), Vector2(4, 3), Color(0.35, 0.18, 0.08), 1.5)
		_:
			_icon_mat(ci, id, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _icon_mat(ci: CanvasItem, id: String, col: Color) -> void:
	match id:
		"log":
			rect(ci, -12, -6, 24, 12, col)
			ellipse(ci, Vector2(-12, 0), 4.0, 6.0, col.lightened(0.4), 10)
			ci.draw_circle(Vector2(-12, 0), 2.0, col)
			ci.draw_line(Vector2(-6, -3), Vector2(8, -3), col.darkened(0.3), 1.0)
		"stone":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-11, 7), Vector2(-9, -5), Vector2(0, -10), Vector2(10, -4), Vector2(11, 7)]), col)
			ci.draw_polyline(PackedVector2Array([Vector2(-11, 7), Vector2(-9, -5), Vector2(0, -10), Vector2(10, -4), Vector2(11, 7), Vector2(-11, 7)]), col.darkened(0.4), 1.5)
		"copper", "iron", "gold", "coal", "obsidian":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-11, 7), Vector2(-9, -5), Vector2(0, -10), Vector2(10, -4), Vector2(11, 7)]), Color(0.5, 0.5, 0.56))
			for k in [Vector2(-4, 0), Vector2(4, -3), Vector2(1, 4)]:
				ci.draw_circle(k, 3.0, col)
		"crystal", "ruby":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(8, -2), Vector2(0, 11), Vector2(-8, -2)]), col)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(-8, -2), Vector2(0, 0)]), col.lightened(0.4))
		"egg":
			ellipse(ci, Vector2(0, 1), 7.0, 9.0, col)
			ellipse(ci, Vector2(-2, -3), 2.0, 3.0, Color(1, 1, 1, 0.6), 6)
		"feather":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, 10), Vector2(-6, -2), Vector2(4, -12), Vector2(9, -6), Vector2(0, 4)]), col)
			ci.draw_line(Vector2(-10, 10), Vector2(6, -9), Color(0.7, 0.7, 0.75), 1.0)
		"milk":
			rect(ci, -6, -6, 12, 16, Color(0.95, 0.97, 1.0))
			rect(ci, -4, -11, 8, 5, Color(0.9, 0.92, 0.98))
			rect(ci, -6, 0, 12, 4, Color(0.4, 0.6, 0.95))
		"meat":
			ellipse(ci, Vector2(0, 0), 10.0, 7.0, col)
			ellipse(ci, Vector2(-2, -1), 5.0, 3.0, col.lightened(0.25), 8)
			rect(ci, 8, -2, 7, 4, Color(0.95, 0.92, 0.85))
		"leather":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-11, -8), Vector2(11, -8), Vector2(9, 0), Vector2(11, 9), Vector2(-11, 9), Vector2(-9, 0)]), col)
			ci.draw_line(Vector2(-6, -4), Vector2(6, 5), col.darkened(0.3), 1.0)
		"scrap":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, 6), Vector2(-8, -6), Vector2(2, -9), Vector2(10, -3), Vector2(8, 7)]), col)
			ci.draw_circle(Vector2(-3, -1), 2.0, col.darkened(0.45))
			ci.draw_circle(Vector2(4, 2), 1.6, col.lightened(0.3))
			ci.draw_line(Vector2(-9, 4), Vector2(7, -5), col.darkened(0.35), 1.0)
		"web":
			for k in 6:
				ci.draw_line(Vector2.ZERO, Vector2.from_angle(k * TAU / 6.0) * 11.0, col, 1.0)
			for r in [4.0, 7.5, 11.0]:
				ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 12, col.darkened(0.12), 1.0)
		"tusk", "fang", "stinger", "horn":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-5, 10), Vector2(5, 10), Vector2(0, -12)]), col)
			ci.draw_line(Vector2(-1, 8), Vector2(0, -8), col.lightened(0.4), 1.0)
		"venom":
			ci.draw_circle(Vector2(0, 4), 8.0, col)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(0, -12)]), col)
			ci.draw_circle(Vector2(-3, 2), 2.0, Color(1, 1, 1, 0.5))
		"honey":
			rect(ci, -8, -7, 16, 16, Color(1.0, 0.75, 0.15))
			rect(ci, -9, -9, 18, 4, Color(0.65, 0.4, 0.2))
			rect(ci, -5, -2, 10, 6, Color(1.0, 0.9, 0.5))
		_:
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -11), Vector2(10, 0), Vector2(0, 11), Vector2(-10, 0)]), col)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -11), Vector2(-10, 0), Vector2(0, 0)]), col.lightened(0.35))


static func _icon_armor(ci: CanvasItem, slot: String, col: Color) -> void:
	var dk: Color = col.darkened(0.4)
	match slot:
		"chest":
			var pts := PackedVector2Array([Vector2(-8, -11), Vector2(-14, -6), Vector2(-11, 0), Vector2(-8, -2), Vector2(-8, 11), Vector2(8, 11), Vector2(8, -2), Vector2(11, 0), Vector2(14, -6), Vector2(8, -11), Vector2(3, -8), Vector2(-3, -8)])
			ci.draw_colored_polygon(pts, col)
			ci.draw_polyline(pts + PackedVector2Array([pts[0]]), dk, 1.5)
			ci.draw_line(Vector2(0, -6), Vector2(0, 10), dk, 1.0)
		"legs":
			var pl := PackedVector2Array([Vector2(-9, -11), Vector2(9, -11), Vector2(10, 11), Vector2(2, 11), Vector2(0, -2), Vector2(-2, 11), Vector2(-10, 11)])
			ci.draw_colored_polygon(pl, col)
			ci.draw_polyline(pl + PackedVector2Array([pl[0]]), dk, 1.5)
			rect(ci, -9, -11, 18, 3, col.lightened(0.25))
		"boots":
			var pb := PackedVector2Array([Vector2(-6, -10), Vector2(3, -10), Vector2(3, 2), Vector2(12, 6), Vector2(12, 11), Vector2(-6, 11)])
			ci.draw_colored_polygon(pb, col)
			ci.draw_polyline(pb + PackedVector2Array([pb[0]]), dk, 1.5)
			rect(ci, -6, -10, 9, 3, col.lightened(0.25))
		"gloves":
			var pg := PackedVector2Array([Vector2(-7, 10), Vector2(-8, -2), Vector2(-5, -10), Vector2(-2, -4), Vector2(0, -12), Vector2(3, -4), Vector2(6, -9), Vector2(8, 0), Vector2(7, 10)])
			ci.draw_colored_polygon(pg, col)
			ci.draw_polyline(pg + PackedVector2Array([pg[0]]), dk, 1.5)
			rect(ci, -7, 6, 14, 5, col.lightened(0.25))
		_:
			var ps := PackedVector2Array([Vector2(-11, -11), Vector2(11, -11), Vector2(11, 0), Vector2(0, 13), Vector2(-11, 0)])
			ci.draw_colored_polygon(ps, col)
			ci.draw_polyline(ps + PackedVector2Array([ps[0]]), dk, 1.5)
			ci.draw_circle(Vector2(0, -2), 4.0, col.lightened(0.4))
			ci.draw_line(Vector2(0, -11), Vector2(0, 11), dk, 1.0)


static func draw_currency(ci: CanvasItem, kind: String, c: Vector2, r: float) -> void:
	if kind == "coin":
		ci.draw_circle(c, r, Color(0.75, 0.55, 0.1))
		ci.draw_circle(c, r * 0.82, Color(1.0, 0.82, 0.25))
		ci.draw_circle(c, r * 0.5, Color(0.95, 0.7, 0.15))
	else:
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.85, -r * 0.1), c + Vector2(0, r), c + Vector2(-r * 0.85, -r * 0.1)])
		ci.draw_colored_polygon(pts, Color(0.3, 0.85, 1.0))
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(-r * 0.85, -r * 0.1), c + Vector2(0, -r * 0.1)]), Color(0.7, 1.0, 1.0))
		ci.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.1, 0.4, 0.6), 1.2)


# Ikon tombol HUD: "sword" "magic" "hand" "bag" "gear" "potion_hp" "potion_mp"
static func draw_hud_icon(ci: CanvasItem, kind: String, c: Vector2, r: float, sword: Dictionary = {}) -> void:
	var u: float = r / 20.0
	match kind:
		"sword":
			if sword.is_empty():
				return
			draw_sword(ci, sword, Vector2(-12, 12), -PI / 4.0, 0.0, Transform2D(0.0, Vector2(u, u), 0.0, c), 1.0)
			ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		"magic":
			ci.draw_circle(c, 9.0 * u, Color(0.4, 0.8, 1.0, 0.35))
			ci.draw_circle(c, 6.0 * u, Color(0.5, 0.9, 1.0))
			ci.draw_circle(c, 3.0 * u, Color.WHITE)
			for i in 4:
				var a: float = TAU * i / 4.0 + 0.4
				ci.draw_line(c + Vector2.from_angle(a) * 9.0 * u, c + Vector2.from_angle(a) * 14.0 * u, Color(0.7, 0.95, 1.0), 2.0)
		"hand":
			rect(ci, c.x - 7 * u, c.y - 2 * u, 14 * u, 11 * u, Color(0.97, 0.79, 0.65))
			for i in 4:
				rect(ci, c.x - 7 * u + i * 3.6 * u, c.y - 10 * u + absf(i - 1.5) * 1.5 * u, 3.0 * u, 10 * u, Color(0.97, 0.79, 0.65))
			rect(ci, c.x - 11 * u, c.y, 5 * u, 3 * u, Color(0.97, 0.79, 0.65))
		"bag":
			ellipse(ci, c + Vector2(0, 3 * u), 11 * u, 10 * u, Color(0.65, 0.42, 0.22))
			rect(ci, c.x - 5 * u, c.y - 10 * u, 10 * u, 5 * u, Color(0.5, 0.32, 0.16))
			rect(ci, c.x - 6 * u, c.y + 1 * u, 12 * u, 3 * u, Color(0.4, 0.25, 0.12))
			ci.draw_circle(c + Vector2(0, 2.5 * u), 1.8 * u, Color(1, 0.85, 0.3))
		"gear":
			ci.draw_circle(c, 9 * u, Color(0.8, 0.82, 0.88))
			for i in 8:
				var a2: float = TAU * i / 8.0
				ci.draw_line(c + Vector2.from_angle(a2) * 8 * u, c + Vector2.from_angle(a2) * 13 * u, Color(0.8, 0.82, 0.88), 4.0 * u)
			ci.draw_circle(c, 4 * u, Color(0.25, 0.27, 0.35))
		"potion_hp":
			draw_icon(ci, "potion_hp", c, r * 1.7)
		"potion_mp":
			draw_icon(ci, "potion_mp", c, r * 1.7)
