extends Node
## Layanan auto-sinkronisasi hasil siswa ke Google Sheets (single-flight BATCH_SYNC, anti tumpang tindih), Leaderboard, & ekspor CSV.

signal sync_status_changed(status_code: String, message: String)
signal leaderboard_updated(status: String, data: Dictionary, message: String)
signal student_check_completed(allowed: bool, exists: bool, message: String, payload: Dictionary)

enum SyncState { NO_URL, INVALID_URL, IDLE, SENDING, SYNCED, OFFLINE_QUEUED }

const SUMMARY_EVENTS: Array[String] = ["SESSION_START", "SESSION_FINISH", "SESSION_SYNC"]
const MAX_BATCH_SIZE := 25

var current_state: SyncState = SyncState.IDLE
var last_message: String = ""
var cached_leaderboard: Dictionary = {}
var used_students_by_class: Dictionary = {"PPLGA": {}, "PPLGB": {}}
var _is_sending: bool = false
var _in_flight_count: int = 0
var _is_fetching_lb: bool = false
var _lb_pending_refresh: bool = false
var _is_checking_student: bool = false
var _is_fetching_pub_cfg: bool = false
var _check_pending_info: Dictionary = {}
var _active_request: HTTPRequest = null
var _lb_request: HTTPRequest = null
var _check_request: HTTPRequest = null
var _cfg_request: HTTPRequest = null
var _roster_request: HTTPRequest = null
var _pub_cfg_request: HTTPRequest = null
var _retry_timer: Timer = null


func _ready() -> void:
	GameConfig.config_reloaded.connect(_on_config_reloaded)
	_setup_auto_retry_timer()
	_refresh_initial_state()
	if OS.has_feature("web"):
		_fetch_web_runtime_config()
		_fetch_web_runtime_roster()
	elif GameConfig.has_valid_apps_script_url():
		if DisplayServer.get_name() != "headless":
			fetch_remote_exam_config()
		enqueue_unsent_attempt_logs()
		if not GameSession.pending_telemetry.is_empty():
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
		return
	_cfg_request = HTTPRequest.new()
	_cfg_request.timeout = 6.0
	add_child(_cfg_request)
	_cfg_request.request_completed.connect(_on_web_config_loaded, CONNECT_ONE_SHOT)
	var base_url: Variant = JavaScriptBridge.eval("window.location.href.split('?')[0].split('#')[0].replace(/[^\\/]*$/, '') + 'game_config.json?v=' + Date.now();")
	if base_url != null and not str(base_url).is_empty():
		_cfg_request.request(str(base_url), PackedStringArray(), HTTPClient.METHOD_GET)
	else:
		_cfg_request.queue_free()
		_cfg_request = null


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
			var prev_url: String = GameConfig.apps_script_url
			GameConfig.apply_config_json(text)
			if prev_url == GameConfig.apps_script_url and GameConfig.has_valid_apps_script_url():
				if DisplayServer.get_name() != "headless":
					fetch_remote_exam_config()
				enqueue_unsent_attempt_logs()
				if not _is_sending and not GameSession.pending_telemetry.is_empty():
					flush_pending_queue()
	elif GameConfig.has_valid_apps_script_url() and DisplayServer.get_name() != "headless":
		fetch_remote_exam_config()


func fetch_remote_exam_config() -> void:
	if not GameConfig.has_valid_apps_script_url() or DisplayServer.get_name() == "headless":
		return
	if _is_fetching_pub_cfg:
		return
	_is_fetching_pub_cfg = true
	if _pub_cfg_request != null and is_instance_valid(_pub_cfg_request):
		_pub_cfg_request.queue_free()
	_pub_cfg_request = HTTPRequest.new()
	_pub_cfg_request.timeout = 10.0
	add_child(_pub_cfg_request)
	_pub_cfg_request.request_completed.connect(_on_public_config_loaded, CONNECT_ONE_SHOT)
	var sep: String = "&" if GameConfig.apps_script_url.contains("?") else "?"
	var url: String = "%s%saction=public_config&_t=%d" % [
		GameConfig.apps_script_url,
		sep,
		int(Time.get_unix_time_from_system() * 1000.0),
	]
	var err: Error = _pub_cfg_request.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		_is_fetching_pub_cfg = false
		_pub_cfg_request.queue_free()
		_pub_cfg_request = null


func _on_public_config_loaded(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_is_fetching_pub_cfg = false
	if _pub_cfg_request != null and is_instance_valid(_pub_cfg_request):
		_pub_cfg_request.queue_free()
		_pub_cfg_request = null
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 400:
		return
	var text: String = body.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(text) == OK and json.data is Dictionary:
		var d := json.data as Dictionary
		if bool(d.get("ok", false)) and d.get("config") is Dictionary:
			GameConfig.apply_remote_exam_config(d.get("config") as Dictionary)


func _fetch_web_runtime_roster() -> void:
	# Memungkinkan guru memperbarui docs/students_roster.json tanpa perlu export ulang Godot!
	if _roster_request != null and is_instance_valid(_roster_request):
		return
	_roster_request = HTTPRequest.new()
	_roster_request.timeout = 6.0
	add_child(_roster_request)
	_roster_request.request_completed.connect(_on_web_roster_loaded, CONNECT_ONE_SHOT)
	var base_url: Variant = JavaScriptBridge.eval("window.location.href.split('?')[0].split('#')[0].replace(/[^\\/]*$/, '') + 'students_roster.json?v=' + Date.now();")
	if base_url != null and not str(base_url).is_empty():
		_roster_request.request(str(base_url), PackedStringArray(), HTTPClient.METHOD_GET)
	else:
		_roster_request.queue_free()
		_roster_request = null


func _on_web_roster_loaded(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if _roster_request != null and is_instance_valid(_roster_request):
		_roster_request.queue_free()
		_roster_request = null
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var text: String = body.get_string_from_utf8()
		if not text.is_empty():
			GameConfig.apply_roster_json(text)


static func _norm_class_key(kelas: String) -> String:
	var n: String = kelas.strip_edges().to_upper().replace(" ", "")
	return "PPLGB" if n == "PPLGB" else "PPLGA"


func mark_student_used_locally(kelas: String, nama: String, absen: String) -> void:
	var ck: String = _norm_class_key(kelas)
	if not used_students_by_class.has(ck):
		used_students_by_class[ck] = {}
	var bucket: Dictionary = used_students_by_class[ck] as Dictionary
	var n_key: String = nama.strip_edges().to_lower()
	var a_key: String = absen.strip_edges()
	if not n_key.is_empty():
		bucket["N:" + n_key] = true
	if not a_key.is_empty():
		bucket["A:" + a_key] = true


func is_student_marked_used(kelas: String, nama: String, absen: String) -> bool:
	var ck: String = _norm_class_key(kelas)
	if not used_students_by_class.has(ck):
		return false
	var bucket: Dictionary = used_students_by_class[ck] as Dictionary
	var n_key: String = nama.strip_edges().to_lower()
	var a_key: String = absen.strip_edges()
	if not n_key.is_empty() and bool(bucket.get("N:" + n_key, false)):
		return true
	if not a_key.is_empty() and bool(bucket.get("A:" + a_key, false)):
		return true
	return false


func check_student_eligibility(nama: String, kelas: String, absen: String) -> void:
	var clean_nama: String = nama.strip_edges()
	var clean_kelas: String = kelas.strip_edges()
	var clean_absen: String = absen.strip_edges()
	var req_mode: String = GameConfig.active_test_mode
	var meta := {"nama": clean_nama, "kelas": clean_kelas, "absen": clean_absen, "mode": req_mode}

	if not GameConfig.has_valid_apps_script_url():
		student_check_completed.emit(true, false, "Mode lokal aktif.", meta)
		return

	if _is_checking_student and _check_request != null and is_instance_valid(_check_request):
		_check_request.cancel_request()
		_check_request.queue_free()
		_check_request = null

	_is_checking_student = true
	_check_pending_info = meta

	var sep: String = "&" if GameConfig.apps_script_url.contains("?") else "?"
	var url: String = "%s%saction=check_student&nama=%s&kelas=%s&absen=%s&mode=%s&_t=%d" % [
		GameConfig.apps_script_url,
		sep,
		clean_nama.uri_encode(),
		clean_kelas.uri_encode(),
		clean_absen.uri_encode(),
		req_mode.uri_encode(),
		int(Time.get_unix_time_from_system() * 1000.0),
	]

	_check_request = HTTPRequest.new()
	_check_request.timeout = 12.0
	add_child(_check_request)
	_check_request.request_completed.connect(_on_student_check_response, CONNECT_ONE_SHOT)

	var err: Error = _check_request.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		_is_checking_student = false
		student_check_completed.emit(false, false, "Gagal memeriksa data ke Spreadsheet (kode %d). Periksa internet lalu coba lagi." % err, meta)


func _on_student_check_response(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_is_checking_student = false
	if _check_request != null and is_instance_valid(_check_request):
		_check_request.queue_free()
		_check_request = null

	var meta: Dictionary = _check_pending_info.duplicate()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 400:
		student_check_completed.emit(
			false,
			false,
			"Gagal memverifikasi nama ke Spreadsheet (HTTP %d). Periksa koneksi internet lalu coba lagi." % response_code,
			meta
		)
		return

	var text: String = body.get_string_from_utf8()
	var parsed: Dictionary = parse_student_check_json(
		text,
		str(meta.get("nama", "")),
		str(meta.get("absen", ""))
	)
	if parsed.is_empty():
		student_check_completed.emit(
			false,
			false,
			"Respon validasi Spreadsheet tidak valid. Pastikan Apps Script Web App (/exec) aktif.",
			meta
		)
		return

	var remote_cfg: Variant = parsed.get("config", {})
	if remote_cfg is Dictionary and not (remote_cfg as Dictionary).is_empty():
		GameConfig.apply_remote_exam_config(remote_cfg as Dictionary)

	var exists: bool = bool(parsed.get("exists", false))
	var allowed: bool = bool(parsed.get("allowed", not exists))
	var msg: String = str(parsed.get("message", ""))
	if exists:
		mark_student_used_locally(str(meta.get("kelas", "")), str(meta.get("nama", "")), str(meta.get("absen", "")))
	student_check_completed.emit(allowed, exists, msg, meta)


static func parse_student_check_json(raw_json: String, fallback_nama: String = "", fallback_absen: String = "") -> Dictionary:
	var json := JSON.new()
	if json.parse(raw_json) != OK or not (json.data is Dictionary):
		return {}
	var d := json.data as Dictionary
	if not bool(d.get("ok", false)):
		return {}

	var exists: bool = false
	var allowed: bool = true
	var msg: String = ""
	if d.has("exists"):
		exists = bool(d.get("exists", false))
		allowed = bool(d.get("allowed", not exists))
		msg = str(d.get("message", ""))
	elif d.has("my_info") and d.get("my_info") is Dictionary:
		# Kompatibilitas dengan deployment Apps Script versi sebelumnya melalui my_info.found
		var mi: Dictionary = d.get("my_info") as Dictionary
		exists = bool(mi.get("found", false))
		allowed = not exists

	if msg.is_empty():
		if exists:
			msg = "Nama \"%s\" (Absen %s) sudah dipakai dan tercatat di Spreadsheet. Hubungi guru jika ingin mengulang." % [fallback_nama, fallback_absen]
		else:
			msg = "Nama tersedia."
	return {
		"ok": true,
		"mode": str(d.get("mode", "")),
		"exists": exists,
		"allowed": allowed,
		"message": msg,
		"config": d.get("config", {}) if d.get("config") is Dictionary else {},
	}


func _on_config_reloaded() -> void:
	_refresh_initial_state()
	if GameConfig.has_valid_apps_script_url():
		if DisplayServer.get_name() != "headless":
			fetch_remote_exam_config()
		enqueue_unsent_attempt_logs()
		if GameSession.has_active_session():
			var summary_payload: Dictionary = GameSession.build_session_summary_payload("SESSION_SYNC")
			_enqueue_payload(summary_payload)
			GameSession.save_to_disk()
		if not GameSession.pending_telemetry.is_empty():
			flush_pending_queue()
		else:
			fetch_leaderboard()


func _emit_status(new_state: SyncState, new_msg: String) -> void:
	var changed: bool = (current_state != new_state) or (last_message != new_msg)
	current_state = new_state
	last_message = new_msg
	if changed:
		sync_status_changed.emit(_state_name(), last_message)


func _refresh_initial_state() -> void:
	if GameConfig.is_spreadsheet_edit_url():
		_emit_status(
			SyncState.INVALID_URL,
			"URL di game_config.json masih link Spreadsheet (docs.google.com). Ganti dengan URL Web App Apps Script (https://script.google.com/macros/s/.../exec)."
		)
	elif not GameConfig.has_valid_apps_script_url():
		_emit_status(
			SyncState.NO_URL,
			"Mode Lokal: isi URL Web App Apps Script (script.google.com/.../exec) di game_config.json agar auto-kirim ke Sheets aktif."
		)
	elif not GameSession.pending_telemetry.is_empty():
		_emit_status(
			SyncState.OFFLINE_QUEUED,
			"Auto-sync: %d data menunggu dikirim ke Google Sheets." % GameSession.pending_telemetry.size()
		)
	else:
		_emit_status(SyncState.IDLE, "Auto-sync aktif ke Google Sheets (Data Game DOS).")


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


func sync_session_now(include_finish: bool = true) -> void:
	if not GameConfig.has_valid_apps_script_url():
		_refresh_initial_state()
		fetch_leaderboard()
		return
	if GameSession.has_active_session():
		enqueue_unsent_attempt_logs()
		var ev_name: String = "SESSION_FINISH" if include_finish else "SESSION_SYNC"
		var summary_payload: Dictionary = GameSession.build_session_summary_payload(ev_name)
		_enqueue_payload(summary_payload)
		GameSession.save_to_disk()
	if not GameSession.pending_telemetry.is_empty():
		_lb_pending_refresh = true
		flush_pending_queue()
	else:
		fetch_leaderboard()


func _build_level_log_payload(entry: Dictionary) -> Dictionary:
	var payload: Dictionary = entry.duplicate(true)
	payload["event"] = "LEVEL_LOG"
	payload["test_mode"] = GameSession.test_mode
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
		_enqueue_payload(_build_level_log_payload(GameSession.attempt_logs[i]))
	GameSession.synced_log_count = total
	GameSession.save_to_disk()


func _enqueue_payload(payload: Dictionary) -> void:
	var ev: String = str(payload.get("event", ""))
	var min_idx: int = _in_flight_count if _is_sending else 0
	var queue: Array[Dictionary] = GameSession.pending_telemetry

	# Gabungkan (coalesce) event ringkasan kelas yg belum terbang agar tidak menumpuk di antrean
	if ev in SUMMARY_EVENTS:
		var sid: String = str(payload.get("session_id", ""))
		for i: int in range(min_idx, queue.size()):
			var existing: Dictionary = queue[i]
			var ex_ev: String = str(existing.get("event", ""))
			if ex_ev in SUMMARY_EVENTS and str(existing.get("session_id", "")) == sid:
				var merged: Dictionary = payload.duplicate(true)
				if ex_ev == "SESSION_FINISH" and ev != "SESSION_FINISH":
					merged["event"] = "SESSION_FINISH"
				queue[i] = merged
				return

	# Cegah duplikasi LEVEL_LOG identik sebelum terkirim
	if ev == "LEVEL_LOG":
		var log_key: String = "%s|%s|%s" % [
			str(payload.get("session_id", "")),
			str(payload.get("level_id", "")),
			str(payload.get("percobaan_ke", 1)),
		]
		for i: int in range(min_idx, queue.size()):
			var ex_log: Dictionary = queue[i]
			if str(ex_log.get("event", "")) == "LEVEL_LOG":
				var ex_key: String = "%s|%s|%s" % [
					str(ex_log.get("session_id", "")),
					str(ex_log.get("level_id", "")),
					str(ex_log.get("percobaan_ke", 1)),
				]
				if ex_key == log_key:
					queue[i] = payload.duplicate(true)
					return

	queue.append(payload.duplicate(true))


func enqueue_and_send(payload: Dictionary) -> void:
	if not GameConfig.has_valid_apps_script_url():
		_refresh_initial_state()
		return
	_enqueue_payload(payload)
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
		_in_flight_count = 0
		_emit_status(SyncState.SYNCED, "Otomatis tersimpan ke Google Sheets (PPLGA/PPLGB & LogJawaban).")
		_lb_pending_refresh = false
		fetch_leaderboard()
		return

	_is_sending = true
	var batch_count: int = mini(MAX_BATCH_SIZE, GameSession.pending_telemetry.size())
	_in_flight_count = batch_count
	_emit_status(SyncState.SENDING, "Auto-mengirim %d data ke Sheets..." % GameSession.pending_telemetry.size())

	var payload_to_send: Dictionary
	if batch_count == 1:
		payload_to_send = GameSession.pending_telemetry[0]
	else:
		var items_arr: Array[Dictionary] = []
		for i: int in range(batch_count):
			items_arr.append(GameSession.pending_telemetry[i])
		payload_to_send = {
			"event": "BATCH_SYNC",
			"items": items_arr,
		}

	var body: String = JSON.stringify(payload_to_send)
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
			var remove_n: int = clampi(_in_flight_count, 1, GameSession.pending_telemetry.size())
			for _i: int in range(remove_n):
				if not GameSession.pending_telemetry.is_empty():
					GameSession.pending_telemetry.remove_at(0)
			_in_flight_count = 0
			GameSession.save_to_disk()
			_send_next_in_queue()
			return

	_handle_send_failure("Koneksi tertunda (HTTP %d). Data aman & akan dicoba ulang otomatis." % response_code)


func _handle_send_failure(reason: String) -> void:
	_is_sending = false
	_in_flight_count = 0
	if _active_request != null and is_instance_valid(_active_request):
		_active_request.queue_free()
		_active_request = null
	_emit_status(SyncState.OFFLINE_QUEUED, reason)
	if _lb_pending_refresh:
		_lb_pending_refresh = false
		fetch_leaderboard()


func fetch_leaderboard(force: bool = false) -> void:
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

	# Cegah race condition: tunggu upload aktif selesai dulu agar leaderboard yang ditarik selalu terbaru
	if _is_sending:
		_lb_pending_refresh = true
		return
	if _is_fetching_lb:
		if force:
			_lb_pending_refresh = true
		return

	_is_fetching_lb = true
	leaderboard_updated.emit("LOADING", cached_leaderboard, "Mengambil papan peringkat terbaru dari Google Sheets...")
	var mode_q: String = GameSession.test_mode if GameSession.has_active_session() else GameConfig.active_test_mode
	var sep: String = "&" if GameConfig.apps_script_url.contains("?") else "?"
	var url: String = "%s%saction=leaderboard&nama=%s&kelas=%s&absen=%s&mode=%s&_t=%d" % [
		GameConfig.apps_script_url,
		sep,
		GameSession.nama.uri_encode(),
		GameSession.kelas.uri_encode(),
		GameSession.absen.uri_encode(),
		mode_q.uri_encode(),
		int(Time.get_unix_time_from_system() * 1000.0),
	]

	if _lb_request != null and is_instance_valid(_lb_request):
		_lb_request.queue_free()
	_lb_request = HTTPRequest.new()
	_lb_request.timeout = 12.0
	add_child(_lb_request)
	_lb_request.request_completed.connect(_on_leaderboard_completed, CONNECT_ONE_SHOT)

	var err: Error = _lb_request.request(url, PackedStringArray(), HTTPClient.METHOD_GET)
	if err != OK:
		_is_fetching_lb = false
		leaderboard_updated.emit("ERROR", cached_leaderboard, "Gagal menghubungi server Leaderboard (kode %d)." % err)


func _on_leaderboard_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_is_fetching_lb = false
	if _lb_request != null and is_instance_valid(_lb_request):
		_lb_request.queue_free()
		_lb_request = null

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 400:
		leaderboard_updated.emit("ERROR", cached_leaderboard, "Gagal memuat Leaderboard (HTTP %d). Periksa koneksi internet." % response_code)
	else:
		var text: String = body.get_string_from_utf8()
		var parsed: Dictionary = parse_leaderboard_json(text)
		if parsed.is_empty():
			leaderboard_updated.emit("ERROR", cached_leaderboard, "Format balasan Leaderboard tidak valid. Pastikan URL mengarah ke Apps Script Web App (/exec).")
		else:
			var remote_cfg: Variant = parsed.get("config", {})
			if remote_cfg is Dictionary and not (remote_cfg as Dictionary).is_empty():
				GameConfig.apply_remote_exam_config(remote_cfg as Dictionary)
			cached_leaderboard = parsed
			_sync_used_students_from_payload(parsed)
			var status_msg: String = str(parsed.get("message", ""))
			if status_msg.is_empty():
				status_msg = "Diperbarui otomatis dari Google Sheets."
			leaderboard_updated.emit("LOADED", parsed, status_msg)

	if _lb_pending_refresh:
		_lb_pending_refresh = false
		fetch_leaderboard()


static func parse_leaderboard_json(raw_json: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(raw_json) != OK or not (json.data is Dictionary):
		return {}
	var d := json.data as Dictionary
	if not bool(d.get("ok", false)):
		return {}
	return {
		"ok": true,
		"mode": str(d.get("mode", "")),
		"has_revealed_flag": d.has("revealed"),
		"revealed": bool(d.get("revealed", true)),
		"message": str(d.get("message", "")),
		"config": d.get("config", {}) if d.get("config") is Dictionary else {},
		"updated_at": str(d.get("updated_at", "")),
		"total_overall": int(d.get("total_overall", 0)),
		"total_pplga": int(d.get("total_pplga", 0)),
		"total_pplgb": int(d.get("total_pplgb", 0)),
		"overall_top10": _sanitize_rows(d.get("overall_top10", [])),
		"pplga_top10": _sanitize_rows(d.get("pplga_top10", [])),
		"pplgb_top10": _sanitize_rows(d.get("pplgb_top10", [])),
		"used_students": d.get("used_students", {}) if d.get("used_students") is Dictionary else {},
		"my_info": _sanitize_my_info(d.get("my_info", {})),
	}


func _sync_used_students_from_payload(parsed: Dictionary) -> void:
	var fresh_map: Dictionary = {"PPLGA": {}, "PPLGB": {}}
	var raw_used: Variant = parsed.get("used_students", {})
	if raw_used is Dictionary and not (raw_used as Dictionary).is_empty():
		for cls_k: Variant in (raw_used as Dictionary).keys():
			var ck: String = _norm_class_key(str(cls_k))
			var bucket: Dictionary = fresh_map[ck] as Dictionary
			var arr_v: Variant = (raw_used as Dictionary)[cls_k]
			if arr_v is Array:
				for item: Variant in arr_v as Array:
					if item is Dictionary:
						var it := item as Dictionary
						var nk: String = str(it.get("nama", "")).strip_edges().to_lower()
						var ak: String = str(it.get("absen", "")).strip_edges()
						if not nk.is_empty():
							bucket["N:" + nk] = true
						if not ak.is_empty():
							bucket["A:" + ak] = true
	else:
		# Fallback saat Apps Script versi lama belum mengirim used_students: isi dari top10 yang tersedia
		for pair: Array in [["pplga_top10", "PPLGA"], ["pplgb_top10", "PPLGB"]]:
			var bucket: Dictionary = fresh_map[str(pair[1])] as Dictionary
			var rows: Variant = parsed.get(str(pair[0]), [])
			if rows is Array:
				for r: Variant in rows as Array:
					if r is Dictionary:
						var rd := r as Dictionary
						var nk: String = str(rd.get("nama", "")).strip_edges().to_lower()
						var ak: String = str(rd.get("absen", "")).strip_edges()
						if not nk.is_empty():
							bucket["N:" + nk] = true
						if not ak.is_empty():
							bucket["A:" + ak] = true
	used_students_by_class = fresh_map


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
	var active_m: String = GameSession.test_mode if GameSession.has_active_session() else GameConfig.active_test_mode
	return {
		"ok": true,
		"local_only": true,
		"mode": active_m,
		"has_revealed_flag": true,
		"revealed": GameConfig.is_results_revealed_for(active_m),
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
