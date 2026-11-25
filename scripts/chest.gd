extends Node2D
# Peti harta: terbuka otomatis saat didekati. Isi: koin, permata, bahan, ramuan.

const Art = preload("res://scripts/art.gd")

var uid := 0
var secret := ""   # id quest rahasia (kosong = peti biasa)
var opened := false
var biome_idx := 1
var player
var _open_t := 0.0


func _ready() -> void:
    player = get_tree().get_first_node_in_group("player")
    add_to_group("lod")
    _open_t = 1.0 if opened else 0.0


func _physics_process(delta: float) -> void:
    if opened:
        _open_t = minf(_open_t + delta * 4.0, 1.0)
        queue_redraw()
        return
    if player == null or player.dead:
        return
    if global_position.distance_to(player.global_position) < 22.0:
        _open()


func _open() -> void:
    opened = true
    Audio.sfx("chest")
    var main = get_tree().current_scene
    var luk: int = int(player.stat("luk"))
    main.spawn_pickup("coin", global_position + Vector2(0, 14), 15 + biome_idx * 10)
    main.spawn_pickup("gems", global_position + Vector2(10, 16), randi_range(5, 12) + biome_idx * 2 + luk / 3)
    if secret != "":
        main.spawn_pickup("coin", global_position + Vector2(-10, 16), 120)
        main.spawn_pickup("gems", global_position + Vector2(14, 12), randi_range(30, 50))
        main.spawn_pickup("item:potion_hp2", global_position + Vector2(-14, 22), 2)
        main.spawn_pickup("item:potion_mp2", global_position + Vector2(14, 24), 1)
        main.fx_text(global_position + Vector2(0, -22), "Peti Rahasia!", Color(0.85, 0.6, 1.0), 16.0)
    var pools := [
        ["log", "stone", "copper", "honey", "leather"],
        ["iron", "log", "leather", "feather", "copper"],
        ["gold", "iron", "amber", "sunshard", "leather"],
        ["crystal", "iron", "shard", "frost", "leather"],
        ["ruby", "coal", "obsidian", "iron", "horn"],
        # biome ekspansi (5-14), memakai ulang material yang sudah ada
        ["obsidian", "coal", "crystal", "ruby", "iron"],
        ["crystal", "gold", "obsidian", "shard", "ruby"],
        ["crystal", "frost", "shard", "gold", "venom"],
        ["log", "copper", "crystal", "honey", "feather"],
        ["log", "crystal", "honey", "feather", "leather"],
        ["copper", "goo", "venom", "crystal", "leather"],
        ["crystal", "gold", "shard", "sunshard", "feather"],
        ["gold", "amber", "obsidian", "iron", "coal"],
        ["crystal", "shard", "gold", "frost", "amber"],
        ["log", "copper", "crystal", "gold", "horn"],
    ]
    var pool: Array = pools[clampi(biome_idx, 0, pools.size() - 1)]
    var extra: int = int(maxi(biome_idx - 4, 0) / 3.0)         # biome jauh = bahan lebih banyak
    for i in 3:
        main.spawn_pickup("item:" + String(pool[randi() % pool.size()]), global_position + Vector2(randf_range(-20, 20), randf_range(8, 24)), randi_range(1, 3 + extra))
    # perlengkapan Raven: 30% peti biasa, peti rahasia pasti dapat (minimal Rare)
    if randf() < 0.3 or secret != "":
        main.spawn_pickup("item:" + Gear.roll_gear(biome_idx, luk, 2 if secret != "" else 0), global_position + Vector2(0, 26), 1)
    if randf() < 0.6:
        main.spawn_pickup("item:potion_hp", global_position + Vector2(-12, 22), 1)
    if randf() < 0.4:
        main.spawn_pickup("item:potion_mp", global_position + Vector2(12, 22), 1)
    main.fx_burst(global_position, Color(1.0, 0.9, 0.4), 14, 70.0, 0.6, 30.0, 2.5, "star")
    if not Game.chests_opened.has(uid):
        Game.chests_opened.append(uid)
    queue_redraw()


func _draw() -> void:
    Art.shadow(self, 10.0, 11.0)
    var wood := Color(0.55, 0.34, 0.16)
    var band := Color(0.9, 0.75, 0.3)
    Art.rect(self, -10, -2, 20, 12, wood)
    Art.rect(self, -10, 3, 20, 2, band)
    Art.rect(self, -1.5, 2, 3, 4, Color(0.3, 0.2, 0.1))
    var lift: float = _open_t * 9.0
    Art.rect(self, -10, -9 - lift * 0.3, 20, 8, wood.lightened(0.15))
    Art.rect(self, -10, -5 - lift * 0.3, 20, 2, band)
    if _open_t > 0.3:
        Art.rect(self, -8, -3, 16, 4, Color(1.0, 0.9, 0.4, 0.8))
