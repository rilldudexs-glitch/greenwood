extends CanvasLayer
# Developer tools are included only in the test/developer-mode branch.
# This build uses a separate Android package ID, so its save data is isolated.

var _panel: PanelContainer
var _god_mode := false
var _status: Label


func _ready() -> void:
	layer = 80
	_build_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		_toggle_panel()


func _build_ui() -> void:
	var toggle := Button.new()
	toggle.text = "DEV"
	toggle.position = Vector2(12, 12)
	toggle.size = Vector2(76, 42)
	toggle.z_index = 10
	toggle.pressed.connect(_toggle_panel)
	add_child(toggle)

	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 62)
	_panel.size = Vector2(340, 430)
	_panel.visible = false
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 410)
	_panel.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	scroll.add_child(column)

	var heading := Label.new()
	heading.text = "GREENWOOD • DEVELOPER TEST"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 18)
	column.add_child(heading)

	_status = Label.new()
	_status.text = "Test build aktif • save terpisah"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	_add_section(column, "PLAYER")
	_add_button(column, "+1 LEVEL", _level_1)
	_add_button(column, "+10 LEVEL", _level_10)
	_add_button(column, "+100 LEVEL", _level_100)
	_add_button(column, "+100 STAT POINTS", _stat_points)
	_add_button(column, "FULL HP / MP", _full_heal)
	_add_button(column, "GOD MODE: OFF", _toggle_god_mode)

	_add_section(column, "ITEMS & PROGRESS")
	_add_button(column, "+100.000 COINS", _add_coins)
	_add_button(column, "+1.000 GEMS", _add_gems)
	_add_button(column, "99 HP & MP POTIONS", _add_potions)
	_add_button(column, "UNLOCK WORLD 2", _unlock_world_two)

	_add_section(column, "WORLD TEST")
	_add_button(column, "TELEPORT TO VILLAGE", _teleport_village)
	_add_button(column, "SPAWN SLIME", _spawn_slime)
	_add_button(column, "SPAWN GOBLIN", _spawn_goblin)
	_add_button(column, "SPAWN WOLF", _spawn_wolf)
	_add_button(column, "SPAWN OGRE", _spawn_ogre)
	_add_button(column, "CLOSE PANEL", _toggle_panel)


func _add_section(parent: VBoxContainer, caption: String) -> void:
	var label := Label.new()
	label.text = "— " + caption + " —"
	label.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
	parent.add_child(label)


func _add_button(parent: VBoxContainer, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)


func _toggle_panel() -> void:
	if _panel != null:
		_panel.visible = not _panel.visible


func _main():
	return get_tree().current_scene


func _player():
	var main = _main()
	if main != null:
		return main.get("player")
	return get_tree().get_first_node_in_group("player")


func _refresh_player() -> void:
	var pl = _player()
	if pl == null:
		_status.text = "Pemain belum tersedia"
		return
	if pl.has_method("recalc"):
		pl.recalc()
	pl.hp = int(pl.max_hp)
	pl.mp = float(pl.max_mp)
	_status.text = "Lv %d • Koin %d • Gem %d" % [int(Game.p.get("level", 1)), int(Game.p.get("coins", 0)), int(Game.p.get("gems", 0))]
	Game.save()


func _add_levels(amount: int) -> void:
	Game.p["level"] = clampi(int(Game.p.get("level", 1)) + amount, 1, 1000)
	Game.p["xp"] = 0
	Game.p["points"] = int(Game.p.get("points", 0)) + amount * 2
	_refresh_player()


func _level_1() -> void:
	_add_levels(1)


func _level_10() -> void:
	_add_levels(10)


func _level_100() -> void:
	_add_levels(100)


func _stat_points() -> void:
	Game.p["points"] = int(Game.p.get("points", 0)) + 100
	_refresh_player()


func _full_heal() -> void:
	_refresh_player()


func _toggle_god_mode() -> void:
	_god_mode = not _god_mode
	var pl = _player()
	if pl != null:
		pl.set_meta("dev_god_mode", _god_mode)
	for child in _panel.find_children("*", "Button", true, false):
		if child.text.begins_with("GOD MODE:"):
			child.text = "GOD MODE: ON" if _god_mode else "GOD MODE: OFF"
	_status.text = "God Mode " + ("aktif" if _god_mode else "nonaktif")


func _add_coins() -> void:
	Game.p["coins"] = int(Game.p.get("coins", 0)) + 100000
	_refresh_player()


func _add_gems() -> void:
	Game.p["gems"] = int(Game.p.get("gems", 0)) + 1000
	_refresh_player()


func _add_potions() -> void:
	if typeof(Game.p.get("inv", null)) != TYPE_DICTIONARY:
		Game.p["inv"] = {}
	Game.p["inv"]["potion_hp"] = 99
	Game.p["inv"]["potion_mp"] = 99
	_refresh_player()


func _unlock_world_two() -> void:
	Game.p["world2_unlocked"] = true
	_status.text = "World 2 terbuka • pindah lewat portal / peta"
	Game.save()


func _teleport_village() -> void:
	var main = _main()
	var pl = _player()
	if main == null or pl == null or main.world == null:
		return
	pl.global_position = main.world.spawn_point()
	pl.velocity = Vector2.ZERO
	_status.text = "Teleport ke desa berhasil"


func _spawn(kind: String) -> void:
	var main = _main()
	var pl = _player()
	if main == null or pl == null or not main.has_method("spawn_mob"):
		_status.text = "World belum siap"
		return
	var pos: Vector2 = pl.global_position + Vector2(100, 0)
	var mob = main.spawn_mob(kind, 1, pos, int(Game.p.get("level", 1)))
	_status.text = "Spawn " + kind if mob != null else "Gagal spawn: " + kind


func _spawn_slime() -> void:
	_spawn("slime")


func _spawn_goblin() -> void:
	_spawn("goblin")


func _spawn_wolf() -> void:
	_spawn("wolf")


func _spawn_ogre() -> void:
	_spawn("ogre")
