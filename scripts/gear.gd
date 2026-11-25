extends Node
# Autoload "Gear": perlengkapan bergambar (assets/gear/weapons.png & armor.png), 7 rarity.
#
# ID item (tidak disimpan satu-satu, dibuat saat dibutuhkan lalu di-cache di Items.db):
#   senjata : "gw_<jenis>_<nomor>_<rarity>"                jenis = sword / bow / axe / hammer / pickaxe
#   armor   : "ga_<set>_<slot>_<nomor>_<rarity>"           set = ice / forest / volcano / desert
#                                                          slot = chest / legs / boots / shield / gloves
# Beliung (pickaxe) masuk slot "pick" (alat tambang), bukan slot senjata.

const DB = preload("res://scripts/gear_db.gd")
const WEAPON_PNG := "res://assets/gear/weapons.png"
const ARMOR_PNG := "res://assets/gear/armor.png"
const CELL := 64
const COLS := 16

const W_OFFSET := {"sword": 0, "bow": 57, "axe": 95, "pickaxe": 133, "hammer": 171}
const W_COUNT := {"sword": 57, "bow": 38, "axe": 38, "pickaxe": 38, "hammer": 38}
const BIOMES := ["ice", "forest", "volcano", "desert"]
const A_SLOTS := ["chest", "legs", "boots", "shield", "gloves"]
const SET_TIER := {"forest": 0, "desert": 1, "ice": 2, "volcano": 3}
const SET_NAME := {"ice": "Es", "forest": "Rimba", "volcano": "Magma", "desert": "Gurun"}
const BIOME_SET := ["forest", "forest", "desert", "ice", "volcano"]   # indeks biome game -> set armor
# Biome 5-14 (World 1 ekspansi & World 2) memakai ulang 4 set armor yang ada; kekuatannya naik lewat "stage".
const BIOME_SET_EXT := {5: "volcano", 6: "ice", 7: "ice", 8: "forest", 9: "forest", 10: "forest", 11: "desert", 12: "desert", 13: "ice", 14: "forest"}
# stage = biome - 4 (0..10), disimpan di id item sebagai rarity + 10 * stage (id lama < 10 = stage 0, tetap valid).
const STAGE_STEP := 0.18         # tiap stage menambah 18% damage / pertahanan / bonus (biome 14 = 2.8x)

const RAR_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Ancient", "Myth"]
const RAR_COL := [
	Color(0.78, 0.78, 0.82), Color(0.4, 0.85, 0.45), Color(0.35, 0.6, 1.0), Color(0.72, 0.42, 1.0),
	Color(1.0, 0.76, 0.2), Color(1.0, 0.36, 0.3), Color(1.0, 0.4, 0.9),
]
const RAR_MULT := [1.0, 1.12, 1.28, 1.5, 1.8, 2.2, 2.8]
const RAR_WEIGHT := [58.0, 26.0, 9.5, 4.2, 1.6, 0.55, 0.15]
const DROP_BASE := 0.014          # peluang gear dari monster biasa

const ELEM_FX := ["crit", "burn", "freeze", "shock", "poison", "drain"]
const ELEM_NAME := ["Baja", "Api", "Es", "Petir", "Racun", "Bayangan"]
const ADJ := ["Elang", "Naga", "Serigala", "Fajar", "Senja", "Badai", "Gagak", "Singa", "Harimau", "Raja",
	"Rimba", "Karang", "Bulan", "Surya", "Kabut", "Puncak", "Samudra", "Kristal", "Pelangi", "Bara"]
const BASE_DMG := [8, 14, 21, 29, 38]
const ARMOR_DEF := [3, 6, 10, 15, 22]
const SLOT_NAME := {"chest": "Zirah", "legs": "Legging", "boots": "Sepatu", "shield": "Perisai", "gloves": "Sarung Tangan"}
const SLOT_MULT := {"chest": 1.0, "legs": 0.7, "boots": 0.4, "shield": 0.8, "gloves": 0.4}
# dm = pengali damage, reach = jangkauan, arc = sudut tebasan (radian, tiap sisi), cd = pengali jeda serang,
# hl = panjang senjata saat dipegang (piksel)
const WEAPON := {
	"sword": {"name": "Pedang", "dm": 1.0, "reach": 32.0, "arc": 1.25, "cd": 1.0, "hl": 30.0, "shape": "long",
		"desc": "Tebasan seimbang."},
	"axe": {"name": "Kapak", "dm": 1.3, "reach": 30.0, "arc": 2.1, "cd": 1.25, "hl": 30.0, "shape": "great",
		"desc": "Tebasan sangat lebar, kena banyak musuh. Menebang pohon lebih cepat."},
	"hammer": {"name": "Palu", "dm": 1.7, "reach": 34.0, "arc": 0.0, "cd": 1.55, "hl": 32.0, "shape": "great", "slam": true,
		"desc": "Hantaman area ke sekeliling titik pukul, mendorong musuh."},
	"bow": {"name": "Busur", "dm": 1.1, "reach": 0.0, "arc": 0.0, "cd": 1.0, "hl": 30.0, "shape": "long", "ranged": true,
		"desc": "Menembakkan panah jarak jauh."},
}

var _sheets := {}


# ------------------------------------------------------------------ gambar
func _sheet(s: String) -> Texture2D:
	if _sheets.has(s):
		return _sheets[s]
	var src: Texture2D = load(WEAPON_PNG if s == "w" else ARMOR_PNG)
	if src == null:
		return null
	var ct := CanvasTexture.new()
	ct.diffuse_texture = src
	ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR     # sprite 64px diperkecil, jangan bergerigi
	_sheets[s] = ct
	return ct


@warning_ignore("integer_division")
func draw_sprite(ci: CanvasItem, sheet: String, gi: int, dst: Rect2, col: Color = Color.WHITE) -> void:
	var tx := _sheet(sheet)
	if tx == null:
		return
	var src := Rect2((gi % COLS) * CELL, (gi / COLS) * CELL, CELL, CELL)
	ci.draw_texture_rect_region(tx, dst, src, col)


# Gambar ikon item di tengah c berukuran s (dipakai tas, toko, drop di tanah).
func draw_icon(ci: CanvasItem, d: Dictionary, c: Vector2, s: float) -> void:
	draw_sprite(ci, String(d["gsheet"]), int(d["gi"]), Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)))


# Gambar senjata/alat dipegang: gagang di pos, ujung menghadap ang. Sprite berujung kanan-atas, gagang kiri-bawah.
func draw_held(ci: CanvasItem, sheet: String, gi: int, pos: Vector2, ang: float, base: Transform2D, hl: float) -> void:
	var k: float = hl / 70.0
	ci.draw_set_transform_matrix(base * Transform2D(ang + PI / 4.0, Vector2(k, k), 0.0, pos))
	draw_sprite(ci, sheet, gi, Rect2(-8.0, -56.0, 64.0, 64.0))
	ci.draw_set_transform_matrix(base)


# Armor terpasang digambar menempel di badan pahlawan (titik (0,0) = tengah badan, kaki di y=+10).
# sx = -1 kalau menghadap kiri. off = geseran badan frame ini (Art.hero_armor_offset): armor ikut bergerak saat
# jalan, menyerang, kena hit, dan mati. alpha < 1 untuk memudarkan armor (saat mati).
func draw_armor(ci: CanvasItem, sx: float, off: Vector2, alpha: float = 1.0) -> void:
	if alpha <= 0.0:
		return
	var eq: Dictionary = Game.p["equip"]
	var parts := [["shield", Vector2(-7.5, -1.0), 15.0], ["legs", Vector2(0.0, 5.0), 12.0], ["boots", Vector2(0.0, 9.0), 12.0],
		["chest", Vector2(0.0, -3.0), 15.0], ["gloves", Vector2(6.5, 0.0), 9.0]]
	for pt in parts:
		var id: String = String(eq.get(pt[0], ""))
		if id == "" or not id.begins_with("ga_"):
			continue
		var d: Dictionary = Items.info(id)
		if not d.has("gi"):
			continue
		var c: Vector2 = pt[1]
		c.x *= sx
		var s: float = pt[2]
		draw_sprite(ci, "a", int(d["gi"]), Rect2(c.x + off.x - s * 0.5, c.y + off.y - s * 0.5, s, s), Color(1, 1, 1, 0.95 * alpha))


# ------------------------------------------------------------------ pembuat item
func rar_color(r: int) -> Color:
	return RAR_COL[clampi(r, 0, 6)]


func make_item(id: String) -> Dictionary:
	var p := id.split("_")
	if p.size() == 4 and p[0] == "gw":
		return _make_weapon(id, p[1], int(p[2]), int(p[3]))
	if p.size() == 5 and p[0] == "ga":
		return _make_armor(id, p[1], p[2], int(p[3]), int(p[4]))
	return {}


@warning_ignore("integer_division")
func _make_weapon(id: String, kind: String, idx: int, r: int) -> Dictionary:
	if not W_COUNT.has(kind) or idx < 0 or idx >= int(W_COUNT[kind]):
		return {}
	var stage: int = r / 10
	var sm: float = 1.0 + STAGE_STEP * float(stage)
	r = clampi(r % 10, 0, 6)
	var n: int = int(W_COUNT[kind])
	var gi: int = int(W_OFFSET[kind]) + idx
	var t: int = mini(idx * 5 / n, 4)
	var rm: float = float(RAR_MULT[r]) * sm
	var el: int = int(DB.W_ELEM.substr(gi, 1))
	var glow: Color = Color.html(DB.W_COL.substr(gi * 6, 6))
	var col: Color = RAR_COL[r]
	var base := {"rarity": r, "rname": RAR_NAMES[r], "kind": kind, "gsheet": "w", "gi": gi, "tier_idx": t, "stage": stage}
	var d: Dictionary
	if kind == "pickaxe":
		var dig: float = 1.0 + 0.12 * t + 0.1 * r + 0.06 * stage
		var ore: float = 0.05 * t + 0.04 * r + 0.01 * stage
		var desc := "Menambang %d%% lebih cepat, peluang ore ekstra %d%%." % [roundi((dig - 1.0) * 100.0), roundi(ore * 100.0)]
		var nm := "Beliung %s %s%s" % [ELEM_NAME[el], ADJ[gi % ADJ.size()], (" +%d" % stage) if stage > 0 else ""]
		d = Items.make_entry(id, nm, "armor", col, int((10 + t * 8) * 4 * (1.0 + 0.35 * r) * sm), desc, {
			"slot": "pick", "def": 0, "tier": clampi(t + 1, 1, 5), "hp": 0, "spd": 0.0, "atk": 0, "block": 0.0,
			"dig": dig, "ore": ore, "blade": glow})
	else:
		var w: Dictionary = WEAPON[kind]
		var dmg: int = roundi(float(BASE_DMG[t]) * float(w["dm"]) * rm)
		var fx := "none"
		if r >= 2 or el == 0:
			fx = String(ELEM_FX[el])
		var ex := {
			"dmg": dmg, "reach": float(w["reach"]), "scale": 1.1, "shape": String(w["shape"]), "blade": glow, "fx": fx,
			"cd": float(w["cd"]), "wtype": kind, "arc": float(w["arc"]), "hl": float(w["hl"]),
			"slam": bool(w.get("slam", false)), "ranged": bool(w.get("ranged", false))}
		var desc2: String = String(w["desc"])
		if kind == "bow":
			ex["pierce"] = 1 if r >= 3 else 0
			ex["spread"] = 3 if r >= 5 else (2 if r >= 4 else 1)
			ex["speed"] = 360.0
			if int(ex["spread"]) > 1:
				desc2 += " Menembak %d panah sekaligus." % int(ex["spread"])
			if int(ex["pierce"]) > 0:
				desc2 += " Menembus musuh."
		if r >= 2 and el > 0:
			desc2 += " Elemen %s." % String(ELEM_NAME[el])
		var nm2 := "%s %s %s%s" % [w["name"], ELEM_NAME[el], ADJ[gi % ADJ.size()], (" +%d" % stage) if stage > 0 else ""]
		d = Items.make_entry(id, nm2, "sword", col, int(dmg * 4 * (1.0 + 0.35 * r)), desc2, ex)
	for k in base.keys():
		d[k] = base[k]
	return d


@warning_ignore("integer_division")
func _make_armor(id: String, set_id: String, slot: String, idx: int, r: int) -> Dictionary:
	var bi: int = BIOMES.find(set_id)
	var si: int = A_SLOTS.find(slot)
	if bi < 0 or si < 0 or idx < 0 or idx >= 18:
		return {}
	var stage: int = r / 10
	r = clampi(r % 10, 0, 6)
	var gi: int = (bi * 5 + si) * 18 + idx
	var t: int = clampi(int(SET_TIER[set_id]) + (1 if idx / 6 == 2 else 0), 0, 4)
	var rm: float = float(RAR_MULT[r]) * (1.0 + STAGE_STEP * float(stage))
	var df: int = maxi(1, roundi(float(ARMOR_DEF[t]) * float(SLOT_MULT[slot]) * rm))
	var ex := {"slot": slot, "def": df, "tier": t + 1, "hp": 0, "spd": 0.0, "atk": 0, "block": 0.0,
		"rarity": r, "rname": RAR_NAMES[r], "kind": slot, "gsheet": "a", "gi": gi, "set": set_id, "stage": stage}
	var desc := "Pertahanan +%d" % df
	match slot:
		"chest":
			ex["hp"] = roundi(10.0 * (t + 1) * rm)
		"legs":
			ex["hp"] = roundi(5.0 * (t + 1) * rm)
		"boots":
			ex["spd"] = minf(3.0 * (t + 1) * rm, 40.0)
		"gloves":
			ex["atk"] = roundi(2.0 * (t + 1) * rm)
		"shield":
			ex["block"] = minf(0.04 * (t + 1) * rm, 0.4)
	# bonus tema set
	match set_id:
		"ice":
			ex["def"] = roundi(float(df) * 1.12)
			desc = "Pertahanan +%d" % int(ex["def"])
		"forest":
			ex["hp"] = int(ex["hp"]) + roundi(4.0 * (t + 1) * rm)
		"volcano":
			ex["atk"] = int(ex["atk"]) + roundi(1.0 * (t + 1) * rm)
		"desert":
			ex["spd"] = minf(float(ex["spd"]) + 2.0 * (t + 1) * rm, 45.0)
	if int(ex["hp"]) > 0:
		desc += ", HP maks +%d" % int(ex["hp"])
	if float(ex["spd"]) > 0.0:
		desc += ", kecepatan +%d" % int(ex["spd"])
	if int(ex["atk"]) > 0:
		desc += ", serangan +%d" % int(ex["atk"])
	if float(ex["block"]) > 0.0:
		desc += ", tangkis %d%%" % int(float(ex["block"]) * 100.0)
	var nm := "%s %s %s%s" % [SLOT_NAME[slot], SET_NAME[set_id], ADJ[gi % ADJ.size()], (" +%d" % stage) if stage > 0 else ""]
	var price: int = int(df * 6 * (1.0 + 0.35 * r))
	return Items.make_entry(id, nm, "armor", RAR_COL[r], price, desc, ex)


# ------------------------------------------------------------------ undian drop
func make_id_weapon(kind: String, idx: int, r: int) -> String:
	return "gw_%s_%d_%d" % [kind, idx, r]


func make_id_armor(set_id: String, slot: String, idx: int, r: int) -> String:
	return "ga_%s_%s_%d_%d" % [set_id, slot, idx, r]


func roll_rarity(biome: float, luk: int, min_r: int = 0) -> int:
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
		r = i
		if roll <= 0.0:
			break
	return clampi(maxi(r, min_r), 0, 6)


# Undi satu perlengkapan sesuai biome (0-14). Mengembalikan id item (tanpa awalan "item:").
# Biome 0-4 seperti semula. Biome 5-14: sprite terbaik (tier senjata 5, varian armor 12-17), rarity sedikit
# lebih tinggi, dan stage = biome - 4 yang menaikkan stat (lihat STAGE_STEP).
@warning_ignore("integer_division")
func roll_gear(biome: int, luk: int, min_r: int = 0) -> String:
	var b: int = clampi(biome, 0, 14)
	var bl: int = mini(b, 4)
	var stage: int = maxi(b - 4, 0)
	var beff: float = float(bl) + float(stage) * 0.35
	var r: int = roll_rarity(beff, luk, min_r)
	var rid: int = r + stage * 10
	# bobot kategori: senjata 68, armor 32
	var cats := ["sword", "sword", "sword", "sword", "bow", "bow", "axe", "axe", "hammer", "pickaxe",
		"chest", "chest", "legs", "legs", "boots", "shield", "gloves"]
	var cat: String = cats[randi() % cats.size()]
	if cat in A_SLOTS:
		var set_id: String = String(BIOME_SET[b]) if b <= 4 else String(BIOME_SET_EXT.get(b, "volcano"))
		var aidx: int = randi() % 18 if b <= 4 else 12 + randi() % 6
		return make_id_armor(set_id, cat, aidx, rid)
	var n: int = int(W_COUNT[cat])
	var tier: int = clampi(bl - 1 + (randi() % 2), 0, 4)
	if b > 4:
		tier = 4
	var lo: int = tier * n / 5
	var hi: int = maxi((tier + 1) * n / 5, lo + 1)
	return make_id_weapon(cat, lo + randi() % (hi - lo), rid)
