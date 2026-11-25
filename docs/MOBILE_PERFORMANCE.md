# Performa di HP kelas bawah (target: Oppo A54 / Helio G35)

Tujuan: FPS stabil di mana pun di peta. Ukuran sebelum -> sesudah (diukur di proyek ini, area hutan):

| | sebelum | sesudah |
|---|---|---|
| draw call per frame | ~2000 | ~130-250 |
| objek digambar per frame | ~7600 | ~350-550 |
| collision shape di fisika | 3212 | puluhan (hanya 3x3 chunk sekitar pemain) |
| waktu fisika per frame | 6.7 ms | 1.7 ms |

## Yang dilakukan
- **Render chunk (bake):** tiap chunk 16x16 tile digambar SEKALI ke `SubViewport` saat loading, lalu
  ditampilkan sebagai satu `Sprite2D`. Pohon ditebang/tumbuh hanya menambal sel di sekitarnya
  (`world.gd: _patch_cell`), bukan menggambar ulang chunk. Konsekuensi: loading di awal (ada bar
  progres) dan ~100 MB memori tekstur.
- **Tabrakan per chunk:** sel padat digabung jadi kotak besar; hanya chunk di sekitar pemain yang
  aktif (`update_collision_ring`).
- **LOD entitas:** musuh/NPC/peti/api unggun di luar radius (`Perf.active_radius`) dimatikan:
  tidak diproses, tidak digambar, keluar dari fisika (`main.gd: _lod_update`, group `lod`).
- **Gambar ulang dibatasi:** animasi musuh ~15-20 FPS dan dilewati di luar layar; HUD 12-30 Hz;
  partikel/teks efek ~20-30 Hz; NPC diam (10 Hz).
- **Mode stretch `viewport`:** dirender di resolusi dasar 960x540 lalu diskalakan -> beban GPU jauh
  lebih kecil dibanding resolusi asli layar.
- **Batas FPS 60, `max_physics_steps_per_frame=3`:** lag tidak menumpuk jadi spiral.
- **Governor otomatis (`scripts/perf.gd`):** kalau rata-rata di bawah ~45 FPS dua detik berturut-turut,
  kualitas turun satu tingkat (efek, radius aktif, laju gambar ulang); naik lagi kalau stabil.
  Setelan "Mode hemat performa" memaksa minimal tingkat 2 dari 3; "Tampilkan FPS" menampilkan angka FPS.

## Menguji
```
godot --headless --path . res://tests/smoke.tscn          # harus mencetak SMOKE_OK
xvfb-run -a godot --rendering-driver opengl3 --path . res://tests/shot.tscn -- out=a.png cx=30 cy=47 kinds=goblin,ogre
```
