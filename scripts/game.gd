extends Node

const Bal = preload("res://scripts/balance.gd")
const Jobs = preload("res://scripts/jobs.gd")
# Autoload "Game": data pemain, pengaturan, quest, dan save/load.

const SAVE_PATH := "user://greenwood_save.json"
const SAVE_TMP := "user://greenwood_save.tmp"
const SAVE_BAK := "user://greenwood_save.bak"
const SAVE_MAP_V := 2          # naikkan kalau format save berubah, lalu tambah langkah di _migrate()
const SET_PATH := "user://greenwood_settings.json"
const STAT_KEYS := ["str", "int", "vit", "dex", "luk"]
const STAT_NAMES := {"str": "STR", "int": "INT", "vit": "VIT", "dex": "DEX", "luk": "LUK"}
const STAT_LONG := {
	"str": "Kekuatan: serangan pedang +7 per poin",
	"int": "Kecerdasan: sihir +7 & MP maks +18 per poin",
	"vit": "Vitalitas: HP maks +18 & pertahanan +0.8 per poin",
	"dex": "Kelincahan: jalan +2 px/dtk, serangan lebih cepat, sedikit kritis",
	"luk": "Keberuntungan: kritis +1.25%, drop lebih banyak, peluang gacha",
}
const POINTS_PER_LEVEL := 2
const GACHA_COST := 60

var p := {}
var settings := {"bgm": 0.7, "sfx": 0.9, "muted": false, "show_fps": false, "low_mode": false, "ultra_mode": false, "cap30": false, "haptic": true}
var in_game := false
var world_seed := 0
var chests_opened: Array = []
var checkpoints: Array = []
var checkpoint_pos: Array = []


func _ready() -> void:
	p = default_player()
	load_settings()
	_setup_input()


func _key(a: String, keys: Array) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(a, ev)


func _setup_input() -> void:
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("move_up", [KEY_W, KEY_UP])
	_key("move_down", [KEY_S, KEY_DOWN])
	_key("attack", [KEY_J, KEY_SPACE])
	_key("magic", [KEY_K])
	_key("interact", [KEY_E])
	_key("dodge", [KEY_L, KEY_SHIFT])
	_key("skill", [KEY_U])
	_key("inventory", [KEY_I, KEY_TAB])
	_key("potion_hp", [KEY_1])
	_key("potion_mp", [KEY_2])
	_key("pause", [KEY_ESCAPE, KEY_P])


func _notification(what: int) -> void:
	if in_game and (what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST):
		save()


func default_player() -> Dictionary:
	return {
		"name": "Petualang", "level": 1, "xp": 0, "points": 0,
		"stats": {"str": 1, "int": 1, "vit": 1, "dex": 1, "luk": 1},
		"coins": 50, "gems": 120, "gender": "m", "skin": "skin_default", "skins": ["skin_default"],
		"sword": "sw_wood", "staff": "st_0", "job": "",
		"equip": {"chest": "", "legs": "", "boots": "", "gloves": "", "shield": "", "pick": ""},
		"inv": {"potion_hp": 3, "potion_mp": 2, "sw_wood": 1, "st_0": 1},
		"hp": 100, "mp": 100, "pos": [], "pulls": 0,
		"quest": {"type": "none", "need": 0, "have": 0, "coins": 0, "gems": 0, "xp": 0, "label": ""},
		"intro": false, "world2_unlocked": false, "world": 0, "clock": 240.0,
		"secrets": {}, "kills": {},
		"story": {"ch": 0, "on": false, "n": false, "k": {}, "v": {}}, "bosskills": {}, "dungeons": {}, "lore": {}, "bseen": {},
		"fog": {}, "jurnal": {}, "plot": {}, "sq": {}, "fast": {}, "st": {}, "ach": {}, "title": "", "tower": 0, "rush": 0, "rush_clear": 0, "ench": {}, "bst": {}, "house": 0, "stash": {}, "ng": 0, "ng_end": "",
	}


# Dunia aktif: 0 = World 1, 1 = World 2 (dibaca world.gd & main.gd saat adegan dibuat)
func world_id() -> int:
	return clampi(int(p.get("world", 0)), 0, 1)


# Pindah dunia: simpan, lalu muat ulang adegan utama. Posisi dikosongkan supaya pemain muncul di titik awal dunia tujuan.
func switch_world(w: int) -> void:
	p["world"] = clampi(w, 0, 1)
	if w == 1:
		p["world2_unlocked"] = true
	p["pos"] = []
	checkpoint_pos = []
	save()
	get_tree().reload_current_scene()


func kill_count(kind: String) -> int:
	return int(p["kills"].get(kind, 0))


func count_kill(kind: String) -> void:
	p["kills"][kind] = kill_count(kind) + 1


# Hitung bos yang dikalahkan pemain lokal (kunci = style bos, mis. "ent"); dipakai Kisah Utama
func count_boss(style: String) -> void:
	if not p.has("bosskills"):
		p["bosskills"] = {}
	p["bosskills"][style] = int(p["bosskills"].get(style, 0)) + 1


func xp_needed(lv: int) -> int:
	return Bal.xp_needed(lv)


func new_game(nm: String, gender: String, job: String = "") -> void:
	p = default_player()
	p["name"] = nm if nm != "" else "Petualang"
	p["gender"] = gender
	if job != "":
		p["job"] = job
		p["stats"] = Jobs.start_stats(job)
	world_seed = randi()
	chests_opened = []
	checkpoints = []
	checkpoint_pos = []
	in_game = true
	save()


# ------------------------------------------------------------------ quest
func make_quest(lv: int) -> Dictionary:
	var kinds := ["kill", "log", "fish", "ore"]
	var k: String = kinds[randi() % kinds.size()]
	var need := 0
	var label := ""
	match k:
		"kill":
			need = 6 + lv
			label = "Kalahkan %d monster" % need
		"log":
			need = 8 + lv
			label = "Kumpulkan %d kayu gelondong" % need
		"fish":
			need = 3 + lv / 2
			label = "Tangkap %d ikan" % need
		_:
			need = 6 + lv
			label = "Tambang %d bijih/batu" % need
	return {"type": k, "need": need, "have": 0, "coins": 40 + lv * 15, "gems": 10 + lv * 2, "xp": Bal.quest_xp(lv), "label": label}


func quest_progress(kind: String, n: int = 1) -> void:
	var q: Dictionary = p["quest"]
	if q["type"] == kind and int(q["have"]) < int(q["need"]):
		q["have"] = mini(int(q["have"]) + n, int(q["need"]))
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			if int(q["have"]) >= int(q["need"]):
				hud.toast("Quest selesai! Temui Tetua Oren")
			else:
				hud.toast("Quest: %d / %d" % [int(q["have"]), int(q["need"])])


func quest_done() -> bool:
	var q: Dictionary = p["quest"]
	return q["type"] != "none" and int(q["have"]) >= int(q["need"])


# ------------------------------------------------------------------ pengaturan
func load_settings() -> void:
	if not FileAccess.file_exists(SET_PATH):
		return
	var f := FileAccess.open(SET_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		settings["bgm"] = clampf(float(data.get("bgm", 0.7)), 0.0, 1.0)
		settings["sfx"] = clampf(float(data.get("sfx", 0.9)), 0.0, 1.0)
		settings["muted"] = bool(data.get("muted", false))
		settings["show_fps"] = bool(data.get("show_fps", false))
		settings["low_mode"] = bool(data.get("low_mode", false))
		settings["ultra_mode"] = bool(data.get("ultra_mode", false))
		settings["cap30"] = bool(data.get("cap30", false))
		settings["haptic"] = bool(data.get("haptic", true))


func set_haptic(on: bool) -> void:
	settings["haptic"] = on
	save_settings()
	if on:
		vibrate(40)


# Getar HP (Android/iOS). Tidak melakukan apa-apa di PC atau jika dimatikan di setelan.
func vibrate(ms: int) -> void:
	if bool(settings.get("haptic", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func save_settings() -> void:
	_atomic_write(SET_PATH, SET_PATH + ".tmp", "", JSON.stringify(settings))


# ------------------------------------------------------------------ save / load
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_TMP) or FileAccess.file_exists(SAVE_BAK)


# Tulis ke file sementara -> cek bisa dibaca balik -> baru timpa file asli.
# Kalau HP mati / app di-kill di tengah proses, file lama tetap utuh (atau ada .bak).
func _atomic_write(path: String, tmp: String, bak: String, text: String) -> bool:
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	f.close()
	var chk := FileAccess.open(tmp, FileAccess.READ)
	if chk == null:
		return false
	var ok: bool = chk.get_length() == text.to_utf8_buffer().size()
	chk.close()
	if not ok:
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):
		if bak != "":
			if FileAccess.file_exists(bak):
				DirAccess.remove_absolute(bak)
			DirAccess.rename_absolute(path, bak)
		else:
			DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


func save() -> void:
	var pd: Dictionary = p
	var sd: int = world_seed
	var ch: Array = chests_opened
	var cps: Array = checkpoints
	var cpp: Array = checkpoint_pos
	if Net.active and not Net.saved.is_empty():
		# sesi co-op sebagai klien: yang disimpan tetap dunia main-sendiri (seed, peti, checkpoint, posisi), hanya karakternya yang maju
		pd = p.duplicate()
		pd["pos"] = Net.saved["pos"]
		pd["world"] = int(Net.saved.get("world", 0))
		sd = int(Net.saved["seed"])
		ch = Net.saved["chests"]
		cps = Net.saved["cps"]
		cpp = Net.saved["cp"]
	var text := JSON.stringify({"p": pd, "seed": sd, "chests": ch, "cps": cps, "cp": cpp, "map_v": SAVE_MAP_V})
	if not _atomic_write(SAVE_PATH, SAVE_TMP, SAVE_BAK, text):
		push_warning("Game.save(): gagal menyimpan (penyimpanan penuh?)")


# Backup: salin save ke clipboard (bisa ditempel ke catatan/chat), lalu pulihkan dari clipboard di HP baru.
func export_text() -> String:
	save()
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


func import_text(text: String) -> bool:
	var data = JSON.parse_string(text.strip_edges())
	if typeof(data) != TYPE_DICTIONARY or not data.has("p") or typeof(data["p"]) != TYPE_DICTIONARY:
		return false
	if not data["p"].has("level") or not data["p"].has("name"):
		return false
	if not _atomic_write(SAVE_PATH, SAVE_TMP, SAVE_BAK, text.strip_edges()):
		return false
	return load_save()


# Baca satu file save; kembalikan Dictionary valid, atau {} kalau rusak/tidak ada.
func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("p") or typeof(data["p"]) != TYPE_DICTIONARY:
		return {}
	return data


# Urutan coba: save utama -> sementara (sisa tulis yang terputus) -> backup.
func _read_best_save() -> Dictionary:
	for path in [SAVE_PATH, SAVE_TMP, SAVE_BAK]:
		var d := _read_save_file(path)
		if not d.is_empty():
			if path != SAVE_PATH:
				push_warning("Save utama rusak/hilang, memakai " + path)
			return d
	return {}


# Tangga migrasi: tiap versi format punya satu langkah. Tambah blok baru di bawah saat format berubah.
func _migrate(data: Dictionary) -> Dictionary:
	var v: int = int(data.get("map_v", 1))
	if v < 2:
		# peta lama (256x192): koordinat tidak berlaku lagi di peta 512x256
		data["p"]["pos"] = []
		data["cp"] = []
		v = 2
	# if v < 3:  ...ubah data di sini...  v = 3
	data["map_v"] = v
	return data


# JSON mengubah int jadi float; kembalikan angka bulat secara rekursif (string & bool dibiarkan)
func _deep_ints(v):
	if typeof(v) == TYPE_DICTIONARY:
		var o := {}
		for k in v.keys():
			o[str(k)] = _deep_ints(v[k])
		return o
	if typeof(v) == TYPE_FLOAT:
		return int(v)
	return v


func _int_dict(src) -> Dictionary:
	var out := {}
	if typeof(src) == TYPE_DICTIONARY:
		for k in src.keys():
			out[str(k)] = int(src[k])
	return out


func load_save() -> bool:
	var data: Dictionary = _read_best_save()
	if data.is_empty():
		return false
	data = _migrate(data)
	var d := default_player()
	var sp: Dictionary = data["p"]
	for k in ["level", "xp", "points", "coins", "gems", "hp", "mp", "pulls", "tower", "rush", "rush_clear", "house", "ng"]:
		d[k] = int(sp.get(k, d[k]))
	for k in ["name", "gender", "skin", "sword", "staff", "job", "title", "ng_end"]:
		d[k] = str(sp.get(k, d[k]))
	d["intro"] = bool(sp.get("intro", false))
	d["world2_unlocked"] = bool(sp.get("world2_unlocked", false))
	d["world"] = clampi(int(sp.get("world", 0)), 0, 1)
	var st: Dictionary = _int_dict(sp.get("stats", {}))
	for k in STAT_KEYS:
		d["stats"][k] = maxi(int(st.get(k, 1)), 1)
	d["inv"] = _int_dict(sp.get("inv", {}))
	var eq = sp.get("equip", {})
	if typeof(eq) == TYPE_DICTIONARY:
		for k in d["equip"].keys():
			d["equip"][k] = str(eq.get(k, ""))
	var owned: Array = []
	for s in sp.get("skins", ["skin_default"]):
		owned.append(str(s))
	if not owned.has("skin_default"):
		owned.append("skin_default")
	d["skins"] = owned
	var pos = sp.get("pos", [])
	if typeof(pos) == TYPE_ARRAY and pos.size() == 2:
		d["pos"] = [float(pos[0]), float(pos[1])]
	var q = sp.get("quest", {})
	if typeof(q) == TYPE_DICTIONARY:
		var dq: Dictionary = d["quest"]
		dq["type"] = str(q.get("type", "none"))
		dq["label"] = str(q.get("label", ""))
		for k in ["need", "have", "coins", "gems", "xp"]:
			dq[k] = int(q.get(k, 0))
	var ssec = sp.get("secrets", {})
	if typeof(ssec) == TYPE_DICTIONARY:
		for k in ssec.keys():
			var v = ssec[k]
			if typeof(v) == TYPE_DICTIONARY:
				var dd := {}
				for kk in v.keys():
					dd[str(kk)] = int(v[kk])
				d["secrets"][str(k)] = dd
			elif typeof(v) == TYPE_BOOL:
				d["secrets"][str(k)] = v
			else:
				d["secrets"][str(k)] = int(v)
	for dk in ["plot", "sq", "fast", "st", "ach", "ench", "bst", "stash"]:
		var dv = sp.get(dk, {})
		if typeof(dv) == TYPE_DICTIONARY:
			d[dk] = _deep_ints(dv)
	var skills = sp.get("kills", {})
	if typeof(skills) == TYPE_DICTIONARY:
		for k in skills.keys():
			d["kills"][str(k)] = int(skills[k])
	var bk = sp.get("bosskills", {})
	if typeof(bk) == TYPE_DICTIONARY:
		for k in bk.keys():
			d["bosskills"][str(k)] = int(bk[k])
	var dg = sp.get("dungeons", {})
	if typeof(dg) == TYPE_DICTIONARY:
		for k in dg.keys():
			d["dungeons"][str(k)] = int(dg[k])
	d["clock"] = float(sp.get("clock", 240.0))
	var lr = sp.get("lore", {})
	if typeof(lr) == TYPE_DICTIONARY:
		for k in lr.keys():
			d["lore"][str(k)] = int(lr[k])
	var bsn = sp.get("bseen", {})
	if typeof(bsn) == TYPE_DICTIONARY:
		for k in bsn.keys():
			d["bseen"][str(k)] = int(bsn[k])
	var jr = sp.get("jurnal", {})
	if typeof(jr) == TYPE_DICTIONARY:
		for k in jr.keys():
			d["jurnal"][str(k)] = int(jr[k])
	var fg = sp.get("fog", {})
	if typeof(fg) == TYPE_DICTIONARY:
		for k in fg.keys():
			d["fog"][str(k)] = str(fg[k])
	var sty = sp.get("story", {})
	if typeof(sty) == TYPE_DICTIONARY:
		var ds: Dictionary = d["story"]
		ds["ch"] = maxi(int(sty.get("ch", 0)), 0)
		ds["on"] = bool(sty.get("on", false))
		ds["n"] = bool(sty.get("n", false))
		for key in ["k", "v"]:
			var sub = sty.get(key, {})
			if typeof(sub) == TYPE_DICTIONARY:
				for kk in sub.keys():
					ds[key][str(kk)] = int(sub[kk])
	p = d
	world_seed = int(data.get("seed", randi()))
	chests_opened = []
	for v in data.get("chests", []):
		chests_opened.append(int(v))
	checkpoints = []
	for v in data.get("cps", []):
		checkpoints.append(int(v))
	var cp = data.get("cp", [])
	checkpoint_pos = [float(cp[0]), float(cp[1])] if (typeof(cp) == TYPE_ARRAY and cp.size() == 2) else []
	in_game = true
	return true
