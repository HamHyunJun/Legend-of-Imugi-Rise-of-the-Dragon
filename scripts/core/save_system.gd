extends Node
## 로컬 저장 시스템(자동 로드: SaveSystem).
##
## 파일 형식과 정책은 docs/design/05_데이터구조.md 7장을 따른다.
## - 슬롯: user://saves/auto.json, user://saves/manual_1.json
## - 쓰기: 임시 파일(.tmp)에 쓴 뒤 이름 변경. 직전 저장본은 .bak으로 보관.
## - 읽기: 본 파일이 없거나 손상(JSON 오류, 체크섬 불일치)되면 .bak으로 복구.
## - 체크섬: 손상 감지용 MD5(조작 방지 목적 아님).
## - 버전: save_version이 낮으면 _MIGRATIONS를 순서대로 적용.
## - 앱이 백그라운드로 가거나 종료될 때 자동 저장.

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1
const SLOT_AUTO := "auto"
const SLOT_MANUAL := "manual_1"

## 버전 n -> n+1 변환 함수. 예: 1: _migrate_v1_to_v2
## 각 함수는 state Dictionary를 받아 변환된 state를 돌려준다.
var _MIGRATIONS: Dictionary = {}

## false면 백그라운드 전환 시 자동 저장을 하지 않는다(테스트용).
var autosave_on_pause := true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			if autosave_on_pause:
				save_game(SLOT_AUTO)


## 현재 GameState를 슬롯에 저장한다. 성공 여부를 돌려준다.
func save_game(slot: String = SLOT_AUTO) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path := slot_path(slot)
	var state_text := _canonical_state_text(GameState.to_dict())
	var envelope := {
		"save_version": SAVE_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"saved_at": Time.get_datetime_string_from_system(),
		"slot": slot,
		"checksum": state_text.md5_text(),
		"state": JSON.parse_string(state_text),
	}

	# 1) 임시 파일에 쓴다.
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return _fail(slot, "임시 파일 열기 실패: %s" % error_string(FileAccess.get_open_error()))
	file.store_string(JSON.stringify(envelope, "\t", true))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return _fail(slot, "쓰기 실패: %s" % error_string(write_error))

	# 2) 기존 본 파일을 .bak으로 옮긴다.
	var dir := DirAccess.open(SAVE_DIR)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			dir.remove(path + ".bak")
		dir.rename(path, path + ".bak")

	# 3) 임시 파일을 본 파일 이름으로 바꾼다.
	var err := dir.rename(tmp_path, path)
	if err != OK:
		return _fail(slot, "이름 변경 실패: %s" % error_string(err))

	EventBus.game_saved.emit(slot)
	return true


## 슬롯을 불러와 GameState에 적용한다. 본 파일이 손상되면 .bak을 시도한다.
func load_game(slot: String = SLOT_AUTO) -> bool:
	var path := slot_path(slot)
	for candidate in [path, path + ".bak"]:
		var state: Variant = _read_save(candidate)
		if state is Dictionary:
			if candidate != path:
				push_warning("[SaveSystem] %s 손상, 백업에서 복구함" % path)
			GameState.from_dict(state)
			EventBus.state_reset.emit()
			EventBus.game_loaded.emit(slot)
			return true
	return false


func has_save(slot: String = SLOT_AUTO) -> bool:
	var path := slot_path(slot)
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## 슬롯의 본 파일과 백업을 모두 지운다.
func delete_save(slot: String) -> void:
	var path := slot_path(slot)
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func slot_path(slot: String) -> String:
	return SAVE_DIR.path_join(slot + ".json")


# --- 내부 ---

## 파일 하나를 읽어 검증·마이그레이션한 state를 돌려준다. 실패하면 null.
func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	# JSON.parse_string은 실패 시 엔진 오류 로그를 남기므로 인스턴스로 조용히 파싱한다.
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not (parsed is Dictionary) or not (parsed.get("state") is Dictionary):
		push_warning("[SaveSystem] %s: 형식 오류" % path)
		return null
	var state: Dictionary = parsed["state"]
	if _canonical_state_text(state).md5_text() != str(parsed.get("checksum", "")):
		push_warning("[SaveSystem] %s: 체크섬 불일치" % path)
		return null
	return _migrate(state, int(parsed.get("save_version", 1)))


func _migrate(state: Dictionary, from_version: int) -> Dictionary:
	var version := from_version
	while version < SAVE_VERSION:
		if not _MIGRATIONS.has(version):
			push_error("[SaveSystem] v%d -> v%d 마이그레이션 없음" % [version, version + 1])
			break
		state = _MIGRATIONS[version].call(state)
		version += 1
	return state


## 체크섬 계산용 정규화 문자열.
## JSON은 정수를 실수로 읽기 때문에(3 -> 3.0) 한 번 왕복시킨 결과를 기준으로 삼아
## 저장 직후와 다시 읽은 뒤의 문자열이 같도록 만든다.
static func _canonical_state_text(state: Dictionary) -> String:
	var once := JSON.stringify(state, "", true)
	return JSON.stringify(JSON.parse_string(once), "", true)


func _fail(slot: String, reason: String) -> bool:
	push_error("[SaveSystem] %s 저장 실패: %s" % [slot, reason])
	EventBus.save_failed.emit(slot, reason)
	return false
