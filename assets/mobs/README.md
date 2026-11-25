PNG MONSTER BUATAN SENDIRI
==========================
Taruh PNG di folder ini dengan nama persis jenis monsternya, game otomatis memakainya
(kalau file belum ada, dipakai gambar sementara dari kode):

  wolf.png       serigala
  bat.png        kelelawar (melayang)
  golem.png      golem
  kobold.png     kobold
  centipede.png  kelabang
  bear.png       beruang
  mummy.png      mumi

Format yang didukung:
  1) Strip horizontal: lebar = jumlah frame x tinggi, tiap frame persegi.
     Contoh 64x16 = 4 frame 16x16, atau 128x32 = 4 frame 32x32. Frame diputar otomatis (jalan cepat, diam pelan).
  2) Sheet gaya Pipoya 96x128 (3 kolom x 4 baris). Dipakai baris ke-3 (menghadap kanan).

Gambar harus menghadap KANAN (game membaliknya sendiri saat berjalan ke kiri).
Ukuran di layar diatur di scripts/art.gd, konstanta MOB_NEW (field "size", dalam px).
Mini boss memakai PNG jenis dasarnya (digambar 1,6x lebih besar).
Setelah menaruh PNG, buka project di Godot sekali supaya diimpor.
