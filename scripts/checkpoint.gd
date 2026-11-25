extends Node2D
# Api unggun: sentuh untuk menyimpan titik respawn + memulihkan HP/MP.

const Art = preload("res://scripts/art.gd")

var uid := 0
var active := false
var player
var _inside := false
var _t := randf() * 5.0
var _rd := 0


func _ready() -> void:
    player = get_tree().get_first_node_in_group("player")
    add_to_group("lod")


func _physics_process(delta: float) -> void:
    _t += delta
    _rd += 1
    if _rd >= Perf.anim_div:
        _rd = 0
        queue_redraw()
    if player == null or player.dead:
        return
    var near: bool = global_position.distance_to(player.global_position) < 26.0
    if near and not _inside:
        _inside = true
        _touch()
    elif not near:
        _inside = false


func _touch() -> void:
    var first := not active
    active = true
    Game.checkpoint_pos = [global_position.x, global_position.y + 20.0]
    if not Game.checkpoints.has(uid):
        Game.checkpoints.append(uid)
    if first or player.hp < player.max_hp or player.mp < player.max_mp:
        player.full_heal()
        get_tree().current_scene.fx_burst(player.global_position, Color(0.5, 1.0, 0.6), 12, 50.0, 0.7, -30.0, 2.0, "star")
    Audio.sfx("checkpoint")
    var hud = get_tree().get_first_node_in_group("hud")
    if hud:
        hud.show_banner("Checkpoint tersimpan", 2.0)
    Game.save()


func _draw() -> void:
    Art.shadow(self, 10.0, 12.0)
    for i in 5:
        var a: float = TAU * i / 5.0
        Art.ellipse(self, Vector2.from_angle(a) * 8.0 + Vector2(0, 6), 3.5, 2.5, Color(0.45, 0.45, 0.5), 8)
    draw_line(Vector2(-8, 6), Vector2(8, -2), Color(0.45, 0.3, 0.15), 3.0)
    draw_line(Vector2(8, 6), Vector2(-8, -2), Color(0.4, 0.27, 0.13), 3.0)
    if active:
        var f: float = sin(_t * 12.0) * 1.5
        Art.ellipse(self, Vector2(0, -3), 6.0 + f * 0.3, 9.0 + f, Color(1.0, 0.45, 0.1, 0.9), 10)
        Art.ellipse(self, Vector2(0, -2), 4.0, 6.5 + f * 0.6, Color(1.0, 0.8, 0.25), 10)
        Art.ellipse(self, Vector2(0, -1), 2.0, 3.5, Color(1.0, 1.0, 0.8), 8)
        draw_circle(Vector2(0, -3), 26.0, Color(1.0, 0.6, 0.2, 0.08))
    else:
        draw_circle(Vector2(0, 0), 2.0, Color(0.3, 0.3, 0.3))
