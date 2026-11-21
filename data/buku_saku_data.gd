class_name BukuSakuData
extends RefCounted
## Materi teraudit dari presentasi DOS/CMD untuk modul Buku Saku di dalam game.


static func get_sections() -> Array[Dictionary]:
	return [
		{
			"id": "konsep",
			"tab": "1. Konsep DOS",
			"title": "Konsep Dasar & Akses DOS / Command Prompt",
			"summary": "Disk Operating System (DOS) adalah sistem operasi berbasis teks (CLI) yang pertama kali dikembangkan oleh IBM lalu dilanjutkan oleh Microsoft untuk PC.",
			"blocks": [
				{
					"heading": "Cara Membuka di Windows",
					"body": "Tekan tombol Win + R lalu ketik cmd (membuka cmd.exe), atau melalui menu Start -> Windows System / Accessories -> Command Prompt."
				},
				{
					"heading": "5 Fungsi Utama DOS & Console",
					"body": "1) Kendali sistem komputer, 2) Manajemen memori utama, 3) Kontrol Input/Output periferal, 4) File management, 5) Directory management."
				},
				{
					"heading": "Koreksi Penting: DOS vs Windows CMD & Linux",
					"body": "- MS-DOS 16-bit/Win9x memakai interpreter command.com, sedangkan Windows XP hingga Windows 11 memakai cmd.exe.\n- Di Linux berbasis X11, shortcut berpindah ke konsol teks (TTY) adalah Ctrl + Alt + F1 s.d. F6, sedangkan Alt + F7 justru untuk kembali ke tampilan grafis (GUI)."
				}
			]
		},
		{
			"id": "klasifikasi",
			"tab": "2. Internal vs Eksternal",
			"title": "Klasifikasi Perintah Internal & Eksternal",
			"summary": "Perintah DOS dibagi berdasarkan apakah perintah tersebut sudah tertanam di interpreter atau butuh berkas program terpisah.",
			"blocks": [
				{
					"heading": "1. Perintah Internal (Built-in)",
					"body": "Sudah tersedia langsung di dalam interpreter (command.com / cmd.exe) sehingga tidak memerlukan berkas terpisah.\nContoh: DIR, VOL, TYPE, MD, CD, RD, CLS, DATE, TIME, VER, COPY, MOVE, REN, DEL."
				},
				{
					"heading": "2. Perintah Eksternal (.EXE / .COM)",
					"body": "Memerlukan file program terpisah agar bisa dijalankan.\nContoh: TREE, FORMAT, CHKDSK, LABEL (dan pada MS-DOS lama terdapat DELTREE.EXE)."
				},
				{
					"heading": "Koreksi Penting: DELTREE vs RD /S",
					"body": "DELTREE hanya ada sampai MS-DOS 6.22 dan Windows 9x/ME. Pada Windows Command Prompt modern (cmd.exe), perintah penghapus folder beserta seluruh isinya adalah RD /S (atau RMDIR /S)."
				}
			]
		},
		{
			"id": "eksplorasi",
			"tab": "3. DIR & Layar",
			"title": "Perintah Layar & Eksplorasi Direktori (DIR)",
			"summary": "Gunakan perintah layar untuk informasi sistem dan DIR beserta parameternya untuk menyaring serta mengurutkan daftar berkas.",
			"blocks": [
				{
					"heading": "Perintah Layar & Informasi Sistem",
					"body": "CLS (bersihkan layar), DATE (lihat/ubah tanggal sistem), TIME (lihat/ubah jam), VER (cek versi OS), VOL (cek label volume & nomor seri disk)."
				},
				{
					"heading": "Parameter Penting DIR",
					"body": "/p : tampil per halaman (page)\n/w : tampil melebar (wide)\n/a : tampilkan semua file termasuk tersembunyi (/ah atau /a:h)\n/s : tampilkan hingga seluruh sub-direktori\n/b : format ringkas (nama file/folder saja per baris)\n/l : huruf kecil (lowercase)\nCatatan /c: di MS-DOS lama menampilkan rasio kompresi, di Windows cmd.exe modern menampilkan pemisah ribuan ukuran file."
				},
				{
					"heading": "Pengurutan DIR /o (Gunakan '-' untuk Membalik Urutan)",
					"body": "/on : urut nama A-Z  |  /oe : urut ekstensi\n/os : urut ukuran kecil -> besar (pakai /o-s untuk terbesar -> terkecil)\n/od : urut tanggal & waktu"
				}
			]
		},
		{
			"id": "wildcard",
			"tab": "4. Wildcard (* & ?)",
			"title": "Karakter Wildcard (* dan ?)",
			"summary": "Wildcard dipakai bersama DIR, COPY, MOVE, atau DEL untuk memilih banyak file sekaligus berdasarkan pola nama.",
			"blocks": [
				{
					"heading": "Aturan Dua Karakter Wildcard",
					"body": "* (Asterisk): mewakili nol, satu, atau banyak karakter bebas.\n? (Tanda Tanya): mewakili TEPAT 1 karakter pada posisi tersebut."
				},
				{
					"heading": "Contoh Pola & Analisis",
					"body": "- dir *.exe -> semua file berekstensi .exe.\n- dir ?ebek.exe -> cocok untuk bebek.exe, tebek.exe, lebek.exe; TIDAK cocok untuk ebek.exe (kurang 1 huruf depan) atau tebek_lama.exe.\n- copy ??g*.* C:\\latdos -> salin semua file yang huruf ketiganya 'g' (misal tugas.doc, lagu.mp3, log.txt)."
				}
			]
		},
		{
			"id": "berkas",
			"tab": "5. Folder & Berkas",
			"title": "Manajemen Direktori & Manipulasi Berkas",
			"summary": "Mengelola struktur folder dan file menggunakan sintaks path Windows yang memakai backslash (\\).",
			"blocks": [
				{
					"heading": "Navigasi & Struktur Folder",
					"body": "MD / MKDIR [nama] : membuat folder baru\nCD / CHDIR [nama] : masuk ke folder\nCD .. : naik satu tingkat ke folder induk\nTREE : menampilkan bagan hierarki folder"
				},
				{
					"heading": "2 Syarat Mutlak Menghapus Folder dengan RD",
					"body": "1) Posisi prompt harus berada DI LUAR folder yang akan dihapus (jalankan CD .. bila masih di dalam).\n2) Folder target harus benar-benar KOSONG (cek file hidden memakai DIR /a lalu hapus dengan DEL terlebih dahulu)."
				},
				{
					"heading": "Manipulasi Berkas (COPY vs MOVE, REN, TYPE, DEL)",
					"body": "- COPY [asal] [tujuan] : menyalin file tanpa menghapus file asal.\n- MOVE [asal] [tujuan] : memindahkan file/folder ke lokasi baru (jangan tertukar dengan perintah cp/mv di Linux!).\n- REN [lama] [baru] : mengganti nama file tanpa mengubah isinya.\n- TYPE [file.txt] : menampilkan isi file teks murni ke layar.\n- DEL [file] : menghapus berkas."
				}
			]
		},
		{
			"id": "batch",
			"tab": "6. PROMPT & .BAT",
			"title": "Kustomisasi PROMPT & Skrip Batch (.BAT)",
			"summary": "Mengubah tampilan teks prompt terminal dan mengotomatiskan rangkaian perintah DOS dalam file .BAT.",
			"blocks": [
				{
					"heading": "Kode Parameter PROMPT",
					"body": "$p : path aktif  |  $g : karakter >  |  $l : karakter <\n$n : drive aktif  |  $_ : pindah baris (Enter)\n$t : jam aktif  |  $d : tanggal aktif  |  $v : versi OS\n$$ : karakter $  |  $b : karakter |  |  $q : karakter =\nContoh: PROMPT SMK$_$P$G -> mencetak 'SMK' di baris 1 lalu 'D:\\TUGAS>' di baris 2."
				},
				{
					"heading": "Membuat Skrip Batch dengan COPY CON",
					"body": "Ketik: COPY CON LATIHAN.BAT lalu tulis baris perintah:\n@ECHO OFF   (menyembunyikan baris perintah agar tidak ikut tampil)\nCLS         (membersihkan layar)\nECHO HALO   (menampilkan pesan teks; pakai ECHO. untuk baris kosong)\nPAUSE       (menjeda layar sampai tombol ditekan)\nSimpan skrip: tekan Ctrl + Z atau F6 lalu Enter."
				}
			]
		}
	]
