extends Control
# Menu awal bergaya Greenwood (bulan, reruntuhan, tombol merah tua): New Game / Continue / Settings /
# Credits / Exit, serta pembuatan karakter (nama + laki-laki atau perempuan).
# Latar & tombol dibuat dari gambar di assets/ui/kit/ (title_*.png).

const Jobs = preload("res://scripts/jobs.gd")
const MenuScript = preload("res://scripts/menu.gd")
const UiKit = preload("res://scripts/ui_kit.gd")
const S := 1280.0 / 1672.0   # skala PNG latar terhadap gambar asli 1672x941
# [label, ikon, tengah x, tengah y] dalam koordinat gambar asli
const SLOTS := [
    ["New Game", "new", 326.0, 421.5],
    ["Continue", "cont", 326.0, 507.0],
    ["Settings", "sett", 326.0, 586.0],
    ["Credits", "cred", 326.0, 661.5],
    ["Exit", "exit", 326.0, 739.5],
]

var _bg_rect: TextureRect
var _edge_l: TextureRect
var _edge_r: TextureRect
var _main_layer: Control
var _dim: ColorRect
var _panel: PanelContainer
var _btns: Array = []
var _sel := 0
var _cur := "main"
var _create_box: VBoxContainer
var _job_box: VBoxContainer
var _job := "knight"
var _job_desc: Label
var _job_btns := {}
var _settings_box: VBoxContainer
var _credits_box: VBoxContainer
var _mp_box: VBoxContainer
var _mp_name: LineEdit
var _mp_ip: LineEdit
var _mp_status: Label
var _mp_go: Button
var _name_edit: LineEdit
var _gender := "m"
var _greet: Label


class MenuBtn extends Control:
    signal pressed
    signal hovered
    var label := ""
    var icon: Texture2D
    var sprite_n: Texture2D
    var sprite_s: Texture2D
    var selected := false
    var enabled := true
    var slot := 0
    var k := 1.0
    var _down := false

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP
        texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        mouse_entered.connect(func(): hovered.emit())

    func _gui_input(e: InputEvent) -> void:
        if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
            if e.pressed:
                _down = true
                hovered.emit()
                queue_redraw()
            else:
                var was: bool = _down
                _down = false
                queue_redraw()
                if was and enabled and Rect2(Vector2.ZERO, size).has_point(e.position):
                    pressed.emit()

    func _draw() -> void:
        var a: float = 1.0 if enabled else 0.4
        var c: Vector2 = size / 2.0
        var sp: Texture2D = sprite_s if selected else sprite_n
        if sp != null:
            var ssz: Vector2 = sp.get_size() * k
            if selected:
                for i in 3:
                    var g: float = float(3 - i) * 3.0
                    draw_rect(Rect2(c - ssz / 2.0 - Vector2(g, g), ssz + Vector2(g, g) * 2.0), Color(1.0, 0.1, 0.2, 0.05), true)
            var tint := Color(0.8, 0.8, 0.85, a) if _down else Color(1, 1, 1, a)
            draw_texture_rect(sp, Rect2(c - ssz / 2.0, ssz), false, tint)
        else:
            draw_rect(Rect2(Vector2.ZERO, size), Color(0.45, 0.08, 0.15) if selected else Color(0.09, 0.08, 0.14), true)
            draw_rect(Rect2(Vector2.ZERO, size), Color(0.9, 0.25, 0.3), false, 2.0)
        if icon != null:
            var isz: Vector2 = icon.get_size() * k
            draw_texture_rect(icon, Rect2(Vector2(62.8 * k, c.y) - isz / 2.0, isz), false, Color(1, 1, 1, a))
        var f: Font = ThemeDB.fallback_font
        var fs: int = int(round(20.0 * k))
        var tp := Vector2(126.0 * k, c.y + float(fs) * 0.36)
        draw_string_outline(f, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.06, 0.03, 0.08, a))
        draw_string(f, tp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
        if selected:
            var ax: float = -26.0 * k
            draw_colored_polygon(PackedVector2Array([Vector2(ax, c.y - 9.0 * k), Vector2(ax + 16.0 * k, c.y), Vector2(ax, c.y + 9.0 * k)]), Color(1, 0.92, 0.92))


func _fit() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    position = Vector2.ZERO
    size = get_viewport_rect().size
    _layout()


func _ready() -> void:
    Audio.music("title")
    theme = UiKit.make_theme()
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var base := ColorRect.new()
    base.color = Color(0.03, 0.03, 0.06)
    base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    base.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(base)
    var bgt: Texture2D = UiKit.tex("title_bg")
    _edge_l = _edge(bgt, 0)
    _edge_r = _edge(bgt, 1)
    _bg_rect = TextureRect.new()
    _bg_rect.texture = bgt
    _bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
    _bg_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    _bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_bg_rect)
    _main_layer = Control.new()
    _main_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _main_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_main_layer)
    _build_main()
    _build_mp_button()
    _dim = ColorRect.new()
    _dim.color = Color(0, 0, 0, 0.62)
    _dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _dim.mouse_filter = Control.MOUSE_FILTER_STOP
    _dim.visible = false
    add_child(_dim)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(center)
    _panel = PanelContainer.new()
    var psb: StyleBoxTexture = UiKit.nine("ui_panel", 16, 36, 16, 16)
    if psb != null:
        psb.content_margin_left = 32
        psb.content_margin_right = 32
        psb.content_margin_top = 14
        psb.content_margin_bottom = 26
        _panel.add_theme_stylebox_override("panel", psb)
    else:
        _panel.add_theme_stylebox_override("panel", UiKit.flat(Color(0.07, 0.06, 0.11, 0.96), UiKit.CRIMSON))
    _panel.custom_minimum_size = Vector2(440, 0)
    _panel.visible = false
    center.add_child(_panel)
    var holder := VBoxContainer.new()
    holder.add_theme_constant_override("separation", 8)
    _panel.add_child(holder)
    _greet = Label.new()
    _greet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _greet.add_theme_font_size_override("font_size", 20)
    _greet.add_theme_color_override("font_color", Color(1, 0.9, 0.75))
    holder.add_child(_greet)
    _create_box = VBoxContainer.new()
    _create_box.add_theme_constant_override("separation", 8)
    holder.add_child(_create_box)
    _job_box = VBoxContainer.new()
    _job_box.add_theme_constant_override("separation", 6)
    holder.add_child(_job_box)
    _settings_box = VBoxContainer.new()
    _settings_box.add_theme_constant_override("separation", 8)
    holder.add_child(_settings_box)
    _credits_box = VBoxContainer.new()
    _credits_box.add_theme_constant_override("separation", 6)
    holder.add_child(_credits_box)
    _mp_box = VBoxContainer.new()
    _mp_box.add_theme_constant_override("separation", 8)
    holder.add_child(_mp_box)
    _build_mp()
    _build_create()
    _build_job()
    _build_settings()
    _build_credits()
    get_viewport().size_changed.connect(_layout)
    _fit.call_deferred()
    _layout()
    _show("main")


func _edge(bgt: Texture2D, side: int) -> TextureRect:
    var r := TextureRect.new()
    if bgt != null:
        var at := AtlasTexture.new()
        at.atlas = bgt
        var rx: int = 0 if side == 0 else bgt.get_width() - 2
        at.region = Rect2(rx, 0, 2, bgt.get_height())
        r.texture = at
    r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    r.stretch_mode = TextureRect.STRETCH_SCALE
    r.modulate = Color(0.6, 0.6, 0.6)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(r)
    return r


# Latar diskalakan sesuai tinggi layar, tombol mengikuti letaknya di gambar.
func _layout() -> void:
    if _bg_rect == null:
        return
    var vp: Vector2 = get_viewport_rect().size
    var k: float = vp.y / 720.0
    var w: float = 1280.0 * k
    var x0: float = (vp.x - w) / 2.0
    _bg_rect.position = Vector2(x0, 0)
    _bg_rect.size = Vector2(w, vp.y)
    _edge_l.position = Vector2.ZERO
    _edge_l.size = Vector2(maxf(x0, 0.0), vp.y)
    _edge_r.position = Vector2(x0 + w, 0)
    _edge_r.size = Vector2(maxf(vp.x - x0 - w, 0.0), vp.y)
    for b in _btns:
        var mb: MenuBtn = b
        var bs := Vector2(318, 59)
        if mb.sprite_n != null:
            bs = mb.sprite_n.get_size()
        var cx: float = x0 + float(SLOTS[mb.slot][2]) * S * k
        var cy: float = float(SLOTS[mb.slot][3]) * S * k
        mb.k = k
        mb.size = bs * k
        mb.position = Vector2(cx, cy) - mb.size / 2.0
        mb.queue_redraw()


func _build_main() -> void:
    var sn: Texture2D = UiKit.tex("title_btn")
    var ss: Texture2D = UiKit.tex("title_btn_sel")
    for i in SLOTS.size():
        var id: String = String(SLOTS[i][1])
        if id == "exit" and OS.has_feature("web"):
            continue
        var b := MenuBtn.new()
        b.label = String(SLOTS[i][0])
        b.icon = UiKit.tex("title_ic_" + id)
        b.sprite_n = sn
        b.sprite_s = ss
        b.slot = i
        b.enabled = not (id == "cont" and not Game.has_save())
        b.selected = _btns.size() == 0
        b.pressed.connect(_on_main.bind(id))
        var idx: int = _btns.size()
        b.hovered.connect(_select.bind(idx))
        _main_layer.add_child(b)
        _btns.append(b)


func _select(i: int) -> void:
    if _cur != "main" or i == _sel or i < 0 or i >= _btns.size():
        return
    _sel = i
    for j in _btns.size():
        var b: MenuBtn = _btns[j]
        b.selected = j == i
        b.queue_redraw()


func _on_main(id: String) -> void:
    Audio.sfx("select")
    match id:
        "new":
            _show("create")
        "cont":
            _continue()
        "sett":
            _show("settings")
        "cred":
            _show("credits")
        "exit":
            _quit()


func _input(e: InputEvent) -> void:
    if _cur != "main" or _btns.is_empty():
        return
    if e.is_action_pressed("ui_down"):
        _select(wrapi(_sel + 1, 0, _btns.size()))
        get_viewport().set_input_as_handled()
    elif e.is_action_pressed("ui_up"):
        _select(wrapi(_sel - 1, 0, _btns.size()))
        get_viewport().set_input_as_handled()
    elif e.is_action_pressed("ui_accept"):
        var b: MenuBtn = _btns[_sel]
        if b.enabled:
            b.pressed.emit()
        get_viewport().set_input_as_handled()


func _show(which: String) -> void:
    _cur = which
    var main_on: bool = which == "main"
    _main_layer.visible = main_on
    _dim.visible = not main_on
    _panel.visible = not main_on
    _create_box.visible = which == "create"
    _job_box.visible = which == "job"
    _settings_box.visible = which == "settings"
    _credits_box.visible = which == "credits"
    _mp_box.visible = which == "mp"
    if which == "mp":
        _greet.text = "Multiplayer (Co-op)"
    if which == "job":
        _greet.text = "Pilih Jobmu"
        _pick_job(_job)
    if which == "create":
        _greet.text = "Siapa namamu, petualang?"
    elif which == "credits":
        _greet.text = "Kredit"
    elif which == "settings":
        _greet.text = "Pengaturan"


func _btn(text: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0, 44)
    b.add_theme_font_size_override("font_size", 18)
    b.pressed.connect(cb)
    return b


func _build_credits() -> void:
    var lines := [
        "Ikon item: Raven Fantasy Icons (Clockwork Raven Studios) & ASSET v0.2",
        "Panel & HUD: Game UI Kit v1.0 (16x16 pixel series)",
        "Menu utama, HUD & panel bergaya Greenwood (gambar UI buatan sendiri)",
        "Karakter: Pipoya • Monster: Basic Asset Pack",
        "Peta: Cainos, Craftpix, nnekart, Ember Caldera",
    ]
    for l in lines:
        var lb := Label.new()
        lb.text = l
        lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        lb.custom_minimum_size = Vector2(360, 0)
        lb.add_theme_font_size_override("font_size", 13)
        lb.add_theme_color_override("font_color", Color(1, 1, 1))
        _credits_box.add_child(lb)
    _credits_box.add_child(_btn("Kembali", _show.bind("main")))


func _build_create() -> void:
    _name_edit = LineEdit.new()
    _name_edit.placeholder_text = "Nama karakter"
    _name_edit.text = "Petualang"
    _name_edit.max_length = 14
    _name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
    _name_edit.custom_minimum_size = Vector2(0, 40)
    _create_box.add_child(_name_edit)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 14)
    _create_box.add_child(row)
    row.add_child(_gender_card("m", "Laki-laki"))
    row.add_child(_gender_card("f", "Perempuan"))
    _create_box.add_child(_btn("Lanjut: Pilih Job", _show.bind("job")))
    _create_box.add_child(_btn("Kembali", _show.bind("main")))


func _build_job() -> void:
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 6)
    grid.add_theme_constant_override("v_separation", 6)
    _job_box.add_child(grid)
    for id in Jobs.BASE:
        var b := _btn(String(Jobs.DATA[id]["name"]), _pick_job.bind(id))
        b.custom_minimum_size = Vector2(0, 38)
        b.add_theme_font_size_override("font_size", 15)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        grid.add_child(b)
        _job_btns[id] = b
    _job_desc = Label.new()
    _job_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _job_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _job_desc.custom_minimum_size = Vector2(400, 84)
    _job_desc.add_theme_font_size_override("font_size", 14)
    _job_box.add_child(_job_desc)
    _job_box.add_child(_btn("Mulai Petualangan!", _start))
    _job_box.add_child(_btn("Kembali", _show.bind("create")))


func _pick_job(id: String) -> void:
    _job = id
    var d: Dictionary = Jobs.DATA[id]
    var sk: Dictionary = d["skill"]
    var st: Dictionary = d.get("stats", {})
    var parts: Array = []
    for k in st.keys():
        parts.append("%s +%d" % [String(k).to_upper(), int(st[k])])
    _job_desc.text = "%s\n%s\nSkill (tombol U): %s\nBonus awal: %s" % [String(d["name"]), String(d["desc"]), String(sk["name"]), ", ".join(PackedStringArray(parts))]
    for k in _job_btns.keys():
        (_job_btns[k] as Button).disabled = (k == id)


func _gender_card(g: String, label: String) -> Control:
    var v := VBoxContainer.new()
    var pv = MenuScript.Preview.new()
    pv.custom_minimum_size = Vector2(130, 120)
    pv.gender = g
    pv.skin_id = "skin_default"
    pv.scl = 3.4
    v.add_child(pv)
    var b := _btn(label, _pick_gender.bind(g))
    b.custom_minimum_size = Vector2(130, 36)
    b.add_theme_font_size_override("font_size", 14)
    v.add_child(b)
    return v


func _pick_gender(g: String) -> void:
    _gender = g
    Audio.sfx("select")
    _greet.text = "Kamu memilih: %s" % ("laki-laki" if g == "m" else "perempuan")


func _slider(label: String, key: String) -> Control:
    var hb := HBoxContainer.new()
    var l := Label.new()
    l.text = label
    l.custom_minimum_size = Vector2(110, 0)
    hb.add_child(l)
    var s := HSlider.new()
    s.min_value = 0.0
    s.max_value = 1.0
    s.step = 0.05
    s.value = float(Game.settings[key])
    s.custom_minimum_size = Vector2(230, 24)
    s.value_changed.connect(_set_vol.bind(key))
    hb.add_child(s)
    return hb


func _build_settings() -> void:
    _settings_box.add_child(_slider("Musik", "bgm"))
    _settings_box.add_child(_slider("Efek suara", "sfx"))
    var cb := CheckBox.new()
    cb.text = "Bisukan semua suara"
    cb.button_pressed = bool(Game.settings["muted"])
    cb.toggled.connect(_set_muted)
    _settings_box.add_child(cb)
    _settings_box.add_child(_btn("Kembali", _show.bind("main")))


func _set_vol(v: float, key: String) -> void:
    Game.settings[key] = v
    Game.save_settings()
    Audio.apply_settings()
    if key == "sfx":
        Audio.sfx("coin")


func _set_muted(m: bool) -> void:
    Game.settings["muted"] = m
    Game.save_settings()
    Audio.apply_settings()


# ------------------------------------------------------------------ multiplayer (lihat net.gd)
func _build_mp_button() -> void:
    var b := Button.new()
    b.text = "Multiplayer"
    b.add_theme_font_size_override("font_size", 20)
    b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    b.offset_left = -214.0
    b.offset_top = -72.0
    b.offset_right = -24.0
    b.offset_bottom = -24.0
    b.pressed.connect(_open_mp)
    _main_layer.add_child(b)


func _open_mp() -> void:
    Audio.sfx("select")
    _show("mp")


func _build_mp() -> void:
    var info := Label.new()
    info.text = "Main bareng lewat WiFi / hotspot yang sama (maks %d pemain).\nSatu orang jadi Host, yang lain Gabung pakai IP host." % Net.MAX_PLAYERS
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.custom_minimum_size = Vector2(380, 0)
    _mp_box.add_child(info)
    _mp_name = LineEdit.new()
    _mp_name.placeholder_text = "Nama karakter (dipakai kalau belum punya save)"
    _mp_name.text = "Petualang"
    _mp_name.max_length = 14
    _mp_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
    _mp_name.custom_minimum_size = Vector2(0, 40)
    _mp_box.add_child(_mp_name)
    _mp_box.add_child(_btn("Jadi Host (buat ruangan)", _mp_host))
    _mp_ip = LineEdit.new()
    _mp_ip.placeholder_text = "IP host, mis. 192.168.43.1"
    _mp_ip.text = Net.guess_host_ip()
    _mp_ip.alignment = HORIZONTAL_ALIGNMENT_CENTER
    _mp_ip.custom_minimum_size = Vector2(0, 40)
    _mp_box.add_child(_mp_ip)
    _mp_box.add_child(_btn("Gabung ke Host", _mp_join))
    _mp_status = Label.new()
    _mp_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _mp_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _mp_status.custom_minimum_size = Vector2(380, 0)
    _mp_box.add_child(_mp_status)
    _mp_go = _btn("Masuk Dunia", _mp_enter)
    _mp_go.visible = false
    _mp_box.add_child(_mp_go)
    _mp_box.add_child(_btn("Kembali", _mp_back))
    Net.joined_ok.connect(_mp_joined)
    Net.failed.connect(_mp_failed)


func _mp_host() -> void:
    Audio.sfx("select")
    if Net.active:
        return
    Net.prepare_character(_mp_name.text.strip_edges())
    if Net.host_game():
        var ips: Array = Net.local_ips()
        var ip_txt: String = ", ".join(PackedStringArray(ips)) if not ips.is_empty() else "(nyalakan hotspot / WiFi dulu)"
        _mp_status.text = "Ruangan aktif!  IP kamu: %s\nSuruh temanmu Gabung ke IP ini, lalu tekan Masuk Dunia." % ip_txt
        _mp_go.visible = true


func _mp_join() -> void:
    Audio.sfx("select")
    if Net.active:
        Net.leave()
    _mp_go.visible = false
    Net.prepare_character(_mp_name.text.strip_edges())
    _mp_status.text = "Menghubungkan ke %s ..." % _mp_ip.text.strip_edges()
    Net.join_game(_mp_ip.text)


func _mp_joined() -> void:
    Audio.sfx("levelup")
    get_tree().change_scene_to_file("res://scenes/main.tscn")


func _mp_failed(reason: String) -> void:
    _mp_status.text = reason
    _mp_go.visible = false


func _mp_enter() -> void:
    Audio.sfx("levelup")
    get_tree().change_scene_to_file("res://scenes/main.tscn")


func _mp_back() -> void:
    Net.leave()
    _mp_go.visible = false
    _mp_status.text = ""
    _show("main")


func _continue() -> void:
    if Game.load_save():
        Audio.sfx("select")
        get_tree().change_scene_to_file("res://scenes/main.tscn")


func _start() -> void:
    Game.new_game(_name_edit.text.strip_edges(), _gender, _job)
    Audio.sfx("levelup")
    get_tree().change_scene_to_file("res://scenes/main.tscn")


func _quit() -> void:
    get_tree().quit()
