extends CharacterBody2D
# Bos dunia terbuka (opsional). Tiap bos punya gaya & jurus sendiri:
# ent (Ent Kuno), scorpion (Ratu Kalajengking), yeti (Yeti Perkasa), dragon (Naga Api).

const Art = preload("res://scripts/art.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Bal = preload("res://scripts/balance.gd")
const Story = preload("res://scripts/story.gd")
const Secrets = preload("res://scripts/secrets.gd")
const Plot = preload("res://scripts/plot.gd")
const BossLines = preload("res://scripts/boss_lines.gd")
const BossSprites = preload("res://scripts/boss_sprites.gd")  # atlas 64x64 hasil tools/gen_boss_sprites.py

const DRAW_SCALE := 1.5     # 64px -> 96px di layar
const SPRITE_FOOT := 26.0   # posisi kaki sprite (y lokal), sejajar bayangan
const DEATH_TIME := 1.4     # lama animasi mati sebelum node dihapus
# jurus -> animasi serangan (default "attack"). Kalajengking punya 3 animasi serangan.
const ATTACK_ANIM := {
    "scorpion": {"charge": "claw", "spray": "storm", "slam": "tail"},
    "sakura": {"slam": "slash", "charge": "slash", "aimed": "flower", "ring": "flower", "summon": "flower", "breath": "flower"},
    "verdant": {"slam": "melee", "charge": "melee", "aimed": "spirit", "ring": "spirit", "summon": "spirit", "breath": "spirit"},
    "leviathan": {"charge": "bite", "aimed": "bite", "breath": "bite", "slam": "whirl", "ring": "whirl", "summon": "whirl"},
    "unwritten": {"slam": "melee", "charge": "melee", "aimed": "cast", "ring": "cast", "summon": "cast", "breath": "cast"},
    "warden": {"slam": "melee", "charge": "melee", "aimed": "cast", "ring": "cast", "summon": "cast", "breath": "cast"},
}

const MOVES := {
    "ent": ["slam", "aimed", "summon", "slam"],
    "scorpion": ["charge", "spray", "slam", "charge"],
    "yeti": ["slam", "ring", "charge", "aimed"],
    "dragon": ["breath", "ring", "charge", "summon", "aimed"],
    "warden": ["slam", "aimed", "ring", "charge", "summon"],
    "unwritten": ["slam", "ring", "aimed", "summon"],
    "leviathan": ["charge", "ring", "breath", "slam", "aimed"],
    "verdant": ["slam", "aimed", "summon", "ring"],
    "sakura": ["slam", "ring", "charge", "aimed"],
    "myconid": ["slam", "summon", "aimed", "ring"],
    "ether": ["ring", "aimed", "summon", "charge", "slam"],
    "monarch": ["charge", "spray", "slam", "summon"],
    "lumina": ["ring", "aimed", "summon", "slam", "charge"],
    "colossus": ["slam", "ring", "charge", "summon", "aimed"],
    "devourer": ["slam", "ring", "spray", "charge", "summon", "aimed"],
}
const COLORS := {"ent": Color(0.5, 0.9, 0.3), "scorpion": Color(1.0, 0.6, 0.2), "yeti": Color(0.6, 0.9, 1.0), "dragon": Color(1.0, 0.4, 0.15), "warden": Color(0.62, 0.3, 1.0), "unwritten": Color(0.45, 0.55, 1.0), "leviathan": Color(0.2, 0.65, 1.0), "verdant": Color(0.4, 0.95, 0.35), "sakura": Color(1.0, 0.5, 0.75), "myconid": Color(0.9, 0.35, 0.3), "ether": Color(1.0, 0.85, 0.4), "monarch": Color(0.9, 0.15, 0.25), "lumina": Color(0.35, 0.75, 1.0), "colossus": Color(0.3, 0.95, 0.55), "devourer": Color(0.7, 0.3, 1.0)}

var style := "ent"
var boss_name := "Ent Kuno"
var biome_idx := 1
var max_hp := 800
var hp := 800
var speed := 46.0
var radius := 26.0
var dmg := 18
var xp_reward := 200
var level := 1
var lair := Vector2.ZERO
var active := false
var player
var _dmg_base := -1
var _gap_t := 0.0

var _state := "idle"
var _t := 1.5
var _dir := Vector2.ZERO
var _move := ""
var _shots := 0
var _shot_t := 0.0
var _flash := 0.0
var _touch_cd := 0.0
var _anim := 0.0
var _face := 1.0
var _look := Vector2.DOWN     # arah hadap bos (untuk sprite 4 arah seperti Warden)
var _atk := 0.0
var _hud
var _p2_said := false          # kalimat fase 2 hanya diucapkan sekali per pertarungan
var _target := Vector2.ZERO
var _tex: Texture2D = null
var _sheet: Dictionary = {}
var _hurt := 0.0
var _dead := false
var _dead_t := 0.0
# co-op (lihat net.gd): host menjalankan AI bos; di HP klien bos adalah "puppet" yang hanya digambar
var net_id := 0
var puppet := false
var _net_pos := Vector2.ZERO
var _last_hud_hp := -1
var _rt_t := 0.0


func _ready() -> void:
    add_to_group("enemies")
    add_to_group("boss")
    motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
    player = get_tree().get_first_node_in_group("player")
    _hud = get_tree().get_first_node_in_group("hud")
    hp = max_hp
    lair = global_position
    var cs := CollisionShape2D.new()
    var sh := CircleShape2D.new()
    sh.radius = 14.0
    cs.shape = sh
    add_child(cs)
    collision_layer = 4
    collision_mask = 1
    if puppet:
        collision_layer = 0
        collision_mask = 0
        _net_pos = global_position
    elif Net.active and Net.is_host:
        net_id = Net.register(self)
    _load_sprites()


# ------------------------------------------------------------------ co-op
func net_spawn_info() -> Dictionary:
    return {"t": "boss", "id": net_id, "style": style, "bname": boss_name, "biome": biome_idx, "lv": level, "mhp": max_hp,
        "dmg": dmg, "xp": xp_reward, "x": global_position.x, "y": global_position.y}


# [id, x, y, hp, atk, face, state]
func net_snapshot() -> PackedFloat32Array:
    return PackedFloat32Array([float(net_id), global_position.x, global_position.y, float(hp), _atk, _face,
        float(maxi(Net.BOSS_STATES.find(_state), 0))])


func net_apply(x: float, y: float, h: float, atk: float, face: float, st: int) -> void:
    _net_pos = Vector2(x, y)
    hp = int(h)
    _atk = atk
    _face = face
    _state = String(Net.BOSS_STATES[clampi(st, 0, Net.BOSS_STATES.size() - 1)])


func net_kill() -> void:
    hp = 0
    _die()


func _puppet_step(delta: float) -> void:
    _anim += delta
    _flash = maxf(_flash - delta, 0.0)
    _hurt = maxf(_hurt - delta, 0.0)
    if _dead:
        _dead_t += delta
        velocity = Vector2.ZERO
        queue_redraw()
        if _dead_t >= DEATH_TIME:
            queue_free()
        return
    var d: Vector2 = _net_pos - global_position
    velocity = d * 8.0
    if velocity.length() > 5.0:
        _look = velocity
    global_position += d * minf(14.0 * delta, 1.0)
    if player != null:
        if hp < max_hp and not active:
            _wake()
        elif hp >= max_hp and active:
            _sleep()
    if active and _hud and hp != _last_hud_hp:
        _last_hud_hp = hp
        _hud.update_boss(hp)
    queue_redraw()


# Host: arahkan bos ke pemain terdekat
func _retarget(delta: float) -> void:
    _rt_t -= delta
    if _rt_t > 0.0:
        return
    _rt_t = 0.4
    var best = player
    var bd := 1.0e12
    for t in Net.targets():
        if t.dead:
            continue
        var d: float = t.global_position.distance_squared_to(global_position)
        if d < bd:
            bd = d
            best = t
    player = best


func _load_sprites() -> void:
    # Kalau atlas belum ada / belum ter-import, bos tetap digambar prosedural (Art.draw_boss).
    var info = BossSprites.SHEETS.get(style)
    if info == null or not ResourceLoader.exists(String(info["file"])):
        return
    _tex = load(String(info["file"])) as Texture2D
    if _tex != null:
        _sheet = info


func enemy_name() -> String:
    return boss_name


func _phase2() -> bool:
    return hp * 2 <= max_hp


func apply_status(_s: String, _secs: float, _dot: int = 0) -> void:
    pass


func _wake() -> void:
    if active:
        return
    active = true
    Audio.music("boss")
    Audio.sfx("boss_roar")
    player.shake_camera(0.8)
    if _hud:
        _hud.show_banner("BOS: %s  (Lv %d)" % [boss_name, level], 2.5)
        _hud.show_boss("%s  Lv %d" % [boss_name, level], hp, max_hp)
    _intro_scene()


# Adegan pembuka: zoom kamera + dialog bos. Pertama kali penuh; setelahnya cukup satu sindiran.
# Dilewati di co-op (dialog menjeda game hanya saat solo) dan untuk bos gua.
func _intro_scene() -> void:
    if _hud == null or player == null or Net.active:
        return
    if not (has_meta("lair") or has_meta("expansion_boss")):
        return
    if not BossLines.has_intro(style):
        return
    if int(Game.p.get("bseen", {}).get(style, 0)) > 0:
        _hud.toast("%s: \"%s\"" % [boss_name, BossLines.again(style)])
        return
    var cam = player.get("cam")
    var z0 := Vector2(2, 2)
    if cam != null:
        z0 = cam.zoom
        var tw: Tween = cam.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
        tw.tween_property(cam, "zoom", z0 * 1.25, 0.5)
    _hud.say(boss_name, BossLines.intro(style), _intro_done.bind(cam, z0))


func _intro_done(cam, z0: Vector2) -> void:
    if cam != null and is_instance_valid(cam):
        cam.create_tween().tween_property(cam, "zoom", z0, 0.4)
    Audio.sfx("boss_roar")
    if player != null and is_instance_valid(player):
        player.shake_camera(0.6)
    var bs: Dictionary = Game.p.get("bseen", {})
    bs[style] = 1
    Game.p["bseen"] = bs
    Game.save()


func _say_phase2() -> void:
    var l: String = BossLines.phase2(style)
    if l == "" or _hud == null:
        return
    _hud.show_banner("\"%s\"" % l, 3.0)
    Audio.sfx("boss_roar")
    if player != null and is_instance_valid(player):
        player.shake_camera(0.5)


func _say_last_words() -> void:
    if _hud == null or Net.active or puppet:
        return
    if not (has_meta("lair") or has_meta("expansion_boss")):
        return
    var l: Array = BossLines.last_words(style)
    if not l.is_empty():
        _hud.say(boss_name, l)


func _sleep() -> void:
    active = false
    _p2_said = false
    hp = max_hp
    _state = "idle"
    _atk = 0.0
    if _hud:
        _hud.hide_boss()
    var world = get_tree().get_first_node_in_group("world")
    if world:
        Audio.music(world.MUSIC[biome_idx], biome_idx)


func _physics_process(delta: float) -> void:
    if puppet:
        _puppet_step(delta)
        return
    if Net.active and not _dead:
        _retarget(delta)
    _gap_t -= delta
    if _gap_t <= 0.0 and player != null and is_instance_valid(player):
        _gap_t = 0.5
        if _dmg_base < 0:
            _dmg_base = dmg
        dmg = maxi(int(float(_dmg_base) * Bal.taken_mult(level, player.level())), 1)
    _anim += delta
    _flash = maxf(_flash - delta, 0.0)
    _hurt = maxf(_hurt - delta, 0.0)
    if _dead:
        _dead_t += delta
        velocity = Vector2.ZERO
        queue_redraw()
        if _dead_t >= DEATH_TIME:
            queue_free()
        return
    _touch_cd = maxf(_touch_cd - delta, 0.0)
    # bos jauh dari layar tidak perlu digambar ulang
    if player == null or active or global_position.distance_squared_to(player.global_position) < 160000.0:
        queue_redraw()
    if player == null or player.dead:
        if active:
            _sleep()
        velocity = Vector2.ZERO
        return
    var to: Vector2 = player.global_position - global_position
    var world = get_tree().get_first_node_in_group("world")
    var safe: bool = world != null and world.in_village(player.global_position)
    if not active:
        velocity = Vector2.ZERO
        if to.length() < 190.0 and not safe:
            _wake()
        return
    if player.global_position.distance_to(lair) > 480.0 or safe:
        _sleep()
        return
    if absf(to.x) > 4.0:
        _face = 1.0 if to.x > 0.0 else -1.0
    if to.length() > 1.0:
        _look = to
    _t -= delta
    var sp: float = speed * (1.25 if _phase2() else 1.0)
    match _state:
        "idle":
            _atk = 0.0
            velocity = to.normalized() * sp if to.length() > 40.0 else Vector2.ZERO
            if _t <= 0.0:
                _begin_move(to)
        "windup":
            velocity = Vector2.ZERO
            _atk = clampf(1.0 - _t / 0.9, 0.0, 1.0)
            if _move == "charge":
                _dir = _dir.lerp(to.normalized(), 0.05).normalized()
            if _t <= 0.0:
                _execute()
        "charge":
            velocity = _dir * sp * 3.6
            if _t <= 0.0:
                _recover(0.9)
        "burst":
            velocity = Vector2.ZERO
            _shot_t -= delta
            if _shot_t <= 0.0 and _shots > 0:
                _shots -= 1
                _shot_t = 0.35 if _move != "breath" else 0.08
                _fire(to)
            if _shots <= 0 and _t <= 0.0:
                _recover(0.6)
        "recover":
            velocity = Vector2.ZERO
            _atk = 0.0
            if _t <= 0.0:
                _state = "idle"
                _t = randf_range(0.8, 1.6) * (0.7 if _phase2() else 1.0)
    move_and_slide()
    if _state == "charge" and get_slide_collision_count() > 0:
        _recover(0.9)
        player.shake_camera(0.6)
    if to.length() < radius + 9.0 and _touch_cd <= 0.0 and _state != "recover":
        player.take_damage(dmg + (dmg / 2 if _state == "charge" else 0), to, "boss")
        _touch_cd = 0.9


func _recover(t: float) -> void:
    _state = "recover"
    _t = t


func _begin_move(to: Vector2) -> void:
    var list: Array = MOVES[style]
    _move = list[randi() % list.size()]
    if _move == "summon" and get_tree().get_nodes_in_group("hostile").size() > 14:
        _move = "aimed"
    _state = "windup"
    _t = 0.9
    _dir = to.normalized()
    _target = player.global_position
    var main = get_tree().current_scene
    Audio.sfx("charge")
    if _move == "slam":
        main.fx_tele(_target, 62.0, COLORS[style], 0.9)
    elif _move == "ring":
        main.fx_ring(global_position, 90.0, COLORS[style], 0.9)


func _execute() -> void:
    var main = get_tree().current_scene
    match _move:
        "charge":
            _state = "charge"
            _t = 0.65
        "slam":
            main.fx_burst(_target, COLORS[style], 24, 120.0, 0.6, 60.0, 3.0, "dot")
            main.fx_ring(_target, 70.0, COLORS[style], 0.4)
            player.shake_camera(0.8)
            Audio.sfx("boss_die", 1.4)
            if player.global_position.distance_to(_target) < 66.0:
                player.take_damage(int(dmg * 1.6), player.global_position - _target, "boss")
            _recover(0.8)
        "summon":
            Audio.sfx("boss_roar", 1.3)
            for i in 3:
                var kinds := ["bee", "slime", "snake", "fiend"]
                var k: String = "bee" if style == "ent" else ("snake" if style == "scorpion" else ("slime" if style == "yeti" else ("shade_stalker" if style == "warden" else ("hollow_wisp" if style == "unwritten" else ("abyss_eel" if style == "leviathan" else ("thorn_sprite" if style == "verdant" else ("petal_fox" if style == "sakura" else ("sporeling" if style == "myconid" else ("cloud_wisp" if style == "ether" else ("dust_revenant" if style == "monarch" else ("pearl_wisp" if style == "lumina" else ("pollen_sprite" if style == "colossus" else ("vine_strangler" if style == "devourer" else "fiend")))))))))))))
                main.spawn_mob(k, biome_idx, global_position + Vector2(randf_range(-50, 50), randf_range(30, 60)), maxi(level - 8, 1))
            _recover(1.0)
        "ring":
            _state = "burst"
            _shots = 3
            _shot_t = 0.1
            _t = 1.6
        "breath":
            _state = "burst"
            _shots = 10
            _shot_t = 0.05
            _t = 1.0
            _target = player.global_position
        _:
            _state = "burst"
            _shots = 2 if _move == "spray" else 3
            _shot_t = 0.05
            _t = 1.2


func _fire(to: Vector2) -> void:
    var col: Color = COLORS[style]
    var base: float = to.angle()
    match _move:
        "ring":
            _ring(14, _shots * 0.3, col)
        "spray":
            for i in 7:
                _bolt(base + (i - 3) * 0.17, col, 130.0)
        "breath":
            _bolt(base + randf_range(-0.12, 0.12), col, 210.0)
        _:
            for i in 3:
                _bolt(base + (i - 1) * 0.18, col, 150.0)
    Audio.sfx("enemy_shoot", 0.7)


func _ring(n: int, off: float, col: Color) -> void:
    for i in n:
        _bolt(TAU * i / n + off, col, 105.0)


func _bolt(ang: float, col: Color, spd: float) -> void:
    var b = Projectile.new()
    b.direction = Vector2.from_angle(ang)
    b.hostile = true
    b.damage = int(dmg * 0.8)
    b.speed = spd
    b.life = 2.8
    b.color = col
    get_parent().add_child(b)
    b.global_position = global_position


func _draw() -> void:
    Art.shadow(self, 24.0, 28.0)
    if _state == "windup" and _move == "charge":
        draw_line(Vector2.ZERO, _dir * 150.0, Color(1, 0.2, 0.2, 0.55), 5.0)
    if _tex != null:
        _draw_sprite()
    else:
        Art.draw_boss(self, {"style": style, "t": _anim, "face": _face, "atk": _atk, "phase2": _phase2(), "moving": velocity.length() > 5.0})
        if _flash > 0.0:
            draw_circle(Vector2(0, -4), radius + 6.0, Color(1, 0.3, 0.3, 0.3))
    if not active and not _dead:
        draw_string(ThemeDB.fallback_font, Vector2(-70, -radius - (46.0 if _tex != null else 34.0)), "%s Lv%d" % [boss_name, level], HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color(1, 0.9, 0.6))


# ---- sprite 64x64 ------------------------------------------------------------
func _attack_anim() -> String:
    var m: Dictionary = ATTACK_ANIM.get(style, {})
    return String(m.get(_move, "attack"))


func _pick_anim() -> String:
    var an: Dictionary = _sheet["anims"]
    var dirs: bool = bool(_sheet.get("dirs", false))
    var sfx := _dir_suffix() if dirs else ""
    if _dead:
        return "death" + sfx
    if _hurt > 0.0 and an.has("hurt" + sfx):
        return "hurt" + sfx
    if _state == "windup" or _state == "charge" or _state == "burst":
        var a := _attack_anim()
        if an.has(a + sfx):
            return a + sfx
    if velocity.length() > 5.0:
        if an.has("move" + sfx):
            return "move" + sfx
        if dirs:
            return "idle" + sfx      # sheet 4 arah tanpa animasi jalan
        # bos dengan sprite per arah (kalajengking)
        if absf(velocity.x) > absf(velocity.y):
            return "side" if an.has("side") else "idle"
        return "down" if velocity.y > 0.0 else "up"
    return "idle" + sfx


# sprite 4 arah (Warden): _down / _up / _side. Sisi menghadap kanan, dibalik lewat _face.
func _dir_suffix() -> String:
    if absf(_look.x) > absf(_look.y):
        return "_side"
    return "_up" if _look.y < 0.0 else "_down"


func _draw_sprite() -> void:
    var an: Dictionary = _sheet["anims"]
    var anim_name := _pick_anim()
    var info: Array = an[anim_name]
    var n: int = int(info[1])
    var fps: float = float(info[2])
    var f := 0
    if _dead:
        f = mini(int(_dead_t * fps), n - 1)
    elif anim_name.begins_with("hurt"):
        f = 0
    elif bool(info[3]):
        f = int(_anim * fps) % n               # animasi berulang (idle / jalan)
    elif _state == "windup":
        f = mini(int(_atk * float(n)), n - 1)  # serangan: maju sesuai progres aba-aba
    else:
        f = n - 1                              # setelah aba-aba: tahan frame akhir
    var cell: int = int(_sheet.get("cell", BossSprites.CELL))
    var src := Rect2(f * cell, int(info[0]) * cell, cell, cell)
    var sz: float = cell * DRAW_SCALE
    var tint := Color.WHITE
    if _phase2() and not _dead:
        tint = Color(1.0, 0.82, 0.78)          # fase 2: sedikit kemerahan
    if _flash > 0.0:
        tint = Color(1.0, 0.45, 0.45)
    if _dead:
        tint.a = clampf((DEATH_TIME - _dead_t) / 0.4, 0.0, 1.0)
    var sx: float = _face * float(_sheet["native"])
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, 1.0))
    var bob := 0.0
    if n == 1 and bool(info[3]):
        bob = sin(_anim * (7.0 if anim_name.begins_with("move") else 3.5)) * 3.0   # gambar tunggal: melayang naik-turun
    draw_texture_rect_region(_tex, Rect2(-sz * 0.5, SPRITE_FOOT - sz * float(_sheet.get("foot", 61.0 / 64.0)) + bob, sz, sz), src, tint)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func take_damage(amount: int, _dir2: Vector2, crit: bool = false) -> void:
    if puppet:
        # klien: HP asli ada di host. Umpan balik lokal, damage dikirim ke host.
        if _dead:
            return
        _flash = 0.1
        _hurt = 0.18
        Audio.sfx("hit", 0.8)
        get_tree().current_scene.fx_text(global_position + Vector2(randf_range(-14, 14), -radius - 14.0), str(amount) + ("!" if crit else ""), Color(1, 0.85, 0.2) if crit else Color.WHITE, 18.0 if crit else 14.0)
        Net.send_hit(net_id, amount, _dir2, crit)
        return
    if _dead or player == null or player.dead:
        return
    if style == "devourer" and Secrets.has_seal():
        amount = int(float(amount) * 1.25)         # Segel Akar dari Aldric
    amount = maxi(int(float(amount) * Bal.dealt_mult(level, player.level())), 1)    # bos jauh di atas level = kebal
    _wake()
    hp = maxi(hp - amount, 0)
    _flash = 0.1
    _hurt = 0.18
    Audio.sfx("hit", 0.8)
    var main = get_tree().current_scene
    main.fx_text(global_position + Vector2(randf_range(-14, 14), -radius - 14.0), str(amount) + ("!" if crit else ""), Color(1, 0.85, 0.2) if crit else Color.WHITE, 18.0 if crit else 14.0)
    main.fx_burst(global_position + Vector2(randf_range(-14, 14), randf_range(-14, 14)), Color(1, 0.9, 0.6), 6, 60.0, 0.3, 0.0, 2.0, "star")
    if _hud:
        _hud.update_boss(hp)
    if hp <= 0:
        _die()
    elif not _p2_said and _phase2():
        _p2_said = true
        _say_phase2()


func _die() -> void:
    active = false
    remove_from_group("enemies")
    Audio.sfx("boss_die")
    var main = get_tree().current_scene
    for i in 8:
        main.fx_burst(global_position + Vector2(randf_range(-26, 26), randf_range(-26, 26)), COLORS[style], 14, 90.0, 0.8, 30.0, 3.0, "star")
    if Net.active and not puppet and Net.is_host:
        Net.host_entity_died(net_id)
    # hadiah untuk pemain lokal (co-op: hanya yang berada di dekat bos; "player" bisa saja pemain lain)
    var local = get_tree().get_first_node_in_group("player")
    if puppet or not Net.active or (local != null and local.global_position.distance_to(global_position) < Net.VIEW_R + 200.0):
        _boss_reward(main, local)
    else:
        active = false
    if _hud:
        _hud.hide_boss()
        _hud.show_banner("%s dikalahkan!" % boss_name, 3.0)
    var world = get_tree().get_first_node_in_group("world")
    if world:
        Audio.music(world.MUSIC[biome_idx], biome_idx)
    if not puppet:
        main.boss_died(self)
    if style == "devourer" and not puppet and not Net.active:
        main.get_tree().create_timer(4.5).timeout.connect(func(): Plot.ending_scene())
    _say_last_words()
    if _tex == null:
        queue_free()
        return
    # putar animasi mati dulu, baru dihapus (lihat _physics_process)
    _dead = true
    _dead_t = 0.0
    remove_from_group("boss")
    set_deferred("collision_layer", 0)
    set_deferred("collision_mask", 0)


func _boss_reward(main, local) -> void:
    main.spawn_pickup("coin", global_position, 60 + biome_idx * 40)
    main.spawn_pickup("gems", global_position + Vector2(10, 6), 30 + biome_idx * 15)
    var mats: Array = [["crown", "wood"], ["ankh", "sunshard"], ["gem", "shard"], ["heart", "obsidian"]][clampi(biome_idx - 1, 0, 3)]
    main.spawn_pickup("item:" + String(mats[0]), global_position + Vector2(0, -8), 1)
    for i in 3:
        main.spawn_pickup("item:" + String(mats[1]), global_position + Vector2(randf_range(-26, 26), randf_range(-20, 20)), 1)
    for i in 2:
        main.spawn_pickup("item:potion_hp2", global_position + Vector2(randf_range(-26, 26), randf_range(-20, 20)), 1)
    # perlengkapan Raven: pasti 1 (minimal Rare), 40% dapat satu lagi (minimal Uncommon)
    var gl: int = int(local.stat("luk")) if local else 1
    main.spawn_pickup("item:" + Gear.roll_gear(biome_idx, gl, 2), global_position + Vector2(0, 14), 1)
    if randf() < 0.4:
        main.spawn_pickup("item:" + Gear.roll_gear(biome_idx, gl, 1), global_position + Vector2(16, 10), 1)
    if local:
        local.give_xp(maxi(int(float(xp_reward) * Bal.xp_diff_mult(level, local.level())), 1))
        local.shake_camera(1.0)
    Story.on_boss(style)    # Kisah Utama: hitung bos ini
