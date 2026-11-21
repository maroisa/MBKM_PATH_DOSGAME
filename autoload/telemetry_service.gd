extends Node
## Layanan auto-sinkronisasi hasil siswa ke Google Sheets, fetch Leaderboard Top 10, & ekspor CSV.

signal sync_status_changed(status_code: String, message: String)
signal leaderboard_updated(status: String, data: Dictionary, message: String)

enum SyncState { NO_URL, INVALID_URL, IDLE, SENDING, SYNCED, OFFLINE_QUEUED }

var current_state: SyncState = SyncState.IDLE
var last_message: String = ""
var cached_leaderboard: Dictionary = {}
var _is_sending: bool = false
var _active_request: HTTPRequest = null
var _lb_request: HTTPRequest = null
var _cfg_request: HTTPRequest = null
var _retry_timer: Timer = null


func _ready() -> void:
	GameConfig.config_reloaded.connect(_on_config_reloaded)
	_setup_auto_retry_timer()
	_refresh_initial_state()
	if OS.has_feature("web"):
		_fetch_web_runtime_config()
	elif GameConfig.has_valid_apps_script_url() and not GameSession.pending_telemetry.is_empty():
		flush_pending_queue()


func _setup_auto_retry_timer() -> void:
	_retry_timer = Timer.new()
	_retry_timer.wait_time = 15.0
	_retry_timer.one_shot = false
	_retry_timer.autostart = true
	_retry_timer.timeout.connect(_on_auto_retry_timeout)
	add_child(_retry_timer)


func _on_auto_retry_timeout() -> void:
	if GameConfig.has_valid_apps_script_url() and not _is_sending and not GameSession.pending_telemetry.is_empty():
		flush_pending_queue()


func _fetch_web_runtime_config() -> void:
	# Memungkinkan guru mengganti apps_script_url di docs/game_config.json tanpa perlu export ulang Godot!
	if _cfg_request != null and is_instance_valid(_cfg_request):
		_cfg_request.queue_free()
	_cfg_request = HTTPRequest.new()
	_cfg_request.timeout = 6.0
	add_child(_cfg_request)
	_cfg_request.request_completed.connect(_on_web_config_loaded, CONNECT_ONE_SHOT)
	var base_url: Variant = JavaScriptBridge.eval("window.location.href.split('?')[0].split('#')[0].replace(/[^\\/]*$/, '') + 'game_config.json?v=' + Date.now();")
	if base_url != null and not str(base_url).is_empty():
		_cfg_request.request(str(base_url), PackedStringArray(), HTTPClient.METHOD_GET)


func _on_web_config_loaded(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if _cfg_request != null and is_instance_valid(_cfg_request):
		_cfg_request.queue_free()
		_cfg_request = null
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var text: String = body.get_string_from_utf8()
		if not text.is_empty():
			GameConfig.apply_config_json(text)


func _on_config_reloaded() -> void:
	_refresh_initial_state()
	if GameConfig.has_valid_apps_script_url():
		enqueue_unsent_attempt_logs()
		if GameSession.has_active_session():
			var summary_payload: Dictionary = GameSession.build_session_summary_payload("SESSION_SYNC")
			GameSession.pending_telemetry.append(summary_payload)
			GameSession.save_to_disk()
		if not GameSession.pending_telemetry.is_empty():
			flush_pending_queue()
		fetch_leaderboard()


func _refresh_initial_state() -> void:
	if GameConfig.is_spreadsheet_edit_url():
		current_state = SyncState.INVALID_URL
		last_message = "URL di game_config.json masih link Spreadsheet (docs.google.com). Ganti dengan URL Web App Apps Script (https://script.google.com/macros/s/.../exec)."
	elif not GameConfig.has_valid_apps_script_url():
		current_state = SyncState.NO_URL
		last_message = "Mode Lokal: isi URL Web App Apps Script (script.google.com/.../exec) di game_config.json agar auto-kirim ke Sheets aktif."
	elif not GameSession.pending_telemetry.is_empty():
		current_state = SyncState.OFFLINE_QUEUED
		last_message = "Auto-sync: %d data menunggu dikirim ke Google Sheets." % GameSession.pending_telemetry.size()
	else:
		current_state = SyncState.IDLE
		last_message = "Auto-sync aktif ke Google Sheets (Data Game DOS)."
	sync_status_changed.emit(_state_name(), last_message)


func get_status_label() -> String:
	if GameConfig.is_spreadsheet_edit_url():
		return "URL salah: pakai URL Web App Apps Script (/exec), bukan link Spreadsheet"
	if not GameConfig.has_valid_apps_script_url():
		return "Mode Lokal (URL Web App Apps Script belum dipasang)"
	match current_state:
		SyncState.SENDING:
			return "Auto-mengirim ke Google Sheets..."
		SyncState.SYNCED:
			return "Otomatis tersimpan ke Google Sheets"
		SyncState.OFFLINE_QUEUED:
			return "Antrean Auto-Sync (%d tertunda)" % GameSession.pending_telemetry.size()
		_:
			return "Auto-sync aktif ke Google Sheets"


func send_session_start() -> void:
	var payload: Dictionary = GameSession.build_session_summary_payload("SESSION_START")
	enqueue_and_send(payload)


func send_level_log(entry: Dictionary) -> void:
	var payload: Dictionary = _build_level_log_payload(entry)
	if GameConfig.has_valid_apps_script_url():
		GameSession.synced_log_count = GameSession.attempt_logs.size()
	enqueue_and_send(payload)


func send_session_finish() -> void:
	enqueue_unsent_attempt_logs()
	var payload: Dictionary = GameSession.build_session_summary_payload("SESSION_FINISH")
	enqueue_and_send(payload)


func _build_level_log_payload(entry: Dictionary) -> Dictionary:
	var payload: Dictionary = entry.duplicate(true)
	payload["event"] = "LEVEL_LOG"
	var summary: Dictionary = GameSession.build_session_summary_payload("LEVEL_LOG")
	payload["skor_mg1"] = summary["skor_mg1"]
	payload["skor_mg2"] = summary["skor_mg2"]
	payload["skor_mg3"] = summary["skor_mg3"]
	payload["skor_mg4"] = summary["skor_mg4"]
	payload["skor_mg5"] = summary["skor_mg5"]
	return payload


func enqueue_unsent_attempt_logs() -> void:
	if not GameConfig.has_valid_apps_script_url() or not GameSession.has_active_session():
		return
	var total: int = GameSession.attempt_logs.size()
	if GameSession.synced_log_count >= total:
		return
	for i: int in range(GameSession.synced_log_count, total):
		GameSession.pending_telemetry.append(_build_level_log_payload(GameSession.attempt_logs[i]))
	GameSession.synced_log_count = total
	GameSession.save_to_disk()


func enqueue_and_send(payload: Dictionary) -> void:
	if not GameConfig.has_valid_apps_script_url():
		_refresh_initial_state()
		return
	GameSession.pending_telemetry.append(payload)
	GameSession.save_to_disk()
	flush_pending_queue()


func flush_pending_queue() -> void:
	if not GameConfig.has_valid_apps_script_url():
		_refresh_initial_state()
		return
	if _is_sending or GameSession.pending_telemetry.is_empty():
		return
	_send_next_in_queue()


func _send_next_in_queue() -> void:
	if GameSession.pending_telemetry.is_empty():
		_is_sending = false
		current_state = SyncState.SYNCED
		last_message = "Otomatis tersimpan ke Google Sheets (PPLGA/PPLGB & LogJawaban)."
		sync_status_changed.emit(_state_name(), last_message)
		fetch_leaderboard()
		return

	_is_sending = true
	current_state = SyncState.SENDING
	last_message = "Auto-mengirim %d antrean data ke Sheets..." % GameSession.pending_telemetry.size()
	sync_status_changed.emit(_state_name(), last_message)

	var next_payload: Dictionary = GameSession.pending_telemetry[0]
	var body: String = JSON.stringify(next_payload)
	var headers := PackedStringArray(["Content-Type: text/plain;charset=utf-8"])

	if _active_request != null and is_instance_valid(_active_request):
		_active_request.queue_free()
	_active_request = HTTPRequest.new()
	_active_request.timeout = 12.0
	add_child(_active_request)
	_active_request.request_completed.connect(_on_request_completed, CONNECT_ONE_SHOT)

	var err: Error = _active_request.request(GameConfig.apps_script_url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_handle_send_failure("Gagal memulai permintaan HTTP (kode %d)." % err)


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if _active_request != null and is_instance_valid(_active_request):
		_active_request.queue_free()
		_active_request = null

	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 400:
		var text: String = body.get_string_from_utf8()
		var ok: bool = true
		if not text.is_empty():
			var json := JSON.new()
			if json.parse(text) == OK and json.data is Dictionary:
				ok = bool((json.data as Dictionary).get("ok", true))
		if ok:
			if not GameSession.pending_telemetry.is_empty():
				GameSession.pending_telemetry.remove_at(0)
				GameSession.save_to_disk()
			_send_next_in_queue()
			return

	_handle_send_failure("Gagal kirim (HTTP %d, hasil %d). Akan dicoba ulang otomatis." % [response_code, result])


func _handle_send_failure(reason: String) -> void:
	_is_sending = false
	if _active_request != null and is_instance_valid(_active_request):
		_active_request.queue_free()
		_active_request = null
	current_state = SyncState.OFFLINE_QUEUED
	last_message = reason
	sync_status_changed.emit(_state_name(), last_message)


func fetch_leaderboard() -> void:
	if GameConfig.is_spreadsheet_edit_url():
		var local_bad: Dictionary = build_local_leaderboard_fallback()
		cached_leaderboard = local_bad
		leaderboard_updated.emit(
			"NO_URL",
			local_bad,
			"URL di game_config.json masih link Spreadsheet, bukan URL Web App Apps Script (https://script.google.com/macros/s/.../exec)."
		)
		return
	if not GameConfig.has_valid_apps_script_url():
		var local_data: Dictionary = build_local_leaderboard_fallback()
		cached_leaderboard = local_data
		leaderboard_updated.emit("NO_URL", local_data, "URL Web App Apps Script belum dipasang di game_config.json. Hanya menampilkan data lokal sesi Anda.")
		return

	leaderboard_updated.emit("LOADING", cached_leaderboard, "Mengambil papan peringkat terbaru dari Google Sheets...")
	var sep: String = "&" if GameConfig.apps_script_url.contains("?") else "?"
	var url: String = "%s%saction=leaderboard&nama=%s&kelas=%s&absen=%s" % [
		GameConfig.apps_script_url,
		sep,
		GameSession.nama.uri_encode(),
		GameSession.kelas.uri_encode(),
		GameSession.absen.uri_encode()
	]

	if _lb_request != null and is_instance_valid(_lb_request):
		_lb_request.queue_free()
	_lb_request = HTTPRequest.new()
	_lb_request.timeout = 12.0
	add_child(_lb_request)
	_lb_request.request_completed.connect(_on_leaderboard_completed, CONNECT_ONE_SHOT)

	var err: Error = _lb_request.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		leaderboard_updated.emit("ERROR", cached_leaderboard, "Gagal menghubungi server Leaderboard (kode %d)." % err)


func _on_leaderboard_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if _lb_request != null and is_instance_valid(_lb_request):
		_lb_request.queue_free()
		_lb_request = null

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 400:
		leaderboard_updated.emit("ERROR", cached_leaderboard, "Gagal memuat Leaderboard (HTTP %d). Periksa koneksi internet." % response_code)
		return

	var text: String = body.get_string_from_utf8()
	var parsed: Dictionary = parse_leaderboard_json(text)
	if parsed.is_empty():
		leaderboard_updated.emit("ERROR", cached_leaderboard, "Format balasan Leaderboard tidak valid. Pastikan URL mengarah ke Apps Script Web App (/exec).")
		return

	cached_leaderboard = parsed
	leaderboard_updated.emit("LOADED", parsed, "Diperbarui otomatis dari Google Sheets.")


static func parse_leaderboard_json(raw_json: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(raw_json) != OK or not (json.data is Dictionary):
		return {}
	var d := json.data as Dictionary
	if not bool(d.get("ok", false)):
		return {}
	return {
		"ok": true,
		"updated_at": str(d.get("updated_at", "")),
		"total_overall": int(d.get("total_overall", 0)),
		"total_pplga": int(d.get("total_pplga", 0)),
		"total_pplgb": int(d.get("total_pplgb", 0)),
		"overall_top10": _sanitize_rows(d.get("overall_top10", [])),
		"pplga_top10": _sanitize_rows(d.get("pplga_top10", [])),
		"pplgb_top10": _sanitize_rows(d.get("pplgb_top10", [])),
		"my_info": _sanitize_my_info(d.get("my_info", {})),
	}


static func _sanitize_rows(raw_val: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (raw_val is Array):
		return out
	for item: Variant in raw_val as Array:
		if item is Dictionary:
			var rd := item as Dictionary
			out.append({
				"rank": int(rd.get("rank", 0)),
				"nama": str(rd.get("nama", "")),
				"absen": str(rd.get("absen", "")),
				"kelas": str(rd.get("kelas", "")),
				"poin": float(rd.get("poin", 0.0)),
			})
	return out


static func _sanitize_my_info(raw_val: Variant) -> Dictionary:
	if not (raw_val is Dictionary):
		return {"found": false}
	var d := raw_val as Dictionary
	return {
		"found": bool(d.get("found", false)),
		"overall_rank": int(d.get("overall_rank", 0)),
		"overall_total": int(d.get("overall_total", 0)),
		"class_rank": int(d.get("class_rank", 0)),
		"class_total": int(d.get("class_total", 0)),
		"kelas": str(d.get("kelas", "")),
		"rata_rata": float(d.get("rata_rata", 0.0)),
	}


func build_local_leaderboard_fallback() -> Dictionary:
	var scores_arr: Array[int] = [
		int(GameSession.mg_scores.get("mg1", 0)),
		int(GameSession.mg_scores.get("mg2", 0)),
		int(GameSession.mg_scores.get("mg3", 0)),
		int(GameSession.mg_scores.get("mg4", 0)),
		int(GameSession.mg_scores.get("mg5", 0)),
	]
	var sum_s: int = 0
	var active_cnt: int = 0
	for i: int in range(5):
		var mg_id: String = GameSession.MG_IDS[i]
		if int(GameSession.mg_levels_done.get(mg_id, 0)) > 0:
			sum_s += scores_arr[i]
			active_cnt += 1
	var avg: float = float(sum_s) / float(maxi(1, active_cnt))
	return {
		"ok": true,
		"local_only": true,
		"total_overall": 0,
		"total_pplga": 0,
		"total_pplgb": 0,
		"overall_top10": [] as Array[Dictionary],
		"pplga_top10": [] as Array[Dictionary],
		"pplgb_top10": [] as Array[Dictionary],
		"my_info": {
			"found": GameSession.has_active_session(),
			"overall_rank": 0,
			"overall_total": 0,
			"class_rank": 0,
			"class_total": 0,
			"kelas": GameSession.kelas,
			"rata_rata": snappedf(avg, 0.01),
		}
	}


func _state_name() -> String:
	match current_state:
		SyncState.NO_URL:
			return "NO_URL"
		SyncState.INVALID_URL:
			return "INVALID_URL"
		SyncState.SENDING:
			return "SENDING"
		SyncState.SYNCED:
			return "SYNCED"
		SyncState.OFFLINE_QUEUED:
			return "OFFLINE_QUEUED"
		_:
			return "IDLE"


static func _csv_escape(value: Variant) -> String:
	var s: String = str(value)
	if s.contains("\"") or s.contains(",") or s.contains("\n") or s.contains("\r"):
		return "\"" + s.replace("\"", "\"\"") + "\""
	return s


func build_csv_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("REKAP_SISWA")
	lines.append("Session_ID,Waktu_Mulai,Nama_Siswa,Kelas,No_Absen,Game_1,Game_2,Game_3,Game_4,Game_5,Rata_Rata,Durasi_Detik,Status,Perangkat")
	var sum: Dictionary = GameSession.build_session_summary_payload("CSV_EXPORT")
	var avg_val: float = float(sum["total_skor"]) / 5.0
	lines.append(",".join([
		_csv_escape(sum["session_id"]),
		_csv_escape(sum["waktu_mulai"]),
		_csv_escape(sum["nama"]),
		_csv_escape(sum["kelas"]),
		_csv_escape(sum["absen"]),
		_csv_escape(sum["skor_mg1"]),
		_csv_escape(sum["skor_mg2"]),
		_csv_escape(sum["skor_mg3"]),
		_csv_escape(sum["skor_mg4"]),
		_csv_escape(sum["skor_mg5"]),
		_csv_escape(snappedf(avg_val, 0.01)),
		_csv_escape(sum["durasi_detik"]),
		_csv_escape(sum["status"]),
		_csv_escape(sum["perangkat"]),
	]))
	lines.append("")
	lines.append("LOG_JAWABAN_DETAIL")
	lines.append("Timestamp,Session_ID,Nama_Siswa,Kelas,Minigame_ID,Level_ID,Ringkasan_Soal,Jawaban_Siswa,Kunci_Jawaban,Hasil,Percobaan_Ke,Poin,Durasi_Detik")
	for entry: Dictionary in GameSession.attempt_logs:
		lines.append(",".join([
			_csv_escape(entry.get("timestamp", "")),
			_csv_escape(entry.get("session_id", "")),
			_csv_escape(entry.get("nama", "")),
			_csv_escape(entry.get("kelas", "")),
			_csv_escape(entry.get("minigame_id", "")),
			_csv_escape(entry.get("level_id", "")),
			_csv_escape(entry.get("soal_ringkas", "")),
			_csv_escape(entry.get("jawaban_siswa", "")),
			_csv_escape(entry.get("kunci_jawaban", "")),
			_csv_escape(entry.get("hasil", "")),
			_csv_escape(entry.get("percobaan_ke", 1)),
			_csv_escape(entry.get("poin", 0)),
			_csv_escape(entry.get("durasi_detik", 0)),
		]))
	return "\n".join(lines)


func export_csv_report() -> String:
	var csv_text: String = build_csv_report()
	var safe_name: String = GameSession.nama.replace(" ", "_")
	if safe_name.is_empty():
		safe_name = "siswa"
	var filename: String = "rapor_dos_%s.csv" % safe_name

	if OS.has_feature("web"):
		var b64: String = Marshalls.utf8_to_base64(csv_text)
		var js: String = (
			"(function(){"
			+ "var bin=atob('%s');" % b64
			+ "var bytes=new Uint8Array(bin.length);"
			+ "for(var i=0;i<bin.length;i++){bytes[i]=bin.charCodeAt(i);}"
			+ "var blob=new Blob([bytes],{type:'text/csv;charset=utf-8;'});"
			+ "var a=document.createElement('a');"
			+ "a.href=URL.createObjectURL(blob);"
			+ "a.download='%s';" % filename.replace("'", "")
			+ "document.body.appendChild(a);a.click();document.body.removeChild(a);"
			+ "})();"
		)
		JavaScriptBridge.eval(js)
		return "File %s mulai diunduh oleh browser." % filename

	var out_path: String = "user://%s" % filename
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		return "Gagal menyimpan CSV (kode %d)." % FileAccess.get_open_error()
	f.store_string(csv_text)
	f.close()
	return "CSV tersimpan di: %s" % ProjectSettings.globalize_path(out_path)
