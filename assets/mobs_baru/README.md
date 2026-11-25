MOB BARU (hasil potong dari sheet "untuk enemy baru")
=====================================================
Nama file sama dengan assets/mobs/ (bat.png, wolf.png, mini_bat.png, dst).
Tinggal copy ke assets/mobs/ kalau mau dipakai game.

  <nama>.png        strip 4 frame (walk). Mob 64x64/frame, mini boss 96x96/frame
  strips/           strip per aksi: idle, walk, attack, hurt, die
                    (mini boss: idle, walk, attack1, attack2, skill, hurt, die)
                    attack & skill sudah di-flip supaya menghadap KANAN
  frames/<nama>/    potongan mentah per frame (transparan), <aksi>_<F|B|L|R>.png

Catatan: kolom F/B/L/R di sheet asli sebenarnya urutan frame, bukan arah asli.
Beberapa frame mini boss (golem, werewolf, warbat) menempel di sheet asli,
jadi di strip diganti frame terdekat yang utuh.
