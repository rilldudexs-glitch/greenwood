extends Node2D
# Meteor jatuh (event dunia): melesat dari langit, meninggalkan kawah berpendar berisi pecahan langka.
# Dekati untuk mengambilnya. Hilang sendiri setelah LIFE detik. Dibuat oleh world_events.gd.

const Art = preload("res://scripts/art.gd")

const FALL := 2.2            # detik jatuh
const LIFE := 300.0          # detik bertahan setelah mendarat
const SEE_R := 1300.0

var biome := 1
var player
var compass_col := Color(1.0, 0.55, 0.2)
var compass_range := 2600.0
var opened := false
var _t := 0.0
var _landed := false
var _fade := 1.0
var _spark_t := 0.0
var _rd := 0


func _ready() -> void:
    player = get_tree().get_first_node_in_group("player")
    add_to_group("compass_target")
    add_to_group("meteor")
    z_index = 1


func compass_on() -> bool:
    return not opened


func _physics_process(delta: float) -> void:
    _t += delta
    var near := false
    if player != null and is_instance_valid(player):
        near = global_position.distance_to(player.global_position) < SEE_R
    if not _landed:
        if _t >= FALL:
            _land()
    else:
        if opened:
            _fade = maxf(_fade - delta * 1.5, 0.0)
            if _fade <= 0.0:
                queue_free()
                return
        elif _t > FALL + LIFE:
            _fade = maxf(_fade - delta * 0.5, 0.0)
            if _fade <= 0.0:
                queue_free()
                return
        elif player != null and is_instance_valid(player) and not player.dead and global_position.distance_to(player.global_position) < 26.0:
            _open()
        if near and not opened:
            _spark_t -= delta
            if _spark_t <= 0.0:
                _spark_t = 0.45
                get_tree().current_scene.fx_burst(global_position + Vector2(randf_range(-8, 8), -4), Color(1.0, 0.6, 0.2), 3, 40.0, 0.7, -30.0, 2.0, "dot")
    if near:
        _rd += 1
        if _rd >= Perf.anim_div:
            _rd = 0
            queue_redraw()


func _land() -> void:
    _landed = true
    var main = get_tree().current_scene
    main.fx_ring(global_position, 90.0, Color(1.0, 0.6, 0.25), 0.6)
    main.fx_burst(global_position, Color(1.0, 0.7, 0.3), 24, 140.0, 0.8, 120.0, 3.0, "dot")
    if player != null and is_instance_valid(player):
        var d: float = global_position.distance_to(player.global_position)
        if d < 1000.0:
            player.shake_camera(1.0 - d / 1200.0)
            Audio.sfx("boss_roar", 0.5)
    queue_redraw()


func _open() -> void:
    opened = true
    Audio.sfx("chest")
    var main = get_tree().current_scene
    var luk: int = int(player.stat("luk"))
    var lv: int = int(Game.p["level"])
    main.spawn_pickup("coin", global_position + Vector2(0, 14), 80 + lv * 10)
    main.spawn_pickup("gems", global_position + Vector2(10, 16), randi_range(15, 30) + luk / 3)
    var pool := ["crystal", "shard", "obsidian", "sunshard", "ruby", "gold"]
    for i in 4:
        main.spawn_pickup("item:" + String(pool[randi() % pool.size()]), global_position + Vector2(randf_range(-22, 22), randf_range(8, 26)), randi_range(2, 4))
    main.spawn_pickup("item:" + Gear.roll_gear(biome, luk, 2), global_position + Vector2(0, 26), 1)
    main.spawn_pickup("item:potion_hp2", global_position + Vector2(-14, 22), 1)
    main.fx_text(global_position + Vector2(0, -26), "Pecahan Meteor!", Color(1.0, 0.7, 0.3), 16.0)
    main.fx_burst(global_position, Color(1.0, 0.8, 0.4), 18, 90.0, 0.7, 30.0, 2.5, "star")
    queue_redraw()


func _draw() -> void:
    if not _landed:
        # bidikan di tanah + bola api turun dari langit
        var p: float = clampf(_t / FALL, 0.0, 1.0)
        draw_arc(Vector2.ZERO, 60.0 * (1.0 - p) + 14.0, 0.0, TAU, 28, Color(1.0, 0.35, 0.15, 0.25 + 0.5 * p), 3.0)
        var head := Vector2(-320.0, -980.0) * (1.0 - p * p)
        var dir: Vector2 = (Vector2.ZERO - head).normalized() if head.length() > 1.0 else Vector2.DOWN
        draw_line(head - dir * 260.0, head, Color(1.0, 0.55, 0.2, 0.45), 14.0)
        draw_line(head - dir * 160.0, head, Color(1.0, 0.85, 0.5, 0.8), 7.0)
        draw_circle(head, 16.0, Color(1.0, 0.9, 0.6, 0.95))
        draw_circle(head, 30.0, Color(1.0, 0.5, 0.15, 0.30))
        return
    var f: float = sin(_t * 3.0) * 0.5 + 0.5
    var a: float = _fade
    Art.ellipse(self, Vector2(0, 6), 40.0, 17.0, Color(0.10, 0.07, 0.06, 0.8 * a), 16)       # kawah
    Art.ellipse(self, Vector2(0, 4), 30.0, 12.0, Color(0.18, 0.11, 0.08, 0.9 * a), 16)
    draw_circle(Vector2(0, -6), 34.0 + f * 6.0, Color(1.0, 0.5, 0.15, (0.10 + 0.06 * f) * a))
    if opened:
        return
    # batu meteor berpendar
    var rock := PackedVector2Array([Vector2(-14, 4), Vector2(-16, -8), Vector2(-6, -18), Vector2(8, -17), Vector2(16, -7), Vector2(13, 4)])
    draw_colored_polygon(rock, Color(0.20, 0.14, 0.14, a))
    draw_polyline(PackedVector2Array([Vector2(-8, -2), Vector2(-2, -9), Vector2(2, -3), Vector2(8, -11)]), Color(1.0, 0.55 + 0.3 * f, 0.15, a), 2.0)
    draw_polyline(PackedVector2Array([Vector2(-11, -8), Vector2(-5, -12)]), Color(1.0, 0.6, 0.2, 0.8 * a), 1.5)
