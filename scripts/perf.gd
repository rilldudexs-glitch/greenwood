extends Node
# Autoload "Perf": mengukur waktu frame dan menyesuaikan kualitas otomatis supaya FPS tetap stabil
# di HP kelas bawah (mis. Oppo A54 / Helio G35). Tier 0 = penuh, 1 = sedang, 2 = hemat.
# Skrip lain cukup membaca: Perf.fx_scale, Perf.fx_cap, Perf.anim_div, Perf.hud_hz,
# Perf.player_div, Perf.active_radius.

signal tier_changed(tier: int)

const TIERS := [
    {"fx_scale": 1.0, "fx_cap": 48, "anim_div": 3, "hud_hz": 30.0, "player_div": 1, "ai_div": 1, "radius": 480.0},
    {"fx_scale": 0.6, "fx_cap": 28, "anim_div": 4, "hud_hz": 20.0, "player_div": 2, "ai_div": 2, "radius": 420.0},
    {"fx_scale": 0.3, "fx_cap": 14, "anim_div": 6, "hud_hz": 12.0, "player_div": 2, "ai_div": 3, "radius": 360.0},
    {"fx_scale": 0.12, "fx_cap": 6, "anim_div": 8, "hud_hz": 10.0, "player_div": 2, "ai_div": 4, "radius": 310.0},
]
const BAD_DT := 0.0222    # < 45 FPS
const GOOD_DT := 0.0185   # > 54 FPS
const WINDOW := 1.0       # detik per jendela ukur

var tier := 0
var fx_scale := 1.0
var fx_cap := 48
var anim_div := 3
var hud_hz := 30.0
var player_div := 1
var ai_div := 1             # musuh jauh & santai: AI cuma dijalankan tiap N frame fisika
var active_radius := 480.0
var fps_avg := 60.0

var _acc := 0.0
var _n := 0
var _bad := 0
var _good := 0
var _label: Label
var _layer: CanvasLayer
var _label_t := 0.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _apply(_floor_tier())
    apply_cap()


# Batas bawah tier: "Mode hemat" memaksa minimal tier 1, "Ultra hemat" tier 3 (paling ringan).
func _floor_tier() -> int:
    if bool(Game.settings.get("ultra_mode", false)):
        return 3
    return 1 if bool(Game.settings.get("low_mode", false)) else 0


# Batasi 30 FPS (hemat baterai & panas); 0 = tanpa batas
func apply_cap() -> void:
    Engine.max_fps = 30 if bool(Game.settings.get("cap30", false)) else 0


func set_ultra_mode(on: bool) -> void:
    Game.settings["ultra_mode"] = on
    Game.save_settings()
    if tier < _floor_tier():
        _apply(_floor_tier())


func set_cap30(on: bool) -> void:
    Game.settings["cap30"] = on
    Game.save_settings()
    apply_cap()


func set_low_mode(on: bool) -> void:
    Game.settings["low_mode"] = on
    Game.save_settings()
    if tier < _floor_tier():
        _apply(_floor_tier())


func _process(delta: float) -> void:
    _update_label(delta)
    # abaikan lonjakan (loading, pause, ganti scene) supaya tidak salah menurunkan kualitas
    if delta > 0.25 or get_tree().paused:
        return
    _acc += delta
    _n += 1
    if _acc < WINDOW:
        return
    var avg: float = _acc / float(_n)
    fps_avg = 1.0 / maxf(avg, 0.001)
    _acc = 0.0
    _n = 0
    if avg > BAD_DT:
        _bad += 1
        _good = 0
    elif avg < GOOD_DT:
        _good += 1
        _bad = 0
    else:
        _bad = maxi(_bad - 1, 0)
    if _bad >= 2 and tier < TIERS.size() - 2:
        _bad = 0
        _apply(tier + 1)
    elif _good >= 12 and tier > _floor_tier():
        _good = 0
        _apply(tier - 1)


func _apply(t: int) -> void:
    tier = clampi(t, 0, TIERS.size() - 1)
    var d: Dictionary = TIERS[tier]
    fx_scale = float(d["fx_scale"])
    fx_cap = int(d["fx_cap"])
    anim_div = int(d["anim_div"])
    hud_hz = float(d["hud_hz"])
    player_div = int(d["player_div"])
    ai_div = int(d["ai_div"])
    active_radius = float(d["radius"])
    tier_changed.emit(tier)


# ------------------------------------------------------------------ penghitung FPS (opsional)
func _update_label(delta: float) -> void:
    var want: bool = bool(Game.settings.get("show_fps", false))
    if not want:
        if _layer != null:
            _layer.queue_free()
            _layer = null
            _label = null
        return
    if _layer == null:
        _layer = CanvasLayer.new()
        _layer.layer = 100
        add_child(_layer)
        _label = Label.new()
        _label.position = Vector2(8, 2)
        _label.add_theme_font_size_override("font_size", 11)
        _label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
        _label.add_theme_color_override("font_outline_color", Color.BLACK)
        _label.add_theme_constant_override("outline_size", 4)
        _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _layer.add_child(_label)
    _label_t -= delta
    if _label_t <= 0.0:
        _label_t = 0.5
        _label.text = "FPS %d  kualitas %d" % [Engine.get_frames_per_second(), 4 - tier]
