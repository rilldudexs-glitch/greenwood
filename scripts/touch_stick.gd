extends Control
# Joystick virtual. Memakai InputEventScreenTouch/Drag supaya bisa multi-touch
# bareng tombol serang.

# Radius dihitung dari ukuran kontrol (diatur HUD) supaya joystick besar & nyaman dipakai.
var radius := 80.0

var value := Vector2.ZERO
var _finger := -1
var _knob := Vector2.ZERO


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
    var c := size / 2.0
    draw_circle(c, radius, Color(1, 1, 1, 0.16))
    draw_arc(c, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
    draw_arc(c, radius * 0.5, 0.0, TAU, 32, Color(1, 1, 1, 0.14), 2.0)
    draw_circle(c + _knob, radius * 0.42, Color(1, 1, 1, 0.5))
    draw_arc(c + _knob, radius * 0.42, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)


func _input(event: InputEvent) -> void:
    if not is_visible_in_tree():
        return
    if event is InputEventScreenTouch:
        if event.pressed and _finger == -1 and get_global_rect().has_point(event.position):
            _finger = event.index
            _update(event.position)
        elif not event.pressed and event.index == _finger:
            _finger = -1
            _knob = Vector2.ZERO
            value = Vector2.ZERO
            queue_redraw()
    elif event is InputEventScreenDrag and event.index == _finger:
        _update(event.position)


func _update(pos: Vector2) -> void:
    var v := (pos - get_global_rect().get_center()) / radius
    if v.length() > 1.0:
        v = v.normalized()
    _knob = v * radius
    value = v if v.length() > 0.15 else Vector2.ZERO
    queue_redraw()
