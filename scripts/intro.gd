extends Node
# Video intro (assets/intro.ogv). Tap / klik / tombol apa saja = lewati. Selesai -> title.

const NEXT_SCENE := "res://scenes/title.tscn"
var _done := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vp := VideoStreamPlayer.new()
	vp.stream = load("res://assets/intro.ogv")
	vp.expand = true
	vp.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.finished.connect(_next)
	add_child(vp)
	vp.play()


func _input(e: InputEvent) -> void:
	if (e is InputEventScreenTouch or e is InputEventMouseButton or e is InputEventKey) and e.is_pressed():
		_next()


func _next() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file(NEXT_SCENE)
