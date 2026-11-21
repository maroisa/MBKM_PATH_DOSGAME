# DOS Rescue: Media Pembelajaran CLI (Retro Pixel Art 128-bit)

Media pembelajaran interaktif berbasis web untuk materi **Disk Operating System (DOS / Windows Command Prompt)** bergaya **Retro Pixel Art 128-bit** dengan navigasi 3 layar yang ringkas dan nyaman di HP, tablet, maupun desktop (minim keyboard).

## Fitur Utama
- **5 Stage Praktik Interaktif:**
  1. `STAGE 1: Debugger Sintaks` (`CMD_PATCH.EXE`): Perbaiki baris perintah DOS yang rusak atau tertukar sintaks Linux (`MOVE`, `COPY`, `REN`, `RD /S`, `\`).
  2. `STAGE 2: Rakit Flowchart` (`FLOW_BATCH`): Susun urutan langkah kerja flowchart (`MD`, `CD`, `COPY CON`, `Ctrl+Z`, `TYPE`, `.BAT`).
  3. `STAGE 3: Filter Wildcard` (`GATE_LOCK.EXE`): Analisis pola wildcard (`*` dan `?`) untuk menyaring file `[ALLOW]` vs `[DENY]`.
  4. `STAGE 4: Labirin Folder` (`TREE_SWEEPER`): Labirin pohon direktori visual, `DIR /a` untuk berkas tersembunyi, dan 2 syarat mutlak `RD`.
  5. `STAGE 5: Studio Layar & .BAT` (`CRT_CONFIG`): Studio layar *Live Preview* untuk flag `DIR`, informasi sistem (`CLS`, `VER`, `VOL`), `PROMPT`, dan skrip `.BAT`.
- **Navigasi 3 Layar Bebas Duplikasi:**
  - Layar 1 (Title & Login): Form masuk ringkas (`Nama`, `[PPLG A]` / `[PPLG B]`, `Absen`, `[MULAI MAIN]`), banner lanjutkan sesi bila ada, dan 2 tombol cepat `[PERINGKAT]` serta `[MATERI]`.
  - Layar 2 (Peta Stage): 1 top bar ringkas (`[< KELUAR]`, `[PERINGKAT]`, `[MATERI]`, `[RAPOR]`, `[SFX]`), 1 strip info pribadi (`Kamu rank X dari Y Peserta`), dan 5 kartu stage dengan rating bintang.
  - Layar 3 (Minigame): 1 baris HUD tipis di atas agar area puzzle dan blok perintah tetap lega di layar HP.
- **Integrasi Google Sheets Multi-User & Ekspor CSV:**
  - Terhubung ke spreadsheet [Data Game DOS](https://docs.google.com/spreadsheets/d/1_5KTFCkMfApJd6mqU1qBDhrvOMRTULbgtgTqdFUC5lo/edit) dengan 5 tab (`PPLGA`, `PPLGB`, `HasilKeseluruhan`, `LeaderBoard`, `LogJawaban`).
  - Mendukung simpan lokal atomik (`user://` / `IndexedDB` + cadangan `.bak`) dan unduh bukti hasil `.CSV`.

## Cara Menghubungkan Google Apps Script (Wajib Sekali di Spreadsheet)
1. Buka spreadsheet **Data Game DOS** -> klik menu **Extensions -> Apps Script**.
2. Salin seluruh isi [google_apps_script/Code.gs](google_apps_script/Code.gs) ke editor Apps Script, lalu simpan (**Save**).
3. Klik **Deploy -> New deployment -> Web app**:
   - *Execute as:* **Me**
   - *Who has access:* **Anyone**
4. Salin **Web App URL** lalu tempel ke field `"apps_script_url"` di `data/game_config.json`.
5. Export ulang Web Build ke `docs/index.html`.

## Cara Export Web & Deploy GitHub Pages
1. Buka proyek di **Godot 4.7.2+ (Standard GDScript)** dengan Export Templates versi yang sama.
2. Pilih preset **Web** (*Thread Support = OFF*, filter `*.json`), lalu export ke `docs/index.html`.
3. Push ke GitHub dan aktifkan **Settings -> Pages -> Deploy from branch (`main` / `/docs`)**.

## Uji Coba Headless
```bash
godot --headless --path . --import
godot --headless --path . --script .agents/skills/godot-gdscript/assets/check_scripts_compile.gd
godot --headless --path . --script res://tests/test_runner.gd
```
