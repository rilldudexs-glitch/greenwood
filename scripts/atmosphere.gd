extends Node
# Siang-malam + cuaca untuk dunia terbuka.
#  - Jam dunia: 1 hari = DAY detik (12 menit nyata), disimpan di Game.p["clock"].
#  - Warna layar mengikuti jam (CanvasModulate), malam gelap dengan cahaya obor di sekitar pemain.
#  - Cuaca mengikuti biome: hujan (hutan/desa), badai pasir (gurun), salju (puncak salju), bara (gunung api).
# Dimatikan otomatis saat pemain di dalam dungeon (dungeon punya pencahayaan sendiri).

const DAY := 720.0

# jam (0-24) -> warna layar
const KEYS := [
    [0.0, Color(0.30, 0.34, 0.56)],
    [5.0, Color(0.32, 0.36, 0.58)],
    [6.5, Color(0.95, 0.74, 0.64)],
    [8.0, Color(1.0, 1.0, 1.0)],
    [17.0, Color(1.0, 0.97, 0.90)],
    [18.5, Color(1.0, 0.68, 0.50)],
    [20.0, Color(0.46, 0.46, 0.70)],
    [21.5, Color(0.30, 0.34, 0.56)],
    [24.0, Color(0.30, 0.34, 0.56)],
]
const RAIN_B := [0, 1, 7, 8, 9, 10, 13, 14]
const SAND_B := [2, 6, 12]
const SNOW_B := [3, 11]
const EMBER_B := [4, 5]
const FIREFLY_B := [1, 8, 14]      # malam: kunang-kunang
const AURORA_B := [3, 11]          # malam: aurora
const BUBBLE_B := [7, 13]          # gelembung air

var main
var player
var world
var wtype := ""
var inten := 0.0
var _target := 0.0
var _chk := 0.0
var _wt := randf() * 5000.0          # penghitung waktu cuaca (acak tiap sesi)
var _mod: CanvasModulate
var _layer: CanvasLayer
var _fx
var _light: PointLight2D
var _amb
var blood_k := 0.0                   # 0..1, Bulan Darah (diatur world_events.gd): langit memerah


class Particles extends Control:
    const N := 120
    var type := ""
    var inten := 0.0
    var _pos := PackedVector2Array()
    var _s := PackedFloat32Array()
    var _t := 0.0
    var _was := false

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        set_anchors_preset(Control.PRESET_FULL_RECT)
        var sz := Vector2(1280, 720)
        for i in N:
            _pos.append(Vector2(randf() * sz.x, randf() * sz.y))
            _s.append(randf_range(0.6, 1.4))

    func _process(d: float) -> void:
        var active: bool = inten > 0.01 and type != ""
        if not active and not _was:
            return
        _was = active
        _t += d
        var sz: Vector2 = get_viewport_rect().size
        for i in N:
            var s: float = _s[i]
            var p: Vector2 = _pos[i]
            match type:
                "rain":
                    p += Vector2(-90.0, 640.0) * s * d
                "snow":
                    p += Vector2(sin(_t * 0.8 + float(i)) * 26.0, 55.0 * s) * d
                "sand":
                    p += Vector2(620.0 * s, 35.0 * s) * d
                "ember":
                    p += Vector2(sin(_t + float(i)) * 20.0, -70.0 * s) * d
            if p.x > sz.x + 20.0:
                p.x = -20.0
                p.y = randf() * sz.y
            elif p.x < -20.0:
                p.x = sz.x + 20.0
            if p.y > sz.y + 20.0:
                p.y = -20.0
                p.x = randf() * sz.x
            elif p.y < -20.0:
                p.y = sz.y + 20.0
                p.x = randf() * sz.x
            _pos[i] = p
        queue_redraw()

    func _draw() -> void:
        if inten <= 0.01 or type == "":
            return
        var sz: Vector2 = get_viewport_rect().size
        var k: float = clampf(inten, 0.0, 1.0)
        var cnt: int = int(float(N) * k * clampf(Perf.fx_scale, 0.4, 1.0))
        match type:
            "rain":
                draw_rect(Rect2(Vector2.ZERO, sz), Color(0.35, 0.4, 0.5, 0.10 * k))
            "sand":
                draw_rect(Rect2(Vector2.ZERO, sz), Color(0.85, 0.68, 0.40, 0.20 * k))
        for i in cnt:
            var p: Vector2 = _pos[i]
            var s: float = _s[i]
            match type:
                "rain":
                    draw_line(p, p + Vector2(-5.0, 17.0) * s, Color(0.75, 0.85, 1.0, 0.5), 1.2)
                "snow":
                    draw_circle(p, 1.4 + s, Color(1, 1, 1, 0.85))
                "sand":
                    draw_line(p, p + Vector2(-16.0 * s, -1.0), Color(0.88, 0.72, 0.45, 0.5), 1.5)
                "ember":
                    draw_circle(p, 1.2 + s * 0.8, Color(1.0, 0.5, 0.15, 0.75))


# Suasana khas biome (di atas cuaca): kunang-kunang & aurora saat malam, kelopak, spora, kristal berkilau,
# gelembung, fatamorgana siang, dan petir saat hujan deras. Ringan: maks ~40 titik, ikut Perf.fx_scale.
class Ambience extends Control:
    const N := 40
    var mode := ""
    var k := 0.0                      # 0..1, muncul / hilang halus
    var rain := 0.0                   # intensitas hujan (memicu petir)
    var _pos := PackedVector2Array()
    var _s := PackedFloat32Array()
    var _t := 0.0
    var _acc := 0.0
    var _was := false
    var _flash := 0.0
    var _bolt_x := 0.5
    var _next_bolt := 8.0
    var _thunder := -1.0

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        set_anchors_preset(Control.PRESET_FULL_RECT)
        var sz := Vector2(1280, 720)
        for i in N:
            _pos.append(Vector2(randf() * sz.x, randf() * sz.y))
            _s.append(randf_range(0.6, 1.4))

    func _process(d: float) -> void:
        k = move_toward(k, 1.0 if mode != "" else 0.0, d * 0.6)
        var active: bool = k > 0.0 or rain > 0.6 or _flash > 0.0 or _thunder > 0.0
        if not active and not _was:
            return
        _was = active
        _t += d
        if rain > 0.6:
            _next_bolt -= d
            if _next_bolt <= 0.0:
                _next_bolt = randf_range(7.0, 20.0)
                _flash = 1.0
                _bolt_x = randf_range(0.15, 0.85)
                _thunder = randf_range(0.4, 1.6)
        if _flash > 0.0:
            _flash = maxf(_flash - d * 2.5, 0.0)
        if _thunder > 0.0:
            _thunder -= d
            if _thunder <= 0.0:
                Audio.sfx("hit", 0.4)
        var sz: Vector2 = get_viewport_rect().size
        for i in N:
            var s: float = _s[i]
            var p: Vector2 = _pos[i]
            match mode:
                "firefly":
                    p += Vector2(4.0, -3.0) * s * d
                "spore":
                    p += Vector2(sin(_t + float(i)) * 10.0, -22.0 * s) * d
                "petal":
                    p += Vector2(38.0 + 30.0 * s, 34.0 * s) * d
                "bubble":
                    p += Vector2(sin(_t * 1.2 + float(i)) * 8.0, -30.0 * s) * d
                _:
                    continue
            if p.x > sz.x + 20.0:
                p.x = -20.0
                p.y = randf() * sz.y
            elif p.x < -20.0:
                p.x = sz.x + 20.0
            if p.y > sz.y + 20.0:
                p.y = -20.0
                p.x = randf() * sz.x
            elif p.y < -20.0:
                p.y = sz.y + 20.0
                p.x = randf() * sz.x
            _pos[i] = p
        _acc += d
        if _acc >= 1.0 / minf(Perf.hud_hz, 30.0):
            _acc = 0.0
            queue_redraw()

    func _draw() -> void:
        var sz: Vector2 = get_viewport_rect().size
        var a: float = k
        if a > 0.01:
            var cnt: int = int(float(N) * clampf(Perf.fx_scale, 0.4, 1.0))
            match mode:
                "firefly":
                    for i in mini(cnt, 24):
                        var p: Vector2 = _pos[i] + Vector2(sin(_t * 0.6 + float(i) * 1.7) * 18.0, cos(_t * 0.5 + float(i) * 2.3) * 14.0)
                        var bl: float = maxf(sin(_t * 1.3 + float(i) * 2.1), 0.0)
                        draw_circle(p, 5.0, Color(0.85, 1.0, 0.35, 0.12 * bl * a))
                        draw_circle(p, 1.6, Color(1.0, 1.0, 0.65, 0.95 * bl * a))
                "spore":
                    for i in mini(cnt, 30):
                        var col := Color(0.95, 0.4, 0.95) if i % 2 == 0 else Color(0.4, 0.95, 1.0)
                        draw_circle(_pos[i], 4.0 + _s[i] * 2.0, Color(col.r, col.g, col.b, 0.10 * a))
                        draw_circle(_pos[i], 1.4 + _s[i], Color(col.r, col.g, col.b, 0.8 * a))
                "petal":
                    for i in mini(cnt, 36):
                        var dv: Vector2 = Vector2.from_angle(_t * 1.5 + float(i)) * (3.0 + _s[i] * 1.5)
                        var pp: Vector2 = _pos[i]
                        draw_colored_polygon(PackedVector2Array([pp + dv, pp + dv.orthogonal() * 0.5, pp - dv, pp - dv.orthogonal() * 0.5]), Color(1.0, 0.72, 0.82, 0.8 * a))
                "sparkle":
                    for i in mini(cnt, 28):
                        var tw: float = maxf(sin(_t * 1.6 + float(i) * 1.9), 0.0)
                        tw *= tw
                        var ln: float = 3.0 + 5.0 * _s[i] * tw
                        var sp: Vector2 = _pos[i]
                        var sc := Color(0.75, 0.85, 1.0, 0.9 * tw * a)
                        draw_line(sp - Vector2(ln, 0.0), sp + Vector2(ln, 0.0), sc, 1.2)
                        draw_line(sp - Vector2(0.0, ln), sp + Vector2(0.0, ln), sc, 1.2)
                "bubble":
                    for i in mini(cnt, 22):
                        draw_arc(_pos[i], 2.0 + 3.0 * _s[i], 0.0, TAU, 10, Color(0.6, 0.95, 1.0, 0.55 * a), 1.0)
                "mirage":
                    for j in 5:
                        var pts := PackedVector2Array()
                        var by: float = sz.y * (0.28 + 0.13 * float(j)) + sin(_t * 0.7 + float(j)) * 6.0
                        for q in 13:
                            var x: float = sz.x * float(q) / 12.0
                            pts.append(Vector2(x, by + sin(x * 0.02 + _t * 1.5 + float(j)) * 5.0))
                        draw_polyline(pts, Color(1.0, 0.95, 0.8, 0.05 * a), 12.0)
                "aurora":
                    var cols := [Color(0.3, 1.0, 0.6), Color(0.3, 0.8, 1.0), Color(0.7, 0.4, 1.0)]
                    for j in 3:
                        var pts := PackedVector2Array()
                        var base: float = sz.y * (0.10 + 0.08 * float(j))
                        for q in 17:
                            var x: float = sz.x * float(q) / 16.0
                            pts.append(Vector2(x, base + sin(x * 0.006 + _t * 0.4 + float(j) * 1.7) * sz.y * 0.06 + sin(x * 0.013 - _t * 0.25) * 10.0))
                        var c: Color = cols[j]
                        var al: float = (0.10 + 0.05 * sin(_t * 0.5 + float(j))) * a
                        draw_polyline(pts, Color(c.r, c.g, c.b, al), 46.0)
                        draw_polyline(pts, Color(c.r, c.g, c.b, al * 1.3), 14.0)
        if _flash > 0.0:
            draw_rect(Rect2(Vector2.ZERO, sz), Color(0.85, 0.9, 1.0, 0.45 * _flash))
            var bp := PackedVector2Array()
            var rr := RandomNumberGenerator.new()
            rr.seed = int(_bolt_x * 100000.0)
            var bx: float = sz.x * _bolt_x
            var by2 := 0.0
            while by2 < sz.y * 0.55:
                bp.append(Vector2(bx, by2))
                bx += rr.randf_range(-22.0, 22.0)
                by2 += rr.randf_range(24.0, 46.0)
            draw_polyline(bp, Color(1, 1, 1, _flash), 2.5)


func setup(m, pl, w) -> void:
    main = m
    player = pl
    world = w
    _mod = CanvasModulate.new()
    add_child(_mod)
    _layer = CanvasLayer.new()
    _layer.layer = 5                      # di atas dunia, di bawah HUD (layer 10)
    add_child(_layer)
    _fx = Particles.new()
    _layer.add_child(_fx)
    _amb = Ambience.new()
    _layer.add_child(_amb)
    _light = PointLight2D.new()
    var g := Gradient.new()
    g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
    g.offsets = PackedFloat32Array([0.0, 1.0])
    var tex := GradientTexture2D.new()
    tex.gradient = g
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    tex.width = 256
    tex.height = 256
    _light.texture = tex
    _light.texture_scale = 2.4
    _light.color = Color(1.0, 0.88, 0.65)
    _light.energy = 0.0
    _light.position = Vector2(0, -6)
    player.add_child(_light)


# ------------------------------------------------------------------ jam
func hour() -> float:
    return fposmod(float(Game.p.get("clock", 240.0)) / DAY, 1.0) * 24.0


func clock_text() -> String:
    if main != null and main.dungeon != null:
        return ""
    var h: float = hour()
    var pn := "Malam"
    if h >= 5.0 and h < 11.0:
        pn = "Pagi"
    elif h >= 11.0 and h < 15.0:
        pn = "Siang"
    elif h >= 15.0 and h < 18.5:
        pn = "Sore"
    var s: String = "%s %02d:%02d" % [pn, int(h), int((h - floorf(h)) * 60.0)]
    var wn: String = {"rain": "Hujan", "sand": "Badai Pasir", "snow": "Salju", "ember": "Abu Panas"}.get(wtype, "")
    if blood_k > 0.5:
        s += "  Bulan Darah"
    elif wn != "" and inten > 0.3:
        s += "  " + wn
    return s


func is_night() -> bool:
    var h: float = hour()
    return h >= 20.0 or h < 5.5


func _day_color() -> Color:
    var h: float = hour()
    for i in range(KEYS.size() - 1):
        var a: Array = KEYS[i]
        var b: Array = KEYS[i + 1]
        if h >= float(a[0]) and h <= float(b[0]):
            var t: float = (h - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
            return (a[1] as Color).lerp(b[1] as Color, t)
    return Color.WHITE


# ------------------------------------------------------------------ cuaca
func _type_for(b: int) -> String:
    if RAIN_B.has(b):
        return "rain"
    if SAND_B.has(b):
        return "sand"
    if SNOW_B.has(b):
        return "snow"
    if EMBER_B.has(b):
        return "ember"
    return ""


func _amb_for(b: int) -> String:
    var night: bool = is_night()
    if night and FIREFLY_B.has(b):
        return "firefly"
    if night and AURORA_B.has(b):
        return "aurora"
    if b == 9:
        return "petal"
    if b == 10:
        return "spore"
    if b == 15:
        return "sparkle"
    if BUBBLE_B.has(b):
        return "bubble"
    var h: float = hour()
    if b == 2 and h >= 10.5 and h < 16.5 and not (wtype == "sand" and inten > 0.3):
        return "mirage"
    return ""


func _target_for(t: String) -> float:
    if t == "":
        return 0.0
    var r := RandomNumberGenerator.new()
    r.seed = int(_wt / 100.0) * 7919 + t.hash() % 1000
    var roll: float = r.randf()
    var level: float = 0.55 + 0.45 * r.randf()
    match t:
        "rain":
            return level if roll < 0.30 else 0.0
        "sand":
            return level if roll < 0.35 else 0.0
        "snow", "ember":
            return level
    return 0.0


func _process(delta: float) -> void:
    if main == null or player == null or not is_instance_valid(player):
        return
    var in_dg: bool = main.dungeon != null
    _mod.visible = not in_dg
    _layer.visible = not in_dg
    if in_dg:
        _light.energy = 0.0
        return
    var rain_now: float = inten if wtype == "rain" else 0.0
    _amb.rain = rain_now
    Game.p["clock"] = fposmod(float(Game.p.get("clock", 240.0)) + delta, DAY)
    _wt += delta
    _chk -= delta
    if _chk <= 0.0:
        _chk = 0.5
        var t: String = _type_for(world.biome_at(player.global_position))
        if t != wtype:
            wtype = t
            inten = 0.0
            _fx.type = t
        _target = _target_for(t)
        var am: String = _amb_for(world.biome_at(player.global_position))
        if am != _amb.mode:
            _amb.mode = am
            if am != "":
                _amb.k = 0.0
    inten = move_toward(inten, _target, delta * 0.25)
    _fx.inten = inten
    var c: Color = _day_color()
    var k: float = clampf(inten, 0.0, 1.0)
    if wtype == "rain":
        c = c.lerp(c * Color(0.72, 0.78, 0.90), k)
    elif wtype == "sand":
        c = c.lerp(c * Color(1.0, 0.85, 0.65), k)
    if blood_k > 0.0:
        c = c.lerp(c * Color(1.0, 0.40, 0.42), blood_k)       # Bulan Darah: layar memerah
    _mod.color = c
    var dark: float = clampf((0.95 - c.get_luminance()) * 2.0, 0.0, 0.9)
    _light.energy = dark
