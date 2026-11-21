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
	await _test_ui_interactions_and_states()
	await _test_minigames_gameplay()
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
		"?ebek.exe",
		["bebek.exe", "tebek.exe", "lebek.exe"],
		["bebek.doc", "ketek.exe", "ebek.exe", "tugasku.exe", "tebek_lama.exe"]
	)
	assert_true(bool(eval1.get("perfect", false)), "MG3 L1 ?ebek.exe harus perfect")

	var eval1_bad: Dictionary = WildcardMatcher.evaluate_filter(
		"*ebek.exe",
		["bebek.exe", "tebek.exe", "lebek.exe"],
		["bebek.doc", "ketek.exe", "ebek.exe", "tugasku.exe", "tebek_lama.exe"]
	)
	assert_eq(bool(eval1_bad.get("perfect", true)), false, "MG3 L1 *ebek.exe harus ditolak oleh ebek.exe")

	var eval2: Dictionary = WildcardMatcher.evaluate_filter(
		"*.doc",
		["tugas1.doc", "catatan.doc", "ortuq.doc"],
		["sistem.exe", "readme.txt", "tugas.docx", "foto.jpg"]
	)
	assert_true(bool(eval2.get("perfect", false)), "MG3 L2 *.doc harus perfect")

	var eval3: Dictionary = WildcardMatcher.evaluate_filter(
		"??g*.*",
		["tugas.doc", "lagu.mp3", "log.txt", "sagu.xls"],
		["gambar.png", "agama.pdf", "file.txt", "go.exe"]
	)
	assert_true(bool(eval3.get("perfect", false)), "MG3 L3 ??g*.* harus perfect")

	var eval4: Dictionary = WildcardMatcher.evaluate_filter(
		"laporan_??.txt",
		["laporan_01.txt", "laporan_09.txt", "laporan_12.txt"],
		["laporan_1.txt", "laporan_final.txt", "laporan_01.doc", "rekap_01.txt"]
	)
	assert_true(bool(eval4.get("perfect", false)), "MG3 L4 laporan_??.txt harus perfect")


func _test_catalog_and_buku_saku() -> void:
	assert_eq(GameConfig.class_options, ["PPLG A", "PPLG B"], "Pilihan kelas harus tepat PPLG A dan PPLG B")

	var raw_lb := '{"ok":true,"total_overall":42,"total_pplga":21,"total_pplgb":21,"overall_top10":[{"rank":1,"nama":"Andi","kelas":"PPLG A","poin":98.5}],"pplga_top10":[{"rank":1,"nama":"Andi","kelas":"PPLG A","poin":98.5}],"pplgb_top10":[],"my_info":{"found":true,"overall_rank":3,"overall_total":42,"class_rank":2,"class_total":21,"kelas":"PPLG A","rata_rata":88.5}}'
	var parsed_lb: Dictionary = TelemetryService.parse_leaderboard_json(raw_lb)
	assert_true(bool(parsed_lb.get("ok", false)), "parse_leaderboard_json harus berhasil")
	assert_eq(int(parsed_lb.get("total_overall", 0)), 42, "total_overall harus 42")
	var my_info: Dictionary = parsed_lb.get("my_info", {}) as Dictionary
	assert_eq(int(my_info.get("overall_rank", 0)), 3, "overall_rank pribadi harus 3")

	var sections: Array[Dictionary] = BukuSakuData.get_sections()
	assert_eq(sections.size(), 6, "BukuSaku harus memiliki 6 tab materi")

	var metas: Array[Dictionary] = LevelsCatalog.get_minigames_meta()
	assert_eq(metas.size(), 5, "Harus ada tepat 5 minigame")
	for m: Dictionary in metas:
		var mg_id: String = str(m.get("id", ""))
		var lvs: Array[Dictionary] = LevelsCatalog.get_levels(mg_id)
		assert_eq(lvs.size(), 4, "Minigame %s harus memiliki 4 level" % mg_id)
		for lv: Dictionary in lvs:
			var m_txt: String = str(lv.get("mission", ""))
			assert_true(not m_txt.to_lower().contains("slide"), "Misi %s tidak boleh menyebut nomor slide" % str(lv.get("id", "")))

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
	GameSession.save_path = test_path
	GameSession.start_new_session("Rina Putri", "PPLG B", "12")
	var log_entry: Dictionary = GameSession.record_attempt(
		"mg1", "mg1_l1", "Misi 1", "MOVE Users\\CZ\\Downloads Users\\CZ\\Kokop",
		"MOVE Users\\CZ\\Downloads Users\\CZ\\Kokop", true, 1, 100, 7.2
	)
	assert_eq(int(log_entry.get("poin", 0)), 100, "Poin percobaan pertama benar harus 100")
	assert_eq(int(GameSession.mg_scores.get("mg1", 0)), 25, "Skor modul mg1 setelah 1 dari 4 level")

	var state1: Dictionary = GameSession.capture_state()
	GameSession.record_attempt("mg3", "mg3_l1", "Wildcard", "?ebek.exe", "?ebek.exe", true, 2, 90, 12.0)
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
	assert_true(csv.contains("Rina Putri") and csv.contains("?ebek.exe"), "CSV harus memuat nama & jawaban siswa")

	for p: String in [test_path, test_path + ".bak", test_path + ".tmp"]:
		var gp: String = ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(gp)
	GameSession.clear_session()


func _test_ui_interactions_and_states() -> void:
	# 1. Login screen validation + class toggle + input absen manual
	GameSession.clear_session()
	var login_inst := (load("res://scenes/ui/login_screen.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(login_inst)
	await get_tree().process_frame
	login_inst.call("_on_start_pressed")
	assert_true((login_inst.get("_error_panel") as Control).visible, "Login nama kosong harus memunculkan panel error")
	var nama_ed := login_inst.get("_nama_input") as LineEdit
	var absen_ed := login_inst.get("_absen_input") as LineEdit
	assert_true(absen_ed != null, "Input absen manual (LineEdit) harus tersedia")
	nama_ed.text = "Budi Santoso"
	absen_ed.text = "abc"
	login_inst.call("_on_absen_text_changed", "abc")
	assert_eq(absen_ed.text, "", "Input absen non-digit harus disaring kosong")
	login_inst.call("_on_start_pressed")
	assert_true((login_inst.get("_error_panel") as Control).visible, "Absen kosong harus memunculkan panel error")
	absen_ed.text = "15"
	assert_eq(int(login_inst.call("parse_valid_absen", absen_ed.text)), 15, "Absen manual '15' harus valid")
	login_inst.call("_on_select_kelas", "PPLG B")
	assert_eq(str(login_inst.get("_selected_kelas")), "PPLG B", "Tombol kelas PPLG B harus aktif saat dipilih")
	login_inst.queue_free()
	await get_tree().process_frame

	# 2. Leaderboard modal: uji 4 state (LOADING, NO_URL, ERROR, EMPTY, LOADED) + 3 filter
	GameSession.start_new_session("Budi Santoso", "PPLG A", "7")
	var lb_inst := (load("res://scenes/components/leaderboard_modal.tscn") as PackedScene).instantiate() as Control
	get_tree().root.add_child(lb_inst)
	await get_tree().process_frame
	for st: String in ["LOADING", "NO_URL", "ERROR", "LOADED"]:
		lb_inst.call("_on_leaderboard_updated", st, {}, "Pesan uji " + st)
		assert_true(not (lb_inst.get("_status_lbl") as Label).text.is_empty(), "Leaderboard state %s harus menampilkan status" % st)
	for sc: String in ["overall", "pplga", "pplgb"]:
		lb_inst.call("_on_scope_selected", sc)
		assert_eq(str(lb_inst.get("_active_scope")), sc, "Filter leaderboard %s harus bekerja" % sc)
	lb_inst.queue_free()
	await get_tree().process_frame

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

	# 1. MG1 Command Patch
	var mg1: BaseMinigame = (load("res://scenes/minigames/mg1_command_patch/mg1_command_patch.tscn") as PackedScene).instantiate() as BaseMinigame
	get_tree().root.add_child(mg1)
	await get_tree().process_frame
	mg1.call("_on_choice_pressed", "mv")
	mg1.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "SALAH", "MG1 'mv' harus ditolak")
	mg1.call("_on_choice_pressed", "MOVE")
	mg1.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "BENAR", "MG1 'MOVE' harus benar")
	assert_eq(int(GameSession.attempt_logs.back()["poin"]), 90, "MG1 poin percobaan ke-2 harus 90")
	mg1.queue_free()
	await get_tree().process_frame

	# 2. MG2 Flowchart Builder (cek _flow_scroll mengunci tinggi saat banyak langkah ditambahkan)
	var mg2: BaseMinigame = (load("res://scenes/minigames/mg2_flowchart_builder/mg2_flowchart_builder.tscn") as PackedScene).instantiate() as BaseMinigame
	get_tree().root.add_child(mg2)
	await get_tree().process_frame
	var flow_card_ctrl := mg2.get("_flow_card") as Control
	var flow_sc := mg2.get("_flow_scroll") as ScrollContainer
	assert_true(flow_sc != null and flow_card_ctrl != null, "MG2 harus memiliki ScrollContainer internal pada panel Flowchart")
	var initial_card_h: float = flow_card_ctrl.size.y
	mg2.call("_add_step", "TYPE ok.txt")
	mg2.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "SALAH", "MG2 urutan salah harus ditolak")
	mg2.call("_on_reset_level_pressed")
	for step: String in ["MD cc", "CD cc", "COPY CON ok.txt", "Isi \"bebas\" + [Ctrl+Z]", "TYPE ok.txt"]:
		mg2.call("_add_step", step)
	await get_tree().process_frame
	assert_true(absf(flow_card_ctrl.size.y - initial_card_h) <= 4.0, "Tinggi panel Flowchart MG2 tidak boleh turun-turun saat tambah 5 langkah")
	mg2.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "BENAR", "MG2 urutan benar harus diterima")
	mg2.queue_free()
	await get_tree().process_frame

	# 3. MG3 Wildcard Gate + cek tidak ada text menurun pada placeholder kosong
	var mg3: BaseMinigame = (load("res://scenes/minigames/mg3_wildcard_gate/mg3_wildcard_gate.tscn") as PackedScene).instantiate() as BaseMinigame
	get_tree().root.add_child(mg3)
	await get_tree().process_frame
	await get_tree().process_frame
	var empty_lbl := mg3.get("_empty_pattern_lbl") as Label
	assert_true(empty_lbl != null and empty_lbl.size.x >= 200.0, "MG3 placeholder teks tidak boleh menurun sempit (lebar=%.1f)" % (empty_lbl.size.x if empty_lbl else 0.0))
	for tok: String in ["*", "ebek", ".exe"]:
		mg3.call("_on_token_tap", tok)
	mg3.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "SALAH", "MG3 *ebek.exe harus ditolak")
	mg3.call("_on_reset_level_pressed")
	for tok: String in ["?", "ebek", ".exe"]:
		mg3.call("_on_token_tap", tok)
	mg3.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "BENAR", "MG3 ?ebek.exe harus benar")
	mg3.queue_free()
	await get_tree().process_frame

	# 4. MG4 Tree Sweeper (Syarat RD #1 & Syarat RD #2 dengan DIR /a; error tidak membocorkan jawaban)
	var mg4: BaseMinigame = (load("res://scenes/minigames/mg4_tree_sweeper/mg4_tree_sweeper.tscn") as PackedScene).instantiate() as BaseMinigame
	get_tree().root.add_child(mg4)
	await get_tree().process_frame
	mg4.call("_exec_rd_while_inside")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "SALAH", "MG4 RD dari dalam folder harus gagal (Syarat #1)")
	var fb_rd1: String = (mg4.get("_feedback_label") as Label).text
	assert_true(not fb_rd1.contains("CD .."), "MG4 error syarat #1 tidak boleh langsung membocorkan perintah 'CD ..'")
	mg4.call("_exec_cd_up")
	mg4.call("_exec_rd_child", "sampah")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "BENAR", "MG4 CD .. lalu RD sampah harus berhasil")
	mg4._current_index = 2
	mg4.call("_load_current_level")
	mg4.call("_exec_rd_child", "GNA")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "SALAH", "MG4 RD GNA dengan file hidden harus gagal (Syarat #2)")
	var fb_rd2: String = (mg4.get("_feedback_label") as Label).text
	assert_true(not fb_rd2.contains("DIR /a"), "MG4 error syarat #2 tidak boleh langsung membocorkan perintah 'DIR /a'")
	mg4.call("_exec_cd", "GNA")
	mg4.call("_exec_dir_hidden")
	mg4.call("_exec_del", "rahasia.sys", true)
	mg4.call("_exec_cd_up")
	mg4.call("_exec_rd_child", "GNA")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "BENAR", "MG4 hapus hidden lalu CD .. & RD GNA harus berhasil")
	mg4.queue_free()
	await get_tree().process_frame

	# 5. MG5 CRT Config
	var mg5: BaseMinigame = (load("res://scenes/minigames/mg5_crt_config/mg5_crt_config.tscn") as PackedScene).instantiate() as BaseMinigame
	get_tree().root.add_child(mg5)
	await get_tree().process_frame
	for tok: String in ["DIR", "/o-s", "/b"]:
		mg5.call("_on_token_tap", tok)
	mg5.call("_on_submit_pressed")
	assert_eq(GameSession.attempt_logs.back()["hasil"], "BENAR", "MG5 DIR /o-s /b harus cocok")
	mg5.queue_free()
	await get_tree().process_frame

	GameSession.clear_session()


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
