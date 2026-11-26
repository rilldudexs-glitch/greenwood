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
        for i in 5:
            var b := Button.new()
            b.add_theme_font_size_override("font_size", 12)
            b.text = ["Skill", "Gelar", "Bestiary", "Tempa", "Data"][i]
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
        _msg = ""
        _confirm = false
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
        match _tab:
            0:
                _skills()
            1:
                _achs()
            2:
                _bestiary()
            3:
                _forge()
            _:
                _data()

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

    # ---------------------------------------------------------------- bestiary
    var _open_b := -1

    func _bestiary() -> void:
        _head.text = "Bestiary - buku monster"
        _list.add_child(_label("Kalahkan semua monster satu biome untuk hadiah. Ketuk nama biome untuk membuka daftar.", 12, Color(0.75, 0.8, 0.9)))
        var names: Array = Prog.biome_names()
        var tbl: Dictionary = Prog.mob_table()
        var keys: Array = tbl.keys()
        keys.sort()
        for b in keys:
            var pr: Vector2i = Prog.biome_progress(int(b))
            var done: bool = int(Game.p.get("bst", {}).get(str(b), 0)) > 0
            var hb := Button.new()
            hb.text = "%s  %d/%d%s" % [String(names[int(b)]), pr.x, pr.y, "  [lengkap]" if done else ""]
            hb.alignment = HORIZONTAL_ALIGNMENT_LEFT
            hb.custom_minimum_size = Vector2(0, 40)
            hb.pressed.connect(_toggle_b.bind(int(b)))
            _list.add_child(hb)
            if _open_b == int(b):
                var lines := ""
                var kinds: Array = (tbl[b] as Dictionary).keys()
                for k in kinds:
                    var n: int = int(Game.p.get("kills", {}).get(String(k), 0))
                    lines += ("%s  x%d\n" % [Prog.mob_label(String(k)), n]) if n > 0 else "???\n"
                _list.add_child(_label(lines, 13, Color(0.85, 0.9, 0.8)))

    func _toggle_b(b: int) -> void:
        _open_b = -1 if _open_b == b else b
        _refresh()

    # ---------------------------------------------------------------- tempa
    var _msg := ""

    func _forge() -> void:
        _head.text = "Tempa Gear  -  %d koin, %d gem" % [int(Game.p.get("coins", 0)), int(Game.p.get("gems", 0))]
        _list.add_child(_label("Tempa perlengkapan yang sedang dipakai sampai +%d. Senjata: damage +7%%/level. Armor: DEF +2%% & HP +1.5%%/level. Mulai +5 ada risiko gagal (biaya hangus, level tidak turun)." % Prog.ENCH_MAX, 12, Color(0.75, 0.8, 0.9)))
        if _msg != "":
            _list.add_child(_label(_msg, 14, Color(1, 0.9, 0.5)))
        var ids: Array = []
        for k in ["sword", "staff"]:
            var id: String = String(Game.p.get(k, ""))
            if id != "" and not ids.has(id):
                ids.append(id)
        var eq = Game.p.get("equip", {})
        if typeof(eq) == TYPE_DICTIONARY:
            for s in eq.keys():
                var id2: String = String(eq[s])
                if id2 != "" and not ids.has(id2):
                    ids.append(id2)
        if ids.is_empty():
            _list.add_child(_label("Belum ada perlengkapan terpasang.", 13))
        for id in ids:
            var lv: int = Prog.ench(String(id))
            var row := HBoxContainer.new()
            row.add_theme_constant_override("separation", 8)
            var txt := "%s  +%d" % [Items.item_name(String(id)), lv]
            if lv < Prog.ENCH_MAX:
                var c: Dictionary = Prog.ench_cost(lv)
                txt += "\nBiaya %d koin%s  -  peluang %d%%" % [int(c["coins"]), (", %d gem" % int(c["gems"])) if int(c["gems"]) > 0 else "", int(c["chance"])]
            else:
                txt += "\nMaksimum"
            row.add_child(_label(txt, 13, Items.info(String(id)).get("color", Color.WHITE)))
            var b := Button.new()
            b.text = "Tempa"
            b.custom_minimum_size = Vector2(84, 52)
            b.disabled = lv >= Prog.ENCH_MAX
            b.pressed.connect(_do_ench.bind(String(id)))
            row.add_child(b)
            _list.add_child(row)

    func _do_ench(id: String) -> void:
        var r: String = Prog.ench_try(id)
        match r:
            "sukses":
                _msg = "Berhasil! %s jadi +%d" % [Items.item_name(id), Prog.ench(id)]
                Audio.sfx("levelup")
            "gagal":
                _msg = "Gagal... bahan hangus."
                Audio.sfx("hurt")
            "kurang":
                _msg = "Koin atau gem tidak cukup."
            _:
                _msg = ""
        if hud.player != null and is_instance_valid(hud.player):
            hud.player.recalc()
        _refresh()

    # ---------------------------------------------------------------- data / backup
    var _confirm := false

    func _data() -> void:
        _head.text = "Data & Backup"
        _list.add_child(_label("Salin save ke clipboard, lalu tempel ke catatan/chat sebagai cadangan. Di HP baru, salin teks itu lagi lalu pilih Pulihkan.", 13, Color(0.75, 0.8, 0.9)))
        var b1 := Button.new()
        b1.text = "Salin save ke clipboard"
        b1.custom_minimum_size = Vector2(0, 48)
        b1.pressed.connect(_export)
        _list.add_child(b1)
        var b2 := Button.new()
        b2.text = "Pulihkan dari clipboard (menimpa save sekarang!)" if not _confirm else "YAKIN? Ketuk lagi untuk menimpa save"
        b2.custom_minimum_size = Vector2(0, 48)
        b2.pressed.connect(_import)
        _list.add_child(b2)
        if _msg != "":
            _list.add_child(_label(_msg, 14, Color(1, 0.9, 0.5)))

    func _export() -> void:
        var t: String = Game.export_text()
        if t == "":
            _msg = "Gagal membaca save."
        else:
            DisplayServer.clipboard_set(t)
            _msg = "Tersalin (%d karakter). Tempel ke tempat aman." % t.length()
        _confirm = false
        _refresh()

    func _import() -> void:
        if not _confirm:
            _confirm = true
            _msg = ""
            _refresh()
            return
        _confirm = false
        if Game.import_text(DisplayServer.clipboard_get()):
            _msg = "Berhasil dipulihkan! Memuat ulang..."
            _refresh()
            hud.get_tree().reload_current_scene()
        else:
            _msg = "Clipboard tidak berisi save yang valid."
            _refresh()
