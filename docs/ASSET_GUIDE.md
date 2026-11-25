# Asset guide
- assets/biomes/<biome>/: 7 tile 32x32 per biome (ground, ground2, path, floor, water, tree, bush)
- assets/characters/: player_sheet.png (4 kolom x 3 baris: bawah, atas, samping), npc_*.png (2 frame),
  slime_*/wisp_* (4 frame 32x32), boss_* (2 frame 64x64)
- assets/audio/: sfx dan music (WAV mono 16-bit)
- Semua dibuat prosedural lewat tools/*.py, jadi bisa diganti dengan sprite/audio sendiri berukuran sama.

## Sprite bos 64x64 (atlas animasi)
- Sumber: `tools/boss_src/sheet_all_bosses.png` (Ent, Yeti, Naga) dan `tools/boss_src/sheet_scorpion.png` (Ratu Kalajengking, lengkap 4 arah).
- `python3 tools/gen_boss_sprites.py` memotong, membuang latar hitam, memperkecil ke sel 64x64, lalu menulis
  `assets/characters/boss_<style>_sheet.png` (baris = animasi, kolom = frame) dan `scripts/boss_sprites.gd` (tabel animasi).
- Animasi: `idle`, `move`, `attack`, `hurt`, `death`. Kalajengking: `idle`, `down`, `up`, `side`, `claw`, `tail`, `storm`, `hurt`, `death`.
- `scripts/boss.gd` menggambar sprite ini (skala `DRAW_SCALE`=1.5). Kalau atlas tidak ada, bos kembali ke gambar prosedural `Art.draw_boss`.
- Ganti frame yang dipakai lewat daftar `(baris, kolom)` di `tools/gen_boss_sprites.py`, lalu jalankan ulang.

## Sprite batu/bijih (atlas)
- Sumber: `tools/rock_src/sheet_rocks.png`. `python3 tools/gen_rock_sprites.py` -> `assets/props/rocks_sheet.png` (sel 48x48, 12 ukuran x 9 jenis).
- Baris: stone, moss (batu hutan), copper, iron, gold, crystal, ruby, coal, obsidian (iron/ruby/coal/obsidian hasil pewarnaan ulang).
- `Art.draw_rock` memilih baris dari jenis bijih dan varian ukuran dari hash sel; batu biasa diberi tint per biome. Tanpa atlas -> gambar kode lama.

## Sprite pahlawan (skin default) - 4 arah
- Sumber: `tools/hero_src/sheet_hero.png` (kolom Down/Left/Right/Up, 8 animasi). `python3 tools/gen_hero_sprites.py` ->
  `assets/characters/hero_sheet.png` (sel 64x64, baris atlas = animasi*4 + arah) + `scripts/hero_sprites.gd`.
- `Art.draw_hero(ci, anim, dir, u, t)` menggambar; `Player._hero_anim()` memilih animasi:
  idle, walk -> run (setelah 0.45 dtk), kombo serangan (tebasan -> tusukan -> tebasan putar), hurt, death.
- Pedang menyatu di sprite serangan. Alat kerja (kapak/beliung/pancing) dan tongkat digambar kode di tangan.
- Hanya skin default; skin gacha tetap pakai sprite/gambar lamanya.
