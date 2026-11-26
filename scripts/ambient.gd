extends Node2D
# Hewan ambient ringan (hanya hiasan): kupu-kupu & burung di siang hari, kelelawar di malam hari.
# Digambar lewat satu node saja; dimatikan di perangkat hemat (Perf tier 2+) dan di dalam dungeon.

const BUTTER_B := [1, 8, 9, 14]
const BIRD_B := [0, 1, 9, 14]
const BAT_B := [1, 5, 6, 14]

var main
var player
var world
var atmos
var _c: Array = []          # {"k": jenis, "p": Vector2, "v": Vector2, "t": float, "col": Color, "fly": bool}
var _spawn_t := 1.0
var _draw_t := 0.0
var _t := 0.0


func setup(m, pl, w, a) -> void:
    main = m
    player = pl
    world = w
    atmos = a
    z_index = 6


func _process(delta: float) -> void:
    if player == null or not is_instance_valid(player) or world == null:
        return
    if Perf.tier >= 2 or main.dungeon != null or get_tree().paused:
        if not _c.is_empty():
            _c.clear()
            queue_redraw()
        return
    _t += delta
    var pp: Vector2 = player.global_position
    var cap: int = 6 if Perf.tier == 0 else 3
    _spawn_t -= delta
    if _spawn_t <= 0.0:
        _spawn_t = 0.8
        if _c.size() < cap:
            _try_spawn(pp)
    var i := _c.size() - 1
    while i >= 0:
        var c: Dictionary = _c[i]
        _step(c, delta, pp)
        if (c["p"] as Vector2).distance_to(pp) > 460.0 or float(c["life"]) <= 0.0:
            _c.remove_at(i)
        i -= 1
    _draw_t += delta
    if _draw_t >= (0.033 if Perf.tier == 0 else 0.06):
        _draw_t = 0.0
        queue_redraw()


func _try_spawn(pp: Vector2) -> void:
    var ang: float = randf() * TAU
    var pos: Vector2 = pp + Vector2.from_angle(ang) * randf_range(170.0, 300.0)
    var b: int = world.biome_at(pos)
    var night: bool = atmos != null and atmos.is_night()
    var k := ""
    if night:
        if BAT_B.has(b):
            k = "bat"
    else:
        var r: float = randf()
        if BUTTER_B.has(b) and r < 0.6:
            k = "butter"
        elif BIRD_B.has(b):
            k = "bird"
    if k == "":
        return
    var col := Color.from_hsv(randf(), 0.45, 1.0)
    _c.append({"k": k, "p": pos, "v": Vector2.ZERO, "t": randf() * 10.0, "col": col, "fly": k != "bird", "life": randf_range(25.0, 50.0)})


func _step(c: Dictionary, d: float, pp: Vector2) -> void:
    c["t"] = float(c["t"]) + d
    c["life"] = float(c["life"]) - d
    var p: Vector2 = c["p"]
    match String(c["k"]):
        "butter":
            var a: float = float(c["t"]) * 1.7
            var v := Vector2(cos(a * 0.7) * 22.0, sin(a * 0.9) * 18.0 - 4.0)
            c["v"] = v
            p += v * d
        "bat":
            var a2: float = float(c["t"]) * 1.2
            var v2 := Vector2(cos(a2) * 55.0, sin(a2 * 1.6) * 30.0)
            c["v"] = v2
            p += v2 * d
        "bird":
            if not bool(c["fly"]):
                if p.distance_to(pp) < 80.0:          # kaget: terbang menjauh
                    c["fly"] = true
                    var away: Vector2 = (p - pp).normalized()
                    c["v"] = (away + Vector2(0, -0.6)).normalized() * 120.0
                    c["life"] = minf(float(c["life"]), 3.5)
            else:
                p += (c["v"] as Vector2) * d
                c["v"] = (c["v"] as Vector2) + Vector2(0, -20.0) * d
    c["p"] = p


func _draw() -> void:
    for c in _c:
        var p: Vector2 = c["p"]
        var t: float = float(c["t"])
        var col: Color = c["col"]
        match String(c["k"]):
            "butter":
                var f: float = absf(sin(t * 14.0))
                draw_circle(p + Vector2(0, 1), 3.2 + 3.0 * 0.0, Color(0, 0, 0, 0.12))   # bayangan kecil
                draw_colored_polygon(PackedVector2Array([p, p + Vector2(-5.0 * f - 1.0, -3.5), p + Vector2(-4.0 * f, 2.0)]), col)
                draw_colored_polygon(PackedVector2Array([p, p + Vector2(5.0 * f + 1.0, -3.5), p + Vector2(4.0 * f, 2.0)]), col)
                draw_rect(Rect2(p.x - 0.6, p.y - 2.0, 1.2, 4.0), Color(0.2, 0.15, 0.15))
            "bat":
                var f2: float = sin(t * 16.0)
                var bc := Color(0.12, 0.1, 0.16)
                draw_line(p, p + Vector2(-7, -3.0 * f2 - 2.0), bc, 2.0)
                draw_line(p, p + Vector2(7, -3.0 * f2 - 2.0), bc, 2.0)
                draw_circle(p, 2.2, bc)
            "bird":
                var bc2 := Color(0.45 + col.r * 0.2, 0.38, 0.3)
                if bool(c["fly"]):
                    var f3: float = sin(t * 18.0)
                    draw_line(p, p + Vector2(-7, -4.0 * f3), bc2, 2.0)
                    draw_line(p, p + Vector2(7, -4.0 * f3), bc2, 2.0)
                    draw_circle(p, 2.4, bc2)
                else:
                    draw_circle(p + Vector2(0, 2), 4.0, Color(0, 0, 0, 0.14))
                    draw_circle(p, 3.6, bc2)
                    draw_circle(p + Vector2(3, -2.5), 2.2, bc2)
                    draw_rect(Rect2(p.x + 4.5, p.y - 2.8, 2.2, 1.2), Color(1.0, 0.75, 0.2))
