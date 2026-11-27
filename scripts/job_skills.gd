extends RefCounted
# 4 skill tambahan tiap job (skill ke-2 sampai ke-5). Skill ke-1 ada di Jobs.DATA[id]["skill"].
# kind: area | dash | blink | line (tusukan lurus) | buff (tanpa damage: heal/invuln/mp). icon: lihat Art.draw_skill_icon.

const UNLOCK := [1, 10, 25, 50, 80]    # level untuk membuka skill ke-1..5

# Ikon skill ke-1 (skill lama) tiap job
const ICON1 := {"knight": "spin", "mage": "flame", "archer": "arrows", "swordsman": "slash", "priest": "heal", "shade": "dagger", "tamer": "paw", "alchemist": "drop", "root_guard": "shield", "seal_weaver": "snow", "mist_shade": "dash", "wild_caller": "leaf", "seed_brewer": "drop", "seed_bearer": "star"}

const EXTRA := {
	"knight": [
		{"name": "Tusukan Perkasa", "cd": 6.0, "kind": "line", "icon": "stab", "dist": 140.0, "w": 30.0, "mult": 2.4, "src": "melee", "col": Color(0.85, 0.9, 1)},
		{"name": "Hantaman Tameng", "cd": 9.0, "kind": "area", "icon": "shield", "at": "ahead", "dist": 50.0, "r": 75.0, "mult": 1.6, "src": "melee", "invuln": 0.8, "col": Color(0.7, 0.8, 1)},
		{"name": "Teriakan Perang", "cd": 12.0, "kind": "area", "icon": "burst", "at": "self", "r": 115.0, "mult": 0.8, "src": "melee", "heal": 0.2, "col": Color(1, 0.6, 0.3)},
		{"name": "Pedang Penghancur", "cd": 14.0, "kind": "area", "icon": "slash", "at": "ahead", "dist": 60.0, "r": 105.0, "mult": 4.0, "src": "melee", "col": Color(1, 0.85, 0.4)},
	],
	"mage": [
		{"name": "Panah Es", "cd": 7.0, "kind": "line", "icon": "snow", "dist": 230.0, "w": 30.0, "mult": 1.8, "src": "magic", "status": "freeze", "col": Color(0.6, 0.9, 1)},
		{"name": "Petir Berantai", "cd": 10.0, "kind": "area", "icon": "nova", "at": "self", "r": 150.0, "mult": 0.9, "src": "magic", "pulses": 3, "gap": 0.3, "col": Color(0.9, 0.9, 0.4)},
		{"name": "Meteor", "cd": 14.0, "kind": "area", "icon": "meteor", "at": "ahead", "dist": 130.0, "r": 115.0, "mult": 4.2, "src": "magic", "status": "burn", "col": Color(1, 0.45, 0.15)},
		{"name": "Pemulihan Arkana", "cd": 16.0, "kind": "buff", "icon": "star", "mp": 0.4, "heal": 0.15, "col": Color(0.6, 0.7, 1)},
	],
	"archer": [
		{"name": "Tembakan Tembus", "cd": 6.0, "kind": "line", "icon": "arrow", "dist": 270.0, "w": 26.0, "mult": 2.6, "src": "melee", "col": Color(0.7, 1, 0.5)},
		{"name": "Jebakan Duri", "cd": 9.0, "kind": "area", "icon": "leaf", "at": "ahead", "dist": 90.0, "r": 75.0, "mult": 0.8, "src": "melee", "pulses": 3, "gap": 0.4, "status": "poison", "col": Color(0.6, 0.9, 0.3)},
		{"name": "Tarian Angin", "cd": 8.0, "kind": "dash", "icon": "dash", "dist": 150.0, "mult": 1.2, "src": "melee", "col": Color(0.8, 1, 0.9)},
		{"name": "Badai Panah", "cd": 14.0, "kind": "area", "icon": "arrows", "at": "self", "r": 150.0, "mult": 0.7, "src": "melee", "pulses": 6, "gap": 0.2, "col": Color(0.7, 1, 0.5)},
	],
	"swordsman": [
		{"name": "Tusukan Kilat", "cd": 5.0, "kind": "line", "icon": "stab", "dist": 165.0, "w": 26.0, "mult": 2.2, "src": "melee", "col": Color(0.8, 0.95, 1)},
		{"name": "Tebasan Bulan", "cd": 8.0, "kind": "area", "icon": "slash", "at": "ahead", "dist": 60.0, "r": 100.0, "mult": 2.4, "src": "melee", "col": Color(0.9, 0.95, 1)},
		{"name": "Tarian Pedang", "cd": 10.0, "kind": "area", "icon": "spin", "at": "self", "r": 82.0, "mult": 0.9, "src": "melee", "pulses": 4, "gap": 0.15, "col": Color(0.8, 0.95, 1)},
		{"name": "Iai Pamungkas", "cd": 13.0, "kind": "dash", "icon": "dash", "dist": 230.0, "mult": 3.4, "src": "melee", "col": Color(1, 1, 1)},
	],
	"priest": [
		{"name": "Penyembuhan", "cd": 12.0, "kind": "buff", "icon": "heal", "heal": 0.45, "col": Color(1, 0.5, 0.6)},
		{"name": "Palu Suci", "cd": 9.0, "kind": "area", "icon": "burst", "at": "ahead", "dist": 70.0, "r": 85.0, "mult": 2.4, "src": "magic", "col": Color(1, 0.95, 0.6)},
		{"name": "Berkah Pelindung", "cd": 14.0, "kind": "buff", "icon": "shield", "invuln": 2.5, "heal": 0.1, "col": Color(0.6, 0.85, 1)},
		{"name": "Hukuman Surgawi", "cd": 15.0, "kind": "area", "icon": "nova", "at": "ahead", "dist": 110.0, "r": 125.0, "mult": 4.0, "src": "magic", "col": Color(1, 0.95, 0.5)},
	],
	"shade": [
		{"name": "Tusuk Belakang", "cd": 5.0, "kind": "line", "icon": "dagger", "dist": 115.0, "w": 26.0, "mult": 2.8, "src": "melee", "crit": true, "col": Color(0.7, 0.4, 1)},
		{"name": "Bom Asap", "cd": 11.0, "kind": "area", "icon": "star", "at": "self", "r": 105.0, "mult": 1.1, "src": "melee", "invuln": 1.2, "col": Color(0.55, 0.55, 0.7)},
		{"name": "Tarian Belati", "cd": 10.0, "kind": "area", "icon": "spin", "at": "self", "r": 78.0, "mult": 0.8, "src": "melee", "pulses": 5, "gap": 0.12, "col": Color(0.65, 0.35, 0.95)},
		{"name": "Eksekusi", "cd": 14.0, "kind": "blink", "icon": "dagger", "range": 340.0, "mult": 4.0, "src": "melee", "crit": true, "col": Color(0.8, 0.2, 0.5)},
	],
	"tamer": [
		{"name": "Cakar Serigala", "cd": 6.0, "kind": "line", "icon": "paw", "dist": 105.0, "w": 42.0, "mult": 2.0, "src": "melee", "col": Color(0.7, 0.9, 0.5)},
		{"name": "Raungan", "cd": 11.0, "kind": "area", "icon": "burst", "at": "self", "r": 130.0, "mult": 1.0, "src": "melee", "heal": 0.1, "col": Color(0.9, 0.8, 0.4)},
		{"name": "Sulur Pengikat", "cd": 9.0, "kind": "area", "icon": "leaf", "at": "ahead", "dist": 80.0, "r": 90.0, "mult": 0.8, "src": "melee", "pulses": 3, "gap": 0.4, "status": "poison", "col": Color(0.4, 0.9, 0.4)},
		{"name": "Amukan Rimba", "cd": 15.0, "kind": "area", "icon": "paw", "at": "self", "r": 130.0, "mult": 1.2, "src": "melee", "pulses": 6, "gap": 0.25, "col": Color(0.5, 0.9, 0.3)},
	],
	"alchemist": [
		{"name": "Botol Api", "cd": 7.0, "kind": "area", "icon": "flame", "at": "ahead", "dist": 95.0, "r": 72.0, "mult": 2.0, "src": "magic", "status": "burn", "col": Color(1, 0.5, 0.2)},
		{"name": "Kabut Beracun", "cd": 10.0, "kind": "area", "icon": "drop", "at": "ahead", "dist": 100.0, "r": 110.0, "mult": 0.7, "src": "magic", "pulses": 4, "gap": 0.4, "status": "poison", "col": Color(0.55, 1, 0.35)},
		{"name": "Eliksir", "cd": 13.0, "kind": "buff", "icon": "heal", "heal": 0.3, "mp": 0.2, "col": Color(0.5, 1, 0.7)},
		{"name": "Ledakan Reaksi", "cd": 14.0, "kind": "area", "icon": "meteor", "at": "ahead", "dist": 110.0, "r": 125.0, "mult": 4.0, "src": "magic", "status": "burn", "col": Color(1, 0.7, 0.2)},
	],
	"root_guard": [
		{"name": "Tusukan Akar", "cd": 6.0, "kind": "line", "icon": "stab", "dist": 150.0, "w": 34.0, "mult": 2.6, "src": "melee", "col": Color(0.5, 0.9, 0.3)},
		{"name": "Dinding Akar", "cd": 11.0, "kind": "area", "icon": "shield", "at": "self", "r": 80.0, "mult": 1.2, "src": "melee", "invuln": 2.0, "col": Color(0.4, 0.8, 0.3)},
		{"name": "Gempa Rimba", "cd": 12.0, "kind": "area", "icon": "burst", "at": "ahead", "dist": 70.0, "r": 115.0, "mult": 2.8, "src": "melee", "col": Color(0.6, 0.8, 0.3)},
		{"name": "Regenerasi Akar", "cd": 15.0, "kind": "buff", "icon": "leaf", "heal": 0.4, "invuln": 1.0, "col": Color(0.5, 1, 0.5)},
	],
	"seal_weaver": [
		{"name": "Rantai Es", "cd": 7.0, "kind": "line", "icon": "snow", "dist": 240.0, "w": 34.0, "mult": 2.0, "src": "magic", "status": "freeze", "col": Color(0.7, 0.9, 1)},
		{"name": "Segel Petir", "cd": 10.0, "kind": "area", "icon": "nova", "at": "self", "r": 140.0, "mult": 1.0, "src": "magic", "pulses": 3, "gap": 0.3, "col": Color(0.8, 0.85, 1)},
		{"name": "Badai Salju", "cd": 13.0, "kind": "area", "icon": "snow", "at": "ahead", "dist": 110.0, "r": 120.0, "mult": 1.2, "src": "magic", "pulses": 4, "gap": 0.35, "status": "freeze", "col": Color(0.8, 0.95, 1)},
		{"name": "Segel Pamungkas", "cd": 16.0, "kind": "area", "icon": "star", "at": "self", "r": 160.0, "mult": 4.2, "src": "magic", "status": "freeze", "col": Color(0.7, 0.7, 1)},
	],
	"mist_shade": [
		{"name": "Tusukan Kabut", "cd": 5.0, "kind": "line", "icon": "dagger", "dist": 130.0, "w": 26.0, "mult": 3.0, "src": "melee", "crit": true, "col": Color(0.75, 0.75, 0.95)},
		{"name": "Langkah Kabut", "cd": 8.0, "kind": "dash", "icon": "dash", "dist": 180.0, "mult": 1.6, "src": "melee", "invuln": 0.6, "col": Color(0.8, 0.8, 1)},
		{"name": "Pusaran Kabut", "cd": 10.0, "kind": "area", "icon": "spin", "at": "self", "r": 85.0, "mult": 1.0, "src": "melee", "pulses": 5, "gap": 0.13, "col": Color(0.7, 0.7, 0.9)},
		{"name": "Pembunuh Senyap", "cd": 14.0, "kind": "blink", "icon": "dagger", "range": 360.0, "mult": 4.6, "src": "melee", "crit": true, "col": Color(0.9, 0.4, 0.6)},
	],
	"wild_caller": [
		{"name": "Tombak Roh", "cd": 6.0, "kind": "line", "icon": "arrow", "dist": 250.0, "w": 28.0, "mult": 2.6, "src": "melee", "col": Color(0.4, 1, 0.6)},
		{"name": "Hujan Daun", "cd": 9.0, "kind": "area", "icon": "leaf", "at": "ahead", "dist": 100.0, "r": 85.0, "mult": 0.8, "src": "melee", "pulses": 4, "gap": 0.3, "col": Color(0.5, 1, 0.5)},
		{"name": "Tanduk Rusa", "cd": 11.0, "kind": "line", "icon": "paw", "dist": 120.0, "w": 44.0, "mult": 2.8, "src": "melee", "col": Color(0.7, 0.95, 0.5)},
		{"name": "Hutan Murka", "cd": 15.0, "kind": "area", "icon": "burst", "at": "self", "r": 140.0, "mult": 1.3, "src": "melee", "pulses": 5, "gap": 0.25, "heal": 0.1, "col": Color(0.4, 1, 0.5)},
	],
	"seed_brewer": [
		{"name": "Botol Benih", "cd": 7.0, "kind": "area", "icon": "drop", "at": "ahead", "dist": 95.0, "r": 75.0, "mult": 1.8, "src": "magic", "status": "poison", "col": Color(0.6, 1, 0.5)},
		{"name": "Embun Penyembuh", "cd": 12.0, "kind": "buff", "icon": "heal", "heal": 0.4, "mp": 0.15, "col": Color(0.6, 1, 0.8)},
		{"name": "Ledakan Spora", "cd": 10.0, "kind": "area", "icon": "burst", "at": "self", "r": 125.0, "mult": 1.5, "src": "magic", "status": "poison", "col": Color(0.8, 1, 0.4)},
		{"name": "Hutan Racun", "cd": 15.0, "kind": "area", "icon": "leaf", "at": "ahead", "dist": 110.0, "r": 130.0, "mult": 0.9, "src": "magic", "pulses": 5, "gap": 0.35, "status": "poison", "heal": 0.05, "col": Color(0.5, 1, 0.35)},
	],
	"seed_bearer": [
		{"name": "Tombak Cahaya", "cd": 6.0, "kind": "line", "icon": "stab", "dist": 190.0, "w": 34.0, "mult": 3.0, "src": "best", "col": Color(0.9, 1, 0.6)},
		{"name": "Pelindung Benih", "cd": 12.0, "kind": "buff", "icon": "shield", "invuln": 2.5, "heal": 0.2, "col": Color(0.7, 1, 0.6)},
		{"name": "Mekar Penuh", "cd": 12.0, "kind": "area", "icon": "nova", "at": "self", "r": 150.0, "mult": 2.0, "src": "best", "heal": 0.15, "col": Color(0.8, 1, 0.5)},
		{"name": "Panen Akhir", "cd": 16.0, "kind": "area", "icon": "star", "at": "self", "r": 170.0, "mult": 1.4, "src": "best", "pulses": 5, "gap": 0.3, "heal": 0.05, "col": Color(1, 0.95, 0.5)},
	],
}
