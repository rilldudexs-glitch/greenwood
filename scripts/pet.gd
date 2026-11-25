extends Node2D
# Pendamping hewan (Penjinak = serigala, Pemanggil Rimba = rusa roh). Mengikuti pemain, menerkam musuh terdekat.

var player
var style := "wolf"
var _t := randf() * 10.0
var _cd := 1.0
var _rage := 0.0
var _lunge := 0.0
var _lunge_from := Vector2.ZERO
var _lunge_to := Vector2.ZERO
var _target = null
var _scan := 0.0
var _face := 1.0


func setup(p, st: String) -> void:
    player = p
    style = st
    z_index = 1
    global_position = p.global_position + Vector2(-24, 10)


func rage(secs: float) -> void:
    _rage = maxf(_rage, secs)


func _process(delta: float) -> void:
    if player == null or not is_instance_valid(player):
        queue_free()
        return
    _t += delta
    _cd -= delta
    _rage = maxf(_rage - delta, 0.0)
    if _lunge > 0.0:
        _lunge = maxf(_lunge - delta, 0.0)
        var u: float = 1.0 - _lunge / 0.25
        global_position = _lunge_from.lerp(_lunge_to, u)
        if _lunge <= 0.0:
            _strike()
        queue_redraw()
        return
    _scan -= delta
    if _scan <= 0.0:
        _scan = 0.35
        _target = _find_target()
    if _target != null and is_instance_valid(_target) and _cd <= 0.0 and not player.dead:
        _lunge = 0.25
        _lunge_from = global_position
        _lunge_to = _target.global_position
        _face = 1.0 if _lunge_to.x >= global_position.x else -1.0
        return
    # ikuti pemain dengan jarak nyaman
    var home: Vector2 = player.global_position + Vector2(-26.0 * (1.0 if player._face.x >= 0.0 else -1.0), 12.0)
    var to: Vector2 = home - global_position
    var d: float = to.length()
    if d > 320.0:
        global_position = home
    elif d > 6.0:
        global_position += to.normalized() * minf(d * 6.0, 170.0) * delta
        if absf(to.x) > 2.0:
            _face = 1.0 if to.x > 0.0 else -1.0
    queue_redraw()


func _find_target():
    var best = null
    var bd := 170.0
    for e in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(e) or e.process_mode == Node.PROCESS_MODE_DISABLED:
            continue
        var d: float = e.global_position.distance_to(player.global_position)
        if d < bd:
            bd = d
            best = e
    return best


func _strike() -> void:
    _cd = 0.6 if _rage > 0.0 else 1.3
    if _target == null or not is_instance_valid(_target):
        return
    var main = get_tree().current_scene
    var base: int = maxi(player.melee_damage(), player.magic_damage())
    var dmg: int = int(float(base) * (0.7 if style == "stag" else 0.6))
    var crit: bool = randf() < player.crit_chance()
    if crit:
        dmg = int(dmg * 1.75)
    _target.take_damage(dmg, _target.global_position - global_position, crit)
    var col := Color(0.8, 0.85, 0.9) if style == "wolf" else Color(0.5, 1.0, 0.65)
    main.fx_burst(_target.global_position, col, 6, 60.0, 0.35, 0.0, 2.0, "star")
    Audio.sfx("hit", 1.2)


func _draw() -> void:
    var s: float = _face
    var bob: float = sin(_t * 8.0) * 1.2 if _lunge <= 0.0 else -3.0
    draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
    draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.3))
    draw_set_transform(Vector2(0, bob), 0.0, Vector2(s, 1.0))
    if style == "wolf":
        var fur := Color(0.62, 0.64, 0.7)
        var dark := Color(0.35, 0.37, 0.45)
        if _rage > 0.0:
            fur = fur.lerp(Color(1.0, 0.7, 0.5), 0.5)
        # ekor
        draw_colored_polygon(PackedVector2Array([Vector2(-9, -3), Vector2(-17, -9 + sin(_t * 9.0) * 2.0), Vector2(-9, 1)]), dark)
        # badan
        draw_colored_polygon(PackedVector2Array([Vector2(-10, -4), Vector2(-6, -9), Vector2(6, -9), Vector2(10, -4), Vector2(8, 2), Vector2(-8, 2)]), fur)
        # kaki
        for lx in [-7.0, -2.0, 3.0, 7.0]:
            draw_rect(Rect2(lx - 1.0, 1.0, 2.5, 4.0), dark)
        # kepala + telinga + moncong
        draw_circle(Vector2(11, -8), 5.0, fur)
        draw_colored_polygon(PackedVector2Array([Vector2(8, -11), Vector2(9, -17), Vector2(12, -12)]), dark)
        draw_colored_polygon(PackedVector2Array([Vector2(12, -12), Vector2(15, -17), Vector2(15, -10)]), dark)
        draw_rect(Rect2(14, -8, 4, 3), dark)
        draw_circle(Vector2(12.5, -9), 0.9, Color.BLACK)
    else:
        var body := Color(0.55, 0.95, 0.65, 0.9)
        var glow := Color(0.5, 1.0, 0.7, 0.25 + 0.1 * sin(_t * 4.0))
        if _rage > 0.0:
            glow.a = 0.5
        draw_circle(Vector2(0, -6), 15.0, glow)
        draw_colored_polygon(PackedVector2Array([Vector2(-10, -4), Vector2(-6, -11), Vector2(6, -11), Vector2(10, -5), Vector2(8, 2), Vector2(-8, 2)]), body)
        for lx in [-7.0, -2.0, 3.0, 7.0]:
            draw_rect(Rect2(lx - 1.0, 1.0, 2.0, 5.0), body.darkened(0.3))
        draw_colored_polygon(PackedVector2Array([Vector2(6, -10), Vector2(9, -18), Vector2(14, -16), Vector2(15, -9), Vector2(11, -7)]), body)
        # tanduk
        draw_polyline(PackedVector2Array([Vector2(10, -17), Vector2(9, -23), Vector2(6, -26)]), Color(0.85, 1.0, 0.7), 1.5)
        draw_polyline(PackedVector2Array([Vector2(12, -17), Vector2(14, -23), Vector2(17, -25)]), Color(0.85, 1.0, 0.7), 1.5)
        draw_circle(Vector2(11, -12), 0.9, Color(0.1, 0.2, 0.1))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
