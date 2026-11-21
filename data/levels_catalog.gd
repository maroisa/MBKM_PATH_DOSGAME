class_name LevelsCatalog
extends RefCounted
## Bank soal modular untuk 5 Minigame (4 level per minigame = 20 tantangan).


static func get_minigames_meta() -> Array[Dictionary]:
	return [
		{
			"id": "mg1",
			"code": "CMD_PATCH.EXE",
			"title": "1. Debugger Sintaks",
			"subtitle": "Perbaiki perintah DOS yang rusak atau tertukar sintaks Linux.",
			"scene_path": "res://scenes/minigames/mg1_command_patch/mg1_command_patch.tscn",
			"topics": "MOVE, COPY, REN, RD /S, path \\"
		},
		{
			"id": "mg2",
			"code": "FLOW_BATCH",
			"title": "2. Rakit Flowchart",
			"subtitle": "Susun urutan blok langkah kerja agar simulasi folder berhasil.",
			"scene_path": "res://scenes/minigames/mg2_flowchart_builder/mg2_flowchart_builder.tscn",
			"topics": "MD, CD, COPY CON, Ctrl+Z, TYPE"
		},
		{
			"id": "mg3",
			"code": "GATE_LOCK.EXE",
			"title": "3. Filter Wildcard",
			"subtitle": "Tentukan pola * dan ? agar hanya file [ALLOW] yang lolos.",
			"scene_path": "res://scenes/minigames/mg3_wildcard_gate/mg3_wildcard_gate.tscn",
			"topics": "Wildcard *, ?, DIR, DEL, COPY"
		},
		{
			"id": "mg4",
			"code": "TREE_SWEEPER",
			"title": "4. Labirin Direktori",
			"subtitle": "Jelajahi pohon folder, temukan file hidden, dan penuhi syarat RD.",
			"scene_path": "res://scenes/minigames/mg4_tree_sweeper/mg4_tree_sweeper.tscn",
			"topics": "TREE, CD, CD .., DIR /a, DEL, RD"
		},
		{
			"id": "mg5",
			"code": "CRT_CONFIG",
			"title": "5. Studio Layar & .BAT",
			"subtitle": "Cocokkan target layar dengan parameter DIR, PROMPT, & skrip .BAT.",
			"scene_path": "res://scenes/minigames/mg5_crt_config/mg5_crt_config.tscn",
			"topics": "DIR /o /b, CLS, VER, VOL, PROMPT, .BAT"
		}
	]


static func get_levels(mg_id: String) -> Array[Dictionary]:
	match mg_id:
		"mg1":
			return _mg1_levels()
		"mg2":
			return _mg2_levels()
		"mg3":
			return _mg3_levels()
		"mg4":
			return _mg4_levels()
		"mg5":
			return _mg5_levels()
		_:
			return []


static func _mg1_levels() -> Array[Dictionary]:
	return [
		{
			"id": "mg1_l1",
			"prompt_dir": "C:\\>",
			"mission": "Pindahkan seluruh folder beserta isi dari Downloads ke Kokop pada Windows Command Prompt!",
			"tokens": [
				{"text": "cp", "editable": true, "answer": "MOVE", "hint_slot": "Perintah pindah Windows"},
				{"text": "Users\\CZ\\Downloads", "editable": false},
				{"text": "Users\\CZ\\Kokop", "editable": false}
			],
			"choices": ["MOVE", "COPY", "DIR", "mv", "DEL"],
			"hint": "Perintah 'cp' dan 'mv' berasal dari Linux. Di Windows DOS, gunakan MOVE untuk memindahkan.",
			"wrong_messages": {
				"mv": "'mv' is not recognized as an internal or external command in DOS! Itu perintah Linux.",
				"COPY": "COPY hanya menyalin file tanpa memindahkan folder asalnya.",
				"DIR": "DIR hanya menampilkan daftar isi direktori.",
				"DEL": "DEL justru menghapus file, bukan memindahkan!"
			},
			"success_output": "        1 dir(s) moved.\nSeluruh isi Users\\CZ\\Downloads berhasil dipindahkan ke Users\\CZ\\Kokop."
		},
		{
			"id": "mg1_l2",
			"prompt_dir": "A:\\>",
			"mission": "Salin berkas tugas.doc ke C:\\latdos TANPA menghapus berkas aslinya di drive A:\\!",
			"tokens": [
				{"text": "REN", "editable": true, "answer": "COPY", "hint_slot": "Perintah salin"},
				{"text": "A:\\tugas.doc", "editable": false},
				{"text": "C:\\latdos", "editable": false}
			],
			"choices": ["COPY", "MOVE", "REN", "TYPE", "cp"],
			"hint": "REN untuk ganti nama, MOVE untuk pindah. Untuk menyalin ke lokasi lain gunakan COPY.",
			"wrong_messages": {
				"MOVE": "MOVE akan menghapus file dari lokasi asal A:\\!",
				"REN": "REN hanya mengganti nama file di direktori yang sama.",
				"TYPE": "TYPE hanya menampilkan isi teks file ke layar.",
				"cp": "'cp' bukan perintah DOS/Windows CMD (itu perintah Linux)."
			},
			"success_output": "        1 file(s) copied.\nA:\\tugas.doc berhasil disalin ke C:\\latdos tanpa menghapus aslinya."
		},
		{
			"id": "mg1_l3",
			"prompt_dir": "C:\\latdos>",
			"mission": "Ubah nama berkas tugasm~1.doc menjadi tugasku.doc tanpa mengubah isi berkasnya.",
			"tokens": [
				{"text": "TYPE", "editable": true, "answer": "REN", "hint_slot": "Perintah ubah nama"},
				{"text": "tugasm~1.doc", "editable": false},
				{"text": "tugasku.doc", "editable": false}
			],
			"choices": ["REN", "MOVE", "COPY", "MD", "DEL"],
			"hint": "Singkatan dari Rename di DOS adalah REN.",
			"wrong_messages": {
				"MOVE": "Untuk sekadar mengganti nama di folder yang sama, materi memakai perintah khusus REN.",
				"COPY": "COPY akan menggandakan berkas sehingga ada 2 berkas.",
				"MD": "MD (Make Directory) digunakan untuk membuat folder baru.",
				"DEL": "DEL akan menghapus berkas!"
			},
			"success_output": "Nama berkas tugasm~1.doc berhasil diubah menjadi tugasku.doc."
		},
		{
			"id": "mg1_l4",
			"prompt_dir": "C:\\>",
			"mission": "Hapus folder D:\\lama beserta seluruh isinya di Windows Command Prompt modern (cmd.exe)!",
			"tokens": [
				{"text": "DELTREE", "editable": true, "answer": "RD /S", "hint_slot": "Perintah hapus folder modern"},
				{"text": "D:/lama", "editable": true, "answer": "D:\\lama", "hint_slot": "Path Windows"}
			],
			"choices": ["RD /S", "DEL", "D:\\lama", "D:/lama", "rm -rf"],
			"hint": "DELTREE sudah dihapus sejak Windows XP (gantinya RD /S), dan Windows memakai pemisah backslash (\\).",
			"wrong_messages": {
				"DEL": "DEL hanya menghapus file, tidak menghapus struktur folder.",
				"rm -rf": "'rm' adalah perintah Linux, bukan Windows CMD!",
				"D:/lama": "Sintaks path standar DOS/Windows memakai backslash (\\), bukan slash (/)."
			},
			"success_output": "D:\\lama, Are you sure (Y/N)? Y\nDirektori D:\\lama beserta seluruh sub-folder dan isinya berhasil dihapus."
		}
	]


static func _mg2_levels() -> Array[Dictionary]:
	return [
		{
			"id": "mg2_l1",
			"start_dir": "C:\\>",
			"mission": "Buat folder bernama 'cc', masuk ke folder tersebut, buat file 'ok.txt' berisi teks 'bebas', lalu tampilkan isinya!",
			"answer_sequence": ["MD cc", "CD cc", "COPY CON ok.txt", "Isi \"bebas\" + [Ctrl+Z]", "TYPE ok.txt"],
			"blocks": ["MD cc", "CD cc", "COPY CON ok.txt", "Isi \"bebas\" + [Ctrl+Z]", "TYPE ok.txt", "CD ..", "RD cc", "DEL ok.txt"],
			"hint": "Urutan logis: buat folder -> masuk folder -> buka COPY CON -> isi & simpan Ctrl+Z -> baca dengan TYPE."
		},
		{
			"id": "mg2_l2",
			"start_dir": "D:\\>",
			"mission": "Di drive D:\\, buat folder 'XRPLb', masuk ke dalamnya, buat sub-folder 'tugas', lalu kembali naik satu tingkat ke D:\\.",
			"answer_sequence": ["MD XRPLb", "CD XRPLb", "MD tugas", "CD .."],
			"blocks": ["MD XRPLb", "CD XRPLb", "MD tugas", "CD ..", "RD tugas", "CD tugas", "TREE"],
			"hint": "Setelah MD XRPLb, Anda harus masuk dulu dengan CD XRPLb sebelum membuat sub-folder 'tugas'."
		},
		{
			"id": "mg2_l3",
			"start_dir": "D:\\tugas>",
			"mission": "Salin berkas 'ortuq.txt' menjadi 'copytgas.txt', ganti namanya menjadi 'gantinma.txt', lalu tampilkan isinya ke layar.",
			"answer_sequence": ["COPY ortuq.txt copytgas.txt", "REN copytgas.txt gantinma.txt", "TYPE gantinma.txt"],
			"blocks": ["COPY ortuq.txt copytgas.txt", "REN copytgas.txt gantinma.txt", "TYPE gantinma.txt", "MOVE ortuq.txt copytgas.txt", "DEL copytgas.txt"],
			"hint": "Gunakan COPY (bukan MOVE agar ortuq.txt tetap ada), lalu REN, terakhir TYPE."
		},
		{
			"id": "mg2_l4",
			"start_dir": "C:\\>",
			"mission": "Rakit langkah membuat skrip 'LATIHAN.BAT' yang menyembunyikan baris perintah, membersihkan layar, mencetak 'SMK', lalu menjeda layar.",
			"answer_sequence": ["COPY CON LATIHAN.BAT", "@ECHO OFF", "CLS", "ECHO SMK", "PAUSE + [Ctrl+Z]"],
			"blocks": ["COPY CON LATIHAN.BAT", "@ECHO OFF", "CLS", "ECHO SMK", "PAUSE + [Ctrl+Z]", "ECHO ON", "DEL LATIHAN.BAT", "TYPE LATIHAN.BAT"],
			"hint": "Mulai dengan COPY CON LATIHAN.BAT, pasang @ECHO OFF di awal isi skrip, CLS, ECHO SMK, lalu PAUSE & simpan Ctrl+Z."
		}
	]


static func _mg3_levels() -> Array[Dictionary]:
	return [
		{
			"id": "mg3_l1",
			"header": "C:\\SERVER\\SECURITY> GATE_LOCK.EXE --FILTER-MODE",
			"command_prefix": "DIR",
			"command_suffix": "",
			"mission": "Tentukan pola wildcard agar HANYA file [ALLOW] yang lolos dan semua file [DENY] tertolak!",
			"allow_files": ["bebek.exe", "tebek.exe", "lebek.exe"],
			"deny_files": ["bebek.doc", "ketek.exe", "ebek.exe", "tugasku.exe", "tebek_lama.exe"],
			"tokens": ["?", "*", "ebek", "ketek", ".exe", ".doc", "tugas"],
			"answer_pattern": "?ebek.exe",
			"hint": "Semua [ALLOW] berekstensi .exe, berakhiran 'ebek', dan punya TEPAT 1 huruf di depan (ebek.exe harus ditolak)."
		},
		{
			"id": "mg3_l2",
			"header": "C:\\latdos> CLEANER.EXE --SAFE-DELETE",
			"command_prefix": "DEL",
			"command_suffix": "",
			"mission": "Hapus semua berkas berekstensi .doc [ALLOW] tanpa menyentuh file .exe, .txt, atau .docx [DENY]!",
			"allow_files": ["tugas1.doc", "catatan.doc", "ortuq.doc"],
			"deny_files": ["sistem.exe", "readme.txt", "tugas.docx", "foto.jpg"],
			"tokens": ["*", "?", "tugas", ".doc", ".docx", ".exe", ".txt"],
			"answer_pattern": "*.doc",
			"hint": "Gunakan '*' untuk mewakili nama depan dengan panjang bebas, lalu akhiri tepat dengan '.doc'."
		},
		{
			"id": "mg3_l3",
			"header": "A:\\> BACKUP_FILTER.EXE --MATCH-THIRD-CHAR",
			"command_prefix": "COPY",
			"command_suffix": "C:\\latdos",
			"mission": "Salin hanya file yang HURUF KETIGANYA adalah 'g' (ekstensi bebas) ke C:\\latdos!",
			"allow_files": ["tugas.doc", "lagu.mp3", "log.txt", "sagu.xls"],
			"deny_files": ["gambar.png", "agama.pdf", "file.txt", "go.exe"],
			"tokens": ["?", "*", "g", ".", "a", ".txt"],
			"answer_pattern": "??g*.*",
			"hint": "Dua huruf bebas di depan ('??'), huruf ke-3 'g', sisa nama bebas ('*'), lalu ekstensi bebas ('.*')."
		},
		{
			"id": "mg3_l4",
			"header": "D:\\ARSIP> REPORT_SCAN.EXE --STRICT-2-DIGIT",
			"command_prefix": "DIR",
			"command_suffix": "",
			"mission": "Tampilkan berkas 'laporan_' yang diikuti TEPAT 2 karakter nomor urut dan berekstensi .txt!",
			"allow_files": ["laporan_01.txt", "laporan_09.txt", "laporan_12.txt"],
			"deny_files": ["laporan_1.txt", "laporan_final.txt", "laporan_01.doc", "rekap_01.txt"],
			"tokens": ["laporan_", "rekap_", "?", "*", ".txt", ".doc"],
			"answer_pattern": "laporan_??.txt",
			"hint": "Karena panjang akhiran setelah 'laporan_' harus tepat 2 karakter (bukan 1 atau 5), gunakan dua '?' bukan '*'."
		}
	]


static func _mg4_levels() -> Array[Dictionary]:
	return [
		{
			"id": "mg4_l1",
			"mission": "Hapus folder kosong 'sampah'! Ingat syarat #1 perintah RD: posisi prompt harus di luar folder target.",
			"target_folder_path": "D:\\latdos\\sampah",
			"start_path": "D:\\latdos\\sampah",
			"par_moves": 2,
			"tree": {
				"D:": {
					"files": [],
					"hidden": [],
					"children": {
						"latdos": {
							"files": ["catatan.txt"],
							"hidden": [],
							"children": {
								"sampah": {"files": [], "hidden": [], "children": {}}
							}
						}
					}
				}
			},
			"hint": "Anda sedang berada di dalam D:\\latdos\\sampah>. Jalankan CD .. dahulu sebelum RD sampah."
		},
		{
			"id": "mg4_l2",
			"mission": "Bersihkan isi lalu hapus folder 'terbenci' (saat ini berisi ortuq.txt).",
			"target_folder_path": "D:\\XRPLb\\photo\\terbenci",
			"start_path": "D:\\XRPLb\\photo\\terbenci",
			"par_moves": 3,
			"tree": {
				"D:": {
					"files": [],
					"hidden": [],
					"children": {
						"XRPLb": {
							"files": [],
							"hidden": [],
							"children": {
								"photo": {
									"files": [],
									"hidden": [],
									"children": {
										"tersayang": {"files": ["biodata.txt"], "hidden": [], "children": {}},
										"terbenci": {"files": ["ortuq.txt"], "hidden": [], "children": {}}
									}
								}
							}
						}
					}
				}
			},
			"hint": "Hapus ortuq.txt dengan DEL ortuq.txt, keluar ke folder induk (CD ..), lalu jalankan RD terbenci."
		},
		{
			"id": "mg4_l3",
			"mission": "Hapus folder 'GNA'! Folder ini tampak kosong saat dilihat biasa, pastikan benar-benar bersih sebelum dihapus.",
			"target_folder_path": "D:\\XRPLb\\tugas\\GNA",
			"start_path": "D:\\XRPLb\\tugas",
			"par_moves": 5,
			"tree": {
				"D:": {
					"files": [],
					"hidden": [],
					"children": {
						"XRPLb": {
							"files": [],
							"hidden": [],
							"children": {
								"tugas": {
									"files": [],
									"hidden": [],
									"children": {
										"GNA": {"files": [], "hidden": ["rahasia.sys"], "children": {}},
										"Produktif": {"files": ["modul.txt"], "hidden": [], "children": {}}
									}
								}
							}
						}
					}
				}
			},
			"hint": "Masuk ke GNA (CD GNA), periksa berkas tersembunyi dengan DIR /a, hapus rahasia.sys, keluar (CD ..), lalu RD GNA."
		},
		{
			"id": "mg4_l4",
			"mission": "Anda sedang di folder 'pdf'. Pindah ke folder saudara 'powpoint', bersihkan isinya, lalu hapus folder 'powpoint'!",
			"target_folder_path": "D:\\XRPLb\\modul\\powpoint",
			"start_path": "D:\\XRPLb\\modul\\pdf",
			"par_moves": 5,
			"tree": {
				"D:": {
					"files": [],
					"hidden": [],
					"children": {
						"XRPLb": {
							"files": [],
							"hidden": [],
							"children": {
								"modul": {
									"files": [],
									"hidden": [],
									"children": {
										"pdf": {"files": ["dos.pdf"], "hidden": [], "children": {}},
										"powpoint": {"files": ["draft.ppt"], "hidden": [], "children": {}}
									}
								}
							}
						}
					}
				}
			},
			"hint": "Naik ke 'modul' (CD ..) -> masuk 'powpoint' (CD powpoint) -> DEL draft.ppt -> CD .. -> RD powpoint."
		}
	]


static func _mg5_levels() -> Array[Dictionary]:
	return [
		{
			"id": "mg5_l1",
			"mode": "dir_flags",
			"mission": "Atur perintah DIR agar menampilkan NAMA FILE SAJA per baris, diurutkan dari UKURAN TERBESAR ke TERKECIL!",
			"target_lines": [
				"app.exe",
				"data.csv",
				"notes.txt"
			],
			"sample_files": [
				{"name": "notes.txt", "ext": "txt", "size": 2048, "date": 20260110},
				{"name": "app.exe", "ext": "exe", "size": 49152, "date": 20260105},
				{"name": "data.csv", "ext": "csv", "size": 12288, "date": 20260120}
			],
			"tokens": ["DIR", "/o-s", "/os", "/on", "/b", "/w"],
			"answer_tokens": ["DIR", "/o-s", "/b"],
			"hint": "/o-s mengurutkan ukuran terbesar -> terkecil (tanda minus membalik urutan), dan /b menampilkan nama saja."
		},
		{
			"id": "mg5_l2",
			"mode": "screen_info",
			"mission": "Layar penuh teks error! Bersihkan layar (CLS), lalu tampilkan versi OS (VER) dan label volume disk (VOL).",
			"target_lines": [
				"Microsoft Windows [Version 10.0.22631]",
				"Volume in drive D is DATA_SMK",
				"Volume Serial Number is 4A2C-99F1"
			],
			"tokens": ["CLS", "VER", "VOL", "DATE", "TIME", "DIR"],
			"answer_tokens": ["CLS", "VER", "VOL"],
			"hint": "Mulai dengan CLS agar teks sampah hilang, diikuti VER lalu VOL."
		},
		{
			"id": "mg5_l3",
			"mode": "prompt",
			"mission": "Ubah tampilan prompt menjadi baris 1 bertuliskan 'SMK', lalu baris 2 menampilkan path aktif dan karakter '>'!",
			"base_path": "D:\\TUGAS",
			"target_lines": [
				"SMK",
				"D:\\TUGAS>"
			],
			"tokens": ["PROMPT", "SMK", "$_", "$P", "$G", "$L", "$T", "$$"],
			"answer_tokens": ["PROMPT", "SMK", "$_", "$P", "$G"],
			"hint": "Sesuai kode PROMPT: teks 'SMK', lalu $_ (pindah baris), $P (path aktif), dan $G (tanda '>')."
		},
		{
			"id": "mg5_l4",
			"mode": "batch",
			"mission": "Rakit isi skrip .BAT agar baris perintah tersembunyi, layar bersih, mencetak 'SISTEM SIAP', menjeda tombol, lalu cek tanggal!",
			"target_lines": [
				"SISTEM SIAP",
				"Press any key to continue . . .",
				"The current date is: Sat 11/21/2026"
			],
			"tokens": ["@ECHO OFF", "CLS", "ECHO SISTEM SIAP", "PAUSE", "DATE", "ECHO ON", "TIME"],
			"answer_tokens": ["@ECHO OFF", "CLS", "ECHO SISTEM SIAP", "PAUSE", "DATE"],
			"hint": "Gunakan @ECHO OFF di awal, CLS, ECHO SISTEM SIAP, PAUSE, lalu DATE."
		}
	]
