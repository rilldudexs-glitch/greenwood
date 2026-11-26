extends Node
# Autoload "Audio": efek suara (pool player) dan musik.
#
# Musik memakai dua player supaya bisa crossfade:
#  - ganti biome / masuk boss: lagu lama turun, lagu baru naik (tidak dipotong mendadak)
#  - pengulangan tanpa celah: ujung lagu menyatu (overlap) dengan awal lagu yang sama, tidak bergantung pada loop
#    bawaan mp3/ogg (yang sering meninggalkan celah kecil) atau loop WAV
#  - tiap biome punya "warna suara" sendiri (pitch + low-pass/reverb) agar 4 lagu terasa beda di 15 biome

const SFX_DIR := "res://assets/audio/sfx/%s.wav"
const MUSIC_DIR := "res://assets/audio/music/%s.%s"
const MUSIC_EXT := ["mp3", "ogg", "wav"]   # dicari berurutan: file mp3/ogg menang atas wav lama
# Penyetara volume per lagu (dB) supaya semua lagu terdengar sama keras. Lagu baru tanpa entri = 0.
const TRACK_GAIN := {"forest": -3.7, "desert": -1.7, "snow": -1.0, "volcano": -3.3,
	"village": 2.5, "shadow": 2.5, "undefined": 2.5, "abyss": 2.5, "enchanted": 2.5, "sakura": 2.5, "mushroom": 2.5,
	"ether": 2.5, "forgotten": 2.5, "reef": 2.5, "verdan": 2.5, "crystal": 2.5}
# Lagu khusus per biome (dibuat dengan sintesis kode, loop sudah mulus): tanpa warna biome & tanpa tumpang-tindih panjang
const OWN_TRACKS := ["village", "shadow", "undefined", "abyss", "enchanted", "sakura", "mushroom", "ether", "forgotten", "reef", "verdan", "crystal"]
const OWN_OVERLAP := 0.6
const FIGHT_TRACKS := ["boss", "title"]   # tanpa warna biome, tanpa jeda
const CROSSFADE := 2.5       # detik, ganti lagu (biome / boss)
const LOOP_OVERLAP := 4.0    # detik, ujung lagu biome menyatu dengan awalnya
const FIGHT_OVERLAP := 1.5   # sama, untuk boss & title
const FADE_IN := 2.0         # saat mulai dari hening
const SILENT_DB := -45.0
# Jeda hening setelah satu putaran lagu biome. 0.0 = musik terus menyambung tanpa jeda.
const REST_CHANCE := 0.0
const REST_MIN := 8.0
const REST_MAX := 20.0

# Warna suara per biome (indeks biome game 0..14). pitch < 1 = lebih lambat/gelap.
const BIOME_PITCH := [1.0, 1.0, 0.97, 1.0, 0.96, 0.92, 0.94, 0.90, 1.02, 1.05, 0.98, 0.96, 0.93, 0.95, 1.0]
const BIOME_LOWPASS := {7: 2600.0, 13: 4200.0}                      # dalam air: suara teredam
const BIOME_REVERB := {5: 0.30, 6: 0.22, 11: 0.28, 12: 0.38, 13: 0.26}   # ruang gaung (0..1)

var muted := false
var _cache := {}
var _sfx: Array[AudioStreamPlayer] = []
var _mp: Array[AudioStreamPlayer] = []     # dua player musik (crossfade)
var _active := 0
var _current := ""
var _pitch := 1.0
var _loop_armed := false
var _rest: Timer
var _fade: Tween
var _color_tw: Tween
var _lp: AudioEffectLowPassFilter
var _rv: AudioEffectReverb


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_sfx.append(pl)
	_setup_bus()
	for i in 2:
		var mp := AudioStreamPlayer.new()
		mp.bus = "BGM_FX"
		add_child(mp)
		_mp.append(mp)
	_rest = Timer.new()
	_rest.one_shot = true
	add_child(_rest)
	_rest.timeout.connect(_on_rest_done)
	apply_settings()


# Bus khusus musik dengan low-pass + reverb (default netral: cutoff 20 kHz, wet 0).
func _setup_bus() -> void:
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "BGM_FX")
	AudioServer.set_bus_send(idx, "Master")
	_lp = AudioEffectLowPassFilter.new()
	_lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(idx, _lp)
	_rv = AudioEffectReverb.new()
	_rv.room_size = 0.7
	_rv.damping = 0.5
	_rv.wet = 0.0
	_rv.dry = 1.0
	AudioServer.add_bus_effect(idx, _rv)


# Terapkan volume BGM / SFX / mute dari Game.settings
func apply_settings() -> void:
	var sf: float = float(Game.settings["sfx"])
	if _fade:
		_fade.kill()
	if _mp.size() == 2:
		_mp[_active].volume_db = _music_db()
	for pl in _sfx:
		pl.volume_db = -3.0 + linear_to_db(maxf(sf, 0.0001))
	AudioServer.set_bus_mute(0, bool(Game.settings["muted"]))


func _music_db() -> float:
	return -9.0 + float(TRACK_GAIN.get(_current, 0.0)) + linear_to_db(maxf(float(Game.settings["bgm"]), 0.0001))


func _load_music(track: String):
	for ext in MUSIC_EXT:
		var s = _load(MUSIC_DIR % [track, ext])
		if s != null:
			return s
	return null


# Pengulangan ditangani di sini (bukan loop bawaan stream) supaya ujung & awal bisa menyatu.
func _prep(s) -> void:
	if s is AudioStreamMP3 or s is AudioStreamOggVorbis:
		s.loop = false
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_DISABLED


# Pindah ke stream (lagu baru atau awal lagu yang sama) dengan crossfade selama `fade` detik.
func _crossfade_to(stream, fade: float) -> void:
	var old: AudioStreamPlayer = _mp[_active]
	_active = 1 - _active
	var nw: AudioStreamPlayer = _mp[_active]
	nw.stream = stream
	nw.pitch_scale = _pitch
	nw.volume_db = SILENT_DB
	nw.play()
	_loop_armed = true
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.set_parallel(true)
	_fade.tween_property(nw, "volume_db", _music_db(), fade)
	if old.playing:
		_fade.tween_property(old, "volume_db", SILENT_DB, fade)
		_fade.chain().tween_callback(old.stop)


func _process(_d: float) -> void:
	if _current == "" or not _loop_armed or _mp.size() < 2:
		return
	var p: AudioStreamPlayer = _mp[_active]
	if not p.playing or p.stream == null:
		return
	var length: float = p.stream.get_length()
	if length <= 1.0:
		return
	var ov: float = minf(OWN_OVERLAP if _current in OWN_TRACKS else (FIGHT_OVERLAP if _current in FIGHT_TRACKS else LOOP_OVERLAP), length * 0.3)
	var remain: float = (length - p.get_playback_position()) / maxf(p.pitch_scale, 0.1)
	if remain > ov:
		return
	_loop_armed = false
	if not (_current in FIGHT_TRACKS) and randf() < REST_CHANCE:
		# jeda hening: lagu menutup pelan, lalu mulai lagi setelah beberapa detik
		var f: float = maxf(remain, 0.5)
		var t := create_tween()
		t.tween_property(p, "volume_db", SILENT_DB, f)
		_rest.start(f + randf_range(REST_MIN, REST_MAX))
		return
	_crossfade_to(p.stream, ov)      # putaran berikutnya menyatu dengan ujung lagu ini


func _on_rest_done() -> void:
	if _current == "":
		return
	var s = _load_music(_current)
	if s != null:
		_prep(s)
		_crossfade_to(s, FADE_IN)


# Warna suara biome: pitch + low-pass + reverb, berubah halus dalam 2 detik.
func _set_color(biome: int) -> void:
	_pitch = float(BIOME_PITCH[biome]) if biome >= 0 and biome < BIOME_PITCH.size() else 1.0
	var cut: float = float(BIOME_LOWPASS.get(biome, 20000.0))
	var wet: float = float(BIOME_REVERB.get(biome, 0.0))
	if _color_tw:
		_color_tw.kill()
	_color_tw = create_tween()
	_color_tw.set_parallel(true)
	_color_tw.tween_property(_lp, "cutoff_hz", cut, 2.0)
	_color_tw.tween_property(_rv, "wet", wet, 2.0)
	if _mp.size() == 2 and _mp[_active].playing:
		_color_tw.tween_property(_mp[_active], "pitch_scale", _pitch, 2.0)


func _load(path: String):
	if not _cache.has(path):
		if not ResourceLoader.exists(path):
			return null
		_cache[path] = load(path)
	return _cache[path]


func sfx(sfx_name: String, pitch: float = 1.0) -> void:
	var s = _load(SFX_DIR % sfx_name)
	if s == null:
		return
	for pl in _sfx:
		if not pl.playing:
			pl.stream = s
			pl.pitch_scale = pitch
			pl.play()
			return
	_sfx[0].stream = s
	_sfx[0].pitch_scale = pitch
	_sfx[0].play()


# `biome` (opsional) = indeks biome game; dipakai untuk warna suara. Boss/title: tanpa warna.
func music(track: String, biome: int = -1) -> void:
	_set_color(-1 if (track in FIGHT_TRACKS or track in OWN_TRACKS) else biome)
	var cur: AudioStreamPlayer = _mp[_active]
	if track == _current and (cur.playing or not _rest.is_stopped()):
		return
	var s = _load_music(track)
	if s == null:
		return
	_rest.stop()
	_current = track
	_prep(s)
	_crossfade_to(s, CROSSFADE if cur.playing else FADE_IN)


func stop_music() -> void:
	_current = ""
	_loop_armed = false
	_rest.stop()
	if _fade:
		_fade.kill()
	for p in _mp:
		p.stop()


func set_muted(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)
