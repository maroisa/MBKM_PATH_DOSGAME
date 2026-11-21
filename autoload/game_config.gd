extends Node
## Konfigurasi global game yang dibaca dari res://data/game_config.json (plus override runtime Web).

signal config_reloaded

const CONFIG_PATH := "res://data/game_config.json"

var apps_script_url: String = "https://script.google.com/macros/s/AKfycbzGoyX345f2PkP1iZT8wd3tlfvdbwZJl3SWVQpmODgiv6kcZzyW4lbMncguhvktEwc0-w/exec"
var spreadsheet_url: String = "https://docs.google.com/spreadsheets/d/1_5KTFCkMfApJd6mqU1qBDhrvOMRTULbgtgTqdFUC5lo/edit?usp=sharing"
var spreadsheet_id: String = "1_5KTFCkMfApJd6mqU1qBDhrvOMRTULbgtgTqdFUC5lo"
var school_label: String = "Laboratorium RPL / PPLG • Materi Pengoperasian Teks (DOS & CMD)"
var class_options: Array[String] = ["PPLG A", "PPLG B"]
var allow_retry: bool = true
var retry_penalty_per_mistake: int = 10
var min_score_on_solve: int = 40
var hint_after_mistakes: int = 2


func _ready() -> void:
	load_config()


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
	apps_script_url = str(dict.get("apps_script_url", apps_script_url)).strip_edges()
	spreadsheet_url = str(dict.get("spreadsheet_url", spreadsheet_url)).strip_edges()
	spreadsheet_id = str(dict.get("spreadsheet_id", spreadsheet_id)).strip_edges()
	school_label = str(dict.get("school_label", school_label))
	allow_retry = bool(dict.get("allow_retry", allow_retry))
	retry_penalty_per_mistake = int(dict.get("retry_penalty_per_mistake", retry_penalty_per_mistake))
	min_score_on_solve = int(dict.get("min_score_on_solve", min_score_on_solve))
	hint_after_mistakes = int(dict.get("hint_after_mistakes", hint_after_mistakes))
	var raw_classes: Variant = dict.get("class_options", null)
	if raw_classes is Array and not (raw_classes as Array).is_empty():
		var parsed_classes: Array[String] = []
		for item: Variant in raw_classes as Array:
			parsed_classes.append(str(item))
		class_options = parsed_classes
	config_reloaded.emit()
	return true


func is_spreadsheet_edit_url() -> bool:
	return apps_script_url.contains("docs.google.com/spreadsheets")


func has_valid_apps_script_url() -> bool:
	if apps_script_url.is_empty():
		return false
	if is_spreadsheet_edit_url():
		return false
	return apps_script_url.begins_with("https://") or apps_script_url.begins_with("http://")
