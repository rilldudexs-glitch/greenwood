extends CharacterBody2D
# Pemain: statistik (STR/INT/VIT/DEX/LUK), animasi lengan/kaki, serang pedang, sihir,
# menebang, menambang, memancing, inventaris & perlengkapan.

const Art = preload("res://scripts/art.gd")
const Projectile = preload("res://scripts/projectile.gd")
const Bal = preload("res://scripts/balance.gd")
const Jobs = preload("res://scripts/jobs.gd")
const Prog = preload("res://scripts/progress.gd")
const MountScript = preload("res://scripts/mount.gd")
const PetScript = preload("res://scripts/pet.gd")

var hp := 100
var mp := 100.0
var max_hp := 100
var max_mp := 100
var dead := false

var _face := Vector2.DOWN
var _phase := 0.0
var _t := 0.0
var _rd := 0
var _swing := -1.0          # 0..1 saat mengayun pedang
var _combo := 0             # 0,1,2 = tebasan / tebasan putar / tusukan (rantai kombo)
var _combo_t := 0.0         # sisa waktu untuk melanjutkan kombo
var _ready_t := 0.0         # pedang masih terhunus setelah menyerang
var _move_t := 0.0          # lama berjalan terus-menerus (jalan -> lari)
var _hflip := false         # sprite pahlawan menghadap kiri
var _swing_hit := false
var _atk_cd := 0.0
var _cast_t := 0.0
var _magic_cd := 0.0
var _gather_t := -1.0
var _gather_cd := 0.0
var _gather_hit := false
var _gather_tool := "axe"
var _invuln := 0.0
# --- dodge (guling) & skill (putaran pedang)
const DODGE_TIME := 0.24
const DODGE_CD := 0.9
const DODGE_SPEED := 340.0
const SPIN_TIME := 0.55
const SKILL_R := 58.0
var _dodge_t := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector2.DOWN
var _pd_done := false
var _slow_until := 0
var _skill_cd := 0.0
var _pet = null
var _spin_t := 0.0
var _spin_hit2 := false
var _flash := 0.0
var _knock := Vector2.ZERO
var _shake := 0.0
var _regen_t := 0.0
var _autosave := 0.0
var _dead_t := 0.0
var _region := -1
var _region_t := 0.0
# memancing: "" | "wait" | "bite"
var _fish := ""
var _fish_t := 0.0
var _fish_pos := Vector2.ZERO
var _fish_cell := Vector2i.ZERO
var cam: Camera2D
var world
var hud


func _ready() -> void:
	add_to_group("player")
	add_child(MountScript.new())
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 6.0
	cs.shape = sh
	cs.position = Vector2(0, 5)
	add_child(cs)
	cam = Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 9.0
	add_child(cam)
	cam.make_current()
	world = get_tree().get_first_node_in_group("world")
	if world:
		var ws: Vector2 = world.world_size()
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(ws.x)
		cam.limit_bottom = int(ws.y)
	hud = get_tree().get_first_node_in_group("hud")
	recalc()
	call_deferred("refresh_pet")
	hp = clampi(int(Game.p["hp"]), 1, max_hp)
	mp = minf(float(Game.p["mp"]), float(max_mp))


# ------------------------------------------------------------------ statistik
func stat(k: String) -> int:
	return int(Game.p["stats"][k])


func level() -> int:
	return int(Game.p["level"])


func _eq(slot: String) -> Dictionary:
	var id: String = String(Game.p["equip"].get(slot, ""))
	if id == "":
		return {}
	return Items.info(id)


func _eq_sum(key: String) -> float:
	var s := 0.0
	for slot in Items.SLOTS:
		var d := _eq(slot)
		if not d.is_empty():
			s += float(d.get(key, 0))
	return s


func sword() -> Dictionary:
	return Items.info(String(Game.p["sword"]))


func staff() -> Dictionary:
	return Items.info(String(Game.p["staff"]))


func defense() -> float:
	return (stat("vit") * 0.8 + _eq_sum("def")) * Jobs.mul("def")


var mounted := false


# Tunggangan terbuka di level 15. Menyerang atau terkena hit otomatis turun.
func toggle_mount() -> String:
	if level() < 15:
		return "Tunggangan terbuka di level 15"
	mounted = not mounted
	return "Naik kuda: lebih cepat (serang = turun)" if mounted else "Turun dari kuda"


func move_speed() -> float:
	return (100.0 + stat("dex") * 2.0 + _eq_sum("spd")) * Jobs.mul("spd") * (1.6 if mounted else 1.0)


func attack_cooldown() -> float:
	return maxf(0.5 - stat("dex") * 0.008, 0.18) * float(sword().get("cd", 1.0)) * Jobs.mul("cd")


func crit_chance() -> float:
	var c: float = 0.03 + stat("luk") * 0.0125 + stat("dex") * 0.003
	if String(sword().get("fx", "")) == "crit":
		c += 0.15
	return minf(c + Jobs.add("crit"), 0.85)


func melee_damage() -> int:
	var raw: int = int(sword().get("dmg", 5)) + stat("str") * 7 + int(_eq_sum("atk"))
	return int(float(raw) * Bal.player_scale(level()) * Jobs.mul("melee"))


func magic_damage() -> int:
	return int(float(int(staff().get("dmg", 8)) + stat("int") * 7) * Bal.player_scale(level()) * Jobs.mul("magic"))


func block_chance() -> float:
	return _eq_sum("block")


func mp_regen() -> float:
	return (2.0 + stat("int") * 0.3) * Jobs.mul("regen")


func recalc() -> void:
	var lv := level()
	var ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 1.0
	max_hp = int(float(90 + stat("vit") * 18) * Bal.player_hp_scale(lv) * Jobs.mul("hp")) + int(_eq_sum("hp"))
	max_mp = int(float(90 + stat("int") * 18) * Bal.player_mp_scale(lv) * Jobs.mul("mp"))
	hp = clampi(roundi(ratio * max_hp) if hp > 0 else 0, 0, max_hp)
	if hp <= 0 and not dead:
		hp = 1
	mp = minf(mp, float(max_mp))


func add_stat(k: String) -> bool:
	if int(Game.p["points"]) <= 0:
		return false
	Game.p["points"] = int(Game.p["points"]) - 1
	Game.p["stats"][k] = stat(k) + 1
	var oh: int = max_hp
	var om: int = max_mp
	recalc()
	hp += max_hp - oh      # poin VIT langsung menambah HP saat ini
	mp += float(max_mp - om)
	Audio.sfx("select")
	return true


func give_xp(n: int) -> void:
	if level() >= Bal.LV_MAX:
		return
	Game.p["xp"] = int(Game.p["xp"]) + n
	fx_text_here("+%d XP" % n, Color(0.6, 1.0, 0.6), 11.0)
	while int(Game.p["xp"]) >= Game.xp_needed(level()):
		Game.p["xp"] = int(Game.p["xp"]) - Game.xp_needed(level())
		Game.p["level"] = level() + 1
		Game.p["points"] = int(Game.p["points"]) + Game.POINTS_PER_LEVEL
		recalc()
		hp = max_hp
		mp = float(max_mp)
		Audio.sfx("levelup")
		Game.vibrate(120)
		if hud:
			hud.show_banner("LEVEL %d!  +%d poin stat" % [level(), Game.POINTS_PER_LEVEL], 3.0)
		get_tree().current_scene.fx_burst(global_position, Color(1.0, 0.9, 0.3), 26, 100.0, 0.9, -20.0, 2.5, "star")
		get_tree().current_scene.fx_ring(global_position, 50.0, Color(1.0, 0.9, 0.3), 0.7)


func fx_text_here(t: String, c: Color, s: float = 12.0) -> void:
	get_tree().current_scene.fx_text(global_position + Vector2(randf_range(-6, 6), -26), t, c, s)


# ------------------------------------------------------------------ inventaris
func count(id: String) -> int:
	return int(Game.p["inv"].get(id, 0))


func add_item(id: String, n: int = 1) -> void:
	Game.p["inv"][id] = count(id) + n


func remove_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	var left: int = count(id) - n
	if left <= 0:
		Game.p["inv"].erase(id)
	else:
		Game.p["inv"][id] = left
	return true


var _coin_combo := 0
var _coin_ms := 0


func collect(kind: String, amount: int) -> bool:
	if kind == "coin":
		Game.p["coins"] = int(Game.p["coins"]) + amount
		var now: int = Time.get_ticks_msec()
		_coin_combo = (_coin_combo + 1) if now - _coin_ms < 600 else 0     # ambil beruntun: nada makin tinggi
		_coin_ms = now
		Audio.sfx("coin", 0.95 + minf(float(_coin_combo), 10.0) * 0.045)
		fx_text_here("+%d" % amount, Color(1.0, 0.85, 0.3), 11.0)
	elif kind == "gems":
		Game.p["gems"] = int(Game.p["gems"]) + amount
		Audio.sfx("mat")
		fx_text_here("+%d gem" % amount, Color(0.4, 0.9, 1.0), 12.0)
	else:
		var id: String = kind.substr(5)
		add_item(id, amount)
		Audio.sfx("mat")
		fx_text_here("+%d %s" % [amount, Items.item_name(id)], Items.info(id)["color"], 11.0)
		if id == "log":
			Game.quest_progress("log", amount)
	return true


func equip_item(id: String) -> void:
	var d := Items.info(id)
	match String(d["type"]):
		"sword":
			Game.p["sword"] = id
		"staff":
			Game.p["staff"] = id
		"armor":
			Game.p["equip"][String(d["slot"])] = id
	recalc()
	Audio.sfx("select")


func unequip(slot: String) -> void:
	Game.p["equip"][slot] = ""
	recalc()


func owns(id: String) -> bool:
	if count(id) > 0:
		return true
	if Game.p["sword"] == id or Game.p["staff"] == id:
		return true
	return Game.p["equip"].values().has(id)


func quick_use(group: String) -> void:
	var order: Array = ["potion_hp", "grilled", "steak", "potion_hp2"] if group == "hp" else ["potion_mp", "omelet", "potion_mp2"]
	for id in order:
		if count(id) > 0 and Items.use_item(id, self):
			remove_item(id)
			Audio.sfx("potion")
			return
	Audio.sfx("nope")


func heal(h: int, m: int) -> void:
	h = int(float(h) * Jobs.mul("potion"))
	m = int(float(m) * Jobs.mul("potion"))
	if h > 0:
		hp = mini(hp + h, max_hp)
		fx_text_here("+%d HP" % h, Color(1.0, 0.4, 0.45), 12.0)
	if m > 0:
		mp = minf(mp + m, float(max_mp))
		fx_text_here("+%d MP" % m, Color(0.45, 0.6, 1.0), 12.0)
	Audio.sfx("heal")


func full_heal() -> void:
	hp = max_hp
	mp = float(max_mp)
	Audio.sfx("heal")


# Pendamping hewan sesuai job (dipanggil saat masuk dunia dan setelah ganti job)
func refresh_pet() -> void:
	var st: String = Jobs.pet_style()
	if _pet != null and is_instance_valid(_pet):
		if st != "" and String(_pet.style) == st:
			return
		_pet.queue_free()
		_pet = null
	if st == "" or get_parent() == null:
		return
	_pet = PetScript.new()
	get_parent().add_child(_pet)
	_pet.setup(self, st)


# Rasa pukulan: jeda singkat (hitstop) + guncangan kamera, lebih kuat saat kritikal
func _hit_feel(crit: bool) -> void:
	shake_camera(0.3 if crit else 0.15)
	if Engine.time_scale >= 0.99:
		var ms: int = 95 if crit else 45
		Engine.time_scale = 0.08
		_slow_until = Time.get_ticks_msec() + ms


func _draw_job_aura() -> void:
	var lk: Array = Jobs.look()
	if lk.is_empty():
		return
	var col: Color = lk[1]
	var tier: int = int(Jobs.DATA[Jobs.cur()]["tier"])
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	draw_set_transform(Vector2(0, 7), 0.0, Vector2(1.0, 0.45))
	draw_arc(Vector2.ZERO, 12.0 + pulse * 1.5, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.28 + 0.12 * float(tier)), 1.6)
	if tier >= 1:
		draw_arc(Vector2.ZERO, 17.0 + pulse * 2.0, 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.18 + 0.1 * float(tier)), 1.2)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if tier >= 2:
		for i in 3:
			var a: float = _t * 1.6 + float(i) * TAU / 3.0
			draw_circle(Vector2(cos(a) * 15.0, -8.0 + sin(a) * 6.0), 1.6, Color(col.r, col.g, col.b, 0.85))


# Senjata melayang bergaya job; dibuat dari bentuk sederhana, arah +x = ke depan
func _draw_job_weapon(style: String, col: Color) -> void:
	var steel := Color(0.85, 0.88, 0.95)
	var wood := Color(0.55, 0.38, 0.2)
	match style:
		"greatsword":
			draw_rect(Rect2(-2, -1.2, 5, 2.4), wood)
			draw_rect(Rect2(3, -4, 2.5, 8), steel.darkened(0.3))
			draw_colored_polygon(PackedVector2Array([Vector2(5.5, -2.5), Vector2(22, -1.2), Vector2(25, 0), Vector2(22, 1.2), Vector2(5.5, 2.5)]), col.lerp(steel, 0.6))
		"staff":
			draw_rect(Rect2(-6, -1, 24, 2), wood)
			var pr: float = 3.5 + sin(_t * 5.0) * 0.5
			draw_circle(Vector2(19, 0), pr + 2.0, Color(col.r, col.g, col.b, 0.3))
			draw_circle(Vector2(19, 0), pr, col)
		"bow":
			draw_arc(Vector2(2, 0), 11.0, -1.2, 1.2, 14, wood, 2.0)
			draw_line(Vector2(2 + 11.0 * cos(1.2), 11.0 * sin(1.2)), Vector2(2 + 11.0 * cos(1.2), -11.0 * sin(1.2)), Color(0.95, 0.95, 0.85), 1.0)
			draw_line(Vector2(-3, 0), Vector2(14, 0), col, 1.4)
		"katana":
			draw_rect(Rect2(-2, -1.0, 5, 2.0), Color(0.2, 0.2, 0.3))
			draw_circle(Vector2(3.5, 0), 2.2, Color(0.8, 0.7, 0.3))
			draw_polyline(PackedVector2Array([Vector2(4, 0), Vector2(14, -0.8), Vector2(24, -0.2), Vector2(27, 1.0)]), col.lerp(steel, 0.5), 1.8)
		"holy":
			draw_rect(Rect2(-6, -1, 20, 2), Color(0.95, 0.9, 0.7))
			draw_arc(Vector2(17, 0), 4.5, 0.0, TAU, 16, col, 1.6)
			draw_circle(Vector2(17, 0), 2.0, Color(col.r, col.g, col.b, 0.5 + 0.3 * sin(_t * 4.0)))
		"dagger":
			for sgn in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(2, sgn * 3.0), Vector2(13, sgn * 3.6), Vector2(16, sgn * 3.0), Vector2(13, sgn * 2.2)]), col.lerp(steel, 0.5))
				draw_rect(Rect2(-1, sgn * 3.0 - 0.8, 4, 1.6), Color(0.2, 0.15, 0.3))
		"spear":
			draw_rect(Rect2(-8, -1, 26, 2), wood)
			draw_colored_polygon(PackedVector2Array([Vector2(18, -3.2), Vector2(26, 0), Vector2(18, 3.2)]), col)
			draw_circle(Vector2(-6, 0), 1.8, Color(0.9, 0.3, 0.3))
		"flask":
			draw_circle(Vector2(8, 0), 5.0, Color(0.85, 0.95, 1.0, 0.5))
			draw_circle(Vector2(8, 1.2), 3.6, col)
			draw_rect(Rect2(11.5, -1.6, 4, 3.2), Color(0.85, 0.95, 1.0, 0.6))
			draw_rect(Rect2(15, -1.2, 2.2, 2.4), wood)


func shake_camera(a: float) -> void:
	_shake = maxf(_shake, a * 5.0)


# ------------------------------------------------------------------ loop utama
func _physics_process(delta: float) -> void:
	_t += delta
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _slow_until:
		Engine.time_scale = 1.0
	if dead:
		_dead_t -= delta
		if _dead_t <= 0.0:
			_respawn()
		queue_redraw()
		return
	if get_tree().paused:
		return
	_atk_cd = maxf(_atk_cd - delta, 0.0)
	_combo_t = maxf(_combo_t - delta, 0.0)
	_ready_t = maxf(_ready_t - delta, 0.0)
	_magic_cd = maxf(_magic_cd - delta, 0.0)
	_gather_cd = maxf(_gather_cd - delta, 0.0)
	_cast_t = maxf(_cast_t - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	_dodge_t = maxf(_dodge_t - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_skill_cd = maxf(_skill_cd - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	_region_t -= delta
	if _shake > 0.0:
		_shake = maxf(_shake - 20.0 * delta, 0.0)
		cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	elif cam.offset != Vector2.ZERO:
		cam.offset = Vector2.ZERO

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if hud and hud.has_method("stick_value") and hud.stick_value() != Vector2.ZERO:
		input = hud.stick_value()
	var busy: bool = _swing >= 0.0 or _gather_t >= 0.0
	var sp: float = move_speed() * (0.35 if busy else 1.0)
	if _fish != "":
		if input.length() > 0.2:
			_cancel_fish("Pancingan ditarik")
		input = Vector2.ZERO
	velocity = input * sp + _knock
	if _dodge_t > 0.0:
		velocity = _dodge_dir * DODGE_SPEED
		get_tree().current_scene.fx_burst(global_position + Vector2(0, 4), Color(0.8, 0.9, 1.0, 0.6), 1, 8.0, 0.3, 0.0, 3.0, "dot")
	_knock = _knock.move_toward(Vector2.ZERO, 600.0 * delta)
	move_and_slide()
	var moving: bool = input.length() > 0.1
	_move_t = _move_t + delta if moving else 0.0
	if moving and _dodge_t <= 0.0:
		_face = input.normalized()
		_phase += delta * (9.0 + sp * 0.04)
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, 0.2)
	# regen
	_regen_t += delta
	mp = minf(mp + mp_regen() * delta, float(max_mp))
	if _regen_t >= 4.0:
		_regen_t = 0.0
		if hp < max_hp and (world == null or world.in_village(global_position)):
			hp = mini(hp + int(float(2 + stat("vit") / 2) * Bal.player_hp_scale(level())), max_hp)

	_handle_actions(delta)
	_update_fishing(delta)
	_update_region()
	_autosave -= delta
	if _autosave <= 0.0 and _swing < 0.0 and _flash <= 0.0:    # tunggu momen tenang supaya tidak ada hitch saat bertarung
		_autosave = 20.0
		Game.p["hp"] = hp
		Game.p["mp"] = int(mp)
		var spos: Vector2 = global_position
		var mn = get_tree().current_scene
		if mn != null and mn.get("dungeon") != null:
			spos = mn.get("_return_pos")     # di dalam gua: simpan posisi mulut gua
		Game.p["pos"] = [spos.x, spos.y]
		Game.save()
	_rd += 1
	if _rd >= Perf.player_div or _swing >= 0.0 or _flash > 0.0 or _spin_t > 0.0 or _dodge_t > 0.0:
		_rd = 0
		queue_redraw()


func _handle_actions(delta: float) -> void:
	if hud and hud.busy():
		return
	if Input.is_action_just_pressed("potion_hp"):
		quick_use("hp")
	if Input.is_action_just_pressed("potion_mp"):
		quick_use("mp")
	if Input.is_action_just_pressed("dodge"):
		_dodge()
	if Input.is_action_just_pressed("skill"):
		_skill()
	if _spin_t > 0.0:
		_spin_t = maxf(_spin_t - delta, 0.0)
		if not _spin_hit2 and _spin_t <= SPIN_TIME * 0.5:
			_spin_hit2 = true
			_skill_hit(0.9)
	var locked: bool = _dodge_t > 0.0 or _spin_t > 0.0
	# serang
	if _swing >= 0.0:
		_swing += delta / 0.24
		if _swing >= 0.4 and not _swing_hit:
			_swing_hit = true
			_melee_hit()
		if _swing >= 1.0:
			_swing = -1.0
	elif Input.is_action_pressed("attack") and _atk_cd <= 0.0 and _gather_t < 0.0 and _fish == "" and not locked:
		mounted = false
		_swing = 0.0
		_swing_hit = false
		_atk_cd = attack_cooldown()
		_combo = (_combo + 1) % 3 if _combo_t > 0.0 else 0
		_combo_t = _atk_cd + 0.5
		_ready_t = 1.8
		Audio.sfx("swing", randf_range(0.9, 1.1))
		_swing_fx()
	# sihir
	if not locked and (Input.is_action_just_pressed("magic") or (Input.is_action_pressed("magic") and _magic_cd <= 0.0)):
		_cast()
	# aksi: bicara / kumpulkan / pancing
	if Input.is_action_just_pressed("interact"):
		if _fish == "bite":
			_reel()
		elif _fish == "wait":
			_cancel_fish("Terlalu cepat! Ikannya kabur")
		else:
			var npc = _nearest_npc()
			if npc:
				npc.interact(self)
			else:
				_start_gather()
	elif Input.is_action_pressed("interact") and _gather_t < 0.0 and _gather_cd <= 0.0 and _fish == "" and _nearest_npc() == null:
		var tg: Dictionary = world.gather_target(global_position + Vector2(0, 4), _face) if world else {}
		if not tg.is_empty() and String(tg["type"]) != "water":
			_start_gather()
	if _gather_t >= 0.0:
		_gather_t += delta / (0.42 / _gather_speed())
		if _gather_t >= 0.5 and not _gather_hit:
			_gather_hit = true
			_gather_strike()
		if _gather_t >= 1.0:
			_gather_t = -1.0


func _nearest_npc():
	var best = null
	var bd := 44.0
	for n in get_tree().get_nodes_in_group("npcs"):
		var d: float = n.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = n
	return best


# Label tombol aksi di HUD
func context_label() -> String:
	if dead:
		return ""
	if _fish == "bite":
		return "TARIK!"
	if _fish == "wait":
		return "Batal"
	var n = _nearest_npc()
	if n:
		return "Bicara"
	if world:
		var tg: Dictionary = world.gather_target(global_position + Vector2(0, 4), _face)
		if not tg.is_empty():
			match String(tg["type"]):
				"tree":
					return "Tebang"
				"rock":
					return "Tambang"
				"water":
					return "Pancing"
	return ""


# ------------------------------------------------------------------ pedang
func _wtype() -> String:
	return String(sword().get("wtype", "sword"))


# Busur: tembakkan panah (1-3 sekaligus menurut rarity)
func _fire_arrows(d: Dictionary) -> void:
	var n: int = int(d.get("spread", 1))
	Audio.sfx("bolt", 1.5)
	for i in n:
		var b = Projectile.new()
		var a: float = _face.angle() + (i - (n - 1) / 2.0) * 0.2
		b.direction = Vector2.from_angle(a)
		b.speed = float(d.get("speed", 360.0))
		b.arrow = true
		b.damage = melee_damage()
		b.crit = randf() < crit_chance()
		if b.crit:
			b.damage = int(b.damage * 1.75)
		b.color = d.get("blade", Color(1.0, 0.9, 0.6))
		b.pierce = int(d.get("pierce", 0))
		b.scale_f = 0.9
		b.life = 0.9
		get_parent().add_child(b)
		b.global_position = global_position + b.direction * 12.0 + Vector2(0, -2)


func _melee_hit() -> void:
	var d := sword()
	if bool(d.get("ranged", false)):
		_fire_arrows(d)
		return
	var reach: float = float(d.get("reach", 26.0)) * Jobs.mul("reach")
	var arc: float = float(d.get("arc", 1.25))
	var slam: bool = bool(d.get("slam", false))
	var fx_kind: String = String(d.get("fx", "none"))
	var main = get_tree().current_scene
	var hit_any := false
	var crit_any := false
	var tip: Vector2 = global_position + _face * reach * 0.8
	# palu: hantaman area di depan pemain; senjata lain: busur tebasan di depan
	var origin: Vector2 = global_position + (_face * reach * 0.7 if slam else Vector2.ZERO)
	if slam:
		main.fx_ring(origin, reach * 0.9, _sword_fx_color(), 0.3)
		main.fx_burst(origin, Color(0.8, 0.75, 0.6), 8, 70.0, 0.4, 20.0, 2.5, "dot")
		shake_camera(0.2)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var to: Vector2 = e.global_position - origin
		var dist: float = to.length()
		if slam:
			if dist > reach * 0.9 + e.radius:
				continue
		else:
			if dist > reach + e.radius + 6.0:
				continue
			if dist > 14.0 and absf(_face.angle_to(to)) > arc:
				continue
		hit_any = true
		if slam:
			fx_kind = fx_kind if fx_kind != "none" else "knock"
		var crit: bool = randf() < crit_chance()
		var dmg: int = melee_damage()
		if fx_kind == "knock":
			dmg = int(dmg * 1.25)
		if crit:
			dmg = int(dmg * 1.75)
		e.take_damage(dmg, to, crit)
		crit_any = crit_any or crit
		main.fx_burst(e.global_position, Color(1, 0.95, 0.75), 8 if crit else 4, 75.0, 0.25, 0.0, 2.0, "star")
		match fx_kind:
			"burn":
				e.apply_status("burn", 3.5, maxi(dmg / 5, 1))
				main.fx_burst(e.global_position, Color(1.0, 0.5, 0.1), 8, 50.0, 0.5, -40.0, 2.5, "flame")
			"poison":
				e.apply_status("poison", 4.0, maxi(dmg / 6, 1))
				main.fx_burst(e.global_position, Color(0.5, 1.0, 0.3), 7, 40.0, 0.5, -20.0, 2.0, "dot")
			"freeze":
				e.apply_status("freeze", 2.5)
				main.fx_burst(e.global_position, Color(0.8, 0.95, 1.0), 9, 45.0, 0.6, 20.0, 2.0, "snow")
			"shock":
				var chained := 0
				for e2 in get_tree().get_nodes_in_group("enemies"):
					if e2 != e and chained < 2 and e2.global_position.distance_to(e.global_position) < 80.0:
						chained += 1
						main.fx_bolt(e.global_position, e2.global_position, Color(1.0, 0.95, 0.4))
						e2.take_damage(maxi(dmg / 2, 1), Vector2.ZERO)
			"drain":
				var g: int = maxi(dmg / 12, 1)
				hp = mini(hp + g, max_hp)
				main.fx_burst(e.global_position, Color(1.0, 0.3, 0.5), 6, 40.0, 0.5, 0.0, 2.0, "dot")
	if hit_any:
		_hit_feel(crit_any)
	else:
		main.fx_burst(tip, Color(1, 1, 1), 3, 30.0, 0.2, 0.0, 1.5, "star")


func _sword_fx_color() -> Color:
	var d := sword()
	return d.get("blade", Color.WHITE)


func _swing_fx() -> void:
	var d := sword()
	if bool(d.get("ranged", false)) or bool(d.get("slam", false)):
		return
	var main = get_tree().current_scene
	main.fx_slash(global_position + Vector2(0, 2), _face.angle(), float(d.get("reach", 26.0)) + 4.0, _sword_fx_color())
	var tip: Vector2 = global_position + _face * float(d.get("reach", 26.0)) * 0.9
	match String(d.get("fx", "none")):
		"burn":
			main.fx_burst(tip, Color(1, 0.6, 0.2), 8, 40.0, 0.5, -50.0, 2.5, "flame")
		"freeze":
			main.fx_burst(tip, Color(0.85, 0.97, 1.0), 8, 40.0, 0.6, 25.0, 2.0, "snow")
		"poison":
			main.fx_burst(tip, Color(0.5, 1.0, 0.3), 6, 30.0, 0.5, -10.0, 2.0, "dot")
		"shock":
			main.fx_burst(tip, Color(1.0, 1.0, 0.5), 6, 60.0, 0.3, 0.0, 2.0, "star")
		"drain":
			main.fx_burst(tip, Color(1.0, 0.3, 0.6), 6, 30.0, 0.5, 0.0, 2.0, "dot")


# ------------------------------------------------------------------ sihir
func _cast() -> void:
	if _magic_cd > 0.0 or _fish != "" or _swing >= 0.0:
		return
	var s := staff()
	var cost: float = float(s.get("cost", 10.0))
	if mp < cost:
		Audio.sfx("nope")
		_magic_cd = 0.3
		return
	mp -= cost
	_magic_cd = maxf(0.45 - stat("dex") * 0.008, 0.25)
	_cast_t = 0.3
	Audio.sfx("bolt")
	var n: int = int(s.get("spread", 1))
	for i in n:
		var b = Projectile.new()
		var a: float = _face.angle() + (i - (n - 1) / 2.0) * 0.28
		b.direction = Vector2.from_angle(a)
		b.speed = float(s.get("speed", 220.0))
		b.damage = magic_damage()
		b.crit = randf() < crit_chance() * 0.5
		if b.crit:
			b.damage = int(b.damage * 1.75)
		b.color = s.get("color", Color(0.4, 0.8, 1.0))
		b.pierce = int(s.get("pierce", 0))
		b.homing = bool(s.get("homing", false))
		b.explode = float(s.get("explode", 0.0))
		b.scale_f = float(s.get("scale", 1.0))
		b.life = 1.2
		get_parent().add_child(b)
		b.global_position = global_position + b.direction * 12.0 + Vector2(0, -2)


# ------------------------------------------------------------------ menebang / menambang / memancing
# Kecepatan kerja: beliung terpasang mempercepat menambang, kapak (senjata) mempercepat menebang.
func _gather_speed() -> float:
	if _gather_tool == "pick":
		return maxf(float(_eq("pick").get("dig", 1.0)), 1.0)
	if _wtype() == "axe":
		return 1.35 + 0.05 * float(sword().get("rarity", 0))
	return 1.0


# Data gambar alat yang sedang dipakai (kosong = pakai gambar bawaan)
func _gather_gear() -> Dictionary:
	if _gather_tool == "pick":
		var p: Dictionary = _eq("pick")
		return p if p.has("gi") else {}
	if _wtype() == "axe" and sword().has("gi"):
		return sword()
	return {}


func _start_gather() -> void:
	if world == null or _gather_t >= 0.0 or _gather_cd > 0.0:
		return
	var tg: Dictionary = world.gather_target(global_position + Vector2(0, 4), _face)
	if tg.is_empty():
		return
	match String(tg["type"]):
		"tree":
			_gather_tool = "axe"
		"rock":
			_gather_tool = "pick"
		"water":
			_begin_fish(tg["cell"])
			return
	_gather_t = 0.0
	_gather_hit = false
	_gather_cd = 0.55


func _gather_strike() -> void:
	var tg: Dictionary = world.gather_target(global_position + Vector2(0, 4), _face)
	if tg.is_empty():
		return
	var main = get_tree().current_scene
	var c: Vector2i = tg["cell"]
	var cc: Vector2 = world.cell_center(c)
	Audio.sfx("hit", 0.7 if _gather_tool == "axe" else 1.3)
	shake_camera(0.1)
	if _gather_tool == "axe":
		main.fx_burst(cc + Vector2(0, 4), Color(0.6, 0.4, 0.2), 6, 50.0, 0.4, 80.0, 2.0, "leaf")
	else:
		main.fx_burst(cc, Color(0.8, 0.8, 0.85), 6, 60.0, 0.35, 80.0, 1.8, "snow")
	var res: Dictionary = world.hit_cell(c)
	if not bool(res["done"]):
		return
	var luk_bonus: int = 1 if randf() < stat("luk") * 0.02 else 0
	if _gather_tool == "axe":
		main.spawn_pickup("item:log", cc + Vector2(0, 10), 2 + luk_bonus)
		if randf() < 0.15:
			main.spawn_pickup("item:honey", cc + Vector2(8, 12), 1)
	else:
		var o: String = String(res["ore"])
		if randf() < float(_eq("pick").get("ore", 0.0)):
			luk_bonus += 1      # beliung bagus: peluang hasil tambang ekstra
		main.spawn_pickup("item:stone", cc + Vector2(-6, 8), 1 + luk_bonus)
		if o != "stone":
			main.spawn_pickup("item:" + o, cc + Vector2(6, 10), 1 + luk_bonus)
		Game.quest_progress("ore", 1 + luk_bonus)
	give_xp(Bal.gather_xp(level()))


func _begin_fish(cell: Vector2i) -> void:
	_fish = "wait"
	_fish_cell = cell
	_fish_pos = world.cell_center(cell)
	_fish_t = maxf(randf_range(1.6, 4.5) - stat("dex") * 0.04, 0.8)
	Audio.sfx("swing", 0.6)
	if hud:
		hud.toast("Memancing... tunggu ikan menggigit")


func _cancel_fish(msg: String) -> void:
	_fish = ""
	if hud:
		hud.toast(msg)


func _update_fishing(delta: float) -> void:
	if _fish == "":
		return
	_fish_t -= delta
	if _fish == "wait" and _fish_t <= 0.0:
		_fish = "bite"
		_fish_t = 0.9
		Audio.sfx("blip", 1.6)
		get_tree().current_scene.fx_text(_fish_pos + Vector2(0, -10), "!", Color(1, 0.3, 0.3), 24.0)
	elif _fish == "bite" and _fish_t <= 0.0:
		_cancel_fish("Ikannya lepas...")


func _reel() -> void:
	var b: int = world.biome[world.idx(_fish_cell.x, _fish_cell.y)]
	var id := "fish_carp"
	var r: float = randf()
	if r < 0.03 + stat("luk") * 0.005:
		id = "fish_gold"
	else:
		match b:
			2:
				id = "fish_sand"
			3:
				id = "fish_ice"
			4:
				id = "fish_lava"
			_:
				id = "fish_carp" if randf() < 0.65 else "fish_bass"
	_fish = ""
	var main = get_tree().current_scene
	main.fx_burst(_fish_pos, Color(0.6, 0.85, 1.0), 10, 60.0, 0.5, 120.0, 2.0, "dot")
	main.spawn_pickup("item:" + id, global_position + _face * 12.0, 1)
	if id == "fish_gold":
		main.spawn_pickup("gems", global_position + _face * 12.0, 5)
	Game.quest_progress("fish")
	give_xp(Bal.gather_xp(level()) + 2)
	Audio.sfx("mat")


# ------------------------------------------------------------------ wilayah
func _update_region() -> void:
	if world == null or _region_t > 0.0 or world.has_meta("in_dungeon"):
		return
	_region_t = 0.5
	var b: int = world.biome_at(global_position)
	if b != _region:
		var first: bool = _region == -1
		_region = b
		var any_boss: bool = false
		for bs in get_tree().get_nodes_in_group("boss"):
			if bs.active:
				any_boss = true
		if not any_boss:
			Audio.music(world.MUSIC[b], b)
		if hud and not first:
			hud.show_banner(world.BNAMES[b], 2.5)


# ------------------------------------------------------------------ terkena damage
func take_damage(amount: int, from: Vector2, _src: String = "") -> void:
	if dead:
		return
	if bool(get_meta("dev_god_mode", false)):
		return
	if _dodge_t > 0.0:
		_perfect_dodge()
		return
	if _invuln > 0.0:
		return
	var dmg: int = Bal.reduce(amount, defense())
	var blocked: bool = randf() < block_chance()
	if blocked:
		dmg = maxi(dmg / 3, 1)
	hp -= dmg
	_invuln = 0.7
	_flash = 0.2
	_knock = from.normalized() * 150.0 if from != Vector2.ZERO else Vector2.ZERO
	_swing = -1.0
	_gather_t = -1.0
	if _fish != "":
		_cancel_fish("Pancingan terganggu!")
	Audio.sfx("hurt")
	mounted = false
	Game.vibrate(35 if dmg < max_hp / 4 else 90)
	shake_camera(0.5)
	get_tree().current_scene.fx_text(global_position + Vector2(0, -24), ("Tangkis " if blocked else "-") + str(dmg), Color(0.6, 0.8, 1.0) if blocked else Color(1.0, 0.35, 0.35), 15.0)
	if hp <= 0:
		_die()


# ------------------------------------------------------------------ dodge & skill
func dodge_ratio() -> float:
	return clampf(_dodge_cd / DODGE_CD, 0.0, 1.0)


func skill_cd_max() -> float:
	var sk: Dictionary = Jobs.skill()
	if not sk.is_empty():
		return maxf(float(sk["cd"]) - stat("dex") * 0.05, 3.5) * Prog.skill_cd()
	return maxf(8.0 - stat("dex") * 0.05, 4.5)


func skill_ratio() -> float:
	return clampf(_skill_cd / skill_cd_max(), 0.0, 1.0)


# Guling cepat ke arah stik (atau arah hadap). Kebal selama guling; kena serangan pas guling = Perfect Dodge.
func _dodge() -> void:
	if _dodge_cd > 0.0 or dead or _spin_t > 0.0 or _dodge_t > 0.0:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if hud and hud.has_method("stick_value") and hud.stick_value() != Vector2.ZERO:
		dir = hud.stick_value()
	if dir.length() < 0.2:
		dir = _face
	_dodge_dir = dir.normalized()
	_face = _dodge_dir
	_dodge_t = DODGE_TIME
	_dodge_cd = DODGE_CD
	_pd_done = false
	_swing = -1.0
	_gather_t = -1.0
	if _fish != "":
		_cancel_fish("Pancingan ditarik")
	Audio.sfx("swing", 1.6)


func _perfect_dodge() -> void:
	if _pd_done:
		return
	_pd_done = true
	Engine.time_scale = 0.45
	_slow_until = Time.get_ticks_msec() + 450
	_skill_cd = maxf(_skill_cd - skill_cd_max() * 0.4, 0.0)
	_dodge_cd = minf(_dodge_cd, 0.2)
	mp = minf(mp + 10.0, float(max_mp))
	var main = get_tree().current_scene
	main.fx_text(global_position + Vector2(0, -26), "Sempurna!", Color(0.5, 0.95, 1.0), 15.0)
	main.fx_ring(global_position, 22.0, Color(0.5, 0.95, 1.0), 0.35)
	Audio.sfx("bolt", 1.4)


# Skill: Putaran Pedang. Menyapu semua musuh di sekitar dua kali, ikut efek elemen senjata.
func _skill() -> void:
	if dead or _spin_t > 0.0 or _dodge_t > 0.0 or _fish != "":
		return
	if _skill_cd > 0.0:
		Audio.sfx("nope")
		return
	_skill_cd = skill_cd_max()
	var jsk: Dictionary = Jobs.skill()
	if not jsk.is_empty():
		_job_skill(jsk)
		return
	_spin_t = SPIN_TIME
	_spin_hit2 = false
	_swing = -1.0
	_gather_t = -1.0
	_invuln = maxf(_invuln, SPIN_TIME * 0.6)
	Audio.sfx("swing", 0.7)
	var main = get_tree().current_scene
	main.fx_ring(global_position, SKILL_R, _sword_fx_color(), 0.35)
	shake_camera(0.3)
	_skill_hit(1.6)


# Skill job (data di jobs.gd): area (sekali / beberapa denyut), dash (menebas lurus), blink (loncat ke belakang musuh)
func _skill_src_dmg(sk: Dictionary) -> int:
	var base: int = melee_damage()
	match String(sk.get("src", "melee")):
		"magic":
			base = magic_damage()
		"best":
			base = maxi(melee_damage(), magic_damage())
	return int(float(base) * Prog.skill_dmg())


func _skill_status(e, sk: Dictionary, dmg: int) -> void:
	match String(sk.get("status", "")):
		"burn":
			e.apply_status("burn", 3.0, maxi(dmg / 5, 1))
		"poison":
			e.apply_status("poison", 3.5, maxi(dmg / 6, 1))
		"freeze":
			e.apply_status("freeze", 3.0)


func _skill_strike(center: Vector2, r: float, sk: Dictionary, force_crit: bool = false) -> void:
	var main = get_tree().current_scene
	var col: Color = sk.get("col", Color.WHITE)
	main.fx_ring(center, r, col, 0.35)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var to: Vector2 = e.global_position - center
		if to.length() > r + e.radius:
			continue
		var crit: bool = force_crit or randf() < crit_chance()
		var dmg: int = int(float(_skill_src_dmg(sk)) * float(sk.get("mult", 1.0)))
		if crit:
			dmg = int(dmg * 1.75)
		e.take_damage(dmg, to, crit)
		_skill_status(e, sk, dmg)
		main.fx_burst(e.global_position, col, 5, 50.0, 0.4, 0.0, 2.0, "star")


func _job_skill(sk: Dictionary) -> void:
	var main = get_tree().current_scene
	if _pet != null and is_instance_valid(_pet):
		_pet.rage(5.0)
	var col: Color = sk.get("col", Color.WHITE)
	Audio.sfx("swing", 0.7)
	shake_camera(0.3)
	main.fx_text(global_position + Vector2(0, -30), String(sk["name"]), col)
	if sk.has("invuln"):
		_invuln = maxf(_invuln, float(sk["invuln"]))
	if sk.has("heal"):
		_skill_heal(float(sk["heal"]))
	match String(sk["kind"]):
		"dash":
			var dir: Vector2 = _face if _face != Vector2.ZERO else Vector2.DOWN
			var start: Vector2 = global_position
			move_and_collide(dir.normalized() * float(sk["dist"]))
			_invuln = maxf(_invuln, 0.3)
			var steps := 4
			for i in steps + 1:
				_skill_strike(start.lerp(global_position, float(i) / float(steps)), 34.0, sk)
		"blink":
			var best = null
			var bd: float = float(sk["range"])
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.process_mode == Node.PROCESS_MODE_DISABLED:
					continue
				var d: float = e.global_position.distance_to(global_position)
				if d < bd:
					bd = d
					best = e
			if best == null:
				_skill_cd = 1.0                    # tidak ada target: cooldown singkat
				main.fx_text(global_position + Vector2(0, -30), "Tak ada target", Color(1, 1, 1))
				return
			var away: Vector2 = (best.global_position - global_position).normalized()
			main.fx_burst(global_position, col, 10, 70.0, 0.4, 0.0, 2.5, "dot")
			move_and_collide(best.global_position + away * (best.radius + 14.0) - global_position)
			main.fx_burst(global_position, col, 10, 70.0, 0.4, 0.0, 2.5, "dot")
			_skill_strike(best.global_position, best.radius + 40.0, sk, bool(sk.get("crit", false)))
		_:
			var pulses: int = int(sk.get("pulses", 1))
			var gap: float = float(sk.get("gap", 0.3))
			for i in pulses:
				if i > 0:
					await get_tree().create_timer(gap).timeout
					if dead or not is_inside_tree():
						return
				var c: Vector2 = global_position
				if String(sk.get("at", "self")) == "ahead":
					c += _face * float(sk.get("dist", 70.0))
				_skill_strike(c, float(sk["r"]), sk)


func _skill_heal(frac: float) -> void:
	var h: int = int(float(max_hp) * frac)
	hp = mini(hp + h, max_hp)
	fx_text_here("+%d HP" % h, Color(1.0, 0.4, 0.45), 12.0)
	Audio.sfx("heal")


func _skill_hit(mult: float) -> void:
	var main = get_tree().current_scene
	var fx_kind: String = String(sword().get("fx", "none"))
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		var to: Vector2 = e.global_position - global_position
		if to.length() > SKILL_R + e.radius:
			continue
		var crit: bool = randf() < crit_chance()
		var dmg: int = int(float(melee_damage()) * mult)
		if crit:
			dmg = int(dmg * 1.75)
		e.take_damage(dmg, to, crit)
		match fx_kind:
			"burn":
				e.apply_status("burn", 3.0, maxi(dmg / 5, 1))
			"poison":
				e.apply_status("poison", 3.5, maxi(dmg / 6, 1))
			"freeze":
				e.apply_status("freeze", 2.0)
		main.fx_burst(e.global_position, _sword_fx_color(), 5, 50.0, 0.4, 0.0, 2.0, "star")
	shake_camera(0.15)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _die() -> void:
	hp = 0
	dead = true
	_dead_t = 2.6
	Audio.sfx("death")
	var lost: int = int(int(Game.p["coins"]) * 0.1)
	Game.p["coins"] = int(Game.p["coins"]) - lost
	if hud:
		hud.show_banner("Kamu pingsan...  (-%d koin)" % lost, 2.4)
	for b in get_tree().get_nodes_in_group("boss"):
		pass


func _respawn() -> void:
	var mn = get_tree().current_scene
	if mn != null and mn.has_method("dungeon_abort"):
		mn.dungeon_abort()              # pingsan di dalam gua: keluar dulu, lalu respawn seperti biasa
	dead = false
	hp = max_hp
	mp = float(max_mp)
	_invuln = 1.5
	var cp: Array = Game.checkpoint_pos
	if cp.size() == 2:
		global_position = Vector2(cp[0], cp[1])
	elif world:
		global_position = world.spawn_point()
	cam.reset_smoothing()
	Audio.sfx("heal")
	_region = -1


# ------------------------------------------------------------------ gambar
func look_dict(for_preview: bool = false) -> Dictionary:
	var o := {}
	var sk: Dictionary = Items.skins.get(String(Game.p["skin"]), Items.skins["skin_default"])
	o["skin"] = sk
	o["gender"] = String(Game.p["gender"])
	for pair in [["chest", "chest_c"], ["legs", "legs_c"], ["boots", "boots_c"], ["gloves", "gloves_c"], ["shield", "shield_c"]]:
		var d := _eq(pair[0])
		if not d.is_empty():
			o[pair[1]] = Items.TIER_COL[int(d["tier"]) - 1]
	return o


func _use_hero() -> bool:
	return String(Game.p["skin"]) == "skin_default" and Art.hero_ready()


# Pilih animasi pahlawan dari keadaan saat ini. Mengembalikan {"anim": nama, "u": progres 0..1}.
func _hero_anim() -> Dictionary:
	if dead:
		return {"anim": "death", "u": clampf((2.6 - _dead_t) / 0.8, 0.0, 1.0)}
	if _flash > 0.0:
		return {"anim": "knock" if _knock.length() > 40.0 else "hurt", "u": 1.0 - _flash / 0.2}
	# serangan pedang TIDAK memakai sprite serang: badan tetap jalan/diam, pedang melayang yang berayun
	if _cast_t > 0.0:
		return {"anim": "special", "u": 1.0 - _cast_t / 0.3}
	if _gather_t >= 0.0 or _fish != "":
		return {"anim": "idle", "u": 0.0}
	if velocity.length() > 8.0:
		return {"anim": "run" if _move_t > 0.45 else "walk", "u": 0.0}
	if _ready_t > 0.0:
		return {"anim": "ready", "u": 0.0}
	return {"anim": "idle", "u": 0.0}


func _draw_hero(o: Dictionary, held: Dictionary) -> void:
	if absf(_face.x) > 0.15:
		_hflip = _face.x < 0.0
	var a: Dictionary = _hero_anim()
	# geseran badan frame ini (naik-turun saat jalan) -> armor & senjata ikut bergerak, tidak "menempel diam"
	var off: Vector2 = Art.hero_body_offset(String(a["anim"]), float(a["u"]), _t, _face)
	# menghadap atas & tidak menyerang: senjata dipegang di belakang badan
	var behind: bool = _face.y < 0.0 and absf(_face.y) >= absf(_face.x) and _swing < 0.0
	if behind:
		_draw_held_gear(o, held, off)
	Art.draw_hero(self, String(a["anim"]), float(a["u"]), _t, _hflip, _face)
	if not behind:
		_draw_held_gear(o, held, off)


# Gaya Soul Knight: senjata melayang di samping badan, selalu terlihat, moncongnya menghadap arah bidik.
# Saat menyerang senjata berputar mengitari badan (jarak ikut membesar di puncak ayunan).
func _draw_held_gear(o: Dictionary, held: Dictionary, off: Vector2) -> void:
	if held.is_empty():
		return
	var swinging: bool = _swing >= 0.0
	var active: bool = swinging or _spin_t > 0.0 or _gather_t >= 0.0 or _cast_t > 0.0 or _fish != ""
	var wa: float = float(o.get("weapon_ang", _face.angle()))
	var r: float = 9.0
	var bob: float = sin(_t * 3.0) * 1.4
	if not active:
		wa = _face.angle() + sin(_t * 2.0) * 0.05
		if velocity.length() > 8.0:
			bob = sin(_t * 11.0) * 1.2
	elif _spin_t > 0.0:
		r = 16.0
	elif swinging:
		r += sin(clampf(_swing, 0.0, 1.0) * PI) * 6.0
	var hand: Vector2 = off + Vector2(0.0, -5.0 + bob) + Vector2.from_angle(wa) * r
	var base := Transform2D.IDENTITY
	var ang: float = wa
	if cos(wa) < 0.0:      # menghadap kiri: sprite dibalik vertikal supaya tidak terbalik
		base = Transform2D(0.0, Vector2(1.0, -1.0), 0.0, Vector2.ZERO)
		ang = -wa
		hand.y = -hand.y
	draw_set_transform_matrix(base)
	var jl: Array = Jobs.look()
	if not jl.is_empty() and String(held.get("kind", "")) == "sword":
		draw_set_transform_matrix(base * Transform2D(ang, hand))
		_draw_job_weapon(String(jl[0]), jl[1])
	else:
		Art.draw_held(self, held, hand, ang, _t, base)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw() -> void:
	if dead:
		draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if _use_hero():
			var da: Dictionary = _hero_anim()
			Art.draw_hero(self, "death", float(da["u"]), _t, _hflip, _face)
		return
	Art.shadow(self, 9.0, 8.0)
	_draw_job_aura()
	var moving: bool = velocity.length() > 8.0
	var dir := 0
	var flip := false
	if absf(_face.x) > absf(_face.y):
		dir = 2
		flip = _face.x < 0.0
	elif _face.y < 0.0:
		dir = 1
	var o := look_dict()
	o["dir"] = dir
	o["flip"] = flip
	o["t"] = _t
	o["phase"] = _phase
	o["moving"] = moving
	var rest: float = PI / 2.0 + (0.55 if flip else -0.55)
	o["weapon_ang"] = rest
	var held := {"kind": "sword", "data": sword()}
	if _spin_t > 0.0:
		var su: float = 1.0 - _spin_t / SPIN_TIME
		o["weapon_ang"] = _face.angle() + su * TAU * 2.0
		o["arm_target"] = Vector2.ZERO
	elif _swing >= 0.0:
		var u: float = clampf(_swing, 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - u, 2.0)
		var ang: float = _face.angle() + lerpf(-1.3, 1.3, e)
		if bool(sword().get("ranged", false)):
			ang = _face.angle()
		elif bool(sword().get("slam", false)):
			ang = _face.angle() + lerpf(-2.2, 0.5, e)    # palu diangkat lalu dihantamkan
		o["weapon_ang"] = ang
		o["arm_target"] = Vector2.from_angle(ang) * 7.5
	elif _cast_t > 0.0:
		held = {"kind": "staff", "tex": Art.tex("res://assets/weapons/staff_%d.png" % int(staff().get("tex", 0)))}
		o["weapon_ang"] = _face.angle()
		o["arm_target"] = _face * 8.0
	elif _gather_t >= 0.0:
		held = {"kind": "tool", "tool": _gather_tool}
		var tgd: Dictionary = _gather_gear()
		if not tgd.is_empty():
			held["gi"] = int(tgd["gi"])
			held["gsheet"] = String(tgd["gsheet"])
			held["hl"] = 30.0
		var g: float = clampf(_gather_t, 0.0, 1.0)
		var ang2: float = _face.angle() + lerpf(-1.2, 1.0, absf(sin(g * PI)) if g < 0.5 else 1.0 - (g - 0.5) * 2.0)
		o["weapon_ang"] = ang2
		o["arm_target"] = Vector2.from_angle(ang2) * 7.0
	elif _fish != "":
		held = {"kind": "tool", "tool": "rod"}
		o["weapon_ang"] = _face.angle() - 0.4
		o["arm_target"] = _face * 6.0 + Vector2(0, -3)
	o["held"] = held
	if _dodge_t > 0.0:
		modulate = Color(0.75, 0.9, 1.0, 0.55)
	elif _invuln > 0.0 and int(_t * 20.0) % 2 == 0:
		modulate = Color(1, 1, 1, 0.45)
	elif _flash > 0.0:
		modulate = Color(1.6, 0.6, 0.6)
	else:
		modulate = Color.WHITE
	if _use_hero():
		_draw_hero(o, held)
	else:
		Art.draw_human(self, o)
	var rar: int = int(o["skin"]["rarity"])
	if rar >= 3:
		for i in 3:
			var a: float = _t * 2.0 + i * 2.1
			draw_circle(Vector2(cos(a) * 12.0, sin(a * 1.3) * 10.0 - 2.0), 1.2, Color(1.0, 0.9, 0.4, 0.8))
	if _fish != "":
		var lp: Vector2 = _fish_pos - global_position
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_line(_face * 18.0 + Vector2(0, -6), lp, Color(1, 1, 1, 0.6), 1.0)
		var bob: float = sin(_t * 6.0) * (3.0 if _fish == "bite" else 1.0)
		draw_circle(lp + Vector2(0, bob), 3.0, Color(1.0, 0.3, 0.3))
		draw_circle(lp + Vector2(0, bob - 1.0), 1.5, Color.WHITE)
		if _fish == "bite":
			draw_arc(lp, 8.0 + sin(_t * 20.0) * 2.0, 0.0, TAU, 16, Color(1, 1, 1, 0.7), 1.5)
