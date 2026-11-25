extends Node2D
# Efek ringan buatan kode: partikel, teks damage melayang, petir, cincin peringatan.
# Dibuat lewat Main.fx_*(); isi properti SEBELUM add_child.

var kind := "burst"      # burst | text | bolt | ring | tele | slash
var col := Color.WHITE
var life := 0.6
var count := 10
var speed := 40.0
var grav := 0.0
var size := 2.0
var shape := "dot"       # dot | star | flame | snow | leaf
var text := ""
var radius := 20.0
var pts := PackedVector2Array()
var ang := 0.0

var _t := 0.0
var _rd := 1.0
var _p: Array = []
var _font: Font = load("res://assets/fonts/DejaVuSans.ttf")


func _ready() -> void:
    z_index = 20
    if kind == "burst":
        for i in count:
            var a: float = randf() * TAU
            var s: float = randf_range(0.3, 1.0) * speed
            _p.append([Vector2.ZERO, Vector2.from_angle(a) * s, randf_range(0.6, 1.2)])


func _process(delta: float) -> void:
    _t += delta
    if _t >= life:
        queue_free()
        return
    if kind == "burst":
        for q in _p:
            q[1] = Vector2(q[1].x, q[1].y + grav * delta)
            q[0] = q[0] + q[1] * delta
    elif kind == "text":
        position.y -= 22.0 * delta
    # partikel & teks tidak perlu 60 FPS; efek peringatan/tebasan tetap mulus
    if kind == "burst" or kind == "text":
        _rd += delta
        if _rd < (0.033 if Perf.tier == 0 else 0.05):
            return
        _rd = 0.0
    queue_redraw()


func _draw() -> void:
    var u: float = clampf(_t / life, 0.0, 1.0)
    match kind:
        "burst":
            for q in _p:
                var sz: float = size * float(q[2]) * (1.0 - 0.6 * u)
                var c := Color(col.r, col.g, col.b, 1.0 - u)
                if shape == "flame":
                    c = Color(1.0, 0.85 - 0.6 * u, 0.2, 1.0 - u)
                var pp: Vector2 = q[0]
                if shape == "star":
                    draw_line(pp - Vector2(sz * 1.6, 0), pp + Vector2(sz * 1.6, 0), c, 1.0)
                    draw_line(pp - Vector2(0, sz * 1.6), pp + Vector2(0, sz * 1.6), c, 1.0)
                elif shape == "snow" or shape == "leaf":
                    draw_rect(Rect2(pp.x - sz / 2.0, pp.y - sz / 2.0, sz, sz), c)
                else:
                    draw_circle(pp, sz, c)
        "text":
            var pop: float = 1.0 + maxf(0.0, 0.25 - _t) * 3.0
            draw_set_transform(Vector2.ZERO, 0.0, Vector2(pop, pop))
            var fs: int = int(size)
            draw_string_outline(_font, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, 5, Color(0, 0, 0, 1.0 - u * u))
            draw_string(_font, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, fs, Color(col.r, col.g, col.b, 1.0 - u * u))
        "bolt":
            if pts.size() >= 2:
                draw_polyline(pts, Color(col.r, col.g, col.b, 0.3 * (1.0 - u)), 6.0)
                draw_polyline(pts, Color(1, 1, 1, 1.0 - u), 1.5)
        "slash":
            var w: float = 1.0 - u
            draw_arc(Vector2.ZERO, radius, ang - 1.0, ang + 1.0, 14, Color(col.r, col.g, col.b, 0.85 * w), 7.0 * w + 1.0)
            draw_arc(Vector2.ZERO, radius - 3.0, ang - 0.9, ang + 0.9, 14, Color(1, 1, 1, 0.8 * w), 2.0)
        "ring":
            var r: float = radius * (0.3 + 0.7 * u)
            draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(col.r, col.g, col.b, 0.8 * (1.0 - u)), 2.5)
        "tele":
            var a: float = 0.18 + 0.12 * sin(_t * 18.0)
            draw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, a))
            draw_arc(Vector2.ZERO, radius * u, 0.0, TAU, 36, Color(col.r, col.g, col.b, 0.8), 2.0)
            draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(col.r, col.g, col.b, 0.9), 2.0)
