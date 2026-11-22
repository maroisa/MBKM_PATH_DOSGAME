extends Node
## Konfigurasi global game yang dibaca dari res://data/game_config.json (plus override runtime Web).

signal config_reloaded
signal roster_reloaded
signal exam_config_updated

const CONFIG_PATH := "res://data/game_config.json"
const ROSTER_PATH := "res://data/students_roster.json"

var apps_script_url: String = "https://script.google.com/macros/s/AKfycbzGoyX345f2PkP1iZT8wd3tlfvdbwZJl3SWVQpmODgiv6kcZzyW4lbMncguhvktEwc0-w/exec"
var spreadsheet_url: String = "https://docs.google.com/spreadsheets/d/1_5KTFCkMfApJd6mqU1qBDhrvOMRTULbgtgTqdFUC5lo/edit?usp=sharing"
var spreadsheet_id: String = "1_5KTFCkMfApJd6mqU1qBDhrvOMRTULbgtgTqdFUC5lo"
var school_label: String = "Laboratorium RPL / PPLG • Materi Pengoperasian Teks (DOS & CMD)"
var class_options: Array[String] = ["PPLG A", "PPLG B"]
var students_by_class: Dictionary = {}

# Mode Ujian Pre-Test / Post-Test (dikontrol Admin via Google Sheets sheet "Config")
var active_test_mode: String = "PRETEST"
var exam_blind_mode: bool = true
var reveal_pretest_results: bool = false
var reveal_posttest_results: bool = false
var allow_materi_pretest: bool = false
var allow_materi_posttest: bool = false

var allow_retry: bool = false
var retry_penalty_per_mistake: int = 10
var min_score_on_solve: int = 10
var level_time_limit_sec: float = 30.0
var time_grace_sec: float = 10.0
var hint_after_mistakes: int = 2


func _ready() -> void:
	load_config()
	load_roster()


func load_roster() -> void:
	if not FileAccess.file_exists(ROSTER_PATH):
		return
	var raw: String = FileAccess.get_file_as_string(ROSTER_PATH)
	apply_roster_json(raw)


func apply_roster_json(raw: String) -> bool:
	var json := JSON.new()
	if json.parse(raw) != OK or not (json.data is Dictionary):
		push_warning("GameConfig: gagal parse students_roster.json (%s)" % json.get_error_message())
		return false
	var root_dict := json.data as Dictionary
	var raw_classes: Variant = root_dict.get("classes", null)
	if not (raw_classes is Dictionary):
		return false
	var parsed: Dictionary = {}
	for cls_k: Variant in (raw_classes as Dictionary).keys():
		var cls_name: String = str(cls_k).strip_edges()
		var raw_arr: Variant = (raw_classes as Dictionary)[cls_k]
		var list: Array[Dictionary] = []
		if raw_arr is Array:
			for item: Variant in raw_arr as Array:
				if item is Dictionary:
					var d := item as Dictionary
					var s_nama: String = str(d.get("nama", "")).strip_edges()
					var s_absen: int = int(d.get("absen", 0))
					var s_nis: String = str(d.get("nis", "")).strip_edges()
					if not s_nama.is_empty() and s_absen > 0:
						list.append({
							"absen": s_absen,
							"nis": s_nis,
							"nama": s_nama,
						})
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("absen", 0)) < int(b.get("absen", 0))
		)
		parsed[cls_name] = list
	students_by_class = parsed
	roster_reloaded.emit()
	return true


func get_students_for_class(kelas: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var target: String = kelas.strip_edges()
	var raw: Variant = students_by_class.get(target, null)
	if raw == null:
		var norm: String = target.to_upper().replace(" ", "")
		for k: Variant in students_by_class.keys():
			if str(k).to_upper().replace(" ", "") == norm:
				raw = students_by_class[k]
				break
	if raw is Array:
		for item: Variant in raw as Array:
			if item is Dictionary:
				out.append(item as Dictionary)
	return out


func has_roster_for_class(kelas: String) -> bool:
	return not get_students_for_class(kelas).is_empty()


func load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var raw: String = FileAccess.get_file_as_string(CONFIG_PATH)
	apply_config_json(raw)


func apply_config_json(raw: String) -> bool:
	var json := JSON.new()
	if json.parse(raw) != OK:
		push_warning("GameConfig: gagal parse konfigurasi (%s)" % json.get_error_message())
		return false
	var data: Variant = json.data
	if not (data is Dictionary):
		return false
	var dict := data as Dictionary
	var new_url: String = str(dict.get("apps_script_url", "")).strip_edges()
	if not new_url.is_empty():
		apps_script_url = new_url
	spreadsheet_url = str(dict.get("spreadsheet_url", spreadsheet_url)).strip_edges()
	spreadsheet_id = str(dict.get("spreadsheet_id", spreadsheet_id)).strip_edges()
	school_label = str(dict.get("school_label", school_label))
	if dict.has("active_test_mode"):
		active_test_mode = normalize_test_mode(str(dict.get("active_test_mode", active_test_mode)))
	if dict.has("exam_blind_mode"):
		exam_blind_mode = bool(dict.get("exam_blind_mode", exam_blind_mode))
	if dict.has("reveal_pretest_results"):
		reveal_pretest_results = bool(dict.get("reveal_pretest_results", reveal_pretest_results))
	if dict.has("reveal_posttest_results"):
		reveal_posttest_results = bool(dict.get("reveal_posttest_results", reveal_posttest_results))
	if dict.has("allow_materi_pretest"):
		allow_materi_pretest = bool(dict.get("allow_materi_pretest", allow_materi_pretest))
	if dict.has("allow_materi_posttest"):
		allow_materi_posttest = bool(dict.get("allow_materi_posttest", allow_materi_posttest))
	allow_retry = bool(dict.get("allow_retry", allow_retry))
	retry_penalty_per_mistake = int(dict.get("retry_penalty_per_mistake", retry_penalty_per_mistake))
	min_score_on_solve = int(dict.get("min_score_on_solve", min_score_on_solve))
	level_time_limit_sec = maxf(10.0, float(dict.get("level_time_limit_sec", level_time_limit_sec)))
	time_grace_sec = clampf(float(dict.get("time_grace_sec", time_grace_sec)), 0.0, level_time_limit_sec)
	hint_after_mistakes = int(dict.get("hint_after_mistakes", hint_after_mistakes))
	var raw_classes: Variant = dict.get("class_options", null)
	if raw_classes is Array and not (raw_classes as Array).is_empty():
		var parsed_classes: Array[String] = []
		for item: Variant in raw_classes as Array:
			parsed_classes.append(str(item))
		class_options = parsed_classes
	config_reloaded.emit()
	exam_config_updated.emit()
	return true


static func normalize_test_mode(raw: String) -> String:
	var s: String = raw.strip_edges().to_upper().replace("-", "").replace("_", "").replace(" ", "")
	return "POSTTEST" if s == "POSTTEST" else "PRETEST"


func get_mode_label(mode_override: String = "") -> String:
	var m: String = normalize_test_mode(mode_override if not mode_override.is_empty() else active_test_mode)
	return "POST-TEST" if m == "POSTTEST" else "PRE-TEST"


func is_results_revealed_for(mode_override: String = "") -> bool:
	var m: String = normalize_test_mode(mode_override if not mode_override.is_empty() else active_test_mode)
	return reveal_posttest_results if m == "POSTTEST" else reveal_pretest_results


func is_materi_allowed_for(mode_override: String = "") -> bool:
	var m: String = normalize_test_mode(mode_override if not mode_override.is_empty() else active_test_mode)
	return allow_materi_posttest if m == "POSTTEST" else allow_materi_pretest


func apply_remote_exam_config(cfg: Dictionary) -> void:
	if cfg.is_empty():
		return
	var changed: bool = false
	if cfg.has("active_mode"):
		var nm: String = normalize_test_mode(str(cfg.get("active_mode", active_test_mode)))
		if nm != active_test_mode:
			active_test_mode = nm
			changed = true
	if cfg.has("reveal_pretest_results"):
		var rp: bool = bool(cfg.get("reveal_pretest_results", reveal_pretest_results))
		if rp != reveal_pretest_results:
			reveal_pretest_results = rp
			changed = true
	if cfg.has("reveal_posttest_results"):
		var rpo: bool = bool(cfg.get("reveal_posttest_results", reveal_posttest_results))
		if rpo != reveal_posttest_results:
			reveal_posttest_results = rpo
			changed = true
	if cfg.has("allow_materi_pretest"):
		var amp: bool = bool(cfg.get("allow_materi_pretest", allow_materi_pretest))
		if amp != allow_materi_pretest:
			allow_materi_pretest = amp
			changed = true
	if cfg.has("allow_materi_posttest"):
		var ampo: bool = bool(cfg.get("allow_materi_posttest", allow_materi_posttest))
		if ampo != allow_materi_posttest:
			allow_materi_posttest = ampo
			changed = true
	if changed:
		exam_config_updated.emit()


func is_spreadsheet_edit_url() -> bool:
	return apps_script_url.contains("docs.google.com/spreadsheets")


func has_valid_apps_script_url() -> bool:
	if apps_script_url.is_empty():
		return false
	if is_spreadsheet_edit_url():
		return false
	return apps_script_url.begins_with("https://") or apps_script_url.begins_with("http://")
