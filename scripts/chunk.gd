extends Node2D
# Penggambar satu potongan peta (16x16 tile). Node ini hanya hidup sebentar: ia menggambar
# ke SubViewport ("baking") lalu dibuang, jadi saat bermain tiap chunk hanya berupa 1 tekstur
# (1 draw call), bukan ribuan perintah gambar. Lihat world.gd.

var world
var cx := 0
var cy := 0
var cells: Array = []   # kosong = gambar seluruh chunk; isi = tambal (patch) sel tertentu saja


func _draw() -> void:
    if cells.is_empty():
        world.draw_chunk(self, cx, cy)
    else:
        world.draw_cells(self, cells)
