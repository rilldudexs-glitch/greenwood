extends RefCounted
# Aset UI bergaya gelap-merah (ikon, bingkai, tombol) + helper pembuatnya.

const DIR := "res://assets/ui/aros/"
static var _c := {}

const SLOT_ICON := {"sword": "sword", "staff": "bolt", "chest": "helm", "legs": "diamond", "boots": "paw", "gloves": "hands", "shield": "shield", "pick": "wrench"}
const STAT_ICON := {"str": "sword", "int": "bolt", "vit": "heart", "dex": "paw", "luk": "star"}
const TAB_ICON := {"bag": "bag", "stats": "person", "craft": "anvil", "skin": "crown", "shop": "shop", "settings": "gear"}


static func tex(n: String) -> Texture2D:
    if not _c.has(n):
        _c[n] = load(DIR + n + ".png")
    return _c[n]


static func icon(n: String, px: float) -> TextureRect:
    var t := TextureRect.new()
    t.texture = tex(n)
    t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    t.custom_minimum_size = Vector2(px, px)
    t.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return t


static func box(n: String, mx: float, my: float, cx: float, cy: float, mod: Color = Color.WHITE) -> StyleBoxTexture:
    var s := StyleBoxTexture.new()
    s.texture = tex(n)
    s.texture_margin_left = mx
    s.texture_margin_right = mx
    s.texture_margin_top = my
    s.texture_margin_bottom = my
    s.content_margin_left = cx
    s.content_margin_right = cx
    s.content_margin_top = cy
    s.content_margin_bottom = cy
    s.modulate_color = mod
    return s


static func make_theme() -> Theme:
    var th := Theme.new()
    th.set_stylebox("normal", "Button", box("btn", 20, 16, 12, 5))
    th.set_stylebox("hover", "Button", box("btn", 20, 16, 12, 5, Color(1.25, 1.15, 1.15)))
    th.set_stylebox("pressed", "Button", box("btn", 20, 16, 12, 5, Color(0.7, 0.6, 0.6)))
    th.set_stylebox("disabled", "Button", box("btn", 20, 16, 12, 5, Color(0.55, 0.5, 0.5, 0.8)))
    th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
    th.set_color("font_color", "Button", Color(0.95, 0.88, 0.8))
    th.set_color("font_disabled_color", "Button", Color(0.6, 0.55, 0.55))
    th.set_constant("icon_max_width", "Button", 20)
    th.set_font_size("font_size", "Button", 14)
    return th


# Garis pemisah bergaya gelap
static func sep_style() -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.45, 0.14, 0.14, 0.8)
    s.content_margin_top = 1
    s.content_margin_bottom = 1
    return s
