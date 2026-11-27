extends Node
# Cahaya hangat di sumber api/lampu saat malam (lampu & obor kastil, jendela rumah) + kilau air.
# Digambar di CanvasLayer sendiri supaya tidak ikut digelapkan CanvasModulate malam.

var main
var world
var player
var atmos
var _layer: CanvasLayer
var _view: Control
var _tex: GradientTexture2D
var _mat: CanvasItemMaterial
var _lights := PackedVector2Array()
var _warm := PackedFloat32Array()
var _sparks: Array = []        # [pos dunia, umur]
var _acc := 0.0
var _sp_acc := 0.0
var _t := 0.0


class View extends Control:
    var g

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        set_anchors_preset(Control.PRESET_FULL_RECT)

    func _draw() -> void:
        g.paint(self)


func setup(m, pl, w, at) -> void:
    main = m
    player = pl
    world = w
    atmos = at
    _layer = CanvasLayer.new()
    _layer.layer = 2
    add_child(_layer)
    _view = View.new()
    _view.g = self
    _layer.add_child(_view)
    _mat = CanvasItemMaterial.new()
    _mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    _view.material = _mat
    _tex = GradientTexture2D.new()
    var gr := Gradient.new()
    gr.set_color(0, Color(1.0, 0.8, 0.45, 0.55))
    gr.set_color(1, Color(1.0, 0.6, 0.2, 0.0))
    _tex.gradient = gr
    _tex.fill = GradientTexture2D.FILL_RADIAL
    _tex.fill_from = Vector2(0.5, 0.5)
    _tex.fill_to = Vector2(1.0, 0.5)
    _tex.width = 96
    _tex.height = 96
    _collect()


func _collect() -> void:
    _lights = PackedVector2Array()
    _warm = PackedFloat32Array()
    for p in world.light_points:
        _lights.append(p)
        _warm.append(1.0)
    for hs in world.houses:
        var kd: String = String(hs.get("kind", ""))
        if kd == "hut":
            continue
        # satu kilau jendela/pintu per rumah
        _lights.append(Vector2(float(int(hs["x"]) * 32) + float(int(hs["w"]) * 16), float((int(hs["y"]) + int(hs["h"])) * 32) - 14.0))
        _warm.append(0.55)


func _process(delta: float) -> void:
    if atmos == null or player == null or not is_instance_valid(player) or main.dungeon != null:
        _view.visible = false
        return
    _view.visible = true
    _t += delta
    _acc += delta
    var low: bool = Perf.tier >= 2
    if _acc >= (0.05 if Perf.tier == 0 else 0.1):
        _acc = 0.0
        _view.queue_redraw()
    # kilau air: titik acak di layar yang jatuh di sel air
    _sp_acc += delta
    var step: float = 0.18 / maxf(0.2, Perf.fx_scale)
    if _sp_acc >= step and not low and _sparks.size() < 14:
        _sp_acc = 0.0
        var cam: Vector2 = player.global_position
        var p: Vector2 = cam + Vector2(randf_range(-230.0, 230.0), randf_range(-130.0, 130.0))
        var c: Vector2i = world.cell_of(p)
        if world.in_bounds(c) and world.kind[world.idx(c.x, c.y)] == world.K.WATER:
            _sparks.append([p, 0.0])
    for s in _sparks:
        s[1] = float(s[1]) + delta
    _sparks = _sparks.filter(func(s): return float(s[1]) < 0.7)


func paint(v: Control) -> void:
    var xf: Transform2D = get_viewport().get_canvas_transform()
    var sc: float = xf.get_scale().x
    var vs: Vector2 = get_viewport().get_visible_rect().size
    var night: float = clampf(atmos._light.energy, 0.0, 0.9) / 0.9
    if night > 0.06 and Perf.tier < 3:
        for i in _lights.size():
            var sp: Vector2 = xf * _lights[i]
            if sp.x < -80.0 or sp.y < -80.0 or sp.x > vs.x + 80.0 or sp.y > vs.y + 80.0:
                continue
            var fl: float = 0.85 + 0.15 * sin(_t * 9.0 + _lights[i].x * 0.13)
            var r: float = 46.0 * sc
            v.draw_texture_rect(_tex, Rect2(sp - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, night * _warm[i] * fl))
    for s in _sparks:
        var u: float = float(s[1]) / 0.7
        var q: Vector2 = xf * (s[0] as Vector2)
        var a: float = sin(u * PI)
        var l: float = (2.0 + 2.0 * a) * sc * 0.5
        v.draw_line(q - Vector2(l, 0), q + Vector2(l, 0), Color(1, 1, 1, 0.8 * a), 1.0)
        v.draw_line(q - Vector2(0, l), q + Vector2(0, l), Color(1, 1, 1, 0.8 * a), 1.0)
