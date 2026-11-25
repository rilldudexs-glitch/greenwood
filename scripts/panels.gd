extends RefCounted
# Panel layar penuh milik HUD: Daftar Tugas (quest log) dan Peta Dunia (dengan fast travel ke kastil yang sudah ditemukan).

# ------------------------------------------------------------------ daftar tugas
class QuestLog extends Control:
    const P = preload("res://scripts/panel_util.gd")
    var hud
    var _rt: RichTextLabel
    var _built := false

    func build() -> void:
        _built = true
        var pc := P._frame(self)
        pc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        pc.offset_left = 28
        pc.offset_right = -28
        pc.offset_top = 16
        pc.offset_bottom = -16
        add_child(pc)
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 6)
        pc.add_child(vb)
        var ti := Label.new()
        ti.text = "Daftar Tugas"
        ti.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        ti.add_theme_font_size_override("font_size", 20)
        ti.add_theme_color_override("font_color", Color(1, 0.9, 0.75))
        vb.add_child(ti)
        var sc := ScrollContainer.new()
        sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
        sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        vb.add_child(sc)
        _rt = RichTextLabel.new()
        _rt.bbcode_enabled = true
        _rt.fit_content = true
        _rt.scroll_active = false
        _rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _rt.add_theme_font_size_override("normal_font_size", 15)
        _rt.add_theme_font_size_override("bold_font_size", 17)
        sc.add_child(_rt)
        var cb := Button.new()
        cb.text = "Tutup"
        cb.custom_minimum_size = Vector2(0, 44)
        cb.pressed.connect(close)
        vb.add_child(cb)

    func open() -> void:
        if not _built:
            build()
        _rt.text = P.quest_text(hud.player)
        visible = true

    func close() -> void:
        visible = false
        hud.panel_closed()


# ------------------------------------------------------------------ peta dunia
class WorldMap extends Control:
    const P = preload("res://scripts/panel_util.gd")
    var hud
    var _view: Control
    var _name: Label
    var _go: Button
    var _sel := -1
    var _built := false

    func build() -> void:
        _built = true
        P._frame(self)      # tema, anchor, dim
        _view = MapView.new()
        _view.map = self
        add_child(_view)
        var bar := VBoxContainer.new()
        bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
        bar.offset_top = -108
        bar.offset_left = 40
        bar.offset_right = -40
        bar.offset_bottom = -8
        bar.add_theme_constant_override("separation", 4)
        add_child(bar)
        _name = Label.new()
        _name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _name.add_theme_font_size_override("font_size", 15)
        bar.add_child(_name)
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 10)
        bar.add_child(row)
        _go = Button.new()
        _go.text = "Teleport"
        _go.custom_minimum_size = Vector2(0, 44)
        _go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _go.disabled = true
        _go.pressed.connect(_teleport)
        row.add_child(_go)
        var cb := Button.new()
        cb.text = "Tutup"
        cb.custom_minimum_size = Vector2(0, 44)
        cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        cb.pressed.connect(close)
        row.add_child(cb)

    func open() -> void:
        if not _built:
            build()
        _sel = -1
        _refresh_label()
        visible = true
        _view.queue_redraw()

    func close() -> void:
        visible = false
        hud.panel_closed()

    func select(i: int) -> void:
        _sel = i
        _refresh_label()
        _view.queue_redraw()

    func _refresh_label() -> void:
        var w = hud.world
        if _sel < 0:
            _name.text = "Ketuk kastil bertanda emas untuk teleport (kastil baru terbuka setelah kamu mendekatinya)."
            _go.disabled = true
        else:
            var cs: Dictionary = w.castles[_sel]
            _name.text = "Kastil %s" % String(w.BNAMES[int(cs["biome"])])
            _go.disabled = w.has_meta("in_dungeon")

    func _teleport() -> void:
        var w = hud.world
        var pl = hud.player
        if _sel < 0 or pl == null or w.has_meta("in_dungeon"):
            return
        var g: Vector2 = w._castle_gate(_sel)
        var from: Vector2 = pl.global_position
        pl.global_position = w.find_open(Vector2i(int(g.x), int(g.y)))
        pl.velocity = Vector2.ZERO
        Audio.sfx("levelup")
        hud.toast("Teleport ke Kastil %s" % String(w.BNAMES[int(w.castles[_sel]["biome"])]))
        close()
        var main = get_tree().current_scene
        main.fx_burst(from, Color(0.7, 0.9, 1.0), 12, 70.0, 0.6, 0.0, 2.5, "star")
        main.fx_burst(pl.global_position, Color(0.7, 0.9, 1.0), 12, 70.0, 0.6, 0.0, 2.5, "star")


class MapView extends Control:
    var map
    var _rect := Rect2()

    func _ready() -> void:
        set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        mouse_filter = Control.MOUSE_FILTER_STOP

    func _calc() -> void:
        var sz: Vector2 = size
        var w: float = minf(sz.x - 40.0, (sz.y - 130.0) * 2.0)
        _rect = Rect2(Vector2((sz.x - w) / 2.0, 12.0), Vector2(w, w / 2.0))

    func _to_map(world, cell: Vector2) -> Vector2:
        return _rect.position + cell / Vector2(world.W, world.H) * _rect.size

    func _draw() -> void:
        var hud = map.hud
        var w = hud.world
        if hud.minimap_tex == null or w == null:
            return
        _calc()
        draw_rect(_rect.grow(3.0), Color(0.9, 0.75, 0.45))
        draw_rect(_rect, Color(0.04, 0.03, 0.07))
        draw_texture_rect(hud.minimap_tex, _rect, false)
        if hud.fog != null:
            draw_texture_rect(hud.fog.tex, _rect, false)
        var f: Font = ThemeDB.fallback_font
        for i in w.castles.size():
            if not hud.castle_found(i):
                continue
            var cs: Dictionary = w.castles[i]
            var c: Vector2 = _to_map(w, Vector2(float(cs["x"]) + float(cs["w"]) / 2.0, float(cs["y"]) + float(cs["h"]) / 2.0))
            var sel: bool = (i == map._sel)
            var r: float = 9.0 if sel else 7.0
            draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), Color.BLACK)
            draw_rect(Rect2(c - Vector2(r - 1.5, r - 1.5), Vector2(r - 1.5, r - 1.5) * 2.0), Color(1.0, 0.85, 0.3) if not sel else Color(1, 1, 1))
            draw_string(f, c + Vector2(-40, -r - 3.0), String(w.BNAMES[int(cs["biome"])]), HORIZONTAL_ALIGNMENT_CENTER, 80, 11, Color.WHITE)
        if hud.player != null:
            var pp: Vector2 = _rect.position + hud.player.global_position / w.world_size() * _rect.size
            var tri := PackedVector2Array([pp + Vector2(0, -7), pp + Vector2(-5, 5), pp + Vector2(5, 5)])
            draw_colored_polygon(tri, Color(0.95, 0.15, 0.2))
            draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color.WHITE, 1.5)

    func _gui_input(event: InputEvent) -> void:
        var pos := Vector2.ZERO
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            pos = event.position
        elif event is InputEventScreenTouch and event.pressed:
            pos = event.position
        else:
            return
        var hud = map.hud
        var w = hud.world
        _calc()
        var best := -1
        var bd := 36.0
        for i in w.castles.size():
            if not hud.castle_found(i):
                continue
            var cs: Dictionary = w.castles[i]
            var c: Vector2 = _to_map(w, Vector2(float(cs["x"]) + float(cs["w"]) / 2.0, float(cs["y"]) + float(cs["h"]) / 2.0))
            var d: float = c.distance_to(pos)
            if d < bd:
                bd = d
                best = i
        if best >= 0:
            Audio.sfx("select")
            map.select(best)
