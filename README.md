# Greenwood RPG 2D (v2: dunia terbuka)

Buka folder ini di Godot 4.x lalu tekan F5. Scene utama: `scenes/title.tscn`.

## Fitur
- Dunia terbuka 128x96 tile: Desa (tengah), Hutan (barat), Gurun (timur), Salju (utara), Gunung Api (selatan). Semua tersambung jalan tanah, tanpa syarat boss.
- 4 bos opsional dengan gaya berbeda: Ent Kuno, Ratu Kalajengking, Yeti Perkasa, Naga Api.
- Monster: slime, lebah, sapi, ayam, ular, fiend, wisp, **goblin** (berkelompok, serang-mundur), **laba-laba** (menerkam + jaring), **ogre** (hantaman tanah) dan **ogre merah** (seruduk + mengamuk).
- Stat: STR, INT, VIT, DEX, LUK. HP/MP berupa angka (awal 100/100). +2 poin stat tiap naik level.
- Tas, Status, Crafting (senjata/armor/ramuan/makanan), Skin, Toko, Setelan suara (BGM/SFX).
- Menebang, menambang, memancing (tombol Aksi / E) + quest dari Tetua Oren.
- Quest rahasia berantai dengan peti tersembunyi: Nenek Marni (desa, sudut barat daya), Kakek Sahar dan Zahra Penjelajah (gurun).
- 10 pedang berefek (api, es, petir, racun, sedot HP, dll), 5 tongkat, armor 5 tier (zirah, legging, sepatu, sarung tangan, perisai).
- Gacha skin (Mecha, Samurai, Street) dengan gem; karakter laki-laki / perempuan.

## Kontrol
WASD/panah jalan, J/Spasi serang, K sihir, E aksi, I tas, 1/2 ramuan, Esc menu. Di HP: joystick + tombol layar.

## Perlengkapan bergambar (Gear)
- `assets/gear/weapons.png` (pedang, busur, kapak, beliung, palu) dan `assets/gear/armor.png` (set Es, Hutan, Gunung Api, Gurun x zirah/legging/sepatu/perisai/sarung tangan), 7 rarity: Common, Uncommon, Rare, Epic, Legendary, Ancient, Myth.
- Logika di `scripts/gear.gd` (id `gw_<jenis>_<no>_<rarity>` dan `ga_<set>_<slot>_<no>_<rarity>`), data warna/elemen di `scripts/gear_db.gd`.
- Pedang = tebasan, kapak = tebasan lebar + menebang cepat, palu = hantaman area, busur = panah jarak jauh, beliung = slot Beliung (menambang cepat + ore ekstra).
- Dapat dari drop monster, peti, boss, dan "Peti Perlengkapan Acak" di toko.

## Zona Leveling (tempat berburu per level)
Monster agresif sekarang dikumpulkan di 21 zona tetap (lingkaran ~6 tile) dengan rentang level sempit, jadi pemain
baru maupun yang sudah tinggi selalu punya tempat leveling. Saat masuk zona muncul banner "Zona Leveling: nama (Lv a-b)".
Respawn zona 45 detik. Sebaran acak di luar zona dikurangi jadi 35%.
Semua diatur di tabel `ZONES` di `scripts/balance.gd` (posisi, level, isi monster); tidak perlu ubah kode lain.

| Wilayah | Zona (level) |
|---|---|
| Hutan (dekat desa -> barat) | Padang Slime 1-6, Hutan Goblin Muda 7-14, Lereng Serigala 15-24, Rawa Laba-laba 25-36, Gua Kelelawar 37-52, Hutan Beruang 53-70, Rimba Ogre 71-86, Gerbang Ent 87-100 |
| Gurun (timur) | Oasis Ular 100-114, Reruntuhan Mumi 115-132, Lembah Kelabang 133-152, Kuburan Firaun 153-171, Badai Pasir 172-190 |
| Salju (utara) | Padang Salju 190-209, Hutan Beku 210-229, Gua Es 230-249, Puncak Badai 250-270 |
| Gunung Api (selatan) | Kaki Gunung Api 270-289, Lembah Lava 290-309, Kawah Merah 310-329, Jantung Magma 330-350 |
