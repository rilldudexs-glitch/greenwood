extends Node2D
# Pemain lain di co-op (hanya gambar + data). Meniru bagian dari API pemain yang dipakai monster/bos
# (dead, level(), stat(), shake_camera(), take_damage()) supaya host bisa menjadikannya sasaran.

const Art = preload("res://scripts/art.gd")

var peer_id := 0
var pname := "Pemain"
var skin := "skin_default"
var gender := "m"
var lvl := 1
var hp := 100
var max_hp := 100
var dead := false

var _target := Vector2.ZERO
var _face := Vector2.DOWN
var _anim := "idle"
var _u := 0.0
var _hflip := false
var _t := 0.0
var _phase := 0.0
var _first := true
var _rd := 0.0


func _ready() -> void:
    add_to_group("peers")


# ---- API yang dipanggil monster / bos (host)
func stat(_k: String) -> int:
    return 1


func level() -> int:
    return lvl


func shake_camera(_a: float) -> void:
    pass


func take_damage(amount: int, from: Vector2, src: String = "") -> void:
    if dead:
        return
    Net.send_hurt(peer_id, amount, from, src)


# arr[off..off+10] = x, y, face.x, face.y, anim, u, hp, max_hp, level, dead, hflip
func net_apply(a: PackedFloat32Array, off: int) -> void:
    _target = Vector2(a[off], a[off + 1])
    if _first:
        _first = false
        position = _target
    _face = Vector2(a[off + 2], a[off + 3])
    var ai: int = clampi(int(a[off + 4]), 0, Net.ANIMS.size() - 1)
    _anim = String(Net.ANIMS[ai])
    _u = a[off + 5]
    hp = int(a[off + 6])
    max_hp = maxi(int(a[off + 7]), 1)
    lvl = int(a[off + 8])
    dead = a[off + 9] > 0.5
    _hflip = a[off + 10] > 0.5


func _process(delta: float) -> void:
    _t += delta
    var d: Vector2 = _target - position
    if d.length() > 400.0:
        position = _target
    else:
        position += d * minf(14.0 * delta, 1.0)
    if _anim == "walk" or _anim == "run":
        _phase += delta * 11.0
    _rd += delta
    if _rd >= 0.045:
        _rd = 0.0
        queue_redraw()


func _draw() -> void:
    Art.shadow(self, 9.0, 8.0)
    if dead:
        if Art.hero_ready():
            Art.draw_hero(self, "death", 1.0, _t, _hflip, _face)
        return
    var moving: bool = _anim == "walk" or _anim == "run"
    if skin == "skin_default" and Art.hero_ready():
        Art.draw_hero(self, _anim, _u, _t, _hflip, _face)
    else:
        var dir := 0
        var flip := false
        if absf(_face.x) > absf(_face.y):
            dir = 2
            flip = _face.x < 0.0
        elif _face.y < 0.0:
            dir = 1
        var o := {}
        o["skin"] = Items.skins.get(skin, Items.skins["skin_default"])
        o["gender"] = gender
        o["dir"] = dir
        o["flip"] = flip
        o["t"] = _t
        o["phase"] = _phase
        o["moving"] = moving
        o["weapon_ang"] = PI / 2.0 + (0.55 if flip else -0.55)
        o["held"] = {}
        Art.draw_human(self, o)
    # nama + bar HP di atas kepala
    var f := ThemeDB.fallback_font
    var lt: String = "%s  Lv%d" % [pname, lvl]
    var sz: Vector2 = f.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
    var np := Vector2(-sz.x / 2.0, -36.0)
    draw_string_outline(f, np, lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0, 0, 0, 0.9))
    draw_string(f, np, lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.95, 1.0))
    draw_rect(Rect2(-14, -33, 28, 4), Color(0, 0, 0, 0.7))
    draw_rect(Rect2(-13, -32, 26.0 * clampf(float(hp) / float(max_hp), 0.0, 1.0), 2), Color(0.4, 0.9, 0.5))
