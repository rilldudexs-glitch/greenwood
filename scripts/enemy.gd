extends CharacterBody2D
# Monster dunia terbuka: slime, bee, cow, chicken, snake, fiend, wisp, goblin, spider, ogre, red_ogre,
# + musuh baru: wolf, kobold, bat, bear, golem, mummy, centipede.
# Bisa juga jadi mini boss (is_mini, lihat Bal.MINI): lebih besar, HP tetap, jurus lebih galak.
# Cow & chicken pasif (kabur kalau diserang); lainnya agresif.
# Musuh yang jauh dari pemain dimatikan oleh LOD di main.gd (group "lod").

const Art = preload("res://scripts/art.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Bal = preload("res://scripts/balance.gd")
const Story = preload("res://scripts/story.gd")

const BASE := {
	# hp, dmg, speed, xp, radius, aggro, passive, bar = tinggi bar HP di atas kepala
	"slime": {"hp": 30, "dmg": 8, "spd": 48.0, "xp": 6, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Slime"},
	"bee": {"hp": 18, "dmg": 6, "spd": 78.0, "xp": 5, "r": 8.0, "aggro": 140.0, "passive": false, "name": "Lebah"},
	"cow": {"hp": 40, "dmg": 0, "spd": 40.0, "xp": 4, "r": 12.0, "aggro": 0.0, "passive": true, "name": "Sapi"},
	"chicken": {"hp": 14, "dmg": 0, "spd": 46.0, "xp": 2, "r": 8.0, "aggro": 0.0, "passive": true, "name": "Ayam"},
	"snake": {"hp": 28, "dmg": 10, "spd": 62.0, "xp": 8, "r": 9.0, "aggro": 130.0, "passive": false, "name": "Ular"},
	"fiend": {"hp": 55, "dmg": 14, "spd": 50.0, "xp": 16, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Fiend"},
	"wisp": {"hp": 32, "dmg": 10, "spd": 44.0, "xp": 12, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Wisp"},
	"goblin": {"hp": 40, "dmg": 9, "spd": 62.0, "xp": 11, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Goblin", "bar": 26.0},
	"spider": {"hp": 30, "dmg": 8, "spd": 74.0, "xp": 10, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Laba-laba", "bar": 18.0},
	"ogre": {"hp": 170, "dmg": 20, "spd": 34.0, "xp": 38, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Ogre", "bar": 40.0},
	"red_ogre": {"hp": 300, "dmg": 28, "spd": 40.0, "xp": 85, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Ogre Merah", "bar": 44.0},
	# --- musuh baru
	"wolf": {"hp": 45, "dmg": 11, "spd": 76.0, "xp": 12, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Serigala", "bar": 22.0},
	"kobold": {"hp": 32, "dmg": 8, "spd": 64.0, "xp": 9, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Kobold", "bar": 24.0},
	"bat": {"hp": 20, "dmg": 7, "spd": 88.0, "xp": 7, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Kelelawar", "bar": 24.0},
	"bear": {"hp": 160, "dmg": 22, "spd": 44.0, "xp": 40, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Beruang", "bar": 34.0},
	"golem": {"hp": 230, "dmg": 24, "spd": 28.0, "xp": 50, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Golem", "bar": 40.0},
	"mummy": {"hp": 70, "dmg": 13, "spd": 36.0, "xp": 20, "r": 10.0, "aggro": 150.0, "passive": false, "name": "Mumi", "bar": 28.0},
	"centipede": {"hp": 60, "dmg": 12, "spd": 68.0, "xp": 18, "r": 10.0, "aggro": 160.0, "passive": false, "name": "Kelabang", "bar": 20.0},
	"umbral_slime": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 8, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Umbral Slime", "base_kind": "slime"},
	"gloomfang_wolf": {"hp": 51, "dmg": 12, "spd": 76.0, "xp": 16, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Gloomfang Wolf", "base_kind": "wolf", "bar": 22.0},
	"shade_stalker": {"hp": 51, "dmg": 12, "spd": 76.0, "xp": 16, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Shade Stalker", "base_kind": "wolf", "bar": 22.0},
	"dusk_bat": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 9, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Dusk Bat", "base_kind": "bat", "bar": 24.0},
	"night_kobold": {"hp": 36, "dmg": 8, "spd": 64.0, "xp": 12, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Night Kobold", "base_kind": "kobold", "bar": 24.0},
	"eclipse_spider": {"hp": 34, "dmg": 8, "spd": 74.0, "xp": 13, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Eclipse Spider", "base_kind": "spider", "bar": 18.0},
	"hollow_wisp": {"hp": 36, "dmg": 11, "spd": 44.0, "xp": 16, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Hollow Wisp", "base_kind": "wisp"},
	"gravebound_ogre": {"hp": 195, "dmg": 22, "spd": 34.0, "xp": 51, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Gravebound Ogre", "base_kind": "ogre", "bar": 40.0},
	"ashen_fiend": {"hp": 63, "dmg": 15, "spd": 50.0, "xp": 21, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Ashen Fiend", "base_kind": "fiend"},
	"rift_serpent": {"hp": 32, "dmg": 11, "spd": 62.0, "xp": 10, "r": 9.0, "aggro": 130.0, "passive": false, "name": "Rift Serpent", "base_kind": "snake"},
	"null_crawler": {"hp": 69, "dmg": 13, "spd": 68.0, "xp": 24, "r": 10.0, "aggro": 160.0, "passive": false, "name": "Null Crawler", "base_kind": "centipede", "bar": 20.0},
	"glitch_golem": {"hp": 264, "dmg": 26, "spd": 28.0, "xp": 67, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Glitch Golem", "base_kind": "golem", "bar": 40.0},
	"abyss_eel": {"hp": 32, "dmg": 11, "spd": 62.0, "xp": 10, "r": 9.0, "aggro": 130.0, "passive": false, "name": "Abyss Eel", "base_kind": "snake"},
	"deep_maw": {"hp": 69, "dmg": 13, "spd": 68.0, "xp": 24, "r": 10.0, "aggro": 160.0, "passive": false, "name": "Deep Maw", "base_kind": "centipede", "bar": 20.0},
	"trench_horror": {"hp": 264, "dmg": 26, "spd": 28.0, "xp": 67, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Trench Horror", "base_kind": "golem", "bar": 40.0},
	"blackfin_stalker": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 9, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Blackfin Stalker", "base_kind": "bat", "bar": 24.0},
	"void_jelly": {"hp": 36, "dmg": 11, "spd": 44.0, "xp": 16, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Void Jelly", "base_kind": "wisp"},
	"drowned_mummy": {"hp": 80, "dmg": 14, "spd": 36.0, "xp": 27, "r": 10.0, "aggro": 150.0, "passive": false, "name": "Drowned Mummy", "base_kind": "mummy", "bar": 28.0},
	"thorn_sprite": {"hp": 51, "dmg": 12, "spd": 76.0, "xp": 16, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Thorn Sprite", "base_kind": "wolf", "bar": 22.0},
	"mossback_bear": {"hp": 184, "dmg": 24, "spd": 44.0, "xp": 54, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Mossback Bear", "base_kind": "bear", "bar": 34.0},
	"elder_treantling": {"hp": 264, "dmg": 26, "spd": 28.0, "xp": 67, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Elder Treantling", "base_kind": "golem", "bar": 40.0},
	"briar_goblin": {"hp": 46, "dmg": 10, "spd": 62.0, "xp": 14, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Briar Goblin", "base_kind": "goblin", "bar": 26.0},
	"bloom_wisp": {"hp": 36, "dmg": 11, "spd": 44.0, "xp": 16, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Bloom Wisp", "base_kind": "wisp"},
	"rootbound_ogre": {"hp": 195, "dmg": 22, "spd": 34.0, "xp": 51, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Rootbound Ogre", "base_kind": "ogre", "bar": 40.0},
	"petal_fox": {"hp": 51, "dmg": 12, "spd": 76.0, "xp": 16, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Petal Fox", "base_kind": "wolf", "bar": 22.0},
	"sakura_moth": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 9, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Sakura Moth", "base_kind": "bat", "bar": 24.0},
	"crimson_koi": {"hp": 32, "dmg": 11, "spd": 62.0, "xp": 10, "r": 9.0, "aggro": 130.0, "passive": false, "name": "Crimson Koi", "base_kind": "snake"},
	"blossom_spider": {"hp": 34, "dmg": 8, "spd": 74.0, "xp": 13, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Blossom Spider", "base_kind": "spider", "bar": 18.0},
	"pink_warden": {"hp": 264, "dmg": 26, "spd": 28.0, "xp": 67, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Pink Warden", "base_kind": "golem", "bar": 40.0},
	"fallen_ronin": {"hp": 36, "dmg": 8, "spd": 64.0, "xp": 12, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Fallen Ronin", "base_kind": "kobold", "bar": 24.0},
	"sporeling": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 8, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Sporeling", "base_kind": "slime"},
	"mushroom_brute": {"hp": 195, "dmg": 22, "spd": 34.0, "xp": 51, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Mushroom Brute", "base_kind": "ogre", "bar": 40.0},
	"myco_shaman": {"hp": 36, "dmg": 11, "spd": 44.0, "xp": 16, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Myco Shaman", "base_kind": "wisp"},
	"toxic_toad": {"hp": 32, "dmg": 11, "spd": 62.0, "xp": 10, "r": 9.0, "aggro": 130.0, "passive": false, "name": "Toxic Toad", "base_kind": "snake"},
	"cap_guardian": {"hp": 264, "dmg": 26, "spd": 28.0, "xp": 67, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Cap Guardian", "base_kind": "golem", "bar": 40.0},
	"fungal_bat": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 9, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Fungal Bat", "base_kind": "bat", "bar": 24.0},
	"ether_drake": {"hp": 63, "dmg": 15, "spd": 50.0, "xp": 21, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Ether Drake", "base_kind": "fiend"},
	"cloud_wisp": {"hp": 36, "dmg": 11, "spd": 44.0, "xp": 16, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Cloud Wisp", "base_kind": "wisp"},
	"aether_manta": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 9, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Aether Manta", "base_kind": "bat", "bar": 24.0},
	"prism_golem": {"hp": 264, "dmg": 26, "spd": 28.0, "xp": 67, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Prism Golem", "base_kind": "golem", "bar": 40.0},
	"sky_kobold": {"hp": 36, "dmg": 8, "spd": 64.0, "xp": 12, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Sky Kobold", "base_kind": "kobold", "bar": 24.0},
	"starved_harpy": {"hp": 51, "dmg": 12, "spd": 76.0, "xp": 16, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Starved Harpy", "base_kind": "wolf", "bar": 22.0},
	"ruins_sentinel": {"hp": 264, "dmg": 26, "spd": 28.0, "xp": 67, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Ruins Sentinel", "base_kind": "golem", "bar": 40.0},
	"forgotten_knight": {"hp": 36, "dmg": 8, "spd": 64.0, "xp": 12, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Forgotten Knight", "base_kind": "kobold", "bar": 24.0},
	"dust_revenant": {"hp": 80, "dmg": 14, "spd": 36.0, "xp": 27, "r": 10.0, "aggro": 150.0, "passive": false, "name": "Dust Revenant", "base_kind": "mummy", "bar": 28.0},
	"relic_scorpion": {"hp": 69, "dmg": 13, "spd": 68.0, "xp": 24, "r": 10.0, "aggro": 160.0, "passive": false, "name": "Relic Scorpion", "base_kind": "centipede", "bar": 20.0},
	"lost_archer": {"hp": 46, "dmg": 10, "spd": 62.0, "xp": 14, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Lost Archer", "base_kind": "goblin", "bar": 26.0},
	"ancient_mummy": {"hp": 80, "dmg": 14, "spd": 36.0, "xp": 27, "r": 10.0, "aggro": 150.0, "passive": false, "name": "Ancient Mummy", "base_kind": "mummy", "bar": 28.0},
	"lumin_ray": {"hp": 36, "dmg": 11, "spd": 44.0, "xp": 16, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Lumin Ray", "base_kind": "wisp"},
	"reef_guardian": {"hp": 264, "dmg": 26, "spd": 28.0, "xp": 67, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Reef Guardian", "base_kind": "golem", "bar": 40.0},
	"pearl_wisp": {"hp": 36, "dmg": 11, "spd": 44.0, "xp": 16, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Pearl Wisp", "base_kind": "wisp"},
	"coral_stalker": {"hp": 34, "dmg": 8, "spd": 74.0, "xp": 13, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Coral Stalker", "base_kind": "spider", "bar": 18.0},
	"tide_serpent": {"hp": 32, "dmg": 11, "spd": 62.0, "xp": 10, "r": 9.0, "aggro": 130.0, "passive": false, "name": "Tide Serpent", "base_kind": "snake"},
	"glow_jelly": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 8, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Glow Jelly", "base_kind": "slime"},
	"verdan_stag": {"hp": 51, "dmg": 12, "spd": 76.0, "xp": 16, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Verdan Stag", "base_kind": "wolf", "bar": 22.0},
	"canopy_hunter": {"hp": 46, "dmg": 10, "spd": 62.0, "xp": 14, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Canopy Hunter", "base_kind": "goblin", "bar": 26.0},
	"elder_boar": {"hp": 184, "dmg": 24, "spd": 44.0, "xp": 54, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Elder Boar", "base_kind": "bear", "bar": 34.0},
	"vine_strangler": {"hp": 69, "dmg": 13, "spd": 68.0, "xp": 24, "r": 10.0, "aggro": 160.0, "passive": false, "name": "Vine Strangler", "base_kind": "centipede", "bar": 20.0},
	"pollen_sprite": {"hp": 36, "dmg": 11, "spd": 44.0, "xp": 16, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Pollen Sprite", "base_kind": "wisp"},
	"grove_colossus": {"hp": 345, "dmg": 31, "spd": 40.0, "xp": 114, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Grove Colossus", "base_kind": "red_ogre", "bar": 44.0},
	"abyssal_slime": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 7, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Abyssal Slime", "base_kind": "slime"},
	"abyssal_crab": {"hp": 34, "dmg": 8, "spd": 74.0, "xp": 12, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Abyssal Crab", "base_kind": "spider", "bar": 18.0},
	"leviathan_larva": {"hp": 69, "dmg": 12, "spd": 68.0, "xp": 22, "r": 10.0, "aggro": 160.0, "passive": false, "name": "Leviathan Larva", "base_kind": "centipede", "bar": 20.0},
	"sea_siren": {"hp": 63, "dmg": 14, "spd": 50.0, "xp": 19, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Sea Siren", "base_kind": "fiend"},
	"coral_golem": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Coral Golem", "base_kind": "golem", "bar": 40.0},
	"depth_reaper": {"hp": 63, "dmg": 14, "spd": 50.0, "xp": 19, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Depth Reaper", "base_kind": "fiend"},
	"krakenling": {"hp": 34, "dmg": 8, "spd": 74.0, "xp": 12, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Krakenling", "base_kind": "spider", "bar": 18.0},
	"reef_golem": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Reef Golem", "base_kind": "golem", "bar": 40.0},
	"abyssal_archer": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Abyssal Archer", "base_kind": "goblin", "bar": 26.0},
	"sea_drake": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Sea Drake", "base_kind": "bat", "bar": 24.0},
	"pearl_guardian": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Pearl Guardian", "base_kind": "golem", "bar": 40.0},
	"oceanic_horror": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Oceanic Horror", "base_kind": "ogre", "bar": 40.0},
	"abyssal_colossus": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Abyssal Colossus", "base_kind": "red_ogre", "bar": 44.0},
	"trident_warden": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Trident Warden", "base_kind": "ogre", "bar": 40.0},
	"bloom_slime": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 7, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Bloom Slime", "base_kind": "slime"},
	"petal_pixie": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Petal Pixie", "base_kind": "wisp"},
	"thorn_spider": {"hp": 34, "dmg": 8, "spd": 74.0, "xp": 12, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Thorn Spider", "base_kind": "spider", "bar": 18.0},
	"moss_golem": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Moss Golem", "base_kind": "golem", "bar": 40.0},
	"fey_knight": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Fey Knight", "base_kind": "goblin", "bar": 26.0},
	"moon_deer": {"hp": 52, "dmg": 11, "spd": 76.0, "xp": 14, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Moon Deer", "base_kind": "wolf", "bar": 22.0},
	"forest_mage": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Forest Mage", "base_kind": "wisp"},
	"vine_crawler": {"hp": 32, "dmg": 10, "spd": 62.0, "xp": 10, "r": 9.0, "aggro": 130.0, "passive": false, "name": "Vine Crawler", "base_kind": "snake"},
	"spore_moth": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Spore Moth", "base_kind": "bat", "bar": 24.0},
	"root_horror": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Root Horror", "base_kind": "ogre", "bar": 40.0},
	"fungal_walker": {"hp": 80, "dmg": 13, "spd": 36.0, "xp": 24, "r": 10.0, "aggro": 150.0, "passive": false, "name": "Fungal Walker", "base_kind": "mummy", "bar": 28.0},
	"ancient_spirit": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Ancient Spirit", "base_kind": "wisp"},
	"verdant_colossus": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Verdant Colossus", "base_kind": "red_ogre", "bar": 44.0},
	"sylvan_beast": {"hp": 52, "dmg": 11, "spd": 76.0, "xp": 14, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Sylvan Beast", "base_kind": "wolf", "bar": 22.0},
	"crystal_golem": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Crystal Golem", "base_kind": "golem", "bar": 40.0},
	"crystal_slime": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 7, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Crystal Slime", "base_kind": "slime"},
	"gem_bat": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Gem Bat", "base_kind": "bat", "bar": 24.0},
	"crystal_archer": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Crystal Archer", "base_kind": "goblin", "bar": 26.0},
	"crystal_mage": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Crystal Mage", "base_kind": "wisp"},
	"rock_elemental": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Rock Elemental", "base_kind": "golem", "bar": 40.0},
	"crystal_spider": {"hp": 34, "dmg": 8, "spd": 74.0, "xp": 12, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Crystal Spider", "base_kind": "spider", "bar": 18.0},
	"shard_wraith": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Shard Wraith", "base_kind": "wisp"},
	"crystal_serpent": {"hp": 32, "dmg": 10, "spd": 62.0, "xp": 10, "r": 9.0, "aggro": 130.0, "passive": false, "name": "Crystal Serpent", "base_kind": "snake"},
	"ice_crystal_knight": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Ice Crystal Knight", "base_kind": "goblin", "bar": 26.0},
	"crystal_beast": {"hp": 52, "dmg": 11, "spd": 76.0, "xp": 14, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Crystal Beast", "base_kind": "wolf", "bar": 22.0},
	"prism_guardian": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Prism Guardian", "base_kind": "golem", "bar": 40.0},
	"crystal_demon": {"hp": 63, "dmg": 14, "spd": 50.0, "xp": 19, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Crystal Demon", "base_kind": "fiend"},
	"crystal_drone": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Crystal Drone", "base_kind": "wisp"},
	"frost_wisp": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Frost Wisp", "base_kind": "wisp"},
	"crystal_hydra": {"hp": 69, "dmg": 12, "spd": 68.0, "xp": 22, "r": 10.0, "aggro": 160.0, "passive": false, "name": "Crystal Hydra", "base_kind": "centipede", "bar": 20.0},
	"shard_golem": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Shard Golem", "base_kind": "golem", "bar": 40.0},
	"crystal_reaper": {"hp": 63, "dmg": 14, "spd": 50.0, "xp": 19, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Crystal Reaper", "base_kind": "fiend"},
	"diamond_colossus": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Diamond Colossus", "base_kind": "red_ogre", "bar": 44.0},
	"crystal_overlord": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Crystal Overlord", "base_kind": "ogre", "bar": 40.0},
	"wind_colossus": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Wind Colossus", "base_kind": "red_ogre", "bar": 44.0},
	"arcane_golem": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Arcane Golem", "base_kind": "golem", "bar": 40.0},
	"rune_sentinel": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Rune Sentinel", "base_kind": "golem", "bar": 40.0},
	"ether_elemental": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Ether Elemental", "base_kind": "wisp"},
	"crystal_wraith": {"hp": 63, "dmg": 14, "spd": 50.0, "xp": 19, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Crystal Wraith", "base_kind": "fiend"},
	"shadow_herald": {"hp": 63, "dmg": 14, "spd": 50.0, "xp": 19, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Shadow Herald", "base_kind": "fiend"},
	"soul_reaver": {"hp": 63, "dmg": 14, "spd": 50.0, "xp": 19, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Soul Reaver", "base_kind": "fiend"},
	"void_spider": {"hp": 34, "dmg": 8, "spd": 74.0, "xp": 12, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Void Spider", "base_kind": "spider", "bar": 18.0},
	"ether_shooter": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Ether Shooter", "base_kind": "wisp"},
	"dream_stalker": {"hp": 52, "dmg": 11, "spd": 76.0, "xp": 14, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Dream Stalker", "base_kind": "wolf", "bar": 22.0},
	"fallen_sorcerer": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Fallen Sorcerer", "base_kind": "goblin", "bar": 26.0},
	"rift_guardian": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Rift Guardian", "base_kind": "ogre", "bar": 40.0},
	"astral_shade": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Astral Shade", "base_kind": "wisp"},
	"nebula_gazer": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Nebula Gazer", "base_kind": "wisp"},
	"grave_warden": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Grave Warden", "base_kind": "ogre", "bar": 40.0},
	"void_archon": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Void Archon", "base_kind": "red_ogre", "bar": 44.0},
	"ether_lord": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Ether Lord", "base_kind": "ogre", "bar": 40.0},
	"the_aether_colossus": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "The Aether Colossus", "base_kind": "red_ogre", "bar": 44.0},
	"ghost": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Ghost", "base_kind": "wisp"},
	"lich_mage": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Lich Mage", "base_kind": "goblin", "bar": 26.0},
	"wraith": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Wraith", "base_kind": "wisp"},
	"cursed_armor": {"hp": 37, "dmg": 8, "spd": 64.0, "xp": 11, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Cursed Armor", "base_kind": "kobold", "bar": 24.0},
	"grave_slime": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 7, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Grave Slime", "base_kind": "slime"},
	"necro_bat": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Necro Bat", "base_kind": "bat", "bar": 24.0},
	"grave_guardian": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Grave Guardian", "base_kind": "golem", "bar": 40.0},
	"phantom_knight": {"hp": 37, "dmg": 8, "spd": 64.0, "xp": 11, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Phantom Knight", "base_kind": "kobold", "bar": 24.0},
	"soul_reaper": {"hp": 63, "dmg": 14, "spd": 50.0, "xp": 19, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Soul Reaper", "base_kind": "fiend"},
	"specter": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Specter", "base_kind": "wisp"},
	"bone_dragon": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Bone Dragon", "base_kind": "red_ogre", "bar": 44.0},
	"death_mage": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Death Mage", "base_kind": "goblin", "bar": 26.0},
	"lost_spirit": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Lost Spirit", "base_kind": "wisp"},
	"the_forgotten_king": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "The Forgotten King", "base_kind": "red_ogre", "bar": 44.0},
	"reef_fish": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Reef Fish", "base_kind": "bat", "bar": 24.0},
	"violet_fish": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Violet Fish", "base_kind": "bat", "bar": 24.0},
	"angler_fish": {"hp": 63, "dmg": 14, "spd": 50.0, "xp": 19, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Angler Fish", "base_kind": "fiend"},
	"reef_perch": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Reef Perch", "base_kind": "bat", "bar": 24.0},
	"armored_coral_crab": {"hp": 34, "dmg": 8, "spd": 74.0, "xp": 12, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Armored Coral Crab", "base_kind": "spider", "bar": 18.0},
	"magma_coral_crab": {"hp": 34, "dmg": 8, "spd": 74.0, "xp": 12, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Magma Coral Crab", "base_kind": "spider", "bar": 18.0},
	"crystal_coral": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Crystal Coral", "base_kind": "golem", "bar": 40.0},
	"sea_urchin": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 7, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Sea Urchin", "base_kind": "slime"},
	"pufferfish": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 7, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Pufferfish", "base_kind": "slime"},
	"bubble_polyp": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Bubble Polyp", "base_kind": "wisp"},
	"pearl_slug": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 7, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Pearl Slug", "base_kind": "slime"},
	"seahorse": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Seahorse", "base_kind": "bat", "bar": 24.0},
	"striped_reef_fish": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Striped Reef Fish", "base_kind": "bat", "bar": 24.0},
	"violet_piranha": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Violet Piranha", "base_kind": "bat", "bar": 24.0},
	"kelp_spirit": {"hp": 63, "dmg": 14, "spd": 50.0, "xp": 19, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Kelp Spirit", "base_kind": "fiend"},
	"pink_jelly": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Pink Jelly", "base_kind": "wisp"},
	"shard_imp": {"hp": 37, "dmg": 8, "spd": 64.0, "xp": 11, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Shard Imp", "base_kind": "kobold", "bar": 24.0},
	"clam_mimic": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 7, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Clam Mimic", "base_kind": "slime"},
	"bubble_imp": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Bubble Imp", "base_kind": "wisp"},
	"shard_minnow": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Shard Minnow", "base_kind": "bat", "bar": 24.0},
	"cherry_oni": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Cherry Oni", "base_kind": "ogre", "bar": 40.0},
	"blossom_spirit": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Blossom Spirit", "base_kind": "wisp"},
	"red_crane": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Red Crane", "base_kind": "bat", "bar": 24.0},
	"sakura_spirit": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Sakura Spirit", "base_kind": "wisp"},
	"sakura_archer": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Sakura Archer", "base_kind": "goblin", "bar": 26.0},
	"sakura_oni_warrior": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Sakura Oni Warrior", "base_kind": "ogre", "bar": 40.0},
	"fallen_hanami": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Fallen Hanami", "base_kind": "wisp"},
	"sakura_beast": {"hp": 52, "dmg": 11, "spd": 76.0, "xp": 14, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Sakura Beast", "base_kind": "wolf", "bar": 22.0},
	"flower_wisp": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Flower Wisp", "base_kind": "wisp"},
	"blossom_guardian": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Blossom Guardian", "base_kind": "golem", "bar": 40.0},
	"shrine_guard": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Shrine Guard", "base_kind": "ogre", "bar": 40.0},
	"cherry_dragon": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Cherry Dragon", "base_kind": "red_ogre", "bar": 44.0},
	"sakura_mage": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Sakura Mage", "base_kind": "goblin", "bar": 26.0},
	"divine_sakura": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Divine Sakura", "base_kind": "red_ogre", "bar": 44.0},
	"spore_shooter": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Spore Shooter", "base_kind": "goblin", "bar": 26.0},
	"myco_spider": {"hp": 34, "dmg": 8, "spd": 74.0, "xp": 12, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Myco Spider", "base_kind": "spider", "bar": 18.0},
	"mushroom_mage": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Mushroom Mage", "base_kind": "goblin", "bar": 26.0},
	"shroom_archer": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Shroom Archer", "base_kind": "goblin", "bar": 26.0},
	"cap_knight": {"hp": 37, "dmg": 8, "spd": 64.0, "xp": 11, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Cap Knight", "base_kind": "kobold", "bar": 24.0},
	"mushroom_beast": {"hp": 184, "dmg": 22, "spd": 44.0, "xp": 48, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Mushroom Beast", "base_kind": "bear", "bar": 34.0},
	"spore_wisp": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Spore Wisp", "base_kind": "wisp"},
	"toadstool_golem": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Toadstool Golem", "base_kind": "golem", "bar": 40.0},
	"mushroom_drone": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Mushroom Drone", "base_kind": "wisp"},
	"fungus_hydra": {"hp": 69, "dmg": 12, "spd": 68.0, "xp": 22, "r": 10.0, "aggro": 160.0, "passive": false, "name": "Fungus Hydra", "base_kind": "centipede", "bar": 20.0},
	"spore_knight": {"hp": 37, "dmg": 8, "spd": 64.0, "xp": 11, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Spore Knight", "base_kind": "kobold", "bar": 24.0},
	"giant_mushroom": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Giant Mushroom", "base_kind": "ogre", "bar": 40.0},
	"royal_mushroom": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Royal Mushroom", "base_kind": "red_ogre", "bar": 44.0},
	"mushroom_overlord": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Mushroom Overlord", "base_kind": "red_ogre", "bar": 44.0},
	"lumin_jelly": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Lumin Jelly", "base_kind": "wisp"},
	"reef_stalker": {"hp": 23, "dmg": 7, "spd": 88.0, "xp": 8, "r": 8.0, "aggro": 180.0, "passive": false, "name": "Reef Stalker", "base_kind": "bat", "bar": 24.0},
	"coral_hydra": {"hp": 32, "dmg": 10, "spd": 62.0, "xp": 10, "r": 9.0, "aggro": 130.0, "passive": false, "name": "Coral Hydra", "base_kind": "snake"},
	"pearl_siren": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Pearl Siren", "base_kind": "wisp"},
	"tide_warden": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Tide Warden", "base_kind": "golem", "bar": 40.0},
	"radiant_leviathan": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Radiant Leviathan", "base_kind": "red_ogre", "bar": 44.0},
	"dusk_wraith": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Dusk Wraith", "base_kind": "wisp"},
	"umbral_archer": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Umbral Archer", "base_kind": "goblin", "bar": 26.0},
	"cursed_knight": {"hp": 37, "dmg": 8, "spd": 64.0, "xp": 11, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Cursed Knight", "base_kind": "kobold", "bar": 24.0},
	"shadow_brute": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Shadow Brute", "base_kind": "ogre", "bar": 40.0},
	"shadow_soul_reaper": {"hp": 63, "dmg": 14, "spd": 50.0, "xp": 19, "r": 11.0, "aggro": 190.0, "passive": false, "name": "Soul Reaper", "base_kind": "fiend"},
	"ethereal_wisp": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Ethereal Wisp", "base_kind": "wisp"},
	"dark_mage": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Dark Mage", "base_kind": "goblin", "bar": 26.0},
	"revenant": {"hp": 37, "dmg": 8, "spd": 64.0, "xp": 11, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Revenant", "base_kind": "kobold", "bar": 24.0},
	"royal_executor": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Royal Executor", "base_kind": "red_ogre", "bar": 44.0},
	"voidling": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 7, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Voidling", "base_kind": "slime"},
	"glitch_mite": {"hp": 34, "dmg": 8, "spd": 74.0, "xp": 12, "r": 9.0, "aggro": 165.0, "passive": false, "name": "Glitch Mite", "base_kind": "spider", "bar": 18.0},
	"rift_mimic": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Rift Mimic", "base_kind": "golem", "bar": 40.0},
	"corrupted_drone": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Corrupted Drone", "base_kind": "wisp"},
	"glitch_knight": {"hp": 37, "dmg": 8, "spd": 64.0, "xp": 11, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Glitch Knight", "base_kind": "kobold", "bar": 24.0},
	"dimensional_wraith": {"hp": 37, "dmg": 10, "spd": 44.0, "xp": 14, "r": 10.0, "aggro": 190.0, "passive": false, "name": "Dimensional Wraith", "base_kind": "wisp"},
	"pixel_swarm": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 7, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Pixel Swarm", "base_kind": "slime"},
	"data_sentinel": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Data Sentinel", "base_kind": "golem", "bar": 40.0},
	"void_leviathan": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Void Leviathan", "base_kind": "red_ogre", "bar": 44.0},
	"verdant_sporeling": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 7, "r": 10.0, "aggro": 120.0, "passive": false, "name": "Sporeling", "base_kind": "slime"},
	"verdant_mushroom_brute": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Mushroom Brute", "base_kind": "ogre", "bar": 40.0},
	"myconid_mage": {"hp": 46, "dmg": 9, "spd": 62.0, "xp": 13, "r": 9.0, "aggro": 150.0, "passive": false, "name": "Myconid Mage", "base_kind": "goblin", "bar": 26.0},
	"toadstool_guard": {"hp": 37, "dmg": 8, "spd": 64.0, "xp": 11, "r": 8.0, "aggro": 150.0, "passive": false, "name": "Toadstool Guard", "base_kind": "kobold", "bar": 24.0},
	"fungal_stalker": {"hp": 52, "dmg": 11, "spd": 76.0, "xp": 14, "r": 10.0, "aggro": 170.0, "passive": false, "name": "Fungal Stalker", "base_kind": "wolf", "bar": 22.0},
	"kings_spore": {"hp": 34, "dmg": 8, "spd": 48.0, "xp": 7, "r": 10.0, "aggro": 120.0, "passive": false, "name": "King's Spore", "base_kind": "slime"},
	"verdant_moss_golem": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Moss Golem", "base_kind": "golem", "bar": 40.0},
	"fungal_giant": {"hp": 195, "dmg": 20, "spd": 34.0, "xp": 46, "r": 15.0, "aggro": 170.0, "passive": false, "name": "Fungal Giant", "base_kind": "ogre", "bar": 40.0},
	"verdant_ent": {"hp": 264, "dmg": 24, "spd": 28.0, "xp": 60, "r": 16.0, "aggro": 160.0, "passive": false, "name": "Verdant Ent", "base_kind": "golem", "bar": 40.0},
	"spore_queen": {"hp": 345, "dmg": 28, "spd": 40.0, "xp": 102, "r": 17.0, "aggro": 200.0, "passive": false, "name": "Spore Queen", "base_kind": "red_ogre", "bar": 44.0}
}

var kind := "slime"
# mini boss (diisi main.gd sebelum add_child)
var is_mini := false
var mini_name := ""
var mini_idx := -1
var mini_hp := 0
var _sc := 1.0                  # skala gambar (mini boss lebih besar)
var biome_idx := 1
var biome_id := "forest"
var mult := 1.0
var level := 0                  # 0 = diundi otomatis dari bioma (lihat balance.gd)
var hp := 30
var max_hp := 30
var dmg := 8
var speed := 48.0
var radius := 10.0
var bar_y := 20.0
var xp_reward := 5
var aggro := 120.0
var passive := false
var spawn_pos := Vector2.ZERO
var player
var _dmg_base := -1               # damage dasar monster (sebelum pengali selisih level)
var _gap_t := randf() * 0.5      # diacak supaya ratusan musuh tidak menghitung di frame yang sama
var _ai_n := randi() % 3
var _ai_acc := 0.0
var world

var _t := randf() * 10.0
var _wander_dir := Vector2.ZERO
var _wander_t := 0.0
var _knock := Vector2.ZERO
var _touch_cd := 0.0
var _flash := 0.0
var _shoot_cd := randf_range(1.0, 2.5)
var _flee := 0.0
var _face := 1.0
var _atk := 0.0
var _lunge := 0.0
var _lunge_mul := 3.2
var _lunge_dir := Vector2.ZERO
var _show_bar := 0.0
var _rd := randi() % 4          # penghitung gambar-ulang (diacak supaya tidak serempak)
var _stale := true
# jurus musuh baru
var _windup := 0.0              # waktu bersiap (telegraf) sebelum jurus
var _retreat := 0.0             # goblin: mundur setelah memukul
var _skill_cd := randf_range(0.5, 2.0)
var _charge_cd := randf_range(1.5, 3.0)
var _charging := false
var _next_charge := false
var _windup_len := 0.8
var _stun := 0.0
# status
var _burn := 0.0
var _poison := 0.0
var _slow := 0.0
var _dot_t := 0.0
var _dot_dmg := 0
# co-op (lihat net.gd): host menjalankan AI; di HP klien monster adalah "puppet" yang hanya digambar
var net_id := 0
var puppet := false
var _net_pos := Vector2.ZERO
var _rt_t := randf() * 0.4


func _ready() -> void:
	add_to_group("enemies")
	if not puppet:
		add_to_group("lod")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	player = get_tree().get_first_node_in_group("player")
	world = get_tree().get_first_node_in_group("world")
	var b: Dictionary = BASE[kind]
	biome_id = String(world.IDS[clampi(biome_idx, 0, world.IDS.size() - 1)]) if world != null else "forest"
	passive = bool(b["passive"])
	if passive:
		level = 1
	elif level <= 0:
		level = Bal.roll_mob_level(biome_idx, kind, global_position.distance_to(world.spawn_point()) if world != null else -1.0)
	mult = 1.0 + float(level) * 0.06
	max_hp = Bal.mob_hp(level, int(b["hp"]))
	hp = max_hp
	dmg = maxi(int(float(Bal.mob_dmg(level, int(b["dmg"]))) * 0.42), 1)
	speed = float(b["spd"]) * (1.0 + minf(float(level), 60.0) * 0.004)
	xp_reward = Bal.mob_xp(level, int(b["xp"]))
	radius = float(b["r"])
	bar_y = float(b.get("bar", radius + 10.0))
	aggro = float(b["aggro"])
	passive = bool(b["passive"])
	if is_mini:
		_sc = 1.5
		max_hp = maxi(mini_hp, 1)
		hp = max_hp
		dmg = int(float(dmg) * 1.5)
		xp_reward = int(float(Bal.xp_needed(level)) * 0.5)
		radius *= 1.5
		bar_y *= 1.45
		aggro += 60.0
	if not passive and not puppet:
		add_to_group("hostile")
	spawn_pos = global_position
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = clampf(radius * 0.62, 7.0, 11.0)
	cs.shape = sh
	cs.position = Vector2(0, 3)
	add_child(cs)
	collision_layer = 4
	collision_mask = 1
	if puppet:
		collision_layer = 0
		collision_mask = 0
		_net_pos = global_position
	elif Net.active and Net.is_host:
		net_id = Net.register(self)


# ------------------------------------------------------------------ co-op
func net_spawn_info() -> Dictionary:
	return {"t": "mob", "id": net_id, "kind": kind, "biome": biome_idx, "lv": level, "x": global_position.x, "y": global_position.y,
		"mini": is_mini, "mname": mini_name, "mhp": mini_hp, "midx": mini_idx}


# [id, x, y, hp, atk, face, flags]
func net_snapshot() -> PackedFloat32Array:
	var fl := 0
	if _burn > 0.0:
		fl |= 1
	if _poison > 0.0:
		fl |= 2
	if _slow > 0.0:
		fl |= 4
	if _stun > 0.0:
		fl |= 8
	return PackedFloat32Array([float(net_id), global_position.x, global_position.y, float(hp), _atk, _face, float(fl)])


func net_apply(x: float, y: float, h: float, atk: float, face: float, fl: int) -> void:
	_net_pos = Vector2(x, y)
	hp = int(h)
	_atk = atk
	_face = face
	_burn = 0.3 if (fl & 1) != 0 else 0.0
	_poison = 0.3 if (fl & 2) != 0 else 0.0
	_slow = 0.3 if (fl & 4) != 0 else 0.0
	_stun = 0.3 if (fl & 8) != 0 else 0.0


func net_kill() -> void:
	hp = 0
	_die()


func _puppet_step(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_show_bar = maxf(_show_bar - delta, 0.0)
	var d: Vector2 = _net_pos - global_position
	velocity = d * 8.0
	global_position += d * minf(14.0 * delta, 1.0)
	_rd += 1
	if _rd >= Perf.anim_div or _flash > 0.12:
		_rd = 0
		queue_redraw()


# Host: arahkan monster ke pemain terdekat (pemain lokal atau pemain lain)
func _retarget(delta: float) -> void:
	_rt_t -= delta
	if _rt_t > 0.0:
		return
	_rt_t = 0.4
	var best = player
	var bd := 1.0e12
	for t in Net.targets():
		if t.dead:
			continue
		var d: float = t.global_position.distance_squared_to(global_position)
		if d < bd:
			bd = d
			best = t
	player = best


func archetype() -> String:
	return String(BASE[kind].get("base_kind", kind))


func enemy_name() -> String:
	if is_mini and mini_name != "":
		return mini_name
	return String(BASE[kind]["name"])


# Ogre Merah & semua mini boss mengamuk saat HP di bawah separuh
func _rage() -> bool:
	return (archetype() == "red_ogre" or is_mini) and hp * 2 <= max_hp


func apply_status(s: String, secs: float, dot: int = 0) -> void:
	if puppet:
		Net.send_status(net_id, s, secs, dot)
		return
	match s:
		"burn":
			_burn = secs
			_dot_dmg = maxi(dot, 1)
		"poison":
			_poison = secs
			_dot_dmg = maxi(dot, 1)
		"freeze":
			_slow = secs


# Musuh yang jauh dari pemain dan tidak sedang bertarung tidak butuh AI 60x/detik.
func _far_idle() -> bool:
	if player == null or _lunge > 0.0 or _flash > 0.0 or _stun > 0.0 or _flee > 0.0 or _burn > 0.0 or _poison > 0.0:
		return false
	if _knock.length_squared() > 4.0:
		return false
	var r: float = aggro * 1.5 + 40.0
	return global_position.distance_squared_to(player.global_position) > r * r


func _physics_process(delta: float) -> void:
	if puppet:
		_puppet_step(delta)
		return
	var step_mul := 1.0
	if Perf.ai_div > 1 and _far_idle():
		_ai_acc += delta
		_ai_n += 1
		if _ai_n < Perf.ai_div:
			return
		_ai_n = 0
		delta = _ai_acc
		_ai_acc = 0.0
		step_mul = delta / maxf(get_physics_process_delta_time(), 0.0001)
	else:
		_ai_acc = 0.0
	if Net.active:
		_retarget(delta)
	_t += delta
	_gap_t -= delta
	if _gap_t <= 0.0 and not passive:
		_gap_t = 0.5
		_apply_gap()
	_touch_cd = maxf(_touch_cd - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	_flee = maxf(_flee - delta, 0.0)
	_show_bar = maxf(_show_bar - delta, 0.0)
	_lunge = maxf(_lunge - delta, 0.0)
	_stun = maxf(_stun - delta, 0.0)
	_burn = maxf(_burn - delta, 0.0)
	_poison = maxf(_poison - delta, 0.0)
	_slow = maxf(_slow - delta, 0.0)
	if _burn > 0.0 or _poison > 0.0:
		_dot_t += delta
		if _dot_t >= 0.7:
			_dot_t = 0.0
			_hurt(_dot_dmg, Vector2.ZERO, false)
			if hp <= 0:
				return
	var spd: float = speed * (0.5 if _slow > 0.0 else 1.0)

	var vel := Vector2.ZERO
	var alert := false
	if player and not player.dead and not passive:
		var to: Vector2 = player.global_position - global_position
		var dist: float = to.length()
		var safe: bool = world != null and world.in_village(player.global_position)
		if dist < aggro and not safe:
			alert = true
			vel = _behave(to, dist, spd, delta)
	if passive and _flee > 0.0 and player:
		alert = true
		vel = (global_position - player.global_position).normalized() * speed * 2.0
	if not alert:
		_atk = 0.0
		_windup = 0.0
		_charging = false
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(1.0, 3.0)
			_wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.6 else Vector2.ZERO
			# jangan menjauh dari tempat lahir
			if global_position.distance_to(spawn_pos) > 140.0:
				_wander_dir = (spawn_pos - global_position).normalized()
		vel = _wander_dir * spd * 0.4
	if _lunge > 0.0:
		vel = _lunge_dir * spd * _lunge_mul
	velocity = (vel + _knock) * step_mul     # frame yang dilewati diganti dengan langkah lebih panjang
	_knock = _knock.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	if absf(velocity.x) > 6.0:
		_face = 1.0 if velocity.x > 0.0 else -1.0
	_redraw_throttled()


# Gambar ulang dibatasi (animasi pixel-art cukup ~15-20 FPS) dan dilewati kalau di luar layar.
func _redraw_throttled() -> void:
	if player and global_position.distance_squared_to(player.global_position) > 160000.0:
		_stale = true
		return
	_rd += 1
	if _rd >= Perf.anim_div or _stale or _flash > 0.12:
		_rd = 0
		_stale = false
		queue_redraw()


func _behave(to: Vector2, dist: float, spd: float, delta: float) -> Vector2:
	var dir: Vector2 = to.normalized()
	match archetype():
		"slime":
			if dist < 16.0:
				_hit_player(to)
			return dir * spd
		"bee":
			# terbang berputar acak lalu menyengat
			var sway: Vector2 = dir.orthogonal() * sin(_t * 6.0) * 0.8
			if dist < 14.0:
				_hit_player(to)
			return (dir + sway).normalized() * spd
		"snake":
			_atk = 0.0
			if dist < 60.0 and dist > 24.0 and _lunge <= 0.0 and randf() < 0.01:
				_lunge = 0.25
				_lunge_mul = 3.2
				_lunge_dir = dir
				_atk = 1.0
			if dist < 15.0:
				_hit_player(to)
			return dir * spd
		"fiend":
			_shoot_cd -= delta
			_atk = clampf(1.0 - _shoot_cd / 0.6, 0.0, 1.0) if _shoot_cd < 0.6 else 0.0
			if _shoot_cd <= 0.0:
				_shoot_cd = 2.0
				_shoot(dir, Color(1.0, 0.4, 0.15), 140.0)
			if dist < 16.0:
				_hit_player(to)
			if dist < 70.0:
				return -dir * spd * 0.8
			if dist > 120.0:
				return dir * spd
			return dir.orthogonal() * spd * 0.6
		"wisp":
			_shoot_cd -= delta
			if _shoot_cd <= 0.0:
				_shoot_cd = 2.3
				_shoot(dir, Color(1.0, 0.45, 0.8), 115.0)
			if dist < 80.0:
				return -dir * spd
			if dist > 130.0:
				return dir * spd
			return dir.orthogonal() * spd * 0.6
		"goblin":
			return _behave_goblin(to, dist, dir, spd, delta)
		"spider":
			return _behave_spider(to, dist, dir, spd, delta)
		"ogre", "red_ogre", "bear":
			return _behave_ogre(to, dist, dir, spd, delta)
		"golem":
			return _behave_golem(to, dist, dir, spd, delta)
		"wolf":
			return _behave_wolf(to, dist, dir, spd, delta)
		"kobold":
			return _behave_kobold(to, dist, dir, spd, delta)
		"bat":
			return _behave_bat(to, dist, dir, spd, delta)
		"mummy":
			return _behave_mummy(to, dist, dir, spd, delta)
		"centipede":
			return _behave_centipede(to, dist, dir, spd, delta)
	return Vector2.ZERO


# Goblin: serang-mundur. Mendekat zig-zag, menerjang, memukul, lalu mundur sebentar.
func _behave_goblin(to: Vector2, dist: float, dir: Vector2, spd: float, delta: float) -> Vector2:
	_shoot_cd -= delta
	if _retreat > 0.0:
		_retreat -= delta
		_atk = 0.0
		return -dir * spd * 0.85 + dir.orthogonal() * sin(_t * 5.0) * spd * 0.45
	_atk = 1.0 if _lunge > 0.0 else 0.0
	if dist < 72.0 and dist > 26.0 and _lunge <= 0.0 and _shoot_cd <= 0.0:
		_lunge = 0.3
		_lunge_mul = 3.0
		_lunge_dir = dir
		_atk = 1.0
		_shoot_cd = randf_range(1.6, 2.6)
	if dist < 18.0:
		_atk = 1.0
		if _hit_player(to):
			_retreat = 0.9
	var zig: Vector2 = dir.orthogonal() * sin(_t * 4.0 + float(get_instance_id() % 7)) * 0.55
	return (dir + zig).normalized() * spd


# Laba-laba: merayap zig-zag cepat, merunduk (telegraf) lalu menerkam; dari jauh menembak jaring.
func _behave_spider(to: Vector2, dist: float, dir: Vector2, spd: float, delta: float) -> Vector2:
	_shoot_cd -= delta
	_skill_cd -= delta
	if _windup > 0.0:
		_windup -= delta
		_atk = clampf(1.0 - _windup / 0.35, 0.0, 1.0)
		if _windup <= 0.0:
			_lunge = 0.28
			_lunge_mul = 3.6
			_lunge_dir = (player.global_position - global_position).normalized()
			_atk = 1.0
		return Vector2.ZERO
	_atk = 1.0 if _lunge > 0.0 else 0.0
	if _lunge > 0.0:
		if dist < 15.0:
			_hit_player(to)
		return Vector2.ZERO
	if dist < 100.0 and dist > 34.0 and _skill_cd <= 0.0:
		_windup = 0.35
		_skill_cd = randf_range(2.0, 3.2)
		return Vector2.ZERO
	if dist > 110.0 and _shoot_cd <= 0.0:
		_shoot_cd = 3.2
		_shoot(dir, Color(0.88, 0.95, 1.0), 95.0, maxi(dmg / 2, 1))
	if dist < 15.0:
		_hit_player(to)
	return (dir + dir.orthogonal() * sin(_t * 9.0) * 0.9).normalized() * spd


# Ogre: lamban, menghantam tanah (lingkaran peringatan dulu). Ogre Merah juga menyeruduk
# lalu pusing sebentar, dan mengamuk (lebih cepat) saat HP di bawah separuh.
func _behave_ogre(to: Vector2, dist: float, dir: Vector2, spd: float, delta: float) -> Vector2:
	var ak := archetype()
	var red: bool = ak == "red_ogre" or (is_mini and (ak == "bear" or ak == "golem"))
	var rage: float = 0.7 if _rage() else 1.0
	_skill_cd -= delta
	_charge_cd -= delta
	if _stun > 0.0:
		_atk = 0.0
		return Vector2.ZERO
	if _charging:
		_atk = 0.0
		if _lunge > 0.0:
			if dist < 24.0 and _hit_player(to, 1.3):
				_lunge = 0.0
			return Vector2.ZERO
		_charging = false
		_stun = 0.9
		return Vector2.ZERO
	if _windup > 0.0:
		_windup -= delta
		_atk = clampf(1.0 - _windup / _windup_len, 0.0, 1.0)
		if _windup <= 0.0:
			_atk = 0.0
			if _next_charge:
				_lunge = 0.55
				_lunge_mul = 5.0
				_lunge_dir = (player.global_position - global_position).normalized()
				_charging = true
			else:
				_slam()
		return Vector2.ZERO
	_atk = 0.0
	var main = get_tree().current_scene
	if red and dist > 90.0 and dist < 200.0 and _charge_cd <= 0.0:
		_next_charge = true
		_windup_len = 0.65 * rage
		_windup = _windup_len
		_charge_cd = randf_range(4.0, 6.0) * rage
		main.fx_tele(global_position + Vector2(0, 6), 30.0, Color(1.0, 0.25, 0.15), _windup_len)
		return Vector2.ZERO
	if dist < 64.0 and _skill_cd <= 0.0:
		_next_charge = false
		_windup_len = 0.8 * rage
		_windup = _windup_len
		_skill_cd = (2.4 if red else 2.8) * rage
		main.fx_tele(global_position + Vector2(0, 6), _slam_radius(), Color(1.0, 0.5, 0.2), _windup_len)
		return Vector2.ZERO
	if dist < 26.0:
		_hit_player(to)
	return dir * spd * (1.3 if _rage() else 1.0)


# Serigala: mengitari mangsa, berjongkok (telegraf) lalu menerkam, mundur sebentar setelah menggigit.
func _behave_wolf(to: Vector2, dist: float, dir: Vector2, spd: float, delta: float) -> Vector2:
	var rm: float = 0.7 if _rage() else 1.0
	_skill_cd -= delta
	if _retreat > 0.0:
		_retreat -= delta
		_atk = 0.0
		return -dir * spd * 0.7 + dir.orthogonal() * spd * 0.5
	if _windup > 0.0:
		_windup -= delta
		_atk = clampf(1.0 - _windup / 0.35, 0.0, 1.0)
		if _windup <= 0.0:
			_lunge = 0.32
			_lunge_mul = 3.4
			_lunge_dir = (player.global_position - global_position).normalized()
			_atk = 1.0
		return Vector2.ZERO
	if _lunge > 0.0:
		_atk = 1.0
		if dist < 16.0 and _hit_player(to):
			_lunge = 0.0
			_retreat = 0.8 * rm
		return Vector2.ZERO
	_atk = 0.0
	if dist < 110.0 and dist > 30.0 and _skill_cd <= 0.0:
		_windup = 0.35
		_skill_cd = randf_range(2.0, 3.2) * rm
		return Vector2.ZERO
	if dist < 16.0 and _hit_player(to):
		_retreat = 0.8 * rm
	var side: float = 1.0 if get_instance_id() % 2 == 0 else -1.0
	if dist < 110.0:
		return (dir * 0.5 + dir.orthogonal() * side * 0.8).normalized() * spd * (1.25 if _rage() else 1.0)
	return dir * spd * (1.25 if _rage() else 1.0)


# Kobold: melempar tombak dari jauh, mundur kalau didekati, menusuk kalau terpojok.
func _behave_kobold(to: Vector2, dist: float, dir: Vector2, spd: float, delta: float) -> Vector2:
	var rm: float = 0.7 if _rage() else 1.0
	_shoot_cd -= delta
	_atk = clampf(1.0 - _shoot_cd / 0.4, 0.0, 1.0) if _shoot_cd < 0.4 else 0.0
	if _shoot_cd <= 0.0 and dist > 40.0 and dist < 140.0:
		_shoot_cd = randf_range(1.8, 2.8) * rm
		_shoot(dir, Color(0.85, 0.72, 0.5), 135.0, maxi(int(float(dmg) * 0.8), 1))
		if is_mini:
			_shoot(dir.rotated(0.3), Color(0.85, 0.72, 0.5), 135.0, maxi(int(float(dmg) * 0.6), 1))
			_shoot(dir.rotated(-0.3), Color(0.85, 0.72, 0.5), 135.0, maxi(int(float(dmg) * 0.6), 1))
	if dist < 16.0:
		_hit_player(to)
	if dist < 55.0:
		return -dir * spd * 0.9 + dir.orthogonal() * sin(_t * 5.0) * spd * 0.4
	if dist > 115.0:
		return dir * spd
	return dir.orthogonal() * sin(_t * 2.0) * spd * 0.7


# Kelelawar: terbang meliuk-liuk, menyambar, lalu kabur. Ratu Kelelawar menyedot darah (menyembuhkan diri).
func _behave_bat(to: Vector2, dist: float, dir: Vector2, spd: float, delta: float) -> Vector2:
	var rm: float = 0.7 if _rage() else 1.0
	_skill_cd -= delta
	if _retreat > 0.0:
		_retreat -= delta
		return -dir * spd * 0.9 + dir.orthogonal() * sin(_t * 8.0) * spd * 0.7
	if _lunge > 0.0:
		_atk = 1.0
		if dist < 15.0 and _hit_player(to):
			_lunge = 0.0
			_retreat = 1.0 * rm
			if is_mini:
				hp = mini(hp + dmg * 3, max_hp)
		return Vector2.ZERO
	_atk = 0.0
	if dist < 95.0 and dist > 24.0 and _skill_cd <= 0.0:
		_lunge = 0.3
		_lunge_mul = 3.0
		_lunge_dir = dir
		_skill_cd = randf_range(1.6, 2.6) * rm
		return Vector2.ZERO
	if dist < 14.0 and _hit_player(to):
		_retreat = 1.0 * rm
		if is_mini:
			hp = mini(hp + dmg * 3, max_hp)
	return (dir + dir.orthogonal() * sin(_t * 7.0 + float(get_instance_id() % 5)) * 1.1).normalized() * spd


# Golem: lambat & keras. Melempar batu dari jauh, lalu menghantam tanah (pakai jurus ogre).
func _behave_golem(to: Vector2, dist: float, dir: Vector2, spd: float, delta: float) -> Vector2:
	_shoot_cd -= delta
	if _windup <= 0.0 and not _charging and _stun <= 0.0 and _shoot_cd <= 0.0 and dist > 80.0 and dist < 180.0:
		_shoot_cd = randf_range(3.0, 4.5) * (0.7 if _rage() else 1.0)
		_shoot(dir, Color(0.62, 0.58, 0.55), 95.0, maxi(int(float(dmg) * 0.7), 1))
	return _behave_ogre(to, dist, dir, spd, delta)


# Mumi: berjalan pelan, melepas peluru kutukan pasir. Mumi Firaun menembak tiga arah.
func _behave_mummy(to: Vector2, dist: float, dir: Vector2, spd: float, delta: float) -> Vector2:
	var rm: float = 0.7 if _rage() else 1.0
	_shoot_cd -= delta
	_atk = clampf(1.0 - _shoot_cd / 0.5, 0.0, 1.0) if _shoot_cd < 0.5 else 0.0
	if _shoot_cd <= 0.0 and dist > 40.0 and dist < 150.0:
		_shoot_cd = 2.8 * rm
		_shoot(dir, Color(0.85, 0.75, 0.35), 100.0)
		if is_mini:
			_shoot(dir.rotated(0.35), Color(0.85, 0.75, 0.35), 100.0)
			_shoot(dir.rotated(-0.35), Color(0.85, 0.75, 0.35), 100.0)
	if dist < 18.0:
		_hit_player(to)
	return dir * spd * (1.3 if _rage() else 1.0)


# Kelabang: merayap cepat berkelok, meringkuk (telegraf) lalu menyeruduk lurus.
func _behave_centipede(to: Vector2, dist: float, dir: Vector2, spd: float, delta: float) -> Vector2:
	var rm: float = 0.7 if _rage() else 1.0
	_skill_cd -= delta
	if _windup > 0.0:
		_windup -= delta
		_atk = clampf(1.0 - _windup / 0.4, 0.0, 1.0)
		if _windup <= 0.0:
			_lunge = 0.4
			_lunge_mul = 3.8
			_lunge_dir = (player.global_position - global_position).normalized()
			_atk = 1.0
		return Vector2.ZERO
	if _lunge > 0.0:
		_atk = 1.0
		if dist < 18.0 and _hit_player(to, 1.2):
			_lunge = 0.0
		return Vector2.ZERO
	_atk = 0.0
	if dist < 120.0 and dist > 36.0 and _skill_cd <= 0.0:
		_windup = 0.4
		_skill_cd = randf_range(2.2, 3.4) * rm
		return Vector2.ZERO
	if dist < 16.0:
		_hit_player(to)
	return (dir + dir.orthogonal() * sin(_t * 6.0) * 0.5).normalized() * spd


func _slam_radius() -> float:
	var r: float = 52.0
	match kind:
		"red_ogre":
			r = 62.0
		"bear":
			r = 40.0
		"golem":
			r = 58.0
	return r * (1.3 if is_mini else 1.0)


func _slam() -> void:
	var main = get_tree().current_scene
	var c: Vector2 = global_position + Vector2(0, 6)
	var r: float = _slam_radius()
	main.fx_ring(c, r, Color(1.0, 0.7, 0.3), 0.35)
	main.fx_burst(c, Color(0.75, 0.62, 0.5), 12, 80.0, 0.45, 60.0, 2.4, "dot")
	Audio.sfx("hit", 0.6)
	if player and not player.dead:
		player.shake_camera(0.8)
		if player.global_position.distance_to(c) < r + 6.0:
			player.take_damage(int(float(dmg) * 1.4 * _bm_mul()), player.global_position - global_position, kind)


# Mengembalikan true kalau pukulan benar-benar mengenai (tidak sedang cooldown)
func _hit_player(to: Vector2, mul: float = 1.0) -> bool:
	if _touch_cd > 0.0:
		return false
	_touch_cd = 1.0
	player.take_damage(int(float(dmg) * mul * _bm_mul()), to, kind)
	return true


# Bulan Darah (world_events.gd): monster memukul lebih keras
func _bm_mul() -> float:
	var m = get_tree().current_scene
	return 1.35 if (m != null and bool(m.get("blood_moon"))) else 1.0


func _shoot(dir: Vector2, c: Color, spd: float, damage: int = -1) -> void:
	var b = Projectile.new()
	b.direction = dir
	b.hostile = true
	b.damage = dmg if damage < 0 else damage
	b.speed = spd
	b.life = 2.4
	b.color = c
	get_parent().add_child(b)
	b.global_position = global_position + dir * 10.0
	Audio.sfx("enemy_shoot")


func _draw() -> void:
	var big: bool = radius >= 14.0
	Art.shadow(self, (12.0 if big else 9.0) * _sc, radius * 0.95 if big else (8.0 if radius < 11.0 else 10.0))
	Art.draw_mob(self, {"kind": archetype(), "skind": kind, "biome": biome_id, "t": _t, "face": _face, "moving": velocity.length() > 4.0, "vel": velocity, "atk": _atk, "rage": _rage(), "stun": _stun > 0.0, "scale": _sc, "mini": is_mini})
	if _flash > 0.0:
		draw_circle(Vector2(0, -2), radius, Color(1, 0.3, 0.3, 0.35))
	if _burn > 0.0:
		draw_circle(Vector2(sin(_t * 9.0) * 3.0, -radius - 2.0), 2.0, Color(1.0, 0.6, 0.1, 0.9))
	if _poison > 0.0:
		draw_circle(Vector2(sin(_t * 7.0) * 3.0, -radius - 2.0), 2.0, Color(0.5, 1.0, 0.3, 0.9))
	if _slow > 0.0:
		draw_circle(Vector2(0, 0), radius + 2.0, Color(0.6, 0.9, 1.0, 0.25))
	if _show_bar > 0.0 or is_mini:
		var w := 22.0 if not big else 36.0
		if is_mini:
			w = 52.0
		var y := -bar_y
		draw_rect(Rect2(-w / 2.0 - 1, y - 1, w + 2, 5), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w / 2.0, y, w * float(hp) / float(max_hp), 3), Color(0.95, 0.3, 0.3) if not passive else Color(0.4, 0.85, 0.4))
		if not passive and player != null:
			var dl: int = level - player.level()
			var lc := Color(1.0, 0.35, 0.3) if dl >= 5 else (Color(0.65, 0.65, 0.7) if dl <= -6 else Color(1.0, 0.95, 0.6))
			var lt := "Lv%d" % level
			draw_string_outline(ThemeDB.fallback_font, Vector2(-w / 2.0, y - 3.0), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 0.9))
			draw_string(ThemeDB.fallback_font, Vector2(-w / 2.0, y - 3.0), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, lc)
		if is_mini and mini_name != "":
			var nsz: Vector2 = ThemeDB.fallback_font.get_string_size(mini_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
			var np := Vector2(-nsz.x / 2.0, y - 15.0)
			draw_string_outline(ThemeDB.fallback_font, np, mini_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.9))
			draw_string(ThemeDB.fallback_font, np, mini_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.82, 0.25))


# amount sudah termasuk bonus pemain; crit = pukulan kritis
func take_damage(amount: int, dir: Vector2, crit: bool = false) -> void:
	if puppet:
		# klien: HP asli ada di host. Tampilkan umpan balik lokal, kirim damage ke host.
		_flash = 0.15
		_show_bar = 4.0
		var pm = get_tree().current_scene
		Audio.sfx("hit", randf_range(0.9, 1.15))
		pm.fx_text(global_position + Vector2(0, -bar_y - 2.0), str(amount) + ("!" if crit else ""), Color(1.0, 0.85, 0.2) if crit else Color(1, 1, 1), 18.0 if crit else 13.0)
		if dir != Vector2.ZERO:
			pm.fx_burst(global_position, Color(1, 0.9, 0.6), 5, 50.0, 0.3, 0.0, 1.8, "star")
		Net.send_hit(net_id, amount, dir, crit)
		return
	if not passive and player != null and is_instance_valid(player):
		amount = maxi(int(float(amount) * Bal.dealt_mult(level, player.level())), 1)    # monster jauh di atas level = kebal
	_hurt(amount, dir, crit)
	if passive:
		_flee = 4.0


# Selisih level: damage monster ke pemain naik kalau monster jauh di atas level pemain (lihat Bal.taken_mult)
func _apply_gap() -> void:
	if _dmg_base < 0:
		_dmg_base = dmg
	if player == null or not is_instance_valid(player):
		return
	dmg = maxi(int(float(_dmg_base) * Bal.taken_mult(level, player.level())), 1)


func _hurt(amount: int, dir: Vector2, crit: bool) -> void:
	hp -= amount
	_flash = 0.15
	_show_bar = 4.0
	var ak := archetype()
	var resist: float = 0.35 if ak == "ogre" or ak == "red_ogre" or ak == "bear" or ak == "golem" else 1.0   # monster besar sulit terpental
	if is_mini:
		resist = 0.08
	if dir != Vector2.ZERO:
		_knock = dir.normalized() * 170.0 * resist
		Audio.sfx("hit", randf_range(0.9, 1.15))
	var main = get_tree().current_scene
	var tcol := Color(1, 1, 1)
	var tsz := 13.0
	if crit:
		tcol = Color(1.0, 0.72, 0.1)
		tsz = 22.0
	elif dir == Vector2.ZERO:                       # damage racun / bakar berjalan: kecil & berwarna
		tcol = Color(0.55, 1.0, 0.35) if _poison > 0.0 else Color(1.0, 0.6, 0.2)
		tsz = 11.0
	main.fx_text(global_position + Vector2(0, -bar_y - 2.0), str(amount) + ("!" if crit else ""), tcol, tsz)
	if dir != Vector2.ZERO:
		main.fx_burst(global_position, Color(1, 0.9, 0.6), 5, 50.0, 0.3, 0.0, 1.8, "star")
	if hp <= 0:
		_die()


func _die() -> void:
	remove_from_group("enemies")
	remove_from_group("hostile")
	remove_from_group("lod")
	var main = get_tree().current_scene
	Audio.sfx("enemy_die")
	main.fx_burst(global_position, Color(1, 1, 1), 10, 60.0, 0.5, 40.0, 2.0, "dot")
	if Net.active and not puppet and Net.is_host:
		Net.host_entity_died(net_id)
	# hadiah untuk pemain lokal (kalau co-op: hanya yang berada di dekat monster ini; "player" bisa saja pemain lain)
	var local = get_tree().get_first_node_in_group("player")
	var rewarded: bool = puppet or not Net.active or (local != null and local.global_position.distance_to(global_position) < Net.VIEW_R + 80.0)
	if rewarded:
		_reward(main, local)
	if puppet:
		queue_free()
		return
	if is_mini:
		main.mini_died(mini_idx)
	else:
		main.enemy_died(self, kind, biome_idx)
	queue_free()


# Drop + XP + hitungan quest untuk pemain lokal (loot pribadi di co-op)
func _reward(main, local) -> void:
	var luk: int = int(local.stat("luk")) if local else 1
	var bonus: float = 1.0 + luk * 0.02
	var bm: bool = bool(main.get("blood_moon"))      # Bulan Darah: hadiah lebih besar
	if bm:
		bonus *= 1.5
	# koin & permata kecil (monster besar menjatuhkan lebih banyak)
	if randf() < 0.75 * bonus and not passive:
		main.spawn_pickup("coin", global_position, int(randf_range(1, 3) * (1.0 + (mult - 1.0) * 0.6) * maxf(radius / 10.0, 1.0)))
	if randf() < 0.08 * bonus and not passive:
		main.spawn_pickup("gems", global_position, 1 + (1 if radius >= 14.0 else 0))
	if randf() < 0.18 * bonus:
		main.spawn_pickup("item:potion_hp", global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8)), 1)
	if is_mini:
		# hadiah mini boss: koin banyak, permata, 2 perlengkapan, ramuan
		main.spawn_pickup("coin", global_position, int(randf_range(25.0, 45.0)))
		main.spawn_pickup("gems", global_position + Vector2(8, 0), int(randf_range(3.0, 7.0)))
		main.spawn_pickup("item:potion_hp2", global_position + Vector2(-8, 4), 1)
		for gi in 2:
			main.spawn_pickup("item:" + Gear.roll_gear(biome_idx, luk), global_position + Vector2(randf_range(-14, 14), randf_range(-14, 14)), 1)
	for d in _drops():
		if randf() < float(d[1]) * bonus:
			main.spawn_pickup("item:" + String(d[0]), global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 1)
	if not passive:
		for d in Items.biome_drops(biome_idx):                  # bahan khas biome
			if randf() < float(d[1]) * bonus * (1.6 if is_mini else 1.0):
				main.spawn_pickup("item:" + String(d[0]), global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 1)
	# perlengkapan Raven (7 rarity), peluang kecil; monster besar & luck lebih tinggi = lebih sering
	if not passive and randf() < Gear.DROP_BASE * bonus * maxf(radius / 10.0, 1.0):
		main.spawn_pickup("item:" + Gear.roll_gear(biome_idx, luk), global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 1)
	if local:
		local.give_xp(maxi(int(float(xp_reward) * Bal.xp_diff_mult(level, local.level()) * (1.5 if bm else 1.0)), 1))
	Game.quest_progress("kill")
	Game.count_kill(kind)
	Story.check_notice()


# [[item, peluang]]
func _drops() -> Array:
	match archetype():
		"slime":
			var l := [["goo", 0.6]]
			if biome_idx == 3:
				l.append(["shard", 0.35])
			elif biome_idx == 2:
				l.append(["amber", 0.35])
			elif biome_idx == 4:
				l.append(["coal", 0.4])
			return l
		"bee":
			return [["honey", 0.5], ["stinger", 0.4]]
		"cow":
			return [["milk", 0.8], ["meat", 0.7], ["leather", 0.7]]
		"chicken":
			return [["egg", 0.7], ["feather", 0.8], ["meat", 0.3]]
		"snake":
			return [["fang", 0.5], ["venom", 0.3], ["leather", 0.15]]
		"fiend":
			return [["horn", 0.35], ["coal", 0.4], ["sunshard", 0.2 if biome_idx == 2 else 0.05], ["frost", 0.3 if biome_idx == 3 else 0.0]]
		"wisp":
			return [["goo", 0.3], ["sunshard", 0.3 if biome_idx == 2 else 0.0], ["frost", 0.3 if biome_idx == 3 else 0.0], ["obsidian", 0.2 if biome_idx == 4 else 0.0]]
		"goblin":
			return [["scrap", 0.55], ["leather", 0.3], ["coal", 0.3 if biome_idx == 4 else 0.0], ["shard", 0.25 if biome_idx == 3 else 0.0], ["amber", 0.25 if biome_idx == 2 else 0.0]]
		"spider":
			return [["web", 0.65], ["fang", 0.3], ["venom", 0.2]]
		"ogre":
			return [["tusk", 0.55], ["meat", 0.5], ["leather", 0.5], ["horn", 0.1], ["potion_hp2", 0.08]]
		"red_ogre":
			return [["tusk", 0.9], ["horn", 0.5], ["coal", 0.5], ["obsidian", 0.3 if biome_idx == 4 else 0.1], ["potion_hp2", 0.25]]
		"wolf":
			return [["fang", 0.5], ["leather", 0.5], ["meat", 0.4], ["frost", 0.3 if biome_idx == 3 else 0.0]]
		"kobold":
			return [["scrap", 0.55], ["leather", 0.3], ["amber", 0.25 if biome_idx == 2 else 0.0], ["coal", 0.3 if biome_idx == 4 else 0.0]]
		"bat":
			return [["fang", 0.4], ["leather", 0.25], ["obsidian", 0.15 if biome_idx == 4 else 0.0], ["frost", 0.2 if biome_idx == 3 else 0.0]]
		"bear":
			return [["leather", 0.7], ["meat", 0.6], ["fang", 0.4], ["frost", 0.3 if biome_idx == 3 else 0.0], ["potion_hp2", 0.08]]
		"golem":
			return [["scrap", 0.4], ["shard", 0.5 if biome_idx == 3 else 0.0], ["coal", 0.5 if biome_idx == 4 else 0.0], ["obsidian", 0.4 if biome_idx == 4 else 0.0], ["amber", 0.3 if biome_idx == 2 else 0.0], ["potion_hp2", 0.08]]
		"mummy":
			return [["scrap", 0.3], ["amber", 0.4], ["sunshard", 0.25], ["venom", 0.1]]
		"centipede":
			return [["fang", 0.5], ["venom", 0.4], ["leather", 0.2], ["amber", 0.2 if biome_idx == 2 else 0.0]]
	return []
