extends RefCounted
# DIBUAT OTOMATIS oleh tools/gen_hero_sprites.py - jangan edit manual.
# Atlas pahlawan 4 arah: baris atlas = indeks_animasi * 4 + indeks_arah, kolom = frame.

const FILE := "res://assets/characters/hero_sheet.png"
const CELL := 64
const FOOT_Y := 56
const AXIS_X := 32
const DIRS := {"down": 0, "left": 1, "right": 2, "up": 3}
# nama animasi -> [indeks_animasi, jumlah_frame]
const ANIMS := {
	"idle": [0, 5],
	"walk": [1, 5],
	"run": [2, 5],
	"attack1": [3, 5],
	"attack2": [4, 5],
	"attack3": [5, 5],
	"hurt": [6, 5],
	"death": [7, 6],
}
