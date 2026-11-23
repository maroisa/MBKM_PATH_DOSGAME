extends Node
## Suite pengujian fungsional, aset pixel art, interaksi UI, & layout responsif (dijalankan oleh test_runner.gd).

var passed: int = 0
var failed: int = 0


func assert_true(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		push_error("FAIL [%s]" % label)


func assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		passed += 1
	else:
		failed += 1
		push_error("FAIL [%s]: expected %s, got %s" % [label, str(expected), str(actual)])


func run_all_tests() -> int:
	await get_tree().process_frame
	_test_pixel_assets_and_theme()
	_test_wildcard_matcher()
	_test_catalog_and_buku_saku()
	_test_mg5_simulation()
	_test_save_roundtrip_and_csv()
	_test_pretest_posttest_controls()
	await _test_ui_interactions_and_states()
	await _test_minigames_gameplay()
	await _test_touch_scrolling()
	await _test_zoom_controls()
	await _test_responsive_layouts()
	print("RESULTS: %d passed, %d failed" % [passed, failed])
	return failed


func _test_pixel_assets_and_theme() -> void:
	var required_files: Array[String] = [
		"panel_rpg.png",
		"panel_monitor.png",
		"panel_gold.png",
		"btn_gold_normal.png",
		"btn_gold_hover.png",
		"btn_gold_pressed.png",
		"btn_blue_normal.png",
		"btn_blue_hover.png",
		"btn_blue_pressed.png",
		"btn_chip_normal.png",
		"btn_chip_selected.png",
		"btn_focus.png",
		"bg_tile.png",
		"ico_trophy.png",
		"ico_book.png",
		"ico_report.png",
		"ico_sound_on.png",
		"ico_sound_off.png",
		"ico_star_on.png",
		"ico_star_off.png",
		"ico_back.png",
		"ico_play.png",
		"ico_folder.png",
		"ico_lock.png",
		"ico_terminal.png",
	]
	for fname: String in required_files:
		var tex := load("res://assets/pixel_ui/" + fname) as Texture2D
		assert_true(tex != null, "Aset pixel harus dimuat: " + fname)

	var pf := UiTheme.get_pixel_font()
	assert_true(pf != null, "Font pixel_display.fnt harus dimuat")

	var ico2x := UiTheme.get_icon_2x("trophy", 2)
	assert_true(ico2x != null and int(ico2x.get_width()) == 32 and int(ico2x.get_height()) == 32, "Ikon 16x16 harus di-upscale 2x = 32x32")

	var theme_res := UiTheme.create_theme()
	assert_true(theme_res != null, "UiTheme.create_theme harus mengembalikan Theme valid")
	assert_eq(UiTheme.compute_star_count(100, true), 3, "Skor 100 harus 3 bintang")
	assert_eq(UiTheme.compute_star_count(80, true), 2, "Skor 80 harus 2 bintang")
	assert_eq(UiTheme.compute_star_count(50, true), 1, "Skor 50 harus 1 bintang")
	assert_eq(UiTheme.compute_star_count(0, false), 0, "Belum main harus 0 bintang")


func _test_wildcard_matcher() -> void:
	var eval1: Dictionary = WildcardMatcher.evaluate_filter(
		"?ode.exe",
		["kode.exe", "mode.exe", "node.exe"],
		["kode.txt", "data.exe", "ode.exe", "modul.exe", "node_baru.exe"]
	)
	assert_true(bool(eval1.get("perfect", false)), "MG3 L1 ?ode.exe harus perfect")

	var eval1_bad: Dictionary = WildcardMatcher.evaluate_filter(
		"*ode.exe",
		["kode.exe", "mode.exe", "node.exe"],
		["kode.txt", "data.exe", "ode.exe", "modul.exe", "node_baru.exe"]
	)
	assert_eq(bool(eval1_bad.get("perfect", true)), false, "MG3 L1 *ode.exe harus ditolak oleh ode.exe")

	var eval2: Dictionary = WildcardMatcher.evaluate_filter(
		"*.csv",
		["nilai_a.csv", "absen.csv", "rekap.csv"],
		["aplikasi.exe", "panduan.txt", "rekap.csvx", "banner.png"]
	)
	assert_true(bool(eval2.get("perfect", false)), "MG3 L2 *.csv harus perfect")

	var eval3: Dictionary = WildcardMatcher.evaluate_filter(
		"??r*.*",
		["kerja.doc", "surat.pdf", "baris.txt", "kartu.png"],
		["rekap.csv", "arsip.zip", "modul.txt", "er.exe"]
	)
	assert_true(bool(eval3.get("perfect", false)), "MG3 L3 ??r*.* harus perfect")

	var eval4: Dictionary = WildcardMatcher.evaluate_filter(
		"praktik_??.log",
		["praktik_01.log", "praktik_08.log", "praktik_15.log"],
		["praktik_1.log", "praktik_utama.log", "praktik_01.txt", "ujian_01.log"]
	)
	assert_true(bool(eval4.get("perfect", false)), "MG3 L4 praktik_??.log harus perfect")


func _test_catalog_and_buku_saku() -> void:
	assert_eq(GameConfig.class_options, ["PPLG A", "PPLG B"], "Pilihan kelas harus tepat PPLG A dan PPLG B")

	var raw_lb := '{"ok":true,"total_overall":42,"total_pplga":21,"total_pplgb":21,"overall_top10":[{"rank":1,"nama":"Andi","kelas":"PPLG A","poin":98.5}],"pplga_top10":[{"rank":1,"nama":"Andi","kelas":"PPLG A","poin":98.5}],"pplgb_top10":[],"my_info":{"found":true,"overall_rank":3,"overall_total":42,"class_rank":2,"class_total":21,"kelas":"PPLG A","rata_rata":88.5}}'
	var parsed_lb: Dictionary = TelemetryService.parse_leaderboard_json(raw_lb)
	assert_true(bool(parsed_lb.get("ok", false)), "parse_leaderboard_json harus berhasil")
	assert_eq(int(parsed_lb.get("total_overall", 0)), 42, "total_overall harus 42")
	var my_info: Dictionary = parsed_lb.get("my_info", {}) as Dictionary
	assert_eq(int(my_info.get("overall_rank", 0)), 3, "overall_rank pribadi harus 3")

	var banned_words: Array[String] = [
		"kokop", "ortuq", "bebek", "tebek", "lebek", "ketek",
		"terbenci", "tersayang", "sampah", "xrplb", "powpoint", "tugasm~1"
	]
	var sections: Array[Dictionary] = BukuSakuData.get_sections()
	assert_eq(sections.size(), 6, "BukuSaku harus memiliki 6 tab materi")
	var buku_dump: String = JSON.stringify(sections).to_lower()
	for bw: String in banned_words:
		assert_true(not buku_dump.contains(bw), "BukuSaku tidak boleh memuat kata lama '%s'" % bw)

	var metas: Array[Dictionary] = LevelsCatalog.get_minigames_meta()
	assert_eq(metas.size(), 5, "Harus ada tepat 5 minigame")
	for m: Dictionary in metas:
		var mg_id: String = str(m.get("id", ""))
		var lvs: Array[Dictionary] = LevelsCatalog.get_levels(mg_id)
		assert_eq(lvs.size(), 4, "Minigame %s harus memiliki 4 level" % mg_id)
		var lvs_dump: String = JSON.stringify(lvs).to_lower()
		for bw: String in banned_words:
			assert_true(not lvs_dump.contains(bw), "Soal %s tidak boleh memuat kata lama '%s'" % [mg_id, bw])
		for lv: Dictionary in lvs:
			var m_txt: String = str(lv.get("mission", ""))
			assert_true(not m_txt.to_lower().contains("slide"), "Misi %s tidak boleh menyebut nomor slide" % str(lv.get("id", "")))

	# Uji pengacakan pilihan sejati (multiset sama, menghasilkan banyak variasi urutan, menghindari prefix jawaban)
	var sample_opts: Array = ["MOVE", "COPY", "DIR", "mv", "DEL"]
	var unique_orders: Dictionary = {}
	for _i: int in range(18):
		var sh: Array[String] = LevelsCatalog.shuffled_choices(sample_opts, ["MOVE"])
		assert_eq(sh.size(), sample_opts.size(), "Jumlah elemen setelah diacak harus tetap sama")
		for orig_item: Variant in sample_opts:
			assert_true(sh.has(str(orig_item)), "Semua pilihan harus tetap ada setelah diacak")
		unique_orders["|".join(sh)] = true
	assert_true(unique_orders.size() >= 3, "Pengacakan pilihan harus menghasilkan variasi urutan acak (got %d)" % unique_orders.size())

	# Uji penilaian tanpa batas waktu (timer dihapus: jawaban benar selalu 100 poin)
	assert_eq(GameConfig.min_score_on_solve, 10, "Skor minimal harus 10 poin")
	assert_eq(int(GameConfig.level_time_limit_sec), 0, "Timer batas waktu harus nonaktif (0)")
	var sc_fast: Dictionary = BaseMinigame.compute_level_score(6.0, 0, 10, 10, 0.0, 0.0)
	assert_eq(int(sc_fast["poin"]), 100, "Jawaban benar tanpa salah harus dapat 100 poin")
	assert_eq(int(sc_fast["time_penalty"]), 0, "Tidak ada penalti waktu saat timer nonaktif")
	var sc_long: Dictionary = BaseMinigame.compute_level_score(120.0, 0, 10, 10, 0.0, 0.0)
	assert_eq(int(sc_long["poin"]), 100, "Durasi lama tetap dapat 100 poin saat timer dihapus")
	assert_eq(bool(sc_long["is_overtime"]), false, "Overtime harus false saat timer dihapus")
	var sc_mistake_floor: Dictionary = BaseMinigame.compute_level_score(10.0, 15, 10, 10, 0.0, 0.0)
	assert_eq(int(sc_mistake_floor["poin"]), 10, "Batas skor minimal saat salah berulang tetap 10 poin")

	# Uji seluruh metode SFX AudioManager aman dipanggil
	AudioManager.play_click()
	AudioManager.play_block_place()
	AudioManager.play_block_remove()
	AudioManager.play_pin_toggle(true)
	AudioManager.play_pin_toggle(false)
	AudioManager.play_folder_move()
	AudioManager.play_scan_reveal()
	AudioManager.play_delete_file()
	AudioManager.play_timer_tick(false)
	AudioManager.play_timer_tick(true)
	AudioManager.play_timeout_warn()
	AudioManager.play_star_pop(0)
	AudioManager.play_modal_open()
	AudioManager.play_modal_close()
	AudioManager.play_success()
	AudioManager.play_error()
	AudioManager.play_stage_clear()

	# Uji validasi URL spreadsheet vs Apps Script Web App
	var old_url: String = GameConfig.apps_script_url
	GameConfig.apps_script_url = "https://docs.google.com/spreadsheets/d/1_5KTFCk/edit?usp=sharing"
	assert_true(GameConfig.is_spreadsheet_edit_url(), "Link spreadsheets/edit harus terdeteksi sebagai bukan URL Apps Script")
	assert_eq(GameConfig.has_valid_apps_script_url(), false, "Link spreadsheets/edit tidak valid untuk HTTP POST")
	GameConfig.apps_script_url = "https://script.google.com/macros/s/AKfycb_test/exec"
	assert_true(GameConfig.has_valid_apps_script_url(), "Link script.google.com/.../exec harus valid")
	GameSession.start_new_session("Kairi", "PPLG A", "26")
	GameSession.record_attempt("mg1", "mg1_l1", "Misi 1", "MOVE", "MOVE", true, 1, 100, 4.0)
	assert_eq(GameSession.synced_log_count, 0, "Saat offline/before enqueue, synced_log_count awal adalah 0")
	TelemetryService.enqueue_unsent_attempt_logs()
	assert_eq(GameSession.synced_log_count, 1, "enqueue_unsent_attempt_logs harus menandai attempt lokal untuk auto-kirim")
	assert_eq(GameSession.pending_telemetry.size(), 1, "Attempt lokal harus masuk antrean pending_telemetry saat URL valid")

	# Uji coalesce event summary & pencegahan duplikat antrean (anti-tumpang-tindih)
	TelemetryService._enqueue_payload(GameSession.build_session_summary_payload("SESSION_START"))
	TelemetryService._enqueue_payload(GameSession.build_session_summary_payload("SESSION_SYNC"))
	TelemetryService._enqueue_payload(GameSession.build_session_summary_payload("SESSION_FINISH"))
	var summary_cnt: int = 0
	var last_summary_ev: String = ""
	for q_item: Dictionary in GameSession.pending_telemetry:
		var qev: String = str(q_item.get("event", ""))
		if qev in TelemetryService.SUMMARY_EVENTS:
			summary_cnt += 1
			last_summary_ev = qev
	assert_eq(summary_cnt, 1, "Event ringkasan sesi tidak boleh menumpuk di antrean")
	assert_eq(last_summary_ev, "SESSION_FINISH", "SESSION_FINISH harus dipertahankan sebagai prioritas ringkasan")
	GameSession.clear_session()
	GameConfig.apps_script_url = old_url


func _test_mg5_simulation() -> void:
	var mg5_script := load("res://scenes/minigames/mg5_crt_config/mg5_crt_config.gd") as Script
	assert_true(mg5_script != null, "mg5_crt_config.gd harus dimuat")
	if mg5_script == null:
		return
	for lv: Dictionary in LevelsCatalog.get_levels("mg5"):
		var ans: Array[String] = []
		for t: Variant in lv.get("answer_tokens", []) as Array:
			ans.append(str(t))
		var live: PackedStringArray = mg5_script.call("simulate_crt_output", lv, ans)
		var expected := PackedStringArray()
		for ln: Variant in lv.get("target_lines", []) as Array:
			var s_ln: String = str(ln)
			assert_true(not s_ln.contains("DIR /o-s"), "MG5 target_lines tidak boleh membocorkan input perintah")
			expected.append(s_ln)
		assert_eq(live, expected, "MG5 simulasi %s harus cocok dengan target_lines" % str(lv.get("id", "")))


func _test_save_roundtrip_and_csv() -> void:
	var test_path: String = "user://test_dos_save.json"
	var test_profiles: String = "user://test_dos_profiles.json"
	var orig_save_path: String = GameSession.save_path
	var orig_profiles_path: String = GameSession.profiles_path
	GameSession.save_path = test_path
	GameSession.profiles_path = test_profiles
	GameSession.start_new_session("Rina Putri", "PPLG B", "12")
	var log_entry: Dictionary = GameSession.record_attempt(
		"mg1", "mg1_l1", "Misi 1", "MOVE D:\\Kerja\\Arsip D:\\Backup",
		"MOVE D:\\Kerja\\Arsip D:\\Backup", true, 1, 100, 7.2
	)
	assert_eq(int(log_entry.get("poin", 0)), 100, "Poin percobaan pertama benar harus 100")
	assert_eq(int(GameSession.mg_scores.get("mg1", 0)), 25, "Skor modul mg1 setelah 1 dari 4 level")

	var state1: Dictionary = GameSession.capture_state()
	GameSession.record_attempt("mg3", "mg3_l1", "Wildcard", "?ode.exe", "?ode.exe", true, 2, 90, 12.0)
	var f: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
	assert_true(f != null, "Harus dapat menulis file uji untuk simulasi corrupt")
	if f != null:
		f.store_string("{\"version\": 1, \"corrupt")
		f.close()
	var loaded: Dictionary = GameSession.load_atomic(test_path)
	assert_true(not loaded.is_empty(), "load_atomic harus fallback ke .bak ketika primary rusak")
	assert_eq(str(loaded.get("nama", "")), state1.get("nama", ""), "Nama dari .bak harus cocok")

	var csv: String = TelemetryService.build_csv_report()
	assert_true(csv.contains("REKAP_SISWA") and csv.contains("LOG_JAWABAN_DETAIL"), "CSV harus memuat 2 bagian utama")
	assert_true(csv.contains("Rina Putri") and csv.contains("?ode.exe"), "CSV harus memuat nama & jawaban siswa")

	for p: String in [test_path, test_path + ".bak", test_path + ".tmp", test_profiles, test_profiles + ".bak", test_profiles + ".tmp"]:
		var gp: String = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(gp)
	GameSession.save_path = orig_save_path
	GameSession.profiles_path = orig_profiles_path
	GameSession.clear_session(true)


func _test_pretest_posttest_controls() -> void:
	# Simpan nilai default
	var orig_mode: String = GameConfig.active_test_mode
	var orig_rev_pre: bool = GameConfig.reveal_pretest_results
	var orig_rev_post: bool = GameConfig.reveal_posttest_results
	var orig_mat_pre: bool = GameConfig.allow_materi_pretest
	var orig_mat_post: bool = GameConfig.allow_materi_posttest

	assert_eq(GameConfig.active_test_mode, "PRETEST", "Mode default awal harus PRETEST")
	assert_eq(GameConfig.exam_blind_mode, true, "Mode ujian blind harus aktif (true)")
	assert_eq(GameConfig.is_results_revealed_for("PRETEST"), false, "Hasil PRETEST default harus disembunyikan sampai di-spill Admin")
	assert_eq(GameConfig.is_results_revealed_for("POSTTEST"), false, "Hasil POSTTEST default harus disembunyikan sampai di-spill Admin")

	# Simulasi Admin ubah konfigurasi lewat Dashboard Admin
	GameConfig.apply_remote_exam_config({
		"active_mode": "POSTTEST",
		"reveal_pretest_results": true,
		"reveal_posttest_results": false,
		"allow_materi_pretest": false,
		"allow_materi_posttest": true,
	})
	assert_eq(GameConfig.active_test_mode, "POSTTEST", "Mode harus berpindah ke POSTTEST")
	assert_eq(GameConfig.get_mode_label(), "POST-TEST", "Label mode harus POST-TEST")
	assert_eq(GameConfig.is_results_revealed_for("PRETEST"), true, "Hasil PRETEST harus terbuka setelah Admin aktifkan Spill")
	assert_eq(GameConfig.is_results_revealed_for("POSTTEST"), false, "Hasil POSTTEST harus tetap tersembunyi")
	assert_eq(GameConfig.is_materi_allowed_for("PRETEST"), false, "Materi PRETEST harus tetap terkunci")
	assert_eq(GameConfig.is_materi_allowed_for("POSTTEST"), true, "Materi POSTTEST harus terbuka sesuai konfigurasi Admin")

	# Verifikasi payload sesi & log membawa test_mode = POSTTEST
	GameSession.start_new_session("Peserta Uji", "PPLG A", "10", "POSTTEST")
	var sum_payload: Dictionary = GameSession.build_session_summary_payload("SESSION_START")
	assert_eq(str(sum_payload.get("test_mode", "")), "POSTTEST", "Ringkasan sesi harus menyertakan test_mode POSTTEST")
	var entry_zero: Dictionary = GameSession.record_attempt("mg1", "mg1_l1", "Misi 1", "SALAH", "MOVE", false, 1, 0, 5.0)
	assert_eq(str(entry_zero.get("test_mode", "")), "POSTTEST", "Log jawaban harus membawa test_mode POSTTEST")
	assert_true(GameSession.level_answered.has("mg1_l1"), "Level yang dijawab salah (0 poin) pada mode blind tetap terkunci sebagai sudah dijawab")
	assert_eq(int(GameSession.mg_levels_done.get("mg1", 0)), 1, "Progres level selesai harus bertambah meski jawaban salah di mode blind")
	assert_eq(int(GameSession.mg_scores.get("mg1", 0)), 0, "Skor level yang salah harus 0")

	# Verifikasi parser leaderboard menjaga flag revealed=false dari server
	var raw_hidden_lb := '{"ok":true,"mode":"PRETEST","revealed":false,"config":{"active_mode":"PRETEST","reveal_pretest_results":false},"total_overall":12,"overall_top10":[],"pplga_top10":[],"pplgb_top10":[],"my_info":{"found":true,"revealed":false}}'
	var parsed_hid: Dictionary = TelemetryService.parse_leaderboard_json(raw_hidden_lb)
	assert_true(bool(parsed_hid.get("has_revealed_flag", false)), "Parser leaderboard harus membaca keberadaan flag revealed")
	assert_eq(bool(parsed_hid.get("revealed", true)), false, "Parser leaderboard harus menjaga revealed=false")

	# Kembalikan konfigurasi default
	GameSession.clear_session()
	GameConfig.apply_remote_exam_config({
		"active_mode": orig_mode,
		"reveal_pretest_results": orig_rev_pre,
		"reveal_posttest_results": orig_rev_post,
		"allow_materi_pretest": orig_mat_pre,
		"allow_materi_posttest": orig_mat_post,
	})


func _test_ui_interactions_and_states() -> void:
	# 1. Login screen: PPLG A dropdown 36 siswa (dari JSON roster), validasi 1x Spreadsheet, & fallback manual PPLG B
	GameSession.clear_session(true)
	var pplga_roster: Array[Dictionary] = GameConfig.get_students_for_class("PPLG A")
	assert_eq(pplga_roster.size(), 36, "Roster JSON PPLG A harus memuat tepat 36 siswa")
	if pplga_roster.size() == 36:
		assert_eq(str(pplga_roster[0]["nama"]), "AISYA KIEANA FADILLA", "Siswa absen 1 PPLG A harus AISYA KIEANA FADILLA")
		assert_eq(int(pplga_roster[0]["absen"]), 1, "Absen pertama PPLG A harus 1")
		assert_eq(str(pplga_roster[35]["nama"]), "YOVAN BISMA PRATAMA AZHAR", "Siswa absen 36 PPLG A harus YOVAN BISMA PRATAMA AZHAR")
		assert_eq(int(pplga_roster[35]["absen"]), 36, "Absen ke-36 PPLG A harus 36")

	# Uji parser validasi siswa Spreadsheet (format Code.gs baru & fallback legacy my_info.found)
	var chk_used: Dictionary = TelemetryService.parse_student_check_json('{"ok":true,"exists":true,"allowed":false,"message":"Nama sudah dipakai"}', "ARYA MUSTOFA", "4")
	assert_eq(bool(chk_used.get("exists", false)), true, "Parser harus mendeteksi siswa sudah ada di Spreadsheet")
	assert_eq(bool(chk_used.get("allowed", true)), false, "Siswa yang sudah ada harus ditolak (allowed=false)")
	var chk_free: Dictionary = TelemetryService.parse_student_check_json('{"ok":true,"exists":false,"allowed":true}', "ARYA MUSTOFA", "4")
	assert_eq(bool(chk_free.get("allowed", false)), true, "Siswa yang belum ada di Spreadsheet harus diizinkan")
	var chk_legacy: Dictionary = TelemetryService.parse_student_check_json('{"ok":true,"my_info":{"found":true}}', "ARYA MUSTOFA", "4")
	assert_eq(bool(chk_legacy.get("exists", false)), true, "Fallback legacy my_info.found=true harus mendeteksi nama sudah dipakai")

	var login_inst := (load("res://scenes/ui/login_screen.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(login_inst)
	await get_tree().process_frame
	var dd_sec := login_inst.get("_dropdown_section") as Control
	var man_sec := login_inst.get("_manual_section") as Control
	var nama_ed := login_inst.get("_nama_input") as LineEdit
	var absen_ed := login_inst.get("_absen_input") as LineEdit
	assert_true(dd_sec.visible and not man_sec.visible, "PPLG A harus menampilkan dropdown roster siswa")
	assert_true(get_tree().root.gui_get_focus_owner() != nama_ed, "Input nama tidak boleh langsung auto-fokus saat layar masuk dibuka")
	login_inst.call("_on_start_pressed")
	assert_true((login_inst.get("_error_panel") as Control).visible, "Belum memilih siswa di dropdown PPLG A harus memunculkan error")

	# Buka dropdown, pastikan scroll wheel sampai mentok bawah TIDAK menutup dropdown, filter pencarian, dan pilih absen 4
	login_inst.call("_open_student_dropdown")
	await get_tree().process_frame
	assert_true((login_inst.get("_dropdown_backdrop") as Control).visible, "Overlay dropdown siswa harus tampil saat dibuka")
	var wheel_dn := InputEventMouseButton.new()
	wheel_dn.pressed = true
	wheel_dn.button_index = MOUSE_BUTTON_WHEEL_DOWN
	login_inst.call("_on_dropdown_backdrop_gui_input", wheel_dn)
	assert_true((login_inst.get("_dropdown_backdrop") as Control).visible, "Scroll wheel ke bawah sampai mentok tidak boleh menutup dropdown siswa")
	login_inst.call("_populate_dropdown_items", "ARYA")
	assert_eq((login_inst.get("_dropdown_list_vbox") as Node).get_child_count(), 1, "Pencarian 'ARYA' harus menyaring tepat 1 siswa")
	assert_true(bool(login_inst.call("select_student_by_absen", 4)), "select_student_by_absen(4) harus berhasil memilih ARYA MUSTOFA")
	assert_true((login_inst.get("_student_dropdown_btn") as Button).text.contains("ARYA MUSTOFA"), "Tombol dropdown harus menampilkan nama siswa terpilih")
	login_inst.call("_close_student_dropdown")

	# Simulasikan balasan Spreadsheet: nama sudah dipakai (tanpa sesi lokal) -> harus memunculkan notif error & tetap di login
	login_inst.call("_on_student_check_completed", false, true, "Nama \"ARYA MUSTOFA\" (Absen 4) sudah dipakai di Spreadsheet.", {"nama": "ARYA MUSTOFA", "kelas": "PPLG A", "absen": "4", "mode": "PRETEST"})
	assert_true((login_inst.get("_error_panel") as Control).visible, "Nama sudah dipakai (tanpa sesi lokal) harus memunculkan panel notifikasi error")
	assert_true((login_inst.get("_error_lbl") as Label).text.to_lower().contains("sudah dipakai"), "Notifikasi harus menyebutkan nama sudah dipakai")

	# Uji tanpa banner 'LANJUTKAN PRE-TEST' + auto-resume saat siswa dengan sesi tersimpan memilih namanya sendiri
	GameSession.start_new_session("ARYA MUSTOFA", "PPLG A", "4", "PRETEST")
	GameSession.record_attempt("mg1", "mg1_l1", "Misi 1", "MOVE", "MOVE", true, 1, 100, 3.0)
	var saved_sid: String = GameSession.session_id
	GameSession.clear_session(false) # Simulasi keluar/ganti siswa tapi profil lokal tetap tersimpan
	assert_true(GameSession.has_saved_session_for("PPLG A", "ARYA MUSTOFA", "4", "PRETEST"), "Profil lokal ARYA MUSTOFA harus tersimpan untuk auto-resume")
	assert_true(GameSession.resume_saved_session_for("PPLG A", "ARYA MUSTOFA", "PRETEST"), "resume_saved_session_for harus memulihkan sesi ARYA MUSTOFA")
	assert_eq(GameSession.session_id, saved_sid, "Auto-resume harus menjaga session_id & progres sebelumnya tanpa reset")
	assert_true(GameSession.level_answered.has("mg1_l1"), "Auto-resume harus mempertahankan soal yang sudah terjawab")
	login_inst.call("_update_dropdown_trigger_display")
	assert_eq((login_inst.get("_start_btn") as Button).text, "LANJUTKAN MAIN", "Tombol CTA harus otomatis berubah menjadi LANJUTKAN MAIN saat siswa punya sesi lokal")
	for btn_n: Node in login_inst.find_children("*", "Button", true, false):
		assert_true(not (btn_n as Button).text.begins_with("LANJUTKAN PRE-TEST"), "Banner tombol LANJUTKAN PRE-TEST harus sudah dihapus dari login_screen")
	GameSession.clear_session(true)

	# Uji pindah ke PPLG B -> mode manual fallback + validasi absen
	login_inst.call("_on_select_kelas", "PPLG B")
	assert_eq(str(login_inst.get("_selected_kelas")), "PPLG B", "Tombol kelas PPLG B harus aktif saat dipilih")
	assert_true(man_sec.visible and not dd_sec.visible, "PPLG B (roster kosong) harus menampilkan input manual")
	login_inst.call("_on_start_pressed")
	assert_true((login_inst.get("_error_panel") as Control).visible, "Login nama kosong PPLG B harus memunculkan panel error")
	assert_true(absen_ed != null, "Input absen manual (LineEdit) harus tersedia")
	nama_ed.text = "Budi Santoso"
	absen_ed.text = "abc"
	login_inst.call("_on_absen_text_changed", "abc")
	assert_eq(absen_ed.text, "", "Input absen non-digit harus disaring kosong")
	login_inst.call("_on_start_pressed")
	assert_true((login_inst.get("_error_panel") as Control).visible, "Absen kosong harus memunculkan panel error")
	absen_ed.text = "15"
	assert_eq(int(login_inst.call("parse_valid_absen", absen_ed.text)), 15, "Absen manual '15' harus valid")
	for btn_node: Node in login_inst.find_children("*", "Button", true, false):
		assert_true((btn_node as Button).text != "Ketik HP", "Tombol 'Ketik HP' harus sudah dihapus dari login_screen")
	login_inst.queue_free()
	await get_tree().process_frame

	# 2. Leaderboard modal & Final Report: uji kondisi TERKUNCI (belum di-spill) lalu TERBUKA (setelah di-spill Admin)
	GameConfig.apply_remote_exam_config({"active_mode": "PRETEST", "reveal_pretest_results": false})
	GameSession.start_new_session("Budi Santoso", "PPLG A", "7", "PRETEST")
	GameSession.record_attempt("mg1", "mg1_l1", "Misi 1", "MOVE", "MOVE", true, 1, 100, 4.0)
	var sample_lb_a: Dictionary = {
		"ok": true,
		"mode": "PRETEST",
		"has_revealed_flag": true,
		"revealed": true,
		"total_overall": 42,
		"total_pplga": 21,
		"total_pplgb": 21,
		"overall_top10": [{"rank": 1, "nama": "Andi", "kelas": "PPLG A", "poin": 98.5}],
		"pplga_top10": [{"rank": 1, "nama": "Andi", "kelas": "PPLG A", "poin": 98.5}],
		"pplgb_top10": [{"rank": 1, "nama": "Siti", "kelas": "PPLG B", "poin": 95.0}],
		"my_info": {
			"found": true,
			"overall_rank": 5,
			"overall_total": 42,
			"class_rank": 2,
			"class_total": 21,
			"kelas": "PPLG A",
			"rata_rata": 88.5,
		}
	}
	var lb_inst := (load("res://scenes/components/leaderboard_modal.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(lb_inst)
	await get_tree().process_frame
	# Sebelum di-spill: peringkat & skor HARUS terkunci
	lb_inst.call("_on_leaderboard_updated", "LOADED", sample_lb_a, "Terkunci")
	assert_true((lb_inst.get("_personal_rank_lbl") as Label).text.contains("BELUM DIBUKA"), "Leaderboard Pre-Test harus terkunci sebelum Admin Spill")
	assert_true(not (lb_inst.get("_scope_flow") as Control).visible, "Tab scope Leaderboard harus tersembunyi sebelum di-spill")

	# Uji FinalReport sebelum di-spill: nilai TERKUNCI & tombol UNDUH CSV tersembunyi
	var rep_locked := (load("res://scenes/ui/final_report.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(rep_locked)
	await get_tree().process_frame
	assert_eq((rep_locked.get("_avg_score_lbl") as Label).text, "TERKUNCI", "FinalReport Pre-Test harus mengunci skor rata-rata sebelum di-spill")
	assert_eq((rep_locked.get("_csv_btn") as Control).visible, false, "Tombol UNDUH CSV harus tersembunyi sebelum hasil di-spill")
	rep_locked.queue_free()
	await get_tree().process_frame

	# Simulasi Admin menekan tombol SPILL hasil Pre-Test -> Leaderboard & Rapor langsung terbuka
	GameConfig.apply_remote_exam_config({"reveal_pretest_results": true})
	await get_tree().process_frame
	var scope_btns_a: Dictionary = lb_inst.get("_scope_buttons") as Dictionary
	assert_true(scope_btns_a.has("overall") and scope_btns_a.has("pplga"), "Siswa PPLG A harus punya tab Keseluruhan & PPLG A")
	assert_true(not scope_btns_a.has("pplgb"), "Siswa PPLG A tidak boleh melihat tab leaderboard PPLG B")
	for st: String in ["LOADING", "NO_URL", "ERROR", "LOADED"]:
		lb_inst.call("_on_leaderboard_updated", st, sample_lb_a, "Pesan uji " + st)
		assert_true(not (lb_inst.get("_status_lbl") as Label).text.is_empty(), "Leaderboard state %s harus menampilkan status" % st)
	lb_inst.call("_on_scope_selected", "overall")
	assert_eq(str(lb_inst.get("_active_scope")), "overall", "Filter overall harus bekerja")
	assert_true((lb_inst.get("_personal_rank_lbl") as Label).text.contains("rank 5 dari 42"), "Tab Keseluruhan harus menampilkan overall_rank (5 dari 42)")
	lb_inst.call("_on_scope_selected", "pplga")
	assert_eq(str(lb_inst.get("_active_scope")), "pplga", "Filter pplga harus bekerja untuk siswa PPLG A")
	assert_true((lb_inst.get("_personal_rank_lbl") as Label).text.contains("rank 2 dari 21"), "Tab PPLG A harus menampilkan class_rank (2 dari 21)")
	lb_inst.call("_on_scope_selected", "pplgb")
	assert_eq(str(lb_inst.get("_active_scope")), "pplga", "Siswa PPLG A tidak boleh berpindah ke scope pplgb")
	lb_inst.queue_free()
	await get_tree().process_frame

	# Uji FinalReport sesudah di-spill: skor & UNDUH CSV muncul
	var rep_open := (load("res://scenes/ui/final_report.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(rep_open)
	await get_tree().process_frame
	assert_true((rep_open.get("_avg_score_lbl") as Label).text != "TERKUNCI", "FinalReport harus menampilkan nilai setelah di-spill Admin")
	assert_eq((rep_open.get("_csv_btn") as Control).visible, true, "Tombol UNDUH CSV harus tampil setelah hasil di-spill")
	rep_open.queue_free()
	await get_tree().process_frame

	# Uji siswa PPLG B hanya mendapat tab Keseluruhan & PPLG B
	GameSession.start_new_session("Siti Rahma", "PPLG B", "9", "PRETEST")
	var lb_b := (load("res://scenes/components/leaderboard_modal.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(lb_b)
	await get_tree().process_frame
	var scope_btns_b: Dictionary = lb_b.get("_scope_buttons") as Dictionary
	assert_true(scope_btns_b.has("overall") and scope_btns_b.has("pplgb"), "Siswa PPLG B harus punya tab Keseluruhan & PPLG B")
	assert_true(not scope_btns_b.has("pplga"), "Siswa PPLG B tidak boleh melihat tab leaderboard PPLG A")
	lb_b.queue_free()
	await get_tree().process_frame
	GameConfig.apply_remote_exam_config({"reveal_pretest_results": false})

	# 3. Buku Saku modal: uji perpindahan semua 6 tab
	var bs_inst := (load("res://scenes/components/buku_saku_modal.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(bs_inst)
	await get_tree().process_frame
	for sec: Dictionary in BukuSakuData.get_sections():
		var sid: String = str(sec.get("id", ""))
		bs_inst.call("select_tab_by_id", sid)
		assert_eq((bs_inst.get("_title_lbl") as Label).text, str(sec.get("title", "")), "Buku Saku tab %s harus aktif" % sid)
	bs_inst.queue_free()
	await get_tree().process_frame

	GameSession.clear_session()


func _test_minigames_gameplay() -> void:
	GameSession.start_new_session("Uji Gameplay", "PPLG A", "1")

	# 1. MG1 Command Patch (slot jawaban harus kosong di awal, tanpa ULANG, output di atas input sticky)
	var play_vp := SubViewport.new()
	play_vp.size = Vector2i(1280, 720)
	get_tree().root.add_child(play_vp)
	var mg1: BaseMinigame = (load("res://scenes/minigames/mg1_command_patch/mg1_command_patch.tscn") as PackedScene).instantiate() as BaseMinigame
	play_vp.add_child(mg1)
	await get_tree().process_frame
	await get_tree().process_frame
	for btn_node: Node in mg1.find_children("*", "Button", true, false):
		var b_txt: String = (btn_node as Button).text
		assert_true(b_txt != "PETUNJUK", "Tombol PETUNJUK (hint) harus sudah dihapus dari minigame")
		assert_true(b_txt != "ULANG", "Tombol ULANG harus sudah dihapus dari minigame")
	var mg1_out := mg1.get("_output_root") as Control
	var mg1_in := mg1.get("_input_root") as Control
	assert_true(mg1_out.get_global_rect().position.y < mg1_in.get_global_rect().position.y, "MG1 Output harus berada di atas Input")
	assert_eq(mg1.is_input_pinned(), true, "Input MG1 harus langsung sticky secara otomatis")
	assert_true((mg1.get("_pinned_input_panel") as Control).visible, "Dock input sticky harus langsung tampil di atas footer")
	assert_eq((mg1.get("_pin_input_btn") as Control).visible, false, "Tombol manual SEMATKAN INPUT tidak perlu tampil karena input sudah selalu sticky")
	var mg1_hud := mg1.get("_hud") as HudBar
	assert_eq((mg1_hud.get("_timer_lbl") as Control).visible, false, "Timer waktu di HUD harus disembunyikan")
	var slot_btns: Dictionary = mg1.get("_slot_buttons") as Dictionary
	assert_true(slot_btns.has(0), "MG1 harus memiliki tombol slot 0")
	if slot_btns.has(0):
		assert_eq((slot_btns[0] as Button).text, "", "Slot jawaban awal MG1 harus kosong tanpa placeholder")
	var logs_before_empty: int = GameSession.attempt_logs.size()
	mg1.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.size(), logs_before_empty, "Submit slot kosong MG1 tidak boleh mencatat kesalahan")
	# Mode blind single-shot: jawaban salah langsung dicatat SALAH (0 poin) & maju tanpa bocor feedback benar/salah
	mg1.call("_on_choice_pressed", "mv")
	mg1.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "SALAH", "MG1 'mv' harus dinilai SALAH di sistem")
	assert_eq(int(GameSession.attempt_logs.back()["poin"]), 0, "MG1 jawaban salah harus dapat 0 poin")
	assert_eq(bool(mg1.get("_level_solved")), true, "Mode blind: setelah kirim jawaban (meski salah), soal langsung terkunci & lanjut")
	var fb_mg1: String = (mg1.get("_feedback_label") as Label).text
	assert_true(not fb_mg1.contains("[ERR]") and not fb_mg1.contains("Poin:"), "Feedback mode blind tidak boleh membocorkan status salah atau poin")
	# Lanjut ke level 2 dan jawab benar
	mg1.call("_advance_level")
	await get_tree().process_frame
	var mg1_l2: Dictionary = LevelsCatalog.get_levels("mg1")[1]
	for tok_v: Variant in mg1_l2.get("tokens", []) as Array:
		var tk := tok_v as Dictionary
		if bool(tk.get("editable", false)):
			mg1.call("_on_choice_pressed", str(tk.get("answer", "")))
	mg1.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "BENAR", "MG1 L2 jawaban benar harus dinilai BENAR")
	assert_eq(int(GameSession.attempt_logs.back()["poin"]), 100, "MG1 L2 poin jawaban benar cepat harus 100")
	mg1.queue_free()
	await get_tree().process_frame

	# Pastikan membuka ulang MG1 langsung loncat ke Level 3 (tidak bisa ulang Level 1 yang salah/0 poin)
	var mg1_reopen: BaseMinigame = (load("res://scenes/minigames/mg1_command_patch/mg1_command_patch.tscn") as PackedScene).instantiate() as BaseMinigame
	get_tree().root.add_child(mg1_reopen)
	await get_tree().process_frame
	assert_eq(int(mg1_reopen.get("_current_index")), 2, "Buka ulang MG1 harus lanjut ke level 3 dan mengunci level 1 (0 poin) & level 2")
	mg1_reopen.queue_free()
	await get_tree().process_frame

	# 2. MG2 Flowchart Builder (cek _flow_scroll mengunci tinggi saat banyak langkah ditambahkan + mode blind)
	var mg2: BaseMinigame = (load("res://scenes/minigames/mg2_flowchart_builder/mg2_flowchart_builder.tscn") as PackedScene).instantiate() as BaseMinigame
	get_tree().root.add_child(mg2)
	await get_tree().process_frame
	var flow_card_ctrl := mg2.get("_flow_card") as Control
	var flow_sc := mg2.get("_flow_scroll") as ScrollContainer
	assert_true(flow_sc != null and flow_card_ctrl != null, "MG2 harus memiliki ScrollContainer internal pada panel Flowchart")
	var initial_card_h: float = flow_card_ctrl.size.y
	mg2.call("_add_step", "TYPE catatan.txt")
	mg2.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "SALAH", "MG2 urutan salah harus dicatat SALAH")
	assert_eq(bool(mg2.get("_level_solved")), true, "MG2 mode blind harus langsung mengunci soal setelah kirim")
	mg2.call("_advance_level")
	await get_tree().process_frame
	var mg2_l2_ans: Array = LevelsCatalog.get_levels("mg2")[1].get("answer_sequence", []) as Array
	for step_v: Variant in mg2_l2_ans:
		mg2.call("_add_step", str(step_v))
	await get_tree().process_frame
	assert_true(absf(flow_card_ctrl.size.y - initial_card_h) <= 4.0, "Tinggi panel Flowchart MG2 tidak boleh turun-turun saat tambah langkah")
	mg2.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "BENAR", "MG2 L2 urutan benar harus dinilai BENAR")
	mg2.queue_free()
	await get_tree().process_frame

	# 3. MG3 Wildcard Gate (no text wrap bug + no live [COCOK]/[BOCOR] leak di mode blind)
	var mg3: BaseMinigame = (load("res://scenes/minigames/mg3_wildcard_gate/mg3_wildcard_gate.tscn") as PackedScene).instantiate() as BaseMinigame
	get_tree().root.add_child(mg3)
	await get_tree().process_frame
	await get_tree().process_frame
	var empty_lbl := mg3.get("_empty_pattern_lbl") as Label
	assert_true(empty_lbl != null and empty_lbl.size.x >= 200.0, "MG3 placeholder teks tidak boleh menurun sempit (lebar=%.1f)" % (empty_lbl.size.x if empty_lbl else 0.0))
	for tok: String in ["*", "ode", ".exe"]:
		mg3.call("_on_token_tap", tok)
	for lbl_node: Node in (mg3.get("_allow_vbox") as Node).find_children("*", "Label", true, false):
		var lt: String = (lbl_node as Label).text
		assert_true(lt != "[COCOK]" and lt != "[LEWAT]", "MG3 mode blind tidak boleh membocorkan status live [COCOK]/[LEWAT]")
	mg3.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "SALAH", "MG3 *ode.exe harus dinilai SALAH")
	mg3.call("_advance_level")
	await get_tree().process_frame
	for tok: String in ["*", ".csv"]:
		mg3.call("_on_token_tap", tok)
	mg3.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "BENAR", "MG3 L2 *.csv harus dinilai BENAR")
	mg3.queue_free()
	await get_tree().process_frame

	# 4. MG4 Tree Sweeper (Output di atas Input sticky + mode blind navigasi lalu tekan KIRIM JAWABAN)
	var mg4: BaseMinigame = (load("res://scenes/minigames/mg4_tree_sweeper/mg4_tree_sweeper.tscn") as PackedScene).instantiate() as BaseMinigame
	play_vp.add_child(mg4)
	await get_tree().process_frame
	await get_tree().process_frame
	var mg4_out := mg4.get("_output_root") as Control
	var mg4_in := mg4.get("_input_root") as Control
	assert_true(mg4_out.get_global_rect().position.y < mg4_in.get_global_rect().position.y, "MG4 Output (tree + log) harus berada di atas Input (tombol perintah)")
	mg4.call("_exec_rd_while_inside")
	assert_eq(bool(mg4.get("_level_solved")), false, "MG4 mode blind: RD di dalam folder tidak langsung mengunci level sebelum tekan KIRIM JAWABAN")
	mg4.call("_exec_cd_up")
	mg4.call("_exec_rd_child", "temp")
	mg4.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "BENAR", "MG4 CD .. lalu RD temp + KIRIM JAWABAN harus dinilai BENAR")
	mg4._current_index = 2
	mg4.call("_load_current_level")
	mg4.call("_exec_rd_child", "uji_coba")
	mg4.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "SALAH", "MG4 kirim sebelum folder target terhapus harus dinilai SALAH")
	assert_eq(int(GameSession.attempt_logs.back()["poin"]), 0, "MG4 kirim jawaban gagal harus dapat 0 poin")
	mg4.queue_free()
	play_vp.queue_free()
	await get_tree().process_frame

	# 5. MG5 CRT Config (mode blind menyembunyikan badge [COCOK]/[BELUM COCOK])
	var mg5: BaseMinigame = (load("res://scenes/minigames/mg5_crt_config/mg5_crt_config.tscn") as PackedScene).instantiate() as BaseMinigame
	get_tree().root.add_child(mg5)
	await get_tree().process_frame
	assert_eq((mg5.get("_match_lbl") as Control).visible, false, "MG5 mode blind harus menyembunyikan indikator [COCOK]/[BELUM COCOK]")
	for tok: String in ["DIR", "/o-s", "/b"]:
		mg5.call("_on_token_tap", tok)
	mg5.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "BENAR", "MG5 DIR /o-s /b harus dinilai BENAR")
	mg5.call("_advance_level")
	await get_tree().process_frame
	mg5.call("_on_token_tap", "DIR")
	mg5.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "SALAH", "MG5 L2 jawaban tidak lengkap harus dinilai SALAH")
	mg5.queue_free()
	await get_tree().process_frame

	# 6. Verifikasi Sticky Input otomatis: saat scroll turun di layar HP, panel input sticky tidak ikut bergeser
	var pin_vp := SubViewport.new()
	pin_vp.size = Vector2i(390, 640)
	get_tree().root.add_child(pin_vp)
	var mg3_pin: BaseMinigame = (load("res://scenes/minigames/mg3_wildcard_gate/mg3_wildcard_gate.tscn") as PackedScene).instantiate() as BaseMinigame
	pin_vp.add_child(mg3_pin)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(mg3_pin.is_input_pinned(), "Input MG3 harus langsung sticky tanpa klik tombol")
	var pin_panel := mg3_pin.get("_pinned_input_panel") as Control
	var mg3_scroll := mg3_pin.get("_scroll") as ScrollContainer
	var y_before_scroll: float = pin_panel.get_global_rect().position.y
	mg3_scroll.scroll_vertical = 120
	await get_tree().process_frame
	var y_after_scroll: float = pin_panel.get_global_rect().position.y
	assert_true(absf(y_after_scroll - y_before_scroll) <= 1.0, "Panel input sticky tidak boleh ikut bergeser saat halaman discroll (before=%.1f, after=%.1f)" % [y_before_scroll, y_after_scroll])
	assert_true(pin_panel.get_global_rect().end.y <= float(pin_vp.size.y) + 2.0, "Panel input sticky harus tetap di dalam batas layar HP")
	pin_vp.queue_free()
	await get_tree().process_frame

	# 7. Verifikasi MainHub tidak memiliki fitur ULANG saat stage selesai (tombol jadi SELESAI & nonaktif)
	GameSession.mark_minigame_finished("mg1")
	var hub_chk := (load("res://scenes/ui/main_hub.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(hub_chk)
	await get_tree().process_frame
	var found_selesai_disabled: bool = false
	for b_node: Node in hub_chk.find_children("*", "Button", true, false):
		var btn := b_node as Button
		assert_true(btn.text != "ULANG", "MainHub tidak boleh menampilkan tombol ULANG untuk stage yang sudah selesai")
		if btn.text == "SELESAI" and btn.disabled:
			found_selesai_disabled = true
	assert_true(found_selesai_disabled, "Stage yang sudah selesai di MainHub harus menampilkan tombol SELESAI (nonaktif)")
	hub_chk.queue_free()
	await get_tree().process_frame

	GameSession.clear_session()


func _test_touch_scrolling() -> void:
	GameSession.start_new_session("Uji Scroll HP", "PPLG A", "5")
	var vp := SubViewport.new()
	vp.size = Vector2i(390, 640)
	get_tree().root.add_child(vp)

	# 1. Uji scroll dari tengah layar di Stage 2 (di atas panel Flowchart kosong yang punya nested TouchScrollContainer)
	var mg2 := (load("res://scenes/minigames/mg2_flowchart_builder/mg2_flowchart_builder.tscn") as PackedScene).instantiate() as BaseMinigame
	vp.add_child(mg2)
	await get_tree().process_frame
	await get_tree().process_frame

	var outer_scroll := mg2.get("_scroll") as TouchScrollContainer
	var flow_scroll := mg2.get("_flow_scroll") as TouchScrollContainer
	assert_true(outer_scroll != null and flow_scroll != null, "Stage 2 harus memakai TouchScrollContainer untuk outer & inner scroll")
	assert_eq(outer_scroll.scroll_vertical, 0, "Scroll awal Stage 2 harus 0")

	var mid_pt: Vector2 = outer_scroll.get_global_rect().get_center()
	var t_down := InputEventScreenTouch.new()
	t_down.index = 0
	t_down.pressed = true
	t_down.position = mid_pt
	vp.push_input(t_down)

	var t_drag := InputEventScreenDrag.new()
	t_drag.index = 0
	t_drag.position = mid_pt + Vector2(0.0, -140.0)
	t_drag.relative = Vector2(0.0, -140.0)
	vp.push_input(t_drag)

	var t_up := InputEventScreenTouch.new()
	t_up.index = 0
	t_up.pressed = false
	t_up.position = mid_pt + Vector2(0.0, -140.0)
	vp.push_input(t_up)
	await get_tree().process_frame

	assert_true(outer_scroll.scroll_vertical > 50, "Swipe dari tengah layar Stage 2 harus menggeser halaman ke bawah (got %d)" % outer_scroll.scroll_vertical)

	# 2. Uji swipe ke bawah (mengembalikan scroll ke atas) dari tengah layar
	var before_up: int = outer_scroll.scroll_vertical
	var t_down2 := InputEventScreenTouch.new()
	t_down2.index = 0
	t_down2.pressed = true
	t_down2.position = mid_pt
	vp.push_input(t_down2)

	var t_drag2 := InputEventScreenDrag.new()
	t_drag2.index = 0
	t_drag2.position = mid_pt + Vector2(0.0, 140.0)
	t_drag2.relative = Vector2(0.0, 140.0)
	vp.push_input(t_drag2)

	var t_up2 := InputEventScreenTouch.new()
	t_up2.index = 0
	t_up2.pressed = false
	t_up2.position = mid_pt + Vector2(0.0, 140.0)
	vp.push_input(t_up2)
	await get_tree().process_frame

	assert_true(outer_scroll.scroll_vertical < before_up, "Swipe turun dari tengah layar Stage 2 harus menggeser kembali ke atas")

	mg2.queue_free()
	await get_tree().process_frame

	# 3. Uji scroll dari tengah layar di Main Hub (di atas kartu stage PanelContainer)
	var hub := (load("res://scenes/ui/main_hub.tscn") as PackedScene).instantiate() as Control
	vp.add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var hub_scroll: TouchScrollContainer = null
	for n: Node in hub.find_children("*", "TouchScrollContainer", true, false):
		hub_scroll = n as TouchScrollContainer
		break
	assert_true(hub_scroll != null, "Main Hub harus memakai TouchScrollContainer")
	if hub_scroll != null:
		var hub_mid: Vector2 = hub_scroll.get_global_rect().get_center()
		var h_down := InputEventScreenTouch.new()
		h_down.index = 0
		h_down.pressed = true
		h_down.position = hub_mid
		vp.push_input(h_down)

		var h_drag := InputEventScreenDrag.new()
		h_drag.index = 0
		h_drag.position = hub_mid + Vector2(0.0, -160.0)
		h_drag.relative = Vector2(0.0, -160.0)
		vp.push_input(h_drag)

		var h_up := InputEventScreenTouch.new()
		h_up.index = 0
		h_up.pressed = false
		h_up.position = hub_mid + Vector2(0.0, -160.0)
		vp.push_input(h_up)
		await get_tree().process_frame
		assert_true(hub_scroll.scroll_vertical > 50, "Swipe dari tengah layar Main Hub harus menggeser daftar stage (got %d)" % hub_scroll.scroll_vertical)

	hub.queue_free()
	await get_tree().process_frame

	# 4. Uji form login naik otomatis saat keyboard HP muncul (tidak tertutup keyboard, uji di PPLG B mode manual)
	vp.size = Vector2i(390, 740)
	var login_kb := (load("res://scenes/ui/login_screen.tscn") as PackedScene).instantiate() as Control
	vp.add_child(login_kb)
	await get_tree().process_frame
	login_kb.call("_on_select_kelas", "PPLG B")
	await get_tree().process_frame
	await get_tree().process_frame

	var absen_ctrl := login_kb.get("_absen_input") as LineEdit
	var login_scroll := login_kb.get("_scroll") as TouchScrollContainer
	var kb_spacer := login_kb.get("_kb_spacer") as Control
	assert_true(absen_ctrl != null and login_scroll != null and kb_spacer != null, "Login screen harus punya _absen_input, _scroll, dan _kb_spacer")
	if absen_ctrl != null and login_scroll != null and kb_spacer != null:
		absen_ctrl.grab_focus()
		login_kb.call("_mark_user_editing", absen_ctrl)
		await get_tree().process_frame
		var simulated_kb_h: float = 340.0
		login_kb.call("apply_keyboard_avoidance", simulated_kb_h)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(kb_spacer.custom_minimum_size.y >= simulated_kb_h, "Spacer keyboard harus membesar minimal setinggi keyboard HP")
		assert_true(absen_ctrl.get_global_rect().end.y <= float(vp.size.y) - simulated_kb_h + 2.0, "Input Nomor Absen harus naik di atas area keyboard HP (end_y=%.1f, limit=%.1f)" % [absen_ctrl.get_global_rect().end.y, float(vp.size.y) - simulated_kb_h])
		login_kb.call("apply_keyboard_avoidance", 0.0)
		await get_tree().process_frame
		assert_eq(kb_spacer.custom_minimum_size.y, 0.0, "Spacer keyboard harus kembali 0 saat keyboard ditutup")

	vp.queue_free()
	await get_tree().process_frame
	GameSession.clear_session()


func _test_zoom_controls() -> void:
	SceneRouter.reset_zoom(false)
	assert_eq(SceneRouter.get_user_zoom(), 1.0, "Zoom awal harus 1.0 (100%)")

	# 1. Keyboard Desktop: Ctrl + / Ctrl - / Ctrl 0
	var ev_plus := InputEventKey.new()
	ev_plus.pressed = true
	ev_plus.ctrl_pressed = true
	ev_plus.keycode = KEY_EQUAL
	SceneRouter._input(ev_plus)
	assert_true(absf(SceneRouter.get_user_zoom() - 1.1) < 0.02, "Ctrl + harus memperbesar zoom ke 110%% (got %.2f)" % SceneRouter.get_user_zoom())

	var ev_minus := InputEventKey.new()
	ev_minus.pressed = true
	ev_minus.ctrl_pressed = true
	ev_minus.keycode = KEY_MINUS
	SceneRouter._input(ev_minus)
	SceneRouter._input(ev_minus)
	assert_true(absf(SceneRouter.get_user_zoom() - 0.9) < 0.02, "Ctrl - 2x harus memperkecil zoom ke 90%% (got %.2f)" % SceneRouter.get_user_zoom())

	var ev_zero := InputEventKey.new()
	ev_zero.pressed = true
	ev_zero.ctrl_pressed = true
	ev_zero.keycode = KEY_0
	SceneRouter._input(ev_zero)
	assert_eq(SceneRouter.get_user_zoom(), 1.0, "Ctrl 0 harus mereset zoom ke 100%")

	# 2. Mouse Wheel Desktop: Ctrl + Wheel Up / Down
	var ev_wu := InputEventMouseButton.new()
	ev_wu.pressed = true
	ev_wu.ctrl_pressed = true
	ev_wu.button_index = MOUSE_BUTTON_WHEEL_UP
	ev_wu.factor = 1.0
	SceneRouter._input(ev_wu)
	assert_true(absf(SceneRouter.get_user_zoom() - 1.1) < 0.02, "Ctrl + Scroll Up harus zoom in (got %.2f)" % SceneRouter.get_user_zoom())

	var ev_wd := InputEventMouseButton.new()
	ev_wd.pressed = true
	ev_wd.ctrl_pressed = true
	ev_wd.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev_wd.factor = 1.0
	SceneRouter._input(ev_wd)
	assert_true(absf(SceneRouter.get_user_zoom() - 1.0) < 0.02, "Ctrl + Scroll Down harus zoom out kembali ke 100%% (got %.2f)" % SceneRouter.get_user_zoom())

	# 3. Trackpad Magnify Gesture + batas clamp [0.50, 2.00]
	var ev_mag := InputEventMagnifyGesture.new()
	ev_mag.factor = 1.25
	SceneRouter._input(ev_mag)
	assert_true(absf(SceneRouter.get_user_zoom() - 1.25) < 0.02, "Trackpad magnify 1.25x harus mengubah zoom ke 125%")
	SceneRouter.set_user_zoom(5.0, false)
	assert_eq(SceneRouter.get_user_zoom(), SceneRouter.ZOOM_MAX, "Zoom tidak boleh melebihi batas maksimum")
	SceneRouter.set_user_zoom(0.1, false)
	assert_eq(SceneRouter.get_user_zoom(), SceneRouter.ZOOM_MIN, "Zoom tidak boleh kurang dari batas minimum")
	SceneRouter.reset_zoom(false)

	# 4. Pinch-to-zoom 2 jari (HP) + pastikan TouchScrollContainer tidak ikut scroll saat mencubit
	var t0_down := InputEventScreenTouch.new()
	t0_down.index = 0
	t0_down.pressed = true
	t0_down.position = Vector2(150.0, 300.0)
	SceneRouter._input(t0_down)

	var t1_down := InputEventScreenTouch.new()
	t1_down.index = 1
	t1_down.pressed = true
	t1_down.position = Vector2(250.0, 300.0)
	SceneRouter._input(t1_down)
	assert_true(SceneRouter.is_pinch_zooming(), "Dua jari menyentuh layar harus mengaktifkan mode pinch zoom")

	var t1_spread := InputEventScreenDrag.new()
	t1_spread.index = 1
	t1_spread.position = Vector2(300.0, 300.0)
	SceneRouter._input(t1_spread)
	assert_true(absf(SceneRouter.get_user_zoom() - 1.5) < 0.03, "Pinch out (jarak 100 -> 150) harus zoom ke 150%% (got %.2f)" % SceneRouter.get_user_zoom())

	var t1_up := InputEventScreenTouch.new()
	t1_up.index = 1
	t1_up.pressed = false
	t1_up.position = Vector2(300.0, 300.0)
	SceneRouter._input(t1_up)

	var t0_up := InputEventScreenTouch.new()
	t0_up.index = 0
	t0_up.pressed = false
	t0_up.position = Vector2(150.0, 300.0)
	SceneRouter._input(t0_up)
	SceneRouter.reset_zoom(false)
	await get_tree().process_frame


func _test_responsive_layouts() -> void:
	GameSession.start_new_session("Muhammad Rizky Ramadhan", "PPLG A", "14")
	var sizes: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(800, 1000),
		Vector2i(390, 844),
	]
	var scene_paths: Array[String] = [
		"res://scenes/ui/login_screen.tscn",
		"res://scenes/ui/main_hub.tscn",
		"res://scenes/ui/final_report.tscn",
		"res://scenes/components/buku_saku_modal.tscn",
		"res://scenes/components/leaderboard_modal.tscn",
		"res://scenes/minigames/mg1_command_patch/mg1_command_patch.tscn",
		"res://scenes/minigames/mg2_flowchart_builder/mg2_flowchart_builder.tscn",
		"res://scenes/minigames/mg3_wildcard_gate/mg3_wildcard_gate.tscn",
		"res://scenes/minigames/mg4_tree_sweeper/mg4_tree_sweeper.tscn",
		"res://scenes/minigames/mg5_crt_config/mg5_crt_config.tscn",
	]

	for s_path: String in scene_paths:
		var packed := load(s_path) as PackedScene
		assert_true(packed != null, "Scene harus berhasil dimuat: " + s_path)
		if packed == null:
			continue
		for sz: Vector2i in sizes:
			var vp := SubViewport.new()
			vp.size = sz
			get_tree().root.add_child(vp)
			var inst := packed.instantiate() as Control
			vp.add_child(inst)
			await get_tree().process_frame
			await get_tree().process_frame

			var screen := Rect2(Vector2.ZERO, Vector2(sz))
			assert_true(vp.gui_get_focus_owner() != null, "Focus owner harus ada di %s @ %s" % [s_path, str(sz)])

			for node: Node in inst.find_children("*", "Control", true, false):
				var c := node as Control
				if not c.is_visible_in_tree():
					continue
				if c is Button:
					var b := c as Button
					assert_true(b.get_global_rect().size.y >= 47.0, "Tap target tinggi >= 48px di %s (%s) @ %s: %.1f" % [b.text, s_path, str(sz), b.get_global_rect().size.y])
				if c is ScrollContainer:
					assert_true(c.get_global_rect().size.x <= screen.size.x + 2.0, "ScrollContainer lebar aman %s @ %s" % [s_path, str(sz)])
					continue
				if _is_inside_scroll(c):
					assert_true(c.get_global_rect().end.x <= screen.size.x + 4.0, "No horizontal overflow %s (%s) @ %s (end_x=%.1f)" % [inst.get_path_to(c), s_path, str(sz), c.get_global_rect().end.x])
					continue
				assert_true(screen.encloses(c.get_global_rect().grow(-1.0)), "Control %s dalam batas layar di %s @ %s (%s)" % [inst.get_path_to(c), s_path, str(sz), str(c.get_global_rect())])

			vp.queue_free()
			await get_tree().process_frame
	GameSession.clear_session()


static func _is_inside_scroll(node: Node) -> bool:
	var p: Node = node.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false
