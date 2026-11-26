extends CanvasLayer
# HUD: bar HP/MP angka, XP, koin & gem, minimap, tombol aksi bergambar, dialog,
# banner, toast, bar bos. Menu lengkap (tas, status, crafting, skin, toko, setelan) ada di menu.gd.

const Art = preload("res://scripts/art.gd")
const MenuScript = preload("res://scripts/menu.gd")
const StickScript = preload("res://scripts/touch_stick.gd")
const K = preload("res://scripts/ui_kit.gd")
const FogScript = preload("res://scripts/fog.gd")
const Panels = preload("res://scripts/panels.gd")

var world
var player
var fog                          # fog of war minimap (fog.gd)
var menu
var overlay
var stick
var buttons: Array = []
var minimap_tex: ImageTexture
var panel_sb: StyleBoxTexture   # bingkai gelap (kit Greenwood) untuk panel quest & toast; null kalau file tidak ada
var pause_list: Control
var toast_sb: StyleBoxTexture

# Skala kontrol sentuh (joystick + tombol). Naikkan kalau masih terasa kecil.
const CTRL_SCALE := 1.35

var banner := ""
var banner_t := 0.0
var banner_dur := 2.0
var toasts: Array = []
var boss_name := ""
var boss_hp := 0
var boss_max := 1
var boss_on := false

var _dlg: VBoxContainer
var _choice_panel: PanelContainer
var _dlg_name: Label
var _dlg_text: Label
var _dlg_next: Label
var _dlg_choices: VBoxContainer
var _lines: Array = []
var _line_i := 0
var _on_done := Callable()
var _choose_cb := Callable()
var _typing := 0.0
var _dim: ColorRect
var _port_l
var _port_r
var _spk := ""
var _spk_npc = null
var _spk_player := false
var _hid := false
var _flash := false
var _qlog
var _wmap
var _disc_t := 0.0
const REACT := ["Hmm, begitu ya...", "Oh, jadi begitu.", "Aku mengerti.", "Lanjutkan, aku mendengarkan.", "Baik, akan kuingat.", "Itu menarik..."]
var _block_t := 0.0
var _debounce := 0.0
var _touch := false


# ------------------------------------------------------------------ gambar HUD
class Overlay extends Control:
    const A = preload("res://scripts/art.gd")
    const Story = preload("res://scripts/story.gd")
    const K = preload("res://scripts/ui_kit.gd")
    const SP := 0.6      # skala PNG aset terhadap sheet asli
    const KS := 0.48     # HUD, status, mata uang, dan minimap diperbesar untuk layar ponsel
    const MAP_HOLE := Rect2(22, 32, 255, 207)   # jendela peta di dalam bingkai (piksel sheet)
    const SLOT := 46.0
    var hud
    var t_status: Texture2D
    var t_fhp: Texture2D
    var t_fmp: Texture2D
    var t_fexp: Texture2D
    var t_pcoin: Texture2D
    var t_pblank: Texture2D
    var t_map: Texture2D
    var t_slot: Texture2D

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
        set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        t_status = K.tex("hud_status")
        t_fhp = K.tex("hud_fill_hp")
        t_fmp = K.tex("hud_fill_mp")
        t_fexp = K.tex("hud_fill_exp")
        t_pcoin = K.tex("hud_pill_coin")
        t_pblank = K.tex("hud_pill_blank")
        t_map = K.tex("hud_minimap")
        t_slot = K.tex("hud_slot")

    var _acc := 0.0

    func _process(d: float) -> void:
        _acc += d
        if _acc >= 1.0 / Perf.hud_hz:
            _acc = 0.0
            queue_redraw()

    func _t(text: String, pos: Vector2, size: int, col: Color, w: float = -1.0, al: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
        var f: Font = ThemeDB.fallback_font
        draw_string_outline(f, pos, text, al, w, size, 4, Color(0, 0, 0, col.a))
        draw_string(f, pos, text, al, w, size, col)

    # teks kecil (angka di dalam bar): garis tepi lebih tipis
    func _tn(text: String, pos: Vector2, size: int, col: Color, w: float = -1.0, al: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
        var f: Font = ThemeDB.fallback_font
        var ol: int = 3 if size >= 10 else 2
        draw_string_outline(f, pos, text, al, w, size, ol, Color(0.03, 0.02, 0.05, col.a))
        draw_string(f, pos, text, al, w, size, col)

    func _panel(r: Rect2) -> void:
        if hud.panel_sb:
            draw_style_box(hud.panel_sb, r)
        else:
            draw_rect(r, Color(0.05, 0.06, 0.1, 0.7))
            draw_rect(r, Color(1, 1, 1, 0.25), false, 1.5)

    # gambar kit pada posisi layar `pos` dengan skala k (px layar per px sheet asli)
    func _sp(tx: Texture2D, pos: Vector2, k: float) -> void:
        if tx != null:
            draw_texture_rect(tx, Rect2(pos, tx.get_size() * k / SP), false)

    # isi bar sebagian (kiri ke kanan)
    func _fill(tx: Texture2D, pos: Vector2, k: float, frac: float) -> void:
        if tx == null:
            return
        var f: float = clampf(frac, 0.0, 1.0)
        if f <= 0.0:
            return
        var tsz: Vector2 = tx.get_size()
        var w: float = maxf(1.0, floorf(tsz.x * f))
        draw_texture_rect_region(tx, Rect2(pos, Vector2(w, tsz.y) * k / SP), Rect2(0, 0, w, tsz.y))

    # angka di tengah bar; rel/w/h dalam piksel sheet, o = pojok panel status
    func _bt(text: String, rel: Vector2, w: float, h: float, o: Vector2, fsize: int) -> void:
        _tn(text, Vector2(o.x + rel.x * KS, o.y + (rel.y + h * 0.5) * KS + float(fsize) * 0.36), fsize, Color.WHITE, w * KS, HORIZONTAL_ALIGNMENT_CENTER)

    func _bar(r: Rect2, frac: float, col: Color, text: String) -> void:
        draw_rect(Rect2(r.position - Vector2(2, 2), r.size + Vector2(4, 4)), Color(0, 0, 0, 0.75))
        draw_rect(r, col.darkened(0.7))
        draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
        draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y * 0.4)), Color(1, 1, 1, 0.18))
        if text != "":
            _t(text, r.position + Vector2(0, r.size.y - 3), int(r.size.y - 3), Color.WHITE, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)

    func _draw() -> void:
        var pl = hud.player
        if pl == null:
            return
        var sz: Vector2 = get_viewport_rect().size
        var lv: int = int(Game.p["level"])
        var o := Vector2(6, 6)
        # --- status kiri atas: potret, Lv, HP / MP / EXP
        _sp(t_status, o, KS)
        var need: int = Game.xp_needed(lv)
        _fill(t_fhp, o + Vector2(316, 79) * KS, KS, float(pl.hp) / float(maxi(pl.max_hp, 1)))
        _fill(t_fmp, o + Vector2(316, 123) * KS, KS, pl.mp / float(maxi(pl.max_mp, 1)))
        _fill(t_fexp, o + Vector2(318, 178) * KS, KS, float(Game.p["xp"]) / float(maxi(need, 1)))
        _bt("%d / %d" % [pl.hp, pl.max_hp], Vector2(316, 79), 308.0, 26.0, o, 10)
        _bt("%d / %d" % [int(pl.mp), pl.max_mp], Vector2(316, 123), 253.0, 25.0, o, 10)
        _bt("%d / %d" % [int(Game.p["xp"]), need], Vector2(318, 178), 282.0, 15.0, o, 9)
        _tn("Lv. %d" % lv, Vector2(o.x + 128.0 * KS - 30.0, o.y + 216.0 * KS + 4.0), 11, Color.WHITE, 60.0, HORIZONTAL_ALIGNMENT_CENTER)
        if int(Game.p["points"]) > 0:
            var pulse: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 150.0)
            _t("+%d poin stat!" % int(Game.p["points"]), Vector2(o.x + 250.0 * KS, o.y + 238.0 * KS), 11, Color(1.0, 0.85, 0.2, pulse))
        # --- mata uang
        var py: float = o.y + 257.0 * KS + 4.0
        var cy: float = py + 36.5 * KS
        _sp(t_pcoin, Vector2(6, py), KS)
        _tn(str(int(Game.p["coins"])), Vector2(6.0 + 60.0 * KS, cy + 5.0), 13, Color(1.0, 0.9, 0.5), 140.0 * KS, HORIZONTAL_ALIGNMENT_RIGHT)
        var gx: float = 6.0 + 222.0 * KS + 6.0
        _sp(t_pblank, Vector2(gx, py), KS)
        A.draw_currency(self, "gem", Vector2(gx + 30.0 * KS, cy), 6.5)
        _tn(str(int(Game.p["gems"])), Vector2(gx + 60.0 * KS, cy + 5.0), 13, Color(0.6, 0.95, 1.0), 140.0 * KS, HORIZONTAL_ALIGNMENT_RIGHT)
        # --- quest
        var qy: float = py + 73.0 * KS + 4.0
        var q: Dictionary = Game.p["quest"]
        if q["type"] != "none":
            _panel(Rect2(6, qy, 232, 46))
            _t("Quest: " + String(q["label"]), Vector2(20, qy + 19), 10, Color(1, 0.95, 0.7), 206.0)
            var done: bool = int(q["have"]) >= int(q["need"])
            _t(("Selesai! Temui Tetua Oren" if done else "%d / %d" % [int(q["have"]), int(q["need"])]), Vector2(20, qy + 35), 11, Color(0.5, 1, 0.5) if done else Color.WHITE)
        # --- kisah utama (di bawah quest harian)
        if not Story.finished() and Story.accepted():
            var sy: float = qy + (50.0 if q["type"] != "none" else 0.0)
            _panel(Rect2(6, sy, 232, 46))
            _t("Kisah: " + String(Story.cur()["title"]), Vector2(20, sy + 19), 10, Color(1, 0.75, 0.4), 206.0)
            var sdone: bool = Story.is_complete()
            _t(Story.short_text(), Vector2(20, sy + 35), 11, Color(0.5, 1, 0.5) if sdone else Color.WHITE, 206.0)
        # --- minimap (kanan atas, di kiri tombol jeda / gigi)
        if hud.minimap_tex and t_map != null:
            var fsz: Vector2 = t_map.get_size() * KS / SP
            var fp := Vector2(sz.x - 6.0 - 51.0 - 4.0 - fsz.x, 6.0)
            var mr := Rect2(fp + MAP_HOLE.position * KS, MAP_HOLE.size * KS)
            draw_rect(mr, Color(0.04, 0.03, 0.07))
            draw_texture_rect(hud.minimap_tex, mr, false)
            if hud.fog != null:
                draw_texture_rect(hud.fog.tex, mr, false)      # kabut penjelajahan, gaya beda tiap biome
            _sp(t_map, fp, KS)
            if hud.world.has_meta("in_dungeon"):
                _t(String(hud.world.get_meta("dungeon_name", "Gua")), Vector2(fp.x, fp.y + fsz.y + 14.0), 11, Color(1, 0.85, 0.6), fsz.x, HORIZONTAL_ALIGNMENT_CENTER)
            else:
                var ws: Vector2 = hud.world.world_size()
                for b in get_tree().get_nodes_in_group("boss"):
                    if hud.fog != null and not hud.fog.seen_at(b.global_position):
                        continue                                # bos di dalam kabut belum kelihatan
                    var bp: Vector2 = mr.position + b.global_position / ws * mr.size
                    draw_circle(bp, 3.0, Color.BLACK)
                    draw_circle(bp, 2.2, Color(1, 0.55, 0.15))
                var pp: Vector2 = mr.position + pl.global_position / ws * mr.size
                var tri := PackedVector2Array([pp + Vector2(0, -5.5), pp + Vector2(-4.2, 4), pp + Vector2(4.2, 4)])
                draw_colored_polygon(tri, Color(0.95, 0.15, 0.2))
                draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color.WHITE, 1.2)
                _t(hud.world.BNAMES[hud.world.biome_at(pl.global_position)], Vector2(fp.x, fp.y + fsz.y + 14.0), 11, Color(1, 1, 0.85), fsz.x, HORIZONTAL_ALIGNMENT_CENTER)
            var am = get_tree().current_scene.get("atmos")
            if am != null and am.clock_text() != "":
                _t(am.clock_text(), Vector2(fp.x, fp.y + fsz.y + 27.0), 10, Color(0.85, 0.92, 1.0), fsz.x, HORIZONTAL_ALIGNMENT_CENTER)
        # --- panah penunjuk arah di tepi layar: tugu jurnal yang dicari & meteor (saat sudah cukup dekat)
        if not hud.world.has_meta("in_dungeon") and not hud.busy():
            var ctr: Vector2 = sz / 2.0
            var half: Vector2 = ctr - Vector2(36.0, 36.0)
            for tn in get_tree().get_nodes_in_group("compass_target"):
                if not tn.compass_on():
                    continue
                var dv: Vector2 = tn.global_position - pl.global_position
                var dist: float = dv.length()
                if dist < 320.0 or dist > float(tn.compass_range):
                    continue
                var dir: Vector2 = dv / dist
                var sc: float = minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
                var ap: Vector2 = ctr + dir * sc
                var cc: Color = tn.compass_col
                var pulse: float = 0.65 + 0.35 * sin(float(Time.get_ticks_msec()) / 220.0)
                var tri := PackedVector2Array([ap + dir * 14.0, ap + dir.rotated(2.5) * 11.0, ap + dir.rotated(-2.5) * 11.0])
                draw_colored_polygon(tri, Color(cc.r, cc.g, cc.b, pulse))
                draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(1, 1, 1, 0.8), 1.2)
                _t("%d" % int(dist / 32.0), ap - dir * 24.0 + Vector2(-20, 4), 10, Color(cc.r, cc.g, cc.b, 1.0), 40.0, HORIZONTAL_ALIGNMENT_CENTER)
        # --- bar bos
        if hud.boss_on:
            var bw := minf(sz.x * 0.4, 360.0)
            var bx: float = (sz.x - bw) / 2.0
            _t(hud.boss_name, Vector2(bx, 24), 14, Color(1, 0.8, 0.5), bw, HORIZONTAL_ALIGNMENT_CENTER)
            _bar(Rect2(bx, 30, bw, 14), float(hud.boss_hp) / float(hud.boss_max), Color(0.85, 0.2, 0.2), "%d / %d" % [hud.boss_hp, hud.boss_max])
        # --- banner
        if hud.banner_t > 0.0:
            var a: float = clampf(minf(hud.banner_t, hud.banner_dur - hud.banner_t + 0.2) * 3.0, 0.0, 1.0)
            draw_rect(Rect2(0, sz.y * 0.26, sz.x, 44), Color(0.05, 0.0, 0.03, 0.55 * a))
            _t(hud.banner, Vector2(0, sz.y * 0.26 + 30), 24, Color(1, 0.95, 0.85, a), sz.x, HORIZONTAL_ALIGNMENT_CENTER)
        # --- toast (pil gelap berbingkai merah)
        var ty: float = sz.y * 0.62
        var fnt: Font = ThemeDB.fallback_font
        for i in hud.toasts.size():
            var ts: Dictionary = hud.toasts[hud.toasts.size() - 1 - i]
            var txt: String = String(ts["t"])
            var al: float = clampf(float(ts["life"]) * 2.0, 0.0, 1.0)
            var tw: float = fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 40.0
            var tr := Rect2(sz.x / 2.0 - tw / 2.0, ty - float(i) * 30.0 - 18.0, tw, 28.0)
            if hud.toast_sb != null:
                hud.toast_sb.modulate_color = Color(1, 1, 1, al)
                draw_style_box(hud.toast_sb, tr)
            else:
                draw_rect(tr, Color(0.05, 0.04, 0.09, 0.8 * al))
            _t(txt, Vector2(tr.position.x, tr.position.y + 19.0), 13, Color(1, 1, 1, al), tw, HORIZONTAL_ALIGNMENT_CENTER)
        # --- hotbar 1..5 (ramuan di slot 1 & 2 digambar tombolnya)
        var hx: float = sz.x / 2.0 - (5.0 * SLOT + 8.0) / 2.0
        var hy: float = sz.y - SLOT - 8.0
        for i in 5:
            var slot_pos := Vector2(hx + float(i) * (SLOT + 2.0), hy)
            if t_slot != null:
                draw_texture_rect(t_slot, Rect2(slot_pos, Vector2(SLOT, SLOT)), false)
            else:
                draw_rect(Rect2(slot_pos, Vector2(SLOT, SLOT)), Color(0.07, 0.06, 0.11, 0.8))
                draw_rect(Rect2(slot_pos, Vector2(SLOT, SLOT)), K.CRIMSON, false, 2.0)
            _tn(str(i + 1), slot_pos + Vector2(5, 13), 10, Color.WHITE)
        # --- petunjuk tombol
        if not hud._touch:
            _t("WASD jalan   J serang   K sihir   E aksi   I tas   1/2 ramuan", Vector2(0, hy - 8.0), 11, Color(1, 1, 1, 0.65), sz.x, HORIZONTAL_ALIGNMENT_CENTER)
        if pl.dead:
            draw_rect(Rect2(Vector2.ZERO, sz), Color(0.3, 0, 0, 0.35))


class Btn extends Control:
    const A = preload("res://scripts/art.gd")
    const K = preload("res://scripts/ui_kit.gd")
    signal pressed
    var kind := ""
    var action := ""
    var hud
    var held := false
    var _finger := -1
    var pulse_text := ""

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

    var _acc := 0.0

    func _process(d: float) -> void:
        _acc += d
        if _acc >= 1.0 / Perf.hud_hz or held:
            _acc = 0.0
            queue_redraw()

    func _input(event: InputEvent) -> void:
        if not is_visible_in_tree() or hud.busy():
            return
        if (kind == "pause" or kind == "gear") and not hud._touch:
            # di PC tombol jeda / gigi bisa diklik mouse
            if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
                if get_global_rect().has_point(event.position):
                    pressed.emit()
                    get_viewport().set_input_as_handled()
            return
        if event is InputEventScreenTouch:
            if event.pressed and _finger == -1 and get_global_rect().has_point(event.position):
                _finger = event.index
                held = true
                if action != "":
                    Input.action_press(action)
                pressed.emit()
            elif not event.pressed and event.index == _finger:
                _finger = -1
                held = false
                if action != "":
                    Input.action_release(action)

    func _circle(tx: Texture2D, c: Vector2, r: float, tint: Color) -> void:
        if tx != null:
            draw_texture_rect(tx, Rect2(Vector2.ZERO, size), false, tint)
        else:
            draw_circle(c, r, Color(0.05, 0.06, 0.1, 0.62 if not held else 0.85))
            draw_arc(c, r - 1.0, 0.0, TAU, 36, Color(1, 1, 1, 0.55 if not held else 1.0), 2.5)

    func _draw() -> void:
        var c := size / 2.0
        var r: float = minf(size.x, size.y) / 2.0
        var pl = hud.player
        var f: Font = ThemeDB.fallback_font
        var tint := Color(0.72, 0.72, 0.78) if held else Color.WHITE
        if kind == "pause" or kind == "gear":
            var tb: Texture2D = K.tex("hud_btn_" + kind)
            if tb != null:
                draw_texture_rect(tb, Rect2(Vector2.ZERO, size), false, tint)
            else:
                _circle(null, c, r, tint)
                A.draw_hud_icon(self, "gear" if kind == "gear" else "bag", c, r * 0.9)
            return
        if kind == "potion_hp" or kind == "potion_mp":
            if held:
                draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.22), true)
            A.draw_hud_icon(self, kind, c + Vector2(0, -2), r * 0.85)
            if pl:
                var n: int = pl.count(kind)
                draw_string_outline(f, Vector2(0, size.y - 4), "x%d" % n, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, int(12.0 * r / 23.0), 4, Color.BLACK)
                draw_string(f, Vector2(0, size.y - 4), "x%d" % n, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4, int(12.0 * r / 23.0), Color.WHITE)
            return
        if kind == "magic":
            var ts: Texture2D = K.tex("hud_btn_star")
            if ts != null:
                draw_texture_rect(ts, Rect2(Vector2.ZERO, size), false, tint)
            else:
                _circle(null, c, r, tint)
                A.draw_hud_icon(self, "magic", c, r * 0.9)
            return
        if kind == "dodge" or kind == "skill":
            _circle(K.tex("hud_btn_round"), c, r, tint)
            var rem: float = 0.0
            if pl:
                rem = pl.dodge_ratio() if kind == "dodge" else pl.skill_ratio()
            var ic := Color(0.75, 0.92, 1.0) if kind == "dodge" else Color(1.0, 0.8, 0.4)
            if kind == "dodge":
                for i in 3:
                    var x: float = -r * 0.35 + float(i) * r * 0.3
                    draw_polyline(PackedVector2Array([c + Vector2(x, -r * 0.3), c + Vector2(x + r * 0.22, 0), c + Vector2(x, r * 0.3)]), ic, 2.5)
            else:
                draw_arc(c, r * 0.42, -0.6, TAU - 1.0, 24, ic, 3.0)
                var tipp: Vector2 = c + Vector2.from_angle(-0.6) * r * 0.42
                draw_colored_polygon(PackedVector2Array([tipp + Vector2(-5, -5), tipp + Vector2(5, 0), tipp + Vector2(-3, 6)]), ic)
            if rem > 0.0:
                var pts := PackedVector2Array([c])
                var a0: float = -PI / 2.0
                for i in 21:
                    pts.append(c + Vector2.from_angle(a0 + TAU * rem * float(i) / 20.0) * (r - 2.0))
                draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
            elif kind == "skill":
                draw_arc(c, r + 2.0, 0.0, TAU, 36, Color(1, 0.85, 0.3, 0.55 + 0.4 * sin(Time.get_ticks_msec() / 160.0)), 3.0)
            return
        _circle(K.tex("hud_btn_round"), c, r, tint)
        if kind == "sword":
            A.draw_hud_icon(self, "sword", c, r * 0.95, pl.sword() if pl else {})
        else:
            A.draw_hud_icon(self, kind, c, r * 0.9)
        if kind == "hand" and pl:
            var lab: String = pl.context_label()
            if lab != "":
                draw_string_outline(f, Vector2(-30, size.y + 14), lab, HORIZONTAL_ALIGNMENT_CENTER, size.x + 60, 15, 4, Color.BLACK)
                draw_string(f, Vector2(-30, size.y + 14), lab, HORIZONTAL_ALIGNMENT_CENTER, size.x + 60, 15, Color(1, 0.95, 0.5))
                draw_arc(c, r + 3.0, 0.0, TAU, 36, Color(1, 0.9, 0.3, 0.6 + 0.4 * sin(Time.get_ticks_msec() / 120.0)), 3.0)


func _ready() -> void:
    add_to_group("hud")
    layer = 10
    process_mode = Node.PROCESS_MODE_ALWAYS
    _touch = DisplayServer.is_touchscreen_available()
    _build_panel_style()
    overlay = Overlay.new()
    overlay.hud = self
    add_child(overlay)
    _build_buttons()
    _build_dialog()
    _build_pause_list()
    menu = MenuScript.new()
    menu.hud = self
    add_child(menu)


func _build_panel_style() -> void:
    panel_sb = K.nine("hud_toast", 16, 14, 16, 14)
    toast_sb = K.nine("hud_toast", 16, 14, 16, 14)


func setup(w, p) -> void:
    world = w
    player = p
    minimap_tex = world.make_minimap()
    fog = FogScript.new()
    fog.setup(world, p.global_position)
    menu.player = p


func _mk_btn(kind: String, action: String, radius: float):
    var b := Btn.new()
    b.kind = kind
    b.action = action
    b.hud = self
    b.size = Vector2(radius * 2.0, radius * 2.0)
    add_child(b)
    buttons.append({"node": b, "r": radius, "kind": kind})
    return b


func _build_buttons() -> void:
    var k := CTRL_SCALE
    _mk_btn("sword", "attack", 40.0 * k)
    _mk_btn("magic", "magic", 34.0 * k)
    _mk_btn("hand", "interact", 30.0 * k)
    _mk_btn("skill", "skill", 30.0 * k)
    _mk_btn("dodge", "dodge", 26.0 * k)
    _mk_btn("potion_hp", "potion_hp", 46.0)
    _mk_btn("potion_mp", "potion_mp", 46.0)
    var pz = _mk_btn("pause", "", 25.5)
    pz.pressed.connect(open_pause_list)
    var gear = _mk_btn("gear", "", 25.5)
    gear.pressed.connect(open_menu.bind("settings"))
    stick = StickScript.new()
    stick.size = Vector2(170, 170) * k
    stick.radius = 60.0 * k
    stick.visible = _touch
    add_child(stick)
    _layout()


func _layout() -> void:
    var sz: Vector2 = get_viewport().get_visible_rect().size
    var hx: float = sz.x / 2.0 - (5.0 * 46.0 + 8.0) / 2.0
    var hy: float = sz.y - 46.0 - 8.0
    var pos := {
        "sword": Vector2(sz.x - 96, sz.y - 104),
        "magic": Vector2(sz.x - 218, sz.y - 70),
        "hand": Vector2(sz.x - 84, sz.y - 232),
        "skill": Vector2(sz.x - 204, sz.y - 172),
        "dodge": Vector2(sz.x - 40, sz.y - 40),
        "potion_hp": Vector2(sz.x / 2.0 - 54.0, sz.y - 50.0),
        "potion_mp": Vector2(sz.x / 2.0 + 54.0, sz.y - 50.0),
        "pause": Vector2(sz.x - 6.0 - 25.5, 6.0 + 25.5),
        "gear": Vector2(sz.x - 6.0 - 25.5, 6.0 + 51.0 + 4.0 + 25.5),
    }
    for b in buttons:
        var n: Control = b["node"]
        var c: Vector2 = pos[b["kind"]]
        n.position = c - Vector2(b["r"], b["r"])
    stick.position = Vector2(22, sz.y - stick.size.y - 20.0)
    _layout_dialog(sz)


func _layout_dialog(sz: Vector2) -> void:
    if _dlg == null or _dim == null or _port_l == null or _port_r == null:
        return          # _layout() sudah dipanggil dari _build_buttons sebelum dialog dibangun
    var on := _dlg.visible
    if on != _hid:
        _hid = on
        for b in buttons:
            (b["node"] as Control).visible = not on
        stick.visible = _touch and not on
    _dim.visible = on
    var show_p := on and _spk_npc != null and not _flash
    _port_l.visible = show_p
    _port_r.visible = on and not _flash
    if not on:
        return
    var bw: float = minf(sz.x - 40.0, 700.0)
    _dlg.custom_minimum_size.x = bw
    _dlg_text.custom_minimum_size.x = bw - 80.0
    _place_dialog(sz)


func _place_dialog(sz: Vector2) -> void:
    # kotak dialog menempel di bawah layar (naik 12%), tinggi mengikuti isi teks
    var bw: float = minf(sz.x - 40.0, 700.0)
    var h: float = _dlg.get_combined_minimum_size().y
    _dlg.position = Vector2((sz.x - bw) / 2.0, sz.y - h - sz.y * 0.12)
    var top: float = _dlg.position.y
    var ph: float = minf(minf(sz.y * 0.42, 210.0), top - 10.0)
    if ph < 70.0:
        _port_l.visible = false
        _port_r.visible = false
        return
    var pw: float = ph * 0.8
    var left: float = (sz.x - bw) / 2.0
    _port_l.size = Vector2(pw, ph)
    _port_r.size = Vector2(pw, ph)
    _port_l.position = Vector2(left + 8.0, top - ph)
    _port_r.position = Vector2(sz.x - left - pw - 8.0, top - ph)
    _port_l.queue_redraw()
    _port_r.queue_redraw()


class Portrait extends Control:
    const A = preload("res://scripts/art.gd")
    var hud
    var mine := false
    var _tt := 0.0

    func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        clip_contents = true

    func _process(d: float) -> void:
        _tt += d
        if visible:
            modulate = Color.WHITE if (hud._spk_player == mine) else Color(0.55, 0.55, 0.62)
            queue_redraw()

    func _draw() -> void:
        var active: bool = (hud._spk_player == mine)
        var f: Font = ThemeDB.fallback_font
        draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.06, 0.12, 0.92), true)
        var o := {}
        if mine:
            o = {"skin": Items.skins.get(String(Game.p["skin"]), Items.skins["skin_default"]),
                "gender": String(Game.p["gender"]), "dir": 0, "flip": false, "t": _tt, "phase": 0.0, "moving": false}
        elif hud._spk_npc != null and is_instance_valid(hud._spk_npc):
            var n = hud._spk_npc
            o = {"skin": n.skin, "gender": "m" if n.role == "elder" else n.gender, "dir": 0, "flip": false,
                "t": _tt, "phase": 0.0, "moving": false, "sprite_id": n._sprite_id()}
        if o.is_empty():
            var ch: String = String(hud._spk).substr(0, 1)
            draw_string(f, Vector2(0, size.y * 0.62), ch, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(size.y * 0.5), Color.WHITE)
        else:
            var s: float = size.y / 40.0
            var lift: float = -3.0 if active else 0.0
            draw_set_transform(Vector2(size.x / 2.0, size.y * 0.9 + lift), 0.0, Vector2(s, s))
            A.draw_human(self, o)
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        var bc := Color(1.0, 0.85, 0.5) if active else Color(0.4, 0.38, 0.45)
        draw_rect(Rect2(Vector2.ZERO, size), bc, false, 3.0 if active else 2.0)


func stick_value() -> Vector2:
    if stick and stick.visible:
        return stick.value
    return Vector2.ZERO


func busy() -> bool:
    return _dlg.visible or menu.is_open or pause_list.visible or _qlog.visible or _wmap.visible or _block_t > 0.0


# ------------------------------------------------------------------ pesan
func toast(text: String) -> void:
    toasts.append({"t": text, "life": 2.2})
    if toasts.size() > 4:
        toasts.pop_front()


func show_banner(text: String, secs: float = 2.5) -> void:
    banner = text
    banner_t = secs
    banner_dur = secs


func show_boss(n: String, hp: int, mx: int) -> void:
    boss_name = n
    boss_hp = hp
    boss_max = mx
    boss_on = true


func update_boss(hp: int) -> void:
    boss_hp = hp


func hide_boss() -> void:
    boss_on = false


func open_menu(tab: String, params: Dictionary = {}) -> void:
    if _dlg.visible:
        _close_dialog(false)
    if pause_list.visible:
        pause_list.visible = false
    menu.open(tab, params)
    _update_pause()


func gacha_pull(n: int) -> void:
    menu.gacha(n)
    _update_pause()


func _update_pause() -> void:
    # co-op: dunia tidak boleh berhenti (host menjalankan semua monster untuk semua pemain)
    get_tree().paused = (_dlg.visible or menu.is_open or pause_list.visible or _qlog.visible or _wmap.visible) and not Net.active


func menu_closed() -> void:
    _block_t = 0.3
    _update_pause()


# ------------------------------------------------------------------ dialog
func _build_dialog() -> void:
    _dim = ColorRect.new()
    _dim.color = Color(0, 0, 0, 0.45)
    _dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    _dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _dim.visible = false
    add_child(_dim)
    _port_l = Portrait.new()
    _port_l.hud = self
    _port_l.mine = true
    _port_l.visible = false
    add_child(_port_l)
    _port_r = Portrait.new()
    _port_r.hud = self
    _port_r.mine = false
    _port_r.visible = false
    add_child(_port_r)
    _dlg = VBoxContainer.new()
    _dlg.theme = K.make_theme()
    _dlg.add_theme_constant_override("separation", 4)
    _dlg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    _dlg.custom_minimum_size = Vector2(640, 0)
    _dlg.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _dlg.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _dlg.position.y = -80
    _dlg.visible = false
    add_child(_dlg)
    # daftar pilihan (muncul di atas kotak dialog)
    _choice_panel = PanelContainer.new()
    var csb: StyleBoxTexture = K.nine("ui_list", 14, 14, 14, 14)
    if csb != null:
        csb.content_margin_left = 22
        csb.content_margin_right = 22
        csb.content_margin_top = 18
        csb.content_margin_bottom = 18
        _choice_panel.add_theme_stylebox_override("panel", csb)
    else:
        _choice_panel.add_theme_stylebox_override("panel", K.flat(Color(0.07, 0.06, 0.11, 0.95), K.CRIMSON))
    _choice_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    _choice_panel.visible = false
    _dlg.add_child(_choice_panel)
    _dlg_choices = VBoxContainer.new()
    _dlg_choices.custom_minimum_size = Vector2(260, 0)
    _choice_panel.add_child(_dlg_choices)
    # tab nama + kotak dialog (tab menimpa tepi atas kotak)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", -14)
    _dlg.add_child(stack)
    var tab := PanelContainer.new()
    var tsb: StyleBoxTexture = K.nine("dlg_tab", 18, 0, 18, 0)
    if tsb != null:
        tsb.content_margin_left = 26
        tsb.content_margin_right = 26
        tsb.content_margin_top = 6
        tsb.content_margin_bottom = 10
        tab.add_theme_stylebox_override("panel", tsb)
    else:
        tab.add_theme_stylebox_override("panel", K.flat(Color(0.07, 0.06, 0.11, 0.95), K.CRIMSON))
    tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    tab.z_index = 1
    stack.add_child(tab)
    _dlg_name = Label.new()
    _dlg_name.add_theme_color_override("font_color", Color(1, 0.88, 0.75))
    _dlg_name.add_theme_font_size_override("font_size", 16)
    tab.add_child(_dlg_name)
    var body := PanelContainer.new()
    var bsb: StyleBoxTexture = K.nine("dlg_body", 29, 0, 29, 0)
    if bsb != null:
        bsb.content_margin_left = 38
        bsb.content_margin_right = 38
        bsb.content_margin_top = 20
        bsb.content_margin_bottom = 14
        body.add_theme_stylebox_override("panel", bsb)
    else:
        body.add_theme_stylebox_override("panel", K.flat(Color(0.07, 0.06, 0.11, 0.95), K.CRIMSON))
    body.custom_minimum_size = Vector2(0, 120)
    stack.add_child(body)
    var vb := VBoxContainer.new()
    body.add_child(vb)
    _dlg_text = Label.new()
    _dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _dlg_text.custom_minimum_size = Vector2(550, 64)
    _dlg_text.add_theme_font_size_override("font_size", 17)
    vb.add_child(_dlg_text)
    _dlg_next = Label.new()
    _dlg_next.text = "▼ ketuk / tekan E"
    _dlg_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _dlg_next.add_theme_font_size_override("font_size", 11)
    _dlg_next.add_theme_color_override("font_color", Color(1, 0.6, 0.65, 0.8))
    vb.add_child(_dlg_next)


# ------------------------------------------------------------------ daftar jeda (tombol ||)
func _build_pause_list() -> void:
    pause_list = Control.new()
    pause_list.theme = K.make_theme()
    pause_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_list.mouse_filter = Control.MOUSE_FILTER_STOP
    pause_list.visible = false
    add_child(pause_list)
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.55)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pause_list.add_child(dim)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pause_list.add_child(center)
    var pc := PanelContainer.new()
    var sb: StyleBoxTexture = K.nine("ui_list", 14, 14, 14, 14)
    if sb != null:
        sb.content_margin_left = 22
        sb.content_margin_right = 22
        sb.content_margin_top = 22
        sb.content_margin_bottom = 22
        pc.add_theme_stylebox_override("panel", sb)
    else:
        pc.add_theme_stylebox_override("panel", K.flat(Color(0.07, 0.06, 0.11, 0.96), K.CRIMSON))
    pc.custom_minimum_size = Vector2(220, 0)
    center.add_child(pc)
    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 2)
    pc.add_child(vb)
    _qlog = Panels.QuestLog.new()
    _qlog.hud = self
    _qlog.visible = false
    add_child(_qlog)
    _wmap = Panels.WorldMap.new()
    _wmap.hud = self
    _wmap.visible = false
    add_child(_wmap)
    var rows := [["Tas", "bag"], ["Status", "stats"], ["Tugas", "quests"], ["Peta", "map"], ["Crafting", "craft"], ["Skin", "skin"], ["Simpan", "save"], ["Keluar", "exit"], ["Lanjutkan", "close"]]
    for rw in rows:
        var b := Button.new()
        b.text = String(rw[0])
        b.custom_minimum_size = Vector2(0, 40)
        b.add_theme_font_size_override("font_size", 17)
        b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
        var sel: StyleBoxTexture = K.nine("ui_list_sel", 24, 12, 24, 12)
        if sel != null:
            b.add_theme_stylebox_override("hover", sel)
            b.add_theme_stylebox_override("pressed", sel)
        b.pressed.connect(_pause_pick.bind(String(rw[1])))
        vb.add_child(b)


func open_pause_list() -> void:
    if _dlg.visible or menu.is_open:
        return
    Audio.sfx("select")
    pause_list.visible = true
    _update_pause()


func close_pause_list() -> void:
    pause_list.visible = false
    _block_t = 0.3
    _update_pause()


func _pause_pick(id: String) -> void:
    Audio.sfx("select")
    pause_list.visible = false
    match id:
        "close":
            _block_t = 0.3
            _update_pause()
        "save":
            menu._save_game()
            _block_t = 0.3
            _update_pause()
        "exit":
            menu._to_title()
        "quests":
            _qlog.open()
            _update_pause()
        "map":
            _wmap.open()
            _update_pause()
        _:
            open_menu(id)


func say(speaker: String, lines: Array, on_done: Callable = Callable()) -> void:
    if lines.is_empty():
        if on_done.is_valid():
            on_done.call()
        return
    _spk = speaker
    _spk_npc = _find_npc(speaker)
    _lines = _with_replies(lines)
    _line_i = 0
    _on_done = on_done
    _choose_cb = Callable()
    _show_line()
    _dlg.visible = true
    _dlg_choices.visible = false
    _choice_panel.visible = false
    _dlg_next.visible = true
    _debounce = 0.2
    _update_pause()


# Kilas balik: layar sepia, tanpa potret, teks digulir seperti dialog biasa
func flashback(title: String, lines: Array, on_done: Callable = Callable()) -> void:
    _flash = true
    _dim.color = Color(0.32, 0.2, 0.08, 0.86)
    say(title, lines, on_done)
    _spk_npc = null


func _find_npc(speaker: String):
    for n in get_tree().get_nodes_in_group("npcs"):
        if is_instance_valid(n) and "npc_name" in n and String(n.npc_name) == speaker:
            return n
    return null


func _with_replies(lines: Array) -> Array:
    if _spk_npc == null or lines.size() < 2:
        return lines
    for l in lines:
        if String(l).begins_with("@p:"):
            return lines
    var out: Array = []
    for i in lines.size():
        out.append(lines[i])
        if i % 2 == 0 and i < lines.size() - 1:
            out.append("@p:" + String(REACT[(i + _spk.length()) % REACT.size()]))
    return out


func player_name() -> String:
    return String(Game.p.get("name", "Petualang"))


func _show_line() -> void:
    var txt := String(_lines[_line_i])
    _spk_player = txt.begins_with("@p:")
    if _spk_player:
        txt = txt.substr(3)
    _dlg_name.text = player_name() if _spk_player else _spk
    _dlg_text.text = txt
    _dlg_text.visible_characters = 0
    _typing = 0.0


func choose(speaker: String, prompt: String, options: Array, on_pick: Callable) -> void:
    _lines = []
    _on_done = Callable()
    _choose_cb = on_pick
    _spk = speaker
    _spk_npc = _find_npc(speaker)
    _spk_player = false
    _dlg_name.text = speaker
    _dlg_text.text = prompt
    _dlg_text.visible_characters = -1
    for c in _dlg_choices.get_children():
        c.queue_free()
    for i in options.size():
        var b := Button.new()
        b.text = String(options[i])
        b.custom_minimum_size = Vector2(0, 36)
        b.pressed.connect(_pick.bind(i))
        _dlg_choices.add_child(b)
    _dlg_choices.visible = true
    _choice_panel.visible = true
    _dlg_next.visible = false
    _dlg.visible = true
    _debounce = 0.2
    _update_pause()


func _pick(i: int) -> void:
    Audio.sfx("select")
    var cb := _choose_cb
    _close_dialog(true)
    if cb.is_valid():
        cb.call(i)


func _close_dialog(block: bool) -> void:
    _dlg.visible = false
    _flash = false
    _dim.color = Color(0, 0, 0, 0.45)
    _lines = []
    if block:
        _block_t = 0.3
    _update_pause()


func _advance() -> void:
    if _dlg_text.visible_characters >= 0 and _dlg_text.visible_characters < _dlg_text.text.length():
        _dlg_text.visible_characters = -1
        return
    Audio.sfx("blip", 1.2)
    _line_i += 1
    if _line_i >= _lines.size():
        var cb := _on_done
        _close_dialog(true)
        if cb.is_valid():
            cb.call()
    else:
        _show_line()


func panel_closed() -> void:
    _block_t = 0.3
    _update_pause()


# Kastil sudah pernah didekati? (titik fast travel)
func castle_found(i: int) -> bool:
    var d = Game.p.get("fast", {})
    return typeof(d) == TYPE_DICTIONARY and d.has("%d_%d" % [world.world_id, i])


func _discover_castles() -> void:
    if world == null or player == null or not is_instance_valid(player) or world.has_meta("in_dungeon"):
        return
    for i in world.castles.size():
        if castle_found(i):
            continue
        var g: Vector2 = (world._castle_gate(i) + Vector2(0.5, 0.5)) * float(world.TILE)
        if player.global_position.distance_to(g) < 450.0:
            if typeof(Game.p.get("fast", null)) != TYPE_DICTIONARY:
                Game.p["fast"] = {}
            Game.p["fast"]["%d_%d" % [world.world_id, i]] = 1
            toast("Titik teleport ditemukan: Kastil %s" % String(world.BNAMES[int(world.castles[i]["biome"])]))
            show_banner("Peta: teleport Kastil %s terbuka" % String(world.BNAMES[int(world.castles[i]["biome"])]), 3.0)


func _input(event: InputEvent) -> void:
    if _qlog.visible or _wmap.visible:
        if event.is_action_pressed("pause"):
            _qlog.visible = false
            _wmap.visible = false
            panel_closed()
            get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M and not menu.is_open and not _dlg.visible and not pause_list.visible:
        _wmap.open()
        _update_pause()
        get_viewport().set_input_as_handled()
        return
    if pause_list.visible:
        if event.is_action_pressed("pause"):
            close_pause_list()
            get_viewport().set_input_as_handled()
        return
    if _dlg.visible and _choose_cb.is_null() and _debounce <= 0.0:
        var go := false
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            go = true
        elif event is InputEventKey and event.pressed and not event.echo:
            if event.is_action("interact") or event.is_action("attack") or event.keycode == KEY_ENTER:
                go = true
        if go:
            _debounce = 0.12
            _advance()
            get_viewport().set_input_as_handled()
            return
    if _dlg.visible or _block_t > 0.0:
        return
    if event.is_action_pressed("inventory") and not menu.is_open:
        open_menu("bag")
    elif event.is_action_pressed("pause") and not menu.is_open:
        open_menu("settings")


func _exit_tree() -> void:
    if fog != null:
        fog.flush()


func _process(delta: float) -> void:
    if _dlg != null and _dlg.visible and _port_l != null:
        _place_dialog(get_viewport().get_visible_rect().size)
    if fog != null and player != null and is_instance_valid(player):
        fog.tick(delta, player.global_position, world.has_meta("in_dungeon"))
    banner_t = maxf(banner_t - delta, 0.0)
    _block_t = maxf(_block_t - delta, 0.0)
    _debounce = maxf(_debounce - delta, 0.0)
    _disc_t += delta
    if _disc_t >= 0.7:
        _disc_t = 0.0
        _discover_castles()
    for t in toasts:
        t["life"] = float(t["life"]) - delta
    toasts = toasts.filter(func(t): return float(t["life"]) > 0.0)
    if _dlg.visible and _dlg_text.visible_characters >= 0:
        _typing += delta * 55.0
        _dlg_text.visible_characters = int(_typing)
        if _dlg_text.visible_characters >= _dlg_text.text.length():
            _dlg_text.visible_characters = -1
    _layout()
