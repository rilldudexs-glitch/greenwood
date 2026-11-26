extends Control
# Menu lengkap: Tas (inventaris + perlengkapan), Status (naikkan stat), Crafting,
# Skin (lemari + ganti gender), Toko (beli/jual), Setelan (suara), dan layar hasil Gacha.

const Art = preload("res://scripts/art.gd")

const GEAR_CHEST_PRICE := 150
const FX_NAMES := {"none": "-", "crit": "Kritis +15%", "burn": "Membakar", "freeze": "Memperlambat", "shock": "Petir berantai", "poison": "Racun", "drain": "Sedot HP", "knock": "Hentakan +25%"}
const SHOP_STOCK := ["potion_hp", "potion_mp", "potion_hp2", "potion_mp2", "grilled", "steak", "omelet"]
const ORES := ["stone", "copper", "iron", "gold", "crystal", "ruby", "coal", "obsidian"]
const TAB_NAMES := {"bag": "Tas", "stats": "Status", "craft": "Crafting", "skin": "Skin", "shop": "Toko", "settings": "Setelan"}

var hud
var player
var is_open := false
var tab := "bag"
var params := {}
var _sel := ""
var _craft_cat := "weapon"
var _tabs: HBoxContainer
var _content: Control
var _title: Label


# ------------------------------------------------------------------ kelas bantu
class Cell extends Control:
    signal picked(id)
    var id := ""
    var count := 0
    var selected := false
    var tag := ""

    func _ready() -> void:
        custom_minimum_size = Vector2(50, 50)
        mouse_filter = Control.MOUSE_FILTER_STOP

    func _gui_input(e: InputEvent) -> void:
        if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
            picked.emit(id)

    func _draw() -> void:
        const A = preload("res://scripts/art.gd")
        var rar: Color = Color(0.3, 0.32, 0.4)
        var rr := -1
        if id != "":
            var inf_d: Dictionary = Items.info(id)
            rar = inf_d["color"].darkened(0.35)
            rr = int(inf_d.get("rarity", -1))
            if rr >= 0:
                rar = inf_d["color"]
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.11, 0.18, 0.95))
        if rr >= 0:
            draw_rect(Rect2(Vector2.ZERO, size), Color(rar.r, rar.g, rar.b, 0.14 + 0.03 * rr))
        draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.9, 0.4) if selected else rar, false, 2.0 + (1.0 if rr >= 4 else 0.0))
        if id != "":
            A.draw_icon(self, id, size / 2.0 + Vector2(0, -2), minf(size.x, size.y) * 0.8)
            if count > 1:
                var f: Font = ThemeDB.fallback_font
                draw_string_outline(f, Vector2(0, size.y - 3), str(count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 3, 12, 4, Color.BLACK)
                draw_string(f, Vector2(0, size.y - 3), str(count), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 3, 12, Color.WHITE)
        if tag != "":
            var f2: Font = ThemeDB.fallback_font
            draw_string_outline(f2, Vector2(3, 11), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color.BLACK)
            draw_string(f2, Vector2(3, 11), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 1, 0.6))


class Preview extends Control:
    var skin_id := "skin_default"
    var gender := "m"
    var scl := 3.0
    var t := randf() * 5.0
    var gear := {}
    var glow := true

    func _process(d: float) -> void:
        t += d
        queue_redraw()

    func _draw() -> void:
        const A = preload("res://scripts/art.gd")
        var sk: Dictionary = Items.skins[skin_id]
        if glow and int(sk["rarity"]) > 0:
            var rc: Color = Items.RAR_COL[int(sk["rarity"])]
            draw_circle(Vector2(size.x / 2.0, size.y * 0.55), size.x * 0.42, Color(rc.r, rc.g, rc.b, 0.16))
            draw_arc(Vector2(size.x / 2.0, size.y * 0.55), size.x * 0.42, 0.0, TAU, 32, Color(rc.r, rc.g, rc.b, 0.5), 2.0)
        var o := {"skin": sk, "gender": gender, "dir": 0, "flip": false, "t": t, "phase": t * 5.0, "moving": true,
            "scale": scl, "offset": Vector2(size.x / 2.0, size.y * 0.55)}
        for k in gear.keys():
            o[k] = gear[k]
        A.draw_human(self, o)


# ------------------------------------------------------------------ kerangka
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visible = false
    mouse_filter = Control.MOUSE_FILTER_STOP
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.6)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(dim)
    var pc := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.07, 0.08, 0.14, 0.97)
    sb.border_color = Color(1, 0.9, 0.5, 0.8)
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(10)
    sb.set_content_margin_all(10)
    pc.add_theme_stylebox_override("panel", sb)
    pc.set_anchors_preset(Control.PRESET_CENTER)
    pc.custom_minimum_size = Vector2(900, 500)
    pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
    pc.grow_vertical = Control.GROW_DIRECTION_BOTH
    add_child(pc)
    var vb := VBoxContainer.new()
    pc.add_child(vb)
    var top := HBoxContainer.new()
    vb.add_child(top)
    _title = Label.new()
    _title.add_theme_font_size_override("font_size", 18)
    _title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
    top.add_child(_title)
    _tabs = HBoxContainer.new()
    _tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _tabs.alignment = BoxContainer.ALIGNMENT_END
    top.add_child(_tabs)
    vb.add_child(HSeparator.new())
    _content = MarginContainer.new()
    _content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vb.add_child(_content)


func open(t: String, p: Dictionary = {}) -> void:
    tab = t
    params = p
    is_open = true
    visible = true
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _sel = ""
    Audio.sfx("select")
    _refresh()


func close() -> void:
    if not is_open:
        return
    is_open = false
    visible = false
    Game.p["hp"] = player.hp
    Game.p["mp"] = int(player.mp)
    Game.save()
    hud.menu_closed()


func _unhandled_input(e: InputEvent) -> void:
    if is_open and (e.is_action_pressed("pause") or (e.is_action_pressed("inventory") and tab != "gacha")):
        close()
        get_viewport().set_input_as_handled()


func _lbl(text: String, size: int = 14, col: Color = Color.WHITE) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", col)
    return l


func _btn(text: String, cb: Callable, disabled: bool = false) -> Button:
    var b := Button.new()
    b.text = text
    b.disabled = disabled
    b.pressed.connect(cb)
    return b


func _clear(n: Node) -> void:
    for c in n.get_children():
        c.queue_free()


func _scroll(inner: Control) -> ScrollContainer:
    var sc := ScrollContainer.new()
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(inner)
    return sc


func _refresh() -> void:
    _clear(_tabs)
    _clear(_content)
    if tab == "gacha":
        _title.text = "Hasil Gacha"
        _build_gacha()
        return
    _title.text = "%s   |   Koin %d   Gem %d" % [TAB_NAMES[tab], int(Game.p["coins"]), int(Game.p["gems"])]
    var names: Array = ["bag", "stats", "craft", "skin", "settings"]
    if tab == "shop":
        names = ["shop"]
    for n in names:
        _tabs.add_child(_btn(TAB_NAMES[n], _goto.bind(n), n == tab))
    _tabs.add_child(_btn("Tutup", close))
    match tab:
        "bag":
            _build_bag()
        "stats":
            _build_stats()
        "craft":
            _build_craft()
        "skin":
            _build_skin()
        "shop":
            _build_shop()
        "settings":
            _build_settings()


func _goto(t: String) -> void:
    tab = t
    _sel = ""
    Audio.sfx("select")
    _refresh()


# ------------------------------------------------------------------ TAS
func _inv_ids() -> Array:
    var ids: Array = []
    for id in Game.p["inv"].keys():
        if int(Game.p["inv"][id]) > 0:
            ids.append(String(id))
    ids.sort_custom(_cmp_items)
    return ids


const TYPE_ORDER := {"sword": 0, "staff": 1, "armor": 2, "potion": 3, "food": 4, "fish": 5, "mat": 6}


func _cmp_items(a, b) -> bool:
    var ta: int = int(TYPE_ORDER.get(String(Items.info(a)["type"]), 9))
    var tb: int = int(TYPE_ORDER.get(String(Items.info(b)["type"]), 9))
    if ta != tb:
        return ta < tb
    var ra: int = int(Items.info(a).get("rarity", -1))
    var rb: int = int(Items.info(b).get("rarity", -1))
    if ra != rb:
        return ra > rb
    return Items.item_name(a) < Items.item_name(b)


func _is_equipped(id: String) -> bool:
    return Game.p["sword"] == id or Game.p["staff"] == id or Game.p["equip"].values().has(id)


func _build_bag() -> void:
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 12)
    _content.add_child(hb)
    var left := VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hb.add_child(left)
    left.add_child(_lbl("Perlengkapan (ketuk untuk lihat)", 13, Color(0.8, 0.85, 1)))
    var er := HBoxContainer.new()
    left.add_child(er)
    var slots := [["sword", Game.p["sword"]], ["staff", Game.p["staff"]]]
    for s in Items.SLOTS:
        slots.append([s, Game.p["equip"][s]])
    for sl in slots:
        var c := Cell.new()
        c.id = String(sl[1])
        c.selected = c.id != "" and c.id == _sel
        c.picked.connect(_select)
        er.add_child(c)
    left.add_child(_lbl("Senjata • Tongkat • Zirah • Legging • Sepatu • Sarung • Perisai • Beliung", 10, Color(0.6, 0.65, 0.8)))
    left.add_child(HSeparator.new())
    left.add_child(_lbl("Isi tas", 13, Color(0.8, 0.85, 1)))
    var grid := GridContainer.new()
    grid.columns = 8
    grid.add_theme_constant_override("h_separation", 4)
    grid.add_theme_constant_override("v_separation", 4)
    for id in _inv_ids():
        var c2 := Cell.new()
        c2.id = id
        c2.count = int(Game.p["inv"][id])
        c2.selected = id == _sel
        if Items.is_equipment(id) and _is_equipped(id):
            c2.tag = "E"
        c2.picked.connect(_select)
        grid.add_child(c2)
    left.add_child(_scroll(grid))
    # detail
    var right := VBoxContainer.new()
    right.custom_minimum_size = Vector2(270, 0)
    hb.add_child(right)
    _build_detail(right)


func _select(id: String) -> void:
    _sel = id
    Audio.sfx("blip")
    _refresh()


func _item_stats_text(id: String) -> String:
    var d := Items.info(id)
    match String(d["type"]):
        "sword":
            var st: String = "Serangan dasar %d\nEfek: %s\nKecepatan x%.2f" % [int(d["dmg"]), FX_NAMES.get(d["fx"], "-"), 1.0 / float(d["cd"])]
            if not d.has("wtype"):
                st = "Serangan dasar %d\nJangkauan %d\nEfek: %s\nKecepatan x%.2f" % [int(d["dmg"]), int(d["reach"]), FX_NAMES.get(d["fx"], "-"), 1.0 / float(d["cd"])]
            else:
                st += "\n" + String(d["desc"])
            return st
        "staff":
            return "Sihir dasar %d\nBiaya MP %d\n%s" % [int(d["dmg"]), int(d["cost"]), d["desc"]]
    return String(d["desc"])


# Bandingkan item terpilih dengan yang sedang dipakai: [[teks, warna], ...]
func _compare_lines(id: String) -> Array:
    var out: Array = []
    if not Items.is_equipment(id) or _is_equipped(id):
        return out
    var d := Items.info(id)
    var cur := ""
    var keys: Array = []
    match String(d["type"]):
        "sword":
            cur = String(Game.p["sword"])
            keys = [["dmg", "Serangan"]]
        "staff":
            cur = String(Game.p["staff"])
            keys = [["dmg", "Sihir"]]
        "armor":
            cur = String(Game.p["equip"].get(String(d.get("slot", "")), ""))
            keys = [["def", "DEF"], ["hp", "HP"], ["atk", "ATK"]]
    if cur == "":
        out.append(["Slot kosong: langsung lebih baik", Color(0.5, 1, 0.55)])
        return out
    var c := Items.info(cur)
    for k in keys:
        var diff: float = float(d.get(k[0], 0)) - float(c.get(k[0], 0))
        if absf(diff) < 0.001:
            continue
        out.append(["%s %s%d  (dipakai: %s)" % [String(k[1]), "▲ +" if diff > 0.0 else "▼ ", int(diff), String(c.get("name", "?"))], Color(0.5, 1, 0.55) if diff > 0.0 else Color(1, 0.5, 0.5)])
    return out


func _build_detail(box: VBoxContainer) -> void:
    if _sel == "":
        box.add_child(_lbl("Pilih item untuk melihat detail.", 13, Color(0.7, 0.75, 0.9)))
        box.add_child(_lbl("\nPotion/makanan bisa dipakai.\nSenjata & armor bisa dipasang.\nBahan dipakai di Crafting.", 12, Color(0.6, 0.65, 0.8)))
        return
    var d := Items.info(_sel)
    box.add_child(_lbl(String(d["name"]), 18, d["color"]))
    if d.has("rarity"):
        box.add_child(_lbl("Rarity: %s" % String(d["rname"]), 12, d["color"]))
    var tn := {"sword": "Senjata", "staff": "Tongkat", "armor": "Armor", "potion": "Ramuan", "food": "Makanan", "fish": "Ikan", "mat": "Bahan"}
    box.add_child(_lbl(String(tn.get(String(d["type"]), "")), 12, Color(0.7, 0.75, 0.9)))
    var l := _lbl(_item_stats_text(_sel), 13)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(l)
    for cl in _compare_lines(_sel):
        var cl_l := _lbl(String(cl[0]), 12, cl[1])
        cl_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(cl_l)
    if String(d["type"]) != "armor" and String(d["desc"]) != "" and not Items.is_equipment(_sel):
        pass
    elif String(d["type"]) == "armor":
        var l2 := _lbl(String(d["desc"]), 13, Color(0.7, 1, 0.8))
        l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(l2)
    box.add_child(_lbl("Nilai jual: %d koin" % int(d["price"]), 11, Color(1, 0.9, 0.5)))
    var row := HBoxContainer.new()
    box.add_child(row)
    if Items.is_usable(_sel):
        row.add_child(_btn("Pakai", _use_item.bind(_sel), player.count(_sel) <= 0))
    elif Items.is_equipment(_sel):
        if _is_equipped(_sel):
            if String(d["type"]) == "armor":
                row.add_child(_btn("Lepas", _unequip.bind(String(d["slot"]))))
            else:
                row.add_child(_lbl("Terpasang", 13, Color(0.5, 1, 0.5)))
        else:
            row.add_child(_btn("Pasang", _equip.bind(_sel)))


func _use_item(id: String) -> void:
    if Items.use_item(id, player):
        player.remove_item(id)
        Audio.sfx("potion")
        if player.count(id) <= 0:
            _sel = ""
    else:
        Audio.sfx("nope")
        hud.toast("HP/MP sudah penuh")
    _refresh()


func _equip(id: String) -> void:
    player.equip_item(id)
    _refresh()


func _unequip(slot: String) -> void:
    player.unequip(slot)
    _refresh()


# ------------------------------------------------------------------ STATUS
func _build_stats() -> void:
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 16)
    _content.add_child(hb)
    var left := VBoxContainer.new()
    left.custom_minimum_size = Vector2(190, 0)
    hb.add_child(left)
    var pv := Preview.new()
    pv.custom_minimum_size = Vector2(190, 150)
    pv.skin_id = String(Game.p["skin"])
    pv.gender = String(Game.p["gender"])
    pv.gear = _gear_colors()
    left.add_child(pv)
    left.add_child(_lbl(String(Game.p["name"]), 18, Color(1, 0.9, 0.5)))
    var lv: int = int(Game.p["level"])
    left.add_child(_lbl("Level %d" % lv, 14))
    left.add_child(_lbl("XP %d / %d" % [int(Game.p["xp"]), Game.xp_needed(lv)], 12, Color(0.7, 1, 0.7)))
    var pts: int = int(Game.p["points"])
    left.add_child(_lbl("Poin stat: %d" % pts, 16, Color(1, 0.85, 0.3) if pts > 0 else Color(0.7, 0.7, 0.8)))
    left.add_child(_lbl("+%d poin tiap naik level" % Game.POINTS_PER_LEVEL, 11, Color(0.6, 0.65, 0.8)))
    var mid := VBoxContainer.new()
    mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hb.add_child(mid)
    for k in Game.STAT_KEYS:
        var row := HBoxContainer.new()
        mid.add_child(row)
        var nm := _lbl(Game.STAT_NAMES[k], 18, Color(1, 0.9, 0.6))
        nm.custom_minimum_size = Vector2(60, 0)
        row.add_child(nm)
        var v := _lbl(str(player.stat(k)), 18)
        v.custom_minimum_size = Vector2(50, 0)
        row.add_child(v)
        row.add_child(_btn("+", _add_stat.bind(k), pts <= 0))
        var d := _lbl("  " + String(Game.STAT_LONG[k]), 11, Color(0.65, 0.7, 0.85))
        row.add_child(d)
    mid.add_child(HSeparator.new())
    var info := "HP maks   %d\nMP maks   %d\nSerangan pedang   %d\nSerangan sihir   %d\nPertahanan   %.1f\nKecepatan gerak   %d\nJeda serang   %.2f dtk\nPeluang kritis   %d%%\nTangkis perisai   %d%%\nRegen MP   %.1f/dtk" % [
        player.max_hp, player.max_mp, player.melee_damage(), player.magic_damage(), player.defense(),
        int(player.move_speed()), player.attack_cooldown(), int(player.crit_chance() * 100.0), int(player.block_chance() * 100.0), player.mp_regen()]
    mid.add_child(_lbl(info, 13, Color(0.85, 0.9, 1)))


func _add_stat(k: String) -> void:
    player.add_stat(k)
    _refresh()


func _gear_colors() -> Dictionary:
    var o: Dictionary = player.look_dict()
    o.erase("skin")
    o.erase("gender")
    return o


# ------------------------------------------------------------------ CRAFTING
func _build_craft() -> void:
    var vb := VBoxContainer.new()
    _content.add_child(vb)
    var cats := HBoxContainer.new()
    vb.add_child(cats)
    var cn := {"weapon": "Senjata", "armor": "Armor", "potion": "Ramuan", "food": "Makanan"}
    for c in cn.keys():
        cats.add_child(_btn(String(cn[c]), _set_cat.bind(String(c)), c == _craft_cat))
    cats.add_child(_lbl("   Bahan didapat dari menebang, menambang, memancing & monster.", 11, Color(0.6, 0.65, 0.8)))
    var list := VBoxContainer.new()
    list.add_theme_constant_override("separation", 4)
    for i in Items.recipes.size():
        var r: Dictionary = Items.recipes[i]
        if String(r["cat"]) != _craft_cat:
            continue
        list.add_child(_craft_row(i, r))
    vb.add_child(_scroll(list))


func _set_cat(c: String) -> void:
    _craft_cat = c
    _refresh()


func _craft_row(i: int, r: Dictionary) -> Control:
    var out: String = String(r["out"])
    var d := Items.info(out)
    var pc := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.11, 0.12, 0.2, 0.9)
    sb.set_corner_radius_all(6)
    sb.set_content_margin_all(5)
    pc.add_theme_stylebox_override("panel", sb)
    var hb := HBoxContainer.new()
    hb.add_theme_constant_override("separation", 10)
    pc.add_child(hb)
    var cell := Cell.new()
    cell.id = out
    cell.count = int(r["n"])
    hb.add_child(cell)
    var mid := VBoxContainer.new()
    mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hb.add_child(mid)
    mid.add_child(_lbl(String(d["name"]), 15, d["color"]))
    var desc := String(d["desc"])
    if String(d["type"]) == "sword":
        desc = "Serangan %d • %s" % [int(d["dmg"]), FX_NAMES[d["fx"]]]
    mid.add_child(_lbl(desc, 11, Color(0.7, 0.75, 0.9)))
    var mats := HBoxContainer.new()
    mats.add_theme_constant_override("separation", 12)
    mid.add_child(mats)
    var can := true
    var mdict: Dictionary = r["mats"]
    for m in mdict.keys():
        var have: int = player.count(String(m))
        var need: int = int(mdict[m])
        var ok: bool = have >= need
        if not ok:
            can = false
        mats.add_child(_lbl("%s %d/%d" % [Items.item_name(String(m)), have, need], 12, Color(0.6, 1, 0.6) if ok else Color(1, 0.5, 0.5)))
    var coins: int = int(r["coins"])
    if coins > 0:
        var okc: bool = int(Game.p["coins"]) >= coins
        if not okc:
            can = false
        mats.add_child(_lbl("%d koin" % coins, 12, Color(1, 0.9, 0.4) if okc else Color(1, 0.5, 0.5)))
    var owned: bool = Items.is_equipment(out) and player.owns(out)
    var b := _btn("Dimiliki" if owned else "Buat", _craft.bind(i), owned or not can)
    b.custom_minimum_size = Vector2(90, 40)
    hb.add_child(b)
    return pc


func _craft(i: int) -> void:
    var r: Dictionary = Items.recipes[i]
    var mdict: Dictionary = r["mats"]
    for m in mdict.keys():
        if player.count(String(m)) < int(mdict[m]):
            Audio.sfx("nope")
            return
    if int(Game.p["coins"]) < int(r["coins"]):
        Audio.sfx("nope")
        return
    for m in mdict.keys():
        player.remove_item(String(m), int(mdict[m]))
    Game.p["coins"] = int(Game.p["coins"]) - int(r["coins"])
    player.add_item(String(r["out"]), int(r["n"]))
    Audio.sfx("craft")
    hud.toast("Berhasil membuat %s!" % Items.item_name(String(r["out"])))
    var t: String = String(Items.info(String(r["out"]))["type"])
    if t == "sword" or t == "staff" or t == "armor":
        player.equip_item(String(r["out"]))
    _refresh()


# ------------------------------------------------------------------ SKIN
func _build_skin() -> void:
    var vb := VBoxContainer.new()
    _content.add_child(vb)
    var gr := HBoxContainer.new()
    vb.add_child(gr)
    gr.add_child(_lbl("Karakter: ", 14))
    gr.add_child(_btn("Laki-laki", _set_gender.bind("m"), Game.p["gender"] == "m"))
    gr.add_child(_btn("Perempuan", _set_gender.bind("f"), Game.p["gender"] == "f"))
    gr.add_child(_lbl("    Dapatkan skin baru dari Madam Gem (gacha) di desa.", 11, Color(0.6, 0.65, 0.8)))
    var grid := GridContainer.new()
    grid.columns = 5
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    for id in Items.skin_order:
        grid.add_child(_skin_card(String(id)))
    vb.add_child(_scroll(grid))


func _skin_card(id: String) -> Control:
    var sk: Dictionary = Items.skins[id]
    var owned: bool = Game.p["skins"].has(id)
    var pc := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    var rc: Color = Items.RAR_COL[int(sk["rarity"])]
    sb.bg_color = Color(0.11, 0.12, 0.2, 0.9)
    sb.border_color = rc if Game.p["skin"] != id else Color(0.5, 1, 0.5)
    sb.set_border_width_all(2)
    sb.set_corner_radius_all(6)
    sb.set_content_margin_all(4)
    pc.add_theme_stylebox_override("panel", sb)
    var v := VBoxContainer.new()
    pc.add_child(v)
    var pv := Preview.new()
    pv.custom_minimum_size = Vector2(150, 118)
    pv.skin_id = id
    pv.gender = String(Game.p["gender"])
    pv.scl = 3.0
    if not owned:
        pv.modulate = Color(0.35, 0.35, 0.4)
    v.add_child(pv)
    v.add_child(_lbl(String(sk["name"]), 13, rc))
    var stars := "★".repeat(int(sk["rarity"])) if int(sk["rarity"]) > 0 else "Dasar"
    v.add_child(_lbl("%s  %s" % [stars, String(sk["theme"]).capitalize()], 10, Color(0.7, 0.75, 0.9)))
    var b: Button
    if Game.p["skin"] == id:
        b = _btn("Dipakai", _noop, true)
    elif owned:
        b = _btn("Pakai", _wear.bind(id))
    else:
        b = _btn("Terkunci", _noop, true)
    v.add_child(b)
    return pc


func _noop() -> void:
    pass


func _wear(id: String) -> void:
    Game.p["skin"] = id
    Audio.sfx("select")
    _refresh()


func _set_gender(g: String) -> void:
    Game.p["gender"] = g
    Audio.sfx("select")
    _refresh()


# ------------------------------------------------------------------ TOKO
func _build_shop() -> void:
    var vb := VBoxContainer.new()
    _content.add_child(vb)
    var mode: String = String(params.get("mode", "buy"))
    var mult: float = float(params.get("mult", 1.0))
    var filter: String = String(params.get("filter", ""))
    vb.add_child(_lbl(String(params.get("title", "Beli ramuan & makanan")) if mode == "buy" else "Jual barang (harga x%.2f)" % mult, 15, Color(1, 0.9, 0.5)))
    var list := VBoxContainer.new()
    list.add_theme_constant_override("separation", 4)
    var ids: Array = params.get("stock", SHOP_STOCK) if mode == "buy" else _sellable(filter)
    if ids.is_empty():
        list.add_child(_lbl("Tidak ada barang yang bisa dijual.", 13, Color(0.7, 0.75, 0.9)))
    if mode == "buy":
        # Peti perlengkapan: isi acak senjata/armor/beliung dengan rarity Common sampai Myth
        var gb := HBoxContainer.new()
        gb.add_theme_constant_override("separation", 10)
        var gl := _lbl("Peti Perlengkapan Acak\nIsi: senjata, armor, atau beliung (Common - Myth)", 12, Color(1.0, 0.85, 0.5))
        gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        gb.add_child(gl)
        gb.add_child(_lbl("%d koin" % GEAR_CHEST_PRICE, 14, Color(1, 0.9, 0.4)))
        gb.add_child(_btn("Buka", _buy_gear, int(Game.p["coins"]) < GEAR_CHEST_PRICE))
        list.add_child(gb)
        list.add_child(HSeparator.new())
    for id in ids:
        var d := Items.info(String(id))
        var hb := HBoxContainer.new()
        hb.add_theme_constant_override("separation", 10)
        var c := Cell.new()
        c.id = String(id)
        c.count = player.count(String(id)) if mode == "sell" else 0
        hb.add_child(c)
        var nm := _lbl("%s\n%s" % [d["name"], d["desc"]], 12)
        nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hb.add_child(nm)
        if mode == "buy":
            var price: int = int(d["price"]) * 3
            hb.add_child(_lbl("%d koin" % price, 14, Color(1, 0.9, 0.4)))
            hb.add_child(_btn("Beli", _buy.bind(String(id), price), int(Game.p["coins"]) < price))
        else:
            var sp: int = maxi(int(float(d["price"]) * mult), 1)
            hb.add_child(_lbl("%d koin" % sp, 14, Color(1, 0.9, 0.4)))
            hb.add_child(_btn("Jual 1", _sell.bind(String(id), sp, 1)))
            hb.add_child(_btn("Semua", _sell.bind(String(id), sp, 9999)))
        list.add_child(hb)
    vb.add_child(_scroll(list))


func _sellable(filter: String) -> Array:
    var out: Array = []
    for id in _inv_ids():
        var t: String = String(Items.info(id)["type"])
        if Items.is_equipment(id) and not (Items.info(id).has("rarity") and not _is_equipped(id)):
            continue
        match filter:
            "fish":
                if t != "fish":
                    continue
            "ore":
                if not ORES.has(id):
                    continue
            "log":
                if id != "log":
                    continue
        out.append(id)
    return out


func _buy(id: String, price: int) -> void:
    if int(Game.p["coins"]) < price:
        Audio.sfx("nope")
        return
    Game.p["coins"] = int(Game.p["coins"]) - price
    player.add_item(id)
    Audio.sfx("buy")
    _refresh()


func _buy_gear() -> void:
    if int(Game.p["coins"]) < GEAR_CHEST_PRICE:
        Audio.sfx("nope")
        return
    Game.p["coins"] = int(Game.p["coins"]) - GEAR_CHEST_PRICE
    var id: String = Gear.roll_gear(randi_range(1, 4), player.stat("luk"), 0)
    player.add_item(id)
    Audio.sfx("buy")
    var d := Items.info(id)
    if player.hud:
        player.hud.toast("Dapat: %s [%s]" % [d["name"], d["rname"]])
    _refresh()


func _sell(id: String, price: int, n: int) -> void:
    var amt: int = mini(n, player.count(id))
    if amt <= 0:
        return
    player.remove_item(id, amt)
    Game.p["coins"] = int(Game.p["coins"]) + price * amt
    Audio.sfx("coin")
    _refresh()


# ------------------------------------------------------------------ SETELAN
func _build_settings() -> void:
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 14)
    _content.add_child(vb)
    vb.add_child(_slider_row("Musik (BGM)", "bgm"))
    vb.add_child(_slider_row("Efek suara (SFX)", "sfx"))
    var cb := CheckBox.new()
    cb.text = "Bisukan semua suara"
    cb.button_pressed = bool(Game.settings["muted"])
    cb.toggled.connect(_set_muted)
    vb.add_child(cb)
    var cf := CheckBox.new()
    cf.text = "Tampilkan FPS"
    cf.button_pressed = bool(Game.settings["show_fps"])
    cf.toggled.connect(_set_fps)
    vb.add_child(cf)
    var cl := CheckBox.new()
    cl.text = "Mode hemat performa (untuk HP kentang)"
    cl.button_pressed = bool(Game.settings["low_mode"])
    cl.toggled.connect(Perf.set_low_mode)
    vb.add_child(cl)
    var ch := CheckBox.new()
    ch.text = "Getar (haptic) saat kena hit / level up"
    ch.button_pressed = bool(Game.settings["haptic"])
    ch.toggled.connect(Game.set_haptic)
    vb.add_child(ch)
    var cu := CheckBox.new()
    cu.text = "Ultra hemat (efek minimal, paling ringan)"
    cu.button_pressed = bool(Game.settings["ultra_mode"])
    cu.toggled.connect(Perf.set_ultra_mode)
    vb.add_child(cu)
    var c3 := CheckBox.new()
    c3.text = "Batasi 30 FPS (hemat baterai & tidak panas)"
    c3.button_pressed = bool(Game.settings["cap30"])
    c3.toggled.connect(Perf.set_cap30)
    vb.add_child(c3)
    vb.add_child(HSeparator.new())
    var row := HBoxContainer.new()
    vb.add_child(row)
    row.add_child(_btn("Lanjutkan bermain", close))
    row.add_child(_btn("Simpan game", _save_game))
    row.add_child(_btn("Keluar ke menu utama", _to_title))
    vb.add_child(_lbl("\nKontrol: WASD/panah jalan • J/Spasi serang • K sihir • E aksi (bicara/tebang/tambang/pancing) • I tas • 1/2 ramuan • Esc menu", 11, Color(0.65, 0.7, 0.85)))


func _slider_row(label: String, key: String) -> Control:
    var hb := HBoxContainer.new()
    var l := _lbl(label, 15)
    l.custom_minimum_size = Vector2(200, 0)
    hb.add_child(l)
    var s := HSlider.new()
    s.min_value = 0.0
    s.max_value = 1.0
    s.step = 0.05
    s.value = float(Game.settings[key])
    s.custom_minimum_size = Vector2(380, 24)
    s.value_changed.connect(_set_vol.bind(key))
    hb.add_child(s)
    return hb


func _set_vol(v: float, key: String) -> void:
    Game.settings[key] = v
    Game.save_settings()
    Audio.apply_settings()
    if key == "sfx":
        Audio.sfx("coin")


func _set_fps(on: bool) -> void:
    Game.settings["show_fps"] = on
    Game.save_settings()


func _set_muted(m: bool) -> void:
    Game.settings["muted"] = m
    Game.save_settings()
    Audio.apply_settings()


func _save_game() -> void:
    Game.p["hp"] = player.hp
    Game.p["mp"] = int(player.mp)
    Game.p["pos"] = [player.global_position.x, player.global_position.y]
    Game.save()
    hud.toast("Game tersimpan")
    Audio.sfx("checkpoint")


func _to_title() -> void:
    _save_game()
    is_open = false
    visible = false
    get_tree().paused = false
    Net.leave()
    Game.in_game = false
    get_tree().change_scene_to_file("res://scenes/title.tscn")


# ------------------------------------------------------------------ GACHA
func gacha(n: int) -> void:
    var cost: int = Game.GACHA_COST * n if n == 1 else Game.GACHA_COST * 9
    if int(Game.p["gems"]) < cost:
        Audio.sfx("nope")
        hud.toast("Gem tidak cukup (butuh %d)" % cost)
        return
    Game.p["gems"] = int(Game.p["gems"]) - cost
    var results: Array = []
    for i in n:
        var id: String = Items.gacha_roll(player.stat("luk"))
        var is_new: bool = not Game.p["skins"].has(id)
        var dg := 0
        if is_new:
            Game.p["skins"].append(id)
        else:
            dg = Items.dupe_gems(int(Items.skins[id]["rarity"]))
            Game.p["gems"] = int(Game.p["gems"]) + dg
        results.append({"id": id, "new": is_new, "gems": dg})
    Game.p["pulls"] = int(Game.p["pulls"]) + n
    Game.save()
    var best := 0
    for r in results:
        best = maxi(best, int(Items.skins[r["id"]]["rarity"]))
    Audio.sfx("win" if best >= 2 else "levelup")
    open("gacha", {"results": results})


func _build_gacha() -> void:
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 8)
    _content.add_child(vb)
    var results: Array = params.get("results", [])
    var grid := GridContainer.new()
    grid.columns = 5 if results.size() > 1 else 1
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    var gc := CenterContainer.new()
    gc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    gc.add_child(grid)
    vb.add_child(gc)
    for r in results:
        var sk: Dictionary = Items.skins[r["id"]]
        var rc: Color = Items.RAR_COL[int(sk["rarity"])]
        var pc := PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(rc.r * 0.25, rc.g * 0.25, rc.b * 0.25, 0.95)
        sb.border_color = rc
        sb.set_border_width_all(3)
        sb.set_corner_radius_all(8)
        sb.set_content_margin_all(4)
        pc.add_theme_stylebox_override("panel", sb)
        var v := VBoxContainer.new()
        pc.add_child(v)
        var pv := Preview.new()
        var big: bool = results.size() == 1
        pv.custom_minimum_size = Vector2(190, 170) if big else Vector2(150, 110)
        pv.scl = 4.5 if big else 3.0
        pv.skin_id = String(r["id"])
        pv.gender = String(Game.p["gender"])
        v.add_child(pv)
        v.add_child(_lbl(String(sk["name"]), 14, rc))
        v.add_child(_lbl("★".repeat(int(sk["rarity"])) + (" BARU!" if bool(r["new"]) else "  (duplikat +%d gem)" % int(r["gems"])), 11, Color(1, 0.95, 0.5) if bool(r["new"]) else Color(0.7, 0.8, 0.9)))
        grid.add_child(pc)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    vb.add_child(row)
    row.add_child(_lbl("Gem tersisa: %d     " % int(Game.p["gems"]), 14, Color(0.6, 0.95, 1)))
    row.add_child(_btn("Pakai di lemari skin", _goto.bind("skin")))
    row.add_child(_btn("OK", close))
