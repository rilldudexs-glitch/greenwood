extends Node2D
# Tunggangan: kuda yang digambar kode di belakang pemain (child dari Player, show_behind_parent).

var _t := 0.0


func _ready() -> void:
    show_behind_parent = true
    visible = false


func _process(delta: float) -> void:
    var pl = get_parent()
    visible = bool(pl.mounted)
    if not visible:
        return
    _t += delta * (4.0 + pl.velocity.length() * 0.06)
    queue_redraw()


func _draw() -> void:
    var pl = get_parent()
    var fx: float = 1.0 if pl._face.x >= 0.0 else -1.0
    var moving: bool = pl.velocity.length() > 8.0
    var body := Color(0.55, 0.36, 0.2)
    var dark := Color(0.3, 0.19, 0.1)
    draw_set_transform(Vector2(0, 11), 0.0, Vector2(1.0, 0.4))
    draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.28))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    for i in 4:
        var side: float = -1.0 if i < 2 else 1.0
        var ph: float = _t * 1.6 + (0.0 if i % 2 == 0 else PI)
        var sw: float = sin(ph) * (5.0 if moving else 0.0)
        var x: float = fx * side * 8.0 + (0.0 if i % 2 == 0 else fx * 2.0)
        draw_line(Vector2(x, 8.0), Vector2(x + sw, 17.0), dark, 2.6)
    draw_set_transform(Vector2(0, 7), 0.0, Vector2(1.0, 0.55))
    draw_circle(Vector2.ZERO, 12.5, body)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    var hx: float = fx * 11.0
    draw_line(Vector2(fx * 8.0, 4.0), Vector2(hx, -2.0), body, 5.0)
    draw_circle(Vector2(hx + fx * 3.0, -2.0), 3.6, body)
    draw_circle(Vector2(hx + fx * 6.0, -1.0), 1.6, dark)
    draw_line(Vector2(fx * 8.0, 2.0), Vector2(fx * 4.0, -3.0), dark, 2.0)
    draw_line(Vector2(-fx * 12.0, 6.0), Vector2(-fx * 16.0, 10.0 + sin(_t) * 2.0), dark, 2.2)
