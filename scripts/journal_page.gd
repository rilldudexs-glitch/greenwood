extends Node2D
# Tugu cahaya Aldric: tekan E untuk membaca halaman jurnal. Berkas cahaya menjulang ke langit supaya
# terlihat dari jauh (tugu yang belum dibaca). Tugu yang sedang dicari memunculkan panah di tepi layar saat dekat.
# Tidak masuk grup "lod" supaya cahayanya tetap tergambar walau di luar radius aktif; menggambar ulang hanya saat pemain dekat.

const Art = preload("res://scripts/art.gd")
const Journal = preload("res://scripts/journal.gd")

const SEE_R := 1300.0          # jarak (px) tempat tugu masih digambar & dianimasikan
const COMPASS_R := 1500.0      # jarak panah kompas mulai muncul

var page_id := "j1"
var biome := 1
var player
var world
var compass_col := Color(0.45, 0.9, 1.0)
var compass_range := COMPASS_R
var _t := randf() * 6.0
var _rd := 0
var _hint_ms := 0


func _ready() -> void:
    player = get_tree().get_first_node_in_group("player")
    add_to_group("compass_target")
    z_index = 1


func compass_on() -> bool:
    return Journal.target_id(world) == page_id


func _physics_process(delta: float) -> void:
    if player == null or not is_instance_valid(player):
        return
    var dist: float = global_position.distance_to(player.global_position)
    if dist > SEE_R:
        return
    _t += delta
    _rd += 1
    if _rd >= Perf.anim_div:
        _rd = 0
        queue_redraw()
    if player.dead or dist > 40.0:
        return
    var hud = get_tree().get_first_node_in_group("hud")
    if hud == null or hud.busy():
        return
    if Input.is_action_just_pressed("interact"):
        _read(hud)
        return
    if Time.get_ticks_msec() - _hint_ms > 3000:
        _hint_ms = Time.get_ticks_msec()
        hud.show_banner("Tekan E untuk membaca halaman jurnal" if not Journal.found(page_id) else "Halaman ini sudah kamu baca (E untuk membaca lagi)", 2.0)


func _read(hud) -> void:
    var d: Dictionary = Journal.get_def(page_id)
    var lines: Array = [String(d["title"])] + (d["lines"] as Array)
    var nid: String = Journal.next_id(world, page_id)
    if nid != "":
        var nd: Dictionary = Journal.get_def(nid)
        var np = _page_node(nid)
        if np != null:
            var v: Vector2 = np.global_position - global_position
            lines.append("Tugu berikutnya ada di %s, ke arah %s dari sini, sekitar %d langkah." % [String(world.BNAMES[int(nd["biome"])]), Journal.dir_name(v), int(v.length() / 32.0)])
    else:
        lines.append("Di bawah tugu ini, Aldric menyimpan sisa hartanya.")
    hud.say("Jurnal Aldric", lines, _after_read.bind(hud))


func _page_node(id: String):
    for n in get_tree().get_nodes_in_group("compass_target"):
        if n.get("page_id") != null and String(n.page_id) == id:
            return n
    return null


func _after_read(hud) -> void:
    var res: Dictionary = Journal.mark(page_id, player, world)
    if not bool(res["first"]):
        return
    Audio.sfx("win")
    hud.toast(String(res["msg"]))
    if String(res["banner"]) != "":
        hud.show_banner(String(res["banner"]), 4.0)
    # petunjuk: kabut peta terbuka samar di sekitar tugu berikutnya (bergeser supaya lokasinya tidak persis)
    var nid: String = Journal.next_id(world, page_id)
    var np = _page_node(nid) if nid != "" else null
    if np != null and hud.fog != null:
        var h1: float = float((absi(hash(nid)) % 1000)) / 1000.0
        var h2: float = float((absi(hash(nid + "y")) % 1000)) / 1000.0
        var off := Vector2((h1 - 0.5) * 2.0, (h2 - 0.5) * 2.0) * 7.0 * 32.0
        hud.fog.reveal_area(np.global_position + off, 11.0)
        hud.show_banner("Sebagian peta terbuka: tugu berikutnya ada di sekitar sana", 3.0)


func _draw() -> void:
    var read: bool = Journal.found(page_id)
    var glow: Color = Color(0.45, 0.85, 1.0) if read else Color(1.0, 0.82, 0.3)
    var f: float = sin(_t * 2.2) * 0.5 + 0.5
    # berkas cahaya (hanya tugu yang belum dibaca): menjulang ke atas, memudar
    if not read:
        var top := -980.0
        var w0: float = 15.0 + f * 3.0
        var pts := PackedVector2Array([Vector2(-w0, -20), Vector2(w0, -20), Vector2(w0 * 0.35, top), Vector2(-w0 * 0.35, top)])
        var cols := PackedColorArray([Color(glow.r, glow.g, glow.b, 0.34), Color(glow.r, glow.g, glow.b, 0.34), Color(glow.r, glow.g, glow.b, 0.0), Color(glow.r, glow.g, glow.b, 0.0)])
        draw_polygon(pts, cols)
        var w1: float = 5.0 + f * 1.5
        var pts2 := PackedVector2Array([Vector2(-w1, -20), Vector2(w1, -20), Vector2(0.0, top * 0.8)])
        var cols2 := PackedColorArray([Color(1, 1, 0.9, 0.5), Color(1, 1, 0.9, 0.5), Color(1, 1, 0.9, 0.0)])
        draw_polygon(pts2, cols2)
    Art.shadow(self, 20.0, 9.0)
    # alas batu bundar
    Art.ellipse(self, Vector2(0, 6), 26.0, 11.0, Color(0.30, 0.29, 0.31), 14)
    Art.ellipse(self, Vector2(0, 4), 20.0, 8.0, Color(0.38, 0.37, 0.40), 14)
    # tugu (obelisk)
    draw_colored_polygon(PackedVector2Array([Vector2(-9, 4), Vector2(-7, -34), Vector2(0, -44), Vector2(7, -34), Vector2(9, 4)]), Color(0.27, 0.27, 0.32))
    draw_colored_polygon(PackedVector2Array([Vector2(1, 4), Vector2(1, -43), Vector2(7, -34), Vector2(9, 4)]), Color(0.20, 0.20, 0.25))
    draw_line(Vector2(-7, -34), Vector2(0, -44), Color(1, 1, 1, 0.2), 1.5)
    # rune bercahaya
    for i in 5:
        var y: float = -32.0 + float(i) * 7.0
        draw_line(Vector2(-4, y), Vector2(3, y + (2.0 if i % 2 == 0 else -2.0)), Color(glow.r, glow.g, glow.b, 0.5 + f * 0.4), 2.0)
    # kristal melayang di puncak
    var bob: float = sin(_t * 1.6) * 3.0
    draw_colored_polygon(PackedVector2Array([Vector2(0, -66 + bob), Vector2(6, -57 + bob), Vector2(0, -48 + bob), Vector2(-6, -57 + bob)]), Color(glow.r, glow.g, glow.b, 0.95))
    draw_circle(Vector2(0, -57 + bob), 16.0 + f * 4.0, Color(glow.r, glow.g, glow.b, 0.10 if read else 0.16))
