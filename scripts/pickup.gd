extends Node2D
# Item di tanah: "coin", "gems", atau "item:<id>". Tertarik otomatis ke pemain saat dekat.

const Art = preload("res://scripts/art.gd")

var kind := "coin"
var amount := 1
var player

var _t := randf() * TAU
var _life := 120.0
var _vel := Vector2(randf_range(-30, 30), randf_range(-40, -10))


var _rd := 0


func _ready() -> void:
    player = get_tree().get_first_node_in_group("player")
    z_index = 1


func _physics_process(delta: float) -> void:
    _t += delta * 4.0
    _life -= delta
    if _life <= 0.0:
        queue_free()
        return
    if _vel.length() > 2.0:
        position += _vel * delta
        _vel = _vel.move_toward(Vector2.ZERO, 120.0 * delta)
    if player and not player.dead:
        var d: float = global_position.distance_to(player.global_position)
        var rng_m: float = 96.0 if (kind == "coin" or kind == "gems") else 56.0     # koin & gem tersedot dari lebih jauh
        if d < rng_m and _life < 119.5:
            var spd: float = 150.0 + (rng_m - d) * 5.0                                # makin dekat makin cepat
            global_position = global_position.move_toward(player.global_position, spd * delta)
        if d < 14.0 and _life < 119.5:
            if player.collect(kind, amount):
                queue_free()
    _rd += 1
    if _rd >= 2:
        _rd = 0
        queue_redraw()


func _draw() -> void:
    var y: float = sin(_t) * 2.0
    Art.shadow(self, 6.0, 5.0)
    if kind == "coin":
        Art.draw_currency(self, "coin", Vector2(0, y - 3.0), 5.5)
    elif kind == "gems":
        Art.draw_currency(self, "gem", Vector2(0, y - 3.0), 6.5)
    else:
        var iid: String = kind.substr(5)
        if Items.info(iid).has("rarity"):
            var rc: Color = Items.info(iid)["color"]
            draw_circle(Vector2(0, y - 3.0), 12.0, Color(rc.r, rc.g, rc.b, 0.25))
            Art.draw_icon(self, iid, Vector2(0, y - 3.0), 26.0)
        else:
            Art.draw_icon(self, iid, Vector2(0, y - 3.0), 16.0)
