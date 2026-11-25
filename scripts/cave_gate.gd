extends Node2D
# Mulut gua di dunia terbuka: tekan E untuk masuk ke dungeon (lihat dungeon.gd / main.dungeon_enter).

const Art = preload("res://scripts/art.gd")
const Dungeon = preload("res://scripts/dungeon.gd")

var dungeon_id := "akar"
var player
var _t := randf() * 6.0
var _rd := 0
var _hint_ms := 0


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
    if global_position.distance_to(player.global_position) > 46.0:
        return
    var main = get_tree().current_scene
    var d: Dictionary = Dungeon.DEFS[dungeon_id]
    if Input.is_action_just_pressed("interact"):
        main.dungeon_enter(dungeon_id)
        return
    if Time.get_ticks_msec() - _hint_ms > 3000:
        _hint_ms = Time.get_ticks_msec()
        main.hud.show_banner("Tekan E untuk masuk: %s  (disarankan Lv %d+)" % [String(d["name"]), int(d["rec"])], 2.5)


func _draw() -> void:
    var d: Dictionary = Dungeon.DEFS[dungeon_id]
    var tc: Color = d["torch"]
    var f: float = sin(_t * 2.5)
    Art.shadow(self, 30.0, 14.0)
    # batu-batu di sekeliling mulut gua
    for i in 9:
        var a: float = PI + float(i) / 8.0 * PI
        var p := Vector2(cos(a) * 26.0, sin(a) * 22.0 - 2.0)
        var g: float = 0.30 + float((i * 37) % 5) * 0.03
        Art.ellipse(self, p, 9.0, 8.0, Color(g, g * 0.95, g * 0.9), 10)
    Art.ellipse(self, Vector2(0, -2), 19.0, 17.0, Color(0.03, 0.025, 0.04), 16)       # mulut gua
    Art.ellipse(self, Vector2(0, 2), 12.0, 9.0, Color(tc.r, tc.g, tc.b, 0.16 + f * 0.04), 12)  # cahaya dari dalam
    # nama di atas gua
    var font := ThemeDB.fallback_font
    var nm: String = String(d["name"])
    draw_string_outline(font, Vector2(-60, -38), nm, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, 3, Color(0, 0, 0, 0.9))
    draw_string(font, Vector2(-60, -38), nm, HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(1.0, 0.9, 0.6))
