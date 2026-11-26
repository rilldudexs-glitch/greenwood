extends RefCounted
# Panel "Karakter": tab Pohon Skill dan tab Gelar & Achievement.

const P = preload("res://scripts/panel_util.gd")
const Prog = preload("res://scripts/progress.gd")
const Jobs = preload("res://scripts/jobs.gd")


class CharPanel extends Control:
    const P = preload("res://scripts/panel_util.gd")
    const Prog = preload("res://scripts/progress.gd")
    const Jobs = preload("res://scripts/jobs.gd")
    var hud
    var _tab := 0
    var _list: VBoxContainer
    var _head: Label
    var _built := false

    func _init() -> void:
        visible = false

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
        _head = Label.new()
        _head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _head.add_theme_font_size_override("font_size", 18)
        _head.add_theme_color_override("font_color", Color(1, 0.9, 0.75))
        vb.add_child(_head)
        var tabs := HBoxContainer.new()
        tabs.add_theme_constant_override("separation", 8)
        vb.add_child(tabs)
        for i in 2:
            var b := Button.new()
            b.text = ["Pohon Skill", "Gelar & Achievement"][i]
            b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            b.custom_minimum_size = Vector2(0, 44)
            b.pressed.connect(_set_tab.bind(i))
            tabs.add_child(b)
        var sc := ScrollContainer.new()
        sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
        sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        vb.add_child(sc)
        _list = VBoxContainer.new()
        _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _list.add_theme_constant_override("separation", 6)
        sc.add_child(_list)
        var cb := Button.new()
        cb.text = "Tutup"
        cb.custom_minimum_size = Vector2(0, 44)
        cb.pressed.connect(close)
        vb.add_child(cb)

    func open() -> void:
        if not _built:
            build()
        _refresh()
        visible = true

    func close() -> void:
        visible = false
        hud.panel_closed()

    func _set_tab(i: int) -> void:
        _tab = i
        _refresh()

    func _clear() -> void:
        for c in _list.get_children():
            _list.remove_child(c)
            c.queue_free()

    func _label(text: String, size: int = 14, col: Color = Color(0.92, 0.9, 0.95)) -> Label:
        var l := Label.new()
        l.text = text
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", col)
        return l

    func _refresh() -> void:
        _clear()
        if _tab == 0:
            _skills()
        else:
            _achs()

    func _skills() -> void:
        _head.text = "Pohon Skill  -  Poin: %d" % Prog.free_points()
        var sk: Dictionary = Jobs.skill()
        var sname: String = String(sk.get("name", "Tebasan Memutar"))
        _list.add_child(_label("%s - skill: %s\nPoin = level / %d. Maks %d rank per cabang." % [Jobs.name_of(Jobs.cur()), sname, Prog.PTS_DIV, Prog.MAX_RANK], 13, Color(0.75, 0.8, 0.9)))
        for n in Prog.NODES:
            var id: String = String(n["id"])
            var row := HBoxContainer.new()
            row.add_theme_constant_override("separation", 8)
            var nm: String = String(n["name"])
            if id == "sk_dmg":
                nm = "Penguasaan: " + sname
            var txt := "%s  [%d/%d]\n%s" % [nm, Prog.rank(id), Prog.MAX_RANK, String(n["desc"])]
            row.add_child(_label(txt, 14))
            var b := Button.new()
            b.text = "+"
            b.custom_minimum_size = Vector2(64, 52)
            b.disabled = not Prog.can_up(id)
            b.pressed.connect(_up.bind(id))
            row.add_child(b)
            _list.add_child(row)
        var rb := Button.new()
        rb.text = "Reset semua poin (gratis)"
        rb.custom_minimum_size = Vector2(0, 44)
        rb.disabled = Prog.spent() == 0
        rb.pressed.connect(_reset)
        _list.add_child(rb)

    func _up(id: String) -> void:
        if Prog.up(id):
            if hud.player != null and is_instance_valid(hud.player):
                hud.player.recalc()
            Audio.sfx("levelup")
        _refresh()

    func _reset() -> void:
        Prog.reset()
        if hud.player != null and is_instance_valid(hud.player):
            hud.player.recalc()
        _refresh()

    func _achs() -> void:
        var n_done := 0
        for a in Prog.ACH:
            if Prog.is_done(String(a["id"])):
                n_done += 1
        var cur: String = Prog.title_text()
        _head.text = "Gelar: %s  (%d/%d)" % [cur if cur != "" else "-", n_done, Prog.ACH.size()]
        var nb := Button.new()
        nb.text = "Lepas gelar"
        nb.custom_minimum_size = Vector2(0, 40)
        nb.pressed.connect(_pick.bind(""))
        _list.add_child(nb)
        for a in Prog.ACH:
            var id: String = String(a["id"])
            var ok: bool = Prog.is_done(id)
            var row := HBoxContainer.new()
            row.add_theme_constant_override("separation", 8)
            var rew := "Hadiah: %d koin" % int(a.get("coins", 0))
            if int(a.get("gems", 0)) > 0:
                rew += ", %d gem" % int(a["gems"])
            var txt := ""
            if ok:
                txt = "[v] %s\n%s  -  gelar \"%s\"" % [String(a["name"]), String(a["desc"]), String(a.get("title", ""))]
            else:
                txt = "[ ] %s  (%d/%d)\n%s  -  %s" % [String(a["name"]), mini(Prog.value(a), int(a["n"])), int(a["n"]), String(a["desc"]), rew]
            row.add_child(_label(txt, 13, Color(1, 0.9, 0.6) if ok else Color(0.7, 0.7, 0.78)))
            if ok:
                var b := Button.new()
                b.text = "Pakai"
                b.custom_minimum_size = Vector2(76, 48)
                b.disabled = String(Game.p.get("title", "")) == id
                b.pressed.connect(_pick.bind(id))
                row.add_child(b)
            _list.add_child(row)

    func _pick(id: String) -> void:
        Prog.set_title(id)
        _refresh()
