extends Node
## State sesi siswa, skor tiap minigame, log jawaban lengkap, dan simpanan lokal atomik.

signal session_updated

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://dos_rescue_save.json"
const MG_IDS: Array[String] = ["mg1", "mg2", "mg3", "mg4", "mg5"]

var save_path: String = DEFAULT_SAVE_PATH

var session_id: String = ""
var test_mode: String = "PRETEST"
var nama: String = ""
var kelas: String = ""
var absen: String = ""
var waktu_mulai_iso: String = ""
var started_unix: int = 0
var device_info: String = ""

var mg_scores: Dictionary[String, int] = {"mg1": 0, "mg2": 0, "mg3": 0, "mg4": 0, "mg5": 0}
var mg_completed: Dictionary[String, bool] = {"mg1": false, "mg2": false, "mg3": false, "mg4": false, "mg5": false}
var mg_levels_done: Dictionary[String, int] = {"mg1": 0, "mg2": 0, "mg3": 0, "mg4": 0, "mg5": 0}
var level_best_scores: Dictionary[String, int] = {}
var level_answered: Dictionary[String, bool] = {}
var attempt_logs: Array[Dictionary] = []
var pending_telemetry: Array[Dictionary] = []
var synced_log_count: int = 0


func _ready() -> void:
	load_from_disk()


func has_active_session() -> bool:
	return not session_id.is_empty() and not nama.is_empty()


func start_new_session(p_nama: String, p_kelas: String, p_absen: String, p_mode: String = "") -> void:
	nama = p_nama.strip_edges()
	kelas = p_kelas.strip_edges()
	absen = p_absen.strip_edges()
	test_mode = GameConfig.normalize_test_mode(p_mode if not p_mode.is_empty() else GameConfig.active_test_mode)
	started_unix = int(Time.get_unix_time_from_system())
	waktu_mulai_iso = Time.get_datetime_string_from_system(false, true)
	session_id = "DOS-%s-%d-%04d" % [test_mode, started_unix, randi() % 10000]
	device_info = _detect_device_label()

	for mg_id: String in MG_IDS:
		mg_scores[mg_id] = 0
		mg_completed[mg_id] = false
		mg_levels_done[mg_id] = 0
	level_best_scores.clear()
	level_answered.clear()
	attempt_logs.clear()
	pending_telemetry.clear()
	synced_log_count = 0
	save_to_disk()
	session_updated.emit()


func clear_session() -> void:
	session_id = ""
	test_mode = GameConfig.active_test_mode
	nama = ""
	kelas = ""
	absen = ""
	waktu_mulai_iso = ""
	started_unix = 0
	for mg_id: String in MG_IDS:
		mg_scores[mg_id] = 0
		mg_completed[mg_id] = false
		mg_levels_done[mg_id] = 0
	level_best_scores.clear()
	level_answered.clear()
	attempt_logs.clear()
	pending_telemetry.clear()
	synced_log_count = 0
	save_to_disk()
	session_updated.emit()


func record_attempt(
	mg_id: String,
	level_id: String,
	soal_ringkas: String,
	jawaban_siswa: String,
	kunci_jawaban: String,
	is_correct: bool,
	percobaan_ke: int,
	poin: int,
	durasi_detik: float
) -> Dictionary:
	var final_poin: int = poin if is_correct else 0
	var entry: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"session_id": session_id,
		"test_mode": test_mode,
		"nama": nama,
		"kelas": kelas,
		"absen": absen,
		"minigame_id": mg_id,
		"level_id": level_id,
		"soal_ringkas": soal_ringkas,
		"jawaban_siswa": jawaban_siswa,
		"kunci_jawaban": kunci_jawaban,
		"hasil": "BENAR" if is_correct else "SALAH",
		"percobaan_ke": percobaan_ke,
		"poin": final_poin,
		"durasi_detik": int(roundf(durasi_detik)),
	}
	attempt_logs.append(entry)

	if GameConfig.exam_blind_mode:
		if not level_answered.has(level_id):
			level_answered[level_id] = true
			level_best_scores[level_id] = final_poin
		_recompute_minigame_summary(mg_id)
	elif is_correct:
		level_answered[level_id] = true
		var prev_best: int = level_best_scores.get(level_id, 0)
		level_best_scores[level_id] = maxi(prev_best, final_poin)
		_recompute_minigame_summary(mg_id)

	save_to_disk()
	session_updated.emit()
	return entry


func mark_minigame_finished(mg_id: String) -> void:
	_recompute_minigame_summary(mg_id)
	mg_completed[mg_id] = true
	save_to_disk()
	session_updated.emit()


func _recompute_minigame_summary(mg_id: String) -> void:
	var levels: Array[Dictionary] = LevelsCatalog.get_levels(mg_id)
	var sum_pts: int = 0
	var done_count: int = 0
	for lv: Dictionary in levels:
		var lid: String = str(lv.get("id", ""))
		if level_answered.has(lid) or level_best_scores.has(lid):
			done_count += 1
			sum_pts += int(level_best_scores.get(lid, 0))
	var avg_score: int = int(roundf(float(sum_pts) / float(maxi(1, levels.size()))))
	mg_scores[mg_id] = avg_score
	mg_levels_done[mg_id] = done_count
	if done_count >= levels.size() and levels.size() > 0:
		mg_completed[mg_id] = true


func get_total_score() -> int:
	var total: int = 0
	for mg_id: String in MG_IDS:
		total += int(mg_scores.get(mg_id, 0))
	return total


func get_completed_minigame_count() -> int:
	var count: int = 0
	for mg_id: String in MG_IDS:
		if bool(mg_completed.get(mg_id, false)):
			count += 1
	return count


func get_elapsed_seconds() -> int:
	if started_unix <= 0:
		return 0
	return maxi(0, int(Time.get_unix_time_from_system()) - started_unix)


func build_session_summary_payload(event_name: String) -> Dictionary:
	var done_count: int = get_completed_minigame_count()
	return {
		"event": event_name,
		"session_id": session_id,
		"test_mode": test_mode,
		"waktu_mulai": waktu_mulai_iso,
		"nama": nama,
		"kelas": kelas,
		"absen": absen,
		"skor_mg1": int(mg_scores.get("mg1", 0)),
		"skor_mg2": int(mg_scores.get("mg2", 0)),
		"skor_mg3": int(mg_scores.get("mg3", 0)),
		"skor_mg4": int(mg_scores.get("mg4", 0)),
		"skor_mg5": int(mg_scores.get("mg5", 0)),
		"total_skor": get_total_score(),
		"minigame_selesai": done_count,
		"durasi_detik": get_elapsed_seconds(),
		"status": "SELESAI" if done_count >= MG_IDS.size() else "PROSES",
		"perangkat": device_info,
	}


func capture_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"session_id": session_id,
		"test_mode": test_mode,
		"nama": nama,
		"kelas": kelas,
		"absen": absen,
		"waktu_mulai_iso": waktu_mulai_iso,
		"started_unix": started_unix,
		"device_info": device_info,
		"mg_scores": mg_scores.duplicate(),
		"mg_completed": mg_completed.duplicate(),
		"mg_levels_done": mg_levels_done.duplicate(),
		"level_best_scores": level_best_scores.duplicate(),
		"level_answered": level_answered.duplicate(),
		"attempt_logs": attempt_logs.duplicate(true),
		"pending_telemetry": pending_telemetry.duplicate(true),
		"synced_log_count": synced_log_count,
	}


func apply_state(data: Dictionary) -> void:
	session_id = str(data.get("session_id", ""))
	test_mode = GameConfig.normalize_test_mode(str(data.get("test_mode", "PRETEST")))
	nama = str(data.get("nama", ""))
	kelas = str(data.get("kelas", ""))
	absen = str(data.get("absen", ""))
	waktu_mulai_iso = str(data.get("waktu_mulai_iso", ""))
	started_unix = int(data.get("started_unix", 0))
	device_info = str(data.get("device_info", ""))

	var raw_scores: Variant = data.get("mg_scores", {})
	var raw_comp: Variant = data.get("mg_completed", {})
	var raw_done: Variant = data.get("mg_levels_done", {})
	for mg_id: String in MG_IDS:
		mg_scores[mg_id] = int((raw_scores as Dictionary).get(mg_id, 0)) if raw_scores is Dictionary else 0
		mg_completed[mg_id] = bool((raw_comp as Dictionary).get(mg_id, false)) if raw_comp is Dictionary else false
		mg_levels_done[mg_id] = int((raw_done as Dictionary).get(mg_id, 0)) if raw_done is Dictionary else 0

	level_best_scores.clear()
	var raw_best: Variant = data.get("level_best_scores", {})
	if raw_best is Dictionary:
		for k: Variant in (raw_best as Dictionary).keys():
			level_best_scores[str(k)] = int((raw_best as Dictionary)[k])

	level_answered.clear()
	var raw_ans: Variant = data.get("level_answered", {})
	if raw_ans is Dictionary:
		for k: Variant in (raw_ans as Dictionary).keys():
			level_answered[str(k)] = bool((raw_ans as Dictionary)[k])
	for bk: String in level_best_scores.keys():
		level_answered[bk] = true

	attempt_logs.clear()
	var raw_logs: Variant = data.get("attempt_logs", [])
	if raw_logs is Array:
		for item: Variant in raw_logs as Array:
			if item is Dictionary:
				var d := (item as Dictionary).duplicate(true)
				d["percobaan_ke"] = int(d.get("percobaan_ke", 1))
				d["poin"] = int(d.get("poin", 0))
				d["durasi_detik"] = int(d.get("durasi_detik", 0))
				attempt_logs.append(d)

	pending_telemetry.clear()
	var raw_pend: Variant = data.get("pending_telemetry", [])
	if raw_pend is Array:
		for item: Variant in raw_pend as Array:
			if item is Dictionary:
				pending_telemetry.append((item as Dictionary).duplicate(true))
	synced_log_count = clampi(int(data.get("synced_log_count", 0)), 0, attempt_logs.size())


func save_to_disk(target_path: String = "") -> Error:
	var path: String = target_path if not target_path.is_empty() else save_path
	return save_atomic(path, capture_state())


func load_from_disk(target_path: String = "") -> bool:
	var path: String = target_path if not target_path.is_empty() else save_path
	var data: Dictionary = load_atomic(path)
	if data.is_empty():
		return false
	var v: int = int(data.get("version", 1))
	if v > SAVE_VERSION:
		push_warning("GameSession: versi simpanan %d lebih baru dari build ini (%d)." % [v, SAVE_VERSION])
		return false
	apply_state(data)
	return true


static func save_atomic(path: String, data: Dictionary) -> Error:
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	if not f.store_string(JSON.stringify(data)):
		f.close()
		return ERR_FILE_CANT_WRITE
	f.close()
	var abs_path: String = ProjectSettings.globalize_path(path)
	var abs_tmp: String = ProjectSettings.globalize_path(tmp)
	var abs_bak: String = ProjectSettings.globalize_path(path + ".bak")
	if FileAccess.file_exists(path):
		DirAccess.rename_absolute(abs_path, abs_bak)
	return DirAccess.rename_absolute(abs_tmp, abs_path)


static func load_atomic(path: String) -> Dictionary:
	for p: String in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			var raw: String = FileAccess.get_file_as_string(p)
			var json := JSON.new()
			if json.parse(raw) == OK and json.data is Dictionary:
				var dict := json.data as Dictionary
				if dict.has("version"):
					dict["version"] = int(dict["version"])
					return dict
	return {}


func _detect_device_label() -> String:
	var plat: String = "Web" if OS.has_feature("web") else OS.get_name()
	var vp := get_viewport()
	if vp != null:
		var s: Vector2 = vp.get_visible_rect().size
		return "%s (%dx%d)" % [plat, int(s.x), int(s.y)]
	return plat
