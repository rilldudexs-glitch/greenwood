extends Node
# Autoload "Net": co-op lewat WiFi / hotspot (ENet, tanpa server online).
#
# Cara kerja:
#  - Host = pemilik dunia. Semua monster & bos HANYA dijalankan (AI) di HP host.
#  - Tiap pemain mengendalikan karakternya sendiri dan mengirim posisi + animasi ke host (15x/detik);
#    host meneruskannya ke semua pemain lain -> muncul sebagai RemotePlayer (remote_player.gd).
#  - Host mengirim monster di sekitar tiap pemain (radius VIEW_R) ke pemain itu 10x/detik.
#    Di HP klien monster itu "puppet" (enemy.gd / boss.gd, puppet = true): hanya digambar.
#  - Pemain memukul puppet -> damage dikirim ke host (s_hit). Monster mati -> semua pemain di dekatnya
#    dapat XP + drop sendiri-sendiri (loot pribadi, tidak perlu sinkron pickup).
#  - Dunia sama karena dibangun dari world_seed milik host. Peti, NPC, quest, tas, dan save tetap lokal tiap pemain.
# Kalau Net.active == false (main sendiri), semua kode ini tidak jalan sama sekali.

const PORT := 24565
const MAX_PLAYERS := 12                # termasuk host
const VERSION := 2
const SEND_HZ := 15.0
const SNAP_HZ := 10.0
const VIEW_R := 560.0                  # monster dalam jarak ini dari seorang pemain dikirim ke pemain itu
const SNAP_CHUNK := 40                 # maks monster per paket (supaya muat satu paket UDP)
const ANIMS := ["idle", "walk", "run", "attack1", "attack2", "attack3", "special", "ready", "hurt", "knock", "death"]
const BOSS_STATES := ["idle", "windup", "charge", "burst", "recover"]

signal joined_ok
signal failed(reason: String)

var active := false
var is_host := false
var my_id := 1
var players := {}          # peer_id -> {name, skin, gender, ver}
var ghosts := {}           # peer_id -> RemotePlayer
var puppets := {}          # klien: net_id -> node monster/bos puppet
var ents := {}             # host: net_id -> node monster/bos asli
var saved := {}            # data main-sendiri yang dicadangkan saat jadi klien (supaya save solo tidak rusak)

var _next_id := 1
var _known := {}           # host: peer_id -> {net_id: true} monster yang sudah dikirim ke peer itu
var _pstate := {}          # host: peer_id -> state terakhir
var _send_t := 0.0
var _snap_t := 0.0
var _main = null
var _entities: Node2D = null
var _local = null
var _hooked := false
var _tcache: Array = []
var _tcache_frame := -1


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


# ------------------------------------------------------------------ alamat IP
func local_ips() -> Array:
    var out: Array = []
    for a in IP.get_local_addresses():
        var s: String = String(a)
        if s.count(".") != 3:
            continue
        if s.begins_with("192.168.") or s.begins_with("10.") or s.begins_with("172."):
            out.append(s)
    return out


# Tebakan IP host untuk klien: hotspot HP biasanya x.x.x.1 (Android 192.168.43.1, iPhone 172.20.10.1)
func guess_host_ip() -> String:
    var l: Array = local_ips()
    if l.is_empty():
        return "192.168.43.1"
    var parts: PackedStringArray = String(l[0]).split(".")
    return "%s.%s.%s.1" % [parts[0], parts[1], parts[2]]


# ------------------------------------------------------------------ mulai / gabung
# Siapkan karakter lokal (pakai save yang ada, atau buat baru kalau belum punya).
func prepare_character(nm: String) -> void:
    if not (Game.has_save() and Game.load_save()):
        Game.new_game(nm if nm != "" else "Petualang", "m")
    Game.in_game = true


func _my_info() -> Dictionary:
    return {"name": String(Game.p["name"]), "skin": String(Game.p["skin"]), "gender": String(Game.p["gender"]), "ver": VERSION}


func _hook() -> void:
    if _hooked:
        return
    _hooked = true
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected)
    multiplayer.connection_failed.connect(_on_conn_failed)
    multiplayer.server_disconnected.connect(_on_server_gone)


func host_game() -> bool:
    var peer := ENetMultiplayerPeer.new()
    var err: int = peer.create_server(PORT, MAX_PLAYERS - 1)
    if err != OK:
        failed.emit("Gagal membuka server (port %d sedang dipakai?)" % PORT)
        return false
    _hook()
    multiplayer.multiplayer_peer = peer
    active = true
    is_host = true
    my_id = 1
    players = {1: _my_info()}
    saved = {}
    return true


func join_game(ip: String) -> bool:
    var peer := ENetMultiplayerPeer.new()
    var err: int = peer.create_client(ip.strip_edges(), PORT)
    if err != OK:
        failed.emit("Alamat IP tidak valid")
        return false
    _hook()
    multiplayer.multiplayer_peer = peer
    active = true
    is_host = false
    players = {}
    saved = {}
    return true


func leave() -> void:
    if not active and saved.is_empty():
        return
    if multiplayer.multiplayer_peer != null:
        multiplayer.multiplayer_peer.close()
        multiplayer.multiplayer_peer = null
    if not saved.is_empty():
        Game.world_seed = int(saved["seed"])
        Game.chests_opened = saved["chests"]
        Game.checkpoints = saved["cps"]
        Game.checkpoint_pos = saved["cp"]
        Game.p["pos"] = saved["pos"]
        Game.p["world"] = int(saved.get("world", 0))
    saved = {}
    active = false
    is_host = false
    players = {}
    ghosts.clear()
    puppets.clear()
    ents.clear()
    _known.clear()
    _pstate.clear()
    _main = null
    _entities = null
    _local = null


func _on_connected() -> void:
    my_id = multiplayer.get_unique_id()
    s_hello.rpc_id(1, _my_info())


func _on_conn_failed() -> void:
    leave()
    failed.emit("Tidak bisa terhubung. Cek IP, WiFi/hotspot, dan pastikan host sudah menekan Host (atau server penuh).")


func _on_server_gone() -> void:
    Game.save()
    leave()
    Game.in_game = false
    get_tree().change_scene_to_file("res://scenes/title.tscn")


func _on_peer_connected(id: int) -> void:
    if is_host:
        _known[id] = {}


func _on_peer_disconnected(id: int) -> void:
    if not is_host:
        return
    var nm: String = String(players.get(id, {}).get("name", "Pemain"))
    players.erase(id)
    _known.erase(id)
    _pstate.erase(id)
    _remove_ghost(id)
    for pid in multiplayer.get_peers():
        c_player_del.rpc_id(pid, id)
    _announce("%s keluar" % nm)


func _announce(text: String) -> void:
    var hud = get_tree().get_first_node_in_group("hud")
    if hud != null:
        hud.show_banner(text, 2.5)


# ------------------------------------------------------------------ handshake
@rpc("any_peer", "reliable")
func s_hello(info: Dictionary) -> void:
    if not is_host:
        return
    var id: int = multiplayer.get_remote_sender_id()
    if int(info.get("ver", 0)) != VERSION:
        c_reject.rpc_id(id, "Versi game berbeda. Pakai APK yang sama dengan host.")
        multiplayer.multiplayer_peer.disconnect_peer(id, false)
        return
    players[id] = info
    c_welcome.rpc_id(id, Game.world_seed, players, Game.world_id())
    for pid in multiplayer.get_peers():
        if pid != id:
            c_player_add.rpc_id(pid, id, info)
    _ensure_ghost(id)
    _announce("%s bergabung" % String(info.get("name", "Pemain")))


@rpc("authority", "reliable")
func c_reject(msg: String) -> void:
    leave()
    failed.emit(msg)


@rpc("authority", "reliable")
func c_welcome(seed_v: int, plist: Dictionary, world_v: int) -> void:
    players = plist
    # cadangkan data main-sendiri, lalu pakai dunia milik host selama sesi co-op
    saved = {"seed": Game.world_seed, "chests": Game.chests_opened.duplicate(), "cps": Game.checkpoints.duplicate(),
        "cp": Game.checkpoint_pos.duplicate(), "pos": (Game.p.get("pos", []) as Array).duplicate(),
        "world": Game.world_id()}
    Game.world_seed = seed_v
    Game.p["world"] = world_v                # klien ikut dunia (World 1/2) milik host
    Game.chests_opened = []
    Game.checkpoints = []
    Game.checkpoint_pos = []
    Game.p["pos"] = []
    Game.in_game = true
    joined_ok.emit()


@rpc("authority", "reliable")
func c_player_add(id: int, info: Dictionary) -> void:
    players[id] = info
    _ensure_ghost(id)
    _announce("%s bergabung" % String(info.get("name", "Pemain")))


@rpc("authority", "reliable")
func c_player_del(id: int) -> void:
    var nm: String = String(players.get(id, {}).get("name", "Pemain"))
    players.erase(id)
    _remove_ghost(id)
    _announce("%s keluar" % nm)


# ------------------------------------------------------------------ pemain lain (ghost)
func on_main_ready(main, entities: Node2D, local) -> void:
    _main = main
    _entities = entities
    _local = local
    ghosts.clear()
    puppets.clear()
    ents.clear()
    _pstate.clear()
    for k in _known.keys():
        _known[k] = {}
    if not active:
        return
    for pid in players.keys():
        _ensure_ghost(int(pid))
    if is_host:
        var ips: Array = local_ips()
        _announce("Host aktif. IP: %s" % (", ".join(PackedStringArray(ips)) if not ips.is_empty() else "(nyalakan hotspot/WiFi)"))


func _ensure_ghost(pid: int):
    if _entities == null or pid == my_id or not players.has(pid):
        return null
    var g = ghosts.get(pid)
    if g != null and is_instance_valid(g):
        return g
    g = load("res://scripts/remote_player.gd").new()    # load (bukan preload) supaya tidak saling-preload dengan autoload ini
    var info: Dictionary = players[pid]
    g.peer_id = pid
    g.pname = String(info.get("name", "Pemain"))
    g.skin = String(info.get("skin", "skin_default"))
    g.gender = String(info.get("gender", "m"))
    _entities.add_child(g)
    ghosts[pid] = g
    return g


func _remove_ghost(pid: int) -> void:
    var g = ghosts.get(pid)
    ghosts.erase(pid)
    if g != null and is_instance_valid(g):
        g.queue_free()


# Semua pemain yang bisa jadi sasaran monster (dipakai host): pemain lokal + semua ghost
func targets() -> Array:
    var f: int = Engine.get_physics_frames()
    if f != _tcache_frame:
        _tcache_frame = f
        _tcache = []
        if _local != null and is_instance_valid(_local):
            _tcache.append(_local)
        for g in ghosts.values():
            if is_instance_valid(g):
                _tcache.append(g)
    return _tcache


# ------------------------------------------------------------------ kirim state tiap frame
func _process(delta: float) -> void:
    if not active or _main == null:
        return
    if not is_instance_valid(_main):
        _main = null
        return
    _send_t -= delta
    if _send_t <= 0.0:
        _send_t = 1.0 / SEND_HZ
        _tick_state()
    if is_host:
        _snap_t -= delta
        if _snap_t <= 0.0:
            _snap_t = 1.0 / SNAP_HZ
            _tick_snap()


func _local_state() -> PackedFloat32Array:
    var pl = _local
    if pl == null or not is_instance_valid(pl):
        return PackedFloat32Array()
    var a: Dictionary = pl._hero_anim()
    var ai: int = maxi(ANIMS.find(String(a["anim"])), 0)
    return PackedFloat32Array([pl.global_position.x, pl.global_position.y, pl._face.x, pl._face.y, float(ai), float(a["u"]),
        float(pl.hp), float(pl.max_hp), float(pl.level()), 1.0 if pl.dead else 0.0, 1.0 if pl._hflip else 0.0])


func _tick_state() -> void:
    var st: PackedFloat32Array = _local_state()
    if st.is_empty():
        return
    if not is_host:
        s_state.rpc_id(1, st)
        return
    _pstate[1] = st
    var all := PackedFloat32Array()
    for pid in _pstate.keys():
        all.append(float(pid))
        all.append_array(_pstate[pid])
    for c in multiplayer.get_peers():
        c_players.rpc_id(c, all)


@rpc("any_peer", "unreliable")
func s_state(arr: PackedFloat32Array) -> void:
    if not is_host or arr.size() < 11:
        return
    var id: int = multiplayer.get_remote_sender_id()
    if not players.has(id):
        return
    _pstate[id] = arr
    var g = _ensure_ghost(id)
    if g != null:
        g.net_apply(arr, 0)


@rpc("authority", "unreliable")
func c_players(arr: PackedFloat32Array) -> void:
    if _entities == null:
        return
    var i := 0
    while i + 12 <= arr.size():
        var pid: int = int(arr[i])
        if pid != my_id:
            var g = _ensure_ghost(pid)
            if g != null:
                g.net_apply(arr, i + 1)
        i += 12


# ------------------------------------------------------------------ monster & bos (host -> klien)
func register(n) -> int:
    var id: int = _next_id
    _next_id += 1
    ents[id] = n
    n.tree_exiting.connect(func(): ents.erase(id))
    return id


func _tick_snap() -> void:
    var r2: float = VIEW_R * VIEW_R
    var r2_out: float = (VIEW_R + 120.0) * (VIEW_R + 120.0)
    for c in multiplayer.get_peers():
        var st: PackedFloat32Array = _pstate.get(c, PackedFloat32Array())
        if st.size() < 2 or not _known.has(c):
            continue
        var center := Vector2(st[0], st[1])
        var known: Dictionary = _known[c]
        var upd := PackedFloat32Array()
        for id in ents.keys():
            var n = ents[id]
            if not is_instance_valid(n):
                continue
            if n.global_position.distance_squared_to(center) > r2:
                continue
            if not known.has(id):
                known[id] = true
                c_spawn.rpc_id(c, n.net_spawn_info())
            upd.append_array(n.net_snapshot())
            if upd.size() >= SNAP_CHUNK * 7:
                c_snap.rpc_id(c, upd)
                upd = PackedFloat32Array()
        var gone := PackedInt32Array()
        for id in known.keys():
            var n2 = ents.get(id)
            if n2 == null or not is_instance_valid(n2) or n2.global_position.distance_squared_to(center) > r2_out:
                gone.append(id)
        if not gone.is_empty():
            for id in gone:
                known.erase(id)
            c_despawn.rpc_id(c, gone)
        if not upd.is_empty():
            c_snap.rpc_id(c, upd)


# Dipanggil monster/bos asli (host) saat mati: kabari klien yang sedang "melihatnya"
func host_entity_died(id: int) -> void:
    ents.erase(id)
    for c in _known.keys():
        var k: Dictionary = _known[c]
        if k.has(id):
            k.erase(id)
            c_kill.rpc_id(int(c), id)


@rpc("authority", "reliable")
func c_spawn(info: Dictionary) -> void:
    if _main == null or not is_instance_valid(_main):
        return
    var id: int = int(info["id"])
    if puppets.has(id):
        return
    var n = _main.net_spawn(info)
    if n != null:
        puppets[id] = n


@rpc("authority", "unreliable")
func c_snap(arr: PackedFloat32Array) -> void:
    var i := 0
    while i + 7 <= arr.size():
        var n = puppets.get(int(arr[i]))
        if n != null and is_instance_valid(n):
            n.net_apply(arr[i + 1], arr[i + 2], arr[i + 3], arr[i + 4], arr[i + 5], int(arr[i + 6]))
        i += 7


@rpc("authority", "reliable")
func c_kill(id: int) -> void:
    var n = puppets.get(id)
    puppets.erase(id)
    if n != null and is_instance_valid(n):
        n.net_kill()


@rpc("authority", "reliable")
func c_despawn(ids: PackedInt32Array) -> void:
    for id in ids:
        var n = puppets.get(id)
        puppets.erase(id)
        if n != null and is_instance_valid(n):
            n.queue_free()


# ------------------------------------------------------------------ pukulan & damage
# Klien memukul puppet -> host yang menghitung (monster & bos hanya punya HP di host)
func send_hit(id: int, amount: int, dir: Vector2, crit: bool) -> void:
    if active and not is_host:
        s_hit.rpc_id(1, id, amount, dir, crit)


func send_status(id: int, s: String, secs: float, dot: int) -> void:
    if active and not is_host:
        s_status.rpc_id(1, id, s, secs, dot)


@rpc("any_peer", "reliable")
func s_hit(id: int, amount: int, dir: Vector2, crit: bool) -> void:
    if not is_host:
        return
    var n = ents.get(id)
    if n != null and is_instance_valid(n):
        n.take_damage(clampi(amount, 0, 100000000), dir, crit)


@rpc("any_peer", "reliable")
func s_status(id: int, s: String, secs: float, dot: int) -> void:
    if not is_host:
        return
    var n = ents.get(id)
    if n != null and is_instance_valid(n):
        n.apply_status(s, minf(secs, 10.0), dot)


# Monster (di host) memukul pemain lain -> kirim ke HP pemain itu, dia yang menghitung defense-nya
func send_hurt(peer: int, amount: int, from: Vector2, src: String) -> void:
    if active and is_host:
        c_hurt.rpc_id(peer, amount, from, src)


@rpc("authority", "reliable")
func c_hurt(amount: int, from: Vector2, src: String) -> void:
    if _local != null and is_instance_valid(_local):
        _local.take_damage(amount, from, src)
