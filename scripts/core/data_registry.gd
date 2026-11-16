extends Node
## 콘텐츠 정의 데이터 저장소(자동 로드: DataRegistry).
##
## 게임 시작 시 res://data/ 아래 JSON을 모두 읽어 메모리에 올린다.
## 정의 데이터는 읽기 전용이다. 변하는 값은 GameState에만 둔다.
##
## 읽는 규칙(docs/design/05_데이터구조.md 1~2장):
## - 단일 파일 카탈로그: elements.json(배열), nest.json, yinyang.json, progression.json(객체)
## - 폴더 카탈로그: forms/, skills/, regions/, npcs/, dialogues/, quests/, enemies/
##   폴더 안의 각 .json 파일은 "id" 필드를 가진 정의 1개(또는 정의 배열)다.
##
## MVP에서는 Dictionary 그대로 보관하고, 필요해지면 카탈로그별 타입 클래스로 감싼다.

const DATA_ROOT := "res://data"

## 폴더 단위로 읽는 카탈로그 이름(= 폴더 이름).
const FOLDER_CATALOGS: PackedStringArray = [
	"forms", "skills", "regions", "npcs", "dialogues", "quests", "enemies",
]
## id 배열로 읽는 단일 파일 카탈로그.
const LIST_FILES: Dictionary = {
	"elements": "elements.json",
}
## 객체 하나로 읽는 단일 파일 설정.
const OBJECT_FILES: Dictionary = {
	"nest": "nest.json",
	"yinyang": "yinyang.json",
	"progression": "progression.json",
}

## catalog 이름 -> { id -> 정의 Dictionary }
var _catalogs: Dictionary = {}
## 설정 이름 -> Dictionary
var _configs: Dictionary = {}
## 로드 중 발견한 문제(중복 ID, JSON 오류 등). 검증 도구와 디버그 화면에서 쓴다.
var errors: PackedStringArray = []
var is_loaded := false


func _ready() -> void:
	load_all()


## 모든 정의 데이터를 다시 읽는다. 개발 중 핫 리로드에도 쓸 수 있다.
func load_all(root: String = DATA_ROOT) -> void:
	_catalogs.clear()
	_configs.clear()
	errors.clear()

	for catalog: String in LIST_FILES:
		_catalogs[catalog] = {}
		var path: String = root.path_join(LIST_FILES[catalog])
		if FileAccess.file_exists(path):
			_register_entries(catalog, _read_json(path), path)

	for catalog: String in FOLDER_CATALOGS:
		_catalogs[catalog] = {}
		for path in _list_json_files(root.path_join(catalog)):
			_register_entries(catalog, _read_json(path), path)

	for config: String in OBJECT_FILES:
		var path: String = root.path_join(OBJECT_FILES[config])
		var parsed: Variant = _read_json(path) if FileAccess.file_exists(path) else {}
		if parsed is Dictionary:
			_configs[config] = parsed
		else:
			_configs[config] = {}
			errors.append("%s: 최상위가 객체가 아님" % path)

	is_loaded = true
	for e in errors:
		push_warning("[DataRegistry] " + e)
	print("[DataRegistry] 로드 완료: %s (오류 %d건)" % [_summary(), errors.size()])
	EventBus.data_loaded.emit()


## 정의 1개를 반환한다. 없으면 빈 Dictionary.
func get_def(catalog: String, id: String) -> Dictionary:
	var table: Dictionary = _catalogs.get(catalog, {})
	return table.get(id, {})


func has_def(catalog: String, id: String) -> bool:
	return _catalogs.get(catalog, {}).has(id)


## 카탈로그의 모든 정의(id -> 정의).
func get_all(catalog: String) -> Dictionary:
	return _catalogs.get(catalog, {})


## 단일 파일 설정(nest, yinyang, progression).
func get_config(config: String) -> Dictionary:
	return _configs.get(config, {})


func catalog_names() -> Array:
	return _catalogs.keys()


# --- 내부 ---

func _register_entries(catalog: String, parsed: Variant, path: String) -> void:
	var entries: Array = []
	if parsed is Array:
		entries = parsed
	elif parsed is Dictionary:
		entries = [parsed]
	else:
		return # _read_json에서 이미 오류를 기록했다.

	var table: Dictionary = _catalogs[catalog]
	for entry: Variant in entries:
		if not (entry is Dictionary) or not entry.has("id"):
			errors.append("%s: id가 없는 항목" % path)
			continue
		var id := str(entry["id"])
		if table.has(id):
			errors.append("%s: 중복 ID '%s' (%s)" % [path, id, catalog])
			continue
		table[id] = entry


func _read_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		errors.append("%s: 읽기 실패 또는 빈 파일" % path)
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s:%d: JSON 오류 - %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _list_json_files(dir_path: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for file in dir.get_files():
		# 내보낸 빌드에서도 원본 .json이 그대로 포함되므로 확장자로만 거른다.
		if file.get_extension() == "json":
			result.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		result.append_array(_list_json_files(dir_path.path_join(sub)))
	result.sort()
	return result


func _summary() -> String:
	var parts: PackedStringArray = []
	for catalog: String in _catalogs:
		parts.append("%s %d" % [catalog, _catalogs[catalog].size()])
	return ", ".join(parts)
