class_name LevelsCatalog
extends RefCounted
## Bank soal modular untuk 5 Minigame (4 level per minigame = 20 tantangan) + pengacak pilihan Fisher-Yates.

static var _shuffle_rng: RandomNumberGenerator = null


static func shuffled_choices(items: Array, avoid_prefix: Array = []) -> Array[String]:
	if _shuffle_rng == null:
		_shuffle_rng = RandomNumberGenerator.new()
		_shuffle_rng.randomize()
	var out: Array[String] = []
	for item: Variant in items:
		out.append(str(item))
	if out.size() <= 1:
		return out

	var avoid_strs: Array[String] = []
	for a: Variant in avoid_prefix:
		avoid_strs.append(str(a))

	# Fisher-Yates acak sejati; ulangi singkat bila kebetulan tepat sama dengan urutan jawaban/asli
	var orig: Array[String] = out.duplicate()
	for _attempt: int in range(6):
		for i: int in range(out.size() - 1, 0, -1):
			var j: int = _shuffle_rng.randi_range(0, i)
			var tmp: String = out[i]
			out[i] = out[j]
			out[j] = tmp
		var matches_orig: bool = (out == orig)
		var matches_avoid: bool = false
		if not avoid_strs.is_empty() and avoid_strs.size() <= out.size():
			matches_avoid = true
			for k: int in range(avoid_strs.size()):
				if out[k] != avoid_strs[k]:
					matches_avoid = false
					break
		if not matches_orig and not matches_avoid:
			break
	return out


static func get_minigames_meta() -> Array[Dictionary]:
	return [
		{
			"id": "mg1",
			"code": "CMD_PATCH.EXE",
			"title": "1. Lengkapi Perintah DOS",
			"subtitle": "Isi slot kosong dengan perintah DOS Windows yang tepat.",
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
			"mission": "Pindahkan seluruh folder 'Arsip' beserta isinya dari D:\\Kerja ke D:\\Backup pada Windows CMD (bukan sekadar menyalin dan bukan perintah Linux!). Pilih blok perintah yang tepat untuk mengisi slot kosong.",
			"tokens": [
				{"text": "", "editable": true, "answer": "MOVE", "hint_slot": "Perintah pindah Windows"},
				{"text": "D:\\Kerja\\Arsip", "editable": false},
				{"text": "D:\\Backup", "editable": false}
			],
			"choices": ["MOVE", "COPY", "DIR", "mv", "DEL"],
			"hint": "Perintah 'mv' berasal dari Linux. Di Windows Command Prompt, gunakan MOVE untuk memindahkan folder.",
			"wrong_messages": {
				"mv": "'mv' is not recognized as an internal or external command in DOS! Itu perintah Linux.",
				"COPY": "COPY hanya menyalin berkas tanpa memindahkan folder asalnya.",
				"DIR": "DIR hanya menampilkan daftar isi direktori.",
				"DEL": "DEL digunakan untuk menghapus berkas, bukan memindahkan."
			},
			"success_output": "        1 dir(s) moved.\nFolder D:\\Kerja\\Arsip beserta isinya berhasil dipindahkan ke D:\\Backup."
		},
		{
			"id": "mg1_l2",
			"prompt_dir": "D:\\>",
			"mission": "Salin berkas modul.txt dari D:\\Materi ke C:\\Praktik pada Windows CMD agar berkas aslinya di D:\\Materi TETAP ADA (tidak terpindah/terhapus). Isi slot kosong di bawah dengan perintah yang tepat.",
			"tokens": [
				{"text": "", "editable": true, "answer": "COPY", "hint_slot": "Perintah salin"},
				{"text": "D:\\Materi\\modul.txt", "editable": false},
				{"text": "C:\\Praktik", "editable": false}
			],
			"choices": ["COPY", "MOVE", "REN", "TYPE", "cp"],
			"hint": "REN untuk ganti nama, MOVE untuk pindah. Untuk menyalin ke lokasi lain gunakan COPY.",
			"wrong_messages": {
				"MOVE": "MOVE akan memindahkan dan menghapus berkas dari lokasi asal D:\\Materi!",
				"REN": "REN hanya mengganti nama berkas di direktori yang sama.",
				"TYPE": "TYPE hanya menampilkan isi teks berkas ke layar.",
				"cp": "'cp' bukan perintah DOS/Windows CMD (itu perintah Linux)."
			},
			"success_output": "        1 file(s) copied.\nD:\\Materi\\modul.txt berhasil disalin ke C:\\Praktik tanpa menghapus aslinya."
		},
		{
			"id": "mg1_l3",
			"prompt_dir": "C:\\Praktik>",
			"mission": "Ganti nama berkas draf_01.txt menjadi laporan_final.txt di dalam folder aktif C:\\Praktik tanpa menggandakan berkas atau mengubah isinya. Isi slot kosong di bawah dengan perintah yang tepat.",
			"tokens": [
				{"text": "", "editable": true, "answer": "REN", "hint_slot": "Perintah ubah nama"},
				{"text": "draf_01.txt", "editable": false},
				{"text": "laporan_final.txt", "editable": false}
			],
			"choices": ["REN", "MOVE", "COPY", "MD", "DEL"],
			"hint": "Singkatan dari Rename di DOS adalah REN.",
			"wrong_messages": {
				"MOVE": "Untuk sekadar mengganti nama di folder yang sama, gunakan perintah khusus REN.",
				"COPY": "COPY akan menggandakan berkas sehingga ada 2 berkas berbeda.",
				"MD": "MD (Make Directory) digunakan untuk membuat folder baru.",
				"DEL": "DEL digunakan untuk menghapus berkas, bukan mengganti nama."
			},
			"success_output": "Nama berkas draf_01.txt berhasil diubah menjadi laporan_final.txt."
		},
		{
			"id": "mg1_l4",
			"prompt_dir": "C:\\>",
			"mission": "Hapus folder E:\\Cache beserta seluruh sub-folder dan isinya pada Windows CMD modern (cmd.exe). Isi KEDUA slot kosong dengan perintah hapus folder modern dan format path Windows yang benar!",
			"tokens": [
				{"text": "", "editable": true, "answer": "RD /S", "hint_slot": "Perintah hapus folder modern"},
				{"text": "", "editable": true, "answer": "E:\\Cache", "hint_slot": "Path Windows"}
			],
			"choices": ["RD /S", "DEL", "E:\\Cache", "E:/Cache", "rm -rf", "DELTREE"],
			"hint": "DELTREE sudah tidak tersedia di cmd.exe modern (gantinya RD /S), dan Windows memakai pemisah backslash (\\).",
			"wrong_messages": {
				"DEL": "DEL hanya menghapus file, tidak menghapus struktur folder.",
				"DELTREE": "DELTREE hanya ada pada MS-DOS lama/Win9x. Di Windows CMD modern gunakan RD /S.",
				"rm -rf": "'rm' adalah perintah Linux, bukan Windows CMD!",
				"E:/Cache": "Sintaks path standar DOS/Windows memakai backslash (\\), bukan slash (/)."
			},
			"success_output": "E:\\Cache, Are you sure (Y/N)? Y\nDirektori E:\\Cache beserta seluruh sub-folder dan isinya berhasil dihapus."
		}
	]


static func _mg2_levels() -> Array[Dictionary]:
	return [
		{
			"id": "mg2_l1",
			"start_dir": "C:\\>",
			"mission": "Susun 5 langkah berurutan di C:\\>: (1) buat folder 'proyek', (2) masuk ke 'proyek', (3) buat berkas 'catatan.txt', (4) isi teks 'siap' lalu simpan, (5) tampilkan isi 'catatan.txt' ke layar!",
			"answer_sequence": ["MD proyek", "CD proyek", "COPY CON catatan.txt", "Isi \"siap\" + [Ctrl+Z]", "TYPE catatan.txt"],
			"blocks": ["MD proyek", "CD proyek", "COPY CON catatan.txt", "Isi \"siap\" + [Ctrl+Z]", "TYPE catatan.txt", "CD ..", "RD proyek", "DEL catatan.txt"],
			"hint": "Urutan logis: buat folder -> masuk folder -> buka COPY CON -> isi & simpan Ctrl+Z -> baca dengan TYPE."
		},
		{
			"id": "mg2_l2",
			"start_dir": "D:\\>",
			"mission": "Susun 4 langkah berurutan di D:\\>: (1) buat folder 'PPLG', (2) masuk ke folder 'PPLG', (3) buat sub-folder 'praktik' di dalamnya, (4) keluar kembali satu tingkat ke D:\\.",
			"answer_sequence": ["MD PPLG", "CD PPLG", "MD praktik", "CD .."],
			"blocks": ["MD PPLG", "CD PPLG", "MD praktik", "CD ..", "RD praktik", "CD praktik", "TREE"],
			"hint": "Setelah MD PPLG, masuk dahulu dengan CD PPLG sebelum membuat sub-folder 'praktik', lalu naik dengan CD .."
		},
		{
			"id": "mg2_l3",
			"start_dir": "D:\\praktik>",
			"mission": "Susun 3 langkah berurutan di D:\\praktik>: (1) salin 'jadwal.txt' menjadi 'salinan.txt' tanpa menghapus aslinya, (2) ganti nama 'salinan.txt' menjadi 'revisi.txt', (3) tampilkan isi 'revisi.txt' ke layar.",
			"answer_sequence": ["COPY jadwal.txt salinan.txt", "REN salinan.txt revisi.txt", "TYPE revisi.txt"],
			"blocks": ["COPY jadwal.txt salinan.txt", "REN salinan.txt revisi.txt", "TYPE revisi.txt", "MOVE jadwal.txt salinan.txt", "DEL salinan.txt"],
			"hint": "Gunakan COPY (bukan MOVE agar jadwal.txt tetap ada), lalu REN, terakhir TYPE."
		},
		{
			"id": "mg2_l4",
			"start_dir": "C:\\>",
			"mission": "Susun 5 langkah membuat skrip 'MULAI.BAT' di C:\\>: (1) buka penulisan berkas batch, (2) sembunyikan tampilan perintah, (3) bersihkan layar, (4) cetak teks 'LAB PPLG', (5) jeda layar lalu simpan berkas.",
			"answer_sequence": ["COPY CON MULAI.BAT", "@ECHO OFF", "CLS", "ECHO LAB PPLG", "PAUSE + [Ctrl+Z]"],
			"blocks": ["COPY CON MULAI.BAT", "@ECHO OFF", "CLS", "ECHO LAB PPLG", "PAUSE + [Ctrl+Z]", "ECHO ON", "DEL MULAI.BAT", "TYPE MULAI.BAT"],
			"hint": "Mulai dengan COPY CON MULAI.BAT, pasang @ECHO OFF di awal isi skrip, CLS, ECHO LAB PPLG, lalu PAUSE & simpan Ctrl+Z."
		}
	]


static func _mg3_levels() -> Array[Dictionary]:
	return [
		{
			"id": "mg3_l1",
			"header": "C:\\LAB\\FILTER> GATE_LOCK.EXE --FILTER-MODE",
			"command_prefix": "DIR",
			"command_suffix": "",
			"mission": "Susun pola wildcard setelah DIR agar SEMUA file [ALLOW] (kode.exe, mode.exe, node.exe) lolos, sedangkan 'ode.exe' dan seluruh file [DENY] tertolak!",
			"allow_files": ["kode.exe", "mode.exe", "node.exe"],
			"deny_files": ["kode.txt", "data.exe", "ode.exe", "modul.exe", "node_baru.exe"],
			"tokens": ["?", "*", "ode", "data", ".exe", ".txt", "modul"],
			"answer_pattern": "?ode.exe",
			"hint": "Semua [ALLOW] berekstensi .exe, berakhiran 'ode', dan punya TEPAT 1 huruf di depan (ode.exe harus ditolak)."
		},
		{
			"id": "mg3_l2",
			"header": "D:\\DATA> CLEANER.EXE --SAFE-FILTER",
			"command_prefix": "DEL",
			"command_suffix": "",
			"mission": "Susun pola wildcard setelah DEL untuk memilih SEMUA berkas berekstensi persis '.csv' [ALLOW], tanpa menyentuh file '.csvx', '.exe', '.txt', atau '.png' [DENY]!",
			"allow_files": ["nilai_a.csv", "absen.csv", "rekap.csv"],
			"deny_files": ["aplikasi.exe", "panduan.txt", "rekap.csvx", "banner.png"],
			"tokens": ["*", "?", "rekap", ".csv", ".csvx", ".exe", ".txt"],
			"answer_pattern": "*.csv",
			"hint": "Gunakan '*' untuk mewakili nama depan dengan panjang bebas, lalu akhiri tepat dengan '.csv'."
		},
		{
			"id": "mg3_l3",
			"header": "D:\\ARSIP> BACKUP_FILTER.EXE --MATCH-THIRD-CHAR",
			"command_prefix": "COPY",
			"command_suffix": "C:\\Backup",
			"mission": "Susun pola wildcard setelah COPY agar hanya menyalin file yang HURUF KETIGANYA adalah 'r' dengan ekstensi bebas [ALLOW] ke C:\\Backup!",
			"allow_files": ["kerja.doc", "surat.pdf", "baris.txt", "kartu.png"],
			"deny_files": ["rekap.csv", "arsip.zip", "modul.txt", "er.exe"],
			"tokens": ["?", "*", "r", ".", "a", ".txt"],
			"answer_pattern": "??r*.*",
			"hint": "Dua huruf bebas di depan ('??'), huruf ke-3 'r', sisa nama bebas ('*'), lalu ekstensi bebas ('.*')."
		},
		{
			"id": "mg3_l4",
			"header": "D:\\SERVER> REPORT_SCAN.EXE --STRICT-2-DIGIT",
			"command_prefix": "DIR",
			"command_suffix": "",
			"mission": "Susun pola wildcard setelah DIR untuk menampilkan file berawalan 'praktik_' diikuti TEPAT 2 karakter nomor sesi dan berekstensi '.log' [ALLOW]!",
			"allow_files": ["praktik_01.log", "praktik_08.log", "praktik_15.log"],
			"deny_files": ["praktik_1.log", "praktik_utama.log", "praktik_01.txt", "ujian_01.log"],
			"tokens": ["praktik_", "ujian_", "?", "*", ".log", ".txt"],
			"answer_pattern": "praktik_??.log",
			"hint": "Karena panjang akhiran setelah 'praktik_' harus tepat 2 karakter (bukan 1 atau 5), gunakan dua '?' bukan '*'."
		}
	]


static func _mg4_levels() -> Array[Dictionary]:
	return [
		{
			"id": "mg4_l1",
			"mission": "Hapus folder kosong [TARGET] 'temp'! Posisimu sekarang masih berada di dalam 'temp' — keluar dulu ke folder induk sebelum menghapus folder target.",
			"target_folder_path": "D:\\kerja\\temp",
			"start_path": "D:\\kerja\\temp",
			"par_moves": 2,
			"tree": {
				"D:": {
					"files": [],
					"hidden": [],
					"children": {
						"kerja": {
							"files": ["catatan.txt"],
							"hidden": [],
							"children": {
								"temp": {"files": [], "hidden": [], "children": {}}
							}
						}
					}
				}
			},
			"hint": "Kamu sedang berada di dalam D:\\kerja\\temp>. Jalankan CD .. dahulu sebelum RD temp."
		},
		{
			"id": "mg4_l2",
			"mission": "Hapus folder [TARGET] 'arsip_lama'! Saat ini folder masih berisi berkas 'log_lama.txt'. Hapus isinya dahulu, keluar ke folder induk, lalu hapus foldernya.",
			"target_folder_path": "D:\\PPLG\\dokumen\\arsip_lama",
			"start_path": "D:\\PPLG\\dokumen\\arsip_lama",
			"par_moves": 3,
			"tree": {
				"D:": {
					"files": [],
					"hidden": [],
					"children": {
						"PPLG": {
							"files": [],
							"hidden": [],
							"children": {
								"dokumen": {
									"files": [],
									"hidden": [],
									"children": {
										"arsip_aktif": {"files": ["profil.txt"], "hidden": [], "children": {}},
										"arsip_lama": {"files": ["log_lama.txt"], "hidden": [], "children": {}}
									}
								}
							}
						}
					}
				}
			},
			"hint": "Hapus log_lama.txt dengan DEL log_lama.txt, keluar ke folder induk (CD ..), lalu jalankan RD arsip_lama."
		},
		{
			"id": "mg4_l3",
			"mission": "Hapus folder [TARGET] 'uji_coba'! Folder ini tampak kosong pada tampilan biasa, tetapi mungkin berisi file tersembunyi. Masuk, periksa file hidden, bersihkan, keluar, lalu hapus foldernya.",
			"target_folder_path": "D:\\PPLG\\praktik\\uji_coba",
			"start_path": "D:\\PPLG\\praktik",
			"par_moves": 5,
			"tree": {
				"D:": {
					"files": [],
					"hidden": [],
					"children": {
						"PPLG": {
							"files": [],
							"hidden": [],
							"children": {
								"praktik": {
									"files": [],
									"hidden": [],
									"children": {
										"uji_coba": {"files": [], "hidden": ["cache.sys"], "children": {}},
										"modul": {"files": ["panduan.txt"], "hidden": [], "children": {}}
									}
								}
							}
						}
					}
				}
			},
			"hint": "Masuk ke uji_coba (CD uji_coba), periksa berkas tersembunyi dengan DIR /a, hapus cache.sys, keluar (CD ..), lalu RD uji_coba."
		},
		{
			"id": "mg4_l4",
			"mission": "Hapus folder [TARGET] 'presentasi'! Kamu sekarang berada di folder saudara 'dokumen'. Naik ke folder 'materi', masuk ke 'presentasi', bersihkan isinya, keluar lagi, lalu hapus 'presentasi'!",
			"target_folder_path": "D:\\PPLG\\materi\\presentasi",
			"start_path": "D:\\PPLG\\materi\\dokumen",
			"par_moves": 5,
			"tree": {
				"D:": {
					"files": [],
					"hidden": [],
					"children": {
						"PPLG": {
							"files": [],
							"hidden": [],
							"children": {
								"materi": {
									"files": [],
									"hidden": [],
									"children": {
										"dokumen": {"files": ["ringkasan.pdf"], "hidden": [], "children": {}},
										"presentasi": {"files": ["draf.ppt"], "hidden": [], "children": {}}
									}
								}
							}
						}
					}
				}
			},
			"hint": "Naik ke 'materi' (CD ..) -> masuk 'presentasi' (CD presentasi) -> DEL draf.ppt -> CD .. -> RD presentasi."
		}
	]


static func _mg5_levels() -> Array[Dictionary]:
	return [
		{
			"id": "mg5_l1",
			"mode": "dir_flags",
			"mission": "Rakit perintah DIR beserta parameternya agar LIVE PREVIEW menampilkan NAMA FILE SAJA per baris (tanpa ukuran) dan diurutkan dari UKURAN TERBESAR ke TERKECIL sesuai TARGET OUTPUT!",
			"target_lines": [
				"installer.exe",
				"dataset.csv",
				"readme.txt"
			],
			"sample_files": [
				{"name": "readme.txt", "ext": "txt", "size": 2048, "date": 20260110},
				{"name": "installer.exe", "ext": "exe", "size": 51200, "date": 20260105},
				{"name": "dataset.csv", "ext": "csv", "size": 14336, "date": 20260120}
			],
			"tokens": ["DIR", "/o-s", "/os", "/on", "/b", "/w"],
			"answer_tokens": ["DIR", "/o-s", "/b"],
			"hint": "/o-s mengurutkan ukuran terbesar -> terkecil (tanda minus membalik urutan), dan /b menampilkan nama saja."
		},
		{
			"id": "mg5_l2",
			"mode": "screen_info",
			"mission": "Layar masih penuh catatan lama! Rakit urutan perintah agar layar dibersihkan dahulu, lalu tampilkan versi Windows dan informasi label volume disk persis seperti TARGET OUTPUT!",
			"target_lines": [
				"Microsoft Windows [Version 10.0.22631]",
				"Volume in drive D is LAB_PPLG",
				"Volume Serial Number is 4A2C-99F1"
			],
			"tokens": ["CLS", "VER", "VOL", "DATE", "TIME", "DIR"],
			"answer_tokens": ["CLS", "VER", "VOL"],
			"hint": "Mulai dengan CLS agar catatan lama hilang, diikuti VER lalu VOL."
		},
		{
			"id": "mg5_l3",
			"mode": "prompt",
			"mission": "Rakit perintah PROMPT dan kode parameternya agar baris pertama mencetak 'LAB_CLI', lalu baris kedua menampilkan path aktif diikuti tanda '>' persis seperti TARGET OUTPUT!",
			"base_path": "D:\\PRAKTIK",
			"target_lines": [
				"LAB_CLI",
				"D:\\PRAKTIK>"
			],
			"tokens": ["PROMPT", "LAB_CLI", "$_", "$P", "$G", "$L", "$T", "$$"],
			"answer_tokens": ["PROMPT", "LAB_CLI", "$_", "$P", "$G"],
			"hint": "Sesuai kode PROMPT: teks 'LAB_CLI', lalu $_ (pindah baris), $P (path aktif), dan $G (tanda '>')."
		},
		{
			"id": "mg5_l4",
			"mode": "batch",
			"mission": "Rakit isi skrip .BAT secara berurutan agar: baris perintah tersembunyi, layar bersih, mencetak 'MODUL AKTIF', menjeda tombol, lalu tampilkan tanggal sistem persis seperti TARGET OUTPUT!",
			"target_lines": [
				"MODUL AKTIF",
				"Press any key to continue . . .",
				"The current date is: Sun 11/22/2026"
			],
			"tokens": ["@ECHO OFF", "CLS", "ECHO MODUL AKTIF", "PAUSE", "DATE", "ECHO ON", "TIME"],
			"answer_tokens": ["@ECHO OFF", "CLS", "ECHO MODUL AKTIF", "PAUSE", "DATE"],
			"hint": "Gunakan @ECHO OFF di awal, CLS, ECHO MODUL AKTIF, PAUSE, lalu DATE."
		}
	]
