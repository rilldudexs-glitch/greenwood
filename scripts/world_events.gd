extends Node
# Event dunia acak di dunia terbuka:
#  - Bulan Darah: sebagian malam. Langit memerah, monster tambahan muncul di sekitarmu dan memukul lebih keras,
#    tapi koin & XP dari monster lebih banyak. Berakhir saat fajar (main.blood_moon dibaca enemy.gd).
#  - Meteor: tiap beberapa menit sebuah meteor jatuh di wilayah tempat pemain berada. Ada penjaga di sekitarnya,
#    hadiahnya pecahan langka. Panah di tepi layar menuntun ke sana (lihat meteor.gd).
# Hanya berjalan di host / main-sendiri (klien co-op tidak membuat monster).

const MeteorScript = preload("res://scripts/meteor.gd")
const Journal = preload("res://scripts/journal.gd")

const BM_CHANCE := 0.25          # peluang Bulan Darah tiap malam
const BM_MAX_MOBS := 7           # monster tambahan maksimum sekaligus
const BM_SPAWN_EVERY := 7.0
const METEOR_MIN := 300.0        # detik bermain antar meteor
const METEOR_MAX := 540.0

var main
var player
var world
var atmos
var blood_moon := false
var _enabled := true
var _night_rolled := false
var _bm_mobs: Array = []
var _bm_t := 5.0
var _meteor_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(m, pl, w, a) -> void:
    main = m
    player = pl
    world = w
    atmos = a
    add_to_group("events")
    _rng.randomize()
    _enabled = not (Net.active and not Net.is_host)
    _meteor_t = _rng.randf_range(150.0, 270.0)       # meteor pertama datang lebih cepat


func _process(delta: float) -> void:
    if not _enabled or main == null or player == null or not is_instance_valid(player):
        return
    if main.get("_loading") != null:
        return
    var in_dg: bool = main.dungeon != null
    # --- Bulan Darah
    var night: bool = atmos.is_night()
    if not in_dg:
        if night and not _night_rolled:
            _night_rolled = true
            if _rng.randf() < BM_CHANCE:
                _start_bm()
        elif not night:
            _night_rolled = false
            if blood_moon:
                _end_bm()
    atmos.blood_k = move_toward(atmos.blood_k, 1.0 if (blood_moon and not in_dg) else 0.0, delta * 0.4)
    if blood_moon and not in_dg:
        _bm_tick(delta)
    # --- Meteor (tidak di dalam gua / di desa)
    if not in_dg:
        _meteor_t -= delta
        if _meteor_t <= 0.0:
            _meteor_t = _rng.randf_range(METEOR_MIN, METEOR_MAX)
            _drop_meteor()


# ------------------------------------------------------------------ Bulan Darah
func _start_bm() -> void:
    blood_moon = true
    main.blood_moon = true
    var hud = get_tree().get_first_node_in_group("hud")
    if hud:
        hud.show_banner("Bulan Darah terbit! Monster mengamuk, tapi hadiahnya lebih besar", 4.0)
    Audio.sfx("boss_roar", 0.7)


func _end_bm() -> void:
    blood_moon = false
    main.blood_moon = false
    for e in _bm_mobs:
        if is_instance_valid(e):
            e.queue_free()
    _bm_mobs = []
    var hud = get_tree().get_first_node_in_group("hud")
    if hud:
        hud.show_banner("Fajar tiba. Bulan Darah mereda", 3.0)


func _bm_tick(delta: float) -> void:
    _bm_t -= delta
    if _bm_t > 0.0:
        return
    _bm_t = BM_SPAWN_EVERY
    _bm_mobs = _bm_mobs.filter(func(e): return is_instance_valid(e))
    if _bm_mobs.size() >= BM_MAX_MOBS or world.biome_at(player.global_position) == 0:
        return
    var e = _spawn_near(player.global_position, 380.0, 560.0)
    if e != null:
        _bm_mobs.append(e)


# Tiru satu monster biasa di dekat 'ref' lalu munculkan salinannya di cincin r0..r1 dari 'center'
func _spawn_near(center: Vector2, r0: float, r1: float):
    var tpl = _template(center)
    if tpl == null:
        return null
    for i in 14:
        var pos: Vector2 = center + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(r0, r1)
        var c: Vector2i = world.cell_of(pos)
        if not world.in_bounds(c) or world.is_solid_cell(c):
            continue
        if world.biome_at(pos) != int(tpl.biome_idx):
            continue
        var safe := false
        for z in world.safe_zones:
            if (z as Rect2i).has_point(c):
                safe = true
                break
        if safe:
            continue
        return main.spawn_mob(String(tpl.kind), int(tpl.biome_idx), pos, int(tpl.level))
    return null


func _template(ref: Vector2):
    var pool: Array = []
    var rb: int = world.biome_at(ref)
    for e in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(e) or e.is_in_group("boss") or bool(e.get("is_mini")) or bool(e.get("passive")):
            continue
        if int(e.biome_idx) == rb and e.global_position.distance_to(ref) < 4500.0:
            pool.append(e)
    if pool.is_empty():
        return null
    return pool[_rng.randi() % pool.size()]


# ------------------------------------------------------------------ Meteor
func _drop_meteor() -> void:
    if get_tree().get_nodes_in_group("meteor").size() > 0:
        return
    var b: int = world.biome_at(player.global_position)
    if b == 0:
        # di desa: pilih biome acak dunia ini
        var opts: Array = []
        for bi in world.open_by_biome.size():
            if bi > 0 and world.has_biome(bi) and not (world.open_by_biome[bi] as Array).is_empty():
                opts.append(bi)
        if opts.is_empty():
            return
        b = int(opts[_rng.randi() % opts.size()])
    var lst: Array = world.open_by_biome[b]
    if lst.is_empty():
        return
    var pos := Vector2.ZERO
    var ok := false
    for i in 60:
        var p: Vector2 = world.cell_center(lst[_rng.randi() % lst.size()])
        var d: float = p.distance_to(player.global_position)
        if d >= 1100.0 and d <= 2600.0:
            pos = p
            ok = true
            break
    if not ok:
        _meteor_t = 45.0        # coba lagi sebentar lagi
        return
    var m = MeteorScript.new()
    m.biome = b
    m.position = pos
    main.entities.add_child(m)
    var hud = get_tree().get_first_node_in_group("hud")
    if hud:
        var v: Vector2 = pos - player.global_position
        hud.show_banner("Meteor jatuh di %s! Arah %s, sekitar %d langkah" % [String(world.BNAMES[b]), Journal.dir_name(v), int(v.length() / 32.0)], 4.0)
    # penjaga di sekitar kawah
    for i in 3:
        _spawn_near(pos, 90.0, 220.0)
