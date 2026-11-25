extends RefCounted
# ExtraSprites - ular (snake) dan peti (chest). Berdiri sendiri, tidak mengubah file lain.
#
# Taruh file ini di  res://scripts/extra_sprites.gd
# dan atlasnya di  res://assets/extra/  (snake_sheet.png, chest_sheet.png).
#
# Pakai di _draw() node mana pun (titik `pos` = tempat KAKI menapak, relatif ke node):
#
#   const ES = preload("res://scripts/extra_sprites.gd")
#
#   # ular: "idle" / "strike" (menyerang)
#   ES.draw_snake(self, ES.dir_from_vector(_face), _t, "idle")
#
#   # peti: "closed" / "opening" / "full" (terbuka berisi emas) / "empty" (terbuka kosong)
#   ES.draw_chest(self, "closed")
#
# Atlas dibuat dalam resolusi ASLI (besar). Ukuran di layar diatur lewat SNAKE_SCALE dan
# CHEST_SCALE di bawah (atau argumen `scale`). Kalau hasil perkecilan terlihat bergerigi, panggil
# ES.smooth(self) sekali di _ready() dan aktifkan Mipmaps > Generate di Import dock untuk PNG-nya.
# Catatan: fungsi draw_* mengembalikan transform node ke identitas setelah menggambar.

# ------------------------------------------------------------------ atlas
const SNAKE_SHEET := "res://assets/extra/snake_sheet.png"      # 4 kolom frame x 5 baris pose, sel 128x100
const CHEST_SHEET := "res://assets/extra/chest_sheet.png"      # 4 sel keadaan, sel 120x136

# (lebar sel, tinggi sel, poros-x badan di dalam sel, y "tanah" di dalam sel)
const SNAKE_CELL := [128, 100, 64, 96]
const CHEST_CELL := [120, 136, 60, 130]

# ukuran di layar (1.0 = ukuran asli sheet). Player asli ~125px tinggi -> 0.30 ~ 37px (tile 32px).
const SNAKE_SCALE := 0.35
const CHEST_SCALE := 0.30

const SNAKE_FPS := 6.0

# Baris atlas ular: 0 melingkar menghadap depan, 1 samping (menghadap KIRI), 2 samping menyerang (KIRI),
# 3 depan menyerang, 4 samping menyerang versi 2 (KIRI). Tidak ada gambar punggung, jadi "up" memakai baris depan.
# Format: [baris, dibalik?]
const SNAKE_IDLE := {"down": [0, false], "up": [0, false], "left": [1, false], "right": [1, true]}
const SNAKE_STRIKE := {"down": [3, false], "up": [3, false], "left": [2, false], "right": [2, true]}

const CHEST_STATE := {"closed": 0, "opening": 1, "full": 2, "empty": 3}

static var _cache := {}


# ------------------------------------------------------------------ util
static func _tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


# Pasang filter halus (untuk perkecilan sheet besar). Panggil sekali, mis. di _ready().
static func smooth(ci: CanvasItem) -> void:
	ci.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


# "down" / "up" / "left" / "right" dari vektor hadap.
static func dir_from_vector(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0.0 else "left"
	return "up" if v.y < 0.0 else "down"


static func _blit(ci: CanvasItem, tx: Texture2D, cell: Array, col: int, row: int, pos: Vector2, scale: float, flip: bool, tint: Color) -> void:
	var cw: int = cell[0]
	var chh: int = cell[1]
	ci.draw_set_transform(pos, 0.0, Vector2(-scale if flip else scale, scale))
	ci.draw_texture_rect_region(tx, Rect2(-float(cell[2]), -float(cell[3]), cw, chh), Rect2(col * cw, row * chh, cw, chh), tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ snake
# state: "idle" (melingkar/melata) atau "strike" (mematuk).
static func draw_snake(ci: CanvasItem, dir: String, t: float, state: String = "idle", pos: Vector2 = Vector2(0, 10), scale: float = SNAKE_SCALE, tint: Color = Color.WHITE) -> bool:
	var tx := _tex(SNAKE_SHEET)
	if tx == null:
		return false
	var map: Dictionary = SNAKE_STRIKE if state == "strike" else SNAKE_IDLE
	var pick: Array = map.get(dir, map["down"])
	var col: int = int(t * SNAKE_FPS) % 4
	_blit(ci, tx, SNAKE_CELL, col, int(pick[0]), pos, scale, bool(pick[1]), tint)
	return true


# ------------------------------------------------------------------ chest
# state: "closed" / "opening" / "full" / "empty".
static func draw_chest(ci: CanvasItem, state: String = "closed", pos: Vector2 = Vector2(0, 12), scale: float = CHEST_SCALE, tint: Color = Color.WHITE) -> bool:
	var tx := _tex(CHEST_SHEET)
	if tx == null:
		return false
	_blit(ci, tx, CHEST_CELL, int(CHEST_STATE.get(state, 0)), 0, pos, scale, false, tint)
	return true


# Animasi buka peti berdasarkan progres 0..1: tertutup -> terangkat -> terbuka berisi.
static func chest_state_at(progress: float) -> String:
	if progress < 0.25:
		return "closed"
	if progress < 0.55:
		return "opening"
	return "full"
