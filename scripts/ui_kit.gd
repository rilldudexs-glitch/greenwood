extends RefCounted
# Bantuan tampilan bergaya "Greenwood": panel gelap berbingkai merah tua berduri.
# Semua gambar ada di assets/ui/kit/. Kalau file hilang, fungsi mengembalikan null / gaya polos.

const Art = preload("res://scripts/art.gd")
const DIR := "res://assets/ui/kit/"

const CRIMSON := Color(0.55, 0.12, 0.2)
const CRIMSON_HI := Color(0.95, 0.25, 0.32)
const INK := Color(0.07, 0.06, 0.11)


static func tex(n: String) -> Texture2D:
    return Art.tex(DIR + n + ".png")


# 9-slice dari gambar kit. l/t/r/b = margin (piksel tekstur). Null kalau gambar tidak ada.
static func nine(n: String, l: int, t: int, r: int, b: int) -> StyleBoxTexture:
    var tx: Texture2D = tex(n)
    if tx == null:
        return null
    var sb := StyleBoxTexture.new()
    sb.texture = tx
    sb.texture_margin_left = l
    sb.texture_margin_top = t
    sb.texture_margin_right = r
    sb.texture_margin_bottom = b
    sb.draw_center = true
    return sb


static func flat(bg: Color, border: Color, bw: int = 2) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(bw)
    sb.set_corner_radius_all(3)
    sb.content_margin_left = 10
    sb.content_margin_right = 10
    sb.content_margin_top = 5
    sb.content_margin_bottom = 5
    return sb


# Tema untuk tombol / kolom isian / dll. Dipasang di Control paling atas sebuah layar.
static func make_theme() -> Theme:
    var th := Theme.new()
    th.set_stylebox("normal", "Button", flat(Color(0.09, 0.08, 0.14), CRIMSON))
    th.set_stylebox("hover", "Button", flat(Color(0.3, 0.07, 0.12), CRIMSON_HI))
    th.set_stylebox("pressed", "Button", flat(Color(0.45, 0.08, 0.15), Color(1, 0.5, 0.5)))
    th.set_stylebox("disabled", "Button", flat(Color(0.22, 0.05, 0.1), Color(0.9, 0.3, 0.35)))
    th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    th.set_color("font_color", "Button", Color(1, 1, 1))
    th.set_color("font_hover_color", "Button", Color(1, 1, 1))
    th.set_color("font_pressed_color", "Button", Color(1, 1, 1))
    th.set_color("font_disabled_color", "Button", Color(1, 0.88, 0.88))
    th.set_stylebox("normal", "LineEdit", flat(Color(0.05, 0.04, 0.09), CRIMSON))
    th.set_stylebox("focus", "LineEdit", flat(Color(0.05, 0.04, 0.09), CRIMSON_HI))
    th.set_color("font_color", "LineEdit", Color(1, 1, 1))
    th.set_color("font_placeholder_color", "LineEdit", Color(1, 1, 1, 0.4))
    return th
