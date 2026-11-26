extends Node
# Smoke test: memuat adegan utama, menunggu dunia selesai di-bake, memunculkan semua jenis musuh,
# membunuh mereka, menguji quest rahasia dan tebang pohon. Jalankan:
#   godot --headless --path . res://tests/smoke.tscn
# Keluaran harus berisi "SMOKE_OK" dan tidak boleh ada "SCRIPT ERROR".

const Secrets = preload("res://scripts/secrets.gd")
var _spawned: Array = []
var main
var frames := 0
var step := 0
var wait := 0
var kinds: Array = []
var fails := 0
var goblin_before := 0


func _ready() -> void:
    Game.new_game("Tester", "m")
    _test_raven()
    _test_gear()
    _test_balance()
    _test_progress()
    main = load("res://scenes/main.tscn").instantiate()
    get_tree().root.add_child.call_deferred(main)
    _set_scene.call_deferred()


func _test_progress() -> void:
    const Prog = preload("res://scripts/progress.gd")
    const Dg = preload("res://scripts/dungeon.gd")
    Game.p["level"] = 60
    check(Prog.free_points() == 15, "poin skill salah")
    check(Prog.up("pow") and Prog.rank("pow") == 1, "naik rank gagal")
    check(Prog.st_mul("melee") > 1.0 and Prog.skill_dmg() == 1.0, "pengali skill tree salah")
    Prog.reset()
    check(Prog.spent() == 0, "reset skill gagal")
    var fresh: Array = Prog.check()
    check(fresh.size() >= 2 and Prog.is_done("lv10"), "achievement level tidak terbuka")
    Prog.set_title("lv10")
    check(Prog.title_text() == "Pemula", "gelar gagal")
    check(Prog.mob_table().size() >= 10 and Prog.biome_names().size() >= 15, "bestiary tabel kosong")
    Game.p["coins"] = 100000
    Game.p["gems"] = 100
    var sw: String = String(Game.p["sword"])
    check(Prog.ench_try(sw) == "sukses" and Prog.ench(sw) == 1 and Prog.st_mul("melee") > 1.0, "tempa gagal")
    check(Game.export_text() != "" and Game.import_text(Game.export_text()), "backup save gagal")
    var d = Dg.new()
    d.id = "menara"
    Game.p["tower_cur"] = 7
    var def: Dictionary = d._tower_def()
    check(int(def["boss"]["hp"]) > 0 and int(def["lo"]) >= 1 and def["gen"] != "", "def menara salah")
    d.free()
    Game.new_game("Tester", "m")


func _test_balance() -> void:
    const Bal = preload("res://scripts/balance.gd")
    var prev := 0
    for lv in range(1, Bal.LV_MAX + 1):
        var n: int = Bal.xp_needed(lv)
        check(n > prev, "XP tidak naik di level %d" % lv)
        prev = n
        check(Bal.mob_hp(lv, 300) <= Bal.MOB_HP_CAP, "HP monster melebihi batas di level %d" % lv)
        check(Bal.player_scale(lv) >= 1.0 and Bal.mob_xp(lv, 6) >= 1, "skala level %d tidak valid" % lv)
    check(Bal.BOSS_HP.size() == Bal.BOSS_LEVEL.size() and Bal.BOSS_HP.size() == 4, "data bos tidak lengkap")
    print("BALANCE xp L10/30/60: ", Bal.xp_needed(10), " ", Bal.xp_needed(30), " ", Bal.xp_needed(60),
        "  slime hp L1/30/60: ", Bal.mob_hp(1, 30), " ", Bal.mob_hp(30, 30), " ", Bal.mob_hp(60, 30))


func _test_gear() -> void:
    var bad := 0
    var total := 0
    for kind in Gear.W_COUNT.keys():
        for i in int(Gear.W_COUNT[kind]):
            for r in 7:
                var id: String = Gear.make_id_weapon(kind, i, r)
                var d: Dictionary = Items.info(id)
                total += 1
                if int(d.get("rarity", -1)) != r or not d.has("gi") or not Items.is_equipment(id):
                    bad += 1
    for set_id in Gear.BIOMES:
        for slot in Gear.A_SLOTS:
            for i in 18:
                for r in 7:
                    var id2: String = Gear.make_id_armor(set_id, slot, i, r)
                    var d2: Dictionary = Items.info(id2)
                    total += 1
                    if int(d2.get("rarity", -1)) != r or String(d2.get("slot", "")) != slot or not d2.has("gi"):
                        bad += 1
    check(bad == 0, "Gear: %d dari %d item tidak valid" % [bad, total])
    var counts := [0, 0, 0, 0, 0, 0, 0]
    for i in 3000:
        var gid: String = Gear.roll_gear(randi() % 5, 1)
        var gd: Dictionary = Items.info(gid)
        check(gd.has("gi"), "Gear roll tidak valid: " + gid)
        if gd.has("rarity"):
            counts[int(gd["rarity"])] += 1
    print("GEAR rarity (3000 undian): ", counts, " total item diuji: ", total)
    check(Gear._sheet("w") != null and Gear._sheet("a") != null, "Gear: atlas gagal dimuat")


func _test_raven() -> void:
    var bad := 0
    for cat in Raven.DB.GEAR.keys():
        for e in Raven.DB.GEAR[cat]:
            for r in 7:
                var id: String = Raven.make_id(int(e[0]), r)
                var d: Dictionary = Items.info(id)
                if int(d.get("rarity", -1)) != r or not Items.is_equipment(id):
                    bad += 1
    check(bad == 0, "Raven: %d item tidak valid" % bad)
    var counts := [0, 0, 0, 0, 0, 0, 0]
    for i in 3000:
        var id2: String = Raven.roll_gear(randi() % 5, 1)
        var d2: Dictionary = Items.info(id2)
        check(d2.has("icon"), "Raven roll tidak valid: " + id2)
        if d2.has("rarity"):
            counts[int(d2["rarity"])] += 1
    print("RAVEN rarity (3000 undian): ", counts)
    check(Raven.icon(1) != null and Raven.icon(2192) != null, "Raven icon null")


func _set_scene() -> void:
    get_tree().current_scene = main


func check(ok: bool, msg: String) -> void:
    if not ok:
        fails += 1
        print("FAIL: ", msg)


func _process(_d: float) -> void:
    if main == null or not main.is_inside_tree():
        return
    frames += 1
    if wait > 0:
        wait -= 1
        return
    var pl = get_tree().get_first_node_in_group("player")
    match step:
        0:
            if main.world.baked:
                check(main._loading == null, "loading overlay harus hilang")
                kinds = load("res://scripts/enemy.gd").BASE.keys()
                for i in kinds.size():
                    for b in [1, 2, 3, 4]:
                        var e = main.spawn_mob(String(kinds[i]), b, pl.global_position + Vector2(40 + i * 12, 30 + b * 10))
                        e.hp = 3
                        _spawned.append(e)
                step = 1
                wait = 90
            elif frames > 600:
                check(false, "bake tidak selesai")
                step = 9
        1:
            for e in _spawned:
                if is_instance_valid(e) and not e.is_in_group("boss"):
                    e.take_damage(999999, Vector2.RIGHT)
            step = 2
            wait = 10
        2:
            var left := 0
            for e in _spawned:
                if is_instance_valid(e) and not e.is_in_group("boss") and not e.is_queued_for_deletion():
                    left += 1
                    print("  sisa: ", e.kind, " hp=", e.hp, " groups=", e.get_groups())
            check(left == 0, "semua musuh harus mati, sisa %d" % left)
            # quest rahasia: Marni tahap 1 -> 2 -> peti
            Secrets.accept("marni")
            check(not Secrets.is_complete("marni", pl), "belum lengkap")
            pl.add_item("egg", 3)
            pl.add_item("milk", 2)
            check(Secrets.is_complete("marni", pl), "tahap 1 harus lengkap")
            Secrets.complete("marni", pl)
            check(Secrets.stage("marni") == 1 and pl.count("egg") == 0, "maju ke tahap 2")
            Secrets.accept("marni")
            pl.add_item("scrap", 4)
            Secrets.complete("marni", pl)
            check(Secrets.finished("marni"), "marni selesai")
            main.spawn_secret_chest("marni", true)
            # quest bunuh
            Secrets.accept("zahra")
            goblin_before = Game.kill_count("goblin")
            for i in 6:
                Game.count_kill("goblin")
            check(Secrets.is_complete("zahra", pl), "zahra tahap 1 (kill)")
            # tebang pohon -> patch chunk + tabrakan dibangun ulang
            var w = main.world
            var tc := Vector2i(-1, -1)
            for y in range(40, 60):
                for x in range(20, 40):
                    if w.kind[w.idx(x, y)] == w.K.TREE:
                        tc = Vector2i(x, y)
            check(tc.x >= 0, "ada pohon untuk diuji")
            if tc.x >= 0:
                for i in 6:
                    w.hit_cell(tc)
                check(w.kind[w.idx(tc.x, tc.y)] != w.K.TREE, "pohon harus berubah jadi tunggul")
            step = 3
            wait = 30
        3:
            # simpan & muat ulang data
            Game.save()
            var ok: bool = Game.load_save()
            print("  load=", ok, " marni=", Secrets.stage("marni"), " goblin=", Game.kill_count("goblin"), " secrets=", Game.p["secrets"])
            check(ok and Secrets.finished("marni") and Game.kill_count("goblin") == goblin_before + 6, "save/load quest rahasia")
            print("SMOKE_%s kinds=%d fails=%d fps=%d" % ["OK" if fails == 0 else "FAIL", kinds.size(), fails, Engine.get_frames_per_second()])
            get_tree().quit(0 if fails == 0 else 1)
        9:
            print("SMOKE_FAIL")
            get_tree().quit(1)
