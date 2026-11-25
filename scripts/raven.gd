extends Node
# Autoload "Raven": icon Raven Fantasy Icons (2192 icon, 32x32) + perlengkapan 7 rarity.
#
# Icon: tersimpan di 3 atlas (assets/raven/atlas_N.png, tinggi <= 2048 supaya aman di HP lama).
#   Pemakaian: texture = Raven.icon(123)
#
# Perlengkapan: id berbentuk "rv_<nomor icon>_<rarity 0-6>", mis. "rv_1441_3" = icon 1441, Epic.
#   Datanya TIDAK disimpan satu-satu; dibuat saat dibutuhkan lalu di-cache di Items.db, jadi
#   tidak membebani memori/FPS dan save lama tetap kompatibel (tas tetap {id: jumlah}).

const DB = preload("res://scripts/raven_db.gd")

const COUNT := 2192
const COLS := 16
const CELL := 32
const PER_ATLAS := 1024

const RAR_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Ancient", "Myth"]
const RAR_COL := [
	Color(0.78, 0.78, 0.82), Color(0.4, 0.85, 0.45), Color(0.35, 0.6, 1.0), Color(0.72, 0.42, 1.0),
	Color(1.0, 0.76, 0.2), Color(1.0, 0.36, 0.3), Color(1.0, 0.4, 0.9),
]
# pengali kekuatan tiap rarity
const RAR_MULT := [1.0, 1.12, 1.28, 1.5, 1.8, 2.2, 2.8]
# bobot dasar peluang jatuh (persen kira-kira)
const RAR_WEIGHT := [58.0, 26.0, 9.5, 4.2, 1.6, 0.55, 0.15]

const DROP_BASE := 0.014          # peluang gear dari monster biasa (dikali luck & ukuran monster)
const KIND_NAME := {
	"sword": "Pedang", "dagger": "Belati", "curved": "Scimitar", "axe": "Kapak", "hammer": "Palu",
	"spear": "Tombak", "mace": "Gada", "wand": "Tongkat", "bow": "Busur",
	"chest": "Zirah", "boots": "Sepatu", "shield": "Perisai",
}
const ADJ := ["Baja", "Elang", "Bayangan", "Badai", "Fajar", "Senja", "Naga", "Serigala", "Embun", "Bara",
	"Petir", "Raja", "Rimba", "Karang", "Bulan", "Surya", "Kabut", "Gagak", "Singa", "Harimau",
	"Kristal", "Racun", "Pelangi", "Puncak", "Samudra", "Gurun", "Salju", "Magma"]
const FX_LIST := ["crit", "burn", "freeze", "shock", "poison", "drain"]
const SWORD_DMG := [8, 14, 20, 28, 36]
const STAFF_DMG := [10, 16, 22, 30, 42]
const ARMOR_DEF := [3, 6, 10, 15, 22]
# jenis -> [pengali dmg, jangkauan, skala, bentuk, cooldown, efek bawaan]
const SWORD_KIND := {
	"sword": [1.0, 30.0, 1.05, "long", 1.0, "none"],
	"dagger": [0.8, 24.0, 0.9, "dagger", 0.7, "none"],
	"curved": [1.0, 32.0, 1.1, "curved", 0.9, "crit"],
	"axe": [1.25, 30.0, 1.2, "great", 1.25, "none"],
	"hammer": [1.5, 32.0, 1.3, "great", 1.45, "knock"],
	"spear": [1.1, 42.0, 1.2, "long", 1.1, "none"],
	"mace": [1.3, 28.0, 1.1, "short", 1.2, "none"],
}

var _atlas := {}
var _cache := {}
var _index := {}      # nomor icon -> [kategori, jenis, tier]
var _pools := {}      # kategori -> {tier: [entri]}


@warning_ignore("integer_division")
func icon(n: int) -> Texture2D:
	n = clampi(n, 1, COUNT)
	if _cache.has(n):
		return _cache[n]
	var idx := n - 1
	var a := idx / PER_ATLAS
	var local := idx % PER_ATLAS
	if not _atlas.has(a):
		_atlas[a] = load("res://assets/raven/atlas_%d.png" % a)
	var t := AtlasTexture.new()
	t.atlas = _atlas[a]
	t.region = Rect2((local % COLS) * CELL, (local / COLS) * CELL, CELL, CELL)
	_cache[n] = t
	return t


func icon_color(n: int) -> Color:
	n = clampi(n, 1, COUNT)
	return Color.html(DB.COLORS.substr((n - 1) * 6, 6))


func rar_color(r: int) -> Color:
	return RAR_COL[clampi(r, 0, 6)]


func rar_name(r: int) -> String:
	return RAR_NAMES[clampi(r, 0, 6)]


func _build_index() -> void:
	if not _index.is_empty():
		return
	for cat in DB.GEAR.keys():
		_pools[cat] = {}
		for e in DB.GEAR[cat]:
			var n: int = int(e[0])
			var t: int = int(e[2])
			_index[n] = [cat, String(e[1]), t]
			if not _pools[cat].has(t):
				_pools[cat][t] = []
			_pools[cat][t].append(n)


# "rv_1441_3" -> [1441, 3] atau [] kalau tidak valid
func parse_id(id: String) -> Array:
	if not id.begins_with("rv_"):
		return []
	var parts := id.split("_")
	if parts.size() != 3:
		return []
	return [int(parts[1]), clampi(int(parts[2]), 0, 6)]


func make_id(n: int, r: int) -> String:
	return "rv_%d_%d" % [n, r]


# Bangun data item dari id. Kosong kalau id tidak dikenal.
func make_item(id: String) -> Dictionary:
	var pr := parse_id(id)
	if pr.is_empty():
		return {}
	_build_index()
	var n: int = int(pr[0])
	var r: int = int(pr[1])
	if not _index.has(n):
		return {}
	var e: Array = _index[n]
	var cat: String = String(e[0])
	var kind: String = String(e[1])
	var t: int = int(e[2])
	var rm: float = float(RAR_MULT[r])
	var col: Color = rar_color(r)
	var nm := "%s %s" % [KIND_NAME.get(kind, "Item"), ADJ[n % ADJ.size()]]
	var base := {"icon": n, "rarity": r, "rname": RAR_NAMES[r], "kind": kind}
	var d: Dictionary
	match cat:
		"sword":
			var k: Array = SWORD_KIND[kind]
			var dmg: int = roundi(float(SWORD_DMG[t]) * float(k[0]) * rm)
			var fx: String = String(k[5])
			if r >= 2:
				fx = FX_LIST[n % FX_LIST.size()]
			d = Items.make_entry(id, nm, "sword", col, int(dmg * 4 * (1.0 + 0.35 * r)), "Pedang %s." % RAR_NAMES[r], {
				"dmg": dmg, "reach": float(k[1]), "scale": float(k[2]), "shape": String(k[3]),
				"blade": icon_color(n), "fx": fx, "cd": float(k[4])})
		"staff":
			var dmg2: int = roundi(float(STAFF_DMG[t]) * 0.9 * rm)
			var pierce: int = (2 if kind == "bow" else 0) + (1 if r >= 3 else 0)
			var spread: int = 3 if r >= 4 else 1
			var homing: bool = r >= 5 and kind == "wand"
			var expl: float = 38.0 if r >= 6 else 0.0
			var desc := "Tembakan %s%s" % ["panah" if kind == "bow" else "sihir", (", menembus %d musuh" % pierce) if pierce > 0 else ""]
			if spread > 1:
				desc += ", 3 arah"
			if homing:
				desc += ", mengejar"
			if expl > 0.0:
				desc += ", meledak"
			d = Items.make_entry(id, nm, "staff", col, int(dmg2 * 4 * (1.0 + 0.35 * r)), desc, {
				"dmg": dmg2, "cost": 10.0 + t * 1.5, "speed": 240.0, "pierce": pierce, "spread": spread,
				"homing": homing, "explode": expl, "scale": 1.2, "tex": clampi(t, 0, 4)})
		_:
			var mult := {"chest": 1.0, "boots": 0.4, "shield": 0.8}
			var df: int = maxi(1, roundi(float(ARMOR_DEF[t]) * float(mult[cat]) * rm))
			var ex := {"slot": cat, "def": df, "tier": t + 1, "hp": 0, "spd": 0.0, "atk": 0, "block": 0.0}
			var desc2 := "Pertahanan +%d" % df
			if cat == "chest":
				ex["hp"] = roundi(10.0 * (t + 1) * rm)
				desc2 += ", HP maks +%d" % int(ex["hp"])
			elif cat == "boots":
				ex["spd"] = minf(3.0 * (t + 1) * rm, 40.0)
				desc2 += ", kecepatan +%d" % int(ex["spd"])
			else:
				ex["block"] = minf(0.04 * (t + 1) * rm, 0.45)
				desc2 += ", tangkis %d%%" % int(float(ex["block"]) * 100.0)
			d = Items.make_entry(id, nm, "armor", col, int(df * 6 * (1.0 + 0.35 * r)), desc2, ex)
	for k2 in base.keys():
		d[k2] = base[k2]
	return d


# Tentukan rarity hasil undian. biome 0-4, luk = stat keberuntungan, min_r = rarity minimum.
func roll_rarity(biome: int, luk: int, min_r: int = 0) -> int:
	var boost: float = 1.0 + luk * 0.02 + biome * 0.12
	var w: Array = []
	var total := 0.0
	for i in 7:
		var x: float = float(RAR_WEIGHT[i]) * pow(boost, float(i))
		w.append(x)
		total += x
	var roll: float = randf() * total
	var r := 0
	for i in 7:
		roll -= float(w[i])
		if roll <= 0.0:
			r = i
			break
		r = i
	return clampi(maxi(r, min_r), 0, 6)


# Undi satu perlengkapan. Kembalikan id item (tanpa awalan "item:").
func roll_gear(biome: int, luk: int, min_r: int = 0) -> String:
	_build_index()
	var cats := ["sword", "sword", "sword", "staff", "chest", "chest", "boots", "shield"]
	var cat: String = cats[randi() % cats.size()]
	var tier: int = clampi(biome - 1 + (randi() % 2), 0, 4)
	var pool: Array = []
	var tt := tier
	while tt >= 0 and pool.is_empty():
		if _pools[cat].has(tt):
			pool = _pools[cat][tt]
		tt -= 1
	if pool.is_empty():
		tt = tier + 1
		while tt <= 4 and pool.is_empty():
			if _pools[cat].has(tt):
				pool = _pools[cat][tt]
			tt += 1
	var n: int = int(pool[randi() % pool.size()])
	return make_id(n, roll_rarity(biome, luk, min_r))
