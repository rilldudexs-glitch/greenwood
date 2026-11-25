extends Node2D
# Bola sihir pemain atau bola musuh (hostile = true).

const Art = preload("res://scripts/art.gd")

var direction := Vector2.RIGHT
var speed := 220.0
var life := 1.0
var hostile := false
var damage := 10
var color := Color(0.3, 0.8, 1.0)
var pierce := 0
var homing := false
var explode := 0.0
var scale_f := 1.0
var crit := false
var arrow := false      # true = digambar sebagai panah (busur), bukan bola sihir

var _hit: Array = []
var _t := 0.0
var _trail: Array = []


func _physics_process(delta: float) -> void:
    _t += delta
    if homing and not hostile:
        var best = null
        var bd := 150.0
        for e in get_tree().get_nodes_in_group("enemies"):
            var d: float = e.global_position.distance_to(global_position)
            if d < bd:
                bd = d
                best = e
        if best:
            var want: Vector2 = (best.global_position - global_position).normalized()
            direction = direction.lerp(want, minf(6.0 * delta, 1.0)).normalized()
    position += direction * speed * delta
    _trail.append(global_position)
    if _trail.size() > 7:
        _trail.pop_front()
    life -= delta
    if life <= 0.0:
        _finish()
        return
    var world = get_tree().get_first_node_in_group("world")
    if world and world.is_solid_at(global_position):
        _finish()
        return
    if hostile:
        var pls: Array = get_tree().get_nodes_in_group("player")
        pls.append_array(get_tree().get_nodes_in_group("peers"))     # co-op: pemain lain (remote_player.gd)
        for pl in pls:
            if not pl.dead and pl.global_position.distance_to(global_position) < 11.0:
                pl.take_damage(damage, direction, "proj")
                queue_free()
                return
    else:
        for e in get_tree().get_nodes_in_group("enemies"):
            if _hit.has(e):
                continue
            if e.global_position.distance_to(global_position) < 8.0 + e.radius:
                _hit.append(e)
                e.take_damage(damage, direction, crit)
                if pierce > 0:
                    pierce -= 1
                else:
                    _finish()
                    return
    queue_redraw()


func _finish() -> void:
    if not hostile:
        var main = get_tree().current_scene
        if explode > 0.0:
            main.fx_burst(global_position, color, 18, 110.0, 0.5, 0.0, 3.0, "flame")
            main.fx_ring(global_position, explode, color, 0.35)
            for e in get_tree().get_nodes_in_group("enemies"):
                if not _hit.has(e) and e.global_position.distance_to(global_position) < explode + e.radius:
                    e.take_damage(maxi(damage / 2, 1), direction)
        else:
            main.fx_burst(global_position, color, 8, 60.0, 0.3, 0.0, 2.0, "star")
    queue_free()


func _draw() -> void:
    if arrow:
        var d0: Vector2 = direction.normalized()
        var o0: Vector2 = d0.orthogonal()
        var k: float = scale_f
        draw_line(-d0 * 10.0 * k, d0 * 4.0 * k, Color(0.85, 0.7, 0.45), 1.6)
        draw_colored_polygon(PackedVector2Array([d0 * 8.0 * k, d0 * 3.0 * k + o0 * 2.4 * k, d0 * 3.0 * k - o0 * 2.4 * k]), color.lightened(0.45))
        draw_line(-d0 * 10.0 * k, -d0 * 12.5 * k + o0 * 2.2 * k, color, 1.3)
        draw_line(-d0 * 10.0 * k, -d0 * 12.5 * k - o0 * 2.2 * k, color, 1.3)
        draw_circle(-d0 * 4.0 * k, 3.5 * k, Color(color.r, color.g, color.b, 0.18))
        return
    # ekor
    for i in _trail.size():
        var p: Vector2 = to_local(_trail[i])
        var u: float = float(i) / maxf(_trail.size(), 1.0)
        draw_circle(p, (2.0 + 3.0 * u) * scale_f, Color(color.r, color.g, color.b, 0.12 + 0.3 * u))
    var s: float = scale_f * (1.0 + 0.1 * sin(_t * 20.0))
    draw_circle(Vector2.ZERO, 7.0 * s, Color(color.r, color.g, color.b, 0.35))
    draw_circle(Vector2.ZERO, 4.5 * s, color)
    draw_circle(Vector2.ZERO, 2.2 * s, Color(1, 1, 1, 0.95))
