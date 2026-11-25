extends RefCounted
# Pembantu panel HUD: bingkai layar penuh dan teks daftar tugas.

const K = preload("res://scripts/ui_kit.gd")
const Story = preload("res://scripts/story.gd")
const Secrets = preload("res://scripts/secrets.gd")
const Sidequests = preload("res://scripts/sidequests.gd")
const Plot = preload("res://scripts/plot.gd")
const Jobs = preload("res://scripts/jobs.gd")


static func _frame(root: Control) -> PanelContainer:
    root.theme = K.make_theme()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    root.visible = false
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.7)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(dim)
    var pc := PanelContainer.new()
    pc.add_theme_stylebox_override("panel", K.flat(Color(0.07, 0.06, 0.11, 0.97), K.CRIMSON))
    return pc


static func quest_text(pl) -> String:
    var t := ""
    t += "[color=#ffd479][b]Kisah Utama[/b][/color]\n"
    if Story.finished():
        t += "Tamat. Kembalilah ke Tetua Oren kapan saja.\n"
    else:
        var c: Dictionary = Story.cur()
        t += "[b]%s[/b]\n" % String(c["title"])
        if not Story.accepted():
            t += "Temui %s untuk memulai.\n" % Story.npc_name(Story.giver())
        else:
            t += "%s\n" % Story.progress_text()
        t += "Lokasi: %s (level saran %d)\n" % [String(c["where"]), int(c["rec"])]
    if Plot.twist_ready():
        t += "[color=#ff9955]Tetua Oren ingin bicara denganmu.[/color]\n"
    if Plot.ending_pending():
        t += "[color=#ff9955]Pilihan akhir menantimu. Temui Tetua Oren.[/color]\n"
    var q: Dictionary = Game.p["quest"]
    t += "\n[color=#ffd479][b]Tugas Harian[/b][/color]\n"
    if String(q["type"]) == "none":
        t += "Belum ada. Ambil dari Tetua Oren.\n"
    else:
        t += "%s (%d/%d)\n" % [String(q["label"]), int(q["have"]), int(q["need"])]
    t += "\n[color=#ffd479][b]Tugas Warga[/b][/color]\n"
    var done := 0
    var shown := 0
    for b in Sidequests.NPC.keys():
        var role := "sq_%d" % int(b)
        var sq: Dictionary = Sidequests.s(role)
        done += int(sq["st"])
        if int(sq["st"]) >= 3:
            continue
        var nm: String = String(Sidequests.NPC[b][0])
        var bn: String = String(Story.BIOME_NAMES.get(int(b), "?"))
        if bool(sq["on"]):
            shown += 1
            var mark := "[color=#80ff80]" if Sidequests.is_complete(role, pl) else "[color=#ffffff]"
            t += "• %s%s[/color] (%s): %s\n" % [mark, nm, bn, Sidequests.goal_text(role, pl)]
        elif Story.visited(int(b)):
            shown += 1
            t += "• [color=#aaaaaa]%s di %s: belum diambil[/color]\n" % [nm, bn]
    if shown == 0:
        t += "Tidak ada tugas aktif.\n"
    t += "Selesai: %d/%d tahap\n" % [done, Sidequests.NPC.size() * 3]
    t += "\n[color=#ffd479][b]Misteri Akar[/b][/color]\n"
    t += "Kepingan Kebenaran: %d/13\n" % Secrets.truth_count()
    var any := false
    for id in Secrets.DATA.keys():
        if Secrets.accepted(id) and not Secrets.finished(id):
            any = true
            t += "• %s: %s\n" % [String(Secrets.DATA[id]["name"]), Secrets.progress_text(id, pl)]
    if not any:
        t += "Tidak ada quest rahasia aktif. Jelajahi biome dan perhatikan malam, bulan merah, dan gua.\n"
    var j: String = Jobs.cur()
    if j != "":
        t += "\n[color=#ffd479][b]Job[/b][/color]\n%s\n" % Jobs.name_of(j)
        var av: Array = Jobs.available()
        if not av.is_empty():
            t += "[color=#ff9955]Jalan Warisan siap diambil di Tetua Oren.[/color]\n"
    return t
