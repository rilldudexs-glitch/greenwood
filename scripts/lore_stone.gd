extends Node2D
# Prasasti kuno di dunia terbuka: tekan E untuk membaca. Pertama kali dibaca = hadiah (lihat lore.gd).

const Art = preload("res://scripts/art.gd")
const Lore = preload("res://scripts/lore.gd")

var stone_id := "f1"
var biome := 1
var player
var _t := randf() * 6.0
var _rd := 0
var _hint_ms := 0


func _ready() -> void:
    player = get_tree().get_first_node_in_group("player")
    add_to_group("lod")
    add_to_group("lore")


func _physics_process(delta: float) -> void:
    _t += delta
    _rd += 1
    if _rd >= Perf.anim_div:
        _rd = 0
        queue_redraw()
    if player == null or player.dead:
        return
    if global_position.distance_to(player.global_position) > 40.0:
        return
    var hud = get_tree().get_first_node_in_group("hud")
    if hud == null or hud.busy():
        return
    if Input.is_action_just_pressed("interact"):
        var d: Dictionary = Lore.get_def(stone_id)
        hud.say("Prasasti Kuno", [String(d["title"])] + (d["lines"] as Array), _after_read.bind(hud))
        return
    if Time.get_ticks_msec() - _hint_ms > 3000:
        _hint_ms = Time.get_ticks_msec()
        hud.show_banner("Tekan E untuk membaca prasasti" if not Lore.found(stone_id) else "Prasasti ini sudah kamu baca (E untuk membaca lagi)", 2.0)


func _after_read(hud) -> void:
    var res: Dictionary = Lore.mark(stone_id, player)
    if bool(res["first"]):
        Audio.sfx("win")
        hud.toast(String(res["msg"]))
        if String(res["banner"]) != "":
            hud.show_banner(String(res["banner"]), 4.0)


func _draw() -> void:
    var read: bool = Lore.found(stone_id)
    var glow: Color = Color(0.45, 0.85, 1.0) if read else Color(1.0, 0.82, 0.3)
    var f: float = sin(_t * 2.2) * 0.5 + 0.5
    Art.shadow(self, 20.0, 9.0)
    # puing pilar di sekeliling
    Art.ellipse(self, Vector2(-22, 4), 7.0, 5.0, Color(0.36, 0.34, 0.33), 8)
    Art.ellipse(self, Vector2(20, 6), 8.0, 5.5, Color(0.33, 0.31, 0.30), 8)
    draw_rect(Rect2(-30, -6, 7, 12), Color(0.38, 0.36, 0.35))
    draw_rect(Rect2(24, -2, 6, 9), Color(0.35, 0.33, 0.32))
    # monolit
    draw_colored_polygon(PackedVector2Array([Vector2(-10, 8), Vector2(-8, -26), Vector2(0, -31), Vector2(8, -26), Vector2(10, 8)]), Color(0.30, 0.29, 0.31))
    draw_colored_polygon(PackedVector2Array([Vector2(2, 8), Vector2(2, -30), Vector2(8, -26), Vector2(10, 8)]), Color(0.24, 0.23, 0.25))
    draw_line(Vector2(-8, -26), Vector2(0, -31), Color(1, 1, 1, 0.18), 1.5)
    # rune bercahaya
    for i in 4:
        var y: float = -22.0 + float(i) * 7.0
        draw_line(Vector2(-4, y), Vector2(3, y + (2.0 if i % 2 == 0 else -2.0)), Color(glow.r, glow.g, glow.b, 0.45 + f * 0.4), 2.0)
    draw_circle(Vector2(0, -12), 18.0 + f * 3.0, Color(glow.r, glow.g, glow.b, 0.06 if read else 0.10))
